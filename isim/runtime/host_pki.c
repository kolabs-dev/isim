/* isim public-key infrastructure on the host: SecKey operations (RSA and NIST EC keys), X.509 certificate
 * parsing, trust evaluation and PKCS#12 import for isim's Security module, through the host's OpenSSL libcrypto
 * (dlopen'ed on first use, like host_crypto.c).
 *
 * Keys cross the boundary in Apple's external representations (what SecKeyCopyExternalRepresentation returns):
 *   RSA public  PKCS#1 RSAPublicKey DER          RSA private  PKCS#1 RSAPrivateKey DER
 *   EC public   X9.63 04 || X || Y               EC private   04 || X || Y || D   (P-256, P-384, P-521)
 * All functions return 1 on success, 0 on failure (isim_pki_error() describes the last failure on this thread). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include "runtime.h"

typedef struct evp_pkey_st EVP_PKEY; typedef struct evp_pkey_ctx_st EVP_PKEY_CTX; typedef struct evp_md_ctx_st EVP_MD_CTX;
typedef struct evp_md_st EVP_MD; typedef struct ec_key_st EC_KEY; typedef struct ec_group_st EC_GROUP; typedef struct ec_point_st EC_POINT;
typedef struct bignum_st BIGNUM; typedef struct ecdsa_sig_st ECDSA_SIG; typedef struct x509_st X509; typedef struct x509_name_st X509_NAME;
typedef struct x509_name_entry_st X509_NAME_ENTRY; typedef struct asn1_string_st ASN1_STRING; typedef struct asn1_object_st ASN1_OBJECT;
typedef struct x509_store_st X509_STORE; typedef struct x509_store_ctx_st X509_STORE_CTX; typedef struct X509_VERIFY_PARAM_st X509_VERIFY_PARAM;
typedef struct stack_st OPENSSL_STACK; typedef struct pkcs12_st PKCS12;
struct tm;

#define PKI_FUNCS(X) \
    X(EVP_PKEY *, EVP_PKEY_Q_keygen, (void *, const char *, const char *, ...)) \
    X(EVP_PKEY *, EVP_PKEY_new, (void)) X(void, EVP_PKEY_free, (EVP_PKEY *)) X(int, EVP_PKEY_get_bits, (const EVP_PKEY *)) \
    X(int, EVP_PKEY_get_base_id, (const EVP_PKEY *)) X(int, EVP_PKEY_set1_EC_KEY, (EVP_PKEY *, EC_KEY *)) \
    X(EC_KEY *, EVP_PKEY_get1_EC_KEY, (EVP_PKEY *)) \
    X(EVP_PKEY *, d2i_PrivateKey, (int, EVP_PKEY **, const unsigned char **, long)) \
    X(EVP_PKEY *, d2i_PublicKey, (int, EVP_PKEY **, const unsigned char **, long)) \
    X(int, i2d_PrivateKey, (const EVP_PKEY *, unsigned char **)) X(int, i2d_PublicKey, (const EVP_PKEY *, unsigned char **)) \
    X(EVP_PKEY_CTX *, EVP_PKEY_CTX_new, (EVP_PKEY *, void *)) X(void, EVP_PKEY_CTX_free, (EVP_PKEY_CTX *)) \
    X(int, EVP_PKEY_sign_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_sign, (EVP_PKEY_CTX *, unsigned char *, size_t *, const unsigned char *, size_t)) \
    X(int, EVP_PKEY_verify_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_verify, (EVP_PKEY_CTX *, const unsigned char *, size_t, const unsigned char *, size_t)) \
    X(int, EVP_PKEY_encrypt_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_encrypt, (EVP_PKEY_CTX *, unsigned char *, size_t *, const unsigned char *, size_t)) \
    X(int, EVP_PKEY_decrypt_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_decrypt, (EVP_PKEY_CTX *, unsigned char *, size_t *, const unsigned char *, size_t)) \
    X(int, EVP_PKEY_derive_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_derive_set_peer, (EVP_PKEY_CTX *, EVP_PKEY *)) \
    X(int, EVP_PKEY_derive, (EVP_PKEY_CTX *, unsigned char *, size_t *)) \
    X(int, EVP_PKEY_CTX_set_rsa_padding, (EVP_PKEY_CTX *, int)) X(int, EVP_PKEY_CTX_set_signature_md, (EVP_PKEY_CTX *, const EVP_MD *)) \
    X(int, EVP_PKEY_CTX_set_rsa_oaep_md, (EVP_PKEY_CTX *, const EVP_MD *)) X(int, EVP_PKEY_CTX_set_rsa_mgf1_md, (EVP_PKEY_CTX *, const EVP_MD *)) \
    X(int, EVP_PKEY_CTX_set_rsa_pss_saltlen, (EVP_PKEY_CTX *, int)) \
    X(EVP_MD_CTX *, EVP_MD_CTX_new, (void)) X(void, EVP_MD_CTX_free, (EVP_MD_CTX *)) \
    X(int, EVP_DigestSignInit, (EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *, void *, EVP_PKEY *)) \
    X(int, EVP_DigestSign, (EVP_MD_CTX *, unsigned char *, size_t *, const unsigned char *, size_t)) \
    X(int, EVP_DigestVerifyInit, (EVP_MD_CTX *, EVP_PKEY_CTX **, const EVP_MD *, void *, EVP_PKEY *)) \
    X(int, EVP_DigestVerify, (EVP_MD_CTX *, const unsigned char *, size_t, const unsigned char *, size_t)) \
    X(const EVP_MD *, EVP_sha1, (void)) X(const EVP_MD *, EVP_sha224, (void)) X(const EVP_MD *, EVP_sha256, (void)) \
    X(const EVP_MD *, EVP_sha384, (void)) X(const EVP_MD *, EVP_sha512, (void)) \
    X(EC_KEY *, EC_KEY_new_by_curve_name, (int)) X(void, EC_KEY_free, (EC_KEY *)) X(const EC_GROUP *, EC_KEY_get0_group, (const EC_KEY *)) \
    X(int, EC_KEY_set_private_key, (EC_KEY *, const BIGNUM *)) X(const BIGNUM *, EC_KEY_get0_private_key, (const EC_KEY *)) \
    X(int, EC_KEY_set_public_key, (EC_KEY *, const EC_POINT *)) X(const EC_POINT *, EC_KEY_get0_public_key, (const EC_KEY *)) \
    X(int, EC_KEY_check_key, (const EC_KEY *)) X(int, EC_GROUP_get_curve_name, (const EC_GROUP *)) \
    X(EC_POINT *, EC_POINT_new, (const EC_GROUP *)) X(void, EC_POINT_free, (EC_POINT *)) \
    X(size_t, EC_POINT_point2oct, (const EC_GROUP *, const EC_POINT *, int, unsigned char *, size_t, void *)) \
    X(int, EC_POINT_oct2point, (const EC_GROUP *, EC_POINT *, const unsigned char *, size_t, void *)) \
    X(BIGNUM *, BN_bin2bn, (const unsigned char *, int, BIGNUM *)) X(int, BN_bn2binpad, (const BIGNUM *, unsigned char *, int)) \
    X(int, BN_num_bits, (const BIGNUM *)) X(int, BN_bn2bin, (const BIGNUM *, unsigned char *)) X(void, BN_free, (BIGNUM *)) \
    X(ECDSA_SIG *, d2i_ECDSA_SIG, (ECDSA_SIG **, const unsigned char **, long)) X(int, i2d_ECDSA_SIG, (const ECDSA_SIG *, unsigned char **)) \
    X(ECDSA_SIG *, ECDSA_SIG_new, (void)) X(void, ECDSA_SIG_free, (ECDSA_SIG *)) \
    X(void, ECDSA_SIG_get0, (const ECDSA_SIG *, const BIGNUM **, const BIGNUM **)) X(int, ECDSA_SIG_set0, (ECDSA_SIG *, BIGNUM *, BIGNUM *)) \
    X(void, CRYPTO_free, (void *, const char *, int)) \
    X(X509 *, d2i_X509, (X509 **, const unsigned char **, long)) X(int, i2d_X509, (X509 *, unsigned char **)) X(void, X509_free, (X509 *)) \
    X(X509_NAME *, X509_get_subject_name, (const X509 *)) X(X509_NAME *, X509_get_issuer_name, (const X509 *)) \
    X(int, i2d_X509_NAME, (const X509_NAME *, unsigned char **)) \
    X(int, X509_NAME_entry_count, (const X509_NAME *)) X(X509_NAME_ENTRY *, X509_NAME_get_entry, (const X509_NAME *, int)) \
    X(ASN1_OBJECT *, X509_NAME_ENTRY_get_object, (const X509_NAME_ENTRY *)) X(ASN1_STRING *, X509_NAME_ENTRY_get_data, (const X509_NAME_ENTRY *)) \
    X(int, OBJ_obj2nid, (const ASN1_OBJECT *)) X(const char *, OBJ_nid2sn, (int)) X(int, OBJ_obj2txt, (char *, int, const ASN1_OBJECT *, int)) \
    X(int, ASN1_STRING_to_UTF8, (unsigned char **, const ASN1_STRING *)) \
    X(ASN1_STRING *, X509_get_serialNumber, (X509 *)) X(BIGNUM *, ASN1_INTEGER_to_BN, (const ASN1_STRING *, BIGNUM *)) \
    X(const ASN1_STRING *, X509_get0_notBefore, (const X509 *)) X(const ASN1_STRING *, X509_get0_notAfter, (const X509 *)) \
    X(int, ASN1_TIME_to_tm, (const ASN1_STRING *, struct tm *)) X(EVP_PKEY *, X509_get0_pubkey, (const X509 *)) \
    X(OPENSSL_STACK *, X509_get1_email, (X509 *)) X(void, X509_email_free, (OPENSSL_STACK *)) X(int, X509_check_ca, (X509 *)) \
    X(int, X509_check_issued, (X509 *, X509 *)) \
    X(OPENSSL_STACK *, OPENSSL_sk_new_null, (void)) X(int, OPENSSL_sk_push, (OPENSSL_STACK *, const void *)) \
    X(int, OPENSSL_sk_num, (const OPENSSL_STACK *)) X(void *, OPENSSL_sk_value, (const OPENSSL_STACK *, int)) X(void, OPENSSL_sk_free, (OPENSSL_STACK *)) \
    X(X509_STORE *, X509_STORE_new, (void)) X(void, X509_STORE_free, (X509_STORE *)) X(int, X509_STORE_add_cert, (X509_STORE *, X509 *)) \
    X(int, X509_STORE_set_default_paths, (X509_STORE *)) \
    X(X509_STORE_CTX *, X509_STORE_CTX_new, (void)) X(void, X509_STORE_CTX_free, (X509_STORE_CTX *)) \
    X(int, X509_STORE_CTX_init, (X509_STORE_CTX *, X509_STORE *, X509 *, OPENSSL_STACK *)) \
    X(void, X509_STORE_CTX_set_time, (X509_STORE_CTX *, unsigned long, time_t)) \
    X(int, X509_STORE_CTX_set_purpose, (X509_STORE_CTX *, int)) X(X509_VERIFY_PARAM *, X509_STORE_CTX_get0_param, (X509_STORE_CTX *)) \
    X(int, X509_VERIFY_PARAM_set1_host, (X509_VERIFY_PARAM *, const char *, size_t)) \
    X(int, X509_verify_cert, (X509_STORE_CTX *)) X(int, X509_STORE_CTX_get_error, (const X509_STORE_CTX *)) \
    X(const char *, X509_verify_cert_error_string, (long)) X(OPENSSL_STACK *, X509_STORE_CTX_get0_chain, (const X509_STORE_CTX *)) \
    X(PKCS12 *, d2i_PKCS12, (PKCS12 **, const unsigned char **, long)) X(void, PKCS12_free, (PKCS12 *)) \
    X(int, PKCS12_parse, (PKCS12 *, const char *, EVP_PKEY **, X509 **, OPENSSL_STACK **))

#define DECL(ret, name, args) ret (*name) args;
static struct { PKI_FUNCS(DECL) } P;
static int pki_state;
static pthread_once_t pki_once = PTHREAD_ONCE_INIT;
static __thread char pki_err[256];
static void fail(const char *m) { snprintf(pki_err, sizeof pki_err, "%s", m); }
const char *isim_pki_error(void) { return pki_err; }
static void pki_load(void) {
    void *h = dlopen("libcrypto.so.3", RTLD_NOW | RTLD_LOCAL);
    if (!h) h = dlopen("libcrypto.so", RTLD_NOW | RTLD_LOCAL);
    if (!h) { pki_state = -1; fprintf(stderr, "isim: OpenSSL libcrypto (libcrypto.so.3) not found on this host: SecKey, SecCertificate and SecTrust are unavailable\n"); return; }
#define LOAD(ret, name, args) if (!(*(void **)&P.name = dlsym(h, #name))) { pki_state = -1; fprintf(stderr, "isim: libcrypto lacks %s\n", #name); return; }
    PKI_FUNCS(LOAD)
    pki_state = 1;
}
static int ok(void) { pthread_once(&pki_once, pki_load); if (pki_state != 1) fail("OpenSSL libcrypto is not available on the host"); return pki_state == 1; }
int isim_pki_available(void) { return ok(); }

enum { PK_RSA = 6, PK_EC = 408 };
enum { RSA_PKCS1 = 1, RSA_NONE = 3, RSA_OAEP = 4, RSA_PSS = 6 };
static int curve_for_size(int n) { return n == 32 ? 415 : n == 48 ? 715 : n == 66 ? 716 : 0; }   /* field bytes -> NID */
static int size_for_curve(int nid) { return nid == 415 ? 32 : nid == 715 ? 48 : nid == 716 ? 66 : 0; }
static void ossl_free(void *p) { if (p) P.CRYPTO_free(p, "", 0); }

/* ---- keys ---- */
static EVP_PKEY *ec_pkey(const uint8_t *k, size_t len, int priv) {
    int n = priv ? (int)(len - 1) / 3 : (int)(len - 1) / 2, nid = curve_for_size(n);
    if (!nid || k[0] != 4 || len != (size_t)(priv ? 1 + 3 * n : 1 + 2 * n)) { fail("not an X9.63 EC key for P-256, P-384 or P-521"); return NULL; }
    EC_KEY *ec = P.EC_KEY_new_by_curve_name(nid);
    const EC_GROUP *g = P.EC_KEY_get0_group(ec);
    EC_POINT *pt = P.EC_POINT_new(g);
    int good = P.EC_POINT_oct2point(g, pt, k, 1 + 2 * n, NULL) && P.EC_KEY_set_public_key(ec, pt);
    if (good && priv) { BIGNUM *d = P.BN_bin2bn(k + 1 + 2 * n, n, NULL); good = P.EC_KEY_set_private_key(ec, d); P.BN_free(d); }
    if (good) good = P.EC_KEY_check_key(ec);
    P.EC_POINT_free(pt);
    EVP_PKEY *pk = NULL;
    if (good) { pk = P.EVP_PKEY_new(); P.EVP_PKEY_set1_EC_KEY(pk, ec); } else fail("invalid EC key");
    P.EC_KEY_free(ec);
    return pk;
}
static EVP_PKEY *load_key(int type, const uint8_t *k, size_t len, int priv) {
    if (!ok() || !k || !len) return NULL;
    if (type == 1) return ec_pkey(k, len, priv);
    const unsigned char *p = k;
    EVP_PKEY *pk = priv ? P.d2i_PrivateKey(PK_RSA, NULL, &p, (long)len) : P.d2i_PublicKey(PK_RSA, NULL, &p, (long)len);
    if (!pk) fail(priv ? "not a PKCS#1 RSA private key" : "not a PKCS#1 RSA public key");
    return pk;
}
/* Apple representation of an EVP key; out == NULL asks for the size only */
static int export_key(EVP_PKEY *pk, int priv, uint8_t *out, size_t *len) {
    if (P.EVP_PKEY_get_base_id(pk) == PK_EC) {
        EC_KEY *ec = P.EVP_PKEY_get1_EC_KEY(pk);
        const EC_GROUP *g = P.EC_KEY_get0_group(ec);
        int n = size_for_curve(P.EC_GROUP_get_curve_name(g));
        size_t need = priv ? 1 + 3 * (size_t)n : 1 + 2 * (size_t)n;
        int good = n > 0 && *len >= need;
        if (good && out) {
            good = P.EC_POINT_point2oct(g, P.EC_KEY_get0_public_key(ec), 4, out, 1 + 2 * n, NULL) == (size_t)(1 + 2 * n);
            if (good && priv) good = P.BN_bn2binpad(P.EC_KEY_get0_private_key(ec), out + 1 + 2 * n, n) == n;
        }
        P.EC_KEY_free(ec);
        *len = need;
        if (!good) fail("cannot export the EC key");
        return good;
    }
    unsigned char *der = NULL;
    int n = priv ? P.i2d_PrivateKey(pk, &der) : P.i2d_PublicKey(pk, &der);
    if (n <= 0) { fail("cannot export the RSA key"); return 0; }
    int good = *len >= (size_t)n;
    if (good && out) memcpy(out, der, (size_t)n);
    *len = (size_t)n; ossl_free(der);
    return good;
}
int isim_pki_generate(int type, int bits, uint8_t *out, size_t *outlen) {
    if (!ok()) return 0;
    EVP_PKEY *pk;
    if (type == 1) {
        const char *curve = bits == 256 ? "P-256" : bits == 384 ? "P-384" : bits == 521 ? "P-521" : NULL;
        if (!curve) { fail("EC keys are 256, 384 or 521 bits"); return 0; }
        pk = P.EVP_PKEY_Q_keygen(NULL, NULL, "EC", curve);
    } else {
        if (bits < 1024 || bits > 8192 || bits % 8) { fail("RSA keys are 1024 to 8192 bits"); return 0; }
        pk = P.EVP_PKEY_Q_keygen(NULL, NULL, "RSA", (size_t)bits);
    }
    if (!pk) { fail("key generation failed"); return 0; }
    int r = export_key(pk, 1, out, outlen);
    P.EVP_PKEY_free(pk);
    return r;
}
int isim_pki_public(int type, const uint8_t *priv, size_t len, uint8_t *out, size_t *outlen) {
    EVP_PKEY *pk = load_key(type, priv, len, 1); if (!pk) return 0;
    int r = export_key(pk, 0, out, outlen); P.EVP_PKEY_free(pk); return r;
}
/* key size in bits, or 0 when the data is not a key of that type and class */
int isim_pki_key_bits(int type, const uint8_t *key, size_t len, int priv) {
    EVP_PKEY *pk = load_key(type, key, len, priv); if (!pk) return 0;
    int b = P.EVP_PKEY_get_bits(pk); P.EVP_PKEY_free(pk); return b;
}

/* alg: bits 0-3 digest (0 none, 1 SHA-1, 2 SHA-224, 3 SHA-256, 4 SHA-384, 5 SHA-512); bit 4 = data is a message
 * (hash it here); bits 8-11 scheme: 0 RSA PKCS#1 v1.5, 1 RSA PSS, 2 ECDSA (DER signature), 3 ECDSA (raw r||s),
 * 4 RSA raw (no padding) */
static const EVP_MD *md_for(int d) {
    switch (d) { case 1: return P.EVP_sha1(); case 2: return P.EVP_sha224(); case 3: return P.EVP_sha256();
                 case 4: return P.EVP_sha384(); case 5: return P.EVP_sha512(); default: return NULL; }
}
static int raw_to_der(const uint8_t *raw, size_t len, uint8_t *out, size_t *outlen) {
    size_t n = len / 2;
    ECDSA_SIG *s = P.ECDSA_SIG_new();
    P.ECDSA_SIG_set0(s, P.BN_bin2bn(raw, (int)n, NULL), P.BN_bin2bn(raw + n, (int)n, NULL));
    unsigned char *der = NULL; int dl = P.i2d_ECDSA_SIG(s, &der);
    int good = dl > 0 && (size_t)dl <= *outlen;
    if (good) memcpy(out, der, (size_t)dl), *outlen = (size_t)dl;
    ossl_free(der); P.ECDSA_SIG_free(s);
    return good;
}
static int der_to_raw(const uint8_t *der, size_t len, int n, uint8_t *out) {
    const unsigned char *p = der;
    ECDSA_SIG *s = P.d2i_ECDSA_SIG(NULL, &p, (long)len);
    if (!s) return 0;
    const BIGNUM *r, *ss; P.ECDSA_SIG_get0(s, &r, &ss);
    int good = P.BN_bn2binpad(r, out, n) == n && P.BN_bn2binpad(ss, out + n, n) == n;
    P.ECDSA_SIG_free(s); return good;
}
static int setup_rsa(EVP_PKEY_CTX *c, int scheme, const EVP_MD *md) {
    if (scheme == 1) return P.EVP_PKEY_CTX_set_rsa_padding(c, RSA_PSS) > 0 && P.EVP_PKEY_CTX_set_rsa_pss_saltlen(c, -1) > 0 &&
                            (!md || P.EVP_PKEY_CTX_set_rsa_mgf1_md(c, md) > 0);
    return P.EVP_PKEY_CTX_set_rsa_padding(c, scheme == 4 ? RSA_NONE : RSA_PKCS1) > 0;
}
int isim_pki_sign(int type, const uint8_t *priv, size_t len, int alg, const uint8_t *data, size_t dlen, uint8_t *sig, size_t *siglen) {
    EVP_PKEY *pk = load_key(type, priv, len, 1); if (!pk) return 0;
    int scheme = alg >> 8 & 15, isMessage = alg & 16; const EVP_MD *md = md_for(alg & 15);
    uint8_t buf[1200]; size_t bl = sizeof buf; int good = 0;
    if (isMessage) {
        EVP_MD_CTX *m = P.EVP_MD_CTX_new(); EVP_PKEY_CTX *pc = NULL;
        good = P.EVP_DigestSignInit(m, &pc, md, NULL, pk) > 0 && (type == 1 || setup_rsa(pc, scheme, md)) && P.EVP_DigestSign(m, buf, &bl, data, dlen) > 0;
        P.EVP_MD_CTX_free(m);
    } else {
        EVP_PKEY_CTX *c = P.EVP_PKEY_CTX_new(pk, NULL);
        good = P.EVP_PKEY_sign_init(c) > 0 && (type == 1 || setup_rsa(c, scheme, md)) && (!md || scheme == 4 || P.EVP_PKEY_CTX_set_signature_md(c, md) > 0) &&
               P.EVP_PKEY_sign(c, buf, &bl, data, dlen) > 0;
        P.EVP_PKEY_CTX_free(c);
    }
    if (good && type == 1 && scheme == 3) {   /* raw r || s */
        int n = (P.EVP_PKEY_get_bits(pk) + 7) / 8;
        good = *siglen >= (size_t)(2 * n) && der_to_raw(buf, bl, n, sig); *siglen = (size_t)(2 * n);
    } else if (good) { good = *siglen >= bl; if (good) memcpy(sig, buf, bl); *siglen = bl; }
    if (!good) fail("signing failed (wrong algorithm for the key, or the data is too long)");
    P.EVP_PKEY_free(pk); return good;
}
int isim_pki_verify(int type, const uint8_t *pub, size_t len, int alg, const uint8_t *data, size_t dlen, const uint8_t *sig, size_t siglen) {
    EVP_PKEY *pk = load_key(type, pub, len, 0); if (!pk) return 0;
    int scheme = alg >> 8 & 15, isMessage = alg & 16; const EVP_MD *md = md_for(alg & 15);
    uint8_t der[200];
    if (type == 1 && scheme == 3) {   /* raw r || s -> DER */
        size_t dl = sizeof der;
        if (!raw_to_der(sig, siglen, der, &dl)) { P.EVP_PKEY_free(pk); fail("malformed signature"); return 0; }
        sig = der; siglen = dl;
    }
    int good;
    if (isMessage) {
        EVP_MD_CTX *m = P.EVP_MD_CTX_new(); EVP_PKEY_CTX *pc = NULL;
        good = P.EVP_DigestVerifyInit(m, &pc, md, NULL, pk) > 0 && (type == 1 || setup_rsa(pc, scheme, md)) && P.EVP_DigestVerify(m, sig, siglen, data, dlen) == 1;
        P.EVP_MD_CTX_free(m);
    } else {
        EVP_PKEY_CTX *c = P.EVP_PKEY_CTX_new(pk, NULL);
        good = P.EVP_PKEY_verify_init(c) > 0 && (type == 1 || setup_rsa(c, scheme, md)) && (!md || scheme == 4 || P.EVP_PKEY_CTX_set_signature_md(c, md) > 0) &&
               P.EVP_PKEY_verify(c, sig, siglen, data, dlen) == 1;
        P.EVP_PKEY_CTX_free(c);
    }
    if (!good) fail("the signature does not match");
    P.EVP_PKEY_free(pk); return good;
}
/* RSA encryption. alg: 0 PKCS#1 v1.5, 1 raw, 2..6 OAEP with SHA-1/224/256/384/512 */
static int rsa_crypt(int encrypt, const uint8_t *key, size_t len, int alg, const uint8_t *in, size_t inlen, uint8_t *out, size_t *outlen) {
    EVP_PKEY *pk = load_key(0, key, len, !encrypt); if (!pk) return 0;
    EVP_PKEY_CTX *c = P.EVP_PKEY_CTX_new(pk, NULL);
    int good = (encrypt ? P.EVP_PKEY_encrypt_init(c) : P.EVP_PKEY_decrypt_init(c)) > 0 &&
               P.EVP_PKEY_CTX_set_rsa_padding(c, alg == 0 ? RSA_PKCS1 : alg == 1 ? RSA_NONE : RSA_OAEP) > 0;
    if (good && alg >= 2) { const EVP_MD *md = md_for(alg - 1); good = P.EVP_PKEY_CTX_set_rsa_oaep_md(c, md) > 0 && P.EVP_PKEY_CTX_set_rsa_mgf1_md(c, md) > 0; }
    if (good) good = (encrypt ? P.EVP_PKEY_encrypt(c, out, outlen, in, inlen) : P.EVP_PKEY_decrypt(c, out, outlen, in, inlen)) > 0;
    if (!good) fail(encrypt ? "encryption failed (data too long for the key?)" : "decryption failed");
    P.EVP_PKEY_CTX_free(c); P.EVP_PKEY_free(pk); return good;
}
int isim_pki_encrypt(const uint8_t *pub, size_t len, int alg, const uint8_t *in, size_t inlen, uint8_t *out, size_t *outlen) { return rsa_crypt(1, pub, len, alg, in, inlen, out, outlen); }
int isim_pki_decrypt(const uint8_t *priv, size_t len, int alg, const uint8_t *in, size_t inlen, uint8_t *out, size_t *outlen) { return rsa_crypt(0, priv, len, alg, in, inlen, out, outlen); }
/* ECDH: the shared x coordinate */
int isim_pki_ecdh(const uint8_t *priv, size_t len, const uint8_t *pub, size_t publen, uint8_t *out, size_t *outlen) {
    EVP_PKEY *a = load_key(1, priv, len, 1), *b = a ? load_key(1, pub, publen, 0) : NULL;
    int good = 0;
    if (a && b) {
        EVP_PKEY_CTX *c = P.EVP_PKEY_CTX_new(a, NULL);
        good = P.EVP_PKEY_derive_init(c) > 0 && P.EVP_PKEY_derive_set_peer(c, b) > 0 && P.EVP_PKEY_derive(c, out, outlen) > 0;
        P.EVP_PKEY_CTX_free(c);
        if (!good) fail("key exchange failed (keys on different curves?)");
    }
    if (a) P.EVP_PKEY_free(a);
    if (b) P.EVP_PKEY_free(b);
    return good;
}

/* ---- certificates ---- */
static X509 *load_cert(const uint8_t *der, size_t len) {
    if (!ok()) return NULL;
    const unsigned char *p = der;
    X509 *x = P.d2i_X509(NULL, &p, (long)len);
    if (!x || p != der + len) { if (x) P.X509_free(x); fail("not a DER X.509 certificate"); return NULL; }
    return x;
}
typedef struct { char *b; size_t n, cap; int bad; } jbuf;
static void jadd(jbuf *j, const char *s, size_t n) { if (j->n + n + 1 > j->cap) { j->bad = 1; return; } memcpy(j->b + j->n, s, n); j->n += n; j->b[j->n] = 0; }
static void jlit(jbuf *j, const char *s) { jadd(j, s, strlen(s)); }
static void jstr(jbuf *j, const char *s) {
    jlit(j, "\"");
    for (; *s; s++) {
        char e[8];
        if (*s == '"' || *s == '\\') { e[0] = '\\'; e[1] = *s; jadd(j, e, 2); }
        else if ((unsigned char)*s < 0x20) { snprintf(e, sizeof e, "\\u%04x", *s); jlit(j, e); }
        else jadd(j, s, 1);
    }
    jlit(j, "\"");
}
static void jhex(jbuf *j, const uint8_t *d, size_t n) {
    jlit(j, "\"");
    for (size_t i = 0; i < n; i++) { char h[3]; snprintf(h, 3, "%02x", d[i]); jadd(j, h, 2); }
    jlit(j, "\"");
}
static void jname(jbuf *j, const X509_NAME *nm) {
    jlit(j, "[");
    for (int i = 0, n = P.X509_NAME_entry_count(nm); i < n; i++) {
        X509_NAME_ENTRY *e = P.X509_NAME_get_entry(nm, i);
        ASN1_OBJECT *o = P.X509_NAME_ENTRY_get_object(e);
        int nid = P.OBJ_obj2nid(o);
        char oid[80]; P.OBJ_obj2txt(oid, sizeof oid, o, 1);
        const char *sn = nid ? P.OBJ_nid2sn(nid) : oid;
        unsigned char *v = NULL; int vl = P.ASN1_STRING_to_UTF8(&v, P.X509_NAME_ENTRY_get_data(e));
        if (i) jlit(j, ",");
        jlit(j, "["); jstr(j, sn ? sn : oid); jlit(j, ","); jstr(j, oid); jlit(j, ",");
        if (vl >= 0) { char *s = strndup((char *)v, (size_t)vl); jstr(j, s); free(s); } else jstr(j, "");
        jlit(j, "]");
        ossl_free(v);
    }
    jlit(j, "]");
}
static double asn1_time(const ASN1_STRING *t) {
    struct tm tm; memset(&tm, 0, sizeof tm);
    if (!P.ASN1_TIME_to_tm(t, &tm)) return 0;
    return (double)timegm(&tm);
}
/* JSON description: subject/issuer ([[shortName, oid, value]...]), subject/issuer DER (hex), serial (hex),
 * notBefore/notAfter (Unix time), keyType ("RSA"/"EC"), keyBits, publicKey (hex, Apple representation),
 * emails, isCA, selfIssued */
int isim_pki_cert_parse(const uint8_t *der, size_t len, char *json, size_t cap) {
    X509 *x = load_cert(der, len); if (!x) return 0;
    jbuf j = { json, 0, cap, 0 }; json[0] = 0;
    jlit(&j, "{\"subject\":"); jname(&j, P.X509_get_subject_name(x));
    jlit(&j, ",\"issuer\":"); jname(&j, P.X509_get_issuer_name(x));
    unsigned char *nd = NULL; int nl = P.i2d_X509_NAME(P.X509_get_subject_name(x), &nd);
    jlit(&j, ",\"subjectDER\":"); jhex(&j, nd, nl > 0 ? (size_t)nl : 0); ossl_free(nd); nd = NULL;
    nl = P.i2d_X509_NAME(P.X509_get_issuer_name(x), &nd);
    jlit(&j, ",\"issuerDER\":"); jhex(&j, nd, nl > 0 ? (size_t)nl : 0); ossl_free(nd);
    BIGNUM *sn = P.ASN1_INTEGER_to_BN(P.X509_get_serialNumber(x), NULL);
    uint8_t sb[64]; int sl = sn ? P.BN_bn2bin(sn, sb) : 0; if (sn) P.BN_free(sn);
    if (sl == 0) { sb[0] = 0; sl = 1; }
    jlit(&j, ",\"serial\":"); jhex(&j, sb, (size_t)sl);
    char num[64];
    snprintf(num, sizeof num, ",\"notBefore\":%.0f,\"notAfter\":%.0f", asn1_time(P.X509_get0_notBefore(x)), asn1_time(P.X509_get0_notAfter(x))); jlit(&j, num);
    EVP_PKEY *pk = P.X509_get0_pubkey(x);
    if (pk) {
        int id = P.EVP_PKEY_get_base_id(pk);
        jlit(&j, ",\"keyType\":"); jstr(&j, id == PK_RSA ? "RSA" : id == PK_EC ? "EC" : "other");
        snprintf(num, sizeof num, ",\"keyBits\":%d", P.EVP_PKEY_get_bits(pk)); jlit(&j, num);
        if (id == PK_RSA || id == PK_EC) {
            uint8_t kb[1100]; size_t kl = sizeof kb;
            if (export_key(pk, 0, kb, &kl)) { jlit(&j, ",\"publicKey\":"); jhex(&j, kb, kl); }
        }
    }
    jlit(&j, ",\"emails\":[");
    OPENSSL_STACK *em = P.X509_get1_email(x);
    for (int i = 0, n = em ? P.OPENSSL_sk_num(em) : 0; i < n; i++) { if (i) jlit(&j, ","); jstr(&j, P.OPENSSL_sk_value(em, i)); }
    if (em) P.X509_email_free(em);
    jlit(&j, "]");
    snprintf(num, sizeof num, ",\"isCA\":%s,\"selfIssued\":%s}", P.X509_check_ca(x) ? "true" : "false", P.X509_check_issued(x, x) == 0 ? "true" : "false");
    jlit(&j, num);
    P.X509_free(x);
    if (j.bad) { fail("certificate description too long"); return 0; }
    return 1;
}

/* Chain building + verification. certs: DER blobs (leaf first) concatenated, lens: their sizes; anchors likewise.
 * useSystemAnchors adds the host's CA store. time 0 = now. hostname (SSL policy) may be NULL. On success *chainlen
 * is the length of the verified chain; on failure err gets OpenSSL's reason. */
int isim_pki_trust(const uint8_t *certs, const size_t *lens, int ncerts, const uint8_t *anchors, const size_t *alens, int nanchors,
                   int useSystemAnchors, int sslServer, const char *hostname, double when, char *err, size_t errcap, int *chainlen) {
    if (!ok() || ncerts < 1) { snprintf(err, errcap, "%s", ncerts < 1 ? "no certificates" : pki_err); return 0; }
    X509 *xs[32]; int nx = 0; X509 *as[64]; int na = 0;
    const uint8_t *p = certs;
    for (int i = 0; i < ncerts && i < 32; i++) { X509 *x = load_cert(p, lens[i]); p += lens[i]; if (x) xs[nx++] = x; }
    p = anchors;
    for (int i = 0; i < nanchors && i < 64; i++) { X509 *x = load_cert(p, alens[i]); p += alens[i]; if (x) as[na++] = x; }
    int good = 0;
    if (nx == 0) snprintf(err, errcap, "the leaf certificate cannot be parsed");
    else {
        X509_STORE *st = P.X509_STORE_new();
        for (int i = 0; i < na; i++) P.X509_STORE_add_cert(st, as[i]);
        if (useSystemAnchors) P.X509_STORE_set_default_paths(st);
        OPENSSL_STACK *untrusted = P.OPENSSL_sk_new_null();
        for (int i = 1; i < nx; i++) P.OPENSSL_sk_push(untrusted, xs[i]);
        X509_STORE_CTX *c = P.X509_STORE_CTX_new();
        P.X509_STORE_CTX_init(c, st, xs[0], untrusted);
        if (when > 0) P.X509_STORE_CTX_set_time(c, 0, (time_t)when);
        if (sslServer) P.X509_STORE_CTX_set_purpose(c, 1 /* X509_PURPOSE_SSL_SERVER */);
        if (hostname && *hostname) P.X509_VERIFY_PARAM_set1_host(P.X509_STORE_CTX_get0_param(c), hostname, 0);
        good = P.X509_verify_cert(c) == 1;
        OPENSSL_STACK *chain = P.X509_STORE_CTX_get0_chain(c);
        *chainlen = chain ? P.OPENSSL_sk_num(chain) : 0;
        if (!good) snprintf(err, errcap, "%s", P.X509_verify_cert_error_string(P.X509_STORE_CTX_get_error(c)));
        P.X509_STORE_CTX_free(c); P.OPENSSL_sk_free(untrusted); P.X509_STORE_free(st);
    }
    for (int i = 0; i < nx; i++) P.X509_free(xs[i]);
    for (int i = 0; i < na; i++) P.X509_free(as[i]);
    return good;
}

/* PKCS#12: the private key (Apple representation, *keytype 0 RSA / 1 EC), the certificate and the extra
 * certificates (DER, concatenated into certs with sizes in certlens; certs[0] is the identity's certificate) */
int isim_pki_pkcs12(const uint8_t *data, size_t len, const char *password, uint8_t *key, size_t *keylen, int *keytype,
                    uint8_t *certs, size_t certscap, size_t *certlens, int *ncerts) {
    if (!ok()) return 0;
    const unsigned char *p = data;
    PKCS12 *p12 = P.d2i_PKCS12(NULL, &p, (long)len);
    if (!p12) { fail("not a PKCS#12 file"); *ncerts = -1; return 0; }
    EVP_PKEY *pk = NULL; X509 *cert = NULL; OPENSSL_STACK *ca = NULL;
    if (!P.PKCS12_parse(p12, password ? password : "", &pk, &cert, &ca)) { P.PKCS12_free(p12); fail("wrong password or unsupported PKCS#12 file"); *ncerts = 0; return 0; }
    int good = pk && cert;
    if (good) { *keytype = P.EVP_PKEY_get_base_id(pk) == PK_EC ? 1 : 0; good = export_key(pk, 1, key, keylen); }
    size_t used = 0; int n = 0;
    X509 *all[17]; int na = 0;
    if (cert) all[na++] = cert;
    for (int i = 0, m = ca ? P.OPENSSL_sk_num(ca) : 0; i < m && na < 17; i++) all[na++] = P.OPENSSL_sk_value(ca, i);
    for (int i = 0; good && i < na && n < 16; i++) {
        unsigned char *der = NULL; int dl = P.i2d_X509(all[i], &der);
        if (dl > 0 && used + (size_t)dl <= certscap) { memcpy(certs + used, der, (size_t)dl); certlens[n++] = (size_t)dl; used += (size_t)dl; }
        ossl_free(der);
    }
    *ncerts = n;
    if (pk) P.EVP_PKEY_free(pk);
    if (cert) P.X509_free(cert);
    if (ca) { for (int i = 0, m = P.OPENSSL_sk_num(ca); i < m; i++) P.X509_free(P.OPENSSL_sk_value(ca, i)); P.OPENSSL_sk_free(ca); }
    P.PKCS12_free(p12);
    return good;
}
