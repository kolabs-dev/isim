// The C library and POSIX headers apps and packages compile against (issue #220): one check per header. Prints
// PASS/FAIL per check, then "libc test: N/M passed"; the exit code is the number of failures.
#include <dispatch/dispatch.h>
#include <arpa/inet.h>
#include <errno.h>
#include <stddef.h>
#include <execinfo.h>
#include <fcntl.h>
#include <libkern/OSAtomic.h>
#include <notify.h>
#include <os/activity.h>
#include <os/proc.h>
#include <pwd.h>
#include <regex.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/event.h>
#include <sys/mman.h>
#include <sys/random.h>
#include <sys/resource.h>
#include <sys/stat.h>
#include <sys/sysctl.h>
#include <sys/utsname.h>
#include <sys/xattr.h>
#include <syslog.h>
#include <termios.h>
#include <time.h>
#include <unistd.h>
#include <wchar.h>

static int failures, checks;
#define CHECK(cond) do { checks++; if (cond) printf("PASS  %s\n", #cond); else { failures++; printf("FAIL  %s  (line %d, errno %d)\n", #cond, __LINE__, errno); } } while (0)

static char tmpdir[1024];
static const char *tmp_path(const char *name) {
    static char p[1100];
    snprintf(p, sizeof p, "%s/%s", tmpdir, name);
    return p;
}

static void test_mman(void) {
    size_t n = (size_t)getpagesize();
    char *p = mmap(NULL, n, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANON, -1, 0);
    CHECK(p != MAP_FAILED);
    p[0] = 42;
    CHECK(mprotect(p, n, PROT_READ) == 0 && p[0] == 42);
    CHECK(madvise(p, n, MADV_FREE) == 0 && madvise(p, n, MADV_FREE_REUSABLE) == 0);
    CHECK(munmap(p, n) == 0);
    int fd = open(tmp_path("map"), O_RDWR | O_CREAT | O_TRUNC, 0644);
    CHECK(fd >= 0 && ftruncate(fd, (off_t)n) == 0);
    char *m = mmap(NULL, n, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
    memcpy(m, "mapped", 6);
    CHECK(msync(m, n, MS_SYNC) == 0 && munmap(m, n) == 0);
    char buf[7] = { 0 };
    CHECK(pread(fd, buf, 6, 0) == 6 && !strcmp(buf, "mapped"));
    close(fd);
}

static void test_sysctl_uname(void) {
    char machine[64]; size_t len = sizeof machine;
    CHECK(sysctlbyname("hw.machine", machine, &len, NULL, 0) == 0 && !strcmp(machine, "x86_64"));
    int mib[2] = { CTL_HW, HW_NCPU }, ncpu = 0; len = sizeof ncpu;
    CHECK(sysctl(mib, 2, &ncpu, &len, NULL, 0) == 0 && ncpu > 0);
    int named[4]; size_t nn = 4;
    CHECK(sysctlnametomib("hw.memsize", named, &nn) == 0 && nn == 2 && named[0] == CTL_HW && named[1] == HW_MEMSIZE);
    struct kinfo_proc info; size_t isz = sizeof info;
    int pmib[4] = { CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid() };
    CHECK(sizeof(struct kinfo_proc) == 648 && sysctl(pmib, 4, &info, &isz, NULL, 0) == 0);
    CHECK(info.kp_proc.p_pid == getpid() && !(info.kp_proc.p_flag & P_TRACED));
    len = sizeof machine;
    CHECK(sysctlbyname("no.such.name", machine, &len, NULL, 0) == -1 && errno == ENOENT);
    struct utsname u;
    CHECK(uname(&u) == 0 && !strcmp(u.sysname, "Darwin") && !strcmp(u.machine, "x86_64") && u.nodename[0]);
}

static void test_kqueue(void) {
    int kq = kqueue(), p[2];
    CHECK(kq >= 0 && pipe(p) == 0);
    struct kevent ch[2], ev[4];
    EV_SET(&ch[0], p[0], EVFILT_READ, EV_ADD, 0, 0, (void *)0x1234);
    CHECK(kevent(kq, ch, 1, NULL, 0, NULL) == 0);
    struct timespec zero = { 0, 0 }, second = { 1, 0 };
    CHECK(kevent(kq, NULL, 0, ev, 4, &zero) == 0);                        // nothing to read yet
    CHECK(write(p[1], "abc", 3) == 3);
    int n = kevent(kq, NULL, 0, ev, 4, &second);
    CHECK(n == 1 && ev[0].ident == (uintptr_t)p[0] && ev[0].filter == EVFILT_READ && ev[0].data == 3 && ev[0].udata == (void *)0x1234);
    EV_SET(&ch[0], p[0], EVFILT_READ, EV_DELETE, 0, 0, NULL);
    EV_SET(&ch[1], 7, EVFILT_TIMER, EV_ADD | EV_ONESHOT, 0, 20, NULL);   // 20 ms
    CHECK(kevent(kq, ch, 2, NULL, 0, NULL) == 0);
    n = kevent(kq, NULL, 0, ev, 4, &second);
    CHECK(n == 1 && ev[0].filter == EVFILT_TIMER && ev[0].ident == 7 && ev[0].data >= 1);
    EV_SET(&ch[0], 9, EVFILT_USER, EV_ADD | EV_CLEAR, 0, 0, NULL);
    CHECK(kevent(kq, ch, 1, NULL, 0, NULL) == 0 && kevent(kq, NULL, 0, ev, 4, &zero) == 0);
    EV_SET(&ch[0], 9, EVFILT_USER, 0, NOTE_TRIGGER | NOTE_FFCOPY | 5, 0, NULL);
    n = kevent(kq, ch, 1, ev, 4, &second);
    CHECK(n == 1 && ev[0].filter == EVFILT_USER && ev[0].ident == 9 && ev[0].fflags == 5);
    EV_SET(&ch[0], 1, EVFILT_PROC, EV_ADD | EV_RECEIPT, NOTE_EXIT, 0, NULL);
    n = kevent(kq, ch, 1, ev, 4, &zero);
    CHECK(n == 1 && (ev[0].flags & EV_ERROR) && ev[0].data == EINVAL);
    EV_SET(&ch[0], 12345, EVFILT_READ, EV_DELETE, 0, 0, NULL);
    CHECK(kevent(kq, ch, 1, NULL, 0, NULL) == -1 && errno == ENOENT);
    close(p[0]); close(p[1]); close(kq);
}

static void test_resource(void) {
    struct rusage ru;
    CHECK(getrusage(RUSAGE_SELF, &ru) == 0 && ru.ru_maxrss > 1024 * 1024);   // bytes, as on Darwin
    struct rlimit rl, low;
    CHECK(getrlimit(RLIMIT_NOFILE, &rl) == 0 && rl.rlim_cur > 0 && rl.rlim_cur <= rl.rlim_max);
    low = rl; low.rlim_cur = 64;
    CHECK(setrlimit(RLIMIT_NOFILE, &low) == 0 && getrlimit(RLIMIT_NOFILE, &low) == 0 && low.rlim_cur == 64);
    CHECK(setrlimit(RLIMIT_NOFILE, &rl) == 0);
    CHECK(getrlimit(RLIMIT_CORE, &low) == 0 && getrlimit(99, &low) == -1 && errno == EINVAL);
}

static void test_xattr(void) {
    const char *path = tmp_path("tagged");
    close(open(path, O_RDWR | O_CREAT | O_TRUNC, 0644));
    int r = setxattr(path, "com.example.tag", "blue", 4, 0, 0);
    if (r != 0 && errno == ENOTSUP) { printf("NOTE  the host file system has no user extended attributes\n"); return; }
    CHECK(r == 0);
    char buf[16] = { 0 };
    CHECK(getxattr(path, "com.example.tag", buf, sizeof buf, 0, 0) == 4 && !memcmp(buf, "blue", 4));
    CHECK(getxattr(path, "com.example.tag", NULL, 0, 0, 0) == 4);
    char names[128];
    ssize_t n = listxattr(path, names, sizeof names, 0);
    CHECK(n == (ssize_t)strlen("com.example.tag") + 1 && !strcmp(names, "com.example.tag"));
    CHECK(setxattr(path, "com.example.tag", "red", 3, 0, XATTR_CREATE) == -1 && errno == EEXIST);
    CHECK(removexattr(path, "com.example.tag", 0) == 0);
    CHECK(getxattr(path, "com.example.tag", buf, sizeof buf, 0, 0) == -1 && errno == ENOATTR);
}

static void test_wchar(void) {
    mbstate_t st; memset(&st, 0, sizeof st);
    wchar_t w = 0;
    CHECK(mbrtowc(&w, "\xc3\xa9t\xc3\xa9", 5, &st) == 2 && w == 0xe9);           // UTF-8 "été"
    wchar_t ws[8];
    CHECK(mbstowcs(ws, "\xc3\xa9t\xc3\xa9", 8) == 3 && wcslen(ws) == 3 && ws[1] == L't');
    char back[16];
    CHECK(wcstombs(back, ws, sizeof back) == 5 && !strcmp(back, "\xc3\xa9t\xc3\xa9"));
    wchar_t out[32];
    CHECK(swprintf(out, 32, L"%d-%ls", 42, L"ok") == 5 && !wcscmp(out, L"42-ok"));
    CHECK(wcwidth(L'a') == 1 && wcschr(out, L'-') == out + 2 && wcstol(L"123", NULL, 10) == 123);
    CHECK(sizeof(mbstate_t) == 128 && mbsinit(&st));
}

static void test_regex(void) {
    regex_t re;
    regmatch_t m[3];
    CHECK(regcomp(&re, "^([a-z]+)-([0-9]+)$", REG_EXTENDED) == 0 && re.re_nsub == 2);
    CHECK(regexec(&re, "abc-42", 3, m, 0) == 0 && m[1].rm_so == 0 && m[1].rm_eo == 3 && m[2].rm_so == 4 && m[2].rm_eo == 6);
    CHECK(regexec(&re, "ABC-42", 3, m, 0) == REG_NOMATCH);
    regfree(&re);
    CHECK(regcomp(&re, "hello", REG_ICASE | REG_NOSUB) == 0 && regexec(&re, "Say HELLO", 0, NULL, 0) == 0);
    regfree(&re);
    CHECK(regcomp(&re, "a.c", REG_NOSPEC) == 0 && regexec(&re, "abc", 0, NULL, 0) == REG_NOMATCH && regexec(&re, "xa.c", 0, NULL, 0) == 0);
    regfree(&re);
    int err = regcomp(&re, "(unclosed", REG_EXTENDED);
    char msg[64];
    CHECK(err == REG_EPAREN && regerror(err, &re, msg, sizeof msg) > 1 && strstr(msg, "parentheses"));
    CHECK(sizeof(regmatch_t) == 16);
}

static void test_syslog_pwd(void) {
    openlog("libctest", LOG_PID | LOG_PERROR, LOG_USER);
    syslog(LOG_NOTICE, "hello from syslog %d", 7);
    errno = ENOENT;
    syslog(LOG_ERR, "failed: %m");
    closelog();
    CHECK(setlogmask(LOG_UPTO(LOG_WARNING)) == 0xff && setlogmask(0) == LOG_UPTO(LOG_WARNING));
    struct passwd *pw = getpwuid(getuid());
    CHECK(pw && !strcmp(pw->pw_name, "mobile") && pw->pw_uid == getuid() && pw->pw_dir && getenv("HOME") && !strcmp(pw->pw_dir, getenv("HOME")));
    CHECK(getpwnam("mobile") != NULL && getpwnam("nobody-else") == NULL && !strcmp(getlogin(), "mobile"));
    struct passwd rpw, *res = NULL; char small[4], big[512];
    CHECK(getpwuid_r(getuid(), &rpw, small, sizeof small, &res) == ERANGE && res == NULL);
    CHECK(getpwuid_r(getuid(), &rpw, big, sizeof big, &res) == 0 && res == &rpw && !strcmp(rpw.pw_shell, "/bin/sh"));
}

static void test_termios(void) {
    int p[2];
    struct termios t;
    CHECK(pipe(p) == 0 && tcgetattr(p[0], &t) == -1 && errno == ENOTTY);
    close(p[0]); close(p[1]);
    memset(&t, 0, sizeof t);
    t.c_lflag = ECHO | ICANON; t.c_iflag = ICRNL;
    cfmakeraw(&t);
    CHECK(!(t.c_lflag & (ECHO | ICANON)) && !(t.c_iflag & ICRNL) && (t.c_cflag & CSIZE) == CS8 && t.c_cc[VMIN] == 1);
    CHECK(cfsetspeed(&t, B115200) == 0 && cfgetospeed(&t) == 115200 && cfgetispeed(&t) == B115200);
    CHECK(sizeof(struct termios) == 72 && NCCS == 20);
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
static void test_osatomic(void) {
    volatile int32_t v = 5; volatile int64_t v64 = 1;
    CHECK(OSAtomicAdd32(3, &v) == 8 && OSAtomicIncrement32Barrier(&v) == 9 && OSAtomicDecrement32(&v) == 8);
    CHECK(OSAtomicCompareAndSwap32(8, 20, &v) && v == 20 && !OSAtomicCompareAndSwap32(8, 30, &v));
    CHECK(OSAtomicAdd64(1LL << 40, &v64) == (1LL << 40) + 1);
    volatile uint32_t bits = 0;
    CHECK(OSAtomicOr32Orig(0x10, &bits) == 0 && bits == 0x10 && OSAtomicAnd32(0x0f, &bits) == 0);
    volatile uint8_t bytes[2] = { 0, 0 };
    CHECK(!OSAtomicTestAndSet(0, bytes) && bytes[0] == 0x80 && OSAtomicTestAndSet(0, bytes) && OSAtomicTestAndClear(0, bytes) && bytes[0] == 0);
    OSSpinLock lock = OS_SPINLOCK_INIT;
    OSSpinLockLock(&lock);
    CHECK(!OSSpinLockTry(&lock));
    OSSpinLockUnlock(&lock);
    CHECK(OSSpinLockTry(&lock));
    OSSpinLockUnlock(&lock);
    OSMemoryBarrier();
    struct elem { int value; void *link; } a = { 1, NULL }, b = { 2, NULL };
    OSQueueHead q = OS_ATOMIC_QUEUE_INIT;
    OSAtomicEnqueue(&q, &a, offsetof(struct elem, link));
    OSAtomicEnqueue(&q, &b, offsetof(struct elem, link));
    CHECK(OSAtomicDequeue(&q, offsetof(struct elem, link)) == &b && OSAtomicDequeue(&q, offsetof(struct elem, link)) == &a);
}
#pragma clang diagnostic pop

static void test_activity(void) {
    os_activity_t outer = os_activity_create("outer", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT);
    struct os_activity_scope_state_s state;
    os_activity_scope_enter(outer, &state);
    os_activity_id_t parent = 99;
    os_activity_id_t current = os_activity_get_identifier(OS_ACTIVITY_CURRENT, &parent);
    CHECK(current != 0 && current == os_activity_get_identifier(outer, NULL) && parent == 0);
    os_activity_t inner = os_activity_create("inner", OS_ACTIVITY_CURRENT, OS_ACTIVITY_FLAG_DEFAULT);
    CHECK(os_activity_get_identifier(inner, &parent) != current && parent == current);
    __block os_activity_id_t inside = 0;
    os_activity_apply(inner, ^{ inside = os_activity_get_identifier(OS_ACTIVITY_CURRENT, NULL); });
    CHECK(inside == os_activity_get_identifier(inner, NULL) && os_activity_get_identifier(OS_ACTIVITY_CURRENT, NULL) == current);
    os_activity_scope_leave(&state);
    CHECK(os_activity_get_identifier(OS_ACTIVITY_CURRENT, NULL) == 0 && os_activity_get_identifier(OS_ACTIVITY_NONE, NULL) == 0);
    os_activity_label_useraction("Tap");
    CHECK(os_proc_available_memory() > 100u * 1024 * 1024);
}

static volatile sig_atomic_t usr1, usr2;
static void on_usr1(int sig) { usr1 = sig; }
static void on_usr2(int sig, siginfo_t *info, void *uc) { (void)uc; usr2 = info->si_signo == sig ? sig : -1; }
static int by_thunk(void *thunk, const void *a, const void *b) { return *(int *)thunk * (*(const int *)a - *(const int *)b); }

__attribute__((noinline)) static void test_posix(void) {
    char t[1100];
    snprintf(t, sizeof t, "%s/fileXXXXXX", tmpdir);
    int fd = mkstemp(t);
    CHECK(fd >= 0 && strstr(t, "XXXXXX") == NULL);
    close(fd); unlink(t);
    snprintf(t, sizeof t, "%s/dirXXXXXX", tmpdir);
    struct stat st;
    CHECK(mkdtemp(t) == t && stat(t, &st) == 0 && S_ISDIR(st.st_mode) && rmdir(t) == 0);
    char csv[] = "a,b,,c", *rest = csv, *tok;
    int count = 0; while ((tok = strsep(&rest, ","))) count++;
    CHECK(count == 4);
    struct tm tm; memset(&tm, 0, sizeof tm);
    CHECK(strptime("2024-03-01 13:45", "%Y-%m-%d %H:%M", &tm) && tm.tm_year == 124 && tm.tm_mon == 2 && tm.tm_mday == 1 && tm.tm_hour == 13);
    unsigned char rnd[32] = { 0 }, zero[32] = { 0 };
    CHECK(getentropy(rnd, sizeof rnd) == 0 && memcmp(rnd, zero, 32) != 0 && getentropy(rnd, 257) == -1 && errno == EIO);
    CHECK(sysconf(_SC_PAGESIZE) == 4096 && sysconf(_SC_NPROCESSORS_ONLN) > 0 && sysconf(_SC_OPEN_MAX) > 0 && sysconf(_SC_CLK_TCK) == 100);
    CHECK(sysconf(_SC_PHYS_PAGES) > 0 && sysconf(12345) == -1 && errno == EINVAL && pathconf(".", _PC_NAME_MAX) == 255);
    CHECK(getppid() > 0 && geteuid() == getuid() && getgid() == getegid() && !issetugid());
    CHECK(fork() == -1 && errno == EPERM && setuid(getuid()) == 0 && setuid(getuid() + 1) == -1 && errno == EPERM);
    char *argv[] = { "prog", "-a", "-b", "value", "rest", NULL };
    int a = 0; const char *b = NULL; int c;
    optind = 1;
    while ((c = getopt(5, argv, "ab:")) != -1) { if (c == 'a') a = 1; else if (c == 'b') b = optarg; }
    CHECK(a == 1 && b && !strcmp(b, "value") && optind == 4);
    int nums[] = { 3, 1, 2 }, desc = -1;
    qsort_r(nums, 3, sizeof *nums, &desc, by_thunk);
    CHECK(nums[0] == 3 && nums[2] == 1);
    CHECK(strnstr("hello world", "world", 11) && !strnstr("hello world", "world", 8) && fls(8) == 4 && ffs(8) == 4 && flsl(0) == 0);
    CHECK(memmem("abcdef", 6, "cd", 2) && !strcmp(stpcpy(t, "x"), "") && strcasestr("Hello", "LL"));

    sigset_t set;
    CHECK(sigemptyset(&set) == 0 && sigaddset(&set, SIGUSR2) == 0 && sigismember(&set, SIGUSR2) == 1 && sigismember(&set, SIGUSR1) == 0);
    struct sigaction sa; memset(&sa, 0, sizeof sa);
    sa.sa_handler = on_usr1;
    CHECK(sigaction(SIGUSR1, &sa, NULL) == 0 && raise(SIGUSR1) == 0 && usr1 == SIGUSR1);
    memset(&sa, 0, sizeof sa);
    sa.sa_sigaction = on_usr2; sa.sa_flags = SA_SIGINFO;
    CHECK(sigaction(SIGUSR2, &sa, NULL) == 0);
    sigset_t old, pending;
    CHECK(sigprocmask(SIG_BLOCK, &set, &old) == 0 && raise(SIGUSR2) == 0 && usr2 == 0);
    CHECK(sigpending(&pending) == 0 && sigismember(&pending, SIGUSR2) == 1);
    CHECK(sigprocmask(SIG_SETMASK, &old, NULL) == 0 && usr2 == SIGUSR2);              // delivered when unblocked
    struct sigaction back;
    CHECK(sigaction(SIGUSR2, NULL, &back) == 0 && (back.sa_flags & SA_SIGINFO) && back.sa_sigaction == on_usr2);
    void *frames[16];
    int depth = backtrace(frames, 16);
    char **symbols = backtrace_symbols(frames, depth);
    CHECK(depth >= 2 && symbols && strstr(symbols[0], "LibcTest") && strstr(symbols[0], "test_posix + ") && !strncmp(symbols[0], "0   ", 4));
    CHECK(depth >= 2 && strstr(symbols[1], "main + "));
    free(symbols);
}

static void test_notify(void) {
    int check_token, value_token, fd_token, notify_fd, flag = 0;
    CHECK(notify_register_check("dev.isim.libc.changed", &check_token) == NOTIFY_STATUS_OK);
    CHECK(notify_check(check_token, &flag) == 0 && flag == 1);                     // the first check reports a change
    CHECK(notify_check(check_token, &flag) == 0 && flag == 0);
    dispatch_semaphore_t got = dispatch_semaphore_create(0);
    __block int handled = 0;
    CHECK(notify_register_dispatch("dev.isim.libc.changed", &value_token, dispatch_get_global_queue(0, 0), ^(int token) {
        handled = token; dispatch_semaphore_signal(got);
    }) == NOTIFY_STATUS_OK);
    CHECK(notify_register_file_descriptor("dev.isim.libc.changed", &notify_fd, 0, &fd_token) == NOTIFY_STATUS_OK);
    CHECK(notify_post("dev.isim.libc.changed") == NOTIFY_STATUS_OK);
    CHECK(dispatch_semaphore_wait(got, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC)) == 0 && handled == value_token);
    CHECK(notify_check(check_token, &flag) == 0 && flag == 1);
    int32_t be = 0;
    CHECK(read(notify_fd, &be, 4) == 4 && (int)ntohl((uint32_t)be) == fd_token);
    CHECK(notify_set_state(check_token, 77) == 0);
    uint64_t state = 0;
    CHECK(notify_get_state(value_token, &state) == 0 && state == 77);              // the state belongs to the name
    CHECK(notify_suspend(check_token) == 0 && notify_post("dev.isim.libc.changed") == 0 && notify_check(check_token, &flag) == 0 && flag == 0);
    CHECK(notify_resume(check_token) == 0 && notify_check(check_token, &flag) == 0 && flag == 1);
    CHECK(notify_cancel(value_token) == 0 && !notify_is_valid_token(value_token) && notify_cancel(value_token) == NOTIFY_STATUS_INVALID_TOKEN);
    notify_cancel(check_token); notify_cancel(fd_token);
}

int main(void) {
    snprintf(tmpdir, sizeof tmpdir, "%s", getenv("TMPDIR") ? getenv("TMPDIR") : "/tmp");
    size_t l = strlen(tmpdir); if (l > 1 && tmpdir[l - 1] == '/') tmpdir[l - 1] = 0;
    test_mman();
    test_sysctl_uname();
    test_kqueue();
    test_resource();
    test_xattr();
    test_wchar();
    test_regex();
    test_syslog_pwd();
    test_termios();
    test_osatomic();
    test_activity();
    test_posix();
    test_notify();
    printf("libc test: %d/%d passed\n", checks - failures, checks);
    return failures;
}
