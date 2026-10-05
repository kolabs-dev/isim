/* Darwin libSystem subset for machoload (experiment 03). See shims.h for status meanings. */
#define _GNU_SOURCE
#include <errno.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/random.h>
#include "shims.h"

/* ---- errno translation (Darwin numbering differs from Linux above 34) ---- */
static int darwin_errno(int e) {
    switch (e) {
    case 0: return 0;
    case EAGAIN: return 35;     case EINPROGRESS: return 36; case EALREADY: return 37;
    case ENOTSUP: return 45;    case EDEADLK: return 11;     case ETIMEDOUT: return 60;
    case ENOSYS: return 78;     case EOVERFLOW: return 84;
    default: return e <= 34 ? e : e; /* 1..34 match; others: TODO full table */
    }
}

/* ---- pthread mutex: Darwin pthread_mutex_t is {long sig; char opaque[56]} (64 bytes).
 * Static initializer sets sig=0x32AAABA7, which glibc would treat as garbage. We keep a
 * glibc mutex (40 bytes) inside the opaque area and initialise it lazily. ---- */
#define D_MUTEX_SIG_INIT 0x32AAABA7L
#define D_MUTEX_SIG      0x4D555458L   /* 'MUTX' as used by Darwin libpthread */
#define D_MUTEX_BUSY     1L
struct d_mutex { long sig; pthread_mutex_t host; };
_Static_assert(sizeof(struct d_mutex) <= 64, "glibc mutex must fit in Darwin storage");

static int d_mutex_ready(struct d_mutex *m) {
    for (;;) {
        long s = __atomic_load_n(&m->sig, __ATOMIC_ACQUIRE);
        if (s == D_MUTEX_SIG) return 0;
        if (s == D_MUTEX_SIG_INIT &&
            __atomic_compare_exchange_n(&m->sig, &s, D_MUTEX_BUSY, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) {
            pthread_mutex_init(&m->host, NULL);
            __atomic_store_n(&m->sig, D_MUTEX_SIG, __ATOMIC_RELEASE);
            return 0;
        }
        if (s != D_MUTEX_BUSY && s != D_MUTEX_SIG_INIT) return 22; /* EINVAL */
        __builtin_ia32_pause();
    }
}
static int d_pthread_mutex_init(struct d_mutex *m, const void *attr) {
    if (attr) return 22; /* Darwin attr layout not translated yet */
    pthread_mutex_init(&m->host, NULL);
    __atomic_store_n(&m->sig, D_MUTEX_SIG, __ATOMIC_RELEASE);
    return 0;
}
static int d_pthread_mutex_lock(struct d_mutex *m)   { int r = d_mutex_ready(m); return r ? r : darwin_errno(pthread_mutex_lock(&m->host)); }
static int d_pthread_mutex_unlock(struct d_mutex *m) { int r = d_mutex_ready(m); return r ? r : darwin_errno(pthread_mutex_unlock(&m->host)); }

/* ---- threads: Darwin pthread_t is a pointer (8 bytes), glibc's is unsigned long (8 bytes). */
_Static_assert(sizeof(pthread_t) == 8, "pthread_t size");
static int d_pthread_create(pthread_t *t, const void *attr, void *(*fn)(void *), void *arg) {
    if (attr) return 22; /* Darwin pthread_attr_t layout not translated yet */
    return darwin_errno(pthread_create(t, NULL, fn, arg));
}
static int d_pthread_join(pthread_t t, void **ret) { return darwin_errno(pthread_join(t, ret)); }

/* ---- stack protector (Darwin uses a global guard, not TLS) ---- */
static uintptr_t stack_chk_guard;
static void d_stack_chk_fail(void) { fputs("machoload: guest stack smashing detected\n", stderr); abort(); }

static void d_stub_binder(void) { fputs("machoload: dyld_stub_binder called (lazy binds are pre-resolved; should not happen)\n", stderr); abort(); }

static const struct shim table[] = {
    { "_puts",                 (void *)puts,                   "passthrough" },
    { "_printf",               (void *)printf,                 "passthrough" }, /* Darwin-only conversions not handled */
    { "_malloc",               (void *)malloc,                 "passthrough" }, /* no malloc zones / malloc_size */
    { "_free",                 (void *)free,                   "passthrough" },
    { "_strlen",               (void *)strlen,                 "passthrough" },
    { "_memset",               (void *)memset,                 "passthrough" },
    { "_calloc",               (void *)calloc,                 "passthrough" },
    { "_exit",                 (void *)exit,                   "passthrough" }, /* atexit of guest ok; no dyld termination */
    { "_pthread_create",       (void *)d_pthread_create,       "adapted" },     /* attr must be NULL */
    { "_pthread_join",         (void *)d_pthread_join,         "adapted" },
    { "_pthread_mutex_init",   (void *)d_pthread_mutex_init,   "adapted" },     /* attr must be NULL */
    { "_pthread_mutex_lock",   (void *)d_pthread_mutex_lock,   "adapted" },
    { "_pthread_mutex_unlock", (void *)d_pthread_mutex_unlock, "adapted" },
    { "___stack_chk_guard",    (void *)&stack_chk_guard,       "adapted" },
    { "___stack_chk_fail",     (void *)d_stack_chk_fail,       "adapted" },
    { "dyld_stub_binder",      (void *)d_stub_binder,          "stub" },
};

const struct shim *shim_lookup(const char *name) {
    for (size_t i = 0; i < sizeof table / sizeof *table; i++)
        if (!strcmp(table[i].name, name)) return &table[i];
    return objc_rt_shim_lookup(name);
}

void shims_init(const char *guest_path) {
    (void)guest_path;
    if (getrandom(&stack_chk_guard, sizeof stack_chk_guard, 0) != sizeof stack_chk_guard) stack_chk_guard = 0x5a5a5a5a;
}
