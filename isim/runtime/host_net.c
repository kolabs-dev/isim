/* libisim_host networking: HTTP(S) transfers through the host's libcurl, WebSockets (isim's own client), and the host's
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
#include <fcntl.h>
#include <netdb.h>
#include <netinet/tcp.h>
#include <time.h>
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
enum {   /* CURLOPT_* (type base + number) */
    O_WRITEDATA = 10001, O_URL = 10002, O_ERRORBUFFER = 10010, O_WRITEFUNCTION = 20011, O_POSTFIELDS = 10015,
    O_LOW_SPEED_LIMIT = 19, O_LOW_SPEED_TIME = 20, O_HTTPHEADER = 10023, O_HEADERDATA = 10029, O_CUSTOMREQUEST = 10036,
    O_NOPROGRESS = 43, O_NOBODY = 44, O_FOLLOWLOCATION = 52, O_MAXREDIRS = 68, O_HEADERFUNCTION = 20079, O_NOSIGNAL = 99,
    O_ACCEPT_ENCODING = 10102, O_POSTFIELDSIZE_LARGE = 30120, O_CONNECT_ONLY = 141, O_TIMEOUT_MS = 155,
    O_CONNECTTIMEOUT_MS = 156, O_XFERINFODATA = 10057, O_XFERINFOFUNCTION = 20219, O_WS_OPTIONS = 320,
};
enum { I_EFFECTIVE_URL = 0x100001, I_RESPONSE_CODE = 0x200002, I_OS_ERRNO = 0x200019, I_ACTIVESOCKET = 0x50002C };

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

/* ---------------- WebSocket (RFC 6455 client, isim's own) ----------------
 * Independent of the host libcurl's build (most distributions' libcurl has no WebSocket support): a TCP
 * connection (TLS through host_tls.c for wss://), the HTTP/1.1 upgrade handshake (Sec-WebSocket-Accept checked),
 * then masked client frames. Messages split into fragments are joined; pings are answered with pongs; a close from
 * the peer is echoed and returned to the caller. One thread receives (isim_ws_recv) while others send: the socket
 * is non-blocking and every read/write of the connection happens under the struct's lock. */
struct isim_tls;
struct isim_tls *isim_tls_connect(int fd, const char *host, int verify, const char *alpn, int min_version, char *err, int errlen, int *code);
long isim_tls_read_nb(struct isim_tls *t, void *buf, long n);
long isim_tls_write_nb(struct isim_tls *t, const void *buf, long n);
void isim_tls_close(struct isim_tls *t);
void isim_sha1(const void *data, size_t n, unsigned char out[20]);

struct isim_ws {
    int sock; struct isim_tls *tls;
    pthread_mutex_t mu;                      /* the connection: reads, writes, close */
    volatile int closed, close_sent;
    unsigned char *in; size_t in_len, in_cap; /* received bytes not yet parsed into frames */
};

static const char b64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
static void base64(const unsigned char *p, size_t n, char *out) {
    size_t i = 0, o = 0;
    for (; i + 2 < n; i += 3) {
        unsigned v = p[i] << 16 | p[i + 1] << 8 | p[i + 2];
        out[o++] = b64[v >> 18]; out[o++] = b64[v >> 12 & 63]; out[o++] = b64[v >> 6 & 63]; out[o++] = b64[v & 63];
    }
    if (i < n) {
        unsigned v = p[i] << 16 | (i + 1 < n ? p[i + 1] << 8 : 0);
        out[o++] = b64[v >> 18]; out[o++] = b64[v >> 12 & 63];
        out[o++] = i + 1 < n ? b64[v >> 6 & 63] : '='; out[o++] = '=';
    }
    out[o] = 0;
}

static void random_bytes(unsigned char *p, size_t n) {
    static __thread unsigned long long x;
    if (!x) { struct timespec t; clock_gettime(CLOCK_MONOTONIC, &t); x = (unsigned long long)t.tv_nsec ^ (unsigned long long)pthread_self() ^ 0x9e3779b97f4a7c15ULL; }
    FILE *f = fopen("/dev/urandom", "rb");
    if (f) { size_t got = fread(p, 1, n, f); fclose(f); if (got == n) return; }
    for (size_t i = 0; i < n; i++) { x ^= x << 13; x ^= x >> 7; x ^= x << 17; p[i] = (unsigned char)x; }
}

/* one read or write of the connection, non-blocking: >0 bytes, 0 closed (read), -1 error, -2 would block */
static long ws_io_read(struct isim_ws *w, void *buf, long n) {
    if (w->tls) return isim_tls_read_nb(w->tls, buf, n);
    long r = recv(w->sock, buf, (size_t)n, 0);
    return r >= 0 ? r : errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR ? -2 : -1;
}
static long ws_io_write(struct isim_ws *w, const void *buf, long n) {
    if (w->tls) return isim_tls_write_nb(w->tls, buf, n);
    long r = send(w->sock, buf, (size_t)n, MSG_NOSIGNAL);
    return r >= 0 ? r : errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR ? -2 : -1;
}

/* the whole buffer, waiting while the socket is full; called with w->mu held */
static int ws_write_all(struct isim_ws *w, const unsigned char *p, size_t n) {
    while (n > 0) {
        if (w->closed) return -1;
        long r = ws_io_write(w, p, (long)n);
        if (r == -2) { struct pollfd pf = { w->sock, POLLOUT, 0 }; poll(&pf, 1, 100); continue; }
        if (r <= 0) return -1;
        p += r; n -= (size_t)r;
    }
    return 0;
}

static int ws_send_frame(struct isim_ws *w, int opcode, const void *data, size_t len) {
    unsigned char hdr[14]; size_t h = 0;
    hdr[h++] = 0x80 | (opcode & 0x0f);                       /* FIN: messages are sent in one frame */
    if (len < 126) hdr[h++] = 0x80 | (unsigned char)len;
    else if (len < 65536) { hdr[h++] = 0x80 | 126; hdr[h++] = (unsigned char)(len >> 8); hdr[h++] = (unsigned char)len; }
    else { hdr[h++] = 0x80 | 127; for (int i = 7; i >= 0; i--) hdr[h++] = (unsigned char)((unsigned long long)len >> (8 * i)); }
    unsigned char mask[4]; random_bytes(mask, 4);
    memcpy(hdr + h, mask, 4); h += 4;
    unsigned char *frame = malloc(h + len + 1);
    memcpy(frame, hdr, h);
    for (size_t i = 0; i < len; i++) frame[h + i] = ((const unsigned char *)data)[i] ^ mask[i & 3];
    pthread_mutex_lock(&w->mu);
    int rc = ws_write_all(w, frame, h + len);
    if (opcode == 8) w->close_sent = 1;
    pthread_mutex_unlock(&w->mu);
    free(frame);
    return rc;
}

/* parsed frame at the start of w->in, or 0 when more bytes are needed (-1: a protocol error) */
static int ws_parse(struct isim_ws *w, int *fin, int *opcode, unsigned char **payload, size_t *plen, size_t *total) {
    const unsigned char *p = w->in; size_t n = w->in_len;
    if (n < 2) return 0;
    *fin = p[0] >> 7; *opcode = p[0] & 0x0f;
    int masked = p[1] >> 7; unsigned long long len = p[1] & 0x7f; size_t h = 2;
    if (len == 126) { if (n < 4) return 0; len = (unsigned long long)p[2] << 8 | p[3]; h = 4; }
    else if (len == 127) { if (n < 10) return 0; len = 0; for (int i = 0; i < 8; i++) len = len << 8 | p[2 + i]; h = 10; }
    if (len > (1ULL << 31)) return -1;
    unsigned char mask[4] = { 0 };
    if (masked) { if (n < h + 4) return 0; memcpy(mask, p + h, 4); h += 4; }   /* servers must not mask; accept it */
    if (n < h + len) return 0;
    *payload = w->in + h; *plen = (size_t)len; *total = h + (size_t)len;
    if (masked) for (size_t i = 0; i < len; i++) (*payload)[i] ^= mask[i & 3];
    return 1;
}

/* Connects (blocking, up to timeout). Returns NULL with *err set to an NSURLError code on failure. */
struct isim_ws *isim_ws_open(const char *url, const char *headers, double timeout, int *err) {
    *err = 0;
    if (offline()) { *err = -1009; return NULL; }
    int secure;
    const char *rest;
    if (!strncasecmp(url, "wss://", 6)) { secure = 1; rest = url + 6; }
    else if (!strncasecmp(url, "ws://", 5)) { secure = 0; rest = url + 5; }
    else if (!strncasecmp(url, "https://", 8)) { secure = 1; rest = url + 8; }
    else if (!strncasecmp(url, "http://", 7)) { secure = 0; rest = url + 7; }
    else { *err = -1002; return NULL; }                       /* NSURLErrorUnsupportedURL */
    /* authority [user@]host[:port], then the path and query (the fragment is not sent) */
    size_t alen = strcspn(rest, "/?#");
    char auth[512]; if (alen >= sizeof auth) { *err = -1000; return NULL; }
    memcpy(auth, rest, alen); auth[alen] = 0;
    const char *path = rest + alen;
    char *at = strrchr(auth, '@'); char *hostp = at ? at + 1 : auth;
    char host[256], port[8]; const char *defport = secure ? "443" : "80";
    if (*hostp == '[') {
        char *e = strchr(hostp, ']'); if (!e) { *err = -1000; return NULL; }
        snprintf(host, sizeof host, "%.*s", (int)(e - hostp - 1), hostp + 1);
        snprintf(port, sizeof port, "%s", e[1] == ':' ? e + 2 : defport);
    } else {
        char *c = strrchr(hostp, ':');
        snprintf(host, sizeof host, "%.*s", c ? (int)(c - hostp) : (int)strlen(hostp), hostp);
        snprintf(port, sizeof port, "%s", c ? c + 1 : defport);
    }
    if (!*host) { *err = -1000; return NULL; }
    size_t plen = strcspn(path, "#");
    char *target = malloc(plen + 2);
    if (plen == 0 || *path == '?') { target[0] = '/'; memcpy(target + 1, path, plen); target[plen + 1] = 0; }
    else { memcpy(target, path, plen); target[plen] = 0; }

    struct timespec t0; clock_gettime(CLOCK_MONOTONIC, &t0);
    int ms_total = timeout > 0 ? (int)(timeout * 1000) : 60000;
    #define WS_LEFT() ({ struct timespec t1; clock_gettime(CLOCK_MONOTONIC, &t1); \
        int l = ms_total - (int)((t1.tv_sec - t0.tv_sec) * 1000 + (t1.tv_nsec - t0.tv_nsec) / 1000000); l > 0 ? l : 0; })

    struct addrinfo hints = { .ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM }, *res = NULL;
    if (getaddrinfo(host, port, &hints, &res) != 0 || !res) { free(target); *err = -1003; return NULL; }   /* cannot find host */
    int fd = -1, cerr = -1004;                                 /* cannot connect to host */
    for (struct addrinfo *a = res; a && fd < 0; a = a->ai_next) {
        int s = socket(a->ai_family, a->ai_socktype | SOCK_NONBLOCK | SOCK_CLOEXEC, a->ai_protocol);
        if (s < 0) continue;
        if (connect(s, a->ai_addr, a->ai_addrlen) == 0) { fd = s; break; }
        if (errno == EINPROGRESS) {
            struct pollfd pf = { s, POLLOUT, 0 };
            int pr = poll(&pf, 1, WS_LEFT());
            int so = 0; socklen_t sl = sizeof so;
            if (pr > 0 && getsockopt(s, SOL_SOCKET, SO_ERROR, &so, &sl) == 0 && so == 0) { fd = s; break; }
            if (pr == 0) cerr = -1001;                         /* timed out */
        }
        close(s);
    }
    freeaddrinfo(res);
    if (fd < 0) { free(target); *err = cerr; return NULL; }
    int one = 1; setsockopt(fd, IPPROTO_TCP, TCP_NODELAY, &one, sizeof one);

    struct isim_ws *w = calloc(1, sizeof *w);
    w->sock = fd;
    pthread_mutex_init(&w->mu, NULL);
    if (secure) {                                              /* the TLS handshake runs on a blocking socket */
        int left = WS_LEFT();
        struct timeval tv = { left / 1000, (left % 1000) * 1000 };
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv); setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
        char msg[256]; int code = 0;
        w->tls = isim_tls_connect(fd, host, 1, "http/1.1", 0, msg, sizeof msg, &code);
        if (!w->tls) {
            fprintf(stderr, "isim: WebSocket %s: %s\n", host, msg);
            *err = code == -9807 ? -1202 : -1200;              /* certificate untrusted / secure connection failed */
            close(fd); free(w); free(target); return NULL;
        }
        struct timeval zero = { 0, 0 };
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &zero, sizeof zero); setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &zero, sizeof zero);
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_NONBLOCK);
    }

    /* the upgrade request: the app's headers (Sec-WebSocket-Protocol, Authorization, cookies, ...) plus our own */
    unsigned char nonce[16]; random_bytes(nonce, sizeof nonce);
    char key[32]; base64(nonce, sizeof nonce, key);
    size_t cap = 1024 + strlen(target) + (headers ? strlen(headers) : 0) + strlen(host);
    char *req = malloc(cap); size_t o = 0;
    int defp = !strcmp(port, defport); int v6 = strchr(host, ':') != NULL;
    o += snprintf(req + o, cap - o, "GET %s HTTP/1.1\r\nHost: %s%s%s%s%s\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n"
                  "Sec-WebSocket-Key: %s\r\nSec-WebSocket-Version: 13\r\n", target, v6 ? "[" : "", host, v6 ? "]" : "",
                  defp ? "" : ":", defp ? "" : port, key);
    for (const char *p = headers ? headers : ""; *p; ) {
        const char *e = strchr(p, '\n'); size_t n = e ? (size_t)(e - p) : strlen(p);
        static const char *ours[] = { "host:", "upgrade:", "connection:", "sec-websocket-key:", "sec-websocket-version:" };
        int skip = n == 0;
        for (size_t i = 0; i < sizeof ours / sizeof *ours && !skip; i++) skip = !strncasecmp(p, ours[i], strlen(ours[i]));
        if (!skip) { memcpy(req + o, p, n); o += n; req[o++] = '\r'; req[o++] = '\n'; }
        p += n + (e != NULL);
    }
    req[o++] = '\r'; req[o++] = '\n';
    free(target);
    int rc = 0;
    pthread_mutex_lock(&w->mu);
    for (size_t sent = 0; sent < o && !rc; ) {
        long r = ws_io_write(w, req + sent, (long)(o - sent));
        if (r == -2) { struct pollfd pf = { fd, POLLOUT, 0 }; if (poll(&pf, 1, WS_LEFT()) <= 0) rc = -1001; continue; }
        if (r <= 0) rc = -1005; else sent += (size_t)r;
    }
    free(req);
    /* the response head; bytes after it already belong to the first frames */
    char *head = NULL; size_t hlen = 0, hend = 0;
    while (!rc) {
        if (w->in_len + 4096 > w->in_cap) { w->in_cap = (w->in_len + 4096) * 2; w->in = realloc(w->in, w->in_cap); }
        long r = ws_io_read(w, w->in + w->in_len, 4096);
        if (r == -2) { struct pollfd pf = { fd, POLLIN, 0 }; if (poll(&pf, 1, WS_LEFT()) <= 0) rc = -1001; continue; }
        if (r <= 0) { rc = -1005; break; }                     /* network connection lost */
        w->in_len += (size_t)r;
        for (size_t i = 3; i < w->in_len; i++)
            if (!memcmp(w->in + i - 3, "\r\n\r\n", 4)) { hend = i + 1; break; }
        if (hend) break;
        if (w->in_len > 65536) rc = -1011;
    }
    pthread_mutex_unlock(&w->mu);
    if (!rc) {
        head = strndup((char *)w->in, hend); hlen = hend;
        memmove(w->in, w->in + hend, w->in_len - hend); w->in_len -= hend;
        /* 101, Upgrade: websocket, and Sec-WebSocket-Accept = base64(SHA-1(key + RFC 6455 GUID)) */
        char want[64], cat[128]; unsigned char dig[20];
        snprintf(cat, sizeof cat, "%s258EAFA5-E914-47DA-95CA-C5AB0DC85B11", key);
        isim_sha1(cat, strlen(cat), dig); base64(dig, 20, want);
        int status = 0; sscanf(head, "HTTP/%*s %d", &status);
        int upgrade = 0, accept = 0;
        for (char *line = strstr(head, "\r\n"); line && line + 2 < head + hlen; line = strstr(line + 2, "\r\n")) {
            char *l = line + 2, *colon = strchr(l, ':'), *eol = strstr(l, "\r\n");
            if (!colon || !eol || colon > eol) continue;
            char *v = colon + 1; while (*v == ' ' || *v == '\t') v++;
            size_t vn = (size_t)(eol - v); while (vn && (v[vn - 1] == ' ' || v[vn - 1] == '\t')) vn--;
            if (!strncasecmp(l, "upgrade:", 8) && vn == 9 && !strncasecmp(v, "websocket", 9)) upgrade = 1;
            if (!strncasecmp(l, "sec-websocket-accept:", 21) && vn == strlen(want) && !strncmp(v, want, vn)) accept = 1;
        }
        if (status != 101 || !upgrade || !accept) {
            fprintf(stderr, "isim: WebSocket %s: the server refused the upgrade (HTTP %d%s)\n", host, status,
                    status == 101 ? ", bad Sec-WebSocket-Accept" : "");
            rc = -1011;                                        /* bad server response */
        }
        free(head);
    }
    if (rc) {
        if (w->tls) isim_tls_close(w->tls);
        close(fd); free(w->in); free(w);
        *err = rc; return NULL;
    }
    return w;
    #undef WS_LEFT
}

/* kind: 1 text, 2 binary, 8 close, 9 ping, 10 pong. Returns 0 or an NSURLError code. */
int isim_ws_send(struct isim_ws *w, int kind, const void *data, long len) {
    if (w->closed || (w->close_sent && kind != 8)) return -1005;
    int op = kind == 1 ? 1 : kind == 2 ? 2 : kind == 8 ? 8 : kind == 9 ? 9 : 10;
    if (op >= 8 && len > 125) len = 125;                     /* control frames carry at most 125 bytes */
    return ws_send_frame(w, op, data ? data : "", (size_t)(len > 0 ? len : 0)) ? -1005 : 0;
}

/* Blocks until a whole message arrives (fragments joined). kind as for send; *data is malloc'd. Pings are answered
 * here and not returned. Returns 0, or an NSURLError code (-1005 when the connection closed). */
int isim_ws_recv(struct isim_ws *w, int *kind, unsigned char **data, long *len) {
    unsigned char *msg = NULL; size_t mlen = 0; int k = 0;
    for (;;) {
        if (w->closed) { free(msg); return -999; }
        int fin, op; unsigned char *pl; size_t pn, total;
        int pr = ws_parse(w, &fin, &op, &pl, &pn, &total);
        if (pr < 0) { free(msg); return -1005; }
        if (pr > 0) {
            unsigned char *copy = malloc(pn + 1); memcpy(copy, pl, pn); copy[pn] = 0;
            memmove(w->in, w->in + total, w->in_len - total); w->in_len -= total;
            if (op == 9) { ws_send_frame(w, 10, copy, pn); free(copy); continue; }    /* ping: answer, keep reading */
            if (op >= 8) {                                     /* close / pong: returned on their own */
                if (op == 8 && !w->close_sent) ws_send_frame(w, 8, copy, pn > 2 ? 2 : pn);   /* echo the close code */
                free(msg);
                *kind = op; *data = copy; *len = (long)pn;
                return 0;
            }
            if (op != 0) { free(msg); msg = NULL; mlen = 0; k = op; }                  /* a new message */
            msg = realloc(msg, mlen + pn + 1); memcpy(msg + mlen, copy, pn); mlen += pn; free(copy);
            if (fin) break;
            continue;
        }
        if (w->in_len + 16384 > w->in_cap) { w->in_cap = (w->in_len + 16384) * 2; w->in = realloc(w->in, w->in_cap); }
        pthread_mutex_lock(&w->mu);
        long r = w->closed ? -1 : ws_io_read(w, w->in + w->in_len, 16384);
        pthread_mutex_unlock(&w->mu);
        if (r == -2) { struct pollfd pf = { w->sock, POLLIN, 0 }; poll(&pf, 1, 100); continue; }
        if (r <= 0) { free(msg); return w->closed ? -999 : -1005; }
        w->in_len += (size_t)r;
    }
    if (!msg) msg = malloc(1);
    msg[mlen] = 0;
    *kind = k == 1 ? 1 : 2; *data = msg; *len = (long)mlen;
    return 0;
}

void isim_ws_close(struct isim_ws *w) {
    if (!w) return;
    w->closed = 1;
    pthread_mutex_lock(&w->mu);              /* waits for a read or write in progress */
    if (w->tls) { isim_tls_close(w->tls); w->tls = NULL; }
    shutdown(w->sock, SHUT_RDWR); close(w->sock); w->sock = -1;
    pthread_mutex_unlock(&w->mu);
    /* the struct is leaked on purpose: a receiving thread may still look at it once */
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
