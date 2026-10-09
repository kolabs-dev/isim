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
#include <sys/file.h>
#include <sys/random.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
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
static int d_clock_getres(int clk, struct timespec *ts) { clockid_t c = clock_of(clk); if (c == (clockid_t)-1) { errno = EINVAL; return -1; } return clock_getres(c, ts); }
/* Darwin's memset_pattern4/8/16: fill with a repeated 4/8/16-byte pattern */
static void fill_pattern(void *b, const void *pat, size_t plen, size_t len) {
    unsigned char *d = b; const unsigned char *p = pat;
    for (size_t i = 0; i < len; i++) d[i] = p[i % plen];
}
static void d_memset_pattern4(void *b, const void *p, size_t len) { fill_pattern(b, p, 4, len); }
static void d_memset_pattern8(void *b, const void *p, size_t len) { fill_pattern(b, p, 8, len); }
static void d_memset_pattern16(void *b, const void *p, size_t len) { fill_pattern(b, p, 16, len); }
static int d_memset_s(void *dest, size_t destsz, int ch, size_t count) {
    if (!dest) return EINVAL;
    memset(dest, ch, count < destsz ? count : destsz);
    __asm__ volatile("" ::: "memory");           /* not optimized away */
    return count > destsz ? EOVERFLOW : 0;
}
/* wide-character classes: Unicode-aware like Darwin's (glibc's "C" locale is ASCII-only) */
#include <wctype.h>
#include <locale.h>
static locale_t utf8_locale(void) {
    static locale_t l;
    if (!l) { l = newlocale(LC_CTYPE_MASK, "C.UTF-8", (locale_t)0); if (!l) l = newlocale(LC_CTYPE_MASK, "en_US.UTF-8", (locale_t)0); }
    return l;
}
#define WCLS(n) static int d_##n(wint_t c) { locale_t l = utf8_locale(); return l ? n##_l(c, l) : n(c); }
WCLS(iswalpha) WCLS(iswdigit) WCLS(iswalnum) WCLS(iswspace) WCLS(iswpunct) WCLS(iswupper) WCLS(iswlower)
WCLS(iswcntrl) WCLS(iswprint) WCLS(iswxdigit) WCLS(iswgraph)
static wint_t d_towupper(wint_t c) { locale_t l = utf8_locale(); return l ? towupper_l(c, l) : towupper(c); }
static wint_t d_towlower(wint_t c) { locale_t l = utf8_locale(); return l ? towlower_l(c, l) : towlower(c); }
/* stat: Darwin layout (64-bit inode) */
struct d_stat {
    int32_t st_dev; uint16_t st_mode, st_nlink; uint64_t st_ino; uint32_t st_uid, st_gid; int32_t st_rdev;
    struct timespec st_atim, st_mtim, st_ctim, st_birthtim;
    int64_t st_size, st_blocks; int32_t st_blksize; uint32_t st_flags, st_gen; int32_t st_lspare; int64_t st_qspare[2];
};
static struct timespec ts_of(struct statx_timestamp t) { return (struct timespec){ t.tv_sec, t.tv_nsec }; }
static int ts_before(struct timespec a, struct timespec b) { return a.tv_sec < b.tv_sec || (a.tv_sec == b.tv_sec && a.tv_nsec < b.tv_nsec); }
/* statx, for the birth time; where the file system does not record one, the earlier of mtime and ctime stands in */
static int d_statx(int dirfd, const char *p, int flags, struct d_stat *d) {
    struct statx h;
    memset(d, 0, sizeof *d);
    if (statx(dirfd, p, flags | AT_STATX_SYNC_AS_STAT, STATX_BASIC_STATS | STATX_BTIME, &h)) {
        struct stat o;                                  /* no statx (old kernel, seccomp filter) */
        if (errno != ENOSYS || fstatat(dirfd, p, &o, flags)) return -1;
        d->st_dev = (int32_t)o.st_dev; d->st_mode = (uint16_t)o.st_mode; d->st_nlink = (uint16_t)o.st_nlink; d->st_ino = o.st_ino;
        d->st_uid = o.st_uid; d->st_gid = o.st_gid; d->st_rdev = (int32_t)o.st_rdev;
        d->st_atim = o.st_atim; d->st_mtim = o.st_mtim; d->st_ctim = o.st_ctim;
        d->st_birthtim = ts_before(o.st_mtim, o.st_ctim) ? o.st_mtim : o.st_ctim;
        d->st_size = o.st_size; d->st_blocks = o.st_blocks; d->st_blksize = (int32_t)o.st_blksize;
        return 0;
    }
    d->st_dev = (int32_t)makedev(h.stx_dev_major, h.stx_dev_minor); d->st_mode = (uint16_t)h.stx_mode; d->st_nlink = (uint16_t)h.stx_nlink;
    d->st_ino = h.stx_ino; d->st_uid = h.stx_uid; d->st_gid = h.stx_gid; d->st_rdev = (int32_t)makedev(h.stx_rdev_major, h.stx_rdev_minor);
    d->st_atim = ts_of(h.stx_atime); d->st_mtim = ts_of(h.stx_mtime); d->st_ctim = ts_of(h.stx_ctime);
    d->st_birthtim = (h.stx_mask & STATX_BTIME) ? ts_of(h.stx_btime) : ts_before(d->st_mtim, d->st_ctim) ? d->st_mtim : d->st_ctim;
    d->st_size = (int64_t)h.stx_size; d->st_blocks = (int64_t)h.stx_blocks; d->st_blksize = (int32_t)h.stx_blksize;
    return 0;
}
static int d_stat(const char *p, struct d_stat *d) { return d_statx(AT_FDCWD, p, 0, d); }
static int d_lstat(const char *p, struct d_stat *d) { return d_statx(AT_FDCWD, p, AT_SYMLINK_NOFOLLOW, d); }
static int d_fstat(int fd, struct d_stat *d) { return d_statx(fd, "", AT_EMPTY_PATH, d); }
/* directories: Darwin struct dirent (64-bit, 1024-byte name) from the host's */
#include <dirent.h>
struct d_dirent { uint64_t d_ino, d_seekoff; uint16_t d_reclen, d_namlen; uint8_t d_type; char d_name[1024]; };
struct d_dir { DIR *host; struct d_dirent ent; };
static struct d_dir *d_opendir(const char *name) {
    DIR *h = opendir(name);
    if (!h) return NULL;
    struct d_dir *d = calloc(1, sizeof *d); d->host = h; return d;
}
static struct d_dirent *d_readdir(struct d_dir *d) {
    struct dirent *e = readdir(d->host);
    if (!e) return NULL;
    d->ent.d_ino = e->d_ino; d->ent.d_seekoff = (uint64_t)e->d_off; d->ent.d_type = e->d_type;
    size_t n = strlen(e->d_name); if (n > 1023) n = 1023;
    memcpy(d->ent.d_name, e->d_name, n); d->ent.d_name[n] = 0;
    d->ent.d_namlen = (uint16_t)n; d->ent.d_reclen = (uint16_t)sizeof d->ent;
    return &d->ent;
}
static int d_closedir(struct d_dir *d) { int r = closedir(d->host); free(d); return r; }
static void d_rewinddir(struct d_dir *d) { rewinddir(d->host); }
static int d_dirfd(struct d_dir *d) { return dirfd(d->host); }
/* OS version answered to availability checks (__builtin_available / #available).
 * isim is not iOS; it reports the API level it emulates: ISIM_OS_VERSION (default 18.0). */
static void isim_os_version(unsigned v[3]) {
    const char *e = getenv("ISIM_OS_VERSION");
    v[0] = 18; v[1] = 0; v[2] = 0;
    if (e) sscanf(e, "%u.%u.%u", &v[0], &v[1], &v[2]);
}
static int d_isPlatformVersionAtLeast(unsigned platform, unsigned major, unsigned minor, unsigned sub) {
    unsigned v[3]; isim_os_version(v);
    if (platform != 7 && platform != 2) return 1;                   /* other platforms' checks: not this OS, treat as satisfied */
    if (v[0] != major) return v[0] > major;
    if (v[1] != minor) return v[1] > minor;
    return v[2] >= sub;
}
static int d_isOSVersionAtLeast(int major, int minor, int sub) { return d_isPlatformVersionAtLeast(7, major, minor, sub); }
/* QoS: reported, not enforced */
static unsigned d_qos_class_self(void) { return getpid() == gettid() ? 0x21u : 0x15u; }
static unsigned d_qos_class_main(void) { return 0x21u; }
static int d_pthread_set_qos_class_self_np(unsigned q, int rel) { return 0; }
static int d_pthread_get_qos_class_np(pthread_t t, unsigned *q, int *rel) { if (q) *q = t == pthread_self() && getpid() == gettid() ? 0x21u : 0x15u; if (rel) *rel = 0; return 0; }
static uint64_t d_clock_gettime_nsec_np(int clk) {
    struct timespec ts; if (d_clock_gettime(clk, &ts)) return 0;
    return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec;
}
#include "mach.inc"      /* Mach: time, task / thread / host information, VM, ports and messages, semaphores */

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
        if (s == SIG_MUTEX_INIT || s == SIG_MUTEX_RECURSIVE_INIT) {
            /* first use of a statically initialised mutex: one thread converts it; a thread that loses the race
               (its compare-exchange fails) loops and sees the finished mutex */
            long expect = s;
            if (__atomic_compare_exchange_n(&m->sig, &expect, SIG_BUSY, 0, __ATOMIC_ACQ_REL, __ATOMIC_ACQUIRE)) {
                mutex_init_host(m, s == SIG_MUTEX_RECURSIVE_INIT ? PTHREAD_MUTEX_RECURSIVE : PTHREAD_MUTEX_NORMAL);
                __atomic_store_n(&m->sig, SIG_MUTEX, __ATOMIC_RELEASE);
                return 0;
            }
            continue;
        }
        if (s != SIG_BUSY) return 22;   /* not a mutex (never initialised, or destroyed) */
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
    struct tstart *s = malloc(sizeof *s);                 /* the thread registers its tid first (mach.inc) */
    s->fn = fn; s->arg = arg;
    int r = pthread_create(t, a && a->sig == 0x54485241 ? a->host : NULL, thread_trampoline, s);
    if (r) free(s);
    return d_errno(r);
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
static double d_exp10(double x) { return pow(10.0, x); }      /* Darwin libm extension */
static float d_exp10f(float x) { return powf(10.0f, x); }
static struct d_sincos d_sincos_stret(double x) { struct d_sincos r = { sin(x), cos(x) }; return r; }
struct d_sincosf { float s, c; };
static struct d_sincosf d_sincosf_stret(float x) { struct d_sincosf r = { sinf(x), cosf(x) }; return r; }

/* XSI strerror_r (glibc's default strerror_r is the GNU variant returning char *) */
extern int __xpg_strerror_r(int, char *, size_t);
static int d_strerror_r(int e, char *b, size_t n) { return __xpg_strerror_r(e, b, n); }
/* BSD strlcpy/strlcat (glibc has them only from 2.38) */
static size_t d_strlcpy(char *d, const char *s, size_t n) {
    size_t l = strlen(s);
    if (n) { size_t c = l < n - 1 ? l : n - 1; memcpy(d, s, c); d[c] = 0; }
    return l;
}
static size_t d_strlcat(char *d, const char *s, size_t n) {
    size_t dl = strnlen(d, n);
    return dl == n ? n + strlen(s) : dl + d_strlcpy(d + dl, s, n - dl);
}
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
/* Exceptions: the host libgcc unwinder walks guest frames (objc_exc.c registers their unwind info) */
#include <unwind.h>
extern _Unwind_Reason_Code isim_objc_personality(int, _Unwind_Action, uint64_t, struct _Unwind_Exception *, struct _Unwind_Context *);
extern _Unwind_Reason_Code isim_gxx_personality(int, _Unwind_Action, uint64_t, struct _Unwind_Exception *, struct _Unwind_Context *);
extern _Unwind_Reason_Code isim_unwind_raise(struct _Unwind_Exception *);
extern _Unwind_Reason_Code isim_unwind_backtrace(_Unwind_Trace_Fn, void *);
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

#include "sockets.inc"     /* BSD sockets, name resolution, poll/select, fcntl/ioctl, getifaddrs */
/* utimes: Darwin's struct timeval has a 32-bit tv_usec (then padding) */
static int d_utimes(const char *p, const struct d_timeval *t) {
    if (!t) return utimes(p, NULL);
    struct timeval h[2] = { { t[0].tv_sec, t[0].tv_usec }, { t[1].tv_sec, t[1].tv_usec } };
    return utimes(p, h);
}
#include "posix_extras.inc"   /* pipe, pread/pwrite, dup, kill, signal numbers */

void libsystem_init(int argc, char **argv) {
    d_stdinp = stdin; d_stdoutp = stdout; d_stderrp = stderr;
    guest_argc = argc; guest_argv = argv;
    if (argc > 0) { char *a = strdup(argv[0]); d_progname = strdup(basename(a)); free(a); }
    if (getrandom(&stack_chk_guard, sizeof stack_chk_guard, 0) != sizeof stack_chk_guard) stack_chk_guard = 0x5a17e57a;
    mach_init();
}

extern int __cxa_atexit(void (*f)(void *), void *arg, void *dso);
#define P(n) { "_" #n, (void *)n, "passthrough" }
#define A(n, f) { n, (void *)f, "adapted" }
#define S(n, f) { n, (void *)f, "stub" }
#define I(n, f) { n, (void *)f, "isim" }
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
    P(exit), P(_exit), P(abort), P(atexit), { "___cxa_atexit", (void *)__cxa_atexit, "passthrough" }, P(getenv), P(setenv), P(getpid), P(getuid), P(isatty), P(getpagesize), P(sleep), P(usleep), P(nanosleep),
    A("_open", d_open), A("_read", d_read), A("_write", d_write), P(close), P(lseek), P(ftruncate), P(fsync), P(access), P(unlink), P(readlink), P(getcwd), P(mkdir), P(rmdir), P(chmod), P(flock),
    A("___error", d_error), A("__NSGetArgc", d_NSGetArgc), A("__NSGetArgv", d_NSGetArgv), A("__NSGetExecutablePath", d_NSGetExecutablePath), A("__NSGetEnviron", d_NSGetEnviron), A("_sysconf", d_sysconf),
    /* time */
    P(time), P(gettimeofday), P(localtime_r), P(gmtime_r), P(mktime), P(strftime), P(tzset), P(timegm),
    A("_clock_gettime", d_clock_gettime),
    A("_stat", d_stat), A("_lstat", d_lstat), A("_fstat", d_fstat), A("_stat$INODE64", d_stat), A("_lstat$INODE64", d_lstat), A("_fstat$INODE64", d_fstat), P(chown), P(lchown), A("_utimes", d_utimes),
    A("_opendir", d_opendir), A("_readdir", d_readdir), A("_closedir", d_closedir), A("_rewinddir", d_rewinddir), A("_dirfd", d_dirfd),
    A("_opendir$INODE64", d_opendir), A("_readdir$INODE64", d_readdir),
    A("_iswalpha", d_iswalpha), A("_iswdigit", d_iswdigit), A("_iswalnum", d_iswalnum), A("_iswspace", d_iswspace), A("_iswpunct", d_iswpunct),
    A("_iswupper", d_iswupper), A("_iswlower", d_iswlower), A("_iswcntrl", d_iswcntrl), A("_iswprint", d_iswprint), A("_iswxdigit", d_iswxdigit),
    A("_iswgraph", d_iswgraph), A("_towupper", d_towupper), A("_towlower", d_towlower), A("_qos_class_self", d_qos_class_self), I("___isPlatformVersionAtLeast", d_isPlatformVersionAtLeast), I("___isOSVersionAtLeast", d_isOSVersionAtLeast), A("_qos_class_main", d_qos_class_main), A("_pthread_set_qos_class_self_np", d_pthread_set_qos_class_self_np), A("_pthread_get_qos_class_np", d_pthread_get_qos_class_np), A("_clock_getres", d_clock_getres), A("_memset_s", d_memset_s), I("_memset_pattern4", d_memset_pattern4), I("_memset_pattern8", d_memset_pattern8), I("_memset_pattern16", d_memset_pattern16), A("_clock_gettime_nsec_np", d_clock_gettime_nsec_np),
    MACH_SHIMS,
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
    A("___sincos_stret", d_sincos_stret), A("___sincosf_stret", d_sincosf_stret), A("___exp10", d_exp10), A("___exp10f", d_exp10f),
    /* more C11 / POSIX */
    P(rand), P(srand), P(random), P(srandom), P(div), P(ldiv), P(lldiv), P(strtold), P(atoll), P(aligned_alloc),
    P(_Exit), P(quick_exit), P(at_quick_exit), P(unsetenv), P(mblen), P(realpath), A("___mb_cur_max", &mb_cur_max_value),
    S("_system", d_system), P(scanf), P(fscanf), P(vscanf), P(vfscanf), P(vsscanf), P(getc), P(getchar), P(fgetc), P(putc), P(ungetc),
    P(freopen), P(fdopen), P(fileno), P(setbuf), P(setvbuf), P(remove), P(rename), P(tmpfile), P(rewind), P(fgetpos), P(fsetpos),
    P(clearerr), P(feof), P(ferror), P(strcoll), P(strxfrm), P(strpbrk), P(strspn), P(strcspn), P(strtok), P(strtok_r),
    P(strerror), A("_strerror_r", d_strerror_r), A("_strlcpy", d_strlcpy), A("_strlcat", d_strlcat), P(clock), P(difftime), P(asctime), P(ctime),
    P(gmtime), P(localtime), P(timespec_get), P(imaxabs), P(imaxdiv), P(strtoimax), P(strtoumax), POSIX_EXTRAS,
    A("___ulock_wait", d_ulock_wait), A("___ulock_wake", d_ulock_wake),
    A("_pthread_get_stackaddr_np", d_pthread_get_stackaddr_np),
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
    /* sockets */
    SOCKET_SHIMS,
    /* random */
    A("_arc4random", d_arc4random), A("_arc4random_uniform", d_arc4random_uniform), A("_arc4random_buf", d_arc4random_buf),
    /* pthreads */
    A("_pthread_create", d_pthread_create), A("_pthread_join", d_pthread_join), A("_pthread_detach", d_pthread_detach),
    P(pthread_self), P(pthread_exit), P(pthread_equal), P(sched_yield), A("_pthread_main_np", d_pthread_main_np), A("_pthread_setname_np", d_pthread_setname_np),
    A("_pthread_mutex_init", d_mutex_init), A("_pthread_mutex_lock", d_mutex_lock), A("_pthread_mutex_trylock", d_mutex_trylock),
    A("_pthread_mutex_unlock", d_mutex_unlock), A("_pthread_mutex_destroy", d_mutex_destroy),
    A("_pthread_mutexattr_init", d_mutexattr_init), A("_pthread_mutexattr_settype", d_mutexattr_settype), A("_pthread_mutexattr_destroy", d_mutexattr_destroy),
    A("_pthread_cond_init", d_cond_init), A("_pthread_cond_wait", d_cond_wait), A("_pthread_cond_timedwait", d_cond_timedwait),
    A("_pthread_cond_signal", d_cond_signal), A("_pthread_cond_broadcast", d_cond_broadcast), A("_pthread_cond_destroy", d_cond_destroy),
    A("_pthread_once", d_once), A("_pthread_key_create", d_pthread_key_create),
    A("_pthread_getspecific", d_pthread_getspecific), A("_pthread_setspecific", d_pthread_setspecific),
    /* toolchain support */
    A("___stack_chk_guard", &stack_chk_guard), A("___stack_chk_fail", d_stack_chk_fail),
    S("dyld_stub_binder", d_stub_binder), A("__Unwind_Resume", _Unwind_Resume), A("__Unwind_RaiseException", isim_unwind_raise),
    A("__Unwind_Resume_or_Rethrow", _Unwind_Resume_or_Rethrow), A("__Unwind_DeleteException", _Unwind_DeleteException),
    A("__Unwind_GetLanguageSpecificData", _Unwind_GetLanguageSpecificData), A("__Unwind_GetRegionStart", _Unwind_GetRegionStart),
    A("__Unwind_GetIP", _Unwind_GetIP), A("__Unwind_GetIPInfo", _Unwind_GetIPInfo), A("__Unwind_GetGR", _Unwind_GetGR),
    A("__Unwind_SetGR", _Unwind_SetGR), A("__Unwind_SetIP", _Unwind_SetIP), A("__Unwind_GetCFA", _Unwind_GetCFA),
    A("__Unwind_Backtrace", isim_unwind_backtrace),
    A("___objc_personality_v0", isim_objc_personality), A("___gxx_personality_v0", isim_gxx_personality), S("__tlv_bootstrap", d_tlv_bootstrap),
};
const struct host_lib host_libsystem = { "/usr/lib/libSystem.B.dylib", libsystem_table, sizeof libsystem_table / sizeof *libsystem_table };
