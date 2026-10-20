#pragma once
/* isim SDK (self-authored, Apple's declarations and values): Darwin notifications (notify_post and the
 * notify_register_* clients), implemented in isim's Foundation. Adapted: a post reaches every process of the device
 * (the app, its extensions and other apps; through a log under ISIM_DATA); the state set with notify_set_state stays
 * in its process; Mach port registrations are not supported (NOTIFY_STATUS_FAILED). */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <dispatch/dispatch.h>
#include <mach/mach_types.h>
#include <notify_keys.h>
__BEGIN_DECLS
#define NOTIFY_STATUS_OK 0
#define NOTIFY_STATUS_INVALID_NAME 1
#define NOTIFY_STATUS_INVALID_TOKEN 2
#define NOTIFY_STATUS_INVALID_PORT 3
#define NOTIFY_STATUS_INVALID_FILE 4
#define NOTIFY_STATUS_INVALID_SIGNAL 5
#define NOTIFY_STATUS_INVALID_REQUEST 6
#define NOTIFY_STATUS_NOT_AUTHORIZED 7
#define NOTIFY_STATUS_OPT_DISABLE 8
#define NOTIFY_STATUS_SERVER_NOT_FOUND 9
#define NOTIFY_STATUS_NULL_INPUT 10
#define NOTIFY_STATUS_FAILED 1000000
#define NOTIFY_REUSE 0x00000001
typedef void (^notify_handler_t)(int token);
uint32_t notify_post(const char *name);
uint32_t notify_register_check(const char *name, int *out_token);
uint32_t notify_register_dispatch(const char *name, int *out_token, dispatch_queue_t queue, notify_handler_t handler);
uint32_t notify_register_signal(const char *name, int sig, int *out_token);
uint32_t notify_register_file_descriptor(const char *name, int *notify_fd, int flags, int *out_token);
uint32_t notify_check(int token, int *check);
uint32_t notify_cancel(int token);
uint32_t notify_suspend(int token);
uint32_t notify_resume(int token);
uint32_t notify_set_state(int token, uint64_t state64);
uint32_t notify_get_state(int token, uint64_t *state64);
bool notify_is_valid_token(int val);
uint32_t notify_register_mach_port(const char *name, mach_port_t *notify_port, int flags, int *out_token);
#define NOTIFY_TOKEN_INVALID -1
__END_DECLS
