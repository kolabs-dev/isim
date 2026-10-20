/* isim CoreGraphics: the primitives of PDF's standard security handler (CGPDFParser.c): MD5, RC4, AES-128/256 (CBC,
 * both ways) and SHA-256/384/512. Small, portable implementations of the public algorithms (RFC 1321, FIPS 197,
 * FIPS 180-4); they only decrypt documents, so speed matters little. */
#include "cg_pdf.h"
#include <string.h>

/* ---------------- MD5 ---------------- */
static const uint32_t md5_k[64] = {
    0xd76aa478, 0xe8c7b756, 0x242070db, 0xc1bdceee, 0xf57c0faf, 0x4787c62a, 0xa8304613, 0xfd469501, 0x698098d8, 0x8b44f7af,
    0xffff5bb1, 0x895cd7be, 0x6b901122, 0xfd987193, 0xa679438e, 0x49b40821, 0xf61e2562, 0xc040b340, 0x265e5a51, 0xe9b6c7aa,
    0xd62f105d, 0x02441453, 0xd8a1e681, 0xe7d3fbc8, 0x21e1cde6, 0xc33707d6, 0xf4d50d87, 0x455a14ed, 0xa9e3e905, 0xfcefa3f8,
    0x676f02d9, 0x8d2a4c8a, 0xfffa3942, 0x8771f681, 0x6d9d6122, 0xfde5380c, 0xa4beea44, 0x4bdecfa9, 0xf6bb4b60, 0xbebfbc70,
    0x289b7ec6, 0xeaa127fa, 0xd4ef3085, 0x04881d05, 0xd9d4d039, 0xe6db99e5, 0x1fa27cf8, 0xc4ac5665, 0xf4292244, 0x432aff97,
    0xab9423a7, 0xfc93a039, 0x655b59c3, 0x8f0ccc92, 0xffeff47d, 0x85845dd1, 0x6fa87e4f, 0xfe2ce6e0, 0xa3014314, 0x4e0811a1,
    0xf7537e82, 0xbd3af235, 0x2ad7d2bb, 0xeb86d391 };
static const uint8_t md5_r[64] = { 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 7, 12, 17, 22, 5, 9, 14, 20, 5, 9, 14, 20, 5, 9, 14, 20,
                                   5, 9, 14, 20, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 4, 11, 16, 23, 6, 10, 15, 21, 6, 10, 15, 21,
                                   6, 10, 15, 21, 6, 10, 15, 21 };
static uint32_t rol(uint32_t x, int n) { return (x << n) | (x >> (32 - n)); }
static void md5_block(uint32_t h[4], const uint8_t *p) {
    uint32_t w[16], a = h[0], b = h[1], c = h[2], d = h[3];
    for (int i = 0; i < 16; i++) w[i] = p[i * 4] | p[i * 4 + 1] << 8 | p[i * 4 + 2] << 16 | (uint32_t)p[i * 4 + 3] << 24;
    for (int i = 0; i < 64; i++) {
        uint32_t f; int g;
        if (i < 16) { f = (b & c) | (~b & d); g = i; }
        else if (i < 32) { f = (d & b) | (~d & c); g = (5 * i + 1) & 15; }
        else if (i < 48) { f = b ^ c ^ d; g = (3 * i + 5) & 15; }
        else { f = c ^ (b | ~d); g = (7 * i) & 15; }
        uint32_t t = d; d = c; c = b; b = b + rol(a + f + md5_k[i] + w[g], md5_r[i]); a = t;
    }
    h[0] += a; h[1] += b; h[2] += c; h[3] += d;
}
void isim_pdf_md5(const uint8_t *data, size_t n, uint8_t out[16]) {
    uint32_t h[4] = { 0x67452301, 0xefcdab89, 0x98badcfe, 0x10325476 };
    size_t i = 0;
    for (; i + 64 <= n; i += 64) md5_block(h, data + i);
    uint8_t tail[128] = { 0 };
    size_t r = n - i;
    memcpy(tail, data + i, r);
    tail[r] = 0x80;
    size_t tn = r + 9 <= 64 ? 64 : 128;
    uint64_t bits = (uint64_t)n * 8;
    for (int k = 0; k < 8; k++) tail[tn - 8 + k] = (uint8_t)(bits >> (8 * k));
    for (size_t k = 0; k < tn; k += 64) md5_block(h, tail + k);
    for (int k = 0; k < 4; k++) for (int j = 0; j < 4; j++) out[k * 4 + j] = (uint8_t)(h[k] >> (8 * j));
}

/* ---------------- RC4 ---------------- */
void isim_pdf_rc4(const uint8_t *key, size_t keylen, uint8_t *buf, size_t n) {
    uint8_t s[256];
    for (int i = 0; i < 256; i++) s[i] = (uint8_t)i;
    for (int i = 0, j = 0; i < 256; i++) { j = (j + s[i] + key[i % keylen]) & 255; uint8_t t = s[i]; s[i] = s[j]; s[j] = t; }
    for (size_t k = 0, i = 0, j = 0; k < n; k++) {
        i = (i + 1) & 255; j = (j + s[i]) & 255;
        uint8_t t = s[i]; s[i] = s[j]; s[j] = t;
        buf[k] ^= s[(s[i] + s[j]) & 255];
    }
}

/* ---------------- AES ---------------- */
static uint8_t sbox[256], inv_sbox[256];
static void aes_tables(void) {
    if (sbox[0]) return;
    uint8_t p = 1, q = 1;
    do {                                           /* p walks the multiplicative group by 3, q by its inverse */
        p = p ^ (uint8_t)(p << 1) ^ (p & 0x80 ? 0x1b : 0);
        q ^= q << 1; q ^= q << 2; q ^= q << 4; if (q & 0x80) q ^= 0x09;
        uint8_t x = q ^ (uint8_t)((q << 1) | (q >> 7)) ^ (uint8_t)((q << 2) | (q >> 6)) ^ (uint8_t)((q << 3) | (q >> 5)) ^
                    (uint8_t)((q << 4) | (q >> 4));
        sbox[p] = x ^ 0x63;
    } while (p != 1);
    sbox[0] = 0x63;
    for (int i = 0; i < 256; i++) inv_sbox[sbox[i]] = (uint8_t)i;
}
static uint8_t xt(uint8_t x) { return (uint8_t)((x << 1) ^ (x & 0x80 ? 0x1b : 0)); }
static uint8_t gmul(uint8_t a, uint8_t b) { uint8_t r = 0; while (b) { if (b & 1) r ^= a; a = xt(a); b >>= 1; } return r; }
/* round keys for a 16- or 32-byte key; returns the number of rounds */
static int aes_expand(const uint8_t *key, int keylen, uint8_t rk[240]) {
    aes_tables();
    int nk = keylen / 4, nr = nk + 6;
    memcpy(rk, key, (size_t)keylen);
    uint8_t rcon = 1;
    for (int i = nk; i < 4 * (nr + 1); i++) {
        uint8_t t[4]; memcpy(t, rk + (i - 1) * 4, 4);
        if (i % nk == 0) {
            uint8_t u = t[0]; t[0] = sbox[t[1]] ^ rcon; t[1] = sbox[t[2]]; t[2] = sbox[t[3]]; t[3] = sbox[u];
            rcon = xt(rcon);
        } else if (nk > 6 && i % nk == 4) { for (int k = 0; k < 4; k++) t[k] = sbox[t[k]]; }
        for (int k = 0; k < 4; k++) rk[i * 4 + k] = rk[(i - nk) * 4 + k] ^ t[k];
    }
    return nr;
}
static void aes_encrypt_block(const uint8_t *rk, int nr, uint8_t s[16]) {
    for (int k = 0; k < 16; k++) s[k] ^= rk[k];
    for (int r = 1; r <= nr; r++) {
        uint8_t t[16];
        for (int k = 0; k < 16; k++) t[k] = sbox[s[(k + 4 * (k % 4)) % 16]];       /* SubBytes + ShiftRows */
        if (r != nr)
            for (int c = 0; c < 4; c++) {
                uint8_t *m = t + 4 * c, a0 = m[0], a1 = m[1], a2 = m[2], a3 = m[3];
                m[0] = xt(a0) ^ xt(a1) ^ a1 ^ a2 ^ a3; m[1] = a0 ^ xt(a1) ^ xt(a2) ^ a2 ^ a3;
                m[2] = a0 ^ a1 ^ xt(a2) ^ xt(a3) ^ a3; m[3] = xt(a0) ^ a0 ^ a1 ^ a2 ^ xt(a3);
            }
        for (int k = 0; k < 16; k++) s[k] = t[k] ^ rk[r * 16 + k];
    }
}
static void aes_decrypt_block(const uint8_t *rk, int nr, uint8_t s[16]) {
    for (int k = 0; k < 16; k++) s[k] ^= rk[nr * 16 + k];
    for (int r = nr - 1; r >= 0; r--) {
        uint8_t t[16];
        for (int k = 0; k < 16; k++) t[(k + 4 * (k % 4)) % 16] = inv_sbox[s[k]];   /* InvShiftRows + InvSubBytes */
        for (int k = 0; k < 16; k++) t[k] ^= rk[r * 16 + k];
        if (r)
            for (int c = 0; c < 4; c++) {
                uint8_t *m = t + 4 * c, a0 = m[0], a1 = m[1], a2 = m[2], a3 = m[3];
                m[0] = gmul(a0, 14) ^ gmul(a1, 11) ^ gmul(a2, 13) ^ gmul(a3, 9);
                m[1] = gmul(a0, 9) ^ gmul(a1, 14) ^ gmul(a2, 11) ^ gmul(a3, 13);
                m[2] = gmul(a0, 13) ^ gmul(a1, 9) ^ gmul(a2, 14) ^ gmul(a3, 11);
                m[3] = gmul(a0, 11) ^ gmul(a1, 13) ^ gmul(a2, 9) ^ gmul(a3, 14);
            }
        memcpy(s, t, 16);
    }
}
/* AES-CBC decryption in place; n a multiple of 16; iv may be NULL (zeros) */
void isim_pdf_aes_cbc_decrypt(const uint8_t *key, int keylen, const uint8_t *iv, uint8_t *buf, size_t n) {
    uint8_t rk[240], prev[16] = { 0 }, cur[16];
    int nr = aes_expand(key, keylen, rk);
    if (iv) memcpy(prev, iv, 16);
    for (size_t i = 0; i + 16 <= n; i += 16) {
        memcpy(cur, buf + i, 16);
        aes_decrypt_block(rk, nr, buf + i);
        for (int k = 0; k < 16; k++) buf[i + k] ^= prev[k];
        memcpy(prev, cur, 16);
    }
}
void isim_pdf_aes_cbc_encrypt(const uint8_t *key, int keylen, const uint8_t *iv, uint8_t *buf, size_t n) {
    uint8_t rk[240], prev[16] = { 0 };
    int nr = aes_expand(key, keylen, rk);
    if (iv) memcpy(prev, iv, 16);
    for (size_t i = 0; i + 16 <= n; i += 16) {
        for (int k = 0; k < 16; k++) buf[i + k] ^= prev[k];
        aes_encrypt_block(rk, nr, buf + i);
        memcpy(prev, buf + i, 16);
    }
}

/* ---------------- SHA-2 ---------------- */
static const uint32_t k256[64] = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01,
    0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
    0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da, 0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
    0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070, 0x19a4c116, 0x1e376c08,
    0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
    0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2 };
static uint32_t ror(uint32_t x, int n) { return (x >> n) | (x << (32 - n)); }
void isim_pdf_sha256(const uint8_t *data, size_t n, uint8_t out[32]) {
    uint32_t h[8] = { 0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19 };
    size_t total = ((n + 9 + 63) / 64) * 64;
    for (size_t off = 0; off < total; off += 64) {
        uint8_t blk[64];
        for (int i = 0; i < 64; i++) {
            size_t at = off + (size_t)i;
            blk[i] = at < n ? data[at] : at == n ? 0x80 : 0;
        }
        if (off + 64 == total) for (int k = 0; k < 8; k++) blk[63 - k] = (uint8_t)(((uint64_t)n * 8) >> (8 * k));
        uint32_t w[64];
        for (int i = 0; i < 16; i++) w[i] = (uint32_t)blk[i * 4] << 24 | blk[i * 4 + 1] << 16 | blk[i * 4 + 2] << 8 | blk[i * 4 + 3];
        for (int i = 16; i < 64; i++) {
            uint32_t s0 = ror(w[i - 15], 7) ^ ror(w[i - 15], 18) ^ (w[i - 15] >> 3), s1 = ror(w[i - 2], 17) ^ ror(w[i - 2], 19) ^ (w[i - 2] >> 10);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        uint32_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 64; i++) {
            uint32_t t1 = hh + (ror(e, 6) ^ ror(e, 11) ^ ror(e, 25)) + ((e & f) ^ (~e & g)) + k256[i] + w[i];
            uint32_t t2 = (ror(a, 2) ^ ror(a, 13) ^ ror(a, 22)) + ((a & b) ^ (a & c) ^ (b & c));
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    for (int i = 0; i < 8; i++) for (int j = 0; j < 4; j++) out[i * 4 + j] = (uint8_t)(h[i] >> (24 - 8 * j));
}
static const uint64_t k512[80] = {
    0x428a2f98d728ae22ull, 0x7137449123ef65cdull, 0xb5c0fbcfec4d3b2full, 0xe9b5dba58189dbbcull, 0x3956c25bf348b538ull,
    0x59f111f1b605d019ull, 0x923f82a4af194f9bull, 0xab1c5ed5da6d8118ull, 0xd807aa98a3030242ull, 0x12835b0145706fbeull,
    0x243185be4ee4b28cull, 0x550c7dc3d5ffb4e2ull, 0x72be5d74f27b896full, 0x80deb1fe3b1696b1ull, 0x9bdc06a725c71235ull,
    0xc19bf174cf692694ull, 0xe49b69c19ef14ad2ull, 0xefbe4786384f25e3ull, 0x0fc19dc68b8cd5b5ull, 0x240ca1cc77ac9c65ull,
    0x2de92c6f592b0275ull, 0x4a7484aa6ea6e483ull, 0x5cb0a9dcbd41fbd4ull, 0x76f988da831153b5ull, 0x983e5152ee66dfabull,
    0xa831c66d2db43210ull, 0xb00327c898fb213full, 0xbf597fc7beef0ee4ull, 0xc6e00bf33da88fc2ull, 0xd5a79147930aa725ull,
    0x06ca6351e003826full, 0x142929670a0e6e70ull, 0x27b70a8546d22ffcull, 0x2e1b21385c26c926ull, 0x4d2c6dfc5ac42aedull,
    0x53380d139d95b3dfull, 0x650a73548baf63deull, 0x766a0abb3c77b2a8ull, 0x81c2c92e47edaee6ull, 0x92722c851482353bull,
    0xa2bfe8a14cf10364ull, 0xa81a664bbc423001ull, 0xc24b8b70d0f89791ull, 0xc76c51a30654be30ull, 0xd192e819d6ef5218ull,
    0xd69906245565a910ull, 0xf40e35855771202aull, 0x106aa07032bbd1b8ull, 0x19a4c116b8d2d0c8ull, 0x1e376c085141ab53ull,
    0x2748774cdf8eeb99ull, 0x34b0bcb5e19b48a8ull, 0x391c0cb3c5c95a63ull, 0x4ed8aa4ae3418acbull, 0x5b9cca4f7763e373ull,
    0x682e6ff3d6b2b8a3ull, 0x748f82ee5defb2fcull, 0x78a5636f43172f60ull, 0x84c87814a1f0ab72ull, 0x8cc702081a6439ecull,
    0x90befffa23631e28ull, 0xa4506cebde82bde9ull, 0xbef9a3f7b2c67915ull, 0xc67178f2e372532bull, 0xca273eceea26619cull,
    0xd186b8c721c0c207ull, 0xeada7dd6cde0eb1eull, 0xf57d4f7fee6ed178ull, 0x06f067aa72176fbaull, 0x0a637dc5a2c898a6ull,
    0x113f9804bef90daeull, 0x1b710b35131c471bull, 0x28db77f523047d84ull, 0x32caab7b40c72493ull, 0x3c9ebe0a15c9bebcull,
    0x431d67c49c100d4cull, 0x4cc5d4becb3e42b6ull, 0x597f299cfc657e2aull, 0x5fcb6fab3ad6faecull, 0x6c44198c4a475817ull };
static uint64_t ror64(uint64_t x, int n) { return (x >> n) | (x << (64 - n)); }
/* SHA-512, or SHA-384 (bits 384: other initial values, 48 bytes out) */
void isim_pdf_sha512(const uint8_t *data, size_t n, uint8_t *out, int bits) {
    uint64_t h[8];
    static const uint64_t h512[8] = { 0x6a09e667f3bcc908ull, 0xbb67ae8584caa73bull, 0x3c6ef372fe94f82bull, 0xa54ff53a5f1d36f1ull,
                                      0x510e527fade682d1ull, 0x9b05688c2b3e6c1full, 0x1f83d9abfb41bd6bull, 0x5be0cd19137e2179ull };
    static const uint64_t h384[8] = { 0xcbbb9d5dc1059ed8ull, 0x629a292a367cd507ull, 0x9159015a3070dd17ull, 0x152fecd8f70e5939ull,
                                      0x67332667ffc00b31ull, 0x8eb44a8768581511ull, 0xdb0c2e0d64f98fa7ull, 0x47b5481dbefa4fa4ull };
    memcpy(h, bits == 384 ? h384 : h512, sizeof h);
    size_t total = ((n + 17 + 127) / 128) * 128;
    for (size_t off = 0; off < total; off += 128) {
        uint8_t blk[128];
        for (int i = 0; i < 128; i++) {
            size_t at = off + (size_t)i;
            blk[i] = at < n ? data[at] : at == n ? 0x80 : 0;
        }
        if (off + 128 == total) for (int k = 0; k < 8; k++) blk[127 - k] = (uint8_t)(((uint64_t)n * 8) >> (8 * k));
        uint64_t w[80];
        for (int i = 0; i < 16; i++) { w[i] = 0; for (int k = 0; k < 8; k++) w[i] = w[i] << 8 | blk[i * 8 + k]; }
        for (int i = 16; i < 80; i++) {
            uint64_t s0 = ror64(w[i - 15], 1) ^ ror64(w[i - 15], 8) ^ (w[i - 15] >> 7), s1 = ror64(w[i - 2], 19) ^ ror64(w[i - 2], 61) ^ (w[i - 2] >> 6);
            w[i] = w[i - 16] + s0 + w[i - 7] + s1;
        }
        uint64_t a = h[0], b = h[1], c = h[2], d = h[3], e = h[4], f = h[5], g = h[6], hh = h[7];
        for (int i = 0; i < 80; i++) {
            uint64_t t1 = hh + (ror64(e, 14) ^ ror64(e, 18) ^ ror64(e, 41)) + ((e & f) ^ (~e & g)) + k512[i] + w[i];
            uint64_t t2 = (ror64(a, 28) ^ ror64(a, 34) ^ ror64(a, 39)) + ((a & b) ^ (a & c) ^ (b & c));
            hh = g; g = f; f = e; e = d + t1; d = c; c = b; b = a; a = t1 + t2;
        }
        h[0] += a; h[1] += b; h[2] += c; h[3] += d; h[4] += e; h[5] += f; h[6] += g; h[7] += hh;
    }
    int words = bits == 384 ? 6 : 8;
    for (int i = 0; i < words; i++) for (int j = 0; j < 8; j++) out[i * 8 + j] = (uint8_t)(h[i] >> (56 - 8 * j));
}
