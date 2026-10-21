#pragma once
/* isim PassKit: shared macros of the Objective-C headers. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Contacts/Contacts.h>
#ifdef __cplusplus
#define PK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define PK_EXTERN extern __attribute__((visibility("default")))
#endif
