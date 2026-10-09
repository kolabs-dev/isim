#pragma once
/* isim SDK (self-authored): thread_info flavors and their structures. */
#include <mach/mach_types.h>
#include <mach/policy.h>
#define THREAD_INFO_MAX 32
typedef integer_t thread_info_data_t[THREAD_INFO_MAX];
#define THREAD_BASIC_INFO 3
struct thread_basic_info {
    time_value_t user_time;
    time_value_t system_time;
    integer_t cpu_usage;          /* scaled to TH_USAGE_SCALE */
    policy_t policy;
    integer_t run_state;
    integer_t flags;
    integer_t suspend_count;
    integer_t sleep_time;
};
typedef struct thread_basic_info thread_basic_info_data_t;
typedef struct thread_basic_info *thread_basic_info_t;
#define THREAD_BASIC_INFO_COUNT ((mach_msg_type_number_t)(sizeof(thread_basic_info_data_t) / sizeof(natural_t)))
#define THREAD_IDENTIFIER_INFO 4
struct thread_identifier_info {
    uint64_t thread_id;           /* pthread_threadid_np's */
    uint64_t thread_handle;       /* the pthread_t */
    uint64_t dispatch_qaddr;
};
typedef struct thread_identifier_info thread_identifier_info_data_t;
typedef struct thread_identifier_info *thread_identifier_info_t;
#define THREAD_IDENTIFIER_INFO_COUNT ((mach_msg_type_number_t)(sizeof(thread_identifier_info_data_t) / sizeof(natural_t)))
#define THREAD_EXTENDED_INFO 5
#define MAXTHREADNAMESIZE 64
struct thread_extended_info {
    uint64_t pth_user_time;       /* nanoseconds */
    uint64_t pth_system_time;
    int32_t pth_cpu_usage;
    int32_t pth_policy;
    int32_t pth_run_state;
    int32_t pth_flags;
    int32_t pth_sleep_time;
    int32_t pth_curpri;
    int32_t pth_priority;
    int32_t pth_maxpriority;
    char pth_name[MAXTHREADNAMESIZE];
};
typedef struct thread_extended_info thread_extended_info_data_t;
typedef struct thread_extended_info *thread_extended_info_t;
#define THREAD_EXTENDED_INFO_COUNT ((mach_msg_type_number_t)(sizeof(thread_extended_info_data_t) / sizeof(natural_t)))
#define TH_USAGE_SCALE 1000
#define TH_STATE_RUNNING 1
#define TH_STATE_STOPPED 2
#define TH_STATE_WAITING 3
#define TH_STATE_UNINTERRUPTIBLE 4
#define TH_STATE_HALTED 5
#define TH_FLAGS_SWAPPED 0x1
#define TH_FLAGS_IDLE 0x2
#define TH_FLAGS_GLOBAL_FORCED_IDLE 0x4
