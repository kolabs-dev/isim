#pragma once
/* isim SDK (self-authored): host_info / host_statistics flavors (4-byte packed, as on iOS). */
#include <mach/machine.h>
#include <mach/vm_statistics.h>
#pragma pack(push, 4)
#define HOST_INFO_MAX 1024
typedef integer_t host_info_data_t[HOST_INFO_MAX];
#define HOST_BASIC_INFO 1
#define HOST_SCHED_INFO 3
#define HOST_PRIORITY_INFO 5
struct host_basic_info {
    integer_t max_cpus;
    integer_t avail_cpus;
    natural_t memory_size;        /* min(max_mem, 2 GB) */
    cpu_type_t cpu_type;
    cpu_subtype_t cpu_subtype;
    cpu_threadtype_t cpu_threadtype;
    integer_t physical_cpu;
    integer_t physical_cpu_max;
    integer_t logical_cpu;
    integer_t logical_cpu_max;
    uint64_t max_mem;             /* the simulated device's memory */
};
typedef struct host_basic_info host_basic_info_data_t;
typedef struct host_basic_info *host_basic_info_t;
#define HOST_BASIC_INFO_COUNT ((mach_msg_type_number_t)(sizeof(host_basic_info_data_t) / sizeof(integer_t)))
#define HOST_LOAD_INFO 1
#define HOST_VM_INFO 2
#define HOST_CPU_LOAD_INFO 3
#define HOST_VM_INFO64 4
#define HOST_EXTMOD_INFO64 5
struct host_cpu_load_info { natural_t cpu_ticks[CPU_STATE_MAX]; };
typedef struct host_cpu_load_info host_cpu_load_info_data_t;
typedef struct host_cpu_load_info *host_cpu_load_info_t;
#define HOST_CPU_LOAD_INFO_COUNT ((mach_msg_type_number_t)(sizeof(host_cpu_load_info_data_t) / sizeof(integer_t)))
#define HOST_VM_INFO_COUNT ((mach_msg_type_number_t)(sizeof(vm_statistics_data_t) / sizeof(integer_t)))
#define HOST_VM_INFO64_COUNT ((mach_msg_type_number_t)(sizeof(vm_statistics64_data_t) / sizeof(integer_t)))
#pragma pack(pop)
