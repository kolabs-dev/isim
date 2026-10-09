#pragma once
/* isim SDK (self-authored): Mach semaphores. */
#include <mach/clock_types.h>
#include <mach/sync_policy.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t semaphore_create(task_t task, semaphore_t *semaphore, int policy, int value);
kern_return_t semaphore_destroy(task_t task, semaphore_t semaphore);
kern_return_t semaphore_signal(semaphore_t semaphore);
kern_return_t semaphore_signal_all(semaphore_t semaphore);
kern_return_t semaphore_wait(semaphore_t semaphore);
kern_return_t semaphore_timedwait(semaphore_t semaphore, mach_timespec_t wait_time);
__END_DECLS
