#pragma once
/* isim: text interactions for custom UITextInput views (#9): UITextInteraction (the system's tap, double tap and long
   press gestures), UITextSelectionDisplayInteraction (the cursor, selection highlight and handles drawn from the
   text input's selection), the cursor, highlight and handle view protocols, UIStandardTextCursorView, the drop
   position animator and the loupe. UITextInteraction.m. */
#import <UIKit/UIView.h>
#import <UIKit/UIInteraction.h>
#import <UIKit/UITextInput.h>
#import <UIKit/UIButton.h>
NS_ASSUME_NONNULL_BEGIN
@class UITextInteraction, UITextSelectionDisplayInteraction, UIBezierPath, UIGestureRecognizer;

typedef NS_ENUM(NSInteger, UITextInteractionMode) { UITextInteractionModeEditable, UITextInteractionModeNonEditable } API_AVAILABLE(ios(13.0));

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@protocol UITextInteractionDelegate <NSObject>
@optional
- (BOOL)interactionShouldBegin:(UITextInteraction *)interaction atPoint:(CGPoint)point;
- (void)interactionWillBegin:(UITextInteraction *)interaction;
- (void)interactionDidEnd:(UITextInteraction *)interaction;
@end

/* editable: a tap places the cursor (and the view becomes first responder), a double tap selects a word, a long press
   moves the cursor under the loupe; non-editable: a double tap or long press selects a word, a tap clears it */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UITextInteraction : NSObject <UIInteraction>
+ (instancetype)textInteractionForMode:(UITextInteractionMode)mode NS_SWIFT_NAME(init(for:));
@property (nonatomic, weak) id<UITextInteractionDelegate> delegate;
@property (nonatomic, weak, nullable) UIResponder<UITextInput> *textInput;   /* the view's, if it adopts UITextInput */
@property (nonatomic, readonly) UITextInteractionMode textInteractionMode;
@property (nonatomic, readonly) NSArray<UIGestureRecognizer *> *gesturesForFailureRequirements;
@end

/* ---- what draws the selection ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UITextCursorView <UICoordinateSpace>
@property (nonatomic, assign, getter=isBlinking) BOOL blinking;
- (void)resetBlinkAnimation;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UITextSelectionHighlightView <UICoordinateSpace>
@property (nonatomic, copy) NSArray<UITextSelectionRect *> *selectionRects;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UITextSelectionHandleView <UICoordinateSpace>
@property (nonatomic, readonly) NSDirectionalRectEdge direction;
@property (nonatomic, copy, nullable) UIBezierPath *customShape;
- (CGRect)preferredFrameForRect:(CGRect)rect;
@end
/* the system's cursor: a 2 pt bar in the tint colour (isim's cursor does not blink: blinking is stored) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UIStandardTextCursorView : UIView <UITextCursorView>
@end

NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@protocol UITextSelectionDisplayInteractionDelegate <NSObject>
@optional
/* where the highlight goes (below the text); nil: the interaction's view */
- (nullable UIView *)selectionContainerViewBelowTextForSelectionDisplayInteraction:(UITextSelectionDisplayInteraction *)interaction
    NS_SWIFT_NAME(selectionContainerViewBelowText(for:));
@end
/* shows the text input's selection: the cursor for an empty one, the highlight and two handles otherwise; call
   setNeedsSelectionUpdate when the selection changes */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UITextSelectionDisplayInteraction : NSObject <UIInteraction>
- (instancetype)initWithTextInput:(id<UITextInput>)textInput delegate:(id<UITextSelectionDisplayInteractionDelegate>)delegate NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, weak, readonly) id<UITextInput> textInput;
@property (nonatomic, weak, readonly) id<UITextSelectionDisplayInteractionDelegate> delegate;
@property (nonatomic, getter=isActivated) BOOL activated;
@property (nonatomic, strong) UIView<UITextCursorView> *cursorView;
@property (nonatomic, strong) UIView<UITextSelectionHighlightView> *highlightView;
@property (nonatomic, copy) NSArray<UIView<UITextSelectionHandleView> *> *handleViews;
- (void)setNeedsSelectionUpdate;
- (void)layoutManagedSubviews;
@end

/* the cursor following a drag over the text (drop position) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UITextCursorDropPositionAnimator : NSObject
- (instancetype)initWithTextCursorView:(UIView<UITextCursorView> *)cursorView textInput:(id<UITextInput>)textInput;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, strong) UIView<UITextCursorView> *cursorView;
@property (nonatomic, readonly, weak) id<UITextInput> textInput;
- (void)setCursorVisible:(BOOL)visible animated:(BOOL)animated;
- (void)placeCursorAtPosition:(UITextPosition *)position animated:(BOOL)animated;
- (void)animateAlongsideChanges:(nullable void (^)(void))animation completion:(nullable void (^)(void))completion NS_SWIFT_NAME(animate(alongsideChanges:completion:));
@end

/* the loupe magnifying the text around a point */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UITextLoupeSession : NSObject
+ (nullable instancetype)beginLoupeSessionAtPoint:(CGPoint)point fromSelectionWidgetView:(nullable UIView *)selectionWidget inView:(UIView *)interactionView
    NS_SWIFT_NAME(begin(at:fromSelectionWidgetView:in:));
- (void)moveToPoint:(CGPoint)point withCaretRect:(CGRect)caretRect trackingCaret:(BOOL)tracksCaret NS_SWIFT_NAME(move(to:withCaretRect:trackingCaret:));
- (void)invalidate;
@end
NS_ASSUME_NONNULL_END
