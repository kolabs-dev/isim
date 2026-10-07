/* isim system keyboard: a window at the bottom of the screen that appears while a key-input
 * responder (UITextField, ...) is first responder.
 *  - built-in keyboards enabled in Settings (English (US), Português (Brasil), Español, Français, Deutsch, Emoji):
 *    letters / numbers / symbols layers, shift + auto-capitalization, accent popups, predictive bar, autocorrection,
 *    delete with auto-repeat, return key titled by returnKeyType; dictation (mic) is not available;
 *  - custom keyboards: the app's embedded keyboard extensions (PlugIns/*.appex,
 *    com.apple.keyboard-service). isim loads the extension executable into the app process
 *    (iOS runs it out of process) and hosts its UIInputViewController. All embedded keyboards
 *    count as enabled (iOS needs Settings > Keyboards); ISIM_KEYBOARDS=none disables them;
 *  - Face ID devices get the bottom bar with the globe key (tap: next keyboard, hold: list);
 *    custom keyboards then report needsInputModeSwitchKey = NO, as on iOS.
 * Key views carry accessibility identifiers (isim-kb-q, isim-kb-space, isim-kb-globe, ...).
 * ISIM_SOFTWARE_KEYBOARD=0 disables the on-screen keyboard (hardware typing still works). */
#import "UIKitInputPrivate.h"
#import <UIKit/UITextChecker.h>
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

/* ================= built-in keyboards ================= */
/* languages: en_US (QWERTY), pt_BR (QWERTY), es_ES (QWERTY + ñ), fr_FR (AZERTY), de_DE (QWERTZ + ü ö ä), emoji.
   Holding a letter shows its accented variants (slide onto one and lift, or tap one); the predictive bar above the
   letters shows the typed word, a correction or completions from UITextChecker; autocorrection replaces a misspelled
   word when space or punctuation is typed on this keyboard (Settings > General > Keyboard). */
enum { L_LETTERS, L_NUMBERS, L_SYMBOLS };
static NSDictionary *global_prefs(void) { extern NSDictionary *isim_global_preferences(void); return isim_global_preferences(); }
static BOOL pref_on(NSString *key) { NSNumber *n = global_prefs()[key]; return n ? n.boolValue : YES; }
NSString *isim_ui_keyboard_language_name(NSString *lang) {
    NSDictionary *names = @{ @"en_US": @"English (US)", @"pt_BR": @"Português (Brasil)", @"es_ES": @"Español (España)", @"fr_FR": @"Français (France)",
                             @"de_DE": @"Deutsch (Deutschland)", @"emoji": @"Emoji" };
    return names[lang];
}
static NSArray *letter_rows(NSString *lang) {
    if ([lang hasPrefix:@"fr"]) return @[@[@"a", @"z", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"], @[@"q", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l", @"m"], @[@"w", @"x", @"c", @"v", @"b", @"n", @"'"]];
    if ([lang hasPrefix:@"de"]) return @[@[@"q", @"w", @"e", @"r", @"t", @"z", @"u", @"i", @"o", @"p", @"ü"], @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l", @"ö", @"ä"], @[@"y", @"x", @"c", @"v", @"b", @"n", @"m"]];
    if ([lang hasPrefix:@"es"]) return @[@[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"], @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l", @"ñ"], @[@"z", @"x", @"c", @"v", @"b", @"n", @"m"]];
    return @[@[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p"], @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l"], @[@"z", @"x", @"c", @"v", @"b", @"n", @"m"]];
}
static NSArray *rows_for(int layer, NSString *lang) {
    switch (layer) {
    case L_NUMBERS: return @[@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"], @[@"-", @"/", @":", @";", @"(", @")", [lang hasPrefix:@"en"] || [lang hasPrefix:@"pt"] ? @"$" : @"€", @"&", @"@", @"\""], @[@".", @",", @"?", @"!", @"'"]];
    case L_SYMBOLS: return @[@[@"[", @"]", @"{", @"}", @"#", @"%", @"^", @"*", @"+", @"="], @[@"_", @"\\", @"|", @"~", @"<", @">", @"€", @"£", @"¥", @"•"], @[@".", @",", @"?", @"!", @"'"]];
    default: return letter_rows(lang);
    }
}
static NSArray<NSString *> *accents_for(NSString *k, NSString *lang) {
    static NSDictionary *t;
    if (!t) t = @{ @"a": @[@"à", @"á", @"â", @"ä", @"æ", @"ã", @"å", @"ā"], @"e": @[@"è", @"é", @"ê", @"ë", @"ē", @"ė", @"ę"],
                   @"i": @[@"î", @"ï", @"í", @"ī", @"į", @"ì"], @"o": @[@"ô", @"ö", @"ò", @"ó", @"œ", @"ø", @"ō", @"õ"],
                   @"u": @[@"û", @"ü", @"ù", @"ú", @"ū"], @"c": @[@"ç", @"ć", @"č"], @"n": @[@"ñ", @"ń"], @"s": @[@"ß", @"ś", @"š"],
                   @"y": @[@"ÿ"], @"z": @[@"ž", @"ź", @"ż"], @"l": @[@"ł"], @"'": @[@"’", @"‘", @"`"], @"?": @[@"¿"], @"!": @[@"¡"],
                   @"-": @[@"–", @"—", @"•"], @"\"": @[@"”", @"“", @"„", @"»", @"«"], @"$": @[@"€", @"£", @"¥", @"₩", @"₽"] };
    return t[k.lowercaseString];
}
static NSArray<NSArray<NSString *> *> *emoji_pages(void) {
    return @[
        [@"😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🥸 🤩 🥳" componentsSeparatedByString:@" "],
        [@"🐶 🐱 🐭 🐹 🐰 🦊 🐻 🐼 🐨 🐯 🦁 🐮 🐷 🐸 🐵 🐔 🐧 🐦 🐤 🦆 🦅 🦉 🦇 🐺 🐗 🐴 🦄 🐝 🐛 🦋 🐌 🐞" componentsSeparatedByString:@" "],
        [@"🍏 🍎 🍐 🍊 🍋 🍌 🍉 🍇 🍓 🫐 🍈 🍒 🍑 🥭 🍍 🥥 🥝 🍅 🍆 🥑 🥦 🥬 🥒 🌶 🌽 🥕 🥐 🍞 🧀 🍕 🍔 🍟" componentsSeparatedByString:@" "],
        [@"⚽️ 🏀 🏈 ⚾️ 🎾 🏐 🏉 🎱 🏓 🏸 🥅 ⛳️ 🏹 🎣 🥊 🎽 🛹 ⛸ 🎿 🏆 🥇 🎮 🎲 🎯 🎳 🎸 🎹 🎺 🎻 🥁 🎤 🎧" componentsSeparatedByString:@" "],
        [@"❤️ 🧡 💛 💚 💙 💜 🖤 🤍 💔 ❣️ 💕 💞 💓 💗 💖 💘 💝 ✨ ⭐️ 🌟 🔥 💥 ☀️ 🌈 ☁️ ❄️ 💧 🌊 👍 👎 👏 🙏" componentsSeparatedByString:@" "],
    ];
}

@interface __IsimKeyboardKeys : UIView
@property (nonatomic, weak) id<UIKeyInput> target;
@property (nonatomic) BOOL showGlobe;                 /* devices without the bottom bar */
@property (nonatomic, copy) NSString *language;       /* en_US, pt_BR, es_ES, fr_FR, de_DE, emoji */
@property (nonatomic, copy) void (^onGlobe)(void);
@property (nonatomic, copy) void (^onLeaveEmoji)(void);
@property (nonatomic, readonly) BOOL showsPredictions;
- (void)_updateSuggestions;
@end
@implementation __IsimKeyboardKeys {
    int _layer; BOOL _shift, _caps; NSUInteger _emojiPage;
    NSMutableArray<UIButton *> *_keys;
    NSTimer *_repeat;
    UIView *_bar, *_popup; NSArray<UIButton *> *_popupKeys; BOOL _suppressTap;
    NSArray<NSString *> *_suggestions;
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { _keys = [NSMutableArray array]; _language = @"en_US"; [self _rebuild]; }
    return self;
}
- (BOOL)_emoji { return [_language isEqualToString:@"emoji"]; }
- (BOOL)showsPredictions {
    id t = _target;
    if ([self _emoji] || !pref_on(@"KeyboardPrediction") || !t) return NO;
    if ([t respondsToSelector:@selector(autocorrectionType)] && [(id<UITextInputTraits>)t autocorrectionType] == UITextAutocorrectionTypeNo) return NO;
    if ([t respondsToSelector:@selector(isSecureTextEntry)] && [(id<UITextInputTraits>)t isSecureTextEntry]) return NO;
    return [t conformsToProtocol:@protocol(UITextInput)];
}
- (CGFloat)_top { return self.showsPredictions ? 44 : 0; }
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
- (NSString *)_spaceTitle {
    NSString *l = _language;
    return [l hasPrefix:@"pt"] ? @"espaço" : [l hasPrefix:@"es"] ? @"espacio" : [l hasPrefix:@"fr"] ? @"espace" : [l hasPrefix:@"de"] ? @"Leerzeichen" : @"space";
}
- (void)_rebuild {
    for (UIButton *b in _keys) [b removeFromSuperview];
    [_keys removeAllObjects];
    [_popup removeFromSuperview]; _popup = nil;
    if (!_bar) {
        _bar = [UIView new];
        _bar.accessibilityIdentifier = @"isim-kb-predictions";
        [self addSubview:_bar];
    }
    _bar.hidden = !self.showsPredictions;
    if ([self _emoji]) { [self _rebuildEmoji]; return; }
    NSArray *rows = rows_for(_layer, _language);
    for (NSUInteger r = 0; r < rows.count; r++)
        for (NSString *k in rows[r]) {
            UIButton *b = [self _key:[self _upper] ? k.uppercaseString : k ident:[@"isim-kb-" stringByAppendingString:k] special:NO action:@selector(_char:)];
            b.tag = (NSInteger)r;
            if (accents_for(k, _language).count) {
                UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_accentHold:)];
                lp.minimumPressDuration = 0.45; lp.cancelsTouchesInView = NO;
                [b addGestureRecognizer:lp];
            }
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
    UIButton *space = [self _key:[self _spaceTitle] ident:@"isim-kb-space" special:NO action:@selector(_space)];
    space.titleLabel.font = [UIFont systemFontOfSize:16];
    space.tag = 104;
    UIButton *ret = [self _key:[self _returnTitle] ident:@"isim-kb-return" special:YES action:@selector(_return)];
    if ([self _returnIsBlue]) { ret.backgroundColor = UIColor.systemBlueColor; [ret setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    ret.tag = 105;
    [self _updateSuggestions];
    [self setNeedsLayout];
    if (self.bounds.size.width > 0) [self layoutSubviews];     /* keys are tappable right away (fast scripted typing) */
    isim_ui_set_needs_display();
}
- (void)_rebuildEmoji {
    NSArray *pages = emoji_pages();
    NSArray *page = pages[_emojiPage % pages.count];
    for (NSString *e in page) {
        UIButton *b = [self _key:e ident:[@"isim-kb-emoji-" stringByAppendingString:e] special:NO action:@selector(_char:)];
        b.backgroundColor = UIColor.clearColor; b.layer.shadowOpacity = 0;
        b.titleLabel.font = [UIFont systemFontOfSize:30];
        b.tag = 200;
    }
    UIButton *abc = [self _key:@"ABC" ident:@"isim-kb-abc" special:YES action:@selector(_leaveEmoji)];
    abc.tag = 102;
    NSArray *cats = @[@"😀", @"🐶", @"🍏", @"⚽️", @"❤️"];
    for (NSUInteger i = 0; i < cats.count; i++) {
        UIButton *c = [self _key:cats[i] ident:[NSString stringWithFormat:@"isim-kb-emoji-cat-%lu", (unsigned long)i] special:YES action:@selector(_emojiCategory:)];
        c.titleLabel.font = [UIFont systemFontOfSize:17];
        c.backgroundColor = i == _emojiPage ? dyn(0.67, 0.27) : UIColor.clearColor; c.layer.shadowOpacity = 0;
        c.tag = 300 + (NSInteger)i;
    }
    UIButton *del = [self _key:@"⌫" ident:@"isim-kb-delete" special:YES action:@selector(_deleteOnce)];
    del.backgroundColor = UIColor.clearColor; del.layer.shadowOpacity = 0;
    del.tag = 101;
    [self setNeedsLayout];
    isim_ui_set_needs_display();
}
- (void)_emojiCategory:(UIButton *)b { _emojiPage = (NSUInteger)(b.tag - 300); [self _rebuild]; }
- (void)_leaveEmoji { if (_onLeaveEmoji) _onLeaveEmoji(); }
- (UIReturnKeyType)_returnType { id t = _target; return [t respondsToSelector:@selector(returnKeyType)] ? [(id<UITextInputTraits>)t returnKeyType] : UIReturnKeyDefault; }
- (NSString *)_returnTitle {
    BOOL pt = [_language hasPrefix:@"pt"], es = [_language hasPrefix:@"es"], fr = [_language hasPrefix:@"fr"], de = [_language hasPrefix:@"de"];
    switch ([self _returnType]) {
    case UIReturnKeyGo: return pt ? @"ir" : es ? @"ir" : fr ? @"aller" : de ? @"Los" : @"go";
    case UIReturnKeyGoogle: case UIReturnKeySearch: case UIReturnKeyYahoo: return pt ? @"buscar" : es ? @"buscar" : fr ? @"rechercher" : de ? @"Suchen" : @"search";
    case UIReturnKeyJoin: return @"join"; case UIReturnKeyNext: return pt || es ? @"seguinte" : fr ? @"suivant" : de ? @"Weiter" : @"next";
    case UIReturnKeyRoute: return @"route";
    case UIReturnKeySend: return pt ? @"enviar" : es ? @"enviar" : fr ? @"envoyer" : de ? @"Senden" : @"send";
    case UIReturnKeyDone: return pt ? @"OK" : es ? @"OK" : fr ? @"OK" : de ? @"Fertig" : @"done";
    case UIReturnKeyEmergencyCall: return @"emergency";
    case UIReturnKeyContinue: return @"continue";
    default: return pt ? @"retorno" : es ? @"intro" : fr ? @"retour" : de ? @"Return" : @"return";
    }
}
- (BOOL)_returnIsBlue { UIReturnKeyType t = [self _returnType]; return t != UIReturnKeyDefault && t != UIReturnKeyNext && t != UIReturnKeyContinue; }
- (void)layoutSubviews {
    CGFloat W = self.bounds.size.width, gap = 6, side = 3, keyH = 42, rowH = 54, top = 8 + [self _top];
    _bar.frame = CGRectMake(0, 0, W, 44);
    [self _layoutBar];
    if ([self _emoji]) {
        CGFloat cw = (W - 2 * side) / 8, ch = 40;
        NSUInteger i = 0;
        for (UIButton *b in _keys) if (b.tag == 200) { b.frame = CGRectMake(side + (i % 8) * cw, 6 + (i / 8) * ch, cw, ch); i++; }
        CGFloat y = 6 + 4 * ch + 6, x = side;
        for (UIButton *b in _keys) if (b.tag == 102) { b.frame = CGRectMake(x, y, 56, 36); x += 62; }
        for (UIButton *b in _keys) if (b.tag >= 300) { b.frame = CGRectMake(x, y, 36, 36); x += 40; }
        for (UIButton *b in _keys) if (b.tag == 101) b.frame = CGRectMake(W - side - 50, y, 50, 36);
        return;
    }
    NSUInteger maxRow = 0; NSArray *rows = rows_for(_layer, _language);
    for (NSArray *r in rows) maxRow = MAX(maxRow, r.count);
    CGFloat kw = (W - 2 * side - (maxRow - 1) * gap) / maxRow, base = (W - 2 * side - 9 * gap) / 10;
    CGFloat specialW = base * 1.3 + 4;
    NSMutableArray *rowKeys[3] = { [NSMutableArray array], [NSMutableArray array], [NSMutableArray array] };
    for (UIButton *b in _keys) if (b.tag < 3) [rowKeys[b.tag] addObject:b];
    for (int r = 0; r < 3; r++) {
        NSArray *ks = rowKeys[r];
        CGFloat y = top + r * rowH, x;
        if (r < 2) { x = (W - ks.count * kw - (ks.count - 1) * gap) / 2; }
        else {
            /* third row: shift/symbols key and delete at the edges, characters centered between */
            CGFloat cw = _layer == L_LETTERS ? fmin(kw, (W - 2 * side - 2 * specialW - 2 * 10 - (ks.count - 1) * gap) / ks.count) : (W - 2 * side - 2 * specialW - 2 * 14 - 4 * gap) / 5;
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
    CGFloat modeW = _showGlobe ? round(base * 1.25) : round(base * 2.5 + gap), retW = round(base * 2.5 + gap), x = side;
    for (UIButton *b in _keys) if (b.tag == 102) { b.frame = CGRectMake(x, y4, modeW, keyH); x += modeW + gap; }
    for (UIButton *b in _keys) if (b.tag == 103) { b.frame = CGRectMake(x, y4, modeW, keyH); x += modeW + gap; }
    for (UIButton *b in _keys) if (b.tag == 104) b.frame = CGRectMake(x, y4, W - side - retW - gap - x, keyH);
    for (UIButton *b in _keys) if (b.tag == 105) b.frame = CGRectMake(W - side - retW, y4, retW, keyH);
}
- (void)setTarget:(id<UIKeyInput>)t { _target = t; _layer = L_LETTERS; _caps = NO; [self _updateAutoShift]; [self _rebuild]; }
- (void)setShowGlobe:(BOOL)g { if (g == _showGlobe) return; _showGlobe = g; [self _rebuild]; }
- (void)setLanguage:(NSString *)l { if ([l isEqualToString:_language]) return; _language = [l copy]; _layer = L_LETTERS; [self _updateAutoShift]; [self _rebuild]; }
/* text before the caret (UITextInput), or the whole text */
- (NSString *)_textBeforeCaret {
    id t = _target;
    if ([t conformsToProtocol:@protocol(UITextInput)]) {
        id<UITextInput> ti = t;
        UITextRange *sel = ti.selectedTextRange;
        UITextRange *r = sel ? [ti textRangeFromPosition:ti.beginningOfDocument toPosition:sel.start] : nil;
        return r ? [ti textInRange:r] ?: @"" : @"";
    }
    return [t respondsToSelector:@selector(text)] ? [t text] ?: @"" : @"";
}
- (void)_updateAutoShift {
    id t = _target;
    UITextAutocapitalizationType ac = [t respondsToSelector:@selector(autocapitalizationType)] ? [(id<UITextInputTraits>)t autocapitalizationType] : UITextAutocapitalizationTypeSentences;
    NSString *text = [self _textBeforeCaret];
    BOOL want = NO;
    NSNumber *pref = global_prefs()[@"KeyboardAutocapitalization"];      /* Settings > General > Keyboard */
    if (pref && !pref.boolValue && ac != UITextAutocapitalizationTypeAllCharacters) ac = UITextAutocapitalizationTypeNone;
    if (ac == UITextAutocapitalizationTypeAllCharacters) want = YES;
    else if (ac == UITextAutocapitalizationTypeSentences) {
        NSString *trim = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        want = trim.length == 0 || [trim hasSuffix:@"."] || [trim hasSuffix:@"!"] || [trim hasSuffix:@"?"] || [text hasSuffix:@"\n"];
        if (trim.length && ![text hasSuffix:@" "] && ![text hasSuffix:@"\n"]) want = NO;
    } else if (ac == UITextAutocapitalizationTypeWords) want = text.length == 0 || [text hasSuffix:@" "];
    _shift = want;
}
/* ---- predictive bar and autocorrection ---- */
- (NSRange)_currentWord:(NSString **)outText {
    NSString *before = [self _textBeforeCaret];
    NSUInteger i = before.length;
    while (i > 0 && ([NSCharacterSet.letterCharacterSet characterIsMember:[before characterAtIndex:i - 1]] || [before characterAtIndex:i - 1] == '\'')) i--;
    if (outText) *outText = [before substringFromIndex:i];
    return NSMakeRange(i, before.length - i);
}
- (void)_updateSuggestions {
    BOOL show = self.showsPredictions;
    _bar.hidden = !show;
    if (!show) { _suggestions = @[]; return; }
    NSString *word = nil; [self _currentWord:&word];
    NSMutableArray *s = [NSMutableArray array];
    UITextChecker *chk = [UITextChecker new];
    if (!word.length) {
        NSDictionary *starters = @{ @"pt": @[@"Eu", @"O", @"A"], @"es": @[@"Yo", @"El", @"La"], @"fr": @[@"Je", @"Le", @"La"], @"de": @[@"Ich", @"Der", @"Die"] };
        s = [starters[[_language substringToIndex:2]] ?: @[@"I", @"The", @"I'm"] mutableCopy];
    } else {
        NSArray *guesses = [chk guessesForWordRange:NSMakeRange(0, word.length) inString:word language:_language] ?: @[];
        NSArray *comps = [chk completionsForPartialWordRange:NSMakeRange(0, word.length) inString:word language:_language] ?: @[];
        [s addObject:[NSString stringWithFormat:@"“%@”", word]];
        for (NSString *g in guesses) if (s.count < 3) [s addObject:g];
        for (NSString *c in comps) if (s.count < 3 && ![s containsObject:c]) {
            BOOL cap = [NSCharacterSet.uppercaseLetterCharacterSet characterIsMember:[word characterAtIndex:0]];
            [s addObject:cap ? [[c substringToIndex:1].uppercaseString stringByAppendingString:[c substringFromIndex:1]] : c];
        }
    }
    _suggestions = s;
    [self _layoutBar];
}
- (void)_layoutBar {
    for (UIView *v in _bar.subviews) [v removeFromSuperview];
    if (_bar.hidden) return;
    CGFloat W = self.bounds.size.width, w = W / 3;
    for (NSUInteger i = 0; i < 3; i++) {
        NSString *t = i < _suggestions.count ? _suggestions[i] : @"";
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:t forState:UIControlStateNormal];
        [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:17];
        b.frame = CGRectMake(i * w, 2, w, 40);
        b.tag = (NSInteger)i;
        b.accessibilityIdentifier = [NSString stringWithFormat:@"isim-kb-suggestion-%lu", (unsigned long)i];
        [b addTarget:self action:@selector(_pickSuggestion:) forControlEvents:UIControlEventTouchUpInside];
        [_bar addSubview:b];
        if (i) { UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(i * w, 12, 1, 20)]; sep.backgroundColor = UIColor.separatorColor; [_bar addSubview:sep]; }
    }
}
- (void)_pickSuggestion:(UIButton *)b {
    if ((NSUInteger)b.tag >= _suggestions.count) return;
    NSString *s = _suggestions[(NSUInteger)b.tag], *word = nil;
    NSRange r = [self _currentWord:&word];
    id t = _target;
    if ([s hasPrefix:@"“"]) s = word;
    NSLog(@"isim: suggestion \"%@\" picked", s);
    if (word.length && [t conformsToProtocol:@protocol(UITextInput)]) {
        id<UITextInput> ti = t;
        UITextPosition *a = [ti positionFromPosition:ti.beginningOfDocument offset:(NSInteger)r.location], *e = [ti positionFromPosition:a offset:(NSInteger)r.length];
        if (a && e) [ti replaceRange:[ti textRangeFromPosition:a toPosition:e] withText:s];
    } else [t insertText:s];
    [self _type:@" " autocorrect:NO];
}
/* space / punctuation after a misspelled word typed on this keyboard: replace it with the best guess */
- (void)_autocorrectBefore:(NSString *)typed {
    id t = _target;
    if (!pref_on(@"KeyboardAutocorrection") || ![t conformsToProtocol:@protocol(UITextInput)]) return;
    if ([t respondsToSelector:@selector(autocorrectionType)] && [(id<UITextInputTraits>)t autocorrectionType] == UITextAutocorrectionTypeNo) return;
    if ([t respondsToSelector:@selector(isSecureTextEntry)] && [(id<UITextInputTraits>)t isSecureTextEntry]) return;
    if (![@" .,!?;:\n" containsString:typed]) return;
    NSString *word = nil; NSRange r = [self _currentWord:&word];
    if (word.length < 2) return;
    UITextChecker *chk = [UITextChecker new];
    if ([chk rangeOfMisspelledWordInString:word range:NSMakeRange(0, word.length) startingAt:0 wrap:NO language:_language].location == NSNotFound) return;
    NSString *fix = [chk guessesForWordRange:NSMakeRange(0, word.length) inString:word language:_language].firstObject;
    if (!fix) return;
    id<UITextInput> ti = t;
    UITextPosition *a = [ti positionFromPosition:ti.beginningOfDocument offset:(NSInteger)r.location], *e = [ti positionFromPosition:a offset:(NSInteger)r.length];
    if (!a || !e) return;
    [ti replaceRange:[ti textRangeFromPosition:a toPosition:e] withText:fix];
    NSLog(@"isim: autocorrected \"%@\" to \"%@\"", word, fix);
}
- (void)_type:(NSString *)s { [self _type:s autocorrect:YES]; }
- (void)_type:(NSString *)s autocorrect:(BOOL)ac {
    if (ac) [self _autocorrectBefore:s];
    [_target insertText:s];
    BOOL was = _shift;
    [self _updateAutoShift];
    if (was != _shift && _layer == L_LETTERS) [self _rebuild]; else [self _updateSuggestions];
}
- (void)_char:(UIButton *)b {
    if (_suppressTap) { _suppressTap = NO; return; }
    [_popup removeFromSuperview]; _popup = nil;
    [self _type:b.currentTitle];
}
/* ---- accent popup ---- */
- (void)_accentHold:(UILongPressGestureRecognizer *)g {
    UIButton *key = (UIButton *)g.view;
    if (g.state == UIGestureRecognizerStateBegan) {
        _suppressTap = YES;
        [_popup removeFromSuperview];
        NSString *base = [key.accessibilityIdentifier substringFromIndex:@"isim-kb-".length];
        NSArray *vs = accents_for(base, _language);
        CGFloat cw = 34, h = 46, w = cw * vs.count + 8;
        CGRect kf = key.frame;
        CGFloat x = fmax(2, fmin(CGRectGetMidX(kf) - w / 2, self.bounds.size.width - w - 2)), y = fmax(0, kf.origin.y - h - 4);
        _popup = [[UIView alloc] initWithFrame:CGRectMake(x, y, w, h)];
        _popup.backgroundColor = dyn(1, 0.42);
        _popup.layer.cornerRadius = 8;
        _popup.layer.shadowColor = UIColor.blackColor.CGColor; _popup.layer.shadowOpacity = 0.35; _popup.layer.shadowRadius = 4;
        _popup.accessibilityIdentifier = @"isim-kb-accents";
        NSMutableArray *ks = [NSMutableArray array];
        for (NSUInteger i = 0; i < vs.count; i++) {
            NSString *v = [self _upper] ? [vs[i] uppercaseString] : vs[i];
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            [b setTitle:v forState:UIControlStateNormal];
            [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
            b.titleLabel.font = [UIFont systemFontOfSize:22];
            b.frame = CGRectMake(4 + i * cw, 4, cw, h - 8);
            b.layer.cornerRadius = 5;
            b.accessibilityIdentifier = [@"isim-kb-accent-" stringByAppendingString:vs[i]];
            [b addTarget:self action:@selector(_accentTap:) forControlEvents:UIControlEventTouchUpInside];
            [_popup addSubview:b];
            [ks addObject:b];
        }
        _popupKeys = ks;
        [self addSubview:_popup];
        NSLog(@"isim: accents for %@: %@", base, [vs componentsJoinedByString:@" "]);
        isim_ui_set_needs_display();
        return;
    }
    if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled)
        dispatch_async(dispatch_get_main_queue(), ^{ self->_suppressTap = NO; });    /* after the key's own touch up */
    if (!_popup) return;
    CGPoint p = [g locationInView:_popup];
    UIButton *hit = nil;
    /* the finger must slide onto a variant; lifting without sliding keeps the popup open to tap one */
    BOOL slid = CGRectContainsPoint(CGRectInset(_popup.bounds, 0, -30), p) && p.y < _popup.bounds.size.height + 8;
    for (UIButton *b in _popupKeys) { BOOL on = slid && CGRectContainsPoint(CGRectInset(b.frame, 0, -30), p); b.backgroundColor = on ? UIColor.systemBlueColor : UIColor.clearColor; if (on) hit = b; }
    if (g.state == UIGestureRecognizerStateEnded && hit) [self _accentTap:hit];      /* slid onto a variant and lifted */
    isim_ui_set_needs_display();
}
- (void)_accentTap:(UIButton *)b {
    NSString *t = b.currentTitle;
    [_popup removeFromSuperview]; _popup = nil; _popupKeys = nil;
    [self _type:t];
}
- (void)_space {
    [_popup removeFromSuperview]; _popup = nil;
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
- (void)_deleteOnce { [_target deleteBackward]; BOOL was = _shift; [self _updateAutoShift]; if (was != _shift && _layer == L_LETTERS) [self _rebuild]; else [self _updateSuggestions]; }
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

static NSArray<NSString *> *system_boards(void) { return @[@"en_US", @"pt_BR", @"es_ES", @"fr_FR", @"de_DE", @"emoji"]; }
static BOOL is_system(NSString *ident) { return [system_boards() containsObject:ident]; }

@interface __IsimKeyboardController : NSObject
@end
@implementation __IsimKeyboardController {
    __IsimKeyboardWindow *_window;
    UIView *_content, *_bar, *_menu;
    UIButton *_barGlobe;
    __IsimKeyboardKeys *_keys;
    NSMutableArray<__IsimCustomKeyboard *> *_custom;
    NSMutableArray<NSString *> *_order;  /* enabled keyboards: system ids (en_US, ..., emoji) and extension bundle ids */
    NSInteger _current, _lastLetters;    /* index into _order */
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
- (__IsimCustomKeyboard *)_customFor:(NSString *)ident { for (__IsimCustomKeyboard *k in _custom) if ([k.bundleID isEqualToString:ident]) return k; return nil; }
- (NSString *)_ident { return _current >= 0 && _current < (NSInteger)_order.count ? _order[(NSUInteger)_current] : @"en_US"; }
/* Keyboards: the built-in ones enabled in Settings > General > Keyboard > Keyboards (AppleKeyboards entries
 * "en_US@sw=QWERTY;hw=Automatic", "emoji@sw=Emoji", ...; default English (US) + Emoji), the app's own embedded keyboard
 * extensions, and under the shell those of every installed app. Under the shell only keyboards enabled in Settings are
 * offered; with plain `isim run` the app's own keyboards are enabled. ISIM_KEYBOARDS=all|none overrides (extensions). */
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
        if ([self _customFor:ident]) continue;
        __IsimCustomKeyboard *k = [__IsimCustomKeyboard new];
        k.bundleID = ident; k.name = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: name.stringByDeletingPathExtension;
        k.executable = [path stringByAppendingPathComponent:info[@"CFBundleExecutable"] ?: name.stringByDeletingPathExtension];
        k.principal = ext[@"NSExtensionPrincipalClass"];
        [_custom addObject:k];
    }
}
- (void)_discover {
    if (_custom) return;
    _custom = [NSMutableArray array];
    _order = [NSMutableArray array];
    NSArray *prefs = global_prefs()[@"AppleKeyboards"];
    if (![prefs isKindOfClass:[NSArray class]]) prefs = @[];
    const char *env = getenv("ISIM_KEYBOARDS");
    BOOL none = env && !strcmp(env, "none");
    BOOL all = (env && !strcmp(env, "all")) || !isim_shell_present();
    if (!none) {
        if (isim_shell_present()) {
            NSString *apps = isim_ui_installed_apps_dir();
            NSMutableArray *paths = [NSMutableArray arrayWithObject:NSBundle.mainBundle.bundlePath];
            for (NSString *a in [NSFileManager.defaultManager contentsOfDirectoryAtPath:apps error:NULL])
                if ([a hasSuffix:@".app"]) [paths addObject:[apps stringByAppendingPathComponent:a]];
            for (NSString *a in paths) [self _addKeyboardsIn:a enabled:prefs all:all];
        } else [self _addKeyboardsIn:NSBundle.mainBundle.bundlePath enabled:prefs all:all];
    }
    BOOL anySystem = NO;
    for (NSString *p in prefs) if ([p isKindOfClass:[NSString class]] && [p containsString:@"@sw="]) anySystem = YES;
    if (!anySystem) [_order addObject:@"en_US"];
    for (NSString *p in prefs) {
        if (![p isKindOfClass:[NSString class]]) continue;
        NSString *ident = [p containsString:@"@"] ? [p componentsSeparatedByString:@"@"][0] : p;
        if (is_system(ident) ? ![_order containsObject:ident] : ([self _customFor:ident] && ![_order containsObject:ident])) [_order addObject:ident];
    }
    for (__IsimCustomKeyboard *k in _custom) if (![_order containsObject:k.bundleID]) [_order addObject:k.bundleID];
    if (!anySystem) [_order addObject:@"emoji"];
    if (!_order.count) [_order addObject:@"en_US"];
}
- (void)_settingsChanged {
    /* keyboards enabled/disabled in Settings: rebuild the list (keep the current one if still enabled) */
    NSString *current = [self _ident];
    NSMutableArray *old = _custom;
    _custom = nil; [self _discover];
    for (__IsimCustomKeyboard *k in _custom) for (__IsimCustomKeyboard *o in old) if ([o.bundleID isEqualToString:k.bundleID]) k.controller = o.controller;
    NSUInteger idx = [_order indexOfObject:current];
    if (idx == NSNotFound) [self _activate:0]; else _current = (NSInteger)idx;
    [self _updateBarButton];
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
    _keys.onLeaveEmoji = ^{ [w _leaveEmoji]; };
    _bar = [UIView new]; [_window addSubview:_bar];
    UIButton *globe = [UIButton buttonWithType:UIButtonTypeCustom];
    globe.tintColor = UIColor.secondaryLabelColor;
    globe.frame = CGRectMake(12, 2, 44, 40);
    [globe addTarget:self action:@selector(_barTapped) forControlEvents:UIControlEventTouchUpInside];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_globeHold:)];
    lp.minimumPressDuration = 0.4;
    [globe addGestureRecognizer:lp];
    [_bar addSubview:globe];
    _barGlobe = globe;
    UIButton *mic = [UIButton buttonWithType:UIButtonTypeCustom];
    [mic setImage:[UIImage systemImageNamed:@"mic" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22]] forState:UIControlStateNormal];
    mic.tintColor = UIColor.secondaryLabelColor;
    mic.accessibilityIdentifier = @"isim-kb-dictation";
    mic.accessibilityLabel = @"Dictate";
    mic.tag = 77;
    [mic addTarget:self action:@selector(_dictation) forControlEvents:UIControlEventTouchUpInside];
    [_bar addSubview:mic];
    [self _updateBarButton];
}
/* iOS: with one language and Emoji the bar shows the emoji key; with more keyboards, the globe */
- (BOOL)_emojiKeyOnly { return _order.count == 2 && [_order containsObject:@"emoji"] && is_system(_order[0]) && is_system(_order[1]); }
- (void)_updateBarButton {
    if (!_barGlobe) return;
    BOOL emojiKey = [self _emojiKeyOnly];
    [_barGlobe setImage:[UIImage systemImageNamed:emojiKey ? @"face.smiling" : @"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:24]] forState:UIControlStateNormal];
    _barGlobe.accessibilityIdentifier = emojiKey ? @"isim-kb-emoji" : @"isim-kb-globe";
    _barGlobe.accessibilityLabel = emojiKey ? @"Emoji" : @"Next keyboard";
}
- (void)_barTapped { [self _next]; }
- (void)_dictation { NSLog(@"isim: dictation is not available on isim (no speech recognition)"); }
- (void)_leaveEmoji {
    NSInteger back = _lastLetters >= 0 && _lastLetters < (NSInteger)_order.count && ![_order[(NSUInteger)_lastLetters] isEqualToString:@"emoji"] ? _lastLetters : 0;
    [self _switchTo:back];
}
- (CGFloat)_contentHeight {
    if (is_system([self _ident]) || !_hostedView) return 216 + ([_keys showsPredictions] ? 44 : 0);
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
    for (UIView *b in _bar.subviews) if (b.tag == 77) b.frame = CGRectMake(d->width - 56, 2, 44, 40);
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
    [self _build]; [self _discover]; [self _updateBarButton];
    id old = _target;
    _target = t;
    _keys.showGlobe = ![self _barVisible] && _order.count > 1;
    _keys.target = t;
    [self _activate:_current];
    __IsimCustomKeyboard *ck = [self _customFor:[self _ident]];
    if (ck && old != t) [ck.controller _isim_setTextInput:t];
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
    if (ck) { [ck.controller viewWillAppear:NO]; [ck.controller viewDidAppear:NO]; }
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
    __IsimCustomKeyboard *ck = [self _customFor:[self _ident]];
    if (ck) [ck.controller viewWillDisappear:NO];
    _window.hidden = YES;
    keyboard_frame = CGRectZero;
    if (ck) { [ck.controller viewDidDisappear:NO]; [ck.controller _isim_setTextInput:nil]; }
    [self _post:UIKeyboardDidHideNotification from:from to:to];
    [self _post:UIKeyboardDidChangeFrameNotification from:from to:to];
    isim_ui_set_needs_layout();
    NSLog(@"isim: keyboard hidden");
}
- (NSString *)_nameFor:(NSString *)ident { return isim_ui_keyboard_language_name(ident) ?: [self _customFor:ident].name ?: ident; }
- (NSString *)_currentName { return [self _nameFor:[self _ident]]; }
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
    if (idx < 0 || idx >= (NSInteger)_order.count) idx = 0;
    __IsimCustomKeyboard *nk = [self _customFor:_order[(NSUInteger)idx]];
    if (nk && ![self _load:nk]) { idx = 0; nk = nil; }
    __IsimCustomKeyboard *ok = [self _customFor:[self _ident]];
    UIInputViewController *oldVC = ok.controller, *newVC = nk.controller;
    UIView *newView = newVC ? newVC.view : _keys;
    if (!newVC) _keys.language = _order[(NSUInteger)idx];
    if (newView == (_hostedView ?: (UIView *)(_keys.superview ? _keys : nil)) && _current == idx) { [self _relayout]; return; }
    if (oldVC && oldVC != newVC && _shown) [oldVC viewWillDisappear:NO];
    [_hostedView removeFromSuperview]; [_keys removeFromSuperview];
    if (oldVC && oldVC != newVC) { if (_shown) [oldVC viewDidDisappear:NO]; [oldVC _isim_setTextInput:nil]; }
    _current = idx;
    if (![_order[(NSUInteger)idx] isEqualToString:@"emoji"] && !newVC) _lastLetters = idx;
    _hostedView = newVC ? newView : nil;
    if (newVC) {
        newView.translatesAutoresizingMaskIntoConstraints = YES;
        [_content addSubview:newView];
        [newVC _isim_setTextInput:_target];
        if (_shown) [newVC viewWillAppear:NO];
    } else [_content addSubview:_keys];
    [self _relayout];
    if (newVC && _shown) [newVC viewDidAppear:NO];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextInputCurrentInputModeDidChangeNotification object:nil];
}
- (void)_next {
    [self _discover];
    NSInteger n = (NSInteger)_order.count;
    if (n < 2) return;
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
    NSMutableArray *names = [NSMutableArray array];
    for (NSString *i in _order) [names addObject:[self _nameFor:i]];
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
        NSString *ident = _order[i];
        b.accessibilityIdentifier = [ident isEqualToString:@"en_US"] ? @"isim-kb-menu-builtin" : [@"isim-kb-menu-" stringByAppendingString:ident];
        [b addTarget:self action:@selector(_menuPick:) forControlEvents:UIControlEventTouchUpInside];
        [_menu addSubview:b];
    }
    /* the menu floats above the keys inside the keyboard window */
    [_window addSubview:_menu];
    NSLog(@"isim: keyboard list shown");
}
- (void)_menuPick:(UIButton *)b { [self _switchTo:b.tag]; }
- (BOOL)_needsSwitchKey { return ![self _barVisible]; }
- (NSString *)_language { NSString *i = [self _ident]; return is_system(i) && ![i isEqualToString:@"emoji"] ? i : _order.count && _lastLetters < (NSInteger)_order.count && is_system(_order[(NSUInteger)_lastLetters]) ? _order[(NSUInteger)_lastLetters] : @"en_US"; }
- (void)_suggestionsChanged {
    if (!_shown || _hostedView) return;
    CGFloat before = _content.frame.size.height;
    [_keys _updateSuggestions];
    if ([self _contentHeight] != before) [self _relayout];
}
- (NSArray<NSString *> *)_activeLanguages { [self _discover]; return _order; }
@end

/* custom keyboards ask this through needsInputModeSwitchKey */
BOOL isim_ui_keyboard_needs_switch_key(void) { return isim_ui_device()->safe_bottom <= 0; }
void isim_ui_keyboard_advance(void) { [[__IsimKeyboardController shared] _next]; }
void isim_ui_keyboard_check(void) { [[__IsimKeyboardController shared] _check]; }
void isim_ui_keyboard_install(void) { [__IsimKeyboardController load_isim]; }
NSString *isim_ui_keyboard_current_language(void) { return [[__IsimKeyboardController shared] _language]; }
void isim_ui_keyboard_suggestions_changed(void) { [[__IsimKeyboardController shared] _suggestionsChanged]; }
NSArray<NSString *> *isim_ui_keyboard_enabled(void) { return [[__IsimKeyboardController shared] _activeLanguages]; }
