/* Menus and commands from the documentation sweep (#9): UICommand / UICommandAlternate, UIAction as a menu leaf,
 * UIMenu extras (identifiers, replacing children, selected elements, element size, display preferences), deferred
 * elements, the menu builder and the main / context menu systems.
 *
 * The main menu (adapted): iOS builds it for the iPad menu bar and the keyboard shortcuts overlay. isim builds the
 * standard menus (the application, File, Edit, Format, View, Window and Help menus, shaped by
 * UIMainMenuSystem.Configuration), runs the build handler and then buildMenu(with:) from the application up its
 * responder chain (the app delegate). The app's key commands in it work from the hardware keyboard (the standard
 * items keep isim's own text editing shortcuts); validate(_:) is asked before a command runs or shows. On iPad,
 * holding Command shows the shortcuts overlay (the available commands with shortcuts, by menu); the script command
 * `mainmenu` logs the menu tree, `mainmenu show|hide` shows / hides the overlay. */
#import "UIKitPrivate.h"
#import <UIKit/UIMenuSystem.h>
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@interface __IsimMenuWeak : NSObject
@property (nonatomic, weak) id value;
@end
@implementation __IsimMenuWeak @end
static void put_weak(id o, const void *k, id v) { __IsimMenuWeak *w = [__IsimMenuWeak new]; w.value = v; put(o, k, v ? w : nil); }
static id get_weak(id o, const void *k) { return ((__IsimMenuWeak *)get(o, k)).value; }

/* ================= identifiers ================= */
UIActionIdentifier const UIActionPaste = @"com.apple.menu.paste";
UIActionIdentifier const UIActionPasteAndMatchStyle = @"com.apple.menu.paste-and-match-style";
UIActionIdentifier const UIActionPasteAndGo = @"com.apple.menu.paste-and-go";
UIActionIdentifier const UIActionPasteAndSearch = @"com.apple.menu.paste-and-search";
UIActionIdentifier const UIActionNewFromPasteboard = @"com.apple.menu.new-from-pasteboard";
const UIMenuIdentifier UIMenuApplication = @"com.apple.menu.application", UIMenuFile = @"com.apple.menu.file", UIMenuEdit = @"com.apple.menu.edit",
    UIMenuView = @"com.apple.menu.view", UIMenuWindow = @"com.apple.menu.window", UIMenuHelp = @"com.apple.menu.help",
    UIMenuAbout = @"com.apple.menu.about", UIMenuPreferences = @"com.apple.menu.preferences", UIMenuServices = @"com.apple.menu.services",
    UIMenuHide = @"com.apple.menu.hide", UIMenuQuit = @"com.apple.menu.quit", UIMenuNewItem = @"com.apple.menu.new-item",
    UIMenuOpen = @"com.apple.menu.open", UIMenuOpenRecent = @"com.apple.menu.open-recent", UIMenuClose = @"com.apple.menu.close",
    UIMenuPrint = @"com.apple.menu.print", UIMenuDocument = @"com.apple.menu.document", UIMenuUndoRedo = @"com.apple.menu.undo-redo",
    UIMenuStandardEdit = @"com.apple.menu.standard-edit", UIMenuFind = @"com.apple.menu.find", UIMenuFindPanel = @"com.apple.menu.find-panel",
    UIMenuReplace = @"com.apple.menu.replace", UIMenuShare = @"com.apple.menu.share", UIMenuTextStyle = @"com.apple.menu.text-style",
    UIMenuSpelling = @"com.apple.menu.spelling", UIMenuSpellingPanel = @"com.apple.menu.spelling-panel",
    UIMenuSpellingOptions = @"com.apple.menu.spelling-options", UIMenuSubstitutions = @"com.apple.menu.substitutions",
    UIMenuSubstitutionsPanel = @"com.apple.menu.substitutions-panel", UIMenuSubstitutionOptions = @"com.apple.menu.substitutions-options",
    UIMenuTransformations = @"com.apple.menu.transformations", UIMenuSpeech = @"com.apple.menu.speech", UIMenuLookup = @"com.apple.menu.lookup",
    UIMenuLearn = @"com.apple.menu.learn", UIMenuFormat = @"com.apple.menu.format", UIMenuFont = @"com.apple.menu.font",
    UIMenuTextSize = @"com.apple.menu.text-size", UIMenuTextColor = @"com.apple.menu.text-color",
    UIMenuTextStylePasteboard = @"com.apple.menu.text-style-pasteboard", UIMenuText = @"com.apple.menu.text",
    UIMenuWritingDirection = @"com.apple.menu.writing-direction", UIMenuAlignment = @"com.apple.menu.alignment",
    UIMenuToolbar = @"com.apple.menu.toolbar", UIMenuFullscreen = @"com.apple.menu.fullscreen",
    UIMenuMinimizeAndZoom = @"com.apple.menu.minimize-and-zoom", UIMenuBringAllToFront = @"com.apple.menu.bring-all-to-front",
    UIMenuRoot = @"com.apple.menu.root", UIMenuAutoFill = @"com.apple.menu.autofill", UIMenuSidebar = @"com.apple.menu.sidebar";
NSString *const UICommandTagShare = @"com.apple.menu.command.share";
static NSString *const kInspector = @"com.apple.menu.inspector", *const kNewScene = @"com.apple.menu.new-scene";

/* ================= where commands go ================= */
UIResponder *isim_ui_focus_responder(void);           /* UIGestures.m: the first responder, else the visible view controller */
/* the responder that performs an action: the first responder's chain (else the source view's, then the visible
   controller's) */
static id command_target(SEL action, id sender, UIView *source) {
    UIResponder *starts[3] = { isim_ui_first_responder(), source, isim_ui_focus_responder() };
    for (int i = 0; i < 3; i++) {
        id t = [starts[i] targetForAction:action withSender:sender];
        if (t) return t;
    }
    UIApplication *app = UIApplication.sharedApplication;
    if ([app canPerformAction:action withSender:sender]) return app;
    id d = app.delegate;
    if ([d respondsToSelector:action]) return d;
    return nil;
}
static void validate(UICommand *c, id target) { if ([target respondsToSelector:@selector(validateCommand:)]) [target validateCommand:c]; }

/* ================= UICommandAlternate ================= */
@implementation UICommandAlternate { NSString *_title; SEL _action; UIKeyModifierFlags _flags; }
+ (instancetype)alternateWithTitle:(NSString *)title action:(SEL)action modifierFlags:(UIKeyModifierFlags)flags {
    UICommandAlternate *a = [super new]; a->_title = [title copy] ?: @""; a->_action = action; a->_flags = flags; return a;
}
- (NSString *)title { return _title; }
- (SEL)action { return _action; }
- (UIKeyModifierFlags)modifierFlags { return _flags; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UICommandAlternate class]] && ((UICommandAlternate *)o)->_action == _action && ((UICommandAlternate *)o)->_flags == _flags; }
- (NSUInteger)hash { return (NSUInteger)(uintptr_t)sel_getName(_action) ^ _flags; }
@end

/* ================= UICommand ================= */
@implementation UICommand { SEL _action; id _propertyList; NSArray *_alternates; __weak id _sender, _sourceItem; }
@dynamic title, image;
- (id)sender { return _sender; }
- (id<UIPopoverPresentationControllerSourceItem>)presentationSourceItem { return _sourceItem; }
- (void)_isim_setPresentationSourceItem:(id)item { _sourceItem = item; }
+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)plist {
    return [self commandWithTitle:title image:image action:action propertyList:plist alternates:@[]];
}
+ (instancetype)commandWithTitle:(NSString *)title image:(UIImage *)image action:(SEL)action propertyList:(id)plist alternates:(NSArray *)alternates {
    UICommand *c = [self new]; c.title = title ?: @""; c.image = image; [c _isim_setAction:action propertyList:plist alternates:alternates]; return c;
}
- (void)_isim_setAction:(SEL)action propertyList:(id)plist alternates:(NSArray *)alternates { _action = action; _propertyList = plist; _alternates = [alternates copy] ?: @[]; }
- (SEL)action { return _action; }
- (id)propertyList { return _propertyList; }
- (NSArray *)alternates { return _alternates ?: @[]; }
- (void)performWithSender:(id)sender target:(id)target {
    _sender = sender;
    id t = target ?: command_target(_action, self, [sender isKindOfClass:[UIView class]] ? sender : nil);
    if (!t || !_action) { NSLog(@"isim: command %@: nothing performs %@", self.title, NSStringFromSelector(_action)); return; }
    validate(self, t);
    if (self.attributes & UIMenuElementAttributesDisabled) return;
    ((void (*)(id, SEL, id))[t methodForSelector:_action])(t, _action, self);
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %@ %@>", self.class, self.title, NSStringFromSelector(_action)]; }
@end

/* ================= UIAction as a menu leaf ================= */
static char kDiscoverability, kRepeat, kSourceItem, kIdentifier, kElementSize, kDisplayPrefs;
@implementation UIAction (UIMenuLeaf)
- (NSString *)discoverabilityTitle { return get(self, &kDiscoverability); }
- (void)setDiscoverabilityTitle:(NSString *)t { put(self, &kDiscoverability, [t copy]); }
- (UIMenuElementRepeatBehavior)repeatBehavior { return [get(self, &kRepeat) integerValue]; }
- (void)setRepeatBehavior:(UIMenuElementRepeatBehavior)r { put(self, &kRepeat, @(r)); }
- (id<UIPopoverPresentationControllerSourceItem>)presentationSourceItem { return get_weak(self, &kSourceItem); }
- (void)_isim_setPresentationSourceItem:(id)item { put_weak(self, &kSourceItem, item); }
- (void)performWithSender:(id)sender target:(id)target {
    [self setSender:sender];
    UIActionHandler h = self.handler;
    if (h) h(self);
}
+ (instancetype)captureTextFromCameraActionForResponder:(UIResponder<UIKeyInput> *)responder identifier:(UIActionIdentifier)identifier {
    __weak UIResponder *r = responder;
    UIAction *a = [self actionWithTitle:@"Scan Text" image:[UIImage systemImageNamed:@"text.viewfinder"] identifier:identifier handler:^(UIAction *x) {
        SEL s = NSSelectorFromString(@"captureTextFromCamera:");
        if ([r respondsToSelector:s]) ((void (*)(id, SEL, id))[r methodForSelector:s])(r, s, x);
        else NSLog(@"isim: Scan Text: the responder does not capture text from the camera");
    }];
    return a;
}
@end

/* ================= UIMenu extras ================= */
@implementation UIMenuDisplayPreferences
- (id)copyWithZone:(NSZone *)z { UIMenuDisplayPreferences *p = [UIMenuDisplayPreferences new]; p.maximumNumberOfTitleLines = _maximumNumberOfTitleLines; return p; }
@end
@implementation UIMenu (IsimMenuExtras)
- (UIMenuIdentifier)identifier {
    NSString *i = get(self, &kIdentifier);
    if (!i) { i = [@"com.apple.menu.dynamic." stringByAppendingString:NSUUID.UUID.UUIDString]; put(self, &kIdentifier, i); }
    return i;
}
- (void)_isim_setIdentifier:(NSString *)i { put(self, &kIdentifier, [i copy]); }
- (UIMenu *)menuByReplacingChildren:(NSArray *)children {
    UIMenu *m = [UIMenu menuWithTitle:self.title image:self.image identifier:self.identifier options:self.options children:children];
    m.subtitle = self.subtitle;
    put(m, &kElementSize, get(self, &kElementSize)); put(m, &kDisplayPrefs, get(self, &kDisplayPrefs));
    return m;
}
static void selected(UIMenu *m, NSMutableArray *out) {
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIMenu class]]) { if (((UIMenu *)e).options & UIMenuOptionsDisplayInline) selected((UIMenu *)e, out); }
        else if (isim_ui_element_state(e) == UIMenuElementStateOn) [out addObject:e];
    }
}
- (NSArray *)selectedElements { NSMutableArray *a = [NSMutableArray array]; selected(self, a); return a; }
- (UIMenuElementSize)preferredElementSize { NSNumber *n = get(self, &kElementSize); return n ? n.integerValue : UIMenuElementSizeLarge; }
- (void)setPreferredElementSize:(UIMenuElementSize)s { put(self, &kElementSize, @(s)); }
- (UIMenuDisplayPreferences *)displayPreferences { return get(self, &kDisplayPrefs); }
- (void)setDisplayPreferences:(UIMenuDisplayPreferences *)p { put(self, &kDisplayPrefs, [p copy]); }
@end

/* the menu leaf protocol over UIAction and UICommand */
UIMenuElementAttributes isim_ui_element_attributes(UIMenuElement *e) {
    if ([e isKindOfClass:[UIAction class]]) return ((UIAction *)e).attributes;
    if ([e isKindOfClass:[UICommand class]]) return ((UICommand *)e).attributes;
    return 0;
}
UIMenuElementState isim_ui_element_state(UIMenuElement *e) {
    if ([e isKindOfClass:[UIAction class]]) return ((UIAction *)e).state;
    if ([e isKindOfClass:[UICommand class]]) return ((UICommand *)e).state;
    return UIMenuElementStateOff;
}
/* a command in a menu: the responder that performs it may change it first (nil target: shown disabled) */
BOOL isim_ui_command_available(UICommand *c, UIView *source) {
    id t = command_target(c.action, c, source);
    if (t) validate(c, t);
    return t != nil;
}
/* a leaf chosen in a menu shown from `source` */
void isim_ui_perform_leaf(UIMenuElement *e, UIView *source) {
    if ([e respondsToSelector:@selector(_isim_setPresentationSourceItem:)]) [(id)e _isim_setPresentationSourceItem:source];
    if ([e isKindOfClass:[UICommand class]]) { [(UICommand *)e performWithSender:source target:nil]; return; }
    if ([e isKindOfClass:[UIAction class]]) [(UIAction *)e performWithSender:source target:nil];
}
/* "⌘N", "⇧⌘G", "⌥⌘F" */
NSString *isim_ui_shortcut_text(UIKeyCommand *c) {
    if (!c.input.length) return @"";
    NSMutableString *s = [NSMutableString string];
    UIKeyModifierFlags f = c.modifierFlags;
    if (f & UIKeyModifierControl) [s appendString:@"⌃"];
    if (f & UIKeyModifierAlternate) [s appendString:@"⌥"];
    if (f & UIKeyModifierShift) [s appendString:@"⇧"];
    if (f & UIKeyModifierCommand) [s appendString:@"⌘"];
    NSDictionary *names = @{ UIKeyInputUpArrow: @"↑", UIKeyInputDownArrow: @"↓", UIKeyInputLeftArrow: @"←", UIKeyInputRightArrow: @"→", UIKeyInputEscape: @"⎋",
                             @"\r": @"↩", @"\t": @"⇥", @" ": @"Space", @"\b": @"⌫", UIKeyInputDelete: @"⌦", UIKeyInputPageUp: @"⇞", UIKeyInputPageDown: @"⇟",
                             UIKeyInputHome: @"↖", UIKeyInputEnd: @"↘" };
    [s appendString:names[c.input] ?: c.input.uppercaseString];
    return s;
}

/* ================= deferred elements ================= */
typedef void (^IsimElementProvider)(void (^)(NSArray<UIMenuElement *> *));
@implementation UIDeferredMenuElementProvider { IsimElementProvider _block; }
+ (instancetype)providerWithElementProvider:(IsimElementProvider)block { UIDeferredMenuElementProvider *p = [super new]; p->_block = [block copy]; return p; }
- (IsimElementProvider)_isim_block { return _block; }
@end
@implementation UIDeferredMenuElement { IsimElementProvider _provider; BOOL _cached, _loading; NSArray *_elements; NSString *_identifier; NSUInteger _generation; }
+ (instancetype)_isim_with:(IsimElementProvider)p cached:(BOOL)cached {
    UIDeferredMenuElement *d = [self new]; d->_provider = [p copy]; d->_cached = cached; return d;
}
+ (instancetype)elementWithProvider:(IsimElementProvider)p { return [self _isim_with:p cached:YES]; }
+ (instancetype)elementWithUncachedProvider:(IsimElementProvider)p { return [self _isim_with:p cached:NO]; }
+ (instancetype)elementUsingFocusWithIdentifier:(UIDeferredMenuElementIdentifier)identifier shouldCacheItems:(BOOL)cache {
    UIDeferredMenuElement *d = [self _isim_with:nil cached:cache]; d->_identifier = [identifier copy]; return d;
}
- (UIDeferredMenuElementIdentifier)identifier { return _identifier; }
/* a menu shows: an uncached element asks again */
- (void)_isim_menuWillShow { if (!_cached) { _elements = nil; _loading = NO; _generation++; } }
/* the elements to show (nil while loading: the menu shows "Loading…" and `reload` once they come) */
- (NSArray *)_isim_elementsReloading:(void (^)(void))reload {
    if (_elements) return _elements;
    if (_loading) return nil;
    IsimElementProvider p = _provider;
    if (!p) {                                            /* focus-based: the responder chain from the first responder */
        for (UIResponder *r = isim_ui_focus_responder(); r && !p; r = r.nextResponder)
            p = [[r providerForDeferredMenuElement:self] _isim_block];
        if (!p) { _elements = @[]; return _elements; }
    }
    _loading = YES;
    NSUInteger gen = _generation;
    __weak UIDeferredMenuElement *ws = self;
    void (^reloadCopy)(void) = [reload copy];
    p(^(NSArray *elements) {
        dispatch_block_t done = ^{
            UIDeferredMenuElement *s = ws;
            if (!s || s->_generation != gen) return;
            s->_elements = [elements copy] ?: @[]; s->_loading = NO;
            NSLog(@"isim: deferred menu element loaded %lu element(s)", (unsigned long)s->_elements.count);
            if (reloadCopy) reloadCopy();
        };
        dispatch_async(dispatch_get_main_queue(), done);       /* after the menu is up, even when the provider answers at once */
    });
    return _elements;
}
@end
void isim_ui_menu_will_show(UIMenu *m) {
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIDeferredMenuElement class]]) [(UIDeferredMenuElement *)e _isim_menuWillShow];
        else if ([e isKindOfClass:[UIMenu class]]) isim_ui_menu_will_show((UIMenu *)e);
    }
}

/* ================= responders ================= */
@implementation UIResponder (UIMenuBuilding)
- (void)buildMenuWithBuilder:(id<UIMenuBuilder>)builder { [self.nextResponder buildMenuWithBuilder:builder]; }
- (void)validateCommand:(UICommand *)command {}
- (UIDeferredMenuElementProvider *)providerForDeferredMenuElement:(UIDeferredMenuElement *)e { return nil; }
@end

/* ================= the builder ================= */
/* rewrites a menu tree bottom-up: `edit` may change a menu's (already rewritten) children; YES when it did */
static UIMenu *rewrite(UIMenu *m, BOOL (^edit)(UIMenu *menu, NSMutableArray *children)) {
    NSMutableArray *kids = [NSMutableArray arrayWithCapacity:m.children.count];
    BOOL changed = NO;
    for (UIMenuElement *e in m.children) {
        UIMenuElement *n = [e isKindOfClass:[UIMenu class]] ? rewrite((UIMenu *)e, edit) : e;
        changed |= n != e;
        [kids addObject:n];
    }
    changed |= edit(m, kids);
    return changed ? [m menuByReplacingChildren:kids] : m;
}
static UIMenu *find_menu(UIMenu *m, NSString *ident) {
    if ([m.identifier isEqualToString:ident]) return m;
    for (UIMenuElement *e in m.children) if ([e isKindOfClass:[UIMenu class]]) { UIMenu *f = find_menu((UIMenu *)e, ident); if (f) return f; }
    return nil;
}
static UIMenuElement *find_leaf(UIMenu *m, BOOL (^match)(UIMenuElement *)) {
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIMenu class]]) { UIMenuElement *f = find_leaf((UIMenu *)e, match); if (f) return f; }
        else if (match(e)) return e;
    }
    return nil;
}
typedef BOOL (^IsimMatch)(UIMenuElement *);
static IsimMatch menu_match(NSString *ident) { return ^BOOL(UIMenuElement *e) { return [e isKindOfClass:[UIMenu class]] && [((UIMenu *)e).identifier isEqualToString:ident]; }; }
static IsimMatch action_match(NSString *ident) { return ^BOOL(UIMenuElement *e) { return [e isKindOfClass:[UIAction class]] && [((UIAction *)e).identifier isEqualToString:ident]; }; }
static IsimMatch command_match(SEL action, id plist) {
    return ^BOOL(UIMenuElement *e) {
        if (![e isKindOfClass:[UICommand class]] || ((UICommand *)e).action != action) return NO;
        id p = ((UICommand *)e).propertyList;
        return p == plist || [p isEqual:plist];
    };
}

@interface __IsimMenuBuilder : NSObject <UIMenuBuilder>
@property (nonatomic, strong) UIMenu *root;
@property (nonatomic, strong) UIMenuSystem *system;
@end
@implementation __IsimMenuBuilder
/* replaces (or inserts next to) the first element `match` finds: where 0 replace, -1 before, 1 after */
- (void)_at:(IsimMatch)match where:(int)where elements:(NSArray *)elements {
    __block BOOL done = NO;
    self.root = rewrite(self.root, ^BOOL(UIMenu *menu, NSMutableArray *kids) {
        if (done) return NO;
        for (NSUInteger i = 0; i < kids.count; i++) {
            if (!match(kids[i])) continue;
            done = YES;
            NSIndexSet *at = [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(where > 0 ? i + 1 : i, elements.count)];
            if (where == 0) [kids removeObjectAtIndex:i];
            [kids insertObjects:elements atIndexes:at];
            return YES;
        }
        return NO;
    });
}
- (void)_inMenu:(NSString *)ident edit:(NSArray *(^)(NSArray *))edit {
    self.root = rewrite(self.root, ^BOOL(UIMenu *menu, NSMutableArray *kids) {
        if (![menu.identifier isEqualToString:ident]) return NO;
        NSArray *n = edit([kids copy]) ?: @[];
        [kids setArray:n];
        return YES;
    });
}
- (UIMenu *)menuForIdentifier:(UIMenuIdentifier)i { return find_menu(self.root, i); }
- (UIAction *)actionForIdentifier:(UIActionIdentifier)i { return (UIAction *)find_leaf(self.root, action_match(i)); }
- (UICommand *)commandForAction:(SEL)a propertyList:(id)p { return (UICommand *)find_leaf(self.root, command_match(a, p)); }
- (void)replaceMenuForIdentifier:(UIMenuIdentifier)i withMenu:(UIMenu *)m {
    if ([self.root.identifier isEqualToString:i]) { self.root = m; return; }
    [self _at:menu_match(i) where:0 elements:@[ m ]];
}
- (void)replaceChildrenOfMenuForIdentifier:(UIMenuIdentifier)i fromChildrenBlock:(NSArray *(NS_NOESCAPE ^)(NSArray *))block { [self _inMenu:i edit:block]; }
- (void)insertSiblingMenu:(UIMenu *)m beforeMenuForIdentifier:(UIMenuIdentifier)i { [self _at:menu_match(i) where:-1 elements:@[ m ]]; }
- (void)insertSiblingMenu:(UIMenu *)m afterMenuForIdentifier:(UIMenuIdentifier)i { [self _at:menu_match(i) where:1 elements:@[ m ]]; }
- (void)insertChildMenu:(UIMenu *)m atStartOfMenuForIdentifier:(UIMenuIdentifier)i { [self insertElements:@[ m ] atStartOfMenuForIdentifier:i]; }
- (void)insertChildMenu:(UIMenu *)m atEndOfMenuForIdentifier:(UIMenuIdentifier)i { [self insertElements:@[ m ] atEndOfMenuForIdentifier:i]; }
- (void)removeMenuForIdentifier:(UIMenuIdentifier)i { [self _at:menu_match(i) where:0 elements:@[]]; }
- (void)replaceMenuForIdentifier:(UIMenuIdentifier)i withElements:(NSArray *)e { [self _at:menu_match(i) where:0 elements:e]; }
- (void)replaceActionForIdentifier:(UIActionIdentifier)i withElements:(NSArray *)e { [self _at:action_match(i) where:0 elements:e]; }
- (void)insertElements:(NSArray *)e atStartOfMenuForIdentifier:(UIMenuIdentifier)i { [self _inMenu:i edit:^NSArray *(NSArray *k) { return [e arrayByAddingObjectsFromArray:k]; }]; }
- (void)insertElements:(NSArray *)e atEndOfMenuForIdentifier:(UIMenuIdentifier)i { [self _inMenu:i edit:^NSArray *(NSArray *k) { return [k arrayByAddingObjectsFromArray:e]; }]; }
- (void)insertElements:(NSArray *)e beforeMenuForIdentifier:(UIMenuIdentifier)i { [self _at:menu_match(i) where:-1 elements:e]; }
- (void)insertElements:(NSArray *)e afterMenuForIdentifier:(UIMenuIdentifier)i { [self _at:menu_match(i) where:1 elements:e]; }
- (void)insertElements:(NSArray *)e beforeActionForIdentifier:(UIActionIdentifier)i { [self _at:action_match(i) where:-1 elements:e]; }
- (void)insertElements:(NSArray *)e afterActionForIdentifier:(UIActionIdentifier)i { [self _at:action_match(i) where:1 elements:e]; }
- (void)insertElements:(NSArray *)e beforeCommandForAction:(SEL)a propertyList:(id)p { [self _at:command_match(a, p) where:-1 elements:e]; }
- (void)insertElements:(NSArray *)e afterCommandForAction:(SEL)a propertyList:(id)p { [self _at:command_match(a, p) where:1 elements:e]; }
@end

/* ================= menu systems ================= */
@implementation UIMenuSystemFindElementGroupConfiguration
- (id)copyWithZone:(NSZone *)z { UIMenuSystemFindElementGroupConfiguration *c = [[self class] new]; c.style = _style; return c; }
@end
@implementation UIMainMenuSystemConfiguration
- (instancetype)init { if ((self = [super init])) _findingConfiguration = [UIMenuSystemFindElementGroupConfiguration new]; return self; }
- (id)copyWithZone:(NSZone *)z {
    UIMainMenuSystemConfiguration *c = [[self class] new];
    c.newScenePreference = _newScenePreference; c.documentPreference = _documentPreference; c.printingPreference = _printingPreference;
    c.findingPreference = _findingPreference; c.toolbarPreference = _toolbarPreference; c.sidebarPreference = _sidebarPreference;
    c.inspectorPreference = _inspectorPreference; c.textFormattingPreference = _textFormattingPreference; c.findingConfiguration = _findingConfiguration;
    return c;
}
@end

@interface UIMenuSystem ()
- (instancetype)initIsimSystem;
@end
@implementation UIMenuSystem { @package BOOL _built; BOOL _revalidate; }
- (instancetype)initIsimSystem { return [super init]; }
+ (UIMenuSystem *)mainSystem { return UIMainMenuSystem.sharedSystem; }
+ (UIMenuSystem *)contextSystem { return UIContextMenuSystem.sharedSystem; }
- (void)setNeedsRebuild { _built = NO; NSLog(@"isim: %@ menu system needs a rebuild", self == UIMenuSystem.mainSystem ? @"main" : @"context"); }
- (void)setNeedsRevalidate { _revalidate = YES; }
@end
@implementation UIContextMenuSystem
+ (UIContextMenuSystem *)sharedSystem { static UIContextMenuSystem *s; if (!s) s = [[self alloc] initIsimSystem]; return s; }
@end

@interface UIMainMenuSystem ()
@property (nonatomic, strong) UIMenu *menu;
@property (nonatomic, copy) UIMainMenuSystemConfiguration *configuration;
@property (nonatomic, copy) void (^buildHandler)(id<UIMenuBuilder>);
@end
@implementation UIMainMenuSystem
+ (UIMainMenuSystem *)sharedSystem { static UIMainMenuSystem *s; if (!s) s = [[self alloc] initIsimSystem]; return s; }
- (instancetype)initIsimSystem { if ((self = [super initIsimSystem])) _configuration = [UIMainMenuSystemConfiguration new]; return self; }
- (void)setBuildConfiguration:(UIMainMenuSystemConfiguration *)configuration buildHandler:(void (^)(id<UIMenuBuilder>))handler {
    self.configuration = configuration; self.buildHandler = handler;
    [self setNeedsRebuild];
}
@end

static UIMenu *menu_with(NSString *title, NSString *ident, UIMenuOptions options, NSArray *children) {
    return [UIMenu menuWithTitle:title image:nil identifier:ident options:options children:children];
}
static UIMenu *group(NSString *ident, NSArray *children) { return menu_with(@"", ident, UIMenuOptionsDisplayInline, children); }
static char kStandard;
static UIKeyCommand *key(NSString *title, NSString *action, NSString *input, UIKeyModifierFlags flags) {
    UIKeyCommand *c = [UIKeyCommand commandWithTitle:title image:nil action:NSSelectorFromString(action) input:input modifierFlags:flags propertyList:nil];
    put(c, &kStandard, @YES);
    return c;
}
static UICommand *command(NSString *title, NSString *action) {
    UICommand *c = [UICommand commandWithTitle:title image:nil action:NSSelectorFromString(action) propertyList:nil];
    put(c, &kStandard, @YES);
    return c;
}
static BOOL included(UIMenuSystemElementGroupPreference p, BOOL automatic) { return p == UIMenuSystemElementGroupPreferenceIncluded || (p == UIMenuSystemElementGroupPreferenceAutomatic && automatic); }
/* the standard menus, shaped by the configuration */
static UIMenu *standard_menu(UIMainMenuSystemConfiguration *cfg) {
    NSString *app = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"] ?: NSBundle.mainBundle.infoDictionary[@"CFBundleName"] ?: @"App";
    const UIKeyModifierFlags cmd = UIKeyModifierCommand, shift = UIKeyModifierShift, alt = UIKeyModifierAlternate, ctrl = UIKeyModifierControl;
    NSArray *appMenu = @[ group(UIMenuAbout, @[ command([@"About " stringByAppendingString:app], @"orderFrontStandardAboutPanel:") ]),
                          group(UIMenuPreferences, @[ key(@"Settings…", @"orderFrontPreferencesPanel:", @",", cmd) ]),
                          group(UIMenuServices, @[]),
                          group(UIMenuHide, @[ key([@"Hide " stringByAppendingString:app], @"hide:", @"h", cmd) ]),
                          group(UIMenuQuit, @[ key([@"Quit " stringByAppendingString:app], @"terminate:", @"q", cmd) ]) ];
    NSMutableArray *file = [NSMutableArray array];
    BOOL multi = [NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"][@"UIApplicationSupportsMultipleScenes"] boolValue];
    if (included(cfg.newScenePreference, multi)) [file addObject:group(kNewScene, @[ key(@"New Window", @"_isim_newScene:", @"n", cmd | alt) ])];
    [file addObject:group(UIMenuNewItem, @[])];
    [file addObject:group(UIMenuOpen, @[])];
    if (included(cfg.documentPreference, NO))
        [file addObject:group(UIMenuDocument, @[ command(@"Duplicate", @"duplicate:"), command(@"Move…", @"move:"), command(@"Rename…", @"rename:"), command(@"Export…", @"export:") ])];
    [file addObject:group(UIMenuClose, @[ key(@"Close", @"_isim_closeScene:", @"w", cmd) ])];
    if (included(cfg.printingPreference, YES)) [file addObject:group(UIMenuPrint, @[ key(@"Print…", @"printContent:", @"p", cmd) ])];
    NSMutableArray *edit = [@[ group(UIMenuUndoRedo, @[ key(@"Undo", @"undo:", @"z", cmd), key(@"Redo", @"redo:", @"z", cmd | shift) ]),
                               group(UIMenuStandardEdit, @[ key(@"Cut", @"cut:", @"x", cmd), key(@"Copy", @"copy:", @"c", cmd), key(@"Paste", @"paste:", @"v", cmd),
                                                            key(@"Paste and Match Style", @"pasteAndMatchStyle:", @"v", cmd | alt | shift),
                                                            command(@"Delete", @"delete:"), key(@"Select All", @"selectAll:", @"a", cmd) ]) ] mutableCopy];
    if (included(cfg.findingPreference, YES)) {
        UIMenuSystemFindElementGroupConfigurationStyle st = cfg.findingConfiguration.style;
        NSMutableArray *find = [NSMutableArray arrayWithObject:key(@"Find…", @"find:", @"f", cmd)];
        if (st != UIMenuSystemFindElementGroupConfigurationStyleSearch) {
            if (st != UIMenuSystemFindElementGroupConfigurationStyleNonEditableText) [find addObject:key(@"Find and Replace…", @"findAndReplace:", @"f", cmd | alt)];
            [find addObjectsFromArray:@[ key(@"Find Next", @"findNext:", @"g", cmd), key(@"Find Previous", @"findPrevious:", @"g", cmd | shift),
                                         key(@"Use Selection for Find", @"useSelectionForFind:", @"e", cmd) ]];
        }
        [edit addObject:menu_with(@"Find", UIMenuFind, 0, find)];
    }
    [edit addObject:menu_with(@"Spelling and Grammar", UIMenuSpelling, 0, @[])];
    [edit addObject:menu_with(@"Substitutions", UIMenuSubstitutions, 0, @[])];
    [edit addObject:menu_with(@"Transformations", UIMenuTransformations, 0, @[ command(@"Make Upper Case", @"uppercaseWord:"),
                                                                                  command(@"Make Lower Case", @"lowercaseWord:"), command(@"Capitalize", @"capitalizeWord:") ])];
    [edit addObject:menu_with(@"Speech", UIMenuSpeech, 0, @[])];
    NSMutableArray *top = [NSMutableArray arrayWithObjects:menu_with(app, UIMenuApplication, 0, appMenu), menu_with(@"File", UIMenuFile, 0, file),
                                                           menu_with(@"Edit", UIMenuEdit, 0, edit), nil];
    if (included(cfg.textFormattingPreference, YES))
        [top addObject:menu_with(@"Format", UIMenuFormat, 0, @[
            menu_with(@"Font", UIMenuFont, 0, @[ group(UIMenuTextStyle, @[ key(@"Bold", @"toggleBoldface:", @"b", cmd), key(@"Italic", @"toggleItalics:", @"i", cmd),
                                                                           key(@"Underline", @"toggleUnderline:", @"u", cmd) ]),
                                                 group(UIMenuTextSize, @[ key(@"Bigger", @"increaseSize:", @"+", cmd), key(@"Smaller", @"decreaseSize:", @"-", cmd) ]) ]),
            menu_with(@"Text", UIMenuText, 0, @[ group(UIMenuAlignment, @[ key(@"Align Left", @"alignLeft:", @"{", cmd), key(@"Center", @"alignCenter:", @"|", cmd),
                                                                           key(@"Align Right", @"alignRight:", @"}", cmd) ]),
                                                 group(UIMenuWritingDirection, @[]) ]) ])];
    NSMutableArray *view = [NSMutableArray array];
    if (included(cfg.toolbarPreference, NO)) [view addObject:group(UIMenuToolbar, @[ command(@"Show Toolbar", @"toggleToolbar:") ])];
    if (included(cfg.sidebarPreference, NO)) [view addObject:group(UIMenuSidebar, @[ key(@"Show Sidebar", @"toggleSidebar:", @"s", cmd | ctrl) ])];
    if (included(cfg.inspectorPreference, NO)) [view addObject:group(kInspector, @[ key(@"Show Inspector", @"toggleInspector:", @"i", cmd | alt) ])];
    [view addObject:group(UIMenuFullscreen, @[ key(@"Enter Full Screen", @"toggleFullScreen:", @"f", cmd | ctrl) ])];
    [top addObject:menu_with(@"View", UIMenuView, 0, view)];
    [top addObject:menu_with(@"Window", UIMenuWindow, 0, @[ group(UIMenuMinimizeAndZoom, @[ key(@"Minimize", @"performMiniaturize:", @"m", cmd), command(@"Zoom", @"performZoom:") ]),
                                                            group(UIMenuBringAllToFront, @[ command(@"Bring All to Front", @"arrangeInFront:") ]) ])];
    [top addObject:menu_with(@"Help", UIMenuHelp, 0, @[])];
    return menu_with(@"", UIMenuRoot, 0, top);
}
UIMenu *isim_ui_main_menu(void) {
    UIMainMenuSystem *s = UIMainMenuSystem.sharedSystem;
    if (s->_built && s.menu) return s.menu;
    s->_built = YES;
    __IsimMenuBuilder *b = [__IsimMenuBuilder new];
    b.system = s;
    b.root = standard_menu(s.configuration);
    if (s.buildHandler) s.buildHandler(b);
    [UIApplication.sharedApplication buildMenuWithBuilder:b];
    s.menu = b.root;
    NSUInteger n = 0;
    for (UIMenuElement *e in s.menu.children) if ([e isKindOfClass:[UIMenu class]]) n++;
    NSLog(@"isim: main menu built: %lu menus", (unsigned long)n);
    return s.menu;
}

/* the app's key commands in the main menu (the standard items: isim's own editing shortcuts handle them, but for Find) */
static BOOL is_find_action(SEL a) {
    return a == @selector(find:) || a == @selector(findNext:) || a == @selector(findPrevious:) || a == @selector(findAndReplace:) || a == @selector(useSelectionForFind:);
}
static void key_commands(UIMenu *m, NSMutableArray *out) {
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIMenu class]]) key_commands((UIMenu *)e, out);
        else if ([e isKindOfClass:[UIKeyCommand class]] && (!get(e, &kStandard) || is_find_action(((UIKeyCommand *)e).action))) [out addObject:e];
    }
}
BOOL isim_ui_main_menu_key(NSString *base, NSString *characters, UIKeyModifierFlags mods, BOOL isRepeat) {
    if (!UIApplication.sharedApplication.delegate) return NO;
    NSMutableArray *cmds = [NSMutableArray array]; key_commands(isim_ui_main_menu(), cmds);
    UIKeyModifierFlags mask = UIKeyModifierShift | UIKeyModifierControl | UIKeyModifierAlternate | UIKeyModifierCommand;
    for (UIKeyCommand *c in cmds) {
        BOOL inputMatch = [c.input caseInsensitiveCompare:base] == NSOrderedSame || [c.input isEqualToString:characters];
        if (!inputMatch || (c.modifierFlags & mask) != (mods & mask)) continue;
        if (isRepeat && c.repeatBehavior == UIMenuElementRepeatBehaviorNonRepeatable) return YES;
        id t = command_target(c.action, c, nil);
        if (!t) continue;
        validate(c, t);
        if (c.attributes & (UIMenuElementAttributesDisabled | UIMenuElementAttributesHidden)) continue;
        NSLog(@"isim: main menu command %@ (%@)", c.title, isim_ui_shortcut_text(c));
        ((void (*)(id, SEL, id))[t methodForSelector:c.action])(t, c.action, c);
        return YES;
    }
    return NO;
}

/* ================= the keyboard shortcuts overlay (iPad: hold Command) ================= */
static void log_menu(UIMenu *m, int depth) {
    for (UIMenuElement *e in m.children) {
        NSString *pad = [@"" stringByPaddingToLength:(NSUInteger)depth * 2 withString:@" " startingAtIndex:0];
        if ([e isKindOfClass:[UIMenu class]]) {
            UIMenu *s = (UIMenu *)e;
            if (s.options & UIMenuOptionsDisplayInline) { if (s.children.count) { NSLog(@"isim: main menu %@-- %@", pad, s.identifier); log_menu(s, depth); } }
            else { NSLog(@"isim: main menu %@%@ (%@)", pad, s.title, s.identifier); log_menu(s, depth + 1); }
        } else {
            NSString *sc = [e isKindOfClass:[UIKeyCommand class]] ? isim_ui_shortcut_text((UIKeyCommand *)e) : @"";
            NSLog(@"isim: main menu %@%@%@%@", pad, e.title, sc.length ? @" " : @"", sc);
        }
    }
}
static void shortcut_rows(UIMenu *m, NSMutableArray *out) {
    for (UIMenuElement *e in m.children) {
        if ([e isKindOfClass:[UIMenu class]]) shortcut_rows((UIMenu *)e, out);
        else if ([e isKindOfClass:[UIKeyCommand class]] && ((UIKeyCommand *)e).input.length) {
            UIKeyCommand *c = (UIKeyCommand *)e;
            id t = command_target(c.action, c, nil);
            if (!t) continue;
            validate(c, t);
            if (c.attributes & UIMenuElementAttributesHidden) continue;
            [out addObject:c];
        }
    }
}
static __weak UIView *shortcuts_hud;
static void hide_shortcuts(void) {
    UIView *h = shortcuts_hud;
    if (!h) return;
    shortcuts_hud = nil;
    [UIView animateWithDuration:0.15 animations:^{ h.alpha = 0; } completion:^(BOOL f) { [h removeFromSuperview]; }];
}
static void show_shortcuts(void) {
    UIWindow *w = UIApplication.sharedApplication.keyWindow;
    if (!w || shortcuts_hud) return;
    UIMenu *root = isim_ui_main_menu();
    NSMutableArray *columns = [NSMutableArray array];
    for (UIMenuElement *e in root.children) {
        if (![e isKindOfClass:[UIMenu class]]) continue;
        NSMutableArray *rows = [NSMutableArray array]; shortcut_rows((UIMenu *)e, rows);
        if (rows.count) [columns addObject:@[ e.title, rows ]];
    }
    UIVisualEffectView *card = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial]];
    card.layer.cornerRadius = 18; card.layer.cornerCurve = kCACornerCurveContinuous; card.clipsToBounds = YES;
    card.accessibilityIdentifier = @"isim-shortcuts";
    CGFloat colW = 230, pad = 20, maxH = 0;
    NSInteger perRow = MAX(1, (NSInteger)floor((w.bounds.size.width - 80 - pad) / (colW + pad)));
    NSInteger ncol = MIN(perRow, (NSInteger)MAX(columns.count, 1));
    CGFloat x = pad, y = pad, rowTop = pad;
    for (NSUInteger i = 0; i < columns.count; i++) {
        if (i && i % (NSUInteger)ncol == 0) { x = pad; rowTop = maxH + pad; }
        y = rowTop;
        UILabel *h = [UILabel new]; h.text = columns[i][0]; h.font = [UIFont boldSystemFontOfSize:15]; h.textColor = UIColor.labelColor;
        h.frame = CGRectMake(x, y, colW, 22); [card.contentView addSubview:h]; y += 30;
        for (UIKeyCommand *c in columns[i][1]) {
            BOOL off = (c.attributes & UIMenuElementAttributesDisabled) != 0;
            UILabel *t = [UILabel new]; t.text = c.discoverabilityTitle ?: c.title; t.font = [UIFont systemFontOfSize:15];
            t.textColor = off ? UIColor.tertiaryLabelColor : UIColor.labelColor; t.frame = CGRectMake(x, y, colW - 70, 20);
            t.accessibilityIdentifier = [@"shortcut-" stringByAppendingString:c.title];
            UILabel *k = [UILabel new]; k.text = isim_ui_shortcut_text(c); k.font = [UIFont systemFontOfSize:15]; k.textAlignment = NSTextAlignmentRight;
            k.textColor = UIColor.secondaryLabelColor; k.frame = CGRectMake(x + colW - 70, y, 70, 20);
            [card.contentView addSubview:t]; [card.contentView addSubview:k];
            y += 26;
        }
        maxH = fmax(maxH, y);
        x += colW + pad;
    }
    if (!columns.count) {
        UILabel *t = [UILabel new]; t.text = @"No Keyboard Shortcuts"; t.font = [UIFont systemFontOfSize:15]; t.textColor = UIColor.secondaryLabelColor;
        t.frame = CGRectMake(pad, pad, colW, 22); [card.contentView addSubview:t]; maxH = pad + 22;
    }
    CGFloat W = ncol * (colW + pad) + pad, H = maxH + pad;
    card.frame = CGRectMake(floor((w.bounds.size.width - W) / 2), floor((w.bounds.size.height - H) / 2), W, H);
    card.userInteractionEnabled = NO;
    [w addSubview:card];
    shortcuts_hud = card;
    NSLog(@"isim: keyboard shortcuts shown: %lu menu(s)", (unsigned long)columns.count);
}
/* Command held alone on iPad: the overlay after a moment; released or another key: hidden */
static NSUInteger cmd_generation;
void isim_ui_main_menu_modifier(UIKeyModifierFlags flag, BOOL down, BOOL otherKey) {
    if (otherKey || flag != UIKeyModifierCommand || !down) { cmd_generation++; hide_shortcuts(); return; }
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return;
    NSUInteger gen = ++cmd_generation;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ if (gen == cmd_generation) show_shortcuts(); });
}
/* script "mainmenu [show|hide]" */
void isim_ui_main_menu_event(NSString *args) {
    if ([args isEqualToString:@"show"]) { show_shortcuts(); return; }
    if ([args isEqualToString:@"hide"]) { hide_shortcuts(); return; }
    log_menu(isim_ui_main_menu(), 0);
    NSLog(@"isim: main menu end");
}
