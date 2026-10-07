/* Host side of XCUITest (isim XCTest's XCUIApplication): starts the app under test as its own isim-runtime
 * process (headless if the test runner is) with a control FIFO, sends it script commands (tap, type, drag, ...)
 * and asks it for accessibility snapshots ("dump FILE": the app writes its element tree to FILE). */
#define _GNU_SOURCE
#include <errno.h>
#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

extern char **environ;
extern const char *isim_sysroot(void);

#define MAX_APPS 8
static struct xcui_app { pid_t pid; int fd; char dir[256]; int seq; int exited, status; } apps[MAX_APPS];
static int atexit_done;

static double mono(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }
static void sleep_s(double s) { struct timespec ts = { (time_t)s, (long)((s - (time_t)s) * 1e9) }; nanosleep(&ts, NULL); }

static void reap(struct xcui_app *a) {
    if (a->pid <= 0 || a->exited) return;
    int st;
    if (waitpid(a->pid, &st, WNOHANG) == a->pid) { a->exited = 1; a->status = st; }
}
static void cleanup_app(struct xcui_app *a) {
    if (a->fd >= 0) close(a->fd);
    a->fd = -1;
    if (a->dir[0]) {
        char p[512];
        snprintf(p, sizeof p, "%s/control", a->dir); unlink(p);
        rmdir(a->dir);
        a->dir[0] = 0;
    }
}
static void kill_all(void) {
    for (int i = 0; i < MAX_APPS; i++) {
        if (apps[i].pid > 0 && !apps[i].exited) { kill(apps[i].pid, SIGTERM); waitpid(apps[i].pid, NULL, 0); apps[i].exited = 1; }
        cleanup_app(&apps[i]);
    }
}

/* argv / envp: NULL-terminated arrays (envp entries are KEY=VALUE, added to the runner's environment).
 * Returns a handle >= 0, or -1. */
int isim_xcui_launch(const char *exe, const char *const *argv, const char *const *envp) {
    int h = -1;
    for (int i = 0; i < MAX_APPS; i++) { reap(&apps[i]); if (apps[i].pid <= 0 || apps[i].exited) { h = i; break; } }
    if (h < 0 || !exe) return -1;
    struct xcui_app *a = &apps[h];
    cleanup_app(a);
    memset(a, 0, sizeof *a); a->fd = -1;
    const char *tmp = getenv("TMPDIR"); if (!tmp || !*tmp) tmp = "/tmp";
    snprintf(a->dir, sizeof a->dir, "%s/isim-xcui-XXXXXX", tmp);
    if (!mkdtemp(a->dir)) { a->dir[0] = 0; return -1; }
    char fifo[512]; snprintf(fifo, sizeof fifo, "%s/control", a->dir);
    if (mkfifo(fifo, 0600) != 0) return -1;
    a->fd = open(fifo, O_RDWR | O_NONBLOCK);          /* RDWR: the app's reads never see EOF between commands */
    if (a->fd < 0) return -1;
    if (!atexit_done) { atexit(kill_all); atexit_done = 1; }

    /* environment: the runner's, minus test-runner settings, plus the control FIFO and the launch environment */
    int nenv = 0; while (environ[nenv]) nenv++;
    int nextra = 0; while (envp && envp[nextra]) nextra++;
    char **env = calloc(nenv + nextra + 4, sizeof *env);
    int k = 0;
    for (int i = 0; i < nenv; i++) {
        const char *e = environ[i];
        if (!strncmp(e, "ISIM_SCRIPT=", 12) || !strncmp(e, "ISIM_CONTROL=", 13) || !strncmp(e, "ISIM_XCTEST_", 12) || !strncmp(e, "ISIM_XCUI_", 10)) continue;
        int overridden = 0;
        for (int j = 0; j < nextra; j++) { const char *eq = strchr(envp[j], '='); if (eq && !strncmp(e, envp[j], eq - envp[j] + 1)) overridden = 1; }
        if (!overridden) env[k++] = (char *)e;
    }
    for (int j = 0; j < nextra; j++) env[k++] = (char *)envp[j];
    char ctl[600]; snprintf(ctl, sizeof ctl, "ISIM_CONTROL=%s", fifo);
    env[k++] = ctl;
    env[k] = NULL;

    int nargs = 0; while (argv && argv[nargs]) nargs++;
    char **args = calloc(nargs + 6, sizeof *args);
    int n = 0;
    args[n++] = "isim-runtime";
    const char *root = isim_sysroot();
    if (root) { args[n++] = "--root"; args[n++] = (char *)root; }
    args[n++] = (char *)exe;
    for (int i = 0; i < nargs; i++) args[n++] = (char *)argv[i];
    args[n] = NULL;
    fflush(NULL);
    pid_t pid = fork();
    if (pid == 0) {
        execve("/proc/self/exe", args, env);
        _exit(127);
    }
    free(args); free(env);
    if (pid < 0) return -1;
    a->pid = pid;
    return h;
}

int isim_xcui_running(int h) {
    if (h < 0 || h >= MAX_APPS || apps[h].pid <= 0) return 0;
    reap(&apps[h]);
    return !apps[h].exited;
}

/* one script command (e.g. "tap 100 200", "type hello", "drag 10 10 10 300 0.3", "rotate landscapeleft") */
int isim_xcui_send(int h, const char *line) {
    if (!isim_xcui_running(h) || apps[h].fd < 0) return -1;
    size_t len = strlen(line);
    char *buf = malloc(len + 2);
    memcpy(buf, line, len); buf[len] = '\n';
    ssize_t w = write(apps[h].fd, buf, len + 1);
    free(buf);
    return w == (ssize_t)(len + 1) ? 0 : -1;
}

/* asks the app for its element tree; returns a malloc'd text (free with isim_xcui_free) or NULL on timeout */
char *isim_xcui_snapshot(int h, double timeout) {
    if (!isim_xcui_running(h)) return NULL;
    char path[512], cmd[600];
    snprintf(path, sizeof path, "%s/snapshot-%d.txt", apps[h].dir, ++apps[h].seq);
    snprintf(cmd, sizeof cmd, "dump %s", path);
    if (isim_xcui_send(h, cmd) != 0) return NULL;
    double end = mono() + timeout;
    while (mono() < end) {
        FILE *f = fopen(path, "rb");
        if (f) {
            fseek(f, 0, SEEK_END); long sz = ftell(f); fseek(f, 0, SEEK_SET);
            char *out = malloc(sz + 1);
            size_t got = fread(out, 1, sz, f);
            out[got] = 0; fclose(f); unlink(path);
            return out;
        }
        if (!isim_xcui_running(h)) return NULL;
        sleep_s(0.005);
    }
    return NULL;
}
void isim_xcui_free(char *p) { free(p); }

void isim_xcui_terminate(int h) {
    if (h < 0 || h >= MAX_APPS || apps[h].pid <= 0) return;
    struct xcui_app *a = &apps[h];
    if (isim_xcui_running(h)) {
        isim_xcui_send(h, "quit");
        double end = mono() + 3;
        while (mono() < end && isim_xcui_running(h)) sleep_s(0.01);
        if (isim_xcui_running(h)) { kill(a->pid, SIGKILL); waitpid(a->pid, NULL, 0); a->exited = 1; }
    }
    cleanup_app(a);
}
