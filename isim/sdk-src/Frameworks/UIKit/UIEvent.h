#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UITouch, UIView, UIWindow, UIGestureRecognizer;
typedef NS_ENUM(NSInteger, UIEventType) { UIEventTypeTouches, UIEventTypeMotion, UIEventTypeRemoteControl, UIEventTypePresses };
typedef NS_ENUM(NSInteger, UIEventSubtype) { UIEventSubtypeNone = 0, UIEventSubtypeMotionShake = 1, UIEventSubtypeRemoteControlPlay = 100,
    UIEventSubtypeRemoteControlPause = 101, UIEventSubtypeRemoteControlStop = 102, UIEventSubtypeRemoteControlTogglePlayPause = 103,
    UIEventSubtypeRemoteControlNextTrack = 104, UIEventSubtypeRemoteControlPreviousTrack = 105 };
NS_SWIFT_UI_ACTOR
@interface UIEvent : NSObject
@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) UIEventSubtype subtype;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly, nullable) NSSet<UITouch *> *allTouches;
- (nullable NSSet<UITouch *> *)touchesForView:(UIView *)view;
- (nullable NSSet<UITouch *> *)touchesForWindow:(UIWindow *)window;
- (nullable NSSet<UITouch *> *)touchesForGestureRecognizer:(UIGestureRecognizer *)gesture;
- (nullable NSArray<UITouch *> *)coalescedTouchesForTouch:(UITouch *)touch;
- (nullable NSArray<UITouch *> *)predictedTouchesForTouch:(UITouch *)touch;
@end
NS_ASSUME_NONNULL_END
