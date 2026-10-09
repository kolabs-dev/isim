/* UITextField: single-line text input implementing UITextInput (selection, marked text, edit menu, selection
 * gestures and keyboard navigation shared with UITextView in UITextInput.m). Becoming first responder brings up
 * isim's system keyboard (UIKeyboard.m); the hardware keyboard and ISIM_SCRIPT "type"/"key" also edit it.
 * A private multi-line mode (_isim_minLines/_isim_maxLines) backs SwiftUI's TextField(axis: .vertical) and
 * TextEditor. The caret does not blink (stable screenshots). */
#import "UITextInputImpl.h"
#include <math.h>

NSNotificationName const UITextFieldTextDidBeginEditingNotification = @"UITextFieldTextDidBeginEditingNotification";
NSNotificationName const UITextFieldTextDidEndEditingNotification = @"UITextFieldTextDidEndEditingNotification";
NSNotificationName const UITextFieldTextDidChangeNotification = @"UITextFieldTextDidChangeNotification";

@interface UITextField () <IsimEditableText>
@end
@implementation UITextField {
    NSString *_storage;
    NSRange _sel;
    BOOL _editing;
    CGFloat _scrollX;                       /* single line: horizontal scroll that keeps the caret visible */
    NSInteger _isim_minLines, _isim_maxLines; BOOL _isim_multi;
}
/* the alignment text is laid out with: natural is right aligned right to left */
- (NSTextAlignment)_isim_alignment { return _textAlignment == NSTextAlignmentNatural ? ([self _isim_isRTL] ? NSTextAlignmentRight : NSTextAlignmentLeft) : _textAlignment; }
- (void)_isim_setLineLimitMin:(NSInteger)minLines max:(NSInteger)maxLines { _isim_minLines = minLines; _isim_maxLines = maxLines; _isim_multi = YES; [self _changed]; }
@synthesize autocapitalizationType = _autocapitalizationType, autocorrectionType = _autocorrectionType, spellCheckingType = _spellCheckingType,
    keyboardType = _keyboardType, keyboardAppearance = _keyboardAppearance, returnKeyType = _returnKeyType,
    enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically, secureTextEntry = _secureTextEntry, textContentType = _textContentType,
    smartQuotesType = _smartQuotesType, smartDashesType = _smartDashesType, smartInsertDeleteType = _smartInsertDeleteType,
    inlinePredictionType = _inlinePredictionType, passwordRules = _passwordRules;
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _storage = @""; _font = [UIFont systemFontOfSize:17]; _textColor = UIColor.labelColor;
        _textAlignment = NSTextAlignmentNatural; _autocapitalizationType = UITextAutocapitalizationTypeSentences;
        [self setContentHuggingPriority:250 forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentHuggingPriority:251 forAxis:UILayoutConstraintAxisVertical];
        isim_ui_text_install(self);
    }
    return self;
}
- (NSString *)text { return _storage; }
- (void)setText:(NSString *)t {
    t = t ?: @"";
    if ([t isEqualToString:_storage]) return;
    _storage = [t copy]; _sel = NSMakeRange(_storage.length, 0);
    isim_ui_set_marked_range(self, NSMakeRange(NSNotFound, 0));
    [self _changed];
}
- (void)setPlaceholder:(NSString *)p { _placeholder = [p copy]; [self _changed]; }
- (void)setFont:(UIFont *)f { _font = f ?: [UIFont systemFontOfSize:17]; [self _changed]; }
- (void)setTextColor:(UIColor *)c { _textColor = c ?: UIColor.labelColor; isim_ui_set_needs_display(); }
- (void)setBorderStyle:(UITextBorderStyle)b { _borderStyle = b; [self _changed]; }
- (void)_changed { [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (BOOL)isEditing { return _editing; }
- (BOOL)hasText { return _storage.length > 0; }
- (BOOL)canBecomeFirstResponder { return self.enabled; }
- (NSString *)_isim_dumpText {
    NSString *t = [NSString stringWithFormat:@"\"%@\"%@", _storage, self.isFirstResponder ? @" (editing)" : @""];
    if (self.isFirstResponder && (_sel.length || _sel.location != _storage.length)) t = [t stringByAppendingFormat:@" selection %lu+%lu", (unsigned long)_sel.location, (unsigned long)_sel.length];
    NSRange m = isim_ui_marked_range(self);
    if (m.location != NSNotFound) t = [t stringByAppendingFormat:@" marked %lu+%lu", (unsigned long)m.location, (unsigned long)m.length];
    return t;
}

/* multi-line (private, SwiftUI) */
- (BOOL)_multiline { return _isim_multi && _isim_maxLines != 1; }

/* ---- editing ---- */
- (BOOL)becomeFirstResponder {
    if (self.isFirstResponder) return YES;
    id<UITextFieldDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textFieldShouldBeginEditing:)] && ![d textFieldShouldBeginEditing:self]) return NO;
    if (![super becomeFirstResponder]) return NO;
    _editing = YES;
    if (_clearsOnBeginEditing) _storage = @"";
    _sel = NSMakeRange(_storage.length, 0);
    if ([d respondsToSelector:@selector(textFieldDidBeginEditing:)]) [d textFieldDidBeginEditing:self];
    [self _isim_sendEvents:UIControlEventEditingDidBegin withEvent:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextFieldTextDidBeginEditingNotification object:self];
    isim_ui_set_needs_display();
    return YES;
}
- (BOOL)resignFirstResponder {
    if (!self.isFirstResponder) return YES;
    id<UITextFieldDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textFieldShouldEndEditing:)] && ![d textFieldShouldEndEditing:self]) return NO;
    [super resignFirstResponder];
    _editing = NO;
    isim_ui_text_did_end_editing(self);
    _sel = NSMakeRange(_storage.length, 0); _scrollX = 0;
    if ([d respondsToSelector:@selector(textFieldDidEndEditing:)]) [d textFieldDidEndEditing:self];
    [self _isim_sendEvents:UIControlEventEditingDidEnd withEvent:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextFieldTextDidEndEditingNotification object:self];
    isim_ui_set_needs_display();
    return YES;
}
/* IsimEditableText */
- (NSString *)_isim_plainText { return _storage; }
- (NSRange)_isim_selectedRange { return _sel; }
- (BOOL)_isim_isEditable { return self.enabled; }
- (void)_isim_setSelectedRange:(NSRange)r {
    _sel = r;
    id<UITextFieldDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textFieldDidChangeSelection:)]) [d textFieldDidChangeSelection:self];
    isim_ui_set_needs_display();
}
- (void)_isim_replaceRange:(NSRange)r withText:(NSString *)s {
    id<UITextFieldDelegate> d = _delegate;
    BOOL composing = isim_ui_marked_range(self).location != NSNotFound;
    if (!composing && [d respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)] &&
        ![d textField:self shouldChangeCharactersInRange:r replacementString:s]) return;
    _storage = [_storage stringByReplacingCharactersInRange:r withString:s];
    _sel = NSMakeRange(r.location + s.length, 0);
    [self _changed];
    [self _isim_sendEvents:UIControlEventEditingChanged withEvent:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextFieldTextDidChangeNotification object:self];
    if ([d respondsToSelector:@selector(textFieldDidChangeSelection:)]) [d textFieldDidChangeSelection:self];
    isim_ui_text_selection_changed(self);
}
- (void)insertText:(NSString *)t {
    if ([t isEqualToString:@"\n"] && ![self _multiline]) {
        isim_ti_unmark(self);
        id<UITextFieldDelegate> d = _delegate;
        BOOL ret = [d respondsToSelector:@selector(textFieldShouldReturn:)] ? [d textFieldShouldReturn:self] : YES;
        if (ret) [self _isim_sendEvents:UIControlEventEditingDidEndOnExit withEvent:nil];
        return;
    }
    isim_ti_insert(self, t);
}
- (void)deleteBackward { isim_ti_delete_backward(self); }
ISIM_TEXT_INPUT_METHODS
/* a password form leaving the screen (submitted): AutoFill may offer to save the password (UITextServices.m) */
- (void)willMoveToWindow:(UIWindow *)w {
    [super willMoveToWindow:w];
    if (!w && self.window) isim_ui_autofill_field_leaving(self);
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    [super touchesEnded:touches withEvent:e];
    UITouch *t = touches.anyObject;
    CGPoint p = [t locationInView:self];
    if (!CGRectContainsPoint(self.bounds, p)) return;
    if (_editing && [self _showsClear] && p.x > self.bounds.size.width - 30) {
        id<UITextFieldDelegate> d = _delegate;
        if (![d respondsToSelector:@selector(textFieldShouldClear:)] || [d textFieldShouldClear:self]) [self _isim_replaceRange:NSMakeRange(0, _storage.length) withText:@""];
        return;
    }
    [self becomeFirstResponder];
}

/* ---- geometry ---- */
- (UIEdgeInsets)_insets {
    switch (_borderStyle) {
    case UITextBorderStyleRoundedRect: return UIEdgeInsetsMake(7, 8, 7, 8);
    case UITextBorderStyleLine: case UITextBorderStyleBezel: return UIEdgeInsetsMake(4, 4, 4, 4);
    default: return UIEdgeInsetsZero;
    }
}
- (BOOL)_showsClear {
    switch (_clearButtonMode) {
    case UITextFieldViewModeAlways: return _storage.length > 0;
    case UITextFieldViewModeWhileEditing: return _editing && _storage.length > 0;
    case UITextFieldViewModeUnlessEditing: return !_editing && _storage.length > 0;
    default: return NO;
    }
}
- (NSString *)_shown {
    if (!_secureTextEntry) return _storage;
    NSMutableString *m = [NSMutableString string];
    for (NSUInteger i = 0; i < _storage.length; i++) [m appendString:@"•"];
    return m;
}
- (CGFloat)_lineHeight { return ceil(_font.lineHeight); }
- (CGSize)_textSizeForWidth:(CGFloat)w {
    NSString *s = _storage.length ? [self _shown] : (_placeholder ?: @"");
    if (![self _multiline]) return isim_ui_measure(s.length ? s : @" ", _font, 0, 1);
    CGSize m = isim_ui_measure(s.length ? s : @" ", _font, w, _isim_maxLines);
    NSInteger minL = MAX(1, _isim_minLines);
    m.height = MAX(m.height, minL * [self _lineHeight]);
    return m;
}
- (CGSize)intrinsicContentSize {
    UIEdgeInsets in = [self _insets];
    CGFloat w = self.bounds.size.width > 0 ? self.bounds.size.width - in.left - in.right : 0;
    CGSize s = [self _textSizeForWidth:w];
    return CGSizeMake(ceil(s.width) + in.left + in.right + 2, ceil(MAX(s.height, [self _lineHeight])) + in.top + in.bottom);
}
- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)w {
    if (![self _multiline] || w <= 0) return [self intrinsicContentSize];
    UIEdgeInsets in = [self _insets];
    CGSize s = [self _textSizeForWidth:w - in.left - in.right];
    return CGSizeMake(ceil(s.width) + in.left + in.right + 2, ceil(s.height) + in.top + in.bottom);
}
- (CGSize)sizeThatFits:(CGSize)size { return [self _isim_intrinsicSizeForWidth:size.width]; }

/* text layout: the text area, and where character index i sits (top-left of its caret) */
- (CGRect)_textArea {
    CGRect r = UIEdgeInsetsInsetRect(self.bounds, [self _insets]);
    if ([self _showsClear]) r.size.width -= 26;
    return r;
}
- (CGFloat)_lineTop {          /* single line: vertically centred */
    CGRect r = [self _textArea];
    CGSize ts = isim_ui_measure(@" ", _font, 0, 1);
    return r.origin.y + floor((r.size.height - ts.height) / 2);
}
- (CGFloat)_alignOffset:(CGFloat)textW area:(CGFloat)w {
    if (textW >= w) return 0;
    NSTextAlignment al = [self _isim_alignment];
    return al == NSTextAlignmentCenter ? (w - textW) / 2 : al == NSTextAlignmentRight ? w - textW : 0;
}
- (CGPoint)_caretPointFor:(NSUInteger)i {
    NSString *s = [self _shown];
    CGRect r = [self _textArea];
    i = MIN(i, s.length);
    if ([self _multiline]) {
        if (!i) return r.origin;
        NSString *prefix = [s substringToIndex:i];
        CGPoint p = isim_ui_text_end_point(prefix, _font, r.size.width);
        if ([prefix hasSuffix:@"\n"] && p.x > 0.5) p = CGPointMake(0, p.y + [self _lineHeight]);
        return CGPointMake(r.origin.x + p.x, r.origin.y + p.y);
    }
    CGFloat full = s.length ? isim_ui_measure(s, _font, 0, 1).width : 0;
    CGFloat x = i ? isim_ui_measure([s substringToIndex:i], _font, 0, 1).width : 0;
    return CGPointMake(r.origin.x + [self _alignOffset:full area:r.size.width - 2] + x - _scrollX, [self _lineTop]);
}
- (CGRect)_isim_caretRectForIndex:(NSUInteger)i {
    CGPoint p = [self _caretPointFor:i];
    return CGRectMake(p.x, p.y + 1, 2, [self _lineHeight] - 2);
}
- (NSUInteger)_isim_indexAtPoint:(CGPoint)p {
    NSString *s = [self _shown];
    CGFloat lh = [self _lineHeight];
    NSUInteger lo = 0, hi = s.length;
    BOOL multi = [self _multiline];
    CGFloat line = multi ? floor((p.y - [self _textArea].origin.y) / lh) : 0;
    if (multi && line < 0) return 0;
    while (lo < hi) {
        NSUInteger mid = (lo + hi) / 2;
        CGPoint c = [self _caretPointFor:mid];
        CGFloat cl = multi ? floor((c.y - [self _textArea].origin.y + lh / 2) / lh) : 0;
        if (cl < line || (cl == line && c.x < p.x)) lo = mid + 1; else hi = mid;
    }
    if (lo > 0) {
        CGPoint a = [self _caretPointFor:lo - 1], b = [self _caretPointFor:lo];
        CGFloat bl = multi ? floor((b.y - [self _textArea].origin.y + lh / 2) / lh) : 0;
        if (bl != line || fabs(a.x - p.x) < fabs(b.x - p.x)) lo--;
    }
    if (lo < _storage.length) lo = [_storage rangeOfComposedCharacterSequenceAtIndex:lo].location;
    return MIN(lo, _storage.length);
}
- (NSArray<NSValue *> *)_isim_selectionRectsForRange:(NSRange)r {
    NSMutableArray *out = [NSMutableArray array];
    if (NSMaxRange(r) > _storage.length) return out;
    CGPoint a = [self _caretPointFor:r.location], b = [self _caretPointFor:NSMaxRange(r)];
    CGFloat lh = [self _lineHeight];
    if (fabs(a.y - b.y) < 1) { [out addObject:[NSValue valueWithCGRect:CGRectMake(a.x, a.y, b.x - a.x, lh)]]; return out; }
    CGRect area = [self _textArea];
    [out addObject:[NSValue valueWithCGRect:CGRectMake(a.x, a.y, CGRectGetMaxX(area) - a.x, lh)]];
    for (CGFloat y = a.y + lh; y < b.y - 0.5; y += lh) [out addObject:[NSValue valueWithCGRect:CGRectMake(area.origin.x, y, area.size.width, lh)]];
    [out addObject:[NSValue valueWithCGRect:CGRectMake(area.origin.x, b.y, b.x - area.origin.x, lh)]];
    return out;
}
/* single line: scroll so the caret (the moving end of the selection) stays inside the field */
- (void)_keepCaretVisible {
    if ([self _multiline] || !_editing) { _scrollX = 0; return; }
    CGRect r = [self _textArea];
    NSString *s = [self _shown];
    CGFloat full = s.length ? isim_ui_measure(s, _font, 0, 1).width : 0;
    if (full <= r.size.width - 2) { _scrollX = 0; return; }
    CGFloat x = NSMaxRange(_sel) ? isim_ui_measure([s substringToIndex:MIN(NSMaxRange(_sel), s.length)], _font, 0, 1).width : 0;
    if (x - _scrollX > r.size.width - 2) _scrollX = x - r.size.width + 2;
    if (x - _scrollX < 0) _scrollX = x;
    _scrollX = fmax(0, fmin(_scrollX, full - r.size.width + 2));
}

/* ---- drawing ---- */
- (void)_isim_drawContent {
    CGRect b = self.bounds;
    if (_borderStyle == UITextBorderStyleRoundedRect) {
        double bg[4], line[4];
        isim_ui_rgba(self.backgroundColor ? UIColor.clearColor : UIColor.systemBackgroundColor, bg);
        isim_ui_rgba(UIColor.separatorColor, line);
        if (bg[3] > 0) isim_gfx_fill_rounded(0, 0, b.size.width, b.size.height, 5, bg);
        isim_gfx_stroke_rounded(0.25, 0.25, b.size.width - 0.5, b.size.height - 0.5, 5, 0.5, line);
    } else if (_borderStyle == UITextBorderStyleLine || _borderStyle == UITextBorderStyleBezel) {
        double line[4]; isim_ui_rgba(UIColor.labelColor, line);
        isim_gfx_stroke_rounded(0.5, 0.5, b.size.width - 1, b.size.height - 1, 0, 1, line);
    }
    if (isim_ui_autofill_strong(self)) {                 /* an AutoFill strong password: the field turns yellow */
        double y[4]; isim_ui_rgba([UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
            return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithRed:0.36 green:0.33 blue:0.08 alpha:1] : [UIColor colorWithRed:1 green:0.96 blue:0.66 alpha:1]; }], y);
        isim_gfx_fill_rounded(0, 0, b.size.width, b.size.height, _borderStyle == UITextBorderStyleRoundedRect ? 5 : 0, y);
    }
    [self _keepCaretVisible];
    CGRect r = [self _textArea];
    BOOL multi = [self _multiline];
    NSString *shown = [self _shown];
    BOOL placeholder = shown.length == 0;
    NSString *text = placeholder ? (_placeholder ?: @"") : shown;
    isim_gfx_save();
    isim_gfx_clip_rounded(r.origin.x - 1, 0, r.size.width + 3, b.size.height, 0);
    if (!placeholder) isim_ui_text_draw_selection_rects(self);
    if (text.length) {
        CGRect dr;
        if (multi) dr = r;
        else {
            CGSize ts = isim_ui_measure(text, _font, 0, 1);
            CGFloat x = placeholder ? r.origin.x + [self _alignOffset:ts.width area:r.size.width] : [self _caretPointFor:0].x;
            dr = CGRectMake(x, [self _lineTop], MAX(ts.width, r.size.width) + 4, ts.height);
        }
        UIColor *c = placeholder ? UIColor.placeholderTextColor : _textColor;
        isim_ui_draw_text(text, _font, c, dr, multi ? [self _isim_alignment] : NSTextAlignmentLeft, multi ? _isim_maxLines : 1, self.enabled ? 1 : 0.5);
    }
    if (_editing) {
        if (placeholder) {
            CGSize ts = isim_ui_measure(text.length ? text : @" ", _font, 0, 1);
            CGFloat cx = multi ? r.origin.x : r.origin.x + ([self _isim_alignment] == NSTextAlignmentCenter ? (r.size.width - (text.length ? ts.width : 0)) / 2 : [self _isim_alignment] == NSTextAlignmentRight ? r.size.width - 2 : 0);
            double tint[4]; isim_ui_rgba(self.tintColor, tint);
            isim_gfx_fill_rounded(cx, (multi ? r.origin.y : [self _lineTop]) + 1, 2, [self _lineHeight] - 2, 1, tint);
        } else {
            isim_ui_text_draw_spelling(self);
            isim_ui_text_draw_selection(self);
        }
    }
    isim_gfx_restore();
    if ([self _showsClear]) {
        UIEdgeInsets in = [self _insets];
        double c[4]; isim_ui_rgba(UIColor.tertiaryLabelColor, c);
        CGFloat x = b.size.width - in.right - 19, y = floor((b.size.height - 19) / 2);
        isim_gfx_fill_ellipse(x, y, 19, 19, c);
        double w[4]; isim_ui_rgba(UIColor.systemBackgroundColor, w);
        isim_path_begin(); isim_path_move(x + 6, y + 6); isim_path_line(x + 13, y + 13); isim_path_move(x + 13, y + 6); isim_path_line(x + 6, y + 13);
        isim_path_stroke(1.6, w);
    }
}
@end
