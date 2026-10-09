#pragma once
/* isim SDK (self-authored): Mach absolute time. Ticks are nanoseconds (timebase 1/1, as on the iOS simulator on x86_64). */
#include <stdint.h>
#include <mach/kern_return.h>
#include <_isim_cdefs.h>
struct mach_timebase_info { uint32_t numer; uint32_t denom; };
typedef struct mach_timebase_info *mach_timebase_info_t;
typedef struct mach_timebase_info mach_timebase_info_data_t;
__BEGIN_DECLS
kern_return_t mach_timebase_info(mach_timebase_info_t info);
kern_return_t mach_wait_until(uint64_t deadline);
uint64_t mach_absolute_time(void);
uint64_t mach_approximate_time(void);
uint64_t mach_continuous_time(void);
uint64_t mach_continuous_approximate_time(void);
__END_DECLS
