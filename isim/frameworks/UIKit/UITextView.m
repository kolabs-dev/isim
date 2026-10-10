/* UITextView: multi-line text in a vertically scrolling UIScrollView (UIKeyInput), kept in a TextKit text storage.
 * Editable text views bring up isim's system keyboard when they become first responder; the hardware keyboard and
 * ISIM_SCRIPT "type"/"key" edit them too. The caret sits at selectedRange (a tap places it at the nearest character);
 * insertions replace the selected range and take the typing attributes. The caret does not blink (stable
 * screenshots). With isScrollEnabled = false the view sizes itself to its text (Auto Layout self-sizing), like UIKit.
 * Defaults follow UIKit: 12 pt system font, insets 8/0/8/0, line fragment padding 5.
 *
 * TextKit: the text storage is laid out by an NSTextLayoutManager (TextKit 2, the default) or, once layoutManager is
 * asked for or with init(frame:textContainer:), an NSLayoutManager (TextKit 1); both use isim's TextKit engine
 * (UITextKitEngine.m), which the view draws and hit-tests with. With TextKit 2 the view is its viewport layout
 * controller's delegate: laying out the viewport places attachment views (NSTextAttachmentViewProvider) and, with
 * iOS 27 reuse policies, keeps them across scrolling and paragraph edits. */
#import "UITextInputImpl.h"
#import "UITextKitPrivate.h"
#import <UIKit/UITextView.h>
#import <objc/runtime.h>
#include <math.h>

NSNotificationName const UITextViewTextDidBeginEditingNotification = @"UITextViewTextDidBeginEditingNotification";
NSNotificationName const UITextViewTextDidChangeNotification = @"UITextViewTextDidChangeNotification";
NSNotificationName const UITextViewTextDidEndEditingNotification = @"UITextViewTextDidEndEditingNotification";

@interface UITextView () <IsimEditableText, NSTextStorageDelegate>
@end
@implementation UITextView {
    NSTextStorage *_ts;
    NSTextContainer *_tc;
    NSLayoutManager *_lm;
    NSTextContentStorage *_tcs;
    NSTextLayoutManager *_tlm;
    BOOL _tk1, _updatingStorage;
    NSDictionary *_typing, *_linkAttrs;
    NSMutableDictionary<NSString *, NSNumber *> *_reusePolicies;          /* provider class name -> policy */
    NSMutableArray<NSTextAttachmentViewProvider *> *_placedProviders;
    __IsimTextEngine *_secureEngine; NSString *_secureText;
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

- (instancetype)initWithFrame:(CGRect)f { return [self initIsimWithFrame:f container:nil textKit1:NO]; }
- (instancetype)initWithFrame:(CGRect)f textContainer:(NSTextContainer *)c { return [self initIsimWithFrame:f container:c textKit1:YES]; }
+ (instancetype)textViewUsingTextLayoutManager:(BOOL)tk2 {
    UITextView *v = [[self alloc] initWithFrame:CGRectZero];
    if (!tk2) [v _isimSwitchToTextKit1];
    return v;
}
- (instancetype)initIsimWithFrame:(CGRect)f container:(NSTextContainer *)c textKit1:(BOOL)tk1 {
    if ((self = [super initWithFrame:f])) {
        _font = [UIFont systemFontOfSize:12]; _textColor = UIColor.labelColor;
        _textAlignment = NSTextAlignmentNatural; _editable = YES; _selectable = YES;
        _textContainerInset = UIEdgeInsetsMake(8, 0, 8, 0);
        _autocapitalizationType = UITextAutocapitalizationTypeSentences;
        _typing = @{ NSFontAttributeName: _font, NSForegroundColorAttributeName: _textColor };
        _reusePolicies = [NSMutableDictionary dictionary]; _placedProviders = [NSMutableArray array];
        /* the text container (the caller's for TextKit 1), the storage, and the layout manager */
        _tc = c ?: [[NSTextContainer alloc] initWithSize:CGSizeMake(f.size.width, CGFLOAT_MAX)];
        _tc.widthTracksTextView = YES;
        if (tk1 && c.layoutManager.textStorage) {                 /* a container already in a TextKit 1 stack */
            _lm = c.layoutManager; _ts = _lm.textStorage; _tk1 = YES;
        } else {
            _ts = [NSTextStorage new];
            if (tk1) { _tk1 = YES; _lm = c.layoutManager ?: [NSLayoutManager new]; if (!c.layoutManager) [_lm addTextContainer:_tc]; [_ts addLayoutManager:_lm]; }
            else {
                _tcs = [NSTextContentStorage new]; _tcs.textStorage = _ts;
                _tlm = [NSTextLayoutManager new]; _tlm.textContainer = _tc; [_tcs addTextLayoutManager:_tlm];
                _tlm.textViewportLayoutController.delegate = self;
            }
        }
        _ts.delegate = self;
        self.backgroundColor = UIColor.systemBackgroundColor;
        self.showsHorizontalScrollIndicator = NO;
        self.alwaysBounceHorizontal = NO;
        [self _isim_tvUpdateContent];
        isim_ui_text_install(self);
    }
    return self;
}

/* ---- TextKit ---- */
- (NSTextStorage *)textStorage { return _ts; }
- (NSTextContainer *)textContainer { return _tc; }
- (NSTextLayoutManager *)textLayoutManager { return _tk1 ? nil : _tlm; }
- (NSLayoutManager *)layoutManager { if (!_tk1) [self _isimSwitchToTextKit1]; return _lm; }
/* like UIKit: asking a TextKit 2 view for its layout manager makes it a TextKit 1 view for good */
- (void)_isimSwitchToTextKit1 {
    if (_tk1) return;
    NSLog(@"isim UIKit: UITextView %p is switching to TextKit 1 compatibility mode because its layoutManager was accessed", self);
    for (NSTextAttachmentViewProvider *p in _placedProviders) [p.view removeFromSuperview];
    [_placedProviders removeAllObjects];
    _tlm.textViewportLayoutController.delegate = nil;
    [_tcs removeTextLayoutManager:_tlm];
    _tcs.textStorage = nil; _tcs = nil; _tlm = nil;
    _tc.textLayoutManager = nil;
    _lm = [NSLayoutManager new];
    [_lm addTextContainer:_tc];
    [_ts addLayoutManager:_lm];
    _tk1 = YES;
    [self _isim_tvChanged];
}
- (__IsimTextEngine *)_isim_tvEngine {
    CGFloat w = [self _isim_tvContainerWidthFor:self.bounds.size.width];
    if (_tc.widthTracksTextView && fabs(_tc.size.width - w) > 0.01) _tc.size = CGSizeMake(w, CGFLOAT_MAX);
    if (_secureTextEntry) {                                       /* bullets */
        NSString *s = [self _isim_tvShown];
        if (!_secureEngine || ![_secureText isEqualToString:s] || fabs(_secureEngine.width - _tc.size.width) > 0.01) {
            _secureText = s;
            _secureEngine = [[__IsimTextEngine alloc] initWithString:[[NSAttributedString alloc] initWithString:s attributes:_typing] width:_tc.size.width
                                                            padding:_tc.lineFragmentPadding font:_font color:_textColor maxLines:_tc.maximumNumberOfLines];
        }
        return _secureEngine;
    }
    return _tk1 ? [_lm _isim_engine] : [_tlm _isim_engine];
}
/* NSTextStorageDelegate: the view follows edits made to its storage (by the app, or its own) */
- (void)textStorage:(NSTextStorage *)ts didProcessEditing:(NSTextStorageEditActions)mask range:(NSRange)r changeInLength:(NSInteger)delta {
    if (_updatingStorage) return;
    if (_selectedRange.location > ts.length) _selectedRange = NSMakeRange(ts.length, 0);
    else if (NSMaxRange(_selectedRange) > ts.length) _selectedRange.length = ts.length - _selectedRange.location;
    dispatch_async(dispatch_get_main_queue(), ^{ [self _isim_tvChanged]; });   /* (after the layout managers heard of it) */
}
- (void)registerTextAttachmentViewProviderReusePolicy:(UITextAttachmentViewProviderReusePolicy)policy forTextAttachmentViewProviderType:(Class)type {
    if (type) _reusePolicies[NSStringFromClass(type)] = @(policy);
}
- (UITextAttachmentViewProviderReusePolicy)_isimPolicyForAttachment:(NSTextAttachment *)a {
    Class c = a.fileType ? [NSTextAttachment textAttachmentViewProviderClassForFileType:a.fileType] : nil;
    return c ? [_reusePolicies[NSStringFromClass(c)] unsignedIntegerValue] : 0;
}
- (UITextAttachmentViewProviderReusePolicy)_isimPolicyForProvider:(NSTextAttachmentViewProvider *)p {
    for (Class c = p.class; c; c = class_getSuperclass(c)) { NSNumber *n = _reusePolicies[NSStringFromClass(c)]; if (n) return n.unsignedIntegerValue; }
    return 0;
}

/* ---- NSTextViewportLayoutControllerDelegate (TextKit 2): attachment views in the viewport ---- */
- (CGPoint)_isim_tvTextOrigin { return CGPointMake(_textContainerInset.left, _textContainerInset.top); }
- (CGRect)viewportBoundsForTextViewportLayoutController:(NSTextViewportLayoutController *)c {
    CGPoint o = [self _isim_tvTextOrigin];
    CGRect b = self.bounds;
    return CGRectMake(b.origin.x - o.x, b.origin.y - o.y, b.size.width, b.size.height);
}
- (void)textViewportLayoutControllerWillLayout:(NSTextViewportLayoutController *)c {}
- (void)textViewportLayoutController:(NSTextViewportLayoutController *)c configureRenderingSurfaceForTextLayoutFragment:(NSTextLayoutFragment *)f {
    __weak UITextView *w = self;
    NSArray *ps = [_tlm _isimProvidersFor:f parentView:self reuse:^BOOL(NSTextAttachment *a) {
        return ([w _isimPolicyForAttachment:a] & UITextAttachmentViewProviderReusePolicyOnEditingInlineParagraphs) != 0;
    }];
    CGPoint o = [self _isim_tvTextOrigin];
    CGRect ff = f.layoutFragmentFrame;
    for (NSTextAttachmentViewProvider *p in ps) {
        UIView *v = p.view;
        if (!v) continue;
        CGRect af = [f frameForTextAttachmentAtLocation:p.location];
        v.frame = CGRectMake(o.x + af.origin.x, o.y + ff.origin.y + af.origin.y, af.size.width, af.size.height);
        if (v.superview != self) [self addSubview:v];
        v.hidden = NO;
        if (![_placedProviders containsObject:p]) [_placedProviders addObject:p];
    }
}
- (void)textViewportLayoutControllerDidLayout:(NSTextViewportLayoutController *)c {
    /* views of providers no longer in a visible fragment: removed, unless their class keeps them (iOS 27) */
    NSMutableSet *current = [NSMutableSet set];
    CGRect vb = c.viewportBounds;
    for (NSTextLayoutFragment *f in [_tlm _isimFragments]) {
        CGRect ff = f.layoutFragmentFrame;
        BOOL visible = CGRectGetMaxY(ff) >= CGRectGetMinY(vb) && ff.origin.y <= CGRectGetMaxY(vb);
        for (NSTextAttachmentViewProvider *p in f.textAttachmentViewProviders) if (visible) [current addObject:p];
        for (NSTextAttachmentViewProvider *p in f.textAttachmentViewProviders)
            if (!visible && ([self _isimPolicyForProvider:p] & UITextAttachmentViewProviderReusePolicyOnScrollingOutOfViewport)) [current addObject:p];
    }
    for (NSTextAttachmentViewProvider *p in [_placedProviders copy]) {
        if ([current containsObject:p]) continue;
        [p.view removeFromSuperview];
        [_placedProviders removeObject:p];
    }
}
- (void)textViewportLayoutControllerReceivedSetNeedsLayout:(NSTextViewportLayoutController *)c { [self setNeedsLayout]; }

/* ---- text ---- */
- (NSString *)text { return _ts.string; }
- (void)setText:(NSString *)t {
    t = t ?: @"";
    if ([t isEqualToString:_ts.string] && ![self _isimHasForeignAttributes]) return;
    [self _isimSetStorage:[[NSAttributedString alloc] initWithString:t attributes:_typing]];
    _selectedRange = NSMakeRange(_ts.length, 0);
    isim_ui_set_marked_range(self, NSMakeRange(NSNotFound, 0));
    [self _isim_tvChanged];
}
- (BOOL)_isimHasForeignAttributes {
    __block BOOL foreign = NO;
    [_ts enumerateAttributesInRange:NSMakeRange(0, _ts.length) options:0 usingBlock:^(NSDictionary *a, NSRange r, BOOL *stop) { if (![a isEqualToDictionary:self->_typing]) { foreign = YES; *stop = YES; } }];
    return foreign;
}
- (void)_isimSetStorage:(NSAttributedString *)s {
    _updatingStorage = YES;
    [_ts setAttributedString:s];
    _updatingStorage = NO;
}
- (NSAttributedString *)attributedText { return [_ts attributedSubstringFromRange:NSMakeRange(0, _ts.length)]; }
- (void)setAttributedText:(NSAttributedString *)a {
    a = a ?: [NSAttributedString new];
    [self _isimSetStorage:a];
    if (a.length) {                                               /* like UIKit: the view's font and colour follow the text's start */
        NSDictionary *at = [a attributesAtIndex:0 effectiveRange:NULL];
        if (at[NSFontAttributeName]) _font = at[NSFontAttributeName];
        if (at[NSForegroundColorAttributeName]) _textColor = at[NSForegroundColorAttributeName];
        NSMutableDictionary *t = [_typing mutableCopy]; [t addEntriesFromDictionary:at]; [t removeObjectForKey:NSAttachmentAttributeName]; [t removeObjectForKey:NSLinkAttributeName];
        _typing = t;
    }
    _selectedRange = NSMakeRange(_ts.length, 0);
    isim_ui_set_marked_range(self, NSMakeRange(NSNotFound, 0));
    [self _isim_tvChanged];
}
- (NSDictionary *)typingAttributes { return _typing; }
- (void)setTypingAttributes:(NSDictionary *)t { _typing = [t copy] ?: @{}; }
- (NSDictionary *)linkTextAttributes { return _linkAttrs ?: @{ NSForegroundColorAttributeName: self.tintColor ?: UIColor.linkColor }; }
- (void)setLinkTextAttributes:(NSDictionary *)a { _linkAttrs = [a copy]; isim_ui_set_needs_display(); }
/* font, colour and alignment apply to all the text and to typing */
- (void)_isimApply:(NSAttributedStringKey)key value:(id)v {
    NSMutableDictionary *t = [_typing mutableCopy]; if (v) t[key] = v; else [t removeObjectForKey:key]; _typing = t;
    if (!_ts.length) return;
    _updatingStorage = YES;
    if (v) [_ts addAttribute:key value:v range:NSMakeRange(0, _ts.length)]; else [_ts removeAttribute:key range:NSMakeRange(0, _ts.length)];
    _updatingStorage = NO;
}
- (void)setFont:(UIFont *)f { _font = f ?: [UIFont systemFontOfSize:12]; [self _isimApply:NSFontAttributeName value:_font]; [self _isim_tvChanged]; }
- (void)setTextColor:(UIColor *)c { _textColor = c ?: UIColor.labelColor; [self _isimApply:NSForegroundColorAttributeName value:_textColor]; isim_ui_set_needs_display(); }
- (void)setTextAlignment:(NSTextAlignment)a {
    _textAlignment = a;
    NSMutableParagraphStyle *ps = [NSMutableParagraphStyle new]; ps.alignment = a;
    [self _isimApply:NSParagraphStyleAttributeName value:a == NSTextAlignmentNatural ? nil : ps];
    [self _isim_tvChanged];
}
- (void)setTextContainerInset:(UIEdgeInsets)i { _textContainerInset = i; [self _isim_tvChanged]; }
- (void)setEditable:(BOOL)e { _editable = e; if (!e && self.isFirstResponder) [self resignFirstResponder]; }
- (void)setSelectedRange:(NSRange)r {
    NSUInteger len = _ts.length;
    if (r.location > len) r.location = len;
    if (NSMaxRange(r) > len) r.length = len - r.location;
    _selectedRange = r;
    isim_ui_set_needs_display();
}
- (void)setScrollEnabled:(BOOL)e { [super setScrollEnabled:e]; [self invalidateIntrinsicContentSize]; }
- (void)setSecureTextEntry:(BOOL)s { _secureTextEntry = s; _secureEngine = nil; [self _isim_tvChanged]; }
- (BOOL)hasText { return _ts.length > 0; }
- (NSString *)_isim_dumpText {
    NSString *t = [_ts.string stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"];
    NSString *sel = _selectedRange.length ? [NSString stringWithFormat:@" selection %lu+%lu", (unsigned long)_selectedRange.location, (unsigned long)_selectedRange.length] : @"";
    NSRange m = isim_ui_marked_range(self);
    if (m.location != NSNotFound) sel = [sel stringByAppendingFormat:@" marked %lu+%lu", (unsigned long)m.location, (unsigned long)m.length];
    return [NSString stringWithFormat:@"\"%@\"%@%@ offset %g, content %g", t, self.isFirstResponder ? @" (editing)" : @"", sel, self.contentOffset.y, self.contentSize.height];
}

/* ---- metrics ---- */
- (CGFloat)_isim_tvContainerWidthFor:(CGFloat)w { return fmax(1, w - _textContainerInset.left - _textContainerInset.right); }
- (NSString *)_isim_tvShown {
    if (!_secureTextEntry) return _ts.string;
    NSMutableString *m = [NSMutableString string];
    for (NSUInteger i = 0; i < _ts.length; i++) [m appendString:@"•"];
    return m;
}
- (CGFloat)_isim_tvTextHeight {
    CGFloat lh = ceil(_font.lineHeight);
    return fmax([self _isim_tvEngine].height, lh);
}
- (void)_isim_tvUpdateContent {
    CGFloat w = self.bounds.size.width;
    _measuredWidth = w;
    CGFloat h = [self _isim_tvTextHeight] + _textContainerInset.top + _textContainerInset.bottom;
    self.contentSize = CGSizeMake(w, ceil(h));
}
- (void)_isim_tvChanged {
    _secureEngine = nil;
    [self _isim_tvUpdateContent];
    if (!self.scrollEnabled) [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
/* (content size follows width changes in layoutSubviews, not in setFrame: a frame applied by the Auto Layout
   solver must not scroll synchronously, which would re-enter layout through scroll observers) */
- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.bounds.size.width != _measuredWidth) [self _isim_tvUpdateContent];
    if (!_tk1 && _tlm) [_tlm.textViewportLayoutController layoutViewport];
}
- (void)setContentOffset:(CGPoint)o {
    [super setContentOffset:o];
    if (!_tk1 && _tlm && _placedProviders.count + [self _isimAttachmentCount]) [self setNeedsLayout];
}
- (NSUInteger)_isimAttachmentCount { return _tk1 || !_tlm ? 0 : [_tlm _isim_engine].attachments.count; }
/* not scrolling: the view is as tall as its text (self-sizing) */
- (CGSize)_isim_tvSizeForWidth:(CGFloat)w {
    UIEdgeInsets in = _textContainerInset;
    __IsimTextEngine *one = [[__IsimTextEngine alloc] initWithString:[[NSAttributedString alloc] initWithString:[self _isim_tvShown] attributes:_typing]
                                                                width:0 padding:_tc.lineFragmentPadding font:_font color:_textColor maxLines:0];
    if (!_secureTextEntry) one = [[__IsimTextEngine alloc] initWithString:self.attributedText width:0 padding:_tc.lineFragmentPadding font:_font color:_textColor maxLines:0];
    CGFloat width = ceil(CGRectGetMaxX(one.usedRect)) + in.left + in.right;
    if (w <= 0) w = width;
    CGFloat ww = [self _isim_tvContainerWidthFor:w];
    __IsimTextEngine *e = fabs(ww - _tc.size.width) < 0.01 ? [self _isim_tvEngine]
        : [[__IsimTextEngine alloc] initWithString:_secureTextEntry ? [[NSAttributedString alloc] initWithString:[self _isim_tvShown] attributes:_typing] : self.attributedText
                                             width:ww padding:_tc.lineFragmentPadding font:_font color:_textColor maxLines:_tc.maximumNumberOfLines];
    CGFloat height = fmax(e.height, ceil(_font.lineHeight)) + in.top + in.bottom;
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

/* the insertion point before a character, in content coordinates */
- (CGRect)_isim_tvCaretRect:(NSUInteger)index {
    CGPoint o = [self _isim_tvTextOrigin];
    CGRect c = [[self _isim_tvEngine] caretRectForIndex:MIN(index, _ts.length)];
    return CGRectOffset(c, o.x, o.y);
}
/* nearest insertion point for a point in content coordinates */
- (NSUInteger)_isim_tvIndexAt:(CGPoint)p {
    CGPoint o = [self _isim_tvTextOrigin];
    return MIN([[self _isim_tvEngine] insertionIndexForPoint:CGPointMake(p.x - o.x, p.y - o.y)], _ts.length);
}

/* ---- editing ---- */
- (BOOL)canBecomeFirstResponder { return _editable; }
- (BOOL)becomeFirstResponder {
    if (self.isFirstResponder) return YES;
    if (!_editable) return NO;
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textViewShouldBeginEditing:)] && ![d textViewShouldBeginEditing:self]) return NO;
    if (![super becomeFirstResponder]) return NO;
    if (_clearsOnInsertion) { [self _isimSetStorage:[NSAttributedString new]]; _selectedRange = NSMakeRange(0, 0); [self _isim_tvChanged]; }
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
    _updatingStorage = YES;
    [_ts replaceCharactersInRange:r withAttributedString:[[NSAttributedString alloc] initWithString:s attributes:_typing]];
    _updatingStorage = NO;
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
- (NSString *)_isim_plainText { return _ts.string; }
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
    CGRect c = [self _isim_tvCaretRect:i];
    return CGRectMake(c.origin.x - 1, c.origin.y + 1, 2, fmax(2, c.size.height - 2));
}
- (NSUInteger)_isim_indexAtPoint:(CGPoint)p { return [self _isim_tvIndexAt:p]; }
- (NSArray<NSValue *> *)_isim_selectionRectsForRange:(NSRange)r {
    NSMutableArray *out = [NSMutableArray array];
    if (NSMaxRange(r) > _ts.length) return out;
    CGPoint o = [self _isim_tvTextOrigin];
    for (NSValue *v in [[self _isim_tvEngine] rectsForRange:r]) [out addObject:[NSValue valueWithCGRect:CGRectOffset(v.CGRectValue, o.x, o.y)]];
    return out;
}
ISIM_TEXT_INPUT_METHODS
/* ---- scrolling ---- */
- (void)_isim_tvScrollToCaret {
    if (!self.scrollEnabled) return;
    CGRect c = [self _isim_tvCaretRect:NSMaxRange(_selectedRange)];
    [self scrollRectToVisible:CGRectMake(c.origin.x, c.origin.y, 2, c.size.height + _textContainerInset.bottom) animated:NO];
}
- (void)scrollRangeToVisible:(NSRange)r {
    if (r.location > _ts.length) return;
    CGRect a = [self _isim_tvCaretRect:r.location], b = [self _isim_tvCaretRect:MIN(NSMaxRange(r), _ts.length)];
    [self scrollRectToVisible:CGRectMake(0, a.origin.y, self.bounds.size.width, CGRectGetMaxY(b) - a.origin.y) animated:NO];
}

/* ---- detected items (dataDetectorTypes; not editable, selectable): UITextServices.m ---- */
- (void)setDataDetectorTypes:(UIDataDetectorTypes)t { _dataDetectorTypes = t; isim_ui_set_needs_display(); }
- (NSArray<NSTextCheckingResult *> *)_isim_items {
    if (_editable || !_selectable || !_dataDetectorTypes || _secureTextEntry) return @[];
    if (!_items || _itemsTypes != _dataDetectorTypes || ![_itemsText isEqualToString:_ts.string]) {
        _items = isim_ui_detect_items(_ts.string, _dataDetectorTypes);
        _itemsText = _ts.string; _itemsTypes = _dataDetectorTypes;
    }
    return _items;
}
/* an item's pieces, one per line: (character range, rect in content coordinates) */
- (void)_isim_itemPieces:(NSRange)r each:(void (^)(NSRange piece, CGRect rect))each {
    CGPoint o = [self _isim_tvTextOrigin];
    __IsimTextEngine *e = [self _isim_tvEngine];
    for (__IsimTextLine *l in e.lines) {
        NSRange in = NSIntersectionRange(l->range, r);
        while (in.length && [_ts.string characterAtIndex:NSMaxRange(in) - 1] == '\n') in.length--;
        if (!in.length) continue;
        each(in, CGRectOffset([e boundingRectForRange:in], o.x, o.y));
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
            UIFont *f = [self->_ts attribute:NSFontAttributeName atIndex:piece.location effectiveRange:NULL] ?: self->_font;
            isim_ui_draw_text([self->_ts.string substringWithRange:piece], f, tc, CGRectMake(d.origin.x, d.origin.y, d.size.width + 20, d.size.height), NSTextAlignmentLeft, 1, 1);
            isim_gfx_fill_rounded(d.origin.x, d.origin.y + ceil(f.ascender) + 2, d.size.width, 1, 0, tint);
        }];
}

/* ---- drawing (content coordinates are shifted by the scroll offset) ---- */
- (void)_isim_drawContent {
    CGPoint off = self.contentOffset, o = [self _isim_tvTextOrigin];
    isim_gfx_save(); isim_gfx_translate(-off.x, -off.y);
    isim_ui_text_draw_selection_rects(self);
    isim_gfx_restore();
    __IsimTextEngine *e = [self _isim_tvEngine];
    if (e.string.length) {
        isim_gfx_save();
        isim_gfx_clip_rounded(0, 0, self.bounds.size.width, self.bounds.size.height, 0);
        [e drawRange:NSMakeRange(0, e.string.length) atPoint:CGPointMake(o.x - off.x, o.y - off.y) skipAttachmentViews:!_tk1];
        isim_gfx_restore();
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
