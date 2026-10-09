#pragma once
/* isim SDK (self-authored): Mach port rights. */
#include <mach/mach_types.h>
#define MACH_PORT_RIGHT_SEND ((mach_port_right_t)0)
#define MACH_PORT_RIGHT_RECEIVE ((mach_port_right_t)1)
#define MACH_PORT_RIGHT_SEND_ONCE ((mach_port_right_t)2)
#define MACH_PORT_RIGHT_PORT_SET ((mach_port_right_t)3)
#define MACH_PORT_RIGHT_DEAD_NAME ((mach_port_right_t)4)
#define MACH_PORT_RIGHT_NUMBER ((mach_port_right_t)6)
#define MACH_PORT_TYPE(right) ((mach_port_type_t)(1u << ((right) + 16)))
#define MACH_PORT_TYPE_NONE ((mach_port_type_t)0)
#define MACH_PORT_TYPE_SEND MACH_PORT_TYPE(MACH_PORT_RIGHT_SEND)
#define MACH_PORT_TYPE_RECEIVE MACH_PORT_TYPE(MACH_PORT_RIGHT_RECEIVE)
#define MACH_PORT_TYPE_SEND_ONCE MACH_PORT_TYPE(MACH_PORT_RIGHT_SEND_ONCE)
#define MACH_PORT_TYPE_PORT_SET MACH_PORT_TYPE(MACH_PORT_RIGHT_PORT_SET)
#define MACH_PORT_TYPE_DEAD_NAME MACH_PORT_TYPE(MACH_PORT_RIGHT_DEAD_NAME)
#define MACH_PORT_TYPE_SEND_RECEIVE (MACH_PORT_TYPE_SEND | MACH_PORT_TYPE_RECEIVE)
#define MACH_PORT_QLIMIT_DEFAULT 5
#define MACH_PORT_QLIMIT_MAX 1024
typedef struct mach_port_limits { natural_t mpl_qlimit; } mach_port_limits_t;
typedef struct mach_port_options {
    uint32_t flags;
    mach_port_limits_t mpl;
    union { uint64_t reserved[2]; mach_port_name_t work_interval_port; };
} mach_port_options_t;
typedef mach_port_options_t *mach_port_options_ptr_t;
#define MPO_CONTEXT_AS_GUARD 0x01
#define MPO_QLIMIT 0x02
#define MPO_TEMPOWNER 0x04
#define MPO_IMPORTANCE_RECEIVER 0x08
#define MPO_INSERT_SEND_RIGHT 0x10
#define MPO_STRICT 0x20
#define MPO_DENAP_RECEIVER 0x40
#define MPO_IMMOVABLE_RECEIVE 0x80
#define MPO_FILTER_MSG 0x100
#define MPO_TG_BLOCK_TRACKING 0x200
typedef int mach_port_flavor_t;
typedef integer_t *mach_port_info_t;
#define MACH_PORT_LIMITS_INFO 1
#define MACH_PORT_RECEIVE_STATUS 2
#define MACH_PORT_LIMITS_INFO_COUNT ((mach_msg_type_number_t)(sizeof(mach_port_limits_t) / sizeof(natural_t)))
typedef natural_t mach_port_rights_t;
typedef natural_t mach_port_mscount_t;
typedef natural_t mach_port_msgcount_t;
/* MACH_PORT_RECEIVE_STATUS (mach_port_get_attributes); isim fills mps_qlimit, mps_msgcount, mps_sorights, mps_srights */
typedef struct mach_port_status {
    mach_port_rights_t mps_pset;
    natural_t mps_seqno;
    mach_port_mscount_t mps_mscount;
    mach_port_msgcount_t mps_qlimit;
    mach_port_msgcount_t mps_msgcount;
    mach_port_rights_t mps_sorights;
    boolean_t mps_srights;
    boolean_t mps_pdrequest;
    boolean_t mps_nsrequest;
    natural_t mps_flags;
} mach_port_status_t;
#define MACH_PORT_RECEIVE_STATUS_COUNT ((mach_msg_type_number_t)(sizeof(mach_port_status_t) / sizeof(natural_t)))
