/* isim libSystem: Mach interfaces of the calling process (<mach/mach.h>, <mach/mach_time.h>), adapted onto Linux.
 * Included by libsystem.c after the time functions.
 *
 * - Time: mach_absolute_time is CLOCK_UPTIME_RAW (the host's CLOCK_MONOTONIC_RAW), mach_continuous_time also counts
 *   sleep (CLOCK_BOOTTIME); the timebase is 1/1 (nanoseconds), as on the iOS simulator on x86_64.
 * - Port names: the task (mach_task_self_), the host, two clocks, threads (THREAD_PORT | Linux tid) and the ports and
 *   semaphores created here. Only the calling task exists: other task ports are invalid destinations.
 * - Ports are in-process message queues: mach_msg sends and receives simple messages (no port or memory descriptors)
 *   between ports of this process, with queue limits, timeouts, reply ports and send / send-once rights.
 * - task_info, thread_info and task_threads read /proc/self; host_info / host_statistics read /proc, with the memory
 *   size of the simulated device and VM page counts scaled to it; host_processor_info gives the host's CPUs' ticks.
 * - vm_allocate & co. are mmap / munmap / mprotect; vm_read_overwrite reads memory without faulting.
 * - Semaphores are a count with a mutex and condition variable.
 */
#include <dirent.h>
#include <sys/mman.h>
#include <sys/resource.h>
#include <sys/uio.h>
#include <sys/eventfd.h>

#define M_KERN_SUCCESS 0
#define M_KERN_INVALID_ADDRESS 1
#define M_KERN_PROTECTION_FAILURE 2
#define M_KERN_NO_SPACE 3
#define M_KERN_INVALID_ARGUMENT 4
#define M_KERN_FAILURE 5
#define M_KERN_RESOURCE_SHORTAGE 6
#define M_KERN_INVALID_NAME 15
#define M_KERN_INVALID_TASK 16
#define M_KERN_INVALID_RIGHT 17
#define M_KERN_INVALID_VALUE 18
#define M_KERN_TERMINATED 37
#define M_KERN_OPERATION_TIMED_OUT 49
#define M_SEND_INVALID_DEST 0x10000003
#define M_SEND_TIMED_OUT 0x10000004
#define M_SEND_MSG_TOO_SMALL 0x10000008
#define M_SEND_INVALID_REPLY 0x10000009
#define M_SEND_INVALID_TYPE 0x1000000f
#define M_SEND_INVALID_HEADER 0x10000010
#define M_RCV_INVALID_NAME 0x10004002
#define M_RCV_TIMED_OUT 0x10004003
#define M_RCV_TOO_LARGE 0x10004004
#define M_RCV_PORT_DIED 0x10004009

typedef int kern_return_t;
typedef unsigned int mach_port_name_t;
typedef unsigned int natural_t;
typedef int integer_t;
struct m_time_value { integer_t seconds, microseconds; };
static uint64_t mach_msgs_sent, mach_msgs_received;          /* TASK_EVENTS_INFO */

/* ---------------- time ---------------- */
static uint64_t d_mach_absolute_time(void) { return d_clock_gettime_nsec_np(8); }   /* Darwin: CLOCK_UPTIME_RAW */
static uint64_t d_mach_continuous_time(void) {          /* absolute time + time suspended (BOOTTIME - MONOTONIC) */
    struct timespec b, m; clock_gettime(CLOCK_BOOTTIME, &b); clock_gettime(CLOCK_MONOTONIC, &m);
    int64_t asleep = (int64_t)(b.tv_sec - m.tv_sec) * 1000000000ll + (b.tv_nsec - m.tv_nsec);
    return d_mach_absolute_time() + (uint64_t)(asleep > 0 ? asleep : 0);
}
struct d_timebase { uint32_t numer, denom; };
static int d_mach_timebase_info(struct d_timebase *tb) { tb->numer = 1; tb->denom = 1; return 0; }
static kern_return_t d_mach_wait_until(uint64_t deadline) {
    for (uint64_t now; (now = d_mach_absolute_time()) < deadline;) {
        uint64_t d = deadline - now;
        struct timespec ts = { (time_t)(d / 1000000000ull), (long)(d % 1000000000ull) };
        nanosleep(&ts, NULL);
    }
    return M_KERN_SUCCESS;
}

/* ---------------- special port names ---------------- */
#define TASK_PORT 0x103u
#define HOST_PORT 0x203u
#define SYSTEM_CLOCK_PORT 0x303u
#define CALENDAR_CLOCK_PORT 0x403u
#define THREAD_PORT 0x40000000u                 /* | Linux tid */
static unsigned int d_mach_task_self_ = TASK_PORT;
static uintptr_t d_vm_page_size, d_vm_page_mask; static int d_vm_page_shift;
static mach_port_name_t d_mach_host_self(void) { return HOST_PORT; }
static int is_task(mach_port_name_t t) { return t == TASK_PORT; }

/* ---------------- threads: pthread_t <-> Linux tid (registered when they start) ---------------- */
struct treg { pthread_t t; pid_t tid; };
static pthread_mutex_t treg_lock = PTHREAD_MUTEX_INITIALIZER;
static struct treg *tregs; static int ntregs, captregs;
static pthread_key_t treg_key;
static void treg_remove(void *unused) {
    pthread_mutex_lock(&treg_lock);
    for (int i = 0; i < ntregs; i++) if (pthread_equal(tregs[i].t, pthread_self())) { tregs[i] = tregs[--ntregs]; break; }
    pthread_mutex_unlock(&treg_lock);
}
static void treg_add(void) {
    if (pthread_getspecific(treg_key)) return;
    pthread_mutex_lock(&treg_lock);
    if (ntregs == captregs) { captregs = captregs ? captregs * 2 : 64; tregs = realloc(tregs, captregs * sizeof *tregs); }
    tregs[ntregs++] = (struct treg){ pthread_self(), gettid() };
    pthread_mutex_unlock(&treg_lock);
    pthread_setspecific(treg_key, (void *)1);     /* treg_remove runs when the thread exits */
}
static pid_t tid_of(pthread_t t) {
    if (pthread_equal(t, pthread_self())) { treg_add(); return gettid(); }
    pid_t tid = 0;
    pthread_mutex_lock(&treg_lock);
    for (int i = 0; i < ntregs && !tid; i++) if (pthread_equal(tregs[i].t, t)) tid = tregs[i].tid;
    pthread_mutex_unlock(&treg_lock);
    return tid;
}
static pthread_t pthread_of(pid_t tid) {
    pthread_t t = 0;
    pthread_mutex_lock(&treg_lock);
    for (int i = 0; i < ntregs; i++) if (tregs[i].tid == tid) t = tregs[i].t;
    pthread_mutex_unlock(&treg_lock);
    return t;
}
struct tstart { void *(*fn)(void *); void *arg; };
static void *thread_trampoline(void *p) {
    struct tstart s = *(struct tstart *)p;
    free(p);
    treg_add();
    return s.fn(s.arg);
}
static mach_port_name_t d_pthread_mach_thread_np(pthread_t t) {
    pid_t tid = tid_of(t);
    return tid ? THREAD_PORT | (unsigned)tid : (unsigned int)(((uintptr_t)t >> 12) & 0x3fffffff) | 1;
}
static pthread_t d_pthread_from_mach_thread_np(mach_port_name_t port) { return port & THREAD_PORT ? pthread_of((pid_t)(port & ~THREAD_PORT)) : 0; }
static int d_pthread_threadid_np(pthread_t t, uint64_t *id) {   /* the Linux tid (NULL: the calling thread) */
    pid_t tid = tid_of(t ? t : pthread_self());
    if (id) *id = tid ? (uint64_t)tid : (uint64_t)(uintptr_t)t;
    return 0;
}
static mach_port_name_t d_mach_thread_self(void) { treg_add(); return THREAD_PORT | (unsigned)gettid(); }

/* ---------------- /proc ---------------- */
static ssize_t read_text(const char *path, char *buf, size_t cap) {
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return -1;
    size_t n = 0; ssize_t r;
    while (n < cap - 1 && (r = read(fd, buf + n, cap - 1 - n)) > 0) n += r;
    close(fd);
    buf[n] = 0;
    return n;
}
static uint64_t field_kb(const char *text, const char *key) {      /* "Key:   123 kB" -> bytes */
    const char *p = strstr(text, key);
    return p ? strtoull(p + strlen(key), NULL, 10) * 1024 : 0;
}
static uint64_t field_num(const char *text, const char *key) {
    const char *p = strstr(text, key);
    return p ? strtoull(p + strlen(key), NULL, 10) : 0;
}
struct tstat { char state; uint64_t utime, stime, start; };          /* clock ticks */
static int thread_stat(pid_t tid, struct tstat *s) {
    char path[64], buf[1024];
    snprintf(path, sizeof path, "/proc/self/task/%d/stat", tid);
    if (read_text(path, buf, sizeof buf) <= 0) return -1;
    char *p = strrchr(buf, ')');
    if (!p) return -1;
    unsigned long long f[22] = {0};                                  /* fields 3.. after "pid (comm)" */
    s->state = p[2];
    p += 4;
    for (int i = 4; i <= 22 && *p; i++) { f[i - 1] = strtoull(p, &p, 10); while (*p == ' ') p++; }
    s->utime = f[13]; s->stime = f[14]; s->start = f[21];
    return 0;
}
static long clk_tck(void) { static long t; if (!t) t = sysconf(_SC_CLK_TCK); return t > 0 ? t : 100; }
static struct m_time_value tv_of_ticks(uint64_t ticks) {
    uint64_t us = ticks * 1000000ull / clk_tck();
    return (struct m_time_value){ (integer_t)(us / 1000000), (integer_t)(us % 1000000) };
}
static struct m_time_value tv_of_timeval(struct timeval t) { return (struct m_time_value){ (integer_t)t.tv_sec, (integer_t)t.tv_usec }; }
static uint64_t now_boot_ns(void) { struct timespec ts; clock_gettime(CLOCK_BOOTTIME, &ts); return (uint64_t)ts.tv_sec * 1000000000ull + ts.tv_nsec; }

/* a thread's recent CPU usage (TH_USAGE_SCALE = 1000 is one CPU), like iOS's average and independent of how often it is
   asked: measured from a baseline (the thread's start, then a sample at least a second old), so back-to-back queries
   agree */
struct usage_sample { pid_t tid; uint64_t cpu_ns, wall_ns; integer_t last; };
static struct usage_sample usage_samples[256];
static pthread_mutex_t usage_lock = PTHREAD_MUTEX_INITIALIZER;
static integer_t cpu_usage(pid_t tid, const struct tstat *s) {
    uint64_t cpu = (s->utime + s->stime) * 1000000000ull / clk_tck(), wall = now_boot_ns();
    pthread_mutex_lock(&usage_lock);
    struct usage_sample *b = &usage_samples[(unsigned)tid % 256];
    if (b->tid != tid || b->wall_ns > wall || b->cpu_ns > cpu) *b = (struct usage_sample){ tid, 0, s->start * 1000000000ull / clk_tck(), 0 };
    uint64_t dw = wall - b->wall_ns;
    integer_t u = b->last;
    if (dw >= 50000000ull) { uint64_t x = (cpu - b->cpu_ns) * 1000 / dw; u = (integer_t)(x > 1000 ? 1000 : x); }
    if (dw >= 1000000000ull) { b->cpu_ns = cpu; b->wall_ns = wall; b->last = u; }
    pthread_mutex_unlock(&usage_lock);
    return u;
}
static int run_state(char c) { return c == 'R' ? 1 : c == 'T' || c == 't' ? 2 : c == 'D' ? 4 : c == 'Z' || c == 'X' ? 5 : 3; }

/* ---------------- thread_info / task_threads ---------------- */
static int valid_thread(mach_port_name_t port, pid_t *tid, struct tstat *s) {
    if (!(port & THREAD_PORT)) return 0;
    *tid = (pid_t)(port & ~THREAD_PORT);
    return thread_stat(*tid, s) == 0 && s->state != 'Z' && s->state != 'X';     /* an exited thread is gone */
}
static kern_return_t d_thread_info(mach_port_name_t port, natural_t flavor, integer_t *info, natural_t *count) {
    pid_t tid; struct tstat s;
    if (!valid_thread(port, &tid, &s)) return M_SEND_INVALID_DEST;
    struct rusage ru; int self = tid == gettid() && getrusage(RUSAGE_THREAD, &ru) == 0;   /* the caller: exact times */
    switch (flavor) {
    case 3: {                                                       /* THREAD_BASIC_INFO */
        struct { struct m_time_value user, system; integer_t cpu_usage, policy, run_state, flags, suspend_count, sleep_time; } b = {
            self ? tv_of_timeval(ru.ru_utime) : tv_of_ticks(s.utime), self ? tv_of_timeval(ru.ru_stime) : tv_of_ticks(s.stime),
            cpu_usage(tid, &s), 1 /* POLICY_TIMESHARE */, self ? 1 : run_state(s.state), 0, 0, 0 };
        if (*count < sizeof b / 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, &b, sizeof b); *count = sizeof b / 4;
        return M_KERN_SUCCESS;
    }
    case 4: {                                                       /* THREAD_IDENTIFIER_INFO */
        struct { uint64_t thread_id, thread_handle, dispatch_qaddr; } b = { (uint64_t)tid, (uint64_t)(uintptr_t)pthread_of(tid), 0 };
        if (self) b.thread_handle = (uint64_t)(uintptr_t)pthread_self();
        if (*count < sizeof b / 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, &b, sizeof b); *count = sizeof b / 4;
        return M_KERN_SUCCESS;
    }
    case 5: {                                                       /* THREAD_EXTENDED_INFO */
        struct { uint64_t user_ns, system_ns; int32_t cpu_usage, policy, run_state, flags, sleep_time, curpri, priority, maxpriority; char name[64]; } b;
        memset(&b, 0, sizeof b);
        b.user_ns = self ? (uint64_t)ru.ru_utime.tv_sec * 1000000000ull + ru.ru_utime.tv_usec * 1000ull : s.utime * 1000000000ull / clk_tck();
        b.system_ns = self ? (uint64_t)ru.ru_stime.tv_sec * 1000000000ull + ru.ru_stime.tv_usec * 1000ull : s.stime * 1000000000ull / clk_tck();
        b.cpu_usage = cpu_usage(tid, &s); b.policy = 1; b.run_state = self ? 1 : run_state(s.state);
        b.curpri = b.priority = 31; b.maxpriority = 63;
        char path[64]; snprintf(path, sizeof path, "/proc/self/task/%d/comm", tid);
        if (read_text(path, b.name, sizeof b.name) > 0) b.name[strcspn(b.name, "\n")] = 0;
        if (*count < sizeof b / 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, &b, sizeof b); *count = sizeof b / 4;
        return M_KERN_SUCCESS;
    }
    default: return M_KERN_INVALID_ARGUMENT;
    }
}
static int cmp_int(const void *a, const void *b) { int x = *(const int *)a, y = *(const int *)b; return (x > y) - (x < y); }
static int thread_ids(int **out) {
    DIR *d = opendir("/proc/self/task");
    int n = 0, cap = 64, *ids = malloc(cap * sizeof *ids);
    for (struct dirent *e; d && (e = readdir(d));) {
        int tid = atoi(e->d_name);
        if (tid <= 0) continue;
        if (n == cap) ids = realloc(ids, (cap *= 2) * sizeof *ids);
        ids[n++] = tid;
    }
    if (d) closedir(d);
    qsort(ids, n, sizeof *ids, cmp_int);
    *out = ids;
    return n;
}
static void *vm_alloc_bytes(size_t n) {               /* out-of-line results: the caller frees them with vm_deallocate */
    void *p = mmap(NULL, n ? n : 1, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);
    return p == MAP_FAILED ? NULL : p;
}
static kern_return_t d_task_threads(mach_port_name_t task, mach_port_name_t **list, natural_t *count) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    int *ids; int n = thread_ids(&ids);
    mach_port_name_t *ports = vm_alloc_bytes(n * sizeof *ports);
    if (!ports) { free(ids); return M_KERN_RESOURCE_SHORTAGE; }
    for (int i = 0; i < n; i++) ports[i] = THREAD_PORT | (unsigned)ids[i];
    free(ids);
    *list = ports; *count = (natural_t)n;
    return M_KERN_SUCCESS;
}
static kern_return_t d_thread_policy_set(mach_port_name_t thread, natural_t flavor, integer_t *info, natural_t count) {
    pid_t tid; struct tstat s;
    return valid_thread(thread, &tid, &s) ? M_KERN_SUCCESS : M_SEND_INVALID_DEST;   /* accepted, not applied */
}
static kern_return_t d_thread_policy_get(mach_port_name_t thread, natural_t flavor, integer_t *info, natural_t *count, int *get_default) {
    pid_t tid; struct tstat s;
    if (!valid_thread(thread, &tid, &s)) return M_SEND_INVALID_DEST;
    if (!*count) return M_KERN_INVALID_ARGUMENT;
    memset(info, 0, *count * 4);
    if (flavor == 1) info[0] = 1;                                   /* THREAD_EXTENDED_POLICY: timeshare */
    if (get_default) *get_default = 1;
    return M_KERN_SUCCESS;
}

/* ---------------- the simulated device ---------------- */
static uint64_t device_memory(void) {                  /* as NSProcessInfo.physicalMemory: by device model */
    const char *d = getenv("ISIM_DEVICE"); if (!d) d = "iphone15";
    uint64_t gb = !strncmp(d, "iphonese", 8) || !strncmp(d, "iphone13", 8) || !strncmp(d, "iphone14", 8) ? 4 :
                  !strcmp(d, "iphone15") || !strcmp(d, "iphone15plus") ? 6 : !strncmp(d, "ipadpro", 7) ? 16 : 8;
    return gb << 30;
}

/* ---------------- task_info ---------------- */
static uint64_t footprint_peak;
static kern_return_t d_task_info(mach_port_name_t task, natural_t flavor, integer_t *info, natural_t *count) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    char st[4096]; read_text("/proc/self/status", st, sizeof st);
    uint64_t vsize = field_kb(st, "VmSize:"), rss = field_kb(st, "VmRSS:"), hwm = field_kb(st, "VmHWM:");
    uint64_t anon = field_kb(st, "RssAnon:"), file = field_kb(st, "RssFile:"), shmem = field_kb(st, "RssShmem:");
    uint64_t swap = field_kb(st, "VmSwap:"), footprint = anon + shmem + swap;
    if (footprint > footprint_peak) footprint_peak = footprint;
    /* CPU times: Mach splits them into terminated threads (task_basic_info) and live ones (task_thread_times_info) */
    struct rusage ru; getrusage(RUSAGE_SELF, &ru);
    uint64_t total_u = (uint64_t)ru.ru_utime.tv_sec * 1000000 + ru.ru_utime.tv_usec, total_s = (uint64_t)ru.ru_stime.tv_sec * 1000000 + ru.ru_stime.tv_usec;
    uint64_t live_u = 0, live_s = 0;
    if (flavor == 20 || flavor == 5 || flavor == 3) {
        int *ids; int n = thread_ids(&ids);
        for (int i = 0; i < n; i++) {
            struct tstat s;
            if (thread_stat(ids[i], &s) == 0) { live_u += s.utime * 1000000ull / clk_tck(); live_s += s.stime * 1000000ull / clk_tck(); }
        }
        free(ids);
    }
    if (live_u > total_u) live_u = total_u;
    if (live_s > total_s) live_s = total_s;
    struct m_time_value dead_u = { (integer_t)((total_u - live_u) / 1000000), (integer_t)((total_u - live_u) % 1000000) };
    struct m_time_value dead_s = { (integer_t)((total_s - live_s) / 1000000), (integer_t)((total_s - live_s) % 1000000) };
    switch (flavor) {
    case 20: {                                                      /* MACH_TASK_BASIC_INFO */
        struct __attribute__((packed, aligned(4))) { uint64_t virtual_size, resident_size, resident_size_max; struct m_time_value user, system; integer_t policy, suspend_count; } b =
            { vsize, rss, hwm, dead_u, dead_s, 1, 0 };
        if (*count < sizeof b / 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, &b, sizeof b); *count = sizeof b / 4;
        return M_KERN_SUCCESS;
    }
    case 5: {                                                       /* TASK_BASIC_INFO_64 (TASK_BASIC_INFO) */
        struct __attribute__((packed, aligned(4))) { integer_t suspend_count; uint64_t virtual_size, resident_size; struct m_time_value user, system; integer_t policy; } b =
            { 0, vsize, rss, dead_u, dead_s, 1 };
        if (*count < sizeof b / 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, &b, sizeof b); *count = sizeof b / 4;
        return M_KERN_SUCCESS;
    }
    case 3: {                                                       /* TASK_THREAD_TIMES_INFO */
        struct m_time_value b[2] = { { (integer_t)(live_u / 1000000), (integer_t)(live_u % 1000000) },
                                     { (integer_t)(live_s / 1000000), (integer_t)(live_s % 1000000) } };
        if (*count < 4) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, b, sizeof b); *count = 4;
        return M_KERN_SUCCESS;
    }
    case 2: {                                                       /* TASK_EVENTS_INFO */
        char stat[1024]; read_text("/proc/self/stat", stat, sizeof stat);
        unsigned long long minflt = 0, majflt = 0; char *p = strrchr(stat, ')');
        if (p) sscanf(p + 2, "%*c %*d %*d %*d %*d %*d %*u %llu %*u %llu", &minflt, &majflt);
        integer_t b[8] = { (integer_t)(minflt + majflt), (integer_t)majflt, 0, 0, 0, 0, 0,
                           (integer_t)(field_num(st, "voluntary_ctxt_switches:") + field_num(st, "nonvoluntary_ctxt_switches:")) };
        b[3] = (integer_t)mach_msgs_sent; b[4] = (integer_t)mach_msgs_received;
        if (*count < 8) return M_KERN_INVALID_ARGUMENT;
        memcpy(info, b, sizeof b); *count = 8;
        return M_KERN_SUCCESS;
    }
    case 22: {                                                      /* TASK_VM_INFO */
        struct __attribute__((packed, aligned(4))) {
            uint64_t virtual_size; integer_t region_count, page_size;
            uint64_t resident_size, resident_size_peak, device, device_peak, internal, internal_peak, external, external_peak,
                     reusable, reusable_peak, pv_pmap, pv_resident, pv_virtual, compressed, compressed_peak, compressed_lifetime;
            uint64_t phys_footprint;                                   /* rev1 */
            uint64_t min_address, max_address;                         /* rev2 */
            int64_t ledger[21];                                         /* rev3: ledger_phys_footprint_peak, ... */
            uint64_t limit_bytes_remaining;                            /* rev4 */
            integer_t decompressions;                                  /* rev5 */
            int64_t ledger_swapins;                                    /* rev6 */
            int64_t neural_total, neural_peak;                         /* rev7 */
        } b;
        memset(&b, 0, sizeof b);
        char *maps = malloc(1 << 18); ssize_t n = read_text("/proc/self/maps", maps, 1 << 18);
        int regions = 0; uint64_t lo = UINT64_MAX, hi = 0;
        for (char *line = maps; n > 0 && *line;) {
            unsigned long long a, z;
            if (sscanf(line, "%llx-%llx", &a, &z) == 2 && z < 0xffffffffff600000ull) { regions++; if (a < lo) lo = a; if (z > hi) hi = z; }
            char *nl = strchr(line, '\n'); if (!nl) break; line = nl + 1;
        }
        free(maps);
        b.virtual_size = vsize; b.region_count = regions; b.page_size = (integer_t)d_vm_page_size;
        b.resident_size = rss; b.resident_size_peak = hwm;
        b.internal = b.internal_peak = anon + shmem; b.external = b.external_peak = file;
        b.phys_footprint = footprint;
        b.min_address = lo == UINT64_MAX ? 0 : lo; b.max_address = hi;
        b.ledger[0] = (int64_t)footprint_peak;
        b.limit_bytes_remaining = 0;                                   /* no memory limit (as in the iOS simulator) */
        b.ledger_swapins = 0;
        natural_t full = sizeof b / 4, rev0 = __builtin_offsetof(__typeof__(b), phys_footprint) / 4;
        if (*count < rev0) return M_KERN_INVALID_ARGUMENT;
        natural_t revs[] = { rev0, __builtin_offsetof(__typeof__(b), min_address) / 4, __builtin_offsetof(__typeof__(b), ledger) / 4,
                             __builtin_offsetof(__typeof__(b), limit_bytes_remaining) / 4, __builtin_offsetof(__typeof__(b), decompressions) / 4,
                             __builtin_offsetof(__typeof__(b), ledger_swapins) / 4, __builtin_offsetof(__typeof__(b), neural_total) / 4, full };
        natural_t give = rev0;                                          /* the newest revision that fits */
        for (size_t i = 0; i < sizeof revs / sizeof *revs; i++) if (revs[i] <= *count) give = revs[i];
        memcpy(info, &b, give * 4); *count = give;
        return M_KERN_SUCCESS;
    }
    default: return M_KERN_INVALID_ARGUMENT;
    }
}

/* ---------------- host ---------------- */
static int ncpus(void) { long n = sysconf(_SC_NPROCESSORS_ONLN); return n > 0 ? (int)n : 1; }
static kern_return_t d_host_page_size(mach_port_name_t host, uintptr_t *size) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    *size = d_vm_page_size;
    return M_KERN_SUCCESS;
}
static kern_return_t d_host_info(mach_port_name_t host, natural_t flavor, integer_t *info, natural_t *count) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    if (flavor == 1) {                                              /* HOST_BASIC_INFO */
        uint64_t mem = device_memory();
        struct __attribute__((packed, aligned(4))) { integer_t max_cpus, avail_cpus; natural_t memory_size; integer_t cpu_type, cpu_subtype, cpu_threadtype,
                 physical_cpu, physical_cpu_max, logical_cpu, logical_cpu_max; uint64_t max_mem; } b =
            { ncpus(), ncpus(), (natural_t)(mem > 0x80000000ull ? 0x80000000ull : mem), 0x01000007 /* CPU_TYPE_X86_64 */, 3 /* _ALL */, 0,
              ncpus(), ncpus(), ncpus(), ncpus(), mem };
        if (*count < 5) return M_KERN_FAILURE;                       /* HOST_BASIC_INFO_OLD_COUNT */
        natural_t give = *count < sizeof b / 4 ? 5 : sizeof b / 4;
        memcpy(info, &b, give * 4); *count = give;
        return M_KERN_SUCCESS;
    }
    if (flavor == 3) {                                              /* HOST_SCHED_INFO: min timeout / quantum (ms) */
        if (*count < 2) return M_KERN_FAILURE;
        info[0] = 10; info[1] = 10; *count = 2;
        return M_KERN_SUCCESS;
    }
    return M_KERN_INVALID_ARGUMENT;
}
/* CPU ticks of /proc/stat's "cpu" (cpu < 0) or "cpuN" line, in Mach's order: user, system, idle, nice */
static int cpu_ticks(int cpu, natural_t t[4]) {
    static char buf[1 << 15];
    static pthread_mutex_t lk = PTHREAD_MUTEX_INITIALIZER;
    pthread_mutex_lock(&lk);
    int found = 0;
    if (read_text("/proc/stat", buf, sizeof buf) > 0) {
        char want[16]; if (cpu < 0) snprintf(want, sizeof want, "cpu "); else snprintf(want, sizeof want, "cpu%d ", cpu);
        char *p = strstr(buf, want);
        unsigned long long user, nice, sys, idle, iowait = 0, irq = 0, softirq = 0;
        if (p && sscanf(p + strlen(want), "%llu %llu %llu %llu %llu %llu %llu", &user, &nice, &sys, &idle, &iowait, &irq, &softirq) >= 4) {
            t[0] = (natural_t)user; t[1] = (natural_t)(sys + irq + softirq); t[2] = (natural_t)(idle + iowait); t[3] = (natural_t)nice;
            found = 1;
        }
    }
    pthread_mutex_unlock(&lk);
    return found;
}
/* VM page counts from /proc/meminfo and /proc/vmstat; counts of memory are scaled from the host's to the simulated
   device's memory size, so they add up to it */
struct vmstats { uint64_t free, active, inactive, wire, internal, external, faults, pageins, pageouts, swapins, swapouts; };
static void vm_stats(struct vmstats *v) {
    char mi[4096], vs[1 << 14];
    read_text("/proc/meminfo", mi, sizeof mi);
    if (read_text("/proc/vmstat", vs, sizeof vs) < 0) vs[0] = 0;
    uint64_t total = field_kb(mi, "MemTotal:"), page = d_vm_page_size;
    double scale = total ? (double)device_memory() / total : 1;
    uint64_t freeb = field_kb(mi, "MemFree:"), act = field_kb(mi, "Active:"), inact = field_kb(mi, "Inactive:");
    uint64_t wire = total > freeb + act + inact ? total - freeb - act - inact : 0;
    v->free = (uint64_t)(freeb * scale) / page; v->active = (uint64_t)(act * scale) / page;
    v->inactive = (uint64_t)(inact * scale) / page; v->wire = (uint64_t)(wire * scale) / page;
    v->internal = (uint64_t)((field_kb(mi, "Active(anon):") + field_kb(mi, "Inactive(anon):")) * scale) / page;
    v->external = (uint64_t)((field_kb(mi, "Active(file):") + field_kb(mi, "Inactive(file):")) * scale) / page;
    v->faults = field_num(vs, "\npgfault "); v->pageins = field_num(vs, "\npgmajfault ");
    v->pageouts = field_num(vs, "\npswpout "); v->swapins = field_num(vs, "\npswpin "); v->swapouts = v->pageouts;
}
static kern_return_t d_host_statistics(mach_port_name_t host, natural_t flavor, integer_t *info, natural_t *count) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    switch (flavor) {
    case 1: {                                                       /* HOST_LOAD_INFO: load averages * LOAD_SCALE */
        double l[3] = {0};
        char buf[128]; if (read_text("/proc/loadavg", buf, sizeof buf) > 0) sscanf(buf, "%lf %lf %lf", &l[0], &l[1], &l[2]);
        if (*count < 6) return M_KERN_FAILURE;
        for (int i = 0; i < 3; i++) { info[i] = (integer_t)(l[i] * 1000); info[3 + i] = (integer_t)(ncpus() * 1000 - l[i] * 1000 > 0 ? ncpus() * 1000 - l[i] * 1000 : 0); }
        *count = 6;
        return M_KERN_SUCCESS;
    }
    case 2: {                                                       /* HOST_VM_INFO */
        struct vmstats v; vm_stats(&v);
        natural_t b[15] = { (natural_t)v.free, (natural_t)v.active, (natural_t)v.inactive, (natural_t)v.wire, 0, 0,
                            (natural_t)v.pageins, (natural_t)v.pageouts, (natural_t)v.faults, 0, 0, 0, 0, 0, 0 };
        if (*count < 15) return M_KERN_FAILURE;
        memcpy(info, b, sizeof b); *count = 15;
        return M_KERN_SUCCESS;
    }
    case 3: {                                                       /* HOST_CPU_LOAD_INFO */
        natural_t t[4];
        if (*count < 4) return M_KERN_FAILURE;
        if (!cpu_ticks(-1, t)) return M_KERN_FAILURE;
        memcpy(info, t, sizeof t); *count = 4;
        return M_KERN_SUCCESS;
    }
    default: return M_KERN_INVALID_ARGUMENT;
    }
}
static kern_return_t d_host_statistics64(mach_port_name_t host, natural_t flavor, integer_t *info, natural_t *count) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    if (flavor != 4) return d_host_statistics(host, flavor, info, count);   /* HOST_VM_INFO64 */
    struct vmstats v; vm_stats(&v);
    struct __attribute__((aligned(8))) {
        natural_t free_count, active_count, inactive_count, wire_count;
        uint64_t zero_fill_count, reactivations, pageins, pageouts, faults, cow_faults, lookups, hits, purges;
        natural_t purgeable_count, speculative_count;
        uint64_t decompressions, compressions, swapins, swapouts;
        natural_t compressor_page_count, throttled_count, external_page_count, internal_page_count;
        uint64_t total_uncompressed_pages_in_compressor;
    } b;
    memset(&b, 0, sizeof b);
    b.free_count = (natural_t)v.free; b.active_count = (natural_t)v.active; b.inactive_count = (natural_t)v.inactive;
    b.wire_count = (natural_t)v.wire; b.pageins = v.pageins; b.pageouts = v.pageouts; b.faults = v.faults;
    b.swapins = v.swapins; b.swapouts = v.swapouts;
    b.external_page_count = (natural_t)v.external; b.internal_page_count = (natural_t)v.internal;
    natural_t rev0 = __builtin_offsetof(__typeof__(b), decompressions) / 4;
    if (*count < rev0) return M_KERN_FAILURE;
    natural_t give = *count < sizeof b / 4 ? rev0 : sizeof b / 4;
    memcpy(info, &b, give * 4); *count = give;
    return M_KERN_SUCCESS;
}
static kern_return_t d_host_processor_info(mach_port_name_t host, natural_t flavor, natural_t *nproc, integer_t **info, natural_t *count) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    int n = ncpus();
    if (flavor == 2) {                                              /* PROCESSOR_CPU_LOAD_INFO */
        natural_t *t = vm_alloc_bytes(n * 4 * sizeof *t);
        if (!t) return M_KERN_RESOURCE_SHORTAGE;
        for (int i = 0; i < n; i++) if (!cpu_ticks(i, t + 4 * i)) memset(t + 4 * i, 0, 4 * sizeof *t);
        *nproc = (natural_t)n; *info = (integer_t *)t; *count = (natural_t)(n * 4);
        return M_KERN_SUCCESS;
    }
    if (flavor == 1) {                                              /* PROCESSOR_BASIC_INFO */
        integer_t *b = vm_alloc_bytes(n * 5 * sizeof *b);
        if (!b) return M_KERN_RESOURCE_SHORTAGE;
        for (int i = 0; i < n; i++) { integer_t *e = b + 5 * i; e[0] = 0x01000007; e[1] = 3; e[2] = 1; e[3] = i; e[4] = i == 0; }
        *nproc = (natural_t)n; *info = b; *count = (natural_t)(n * 5);
        return M_KERN_SUCCESS;
    }
    return M_KERN_INVALID_ARGUMENT;
}

/* ---------------- clocks ---------------- */
struct m_timespec { unsigned int tv_sec; int tv_nsec; };
static kern_return_t d_host_get_clock_service(mach_port_name_t host, int clock_id, mach_port_name_t *clock) {
    if (host != HOST_PORT) return M_SEND_INVALID_DEST;
    if (clock_id != 0 && clock_id != 1) return M_KERN_INVALID_ARGUMENT;
    *clock = clock_id ? CALENDAR_CLOCK_PORT : SYSTEM_CLOCK_PORT;
    return M_KERN_SUCCESS;
}
static kern_return_t d_clock_get_time(mach_port_name_t clock, struct m_timespec *t) {
    if (clock != SYSTEM_CLOCK_PORT && clock != CALENDAR_CLOCK_PORT) return M_SEND_INVALID_DEST;
    struct timespec ts; clock_gettime(clock == SYSTEM_CLOCK_PORT ? CLOCK_MONOTONIC_RAW : CLOCK_REALTIME, &ts);
    t->tv_sec = (unsigned int)ts.tv_sec; t->tv_nsec = (int)ts.tv_nsec;
    return M_KERN_SUCCESS;
}

/* ---------------- virtual memory ---------------- */
static kern_return_t vm_alloc(mach_port_name_t task, uint64_t *addr, uint64_t size, int flags) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (!size) { if (flags & 1) *addr = 0; return M_KERN_SUCCESS; }
    size = (size + d_vm_page_mask) & ~(uint64_t)d_vm_page_mask;
    void *p;
    if (flags & 1) p = mmap(NULL, size, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS, -1, 0);   /* VM_FLAGS_ANYWHERE */
    else {
        if (*addr & d_vm_page_mask) return M_KERN_INVALID_ADDRESS;
        p = mmap((void *)(uintptr_t)*addr, size, PROT_READ | PROT_WRITE,
                 MAP_PRIVATE | MAP_ANONYMOUS | (flags & 0x4000 /* VM_FLAGS_OVERWRITE */ ? MAP_FIXED : MAP_FIXED_NOREPLACE), -1, 0);
        if (p != MAP_FAILED && (uintptr_t)p != *addr) { munmap(p, size); p = MAP_FAILED; }   /* kernels without NOREPLACE */
    }
    if (p == MAP_FAILED) return M_KERN_NO_SPACE;
    *addr = (uint64_t)(uintptr_t)p;
    return M_KERN_SUCCESS;
}
static kern_return_t vm_dealloc(mach_port_name_t task, uint64_t addr, uint64_t size) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (!size) return M_KERN_SUCCESS;
    uint64_t start = addr & ~(uint64_t)d_vm_page_mask, end = (addr + size + d_vm_page_mask) & ~(uint64_t)d_vm_page_mask;
    return munmap((void *)(uintptr_t)start, end - start) ? M_KERN_INVALID_ADDRESS : M_KERN_SUCCESS;
}
static kern_return_t vm_prot(mach_port_name_t task, uint64_t addr, uint64_t size, int set_max, int prot) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (set_max) return M_KERN_SUCCESS;                              /* Linux has no maximum protection to lower */
    uint64_t start = addr & ~(uint64_t)d_vm_page_mask, end = (addr + size + d_vm_page_mask) & ~(uint64_t)d_vm_page_mask;
    int p = (prot & 1 ? PROT_READ : 0) | (prot & 2 ? PROT_WRITE : 0) | (prot & 4 ? PROT_EXEC : 0);
    if (!mprotect((void *)(uintptr_t)start, end - start, p)) return M_KERN_SUCCESS;
    return errno == EACCES ? M_KERN_PROTECTION_FAILURE : M_KERN_INVALID_ADDRESS;
}
/* copy memory that may not be mapped: process_vm_readv on ourselves, or through a pipe (write fails with EFAULT) */
static kern_return_t vm_read_over(mach_port_name_t task, uint64_t addr, uint64_t size, uint64_t data, uint64_t *out) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    struct iovec local = { (void *)(uintptr_t)data, size }, remote = { (void *)(uintptr_t)addr, size };
    ssize_t r = process_vm_readv(getpid(), &local, 1, &remote, 1, 0);
    if (r == (ssize_t)size) { if (out) *out = size; return M_KERN_SUCCESS; }
    if (r < 0 && errno != EPERM && errno != ENOSYS) return M_KERN_INVALID_ADDRESS;
    int fds[2];
    if (r >= 0 || pipe2(fds, O_CLOEXEC)) return M_KERN_INVALID_ADDRESS;
    kern_return_t kr = M_KERN_SUCCESS;
    for (uint64_t done = 0; done < size && kr == M_KERN_SUCCESS;) {
        size_t chunk = size - done > 4096 ? 4096 : size - done;
        if (write(fds[1], (const char *)(uintptr_t)addr + done, chunk) != (ssize_t)chunk ||
            read(fds[0], (char *)(uintptr_t)data + done, chunk) != (ssize_t)chunk) kr = M_KERN_INVALID_ADDRESS;
        done += chunk;
    }
    close(fds[0]); close(fds[1]);
    if (kr == M_KERN_SUCCESS && out) *out = size;
    return kr;
}
static kern_return_t d_vm_allocate(mach_port_name_t t, uintptr_t *a, uintptr_t s, int f) { uint64_t x = *a; kern_return_t r = vm_alloc(t, &x, s, f); if (!r) *a = (uintptr_t)x; return r; }
static kern_return_t d_vm_deallocate(mach_port_name_t t, uintptr_t a, uintptr_t s) { return vm_dealloc(t, a, s); }
static kern_return_t d_vm_protect(mach_port_name_t t, uintptr_t a, uintptr_t s, int m, int p) { return vm_prot(t, a, s, m, p); }
static kern_return_t d_vm_read_overwrite(mach_port_name_t t, uintptr_t a, uintptr_t s, uintptr_t d, uintptr_t *o) {
    uint64_t n = 0; kern_return_t r = vm_read_over(t, a, s, d, &n); if (!r && o) *o = (uintptr_t)n; return r;
}
static kern_return_t d_mach_vm_allocate(mach_port_name_t t, uint64_t *a, uint64_t s, int f) { return vm_alloc(t, a, s, f); }
static kern_return_t d_mach_vm_deallocate(mach_port_name_t t, uint64_t a, uint64_t s) { return vm_dealloc(t, a, s); }
static kern_return_t d_mach_vm_protect(mach_port_name_t t, uint64_t a, uint64_t s, int m, int p) { return vm_prot(t, a, s, m, p); }
static kern_return_t d_mach_vm_read_overwrite(mach_port_name_t t, uint64_t a, uint64_t s, uint64_t d, uint64_t *o) { return vm_read_over(t, a, s, d, o); }

/* ---------------- ports and semaphores (names of this process) ---------------- */
struct mmsg { struct mmsg *next; uint32_t size, bits, reply, reply_type, dest_type; uint8_t data[]; };
enum { K_PORT, K_SEM };
struct mport {
    mach_port_name_t name; int kind;
    int receive, dead;                  /* a receive right; dead: a dead name (its receive right was destroyed) */
    int srefs, sorefs;                  /* send / send-once rights (urefs) */
    uint32_t qlimit, count; struct mmsg *head, *tail;
    int waiters;                        /* threads blocked on cv: the port is freed by the last one to leave */
    int value, destroyed;               /* semaphores */
    int notify_fd;                      /* eventfd + 1 (0: none) signalled on each queued message and on death (dispatch) */
    pthread_cond_t cv;
    struct mport *next;
};
static pthread_mutex_t mport_lock = PTHREAD_MUTEX_INITIALIZER;
static struct mport *mports[256];
static mach_port_name_t next_port_name = 0x1003;

static struct mport *mport_find(mach_port_name_t name) {
    for (struct mport *p = mports[(name >> 8) & 255]; p; p = p->next) if (p->name == name) return p;
    return NULL;
}
static struct mport *mport_new(int kind) {
    struct mport *p = calloc(1, sizeof *p);
    p->kind = kind; p->name = next_port_name; next_port_name += 0x100; p->qlimit = 5;   /* MACH_PORT_QLIMIT_DEFAULT */
    pthread_condattr_t a; pthread_condattr_init(&a); pthread_condattr_setclock(&a, CLOCK_MONOTONIC);
    pthread_cond_init(&p->cv, &a); pthread_condattr_destroy(&a);
    struct mport **b = &mports[(p->name >> 8) & 255];
    p->next = *b; *b = p;
    return p;
}
static void mport_notify(struct mport *p) { if (p->notify_fd) { uint64_t one = 1; (void)!write(p->notify_fd - 1, &one, sizeof one); } }
static void mport_free(struct mport *p) {
    if (p->notify_fd) close(p->notify_fd - 1);
    struct mport **b = &mports[(p->name >> 8) & 255];
    while (*b && *b != p) b = &(*b)->next;
    if (*b) *b = p->next;
    pthread_cond_destroy(&p->cv);
    free(p);
}
static void mport_drop_if_unused(struct mport *p) { if (p->kind == K_PORT && !p->receive && !p->srefs && !p->sorefs && !p->waiters) mport_free(p); }
static void mport_destroy_receive(struct mport *p) {         /* queued messages go; send rights become dead names */
    p->receive = 0; p->dead = 1;
    for (struct mmsg *m = p->head, *n; m; m = n) { n = m->next; free(m); }
    p->head = p->tail = NULL; p->count = 0;
    pthread_cond_broadcast(&p->cv);
    mport_notify(p);
    mport_drop_if_unused(p);
}
static int special_name(mach_port_name_t n) {
    return n == TASK_PORT || n == HOST_PORT || n == SYSTEM_CLOCK_PORT || n == CALENDAR_CLOCK_PORT || (n & THREAD_PORT);
}
static struct timespec deadline_ms(uint32_t ms) {
    struct timespec ts; clock_gettime(CLOCK_MONOTONIC, &ts);
    ts.tv_sec += ms / 1000; ts.tv_nsec += (long)(ms % 1000) * 1000000;
    if (ts.tv_nsec >= 1000000000) { ts.tv_sec++; ts.tv_nsec -= 1000000000; }
    return ts;
}

static kern_return_t d_mach_port_allocate(mach_port_name_t task, natural_t right, mach_port_name_t *name) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (right != 1 && right != 4) return M_KERN_INVALID_VALUE;     /* RECEIVE, DEAD_NAME (port sets: unsupported) */
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_new(K_PORT);
    if (right == 1) p->receive = 1; else { p->dead = 1; p->srefs = 1; }
    *name = p->name;
    pthread_mutex_unlock(&mport_lock);
    return M_KERN_SUCCESS;
}
static mach_port_name_t d_mach_reply_port(void) { mach_port_name_t n = 0; d_mach_port_allocate(TASK_PORT, 1, &n); return n; }
struct m_port_options { uint32_t flags; uint32_t qlimit; uint64_t reserved[2]; };
static kern_return_t d_mach_port_construct(mach_port_name_t task, struct m_port_options *o, uint64_t context, mach_port_name_t *name) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_new(K_PORT);
    p->receive = 1;
    if (o && (o->flags & 0x10)) p->srefs = 1;                       /* MPO_INSERT_SEND_RIGHT */
    if (o && (o->flags & 0x02)) p->qlimit = o->qlimit < 1 ? 1 : o->qlimit > 1024 ? 1024 : o->qlimit;   /* MPO_QLIMIT */
    *name = p->name;
    pthread_mutex_unlock(&mport_lock);
    return M_KERN_SUCCESS;
}
static kern_return_t d_mach_port_destruct(mach_port_name_t task, mach_port_name_t name, int srdelta, uint64_t guard) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (!p->receive) r = M_KERN_INVALID_RIGHT;
    else if (p->srefs + srdelta < 0) r = M_KERN_INVALID_VALUE;
    else { p->srefs += srdelta; mport_destroy_receive(p); }
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_insert_right(mach_port_name_t task, mach_port_name_t name, mach_port_name_t poly, natural_t type) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (name != poly) return M_KERN_INVALID_VALUE;                 /* a right under another name: unsupported */
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (type == 20) { if (p->receive) p->srefs++; else r = M_KERN_INVALID_RIGHT; }           /* MAKE_SEND */
    else if (type == 21) { if (p->receive) p->sorefs++; else r = M_KERN_INVALID_RIGHT; }          /* MAKE_SEND_ONCE */
    else if (type == 19) { if (p->srefs && !p->dead) p->srefs++; else r = M_KERN_INVALID_RIGHT; }  /* COPY_SEND */
    else if (type < 16 || type > 18) r = M_KERN_INVALID_VALUE;                                       /* MOVE_*: same name */
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_deallocate(mach_port_name_t task, mach_port_name_t name) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (special_name(name) || name == 0 || name == ~0u) return M_KERN_SUCCESS;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (p->srefs) { p->srefs--; mport_drop_if_unused(p); }
    else if (p->sorefs) { p->sorefs--; mport_drop_if_unused(p); }
    else r = M_KERN_INVALID_RIGHT;
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_destroy(mach_port_name_t task, mach_port_name_t name) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else { p->srefs = p->sorefs = 0; if (p->receive) mport_destroy_receive(p); else mport_drop_if_unused(p); }
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_mod_refs(mach_port_name_t task, mach_port_name_t name, natural_t right, int delta) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (special_name(name)) return M_KERN_SUCCESS;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (right == 1) {                                          /* RECEIVE: 0 or -1 */
        if (!p->receive) r = M_KERN_INVALID_RIGHT;
        else if (delta < -1 || delta > 0) r = M_KERN_INVALID_VALUE;
        else if (delta == -1) mport_destroy_receive(p);
    } else if (right == 0 || right == 4) {                          /* SEND, DEAD_NAME */
        if ((right == 4) != (p->dead != 0) || (!p->srefs && delta < 0)) r = M_KERN_INVALID_RIGHT;
        else if (p->srefs + delta < 0) r = M_KERN_INVALID_VALUE;
        else { p->srefs += delta; mport_drop_if_unused(p); }
    } else if (right == 2) {                                        /* SEND_ONCE */
        if (p->sorefs + delta < 0) r = M_KERN_INVALID_VALUE;
        else { p->sorefs += delta; mport_drop_if_unused(p); }
    } else r = M_KERN_INVALID_VALUE;
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_get_refs(mach_port_name_t task, mach_port_name_t name, natural_t right, natural_t *refs) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else *refs = right == 1 ? (natural_t)p->receive : right == 0 ? (p->dead ? 0 : (natural_t)p->srefs) :
                 right == 2 ? (natural_t)p->sorefs : right == 4 ? (p->dead ? (natural_t)p->srefs : 0) : 0;
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_type(mach_port_name_t task, mach_port_name_t name, natural_t *type) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (special_name(name)) { *type = 1u << 16; return M_KERN_SUCCESS; }   /* a send right */
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else *type = p->dead ? 1u << 20 : (p->receive ? 1u << 17 : 0) | (p->srefs ? 1u << 16 : 0) | (p->sorefs ? 1u << 18 : 0);
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_port_set_attributes(mach_port_name_t task, mach_port_name_t name, int flavor, integer_t *info, natural_t count) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (flavor != 1 || count < 1) return M_KERN_INVALID_ARGUMENT;      /* MACH_PORT_LIMITS_INFO */
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (!p->receive) r = M_KERN_INVALID_RIGHT;
    else { p->qlimit = info[0] < 1 ? 1 : info[0] > 1024 ? 1024 : (uint32_t)info[0]; pthread_cond_broadcast(&p->cv); }
    pthread_mutex_unlock(&mport_lock);
    return r;
}

static kern_return_t d_mach_port_get_attributes(mach_port_name_t task, mach_port_name_t name, int flavor, integer_t *info, natural_t *count) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (!info || !count) return M_KERN_INVALID_ARGUMENT;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT) r = M_KERN_INVALID_NAME;
    else if (!p->receive) r = M_KERN_INVALID_RIGHT;
    else if (flavor == 1) {                                          /* MACH_PORT_LIMITS_INFO */
        if (*count < 1) r = M_KERN_FAILURE; else { info[0] = (integer_t)p->qlimit; *count = 1; }
    } else if (flavor == 2) {                                        /* MACH_PORT_RECEIVE_STATUS (mach_port_status_t) */
        if (*count < 10) r = M_KERN_FAILURE;
        else {
            memset(info, 0, 10 * sizeof *info);
            info[3] = (integer_t)p->qlimit; info[4] = (integer_t)p->count;           /* mps_qlimit, mps_msgcount */
            info[5] = p->sorefs; info[6] = p->srefs > 0;                            /* mps_sorights, mps_srights */
            *count = 10;
        }
    } else r = M_KERN_INVALID_ARGUMENT;
    pthread_mutex_unlock(&mport_lock);
    return r;
}
/* isim (private, for Dispatch's Mach sources): a descriptor that becomes readable (eventfd counter) when a message is
   queued on the port or its receive right dies; the caller owns (closes) it. -1 for an unknown name. */
static int d_isim_mach_port_notify_fd(mach_port_name_t name) {
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    int fd = -1;
    if (p && p->kind == K_PORT) {
        if (!p->notify_fd) { int e = eventfd(0, EFD_NONBLOCK | EFD_CLOEXEC); if (e >= 0) p->notify_fd = e + 1; }
        if (p->notify_fd) fd = fcntl(p->notify_fd - 1, F_DUPFD_CLOEXEC, 0);
        if (fd >= 0 && (p->count || p->dead)) mport_notify(p);       /* already pending */
    }
    pthread_mutex_unlock(&mport_lock);
    if (fd < 0) errno = 22;                                          /* EINVAL */
    return fd;
}

/* mach_msg: simple messages between ports of this process */
struct m_header { uint32_t bits, size, remote, local, voucher; int32_t id; };
static int right_type(uint32_t disp) {                 /* what the receiver gets for a disposition (0: invalid) */
    return disp == 17 || disp == 19 || disp == 20 ? 17 : disp == 18 || disp == 21 ? 18 : 0;
}
static int take_right(struct mport *p, uint32_t disp) {   /* the sender's right for a disposition; consumes MOVE_* */
    switch (disp) {
    case 20: case 21: return p->receive;                                   /* MAKE_SEND(_ONCE) */
    case 19: return p->srefs > 0 || p->receive;                            /* COPY_SEND */
    case 17: if (p->srefs > 0) { p->srefs--; return 1; } return 0;          /* MOVE_SEND */
    case 18: if (p->sorefs > 0) { p->sorefs--; return 1; } return 0;        /* MOVE_SEND_ONCE */
    default: return 0;
    }
}
static kern_return_t msg_send(struct m_header *h, uint32_t size, int options, uint32_t timeout) {
    if (size < sizeof *h || (size & 3)) return M_SEND_MSG_TOO_SMALL;
    if (h->bits & 0x80000000u) return M_SEND_INVALID_TYPE;          /* complex messages (descriptors): unsupported */
    uint32_t rdisp = h->bits & 0x1f, ldisp = (h->bits >> 8) & 0x1f;
    if (!right_type(rdisp) || (ldisp && !right_type(ldisp))) return M_SEND_INVALID_HEADER;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(h->remote);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT || !p->receive) r = M_SEND_INVALID_DEST;
    struct mport *reply = NULL;
    if (!r && ldisp && h->local) {
        reply = mport_find(h->local);
        if (!reply || reply->kind != K_PORT || reply->dead) r = M_SEND_INVALID_REPLY;
    }
    struct timespec dl = deadline_ms(timeout);
    while (!r && p->count >= p->qlimit) {                          /* a full queue blocks the sender */
        int timed_out = 0;
        p->waiters++;
        if (options & 0x10) timed_out = !timeout || pthread_cond_timedwait(&p->cv, &mport_lock, &dl) == ETIMEDOUT;   /* MACH_SEND_TIMEOUT */
        else pthread_cond_wait(&p->cv, &mport_lock);
        p->waiters--;
        if (!p->receive) { r = M_SEND_INVALID_DEST; mport_drop_if_unused(p); }
        else if (timed_out && p->count >= p->qlimit) r = M_SEND_TIMED_OUT;
    }
    if (!r && !take_right(p, rdisp)) r = M_SEND_INVALID_DEST;
    if (!r && reply && !take_right(reply, ldisp)) { r = M_SEND_INVALID_REPLY; if (rdisp == 17) p->srefs++; else if (rdisp == 18) p->sorefs++; }
    if (!r) {
        struct mmsg *m = malloc(sizeof *m + size);
        m->next = NULL; m->size = size; m->bits = h->bits;
        m->reply = reply ? h->local : 0; m->reply_type = reply ? right_type(ldisp) : 0; m->dest_type = right_type(rdisp);
        memcpy(m->data, h, size);
        if (p->tail) p->tail->next = m; else p->head = m;
        p->tail = m; p->count++;
        mach_msgs_sent++;
        pthread_cond_broadcast(&p->cv);
        mport_notify(p);
    }
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t msg_receive(struct m_header *h, uint32_t cap, mach_port_name_t name, int options, uint32_t timeout) {
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_find(name);
    kern_return_t r = M_KERN_SUCCESS;
    if (!p || p->kind != K_PORT || !p->receive) r = M_RCV_INVALID_NAME;
    struct timespec dl = deadline_ms(timeout);
    while (!r && !p->head) {
        int timed_out = 0;
        p->waiters++;
        if (options & 0x100) timed_out = !timeout || pthread_cond_timedwait(&p->cv, &mport_lock, &dl) == ETIMEDOUT;  /* MACH_RCV_TIMEOUT */
        else pthread_cond_wait(&p->cv, &mport_lock);
        p->waiters--;
        if (!p->receive) { r = M_RCV_PORT_DIED; mport_drop_if_unused(p); }
        else if (timed_out && !p->head) r = M_RCV_TIMED_OUT;
    }
    if (!r) {
        struct mmsg *m = p->head;
        uint32_t need = m->size + 8;                               /* + the minimum trailer */
        if (cap < need) {
            r = M_RCV_TOO_LARGE;
            if (options & 0x4) h->size = m->size;                   /* MACH_RCV_LARGE: stays queued, its size returned */
            else { p->head = m->next; if (!p->head) p->tail = NULL; p->count--; free(m); pthread_cond_broadcast(&p->cv); }
        } else {
            p->head = m->next; if (!p->head) p->tail = NULL; p->count--;
            memcpy(h, m->data, m->size);
            h->bits = m->reply_type | (m->dest_type << 8) | (m->bits & ~0x801f1f1fu);
            h->remote = m->reply; h->local = name; h->voucher = 0; h->size = m->size;
            uint32_t trailer[2] = { 0, 8 };                          /* MACH_MSG_TRAILER_FORMAT_0, minimum size */
            memcpy((uint8_t *)h + m->size, trailer, sizeof trailer);
            struct mport *reply = m->reply ? mport_find(m->reply) : NULL;
            if (reply && m->reply_type == 17) reply->srefs++;
            else if (reply && m->reply_type == 18) reply->sorefs++;
            mach_msgs_received++;
            free(m);
            pthread_cond_broadcast(&p->cv);                          /* room for blocked senders */
        }
    }
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_mach_msg(struct m_header *h, int options, uint32_t send_size, uint32_t rcv_size, mach_port_name_t rcv_name,
                                uint32_t timeout, mach_port_name_t notify) {
    if (options & 1) { kern_return_t r = msg_send(h, send_size, options, timeout); if (r) return r; }   /* MACH_SEND_MSG */
    if (options & 2) return msg_receive(h, rcv_size, rcv_name, options, timeout);                     /* MACH_RCV_MSG */
    return M_KERN_SUCCESS;
}
static kern_return_t d_mach_msg_send(struct m_header *h) { return d_mach_msg(h, 1, h->size, 0, 0, 0, 0); }
static kern_return_t d_mach_msg_receive(struct m_header *h) { return d_mach_msg(h, 2, 0, h->size, h->local, 0, 0); }

/* semaphores */
static kern_return_t d_semaphore_create(mach_port_name_t task, mach_port_name_t *sem, int policy, int value) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    if (value < 0) return M_KERN_INVALID_ARGUMENT;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = mport_new(K_SEM);
    p->value = value;
    *sem = p->name;
    pthread_mutex_unlock(&mport_lock);
    return M_KERN_SUCCESS;
}
static struct mport *sem_find(mach_port_name_t name) { struct mport *p = mport_find(name); return p && p->kind == K_SEM && !p->destroyed ? p : NULL; }
static kern_return_t d_semaphore_destroy(mach_port_name_t task, mach_port_name_t sem) {
    if (!is_task(task)) return M_SEND_INVALID_DEST;
    pthread_mutex_lock(&mport_lock);
    struct mport *p = sem_find(sem);
    if (p) { p->destroyed = 1; pthread_cond_broadcast(&p->cv); if (!p->waiters) mport_free(p); }   /* else the last waiter frees it */
    pthread_mutex_unlock(&mport_lock);
    return p ? M_KERN_SUCCESS : M_KERN_INVALID_ARGUMENT;
}
static kern_return_t sem_signal(mach_port_name_t sem, int all) {
    pthread_mutex_lock(&mport_lock);
    struct mport *p = sem_find(sem);
    if (p) {
        if (all) { if (p->waiters > 0 && p->value < 0) p->value = 0; p->value += p->waiters; pthread_cond_broadcast(&p->cv); }  /* wakes the current waiters */
        else { p->value++; pthread_cond_signal(&p->cv); }
    }
    pthread_mutex_unlock(&mport_lock);
    return p ? M_KERN_SUCCESS : M_KERN_INVALID_ARGUMENT;
}
static kern_return_t d_semaphore_signal(mach_port_name_t sem) { return sem_signal(sem, 0); }
static kern_return_t d_semaphore_signal_all(mach_port_name_t sem) { return sem_signal(sem, 1); }
static kern_return_t sem_wait(mach_port_name_t sem, const struct timespec *deadline) {
    pthread_mutex_lock(&mport_lock);
    struct mport *p = sem_find(sem);
    kern_return_t r = p ? M_KERN_SUCCESS : M_KERN_INVALID_ARGUMENT;
    if (p) {
        p->waiters++;
        while (p->value <= 0 && !p->destroyed && !r)
            if (deadline ? pthread_cond_timedwait(&p->cv, &mport_lock, deadline) == ETIMEDOUT : pthread_cond_wait(&p->cv, &mport_lock) != 0)
                r = M_KERN_OPERATION_TIMED_OUT;
        p->waiters--;
        if (p->destroyed) { r = M_KERN_TERMINATED; if (!p->waiters) mport_free(p); }
        else if (!r) p->value--;
        else if (p->value > 0) { p->value--; r = M_KERN_SUCCESS; }  /* signalled as the wait timed out */
    }
    pthread_mutex_unlock(&mport_lock);
    return r;
}
static kern_return_t d_semaphore_wait(mach_port_name_t sem) { return sem_wait(sem, NULL); }
static kern_return_t d_semaphore_timedwait(mach_port_name_t sem, struct m_timespec wait) {
    struct timespec dl; clock_gettime(CLOCK_MONOTONIC, &dl);
    dl.tv_sec += wait.tv_sec; dl.tv_nsec += wait.tv_nsec;
    while (dl.tv_nsec >= 1000000000) { dl.tv_sec++; dl.tv_nsec -= 1000000000; }
    return sem_wait(sem, &dl);
}

/* ---------------- errors ---------------- */
static const struct { int code; const char *text; } mach_errors[] = {
    { 0, "(os/kern) successful" }, { 1, "(os/kern) invalid address" }, { 2, "(os/kern) protection failure" },
    { 3, "(os/kern) no space available" }, { 4, "(os/kern) invalid argument" }, { 5, "(os/kern) failure" },
    { 6, "(os/kern) resource shortage" }, { 7, "(os/kern) not receiver" }, { 8, "(os/kern) no access" },
    { 9, "(os/kern) memory failure" }, { 10, "(os/kern) memory error" }, { 14, "(os/kern) aborted" },
    { 15, "(os/kern) invalid name" }, { 16, "(os/kern) invalid task" }, { 17, "(os/kern) invalid right" },
    { 18, "(os/kern) invalid value" }, { 19, "(os/kern) urefs overflow" }, { 22, "(os/kern) invalid host" },
    { 37, "(os/kern) terminated" }, { 46, "(os/kern) not supported" }, { 49, "(os/kern) operation timed out" },
    { M_SEND_INVALID_DEST, "(ipc/send) invalid destination port" }, { M_SEND_TIMED_OUT, "(ipc/send) timed out" },
    { M_SEND_MSG_TOO_SMALL, "(ipc/send) message size changed while being copied" },
    { M_SEND_INVALID_REPLY, "(ipc/send) invalid reply port" }, { M_SEND_INVALID_TYPE, "(ipc/send) invalid port type" },
    { M_SEND_INVALID_HEADER, "(ipc/send) invalid header" }, { M_RCV_INVALID_NAME, "(ipc/rcv) invalid name" },
    { M_RCV_TIMED_OUT, "(ipc/rcv) timed out" }, { M_RCV_TOO_LARGE, "(ipc/rcv) message too large" },
    { M_RCV_PORT_DIED, "(ipc/rcv) port died" },
};
static char *d_mach_error_string(int code) {
    for (size_t i = 0; i < sizeof mach_errors / sizeof *mach_errors; i++) if (mach_errors[i].code == code) return (char *)mach_errors[i].text;
    return (char *)"unknown error code";
}
static char *d_mach_error_type(int code) {
    return (char *)((code & 0xfc000000) == 0x10000000 ? (code & 0x4000 ? "(ipc/rcv)" : "(ipc/send)") : "(os/kern)");
}
static void d_mach_error(const char *s, int code) { fprintf(stderr, "%s %s (%x)\n", s, d_mach_error_string(code), code); }

static void mach_init(void) {
    long ps = sysconf(_SC_PAGESIZE); if (ps <= 0) ps = 4096;
    d_vm_page_size = (uintptr_t)ps; d_vm_page_mask = d_vm_page_size - 1;
    while ((1ul << d_vm_page_shift) < d_vm_page_size) d_vm_page_shift++;
    pthread_key_create(&treg_key, treg_remove);
    treg_add();                                                     /* the main thread */
}

#define MACH_SHIMS \
    A("_mach_absolute_time", d_mach_absolute_time), A("_mach_approximate_time", d_mach_absolute_time), \
    A("_mach_continuous_time", d_mach_continuous_time), A("_mach_continuous_approximate_time", d_mach_continuous_time), \
    A("_mach_timebase_info", d_mach_timebase_info), A("_mach_wait_until", d_mach_wait_until), \
    A("_mach_task_self_", &d_mach_task_self_), A("_mach_host_self", d_mach_host_self), A("_mach_thread_self", d_mach_thread_self), \
    A("_vm_page_size", &d_vm_page_size), A("_vm_page_mask", &d_vm_page_mask), A("_vm_page_shift", &d_vm_page_shift), \
    A("_vm_kernel_page_size", &d_vm_page_size), A("_vm_kernel_page_mask", &d_vm_page_mask), A("_vm_kernel_page_shift", &d_vm_page_shift), \
    A("_pthread_mach_thread_np", d_pthread_mach_thread_np), A("_pthread_from_mach_thread_np", d_pthread_from_mach_thread_np), \
    A("_pthread_threadid_np", d_pthread_threadid_np), \
    A("_task_info", d_task_info), A("_task_threads", d_task_threads), A("_thread_info", d_thread_info), \
    S("_thread_policy_set", d_thread_policy_set), S("_thread_policy_get", d_thread_policy_get), \
    A("_host_page_size", d_host_page_size), A("_host_info", d_host_info), A("_host_statistics", d_host_statistics), \
    A("_host_statistics64", d_host_statistics64), A("_host_processor_info", d_host_processor_info), \
    A("_host_get_clock_service", d_host_get_clock_service), A("_clock_get_time", d_clock_get_time), \
    A("_vm_allocate", d_vm_allocate), A("_vm_deallocate", d_vm_deallocate), A("_vm_protect", d_vm_protect), \
    A("_vm_read_overwrite", d_vm_read_overwrite), A("_mach_vm_allocate", d_mach_vm_allocate), \
    A("_mach_vm_deallocate", d_mach_vm_deallocate), A("_mach_vm_protect", d_mach_vm_protect), \
    A("_mach_vm_read_overwrite", d_mach_vm_read_overwrite), \
    A("_mach_port_allocate", d_mach_port_allocate), A("_mach_port_deallocate", d_mach_port_deallocate), \
    A("_mach_port_destroy", d_mach_port_destroy), A("_mach_port_mod_refs", d_mach_port_mod_refs), \
    A("_mach_port_get_refs", d_mach_port_get_refs), A("_mach_port_insert_right", d_mach_port_insert_right), \
    A("_mach_port_type", d_mach_port_type), A("_mach_port_construct", d_mach_port_construct), \
    A("_mach_port_destruct", d_mach_port_destruct), A("_mach_port_set_attributes", d_mach_port_set_attributes), \
    A("_mach_port_get_attributes", d_mach_port_get_attributes), I("_isim_mach_port_notify_fd", d_isim_mach_port_notify_fd), \
    A("_mach_reply_port", d_mach_reply_port), A("_mach_msg", d_mach_msg), A("_mach_msg_send", d_mach_msg_send), \
    A("_mach_msg_receive", d_mach_msg_receive), A("_semaphore_create", d_semaphore_create), \
    A("_semaphore_destroy", d_semaphore_destroy), A("_semaphore_signal", d_semaphore_signal), \
    A("_semaphore_signal_all", d_semaphore_signal_all), A("_semaphore_wait", d_semaphore_wait), \
    A("_semaphore_timedwait", d_semaphore_timedwait), A("_mach_error_string", d_mach_error_string), \
    A("_mach_error_type", d_mach_error_type), A("_mach_error", d_mach_error)
