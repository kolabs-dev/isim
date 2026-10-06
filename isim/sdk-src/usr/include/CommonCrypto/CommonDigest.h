/* isim SDK (self-authored): CommonCrypto message digests. Implemented by isim's libSystem (libcommonCrypto). */
#pragma once
#include <_isim_cdefs.h>
#include <stdint.h>
#include <stddef.h>
__BEGIN_DECLS
typedef uint32_t CC_LONG;
typedef uint64_t CC_LONG64;

#define CC_MD5_DIGEST_LENGTH    16
#define CC_MD5_BLOCK_BYTES      64
#define CC_SHA1_DIGEST_LENGTH   20
#define CC_SHA1_BLOCK_BYTES     64
#define CC_SHA224_DIGEST_LENGTH 28
#define CC_SHA224_BLOCK_BYTES   64
#define CC_SHA256_DIGEST_LENGTH 32
#define CC_SHA256_BLOCK_BYTES   64
#define CC_SHA384_DIGEST_LENGTH 48
#define CC_SHA384_BLOCK_BYTES   128
#define CC_SHA512_DIGEST_LENGTH 64
#define CC_SHA512_BLOCK_BYTES   128

/* context sizes match iOS; the contents are private to the implementation */
typedef struct CC_MD5state_st { CC_LONG A, B, C, D; CC_LONG Nl, Nh; CC_LONG data[16]; int num; } CC_MD5_CTX;
typedef struct CC_SHA1state_st { CC_LONG h0, h1, h2, h3, h4; CC_LONG Nl, Nh; CC_LONG data[16]; int num; } CC_SHA1_CTX;
typedef struct CC_SHA256state_st { CC_LONG count[2]; CC_LONG hash[8]; CC_LONG wbuf[16]; } CC_SHA256_CTX;
typedef struct CC_SHA512state_st { CC_LONG64 count[2]; CC_LONG64 hash[8]; CC_LONG64 wbuf[16]; } CC_SHA512_CTX;

/* MD5 and SHA-1 are cryptographically broken; they remain for compatibility (deprecated on iOS 13+) */
extern int CC_MD5_Init(CC_MD5_CTX *c);
extern int CC_MD5_Update(CC_MD5_CTX *c, const void *data, CC_LONG len);
extern int CC_MD5_Final(unsigned char *md, CC_MD5_CTX *c);
extern unsigned char *CC_MD5(const void *data, CC_LONG len, unsigned char *md);
extern int CC_SHA1_Init(CC_SHA1_CTX *c);
extern int CC_SHA1_Update(CC_SHA1_CTX *c, const void *data, CC_LONG len);
extern int CC_SHA1_Final(unsigned char *md, CC_SHA1_CTX *c);
extern unsigned char *CC_SHA1(const void *data, CC_LONG len, unsigned char *md);
extern int CC_SHA224_Init(CC_SHA256_CTX *c);
extern int CC_SHA224_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len);
extern int CC_SHA224_Final(unsigned char *md, CC_SHA256_CTX *c);
extern unsigned char *CC_SHA224(const void *data, CC_LONG len, unsigned char *md);
extern int CC_SHA256_Init(CC_SHA256_CTX *c);
extern int CC_SHA256_Update(CC_SHA256_CTX *c, const void *data, CC_LONG len);
extern int CC_SHA256_Final(unsigned char *md, CC_SHA256_CTX *c);
extern unsigned char *CC_SHA256(const void *data, CC_LONG len, unsigned char *md);
extern int CC_SHA384_Init(CC_SHA512_CTX *c);
extern int CC_SHA384_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len);
extern int CC_SHA384_Final(unsigned char *md, CC_SHA512_CTX *c);
extern unsigned char *CC_SHA384(const void *data, CC_LONG len, unsigned char *md);
extern int CC_SHA512_Init(CC_SHA512_CTX *c);
extern int CC_SHA512_Update(CC_SHA512_CTX *c, const void *data, CC_LONG len);
extern int CC_SHA512_Final(unsigned char *md, CC_SHA512_CTX *c);
extern unsigned char *CC_SHA512(const void *data, CC_LONG len, unsigned char *md);
__END_DECLS
