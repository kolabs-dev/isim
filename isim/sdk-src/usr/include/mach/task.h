#pragma once
/* isim SDK (self-authored): calls on the calling task. */
#include <mach/task_info.h>
#include <mach/semaphore.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t task_info(task_name_t task, task_flavor_t flavor, task_info_t info, mach_msg_type_number_t *count);
kern_return_t task_threads(task_inspect_t task, thread_act_array_t *threads, mach_msg_type_number_t *count);
__END_DECLS
