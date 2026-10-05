#pragma once
#include <_isim_cdefs.h>
__BEGIN_DECLS
struct sched_param { int sched_priority; char __opaque[4]; };   /* Darwin layout */
int sched_yield(void);
__END_DECLS
