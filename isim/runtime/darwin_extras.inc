/* isim libSystem: more Darwin functions for binary SDKs (Google Mobile Ads...): signal actions and masks, read-write
 * locks, mmap, uname, sysctl, the rune tables of Darwin's <ctype.h> inline functions, libunwind's unw_* API,
 * thread-local destructors, __assert_rtn and compiler-rt's 128-bit conversions.
 * Included by libsystem.c after posix_extras.inc (uses sig_host/sig_darwin, NETRET, darwin_errno, d_errno). */
#include <sys/mman.h>
#include <sys/utsname.h>
#include <sys/sysinfo.h>
#include <execinfo.h>
#include <wctype.h>
#include <wchar.h>

/* ---------------- sigaction, signal masks ---------------- */
/* Darwin: struct sigaction { handler; uint32_t sa_mask; int sa_flags; }, sigset_t = uint32_t (bit n-1 = signal n),
   SA_ONSTACK 1, SA_RESTART 2, SA_RESETHAND 4, SA_NOCLDSTOP 8, SA_NODEFER 0x10, SA_NOCLDWAIT 0x20, SA_SIGINFO 0x40;
   siginfo_t { si_signo, si_errno, si_code, si_pid, si_uid, si_status, si_addr, si_value, si_band, pad[7] } */
struct d_sigaction { void *handler; uint32_t mask; int flags; };
struct d_siginfo { int signo, err, code; int pid; unsigned uid; int status; void *addr; void *value; long band; unsigned long pad[7]; };
typedef void (*d_siginfo_handler)(int, struct d_siginfo *, void *);
static struct d_sigaction guest_actions[65];        /* by host signal number */

static void sigset_to_host(uint32_t d, sigset_t *h) {
    sigemptyset(h);
    for (int s = 1; s < 32; s++) if (d & (1u << (s - 1))) { int hs = sig_host(s); if (hs > 0) sigaddset(h, hs); }
}
static uint32_t sigset_to_darwin(const sigset_t *h) {
    uint32_t d = 0;
    for (int s = 1; s < 32; s++) { int hs = sig_host(s); if (hs > 0 && sigismember(h, hs)) d |= 1u << (s - 1); }
    return d;
}
static void sig_info_trampoline(int h, siginfo_t *si, void *uc) {
    (void)uc;
    struct d_sigaction *a = &guest_actions[h];
    struct d_siginfo d = { sig_darwin(h), si ? si->si_errno : 0, si ? si->si_code : 0, si ? si->si_pid : 0, si ? si->si_uid : 0,
                           si ? si->si_status : 0, si ? si->si_addr : NULL, NULL, 0, { 0 } };
    /* Linux's ucontext is not Darwin's: the handler gets no machine context */
    if (a->flags & 0x40) ((d_siginfo_handler)a->handler)(sig_darwin(h), &d, NULL);
    else if (a->handler && a->handler != (void *)1) ((void (*)(int))a->handler)(sig_darwin(h));
}
/* adapted: isim keeps its own handlers for the fatal signals (its crash reports and stack samples rely on them): a
   guest's action for SIGSEGV, SIGBUS, SIGILL, SIGFPE, SIGTRAP or SIGABRT is recorded (and reported back as the old
   action) but not installed. Other signals get the guest's handler with Darwin signal numbers and siginfo. */
static int fatal_signal(int h) { return h == SIGSEGV || h == SIGBUS || h == SIGILL || h == SIGFPE || h == SIGTRAP || h == SIGABRT; }
ISIM_GUEST_ABI static int d_sigaction(int dsig, const struct d_sigaction *act, struct d_sigaction *old) {
    int h = sig_host(dsig);
    if (h <= 0 || h >= 65 || dsig == 9 || dsig == 17) { errno = 22; return -1; }   /* SIGKILL, SIGSTOP */
    struct sigaction ha, hold;
    if (sigaction(h, NULL, &hold) != 0) { errno = darwin_errno(errno); return -1; }
    if (old) {
        if (hold.sa_handler == SIG_DFL || hold.sa_handler == SIG_IGN) *old = (struct d_sigaction){ (void *)hold.sa_handler, 0, 0 };
        else *old = guest_actions[h];
        if (fatal_signal(h) && guest_actions[h].handler) *old = guest_actions[h];
    }
    if (!act) return 0;
    if (fatal_signal(h)) {
        static int warned;
        if (!warned++) fprintf(stderr, "isim: sigaction(%d): isim keeps its crash handler for fatal signals; the app's handler is not installed\n", dsig);
        guest_actions[h] = *act;
        return 0;
    }
    memset(&ha, 0, sizeof ha);
    sigset_to_host(act->mask, &ha.sa_mask);
    ha.sa_flags = (act->flags & 1 ? SA_ONSTACK : 0) | (act->flags & 2 ? SA_RESTART : 0) | (act->flags & 4 ? SA_RESETHAND : 0) |
                  (act->flags & 8 ? SA_NOCLDSTOP : 0) | (act->flags & 0x10 ? SA_NODEFER : 0) | (act->flags & 0x20 ? SA_NOCLDWAIT : 0);
    if (act->handler == NULL || act->handler == (void *)1) ha.sa_handler = (__sighandler_t)act->handler;
    else { ha.sa_flags |= SA_SIGINFO; ha.sa_sigaction = sig_info_trampoline; }
    guest_actions[h] = *act;
    guest_sig_handlers[h] = NULL;            /* signal() and sigaction() share the slot */
    return NETRET(sigaction(h, &ha, NULL));
}
static int d_sigmask(int (*fn)(int, const sigset_t *, sigset_t *), int how, const uint32_t *set, uint32_t *old) {
    int hhow = how == 1 ? SIG_BLOCK : how == 2 ? SIG_UNBLOCK : how == 3 ? SIG_SETMASK : -1;
    if (set && hhow < 0) return 22;
    sigset_t hs, ho;
    if (set) sigset_to_host(*set, &hs);
    int r = fn(hhow < 0 ? SIG_BLOCK : hhow, set ? &hs : NULL, &ho);
    if (r == 0 && old) *old = sigset_to_darwin(&ho);
    return r;
}
ISIM_GUEST_ABI static int d_pthread_sigmask(int how, const uint32_t *set, uint32_t *old) { return d_errno(d_sigmask(pthread_sigmask, how, set, old)); }
ISIM_GUEST_ABI static int d_sigprocmask(int how, const uint32_t *set, uint32_t *old) {
    int r = d_sigmask(sigprocmask, how, set, old);
    if (r) { errno = darwin_errno(r == 22 ? EINVAL : errno); return -1; }
    return 0;
}

/* ---------------- read-write locks ---------------- */
/* Darwin pthread_rwlock_t: 200 bytes, signature first (PTHREAD_RWLOCK_INITIALIZER: 0x2DA8B3B4); the host lock lives
   on the heap like conditions (struct d_cond) */
#define SIG_RWLOCK_INIT 0x2DA8B3B4L
#define SIG_RWLOCK 0x52574C4BL
struct d_rwlock { long sig; pthread_rwlock_t *host; };
static pthread_mutex_t rwlock_init_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_rwlock_t *rwlock_ready(struct d_rwlock *l) {
    if (__atomic_load_n(&l->sig, __ATOMIC_ACQUIRE) == SIG_RWLOCK) return l->host;
    pthread_mutex_lock(&rwlock_init_lock);
    if (l->sig != SIG_RWLOCK) {
        l->host = malloc(sizeof *l->host);
        pthread_rwlock_init(l->host, NULL);
        __atomic_store_n(&l->sig, SIG_RWLOCK, __ATOMIC_RELEASE);
    }
    pthread_mutex_unlock(&rwlock_init_lock);
    return l->host;
}
ISIM_GUEST_ABI static int d_rwlock_init(struct d_rwlock *l, const void *attr) { (void)attr; l->sig = SIG_RWLOCK_INIT; rwlock_ready(l); return 0; }
ISIM_GUEST_ABI static int d_rwlock_destroy(struct d_rwlock *l) { if (l->sig == SIG_RWLOCK) { pthread_rwlock_destroy(l->host); free(l->host); } l->sig = 0; return 0; }
ISIM_GUEST_ABI static int d_rwlock_rdlock(struct d_rwlock *l) { return d_errno(pthread_rwlock_rdlock(rwlock_ready(l))); }
ISIM_GUEST_ABI static int d_rwlock_wrlock(struct d_rwlock *l) { return d_errno(pthread_rwlock_wrlock(rwlock_ready(l))); }
ISIM_GUEST_ABI static int d_rwlock_tryrdlock(struct d_rwlock *l) { return d_errno(pthread_rwlock_tryrdlock(rwlock_ready(l))); }
ISIM_GUEST_ABI static int d_rwlock_trywrlock(struct d_rwlock *l) { return d_errno(pthread_rwlock_trywrlock(rwlock_ready(l))); }
ISIM_GUEST_ABI static int d_rwlock_unlock(struct d_rwlock *l) { return d_errno(pthread_rwlock_unlock(rwlock_ready(l))); }

ISIM_GUEST_ABI static int d_cond_timedwait_relative_np(struct d_cond *c, struct d_mutex *m, const struct timespec *rel) {
    struct timespec ts; clock_gettime(CLOCK_REALTIME, &ts);
    ts.tv_sec += rel->tv_sec; ts.tv_nsec += rel->tv_nsec;
    if (ts.tv_nsec >= 1000000000L) { ts.tv_sec++; ts.tv_nsec -= 1000000000L; }
    return d_cond_timedwait(c, m, &ts);
}
/* Darwin: SCHED_OTHER 1, struct sched_param { int sched_priority; char opaque[4]; }; threads run at priority 31 */
ISIM_GUEST_ABI static int d_pthread_getschedparam(pthread_t t, int *policy, int *param) {
    (void)t;
    if (policy) *policy = 1;
    if (param) *param = 31;
    return 0;
}

/* ---------------- mmap, uname ---------------- */
/* Darwin: MAP_SHARED 1, MAP_PRIVATE 2, MAP_FIXED 0x10, MAP_NORESERVE 0x40, MAP_JIT 0x800, MAP_ANON 0x1000 */
ISIM_GUEST_ABI static void *d_mmap(void *addr, size_t len, int prot, int flags, int fd, off_t off) {
    int h = (flags & 1 ? MAP_SHARED : 0) | (flags & 2 ? MAP_PRIVATE : 0) | (flags & 0x10 ? MAP_FIXED : 0) |   /* linux-only: mmap: Darwin flag bits translated to the host's */
            (flags & 0x40 ? MAP_NORESERVE : 0) | (flags & 0x1000 ? MAP_ANONYMOUS : 0);
    void *p = mmap(addr, len, prot & 7, h, flags & 0x1000 ? -1 : fd, off);
    if (p == MAP_FAILED) errno = darwin_errno(errno);
    return p;
}
ISIM_GUEST_ABI static int d_munmap(void *addr, size_t len) { return NETRET(munmap(addr, len)); }
/* Darwin struct utsname: five 256-byte fields. Adapted: like Apple's Simulator, uname describes the Mac it runs on
   (Darwin, x86_64), with the Linux host's name */
struct d_utsname { char sysname[256], nodename[256], release[256], version[256], machine[256]; };
ISIM_GUEST_ABI static int d_uname(struct d_utsname *u) {
    struct utsname h;
    if (uname(&h) != 0) { errno = darwin_errno(errno); return -1; }
    memset(u, 0, sizeof *u);
    snprintf(u->sysname, 256, "Darwin");
    snprintf(u->nodename, 256, "%s", h.nodename);
    snprintf(u->release, 256, "24.0.0");
    snprintf(u->version, 256, "Darwin Kernel Version 24.0.0 (isim on Linux %s)", h.release);
    snprintf(u->machine, 256, "x86_64");
    return 0;
}

/* ---------------- sysctl ---------------- */
/* adapted: the names apps read about the device and the process, answered like Apple's Simulator on an Intel Mac
   (hw.machine x86_64) with the host's CPU count and memory; kern.proc for the own process reports it is not being
   debugged. Other names fail with ENOENT. */
static int sysctl_put(void *old, size_t *oldlen, const void *v, size_t n) {
    if (!oldlen) return 0;
    if (!old) { *oldlen = n; return 0; }
    if (*oldlen < n) { *oldlen = n; errno = 12; return -1; }      /* ENOMEM */
    memcpy(old, v, n); *oldlen = n;
    return 0;
}
static int sysctl_str(void *old, size_t *oldlen, const char *s) { return sysctl_put(old, oldlen, s, strlen(s) + 1); }
static int sysctl_int(void *old, size_t *oldlen, int v) { return sysctl_put(old, oldlen, &v, sizeof v); }
static int sysctl_i64(void *old, size_t *oldlen, int64_t v) { return sysctl_put(old, oldlen, &v, sizeof v); }
static int sysctl_named(const char *name, void *old, size_t *oldlen) {
    long ncpu = sysconf(_SC_NPROCESSORS_ONLN);
    struct sysinfo si; sysinfo(&si);
    int64_t mem = (int64_t)si.totalram * si.mem_unit;
    if (!strcmp(name, "hw.machine")) return sysctl_str(old, oldlen, "x86_64");
    if (!strcmp(name, "hw.model")) return sysctl_str(old, oldlen, "MacBookPro16,1");
    if (!strcmp(name, "hw.ncpu") || !strcmp(name, "hw.physicalcpu") || !strcmp(name, "hw.logicalcpu") ||
        !strcmp(name, "hw.activecpu") || !strcmp(name, "hw.physicalcpu_max") || !strcmp(name, "hw.logicalcpu_max"))
        return sysctl_int(old, oldlen, (int)ncpu);
    if (!strcmp(name, "hw.memsize")) return sysctl_i64(old, oldlen, mem);
    if (!strcmp(name, "hw.physmem") || !strcmp(name, "hw.usermem")) return sysctl_int(old, oldlen, mem > 0x7fffffff ? 0x7fffffff : (int)mem);
    if (!strcmp(name, "hw.pagesize")) return sysctl_int(old, oldlen, 4096);
    if (!strcmp(name, "hw.cpufrequency")) return sysctl_i64(old, oldlen, 2400000000LL);
    if (!strcmp(name, "hw.byteorder")) return sysctl_int(old, oldlen, 1234);
    if (!strcmp(name, "hw.optional.arm64") || !strcmp(name, "sysctl.proc_translated")) return sysctl_int(old, oldlen, 0);
    if (!strcmp(name, "kern.ostype")) return sysctl_str(old, oldlen, "Darwin");
    if (!strcmp(name, "kern.osrelease")) return sysctl_str(old, oldlen, "24.0.0");
    if (!strcmp(name, "kern.osversion")) return sysctl_str(old, oldlen, "24A335");
    if (!strcmp(name, "kern.hostname")) { char h[256]; gethostname(h, sizeof h); h[255] = 0; return sysctl_str(old, oldlen, h); }
    if (!strcmp(name, "kern.boottime")) {
        struct timespec now, up; clock_gettime(CLOCK_REALTIME, &now); clock_gettime(CLOCK_BOOTTIME, &up);
        struct { long sec; int usec; int pad; } tv = { now.tv_sec - up.tv_sec, 0, 0 };
        return sysctl_put(old, oldlen, &tv, sizeof tv);
    }
    errno = 2;                                                       /* ENOENT */
    return -1;
}
ISIM_GUEST_ABI static int d_sysctlbyname(const char *name, void *old, size_t *oldlen, void *newp, size_t newlen) {
    if (newp && newlen) { errno = 1; return -1; }                    /* EPERM */
    return sysctl_named(name, old, oldlen);
}
ISIM_GUEST_ABI static int d_sysctl(int *mib, unsigned n, void *old, size_t *oldlen, void *newp, size_t newlen) {
    if (newp && newlen) { errno = 1; return -1; }
    if (n >= 2 && mib[0] == 6) {                                     /* CTL_HW */
        switch (mib[1]) {
        case 1: return sysctl_named("hw.machine", old, oldlen);
        case 2: return sysctl_named("hw.model", old, oldlen);
        case 3: case 25: return sysctl_named("hw.ncpu", old, oldlen);
        case 5: return sysctl_named("hw.physmem", old, oldlen);
        case 6: return sysctl_named("hw.usermem", old, oldlen);
        case 7: return sysctl_named("hw.pagesize", old, oldlen);
        case 15: return sysctl_named("hw.cpufrequency", old, oldlen);
        case 24: return sysctl_named("hw.memsize", old, oldlen);
        }
    } else if (n >= 2 && mib[0] == 1) {                              /* CTL_KERN */
        switch (mib[1]) {
        case 1: return sysctl_named("kern.ostype", old, oldlen);
        case 2: return sysctl_named("kern.osrelease", old, oldlen);
        case 10: return sysctl_named("kern.hostname", old, oldlen);
        case 21: return sysctl_named("kern.boottime", old, oldlen);
        case 65: return sysctl_named("kern.osversion", old, oldlen);
        case 14:                                                     /* KERN_PROC, KERN_PROC_PID, pid: struct kinfo_proc */
            if (n == 4 && mib[2] == 1) {
                unsigned char kp[648]; memset(kp, 0, sizeof kp);    /* kp_proc.p_flag (offset 32) without P_TRACED */
                int pid = mib[3];
                memcpy(kp + 40, &pid, sizeof pid);                   /* kp_proc.p_pid */
                return sysctl_put(old, oldlen, kp, sizeof kp);
            }
            break;
        }
    }
    errno = 2;
    return -1;
}

/* ---------------- Darwin <ctype.h>: rune tables ---------------- */
/* Darwin's inline isalpha()... read _DefaultRuneLocale.__runetype[c] (c < 128) and call __maskrune otherwise.
   _RuneLocale: magic[8], encoding[32], sgetrune, sputrune, invalid_rune, runetype[256], maplower[256], mapupper[256],
   then range tables and character classes (empty). Adapted: the C locale's classes for 0..255 (ASCII; no
   Latin-1 letters), wide characters through the host's wctype */
#define CT_A 0x100L
#define CT_C 0x200L
#define CT_D 0x400L
#define CT_G 0x800L
#define CT_L 0x1000L
#define CT_P 0x2000L
#define CT_S 0x4000L
#define CT_U 0x8000L
#define CT_X 0x10000L
#define CT_B 0x20000L
#define CT_R 0x40000L
#define CT_SW1 0x40000000L
struct d_runelocale {
    char magic[8], encoding[32];
    void *sgetrune, *sputrune; int32_t invalid_rune;
    uint32_t runetype[256]; int32_t maplower[256], mapupper[256];
    struct { int nranges; void *ranges; } runetype_ext, maplower_ext, mapupper_ext;
    void *variable; int variable_len; int ncharclasses; void *charclasses;
};
struct d_runelocale d_DefaultRuneLocale;
static uint32_t rune_class(int c) {
    uint32_t m = 0;
    if (c >= 128) return 0;
    if (isalpha(c)) m |= CT_A;
    if (iscntrl(c)) m |= CT_C;
    if (isdigit(c)) m |= CT_D | (uint32_t)(c - '0');
    if (isgraph(c)) m |= CT_G;
    if (islower(c)) m |= CT_L;
    if (ispunct(c)) m |= CT_P;
    if (isspace(c)) m |= CT_S;
    if (isupper(c)) m |= CT_U;
    if (isxdigit(c)) m |= CT_X | (uint32_t)(isdigit(c) ? c - '0' : (tolower(c) - 'a' + 10));
    if (c == ' ' || c == '\t') m |= CT_B;
    if (isprint(c)) m |= CT_R | CT_SW1;
    return m;
}
static void rune_init(void) {
    memcpy(d_DefaultRuneLocale.magic, "RuneMagA", 8);
    snprintf(d_DefaultRuneLocale.encoding, 32, "NONE");
    d_DefaultRuneLocale.invalid_rune = 0xFFFD;
    for (int c = 0; c < 256; c++) {
        d_DefaultRuneLocale.runetype[c] = rune_class(c);
        d_DefaultRuneLocale.maplower[c] = c < 128 ? tolower(c) : c;
        d_DefaultRuneLocale.mapupper[c] = c < 128 ? toupper(c) : c;
    }
}
ISIM_GUEST_ABI static unsigned long d_maskrune(int c, unsigned long mask) {
    if (c >= 0 && c < 256) return d_DefaultRuneLocale.runetype[c] & mask;
    uint32_t m = 0;
    if (iswalpha(c)) m |= CT_A;
    if (iswcntrl(c)) m |= CT_C;
    if (iswdigit(c)) m |= CT_D;
    if (iswgraph(c)) m |= CT_G;
    if (iswlower(c)) m |= CT_L;
    if (iswpunct(c)) m |= CT_P;
    if (iswspace(c)) m |= CT_S;
    if (iswupper(c)) m |= CT_U;
    if (iswxdigit(c)) m |= CT_X;
    if (iswblank(c)) m |= CT_B;
    if (iswprint(c)) m |= CT_R;
    return m & mask;
}
ISIM_GUEST_ABI static int d___tolower(int c) { return c >= 0 && c < 256 ? d_DefaultRuneLocale.maplower[c] : (int)towlower(c); }
ISIM_GUEST_ABI static int d___toupper(int c) { return c >= 0 && c < 256 ? d_DefaultRuneLocale.mapupper[c] : (int)towupper(c); }

/* ---------------- libunwind (unw_*) ---------------- */
/* adapted: frame-pointer unwinding of the calling thread (Apple's x86_64 code keeps frame pointers); there is no
   compact-unwind or DWARF stepping, so frames without a frame pointer end the walk. unw_context_t is Darwin's
   (21 registers: rax rbx rcx rdx rdi rsi rbp rsp r8-r15 rip rflags cs fs gs), unw_cursor_t holds the walk. */
struct d_unw_cursor { uint64_t rip, rsp, rbp, rbx; uint64_t pad[29]; };
ISIM_GUEST_ABI __attribute__((naked)) static int d_unw_getcontext(uint64_t *ctx) {
    __asm__ volatile(
        "mov %rax, 0x00(%rdi)\n mov %rbx, 0x08(%rdi)\n mov %rcx, 0x10(%rdi)\n mov %rdx, 0x18(%rdi)\n"
        "mov %rdi, 0x20(%rdi)\n mov %rsi, 0x28(%rdi)\n mov %rbp, 0x30(%rdi)\n"
        "lea 8(%rsp), %rax\n mov %rax, 0x38(%rdi)\n"                         /* the caller's rsp after return */
        "mov %r8, 0x40(%rdi)\n mov %r9, 0x48(%rdi)\n mov %r10, 0x50(%rdi)\n mov %r11, 0x58(%rdi)\n"
        "mov %r12, 0x60(%rdi)\n mov %r13, 0x68(%rdi)\n mov %r14, 0x70(%rdi)\n mov %r15, 0x78(%rdi)\n"
        "mov (%rsp), %rax\n mov %rax, 0x80(%rdi)\n"                          /* rip: the return address */
        "xor %eax, %eax\n ret\n");
}
ISIM_GUEST_ABI static int d_unw_init_local(struct d_unw_cursor *c, const uint64_t *ctx) {
    memset(c, 0, sizeof *c);
    c->rip = ctx[16]; c->rsp = ctx[7]; c->rbp = ctx[6]; c->rbx = ctx[1];
    return 0;
}
ISIM_GUEST_ABI static int d_unw_step(struct d_unw_cursor *c) {
    uint64_t fp = c->rbp;
    if (!fp || fp < c->rsp || (fp & 7) || fp - c->rsp > (64u << 20)) return 0;
    uint64_t next_fp = ((uint64_t *)fp)[0], ret = ((uint64_t *)fp)[1];
    if (!ret) return 0;
    c->rip = ret; c->rsp = fp + 16; c->rbp = next_fp;
    return 1;
}
ISIM_GUEST_ABI static int d_unw_get_reg(struct d_unw_cursor *c, int reg, uint64_t *v) {
    switch (reg) {
    case -1: case 16: *v = c->rip; return 0;          /* UNW_REG_IP */
    case -2: case 7: *v = c->rsp; return 0;           /* UNW_REG_SP, UNW_X86_64_RSP */
    case 6: *v = c->rbp; return 0;                    /* UNW_X86_64_RBP */
    case 3: *v = c->rbx; return 0;                    /* UNW_X86_64_RBX */
    default: return -6542;                            /* UNW_EBADREG */
    }
}

/* ---------------- toolchain ---------------- */
extern int __cxa_thread_atexit_impl(void (*)(void *), void *, void *);
extern void *__dso_handle;
/* Darwin's thread_local destructors: run at thread exit like glibc's */
ISIM_GUEST_ABI static void d_tlv_atexit(void (*fn)(void *), void *obj) { __cxa_thread_atexit_impl(fn, obj, &__dso_handle); }
ISIM_GUEST_ABI static void d_assert_rtn(const char *func, const char *file, int line, const char *expr) {
    fflush(NULL);
    if (func) fprintf(stderr, "Assertion failed: (%s), function %s, file %s, line %d.\n", expr, func, file, line);
    else fprintf(stderr, "Assertion failed: (%s), file %s, line %d.\n", expr, file, line);
    abort();
}
/* compiler-rt builtins for 128-bit integers (libgcc's on the host) */
extern double __floattidf(__int128); extern float __floattisf(__int128); extern double __floatuntidf(unsigned __int128);
extern float __floatuntisf(unsigned __int128); extern __int128 __fixdfti(double); extern __int128 __fixsfti(float);
extern unsigned __int128 __fixunsdfti(double); extern unsigned __int128 __fixunssfti(float);
extern __int128 __multi3(__int128, __int128);

/* ---------------- Darwin <locale.h> / <xlocale.h> ---------------- */
/* Adapted: a guest locale_t is the host's (glibc) locale object; NULL (Darwin's C locale in the _l functions) maps to
   the host's C locale, Darwin's category numbers and LC_*_MASK bits are translated, and struct lconv is rebuilt in
   Darwin's field order. setlocale() does not change the host process's global locale (isim's own code runs in the same
   process): it validates the name and records it, and localeconv() reports that locale. */
#include <locale.h>
#include <langinfo.h>
#include <stdarg.h>
#include <nl_types.h>
struct d_lconv {
    char *decimal_point, *thousands_sep, *grouping, *int_curr_symbol, *currency_symbol, *mon_decimal_point,
         *mon_thousands_sep, *mon_grouping, *positive_sign, *negative_sign;
    char int_frac_digits, frac_digits, p_cs_precedes, p_sep_by_space, n_cs_precedes, n_sep_by_space, p_sign_posn,
         n_sign_posn, int_p_cs_precedes, int_n_cs_precedes, int_p_sep_by_space, int_n_sep_by_space, int_p_sign_posn,
         int_n_sign_posn;
};
static locale_t c_locale(void) {
    static locale_t c;
    if (!c) c = newlocale(LC_ALL_MASK, "C", (locale_t)0);
    return c;
}
#define LOC(l) ((l) ? (l) : c_locale())
static const int d_lc_cat[] = { LC_ALL, LC_COLLATE, LC_CTYPE, LC_MONETARY, LC_NUMERIC, LC_TIME, LC_MESSAGES };
static int d_lc_mask(int m) {
    static const int bits[] = { LC_COLLATE_MASK, LC_CTYPE_MASK, LC_MESSAGES_MASK, LC_MONETARY_MASK, LC_NUMERIC_MASK, LC_TIME_MASK };
    int r = 0;
    for (int i = 0; i < 6; i++) if (m & (1 << i)) r |= bits[i];
    return r;
}
static locale_t d_global_locale;                     /* what the guest's setlocale chose (0: "C") */
static char d_locale_names[7][64] = { "C", "C", "C", "C", "C", "C", "C" };
static pthread_mutex_t d_locale_lock = PTHREAD_MUTEX_INITIALIZER;
ISIM_GUEST_ABI static char *d_setlocale(int cat, const char *name) {
    if (cat < 0 || cat > 6) return NULL;
    pthread_mutex_lock(&d_locale_lock);
    char *r = d_locale_names[cat];
    if (name) {
        const char *n = *name ? name : getenv("LC_ALL") && *getenv("LC_ALL") ? getenv("LC_ALL") : getenv("LANG") && *getenv("LANG") ? getenv("LANG") : "C";
        locale_t l = !strcmp(n, "C") || !strcmp(n, "POSIX") ? (locale_t)0
                   : newlocale(cat ? (1 << d_lc_cat[cat]) : LC_ALL_MASK, n, d_global_locale ? duplocale(d_global_locale) : (locale_t)0);
        if (strcmp(n, "C") && strcmp(n, "POSIX") && !l) r = NULL;
        else {
            if (!l && cat) l = newlocale(1 << d_lc_cat[cat], "C", d_global_locale ? duplocale(d_global_locale) : (locale_t)0);
            if (d_global_locale) freelocale(d_global_locale);
            d_global_locale = l;
            for (int i = cat ? cat : 1; i <= (cat ? cat : 6); i++) snprintf(d_locale_names[i], 64, "%s", n);
            if (!cat) snprintf(d_locale_names[0], 64, "%s", n);
        }
    }
    pthread_mutex_unlock(&d_locale_lock);
    return r;
}
static struct d_lconv *d_lconv_of(locale_t l) {
    static __thread struct d_lconv out;
    locale_t old = uselocale(LOC(l));
    struct lconv *h = localeconv();
    out = (struct d_lconv){ h->decimal_point, h->thousands_sep, h->grouping, h->int_curr_symbol, h->currency_symbol,
        h->mon_decimal_point, h->mon_thousands_sep, h->mon_grouping, h->positive_sign, h->negative_sign,
        h->int_frac_digits, h->frac_digits, h->p_cs_precedes, h->p_sep_by_space, h->n_cs_precedes, h->n_sep_by_space,
        h->p_sign_posn, h->n_sign_posn, h->int_p_cs_precedes, h->int_n_cs_precedes, h->int_p_sep_by_space,
        h->int_n_sep_by_space, h->int_p_sign_posn, h->int_n_sign_posn };
    uselocale(old);
    return &out;
}
ISIM_GUEST_ABI static struct d_lconv *d_localeconv(void) {
    locale_t t = uselocale((locale_t)0);
    return d_lconv_of(t == LC_GLOBAL_LOCALE ? d_global_locale : t);
}
ISIM_GUEST_ABI static struct d_lconv *d_localeconv_l(locale_t l) { return d_lconv_of(l == LC_GLOBAL_LOCALE ? d_global_locale : l); }
ISIM_GUEST_ABI static locale_t d_newlocale(int mask, const char *name, locale_t base) {
    return newlocale(d_lc_mask(mask), name ? name : "C", base == LC_GLOBAL_LOCALE ? (locale_t)0 : base);
}
ISIM_GUEST_ABI static int d_freelocale(locale_t l) { if (l && l != LC_GLOBAL_LOCALE) freelocale(l); return 0; }
ISIM_GUEST_ABI static locale_t d_duplocale(locale_t l) { return duplocale(l == LC_GLOBAL_LOCALE ? LOC(d_global_locale) : LOC(l)); }
ISIM_GUEST_ABI static locale_t d_uselocale(locale_t l) { return uselocale(l); }
ISIM_GUEST_ABI static const char *d_querylocale(int mask, locale_t l) {
    static const int cats[] = { LC_COLLATE, LC_CTYPE, LC_MESSAGES, LC_MONETARY, LC_NUMERIC, LC_TIME };
    int i = 0;
    while (i < 5 && !(mask & (1 << i))) i++;
    if (l == LC_GLOBAL_LOCALE) l = d_global_locale;
    return l ? l->__names[cats[i]] : "C";
}
ISIM_GUEST_ABI static int d_mb_cur_max_l(locale_t l) { locale_t old = uselocale(LOC(l)); int r = (int)MB_CUR_MAX; uselocale(old); return r; }
ISIM_GUEST_ABI static float d_strtof_l(const char *s, char **e, locale_t l) { return strtof_l(s, e, LOC(l)); }
ISIM_GUEST_ABI static double d_strtod_l(const char *s, char **e, locale_t l) { return strtod_l(s, e, LOC(l)); }
ISIM_GUEST_ABI static long double d_strtold_l(const char *s, char **e, locale_t l) { return strtold_l(s, e, LOC(l)); }
ISIM_GUEST_ABI static long d_strtol_l(const char *s, char **e, int b, locale_t l) { return strtol_l(s, e, b, LOC(l)); }
ISIM_GUEST_ABI static long long d_strtoll_l(const char *s, char **e, int b, locale_t l) { return strtoll_l(s, e, b, LOC(l)); }
ISIM_GUEST_ABI static unsigned long d_strtoul_l(const char *s, char **e, int b, locale_t l) { return strtoul_l(s, e, b, LOC(l)); }
ISIM_GUEST_ABI static unsigned long long d_strtoull_l(const char *s, char **e, int b, locale_t l) { return strtoull_l(s, e, b, LOC(l)); }
ISIM_GUEST_ABI static double d_atof_l(const char *s, locale_t l) { return strtod_l(s, NULL, LOC(l)); }
ISIM_GUEST_ABI static int d_toupper_l(int c, locale_t l) { return toupper_l(c, LOC(l)); }
ISIM_GUEST_ABI static int d_tolower_l(int c, locale_t l) { return tolower_l(c, LOC(l)); }
#define D_IS_L(f) ISIM_GUEST_ABI static int d_##f##_l(int c, locale_t l) { return f##_l(c, LOC(l)); }
D_IS_L(isalnum) D_IS_L(isalpha) D_IS_L(isblank) D_IS_L(iscntrl) D_IS_L(isdigit) D_IS_L(isgraph) D_IS_L(islower)
D_IS_L(isprint) D_IS_L(ispunct) D_IS_L(isspace) D_IS_L(isupper) D_IS_L(isxdigit)
ISIM_GUEST_ABI static int d_strcoll_l(const char *a, const char *b, locale_t l) { return strcoll_l(a, b, LOC(l)); }
ISIM_GUEST_ABI static size_t d_strxfrm_l(char *d, const char *s, size_t n, locale_t l) { return strxfrm_l(d, s, n, LOC(l)); }
ISIM_GUEST_ABI static int d_strcasecmp_l(const char *a, const char *b, locale_t l) { return strcasecmp_l(a, b, LOC(l)); }
ISIM_GUEST_ABI static int d_strncasecmp_l(const char *a, const char *b, size_t n, locale_t l) { return strncasecmp_l(a, b, n, LOC(l)); }
ISIM_GUEST_ABI static size_t d_strftime_l(char *s, size_t n, const char *f, const struct tm *t, locale_t l) { return strftime_l(s, n, f, t, LOC(l)); }
ISIM_GUEST_ABI static char *d_strptime_l(const char *s, const char *f, struct tm *t, locale_t l) {
    locale_t old = uselocale(LOC(l)); char *r = strptime(s, f, t); uselocale(old); return r;
}
/* the printf/scanf _l variants: the host's under the locale for this call */
ISIM_GUEST_ABI static int d_vsnprintf_l(char *s, size_t n, locale_t l, const char *f, va_list ap) {
    locale_t old = uselocale(LOC(l)); int r = vsnprintf(s, n, f, ap); uselocale(old); return r;
}
ISIM_GUEST_ABI static int d_vasprintf_l(char **s, locale_t l, const char *f, va_list ap) {
    locale_t old = uselocale(LOC(l)); int r = vasprintf(s, f, ap); uselocale(old); return r;
}
ISIM_GUEST_ABI static int d_vsscanf_l(const char *s, locale_t l, const char *f, va_list ap) {
    locale_t old = uselocale(LOC(l)); int r = vsscanf(s, f, ap); uselocale(old); return r;
}
ISIM_GUEST_ABI static int d_snprintf_l(char *s, size_t n, locale_t l, const char *f, ...) { va_list ap; va_start(ap, f); int r = d_vsnprintf_l(s, n, l, f, ap); va_end(ap); return r; }
ISIM_GUEST_ABI static int d_sprintf_l(char *s, locale_t l, const char *f, ...) { va_list ap; va_start(ap, f); int r = d_vsnprintf_l(s, (size_t)-1 >> 1, l, f, ap); va_end(ap); return r; }
ISIM_GUEST_ABI static int d_asprintf_l(char **s, locale_t l, const char *f, ...) { va_list ap; va_start(ap, f); int r = d_vasprintf_l(s, l, f, ap); va_end(ap); return r; }
ISIM_GUEST_ABI static int d_sscanf_l(const char *s, locale_t l, const char *f, ...) { va_list ap; va_start(ap, f); int r = d_vsscanf_l(s, l, f, ap); va_end(ap); return r; }
ISIM_GUEST_ABI static int d_printf_l(locale_t l, const char *f, ...) {
    va_list ap; va_start(ap, f); locale_t old = uselocale(LOC(l)); int r = vprintf(f, ap); uselocale(old); va_end(ap); return r;
}
ISIM_GUEST_ABI static int d_fprintf_l(FILE *fp, locale_t l, const char *f, ...) {
    va_list ap; va_start(ap, f); locale_t old = uselocale(LOC(l)); int r = vfprintf(fp, f, ap); uselocale(old); va_end(ap); return r;
}
#define DARWIN_LOCALE \
    A("_setlocale", d_setlocale), A("_localeconv", d_localeconv), A("_localeconv_l", d_localeconv_l), \
    A("_newlocale", d_newlocale), A("_freelocale", d_freelocale), A("_duplocale", d_duplocale), A("_uselocale", d_uselocale), \
    A("_querylocale", d_querylocale), A("____mb_cur_max_l", d_mb_cur_max_l), \
    A("_strtof_l", d_strtof_l), A("_strtod_l", d_strtod_l), A("_strtold_l", d_strtold_l), A("_strtol_l", d_strtol_l), \
    A("_strtoll_l", d_strtoll_l), A("_strtoul_l", d_strtoul_l), A("_strtoull_l", d_strtoull_l), A("_atof_l", d_atof_l), \
    A("_toupper_l", d_toupper_l), A("_tolower_l", d_tolower_l), A("_isalnum_l", d_isalnum_l), A("_isalpha_l", d_isalpha_l), \
    A("_isblank_l", d_isblank_l), A("_iscntrl_l", d_iscntrl_l), A("_isdigit_l", d_isdigit_l), A("_isgraph_l", d_isgraph_l), \
    A("_islower_l", d_islower_l), A("_isprint_l", d_isprint_l), A("_ispunct_l", d_ispunct_l), A("_isspace_l", d_isspace_l), \
    A("_isupper_l", d_isupper_l), A("_isxdigit_l", d_isxdigit_l), A("_strcoll_l", d_strcoll_l), A("_strxfrm_l", d_strxfrm_l), \
    A("_strcasecmp_l", d_strcasecmp_l), A("_strncasecmp_l", d_strncasecmp_l), A("_strftime_l", d_strftime_l), \
    A("_strptime_l", d_strptime_l), A("_snprintf_l", d_snprintf_l), A("_sprintf_l", d_sprintf_l), A("_asprintf_l", d_asprintf_l), \
    A("_vsnprintf_l", d_vsnprintf_l), A("_vasprintf_l", d_vasprintf_l), A("_sscanf_l", d_sscanf_l), A("_vsscanf_l", d_vsscanf_l), \
    A("_printf_l", d_printf_l), A("_fprintf_l", d_fprintf_l), P(catopen), P(catgets), P(catclose), \
    P(iscntrl), P(isgraph), P(isblank), P(isascii), P(toascii)

#define DARWIN_EXTRAS \
    A("_sigaction", d_sigaction), A("_pthread_sigmask", d_pthread_sigmask), A("_sigprocmask", d_sigprocmask), \
    A("_pthread_rwlock_init", d_rwlock_init), A("_pthread_rwlock_destroy", d_rwlock_destroy), \
    A("_pthread_rwlock_rdlock", d_rwlock_rdlock), A("_pthread_rwlock_wrlock", d_rwlock_wrlock), \
    A("_pthread_rwlock_tryrdlock", d_rwlock_tryrdlock), A("_pthread_rwlock_trywrlock", d_rwlock_trywrlock), \
    A("_pthread_rwlock_unlock", d_rwlock_unlock), P(pthread_atfork), \
    A("_pthread_cond_timedwait_relative_np", d_cond_timedwait_relative_np), A("_pthread_getschedparam", d_pthread_getschedparam), \
    A("_mmap", d_mmap), A("_munmap", d_munmap), A("_uname", d_uname), A("_sysctl", d_sysctl), A("_sysctlbyname", d_sysctlbyname), \
    P(strptime), P(fseeko), P(ftello), P(wcslen), \
    A("__DefaultRuneLocale", &d_DefaultRuneLocale), A("___maskrune", d_maskrune), A("___tolower", d___tolower), \
    A("___toupper", d___toupper), \
    A("_unw_getcontext", d_unw_getcontext), A("_unw_init_local", d_unw_init_local), A("_unw_step", d_unw_step), \
    A("_unw_get_reg", d_unw_get_reg), \
    A("__tlv_atexit", d_tlv_atexit), A("___assert_rtn", d_assert_rtn), \
    P(__floattidf), P(__floattisf), P(__floatuntidf), P(__floatuntisf), P(__fixdfti), P(__fixsfti), P(__fixunsdfti), \
    P(__fixunssfti), P(__multi3), DARWIN_LOCALE
