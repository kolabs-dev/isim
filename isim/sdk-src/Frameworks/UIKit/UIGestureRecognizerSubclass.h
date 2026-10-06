#pragma once
/* isim: the subclassing interface of UIGestureRecognizer (import UIKit.UIGestureRecognizerSubclass). */
#import <UIKit/UIGestureRecognizer.h>
NS_ASSUME_NONNULL_BEGIN
@interface UIGestureRecognizer (UIGestureRecognizerProtected)
@property (nonatomic, readwrite) UIGestureRecognizerState state;
- (void)ignoreTouch:(UITouch *)touch forEvent:(UIEvent *)event;
- (void)reset;
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer;
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer;
- (BOOL)shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (BOOL)shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer;
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event;
@end
NS_ASSUME_NONNULL_END
