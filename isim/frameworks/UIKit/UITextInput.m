/* Text editing shared by UITextField and UITextView: UITextInput positions/ranges and tokenizer, marked text (host IME
 * composition, script `compose`), the standard edit actions over UIPasteboard, selection interactions (tap places the
 * caret at a word boundary, double tap selects a word, triple tap a paragraph, long press shows the loupe and moves
 * the caret, selection handles drag), the edit menu (UIEditMenuInteraction, UIMenuController), and hardware keyboard
 * navigation (arrows, Shift to extend, Option word / Cmd line jumps, Cmd/Ctrl + A C X V). */
#import "UIKitInputPrivate.h"
#import <UIKit/UIEditMenuInteraction.h>
#import <UIKit/UITextChecker.h>
#import <objc/runtime.h>
#import <objc/message.h>
#include <math.h>

@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
- (void)_fire;
@end

NSNotificationName const UITextInputCurrentInputModeDidChangeNotification = @"UITextInputCurrentInputModeDidChangeNotification";

/* ================= positions and ranges ================= */
@implementation UITextPosition @end
@implementation UITextRange
- (BOOL)isEmpty { return YES; }
- (UITextPosition *)start { return nil; }
- (UITextPosition *)end { return nil; }
@end
@interface __IsimTextPosition : UITextPosition
@property (nonatomic) NSInteger offset;
@end
@implementation __IsimTextPosition
- (NSString *)description { return [NSString stringWithFormat:@"<UITextPosition %ld>", (long)_offset]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[__IsimTextPosition class]] && ((__IsimTextPosition *)o).offset == _offset; }
- (NSUInteger)hash { return (NSUInteger)_offset; }
@end
@interface __IsimTextRange : UITextRange
@property (nonatomic) NSRange range;
@end
@implementation __IsimTextRange
- (BOOL)isEmpty { return _range.length == 0; }
- (UITextPosition *)start { __IsimTextPosition *p = [__IsimTextPosition new]; p.offset = (NSInteger)_range.location; return p; }
- (UITextPosition *)end { __IsimTextPosition *p = [__IsimTextPosition new]; p.offset = (NSInteger)NSMaxRange(_range); return p; }
- (id)copyWithZone:(NSZone *)z { __IsimTextRange *r = [__IsimTextRange new]; r.range = _range; return r; }
- (NSString *)description { return [NSString stringWithFormat:@"<UITextRange %@>", NSStringFromRange(_range)]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[__IsimTextRange class]] && NSEqualRanges(((__IsimTextRange *)o).range, _range); }
@end
@implementation UITextSelectionRect @end
@interface __IsimSelectionRect : UITextSelectionRect
@property (nonatomic) CGRect isimRect;
@property (nonatomic) BOOL isimStart, isimEnd;
@end
@implementation __IsimSelectionRect
- (CGRect)rect { return _isimRect; }
- (NSWritingDirection)writingDirection { return NSWritingDirectionLeftToRight; }
- (BOOL)containsStart { return _isimStart; }
- (BOOL)containsEnd { return _isimEnd; }
- (BOOL)isVertical { return NO; }
@end

UITextPosition *isim_ti_pos(NSInteger o) { __IsimTextPosition *p = [__IsimTextPosition new]; p.offset = o; return p; }
UITextRange *isim_ti_range(NSRange r) { __IsimTextRange *x = [__IsimTextRange new]; x.range = r; return x; }
NSInteger isim_ti_off(UITextPosition *p) { return [p isKindOfClass:[__IsimTextPosition class]] ? ((__IsimTextPosition *)p).offset : 0; }
NSRange isim_ti_nsrange(UITextRange *r) {
    if ([r isKindOfClass:[__IsimTextRange class]]) return ((__IsimTextRange *)r).range;
    NSInteger a = isim_ti_off(r.start), b = isim_ti_off(r.end);
    return NSMakeRange((NSUInteger)MIN(a, b), (NSUInteger)labs(b - a));
}

/* ================= per-view editing state ================= */
@interface __IsimTextState : NSObject
@property (nonatomic) NSRange marked;
@property (nonatomic, weak) id<UITextInputDelegate> inputDelegate;
@property (nonatomic, copy) NSDictionary *markedTextStyle;
@property (nonatomic, strong) UITextInputStringTokenizer *tokenizer;
@property (nonatomic) BOOL menuWanted;
@end
@implementation __IsimTextState
- (instancetype)init { if ((self = [super init])) _marked = NSMakeRange(NSNotFound, 0); return self; }
@end
static char k_state;
static __IsimTextState *state_of(id v) {
    __IsimTextState *s = objc_getAssociatedObject(v, &k_state);
    if (!s) { s = [__IsimTextState new]; objc_setAssociatedObject(v, &k_state, s, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return s;
}
NSRange isim_ui_marked_range(id v) { return state_of(v).marked; }
void isim_ui_set_marked_range(id v, NSRange r) { state_of(v).marked = r; isim_ui_set_needs_display(); }

static NSString *text_of(id<IsimEditableText> v) { return [v _isim_plainText] ?: @""; }
static NSRange clamp_range(NSRange r, NSUInteger len) {
    if (r.location == NSNotFound || r.location > len) r.location = len;
    if (NSMaxRange(r) > len) r.length = len - r.location;
    return r;
}

/* ================= tokenizer ================= */
@implementation UITextInputStringTokenizer { __weak UIResponder<UITextInput> *_input; }
- (instancetype)initWithTextInput:(UIResponder<UITextInput> *)input { if ((self = [super init])) _input = input; return self; }
- (NSString *)_text {
    UIResponder<UITextInput> *in = _input;
    UITextRange *all = [in textRangeFromPosition:in.beginningOfDocument toPosition:in.endOfDocument];
    return all ? [in textInRange:all] ?: @"" : @"";
}
static BOOL forward(UITextDirection d) { return d == UITextStorageDirectionForward || d == UITextLayoutDirectionRight || d == UITextLayoutDirectionDown; }
/* the unit (word, sentence, paragraph/line, document) containing `i`, or the one ending/starting at it */
static NSRange unit_at(NSString *s, NSUInteger i, UITextGranularity g) {
    NSUInteger n = s.length;
    if (g == UITextGranularityDocument) return NSMakeRange(0, n);
    if (g == UITextGranularityCharacter) {
        if (i >= n) return NSMakeRange(n, 0);
        return [s rangeOfComposedCharacterSequenceAtIndex:i];
    }
    __block NSRange found = NSMakeRange(NSNotFound, 0);
    NSStringEnumerationOptions o = g == UITextGranularityWord ? NSStringEnumerationByWords : g == UITextGranularitySentence ? NSStringEnumerationBySentences : NSStringEnumerationByParagraphs;
    [s enumerateSubstringsInRange:NSMakeRange(0, n) options:o | NSStringEnumerationSubstringNotRequired usingBlock:^(NSString *x, NSRange r, NSRange e, BOOL *stop) {
        if (i >= r.location && i <= NSMaxRange(r)) { found = r; if (i < NSMaxRange(r)) *stop = YES; }
    }];
    return found;
}
- (UITextRange *)rangeEnclosingPosition:(UITextPosition *)p withGranularity:(UITextGranularity)g inDirection:(UITextDirection)d {
    NSString *s = [self _text];
    NSUInteger i = (NSUInteger)MAX(0, isim_ti_off(p));
    if (!forward(d) && i > 0 && g != UITextGranularityDocument) i--;
    NSRange r = unit_at(s, MIN(i, s.length), g);
    return r.location == NSNotFound ? nil : isim_ti_range(r);
}
- (BOOL)isPosition:(UITextPosition *)p atBoundary:(UITextGranularity)g inDirection:(UITextDirection)d {
    NSString *s = [self _text];
    NSUInteger i = (NSUInteger)MAX(0, isim_ti_off(p));
    if (g == UITextGranularityDocument) return i == 0 || i >= s.length;
    NSRange r = unit_at(s, forward(d) ? i : (i ? i - 1 : 0), g);
    if (r.location == NSNotFound) return NO;
    return forward(d) ? NSMaxRange(r) == i : r.location == i;
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)p toBoundary:(UITextGranularity)g inDirection:(UITextDirection)d {
    NSString *s = [self _text];
    NSInteger i = isim_ti_off(p), n = (NSInteger)s.length;
    if (g == UITextGranularityDocument) return isim_ti_pos(forward(d) ? n : 0);
    if (forward(d)) {
        for (NSInteger k = i; k < n; k++) { NSRange r = unit_at(s, (NSUInteger)k, g); if (r.location != NSNotFound && (NSInteger)NSMaxRange(r) > i) return isim_ti_pos((NSInteger)NSMaxRange(r)); }
        return isim_ti_pos(n);
    }
    for (NSInteger k = i - 1; k >= 0; k--) { NSRange r = unit_at(s, (NSUInteger)k, g); if (r.location != NSNotFound && (NSInteger)r.location < i) return isim_ti_pos((NSInteger)r.location); }
    return isim_ti_pos(0);
}
- (BOOL)isPosition:(UITextPosition *)p withinTextUnit:(UITextGranularity)g inDirection:(UITextDirection)d {
    NSString *s = [self _text];
    NSUInteger i = (NSUInteger)MAX(0, isim_ti_off(p));
    NSRange r = unit_at(s, forward(d) ? i : (i ? i - 1 : 0), g);
    return r.location != NSNotFound && (forward(d) ? (i >= r.location && i < NSMaxRange(r)) : (i > r.location && i <= NSMaxRange(r)));
}
@end

/* ================= editing operations ================= */
static void notify_selection(id<IsimEditableText> v, void (^change)(void)) {
    id<UITextInputDelegate> d = state_of(v).inputDelegate;
    [d selectionWillChange:v];
    change();
    [d selectionDidChange:v];
}
void isim_ti_set_selection(id<IsimEditableText> v, NSRange r) {
    r = clamp_range(r, text_of(v).length);
    if (NSEqualRanges(r, [v _isim_selectedRange])) return;
    notify_selection(v, ^{ [v _isim_setSelectedRange:r]; });
    isim_ui_text_selection_changed(v);
}
static void replace(id<IsimEditableText> v, NSRange r, NSString *t) {
    id<UITextInputDelegate> d = state_of(v).inputDelegate;
    [d textWillChange:v];
    [v _isim_replaceRange:clamp_range(r, text_of(v).length) withText:t ?: @""];
    [d textDidChange:v];
}
void isim_ti_insert(id<IsimEditableText> v, NSString *text) {
    __IsimTextState *st = state_of(v);
    NSRange target = st.marked.location != NSNotFound ? st.marked : [v _isim_selectedRange];
    st.marked = NSMakeRange(NSNotFound, 0);
    replace(v, target, text);
}
void isim_ti_delete_backward(id<IsimEditableText> v) {
    __IsimTextState *st = state_of(v);
    NSString *s = text_of(v);
    if (st.marked.location != NSNotFound && st.marked.length) {
        NSRange m = clamp_range(st.marked, s.length);
        NSString *mt = [s substringWithRange:m];
        NSRange last = [mt rangeOfComposedCharacterSequenceAtIndex:mt.length - 1];
        NSString *rest = [mt substringToIndex:last.location];
        st.marked = NSMakeRange(NSNotFound, 0);
        replace(v, m, rest);
        st.marked = rest.length ? NSMakeRange(m.location, rest.length) : NSMakeRange(NSNotFound, 0);
        return;
    }
    NSRange sel = [v _isim_selectedRange];
    if (sel.length) { replace(v, sel, @""); return; }
    if (sel.location == 0 || !s.length) return;
    replace(v, [s rangeOfComposedCharacterSequenceAtIndex:MIN(sel.location, s.length) - 1], @"");
}
void isim_ti_set_marked(id<IsimEditableText> v, NSString *text, NSRange selInMarked) {
    __IsimTextState *st = state_of(v);
    text = text ?: @"";
    NSRange target = st.marked.location != NSNotFound ? st.marked : [v _isim_selectedRange];
    target = clamp_range(target, text_of(v).length);
    /* (marked before the change, so text-change delegates already see markedTextRange) */
    st.marked = text.length ? NSMakeRange(target.location, text.length) : NSMakeRange(NSNotFound, 0);
    replace(v, target, text);
    NSRange sel = selInMarked.location == NSNotFound ? NSMakeRange(text.length, 0) : clamp_range(selInMarked, text.length);
    isim_ti_set_selection(v, NSMakeRange(target.location + sel.location, sel.length));
    isim_ui_set_needs_display();
}
void isim_ti_unmark(id<IsimEditableText> v) {
    __IsimTextState *st = state_of(v);
    if (st.marked.location == NSNotFound) return;
    st.marked = NSMakeRange(NSNotFound, 0);
    isim_ui_set_needs_display();
}
/* host IME composition (SDL text editing events, script `compose`) */
void isim_ui_text_editing(NSString *marked, int cursor, int length) {
    id fr = isim_ui_first_responder();
    if (![fr conformsToProtocol:@protocol(UITextInput)]) return;
    id<UITextInput> t = fr;
    if (!marked.length) { [t setMarkedText:@"" selectedRange:NSMakeRange(0, 0)]; [t unmarkText]; return; }
    /* the cursor counts characters (code points); convert to UTF-16 */
    NSUInteger c = 0, units = 0;
    while (units < marked.length && (int)c < cursor) { units = NSMaxRange([marked rangeOfComposedCharacterSequenceAtIndex:units]); c++; }
    if (cursor < 0) units = marked.length;
    [t setMarkedText:marked selectedRange:NSMakeRange(units, length > 0 ? 0 : 0)];
    NSLog(@"isim: marked text \"%@\"", marked);
}

/* ================= caret placement helpers ================= */
/* iOS puts a tapped caret at the nearer edge of the word under the finger */
static NSUInteger snap_to_word(NSString *s, NSUInteger i) {
    if (i == 0 || i >= s.length) return MIN(i, s.length);
    NSRange w = unit_at(s, i, UITextGranularityWord);
    if (w.location == NSNotFound || i <= w.location || i >= NSMaxRange(w)) return i;
    return (i - w.location) < (NSMaxRange(w) - i) ? w.location : NSMaxRange(w);
}
static NSRange word_range_at(NSString *s, NSUInteger i) {
    NSRange w = unit_at(s, MIN(i, s.length ? s.length - 1 : 0), UITextGranularityWord);
    if (w.location == NSNotFound && i > 0) w = unit_at(s, i - 1, UITextGranularityWord);
    return w;
}
static NSRange paragraph_range_at(NSString *s, NSUInteger i) {
    if (!s.length) return NSMakeRange(0, 0);
    NSUInteger a = 0, b = s.length;
    NSRange nl = [s rangeOfString:@"\n" options:NSBackwardsSearch range:NSMakeRange(0, MIN(i, s.length))];
    if (nl.location != NSNotFound) a = NSMaxRange(nl);
    NSRange nr = [s rangeOfString:@"\n" options:0 range:NSMakeRange(MIN(i, s.length), s.length - MIN(i, s.length))];
    if (nr.location != NSNotFound) b = nr.location;
    return NSMakeRange(a, b - a);
}

/* ================= standard edit actions ================= */
static BOOL secure_view(id v) { return [v respondsToSelector:@selector(isSecureTextEntry)] && [v isSecureTextEntry]; }
static NSString *selected_text(id<IsimEditableText> v) {
    NSRange r = clamp_range([v _isim_selectedRange], text_of(v).length);
    return r.length ? [text_of(v) substringWithRange:r] : nil;
}
static NSArray<NSString *> *replace_guesses(id<IsimEditableText> v) {
    NSString *t = selected_text(v);
    if (!t.length || [t rangeOfCharacterFromSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].location != NSNotFound) return @[];
    NSString *lang = isim_ui_keyboard_current_language();
    return [[UITextChecker new] guessesForWordRange:NSMakeRange(0, t.length) inString:t language:lang] ?: @[];
}
BOOL isim_ti_can_perform(id<IsimEditableText> v, SEL a) {
    NSString *s = text_of(v);
    NSRange sel = clamp_range([v _isim_selectedRange], s.length);
    BOOL editable = [v _isim_isEditable];
    if (a == @selector(copy:)) return sel.length > 0 && !secure_view(v);
    if (a == @selector(cut:)) return sel.length > 0 && editable && !secure_view(v);
    if (a == @selector(paste:)) return editable && UIPasteboard.generalPasteboard.hasStrings;
    if (a == @selector(delete:)) return sel.length > 0 && editable;
    if (a == @selector(select:)) return sel.length == 0 && s.length > 0 && !secure_view(v);
    if (a == @selector(selectAll:)) return s.length > 0 && sel.length < s.length;
    if (a == NSSelectorFromString(@"_isim_promptForReplace:")) return editable && replace_guesses(v).count > 0;
    return NO;
}
void isim_ti_copy(id<IsimEditableText> v) {
    NSString *t = selected_text(v);
    if (t) { UIPasteboard.generalPasteboard.string = t; NSLog(@"isim: copied \"%@\"", t); }
}
void isim_ti_cut(id<IsimEditableText> v) {
    NSString *t = selected_text(v);
    if (!t) return;
    UIPasteboard.generalPasteboard.string = t;
    NSLog(@"isim: cut \"%@\"", t);
    replace(v, [v _isim_selectedRange], @"");
}
void isim_ti_paste(id<IsimEditableText> v) {
    NSString *t = UIPasteboard.generalPasteboard.string;
    if (!t.length || ![v _isim_isEditable]) return;
    NSLog(@"isim: pasted \"%@\"", t);
    isim_ti_insert(v, t);
}
void isim_ti_delete(id<IsimEditableText> v) { NSRange r = [v _isim_selectedRange]; if (r.length) replace(v, r, @""); }
void isim_ui_show_text_menu(id<IsimEditableText> v);
void isim_ti_select(id<IsimEditableText> v) {
    NSString *s = text_of(v);
    NSRange w = word_range_at(s, [v _isim_selectedRange].location);
    if (w.location == NSNotFound || !w.length) return;
    isim_ti_set_selection(v, w);
    isim_ui_show_text_menu(v);
}
void isim_ti_select_all(id<IsimEditableText> v) {
    isim_ti_set_selection(v, NSMakeRange(0, text_of(v).length));
    isim_ui_show_text_menu(v);
}

/* ================= selection drawing ================= */
static double tint_of(UIView *v, double out[4]) { isim_ui_rgba(v.tintColor, out); return out[3]; }
void isim_ui_text_draw_selection_rects(id<IsimEditableText> v) {
    UIView *view = (UIView *)v;
    NSRange sel = clamp_range([v _isim_selectedRange], text_of(v).length);
    if (!sel.length) return;
    double t[4]; tint_of(view, t); t[3] = 0.22;
    for (NSValue *r in [v _isim_selectionRectsForRange:sel]) { CGRect x = r.CGRectValue; isim_gfx_fill_rounded(x.origin.x, x.origin.y, x.size.width, x.size.height, 0, t); }
}
/* caret (when collapsed) or handles (with a selection); marked text gets an underline */
void isim_ui_text_draw_selection(id<IsimEditableText> v) {
    UIView *view = (UIView *)v;
    if (!view.isFirstResponder && ![v _isim_selectedRange].length) return;
    NSString *s = text_of(v);
    NSRange sel = clamp_range([v _isim_selectedRange], s.length);
    double t[4]; tint_of(view, t);
    NSRange m = state_of(v).marked;
    if (m.location != NSNotFound && m.length && NSMaxRange(m) <= s.length) {
        double u[4]; isim_ui_rgba(UIColor.labelColor, u); u[3] = 0.6;
        for (NSValue *r in [v _isim_selectionRectsForRange:m]) { CGRect x = r.CGRectValue; isim_gfx_fill_rounded(x.origin.x, CGRectGetMaxY(x) - 2, x.size.width, 1.5, 0, u); }
    }
    if (!view.isFirstResponder) return;
    if (!sel.length) {
        CGRect c = [v _isim_caretRectForIndex:sel.location];
        isim_gfx_fill_rounded(c.origin.x, c.origin.y, 2, c.size.height, 1, t);
        return;
    }
    CGRect a = [v _isim_caretRectForIndex:sel.location], b = [v _isim_caretRectForIndex:NSMaxRange(sel)];
    isim_gfx_fill_rounded(a.origin.x - 1, a.origin.y, 2, a.size.height, 1, t);
    isim_gfx_fill_ellipse(a.origin.x - 4, a.origin.y - 7, 8, 8, t);
    isim_gfx_fill_rounded(b.origin.x - 1, b.origin.y, 2, b.size.height, 1, t);
    isim_gfx_fill_ellipse(b.origin.x - 4, CGRectGetMaxY(b) - 1, 8, 8, t);
}
/* red dotted underline under misspelled words (spell checking), except the word being typed */
void isim_ui_text_draw_spelling(id<IsimEditableText> v) {
    UIView *view = (UIView *)v;
    if (!view.isFirstResponder || secure_view(v)) return;
    extern NSDictionary *isim_global_preferences(void);
    NSNumber *pref = isim_global_preferences()[@"KeyboardCheckSpelling"];     /* Settings > General > Keyboard */
    if (pref && !pref.boolValue) return;
    if ([v respondsToSelector:@selector(spellCheckingType)] && [(id<UITextInputTraits>)v spellCheckingType] == UITextSpellCheckingTypeNo) return;
    if ([v respondsToSelector:@selector(autocorrectionType)] && [(id<UITextInputTraits>)v autocorrectionType] == UITextAutocorrectionTypeNo &&
        (![v respondsToSelector:@selector(spellCheckingType)] || [(id<UITextInputTraits>)v spellCheckingType] != UITextSpellCheckingTypeYes)) return;
    NSString *s = text_of(v);
    if (!s.length || s.length > 4000) return;
    NSUInteger caret = [v _isim_selectedRange].location;
    UITextChecker *chk = [UITextChecker new];
    NSString *lang = isim_ui_keyboard_current_language();
    double red[4] = { 1, 0.23, 0.19, 0.95 };
    NSUInteger from = 0;
    for (int guard = 0; guard < 50; guard++) {
        NSRange r = [chk rangeOfMisspelledWordInString:s range:NSMakeRange(0, s.length) startingAt:(NSInteger)from wrap:NO language:lang];
        if (r.location == NSNotFound) break;
        from = NSMaxRange(r);
        if (caret >= r.location && caret <= NSMaxRange(r)) continue;          /* still typing it */
        for (NSValue *rv in [v _isim_selectionRectsForRange:r]) {
            CGRect x = rv.CGRectValue;
            for (CGFloat dx = 0; dx < x.size.width; dx += 4) isim_gfx_fill_ellipse(x.origin.x + dx, CGRectGetMaxY(x) - 2.5, 2.2, 2.2, red);
        }
    }
}

/* ================= edit menu ================= */
@interface __IsimMenuPlatter : UIView
@property (nonatomic, copy) void (^onDismiss)(void);
@end
@implementation __IsimMenuPlatter @end

@interface __IsimMenuWindow : UIWindow
@property (nonatomic, strong) __IsimMenuPlatter *platter;
@end
@implementation __IsimMenuWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e {
    if (!_platter || !CGRectContainsPoint(_platter.frame, p)) return nil;
    return [super hitTest:p withEvent:e];
}
@end

static __IsimMenuWindow *menu_window;
static NSArray<UIMenuElement *> *menu_items;           /* the page shown */
static NSMutableArray<NSArray *> *menu_stack;           /* submenus: previous item lists */
static CGRect menu_target;                              /* window coordinates */
static void (^menu_dismissed)(void);
static NSUInteger menu_page;

static void menu_build(void);
BOOL isim_ui_edit_menu_visible(void) { return menu_window && !menu_window.hidden; }
void isim_ui_hide_edit_menu(void) {
    if (!isim_ui_edit_menu_visible()) return;
    menu_window.hidden = YES;
    [menu_window.platter removeFromSuperview]; menu_window.platter = nil;
    void (^d)(void) = menu_dismissed; menu_dismissed = nil;
    menu_items = nil; menu_stack = nil;
    NSLog(@"isim: edit menu hidden");
    if (d) d();
    isim_ui_set_needs_display();
}
@interface __IsimMenuTarget : NSObject
+ (void)tapped:(UIButton *)b;
@end
static NSArray *flatten(NSArray<UIMenuElement *> *els) {
    NSMutableArray *out = [NSMutableArray array];
    for (UIMenuElement *e in els) {
        if ([e isKindOfClass:[UIMenu class]] && (((UIMenu *)e).options & UIMenuOptionsDisplayInline)) [out addObjectsFromArray:flatten(((UIMenu *)e).children)];
        else if (!([e isKindOfClass:[UIAction class]] && (((UIAction *)e).attributes & UIMenuElementAttributesHidden))) [out addObject:e];
    }
    return out;
}
@implementation __IsimMenuTarget
+ (void)tapped:(UIButton *)b {
    NSArray *items = flatten(menu_items);
    if (b.tag == -1) { menu_page++; menu_build(); return; }
    if (b.tag == -2) { if (menu_page) menu_page--; else if (menu_stack.count) { menu_items = menu_stack.lastObject; [menu_stack removeLastObject]; } menu_build(); return; }
    if (b.tag < 0 || (NSUInteger)b.tag >= items.count) return;
    UIMenuElement *e = items[(NSUInteger)b.tag];
    if ([e isKindOfClass:[UIMenu class]]) {
        if (!menu_stack) menu_stack = [NSMutableArray array];
        [menu_stack addObject:menu_items];
        menu_items = ((UIMenu *)e).children; menu_page = 0;
        menu_build();
        return;
    }
    NSLog(@"isim: edit menu chose \"%@\"", e.title);
    isim_ui_hide_edit_menu();
    if ([e isKindOfClass:[UIAction class]]) {
        UIAction *a = (UIAction *)e;
        if (a.handler) a.handler(a);
    }
}
@end
static void menu_build(void) {
    __IsimMenuPlatter *p = menu_window.platter;
    for (UIView *s in p.subviews) [s removeFromSuperview];
    NSArray *items = flatten(menu_items);
    UIFont *font = [UIFont systemFontOfSize:15];
    CGFloat pad = 14, h = 38, maxW = isim_ui_device()->width - 16, x = 0;
    NSMutableArray<UIButton *> *buttons = [NSMutableArray array];
    BOOL back = menu_page > 0 || menu_stack.count > 0;
    /* pages: as many items as fit, with ‹ / › arrows */
    NSUInteger start = 0;
    for (NSUInteger page = 0, i = 0; i < items.count; page++) {
        CGFloat w = page > 0 || menu_stack.count ? 36 : 0;
        NSUInteger j = i;
        while (j < items.count) {
            CGFloat iw = isim_ui_measure(((UIMenuElement *)items[j]).title ?: @"", font, 0, 1).width + 2 * pad;
            if (w + iw + (j + 1 < items.count ? 36 : 0) > maxW && j > i) break;
            w += iw; j++;
        }
        if (page == menu_page) { start = i; break; }
        i = j;
        if (i >= items.count) { menu_page = page; start = i - (j - i); }
    }
    UIColor *fg = UIColor.labelColor;
    UIButton *(^mk)(NSString *, NSInteger, NSString *) = ^UIButton *(NSString *title, NSInteger tag, NSString *ident) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:title forState:UIControlStateNormal];
        [b setTitleColor:fg forState:UIControlStateNormal];
        b.titleLabel.font = font;
        b.tag = tag;
        b.accessibilityIdentifier = ident;
        [b addTarget:[__IsimMenuTarget class] action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
        return b;
    };
    if (back) [buttons addObject:mk(@"‹", -2, @"isim-menu-back")];
    NSUInteger i = start;
    CGFloat used = back ? 36 : 0;
    for (; i < items.count; i++) {
        UIMenuElement *e = items[i];
        NSString *t = e.title ?: @"";
        CGFloat iw = isim_ui_measure(t, font, 0, 1).width + 2 * pad;
        if (used + iw + (i + 1 < items.count ? 36 : 0) > maxW && i > start) break;
        UIButton *b = mk(t, (NSInteger)i, [@"isim-menu-" stringByAppendingString:t]);
        if ([e isKindOfClass:[UIAction class]] && (((UIAction *)e).attributes & UIMenuElementAttributesDisabled)) b.enabled = NO;
        [buttons addObject:b];
        used += iw;
    }
    if (i < items.count) [buttons addObject:mk(@"›", -1, @"isim-menu-more")];
    for (UIButton *b in buttons) {
        CGFloat w = b.tag < 0 ? 36 : isim_ui_measure([b titleForState:UIControlStateNormal], font, 0, 1).width + 2 * pad;
        b.frame = CGRectMake(x, 0, w, h);
        if (x > 0) {
            UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(x, 8, 1.0 / 3, h - 16)];
            sep.backgroundColor = UIColor.separatorColor; sep.userInteractionEnabled = NO;
            [p addSubview:sep];
        }
        [p addSubview:b];
        x += w;
    }
    /* above the target, or below if there is no room; inside the screen */
    const struct isim_device *d = isim_ui_device();
    CGFloat px = CGRectGetMidX(menu_target) - x / 2, py = menu_target.origin.y - h - 10;
    if (py < d->safe_top + 4) py = CGRectGetMaxY(menu_target) + 12;
    px = fmax(8, fmin(px, d->width - 8 - x));
    p.frame = CGRectMake(px, py, x, h);
    isim_ui_set_needs_display();
}
/* shows `elements` in the edit menu next to `rect` (window coordinates) */
void isim_ui_show_edit_menu(CGRect rect, NSArray<UIMenuElement *> *elements, void (^dismissed)(void)) {
    if (!elements.count) { isim_ui_hide_edit_menu(); return; }
    void (^old)(void) = menu_dismissed; menu_dismissed = nil;
    if (old) old();
    if (!menu_window) {
        menu_window = [[__IsimMenuWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        menu_window.windowLevel = 15000000;          /* above the keyboard */
        menu_window.backgroundColor = UIColor.clearColor;
        isim_ui_add_touch_filter(^BOOL(const struct isim_event *ev) {
            /* a touch anywhere else dismisses the menu (and still goes where it was going) */
            if (ev->type == ISIM_EV_TOUCH_DOWN && isim_ui_edit_menu_visible() && !CGRectContainsPoint(menu_window.platter.frame, CGPointMake(ev->x, ev->y)))
                isim_ui_hide_edit_menu();
            return NO;
        });
    }
    menu_window.frame = UIScreen.mainScreen.bounds;
    [menu_window.platter removeFromSuperview];
    __IsimMenuPlatter *p = [__IsimMenuPlatter new];
    p.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:0.98] : [UIColor colorWithWhite:0.99 alpha:0.98]; }];
    p.layer.cornerRadius = 8;
    p.layer.shadowColor = UIColor.blackColor.CGColor; p.layer.shadowOpacity = 0.18; p.layer.shadowRadius = 10; p.layer.shadowOffset = CGSizeMake(0, 3);
    p.accessibilityIdentifier = @"isim-edit-menu";
    menu_window.platter = p;
    [menu_window addSubview:p];
    menu_items = elements; menu_stack = nil; menu_page = 0; menu_target = rect;
    menu_dismissed = [dismissed copy];
    menu_build();
    menu_window.hidden = NO;
    NSMutableArray *titles = [NSMutableArray array];
    for (UIMenuElement *e in flatten(elements)) [titles addObject:e.title ?: @""];
    NSLog(@"isim: edit menu shown: %@", [titles componentsJoinedByString:@", "]);
}

/* the standard edit menu of a text view: its suggested actions (and the delegate's say) */
static NSString *loc(NSString *s) { return [[NSBundle bundleForClass:[UIView class]] localizedStringForKey:s value:s table:nil]; }
static UIAction *edit_action(id<IsimEditableText> v, NSString *title, SEL sel) {
    __weak id wv = v;
    UIAction *a = [UIAction actionWithTitle:loc(title) image:nil identifier:NSStringFromSelector(sel) handler:^(UIAction *x) {
        id t = wv; if (t) isim_ui_perform_edit_action(t, sel, nil);
    }];
    return a;
}
NSArray<UIMenuElement *> *isim_ui_text_suggested_actions(id<IsimEditableText> v) {
    NSMutableArray *a = [NSMutableArray array];
    UIResponder *r = (UIResponder *)v;
    struct { NSString *t; SEL s; } std[] = { { @"Cut", @selector(cut:) }, { @"Copy", @selector(copy:) }, { @"Paste", @selector(paste:) },
        { @"Select", @selector(select:) }, { @"Select All", @selector(selectAll:) }, { @"Delete", @selector(delete:) } };
    for (size_t i = 0; i < sizeof std / sizeof *std; i++) {
        if (std[i].s == @selector(delete:)) continue;            /* (iOS shows Delete only for some selections) */
        if ([r canPerformAction:std[i].s withSender:nil]) [a addObject:edit_action(v, std[i].t, std[i].s)];
    }
    SEL rep = NSSelectorFromString(@"_isim_promptForReplace:");
    if ([r canPerformAction:rep withSender:nil]) {
        NSMutableArray *guesses = [NSMutableArray array];
        __weak id wv = v;
        for (NSString *g in [replace_guesses(v) subarrayWithRange:NSMakeRange(0, MIN(4, replace_guesses(v).count))])
            [guesses addObject:[UIAction actionWithTitle:g image:nil identifier:nil handler:^(UIAction *x) {
                id t = wv; if (!t) return;
                NSLog(@"isim: replaced \"%@\" with \"%@\"", selected_text(t), g);
                replace(t, [t _isim_selectedRange], g);
            }]];
        [a addObject:[UIMenu menuWithTitle:loc(@"Replace…") children:guesses]];
    }
    return a;
}
void isim_ui_show_text_menu(id<IsimEditableText> v) {
    UIView *view = (UIView *)v;
    if (!view.window) return;
    NSRange sel = clamp_range([v _isim_selectedRange], text_of(v).length);
    CGRect r;
    if (sel.length) {
        r = CGRectNull;
        for (NSValue *x in [v _isim_selectionRectsForRange:sel]) r = CGRectUnion(r, x.CGRectValue);
    } else r = [v _isim_caretRectForIndex:sel.location];
    if (CGRectIsNull(r)) return;
    r = [view convertRect:r toView:nil];
    r.origin = [view.window convertPoint:r.origin toView:nil];
    NSArray *suggested = isim_ui_text_suggested_actions(v);
    NSArray *items = suggested;
    /* UITextViewDelegate / UITextFieldDelegate textView(_:editMenuForTextIn:suggestedActions:) */
    id d = [view respondsToSelector:@selector(delegate)] ? [(id)view delegate] : nil;
    SEL tv = NSSelectorFromString(@"textView:editMenuForTextInRange:suggestedActions:"), tf = NSSelectorFromString(@"textField:editMenuForCharactersInRange:suggestedActions:");
    SEL dsel = [d respondsToSelector:tv] ? tv : [d respondsToSelector:tf] ? tf : NULL;
    if (dsel) {
        UIMenu *m = ((UIMenu *(*)(id, SEL, id, NSRange, id))objc_msgSend)(d, dsel, view, sel, suggested);
        if (m) items = m.children;
    }
    /* UIMenuController items added by the app */
    for (UIMenuItem *mi in UIMenuController.sharedMenuController.menuItems) {
        if (![(UIResponder *)v canPerformAction:mi.action withSender:UIMenuController.sharedMenuController] &&
            ![[(UIResponder *)v targetForAction:mi.action withSender:nil] respondsToSelector:mi.action]) continue;
        SEL s = mi.action;
        __weak UIResponder *wr = (UIResponder *)v;
        items = [items arrayByAddingObject:[UIAction actionWithTitle:mi.title image:nil identifier:nil handler:^(UIAction *x) {
            id t = [wr targetForAction:s withSender:UIMenuController.sharedMenuController];
            if (t) ((void (*)(id, SEL, id))[t methodForSelector:s])(t, s, UIMenuController.sharedMenuController);
        }]];
    }
    isim_ui_show_edit_menu(r, items, nil);
}

/* ================= UIEditMenuInteraction ================= */
@implementation UIEditMenuConfiguration { id _ident; CGPoint _src; }
+ (instancetype)configurationWithIdentifier:(id<NSCopying>)i sourcePoint:(CGPoint)p { UIEditMenuConfiguration *c = [self new]; c->_ident = i; c->_src = p; return c; }
- (id<NSCopying>)identifier { return _ident; }
- (CGPoint)sourcePoint { return _src; }
@end
@interface __IsimEditMenuAnimator : NSObject <UIEditMenuInteractionAnimating>
@property (nonatomic, strong) NSMutableArray *anims, *comps;
@end
@implementation __IsimEditMenuAnimator
- (instancetype)init { if ((self = [super init])) { _anims = [NSMutableArray array]; _comps = [NSMutableArray array]; } return self; }
- (void)addAnimations:(void (^)(void))a { if (a) [_anims addObject:[a copy]]; }
- (void)addCompletion:(void (^)(void))c { if (c) [_comps addObject:[c copy]]; }
- (void)_run { for (void (^a)(void) in _anims) a(); for (void (^c)(void) in _comps) c(); }
@end
@implementation UIEditMenuInteraction { __weak UIView *_view; __weak id<UIEditMenuInteractionDelegate> _delegate; UIEditMenuConfiguration *_shown; CGPoint _loc; }
- (instancetype)initWithDelegate:(id<UIEditMenuInteractionDelegate>)d { if ((self = [super init])) _delegate = d; return self; }
- (id<UIEditMenuInteractionDelegate>)delegate { return _delegate; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
- (CGPoint)locationInView:(UIView *)v { return [_view convertPoint:_loc toView:v]; }
- (void)presentEditMenuWithConfiguration:(UIEditMenuConfiguration *)c {
    UIView *v = _view;
    if (!v.window) return;
    id<UIEditMenuInteractionDelegate> d = _delegate;
    _loc = c.sourcePoint;
    CGRect target = CGRectMake(c.sourcePoint.x, c.sourcePoint.y, 0, 0);
    if ([d respondsToSelector:@selector(editMenuInteraction:targetRectForConfiguration:)]) {
        CGRect t = [d editMenuInteraction:self targetRectForConfiguration:c];
        if (!CGRectIsNull(t)) target = t;
    }
    /* suggested actions: the standard edit actions the responder chain can perform */
    NSMutableArray *suggested = [NSMutableArray array];
    struct { NSString *t; SEL s; } std[] = { { @"Cut", @selector(cut:) }, { @"Copy", @selector(copy:) }, { @"Paste", @selector(paste:) },
        { @"Select", @selector(select:) }, { @"Select All", @selector(selectAll:) } };
    for (size_t i = 0; i < sizeof std / sizeof *std; i++) {
        SEL s = std[i].s;
        id t = [v targetForAction:s withSender:self];
        if (!t) continue;
        __weak UIView *wv = v;
        [suggested addObject:[UIAction actionWithTitle:loc(std[i].t) image:nil identifier:NSStringFromSelector(s) handler:^(UIAction *a) {
            id tt = [wv targetForAction:s withSender:nil]; if (tt) isim_ui_perform_edit_action(tt, s, nil);
        }]];
    }
    NSArray *items = suggested;
    if ([d respondsToSelector:@selector(editMenuInteraction:menuForConfiguration:suggestedActions:)]) {
        UIMenu *m = [d editMenuInteraction:self menuForConfiguration:c suggestedActions:suggested];
        items = m ? m.children : suggested;
    }
    if (!items.count) return;
    if ([d respondsToSelector:@selector(editMenuInteraction:willPresentMenuForConfiguration:animator:)]) {
        __IsimEditMenuAnimator *a = [__IsimEditMenuAnimator new];
        [d editMenuInteraction:self willPresentMenuForConfiguration:c animator:a]; [a _run];
    }
    _shown = c;
    CGRect r = [v convertRect:target toView:nil];
    r.origin = [v.window convertPoint:r.origin toView:nil];
    __weak UIEditMenuInteraction *ws = self;
    isim_ui_show_edit_menu(r, items, ^{
        UIEditMenuInteraction *s = ws; if (!s) return;
        UIEditMenuConfiguration *cfg = s->_shown; s->_shown = nil;
        id<UIEditMenuInteractionDelegate> dd = s->_delegate;
        if (cfg && [dd respondsToSelector:@selector(editMenuInteraction:willDismissMenuForConfiguration:animator:)]) {
            __IsimEditMenuAnimator *a = [__IsimEditMenuAnimator new];
            [dd editMenuInteraction:s willDismissMenuForConfiguration:cfg animator:a]; [a _run];
        }
    });
}
- (void)dismissMenu { if (_shown) isim_ui_hide_edit_menu(); }
- (void)reloadVisibleMenu { UIEditMenuConfiguration *c = _shown; if (c) [self presentEditMenuWithConfiguration:c]; }
@end

/* ================= UIMenuController (deprecated, same platter) ================= */
NSNotificationName const UIMenuControllerWillShowMenuNotification = @"UIMenuControllerWillShowMenuNotification";
NSNotificationName const UIMenuControllerDidShowMenuNotification = @"UIMenuControllerDidShowMenuNotification";
NSNotificationName const UIMenuControllerWillHideMenuNotification = @"UIMenuControllerWillHideMenuNotification";
NSNotificationName const UIMenuControllerDidHideMenuNotification = @"UIMenuControllerDidHideMenuNotification";
@implementation UIMenuItem
- (instancetype)initWithTitle:(NSString *)t action:(SEL)a { if ((self = [super init])) { _title = [t copy]; _action = a; } return self; }
@end
@implementation UIMenuController
+ (UIMenuController *)sharedMenuController { static UIMenuController *m; if (!m) m = [UIMenuController new]; return m; }
- (BOOL)isMenuVisible { return isim_ui_edit_menu_visible(); }
- (CGRect)menuFrame { return isim_ui_edit_menu_visible() ? menu_window.platter.frame : CGRectZero; }
- (void)showMenuFromView:(UIView *)v rect:(CGRect)rect {
    if (!v.window) return;
    NSMutableArray *items = [NSMutableArray array];
    struct { NSString *t; SEL s; } std[] = { { @"Cut", @selector(cut:) }, { @"Copy", @selector(copy:) }, { @"Paste", @selector(paste:) },
        { @"Select", @selector(select:) }, { @"Select All", @selector(selectAll:) } };
    UIResponder *fr = isim_ui_first_responder() ?: v;
    for (size_t i = 0; i < sizeof std / sizeof *std; i++) {
        SEL s = std[i].s;
        if (![fr targetForAction:s withSender:self]) continue;
        __weak UIResponder *wr = fr;
        [items addObject:[UIAction actionWithTitle:loc(std[i].t) image:nil identifier:nil handler:^(UIAction *a) {
            id t = [wr targetForAction:s withSender:nil]; if (t) isim_ui_perform_edit_action(t, s, nil);
        }]];
    }
    for (UIMenuItem *mi in _menuItems) {
        SEL s = mi.action;
        if (![fr targetForAction:s withSender:self]) continue;
        __weak UIResponder *wr = fr;
        [items addObject:[UIAction actionWithTitle:mi.title image:nil identifier:nil handler:^(UIAction *a) {
            id t = [wr targetForAction:s withSender:UIMenuController.sharedMenuController]; if (t) ((void (*)(id, SEL, id))[t methodForSelector:s])(t, s, UIMenuController.sharedMenuController);
        }]];
    }
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc postNotificationName:UIMenuControllerWillShowMenuNotification object:self];
    CGRect r = [v convertRect:rect toView:nil];
    r.origin = [v.window convertPoint:r.origin toView:nil];
    isim_ui_show_edit_menu(r, items, ^{
        [nc postNotificationName:UIMenuControllerWillHideMenuNotification object:self];
        [nc postNotificationName:UIMenuControllerDidHideMenuNotification object:self];
    });
    [nc postNotificationName:UIMenuControllerDidShowMenuNotification object:self];
}
- (void)hideMenuFromView:(UIView *)v { isim_ui_hide_edit_menu(); }
- (void)hideMenu { isim_ui_hide_edit_menu(); }
@end

/* ================= loupe ================= */
@interface __IsimLoupeWindow : UIWindow
@property (nonatomic, weak) UIWindow *source;
@property (nonatomic) CGPoint focus;       /* screen point magnified */
@end
@implementation __IsimLoupeWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIView *)hitTest:(CGPoint)p withEvent:(UIEvent *)e { return nil; }
- (void)_isim_drawContent {
    UIWindow *src = _source;
    if (!src) return;
    /* iOS 17 loupe: a capsule above the finger showing the text around the caret, slightly magnified */
    CGFloat w = 120, h = 44, k = 1.25;
    CGRect r = CGRectMake(_focus.x - w / 2, _focus.y - h - 30, w, h);
    double shadow[4] = { 0, 0, 0, 0.18 };
    isim_gfx_fill_rounded(r.origin.x, r.origin.y + 2, w, h, h / 2, shadow);
    isim_gfx_save();
    isim_gfx_clip_rounded(r.origin.x, r.origin.y, w, h, h / 2);
    double bg[4]; isim_ui_rgba(UIColor.systemBackgroundColor, bg);
    isim_gfx_fill_rounded(r.origin.x, r.origin.y, w, h, h / 2, bg);
    isim_gfx_translate(CGRectGetMidX(r), CGRectGetMidY(r));
    isim_gfx_scale(k, k);
    isim_gfx_translate(-_focus.x, -_focus.y);
    [src _isim_render];
    isim_gfx_restore();
    double line[4]; isim_ui_rgba(UIColor.separatorColor, line);
    isim_gfx_stroke_rounded(r.origin.x, r.origin.y, w, h, h / 2, 0.5, line);
}
@end
static __IsimLoupeWindow *loupe;
static void show_loupe(UIView *v, CGPoint windowPoint) {
    if (!loupe) {
        loupe = [[__IsimLoupeWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        loupe.windowLevel = 16000000;
        loupe.backgroundColor = UIColor.clearColor;
        loupe.accessibilityIdentifier = @"isim-loupe";
    }
    loupe.frame = UIScreen.mainScreen.bounds;
    loupe.source = v.window;
    loupe.focus = [v.window convertPoint:windowPoint toView:nil];
    if (loupe.hidden) NSLog(@"isim: loupe shown");
    loupe.hidden = NO;
    isim_ui_set_needs_display();
}
static void hide_loupe(void) { if (loupe && !loupe.hidden) { loupe.hidden = YES; isim_ui_set_needs_display(); } }

/* ================= selection interaction ================= */
enum { TI_NONE, TI_PENDING, TI_LOUPE, TI_HANDLE_START, TI_HANDLE_END };
@interface UIView (IsimTextItems)                   /* UITextView: detected items */
- (BOOL)_isim_tapItemAt:(CGPoint)p;
- (BOOL)_isim_longPressItemAt:(CGPoint)p;
@end
@interface __IsimTextInteraction : UIGestureRecognizer
@property (nonatomic) int mode;
@property (nonatomic) CGPoint downAt;          /* in the view */
@property (nonatomic) NSUInteger generation, anchor;
@end
@implementation __IsimTextInteraction
- (BOOL)_isim_acceptsExtraTouches { return NO; }
- (id<IsimEditableText>)_text { return (id<IsimEditableText>)self.view; }
- (void)_begin { self.state = UIGestureRecognizerStateBegan; [self _fire]; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    id<IsimEditableText> v = [self _text];
    UIView *view = self.view;
    CGPoint p = [touch locationInView:view];
    switch (phase) {
    case UITouchPhaseBegan: {
        self.downAt = p; self.mode = TI_PENDING; self.state = UIGestureRecognizerStatePossible;
        NSRange sel = [v _isim_selectedRange];
        if (view.isFirstResponder && sel.length) {           /* grabbing a selection handle */
            CGRect a = [v _isim_caretRectForIndex:sel.location], b = [v _isim_caretRectForIndex:NSMaxRange(sel)];
            if (hypot(p.x - a.origin.x, p.y - CGRectGetMidY(a)) < 22) { self.mode = TI_HANDLE_START; self.anchor = NSMaxRange(sel); }
            else if (hypot(p.x - b.origin.x, p.y - CGRectGetMidY(b)) < 22) { self.mode = TI_HANDLE_END; self.anchor = sel.location; }
            if (self.mode != TI_PENDING) { isim_ui_hide_edit_menu(); [self _begin]; show_loupe(view, [view convertPoint:p toView:nil]); return; }
        }
        NSUInteger gen = ++self.generation;
        __weak __IsimTextInteraction *ws = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __IsimTextInteraction *s = ws;
            if (!s || s.generation != gen || s.mode != TI_PENDING) return;
            id<IsimEditableText> t = [s _text];
            UIView *tv = s.view;
            if (![t _isim_isEditable] && !(([tv respondsToSelector:@selector(isSelectable)] && [(id)tv isSelectable]))) return;
            if (![t _isim_isEditable] && [tv respondsToSelector:@selector(_isim_longPressItemAt:)] && [(id)tv _isim_longPressItemAt:s.downAt]) {
                s.mode = TI_NONE; return;                   /* a detected item's menu (UITextView) */
            }
            s.mode = TI_LOUPE;
            [s _begin];
            if ([t _isim_isEditable] && !tv.isFirstResponder) [tv becomeFirstResponder];
            isim_ui_hide_edit_menu();
            isim_ti_unmark(t);
            isim_ti_set_selection(t, NSMakeRange([t _isim_indexAtPoint:s.downAt], 0));
            show_loupe(tv, [tv convertPoint:s.downAt toView:nil]);
        });
        return; }
    case UITouchPhaseMoved:
        if (self.mode == TI_PENDING) {
            if (hypot(p.x - self.downAt.x, p.y - self.downAt.y) > 10) { self.mode = TI_NONE; self.generation++; self.state = UIGestureRecognizerStateFailed; }
            return;
        }
        if (self.mode == TI_LOUPE) {
            isim_ti_set_selection(v, NSMakeRange([v _isim_indexAtPoint:p], 0));
            show_loupe(view, [view convertPoint:p toView:nil]);
        } else if (self.mode == TI_HANDLE_START || self.mode == TI_HANDLE_END) {
            NSUInteger i = [v _isim_indexAtPoint:p], a = self.anchor;
            if (i == a) i = self.mode == TI_HANDLE_END ? a + 1 : (a ? a - 1 : 0);      /* keep at least one character */
            isim_ti_set_selection(v, i < a ? NSMakeRange(i, a - i) : NSMakeRange(a, i - a));
            show_loupe(view, [view convertPoint:p toView:nil]);
        }
        if (self.mode != TI_NONE) self.state = UIGestureRecognizerStateChanged;
        return;
    case UITouchPhaseEnded: case UITouchPhaseCancelled: {
        int mode = self.mode;
        self.mode = TI_NONE; self.generation++;
        hide_loupe();
        if (phase == UITouchPhaseCancelled) { self.state = UIGestureRecognizerStatePossible; return; }
        if (mode == TI_LOUPE || mode == TI_HANDLE_START || mode == TI_HANDLE_END) {
            self.state = UIGestureRecognizerStateEnded; [self _fire]; self.state = UIGestureRecognizerStatePossible;
            isim_ui_show_text_menu(v);
            return;
        }
        if (mode == TI_PENDING && CGRectContainsPoint(view.bounds, p)) [self _tap:touch.tapCount at:p];
        self.state = UIGestureRecognizerStatePossible;
        return; }
    default: return;
    }
}
- (void)_tap:(NSUInteger)count at:(CGPoint)p {
    id<IsimEditableText> v = [self _text];
    UIView *view = self.view;
    BOOL editable = [v _isim_isEditable], selectable = editable || ([view respondsToSelector:@selector(isSelectable)] && [(id)view isSelectable]);
    if (!selectable) return;
    if (count == 1 && !editable && [view respondsToSelector:@selector(_isim_tapItemAt:)] && [(id)view _isim_tapItemAt:p]) return;   /* detected items */
    NSString *s = text_of(v);
    BOOL wasEditing = view.isFirstResponder;
    if (editable && wasEditing) isim_ui_keyboard_responder_check();      /* (a finger tap after Scribble brings the keyboard back) */
    if (editable && !wasEditing && ![view becomeFirstResponder]) return;
    NSUInteger i = [v _isim_indexAtPoint:p];
    isim_ti_unmark(v);
    if (count >= 3) {
        NSRange r = [view isKindOfClass:[UITextField class]] && ![s containsString:@"\n"] ? NSMakeRange(0, s.length) : paragraph_range_at(s, i);
        isim_ti_set_selection(v, r);
        if (r.length) isim_ui_show_text_menu(v);
        return;
    }
    if (count == 2) {
        NSRange w = word_range_at(s, i);
        if (w.location != NSNotFound && w.length) { isim_ti_set_selection(v, w); isim_ui_show_text_menu(v); }
        return;
    }
    NSRange before = [v _isim_selectedRange];
    NSUInteger c = snap_to_word(s, i);
    if (wasEditing && !before.length && before.location == c) {
        /* a tap on the caret toggles the edit menu */
        if (isim_ui_edit_menu_visible()) isim_ui_hide_edit_menu(); else isim_ui_show_text_menu(v);
        return;
    }
    isim_ui_hide_edit_menu();
    if (!editable) { isim_ti_set_selection(v, NSMakeRange(c, 0)); return; }
    isim_ti_set_selection(v, NSMakeRange(c, 0));
}
@end
void isim_ui_text_install(UIView *v) {
    __IsimTextInteraction *g = [[__IsimTextInteraction alloc] initWithTarget:nil action:NULL];
    g.cancelsTouchesInView = NO;
    [g _isim_setExclusive:YES];
    g.name = @"isim.textInteraction";
    [v addGestureRecognizer:g];
}
void isim_ui_text_did_end_editing(id<IsimEditableText> v) {
    isim_ti_unmark(v);
    isim_ui_hide_edit_menu();
    hide_loupe();
}
void isim_ui_text_selection_changed(id<IsimEditableText> v) {
    isim_ui_set_needs_display();
    isim_ui_keyboard_suggestions_changed();
}
void isim_ui_text_touch(id<IsimEditableText> v, UITouch *touch, UITouchPhase phase) {}

/* ================= accessors used by ISIM_TEXT_INPUT_METHODS ================= */
id isim_ti_input_delegate(id v) { return state_of(v).inputDelegate; }
void isim_ti_set_input_delegate(id v, id d) { state_of(v).inputDelegate = d; }
NSDictionary *isim_ti_marked_style(id v) { return state_of(v).markedTextStyle; }
void isim_ti_set_marked_style(id v, NSDictionary *d) { state_of(v).markedTextStyle = d; }
id<UITextInputTokenizer> isim_ti_tokenizer(id v) {
    __IsimTextState *st = state_of(v);
    if (!st.tokenizer) st.tokenizer = [[UITextInputStringTokenizer alloc] initWithTextInput:v];
    return st.tokenizer;
}
NSArray<UITextSelectionRect *> *isim_ti_selection_rect_objects(id<IsimEditableText> v, NSRange r) {
    NSArray *rects = [v _isim_selectionRectsForRange:r];
    NSMutableArray *out = [NSMutableArray array];
    for (NSUInteger i = 0; i < rects.count; i++) {
        __IsimSelectionRect *x = [__IsimSelectionRect new];
        x.isimRect = [rects[i] CGRectValue]; x.isimStart = i == 0; x.isimEnd = i + 1 == rects.count;
        [out addObject:x];
    }
    return out;
}

/* ================= hardware keyboard navigation ================= */
extern UIKeyModifierFlags isim_ui_current_modifiers(int hostmods);
static NSUInteger line_move(id<IsimEditableText> v, NSUInteger i, int dir) {
    CGRect c = [v _isim_caretRectForIndex:i];
    CGPoint p = CGPointMake(c.origin.x, CGRectGetMidY(c) + dir * c.size.height);
    if (p.y < 0) return 0;
    NSUInteger j = [v _isim_indexAtPoint:p];
    if (j == i) return dir > 0 ? text_of(v).length : 0;
    return j;
}
BOOL isim_ui_text_handle_key(id<IsimEditableText> v, int hid, int hostmods) {
    UIKeyModifierFlags m = isim_ui_current_modifiers(hostmods);
    BOOL shift = (m & UIKeyModifierShift) != 0, cmd = (m & (UIKeyModifierCommand | UIKeyModifierControl)) != 0, alt = (m & UIKeyModifierAlternate) != 0;
    NSString *s = text_of(v);
    NSRange sel = clamp_range([v _isim_selectedRange], s.length);
    UIResponder *r = (UIResponder *)v;
    /* Cmd/Ctrl shortcuts */
    if (cmd && !alt) {
        SEL a = hid == 0x04 ? @selector(selectAll:) : hid == 0x06 ? @selector(copy:) : hid == 0x1B ? @selector(cut:) : hid == 0x19 ? @selector(paste:) : NULL;
        if (a) { if ([r canPerformAction:a withSender:nil]) isim_ui_perform_edit_action(r, a, nil); return YES; }
    }
    if (hid == 0x4C && [v _isim_isEditable]) {                 /* forward delete */
        isim_ti_unmark(v);
        if (sel.length) replace(v, sel, @"");
        else if (sel.location < s.length) replace(v, [s rangeOfComposedCharacterSequenceAtIndex:sel.location], @"");
        return YES;
    }
    if (hid < 0x4F || hid > 0x52) return NO;                  /* arrows: 4F right 50 left 51 down 52 up */
    isim_ti_unmark(v);
    isim_ui_hide_edit_menu();
    /* the moving end: the caret, or the end opposite the anchor when extending */
    static __weak id anchor_view; static NSUInteger anchor;
    if (!shift || anchor_view != v || !(anchor == sel.location || anchor == NSMaxRange(sel))) { anchor_view = v; anchor = sel.location; }
    NSUInteger head = anchor == sel.location ? NSMaxRange(sel) : sel.location;
    if (!shift && sel.length && (hid == 0x4F || hid == 0x50) && !cmd && !alt) {      /* collapse a selection to its edge */
        isim_ti_set_selection(v, NSMakeRange(hid == 0x4F ? NSMaxRange(sel) : sel.location, 0));
        return YES;
    }
    NSUInteger n = head;
    UITextInputStringTokenizer *tok = [[UITextInputStringTokenizer alloc] initWithTextInput:(id)v];
    switch (hid) {
    case 0x4F:
        if (cmd) n = NSMaxRange(paragraph_range_at(s, head));
        else if (alt) n = (NSUInteger)isim_ti_off([tok positionFromPosition:isim_ti_pos((NSInteger)head) toBoundary:UITextGranularityWord inDirection:UITextStorageDirectionForward]);
        else if (head < s.length) n = NSMaxRange([s rangeOfComposedCharacterSequenceAtIndex:head]);
        break;
    case 0x50:
        if (cmd) n = paragraph_range_at(s, head).location;
        else if (alt) n = (NSUInteger)isim_ti_off([tok positionFromPosition:isim_ti_pos((NSInteger)head) toBoundary:UITextGranularityWord inDirection:UITextStorageDirectionBackward]);
        else if (head > 0) n = [s rangeOfComposedCharacterSequenceAtIndex:head - 1].location;
        break;
    case 0x51: n = cmd ? s.length : line_move(v, head, 1); break;
    case 0x52: n = cmd ? 0 : line_move(v, head, -1); break;
    }
    if (shift) isim_ti_set_selection(v, n < anchor ? NSMakeRange(n, anchor - n) : NSMakeRange(anchor, n - anchor));
    else { isim_ti_set_selection(v, NSMakeRange(n, 0)); anchor = n; }
    return YES;
}
