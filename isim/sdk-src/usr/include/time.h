#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
typedef long time_t;
struct timespec { time_t tv_sec; long tv_nsec; };
struct tm { int tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year, tm_wday, tm_yday, tm_isdst; long tm_gmtoff; char *tm_zone; };
typedef enum { _CLOCK_REALTIME = 0, _CLOCK_MONOTONIC_RAW = 4, _CLOCK_MONOTONIC = 6, _CLOCK_UPTIME_RAW = 8,
               _CLOCK_PROCESS_CPUTIME_ID = 12, _CLOCK_THREAD_CPUTIME_ID = 16 } clockid_t;
#define CLOCK_REALTIME _CLOCK_REALTIME
#define CLOCK_MONOTONIC _CLOCK_MONOTONIC
#define CLOCK_MONOTONIC_RAW _CLOCK_MONOTONIC_RAW
#define CLOCK_UPTIME_RAW _CLOCK_UPTIME_RAW
time_t time(time_t *);
struct tm *localtime_r(const time_t *, struct tm *);
struct tm *gmtime_r(const time_t *, struct tm *);
time_t mktime(struct tm *);
size_t strftime(char *, size_t, const char *, const struct tm *);
int nanosleep(const struct timespec *, struct timespec *);
int clock_gettime(clockid_t, struct timespec *);
uint64_t clock_gettime_nsec_np(clockid_t);
__END_DECLS
