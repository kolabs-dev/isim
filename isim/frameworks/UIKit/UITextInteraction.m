/* Text interactions for custom UITextInput views (UITextInteraction.h). They drive the view only through UITextInput
 * (closestPositionToPoint:, the tokenizer, selectedTextRange, caret and selection rects), as on iOS: isim's own text
 * fields and views use the same gestures through UITextInput.m. */
#import "UIKitPrivate.h"
#import <UIKit/UITextInteraction.h>

void isim_ui_show_loupe(UIView *v, CGPoint windowPoint);
void isim_ui_hide_loupe(void);
UITextSelectionRect *isim_ui_selection_rect(CGRect r);       /* UITextInputExtras.m */
/* the text input's view (textInputView is optional: the input itself when it is a view) */
static UIView *input_view(id<UITextInput> ti, UIView *fallback) {
    if ([ti respondsToSelector:@selector(textInputView)]) return ti.textInputView ?: fallback;
    return [(id)ti isKindOfClass:[UIView class]] ? (UIView *)ti : fallback;
}

/* ================= the standard views ================= */
@implementation UIStandardTextCursorView
@synthesize blinking = _blinking;
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.userInteractionEnabled = NO; self.accessibilityIdentifier = @"isim-text-cursor"; }
    return self;
}
- (void)resetBlinkAnimation {}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; double t[4]; isim_ui_rgba(self.tintColor, t);
    isim_gfx_fill_rounded(0, 0, s.width, s.height, fmin(1, s.width / 2), t);
}
@end
@interface __IsimSelectionHighlightView : UIView <UITextSelectionHighlightView>
@end
@implementation __IsimSelectionHighlightView
@synthesize selectionRects = _selectionRects;
- (void)setSelectionRects:(NSArray *)r { _selectionRects = [r copy]; isim_ui_set_needs_display(); }
- (void)_isim_drawContent {
    double t[4]; isim_ui_rgba(self.tintColor, t); t[3] = 0.22;
    for (UITextSelectionRect *r in _selectionRects) { CGRect x = r.rect; isim_gfx_fill_rounded(x.origin.x, x.origin.y, x.size.width, x.size.height, 0, t); }
}
@end
/* a handle: a bar along the selection's edge with a knob (above the start, below the end) */
@interface __IsimSelectionHandleView : UIView <UITextSelectionHandleView>
@property (nonatomic) NSDirectionalRectEdge isimDirection;
@end
@implementation __IsimSelectionHandleView
@synthesize customShape = _customShape;
- (NSDirectionalRectEdge)direction { return _isimDirection; }
- (CGRect)preferredFrameForRect:(CGRect)r {
    BOOL start = _isimDirection == NSDirectionalRectEdgeLeading || _isimDirection == NSDirectionalRectEdgeTop;
    CGFloat x = start ? CGRectGetMinX(r) : CGRectGetMaxX(r);
    return CGRectMake(x - 6, r.origin.y - (start ? 12 : 0), 12, r.size.height + 12);
}
- (void)_isim_drawContent {
    CGSize s = self.bounds.size; double t[4]; isim_ui_rgba(self.tintColor, t);
    BOOL start = _isimDirection == NSDirectionalRectEdgeLeading || _isimDirection == NSDirectionalRectEdgeTop;
    isim_gfx_fill_rounded(s.width / 2 - 1, start ? 10 : 0, 2, s.height - 10, 1, t);
    isim_gfx_fill_ellipse(s.width / 2 - 5, start ? 0 : s.height - 10, 10, 10, t);
}
@end

/* ================= UITextSelectionDisplayInteraction ================= */
@implementation UITextSelectionDisplayInteraction { __weak UIView *_view; }
- (instancetype)initWithTextInput:(id<UITextInput>)textInput delegate:(id<UITextSelectionDisplayInteractionDelegate>)delegate {
    if ((self = [super init])) {
        _textInput = textInput; _delegate = delegate;
        _cursorView = [UIStandardTextCursorView new];
        _highlightView = [__IsimSelectionHighlightView new];
        __IsimSelectionHandleView *a = [__IsimSelectionHandleView new], *b = [__IsimSelectionHandleView new];
        a.isimDirection = NSDirectionalRectEdgeLeading; b.isimDirection = NSDirectionalRectEdgeTrailing;
        _handleViews = @[ a, b ];
        for (UIView *v in @[ _cursorView, _highlightView, a, b ]) { v.userInteractionEnabled = NO; v.backgroundColor = UIColor.clearColor; v.hidden = YES; }
    }
    return self;
}
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { for (UIView *s in [self _managed]) [s removeFromSuperview]; }
- (void)didMoveToView:(UIView *)v { _view = v; [self setNeedsSelectionUpdate]; }
- (NSArray<UIView *> *)_managed { return [@[ _cursorView, _highlightView ] arrayByAddingObjectsFromArray:_handleViews ?: @[]]; }
- (void)setActivated:(BOOL)a { _activated = a; [self setNeedsSelectionUpdate]; }
- (void)setCursorView:(UIView<UITextCursorView> *)v { [_cursorView removeFromSuperview]; _cursorView = v; [self setNeedsSelectionUpdate]; }
- (void)setHighlightView:(UIView<UITextSelectionHighlightView> *)v { [_highlightView removeFromSuperview]; _highlightView = v; [self setNeedsSelectionUpdate]; }
- (void)setHandleViews:(NSArray *)h { for (UIView *v in _handleViews) [v removeFromSuperview]; _handleViews = [h copy]; [self setNeedsSelectionUpdate]; }
- (void)setNeedsSelectionUpdate { [self layoutManagedSubviews]; }
/* places the views from the selection (text input view coordinates converted to the views' containers) */
- (void)layoutManagedSubviews {
    UIView *view = _view;
    id<UITextInput> ti = _textInput;
    if (!view) return;
    UIView *below = [_delegate respondsToSelector:@selector(selectionContainerViewBelowTextForSelectionDisplayInteraction:)]
        ? [_delegate selectionContainerViewBelowTextForSelectionDisplayInteraction:self] : nil;
    below = below ?: view;
    if (_highlightView.superview != below) [below insertSubview:_highlightView atIndex:0];
    for (UIView *v in [@[ _cursorView ] arrayByAddingObjectsFromArray:_handleViews]) if (v.superview != view) [view addSubview:v];
    UITextRange *sel = ti.selectedTextRange;
    BOOL show = _activated && sel;
    UIView *src = input_view(ti, view);
    BOOL empty = !sel || sel.isEmpty;
    _cursorView.hidden = !show || !empty;
    _highlightView.hidden = !show || empty;
    for (UIView *h in _handleViews) h.hidden = !show || empty;
    if (!show) return;
    if (empty) {
        CGRect c = [src convertRect:[ti caretRectForPosition:sel.start] toView:view];
        _cursorView.frame = CGRectMake(c.origin.x, c.origin.y, fmax(c.size.width, 2), c.size.height);
        [_cursorView setNeedsDisplay]; isim_ui_set_needs_display();
        return;
    }
    NSArray<UITextSelectionRect *> *rects = [ti selectionRectsForRange:sel];
    _highlightView.frame = below.bounds;
    NSMutableArray *conv = [NSMutableArray array];
    CGRect first = CGRectNull, last = CGRectNull;
    for (UITextSelectionRect *r in rects) {
        CGRect x = [src convertRect:r.rect toView:below];
        [conv addObject:[self _rect:x like:r]];
        if (CGRectIsNull(first)) first = [src convertRect:r.rect toView:view];
        last = [src convertRect:r.rect toView:view];
    }
    _highlightView.selectionRects = conv;
    if (_handleViews.count >= 2) {
        _handleViews[0].frame = [_handleViews[0] preferredFrameForRect:first];
        _handleViews[1].frame = [_handleViews[1] preferredFrameForRect:last];
    }
    isim_ui_set_needs_display();
}
- (UITextSelectionRect *)_rect:(CGRect)x like:(UITextSelectionRect *)r { return isim_ui_selection_rect(x); }
@end

/* ================= UITextCursorDropPositionAnimator ================= */
@implementation UITextCursorDropPositionAnimator
- (instancetype)initWithTextCursorView:(UIView<UITextCursorView> *)v textInput:(id<UITextInput>)ti {
    if ((self = [super init])) { _cursorView = v; _textInput = ti; }
    return self;
}
- (void)setCursorVisible:(BOOL)visible animated:(BOOL)animated {
    UIView *v = _cursorView;
    void (^a)(void) = ^{ v.alpha = visible ? 1 : 0; };
    if (animated) [UIView animateWithDuration:0.15 animations:a]; else a();
}
- (void)placeCursorAtPosition:(UITextPosition *)p animated:(BOOL)animated {
    id<UITextInput> ti = _textInput;
    UIView *src = input_view(ti, _cursorView.superview), *dst = _cursorView.superview ?: src;
    CGRect c = [src convertRect:[ti caretRectForPosition:p] toView:dst];
    UIView *v = _cursorView;
    void (^a)(void) = ^{ v.frame = CGRectMake(c.origin.x, c.origin.y, fmax(c.size.width, 2), c.size.height); };
    if (animated) [UIView animateWithDuration:0.15 animations:a]; else a();
}
- (void)animateAlongsideChanges:(void (^)(void))animation completion:(void (^)(void))completion {
    [UIView animateWithDuration:0.15 animations:animation ?: ^{} completion:^(BOOL f) { if (completion) completion(); }];
}
@end

/* ================= UITextLoupeSession ================= */
@implementation UITextLoupeSession { __weak UIView *_view; }
+ (instancetype)beginLoupeSessionAtPoint:(CGPoint)p fromSelectionWidgetView:(UIView *)widget inView:(UIView *)view {
    if (!view.window) return nil;
    UITextLoupeSession *s = [self new]; s->_view = view;
    isim_ui_show_loupe(view, [view convertPoint:p toView:nil]);
    return s;
}
- (void)moveToPoint:(CGPoint)p withCaretRect:(CGRect)caret trackingCaret:(BOOL)tracks {
    UIView *v = _view; if (!v.window) return;
    CGPoint at = tracks && !CGRectIsNull(caret) ? CGPointMake(CGRectGetMidX(caret), CGRectGetMidY(caret)) : p;
    isim_ui_show_loupe(v, [v convertPoint:at toView:nil]);
}
- (void)invalidate { isim_ui_hide_loupe(); _view = nil; }
@end

/* ================= UITextInteraction ================= */
@implementation UITextInteraction {
    __weak UIView *_view; UITapGestureRecognizer *_tap, *_double; UILongPressGestureRecognizer *_press;
    UITextSelectionDisplayInteraction *_display; UITextLoupeSession *_loupe;
}
+ (instancetype)textInteractionForMode:(UITextInteractionMode)mode {
    UITextInteraction *i = [self new]; i->_textInteractionMode = mode; return i;
}
- (UIView *)view { return _view; }
- (NSArray<UIGestureRecognizer *> *)gesturesForFailureRequirements { return _tap ? @[ _double, _tap, _press ] : @[]; }
- (void)willMoveToView:(UIView *)v {
    UIView *old = _view;
    for (UIGestureRecognizer *g in [self gesturesForFailureRequirements]) [old removeGestureRecognizer:g];
    if (_display) [old removeInteraction:_display];
}
- (void)didMoveToView:(UIView *)v {
    _view = v;
    if (!v) return;
    if (!_textInput && [v conformsToProtocol:@protocol(UITextInput)]) _textInput = (UIResponder<UITextInput> *)v;
    _double = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_doubleTap:)]; _double.numberOfTapsRequired = 2;
    _tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(_tap:)];
    [_tap requireGestureRecognizerToFail:_double];
    _press = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_press:)]; _press.minimumPressDuration = 0.5;
    for (UIGestureRecognizer *g in @[ _double, _tap, _press ]) [v addGestureRecognizer:g];
    if (_textInput) {
        _display = [[UITextSelectionDisplayInteraction alloc] initWithTextInput:_textInput delegate:(id)self];
        [v addInteraction:_display];
    }
}
- (BOOL)_begin:(CGPoint)p {
    id<UITextInteractionDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(interactionShouldBegin:atPoint:)] && ![d interactionShouldBegin:self atPoint:p]) return NO;
    if ([d respondsToSelector:@selector(interactionWillBegin:)]) [d interactionWillBegin:self];
    return YES;
}
- (void)_end { id<UITextInteractionDelegate> d = _delegate; if ([d respondsToSelector:@selector(interactionDidEnd:)]) [d interactionDidEnd:self]; [self _refresh]; }
- (void)_refresh {
    UIResponder<UITextInput> *ti = _textInput;
    _display.activated = _textInteractionMode == UITextInteractionModeEditable ? ti.isFirstResponder : !ti.selectedTextRange.isEmpty;
    [_display setNeedsSelectionUpdate];
}
- (UITextPosition *)_positionAt:(UIGestureRecognizer *)g {
    UIResponder<UITextInput> *ti = _textInput;
    UIView *src = input_view(ti, _view);
    return [ti closestPositionToPoint:[g locationInView:src]];
}
- (void)_select:(UITextRange *)r {
    UIResponder<UITextInput> *ti = _textInput;
    if (!r) return;
    [ti.inputDelegate selectionWillChange:ti];
    ti.selectedTextRange = r;
    [ti.inputDelegate selectionDidChange:ti];
}
- (void)_tap:(UITapGestureRecognizer *)g {
    UIResponder<UITextInput> *ti = _textInput;
    if (!ti || ![self _begin:[g locationInView:_view]]) return;
    UITextPosition *p = [self _positionAt:g];
    if (_textInteractionMode == UITextInteractionModeEditable) {
        if (!ti.isFirstResponder) [ti becomeFirstResponder];
        if (p) [self _select:[ti textRangeFromPosition:p toPosition:p]];
        NSLog(@"isim: text interaction placed the cursor at %ld", (long)[ti offsetFromPosition:ti.beginningOfDocument toPosition:p]);
    } else if (p) [self _select:[ti textRangeFromPosition:p toPosition:p]];
    [self _end];
}
- (UITextRange *)_wordAt:(UITextPosition *)p {
    UIResponder<UITextInput> *ti = _textInput;
    UITextRange *w = [ti.tokenizer rangeEnclosingPosition:p withGranularity:UITextGranularityWord inDirection:UITextStorageDirectionForward];
    return w ?: [ti.tokenizer rangeEnclosingPosition:p withGranularity:UITextGranularityWord inDirection:UITextStorageDirectionBackward];
}
- (void)_doubleTap:(UITapGestureRecognizer *)g {
    UIResponder<UITextInput> *ti = _textInput;
    if (!ti || ![self _begin:[g locationInView:_view]]) return;
    if (_textInteractionMode == UITextInteractionModeEditable && !ti.isFirstResponder) [ti becomeFirstResponder];
    UITextPosition *p = [self _positionAt:g];
    UITextRange *w = p ? [self _wordAt:p] : nil;
    [self _select:w];
    if (w) NSLog(@"isim: text interaction selected \"%@\"", [ti textInRange:w]);
    [self _end];
}
- (void)_press:(UILongPressGestureRecognizer *)g {
    UIResponder<UITextInput> *ti = _textInput;
    if (!ti) return;
    CGPoint at = [g locationInView:_view];
    if (g.state == UIGestureRecognizerStateBegan) {
        if (![self _begin:at]) return;
        if (_textInteractionMode == UITextInteractionModeEditable && !ti.isFirstResponder) [ti becomeFirstResponder];
        _loupe = [UITextLoupeSession beginLoupeSessionAtPoint:at fromSelectionWidgetView:nil inView:_view];
    }
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        UITextPosition *p = [self _positionAt:g];
        if (!p) return;
        if (_textInteractionMode == UITextInteractionModeEditable) [self _select:[ti textRangeFromPosition:p toPosition:p]];
        else [self _select:[self _wordAt:p]];
        [_loupe moveToPoint:at withCaretRect:CGRectNull trackingCaret:NO];
        [self _refresh];
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        [_loupe invalidate]; _loupe = nil;
        [self _end];
    }
}
@end
