/* isim system keyboard: a window at the bottom of the screen that appears while a key-input
 * responder (UITextField, ...) is first responder.
 *  - built-in "English (US)" keyboard: letters / numbers / symbols layers, shift + auto-capitalization,
 *    delete with auto-repeat, return key titled by returnKeyType;
 *  - custom keyboards: the app's embedded keyboard extensions (PlugIns/*.appex,
 *    com.apple.keyboard-service). isim loads the extension executable into the app process
 *    (iOS runs it out of process) and hosts its UIInputViewController. All embedded keyboards
 *    count as enabled (iOS needs Settings > Keyboards); ISIM_KEYBOARDS=none disables them;
 *  - Face ID devices get the bottom bar with the globe key (tap: next keyboard, hold: list);
 *    custom keyboards then report needsInputModeSwitchKey = NO, as on iOS.
 * Key views carry accessibility identifiers (isim-kb-q, isim-kb-space, isim-kb-globe, ...).
 * ISIM_SOFTWARE_KEYBOARD=0 disables the on-screen keyboard (hardware typing still works). */
#import "UIKitPrivate.h"
#include <dlfcn.h>
#include <math.h>

NSNotificationName const UIKeyboardWillShowNotification = @"UIKeyboardWillShowNotification";
NSNotificationName const UIKeyboardDidShowNotification = @"UIKeyboardDidShowNotification";
NSNotificationName const UIKeyboardWillHideNotification = @"UIKeyboardWillHideNotification";
NSNotificationName const UIKeyboardDidHideNotification = @"UIKeyboardDidHideNotification";
NSNotificationName const UIKeyboardWillChangeFrameNotification = @"UIKeyboardWillChangeFrameNotification";
NSNotificationName const UIKeyboardDidChangeFrameNotification = @"UIKeyboardDidChangeFrameNotification";
NSString *const UIKeyboardFrameBeginUserInfoKey = @"UIKeyboardFrameBeginUserInfoKey";
NSString *const UIKeyboardFrameEndUserInfoKey = @"UIKeyboardFrameEndUserInfoKey";
NSString *const UIKeyboardAnimationDurationUserInfoKey = @"UIKeyboardAnimationDurationUserInfoKey";
NSString *const UIKeyboardAnimationCurveUserInfoKey = @"UIKeyboardAnimationCurveUserInfoKey";
NSString *const UIKeyboardIsLocalUserInfoKey = @"UIKeyboardIsLocalUserInfoKey";

BOOL isim_ui_system_keyboard_disabled;
static CGRect keyboard_frame;                 /* screen coordinates; empty when hidden */
CGRect isim_ui_keyboard_frame(void) { return keyboard_frame; }

static UIColor *dyn(double light, double dark) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) { return [UIColor colorWithWhite:t.userInterfaceStyle == UIUserInterfaceStyleDark ? dark : light alpha:1]; }];
}
static UIColor *kb_background(void) {
    return [UIColor colorWithDynamicProvider:^UIColor *(UITraitCollection *t) {
        return t.userInterfaceStyle == UIUserInterfaceStyleDark ? [UIColor colorWithWhite:0.17 alpha:1] : [UIColor colorWithRed:0.82 green:0.83 blue:0.85 alpha:1]; }];
}

/* ================= built-in keyboard ================= */
enum { L_LETTERS, L_NUMBERS, L_SYMBOLS };
@interface __IsimKeyboardKeys : UIView
@property (nonatomic, weak) id<UIKeyInput> target;
@property (nonatomic) BOOL showGlobe;                 /* devices without the bottom bar */
@property (nonatomic, copy) void (^onGlobe)(void);
@end
@implementation __IsimKeyboardKeys {
    int _layer; BOOL _shift, _caps;
    NSMutableArray<UIButton *> *_keys;
    NSTimer *_repeat;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { _keys = [NSMutableArray array]; [self _rebuild]; }
    return self;
}
static NSArray *rows_for(int layer) {
    switch (layer) {
    case L_NUMBERS: return @[@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"], @[@"-", @"/", @":", @";", @"(", @")", @"$", @"&", @"@", @"\""], @[@".", @",", @"?", @"!", @"'"]];
    case L_SYMBOLS: return @[@[@"[", @"]", @"{", @"}", @"#", @"%", @"^", @"*", @"+", @"="], @[@"_", @"\\", @"|", @"~", @"<", @">", @"€", @"£", @"¥", @"•"], @[@".", @",", @"?", @"!", @"'"]];
    default: return @[@[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"], @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l"], @[@"z", @"x", @"c", @"v", @"b", @"n", @"m"]];
    }
}
- (UIButton *)_key:(NSString *)title ident:(NSString *)ident special:(BOOL)special action:(SEL)sel {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
    b.tintColor = UIColor.labelColor;
    b.titleLabel.font = [UIFont systemFontOfSize:special ? 16 : 23];
    b.backgroundColor = special ? dyn(0.67, 0.27) : dyn(1, 0.42);
    b.layer.cornerRadius = 5;
    b.layer.shadowColor = UIColor.blackColor.CGColor; b.layer.shadowOpacity = 0.3; b.layer.shadowOffset = CGSizeMake(0, 1); b.layer.shadowRadius = 0;
    b.accessibilityIdentifier = ident;
    b.accessibilityTraits = UIAccessibilityTraitKeyboardKey;
    [b addTarget:self action:sel forControlEvents:UIControlEventTouchUpInside];
    [self addSubview:b];
    [_keys addObject:b];
    return b;
}
- (BOOL)_upper { return _layer == L_LETTERS && (_shift || _caps); }
- (void)_rebuild {
    for (UIButton *b in _keys) [b removeFromSuperview];
    [_keys removeAllObjects];
    NSArray *rows = rows_for(_layer);
    for (NSUInteger r = 0; r < rows.count; r++)
        for (NSString *k in rows[r]) {
            UIButton *b = [self _key:[self _upper] ? k.uppercaseString : k ident:[@"isim-kb-" stringByAppendingString:k] special:NO action:@selector(_char:)];
            b.tag = (NSInteger)r;
        }
    NSString *shiftTitle = _layer == L_LETTERS ? (_caps ? @"⇪" : @"⇧") : _layer == L_NUMBERS ? @"#+=" : @"123";
    UIButton *shift = [self _key:shiftTitle ident:@"isim-kb-shift" special:_layer == L_LETTERS ? !(_shift || _caps) : YES action:@selector(_shift:)];
    if (_layer == L_LETTERS && (_shift || _caps)) shift.backgroundColor = dyn(1, 0.42);
    shift.titleLabel.font = [UIFont systemFontOfSize:_layer == L_LETTERS ? 22 : 16];
    shift.tag = 100;
    UIButton *del = [self _key:@"⌫" ident:@"isim-kb-delete" special:YES action:@selector(_noop)];
    del.titleLabel.font = [UIFont systemFontOfSize:20];
    [del addTarget:self action:@selector(_deleteDown) forControlEvents:UIControlEventTouchDown];
    [del addTarget:self action:@selector(_deleteUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    del.tag = 101;
    UIButton *mode = [self _key:_layer == L_LETTERS ? @"123" : @"ABC" ident:_layer == L_LETTERS ? @"isim-kb-123" : @"isim-kb-abc" special:YES action:@selector(_mode:)];
    mode.tag = 102;
    if (_showGlobe) {
        UIButton *g = [self _key:@"" ident:@"isim-kb-globe" special:YES action:@selector(_globe)];
        [g setImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:19]] forState:UIControlStateNormal];
        g.tag = 103;
    }
    UIButton *space = [self _key:@"space" ident:@"isim-kb-space" special:NO action:@selector(_space)];
    space.titleLabel.font = [UIFont systemFontOfSize:16];
    space.tag = 104;
    UIButton *ret = [self _key:[self _returnTitle] ident:@"isim-kb-return" special:YES action:@selector(_return)];
    if ([self _returnIsBlue]) { ret.backgroundColor = UIColor.systemBlueColor; [ret setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    ret.tag = 105;
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (UIReturnKeyType)_returnType { id t = _target; return [t respondsToSelector:@selector(returnKeyType)] ? [(id<UITextInputTraits>)t returnKeyType] : UIReturnKeyDefault; }
- (NSString *)_returnTitle {
    switch ([self _returnType]) {
    case UIReturnKeyGo: return @"go"; case UIReturnKeyGoogle: case UIReturnKeySearch: case UIReturnKeyYahoo: return @"search";
    case UIReturnKeyJoin: return @"join"; case UIReturnKeyNext: return @"next"; case UIReturnKeyRoute: return @"route";
    case UIReturnKeySend: return @"send"; case UIReturnKeyDone: return @"done"; case UIReturnKeyEmergencyCall: return @"emergency";
    case UIReturnKeyContinue: return @"continue"; default: return @"return";
    }
}
- (BOOL)_returnIsBlue { UIReturnKeyType t = [self _returnType]; return t != UIReturnKeyDefault && t != UIReturnKeyNext && t != UIReturnKeyContinue; }
- (void)layoutSubviews {
    CGFloat W = self.bounds.size.width, gap = 6, side = 3, keyH = 42, rowH = 54, top = 8;
    CGFloat kw = (W - 2 * side - 9 * gap) / 10;
    CGFloat specialW = kw * 1.3 + 4;
    NSMutableArray *rowKeys[3] = { [NSMutableArray array], [NSMutableArray array], [NSMutableArray array] };
    for (UIButton *b in _keys) if (b.tag < 3) [rowKeys[b.tag] addObject:b];
    for (int r = 0; r < 3; r++) {
        NSArray *ks = rowKeys[r];
        CGFloat y = top + r * rowH, x;
        if (r < 2) { x = (W - ks.count * kw - (ks.count - 1) * gap) / 2; }
        else {
            /* third row: shift/symbols key and delete at the edges, characters centered between */
            CGFloat cw = _layer == L_LETTERS ? kw : (W - 2 * side - 2 * specialW - 2 * 14 - 4 * gap) / 5;
            CGFloat total = ks.count * cw + (ks.count - 1) * gap;
            x = (W - total) / 2;
            for (UIButton *b in ks) { b.frame = CGRectMake(round(x), y, round(cw), keyH); x += cw + gap; }
            continue;
        }
        for (UIButton *b in ks) { b.frame = CGRectMake(round(x), y, round(kw), keyH); x += kw + gap; }
    }
    CGFloat y3 = top + 2 * rowH, y4 = top + 3 * rowH;
    for (UIButton *b in _keys) {
        switch (b.tag) {
        case 100: b.frame = CGRectMake(side, y3, round(specialW), keyH); break;
        case 101: b.frame = CGRectMake(W - side - round(specialW), y3, round(specialW), keyH); break;
        default: break;
        }
    }
    CGFloat modeW = _showGlobe ? round(kw * 1.25) : round(kw * 2.5 + gap), retW = round(kw * 2.5 + gap), x = side;
    for (UIButton *b in _keys) if (b.tag == 102) { b.frame = CGRectMake(x, y4, modeW, keyH); x += modeW + gap; }
    for (UIButton *b in _keys) if (b.tag == 103) { b.frame = CGRectMake(x, y4, modeW, keyH); x += modeW + gap; }
    for (UIButton *b in _keys) if (b.tag == 104) b.frame = CGRectMake(x, y4, W - side - retW - gap - x, keyH);
    for (UIButton *b in _keys) if (b.tag == 105) b.frame = CGRectMake(W - side - retW, y4, retW, keyH);
}
- (void)setTarget:(id<UIKeyInput>)t { _target = t; _layer = L_LETTERS; _caps = NO; [self _updateAutoShift]; [self _rebuild]; }
- (void)setShowGlobe:(BOOL)g { if (g == _showGlobe) return; _showGlobe = g; [self _rebuild]; }
- (void)_updateAutoShift {
    id t = _target;
    UITextAutocapitalizationType ac = [t respondsToSelector:@selector(autocapitalizationType)] ? [(id<UITextInputTraits>)t autocapitalizationType] : UITextAutocapitalizationTypeSentences;
    NSString *text = [t respondsToSelector:@selector(text)] ? [t text] : @"";
    BOOL want = NO;
    extern NSDictionary *isim_global_preferences(void);
    NSNumber *pref = isim_global_preferences()[@"KeyboardAutocapitalization"];      /* Settings > General > Keyboard */
    if (pref && !pref.boolValue && ac != UITextAutocapitalizationTypeAllCharacters) ac = UITextAutocapitalizationTypeNone;
    if (ac == UITextAutocapitalizationTypeAllCharacters) want = YES;
    else if (ac == UITextAutocapitalizationTypeSentences) {
        NSString *trim = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        want = trim.length == 0 || [trim hasSuffix:@"."] || [trim hasSuffix:@"!"] || [trim hasSuffix:@"?"] || [text hasSuffix:@"\n"];
        if (trim.length && ![text hasSuffix:@" "] && ![text hasSuffix:@"\n"]) want = NO;
    } else if (ac == UITextAutocapitalizationTypeWords) want = text.length == 0 || [text hasSuffix:@" "];
    _shift = want;
}
- (void)_type:(NSString *)s {
    [_target insertText:s];
    BOOL was = _shift;
    [self _updateAutoShift];
    if (was != _shift && _layer == L_LETTERS) [self _rebuild];
}
- (void)_char:(UIButton *)b { [self _type:b.currentTitle]; }
- (void)_space {
    [self _type:@" "];
    if (_layer != L_LETTERS) { _layer = L_LETTERS; [self _updateAutoShift]; [self _rebuild]; }
}
- (void)_return { [self _type:@"\n"]; }
- (void)_shift:(UIButton *)b {
    if (_layer == L_LETTERS) { if (_caps) _caps = _shift = NO; else if (_shift) _caps = YES; else _shift = YES; }
    else _layer = _layer == L_NUMBERS ? L_SYMBOLS : L_NUMBERS;
    [self _rebuild];
}
- (void)_mode:(UIButton *)b { _layer = _layer == L_LETTERS ? L_NUMBERS : L_LETTERS; [self _updateAutoShift]; [self _rebuild]; }
- (void)_globe { if (_onGlobe) _onGlobe(); }
- (void)_noop {}
- (void)_deleteOnce { [_target deleteBackward]; BOOL was = _shift; [self _updateAutoShift]; if (was != _shift && _layer == L_LETTERS) [self _rebuild]; }
- (void)_deleteDown {
    [self _deleteOnce];
    __weak __IsimKeyboardKeys *w = self;
    _repeat = [NSTimer timerWithTimeInterval:0.5 repeats:NO block:^(NSTimer *t) {
        __IsimKeyboardKeys *s = w; if (!s) return;
        s->_repeat = [NSTimer timerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t2) { [w _deleteOnce]; }];
        [NSRunLoop.mainRunLoop addTimer:s->_repeat forMode:NSRunLoopCommonModes];
    }];
    [NSRunLoop.mainRunLoop addTimer:_repeat forMode:NSRunLoopCommonModes];
}
- (void)_deleteUp { [_repeat invalidate]; _repeat = nil; }
@end

/* ================= keyboard window ================= */
@interface __IsimKeyboardWindow : UIWindow
@end
@implementation __IsimKeyboardWindow
- (BOOL)_isim_isSystemWindow { return YES; }
- (BOOL)canBecomeKeyWindow { return NO; }
- (UIEdgeInsets)safeAreaInsets {
    const struct isim_device *d = isim_ui_device();
    CGFloat bottom = MAX(0, CGRectGetMaxY(self.frame) - (d->height - d->safe_bottom));
    return UIEdgeInsetsMake(0, 0, bottom, 0);
}
@end

@interface __IsimCustomKeyboard : NSObject
@property (nonatomic, copy) NSString *bundleID, *name, *executable, *principal;
@property (nonatomic, strong) UIInputViewController *controller;
@end
@implementation __IsimCustomKeyboard @end

@interface __IsimKeyboardController : NSObject
@end
@implementation __IsimKeyboardController {
    __IsimKeyboardWindow *_window;
    UIView *_content, *_bar, *_menu;
    __IsimKeyboardKeys *_keys;
    NSMutableArray<__IsimCustomKeyboard *> *_custom;
    NSInteger _current;                  /* 0 = built-in, n = _custom[n-1] */
    UIView *_hostedView;
    __weak id _target;
    BOOL _shown;
}
+ (instancetype)shared { static __IsimKeyboardController *c; if (!c) c = [self new]; return c; }
+ (void)load_isim {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimFirstResponderDidChange" object:nil queue:nil usingBlock:^(NSNotification *n) {
        [[__IsimKeyboardController shared] _responderChanged:n.object];
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSettingsChanged" object:nil queue:nil usingBlock:^(NSNotification *n) {
        [[__IsimKeyboardController shared] _settingsChanged];
    }];
}
- (BOOL)_barVisible { return isim_ui_device()->safe_bottom > 0; }
/* Keyboards: the app's own embedded keyboards, and under the shell those of every installed app.
 * Under the shell only keyboards enabled in Settings > General > Keyboard > Keyboards are offered
 * (AppleKeyboards in the global domain); with plain `isim run` the app's own keyboards are enabled.
 * ISIM_KEYBOARDS=all|none overrides. */
- (void)_addKeyboardsIn:(NSString *)appPath enabled:(NSArray *)enabled all:(BOOL)all {
    NSString *plugins = [appPath stringByAppendingPathComponent:@"PlugIns"];
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:plugins error:NULL]) {
        if (![name hasSuffix:@".appex"]) continue;
        NSString *path = [plugins stringByAppendingPathComponent:name];
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"Info.plist"]];
        NSDictionary *ext = info[@"NSExtension"];
        if (![ext[@"NSExtensionPointIdentifier"] isEqualToString:@"com.apple.keyboard-service"]) continue;
        NSString *ident = info[@"CFBundleIdentifier"];
        if (!all && ![enabled containsObject:ident]) continue;
        for (__IsimCustomKeyboard *k in _custom) if ([k.bundleID isEqualToString:ident]) goto next;
        {
            __IsimCustomKeyboard *k = [__IsimCustomKeyboard new];
            k.bundleID = ident; k.name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: name.stringByDeletingPathExtension;
            k.executable = [path stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: name.stringByDeletingPathExtension];
            k.principal = ext[@"NSExtensionPrincipalClass"];
            [_custom addObject:k];
        }
        next:;
    }
}
- (void)_discover {
    if (_custom) return;
    _custom = [NSMutableArray array];
    const char *env = getenv("ISIM_KEYBOARDS");
    if (env && !strcmp(env, "none")) return;
    extern NSDictionary *isim_global_preferences(void);
    NSArray *enabled = isim_global_preferences()[@"AppleKeyboards"];
    if (![enabled isKindOfClass:[NSArray class]]) enabled = @[];
    BOOL all = (env && !strcmp(env, "all")) || !isim_shell_present();
    if (isim_shell_present()) {
        /* iOS order: the order keyboards were added in Settings */
        NSString *apps = isim_ui_installed_apps_dir();
        NSMutableArray *paths = [NSMutableArray arrayWithObject:NSBundle.mainBundle.bundlePath];
        for (NSString *a in [NSFileManager.defaultManager contentsOfDirectoryAtPath:apps error:NULL])
            if ([a hasSuffix:@".app"]) [paths addObject:[apps stringByAppendingPathComponent:a]];
        for (NSString *a in paths) [self _addKeyboardsIn:a enabled:enabled all:all];
        [_custom sortUsingComparator:^NSComparisonResult(__IsimCustomKeyboard *x, __IsimCustomKeyboard *y) {
            NSUInteger i = [enabled indexOfObject:x.bundleID], j = [enabled indexOfObject:y.bundleID];
            return i < j ? NSOrderedAscending : i > j ? NSOrderedDescending : NSOrderedSame; }];
    } else [self _addKeyboardsIn:NSBundle.mainBundle.bundlePath enabled:enabled all:all];
}
- (void)_settingsChanged {
    /* keyboards enabled/disabled in Settings: rebuild the list (keep the current one if still enabled) */
    NSString *current = _current > 0 ? _custom[_current - 1].bundleID : nil;
    NSMutableArray *old = _custom;
    _custom = nil; [self _discover];
    for (__IsimCustomKeyboard *k in _custom) for (__IsimCustomKeyboard *o in old) if ([o.bundleID isEqualToString:k.bundleID]) k.controller = o.controller;
    NSInteger idx = 0;
    for (NSUInteger i = 0; i < _custom.count; i++) if ([_custom[i].bundleID isEqualToString:current]) idx = (NSInteger)i + 1;
    if (_current > 0 && idx == 0) [self _activate:0];
    _current = idx;
}
- (void)_build {
    if (_window) return;
    _window = [[__IsimKeyboardWindow alloc] initWithFrame:CGRectZero];
    _window.windowLevel = 10000000;
    _window.backgroundColor = kb_background();
    _content = [UIView new]; [_window addSubview:_content];
    _keys = [[__IsimKeyboardKeys alloc] initWithFrame:CGRectZero];
    __weak __IsimKeyboardController *w = self;
    _keys.onGlobe = ^{ [w _next]; };
    _bar = [UIView new]; [_window addSubview:_bar];
    UIButton *globe = [UIButton buttonWithType:UIButtonTypeCustom];
    [globe setImage:[UIImage systemImageNamed:@"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24]] forState:UIControlStateNormal];
    globe.tintColor = UIColor.secondaryLabelColor;
    globe.accessibilityIdentifier = @"isim-kb-globe";
    globe.accessibilityLabel = @"Next keyboard";
    globe.frame = CGRectMake(12, 2, 44, 40);
    [globe addTarget:self action:@selector(_next) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_globeHold:)];
    lp.minimumPressDuration = 0.4;
    [globe addGestureRecognizer:lp];
    [_bar addSubview:globe];
}
- (CGFloat)_contentHeight {
    if (_current == 0 || !_hostedView) return 216;
    UIView *v = _hostedView;
    CGFloat W = isim_ui_device()->width;
    CGSize s = [v systemLayoutSizeFittingSize:CGSizeMake(W, 216) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return s.height > 20 ? s.height : 216;
}
- (void)_relayout {
    const struct isim_device *d = isim_ui_device();
    CGFloat contentH = [self _contentHeight], barH = [self _barVisible] ? 45 + d->safe_bottom : 0;
    CGFloat H = contentH + barH;
    CGRect old = keyboard_frame;
    CGRect f = CGRectMake(0, d->height - H, d->width, H);
    _window.frame = f;
    _content.frame = CGRectMake(0, 0, d->width, contentH);
    _bar.frame = CGRectMake(0, contentH, d->width, barH);
    _bar.hidden = barH == 0;
    if (_hostedView) _hostedView.frame = _content.bounds;
    _keys.frame = _content.bounds;
    if (_shown && !CGRectEqualToRect(old, f)) [self _post:UIKeyboardWillChangeFrameNotification from:old to:f], keyboard_frame = f, [self _post:UIKeyboardDidChangeFrameNotification from:old to:f];
    isim_ui_set_needs_layout();
}
- (void)_post:(NSNotificationName)name from:(CGRect)a to:(CGRect)b {
    [NSNotificationCenter.defaultCenter postNotificationName:name object:nil userInfo:@{
        UIKeyboardFrameBeginUserInfoKey: [NSValue valueWithCGRect:a], UIKeyboardFrameEndUserInfoKey: [NSValue valueWithCGRect:b],
        UIKeyboardAnimationDurationUserInfoKey: @0.25, UIKeyboardAnimationCurveUserInfoKey: @7, UIKeyboardIsLocalUserInfoKey: @YES }];
}
- (void)_responderChanged:(id)responder {
    if (isim_ui_system_keyboard_disabled) return;
    const char *env = getenv("ISIM_SOFTWARE_KEYBOARD");
    if (env && !strcmp(env, "0")) return;
    BOOL wants = [responder isKindOfClass:[UIView class]] && [responder respondsToSelector:@selector(insertText:)] && [responder respondsToSelector:@selector(deleteBackward)];
    if (wants && [responder respondsToSelector:@selector(inputView)] && [responder inputView]) wants = NO;   /* custom input views: not supported, no keyboard */
    if (wants) [self _showFor:responder]; else [self _hide];
}
- (void)_showFor:(id<UIKeyInput>)t {
    [self _build]; [self _discover];
    id old = _target;
    _target = t;
    _keys.showGlobe = ![self _barVisible] && _custom.count > 0;
    _keys.target = t;
    [self _activate:_current];
    if (_current > 0) { UIInputViewController *vc = _custom[_current - 1].controller; if (old != t) [vc _isim_setTextInput:t]; }
    if (_shown) { [self _relayout]; return; }
    _shown = YES;
    CGRect from = keyboard_frame;
    [self _relayout];
    CGRect to = _window.frame;
    if (CGRectIsEmpty(from)) from = CGRectOffset(to, 0, to.size.height);
    [self _post:UIKeyboardWillShowNotification from:from to:to];
    [self _post:UIKeyboardWillChangeFrameNotification from:from to:to];
    keyboard_frame = to;
    _window.hidden = NO;
    if (_current > 0) { UIInputViewController *vc = _custom[_current - 1].controller; [vc viewWillAppear:NO]; [vc viewDidAppear:NO]; }
    [self _post:UIKeyboardDidShowNotification from:from to:to];
    [self _post:UIKeyboardDidChangeFrameNotification from:from to:to];
    NSLog(@"isim: keyboard shown (%@)", [self _currentName]);
}
/* the edited view was deallocated or left its window without resigning */
- (void)_check {
    if (!_shown) return;
    UIView *t = (UIView *)_target;
    if (!t || isim_ui_first_responder() != (id)t || ([t isKindOfClass:[UIView class]] && !t.window)) {
        if (t && isim_ui_first_responder() == (id)t) [t resignFirstResponder]; else [self _hide];
    }
}
- (void)_hide {
    if (!_shown) return;
    _shown = NO;
    _target = nil;
    [_menu removeFromSuperview]; _menu = nil;
    CGRect from = keyboard_frame, to = CGRectOffset(from, 0, from.size.height);
    [self _post:UIKeyboardWillHideNotification from:from to:to];
    [self _post:UIKeyboardWillChangeFrameNotification from:from to:to];
    if (_current > 0) [_custom[_current - 1].controller viewWillDisappear:NO];
    _window.hidden = YES;
    keyboard_frame = CGRectZero;
    if (_current > 0) { UIInputViewController *vc = _custom[_current - 1].controller; [vc viewDidDisappear:NO]; [vc _isim_setTextInput:nil]; }
    [self _post:UIKeyboardDidHideNotification from:from to:to];
    [self _post:UIKeyboardDidChangeFrameNotification from:from to:to];
    isim_ui_set_needs_layout();
    NSLog(@"isim: keyboard hidden");
}
- (NSString *)_currentName { return _current == 0 ? @"English (US)" : _custom[_current - 1].name; }
- (BOOL)_load:(__IsimCustomKeyboard *)k {
    if (k.controller) return YES;
    if (!dlopen(k.executable.UTF8String, RTLD_NOW)) { NSLog(@"isim: cannot load keyboard %@: %s", k.bundleID, dlerror()); return NO; }
    extern void isim_bundle_register_extension(NSString *path);
    isim_bundle_register_extension(k.executable.stringByDeletingLastPathComponent);
    Class cls = NSClassFromString(k.principal);
    if (![cls isSubclassOfClass:[UIInputViewController class]]) { NSLog(@"isim: keyboard %@: principal class %@ not found", k.bundleID, k.principal); return NO; }
    k.controller = [cls new];
    NSLog(@"isim: loaded keyboard extension %@ (%@) into the app process", k.name, k.bundleID);
    return YES;
}
- (void)_activate:(NSInteger)idx {
    if (idx > 0 && ![self _load:_custom[idx - 1]]) idx = 0;
    UIInputViewController *oldVC = _current > 0 ? _custom[_current - 1].controller : nil;
    UIInputViewController *newVC = idx > 0 ? _custom[idx - 1].controller : nil;
    UIView *newView = newVC ? newVC.view : _keys;
    if (newView == (_hostedView ?: (UIView *)(_keys.superview ? _keys : nil)) && _current == idx) return;
    if (oldVC && oldVC != newVC && _shown) [oldVC viewWillDisappear:NO];
    [_hostedView removeFromSuperview]; [_keys removeFromSuperview];
    if (oldVC && oldVC != newVC) { if (_shown) [oldVC viewDidDisappear:NO]; [oldVC _isim_setTextInput:nil]; }
    _current = idx;
    _hostedView = newVC ? newView : nil;
    if (newVC) {
        newView.translatesAutoresizingMaskIntoConstraints = YES;
        [_content addSubview:newView];
        [newVC _isim_setTextInput:_target];
        if (_shown) [newVC viewWillAppear:NO];
    } else [_content addSubview:_keys];
    [self _relayout];
    if (newVC && _shown) [newVC viewDidAppear:NO];
}
- (void)_next {
    [self _discover];
    NSInteger n = (NSInteger)_custom.count + 1;
    [self _switchTo:(_current + 1) % n];
}
- (void)_switchTo:(NSInteger)idx {
    [_menu removeFromSuperview]; _menu = nil;
    if (idx == _current) return;
    [self _activate:idx];
    NSLog(@"isim: keyboard switched to %@", [self _currentName]);
}
- (void)_globeHold:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    [self _discover];
    [_menu removeFromSuperview];
    NSMutableArray *names = [NSMutableArray arrayWithObject:@"English (US)"];
    for (__IsimCustomKeyboard *k in _custom) [names addObject:k.name];
    CGFloat rowH = 44, w = 240, h = rowH * names.count;
    _menu = [[UIView alloc] initWithFrame:CGRectMake(8, MAX(8, _bar.frame.origin.y - h - 4), w, h)];
    _menu.backgroundColor = dyn(0.98, 0.22);
    _menu.layer.cornerRadius = 12;
    _menu.layer.shadowColor = UIColor.blackColor.CGColor; _menu.layer.shadowOpacity = 0.25; _menu.layer.shadowRadius = 8;
    for (NSUInteger i = 0; i < names.count; i++) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:names[i] forState:UIControlStateNormal];
        [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        b.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        b.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 16);
        b.frame = CGRectMake(0, i * rowH, w, rowH);
        b.tag = (NSInteger)i;
        if ((NSInteger)i == _current) b.backgroundColor = dyn(0.9, 0.3);
        b.accessibilityIdentifier = i == 0 ? @"isim-kb-menu-builtin" : [@"isim-kb-menu-" stringByAppendingString:_custom[i - 1].bundleID];
        [b addTarget:self action:@selector(_menuPick:) forControlEvents:UIControlEventTouchUpInside];
        [_menu addSubview:b];
    }
    /* the menu floats above the keys inside the keyboard window */
    [_window addSubview:_menu];
    NSLog(@"isim: keyboard list shown");
}
- (void)_menuPick:(UIButton *)b { [self _switchTo:b.tag]; }
- (BOOL)_needsSwitchKey { return ![self _barVisible]; }
@end

/* custom keyboards ask this through needsInputModeSwitchKey */
BOOL isim_ui_keyboard_needs_switch_key(void) { return isim_ui_device()->safe_bottom <= 0; }
void isim_ui_keyboard_advance(void) { [[__IsimKeyboardController shared] _next]; }
void isim_ui_keyboard_check(void) { [[__IsimKeyboardController shared] _check]; }
void isim_ui_keyboard_install(void) { [__IsimKeyboardController load_isim]; }
