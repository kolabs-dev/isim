/* isim Metal: running compute dispatches on the CPU (issue #328). A pool of worker threads (one per CPU, up to 16)
 * takes threadgroups from a shared counter; each worker runs one threadgroup at a time, so a kernel's threadgroup
 * memory (static thread_local in the translated kernels, plus setThreadgroupMemoryLength buffers) is the worker's.
 * The threads of a threadgroup run one after another; a kernel that calls threadgroup_barrier runs them as fibers
 * instead, each switching to the next at a barrier until every thread of the group has reached it. Adapted. */
#include "MTLDispatch.h"
#include <pthread.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

/* ---- fibers: x86-64 System V context switch (callee-saved registers on the old stack, then the stack pointer) ---- */
void isim_mtl_switch(void **save_sp, void *to_sp);
void isim_mtl_fiber_start(void);
__asm__(
    ".text\n.private_extern _isim_mtl_switch\n.globl _isim_mtl_switch\n_isim_mtl_switch:\n"
    "  pushq %rbp\n  pushq %rbx\n  pushq %r12\n  pushq %r13\n  pushq %r14\n  pushq %r15\n"
    "  subq $8, %rsp\n  stmxcsr (%rsp)\n  fnstcw 4(%rsp)\n"
    "  movq %rsp, (%rdi)\n  movq %rsi, %rsp\n"
    "  ldmxcsr (%rsp)\n  fldcw 4(%rsp)\n  addq $8, %rsp\n"
    "  popq %r15\n  popq %r14\n  popq %r13\n  popq %r12\n  popq %rbx\n  popq %rbp\n  retq\n"
    /* a new fiber's first switch returns here: r12 = the fiber, r13 = its body */
    ".private_extern _isim_mtl_fiber_start\n.globl _isim_mtl_fiber_start\n_isim_mtl_fiber_start:\n"
    "  movq %r12, %rdi\n  callq *%r13\n  ud2\n");

#define FIBER_STACK (128 * 1024)

typedef struct fiber {
    void *sp;
    uint8_t *stack;
    int done;
    __isim_mtl_thread thread;
    struct worker *w;
} fiber;

typedef struct worker {
    void *sched_sp;                    /* the scheduler's stack pointer while a fiber runs */
    fiber *fibers;
    int nfibers, cap;
    fiber *current;
    void *tgmem[ISIM_MTL_MAX_TGMEM];
    size_t tgmem_cap[ISIM_MTL_MAX_TGMEM];
    __isim_mtl_args args;
    const isim_mtl_dispatch *prepared;  /* the dispatch args were set up for */
} worker;

static void fiber_body(fiber *f) {
    f->w->prepared->fn->entry(&f->thread);
    f->done = 1;
    isim_mtl_switch(&f->sp, f->w->sched_sp);
}

/* threadgroup_barrier from a kernel: back to the scheduler, which runs the group's other threads */
static void barrier(void *sched) {
    worker *w = sched;
    fiber *f = w->current;
    if (f) isim_mtl_switch(&f->sp, w->sched_sp);
}

static void fiber_init(fiber *f) {
    uint64_t *top = (uint64_t *)(f->stack + FIBER_STACK);
    top -= 2;                                     /* 16-byte aligned once isim_mtl_fiber_start is "returned" to */
    *--top = (uint64_t)(uintptr_t)isim_mtl_fiber_start;
    *--top = 0;                                   /* rbp */
    *--top = 0;                                   /* rbx */
    *--top = (uint64_t)(uintptr_t)f;              /* r12 */
    *--top = (uint64_t)(uintptr_t)fiber_body;     /* r13 */
    *--top = 0;                                   /* r14 */
    *--top = 0;                                   /* r15 */
    *--top = 0x1f80 | (uint64_t)0x37f << 32;      /* mxcsr, x87 control word: the defaults */
    f->sp = top;
    f->done = 0;
}

/* ---- one threadgroup ---- */
static void run_group(worker *w, const isim_mtl_dispatch *d, uint32_t g) {
    uint32_t gx = g % d->groups[0], gy = g / d->groups[0] % d->groups[1], gz = g / d->groups[0] / d->groups[1];
    uint32_t pos[3] = {gx, gy, gz}, size[3];
    for (int i = 0; i < 3; i++) {
        uint32_t start = pos[i] * d->group_size[i];
        size[i] = d->grid[i] - start < d->group_size[i] ? d->grid[i] - start : d->group_size[i];
    }
    if (w->prepared != d) {
        w->args = d->args;
        for (int i = 0; i < ISIM_MTL_MAX_TGMEM; i++) {
            if (d->tgmem_length[i] > w->tgmem_cap[i]) { free(w->tgmem[i]); w->tgmem[i] = calloc(1, d->tgmem_length[i]); w->tgmem_cap[i] = d->tgmem_length[i]; }
            w->args.tgmem[i] = d->tgmem_length[i] ? w->tgmem[i] : NULL;
        }
        w->args.sched = w;
        w->args.barrier = d->fn->uses_barrier ? barrier : NULL;
        w->prepared = d;
        d->prepare(&w->args);
    }
    uint32_t n = size[0] * size[1] * size[2];
    if (!d->fn->uses_barrier) {
        __isim_mtl_thread t;
        memcpy(t.threadgroup_position_in_grid, pos, sizeof pos);
        memcpy(t.threads_per_threadgroup, size, sizeof size);
        uint32_t i = 0;
        for (uint32_t z = 0; z < size[2]; z++)
            for (uint32_t y = 0; y < size[1]; y++)
                for (uint32_t x = 0; x < size[0]; x++, i++) {
                    t.position_in_threadgroup[0] = x; t.position_in_threadgroup[1] = y; t.position_in_threadgroup[2] = z;
                    t.position_in_grid[0] = gx * d->group_size[0] + x; t.position_in_grid[1] = gy * d->group_size[1] + y;
                    t.position_in_grid[2] = gz * d->group_size[2] + z;
                    t.index_in_threadgroup = i;
                    d->fn->entry(&t);
                }
        return;
    }
    if ((int)n > w->cap) {
        w->fibers = realloc(w->fibers, n * sizeof *w->fibers);
        for (int i = w->cap; i < (int)n; i++) {
            w->fibers[i].stack = mmap(NULL, FIBER_STACK, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
            w->fibers[i].w = w;
        }
        w->cap = (int)n;
    }
    uint32_t i = 0;
    for (uint32_t z = 0; z < size[2]; z++)
        for (uint32_t y = 0; y < size[1]; y++)
            for (uint32_t x = 0; x < size[0]; x++, i++) {
                fiber *f = &w->fibers[i];
                __isim_mtl_thread *t = &f->thread;
                memcpy(t->threadgroup_position_in_grid, pos, sizeof pos);
                memcpy(t->threads_per_threadgroup, size, sizeof size);
                t->position_in_threadgroup[0] = x; t->position_in_threadgroup[1] = y; t->position_in_threadgroup[2] = z;
                t->position_in_grid[0] = gx * d->group_size[0] + x; t->position_in_grid[1] = gy * d->group_size[1] + y;
                t->position_in_grid[2] = gz * d->group_size[2] + z;
                t->index_in_threadgroup = i;
                fiber_init(f);
            }
    for (;;) {                                    /* each round: every unfinished thread runs to its next barrier */
        int running = 0;
        for (uint32_t k = 0; k < n; k++) {
            fiber *f = &w->fibers[k];
            if (f->done) continue;
            running = 1;
            w->current = f;
            w->args.barrier = barrier;
            isim_mtl_switch(&w->sched_sp, f->sp);
        }
        w->current = NULL;
        if (!running) break;
    }
}

/* ---- the pool ---- */
static pthread_mutex_t pool_lock = PTHREAD_MUTEX_INITIALIZER, run_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t pool_work = PTHREAD_COND_INITIALIZER, pool_done = PTHREAD_COND_INITIALIZER;
static const isim_mtl_dispatch *job;
static uint64_t job_generation;
static uint32_t job_total, job_next;
static int job_active, nworkers;
static worker *workers;

int isim_mtl_worker_count(void) {
    long n = sysconf(58);                         /* _SC_NPROCESSORS_ONLN on Darwin */
    if (n < 1) n = 1;
    return n > 16 ? 16 : (int)n;
}

static void run_groups(worker *w, const isim_mtl_dispatch *d) {
    for (;;) {
        uint32_t g = __atomic_fetch_add(&job_next, 1, __ATOMIC_RELAXED);
        if (g >= job_total) break;
        run_group(w, d, g);
    }
    w->prepared = NULL;
}

static void *worker_main(void *arg) {
    worker *w = arg;
    uint64_t seen = 0;
    pthread_mutex_lock(&pool_lock);
    for (;;) {
        while (job_generation == seen) pthread_cond_wait(&pool_work, &pool_lock);
        seen = job_generation;
        const isim_mtl_dispatch *d = job;
        job_active++;
        pthread_mutex_unlock(&pool_lock);
        if (d) run_groups(w, d);           /* NULL: woke after the dispatch it was called for had finished */
        pthread_mutex_lock(&pool_lock);
        if (--job_active == 0) pthread_cond_broadcast(&pool_done);
    }
    return NULL;
}

void isim_mtl_run(const isim_mtl_dispatch *d) {
    uint32_t total = d->groups[0] * d->groups[1] * d->groups[2];
    if (!total || !d->fn || !d->fn->entry) return;
    pthread_mutex_lock(&run_lock);                /* one dispatch at a time across the process's queues */
    pthread_mutex_lock(&pool_lock);
    if (!workers) {
        nworkers = isim_mtl_worker_count();
        workers = calloc((size_t)nworkers, sizeof *workers);
        for (int i = 1; i < nworkers; i++) {      /* worker 0 is the calling thread */
            pthread_t t;
            pthread_attr_t a;
            pthread_attr_init(&a);
            pthread_attr_setstacksize(&a, 8 << 20);
            pthread_create(&t, &a, worker_main, &workers[i]);
            pthread_attr_destroy(&a);
        }
    }
    job = d; job_total = total; job_next = 0; job_active++;
    if (total > 1) { job_generation++; pthread_cond_broadcast(&pool_work); }
    pthread_mutex_unlock(&pool_lock);
    run_groups(&workers[0], d);
    pthread_mutex_lock(&pool_lock);
    job_active--;
    while (job_active > 0) pthread_cond_wait(&pool_done, &pool_lock);
    job = NULL;
    pthread_mutex_unlock(&pool_lock);
    pthread_mutex_unlock(&run_lock);
}
