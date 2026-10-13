/*
 * isim diagnostics: what MetricKit measures and what crash reports name (adapted: isim measures its own process the
 * way iOS measures an app).
 *
 *   - The app's identity (bundle id, versions, name), set by UIApplicationMain, for crash reports.
 *   - Resource usage: CPU time (getrusage), peak and current memory, logical writes (/proc/self/io wchar), the
 *     process's age.
 *   - Launch: from the process's start to the first frame drawn (isim_frame_end calls isim_diag_frame).
 *   - Hangs: the main thread waits for events in isim_next_event; a watchdog thread notices when it has been away
 *     from that wait (busy) for 250 ms or more, samples its stack once, and records the hang with its duration when
 *     the main thread comes back (iOS's hang threshold is 250 ms too). The first wait (launch) is not a hang.
 */
#define _GNU_SOURCE
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/resource.h>
#include <sys/time.h>
#include <time.h>
#include <unistd.h>
#include "runtime.h"

static double wall(void) { struct timeval tv; gettimeofday(&tv, NULL); return tv.tv_sec + tv.tv_usec / 1e6; }
static double mono(void) { struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts); return ts.tv_sec + ts.tv_nsec / 1e9; }

/* ---- the app's identity ---- */
static char app_bundle[256], app_version[64], app_build[64], app_name[256], app_path[1024];
static void start_watchdog(void);
void isim_diag_set_app(const char *bundle_id, const char *version, const char *build, const char *name, const char *path) {
    start_watchdog();                                       /* from launch: a slow launch's stack is sampled too */
    snprintf(app_bundle, sizeof app_bundle, "%s", bundle_id ? bundle_id : "");
    snprintf(app_version, sizeof app_version, "%s", version ? version : "");
    snprintf(app_build, sizeof app_build, "%s", build ? build : "");
    snprintf(app_name, sizeof app_name, "%s", name ? name : "");
    snprintf(app_path, sizeof app_path, "%s", path ? path : "");
}
const char *isim_diag_app(int which) {
    switch (which) { case 0: return app_bundle; case 1: return app_version; case 2: return app_build; case 3: return app_name; default: return app_path; }
}

/* ---- the process's start (wall clock): /proc/self/stat's start time after boot ---- */
double isim_diag_process_start(void) {
    static double start;
    if (start) return start;
    unsigned long long ticks = 0; double btime = 0;
    FILE *f = fopen("/proc/self/stat", "r");
    if (f) {
        char buf[2048]; size_t n = fread(buf, 1, sizeof buf - 1, f); buf[n] = 0; fclose(f);
        char *p = strrchr(buf, ')');                       /* the command may contain spaces: fields after ')' */
        for (int field = 2; p && *p && field < 22; p++) if (*p == ' ') field++;
        if (p) ticks = strtoull(p, NULL, 10);
    }
    f = fopen("/proc/stat", "r");
    if (f) { char line[256]; while (fgets(line, sizeof line, f)) if (!strncmp(line, "btime ", 6)) { btime = atof(line + 6); break; } fclose(f); }
    long hz = sysconf(_SC_CLK_TCK);
    start = btime && hz > 0 ? btime + (double)ticks / hz : wall();
    return start;
}

/* ---- launch: the first frame ---- */
static double first_frame;                                  /* wall clock; 0 until drawn */
static double frame_last, frame_hitch;                       /* frame pacing: time past one 60 Hz frame */
void isim_diag_frame(void) {
    double t = wall();
    if (!first_frame) first_frame = t;
    if (frame_last && t - frame_last < 0.5 && t - frame_last > 1.0 / 60 * 1.5) frame_hitch += t - frame_last - 1.0 / 60;
    frame_last = t;
}

/* usage: [0] user CPU s, [1] system CPU s, [2] peak memory KB, [3] logical writes bytes, [4] process age s,
   [5] time to first frame ms (0 before it), [6] current memory KB, [7] hitch time s (frames slower than 1.5 x 60 Hz) */
int isim_resource_usage(double out[8]) {
    struct rusage ru; getrusage(RUSAGE_SELF, &ru);
    out[0] = ru.ru_utime.tv_sec + ru.ru_utime.tv_usec / 1e6;
    out[1] = ru.ru_stime.tv_sec + ru.ru_stime.tv_usec / 1e6;
    out[2] = (double)ru.ru_maxrss;
    out[3] = 0;
    FILE *f = fopen("/proc/self/io", "r");
    if (f) { char line[128]; while (fgets(line, sizeof line, f)) if (!strncmp(line, "wchar:", 6)) out[3] = atof(line + 6); fclose(f); }
    out[4] = wall() - isim_diag_process_start();
    out[5] = first_frame ? (first_frame - isim_diag_process_start()) * 1000 : 0;
    out[6] = 0;
    f = fopen("/proc/self/statm", "r");
    if (f) { unsigned long size, res; if (fscanf(f, "%lu %lu", &size, &res) == 2) out[6] = res * (sysconf(_SC_PAGESIZE) / 1024.0); fclose(f); }
    out[7] = frame_hitch;
    return 8;
}

/* ---- hangs ---- */
#define HANG_THRESHOLD 0.25
#define MAX_HANGS 64
struct hang { double start, duration; char stack[4096]; };
static struct hang hangs[MAX_HANGS];
static int nhangs;
static pthread_mutex_t hang_lock = PTHREAD_MUTEX_INITIALIZER;
static volatile double busy_since;                          /* monotonic; 0 while waiting for events */
static volatile int watching;                               /* after the first wait (launch is not a hang) */
static char pending_stack[4096];
static volatile int pending_sampled;
static double pending_wall;

/* the main thread's stack, one "image\toffset\taddress\tsymbol" line a frame */
static void sample_main(char *out, size_t cap) {
    uintptr_t pcs[48]; int n = isim_sample_thread(getpid(), pcs, 48);
    out[0] = 0; size_t len = 0;
    for (int i = 0; i < n && len < cap - 300; i++) {
        char image[256], sym[256]; uint64_t image_off = 0, sym_off = 0, base = 0;
        isim_symbolize(pcs[i], image, sizeof image, sym, sizeof sym, &image_off, &sym_off, &base);
        len += (size_t)snprintf(out + len, cap - len, "%s\t%llu\t%llu\t%s\n", image, (unsigned long long)image_off,
                                (unsigned long long)pcs[i], sym);
    }
}
/* the main thread's stack now (MetricKit CPU exception diagnostics); returns the number of frames */
int isim_sample_main_stack(char *out, int cap) {
    sample_main(out, (size_t)cap);
    int n = 0; for (const char *p = out; *p; p++) n += *p == '\n';
    return n;
}
/* launch: the main thread's stack when the first frame is still missing 1.5 s after the process started (MetricKit's
   app launch diagnostic for a slow launch) */
static char launch_stack[4096];
static volatile int launch_sampled;
int isim_launch_stack(char *out, int cap) { snprintf(out, (size_t)cap, "%s", launch_sampled ? launch_stack : ""); return launch_sampled; }
static void *hang_watchdog(void *arg) {
    (void)arg;
    pthread_setname_np(pthread_self(), "isim-hangs");
    for (;;) {
        usleep(50000);
        if (!launch_sampled && !first_frame && wall() - isim_diag_process_start() > 1.5) {
            sample_main(launch_stack, sizeof launch_stack); launch_sampled = 1;
        }
        double since = busy_since;
        if (!watching || !since || pending_sampled) continue;
        if (mono() - since >= HANG_THRESHOLD + 0.05) {        /* hung: sample the stack once */
            sample_main(pending_stack, sizeof pending_stack);
            if (busy_since == since) { pending_wall = wall() - (mono() - since); pending_sampled = 1; }
        }
    }
    return NULL;
}
/* the main thread: entering (1) or leaving (0) its wait for events */
static void start_watchdog(void) {
    static int started;
    if (started) return;
    started = 1;
    if (!getenv("ISIM_NO_HANG_WATCHDOG")) { pthread_t t; if (!pthread_create(&t, NULL, hang_watchdog, NULL)) pthread_detach(t); }
}
void isim_diag_beat(int waiting) {
    start_watchdog();
    if (waiting) {
        double since = busy_since, d = since ? mono() - since : 0;
        if (watching && since && d >= HANG_THRESHOLD) {
            pthread_mutex_lock(&hang_lock);
            struct hang *h = &hangs[nhangs < MAX_HANGS ? nhangs++ : MAX_HANGS - 1];
            h->start = pending_sampled ? pending_wall : wall() - d; h->duration = d;
            snprintf(h->stack, sizeof h->stack, "%s", pending_sampled ? pending_stack : "");
            pthread_mutex_unlock(&hang_lock);
            isim_metric_add("hang.count", 1); isim_metric_add("hang.time", d);
        }
        busy_since = 0; pending_sampled = 0;
        watching = 1;
    } else busy_since = mono();
}
int isim_hang_count(void) { pthread_mutex_lock(&hang_lock); int n = nhangs; pthread_mutex_unlock(&hang_lock); return n; }
/* one hang: start (wall clock), duration (s) and its stack (see sample_main) */
int isim_hang_get(int i, double *start, double *duration, char *stack, int cap) {
    pthread_mutex_lock(&hang_lock);
    if (i < 0 || i >= nhangs) { pthread_mutex_unlock(&hang_lock); return 0; }
    *start = hangs[i].start; *duration = hangs[i].duration;
    snprintf(stack, (size_t)cap, "%s", hangs[i].stack);
    pthread_mutex_unlock(&hang_lock);
    return 1;
}
