// AppleArchive's C API on isim (AppleArchiveTest.app, issue #348): key sets, headers built, encoded and decoded, XAT
// blobs, file / temporary / custom byte streams, compression in each algorithm, a directory archived with a path list,
// decoded, converted and extracted, AAArchiveStreamProcess, custom archive streams, paths that leave the directory.
#import <Foundation/Foundation.h>
#include <AppleArchive/AppleArchive.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[200]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)

static char root[1024];
static void path_in(char *out, size_t cap, const char *rel) { snprintf(out, cap, "%s/%s", root, rel); }
static void write_file(const char *rel, const void *data, size_t n) {
    char p[1100]; path_in(p, sizeof p, rel);
    FILE *f = fopen(p, "wb"); fwrite(data, 1, n, f); fclose(f);
}
static size_t read_file(const char *rel, void *buf, size_t cap) {
    char p[1100]; path_in(p, sizeof p, rel);
    FILE *f = fopen(p, "rb"); if (!f) return 0;
    size_t n = fread(buf, 1, cap, f); fclose(f); return n;
}

/* an in-memory byte stream for AACustomByteStreamOpen */
struct mem { uint8_t *bytes; size_t size, cap, at; };
static ssize_t mem_write(void *arg, const void *buf, size_t n) {
    struct mem *m = arg;
    if (m->size + n > m->cap) { m->cap = (m->size + n) * 2; m->bytes = realloc(m->bytes, m->cap); }
    memcpy(m->bytes + m->size, buf, n); m->size += n; return (ssize_t)n;
}
static ssize_t mem_read(void *arg, void *buf, size_t n) {
    struct mem *m = arg;
    if (n > m->size - m->at) n = m->size - m->at;
    memcpy(buf, m->bytes + m->at, n); m->at += n; return (ssize_t)n;
}
static AAByteStream mem_stream(struct mem *m) {
    AAByteStream s = AACustomByteStreamOpen();
    AACustomByteStreamSetData(s, m);
    AACustomByteStreamSetWriteProc(s, mem_write);
    AACustomByteStreamSetReadProc(s, mem_read);
    return s;
}

/* entry messages: counts, and excludes "skip.me" */
static int excluded, extracted;
static int on_message(void *arg, AAEntryMessage m, const char *path, void *data) {
    if (m == AA_ENTRY_MESSAGE_SEARCH_EXCLUDE && strstr(path, "skip.me")) { excluded++; return 1; }
    if (m == AA_ENTRY_MESSAGE_EXTRACT_BEGIN && data) extracted++;
    return 0;
}

/* a custom archive stream that counts the entries and DAT bytes written to it */
struct counter { int headers; size_t bytes; };
static int count_header(void *arg, AAHeader h) { ((struct counter *)arg)->headers++; return 0; }
static int count_blob(void *arg, AAFieldKey key, const void *buf, size_t n) { ((struct counter *)arg)->bytes += n; return 0; }

static void key_sets(void) {
    AAFieldKeySet s = AAFieldKeySetCreateWithString("TYP,PAT,DAT");
    AAFieldKeySet t = AAFieldKeySetCreateWithString("DAT,MOD");
    AAFieldKeySetInsertKeySet(s, t);
    char out[64] = { 0 };
    AAFieldKeySetSerialize(s, sizeof out, out);
    CHECK(AAFieldKeySetGetKeyCount(s) == 4 && AAFieldKeySetContainsKey(s, AA_FIELD_C("MOD")) == 1 && !strcmp(out, "TYP,PAT,DAT,MOD"),
          "key sets: insert a set, contains, serialize (%s)", out);
    AAFieldKeySetRemoveKeySet(s, t);
    AAFieldKeySetSelectKeySet(t, s);
    CHECK(AAFieldKeySetGetKeyCount(s) == 2 && AAFieldKeySetGetKeyCount(t) == 0 && AAFieldKeySetCreateWithString("TOOLONG") == NULL,
          "key sets: remove, select, bad strings refused");
    AAFieldKeySetDestroy(s); AAFieldKeySetDestroy(t);
}

static void headers(void) {
    AAHeader h = AAHeaderCreate();
    struct timespec ts = { 1700000000, 5 };
    uint8_t digest[32]; for (int i = 0; i < 32; i++) digest[i] = (uint8_t)i;
    AAHeaderSetFieldUInt(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("TYP"), AA_ENTRY_TYPE_REG);
    AAHeaderSetFieldString(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("PAT"), "dir/file.txt", 12);
    AAHeaderSetFieldTimespec(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("MTM"), &ts);
    AAHeaderSetFieldHash(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("SH2"), AA_HASH_FUNCTION_SHA256, digest);
    AAHeaderSetFieldFlag(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("XYZ"));
    AAHeaderSetFieldBlob(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("XAT"), 10);
    AAHeaderSetFieldBlob(h, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("DAT"), 100000);
    const uint8_t *enc = AAHeaderGetEncodedData(h);
    size_t n = AAHeaderGetEncodedSize(h);
    CHECK(enc && n > 6 && !memcmp(enc, "AA01", 4) && (enc[4] | enc[5] << 8) == n, "header encoding: AA01 and its size (%zu)", n);
    AAHeader d = AAHeaderCreateWithEncodedData(n, enc);
    char pat[64]; size_t len = 0; struct timespec t2; uint8_t dg[64]; AAHashFunction fn = 0; uint64_t size, off;
    int i = AAHeaderGetKeyIndex(d, AA_FIELD_C("PAT"));
    AAHeaderGetFieldString(d, (uint32_t)i, sizeof pat, pat, &len);
    AAHeaderGetFieldTimespec(d, (uint32_t)AAHeaderGetKeyIndex(d, AA_FIELD_C("MTM")), &t2);
    AAHeaderGetFieldHash(d, (uint32_t)AAHeaderGetKeyIndex(d, AA_FIELD_C("SH2")), sizeof dg, &fn, dg);
    AAHeaderGetFieldBlob(d, (uint32_t)AAHeaderGetKeyIndex(d, AA_FIELD_C("DAT")), &size, &off);
    CHECK(AAHeaderGetFieldCount(d) == 7 && !strcmp(pat, "dir/file.txt") && t2.tv_sec == ts.tv_sec && t2.tv_nsec == 5 &&
          fn == AA_HASH_FUNCTION_SHA256 && !memcmp(dg, digest, 32) && size == 100000 && off == 10 && AAHeaderGetPayloadSize(d) == 100010 &&
          AAHeaderGetFieldType(d, (uint32_t)AAHeaderGetKeyIndex(d, AA_FIELD_C("XYZ"))) == AA_FIELD_TYPE_FLAG,
          "header decoding: string, timespec, hash, flag, blobs and their offsets");
    AAHeaderRemoveField(d, (uint32_t)AAHeaderGetKeyIndex(d, AA_FIELD_C("XYZ")));
    AAHeader c = AAHeaderClone(d);
    CHECK(AAHeaderGetFieldCount(c) == 6 && AAHeaderGetKeyIndex(c, AA_FIELD_C("XYZ")) < 0, "AAHeaderRemoveField, AAHeaderClone");
    AAHeaderDestroy(h); AAHeaderDestroy(d); AAHeaderDestroy(c);

    AAEntryXATBlob x = AAEntryXATBlobCreate();
    AAEntryXATBlobAppendEntry(x, "com.example.a", (const uint8_t *)"one", 3);
    AAEntryXATBlobAppendEntry(x, "com.example.b", (const uint8_t *)"", 0);
    AAEntryXATBlob y = AAEntryXATBlobCreateWithEncodedData(AAEntryXATBlobGetEncodedData(x), AAEntryXATBlobGetEncodedSize(x));
    char key[64]; uint8_t data[8]; size_t kl, ds;
    AAEntryXATBlobGetEntry(y, 0, sizeof key, key, &kl, sizeof data, data, &ds);
    CHECK(y && AAEntryXATBlobGetEntryCount(y) == 2 && !strcmp(key, "com.example.a") && ds == 3 && !memcmp(data, "one", 3), "XAT blob encoding round trip");
    AAEntryXATBlobDestroy(x); AAEntryXATBlobDestroy(y);
}

static void compression(void) {
    size_t n = 300000;
    uint8_t *in = malloc(n), *out = malloc(n);
    for (size_t i = 0; i < n; i++) in[i] = (uint8_t)("isim archive "[i % 13] + (i / 4096) % 3);
    const struct { AACompressionAlgorithm a; const char *name; } algs[] = {
        { AA_COMPRESSION_ALGORITHM_NONE, "none" }, { AA_COMPRESSION_ALGORITHM_LZ4, "lz4" }, { AA_COMPRESSION_ALGORITHM_ZLIB, "zlib" },
        { AA_COMPRESSION_ALGORITHM_LZMA, "lzma" }, { AA_COMPRESSION_ALGORITHM_LZFSE, "lzfse" },
    };
    for (size_t k = 0; k < sizeof algs / sizeof *algs; k++) {
        struct mem m = { 0 };
        AAByteStream ms = mem_stream(&m);
        AAByteStream cs = AACompressionOutputStreamOpen(ms, algs[k].a, 65536, 0, 0);
        for (size_t at = 0; at < n; at += 10000) AAByteStreamWrite(cs, in + at, n - at < 10000 ? n - at : 10000);
        AAByteStreamClose(cs);
        m.at = 0;
        AAByteStream ds = AADecompressionInputStreamOpen(ms, 0, 0);
        size_t got = 0; ssize_t r;
        while ((r = AAByteStreamRead(ds, out + got, n - got < 7777 ? n - got : 7777)) > 0) got += (size_t)r;
        AAByteStreamClose(ds); AAByteStreamClose(ms);
        CHECK(got == n && !memcmp(in, out, n) && (algs[k].a == AA_COMPRESSION_ALGORITHM_NONE || m.size < n / 2) && !memcmp(m.bytes, "pbz", 3),
              "compression %s: %zu -> %zu bytes and back", algs[k].name, n, m.size);
        free(m.bytes);
    }
    free(in); free(out);
}

static void archives(void) {
    char src[1100], dst[1100], arc[1100];
    path_in(src, sizeof src, "src"); path_in(dst, sizeof dst, "dst"); path_in(arc, sizeof arc, "test.aar");
    mkdir(src, 0755);
    char sub[1100]; path_in(sub, sizeof sub, "src/sub"); mkdir(sub, 0755);
    const char *text = "AppleArchive on isim, from C.\n";
    write_file("src/hello.txt", text, strlen(text));
    write_file("src/skip.me", "x", 1);
    uint8_t big[50000]; for (size_t i = 0; i < sizeof big; i++) big[i] = (uint8_t)(i * 7);
    write_file("src/sub/big.bin", big, sizeof big);

    // archive: a path list of the directory, written to an encode stream over a compressed file
    AAPathList list = AAPathListCreateWithDirectoryContents(src, NULL, NULL, on_message, 0, 0);
    int paths = 0;
    char first[64] = "?";
    for (uint64_t node = AAPathListNodeFirst(list); node != AA_PATH_LIST_NODE_END; node = AAPathListNodeNext(list, node)) {
        if (paths == 1) AAPathListNodeGetPath(list, node, sizeof first, first, NULL);
        paths++;
    }
    CHECK(paths == 4 && excluded == 1 && !strcmp(first, "hello.txt"), "path list: 4 paths (%s first after the root), skip.me excluded", first);
    AAByteStream file = AAFileStreamOpenWithPath(arc, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    AAByteStream comp = AACompressionOutputStreamOpen(file, AA_COMPRESSION_ALGORITHM_LZFSE, 0, 0, 0);
    AAArchiveStream enc = AAEncodeArchiveOutputStreamOpen(comp, NULL, NULL, 0, 0);
    AAFieldKeySet keys = AAFieldKeySetCreateWithString("TYP,PAT,DAT,MOD,UID,CKS");
    int w = AAArchiveStreamWritePathList(enc, list, keys, src, NULL, NULL, 0, 0);
    CHECK(w == 0 && AAArchiveStreamClose(enc) == 0 && AAByteStreamClose(comp) == 0 && AAByteStreamClose(file) == 0, "AAArchiveStreamWritePathList");
    AAPathListDestroy(list);

    // decode: headers in order, DAT read in two pieces
    file = AAFileStreamOpenWithPath(arc, O_RDONLY, 0);
    AAByteStream plain = AADecompressionInputStreamOpen(file, 0, 0);
    AAArchiveStream dec = AADecodeArchiveInputStreamOpen(plain, NULL, NULL, 0, 0);
    AAHeader h;
    int entries = 0, ok_data = 0;
    char pat[256];
    while (AAArchiveStreamReadHeader(dec, &h) == 1) {
        entries++;
        int i = AAHeaderGetKeyIndex(h, AA_FIELD_C("PAT"));
        AAHeaderGetFieldString(h, (uint32_t)i, sizeof pat, pat, NULL);
        if (!strcmp(pat, "hello.txt")) {
            char buf[64] = { 0 };
            ok_data = AAArchiveStreamReadBlob(dec, AA_FIELD_C("DAT"), buf, 5) == 0 &&
                      AAArchiveStreamReadBlob(dec, AA_FIELD_C("DAT"), buf + 5, strlen(text) - 5) == 0 && !strcmp(buf, text) &&
                      AAArchiveStreamReadBlob(dec, AA_FIELD_C("DAT"), buf, 1) < 0;
        }
    }
    AAArchiveStreamClose(dec); AAByteStreamClose(plain); AAByteStreamClose(file);
    CHECK(entries == 4 && ok_data, "decode: 4 entries; DAT in pieces, not past its end");

    // convert (remove UID) into a counting custom stream, then extract with AAArchiveStreamProcess
    file = AAFileStreamOpenWithPath(arc, O_RDONLY, 0);
    plain = AADecompressionInputStreamOpen(file, 0, 0);
    dec = AADecodeArchiveInputStreamOpen(plain, NULL, NULL, 0, 0);
    struct counter counter = { 0 };
    AAArchiveStream custom = AACustomArchiveStreamOpen();
    AACustomArchiveStreamSetData(custom, &counter);
    AACustomArchiveStreamSetWriteHeaderProc(custom, count_header);
    AACustomArchiveStreamSetWriteBlobProc(custom, count_blob);
    AAFieldKeySet remove = AAFieldKeySetCreateWithString("UID");
    AAArchiveStream conv = AAConvertArchiveOutputStreamOpen(custom, NULL, remove, NULL, NULL, 0, 0);
    ssize_t copied = AAArchiveStreamProcess(dec, conv, NULL, NULL, 0, 0);
    AAArchiveStreamClose(conv); AAArchiveStreamClose(custom); AAArchiveStreamClose(dec); AAByteStreamClose(plain); AAByteStreamClose(file);
    CHECK(copied == 4 && counter.headers == 4 && counter.bytes == strlen(text) + sizeof big, "convert into a custom archive stream: 4 entries, %zu bytes", counter.bytes);

    file = AAFileStreamOpenWithPath(arc, O_RDONLY, 0);
    plain = AADecompressionInputStreamOpen(file, 0, 0);
    dec = AADecodeArchiveInputStreamOpen(plain, NULL, NULL, 0, 0);
    AAArchiveStream ext = AAExtractArchiveOutputStreamOpen(dst, NULL, on_message, 0, 0);
    copied = AAArchiveStreamProcess(dec, ext, NULL, NULL, 0, 0);
    AAArchiveStreamClose(ext); AAArchiveStreamClose(dec); AAByteStreamClose(plain); AAByteStreamClose(file);
    char back[64] = { 0 };
    uint8_t bigback[60000];
    CHECK(copied == 4 && extracted == 4 && read_file("dst/hello.txt", back, sizeof back) == strlen(text) && !strcmp(back, text) &&
          read_file("dst/sub/big.bin", bigback, sizeof bigback) == sizeof big && !memcmp(big, bigback, sizeof big),
          "extract: the files come back");

    // a path that leaves the directory is refused
    ext = AAExtractArchiveOutputStreamOpen(dst, NULL, NULL, 0, 0);
    AAHeader evil = AAHeaderCreate();
    AAHeaderSetFieldUInt(evil, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("TYP"), AA_ENTRY_TYPE_REG);
    AAHeaderSetFieldString(evil, AA_HEADER_FIELD_INDEX_BY_KEY, AA_FIELD_C("PAT"), "sub/../../escaped", 17);
    int refused = AAArchiveStreamWriteHeader(ext, evil) < 0;
    AAArchiveStreamClose(ext); AAHeaderDestroy(evil);
    char esc[1100]; path_in(esc, sizeof esc, "escaped");
    CHECK(refused && access(esc, F_OK) != 0, "extract: ../ paths refused");
    AAFieldKeySetDestroy(keys); AAFieldKeySetDestroy(remove);
}

static void temp_and_header_from_path(void) {
    AAByteStream t = AATempFileStreamOpen();
    char buf[16] = { 0 };
    CHECK(AAByteStreamWrite(t, "temporary", 9) == 9 && AAByteStreamSeek(t, 0, SEEK_SET) == 0 && AAByteStreamRead(t, buf, 16) == 9 &&
          !strcmp(buf, "temporary") && AAByteStreamPRead(t, buf, 4, 5) == 4 && !memcmp(buf, "rary", 4), "temporary file stream: write, seek, read, pread");
    AAByteStreamClose(t);
    AAFieldKeySet keys = AAFieldKeySetCreateWithString("TYP,PAT,SIZ,DAT,SH1");
    AAHeader h = AAHeaderCreateWithPath(keys, root, "src/hello.txt", 0);
    uint64_t typ = 0, siz = 0;
    AAHeaderGetFieldUInt(h, (uint32_t)AAHeaderGetKeyIndex(h, AA_FIELD_C("TYP")), &typ);
    AAHeaderGetFieldUInt(h, (uint32_t)AAHeaderGetKeyIndex(h, AA_FIELD_C("SIZ")), &siz);
    CHECK(h && typ == AA_ENTRY_TYPE_REG && siz == 30 && AAHeaderGetPayloadSize(h) == 30 && AAHeaderGetKeyIndex(h, AA_FIELD_C("SH1")) >= 0,
          "AAHeaderCreateWithPath: TYP, SIZ, DAT, SH1");
    AAHeaderDestroy(h); AAFieldKeySetDestroy(keys);
}

int main(void) {
    @autoreleasepool {
        snprintf(root, sizeof root, "%s/aa-c-%d", NSTemporaryDirectory().fileSystemRepresentation, getpid());
        mkdir(root, 0755);
        key_sets();
        headers();
        compression();
        archives();
        temp_and_header_from_path();
        [[NSFileManager defaultManager] removeItemAtPath:@(root) error:nil];
        printf("apple archive C test: %d/%d passed\n", checks - failures, checks);
        return failures == 0 ? 0 : 1;
    }
}
