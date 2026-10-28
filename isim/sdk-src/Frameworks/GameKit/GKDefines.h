#pragma once
/* isim GameKit: shared macros of the Objective-C headers. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#ifdef __cplusplus
#define GK_EXTERN extern "C" __attribute__((visibility("default")))
#else
#define GK_EXTERN extern __attribute__((visibility("default")))
#endif

#if !defined(__swift__)
/* whether an item is released to players or only to testers (issue #394) */
typedef NS_OPTIONS(NSUInteger, GKReleaseState) { GKReleaseStateUnknown = 0, GKReleaseStateReleased = 1, GKReleaseStatePrereleased = 2 };
/* the legacy session API's transport and peer state */
typedef NS_ENUM(NSInteger, GKTransportType) { GKTransportTypeUnreliable = 0, GKTransportTypeReliable = 1 };
typedef NS_ENUM(NSInteger, GKConnectionState) { GKConnectionStateNotConnected = 0, GKConnectionStateConnected = 1 };
GK_EXTERN NSString * const GKSessionErrorDomain;
GK_EXTERN NSString * const GKVoiceChatServiceErrorDomain;
GK_EXTERN NSString * const GKPlayerIDNoLongerAvailable;
#endif
