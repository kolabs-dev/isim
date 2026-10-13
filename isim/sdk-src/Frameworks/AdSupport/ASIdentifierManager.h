#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: the identifier is all zeros unless App Tracking Transparency allowed tracking for the app (iOS 14.5+); then it
   is the device's advertising identifier. Not subclassable from Objective-C. */
@interface ASIdentifierManager : NSObject
+ (ASIdentifierManager *)sharedManager;
@property (nonnull, nonatomic, readonly) NSUUID *advertisingIdentifier;
@property (nonatomic, readonly, getter=isAdvertisingTrackingEnabled) BOOL advertisingTrackingEnabled __attribute__((deprecated));
@end
NS_ASSUME_NONNULL_END
