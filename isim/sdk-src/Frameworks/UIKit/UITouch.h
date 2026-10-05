#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UIView, UIWindow;
typedef NS_ENUM(NSInteger, UITouchPhase) { UITouchPhaseBegan, UITouchPhaseMoved, UITouchPhaseStationary, UITouchPhaseEnded, UITouchPhaseCancelled };
typedef NS_ENUM(NSInteger, UITouchType) { UITouchTypeDirect, UITouchTypeIndirect, UITouchTypePencil };
NS_SWIFT_UI_ACTOR
@interface UITouch : NSObject
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly) UITouchPhase phase;
@property (nonatomic, readonly) NSUInteger tapCount;
@property (nonatomic, readonly) UITouchType type;
@property (nullable, nonatomic, readonly, strong) UIWindow *window;
@property (nullable, nonatomic, readonly, strong) UIView *view;
- (CGPoint)locationInView:(nullable UIView *)view;
- (CGPoint)previousLocationInView:(nullable UIView *)view;
@end
NS_ASSUME_NONNULL_END
