/* Text input members from the documentation sweep (#9) shared by UITextField and UITextView: the new traits (math
 * expression completion, grammar checking, number pad popover), selection affinity, text placeholders, attributed
 * text in a range, inserting attributed text, the unobscured content rect; UITextInputContext. Stored outside the
 * instances (associated objects): apps' subclasses keep their sizes. */
#import "UITextInputImpl.h"
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
static char kMath, kGrammar, kNumberPopover, kAffinity, kPlaceholders;

@interface UITextPlaceholder ()
@property (nonatomic, copy) NSArray<UITextSelectionRect *> *rects;
@property (nonatomic) NSUInteger isimLocation;
@end
@implementation UITextPlaceholder @end
@interface __IsimPlaceholderRect : UITextSelectionRect
@property (nonatomic) CGRect isimRect;
@end
@implementation __IsimPlaceholderRect
- (CGRect)rect { return _isimRect; }
- (BOOL)containsStart { return YES; }
- (BOOL)containsEnd { return YES; }
@end
UITextSelectionRect *isim_ui_selection_rect(CGRect r) { __IsimPlaceholderRect *x = [__IsimPlaceholderRect new]; x.isimRect = r; return x; }

@implementation UITextInputContext
+ (instancetype)current { static UITextInputContext *c; if (!c) c = [self new]; return c; }
@end

/* a text placeholder: a box of the given size at the caret (the text is not changed) */
static UITextPlaceholder *insert_placeholder(UIView<IsimEditableText> *v, CGSize size) {
    NSUInteger at = [v _isim_selectedRange].location;
    CGRect c = [v _isim_caretRectForIndex:at];
    UITextPlaceholder *p = [UITextPlaceholder new];
    p.isimLocation = at;
    __IsimPlaceholderRect *r = [__IsimPlaceholderRect new];
    r.isimRect = CGRectMake(c.origin.x, c.origin.y, size.width, fmax(size.height, c.size.height));
    p.rects = @[ r ];
    NSMutableArray *a = get(v, &kPlaceholders) ?: [NSMutableArray array];
    [a addObject:p]; put(v, &kPlaceholders, a);
    NSLog(@"isim: text placeholder %.0fx%.0f at %lu (%.0f,%.0f)", size.width, size.height, (unsigned long)at, c.origin.x, c.origin.y);
    return p;
}
static void remove_placeholder(UIView *v, UITextPlaceholder *p) { [get(v, &kPlaceholders) removeObject:p]; }
/* the part of the view the keyboard does not cover (view coordinates) */
static CGRect unobscured(UIView *v) {
    CGRect b = v.bounds;
    if ([v isKindOfClass:[UIScrollView class]]) b.origin = ((UIScrollView *)v).contentOffset;
    CGRect kb = isim_ui_keyboard_frame();
    if (!v.window || CGRectIsEmpty(kb)) return b;
    CGRect inView = [v convertRect:kb fromView:nil];
    if (CGRectIntersectsRect(inView, b) && inView.origin.y > b.origin.y) b.size.height = inView.origin.y - b.origin.y;
    return b;
}

#define ISIM_INPUT_EXTRAS \
- (UITextMathExpressionCompletionType)mathExpressionCompletionType { return [get(self, &kMath) integerValue]; } \
- (void)setMathExpressionCompletionType:(UITextMathExpressionCompletionType)t { put(self, &kMath, @(t)); } \
- (UITextGrammarCheckingType)grammarCheckingType { return [get(self, &kGrammar) integerValue]; } \
- (void)setGrammarCheckingType:(UITextGrammarCheckingType)t { put(self, &kGrammar, @(t)); } \
- (BOOL)allowsNumberPadPopover { return [get(self, &kNumberPopover) boolValue]; } \
- (void)setAllowsNumberPadPopover:(BOOL)b { put(self, &kNumberPopover, @(b)); } \
- (UITextStorageDirection)selectionAffinity { return [get(self, &kAffinity) integerValue]; } \
- (void)setSelectionAffinity:(UITextStorageDirection)d { put(self, &kAffinity, @(d)); } \
- (CGAffineTransform)caretTransformForPosition:(UITextPosition *)p { return CGAffineTransformIdentity; } \
- (UITextPlaceholder *)insertTextPlaceholderWithSize:(CGSize)size { return insert_placeholder((UIView<IsimEditableText> *)self, size); } \
- (void)removeTextPlaceholder:(UITextPlaceholder *)p { remove_placeholder(self, p); } \
- (CGRect)unobscuredContentRect { return unobscured(self); } \
- (void)willPresentWritingTools {} \
- (void)didDismissWritingTools {}

@interface UITextField (IsimInputExtras) <UITextInput>
@end
@implementation UITextField (IsimInputExtras)
ISIM_INPUT_EXTRAS
- (NSAttributedString *)attributedTextInRange:(UITextRange *)r {
    NSRange x = isim_ti_nsrange(r); NSAttributedString *a = self.attributedText;
    return NSMaxRange(x) <= a.length ? [a attributedSubstringFromRange:x] : [NSAttributedString new];
}
- (void)insertAttributedText:(NSAttributedString *)s { [self insertText:s.string]; }
@end

@interface UITextView (IsimInputExtras) <UITextInput>
@end
@implementation UITextView (IsimInputExtras)
ISIM_INPUT_EXTRAS
- (NSAttributedString *)attributedTextInRange:(UITextRange *)r {
    NSRange x = isim_ti_nsrange(r); NSAttributedString *a = self.attributedText;
    return NSMaxRange(x) <= a.length ? [a attributedSubstringFromRange:x] : [NSAttributedString new];
}
/* keeps its attributes when the text view allows editing them (else it is typed in the typing attributes) */
- (void)insertAttributedText:(NSAttributedString *)s {
    if (!self.allowsEditingTextAttributes || !self.editable) { [self insertText:s.string]; return; }
    NSRange sel = self.selectedRange;
    NSTextStorage *ts = self.textStorage;
    if (NSMaxRange(sel) > ts.length) return;
    [ts replaceCharactersInRange:sel withAttributedString:s];
    self.selectedRange = NSMakeRange(sel.location + s.length, 0);
    id<UITextViewDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(textViewDidChange:)]) [d textViewDidChange:self];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextViewTextDidChangeNotification object:self];
}
@end
