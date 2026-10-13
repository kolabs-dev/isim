/* isim /usr/lib/libz.1.dylib and /usr/lib/libcompression.dylib.
 *
 * libz: zlib's C API, forwarded to the host's libz.so.1 like libsqlite3 (host_sqlite.c): zlib passes pointers, integers
 * and C callbacks, and its structures (z_stream, gz_header, gzFile_s) have the same layout on Darwin and Linux, so every
 * function maps to the host's (passthrough). The library is dlopen'ed on the first symbol lookup; gzprintf (variadic)
 * is not offered.
 * libcompression: the buffer API (compression_encode_buffer / compression_decode_buffer); adapted: COMPRESSION_ZLIB
 * (raw DEFLATE, RFC 1951, like Apple's) through the host's zlib; LZFSE, LZ4, LZMA and Brotli are not available (the
 * calls return 0, Apple's result for a failure). */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "runtime.h"

#define ZLIB_NAMES(F) \
    F(zlibVersion) F(zlibCompileFlags) F(zError) F(deflateInit_) F(deflateInit2_) F(deflate) F(deflateEnd) F(deflateSetDictionary) \
    F(deflateGetDictionary) F(deflateCopy) F(deflateReset) F(deflateResetKeep) F(deflateParams) F(deflateTune) F(deflateBound) \
    F(deflatePending) F(deflatePrime) F(deflateSetHeader) F(inflateInit_) F(inflateInit2_) F(inflate) F(inflateEnd) \
    F(inflateSetDictionary) F(inflateGetDictionary) F(inflateSync) F(inflateSyncPoint) F(inflateCopy) F(inflateReset) \
    F(inflateResetKeep) F(inflateReset2) F(inflatePrime) F(inflateMark) F(inflateGetHeader) F(inflateBackInit_) F(inflateBack) \
    F(inflateBackEnd) F(inflateUndermine) F(inflateValidate) F(inflateCodesUsed) F(compress) F(compress2) F(compressBound) \
    F(uncompress) F(uncompress2) F(gzopen) F(gzdopen) F(gzbuffer) F(gzsetparams) F(gzread) F(gzfread) F(gzwrite) F(gzfwrite) \
    F(gzputs) F(gzgets) F(gzputc) F(gzgetc) F(gzgetc_) F(gzungetc) F(gzflush) F(gzseek) F(gzrewind) F(gztell) F(gzoffset) F(gzeof) \
    F(gzdirect) F(gzclose) F(gzclose_r) F(gzclose_w) F(gzerror) F(gzclearerr) F(adler32) F(adler32_z) F(adler32_combine) \
    F(crc32) F(crc32_z) F(crc32_combine) F(crc32_combine_gen) F(crc32_combine_op) F(get_crc_table)

static void z_missing(void);
#define ZF(n) { "_" #n, (void *)z_missing, "passthrough" },
static struct shim z_table[] = { ZLIB_NAMES(ZF) };
#undef ZF

static int z_loaded;
static void *z_handle;
static void z_missing(void) {
    fflush(NULL);
    fprintf(stderr, "isim: FATAL: the app called a zlib function that the host's libz.so.1 does not provide%s\n",
            z_loaded > 0 ? " (older zlib)" : " (libz.so.1 not found: install zlib)");
    abort();
}
static void z_load(void) {
    if (z_loaded) return;
    z_loaded = -1;
    void *h = dlopen("libz.so.1", RTLD_NOW | RTLD_GLOBAL);
    if (!h) return;
    z_loaded = 1;
    z_handle = h;
    for (size_t i = 0; i < sizeof z_table / sizeof *z_table; i++) {
        void *p = dlsym(h, z_table[i].name + 1);
        if (p) z_table[i].addr = p;
    }
}
const struct host_lib host_libz = { "/usr/lib/libz.1.dylib", z_table, sizeof z_table / sizeof *z_table, z_load };

/* ---------------- libcompression ---------------- */
/* zlib's z_stream (same layout as zlib.h's; only the fields used here are named) */
struct zs {
    const unsigned char *next_in; unsigned avail_in; unsigned long total_in;
    unsigned char *next_out; unsigned avail_out; unsigned long total_out;
    const char *msg; void *state; void *zalloc, *zfree, *opaque; int data_type; unsigned long adler, reserved;
};
enum { COMPRESSION_ZLIB = 0x205 };

static void *zfn(const char *name) { z_load(); return z_handle ? dlsym(z_handle, name) : NULL; }

static size_t c_encode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch, int alg) {
    (void)scratch;
    if (alg != COMPRESSION_ZLIB || dcap == 0) return 0;
    int (*init2)(struct zs *, int, int, int, int, int, const char *, int) = zfn("deflateInit2_");
    int (*def)(struct zs *, int) = zfn("deflate");
    int (*end)(struct zs *) = zfn("deflateEnd");
    const char *(*ver)(void) = zfn("zlibVersion");
    if (!init2 || !def || !end || !ver) return 0;
    struct zs z; memset(&z, 0, sizeof z);
    if (init2(&z, 5, 8 /* Z_DEFLATED */, -15 /* raw */, 8, 0, ver(), sizeof z) != 0) return 0;
    z.next_in = src; z.avail_in = (unsigned)slen; z.next_out = dst; z.avail_out = (unsigned)dcap;
    int r = def(&z, 4 /* Z_FINISH */);
    size_t n = r == 1 /* Z_STREAM_END */ ? z.total_out : 0;
    end(&z);
    return n;
}
static size_t c_decode(uint8_t *dst, size_t dcap, const uint8_t *src, size_t slen, void *scratch, int alg) {
    (void)scratch;
    if (alg != COMPRESSION_ZLIB || dcap == 0) return 0;
    int (*init2)(struct zs *, int, const char *, int) = zfn("inflateInit2_");
    int (*inf)(struct zs *, int) = zfn("inflate");
    int (*end)(struct zs *) = zfn("inflateEnd");
    const char *(*ver)(void) = zfn("zlibVersion");
    if (!init2 || !inf || !end || !ver) return 0;
    struct zs z; memset(&z, 0, sizeof z);
    if (init2(&z, -15, ver(), sizeof z) != 0) return 0;
    z.next_in = src; z.avail_in = (unsigned)slen; z.next_out = dst; z.avail_out = (unsigned)dcap;
    int r = inf(&z, 4 /* Z_FINISH */);
    size_t n = (r == 1 || r == -5 /* Z_BUF_ERROR: dst full, Apple returns what fits */) ? z.total_out : 0;
    end(&z);
    return n;
}
static size_t c_scratch_size(int alg) { (void)alg; return 1; }   /* zlib allocates its own state */

static const struct shim compression_table[] = {
    { "_compression_encode_buffer", (void *)c_encode, "adapted" }, { "_compression_decode_buffer", (void *)c_decode, "adapted" },
    { "_compression_encode_scratch_buffer_size", (void *)c_scratch_size, "adapted" },
    { "_compression_decode_scratch_buffer_size", (void *)c_scratch_size, "adapted" },
};
const struct host_lib host_libcompression = { "/usr/lib/libcompression.dylib", compression_table,
                                              sizeof compression_table / sizeof *compression_table, NULL };
