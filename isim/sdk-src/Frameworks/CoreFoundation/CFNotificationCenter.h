#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFNotificationCenter, implemented in Foundation
 * (CFNotificationCenter.m). The Darwin center is notify(3) (posts reach every process of the device; object and
 * userInfo are not sent, as on iOS); the local center delivers within the process, on the posting thread; the
 * distributed center (macOS's) delivers within the process too. */
#include <CoreFoundation/CFBase.h>
#include <CoreFoundation/CFString.h>

__BEGIN_DECLS
#pragma clang arc_cf_code_audited begin
/* Boolean parameters are C bool here (the same one-byte ABI) so Swift sees Bool, as with Apple's SDK (#523) */

#ifndef CF_EXTENSIBLE_STRING_ENUM
#define CF_EXTENSIBLE_STRING_ENUM __attribute__((swift_wrapper(struct)))
#endif
#ifndef __ISIM_CFNOTIFICATIONNAME
#define __ISIM_CFNOTIFICATIONNAME
typedef CFStringRef CFNotificationName CF_EXTENSIBLE_STRING_ENUM;
#endif

typedef struct __attribute__((objc_bridge_mutable(id))) __CFNotificationCenter *CFNotificationCenterRef;

typedef void (*CFNotificationCallback)(CFNotificationCenterRef center, void *observer, CFNotificationName name,
                                       const void *object, CFDictionaryRef userInfo);

typedef CF_ENUM(CFIndex, CFNotificationSuspensionBehavior) {
    CFNotificationSuspensionBehaviorDrop = 1,
    CFNotificationSuspensionBehaviorCoalesce = 2,
    CFNotificationSuspensionBehaviorHold = 3,
    CFNotificationSuspensionBehaviorDeliverImmediately = 4
};

enum {
    kCFNotificationDeliverImmediately = (1UL << 0),
    kCFNotificationPostToAllSessions = (1UL << 1)
};

CF_EXPORT CFTypeID CFNotificationCenterGetTypeID(void);
CF_EXPORT CFNotificationCenterRef CFNotificationCenterGetLocalCenter(void);
CF_EXPORT CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);
CF_EXPORT CFNotificationCenterRef CFNotificationCenterGetDarwinNotifyCenter(void);
CF_EXPORT void CFNotificationCenterAddObserver(CFNotificationCenterRef center, const void *observer, CFNotificationCallback callBack,
                                               CFStringRef name, const void *object, CFNotificationSuspensionBehavior suspensionBehavior);
CF_EXPORT void CFNotificationCenterRemoveObserver(CFNotificationCenterRef center, const void *observer, CFNotificationName name, const void *object);
CF_EXPORT void CFNotificationCenterRemoveEveryObserver(CFNotificationCenterRef center, const void *observer);
CF_EXPORT void CFNotificationCenterPostNotification(CFNotificationCenterRef center, CFNotificationName name, const void *object,
                                                    CFDictionaryRef userInfo, bool deliverImmediately);
CF_EXPORT void CFNotificationCenterPostNotificationWithOptions(CFNotificationCenterRef center, CFNotificationName name, const void *object,
                                                               CFDictionaryRef userInfo, CFOptionFlags options);

#pragma clang arc_cf_code_audited end
__END_DECLS
