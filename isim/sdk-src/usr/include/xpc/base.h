#pragma once
/* isim <xpc/base.h> (self-authored): XPC objects are Objective-C objects (OS_xpc_object), in Objective-C, in Swift's
 * importer (as on Apple: xpc_object_t is `any OS_xpc_object`) and in C (opaque pointers there); xpc_retain /
 * xpc_release manage them outside ARC. */
#include <_isim_cdefs.h>
#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <stdarg.h>
#include <unistd.h>
#include <sys/types.h>
#include <uuid/uuid.h>
#include <dispatch/dispatch.h>

#define XPC_API_VERSION 20200610
#define IPHONE_SIMULATOR_HOST_MIN_VERSION_REQUIRED 999999
#define XPC_EXPORT extern __attribute__((visibility("default")))
#define XPC_NONNULL_ALL
#define XPC_RETURNS_RETAINED
#if defined(__OBJC__) || defined(__swift__)
#import <objc/NSObject.h>
#define XPC_DECL(name) typedef xpc_object_t name##_t     /* as on Apple: every XPC type is an xpc_object_t */
@protocol OS_xpc_object <NSObject> @end
typedef NSObject<OS_xpc_object> *xpc_object_t;
#if __has_feature(objc_arc)
#undef XPC_RETURNS_RETAINED
#define XPC_RETURNS_RETAINED __attribute__((__ns_returns_retained__))
#endif
#else
#define XPC_DECL(name) typedef struct _##name##_s *name##_t
typedef void *xpc_object_t;
#endif

/* shared with Foundation's NSXPCConnection.h (which includes only this header, module _XPCBase) */
typedef const struct _xpc_type_s *xpc_type_t;
typedef unsigned int au_asid_t;
