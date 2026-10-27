/* isim runtime: the platform layer (platform.h) for Linux. */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/prctl.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/wait.h>
#include <unistd.h>

#include "platform.h"

extern char **environ;

static int in_list(const int *list, int fd) {
    for (; list && *list >= 0; list++) if (*list == fd) return 1;
    return 0;
}

/* the child, between fork and exec: only async-signal-safe calls, plus setenv/unsetenv (the parent's heap is a copy) */
static void child(const struct isim_spawn *s, pid_t parent, int report) {
    if (s->die_with_parent) {
        prctl(PR_SET_PDEATHSIG, SIGKILL);
        if (getppid() != parent) _exit(1);                 /* the parent is already gone */
    }
    if (s->new_session) setsid();
    if (s->remap_to > 0 && s->remap_from >= 0 && s->remap_from != s->remap_to) dup2(s->remap_from, s->remap_to);
    if (s->null_stdin || s->null_stdout || s->null_stderr) {
        int dn = open("/dev/null", O_RDWR);
        if (dn >= 0) {
            if (s->null_stdin) dup2(dn, 0);
            if (s->null_stdout) dup2(dn, 1);
            if (s->null_stderr) dup2(dn, 2);
            if (dn > 2) close(dn);
        }
    }
    for (const int *k = s->keep; k && *k >= 0; k++) fcntl(*k, F_SETFD, 0);    /* inherited across exec */
    if (s->close_others)
        for (int fd = 3; fd < 1024; fd++)
            if (fd != report && fd != s->remap_to && !in_list(s->keep, fd)) close(fd);
    for (const char *const *u = s->unset_env; u && *u; u++) unsetenv(*u);
    for (const char *const *e = s->set_env; e && *e; e++) {
        const char *eq = strchr(*e, '=');
        if (!eq) continue;
        char name[256];
        size_t n = (size_t)(eq - *e) < sizeof name - 1 ? (size_t)(eq - *e) : sizeof name - 1;
        memcpy(name, *e, n); name[n] = 0;
        setenv(name, eq + 1, 1);
    }
    char *const *env = s->env ? s->env : environ;
    if (strchr(s->path, '/')) execve(s->path, s->argv, env);
    else execvpe(s->path, s->argv, env);
    int e = errno;
    if (write(report, &e, sizeof e) < 0) {}                /* tells the parent why the program did not start */
    _exit(127);
}

pid_t isim_spawn(const struct isim_spawn *s) {
    int rep[2];                                            /* closes on a successful exec; carries errno otherwise */
    if (pipe2(rep, O_CLOEXEC) != 0) return -1;
    fflush(NULL);
    pid_t parent = getpid(), pid = fork();
    if (pid < 0) { int e = errno; close(rep[0]); close(rep[1]); errno = e; return -1; }
    if (pid == 0) { close(rep[0]); child(s, parent, rep[1]); }
    close(rep[1]);
    int e = 0;
    ssize_t r;
    do r = read(rep[0], &e, sizeof e); while (r < 0 && errno == EINTR);
    close(rep[0]);
    if (r == (ssize_t)sizeof e) {                          /* the exec failed: reap the child, report its errno */
        int st;
        while (waitpid(pid, &st, 0) < 0 && errno == EINTR) {}
        errno = e;
        return -1;
    }
    return pid;
}

int isim_open_on_desktop(const char *what) {
    if (!what || !*what) return 0;
    char *argv[] = { "xdg-open", (char *)what, NULL };
    struct isim_spawn s = { .path = "xdg-open", .argv = argv, .new_session = 1 };
    return isim_spawn(&s) > 0;
}

int isim_self_path(char *buf, size_t cap) {
    if (!cap) return -1;
    ssize_t n = readlink("/proc/self/exe", buf, cap - 1);
    if (n < 0) return -1;
    buf[n] = 0;
    return (int)n;
}

long long isim_self_bytes_written(void) {
    char buf[1024];
    int fd = open("/proc/self/io", O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t n = read(fd, buf, sizeof buf - 1);
    close(fd);
    if (n <= 0) return -1;
    buf[n] = 0;
    const char *w = strstr(buf, "wchar:");
    return w ? strtoll(w + 6, NULL, 10) : -1;
}

int isim_self_args(char *buf, size_t cap, char **argv, int max) {
    if (!cap || max < 1) return -1;
    size_t n = 0;
    int fd = open("/proc/self/cmdline", O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    ssize_t r;
    while (n < cap - 1 && (r = read(fd, buf + n, cap - 1 - n)) > 0) n += (size_t)r;
    close(fd);
    buf[n] = 0;
    int argc = 0;
    for (size_t i = 0; i < n && argc < max - 1; i += strlen(buf + i) + 1) argv[argc++] = buf + i;
    argv[argc] = NULL;
    return argc;
}

int isim_restart_self(char *const *argv) {
    fflush(NULL);
    execv("/proc/self/exe", argv);
    return -1;
}

int isim_shm_create(const char *name, size_t size) {
    int fd = memfd_create(name ? name : "isim-shm", MFD_CLOEXEC);
    if (fd < 0) return -1;
    if (ftruncate(fd, (off_t)size) != 0) { int e = errno; close(fd); errno = e; return -1; }
    return fd;
}

void *isim_shm_map(int handle, size_t size, int writable) {
    void *p = mmap(NULL, size, PROT_READ | (writable ? PROT_WRITE : 0), MAP_SHARED, handle, 0);
    return p == MAP_FAILED ? NULL : p;
}

void isim_shm_unmap(void *p, size_t size) { if (p) munmap(p, size); }

int isim_ipc_pair(int h[2], int packets) {
    return socketpair(AF_UNIX, (packets ? SOCK_SEQPACKET : SOCK_STREAM) | SOCK_CLOEXEC, 0, h);
}

int isim_ctl_create(const char *path) { return mkfifo(path, 0600); }
