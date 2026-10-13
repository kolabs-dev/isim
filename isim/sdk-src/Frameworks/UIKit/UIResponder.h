#pragma once
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UITouch, UIEvent;
NS_SWIFT_UI_ACTOR
@interface UIResponder : NSObject
@property (nonatomic, readonly, nullable) UIResponder *nextResponder;
@property (nonatomic, readonly) BOOL canBecomeFirstResponder, canResignFirstResponder, isFirstResponder;
- (BOOL)becomeFirstResponder;
- (BOOL)resignFirstResponder;
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event;
- (BOOL)canPerformAction:(SEL)action withSender:(nullable id)sender;
@end
/* the next responder's; a window has its own (Shake to Undo uses the first responder's). A category: UIResponder's
   instance size (and its subclasses' ivar offsets) must not change */
@interface UIResponder (UIResponderUndo)
@property (nullable, nonatomic, readonly) NSUndoManager *undoManager;
@end
NS_ASSUME_NONNULL_END
