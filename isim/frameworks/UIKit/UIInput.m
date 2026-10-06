/* Accessibility properties, UILongPressGestureRecognizer, and custom keyboard support
 * (UIInputView, UIInputViewController, its text document proxy, UITextInputMode). */
#import "UIKitPrivate.h"
#import <objc/runtime.h>
#include <math.h>

/* ---------------- accessibility (stored; used by the scripted test driver) ---------------- */
const UIAccessibilityTraits UIAccessibilityTraitNone = 0, UIAccessibilityTraitButton = 1 << 0, UIAccessibilityTraitLink = 1 << 1,
    UIAccessibilityTraitImage = 1 << 2, UIAccessibilityTraitSelected = 1 << 3, UIAccessibilityTraitPlaysSound = 1 << 4,
    UIAccessibilityTraitKeyboardKey = 1 << 5, UIAccessibilityTraitStaticText = 1 << 6, UIAccessibilityTraitSummaryElement = 1 << 7,
    UIAccessibilityTraitNotEnabled = 1 << 8, UIAccessibilityTraitUpdatesFrequently = 1 << 9, UIAccessibilityTraitSearchField = 1 << 10,
    UIAccessibilityTraitAdjustable = 1 << 12, UIAccessibilityTraitHeader = 1 << 16;

static char k_label, k_hint, k_value, k_traits, k_element, k_ident, k_hidden, k_modal;
@implementation NSObject (UIAccessibility)
- (NSString *)accessibilityLabel {
    NSString *l = objc_getAssociatedObject(self, &k_label);
    if (l || ![self isKindOfClass:[UIView class]]) return l;
    if ([self isKindOfClass:[UILabel class]]) return ((UILabel *)self).text;                  /* UIKit defaults */
    if ([self isKindOfClass:[UIButton class]]) return ((UIButton *)self).currentTitle;
    return nil;
}
- (void)setAccessibilityLabel:(NSString *)v { objc_setAssociatedObject(self, &k_label, v, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSString *)accessibilityHint { return objc_getAssociatedObject(self, &k_hint); }
- (void)setAccessibilityHint:(NSString *)v { objc_setAssociatedObject(self, &k_hint, v, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSString *)accessibilityValue { return objc_getAssociatedObject(self, &k_value); }
- (void)setAccessibilityValue:(NSString *)v { objc_setAssociatedObject(self, &k_value, v, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (UIAccessibilityTraits)accessibilityTraits {
    NSNumber *n = objc_getAssociatedObject(self, &k_traits);
    if (n) return n.unsignedLongLongValue;
    if ([self isKindOfClass:[UIButton class]]) return UIAccessibilityTraitButton;
    if ([self isKindOfClass:[UILabel class]]) return UIAccessibilityTraitStaticText;
    return UIAccessibilityTraitNone;
}
- (void)setAccessibilityTraits:(UIAccessibilityTraits)v { objc_setAssociatedObject(self, &k_traits, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)isAccessibilityElement {
    NSNumber *n = objc_getAssociatedObject(self, &k_element);
    return n ? n.boolValue : ([self isKindOfClass:[UIControl class]] || [self isKindOfClass:[UILabel class]]);
}
- (void)setIsAccessibilityElement:(BOOL)v { objc_setAssociatedObject(self, &k_element, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)accessibilityElementsHidden { return [objc_getAssociatedObject(self, &k_hidden) boolValue]; }
- (void)setAccessibilityElementsHidden:(BOOL)v { objc_setAssociatedObject(self, &k_hidden, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)accessibilityViewIsModal { return [objc_getAssociatedObject(self, &k_modal) boolValue]; }
- (void)setAccessibilityViewIsModal:(BOOL)v { objc_setAssociatedObject(self, &k_modal, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
@implementation UIView (UIAccessibilityIdentification)
- (NSString *)accessibilityIdentifier { return objc_getAssociatedObject(self, &k_ident); }
- (void)setAccessibilityIdentifier:(NSString *)v { objc_setAssociatedObject(self, &k_ident, v, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end
/* UIAccessibilityIsVoiceOverRunning & co: UIAccessibilityRuntime.m */

/* ---------------- long press ---------------- */
@interface UIGestureRecognizer ()
@property (nonatomic, readwrite) UIGestureRecognizerState state;
@property (nonatomic) CGPoint startPoint, lastPoint;
- (void)_fire;
@end
@implementation UILongPressGestureRecognizer { NSUInteger _generation; }
- (instancetype)initWithTarget:(id)t action:(SEL)a {
    if ((self = [super initWithTarget:t action:a])) { _minimumPressDuration = 0.5; _allowableMovement = 10; _numberOfTouchesRequired = 1; }
    return self;
}
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    CGPoint p = [touch locationInView:self.view];
    switch (phase) {
    case UITouchPhaseBegan: {
        self.startPoint = p; self.lastPoint = p; self.state = UIGestureRecognizerStatePossible;
        NSUInteger gen = ++_generation;
        __weak UILongPressGestureRecognizer *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(_minimumPressDuration * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UILongPressGestureRecognizer *s = weakSelf;
            if (!s || s->_generation != gen || s.state != UIGestureRecognizerStatePossible) return;
            s.state = UIGestureRecognizerStateBegan; [s _fire];
        });
        break; }
    case UITouchPhaseMoved:
        if (self.state == UIGestureRecognizerStatePossible) {
            if (hypot(p.x - self.startPoint.x, p.y - self.startPoint.y) > _allowableMovement) { self.state = UIGestureRecognizerStateFailed; _generation++; }
        } else if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
            self.lastPoint = p; self.state = UIGestureRecognizerStateChanged; [self _fire];
        }
        break;
    case UITouchPhaseCancelled:
        _generation++;
        if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) { self.state = UIGestureRecognizerStateCancelled; [self _fire]; }
        self.state = UIGestureRecognizerStatePossible;
        break;
    default:   /* ended */
        _generation++;
        if (self.state == UIGestureRecognizerStateBegan || self.state == UIGestureRecognizerStateChanged) {
            self.lastPoint = p; self.state = UIGestureRecognizerStateEnded; [self _fire];
        }
        self.state = UIGestureRecognizerStatePossible;
    }
}
@end

/* ---------------- custom keyboards ---------------- */
@implementation UITextInputMode
/* one mode per built-in keyboard enabled in Settings (en-US, pt-BR, ..., emoji) */
+ (NSArray<UITextInputMode *> *)activeInputModes {
    extern NSArray<NSString *> *isim_ui_keyboard_enabled(void);
    NSMutableArray *a = [NSMutableArray array];
    for (NSString *k in isim_ui_keyboard_enabled()) {
        if (![@[@"en_US", @"pt_BR", @"es_ES", @"fr_FR", @"de_DE", @"emoji"] containsObject:k]) continue;
        UITextInputMode *m = [UITextInputMode new];
        objc_setAssociatedObject(m, "isim.lang", [k stringByReplacingOccurrencesOfString:@"_" withString:@"-"], OBJC_ASSOCIATION_COPY_NONATOMIC);
        [a addObject:m];
    }
    return a.count ? a : @[[UITextInputMode new]];
}
- (NSString *)primaryLanguage { return objc_getAssociatedObject(self, "isim.lang") ?: @"en-US"; }
@end

@implementation UIInputView
- (instancetype)initWithFrame:(CGRect)f inputViewStyle:(UIInputViewStyle)style {
    if ((self = [super initWithFrame:f])) _inputViewStyle = style;
    return self;
}
@end

/* Forwards to the text input currently being edited (set by the keyboard host). */
@interface __IsimTextDocumentProxy : NSObject <UITextDocumentProxy>
@property (nonatomic, weak) id<UIKeyInput> target;
@end
@implementation __IsimTextDocumentProxy
@synthesize keyboardType, keyboardAppearance, returnKeyType, autocapitalizationType, autocorrectionType, spellCheckingType, enablesReturnKeyAutomatically, secureTextEntry, textContentType;
- (BOOL)hasText { return _target.hasText; }
- (void)insertText:(NSString *)text { [_target insertText:text]; }
- (void)deleteBackward { [_target deleteBackward]; }
- (NSString *)_text { id t = _target; return [t respondsToSelector:@selector(text)] ? [t text] : nil; }
- (id<UITextInput>)_input { id t = _target; return [t conformsToProtocol:@protocol(UITextInput)] ? t : nil; }
- (NSString *)_textFrom:(UITextPosition *)a to:(UITextPosition *)b { id<UITextInput> t = [self _input]; UITextRange *r = a && b ? [t textRangeFromPosition:a toPosition:b] : nil; return r ? [t textInRange:r] : nil; }
- (NSString *)documentContextBeforeInput {
    id<UITextInput> t = [self _input];
    return t ? [self _textFrom:t.beginningOfDocument to:t.selectedTextRange.start] : [self _text];
}
- (NSString *)documentContextAfterInput {
    id<UITextInput> t = [self _input];
    return t ? [self _textFrom:t.selectedTextRange.end to:t.endOfDocument] : ([self _text] ? @"" : nil);
}
- (NSString *)selectedText { id<UITextInput> t = [self _input]; UITextRange *r = t.selectedTextRange; return r && !r.isEmpty ? [t textInRange:r] : nil; }
- (UITextInputMode *)documentInputMode { return UITextInputMode.activeInputModes.firstObject; }
- (void)adjustTextPositionByCharacterOffset:(NSInteger)offset {
    id<UITextInput> t = [self _input];
    UITextPosition *p = [t positionFromPosition:t.selectedTextRange.end offset:offset];
    if (p) t.selectedTextRange = [t textRangeFromPosition:p toPosition:p];
}
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange {
    id<UITextInput> t = [self _input];
    if (t) [t setMarkedText:markedText selectedRange:selectedRange]; else [self insertText:markedText];
}
- (void)unmarkText { [[self _input] unmarkText]; }
@end

@implementation UIInputViewController { __IsimTextDocumentProxy *_proxy; }
- (id<UITextDocumentProxy>)textDocumentProxy { if (!_proxy) _proxy = [__IsimTextDocumentProxy new]; return _proxy; }
- (void)_isim_setTextInput:(id<UIKeyInput>)input {
    id old = ((__IsimTextDocumentProxy *)self.textDocumentProxy).target;
    if (old == input) return;
    [self textWillChange:(id<UITextInput>)input];
    ((__IsimTextDocumentProxy *)self.textDocumentProxy).target = input;
    [self textDidChange:(id<UITextInput>)input];
}
- (UIInputView *)inputView { return [self.view isKindOfClass:[UIInputView class]] ? (UIInputView *)self.view : nil; }
- (void)setInputView:(UIInputView *)v { self.view = v; }
- (void)loadView { self.view = [[UIInputView alloc] initWithFrame:CGRectZero inputViewStyle:UIInputViewStyleKeyboard]; }
- (BOOL)hasFullAccess { return NO; }
/* Face ID devices show the globe key in the system bar below the keyboard, so extensions don't need one */
- (BOOL)needsInputModeSwitchKey { return isim_ui_keyboard_needs_switch_key(); }
- (void)dismissKeyboard {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"_IsimDismissKeyboard" object:self];
    if (!isim_ui_system_keyboard_disabled) [isim_ui_first_responder() resignFirstResponder];
}
- (void)advanceToNextInputMode {
    [[NSNotificationCenter defaultCenter] postNotificationName:@"_IsimAdvanceInputMode" object:self];
    if (!isim_ui_system_keyboard_disabled) isim_ui_keyboard_advance();
}
- (void)handleInputModeListFromView:(UIView *)view withEvent:(UIEvent *)event {
    if (event.allTouches.anyObject.phase == UITouchPhaseEnded) [self advanceToNextInputMode];
}
- (void)selectionWillChange:(id<UITextInput>)t {}
- (void)selectionDidChange:(id<UITextInput>)t {}
- (void)textWillChange:(id<UITextInput>)t {}
- (void)textDidChange:(id<UITextInput>)t {}
@end

/* ---------------- keyboard extension preview host ----------------
 * Running a custom keyboard .appex on isim (NSExtensionMain) opens a host screen: a text
 * field at the top and the extension's UIInputViewController docked at the bottom where
 * iOS puts the keyboard. Typing on the keyboard edits the field through textDocumentProxy;
 * the hardware keyboard / ISIM_SCRIPT "type" also edit it. */
@interface __IsimKeyboardPreviewField : UIView <UIKeyInput>
@property (nonatomic, strong) NSMutableString *text;
@property (nonatomic, copy) NSString *placeholder;
@end
@implementation __IsimKeyboardPreviewField
@synthesize keyboardType, keyboardAppearance, returnKeyType, autocapitalizationType, autocorrectionType, spellCheckingType, enablesReturnKeyAutomatically, secureTextEntry, textContentType;
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) {
        _text = [NSMutableString string];
        self.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor;
        self.layer.cornerRadius = 10;
        self.accessibilityIdentifier = @"isim-preview-field";
    }
    return self;
}
- (BOOL)canBecomeFirstResponder { return YES; }
- (BOOL)hasText { return _text.length > 0; }
- (void)insertText:(NSString *)t { [_text appendString:t]; isim_ui_set_needs_display(); [self _changed]; }
- (void)deleteBackward {
    if (!_text.length) return;
    [_text deleteCharactersInRange:NSMakeRange(_text.length - 1, 1)];
    isim_ui_set_needs_display(); [self _changed];
}
- (void)_changed {
    self.accessibilityValue = [_text copy];
    if (getenv("ISIM_SCRIPT")) NSLog(@"isim: preview field text = \"%@\"", _text);
}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e {
    [self becomeFirstResponder];
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimShowKeyboard" object:self];
}
- (void)_isim_drawContent {
    CGRect r = CGRectInset(self.bounds, 12, 10);
    UIFont *f = [UIFont systemFontOfSize:17];
    NSString *shown = _text.length ? [_text stringByAppendingString:self.isFirstResponder ? @"|" : @""] : (self.isFirstResponder ? @"|" : _placeholder);
    UIColor *c = _text.length || self.isFirstResponder ? UIColor.labelColor : UIColor.placeholderTextColor;
    isim_ui_draw_text(shown ?: @"", f, c, r, NSTextAlignmentLeft, 0, 1);
}
@end

@interface __IsimKeyboardPreviewDelegate : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation __IsimKeyboardPreviewDelegate {
    UIInputViewController *_keyboard;
    UIView *_dock;
    __IsimKeyboardPreviewField *_field;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    isim_ui_system_keyboard_disabled = YES;          /* this host docks the extension itself */
    NSDictionary *info = NSBundle.mainBundle.infoDictionary, *ext = info[@"NSExtension"];
    NSString *principal = ext[@"NSExtensionPrincipalClass"];
    Class cls = NSClassFromString(principal);
    if (![cls isSubclassOfClass:[UIInputViewController class]]) {
        NSLog(@"isim: NSExtensionPrincipalClass '%@' is not a UIInputViewController subclass", principal);
        exit(1);
    }
    NSString *name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: @"Keyboard";
    _window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *root = [UIViewController new];
    UIView *v = root.view;
    v.backgroundColor = UIColor.systemGroupedBackgroundColor;

    UILabel *title = [UILabel new];
    title.text = [NSString stringWithFormat:@"%@ — keyboard preview", name];
    title.font = [UIFont boldSystemFontOfSize:20];
    UILabel *note = [UILabel new];
    note.text = @"isim keyboard extension host. Type with the keyboard below; the field shows what the extension inserts.";
    note.font = [UIFont systemFontOfSize:13]; note.textColor = UIColor.secondaryLabelColor; note.numberOfLines = 0;
    _field = [__IsimKeyboardPreviewField new];
    _field.placeholder = @"Tap here to type";
    for (UIView *s in @[title, note, _field]) { s.translatesAutoresizingMaskIntoConstraints = NO; [v addSubview:s]; }

    /* keyboard dock: system keyboard backdrop down to the screen edge, extension view on top */
    _dock = [UIView new];
    _dock.backgroundColor = [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:1] : [UIColor colorWithRed:0.82 green:0.83 blue:0.85 alpha:1];
    }];
    _dock.translatesAutoresizingMaskIntoConstraints = NO;
    [v addSubview:_dock];
    _keyboard = [cls new];
    [root addChildViewController:_keyboard];
    UIView *kv = _keyboard.view;
    kv.translatesAutoresizingMaskIntoConstraints = NO;
    [_dock addSubview:kv];
    [_keyboard didMoveToParentViewController:root];

    UILayoutGuide *safe = v.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [title.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [title.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:20],
        [title.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-20],
        [note.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:6],
        [note.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [note.trailingAnchor constraintEqualToAnchor:title.trailingAnchor],
        [_field.topAnchor constraintEqualToAnchor:note.bottomAnchor constant:16],
        [_field.leadingAnchor constraintEqualToAnchor:v.leadingAnchor constant:16],
        [_field.trailingAnchor constraintEqualToAnchor:v.trailingAnchor constant:-16],
        [_field.heightAnchor constraintEqualToConstant:88],
        [_dock.leadingAnchor constraintEqualToAnchor:v.leadingAnchor],
        [_dock.trailingAnchor constraintEqualToAnchor:v.trailingAnchor],
        [_dock.bottomAnchor constraintEqualToAnchor:v.bottomAnchor],
        [_dock.topAnchor constraintEqualToAnchor:kv.topAnchor],
        [kv.leadingAnchor constraintEqualToAnchor:_dock.leadingAnchor],
        [kv.trailingAnchor constraintEqualToAnchor:_dock.trailingAnchor],
        [kv.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];
    /* a keyboard view without its own height gets the standard iPhone portrait keyboard height */
    NSLayoutConstraint *fallback = [kv.heightAnchor constraintEqualToConstant:216];
    fallback.priority = UILayoutPriorityDefaultLow;
    fallback.active = YES;

    _window.rootViewController = root;
    [_window makeKeyAndVisible];
    [_field becomeFirstResponder];
    [_keyboard _isim_setTextInput:_field];

    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    [nc addObserverForName:@"_IsimDismissKeyboard" object:nil queue:nil usingBlock:^(NSNotification *n) { [self _setKeyboardShown:NO]; }];
    [nc addObserverForName:@"_IsimShowKeyboard" object:nil queue:nil usingBlock:^(NSNotification *n) { [self _setKeyboardShown:YES]; }];
    [nc addObserverForName:@"_IsimAdvanceInputMode" object:nil queue:nil usingBlock:^(NSNotification *n) {
        NSLog(@"isim: next keyboard requested (globe key); isim has only this keyboard installed");
    }];
    NSLog(@"isim: hosting keyboard extension %@ (%@)", principal, NSBundle.mainBundle.bundleIdentifier);
    return YES;
}
- (void)_setKeyboardShown:(BOOL)shown {
    if (_dock.hidden == !shown) return;
    if (!shown) { [_keyboard viewWillDisappear:NO]; _dock.hidden = YES; [_field resignFirstResponder]; [_keyboard viewDidDisappear:NO]; }
    else { [_keyboard viewWillAppear:NO]; _dock.hidden = NO; [_field becomeFirstResponder]; [_keyboard viewDidAppear:NO]; }
    NSLog(@"isim: keyboard %@", shown ? @"shown" : @"dismissed");
    isim_ui_set_needs_display();
}
@end

/* Entry point of app extensions (linked with -e _NSExtensionMain). */
int NSExtensionMain(int argc, char *argv[]) {
    NSString *point = NSBundle.mainBundle.infoDictionary[@"NSExtension"][@"NSExtensionPointIdentifier"];
    if (![point isEqualToString:@"com.apple.keyboard-service"]) {
        NSLog(@"isim: extension point '%@' is not supported (isim hosts custom keyboards only)", point);
        return 1;
    }
    return UIApplicationMain(argc, argv, nil, @"__IsimKeyboardPreviewDelegate");
}
