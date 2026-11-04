/* UIResponder members from the documentation sweep (#9): input view controllers and reloadInputViews (UIKeyboard.m
 * reads them), the text input mode and context identifiers, the input assistant item, remote control events.
 *
 * Remote control events (adapted): after beginReceivingRemoteControlEvents, the script command `remote
 * play|pause|toggle|next|previous|seekforward|seekback [0]` reaches remoteControlReceived(with:) of the first
 * responder (then up its chain; without one, the key window's visible view controller). An app whose
 * MPRemoteCommandCenter has targets gets them there instead, as on iOS. */
#import "UIKitPrivate.h"
#import <UIKit/UIResponderExtras.h>
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

/* iPadOS's shortcuts (adapted, issue #179): until the app sets them, an editable text responder's groups are the
   system's, undo / redo / paste on the leading side and, in a text view that allows editing text attributes, bold /
   italic / underline on the trailing side. Each item acts on the responder; undo / redo / paste are disabled when there
   is nothing to undo, redo or paste. Setting the groups (an empty array removes them) replaces the system's. */
static UIBarButtonItem *shortcut(NSString *ident, NSString *symbol, BOOL enabled, void (^act)(void)) {
    UIBarButtonItem *it = [[UIBarButtonItem alloc] initWithPrimaryAction:[UIAction actionWithTitle:@"" image:[UIImage systemImageNamed:symbol]
                                                                                       identifier:nil handler:^(UIAction *a) { act(); }]];
    it.accessibilityIdentifier = ident;
    it.enabled = enabled;
    return it;
}
static BOOL editable_text(UIResponder *r) {
    if (![r conformsToProtocol:@protocol(UITextInput)]) return NO;
    if ([r isKindOfClass:[UITextView class]] && !((UITextView *)r).editable) return NO;
    return YES;
}
@implementation UITextInputAssistantItem {
    BOOL _setLeading, _setTrailing;
    @public __weak UIResponder *_owner;
}
@synthesize leadingBarButtonGroups = _leadingBarButtonGroups, trailingBarButtonGroups = _trailingBarButtonGroups;
- (instancetype)init {
    if ((self = [super init])) { _leadingBarButtonGroups = @[]; _trailingBarButtonGroups = @[]; _allowsHidingShortcuts = YES; }
    return self;
}
- (NSArray<UIBarButtonItemGroup *> *)leadingBarButtonGroups {
    if (_setLeading) return _leadingBarButtonGroups;
    __weak UIResponder *r = _owner;
    if (!r || !editable_text(r) || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return @[];
    NSUndoManager *um = r.undoManager;
    BOOL paste = UIPasteboard.generalPasteboard.hasStrings && [r canPerformAction:@selector(paste:) withSender:nil];
    NSArray *items = @[
        shortcut(@"undo", @"arrow.uturn.backward", um.canUndo, ^{ NSLog(@"isim: shortcuts bar undo"); [r.undoManager undo]; }),
        shortcut(@"redo", @"arrow.uturn.forward", um.canRedo, ^{ NSLog(@"isim: shortcuts bar redo"); [r.undoManager redo]; }),
        shortcut(@"paste", @"doc.on.clipboard", paste, ^{ NSLog(@"isim: shortcuts bar paste"); [r paste:nil]; }),
    ];
    return @[[[UIBarButtonItemGroup alloc] initWithBarButtonItems:items representativeItem:nil]];
}
- (NSArray<UIBarButtonItemGroup *> *)trailingBarButtonGroups {
    if (_setTrailing) return _trailingBarButtonGroups;
    __weak UIResponder *r = _owner;
    if (![r isKindOfClass:[UITextView class]] || !((UITextView *)r).allowsEditingTextAttributes || !editable_text(r)
        || UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return @[];
    NSArray *items = @[
        shortcut(@"bold", @"bold", YES, ^{ NSLog(@"isim: shortcuts bar bold"); [r toggleBoldface:nil]; }),
        shortcut(@"italic", @"italic", YES, ^{ NSLog(@"isim: shortcuts bar italic"); [r toggleItalics:nil]; }),
        shortcut(@"underline", @"underline", YES, ^{ NSLog(@"isim: shortcuts bar underline"); [r toggleUnderline:nil]; }),
    ];
    return @[[[UIBarButtonItemGroup alloc] initWithBarButtonItems:items representativeItem:nil]];
}
- (void)setLeadingBarButtonGroups:(NSArray *)g { _setLeading = YES; _leadingBarButtonGroups = [g copy] ?: @[]; isim_ui_keyboard_assistant_changed(); }
- (void)setTrailingBarButtonGroups:(NSArray *)g { _setTrailing = YES; _trailingBarButtonGroups = [g copy] ?: @[]; isim_ui_keyboard_assistant_changed(); }
- (void)setAllowsHidingShortcuts:(BOOL)a { _allowsHidingShortcuts = a; isim_ui_keyboard_assistant_changed(); }
@end

static char kAssistant;
static NSString *const kContexts = @"_IsimTextInputContextIdentifiers";
@implementation UIResponder (IsimResponderExtras)
- (void)touchesEstimatedPropertiesUpdated:(NSSet *)touches {}
- (void)remoteControlReceivedWithEvent:(UIEvent *)event { [self.nextResponder remoteControlReceivedWithEvent:event]; }
- (UIInputViewController *)inputViewController { return nil; }
- (UIInputViewController *)inputAccessoryViewController { return nil; }
- (void)reloadInputViews { if (self.isFirstResponder) isim_ui_keyboard_reload(self); }
- (UITextInputMode *)textInputMode {
    if (isim_ui_keyboard_target() != self) return nil;
    NSString *lang = [isim_ui_keyboard_current_language() stringByReplacingOccurrencesOfString:@"_" withString:@"-"];
    for (UITextInputMode *m in UITextInputMode.activeInputModes) if ([m.primaryLanguage isEqualToString:lang]) return m;
    return UITextInputMode.activeInputModes.firstObject;
}
- (NSString *)textInputContextIdentifier { return nil; }
+ (void)clearTextInputContextIdentifier:(NSString *)identifier {
    NSMutableDictionary *d = [[NSUserDefaults.standardUserDefaults dictionaryForKey:kContexts] mutableCopy];
    if (!d[identifier]) return;
    [d removeObjectForKey:identifier];
    [NSUserDefaults.standardUserDefaults setObject:d forKey:kContexts];
}
- (UITextInputAssistantItem *)inputAssistantItem {
    UITextInputAssistantItem *i = get(self, &kAssistant);
    if (!i) { i = [UITextInputAssistantItem new]; i->_owner = self; put(self, &kAssistant, i); }
    return i;
}
- (UIEditingInteractionConfiguration)editingInteractionConfiguration { return UIEditingInteractionConfigurationDefault; }
@end

/* the keyboard last used for a context identifier (UIKeyboard.m) */
NSString *isim_ui_keyboard_for_context(NSString *identifier) {
    return identifier.length ? [NSUserDefaults.standardUserDefaults dictionaryForKey:kContexts][identifier] : nil;
}
void isim_ui_keyboard_remember_context(NSString *identifier, NSString *keyboard) {
    if (!identifier.length || !keyboard.length) return;
    NSMutableDictionary *d = [[NSUserDefaults.standardUserDefaults dictionaryForKey:kContexts] mutableCopy] ?: [NSMutableDictionary dictionary];
    if ([d[identifier] isEqualToString:keyboard]) return;
    d[identifier] = keyboard;
    [NSUserDefaults.standardUserDefaults setObject:d forKey:kContexts];
}

/* ---- remote control events ---- */
@interface __IsimRemoteEvent : UIEvent
@property (nonatomic) UIEventSubtype isimSubtype;
@end
@implementation __IsimRemoteEvent
- (UIEventType)type { return UIEventTypeRemoteControl; }
- (UIEventSubtype)subtype { return _isimSubtype; }
- (NSTimeInterval)timestamp { return isim_time(); }
@end
extern int isim_remote_command_poll(char *buf, int len);
static NSTimer *remote_timer;
static BOOL command_center_active;
static UIEventSubtype remote_subtype(NSString *line) {
    NSArray *p = [line componentsSeparatedByString:@" "];
    NSString *n = [p.firstObject lowercaseString];
    BOOL end = p.count > 1 && [p[1] doubleValue] == 0 && [p[1] length];
    NSDictionary *m = @{ @"play": @(UIEventSubtypeRemoteControlPlay), @"pause": @(UIEventSubtypeRemoteControlPause), @"stop": @(UIEventSubtypeRemoteControlStop),
                         @"toggle": @(UIEventSubtypeRemoteControlTogglePlayPause), @"next": @(UIEventSubtypeRemoteControlNextTrack),
                         @"previous": @(UIEventSubtypeRemoteControlPreviousTrack),
                         @"seekback": @(end ? UIEventSubtypeRemoteControlEndSeekingBackward : UIEventSubtypeRemoteControlBeginSeekingBackward),
                         @"seekforward": @(end ? UIEventSubtypeRemoteControlEndSeekingForward : UIEventSubtypeRemoteControlBeginSeekingForward) };
    return [m[n] integerValue];
}
static void remote_poll(void) {
    if (command_center_active || !isim_ui_receiving_remote_events()) return;
    char buf[64];
    while (isim_remote_command_poll(buf, sizeof buf)) {
        NSString *line = [@(buf) stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        UIEventSubtype st = remote_subtype(line);
        if (!st) { NSLog(@"isim: remote control '%@' has no UIEvent subtype", line); continue; }
        __IsimRemoteEvent *e = [__IsimRemoteEvent new]; e.isimSubtype = st;
        UIResponder *r = isim_ui_focus_responder();
        NSLog(@"isim: remote control event %ld to %@", (long)st, r ? NSStringFromClass(r.class) : @"nobody");
        [r remoteControlReceivedWithEvent:e];
    }
}
void isim_ui_remote_events_started(void) {
    static BOOL observing;
    if (!observing) {
        observing = YES;
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimRemoteCommandCenterActive" object:nil queue:nil usingBlock:^(NSNotification *n) {
            command_center_active = YES; [remote_timer invalidate]; remote_timer = nil;
        }];
    }
    if (remote_timer || command_center_active) return;
    remote_timer = [NSTimer scheduledTimerWithTimeInterval:0.1 repeats:YES block:^(NSTimer *t) { remote_poll(); }];
}
