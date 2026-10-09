#pragma once
/* isim SDK (self-authored): task_info flavors and their structures (4-byte packed, as on iOS). */
#include <mach/mach_types.h>
#include <mach/vm_statistics.h>
#pragma pack(push, 4)
#define TASK_INFO_MAX 1024
typedef integer_t task_info_data_t[TASK_INFO_MAX];
#define MACH_TASK_BASIC_INFO 20
struct mach_task_basic_info {
    mach_vm_size_t virtual_size;
    mach_vm_size_t resident_size;
    mach_vm_size_t resident_size_max;
    time_value_t user_time;      /* terminated threads */
    time_value_t system_time;
    policy_t policy;
    integer_t suspend_count;
};
typedef struct mach_task_basic_info mach_task_basic_info_data_t;
typedef struct mach_task_basic_info *mach_task_basic_info_t;
#define MACH_TASK_BASIC_INFO_COUNT ((mach_msg_type_number_t)(sizeof(mach_task_basic_info_data_t) / sizeof(natural_t)))
#define TASK_BASIC_INFO_64 5
struct task_basic_info_64 {
    integer_t suspend_count;
    mach_vm_size_t virtual_size;
    mach_vm_size_t resident_size;
    time_value_t user_time;
    time_value_t system_time;
    policy_t policy;
};
typedef struct task_basic_info_64 task_basic_info_64_data_t;
typedef struct task_basic_info_64 *task_basic_info_64_t;
#define TASK_BASIC_INFO_64_COUNT ((mach_msg_type_number_t)(sizeof(task_basic_info_64_data_t) / sizeof(natural_t)))
struct task_basic_info {
    integer_t suspend_count;
    vm_size_t virtual_size;
    vm_size_t resident_size;
    time_value_t user_time;
    time_value_t system_time;
    policy_t policy;
};
typedef struct task_basic_info task_basic_info_data_t;
typedef struct task_basic_info *task_basic_info_t;
#define TASK_BASIC_INFO TASK_BASIC_INFO_64
#define TASK_BASIC_INFO_COUNT ((mach_msg_type_number_t)(sizeof(task_basic_info_data_t) / sizeof(natural_t)))
#define TASK_THREAD_TIMES_INFO 3
struct task_thread_times_info {
    time_value_t user_time;      /* live threads */
    time_value_t system_time;
};
typedef struct task_thread_times_info task_thread_times_info_data_t;
typedef struct task_thread_times_info *task_thread_times_info_t;
#define TASK_THREAD_TIMES_INFO_COUNT ((mach_msg_type_number_t)(sizeof(task_thread_times_info_data_t) / sizeof(natural_t)))
#define TASK_EVENTS_INFO 2
struct task_events_info {
    integer_t faults, pageins, cow_faults, messages_sent, messages_received, syscalls_mach, syscalls_unix, csw;
};
typedef struct task_events_info task_events_info_data_t;
typedef struct task_events_info *task_events_info_t;
#define TASK_EVENTS_INFO_COUNT ((mach_msg_type_number_t)(sizeof(task_events_info_data_t) / sizeof(natural_t)))
#define TASK_VM_INFO 22
#define TASK_VM_INFO_PURGEABLE 23
struct task_vm_info {
    mach_vm_size_t virtual_size;
    integer_t region_count;
    integer_t page_size;
    mach_vm_size_t resident_size;
    mach_vm_size_t resident_size_peak;
    mach_vm_size_t device;
    mach_vm_size_t device_peak;
    mach_vm_size_t internal;
    mach_vm_size_t internal_peak;
    mach_vm_size_t external;
    mach_vm_size_t external_peak;
    mach_vm_size_t reusable;
    mach_vm_size_t reusable_peak;
    mach_vm_size_t purgeable_volatile_pmap;
    mach_vm_size_t purgeable_volatile_resident;
    mach_vm_size_t purgeable_volatile_virtual;
    mach_vm_size_t compressed;
    mach_vm_size_t compressed_peak;
    mach_vm_size_t compressed_lifetime;
    /* rev1 */
    mach_vm_size_t phys_footprint;
    /* rev2 */
    mach_vm_address_t min_address;
    mach_vm_address_t max_address;
    /* rev3 */
    int64_t ledger_phys_footprint_peak;
    int64_t ledger_purgeable_nonvolatile;
    int64_t ledger_purgeable_novolatile_compressed;
    int64_t ledger_purgeable_volatile;
    int64_t ledger_purgeable_volatile_compressed;
    int64_t ledger_tag_network_nonvolatile;
    int64_t ledger_tag_network_nonvolatile_compressed;
    int64_t ledger_tag_network_volatile;
    int64_t ledger_tag_network_volatile_compressed;
    int64_t ledger_tag_media_footprint;
    int64_t ledger_tag_media_footprint_compressed;
    int64_t ledger_tag_media_nofootprint;
    int64_t ledger_tag_media_nofootprint_compressed;
    int64_t ledger_tag_graphics_footprint;
    int64_t ledger_tag_graphics_footprint_compressed;
    int64_t ledger_tag_graphics_nofootprint;
    int64_t ledger_tag_graphics_nofootprint_compressed;
    int64_t ledger_tag_neural_footprint;
    int64_t ledger_tag_neural_footprint_compressed;
    int64_t ledger_tag_neural_nofootprint;
    int64_t ledger_tag_neural_nofootprint_compressed;
    /* rev4 */
    uint64_t limit_bytes_remaining;
    /* rev5 */
    integer_t decompressions;
    /* rev6 */
    int64_t ledger_swapins;
    /* rev7 */
    int64_t ledger_tag_neural_nofootprint_total;
    int64_t ledger_tag_neural_nofootprint_peak;
};
typedef struct task_vm_info task_vm_info_data_t;
typedef struct task_vm_info *task_vm_info_t;
#define TASK_VM_INFO_COUNT ((mach_msg_type_number_t)(sizeof(task_vm_info_data_t) / sizeof(natural_t)))
#define TASK_VM_INFO_REV7_COUNT TASK_VM_INFO_COUNT
#define TASK_VM_INFO_REV6_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, ledger_tag_neural_nofootprint_total) / sizeof(natural_t)))
#define TASK_VM_INFO_REV5_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, ledger_swapins) / sizeof(natural_t)))
#define TASK_VM_INFO_REV4_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, decompressions) / sizeof(natural_t)))
#define TASK_VM_INFO_REV3_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, limit_bytes_remaining) / sizeof(natural_t)))
#define TASK_VM_INFO_REV2_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, ledger_phys_footprint_peak) / sizeof(natural_t)))
#define TASK_VM_INFO_REV1_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, min_address) / sizeof(natural_t)))
#define TASK_VM_INFO_REV0_COUNT ((mach_msg_type_number_t)(__builtin_offsetof(task_vm_info_data_t, phys_footprint) / sizeof(natural_t)))
#pragma pack(pop)
