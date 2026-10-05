/* Host implementation of the libSystem subset exposed to iOS-simulator guests. */
#define _GNU_SOURCE
#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <pthread.h>
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/random.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>

#include "runtime.h"

/* ---------------- errno ---------------- */
static int *d_error(void) { return &errno; } /* values 1..34 match Darwin; higher values are NOT translated */

/* ---------------- stdio globals: Darwin's stdin/stdout/stderr are FILE* variables ---------------- */
static FILE *d_stdinp, *d_stdoutp, *d_stderrp;

/* ---------------- open(): Darwin flag bits differ ---------------- */
static int d_open(const char *path, int dflags, int mode) {
    int f = dflags & 3;                                   /* O_RDONLY/O_WRONLY/O_RDWR identical */
    if (dflags & 0x0008) f |= O_APPEND;
    if (dflags & 0x0004) f |= O_NONBLOCK;
    if (dflags & 0x0200) f |= O_CREAT;
    if (dflags & 0x0400) f |= O_TRUNC;
    if (dflags & 0x0800) f |= O_EXCL;
    if (dflags & 0x1000000) f |= O_CLOEXEC;
    if (dflags & 0x100000) f |= O_DIRECTORY;
    return open(path, f, mode);
}

/* ---------------- time ---------------- */
static clockid_t clock_of(int d) {
    switch (d) {
    case 0: return CLOCK_REALTIME;
    case 4: case 5: return CLOCK_MONOTONIC_RAW;           /* MONOTONIC_RAW(_APPROX) */
    case 6: return CLOCK_MONOTONIC;
    case 8: case 9: return CLOCK_MONOTONIC_RAW;           /* UPTIME_RAW(_APPROX) */
    case 12: return CLOCK_PROCESS_CPUTIME_ID;
    case 16: return CLOCK_THREAD_CPUTIME_ID;
    default: return (clockid_t)-1;
    }
}
static int d_clock_gettime(int clk, struct timespec *ts) { clockid_t c = clock_of(clk); if (c == (clockid_t)-1) { errno = EINVAL; return -1; } return clock_gettime(c, ts); }
static uint64_t d_clock_gettime_nsec_np(int clk) {
    struct timespec ts; if (d_clock_gettime(clk, &ts)) return 0;
    return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec;
}
static uint64_t d_mach_absolute_time(void) { return d_clock_gettime_nsec_np(6); }
struct d_timebase { uint32_t numer, denom; };
static int d_mach_timebase_info(struct d_timebase *tb) { tb->numer = 1; tb->denom = 1; return 0; }

/* ---------------- pthreads (Darwin layouts) ---------------- */
#define SIG_MUTEX_INIT 0x32AAABA7L
#define SIG_MUTEX_RECURSIVE_INIT 0x32AAABA2L
#define SIG_MUTEX 0x4D555458L
#define SIG_BUSY 1L
#define SIG_COND_INIT 0x3CB0B1BBL
#define SIG_COND 0x434F4E44L
#define SIG_ONCE_INIT 0x30B1BCBAL
#define SIG_MUTEXATTR 0x4D545841L

struct d_mutex { long sig; pthread_mutex_t host; };              /* Darwin: 64 bytes */
struct d_mutexattr { long sig; int type; int pad; };             /* Darwin: 16 bytes */
struct d_cond { long sig; pthread_cond_t *host; };               /* Darwin: 48 bytes; glibc cond is 48 so keep it on the heap */
struct d_once { long sig; long state; };                         /* Darwin: 16 bytes */
_Static_assert(sizeof(struct d_mutex) <= 64, "mutex fits");

static int d_errno(int e) {
    switch (e) {
    case EAGAIN: return 35; case EDEADLK: return 11; case ETIMEDOUT: return 60;
    case ENOTSUP: return 45; case ENOSYS: return 78; case EBUSY: return 16;
    default: return e;
    }
}

static void mutex_init_host(struct d_mutex *m, int type) {
    pthread_mutexattr_t a; pthread_mutexattr_init(&a);
    pthread_mutexattr_settype(&a, type);
    pthread_mutex_init(&m->host, &a);
    pthread_mutexattr_destroy(&a);
}
static int mutex_ready(struct d_mutex *m) {
    for (;;) {
        long s = __atomic_load_n(&m->sig, __ATOMIC_ACQUIRE);
        if (s == SIG_MUTEX) return 0;
        if ((s == SIG_MUTEX_INIT || s == SIG_MUTEX_RECURSIVE_INIT) &&
            __atomic_compare_exchange_n(&m->sig, &s, SIG_BUSY, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) {
            mutex_init_host(m, s == SIG_MUTEX_RECURSIVE_INIT ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_NORMAL);
            __atomic_store_n(&m->sig, SIG_MUTEX, __ATOMIC_RELEASE);
            return 0;
        }
        if (s != SIG_BUSY && s != SIG_MUTEX_INIT && s != SIG_MUTEX_RECURSIVE_INIT) return 22;
        sched_yield();
    }
}
static int d_mutexattr_init(struct d_mutexattr *a) { a->sig = SIG_MUTEXATTR; a->type = 0; return 0; }
static int d_mutexattr_settype(struct d_mutexattr *a, int t) { a->type = t; return 0; } /* Darwin: 0 normal,1 errorcheck,2 recursive */
static int d_mutexattr_destroy(struct d_mutexattr *a) { a->sig = 0; return 0; }
static int d_mutex_init(struct d_mutex *m, const struct d_mutexattr *a) {
    int t = a ? a->type : 0;
    mutex_init_host(m, t == 2 ? PTHREAD_MUTEX_RECURSIVE : t == 1 ? PTHREAD_MUTEX_ERRORCHECK : PTHREAD_MUTEX_NORMAL);
    __atomic_store_n(&m->sig, SIG_MUTEX, __ATOMIC_RELEASE);
    return 0;
}
static int d_mutex_lock(struct d_mutex *m) { int r = mutex_ready(m); return r ? r : d_errno(pthread_mutex_lock(&m->host)); }
static int d_mutex_trylock(struct d_mutex *m) { int r = mutex_ready(m); return r ? r : d_errno(pthread_mutex_trylock(&m->host)); }
static int d_mutex_unlock(struct d_mutex *m) { int r = mutex_ready(m); return r ? r : d_errno(pthread_mutex_unlock(&m->host)); }
static int d_mutex_destroy(struct d_mutex *m) { if (m->sig == SIG_MUTEX) pthread_mutex_destroy(&m->host); m->sig = 0; return 0; }

static pthread_mutex_t cond_init_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t *cond_ready(struct d_cond *c) {
    if (__atomic_load_n(&c->sig, __ATOMIC_ACQUIRE) == SIG_COND) return c->host;
    pthread_mutex_lock(&cond_init_lock);
    if (c->sig != SIG_COND) {
        c->host = malloc(sizeof *c->host);
        pthread_condattr_t a; pthread_condattr_init(&a);
        pthread_condattr_setclock(&a, CLOCK_REALTIME);
        pthread_cond_init(c->host, &a);
        __atomic_store_n(&c->sig, SIG_COND, __ATOMIC_RELEASE);
    }
    pthread_mutex_unlock(&cond_init_lock);
    return c->host;
}
static int d_cond_init(struct d_cond *c, const void *attr) { c->sig = SIG_COND_INIT; cond_ready(c); return 0; }
static int d_cond_wait(struct d_cond *c, struct d_mutex *m) { mutex_ready(m); return d_errno(pthread_cond_wait(cond_ready(c), &m->host)); }
static int d_cond_timedwait(struct d_cond *c, struct d_mutex *m, const struct timespec *ts) { mutex_ready(m); return d_errno(pthread_cond_timedwait(cond_ready(c), &m->host, ts)); }
static int d_cond_signal(struct d_cond *c) { return d_errno(pthread_cond_signal(cond_ready(c))); }
static int d_cond_broadcast(struct d_cond *c) { return d_errno(pthread_cond_broadcast(cond_ready(c))); }
static int d_cond_destroy(struct d_cond *c) { if (c->sig == SIG_COND) { pthread_cond_destroy(c->host); free(c->host); } c->sig = 0; return 0; }

static int d_once(struct d_once *o, void (*fn)(void)) {
    static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
    if (__atomic_load_n(&o->state, __ATOMIC_ACQUIRE) == 2) return 0;
    pthread_mutex_lock(&lk);   /* coarse: one global lock for all once-blocks (recursion would deadlock) */
    if (o->state != 2) { o->state = 1; fn(); __atomic_store_n(&o->state, 2, __ATOMIC_RELEASE); }
    pthread_mutex_unlock(&lk);
    return 0;
}

static int d_pthread_create(pthread_t *t, const void *attr, void *(*fn)(void *), void *arg) {
    (void)attr;  /* Darwin pthread_attr_t contents are ignored: default attributes used */
    return d_errno(pthread_create(t, NULL, fn, arg));
}
static int d_pthread_join(pthread_t t, void **r) { return d_errno(pthread_join(t, r)); }
static int d_pthread_detach(pthread_t t) { return d_errno(pthread_detach(t)); }
static int d_pthread_key_create(unsigned long *k, void (*dtor)(void *)) { pthread_key_t hk; int r = pthread_key_create(&hk, dtor); *k = hk; return d_errno(r); }
static void *d_pthread_getspecific(unsigned long k) { return pthread_getspecific((pthread_key_t)k); }
static int d_pthread_setspecific(unsigned long k, const void *v) { return d_errno(pthread_setspecific((pthread_key_t)k, v)); }
static int d_pthread_setname_np(const char *name) { char b[16]; snprintf(b, sizeof b, "%s", name); return d_errno(pthread_setname_np(pthread_self(), b)); }
static int d_pthread_main_np(void) { return getpid() == gettid(); }

/* Darwin libm: sin+cos pair returned in xmm0/xmm1 (SysV struct return, same on Linux) */
struct d_sincos { double s, c; };
static struct d_sincos d_sincos_stret(double x) { struct d_sincos r = { sin(x), cos(x) }; return r; }
struct d_sincosf { float s, c; };
static struct d_sincosf d_sincosf_stret(float x) { struct d_sincosf r = { sinf(x), cosf(x) }; return r; }

/* ---------------- misc ---------------- */
static uintptr_t stack_chk_guard;
static void d_stack_chk_fail(void) { fflush(NULL); fputs("isim: guest stack smashing detected\n", stderr); abort(); }
static void d_stub_binder(void) { fputs("isim: dyld_stub_binder called (lazy binds are pre-resolved)\n", stderr); abort(); }
static void d_tlv_bootstrap(void) { fputs("isim: thread-local variables are not supported\n", stderr); abort(); }
/* Exceptions are not implemented (objc_exception_throw aborts), so unwinding never starts:
 * these are only reachable from landing pads/personality lookups that cannot execute. */
static void d_unwind_resume(void *e) { fflush(NULL); fputs("isim: _Unwind_Resume reached (C++/ObjC exceptions unsupported)\n", stderr); abort(); }
static int d_personality(void) { fflush(NULL); fputs("isim: exception personality invoked (exceptions unsupported)\n", stderr); abort(); }
static uint32_t d_arc4random(void) { uint32_t v; if (getrandom(&v, sizeof v, 0) != sizeof v) v = (uint32_t)random(); return v; }
static uint32_t d_arc4random_uniform(uint32_t n) { if (n < 2) return 0; uint32_t min = -n % n, r; do r = d_arc4random(); while (r < min); return r % n; }
static void d_arc4random_buf(void *b, size_t n) { uint8_t *p = b; while (n) { ssize_t r = getrandom(p, n, 0); if (r <= 0) break; p += r; n -= r; } }
static void d_bzero(void *p, size_t n) { memset(p, 0, n); }
static char **guest_argv; static int guest_argc;
static int *d_NSGetArgc(void) { return &guest_argc; }
static char ***d_NSGetArgv(void) { return &guest_argv; }
extern char **environ;
static char ***d_NSGetEnviron(void) { return &environ; }
static long d_sysconf(int name) {
    switch (name) {                     /* Darwin _SC_* numbering */
    case 29: return sysconf(_SC_PAGESIZE);
    case 57: return sysconf(_SC_NPROCESSORS_CONF);
    case 58: return sysconf(_SC_NPROCESSORS_ONLN);
    default: errno = EINVAL; return -1;
    }
}
static int d_NSGetExecutablePath(char *buf, uint32_t *size) {
    const char *p = isim_main_executable_path(); size_t n = strlen(p) + 1;
    if (n > *size) { *size = n; return -1; }
    memcpy(buf, p, n); return 0;
}

void libsystem_init(int argc, char **argv) {
    d_stdinp = stdin; d_stdoutp = stdout; d_stderrp = stderr;
    guest_argc = argc; guest_argv = argv;
    if (getrandom(&stack_chk_guard, sizeof stack_chk_guard, 0) != sizeof stack_chk_guard) stack_chk_guard = 0x5a17e57a;
}

#define P(n) { "_" #n, (void *)n, "passthrough" }
#define A(n, f) { n, (void *)f, "adapted" }
#define S(n, f) { n, (void *)f, "stub" }
static const struct shim libsystem_table[] = {
    /* memory & strings */
    P(malloc), P(calloc), P(realloc), P(free), P(posix_memalign), P(memcpy), P(memmove), P(memset), P(memcmp), P(memchr),
    P(strlen), P(strnlen), P(strcmp), P(strncmp), P(strcasecmp), P(strncasecmp), P(strcpy), P(strncpy), P(strcat), P(strncat),
    P(strchr), P(strrchr), P(strstr), P(strdup), P(strndup), P(strtol), P(strtoll), P(strtoul), P(strtoull), P(strtod), P(strtof),
    P(atoi), P(atol), P(atof), P(abs), P(labs), P(llabs), P(qsort), P(bsearch), A("_bzero", d_bzero),
    P(tolower), P(toupper), P(isalpha), P(isdigit), P(isalnum), P(isspace), P(isupper), P(islower), P(isxdigit), P(ispunct), P(isprint),
    /* stdio (FILE* is opaque to guests) */
    P(printf), P(fprintf), P(vprintf), P(vfprintf), P(snprintf), P(vsnprintf), P(sprintf), P(vsprintf), P(sscanf),
    P(puts), P(fputs), P(fputc), P(putchar), P(fwrite), P(fread), P(fflush), P(fopen), P(fclose), P(fgets), P(fseek), P(ftell), P(perror),
    A("___stdinp", &d_stdinp), A("___stdoutp", &d_stdoutp), A("___stderrp", &d_stderrp),
    /* process & environment */
    P(exit), P(_exit), P(abort), P(atexit), P(getenv), P(setenv), P(getpid), P(getuid), P(isatty), P(sleep), P(usleep), P(nanosleep),
    A("_open", d_open), P(read), P(write), P(close), P(lseek), P(access), P(unlink),
    A("___error", d_error), A("__NSGetArgc", d_NSGetArgc), A("__NSGetArgv", d_NSGetArgv), A("__NSGetExecutablePath", d_NSGetExecutablePath), A("__NSGetEnviron", d_NSGetEnviron), A("_sysconf", d_sysconf),
    /* time */
    P(time), P(gettimeofday), P(localtime_r), P(gmtime_r), P(mktime), P(strftime),
    A("_clock_gettime", d_clock_gettime), A("_clock_gettime_nsec_np", d_clock_gettime_nsec_np),
    A("_mach_absolute_time", d_mach_absolute_time), A("_mach_timebase_info", d_mach_timebase_info),
    /* math (Darwin's libm lives in libSystem) */
    P(sin), P(cos), P(tan), P(asin), P(acos), P(atan), P(atan2), P(sqrt), P(pow), P(exp), P(log), P(log10), P(log2),
    P(floor), P(ceil), P(round), P(trunc), P(fmod), P(fabs), P(fmin), P(fmax), P(hypot), P(lround), P(rint),
    A("___sincos_stret", d_sincos_stret), A("___sincosf_stret", d_sincosf_stret),
    P(sinf), P(cosf), P(sqrtf), P(floorf), P(ceilf), P(roundf), P(fabsf), P(fminf), P(fmaxf), P(powf), P(fmodf),
    /* random */
    A("_arc4random", d_arc4random), A("_arc4random_uniform", d_arc4random_uniform), A("_arc4random_buf", d_arc4random_buf),
    /* pthreads */
    A("_pthread_create", d_pthread_create), A("_pthread_join", d_pthread_join), A("_pthread_detach", d_pthread_detach),
    P(pthread_self), P(pthread_equal), P(sched_yield), A("_pthread_main_np", d_pthread_main_np), A("_pthread_setname_np", d_pthread_setname_np),
    A("_pthread_mutex_init", d_mutex_init), A("_pthread_mutex_lock", d_mutex_lock), A("_pthread_mutex_trylock", d_mutex_trylock),
    A("_pthread_mutex_unlock", d_mutex_unlock), A("_pthread_mutex_destroy", d_mutex_destroy),
    A("_pthread_mutexattr_init", d_mutexattr_init), A("_pthread_mutexattr_settype", d_mutexattr_settype), A("_pthread_mutexattr_destroy", d_mutexattr_destroy),
    A("_pthread_cond_init", d_cond_init), A("_pthread_cond_wait", d_cond_wait), A("_pthread_cond_timedwait", d_cond_timedwait),
    A("_pthread_cond_signal", d_cond_signal), A("_pthread_cond_broadcast", d_cond_broadcast), A("_pthread_cond_destroy", d_cond_destroy),
    A("_pthread_once", d_once), A("_pthread_key_create", d_pthread_key_create),
    A("_pthread_getspecific", d_pthread_getspecific), A("_pthread_setspecific", d_pthread_setspecific),
    /* toolchain support */
    A("___stack_chk_guard", &stack_chk_guard), A("___stack_chk_fail", d_stack_chk_fail),
    S("dyld_stub_binder", d_stub_binder), S("__Unwind_Resume", d_unwind_resume), S("___objc_personality_v0", d_personality), S("___gxx_personality_v0", d_personality), S("__tlv_bootstrap", d_tlv_bootstrap),
};
const struct host_lib host_libsystem = { "/usr/lib/libSystem.B.dylib", libsystem_table, sizeof libsystem_table / sizeof *libsystem_table };
