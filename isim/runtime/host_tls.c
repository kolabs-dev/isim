/* isim host: TLS client sessions over an app's connected socket, for the Network framework's NWConnection
 * with NWParameters.tls. Uses the host's OpenSSL 3 libssl (dlopen'ed on first use; without it TLS
 * connections fail with a clear message). Certificates are checked against the host's CA store and the host
 * name, unless the app installed its own verify block (then the app decides, as with sec_protocol_options). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <signal.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef void SSL_CTX, SSL, SSL_METHOD;
static struct {
    int tried, ok;
    const SSL_METHOD *(*TLS_client_method)(void);
    SSL_CTX *(*SSL_CTX_new)(const SSL_METHOD *);
    void (*SSL_CTX_free)(SSL_CTX *);
    int (*SSL_CTX_set_default_verify_paths)(SSL_CTX *);
    void (*SSL_CTX_set_verify)(SSL_CTX *, int, void *);
    long (*SSL_CTX_ctrl)(SSL_CTX *, int, long, void *);
    SSL *(*SSL_new)(SSL_CTX *);
    void (*SSL_free)(SSL *);
    int (*SSL_set_fd)(SSL *, int);
    long (*SSL_ctrl)(SSL *, int, long, void *);
    int (*SSL_set1_host)(SSL *, const char *);
    int (*SSL_set_alpn_protos)(SSL *, const unsigned char *, unsigned int);
    void (*SSL_get0_alpn_selected)(const SSL *, const unsigned char **, unsigned int *);
    int (*SSL_connect)(SSL *);
    int (*SSL_read)(SSL *, void *, int);
    int (*SSL_write)(SSL *, const void *, int);
    int (*SSL_shutdown)(SSL *);
    int (*SSL_get_error)(const SSL *, int);
    long (*SSL_get_verify_result)(const SSL *);
    const char *(*SSL_get_version)(const SSL *);
    unsigned long (*ERR_get_error)(void);
    void (*ERR_error_string_n)(unsigned long, char *, size_t);
    const char *(*X509_verify_cert_error_string)(long);
} L;
static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;

static int load(void) {
    pthread_mutex_lock(&lk);
    if (!L.tried) {
        L.tried = 1;
        void *s = dlopen("libssl.so.3", RTLD_NOW | RTLD_LOCAL), *c = dlopen("libcrypto.so.3", RTLD_NOW | RTLD_LOCAL);
        if (s && c) {
#define S(n) L.n = dlsym(s, #n)
#define C(n) L.n = dlsym(c, #n)
            S(TLS_client_method); S(SSL_CTX_new); S(SSL_CTX_free); S(SSL_CTX_set_default_verify_paths); S(SSL_CTX_set_verify); S(SSL_CTX_ctrl);
            S(SSL_new); S(SSL_free); S(SSL_set_fd); S(SSL_ctrl); S(SSL_set1_host); S(SSL_set_alpn_protos); S(SSL_get0_alpn_selected);
            S(SSL_connect); S(SSL_read); S(SSL_write); S(SSL_shutdown); S(SSL_get_error); S(SSL_get_verify_result); S(SSL_get_version);
            C(ERR_get_error); C(ERR_error_string_n); C(X509_verify_cert_error_string);
            L.ok = L.TLS_client_method && L.SSL_CTX_new && L.SSL_new && L.SSL_set_fd && L.SSL_connect && L.SSL_read && L.SSL_write && L.SSL_ctrl
                   && L.SSL_set1_host && L.SSL_CTX_set_verify && L.SSL_get_verify_result && L.ERR_get_error && L.ERR_error_string_n;
        }
    }
    pthread_mutex_unlock(&lk);
    return L.ok;
}

struct isim_tls { SSL_CTX *ctx; SSL *ssl; };

/* OpenSSL writes with write(): a peer that went away would raise SIGPIPE and kill the app. Block it on this
   thread around TLS calls and swallow one that became pending (sockets on isim report EPIPE instead). */
static void nopipe_begin(sigset_t *old) {
    sigset_t s; sigemptyset(&s); sigaddset(&s, SIGPIPE);
    pthread_sigmask(SIG_BLOCK, &s, old);
}
static void nopipe_end(const sigset_t *old) {
    sigset_t pend; sigemptyset(&pend);
    if (sigpending(&pend) == 0 && sigismember(&pend, SIGPIPE)) {
        sigset_t s; sigemptyset(&s); sigaddset(&s, SIGPIPE);
        struct timespec zero = { 0, 0 };
        sigtimedwait(&s, NULL, &zero);
    }
    pthread_sigmask(SIG_SETMASK, old, NULL);
}

/* TLS handshake on a connected blocking socket. verify: 1 = CA store + host name, 0 = accept any certificate.
   alpn: comma-separated protocols or NULL. Returns a session or NULL with a message in err; *code gets
   -9807 (errSSLXCertChainInvalid) for certificate failures, -9806 (errSSLClosedAbort) otherwise. */
struct isim_tls *isim_tls_connect(int fd, const char *host, int verify, const char *alpn, int min_version, char *err, int errlen, int *code) {
    if (code) *code = -9806;
    if (!load()) { snprintf(err, errlen, "TLS needs the host's OpenSSL 3 libssl.so.3"); return NULL; }
    struct isim_tls *t = calloc(1, sizeof *t);
    t->ctx = L.SSL_CTX_new(L.TLS_client_method());
    if (!t->ctx) { snprintf(err, errlen, "SSL_CTX_new failed"); free(t); return NULL; }
    if (verify && L.SSL_CTX_set_default_verify_paths) L.SSL_CTX_set_default_verify_paths(t->ctx);
    L.SSL_CTX_set_verify(t->ctx, verify ? 1 /* SSL_VERIFY_PEER */ : 0, NULL);
    if (min_version > 0 && L.SSL_CTX_ctrl) L.SSL_CTX_ctrl(t->ctx, 123 /* SSL_CTRL_SET_MIN_PROTO_VERSION */, min_version, NULL);
    t->ssl = L.SSL_new(t->ctx);
    L.SSL_set_fd(t->ssl, fd);
    if (host && *host) {
        L.SSL_ctrl(t->ssl, 55 /* SSL_CTRL_SET_TLSEXT_HOSTNAME */, 0 /* TLSEXT_NAMETYPE_host_name */, (void *)host);
        if (verify) L.SSL_set1_host(t->ssl, host);
    }
    if (alpn && *alpn && L.SSL_set_alpn_protos) {
        unsigned char wire[256]; unsigned n = 0;
        char *dup = strdup(alpn), *save = NULL;
        for (char *p = strtok_r(dup, ",", &save); p && n < sizeof wire - 1; p = strtok_r(NULL, ",", &save)) {
            size_t l = strlen(p); if (l > 255 || n + 1 + l > sizeof wire) break;
            wire[n++] = (unsigned char)l; memcpy(wire + n, p, l); n += l;
        }
        free(dup);
        L.SSL_set_alpn_protos(t->ssl, wire, n);
    }
    sigset_t om; nopipe_begin(&om);
    int crc = L.SSL_connect(t->ssl);
    nopipe_end(&om);
    if (crc != 1) {
        long vr = L.SSL_get_verify_result(t->ssl);
        if (vr != 0) {
            snprintf(err, errlen, "certificate verify failed: %s", L.X509_verify_cert_error_string ? L.X509_verify_cert_error_string(vr) : "?");
            if (code) *code = -9807;
        } else {
            unsigned long e = L.ERR_get_error();
            char buf[256] = "handshake failed";
            if (e) L.ERR_error_string_n(e, buf, sizeof buf);
            snprintf(err, errlen, "TLS handshake failed: %s", buf);
        }
        L.SSL_free(t->ssl); L.SSL_CTX_free(t->ctx); free(t);
        return NULL;
    }
    return t;
}
/* bytes read (0 = closed by the peer, < 0 error) */
long isim_tls_read(struct isim_tls *t, void *buf, long n) {
    sigset_t om; nopipe_begin(&om);
    int r = L.SSL_read(t->ssl, buf, (int)(n > 1 << 30 ? 1 << 30 : n));
    nopipe_end(&om);
    if (r > 0) return r;
    int e = L.SSL_get_error(t->ssl, r);
    return e == 6 /* SSL_ERROR_ZERO_RETURN */ ? 0 : -1;
}
long isim_tls_write(struct isim_tls *t, const void *buf, long n) {
    long done = 0;
    sigset_t om; nopipe_begin(&om);
    while (done < n) {
        int r = L.SSL_write(t->ssl, (const char *)buf + done, (int)(n - done > 1 << 30 ? 1 << 30 : n - done));
        if (r <= 0) break;
        done += r;
    }
    nopipe_end(&om);
    return done ? done : -1;
}
/* negotiated protocol version ("TLSv1.3") and ALPN protocol into the buffers */
void isim_tls_info(struct isim_tls *t, char *version, int vlen, char *alpn, int alen) {
    if (version && vlen > 0) snprintf(version, vlen, "%s", L.SSL_get_version ? L.SSL_get_version(t->ssl) : "");
    if (alpn && alen > 0) {
        const unsigned char *p = NULL; unsigned int n = 0;
        if (L.SSL_get0_alpn_selected) L.SSL_get0_alpn_selected(t->ssl, &p, &n);
        snprintf(alpn, alen, "%.*s", (int)n, p ? (const char *)p : "");
    }
}
void isim_tls_close(struct isim_tls *t) {
    if (!t) return;
    sigset_t om; nopipe_begin(&om);
    if (L.SSL_shutdown) L.SSL_shutdown(t->ssl);
    nopipe_end(&om);
    L.SSL_free(t->ssl); L.SSL_CTX_free(t->ctx); free(t);
}
