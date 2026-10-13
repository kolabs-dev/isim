/* isim host: TLS and DTLS sessions over an app's connected socket, for the Network framework's NWConnection
 * with NWParameters.tls / .dtls, as a client or (with a server identity, for NWListener) as a server. Uses the host's OpenSSL 3 libssl (dlopen'ed on first use; without it TLS
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

typedef void SSL_CTX, SSL, SSL_METHOD, X509, X509_NAME, X509_PUBKEY, EVP_PKEY, EVP_MD, OPENSSL_STACK, BIO;
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
    /* servers, client identities and DTLS */
    const SSL_METHOD *(*TLS_server_method)(void);
    const SSL_METHOD *(*DTLS_client_method)(void);
    const SSL_METHOD *(*DTLS_server_method)(void);
    int (*SSL_accept)(SSL *);
    int (*SSL_CTX_use_certificate)(SSL_CTX *, X509 *);
    int (*SSL_CTX_use_PrivateKey)(SSL_CTX *, EVP_PKEY *);
    int (*SSL_CTX_check_private_key)(const SSL_CTX *);
    void (*SSL_CTX_set_alpn_select_cb)(SSL_CTX *, int (*)(SSL *, const unsigned char **, unsigned char *, const unsigned char *, unsigned int, void *), void *);
    int (*SSL_select_next_proto)(unsigned char **, unsigned char *, const unsigned char *, unsigned int, const unsigned char *, unsigned int);
    void (*SSL_set_bio)(SSL *, BIO *, BIO *);
    BIO *(*BIO_new_dgram)(int, int);
    long (*BIO_ctrl)(BIO *, int, long, void *);
    BIO *(*BIO_new_mem_buf)(const void *, int);
    int (*BIO_free)(BIO *);
    X509 *(*PEM_read_bio_X509)(BIO *, X509 **, void *, void *);
    X509 *(*SSL_get1_peer_certificate)(const SSL *);
    EVP_PKEY *(*PEM_read_bio_PrivateKey)(BIO *, EVP_PKEY **, void *, void *);
    void (*X509_free)(X509 *);
    void (*EVP_PKEY_free)(EVP_PKEY *);
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
            S(TLS_server_method); S(DTLS_client_method); S(DTLS_server_method); S(SSL_accept); S(SSL_CTX_use_certificate);
            S(SSL_CTX_use_PrivateKey); S(SSL_CTX_check_private_key); S(SSL_CTX_set_alpn_select_cb); S(SSL_select_next_proto); S(SSL_set_bio);
            C(BIO_new_dgram); C(BIO_ctrl); C(BIO_new_mem_buf); C(BIO_free); C(PEM_read_bio_X509); C(PEM_read_bio_PrivateKey);
            C(X509_free); C(EVP_PKEY_free); S(SSL_get1_peer_certificate);
            L.ok = L.TLS_client_method && L.SSL_CTX_new && L.SSL_new && L.SSL_set_fd && L.SSL_connect && L.SSL_read && L.SSL_write && L.SSL_ctrl
                   && L.SSL_set1_host && L.SSL_CTX_set_verify && L.SSL_get_verify_result && L.ERR_get_error && L.ERR_error_string_n;
        }
    }
    pthread_mutex_unlock(&lk);
    return L.ok;
}

struct isim_tls { SSL_CTX *ctx; SSL *ssl; unsigned char alpn[256]; unsigned alpn_len; };

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

/* comma-separated ALPN protocols in wire format (length-prefixed) */
static unsigned alpn_wire(const char *alpn, unsigned char *wire, unsigned cap) {
    unsigned n = 0;
    if (!alpn || !*alpn) return 0;
    char *dup = strdup(alpn), *save = NULL;
    for (char *p = strtok_r(dup, ",", &save); p && n < cap - 1; p = strtok_r(NULL, ",", &save)) {
        size_t l = strlen(p); if (l > 255 || n + 1 + l > cap) break;
        wire[n++] = (unsigned char)l; memcpy(wire + n, p, l); n += l;
    }
    free(dup);
    return n;
}
/* a server picks the first of its protocols that the client offers */
static int alpn_select(SSL *ssl, const unsigned char **out, unsigned char *outlen, const unsigned char *in, unsigned int inlen, void *arg) {
    struct isim_tls *t = arg;
    (void)ssl;
    for (unsigned i = 0; i < t->alpn_len; i += 1 + t->alpn[i])
        for (unsigned j = 0; j < inlen; j += 1 + in[j])
            if (t->alpn[i] == in[j] && memcmp(t->alpn + i + 1, in + j + 1, t->alpn[i]) == 0) {
                *out = t->alpn + i + 1; *outlen = t->alpn[i]; return 0;   /* SSL_TLSEXT_ERR_OK */
            }
    return 3;                                                               /* SSL_TLSEXT_ERR_NOACK */
}
/* the app's verify block decides (sec_protocol_options_set_verify_block): OpenSSL accepts any peer certificate */
static int accept_any(int ok, void *store) { (void)ok; (void)store; return 1; }

/* loads an identity (PEM: the certificate, more certificates of its chain, the private key) into a context */
static int use_identity(SSL_CTX *ctx, const char *pem, char *err, int errlen) {
    if (!L.BIO_new_mem_buf || !L.PEM_read_bio_X509 || !L.PEM_read_bio_PrivateKey || !L.SSL_CTX_use_certificate || !L.SSL_CTX_use_PrivateKey) {
        snprintf(err, errlen, "the host's OpenSSL cannot load identities"); return 0;
    }
    BIO *b = L.BIO_new_mem_buf(pem, -1);
    X509 *leaf = L.PEM_read_bio_X509(b, NULL, NULL, NULL);
    int ok = leaf && L.SSL_CTX_use_certificate(ctx, leaf) == 1;
    if (leaf) L.X509_free(leaf);
    X509 *extra;
    while (ok && (extra = L.PEM_read_bio_X509(b, NULL, NULL, NULL)))   /* SSL_CTX_add_extra_chain_cert takes ownership */
        L.SSL_CTX_ctrl(ctx, 14 /* SSL_CTRL_EXTRA_CHAIN_CERT */, 0, extra);
    L.BIO_free(b);
    b = L.BIO_new_mem_buf(pem, -1);
    EVP_PKEY *key = ok ? L.PEM_read_bio_PrivateKey(b, NULL, NULL, NULL) : NULL;
    L.BIO_free(b);
    ok = ok && key && L.SSL_CTX_use_PrivateKey(ctx, key) == 1 && (!L.SSL_CTX_check_private_key || L.SSL_CTX_check_private_key(ctx) == 1);
    if (key) L.EVP_PKEY_free(key);
    if (!ok) snprintf(err, errlen, "the identity's certificate or private key cannot be used");
    return ok;
}

/* A TLS (dtls 0: a connected stream socket) or DTLS (dtls 1: a connected datagram socket) handshake, as the client
 * (server 0) or the server (server 1). verify, for a client: 1 = CA store + host name, 0 = accept any certificate (the
 * app's verify block decides); for a server: 0 = no client certificate, 1 = require one (accepted, the verify block
 * decides), 2 = ask for one. identity: PEM certificate(s) and private key (a server's identity, a client's
 * certificate) or NULL. alpn: comma-separated protocols or NULL. Returns a session or NULL with a message in err;
 * *code gets -9807 (errSSLXCertChainInvalid) for certificate failures, -9806 (errSSLClosedAbort) otherwise. */
struct isim_tls *isim_tls_start(int fd, int server, int dtls, const char *host, int verify, const char *alpn, int min_version,
                                const char *identity, char *err, int errlen, int *code) {
    if (code) *code = -9806;
    if (!load()) { snprintf(err, errlen, "TLS needs the host's OpenSSL 3 libssl.so.3"); return NULL; }
    const SSL_METHOD *(*method)(void) = dtls ? (server ? L.DTLS_server_method : L.DTLS_client_method) : (server ? L.TLS_server_method : L.TLS_client_method);
    if (!method || (dtls && (!L.BIO_new_dgram || !L.SSL_set_bio))) { snprintf(err, errlen, "the host's OpenSSL has no %s %s", dtls ? "DTLS" : "TLS", server ? "server" : "client"); return NULL; }
    if (server && (!identity || !*identity)) { snprintf(err, errlen, "a TLS server needs an identity (sec_protocol_options_set_local_identity)"); return NULL; }
    struct isim_tls *t = calloc(1, sizeof *t);
    t->ctx = L.SSL_CTX_new(method());
    if (!t->ctx) { snprintf(err, errlen, "SSL_CTX_new failed"); free(t); return NULL; }
    if (identity && *identity && !use_identity(t->ctx, identity, err, errlen)) { L.SSL_CTX_free(t->ctx); free(t); return NULL; }
    if (server) {
        if (verify) L.SSL_CTX_set_verify(t->ctx, 1 /* SSL_VERIFY_PEER */ | (verify == 1 ? 2 /* FAIL_IF_NO_PEER_CERT */ : 0), accept_any);
        else L.SSL_CTX_set_verify(t->ctx, 0, NULL);
        t->alpn_len = alpn_wire(alpn, t->alpn, sizeof t->alpn);
        if (t->alpn_len && L.SSL_CTX_set_alpn_select_cb) L.SSL_CTX_set_alpn_select_cb(t->ctx, alpn_select, t);
    } else {
        if (verify && L.SSL_CTX_set_default_verify_paths) L.SSL_CTX_set_default_verify_paths(t->ctx);
        L.SSL_CTX_set_verify(t->ctx, verify ? 1 /* SSL_VERIFY_PEER */ : 0, NULL);
    }
    if (min_version > 0 && !dtls && L.SSL_CTX_ctrl) L.SSL_CTX_ctrl(t->ctx, 123 /* SSL_CTRL_SET_MIN_PROTO_VERSION */, min_version, NULL);
    t->ssl = L.SSL_new(t->ctx);
    if (dtls) {
        BIO *bio = L.BIO_new_dgram(fd, 0 /* BIO_NOCLOSE */);
        struct sockaddr_storage peer; socklen_t pl = sizeof peer;
        if (getpeername(fd, (struct sockaddr *)&peer, &pl) == 0) L.BIO_ctrl(bio, 32 /* BIO_CTRL_DGRAM_SET_CONNECTED */, 0, &peer);
        L.SSL_set_bio(t->ssl, bio, bio);
    } else L.SSL_set_fd(t->ssl, fd);
    if (!server && host && *host) {
        L.SSL_ctrl(t->ssl, 55 /* SSL_CTRL_SET_TLSEXT_HOSTNAME */, 0 /* TLSEXT_NAMETYPE_host_name */, (void *)host);
        if (verify) L.SSL_set1_host(t->ssl, host);
    }
    if (!server && alpn && *alpn && L.SSL_set_alpn_protos) {
        unsigned char wire[256]; unsigned n = alpn_wire(alpn, wire, sizeof wire);
        L.SSL_set_alpn_protos(t->ssl, wire, n);
    }
    sigset_t om; nopipe_begin(&om);
    int crc = server ? L.SSL_accept(t->ssl) : L.SSL_connect(t->ssl);
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
            snprintf(err, errlen, "%s handshake failed: %s", dtls ? "DTLS" : "TLS", buf);
        }
        L.SSL_free(t->ssl); L.SSL_CTX_free(t->ctx); free(t);
        return NULL;
    }
    return t;
}
/* TLS client handshake on a connected blocking socket (see isim_tls_start) */
struct isim_tls *isim_tls_connect(int fd, const char *host, int verify, const char *alpn, int min_version, char *err, int errlen, int *code) {
    return isim_tls_start(fd, 0, 0, host, verify, alpn, min_version, NULL, err, errlen, code);
}
/* the peer's certificates (DER, leaf first) concatenated into out, their sizes in lens: how many */
int isim_tls_peer_chain(struct isim_tls *t, unsigned char *out, long cap, long *lens, int max) {
    int n = 0; long used = 0;
    /* the peer's own certificate first: a server's view of the chain leaves the client's certificate out */
    X509 *leaf = L.SSL_get1_peer_certificate ? L.SSL_get1_peer_certificate(t->ssl) : NULL;
    if (leaf) {
        unsigned char *der = NULL; int dl = L.i2d_X509(leaf, &der);
        if (dl > 0 && dl <= cap && max > 0) { memcpy(out, der, (size_t)dl); lens[n++] = dl; used = dl; }
        if (der) L.CRYPTO_free(der, __FILE__, __LINE__);
        L.X509_free(leaf);
    }
    OPENSSL_STACK *st = L.SSL_get_peer_cert_chain ? L.SSL_get_peer_cert_chain(t->ssl) : NULL;
    for (int i = 0, m = st ? L.OPENSSL_sk_num(st) : 0; i < m && n < max; i++) {
        unsigned char *der = NULL; int dl = L.i2d_X509(L.OPENSSL_sk_value(st, i), &der);
        int dup = n > 0 && dl == lens[0] && memcmp(out, der, (size_t)dl) == 0;    /* the leaf again (a client's view) */
        if (dl > 0 && !dup && used + dl <= cap) { memcpy(out + used, der, (size_t)dl); lens[n++] = dl; used += dl; }
        if (der) L.CRYPTO_free(der, __FILE__, __LINE__);
    }
    return n;
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
