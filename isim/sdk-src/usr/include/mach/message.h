#pragma once
/* isim SDK (self-authored): Mach messages (mach_msg). isim delivers messages between ports of the same process. */
#include <mach/port.h>
#include <_isim_cdefs.h>
typedef unsigned int mach_msg_bits_t;
typedef natural_t mach_msg_size_t;
typedef integer_t mach_msg_id_t;
typedef natural_t mach_msg_timeout_t;
typedef integer_t mach_msg_option_t;
typedef kern_return_t mach_msg_return_t;
typedef unsigned int mach_msg_type_name_t;
typedef unsigned int mach_msg_trailer_type_t;
typedef unsigned int mach_msg_trailer_size_t;
typedef unsigned int mach_msg_descriptor_type_t;
typedef natural_t mach_port_seqno_t;
typedef struct {
    mach_msg_bits_t msgh_bits;
    mach_msg_size_t msgh_size;
    mach_port_t msgh_remote_port;
    mach_port_t msgh_local_port;
    mach_port_name_t msgh_voucher_port;
    mach_msg_id_t msgh_id;
} mach_msg_header_t;
typedef struct { mach_msg_size_t msgh_descriptor_count; } mach_msg_body_t;
typedef struct { mach_msg_trailer_type_t msgh_trailer_type; mach_msg_trailer_size_t msgh_trailer_size; } mach_msg_trailer_t;
typedef struct { mach_msg_header_t header; } mach_msg_empty_send_t;
typedef struct { mach_msg_header_t header; mach_msg_trailer_t trailer; } mach_msg_empty_rcv_t;
typedef union { mach_msg_empty_send_t send; mach_msg_empty_rcv_t rcv; } mach_msg_empty_t;
#define MACH_MSG_TRAILER_FORMAT_0 0
#define MACH_MSG_TRAILER_MINIMUM_SIZE sizeof(mach_msg_trailer_t)
#define MACH_MSGH_BITS_ZERO 0x00000000
#define MACH_MSGH_BITS_REMOTE_MASK 0x0000001f
#define MACH_MSGH_BITS_LOCAL_MASK 0x00001f00
#define MACH_MSGH_BITS_VOUCHER_MASK 0x001f0000
#define MACH_MSGH_BITS_PORTS_MASK (MACH_MSGH_BITS_REMOTE_MASK | MACH_MSGH_BITS_LOCAL_MASK | MACH_MSGH_BITS_VOUCHER_MASK)
#define MACH_MSGH_BITS_COMPLEX 0x80000000U
#define MACH_MSGH_BITS(remote, local) ((remote) | ((local) << 8))
#define MACH_MSGH_BITS_SET(remote, local, voucher, other) \
    (MACH_MSGH_BITS(remote, local) | ((voucher) << 16) | ((other) & ~MACH_MSGH_BITS_PORTS_MASK))
#define MACH_MSGH_BITS_REMOTE(bits) ((bits) & MACH_MSGH_BITS_REMOTE_MASK)
#define MACH_MSGH_BITS_LOCAL(bits) (((bits) & MACH_MSGH_BITS_LOCAL_MASK) >> 8)
#define MACH_MSGH_BITS_VOUCHER(bits) (((bits) & MACH_MSGH_BITS_VOUCHER_MASK) >> 16)
#define MACH_MSG_TYPE_MOVE_RECEIVE 16
#define MACH_MSG_TYPE_MOVE_SEND 17
#define MACH_MSG_TYPE_MOVE_SEND_ONCE 18
#define MACH_MSG_TYPE_COPY_SEND 19
#define MACH_MSG_TYPE_MAKE_SEND 20
#define MACH_MSG_TYPE_MAKE_SEND_ONCE 21
#define MACH_MSG_TYPE_COPY_RECEIVE 22
#define MACH_MSG_TYPE_DISPOSE_RECEIVE 24
#define MACH_MSG_TYPE_DISPOSE_SEND 25
#define MACH_MSG_TYPE_DISPOSE_SEND_ONCE 26
#define MACH_MSG_TYPE_PORT_NAME 15
#define MACH_MSG_TYPE_PORT_RECEIVE MACH_MSG_TYPE_MOVE_RECEIVE
#define MACH_MSG_TYPE_PORT_SEND MACH_MSG_TYPE_MOVE_SEND
#define MACH_MSG_TYPE_PORT_SEND_ONCE MACH_MSG_TYPE_MOVE_SEND_ONCE
#define MACH_MSG_OPTION_NONE 0x00000000
#define MACH_SEND_MSG 0x00000001
#define MACH_RCV_MSG 0x00000002
#define MACH_RCV_LARGE 0x00000004
#define MACH_RCV_LARGE_IDENTITY 0x00000008
#define MACH_SEND_TIMEOUT 0x00000010
#define MACH_SEND_OVERRIDE 0x00000020
#define MACH_SEND_INTERRUPT 0x00000040
#define MACH_SEND_NOTIFY 0x00000080
#define MACH_RCV_TIMEOUT 0x00000100
#define MACH_RCV_NOTIFY 0x00000200
#define MACH_RCV_INTERRUPT 0x00000400
#define MACH_RCV_VOUCHER 0x00000800
#define MACH_MSG_TIMEOUT_NONE ((mach_msg_timeout_t)0)
#define MACH_MSG_SUCCESS 0x00000000
#define MACH_MSG_MASK 0x00003e00
#define MACH_SEND_IN_PROGRESS 0x10000001
#define MACH_SEND_INVALID_DATA 0x10000002
#define MACH_SEND_INVALID_DEST 0x10000003
#define MACH_SEND_TIMED_OUT 0x10000004
#define MACH_SEND_INVALID_VOUCHER 0x10000005
#define MACH_SEND_INTERRUPTED 0x10000007
#define MACH_SEND_MSG_TOO_SMALL 0x10000008
#define MACH_SEND_INVALID_REPLY 0x10000009
#define MACH_SEND_INVALID_RIGHT 0x1000000a
#define MACH_SEND_INVALID_NOTIFY 0x1000000b
#define MACH_SEND_INVALID_MEMORY 0x1000000c
#define MACH_SEND_NO_BUFFER 0x1000000d
#define MACH_SEND_TOO_LARGE 0x1000000e
#define MACH_SEND_INVALID_TYPE 0x1000000f
#define MACH_SEND_INVALID_HEADER 0x10000010
#define MACH_SEND_INVALID_TRAILER 0x10000011
#define MACH_RCV_IN_PROGRESS 0x10004001
#define MACH_RCV_INVALID_NAME 0x10004002
#define MACH_RCV_TIMED_OUT 0x10004003
#define MACH_RCV_TOO_LARGE 0x10004004
#define MACH_RCV_INTERRUPTED 0x10004005
#define MACH_RCV_PORT_CHANGED 0x10004006
#define MACH_RCV_INVALID_NOTIFY 0x10004007
#define MACH_RCV_INVALID_DATA 0x10004008
#define MACH_RCV_PORT_DIED 0x10004009
#define MACH_RCV_IN_SET 0x1000400a
#define MACH_RCV_HEADER_ERROR 0x1000400b
#define MACH_RCV_BODY_ERROR 0x1000400c
#define MACH_RCV_INVALID_TYPE 0x1000400d
#define MACH_RCV_SCATTER_SMALL 0x1000400e
#define MACH_RCV_INVALID_TRAILER 0x1000400f
__BEGIN_DECLS
mach_msg_return_t mach_msg(mach_msg_header_t *msg, mach_msg_option_t option, mach_msg_size_t send_size,
                           mach_msg_size_t rcv_size, mach_port_name_t rcv_name, mach_msg_timeout_t timeout,
                           mach_port_name_t notify);
mach_msg_return_t mach_msg_send(mach_msg_header_t *msg);
mach_msg_return_t mach_msg_receive(mach_msg_header_t *msg);
__END_DECLS
