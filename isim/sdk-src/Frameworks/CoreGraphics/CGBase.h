#pragma once
#include <_isim_cdefs.h>
#include <Availability.h>
#include <TargetConditionals.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFData.h>
typedef double CGFloat;
#define CGFLOAT_IS_DOUBLE 1
#define CGFLOAT_MIN 2.2250738585072014e-308
#define CGFLOAT_MAX 1.7976931348623157e+308
#if defined(__cplusplus)
#define CG_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define CG_EXTERN extern __attribute__((visibility("default")))
#endif
#define CG_INLINE static inline
#ifndef CF_ENUM
#define CF_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
#if defined(__cplusplus)   /* like Apple's: in C++ the options are an integer typedef, so a | b stays that type */
#define CF_OPTIONS(_type, _name) __attribute__((availability(swift, unavailable))) _type _name; enum __attribute__((flag_enum, enum_extensibility(open))) : _name
#else
#define CF_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type
#endif
#endif
#define CG_SWIFT_NAME(n) __attribute__((swift_name(#n)))
#ifndef CF_RETURNS_RETAINED
#define CF_RETURNS_RETAINED __attribute__((cf_returns_retained))
#endif
