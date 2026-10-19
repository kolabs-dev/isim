/* isim libSystem: the rest of the C library and POSIX headers apps and packages compile against (issue #220):
 * memory mapping, resources and limits, extended attributes, kqueue, wide characters, POSIX regular expressions,
 * syslog, the user database, termios, OSAtomic / OSSpinLock, getopt and the remaining unistd / stdlib / string /
 * signal functions. Passthrough where Darwin and the host share the ABI, adapted where layouts or constants differ.
 * Included by libsystem.c after darwin_extras.inc (uses sig_host/sig_darwin, darwin_errno, NETRET, utf8_locale). */
#include <stdbool.h>
#include <sys/epoll.h>
#include <sys/eventfd.h>
#include <sys/resource.h>
#include <sys/timerfd.h>
#include <sys/xattr.h>
#include <getopt.h>
#include <pwd.h>
#include <regex.h>
#include <termios.h>

ISIM_GUEST_ABI void isim_log_record(int kind, int type, const char *subsystem, const char *category, const char *message,
                     const char *format, int sptype, uint64_t spid, const char *name);

/* ---------------- sys/mman.h ---------------- */
ISIM_GUEST_ABI static int d_mprotect(void *a, size_t n, int prot) { return NETRET(mprotect(a, n, prot & 7)); }
/* Darwin MS_SYNC is 0x10 (Linux 4); MS_KILLPAGES / MS_DEACTIVATE have no Linux equivalent */
ISIM_GUEST_ABI static int d_msync(void *a, size_t n, int flags) {
    int h = (flags & 1 ? MS_ASYNC : 0) | (flags & 2 ? MS_INVALIDATE : 0) | (flags & 0x10 ? MS_SYNC : 0);
    return NETRET(msync(a, n, h));
}
/* MADV_FREE is 5 on Darwin (8 on Linux); the reuse hints are Darwin's own and do nothing here */
ISIM_GUEST_ABI static int d_madvise(void *a, size_t n, int advice) {
    if (advice >= 6) return 0;
    return NETRET(madvise(a, n, advice == 5 ? MADV_FREE : advice));
}
ISIM_GUEST_ABI static int d_posix_madvise(void *a, size_t n, int advice) { return advice >= 0 && advice <= 4 ? posix_madvise(a, n, advice) : EINVAL; }
ISIM_GUEST_ABI static int d_minherit(void *a, size_t n, int inherit) { (void)a; (void)n; (void)inherit; return 0; }   /* no fork on iOS */
ISIM_GUEST_ABI static int d_mlockall(int flags) { return NETRET(mlockall((flags & 1 ? MCL_CURRENT : 0) | (flags & 2 ? MCL_FUTURE : 0))); }
ISIM_GUEST_ABI static int d_mincore(const void *a, size_t n, char *vec) { return NETRET(mincore((void *)a, n, (unsigned char *)vec)); }

/* ---------------- sys/resource.h ---------------- */
#define D_RLIM_INFINITY (((uint64_t)1 << 63) - 1)
static int rlimit_host(int d) {
    static const int map[] = { RLIMIT_CPU, RLIMIT_FSIZE, RLIMIT_DATA, RLIMIT_STACK, RLIMIT_CORE, RLIMIT_AS, RLIMIT_MEMLOCK,
                               RLIMIT_NPROC, RLIMIT_NOFILE };
    return d >= 0 && d < 9 ? map[d] : -1;
}
struct d_rlimit { uint64_t cur, max; };
static uint64_t rlim_darwin(rlim_t v) { return v == RLIM_INFINITY ? D_RLIM_INFINITY : (uint64_t)v; }
static rlim_t rlim_host(uint64_t v) { return v >= D_RLIM_INFINITY ? RLIM_INFINITY : (rlim_t)v; }
ISIM_GUEST_ABI static int d_getrlimit(int res, struct d_rlimit *out) {
    int h = rlimit_host(res);
    struct rlimit r;
    if (h < 0 || !out) { errno = EINVAL; return -1; }
    if (getrlimit(h, &r) != 0) { errno = darwin_errno(errno); return -1; }
    out->cur = rlim_darwin(r.rlim_cur); out->max = rlim_darwin(r.rlim_max);
    return 0;
}
ISIM_GUEST_ABI static int d_setrlimit(int res, const struct d_rlimit *in) {
    int h = rlimit_host(res);
    if (h < 0 || !in) { errno = EINVAL; return -1; }
    struct rlimit r = { rlim_host(in->cur), rlim_host(in->max) };
    return NETRET(setrlimit(h, &r));
}
/* the same layout (a Darwin timeval is 16 bytes too); ru_maxrss is in bytes on Darwin, kilobytes on Linux */
struct d_rusage { struct d_timeval utime, stime; long maxrss, rest[13]; };
ISIM_GUEST_ABI static int d_getrusage(int who, struct d_rusage *out) {
    struct rusage r;
    if (getrusage(who == -1 ? RUSAGE_CHILDREN : who == 0 ? RUSAGE_SELF : who, &r) != 0) { errno = darwin_errno(errno); return -1; }
    out->utime = (struct d_timeval){ r.ru_utime.tv_sec, (int)r.ru_utime.tv_usec };
    out->stime = (struct d_timeval){ r.ru_stime.tv_sec, (int)r.ru_stime.tv_usec };
    out->maxrss = r.ru_maxrss * 1024;
    long rest[13] = { r.ru_ixrss, r.ru_idrss, r.ru_isrss, r.ru_minflt, r.ru_majflt, r.ru_nswap, r.ru_inblock, r.ru_oublock,
                      r.ru_msgsnd, r.ru_msgrcv, r.ru_nsignals, r.ru_nvcsw, r.ru_nivcsw };
    memcpy(out->rest, rest, sizeof rest);
    return 0;
}
ISIM_GUEST_ABI static int d_getpriority(int which, unsigned id) {
    if (which > 2) return 0;                                         /* PRIO_DARWIN_THREAD / PROCESS: default */
    errno = 0;
    int r = getpriority(which, id);
    if (r == -1 && errno) errno = darwin_errno(errno);
    return r;
}
ISIM_GUEST_ABI static int d_setpriority(int which, unsigned id, int prio) { return which > 2 ? 0 : NETRET(setpriority(which, id, prio)); }

/* ---------------- sys/xattr.h ---------------- */
/* adapted: Darwin's attribute names live in the host's "user." namespace; `position` (resource forks) must be 0;
   ENODATA is Darwin's ENOATTR (93) */
static int xattr_name(const char *name, char *out, size_t n) {
    if (!name || !*name) { errno = EINVAL; return -1; }
    if ((size_t)snprintf(out, n, "user.%s", name) >= n) { errno = 63; return -1; }   /* ENAMETOOLONG */
    return 0;
}
static int xattr_errno(int e) { return e == ENODATA ? 93 : e == ENOTSUP ? 45 : darwin_errno(e); }
#define XRET(expr) ({ __typeof__(expr) r_ = (expr); if (r_ < 0) errno = xattr_errno(errno); r_; })
ISIM_GUEST_ABI static ssize_t d_getxattr(const char *path, const char *name, void *value, size_t size, uint32_t pos, int opts) {
    char n[300];
    if (pos) { errno = EINVAL; return -1; }
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(opts & 1 ? lgetxattr(path, n, value, size) : getxattr(path, n, value, size));
}
ISIM_GUEST_ABI static ssize_t d_fgetxattr(int fd, const char *name, void *value, size_t size, uint32_t pos, int opts) {
    char n[300]; (void)opts;
    if (pos) { errno = EINVAL; return -1; }
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(fgetxattr(fd, n, value, size));
}
static int xattr_set_flags(int opts) { return (opts & 2 ? XATTR_CREATE : 0) | (opts & 4 ? XATTR_REPLACE : 0); }
ISIM_GUEST_ABI static int d_setxattr(const char *path, const char *name, const void *value, size_t size, uint32_t pos, int opts) {
    char n[300];
    if (pos) { errno = EINVAL; return -1; }
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(opts & 1 ? lsetxattr(path, n, value, size, xattr_set_flags(opts)) : setxattr(path, n, value, size, xattr_set_flags(opts)));
}
ISIM_GUEST_ABI static int d_fsetxattr(int fd, const char *name, const void *value, size_t size, uint32_t pos, int opts) {
    char n[300];
    if (pos) { errno = EINVAL; return -1; }
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(fsetxattr(fd, n, value, size, xattr_set_flags(opts)));
}
ISIM_GUEST_ABI static int d_removexattr(const char *path, const char *name, int opts) {
    char n[300];
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(opts & 1 ? lremovexattr(path, n) : removexattr(path, n));
}
ISIM_GUEST_ABI static int d_fremovexattr(int fd, const char *name, int opts) {
    char n[300]; (void)opts;
    if (xattr_name(name, n, sizeof n) < 0) return -1;
    return XRET(fremovexattr(fd, n));
}
/* the "user." names without their prefix, NUL-separated */
static ssize_t xattr_list_darwin(ssize_t len, char *all, char *out, size_t size) {
    ssize_t need = 0;
    for (char *p = all; p < all + len; p += strlen(p) + 1) if (!strncmp(p, "user.", 5)) need += (ssize_t)strlen(p + 5) + 1;
    if (!out || !size) return need;
    if ((size_t)need > size) { errno = 34; return -1; }               /* ERANGE */
    char *w = out;
    for (char *p = all; p < all + len; p += strlen(p) + 1)
        if (!strncmp(p, "user.", 5)) { size_t l = strlen(p + 5) + 1; memcpy(w, p + 5, l); w += l; }
    return need;
}
ISIM_GUEST_ABI static ssize_t d_listxattr(const char *path, char *out, size_t size, int opts) {
    ssize_t len = opts & 1 ? llistxattr(path, NULL, 0) : listxattr(path, NULL, 0);
    if (len < 0) { errno = xattr_errno(errno); return -1; }
    char *all = malloc((size_t)len + 1);
    len = opts & 1 ? llistxattr(path, all, (size_t)len) : listxattr(path, all, (size_t)len);
    ssize_t r = len < 0 ? (errno = xattr_errno(errno), -1) : xattr_list_darwin(len, all, out, size);
    free(all);
    return r;
}
ISIM_GUEST_ABI static ssize_t d_flistxattr(int fd, char *out, size_t size, int opts) {
    (void)opts;
    ssize_t len = flistxattr(fd, NULL, 0);
    if (len < 0) { errno = xattr_errno(errno); return -1; }
    char *all = malloc((size_t)len + 1);
    len = flistxattr(fd, all, (size_t)len);
    ssize_t r = len < 0 ? (errno = xattr_errno(errno), -1) : xattr_list_darwin(len, all, out, size);
    free(all);
    return r;
}

/* ---------------- sys/event.h: kqueue on epoll ---------------- */
/* adapted: a kqueue is an epoll instance; EVFILT_READ / EVFILT_WRITE watch the descriptor, EVFILT_TIMER uses a timerfd
   and EVFILT_USER an eventfd. Each registered descriptor has one epoll entry whose mask joins its enabled filters. */
struct d_kevent { uintptr_t ident; int16_t filter; uint16_t flags; uint32_t fflags; intptr_t data; void *udata; };
#define KEV_ADD 0x1
#define KEV_DELETE 0x2
#define KEV_ENABLE 0x4
#define KEV_DISABLE 0x8
#define KEV_ONESHOT 0x10
#define KEV_CLEAR 0x20
#define KEV_RECEIPT 0x40
#define KEV_DISPATCH 0x80
#define KEV_ERROR 0x4000
#define KEV_EOF 0x8000
struct kq_reg { uintptr_t ident; int16_t filter; uint16_t flags; uint32_t fflags; intptr_t data; void *udata; int enabled;
                int hostfd; struct kq_watch *watch; struct kq_reg *next; };
struct kq_watch { int fd; struct kq_reg *read, *write, *other; };   /* other: the timer / user registration on its own fd */
struct kq { int epfd; struct kq_reg *regs; pthread_mutex_t lock; };
static struct kq *kqs[4096];
static pthread_mutex_t kq_table_lock = PTHREAD_MUTEX_INITIALIZER;
static struct kq *kq_for(int fd) {
    pthread_mutex_lock(&kq_table_lock);
    struct kq *k = fd >= 0 && fd < 4096 ? kqs[fd] : NULL;
    pthread_mutex_unlock(&kq_table_lock);
    return k;
}
ISIM_GUEST_ABI static int d_kqueue(void) {
    int ep = epoll_create1(EPOLL_CLOEXEC);   /* linux-only: kqueue over epoll / task memory from procfs (libSystem) */
    if (ep < 0) { errno = darwin_errno(errno); return -1; }
    if (ep >= 4096) { close(ep); errno = 24; return -1; }             /* EMFILE */
    struct kq *k = calloc(1, sizeof *k);
    k->epfd = ep; pthread_mutex_init(&k->lock, NULL);
    pthread_mutex_lock(&kq_table_lock);
    struct kq *old = kqs[ep];                                          /* an earlier kqueue closed with close(2) */
    kqs[ep] = k;
    pthread_mutex_unlock(&kq_table_lock);
    if (old) {
        for (struct kq_reg *r = old->regs, *n; r; r = n) { n = r->next; if (r->filter == -7 || r->filter == -10) close(r->hostfd); free(r); }
        free(old);
    }
    return ep;
}
static void kq_update(struct kq *k, struct kq_watch *w) {
    uint32_t ev = 0;
    int clear = 0;
    if (w->read && w->read->enabled) { ev |= EPOLLIN | EPOLLRDHUP; clear |= w->read->flags & KEV_CLEAR; }
    if (w->write && w->write->enabled) { ev |= EPOLLOUT; clear |= w->write->flags & KEV_CLEAR; }
    if (w->other && w->other->enabled) ev |= EPOLLIN;
    if (clear) ev |= EPOLLET;
    struct epoll_event e = { .events = ev, .data.ptr = w };
    if (epoll_ctl(k->epfd, EPOLL_CTL_MOD, w->fd, &e) != 0) epoll_ctl(k->epfd, EPOLL_CTL_ADD, w->fd, &e);   /* linux-only: kqueue over epoll / task memory from procfs (libSystem) */
}
static struct kq_watch *kq_watch_for(struct kq *k, int fd) {
    for (struct kq_reg *r = k->regs; r; r = r->next) if (r->watch && r->watch->fd == fd && r->filter != -7 && r->filter != -10) return r->watch;
    struct kq_watch *w = calloc(1, sizeof *w);
    w->fd = fd;
    return w;
}
static int kq_timer_set(struct kq_reg *r) {
    int64_t v = r->data;
    struct timespec t;
    if (r->fflags & 4) t = (struct timespec){ v / 1000000000, v % 1000000000 };                 /* NOTE_NSECONDS */
    else if (r->fflags & 2) t = (struct timespec){ v / 1000000, (v % 1000000) * 1000 };       /* NOTE_USECONDS */
    else if (r->fflags & 1) t = (struct timespec){ v, 0 };                                      /* NOTE_SECONDS */
    else t = (struct timespec){ v / 1000, (v % 1000) * 1000000 };                               /* milliseconds */
    if (!t.tv_sec && !t.tv_nsec) t.tv_nsec = 1;
    struct itimerspec its = { (r->flags & KEV_ONESHOT) ? (struct timespec){ 0, 0 } : t, t };
    return timerfd_settime(r->hostfd, 0, &its, NULL);
}
static void kq_remove(struct kq *k, struct kq_reg *r) {
    for (struct kq_reg **pp = &k->regs; *pp; pp = &(*pp)->next) if (*pp == r) { *pp = r->next; break; }
    struct kq_watch *w = r->watch;
    if (w->read == r) w->read = NULL;
    if (w->write == r) w->write = NULL;
    if (w->other == r) w->other = NULL;
    if (!w->read && !w->write && !w->other) { epoll_ctl(k->epfd, EPOLL_CTL_DEL, w->fd, NULL); free(w); }   /* linux-only: kqueue over epoll / task memory from procfs (libSystem) */
    else kq_update(k, w);
    if (r->filter == -7 || r->filter == -10) close(r->hostfd);
    free(r);
}
/* one change; returns 0 or a Darwin errno */
static int kq_change(struct kq *k, const struct d_kevent *c) {
    struct kq_reg *r = NULL;
    for (r = k->regs; r && !(r->ident == c->ident && r->filter == c->filter); r = r->next) {}
    if (c->filter != -1 && c->filter != -2 && c->filter != -7 && c->filter != -10) return 22;            /* EINVAL */
    if (c->flags & KEV_DELETE) { if (!r) return 2; kq_remove(k, r); return 0; }                     /* ENOENT */
    if (!r) {
        if (!(c->flags & KEV_ADD)) return 2;
        r = calloc(1, sizeof *r);
        r->ident = c->ident; r->filter = c->filter;
        if (c->filter == -7) r->hostfd = timerfd_create(CLOCK_MONOTONIC, TFD_CLOEXEC | TFD_NONBLOCK);
        else if (c->filter == -10) r->hostfd = eventfd(0, EFD_CLOEXEC | EFD_NONBLOCK);
        else r->hostfd = (int)c->ident;
        if (r->hostfd < 0) { int e = darwin_errno(errno); free(r); return e; }
        if (c->filter == -1 || c->filter == -2) {
            struct stat st;
            if (fstat(r->hostfd, &st) != 0) { free(r); return 9; }                                  /* EBADF */
            r->watch = kq_watch_for(k, r->hostfd);
            if (c->filter == -1) r->watch->read = r; else r->watch->write = r;
        } else {
            r->watch = calloc(1, sizeof *r->watch);
            r->watch->fd = r->hostfd; r->watch->other = r;
        }
        r->next = k->regs; k->regs = r;
        r->enabled = 1;
    }
    r->flags = (r->flags & ~(KEV_ONESHOT | KEV_CLEAR | KEV_DISPATCH)) | (c->flags & (KEV_ONESHOT | KEV_CLEAR | KEV_DISPATCH));
    if (c->flags & KEV_ADD) { r->udata = c->udata; r->enabled = 1; }
    if (c->flags & KEV_ENABLE) r->enabled = 1;
    if (c->flags & KEV_DISABLE) r->enabled = 0;
    if (c->filter == -10) {                                            /* EVFILT_USER: NOTE_FF* then NOTE_TRIGGER */
        uint32_t ff = c->fflags & 0x00ffffff;
        switch (c->fflags & 0xc0000000) {
        case 0x40000000: r->fflags &= ff; break;                       /* NOTE_FFAND */
        case 0x80000000: r->fflags |= ff; break;                       /* NOTE_FFOR */
        case 0xc0000000: r->fflags = ff; break;                        /* NOTE_FFCOPY */
        }
        if (c->fflags & 0x01000000) { uint64_t one = 1; if (write(r->hostfd, &one, sizeof one) < 0) {} }
    } else if (c->flags & KEV_ADD) {
        r->fflags = c->fflags; r->data = c->data;
        if (c->filter == -7 && kq_timer_set(r) != 0) { int e = darwin_errno(errno); kq_remove(k, r); return e; }
    }
    kq_update(k, r->watch);
    return 0;
}
/* fill one Darwin event from a ready registration; returns 0 when there is nothing to report after all */
static int kq_fire(struct kq *k, struct kq_reg *r, uint32_t ev, struct d_kevent *out) {
    *out = (struct d_kevent){ r->ident, r->filter, 0, 0, 0, r->udata };
    if (r->filter == -1) {
        int n = 0;
        if (ioctl(r->hostfd, FIONREAD, &n) != 0) n = 1;
        out->data = n;
        if (ev & (EPOLLHUP | EPOLLRDHUP | EPOLLERR)) out->flags |= KEV_EOF;
    } else if (r->filter == -2) {
        int space = 0, sz = 0; socklen_t l = sizeof sz;
        if (getsockopt(r->hostfd, SOL_SOCKET, SO_SNDBUF, &sz, &l) == 0 && ioctl(r->hostfd, TIOCOUTQ, &space) == 0) out->data = sz - space;
        else out->data = 65536;
        if (ev & (EPOLLHUP | EPOLLERR)) out->flags |= KEV_EOF;
    } else {                                                           /* timer expirations / user trigger */
        uint64_t count = 0;
        if (read(r->hostfd, &count, sizeof count) != sizeof count) return 0;
        out->data = r->filter == -7 ? (intptr_t)count : 0;
        out->fflags = r->filter == -10 ? r->fflags : 0;
    }
    if (r->flags & KEV_ONESHOT) kq_remove(k, r);
    else if (r->flags & KEV_DISPATCH) { r->enabled = 0; kq_update(k, r->watch); }
    return 1;
}
ISIM_GUEST_ABI static int d_kevent(int kqfd, const struct d_kevent *changes, int nchanges, struct d_kevent *events, int nevents, const struct timespec *timeout) {
    struct kq *k = kq_for(kqfd);
    if (!k) { errno = 9; return -1; }                                  /* EBADF */
    int out = 0;
    pthread_mutex_lock(&k->lock);
    for (int i = 0; i < nchanges; i++) {
        int e = kq_change(k, &changes[i]);
        if (e || (changes[i].flags & KEV_RECEIPT)) {
            if (out < nevents) { events[out] = changes[i]; events[out].flags = KEV_ERROR; events[out].data = e; out++; }
            else if (e) { pthread_mutex_unlock(&k->lock); errno = e; return -1; }
        }
    }
    pthread_mutex_unlock(&k->lock);
    if (out || nevents <= 0) return out;
    int ms = !timeout ? -1 : (int)(timeout->tv_sec * 1000 + (timeout->tv_nsec + 999999) / 1000000);
    struct epoll_event ev[64];
    for (;;) {
        int n = epoll_wait(k->epfd, ev, nevents < 64 ? nevents : 64, ms);   /* linux-only: kqueue over epoll / task memory from procfs (libSystem) */
        if (n < 0) { if (errno == EINTR) errno = 4; else errno = darwin_errno(errno); return -1; }
        pthread_mutex_lock(&k->lock);
        for (int i = 0; i < n && out < nevents; i++) {
            struct kq_watch *w = ev[i].data.ptr;
            struct kq_reg *rr = w->read, *wr = w->write, *other = w->other;
            if (rr && rr->enabled && (ev[i].events & (EPOLLIN | EPOLLHUP | EPOLLRDHUP | EPOLLERR)) && out < nevents) out += kq_fire(k, rr, ev[i].events, &events[out]);
            if (wr && wr->enabled && (ev[i].events & (EPOLLOUT | EPOLLHUP | EPOLLERR)) && out < nevents) out += kq_fire(k, wr, ev[i].events, &events[out]);
            if (other && other->enabled && (ev[i].events & EPOLLIN) && out < nevents) out += kq_fire(k, other, ev[i].events, &events[out]);
        }
        pthread_mutex_unlock(&k->lock);
        if (out || n == 0) return out;                                 /* spurious (a drained timer): wait again */
    }
}
struct d_kevent64 { uint64_t ident; int16_t filter; uint16_t flags; uint32_t fflags; int64_t data; uint64_t udata; uint64_t ext[2]; };
ISIM_GUEST_ABI static int d_kevent64(int kq, const struct d_kevent64 *changes, int nchanges, struct d_kevent64 *events, int nevents,
                      unsigned flags, const struct timespec *timeout) {
    struct d_kevent *c = calloc((size_t)(nchanges > 0 ? nchanges : 1), sizeof *c), *e = calloc((size_t)(nevents > 0 ? nevents : 1), sizeof *e);
    for (int i = 0; i < nchanges; i++)
        c[i] = (struct d_kevent){ (uintptr_t)changes[i].ident, changes[i].filter, changes[i].flags, changes[i].fflags,
                                  (intptr_t)changes[i].data, (void *)(uintptr_t)changes[i].udata };
    struct timespec zero = { 0, 0 };
    int n = d_kevent(kq, c, nchanges, e, nevents, flags & 1 ? &zero : timeout);   /* KEVENT_FLAG_IMMEDIATE */
    for (int i = 0; i < n; i++)
        events[i] = (struct d_kevent64){ e[i].ident, e[i].filter, e[i].flags, e[i].fflags, e[i].data, (uint64_t)(uintptr_t)e[i].udata, { 0, 0 } };
    free(c); free(e);
    return n;
}

/* ---------------- wchar.h: multibyte conversions in UTF-8 ---------------- */
/* adapted: like an app under a UTF-8 locale (the host process's own locale is left alone) */
#define IN_UTF8(expr) ({ locale_t l_ = utf8_locale(), o_ = l_ ? uselocale(l_) : (locale_t)0; __typeof__(expr) r_ = (expr); if (l_) uselocale(o_); r_; })
ISIM_GUEST_ABI static size_t d_mbrtowc(wchar_t *w, const char *s, size_t n, mbstate_t *st) { return IN_UTF8(mbrtowc(w, s, n, st)); }
ISIM_GUEST_ABI static size_t d_mbrlen(const char *s, size_t n, mbstate_t *st) { return IN_UTF8(mbrlen(s, n, st)); }
ISIM_GUEST_ABI static size_t d_wcrtomb(char *s, wchar_t w, mbstate_t *st) { return IN_UTF8(wcrtomb(s, w, st)); }
ISIM_GUEST_ABI static size_t d_mbstowcs(wchar_t *w, const char *s, size_t n) { return IN_UTF8(mbstowcs(w, s, n)); }
ISIM_GUEST_ABI static size_t d_wcstombs(char *s, const wchar_t *w, size_t n) { return IN_UTF8(wcstombs(s, w, n)); }
ISIM_GUEST_ABI static size_t d_mbsrtowcs(wchar_t *w, const char **s, size_t n, mbstate_t *st) { return IN_UTF8(mbsrtowcs(w, s, n, st)); }
ISIM_GUEST_ABI static size_t d_wcsrtombs(char *s, const wchar_t **w, size_t n, mbstate_t *st) { return IN_UTF8(wcsrtombs(s, w, n, st)); }
ISIM_GUEST_ABI static size_t d_mbsnrtowcs(wchar_t *w, const char **s, size_t nms, size_t n, mbstate_t *st) { return IN_UTF8(mbsnrtowcs(w, s, nms, n, st)); }
ISIM_GUEST_ABI static size_t d_wcsnrtombs(char *s, const wchar_t **w, size_t nwc, size_t n, mbstate_t *st) { return IN_UTF8(wcsnrtombs(s, w, nwc, n, st)); }
ISIM_GUEST_ABI static int d_mbtowc(wchar_t *w, const char *s, size_t n) { return IN_UTF8(mbtowc(w, s, n)); }
ISIM_GUEST_ABI static int d_wctomb(char *s, wchar_t w) { return IN_UTF8(wctomb(s, w)); }
ISIM_GUEST_ABI static wint_t d_btowc(int c) { return IN_UTF8(btowc(c)); }
ISIM_GUEST_ABI static int d_wctob(wint_t c) { return IN_UTF8(wctob(c)); }
ISIM_GUEST_ABI static int d_wcwidth(wchar_t c) { return IN_UTF8(wcwidth(c)); }
ISIM_GUEST_ABI static int d_wcswidth(const wchar_t *s, size_t n) { return IN_UTF8(wcswidth(s, n)); }
ISIM_GUEST_ABI static size_t d_wcslcpy(wchar_t *d, const wchar_t *s, size_t n) {
    size_t l = wcslen(s);
    if (n) { size_t c = l < n - 1 ? l : n - 1; wmemcpy(d, s, c); d[c] = 0; }
    return l;
}
ISIM_GUEST_ABI static size_t d_wcslcat(wchar_t *d, const wchar_t *s, size_t n) {
    size_t dl = wcsnlen(d, n);
    return dl == n ? n + wcslen(s) : dl + d_wcslcpy(d + dl, s, n - dl);
}

/* ---------------- regex.h ---------------- */
/* Darwin's regex_t keeps the host's compiled expression in re_g; offsets are 64-bit; flags and codes are translated */
struct d_regex { int magic; size_t nsub; const char *endp; regex_t *g; };
struct d_regmatch { int64_t so, eo; };
static int regerr_darwin(int e) { return e == REG_ESIZE ? 12 : e == REG_ERPAREN ? 8 : e == REG_EEND ? 14 : e; }
ISIM_GUEST_ABI static int d_regcomp(struct d_regex *re, const char *pattern, int dflags) {
    int f = (dflags & 1 ? REG_EXTENDED : 0) | (dflags & 2 ? REG_ICASE : 0) | (dflags & 4 ? REG_NOSUB : 0) | (dflags & 8 ? REG_NEWLINE : 0);
    if (dflags & 0400) return 16;                                      /* REG_ENHANCED: REG_INVARG */
    regex_t *g = calloc(1, sizeof *g);
    char *copy = NULL;
    if (dflags & 040) { copy = strndup(pattern, (size_t)(re->endp - pattern)); pattern = copy; }   /* REG_PEND */
    if (dflags & 020) {                                                /* REG_NOSPEC: a literal string */
        size_t n = strlen(pattern);
        char *lit = malloc(2 * n + 1), *w = lit;
        for (const char *p = pattern; *p; p++) { if (strchr(".[]()*+?{}|^$\\", *p)) *w++ = '\\'; *w++ = *p; }
        *w = 0; free(copy); copy = lit; pattern = lit; f |= REG_EXTENDED;
    }
    int r = IN_UTF8(regcomp(g, pattern, f));
    free(copy);
    if (r) { free(g); return regerr_darwin(r); }
    re->magic = 0xf1234; re->nsub = g->re_nsub; re->g = g;
    return 0;
}
ISIM_GUEST_ABI static int d_regexec(const struct d_regex *re, const char *s, size_t n, struct d_regmatch *m, int eflags) {
    if (!re || !re->g) return 16;
    int f = (eflags & 1 ? REG_NOTBOL : 0) | (eflags & 2 ? REG_NOTEOL : 0) | (eflags & 4 ? REG_STARTEND : 0);
    regmatch_t *h = n ? calloc(n, sizeof *h) : NULL;
    if ((eflags & 4) && m) {
        if (!h) { h = calloc(1, sizeof *h); }
        h[0].rm_so = (regoff_t)m[0].so; h[0].rm_eo = (regoff_t)m[0].eo;
    }
    int r = IN_UTF8(regexec(re->g, s, n, h, f));
    for (size_t i = 0; r == 0 && m && i < n; i++) { m[i].so = h[i].rm_so; m[i].eo = h[i].rm_eo; }
    free(h);
    return r == REG_NOMATCH ? 1 : regerr_darwin(r);
}
ISIM_GUEST_ABI static size_t d_regerror(int code, const struct d_regex *re, char *buf, size_t n) {
    static const char *msg[] = { "success", "regexec() failed to match", "invalid regular expression", "invalid collating element",
                                 "invalid character class", "trailing backslash (\\)", "invalid backreference number",
                                 "brackets ([ ]) not balanced", "parentheses not balanced", "braces not balanced",
                                 "invalid repetition count(s)", "invalid character range", "out of memory",
                                 "repetition-operator operand invalid", "empty (sub)expression", "cannot happen",
                                 "invalid argument to regex routine", "illegal byte sequence" };
    (void)re;
    const char *s = code >= 0 && code < 18 ? msg[code] : "unknown regexec error";
    size_t l = strlen(s) + 1;
    if (buf && n) { size_t c = l < n ? l : n; memcpy(buf, s, c - 1); buf[c - 1] = 0; }
    return l;
}
ISIM_GUEST_ABI static void d_regfree(struct d_regex *re) { if (re && re->g) { regfree(re->g); free(re->g); re->g = NULL; } }

/* ---------------- syslog.h: to the unified log, as on iOS ---------------- */
static char syslog_ident[64]; static int syslog_opts, syslog_mask = 0xff;
ISIM_GUEST_ABI static void d_openlog(const char *ident, int opts, int facility) {
    (void)facility;
    snprintf(syslog_ident, sizeof syslog_ident, "%s", ident ? ident : "");
    syslog_opts = opts;
}
ISIM_GUEST_ABI static void d_closelog(void) { syslog_ident[0] = 0; syslog_opts = 0; }
ISIM_GUEST_ABI static int d_setlogmask(int mask) { int old = syslog_mask; if (mask) syslog_mask = mask; return old; }
ISIM_GUEST_ABI static void d_vsyslog(int pri, const char *fmt, va_list ap) {
    if (!(syslog_mask & (1 << (pri & 7)))) return;
    int saved = errno;
    char f[2048], msg[4096];
    size_t w = 0;
    for (const char *p = fmt; *p && w < sizeof f - 64; p++) {          /* %m: the error message */
        if (p[0] == '%' && p[1] == 'm') { w += (size_t)snprintf(f + w, sizeof f - w, "%s", strerror(saved)); p++; }
        else if (p[0] == '%' && p[1] == '%') { f[w++] = '%'; f[w++] = '%'; p++; }
        else f[w++] = *p;
    }
    f[w] = 0;
    vsnprintf(msg, sizeof msg, f, ap);
    static const uint8_t types[8] = { 0x11, 0x11, 0x11, 0x10, 0x00, 0x00, 0x01, 0x02 };   /* fault, error, default, info, debug */
    isim_log_record(0, types[pri & 7], "syslog", syslog_ident, msg, fmt, 0, 0, "");
    if (syslog_opts & 0x20) {                                          /* LOG_PERROR */
        if (syslog_opts & 1) fprintf(stderr, "%s[%d]: %s\n", syslog_ident[0] ? syslog_ident : "", (int)getpid(), msg);
        else fprintf(stderr, "%s%s%s\n", syslog_ident, syslog_ident[0] ? ": " : "", msg);
    }
}
ISIM_GUEST_ABI static void d_syslog(int pri, const char *fmt, ...) { va_list ap; va_start(ap, fmt); d_vsyslog(pri, fmt, ap); va_end(ap); }

/* ---------------- pwd.h: the device's one user ---------------- */
/* adapted: like an iOS device, the app runs as "mobile"; its home is the app's home directory (HOME) */
struct d_passwd { char *name, *passwd; uid_t uid; gid_t gid; long change; char *cls, *gecos, *dir, *shell; long expire; };
static struct d_passwd pw_entry;
static __thread int pw_iter;
static char pw_home[1024];
static struct d_passwd *pw_fill(struct d_passwd *p, char *buf, size_t n) {
    const char *home = getenv("HOME");
    snprintf(pw_home, sizeof pw_home, "%s", home && *home ? home : "/var/mobile");
    const char *strs[] = { "mobile", "*", "", "Mobile User", pw_home, "/bin/sh" };
    char *out[6];
    if (buf) {
        size_t w = 0;
        for (int i = 0; i < 6; i++) {
            size_t l = strlen(strs[i]) + 1;
            if (w + l > n) return NULL;
            memcpy(buf + w, strs[i], l); out[i] = buf + w; w += l;
        }
    } else for (int i = 0; i < 6; i++) out[i] = (char *)strs[i];
    *p = (struct d_passwd){ out[0], out[1], getuid(), getgid(), 0, out[2], out[3], out[4], out[5], 0 };
    return p;
}
ISIM_GUEST_ABI static struct d_passwd *d_getpwuid(uid_t uid) { return uid == getuid() ? pw_fill(&pw_entry, NULL, 0) : NULL; }
ISIM_GUEST_ABI static struct d_passwd *d_getpwnam(const char *name) { return name && !strcmp(name, "mobile") ? pw_fill(&pw_entry, NULL, 0) : NULL; }
ISIM_GUEST_ABI static int d_getpwuid_r(uid_t uid, struct d_passwd *p, char *buf, size_t n, struct d_passwd **out) {
    *out = NULL;
    if (uid != getuid()) return 0;
    if (!pw_fill(p, buf, n)) return 34;                                /* ERANGE */
    *out = p;
    return 0;
}
ISIM_GUEST_ABI static int d_getpwnam_r(const char *name, struct d_passwd *p, char *buf, size_t n, struct d_passwd **out) {
    *out = NULL;
    if (!name || strcmp(name, "mobile")) return 0;
    if (!pw_fill(p, buf, n)) return 34;
    *out = p;
    return 0;
}
ISIM_GUEST_ABI static struct d_passwd *d_getpwent(void) { return pw_iter++ ? NULL : pw_fill(&pw_entry, NULL, 0); }
ISIM_GUEST_ABI static void d_setpwent(void) { pw_iter = 0; }
ISIM_GUEST_ABI static void d_endpwent(void) { pw_iter = 0; }
ISIM_GUEST_ABI static char *d_getlogin(void) { return "mobile"; }
ISIM_GUEST_ABI static int d_getlogin_r(char *buf, size_t n) { if (n < 7) return 34; memcpy(buf, "mobile", 7); return 0; }

/* ---------------- termios.h ---------------- */
struct d_termios { unsigned long iflag, oflag, cflag, lflag; unsigned char cc[20]; unsigned long ispeed, ospeed; };
static const struct { unsigned long d; tcflag_t h; } t_iflags[] = {
    { 0x1, IGNBRK }, { 0x2, BRKINT }, { 0x4, IGNPAR }, { 0x8, PARMRK }, { 0x10, INPCK }, { 0x20, ISTRIP }, { 0x40, INLCR },
    { 0x80, IGNCR }, { 0x100, ICRNL }, { 0x200, IXON }, { 0x400, IXOFF }, { 0x800, IXANY }, { 0x2000, IMAXBEL }, { 0x4000, IUTF8 } };
static const struct { unsigned long d; tcflag_t h; } t_oflags[] = {
    { 0x1, OPOST }, { 0x2, ONLCR }, { 0x4, TAB3 }, { 0x10, OCRNL }, { 0x20, ONOCR }, { 0x40, ONLRET } };
static const struct { unsigned long d; tcflag_t h; } t_cflags[] = {
    { 0x400, CSTOPB }, { 0x800, CREAD }, { 0x1000, PARENB }, { 0x2000, PARODD }, { 0x4000, HUPCL }, { 0x8000, CLOCAL }, { 0x30000, CRTSCTS } };
static const struct { unsigned long d; tcflag_t h; } t_lflags[] = {
    { 0x1, ECHOKE }, { 0x2, ECHOE }, { 0x4, ECHOK }, { 0x8, ECHO }, { 0x10, ECHONL }, { 0x20, ECHOPRT }, { 0x40, ECHOCTL },
    { 0x80, ISIG }, { 0x100, ICANON }, { 0x400, IEXTEN }, { 0x800, EXTPROC }, { 0x400000, TOSTOP }, { 0x800000, FLUSHO },
    { 0x20000000, PENDIN }, { 0x80000000UL, NOFLSH } };
static const struct { int d, h; } t_cc[] = {
    { 0, VEOF }, { 1, VEOL }, { 2, VEOL2 }, { 3, VERASE }, { 4, VWERASE }, { 5, VKILL }, { 6, VREPRINT }, { 8, VINTR }, { 9, VQUIT },
    { 10, VSUSP }, { 12, VSTART }, { 13, VSTOP }, { 14, VLNEXT }, { 15, VDISCARD }, { 16, VMIN }, { 17, VTIME } };
static const struct { unsigned long d; speed_t h; } t_speeds[] = {
    { 0, B0 }, { 50, B50 }, { 75, B75 }, { 110, B110 }, { 134, B134 }, { 150, B150 }, { 200, B200 }, { 300, B300 }, { 600, B600 },
    { 1200, B1200 }, { 1800, B1800 }, { 2400, B2400 }, { 4800, B4800 }, { 9600, B9600 }, { 19200, B19200 }, { 38400, B38400 },
    { 57600, B57600 }, { 115200, B115200 }, { 230400, B230400 } };
static speed_t speed_host(unsigned long d) { for (size_t i = 0; i < sizeof t_speeds / sizeof *t_speeds; i++) if (t_speeds[i].d == d) return t_speeds[i].h; return B9600; }
static unsigned long speed_darwin(speed_t h) { for (size_t i = 0; i < sizeof t_speeds / sizeof *t_speeds; i++) if (t_speeds[i].h == h) return t_speeds[i].d; return 9600; }
static void termios_to_darwin(const struct termios *h, struct d_termios *d) {
    memset(d, 0, sizeof *d);
    for (size_t i = 0; i < sizeof t_iflags / sizeof *t_iflags; i++) if (h->c_iflag & t_iflags[i].h) d->iflag |= t_iflags[i].d;
    for (size_t i = 0; i < sizeof t_oflags / sizeof *t_oflags; i++) if ((h->c_oflag & t_oflags[i].h) == t_oflags[i].h) d->oflag |= t_oflags[i].d;
    for (size_t i = 0; i < sizeof t_cflags / sizeof *t_cflags; i++) if ((h->c_cflag & t_cflags[i].h) == t_cflags[i].h) d->cflag |= t_cflags[i].d;
    for (size_t i = 0; i < sizeof t_lflags / sizeof *t_lflags; i++) if (h->c_lflag & t_lflags[i].h) d->lflag |= t_lflags[i].d;
    tcflag_t cs = h->c_cflag & CSIZE;
    d->cflag |= cs == CS8 ? 0x300 : cs == CS7 ? 0x200 : cs == CS6 ? 0x100 : 0;
    memset(d->cc, 0xff, sizeof d->cc);                                 /* _POSIX_VDISABLE */
    for (size_t i = 0; i < sizeof t_cc / sizeof *t_cc; i++) d->cc[t_cc[i].d] = h->c_cc[t_cc[i].h];
    d->ispeed = speed_darwin(cfgetispeed(h)); d->ospeed = speed_darwin(cfgetospeed(h));
}
static void termios_to_host(const struct d_termios *d, struct termios *h) {
    memset(h, 0, sizeof *h);
    for (size_t i = 0; i < sizeof t_iflags / sizeof *t_iflags; i++) if (d->iflag & t_iflags[i].d) h->c_iflag |= t_iflags[i].h;
    for (size_t i = 0; i < sizeof t_oflags / sizeof *t_oflags; i++) if (d->oflag & t_oflags[i].d) h->c_oflag |= t_oflags[i].h;
    for (size_t i = 0; i < sizeof t_cflags / sizeof *t_cflags; i++) if ((d->cflag & t_cflags[i].d) == t_cflags[i].d) h->c_cflag |= t_cflags[i].h;
    for (size_t i = 0; i < sizeof t_lflags / sizeof *t_lflags; i++) if (d->lflag & t_lflags[i].d) h->c_lflag |= t_lflags[i].h;
    unsigned long cs = d->cflag & 0x300;
    h->c_cflag |= cs == 0x300 ? CS8 : cs == 0x200 ? CS7 : cs == 0x100 ? CS6 : CS5;
    for (size_t i = 0; i < sizeof t_cc / sizeof *t_cc; i++) h->c_cc[t_cc[i].h] = d->cc[t_cc[i].d];
    cfsetispeed(h, speed_host(d->ispeed)); cfsetospeed(h, speed_host(d->ospeed));
}
ISIM_GUEST_ABI static int d_tcgetattr(int fd, struct d_termios *d) {
    struct termios h;
    if (tcgetattr(fd, &h) != 0) { errno = darwin_errno(errno); return -1; }
    termios_to_darwin(&h, d);
    return 0;
}
ISIM_GUEST_ABI static int d_tcsetattr(int fd, int when, const struct d_termios *d) {
    struct termios h;
    termios_to_host(d, &h);
    int w = (when & ~0x10) == 1 ? TCSADRAIN : (when & ~0x10) == 2 ? TCSAFLUSH : TCSANOW;
    return NETRET(tcsetattr(fd, w, &h));
}
ISIM_GUEST_ABI static unsigned long d_cfgetispeed(const struct d_termios *d) { return d->ispeed; }
ISIM_GUEST_ABI static unsigned long d_cfgetospeed(const struct d_termios *d) { return d->ospeed; }
ISIM_GUEST_ABI static int d_cfsetispeed(struct d_termios *d, unsigned long s) { d->ispeed = s; return 0; }
ISIM_GUEST_ABI static int d_cfsetospeed(struct d_termios *d, unsigned long s) { d->ospeed = s; return 0; }
ISIM_GUEST_ABI static int d_cfsetspeed(struct d_termios *d, unsigned long s) { d->ispeed = d->ospeed = s; return 0; }
ISIM_GUEST_ABI static void d_cfmakeraw(struct d_termios *d) {
    d->iflag &= ~(0x1UL | 0x2 | 0x8 | 0x20 | 0x40 | 0x80 | 0x100 | 0x200 | 0x2000);
    d->oflag &= ~0x1UL;
    d->lflag &= ~(0x8UL | 0x10 | 0x100 | 0x80 | 0x400 | 0x800 | 0x2 | 0x1 | 0x40 | 0x20);
    d->cflag &= ~(0x300UL | 0x1000); d->cflag |= 0x300;
    d->cc[16] = 1; d->cc[17] = 0;
}
ISIM_GUEST_ABI static int d_tcflush(int fd, int q) { return NETRET(tcflush(fd, q == 1 ? TCIFLUSH : q == 2 ? TCOFLUSH : TCIOFLUSH)); }
ISIM_GUEST_ABI static int d_tcflow(int fd, int a) { return NETRET(tcflow(fd, a == 1 ? TCOOFF : a == 2 ? TCOON : a == 3 ? TCIOFF : TCION)); }
ISIM_GUEST_ABI static int d_tcdrain(int fd) { return NETRET(tcdrain(fd)); }
ISIM_GUEST_ABI static int d_tcsendbreak(int fd, int d) { return NETRET(tcsendbreak(fd, d)); }
ISIM_GUEST_ABI static pid_t d_tcgetsid(int fd) { return NETRET(tcgetsid(fd)); }
ISIM_GUEST_ABI static pid_t d_tcgetpgrp(int fd) { return NETRET(tcgetpgrp(fd)); }
ISIM_GUEST_ABI static int d_tcsetpgrp(int fd, pid_t p) { return NETRET(tcsetpgrp(fd, p)); }

/* ---------------- libkern/OSAtomic.h ---------------- */
ISIM_GUEST_ABI static int32_t d_OSAtomicAdd32(int32_t v, volatile int32_t *p) { return __atomic_add_fetch(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicIncrement32(volatile int32_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicDecrement32(volatile int32_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int64_t d_OSAtomicAdd64(int64_t v, volatile int64_t *p) { return __atomic_add_fetch(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int64_t d_OSAtomicIncrement64(volatile int64_t *p) { return __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int64_t d_OSAtomicDecrement64(volatile int64_t *p) { return __atomic_sub_fetch(p, 1, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicOr32(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_or_fetch(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicOr32Orig(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_fetch_or(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicAnd32(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_and_fetch(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicAnd32Orig(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_fetch_and(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicXor32(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_xor_fetch(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static int32_t d_OSAtomicXor32Orig(uint32_t v, volatile uint32_t *p) { return (int32_t)__atomic_fetch_xor(p, v, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static bool d_OSAtomicCompareAndSwap32(int32_t o, int32_t n, volatile int32_t *p) { return __atomic_compare_exchange_n(p, &o, n, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static bool d_OSAtomicCompareAndSwap64(int64_t o, int64_t n, volatile int64_t *p) { return __atomic_compare_exchange_n(p, &o, n, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static bool d_OSAtomicCompareAndSwapPtr(void *o, void *n, void *volatile *p) { return __atomic_compare_exchange_n(p, &o, n, 0, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST); }
/* bit n counts from the most significant bit of the first byte, as Apple's */
ISIM_GUEST_ABI static bool d_OSAtomicTestAndSet(uint32_t n, volatile void *addr) {
    volatile uint8_t *b = (volatile uint8_t *)addr + (n >> 3); uint8_t mask = (uint8_t)(0x80 >> (n & 7));
    return (__atomic_fetch_or(b, mask, __ATOMIC_SEQ_CST) & mask) != 0;
}
ISIM_GUEST_ABI static bool d_OSAtomicTestAndClear(uint32_t n, volatile void *addr) {
    volatile uint8_t *b = (volatile uint8_t *)addr + (n >> 3); uint8_t mask = (uint8_t)(0x80 >> (n & 7));
    return (__atomic_fetch_and(b, (uint8_t)~mask, __ATOMIC_SEQ_CST) & mask) != 0;
}
ISIM_GUEST_ABI static void d_OSMemoryBarrier(void) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }
ISIM_GUEST_ABI static bool d_OSSpinLockTry(volatile int32_t *l) { int32_t z = 0; return __atomic_compare_exchange_n(l, &z, -1, 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED); }
ISIM_GUEST_ABI static void d_OSSpinLockLock(volatile int32_t *l) { for (int spins = 0; !d_OSSpinLockTry(l); spins++) if (spins > 100) sched_yield(); }
ISIM_GUEST_ABI static void d_OSSpinLockUnlock(volatile int32_t *l) { __atomic_store_n(l, 0, __ATOMIC_RELEASE); }
/* OSAtomicEnqueue / Dequeue: a LIFO linked through the element's link field at `offset`, under one lock */
static pthread_mutex_t osq_lock = PTHREAD_MUTEX_INITIALIZER;
ISIM_GUEST_ABI static void d_OSAtomicEnqueue(void **head, void *elem, size_t offset) {
    pthread_mutex_lock(&osq_lock);
    *(void **)((char *)elem + offset) = head[0]; head[0] = elem;
    pthread_mutex_unlock(&osq_lock);
}
ISIM_GUEST_ABI static void *d_OSAtomicDequeue(void **head, size_t offset) {
    pthread_mutex_lock(&osq_lock);
    void *e = head[0];
    if (e) head[0] = *(void **)((char *)e + offset);
    pthread_mutex_unlock(&osq_lock);
    return e;
}

/* ---------------- unistd / stdlib / string / signal ---------------- */
ISIM_GUEST_ABI static int d_sigemptyset(uint32_t *s) { *s = 0; return 0; }
ISIM_GUEST_ABI static int d_sigfillset(uint32_t *s) { *s = 0xffffffffu; return 0; }
ISIM_GUEST_ABI static int d_sigaddset(uint32_t *s, int n) { if (n <= 0 || n > 31) { errno = 22; return -1; } *s |= 1u << (n - 1); return 0; }
ISIM_GUEST_ABI static int d_sigdelset(uint32_t *s, int n) { if (n <= 0 || n > 31) { errno = 22; return -1; } *s &= ~(1u << (n - 1)); return 0; }
ISIM_GUEST_ABI static int d_sigismember(const uint32_t *s, int n) { if (n <= 0 || n > 31) { errno = 22; return -1; } return (*s >> (n - 1)) & 1; }
ISIM_GUEST_ABI static int d_sigpending(uint32_t *out) { sigset_t h; if (sigpending(&h) != 0) return -1; *out = sigset_to_darwin(&h); return 0; }
ISIM_GUEST_ABI static int d_sigsuspend(const uint32_t *m) { sigset_t h; sigset_to_host(*m, &h); int r = sigsuspend(&h); if (r < 0) errno = errno == EINTR ? 4 : darwin_errno(errno); return r; }
ISIM_GUEST_ABI static int d_sigwait(const uint32_t *m, int *sig) { sigset_t h; int s = 0; sigset_to_host(*m, &h); int r = sigwait(&h, &s); if (!r) *sig = sig_darwin(s); return r ? darwin_errno(r) : 0; }
struct d_stack { void *sp; size_t size; int flags; };
ISIM_GUEST_ABI static int d_sigaltstack(const struct d_stack *ss, struct d_stack *old) {
    stack_t h, o;
    if (ss) h = (stack_t){ ss->sp, (ss->flags & 4 ? SS_DISABLE : 0), ss->size };
    if (sigaltstack(ss ? &h : NULL, old ? &o : NULL) != 0) { errno = darwin_errno(errno); return -1; }
    if (old) *old = (struct d_stack){ o.ss_sp, o.ss_size, (o.ss_flags & SS_ONSTACK ? 1 : 0) | (o.ss_flags & SS_DISABLE ? 4 : 0) };
    return 0;
}
/* siginterrupt as glibc implements it (its own is deprecated): a flag clears SA_RESTART on the handler, 0 sets it */
ISIM_GUEST_ABI static int d_siginterrupt(int sig, int flag) {
    int h = sig_host(sig);
    if (h <= 0) { errno = 22; return -1; }
    struct sigaction sa;
    if (sigaction(h, NULL, &sa) != 0) return -1;
    if (flag) sa.sa_flags &= ~SA_RESTART; else sa.sa_flags |= SA_RESTART;
    return sigaction(h, &sa, NULL);
}
/* mktemp: the template's trailing Xs replaced until no file has the name (adapted: glibc's mktemp makes the linker
   warn, and Darwin keeps the call) */
ISIM_GUEST_ABI static char *d_mktemp(char *t) {
    size_t n = t ? strlen(t) : 0, x = 0;
    while (x < n && t[n - 1 - x] == 'X') x++;
    if (x < 3) { if (t && n) t[0] = 0; errno = 22; return t; }
    static const char chars[] = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
    for (int tries = 0; tries < 1000; tries++) {
        unsigned char r[64];
        if (getentropy(r, x < sizeof r ? x : sizeof r) != 0) break;
        for (size_t i = 0; i < x; i++) t[n - x + i] = chars[r[i % sizeof r] % (sizeof chars - 1)];
        struct stat st;
        if (lstat(t, &st) != 0 && errno == ENOENT) return t;
    }
    t[0] = 0; errno = 17;
    return t;
}
ISIM_GUEST_ABI static int d_killpg(pid_t pg, int sig) { int h = sig ? sig_host(sig) : 0; if (h < 0) { errno = 22; return -1; } return NETRET(killpg(pg, h)); }
ISIM_GUEST_ABI static void d_psignal(int sig, const char *s) { psignal(sig_host(sig) > 0 ? sig_host(sig) : sig, s); }
ISIM_GUEST_ABI static char *d_strsignal(int sig) { return strsignal(sig_host(sig) > 0 ? sig_host(sig) : sig); }
/* adapted: the iOS sandbox gives an app no new processes and no other identity */
static int deny_eperm(void) { errno = 1; return -1; }
ISIM_GUEST_ABI static pid_t d_fork(void) { return deny_eperm(); }
ISIM_GUEST_ABI static int d_execv(const char *p, char *const a[]) { (void)p; (void)a; return deny_eperm(); }
ISIM_GUEST_ABI static int d_execve(const char *p, char *const a[], char *const e[]) { (void)p; (void)a; (void)e; return deny_eperm(); }
ISIM_GUEST_ABI static int d_execl(const char *p, const char *a, ...) { (void)p; (void)a; return deny_eperm(); }
ISIM_GUEST_ABI static int d_setid(unsigned id) { return id == getuid() ? 0 : deny_eperm(); }
ISIM_GUEST_ABI static int d_issetugid(void) { return 0; }
ISIM_GUEST_ABI static int d_setpgid(pid_t p, pid_t g) { return NETRET(setpgid(p, g)); }
ISIM_GUEST_ABI static pid_t d_setsid(void) { return NETRET(setsid()); }
ISIM_GUEST_ABI static int d_lockf(int fd, int cmd, off_t len) { return NETRET(lockf(fd, cmd, len)); }
ISIM_GUEST_ABI static long d_pathconf(const char *p, int name) { return name >= 1 && name <= 9 ? pathconf(p, name - 1) : (errno = 22, -1); }
ISIM_GUEST_ABI static long d_fpathconf(int fd, int name) { return name >= 1 && name <= 9 ? fpathconf(fd, name - 1) : (errno = 22, -1); }
/* getopt: Darwin's optreset restarts the scan (glibc: optind = 0) */
int d_optreset;
ISIM_GUEST_ABI static int d_getopt(int argc, char *const argv[], const char *opts) {
    if (d_optreset) { d_optreset = 0; optind = 0; }
    return getopt(argc, argv, opts);
}
ISIM_GUEST_ABI static void *d_reallocf(void *p, size_t n) { void *r = realloc(p, n); if (!r && n) free(p); return r; }
/* Darwin's qsort_r passes its thunk first; glibc's passes it last */
struct qsort_thunk { void *thunk; int (*cmp)(void *, const void *, const void *); };
static int qsort_r_cmp(const void *a, const void *b, void *t) { struct qsort_thunk *q = t; return q->cmp(q->thunk, a, b); }
ISIM_GUEST_ABI static void d_qsort_r(void *base, size_t n, size_t size, void *thunk, int (*cmp)(void *, const void *, const void *)) {
    struct qsort_thunk q = { thunk, cmp };
    qsort_r(base, n, size, qsort_r_cmp, &q);
}
ISIM_GUEST_ABI static int d_heapsort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *)) { qsort(base, n, size, cmp); return 0; }
ISIM_GUEST_ABI static int d_mergesort(void *base, size_t n, size_t size, int (*cmp)(const void *, const void *)) { qsort(base, n, size, cmp); return 0; }
ISIM_GUEST_ABI static const char *d_getprogname(void) { return program_invocation_short_name; }
ISIM_GUEST_ABI static void d_setprogname(const char *n) { const char *s = strrchr(n, '/'); program_invocation_short_name = (char *)(s ? s + 1 : n); }
ISIM_GUEST_ABI static long long d_strtonum(const char *s, long long lo, long long hi, const char **err) {
    char *end; long long v = 0;
    errno = 0;
    if (lo > hi) { if (err) *err = "invalid"; errno = 22; return 0; }
    v = strtoll(s, &end, 10);
    if (end == s || *end) { if (err) *err = "invalid"; errno = 22; return 0; }
    if (v < lo || errno == ERANGE) { if (err) *err = "too small"; errno = 34; return 0; }
    if (v > hi) { if (err) *err = "too large"; errno = 34; return 0; }
    if (err) *err = NULL;
    return v;
}
ISIM_GUEST_ABI static char *d_strnstr(const char *s, const char *find, size_t n) {
    size_t l = strlen(find);
    if (!l) return (char *)s;
    for (; n >= l && *s; s++, n--) if (!strncmp(s, find, l)) return (char *)s;
    return NULL;
}
ISIM_GUEST_ABI static int d_fls(int v) { return v ? 32 - __builtin_clz((unsigned)v) : 0; }
ISIM_GUEST_ABI static int d_flsl(long v) { return v ? 64 - __builtin_clzl((unsigned long)v) : 0; }
ISIM_GUEST_ABI static int d_ffsl(long v) { return __builtin_ffsl(v); }
ISIM_GUEST_ABI static int d_ffsll(long long v) { return __builtin_ffsll(v); }
ISIM_GUEST_ABI static int d_getentropy(void *b, size_t n) { if (n > 256) { errno = 5; return -1; } return NETRET(getentropy(b, n)); }   /* EIO */
ISIM_GUEST_ABI static int d_getloadavg(double *l, int n) { return getloadavg(l, n); }

/* ---------------- os/proc.h ---------------- */
/* adapted: the simulated device's per-app limit (3 GB) minus the app's resident size */
ISIM_GUEST_ABI static size_t d_os_proc_available_memory(void) {
    long pages = 0, resident = 0;
    FILE *f = fopen("/proc/self/statm", "r");   /* linux-only: kqueue over epoll / task memory from procfs (libSystem) */
    if (f) { if (fscanf(f, "%ld %ld", &pages, &resident) != 2) resident = 0; fclose(f); }
    size_t used = (size_t)resident * (size_t)sysconf(_SC_PAGESIZE), limit = (size_t)3 << 30;
    return used < limit ? limit - used : 0;
}

/* ---------------- sysctlnametomib: the names d_sysctl knows ---------------- */
ISIM_GUEST_ABI static int d_sysctlnametomib(const char *name, int *mib, size_t *n) {
    static const struct { const char *name; int a, b; } names[] = {
        { "hw.machine", 6, 1 }, { "hw.model", 6, 2 }, { "hw.ncpu", 6, 3 }, { "hw.physmem", 6, 5 }, { "hw.usermem", 6, 6 },
        { "hw.pagesize", 6, 7 }, { "hw.cpufrequency", 6, 15 }, { "hw.memsize", 6, 24 }, { "hw.activecpu", 6, 25 },
        { "kern.ostype", 1, 1 }, { "kern.osrelease", 1, 2 }, { "kern.hostname", 1, 10 }, { "kern.proc", 1, 14 },
        { "kern.boottime", 1, 21 }, { "kern.osversion", 1, 65 },
    };
    if (!name || !mib || !n) { errno = 22; return -1; }
    for (size_t i = 0; i < sizeof names / sizeof *names; i++)
        if (!strcmp(name, names[i].name)) {
            if (*n < 2) { errno = 12; return -1; }                       /* ENOMEM */
            mib[0] = names[i].a; mib[1] = names[i].b; *n = 2;
            return 0;
        }
    errno = 2;
    return -1;
}

#define LIBC_EXTRAS_SHIMS \
    A("_mprotect", d_mprotect), A("_msync", d_msync), A("_madvise", d_madvise), A("_posix_madvise", d_posix_madvise), \
    A("_minherit", d_minherit), P(mlock), P(munlock), A("_mlockall", d_mlockall), P(munlockall), A("_mincore", d_mincore), \
    A("_getrlimit", d_getrlimit), A("_setrlimit", d_setrlimit), A("_getrusage", d_getrusage), A("_getpriority", d_getpriority), \
    A("_setpriority", d_setpriority), \
    A("_getxattr", d_getxattr), A("_fgetxattr", d_fgetxattr), A("_setxattr", d_setxattr), A("_fsetxattr", d_fsetxattr), \
    A("_removexattr", d_removexattr), A("_fremovexattr", d_fremovexattr), A("_listxattr", d_listxattr), A("_flistxattr", d_flistxattr), \
    A("_kqueue", d_kqueue), A("_kevent", d_kevent), A("_kevent64", d_kevent64), \
    A("_mbrtowc", d_mbrtowc), A("_mbrlen", d_mbrlen), A("_wcrtomb", d_wcrtomb), A("_mbstowcs", d_mbstowcs), A("_wcstombs", d_wcstombs), \
    A("_mbsrtowcs", d_mbsrtowcs), A("_wcsrtombs", d_wcsrtombs), A("_mbsnrtowcs", d_mbsnrtowcs), A("_wcsnrtombs", d_wcsnrtombs), \
    A("_mbtowc", d_mbtowc), A("_wctomb", d_wctomb), A("_btowc", d_btowc), A("_wctob", d_wctob), \
    A("_wcwidth", d_wcwidth), A("_wcswidth", d_wcswidth), I("_wcslcpy", d_wcslcpy), I("_wcslcat", d_wcslcat), P(mbsinit), \
    P(wcscat), P(wcschr), P(wcscmp), P(wcscoll), P(wcscpy), P(wcscspn), P(wcsftime), P(wcsnlen), P(wcsncat), P(wcsncmp), P(wcsncpy), \
    P(wcspbrk), P(wcsrchr), P(wcsspn), P(wcsstr), P(wcstok), P(wcsxfrm), P(wcsdup), P(wcscasecmp), P(wcsncasecmp), \
    P(wcstod), P(wcstof), P(wcstold), P(wcstol), P(wcstoll), P(wcstoul), P(wcstoull), P(wmemchr), P(wmemcmp), P(wmemcpy), \
    P(wmemmove), P(wmemset), P(swprintf), P(vswprintf), P(swscanf), P(fwide), P(fgetwc), P(fgetws), P(fputwc), P(fputws), P(getwc), \
    P(getwchar), P(putwc), P(putwchar), P(ungetwc), P(fwprintf), P(wprintf), P(vfwprintf), P(vwprintf), \
    A("_regcomp", d_regcomp), A("_regexec", d_regexec), A("_regerror", d_regerror), A("_regfree", d_regfree), \
    A("_openlog", d_openlog), A("_closelog", d_closelog), A("_setlogmask", d_setlogmask), A("_syslog", d_syslog), A("_vsyslog", d_vsyslog), \
    A("_getpwuid", d_getpwuid), A("_getpwnam", d_getpwnam), A("_getpwuid_r", d_getpwuid_r), A("_getpwnam_r", d_getpwnam_r), \
    A("_getpwent", d_getpwent), A("_setpwent", d_setpwent), A("_endpwent", d_endpwent), A("_getlogin", d_getlogin), A("_getlogin_r", d_getlogin_r), \
    A("_tcgetattr", d_tcgetattr), A("_tcsetattr", d_tcsetattr), A("_cfgetispeed", d_cfgetispeed), A("_cfgetospeed", d_cfgetospeed), \
    A("_cfsetispeed", d_cfsetispeed), A("_cfsetospeed", d_cfsetospeed), A("_cfsetspeed", d_cfsetspeed), A("_cfmakeraw", d_cfmakeraw), \
    A("_tcflush", d_tcflush), A("_tcflow", d_tcflow), A("_tcdrain", d_tcdrain), A("_tcsendbreak", d_tcsendbreak), A("_tcgetsid", d_tcgetsid), \
    A("_tcgetpgrp", d_tcgetpgrp), A("_tcsetpgrp", d_tcsetpgrp), \
    I("_OSAtomicAdd32", d_OSAtomicAdd32), I("_OSAtomicAdd32Barrier", d_OSAtomicAdd32), I("_OSAtomicIncrement32", d_OSAtomicIncrement32), \
    I("_OSAtomicIncrement32Barrier", d_OSAtomicIncrement32), I("_OSAtomicDecrement32", d_OSAtomicDecrement32), \
    I("_OSAtomicDecrement32Barrier", d_OSAtomicDecrement32), I("_OSAtomicAdd64", d_OSAtomicAdd64), I("_OSAtomicAdd64Barrier", d_OSAtomicAdd64), \
    I("_OSAtomicIncrement64", d_OSAtomicIncrement64), I("_OSAtomicIncrement64Barrier", d_OSAtomicIncrement64), \
    I("_OSAtomicDecrement64", d_OSAtomicDecrement64), I("_OSAtomicDecrement64Barrier", d_OSAtomicDecrement64), \
    I("_OSAtomicOr32", d_OSAtomicOr32), I("_OSAtomicOr32Barrier", d_OSAtomicOr32), I("_OSAtomicOr32Orig", d_OSAtomicOr32Orig), \
    I("_OSAtomicOr32OrigBarrier", d_OSAtomicOr32Orig), I("_OSAtomicAnd32", d_OSAtomicAnd32), I("_OSAtomicAnd32Barrier", d_OSAtomicAnd32), \
    I("_OSAtomicAnd32Orig", d_OSAtomicAnd32Orig), I("_OSAtomicAnd32OrigBarrier", d_OSAtomicAnd32Orig), I("_OSAtomicXor32", d_OSAtomicXor32), \
    I("_OSAtomicXor32Barrier", d_OSAtomicXor32), I("_OSAtomicXor32Orig", d_OSAtomicXor32Orig), I("_OSAtomicXor32OrigBarrier", d_OSAtomicXor32Orig), \
    I("_OSAtomicCompareAndSwap32", d_OSAtomicCompareAndSwap32), I("_OSAtomicCompareAndSwap32Barrier", d_OSAtomicCompareAndSwap32), \
    I("_OSAtomicCompareAndSwapInt", d_OSAtomicCompareAndSwap32), I("_OSAtomicCompareAndSwapIntBarrier", d_OSAtomicCompareAndSwap32), \
    I("_OSAtomicCompareAndSwap64", d_OSAtomicCompareAndSwap64), I("_OSAtomicCompareAndSwap64Barrier", d_OSAtomicCompareAndSwap64), \
    I("_OSAtomicCompareAndSwapLong", d_OSAtomicCompareAndSwap64), I("_OSAtomicCompareAndSwapLongBarrier", d_OSAtomicCompareAndSwap64), \
    I("_OSAtomicCompareAndSwapPtr", d_OSAtomicCompareAndSwapPtr), I("_OSAtomicCompareAndSwapPtrBarrier", d_OSAtomicCompareAndSwapPtr), \
    I("_OSAtomicTestAndSet", d_OSAtomicTestAndSet), I("_OSAtomicTestAndSetBarrier", d_OSAtomicTestAndSet), \
    I("_OSAtomicTestAndClear", d_OSAtomicTestAndClear), I("_OSAtomicTestAndClearBarrier", d_OSAtomicTestAndClear), \
    I("_OSMemoryBarrier", d_OSMemoryBarrier), I("_OSSpinLockTry", d_OSSpinLockTry), I("_OSSpinLockLock", d_OSSpinLockLock), \
    I("_OSSpinLockUnlock", d_OSSpinLockUnlock), I("_OSAtomicEnqueue", d_OSAtomicEnqueue), I("_OSAtomicDequeue", d_OSAtomicDequeue), \
    A("_sigemptyset", d_sigemptyset), A("_sigfillset", d_sigfillset), A("_sigaddset", d_sigaddset), A("_sigdelset", d_sigdelset), \
    A("_sigismember", d_sigismember), A("_sigpending", d_sigpending), A("_sigsuspend", d_sigsuspend), A("_sigwait", d_sigwait), \
    A("_sigaltstack", d_sigaltstack), A("_siginterrupt", d_siginterrupt), A("_killpg", d_killpg), A("_psignal", d_psignal), \
    A("_strsignal", d_strsignal), \
    A("_fork", d_fork), A("_vfork", d_fork), A("_execv", d_execv), A("_execve", d_execve), A("_execvp", d_execv), A("_execl", d_execl), \
    A("_execlp", d_execl), A("_setuid", d_setid), A("_setgid", d_setid), A("_seteuid", d_setid), A("_setegid", d_setid), \
    I("_issetugid", d_issetugid), P(getppid), P(getpgrp), P(getpgid), A("_setpgid", d_setpgid), A("_setsid", d_setsid), P(getsid), \
    P(geteuid), P(getgid), P(getegid), P(getgroups), P(ttyname), P(ttyname_r), P(alarm), P(pause), P(fchdir), P(fchown), \
    P(truncate), P(fdatasync), P(sync), A("_lockf", d_lockf), P(nice), P(getdtablesize), P(mkstemp), P(mkstemps), P(mkdtemp), \
    A("_mktemp", d_mktemp), A("_getentropy", d_getentropy), P(swab), A("_pathconf", d_pathconf), A("_fpathconf", d_fpathconf), \
    A("_getopt", d_getopt), I("_optarg", &optarg), I("_optind", &optind), I("_opterr", &opterr), I("_optopt", &optopt), \
    I("_optreset", &d_optreset), \
    I("_reallocf", d_reallocf), P(valloc), P(putenv), A("_qsort_r", d_qsort_r), I("_heapsort", d_heapsort), I("_mergesort", d_mergesort), \
    P(rand_r), P(drand48), P(erand48), P(lrand48), P(nrand48), P(mrand48), P(jrand48), P(srand48), P(seed48), \
    I("_getprogname", d_getprogname), I("_setprogname", d_setprogname), I("_strtonum", d_strtonum), I("_strtoq", strtoll), \
    I("_strtouq", strtoull), A("_getloadavg", d_getloadavg), \
    P(strsep), P(strcasestr), I("_strnstr", d_strnstr), P(memmem), P(memccpy), P(stpcpy), P(stpncpy), P(bcopy), P(bcmp), P(index), \
    P(rindex), P(ffs), I("_ffsl", d_ffsl), I("_ffsll", d_ffsll), I("_fls", d_fls), I("_flsl", d_flsl), I("_flsll", d_flsl), \
    I("_os_proc_available_memory", d_os_proc_available_memory), A("_sysctlnametomib", d_sysctlnametomib), \
    P(asctime_r), P(ctime_r), I("_timelocal", mktime), I("_tzname", tzname)
