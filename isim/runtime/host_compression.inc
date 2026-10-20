/* isim /usr/lib/libcompression.dylib (included by host_z.c): the buffer API and the stream API (compression_stream).
 * Adapted, by algorithm:
 *   COMPRESSION_ZLIB    raw DEFLATE (RFC 1951, level 5, like Apple's), through the host's zlib (passthrough codec)
 *   COMPRESSION_LZMA    the xz format, preset 6 (Apple's), through the host's liblzma
 *   COMPRESSION_LZ4     Apple's LZ4 frames ("bv41" / "bv4-" blocks, "bv4$" end) over the host's liblz4 blocks;
 *   COMPRESSION_LZ4_RAW one raw LZ4 block
 *   COMPRESSION_LZFSE   Apple's reference LZFSE (third_party/lzfse, BSD-3-Clause; host_lzfse.c)
 *   COMPRESSION_BROTLI  through the host's libbrotlienc / libbrotlidec
 *   COMPRESSION_LZBITMAP not available (Apple's own, undocumented format): calls fail
 * A missing host library makes its algorithm fail the same way (0 from the buffer calls, COMPRESSION_STATUS_ERROR from
 * stream_init). Streams of zlib, LZMA and Brotli are the libraries' own streams; LZ4 streams decode block by block;
 * LZFSE and raw LZ4 streams are buffered (an encoder's output comes at COMPRESSION_STREAM_FINALIZE, a decoder's when
 * the end-of-stream block has arrived). */
#include "host_lzfse.h"

enum { ALG_LZ4 = 0x100, ALG_LZ4_RAW = 0x101, ALG_ZLIB = 0x205, ALG_LZMA = 0x306, ALG_LZFSE = 0x801, ALG_BROTLI = 0xB02 };
enum { STATUS_OK = 0, STATUS_ERROR = -1, STATUS_END = 1, STREAM_FINALIZE = 1, OP_ENCODE = 0, OP_DECODE = 1 };

/* the host's codec libraries, by name (a table per host OS: these are Linux's) */
static const char *const lz4_names[] = { "liblz4.so.1", NULL };
static const char *const lzma_names[] = { "liblzma.so.5", NULL };
static const char *const brotlienc_names[] = { "libbrotlienc.so.1", NULL };
static const char *const brotlidec_names[] = { "libbrotlidec.so.1", NULL };
static void *open_first(const char *const *names) {
    for (int i = 0; names[i]; i++) { void *h = dlopen(names[i], RTLD_NOW | RTLD_LOCAL); if (h) return h; }
    return NULL;
}
static void *codec_symbol(const char *const *names, void **handle, int *tried, const char *sym) {
    if (!*tried) { *tried = 1; *handle = open_first(names); }
    return *handle ? dlsym(*handle, sym) : NULL;
}
static void *lz4_h, *lzma_h, *benc_h, *bdec_h;
static int lz4_t, lzma_t, benc_t, bdec_t;
#define LZ4(s) codec_symbol(lz4_names, &lz4_h, &lz4_t, s)
#define LZMA(s) codec_symbol(lzma_names, &lzma_h, &lzma_t, s)
#define BENC(s) codec_symbol(brotlienc_names, &benc_h, &benc_t, s)
#define BDEC(s) codec_symbol(brotlidec_names, &bdec_h, &bdec_t, s)

/* liblzma's lzma_stream (lzma/base.h), with room to spare at the end */
struct lzs {
    const uint8_t *next_in; size_t avail_in; uint64_t total_in;
    uint8_t *next_out; size_t avail_out; uint64_t total_out;
    const void *allocator; void *internal; void *reserved_ptr[4];
    uint64_t seek_pos, reserved_int2; size_t reserved_int3, reserved_int4; int reserved_enum1, reserved_enum2;
    uint64_t spare[8];
};
enum { LZMA_RUN = 0, LZMA_FINISH = 3, LZMA_OK_ = 0, LZMA_STREAM_END_ = 1, LZMA_BUF_ERROR_ = 10, LZMA_CHECK_CRC64_ = 4 };

/* ---------------- the LZ4 frames Apple writes ---------------- */
static void put32(uint8_t *p, uint32_t v) { p[0] = v; p[1] = v >> 8; p[2] = v >> 16; p[3] = v >> 24; }
static uint32_t get32(const uint8_t *p) { return p[0] | (uint32_t)p[1] << 8 | (uint32_t)p[2] << 16 | (uint32_t)p[3] << 24; }
enum { LZ4_BLOCK = 1 << 16 };
/* frames of up to 64 KiB of input each; 0 if dst is too small */
static size_t lz4_frame_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen) {
    int (*comp)(const char *, char *, int, int) = LZ4("LZ4_compress_default");
    int (*bound)(int) = LZ4("LZ4_compressBound");
    if (!comp || !bound) return 0;
    size_t out = 0;
    for (size_t at = 0; at < slen; at += LZ4_BLOCK) {
        size_t n = slen - at < LZ4_BLOCK ? slen - at : LZ4_BLOCK;
        if (out + 12 > dcap) return 0;
        int room = (int)(dcap - out - 12 < (size_t)bound((int)n) ? dcap - out - 12 : (size_t)bound((int)n));
        int c = comp((const char *)src + at, (char *)dst + out + 12, (int)n, room);
        if (c > 0 && (size_t)c < n) {
            memcpy(dst + out, "bv41", 4); put32(dst + out + 4, (uint32_t)n); put32(dst + out + 8, (uint32_t)c);
            out += 12 + (size_t)c;
        } else {                                          /* incompressible: stored ("bv4-") */
            if (out + 8 + n > dcap) return 0;
            memcpy(dst + out, "bv4-", 4); put32(dst + out + 4, (uint32_t)n); memcpy(dst + out + 8, src + at, n);
            out += 8 + n;
        }
    }
    if (out + 4 > dcap) return 0;
    memcpy(dst + out, "bv4$", 4);
    return out + 4;
}
/* decodes whole blocks of src after dst's first `prefix` bytes, which are the output so far (a "bv41" block may refer
   to the 64 KiB before it); *produced: the bytes added (at most dcap - prefix), *used: the input consumed; 1 at the end
   block, -1 on bad data, 0 when more input is needed */
static int lz4_frame_decode(uint8_t *dst, size_t dcap, size_t prefix, size_t *produced, const uint8_t *src, size_t slen, size_t *used) {
    int (*dec)(const char *, char *, int, int, const char *, int) = LZ4("LZ4_decompress_safe_usingDict");
    size_t pos = prefix;
    *produced = 0; *used = 0;
    if (!dec) return -1;
    while (slen - *used >= 4) {
        const uint8_t *p = src + *used;
        size_t left = slen - *used;
        if (!memcmp(p, "bv4$", 4)) { *used += 4; return 1; }
        if (!memcmp(p, "bv4-", 4)) {
            if (left < 8) return 0;
            uint32_t n = get32(p + 4);
            if (left < 8 + (size_t)n || pos + n > dcap) return 0;
            memcpy(dst + pos, p + 8, n); pos += n; *used += 8 + n;
        } else if (!memcmp(p, "bv41", 4)) {
            if (left < 12) return 0;
            uint32_t n = get32(p + 4), c = get32(p + 8);
            if (left < 12 + (size_t)c || pos + n > dcap) return 0;
            size_t d = pos < 65536 ? pos : 65536;
            int r = dec((const char *)p + 12, (char *)dst + pos, (int)c, (int)n, (const char *)dst + pos - d, (int)d);
            if (r != (int)n) return -1;
            pos += n; *used += 12 + c;
        } else return -1;
        *produced = pos - prefix;
    }
    return 0;
}

/* ---------------- the buffer API ---------------- */
static size_t zlib_buffer(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, int encode);
static size_t lzma_buffer(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, int encode) {
    if (encode) {
        int (*enc)(uint32_t, int, const void *, const uint8_t *, size_t, uint8_t *, size_t *, size_t) = LZMA("lzma_easy_buffer_encode");
        size_t pos = 0;
        return enc && enc(6, LZMA_CHECK_CRC64_, NULL, src, slen, dst, &pos, dcap) == LZMA_OK_ ? pos : 0;
    }
    /* a decoder stream, so that a dst too small gives what fits (like Apple's) */
    int (*init)(struct lzs *, uint64_t, uint32_t) = LZMA("lzma_stream_decoder");
    int (*code)(struct lzs *, int) = LZMA("lzma_code");
    void (*end)(struct lzs *) = LZMA("lzma_end");
    if (!init || !code || !end) return 0;
    struct lzs z; memset(&z, 0, sizeof z);
    if (init(&z, UINT64_MAX, 0) != LZMA_OK_) return 0;
    z.next_in = src; z.avail_in = slen; z.next_out = dst; z.avail_out = dcap;
    int r = code(&z, LZMA_FINISH);
    size_t n = r == LZMA_STREAM_END_ || r == LZMA_OK_ || r == LZMA_BUF_ERROR_ ? (size_t)z.total_out : 0;
    end(&z);
    return n;
}
static size_t brotli_buffer(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, int encode) {
    size_t n = dcap;
    if (encode) {
        int (*enc)(int, int, int, size_t, const uint8_t *, size_t *, uint8_t *) = BENC("BrotliEncoderCompress");
        return enc && enc(2 /* quality, Apple's speed */, 22, 0, slen, src, &n, dst) ? n : 0;
    }
    int (*dec)(size_t, const uint8_t *, size_t *, uint8_t *) = BDEC("BrotliDecoderDecompress");
    return dec && dec(slen, src, &n, dst) == 1 ? n : 0;
}
ISIM_GUEST_ABI static size_t c_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch, int alg) {
    if (dcap == 0) return 0;
    switch (alg) {
    case ALG_ZLIB: return zlib_buffer(dst, dcap, src, slen, 1);
    case ALG_LZMA: return lzma_buffer(dst, dcap, src, slen, 1);
    case ALG_BROTLI: return brotli_buffer(dst, dcap, src, slen, 1);
    case ALG_LZ4: return lz4_frame_encode(dst, dcap, src, slen);
    case ALG_LZ4_RAW: {
        int (*comp)(const char *, char *, int, int) = LZ4("LZ4_compress_default");
        int c = comp ? comp((const char *)src, (char *)dst, (int)slen, (int)(dcap > INT32_MAX ? INT32_MAX : dcap)) : 0;
        return c > 0 ? (size_t)c : 0;
    }
    case ALG_LZFSE: return isim_lzfse_encode(dst, dcap, src, slen, scratch);
    default: return 0;
    }
}
ISIM_GUEST_ABI static size_t c_decode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch, int alg) {
    if (dcap == 0) return 0;
    switch (alg) {
    case ALG_ZLIB: return zlib_buffer(dst, dcap, src, slen, 0);
    case ALG_LZMA: return lzma_buffer(dst, dcap, src, slen, 0);
    case ALG_BROTLI: return brotli_buffer(dst, dcap, src, slen, 0);
    case ALG_LZ4: {
        size_t produced = 0, used = 0;
        return lz4_frame_decode(dst, dcap, 0, &produced, src, slen, &used) >= 0 ? produced : 0;
    }
    case ALG_LZ4_RAW: {
        int (*dec)(const char *, char *, int, int, int) = LZ4("LZ4_decompress_safe_partial");
        int r = dec ? dec((const char *)src, (char *)dst, (int)slen, (int)dcap, (int)dcap) : -1;
        return r > 0 ? (size_t)r : 0;
    }
    case ALG_LZFSE: return isim_lzfse_decode(dst, dcap, src, slen, scratch);
    default: return 0;
    }
}
ISIM_GUEST_ABI static size_t c_encode_scratch_size(int alg) { return alg == ALG_LZFSE ? isim_lzfse_encode_scratch_size() : 1; }
ISIM_GUEST_ABI static size_t c_decode_scratch_size(int alg) { return alg == ALG_LZFSE ? isim_lzfse_decode_scratch_size() : 1; }

static size_t zlib_buffer(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, int encode) {
    const char *(*ver)(void) = zfn("zlibVersion");
    if (!ver) return 0;
    struct zs z; memset(&z, 0, sizeof z);
    if (encode) {
        int (*init2)(struct zs *, int, int, int, int, int, const char *, int) = zfn("deflateInit2_");
        int (*def)(struct zs *, int) = zfn("deflate");
        int (*end)(struct zs *) = zfn("deflateEnd");
        if (!init2 || !def || !end || init2(&z, 5, 8 /* Z_DEFLATED */, -15 /* raw */, 8, 0, ver(), sizeof z) != 0) return 0;
        z.next_in = src; z.avail_in = (unsigned)slen; z.next_out = dst; z.avail_out = (unsigned)dcap;
        int r = def(&z, 4 /* Z_FINISH */);
        size_t n = r == 1 /* Z_STREAM_END */ ? z.total_out : 0;
        end(&z);
        return n;
    }
    int (*init2)(struct zs *, int, const char *, int) = zfn("inflateInit2_");
    int (*inf)(struct zs *, int) = zfn("inflate");
    int (*end)(struct zs *) = zfn("inflateEnd");
    if (!init2 || !inf || !end || init2(&z, -15, ver(), sizeof z) != 0) return 0;
    z.next_in = src; z.avail_in = (unsigned)slen; z.next_out = dst; z.avail_out = (unsigned)dcap;
    int r = inf(&z, 4 /* Z_FINISH */);
    size_t n = (r == 1 || r == -5 /* Z_BUF_ERROR: dst full, Apple returns what fits */) ? z.total_out : 0;
    end(&z);
    return n;
}

/* ---------------- the stream API ---------------- */
/* Apple's compression_stream */
struct cstream { uint8_t *dst_ptr; size_t dst_size; const uint8_t *src_ptr; size_t src_size; void *state; };
struct cstate {
    int op, alg, finished;
    struct zs z;                               /* zlib */
    struct lzs l;                              /* LZMA */
    void *brotli;                              /* a BrotliEncoderState / BrotliDecoderState */
    uint8_t *in; size_t in_len, in_cap;        /* buffered input (LZ4, LZFSE) */
    uint8_t *out; size_t out_len, out_pos;     /* output not yet given (LZ4, LZFSE) */
};
static void append(uint8_t **buf, size_t *len, size_t *cap, const uint8_t *p, size_t n) {
    if (*len + n > *cap) { *cap = (*len + n) * 2 + 4096; *buf = realloc(*buf, *cap); }
    memcpy(*buf + *len, p, n); *len += n;
}
ISIM_GUEST_ABI static int c_stream_init(struct cstream *s, int op, int alg) {
    if (!s || (op != OP_ENCODE && op != OP_DECODE)) return STATUS_ERROR;
    struct cstate *st = calloc(1, sizeof *st);
    st->op = op; st->alg = alg;
    int ok = 0;
    switch (alg) {
    case ALG_ZLIB: {
        const char *(*ver)(void) = zfn("zlibVersion");
        if (!ver) break;
        if (op == OP_ENCODE) { int (*i)(struct zs *, int, int, int, int, int, const char *, int) = zfn("deflateInit2_"); ok = i && i(&st->z, 5, 8, -15, 8, 0, ver(), sizeof st->z) == 0; }
        else { int (*i)(struct zs *, int, const char *, int) = zfn("inflateInit2_"); ok = i && i(&st->z, -15, ver(), sizeof st->z) == 0; }
        break;
    }
    case ALG_LZMA:
        if (op == OP_ENCODE) { int (*i)(struct lzs *, uint32_t, int) = LZMA("lzma_easy_encoder"); ok = i && i(&st->l, 6, LZMA_CHECK_CRC64_) == LZMA_OK_; }
        else { int (*i)(struct lzs *, uint64_t, uint32_t) = LZMA("lzma_stream_decoder"); ok = i && i(&st->l, UINT64_MAX, 0) == LZMA_OK_; }
        break;
    case ALG_BROTLI:
        if (op == OP_ENCODE) {
            void *(*create)(void *, void *, void *) = BENC("BrotliEncoderCreateInstance");
            int (*param)(void *, int, uint32_t) = BENC("BrotliEncoderSetParameter");
            if (create && param && (st->brotli = create(NULL, NULL, NULL))) { param(st->brotli, 1 /* QUALITY */, 2); ok = 1; }
        } else {
            void *(*create)(void *, void *, void *) = BDEC("BrotliDecoderCreateInstance");
            ok = create && (st->brotli = create(NULL, NULL, NULL));
        }
        break;
    case ALG_LZ4: case ALG_LZ4_RAW: ok = LZ4("LZ4_compress_default") != NULL; break;
    case ALG_LZFSE: ok = 1; break;
    default: break;
    }
    if (!ok) { free(st); s->state = NULL; return STATUS_ERROR; }
    s->state = st;
    return STATUS_OK;
}
/* gives buffered output; END once it is all given and the stream is finished */
static int drain(struct cstream *s, struct cstate *st) {
    size_t n = st->out_len - st->out_pos;
    if (n > s->dst_size) n = s->dst_size;
    memcpy(s->dst_ptr, st->out + st->out_pos, n);
    st->out_pos += n; s->dst_ptr += n; s->dst_size -= n;
    return st->finished && st->out_pos == st->out_len ? STATUS_END : STATUS_OK;
}
ISIM_GUEST_ABI static int c_stream_process(struct cstream *s, int flags) {
    struct cstate *st = s ? s->state : NULL;
    if (!st) return STATUS_ERROR;
    int fin = flags & STREAM_FINALIZE;
    switch (st->alg) {
    case ALG_ZLIB: {
        int (*fn)(struct zs *, int) = zfn(st->op == OP_ENCODE ? "deflate" : "inflate");
        st->z.next_in = s->src_ptr; st->z.avail_in = (unsigned)s->src_size; st->z.next_out = s->dst_ptr; st->z.avail_out = (unsigned)s->dst_size;
        int r = fn(&st->z, st->op == OP_ENCODE ? (fin ? 4 : 0) : 0);
        s->src_ptr = st->z.next_in; s->src_size = st->z.avail_in; s->dst_ptr = st->z.next_out; s->dst_size = st->z.avail_out;
        return r == 1 ? STATUS_END : (r == 0 || r == -5) ? STATUS_OK : STATUS_ERROR;
    }
    case ALG_LZMA: {
        int (*code)(struct lzs *, int) = LZMA("lzma_code");
        st->l.next_in = s->src_ptr; st->l.avail_in = s->src_size; st->l.next_out = s->dst_ptr; st->l.avail_out = s->dst_size;
        int r = code(&st->l, fin ? LZMA_FINISH : LZMA_RUN);
        s->src_ptr = st->l.next_in; s->src_size = st->l.avail_in; s->dst_ptr = st->l.next_out; s->dst_size = st->l.avail_out;
        return r == LZMA_STREAM_END_ ? STATUS_END : (r == LZMA_OK_ || r == LZMA_BUF_ERROR_) ? STATUS_OK : STATUS_ERROR;
    }
    case ALG_BROTLI: {
        if (st->op == OP_ENCODE) {
            int (*cs)(void *, int, size_t *, const uint8_t **, size_t *, uint8_t **, size_t *) = BENC("BrotliEncoderCompressStream");
            int (*done)(void *) = BENC("BrotliEncoderIsFinished");
            if (!cs(st->brotli, fin ? 2 /* FINISH */ : 0 /* PROCESS */, &s->src_size, &s->src_ptr, &s->dst_size, &s->dst_ptr, NULL)) return STATUS_ERROR;
            return fin && done(st->brotli) ? STATUS_END : STATUS_OK;
        }
        int (*ds)(void *, size_t *, const uint8_t **, size_t *, uint8_t **, size_t *) = BDEC("BrotliDecoderDecompressStream");
        int r = ds(st->brotli, &s->src_size, &s->src_ptr, &s->dst_size, &s->dst_ptr, NULL);
        return r == 1 /* SUCCESS */ ? STATUS_END : r == 0 /* ERROR */ ? STATUS_ERROR : STATUS_OK;
    }
    default: break;
    }
    /* LZ4 and LZFSE: buffered */
    if (st->out_pos < st->out_len || st->finished) return drain(s, st);
    append(&st->in, &st->in_len, &st->in_cap, s->src_ptr, s->src_size);
    s->src_ptr += s->src_size; s->src_size = 0;
    if (st->op == OP_DECODE && st->alg == ALG_LZ4) {           /* the whole blocks that have arrived */
        size_t keep = st->out_len < 65536 ? st->out_len : 65536;     /* the history the next blocks may refer to */
        size_t produced, used, cap = keep + st->in_len * 4 + LZ4_BLOCK * 2;
        uint8_t *out = malloc(cap);
        if (keep) memcpy(out, st->out + st->out_len - keep, keep);
        int r = lz4_frame_decode(out, cap, keep, &produced, st->in, st->in_len, &used);
        if (r < 0) { free(out); return STATUS_ERROR; }
        memmove(st->in, st->in + used, st->in_len - used); st->in_len -= used;
        free(st->out); st->out = out; st->out_len = keep + produced; st->out_pos = keep;
        st->finished = r == 1;
        return drain(s, st);
    }
    int ready = fin;
    if (st->op == OP_DECODE && st->alg == ALG_LZFSE && st->in_len >= 4 && !memcmp(st->in + st->in_len - 4, "bvx$", 4)) ready = 1;
    if (!ready) return STATUS_OK;
    size_t cap = st->op == OP_ENCODE ? st->in_len + st->in_len / 2 + 1024 : st->in_len * 8 + 4096, n;
    for (;;) {                                                  /* grows the output until it all fits */
        st->out = realloc(st->out, cap);
        if (st->op == OP_ENCODE) {
            n = c_encode(st->out, cap, st->in, st->in_len, NULL, st->alg);
            if (n > 0) break;
        } else {
            n = c_decode(st->out, cap, st->in, st->in_len, NULL, st->alg);
            if (n > 0 && n < cap) break;
            if (n == 0) {                                       /* bad data, a stream not complete yet, or empty */
                if (!fin) return STATUS_OK;
                if (st->alg == ALG_LZFSE && st->in_len == 4 && !memcmp(st->in, "bvx$", 4)) break;
                return STATUS_ERROR;
            }
        }
        if (cap > (size_t)1 << 31) return STATUS_ERROR;
        cap *= 4;
    }
    st->out_len = n; st->out_pos = 0; st->finished = 1;
    return drain(s, st);
}
ISIM_GUEST_ABI static int c_stream_destroy(struct cstream *s) {
    struct cstate *st = s ? s->state : NULL;
    if (!st) return STATUS_ERROR;
    if (st->alg == ALG_ZLIB) { int (*end)(struct zs *) = zfn(st->op == OP_ENCODE ? "deflateEnd" : "inflateEnd"); if (end) end(&st->z); }
    if (st->alg == ALG_LZMA) { void (*end)(struct lzs *) = LZMA("lzma_end"); if (end) end(&st->l); }
    if (st->alg == ALG_BROTLI && st->brotli) {
        void (*d)(void *) = st->op == OP_ENCODE ? BENC("BrotliEncoderDestroyInstance") : BDEC("BrotliDecoderDestroyInstance");
        if (d) d(st->brotli);
    }
    free(st->in); free(st->out); free(st);
    s->state = NULL;
    return STATUS_OK;
}

static const struct shim compression_table[] = {
    { "_compression_encode_buffer", (void *)c_encode, "adapted" }, { "_compression_decode_buffer", (void *)c_decode, "adapted" },
    { "_compression_encode_scratch_buffer_size", (void *)c_encode_scratch_size, "adapted" },
    { "_compression_decode_scratch_buffer_size", (void *)c_decode_scratch_size, "adapted" },
    { "_compression_stream_init", (void *)c_stream_init, "adapted" }, { "_compression_stream_process", (void *)c_stream_process, "adapted" },
    { "_compression_stream_destroy", (void *)c_stream_destroy, "adapted" },
};
const struct host_lib host_libcompression = { "/usr/lib/libcompression.dylib", compression_table,
                                              sizeof compression_table / sizeof *compression_table, NULL };
