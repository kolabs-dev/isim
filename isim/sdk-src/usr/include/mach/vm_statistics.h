#pragma once
/* isim SDK (self-authored): VM statistics (host_statistics HOST_VM_INFO / host_statistics64 HOST_VM_INFO64). */
#include <mach/mach_types.h>
struct vm_statistics {
    natural_t free_count, active_count, inactive_count, wire_count, zero_fill_count, reactivations, pageins, pageouts,
              faults, cow_faults, lookups, hits, purgeable_count, purges, speculative_count;
};
typedef struct vm_statistics *vm_statistics_t;
typedef struct vm_statistics vm_statistics_data_t;
struct vm_statistics64 {
    natural_t free_count;
    natural_t active_count;
    natural_t inactive_count;
    natural_t wire_count;
    uint64_t zero_fill_count;
    uint64_t reactivations;
    uint64_t pageins;
    uint64_t pageouts;
    uint64_t faults;
    uint64_t cow_faults;
    uint64_t lookups;
    uint64_t hits;
    uint64_t purges;
    natural_t purgeable_count;
    natural_t speculative_count;
    uint64_t decompressions;
    uint64_t compressions;
    uint64_t swapins;
    uint64_t swapouts;
    natural_t compressor_page_count;
    natural_t throttled_count;
    natural_t external_page_count;
    natural_t internal_page_count;
    uint64_t total_uncompressed_pages_in_compressor;
} __attribute__((aligned(8)));
typedef struct vm_statistics64 *vm_statistics64_t;
typedef struct vm_statistics64 vm_statistics64_data_t;
