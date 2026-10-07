#pragma once
/* isim: UIInteraction (views own interactions: drag, drop, pointer, pencil, edit menu, large content viewer) */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
NS_SWIFT_UI_ACTOR
@protocol UIInteraction <NSObject>
@property (nullable, nonatomic, readonly, weak) UIView *view;
- (void)willMoveToView:(nullable UIView *)view;
- (void)didMoveToView:(nullable UIView *)view;
@end
@interface UIView (UIInteractions)
- (void)addInteraction:(id<UIInteraction>)interaction;
- (void)removeInteraction:(id<UIInteraction>)interaction;
@property (nonatomic, copy) NSArray<id<UIInteraction>> *interactions;
@end
NS_ASSUME_NONNULL_END
