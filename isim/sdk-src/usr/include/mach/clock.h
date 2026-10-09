#pragma once
#include <mach/clock_types.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t clock_get_time(clock_serv_t clock_serv, mach_timespec_t *cur_time);
__END_DECLS
