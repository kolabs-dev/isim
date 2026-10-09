/* isim libSystem: more POSIX for guests (pipe, pread/pwrite, dup, kill, signal numbers).
 * Included by libsystem.c after sockets.inc (uses NETRET/darwin_errno).
 * Darwin and Linux disagree on several signal numbers (SIGUSR1 is 30 on Darwin, 10 on Linux, ...): guests use
 * Darwin numbers; signal()/raise()/kill() translate, and guest handlers receive Darwin numbers. */
#include <signal.h>
#include <sys/inotify.h>
#include <sys/ioctl.h>
#include <sys/socket.h>
#include <linux/sockios.h>
#include <netinet/in.h>
#include <netinet/tcp.h>

static int sig_host(int d) {
    switch (d) {
    case 7: return -1;            /* SIGEMT: none on Linux */
    case 10: return SIGBUS;
    case 12: return SIGSYS;
    case 16: return SIGURG;
    case 17: return SIGSTOP;
    case 18: return SIGTSTP;
    case 19: return SIGCONT;
    case 20: return SIGCHLD;
    case 21: return SIGTTIN;
    case 22: return SIGTTOU;
    case 23: return SIGIO;
    case 24: return SIGXCPU;
    case 25: return SIGXFSZ;
    case 26: return SIGVTALRM;
    case 27: return SIGPROF;
    case 28: return SIGWINCH;
    case 29: return -1;           /* SIGINFO */
    case 30: return SIGUSR1;
    case 31: return SIGUSR2;
    default: return d >= 0 && d <= 15 ? d : -1;   /* 0..15 except the above match */
    }
}
static int sig_darwin(int h) {
    for (int d = 1; d < 32; d++) if (sig_host(d) == h) return d;
    return h;
}
typedef void (*d_sighandler)(int);
static d_sighandler guest_sig_handlers[65];
static void sig_trampoline(int h) {
    d_sighandler f = h > 0 && h < 65 ? guest_sig_handlers[h] : NULL;
    if (f) f(sig_darwin(h));
}
static d_sighandler d_signal(int dsig, d_sighandler f) {
    int h = sig_host(dsig);
    if (h <= 0 || h >= 65) { errno = 22 /* EINVAL */; return (d_sighandler)-1; }
    d_sighandler old = guest_sig_handlers[h];
    __sighandler_t prev;
    if (f == (d_sighandler)0 || f == (d_sighandler)1) { guest_sig_handlers[h] = NULL; prev = signal(h, (__sighandler_t)f); }
    else { guest_sig_handlers[h] = f; prev = signal(h, sig_trampoline); }
    if (prev == SIG_ERR) { errno = darwin_errno(errno); return (d_sighandler)-1; }
    return prev == sig_trampoline ? old : (d_sighandler)prev;
}
static int d_raise(int dsig) { int h = sig_host(dsig); if (h < 0) { errno = 22; return -1; } return raise(h); }
static int d_kill(pid_t pid, int dsig) { int h = dsig == 0 ? 0 : sig_host(dsig); if (h < 0) { errno = 22; return -1; } return NETRET(kill(pid, h)); }
static int d_pipe(int fds[2]) { return NETRET(pipe(fds)); }
static ssize_t d_pread(int fd, void *b, size_t n, off_t off) { return NETRET(pread(fd, b, n, off)); }
static ssize_t d_pwrite(int fd, const void *b, size_t n, off_t off) { return NETRET(pwrite(fd, b, n, off)); }
static int d_dup(int fd) { return NETRET(dup(fd)); }
static int d_dup2(int a, int b) { return NETRET(dup2(a, b)); }

/* ---- isim private helpers for Dispatch's sources (Foundation, Dispatch.mrc.m): the Linux facilities behind
   kqueue-like events ---- */
/* free space for a write source: a pipe's capacity minus what is queued in it, a socket's send buffer minus its
   unsent bytes; -1 for anything else (files, terminals) */
static long d_isim_fd_write_space(int fd) {
    struct stat st;
    if (fstat(fd, &st) != 0) return -1;
    int queued = 0;
    if (S_ISFIFO(st.st_mode)) {
        int cap = fcntl(fd, F_GETPIPE_SZ);
        if (cap <= 0 || ioctl(fd, FIONREAD, &queued) != 0) return -1;
        return cap > queued ? cap - queued : 0;
    }
    if (S_ISSOCK(st.st_mode)) {
        int cap = 0; socklen_t len = sizeof cap;
        if (getsockopt(fd, SOL_SOCKET, SO_SNDBUF, &cap, &len) != 0 || ioctl(fd, SIOCOUTQ, &queued) != 0) return -1;
        return cap > queued ? cap - queued : 0;
    }
    return -1;
}
/* data of a read source: the bytes readable (FIONREAD: also a file's bytes after the offset), or the pending
   connections of a listening socket (TCP: the accept queue; others: 1); -1 if unknown */
static long d_isim_fd_read_available(int fd) {
    int listening = 0; socklen_t len = sizeof listening;
    if (getsockopt(fd, SOL_SOCKET, SO_ACCEPTCONN, &listening, &len) == 0 && listening) {
        struct tcp_info ti; len = sizeof ti;
        if (getsockopt(fd, IPPROTO_TCP, TCP_INFO, &ti, &len) == 0 && ti.tcpi_unacked > 0) return ti.tcpi_unacked;
        return 1;
    }
    int avail = 0;
    return ioctl(fd, FIONREAD, &avail) == 0 ? avail : -1;
}
/* an inotify descriptor that becomes readable when the file or directory open as `fd` changes (content, attributes,
   link count, entries, rename, deletion); the caller drains it with read() and closes it. -1 if unsupported. */
static int d_isim_fs_watch_fd(int fd) {
    int in = inotify_init1(IN_NONBLOCK | IN_CLOEXEC);
    if (in < 0) return -1;
    char path[64]; snprintf(path, sizeof path, "/proc/self/fd/%d", fd);
    if (inotify_add_watch(in, path, IN_MODIFY | IN_ATTRIB | IN_MOVE_SELF | IN_DELETE_SELF | IN_CREATE | IN_DELETE |
                                    IN_MOVED_FROM | IN_MOVED_TO | IN_CLOSE_WRITE | IN_UNMOUNT) < 0) { close(in); return -1; }
    return in;
}
/* a pidfd: readable once the process has exited (also while it is an unreaped zombie). -1 with errno ESRCH (3) when
   there is no such process, another errno if pidfds are unsupported. */
static int d_isim_proc_watch_fd(pid_t pid) {
    int fd = (int)syscall(SYS_pidfd_open, pid, 0);
    if (fd < 0) { errno = darwin_errno(errno); return -1; }
    fcntl(fd, F_SETFD, FD_CLOEXEC);
    return fd;
}
/* what a process source compares between checks: its children (up to `max` pids, all threads) and an exec signature
   (the executable and command line, which change on exec; thread names do not count); returns the number of children, -1 if gone */
static int d_isim_proc_snapshot(pid_t pid, pid_t *children, int max, uint64_t *exec_sig) {
    char path[96]; snprintf(path, sizeof path, "/proc/%d/task", (int)pid);
    DIR *d = opendir(path);
    if (!d) return -1;
    int n = 0;
    for (struct dirent *e; (e = readdir(d));) {
        if (e->d_name[0] == '.') continue;
        snprintf(path, sizeof path, "/proc/%d/task/%s/children", (int)pid, e->d_name);
        FILE *f = fopen(path, "r");
        if (!f) continue;
        for (int c; fscanf(f, "%d", &c) == 1;) if (n < max) children[n++] = c;
        fclose(f);
    }
    closedir(d);
    uint64_t h = 1469598103934665603ull;                             /* FNV-1a */
    char buf[4096]; ssize_t len;
    snprintf(path, sizeof path, "/proc/%d/exe", (int)pid);
    if ((len = readlink(path, buf, sizeof buf)) > 0) for (ssize_t i = 0; i < len; i++) h = (h ^ (uint8_t)buf[i]) * 1099511628211ull;
    snprintf(path, sizeof path, "/proc/%d/cmdline", (int)pid);
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd >= 0) { if ((len = read(fd, buf, sizeof buf)) > 0) for (ssize_t i = 0; i < len; i++) h = (h ^ (uint8_t)buf[i]) * 1099511628211ull; close(fd); }
    if (exec_sig) *exec_sig = h;
    return n;
}

#define POSIX_EXTRAS \
    A("_signal", d_signal), A("_raise", d_raise), A("_kill", d_kill), A("_pipe", d_pipe), A("_pread", d_pread), A("_pwrite", d_pwrite), \
    A("_dup", d_dup), A("_dup2", d_dup2), \
    I("_isim_fd_write_space", d_isim_fd_write_space), I("_isim_fd_read_available", d_isim_fd_read_available), I("_isim_fs_watch_fd", d_isim_fs_watch_fd), \
    I("_isim_proc_watch_fd", d_isim_proc_watch_fd), I("_isim_proc_snapshot", d_isim_proc_snapshot)
