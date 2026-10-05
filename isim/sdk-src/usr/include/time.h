#pragma once
#include <_isim_cdefs.h>
#include <stddef.h>
#include <stdint.h>
__BEGIN_DECLS
typedef long time_t;
typedef unsigned long clock_t;
#define CLOCKS_PER_SEC 1000000
#define TIME_UTC 1
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
time_t timegm(struct tm *);
void tzset(void);
size_t strftime(char *, size_t, const char *, const struct tm *);
clock_t clock(void);
double difftime(time_t, time_t);
char *asctime(const struct tm *);
char *ctime(const time_t *);
struct tm *gmtime(const time_t *);
struct tm *localtime(const time_t *);
int timespec_get(struct timespec *, int);
int nanosleep(const struct timespec *, struct timespec *);
int clock_gettime(clockid_t, struct timespec *);
int clock_getres(clockid_t, struct timespec *);
uint64_t clock_gettime_nsec_np(clockid_t);
__END_DECLS
