#pragma once
/* isim SDK CoreFoundation subset: absolute time and CFDate (toll-free bridged to NSDate). Self-authored. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
typedef double CFTimeInterval;
typedef CFTimeInterval CFAbsoluteTime;          /* seconds since 1 January 2001 00:00 GMT */
CF_EXPORT const CFTimeInterval kCFAbsoluteTimeIntervalSince1970;
CF_EXPORT const CFTimeInterval kCFAbsoluteTimeIntervalSince1904;
CF_EXPORT CFAbsoluteTime CFAbsoluteTimeGetCurrent(void);
typedef const struct __attribute__((objc_bridge(NSDate))) __CFDate *CFDateRef;
CF_EXPORT CFTypeID CFDateGetTypeID(void);
CF_EXPORT CFDateRef CFDateCreate(CFAllocatorRef allocator, CFAbsoluteTime at) CF_RETURNS_RETAINED;
CF_EXPORT CFAbsoluteTime CFDateGetAbsoluteTime(CFDateRef theDate);
CF_EXPORT CFTimeInterval CFDateGetTimeIntervalSinceDate(CFDateRef theDate, CFDateRef otherDate);
CF_EXPORT CFComparisonResult CFDateCompare(CFDateRef theDate, CFDateRef otherDate, void *context);
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
