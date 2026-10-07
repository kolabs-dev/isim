/* libisim_host networking: HTTP(S) transfers and WebSockets through the host's libcurl, and the host's
 * connectivity (NWPathMonitor). Used by isim's Foundation (URLSession) and Network overlays.
 * libcurl is dlopen'd (libcurl.so.4): isim runs without it, and transfers then fail with an error.
 * Option/info numbers are libcurl's stable ABI values (curl.h is not needed to build).
 * Each HTTP transfer runs curl_easy_perform on its own thread; the guest reads the response and
 * the body stream with blocking calls from its own (background) thread.
 * ISIM_NETWORK=offline makes the device look offline (unsatisfied path, requests fail with
 * NSURLErrorNotConnectedToInternet), for testing an app's offline handling. */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <errno.h>
#include <ifaddrs.h>
#include <math.h>
#include <net/if.h>
#include <netinet/in.h>
#include <poll.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/socket.h>
#include <unistd.h>

typedef void CURL;
struct curl_slist;
struct curl_ws_frame { int age, flags; long long offset, bytesleft; size_t len; };
enum {   /* CURLOPT_* (type base + number) */
    O_WRITEDATA = 10001, O_URL = 10002, O_ERRORBUFFER = 10010, O_WRITEFUNCTION = 20011, O_POSTFIELDS = 10015,
    O_LOW_SPEED_LIMIT = 19, O_LOW_SPEED_TIME = 20, O_HTTPHEADER = 10023, O_HEADERDATA = 10029, O_CUSTOMREQUEST = 10036,
    O_NOPROGRESS = 43, O_NOBODY = 44, O_FOLLOWLOCATION = 52, O_MAXREDIRS = 68, O_HEADERFUNCTION = 20079, O_NOSIGNAL = 99,
    O_ACCEPT_ENCODING = 10102, O_POSTFIELDSIZE_LARGE = 30120, O_CONNECT_ONLY = 141, O_TIMEOUT_MS = 155,
    O_CONNECTTIMEOUT_MS = 156, O_XFERINFODATA = 10057, O_XFERINFOFUNCTION = 20219, O_WS_OPTIONS = 320,
};
enum { I_EFFECTIVE_URL = 0x100001, I_RESPONSE_CODE = 0x200002, I_OS_ERRNO = 0x200019, I_ACTIVESOCKET = 0x50002C };
enum { CURLE_AGAIN = 81, CURLWS_TEXT = 1, CURLWS_BINARY = 2, CURLWS_CONT = 4, CURLWS_CLOSE = 8, CURLWS_PING = 16, CURLWS_PONG = 64 };

static struct {
    int state;                    /* 0 = not tried, 1 = loaded, -1 = unavailable */
    int (*global_init)(long);
    CURL *(*easy_init)(void);
    int (*setopt)(CURL *, int, ...);
    int (*perform)(CURL *);
    int (*getinfo)(CURL *, int, ...);
    void (*cleanup)(CURL *);
    struct curl_slist *(*slist_append)(struct curl_slist *, const char *);
    void (*slist_free_all)(struct curl_slist *);
    const char *(*strerror)(int);
    int (*ws_send)(CURL *, const void *, size_t, size_t *, long long, unsigned);
    int (*ws_recv)(CURL *, void *, size_t, size_t *, const struct curl_ws_frame **);
} curl;
static pthread_mutex_t curl_lock = PTHREAD_MUTEX_INITIALIZER;

static int curl_load(void) {
    pthread_mutex_lock(&curl_lock);
    if (!curl.state) {
        void *h = dlopen("libcurl.so.4", RTLD_NOW | RTLD_LOCAL);
        if (!h) h = dlopen("libcurl.so", RTLD_NOW | RTLD_LOCAL);
        curl.state = -1;
        if (h) {
#define L(f, n) *(void **)&curl.f = dlsym(h, n)
            L(global_init, "curl_global_init"); L(easy_init, "curl_easy_init"); L(setopt, "curl_easy_setopt");
            L(perform, "curl_easy_perform"); L(getinfo, "curl_easy_getinfo"); L(cleanup, "curl_easy_cleanup");
            L(slist_append, "curl_slist_append"); L(slist_free_all, "curl_slist_free_all"); L(strerror, "curl_easy_strerror");
            L(ws_send, "curl_ws_send"); L(ws_recv, "curl_ws_recv");
#undef L
            if (curl.global_init && curl.easy_init && curl.setopt && curl.perform && curl.getinfo && curl.cleanup &&
                curl.slist_append && curl.slist_free_all && curl.strerror && curl.global_init(3 /* CURL_GLOBAL_ALL */) == 0)
                curl.state = 1;
        }
        if (curl.state < 0) fprintf(stderr, "isim: networking needs the host's libcurl (libcurl.so.4), which could not be loaded\n");
    }
    int ok = curl.state > 0;
    pthread_mutex_unlock(&curl_lock);
    return ok;
}

/* ISIM_NETWORK=offline, or Control Center's Wi-Fi off / Airplane Mode (the shell creates <isim data>/Library/isim/NetworkOffline) */
static int offline(void) {
    const char *e = getenv("ISIM_NETWORK");
    if (e && !strcmp(e, "offline")) return 1;
    const char *d = getenv("ISIM_DATA");
    if (!d || !*d) return 0;
    char p[1024]; snprintf(p, sizeof p, "%s/Library/isim/NetworkOffline", d);
    return access(p, F_OK) == 0;
}

/* libcurl result -> NSURLError code */
static int url_error(CURL *c, int rc) {
    long os = 0;
    switch (rc) {
    case 0: return 0;
    case 1: return -1002;                    /* unsupported protocol -> NSURLErrorUnsupportedURL */
    case 3: return -1000;                    /* malformed -> BadURL */
    case 5: case 6: return -1003;            /* could not resolve -> CannotFindHost */
    case 7:
        if (c) curl.getinfo(c, I_OS_ERRNO, &os);
        return os == ENETUNREACH || os == ENETDOWN ? -1009 : -1004;   /* NotConnectedToInternet / CannotConnectToHost */
    case 8: return -1011;                    /* weird reply -> BadServerResponse */
    case 18: case 52: case 55: case 56: case 92: return -1005;   /* NetworkConnectionLost */
    case 28: return -1001;                   /* TimedOut */
    case 42: return -999;                    /* aborted by us -> Cancelled */
    case 47: return -1007;                   /* HTTPTooManyRedirects */
    case 35: case 77: return -1200;          /* SecureConnectionFailed */
    case 58: return -1206;                   /* ClientCertificateRequired */
    case 60: case 83: return -1202;          /* ServerCertificateUntrusted */
    case 61: return -1016;                   /* CannotDecodeContentData */
    default: return -1;                      /* Unknown */
    }
}

/* ---------------- HTTP ---------------- */
struct isim_http {
    pthread_mutex_t mu; pthread_cond_t cv;
    CURL *easy; struct curl_slist *hdrs;
    char *url, *method; void *body; long body_len; double timeout, resource_timeout; int flags;
    char *hbuf; size_t hlen, hcap;           /* header block of the latest response */
    int have_response, done, error, refs; volatile int cancelled;
    double timing[7]; long http_version, new_connections, local_port, remote_port; char remote_ip[64], local_ip[64];   /* URLSessionTaskMetrics */
    long status; char *final_url, *final_headers;
    unsigned char *buf; size_t blen, bcap, bpos;   /* received body not yet read by the guest */
    char errbuf[256];
};

static void http_unref(struct isim_http *h) {
    pthread_mutex_lock(&h->mu);
    int last = --h->refs == 0;
    pthread_mutex_unlock(&h->mu);
    if (!last) return;
    if (h->easy) curl.cleanup(h->easy);
    if (h->hdrs) curl.slist_free_all(h->hdrs);
    free(h->url); free(h->method); free(h->body); free(h->hbuf); free(h->final_url); free(h->final_headers); free(h->buf);
    pthread_mutex_destroy(&h->mu); pthread_cond_destroy(&h->cv);
    free(h);
}

/* the response is the last header block seen: called (locked) on the first body byte or at the end */
static void publish_response(struct isim_http *h) {
    if (h->have_response) return;
    h->have_response = 1;
    long code = 0; char *u = NULL;
    curl.getinfo(h->easy, I_RESPONSE_CODE, &code);
    curl.getinfo(h->easy, I_EFFECTIVE_URL, &u);
    h->status = code;
    h->final_url = strdup(u ? u : h->url);
    h->final_headers = strndup(h->hbuf ? h->hbuf : "", h->hlen);
    pthread_cond_broadcast(&h->cv);
}

static size_t on_header(char *p, size_t size, size_t n, void *ud) {
    struct isim_http *h = ud; size_t len = size * n;
    pthread_mutex_lock(&h->mu);
    if (len >= 5 && !strncmp(p, "HTTP/", 5)) h->hlen = 0;          /* a new response (redirect, 100 Continue) */
    if (h->hlen + len + 1 > h->hcap) { h->hcap = (h->hlen + len + 1) * 2; h->hbuf = realloc(h->hbuf, h->hcap); }
    memcpy(h->hbuf + h->hlen, p, len); h->hlen += len; h->hbuf[h->hlen] = 0;
    pthread_mutex_unlock(&h->mu);
    return len;
}

static size_t on_body(char *p, size_t size, size_t n, void *ud) {
    struct isim_http *h = ud; size_t len = size * n;
    if (h->cancelled) return 0;
    pthread_mutex_lock(&h->mu);
    publish_response(h);
    if (h->bpos && h->bpos == h->blen) h->bpos = h->blen = 0;
    if (h->blen + len > h->bcap) {
        if (h->bpos) { memmove(h->buf, h->buf + h->bpos, h->blen - h->bpos); h->blen -= h->bpos; h->bpos = 0; }
        if (h->blen + len > h->bcap) { h->bcap = (h->blen + len) * 2; h->buf = realloc(h->buf, h->bcap); }
    }
    memcpy(h->buf + h->blen, p, len); h->blen += len;
    pthread_cond_broadcast(&h->cv);
    pthread_mutex_unlock(&h->mu);
    return len;
}

static int on_progress(void *ud, long long dt, long long dn, long long ut, long long un) { return ((struct isim_http *)ud)->cancelled; }

static void *http_thread(void *arg) {
    struct isim_http *h = arg;
    CURL *c = h->easy;
    curl.setopt(c, O_URL, h->url);
    curl.setopt(c, O_NOSIGNAL, 1L);
    curl.setopt(c, O_ERRORBUFFER, h->errbuf);
    curl.setopt(c, O_HEADERFUNCTION, on_header); curl.setopt(c, O_HEADERDATA, h);
    curl.setopt(c, O_WRITEFUNCTION, on_body); curl.setopt(c, O_WRITEDATA, h);
    curl.setopt(c, O_NOPROGRESS, 0L);
    curl.setopt(c, O_XFERINFOFUNCTION, on_progress); curl.setopt(c, O_XFERINFODATA, h);
    curl.setopt(c, O_ACCEPT_ENCODING, "");            /* like CFNetwork: advertise and transparently decode gzip etc. */
    if (!(h->flags & 1)) { curl.setopt(c, O_FOLLOWLOCATION, 1L); curl.setopt(c, O_MAXREDIRS, 16L); }
    if (h->flags & 2) { curl.setopt(c, 64 /* CURLOPT_SSL_VERIFYPEER */, 0L); curl.setopt(c, 81 /* CURLOPT_SSL_VERIFYHOST */, 0L); }   /* the app trusted the server */
    /* timeoutIntervalForRequest is an idle timeout (no bytes for that long), as on iOS */
    if (h->timeout > 0) {
        curl.setopt(c, O_CONNECTTIMEOUT_MS, (long)(h->timeout * 1000));
        curl.setopt(c, O_LOW_SPEED_LIMIT, 1L); curl.setopt(c, O_LOW_SPEED_TIME, (long)ceil(h->timeout));
    }
    if (h->resource_timeout > 0 && h->resource_timeout < 86400) curl.setopt(c, O_TIMEOUT_MS, (long)(h->resource_timeout * 1000));
    if (!strcasecmp(h->method, "HEAD")) curl.setopt(c, O_NOBODY, 1L);
    else if (strcmp(h->method, "GET") || h->body) {
        if (strcmp(h->method, "POST")) curl.setopt(c, O_CUSTOMREQUEST, h->method);
        if (h->body || !strcmp(h->method, "POST")) {
            curl.setopt(c, O_POSTFIELDSIZE_LARGE, (long long)h->body_len);
            curl.setopt(c, O_POSTFIELDS, h->body ? h->body : "");
        }
    }
    if (h->hdrs) curl.setopt(c, O_HTTPHEADER, h->hdrs);
    int rc = curl.perform(c);
    /* timings for URLSessionTaskMetrics: total, name lookup, connect, TLS, pretransfer, first byte, redirect */
    static const int tinfo[7] = { 0x300000 + 3, 0x300000 + 4, 0x300000 + 5, 0x300000 + 33, 0x300000 + 6, 0x300000 + 17, 0x300000 + 19 };
    for (int i = 0; i < 7; i++) { double v = -1; if (curl.getinfo(c, tinfo[i], &v) != 0) v = -1; h->timing[i] = v; }
    curl.getinfo(c, 0x200000 + 46, &h->http_version); curl.getinfo(c, 0x200000 + 26, &h->new_connections);
    curl.getinfo(c, 0x200000 + 40, &h->remote_port); curl.getinfo(c, 0x200000 + 42, &h->local_port);
    { char *ip = NULL; if (curl.getinfo(c, 0x100000 + 32, &ip) == 0 && ip) snprintf(h->remote_ip, sizeof h->remote_ip, "%s", ip);
      ip = NULL; if (curl.getinfo(c, 0x100000 + 41, &ip) == 0 && ip) snprintf(h->local_ip, sizeof h->local_ip, "%s", ip); }
    pthread_mutex_lock(&h->mu);
    h->error = h->cancelled ? -999 : url_error(c, rc);
    if (!h->error) publish_response(h);
    else if (!h->errbuf[0]) snprintf(h->errbuf, sizeof h->errbuf, "%s", curl.strerror(rc));
    h->done = 1;
    pthread_cond_broadcast(&h->cv);
    pthread_mutex_unlock(&h->mu);
    http_unref(h);
    return NULL;
}

/* Starts a transfer. headers: "Name: value" lines separated by '\n'. flags: 1 = do not follow redirects, 2 = accept any server certificate.
 * timeout: idle timeout (s); resource_timeout: whole transfer (s, <= 0 none). NULL if libcurl is missing. */
struct isim_http *isim_http_start(const char *method, const char *url, const char *headers, const void *body, long body_len,
                                  double timeout, double resource_timeout, int flags) {
    if (!curl_load()) return NULL;
    struct isim_http *h = calloc(1, sizeof *h);
    pthread_mutex_init(&h->mu, NULL); pthread_cond_init(&h->cv, NULL);
    h->refs = 2;                                         /* guest handle + transfer thread */
    h->url = strdup(url); h->method = strdup(method && *method ? method : "GET");
    if (body) { h->body = malloc(body_len ? body_len : 1); memcpy(h->body, body, body_len); h->body_len = body_len; }
    h->timeout = timeout; h->resource_timeout = resource_timeout; h->flags = flags;
    if (headers) {
        const char *p = headers;
        while (*p) {
            const char *e = strchr(p, '\n'); size_t n = e ? (size_t)(e - p) : strlen(p);
            if (n) { char *line = strndup(p, n); h->hdrs = curl.slist_append(h->hdrs, line); free(line); }
            p += n + (e != NULL);
        }
    }
    h->hdrs = curl.slist_append(h->hdrs, "Expect:");    /* no 100-continue round trip for large bodies */
    h->easy = curl.easy_init();
    if (offline()) {                                      /* fail like an iPhone without a network */
        h->error = -1009; h->done = 1; h->refs = 1;
        snprintf(h->errbuf, sizeof h->errbuf, "The Internet connection appears to be offline.");
        return h;
    }
    pthread_t t; pthread_attr_t a; pthread_attr_init(&a); pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
    if (pthread_create(&t, &a, http_thread, h)) { h->error = -1; h->done = 1; h->refs = 1; }
    pthread_attr_destroy(&a);
    return h;
}

/* Blocks until the response headers arrive. Returns 0 or an NSURLError code; *url and *headers are
 * malloc'd (free them), headers as raw "Name: value\r\n" lines after the status line. */
int isim_http_response(struct isim_http *h, long *status, char **url, char **headers) {
    pthread_mutex_lock(&h->mu);
    while (!h->have_response && !h->done) pthread_cond_wait(&h->cv, &h->mu);
    int err = h->have_response ? 0 : h->error ? h->error : -1;
    if (!err) { *status = h->status; *url = strdup(h->final_url); *headers = strdup(h->final_headers); }
    pthread_mutex_unlock(&h->mu);
    return err;
}

/* Blocks until body bytes arrive: > 0 bytes copied, 0 at the end, < 0 NSURLError code. */
long isim_http_read(struct isim_http *h, void *out, long cap) {
    pthread_mutex_lock(&h->mu);
    while (h->bpos == h->blen && !h->done) pthread_cond_wait(&h->cv, &h->mu);
    long n = 0;
    if (h->bpos < h->blen) {
        n = (long)(h->blen - h->bpos); if (n > cap) n = cap;
        memcpy(out, h->buf + h->bpos, n); h->bpos += n;
    } else if (h->error) n = h->error;
    pthread_mutex_unlock(&h->mu);
    return n;
}

const char *isim_http_error_message(struct isim_http *h) { return h->errbuf; }
/* after the body was read: seconds from the start for t[0] total, [1] name lookup, [2] connect, [3] TLS handshake,
   [4] request sent, [5] first response byte, [6] redirects (-1 unknown); ints[0] HTTP version (CURL_HTTP_VERSION_*),
   [1] new connections (0 = reused), [2] remote port, [3] local port; remote/local IP strings */
void isim_http_metrics(struct isim_http *h, double *t, long *ints, char *remote, int rlen, char *local, int llen) {
    pthread_mutex_lock(&h->mu);
    for (int i = 0; i < 7; i++) t[i] = h->done ? h->timing[i] : -1;
    ints[0] = h->http_version; ints[1] = h->new_connections; ints[2] = h->remote_port; ints[3] = h->local_port;
    snprintf(remote, rlen, "%s", h->remote_ip); snprintf(local, llen, "%s", h->local_ip);
    pthread_mutex_unlock(&h->mu);
}
void isim_http_cancel(struct isim_http *h) {
    pthread_mutex_lock(&h->mu); h->cancelled = 1; pthread_cond_broadcast(&h->cv); pthread_mutex_unlock(&h->mu);
}
void isim_http_close(struct isim_http *h) { if (h) { isim_http_cancel(h); http_unref(h); } }

/* ---------------- WebSocket (libcurl ≥ 7.86 built with WebSocket support) ---------------- */
struct isim_ws { CURL *easy; struct curl_slist *hdrs; pthread_mutex_t mu; int sock; volatile int closed; char errbuf[256]; };

/* Connects (blocking). Returns NULL with *err set to an NSURLError code on failure. */
struct isim_ws *isim_ws_open(const char *url, const char *headers, double timeout, int *err) {
    *err = 0;
    if (!curl_load()) { *err = -1; return NULL; }
    if (!curl.ws_send || !curl.ws_recv) { fprintf(stderr, "isim: the host's libcurl has no WebSocket support\n"); *err = -1002; return NULL; }
    if (offline()) { *err = -1009; return NULL; }
    struct isim_ws *w = calloc(1, sizeof *w);
    pthread_mutex_init(&w->mu, NULL);
    w->easy = curl.easy_init();
    if (headers) {
        const char *p = headers;
        while (*p) {
            const char *e = strchr(p, '\n'); size_t n = e ? (size_t)(e - p) : strlen(p);
            if (n) { char *line = strndup(p, n); w->hdrs = curl.slist_append(w->hdrs, line); free(line); }
            p += n + (e != NULL);
        }
    }
    curl.setopt(w->easy, O_URL, url);
    curl.setopt(w->easy, O_CONNECT_ONLY, 2L);             /* 2: do the WebSocket upgrade, then hand over */
    curl.setopt(w->easy, O_NOSIGNAL, 1L);
    curl.setopt(w->easy, O_ERRORBUFFER, w->errbuf);
    if (timeout > 0) curl.setopt(w->easy, O_CONNECTTIMEOUT_MS, (long)(timeout * 1000));
    if (w->hdrs) curl.setopt(w->easy, O_HTTPHEADER, w->hdrs);
    int rc = curl.perform(w->easy);
    if (rc) {
        *err = url_error(w->easy, rc);
        if (rc == 22 || rc == 8) *err = -1011;           /* the server refused the upgrade */
        curl.cleanup(w->easy); if (w->hdrs) curl.slist_free_all(w->hdrs); free(w);
        return NULL;
    }
    long s = -1; curl.getinfo(w->easy, I_ACTIVESOCKET, &s); w->sock = (int)s;
    return w;
}

/* kind: 1 text, 2 binary, 8 close, 9 ping, 10 pong. Returns 0 or an NSURLError code. */
int isim_ws_send(struct isim_ws *w, int kind, const void *data, long len) {
    unsigned flags = kind == 1 ? CURLWS_TEXT : kind == 2 ? CURLWS_BINARY : kind == 8 ? CURLWS_CLOSE : kind == 9 ? CURLWS_PING : CURLWS_PONG;
    const char *p = data; size_t left = (size_t)len;
    pthread_mutex_lock(&w->mu);
    int rc = 0;
    do {
        size_t sent = 0;
        rc = curl.ws_send(w->easy, p, left, &sent, 0, flags);
        if (rc == CURLE_AGAIN) {
            pthread_mutex_unlock(&w->mu);
            struct pollfd pf = { w->sock, POLLOUT, 0 }; poll(&pf, 1, 100);
            pthread_mutex_lock(&w->mu);
            continue;
        }
        if (rc) break;
        p += sent; left -= sent;
    } while ((left > 0 || rc == CURLE_AGAIN) && !w->closed);
    pthread_mutex_unlock(&w->mu);
    return rc ? url_error(NULL, rc) : 0;
}

/* Blocks until a whole message arrives (fragments joined). kind as for send; *data is malloc'd.
 * Returns 0, or an NSURLError code (-1005 when the connection closed). */
int isim_ws_recv(struct isim_ws *w, int *kind, unsigned char **data, long *len) {
    unsigned char *msg = NULL; size_t mlen = 0, cap = 0; int k = 0;
    char chunk[16384];
    for (;;) {
        if (w->closed) { free(msg); return -999; }
        size_t got = 0; const struct curl_ws_frame *meta = NULL;
        pthread_mutex_lock(&w->mu);
        int rc = curl.ws_recv(w->easy, chunk, sizeof chunk, &got, &meta);
        pthread_mutex_unlock(&w->mu);
        if (rc == CURLE_AGAIN) { struct pollfd pf = { w->sock, POLLIN, 0 }; poll(&pf, 1, 100); continue; }
        if (rc) { free(msg); return rc == 52 || rc == 56 ? -1005 : url_error(w->easy, rc); }
        if (!k && meta) k = meta->flags & CURLWS_TEXT ? 1 : meta->flags & CURLWS_BINARY ? 2 : meta->flags & CURLWS_CLOSE ? 8 :
                            meta->flags & CURLWS_PING ? 9 : meta->flags & CURLWS_PONG ? 10 : 2;
        if (mlen + got + 1 > cap) { cap = (mlen + got + 1) * 2; msg = realloc(msg, cap); }
        memcpy(msg + mlen, chunk, got); mlen += got;
        if (meta && meta->bytesleft == 0 && !(meta->flags & CURLWS_CONT)) break;
    }
    if (!msg) msg = malloc(1);
    msg[mlen] = 0;
    *kind = k; *data = msg; *len = (long)mlen;
    return 0;
}

void isim_ws_close(struct isim_ws *w) {
    if (!w) return;
    w->closed = 1;
    pthread_mutex_lock(&w->mu);              /* waits for a recv in progress to leave libcurl */
    curl.cleanup(w->easy); if (w->hdrs) curl.slist_free_all(w->hdrs);
    w->easy = NULL;
    pthread_mutex_unlock(&w->mu);
    /* the struct is leaked on purpose: a receiving thread may still poll it once */
}

/* ---------------- connectivity ---------------- */
/* Returns 1 if the host has a usable (non-loopback, up) interface with an address. flags: 1 Wi-Fi, 2 wired,
 * 4 IPv4, 8 IPv6 (global), 16 a VPN/tunnel-like interface. */
int isim_net_path(int *flags) {
    int f = 0;
    if (offline()) { if (flags) *flags = 0; return 0; }
    struct ifaddrs *list = NULL;
    if (getifaddrs(&list) == 0) {
        for (struct ifaddrs *a = list; a; a = a->ifa_next) {
            if (!a->ifa_addr || !(a->ifa_flags & IFF_UP) || !(a->ifa_flags & IFF_RUNNING) || (a->ifa_flags & IFF_LOOPBACK)) continue;
            if (!strncmp(a->ifa_name, "docker", 6) || !strncmp(a->ifa_name, "veth", 4) || !strncmp(a->ifa_name, "br-", 3) ||
                !strncmp(a->ifa_name, "virbr", 5)) continue;        /* local bridges do not reach the Internet */
            int fam = a->ifa_addr->sa_family;
            if (fam == AF_INET) f |= 4;
            else if (fam == AF_INET6) {
                const unsigned char *b = ((struct sockaddr_in6 *)a->ifa_addr)->sin6_addr.s6_addr;
                if ((b[0] & 0xe0) == 0x20) f |= 8;     /* global unicast */
                else continue;
            } else continue;
            char p[300]; snprintf(p, sizeof p, "/sys/class/net/%s/wireless", a->ifa_name);
            if (!access(p, F_OK)) f |= 1;
            else if (!strncmp(a->ifa_name, "tun", 3) || !strncmp(a->ifa_name, "wg", 2) || !strncmp(a->ifa_name, "tailscale", 9)) f |= 16;
            else f |= 2;
        }
        freeifaddrs(list);
    }
    if (flags) *flags = f;
    return (f & 3) || (f & 16) ? 1 : 0;
}
