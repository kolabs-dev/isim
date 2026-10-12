/* isim IntentsUI (ARC): the Add to Siri sheet (adapted: the phrase is typed, isim has no microphone input), the edit
 * sheet, the Add to Siri button, and Intents UI extensions (com.apple.intents-ui-service) as helper processes that
 * draw their view for Siri's card (ISIM_EXTENSION_REQUEST { mode = intents-ui; interaction; width; out }). */
#import <IntentsUI/IntentsUI.h>
#include <stdlib.h>

INVoiceShortcut *isim_in_add_voice_shortcut(INShortcut *shortcut, NSString *phrase);
void isim_in_update_voice_shortcut(NSUUID *ident, NSString *phrase, BOOL remove);
id isim_in_decode(id v);
@interface NSObject (INValuesUI)
- (void)_set:(id)v forKey:(NSString *)k;
@end

static NSString *shortcut_title(INShortcut *s) {
    if (s.intent) return s.intent.suggestedInvocationPhrase ?: s.intent.intentDescription;
    return s.userActivity.title ?: s.userActivity.suggestedInvocationPhrase ?: s.userActivity.activityType;
}
static NSString *suggested_phrase(INShortcut *s) { return s.intent.suggestedInvocationPhrase ?: s.userActivity.suggestedInvocationPhrase ?: @""; }

/* the sheet: "When I say" (the phrase), "Do" (the shortcut), Cancel / Done (iOS 13+ layout) */
@interface _INUIVoiceShortcutSheet : UIViewController <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *phrase;
@property (nonatomic, copy) NSString *initialPhrase, *doTitle, *doneTitle;
@property (nonatomic, copy) void (^onDone)(NSString *phrase);
@property (nonatomic, copy) void (^onCancel)(void);
@property (nonatomic, copy) void (^onDelete)(void);
@end
@implementation _INUIVoiceShortcutSheet
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.systemGroupedBackgroundColor;
    self.title = NSLocalizedString(@"Add to Siri", nil);
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:self.doneTitle ?: NSLocalizedString(@"Done", nil) style:UIBarButtonItemStyleDone target:self action:@selector(done)];
    done.accessibilityIdentifier = @"siri-shortcut-done";
    self.navigationItem.rightBarButtonItem = done;
    self.navigationItem.leftBarButtonItem.accessibilityIdentifier = @"siri-shortcut-cancel";
    CGFloat W = self.view.bounds.size.width, y = 120;
    UILabel *when = [[UILabel alloc] initWithFrame:CGRectMake(20, y, W - 40, 20)];
    when.text = NSLocalizedString(@"WHEN I SAY", nil); when.font = [UIFont systemFontOfSize:13]; when.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:when];
    UIView *box = [[UIView alloc] initWithFrame:CGRectMake(16, y + 26, W - 32, 52)];
    box.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; box.layer.cornerRadius = 10;
    [self.view addSubview:box];
    _phrase = [[UITextField alloc] initWithFrame:CGRectMake(32, y + 26, W - 64, 52)];
    _phrase.text = self.initialPhrase; _phrase.font = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    _phrase.placeholder = NSLocalizedString(@"Phrase", nil); _phrase.delegate = self;
    _phrase.accessibilityIdentifier = @"siri-shortcut-phrase"; _phrase.clearButtonMode = UITextFieldViewModeWhileEditing;
    [self.view addSubview:_phrase];
    UILabel *hint = [[UILabel alloc] initWithFrame:CGRectMake(20, y + 84, W - 40, 34)];
    hint.text = NSLocalizedString(@"isim has no microphone input: type the phrase. Say it with the script command siri.", nil);
    hint.numberOfLines = 2; hint.font = [UIFont systemFontOfSize:12]; hint.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:hint];
    UILabel *doLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, y + 140, W - 40, 20)];
    doLabel.text = NSLocalizedString(@"DO", nil); doLabel.font = [UIFont systemFontOfSize:13]; doLabel.textColor = UIColor.secondaryLabelColor;
    [self.view addSubview:doLabel];
    UILabel *doBox = [[UILabel alloc] initWithFrame:CGRectMake(16, y + 166, W - 32, 52)];
    doBox.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; doBox.layer.cornerRadius = 10; doBox.clipsToBounds = YES;
    doBox.text = [@"   " stringByAppendingString:self.doTitle ?: @""]; doBox.font = [UIFont systemFontOfSize:17];
    doBox.accessibilityIdentifier = @"siri-shortcut-action";
    [self.view addSubview:doBox];
    if (self.onDelete) {
        UIButton *del = [UIButton buttonWithType:UIButtonTypeSystem];
        del.frame = CGRectMake(16, y + 240, W - 32, 48); [del setTitle:NSLocalizedString(@"Delete Shortcut", nil) forState:UIControlStateNormal];
        [del setTitleColor:UIColor.systemRedColor forState:UIControlStateNormal]; del.backgroundColor = UIColor.secondarySystemGroupedBackgroundColor; del.layer.cornerRadius = 10;
        del.accessibilityIdentifier = @"siri-shortcut-delete";
        [del addTarget:self action:@selector(remove) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:del];
    }
}
- (void)viewDidAppear:(BOOL)animated { [super viewDidAppear:animated]; [_phrase becomeFirstResponder]; }
- (BOOL)textFieldShouldReturn:(UITextField *)f { [self done]; return NO; }
- (void)cancel { [_phrase resignFirstResponder]; if (self.onCancel) self.onCancel(); }
- (void)remove { [_phrase resignFirstResponder]; if (self.onDelete) self.onDelete(); }
- (void)done {
    NSString *p = [_phrase.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    if (!p.length) return;
    [_phrase resignFirstResponder];
    if (self.onDone) self.onDone(p);
}
@end

static UINavigationController *wrap(UIViewController *host, _INUIVoiceShortcutSheet *sheet) {
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:sheet];
    nav.view.frame = host.view.bounds; nav.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [host addChildViewController:nav]; [host.view addSubview:nav.view]; [nav didMoveToParentViewController:host];
    return nav;
}

@implementation INUIAddVoiceShortcutViewController { INShortcut *_shortcut; }
- (instancetype)initWithShortcut:(INShortcut *)shortcut { if ((self = [super initWithNibName:nil bundle:nil])) _shortcut = shortcut; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _INUIVoiceShortcutSheet *s = [_INUIVoiceShortcutSheet new];
    s.initialPhrase = suggested_phrase(_shortcut); s.doTitle = shortcut_title(_shortcut);
    __weak INUIAddVoiceShortcutViewController *weakSelf = self;
    s.onCancel = ^{ INUIAddVoiceShortcutViewController *me = weakSelf; [me.delegate addVoiceShortcutViewControllerDidCancel:me]; };
    s.onDone = ^(NSString *phrase) {
        INUIAddVoiceShortcutViewController *me = weakSelf; if (!me) return;
        INVoiceShortcut *v = isim_in_add_voice_shortcut(me->_shortcut, phrase);
        [me.delegate addVoiceShortcutViewController:me didFinishWithVoiceShortcut:v error:nil];
    };
    wrap(self, s);
    NSLog(@"isim IntentsUI: Add to Siri (%@)", shortcut_title(_shortcut));
}
@end

@implementation INUIEditVoiceShortcutViewController { INVoiceShortcut *_voice; }
- (instancetype)initWithVoiceShortcut:(INVoiceShortcut *)v { if ((self = [super initWithNibName:nil bundle:nil])) _voice = v; return self; }
- (void)viewDidLoad {
    [super viewDidLoad];
    _INUIVoiceShortcutSheet *s = [_INUIVoiceShortcutSheet new];
    s.initialPhrase = _voice.invocationPhrase; s.doTitle = shortcut_title(_voice.shortcut);
    __weak INUIEditVoiceShortcutViewController *weakSelf = self;
    s.onCancel = ^{ INUIEditVoiceShortcutViewController *me = weakSelf; [me.delegate editVoiceShortcutViewControllerDidCancel:me]; };
    s.onDone = ^(NSString *phrase) {
        INUIEditVoiceShortcutViewController *me = weakSelf; if (!me) return;
        isim_in_update_voice_shortcut(me->_voice.identifier, phrase, NO);
        [me->_voice _set:phrase forKey:@"invocationPhrase"];
        [me.delegate editVoiceShortcutViewController:me didUpdateVoiceShortcut:me->_voice error:nil];
    };
    s.onDelete = ^{
        INUIEditVoiceShortcutViewController *me = weakSelf; if (!me) return;
        isim_in_update_voice_shortcut(me->_voice.identifier, nil, YES);
        [me.delegate editVoiceShortcutViewController:me didDeleteVoiceShortcutWithIdentifier:me->_voice.identifier];
    };
    wrap(self, s);
}
@end

@implementation INUIAddVoiceShortcutButton { INVoiceShortcut *_voice; }
- (instancetype)initWithStyle:(INUIAddVoiceShortcutButtonStyle)style {
    if ((self = [super initWithFrame:CGRectMake(0, 0, 180, 44)])) {
        _style = style;
        BOOL dark = style == INUIAddVoiceShortcutButtonStyleBlack || style == INUIAddVoiceShortcutButtonStyleBlackOutline;
        BOOL outline = style == INUIAddVoiceShortcutButtonStyleWhiteOutline || style == INUIAddVoiceShortcutButtonStyleBlackOutline || style == INUIAddVoiceShortcutButtonStyleAutomaticOutline;
        self.backgroundColor = dark ? UIColor.blackColor : UIColor.whiteColor;
        [self setTitleColor:dark ? UIColor.whiteColor : UIColor.blackColor forState:UIControlStateNormal];
        self.layer.cornerRadius = 8;
        if (outline) { self.layer.borderWidth = 1; self.layer.borderColor = (dark ? UIColor.whiteColor : UIColor.blackColor).CGColor; }
        self.titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightSemibold];
        [self setTitle:NSLocalizedString(@"Add to Siri", nil) forState:UIControlStateNormal];
        self.accessibilityIdentifier = @"add-to-siri";
        [self addTarget:self action:@selector(_tapped) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}
- (instancetype)initWithFrame:(CGRect)frame { return [self initWithStyle:INUIAddVoiceShortcutButtonStyleWhite]; }
- (void)setShortcut:(INShortcut *)shortcut {
    _shortcut = shortcut; _voice = nil;
    [INVoiceShortcutCenter.sharedCenter getAllVoiceShortcutsWithCompletion:^(NSArray<INVoiceShortcut *> *list, NSError *e) {
        for (INVoiceShortcut *v in list) if ([v.shortcut isEqual:shortcut] || (v.shortcut.intent && [NSStringFromClass(v.shortcut.intent.class) isEqual:NSStringFromClass(shortcut.intent.class)] && [shortcut_title(v.shortcut) isEqual:shortcut_title(shortcut)])) self->_voice = v;
        [self setTitle:self->_voice ? [NSString stringWithFormat:@"“%@”", self->_voice.invocationPhrase] : NSLocalizedString(@"Add to Siri", nil) forState:UIControlStateNormal];
    }];
}
- (void)_tapped {
    if (!_shortcut) return;
    if (_voice) [self.delegate presentEditVoiceShortcutViewController:[[INUIEditVoiceShortcutViewController alloc] initWithVoiceShortcut:_voice] forAddVoiceShortcutButton:self];
    else [self.delegate presentAddVoiceShortcutViewController:[[INUIAddVoiceShortcutViewController alloc] initWithShortcut:_shortcut] forAddVoiceShortcutButton:self];
}
@end

@implementation NSExtensionContext (INUIHostedViewControlling)
- (CGSize)hostedViewMinimumAllowedSize { return CGSizeMake(UIScreen.mainScreen.bounds.size.width - 32, 0); }
- (CGSize)hostedViewMaximumAllowedSize { return CGSizeMake(UIScreen.mainScreen.bounds.size.width - 32, 400); }
@end

/* ---------------- Intents UI extensions (helper processes) ---------------- */
@interface __IsimIntentsUIExtensionHost : UIResponder <UIApplicationDelegate>
@property (nonatomic, strong) UIWindow *window;
@end
@implementation __IsimIntentsUIExtensionHost
static void finish_ui(NSDictionary *result, NSString *out) {
    [result writeToFile:out atomically:YES];
    fflush(NULL);
    dispatch_async(dispatch_get_main_queue(), ^{ exit(0); });
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    const char *rp = getenv("ISIM_EXTENSION_REQUEST");
    NSDictionary *req = rp ? [NSDictionary dictionaryWithContentsOfFile:@(rp)] : nil;
    NSString *out = req[@"out"];
    if (!req || !out) { NSLog(@"isim: Intents UI extension started without a request (ISIM_EXTENSION_REQUEST)"); exit(2); }
    NSDictionary *ext = NSBundle.mainBundle.infoDictionary[@"NSExtension"];
    UIViewController *vc = nil;
    Class cls = NSClassFromString(ext[@"NSExtensionPrincipalClass"] ?: @"");
    if ([cls isSubclassOfClass:[UIViewController class]]) vc = [cls new];
    else if ([ext[@"NSExtensionMainStoryboard"] length]) vc = [[UIStoryboard storyboardWithName:ext[@"NSExtensionMainStoryboard"] bundle:NSBundle.mainBundle] instantiateInitialViewController];
    INInteraction *interaction = isim_in_decode(req[@"interaction"]);
    if (!vc || ![interaction isKindOfClass:[INInteraction class]]) {
        NSLog(@"isim: Intents UI extension: %@", vc ? @"no interaction" : @"no view controller (NSExtensionPrincipalClass / NSExtensionMainStoryboard)");
        finish_ui(@{ @"error": @"failed" }, out); return YES;
    }
    CGFloat width = [req[@"width"] doubleValue] ?: UIScreen.mainScreen.bounds.size.width - 32;
    self.window = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, width, 200)];
    self.window.rootViewController = vc;
    [self.window makeKeyAndVisible];
    INUIInteractiveBehavior behavior = [req[@"confirm"] boolValue] ? INUIInteractiveBehaviorNone : INUIInteractiveBehaviorLaunch;
    void (^render)(CGSize) = ^(CGSize size) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGFloat h = size.height > 0 ? MIN(size.height, 400) : (vc.preferredContentSize.height > 0 ? vc.preferredContentSize.height : 120);
            self.window.frame = CGRectMake(0, 0, width, h); vc.view.frame = self.window.bounds;
            [vc.view setNeedsLayout]; [vc.view layoutIfNeeded];
            UIGraphicsBeginImageContextWithOptions(CGSizeMake(width, h), NO, UIScreen.mainScreen.scale ?: 3);
            [vc.view drawViewHierarchyInRect:CGRectMake(0, 0, width, h) afterScreenUpdates:YES];
            UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            NSString *png = [out.stringByDeletingPathExtension stringByAppendingPathExtension:@"png"];
            [UIImagePNGRepresentation(img) writeToFile:png atomically:YES];
            NSLog(@"isim: Intents UI extension rendered %.0f x %.0f", width, h);
            BOOL message = [vc respondsToSelector:@selector(displaysMessage)] && [(id<INUIHostedViewSiriProviding>)vc displaysMessage];
            finish_ui(@{ @"image": png, @"width": @(width), @"height": @(h), @"displaysMessage": @(message) }, out);
        });
    };
    if ([vc respondsToSelector:@selector(configureViewForParameters:ofInteraction:interactiveBehavior:context:completion:)]) {
        [(id<INUIHostedViewControlling>)vc configureViewForParameters:[NSSet set] ofInteraction:interaction interactiveBehavior:behavior context:INUIHostedViewContextSiriSnippet
                                                           completion:^(BOOL ok, NSSet *params, CGSize size) {
            if (!ok) { NSLog(@"isim: Intents UI extension declined the interaction"); finish_ui(@{ @"declined": @YES }, out); return; }
            render(size);
        }];
    } else if ([vc respondsToSelector:@selector(configureWithInteraction:context:completion:)]) {
        [(id<INUIHostedViewControlling>)vc configureWithInteraction:interaction context:INUIHostedViewContextSiriSnippet completion:^(CGSize size) { render(size); }];
    } else { NSLog(@"isim: Intents UI extension: the view controller does not implement INUIHostedViewControlling"); finish_ui(@{ @"error": @"failed" }, out); }
    return YES;
}
@end
int isim_inui_extension_main(int argc, char **argv) {
    return UIApplicationMain(argc, argv, nil, @"__IsimIntentsUIExtensionHost");
}
