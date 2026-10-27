/* isim AppleArchive: byte streams (adapted). Files and temporary files over libSystem; custom streams over callbacks; a
 * shared buffer pipe (a bounded buffer between a writer and a reader thread); compression in AppleArchive's block
 * format: "pbz" + the algorithm's letter, the block size (big-endian uint64), then per block its raw and compressed
 * sizes (big-endian uint64) and the bytes (stored raw when compression does not shrink them), compressed with
 * libcompression. Self-authored. */
#include "AAInternal.h"
#include <compression.h>
#include <errno.h>
#include <fcntl.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

struct AAByteStream_impl {
    void *data;
    AAByteStreamCloseProc close;
    AAByteStreamReadProc read;
    AAByteStreamPReadProc pread;
    AAByteStreamWriteProc write;
    AAByteStreamPWriteProc pwrite;
    AAByteStreamSeekProc seek;
    AAByteStreamCancelProc cancel;
    int cancelled;
};

static AAByteStream stream_new(void) { return calloc(1, sizeof(struct AAByteStream_impl)); }

/* ---- the stream functions ---- */
ssize_t AAByteStreamWrite(AAByteStream s, const void *buf, size_t n) { return s->cancelled || !s->write ? -1 : s->write(s->data, buf, n); }
ssize_t AAByteStreamPWrite(AAByteStream s, const void *buf, size_t n, off_t o) { return s->cancelled || !s->pwrite ? -1 : s->pwrite(s->data, buf, n, o); }
ssize_t AAByteStreamRead(AAByteStream s, void *buf, size_t n) { return s->cancelled || !s->read ? -1 : s->read(s->data, buf, n); }
ssize_t AAByteStreamPRead(AAByteStream s, void *buf, size_t n, off_t o) { return s->cancelled || !s->pread ? -1 : s->pread(s->data, buf, n, o); }
off_t AAByteStreamSeek(AAByteStream s, off_t o, int whence) { return s->cancelled || !s->seek ? -1 : s->seek(s->data, o, whence); }
void AAByteStreamCancel(AAByteStream s) { s->cancelled = 1; if (s->cancel) s->cancel(s->data); }
int AAByteStreamClose(AAByteStream s) {
    if (!s) return 0;
    int r = s->close ? s->close(s->data) : 0;
    free(s);
    return r < 0 ? -1 : 0;
}
off_t AAByteStreamProcess(AAByteStream in, AAByteStream out) {
    char buf[65536];
    off_t total = 0;
    for (;;) {
        ssize_t n = AAByteStreamRead(in, buf, sizeof buf);
        if (n < 0) return -1;
        if (n == 0) return total;
        if (aa_write_all(out, buf, (size_t)n) < 0) return -1;
        total += n;
    }
}
/* writes everything (a stream may write less than asked) */
int aa_write_all(AAByteStream s, const void *buf, size_t n) {
    const char *p = buf;
    while (n) {
        ssize_t w = AAByteStreamWrite(s, p, n);
        if (w <= 0) return -1;
        p += w; n -= (size_t)w;
    }
    return 0;
}
/* reads exactly n bytes: n, fewer at the end of the stream, or -1 */
ssize_t aa_read_all(AAByteStream s, void *buf, size_t n) {
    char *p = buf;
    size_t got = 0;
    while (got < n) {
        ssize_t r = AAByteStreamRead(s, p + got, n - got);
        if (r < 0) return -1;
        if (r == 0) break;
        got += (size_t)r;
    }
    return (ssize_t)got;
}

/* ---- custom streams ---- */
AAByteStream AACustomByteStreamOpen(void) { return stream_new(); }
void AACustomByteStreamSetData(AAByteStream s, void *data) { s->data = data; }
void AACustomByteStreamSetCloseProc(AAByteStream s, AAByteStreamCloseProc p) { s->close = p; }
void AACustomByteStreamSetReadProc(AAByteStream s, AAByteStreamReadProc p) { s->read = p; }
void AACustomByteStreamSetPReadProc(AAByteStream s, AAByteStreamPReadProc p) { s->pread = p; }
void AACustomByteStreamSetWriteProc(AAByteStream s, AAByteStreamWriteProc p) { s->write = p; }
void AACustomByteStreamSetPWriteProc(AAByteStream s, AAByteStreamPWriteProc p) { s->pwrite = p; }
void AACustomByteStreamSetSeekProc(AAByteStream s, AAByteStreamSeekProc p) { s->seek = p; }
void AACustomByteStreamSetCancelProc(AAByteStream s, AAByteStreamCancelProc p) { s->cancel = p; }

/* ---- files ---- */
struct file_stream { int fd, owned; };
static ssize_t f_read(void *a, void *b, size_t n) { return read(((struct file_stream *)a)->fd, b, n); }
static ssize_t f_pread(void *a, void *b, size_t n, off_t o) { return pread(((struct file_stream *)a)->fd, b, n, o); }
static ssize_t f_write(void *a, const void *b, size_t n) { return write(((struct file_stream *)a)->fd, b, n); }
static ssize_t f_pwrite(void *a, const void *b, size_t n, off_t o) { return pwrite(((struct file_stream *)a)->fd, b, n, o); }
static off_t f_seek(void *a, off_t o, int w) { return lseek(((struct file_stream *)a)->fd, o, w); }
static int f_close(void *a) {
    struct file_stream *f = a;
    int r = f->owned ? close(f->fd) : 0;
    free(f);
    return r;
}
static AAByteStream file_stream(int fd, int owned) {
    AAByteStream s = stream_new();
    struct file_stream *f = calloc(1, sizeof *f);
    if (!s || !f) { free(s); free(f); return NULL; }
    f->fd = fd; f->owned = owned;
    s->data = f; s->read = f_read; s->pread = f_pread; s->write = f_write; s->pwrite = f_pwrite; s->seek = f_seek; s->close = f_close;
    return s;
}
AAByteStream AAFileStreamOpenWithFD(int fd, int automatic_close) { return fd < 0 ? NULL : file_stream(fd, automatic_close); }
AAByteStream AAFileStreamOpenWithPath(const char *path, int flags, mode_t mode) {
    int fd = open(path, flags, mode);
    return fd < 0 ? NULL : file_stream(fd, 1);
}
/* a file in the temporary directory, removed at once (it lives while the stream is open) */
AAByteStream AATempFileStreamOpen(void) {
    char path[1100];
    const char *t = getenv("TMPDIR");
    snprintf(path, sizeof path, "%s/aa-temp-XXXXXX", t && *t ? t : "/tmp");
    int fd = mkstemp(path);
    if (fd < 0) return NULL;
    unlink(path);
    return file_stream(fd, 1);
}

/* ---- shared buffer pipe: the output stream's writes become the input stream's reads ---- */
struct pipe_state {
    pthread_mutex_t lock;
    pthread_cond_t cond;
    unsigned char *buf;
    size_t cap, head, count;
    int writer_closed, reader_closed, cancelled, refs;
};
static void pipe_unref(struct pipe_state *p) {
    pthread_mutex_lock(&p->lock);
    int last = --p->refs == 0;
    pthread_mutex_unlock(&p->lock);
    if (!last) return;
    pthread_mutex_destroy(&p->lock); pthread_cond_destroy(&p->cond);
    free(p->buf); free(p);
}
static ssize_t p_write(void *a, const void *b, size_t n) {
    struct pipe_state *p = a;
    const unsigned char *src = b;
    size_t done = 0;
    pthread_mutex_lock(&p->lock);
    while (done < n) {
        while (p->count == p->cap && !p->reader_closed && !p->cancelled) pthread_cond_wait(&p->cond, &p->lock);
        if (p->reader_closed || p->cancelled) { pthread_mutex_unlock(&p->lock); return -1; }
        size_t tail = (p->head + p->count) % p->cap, room = p->cap - p->count, k = n - done;
        if (k > room) k = room;
        if (k > p->cap - tail) k = p->cap - tail;
        memcpy(p->buf + tail, src + done, k);
        p->count += k; done += k;
        pthread_cond_broadcast(&p->cond);
    }
    pthread_mutex_unlock(&p->lock);
    return (ssize_t)n;
}
static ssize_t p_read(void *a, void *b, size_t n) {
    struct pipe_state *p = a;
    pthread_mutex_lock(&p->lock);
    while (!p->count && !p->writer_closed && !p->cancelled) pthread_cond_wait(&p->cond, &p->lock);
    if (p->cancelled) { pthread_mutex_unlock(&p->lock); return -1; }
    size_t k = n < p->count ? n : p->count;
    if (k > p->cap - p->head) k = p->cap - p->head;
    memcpy(b, p->buf + p->head, k);
    p->head = (p->head + k) % p->cap; p->count -= k;
    pthread_cond_broadcast(&p->cond);
    pthread_mutex_unlock(&p->lock);
    return (ssize_t)k;
}
static void p_cancel(void *a) {
    struct pipe_state *p = a;
    pthread_mutex_lock(&p->lock); p->cancelled = 1; pthread_cond_broadcast(&p->cond); pthread_mutex_unlock(&p->lock);
}
static int p_close_writer(void *a) {
    struct pipe_state *p = a;
    pthread_mutex_lock(&p->lock); p->writer_closed = 1; pthread_cond_broadcast(&p->cond); pthread_mutex_unlock(&p->lock);
    pipe_unref(p);
    return 0;
}
static int p_close_reader(void *a) {
    struct pipe_state *p = a;
    pthread_mutex_lock(&p->lock); p->reader_closed = 1; pthread_cond_broadcast(&p->cond); pthread_mutex_unlock(&p->lock);
    pipe_unref(p);
    return 0;
}
int AASharedBufferPipeOpen(AAByteStream *ostream, AAByteStream *istream, size_t capacity) {
    struct pipe_state *p = calloc(1, sizeof *p);
    AAByteStream o = stream_new(), i = stream_new();
    if (!p || !o || !i || !(p->buf = malloc(capacity ? capacity : 1 << 20))) { free(p ? p->buf : NULL); free(p); free(o); free(i); return -1; }
    p->cap = capacity ? capacity : 1 << 20; p->refs = 2;
    pthread_mutex_init(&p->lock, NULL); pthread_cond_init(&p->cond, NULL);
    o->data = p; o->write = p_write; o->cancel = p_cancel; o->close = p_close_writer;
    i->data = p; i->read = p_read; i->cancel = p_cancel; i->close = p_close_reader;
    *ostream = o; *istream = i;
    return 0;
}

/* ---- compression ---- */
/* libcompression's algorithm of an AppleArchive one (AppleArchive's ZLIB is zlib at level 5) */
static compression_algorithm lib_algo(AACompressionAlgorithm a) {
    return a == AA_COMPRESSION_ALGORITHM_ZLIB ? COMPRESSION_ZLIB : (compression_algorithm)a;
}
static char algo_letter(AACompressionAlgorithm a) {
    switch (a) {
    case AA_COMPRESSION_ALGORITHM_LZFSE: return 'e';
    case AA_COMPRESSION_ALGORITHM_LZ4: return '4';
    case AA_COMPRESSION_ALGORITHM_LZMA: return 'x';
    case AA_COMPRESSION_ALGORITHM_ZLIB: return 'z';
    case AA_COMPRESSION_ALGORITHM_LZBITMAP: return 'b';
    case AA_COMPRESSION_ALGORITHM_NONE: return '-';
    default: return 0;
    }
}
static AACompressionAlgorithm algo_of_letter(char c) {
    switch (c) {
    case 'e': return AA_COMPRESSION_ALGORITHM_LZFSE;
    case '4': return AA_COMPRESSION_ALGORITHM_LZ4;
    case 'x': return AA_COMPRESSION_ALGORITHM_LZMA;
    case 'z': return AA_COMPRESSION_ALGORITHM_ZLIB;
    case 'b': return AA_COMPRESSION_ALGORITHM_LZBITMAP;
    case '-': return AA_COMPRESSION_ALGORITHM_NONE;
    default: return (AACompressionAlgorithm)-1;
    }
}
static void put_be64(unsigned char *p, uint64_t v) { for (int i = 7; i >= 0; i--) { p[i] = (unsigned char)v; v >>= 8; } }
static uint64_t get_be64(const unsigned char *p) { uint64_t v = 0; for (int i = 0; i < 8; i++) v = (v << 8) | p[i]; return v; }

struct compressor {
    AAByteStream out;
    AACompressionAlgorithm algo;
    unsigned char *block, *packed;
    size_t block_size, used;
    int failed, wrote_header;
};
static int flush_block(struct compressor *c) {
    if (!c->wrote_header) {
        unsigned char h[12] = { 'p', 'b', 'z', (unsigned char)algo_letter(c->algo) };
        put_be64(h + 4, c->block_size);
        if (aa_write_all(c->out, h, sizeof h) < 0) return -1;
        c->wrote_header = 1;
    }
    if (!c->used) return 0;
    size_t packed = 0;
    if (c->algo != AA_COMPRESSION_ALGORITHM_NONE)
        packed = compression_encode_buffer(c->packed, c->block_size, c->block, c->used, NULL, lib_algo(c->algo));
    const unsigned char *bytes = packed && packed < c->used ? c->packed : c->block;
    size_t size = packed && packed < c->used ? packed : c->used;      /* (equal sizes: stored raw) */
    unsigned char sizes[16];
    put_be64(sizes, c->used); put_be64(sizes + 8, size);
    if (aa_write_all(c->out, sizes, 16) < 0 || aa_write_all(c->out, bytes, size) < 0) return -1;
    c->used = 0;
    return 0;
}
static ssize_t c_write(void *a, const void *b, size_t n) {
    struct compressor *c = a;
    const unsigned char *src = b;
    size_t done = 0;
    while (done < n) {
        size_t k = c->block_size - c->used;
        if (k > n - done) k = n - done;
        memcpy(c->block + c->used, src + done, k);
        c->used += k; done += k;
        if (c->used == c->block_size && flush_block(c) < 0) { c->failed = 1; return -1; }
    }
    return (ssize_t)n;
}
static int c_close(void *a) {
    struct compressor *c = a;
    int r = c->failed ? -1 : flush_block(c);
    free(c->block); free(c->packed); free(c);
    return r;
}
static void c_cancel(void *a) { struct compressor *c = a; c->failed = 1; AAByteStreamCancel(c->out); }
static AAByteStream compressor_open(AAByteStream out, AACompressionAlgorithm algo, size_t block_size, int wrote_header) {
    if (!algo_letter(algo)) { errno = EINVAL; return NULL; }
    struct compressor *c = calloc(1, sizeof *c);
    AAByteStream s = stream_new();
    if (!c || !s) { free(c); free(s); return NULL; }
    c->out = out; c->algo = algo; c->block_size = block_size ? block_size : 4 << 20; c->wrote_header = wrote_header;
    c->block = malloc(c->block_size); c->packed = malloc(c->block_size);
    if (!c->block || !c->packed) { free(c->block); free(c->packed); free(c); free(s); return NULL; }
    s->data = c; s->write = c_write; s->close = c_close; s->cancel = c_cancel;
    return s;
}
AAByteStream AACompressionOutputStreamOpen(AAByteStream out, AACompressionAlgorithm algo, size_t block_size, AAFlagSet flags, int n_threads) {
    return compressor_open(out, algo, block_size, 0);
}
/* appends blocks to an existing compressed stream: reads its header, then seeks to its end */
AAByteStream AACompressionOutputStreamOpenExisting(AAByteStream out, AAFlagSet flags, int n_threads) {
    unsigned char h[12];
    if (AAByteStreamPRead(out, h, sizeof h, 0) != (ssize_t)sizeof h || memcmp(h, "pbz", 3)) { errno = EINVAL; return NULL; }
    AACompressionAlgorithm algo = algo_of_letter((char)h[3]);
    if (algo == (AACompressionAlgorithm)-1 || AAByteStreamSeek(out, 0, SEEK_END) < 0) { errno = EINVAL; return NULL; }
    return compressor_open(out, algo, (size_t)get_be64(h + 4), 1);
}

struct decompressor {
    AAByteStream in;
    AACompressionAlgorithm algo;
    size_t block_size;
    unsigned char *block, *packed;
    size_t avail, pos;
    int eof, failed, random;
    off_t offset;                                  /* random access: the uncompressed position */
    /* random access: the blocks' raw offsets and their places in the compressed stream */
    uint64_t *raw_at, *packed_at, *raw_size, *packed_size;
    size_t nblocks;
    long cached;
};
static int read_header(struct decompressor *d) {
    unsigned char h[12];
    if (aa_read_all(d->in, h, sizeof h) != (ssize_t)sizeof h || memcmp(h, "pbz", 3)) return -1;
    d->algo = algo_of_letter((char)h[3]);
    d->block_size = (size_t)get_be64(h + 4);
    if (d->algo == (AACompressionAlgorithm)-1 || !d->block_size || d->block_size > (1u << 30)) return -1;
    d->block = malloc(d->block_size); d->packed = malloc(d->block_size);
    return d->block && d->packed ? 0 : -1;
}
static int decode_block(struct decompressor *d, const unsigned char *packed, size_t psize, size_t rsize) {
    if (rsize > d->block_size || psize > d->block_size) return -1;
    if (psize == rsize) memcpy(d->block, packed, rsize);
    else if (compression_decode_buffer(d->block, rsize, packed, psize, NULL, lib_algo(d->algo)) != rsize) return -1;
    d->avail = rsize; d->pos = 0;
    return 0;
}
static int next_block(struct decompressor *d) {
    unsigned char sizes[16];
    ssize_t r = aa_read_all(d->in, sizes, 16);
    if (r == 0) { d->eof = 1; return 0; }
    if (r != 16) return -1;
    uint64_t rsize = get_be64(sizes), psize = get_be64(sizes + 8);
    if (psize > d->block_size || aa_read_all(d->in, d->packed, (size_t)psize) != (ssize_t)psize) return -1;
    return decode_block(d, d->packed, (size_t)psize, (size_t)rsize);
}
static ssize_t d_read(void *a, void *b, size_t n) {
    struct decompressor *d = a;
    if (d->failed) return -1;
    while (d->pos == d->avail && !d->eof)
        if (next_block(d) < 0) { d->failed = 1; return -1; }
    size_t k = d->avail - d->pos;
    if (k > n) k = n;
    memcpy(b, d->block + d->pos, k);
    d->pos += k;
    return (ssize_t)k;
}
static int d_close(void *a) {
    struct decompressor *d = a;
    free(d->block); free(d->packed); free(d->raw_at); free(d->packed_at); free(d->raw_size); free(d->packed_size); free(d);
    return 0;
}
static void d_cancel(void *a) { struct decompressor *d = a; d->failed = 1; AAByteStreamCancel(d->in); }
AAByteStream AADecompressionInputStreamOpen(AAByteStream in, AAFlagSet flags, int n_threads) {
    struct decompressor *d = calloc(1, sizeof *d);
    AAByteStream s = stream_new();
    if (!d || !s || (d->in = in, read_header(d) < 0)) { if (d) d_close(d); free(s); errno = EINVAL; return NULL; }
    s->data = d; s->read = d_read; s->close = d_close; s->cancel = d_cancel;
    return s;
}
/* random access: an index of the blocks (read once with PRead), then blocks decoded on demand (the last one cached) */
static ssize_t r_pread(void *a, void *b, size_t n, off_t off) {
    struct decompressor *d = a;
    size_t done = 0;
    unsigned char *dst = b;
    while (done < n) {
        uint64_t at = (uint64_t)off + done;
        size_t i = 0;
        while (i < d->nblocks && at >= d->raw_at[i] + d->raw_size[i]) i++;
        if (i == d->nblocks) break;
        if (d->cached != (long)i) {
            if (AAByteStreamPRead(d->in, d->packed, (size_t)d->packed_size[i], (off_t)d->packed_at[i]) != (ssize_t)d->packed_size[i] ||
                decode_block(d, d->packed, (size_t)d->packed_size[i], (size_t)d->raw_size[i]) < 0) return -1;
            d->cached = (long)i;
        }
        size_t from = (size_t)(at - d->raw_at[i]), k = (size_t)d->raw_size[i] - from;
        if (k > n - done) k = n - done;
        memcpy(dst + done, d->block + from, k);
        done += k;
    }
    return (ssize_t)done;
}
static ssize_t r_read(void *a, void *b, size_t n) {
    struct decompressor *d = a;
    ssize_t r = r_pread(a, b, n, d->offset);
    if (r > 0) d->offset += r;
    return r;
}
static off_t r_seek(void *a, off_t o, int whence) {
    struct decompressor *d = a;
    off_t size = d->nblocks ? (off_t)(d->raw_at[d->nblocks - 1] + d->raw_size[d->nblocks - 1]) : 0;
    off_t to = whence == SEEK_SET ? o : whence == SEEK_CUR ? d->offset + o : size + o;
    if (to < 0) { errno = EINVAL; return -1; }
    return d->offset = to;
}
AAByteStream AADecompressionRandomAccessInputStreamOpen(AAByteStream in, size_t alloc_limit, AAFlagSet flags, int n_threads) {
    struct decompressor *d = calloc(1, sizeof *d);
    AAByteStream s = stream_new();
    if (!d || !s) { free(d); free(s); return NULL; }
    d->in = in; d->random = 1; d->cached = -1;
    unsigned char h[12];
    uint64_t pos = 12, raw = 0;
    size_t cap = 0;
    if (AAByteStreamPRead(in, h, 12, 0) != 12 || memcmp(h, "pbz", 3)) goto fail;
    d->algo = algo_of_letter((char)h[3]); d->block_size = (size_t)get_be64(h + 4);
    if (d->algo == (AACompressionAlgorithm)-1 || !d->block_size || d->block_size > (1u << 30)) goto fail;
    if (!(d->block = malloc(d->block_size)) || !(d->packed = malloc(d->block_size))) goto fail;
    for (;;) {
        unsigned char sizes[16];
        ssize_t r = AAByteStreamPRead(in, sizes, 16, (off_t)pos);
        if (r == 0) break;
        if (r != 16) goto fail;
        if (d->nblocks == cap) {
            cap = cap ? cap * 2 : 16;
            d->raw_at = realloc(d->raw_at, cap * 8); d->packed_at = realloc(d->packed_at, cap * 8);
            d->raw_size = realloc(d->raw_size, cap * 8); d->packed_size = realloc(d->packed_size, cap * 8);
        }
        d->raw_size[d->nblocks] = get_be64(sizes); d->packed_size[d->nblocks] = get_be64(sizes + 8);
        if (d->packed_size[d->nblocks] > d->block_size || d->raw_size[d->nblocks] > d->block_size) goto fail;
        d->raw_at[d->nblocks] = raw; d->packed_at[d->nblocks] = pos + 16;
        raw += d->raw_size[d->nblocks]; pos += 16 + d->packed_size[d->nblocks];
        d->nblocks++;
    }
    s->data = d; s->read = r_read; s->pread = r_pread; s->seek = r_seek; s->close = d_close; s->cancel = d_cancel;
    return s;
fail:
    d_close(d); free(s); errno = EINVAL;
    return NULL;
}
