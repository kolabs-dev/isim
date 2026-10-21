#pragma once
/* isim CloudKit: shared macros of the Objective-C headers. */
#import <Foundation/Foundation.h>
#ifdef __cplusplus
#define CK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define CK_EXTERN extern __attribute__((visibility("default")))
#endif
