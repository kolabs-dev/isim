/* UITextField: single-line text input (UIKeyInput) with the caret at the end of the text.
 * Becoming first responder brings up isim's system keyboard (UIKeyboard.m); the hardware keyboard
 * and ISIM_SCRIPT "type"/"key" also edit it. A private multi-line mode (_isim_minLines/_isim_maxLines)
 * backs SwiftUI's TextField(axis: .vertical). The caret does not blink (stable screenshots). */
#import "UIKitPrivate.h"
#include <math.h>

NSNotificationName const UITextFieldTextDidBeginEditingNotification = @"UITextFieldTextDidBeginEditingNotification";
NSNotificationName const UITextFieldTextDidEndEditingNotification = @"UITextFieldTextDidEndEditingNotification";
NSNotificationName const UITextFieldTextDidChangeNotification = @"UITextFieldTextDidChangeNotification";

@implementation UITextField {
    NSString *_storage;
    BOOL _editing;
    NSInteger _isim_minLines, _isim_maxLines; BOOL _isim_multi;
}
- (void)_isim_setLineLimitMin:(NSInteger)minLines max:(NSInteger)maxLines { _isim_minLines = minLines; _isim_maxLines = maxLines; _isim_multi = YES; [self _changed]; }
@synthesize autocapitalizationType = _autocapitalizationType, autocorrectionType = _autocorrectionType, spellCheckingType = _spellCheckingType,
    keyboardType = _keyboardType, keyboardAppearance = _keyboardAppearance, returnKeyType = _returnKeyType,
    enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically, secureTextEntry = _secureTextEntry, textContentType = _textContentType;
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _storage = @""; _font = [UIFont systemFontOfSize:17]; _textColor = UIColor.labelColor;
        _textAlignment = NSTextAlignmentNatural; _autocapitalizationType = UITextAutocapitalizationTypeSentences;
        [self setContentHuggingPriority:250 forAxis:UILayoutConstraintAxisHorizontal];
        [self setContentHuggingPriority:251 forAxis:UILayoutConstraintAxisVertical];
    }
    return self;
}
- (NSString *)text { return _storage; }
- (void)setText:(NSString *)t { t = t ?: @""; if ([t isEqualToString:_storage]) return; _storage = [t copy]; [self _changed]; }
- (void)setPlaceholder:(NSString *)p { _placeholder = [p copy]; [self _changed]; }
- (void)setFont:(UIFont *)f { _font = f ?: [UIFont systemFontOfSize:17]; [self _changed]; }
- (void)setTextColor:(UIColor *)c { _textColor = c ?: UIColor.labelColor; isim_ui_set_needs_display(); }
- (void)setBorderStyle:(UITextBorderStyle)b { _borderStyle = b; [self _changed]; }
- (void)_changed { [self invalidateIntrinsicContentSize]; isim_ui_set_needs_display(); }
- (BOOL)isEditing { return _editing; }
- (BOOL)hasText { return _storage.length > 0; }
- (BOOL)canBecomeFirstResponder { return self.enabled; }

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
    if ([d respondsToSelector:@selector(textFieldDidEndEditing:)]) [d textFieldDidEndEditing:self];
    [self _isim_sendEvents:UIControlEventEditingDidEnd withEvent:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextFieldTextDidEndEditingNotification object:self];
    isim_ui_set_needs_display();
    return YES;
}
- (void)_replace:(NSRange)r with:(NSString *)s {
    id<UITextFieldDelegate> d = _delegate;
    if ([d respondsToSelector:@selector(textField:shouldChangeCharactersInRange:replacementString:)] &&
        ![d textField:self shouldChangeCharactersInRange:r replacementString:s]) return;
    _storage = [_storage stringByReplacingCharactersInRange:r withString:s];
    [self _changed];
    [self _isim_sendEvents:UIControlEventEditingChanged withEvent:nil];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextFieldTextDidChangeNotification object:self];
    if ([d respondsToSelector:@selector(textFieldDidChangeSelection:)]) [d textFieldDidChangeSelection:self];
}
- (void)insertText:(NSString *)t {
    if ([t isEqualToString:@"\n"] && ![self _multiline]) {
        id<UITextFieldDelegate> d = _delegate;
        BOOL ret = [d respondsToSelector:@selector(textFieldShouldReturn:)] ? [d textFieldShouldReturn:self] : YES;
        if (ret) [self _isim_sendEvents:UIControlEventEditingDidEndOnExit withEvent:nil];
        return;
    }
    [self _replace:NSMakeRange(_storage.length, 0) with:t];
}
- (void)deleteBackward {
    if (!_storage.length) return;
    NSRange r = [_storage rangeOfComposedCharacterSequenceAtIndex:_storage.length - 1];
    [self _replace:r with:@""];
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    [super touchesEnded:touches withEvent:e];
    UITouch *t = touches.anyObject;
    CGPoint p = [t locationInView:self];
    if (!CGRectContainsPoint(self.bounds, p)) return;
    if (_editing && [self _showsClear] && p.x > self.bounds.size.width - 30) {
        id<UITextFieldDelegate> d = _delegate;
        if (![d respondsToSelector:@selector(textFieldShouldClear:)] || [d textFieldShouldClear:self]) [self _replace:NSMakeRange(0, _storage.length) with:@""];
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
    UIEdgeInsets in = [self _insets];
    CGRect r = UIEdgeInsetsInsetRect(b, in);
    if ([self _showsClear]) r.size.width -= 26;
    BOOL multi = [self _multiline];
    NSString *shown = [self _shown];
    BOOL placeholder = shown.length == 0;
    NSString *text = placeholder ? (_placeholder ?: @"") : shown;
    CGSize ts = isim_ui_measure(text.length ? text : @" ", _font, multi ? r.size.width : 0, multi ? _isim_maxLines : 1);
    CGRect tr = r;
    if (!multi) { tr.origin.y = r.origin.y + floor((r.size.height - ts.height) / 2); tr.size.height = ts.height; }
    CGFloat shift = 0;
    if (!multi && _editing && ts.width > r.size.width - 2) shift = ts.width - r.size.width + 2;   /* keep the caret visible */
    isim_gfx_save();
    isim_gfx_clip_rounded(r.origin.x, 0, r.size.width + 1, b.size.height, 0);
    if (text.length) {
        CGRect dr = tr; dr.origin.x -= shift; dr.size.width += shift;
        UIColor *c = placeholder ? UIColor.placeholderTextColor : _textColor;
        isim_ui_draw_text(text, _font, c, dr, shift > 0 ? NSTextAlignmentLeft : _textAlignment, multi ? _isim_maxLines : 1, self.enabled ? 1 : 0.5);
    }
    if (_editing) {
        /* caret after the last character */
        CGFloat cx, cy;
        if (placeholder) { cx = _textAlignment == NSTextAlignmentCenter ? CGRectGetMidX(r) : _textAlignment == NSTextAlignmentRight ? CGRectGetMaxX(r) - 2 : r.origin.x; cy = tr.origin.y; }
        else if (multi) {
            CGPoint end = isim_ui_text_end_point(shown, _font, r.size.width);
            cx = r.origin.x + end.x; cy = r.origin.y + end.y;
        } else {
            CGFloat w = MIN(ts.width, r.size.width - 2);
            cx = _textAlignment == NSTextAlignmentCenter ? CGRectGetMidX(r) + w / 2 : _textAlignment == NSTextAlignmentRight ? CGRectGetMaxX(r) - 1 : r.origin.x + w;
            cy = tr.origin.y;
        }
        double tint[4]; isim_ui_rgba(self.tintColor, tint);
        isim_gfx_fill_rounded(cx, cy + 1, 2, [self _lineHeight] - 2, 1, tint);
    }
    isim_gfx_restore();
    if ([self _showsClear]) {
        double c[4]; isim_ui_rgba(UIColor.tertiaryLabelColor, c);
        CGFloat x = b.size.width - in.right - 19, y = floor((b.size.height - 19) / 2);
        isim_gfx_fill_ellipse(x, y, 19, 19, c);
        double w[4]; isim_ui_rgba(UIColor.systemBackgroundColor, w);
        isim_path_begin(); isim_path_move(x + 6, y + 6); isim_path_line(x + 13, y + 13); isim_path_move(x + 13, y + 6); isim_path_line(x + 6, y + 13);
        isim_path_stroke(1.6, w);
    }
}
@end
