#pragma once
/* isim SDK (self-authored, Apple's layout and values): resource usage and limits. isim translates the limits and
 * reports ru_maxrss in bytes, as Darwin does. */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <sys/types.h>
#include <sys/time.h>
__BEGIN_DECLS
typedef unsigned int id_t;
typedef uint64_t rlim_t;
#define PRIO_PROCESS 0
#define PRIO_PGRP 1
#define PRIO_USER 2
#define PRIO_DARWIN_THREAD 3
#define PRIO_DARWIN_PROCESS 4
#define PRIO_MIN (-20)
#define PRIO_MAX 20
#define PRIO_DARWIN_BG 0x1000
#define PRIO_DARWIN_NONUI 0x1001
#define RUSAGE_SELF 0
#define RUSAGE_CHILDREN (-1)
struct rusage {
    struct timeval ru_utime;
    struct timeval ru_stime;
    long ru_maxrss;
    long ru_ixrss;
    long ru_idrss;
    long ru_isrss;
    long ru_minflt;
    long ru_majflt;
    long ru_nswap;
    long ru_inblock;
    long ru_oublock;
    long ru_msgsnd;
    long ru_msgrcv;
    long ru_nsignals;
    long ru_nvcsw;
    long ru_nivcsw;
};
#define RLIM_INFINITY (((uint64_t)1 << 63) - 1)
#define RLIM_SAVED_MAX RLIM_INFINITY
#define RLIM_SAVED_CUR RLIM_INFINITY
#define RLIMIT_CPU 0
#define RLIMIT_FSIZE 1
#define RLIMIT_DATA 2
#define RLIMIT_STACK 3
#define RLIMIT_CORE 4
#define RLIMIT_AS 5
#define RLIMIT_RSS RLIMIT_AS
#define RLIMIT_MEMLOCK 6
#define RLIMIT_NPROC 7
#define RLIMIT_NOFILE 8
#define RLIM_NLIMITS 9
struct rlimit {
    rlim_t rlim_cur;
    rlim_t rlim_max;
};
int getpriority(int, id_t);
int setpriority(int, id_t, int);
int getrlimit(int, struct rlimit *);
int setrlimit(int, const struct rlimit *);
int getrusage(int, struct rusage *);
__END_DECLS
