/* UITextInput methods shared by UITextField and UITextView (expanded inside each @implementation). The class provides
 * the IsimEditableText primitives (UIKitInputPrivate.h); everything else is in UITextInput.m. */
#pragma once
#import "UIKitInputPrivate.h"

UITextPosition *isim_ti_pos(NSInteger offset);
UITextRange *isim_ti_range(NSRange r);
NSInteger isim_ti_off(UITextPosition *p);
NSRange isim_ti_nsrange(UITextRange *r);
void isim_ti_set_selection(id<IsimEditableText> v, NSRange r);
void isim_ti_insert(id<IsimEditableText> v, NSString *text);
void isim_ti_delete_backward(id<IsimEditableText> v);
void isim_ti_set_marked(id<IsimEditableText> v, NSString *_Nullable text, NSRange selInMarked);
void isim_ti_unmark(id<IsimEditableText> v);
BOOL isim_ti_can_perform(id<IsimEditableText> v, SEL a);
void isim_ti_copy(id<IsimEditableText> v);
void isim_ti_cut(id<IsimEditableText> v);
void isim_ti_paste(id<IsimEditableText> v);
void isim_ti_delete(id<IsimEditableText> v);
void isim_ti_select(id<IsimEditableText> v);
void isim_ti_select_all(id<IsimEditableText> v);
id isim_ti_input_delegate(id v);
void isim_ti_set_input_delegate(id v, id d);
NSDictionary *_Nullable isim_ti_marked_style(id v);
void isim_ti_set_marked_style(id v, NSDictionary *_Nullable d);
id<UITextInputTokenizer> isim_ti_tokenizer(id v);
void isim_ui_text_install(UIView *v);
void isim_ui_text_draw_selection_rects(id<IsimEditableText> v);
void isim_ui_text_draw_spelling(id<IsimEditableText> v);
void isim_ui_show_text_menu(id<IsimEditableText> v);
void isim_ui_hide_edit_menu(void);

#define ISIM_TI_LEN ((NSInteger)[self _isim_plainText].length)
#define ISIM_TEXT_INPUT_METHODS \
- (NSString *)textInRange:(UITextRange *)r { NSString *s = [self _isim_plainText]; NSRange x = isim_ti_nsrange(r); if (NSMaxRange(x) > s.length) return nil; return [s substringWithRange:x]; } \
- (void)replaceRange:(UITextRange *)r withText:(NSString *)t { [self _isim_replaceRange:isim_ti_nsrange(r) withText:t]; } \
- (UITextRange *)selectedTextRange { return isim_ti_range([self _isim_selectedRange]); } \
- (void)setSelectedTextRange:(UITextRange *)r { if (r) isim_ti_set_selection(self, isim_ti_nsrange(r)); } \
- (UITextRange *)markedTextRange { NSRange m = isim_ui_marked_range(self); return m.location == NSNotFound ? nil : isim_ti_range(m); } \
- (NSDictionary *)markedTextStyle { return isim_ti_marked_style(self); } \
- (void)setMarkedTextStyle:(NSDictionary *)d { isim_ti_set_marked_style(self, d); } \
- (void)setMarkedText:(NSString *)t selectedRange:(NSRange)r { isim_ti_set_marked(self, t, r); } \
- (void)unmarkText { isim_ti_unmark(self); } \
- (UITextPosition *)beginningOfDocument { return isim_ti_pos(0); } \
- (UITextPosition *)endOfDocument { return isim_ti_pos(ISIM_TI_LEN); } \
- (UITextRange *)textRangeFromPosition:(UITextPosition *)a toPosition:(UITextPosition *)b { \
    NSInteger x = isim_ti_off(a), y = isim_ti_off(b); if (MIN(x, y) < 0 || MAX(x, y) > ISIM_TI_LEN) return nil; \
    return isim_ti_range(NSMakeRange((NSUInteger)MIN(x, y), (NSUInteger)labs(y - x))); } \
- (UITextPosition *)positionFromPosition:(UITextPosition *)p offset:(NSInteger)o { NSInteger x = isim_ti_off(p) + o; return x < 0 || x > ISIM_TI_LEN ? nil : isim_ti_pos(x); } \
- (UITextPosition *)positionFromPosition:(UITextPosition *)p inDirection:(UITextLayoutDirection)d offset:(NSInteger)o { \
    NSInteger x = isim_ti_off(p); \
    if (d == UITextLayoutDirectionRight || d == UITextLayoutDirectionLeft) { x += d == UITextLayoutDirectionRight ? o : -o; return x < 0 || x > ISIM_TI_LEN ? nil : isim_ti_pos(x); } \
    CGRect c = [self _isim_caretRectForIndex:(NSUInteger)x]; \
    CGPoint q = CGPointMake(c.origin.x, CGRectGetMidY(c) + (d == UITextLayoutDirectionDown ? 1 : -1) * o * c.size.height); \
    return isim_ti_pos((NSInteger)[self _isim_indexAtPoint:q]); } \
- (NSComparisonResult)comparePosition:(UITextPosition *)a toPosition:(UITextPosition *)b { NSInteger x = isim_ti_off(a), y = isim_ti_off(b); return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame; } \
- (NSInteger)offsetFromPosition:(UITextPosition *)a toPosition:(UITextPosition *)b { return isim_ti_off(b) - isim_ti_off(a); } \
- (id<UITextInputDelegate>)inputDelegate { return isim_ti_input_delegate(self); } \
- (void)setInputDelegate:(id<UITextInputDelegate>)d { isim_ti_set_input_delegate(self, d); } \
- (id<UITextInputTokenizer>)tokenizer { return isim_ti_tokenizer(self); } \
- (UITextPosition *)positionWithinRange:(UITextRange *)r farthestInDirection:(UITextLayoutDirection)d { \
    NSRange x = isim_ti_nsrange(r); return isim_ti_pos((NSInteger)(d == UITextLayoutDirectionRight || d == UITextLayoutDirectionDown ? NSMaxRange(x) : x.location)); } \
- (UITextRange *)characterRangeByExtendingPosition:(UITextPosition *)p inDirection:(UITextLayoutDirection)d { \
    NSInteger x = isim_ti_off(p); BOOL fwd = d == UITextLayoutDirectionRight || d == UITextLayoutDirectionDown; \
    NSInteger y = fwd ? MIN(x + 1, ISIM_TI_LEN) : MAX(x - 1, 0); return isim_ti_range(NSMakeRange((NSUInteger)MIN(x, y), (NSUInteger)labs(y - x))); } \
- (NSWritingDirection)baseWritingDirectionForPosition:(UITextPosition *)p inDirection:(UITextStorageDirection)d { return NSWritingDirectionLeftToRight; } \
- (void)setBaseWritingDirection:(NSWritingDirection)w forRange:(UITextRange *)r {} \
- (CGRect)firstRectForRange:(UITextRange *)r { NSArray *a = [self _isim_selectionRectsForRange:isim_ti_nsrange(r)]; return a.count ? [a[0] CGRectValue] : CGRectNull; } \
- (CGRect)caretRectForPosition:(UITextPosition *)p { return [self _isim_caretRectForIndex:(NSUInteger)MAX(0, MIN(isim_ti_off(p), ISIM_TI_LEN))]; } \
- (NSArray<UITextSelectionRect *> *)selectionRectsForRange:(UITextRange *)r { return isim_ti_selection_rect_objects(self, isim_ti_nsrange(r)); } \
- (UITextPosition *)closestPositionToPoint:(CGPoint)p { return isim_ti_pos((NSInteger)[self _isim_indexAtPoint:p]); } \
- (UITextPosition *)closestPositionToPoint:(CGPoint)p withinRange:(UITextRange *)r { \
    NSRange x = isim_ti_nsrange(r); NSUInteger i = [self _isim_indexAtPoint:p]; return isim_ti_pos((NSInteger)MIN(MAX(i, x.location), NSMaxRange(x))); } \
- (UITextRange *)characterRangeAtPoint:(CGPoint)p { \
    NSString *s = [self _isim_plainText]; NSUInteger i = [self _isim_indexAtPoint:p]; \
    if (i >= s.length) return s.length ? isim_ti_range([s rangeOfComposedCharacterSequenceAtIndex:s.length - 1]) : nil; \
    return isim_ti_range([s rangeOfComposedCharacterSequenceAtIndex:i]); } \
- (UIView *)textInputView { return self; } \
- (BOOL)canPerformAction:(SEL)a withSender:(id)sender { \
    if (a == @selector(cut:) || a == @selector(copy:) || a == @selector(paste:) || a == @selector(select:) || a == @selector(selectAll:) || a == @selector(delete:) || a == NSSelectorFromString(@"_isim_promptForReplace:")) \
        return isim_ti_can_perform(self, a); \
    return [super canPerformAction:a withSender:sender]; } \
- (void)cut:(id)sender { isim_ti_cut(self); } \
- (void)copy:(id)sender { isim_ti_copy(self); } \
- (void)paste:(id)sender { isim_ti_paste(self); } \
- (void)select:(id)sender { isim_ti_select(self); } \
- (void)selectAll:(id)sender { isim_ti_select_all(self); } \
- (void)delete:(id)sender { isim_ti_delete(self); } \
- (void)_isim_promptForReplace:(id)sender { isim_ui_show_text_menu(self); }

NSArray<UITextSelectionRect *> *isim_ti_selection_rect_objects(id<IsimEditableText> v, NSRange r);
