#pragma once
/* isim SDK (self-authored): Intents — INFocusStatusCenter, whether a Focus is on (iOS 15). Adapted: the Focus is the
 * one isim's Control Center, Settings > Focus or the script `focus` turns on. The app asks for permission first
 * (an alert; ISIM_FOCUS_STATUS_PERMISSION=allow|deny answers it); until then, or when denied, isFocused is nil.
 * iOS shares the status only with apps that have the Communication Notifications capability; isim does not check it. */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, INFocusStatusAuthorizationStatus) {
    INFocusStatusAuthorizationStatusNotDetermined = 0,
    INFocusStatusAuthorizationStatusRestricted,
    INFocusStatusAuthorizationStatusDenied,
    INFocusStatusAuthorizationStatusAuthorized,
} API_AVAILABLE(ios(15.0));

API_AVAILABLE(ios(15.0))
@interface INFocusStatus : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithIsFocused:(nullable NSNumber *)isFocused NS_DESIGNATED_INITIALIZER NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
/** @YES while a Focus is on, @NO when none is; nil without authorization */
@property (readonly, copy, nullable, nonatomic) NSNumber *isFocused NS_REFINED_FOR_SWIFT;
@end

API_AVAILABLE(ios(15.0))
@interface INFocusStatusCenter : NSObject
@property (class, readonly, strong, nonatomic) INFocusStatusCenter *defaultCenter;
@property (readonly, copy, nonatomic) INFocusStatus *focusStatus;
@property (readonly, nonatomic) INFocusStatusAuthorizationStatus authorizationStatus;
- (void)requestAuthorizationWithCompletionHandler:(nullable void (^)(INFocusStatusAuthorizationStatus status))completionHandler;
@end

NS_ASSUME_NONNULL_END
