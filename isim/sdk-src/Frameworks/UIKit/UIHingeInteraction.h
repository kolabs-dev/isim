#pragma once
/* iOS 27.1: the hinge of a foldable device, observed through an interaction. isim's devices have no hinge: the
   handler is called with a nil hinge when the interaction joins (or leaves) a window, as when it leaves a hierarchy
   that provides hinge updates (adapted). */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIInteraction.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIHingeStatus) {
    UIHingeStatusUnknown = 0,
    UIHingeStatusClosed = 1,
    UIHingeStatusPartiallyOpen = 2,
    UIHingeStatusFullyOpen = 3,
} NS_SWIFT_NAME(UIHinge.Status) API_AVAILABLE(ios(27.1));

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(27.1))
@interface UIHinge : NSObject <NSCopying>
@property (nonatomic, readonly) CGFloat angle;            /* radians */
@property (nonatomic, readonly) UIHingeStatus status;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_SWIFT_UI_ACTOR NS_SWIFT_NAME(UIHingeInteraction.Update) API_AVAILABLE(ios(27.1))
@interface UIHingeInteractionUpdate : NSObject
@property (nonatomic, copy, readonly, nullable) UIHinge *hinge;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(27.1))
@interface UIHingeInteraction : NSObject <UIInteraction>
- (instancetype)initWithUpdateHandler:(void (^)(UIHingeInteraction *interaction, UIHingeInteractionUpdate *update))updateHandler NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@end
NS_ASSUME_NONNULL_END
