#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UIView;
/* isim (adapted): there is no haptic hardware; each feedback is shown as a brief ring at its location (the point
   given, the generator's view, or the middle of the screen) and logged ("isim: haptic ..."). ISIM_HAPTIC_INDICATOR=0
   turns the ring off. */
NS_SWIFT_UI_ACTOR
@interface UIFeedbackGenerator : NSObject
- (instancetype)init;
/* iOS 17.5: a generator attached to a view (feedback is located in it) */
+ (instancetype)feedbackGeneratorForView:(UIView *)view API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(init(view:));
- (void)prepare;
@end
typedef NS_ENUM(NSInteger, UIImpactFeedbackStyle) {
    UIImpactFeedbackStyleLight, UIImpactFeedbackStyleMedium, UIImpactFeedbackStyleHeavy, UIImpactFeedbackStyleSoft, UIImpactFeedbackStyleRigid
};
NS_SWIFT_UI_ACTOR
@interface UIImpactFeedbackGenerator : UIFeedbackGenerator
- (instancetype)initWithStyle:(UIImpactFeedbackStyle)style;
+ (instancetype)feedbackGeneratorWithStyle:(UIImpactFeedbackStyle)style forView:(UIView *)view API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(init(style:view:));
- (void)impactOccurred;
- (void)impactOccurredWithIntensity:(CGFloat)intensity NS_SWIFT_NAME(impactOccurred(intensity:));
- (void)impactOccurredAtLocation:(CGPoint)location API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(impactOccurred(at:));
- (void)impactOccurredWithIntensity:(CGFloat)intensity atLocation:(CGPoint)location API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(impactOccurred(intensity:at:));
@end
NS_SWIFT_UI_ACTOR
@interface UISelectionFeedbackGenerator : UIFeedbackGenerator
- (void)selectionChanged;
- (void)selectionChangedAtLocation:(CGPoint)location API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(selectionChanged(at:));
@end
typedef NS_ENUM(NSInteger, UINotificationFeedbackType) {
    UINotificationFeedbackTypeSuccess, UINotificationFeedbackTypeWarning, UINotificationFeedbackTypeError
};
NS_SWIFT_UI_ACTOR
@interface UINotificationFeedbackGenerator : UIFeedbackGenerator
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType;
- (void)notificationOccurred:(UINotificationFeedbackType)notificationType atLocation:(CGPoint)location API_AVAILABLE(ios(17.5)) NS_SWIFT_NAME(notificationOccurred(_:at:));
@end
/* iOS 17.5: drawing canvases (snapping, finished paths) */
NS_SWIFT_UI_ACTOR
@interface UICanvasFeedbackGenerator : UIFeedbackGenerator
- (void)alignmentOccurredAtLocation:(CGPoint)location NS_SWIFT_NAME(alignmentOccurred(at:));
- (void)pathCompletedAtLocation:(CGPoint)location NS_SWIFT_NAME(pathCompleted(at:));
@end
NS_ASSUME_NONNULL_END
