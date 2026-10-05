#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UIView;
/* isim: like the iOS Simulator, feedback generators exist and produce no haptics. */
NS_SWIFT_UI_ACTOR
@interface UIFeedbackGenerator : NSObject
- (void)prepare;
@end
typedef NS_ENUM(NSInteger, UIImpactFeedbackStyle) {
    UIImpactFeedbackStyleLight, UIImpactFeedbackStyleMedium, UIImpactFeedbackStyleHeavy, UIImpactFeedbackStyleSoft, UIImpactFeedbackStyleRigid
};
NS_SWIFT_UI_ACTOR
@interface UIImpactFeedbackGenerator : UIFeedbackGenerator
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
- (void)impactOccurred;
- (void)impactOccurredWithIntensity:(CGFloat)intensity;
@end
NS_SWIFT_UI_ACTOR
@interface UISelectionFeedbackGenerator : UIFeedbackGenerator
- (void)selectionChanged;
@end
typedef NS_ENUM(NSInteger, UINotificationFeedbackType) {
    UINotificationFeedbackTypeSuccess, UINotificationFeedbackTypeWarning, UINotificationFeedbackTypeError
};
NS_SWIFT_UI_ACTOR
@interface UINotificationFeedbackGenerator : UIFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;
@end
NS_ASSUME_NONNULL_END
