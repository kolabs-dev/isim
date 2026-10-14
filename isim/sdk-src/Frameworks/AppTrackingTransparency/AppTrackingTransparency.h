#pragma once
/* isim AppTrackingTransparency for Objective-C: ATTrackingManager of the Swift overlay (the framework re-exports
   libswiftAppTrackingTransparency.dylib). The request shows iOS's tracking alert; the answer is stored in the app's
   container. Swift uses the overlay; these declarations are hidden from Swift. Not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, ATTrackingManagerAuthorizationStatus) {
    ATTrackingManagerAuthorizationStatusNotDetermined = 0,
    ATTrackingManagerAuthorizationStatusRestricted,
    ATTrackingManagerAuthorizationStatusDenied,
    ATTrackingManagerAuthorizationStatusAuthorized
};
@interface ATTrackingManager : NSObject
@property (class, nonatomic, readonly, assign) ATTrackingManagerAuthorizationStatus trackingAuthorizationStatus;
+ (void)requestTrackingAuthorizationWithCompletionHandler:(void (^)(ATTrackingManagerAuthorizationStatus status))completion;
@end
NS_ASSUME_NONNULL_END
#endif
