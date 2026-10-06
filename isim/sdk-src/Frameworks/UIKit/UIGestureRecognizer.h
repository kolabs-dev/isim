#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIGestureRecognizerState) { UIGestureRecognizerStatePossible, UIGestureRecognizerStateBegan, UIGestureRecognizerStateChanged, UIGestureRecognizerStateEnded, UIGestureRecognizerStateCancelled, UIGestureRecognizerStateFailed, UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded };
@class UIGestureRecognizer, UITouch;
NS_SWIFT_UI_ACTOR
@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
@end
NS_SWIFT_UI_ACTOR
@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, readonly) UIView *view;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nullable, nonatomic, weak) id<UIGestureRecognizerDelegate> delegate;
@property (nullable, nonatomic, copy) NSString *name;
- (CGPoint)locationInView:(nullable UIView *)view;
@end
@interface UIView (UIGestureRecognizerShouldBegin)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
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
@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@end
NS_ASSUME_NONNULL_END
