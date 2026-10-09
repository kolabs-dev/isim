/* isim libdispatch: dispatch_data_t and dispatch_io_t (MRC; plain C objects, see DispatchInternal.h).
 *  - data: an immutable list of regions of reference-counted buffers; concat / subrange share buffers, map copies
 *    only when there is more than one region; a buffer's destructor (free, munmap or a block on a queue) runs when
 *    the last data object using it goes away;
 *  - I/O channels: each has a private serial queue that runs its reads, writes and barriers in submission order with
 *    POSIX read/write (stream) or pread/pwrite (random access, offsets relative to the descriptor's position when the
 *    channel was created). Partial results follow the high / low water marks (Apple's defaults: SIZE_MAX and 512 KiB)
 *    and the interval (strict: also below the low-water mark). Self-authored. */
#include "DispatchInternal.h"
#include <Block.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include <mach/mach.h>
#include <time.h>
#include <unistd.h>

/* ---------------- data ---------------- */
typedef struct dbuf { int refs; const void *ptr; size_t size; dispatch_block_t destructor; dispatch_queue_t queue; } dbuf;
typedef struct { dbuf *buf; size_t off, len; } dregion;
struct dispatch_data_s { dobj h; size_t size, n; dregion *r; };

struct dispatch_data_s _dispatch_data_empty = { { K_DATA, 1 << 30, NULL, NULL }, 0, 0, NULL };
static volatile int destructor_marks;
const dispatch_block_t _dispatch_data_destructor_free = ^{ destructor_marks |= 1; };      /* markers, never run */
const dispatch_block_t _dispatch_data_destructor_munmap = ^{ destructor_marks |= 2; };

static void run_destructor(const void *ptr, size_t size, dispatch_queue_t q, dispatch_block_t destructor) {
    if (!destructor) free((void *)ptr);                                    /* a copy made by dispatch_data_create */
    else if (destructor == _dispatch_data_destructor_free) free((void *)ptr);
    else if (destructor == _dispatch_data_destructor_munmap) vm_deallocate(mach_task_self(), (vm_address_t)ptr, size);   /* isim: munmap */
    else if (q) dispatch_async(q, destructor);
    else destructor();
}
static void dbuf_release(dbuf *b) {
    if (__atomic_sub_fetch(&b->refs, 1, __ATOMIC_ACQ_REL) != 0) return;
    run_destructor(b->ptr, b->size, b->queue, b->destructor);
    if (b->destructor) Block_release(b->destructor);
    free(b);
}
static dispatch_data_t data_new(size_t n) {
    struct dispatch_data_s *d = calloc(1, sizeof *d);
    d->h = (dobj){ K_DATA, 1, NULL, NULL };
    d->r = n ? calloc(n, sizeof *d->r) : NULL;
    return d;
}
static void data_add(dispatch_data_t d, dbuf *b, size_t off, size_t len) {
    __atomic_add_fetch(&b->refs, 1, __ATOMIC_RELAXED);
    d->r[d->n++] = (dregion){ b, off, len };
    d->size += len;
}
void isim_dispatch_data_dispose(dispatch_data_t d) {
    for (size_t i = 0; i < d->n; i++) dbuf_release(d->r[i].buf);
    free(d->r);
    free(d);
}
static dispatch_data_t retained(dispatch_data_t d) { dispatch_retain(d); return d; }

dispatch_data_t dispatch_data_create(const void *buffer, size_t size, dispatch_queue_t queue, dispatch_block_t destructor) {
    if (!buffer || !size) {
        if (destructor && destructor != _dispatch_data_destructor_free && destructor != _dispatch_data_destructor_munmap) run_destructor(buffer, size, queue, destructor);
        else if (destructor == _dispatch_data_destructor_free) free((void *)buffer);
        return dispatch_data_empty;
    }
    dbuf *b = calloc(1, sizeof *b);
    if (!destructor) { void *copy = malloc(size); memcpy(copy, buffer, size); b->ptr = copy; }
    else { b->ptr = buffer; b->destructor = Block_copy(destructor); b->queue = queue; }
    b->size = size;
    dispatch_data_t d = data_new(1);
    data_add(d, b, 0, size);
    b->refs--;                                                              /* data_add counted the one reference */
    return d;
}
size_t dispatch_data_get_size(dispatch_data_t d) { return d ? d->size : 0; }
dispatch_data_t dispatch_data_create_concat(dispatch_data_t a, dispatch_data_t b) {
    if (!a->size) return retained(b);
    if (!b->size) return retained(a);
    dispatch_data_t d = data_new(a->n + b->n);
    for (size_t i = 0; i < a->n; i++) data_add(d, a->r[i].buf, a->r[i].off, a->r[i].len);
    for (size_t i = 0; i < b->n; i++) data_add(d, b->r[i].buf, b->r[i].off, b->r[i].len);
    return d;
}
dispatch_data_t dispatch_data_create_subrange(dispatch_data_t data, size_t offset, size_t length) {
    if (offset >= data->size || !length) return dispatch_data_empty;
    if (length > data->size - offset) length = data->size - offset;
    if (offset == 0 && length == data->size) return retained(data);
    dispatch_data_t d = data_new(data->n);
    size_t at = 0, end = offset + length;
    for (size_t i = 0; i < data->n && at < end; i++) {
        dregion r = data->r[i];
        size_t lo = offset > at ? offset : at, hi = end < at + r.len ? end : at + r.len;
        if (lo < hi) data_add(d, r.buf, r.off + (lo - at), hi - lo);
        at += r.len;
    }
    return d;
}
dispatch_data_t dispatch_data_create_map(dispatch_data_t data, const void **buffer_ptr, size_t *size_ptr) {
    dispatch_data_t d;
    if (!data->size) d = dispatch_data_empty;
    else if (data->n == 1) d = retained(data);
    else {
        char *flat = malloc(data->size);
        size_t at = 0;
        for (size_t i = 0; i < data->n; i++) { memcpy(flat + at, (const char *)data->r[i].buf->ptr + data->r[i].off, data->r[i].len); at += data->r[i].len; }
        d = dispatch_data_create(flat, data->size, NULL, DISPATCH_DATA_DESTRUCTOR_FREE);
    }
    if (buffer_ptr) *buffer_ptr = d->n ? (const char *)d->r[0].buf->ptr + d->r[0].off : NULL;
    if (size_ptr) *size_ptr = d->size;
    return d;
}
/* the contiguous region `i` as a data object of its own (the data itself when it has one region) */
static dispatch_data_t region_object(dispatch_data_t data, size_t i) {
    if (data->n == 1) return retained(data);
    dispatch_data_t d = data_new(1);
    data_add(d, data->r[i].buf, data->r[i].off, data->r[i].len);
    return d;
}
bool dispatch_data_apply_f(dispatch_data_t data, void *ctx, dispatch_data_applier_function_t applier) {
    size_t at = 0;
    for (size_t i = 0; i < data->n; i++) {
        dispatch_data_t region = region_object(data, i);
        bool go = applier(ctx, region, at, (const char *)data->r[i].buf->ptr + data->r[i].off, data->r[i].len);
        dispatch_release(region);
        if (!go) return false;
        at += data->r[i].len;
    }
    return true;
}
static bool apply_block(void *ctx, dispatch_data_t region, size_t offset, const void *buffer, size_t size) {
    return ((dispatch_data_applier_t)ctx)(region, offset, buffer, size);
}
bool dispatch_data_apply(dispatch_data_t data, dispatch_data_applier_t applier) { return dispatch_data_apply_f(data, (void *)applier, apply_block); }
dispatch_data_t dispatch_data_copy_region(dispatch_data_t data, size_t location, size_t *offset_ptr) {
    size_t at = 0;
    for (size_t i = 0; i < data->n; i++) {
        if (location < at + data->r[i].len) { if (offset_ptr) *offset_ptr = at; return region_object(data, i); }
        at += data->r[i].len;
    }
    if (offset_ptr) *offset_ptr = data->size;
    return dispatch_data_empty;
}

/* ---------------- I/O channels ---------------- */
struct dispatch_io_s {
    dobj h;
    int type, fd, owns, err;           /* err: the open error of a path channel (handlers and cleanup get it) */
    off_t base;                        /* random access: offsets are relative to the position at creation */
    dispatch_queue_t q, cleanup_q;
    void (^cleanup)(int error);
    struct dispatch_io_s *parent;      /* dispatch_io_create_with_io: the channel whose descriptor this one uses */
    pthread_mutex_t lock;
    int closed, stopped, pending, cleaned;
    size_t low, high; uint64_t interval; int strict;
};
static uint64_t now_ns(void) { struct timespec ts; clock_gettime(CLOCK_UPTIME_RAW, &ts); return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec; }

static dispatch_io_t io_new(dispatch_io_type_t type, int fd, int owns, int err, dispatch_queue_t queue, void (^cleanup)(int)) {
    if (type != DISPATCH_IO_STREAM && type != DISPATCH_IO_RANDOM) return NULL;
    struct dispatch_io_s *c = calloc(1, sizeof *c);
    c->h = (dobj){ K_IO, 1, NULL, NULL };
    c->type = (int)type; c->fd = fd; c->owns = owns; c->err = err;
    c->q = dispatch_queue_create("com.apple.libdispatch-io.channelq", NULL);
    c->cleanup_q = queue ?: dispatch_get_global_queue(0, 0);
    c->cleanup = cleanup ? Block_copy(cleanup) : NULL;
    pthread_mutex_init(&c->lock, NULL);
    c->low = 512 * 1024; c->high = SIZE_MAX;
    if (!err && type == DISPATCH_IO_RANDOM) { off_t p = lseek(fd, 0, SEEK_CUR); c->base = p < 0 ? 0 : p; }
    return c;
}
/* the descriptor goes back to its owner: closed if the channel opened it, then the cleanup handler */
static void io_cleanup(dispatch_io_t c) {
    if (c->owns && c->fd >= 0) close(c->fd);
    void (^cleanup)(int) = c->cleanup; int err = c->err;
    c->cleanup = NULL;
    if (cleanup) { dispatch_async(c->cleanup_q, ^{ cleanup(err); }); Block_release(cleanup); }
}
void isim_dispatch_io_dispose(dispatch_io_t c) {
    if (!c->cleaned) { c->cleaned = 1; io_cleanup(c); }                     /* released while open: closed for it */
    if (c->cleanup) Block_release(c->cleanup);
    if (c->parent) dispatch_release(c->parent);
    dispatch_release(c->q);
    pthread_mutex_destroy(&c->lock);
    free(c);
}
dispatch_io_t dispatch_io_create(dispatch_io_type_t type, dispatch_fd_t fd, dispatch_queue_t queue, void (^cleanup)(int)) {
    return io_new(type, fd, 0, fd < 0 ? EBADF : 0, queue, cleanup);           /* a bad descriptor: its operations fail */
}
dispatch_io_t dispatch_io_create_with_path(dispatch_io_type_t type, const char *path, int oflag, mode_t mode, dispatch_queue_t queue,
                                           void (^cleanup)(int)) {
    if (!path || path[0] != '/') return NULL;                               /* absolute paths only, like Apple */
    int fd = open(path, oflag, mode);
    return io_new(type, fd, fd >= 0, fd < 0 ? errno : 0, queue, cleanup);
}
dispatch_io_t dispatch_io_create_with_io(dispatch_io_type_t type, dispatch_io_t io, dispatch_queue_t queue, void (^cleanup)(int)) {
    if (!io) return NULL;
    dispatch_io_t c = io_new(type, io->fd, 0, io->err, queue, cleanup);
    if (c) { dispatch_retain(io); c->parent = io; }
    return c;
}
dispatch_fd_t dispatch_io_get_descriptor(dispatch_io_t c) {
    pthread_mutex_lock(&c->lock); int fd = c->cleaned || c->err ? -1 : c->fd; pthread_mutex_unlock(&c->lock);
    return fd;
}
void dispatch_io_set_high_water(dispatch_io_t c, size_t high) {
    pthread_mutex_lock(&c->lock); c->high = high ? high : 1; if (c->low > c->high) c->low = c->high; pthread_mutex_unlock(&c->lock);
}
void dispatch_io_set_low_water(dispatch_io_t c, size_t low) {
    pthread_mutex_lock(&c->lock); c->low = low; if (c->high < c->low) c->high = c->low; pthread_mutex_unlock(&c->lock);
}
void dispatch_io_set_interval(dispatch_io_t c, uint64_t interval, dispatch_io_interval_flags_t flags) {
    pthread_mutex_lock(&c->lock); c->interval = interval; c->strict = (flags & DISPATCH_IO_STRICT_INTERVAL) != 0; pthread_mutex_unlock(&c->lock);
}
static int io_stopped(dispatch_io_t c) { pthread_mutex_lock(&c->lock); int s = c->stopped; pthread_mutex_unlock(&c->lock); return s; }
static int io_begin(dispatch_io_t c) {
    pthread_mutex_lock(&c->lock);
    int ok = !c->closed;
    if (ok) c->pending++;
    pthread_mutex_unlock(&c->lock);
    if (ok) dispatch_retain(c);
    return ok;
}
static void io_end(dispatch_io_t c) {
    pthread_mutex_lock(&c->lock);
    int finish = --c->pending == 0 && c->closed && !c->cleaned;
    if (finish) c->cleaned = 1;
    pthread_mutex_unlock(&c->lock);
    if (finish) io_cleanup(c);
    dispatch_release(c);
}
void dispatch_io_close(dispatch_io_t c, dispatch_io_close_flags_t flags) {
    pthread_mutex_lock(&c->lock);
    if (c->closed) { pthread_mutex_unlock(&c->lock); return; }
    c->closed = 1;
    if (flags & DISPATCH_IO_STOP) c->stopped = 1;
    int finish = c->pending == 0 && !c->cleaned;
    if (finish) c->cleaned = 1;
    pthread_mutex_unlock(&c->lock);
    if (finish) { dispatch_retain(c); dispatch_async(c->q, ^{ io_cleanup(c); dispatch_release(c); }); }
}
/* the handler on its queue; the block owns one reference to `data` */
static void deliver(dispatch_queue_t q, dispatch_io_handler_t handler, bool done, dispatch_data_t data, int err) {
    dispatch_async(q, ^{ handler(done, data, err); if (data) dispatch_release(data); });
}
/* waits until a non-blocking descriptor is ready (or the channel is stopped) */
static void wait_ready(dispatch_io_t c, int fd, short events) {
    struct pollfd p = { fd, events, 0 };
    while (!io_stopped(c) && poll(&p, 1, 100) == 0) {}
}

void dispatch_io_read(dispatch_io_t c, off_t offset, size_t length, dispatch_queue_t queue, dispatch_io_handler_t handler) {
    if (!io_begin(c)) { deliver(queue, handler, true, NULL, ECANCELED); return; }
    dispatch_async(c->q, ^{
        if (c->err) { deliver(queue, handler, true, NULL, c->err); io_end(c); return; }
        pthread_mutex_lock(&c->lock); size_t low = c->low, high = c->high; uint64_t interval = c->interval; int strict = c->strict; pthread_mutex_unlock(&c->lock);
        size_t remaining = length;
        off_t pos = c->base + offset;
        dispatch_data_t chunk = dispatch_data_empty;
        uint64_t last = now_ns();
        int err = 0;
        while (remaining > 0) {
            if (io_stopped(c)) { err = ECANCELED; break; }
            size_t want = remaining < 512 * 1024 ? remaining : 512 * 1024;
            char *buf = malloc(want);
            ssize_t n = c->type == DISPATCH_IO_RANDOM ? pread(c->fd, buf, want, pos) : read(c->fd, buf, want);
            if (n <= 0) {
                free(buf);
                if (n < 0 && errno == EINTR) continue;
                if (n < 0 && errno == EAGAIN) { wait_ready(c, c->fd, POLLIN); continue; }
                if (n < 0) err = errno;
                break;                                                      /* 0: end of file */
            }
            dispatch_data_t piece = dispatch_data_create(buf, (size_t)n, NULL, DISPATCH_DATA_DESTRUCTOR_FREE);
            dispatch_data_t joined = dispatch_data_create_concat(chunk, piece);
            dispatch_release(piece); dispatch_release(chunk); chunk = joined;
            remaining -= (size_t)n; pos += n;
            if (remaining == 0) break;
            /* partial results: pieces of the high-water mark, everything once at the low-water mark, and at each
               interval (strict: even below the low-water mark) */
            while (chunk->size >= high) {
                deliver(queue, handler, false, dispatch_data_create_subrange(chunk, 0, high), 0);
                dispatch_data_t rest = dispatch_data_create_subrange(chunk, high, SIZE_MAX);
                dispatch_release(chunk); chunk = rest; last = now_ns();
            }
            uint64_t now = now_ns();
            if (chunk->size && (chunk->size >= low || (interval && now - last >= interval && strict))) {
                deliver(queue, handler, false, chunk, 0); chunk = dispatch_data_empty; last = now;
            }
        }
        while (chunk->size > high) {
            deliver(queue, handler, false, dispatch_data_create_subrange(chunk, 0, high), 0);
            dispatch_data_t rest = dispatch_data_create_subrange(chunk, high, SIZE_MAX);
            dispatch_release(chunk); chunk = rest;
        }
        deliver(queue, handler, true, chunk, err);
        io_end(c);
    });
}

void dispatch_io_write(dispatch_io_t c, off_t offset, dispatch_data_t data, dispatch_queue_t queue, dispatch_io_handler_t handler) {
    dispatch_retain(data);
    if (!io_begin(c)) { deliver(queue, handler, true, data, ECANCELED); return; }
    dispatch_async(c->q, ^{
        if (c->err) { deliver(queue, handler, true, data, c->err); io_end(c); return; }
        pthread_mutex_lock(&c->lock); size_t low = c->low; uint64_t interval = c->interval; int strict = c->strict; pthread_mutex_unlock(&c->lock);
        off_t pos = c->base + offset;
        size_t written = 0, reported = 0;
        uint64_t last = now_ns();
        int err = 0;
        for (size_t i = 0; i < data->n && !err; i++) {
            const char *p = (const char *)data->r[i].buf->ptr + data->r[i].off;
            size_t len = data->r[i].len, done = 0;
            while (done < len) {
                if (io_stopped(c)) { err = ECANCELED; break; }
                ssize_t n = c->type == DISPATCH_IO_RANDOM ? pwrite(c->fd, p + done, len - done, pos) : write(c->fd, p + done, len - done);
                if (n < 0 && errno == EINTR) continue;
                if (n < 0 && errno == EAGAIN) { wait_ready(c, c->fd, POLLOUT); continue; }
                if (n < 0) { err = errno; break; }
                done += (size_t)n; written += (size_t)n; pos += n;
                /* progress: the data still to be written, at the low-water mark or the interval */
                uint64_t now = now_ns();
                if (written < data->size && (written - reported >= low || (interval && now - last >= interval && (strict || written > reported)))) {
                    deliver(queue, handler, false, dispatch_data_create_subrange(data, written, SIZE_MAX), 0);
                    reported = written; last = now;
                }
            }
        }
        deliver(queue, handler, true, written < data->size ? dispatch_data_create_subrange(data, written, SIZE_MAX) : NULL, err);
        dispatch_release(data);
        io_end(c);
    });
}

void dispatch_io_barrier(dispatch_io_t c, dispatch_block_t barrier) {
    dispatch_retain(c);
    dispatch_async(c->q, ^{ barrier(); dispatch_release(c); });
}

/* one-shot reads and writes on a descriptor */
void dispatch_read(dispatch_fd_t fd, size_t length, dispatch_queue_t queue, void (^handler)(dispatch_data_t, int)) {
    dispatch_io_t c = dispatch_io_create(DISPATCH_IO_STREAM, fd, queue, NULL);
    dispatch_io_set_low_water(c, SIZE_MAX);
    __block dispatch_data_t all = dispatch_data_empty;
    dispatch_io_read(c, 0, length, c->q, ^(bool done, dispatch_data_t data, int err) {
        if (data) { dispatch_data_t joined = dispatch_data_create_concat(all, data); dispatch_release(all); all = joined; }
        if (!done) return;
        dispatch_data_t result = all;
        dispatch_async(queue, ^{ handler(result, err); dispatch_release(result); });
        dispatch_io_close(c, 0);
        dispatch_release(c);
    });
}
void dispatch_write(dispatch_fd_t fd, dispatch_data_t data, dispatch_queue_t queue, void (^handler)(dispatch_data_t, int)) {
    dispatch_io_t c = dispatch_io_create(DISPATCH_IO_STREAM, fd, queue, NULL);
    dispatch_io_set_low_water(c, SIZE_MAX);
    dispatch_io_write(c, 0, data, c->q, ^(bool done, dispatch_data_t rest, int err) {
        if (!done) return;
        if (rest) dispatch_retain(rest);
        dispatch_async(queue, ^{ handler(rest, err); if (rest) dispatch_release(rest); });
        dispatch_io_close(c, 0);
        dispatch_release(c);
    });
}

/* function variants */
dispatch_io_t dispatch_io_create_f(dispatch_io_type_t type, dispatch_fd_t fd, dispatch_queue_t queue, void *ctx, void (*cleanup)(void *, int)) {
    return dispatch_io_create(type, fd, queue, cleanup ? ^(int e) { cleanup(ctx, e); } : NULL);
}
dispatch_io_t dispatch_io_create_with_path_f(dispatch_io_type_t type, const char *path, int oflag, mode_t mode, dispatch_queue_t queue, void *ctx,
                                             void (*cleanup)(void *, int)) {
    return dispatch_io_create_with_path(type, path, oflag, mode, queue, cleanup ? ^(int e) { cleanup(ctx, e); } : NULL);
}
dispatch_io_t dispatch_io_create_with_io_f(dispatch_io_type_t type, dispatch_io_t io, dispatch_queue_t queue, void *ctx, void (*cleanup)(void *, int)) {
    return dispatch_io_create_with_io(type, io, queue, cleanup ? ^(int e) { cleanup(ctx, e); } : NULL);
}
void dispatch_io_read_f(dispatch_io_t c, off_t offset, size_t length, dispatch_queue_t queue, void *ctx, dispatch_io_handler_function_t f) {
    dispatch_io_read(c, offset, length, queue, ^(bool done, dispatch_data_t data, int err) { f(ctx, done, data, err); });
}
void dispatch_io_write_f(dispatch_io_t c, off_t offset, dispatch_data_t data, dispatch_queue_t queue, void *ctx, dispatch_io_handler_function_t f) {
    dispatch_io_write(c, offset, data, queue, ^(bool done, dispatch_data_t rest, int err) { f(ctx, done, rest, err); });
}
void dispatch_io_barrier_f(dispatch_io_t c, void *ctx, dispatch_function_t f) { dispatch_io_barrier(c, ^{ f(ctx); }); }
void dispatch_read_f(dispatch_fd_t fd, size_t length, dispatch_queue_t queue, void *ctx, void (*f)(void *, dispatch_data_t, int)) {
    dispatch_read(fd, length, queue, ^(dispatch_data_t data, int err) { f(ctx, data, err); });
}
void dispatch_write_f(dispatch_fd_t fd, dispatch_data_t data, dispatch_queue_t queue, void *ctx, void (*f)(void *, dispatch_data_t, int)) {
    dispatch_write(fd, data, queue, ^(dispatch_data_t rest, int err) { f(ctx, rest, err); });
}
