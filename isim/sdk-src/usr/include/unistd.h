#pragma once
#include <_isim_cdefs.h>
#include <sys/types.h>
__BEGIN_DECLS
ssize_t read(int, void *, size_t);
ssize_t write(int, const void *, size_t);
int close(int);
ssize_t pread(int, void *, size_t, off_t);
ssize_t pwrite(int, const void *, size_t, off_t);
int pipe(int[2]);
int dup(int);
int dup2(int, int);
int fsync(int);
int ftruncate(int, off_t);
off_t lseek(int, off_t, int);
#ifndef SEEK_SET
#define SEEK_SET 0
#define SEEK_CUR 1
#define SEEK_END 2
#endif
#ifndef SEEK_HOLE
#define SEEK_HOLE 3
#define SEEK_DATA 4
#endif
int access(const char *, int);
int unlink(const char *);
int unlinkat(int, const char *, int);
/* confstr names; _CS_DARWIN_USER_TEMP_DIR / _USER_CACHE_DIR / _USER_DIR answer the app's container */
#define _CS_PATH 1
#define _CS_DARWIN_USER_DIR 65536
#define _CS_DARWIN_USER_TEMP_DIR 65537
#define _CS_DARWIN_USER_CACHE_DIR 65538
size_t confstr(int, char *, size_t);
int rmdir(const char *);
int chown(const char *, uid_t, gid_t);
int lchown(const char *, uid_t, gid_t);
ssize_t readlink(const char *, char *, size_t);
int symlink(const char *, const char *);
int link(const char *, const char *);
char *getcwd(char *, size_t);
int chdir(const char *);
pid_t getpid(void);
uid_t getuid(void);
int isatty(int);
int getpagesize(void);
unsigned int sleep(unsigned int);
int usleep(unsigned int);
int gethostname(char *, size_t);
pid_t getppid(void);
pid_t getpgrp(void);
pid_t getpgid(pid_t);
int setpgid(pid_t, pid_t);
pid_t setsid(void);
pid_t getsid(pid_t);
uid_t geteuid(void);
gid_t getgid(void);
gid_t getegid(void);
int getgroups(int, gid_t[]);
int setuid(uid_t);
int setgid(gid_t);
int seteuid(uid_t);
int setegid(gid_t);
int issetugid(void);
char *getlogin(void);
int getlogin_r(char *, size_t);
char *ttyname(int);
int ttyname_r(int, char *, size_t);
pid_t tcgetpgrp(int);
int tcsetpgrp(int, pid_t);
/* adapted: the iOS sandbox lets an app start no processes; these fail with EPERM */
pid_t fork(void);
pid_t vfork(void);
int execv(const char *, char *const[]);
int execve(const char *, char *const[], char *const[]);
int execvp(const char *, char *const[]);
int execl(const char *, const char *, ...);
int execlp(const char *, const char *, ...);
unsigned int alarm(unsigned int);
int pause(void);
int fchdir(int);
int fchown(int, uid_t, gid_t);
int truncate(const char *, off_t);
int fdatasync(int);
void sync(void);
int lockf(int, int, off_t);
int nice(int);
int getdtablesize(void);
int mkstemp(char *);
int mkstemps(char *, int);
char *mkdtemp(char *);
char *mktemp(char *);
int getentropy(void *, size_t);
void swab(const void *, void *, ssize_t);
long sysconf(int);
long pathconf(const char *, int);
long fpathconf(int, int);
int getopt(int, char *const[], const char *);
extern char *optarg;
extern int optind, opterr, optopt, optreset;
#define F_ULOCK 0
#define F_LOCK 1
#define F_TLOCK 2
#define F_TEST 3
#define _PC_LINK_MAX 1
#define _PC_MAX_CANON 2
#define _PC_MAX_INPUT 3
#define _PC_NAME_MAX 4
#define _PC_PATH_MAX 5
#define _PC_PIPE_BUF 6
#define _PC_CHOWN_RESTRICTED 7
#define _PC_NO_TRUNC 8
#define _PC_VDISABLE 9
#define _SC_ARG_MAX 1
#define _SC_CHILD_MAX 2
#define _SC_CLK_TCK 3
#define _SC_NGROUPS_MAX 4
#define _SC_OPEN_MAX 5
#define _SC_JOB_CONTROL 6
#define _SC_SAVED_IDS 7
#define _SC_VERSION 8
#define _SC_BC_BASE_MAX 9
#define _SC_BC_DIM_MAX 10
#define _SC_BC_SCALE_MAX 11
#define _SC_BC_STRING_MAX 12
#define _SC_COLL_WEIGHTS_MAX 13
#define _SC_EXPR_NEST_MAX 14
#define _SC_LINE_MAX 15
#define _SC_RE_DUP_MAX 16
#define _SC_2_VERSION 17
#define _SC_STREAM_MAX 26
#define _SC_TZNAME_MAX 27
#define _SC_PAGESIZE 29
#define _SC_PAGE_SIZE _SC_PAGESIZE
#define _SC_FSYNC 38
#define _SC_TIMERS 41
#define _SC_SEM_VALUE_MAX 50
#define _SC_IOV_MAX 56
#define _SC_NPROCESSORS_CONF 57
#define _SC_NPROCESSORS_ONLN 58
#define _SC_GETGR_R_SIZE_MAX 70
#define _SC_GETPW_R_SIZE_MAX 71
#define _SC_HOST_NAME_MAX 72
#define _SC_LOGIN_NAME_MAX 73
#define _SC_MONOTONIC_CLOCK 74
#define _SC_THREAD_DESTRUCTOR_ITERATIONS 85
#define _SC_THREAD_KEYS_MAX 86
#define _SC_THREAD_STACK_MIN 93
#define _SC_THREAD_THREADS_MAX 94
#define _SC_THREADS 96
#define _SC_TTY_NAME_MAX 101
#define _SC_PHYS_PAGES 200
#define STDIN_FILENO 0
#define STDOUT_FILENO 1
#define STDERR_FILENO 2
#define R_OK 4
#define W_OK 2
#define X_OK 1
#define F_OK 0
__END_DECLS
