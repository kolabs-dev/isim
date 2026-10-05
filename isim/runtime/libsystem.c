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
#include <inttypes.h>
#include <libgen.h>
#include <linux/futex.h>
#include <malloc.h>
#include <sys/syscall.h>
#include <signal.h>

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
    const struct { long sig; pthread_attr_t *host; } *a = attr;
    return d_errno(pthread_create(t, a && a->sig == 0x54485241 ? a->host : NULL, fn, arg));
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

/* XSI strerror_r (glibc's default strerror_r is the GNU variant returning char *) */
extern int __xpg_strerror_r(int, char *, size_t);
static int d_strerror_r(int e, char *b, size_t n) { return __xpg_strerror_r(e, b, n); }
static int mb_cur_max_value = 1;
static int d_system(const char *cmd) { (void)cmd; errno = ENOSYS; return -1; }   /* no subprocesses on iOS */

/* ---------------- Darwin private futex (__ulock_*) on Linux futexes ---------------- */
#define UL_OPCODE_MASK 0xff
#define ULF_WAKE_ALL 0x100
static int d_ulock_wait(uint32_t op, void *addr, uint64_t value, uint32_t timeout_us) {
    struct timespec ts, *tp = NULL;
    if (timeout_us) { ts.tv_sec = timeout_us / 1000000; ts.tv_nsec = (timeout_us % 1000000) * 1000; tp = &ts; }
    long r = syscall(SYS_futex, addr, FUTEX_WAIT_PRIVATE, (uint32_t)value, tp, NULL, 0);   /* 32-bit compare ops only */
    if (r < 0 && (errno == EAGAIN || errno == EINTR)) return 0;
    return r < 0 ? -d_errno(errno) : 0;
}
static int d_ulock_wake(uint32_t op, void *addr, uint64_t wake_value) {
    syscall(SYS_futex, addr, FUTEX_WAKE_PRIVATE, (op & ULF_WAKE_ALL) ? INT32_MAX : 1, NULL, NULL, 0);
    return 0;
}
static unsigned int d_pthread_mach_thread_np(pthread_t t) { return (unsigned int)(((uintptr_t)t >> 12) & 0xffffffff) | 1; }
static int d_pthread_threadid_np(pthread_t t, uint64_t *id) { if (id) *id = t ? (uint64_t)(uintptr_t)t : (uint64_t)gettid(); return 0; }
static void *d_pthread_get_stackaddr_np(pthread_t t) {
    pthread_attr_t a; void *addr = NULL; size_t sz = 0;
    if (pthread_getattr_np(t, &a) == 0) { pthread_attr_getstack(&a, &addr, &sz); pthread_attr_destroy(&a); }
    return (char *)addr + sz;                                   /* Darwin returns the stack top */
}
static size_t d_pthread_get_stacksize_np(pthread_t t) {
    pthread_attr_t a; void *addr = NULL; size_t sz = 0;
    if (pthread_getattr_np(t, &a) == 0) { pthread_attr_getstack(&a, &addr, &sz); pthread_attr_destroy(&a); }
    return sz;
}
/* Darwin pthread_attr_t is 64 bytes; glibc's is 56, so it is stored inline after a signature word */
struct d_attr { long sig; pthread_attr_t *host; };
static int d_attr_init(struct d_attr *a) { a->sig = 0x54485241; a->host = malloc(sizeof *a->host); return pthread_attr_init(a->host); }
static int d_attr_destroy(struct d_attr *a) { if (a->host) { pthread_attr_destroy(a->host); free(a->host); a->host = NULL; } return 0; }
static int d_attr_setstacksize(struct d_attr *a, size_t n) { return d_errno(pthread_attr_setstacksize(a->host, n)); }
static int d_attr_getstacksize(const struct d_attr *a, size_t *n) { return d_errno(pthread_attr_getstacksize(a->host, n)); }
static int d_attr_getstack(const struct d_attr *a, void **p, size_t *n) { return d_errno(pthread_attr_getstack(a->host, p, n)); }
static int d_attr_setdetachstate(struct d_attr *a, int s) { return d_errno(pthread_attr_setdetachstate(a->host, s == 2 ? PTHREAD_CREATE_DETACHED : PTHREAD_CREATE_JOINABLE)); }

/* ---------------- libmalloc subset ---------------- */
static char fake_zone[64];
static size_t d_malloc_size(const void *p) { return p ? malloc_usable_size((void *)p) : 0; }
static size_t d_malloc_good_size(size_t n) { return (n + 15) & ~(size_t)15; }
static void *d_malloc_default_zone(void) { return fake_zone; }
static void *d_malloc_zone_from_ptr(const void *p) { return NULL; }
static void *d_zone_malloc(void *z, size_t n) { return malloc(n); }
static void *d_zone_calloc(void *z, size_t n, size_t s) { return calloc(n, s); }
static void *d_zone_memalign(void *z, size_t a, size_t n) { void *p = NULL; return posix_memalign(&p, a < sizeof(void *) ? sizeof(void *) : a, n) ? NULL : p; }
static void d_zone_free(void *z, void *p) { free(p); }

/* ---------------- os_object (no ObjC-backed OS objects in isim) ---------------- */
static void *d_os_retain(void *o) { return o; }
static void d_os_release(void *o) { }

/* compiler-rt / libgcc builtins: identical calling convention on Linux and Darwin x86_64 */
extern __int128 __divti3(__int128, __int128);
extern __int128 __modti3(__int128, __int128);
extern unsigned __int128 __udivti3(unsigned __int128, unsigned __int128);
extern unsigned __int128 __umodti3(unsigned __int128, unsigned __int128);
extern float __extendhfsf2(_Float16);
extern _Float16 __truncdfhf2(double);
extern _Float16 __truncsfhf2(float);

static char *d_progname = "app";

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
    if (argc > 0) { char *a = strdup(argv[0]); d_progname = strdup(basename(a)); free(a); }
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
    P(asprintf), P(vasprintf), P(flockfile), P(funlockfile), P(getc_unlocked), P(getline), P(getdelim),
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
    /* math (Darwin's libm lives in libSystem): full C99 set incl. f/l variants */
    P(acos),
    P(acosf),
    P(acosl),
    P(asin),
    P(asinf),
    P(asinl),
    P(atan),
    P(atanf),
    P(atanl),
    P(cos),
    P(cosf),
    P(cosl),
    P(sin),
    P(sinf),
    P(sinl),
    P(tan),
    P(tanf),
    P(tanl),
    P(acosh),
    P(acoshf),
    P(acoshl),
    P(asinh),
    P(asinhf),
    P(asinhl),
    P(atanh),
    P(atanhf),
    P(atanhl),
    P(cosh),
    P(coshf),
    P(coshl),
    P(sinh),
    P(sinhf),
    P(sinhl),
    P(tanh),
    P(tanhf),
    P(tanhl),
    P(exp),
    P(expf),
    P(expl),
    P(exp2),
    P(exp2f),
    P(exp2l),
    P(expm1),
    P(expm1f),
    P(expm1l),
    P(log),
    P(logf),
    P(logl),
    P(log10),
    P(log10f),
    P(log10l),
    P(log1p),
    P(log1pf),
    P(log1pl),
    P(log2),
    P(log2f),
    P(log2l),
    P(logb),
    P(logbf),
    P(logbl),
    P(cbrt),
    P(cbrtf),
    P(cbrtl),
    P(fabs),
    P(fabsf),
    P(fabsl),
    P(sqrt),
    P(sqrtf),
    P(sqrtl),
    P(erf),
    P(erff),
    P(erfl),
    P(erfc),
    P(erfcf),
    P(erfcl),
    P(lgamma),
    P(lgammaf),
    P(lgammal),
    P(tgamma),
    P(tgammaf),
    P(tgammal),
    P(ceil),
    P(ceilf),
    P(ceill),
    P(floor),
    P(floorf),
    P(floorl),
    P(nearbyint),
    P(nearbyintf),
    P(nearbyintl),
    P(rint),
    P(rintf),
    P(rintl),
    P(round),
    P(roundf),
    P(roundl),
    P(trunc),
    P(truncf),
    P(truncl),
    P(atan2),
    P(atan2f),
    P(atan2l),
    P(hypot),
    P(hypotf),
    P(hypotl),
    P(pow),
    P(powf),
    P(powl),
    P(fmod),
    P(fmodf),
    P(fmodl),
    P(remainder),
    P(remainderf),
    P(remainderl),
    P(copysign),
    P(copysignf),
    P(copysignl),
    P(nextafter),
    P(nextafterf),
    P(nextafterl),
    P(fdim),
    P(fdimf),
    P(fdiml),
    P(fmax),
    P(fmaxf),
    P(fmaxl),
    P(fmin),
    P(fminf),
    P(fminl),
    P(frexp),
    P(frexpf),
    P(frexpl),
    P(ldexp),
    P(ldexpf),
    P(ldexpl),
    P(modf),
    P(modff),
    P(modfl),
    P(scalbn),
    P(scalbnf),
    P(scalbnl),
    P(scalbln),
    P(scalblnf),
    P(scalblnl),
    P(ilogb),
    P(ilogbf),
    P(ilogbl),
    P(lrint),
    P(lrintf),
    P(lrintl),
    P(llrint),
    P(llrintf),
    P(llrintl),
    P(lround),
    P(lroundf),
    P(lroundl),
    P(llround),
    P(llroundf),
    P(llroundl),
    P(remquo),
    P(remquof),
    P(remquol),
    P(nan),
    P(nanf),
    P(nanl),
    P(nexttoward),
    P(nexttowardf),
    P(nexttowardl),
    P(fma),
    P(fmaf),
    P(fmal),
    A("___sincos_stret", d_sincos_stret), A("___sincosf_stret", d_sincosf_stret),
    /* more C11 / POSIX */
    P(rand), P(srand), P(random), P(srandom), P(div), P(ldiv), P(lldiv), P(strtold), P(atoll), P(aligned_alloc),
    P(_Exit), P(quick_exit), P(at_quick_exit), P(unsetenv), P(mblen), P(realpath), A("___mb_cur_max", &mb_cur_max_value),
    S("_system", d_system), P(scanf), P(fscanf), P(vscanf), P(vfscanf), P(vsscanf), P(getc), P(getchar), P(fgetc), P(putc), P(ungetc),
    P(freopen), P(fdopen), P(fileno), P(setbuf), P(setvbuf), P(remove), P(rename), P(tmpfile), P(rewind), P(fgetpos), P(fsetpos),
    P(clearerr), P(feof), P(ferror), P(strcoll), P(strxfrm), P(strpbrk), P(strspn), P(strcspn), P(strtok), P(strtok_r),
    P(strerror), A("_strerror_r", d_strerror_r), P(strlcpy), P(strlcat), P(clock), P(difftime), P(asctime), P(ctime),
    P(gmtime), P(localtime), P(timespec_get), P(imaxabs), P(imaxdiv), P(strtoimax), P(strtoumax), P(signal), P(raise),
    A("___ulock_wait", d_ulock_wait), A("___ulock_wake", d_ulock_wake), A("_pthread_mach_thread_np", d_pthread_mach_thread_np),
    A("_pthread_threadid_np", d_pthread_threadid_np), A("_pthread_get_stackaddr_np", d_pthread_get_stackaddr_np),
    A("_pthread_get_stacksize_np", d_pthread_get_stacksize_np), A("_pthread_attr_init", d_attr_init),
    A("_pthread_attr_destroy", d_attr_destroy), A("_pthread_attr_setstacksize", d_attr_setstacksize),
    A("_pthread_attr_getstacksize", d_attr_getstacksize), A("_pthread_attr_getstack", d_attr_getstack),
    A("_pthread_attr_setdetachstate", d_attr_setdetachstate), P(pthread_key_delete),
    A("_malloc_size", d_malloc_size), A("_malloc_good_size", d_malloc_good_size), A("_malloc_default_zone", d_malloc_default_zone),
    A("_malloc_zone_from_ptr", d_malloc_zone_from_ptr), A("_malloc_zone_malloc", d_zone_malloc), A("_malloc_zone_calloc", d_zone_calloc),
    A("_malloc_zone_memalign", d_zone_memalign), A("_malloc_zone_free", d_zone_free),
    S("_os_retain", d_os_retain), S("_os_release", d_os_release),
    P(__divti3), P(__modti3), P(__udivti3), P(__umodti3), P(__extendhfsf2), P(__truncdfhf2), P(__truncsfhf2),
    A("_environ", &environ), A("___progname", &d_progname),
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
