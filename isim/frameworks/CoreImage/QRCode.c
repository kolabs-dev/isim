/* isim Core Image: QR Code symbols (ISO/IEC 18004) for CIQRCodeGenerator — byte mode, versions 1-40, error
 * correction L/M/Q/H, Reed-Solomon over GF(256), mask pattern chosen by the standard's penalty rules. */
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

static const int8_t ECC_PER_BLOCK[4][41] = {
    { -1, 7, 10, 15, 20, 26, 18, 20, 24, 30, 18, 20, 24, 26, 30, 22, 24, 28, 30, 28, 28, 28, 28, 30, 30, 26, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30 },
    { -1, 10, 16, 26, 18, 24, 16, 18, 22, 22, 26, 30, 22, 22, 24, 24, 28, 28, 26, 26, 26, 26, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28, 28 },
    { -1, 13, 22, 18, 26, 18, 24, 18, 22, 20, 24, 28, 26, 24, 20, 30, 24, 28, 28, 26, 30, 28, 30, 30, 30, 30, 28, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30 },
    { -1, 17, 28, 22, 16, 22, 28, 26, 26, 24, 28, 24, 28, 22, 24, 24, 30, 28, 28, 26, 28, 30, 24, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, 30 },
};
static const int8_t NUM_BLOCKS[4][41] = {
    { -1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 4, 4, 4, 4, 4, 6, 6, 6, 6, 7, 8, 8, 9, 9, 10, 12, 12, 12, 13, 14, 15, 16, 17, 18, 19, 19, 20, 21, 22, 24, 25 },
    { -1, 1, 1, 1, 2, 2, 4, 4, 4, 5, 5, 5, 8, 9, 9, 10, 10, 11, 13, 14, 16, 17, 17, 18, 20, 21, 23, 25, 26, 28, 29, 31, 33, 35, 37, 38, 40, 43, 45, 47, 49 },
    { -1, 1, 1, 2, 2, 4, 4, 6, 6, 8, 8, 8, 10, 12, 16, 12, 17, 16, 18, 21, 20, 23, 23, 25, 27, 29, 34, 34, 35, 38, 40, 43, 45, 48, 51, 53, 56, 59, 62, 65, 68 },
    { -1, 1, 1, 2, 4, 4, 4, 5, 6, 8, 8, 11, 11, 16, 16, 18, 16, 19, 21, 25, 25, 25, 34, 30, 32, 35, 37, 40, 42, 45, 48, 51, 54, 57, 60, 63, 66, 70, 74, 77, 81 },
};
static int raw_modules(int v) {
    int r = (16 * v + 128) * v + 64;
    if (v >= 2) { int n = v / 7 + 2; r -= (25 * n - 10) * n - 55; if (v >= 7) r -= 36; }
    return r;
}
static int data_codewords(int v, int ecl) { return raw_modules(v) / 8 - ECC_PER_BLOCK[ecl][v] * NUM_BLOCKS[ecl][v]; }
static uint8_t gf_mul(uint8_t x, uint8_t y) {
    int z = 0;
    for (int i = 7; i >= 0; i--) { z = (z << 1) ^ ((z >> 7) * 0x11D); z ^= ((y >> i) & 1) * x; }
    return (uint8_t)z;
}
static void rs_divisor(int degree, uint8_t *res) {
    memset(res, 0, (size_t)degree); res[degree - 1] = 1;
    uint8_t root = 1;
    for (int i = 0; i < degree; i++) {
        for (int j = 0; j < degree; j++) { res[j] = gf_mul(res[j], root); if (j + 1 < degree) res[j] ^= res[j + 1]; }
        root = gf_mul(root, 0x02);
    }
}
static void rs_remainder(const uint8_t *data, int len, const uint8_t *div, int degree, uint8_t *res) {
    memset(res, 0, (size_t)degree);
    for (int i = 0; i < len; i++) {
        uint8_t f = data[i] ^ res[0];
        memmove(res, res + 1, (size_t)degree - 1); res[degree - 1] = 0;
        for (int j = 0; j < degree; j++) res[j] ^= gf_mul(div[j], f);
    }
}

struct qr { int size; uint8_t m[177 * 177], fn[177 * 177]; };
#define M(q, x, y) (q)->m[(y) * (q)->size + (x)]
#define F(q, x, y) (q)->fn[(y) * (q)->size + (x)]
static void setf(struct qr *q, int x, int y, int dark) { M(q, x, y) = (uint8_t)dark; F(q, x, y) = 1; }
static void finder(struct qr *q, int x, int y) {
    for (int dy = -4; dy <= 4; dy++) for (int dx = -4; dx <= 4; dx++) {
        int d = abs(dx) > abs(dy) ? abs(dx) : abs(dy), xx = x + dx, yy = y + dy;
        if (xx >= 0 && xx < q->size && yy >= 0 && yy < q->size) setf(q, xx, yy, d != 2 && d != 4);
    }
}
static void alignment(struct qr *q, int x, int y) {
    for (int dy = -2; dy <= 2; dy++) for (int dx = -2; dx <= 2; dx++) setf(q, x + dx, y + dy, (abs(dx) > abs(dy) ? abs(dx) : abs(dy)) != 1);
}
static void format_bits(struct qr *q, int ecl, int mask) {
    static const int ecl_bits[4] = { 1, 0, 3, 2 };
    int data = ecl_bits[ecl] << 3 | mask, rem = data;
    for (int i = 0; i < 10; i++) rem = (rem << 1) ^ ((rem >> 9) * 0x537);
    int bits = (data << 10 | rem) ^ 0x5412, s = q->size;
    for (int i = 0; i <= 5; i++) setf(q, 8, i, (bits >> i) & 1);
    setf(q, 8, 7, (bits >> 6) & 1); setf(q, 8, 8, (bits >> 7) & 1); setf(q, 7, 8, (bits >> 8) & 1);
    for (int i = 9; i < 15; i++) setf(q, 14 - i, 8, (bits >> i) & 1);
    for (int i = 0; i < 8; i++) setf(q, s - 1 - i, 8, (bits >> i) & 1);
    for (int i = 8; i < 15; i++) setf(q, 8, s - 15 + i, (bits >> i) & 1);
    setf(q, 8, s - 8, 1);
}
static void function_patterns(struct qr *q, int v, int ecl) {
    int s = q->size;
    for (int i = 0; i < s; i++) { setf(q, 6, i, i % 2 == 0); setf(q, i, 6, i % 2 == 0); }
    finder(q, 3, 3); finder(q, s - 4, 3); finder(q, 3, s - 4);
    if (v > 1) {
        int n = v / 7 + 2, step = v == 32 ? 26 : (v * 4 + n * 2 + 1) / (n * 2 - 2) * 2, pos[7];
        pos[0] = 6;
        for (int i = n - 1, p = s - 7; i >= 1; i--, p -= step) pos[i] = p;
        for (int i = 0; i < n; i++) for (int j = 0; j < n; j++)
            if (!((i == 0 && j == 0) || (i == 0 && j == n - 1) || (i == n - 1 && j == 0))) alignment(q, pos[i], pos[j]);
    }
    format_bits(q, ecl, 0);
    if (v >= 7) {
        int rem = v;
        for (int i = 0; i < 12; i++) rem = (rem << 1) ^ ((rem >> 11) * 0x1F25);
        long bits = (long)v << 12 | rem;
        for (int i = 0; i < 18; i++) { int bit = (bits >> i) & 1, a = s - 11 + i % 3, b = i / 3; setf(q, a, b, bit); setf(q, b, a, bit); }
    }
}
static int masked(int mask, int x, int y) {
    switch (mask) {
    case 0: return (x + y) % 2 == 0;
    case 1: return y % 2 == 0;
    case 2: return x % 3 == 0;
    case 3: return (x + y) % 3 == 0;
    case 4: return (x / 3 + y / 2) % 2 == 0;
    case 5: return x * y % 2 + x * y % 3 == 0;
    case 6: return (x * y % 2 + x * y % 3) % 2 == 0;
    default: return ((x + y) % 2 + x * y % 3) % 2 == 0;
    }
}
static void apply_mask(struct qr *q, int mask) {
    for (int y = 0; y < q->size; y++) for (int x = 0; x < q->size; x++) if (!F(q, x, y) && masked(mask, x, y)) M(q, x, y) ^= 1;
}
/* the standard's penalty: runs, 2x2 blocks, finder-like patterns, dark balance */
static long penalty(struct qr *q) {
    long p = 0; int s = q->size;
    for (int pass = 0; pass < 2; pass++)
        for (int a = 0; a < s; a++) {
            int run = 1; uint32_t hist = 0;
            for (int b = 0; b < s; b++) {
                int c = pass ? M(q, a, b) : M(q, b, a);
                if (b > 0) { int pc = pass ? M(q, a, b - 1) : M(q, b - 1, a); if (c == pc) { run++; if (run == 5) p += 3; else if (run > 5) p++; } else run = 1; }
                hist = (hist << 1 | (uint32_t)c) & 0x7ff;
                if (b >= 10 && (hist == 0x5d || hist == 0x5d0)) p += 40;      /* 1011101 with 4 light on a side */
            }
        }
    for (int y = 0; y + 1 < s; y++) for (int x = 0; x + 1 < s; x++) {
        int c = M(q, x, y);
        if (c == M(q, x + 1, y) && c == M(q, x, y + 1) && c == M(q, x + 1, y + 1)) p += 3;
    }
    long dark = 0; for (int i = 0; i < s * s; i++) dark += q->m[i];
    long k = (labs(dark * 20 - (long)s * s * 10) + s * s - 1) / ((long)s * s) - 1;
    p += (k > 0 ? k : 0) * 10;
    return p;
}

/* encodes bytes; out gets size*size modules (1 = dark). Returns the size, or 0 if the message is too long. */
int isim_qr_encode(const uint8_t *msg, int len, int ecl, uint8_t *out) {
    if (ecl < 0 || ecl > 3 || len < 0) return 0;
    int v;
    for (v = 1; v <= 40; v++) if (4 + (v < 10 ? 8 : 16) + 8 * len <= data_codewords(v, ecl) * 8) break;
    if (v > 40) return 0;
    for (int e = 3; e > ecl; e--) if (4 + (v < 10 ? 8 : 16) + 8 * len <= data_codewords(v, e) * 8) { ecl = e; break; }   /* boost if it fits */
    int cap = data_codewords(v, ecl);
    uint8_t *data = calloc((size_t)cap, 1); long bit = 0;
    #define PUT(val, n) do { for (int i_ = (n) - 1; i_ >= 0; i_--) { if (((val) >> i_) & 1) data[bit >> 3] |= (uint8_t)(0x80 >> (bit & 7)); bit++; } } while (0)
    PUT(4, 4); PUT(len, v < 10 ? 8 : 16);
    for (int i = 0; i < len; i++) PUT(msg[i], 8);
    int term = cap * 8 - (int)bit; if (term > 4) term = 4; PUT(0, term);
    if (bit % 8) PUT(0, 8 - (int)(bit % 8));
    for (int pad = 0xEC; bit < cap * 8; pad ^= 0xEC ^ 0x11) PUT(pad, 8);
    #undef PUT
    /* blocks + error correction, interleaved */
    int nb = NUM_BLOCKS[ecl][v], ecc = ECC_PER_BLOCK[ecl][v], raw = raw_modules(v) / 8, nshort = nb - raw % nb, shortlen = raw / nb;
    uint8_t div[30]; rs_divisor(ecc, div);
    uint8_t *blocks = calloc((size_t)nb * (shortlen + 1), 1), *all = calloc((size_t)raw, 1);
    for (int i = 0, k = 0; i < nb; i++) {
        int dl = shortlen - ecc + (i < nshort ? 0 : 1);
        uint8_t *b = blocks + (size_t)i * (shortlen + 1);
        memcpy(b, data + k, (size_t)dl); k += dl;
        uint8_t rem[30]; rs_remainder(b, dl, div, ecc, rem);
        if (i < nshort) { memmove(b + dl + 1, b + dl, 0); memcpy(b + dl + 1, rem, (size_t)ecc); }   /* short blocks: a gap at dl */
        else memcpy(b + dl, rem, (size_t)ecc);
    }
    for (int i = 0, n = 0; i <= shortlen; i++)
        for (int j = 0; j < nb; j++)
            if (i != shortlen - ecc || j >= nshort) all[n++] = blocks[(size_t)j * (shortlen + 1) + i];
    free(blocks); free(data);
    /* modules */
    struct qr *q = calloc(1, sizeof *q);
    q->size = v * 4 + 17;
    function_patterns(q, v, ecl);
    long i = 0; int s = q->size;
    for (int right = s - 1; right >= 1; right -= 2) {
        if (right == 6) right = 5;
        for (int vert = 0; vert < s; vert++)
            for (int j = 0; j < 2; j++) {
                int x = right - j, up = ((right + 1) & 2) == 0, y = up ? s - 1 - vert : vert;
                if (!F(q, x, y) && i < (long)raw * 8) { M(q, x, y) = (all[i >> 3] >> (7 - (i & 7))) & 1; i++; }
            }
    }
    free(all);
    int best = 0; long bestp = -1;
    for (int mask = 0; mask < 8; mask++) {
        apply_mask(q, mask); format_bits(q, ecl, mask);
        long p = penalty(q);
        if (bestp < 0 || p < bestp) { bestp = p; best = mask; }
        apply_mask(q, mask);
    }
    apply_mask(q, best); format_bits(q, ecl, best);
    memcpy(out, q->m, (size_t)s * s);
    free(q);
    return s;
}
