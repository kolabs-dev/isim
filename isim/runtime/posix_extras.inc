/* isim libSystem: more POSIX for guests (pipe, pread/pwrite, dup, kill, signal numbers).
 * Included by libsystem.c after sockets.inc (uses NETRET/darwin_errno).
 * Darwin and Linux disagree on several signal numbers (SIGUSR1 is 30 on Darwin, 10 on Linux, ...): guests use
 * Darwin numbers; signal()/raise()/kill() translate, and guest handlers receive Darwin numbers. */
#include <signal.h>

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

#define POSIX_EXTRAS \
    A("_signal", d_signal), A("_raise", d_raise), A("_kill", d_kill), A("_pipe", d_pipe), A("_pread", d_pread), A("_pwrite", d_pwrite), \
    A("_dup", d_dup), A("_dup2", d_dup2)
