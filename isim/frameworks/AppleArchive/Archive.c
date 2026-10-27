/* isim AppleArchive: archive streams and path lists (adapted). An archive is a sequence of entries, each an encoded
 * header followed by its blobs (DAT, XAT, …) in field order. Encoding writes entries to a byte stream, decoding reads
 * them back, extraction makes the files they describe under a directory (paths that leave it are refused), conversion
 * removes or adds fields (sizes and hashes computed from DAT) and custom streams call back. Self-authored. */
#include "AAInternal.h"
#include <CommonCrypto/CommonDigest.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/time.h>
#include <unistd.h>
#include <zlib.h>

struct AAArchiveStream_impl {
    void *data;
    AAArchiveStreamCloseProc close;
    AAArchiveStreamWriteHeaderProc write_header;
    AAArchiveStreamWriteBlobProc write_blob;
    AAArchiveStreamReadHeaderProc read_header;
    AAArchiveStreamReadBlobProc read_blob;
    AAArchiveStreamCancelProc cancel;
    int cancelled;
};

static AAArchiveStream astream_new(void) { return calloc(1, sizeof(struct AAArchiveStream_impl)); }
/* a message to the callback; data: the entry's header (encode, decode, convert, process, extract begin) or XAT blob */
static int message_with(AAEntryMessageProc proc, void *arg, AAEntryMessage m, const char *path, void *data) { return proc ? proc(arg, m, path, data) : 0; }
static int message(AAEntryMessageProc proc, void *arg, AAEntryMessage m, const char *path) { return message_with(proc, arg, m, path, NULL); }
static void header_path(AAHeader h, char *out, size_t cap) {
    int i = AAHeaderGetKeyIndex(h, aa_key("PAT"));
    size_t len = 0;
    out[0] = 0;
    if (i >= 0) AAHeaderGetFieldString(h, (uint32_t)i, cap, out, &len);
}
static int header_uint(AAHeader h, const char *key, uint64_t *v) {
    int i = AAHeaderGetKeyIndex(h, aa_key(key));
    return i >= 0 && AAHeaderGetFieldUInt(h, (uint32_t)i, v) == 0;
}

/* ---- the stream functions ---- */
int AAArchiveStreamWriteHeader(AAArchiveStream s, AAHeader h) { return s->cancelled || !s->write_header ? -1 : s->write_header(s->data, h); }
int AAArchiveStreamWriteBlob(AAArchiveStream s, AAFieldKey k, const void *buf, size_t n) { return s->cancelled || !s->write_blob ? -1 : s->write_blob(s->data, k, buf, n); }
int AAArchiveStreamReadHeader(AAArchiveStream s, AAHeader *h) { *h = NULL; return s->cancelled || !s->read_header ? -1 : s->read_header(s->data, h); }
int AAArchiveStreamReadBlob(AAArchiveStream s, AAFieldKey k, void *buf, size_t n) { return s->cancelled || !s->read_blob ? -1 : s->read_blob(s->data, k, buf, n); }
void AAArchiveStreamCancel(AAArchiveStream s) { s->cancelled = 1; if (s->cancel) s->cancel(s->data); }
int AAArchiveStreamClose(AAArchiveStream s) {
    if (!s) return 0;
    int r = s->close ? s->close(s->data) : 0;
    free(s);
    return r;
}

/* ---- custom streams ---- */
AAArchiveStream AACustomArchiveStreamOpen(void) { return astream_new(); }
void AACustomArchiveStreamSetData(AAArchiveStream s, void *d) { s->data = d; }
void AACustomArchiveStreamSetCloseProc(AAArchiveStream s, AAArchiveStreamCloseProc p) { s->close = p; }
void AACustomArchiveStreamSetWriteHeaderProc(AAArchiveStream s, AAArchiveStreamWriteHeaderProc p) { s->write_header = p; }
void AACustomArchiveStreamSetWriteBlobProc(AAArchiveStream s, AAArchiveStreamWriteBlobProc p) { s->write_blob = p; }
void AACustomArchiveStreamSetReadHeaderProc(AAArchiveStream s, AAArchiveStreamReadHeaderProc p) { s->read_header = p; }
void AACustomArchiveStreamSetReadBlobProc(AAArchiveStream s, AAArchiveStreamReadBlobProc p) { s->read_blob = p; }
void AACustomArchiveStreamSetCancelProc(AAArchiveStream s, AAArchiveStreamCancelProc p) { s->cancel = p; }

/* ---- encoding: entries to a byte stream ---- */
struct encoder { AAByteStream out; void *msg_data; AAEntryMessageProc msg; };
static int enc_header(void *a, AAHeader h) {
    struct encoder *e = a;
    char path[1024];
    header_path(h, path, sizeof path);
    if (message_with(e->msg, e->msg_data, AA_ENTRY_MESSAGE_ENCODE_WRITING, path, h) < 0) return -1;
    size_t n = AAHeaderGetEncodedSize(h);
    const uint8_t *d = AAHeaderGetEncodedData(h);
    return d && n && aa_write_all(e->out, d, n) == 0 ? 0 : -1;
}
static int enc_blob(void *a, AAFieldKey k, const void *buf, size_t n) { (void)k; return aa_write_all(((struct encoder *)a)->out, buf, n); }
static int enc_close(void *a) { free(a); return 0; }
AAArchiveStream AAEncodeArchiveOutputStreamOpen(AAByteStream out, void *msg_data, AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)flags; (void)n_threads;
    struct encoder *e = calloc(1, sizeof *e);
    AAArchiveStream s = astream_new();
    if (!e || !s) { free(e); free(s); return NULL; }
    e->out = out; e->msg_data = msg_data; e->msg = msg;
    s->data = e; s->write_header = enc_header; s->write_blob = enc_blob; s->close = enc_close;
    return s;
}

/* ---- decoding: entries from a byte stream; blobs are read in field order, each in one or more pieces ---- */
struct decoder {
    AAByteStream in; void *msg_data; AAEntryMessageProc msg;
    AAHeader cur;
    uint64_t payload, pos;               /* the current entry's payload size, and how much of it was read */
    uint64_t *done; uint32_t ndone;      /* per field: the bytes of its blob read so far */
};
static int skip(AAByteStream in, uint64_t n) {
    uint8_t buf[16384];
    while (n) {
        size_t c = n < sizeof buf ? (size_t)n : sizeof buf;
        if (aa_read_all(in, buf, c) != (ssize_t)c) return -1;
        n -= c;
    }
    return 0;
}
static int dec_header(void *a, AAHeader *out) {
    struct decoder *d = a;
    if (d->cur && skip(d->in, d->payload - d->pos) < 0) return -1;
    AAHeaderDestroy(d->cur);
    d->cur = NULL;
    int eof;
    AAHeader h = aa_header_read(d->in, &eof);
    if (!h) return eof ? 0 : -1;
    char path[1024];
    header_path(h, path, sizeof path);
    if (message_with(d->msg, d->msg_data, AA_ENTRY_MESSAGE_DECODE_READING, path, h) < 0) { AAHeaderDestroy(h); return -1; }
    d->cur = h; d->payload = AAHeaderGetPayloadSize(h); d->pos = 0;
    uint32_t n = AAHeaderGetFieldCount(h);
    uint64_t *done = realloc(d->done, (n ? n : 1) * sizeof *done);
    if (!done) return -1;
    memset(done, 0, (n ? n : 1) * sizeof *done);
    d->done = done; d->ndone = n;
    *out = h;
    return 1;
}
static int dec_blob(void *a, AAFieldKey k, void *buf, size_t n) {
    struct decoder *d = a;
    if (!d->cur) return -1;
    int i = AAHeaderGetKeyIndex(d->cur, k);
    uint64_t size, off;
    if (i < 0 || AAHeaderGetFieldBlob(d->cur, (uint32_t)i, &size, &off) != 0 || d->done[i] + n > size) return -1;
    uint64_t at = off + d->done[i];
    if (at < d->pos || skip(d->in, at - d->pos) < 0) return -1;     /* a blob already passed cannot be read again */
    if (aa_read_all(d->in, buf, n) != (ssize_t)n) return -1;
    d->pos = at + n; d->done[i] += n;
    return 0;
}
static int dec_close(void *a) { struct decoder *d = a; AAHeaderDestroy(d->cur); free(d->done); free(d); return 0; }
AAArchiveStream AADecodeArchiveInputStreamOpen(AAByteStream in, void *msg_data, AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)flags; (void)n_threads;
    struct decoder *d = calloc(1, sizeof *d);
    AAArchiveStream s = astream_new();
    if (!d || !s) { free(d); free(s); return NULL; }
    d->in = in; d->msg_data = msg_data; d->msg = msg;
    s->data = d; s->read_header = dec_header; s->read_blob = dec_blob; s->close = dec_close;
    return s;
}

/* ---- extraction: entries become files under a directory ---- */
struct dirattr { char *path; uint64_t mode; int has_mode; struct timespec mtm; int has_mtm; };
struct extractor {
    char *dir; void *msg_data; AAEntryMessageProc msg; AAFlagSet flags;
    int active, skipping; char path[1024], full[2048];
    AAHeader cur; int fd;
    uint8_t *xat; size_t xat_size, xat_cap;
    struct dirattr *dirs; size_t ndirs, capdirs;     /* directories' attributes, set at the end (their files change them) */
};
/* a relative path that stays inside the directory: no "..", not absolute */
static int safe_path(const char *p) {
    if (p[0] == '/') return 0;
    for (const char *c = p; *c; ) {
        const char *e = strchr(c, '/');
        size_t len = e ? (size_t)(e - c) : strlen(c);
        if (len == 2 && c[0] == '.' && c[1] == '.') return 0;
        if (!e) break;
        c = e + 1;
    }
    return 1;
}
static void make_parents(char *full) {
    for (char *p = full + 1; *p; p++)
        if (*p == '/') { *p = 0; mkdir(full, 0755); *p = '/'; }
}
static void set_times(const char *path, const struct timespec *t) {
    struct timeval tv[2] = { { t->tv_sec, (int)(t->tv_nsec / 1000) }, { t->tv_sec, (int)(t->tv_nsec / 1000) } };
    utimes(path, tv);
}
static int ext_finish(struct extractor *x) {
    if (!x->active) return 0;
    x->active = 0;
    if (x->fd >= 0) { close(x->fd); x->fd = -1; }
    int r = 0;
    if (!x->skipping) {
        uint64_t typ = 'F', mode;
        header_uint(x->cur, "TYP", &typ);
        if (x->xat_size) {
            AAEntryXATBlob b = AAEntryXATBlobCreateWithEncodedData(x->xat, x->xat_size);
            if (b) { message_with(x->msg, x->msg_data, AA_ENTRY_MESSAGE_EXTRACT_XAT, x->path, b); AAEntryXATBlobApplyToPath(b, x->dir, x->path, x->flags); }
            AAEntryXATBlobDestroy(b);
        }
        int mi = AAHeaderGetKeyIndex(x->cur, aa_key("MTM"));
        struct timespec mtm = { 0, 0 };
        int has_mtm = mi >= 0 && AAHeaderGetFieldTimespec(x->cur, (uint32_t)mi, &mtm) == 0;
        int has_mode = header_uint(x->cur, "MOD", &mode);
        if (typ == 'D') {
            if (x->ndirs == x->capdirs) {
                size_t cap = x->capdirs ? x->capdirs * 2 : 16;
                struct dirattr *d = realloc(x->dirs, cap * sizeof *d);
                if (d) { x->dirs = d; x->capdirs = cap; }
            }
            if (x->ndirs < x->capdirs)
                x->dirs[x->ndirs++] = (struct dirattr){ strdup(x->full), mode, has_mode, mtm, has_mtm };
        } else if (typ != 'L') {
            message(x->msg, x->msg_data, AA_ENTRY_MESSAGE_EXTRACT_ATTRIBUTES, x->path);
            if (has_mode) chmod(x->full, (mode_t)(mode & 07777));
            if (has_mtm) set_times(x->full, &mtm);
        }
        r = message(x->msg, x->msg_data, AA_ENTRY_MESSAGE_EXTRACT_END, x->path) < 0 ? -1 : 0;
    }
    AAHeaderDestroy(x->cur);
    x->cur = NULL; x->xat_size = 0;
    return r;
}
static int ext_fail(struct extractor *x) {
    int r = message(x->msg, x->msg_data, AA_ENTRY_MESSAGE_EXTRACT_FAIL, x->path);
    x->skipping = 1;
    return r < 0 || !(x->flags & AA_FLAG_IGNORE_EPERM) ? -1 : 0;
}
static int ext_header(void *a, AAHeader h) {
    struct extractor *x = a;
    if (ext_finish(x) < 0) return -1;
    x->cur = AAHeaderClone(h);
    if (!x->cur) return -1;
    x->active = 1; x->skipping = 0; x->fd = -1;
    header_path(h, x->path, sizeof x->path);
    uint64_t typ = 'F';
    header_uint(h, "TYP", &typ);
    if (typ == 'M') { x->skipping = 1; return 0; }           /* metadata entries make no file */
    if (!safe_path(x->path)) { errno = EPERM; return ext_fail(x); }
    int b = message_with(x->msg, x->msg_data, AA_ENTRY_MESSAGE_EXTRACT_BEGIN, x->path, h);
    if (b < 0) return -1;
    if (b > 0) { x->skipping = 1; return 0; }
    snprintf(x->full, sizeof x->full, x->path[0] ? "%s/%s" : "%s", x->dir, x->path);
    make_parents(x->full);
    switch (typ) {
    case 'D':
        if (mkdir(x->full, 0755) != 0 && errno != EEXIST) return ext_fail(x);
        break;
    case 'L': {
        char target[1024];
        size_t len = 0;
        int i = AAHeaderGetKeyIndex(h, aa_key("LNK"));
        if (i < 0 || AAHeaderGetFieldString(h, (uint32_t)i, sizeof target, target, &len) != 0) return ext_fail(x);
        unlink(x->full);
        if (symlink(target, x->full) != 0) return ext_fail(x);
        break;
    }
    case 'F':
        unlink(x->full);
        x->fd = open(x->full, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (x->fd < 0) return ext_fail(x);
        break;
    default:                                                  /* FIFOs, devices, sockets, …: not made in an app's container */
        x->skipping = 1;
        break;
    }
    return 0;
}
static int ext_blob(void *a, AAFieldKey k, const void *buf, size_t n) {
    struct extractor *x = a;
    if (!x->active || x->skipping) return 0;
    if (aa_key_is(k, "DAT") && x->fd >= 0) {
        for (const uint8_t *p = buf; n; ) {
            ssize_t w = write(x->fd, p, n);
            if (w < 0) { if (errno == EINTR) continue; return ext_fail(x); }
            p += w; n -= (size_t)w;
        }
    } else if (aa_key_is(k, "XAT")) {
        if (x->xat_size + n > x->xat_cap) {
            size_t cap = (x->xat_size + n) * 2;
            uint8_t *d = realloc(x->xat, cap);
            if (!d) return -1;
            x->xat = d; x->xat_cap = cap;
        }
        memcpy(x->xat + x->xat_size, buf, n);
        x->xat_size += n;
    }
    return 0;                                                 /* other blobs (ACL, …) are not applied */
}
static int ext_close(void *a) {
    struct extractor *x = a;
    int r = ext_finish(x);
    for (size_t i = x->ndirs; i-- > 0; ) {                  /* deepest last-made first, as their children are done */
        struct dirattr *d = &x->dirs[i];
        if (d->has_mode) chmod(d->path, (mode_t)(d->mode & 07777));
        if (d->has_mtm) set_times(d->path, &d->mtm);
        free(d->path);
    }
    free(x->dirs); free(x->xat); free(x->dir); free(x);
    return r;
}
AAArchiveStream AAExtractArchiveOutputStreamOpen(const char *dir, void *msg_data, AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)n_threads;
    struct extractor *x = calloc(1, sizeof *x);
    AAArchiveStream s = astream_new();
    if (!x || !s || !(x->dir = strdup(dir))) { free(x); free(s); return NULL; }
    size_t len = strlen(x->dir);
    while (len > 1 && x->dir[len - 1] == '/') x->dir[--len] = 0;
    mkdir(x->dir, 0755);
    x->msg_data = msg_data; x->msg = msg; x->flags = flags; x->fd = -1;
    s->data = x; s->write_header = ext_header; s->write_blob = ext_blob; s->close = ext_close;
    return s;
}

/* ---- conversion: fields removed and added on the way to another stream. An entry is held until its blobs are in
 * (sizes and hashes of DAT go in its header), then passed on ---- */
struct blobbuf { AAFieldKey key; uint8_t *data; size_t size, cap; };
struct converter {
    AAArchiveStream out; AAFieldKeySet insert, remove; void *msg_data; AAEntryMessageProc msg;
    AAHeader cur; int excluded;
    struct blobbuf *blobs; uint32_t nblobs;
};
static void hash_buf(AAHashFunction fn, const uint8_t *d, size_t n, uint8_t *out) {
    switch (fn) {
    case AA_HASH_FUNCTION_CRC32: {
        uLong c = crc32(crc32(0, Z_NULL, 0), d, (uInt)n);
        out[0] = (uint8_t)(c >> 24); out[1] = (uint8_t)(c >> 16); out[2] = (uint8_t)(c >> 8); out[3] = (uint8_t)c;
        break;
    }
    case AA_HASH_FUNCTION_SHA1: CC_SHA1(d, (CC_LONG)n, out); break;
    case AA_HASH_FUNCTION_SHA256: CC_SHA256(d, (CC_LONG)n, out); break;
    case AA_HASH_FUNCTION_SHA384: CC_SHA384(d, (CC_LONG)n, out); break;
    default: CC_SHA512(d, (CC_LONG)n, out); break;
    }
}
static void conv_reset(struct converter *c) {
    for (uint32_t i = 0; i < c->nblobs; i++) free(c->blobs[i].data);
    free(c->blobs);
    c->blobs = NULL; c->nblobs = 0;
    AAHeaderDestroy(c->cur);
    c->cur = NULL;
}
static int conv_flush(struct converter *c) {
    if (!c->cur) return 0;
    int r = 0;
    if (!c->excluded) {
        const uint8_t *dat = NULL; size_t dat_size = 0; int has_dat = 0;
        for (uint32_t i = 0; i < c->nblobs; i++)
            if (aa_key_is(c->blobs[i].key, "DAT")) { dat = c->blobs[i].data; dat_size = c->blobs[i].size; has_dat = 1; }
        if (c->insert && has_dat) {
            static const struct { const char *key; AAHashFunction fn; } hashes[] = {
                { "CKS", AA_HASH_FUNCTION_CRC32 }, { "SH1", AA_HASH_FUNCTION_SHA1 }, { "SH2", AA_HASH_FUNCTION_SHA256 },
                { "SH3", AA_HASH_FUNCTION_SHA384 }, { "SH5", AA_HASH_FUNCTION_SHA512 },
            };
            if (AAFieldKeySetContainsKey(c->insert, aa_key("SIZ")) > 0)
                AAHeaderSetFieldUInt(c->cur, AA_HEADER_FIELD_INDEX_BY_KEY, aa_key("SIZ"), dat_size);
            for (size_t i = 0; i < sizeof hashes / sizeof *hashes; i++)
                if (AAFieldKeySetContainsKey(c->insert, aa_key(hashes[i].key)) > 0) {
                    uint8_t digest[AA_HASH_MAX_SIZE];
                    hash_buf(hashes[i].fn, dat ? dat : (const uint8_t *)"", dat_size, digest);
                    AAHeaderSetFieldHash(c->cur, AA_HEADER_FIELD_INDEX_BY_KEY, aa_key(hashes[i].key), hashes[i].fn, digest);
                }
        }
        r = AAArchiveStreamWriteHeader(c->out, c->cur);
        uint32_t n = AAHeaderGetFieldCount(c->cur);
        for (uint32_t i = 0; r == 0 && i < n; i++) {     /* the blobs left, in the header's order */
            if (AAHeaderGetFieldType(c->cur, i) != AA_FIELD_TYPE_BLOB) continue;
            AAFieldKey k = AAHeaderGetFieldKey(c->cur, i);
            for (uint32_t j = 0; j < c->nblobs; j++)
                if (c->blobs[j].key.ikey == k.ikey && c->blobs[j].size)
                    r = AAArchiveStreamWriteBlob(c->out, k, c->blobs[j].data, c->blobs[j].size);
        }
    }
    conv_reset(c);
    return r;
}
static int conv_header(void *a, AAHeader h) {
    struct converter *c = a;
    if (conv_flush(c) < 0) return -1;
    char path[1024];
    header_path(h, path, sizeof path);
    int m = message_with(c->msg, c->msg_data, AA_ENTRY_MESSAGE_CONVERT_EXCLUDE, path, h);
    if (m < 0) return -1;
    c->excluded = m > 0;
    c->cur = AAHeaderClone(h);
    if (!c->cur) return -1;
    if (c->remove)
        for (uint32_t i = AAHeaderGetFieldCount(c->cur); i-- > 0; )
            if (AAFieldKeySetContainsKey(c->remove, AAHeaderGetFieldKey(c->cur, i)) > 0) AAHeaderRemoveField(c->cur, i);
    return 0;
}
static int conv_blob(void *a, AAFieldKey k, const void *buf, size_t n) {
    struct converter *c = a;
    if (!c->cur) return -1;
    struct blobbuf *b = NULL;
    for (uint32_t i = 0; i < c->nblobs; i++) if (c->blobs[i].key.ikey == k.ikey) b = &c->blobs[i];
    if (!b) {
        struct blobbuf *nb = realloc(c->blobs, (c->nblobs + 1) * sizeof *nb);
        if (!nb) return -1;
        c->blobs = nb;
        b = &c->blobs[c->nblobs++];
        *b = (struct blobbuf){ k, NULL, 0, 0 };
    }
    if (b->size + n > b->cap) {
        size_t cap = (b->size + n) * 2;
        uint8_t *d = realloc(b->data, cap);
        if (!d) return -1;
        b->data = d; b->cap = cap;
    }
    memcpy(b->data + b->size, buf, n);
    b->size += n;
    return 0;
}
static int conv_close(void *a) {
    struct converter *c = a;
    int r = conv_flush(c);
    AAFieldKeySetDestroy(c->insert); AAFieldKeySetDestroy(c->remove);
    free(c);
    return r;
}
AAArchiveStream AAConvertArchiveOutputStreamOpen(AAArchiveStream out, AAFieldKeySet insert, AAFieldKeySet remove, void *msg_data,
                                                 AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)flags; (void)n_threads;
    struct converter *c = calloc(1, sizeof *c);
    AAArchiveStream s = astream_new();
    if (!c || !s) { free(c); free(s); return NULL; }
    c->out = out; c->msg_data = msg_data; c->msg = msg;
    c->insert = insert ? AAFieldKeySetClone(insert) : NULL;
    c->remove = remove ? AAFieldKeySetClone(remove) : NULL;
    s->data = c; s->write_header = conv_header; s->write_blob = conv_blob; s->close = conv_close;
    return s;
}

/* ---- archiving files, and copying archives ---- */
int AAArchiveStreamWritePathList(AAArchiveStream s, AAPathList list, AAFieldKeySet keys, const char *dir, void *msg_data,
                                 AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)n_threads;
    char path[1024], full[2048];
    uint8_t buf[65536];
    for (uint64_t node = AAPathListNodeFirst(list); node != AA_PATH_LIST_NODE_END; node = AAPathListNodeNext(list, node)) {
        if (AAPathListNodeGetPath(list, node, sizeof path, path, NULL) != 0) return -1;
        if (message(msg, msg_data, AA_ENTRY_MESSAGE_ENCODE_SCANNING, path) < 0) return -1;
        AAHeader h = AAHeaderCreateWithPath(keys, dir, path, flags);
        if (!h) {
            if (message(msg, msg_data, AA_ENTRY_MESSAGE_SEARCH_FAIL, path) < 0 || !(flags & AA_FLAG_IGNORE_EPERM)) return -1;
            continue;
        }
        int m = message_with(msg, msg_data, AA_ENTRY_MESSAGE_ENCODE_WRITING, path, h);
        if (m != 0) { AAHeaderDestroy(h); if (m < 0) return -1; continue; }
        int r = AAArchiveStreamWriteHeader(s, h);
        snprintf(full, sizeof full, path[0] ? "%s/%s" : "%s", dir, path);
        uint32_t n = AAHeaderGetFieldCount(h);
        for (uint32_t i = 0; r == 0 && i < n; i++) {
            if (AAHeaderGetFieldType(h, i) != AA_FIELD_TYPE_BLOB) continue;
            AAFieldKey k = AAHeaderGetFieldKey(h, i);
            uint64_t size, off;
            AAHeaderGetFieldBlob(h, i, &size, &off);
            if (aa_key_is(k, "DAT")) {
                int fd = open(full, O_RDONLY);
                if (fd < 0) { r = -1; break; }
                while (r == 0 && size) {
                    ssize_t got = read(fd, buf, size < sizeof buf ? (size_t)size : sizeof buf);
                    if (got <= 0) { r = -1; break; }
                    r = AAArchiveStreamWriteBlob(s, k, buf, (size_t)got);
                    size -= (uint64_t)got;
                }
                close(fd);
            } else if (aa_key_is(k, "XAT")) {
                AAEntryXATBlob x = AAEntryXATBlobCreateWithPath(dir, path, flags);
                if (!x || AAEntryXATBlobGetEncodedSize(x) != size) r = -1;
                else r = AAArchiveStreamWriteBlob(s, k, AAEntryXATBlobGetEncodedData(x), (size_t)size);
                AAEntryXATBlobDestroy(x);
            } else {
                r = -1;
            }
        }
        AAHeaderDestroy(h);
        if (r < 0) return -1;
    }
    return 0;
}
ssize_t AAArchiveStreamProcess(AAArchiveStream in, AAArchiveStream out, void *msg_data, AAEntryMessageProc msg, AAFlagSet flags, int n_threads) {
    (void)flags; (void)n_threads;
    ssize_t count = 0;
    uint8_t buf[65536];
    char path[1024];
    for (;;) {
        AAHeader h = NULL;
        int r = AAArchiveStreamReadHeader(in, &h);
        if (r == 0) return count;
        if (r < 0) return -1;
        header_path(h, path, sizeof path);
        int m = message_with(msg, msg_data, AA_ENTRY_MESSAGE_PROCESS_EXCLUDE, path, h);
        if (m < 0) return -1;
        if (m > 0) continue;                                 /* the decoder skips the blobs not read */
        if (AAArchiveStreamWriteHeader(out, h) < 0) return -1;
        uint32_t n = AAHeaderGetFieldCount(h);
        for (uint32_t i = 0; i < n; i++) {
            if (AAHeaderGetFieldType(h, i) != AA_FIELD_TYPE_BLOB) continue;
            AAFieldKey k = AAHeaderGetFieldKey(h, i);
            uint64_t size, off;
            AAHeaderGetFieldBlob(h, i, &size, &off);
            while (size) {
                size_t c = size < sizeof buf ? (size_t)size : sizeof buf;
                if (AAArchiveStreamReadBlob(in, k, buf, c) < 0 || AAArchiveStreamWriteBlob(out, k, buf, c) < 0) return -1;
                size -= c;
            }
        }
        count++;
    }
}

/* ---- path lists ---- */
struct AAPathList_impl { char **paths; uint64_t count, cap; };
static int list_add(AAPathList l, const char *p) {
    if (l->count == l->cap) {
        uint64_t cap = l->cap ? l->cap * 2 : 64;
        char **d = realloc(l->paths, cap * sizeof *d);
        if (!d) return -1;
        l->paths = d; l->cap = cap;
    }
    return (l->paths[l->count] = strdup(p)) ? (int)(l->count++, 0) : -1;
}
static int cmp_names(const void *a, const void *b) { return strcmp(*(char *const *)a, *(char *const *)b); }
/* adds rel (under dir) and, for a directory, its contents in name order; -1 when the callback cancels */
static int walk(AAPathList l, const char *dir, const char *rel, void *msg_data, AAEntryMessageProc msg) {
    char full[2048];
    snprintf(full, sizeof full, rel[0] ? "%s/%s" : "%s", dir, rel);
    struct stat st;
    if (lstat(full, &st) != 0) return message(msg, msg_data, AA_ENTRY_MESSAGE_SEARCH_FAIL, rel) < 0 ? -1 : 0;
    int m = message(msg, msg_data, AA_ENTRY_MESSAGE_SEARCH_EXCLUDE, rel);
    if (m < 0) return -1;
    if (m > 0) return 0;
    if (list_add(l, rel) < 0) return -1;
    if (!S_ISDIR(st.st_mode)) return 0;
    m = message(msg, msg_data, AA_ENTRY_MESSAGE_SEARCH_PRUNE_DIR, rel);
    if (m < 0) return -1;
    if (m > 0) return 0;
    DIR *d = opendir(full);
    if (!d) return 0;
    char **names = NULL;
    size_t n = 0, cap = 0;
    struct dirent *e;
    while ((e = readdir(d))) {
        if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
        if (n == cap) { cap = cap ? cap * 2 : 32; char **nn = realloc(names, cap * sizeof *nn); if (!nn) break; names = nn; }
        names[n++] = strdup(e->d_name);
    }
    closedir(d);
    qsort(names, n, sizeof *names, cmp_names);
    int r = 0;
    for (size_t i = 0; i < n; i++) {
        char child[1024];
        snprintf(child, sizeof child, rel[0] ? "%s/%s" : "%s%s", rel, names[i]);
        if (r == 0) r = walk(l, dir, child, msg_data, msg);
        free(names[i]);
    }
    free(names);
    return r;
}
AAPathList AAPathListCreateWithDirectoryContents(const char *dir, const char *path, void *msg_data, AAEntryMessageProc msg,
                                                 AAFlagSet flags, int n_threads) {
    (void)flags; (void)n_threads;
    AAPathList l = calloc(1, sizeof *l);
    if (!l) return NULL;
    if (walk(l, dir, path ? path : "", msg_data, msg) < 0) { AAPathListDestroy(l); return NULL; }
    return l;
}
AAPathList AAPathListCreateWithPath(const char *dir, const char *path) {
    (void)dir;
    AAPathList l = calloc(1, sizeof *l);
    if (l && list_add(l, path) < 0) { AAPathListDestroy(l); return NULL; }
    return l;
}
void AAPathListDestroy(AAPathList l) {
    if (!l) return;
    for (uint64_t i = 0; i < l->count; i++) free(l->paths[i]);
    free(l->paths); free(l);
}
uint64_t AAPathListNodeFirst(AAPathList l) { return l->count ? 0 : AA_PATH_LIST_NODE_END; }
uint64_t AAPathListNodeNext(AAPathList l, uint64_t node) { return node + 1 < l->count ? node + 1 : AA_PATH_LIST_NODE_END; }
int AAPathListNodeGetPath(AAPathList l, uint64_t node, size_t cap, char *path, size_t *len) {
    if (node >= l->count) return -1;
    size_t n = strlen(l->paths[node]);
    if (len) *len = n;
    if (path) {
        if (cap <= n) return -1;
        memcpy(path, l->paths[node], n + 1);
    }
    return 0;
}
