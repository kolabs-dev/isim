/* isim libSystem: os_unfair_lock (libsystem_platform on iOS) on a Linux futex. The 32-bit lock word holds the
 * owner's thread id (bit 31 = waiters), so ownership assertions work and unlocking from another thread aborts
 * like on iOS.
 *
 * Also the C side of unified logging (libsystem_trace): os_log_create, os_log_type_enabled and _os_log_impl,
 * which the os_log() macros call with clang's __builtin_os_log_format buffer. Lines go to stderr in the same
 * format as isim's Swift Logger; private arguments print <private> (ISIM_LOG_PRIVATE=1 shows them).
 *
 * The log store (OSLogStore): every message (C os_log, Swift Logger / os_log, NSLog) and every signpost is also kept
 * in memory for this process, as on iOS where an app reads back its own process's entries
 * (OSLogStore(scope: .currentProcessIdentifier)). The store keeps the last 50,000 entries; messages are kept as
 * shown (private values redacted unless ISIM_LOG_PRIVATE=1).
 *
 * Signposts (C): os_signpost_id_generate / _make_with_pointer, os_signpost_enabled and _os_signpost_emit_with_name_impl
 * (the os_signpost_* macros). Recorded in the store; ISIM_LOG_SIGNPOSTS=1 also prints them.
 *
 * Metrics (MetricKit): a small table of named accumulators other parts of isim add to (isim_metric_add), read
 * back by MetricKit (isim_metric_get). */
#define _GNU_SOURCE
#include <linux/futex.h>
#include <errno.h>
#include <libgen.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include <sys/time.h>
#include <time.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/syscall.h>
#include <unistd.h>
#include "runtime.h"

#define WAITERS 0x80000000u
static uint32_t self_id(void) { static __thread uint32_t tid; if (!tid) tid = (uint32_t)syscall(SYS_gettid) & 0x7fffffff; return tid; }
static void ul_crash(const char *what) { fflush(NULL); fprintf(stderr, "isim: BUG IN CLIENT OF LIBPLATFORM: %s\n", what); abort(); }

static void ul_lock(uint32_t *l) {
    uint32_t me = self_id(), v = 0;
    if (__atomic_compare_exchange_n(l, &v, me, 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) return;
    for (;;) {
        v = __atomic_load_n(l, __ATOMIC_RELAXED);
        if ((v & ~WAITERS) == me) ul_crash("Trying to recursively lock an os_unfair_lock");
        if (v == 0) {
            if (__atomic_compare_exchange_n(l, &v, me | WAITERS, 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED)) return;
            continue;
        }
        if (!(v & WAITERS) && !__atomic_compare_exchange_n(l, &v, v | WAITERS, 0, __ATOMIC_RELAXED, __ATOMIC_RELAXED)) continue;
        syscall(SYS_futex, l, FUTEX_WAIT_PRIVATE, v | WAITERS, NULL, NULL, 0);
    }
}
static _Bool ul_trylock(uint32_t *l) {
    uint32_t v = 0;
    return __atomic_compare_exchange_n(l, &v, self_id(), 0, __ATOMIC_ACQUIRE, __ATOMIC_RELAXED);
}
static void ul_unlock(uint32_t *l) {
    uint32_t v = __atomic_load_n(l, __ATOMIC_RELAXED);
    if ((v & ~WAITERS) != self_id()) ul_crash("Unlock of an os_unfair_lock not owned by current thread");
    v = __atomic_exchange_n(l, 0, __ATOMIC_RELEASE);
    if (v & WAITERS) syscall(SYS_futex, l, FUTEX_WAKE_PRIVATE, 1, NULL, NULL, 0);
}
static void ul_assert_owner(const uint32_t *l) {
    if ((__atomic_load_n(l, __ATOMIC_RELAXED) & ~WAITERS) != self_id()) ul_crash("os_unfair_lock is not owned by current thread");
}
static void ul_assert_not_owner(const uint32_t *l) {
    if ((__atomic_load_n(l, __ATOMIC_RELAXED) & ~WAITERS) == self_id()) ul_crash("os_unfair_lock is owned by current thread");
}

/* ---------------- os_log (C) ---------------- */
/* an os_log_t is an Objective-C object on Apple platforms (ARC retains it): isa is the runtime's OS_os_log class */
struct os_log_s { void *isa; char subsystem[256], category[256]; int disabled; };
struct os_log_s _os_log_default = { NULL, "", "", 0 }, _os_log_disabled = { NULL, "", "", 1 };
__attribute__((constructor)) static void log_class_init(void) {
    _os_log_default.isa = _os_log_disabled.isa = objc_rt_immortal_class("OS_os_log");
}
static struct os_log_s *log_create(const char *subsystem, const char *category) {
    struct os_log_s *l = calloc(1, sizeof *l);
    l->isa = _os_log_default.isa;
    snprintf(l->subsystem, sizeof l->subsystem, "%s", subsystem ? subsystem : "");
    snprintf(l->category, sizeof l->category, "%s", category ? category : "");
    return l;
}
static int min_rank(void) {
    const char *e = getenv("ISIM_LOG_LEVEL");
    if (!e) return 0;
    if (!strcasecmp(e, "info")) return 1;
    if (!strcasecmp(e, "default") || !strcasecmp(e, "notice")) return 2;
    if (!strcasecmp(e, "error")) return 3;
    if (!strcasecmp(e, "fault")) return 4;
    return 0;
}
static int type_rank(uint8_t t) { return t == 0x02 ? 0 : t == 0x01 ? 1 : t == 0x10 ? 3 : t == 0x11 ? 4 : 2; }
static bool log_type_enabled(struct os_log_s *l, uint8_t type) { return l && !l->disabled && type_rank(type) >= min_rank(); }

/* -[obj description].UTF8String through isim's Objective-C runtime */
typedef void *(*imp_t)(void *, void *);
extern void *object_getClass(void *);
extern void *sel_registerName(const char *);
extern void *class_getMethodImplementation(void *, void *);
extern void *objc_autoreleasePoolPush(void);
extern void objc_autoreleasePoolPop(void *);
static void append_object(char *out, size_t cap, void *obj) {
    size_t n = strlen(out);
    if (!obj) { snprintf(out + n, cap - n, "(null)"); return; }
    void *pool = objc_autoreleasePoolPush();
    void *sd = sel_registerName("description"), *su = sel_registerName("UTF8String");
    void *str = ((imp_t)class_getMethodImplementation(object_getClass(obj), sd))(obj, sd);
    const char *u = str ? ((const char *(*)(void *, void *))class_getMethodImplementation(object_getClass(str), su))(str, su) : NULL;
    snprintf(out + n, cap - n, "%s", u ? u : "(null)");
    objc_autoreleasePoolPop(pool);
}

/* clang's os_log buffer: summary byte, argument count, then per argument a descriptor (kind << 4 | flags:
   1 private, 2 public), a size byte and the data. Kinds: 0 scalar, 1 count, 2 string, 3 pointer, 4 object. */
struct item { uint8_t kind, flags, size; const uint8_t *data; };
static int64_t item_int(const struct item *it) {
    switch (it->size) {
    case 1: return (int8_t)it->data[0];
    case 2: { int16_t v; memcpy(&v, it->data, 2); return v; }
    case 4: { int32_t v; memcpy(&v, it->data, 4); return v; }
    case 8: { int64_t v; memcpy(&v, it->data, 8); return v; }
    }
    return 0;
}
static void *item_ptr(const struct item *it) { void *p = NULL; if (it->size == 8) memcpy(&p, it->data, 8); return p; }

/* the message: walk the format, take one encoded argument per conversion (and per '*' width/precision) */
static void format_message(char *out, size_t cap, const char *fmt, const uint8_t *buf, uint32_t size) {
    struct item items[64]; int nitems = 0;
    if (buf && size >= 2) {
        int n = buf[1]; uint32_t off = 2;
        for (int i = 0; i < n && nitems < 64 && off + 2 <= size; i++) {
            struct item it = { (uint8_t)(buf[off] >> 4), (uint8_t)(buf[off] & 0x0f), buf[off + 1], buf + off + 2 };
            off += 2u + it.size;
            if (off > size) break;
            items[nitems++] = it;
        }
    }
    const char *rv = getenv("ISIM_LOG_PRIVATE");
    int next = 0, reveal = rv && !strcmp(rv, "1");
    out[0] = 0;
    for (const char *p = fmt; *p;) {
        size_t n = strlen(out);
        if (n + 1 >= cap) break;
        if (*p != '%') { out[n] = *p++; out[n + 1] = 0; continue; }
        if (p[1] == '%') { strncat(out, "%", cap - n - 1); p += 2; continue; }
        const char *q = p + 1;
        int privacy = 0;                                  /* 1 public, 2 private */
        if (*q == '{') {
            const char *e = strchr(q, '}');
            if (!e) break;
            char mods[128]; snprintf(mods, sizeof mods, "%.*s", (int)(e - q - 1), q + 1);
            if (strstr(mods, "public")) privacy = 1;
            if (strstr(mods, "private") || strstr(mods, "sensitive")) privacy = 2;
            q = e + 1;
        }
        char spec[48] = "%"; size_t sl = 1;
        int precision = -1, width = -1;
        while (*q && strchr("-+ #0", *q)) { if (sl < 20) spec[sl++] = *q; q++; }
        if (*q == '*') { if (next < nitems) width = (int)item_int(&items[next++]); q++; }
        else while (*q >= '0' && *q <= '9') { if (sl < 20) spec[sl++] = *q; q++; }
        if (*q == '.') {
            q++;
            if (*q == '*') { if (next < nitems) precision = (int)item_int(&items[next++]); q++; }
            else { precision = 0; while (*q >= '0' && *q <= '9') precision = precision * 10 + (*q++ - '0'); }
        }
        while (*q && strchr("hlLqjztN", *q)) q++;            /* length modifiers: sizes come from the buffer */
        char conv = *q ? *q++ : 0;
        p = q;
        if (!conv) break;
        spec[sl] = 0;
        if (width >= 0) sl += (size_t)snprintf(spec + sl, sizeof spec - sl, "%d", width);
        if (precision >= 0) sl += (size_t)snprintf(spec + sl, sizeof spec - sl, ".%d", precision);
        if (next >= nitems) { strncat(out, "<decode: missing data>", cap - n - 1); continue; }
        const struct item *it = &items[next++];
        int is_private = it->flags & 0x1, is_public = it->flags & 0x2;
        int hide = privacy == 2 || is_private || (!is_public && privacy != 1 && (it->kind == 2 || it->kind == 4 || it->kind == 5));
        if (hide && !reveal) { strncat(out, "<private>", cap - n - 1); continue; }
        char tmp[1024] = "";
        switch (conv) {
        case 'd': case 'i':
            snprintf(spec + sl, sizeof spec - sl, "lld"); snprintf(tmp, sizeof tmp, spec, (long long)item_int(it)); break;
        case 'c':
            snprintf(spec + sl, sizeof spec - sl, "c"); snprintf(tmp, sizeof tmp, spec, (int)item_int(it)); break;
        case 'u': case 'o': case 'x': case 'X': {
            uint64_t v = (uint64_t)item_int(it);
            if (it->size == 4) v &= 0xffffffffu; else if (it->size == 2) v &= 0xffff; else if (it->size == 1) v &= 0xff;
            snprintf(spec + sl, sizeof spec - sl, "ll%c", conv); snprintf(tmp, sizeof tmp, spec, (unsigned long long)v); break; }
        case 'f': case 'F': case 'e': case 'E': case 'g': case 'G': case 'a': case 'A': {
            double v = 0;
            if (it->size == 8) memcpy(&v, it->data, 8); else if (it->size == 4) { float f; memcpy(&f, it->data, 4); v = f; }
            snprintf(spec + sl, sizeof spec - sl, "%c", conv); snprintf(tmp, sizeof tmp, spec, v); break; }
        case 's': { const char *s = item_ptr(it); snprintf(spec + sl, sizeof spec - sl, "s"); snprintf(tmp, sizeof tmp, spec, s ? s : "(null)"); break; }
        case 'p': snprintf(tmp, sizeof tmp, "%p", item_ptr(it)); break;
        case '@': append_object(tmp, sizeof tmp, item_ptr(it)); break;
        case 'm': snprintf(tmp, sizeof tmp, "%s", strerror((int)item_int(it))); break;
        default: snprintf(tmp, sizeof tmp, "<unsupported %%%c>", conv); break;
        }
        strncat(out, tmp, cap - strlen(out) - 1);
    }
}
/* ---------------- the log store ---------------- */
struct log_rec { double date; int kind, type, sptype; uint64_t spid, tid; char *s[5]; };   /* subsystem, category, message, format, name */
#define LOG_MAX 50000
static struct log_rec *recs;                            /* ring of LOG_MAX; entry seq lives at recs[seq % LOG_MAX] */
static long rec_end;                                    /* the next sequence number */
static pthread_mutex_t store_lock = PTHREAD_MUTEX_INITIALIZER;
static char *dupz(const char *s) { return strdup(s ? s : ""); }
/* kind 0 log message, 1 signpost (sptype 0 event, 1 begin, 2 end) */
void isim_log_record(int kind, int type, const char *subsystem, const char *category, const char *message,
                     const char *format, int sptype, uint64_t spid, const char *name) {
    struct timeval tv; gettimeofday(&tv, NULL);
    pthread_mutex_lock(&store_lock);
    if (!recs) recs = calloc(LOG_MAX, sizeof *recs);
    if (recs) {
        struct log_rec *r = &recs[rec_end % LOG_MAX];
        for (int i = 0; i < 5; i++) free(r->s[i]);
        r->date = tv.tv_sec + tv.tv_usec / 1e6; r->kind = kind; r->type = type; r->sptype = sptype; r->spid = spid;
        r->tid = (uint64_t)syscall(SYS_gettid);
        r->s[0] = dupz(subsystem); r->s[1] = dupz(category); r->s[2] = dupz(message); r->s[3] = dupz(format); r->s[4] = dupz(name);
        rec_end++;
    }
    pthread_mutex_unlock(&store_lock);
}
/* the range of sequence numbers held: [*first, end) */
long isim_log_range(long *first) {
    pthread_mutex_lock(&store_lock);
    long end = rec_end; if (first) *first = end > LOG_MAX ? end - LOG_MAX : 0;
    pthread_mutex_unlock(&store_lock);
    return end;
}
/* one entry: meta = kind, type, sptype; ids = signpost id, thread id; strs = 5 malloc'd copies (free them) */
int isim_log_get(long seq, double *date, int meta[3], uint64_t ids[2], char *strs[5]) {
    pthread_mutex_lock(&store_lock);
    long first = rec_end > LOG_MAX ? rec_end - LOG_MAX : 0;
    if (!recs || seq < first || seq >= rec_end) { pthread_mutex_unlock(&store_lock); return 0; }
    struct log_rec *r = &recs[seq % LOG_MAX];
    *date = r->date; meta[0] = r->kind; meta[1] = r->type; meta[2] = r->sptype; ids[0] = r->spid; ids[1] = r->tid;
    for (int i = 0; i < 5; i++) strs[i] = strdup(r->s[i]);
    pthread_mutex_unlock(&store_lock);
    return 1;
}

/* ---------------- metrics (MetricKit) ---------------- */
struct metric { char key[48]; double v; };
static struct metric metrics[128]; static int nmetrics;
static pthread_mutex_t metric_lock = PTHREAD_MUTEX_INITIALIZER;
static struct metric *metric_slot(const char *key) {
    for (int i = 0; i < nmetrics; i++) if (!strcmp(metrics[i].key, key)) return &metrics[i];
    if (nmetrics >= 128) return NULL;
    struct metric *m = &metrics[nmetrics++]; snprintf(m->key, sizeof m->key, "%s", key); m->v = 0; return m;
}
void isim_metric_add(const char *key, double v) {
    pthread_mutex_lock(&metric_lock); struct metric *m = metric_slot(key); if (m) m->v += v; pthread_mutex_unlock(&metric_lock);
}
void isim_metric_max(const char *key, double v) {
    pthread_mutex_lock(&metric_lock); struct metric *m = metric_slot(key); if (m && v > m->v) m->v = v; pthread_mutex_unlock(&metric_lock);
}
double isim_metric_get(const char *key) {
    pthread_mutex_lock(&metric_lock); double v = 0;
    for (int i = 0; i < nmetrics; i++) if (!strcmp(metrics[i].key, key)) { v = metrics[i].v; break; }
    pthread_mutex_unlock(&metric_lock); return v;
}

static pthread_mutex_t log_lock = PTHREAD_MUTEX_INITIALIZER;
static void os_log_impl(void *dso, struct os_log_s *l, uint8_t type, const char *fmt, const uint8_t *buf, uint32_t size) {
    if (!log_type_enabled(l, type) || !fmt) return;
    char msg[4096]; format_message(msg, sizeof msg, fmt, buf, size);
    isim_log_record(0, type, l->subsystem, l->category, msg, fmt, 0, 0, "");
    struct timeval tv; gettimeofday(&tv, NULL);
    time_t t = tv.tv_sec; struct tm tm; localtime_r(&t, &tm);
    char ts[32]; strftime(ts, sizeof ts, "%Y-%m-%d %H:%M:%S", &tm);
    const char *code = type == 0x01 ? "I " : type == 0x02 ? "Db" : type == 0x10 ? "E " : type == 0x11 ? "F " : "Df";
    char exe[512]; snprintf(exe, sizeof exe, "%s", isim_main_executable_path() ? isim_main_executable_path() : "app");
    char scope[600] = "";
    if (l->subsystem[0] || l->category[0]) snprintf(scope, sizeof scope, " [%s:%s]", l->subsystem, l->category);
    pthread_mutex_lock(&log_lock);
    fprintf(stderr, "%s.%03ld %s %s[%d:%lx]%s %s\n", ts, (long)(tv.tv_usec / 1000), code, basename(exe), getpid(),
            (unsigned long)(uintptr_t)pthread_self() & 0xffffff, scope, msg);
    fflush(stderr);
    pthread_mutex_unlock(&log_lock);
}

/* the `signposts` script command (Instruments' Points of Interest, as text): per subsystem, category and name, the
   events and the intervals with their total, average and longest duration; optional filter: a subsystem or category */
void isim_signposts_summary(const char *filter) {
    struct sp_sum { char key[600]; int events, intervals, open; double total, max; };
    struct sp_open { char key[600]; uint64_t id; double begin; };
    static struct sp_sum sums[256]; static struct sp_open opens[512];
    int nsums = 0, nopens = 0;
    pthread_mutex_lock(&store_lock);
    long first = rec_end > LOG_MAX ? rec_end - LOG_MAX : 0;
    for (long seq = first; recs && seq < rec_end; seq++) {
        struct log_rec *r = &recs[seq % LOG_MAX];
        if (r->kind != 1) continue;
        if (filter && *filter && strcmp(filter, r->s[0]) && strcmp(filter, r->s[1])) continue;
        char key[600]; snprintf(key, sizeof key, "%s:%s %s", r->s[0], r->s[1], r->s[4]);
        int k = 0; while (k < nsums && strcmp(sums[k].key, key)) k++;
        if (k == nsums) { if (nsums == 256) continue; memset(&sums[k], 0, sizeof sums[k]); snprintf(sums[k].key, sizeof sums[k].key, "%s", key); nsums++; }
        if (r->sptype == 0) sums[k].events++;
        else if (r->sptype == 1) {
            if (nopens < 512) { snprintf(opens[nopens].key, sizeof opens[nopens].key, "%s", key); opens[nopens].id = r->spid; opens[nopens].begin = r->date; nopens++; }
            sums[k].open++;
        } else {
            for (int o = nopens - 1; o >= 0; o--) if (opens[o].id == r->spid && !strcmp(opens[o].key, key)) {
                double d = (r->date - opens[o].begin) * 1000;
                sums[k].intervals++; sums[k].open--; sums[k].total += d; if (d > sums[k].max) sums[k].max = d;
                opens[o] = opens[--nopens]; break;
            }
        }
    }
    pthread_mutex_unlock(&store_lock);
    pthread_mutex_lock(&log_lock);
    fprintf(stderr, "isim signposts: %d name(s)%s%s\n", nsums, filter && *filter ? " in " : "", filter && *filter ? filter : "");
    for (int k = 0; k < nsums; k++)
        fprintf(stderr, "isim signposts: %s events %d intervals %d open %d total %.1f ms avg %.1f ms max %.1f ms\n", sums[k].key,
                sums[k].events, sums[k].intervals, sums[k].open, sums[k].total, sums[k].intervals ? sums[k].total / sums[k].intervals : 0, sums[k].max);
    fflush(stderr);
    pthread_mutex_unlock(&log_lock);
}

/* ---------------- signposts (C) ---------------- */
static uint64_t sp_counter = 1;
static uint64_t sp_generate(struct os_log_s *l) { (void)l; return __atomic_add_fetch(&sp_counter, 1, __ATOMIC_RELAXED) + 0x1000; }
static uint64_t sp_with_pointer(struct os_log_s *l, const void *p) { (void)l; return (uint64_t)(uintptr_t)p; }
static bool sp_enabled(struct os_log_s *l) { return l && !l->disabled; }
void isim_signpost_print(const char *subsystem, const char *category, int sptype, uint64_t spid, const char *name, const char *msg) {
    const char *e = getenv("ISIM_LOG_SIGNPOSTS");
    if (!e || strcmp(e, "1")) return;
    struct timeval tv; gettimeofday(&tv, NULL);
    time_t t = tv.tv_sec; struct tm tm; localtime_r(&t, &tm);
    char ts[32]; strftime(ts, sizeof ts, "%Y-%m-%d %H:%M:%S", &tm);
    char exe[512]; snprintf(exe, sizeof exe, "%s", isim_main_executable_path() ? isim_main_executable_path() : "app");
    pthread_mutex_lock(&log_lock);
    fprintf(stderr, "%s.%03ld Sp %s[%d:%lx] [%s:%s] %s %s id=%llu%s%s\n", ts, (long)(tv.tv_usec / 1000), basename(exe), getpid(),
            (unsigned long)(uintptr_t)pthread_self() & 0xffffff, subsystem, category,
            sptype == 1 ? "begin" : sptype == 2 ? "end" : "event", name, (unsigned long long)spid, msg && *msg ? " " : "", msg ? msg : "");
    fflush(stderr);
    pthread_mutex_unlock(&log_lock);
}
static void sp_emit(void *dso, struct os_log_s *l, uint8_t type, uint64_t spid, const char *name, const char *fmt, const uint8_t *buf, uint32_t size) {
    (void)dso;
    if (!sp_enabled(l) || spid == 0 || spid == ~0ULL) return;
    char msg[4096] = ""; if (fmt && *fmt) format_message(msg, sizeof msg, fmt, buf, size);
    isim_log_record(1, 0, l->subsystem, l->category, msg, fmt ? fmt : "", type, spid, name ? name : "");
    isim_signpost_print(l->subsystem, l->category, type, spid, name ? name : "", msg);
}

static const struct shim os_table[] = {
    { "_os_signpost_id_generate", (void *)sp_generate, "isim" }, { "_os_signpost_id_make_with_pointer", (void *)sp_with_pointer, "isim" },
    { "_os_signpost_enabled", (void *)sp_enabled, "isim" }, { "__os_signpost_emit_with_name_impl", (void *)sp_emit, "isim" },
    { "_os_unfair_lock_lock", (void *)ul_lock, "isim" }, { "_os_unfair_lock_trylock", (void *)ul_trylock, "isim" },
    { "_os_unfair_lock_unlock", (void *)ul_unlock, "isim" }, { "_os_unfair_lock_assert_owner", (void *)ul_assert_owner, "isim" },
    { "_os_unfair_lock_assert_not_owner", (void *)ul_assert_not_owner, "isim" },
    { "_os_log_create", (void *)log_create, "isim" }, { "_os_log_type_enabled", (void *)log_type_enabled, "isim" },
    { "__os_log_impl", (void *)os_log_impl, "isim" }, { "__os_log_debug_impl", (void *)os_log_impl, "isim" },
    { "__os_log_error_impl", (void *)os_log_impl, "isim" }, { "__os_log_fault_impl", (void *)os_log_impl, "isim" },
    { "__os_log_default", &_os_log_default, "isim" }, { "__os_log_disabled", &_os_log_disabled, "isim" },
};
const struct host_lib host_libsystem_os = { "/usr/lib/system/libsystem_platform.dylib", os_table, sizeof os_table / sizeof *os_table, NULL };
