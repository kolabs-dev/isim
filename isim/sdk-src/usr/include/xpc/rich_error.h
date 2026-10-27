#pragma once
/* isim <xpc/rich_error.h> (self-authored, Apple's API): the errors sessions report. */
#include <xpc/base.h>

__BEGIN_DECLS
#pragma clang assume_nonnull begin
XPC_EXPORT bool xpc_rich_error_can_retry(xpc_rich_error_t error);
XPC_EXPORT char *_Nullable xpc_rich_error_copy_description(xpc_rich_error_t error);
#pragma clang assume_nonnull end
__END_DECLS
