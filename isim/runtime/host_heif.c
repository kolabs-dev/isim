/* libisim_host HEIF (HEIC) images: isim writes and reads the ISO/IEC 23008-12 container itself and leaves the HEVC
 * coding to the host's ffmpeg (libx265 to encode, ffmpeg's own decoder to decode).
 *
 * Encoding (isim_heif_encode_bgra): ffmpeg codes the picture as one HEVC frame into a temporary MP4; isim takes the
 * decoder configuration (hvcC) and the coded sample out of it and builds a still-image HEIF around them: ftyp heic,
 * meta (hdlr pict, pitm, iinf with one hvc1 item, iloc, iprp with hvcC / ispe / colr nclx) and mdat. Without ffmpeg's
 * libx265 there is no HEIC encoder (isim_heif_can_encode is 0).
 *
 * Decoding (isim_heif_decode): the primary item is an hvc1 image or a grid of hvc1 tiles (what iPhones write); the
 * tiles become one Annex B stream that ffmpeg decodes to RGBA; isim composes the grid, crops it to the output size and
 * applies irot / imir. Thumbnails, alpha and depth auxiliary images and Exif are not read. */
#define _GNU_SOURCE
#include "guest_abi.h"
#include <errno.h>
#include <fcntl.h>
#include <spawn.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

extern char **environ;

/* ---------- helpers ---------- */
struct buf { unsigned char *d; size_t n, cap; };
static void put(struct buf *b, const void *p, size_t n) {
    if (b->n + n > b->cap) { b->cap = (b->n + n) * 2 + 256; b->d = realloc(b->d, b->cap); }
    memcpy(b->d + b->n, p, n); b->n += n;
}
static void put8(struct buf *b, unsigned v) { unsigned char c = (unsigned char)v; put(b, &c, 1); }
static void put16(struct buf *b, unsigned v) { put8(b, v >> 8); put8(b, v); }
static void put32(struct buf *b, uint32_t v) { put16(b, v >> 16); put16(b, v & 0xffff); }
static void put4cc(struct buf *b, const char *t) { put(b, t, 4); }
static size_t open_box(struct buf *b, const char *type) { size_t at = b->n; put32(b, 0); put4cc(b, type); return at; }
static size_t open_full(struct buf *b, const char *type, unsigned version, unsigned flags) {
    size_t at = open_box(b, type); put32(b, (uint32_t)version << 24 | (flags & 0xffffff)); return at;
}
static void close_box(struct buf *b, size_t at) {
    uint32_t n = (uint32_t)(b->n - at);
    b->d[at] = n >> 24; b->d[at + 1] = n >> 16; b->d[at + 2] = n >> 8; b->d[at + 3] = n;
}
static uint32_t rd16(const unsigned char *p) { return (uint32_t)p[0] << 8 | p[1]; }
static uint32_t rd32(const unsigned char *p) { return (uint32_t)p[0] << 24 | (uint32_t)p[1] << 16 | (uint32_t)p[2] << 8 | p[3]; }
static uint64_t rdn(const unsigned char *p, int n) { uint64_t v = 0; for (int i = 0; i < n; i++) v = v << 8 | p[i]; return v; }

static int run(char *const argv[]) {
    posix_spawn_file_actions_t fa;
    posix_spawn_file_actions_init(&fa);
    posix_spawn_file_actions_addopen(&fa, 0, "/dev/null", O_RDONLY, 0);
    posix_spawn_file_actions_addopen(&fa, 1, "/dev/null", O_WRONLY, 0);
    posix_spawn_file_actions_addopen(&fa, 2, "/dev/null", O_WRONLY, 0);
    pid_t pid;
    int ok = posix_spawnp(&pid, argv[0], &fa, NULL, argv, environ) == 0;
    posix_spawn_file_actions_destroy(&fa);
    if (!ok) return -1;
    int st;
    while (waitpid(pid, &st, 0) < 0) if (errno != EINTR) return -1;
    return WIFEXITED(st) ? WEXITSTATUS(st) : -1;
}
static unsigned char *slurp(const char *path, size_t *len) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); long n = ftell(f); fseek(f, 0, SEEK_SET);
    unsigned char *d = n > 0 ? malloc((size_t)n) : NULL;
    if (d && fread(d, 1, (size_t)n, f) != (size_t)n) { free(d); d = NULL; }
    fclose(f);
    *len = d ? (size_t)n : 0;
    return d;
}
static int spill(const char *path, const void *d, size_t n) {
    FILE *f = fopen(path, "wb");
    if (!f) return 0;
    int ok = fwrite(d, 1, n, f) == n;
    return fclose(f) == 0 && ok;
}
static void tmpname(char *out, size_t len, const char *ext) {
    const char *t = getenv("TMPDIR"); if (!t || !*t) t = "/tmp";
    static int seq;
    snprintf(out, len, "%s/isim-heif-%d-%d%s", t, (int)getpid(), __sync_add_and_fetch(&seq, 1), ext);
}

/* ---------- boxes ---------- */
struct box { const unsigned char *p; size_t n; char type[5]; };   /* p: the payload (after the header) */
static int box_at(const unsigned char *d, size_t len, size_t *off, struct box *b) {
    if (*off + 8 > len) return 0;
    const unsigned char *h = d + *off;
    uint64_t size = rd32(h); size_t hdr = 8;
    if (size == 1) { if (*off + 16 > len) return 0; size = rdn(h + 8, 8); hdr = 16; }
    else if (size == 0) size = len - *off;
    if (size < hdr || *off + size > len) return 0;
    memcpy(b->type, h + 4, 4); b->type[4] = 0;
    b->p = h + hdr; b->n = (size_t)size - hdr;
    *off += (size_t)size;
    return 1;
}
/* the first child box of `type` in a payload (skip: bytes before the children) */
static int child(const unsigned char *p, size_t n, size_t skip, const char *type, struct box *out) {
    size_t off = skip; struct box b;
    while (box_at(p, n, &off, &b)) if (!memcmp(b.type, type, 4)) { *out = b; return 1; }
    return 0;
}

/* ---------- encoding ---------- */
static int can_encode = -1;
ISIM_GUEST_ABI int isim_heif_can_encode(void) {
    if (can_encode >= 0) return can_encode;
    char out[256]; tmpname(out, sizeof out, ".txt");
    /* an 2x2 frame through libx265: proves both ffmpeg and the encoder are there */
    char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "lavfi", "-i", "color=c=gray:s=16x16:d=0.04", "-frames:v", "1",
                     "-c:v", "libx265", "-x265-params", "log-level=none", "-f", "hevc", out, NULL };
    can_encode = run(argv) == 0;
    unlink(out);
    return can_encode;
}

/* hvcC payload and the first sample of the first track of an MP4 written by ffmpeg */
static int mp4_hevc(const unsigned char *d, size_t len, const unsigned char **hvcc, size_t *hvcc_n, const unsigned char **sample, size_t *sample_n) {
    struct box moov, trak, mdia, minf, stbl, stsd, entry, cfg, stsz, stco;
    if (!child(d, len, 0, "moov", &moov) || !child(moov.p, moov.n, 0, "trak", &trak) || !child(trak.p, trak.n, 0, "mdia", &mdia) ||
        !child(mdia.p, mdia.n, 0, "minf", &minf) || !child(minf.p, minf.n, 0, "stbl", &stbl) || !child(stbl.p, stbl.n, 0, "stsd", &stsd))
        return 0;
    if (!child(stsd.p, stsd.n, 8, "hvc1", &entry) && !child(stsd.p, stsd.n, 8, "hev1", &entry)) return 0;
    if (!child(entry.p, entry.n, 78, "hvcC", &cfg)) return 0;
    if (!child(stbl.p, stbl.n, 0, "stsz", &stsz) || stsz.n < 12) return 0;
    uint32_t size = rd32(stsz.p + 4);
    if (!size && stsz.n >= 16) size = rd32(stsz.p + 12);
    uint64_t offset;
    if (child(stbl.p, stbl.n, 0, "stco", &stco) && stco.n >= 12) offset = rd32(stco.p + 8);
    else if (child(stbl.p, stbl.n, 0, "co64", &stco) && stco.n >= 16) offset = rdn(stco.p + 8, 8);
    else return 0;
    if (!size || offset + size > len) return 0;
    *hvcc = cfg.p; *hvcc_n = cfg.n; *sample = d + offset; *sample_n = size;
    return 1;
}

/* Encodes w x h BGRA pixels (rows `stride` bytes apart; alpha ignored) as a HEIC still image. quality 0...1.
   Returns the length (*out freed with free), or 0 without ffmpeg's libx265. */
ISIM_GUEST_ABI long isim_heif_encode_bgra(const unsigned char *bgra, int w, int h, int stride, double quality, unsigned char **out) {
    *out = NULL;
    if (w <= 0 || h <= 0 || !isim_heif_can_encode()) return 0;
    char raw[256], mp4[256]; tmpname(raw, sizeof raw, ".bgra"); tmpname(mp4, sizeof mp4, ".mp4");
    FILE *f = fopen(raw, "wb");
    if (!f) return 0;
    for (int y = 0; y < h; y++) fwrite(bgra + (size_t)y * stride, 1, (size_t)w * 4, f);
    fclose(f);
    char size[32], crf[16];
    snprintf(size, sizeof size, "%dx%d", w, h);
    if (quality < 0) quality = 0;
    if (quality > 1) quality = 1;
    snprintf(crf, sizeof crf, "%d", (int)(12 + (1 - quality) * 36 + 0.5));
    /* even dimensions for 4:2:0 and at least 16 x 16 for x265 (padding on the right and bottom, cropped again by the
       clean aperture box); BT.601 limited range like the colr box below */
    char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "rawvideo", "-pix_fmt", "bgra", "-s", size, "-i", raw,
                     "-vf", "pad=max(16\\,ceil(iw/2)*2):max(16\\,ceil(ih/2)*2),format=yuv420p", "-frames:v", "1", "-c:v", "libx265", "-crf", crf,
                     "-preset", "fast", "-x265-params", "log-level=none:info=0", "-colorspace", "bt470bg", "-color_range", "tv",
                     "-tag:v", "hvc1", "-f", "mp4", mp4, NULL };
    int st = run(argv);
    unlink(raw);
    size_t len = 0; unsigned char *m = st == 0 ? slurp(mp4, &len) : NULL;
    unlink(mp4);
    const unsigned char *hvcc, *sample; size_t hvcc_n, sample_n;
    if (!m || !mp4_hevc(m, len, &hvcc, &hvcc_n, &sample, &sample_n)) { free(m); return 0; }
    int pw = (w + 1) & ~1, ph = (h + 1) & ~1;
    if (pw < 16) pw = 16;
    if (ph < 16) ph = 16;

    struct buf b = { 0 };
    size_t at = open_box(&b, "ftyp");
    put4cc(&b, "heic"); put32(&b, 0); put4cc(&b, "mif1"); put4cc(&b, "heic");
    close_box(&b, at);
    size_t meta = open_full(&b, "meta", 0, 0);
    at = open_full(&b, "hdlr", 0, 0); put32(&b, 0); put4cc(&b, "pict"); put32(&b, 0); put32(&b, 0); put32(&b, 0); put8(&b, 0); close_box(&b, at);
    at = open_full(&b, "pitm", 0, 0); put16(&b, 1); close_box(&b, at);
    at = open_full(&b, "iloc", 0, 0);
    put8(&b, 0x44); put8(&b, 0x00);                         /* offset_size 4, length_size 4, base_offset_size 0 */
    put16(&b, 1); put16(&b, 1); put16(&b, 0); put16(&b, 1);  /* one item (1), data reference 0, one extent */
    size_t extent = b.n; put32(&b, 0); put32(&b, (uint32_t)sample_n);
    close_box(&b, at);
    at = open_full(&b, "iinf", 0, 0); put16(&b, 1);
    size_t infe = open_full(&b, "infe", 2, 0); put16(&b, 1); put16(&b, 0); put4cc(&b, "hvc1"); put8(&b, 0); close_box(&b, infe);
    close_box(&b, at);
    size_t iprp = open_box(&b, "iprp");
    size_t ipco = open_box(&b, "ipco");
    at = open_box(&b, "hvcC"); put(&b, hvcc, hvcc_n); close_box(&b, at);
    at = open_full(&b, "ispe", 0, 0); put32(&b, (uint32_t)pw); put32(&b, (uint32_t)ph); close_box(&b, at);
    at = open_box(&b, "colr"); put4cc(&b, "nclx"); put16(&b, 1); put16(&b, 13); put16(&b, 6); put8(&b, 0); close_box(&b, at);
    int crop = pw != w || ph != h;
    if (crop) {                                             /* clean aperture: drop the padded edge (offsets from the centre) */
        at = open_box(&b, "clap");
        put32(&b, (uint32_t)w); put32(&b, 1); put32(&b, (uint32_t)h); put32(&b, 1);
        put32(&b, (uint32_t)(w - pw)); put32(&b, 2); put32(&b, (uint32_t)(h - ph)); put32(&b, 2);
        close_box(&b, at);
    }
    close_box(&b, ipco);
    at = open_full(&b, "ipma", 0, 0); put32(&b, 1); put16(&b, 1); put8(&b, crop ? 4 : 3);
    put8(&b, 0x81); put8(&b, 0x02); put8(&b, 0x83); if (crop) put8(&b, 0x84);
    close_box(&b, at);
    close_box(&b, iprp);
    close_box(&b, meta);
    at = open_box(&b, "mdat");
    uint32_t data_at = (uint32_t)b.n;
    put(&b, sample, sample_n);
    close_box(&b, at);
    b.d[extent] = data_at >> 24; b.d[extent + 1] = data_at >> 16; b.d[extent + 2] = data_at >> 8; b.d[extent + 3] = data_at;
    free(m);
    *out = b.d;
    return (long)b.n;
}

/* ---------- decoding ---------- */
#define MAX_ITEMS 512
#define MAX_PROPS 256
struct item { uint32_t id; char type[5]; int method; uint64_t base; int nextents; uint64_t off[8], len[8]; int props[16], nprops; uint32_t dimg[256]; int ndimg; };
struct heif { const unsigned char *d; size_t len; const unsigned char *idat; size_t idat_n; uint32_t primary;
              struct item items[MAX_ITEMS]; int nitems; struct box props[MAX_PROPS]; int nprops; };

static struct item *item_get(struct heif *h, uint32_t id) {
    for (int i = 0; i < h->nitems; i++) if (h->items[i].id == id) return &h->items[i];
    if (h->nitems == MAX_ITEMS) return NULL;
    struct item *it = &h->items[h->nitems++];
    memset(it, 0, sizeof *it); it->id = id;
    return it;
}
/* the item's bytes (a malloc'd copy) */
static unsigned char *item_data(struct heif *h, struct item *it, size_t *n) {
    size_t total = 0;
    for (int e = 0; e < it->nextents; e++) total += (size_t)it->len[e];
    unsigned char *out = malloc(total ? total : 1); size_t at = 0;
    for (int e = 0; e < it->nextents; e++) {
        const unsigned char *src = it->method == 1 ? h->idat : h->d;
        size_t srcn = it->method == 1 ? h->idat_n : h->len;
        uint64_t o = it->base + it->off[e], l = it->len[e];
        if (!src || o + l > srcn) { free(out); return NULL; }
        memcpy(out + at, src + o, (size_t)l); at += (size_t)l;
    }
    *n = at;
    return out;
}
static const struct box *prop(struct heif *h, struct item *it, const char *type) {
    for (int i = 0; i < it->nprops; i++) {
        int k = it->props[i] - 1;
        if (k >= 0 && k < h->nprops && !memcmp(h->props[k].type, type, 4)) return &h->props[k];
    }
    return NULL;
}

static int parse(struct heif *h) {
    struct box meta;
    if (!child(h->d, h->len, 0, "meta", &meta) || meta.n < 4) return 0;
    const unsigned char *p = meta.p; size_t n = meta.n, off = 4; struct box b;
    while (box_at(p, n, &off, &b)) {
        if (!memcmp(b.type, "pitm", 4) && b.n >= 6) h->primary = b.p[0] == 0 ? rd16(b.p + 4) : rd32(b.p + 4);
        else if (!memcmp(b.type, "idat", 4)) { h->idat = b.p; h->idat_n = b.n; }
        else if (!memcmp(b.type, "iinf", 4) && b.n >= 6) {
            size_t o = b.p[0] == 0 ? 6 : 8; struct box e;
            while (box_at(b.p, b.n, &o, &e)) {
                if (memcmp(e.type, "infe", 4) || e.n < 4) continue;
                int v = e.p[0];
                if (v == 2 && e.n >= 12) { struct item *it = item_get(h, rd16(e.p + 4)); if (it) memcpy(it->type, e.p + 8, 4); }
                else if (v == 3 && e.n >= 14) { struct item *it = item_get(h, rd32(e.p + 4)); if (it) memcpy(it->type, e.p + 10, 4); }
            }
        } else if (!memcmp(b.type, "iloc", 4) && b.n >= 8) {
            int v = b.p[0];
            const unsigned char *q = b.p + 4, *end = b.p + b.n;
            int os = q[0] >> 4, ls = q[0] & 15, bs = q[1] >> 4, is = v >= 1 ? q[1] & 15 : 0;
            q += 2;
            uint32_t count = v < 2 ? rd16(q) : rd32(q); q += v < 2 ? 2 : 4;
            for (uint32_t i = 0; i < count && q < end; i++) {
                if (q + (v < 2 ? 2 : 4) > end) return 0;
                uint32_t id = v < 2 ? rd16(q) : rd32(q); q += v < 2 ? 2 : 4;
                int method = 0;
                if (v >= 1) { if (q + 2 > end) return 0; method = rd16(q) & 15; q += 2; }
                if (q + 2 + bs + 2 > end) return 0;
                q += 2;                                                     /* data_reference_index */
                uint64_t base = rdn(q, bs); q += bs;
                int ne = (int)rd16(q); q += 2;
                struct item *it = item_get(h, id);
                for (int e = 0; e < ne; e++) {
                    if (q + is + os + ls > end) return 0;
                    q += is;
                    uint64_t eo = rdn(q, os); q += os;
                    uint64_t el = rdn(q, ls); q += ls;
                    if (it && it->nextents < 8) { it->off[it->nextents] = eo; it->len[it->nextents] = el; it->nextents++; }
                }
                if (it) { it->method = method; it->base = base; }
            }
        } else if (!memcmp(b.type, "iref", 4) && b.n >= 4) {
            int v = b.p[0]; size_t o = 4; struct box r;
            while (box_at(b.p, b.n, &o, &r)) {
                if (memcmp(r.type, "dimg", 4)) continue;
                const unsigned char *q = r.p, *end = r.p + r.n;
                int w = v == 0 ? 2 : 4;
                if (q + w + 2 > end) continue;
                struct item *it = item_get(h, (uint32_t)rdn(q, w)); q += w;
                int cnt = (int)rd16(q); q += 2;
                for (int k = 0; k < cnt && q + w <= end; k++, q += w) if (it && it->ndimg < 256) it->dimg[it->ndimg++] = (uint32_t)rdn(q, w);
            }
        } else if (!memcmp(b.type, "iprp", 4)) {
            struct box ipco, ipma;
            if (child(b.p, b.n, 0, "ipco", &ipco)) {
                size_t o = 0; struct box pr;
                while (h->nprops < MAX_PROPS && box_at(ipco.p, ipco.n, &o, &pr)) h->props[h->nprops++] = pr;
            }
            if (child(b.p, b.n, 0, "ipma", &ipma) && ipma.n >= 8) {
                int v = ipma.p[0], wide = ipma.p[3] & 1;
                const unsigned char *q = ipma.p + 4, *end = ipma.p + ipma.n;
                uint32_t cnt = rd32(q); q += 4;
                for (uint32_t i = 0; i < cnt && q < end; i++) {
                    int w = v < 1 ? 2 : 4;
                    if (q + w + 1 > end) return 0;
                    struct item *it = item_get(h, (uint32_t)rdn(q, w)); q += w;
                    int na = *q++;
                    for (int k = 0; k < na; k++) {
                        int idx;
                        if (wide) { if (q + 2 > end) return 0; idx = (int)(rd16(q) & 0x7fff); q += 2; }
                        else { if (q + 1 > end) return 0; idx = *q & 0x7f; q += 1; }
                        if (it && it->nprops < 16) it->props[it->nprops++] = idx;
                    }
                }
            }
        }
    }
    return h->primary != 0;
}

/* Annex B: the parameter sets of hvcC, then the item's NAL units with start codes instead of length prefixes */
static int annexb(struct buf *out, const struct box *hvcc, const unsigned char *data, size_t n) {
    static const unsigned char sc[4] = { 0, 0, 0, 1 };
    if (!hvcc || hvcc->n < 23) return 0;
    const unsigned char *p = hvcc->p, *end = hvcc->p + hvcc->n;
    int lsize = (p[21] & 3) + 1, arrays = p[22];
    const unsigned char *q = p + 23;
    for (int a = 0; a < arrays; a++) {
        if (q + 3 > end) return 0;
        int cnt = (int)rd16(q + 1); q += 3;
        for (int k = 0; k < cnt; k++) {
            if (q + 2 > end) return 0;
            size_t l = rd16(q); q += 2;
            if (q + l > end) return 0;
            put(out, sc, 4); put(out, q, l); q += l;
        }
    }
    size_t o = 0;
    while (o + (size_t)lsize <= n) {
        size_t l = (size_t)rdn(data + o, lsize); o += (size_t)lsize;
        if (o + l > n) return 0;
        put(out, sc, 4); put(out, data + o, l); o += l;
    }
    return 1;
}

/* Decodes a HEIF image (hvc1, or a grid of hvc1 tiles). Returns 1 with *rgba (w*h*4, straight alpha 255; free with
   free) and its size; 0 when it is not such a file or ffmpeg cannot decode it. */
ISIM_GUEST_ABI int isim_heif_decode(const void *data, long len, int *w, int *h, unsigned char **rgba) {
    *rgba = NULL; *w = *h = 0;
    struct heif *hf = calloc(1, sizeof *hf);
    hf->d = data; hf->len = (size_t)len;
    int ok = 0;
    struct buf stream = { 0 };
    unsigned char *frames = NULL;
    char in[256] = "", outp[256] = "";
    if (!parse(hf)) goto done;
    struct item *primary = item_get(hf, hf->primary);
    if (!primary) goto done;
    uint32_t tiles[256]; int ntiles = 0, rows = 1, cols = 1, ow = 0, oh = 0;
    if (!memcmp(primary->type, "grid", 4)) {
        size_t gn; unsigned char *g = item_data(hf, primary, &gn);
        if (!g || gn < 8) { free(g); goto done; }
        int wide = g[1] & 1;
        rows = g[2] + 1; cols = g[3] + 1;
        ow = (int)(wide ? rd32(g + 4) : rd16(g + 4)); oh = (int)(wide ? rd32(g + (wide ? 8 : 6)) : rd16(g + 6));
        free(g);
        ntiles = primary->ndimg;
        memcpy(tiles, primary->dimg, sizeof(uint32_t) * (size_t)ntiles);
        if (ntiles != rows * cols) goto done;
    } else if (!memcmp(primary->type, "hvc1", 4)) {
        tiles[0] = primary->id; ntiles = 1;
    } else goto done;
    int tw = 0, th = 0;
    for (int t = 0; t < ntiles; t++) {
        struct item *it = item_get(hf, tiles[t]);
        if (!it || memcmp(it->type, "hvc1", 4)) goto done;
        const struct box *sp = prop(hf, it, "ispe");
        if (t == 0 && sp && sp->n >= 12) { tw = (int)rd32(sp->p + 4); th = (int)rd32(sp->p + 8); }
        size_t n; unsigned char *d = item_data(hf, it, &n);
        int good = d && annexb(&stream, prop(hf, it, "hvcC"), d, n);
        free(d);
        if (!good) goto done;
    }
    if (tw <= 0 || th <= 0) goto done;
    if (ntiles == 1) { ow = tw; oh = th; }
    tmpname(in, sizeof in, ".hevc"); tmpname(outp, sizeof outp, ".rgba");
    if (!spill(in, stream.d, stream.n)) goto done;
    char *argv[] = { "ffmpeg", "-nostdin", "-v", "error", "-y", "-f", "hevc", "-i", in, "-f", "rawvideo", "-pix_fmt", "rgba", outp, NULL };
    if (run(argv) != 0) goto done;
    size_t fn; frames = slurp(outp, &fn);
    size_t one = (size_t)tw * th * 4;
    if (!frames || fn < one * (size_t)ntiles) goto done;
    /* compose the tiles and crop to the output size */
    unsigned char *img = malloc((size_t)ow * oh * 4);
    for (int t = 0; t < ntiles; t++) {
        int tx = (t % cols) * tw, ty = (t / cols) * th;
        for (int y = 0; y < th && ty + y < oh; y++) {
            int cw = tx + tw > ow ? ow - tx : tw;
            if (cw > 0) memcpy(img + ((size_t)(ty + y) * ow + tx) * 4, frames + one * t + (size_t)y * tw * 4, (size_t)cw * 4);
        }
    }
    /* transformative properties of the primary item, in order */
    for (int i = 0; i < primary->nprops; i++) {
        int k = primary->props[i] - 1;
        if (k < 0 || k >= hf->nprops) continue;
        const struct box *pr = &hf->props[k];
        if (!memcmp(pr->type, "clap", 4) && pr->n >= 32) {
            int32_t v[8]; for (int j = 0; j < 8; j++) v[j] = (int32_t)rd32(pr->p + 4 * j);
            if (!v[1] || !v[3] || !v[5] || !v[7]) continue;
            int cw = (int)((double)v[0] / v[1] + 0.5), ch = (int)((double)v[2] / v[3] + 0.5);
            int left = (int)((ow - cw) / 2.0 + (double)v[4] / v[5] + 0.5), top = (int)((oh - ch) / 2.0 + (double)v[6] / v[7] + 0.5);
            if (cw <= 0 || ch <= 0 || left < 0 || top < 0 || left + cw > ow || top + ch > oh) continue;
            unsigned char *o = malloc((size_t)cw * ch * 4);
            for (int y = 0; y < ch; y++) memcpy(o + (size_t)y * cw * 4, img + ((size_t)(top + y) * ow + left) * 4, (size_t)cw * 4);
            free(img); img = o; ow = cw; oh = ch;
        } else if (!memcmp(pr->type, "irot", 4) && pr->n >= 1) {
            int a = pr->p[0] & 3;                                       /* anticlockwise quarter turns */
            for (int r = 0; r < a; r++) {
                unsigned char *o = malloc((size_t)ow * oh * 4);
                for (int y = 0; y < oh; y++) for (int x = 0; x < ow; x++)   /* (x, y) -> (y, ow - 1 - x) in an oh x ow image */
                    memcpy(o + ((size_t)(ow - 1 - x) * oh + y) * 4, img + ((size_t)y * ow + x) * 4, 4);
                free(img); img = o; int t = ow; ow = oh; oh = t;
            }
        } else if (!memcmp(pr->type, "imir", 4) && pr->n >= 1) {
            int vertical_axis = (pr->p[0] & 1) == 0;                     /* axis 0: left-right flip */
            for (int y = 0; y < (vertical_axis ? oh : oh / 2); y++) for (int x = 0; x < (vertical_axis ? ow / 2 : ow); x++) {
                unsigned char *a = img + ((size_t)y * ow + x) * 4;
                unsigned char *b2 = vertical_axis ? img + ((size_t)y * ow + (ow - 1 - x)) * 4 : img + ((size_t)(oh - 1 - y) * ow + x) * 4;
                unsigned char t4[4]; memcpy(t4, a, 4); memcpy(a, b2, 4); memcpy(b2, t4, 4);
            }
        }
    }
    *rgba = img; *w = ow; *h = oh;
    ok = 1;
done:
    if (in[0]) unlink(in);
    if (outp[0]) unlink(outp);
    free(frames); free(stream.d); free(hf);
    return ok;
}
