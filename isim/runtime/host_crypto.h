/* libisim_host crypto primitives (host_crypto.c); the guest declarations are in isim_host.h. */
#pragma once
#include <stddef.h>
#include <stdint.h>
int isim_crypto_available(void);
int isim_crypto_aead(int alg, int encrypt, const void *key, size_t keylen, const void *nonce, size_t noncelen,
                     const void *aad, size_t aadlen, const void *in, size_t inlen, void *out, void *tag);
int isim_crypto_ec_generate(int curve, uint8_t *priv);
int isim_crypto_ec_public(int curve, const uint8_t *priv, uint8_t *pub);
int isim_crypto_ec_import_public(int curve, const uint8_t *pub, size_t len, uint8_t *uncompressed);
int isim_crypto_ec_compress(int curve, const uint8_t *pub, size_t len, uint8_t *compressed);
int isim_crypto_ec_sign(int curve, const uint8_t *priv, const uint8_t *digest, size_t dlen, uint8_t *sig);
int isim_crypto_ec_verify(int curve, const uint8_t *pub, size_t publen, const uint8_t *digest, size_t dlen, const uint8_t *sig);
int isim_crypto_ec_ecdh(int curve, const uint8_t *priv, const uint8_t *pub, size_t publen, uint8_t *shared);
int isim_crypto_25519_public(int kind, const uint8_t *priv, uint8_t *pub);
int isim_crypto_25519_check_public(int kind, const uint8_t *pub);
int isim_crypto_x25519(const uint8_t *priv, const uint8_t *pub, uint8_t *shared);
int isim_crypto_ed25519_sign(const uint8_t *priv, const void *msg, size_t len, uint8_t *sig);
int isim_crypto_ed25519_verify(const uint8_t *pub, const void *msg, size_t len, const uint8_t *sig);
