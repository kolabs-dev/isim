/* isim /usr/lib/libz.1.dylib and /usr/lib/libcompression.dylib.
 *
 * libz: zlib's C API, forwarded to the host's libz.so.1 like libsqlite3 (host_sqlite.c): zlib passes pointers, integers
 * and C callbacks, and its structures (z_stream, gz_header, gzFile_s) have the same layout on Darwin and Linux, so every
 * function maps to the host's (passthrough). The library is dlopen'ed on the first symbol lookup; gzprintf (variadic)
 * is not offered.
 * libcompression: the buffer and stream APIs, every algorithm (host_compression.inc). */
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
static void *zfn(const char *name) { z_load(); return z_handle ? dlsym(z_handle, name) : NULL; }

#include "host_compression.inc"
