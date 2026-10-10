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
/* failure requirements decided while the touch is in progress (iOS 7) */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
@end
NS_SWIFT_UI_ACTOR
@interface UIGestureRecognizer : NSObject
- (instancetype)initWithTarget:(nullable id)target action:(nullable SEL)action NS_DESIGNATED_INITIALIZER;
- (instancetype)init;
- (void)addTarget:(id)target action:(SEL)action;
- (void)removeTarget:(nullable id)target action:(nullable SEL)action;
@property (nonatomic, readonly) UIGestureRecognizerState state;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nullable, nonatomic, readonly, weak) UIView *view;
@property (nonatomic) BOOL cancelsTouchesInView;
@property (nullable, nonatomic, weak) id<UIGestureRecognizerDelegate> delegate;
@property (nullable, nonatomic, copy) NSString *name;
- (CGPoint)locationInView:(nullable UIView *)view;
- (CGPoint)locationOfTouch:(NSUInteger)touchIndex inView:(nullable UIView *)view;
@property (nonatomic, readonly) NSUInteger numberOfTouches;
@property (nonatomic) BOOL delaysTouchesBegan;
@property (nonatomic) BOOL delaysTouchesEnded;
@property (nonatomic) BOOL requiresExclusiveTouchType;
- (void)requireGestureRecognizerToFail:(UIGestureRecognizer *)otherGestureRecognizer;
/* isim (SwiftUI high-priority and simultaneous gestures): a tap recognizer that still takes taps on the controls
   inside its view (UIKit's rule lets a control's tap win over its superviews' tap recognizers) */
@property (nonatomic, setter=_isim_setTakesControlTaps:) BOOL _isim_takesControlTaps;
@end
@interface UIView (UIGestureRecognizerShouldBegin)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
@end
@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@end
@interface UIPanGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger minimumNumberOfTouches;
@property (nonatomic) NSUInteger maximumNumberOfTouches;
- (CGPoint)translationInView:(nullable UIView *)view;
- (void)setTranslation:(CGPoint)translation inView:(nullable UIView *)view;
- (CGPoint)velocityInView:(nullable UIView *)view;
@end
typedef NS_OPTIONS(NSUInteger, UISwipeGestureRecognizerDirection) {
    UISwipeGestureRecognizerDirectionRight = 1 << 0, UISwipeGestureRecognizerDirectionLeft = 1 << 1,
    UISwipeGestureRecognizerDirectionUp = 1 << 2, UISwipeGestureRecognizerDirectionDown = 1 << 3 };
@interface UISwipeGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) UISwipeGestureRecognizerDirection direction;
@end
typedef NS_OPTIONS(NSUInteger, UIRectEdge) { UIRectEdgeNone = 0, UIRectEdgeTop = 1 << 0, UIRectEdgeLeft = 1 << 1, UIRectEdgeBottom = 1 << 2, UIRectEdgeRight = 1 << 3, UIRectEdgeAll = 15 };
@interface UIScreenEdgePanGestureRecognizer : UIPanGestureRecognizer
@property (nonatomic) UIRectEdge edges;
@end
@interface UILongPressGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
@property (nonatomic) NSTimeInterval minimumPressDuration;
@property (nonatomic) CGFloat allowableMovement;
@end
NS_ASSUME_NONNULL_END
