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
/* enums and option sets with a fixed underlying type, as Apple's (Swift imports OBJC_ENUM as an enum) */
#if __has_attribute(enum_extensibility)
#define __OBJC_ENUM_ATTR __attribute__((enum_extensibility(open)))
#define __OBJC_OPTIONS_ATTR __attribute__((flag_enum, enum_extensibility(open)))
#else
#define __OBJC_ENUM_ATTR
#define __OBJC_OPTIONS_ATTR
#endif
#define OBJC_ENUM(_type, _name) enum __OBJC_ENUM_ATTR _name : _type _name; enum __OBJC_ENUM_ATTR _name : _type
#define OBJC_OPTIONS(_type, _name) enum __OBJC_OPTIONS_ATTR _name : _type _name; enum __OBJC_OPTIONS_ATTR _name : _type
#define OBJC_RUNTIME_OBJC_EXCEPTION_THROW_UNAVAILABLE
#define OBJC_INLINE static inline
#define OBJC_ISA_AVAILABILITY
#define OBJC_UNAVAILABLE(...)
#define OBJC_DEPRECATED(...)
#ifndef NS_RETURNS_RETAINED
#define NS_RETURNS_RETAINED __attribute__((ns_returns_retained))
#endif
