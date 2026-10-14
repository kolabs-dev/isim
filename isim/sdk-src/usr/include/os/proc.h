#pragma once
/* isim SDK (self-authored): the memory the app may still use before the system would end it (adapted: isim's
 * simulated device limit minus the app's resident size). */
#include <_isim_cdefs.h>
#include <stddef.h>
__BEGIN_DECLS
size_t os_proc_available_memory(void);
__END_DECLS
