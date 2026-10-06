/* isim libSystem: os_unfair_lock (libsystem_platform on iOS) on a Linux futex. The 32-bit lock word holds the
 * owner's thread id (bit 31 = waiters), so ownership assertions work and unlocking from another thread aborts
 * like on iOS.
 *
 * Also the C side of unified logging (libsystem_trace): os_log_create, os_log_type_enabled and _os_log_impl,
 * which the os_log() macros call with clang's __builtin_os_log_format buffer. Lines go to stderr in the same
 * format as isim's Swift Logger; private arguments print <private> (ISIM_LOG_PRIVATE=1 shows them). */
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
struct os_log_s { char subsystem[256], category[256]; int disabled; };
struct os_log_s _os_log_default = { "", "", 0 }, _os_log_disabled = { "", "", 1 };
static struct os_log_s *log_create(const char *subsystem, const char *category) {
    struct os_log_s *l = calloc(1, sizeof *l);
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
static pthread_mutex_t log_lock = PTHREAD_MUTEX_INITIALIZER;
static void os_log_impl(void *dso, struct os_log_s *l, uint8_t type, const char *fmt, const uint8_t *buf, uint32_t size) {
    if (!log_type_enabled(l, type) || !fmt) return;
    char msg[4096]; format_message(msg, sizeof msg, fmt, buf, size);
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

static const struct shim os_table[] = {
    { "_os_unfair_lock_lock", (void *)ul_lock, "isim" }, { "_os_unfair_lock_trylock", (void *)ul_trylock, "isim" },
    { "_os_unfair_lock_unlock", (void *)ul_unlock, "isim" }, { "_os_unfair_lock_assert_owner", (void *)ul_assert_owner, "isim" },
    { "_os_unfair_lock_assert_not_owner", (void *)ul_assert_not_owner, "isim" },
    { "_os_log_create", (void *)log_create, "isim" }, { "_os_log_type_enabled", (void *)log_type_enabled, "isim" },
    { "__os_log_impl", (void *)os_log_impl, "isim" }, { "__os_log_debug_impl", (void *)os_log_impl, "isim" },
    { "__os_log_error_impl", (void *)os_log_impl, "isim" }, { "__os_log_fault_impl", (void *)os_log_impl, "isim" },
    { "__os_log_default", &_os_log_default, "isim" }, { "__os_log_disabled", &_os_log_disabled, "isim" },
};
const struct host_lib host_libsystem_os = { "/usr/lib/system/libsystem_platform.dylib", os_table, sizeof os_table / sizeof *os_table };
