#pragma once
/* isim SDK CoreFoundation subset: CFBoolean (toll-free bridged to NSNumber). Self-authored. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
typedef const struct __attribute__((objc_bridge(NSNumber))) __CFBoolean *CFBooleanRef;
typedef const struct __attribute__((objc_bridge(NSNumber))) __CFNumber *CFNumberRef;
CF_EXPORT const CFBooleanRef kCFBooleanTrue;
CF_EXPORT const CFBooleanRef kCFBooleanFalse;
CF_EXPORT Boolean CFBooleanGetValue(CFBooleanRef boolean);
__END_DECLS
