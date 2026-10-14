#pragma once
/* isim SDK (self-authored, Apple's declarations and values): Darwin notifications (notify_post and the
 * notify_register_* clients), implemented in isim's Foundation. Adapted: they are delivered within the app's process
 * (not to other apps or extensions); Mach port registrations are not supported. */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <dispatch/dispatch.h>
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
__END_DECLS
