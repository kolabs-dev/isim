/* UITextView: multi-line plain text in a vertically scrolling UIScrollView (UIKeyInput).
 * Editable text views bring up isim's system keyboard when they become first responder; the
 * hardware keyboard and ISIM_SCRIPT "type"/"key" edit them too. The caret sits at selectedRange
 * (a tap places it at the nearest character); insertions replace the selected range. The caret does
 * not blink (stable screenshots). With isScrollEnabled = false the view sizes itself to its text
 * (Auto Layout self-sizing), like UIKit. Defaults follow UIKit: 12 pt system font, insets 8/0/8/0,
 * line fragment padding 5. */
#import "UITextInputImpl.h"
#import <UIKit/UITextView.h>
#include <math.h>

NSNotificationName const UITextViewTextDidBeginEditingNotification = @"UITextViewTextDidBeginEditingNotification";
NSNotificationName const UITextViewTextDidChangeNotification = @"UITextViewTextDidChangeNotification";
NSNotificationName const UITextViewTextDidEndEditingNotification = @"UITextViewTextDidEndEditingNotification";

#define PAD 5.0     /* NSTextContainer.lineFragmentPadding */

@interface UITextView () <IsimEditableText>
@end
@implementation UITextView {
    NSString *_storage;
    CGFloat _measuredWidth;
    NSArray<NSTextCheckingResult *> *_items; NSString *_itemsText; UIDataDetectorTypes _itemsTypes;
}
@dynamic delegate;
@synthesize autocapitalizationType = _autocapitalizationType, autocorrectionType = _autocorrectionType, spellCheckingType = _spellCheckingType,
    keyboardType = _keyboardType, keyboardAppearance = _keyboardAppearance, returnKeyType = _returnKeyType,
    enablesReturnKeyAutomatically = _enablesReturnKeyAutomatically, secureTextEntry = _secureTextEntry, textContentType = _textContentType,
    inputView = _inputView, inputAccessoryView = _inputAccessoryView,
    smartQuotesType = _smartQuotesType, smartDashesType = _smartDashesType, smartInsertDeleteType = _smartInsertDeleteType,
    inlinePredictionType = _inlinePredictionType, passwordRules = _passwordRules;

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
        isim_ui_text_install(self);
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
    isim_ui_set_marked_range(self, NSMakeRange(NSNotFound, 0));
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
    NSString *sel = _selectedRange.length ? [NSString stringWithFormat:@" selection %lu+%lu", (unsigned long)_selectedRange.location, (unsigned long)_selectedRange.length] : @"";
    NSRange m = isim_ui_marked_range(self);
    if (m.location != NSNotFound) sel = [sel stringByAppendingFormat:@" marked %lu+%lu", (unsigned long)m.location, (unsigned long)m.length];
    return [NSString stringWithFormat:@"\"%@\"%@%@ offset %g, content %g", t, self.isFirstResponder ? @" (editing)" : @"", sel, self.contentOffset.y, self.contentSize.height];
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
    if (lo < _storage.length) {                          /* (an empty text has no character to snap to) */
        NSRange r = [_storage rangeOfComposedCharacterSequenceAtIndex:lo];
        if (lo != r.location) lo = r.location;
    }
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
    isim_ui_text_did_end_editing(self);
    if ([d respondsToSelector:@selector(textViewDidEndEditing:)]) [d textViewDidEndEditing:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidEndEditingNotification object:self];
    isim_ui_set_needs_display();
    return YES;
}
- (void)_isim_tvReplace:(NSRange)r with:(NSString *)s {
    id<UITextViewDelegate> d = self.delegate;
    BOOL composing = isim_ui_marked_range(self).location != NSNotFound;
    if (!composing && [d respondsToSelector:@selector(textView:shouldChangeTextInRange:replacementText:)] && ![d textView:self shouldChangeTextInRange:r replacementText:s]) return;
    _storage = [_storage stringByReplacingCharactersInRange:r withString:s];
    _selectedRange = NSMakeRange(r.location + s.length, 0);
    [self _isim_tvChanged];
    if ([d respondsToSelector:@selector(textViewDidChange:)]) [d textViewDidChange:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidChangeNotification object:self];
    if ([d respondsToSelector:@selector(textViewDidChangeSelection:)]) [d textViewDidChangeSelection:self];
    [self _isim_tvScrollToCaret];
    isim_ui_text_selection_changed(self);
}
- (void)insertText:(NSString *)t {
    if (!_editable || !t.length) return;
    isim_ti_insert(self, t);
}
- (void)deleteBackward { if (_editable) isim_ti_delete_backward(self); }
/* IsimEditableText (view coordinates = content coordinates) */
- (NSString *)_isim_plainText { return _storage; }
- (NSRange)_isim_selectedRange { return _selectedRange; }
- (BOOL)_isim_isEditable { return _editable; }
- (void)_isim_setSelectedRange:(NSRange)r {
    _selectedRange = r;
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textViewDidChangeSelection:)]) [d textViewDidChangeSelection:self];
    [self _isim_tvScrollToCaret];
    isim_ui_set_needs_display();
}
- (void)_isim_replaceRange:(NSRange)r withText:(NSString *)t { if (_editable) [self _isim_tvReplace:r with:t ?: @""]; }
- (CGRect)_isim_caretRectForIndex:(NSUInteger)i {
    CGPoint o = [self _isim_tvTextOrigin], c = [self _isim_tvCaretFor:MIN(i, _storage.length)];
    return CGRectMake(o.x + c.x - 1, o.y + c.y + 1, 2, ceil(_font.lineHeight) - 2);
}
- (NSUInteger)_isim_indexAtPoint:(CGPoint)p { return [self _isim_tvIndexAt:p]; }
- (NSArray<NSValue *> *)_isim_selectionRectsForRange:(NSRange)r {
    NSMutableArray *out = [NSMutableArray array];
    if (NSMaxRange(r) > _storage.length) return out;
    CGPoint o = [self _isim_tvTextOrigin], a = [self _isim_tvCaretFor:r.location], b = [self _isim_tvCaretFor:NSMaxRange(r)];
    CGFloat lh = ceil(_font.lineHeight), w = [self _isim_tvTextWidthFor:self.bounds.size.width];
    if (fabs(a.y - b.y) < 1) { [out addObject:[NSValue valueWithCGRect:CGRectMake(o.x + a.x, o.y + a.y, b.x - a.x, lh)]]; return out; }
    [out addObject:[NSValue valueWithCGRect:CGRectMake(o.x + a.x, o.y + a.y, w - a.x, lh)]];
    for (CGFloat y = a.y + lh; y < b.y - 0.5; y += lh) [out addObject:[NSValue valueWithCGRect:CGRectMake(o.x, o.y + y, w, lh)]];
    [out addObject:[NSValue valueWithCGRect:CGRectMake(o.x, o.y + b.y, b.x, lh)]];
    return out;
}
ISIM_TEXT_INPUT_METHODS
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

/* ---- detected items (dataDetectorTypes; not editable, selectable): UITextServices.m ---- */
- (void)setDataDetectorTypes:(UIDataDetectorTypes)t { _dataDetectorTypes = t; isim_ui_set_needs_display(); }
- (NSArray<NSTextCheckingResult *> *)_isim_items {
    if (_editable || !_selectable || !_dataDetectorTypes || _secureTextEntry) return @[];
    if (!_items || _itemsTypes != _dataDetectorTypes || ![_itemsText isEqualToString:_storage]) {
        _items = isim_ui_detect_items(_storage, _dataDetectorTypes);
        _itemsText = _storage; _itemsTypes = _dataDetectorTypes;
    }
    return _items;
}
/* an item's pieces, one per line: (character range, rect in content coordinates) */
- (void)_isim_itemPieces:(NSRange)r each:(void (^)(NSRange piece, CGRect rect))each {
    CGPoint o = [self _isim_tvTextOrigin];
    CGFloat lh = ceil(_font.lineHeight);
    NSUInteger start = r.location;
    CGPoint a = [self _isim_tvCaretFor:start];
    for (NSUInteger i = r.location + 1; i <= NSMaxRange(r); i++) {
        CGPoint c = [self _isim_tvCaretFor:i];
        BOOL wrapped = c.y > a.y + 0.5 && i < NSMaxRange(r);
        if (wrapped || i == NSMaxRange(r)) {
            NSUInteger end = wrapped ? i - 1 : i;
            CGPoint e = wrapped ? [self _isim_tvCaretFor:end] : c;
            if (e.y > a.y + 0.5) e = CGPointMake([self _isim_tvTextWidthFor:self.bounds.size.width], a.y);
            if (end > start) each(NSMakeRange(start, end - start), CGRectMake(o.x + a.x, o.y + a.y, e.x - a.x, lh));
            if (wrapped) { start = end; a = [self _isim_tvCaretFor:start]; if (a.y < c.y - 0.5) a = CGPointMake(0, c.y); }
        }
    }
}
- (NSTextCheckingResult *)_isim_itemAt:(CGPoint)p {
    __block NSTextCheckingResult *hit = nil;
    for (NSTextCheckingResult *r in [self _isim_items]) {
        [self _isim_itemPieces:r.range each:^(NSRange piece, CGRect rect) { if (CGRectContainsPoint(CGRectInset(rect, -2, -4), p)) hit = r; }];
        if (hit) break;
    }
    return hit;
}
- (BOOL)_isim_tapItemAt:(CGPoint)p {
    NSTextCheckingResult *r = [self _isim_itemAt:p];
    return r && isim_ui_text_item_tap(self, r);
}
- (BOOL)_isim_longPressItemAt:(CGPoint)p {
    NSTextCheckingResult *r = [self _isim_itemAt:p];
    if (!r) return NO;
    __block CGRect box = CGRectNull;
    [self _isim_itemPieces:r.range each:^(NSRange piece, CGRect rect) { box = CGRectUnion(box, rect); }];
    return isim_ui_text_item_menu(self, r, [self convertRect:box toView:nil]);
}
/* items are drawn over the text in the tint colour, underlined (the text under them is covered first) */
- (void)_isim_drawItems {
    NSArray *items = [self _isim_items];
    if (!items.count) return;
    UIColor *bg = nil;
    for (UIView *v = self; v && !bg; v = v.superview) { double c[4]; if (v.backgroundColor) { isim_ui_rgba(v.backgroundColor, c); if (c[3] > 0.99) bg = v.backgroundColor; } }
    double back4[4], tint4[4];
    isim_ui_rgba(bg ?: UIColor.systemBackgroundColor, back4);
    isim_ui_rgba(self.tintColor, tint4);
    double *back = back4, *tint = tint4;
    UIColor *tc = self.tintColor;
    CGPoint off = self.contentOffset;
    for (NSTextCheckingResult *r in items)
        [self _isim_itemPieces:r.range each:^(NSRange piece, CGRect rect) {
            CGRect d = CGRectOffset(rect, -off.x, -off.y);
            isim_gfx_fill_rounded(d.origin.x, d.origin.y, d.size.width + 1, d.size.height, 0, back);
            isim_ui_draw_text([_storage substringWithRange:piece], _font, tc, CGRectMake(d.origin.x, d.origin.y, d.size.width + 20, d.size.height), NSTextAlignmentLeft, 1, 1);
            isim_gfx_fill_rounded(d.origin.x, d.origin.y + ceil(_font.ascender) + 2, d.size.width, 1, 0, tint);
        }];
}

/* ---- drawing (content coordinates are shifted by the scroll offset) ---- */
- (void)_isim_drawContent {
    CGPoint off = self.contentOffset, o = [self _isim_tvTextOrigin];
    CGFloat w = [self _isim_tvTextWidthFor:self.bounds.size.width];
    NSString *s = [self _isim_tvShown];
    CGFloat x = o.x - off.x, y = o.y - off.y;
    isim_gfx_save(); isim_gfx_translate(-off.x, -off.y);
    isim_ui_text_draw_selection_rects(self);
    isim_gfx_restore();
    if (s.length) {
        CGFloat h = isim_ui_measure(s, _font, w, 0).height;
        isim_ui_draw_text(s, _font, _textColor, CGRectMake(x, y, w, h), _textAlignment, 0, 1);
    }
    [self _isim_drawItems];
    isim_gfx_save(); isim_gfx_translate(-off.x, -off.y);
    isim_ui_text_draw_spelling(self);
    isim_ui_text_draw_selection(self);
    isim_gfx_restore();
}
@end

@implementation UIView (UITextFieldEditing)
- (BOOL)endEditing:(BOOL)force {
    UIResponder *fr = isim_ui_first_responder();
    if (![fr isKindOfClass:[UIView class]] || ![(UIView *)fr isDescendantOfView:self]) return YES;
    return [fr resignFirstResponder] || force;
}
@end
