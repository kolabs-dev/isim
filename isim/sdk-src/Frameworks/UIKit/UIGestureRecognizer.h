#pragma once
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIView.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, UIGestureRecognizerState) { UIGestureRecognizerStatePossible, UIGestureRecognizerStateBegan, UIGestureRecognizerStateChanged, UIGestureRecognizerStateEnded, UIGestureRecognizerStateCancelled, UIGestureRecognizerStateFailed, UIGestureRecognizerStateRecognized = UIGestureRecognizerStateEnded };
@class UIGestureRecognizer, UITouch, UIPress, UIPressesEvent;
NS_SWIFT_UI_ACTOR
@protocol UIGestureRecognizerDelegate <NSObject>
@optional
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch;
/* failure requirements decided while the touch is in progress (iOS 7) */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceivePress:(UIPress *)press;
/* asked before a recognizer gets any part of an event (iOS 13.4) */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveEvent:(UIEvent *)event API_AVAILABLE(ios(13.4));
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
/* the touch types (UITouchType numbers) the recognizer gets; default: all of them */
@property (nonatomic, copy) NSArray<NSNumber *> *allowedTouchTypes;
/* the press types (UIPressType numbers) it gets (isim delivers no presses to recognizers) */
@property (nonatomic, copy) NSArray<NSNumber *> *allowedPressTypes;
/* the keyboard modifiers and pointer buttons of the event it is handling (iOS 13.4) */
@property (nonatomic, readonly) UIKeyModifierFlags modifierFlags API_AVAILABLE(ios(13.4));
@property (nonatomic, readonly) UIEventButtonMask buttonMask API_AVAILABLE(ios(13.4));
/* asks the delegate's gestureRecognizer(_:shouldReceive:) (event) */
- (BOOL)shouldReceiveEvent:(UIEvent *)event NS_SWIFT_NAME(shouldReceive(_:)) API_AVAILABLE(ios(13.4));
@end

@interface UIView (UIGestureRecognizerShouldBegin)
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer;
@end
@interface UITapGestureRecognizer : UIGestureRecognizer
@property (nonatomic) NSUInteger numberOfTapsRequired;
@property (nonatomic) NSUInteger numberOfTouchesRequired;
/* the pointer buttons a pointer click must use (default primary); finger taps always count */
@property (nonatomic) UIEventButtonMask buttonMaskRequired API_AVAILABLE(ios(13.4));
@end
/* trackpad / mouse wheel scrolling (UIEventTypeScroll): continuous (trackpad) and discrete (wheel) */
typedef NS_ENUM(NSInteger, UIScrollType) { UIScrollTypeDiscrete, UIScrollTypeContinuous } API_AVAILABLE(ios(13.4));
typedef NS_OPTIONS(NSInteger, UIScrollTypeMask) {
    UIScrollTypeMaskDiscrete = 1 << UIScrollTypeDiscrete, UIScrollTypeMaskContinuous = 1 << UIScrollTypeContinuous,
    UIScrollTypeMaskAll = UIScrollTypeMaskDiscrete | UIScrollTypeMaskContinuous } API_AVAILABLE(ios(13.4));
@interface UIPanGestureRecognizer : UIGestureRecognizer
/* scroll events it turns into pans (default none; a scroll view's pan takes all) */
@property (nonatomic) UIScrollTypeMask allowedScrollTypesMask API_AVAILABLE(ios(13.4));
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
