/* UITextView: multi-line plain text in a vertically scrolling UIScrollView (UIKeyInput).
 * Editable text views bring up isim's system keyboard when they become first responder; the
 * hardware keyboard and ISIM_SCRIPT "type"/"key" edit them too. The caret sits at selectedRange
 * (a tap places it at the nearest character); insertions replace the selected range. The caret does
 * not blink (stable screenshots). With isScrollEnabled = false the view sizes itself to its text
 * (Auto Layout self-sizing), like UIKit. Defaults follow UIKit: 12 pt system font, insets 8/0/8/0,
 * line fragment padding 5. */
#import "UIKitPrivate.h"
#import <UIKit/UITextView.h>
#include <math.h>

NSNotificationName const UITextViewTextDidBeginEditingNotification = @"UITextViewTextDidBeginEditingNotification";
NSNotificationName const UITextViewTextDidChangeNotification = @"UITextViewTextDidChangeNotification";
NSNotificationName const UITextViewTextDidEndEditingNotification = @"UITextViewTextDidEndEditingNotification";

#define PAD 5.0     /* NSTextContainer.lineFragmentPadding */

@implementation UITextView {
    NSString *_storage;
    CGFloat _measuredWidth;
}
@dynamic delegate;
@synthesize autocapitalizationType = _autocapitalizationType, autocorrectionType = _autocorrectionType, spellCheckingType = _spellCheckingType,
    keyboardType = _keyboardType, keyboardAppearance = _keyboardAppearance, returnKeyType = _returnKeyType,
    enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically, secureTextEntry = _secureTextEntry, textContentType = _textContentType,
    inputView = _inputView, inputAccessoryView = _inputAccessoryView;

- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _storage = @""; _font = [UIFont systemFontOfSize:12]; _textColor = UIColor.labelColor;
        _textAlignment = NSTextAlignmentNatural; _editable = YES; _selectable = YES;
        _textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
        _autocapitalizationType = UITextAutocapitalizationTypeSentences;
        self.backgroundColor = UIColor.systemBackgroundColor;
        self.showsHorizontalScrollIndicator = NO;
        self.alwaysBounceHorizontal = NO;
        [self _isim_tvUpdateContent];
    }
    return self;
}

/* ---- text ---- */
- (NSString *)text { return _storage; }
- (void)setText:(NSString *)t {
    t = t ?: @"";
    if ([t isEqualToString:_storage]) return;
    _storage = [t copy];
    _selectedRange = NSMakeRange(_storage.length, 0);
    [self _isim_tvChanged];
}
- (void)setFont:(UIFont *)f { _font = f ?: [UIFont systemFontOfSize:12]; [self _isim_tvChanged]; }
- (void)setTextColor:(UIColor *)c { _textColor = c ?: UIColor.labelColor; isim_ui_set_needs_display(); }
- (void)setTextAlignment:(NSTextAlignment)a { _textAlignment = a; isim_ui_set_needs_display(); }
- (void)setTextContainerInset:(UIEdgeInsets)i { _textContainerInset = i; [self _isim_tvChanged]; }
- (void)setEditable:(BOOL)e { _editable = e; if (!e && self.isFirstResponder) [self resignFirstResponder]; }
- (void)setSelectedRange:(NSRange)r {
    NSUInteger len = _storage.length;
    if (r.location > len) r.location = len;
    if (NSMaxRange(r) > len) r.length = len - r.location;
    _selectedRange = r;
    isim_ui_set_needs_display();
}
- (void)setScrollEnabled:(BOOL)e { [super setScrollEnabled:e]; [self invalidateIntrinsicContentSize]; }
- (BOOL)hasText { return _storage.length > 0; }
- (NSString *)_isim_dumpText {
    NSString *t = [_storage stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    return [NSString stringWithFormat:@"\"%@\"%@ offset %g, content %g", t, self.isFirstResponder ? @" (editing)" : @"", self.contentOffset.y, self.contentSize.height];
}

/* ---- metrics ---- */
- (CGFloat)_isim_tvTextWidthFor:(CGFloat)w { return fmax(1, w - _textContainerInset.left - _textContainerInset.right - 2 * PAD); }
- (NSString *)_isim_tvShown {
    if (!_secureTextEntry) return _storage;
    NSMutableString *m = [NSMutableString string];
    for (NSUInteger i = 0; i < _storage.length; i++) [m appendString:@"•"];
    return m;
}
- (CGFloat)_isim_tvTextHeightFor:(CGFloat)w {
    NSString *s = [self _isim_tvShown];
    CGFloat lh = ceil(_font.lineHeight);
    if (!s.length) return lh;
    CGFloat h = isim_ui_measure(s, _font, [self _isim_tvTextWidthFor:w], 0).height;
    if ([s hasSuffix:@"\n"]) h += lh;                    /* an empty last line still takes a line */
    return fmax(h, lh);
}
- (void)_isim_tvUpdateContent {
    CGFloat w = self.bounds.size.width;
    _measuredWidth = w;
    CGFloat h = [self _isim_tvTextHeightFor:w] + _textContainerInset.top + _textContainerInset.bottom;
    self.contentSize = CGSizeMake(w, ceil(h));
}
- (void)_isim_tvChanged {
    [self _isim_tvUpdateContent];
    if (!self.scrollEnabled) [self invalidateIntrinsicContentSize];
    isim_ui_set_needs_display();
}
/* (content size follows width changes in layoutSubviews, not in setFrame: a frame applied by the Auto Layout
   solver must not scroll synchronously, which would re-enter layout through scroll observers) */
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.bounds.size.width != _measuredWidth) [self _isim_tvUpdateContent];
}
/* not scrolling: the view is as tall as its text (self-sizing) */
- (CGSize)_isim_tvSizeForWidth:(CGFloat)w {
    NSString *s = [self _isim_tvShown];
    CGFloat textW = s.length ? isim_ui_measure(s, _font, 0, 0).width : 0;
    UIEdgeInsets in = _textContainerInset;
    CGFloat width = ceil(textW) + 2 * PAD + in.left + in.right;
    CGFloat height = [self _isim_tvTextHeightFor:w > 0 ? w : width] + in.top + in.bottom;
    return CGSizeMake(width, ceil(height));
}
- (CGSize)intrinsicContentSize {
    if (self.scrollEnabled) return CGSizeMake(UIViewNoIntrinsicMetric, UIViewNoIntrinsicMetric);
    return [self _isim_tvSizeForWidth:self.bounds.size.width];
}
- (CGSize)_isim_intrinsicSizeForWidth:(CGFloat)w {
    if (self.scrollEnabled) return [self intrinsicContentSize];
    return [self _isim_tvSizeForWidth:w];
}
- (BOOL)_isim_heightTracksWidth { return !self.scrollEnabled; }
- (CGSize)sizeThatFits:(CGSize)s { return [self _isim_tvSizeForWidth:s.width > 0 && s.width < 1e5 ? s.width : 0]; }

/* caret position (text coordinates: origin at the first line's top-left) for a character index */
- (CGPoint)_isim_tvCaretFor:(NSUInteger)index {
    NSString *s = [self _isim_tvShown];
    CGFloat w = [self _isim_tvTextWidthFor:self.bounds.size.width];
    if (index == 0 || !s.length) {
        CGFloat x = _textAlignment == NSTextAlignmentCenter ? w / 2 : _textAlignment == NSTextAlignmentRight ? w : 0;
        return CGPointMake(x, 0);
    }
    NSString *prefix = [s substringToIndex:MIN(index, s.length)];
    CGPoint p = isim_ui_text_end_point(prefix, _font, w);
    if ([prefix hasSuffix:@"\n"] && p.x > 0.5) p = CGPointMake(0, p.y + ceil(_font.lineHeight));
    return p;
}
- (CGPoint)_isim_tvTextOrigin { return CGPointMake(_textContainerInset.left + PAD, _textContainerInset.top); }
/* nearest character index for a point in content coordinates (binary search over caret positions) */
- (NSUInteger)_isim_tvIndexAt:(CGPoint)p {
    CGPoint o = [self _isim_tvTextOrigin];
    CGFloat lh = ceil(_font.lineHeight);
    CGFloat x = p.x - o.x, line = floor((p.y - o.y) / lh);
    NSUInteger lo = 0, hi = _storage.length;
    if (line < 0) return 0;
    while (lo < hi) {                                    /* first index whose caret is past (line, x) */
        NSUInteger mid = (lo + hi) / 2;
        CGPoint c = [self _isim_tvCaretFor:mid];
        CGFloat cl = floor((c.y + lh / 2) / lh);
        if (cl < line || (cl == line && c.x < x)) lo = mid + 1; else hi = mid;
    }
    /* pick the closer of lo-1 and lo on the same line */
    if (lo > 0) {
        CGPoint a = [self _isim_tvCaretFor:lo - 1], b = [self _isim_tvCaretFor:lo];
        CGFloat bl = floor((b.y + lh / 2) / lh);
        if (bl != line || fabs(a.x - x) < fabs(b.x - x)) lo = lo - 1;
    }
    NSRange r = [_storage rangeOfComposedCharacterSequenceAtIndex:MIN(lo, _storage.length ? _storage.length - 1 : 0)];
    if (lo < _storage.length && lo != r.location) lo = r.location;
    return lo;
}

/* ---- editing ---- */
- (BOOL)canBecomeFirstResponder { return _editable; }
- (BOOL)becomeFirstResponder {
    if (self.isFirstResponder) return YES;
    if (!_editable) return NO;
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textViewShouldBeginEditing:)] && ![d textViewShouldBeginEditing:self]) return NO;
    if (![super becomeFirstResponder]) return NO;
    if (_clearsOnInsertion) { _storage = @""; _selectedRange = NSMakeRange(0, 0); [self _isim_tvChanged]; }
    if ([d respondsToSelector:@selector(textViewDidBeginEditing:)]) [d textViewDidBeginEditing:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidBeginEditingNotification object:self];
    [self _isim_tvScrollToCaret];
    isim_ui_set_needs_display();
    return YES;
}
- (BOOL)resignFirstResponder {
    if (!self.isFirstResponder) return YES;
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textViewShouldEndEditing:)] && ![d textViewShouldEndEditing:self]) return NO;
    [super resignFirstResponder];
    if ([d respondsToSelector:@selector(textViewDidEndEditing:)]) [d textViewDidEndEditing:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidEndEditingNotification object:self];
    isim_ui_set_needs_display();
    return YES;
}
- (void)_isim_tvReplace:(NSRange)r with:(NSString *)s {
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)] && ![d textView:self shouldChangeTextInRange:r replacementText:s]) return;
    _storage = [_storage stringByReplacingCharactersInRange:r withString:s];
    _selectedRange = NSMakeRange(r.location + s.length, 0);
    [self _isim_tvChanged];
    if ([d respondsToSelector:@selector(textViewDidChange:)]) [d textViewDidChange:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidChangeNotification object:self];
    if ([d respondsToSelector:@selector(textViewDidChangeSelection:)]) [d textViewDidChangeSelection:self];
    [self _isim_tvScrollToCaret];
}
- (void)insertText:(NSString *)t {
    if (!_editable || !t.length) return;
    [self _isim_tvReplace:_selectedRange with:t];
}
- (void)deleteBackward {
    if (!_editable) return;
    NSRange r = _selectedRange;
    if (r.length == 0) {
        if (r.location == 0) return;
        r = [_storage rangeOfComposedCharacterSequenceAtIndex:r.location - 1];
    }
    [self _isim_tvReplace:r with:@""];
}
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    [super touchesEnded:touches withEvent:e];
    if (!_editable && !_selectable) return;
    CGPoint p = [touches.anyObject locationInView:self];           /* content coordinates (bounds origin = offset) */
    if (!CGRectContainsPoint(self.bounds, p)) return;
    NSUInteger i = [self _isim_tvIndexAt:p];
    if (_editable) {
        _selectedRange = NSMakeRange(i, 0);
        id<UITextViewDelegate> d = self.delegate;
        if (self.isFirstResponder && [d respondsToSelector:@selector(textViewDidChangeSelection:)]) [d textViewDidChangeSelection:self];
        [self becomeFirstResponder];
        isim_ui_set_needs_display();
    }
}

/* ---- scrolling ---- */
- (void)_isim_tvScrollToCaret {
    if (!self.scrollEnabled) return;
    CGPoint o = [self _isim_tvTextOrigin], c = [self _isim_tvCaretFor:NSMaxRange(_selectedRange)];
    CGFloat lh = ceil(_font.lineHeight);
    [self scrollRectToVisible:CGRectMake(o.x + c.x, o.y + c.y, 2, lh + _textContainerInset.bottom) animated:NO];
}
- (void)scrollRangeToVisible:(NSRange)r {
    if (r.location > _storage.length) return;
    CGPoint o = [self _isim_tvTextOrigin], a = [self _isim_tvCaretFor:r.location], b = [self _isim_tvCaretFor:MIN(NSMaxRange(r), _storage.length)];
    CGFloat lh = ceil(_font.lineHeight);
    [self scrollRectToVisible:CGRectMake(0, o.y + a.y, self.bounds.size.width, b.y - a.y + lh) animated:NO];
}

/* ---- drawing (content coordinates are shifted by the scroll offset) ---- */
- (void)_isim_drawContent {
    CGPoint off = self.contentOffset, o = [self _isim_tvTextOrigin];
    CGFloat w = [self _isim_tvTextWidthFor:self.bounds.size.width];
    NSString *s = [self _isim_tvShown];
    CGFloat x = o.x - off.x, y = o.y - off.y;
    if (s.length) {
        CGFloat h = isim_ui_measure(s, _font, w, 0).height;
        isim_ui_draw_text(s, _font, _textColor, CGRectMake(x, y, w, h), _textAlignment, 0, 1);
    }
    if (self.isFirstResponder) {
        CGPoint c = [self _isim_tvCaretFor:NSMaxRange(_selectedRange)];
        double tint[4]; isim_ui_rgba(self.tintColor, tint);
        isim_gfx_fill_rounded(x + c.x - 1, y + c.y + 1, 2, ceil(_font.lineHeight) - 2, 1, tint);
    }
}
@end

@implementation UIView (UITextFieldEditing)
- (BOOL)endEditing:(BOOL)force {
    UIResponder *fr = isim_ui_first_responder();
    if (![fr isKindOfClass:[UIView class]] || ![(UIView *)fr isDescendantOfView:self]) return YES;
    return [fr resignFirstResponder] || force;
}
@end
