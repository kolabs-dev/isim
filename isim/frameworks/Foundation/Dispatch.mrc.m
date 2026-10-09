/* isim libdispatch subset (MRC; plain C objects).
 *  - main queue: items go to the main run loop (Runtime.m), serviced by UIApplicationMain,
 *    -[NSRunLoop run] or dispatch_main();
 *  - global queues: one shared FIFO served by a worker pool that grows while all workers are
 *    busy (blocked workers do not starve later work), up to 64 threads;
 *  - serial queues: FIFO drained by one pool job at a time (order + mutual exclusion);
 *  - timers: one timer thread (dispatch_after on non-main queues, timer sources).
 * Time values are nanoseconds of CLOCK_UPTIME_RAW (what mach_absolute_time and Swift's
 * suspending clock read); bit 63 marks the continuous clock (same base on isim), bit 62 wall time. */
#import <Foundation/Foundation.h>
#include <dispatch/dispatch.h>
#include <Block.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <sys/ioctl.h>
#include <sys/stat.h>
#include <mach/mach.h>

void isim_main_enqueue_f(double delay, dispatch_function_t f, void *ctx);   /* Runtime.m */
double isim_main_fire_due(void);                                            /* Runtime.m: runs due items, returns next delay */
void isim_main_wait(double seconds);                                        /* Runtime.m: sleeps until new main work or timeout */
/* isim libSystem (private): the Linux facilities behind the sources' events */
long isim_fd_write_space(int fd);                     /* free space of a pipe / socket, -1 for other descriptors */
long isim_fd_read_available(int fd);                  /* readable bytes, or pending connections of a listening socket */
int isim_fs_watch_fd(int fd);                         /* inotify descriptor: readable when the file of fd changes */
int isim_proc_watch_fd(pid_t pid);                    /* pidfd: readable once the process exited (-1, errno ESRCH: none) */
int isim_proc_snapshot(pid_t pid, pid_t *children, int max, uint64_t *exec_sig);   /* children count, -1 if gone */
int isim_mach_port_notify_fd(mach_port_name_t name);  /* eventfd: readable when a message is queued or the port dies */

#include "DispatchInternal.h"
typedef struct job { dispatch_function_t f; void *ctx; struct job *next; } job;
typedef struct specific { const void *key; void *ctx; dispatch_function_t dtor; struct specific *next; } specific;

struct dispatch_queue_s {
    dobj h;
    int qkind;                         /* 0 main, 1 global, 2 serial */
    const char *label;
    pthread_mutex_t lock;
    job *head, *tail; int draining;
    specific *specifics;
    struct dispatch_queue_s *target;
};
struct dispatch_queue_attr_s { dobj h; int concurrent; };
struct dispatch_source_type_s { int type; };
struct dispatch_source_s {
    dobj h;
    dispatch_queue_t queue;
    pthread_mutex_t lock;
    uint64_t next, interval;           /* timers: next fire (uptime ns), 0 = not armed */
    dispatch_function_t handler_f, cancel_f, reg_f; void *handler_b, *cancel_b, *reg_b;
    int activated, suspended, cancelled, scheduled;
    unsigned long fired;               /* timers: fires since the last handler run */
    /* other source types */
    int type;
    uintptr_t handle, mask;
    unsigned long pending, data;       /* merged events waiting for the handler / value seen by the running handler */
    int handler_queued, monitored;
    struct stat_snapshot { long long size, mtime_ns, ctime_ns, nlink, ino; int mode; char path[1024]; } vn;
    int wfd;                           /* event descriptor: inotify (vnode), pidfd (process), eventfd (Mach); -1 none */
    int nkids; pid_t kids[64]; uint64_t exec_sig;   /* process sources watching fork / exec */
    struct dispatch_source_s *next_monitored;
};
struct dispatch_semaphore_s { dobj h; long value; pthread_mutex_t lock; pthread_cond_t cond; };
struct dispatch_group_s { dobj h; long count; pthread_mutex_t lock; pthread_cond_t cond; job *notify; dispatch_queue_t *notify_q; int nnotify; };

struct dispatch_queue_s _dispatch_main_q = { { K_QUEUE, 1 << 30, NULL, NULL }, 0, "com.apple.main-thread", PTHREAD_MUTEX_INITIALIZER, NULL, NULL, 0, NULL, NULL };
struct dispatch_queue_attr_s _dispatch_queue_attr_concurrent = { { K_ATTR, 1 << 30, NULL, NULL }, 1 };
enum { ST_TIMER = 1, ST_DATA_ADD, ST_DATA_OR, ST_DATA_REPLACE, ST_READ, ST_WRITE, ST_SIGNAL, ST_PROC, ST_VNODE, ST_MEMORYPRESSURE, ST_MACH_SEND, ST_MACH_RECV };
const struct dispatch_source_type_s _dispatch_source_type_timer = { ST_TIMER };
const struct dispatch_source_type_s _dispatch_source_type_data_add = { ST_DATA_ADD };
const struct dispatch_source_type_s _dispatch_source_type_data_or = { ST_DATA_OR };
const struct dispatch_source_type_s _dispatch_source_type_data_replace = { ST_DATA_REPLACE };
const struct dispatch_source_type_s _dispatch_source_type_read = { ST_READ };
const struct dispatch_source_type_s _dispatch_source_type_write = { ST_WRITE };
const struct dispatch_source_type_s _dispatch_source_type_signal = { ST_SIGNAL };
const struct dispatch_source_type_s _dispatch_source_type_proc = { ST_PROC };
const struct dispatch_source_type_s _dispatch_source_type_vnode = { ST_VNODE };
const struct dispatch_source_type_s _dispatch_source_type_memorypressure = { ST_MEMORYPRESSURE };
const struct dispatch_source_type_s _dispatch_source_type_mach_send = { ST_MACH_SEND };
const struct dispatch_source_type_s _dispatch_source_type_mach_recv = { ST_MACH_RECV };
static struct dispatch_queue_s global_q[6];
static pthread_once_t global_once = PTHREAD_ONCE_INIT;
static __thread dispatch_queue_t current_queue;

/* ---------------- time ---------------- */
static uint64_t uptime_ns(void) { struct timespec ts; clock_gettime(CLOCK_UPTIME_RAW, &ts); return (uint64_t)ts.tv_sec * NSEC_PER_SEC + ts.tv_nsec; }
static uint64_t wall_ns(void) { struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); return (uint64_t)ts.tv_sec * NSEC_PER_SEC + ts.tv_nsec; }
#define WALL_BIT (1ull << 62)
#define CONT_BIT (1ull << 63)
static int is_wall(dispatch_time_t t) { return (t & CONT_BIT) && (t & WALL_BIT) && t != DISPATCH_TIME_FOREVER; }
static int is_cont(dispatch_time_t t) { return (t & CONT_BIT) && !(t & WALL_BIT); }
/* absolute uptime ns for a dispatch_time_t (wall times converted at call time) */
static uint64_t to_uptime(dispatch_time_t t) {
    if (t == DISPATCH_TIME_FOREVER) return UINT64_MAX;
    if (t == DISPATCH_TIME_NOW) return uptime_ns();
    if (is_cont(t)) return t & ~CONT_BIT;
    if (is_wall(t)) {
        uint64_t wall = t == DISPATCH_WALLTIME_NOW ? wall_ns() : (uint64_t)(-(int64_t)t), now = wall_ns(), up = uptime_ns();
        return wall > now ? up + (wall - now) : up;
    }
    return t;
}
dispatch_time_t dispatch_time(dispatch_time_t when, int64_t delta) {
    if (when == DISPATCH_TIME_FOREVER) return when;
    if (is_wall(when)) {
        int64_t w = (when == DISPATCH_WALLTIME_NOW ? (int64_t)wall_ns() : -(int64_t)when) + delta;
        return w <= 1 ? DISPATCH_WALLTIME_NOW : (dispatch_time_t)(-w);
    }
    if (is_cont(when)) { int64_t v = (int64_t)(when & ~CONT_BIT) + delta; return (v < 1 ? 1 : (uint64_t)v) | CONT_BIT; }
    int64_t v = (int64_t)(when == DISPATCH_TIME_NOW ? uptime_ns() : when) + delta;
    return v < 1 ? 1 : (dispatch_time_t)v;
}
dispatch_time_t dispatch_walltime(const struct timespec *when, int64_t delta) {
    uint64_t w = when ? (uint64_t)when->tv_sec * NSEC_PER_SEC + when->tv_nsec : wall_ns();
    int64_t v = (int64_t)w + delta;
    if (v <= 1) return DISPATCH_WALLTIME_NOW;
    return (dispatch_time_t)(-v);
}

/* ---------------- objects ---------------- */
void dispatch_retain(dispatch_object_t o) { if (o) __atomic_add_fetch(&((dobj *)o)->refs, 1, __ATOMIC_RELAXED); }
static void source_free(struct dispatch_source_s *s);
void dispatch_release(dispatch_object_t o) {
    if (!o) return;
    dobj *d = o;
    if (d->refs >= (1 << 29)) return;                   /* static objects */
    if (__atomic_sub_fetch(&d->refs, 1, __ATOMIC_ACQ_REL) != 0) return;
    if (d->finalizer) d->finalizer(d->ctx);
    if (d->kind == K_SOURCE) source_free(o);
    else if (d->kind == K_QUEUE) { /* queues are kept: jobs may still reference them */ }
    else if (d->kind == K_DATA) isim_dispatch_data_dispose(o);
    else if (d->kind == K_IO) isim_dispatch_io_dispose(o);
    else free(o);
}
void *dispatch_get_context(dispatch_object_t o) { return o ? ((dobj *)o)->ctx : NULL; }
void dispatch_set_context(dispatch_object_t o, void *ctx) { if (o) ((dobj *)o)->ctx = ctx; }
void dispatch_set_finalizer_f(dispatch_object_t o, dispatch_function_t f) { if (o) ((dobj *)o)->finalizer = f; }

/* ---------------- worker pool ---------------- */
static pthread_mutex_t pool_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pool_cond = PTHREAD_COND_INITIALIZER;
static job *pool_head, *pool_tail;
static int pool_threads, pool_idle, pool_wakeups;   /* wakeups: idle workers already claimed by a submit */
enum { POOL_MAX = 64 };
static void *pool_worker(void *arg) {
    for (;;) {
        pthread_mutex_lock(&pool_lock);
        while (!pool_head) {
            pool_idle++;
            struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts); ts.tv_sec += 10;
            int rc = pthread_cond_timedwait(&pool_cond, &pool_lock, &ts);
            pool_idle--;
            if (pool_wakeups > 0) pool_wakeups--;
            if (rc && !pool_head && pool_threads > 2) { pool_threads--; pthread_mutex_unlock(&pool_lock); return NULL; }
        }
        job *j = pool_head; pool_head = j->next; if (!pool_head) pool_tail = NULL;
        pthread_mutex_unlock(&pool_lock);
        @autoreleasepool { j->f(j->ctx); }
        free(j);
    }
}
static void pool_submit(dispatch_function_t f, void *ctx) {
    job *j = malloc(sizeof *j); j->f = f; j->ctx = ctx; j->next = NULL;
    pthread_mutex_lock(&pool_lock);
    if (pool_tail) pool_tail->next = j; else pool_head = j;
    pool_tail = j;
    int spawn = 0;
    if (pool_idle - pool_wakeups > 0) { pool_wakeups++; pthread_cond_signal(&pool_cond); }
    else if (pool_threads < POOL_MAX) { spawn = 1; pool_threads++; }
    pthread_mutex_unlock(&pool_lock);
    if (spawn) {
        pthread_t t; pthread_attr_t a; pthread_attr_init(&a); pthread_attr_setstacksize(&a, 1 << 20);
        pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
        if (pthread_create(&t, &a, pool_worker, NULL)) { pthread_mutex_lock(&pool_lock); pool_threads--; pthread_mutex_unlock(&pool_lock); }
        pthread_attr_destroy(&a);
    }
}

/* ---------------- queues ---------------- */
static void init_globals(void) {
    static const char *labels[6] = { "com.apple.root.background-qos", "com.apple.root.utility-qos", "com.apple.root.default-qos",
                                     "com.apple.root.user-initiated-qos", "com.apple.root.user-interactive-qos", "com.apple.root.low-qos" };
    for (int i = 0; i < 6; i++) {
        global_q[i] = (struct dispatch_queue_s){ { K_QUEUE, 1 << 30, NULL, NULL }, 1, labels[i] };
        pthread_mutex_init(&global_q[i].lock, NULL);
    }
}
dispatch_queue_t dispatch_get_global_queue(long id, unsigned long flags) {
    pthread_once(&global_once, init_globals);
    switch (id) {
    case QOS_CLASS_BACKGROUND: case DISPATCH_QUEUE_PRIORITY_BACKGROUND: return &global_q[0];
    case QOS_CLASS_UTILITY: case DISPATCH_QUEUE_PRIORITY_LOW: return &global_q[1];
    case QOS_CLASS_USER_INITIATED: case DISPATCH_QUEUE_PRIORITY_HIGH: return &global_q[3];
    case QOS_CLASS_USER_INTERACTIVE: return &global_q[4];
    default: return &global_q[2];
    }
}
dispatch_queue_attr_t dispatch_queue_attr_make_with_qos_class(dispatch_queue_attr_t attr, dispatch_qos_class_t qos, int prio) { return attr; }
dispatch_queue_t dispatch_queue_create_with_target(const char *label, dispatch_queue_attr_t attr, dispatch_queue_t target) {
    struct dispatch_queue_s *q = calloc(1, sizeof *q);
    q->h = (dobj){ K_QUEUE, 1, NULL, NULL };
    q->qkind = attr && attr->concurrent ? 1 : 2;
    q->label = strdup(label ? label : "");
    pthread_mutex_init(&q->lock, NULL);
    q->target = target;
    return q;
}
dispatch_queue_t dispatch_queue_create(const char *label, dispatch_queue_attr_t attr) { return dispatch_queue_create_with_target(label, attr, NULL); }
const char *dispatch_queue_get_label(dispatch_queue_t q) { return q ? q->label : (current_queue ? current_queue->label : ""); }
void dispatch_set_target_queue(dispatch_object_t o, dispatch_queue_t q) { if (o && ((dobj *)o)->kind == K_QUEUE) ((struct dispatch_queue_s *)o)->target = q; }

void dispatch_queue_set_specific(dispatch_queue_t q, const void *key, void *ctx, dispatch_function_t dtor) {
    pthread_mutex_lock(&q->lock);
    specific **pp = &q->specifics;
    for (; *pp; pp = &(*pp)->next) if ((*pp)->key == key) break;
    if (*pp) { if ((*pp)->dtor && (*pp)->ctx) (*pp)->dtor((*pp)->ctx); if (ctx) { (*pp)->ctx = ctx; (*pp)->dtor = dtor; } else { specific *d = *pp; *pp = d->next; free(d); } }
    else if (ctx) { specific *s = malloc(sizeof *s); *s = (specific){ key, ctx, dtor, NULL }; *pp = s; }
    pthread_mutex_unlock(&q->lock);
}
void *dispatch_queue_get_specific(dispatch_queue_t q, const void *key) {
    void *r = NULL;
    pthread_mutex_lock(&q->lock);
    for (specific *s = q->specifics; s; s = s->next) if (s->key == key) { r = s->ctx; break; }
    pthread_mutex_unlock(&q->lock);
    return r;
}
void *dispatch_get_specific(const void *key) {
    dispatch_queue_t q = current_queue ?: (pthread_main_np() ? &_dispatch_main_q : NULL);
    for (; q; q = q->target) { void *r = dispatch_queue_get_specific(q, key); if (r) return r; }
    return NULL;
}
static BOOL on_queue(dispatch_queue_t q) {
    if (q == &_dispatch_main_q) return pthread_main_np();
    for (dispatch_queue_t c = current_queue; c; c = c->target) if (c == q) return YES;
    return NO;
}
void dispatch_assert_queue(dispatch_queue_t q) {
    if (!on_queue(q)) { fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: Block was expected to execute on queue [%s] (main thread: %d)\n", q->label, pthread_main_np()); __builtin_trap(); }
}
void dispatch_assert_queue_not(dispatch_queue_t q) {
    if (on_queue(q)) { fprintf(stderr, "BUG IN CLIENT OF LIBDISPATCH: Block was expected not to execute on queue [%s]\n", q->label); abort(); }
}

typedef struct { dispatch_queue_t q; dispatch_function_t f; void *ctx; } qjob;
static void run_on(dispatch_queue_t q, dispatch_function_t f, void *ctx) {
    dispatch_queue_t saved = current_queue; current_queue = q;
    f(ctx);
    current_queue = saved;
}
static void global_trampoline(void *p) { qjob *j = p; run_on(j->q, j->f, j->ctx); free(j); }
static void serial_drain(void *p) {
    dispatch_queue_t q = p;
    for (;;) {
        pthread_mutex_lock(&q->lock);
        job *j = q->head;
        if (!j) { q->draining = 0; pthread_mutex_unlock(&q->lock); return; }
        q->head = j->next; if (!q->head) q->tail = NULL;
        pthread_mutex_unlock(&q->lock);
        @autoreleasepool { run_on(q, j->f, j->ctx); }
        free(j);
    }
}
static void main_trampoline(void *p) { qjob *j = p; run_on(&_dispatch_main_q, j->f, j->ctx); free(j); }
void dispatch_async_f(dispatch_queue_t q, void *ctx, dispatch_function_t f) {
    if (q == &_dispatch_main_q) {
        qjob *j = malloc(sizeof *j); *j = (qjob){ q, f, ctx };
        isim_main_enqueue_f(0, main_trampoline, j);
        return;
    }
    if (q->qkind == 1) {   /* concurrent */
        qjob *j = malloc(sizeof *j); *j = (qjob){ q, f, ctx };
        pool_submit(global_trampoline, j);
        return;
    }
    job *j = malloc(sizeof *j); j->f = f; j->ctx = ctx; j->next = NULL;
    pthread_mutex_lock(&q->lock);
    if (q->tail) q->tail->next = j; else q->head = j;
    q->tail = j;
    int start = !q->draining; q->draining = 1;
    pthread_mutex_unlock(&q->lock);
    if (start) pool_submit(serial_drain, q);
}
void dispatch_barrier_async_f(dispatch_queue_t q, void *ctx, dispatch_function_t f) { dispatch_async_f(q, ctx, f); }

typedef struct { dispatch_function_t f; void *ctx; pthread_mutex_t m; pthread_cond_t c; int done; } syncjob;
static void sync_trampoline(void *p) {
    syncjob *s = p; s->f(s->ctx);
    pthread_mutex_lock(&s->m); s->done = 1; pthread_cond_signal(&s->c); pthread_mutex_unlock(&s->m);
}
void dispatch_sync_f(dispatch_queue_t q, void *ctx, dispatch_function_t f) {
    /* concurrent queues, and the queue we're already on (UIKit code calling sync on main from main), run inline */
    if (q->qkind == 1 || on_queue(q)) { run_on(q, f, ctx); return; }
    syncjob s = { f, ctx, PTHREAD_MUTEX_INITIALIZER, PTHREAD_COND_INITIALIZER, 0 };
    dispatch_async_f(q, &s, sync_trampoline);
    pthread_mutex_lock(&s.m); while (!s.done) pthread_cond_wait(&s.c, &s.m); pthread_mutex_unlock(&s.m);
}
void dispatch_barrier_sync_f(dispatch_queue_t q, void *ctx, dispatch_function_t f) { dispatch_sync_f(q, ctx, f); }
void dispatch_apply_f(size_t n, dispatch_queue_t q, void *ctx, void (*f)(void *, size_t)) { for (size_t i = 0; i < n; i++) f(ctx, i); }

void dispatch_once_f(dispatch_once_t *pred, void *ctx, dispatch_function_t f) {
    static pthread_mutex_t lk = PTHREAD_RECURSIVE_MUTEX_INITIALIZER;
    if (__atomic_load_n(pred, __ATOMIC_ACQUIRE) == ~0L) return;
    pthread_mutex_lock(&lk);
    if (*pred != ~0L) { f(ctx); __atomic_store_n(pred, ~0L, __ATOMIC_RELEASE); }
    pthread_mutex_unlock(&lk);
}

/* ---------------- timers ---------------- */
typedef struct timer { uint64_t at; dispatch_queue_t q; dispatch_function_t f; void *ctx; struct dispatch_source_s *src; struct timer *next; } timer;
static pthread_mutex_t timer_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t timer_cond;
static timer *timers;
static int timer_thread_started;
static void *timer_thread(void *arg) {
    pthread_mutex_lock(&timer_lock);
    for (;;) {
        uint64_t now = uptime_ns();
        while (timers && timers->at <= now) {
            timer *t = timers; timers = t->next;
            pthread_mutex_unlock(&timer_lock);
            if (t->src) { extern void source_fire(struct dispatch_source_s *); source_fire(t->src); }
            else dispatch_async_f(t->q, t->ctx, t->f);
            free(t);
            pthread_mutex_lock(&timer_lock);
            now = uptime_ns();
        }
        if (!timers) pthread_cond_wait(&timer_cond, &timer_lock);
        else {
            uint64_t wait = timers->at - now;
            struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
            uint64_t abs = (uint64_t)ts.tv_sec * NSEC_PER_SEC + ts.tv_nsec + wait;
            ts.tv_sec = abs / NSEC_PER_SEC; ts.tv_nsec = abs % NSEC_PER_SEC;
            pthread_cond_timedwait(&timer_cond, &timer_lock, &ts);
        }
    }
    return NULL;
}
static void timer_add(uint64_t at, dispatch_queue_t q, dispatch_function_t f, void *ctx, struct dispatch_source_s *src) {
    timer *t = malloc(sizeof *t); *t = (timer){ at, q, f, ctx, src, NULL };
    pthread_mutex_lock(&timer_lock);
    if (!timer_thread_started) {
        pthread_cond_init(&timer_cond, NULL);
        pthread_t th; pthread_create(&th, NULL, timer_thread, NULL); pthread_detach(th);
        timer_thread_started = 1;
    }
    timer **pp = &timers;
    while (*pp && (*pp)->at <= at) pp = &(*pp)->next;
    t->next = *pp; *pp = t;
    pthread_cond_signal(&timer_cond);
    pthread_mutex_unlock(&timer_lock);
}
void dispatch_after_f(dispatch_time_t when, dispatch_queue_t q, void *ctx, dispatch_function_t f) {
    if (when == DISPATCH_TIME_FOREVER) return;
    uint64_t at = to_uptime(when), now = uptime_ns();
    if (q == &_dispatch_main_q) {
        qjob *j = malloc(sizeof *j); *j = (qjob){ q, f, ctx };
        isim_main_enqueue_f(at > now ? (at - now) / 1e9 : 0, main_trampoline, j);
        return;
    }
    if (at <= now) { dispatch_async_f(q, ctx, f); return; }
    timer_add(at, q, f, ctx, NULL);
}

/* ---------------- sources ----------------
 * Timers ride on the timer thread. Data sources (add/or/replace) coalesce dispatch_source_merge_data values
 * until the handler runs. The other kinds are watched by one monitor thread blocked in poll() (adapted from kqueue):
 * read / write sources on their descriptor (level-triggered: re-armed after the handler returns; data = readable bytes
 * or pending connections, the pipe's / socket's free space), file-system-object sources on an inotify descriptor
 * (each event re-checks the file with fstat for the DISPATCH_VNODE_* bits), process exit on a pidfd, Mach ports on
 * an eventfd signalled by isim's port queues, signals through a counter fed by a signal handler. Process fork / exec
 * are checked every 50 ms (/proc children and executable). Memory pressure comes from the Simulator's memory warning
 * (UIKit calls isim_dispatch_memory_pressure). */
static pthread_mutex_t mon_lock = PTHREAD_MUTEX_INITIALIZER;
static struct dispatch_source_s *monitored;
static int mon_pipe[2] = { -1, -1 };
static int mon_started;
static volatile unsigned long sig_counts[32];
static int sig_installed[32];
static void mon_wake(void) { if (mon_pipe[1] >= 0) { char c = 1; (void)write(mon_pipe[1], &c, 1); } }
static void sig_handler(int sig) { if (sig > 0 && sig < 32) __atomic_add_fetch(&sig_counts[sig], 1, __ATOMIC_RELAXED); mon_wake(); }

dispatch_source_t dispatch_source_create(dispatch_source_type_t type, uintptr_t handle, uintptr_t mask, dispatch_queue_t q) {
    if (!type || type->type < ST_TIMER || type->type > ST_MACH_RECV) { fprintf(stderr, "isim: dispatch_source_create: unknown source type\n"); return NULL; }
    if ((type->type == ST_READ || type->type == ST_WRITE || type->type == ST_VNODE) && (int)handle < 0) return NULL;
    if (type->type == ST_SIGNAL && (handle == 0 || handle >= 32)) return NULL;
    if ((type->type == ST_MACH_SEND || type->type == ST_MACH_RECV) && (handle == MACH_PORT_NULL || handle == MACH_PORT_DEAD)) return NULL;
    struct dispatch_source_s *s = calloc(1, sizeof *s);
    s->wfd = -1;
    s->h = (dobj){ K_SOURCE, 1, NULL, NULL };
    s->queue = q ?: dispatch_get_global_queue(0, 0);
    s->type = type->type; s->handle = handle; s->mask = mask;
    pthread_mutex_init(&s->lock, NULL);
    s->suspended = 1;   /* sources start inactive */
    return s;
}
static void source_free(struct dispatch_source_s *s) {
    if (s->handler_b) Block_release(s->handler_b);
    if (s->cancel_b) Block_release(s->cancel_b);
    if (s->reg_b) Block_release(s->reg_b);
    if (s->wfd >= 0) close(s->wfd);    /* here, not on cancel: the monitor thread may still be polling it */
    pthread_mutex_destroy(&s->lock);
    free(s);
}
static void source_arm(struct dispatch_source_s *s) {
    /* caller holds s->lock */
    if (s->type != ST_TIMER) return;
    if (!s->activated || s->suspended || s->cancelled || !s->next || s->scheduled) return;
    s->scheduled = 1;
    dispatch_retain(s);
    timer_add(s->next, NULL, NULL, NULL, s);
}
static void source_handler(void *p) {
    struct dispatch_source_s *s = p;
    pthread_mutex_lock(&s->lock);
    int cancelled = s->cancelled;
    if (s->type != ST_TIMER) { s->data = s->pending; s->pending = 0; s->handler_queued = 0; }
    pthread_mutex_unlock(&s->lock);
    if (!cancelled) {
        if (s->handler_f) s->handler_f(s->h.ctx);
        else if (s->handler_b) ((dispatch_block_t)s->handler_b)();
    }
    if (s->type == ST_TIMER) { pthread_mutex_lock(&s->lock); s->fired = 0; pthread_mutex_unlock(&s->lock); }
    if (s->type == ST_READ || s->type == ST_WRITE || s->type == ST_MACH_RECV) mon_wake();   /* level-triggered: check again */
    dispatch_release(s);
}
/* caller holds s->lock: queue the event handler unless one is already queued or the source is held */
static void source_queue_handler(struct dispatch_source_s *s) {
    if (!s->activated || s->suspended || s->cancelled || s->handler_queued || !s->pending) return;
    s->handler_queued = 1;
    dispatch_retain(s);
    dispatch_async_f(s->queue, s, source_handler);
}
static void source_merge(struct dispatch_source_s *s, unsigned long value, int replace_only) {
    pthread_mutex_lock(&s->lock);
    switch (s->type) {
    case ST_DATA_ADD: case ST_SIGNAL: s->pending += value; break;
    case ST_DATA_REPLACE: s->pending = value; break;
    case ST_READ: case ST_WRITE: case ST_MACH_RECV: s->pending = value ? value : 1; break;
    case ST_MEMORYPRESSURE: s->pending = value; break;   /* the current level */
    default: s->pending |= value; break;
    }
    source_queue_handler(s);
    pthread_mutex_unlock(&s->lock);
}
void source_fire(struct dispatch_source_s *s) {
    pthread_mutex_lock(&s->lock);
    s->scheduled = 0;
    int run = !s->cancelled && !s->suspended;
    if (run) {
        s->fired++;
        if (s->interval && s->interval != DISPATCH_TIME_FOREVER) { s->next += s->interval; uint64_t now = uptime_ns(); if (s->next < now) s->next = now + s->interval; }
        else s->next = 0;
        source_arm(s);
        dispatch_retain(s);
    }
    pthread_mutex_unlock(&s->lock);
    if (run) dispatch_async_f(s->queue, s, source_handler);
    dispatch_release(s);
}
void dispatch_source_merge_data(dispatch_source_t s, uintptr_t value) {
    if (!s || (s->type != ST_DATA_ADD && s->type != ST_DATA_OR && s->type != ST_DATA_REPLACE)) return;
    if (value == 0 && s->type != ST_DATA_REPLACE) return;
    source_merge(s, value, 0);
}
void dispatch_source_set_timer(dispatch_source_t s, dispatch_time_t start, uint64_t interval, uint64_t leeway) {
    pthread_mutex_lock(&s->lock);
    s->next = start == DISPATCH_TIME_FOREVER ? 0 : to_uptime(start);
    if (!s->next && start != DISPATCH_TIME_FOREVER) s->next = 1;
    s->interval = interval;
    source_arm(s);
    pthread_mutex_unlock(&s->lock);
}
void dispatch_source_set_event_handler_f(dispatch_source_t s, dispatch_function_t f) { s->handler_f = f; }
void dispatch_source_set_cancel_handler_f(dispatch_source_t s, dispatch_function_t f) { s->cancel_f = f; }
void dispatch_source_set_registration_handler_f(dispatch_source_t s, dispatch_function_t f) { s->reg_f = f; }
static void cancel_handler(void *p) {
    struct dispatch_source_s *s = p;
    if (s->cancel_f) s->cancel_f(s->h.ctx); else if (s->cancel_b) ((dispatch_block_t)s->cancel_b)();
    dispatch_release(s);
}
static void reg_handler(void *p) {
    struct dispatch_source_s *s = p;
    if (!s->cancelled) { if (s->reg_f) s->reg_f(s->h.ctx); else if (s->reg_b) ((dispatch_block_t)s->reg_b)(); }
    dispatch_release(s);
}

/* ---- monitor thread ---- */
static void vn_snapshot(struct dispatch_source_s *s, struct stat_snapshot *v) {
    struct stat st;
    memset(v, 0, sizeof *v);
    if (fstat((int)s->handle, &st) == 0) {
        v->size = st.st_size; v->nlink = st.st_nlink; v->ino = (long long)st.st_ino; v->mode = st.st_mode;
        v->mtime_ns = (long long)st.st_mtimespec.tv_sec * 1000000000LL + st.st_mtimespec.tv_nsec;
        v->ctime_ns = (long long)st.st_ctimespec.tv_sec * 1000000000LL + st.st_ctimespec.tv_nsec;
    } else v->nlink = -1;
    char link[64]; snprintf(link, sizeof link, "/proc/self/fd/%d", (int)s->handle);
    ssize_t n = readlink(link, v->path, sizeof v->path - 1);
    v->path[n > 0 ? n : 0] = 0;
}
#define VN_DELETE 0x1
#define VN_WRITE 0x2
#define VN_EXTEND 0x4
#define VN_ATTRIB 0x8
#define VN_LINK 0x10
#define VN_RENAME 0x20
#define VN_REVOKE 0x40
#define PROC_EXIT 0x80000000UL
#define PROC_FORK 0x40000000UL
#define PROC_EXEC 0x20000000UL
static unsigned long vn_changes(struct dispatch_source_s *s) {
    struct stat_snapshot now; vn_snapshot(s, &now);
    struct stat_snapshot *was = &s->vn;
    unsigned long ev = 0;
    if (now.nlink == -1) ev |= VN_REVOKE;
    else {
        if (now.nlink == 0 && was->nlink > 0) ev |= VN_DELETE;
        else if (now.nlink != was->nlink) ev |= VN_LINK;
        if (now.mtime_ns != was->mtime_ns || now.size != was->size) ev |= VN_WRITE;
        if (now.size > was->size) ev |= VN_EXTEND;
        if (now.mode != was->mode || (now.ctime_ns != was->ctime_ns && now.mtime_ns == was->mtime_ns && now.nlink == was->nlink)) ev |= VN_ATTRIB;
        /* a deleted file's /proc link gains " (deleted)"; anything else is a rename */
        if (was->path[0] && strcmp(now.path, was->path) != 0 && !strstr(now.path, " (deleted)")) ev |= VN_RENAME;
        if (strstr(now.path, " (deleted)") && !strstr(was->path, " (deleted)")) ev |= VN_DELETE;
    }
    *was = now;
    return ev & s->mask;
}
/* fork / exec of a watched process: new children since the last check, a changed executable or command line */
static unsigned long proc_changes(struct dispatch_source_s *s) {
    pid_t kids[64]; uint64_t sig = 0;
    int n = isim_proc_snapshot((pid_t)s->handle, kids, 64, &sig);
    if (n < 0) return 0;
    if (n > 64) n = 64;
    unsigned long ev = 0;
    for (int i = 0; i < n && !(ev & PROC_FORK); i++) {
        int known = 0;
        for (int j = 0; j < s->nkids; j++) if (s->kids[j] == kids[i]) { known = 1; break; }
        if (!known) ev |= PROC_FORK;
    }
    if (sig != s->exec_sig) ev |= PROC_EXEC;
    memcpy(s->kids, kids, n * sizeof *kids); s->nkids = n; s->exec_sig = sig;
    return ev & s->mask;
}
static int mach_queued(mach_port_name_t name) {
    mach_port_status_t st; mach_msg_type_number_t n = MACH_PORT_RECEIVE_STATUS_COUNT;
    return mach_port_get_attributes(mach_task_self(), name, MACH_PORT_RECEIVE_STATUS, (mach_port_info_t)&st, &n) == KERN_SUCCESS ? (int)st.mps_msgcount : 0;
}
static int mach_dead(mach_port_name_t name) {
    mach_port_type_t t = 0;
    return mach_port_type(mach_task_self(), name, &t) != KERN_SUCCESS || (t & MACH_PORT_TYPE_DEAD_NAME);
}
static int source_idle(struct dispatch_source_s *s) {
    pthread_mutex_lock(&s->lock);
    int idle = !s->handler_queued && !s->suspended && !s->cancelled;
    pthread_mutex_unlock(&s->lock);
    return idle;
}
static void drain(int fd) { char buf[4096]; while (read(fd, buf, sizeof buf) > 0) {} }
static void *monitor_thread(void *arg) {
    unsigned long seen_sig[32] = { 0 };
    for (;;) {
        struct pollfd fds[256]; struct dispatch_source_s *who[256]; int n = 0;
        fds[n].fd = mon_pipe[0]; fds[n].events = POLLIN; fds[n].revents = 0; who[n++] = NULL;
        pthread_mutex_lock(&mon_lock);
        int timed = 0;
        for (struct dispatch_source_s *s = monitored; s && n < 256; s = s->next_monitored) {
            int fd = -1, ev = POLLIN;
            switch (s->type) {
            case ST_READ: case ST_WRITE:              /* level-triggered: only while no handler is pending */
                if (source_idle(s)) { fd = (int)s->handle; ev = s->type == ST_READ ? POLLIN : POLLOUT; }
                break;
            case ST_VNODE: if (s->wfd >= 0) fd = s->wfd; else timed = 1; break;
            case ST_PROC:
                if (s->mask & (PROC_FORK | PROC_EXEC)) timed = 1;
                if (s->mask & PROC_EXIT) { if (s->wfd >= 0) fd = s->wfd; else timed = 1; }
                break;
            case ST_MACH_RECV: case ST_MACH_SEND: fd = s->wfd; break;
            }
            if (fd < 0) continue;
            dispatch_retain(s);
            fds[n].fd = fd; fds[n].events = (short)ev; fds[n].revents = 0; who[n++] = s;
        }
        pthread_mutex_unlock(&mon_lock);
        int r = poll(fds, (nfds_t)n, timed ? 50 : 1000);
        if (r > 0 && (fds[0].revents & POLLIN)) drain(mon_pipe[0]);
        for (int i = 1; i < n; i++) {
            struct dispatch_source_s *s = who[i];
            if (r > 0 && fds[i].revents && !(fds[i].revents & POLLNVAL)) {
                if (s->type == ST_READ || s->type == ST_WRITE) {
                    long data = s->type == ST_READ ? isim_fd_read_available((int)s->handle) : isim_fd_write_space((int)s->handle);
                    /* readable with 0 bytes = end of file / hang-up: still an event (data 0 like Apple's); a write
                       source on a file or terminal (no measurable buffer) reports 1 */
                    if (data < 0) data = s->type == ST_READ ? 0 : 1;
                    pthread_mutex_lock(&s->lock);
                    s->pending = (unsigned long)data;
                    if (!s->handler_queued && s->activated && !s->suspended && !s->cancelled) {
                        s->handler_queued = 1; dispatch_retain(s);
                        pthread_mutex_unlock(&s->lock);
                        dispatch_async_f(s->queue, s, source_handler);
                    } else pthread_mutex_unlock(&s->lock);
                } else if (s->type == ST_VNODE) {
                    /* inotify events: IN_UNMOUNT (0x2000) revokes; everything else is re-checked with fstat */
                    char buf[4096] __attribute__((aligned(8))); ssize_t len; unsigned long ev = 0;
                    while ((len = read(s->wfd, buf, sizeof buf)) > 0)
                        for (ssize_t off = 0; off + 16 <= len;) {
                            uint32_t mask, namelen; memcpy(&mask, buf + off + 4, 4); memcpy(&namelen, buf + off + 12, 4);
                            if (mask & 0x2000) ev |= VN_REVOKE;
                            off += 16 + namelen;
                        }
                    pthread_mutex_lock(&mon_lock);
                    ev = (ev & s->mask) | (s->monitored ? vn_changes(s) : 0);
                    pthread_mutex_unlock(&mon_lock);
                    if (ev) source_merge(s, ev, 0);
                } else if (s->type == ST_PROC) {        /* the pidfd: the process exited */
                    pthread_mutex_lock(&mon_lock);
                    if (s->monitored && (s->mask & PROC_EXIT)) { s->mask &= ~PROC_EXIT; pthread_mutex_unlock(&mon_lock); source_merge(s, PROC_EXIT, 0); }
                    else pthread_mutex_unlock(&mon_lock);
                } else {                                 /* Mach: drain the eventfd; the checks below look at the port */
                    uint64_t c; (void)!read(s->wfd, &c, sizeof c);
                }
            }
            dispatch_release(s);
        }
        /* signals, Mach ports, timed checks (process fork / exec, fallbacks without an event descriptor) */
        pthread_mutex_lock(&mon_lock);
        unsigned long counts[32];
        for (int i = 0; i < 32; i++) { unsigned long c = __atomic_load_n(&sig_counts[i], __ATOMIC_RELAXED); counts[i] = c - seen_sig[i]; seen_sig[i] = c; }
        for (struct dispatch_source_s *s = monitored; s; s = s->next_monitored) {
            if (s->type == ST_SIGNAL && counts[s->handle]) source_merge(s, counts[s->handle], 0);
            else if (s->type == ST_MACH_RECV) {
                if (source_idle(s) && mach_queued((mach_port_name_t)s->handle) > 0) source_merge(s, 1, 0);
            } else if (s->type == ST_MACH_SEND) {
                if ((s->mask & DISPATCH_MACH_SEND_DEAD) && mach_dead((mach_port_name_t)s->handle)) {
                    s->mask &= ~DISPATCH_MACH_SEND_DEAD;      /* a dead name stays dead: report it once */
                    if (s->wfd >= 0) { close(s->wfd); s->wfd = -1; }
                    source_merge(s, DISPATCH_MACH_SEND_DEAD, 0);
                }
            } else if (s->type == ST_PROC) {
                unsigned long ev = (s->mask & (PROC_FORK | PROC_EXEC)) ? proc_changes(s) : 0;
                if ((s->mask & PROC_EXIT) && s->wfd < 0 && kill((pid_t)s->handle, 0) != 0 && errno == ESRCH) { ev |= PROC_EXIT; s->mask &= ~PROC_EXIT; }
                if (ev) source_merge(s, ev, 0);
            } else if (s->type == ST_VNODE && s->wfd < 0) {
                unsigned long ev = vn_changes(s);
                if (ev) source_merge(s, ev, 0);
            }
        }
        pthread_mutex_unlock(&mon_lock);
    }
    return NULL;
}
static void monitor_add(struct dispatch_source_s *s) {
    pthread_mutex_lock(&mon_lock);
    if (!mon_started) {
        mon_started = 1;
        if (pipe(mon_pipe) == 0) { fcntl(mon_pipe[0], F_SETFL, O_NONBLOCK); fcntl(mon_pipe[1], F_SETFL, O_NONBLOCK); }
        pthread_t th; pthread_create(&th, NULL, monitor_thread, NULL); pthread_detach(th);
    }
    if (s->type == ST_SIGNAL && !sig_installed[s->handle]) { sig_installed[s->handle] = 1; signal((int)s->handle, sig_handler); }
    if (s->type == ST_VNODE) { vn_snapshot(s, &s->vn); s->wfd = isim_fs_watch_fd((int)s->handle); }
    if (s->type == ST_PROC) {
        if (s->mask & (PROC_FORK | PROC_EXEC)) {
            int n = isim_proc_snapshot((pid_t)s->handle, s->kids, 64, &s->exec_sig);
            s->nkids = n < 0 ? 0 : n > 64 ? 64 : n;
        }
        if (s->mask & PROC_EXIT) s->wfd = isim_proc_watch_fd((pid_t)s->handle);   /* -1 for a process that is gone */
    }
    if (s->type == ST_MACH_RECV || s->type == ST_MACH_SEND) s->wfd = isim_mach_port_notify_fd((mach_port_name_t)s->handle);
    dispatch_retain(s);
    s->monitored = 1;
    s->next_monitored = monitored; monitored = s;
    pthread_mutex_unlock(&mon_lock);
    mon_wake();
}
static void monitor_remove(struct dispatch_source_s *s) {
    pthread_mutex_lock(&mon_lock);
    int found = 0;
    for (struct dispatch_source_s **pp = &monitored; *pp; pp = &(*pp)->next_monitored)
        if (*pp == s) { *pp = s->next_monitored; found = 1; break; }
    s->monitored = 0;
    pthread_mutex_unlock(&mon_lock);
    if (found) { mon_wake(); dispatch_release(s); }
}
static int is_monitored_type(int t) {
    return t == ST_READ || t == ST_WRITE || t == ST_SIGNAL || t == ST_PROC || t == ST_VNODE || t == ST_MACH_SEND ||
           t == ST_MACH_RECV || t == ST_MEMORYPRESSURE;
}
/* Debug > Simulate Memory Warning (UIKit, script `memorywarning [warn|critical|normal]`): memory-pressure sources
   whose mask has the level fire with it as their data */
void isim_dispatch_memory_pressure(unsigned long level) {
    pthread_mutex_lock(&mon_lock);
    for (struct dispatch_source_s *s = monitored; s; s = s->next_monitored)
        if (s->type == ST_MEMORYPRESSURE && (s->mask & level)) source_merge(s, level, 0);
    pthread_mutex_unlock(&mon_lock);
}

void dispatch_source_cancel(dispatch_source_t s) {
    pthread_mutex_lock(&s->lock);
    int first = !s->cancelled; s->cancelled = 1;
    pthread_mutex_unlock(&s->lock);
    if (first && is_monitored_type(s->type)) monitor_remove(s);
    if (first && (s->cancel_f || s->cancel_b)) { dispatch_retain(s); dispatch_async_f(s->queue, s, cancel_handler); }
}
long dispatch_source_testcancel(dispatch_source_t s) { return s->cancelled; }
uintptr_t dispatch_source_get_data(dispatch_source_t s) { return s->type == ST_TIMER ? s->fired : s->type == ST_MACH_RECV ? 0 : s->data; }
uintptr_t dispatch_source_get_handle(dispatch_source_t s) { return s->handle; }
uintptr_t dispatch_source_get_mask(dispatch_source_t s) { return s->mask; }
void dispatch_activate(dispatch_object_t o) {
    dobj *d = o;
    if (!d || d->kind != K_SOURCE) return;
    struct dispatch_source_s *s = o;
    pthread_mutex_lock(&s->lock);
    int first = !s->activated;
    if (first) { s->activated = 1; s->suspended = 0; source_arm(s); source_queue_handler(s); }
    pthread_mutex_unlock(&s->lock);
    if (first && (s->reg_f || s->reg_b)) { dispatch_retain(s); dispatch_async_f(s->queue, s, reg_handler); }
    if (first && is_monitored_type(s->type) && !s->cancelled) monitor_add(s);
}
void dispatch_resume(dispatch_object_t o) {
    dobj *d = o;
    if (!d || d->kind != K_SOURCE) return;
    struct dispatch_source_s *s = o;
    if (!s->activated) { dispatch_activate(o); return; }
    pthread_mutex_lock(&s->lock);
    if (s->suspended > 0) s->suspended--;
    source_arm(s);
    source_queue_handler(s);
    pthread_mutex_unlock(&s->lock);
    if (s->type == ST_READ || s->type == ST_WRITE) mon_wake();
}
void dispatch_suspend(dispatch_object_t o) {
    dobj *d = o;
    if (d && d->kind == K_SOURCE) { struct dispatch_source_s *s = o; pthread_mutex_lock(&s->lock); s->suspended++; pthread_mutex_unlock(&s->lock); }
}

/* ---------------- semaphores & groups ---------------- */
static int wait_until(pthread_cond_t *c, pthread_mutex_t *m, dispatch_time_t timeout) {
    if (timeout == DISPATCH_TIME_FOREVER) return pthread_cond_wait(c, m);
    uint64_t at = to_uptime(timeout), now = uptime_ns();
    if (at <= now) return 1;
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    uint64_t abs = (uint64_t)ts.tv_sec * NSEC_PER_SEC + ts.tv_nsec + (at - now);
    ts.tv_sec = abs / NSEC_PER_SEC; ts.tv_nsec = abs % NSEC_PER_SEC;
    return pthread_cond_timedwait(c, m, &ts);
}
dispatch_semaphore_t dispatch_semaphore_create(long value) {
    if (value < 0) return NULL;
    struct dispatch_semaphore_s *s = calloc(1, sizeof *s);
    s->h = (dobj){ K_SEMA, 1, NULL, NULL }; s->value = value;
    pthread_mutex_init(&s->lock, NULL); pthread_cond_init(&s->cond, NULL);
    return s;
}
long dispatch_semaphore_wait(dispatch_semaphore_t s, dispatch_time_t timeout) {
    pthread_mutex_lock(&s->lock);
    while (s->value <= 0) if (wait_until(&s->cond, &s->lock, timeout)) { if (s->value > 0) break; pthread_mutex_unlock(&s->lock); return 1; }
    s->value--;
    pthread_mutex_unlock(&s->lock);
    return 0;
}
long dispatch_semaphore_signal(dispatch_semaphore_t s) {
    pthread_mutex_lock(&s->lock);
    s->value++;
    pthread_cond_signal(&s->cond);
    pthread_mutex_unlock(&s->lock);
    return 0;
}
dispatch_group_t dispatch_group_create(void) {
    struct dispatch_group_s *g = calloc(1, sizeof *g);
    g->h = (dobj){ K_GROUP, 1, NULL, NULL };
    pthread_mutex_init(&g->lock, NULL); pthread_cond_init(&g->cond, NULL);
    return g;
}
void dispatch_group_enter(dispatch_group_t g) { pthread_mutex_lock(&g->lock); g->count++; pthread_mutex_unlock(&g->lock); }
void dispatch_group_leave(dispatch_group_t g) {
    pthread_mutex_lock(&g->lock);
    job *notify = NULL; dispatch_queue_t *nq = NULL; int nn = 0;
    if (--g->count <= 0) {
        g->count = 0;
        pthread_cond_broadcast(&g->cond);
        notify = g->notify; nq = g->notify_q; nn = g->nnotify;
        g->notify = NULL; g->notify_q = NULL; g->nnotify = 0;
    }
    pthread_mutex_unlock(&g->lock);
    job *j = notify;
    for (int i = 0; i < nn && j; i++) { job *next = j->next; dispatch_async_f(nq[i], j->ctx, j->f); free(j); j = next; }
    free(nq);
}
long dispatch_group_wait(dispatch_group_t g, dispatch_time_t timeout) {
    pthread_mutex_lock(&g->lock);
    while (g->count > 0) if (wait_until(&g->cond, &g->lock, timeout)) { if (g->count <= 0) break; pthread_mutex_unlock(&g->lock); return 1; }
    pthread_mutex_unlock(&g->lock);
    return 0;
}
typedef struct { dispatch_group_t g; dispatch_function_t f; void *ctx; } gjob;
static void group_trampoline(void *p) { gjob *j = p; j->f(j->ctx); dispatch_group_leave(j->g); free(j); }
void dispatch_group_async_f(dispatch_group_t g, dispatch_queue_t q, void *ctx, dispatch_function_t f) {
    dispatch_group_enter(g);
    gjob *j = malloc(sizeof *j); *j = (gjob){ g, f, ctx };
    dispatch_async_f(q, j, group_trampoline);
}
void dispatch_group_notify_f(dispatch_group_t g, dispatch_queue_t q, void *ctx, dispatch_function_t f) {
    pthread_mutex_lock(&g->lock);
    if (g->count <= 0) { pthread_mutex_unlock(&g->lock); dispatch_async_f(q, ctx, f); return; }
    job *j = malloc(sizeof *j); j->f = f; j->ctx = ctx; j->next = NULL;
    job **pp = &g->notify; while (*pp) pp = &(*pp)->next; *pp = j;
    g->notify_q = realloc(g->notify_q, (g->nnotify + 1) * sizeof *g->notify_q); g->notify_q[g->nnotify++] = q;
    pthread_mutex_unlock(&g->lock);
}

/* ---------------- block variants ---------------- */
static void block_trampoline(void *b) { ((dispatch_block_t)b)(); Block_release(b); }
static void block_sync(void *b) { ((dispatch_block_t)b)(); }
void dispatch_async(dispatch_queue_t q, dispatch_block_t b) { dispatch_async_f(q, Block_copy(b), block_trampoline); }
void dispatch_barrier_async(dispatch_queue_t q, dispatch_block_t b) { dispatch_async(q, b); }
void dispatch_sync(dispatch_queue_t q, dispatch_block_t b) { dispatch_sync_f(q, (void *)b, block_sync); }
void dispatch_barrier_sync(dispatch_queue_t q, dispatch_block_t b) { dispatch_sync(q, b); }
void dispatch_after(dispatch_time_t when, dispatch_queue_t q, dispatch_block_t b) { dispatch_after_f(when, q, Block_copy(b), block_trampoline); }
void dispatch_apply(size_t n, dispatch_queue_t q, void (^b)(size_t)) { for (size_t i = 0; i < n; i++) b(i); }
void dispatch_once(dispatch_once_t *pred, dispatch_block_t b) { dispatch_once_f(pred, (void *)b, block_sync); }
void dispatch_source_set_event_handler(dispatch_source_t s, dispatch_block_t h) { if (s->handler_b) Block_release(s->handler_b); s->handler_b = h ? Block_copy(h) : NULL; s->handler_f = NULL; }
void dispatch_source_set_cancel_handler(dispatch_source_t s, dispatch_block_t h) { if (s->cancel_b) Block_release(s->cancel_b); s->cancel_b = h ? Block_copy(h) : NULL; s->cancel_f = NULL; }
void dispatch_source_set_registration_handler(dispatch_source_t s, dispatch_block_t h) { if (s->reg_b) Block_release(s->reg_b); s->reg_b = h ? Block_copy(h) : NULL; s->reg_f = NULL; }
void dispatch_group_async(dispatch_group_t g, dispatch_queue_t q, dispatch_block_t b) { dispatch_group_async_f(g, q, Block_copy(b), block_trampoline); }
void dispatch_group_notify(dispatch_group_t g, dispatch_queue_t q, dispatch_block_t b) { dispatch_group_notify_f(g, q, Block_copy(b), block_trampoline); }

/* ---------------- dispatch_main ---------------- */
void dispatch_main(void) {
    for (;;) {
        @autoreleasepool {
            double next = isim_main_fire_due();
            isim_main_wait(next < 1 ? next : 1);
        }
    }
}

/* ---------------- vouchers (Swift Concurrency propagates them; isim has none) ---------------- */
void *voucher_copy(void) { return NULL; }
void *voucher_adopt(void *voucher) { return NULL; }
