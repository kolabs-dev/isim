/* isim-webkit: the web engine behind isim's WKWebView (a host helper process, Linux ELF).
 *
 * Runs real WebKit (the host's WebKitGTK 6.0) without any visible window: it starts a private
 * GTK broadway display server (gtk4-broadwayd, bound to 127.0.0.1, nobody connects to it), puts
 * each web view in an undecorated window there, and snapshots the page into shared memory that the
 * isim runtime (runtime/host_web.c) maps and draws. Input from the simulated touch screen and
 * keyboard arrives as commands and is applied with DOM events from an isolated JavaScript world
 * (WebKitGTK has no public input-injection API), so page scripts see isTrusted == false.
 *
 * Protocol (fd 3, a socketpair with the runtime): one message per line, fields separated by TAB;
 * fields escape '\\' '\n' '\t' as "\\\\" "\\n" "\\t". Commands carry a view id in field 2; see
 * cmd() below. Events go back the same way (see host_web.c / the WebKit overlay for their meaning).
 */
#define _GNU_SOURCE
#include <gtk/gtk.h>
#include <webkit/webkit.h>
#include <jsc/jsc.h>
#include <libsoup/soup.h>
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#define PROTO_FD 3
static GString *inbuf;
static int debug;
static pid_t broadway_pid;

/* ---------------- messages ---------------- */
static void esc(GString *o, const char *s) {
    for (; s && *s; s++) {
        if (*s == '\\') g_string_append(o, "\\\\");
        else if (*s == '\n') g_string_append(o, "\\n");
        else if (*s == '\t') g_string_append(o, "\\t");
        else if (*s == '\r') g_string_append(o, "\\r");
        else g_string_append_c(o, *s);
    }
}
static void unesc(char *s) {
    char *d = s;
    for (; *s; s++) {
        if (*s == '\\' && s[1]) {
            s++;
            *d++ = *s == 'n' ? '\n' : *s == 't' ? '\t' : *s == 'r' ? '\r' : *s;
        } else *d++ = *s;
    }
    *d = 0;
}
/* send(view, event, fields..., NULL) */
static void sendv(int view, const char *ev, ...) {
    GString *o = g_string_new(NULL);
    g_string_append_printf(o, "%s\t%d", ev, view);
    va_list ap; va_start(ap, ev);
    for (const char *f; (f = va_arg(ap, const char *)); ) { g_string_append_c(o, '\t'); esc(o, f); }
    va_end(ap);
    g_string_append_c(o, '\n');
    const char *p = o->str; size_t n = o->len;
    while (n > 0) {
        ssize_t w = write(PROTO_FD, p, n);
        if (w < 0 && errno == EINTR) continue;
        if (w <= 0) break;
        p += w; n -= w;
    }
    if (debug) fprintf(stderr, "isim-webkit -> %.2000s", o->str);
    g_string_free(o, TRUE);
}
#define SEND(v, ev, ...) sendv(v, ev, __VA_ARGS__, NULL)
static char *itoa_(long v) { static char b[8][32]; static int i; i = (i + 1) & 7; snprintf(b[i], 32, "%ld", v); return b[i]; }
static char *ftoa_(double v) { static char b[8][G_ASCII_DTOSTR_BUF_SIZE]; static int i; i = (i + 1) & 7; return g_ascii_formatd(b[i], sizeof b[i], "%.6g", v); }

/* the inside of a JSON string literal (UTF-8 kept; quotes, backslashes and controls escaped); g_free it */
static char *json_esc(const char *s) {
    GString *o = g_string_new(NULL);
    for (const unsigned char *p = (const unsigned char *)(s ? s : ""); *p; p++) {
        if (*p == '"' || *p == '\\') { g_string_append_c(o, '\\'); g_string_append_c(o, *p); }
        else if (*p < 0x20) g_string_append_printf(o, "\\u%04x", *p);
        else g_string_append_c(o, *p);
    }
    return g_string_free(o, FALSE);
}

/* ---------------- views ---------------- */
struct view {
    int id;
    WebKitWebView *wv;
    GtkWidget *win;
    WebKitUserContentManager *ucm;
    double w, h, scale, zoom;
    int pw, ph;                      /* frame pixel size */
    int memfd; unsigned char *mem; size_t memsize;
    unsigned char *last;             /* previous frame, to skip unchanged ones */
    int awaiting_ack, snapping, closed;
    long seq;
    gint64 hot_until;                /* snapshot quickly until then (after activity) */
    gint64 next_snap;
    GHashTable *pending;             /* request id -> WebKitPolicyDecision / WebKitScriptDialog / reply (by kind) */
    int next_req;
    int policy_cancelled;            /* the last navigation was cancelled by the app's policy: hide its error */
    GHashTable *alt_html;            /* URL -> HTML loaded with loadHTMLString(_:baseURL:) (back/forward re-shows it, like iOS) */
    char *bf_alt;                    /* a back/forward navigation to such a URL is under way */
    int alt_reloading;               /* re-showing it: the guest already saw "started" */
    int skip_finish;                 /* the replaced load's "finished" is not reported */
};
static GHashTable *views;            /* id -> struct view */
static WebKitNetworkSession *persistent, *ephemeral;
static char *persistent_dir;
static GHashTable *schemes;          /* registered custom URL schemes */
static GHashTable *scheme_reqs;      /* request id -> WebKitURISchemeRequest */
static int next_scheme_req = 1;

enum { P_POLICY = 1, P_DIALOG, P_REPLY };
struct pend { int kind; gpointer obj; };

static struct view *view_get(int id) { return views ? g_hash_table_lookup(views, GINT_TO_POINTER(id)) : NULL; }
static void hot(struct view *v) { if (v) v->hot_until = g_get_monotonic_time() + 1500000; }

static int pend_add(struct view *v, int kind, gpointer obj) {
    struct pend *p = g_new0(struct pend, 1); p->kind = kind; p->obj = obj;
    int id = ++v->next_req;
    g_hash_table_insert(v->pending, GINT_TO_POINTER(id), p);
    return id;
}
static struct pend *pend_take(struct view *v, int id) {
    struct pend *p = g_hash_table_lookup(v->pending, GINT_TO_POINTER(id));
    if (p) g_hash_table_steal(v->pending, GINT_TO_POINTER(id));
    return p;
}

/* ---------------- frames ---------------- */
static void frame_buffer(struct view *v) {
    size_t need = (size_t)v->pw * v->ph * 4;
    if (v->mem && v->memsize == need) return;
    if (v->mem) { munmap(v->mem, v->memsize); close(v->memfd); g_free(v->last); }
    v->memfd = memfd_create("isim-webkit-frame", 0);
    if (v->memfd < 0 || ftruncate(v->memfd, need) != 0) { v->mem = NULL; return; }
    v->mem = mmap(NULL, need, PROT_READ | PROT_WRITE, MAP_SHARED, v->memfd, 0);
    if (v->mem == MAP_FAILED) v->mem = NULL;
    v->memsize = need;
    v->last = g_malloc0(need);
    v->awaiting_ack = 0;
}
static void snap_done(GObject *o, GAsyncResult *r, gpointer data) {
    int id = GPOINTER_TO_INT(data);
    struct view *v = view_get(id);
    GError *e = NULL;
    GdkTexture *t = webkit_web_view_get_snapshot_finish(WEBKIT_WEB_VIEW(o), r, &e);
    if (!v) { if (t) g_object_unref(t); g_clear_error(&e); return; }
    v->snapping = 0;
    if (!t) { if (debug) fprintf(stderr, "isim-webkit: snapshot failed: %s\n", e ? e->message : "?"); g_clear_error(&e); return; }
    int tw = gdk_texture_get_width(t), th = gdk_texture_get_height(t);
    frame_buffer(v);
    if (v->mem && tw > 0 && th > 0) {
        int w = MIN(tw, v->pw), h = MIN(th, v->ph);
        unsigned char *tmp = g_malloc((size_t)tw * th * 4);
        gdk_texture_download(t, tmp, (size_t)tw * 4);        /* GDK_MEMORY_DEFAULT: premultiplied BGRA = cairo ARGB32 */
        /* the frame buffer is pw x ph; what the snapshot does not cover stays transparent */
        unsigned char *next = g_malloc0(v->memsize);
        for (int y = 0; y < h; y++) memcpy(next + (size_t)y * v->pw * 4, tmp + (size_t)y * tw * 4, (size_t)w * 4);
        g_free(tmp);
        if (memcmp(next, v->last, v->memsize) != 0 || v->seq == 0) {
            memcpy(v->mem, next, v->memsize);
            memcpy(v->last, next, v->memsize);
            v->seq++;
            v->awaiting_ack = 1;
            char path[64]; snprintf(path, sizeof path, "/proc/%d/fd/%d", getpid(), v->memfd);
            SEND(v->id, "frame", itoa_(v->seq), itoa_(v->pw), itoa_(v->ph), path);
        }
        g_free(next);
    }
    g_object_unref(t);
}
static gboolean tick(gpointer unused) {
    if (!views) return G_SOURCE_CONTINUE;
    gint64 now = g_get_monotonic_time();
    GHashTableIter it; gpointer k, val;
    g_hash_table_iter_init(&it, views);
    while (g_hash_table_iter_next(&it, &k, &val)) {
        struct view *v = val;
        if (v->closed || v->snapping || v->awaiting_ack || now < v->next_snap) continue;
        v->next_snap = now + (now < v->hot_until ? 33000 : 250000);
        v->snapping = 1;
        webkit_web_view_get_snapshot(v->wv, WEBKIT_SNAPSHOT_REGION_VISIBLE, WEBKIT_SNAPSHOT_OPTIONS_NONE, NULL, snap_done, GINT_TO_POINTER(v->id));
    }
    return G_SOURCE_CONTINUE;
}

/* ---------------- JSON of JS values ---------------- */
/* "undefined", or JSON text; NULL with *unsupported for values iOS cannot convert (functions, symbols) */
static char *value_json(JSCValue *val, int *unsupported) {
    *unsupported = 0;
    if (!val || jsc_value_is_undefined(val)) return g_strdup("undefined");
    if (jsc_value_is_function(val)) { *unsupported = 1; return NULL; }
    char *j = jsc_value_to_json(val, 0);
    if (!j) { *unsupported = 1; return NULL; }
    return j;
}

/* ---------------- errors (as iOS reports them) ---------------- */
static void error_fields(GError *e, const char **domain, long *code) {
    *domain = "NSURLErrorDomain"; *code = -1;
    if (!e) return;
    if (e->domain == WEBKIT_NETWORK_ERROR) {
        if (e->code == WEBKIT_NETWORK_ERROR_CANCELLED) *code = -999;
        else if (e->code == WEBKIT_NETWORK_ERROR_FILE_DOES_NOT_EXIST) *code = -1100;
        else if (e->code == WEBKIT_NETWORK_ERROR_UNKNOWN_PROTOCOL) *code = -1002;
        else *code = -1;
    } else if (e->domain == WEBKIT_POLICY_ERROR) {
        *domain = "WebKitErrorDomain"; *code = e->code == WEBKIT_POLICY_ERROR_FRAME_LOAD_INTERRUPTED_BY_POLICY_CHANGE ? 102 : 101;
    } else if (e->domain == G_RESOLVER_ERROR) *code = -1003;
    else if (e->domain == G_IO_ERROR) {
        switch (e->code) {
        case G_IO_ERROR_CONNECTION_REFUSED: *code = -1004; break;
        case G_IO_ERROR_TIMED_OUT: *code = -1001; break;
        case G_IO_ERROR_NETWORK_UNREACHABLE: case G_IO_ERROR_HOST_UNREACHABLE: *code = -1009; break;
        case G_IO_ERROR_CANCELLED: *code = -999; break;
        case G_IO_ERROR_BROKEN_PIPE: *code = -1005; break;
        default: *code = -1; break;
        }
    } else if (e->domain == G_TLS_ERROR) *code = -1200;
}

/* ---------------- signal handlers ---------------- */
static void finished_title(GObject *o, GAsyncResult *r, gpointer data) {
    JSCValue *val = webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(o), r, NULL);
    struct view *v = view_get(GPOINTER_TO_INT(data));
    if (v) {
        char *t = val && jsc_value_is_string(val) ? jsc_value_to_string(val) : NULL;
        if (t && *t) SEND(v->id, "title", t);
        g_free(t);
        SEND(v->id, "load", "finished", webkit_web_view_get_uri(v->wv) ?: "");
        hot(v);
    }
    if (val) g_object_unref(val);
}
static void on_load(WebKitWebView *wv, WebKitLoadEvent ev, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return;
    const char *names[] = { "started", "redirected", "committed", "finished" };
    if (ev == WEBKIT_LOAD_STARTED) { v->policy_cancelled = 0; if (v->alt_reloading) { v->alt_reloading = 0; hot(v); return; } }
    if (ev == WEBKIT_LOAD_FINISHED && v->skip_finish) { v->skip_finish = 0; return; }
    if (ev == WEBKIT_LOAD_FINISHED) {   /* iOS has the title before didFinish: read it from the document first */
        webkit_web_view_evaluate_javascript(wv, "document.title", -1, "isim", NULL, NULL, finished_title, GINT_TO_POINTER(v->id));
        return;
    }
    SEND(v->id, "load", names[ev], webkit_web_view_get_uri(wv) ?: "");
    hot(v);
}
static gboolean on_load_failed(WebKitWebView *wv, WebKitLoadEvent ev, const char *uri, GError *e, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return TRUE;
    if (v->bf_alt && uri && !strcmp(uri, v->bf_alt)) {    /* back/forward to a loadHTMLString page: show its HTML again */
        const char *html = g_hash_table_lookup(v->alt_html, v->bf_alt);
        char *u = v->bf_alt; v->bf_alt = NULL;
        if (html) { v->alt_reloading = 1; v->skip_finish = 1; webkit_web_view_load_alternate_html(wv, html, u, u); g_free(u); return TRUE; }
        g_free(u);
    }
    const char *domain; long code; error_fields(e, &domain, &code);
    if (v->policy_cancelled && !strcmp(domain, "WebKitErrorDomain")) return TRUE;
    SEND(v->id, "fail", ev == WEBKIT_LOAD_COMMITTED ? "0" : "1", domain, itoa_(code), e ? e->message : "", uri ?: "");
    hot(v);
    return TRUE;
}
static gboolean on_tls_failed(WebKitWebView *wv, const char *uri, GTlsCertificate *cert, GTlsCertificateFlags errs, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return TRUE;
    SEND(v->id, "fail", "1", "NSURLErrorDomain", "-1202", "The certificate for this server is invalid.", uri ?: "");
    return TRUE;
}
static void bf_changed(struct view *v) {
    WebKitBackForwardList *l = webkit_web_view_get_back_forward_list(v->wv);
    GString *j = g_string_new("{\"back\":[");
    GList *back = webkit_back_forward_list_get_back_list(l), *fwd = webkit_back_forward_list_get_forward_list(l);
    /* back list: nearest first in WebKitGTK; iOS lists oldest first */
    back = g_list_reverse(back);
    int first = 1;
    for (GList *i = back; i; i = i->next) {
        WebKitBackForwardListItem *it = i->data;
        JSCContext *ctx = NULL; (void)ctx;
        char *u = json_esc(webkit_back_forward_list_item_get_uri(it) ?: ""), *t = json_esc(webkit_back_forward_list_item_get_title(it) ?: ""),
             *o = json_esc(webkit_back_forward_list_item_get_original_uri(it) ?: "");
        g_string_append_printf(j, "%s[\"%s\",\"%s\",\"%s\"]", first ? "" : ",", u, t, o); first = 0;
        g_free(u); g_free(t); g_free(o);
    }
    g_string_append(j, "],\"forward\":[");
    first = 1;
    for (GList *i = fwd; i; i = i->next) {
        WebKitBackForwardListItem *it = i->data;
        char *u = json_esc(webkit_back_forward_list_item_get_uri(it) ?: ""), *t = json_esc(webkit_back_forward_list_item_get_title(it) ?: ""),
             *o = json_esc(webkit_back_forward_list_item_get_original_uri(it) ?: "");
        g_string_append_printf(j, "%s[\"%s\",\"%s\",\"%s\"]", first ? "" : ",", u, t, o); first = 0;
        g_free(u); g_free(t); g_free(o);
    }
    WebKitBackForwardListItem *cur = webkit_back_forward_list_get_current_item(l);
    if (cur) {
        char *u = json_esc(webkit_back_forward_list_item_get_uri(cur) ?: ""), *t = json_esc(webkit_back_forward_list_item_get_title(cur) ?: ""),
             *o = json_esc(webkit_back_forward_list_item_get_original_uri(cur) ?: "");
        g_string_append_printf(j, "],\"current\":[\"%s\",\"%s\",\"%s\"]}", u, t, o);
        g_free(u); g_free(t); g_free(o);
    } else g_string_append(j, "]}");
    g_list_free(back); g_list_free(fwd);
    SEND(v->id, "bf", webkit_web_view_can_go_back(v->wv) ? "1" : "0", webkit_web_view_can_go_forward(v->wv) ? "1" : "0", j->str);
    g_string_free(j, TRUE);
}
static void on_bf(WebKitBackForwardList *l, WebKitBackForwardListItem *added, gpointer removed, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (v) bf_changed(v);
}
static void on_notify(GObject *o, GParamSpec *p, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return;
    WebKitWebView *wv = v->wv;
    const char *n = p->name;
    if (!strcmp(n, "title")) SEND(v->id, "title", webkit_web_view_get_title(wv) ?: "");
    else if (!strcmp(n, "uri")) SEND(v->id, "url", webkit_web_view_get_uri(wv) ?: "");
    else if (!strcmp(n, "estimated-load-progress")) SEND(v->id, "progress", ftoa_(webkit_web_view_get_estimated_load_progress(wv)));
    else if (!strcmp(n, "is-loading")) SEND(v->id, "loading", webkit_web_view_is_loading(wv) ? "1" : "0");
    hot(v);
}
static char *request_json(WebKitURIRequest *rq) {
    GString *j = g_string_new("{");
    char *u = json_esc(webkit_uri_request_get_uri(rq) ?: "");
    char *m = json_esc(webkit_uri_request_get_http_method(rq) ?: "GET");
    g_string_append_printf(j, "\"url\":\"%s\",\"method\":\"%s\",\"headers\":{", u, m);
    g_free(u); g_free(m);
    SoupMessageHeaders *h = webkit_uri_request_get_http_headers(rq);
    if (h) {
        SoupMessageHeadersIter it; const char *name, *value; int first = 1;
        soup_message_headers_iter_init(&it, h);
        while (soup_message_headers_iter_next(&it, &name, &value)) {
            char *a = json_esc(name), *b = json_esc(value);
            g_string_append_printf(j, "%s\"%s\":\"%s\"", first ? "" : ",", a, b); first = 0;
            g_free(a); g_free(b);
        }
    }
    g_string_append(j, "}}");
    return g_string_free(j, FALSE);
}
static gboolean on_policy(WebKitWebView *wv, WebKitPolicyDecision *d, WebKitPolicyDecisionType type, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return FALSE;
    GString *j = g_string_new(NULL);
    const char *kind;
    if (type == WEBKIT_POLICY_DECISION_TYPE_RESPONSE) {
        WebKitResponsePolicyDecision *r = WEBKIT_RESPONSE_POLICY_DECISION(d);
        WebKitURIResponse *resp = webkit_response_policy_decision_get_response(r);
        if (v->bf_alt && webkit_response_policy_decision_is_main_frame_main_resource(r) && !g_strcmp0(webkit_uri_response_get_uri(resp), v->bf_alt)) {
            webkit_policy_decision_ignore(d);          /* the load fails; on_load_failed re-shows the app's HTML */
            g_string_free(j, TRUE);
            return TRUE;
        }
        char *rq = request_json(webkit_response_policy_decision_get_request(r));
        char *u = json_esc(webkit_uri_response_get_uri(resp) ?: ""), *mime = json_esc(webkit_uri_response_get_mime_type(resp) ?: "");
        g_string_append_printf(j, "{\"request\":%s,\"url\":\"%s\",\"status\":%u,\"mime\":\"%s\",\"length\":%" G_GUINT64_FORMAT ",\"canShow\":%s,\"mainFrame\":%s,\"headers\":{",
                               rq, u, webkit_uri_response_get_status_code(resp), mime, webkit_uri_response_get_content_length(resp),
                               webkit_response_policy_decision_is_mime_type_supported(r) ? "true" : "false",
                               webkit_response_policy_decision_is_main_frame_main_resource(r) ? "true" : "false");
        SoupMessageHeaders *h = webkit_uri_response_get_http_headers(resp);
        if (h) {
            SoupMessageHeadersIter it; const char *name, *value; int first = 1;
            soup_message_headers_iter_init(&it, h);
            while (soup_message_headers_iter_next(&it, &name, &value)) {
                char *a = json_esc(name), *b = json_esc(value);
                g_string_append_printf(j, "%s\"%s\":\"%s\"", first ? "" : ",", a, b); first = 0;
                g_free(a); g_free(b);
            }
        }
        g_string_append(j, "}}");
        g_free(rq); g_free(u); g_free(mime);
        kind = "response";
    } else {
        WebKitNavigationAction *a = webkit_navigation_policy_decision_get_navigation_action(WEBKIT_NAVIGATION_POLICY_DECISION(d));
        const char *target = webkit_uri_request_get_uri(webkit_navigation_action_get_request(a));
        g_free(v->bf_alt); v->bf_alt = NULL;
        if (type == WEBKIT_POLICY_DECISION_TYPE_NAVIGATION_ACTION && webkit_navigation_action_get_navigation_type(a) == WEBKIT_NAVIGATION_TYPE_BACK_FORWARD
            && target && g_hash_table_contains(v->alt_html, target)) v->bf_alt = g_strdup(target);
        char *rq = request_json(webkit_navigation_action_get_request(a));
        const char *frame = webkit_navigation_action_get_frame_name(a);
        char *fn = json_esc(frame ?: "");
        g_string_append_printf(j, "{\"request\":%s,\"type\":%d,\"button\":%u,\"modifiers\":%u,\"userGesture\":%s,\"redirect\":%s,\"frameName\":\"%s\"}",
                               rq, webkit_navigation_action_get_navigation_type(a), webkit_navigation_action_get_mouse_button(a),
                               webkit_navigation_action_get_modifiers(a), webkit_navigation_action_is_user_gesture(a) ? "true" : "false",
                               webkit_navigation_action_is_redirect(a) ? "true" : "false", fn);
        g_free(rq); g_free(fn);
        kind = type == WEBKIT_POLICY_DECISION_TYPE_NEW_WINDOW_ACTION ? "newwindow" : "action";
    }
    g_object_ref(d);
    int req = pend_add(v, P_POLICY, d);
    SEND(v->id, "policy", itoa_(req), kind, j->str);
    g_string_free(j, TRUE);
    return TRUE;
}
static GtkWidget *on_create(WebKitWebView *wv, WebKitNavigationAction *a, gpointer data) {
    /* window.open / target=_blank: the app's WKUIDelegate decides (createWebViewWith...); no new engine view here */
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return NULL;
    char *rq = request_json(webkit_navigation_action_get_request(a));
    SEND(v->id, "create", rq);
    g_free(rq);
    return NULL;
}
static void on_close(WebKitWebView *wv, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (v) SEND(v->id, "closed", "");
}
static gboolean on_dialog(WebKitWebView *wv, WebKitScriptDialog *d, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return FALSE;
    const char *types[] = { "alert", "confirm", "prompt", "beforeunload" };
    webkit_script_dialog_ref(d);
    int req = pend_add(v, P_DIALOG, d);
    WebKitScriptDialogType t = webkit_script_dialog_get_dialog_type(d);
    SEND(v->id, "dialog", itoa_(req), types[t], webkit_script_dialog_get_message(d) ?: "",
         t == WEBKIT_SCRIPT_DIALOG_PROMPT ? webkit_script_dialog_prompt_get_default_text(d) ?: "" : "", webkit_web_view_get_uri(wv) ?: "");
    return TRUE;
}
static void on_crash(WebKitWebView *wv, WebKitWebProcessTerminationReason r, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (v) SEND(v->id, "terminated", itoa_(r));
}
/* messages from the private "isim" world: scroll position, focus */
static void on_isim_message(WebKitUserContentManager *m, JSCValue *val, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(data)); if (!v) return;
    int un; char *j = value_json(val, &un);
    if (j) SEND(v->id, "page", j);
    g_free(j);
    hot(v);
}
static void on_message(WebKitUserContentManager *m, JSCValue *val, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(g_object_get_data(G_OBJECT(m), "isim-view")));
    if (!v) return;
    int un; char *j = value_json(val, &un);
    SEND(v->id, "message", "0", (const char *)data, j ?: "null");
    g_free(j);
    hot(v);
}
static gboolean on_message_reply(WebKitUserContentManager *m, JSCValue *val, WebKitScriptMessageReply *reply, gpointer data) {
    struct view *v = view_get(GPOINTER_TO_INT(g_object_get_data(G_OBJECT(m), "isim-view")));
    if (!v) return FALSE;
    int un; char *j = value_json(val, &un);
    webkit_script_message_reply_ref(reply);
    int req = pend_add(v, P_REPLY, reply);
    SEND(v->id, "message", itoa_(req), (const char *)data, j ?: "null");
    g_free(j);
    hot(v);
    return TRUE;
}

/* custom URL schemes (WKURLSchemeHandler): requests go to the app, the response comes back whole */
struct scheme_req { WebKitURISchemeRequest *rq; int view; int status; char *mime; char *headers; GByteArray *body; };
static void on_scheme(WebKitURISchemeRequest *rq, gpointer data) {
    WebKitWebView *wv = webkit_uri_scheme_request_get_web_view(rq);
    int vid = wv ? GPOINTER_TO_INT(g_object_get_data(G_OBJECT(wv), "isim-view")) : 0;
    struct scheme_req *s = g_new0(struct scheme_req, 1);
    s->rq = g_object_ref(rq); s->view = vid; s->status = 200; s->body = g_byte_array_new();
    int id = next_scheme_req++;
    g_hash_table_insert(scheme_reqs, GINT_TO_POINTER(id), s);
    GString *j = g_string_new("{");
    char *u = json_esc(webkit_uri_scheme_request_get_uri(rq) ?: ""), *m = json_esc(webkit_uri_scheme_request_get_http_method(rq) ?: "GET");
    g_string_append_printf(j, "\"url\":\"%s\",\"method\":\"%s\",\"headers\":{", u, m);
    g_free(u); g_free(m);
    SoupMessageHeaders *h = webkit_uri_scheme_request_get_http_headers(rq);
    if (h) {
        SoupMessageHeadersIter it; const char *name, *value; int first = 1;
        soup_message_headers_iter_init(&it, h);
        while (soup_message_headers_iter_next(&it, &name, &value)) {
            char *a = json_esc(name), *b = json_esc(value);
            g_string_append_printf(j, "%s\"%s\":\"%s\"", first ? "" : ",", a, b); first = 0;
            g_free(a); g_free(b);
        }
    }
    g_string_append(j, "}}");
    SEND(vid, "scheme", itoa_(id), j->str);
    g_string_free(j, TRUE);
}

/* ---------------- view lifecycle ---------------- */
static const char *isim_world_script =
    "(function(){if(window.__isimInstalled)return;window.__isimInstalled=true;"
    "var post=function(o){try{window.webkit.messageHandlers.__isim.postMessage(o)}catch(e){}};"
    "var queued=false;function sc(){if(queued)return;queued=true;requestAnimationFrame(function(){queued=false;"
    "var d=document.documentElement,b=document.body;"
    "post({t:'scroll',x:window.scrollX,y:window.scrollY,w:Math.max(d?d.scrollWidth:0,b?b.scrollWidth:0),h:Math.max(d?d.scrollHeight:0,b?b.scrollHeight:0),vw:window.innerWidth,vh:window.innerHeight})})}"
    "window.addEventListener('scroll',sc,{passive:true});window.addEventListener('resize',sc);window.addEventListener('load',sc);"
    "document.addEventListener('DOMContentLoaded',sc);"
    "function ed(e){if(!e)return false;if(e.isContentEditable)return true;var t=(e.tagName||'').toLowerCase();"
    "if(t==='textarea')return !e.readOnly&&!e.disabled;if(t!=='input')return false;"
    "var ty=(e.type||'text').toLowerCase();return ['text','search','email','url','tel','password','number',''].indexOf(ty)>=0&&!e.readOnly&&!e.disabled}"
    "function fc(){var a=document.activeElement;post({t:'focus',editable:ed(a),type:a&&a.type||'',kind:a&&a.getAttribute&&(a.getAttribute('inputmode')||'')||''})}"
    "document.addEventListener('focusin',fc,true);document.addEventListener('focusout',function(){setTimeout(fc,0)},true);"
    "if(typeof ResizeObserver!=='undefined'){var ro=new ResizeObserver(sc);document.addEventListener('DOMContentLoaded',function(){ro.observe(document.documentElement)})}"
    "window.__isimEd=ed;"
    "})();";

static void view_new(int id, double w, double h, double scale, int ephem, const char *datadir, const char *ua, int js, const char *bg) {
    if (view_get(id)) return;
    WebKitNetworkSession *ns;
    if (ephem) { if (!ephemeral) ephemeral = webkit_network_session_new_ephemeral(); ns = ephemeral; }
    else {
        if (!persistent) {
            persistent_dir = g_strdup(datadir && *datadir ? datadir : g_get_tmp_dir());
            char *data = g_build_filename(persistent_dir, "WebsiteData", NULL), *cache = g_build_filename(persistent_dir, "Caches", NULL);
            persistent = webkit_network_session_new(data, cache);
            WebKitCookieManager *cm = webkit_network_session_get_cookie_manager(persistent);
            char *cookies = g_build_filename(persistent_dir, "Cookies.sqlite", NULL);
            webkit_cookie_manager_set_persistent_storage(cm, cookies, WEBKIT_COOKIE_PERSISTENT_STORAGE_SQLITE);
            g_free(data); g_free(cache); g_free(cookies);
        }
        ns = persistent;
    }
    struct view *v = g_new0(struct view, 1);
    v->id = id; v->w = w; v->h = h; v->scale = scale; v->zoom = 1;
    v->pending = g_hash_table_new_full(g_direct_hash, g_direct_equal, NULL, g_free);
    v->alt_html = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, g_free);
    v->ucm = webkit_user_content_manager_new();
    g_object_set_data(G_OBJECT(v->ucm), "isim-view", GINT_TO_POINTER(id));
    WebKitSettings *st = webkit_settings_new();
    webkit_settings_set_enable_javascript(st, js);
    webkit_settings_set_enable_page_cache(st, TRUE);
    webkit_settings_set_allow_file_access_from_file_urls(st, TRUE);
    webkit_settings_set_javascript_can_open_windows_automatically(st, FALSE);
    webkit_settings_set_enable_developer_extras(st, FALSE);
    webkit_settings_set_default_font_family(st, "sans-serif");
    webkit_settings_set_hardware_acceleration_policy(st, WEBKIT_HARDWARE_ACCELERATION_POLICY_NEVER);
    if (ua && *ua) webkit_settings_set_user_agent(st, ua);
    v->wv = WEBKIT_WEB_VIEW(g_object_new(WEBKIT_TYPE_WEB_VIEW, "network-session", ns, "user-content-manager", v->ucm, "settings", st, NULL));
    g_object_unref(st);
    g_object_set_data(G_OBJECT(v->wv), "isim-view", GINT_TO_POINTER(id));
    if (bg && *bg) { GdkRGBA c; if (gdk_rgba_parse(&c, bg)) webkit_web_view_set_background_color(v->wv, &c); }
    /* the private world: scroll/focus reports */
    webkit_user_content_manager_register_script_message_handler(v->ucm, "__isim", "isim");
    g_signal_connect(v->ucm, "script-message-received::__isim", G_CALLBACK(on_isim_message), GINT_TO_POINTER(id));
    WebKitUserScript *us = webkit_user_script_new_for_world(isim_world_script, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                                                            WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, "isim", NULL, NULL);
    webkit_user_content_manager_add_script(v->ucm, us);
    webkit_user_script_unref(us);

    g_signal_connect(v->wv, "load-changed", G_CALLBACK(on_load), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "load-failed", G_CALLBACK(on_load_failed), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "load-failed-with-tls-errors", G_CALLBACK(on_tls_failed), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "notify::title", G_CALLBACK(on_notify), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "notify::uri", G_CALLBACK(on_notify), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "notify::estimated-load-progress", G_CALLBACK(on_notify), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "notify::is-loading", G_CALLBACK(on_notify), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "decide-policy", G_CALLBACK(on_policy), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "create", G_CALLBACK(on_create), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "close", G_CALLBACK(on_close), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "script-dialog", G_CALLBACK(on_dialog), GINT_TO_POINTER(id));
    g_signal_connect(v->wv, "web-process-terminated", G_CALLBACK(on_crash), GINT_TO_POINTER(id));
    g_signal_connect(webkit_web_view_get_back_forward_list(v->wv), "changed", G_CALLBACK(on_bf), GINT_TO_POINTER(id));

    /* an undecorated window on the private display; the view gets its full pixel size inside a scrolled
       window so the display's screen size does not limit it */
    v->win = gtk_window_new();
    gtk_window_set_decorated(GTK_WINDOW(v->win), FALSE);
    gtk_window_set_default_size(GTK_WINDOW(v->win), 64, 64);
    GtkWidget *sw = gtk_scrolled_window_new(), *fx = gtk_fixed_new();
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(sw), GTK_POLICY_EXTERNAL, GTK_POLICY_EXTERNAL);
    gtk_fixed_put(GTK_FIXED(fx), GTK_WIDGET(v->wv), 0, 0);
    gtk_scrolled_window_set_child(GTK_SCROLLED_WINDOW(sw), fx);
    gtk_window_set_child(GTK_WINDOW(v->win), sw);
    v->pw = (int)(w * scale + 0.5); v->ph = (int)(h * scale + 0.5);
    gtk_widget_set_size_request(GTK_WIDGET(v->wv), MAX(1, v->pw), MAX(1, v->ph));
    webkit_web_view_set_zoom_level(v->wv, scale * v->zoom);
    gtk_window_present(GTK_WINDOW(v->win));
    g_hash_table_insert(views, GINT_TO_POINTER(id), v);
    hot(v);
    SEND(id, "ready", "");
}
static void view_resize(struct view *v, double w, double h, double scale) {
    v->w = w; v->h = h; v->scale = scale;
    v->pw = (int)(w * scale + 0.5); v->ph = (int)(h * scale + 0.5);
    gtk_widget_set_size_request(GTK_WIDGET(v->wv), MAX(1, v->pw), MAX(1, v->ph));
    webkit_web_view_set_zoom_level(v->wv, scale * v->zoom);
    v->awaiting_ack = 0; v->next_snap = 0;
    hot(v);
}
static void view_close(struct view *v) {
    v->closed = 1;
    g_hash_table_steal(views, GINT_TO_POINTER(v->id));
    /* answer anything still waiting so the web process is not left hanging */
    GHashTableIter it; gpointer k, val;
    g_hash_table_iter_init(&it, v->pending);
    while (g_hash_table_iter_next(&it, &k, &val)) {
        struct pend *p = val;
        if (p->kind == P_POLICY) { webkit_policy_decision_ignore(p->obj); g_object_unref(p->obj); }
        else if (p->kind == P_DIALOG) { webkit_script_dialog_close(p->obj); webkit_script_dialog_unref(p->obj); }
        else { webkit_script_message_reply_return_error_message(p->obj, "web view closed"); webkit_script_message_reply_unref(p->obj); }
    }
    g_hash_table_destroy(v->pending);
    g_hash_table_destroy(v->alt_html); g_free(v->bf_alt);
    gtk_window_destroy(GTK_WINDOW(v->win));
    if (v->mem) { munmap(v->mem, v->memsize); close(v->memfd); }
    g_free(v->last);
    g_free(v);
}

/* ---------------- JavaScript ---------------- */
struct jsreq { int view; int req; };
static void js_done(GObject *o, GAsyncResult *r, gpointer data) {
    struct jsreq *q = data;
    GError *e = NULL;
    JSCValue *val = q->req < 0 ? webkit_web_view_call_async_javascript_function_finish(WEBKIT_WEB_VIEW(o), r, &e)
                               : webkit_web_view_evaluate_javascript_finish(WEBKIT_WEB_VIEW(o), r, &e);
    int req = q->req < 0 ? -q->req : q->req;
    if (!view_get(q->view)) { g_free(q); g_clear_error(&e); if (val) g_object_unref(val); return; }
    if (!val) {
        SEND(q->view, "js", itoa_(req), "error", e ? e->message : "JavaScript exception");
    } else {
        int un; char *j = value_json(val, &un);
        if (un) SEND(q->view, "js", itoa_(req), "unsupported", "JavaScript execution returned a result of an unsupported type");
        else SEND(q->view, "js", itoa_(req), "ok", j);
        g_free(j);
        g_object_unref(val);
    }
    g_clear_error(&e);
    hot(view_get(q->view));
    g_free(q);
}
static void run_js(struct view *v, int req, const char *world, const char *script, int async_fn) {
    struct jsreq *q = g_new0(struct jsreq, 1); q->view = v->id; q->req = async_fn ? -req : req;
    const char *w = world && *world ? world : NULL;
    if (async_fn) webkit_web_view_call_async_javascript_function(v->wv, script, -1, NULL, w, NULL, NULL, js_done, q);
    else webkit_web_view_evaluate_javascript(v->wv, script, -1, w, NULL, NULL, js_done, q);
    hot(v);
}
/* input helpers run in the private world (not visible to page scripts) */
static void input_js(struct view *v, const char *script) {
    webkit_web_view_evaluate_javascript(v->wv, script, -1, "isim", NULL, NULL, NULL, NULL);
    hot(v);
}
static char *js_string(const char *s) {   /* a JS string literal */
    GString *o = g_string_new("\"");
    for (const unsigned char *p = (const unsigned char *)s; *p; p++) {
        if (*p == '"' || *p == '\\') { g_string_append_c(o, '\\'); g_string_append_c(o, *p); }
        else if (*p < 0x20) g_string_append_printf(o, "\\u%04x", *p);
        else g_string_append_c(o, *p);
    }
    g_string_append_c(o, '"');
    return g_string_free(o, FALSE);
}
static const char *tap_js =
    "(function(x,y,phase){var e=document.elementFromPoint(x,y);if(!e)return;"
    "var o={clientX:x,clientY:y,screenX:x,screenY:y,bubbles:true,cancelable:true,composed:true,view:window,button:0,buttons:phase==='up'?0:1,pointerType:'touch',isPrimary:true,pointerId:1};"
    "var fire=function(t,C){try{return e.dispatchEvent(new C(t,o))}catch(_){return true}};"
    "if(phase==='down'){window.__isimDown=e;fire('pointerdown',PointerEvent);"
    "try{var tch=new Touch({identifier:1,target:e,clientX:x,clientY:y,pageX:x+scrollX,pageY:y+scrollY});"
    "e.dispatchEvent(new TouchEvent('touchstart',{bubbles:true,cancelable:true,composed:true,touches:[tch],targetTouches:[tch],changedTouches:[tch]}))}catch(_){}"
    "fire('mousedown',MouseEvent);return}"
    "if(phase==='cancel'){fire('pointercancel',PointerEvent);window.__isimDown=null;return}"
    "fire('pointerup',PointerEvent);"
    "try{var t2=new Touch({identifier:1,target:e,clientX:x,clientY:y,pageX:x+scrollX,pageY:y+scrollY});"
    "e.dispatchEvent(new TouchEvent('touchend',{bubbles:true,cancelable:true,composed:true,touches:[],targetTouches:[],changedTouches:[t2]}))}catch(_){}"
    "fire('mouseup',MouseEvent);"
    "var f=e.closest&&e.closest('input,textarea,select,button,a[href],[contenteditable=\"\"],[contenteditable=true],[tabindex]');"
    "if(f&&f.focus){f.focus();if(window.__isimEd&&window.__isimEd(f)&&f.setSelectionRange){try{var n=f.value.length;f.setSelectionRange(n,n)}catch(_){}}}"
    "else if(document.activeElement&&document.activeElement!==document.body&&document.activeElement.blur)document.activeElement.blur();"
    "if(e.click)e.click();else fire('click',MouseEvent);window.__isimDown=null})";
static const char *scroll_js =
    "(function(x,y,dx,dy){var e=document.elementFromPoint(x,y);"
    "for(;e&&e!==document.body&&e!==document.documentElement;e=e.parentElement){var s=getComputedStyle(e);"
    "var oy=/(auto|scroll)/.test(s.overflowY),ox=/(auto|scroll)/.test(s.overflowX);"
    "if((oy&&dy&&e.scrollHeight>e.clientHeight&&((dy>0&&e.scrollTop+e.clientHeight<e.scrollHeight)||(dy<0&&e.scrollTop>0)))||"
    "(ox&&dx&&e.scrollWidth>e.clientWidth&&((dx>0&&e.scrollLeft+e.clientWidth<e.scrollWidth)||(dx<0&&e.scrollLeft>0)))){e.scrollBy(dx,dy);return}}"
    "window.scrollBy(dx,dy)})";
static const char *text_js =
    "(function(s){var a=document.activeElement;if(!a)return;var k=function(t,key){try{return a.dispatchEvent(new KeyboardEvent(t,{key:key,bubbles:true,cancelable:true,composed:true}))}catch(_){return true}};"
    "for(var ch of s){if(k('keydown',ch)){k('keypress',ch);document.execCommand('insertText',false,ch)}k('keyup',ch)}})";
static const char *key_js =
    "(function(name){var a=document.activeElement||document.body;var key={backspace:'Backspace',enter:'Enter',tab:'Tab',escape:'Escape',left:'ArrowLeft',right:'ArrowRight',up:'ArrowUp',down:'ArrowDown'}[name]||name;"
    "var ok=true;try{ok=a.dispatchEvent(new KeyboardEvent('keydown',{key:key,code:key,bubbles:true,cancelable:true,composed:true}))}catch(_){}"
    "if(ok){if(key==='Backspace')document.execCommand('delete',false);"
    "else if(key==='Enter'){var t=(a.tagName||'').toLowerCase();if(t==='textarea'||a.isContentEditable)document.execCommand('insertLineBreak',false);"
    "else if(a.form){if(a.form.requestSubmit)a.form.requestSubmit();else a.form.submit()}}"
    "else if(key==='Tab'){}}"
    "try{a.dispatchEvent(new KeyboardEvent('keyup',{key:key,code:key,bubbles:true,cancelable:true,composed:true}))}catch(_){}})";

/* ---------------- cookies ---------------- */
static WebKitCookieManager *cookie_manager(struct view *v) {
    return webkit_network_session_get_cookie_manager(webkit_web_view_get_network_session(v->wv));
}
struct cookiereq { int view; int req; };
static void cookies_done(GObject *o, GAsyncResult *r, gpointer data) {
    struct cookiereq *q = data;
    GError *e = NULL;
    GList *list = webkit_cookie_manager_get_all_cookies_finish(WEBKIT_COOKIE_MANAGER(o), r, &e);
    GString *j = g_string_new("[");
    for (GList *i = list; i; i = i->next) {
        SoupCookie *c = i->data;
        char *n = json_esc(soup_cookie_get_name(c) ?: ""), *val = json_esc(soup_cookie_get_value(c) ?: ""),
             *d = json_esc(soup_cookie_get_domain(c) ?: ""), *p = json_esc(soup_cookie_get_path(c) ?: "/");
        GDateTime *ex = soup_cookie_get_expires(c);
        g_string_append_printf(j, "%s{\"name\":\"%s\",\"value\":\"%s\",\"domain\":\"%s\",\"path\":\"%s\",\"secure\":%s,\"httpOnly\":%s,\"expires\":%" G_GINT64_FORMAT "}",
                               i == list ? "" : ",", n, val, d, p, soup_cookie_get_secure(c) ? "true" : "false",
                               soup_cookie_get_http_only(c) ? "true" : "false", ex ? g_date_time_to_unix(ex) : (gint64)0);
        g_free(n); g_free(val); g_free(d); g_free(p);
    }
    g_string_append(j, "]");
    g_list_free_full(list, (GDestroyNotify)soup_cookie_free);
    SEND(q->view, "done", itoa_(q->req), j->str);
    g_string_free(j, TRUE);
    g_clear_error(&e);
    g_free(q);
}
static void cookie_op_done(GObject *o, GAsyncResult *r, gpointer data) {
    struct cookiereq *q = data;
    GError *e = NULL;
    if (q->req > 0) webkit_cookie_manager_add_cookie_finish(WEBKIT_COOKIE_MANAGER(o), r, &e);
    else webkit_cookie_manager_delete_cookie_finish(WEBKIT_COOKIE_MANAGER(o), r, &e);
    SEND(q->view, "done", itoa_(q->req > 0 ? q->req : -q->req), "");
    g_clear_error(&e);
    g_free(q);
}
static void clear_done(GObject *o, GAsyncResult *r, gpointer data) {
    struct cookiereq *q = data;
    webkit_website_data_manager_clear_finish(WEBKIT_WEBSITE_DATA_MANAGER(o), r, NULL);
    SEND(q->view, "done", itoa_(q->req), "");
    g_free(q);
}

/* ---------------- commands ---------------- */
static void cmd(char **f, int n) {
    if (n < 2) return;
    const char *c = f[0];
    int id = atoi(f[1]);
    struct view *v = view_get(id);
#define ARG(i) (n > (i) ? f[i] : "")
    if (!strcmp(c, "new")) { view_new(id, g_ascii_strtod(ARG(2), NULL), g_ascii_strtod(ARG(3), NULL), g_ascii_strtod(ARG(4), NULL), atoi(ARG(5)), ARG(6), ARG(7), atoi(ARG(8)), ARG(9)); return; }
    if (!strcmp(c, "scheme")) {           /* register a custom URL scheme (once per process) */
        const char *name = ARG(2);
        if (!g_hash_table_contains(schemes, name)) {
            g_hash_table_add(schemes, g_strdup(name));
            WebKitWebContext *ctx = webkit_web_context_get_default();
            webkit_web_context_register_uri_scheme(ctx, name, on_scheme, NULL, NULL);
            WebKitSecurityManager *sm = webkit_web_context_get_security_manager(ctx);
            webkit_security_manager_register_uri_scheme_as_secure(sm, name);
            webkit_security_manager_register_uri_scheme_as_cors_enabled(sm, name);
        }
        return;
    }
    if (!strcmp(c, "schemeresp") || !strcmp(c, "schemedata") || !strcmp(c, "schemedone") || !strcmp(c, "schemefail")) {
        int rid = atoi(ARG(2));
        struct scheme_req *s = g_hash_table_lookup(scheme_reqs, GINT_TO_POINTER(rid));
        if (!s) return;
        if (!strcmp(c, "schemeresp")) { s->status = atoi(ARG(3)); g_free(s->mime); s->mime = g_strdup(ARG(4)); g_free(s->headers); s->headers = g_strdup(ARG(5)); return; }
        if (!strcmp(c, "schemedata")) { gsize len; guchar *d = g_base64_decode(ARG(3), &len); g_byte_array_append(s->body, d, len); g_free(d); return; }
        g_hash_table_remove(scheme_reqs, GINT_TO_POINTER(rid));
        if (!strcmp(c, "schemefail")) {
            GError *e = g_error_new_literal(WEBKIT_NETWORK_ERROR, WEBKIT_NETWORK_ERROR_FAILED, *ARG(3) ? ARG(3) : "The operation couldn't be completed.");
            webkit_uri_scheme_request_finish_error(s->rq, e);
            g_error_free(e);
        } else {
            GBytes *b = g_byte_array_free_to_bytes(s->body); s->body = NULL;
            GInputStream *in = g_memory_input_stream_new_from_bytes(b);
            WebKitURISchemeResponse *r = webkit_uri_scheme_response_new(in, g_bytes_get_size(b));
            webkit_uri_scheme_response_set_status(r, s->status, NULL);
            if (s->mime && *s->mime) webkit_uri_scheme_response_set_content_type(r, s->mime);
            if (s->headers && *s->headers) {
                SoupMessageHeaders *h = soup_message_headers_new(SOUP_MESSAGE_HEADERS_RESPONSE);
                char **lines = g_strsplit(s->headers, "\n", -1);
                for (char **l = lines; *l; l++) { char *colon = strchr(*l, ':'); if (colon) { *colon = 0; soup_message_headers_append(h, g_strstrip(*l), g_strstrip(colon + 1)); } }
                g_strfreev(lines);
                webkit_uri_scheme_response_set_http_headers(r, h);
            }
            webkit_uri_scheme_request_finish_with_response(s->rq, r);
            g_object_unref(r); g_object_unref(in); g_bytes_unref(b);
        }
        g_object_unref(s->rq); g_free(s->mime); g_free(s->headers); if (s->body) g_byte_array_free(s->body, TRUE); g_free(s);
        return;
    }
    if (!v) return;
    hot(v);
    if (!strcmp(c, "close")) view_close(v);
    else if (!strcmp(c, "size")) view_resize(v, g_ascii_strtod(ARG(2), NULL), g_ascii_strtod(ARG(3), NULL), g_ascii_strtod(ARG(4), NULL));
    else if (!strcmp(c, "ack")) v->awaiting_ack = 0;
    else if (!strcmp(c, "load")) {
        WebKitURIRequest *rq = webkit_uri_request_new(ARG(2));
        if (*ARG(3)) {                         /* extra headers "Name: value\n..." */
            SoupMessageHeaders *h = webkit_uri_request_get_http_headers(rq);
            char **lines = g_strsplit(ARG(3), "\n", -1);
            for (char **l = lines; *l && h; l++) { char *colon = strchr(*l, ':'); if (colon) { *colon = 0; soup_message_headers_replace(h, g_strstrip(*l), g_strstrip(colon + 1)); } }
            g_strfreev(lines);
        }
        webkit_web_view_load_request(v->wv, rq);
        g_object_unref(rq);
    }
    else if (!strcmp(c, "html")) {
        /* with a real base URL the page is loaded "as" that URL so it gets a back-forward item, like iOS */
        if (*ARG(2) && strcmp(ARG(2), "about:blank")) {
            g_hash_table_insert(v->alt_html, g_strdup(ARG(2)), g_strdup(ARG(3)));
            webkit_web_view_load_alternate_html(v->wv, ARG(3), ARG(2), ARG(2));
        }
        else webkit_web_view_load_html(v->wv, ARG(3), NULL);
    }
    else if (!strcmp(c, "data")) {
        gsize len; guchar *d = g_base64_decode(ARG(5), &len);
        GBytes *b = g_bytes_new_take(d, len);
        webkit_web_view_load_bytes(v->wv, b, *ARG(3) ? ARG(3) : NULL, *ARG(4) ? ARG(4) : NULL, *ARG(2) ? ARG(2) : NULL);
        g_bytes_unref(b);
    }
    else if (!strcmp(c, "back")) webkit_web_view_go_back(v->wv);
    else if (!strcmp(c, "forward")) webkit_web_view_go_forward(v->wv);
    else if (!strcmp(c, "goto")) {
        WebKitBackForwardListItem *it = webkit_back_forward_list_get_nth_item(webkit_web_view_get_back_forward_list(v->wv), atoi(ARG(2)));
        if (it) webkit_web_view_go_to_back_forward_list_item(v->wv, it);
    }
    else if (!strcmp(c, "reload")) webkit_web_view_reload(v->wv);
    else if (!strcmp(c, "reloadorigin")) webkit_web_view_reload_bypass_cache(v->wv);
    else if (!strcmp(c, "stop")) webkit_web_view_stop_loading(v->wv);
    else if (!strcmp(c, "js")) run_js(v, atoi(ARG(2)), ARG(3), ARG(4), 0);
    else if (!strcmp(c, "call")) run_js(v, atoi(ARG(2)), ARG(3), ARG(4), 1);
    else if (!strcmp(c, "script")) {         /* world time(0 start,1 end) mainOnly source */
        const char *world = *ARG(2) ? ARG(2) : NULL;
        WebKitUserContentInjectedFrames fr = atoi(ARG(4)) ? WEBKIT_USER_CONTENT_INJECT_TOP_FRAME : WEBKIT_USER_CONTENT_INJECT_ALL_FRAMES;
        WebKitUserScriptInjectionTime when = atoi(ARG(3)) ? WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_END : WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START;
        WebKitUserScript *us = world ? webkit_user_script_new_for_world(ARG(5), fr, when, world, NULL, NULL) : webkit_user_script_new(ARG(5), fr, when, NULL, NULL);
        webkit_user_content_manager_add_script(v->ucm, us);
        webkit_user_script_unref(us);
    }
    else if (!strcmp(c, "clearscripts")) {
        webkit_user_content_manager_remove_all_scripts(v->ucm);
        WebKitUserScript *us = webkit_user_script_new_for_world(isim_world_script, WEBKIT_USER_CONTENT_INJECT_TOP_FRAME,
                                                                WEBKIT_USER_SCRIPT_INJECT_AT_DOCUMENT_START, "isim", NULL, NULL);
        webkit_user_content_manager_add_script(v->ucm, us);
        webkit_user_script_unref(us);
    }
    else if (!strcmp(c, "handler")) {        /* world name withReply */
        const char *world = *ARG(2) ? ARG(2) : NULL;
        char *name = g_strdup(ARG(3)), *sig;
        if (atoi(ARG(4))) {
            webkit_user_content_manager_register_script_message_handler_with_reply(v->ucm, name, world);
            sig = g_strdup_printf("script-message-with-reply-received::%s", name);
            g_signal_connect_data(v->ucm, sig, G_CALLBACK(on_message_reply), name, (GClosureNotify)g_free, 0);
        } else {
            webkit_user_content_manager_register_script_message_handler(v->ucm, name, world);
            sig = g_strdup_printf("script-message-received::%s", name);
            g_signal_connect_data(v->ucm, sig, G_CALLBACK(on_message), name, (GClosureNotify)g_free, 0);
        }
        g_free(sig);
    }
    else if (!strcmp(c, "rmhandler")) {
        webkit_user_content_manager_unregister_script_message_handler(v->ucm, ARG(3), *ARG(2) ? ARG(2) : NULL);
        char *sig1 = g_strdup_printf("script-message-received::%s", ARG(3)), *sig2 = g_strdup_printf("script-message-with-reply-received::%s", ARG(3));
        guint s1 = g_signal_lookup("script-message-received", WEBKIT_TYPE_USER_CONTENT_MANAGER), s2 = g_signal_lookup("script-message-with-reply-received", WEBKIT_TYPE_USER_CONTENT_MANAGER);
        g_signal_handlers_disconnect_matched(v->ucm, G_SIGNAL_MATCH_ID | G_SIGNAL_MATCH_DETAIL, s1, g_quark_from_string(ARG(3)), NULL, NULL, NULL);
        g_signal_handlers_disconnect_matched(v->ucm, G_SIGNAL_MATCH_ID | G_SIGNAL_MATCH_DETAIL, s2, g_quark_from_string(ARG(3)), NULL, NULL, NULL);
        g_free(sig1); g_free(sig2);
    }
    else if (!strcmp(c, "policy")) {          /* req decision(0 cancel, 1 allow, 2 download) */
        struct pend *p = pend_take(v, atoi(ARG(2)));
        if (!p) return;
        int d = atoi(ARG(3));
        if (d == 1) webkit_policy_decision_use(p->obj);
        else if (d == 2) webkit_policy_decision_download(p->obj);
        else { v->policy_cancelled = 1; webkit_policy_decision_ignore(p->obj); }
        g_object_unref(p->obj); g_free(p);
    }
    else if (!strcmp(c, "dialog")) {          /* req ok text */
        struct pend *p = pend_take(v, atoi(ARG(2)));
        if (!p) return;
        WebKitScriptDialog *d = p->obj;
        WebKitScriptDialogType t = webkit_script_dialog_get_dialog_type(d);
        if (t == WEBKIT_SCRIPT_DIALOG_CONFIRM || t == WEBKIT_SCRIPT_DIALOG_BEFORE_UNLOAD_CONFIRM) webkit_script_dialog_confirm_set_confirmed(d, atoi(ARG(3)));
        else if (t == WEBKIT_SCRIPT_DIALOG_PROMPT && atoi(ARG(3))) webkit_script_dialog_prompt_set_text(d, ARG(4));
        webkit_script_dialog_close(d);
        webkit_script_dialog_unref(d);
        g_free(p);
    }
    else if (!strcmp(c, "reply")) {           /* req ok json-or-error */
        struct pend *p = pend_take(v, atoi(ARG(2)));
        if (!p) return;
        if (atoi(ARG(3))) {
            JSCContext *ctx = jsc_context_new();
            JSCValue *val = *ARG(4) ? jsc_value_new_from_json(ctx, ARG(4)) : jsc_value_new_undefined(ctx);
            webkit_script_message_reply_return_value(p->obj, val);
            g_object_unref(val); g_object_unref(ctx);
        } else webkit_script_message_reply_return_error_message(p->obj, ARG(4));
        webkit_script_message_reply_unref(p->obj);
        g_free(p);
    }
    else if (!strcmp(c, "tap")) {             /* x y phase(down/up/cancel) */
        char *s = g_strdup_printf("%s(%s,%s,'%s')", tap_js, ARG(2), ARG(3), *ARG(4) ? ARG(4) : "up");
        input_js(v, s); g_free(s);
    }
    else if (!strcmp(c, "scroll")) { char *s = g_strdup_printf("%s(%s,%s,%s,%s)", scroll_js, ARG(2), ARG(3), ARG(4), ARG(5)); input_js(v, s); g_free(s); }
    else if (!strcmp(c, "scrollto")) { char *s = g_strdup_printf("window.scrollTo(%s,%s)", ARG(2), ARG(3)); input_js(v, s); g_free(s); }
    else if (!strcmp(c, "text")) { char *lit = js_string(ARG(2)), *s = g_strdup_printf("%s(%s)", text_js, lit); input_js(v, s); g_free(s); g_free(lit); }
    else if (!strcmp(c, "key")) { char *lit = js_string(ARG(2)), *s = g_strdup_printf("%s(%s)", key_js, lit); input_js(v, s); g_free(s); g_free(lit); }
    else if (!strcmp(c, "blur")) input_js(v, "if(document.activeElement&&document.activeElement.blur)document.activeElement.blur()");
    else if (!strcmp(c, "ua")) webkit_settings_set_user_agent(webkit_web_view_get_settings(v->wv), *ARG(2) ? ARG(2) : NULL);
    else if (!strcmp(c, "zoom")) { v->zoom = g_ascii_strtod(ARG(2), NULL) > 0 ? g_ascii_strtod(ARG(2), NULL) : 1; webkit_web_view_set_zoom_level(v->wv, v->scale * v->zoom); }
    else if (!strcmp(c, "js-enabled")) webkit_settings_set_enable_javascript(webkit_web_view_get_settings(v->wv), atoi(ARG(2)));
    else if (!strcmp(c, "bg")) { GdkRGBA col; if (gdk_rgba_parse(&col, ARG(2))) webkit_web_view_set_background_color(v->wv, &col); }
    else if (!strcmp(c, "cookies")) {
        struct cookiereq *q = g_new0(struct cookiereq, 1); q->view = id; q->req = atoi(ARG(2));
        webkit_cookie_manager_get_all_cookies(cookie_manager(v), NULL, cookies_done, q);
    }
    else if (!strcmp(c, "setcookie") || !strcmp(c, "delcookie")) {   /* req name value domain path expires secure httpOnly */
        SoupCookie *ck = soup_cookie_new(ARG(3), ARG(4), ARG(5), *ARG(6) ? ARG(6) : "/", -1);
        if (atol(ARG(7)) > 0) { GDateTime *dt = g_date_time_new_from_unix_utc(atol(ARG(7))); soup_cookie_set_expires(ck, dt); g_date_time_unref(dt); }
        soup_cookie_set_secure(ck, atoi(ARG(8))); soup_cookie_set_http_only(ck, atoi(ARG(9)));
        struct cookiereq *q = g_new0(struct cookiereq, 1); q->view = id;
        if (!strcmp(c, "setcookie")) { q->req = atoi(ARG(2)); webkit_cookie_manager_add_cookie(cookie_manager(v), ck, NULL, cookie_op_done, q); }
        else { q->req = -atoi(ARG(2)); webkit_cookie_manager_delete_cookie(cookie_manager(v), ck, NULL, cookie_op_done, q); }
        soup_cookie_free(ck);
    }
    else if (!strcmp(c, "cleardata")) {       /* req since(unix, 0 = all) */
        struct cookiereq *q = g_new0(struct cookiereq, 1); q->view = id; q->req = atoi(ARG(2));
        long since = atol(ARG(3));
        GTimeSpan span = since > 0 ? (g_get_real_time() / 1000000 - since) * G_TIME_SPAN_SECOND : 0;
        WebKitWebsiteDataManager *m = webkit_network_session_get_website_data_manager(webkit_web_view_get_network_session(v->wv));
        webkit_website_data_manager_clear(m, WEBKIT_WEBSITE_DATA_ALL, span, NULL, clear_done, q);
    }
#undef ARG
}

static gboolean on_input(GIOChannel *ch, GIOCondition cond, gpointer unused) {
    char buf[65536];
    ssize_t r = read(PROTO_FD, buf, sizeof buf);
    if (r <= 0) {                                 /* the app went away */
        if (r < 0 && (errno == EINTR || errno == EAGAIN)) return G_SOURCE_CONTINUE;
        if (broadway_pid > 0) kill(broadway_pid, SIGTERM);
        _exit(0);
    }
    g_string_append_len(inbuf, buf, r);
    char *nl;
    while ((nl = memchr(inbuf->str, '\n', inbuf->len))) {
        size_t len = nl - inbuf->str;
        char *line = g_strndup(inbuf->str, len);
        g_string_erase(inbuf, 0, len + 1);
        char **f = g_strsplit(line, "\t", -1);
        int n = 0; for (; f[n]; n++) unesc(f[n]);
        if (debug) fprintf(stderr, "isim-webkit <- %.200s\n", line);
        cmd(f, n);
        g_strfreev(f); g_free(line);
    }
    return G_SOURCE_CONTINUE;
}

/* a private broadway display: :N with N derived from our pid, retried until one is free */
static int start_broadway(void) {
    const char *bin = getenv("ISIM_BROADWAYD");
    char path[256];
    if (!bin) bin = "gtk4-broadwayd";
    const char *rt = g_get_user_runtime_dir();
    for (int attempt = 0; attempt < 20; attempt++) {
        int disp = 200 + (getpid() * 7 + attempt * 131) % 20000;
        snprintf(path, sizeof path, "%s/broadway%d.socket", rt, disp + 1);   /* gtk4-broadwayd names it display + 1 */
        if (access(path, F_OK) == 0) continue;
        pid_t pid = fork();
        if (pid == 0) {
            prctl(PR_SET_PDEATHSIG, SIGTERM);
            int dn = open("/dev/null", O_RDWR);
            if (!debug) { dup2(dn, 1); dup2(dn, 2); }
            close(PROTO_FD);
            char d[16]; snprintf(d, sizeof d, ":%d", disp);
            execlp(bin, bin, "-a", "127.0.0.1", d, (char *)NULL);
            _exit(127);
        }
        if (pid < 0) return -1;
        for (int i = 0; i < 100; i++) {           /* up to 5 s for the socket to appear */
            if (access(path, F_OK) == 0) {
                char d[16]; snprintf(d, sizeof d, ":%d", disp);
                setenv("BROADWAY_DISPLAY", d, 1);
                setenv("GDK_BACKEND", "broadway", 1);
                broadway_pid = pid;
                return disp;
            }
            int st;
            if (waitpid(pid, &st, WNOHANG) == pid) break;   /* port in use etc: try another number */
            g_usleep(50000);
        }
        kill(pid, SIGKILL); waitpid(pid, NULL, 0);
    }
    return -1;
}

int main(int argc, char **argv) {
    debug = getenv("ISIM_WEBKIT_DEBUG") != NULL;
    signal(SIGPIPE, SIG_IGN);
    prctl(PR_SET_PDEATHSIG, SIGTERM);
    if (fcntl(PROTO_FD, F_GETFD) < 0) { fprintf(stderr, "isim-webkit: run by the isim runtime (needs the protocol socket on fd 3)\n"); return 2; }
    if (start_broadway() < 0) { const char *m = "error\t0\tgtk4-broadwayd could not be started\n"; if (write(PROTO_FD, m, strlen(m))) {} return 1; }
    setenv("WEBKIT_DISABLE_COMPOSITING_MODE", "1", 0);
    gtk_init();
    webkit_web_context_set_cache_model(webkit_web_context_get_default(), WEBKIT_CACHE_MODEL_WEB_BROWSER);
    views = g_hash_table_new(g_direct_hash, g_direct_equal);
    schemes = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    scheme_reqs = g_hash_table_new(g_direct_hash, g_direct_equal);
    inbuf = g_string_new(NULL);
    GIOChannel *ch = g_io_channel_unix_new(PROTO_FD);
    g_io_add_watch(ch, G_IO_IN | G_IO_HUP | G_IO_ERR, on_input, NULL);
    g_timeout_add(16, tick, NULL);
    SEND(0, "hello", webkit_get_major_version() == 2 ? "WebKitGTK" : "WebKit", itoa_(webkit_get_major_version()), itoa_(webkit_get_minor_version()), itoa_(webkit_get_micro_version()));
    GMainLoop *loop = g_main_loop_new(NULL, FALSE);
    g_main_loop_run(loop);
    return 0;
}
