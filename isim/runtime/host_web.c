/* isim host: the web engine bridge behind WKWebView (swift/overlays/WebKit).
 *
 * Starts the helper process out/bin/isim-webkit (runtime/isim-webkit.c, the host's WebKitGTK on a
 * private, invisible GTK broadway display) on first use and talks to it over a socketpair with a
 * line protocol (TAB-separated, escaped fields; the overlay builds and parses the lines). A reader
 * thread queues the helper's events for the app; page frames arrive in shared memory that is copied
 * into an image handle when the app asks for it (isim_web_frame), then acknowledged so the helper
 * can send the next one. Without WebKitGTK on the host (no helper binary) isim_web_available is 0. */
#define _GNU_SOURCE
#include "guest_abi.h"
#include "platform.h"
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

ISIM_GUEST_ABI void isim_post_wakeup(void);
ISIM_GUEST_ABI int isim_image_create_bgra(int w, int h);
ISIM_GUEST_ABI void isim_image_update_bgra(int hd, const unsigned char *px, int w, int h);
ISIM_GUEST_ABI void isim_image_free(int hd);

static pthread_mutex_t mtx = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t cv = PTHREAD_COND_INITIALIZER;
static int sock = -1, state;            /* state: 0 not started, 1 running, -1 unavailable/dead */
static pid_t helper_pid;
static char reason[256];

struct line { struct line *next; char *s; };
static struct line *qhead, *qtail;

#define MAXV 256
struct webframe { int view; long seq, shown; int w, h; char path[64]; int img, iw, ih; };
static struct webframe frames[MAXV];

static struct webframe *frame_slot(int view, int create) {
    for (int i = 0; i < MAXV; i++) if (frames[i].view == view) return &frames[i];
    if (!create) return NULL;
    for (int i = 0; i < MAXV; i++) if (frames[i].view == 0) { memset(&frames[i], 0, sizeof frames[i]); frames[i].view = view; return &frames[i]; }
    return NULL;
}

static void helper_path(char *out, size_t n) {
    const char *e = getenv("ISIM_WEBKIT_HELPER");
    if (e && *e) { snprintf(out, n, "%s", e); return; }
    char self[PATH_MAX];
    if (isim_self_path(self, sizeof self) <= 0) { snprintf(out, n, "isim-webkit"); return; }
    char *slash = strrchr(self, '/'); if (slash) *slash = 0;
    snprintf(out, n, "%s/isim-webkit", self);
}

static void enqueue(char *s) {
    struct line *l = malloc(sizeof *l); l->next = NULL; l->s = s;
    if (qtail) qtail->next = l; else qhead = l;
    qtail = l;
}

static void *reader(void *arg) {
    char buf[65536]; size_t have = 0; char *acc = NULL; size_t alen = 0, acap = 0;
    (void)buf; (void)have;
    for (;;) {
        char chunk[65536];
        ssize_t r = read(sock, chunk, sizeof chunk);
        if (r < 0 && errno == EINTR) continue;
        if (r <= 0) break;
        if (alen + r + 1 > acap) { acap = (alen + r + 1) * 2; acc = realloc(acc, acap); }
        memcpy(acc + alen, chunk, r); alen += r;
        size_t start = 0;
        pthread_mutex_lock(&mtx);
        for (size_t i = 0; i < alen; i++) if (acc[i] == '\n') {
            char *s = strndup(acc + start, i - start);
            start = i + 1;
            /* frame\tview\tseq\tw\th\tpath: remember where the newest frame is */
            if (!strncmp(s, "frame\t", 6)) {
                int view = 0, w = 0, h = 0; long seq = 0; char path[64] = "";
                if (sscanf(s + 6, "%d\t%ld\t%d\t%d\t%63s", &view, &seq, &w, &h, path) == 5) {
                    struct webframe *f = frame_slot(view, 1);
                    if (f) { f->seq = seq; f->w = w; f->h = h; snprintf(f->path, sizeof f->path, "%s", path); }
                }
            }
            enqueue(s);
        }
        memmove(acc, acc + start, alen - start); alen -= start;
        pthread_cond_broadcast(&cv);
        pthread_mutex_unlock(&mtx);
        isim_post_wakeup();
    }
    pthread_mutex_lock(&mtx);
    state = -1;
    snprintf(reason, sizeof reason, "the web engine process (isim-webkit) exited");
    enqueue(strdup("exited\t0\tthe web engine process exited"));
    pthread_cond_broadcast(&cv);
    pthread_mutex_unlock(&mtx);
    isim_post_wakeup();
    free(acc);
    return NULL;
}

static int start_locked(void) {
    if (state) return state > 0;
    char path[PATH_MAX]; helper_path(path, sizeof path);
    if (access(path, X_OK) != 0) {
        state = -1;
        snprintf(reason, sizeof reason, "no web engine: %s is missing (isim builds it when the host has WebKitGTK 6.0 / webkitgtk-6.0)", path);
        return 0;
    }
    int sv[2];
    if (isim_ipc_pair(sv, 0) != 0) { state = -1; snprintf(reason, sizeof reason, "ipc pair: %s", strerror(errno)); return 0; }
    char *argv[] = { path, NULL };
    struct isim_spawn sp = { .path = path, .argv = argv, .remap_from = sv[1], .remap_to = 3,   /* the helper's fd 3 */
                             .null_stdin = 1, .null_stdout = 1, .null_stderr = !getenv("ISIM_WEBKIT_DEBUG") };
    helper_pid = isim_spawn(&sp);
    int err = errno;
    close(sv[1]);
    if (helper_pid < 0) { close(sv[0]); state = -1; snprintf(reason, sizeof reason, "cannot start %s: %s", path, strerror(err)); return 0; }
    sock = sv[0];
    state = 1;
    pthread_t th; pthread_create(&th, NULL, reader, NULL); pthread_detach(th);
    return 1;
}

/* 1 if the web engine can run (starts the helper on first call); reason (optional) explains a 0 */
ISIM_GUEST_ABI int isim_web_available(char *why, int cap) {
    pthread_mutex_lock(&mtx);
    int ok = start_locked();
    if (!ok && why && cap > 0) snprintf(why, cap, "%s", reason);
    pthread_mutex_unlock(&mtx);
    return ok;
}

/* sends one protocol line (without the newline) */
ISIM_GUEST_ABI void isim_web_send(const char *line) {
    pthread_mutex_lock(&mtx);
    int ok = start_locked(), fd = sock;
    pthread_mutex_unlock(&mtx);
    if (!ok || fd < 0) return;
    size_t n = strlen(line);
    char *b = malloc(n + 1); memcpy(b, line, n); b[n] = '\n';
    const char *p = b; size_t left = n + 1;
    while (left > 0) {
        ssize_t w = send(fd, p, left, MSG_NOSIGNAL);
        if (w < 0 && errno == EINTR) continue;
        if (w <= 0) break;
        p += w; left -= w;
    }
    free(b);
}

/* next event line (malloc'd, free with isim_web_free) or NULL; waits up to timeout seconds (0: no wait) */
ISIM_GUEST_ABI char *isim_web_next(double timeout) {
    pthread_mutex_lock(&mtx);
    if (!qhead && timeout > 0 && state > 0) {
        struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
        long ns = ts.tv_nsec + (long)((timeout - (long)timeout) * 1e9);
        ts.tv_sec += (long)timeout + ns / 1000000000L; ts.tv_nsec = ns % 1000000000L;
        while (!qhead && state > 0) if (pthread_cond_timedwait(&cv, &mtx, &ts) == ETIMEDOUT) break;
    }
    char *s = NULL;
    if (qhead) {
        struct line *l = qhead; qhead = l->next; if (!qhead) qtail = NULL;
        s = l->s; free(l);
    }
    pthread_mutex_unlock(&mtx);
    return s;
}
ISIM_GUEST_ABI void isim_web_free(char *s) { free(s); }

/* UI thread: image handle with the view's newest frame (0 before the first), pixel size in *w and *h */
ISIM_GUEST_ABI int isim_web_frame(int view, int *w, int *h) {
    pthread_mutex_lock(&mtx);
    struct webframe *f = frame_slot(view, 0);
    if (!f) { pthread_mutex_unlock(&mtx); return 0; }
    struct webframe cur = *f;
    pthread_mutex_unlock(&mtx);
    if (cur.seq != cur.shown && cur.w > 0 && cur.h > 0) {
        int fd = open(cur.path, O_RDONLY | O_CLOEXEC);
        if (fd >= 0) {
            size_t sz = (size_t)cur.w * cur.h * 4;
            struct stat st;
            if (fstat(fd, &st) == 0 && (size_t)st.st_size >= sz) {
                void *m = isim_shm_map(fd, sz, 0);
                if (m) {
                    if (!cur.img || cur.iw != cur.w || cur.ih != cur.h) {
                        if (cur.img) isim_image_free(cur.img);
                        cur.img = isim_image_create_bgra(cur.w, cur.h); cur.iw = cur.w; cur.ih = cur.h;
                    }
                    isim_image_update_bgra(cur.img, m, cur.w, cur.h);
                    isim_shm_unmap(m, sz);
                }
            }
            close(fd);
        }
        pthread_mutex_lock(&mtx);
        f = frame_slot(view, 0);
        if (f) { f->img = cur.img; f->iw = cur.iw; f->ih = cur.ih; f->shown = cur.seq; }
        pthread_mutex_unlock(&mtx);
        char ack[32]; snprintf(ack, sizeof ack, "ack\t%d", view);
        isim_web_send(ack);
    }
    if (w) *w = cur.iw;
    if (h) *h = cur.ih;
    return cur.img;
}

/* forget a closed view's frame */
ISIM_GUEST_ABI void isim_web_release(int view) {
    pthread_mutex_lock(&mtx);
    struct webframe *f = frame_slot(view, 0);
    int img = 0;
    if (f) { img = f->img; memset(f, 0, sizeof *f); }
    pthread_mutex_unlock(&mtx);
    if (img) isim_image_free(img);
}
