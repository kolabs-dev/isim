#pragma once
#ifndef NS_AUTOMATED_REFCOUNT_UNAVAILABLE
#if __has_feature(objc_arc)
#define NS_AUTOMATED_REFCOUNT_UNAVAILABLE __attribute__((unavailable("not available in automatic reference counting mode")))
#else
#define NS_AUTOMATED_REFCOUNT_UNAVAILABLE
#endif
#endif
#include <objc/objc.h>
#include <objc/runtime.h>
#include <stdarg.h>
/* Like Apple's CoreFoundation.h, make the common C library headers available. */
#include <assert.h>
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <Availability.h>
#include <TargetConditionals.h>
#include <CoreGraphics/CGBase.h>
#include <CoreGraphics/CGGeometry.h>

#define FOUNDATION_EXPORT extern __attribute__((visibility("default")))
#define FOUNDATION_EXTERN FOUNDATION_EXPORT
#define NS_INLINE static inline
#define NS_ASSUME_NONNULL_BEGIN _Pragma("clang assume_nonnull begin")
#define NS_ASSUME_NONNULL_END _Pragma("clang assume_nonnull end")
#define NS_DESIGNATED_INITIALIZER __attribute__((objc_designated_initializer))
#define NS_UNAVAILABLE __attribute__((unavailable))
#define NS_REQUIRES_SUPER __attribute__((objc_requires_super))
#define NS_REQUIRES_NIL_TERMINATION __attribute__((sentinel(0, 1)))
#define NS_FORMAT_FUNCTION(F, A) __attribute__((format(__NSString__, F, A)))
#define NS_SWIFT_NAME(_name) __attribute__((swift_name(#_name)))
#define NS_SWIFT_UI_ACTOR
#define NS_REFINED_FOR_SWIFT __attribute__((swift_private))
#define NS_NOESCAPE __attribute__((noescape))
#define NS_RETURNS_INNER_POINTER __attribute__((objc_returns_inner_pointer))
#define NS_ENUM(_type, _name) enum __attribute__((enum_extensibility(open))) _name : _type _name; enum _name : _type
#define NS_OPTIONS(_type, _name) enum __attribute__((flag_enum, enum_extensibility(open))) _name : _type _name; enum _name : _type
#define NS_CLOSED_ENUM(_type, _name) enum __attribute__((enum_extensibility(closed))) _name : _type _name; enum _name : _type
#define NS_TYPED_ENUM __attribute__((swift_wrapper(struct)))
#define NS_TYPED_EXTENSIBLE_ENUM __attribute__((swift_wrapper(struct)))
#define NS_EXTENSIBLE_STRING_ENUM __attribute__((swift_wrapper(struct)))
#define NS_STRING_ENUM __attribute__((swift_wrapper(enum)))
#define NS_ERROR_ENUM(_domain, _name) NS_ENUM(NSInteger, _name)
#define UIKIT_EXTERN FOUNDATION_EXPORT
#define NS_AVAILABLE(...)
#define NS_CLASS_AVAILABLE_IOS(...)
#define NS_ENUM_AVAILABLE_IOS(...)

typedef long NSInteger;
typedef unsigned long NSUInteger;
#define NSIntegerMax __LONG_MAX__
#define NSIntegerMin (-__LONG_MAX__ - 1L)
#define NSUIntegerMax (__LONG_MAX__ * 2UL + 1UL)
static const NSInteger NSNotFound = NSIntegerMax;
typedef double NSTimeInterval NS_SWIFT_NAME(TimeInterval);
typedef struct _NSZone NSZone;

typedef NS_ENUM(NSInteger, NSComparisonResult) { NSOrderedAscending = -1L, NSOrderedSame, NSOrderedDescending };
typedef struct _NSRange { NSUInteger location; NSUInteger length; } NSRange;
typedef NSRange *NSRangePointer;
NS_INLINE NSRange NSMakeRange(NSUInteger loc, NSUInteger len) { NSRange r = { loc, len }; return r; }
NS_INLINE NSUInteger NSMaxRange(NSRange r) { return r.location + r.length; }
NS_INLINE BOOL NSLocationInRange(NSUInteger loc, NSRange r) { return loc - r.location < r.length; }

#ifndef MIN
#define MIN(A, B) ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a < __b ? __a : __b; })
#endif
#ifndef MAX
#define MAX(A, B) ({ __typeof__(A) __a = (A); __typeof__(B) __b = (B); __a > __b ? __a : __b; })
#endif
#ifndef ABS
#define ABS(A) ({ __typeof__(A) __a = (A); __a < 0 ? -__a : __a; })
#endif

#ifdef __OBJC__
NS_ASSUME_NONNULL_BEGIN
@class NSString, Protocol;
typedef id (^NSComparator_t)(id, id);
typedef NSComparisonResult (^NSComparator)(id obj1, id obj2);
__BEGIN_DECLS
FOUNDATION_EXPORT void NSLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
FOUNDATION_EXPORT void NSLogv(NSString *format, va_list args) NS_FORMAT_FUNCTION(1, 0);
FOUNDATION_EXPORT NSString *NSStringFromSelector(SEL aSelector);
FOUNDATION_EXPORT SEL NSSelectorFromString(NSString *aSelectorName);
FOUNDATION_EXPORT NSString *NSStringFromClass(Class aClass);
FOUNDATION_EXPORT Class _Nullable NSClassFromString(NSString *aClassName);
FOUNDATION_EXPORT NSString *NSStringFromProtocol(Protocol *proto);
FOUNDATION_EXPORT NSString *NSStringFromRange(NSRange range);
FOUNDATION_EXPORT NSString *NSStringFromCGPoint(CGPoint p);
FOUNDATION_EXPORT NSString *NSStringFromCGSize(CGSize s);
FOUNDATION_EXPORT NSString *NSStringFromCGRect(CGRect r);
__END_DECLS
NS_ASSUME_NONNULL_END
#endif
