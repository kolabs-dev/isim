#pragma once
/* isim SDK (self-authored): thread policies (accepted; Linux scheduling is not changed). */
#include <mach/mach_types.h>
#define THREAD_STANDARD_POLICY 1
#define THREAD_EXTENDED_POLICY 1
#define THREAD_TIME_CONSTRAINT_POLICY 2
#define THREAD_PRECEDENCE_POLICY 3
#define THREAD_AFFINITY_POLICY 4
#define THREAD_BACKGROUND_POLICY 5
#define THREAD_LATENCY_QOS_POLICY 7
#define THREAD_THROUGHPUT_QOS_POLICY 8
struct thread_standard_policy { natural_t no_data; };
typedef struct thread_standard_policy thread_standard_policy_data_t;
struct thread_extended_policy { boolean_t timeshare; };
typedef struct thread_extended_policy thread_extended_policy_data_t;
struct thread_time_constraint_policy { uint32_t period, computation, constraint; boolean_t preemptible; };
typedef struct thread_time_constraint_policy thread_time_constraint_policy_data_t;
struct thread_precedence_policy { integer_t importance; };
typedef struct thread_precedence_policy thread_precedence_policy_data_t;
struct thread_affinity_policy { integer_t affinity_tag; };
typedef struct thread_affinity_policy thread_affinity_policy_data_t;
#define THREAD_EXTENDED_POLICY_COUNT ((mach_msg_type_number_t)(sizeof(thread_extended_policy_data_t) / sizeof(integer_t)))
#define THREAD_TIME_CONSTRAINT_POLICY_COUNT ((mach_msg_type_number_t)(sizeof(thread_time_constraint_policy_data_t) / sizeof(integer_t)))
#define THREAD_PRECEDENCE_POLICY_COUNT ((mach_msg_type_number_t)(sizeof(thread_precedence_policy_data_t) / sizeof(integer_t)))
#define THREAD_AFFINITY_POLICY_COUNT ((mach_msg_type_number_t)(sizeof(thread_affinity_policy_data_t) / sizeof(integer_t)))
