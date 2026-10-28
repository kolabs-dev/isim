/* isim system keyboard: a window at the bottom of the screen that appears while a key-input
 * responder (UITextField, ...) is first responder.
 *  - built-in keyboards enabled in Settings (English (US), Português (Brasil), Español, Français, Deutsch, Emoji):
 *    letters / numbers / symbols layers, shift + auto-capitalization, accent popups, predictive bar, autocorrection,
 *    delete with auto-repeat, return key titled by returnKeyType; inline predictions (the completion in grey after the
 *    caret, accepted with space); the QuickType bar's AutoFill (passwords, one-time codes) and dictation (mic key;
 *    the speech comes from the script command `dictate`): UITextServices.m;
 *  - the responder's keyboardType: number / decimal / phone pads (3 x 4 keys, letters under the digits, no return
 *    key), the email (@ .), URL (. / .com, no space), Twitter (@ #) and web search (.) bottom rows, numbers and
 *    punctuation starting (and staying) on the numbers layer;
 *  - custom keyboards: the app's embedded keyboard extensions (PlugIns/<name>.appex,
 *    com.apple.keyboard-service). isim loads the extension executable into the app process
 *    (iOS runs it out of process) and hosts its UIInputViewController. All embedded keyboards
 *    count as enabled (iOS needs Settings > Keyboards); ISIM_KEYBOARDS=none disables them;
 *  - Face ID iPhones get the bottom bar with the globe key (tap: next keyboard, hold: list);
 *    custom keyboards then report needsInputModeSwitchKey = NO, as on iOS;
 *  - iPads get the iPadOS layout (ipad_rows below): delete and return at the row ends, shift on both sides, the
 *    globe / emoji, mic and hide-keyboard keys in the bottom row, flick characters on the letter keys, no bar.
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
/* ---- iPad (adapted): the iPadOS keyboard of iPads with the standard layout (iPad mini, Air, Pro 11"). Four rows:
 *   q w e r t y u i o p  delete  /  a s d f g h j k l  return  /  shift z x c v b n m , .  shift  /
 *   .?123  globe or emoji  mic  space  .?123  hide-keyboard
 * every letter key of the English layout shows the character of the numbers plane above its letter (small, grey) and
 * types it on a downward swipe ("flick", iPadOS 11 and later; tap: the letter). No bar under the keys (the globe and
 * the mic are in the bottom row), number / phone pads show the numbers plane (iPadOS has no 3 x 4 pad on iPad).
 * Row contents follow iPadOS (en_US); the symbols plane's third row, the key proportions and sizes are estimated from
 * screenshots, not measured (see ipad_metrics). Other languages use their letter rows in the same frame, with the flick
 * characters only on the punctuation keys. The floating / split keyboards are not implemented.
 * The 13" iPad Pro (screens 1000 pt and wider on the short side) has iPadOS's extended layout for English, five rows:
 *   ` 1 2 3 4 5 6 7 8 9 0 - =  delete  /  tab  q w e r t y u i o p [ ] \  /  caps lock  a s d f g h j k l ; '  return  /
 *   shift  z x c v b n m , . /  shift  /  globe or emoji  .?123  mic  space  .?123  hide-keyboard
 * with the shifted character above the number-row and punctuation keys (a downward swipe or shift types it; the letters
 * have none). Its numbers and symbols planes, and other languages, are the standard layout. The key proportions are
 * estimated from screenshots, not measured. */
static BOOL kb_ipad(void) { return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; }
static NSArray *ipad_rows(int layer, NSString *lang) {
    switch (layer) {
    case L_NUMBERS: return @[@[@"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0"],
                             @[@"@", @"#", [lang hasPrefix:@"en"] || [lang hasPrefix:@"pt"] ? @"$" : @"€", @"&", @"*", @"(", @")", @"'", @"\""],
                             @[@"%", @"-", @"+", @"=", @"/", @";", @":", @",", @"."]];
    case L_SYMBOLS: return @[@[@"[", @"]", @"{", @"}", @"#", @"%", @"^", @"*", @"+", @"="],
                             @[@"_", @"\\", @"|", @"~", @"<", @">", @"€", @"£", @"¥", @"•"],
                             @[@"…", @"¿", @"¡", @"§", @"°", @"`", @"¶", @",", @"."]];      /* estimated */
    default: {
        NSArray *r = letter_rows(lang);
        NSMutableArray *third = [r[2] mutableCopy];
        [third addObjectsFromArray:@[@",", @"."]];
        return @[r[0], r[1], third];
    }
    }
}
/* the 13" iPad Pro's extended letters plane (English) */
static BOOL ipad_extended_device(NSString *lang) {
    const struct isim_device *d = isim_ui_device();
    return [lang hasPrefix:@"en"] && MIN(d->width, d->height) >= 1000;
}
static BOOL ipad_extended(int layer, NSString *lang) { return layer == L_LETTERS && ipad_extended_device(lang); }
static NSArray *ipad_extended_rows(void) {
    return @[@[@"`", @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9", @"0", @"-", @"="],
             @[@"q", @"w", @"e", @"r", @"t", @"y", @"u", @"i", @"o", @"p", @"[", @"]", @"\\"],
             @[@"a", @"s", @"d", @"f", @"g", @"h", @"j", @"k", @"l", @";", @"'"],
             @[@"z", @"x", @"c", @"v", @"b", @"n", @"m", @",", @".", @"/"]];
}
/* the shifted character drawn above a key of the extended layout, as on a hardware keyboard */
static NSString *ipad_extended_flick(NSString *k) {
    static NSDictionary *t;
    if (!t) t = @{ @"`": @"~", @"1": @"!", @"2": @"@", @"3": @"#", @"4": @"$", @"5": @"%", @"6": @"^", @"7": @"&", @"8": @"*",
                   @"9": @"(", @"0": @")", @"-": @"_", @"=": @"+", @"[": @"{", @"]": @"}", @"\\": @"|", @";": @":",
                   @"'": @"\"", @",": @"<", @".": @">", @"/": @"?" };
    return t[k];
}
/* the flick character above a key of the letters plane (the numbers plane at the same place, iPadOS en_US) */
static NSString *ipad_flick(NSString *k, NSString *lang) {
    if ([k isEqualToString:@","]) return @"!";
    if ([k isEqualToString:@"."]) return @"?";
    if (![lang hasPrefix:@"en"]) return nil;
    static NSDictionary *t;
    if (!t) t = @{ @"q": @"1", @"w": @"2", @"e": @"3", @"r": @"4", @"t": @"5", @"y": @"6", @"u": @"7", @"i": @"8", @"o": @"9", @"p": @"0",
                   @"a": @"@", @"s": @"#", @"d": @"$", @"f": @"&", @"g": @"*", @"h": @"(", @"j": @")", @"k": @"'", @"l": @"\"",
                   @"z": @"%", @"x": @"-", @"c": @"+", @"v": @"=", @"b": @"/", @"n": @";", @"m": @":" };
    return t[k];
}
/* the keys' area (without the predictive bar and the home indicator's band) and the gaps, in points. Estimated from
 * iPadOS screenshots: about 264 pt in portrait on the 11" class (the height iPads without the predictive bar had),
 * 352 pt in landscape; the 13" iPad Pro somewhat taller. Keys are near-square in portrait. */
struct ipad_metrics { CGFloat height, side, gap, vgap, top; };
static struct ipad_metrics ipad_metrics(NSString *lang) {
    const struct isim_device *d = isim_ui_device();
    BOOL landscape = d->width > d->height, big = MIN(d->width, d->height) >= 1000;
    struct ipad_metrics m = { landscape ? (big ? 384 : 352) : (big ? 290 : 264), 6, landscape ? 14 : 12, 9, 7 };
    if (ipad_extended_device(lang)) m.height = landscape ? 420 : 340;   /* the extended layout's five rows (estimated);
                                                                       its other planes keep the height */
    return m;
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

@interface UITextChecker (IsimKnown)
- (BOOL)_isim_known:(NSString *)w language:(NSString *)language;
@end
/* an iPad key with a flick character: a downward swipe on it types that character instead of the key's own */
@interface __IsimFlickKey : UIButton
@property (nonatomic, copy) NSString *flick;
@property (nonatomic, readonly) BOOL flicked;          /* the last touch swiped down */
@end
@implementation __IsimFlickKey { CGPoint _down; }
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)e { _down = [touches.anyObject locationInView:self]; _flicked = NO; [super touchesBegan:touches withEvent:e]; }
- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)e {
    CGPoint p = [touches.anyObject locationInView:self];
    _flicked = _flick.length && p.y - _down.y >= fmax(16, self.bounds.size.height * 0.3) && fabs(p.x - _down.x) < self.bounds.size.width;
    [super touchesEnded:touches withEvent:e];
}
@end

@interface __IsimKeyboardKeys : UIView
@property (nonatomic, weak) id<UIKeyInput> target;
@property (nonatomic) BOOL emojiKey;                  /* iPad: the bottom row's key shows the emoji face (English + Emoji only) */
@property (nonatomic, copy) void (^onDismiss)(void);  /* iPad: the hide-keyboard key */
@property (nonatomic, copy) void (^onDictation)(void);/* iPad: the mic key of the bottom row */
- (void)_setDictating:(BOOL)on;
- (CGRect)_spaceFrameIn:(UIView *)v;
- (BOOL)_pad;                                         /* a number / decimal / phone pad */
@property (nonatomic) BOOL showGlobe;                 /* devices without the bottom bar */
@property (nonatomic, copy) NSString *language;       /* en_US, pt_BR, es_ES, fr_FR, de_DE, emoji */
@property (nonatomic, copy) void (^onGlobe)(void);
@property (nonatomic, copy) void (^onLeaveEmoji)(void);
@property (nonatomic, readonly) BOOL showsPredictions;
- (void)_updateSuggestions;
- (void)_clearInline;
- (void)_layoutBar;
@end
@implementation __IsimKeyboardKeys {
    int _layer; BOOL _shift, _caps, _dictatingKey; NSUInteger _emojiPage;
    NSMutableArray<UIButton *> *_keys;
    NSTimer *_repeat;
    UIView *_bar, *_popup; NSArray<UIButton *> *_popupKeys; BOOL _suppressTap;
    NSArray<NSString *> *_suggestions;
    NSArray<__IsimAutoFillSuggestion *> *_autofill;
    NSString *_inline; UILabel *_ghost;          /* inline prediction: the rest of the word, drawn after the caret */
}
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { _keys = [NSMutableArray array]; _language = @"en_US"; [self _rebuild]; }
    return self;
}
- (BOOL)_emoji { return [_language isEqualToString:@"emoji"]; }
- (UIKeyboardType)_kbType { id t = _target; return [t respondsToSelector:@selector(keyboardType)] ? [(id<UITextInputTraits>)t keyboardType] : UIKeyboardTypeDefault; }
- (BOOL)_numberType {
    UIKeyboardType k = [self _kbType];
    return k == UIKeyboardTypeNumberPad || k == UIKeyboardTypeDecimalPad || k == UIKeyboardTypePhonePad || k == UIKeyboardTypeASCIICapableNumberPad;
}
- (BOOL)_pad {
    UIKeyboardType k = [self _kbType];
    return !kb_ipad() && ![self _emoji] && (k == UIKeyboardTypeNumberPad || k == UIKeyboardTypeDecimalPad || k == UIKeyboardTypePhonePad || k == UIKeyboardTypeASCIICapableNumberPad);
}
- (NSArray<__IsimAutoFillSuggestion *> *)_autofillSuggestions { id t = _target; return t && ![self _emoji] ? isim_ui_autofill_suggestions(t) : @[]; }
- (BOOL)showsPredictions {
    id t = _target;
    if (t && [self _autofillSuggestions].count) return YES;
    if ([self _emoji] || [self _pad] || !pref_on(@"KeyboardPrediction") || !t) return NO;
    if ([t respondsToSelector:@selector(autocorrectionType)] && [(id<UITextInputTraits>)t autocorrectionType] == UITextAutocorrectionTypeNo) return NO;
    if ([t respondsToSelector:@selector(isSecureTextEntry)] && [(id<UITextInputTraits>)t isSecureTextEntry]) return NO;
    return [t conformsToProtocol:@protocol(UITextInput)];
}
- (CGFloat)_top { return self.showsPredictions ? 44 : 0; }
- (UIButton *)_key:(NSString *)title ident:(NSString *)ident special:(BOOL)special action:(SEL)sel {
    return [self _key:title ident:ident special:special action:sel class:[UIButton class]];
}
- (UIButton *)_key:(NSString *)title ident:(NSString *)ident special:(BOOL)special action:(SEL)sel class:(Class)cls {
    UIButton *b = [cls buttonWithType:UIButtonTypeCustom];
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
    if (kb_ipad()) { [self _rebuildIPad]; return; }
    if ([self _pad]) { [self _rebuildPad]; return; }
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
    /* the keyboard type's bottom-row keys (between space and return); URL keyboards have no space bar */
    UIKeyboardType kt = [self _kbType];
    NSArray *extras = _layer != L_LETTERS ? nil : kt == UIKeyboardTypeEmailAddress ? @[@"@", @"."] : kt == UIKeyboardTypeURL ? @[@".", @"/", @".com"]
                    : kt == UIKeyboardTypeTwitter ? @[@"@", @"#"] : kt == UIKeyboardTypeWebSearch ? @[@"."] : nil;
    if (kt == UIKeyboardTypeURL && _layer == L_LETTERS) [space removeFromSuperview], [_keys removeObject:space];
    for (NSString *e in extras) {
        UIButton *b = [self _key:e ident:[@"isim-kb-" stringByAppendingString:[e isEqualToString:@".com"] ? @"dotcom" : e] special:NO action:@selector(_char:)];
        b.titleLabel.font = [UIFont systemFontOfSize:[e isEqualToString:@".com"] ? 16 : 20];
        b.tag = 106;
    }
    UIButton *ret = [self _key:[self _returnTitle] ident:@"isim-kb-return" special:YES action:@selector(_return)];
    if ([self _returnIsBlue]) { ret.backgroundColor = UIColor.systemBlueColor; [ret setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    ret.tag = 105;
    [self _updateSuggestions];
    [self setNeedsLayout];
    if (self.bounds.size.width > 0) [self layoutSubviews];     /* keys are tappable right away (fast scripted typing) */
    isim_ui_set_needs_display();
}
/* number / decimal / phone pads: three columns of big keys, the digits with their letters, no return key */
- (void)_rebuildPad {
    UIKeyboardType kt = [self _kbType];
    BOOL phone = kt == UIKeyboardTypePhonePad;
    if (phone && _layer == L_SYMBOLS) {                 /* "+*#": the phone pad's symbols (adapted) */
        for (NSString *k in @[@"+", @"*", @"#", @",", @";", @"(", @")", @"/", @"-"]) [self _key:k ident:[@"isim-kb-" stringByAppendingString:k] special:NO action:@selector(_char:)].tag = 400;
        UIButton *back = [self _key:@"123" ident:@"isim-kb-123" special:YES action:@selector(_padSymbols)];
        back.tag = 401;
    } else {
        NSArray *letters = @[@"", @"ABC", @"DEF", @"GHI", @"JKL", @"MNO", @"PQRS", @"TUV", @"WXYZ"];
        for (int d = 1; d <= 9; d++) {
            UIButton *b = [self _key:[NSString stringWithFormat:@"%d", d] ident:[NSString stringWithFormat:@"isim-kb-%d", d] special:NO action:@selector(_char:)];
            b.titleLabel.font = [UIFont systemFontOfSize:26]; b.tag = 400;
            if (kt != UIKeyboardTypeASCIICapableNumberPad && [letters[d - 1] length]) {
                UILabel *l = [UILabel new]; l.text = letters[d - 1]; l.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
                l.textAlignment = NSTextAlignmentCenter; l.tag = 99; l.textColor = UIColor.labelColor;
                [b addSubview:l];
            }
        }
        if (kt == UIKeyboardTypeDecimalPad) {
            NSString *sep = [NSLocale.currentLocale objectForKey:NSLocaleDecimalSeparator] ?: @".";
            UIButton *dot = [self _key:sep ident:@"isim-kb-decimal" special:NO action:@selector(_char:)];
            dot.titleLabel.font = [UIFont systemFontOfSize:26]; dot.tag = 401;
            dot.backgroundColor = UIColor.clearColor; dot.layer.shadowOpacity = 0;
        } else if (phone) {
            UIButton *sym = [self _key:@"+*#" ident:@"isim-kb-phone-symbols" special:YES action:@selector(_padSymbols)];
            sym.tag = 401; sym.backgroundColor = UIColor.clearColor; sym.layer.shadowOpacity = 0;
        }
    }
    UIButton *zero = [self _key:@"0" ident:@"isim-kb-0" special:NO action:@selector(_char:)];
    zero.titleLabel.font = [UIFont systemFontOfSize:26]; zero.tag = 402;
    UIButton *del = [self _key:@"⌫" ident:@"isim-kb-delete" special:YES action:@selector(_noop)];
    del.titleLabel.font = [UIFont systemFontOfSize:22]; del.backgroundColor = UIColor.clearColor; del.layer.shadowOpacity = 0;
    [del addTarget:self action:@selector(_deleteDown) forControlEvents:UIControlEventTouchDown];
    [del addTarget:self action:@selector(_deleteUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    del.tag = 403;
    [self setNeedsLayout];
    if (self.bounds.size.width > 0) [self layoutSubviews];
    isim_ui_set_needs_display();
}
/* ---- iPad (see ipad_rows) ---- */
- (void)_rebuildIPad {
    BOOL ext = ipad_extended(_layer, _language);
    NSArray *rows = ext ? ipad_extended_rows() : ipad_rows(_layer, _language);
    for (NSUInteger r = 0; r < rows.count; r++)
        for (NSString *k in rows[r]) {
            NSString *flick = ext ? ipad_extended_flick(k) : _layer == L_LETTERS ? ipad_flick(k, _language) : nil;
            UIButton *b = [self _key:[self _upper] ? k.uppercaseString : k ident:[@"isim-kb-" stringByAppendingString:k] special:NO action:@selector(_char:)
                               class:flick ? [__IsimFlickKey class] : [UIButton class]];
            b.tag = (NSInteger)r;
            if (flick) {
                ((__IsimFlickKey *)b).flick = flick;
                UILabel *l = [UILabel new]; l.text = flick; l.tag = 98;
                l.textAlignment = NSTextAlignmentCenter; l.textColor = UIColor.secondaryLabelColor;
                [b addSubview:l];
            }
            if (accents_for(k, _language).count) {
                UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(_accentHold:)];
                lp.minimumPressDuration = 0.45; lp.cancelsTouchesInView = NO;
                [b addGestureRecognizer:lp];
            }
        }
    BOOL letters = _layer == L_LETTERS, up = _shift || _caps;
    NSString *shiftTitle = letters ? (_caps ? @"⇪" : @"⇧") : _layer == L_NUMBERS ? @"#+=" : @"123";
    for (int side = 0; side < 2; side++) {                         /* shift on both ends of the third row */
        UIButton *sh = [self _key:shiftTitle ident:side ? @"isim-kb-shift-right" : @"isim-kb-shift" special:letters ? !up : YES action:@selector(_shift:)];
        if (letters && up) sh.backgroundColor = dyn(1, 0.42);
        sh.tag = side ? 107 : 100;
    }
    UIButton *del = [self _key:@"⌫" ident:@"isim-kb-delete" special:YES action:@selector(_noop)];
    [del addTarget:self action:@selector(_deleteDown) forControlEvents:UIControlEventTouchDown];
    [del addTarget:self action:@selector(_deleteUp) forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel];
    del.tag = 101;
    UIButton *ret = [self _key:[self _returnTitle] ident:@"isim-kb-return" special:YES action:@selector(_return)];
    if ([self _returnIsBlue]) { ret.backgroundColor = UIColor.systemBlueColor; [ret setTitleColor:UIColor.whiteColor forState:UIControlStateNormal]; }
    ret.tag = 105;
    if (ext) {                                                     /* tab and caps lock start rows 2 and 3 */
        UIButton *tab = [self _key:@"tab" ident:@"isim-kb-tab" special:YES action:@selector(_tab)];
        tab.tag = 111;
        UIButton *caps = [self _key:@"caps lock" ident:@"isim-kb-capslock" special:!_caps action:@selector(_capsLock)];
        if (_caps) caps.backgroundColor = dyn(1, 0.42);
        caps.tag = 112;
    }
    /* the bottom row */
    for (int side = 0; side < 2; side++) {
        UIButton *mode = [self _key:letters ? @".?123" : @"ABC" ident:[NSString stringWithFormat:@"isim-kb-%@%@", letters ? @"123" : @"abc", side ? @"-right" : @""]
                            special:YES action:@selector(_mode:)];
        mode.tag = side ? 108 : 102;
    }
    if (_showGlobe) {
        UIButton *g = [self _key:@"" ident:_emojiKey ? @"isim-kb-emoji" : @"isim-kb-globe" special:YES action:@selector(_globe)];
        [g setImage:[UIImage systemImageNamed:_emojiKey ? @"face.smiling" : @"globe" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]] forState:UIControlStateNormal];
        g.tag = 103;
    }
    if (pref_on(@"KeyboardDictation")) {
        UIButton *mic = [self _key:@"" ident:@"isim-kb-dictation" special:YES action:@selector(_dictation)];
        mic.tag = 109;
        [self _styleMic:mic on:_dictatingKey];
    }
    UIButton *space = [self _key:@"" ident:@"isim-kb-space" special:NO action:@selector(_space)];      /* iPadOS: no title */
    space.tag = 104;
    UIKeyboardType kt = [self _kbType];                          /* the "." is on the third row already */
    NSArray *extras = !letters ? nil : kt == UIKeyboardTypeEmailAddress ? @[@"@"] : kt == UIKeyboardTypeURL ? @[@"/", @".com"]
                    : kt == UIKeyboardTypeTwitter ? @[@"@", @"#"] : nil;
    if (kt == UIKeyboardTypeURL && letters) [space removeFromSuperview], [_keys removeObject:space];
    for (NSString *e in extras) {
        UIButton *b = [self _key:e ident:[@"isim-kb-" stringByAppendingString:[e isEqualToString:@".com"] ? @"dotcom" : e] special:NO action:@selector(_char:)];
        b.tag = 106;
    }
    UIButton *hide = [self _key:@"" ident:@"isim-kb-dismiss" special:YES action:@selector(_dismiss)];
    [hide setImage:[UIImage systemImageNamed:@"keyboard.chevron.compact.down" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]] forState:UIControlStateNormal];
    hide.tag = 110;
    [self _updateSuggestions];
    [self setNeedsLayout];
    if (self.bounds.size.width > 0) [self layoutSubviews];
    isim_ui_set_needs_display();
}
- (void)_styleMic:(UIButton *)mic on:(BOOL)on {
    [mic setImage:[UIImage systemImageNamed:on ? @"mic.fill" : @"mic" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20]] forState:UIControlStateNormal];
    mic.tintColor = on ? UIColor.systemBlueColor : UIColor.labelColor;
    mic.accessibilityLabel = on ? @"Stop Dictation" : @"Dictate";
}
- (void)_setDictating:(BOOL)on {
    _dictatingKey = on;
    for (UIButton *b in _keys) if (b.tag == 109) [self _styleMic:b on:on];
    isim_ui_set_needs_display();
}
- (void)_dictation { if (_onDictation) _onDictation(); }
- (CGRect)_spaceFrameIn:(UIView *)v {
    for (UIButton *b in _keys) if (b.tag == 104 && b.superview) return CGRectInset([self convertRect:b.frame toView:v], 2, 2);
    return CGRectZero;
}
- (void)_dismiss { NSLog(@"isim: hide keyboard key"); if (_onDismiss) _onDismiss(); }
- (void)_tab { [self _type:@"\t"]; }
- (void)_capsLock { _caps = !_caps; _shift = NO; NSLog(@"isim: caps lock %@", _caps ? @"on" : @"off"); [self _rebuild]; }
- (void)_layoutIPad {
    struct ipad_metrics m = ipad_metrics(_language);
    BOOL ext = ipad_extended(_layer, _language);
    int nrows = ext ? 5 : 4;
    CGFloat W = self.bounds.size.width, top = m.top + [self _top], g = m.gap, side = m.side, IW = W - 2 * side;
    CGFloat keyH = floor((m.height - 2 * m.top - (nrows - 1) * m.vgap) / nrows);
    NSMutableArray *rk[4] = { [NSMutableArray array], [NSMutableArray array], [NSMutableArray array], [NSMutableArray array] };
    for (UIButton *b in _keys) if (b.tag >= 0 && b.tag < 4) [rk[b.tag] addObject:b];
    NSUInteger n1 = MAX((NSUInteger)1, [rk[0] count]), n2 = [rk[1] count], n3 = [rk[2] count];
    CGFloat u = (IW - n1 * g) / (n1 + 1.5);                      /* a letter key; delete is 1.5 keys wide */
    UIFont *letterFont = [UIFont systemFontOfSize:round(keyH * 0.42)], *specialFont = [UIFont systemFontOfSize:round(keyH * 0.31)];
    UIFont *flickFont = [UIFont systemFontOfSize:round(keyH * 0.26)], *glyphFont = [UIFont systemFontOfSize:round(keyH * 0.4)];
    CGFloat y[5]; for (int r = 0; r < nrows; r++) y[r] = top + r * (keyH + m.vgap);
    CGFloat right = W - side;
    void (^place)(UIButton *, CGFloat, CGFloat, CGFloat) = ^(UIButton *b, CGFloat x, CGFloat yy, CGFloat w) {
        b.frame = CGRectMake(round(x), yy, round(x + w) - round(x), keyH);
        b.layer.cornerRadius = 6;
        UILabel *l = (UILabel *)[b viewWithTag:98];
        b.titleLabel.font = b.tag < 4 || b.tag == 106 ? ([b.currentTitle length] > 1 ? specialFont : letterFont) : specialFont;
        if (b.tag == 101 || ((b.tag == 100 || b.tag == 107) && b.currentTitle.length == 1)) b.titleLabel.font = glyphFont;   /* ⌫ ⇧ */
        if (l) {                                                  /* the flick character above, the key's own below */
            l.font = flickFont;
            l.frame = CGRectMake(0, keyH * 0.1, b.frame.size.width, keyH * 0.32);
            b.contentEdgeInsets = UIEdgeInsetsMake(keyH * 0.34, 0, 0, 0);
            b.titleLabel.font = [UIFont systemFontOfSize:round(keyH * 0.36)];
        }
    };
    CGFloat modeW = u * 1.6, smallW = u, hideW, yb = y[nrows - 1];
    CGFloat x4 = side, r4 = right;
    if (ext) {
        /* the number row and delete; tab, the q row and [ ] \; caps lock, the a row, ; ' and return; shift, the z row,
           , . / and shift: the specials share what the keys leave (caps lock about 1.6 keys) */
        CGFloat x = side;
        for (UIButton *b in rk[0]) { place(b, x, y[0], u); x += u + g; }
        CGFloat tabW = IW - [rk[1] count] * (u + g), capsW = round(u * 1.6);
        CGFloat x1 = side + tabW + g;
        for (UIButton *b in rk[1]) { place(b, x1, y[1], u); x1 += u + g; }
        CGFloat x2 = side + capsW + g;
        for (UIButton *b in rk[2]) { place(b, x2, y[2], u); x2 += u + g; }
        CGFloat shiftW = (IW - [rk[3] count] * u - ([rk[3] count] + 1) * g) / 2, x3 = side + shiftW + g;
        for (UIButton *b in rk[3]) { place(b, x3, y[3], u); x3 += u + g; }
        hideW = round(u * 1.5);
        for (UIButton *b in _keys) {
            switch (b.tag) {
            case 101: place(b, x, y[0], right - x); break;
            case 111: place(b, side, y[1], tabW); break;
            case 112: place(b, side, y[2], capsW); break;
            case 105: place(b, x2, y[2], right - x2); break;
            case 100: place(b, side, y[3], shiftW); break;
            case 107: place(b, right - shiftW, y[3], shiftW); break;
            case 110: place(b, right - hideW, yb, hideW); r4 = right - hideW - g; break;
            default: break;
            }
        }
        for (UIButton *b in _keys) if (b.tag == 103) { place(b, x4, yb, modeW); x4 += modeW + g; }   /* globe first */
    } else {
        /* row 1: the letters, delete to the right edge */
        CGFloat x = side;
        for (UIButton *b in rk[0]) { place(b, x, y[0], u); x += u + g; }
        /* row 2: indented by half a key per key fewer than row 1, return to the right edge */
        CGFloat x2 = side + (n1 > n2 ? (n1 - n2) * 0.5 * u : 0);
        for (UIButton *b in rk[1]) { place(b, x2, y[1], u); x2 += u + g; }
        /* row 3: shift, the letters and , . , shift: both shifts share what is left */
        CGFloat shiftW = (IW - n3 * u - (n3 + 1) * g) / 2, x3 = side + shiftW + g;
        for (UIButton *b in rk[2]) { place(b, x3, y[2], u); x3 += u + g; }
        hideW = shiftW;
        for (UIButton *b in _keys) {
            switch (b.tag) {
            case 100: place(b, side, y[2], shiftW); break;
            case 107: place(b, right - shiftW, y[2], shiftW); break;
            case 101: place(b, x, y[0], right - x); break;
            case 105: place(b, x2, y[1], right - x2); break;
            case 110: place(b, right - hideW, yb, hideW); r4 = right - hideW - g; break;
            default: break;
            }
        }
    }
    /* the bottom row: .?123, globe / emoji (first on the extended layout), mic, space (and the keyboard type's keys),
       .?123, hide keyboard */
    for (UIButton *b in _keys) if (b.tag == 108) { place(b, r4 - modeW, yb, modeW); r4 -= modeW + g; }
    for (UIButton *b in _keys) if (b.tag == 102) { place(b, x4, yb, modeW); x4 += modeW + g; }
    if (!ext) for (UIButton *b in _keys) if (b.tag == 103) { place(b, x4, yb, smallW); x4 += smallW + g; }
    for (UIButton *b in _keys) if (b.tag == 109) { place(b, x4, yb, smallW); x4 += smallW + g; }
    NSMutableArray *ex = [NSMutableArray array]; UIButton *spaceKey = nil;
    for (UIButton *b in _keys) { if (b.tag == 106) [ex addObject:b]; if (b.tag == 104) spaceKey = b; }
    CGFloat exW = 0;
    for (UIButton *b in ex) exW += ([b.currentTitle isEqualToString:@".com"] ? round(u * 1.5) : round(u)) + g;
    if (!spaceKey && ex.count) {
        CGFloat each = (r4 - x4 + g - ex.count * g) / ex.count;
        for (UIButton *b in ex) { place(b, x4, yb, each); x4 += each + g; }
    } else {
        CGFloat sw = r4 - x4 - exW;
        if (spaceKey) place(spaceKey, x4, yb, sw);
        x4 += sw + g;
        for (UIButton *b in ex) { CGFloat w = [b.currentTitle isEqualToString:@".com"] ? round(u * 1.5) : round(u); place(b, x4, yb, w); x4 += w + g; }
    }
}
- (void)_padSymbols { _layer = _layer == L_SYMBOLS ? L_NUMBERS : L_SYMBOLS; [self _rebuild]; }
- (void)_layoutPad {
    CGFloat W = self.bounds.size.width, side = 6, gap = 6, top = 6 + [self _top], keyH = 46;
    CGFloat kw = floor((W - 2 * side - 2 * gap) / 3);
    NSUInteger i = 0;
    for (UIButton *b in _keys) {
        if (b.tag != 400) continue;
        b.frame = CGRectMake(side + (i % 3) * (kw + gap), top + (i / 3) * (keyH + gap), kw, keyH);
        UILabel *l = (UILabel *)[b viewWithTag:99];
        if (l) { b.contentEdgeInsets = UIEdgeInsetsMake(0, 0, 12, 0); l.frame = CGRectMake(0, keyH - 17, kw, 12); }
        i++;
    }
    CGFloat y = top + 3 * (keyH + gap);
    for (UIButton *b in _keys) {
        if (b.tag == 401) b.frame = CGRectMake(side, y, kw, keyH);
        if (b.tag == 402) b.frame = CGRectMake(side + kw + gap, y, kw, keyH);
        if (b.tag == 403) b.frame = CGRectMake(side + 2 * (kw + gap), y, kw, keyH);
    }
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
    if (kb_ipad() && ![self _emoji]) { [self _layoutIPad]; return; }
    if ([self _pad]) { [self _layoutPad]; return; }
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
    /* space, then the keyboard type's keys (".com" wider), between the left keys and return */
    NSMutableArray *ex = [NSMutableArray array]; UIButton *spaceKey = nil;
    for (UIButton *b in _keys) { if (b.tag == 106) [ex addObject:b]; if (b.tag == 104) spaceKey = b; }
    CGFloat avail = W - side - retW - gap - x, exW = 0;
    for (UIButton *b in ex) exW += ([b.currentTitle isEqualToString:@".com"] ? round(base * 1.6) : round(base)) + gap;
    if (!spaceKey && ex.count) {                       /* URL: the keys share the row */
        CGFloat each = (avail - (ex.count - 1) * gap) / ex.count;
        for (UIButton *b in ex) { b.frame = CGRectMake(x, y4, each, keyH); x += each + gap; }
    } else {
        spaceKey.frame = CGRectMake(x, y4, avail - exW, keyH); x += avail - exW + gap;
        for (UIButton *b in ex) { CGFloat w = [b.currentTitle isEqualToString:@".com"] ? round(base * 1.6) : round(base); b.frame = CGRectMake(x, y4, w, keyH); x += w + gap; }
    }
    for (UIButton *b in _keys) if (b.tag == 105) b.frame = CGRectMake(W - side - retW, y4, retW, keyH);
}
- (void)setTarget:(id<UIKeyInput>)t {
    _target = t; _caps = NO;
    UIKeyboardType k = [self _kbType];
    _layer = k == UIKeyboardTypeNumbersAndPunctuation || k == UIKeyboardTypePhonePad || [self _pad] || [self _numberType] ? L_NUMBERS : L_LETTERS;
    [self _updateAutoShift]; [self _rebuild];
}
- (void)setShowGlobe:(BOOL)g { if (g == _showGlobe) return; _showGlobe = g; [self _rebuild]; }
- (void)setEmojiKey:(BOOL)e { if (e == _emojiKey) return; _emojiKey = e; if (kb_ipad()) [self _rebuild]; }
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
    [self _clearInline];
    _autofill = [self _autofillSuggestions];
    BOOL show = self.showsPredictions;
    _bar.hidden = !show;
    if (!show) { _suggestions = @[]; return; }
    if (_autofill.count) { _suggestions = @[]; [self _layoutBar]; return; }
    NSString *math = [self _mathResult];
    if (math) { _suggestions = @[ math ]; [self _layoutBar]; NSLog(@"isim: math completion %@", math); return; }
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
        if (!guesses.count && comps.count && ![chk _isim_known:word language:_language]) [self _showInline:comps[0] after:word];   /* a partial word */
    }
    _suggestions = s;
    [self _layoutBar];
}
/* ---- math expression completion (iOS 18): "12*3=" offers 36 ---- */
static double math_expr(const char **p, BOOL *ok);
static void math_ws(const char **p) { while (**p == ' ') (*p)++; }
static double math_atom(const char **p, BOOL *ok) {
    math_ws(p);
    if (**p == '(') { (*p)++; double v = math_expr(p, ok); math_ws(p); if (**p == ')') (*p)++; else *ok = NO; return v; }
    if (**p == '-') { (*p)++; return -math_atom(p, ok); }
    char *end; double v = strtod(*p, &end);
    if (end == *p) { *ok = NO; return 0; }
    *p = end; return v;
}
static double math_term(const char **p, BOOL *ok) {
    double v = math_atom(p, ok);
    for (;;) {
        math_ws(p);
        if (**p == '*' || **p == 'x') { (*p)++; v *= math_atom(p, ok); }
        else if (**p == '/') { (*p)++; double d = math_atom(p, ok); if (d == 0) *ok = NO; else v /= d; }
        else return v;
    }
}
static double math_expr(const char **p, BOOL *ok) {
    double v = math_term(p, ok);
    for (;;) {
        math_ws(p);
        if (**p == '+') { (*p)++; v += math_term(p, ok); }
        else if (**p == '-') { (*p)++; v -= math_term(p, ok); }
        else return v;
    }
}
- (NSString *)_mathResult {
    id t = self.target;
    if (![t respondsToSelector:@selector(mathExpressionCompletionType)] || [t mathExpressionCompletionType] != UITextMathExpressionCompletionTypeYes) return nil;
    NSString *before = [self _textBeforeCaret];
    if (![before hasSuffix:@"="]) return nil;
    NSString *line = [[before substringToIndex:before.length - 1] componentsSeparatedByString:@"\n"].lastObject;
    NSUInteger start = line.length;                    /* the expression: the trailing run of digits, operators and parentheses */
    NSCharacterSet *ok = [NSCharacterSet characterSetWithCharactersInString:@"0123456789.+-*/x×÷() "];
    while (start > 0 && [ok characterIsMember:[line characterAtIndex:start - 1]]) start--;
    NSString *expr = [[[line substringFromIndex:start] stringByReplacingOccurrencesOfString:@"×" withString:@"*"] stringByReplacingOccurrencesOfString:@"÷" withString:@"/"];
    if ([expr rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"+-*/x"]].location == NSNotFound) return nil;
    const char *c = expr.UTF8String; BOOL good = YES;
    double v = math_expr(&c, &good); math_ws(&c);
    if (!good || *c || !isfinite(v)) return nil;
    NSString *r = [NSString stringWithFormat:@"%.10g", v];
    return r;
}
/* ---- inline predictions (iOS 17): the likeliest completion in grey after the caret; space accepts it ---- */
- (BOOL)_inlineEnabled {
    id t = _target;
    if (!pref_on(@"KeyboardInlinePrediction") || ![t isKindOfClass:[UIView class]] || ![t conformsToProtocol:@protocol(IsimEditableText)]) return NO;
    if ([t respondsToSelector:@selector(inlinePredictionType)] && [(id<UITextInputTraits>)t inlinePredictionType] == UITextInlinePredictionTypeNo) return NO;
    if ([t respondsToSelector:@selector(autocorrectionType)] && [(id<UITextInputTraits>)t autocorrectionType] == UITextAutocorrectionTypeNo &&
        !([t respondsToSelector:@selector(inlinePredictionType)] && [(id<UITextInputTraits>)t inlinePredictionType] == UITextInlinePredictionTypeYes)) return NO;
    return isim_os_version() >= 170000;
}
- (void)_showInline:(NSString *)completion after:(NSString *)word {
    if (word.length < 2 || completion.length <= word.length || ![self _inlineEnabled]) return;
    UIView<IsimEditableText> *t = (UIView<IsimEditableText> *)_target;
    NSString *text = [t _isim_plainText];
    NSRange sel = [t _isim_selectedRange];
    if (sel.length || isim_ui_marked_range(t).location != NSNotFound) return;
    if (NSMaxRange(sel) < text.length && [NSCharacterSet.letterCharacterSet characterIsMember:[text characterAtIndex:NSMaxRange(sel)]]) return;
    _inline = [completion substringFromIndex:word.length];
    CGRect c = [t _isim_caretRectForIndex:sel.location];
    UIFont *font = [t respondsToSelector:@selector(font)] ? [(id)t font] : nil;
    _ghost = [UILabel new];
    _ghost.text = _inline;
    _ghost.font = font ?: [UIFont systemFontOfSize:17];
    _ghost.textColor = UIColor.tertiaryLabelColor;
    _ghost.accessibilityIdentifier = @"isim-inline-prediction";
    [_ghost sizeToFit];
    _ghost.frame = CGRectMake(CGRectGetMaxX(c) - 1, CGRectGetMidY(c) - _ghost.bounds.size.height / 2, _ghost.bounds.size.width, _ghost.bounds.size.height);
    [t addSubview:_ghost];
}
- (void)_clearInline { [_ghost removeFromSuperview]; _ghost = nil; _inline = nil; }
- (BOOL)_acceptInline {
    if (!_inline.length) return NO;
    NSString *rest = _inline, *word = nil;
    [self _currentWord:&word];
    [self _clearInline];
    [_target insertText:rest];
    NSLog(@"isim: inline prediction accepted \"%@%@\"", word ?: @"", rest);
    return YES;
}
- (void)_layoutBar {
    for (UIView *v in _bar.subviews) [v removeFromSuperview];
    if (_bar.hidden) return;
    CGFloat W = self.bounds.size.width, w = W / 3;
    if (_autofill.count) {                          /* AutoFill: passwords, a strong password, a one-time code */
        CGFloat aw = W / _autofill.count;
        for (NSUInteger i = 0; i < _autofill.count; i++) {
            __IsimAutoFillSuggestion *a = _autofill[i];
            UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
            [b setTitle:a.subtitle.length ? [NSString stringWithFormat:@"%@\n%@", a.title, a.subtitle] : a.title forState:UIControlStateNormal];
            [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
            b.titleLabel.numberOfLines = 2;
            b.titleLabel.textAlignment = NSTextAlignmentCenter;
            b.titleLabel.font = [UIFont systemFontOfSize:a.subtitle.length ? 14 : 16];
            if (a.symbol) { [b setImage:[UIImage systemImageNamed:a.symbol withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:14]] forState:UIControlStateNormal]; b.tintColor = UIColor.secondaryLabelColor; }
            b.frame = CGRectMake(i * aw, 2, aw, 40);
            b.tag = (NSInteger)i;
            b.accessibilityIdentifier = [NSString stringWithFormat:@"isim-kb-autofill-%lu", (unsigned long)i];
            b.accessibilityLabel = a.title;
            [b addTarget:self action:@selector(_pickAutoFill:) forControlEvents:UIControlEventTouchUpInside];
            [_bar addSubview:b];
            if (i) { UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(i * aw, 12, 1, 20)]; sep.backgroundColor = UIColor.separatorColor; [_bar addSubview:sep]; }
        }
        return;
    }
    /* iPad: the responder's input assistant item puts its bar button groups at the ends (the shortcuts bar) */
    CGFloat x0 = 0;
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && [(id)self.target isKindOfClass:[UIResponder class]]) {
        UITextInputAssistantItem *ai = [(UIResponder *)self.target inputAssistantItem];
        CGFloat lead = [self _placeGroups:ai.leadingBarButtonGroups from:8 leading:YES], trail = [self _placeGroups:ai.trailingBarButtonGroups from:W - 8 leading:NO];
        x0 = lead; W -= lead + trail; w = W / 3;
    }
    for (NSUInteger i = 0; i < 3; i++) {
        NSString *t = i < _suggestions.count ? _suggestions[i] : @"";
        UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
        [b setTitle:t forState:UIControlStateNormal];
        [b setTitleColor:UIColor.labelColor forState:UIControlStateNormal];
        b.titleLabel.font = [UIFont systemFontOfSize:17];
        b.frame = CGRectMake(x0 + i * w, 2, w, 40);
        b.tag = (NSInteger)i;
        b.accessibilityIdentifier = [NSString stringWithFormat:@"isim-kb-suggestion-%lu", (unsigned long)i];
        [b addTarget:self action:@selector(_pickSuggestion:) forControlEvents:UIControlEventTouchUpInside];
        [_bar addSubview:b];
        if (i) { UIView *sep = [[UIView alloc] initWithFrame:CGRectMake(x0 + i * w, 12, 1, 20)]; sep.backgroundColor = UIColor.separatorColor; [_bar addSubview:sep]; }
    }
}
/* bar button groups as 44 pt buttons from an edge; returns the width they take */
- (CGFloat)_placeGroups:(NSArray<UIBarButtonItemGroup *> *)groups from:(CGFloat)edge leading:(BOOL)leading {
    NSMutableArray<UIBarButtonItem *> *items = [NSMutableArray array];
    for (UIBarButtonItemGroup *g in groups) if (!g.hidden) [items addObjectsFromArray:g.barButtonItems];
    if (!leading) items = [[[items reverseObjectEnumerator] allObjects] mutableCopy];
    CGFloat x = edge;
    for (UIBarButtonItem *it in items) {
        UIButton *b = [UIButton buttonWithType:UIButtonTypeSystem];
        if (it.image) [b setImage:it.image forState:UIControlStateNormal]; else [b setTitle:it.title forState:UIControlStateNormal];
        b.tintColor = UIColor.labelColor;
        CGFloat bw = it.image ? 44 : fmax(44, [b sizeThatFits:CGSizeMake(200, 40)].width + 12);
        b.frame = CGRectMake(leading ? x : x - bw, 2, bw, 40);
        x = leading ? x + bw : x - bw;
        b.accessibilityIdentifier = [@"isim-kb-assistant-" stringByAppendingString:it.accessibilityIdentifier ?: it.title ?: @"item"];
        b.enabled = it.enabled;
        __weak UIBarButtonItem *wi = it;
        [b addAction:[UIAction actionWithHandler:^(UIAction *a) {
            UIBarButtonItem *i = wi; if (!i) return;
            NSLog(@"isim: shortcuts bar item %@", i.title ?: i.accessibilityIdentifier ?: @"");
            if (i.primaryAction) [i.primaryAction performWithSender:i target:nil];
            else if (i.action) [UIApplication.sharedApplication sendAction:i.action to:i.target from:i forEvent:nil];
        }] forControlEvents:UIControlEventTouchUpInside];
        [_bar addSubview:b];
    }
    return fabs(x - edge) + (items.count ? 8 : 0);
}
- (void)_pickAutoFill:(UIButton *)b {
    if ((NSUInteger)b.tag >= _autofill.count) return;
    __IsimAutoFillSuggestion *a = _autofill[(NSUInteger)b.tag];
    NSLog(@"isim: AutoFill suggestion \"%@\" picked", a.title);
    a.action();
    [self _updateSuggestions];
    isim_ui_keyboard_suggestions_changed();
}
- (void)_pickSuggestion:(UIButton *)b {
    if ((NSUInteger)b.tag >= _suggestions.count) return;
    NSString *s = _suggestions[(NSUInteger)b.tag], *word = nil;
    NSRange r = [self _currentWord:&word];
    id t = _target;
    if ([s isEqualToString:[self _mathResult] ?: @""]) {      /* a math result goes after the = as it is */
        NSLog(@"isim: math result \"%@\" inserted", s);
        [t insertText:s];
        [self _updateSuggestions];
        return;
    }
    if ([s hasPrefix:@"“"]) {                       /* keeping what was typed: the keyboard learns the word */
        s = word;
        if (word.length > 1 && ![UITextChecker hasLearnedWord:word]) { [UITextChecker learnWord:word]; NSLog(@"isim: learned the word \"%@\"", word); }
    }
    NSLog(@"isim: suggestion \"%@\" picked", s);
    if (word.length && [t conformsToProtocol:@protocol(UITextInput)]) {
        id<UITextInput> ti = t;
        UITextPosition *a = [ti positionFromPosition:ti.beginningOfDocument offset:(NSInteger)r.location], *e = [ti positionFromPosition:a offset:(NSInteger)r.length];
        if (a && e) [ti replaceRange:[ti textRangeFromPosition:a toPosition:e] withText:s];
    } else [t insertText:s];
    [self _clearInline];
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
    if ([s isEqualToString:@" "] && [self _acceptInline]) ac = NO;
    if (ac && [@" .,!?;:\n" containsString:s]) {
        extern void isim_text_checker_note_word(NSString *);
        NSString *word = nil; [self _currentWord:&word];
        if (word.length > 1) isim_text_checker_note_word(word);
    }
    if (ac) [self _autocorrectBefore:s];
    [_target insertText:s];
    BOOL was = _shift;
    [self _updateAutoShift];
    if (was != _shift && _layer == L_LETTERS) [self _rebuild]; else [self _updateSuggestions];
}
- (void)_char:(UIButton *)b {
    if (_suppressTap) { _suppressTap = NO; return; }
    [_popup removeFromSuperview]; _popup = nil;
    if ([b isKindOfClass:[__IsimFlickKey class]] && ((__IsimFlickKey *)b).flicked) {
        NSLog(@"isim: flick key %@: %@", b.currentTitle, ((__IsimFlickKey *)b).flick);
        [self _type:((__IsimFlickKey *)b).flick];
        return;
    }
    if (_shift && ipad_extended(_layer, _language) && [b isKindOfClass:[__IsimFlickKey class]]) {   /* shift + 1: ! */
        [self _type:((__IsimFlickKey *)b).flick];
        return;
    }
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
    /* back to letters after a space, except on the numbers and punctuation keyboard */
    if (_layer != L_LETTERS && [self _kbType] != UIKeyboardTypeNumbersAndPunctuation && ![self _numberType]) { _layer = L_LETTERS; [self _updateAutoShift]; [self _rebuild]; }
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
    UIView *_inputOverride, *_accessory;   /* the responder's inputView (instead of the keys) and inputAccessoryView (above) */
    BOOL _dictating; UIView *_listening;
}
+ (instancetype)shared { static __IsimKeyboardController *c; if (!c) c = [self new]; return c; }
+ (void)load_isim {
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimFirstResponderDidChange" object:nil queue:nil usingBlock:^(NSNotification *n) {
        [[__IsimKeyboardController shared] _responderChanged:n.object];
    }];
    [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimSettingsChanged" object:nil queue:nil usingBlock:^(NSNotification *n) {
        [[__IsimKeyboardController shared] _settingsChanged];
    }];
    /* the device turned: the keyboard takes the new screen width and height (its window is not full screen, so the
       rotation does not resize it), and apps hear the frame change */
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"   /* still sent after every rotation (UIOrientation.m) */
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidChangeStatusBarOrientationNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        __IsimKeyboardController *c = [__IsimKeyboardController shared];
        if (c->_shown) { [c _relayout]; [c->_keys setNeedsLayout]; }
    }];
#pragma clang diagnostic pop
}
/* the bar under the keys with the globe and the mic: Face ID iPhones (iPads have both keys in the bottom row) */
- (BOOL)_barVisible { return isim_ui_device()->safe_bottom > 0 && !_inputOverride && !kb_ipad(); }
- (CGFloat)_accessoryHeight {
    if (!_accessory) return 0;
    CGFloat h = _accessory.frame.size.height;
    if (h <= 0) h = _accessory.intrinsicContentSize.height;
    return h > 0 ? h : 44;
}
- (void)_setAccessory:(UIView *)acc {
    if (acc == _accessory) return;
    [_accessory removeFromSuperview];
    _accessory = acc;
    if (acc) [_window addSubview:acc];
}
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
    _keys.onDictation = ^{ [w _dictation]; };
    _keys.onDismiss = ^{ [w _dismissKey]; };
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
    _barGlobe.hidden = [_keys _pad];                   /* number / phone pads: no keyboard switching, as on iOS */
}
- (void)_barTapped { [self _next]; }
/* iPad: the hide-keyboard key ends editing (the responder resigns, as when iPadOS hides the keyboard) */
- (void)_dismissKey {
    id t = _target;
    if ([t isKindOfClass:[UIResponder class]] && [(UIResponder *)t isFirstResponder]) [(UIResponder *)t resignFirstResponder];
    else [self _hide];
}
/* dictation (adapted): the mic key starts and stops listening; what is "said" comes from `dictate TEXT` (UITextServices.m) */
- (void)_dictation {
    if (!pref_on(@"KeyboardDictation")) { NSLog(@"isim: dictation is off (Settings > General > Keyboard > Enable Dictation)"); return; }
    [self _setDictating:!_dictating];
}
- (BOOL)_dictating { return _dictating; }
- (void)_setDictating:(BOOL)on {
    if (on == _dictating || (on && !_shown)) return;
    _dictating = on;
    UIButton *mic = nil;
    for (UIView *b in _bar.subviews) if (b.tag == 77) mic = (UIButton *)b;
    [mic setImage:[UIImage systemImageNamed:on ? @"mic.fill" : @"mic" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:22]] forState:UIControlStateNormal];
    mic.tintColor = on ? UIColor.systemBlueColor : UIColor.secondaryLabelColor;
    mic.accessibilityLabel = on ? @"Stop Dictation" : @"Dictate";
    [_keys _setDictating:on];                                  /* iPad: the mic key of the bottom row */
    [_listening removeFromSuperview]; _listening = nil;
    if (on) {
        UILabel *l = [UILabel new];
        l.text = @"Listening…";
        l.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        l.textColor = UIColor.systemBlueColor;
        l.textAlignment = NSTextAlignmentCenter;
        l.accessibilityIdentifier = @"isim-dictation-listening";
        _listening = l;
        if (kb_ipad()) {                                        /* no bar on iPad: over the space bar (adapted) */
            l.backgroundColor = kb_background();
            [_window addSubview:l];
        } else [_bar addSubview:l];
    }
    [self _relayout];
    [NSNotificationCenter.defaultCenter postNotificationName:UITextInputCurrentInputModeDidChangeNotification object:nil];
    NSLog(@"isim: dictation %@", on ? @"started (listening)" : @"stopped");
}
- (id)_shownTarget { return _shown ? _target : nil; }
- (void)_responderCheck { id fr = isim_ui_first_responder(); if (fr && (!_shown || _target != fr)) [self _responderChanged:fr]; }
- (void)_leaveEmoji {
    NSInteger back = _lastLetters >= 0 && _lastLetters < (NSInteger)_order.count && ![_order[(NSUInteger)_lastLetters] isEqualToString:@"emoji"] ? _lastLetters : 0;
    [self _switchTo:back];
}
- (CGFloat)_contentHeight {
    if (_inputOverride) {                         /* a custom input view: its height, over the home indicator area */
        CGFloat h = _inputOverride.frame.size.height;
        if (h <= 0) h = _inputOverride.intrinsicContentSize.height;
        return (h > 0 ? h : 216) + isim_ui_device()->safe_bottom;
    }
    if (kb_ipad() && (is_system([self _ident]) || !_hostedView))      /* the keys, over the home indicator's band */
        return ipad_metrics([self _language]).height + ([_keys showsPredictions] ? 44 : 0) + isim_ui_device()->safe_bottom;
    if (is_system([self _ident]) || !_hostedView) return 216 + ([_keys showsPredictions] ? 44 : 0);
    UIView *v = _hostedView;
    CGFloat W = isim_ui_device()->width;
    CGSize s = [v systemLayoutSizeFittingSize:CGSizeMake(W, 216) withHorizontalFittingPriority:UILayoutPriorityRequired verticalFittingPriority:UILayoutPriorityFittingSizeLevel];
    return s.height > 20 ? s.height : 216;
}
- (void)_relayout {
    const struct isim_device *d = isim_ui_device();
    CGFloat contentH = [self _contentHeight], barH = [self _barVisible] ? 45 + d->safe_bottom : 0, accH = [self _accessoryHeight];
    CGFloat H = accH + contentH + barH;
    CGRect old = keyboard_frame;
    CGRect f = CGRectMake(0, d->height - H, d->width, H);
    _window.frame = f;
    _accessory.frame = CGRectMake(0, 0, d->width, accH);
    _content.frame = CGRectMake(0, accH, d->width, contentH);
    _inputOverride.frame = CGRectMake(0, 0, d->width, contentH);
    _bar.frame = CGRectMake(0, accH + contentH, d->width, barH);
    _bar.hidden = barH == 0;
    for (UIView *b in _bar.subviews) if (b.tag == 77) { b.frame = CGRectMake(d->width - 56, 2, 44, 40); b.hidden = !pref_on(@"KeyboardDictation"); }
    _listening.frame = kb_ipad() ? [_keys _spaceFrameIn:_window] : CGRectMake(70, 2, d->width - 140, 40);
    if (_hostedView) _hostedView.frame = _content.bounds;
    CGRect kf = _content.bounds;
    if (kb_ipad() && !_hostedView) kf.size.height = MAX(0, kf.size.height - d->safe_bottom);   /* keys above the home indicator */
    _keys.frame = kf;
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
    /* a responder's inputView replaces the keyboard (any responder may have one); inputAccessoryView sits above */
    UIView *custom = [responder isKindOfClass:[UIResponder class]] && [responder respondsToSelector:@selector(inputView)] ? [responder inputView] : nil;
    UIView *acc = [responder isKindOfClass:[UIResponder class]] && [responder respondsToSelector:@selector(inputAccessoryView)] ? [responder inputAccessoryView] : nil;
    /* else their controllers' (inputViewController, inputAccessoryViewController) */
    if (!custom && [responder isKindOfClass:[UIResponder class]]) { UIInputViewController *c = [responder inputViewController]; custom = c ? (c.inputView ?: c.view) : nil; }
    if (!acc && [responder isKindOfClass:[UIResponder class]]) { UIInputViewController *c = [responder inputAccessoryViewController]; acc = c ? (c.inputView ?: c.view) : nil; }
    if (custom) { [self _showCustom:custom accessory:acc for:responder]; return; }
    if (wants && isim_ui_scribble_focusing) {          /* writing with the Pencil: no on-screen keyboard */
        [self _hide];
        _target = responder;
        NSLog(@"isim: Scribble: editing without the on-screen keyboard");
        return;
    }
    if (wants) { [self _build]; [self _setAccessory:acc]; [self _showFor:responder]; } else [self _hide];
}
- (void)_showCustom:(UIView *)custom accessory:(UIView *)acc for:(id)t {
    [self _build];
    _target = t;
    if (_inputOverride != custom) {
        [_inputOverride removeFromSuperview];
        [_hostedView removeFromSuperview]; [_keys removeFromSuperview];
        _inputOverride = custom;
        custom.translatesAutoresizingMaskIntoConstraints = YES;
        [_content addSubview:custom];
    }
    [self _setAccessory:acc];
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
    [self _post:UIKeyboardDidShowNotification from:from to:to];
    [self _post:UIKeyboardDidChangeFrameNotification from:from to:to];
    NSLog(@"isim: input view shown (%@%@)", NSStringFromClass([custom class]), _accessory ? @", with an accessory view" : @"");
}
- (void)_showFor:(id<UIKeyInput>)t {
    [self _build]; [self _discover]; [self _updateBarButton];
    if (_inputOverride) { [_inputOverride removeFromSuperview]; _inputOverride = nil; }     /* back from a custom input view */
    id old = _target;
    if (old != t) { [self _setDictating:NO]; [_keys _clearInline]; }
    _target = t;
    if (old != t && [(id)t isKindOfClass:[UIResponder class]]) {        /* the keyboard last used in this context comes back */
        NSString *k = isim_ui_keyboard_for_context([(UIResponder *)t textInputContextIdentifier]);
        NSUInteger i = k ? [_order indexOfObject:k] : NSNotFound;
        if (i != NSNotFound) _current = (NSInteger)i;
    }
    _keys.showGlobe = ![self _barVisible] && _order.count > 1;
    _keys.emojiKey = kb_ipad() && [self _emojiKeyOnly];
    _keys.target = t;
    [self _updateBarButton];                          /* (after the target: pads hide the globe) */
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
    [self _setDictating:NO];
    [_keys _clearInline];
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
    if (_inputOverride) { [_inputOverride removeFromSuperview]; _inputOverride = nil; }
    [self _setAccessory:nil];
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
    if ([_target isKindOfClass:[UIResponder class]]) isim_ui_keyboard_remember_context([(UIResponder *)_target textInputContextIdentifier], _order[(NSUInteger)idx]);
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
    _menu.layer.cornerRadius = 12; _menu.layer.cornerCurve = kCACornerCurveContinuous;
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
- (void)_assistantChanged { if (_shown && !_hostedView) [_keys _layoutBar]; }
@end

/* custom keyboards ask this through needsInputModeSwitchKey */
BOOL isim_ui_keyboard_needs_switch_key(void) { return isim_ui_device()->safe_bottom <= 0 || kb_ipad(); }
void isim_ui_keyboard_advance(void) { [[__IsimKeyboardController shared] _next]; }
void isim_ui_keyboard_check(void) { [[__IsimKeyboardController shared] _check]; }
void isim_ui_keyboard_install(void) { [__IsimKeyboardController load_isim]; }
NSString *isim_ui_keyboard_current_language(void) { return [[__IsimKeyboardController shared] _language]; }
void isim_ui_keyboard_suggestions_changed(void) { [[__IsimKeyboardController shared] _suggestionsChanged]; }
NSArray<NSString *> *isim_ui_keyboard_enabled(void) { return [[__IsimKeyboardController shared] _activeLanguages]; }
id isim_ui_keyboard_target(void) { return [[__IsimKeyboardController shared] _shownTarget]; }
BOOL isim_ui_keyboard_dictating(void) { return [[__IsimKeyboardController shared] _dictating]; }
void isim_ui_keyboard_set_dictating(BOOL on) { [[__IsimKeyboardController shared] _setDictating:on]; }
void isim_ui_keyboard_assistant_changed(void) { [[__IsimKeyboardController shared] _assistantChanged]; }
void isim_ui_keyboard_reload(id responder) { [[__IsimKeyboardController shared] _responderChanged:responder]; }
void isim_ui_keyboard_responder_check(void) { [[__IsimKeyboardController shared] _responderCheck]; }
