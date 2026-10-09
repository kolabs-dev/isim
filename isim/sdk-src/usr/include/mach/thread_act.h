#pragma once
/* isim SDK (self-authored): calls on threads of the calling task. */
#include <mach/thread_info.h>
#include <mach/thread_policy.h>
#include <_isim_cdefs.h>
__BEGIN_DECLS
kern_return_t thread_info(thread_inspect_t thread, thread_flavor_t flavor, thread_info_t info, mach_msg_type_number_t *count);
kern_return_t thread_policy_set(thread_act_t thread, thread_policy_flavor_t flavor, thread_policy_t info, mach_msg_type_number_t count);
kern_return_t thread_policy_get(thread_act_t thread, thread_policy_flavor_t flavor, thread_policy_t info,
                                mach_msg_type_number_t *count, boolean_t *get_default);
__END_DECLS
