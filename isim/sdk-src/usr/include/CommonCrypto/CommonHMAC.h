/* isim SDK (self-authored): CommonCrypto HMAC. */
#pragma once
#include <_isim_cdefs.h>
#include <CommonCrypto/CommonDigest.h>
__BEGIN_DECLS
enum {
    kCCHmacAlgSHA1,
    kCCHmacAlgMD5,
    kCCHmacAlgSHA256,
    kCCHmacAlgSHA384,
    kCCHmacAlgSHA512,
    kCCHmacAlgSHA224
};
typedef uint32_t CCHmacAlgorithm;
#define CC_HMAC_CONTEXT_SIZE 96
typedef struct { uint32_t ctx[CC_HMAC_CONTEXT_SIZE]; } CCHmacContext;
void CCHmacInit(CCHmacContext *ctx, CCHmacAlgorithm algorithm, const void *key, size_t keyLength);
void CCHmacUpdate(CCHmacContext *ctx, const void *data, size_t dataLength);
void CCHmacFinal(CCHmacContext *ctx, void *macOut);
void CCHmac(CCHmacAlgorithm algorithm, const void *key, size_t keyLength, const void *data, size_t dataLength, void *macOut);
__END_DECLS
