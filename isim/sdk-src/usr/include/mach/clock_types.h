#pragma once
/* isim SDK (self-authored): Mach clocks. */
#include <mach/mach_types.h>
struct mach_timespec { unsigned int tv_sec; clock_res_t tv_nsec; };
typedef struct mach_timespec mach_timespec_t;
#define SYSTEM_CLOCK 0
#define CALENDAR_CLOCK 1
#define REALTIME_CLOCK 0
#define NSEC_PER_USEC 1000ull
#define USEC_PER_SEC 1000000ull
#define NSEC_PER_SEC 1000000000ull
#define NSEC_PER_MSEC 1000000ull
