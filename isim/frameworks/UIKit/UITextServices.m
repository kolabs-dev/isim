/* isim text services: textContentType values, Password AutoFill, dictation, Scribble and the detected items of
 * non-editable text views. All of it is adapted: isim has no iCloud Keychain, microphone speech recognition, Apple
 * Pencil or Messages, so their input comes from script commands (runtime/host_input.inc).
 *
 *  - Passwords (adapted): the device's Passwords store is $ISIM_DATA/Library/Passwords/passwords.plist (an array of
 *    { site, user, password, created }; not encrypted, like isim's keychain). An app's site is its first
 *    `webcredentials:` associated domain, else its bundle identifier. Settings > Passwords lists and deletes them.
 *  - AutoFill (adapted): while a field whose textContentType is username / emailAddress / password is edited, the
 *    keyboard's QuickType bar offers the site's saved passwords and the app's own keychain internet passwords; picking
 *    one fills every username and password field of the window. newPassword fields offer "Use Strong Password"
 *    (Apple's format, xxxxxx-xxxxxx-xxxxxx, or the passwordRules' length). When a typed password field leaves the
 *    window (the form was submitted), "Save Password?" asks to keep it. oneTimeCode fields offer the code of a text
 *    message that arrived in the last three minutes (script `sms TEXT`). Settings > Passwords > AutoFill Passwords
 *    turns it off.
 *  - Dictation (adapted): the keyboard's mic key starts listening (the key turns blue, a "Listening" pill shows
 *    above the field); `dictate TEXT` is what was said: spoken punctuation ("period", "comma", "question mark",
 *    "new line", ...) becomes characters, sentences are capitalised, and the result goes through
 *    insertDictationResult: when the input implements it (else insertText:), then dictationRecordingDidEnd.
 *    `dictate fail` calls dictationRecognitionFailed. Settings > General > Keyboard > Enable Dictation.
 *  - Scribble (adapted, iPad): `scribble X Y TEXT` writes TEXT with the Pencil at (X, Y). The ink is drawn, the
 *    field under it is focused without the on-screen keyboard and the text is inserted where it was written.
 *    UIScribbleInteraction's delegate can decline (shouldBeginAtLocation) and sees will-begin / did-finish;
 *    UIIndirectScribbleInteraction's delegate supplies elements, frames and the input to focus.
 *  - Detected items: a non-editable, selectable UITextView with dataDetectorTypes draws links, phone numbers,
 *    addresses and dates in its tint colour, underlined; a tap runs the primary action (delegate
 *    primaryActionForTextItem: / shouldInteractWithURL:, else open the URL: tel:, maps, http, calshow:), a long
 *    press shows the item's menu (delegate menuConfigurationForTextItem:). */
#import "UITextInputImpl.h"
#import <UIKit/UIScribbleInteraction.h>
#import <UIKit/UITextView.h>
#include <math.h>
#include <ctype.h>
#include <sys/stat.h>

@interface UIAction (IsimTextServices)
- (UIActionHandler)handler;
- (void)setSender:(id)sender;
@end
void isim_ui_show_edit_menu(CGRect rect, NSArray<UIMenuElement *> *elements, void (^dismissed)(void));

/* ================= textContentType ================= */
UITextContentType const UITextContentTypeName = @"name", UITextContentTypeNamePrefix = @"honorific-prefix",
    UITextContentTypeGivenName = @"given-name", UITextContentTypeMiddleName = @"additional-name", UITextContentTypeFamilyName = @"family-name",
    UITextContentTypeNameSuffix = @"honorific-suffix", UITextContentTypeNickname = @"nickname", UITextContentTypeJobTitle = @"organization-title",
    UITextContentTypeOrganizationName = @"organization", UITextContentTypeLocation = @"location",
    UITextContentTypeFullStreetAddress = @"street-address", UITextContentTypeStreetAddressLine1 = @"address-line1",
    UITextContentTypeStreetAddressLine2 = @"address-line2", UITextContentTypeAddressCity = @"address-level2",
    UITextContentTypeAddressState = @"address-level1", UITextContentTypeAddressCityAndState = @"address-level1+2",
    UITextContentTypeSublocality = @"address-level3", UITextContentTypeCountryName = @"country-name", UITextContentTypePostalCode = @"postal-code",
    UITextContentTypeTelephoneNumber = @"tel", UITextContentTypeEmailAddress = @"email", UITextContentTypeURL = @"url",
    UITextContentTypeCreditCardNumber = @"cc-number", UITextContentTypeUsername = @"username", UITextContentTypePassword = @"password",
    UITextContentTypeNewPassword = @"new-password", UITextContentTypeOneTimeCode = @"one-time-code",
    UITextContentTypeShipmentTrackingNumber = @"shipment-tracking-number", UITextContentTypeFlightNumber = @"flight-number",
    UITextContentTypeDateTime = @"date-time", UITextContentTypeBirthdate = @"birthdate", UITextContentTypeBirthdateDay = @"birthdate-day",
    UITextContentTypeBirthdateMonth = @"birthdate-month", UITextContentTypeBirthdateYear = @"birthdate-year",
    UITextContentTypeCreditCardSecurityCode = @"cc-csc", UITextContentTypeCreditCardName = @"cc-name",
    UITextContentTypeCreditCardGivenName = @"cc-given-name", UITextContentTypeCreditCardMiddleName = @"cc-additional-name",
    UITextContentTypeCreditCardFamilyName = @"cc-family-name", UITextContentTypeCreditCardExpiration = @"cc-exp",
    UITextContentTypeCreditCardExpirationMonth = @"cc-exp-month", UITextContentTypeCreditCardExpirationYear = @"cc-exp-year",
    UITextContentTypeCreditCardType = @"cc-type", UITextContentTypeCellularEID = @"cellular-eid", UITextContentTypeCellularIMEI = @"cellular-imei";

@implementation UITextInputPasswordRules
+ (instancetype)passwordRulesWithDescriptor:(NSString *)d {
    UITextInputPasswordRules *r = [super new];
    r->_passwordRulesDescriptor = [d copy] ?: @"";
    return r;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_passwordRulesDescriptor forKey:@"descriptor"]; }
- (instancetype)initWithCoder:(NSCoder *)c {
    if ((self = [super init])) _passwordRulesDescriptor = [[c decodeObjectOfClass:[NSString class] forKey:@"descriptor"] copy] ?: @"";
    return self;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UITextInputPasswordRules class]] && [_passwordRulesDescriptor isEqualToString:[o passwordRulesDescriptor]]; }
- (NSUInteger)hash { return _passwordRulesDescriptor.hash; }
@end

@interface UIDictationPhrase ()
- (instancetype)initWithIsimText:(NSString *)t alternatives:(NSArray *)a;
@end
@implementation UIDictationPhrase
- (instancetype)initWithIsimText:(NSString *)t alternatives:(NSArray *)a {
    if ((self = [super init])) { _text = [t copy]; _alternativeInterpretations = [a copy]; }
    return self;
}
@end

static NSDictionary *global_prefs(void) { extern NSDictionary *isim_global_preferences(void); return isim_global_preferences(); }
static BOOL pref_on(NSString *key) { NSNumber *n = global_prefs()[key]; return n ? n.boolValue : YES; }
static NSString *content_type(id v) { return [v respondsToSelector:@selector(textContentType)] ? [(id<UITextInputTraits>)v textContentType] : nil; }
static NSString *data_dir(void) {
    const char *e = getenv("ISIM_DATA");
    return e && *e ? @(e) : [NSHomeDirectory() stringByAppendingPathComponent:@".local/share/isim"];
}
static UIViewController *top_controller(void) {
    UIViewController *top = UIApplication.sharedApplication.keyWindow.rootViewController ?: UIApplication.sharedApplication.windows.firstObject.rootViewController;
    while (top.presentedViewController && !top.presentedViewController.isBeingDismissed) top = top.presentedViewController;
    return top;
}

/* ================= the Passwords store ================= */
static NSString *passwords_path(void) { return [data_dir() stringByAppendingPathComponent:@"Library/Passwords/passwords.plist"]; }
static NSArray<NSDictionary *> *passwords_all(void) {
    NSData *d = [NSData dataWithContentsOfFile:passwords_path()];
    id a = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    return [a isKindOfClass:[NSArray class]] ? a : @[];
}
static void passwords_save(NSString *site, NSString *user, NSString *password) {
    NSMutableArray *a = [passwords_all() mutableCopy];
    for (NSUInteger i = 0; i < a.count; i++)
        if ([a[i][@"site"] isEqualToString:site] && [a[i][@"user"] isEqualToString:user]) { [a removeObjectAtIndex:i]; break; }
    [a addObject:@{ @"site": site, @"user": user, @"password": password, @"created": NSDate.date }];
    [NSFileManager.defaultManager createDirectoryAtPath:passwords_path().stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    [a writeToFile:passwords_path() atomically:YES];
    chmod(passwords_path().UTF8String, 0600);
}
/* the app's sites: `webcredentials:` associated domains, else the bundle identifier */
static NSArray<NSString *> *app_sites(void) {
    static NSArray *sites;
    if (sites) return sites;
    NSMutableArray *out = [NSMutableArray array];
    NSString *path = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"archived-expanded-entitlements.xcent"];
    NSData *d = [NSData dataWithContentsOfFile:path];
    NSDictionary *ent = d ? [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL] : nil;
    id list = [ent isKindOfClass:[NSDictionary class]] ? ent[@"com.apple.developer.associated-domains"] : nil;
    if ([list isKindOfClass:[NSArray class]])
        for (id e in list) if ([e isKindOfClass:[NSString class]] && [e hasPrefix:@"webcredentials:"]) {
            NSString *dom = [e substringFromIndex:15];
            NSRange q = [dom rangeOfString:@"?"];
            [out addObject:(q.location != NSNotFound ? [dom substringToIndex:q.location] : dom).lowercaseString];
        }
    if (!out.count) [out addObject:NSBundle.mainBundle.bundleIdentifier ?: @"isim.app"];
    sites = [out copy];
    return sites;
}
/* the app's own internet passwords (Security's keychain file: JSON, values as Swift Codable enums) */
static NSArray<NSDictionary *> *keychain_passwords(void) {
    NSString *group = NSBundle.mainBundle.bundleIdentifier ?: @"isim.unknown";
    NSString *p = [data_dir() stringByAppendingFormat:@"/Library/Keychains/%@.keychain", [group stringByReplacingOccurrencesOfString:@"/" withString:@"_"]];
    NSData *d = [NSData dataWithContentsOfFile:p];
    NSDictionary *f = d ? [NSJSONSerialization JSONObjectWithData:d options:0 error:NULL] : nil;
    NSMutableArray *out = [NSMutableArray array];
    if (![f isKindOfClass:[NSDictionary class]]) return out;
    for (NSDictionary *it in f[@"items"]) {
        if (![it isKindOfClass:[NSDictionary class]] || ![it[@"cls"] isEqual:@"inet"]) continue;
        NSString *(^str)(NSString *) = ^NSString *(NSString *k) { id v = it[@"attrs"][k][@"string"]; return [v isKindOfClass:[NSDictionary class]] ? v[@"_0"] : nil; };
        NSString *user = str(@"acct"), *server = str(@"srvr");
        NSMutableData *pw = [NSMutableData data];
        for (NSNumber *b in it[@"data"]) { uint8_t c = (uint8_t)b.unsignedIntValue; [pw appendBytes:&c length:1]; }
        NSString *password = [[NSString alloc] initWithData:pw encoding:NSUTF8StringEncoding];
        if (user.length && password.length) [out addObject:@{ @"site": server ?: app_sites()[0], @"user": user, @"password": password }];
    }
    return out;
}
static NSArray<NSDictionary *> *credentials_for_app(void) {
    NSMutableArray *out = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    NSArray *sites = app_sites();
    for (NSDictionary *e in passwords_all().reverseObjectEnumerator)
        if ([sites containsObject:e[@"site"]] && ![seen containsObject:e[@"user"]]) { [seen addObject:e[@"user"]]; [out addObject:e]; }
    for (NSDictionary *e in keychain_passwords())
        if (![seen containsObject:e[@"user"]]) { [seen addObject:e[@"user"]]; [out addObject:e]; }
    return out;
}

/* ================= AutoFill ================= */
static BOOL is_user_type(NSString *t) { return [t isEqualToString:UITextContentTypeUsername] || [t isEqualToString:UITextContentTypeEmailAddress]; }
static BOOL is_password_type(NSString *t) { return [t isEqualToString:UITextContentTypePassword] || [t isEqualToString:UITextContentTypeNewPassword]; }
static void collect_fields(UIView *v, NSMutableArray *out) {
    if (v.hidden) return;
    if ([v conformsToProtocol:@protocol(IsimEditableText)] && content_type(v)) [out addObject:v];
    for (UIView *s in v.subviews) collect_fields(s, out);
}
/* the text fields of the form `near` is in (its window, or the view tree it is leaving the window with) */
static NSArray<UIView<IsimEditableText> *> *form_fields(UIView *near) {
    NSMutableArray *out = [NSMutableArray array];
    UIView *root = near;
    while (root.superview) root = root.superview;
    if (root) collect_fields(root, out);
    return out;
}
static const void *kAutoFilled = &kAutoFilled;
static void fill_field(UIView<IsimEditableText> *f, NSString *text) {
    [f _isim_replaceRange:NSMakeRange(0, [f _isim_plainText].length) withText:text];
    objc_setAssociatedObject(f, kAutoFilled, text, OBJC_ASSOCIATION_COPY_NONATOMIC);
}
static void autofill_credentials(UIView *target, NSDictionary *cred) {
    NSUInteger n = 0;
    for (UIView<IsimEditableText> *f in form_fields(target)) {
        NSString *t = content_type(f);
        if (is_user_type(t)) { fill_field(f, cred[@"user"]); n++; }
        else if ([t isEqualToString:UITextContentTypePassword]) { fill_field(f, cred[@"password"]); n++; }
    }
    NSLog(@"isim: AutoFill: filled %lu field(s) with the password of %@ (%@)", (unsigned long)n, cred[@"user"], cred[@"site"]);
}
/* "abcdef-ghijk2-mnopQr": Apple's strong password format (lower case, one capital, one digit) */
static NSString *strong_password(id target) {
    NSUInteger len = 20, maxlen = 0;
    UITextInputPasswordRules *rules = [target respondsToSelector:@selector(passwordRules)] ? [(id<UITextInputTraits>)target passwordRules] : nil;
    for (NSString *part in [rules.passwordRulesDescriptor componentsSeparatedByString:@";"]) {
        NSArray *kv = [part componentsSeparatedByString:@":"];
        if (kv.count != 2) continue;
        NSString *k = [kv[0] stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        NSInteger v = [kv[1] integerValue];
        if ([k isEqualToString:@"minlength"] && v > (NSInteger)len) len = (NSUInteger)v;
        if ([k isEqualToString:@"maxlength"] && v > 0) maxlen = (NSUInteger)v;
    }
    if (maxlen && len > maxlen) len = maxlen;
    const char *lower = "abcdefghijkmnopqrstuvwxyz";
    NSMutableString *s = [NSMutableString string];
    BOOL hyphens = len == 20;
    for (NSUInteger i = 0; i < len; i++) {
        if (hyphens && (i == 6 || i == 13)) { [s appendString:@"-"]; continue; }
        [s appendFormat:@"%c", lower[arc4random_uniform((uint32_t)strlen(lower))]];
    }
    NSUInteger slots[2], k = 0;
    while (k < 2) { NSUInteger i = arc4random_uniform((uint32_t)len); if ([s characterAtIndex:i] != '-' && (k == 0 || i != slots[0])) slots[k++] = i; }
    [s replaceCharactersInRange:NSMakeRange(slots[0], 1) withString:[NSString stringWithFormat:@"%u", arc4random_uniform(10)]];
    [s replaceCharactersInRange:NSMakeRange(slots[1], 1) withString:[[s substringWithRange:NSMakeRange(slots[1], 1)] uppercaseString]];
    return s;
}
static NSString *last_code; static NSDate *last_code_at;
static NSString *recent_code(void) { return last_code && -last_code_at.timeIntervalSinceNow < 180 ? last_code : nil; }

@implementation __IsimAutoFillSuggestion
@end
NSArray<__IsimAutoFillSuggestion *> *isim_ui_autofill_suggestions(id target) {
    NSString *t = content_type(target);
    if (!t || ![target isKindOfClass:[UIView class]]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    __weak UIView *weakTarget = target;
    if ([t isEqualToString:UITextContentTypeOneTimeCode]) {
        NSString *code = recent_code();
        if (!code) return out;
        __IsimAutoFillSuggestion *s = [__IsimAutoFillSuggestion new];
        s.title = code; s.subtitle = @"From Messages"; s.symbol = @"message.fill";
        s.action = ^{
            UIView<IsimEditableText> *f = (UIView<IsimEditableText> *)weakTarget;
            if (!f) return;
            fill_field(f, code);
            last_code = nil;
            NSLog(@"isim: AutoFill: one-time code %@ from Messages", code);
        };
        [out addObject:s];
        return out;
    }
    if (!pref_on(@"AutoFillPasswords")) return out;
    if ([t isEqualToString:UITextContentTypeNewPassword]) {
        __IsimAutoFillSuggestion *s = [__IsimAutoFillSuggestion new];
        s.title = @"Use Strong Password"; s.symbol = @"key.fill";
        s.action = ^{
            UIView *v = weakTarget;
            if (!v) return;
            NSString *pw = strong_password(v);
            for (UIView<IsimEditableText> *f in form_fields(v)) if ([content_type(f) isEqualToString:UITextContentTypeNewPassword]) {
                fill_field(f, pw);
                objc_setAssociatedObject(f, kAutoFilled, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);    /* still offered for saving */
                objc_setAssociatedObject(f, "isim.strong", pw, OBJC_ASSOCIATION_COPY_NONATOMIC);
                isim_ui_set_needs_display();
            }
            NSLog(@"isim: AutoFill: strong password suggested (%lu characters)", (unsigned long)pw.length);
        };
        [out addObject:s];
        return out;
    }
    if (!is_user_type(t) && ![t isEqualToString:UITextContentTypePassword]) return out;
    for (NSDictionary *c in credentials_for_app()) {
        if (out.count == 3) break;
        __IsimAutoFillSuggestion *s = [__IsimAutoFillSuggestion new];
        s.title = c[@"user"]; s.subtitle = c[@"site"]; s.symbol = @"key.fill";
        s.action = ^{ UIView *v = weakTarget; if (v) autofill_credentials(v, c); };
        [out addObject:s];
    }
    return out;
}
BOOL isim_ui_autofill_strong(id field) {
    NSString *pw = objc_getAssociatedObject(field, "isim.strong");
    return pw && [field conformsToProtocol:@protocol(IsimEditableText)] && [[(id<IsimEditableText>)field _isim_plainText] isEqualToString:pw];
}

/* a password field leaves its window with a password the user typed (or a strong one AutoFill made): offer to save */
static BOOL save_pending;
void isim_ui_autofill_field_leaving(UIView<IsimEditableText> *field) {
    NSString *t = content_type(field), *pw = [field _isim_plainText];
    if (save_pending || !is_password_type(t) || !pw.length || !pref_on(@"AutoFillPasswords")) return;
    if ([objc_getAssociatedObject(field, kAutoFilled) isEqualToString:pw]) return;
    NSString *user = nil;
    for (UIView<IsimEditableText> *f in form_fields(field)) if (is_user_type(content_type(f)) && [f _isim_plainText].length) { user = [f _isim_plainText]; break; }
    if (!user) return;
    NSString *site = app_sites()[0];
    NSDictionary *existing = nil;
    for (NSDictionary *e in passwords_all()) if ([e[@"site"] isEqualToString:site] && [e[@"user"] isEqualToString:user]) existing = e;
    if ([existing[@"password"] isEqualToString:pw]) return;
    static NSMutableSet *offered;                        /* each password is offered once (the form may leave the screen twice) */
    if (!offered) offered = [NSMutableSet set];
    NSString *key = [NSString stringWithFormat:@"%@\n%@\n%@", site, user, pw];
    if ([offered containsObject:key]) return;
    [offered addObject:key];
    save_pending = YES;
    BOOL update = existing != nil;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.6 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIViewController *top = top_controller();
        if (!top) { save_pending = NO; return; }
        NSString *app = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"this app";
        UIAlertController *a = [UIAlertController alertControllerWithTitle:update ? @"Update Password?" : @"Save Password?"
            message:[NSString stringWithFormat:@"Would you like to %@ the password for “%@” to use with %@ and %@?", update ? @"update" : @"save", user, app, site]
            preferredStyle:UIAlertControllerStyleAlert];
        [a addAction:[UIAlertAction actionWithTitle:@"Not Now" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x) {
            save_pending = NO; NSLog(@"isim: AutoFill: password not saved"); }]];
        [a addAction:[UIAlertAction actionWithTitle:update ? @"Update Password" : @"Save Password" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
            save_pending = NO;
            passwords_save(site, user, pw);
            NSLog(@"isim: AutoFill: %@ the password of %@ for %@", update ? @"updated" : @"saved", user, site);
        }]];
        a.view.accessibilityIdentifier = @"isim-save-password";
        NSLog(@"isim: AutoFill: %@ password prompt for %@ (%@)", update ? @"update" : @"save", user, site);
        [top presentViewController:a animated:YES completion:nil];
    });
}

/* ================= dictation ================= */
static NSString *spoken_to_text(NSString *spoken, NSString *before) {
    NSDictionary *marks = @{ @"period": @".", @"full stop": @".", @"comma": @",", @"question mark": @"?", @"exclamation point": @"!",
                             @"exclamation mark": @"!", @"colon": @":", @"semicolon": @";", @"new line": @"\n", @"new paragraph": @"\n\n" };
    NSArray *words = [spoken componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSMutableString *out = [NSMutableString string];
    NSString *trimmed = [before stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    BOOL capital = !trimmed.length || [trimmed hasSuffix:@"."] || [trimmed hasSuffix:@"?"] || [trimmed hasSuffix:@"!"] || [before hasSuffix:@"\n"];
    BOOL needSpace = before.length && ![NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:[before characterAtIndex:before.length - 1]];
    for (NSUInteger i = 0; i < words.count; i++) {
        NSString *w = words[i];
        if (!w.length) continue;
        NSString *two = i + 1 < words.count ? [[w stringByAppendingFormat:@" %@", words[i + 1]] lowercaseString] : nil;
        NSString *mark = two ? marks[two] : nil;
        if (mark) i++; else mark = marks[w.lowercaseString];
        if (mark) {
            [out appendString:mark];
            needSpace = ![mark hasPrefix:@"\n"];
            if ([@".?!\n" containsString:[mark substringToIndex:1]]) capital = YES;
            continue;
        }
        if (needSpace) [out appendString:@" "];
        [out appendString:capital ? [[w substringToIndex:1].uppercaseString stringByAppendingString:[w substringFromIndex:1]] : w];
        capital = NO; needSpace = YES;
    }
    return out;
}
static NSString *text_before_caret(id t) {
    if (![t conformsToProtocol:@protocol(UITextInput)]) return @"";
    id<UITextInput> ti = t;
    UITextRange *r = [ti textRangeFromPosition:ti.beginningOfDocument toPosition:ti.selectedTextRange.start ?: ti.endOfDocument];
    return (r ? [ti textInRange:r] : nil) ?: @"";
}
static void dictation_text(NSString *spoken) {
    id t = isim_ui_keyboard_target();
    if (!t) { NSLog(@"isim: dictation: no text input is being edited"); return; }
    if (!pref_on(@"KeyboardDictation")) { NSLog(@"isim: dictation is off (Settings > General > Keyboard > Enable Dictation)"); return; }
    if (!isim_ui_keyboard_dictating()) isim_ui_keyboard_set_dictating(YES);
    NSString *text = spoken_to_text(spoken, text_before_caret(t));
    if ([t respondsToSelector:@selector(insertDictationResult:)]) {
        UIDictationPhrase *p = [[UIDictationPhrase alloc] initWithIsimText:text alternatives:nil];
        [(id<UITextInput>)t insertDictationResult:@[p]];
    } else [(id<UIKeyInput>)t insertText:text];
    if ([t respondsToSelector:@selector(dictationRecordingDidEnd)]) [(id<UITextInput>)t dictationRecordingDidEnd];
    NSLog(@"isim: dictation: \"%@\"", [text stringByReplacingOccurrencesOfString:@"\n" withString:@"\\n"]);
    isim_ui_keyboard_suggestions_changed();
}

/* ================= Scribble ================= */
static BOOL pencil_expected;
BOOL isim_ui_scribble_focusing;
@implementation UIScribbleInteraction { __weak UIView *_view; }
+ (BOOL)isPencilInputExpected { return pencil_expected; }
- (instancetype)initWithDelegate:(id<UIScribbleInteractionDelegate>)d { if ((self = [super init])) _delegate = d; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
- (void)_isim_setHandling:(BOOL)h { _handlingWriting = h; }
@end
@implementation UIIndirectScribbleInteraction { __weak UIView *_view; }
- (instancetype)initWithDelegate:(id<UIIndirectScribbleInteractionDelegate>)d { if ((self = [super init])) _delegate = d; return self; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v {}
- (void)didMoveToView:(UIView *)v { _view = v; }
- (void)_isim_setHandling:(BOOL)h { _handlingWriting = h; }
@end

/* the handwriting: drawn where it was written, then it fades as the text appears */
static UIWindow *ink_window;
static void show_ink(CGPoint at, NSString *text) {
    if (!ink_window) {
        ink_window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
        ink_window.windowLevel = 14000000;
        ink_window.userInteractionEnabled = NO;
        ink_window.backgroundColor = UIColor.clearColor;
    }
    for (UIView *v in ink_window.subviews) [v removeFromSuperview];
    UILabel *ink = [UILabel new];
    ink.text = text;
    ink.font = [UIFont italicSystemFontOfSize:30];
    ink.textColor = [UIColor colorWithRed:0.1 green:0.1 blue:0.35 alpha:1];
    [ink sizeToFit];
    ink.center = CGPointMake(at.x + ink.bounds.size.width / 2 - 8, at.y);
    ink.transform = CGAffineTransformMakeRotation(-0.05);
    ink.accessibilityIdentifier = @"isim-scribble-ink";
    [ink_window addSubview:ink];
    ink_window.hidden = NO;
    isim_ui_set_needs_display();
}
static void hide_ink(void) {
    UIView *ink = ink_window.subviews.firstObject;
    if (!ink) return;
    [UIView animateWithDuration:0.3 animations:^{ ink.alpha = 0; } completion:^(BOOL f) { [ink removeFromSuperview]; ink_window.hidden = YES; }];
}
static void write_into(UIResponder<UITextInput> *input, CGPoint screen, NSString *text, void (^done)(void)) {
    UIView *v = [input isKindOfClass:[UIView class]] ? (UIView *)input : nil;
    if (!input || ([input conformsToProtocol:@protocol(IsimEditableText)] && ![(id<IsimEditableText>)input _isim_isEditable])) {
        NSLog(@"isim: Scribble: nothing to write into"); if (done) done(); return;
    }
    show_ink(screen, text);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (!input.isFirstResponder) { isim_ui_scribble_focusing = YES; [input becomeFirstResponder]; isim_ui_scribble_focusing = NO; }
        NSString *s = text;
        if ([input conformsToProtocol:@protocol(IsimEditableText)] && v) {
            id<IsimEditableText> e = (id<IsimEditableText>)input;
            NSString *cur = [e _isim_plainText];
            CGPoint p = [v convertPoint:[v.window convertPoint:screen fromView:nil] fromView:nil];
            NSUInteger i = MIN([e _isim_indexAtPoint:p], cur.length);
            if (i && ![NSCharacterSet.whitespaceAndNewlineCharacterSet characterIsMember:[cur characterAtIndex:i - 1]]) s = [@" " stringByAppendingString:s];
            isim_ti_set_selection(e, NSMakeRange(i, 0));
        }
        [input insertText:s];
        hide_ink();
        NSLog(@"isim: Scribble wrote \"%@\" into %@%@", text, NSStringFromClass([input class]),
              v.accessibilityIdentifier ? [NSString stringWithFormat:@" (%@)", v.accessibilityIdentifier] : @"");
        if (done) done();
    });
}
static void scribble(CGPoint screen, NSString *text) {
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) { NSLog(@"isim: Scribble needs an iPad (Apple Pencil)"); return; }
    if (!pref_on(@"PencilScribble")) { NSLog(@"isim: Scribble is off (Settings > Apple Pencil > Scribble)"); return; }
    pencil_expected = YES;
    UIWindow *w = UIApplication.sharedApplication.keyWindow;
    CGPoint wp = [w convertPoint:screen fromView:nil];
    UIView *hit = [w hitTest:wp withEvent:nil];
    for (UIView *v = hit; v; v = v.superview) {
        for (id<UIInteraction> i in v.interactions) {
            if ([i isKindOfClass:[UIIndirectScribbleInteraction class]]) {
                UIIndirectScribbleInteraction *ii = (UIIndirectScribbleInteraction *)i;
                id<UIIndirectScribbleInteractionDelegate> d = ii.delegate;
                CGPoint p = [v convertPoint:wp fromView:w];
                __block id element = nil;
                [d indirectScribbleInteraction:ii requestElementsInRect:CGRectMake(p.x - 20, p.y - 20, 40, 40) completion:^(NSArray *elements) {
                    for (id e in elements) if (CGRectContainsPoint(CGRectInset([d indirectScribbleInteraction:ii frameForElement:e], -10, -10), p)) { element = e; break; }
                }];
                if (!element) continue;
                [ii _isim_setHandling:YES];
                if ([d respondsToSelector:@selector(indirectScribbleInteraction:willBeginWritingInElement:)]) [d indirectScribbleInteraction:ii willBeginWritingInElement:element];
                void (^finish)(void) = ^{
                    [ii _isim_setHandling:NO];
                    if ([d respondsToSelector:@selector(indirectScribbleInteraction:didFinishWritingInElement:)]) [d indirectScribbleInteraction:ii didFinishWritingInElement:element];
                };
                NSLog(@"isim: Scribble: writing in element %@", element);
                if ([d indirectScribbleInteraction:ii isElementFocused:element]) {
                    write_into((UIResponder<UITextInput> *)isim_ui_first_responder(), screen, text, finish);
                } else {
                    isim_ui_scribble_focusing = YES;
                    [d indirectScribbleInteraction:ii focusElementIfNeeded:element referencePoint:p completion:^(UIResponder<UITextInput> *input) {
                        isim_ui_scribble_focusing = NO;
                        write_into(input, screen, text, finish);
                    }];
                    isim_ui_scribble_focusing = NO;
                }
                return;
            }
            if ([i isKindOfClass:[UIScribbleInteraction class]]) {
                UIScribbleInteraction *si = (UIScribbleInteraction *)i;
                id<UIScribbleInteractionDelegate> d = si.delegate;
                CGPoint p = [v convertPoint:wp fromView:w];
                if ([d respondsToSelector:@selector(scribbleInteraction:shouldBeginAtLocation:)] && ![d scribbleInteraction:si shouldBeginAtLocation:p]) {
                    NSLog(@"isim: Scribble declined by %@ (shouldBeginAtLocation)", NSStringFromClass([d class]));
                    return;
                }
                UIView *field = v;
                while (field && ![field conformsToProtocol:@protocol(UITextInput)]) field = field.superview;
                if (!field) for (UIView *sub = hit; sub && sub != v.superview; sub = sub.superview) if ([sub conformsToProtocol:@protocol(UITextInput)]) { field = sub; break; }
                [si _isim_setHandling:YES];
                if ([d respondsToSelector:@selector(scribbleInteractionWillBeginWriting:)]) [d scribbleInteractionWillBeginWriting:si];
                write_into((UIResponder<UITextInput> *)field, screen, text, ^{
                    [si _isim_setHandling:NO];
                    if ([d respondsToSelector:@selector(scribbleInteractionDidFinishWriting:)]) [d scribbleInteractionDidFinishWriting:si];
                });
                return;
            }
        }
        if ([v conformsToProtocol:@protocol(IsimEditableText)] && [(id<IsimEditableText>)v _isim_isEditable]) {
            write_into((UIResponder<UITextInput> *)v, screen, text, nil);
            return;
        }
    }
    NSLog(@"isim: Scribble: no text input at %g,%g", screen.x, screen.y);
}

/* ================= script commands ================= */
void isim_ui_text_service(NSString *command) {
    if ([command isEqualToString:@"dictate-fail"]) {
        id t = isim_ui_keyboard_target();
        if (t && [t respondsToSelector:@selector(dictationRecognitionFailed)]) [(id<UITextInput>)t dictationRecognitionFailed];
        NSLog(@"isim: dictation: recognition failed");
        return;
    }
    if ([command hasPrefix:@"dictate:"]) { dictation_text([command substringFromIndex:8]); return; }
    if ([command hasPrefix:@"sms:"]) {
        NSString *msg = [command substringFromIndex:4];
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:@"(?<![\\d-])(\\d{4,8})(?![\\d-])" options:0 error:NULL];
        NSTextCheckingResult *m = [re firstMatchInString:msg options:0 range:NSMakeRange(0, msg.length)];
        if (m) { last_code = [msg substringWithRange:[m rangeAtIndex:1]]; last_code_at = NSDate.date; }
        NSLog(@"isim: message received: \"%@\"%@", msg, m ? [NSString stringWithFormat:@" (code %@)", last_code] : @"");
        isim_ui_keyboard_suggestions_changed();
        return;
    }
    if ([command hasPrefix:@"scribble:"]) {
        double x = 0, y = 0; int n = 0;
        NSString *rest = [command substringFromIndex:9];
        if (sscanf(rest.UTF8String, "%lf %lf %n", &x, &y, &n) < 2) { NSLog(@"isim: scribble X Y TEXT"); return; }
        scribble(CGPointMake(x, y), [@(rest.UTF8String + n) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet]);
        return;
    }
}

/* ================= detected items (UITextView) ================= */
@interface UITextItem ()
- (instancetype)initWithIsimRange:(NSRange)r link:(NSURL *)u;
@end
@implementation UITextItem
- (instancetype)initWithIsimRange:(NSRange)r link:(NSURL *)u {
    if ((self = [super init])) { _contentType = UITextItemContentTypeLink; _range = r; _link = u; }
    return self;
}
@end
@implementation UITextItemMenuConfiguration { @public UIMenu *_menu; }
+ (instancetype)configurationWithMenu:(UIMenu *)menu { UITextItemMenuConfiguration *c = [super new]; c->_menu = menu; return c; }
@end

NSArray<NSTextCheckingResult *> *isim_ui_detect_items(NSString *text, UIDataDetectorTypes types) {
    NSTextCheckingTypes t = 0;
    if (types & UIDataDetectorTypeLink) t |= NSTextCheckingTypeLink;
    if (types & UIDataDetectorTypePhoneNumber) t |= NSTextCheckingTypePhoneNumber;
    if (types & UIDataDetectorTypeAddress) t |= NSTextCheckingTypeAddress;
    if (types & UIDataDetectorTypeCalendarEvent) t |= NSTextCheckingTypeDate;
    if (types & UIDataDetectorTypeFlightNumber) t |= NSTextCheckingTypeTransitInformation;
    if (!text.length) return @[];
    NSMutableArray *found = [NSMutableArray array];
    if (t) [found addObjectsFromArray:[[NSDataDetector dataDetectorWithTypes:t error:NULL] matchesInString:text options:0 range:NSMakeRange(0, text.length)] ?: @[]];
    if (types & UIDataDetectorTypeShipmentTrackingNumber) {          /* UPS and USPS numbers open the carrier's tracking page */
        NSDictionary *carriers = @{ @"\\b1Z[0-9A-Z]{16}\\b": @"https://www.ups.com/track?tracknum=",
                                    @"\\b9[2-5]\\d{20}\\b": @"https://tools.usps.com/go/TrackConfirmAction?tLabels=" };
        for (NSString *pattern in carriers)
            for (NSTextCheckingResult *m in [[NSRegularExpression regularExpressionWithPattern:pattern options:0 error:NULL] matchesInString:text options:0 range:NSMakeRange(0, text.length)])
                [found addObject:[NSTextCheckingResult linkCheckingResultWithRange:m.range URL:[NSURL URLWithString:[carriers[pattern] stringByAppendingString:[text substringWithRange:m.range]]]]];
    }
    /* (.lookupSuggestion: isim has no Look Up service, so nothing is suggested) */
    [found sortUsingComparator:^NSComparisonResult(NSTextCheckingResult *a, NSTextCheckingResult *b) {
        return a.range.location < b.range.location ? NSOrderedAscending : a.range.location > b.range.location ? NSOrderedDescending : NSOrderedSame; }];
    NSMutableArray *out = [NSMutableArray array];
    NSUInteger end = 0;
    for (NSTextCheckingResult *r in found) if (r.range.location >= end) { [out addObject:r]; end = NSMaxRange(r.range); }
    return out;
}
static NSString *query_escape(NSString *s) {
    NSMutableString *out = [NSMutableString string];
    const unsigned char *u = (const unsigned char *)s.UTF8String;
    for (; *u; u++) {
        if (isalnum(*u) || strchr("-._~", *u)) [out appendFormat:@"%c", *u];
        else if (*u == ' ') [out appendString:@"+"];
        else [out appendFormat:@"%%%02X", *u];
    }
    return out;
}
NSURL *isim_ui_detected_url(NSTextCheckingResult *r, NSString *text) {
    NSString *s = [text substringWithRange:r.range];
    switch (r.resultType) {
    case NSTextCheckingTypeLink: return r.URL;
    case NSTextCheckingTypePhoneNumber: {
        NSMutableString *d = [NSMutableString string];
        for (NSUInteger i = 0; i < s.length; i++) { unichar c = [s characterAtIndex:i]; if (isdigit(c) || c == '+') [d appendFormat:@"%C", c]; }
        return [NSURL URLWithString:[@"tel:" stringByAppendingString:d]];
    }
    case NSTextCheckingTypeAddress: return [NSURL URLWithString:[@"https://maps.apple.com/?address=" stringByAppendingString:query_escape(s)]];
    case NSTextCheckingTypeDate: return [NSURL URLWithString:[NSString stringWithFormat:@"calshow:%.0f", r.date.timeIntervalSinceReferenceDate]];
    case NSTextCheckingTypeTransitInformation:            /* (iOS links data-detector items with this scheme) */
        return [NSURL URLWithString:[NSString stringWithFormat:@"x-apple-data-detectors://flight/%@", query_escape([s stringByReplacingOccurrencesOfString:@" " withString:@""])]];
    default: return nil;
    }
}
static void open_item_url(NSURL *u) {
    NSLog(@"isim: text item opened: %@", u.absoluteString);
    [UIApplication.sharedApplication openURL:u options:@{} completionHandler:nil];
}
/* a tap on a detected item: YES if handled */
BOOL isim_ui_text_item_tap(UITextView *tv, NSTextCheckingResult *r) {
    NSURL *u = isim_ui_detected_url(r, tv.text);
    if (!u) return NO;
    UITextItem *item = [[UITextItem alloc] initWithIsimRange:r.range link:u];
    id<UITextViewDelegate> d = tv.delegate;
    NSLog(@"isim: text item tapped: %@", [tv.text substringWithRange:r.range]);
    BOOL flight = r.resultType == NSTextCheckingTypeTransitInformation;
    UIAction *def = [UIAction actionWithTitle:@"Open" image:nil identifier:nil handler:^(UIAction *a) {
        if (flight) {                                    /* no flight preview on isim: the item's menu */
            NSArray *rects = [(id<IsimEditableText>)tv _isim_selectionRectsForRange:r.range];
            CGRect box = rects.count ? [rects[0] CGRectValue] : tv.bounds;
            box = CGRectOffset(box, -tv.contentOffset.x, -tv.contentOffset.y);
            isim_ui_text_item_menu(tv, r, [tv convertRect:box toView:nil]);
        } else open_item_url(u);
    }];
    if ([d respondsToSelector:@selector(textView:primaryActionForTextItem:defaultAction:)]) {
        UIAction *a = [d textView:tv primaryActionForTextItem:item defaultAction:def];
        if (a) { [a setSender:tv]; if (a.handler) a.handler(a); }
        return YES;
    }
    if ([d respondsToSelector:@selector(textView:shouldInteractWithURL:inRange:interaction:)]) {
        if ([d textView:tv shouldInteractWithURL:u inRange:r.range interaction:UITextItemInteractionInvokeDefaultAction]) open_item_url(u);
        return YES;
    }
    if ([d respondsToSelector:@selector(textView:shouldInteractWithURL:inRange:)]) {
        if ([d textView:tv shouldInteractWithURL:u inRange:r.range]) open_item_url(u);
        return YES;
    }
    open_item_url(u);
    return YES;
}
/* a long press: the item's menu */
BOOL isim_ui_text_item_menu(UITextView *tv, NSTextCheckingResult *r, CGRect windowRect) {
    NSURL *u = isim_ui_detected_url(r, tv.text);
    if (!u) return NO;
    NSString *s = [tv.text substringWithRange:r.range];
    UITextItem *item = [[UITextItem alloc] initWithIsimRange:r.range link:u];
    NSDictionary *fc = r.resultType == NSTextCheckingTypeTransitInformation ? r.components : nil;
    NSString *open = fc ? [NSString stringWithFormat:@"%@ flight %@", fc[NSTextCheckingAirlineKey], fc[NSTextCheckingFlightKey]]
                   : r.resultType == NSTextCheckingTypePhoneNumber ? [@"Call " stringByAppendingString:s]
                   : r.resultType == NSTextCheckingTypeAddress ? @"Get Directions" : r.resultType == NSTextCheckingTypeDate ? @"Show in Calendar" : @"Open Link";
    NSString *copy = r.resultType == NSTextCheckingTypeLink ? @"Copy Link" : r.resultType == NSTextCheckingTypeAddress ? @"Copy Address" : @"Copy";
    UIMenu *menu = [UIMenu menuWithTitle:s children:@[
        [UIAction actionWithTitle:open image:nil identifier:nil handler:^(UIAction *a) { if (!fc) open_item_url(u); else NSLog(@"isim: flight %@ (no flight information on isim)", s); }],
        [UIAction actionWithTitle:copy image:nil identifier:nil handler:^(UIAction *a) {
            UIPasteboard.generalPasteboard.string = r.resultType == NSTextCheckingTypeLink ? u.absoluteString : s; NSLog(@"isim: text item copied"); }],
    ]];
    id<UITextViewDelegate> d = tv.delegate;
    if ([d respondsToSelector:@selector(textView:menuConfigurationForTextItem:defaultMenu:)]) {
        UITextItemMenuConfiguration *c = [d textView:tv menuConfigurationForTextItem:item defaultMenu:menu];
        if (!c) return YES;                                  /* no menu for this item */
        menu = c->_menu ?: menu;
    } else if ([d respondsToSelector:@selector(textView:shouldInteractWithURL:inRange:interaction:)] &&
               ![d textView:tv shouldInteractWithURL:u inRange:r.range interaction:UITextItemInteractionPresentActions]) return YES;
    NSLog(@"isim: text item menu: %@", s);
    isim_ui_show_edit_menu(windowRect, menu.children, nil);
    return YES;
}
