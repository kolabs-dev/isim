#pragma once
/* isim GameKit: shared macros of the Objective-C headers. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#ifdef __cplusplus
#define GK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define GK_EXTERN extern __attribute__((visibility("default")))
#endif
