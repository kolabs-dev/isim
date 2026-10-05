#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UITouch, UIView, UIWindow;
typedef NS_ENUM(NSInteger, UIEventType) { UIEventTypeTouches, UIEventTypeMotion, UIEventTypeRemoteControl, UIEventTypePresses };
@interface UIEvent : NSObject
@property (nonatomic, readonly) UIEventType type;
@property (nonatomic, readonly) NSTimeInterval timestamp;
@property (nonatomic, readonly, nullable) NSSet<UITouch *> *allTouches;
- (nullable NSSet<UITouch *> *)touchesForView:(UIView *)view;
- (nullable NSSet<UITouch *> *)touchesForWindow:(UIWindow *)window;
@end
NS_ASSUME_NONNULL_END
