#pragma once
#include <Availability.h>
#ifndef OBJC_EXTERN
#ifdef __cplusplus
#define OBJC_EXTERN extern "C"
#else
#define OBJC_EXTERN extern
#endif
#endif
#ifndef OBJC_EXPORT
#define OBJC_EXPORT OBJC_EXTERN __attribute__((visibility("default")))
#endif
#define OBJC_IMPORT extern
#define OBJC_VISIBLE __attribute__((visibility("default")))
#define OBJC_AVAILABLE(...)
#define OBJC_OSX_AVAILABLE_OTHERS_UNAVAILABLE(...)
#define OBJC_IOS_UNAVAILABLE
#define OBJC_SWIFT_UNAVAILABLE(...)
#define OBJC_ARC_UNAVAILABLE
#define OBJC_ROOT_CLASS __attribute__((objc_root_class))
#define OBJC_RUNTIME_OBJC_EXCEPTION_THROW_UNAVAILABLE
#define OBJC_INLINE static inline
#define OBJC_ISA_AVAILABILITY
#define OBJC_UNAVAILABLE(...)
#define OBJC_DEPRECATED(...)
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#endif
