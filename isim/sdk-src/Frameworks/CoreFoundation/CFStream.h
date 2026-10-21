#pragma once
/* isim SDK (self-authored, Apple's declarations and values): CFStream's error type, which CFNetwork's CFHost reports.
   The read and write streams themselves (CFReadStream, CFWriteStream) are not in isim's CoreFoundation yet: Foundation's
   NSInputStream / NSOutputStream are. */
#include <CoreFoundation/CFBase.h>
__BEGIN_DECLS
CF_IMPLICIT_BRIDGING_ENABLED
typedef CF_ENUM(CFIndex, CFStreamErrorDomain) {
    kCFStreamErrorDomainCustom = -1L,
    kCFStreamErrorDomainPOSIX = 1,
    kCFStreamErrorDomainMacOSStatus
};
typedef struct {
    CFIndex domain;
    SInt32 error;
} CFStreamError;
CF_IMPLICIT_BRIDGING_DISABLED
__END_DECLS
