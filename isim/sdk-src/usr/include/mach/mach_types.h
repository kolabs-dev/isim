#pragma once
/* isim SDK (self-authored): Mach types, as on iOS (x86_64 simulator). */
#include <stdint.h>
#include <mach/kern_return.h>
#include <mach/boolean.h>
typedef unsigned int natural_t;
typedef int integer_t;
typedef natural_t mach_port_name_t;
typedef unsigned int mach_port_t;
typedef mach_port_name_t *mach_port_name_array_t;
typedef mach_port_t *mach_port_array_t;
typedef mach_port_t task_t, task_name_t, task_inspect_t, task_read_t, thread_t, thread_act_t, thread_inspect_t,
                    thread_read_t, host_t, host_priv_t, host_name_t, ipc_space_t, vm_map_t, vm_map_read_t, semaphore_t,
                    clock_serv_t, clock_ctrl_t, processor_t, processor_set_t, processor_set_name_t, ledger_t;
typedef thread_act_t *thread_act_array_t;
typedef thread_t *thread_array_t;
typedef natural_t mach_msg_type_number_t;
typedef natural_t mach_port_right_t;
typedef natural_t mach_port_type_t;
typedef natural_t mach_port_urefs_t;
typedef integer_t mach_port_delta_t;
typedef uint64_t mach_port_context_t;
typedef uintptr_t vm_offset_t, vm_address_t, vm_size_t;
typedef uint64_t mach_vm_address_t, mach_vm_offset_t, mach_vm_size_t;
typedef int vm_prot_t;
typedef int policy_t;
typedef natural_t task_flavor_t, thread_flavor_t, thread_policy_flavor_t;
typedef integer_t host_flavor_t;
typedef int processor_flavor_t;
typedef integer_t *task_info_t, *thread_info_t, *host_info_t, *host_info64_t, *processor_info_t, *thread_policy_t;
typedef integer_t *processor_info_array_t;
typedef int cpu_type_t, cpu_subtype_t, cpu_threadtype_t;
typedef int clock_id_t, clock_res_t, alarm_type_t, sleep_type_t;
typedef int sync_policy_t;
struct time_value { integer_t seconds; integer_t microseconds; };
typedef struct time_value time_value_t;
#define MACH_PORT_NULL 0
#define MACH_PORT_DEAD ((mach_port_name_t)~0)
#define MACH_PORT_VALID(name) ((name) != MACH_PORT_NULL && (name) != MACH_PORT_DEAD)
#define TASK_NULL ((task_t)0)
#define THREAD_NULL ((thread_t)0)
#define SEMAPHORE_NULL ((semaphore_t)0)
