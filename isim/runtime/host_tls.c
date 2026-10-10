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
#include <errno.h>
#include <fcntl.h>
#include <netdb.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

typedef void SSL_CTX, SSL, SSL_METHOD, X509, X509_NAME, X509_PUBKEY, EVP_PKEY, EVP_MD, OPENSSL_STACK;
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
    /* the probe (isim_tls_probe): the server's chain and key, and its client-certificate request */
    OPENSSL_STACK *(*SSL_get_peer_cert_chain)(const SSL *);
    OPENSSL_STACK *(*SSL_get_client_CA_list)(const SSL *);
    void (*SSL_CTX_set_client_cert_cb)(SSL_CTX *, int (*)(SSL *, X509 **, EVP_PKEY **));
    int (*OPENSSL_sk_num)(const OPENSSL_STACK *);
    void *(*OPENSSL_sk_value)(const OPENSSL_STACK *, int);
    int (*i2d_X509)(X509 *, unsigned char **);
    int (*i2d_X509_NAME)(const X509_NAME *, unsigned char **);
    X509_PUBKEY *(*X509_get_X509_PUBKEY)(const X509 *);
    int (*i2d_X509_PUBKEY)(const X509_PUBKEY *, unsigned char **);
    int (*EVP_Digest)(const void *, size_t, unsigned char *, unsigned int *, const EVP_MD *, void *);
    const EVP_MD *(*EVP_sha256)(void);
    void (*CRYPTO_free)(void *, const char *, int);
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
            S(SSL_get_peer_cert_chain); S(SSL_get_client_CA_list); S(SSL_CTX_set_client_cert_cb);
            C(OPENSSL_sk_num); C(OPENSSL_sk_value); C(i2d_X509); C(i2d_X509_NAME); C(X509_get_X509_PUBKEY); C(i2d_X509_PUBKEY);
            C(EVP_Digest); C(EVP_sha256); C(CRYPTO_free);
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
/* For a non-blocking socket (one session shared by a reading and a writing thread, each call under the caller's
   lock): bytes read or written, 0 = closed by the peer (read), -1 error, -2 would block (poll the socket and retry;
   SSL_pending data is returned by the next call without waiting). */
long isim_tls_read_nb(struct isim_tls *t, void *buf, long n) {
    sigset_t om; nopipe_begin(&om);
    int r = L.SSL_read(t->ssl, buf, (int)(n > 1 << 30 ? 1 << 30 : n));
    int e = r > 0 ? 0 : L.SSL_get_error(t->ssl, r);
    nopipe_end(&om);
    if (r > 0) return r;
    return e == 2 || e == 3 /* SSL_ERROR_WANT_READ / WRITE */ ? -2 : e == 6 /* ZERO_RETURN */ ? 0 : -1;
}
long isim_tls_write_nb(struct isim_tls *t, const void *buf, long n) {
    sigset_t om; nopipe_begin(&om);
    int r = L.SSL_write(t->ssl, buf, (int)(n > 1 << 30 ? 1 << 30 : n));
    int e = r > 0 ? 0 : L.SSL_get_error(t->ssl, r);
    nopipe_end(&om);
    if (r > 0) return r;
    return e == 2 || e == 3 ? -2 : -1;
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

/* --- isim_tls_probe: what URLSession's trust and client-certificate challenges show, before libcurl connects --- */
struct probe {
    unsigned char *chain; long cap, used; long *lens; int max, n;          /* the server's certificates (DER) */
    int client_requested;
    unsigned char *dn; long dncap, dnused; long *dnlens; int dnmax, ndn;   /* the CA names it accepts (DER) */
};
static __thread struct probe *cur_probe;

static void probe_chain(SSL *ssl, struct probe *p) {
    OPENSSL_STACK *st = L.SSL_get_peer_cert_chain ? L.SSL_get_peer_cert_chain(ssl) : NULL;
    if (!st || p->n) return;
    for (int i = 0, m = L.OPENSSL_sk_num(st); i < m && p->n < p->max; i++) {
        unsigned char *der = NULL; int dl = L.i2d_X509(L.OPENSSL_sk_value(st, i), &der);
        if (dl > 0 && p->used + dl <= p->cap) { memcpy(p->chain + p->used, der, (size_t)dl); p->lens[p->n++] = dl; p->used += dl; }
        if (der) L.CRYPTO_free(der, __FILE__, __LINE__);
    }
}
/* the server asked for a client certificate: remember it and its CA names, send none */
static int probe_client_cert(SSL *ssl, X509 **x, EVP_PKEY **k) {
    struct probe *p = cur_probe;
    if (!p) return 0;
    p->client_requested = 1;
    probe_chain(ssl, p);
    OPENSSL_STACK *names = L.SSL_get_client_CA_list ? L.SSL_get_client_CA_list(ssl) : NULL;
    for (int i = 0, m = names ? L.OPENSSL_sk_num(names) : 0; i < m && p->ndn < p->dnmax; i++) {
        unsigned char *der = NULL; int dl = L.i2d_X509_NAME(L.OPENSSL_sk_value(names, i), &der);
        if (dl > 0 && p->dnused + dl <= p->dncap) { memcpy(p->dn + p->dnused, der, (size_t)dl); p->dnlens[p->ndn++] = dl; p->dnused += dl; }
        if (der) L.CRYPTO_free(der, __FILE__, __LINE__);
    }
    return 0;
}

/* Connects to host:port and runs a TLS handshake that accepts any certificate, to learn the server's certificate
 * chain (DER, concatenated into chain with sizes in lens, leaf first), its key pin ("sha256//<base64 of the SHA-256
 * of the leaf's SubjectPublicKeyInfo>", libcurl's CURLOPT_PINNEDPUBLICKEY form) and whether it asks for a client
 * certificate (*client_requested, with the DER names of the CAs it accepts in dn / dnlens). Returns 1, or 0 with a
 * message in err when the server cannot be reached or does not speak TLS. */
int isim_tls_probe(const char *host, int port, double timeout, unsigned char *chain, long cap, long *lens, int maxcerts, int *ncerts,
                   char *pin, int pincap, int *client_requested, unsigned char *dn, long dncap, long *dnlens, int maxdn, int *ndn,
                   char *err, int errlen) {
    *ncerts = 0; *ndn = 0; *client_requested = 0; if (pincap > 0) pin[0] = 0; if (errlen > 0) err[0] = 0;
    if (!load() || !L.SSL_get_peer_cert_chain || !L.OPENSSL_sk_num || !L.i2d_X509 || !L.EVP_Digest || !L.CRYPTO_free) {
        snprintf(err, errlen, "TLS needs the host's OpenSSL 3 libssl.so.3"); return 0;
    }
    char ps[16]; snprintf(ps, sizeof ps, "%d", port);
    struct addrinfo hints = { .ai_family = AF_UNSPEC, .ai_socktype = SOCK_STREAM }, *res = NULL;
    if (getaddrinfo(host, ps, &hints, &res) != 0 || !res) { snprintf(err, errlen, "cannot find host %s", host); return 0; }
    int ms = timeout > 0 && timeout < 600 ? (int)(timeout * 1000) : 60000, fd = -1;
    for (struct addrinfo *a = res; a && fd < 0; a = a->ai_next) {
        int s = socket(a->ai_family, a->ai_socktype | SOCK_NONBLOCK | SOCK_CLOEXEC, a->ai_protocol);
        if (s < 0) continue;
        if (connect(s, a->ai_addr, a->ai_addrlen) == 0) { fd = s; break; }
        if (errno == EINPROGRESS) {
            struct pollfd pf = { s, POLLOUT, 0 }; int so = 0; socklen_t sl = sizeof so;
            if (poll(&pf, 1, ms) > 0 && getsockopt(s, SOL_SOCKET, SO_ERROR, &so, &sl) == 0 && so == 0) { fd = s; break; }
        }
        close(s);
    }
    freeaddrinfo(res);
    if (fd < 0) { snprintf(err, errlen, "cannot connect to %s:%d", host, port); return 0; }
    fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_NONBLOCK);
    struct timeval tv = { ms / 1000, (ms % 1000) * 1000 };
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv); setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);

    struct probe p = { chain, cap, 0, lens, maxcerts, 0, 0, dn, dncap, 0, dnlens, maxdn, 0 };
    SSL_CTX *ctx = L.SSL_CTX_new(L.TLS_client_method());
    if (!ctx) { close(fd); snprintf(err, errlen, "SSL_CTX_new failed"); return 0; }
    L.SSL_CTX_set_verify(ctx, 0, NULL);
    if (L.SSL_CTX_set_client_cert_cb) L.SSL_CTX_set_client_cert_cb(ctx, probe_client_cert);
    SSL *ssl = L.SSL_new(ctx);
    L.SSL_set_fd(ssl, fd);
    L.SSL_ctrl(ssl, 55 /* SSL_CTRL_SET_TLSEXT_HOSTNAME */, 0, (void *)host);
    unsigned char alpn[] = "\x08http/1.1";
    if (L.SSL_set_alpn_protos) L.SSL_set_alpn_protos(ssl, alpn, sizeof alpn - 1);
    sigset_t om; nopipe_begin(&om);
    cur_probe = &p;
    int crc = L.SSL_connect(ssl);
    cur_probe = NULL;
    probe_chain(ssl, &p);
    if (L.SSL_shutdown && crc == 1) L.SSL_shutdown(ssl);
    nopipe_end(&om);
    if (p.n > 0 && L.X509_get_X509_PUBKEY && L.i2d_X509_PUBKEY && L.EVP_sha256) {
        /* the leaf's SubjectPublicKeyInfo */
        OPENSSL_STACK *st = L.SSL_get_peer_cert_chain(ssl);
        X509 *leaf = st && L.OPENSSL_sk_num(st) > 0 ? L.OPENSSL_sk_value(st, 0) : NULL;
        unsigned char *spki = NULL; int sl = leaf ? L.i2d_X509_PUBKEY(L.X509_get_X509_PUBKEY(leaf), &spki) : 0;
        if (sl > 0) {
            unsigned char md[32]; unsigned int mdl = 0;
            if (L.EVP_Digest(spki, (size_t)sl, md, &mdl, L.EVP_sha256(), NULL) == 1 && pincap > 60) {
                static const char b64[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
                int o = snprintf(pin, pincap, "sha256//");
                for (unsigned i = 0; i < mdl; i += 3) {
                    unsigned v = md[i] << 16 | (i + 1 < mdl ? md[i + 1] << 8 : 0) | (i + 2 < mdl ? md[i + 2] : 0);
                    pin[o++] = b64[v >> 18]; pin[o++] = b64[v >> 12 & 63];
                    pin[o++] = i + 1 < mdl ? b64[v >> 6 & 63] : '='; pin[o++] = i + 2 < mdl ? b64[v & 63] : '=';
                }
                pin[o] = 0;
            }
        }
        if (spki) L.CRYPTO_free(spki, __FILE__, __LINE__);
    }
    L.SSL_free(ssl); L.SSL_CTX_free(ctx); close(fd);
    *ncerts = p.n; *ndn = p.ndn; *client_requested = p.client_requested;
    if (p.n == 0) {
        unsigned long e = L.ERR_get_error(); char buf[256] = "no server certificate";
        if (e) L.ERR_error_string_n(e, buf, sizeof buf);
        snprintf(err, errlen, "TLS handshake failed: %s", buf);
        return 0;
    }
    return 1;
}
