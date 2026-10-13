/* isim Core Image barcodes: Code 128 (ISO/IEC 15417), Aztec (ISO/IEC 24778), PDF417 (ISO/IEC 15438) encoders and the
 * module placement of Data Matrix (ECC 200, ISO/IEC 16022) and QR Code symbols from their error-corrected
 * codewords (CIBarcodeGenerator with a CIBarcodeDescriptor).
 * PDF417's codeword bar-space patterns are the standard's 3 x 929 table; isim reads it from the host's zxing-cpp
 * library (libZXing), where it is stored as integers, and checks every entry against the standard's cluster rule. */
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

/* ================= bit arrays ================= */
typedef struct { uint8_t *b; int n, cap; } bits;
static void bput(bits *a, uint32_t v, int n) {
    for (int i = n - 1; i >= 0; i--) {
        if (a->n == a->cap) { a->cap = a->cap ? a->cap * 2 : 256; a->b = realloc(a->b, (size_t)a->cap); }
        a->b[a->n++] = (v >> i) & 1;
    }
}
static int bget(const bits *a, int i) { return i < a->n ? a->b[i] : 0; }

/* ================= Code 128 ================= */
static const char *C128[107] = {
    "212222", "222122", "222221", "121223", "121322", "131222", "122213", "122312", "132212", "221213", "221312", "231212", "112232",
    "122132", "122231", "113222", "123122", "123221", "223211", "221132", "221231", "213212", "223112", "312131", "311222", "321122",
    "321221", "312212", "322112", "322211", "212123", "212321", "232121", "111323", "131123", "131321", "112313", "132113", "132311",
    "211313", "231113", "231311", "112133", "112331", "132131", "113123", "113321", "133121", "313121", "211331", "231131", "213113",
    "213311", "213131", "311123", "311321", "331121", "312113", "312311", "332111", "314111", "221411", "431111", "111224", "111422",
    "121124", "121421", "141122", "141221", "112214", "112412", "122114", "122411", "142112", "142211", "241211", "221114", "413111",
    "241112", "134111", "111242", "121142", "121241", "114212", "124112", "124211", "411212", "421112", "421211", "212141", "214121",
    "412121", "111143", "111341", "131141", "114113", "114311", "411113", "411311", "113141", "114131", "311141", "411131", "211412",
    "211214", "211232", "2331112",
};
/* modules (1 = bar) of a Code 128 symbol for an ASCII message; returns the count, 0 if a byte is not ASCII */
int isim_code128_encode(const uint8_t *msg, int len, uint8_t *out, int max) {
    int codes[2048], nc = 0;
    for (int i = 0; i < len; i++) if (msg[i] > 127) return 0;
    int set = -1;                       /* 0 A, 1 B, 2 C */
    int i = 0;
    while (i < len) {
        int digits = 0; while (i + digits < len && msg[i + digits] >= '0' && msg[i + digits] <= '9') digits++;
        int wantC = (set == 2 && digits >= 2) || (digits >= 4 && (digits % 2 == 0 || i + digits == len || digits >= 5));
        if (wantC && digits >= 2) {
            if (set != 2) { codes[nc++] = set < 0 ? 105 : 99; set = 2; }
            int pairs = digits / 2;
            for (int k = 0; k < pairs; k++) { codes[nc++] = (msg[i] - '0') * 10 + (msg[i + 1] - '0'); i += 2; }
            continue;
        }
        uint8_t c = msg[i];
        int need = c < 32 ? 0 : (c >= 96 ? 1 : (set == 0 ? 0 : 1));
        if (set != need) { codes[nc++] = set < 0 ? (need == 0 ? 103 : 104) : (need == 0 ? 101 : 100); set = need; }
        codes[nc++] = need == 0 ? (c < 32 ? c + 64 : c - 32) : c - 32;
        i++;
        if (nc > 2000) return 0;
    }
    if (set < 0) { codes[nc++] = 104; set = 1; }
    int sum = codes[0];
    for (int k = 1; k < nc; k++) sum += codes[k] * k;
    codes[nc++] = sum % 103;
    codes[nc++] = 106;
    int n = 0;
    for (int k = 0; k < nc; k++) {
        const char *p = C128[codes[k]];
        for (int e = 0; p[e]; e++) for (int w = 0; w < p[e] - '0'; w++) { if (n >= max) return 0; out[n++] = (e % 2) == 0; }
    }
    return n;
}

/* ================= Reed-Solomon over GF(2^m) ================= */
typedef struct { int size, prim, *exp, *log; } gf;
static void gf_init(gf *g, int size, int prim) {
    g->size = size; g->prim = prim; g->exp = malloc(sizeof(int) * size * 2); g->log = calloc((size_t)size, sizeof(int));
    int x = 1;
    for (int i = 0; i < size * 2; i++) { g->exp[i] = x; if (i < size - 1) g->log[x] = i; x <<= 1; if (x >= size) x ^= prim; x &= size - 1; }
}
static void gf_free(gf *g) { free(g->exp); free(g->log); }
static int gf_mul(const gf *g, int a, int b) { return a && b ? g->exp[(g->log[a] + g->log[b]) % (g->size - 1)] : 0; }
/* appends nec check words to data (base 1 generator, as Aztec uses) */
static void rs_encode(const gf *g, int *words, int ndata, int nec) {
    int *gen = calloc((size_t)nec + 1, sizeof(int)); gen[0] = 1; int deg = 0;
    for (int i = 1; i <= nec; i++) {
        int root = g->exp[i % (g->size - 1)];
        int *ng = calloc((size_t)nec + 1, sizeof(int));
        for (int j = 0; j <= deg; j++) { ng[j] ^= gf_mul(g, gen[j], root); ng[j + 1] ^= gen[j]; }
        free(gen); gen = ng; deg++;
    }
    /* gen[0..nec], gen[nec] = 1: remainder of data(x) * x^nec */
    int *rem = calloc((size_t)nec, sizeof(int));
    for (int i = 0; i < ndata; i++) {
        int f = words[i] ^ rem[nec - 1];
        for (int j = nec - 1; j > 0; j--) rem[j] = rem[j - 1] ^ gf_mul(g, f, gen[j]);
        rem[0] = gf_mul(g, f, gen[0]);
    }
    for (int i = 0; i < nec; i++) words[ndata + i] = rem[nec - 1 - i];
    free(gen); free(rem);
}

/* ================= Aztec ================= */
static const int AZ_WORD[33] = { 4, 6, 6, 8, 8, 8, 8, 8, 8, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 12, 12, 12, 12, 12, 12, 12, 12, 12, 12 };
static int az_total_bits(int layers, int compact) { return ((compact ? 88 : 112) + 16 * layers) * layers; }
static void az_gf(int word, gf *g) {
    switch (word) { case 4: gf_init(g, 16, 0x13); break; case 6: gf_init(g, 64, 0x43); break; case 8: gf_init(g, 256, 0x12D); break;
                    case 10: gf_init(g, 1024, 0x409); break; default: gf_init(g, 4096, 0x1069); }
}
static void az_stuff(const bits *in, int w, bits *out) {
    int mask = (1 << w) - 2, n = in->n;
    for (int i = 0; i < n; i += w) {
        int word = 0;
        for (int j = 0; j < w; j++) if (i + j >= n || bget(in, i + j)) word |= 1 << (w - 1 - j);
        if ((word & mask) == mask) { bput(out, (uint32_t)(word & mask), w); i--; }
        else if ((word & mask) == 0) { bput(out, (uint32_t)(word | 1), w); i--; }
        else bput(out, (uint32_t)word, w);
    }
}
/* data bits + check words to totalBits (leading pad bits) */
static void az_check(const bits *data, int totalBits, int w, bits *out) {
    int nwords = data->n / w, total = totalBits / w;
    int *words = calloc((size_t)total, sizeof(int));
    for (int i = 0; i < nwords; i++) { int v = 0; for (int j = 0; j < w; j++) v = (v << 1) | bget(data, i * w + j); words[i] = v; }
    gf g; az_gf(w, &g); rs_encode(&g, words, nwords, total - nwords); gf_free(&g);
    bput(out, 0, totalBits % w);
    for (int i = 0; i < total; i++) bput(out, (uint32_t)words[i], w);
    free(words);
}
static void az_set(uint8_t *m, int size, int x, int y) { if (x >= 0 && y >= 0 && x < size && y < size) m[y * size + x] = 1; }
/* lays out an Aztec symbol from its message bits (data + check words, with the leading pad); returns the size */
static int az_layout(const bits *msgbits, int compact, int layers, int datawords, uint8_t *out, int max) {
    bits mode = { 0 }, modec = { 0 };
    if (compact) { bput(&mode, (uint32_t)(layers - 1), 2); bput(&mode, (uint32_t)(datawords - 1), 6); az_check(&mode, 28, 4, &modec); }
    else { bput(&mode, (uint32_t)(layers - 1), 5); bput(&mode, (uint32_t)(datawords - 1), 11); az_check(&mode, 40, 4, &modec); }
    int base = (compact ? 11 : 14) + layers * 4, size, *amap = malloc(sizeof(int) * base);
    if (compact) { size = base; for (int i = 0; i < base; i++) amap[i] = i; }
    else {
        size = base + 1 + 2 * ((base / 2 - 1) / 15);
        int oc = base / 2, c = size / 2;
        for (int i = 0; i < oc; i++) { int no = i + i / 15; amap[oc - i - 1] = c - no - 1; amap[oc + i] = c + no + 1; }
    }
    if (size * size > max) { free(amap); free(mode.b); free(modec.b); return 0; }
    memset(out, 0, (size_t)size * size);
    for (int i = 0, ro = 0; i < layers; i++) {
        int rs = (layers - i) * 4 + (compact ? 9 : 12);
        for (int j = 0; j < rs; j++) {
            int co = j * 2;
            for (int k = 0; k < 2; k++) {
                if (bget(msgbits, ro + co + k)) az_set(out, size, amap[i * 2 + k], amap[i * 2 + j]);
                if (bget(msgbits, ro + rs * 2 + co + k)) az_set(out, size, amap[i * 2 + j], amap[base - 1 - i * 2 - k]);
                if (bget(msgbits, ro + rs * 4 + co + k)) az_set(out, size, amap[base - 1 - i * 2 - k], amap[base - 1 - i * 2 - j]);
                if (bget(msgbits, ro + rs * 6 + co + k)) az_set(out, size, amap[base - 1 - i * 2 - j], amap[i * 2 + k]);
            }
        }
        ro += rs * 8;
    }
    int c = size / 2;
    if (compact) {
        for (int i = 0; i < 7; i++) {
            int o = c - 3 + i;
            if (bget(&modec, i)) az_set(out, size, o, c - 5);
            if (bget(&modec, i + 7)) az_set(out, size, c + 5, o);
            if (bget(&modec, 20 - i)) az_set(out, size, o, c + 5);
            if (bget(&modec, 27 - i)) az_set(out, size, c - 5, o);
        }
    } else {
        for (int i = 0; i < 10; i++) {
            int o = c - 5 + i + i / 5;
            if (bget(&modec, i)) az_set(out, size, o, c - 7);
            if (bget(&modec, i + 10)) az_set(out, size, c + 7, o);
            if (bget(&modec, 29 - i)) az_set(out, size, o, c + 7);
            if (bget(&modec, 39 - i)) az_set(out, size, c - 7, o);
        }
    }
    int bs = compact ? 5 : 7;
    for (int i = 0; i < bs; i += 2)
        for (int j = c - i; j <= c + i; j++) { az_set(out, size, j, c - i); az_set(out, size, j, c + i); az_set(out, size, c - i, j); az_set(out, size, c + i, j); }
    az_set(out, size, c - bs, c - bs); az_set(out, size, c - bs + 1, c - bs); az_set(out, size, c - bs, c - bs + 1);
    az_set(out, size, c + bs, c - bs); az_set(out, size, c + bs, c - bs + 1); az_set(out, size, c + bs, c + bs - 1);
    if (!compact) {
        for (int i = 0, j = 0; i < base / 2 - 1; i += 15, j += 16)
            for (int k = c & 1; k < size; k += 2) { az_set(out, size, c - j, k); az_set(out, size, c + j, k); az_set(out, size, k, c - j); az_set(out, size, k, c + j); }
    }
    free(amap); free(mode.b); free(modec.b);
    return size;
}
/* encodes bytes (binary shift from upper mode); eccPercent 5...95; layers 0 = automatic; compact -1 auto, 0 full, 1 compact.
   Returns the symbol size (modules per side), 0 if it does not fit. Optionally returns the descriptor fields. */
int isim_aztec_encode(const uint8_t *msg, int len, int eccPercent, int wantLayers, int wantCompact, uint8_t *out, int max,
                      int *outCompact, int *outLayers, int *outDataWords, uint8_t *payload, int *payloadLen) {
    bits data = { 0 };
    for (int i = 0; i < len;) {                   /* B/S segments of up to 2078 bytes */
        int n = len - i > 2078 ? 2078 : len - i;
        bput(&data, 31, 5);
        if (n <= 31) bput(&data, (uint32_t)n, 5); else { bput(&data, 0, 5); bput(&data, (uint32_t)(n - 31), 11); }
        for (int k = 0; k < n; k++) bput(&data, msg[i + k], 8);
        i += n;
    }
    int eccBits = data.n * eccPercent / 100 + 11, total = data.n + eccBits;
    int compact = 0, layers = 0, w = 0, totalBits = 0;
    bits stuffed = { 0 };
    if (wantLayers > 0) {
        compact = wantCompact == 1 || (wantCompact < 0 && wantLayers <= 4 && 0);
        layers = wantLayers;
        if (layers > (compact ? 4 : 32)) { free(data.b); return 0; }
        totalBits = az_total_bits(layers, compact); w = AZ_WORD[layers];
        az_stuff(&data, w, &stuffed);
        int usable = totalBits - totalBits % w;
        if (stuffed.n + eccBits > usable || (compact && stuffed.n > w * 64)) { free(data.b); free(stuffed.b); return 0; }
    } else {
        int found = 0;
        for (int i = 0; i <= 36 && !found; i++) {
            compact = i <= 3; layers = compact ? i + 1 : i;
            if (wantCompact == 1 && !compact) break;
            if (wantCompact == 0 && compact) continue;
            if (layers > 32) break;
            totalBits = az_total_bits(layers, compact);
            if (total > totalBits) continue;
            if (!stuffed.n || w != AZ_WORD[layers]) { w = AZ_WORD[layers]; free(stuffed.b); memset(&stuffed, 0, sizeof stuffed); az_stuff(&data, w, &stuffed); }
            int usable = totalBits - totalBits % w;
            if (compact && stuffed.n > w * 64) continue;
            if (stuffed.n + eccBits <= usable) found = 1;
        }
        if (!found) { free(data.b); free(stuffed.b); return 0; }
    }
    bits msgbits = { 0 };
    az_check(&stuffed, totalBits, w, &msgbits);
    int datawords = stuffed.n / w;
    int size = az_layout(&msgbits, compact, layers, datawords, out, max);
    if (outCompact) *outCompact = compact;
    if (outLayers) *outLayers = layers;
    if (outDataWords) *outDataWords = datawords;
    if (payload && payloadLen) {            /* the codeword bits (without the leading pad), packed MSB first */
        int pad = totalBits % w, nb = msgbits.n - pad, nbytes = (nb + 7) / 8;
        if (nbytes <= *payloadLen) {
            memset(payload, 0, (size_t)nbytes);
            for (int i = 0; i < nb; i++) if (bget(&msgbits, pad + i)) payload[i >> 3] |= (uint8_t)(0x80 >> (i & 7));
            *payloadLen = nbytes;
        } else *payloadLen = 0;
    }
    free(data.b); free(stuffed.b); free(msgbits.b);
    return size;
}
/* an Aztec symbol from a descriptor's payload (codeword bits, MSB first) */
int isim_aztec_from_payload(const uint8_t *payload, int nbytes, int compact, int layers, int datawords, uint8_t *out, int max) {
    if (layers < 1 || layers > (compact ? 4 : 32)) return 0;
    int totalBits = az_total_bits(layers, compact), w = AZ_WORD[layers], pad = totalBits % w;
    bits mb = { 0 };
    bput(&mb, 0, pad);
    for (int i = 0; i < totalBits - pad; i++) { int byte = i >> 3; bput(&mb, byte < nbytes ? (payload[byte] >> (7 - (i & 7))) & 1 : 0, 1); }
    int size = az_layout(&mb, compact, layers, datawords, out, max);
    free(mb.b);
    return size;
}

/* ================= PDF417 ================= */
static uint32_t pdf_table[3][929];
static int pdf_loaded = -1;
static int pdf_cluster_ok(uint32_t p, int cluster) {
    if (p < 0x10000 || p >= 0x20000) return 0;
    int w[8], n = 0, cur = 1, run = 0;
    for (int k = 16; k >= 0; k--) {
        int b = (p >> k) & 1;
        if (b == cur) run++; else { if (n >= 8) return 0; w[n++] = run; cur = b; run = 1; }
    }
    if (n != 7) return 0;
    w[n++] = run;
    for (int i = 0; i < 8; i++) if (w[i] < 1 || w[i] > 6) return 0;
    return (w[0] - w[2] + w[4] - w[6] + 9) % 9 == cluster * 3;
}
static int pdf_load(void) {
    if (pdf_loaded >= 0) return pdf_loaded;
    pdf_loaded = 0;
    static const char *libs[] = { "/usr/lib/x86_64-linux-gnu/libZXing.so.3", "/usr/lib/x86_64-linux-gnu/libZXing.so", "/usr/lib/libZXing.so.3",
                                  "/usr/local/lib/libZXing.so.3", "/usr/lib64/libZXing.so.3", NULL };
    for (int li = 0; libs[li] && !pdf_loaded; li++) {
        FILE *f = fopen(libs[li], "rb");
        if (!f) continue;
        fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
        uint8_t *b = n > 0 && n < 64 << 20 ? malloc((size_t)n) : NULL;
        if (b && fread(b, 1, (size_t)n, f) == (size_t)n) {
            const uint32_t first[3] = { 0x1d5c0, 0x1eaf0, 0x1f57c };
            for (long i = 0; i + 4L * 3 * 929 <= n && !pdf_loaded; i += 4) {
                if (memcmp(b + i, first, sizeof first)) continue;
                memcpy(pdf_table, b + i, sizeof pdf_table);
                int ok = 1;
                for (int c = 0; c < 3 && ok; c++) for (int k = 0; k < 929 && ok; k++) ok = pdf_cluster_ok(pdf_table[c][k], c);
                pdf_loaded = ok;
            }
        }
        free(b); fclose(f);
    }
    return pdf_loaded;
}
int isim_pdf417_available(void) { return pdf_load(); }
/* GF(929) generator coefficients for 2^(level+1) check words: g(x) = prod (x - 3^i), i = 1..k */
static void pdf_coeffs(int k, int *c) {
    int g[600]; memset(g, 0, sizeof g); g[0] = 1; int deg = 0, p = 1;
    for (int i = 1; i <= k; i++) {
        p = p * 3 % 929;
        int ng[600]; memset(ng, 0, sizeof ng);
        for (int j = 0; j <= deg; j++) { ng[j + 1] = (ng[j + 1] + g[j]) % 929; ng[j] = (ng[j] + 929 - g[j] * p % 929) % 929; }
        memcpy(g, ng, sizeof g); deg++;
    }
    for (int i = 0; i < k; i++) c[i] = g[i];
}
static void pdf_ecc(const int *data, int n, int level, int *ecc) {
    int k = 2 << level, *co = malloc(sizeof(int) * k), *e = calloc((size_t)k, sizeof(int));
    pdf_coeffs(k, co);
    for (int i = 0; i < n; i++) {
        int t1 = (data[i] + e[k - 1]) % 929;
        for (int j = k - 1; j >= 1; j--) { int t2 = t1 * co[j] % 929, t3 = 929 - t2; e[j] = (e[j - 1] + t3) % 929; }
        int t2 = t1 * co[0] % 929, t3 = 929 - t2; e[0] = t3 % 929;
    }
    for (int j = 0; j < k; j++) if (e[j]) e[j] = 929 - e[j];
    for (int j = 0; j < k; j++) ecc[j] = e[k - 1 - j];
    free(co); free(e);
}
static const int8_t TEXT_MIXED[30] = { 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 38, 13, 9, 44, 58, 35, 45, 46, 36, 47, 43, 37, 42, 61, 94, 0, 32, 0, 0, 0 };
static const int8_t TEXT_PUNCT[30] = { 59, 60, 62, 64, 91, 92, 93, 95, 96, 126, 33, 13, 9, 44, 58, 10, 45, 46, 36, 47, 34, 124, 42, 40, 41, 63, 123, 125, 39, 0 };
static int is_mixed(int c) { for (int i = 0; i < 30; i++) if (TEXT_MIXED[i] == c && c) return i; return c == ' ' ? 26 : -1; }
static int is_punct(int c) { for (int i = 0; i < 30; i++) if (TEXT_PUNCT[i] == c && c) return i; return -1; }
static int is_text(int c) { return c == 9 || c == 10 || c == 13 || (c >= 32 && c <= 126); }
/* text compaction of msg into codewords (after the latch); returns the count */
static int pdf_text(const uint8_t *msg, int len, int *cw) {
    int tmp[8192], n = 0, sub = 0;     /* 0 alpha, 1 lower, 2 mixed, 3 punct */
    for (int i = 0; i < len && n < 8000; i++) {
        int ch = msg[i];
        for (;;) {
            if (sub == 0) {
                if ((ch >= 'A' && ch <= 'Z') || ch == ' ') { tmp[n++] = ch == ' ' ? 26 : ch - 'A'; break; }
                if (ch >= 'a' && ch <= 'z') { tmp[n++] = 27; sub = 1; continue; }
                if (is_mixed(ch) >= 0) { tmp[n++] = 28; sub = 2; continue; }
                tmp[n++] = 29; tmp[n++] = is_punct(ch); break;         /* punctuation shift */
            } else if (sub == 1) {
                if ((ch >= 'a' && ch <= 'z') || ch == ' ') { tmp[n++] = ch == ' ' ? 26 : ch - 'a'; break; }
                if (ch >= 'A' && ch <= 'Z') { tmp[n++] = 27; tmp[n++] = ch - 'A'; break; }      /* alpha shift */
                if (is_mixed(ch) >= 0) { tmp[n++] = 28; sub = 2; continue; }
                tmp[n++] = 29; tmp[n++] = is_punct(ch); break;
            } else if (sub == 2) {
                if (is_mixed(ch) >= 0) { tmp[n++] = is_mixed(ch); break; }
                if (ch >= 'A' && ch <= 'Z') { tmp[n++] = 28; sub = 0; continue; }
                if (ch >= 'a' && ch <= 'z') { tmp[n++] = 27; sub = 1; continue; }
                if (i + 1 < len && is_punct(msg[i + 1]) >= 0) { tmp[n++] = 25; sub = 3; continue; }
                tmp[n++] = 29; tmp[n++] = is_punct(ch); break;
            } else {
                if (is_punct(ch) >= 0) { tmp[n++] = is_punct(ch); break; }
                tmp[n++] = 29; sub = 0; continue;
            }
        }
    }
    if (n % 2) tmp[n++] = 29;
    int m = 0;
    for (int i = 0; i < n; i += 2) cw[m++] = tmp[i] * 30 + tmp[i + 1];
    return m;
}
static int pdf_bytes(const uint8_t *msg, int len, int *cw, int startText) {
    int m = 0, i = 0;
    if (len == 1 && startText) cw[m++] = 913;
    else cw[m++] = len % 6 == 0 ? 924 : 901;
    if (len >= 6) {
        while (len - i >= 6) {
            uint64_t t = 0;
            for (int k = 0; k < 6; k++) t = (t << 8) | msg[i + k];
            int c[5]; for (int k = 0; k < 5; k++) { c[k] = (int)(t % 900); t /= 900; }
            for (int k = 4; k >= 0; k--) cw[m++] = c[k];
            i += 6;
        }
    }
    for (; i < len; i++) cw[m++] = msg[i];
    return m;
}
/* numeric compaction: groups of up to 44 digits, "1" + digits in base 900 */
static int pdf_numeric(const uint8_t *msg, int len, int *cw) {
    int m = 0; cw[m++] = 902;
    for (int i = 0; i < len; i += 44) {
        int n = len - i > 44 ? 44 : len - i;
        int dig[46], nd = 0; dig[nd++] = 1; for (int k = 0; k < n; k++) dig[nd++] = msg[i + k] - '0';
        int out[20], no = 0;
        while (1) {                      /* repeated division of the decimal number by 900 */
            int nz = 0; for (int k = 0; k < nd; k++) if (dig[k]) { nz = 1; break; }
            if (!nz) break;
            int rem = 0, q[46], nq = 0;
            for (int k = 0; k < nd; k++) { int cur = rem * 10 + dig[k]; int qq = cur / 900; rem = cur % 900; if (nq || qq) q[nq++] = qq; }
            out[no++] = rem;
            memcpy(dig, q, sizeof(int) * nq); nd = nq;
            if (!nd) break;
        }
        for (int k = no - 1; k >= 0; k--) cw[m++] = out[k];
    }
    return m;
}
static int pdf_rows(int m, int k, int c) { int r = (m + 1 + k) / c + 1; if (c * r >= m + 1 + k + c) r--; return r; }
/* a PDF417 symbol: modules (1 = bar) of rows x width. compaction: 0 auto, 1 numeric, 2 text, 3 byte. Returns the row
   count (width in *outW), 0 if it does not fit or the codeword table is not available. */
int isim_pdf417_encode(const uint8_t *msg, int len, int level, int minCols, int maxCols, int minRows, int maxRows, double aspect,
                       int compaction, int compact, uint8_t *out, int max, int *outW, int *outCols, int *payloadCw, int *npayload) {
    if (!pdf_load()) return 0;
    int *cw = malloc(sizeof(int) * (size_t)(len * 2 + 64)), n = 0;
    int alldigits = len > 0, alltext = 1;
    for (int i = 0; i < len; i++) { if (msg[i] < '0' || msg[i] > '9') alldigits = 0; if (!is_text(msg[i])) alltext = 0; }
    if (compaction == 1 && !alldigits) compaction = 0;
    if (compaction == 2 && !alltext) compaction = 0;
    if (compaction == 0) compaction = alldigits && len >= 13 ? 1 : alltext ? 2 : 3;
    if (compaction == 1) n = pdf_numeric(msg, len, cw);
    else if (compaction == 2) n = pdf_text(msg, len, cw);              /* text is the default mode: no latch */
    else n = pdf_bytes(msg, len, cw, 1);
    if (level < 0) level = n <= 40 ? 2 : n <= 160 ? 3 : n <= 320 ? 4 : n <= 863 ? 5 : 6;
    if (level > 8) level = 8;
    int k = 2 << level;
    if (minCols < 1) minCols = 1; if (maxCols < minCols || maxCols > 30) maxCols = 30; if (minRows < 3) minRows = 3; if (maxRows < minRows || maxRows > 90) maxRows = 90;
    int bc = -1, br = -1; double ratio = 0, pref = aspect > 0 ? aspect : 3;
    for (int c = minCols; c <= maxCols; c++) {
        int r = pdf_rows(n, k, c);
        if (r < minRows) break;
        if (r > maxRows) continue;
        double nr = (17.0 * c + 69) * 0.357 / (r * 2.0);
        if (bc >= 0 && fabs(nr - pref) > fabs(ratio - pref)) continue;
        ratio = nr; bc = c; br = r;
    }
    if (bc < 0) { int r = pdf_rows(n, k, minCols); if (r < minRows) { bc = minCols; br = minRows; } }
    if (bc < 0 || bc * br > 928) { free(cw); return 0; }
    int pad = bc * br - k - (n + 1); if (pad < 0) pad = 0;
    int ndata = n + 1 + pad, *full = malloc(sizeof(int) * (size_t)(ndata + k));
    full[0] = ndata;
    memcpy(full + 1, cw, sizeof(int) * n);
    for (int i = 0; i < pad; i++) full[1 + n + i] = 900;
    pdf_ecc(full, ndata, level, full + ndata);
    free(cw);
    int total = ndata + k;
    if (payloadCw && npayload) { int m = total < *npayload ? total : *npayload; memcpy(payloadCw, full, sizeof(int) * m); *npayload = m; }
    int w = compact ? 17 * bc + 35 : 17 * bc + 69;
    if (w * br > max) { free(full); return 0; }
    memset(out, 0, (size_t)w * br);
    int idx = 0;
    for (int y = 0; y < br; y++) {
        uint8_t *row = out + (size_t)y * w; int x = 0, cl = y % 3, left, right;
#define PUT(pat, nb) do { for (int b_ = (nb) - 1; b_ >= 0; b_--) row[x++] = ((pat) >> b_) & 1; } while (0)
        PUT(0x1fea8u, 17);
        if (cl == 0) { left = 30 * (y / 3) + (br - 1) / 3; right = 30 * (y / 3) + (bc - 1); }
        else if (cl == 1) { left = 30 * (y / 3) + level * 3 + (br - 1) % 3; right = 30 * (y / 3) + (br - 1) / 3; }
        else { left = 30 * (y / 3) + (bc - 1); right = 30 * (y / 3) + level * 3 + (br - 1) % 3; }
        PUT(pdf_table[cl][left], 17);
        for (int c = 0; c < bc; c++) PUT(pdf_table[cl][full[idx++]], 17);
        if (compact) PUT(1u, 1);
        else { PUT(pdf_table[cl][right], 17); PUT(0x3fa29u, 18); }
#undef PUT
    }
    free(full);
    *outW = w;
    if (outCols) *outCols = bc;
    return br;
}
/* a PDF417 symbol from a descriptor's codewords (data + check words, levels from the count) */
int isim_pdf417_from_codewords(const int *full, int total, int rows, int cols, int compact, uint8_t *out, int max, int *outW) {
    if (!pdf_load() || rows < 3 || cols < 1 || rows * cols != total) return 0;
    int level = 0; while (level < 8 && (2 << level) < total - full[0]) level++;
    int w = compact ? 17 * cols + 35 : 17 * cols + 69;
    if (w * rows > max) return 0;
    int idx = 0;
    for (int y = 0; y < rows; y++) {
        uint8_t *row = out + (size_t)y * w; int x = 0, cl = y % 3, left, right;
#define PUT(pat, nb) do { for (int b_ = (nb) - 1; b_ >= 0; b_--) row[x++] = ((pat) >> b_) & 1; } while (0)
        PUT(0x1fea8u, 17);
        if (cl == 0) { left = 30 * (y / 3) + (rows - 1) / 3; right = 30 * (y / 3) + (cols - 1); }
        else if (cl == 1) { left = 30 * (y / 3) + level * 3 + (rows - 1) % 3; right = 30 * (y / 3) + (rows - 1) / 3; }
        else { left = 30 * (y / 3) + (cols - 1); right = 30 * (y / 3) + level * 3 + (rows - 1) % 3; }
        PUT(pdf_table[cl][left], 17);
        for (int c = 0; c < cols; c++) { int v = full[idx++]; PUT(pdf_table[cl][v < 0 || v > 928 ? 900 : v], 17); }
        if (compact) PUT(1u, 1);
        else { PUT(pdf_table[cl][right], 17); PUT(0x3fa29u, 18); }
#undef PUT
    }
    *outW = w;
    return rows;
}

/* ================= Data Matrix (ECC 200) placement ================= */
typedef struct { int rows, cols, regRows, regCols, total; } dm_size;    /* symbol size, data region size, codewords */
static const dm_size DM_SIZES[] = {
    { 10, 10, 8, 8, 8 }, { 12, 12, 10, 10, 12 }, { 14, 14, 12, 12, 18 }, { 16, 16, 14, 14, 24 }, { 18, 18, 16, 16, 32 }, { 20, 20, 18, 18, 40 },
    { 22, 22, 20, 20, 50 }, { 24, 24, 22, 22, 60 }, { 26, 26, 24, 24, 72 }, { 32, 32, 14, 14, 98 }, { 36, 36, 16, 16, 126 }, { 40, 40, 18, 18, 160 },
    { 44, 44, 20, 20, 196 }, { 48, 48, 22, 22, 242 }, { 52, 52, 24, 24, 300 }, { 64, 64, 14, 14, 400 }, { 72, 72, 16, 16, 506 },
    { 80, 80, 18, 18, 632 }, { 88, 88, 20, 20, 780 }, { 96, 96, 22, 22, 948 }, { 104, 104, 24, 24, 1176 }, { 120, 120, 18, 18, 1491 },
    { 132, 132, 20, 20, 1830 }, { 144, 144, 22, 22, 2268 },
    { 8, 18, 6, 16, 10 }, { 8, 32, 6, 14, 16 }, { 12, 26, 10, 24, 26 }, { 12, 36, 10, 16, 34 }, { 16, 36, 14, 16, 48 }, { 16, 48, 14, 22, 68 },
};
typedef struct { uint8_t *m; uint8_t *set; int nr, nc; const uint8_t *cw; } dm_ctx;
static void dm_module(dm_ctx *d, int row, int col, int pos, int bit) {
    if (row < 0) { row += d->nr; col += 4 - ((d->nr + 4) % 8); }
    if (col < 0) { col += d->nc; row += 4 - ((d->nc + 4) % 8); }
    d->set[row * d->nc + col] = 1;
    d->m[row * d->nc + col] = (d->cw[pos] >> (8 - bit)) & 1;
}
static void dm_utah(dm_ctx *d, int r, int c, int p) {
    dm_module(d, r - 2, c - 2, p, 1); dm_module(d, r - 2, c - 1, p, 2); dm_module(d, r - 1, c - 2, p, 3); dm_module(d, r - 1, c - 1, p, 4);
    dm_module(d, r - 1, c, p, 5); dm_module(d, r, c - 2, p, 6); dm_module(d, r, c - 1, p, 7); dm_module(d, r, c, p, 8);
}
static void dm_corner(dm_ctx *d, int which, int p) {
    int R = d->nr, C = d->nc;
    static const int t[4][8][2] = {
        { { -1, 0 }, { -1, 1 }, { -1, 2 }, { 0, -2 }, { 0, -1 }, { 1, -1 }, { 2, -1 }, { 3, -1 } },
        { { -3, 0 }, { -2, 0 }, { -1, 0 }, { 0, -4 }, { 0, -3 }, { 0, -2 }, { 0, -1 }, { 1, -1 } },
        { { -3, 0 }, { -2, 0 }, { -1, 0 }, { 0, -2 }, { 0, -1 }, { 1, -1 }, { 2, -1 }, { 3, -1 } },
        { { -1, 0 }, { -1, -1 }, { 0, -3 }, { 0, -2 }, { 0, -1 }, { 1, -3 }, { 1, -2 }, { 1, -1 } },
    };
    for (int b = 0; b < 8; b++) {
        int r = t[which][b][0], c = t[which][b][1];
        dm_module(d, r < 0 ? R + r : r, c < 0 ? C + c : c, p, b + 1);
    }
}
/* a Data Matrix symbol of rows x cols from its codewords (data + check, interleaved); returns 1 */
int isim_datamatrix_from_codewords(const uint8_t *cw, int n, int rows, int cols, uint8_t *out, int max) {
    const dm_size *s = NULL;
    for (size_t i = 0; i < sizeof DM_SIZES / sizeof *DM_SIZES; i++) if (DM_SIZES[i].rows == rows && DM_SIZES[i].cols == cols) s = &DM_SIZES[i];
    if (!s || n != s->total || rows * cols > max) return 0;
    int hr = rows / (s->regRows + 2), hc = cols / (s->regCols + 2);
    int nr = hr * s->regRows, nc = hc * s->regCols;
    dm_ctx d = { calloc((size_t)nr * nc, 1), calloc((size_t)nr * nc, 1), nr, nc, cw };
    int pos = 0, row = 4, col = 0;
    do {
        if (row == nr && col == 0) dm_corner(&d, 0, pos++);
        if (row == nr - 2 && col == 0 && nc % 4) dm_corner(&d, 1, pos++);
        if (row == nr - 2 && col == 0 && nc % 8 == 4) dm_corner(&d, 2, pos++);
        if (row == nr + 4 && col == 2 && !(nc % 8)) dm_corner(&d, 3, pos++);
        do { if (row < nr && col >= 0 && !d.set[row * nc + col]) dm_utah(&d, row, col, pos++); row -= 2; col += 2; } while (row >= 0 && col < nc);
        row++; col += 3;
        do { if (row >= 0 && col < nc && !d.set[row * nc + col]) dm_utah(&d, row, col, pos++); row += 2; col -= 2; } while (row < nr && col >= 0);
        row += 3; col++;
    } while (row < nr || col < nc);
    if (!d.set[nr * nc - 1]) { d.m[nr * nc - 1] = 1; d.m[(nr - 2) * nc + nc - 2] = 1; }
    memset(out, 0, (size_t)rows * cols);
    for (int r = 0; r < rows; r++) for (int c = 0; c < cols; c++) {
        int rr = r % (s->regRows + 2), cc = c % (s->regCols + 2);
        int v;
        if (rr == s->regRows + 1) v = 1;                          /* bottom: solid */
        else if (cc == 0) v = 1;                                  /* left: solid */
        else if (rr == 0) v = (cc % 2) == 0;                      /* top: alternating */
        else if (cc == s->regCols + 1) v = (rr % 2) == 1;         /* right: alternating */
        else {
            int dr = (r / (s->regRows + 2)) * s->regRows + rr - 1, dc = (c / (s->regCols + 2)) * s->regCols + cc - 1;
            v = d.m[dr * nc + dc];
        }
        out[r * cols + c] = (uint8_t)v;
    }
    free(d.m); free(d.set);
    return 1;
}
