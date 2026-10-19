#pragma once
/* os_object: Apple's OS_OBJECT_USE_OBJC. In Objective-C (not Swift's Clang importer) libdispatch's and os_log's objects
 * are Objective-C objects: a protocol per type, the type an NSObject conforming to it; elsewhere C struct pointers. */
#include <_isim_cdefs.h>
#ifndef OS_OBJECT_USE_OBJC
#if defined(__OBJC__) && !defined(__swift__)
#define OS_OBJECT_USE_OBJC 1
#else
#define OS_OBJECT_USE_OBJC 0
#endif
#endif
#if OS_OBJECT_USE_OBJC
#import <objc/NSObject.h>
#if __has_feature(objc_arc)
#define OS_OBJECT_BRIDGE __bridge
#else
#define OS_OBJECT_BRIDGE
#endif
#define OS_OBJECT_RETURNS_RETAINED __attribute__((__ns_returns_retained__))
#define OS_OBJECT_DECL_PROTOCOL(name, ...) @protocol OS_##name __VA_ARGS__ @end
#define OS_OBJECT_DECL_CLASS(name) OS_OBJECT_DECL_PROTOCOL(name, <NSObject>) typedef NSObject<OS_##name> *name##_t
#define OS_OBJECT_DECL_SUBCLASS(name, super) OS_OBJECT_DECL_PROTOCOL(name, <OS_##super>) typedef NSObject<OS_##name> *name##_t
#define OS_OBJECT_DECL(name) OS_OBJECT_DECL_CLASS(name)
#define OS_OBJECT_GLOBAL_OBJECT(type, object) ((OS_OBJECT_BRIDGE type)&(object))
#else
#define OS_OBJECT_BRIDGE
#define OS_OBJECT_RETURNS_RETAINED
#define OS_OBJECT_DECL(name) typedef struct name##_s *name##_t
#define OS_OBJECT_DECL_CLASS(name) typedef struct name##_s *name##_t
#define OS_OBJECT_DECL_SUBCLASS(name, super) typedef struct name##_s *name##_t
#define OS_OBJECT_GLOBAL_OBJECT(type, object) ((type)&(object))
#endif
__BEGIN_DECLS
void *os_retain(void *object);
void os_release(void *object);
__END_DECLS
