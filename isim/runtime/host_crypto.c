/* isim cryptography on the host.
 *
 * CommonCrypto (libcommonCrypto, part of the libSystem umbrella on iOS): message digests (MD5, SHA-1,
 * SHA-2) implemented here in C with state kept inside the guest's CC_*_CTX structs (so contexts can be
 * copied like on iOS), HMAC, PBKDF2, CCRandomGenerateBytes; CCCrypt/CCCryptor (AES, 3DES; ECB, CBC,
 * CTR, CFB, OFB) through the host's OpenSSL libcrypto (dlopen'ed on first use).
 *
 * libisim_host (isim_crypto_*): primitives for isim's CryptoKit — AES-GCM and ChaCha20-Poly1305 AEADs,
 * ECDSA/ECDH on P-256/P-384/P-521, X25519 and Ed25519 — also through libcrypto. Without libcrypto.so.3 on
 * the host these report failure (CryptoKit then stops with a clear message); digests/HMAC still work.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include "runtime.h"
#include "host_crypto.h"

/* ================= digests ================= */
static inline uint32_t rol32(uint32_t x, int n) { return (x << n) | (x >> (32 - n)); }
static inline uint32_t ror32(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
static inline uint64_t ror64(uint64_t x, int n) { return (x >> n) | (x << (64 - n)); }
static inline uint32_t be32(const uint8_t *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static inline uint32_t le32(const uint8_t *p) { return (uint32_t)p[3] << 24 | (uint32_t)p[2] << 16 | (uint32_t)p[1] << 8 | p[0]; }
static inline uint64_t be64(const uint8_t *p) { return (uint64_t)be32(p) << 32 | be32(p + 4); }
static inline void put_be32(uint8_t *p, uint32_t v) { p[0] = v >> 24; p[1] = v >> 16; p[2] = v >> 8; p[3] = v; }
static inline void put_le32(uint8_t *p, uint32_t v) { p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24; }
static inline void put_be64(uint8_t *p, uint64_t v) { put_be32(p, v >> 32); put_be32(p + 4, (uint32_t)v); }

/* state layouts fit inside Apple's CC_*_CTX sizes: MD5 92, SHA1 96, SHA256 104, SHA512 208 bytes */
struct md5_st { uint32_t h[4]; uint64_t len; uint8_t buf[64]; };
struct sha1_st { uint32_t h[5]; uint32_t pad; uint64_t len; uint8_t buf[64]; };
struct sha256_st { uint32_t h[8]; uint64_t len; uint8_t buf[64]; };
struct sha512_st { uint64_t h[8]; uint64_t len, len_hi; uint8_t buf[128]; };
_Static_assert(sizeof(struct md5_st) <= 92, "md5"); _Static_assert(sizeof(struct sha1_st) <= 96, "sha1");
_Static_assert(sizeof(struct sha256_st) <= 104, "sha256"); _Static_assert(sizeof(struct sha512_st) <= 208, "sha512");

static void md5_block(uint32_t *h, const uint8_t *p) {
    static const uint32_t K[64] = {
        0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501,
        0x698098d8, 0x8b44f7af, 0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821,
        0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa, 0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8,
        0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8, 0x676f02d9, 0x8d2a4c8a,
        0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
        0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665,
        0xf4292244, 0x432aff97, 0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1,
        0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1, 0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };
    static const int R[64] = { 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                               4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21, 6, 10, 15, 21 };
    uint32_t m[16], a = h[0], b = h[1], c = h[2], d = h[3];
    for (int i = 0; i < 16; i++) m[i] = le32(p + 4 * i);
    for (int i = 0; i < 64; i++) {
        uint32_t f; int g;
        if (i < 16) { f = (b & c) | (~b & d); g = i; }
        else if (i < 32) { f = (d & b) | (~d & c); g = (5 * i + 1) & 15; }
        else if (i < 48) { f = b ^ c ^ d; g = (3 * i + 5) & 15; }
        else { f = c ^ (b | ~d); g = (7 * i) & 15; }
        uint32_t t = d; d = c; c = b;
        b = b + rol32(a + f + K[i] + m[g], R[i]);
        a = t;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d;
}

static void sha1_block(uint32_t *h, const uint8_t *p) {
    uint32_t w[80], a = h[0], b = h[1], c = h[2], d = h[3], e = h[4];
    for (int i = 0; i < 16; i++) w[i] = be32(p + 4 * i);
    for (int i = 16; i < 80; i++) w[i] = rol32(w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16], 1);
    for (int i = 0; i < 80; i++) {
        uint32_t f, k;
        if (i < 20) { f = (b & c) | (~b & d); k = 0x5a827999; }
        else if (i < 40) { f = b ^ c ^ d; k = 0x6ed9eba1; }
        else if (i < 60) { f = (b & c) | (b & d) | (c & d); k = 0x8f1bbcdc; }
        else { f = b ^ c ^ d; k = 0xca62c1d6; }
        uint32_t t = rol32(a, 5) + f + e + k + w[i];
        e = d; d = c; c = rol32(b, 30); b = a; a = t;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e;
}

static const uint32_t K256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 };
static void sha256_block(uint32_t *h, const uint8_t *p) {
    uint32_t w[64], s[8];
    for (int i = 0; i < 16; i++) w[i] = be32(p + 4 * i);
    for (int i = 16; i < 64; i++) {
        uint32_t s0 = ror32(w[i - 15], 7) ^ ror32(w[i - 15], 18) ^ (w[i - 15] >> 3);
        uint32_t s1 = ror32(w[i - 2], 17) ^ ror32(w[i - 2], 19) ^ (w[i - 2] >> 10);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    memcpy(s, h, sizeof s);
    for (int i = 0; i < 64; i++) {
        uint32_t S1 = ror32(s[4], 6) ^ ror32(s[4], 11) ^ ror32(s[4], 25);
        uint32_t ch = (s[4] & s[5]) ^ (~s[4] & s[6]);
        uint32_t t1 = s[7] + S1 + ch + K256[i] + w[i];
        uint32_t S0 = ror32(s[0], 2) ^ ror32(s[0], 13) ^ ror32(s[0], 22);
        uint32_t mj = (s[0] & s[1]) ^ (s[0] & s[2]) ^ (s[1] & s[2]);
        uint32_t t2 = S0 + mj;
        s[7] = s[6]; s[6] = s[5]; s[5] = s[4]; s[4] = s[3] + t1; s[3] = s[2]; s[2] = s[1]; s[1] = s[0]; s[0] = t1 + t2;
    }
    for (int i = 0; i < 8; i++) h[i] += s[i];
}

static const uint64_t K512[80] = {
    0x428a2f98d728ae22ULL, 0x7137449123ef65cdULL, 0xb5c0fbcfec4d3b2fULL, 0xe9b5dba58189dbbcULL, 0x3956c25bf348b538ULL,
    0x59f111f1b605d019ULL, 0x923f82a4af194f9bULL, 0xab1c5ed5da6d8118ULL, 0xd807aa98a3030242ULL, 0x12835b0145706fbeULL,
    0x243185be4ee4b28cULL, 0x550c7dc3d5ffb4e2ULL, 0x72be5d74f27b896fULL, 0x80deb1fe3b1696b1ULL, 0x9bdc06a725c71235ULL,
    0xc19bf174cf692694ULL, 0xe49b69c19ef14ad2ULL, 0xefbe4786384f25e3ULL, 0x0fc19dc68b8cd5b5ULL, 0x240ca1cc77ac9c65ULL,
    0x2de92c6f592b0275ULL, 0x4a7484aa6ea6e483ULL, 0x5cb0a9dcbd41fbd4ULL, 0x76f988da831153b5ULL, 0x983e5152ee66dfabULL,
    0xa831c66d2db43210ULL, 0xb00327c898fb213fULL, 0xbf597fc7beef0ee4ULL, 0xc6e00bf33da88fc2ULL, 0xd5a79147930aa725ULL,
    0x06ca6351e003826fULL, 0x142929670a0e6e70ULL, 0x27b70a8546d22ffcULL, 0x2e1b21385c26c926ULL, 0x4d2c6dfc5ac42aedULL,
    0x53380d139d95b3dfULL, 0x650a73548baf63deULL, 0x766a0abb3c77b2a8ULL, 0x81c2c92e47edaee6ULL, 0x92722c851482353bULL,
    0xa2bfe8a14cf10364ULL, 0xa81a664bbc423001ULL, 0xc24b8b70d0f89791ULL, 0xc76c51a30654be30ULL, 0xd192e819d6ef5218ULL,
    0xd69906245565a910ULL, 0xf40e35855771202aULL, 0x106aa07032bbd1b8ULL, 0x19a4c116b8d2d0c8ULL, 0x1e376c085141ab53ULL,
    0x2748774cdf8eeb99ULL, 0x34b0bcb5e19b48a8ULL, 0x391c0cb3c5c95a63ULL, 0x4ed8aa4ae3418acbULL, 0x5b9cca4f7763e373ULL,
    0x682e6ff3d6b2b8a3ULL, 0x748f82ee5defb2fcULL, 0x78a5636f43172f60ULL, 0x84c87814a1f0ab72ULL, 0x8cc702081a6439ecULL,
    0x90befffa23631e28ULL, 0xa4506cebde82bde9ULL, 0xbef9a3f7b2c67915ULL, 0xc67178f2e372532bULL, 0xca273eceea26619cULL,
    0xd186b8c721c0c207ULL, 0xeada7dd6cde0eb1eULL, 0xf57d4f7fee6ed178ULL, 0x06f067aa72176fbaULL, 0x0a637dc5a2c898a6ULL,
    0x113f9804bef90daeULL, 0x1b710b35131c471bULL, 0x28db77f523047d84ULL, 0x32caab7b40c72493ULL, 0x3c9ebe0a15c9bebcULL,
    0x431d67c49c100d4cULL, 0x4cc5d4becb3e42b6ULL, 0x597f299cfc657e2aULL, 0x5fcb6fab3ad6faecULL, 0x6c44198c4a475817ULL };
static void sha512_block(uint64_t *h, const uint8_t *p) {
    uint64_t w[80], s[8];
    for (int i = 0; i < 16; i++) w[i] = be64(p + 8 * i);
    for (int i = 16; i < 80; i++) {
        uint64_t s0 = ror64(w[i - 15], 1) ^ ror64(w[i - 15], 8) ^ (w[i - 15] >> 7);
        uint64_t s1 = ror64(w[i - 2], 19) ^ ror64(w[i - 2], 61) ^ (w[i - 2] >> 6);
        w[i] = w[i - 16] + s0 + w[i - 7] + s1;
    }
    memcpy(s, h, sizeof s);
    for (int i = 0; i < 80; i++) {
        uint64_t S1 = ror64(s[4], 14) ^ ror64(s[4], 18) ^ ror64(s[4], 41);
        uint64_t ch = (s[4] & s[5]) ^ (~s[4] & s[6]);
        uint64_t t1 = s[7] + S1 + ch + K512[i] + w[i];
        uint64_t S0 = ror64(s[0], 28) ^ ror64(s[0], 34) ^ ror64(s[0], 39);
        uint64_t mj = (s[0] & s[1]) ^ (s[0] & s[2]) ^ (s[1] & s[2]);
        uint64_t t2 = S0 + mj;
        s[7] = s[6]; s[6] = s[5]; s[5] = s[4]; s[4] = s[3] + t1; s[3] = s[2]; s[2] = s[1]; s[1] = s[0]; s[0] = t1 + t2;
    }
    for (int i = 0; i < 8; i++) h[i] += s[i];
}

/* generic Merkle–Damgård buffering: len = total bytes so far, buf holds len % block bytes */
#define MD_UPDATE(st, blk, block_fn, data, n) do {                                   \
    const uint8_t *p_ = (const uint8_t *)(data); size_t n_ = (n);                    \
    size_t have_ = (size_t)((st)->len % (blk));                                      \
    if (((st)->len += n_) < n_ && (blk) == 128) ((struct sha512_st *)(void *)(st))->len_hi++; \
    if (have_) {                                                                     \
        size_t take_ = (blk) - have_ < n_ ? (blk) - have_ : n_;                      \
        memcpy((st)->buf + have_, p_, take_); p_ += take_; n_ -= take_;              \
        if (have_ + take_ < (blk)) break;                                            \
        block_fn((st)->h, (st)->buf);                                                \
    }                                                                                \
    for (; n_ >= (blk); p_ += (blk), n_ -= (blk)) block_fn((st)->h, p_);             \
    if (n_) memcpy((st)->buf, p_, n_);                                               \
} while (0)

static void md5_init(struct md5_st *s) { memset(s, 0, sizeof *s); s->h[0] = 0x67452301; s->h[1] = 0xefcdab89; s->h[2] = 0x98badcfe; s->h[3] = 0x10325476; }
static void md5_update(struct md5_st *s, const void *d, size_t n) { MD_UPDATE(s, 64, md5_block, d, n); }
static void md5_final(struct md5_st *s, uint8_t *out) {
    uint64_t bits = s->len * 8; uint8_t pad[72] = { 0x80 }; size_t have = s->len % 64;
    size_t padn = (have < 56 ? 56 : 120) - have;
    uint8_t lenb[8]; for (int i = 0; i < 8; i++) lenb[i] = (uint8_t)(bits >> (8 * i));
    md5_update(s, pad, padn); md5_update(s, lenb, 8);
    for (int i = 0; i < 4; i++) put_le32(out + 4 * i, s->h[i]);
}
static void sha1_init(struct sha1_st *s) { memset(s, 0, sizeof *s); s->h[0] = 0x67452301; s->h[1] = 0xefcdab89; s->h[2] = 0x98badcfe; s->h[3] = 0x10325476; s->h[4] = 0xc3d2e1f0; }
static void sha1_update(struct sha1_st *s, const void *d, size_t n) { MD_UPDATE(s, 64, sha1_block, d, n); }
static void sha1_final(struct sha1_st *s, uint8_t *out) {
    uint64_t bits = s->len * 8; uint8_t pad[72] = { 0x80 }; size_t have = s->len % 64;
    uint8_t lenb[8]; put_be64(lenb, bits);
    sha1_update(s, pad, (have < 56 ? 56 : 120) - have); sha1_update(s, lenb, 8);
    for (int i = 0; i < 5; i++) put_be32(out + 4 * i, s->h[i]);
}
static void sha256_init(struct sha256_st *s, int is224) {
    static const uint32_t h256[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    static const uint32_t h224[8] = { 0xc1059ed8, 0x367cd507, 0x3070dd17, 0xf70e5939, 0xffc00b31, 0x68581511, 0x64f98fa7, 0xbefa4fa4 };
    memset(s, 0, sizeof *s); memcpy(s->h, is224 ? h224 : h256, sizeof s->h);
}
static void sha256_update(struct sha256_st *s, const void *d, size_t n) { MD_UPDATE(s, 64, sha256_block, d, n); }
static void sha256_final(struct sha256_st *s, uint8_t *out, int words) {
    uint64_t bits = s->len * 8; uint8_t pad[72] = { 0x80 }; size_t have = s->len % 64;
    uint8_t lenb[8]; put_be64(lenb, bits);
    sha256_update(s, pad, (have < 56 ? 56 : 120) - have); sha256_update(s, lenb, 8);
    for (int i = 0; i < words; i++) put_be32(out + 4 * i, s->h[i]);
}
static void sha512_init(struct sha512_st *s, int is384) {
    static const uint64_t h512[8] = { 0x6a09e667f3bcc908ULL, 0xbb67ae8584caa73bULL, 0x3c6ef372fe94f82bULL, 0xa54ff53a5f1d36f1ULL,
                                      0x510e527fade682d1ULL, 0x9b05688c2b3e6c1fULL, 0x1f83d9abfb41bd6bULL, 0x5be0cd19137e2179ULL };
    static const uint64_t h384[8] = { 0xcbbb9d5dc1059ed8ULL, 0x629a292a367cd507ULL, 0x9159015a3070dd17ULL, 0x152fecd8f70e5939ULL,
                                      0x67332667ffc00b31ULL, 0x8eb44a8768581511ULL, 0xdb0c2e0d64f98fa7ULL, 0x47b5481dbefa4fa4ULL };
    memset(s, 0, sizeof *s); memcpy(s->h, is384 ? h384 : h512, sizeof s->h);
}
static void sha512_update(struct sha512_st *s, const void *d, size_t n) { MD_UPDATE(s, 128, sha512_block, d, n); }
static void sha512_final(struct sha512_st *s, uint8_t *out, int words) {
    uint64_t lo = s->len << 3, hi = (s->len_hi << 3) | (s->len >> 61);
    uint8_t pad[144] = { 0x80 }; size_t have = s->len % 128;
    uint8_t lenb[16]; put_be64(lenb, hi); put_be64(lenb + 8, lo);
    sha512_update(s, pad, (have < 112 ? 112 : 240) - have); sha512_update(s, lenb, 16);
    for (int i = 0; i < words; i++) put_be64(out + 8 * i, s->h[i]);
}

/* algorithm table shared by CommonCrypto HMAC/PBKDF2 and isim_crypto_digest */
enum { ALG_MD5, ALG_SHA1, ALG_SHA224, ALG_SHA256, ALG_SHA384, ALG_SHA512, ALG_COUNT };
union md_state { struct md5_st md5; struct sha1_st sha1; struct sha256_st sha256; struct sha512_st sha512; };
static const struct { int out, block; } md_info[ALG_COUNT] = { { 16, 64 }, { 20, 64 }, { 28, 64 }, { 32, 64 }, { 48, 128 }, { 64, 128 } };
static void md_init(int alg, union md_state *s) {
    switch (alg) {
    case ALG_MD5: md5_init(&s->md5); break;
    case ALG_SHA1: sha1_init(&s->sha1); break;
    case ALG_SHA224: case ALG_SHA256: sha256_init(&s->sha256, alg == ALG_SHA224); break;
    default: sha512_init(&s->sha512, alg == ALG_SHA384); break;
    }
}
static void md_update(int alg, union md_state *s, const void *d, size_t n) {
    switch (alg) {
    case ALG_MD5: md5_update(&s->md5, d, n); break;
    case ALG_SHA1: sha1_update(&s->sha1, d, n); break;
    case ALG_SHA224: case ALG_SHA256: sha256_update(&s->sha256, d, n); break;
    default: sha512_update(&s->sha512, d, n); break;
    }
}
static void md_final(int alg, union md_state *s, uint8_t *out) {
    switch (alg) {
    case ALG_MD5: md5_final(&s->md5, out); break;
    case ALG_SHA1: sha1_final(&s->sha1, out); break;
    case ALG_SHA224: sha256_final(&s->sha256, out, 7); break;
    case ALG_SHA256: sha256_final(&s->sha256, out, 8); break;
    case ALG_SHA384: sha512_final(&s->sha512, out, 6); break;
    default: sha512_final(&s->sha512, out, 8); break;
    }
}
static void md_oneshot(int alg, const void *d, size_t n, uint8_t *out) { union md_state s; md_init(alg, &s); md_update(alg, &s, d, n); md_final(alg, &s, out); }

/* ---- CommonDigest API: CC_LONG is uint32_t; contexts are opaque byte blobs of Apple's sizes ---- */
#define CC_DIGEST_API(NAME, ALG, ST, FIELD)                                                                   \
    static int cc_##NAME##_init(void *c) { union md_state s; md_init(ALG, &s); memcpy(c, &s.FIELD, sizeof s.FIELD); return 1; } \
    static int cc_##NAME##_update(void *c, const void *d, uint32_t n) {                                        \
        union md_state s; memcpy(&s.FIELD, c, sizeof s.FIELD); md_update(ALG, &s, d, n); memcpy(c, &s.FIELD, sizeof s.FIELD); return 1; } \
    static int cc_##NAME##_final(uint8_t *md, void *c) {                                                     \
        union md_state s; memcpy(&s.FIELD, c, sizeof s.FIELD); md_final(ALG, &s, md); memset(c, 0, sizeof s.FIELD); return 1; } \
    static uint8_t *cc_##NAME(const void *d, uint32_t n, uint8_t *md) { md_oneshot(ALG, d, n, md); return md; }
CC_DIGEST_API(md5, ALG_MD5, md5_st, md5)
CC_DIGEST_API(sha1, ALG_SHA1, sha1_st, sha1)
CC_DIGEST_API(sha224, ALG_SHA224, sha256_st, sha256)
CC_DIGEST_API(sha256, ALG_SHA256, sha256_st, sha256)
CC_DIGEST_API(sha384, ALG_SHA384, sha512_st, sha512)
CC_DIGEST_API(sha512, ALG_SHA512, sha512_st, sha512)

/* ---- HMAC (CCHmacContext is 384 bytes) ---- */
enum { kCCHmacAlgSHA1, kCCHmacAlgMD5, kCCHmacAlgSHA256, kCCHmacAlgSHA384, kCCHmacAlgSHA512, kCCHmacAlgSHA224 };
struct hmac_st { int alg; uint8_t okey[128]; union md_state inner; };
_Static_assert(sizeof(struct hmac_st) <= 384, "hmac");
static int hmac_alg(unsigned cc) {
    static const int map[] = { ALG_SHA1, ALG_MD5, ALG_SHA256, ALG_SHA384, ALG_SHA512, ALG_SHA224 };
    return cc < 6 ? map[cc] : -1;
}
static void hmac_init(struct hmac_st *h, int alg, const void *key, size_t keylen) {
    uint8_t k[128] = { 0 }, ikey[128]; int bs = md_info[alg].block;
    if (keylen > (size_t)bs) md_oneshot(alg, key, keylen, k); else if (keylen) memcpy(k, key, keylen);
    for (int i = 0; i < bs; i++) { ikey[i] = k[i] ^ 0x36; h->okey[i] = k[i] ^ 0x5c; }
    h->alg = alg; md_init(alg, &h->inner); md_update(alg, &h->inner, ikey, bs);
}
static void hmac_final(struct hmac_st *h, uint8_t *out) {
    uint8_t ih[64]; union md_state o;
    md_final(h->alg, &h->inner, ih);
    md_init(h->alg, &o); md_update(h->alg, &o, h->okey, md_info[h->alg].block); md_update(h->alg, &o, ih, md_info[h->alg].out);
    md_final(h->alg, &o, out);
}
static void cc_hmac_init(void *ctx, unsigned alg, const void *key, size_t keylen) {
    struct hmac_st h; int a = hmac_alg(alg); if (a < 0) a = ALG_SHA1;
    hmac_init(&h, a, key, keylen); memcpy(ctx, &h, sizeof h);
}
static void cc_hmac_update(void *ctx, const void *d, size_t n) {
    struct hmac_st h; memcpy(&h, ctx, sizeof h); md_update(h.alg, &h.inner, d, n); memcpy(ctx, &h, sizeof h);
}
static void cc_hmac_final(void *ctx, void *mac) { struct hmac_st h; memcpy(&h, ctx, sizeof h); hmac_final(&h, mac); memset(ctx, 0, sizeof h); }
static void cc_hmac(unsigned alg, const void *key, size_t keylen, const void *d, size_t n, void *mac) {
    struct hmac_st h; int a = hmac_alg(alg); if (a < 0) a = ALG_SHA1;
    hmac_init(&h, a, key, keylen); md_update(a, &h.inner, d, n); hmac_final(&h, mac);
}

/* ---- PBKDF2 (CommonKeyDerivation) ---- */
#define kCCSuccess 0
#define kCCParamError (-4300)
#define kCCBufferTooSmall (-4301)
#define kCCMemoryFailure (-4302)
#define kCCAlignmentError (-4303)
#define kCCDecodeError (-4304)
#define kCCUnimplemented (-4305)
static int prf_alg(unsigned prf) { /* kCCPRFHmacAlgSHA1 = 1 ... SHA512 = 5 */
    static const int map[] = { -1, ALG_SHA1, ALG_SHA224, ALG_SHA256, ALG_SHA384, ALG_SHA512 };
    return prf < 6 ? map[prf] : -1;
}
static int pbkdf2(int alg, const void *pw, size_t pwlen, const uint8_t *salt, size_t saltlen, unsigned rounds, uint8_t *out, size_t outlen) {
    int hl = md_info[alg].out; struct hmac_st base, h; uint8_t u[64], t[64];
    hmac_init(&base, alg, pw, pwlen);
    for (uint32_t block = 1; outlen; block++) {
        uint8_t be[4]; put_be32(be, block);
        h = base; md_update(alg, &h.inner, salt, saltlen); md_update(alg, &h.inner, be, 4); hmac_final(&h, u);
        memcpy(t, u, hl);
        for (unsigned r = 1; r < rounds; r++) {
            h = base; md_update(alg, &h.inner, u, hl); hmac_final(&h, u);
            for (int i = 0; i < hl; i++) t[i] ^= u[i];
        }
        size_t take = outlen < (size_t)hl ? outlen : (size_t)hl;
        memcpy(out, t, take); out += take; outlen -= take;
    }
    return kCCSuccess;
}
static int cc_pbkdf(unsigned algorithm, const char *pw, size_t pwlen, const uint8_t *salt, size_t saltlen, unsigned prf, unsigned rounds, uint8_t *dk, size_t dklen) {
    int a = prf_alg(prf);
    if (algorithm != 2 /* kCCPBKDF2 */ || a < 0 || !dk || !dklen || rounds == 0 || (!pw && pwlen)) return kCCParamError;
    return pbkdf2(a, pw, pwlen, salt, saltlen, rounds, dk, dklen);
}
static unsigned cc_calibrate_pbkdf(unsigned algorithm, size_t pwlen, size_t saltlen, unsigned prf, size_t dklen, uint32_t msec) {
    int a = prf_alg(prf); if (algorithm != 2 || a < 0) return (unsigned)-1;
    /* time a short run and scale to the requested duration */
    uint8_t salt[64] = { 0 }, out[64]; struct timespec t0, t1; unsigned probe = 2000;
    clock_gettime(CLOCK_MONOTONIC, &t0); pbkdf2(a, "password", 8, salt, saltlen < 64 ? saltlen : 64, probe, out, 32); clock_gettime(CLOCK_MONOTONIC, &t1);
    double ms = (t1.tv_sec - t0.tv_sec) * 1e3 + (t1.tv_nsec - t0.tv_nsec) / 1e6; if (ms <= 0) ms = 0.001;
    double blocks = (double)((dklen + md_info[a].out - 1) / md_info[a].out); if (blocks < 1) blocks = 1;
    double r = probe * (msec / ms) / blocks; return r < 10000 ? 10000 : (unsigned)r;
}
static int cc_random(void *bytes, size_t n) {
    uint8_t *p = bytes;
    while (n) { ssize_t r = getrandom(p, n, 0); if (r <= 0) return -1; p += r; n -= (size_t)r; }
    return kCCSuccess;
}

/* ================= libcrypto (OpenSSL 3, dlopen'ed) ================= */
typedef struct evp_cipher_ctx_st EVP_CIPHER_CTX; typedef struct evp_cipher_st EVP_CIPHER; typedef struct evp_pkey_st EVP_PKEY;
typedef struct evp_pkey_ctx_st EVP_PKEY_CTX; typedef struct evp_md_ctx_st EVP_MD_CTX; typedef struct ec_key_st EC_KEY;
typedef struct ec_group_st EC_GROUP; typedef struct ec_point_st EC_POINT; typedef struct bignum_st BIGNUM; typedef struct ecdsa_sig_st ECDSA_SIG;
#define LIBCRYPTO_FUNCS(X) \
    X(EVP_CIPHER_CTX *, EVP_CIPHER_CTX_new, (void)) X(void, EVP_CIPHER_CTX_free, (EVP_CIPHER_CTX *)) \
    X(int, EVP_CIPHER_CTX_set_padding, (EVP_CIPHER_CTX *, int)) X(int, EVP_CIPHER_CTX_ctrl, (EVP_CIPHER_CTX *, int, int, void *)) \
    X(int, EVP_CipherInit_ex, (EVP_CIPHER_CTX *, const EVP_CIPHER *, void *, const unsigned char *, const unsigned char *, int)) \
    X(int, EVP_CipherUpdate, (EVP_CIPHER_CTX *, unsigned char *, int *, const unsigned char *, int)) \
    X(int, EVP_CipherFinal_ex, (EVP_CIPHER_CTX *, unsigned char *, int *)) \
    X(const EVP_CIPHER *, EVP_aes_128_gcm, (void)) X(const EVP_CIPHER *, EVP_aes_192_gcm, (void)) X(const EVP_CIPHER *, EVP_aes_256_gcm, (void)) \
    X(const EVP_CIPHER *, EVP_chacha20_poly1305, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_ecb, (void)) X(const EVP_CIPHER *, EVP_aes_192_ecb, (void)) X(const EVP_CIPHER *, EVP_aes_256_ecb, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_cbc, (void)) X(const EVP_CIPHER *, EVP_aes_192_cbc, (void)) X(const EVP_CIPHER *, EVP_aes_256_cbc, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_ctr, (void)) X(const EVP_CIPHER *, EVP_aes_192_ctr, (void)) X(const EVP_CIPHER *, EVP_aes_256_ctr, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_cfb128, (void)) X(const EVP_CIPHER *, EVP_aes_192_cfb128, (void)) X(const EVP_CIPHER *, EVP_aes_256_cfb128, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_cfb8, (void)) X(const EVP_CIPHER *, EVP_aes_192_cfb8, (void)) X(const EVP_CIPHER *, EVP_aes_256_cfb8, (void)) \
    X(const EVP_CIPHER *, EVP_aes_128_ofb, (void)) X(const EVP_CIPHER *, EVP_aes_192_ofb, (void)) X(const EVP_CIPHER *, EVP_aes_256_ofb, (void)) \
    X(const EVP_CIPHER *, EVP_des_ede3_ecb, (void)) X(const EVP_CIPHER *, EVP_des_ede3_cbc, (void)) \
    X(EVP_PKEY *, EVP_PKEY_new_raw_private_key, (int, void *, const unsigned char *, size_t)) \
    X(EVP_PKEY *, EVP_PKEY_new_raw_public_key, (int, void *, const unsigned char *, size_t)) \
    X(int, EVP_PKEY_get_raw_public_key, (const EVP_PKEY *, unsigned char *, size_t *)) X(void, EVP_PKEY_free, (EVP_PKEY *)) \
    X(EVP_PKEY_CTX *, EVP_PKEY_CTX_new, (EVP_PKEY *, void *)) X(void, EVP_PKEY_CTX_free, (EVP_PKEY_CTX *)) \
    X(int, EVP_PKEY_derive_init, (EVP_PKEY_CTX *)) X(int, EVP_PKEY_derive_set_peer, (EVP_PKEY_CTX *, EVP_PKEY *)) \
    X(int, EVP_PKEY_derive, (EVP_PKEY_CTX *, unsigned char *, size_t *)) \
    X(EVP_MD_CTX *, EVP_MD_CTX_new, (void)) X(void, EVP_MD_CTX_free, (EVP_MD_CTX *)) \
    X(int, EVP_DigestSignInit, (EVP_MD_CTX *, EVP_PKEY_CTX **, const void *, void *, EVP_PKEY *)) \
    X(int, EVP_DigestSign, (EVP_MD_CTX *, unsigned char *, size_t *, const unsigned char *, size_t)) \
    X(int, EVP_DigestVerifyInit, (EVP_MD_CTX *, EVP_PKEY_CTX **, const void *, void *, EVP_PKEY *)) \
    X(int, EVP_DigestVerify, (EVP_MD_CTX *, const unsigned char *, size_t, const unsigned char *, size_t)) \
    X(EC_KEY *, EC_KEY_new_by_curve_name, (int)) X(void, EC_KEY_free, (EC_KEY *)) X(const EC_GROUP *, EC_KEY_get0_group, (const EC_KEY *)) \
    X(int, EC_KEY_set_private_key, (EC_KEY *, const BIGNUM *)) X(const BIGNUM *, EC_KEY_get0_private_key, (const EC_KEY *)) \
    X(int, EC_KEY_set_public_key, (EC_KEY *, const EC_POINT *)) X(const EC_POINT *, EC_KEY_get0_public_key, (const EC_KEY *)) \
    X(int, EC_KEY_generate_key, (EC_KEY *)) X(int, EC_KEY_check_key, (const EC_KEY *)) \
    X(EC_POINT *, EC_POINT_new, (const EC_GROUP *)) X(void, EC_POINT_free, (EC_POINT *)) \
    X(int, EC_POINT_mul, (const EC_GROUP *, EC_POINT *, const BIGNUM *, const EC_POINT *, const BIGNUM *, void *)) \
    X(size_t, EC_POINT_point2oct, (const EC_GROUP *, const EC_POINT *, int, unsigned char *, size_t, void *)) \
    X(int, EC_POINT_oct2point, (const EC_GROUP *, EC_POINT *, const unsigned char *, size_t, void *)) \
    X(BIGNUM *, BN_bin2bn, (const unsigned char *, int, BIGNUM *)) X(int, BN_bn2binpad, (const BIGNUM *, unsigned char *, int)) X(void, BN_free, (BIGNUM *)) \
    X(ECDSA_SIG *, ECDSA_do_sign, (const unsigned char *, int, EC_KEY *)) X(int, ECDSA_do_verify, (const unsigned char *, int, const ECDSA_SIG *, EC_KEY *)) \
    X(ECDSA_SIG *, ECDSA_SIG_new, (void)) X(void, ECDSA_SIG_free, (ECDSA_SIG *)) \
    X(void, ECDSA_SIG_get0, (const ECDSA_SIG *, const BIGNUM **, const BIGNUM **)) X(int, ECDSA_SIG_set0, (ECDSA_SIG *, BIGNUM *, BIGNUM *)) \
    X(int, ECDH_compute_key, (void *, size_t, const EC_POINT *, const EC_KEY *, void *))
#define DECL(ret, name, args) ret (*name) args;
static struct { LIBCRYPTO_FUNCS(DECL) } ossl;
static int ossl_state;   /* 0 = not tried, 1 = loaded, -1 = unavailable */
static pthread_once_t ossl_once = PTHREAD_ONCE_INIT;
static void ossl_load(void) {
    void *h = dlopen("libcrypto.so.3", RTLD_NOW | RTLD_LOCAL);
    if (!h) h = dlopen("libcrypto.so", RTLD_NOW | RTLD_LOCAL);
    if (!h) { ossl_state = -1; fprintf(stderr, "isim: OpenSSL libcrypto (libcrypto.so.3) not found on this host: AES, ChaChaPoly and public-key crypto are unavailable\n"); return; }
#define LOAD(ret, name, args) if (!(*(void **)&ossl.name = dlsym(h, #name))) { ossl_state = -1; fprintf(stderr, "isim: libcrypto lacks %s\n", #name); return; }
    LIBCRYPTO_FUNCS(LOAD)
    ossl_state = 1;
}
static int ossl_ok(void) { pthread_once(&ossl_once, ossl_load); return ossl_state == 1; }

/* ---- CCCrypt / CCCryptor ---- */
enum { kCCAlgorithmAES = 0, kCCAlgorithmDES = 1, kCCAlgorithm3DES = 2 };
enum { kCCOptionPKCS7Padding = 1, kCCOptionECBMode = 2 };
enum { kCCModeECB = 1, kCCModeCBC = 2, kCCModeCFB = 3, kCCModeCTR = 4, kCCModeOFB = 7, kCCModeCFB8 = 10 };
struct cryptor { EVP_CIPHER_CTX *ctx; int op, mode, padding, block; const EVP_CIPHER *cipher; uint8_t key[32]; size_t keylen; size_t buffered; };
static const EVP_CIPHER *pick_cipher(unsigned alg, int mode, size_t keylen, int *block, int *err) {
    *err = kCCSuccess;
    if (alg == kCCAlgorithmAES) {
        *block = 16;
        int k = keylen == 16 ? 0 : keylen == 24 ? 1 : keylen == 32 ? 2 : -1;
        if (k < 0) { *err = kCCParamError; return NULL; }
        switch (mode) {
        case kCCModeECB: return (k == 0 ? ossl.EVP_aes_128_ecb : k == 1 ? ossl.EVP_aes_192_ecb : ossl.EVP_aes_256_ecb)();
        case kCCModeCBC: return (k == 0 ? ossl.EVP_aes_128_cbc : k == 1 ? ossl.EVP_aes_192_cbc : ossl.EVP_aes_256_cbc)();
        case kCCModeCTR: return (k == 0 ? ossl.EVP_aes_128_ctr : k == 1 ? ossl.EVP_aes_192_ctr : ossl.EVP_aes_256_ctr)();
        case kCCModeCFB: return (k == 0 ? ossl.EVP_aes_128_cfb128 : k == 1 ? ossl.EVP_aes_192_cfb128 : ossl.EVP_aes_256_cfb128)();
        case kCCModeCFB8: return (k == 0 ? ossl.EVP_aes_128_cfb8 : k == 1 ? ossl.EVP_aes_192_cfb8 : ossl.EVP_aes_256_cfb8)();
        case kCCModeOFB: return (k == 0 ? ossl.EVP_aes_128_ofb : k == 1 ? ossl.EVP_aes_192_ofb : ossl.EVP_aes_256_ofb)();
        }
    } else if (alg == kCCAlgorithm3DES) {
        *block = 8;
        if (keylen != 24) { *err = kCCParamError; return NULL; }
        if (mode == kCCModeECB) return ossl.EVP_des_ede3_ecb();
        if (mode == kCCModeCBC) return ossl.EVP_des_ede3_cbc();
    }
    *err = kCCUnimplemented; return NULL;
}
static int cryptor_create(int op, int mode, unsigned alg, int padding, const void *iv, const void *key, size_t keylen, struct cryptor **out) {
    if (!out || (op != 0 && op != 1) || !key) return kCCParamError;
    if (!ossl_ok()) return kCCUnimplemented;
    int block, err; const EVP_CIPHER *c = pick_cipher(alg, mode, keylen, &block, &err);
    if (!c) return err;
    struct cryptor *cr = calloc(1, sizeof *cr);
    if (!cr || !(cr->ctx = ossl.EVP_CIPHER_CTX_new())) { free(cr); return kCCMemoryFailure; }
    uint8_t zero[16] = { 0 };
    if (!ossl.EVP_CipherInit_ex(cr->ctx, c, NULL, key, iv ? iv : zero, op == 0)) { ossl.EVP_CIPHER_CTX_free(cr->ctx); free(cr); return kCCParamError; }
    int blockmode = mode == kCCModeECB || mode == kCCModeCBC;
    cr->padding = blockmode && padding; cr->block = blockmode ? block : 1;
    ossl.EVP_CIPHER_CTX_set_padding(cr->ctx, cr->padding);
    cr->op = op; cr->mode = mode; cr->cipher = c; memcpy(cr->key, key, keylen); cr->keylen = keylen;
    *out = cr; return kCCSuccess;
}
static size_t cryptor_output_len(struct cryptor *cr, size_t in, int final) {
    size_t total = cr->buffered + in;
    if (cr->block == 1) return in;
    if (!final) return total - total % cr->block;
    if (cr->op == 0 && cr->padding) return total - total % cr->block + cr->block;
    return total;
}
static int cc_cryptor_create_with_mode(int op, int mode, unsigned alg, int padding, const void *iv, const void *key, size_t keylen,
                                       const void *tweak, size_t tweaklen, int rounds, unsigned options, struct cryptor **out) {
    return cryptor_create(op, mode, alg, padding, iv, key, keylen, out);
}
static int cc_cryptor_create(int op, unsigned alg, unsigned options, const void *key, size_t keylen, const void *iv, struct cryptor **out) {
    return cryptor_create(op, options & kCCOptionECBMode ? kCCModeECB : kCCModeCBC, alg, options & kCCOptionPKCS7Padding, iv, key, keylen, out);
}
static int cc_cryptor_update(struct cryptor *cr, const void *in, size_t inlen, void *out, size_t avail, size_t *moved) {
    if (!cr) return kCCParamError;
    size_t need = cryptor_output_len(cr, inlen, 0);
    if (cr->op == 1 && cr->padding && need >= (size_t)cr->block) need -= cr->block; /* OpenSSL holds back the last block when unpadding */
    if (avail < need) { if (moved) *moved = need; return kCCBufferTooSmall; }
    int outl = 0;
    if (inlen && !ossl.EVP_CipherUpdate(cr->ctx, out, &outl, in, (int)inlen)) return kCCDecodeError;
    cr->buffered = (cr->buffered + inlen) % (size_t)cr->block;
    if (moved) *moved = (size_t)outl;
    return kCCSuccess;
}
static int cc_cryptor_final(struct cryptor *cr, void *out, size_t avail, size_t *moved) {
    if (!cr) return kCCParamError;
    if (!cr->padding && cr->block > 1 && cr->buffered) return kCCAlignmentError;
    uint8_t tmp[32]; int outl = 0;
    if (!ossl.EVP_CipherFinal_ex(cr->ctx, tmp, &outl)) return cr->op == 1 ? kCCDecodeError : kCCAlignmentError;
    if ((size_t)outl > avail) { if (moved) *moved = (size_t)outl; return kCCBufferTooSmall; }
    if (outl) memcpy(out, tmp, (size_t)outl);
    if (moved) *moved = (size_t)outl;
    return kCCSuccess;
}
static int cc_cryptor_release(struct cryptor *cr) {
    if (cr) { if (cr->ctx) ossl.EVP_CIPHER_CTX_free(cr->ctx); memset(cr->key, 0, sizeof cr->key); free(cr); }
    return kCCSuccess;
}
static int cc_cryptor_reset(struct cryptor *cr, const void *iv) {
    if (!cr) return kCCParamError;
    uint8_t zero[16] = { 0 };
    if (!ossl.EVP_CipherInit_ex(cr->ctx, cr->cipher, NULL, cr->key, iv ? iv : zero, cr->op == 0)) return kCCParamError;
    ossl.EVP_CIPHER_CTX_set_padding(cr->ctx, cr->padding);
    cr->buffered = 0; return kCCSuccess;
}
static size_t cc_cryptor_get_output_length(struct cryptor *cr, size_t in, int final) { return cr ? cryptor_output_len(cr, in, final) : 0; }
static int cc_crypt(int op, unsigned alg, unsigned options, const void *key, size_t keylen, const void *iv,
                    const void *in, size_t inlen, void *out, size_t avail, size_t *moved) {
    struct cryptor *cr; int st = cc_cryptor_create(op, alg, options, key, keylen, iv, &cr);
    if (st) return st;
    size_t need = cryptor_output_len(cr, inlen, 1);
    if (cr->block > 1 && !cr->padding && inlen % (size_t)cr->block) { cc_cryptor_release(cr); return kCCAlignmentError; }
    if (avail < need) { if (moved) *moved = need; cc_cryptor_release(cr); return kCCBufferTooSmall; }
    uint8_t *tmp = malloc(need + 32); size_t a = 0, b = 0;
    if (!tmp) { cc_cryptor_release(cr); return kCCMemoryFailure; }
    st = cc_cryptor_update(cr, in, inlen, tmp, need + 32, &a);
    if (!st) st = cc_cryptor_final(cr, tmp + a, need + 32 - a, &b);
    cc_cryptor_release(cr);
    if (!st && a + b > avail) { if (moved) *moved = a + b; st = kCCBufferTooSmall; }
    else if (!st) { memcpy(out, tmp, a + b); if (moved) *moved = a + b; }
    memset(tmp, 0, need + 32); free(tmp);
    return st;
}

#define S_(n, f) { "_" n, (void *)f, "isim" }
static const struct shim commoncrypto_table[] = {
    S_("CC_MD5", cc_md5), S_("CC_MD5_Init", cc_md5_init), S_("CC_MD5_Update", cc_md5_update), S_("CC_MD5_Final", cc_md5_final),
    S_("CC_SHA1", cc_sha1), S_("CC_SHA1_Init", cc_sha1_init), S_("CC_SHA1_Update", cc_sha1_update), S_("CC_SHA1_Final", cc_sha1_final),
    S_("CC_SHA224", cc_sha224), S_("CC_SHA224_Init", cc_sha224_init), S_("CC_SHA224_Update", cc_sha224_update), S_("CC_SHA224_Final", cc_sha224_final),
    S_("CC_SHA256", cc_sha256), S_("CC_SHA256_Init", cc_sha256_init), S_("CC_SHA256_Update", cc_sha256_update), S_("CC_SHA256_Final", cc_sha256_final),
    S_("CC_SHA384", cc_sha384), S_("CC_SHA384_Init", cc_sha384_init), S_("CC_SHA384_Update", cc_sha384_update), S_("CC_SHA384_Final", cc_sha384_final),
    S_("CC_SHA512", cc_sha512), S_("CC_SHA512_Init", cc_sha512_init), S_("CC_SHA512_Update", cc_sha512_update), S_("CC_SHA512_Final", cc_sha512_final),
    S_("CCHmac", cc_hmac), S_("CCHmacInit", cc_hmac_init), S_("CCHmacUpdate", cc_hmac_update), S_("CCHmacFinal", cc_hmac_final),
    S_("CCKeyDerivationPBKDF", cc_pbkdf), S_("CCCalibratePBKDF", cc_calibrate_pbkdf), S_("CCRandomGenerateBytes", cc_random),
    S_("CCCrypt", cc_crypt), S_("CCCryptorCreate", cc_cryptor_create), S_("CCCryptorCreateWithMode", cc_cryptor_create_with_mode),
    S_("CCCryptorUpdate", cc_cryptor_update), S_("CCCryptorFinal", cc_cryptor_final), S_("CCCryptorRelease", cc_cryptor_release),
    S_("CCCryptorReset", cc_cryptor_reset), S_("CCCryptorGetOutputLength", cc_cryptor_get_output_length),
};
const struct host_lib host_commoncrypto = { "/usr/lib/system/libcommonCrypto.dylib", commoncrypto_table, sizeof commoncrypto_table / sizeof *commoncrypto_table };

/* ================= libisim_host: CryptoKit primitives ================= */
int isim_crypto_available(void) { return ossl_ok(); }

/* alg: 0 AES-GCM (16/24/32-byte key), 1 ChaCha20-Poly1305 (32-byte key). tag is 16 bytes.
   Returns 1 on success, 0 on failure (authentication failure when opening), -1 if libcrypto is missing. */
int isim_crypto_aead(int alg, int encrypt, const void *key, size_t keylen, const void *nonce, size_t noncelen,
                     const void *aad, size_t aadlen, const void *in, size_t inlen, void *out, void *tag) {
    if (!ossl_ok()) return -1;
    const EVP_CIPHER *c;
    if (alg == 0) c = keylen == 16 ? ossl.EVP_aes_128_gcm() : keylen == 24 ? ossl.EVP_aes_192_gcm() : keylen == 32 ? ossl.EVP_aes_256_gcm() : NULL;
    else c = keylen == 32 ? ossl.EVP_chacha20_poly1305() : NULL;
    if (!c || !noncelen) return 0;
    EVP_CIPHER_CTX *ctx = ossl.EVP_CIPHER_CTX_new(); int ok = 0, l = 0;
    if (!ctx) return 0;
    if (!ossl.EVP_CipherInit_ex(ctx, c, NULL, NULL, NULL, encrypt)) goto done;
    if (!ossl.EVP_CIPHER_CTX_ctrl(ctx, 0x9 /* EVP_CTRL_AEAD_SET_IVLEN */, (int)noncelen, NULL)) goto done;
    if (!ossl.EVP_CipherInit_ex(ctx, NULL, NULL, key, nonce, encrypt)) goto done;
    if (aadlen && !ossl.EVP_CipherUpdate(ctx, NULL, &l, aad, (int)aadlen)) goto done;
    if (inlen && !ossl.EVP_CipherUpdate(ctx, out, &l, in, (int)inlen)) goto done;
    if (!encrypt && !ossl.EVP_CIPHER_CTX_ctrl(ctx, 0x11 /* EVP_CTRL_AEAD_SET_TAG */, 16, tag)) goto done;
    uint8_t fin[32];
    if (ossl.EVP_CipherFinal_ex(ctx, fin, &l) <= 0) goto done;
    if (encrypt && !ossl.EVP_CIPHER_CTX_ctrl(ctx, 0x10 /* EVP_CTRL_AEAD_GET_TAG */, 16, tag)) goto done;
    ok = 1;
done:
    ossl.EVP_CIPHER_CTX_free(ctx);
    return ok;
}

/* ---- NIST curves: curve = 256, 384 or 521; scalars and coordinates are n = 32, 48 or 66 bytes ---- */
static int curve_nid(int curve, int *n) {
    switch (curve) { case 256: *n = 32; return 415; case 384: *n = 48; return 715; case 521: *n = 66; return 716; }
    return 0;
}
static EC_KEY *ec_from_private(int curve, const uint8_t *priv, int *n) {
    int nid = curve_nid(curve, n); if (!nid || !ossl_ok()) return NULL;
    EC_KEY *k = ossl.EC_KEY_new_by_curve_name(nid); if (!k) return NULL;
    const EC_GROUP *g = ossl.EC_KEY_get0_group(k);
    BIGNUM *d = ossl.BN_bin2bn(priv, *n, NULL); EC_POINT *p = ossl.EC_POINT_new(g);
    int ok = d && p && ossl.EC_KEY_set_private_key(k, d) && ossl.EC_POINT_mul(g, p, d, NULL, NULL, NULL) && ossl.EC_KEY_set_public_key(k, p) && ossl.EC_KEY_check_key(k);
    if (d) ossl.BN_free(d);
    if (p) ossl.EC_POINT_free(p);
    if (!ok) { ossl.EC_KEY_free(k); return NULL; }
    return k;
}
/* pub: X9.63 uncompressed (0x04||X||Y) or compressed (0x02/0x03||X) */
static EC_KEY *ec_from_public(int curve, const uint8_t *pub, size_t len, int *n) {
    int nid = curve_nid(curve, n); if (!nid || !ossl_ok()) return NULL;
    EC_KEY *k = ossl.EC_KEY_new_by_curve_name(nid); if (!k) return NULL;
    const EC_GROUP *g = ossl.EC_KEY_get0_group(k); EC_POINT *p = ossl.EC_POINT_new(g);
    int ok = p && ossl.EC_POINT_oct2point(g, p, pub, len, NULL) && ossl.EC_KEY_set_public_key(k, p) && ossl.EC_KEY_check_key(k);
    if (p) ossl.EC_POINT_free(p);
    if (!ok) { ossl.EC_KEY_free(k); return NULL; }
    return k;
}
int isim_crypto_ec_generate(int curve, uint8_t *priv) {
    int n, nid = curve_nid(curve, &n); if (!nid || !ossl_ok()) return 0;
    EC_KEY *k = ossl.EC_KEY_new_by_curve_name(nid); if (!k) return 0;
    int ok = ossl.EC_KEY_generate_key(k) && ossl.BN_bn2binpad(ossl.EC_KEY_get0_private_key(k), priv, n) == n;
    ossl.EC_KEY_free(k); return ok;
}
/* form: 4 uncompressed (1 + 2n bytes), 2 compressed (1 + n bytes). Returns the length written or 0. */
static size_t ec_point_out(EC_KEY *k, int form, uint8_t *out, size_t cap) {
    return ossl.EC_POINT_point2oct(ossl.EC_KEY_get0_group(k), ossl.EC_KEY_get0_public_key(k), form, out, cap, NULL);
}
int isim_crypto_ec_public(int curve, const uint8_t *priv, uint8_t *pub) {
    int n; EC_KEY *k = ec_from_private(curve, priv, &n); if (!k) return 0;
    size_t r = ec_point_out(k, 4, pub, 1 + 2 * (size_t)n); ossl.EC_KEY_free(k); return r == 1 + 2 * (size_t)n;
}
/* validates a public key (X9.63 uncompressed or compressed) and writes its uncompressed form */
int isim_crypto_ec_import_public(int curve, const uint8_t *pub, size_t len, uint8_t *uncompressed) {
    int n; EC_KEY *k = ec_from_public(curve, pub, len, &n); if (!k) return 0;
    size_t r = ec_point_out(k, 4, uncompressed, 1 + 2 * (size_t)n); ossl.EC_KEY_free(k); return r == 1 + 2 * (size_t)n;
}
int isim_crypto_ec_compress(int curve, const uint8_t *pub, size_t len, uint8_t *compressed) {
    int n; EC_KEY *k = ec_from_public(curve, pub, len, &n); if (!k) return 0;
    size_t r = ec_point_out(k, 2, compressed, 1 + (size_t)n); ossl.EC_KEY_free(k); return r == 1 + (size_t)n;
}
int isim_crypto_ec_sign(int curve, const uint8_t *priv, const uint8_t *digest, size_t dlen, uint8_t *sig) {
    int n; EC_KEY *k = ec_from_private(curve, priv, &n); if (!k) return 0;
    ECDSA_SIG *s = ossl.ECDSA_do_sign(digest, (int)dlen, k); int ok = 0;
    if (s) {
        const BIGNUM *r, *ss; ossl.ECDSA_SIG_get0(s, &r, &ss);
        ok = ossl.BN_bn2binpad(r, sig, n) == n && ossl.BN_bn2binpad(ss, sig + n, n) == n;
        ossl.ECDSA_SIG_free(s);
    }
    ossl.EC_KEY_free(k); return ok;
}
int isim_crypto_ec_verify(int curve, const uint8_t *pub, size_t publen, const uint8_t *digest, size_t dlen, const uint8_t *sig) {
    int n; EC_KEY *k = ec_from_public(curve, pub, publen, &n); if (!k) return 0;
    ECDSA_SIG *s = ossl.ECDSA_SIG_new(); int ok = 0;
    BIGNUM *r = ossl.BN_bin2bn(sig, n, NULL), *ss = ossl.BN_bin2bn(sig + n, n, NULL);
    if (s && r && ss && ossl.ECDSA_SIG_set0(s, r, ss)) { r = ss = NULL; ok = ossl.ECDSA_do_verify(digest, (int)dlen, s, k) == 1; }
    if (r) ossl.BN_free(r);
    if (ss) ossl.BN_free(ss);
    if (s) ossl.ECDSA_SIG_free(s);
    ossl.EC_KEY_free(k); return ok;
}
int isim_crypto_ec_ecdh(int curve, const uint8_t *priv, const uint8_t *pub, size_t publen, uint8_t *shared) {
    int n, m; EC_KEY *k = ec_from_private(curve, priv, &n), *peer = ec_from_public(curve, pub, publen, &m);
    int ok = k && peer && ossl.ECDH_compute_key(shared, (size_t)n, ossl.EC_KEY_get0_public_key(peer), k, NULL) == n;
    if (k) ossl.EC_KEY_free(k);
    if (peer) ossl.EC_KEY_free(peer);
    return ok;
}

/* ---- Curve25519: kind 0 = X25519 (key agreement), 1 = Ed25519 (signing) ---- */
static int kind_nid(int kind) { return kind ? 1087 /* EVP_PKEY_ED25519 */ : 1034 /* EVP_PKEY_X25519 */; }
int isim_crypto_25519_public(int kind, const uint8_t *priv, uint8_t *pub) {
    if (!ossl_ok()) return 0;
    EVP_PKEY *k = ossl.EVP_PKEY_new_raw_private_key(kind_nid(kind), NULL, priv, 32); if (!k) return 0;
    size_t len = 32; int ok = ossl.EVP_PKEY_get_raw_public_key(k, pub, &len) == 1 && len == 32;
    ossl.EVP_PKEY_free(k); return ok;
}
int isim_crypto_25519_check_public(int kind, const uint8_t *pub) {
    if (!ossl_ok()) return 0;
    EVP_PKEY *k = ossl.EVP_PKEY_new_raw_public_key(kind_nid(kind), NULL, pub, 32); if (!k) return 0;
    ossl.EVP_PKEY_free(k); return 1;
}
int isim_crypto_x25519(const uint8_t *priv, const uint8_t *pub, uint8_t *shared) {
    if (!ossl_ok()) return 0;
    EVP_PKEY *k = ossl.EVP_PKEY_new_raw_private_key(1034, NULL, priv, 32), *p = ossl.EVP_PKEY_new_raw_public_key(1034, NULL, pub, 32);
    EVP_PKEY_CTX *c = k ? ossl.EVP_PKEY_CTX_new(k, NULL) : NULL; size_t len = 32;
    int ok = c && p && ossl.EVP_PKEY_derive_init(c) > 0 && ossl.EVP_PKEY_derive_set_peer(c, p) > 0 && ossl.EVP_PKEY_derive(c, shared, &len) > 0 && len == 32;
    if (c) ossl.EVP_PKEY_CTX_free(c);
    if (k) ossl.EVP_PKEY_free(k);
    if (p) ossl.EVP_PKEY_free(p);
    return ok;
}
int isim_crypto_ed25519_sign(const uint8_t *priv, const void *msg, size_t len, uint8_t *sig) {
    if (!ossl_ok()) return 0;
    EVP_PKEY *k = ossl.EVP_PKEY_new_raw_private_key(1087, NULL, priv, 32); EVP_MD_CTX *m = ossl.EVP_MD_CTX_new(); size_t sl = 64;
    int ok = k && m && ossl.EVP_DigestSignInit(m, NULL, NULL, NULL, k) == 1 && ossl.EVP_DigestSign(m, sig, &sl, msg, len) == 1 && sl == 64;
    if (m) ossl.EVP_MD_CTX_free(m);
    if (k) ossl.EVP_PKEY_free(k);
    return ok;
}
int isim_crypto_ed25519_verify(const uint8_t *pub, const void *msg, size_t len, const uint8_t *sig) {
    if (!ossl_ok()) return 0;
    EVP_PKEY *k = ossl.EVP_PKEY_new_raw_public_key(1087, NULL, pub, 32); EVP_MD_CTX *m = ossl.EVP_MD_CTX_new();
    int ok = k && m && ossl.EVP_DigestVerifyInit(m, NULL, NULL, NULL, k) == 1 && ossl.EVP_DigestVerify(m, sig, 64, msg, len) == 1;
    if (m) ossl.EVP_MD_CTX_free(m);
    if (k) ossl.EVP_PKEY_free(k);
    return ok;
}
