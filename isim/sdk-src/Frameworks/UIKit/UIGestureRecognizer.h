#pragma once
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIGestureRecognizerState) { UIGestureRecognizerStatePossible, UIGestureRecognizerStateBegan, UIGestureRecognizerStateChanged, UIGestureRecognizerStateEnded, UIGestureRecognizerStateCancelled, UIGestureRecognizerStateFailed, UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded };
@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, readonly) UIView *view;
@property (nonatomic) BOOL cancelsTouchesInView;
- (CGPoint)locationInView:(nullable UIView *)view;
@end
@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end
@interface UIPanGestureRecognizer : UIGestureRecognizer
- (CGPoint)translationInView:(nullable UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(nullable UIView *)view;
- (CGPoint)velocityInView:(nullable UIView *)view;
@end
NS_ASSUME_NONNULL_END
