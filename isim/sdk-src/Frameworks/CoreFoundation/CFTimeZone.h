#pragma once
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
/* toll-free bridged to NSTimeZone */
typedef const struct __attribute__((objc_bridge(NSTimeZone))) __CFTimeZone *CFTimeZoneRef;
CF_EXPORT CFTimeZoneRef CFTimeZoneCopyDefault(void) CF_RETURNS_RETAINED;
CF_EXPORT CFTimeZoneRef CFTimeZoneCopySystem(void) CF_RETURNS_RETAINED;
CF_EXPORT CFStringRef CFTimeZoneGetName(CFTimeZoneRef tz);
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
