#pragma once
/* isim SDK (self-authored): per-processor information (host_processor_info). */
#include <mach/machine.h>
#define PROCESSOR_BASIC_INFO 1
#define PROCESSOR_CPU_LOAD_INFO 2
struct processor_cpu_load_info { unsigned int cpu_ticks[CPU_STATE_MAX]; };
typedef struct processor_cpu_load_info processor_cpu_load_info_data_t;
typedef struct processor_cpu_load_info *processor_cpu_load_info_t;
#define PROCESSOR_CPU_LOAD_INFO_COUNT ((mach_msg_type_number_t)(sizeof(processor_cpu_load_info_data_t) / sizeof(natural_t)))
