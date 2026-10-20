// libcompression and NSData compression from C / Objective-C (CompressionTest.app, issue #264): every algorithm through
// the buffer and stream APIs, the formats' signatures (Apple's LZ4 frames, xz, LZFSE blocks, raw DEFLATE that zlib
// reads back), streams fed and drained in small pieces, bad data and LZBITMAP failing, NSData / NSMutableData.
#import <Foundation/Foundation.h>
#include <compression.h>
#include <zlib.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[160]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static const struct { compression_algorithm alg; const char *name; } ALGS[] = {
    { COMPRESSION_LZ4, "LZ4" }, { COMPRESSION_LZ4_RAW, "LZ4_RAW" }, { COMPRESSION_ZLIB, "ZLIB" },
    { COMPRESSION_LZMA, "LZMA" }, { COMPRESSION_LZFSE, "LZFSE" }, { COMPRESSION_BROTLI, "BROTLI" },
};

/* text-like input that compresses, longer than LZ4's 64 KiB blocks */
static uint8_t *sample(size_t n) {
    uint8_t *p = malloc(n);
    const char *words[] = { "isim ", "runs ", "iOS ", "apps ", "on ", "Linux, ", "compressed ", "with ", "LZFSE. " };
    uint32_t x = 12345;
    for (size_t i = 0; i < n;) {
        x = x * 1103515245 + 12345;
        const char *w = words[(x >> 16) % 9];
        for (size_t k = 0; w[k] && i < n; k++) p[i++] = (uint8_t)w[k];
    }
    return p;
}

/* a stream round trip that feeds `chunk` bytes at a time into an output buffer of `room` bytes */
static size_t stream_run(compression_stream_operation op, compression_algorithm alg, const uint8_t *src, size_t n,
                         uint8_t *out, size_t cap, size_t chunk, size_t room, compression_status *last) {
    compression_stream s;
    if (compression_stream_init(&s, op, alg) != COMPRESSION_STATUS_OK) { *last = COMPRESSION_STATUS_ERROR; return 0; }
    size_t fed = 0, made = 0;
    compression_status st = COMPRESSION_STATUS_OK;
    s.src_size = 0;
    for (int guard = 0; guard < 1000000 && st == COMPRESSION_STATUS_OK; guard++) {
        if (s.src_size == 0 && fed < n) { size_t k = n - fed < chunk ? n - fed : chunk; s.src_ptr = src + fed; s.src_size = k; fed += k; }
        size_t r = cap - made < room ? cap - made : room;
        s.dst_ptr = out + made; s.dst_size = r;
        int fin = fed == n ? COMPRESSION_STREAM_FINALIZE : 0;
        st = compression_stream_process(&s, fin);
        made += r - s.dst_size;
        if (made == cap) break;
    }
    compression_stream_destroy(&s);
    *last = st;
    return made;
}

static void algorithms(void) {
    size_t n = 200000;
    uint8_t *src = sample(n), *enc = malloc(n * 2), *dec = malloc(n + 16), *enc2 = malloc(n * 2), *dec2 = malloc(n + 16);
    for (size_t i = 0; i < sizeof ALGS / sizeof *ALGS; i++) {
        compression_algorithm a = ALGS[i].alg;
        const char *nm = ALGS[i].name;
        void *es = malloc(compression_encode_scratch_buffer_size(a)), *ds = malloc(compression_decode_scratch_buffer_size(a));
        size_t e = compression_encode_buffer(enc, n * 2, src, n, es, a);
        CHECK(e > 0 && e < n / 2, "%s buffer encode (%zu -> %zu bytes)", nm, n, e);
        size_t d = compression_decode_buffer(dec, n + 16, enc, e, ds, a);
        CHECK(d == n && !memcmp(dec, src, n), "%s buffer round trip", nm);
        CHECK(compression_encode_buffer(enc2, 8, src, n, es, a) == 0, "%s encode into too small a buffer gives 0", nm);
        free(es); free(ds);

        compression_status st;
        size_t se = stream_run(COMPRESSION_STREAM_ENCODE, a, src, n, enc2, n * 2, 1000, 777, &st);
        CHECK(st == COMPRESSION_STATUS_END && se > 0, "%s stream encode, 1000-byte pieces into 777-byte buffers (%zu bytes)", nm, se);
        size_t sd = stream_run(COMPRESSION_STREAM_DECODE, a, enc2, se, dec2, n + 16, 333, 4096, &st);
        CHECK(st == COMPRESSION_STATUS_END && sd == n && !memcmp(dec2, src, n), "%s stream round trip", nm);
        d = compression_decode_buffer(dec, n + 16, enc2, se, NULL, a);
        CHECK(d == n && !memcmp(dec, src, n), "%s stream output decodes as a buffer", nm);
        sd = stream_run(COMPRESSION_STREAM_DECODE, a, enc, e, dec2, n + 16, e, n + 16, &st);
        CHECK(st == COMPRESSION_STATUS_END && sd == n && !memcmp(dec2, src, n), "%s buffer output decodes as a stream", nm);

        uint8_t junk[64];
        memset(junk, 0xA5, sizeof junk);
        CHECK(compression_decode_buffer(dec, n, junk, sizeof junk, NULL, a) == 0 || a == COMPRESSION_LZ4_RAW, "%s bad data gives 0", nm);
    }
    /* the formats */
    size_t e = compression_encode_buffer(enc, n * 2, src, n, NULL, COMPRESSION_LZ4);
    CHECK(!memcmp(enc, "bv41", 4) && !memcmp(enc + e - 4, "bv4$", 4), "LZ4 is Apple's frames (bv41 ... bv4$)");
    e = compression_encode_buffer(enc, n, (const uint8_t *)"", 0, NULL, COMPRESSION_LZFSE);
    CHECK(e >= 4 && !memcmp(enc + e - 4, "bvx$", 4), "LZFSE of nothing is its end-of-stream block (bvx$)");
    e = compression_encode_buffer(enc, n * 2, src, n, NULL, COMPRESSION_LZFSE);
    CHECK(!memcmp(enc, "bvx", 3) && !memcmp(enc + e - 4, "bvx$", 4), "LZFSE is LZFSE blocks (bvx...)");
    e = compression_encode_buffer(enc, n * 2, src, n, NULL, COMPRESSION_LZMA);
    CHECK(!memcmp(enc, "\xFD" "7zXZ", 6), "LZMA is the xz format");
    e = compression_encode_buffer(enc, n * 2, src, n, NULL, COMPRESSION_ZLIB);
    z_stream z = { 0 };
    inflateInit2(&z, -15);
    z.next_in = enc; z.avail_in = (uInt)e; z.next_out = dec; z.avail_out = (uInt)(n + 16);
    int zr = inflate(&z, Z_FINISH);
    CHECK(zr == Z_STREAM_END && z.total_out == n && !memcmp(dec, src, n), "ZLIB is raw DEFLATE (zlib reads it back)");
    inflateEnd(&z);
    /* LZ4 data that does not compress is stored */
    uint8_t rnd[5000];
    uint32_t x = 99;
    for (size_t i = 0; i < sizeof rnd; i++) { x = x * 1664525 + 1013904223; rnd[i] = x >> 24; }
    e = compression_encode_buffer(enc, n, rnd, sizeof rnd, NULL, COMPRESSION_LZ4);
    size_t d = compression_decode_buffer(dec, n, enc, e, NULL, COMPRESSION_LZ4);
    CHECK(!memcmp(enc, "bv4-", 4) && d == sizeof rnd && !memcmp(dec, rnd, d), "LZ4 stores incompressible data (bv4-)");
    /* a destination too small for the whole output gives what fits */
    e = compression_encode_buffer(enc, n * 2, src, n, NULL, COMPRESSION_ZLIB);
    CHECK(compression_decode_buffer(dec, 1000, enc, e, NULL, COMPRESSION_ZLIB) == 1000 && !memcmp(dec, src, 1000), "decoding into a small buffer gives what fits");
    /* LZBITMAP is not available */
    compression_stream s;
    CHECK(compression_encode_buffer(enc, n, src, n, NULL, COMPRESSION_LZBITMAP) == 0, "LZBITMAP buffer encode fails (0)");
    CHECK(compression_stream_init(&s, COMPRESSION_STREAM_ENCODE, COMPRESSION_LZBITMAP) == COMPRESSION_STATUS_ERROR, "LZBITMAP stream_init fails");
    CHECK(compression_stream_init(&s, COMPRESSION_STREAM_DECODE, COMPRESSION_ZLIB) == COMPRESSION_STATUS_OK &&
          compression_stream_destroy(&s) == COMPRESSION_STATUS_OK, "init and destroy");
    free(src); free(enc); free(dec); free(enc2); free(dec2);
}

static void nsdata(void) {
    NSMutableString *text = [NSMutableString string];
    for (int i = 0; i < 2000; i++) [text appendFormat:@"line %d of isim's NSData compression test\n", i % 37];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding];
    const char *names[] = { "LZFSE", "LZ4", "LZMA", "Zlib" };
    for (NSInteger a = NSDataCompressionAlgorithmLZFSE; a <= NSDataCompressionAlgorithmZlib; a++) {
        NSError *err = nil;
        NSData *c = [data compressedDataUsingAlgorithm:a error:&err];
        NSData *d = [c decompressedDataUsingAlgorithm:a error:&err];
        CHECK(c && c.length < data.length / 4 && [d isEqualToData:data], "NSData %s round trip (%lu -> %lu bytes)", names[a],
              (unsigned long)data.length, (unsigned long)c.length);
        NSMutableData *m = [data mutableCopy];
        CHECK([m compressUsingAlgorithm:a error:&err] && [m isEqualToData:c] && [m decompressUsingAlgorithm:a error:&err] &&
              [m isEqualToData:data], "NSMutableData %s compress / decompress in place", names[a]);
    }
    NSData *c = [data compressedDataUsingAlgorithm:NSDataCompressionAlgorithmZlib error:NULL];
    uint8_t out[8192];
    size_t d = compression_decode_buffer(out, sizeof out, c.bytes, c.length, NULL, COMPRESSION_ZLIB);
    CHECK(d == sizeof out && !memcmp(out, data.bytes, d), "NSData's zlib is libcompression's");
    NSError *err = nil;
    NSData *bad = [[NSData dataWithBytes:"not compressed at all" length:21] decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZFSE error:&err];
    CHECK(bad == nil && [err.domain isEqualToString:NSCocoaErrorDomain], "bad data: nil and a Cocoa error");
    CHECK([[[NSData data] compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZMA error:NULL] decompressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZMA error:NULL].length == 0,
          "empty data round trip");
    NSMutableData *md = [NSMutableData dataWithData:data];
    CHECK([[md compressedDataUsingAlgorithm:NSDataCompressionAlgorithmLZ4 error:NULL] isKindOfClass:[NSMutableData class]], "a mutable receiver gives mutable data (instancetype)");
}

int main(void) {
    @autoreleasepool {
        algorithms();
        nsdata();
        printf("compression test: %d/%d passed\n", checks - failures, checks);
        return failures ? 1 : 0;
    }
}
