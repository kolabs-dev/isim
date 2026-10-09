/* iOS 27 scenes: scene accessories on a simulated external display, and the closure confirmation of a window scene.
 *
 * External display (adapted): the script command `display connect [WxH]` connects one (default 1920x1080, scale 1;
 * UIScreen.screens, UIScreen.didConnectNotification), `display disconnect` removes it and `display shot PATH` saves
 * what it shows as a PNG (isim draws no second window). While it is connected, the most recently registered enabled
 * external scene accessory (UIViewController.registerSceneAccessory) gets a scene of role
 * windowExternalDisplayNonInteractive on it, made from the accessory's configuration, with its userInfo in the
 * connection options; without one, a UIWindowSceneSessionRoleExternalDisplayNonInteractive configuration of the scene
 * manifest gets the scene (iOS 16); without either, the display mirrors the device. Its windows are laid out and drawn
 * only on the display (never touched). Registrations become available while the display is connected; camera capture
 * accessories never are (isim has no capture accessory surface: stub).
 *
 * Closure confirmation: the script command `closescene [SESSION-ID]` is the user closing a window (iPad, multiple
 * scenes; the key scene by default). With UIWindowScene.closureConfirmation set, a confirmation alert is shown first:
 * Close (or the confirmation's .destructive action) closes the scene, Cancel (or its .cancel action) keeps it.
 */
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "UIKitPrivate.h"

UISceneSessionRole const UIWindowSceneSessionRoleCameraCaptureAccessory = @"UIWindowSceneSessionRoleCameraCaptureAccessory";

UIScene *isim_ui_connect_role_scene(UISceneConfiguration *config, UISceneSessionRole role, UIScreen *screen, id accessoryUserInfo);
void isim_ui_disconnect_role_scene(UIScene *s);
NSDictionary *isim_ui_role_configuration(UISceneSessionRole role);
@interface UIScreen (IsimExternal)
+ (UIScreen *)_isim_externalScreenWithSize:(CGSize)size;
@end

/* ================= scene accessories ================= */
typedef NS_ENUM(NSInteger, IsimAccessoryKind) { IsimAccessoryExternal, IsimAccessoryCamera };
@interface UISceneAccessory ()
@property (nonatomic) IsimAccessoryKind kind;
@property (nonatomic, copy) UISceneConfiguration *configuration;
@property (nonatomic, strong) id userInfo;
@end
@implementation UISceneAccessory
+ (instancetype)_isim_kind:(IsimAccessoryKind)k configuration:(UISceneConfiguration *)c userInfo:(id)u {
    UISceneAccessory *a = [[self alloc] initForIsim];
    a.kind = k; a.configuration = c; a.userInfo = u;
    return a;
}
- (instancetype)initForIsim { return [super init]; }
+ (instancetype)externalNonInteractiveSceneAccessoryWithConfiguration:(UISceneConfiguration *)c { return [self _isim_kind:IsimAccessoryExternal configuration:c userInfo:nil]; }
+ (instancetype)externalNonInteractiveSceneAccessoryWithConfiguration:(UISceneConfiguration *)c userInfo:(id)u { return [self _isim_kind:IsimAccessoryExternal configuration:c userInfo:u]; }
+ (instancetype)cameraCaptureSceneAccessoryWithConfiguration:(UISceneConfiguration *)c { return [self _isim_kind:IsimAccessoryCamera configuration:c userInfo:nil]; }
+ (instancetype)cameraCaptureSceneAccessoryWithConfiguration:(UISceneConfiguration *)c userInfo:(id)u { return [self _isim_kind:IsimAccessoryCamera configuration:c userInfo:u]; }
@end

static UIScreen *external_screen;
static UIScene *external_scene;                                    /* the scene on the external display, if any */
static NSPointerArray *registrations;                              /* weak, in registration order */
static void accessories_update(void);

@interface UISceneAccessoryRegistration ()
@property (nonatomic, strong) UISceneAccessory *accessory;
@property (nonatomic, weak) UIViewController *controller;
@property (nonatomic, readwrite, getter=isAvailable) BOOL available;
@end
@implementation UISceneAccessoryRegistration
- (instancetype)initForIsim { if ((self = [super init])) _enabled = YES; return self; }
- (void)setEnabled:(BOOL)e {
    if (e == _enabled) return;
    _enabled = e;
    NSLog(@"isim: scene accessory %@", e ? @"enabled" : @"disabled");
    accessories_update();
}
- (void)dealloc { dispatch_async(dispatch_get_main_queue(), ^{ accessories_update(); }); }
@end

static char registrations_key;
@implementation UIViewController (UISceneAccessory)
- (UISceneAccessoryRegistration *)registerSceneAccessory:(UISceneAccessory *)accessory {
    UISceneAccessoryRegistration *r = [[UISceneAccessoryRegistration alloc] initForIsim];
    r.accessory = accessory; r.controller = self;
    NSMutableArray *mine = objc_getAssociatedObject(self, &registrations_key);    /* the controller keeps its registrations */
    if (!mine) { mine = [NSMutableArray array]; objc_setAssociatedObject(self, &registrations_key, mine, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    [mine addObject:r];
    if (!registrations) registrations = [NSPointerArray weakObjectsPointerArray];
    [registrations addPointer:(__bridge void *)r];
    NSLog(@"isim: scene accessory registered (%@, %@)", accessory.kind == IsimAccessoryCamera ? @"camera capture" : @"external non-interactive",
          accessory.configuration.name ?: @"no configuration name");
    accessories_update();
    return r;
}
- (void)unregisterSceneAccessory:(UISceneAccessoryRegistration *)r {
    if (!r) return;
    [objc_getAssociatedObject(self, &registrations_key) removeObjectIdenticalTo:r];
    for (NSUInteger i = 0; i < registrations.count; i++) if ([registrations pointerAtIndex:i] == (__bridge void *)r) { [registrations removePointerAtIndex:i]; break; }
    r.controller = nil;
    NSLog(@"isim: scene accessory unregistered");
    accessories_update();
}
@end

/* the accessory that gets the external display: the most recent enabled external one whose controller still exists */
static __weak UISceneAccessoryRegistration *shown_registration;
static void accessories_update(void) {
    [registrations compact];
    UISceneAccessoryRegistration *want = nil;
    for (NSInteger i = (NSInteger)registrations.count - 1; i >= 0; i--) {
        UISceneAccessoryRegistration *r = (__bridge UISceneAccessoryRegistration *)[registrations pointerAtIndex:(NSUInteger)i];
        if (!r || !r.controller) continue;
        BOOL avail = r.accessory.kind == IsimAccessoryExternal && external_screen != nil;
        if (avail != r.available) {
            r.available = avail;
            NSLog(@"isim: scene accessory %@", avail ? @"available" : @"unavailable");
            /* observed during updateProperties and layoutSubviews, like iOS */
            UIViewController *vc = r.controller;
            [vc setNeedsUpdateProperties];
            [vc.viewIfLoaded setNeedsUpdateProperties];
            [vc.viewIfLoaded setNeedsLayout];
        }
        if (!want && avail && r.enabled) want = r;
    }
    BOOL manifest = !want && external_screen && isim_ui_role_configuration(UIWindowSceneSessionRoleExternalDisplayNonInteractive);
    BOOL same = external_scene && (want ? shown_registration == want : (manifest && !shown_registration));
    if (same) return;
    if (external_scene) { UIScene *s = external_scene; external_scene = nil; isim_ui_disconnect_role_scene(s); }
    shown_registration = want;
    if (want) external_scene = isim_ui_connect_role_scene(want.accessory.configuration, UIWindowSceneSessionRoleExternalDisplayNonInteractive, external_screen, want.accessory.userInfo);
    else if (manifest) external_scene = isim_ui_connect_role_scene(nil, UIWindowSceneSessionRoleExternalDisplayNonInteractive, external_screen, nil);
    isim_ui_set_needs_display();
}

/* ================= the external display ================= */
UIScreen *isim_ui_external_screen(void) { return external_screen; }

/* what the display shows: the external scene's windows, or the device's (mirrored, scaled to fit) */
static void external_shot(NSString *path) {
    if (!external_screen) { NSLog(@"isim: display shot: no external display is connected"); return; }
    CGSize size = external_screen.bounds.size;
    UIGraphicsBeginImageContextWithOptions(size, YES, 1);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGContextSetRGBFillColor(c, 0, 0, 0, 1);
    CGContextFillRect(c, CGRectMake(0, 0, size.width, size.height));
    NSArray *(^byLevel)(NSArray *) = ^NSArray *(NSArray *ws) {
        return [ws sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
            return a.windowLevel < b.windowLevel ? NSOrderedAscending : a.windowLevel > b.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
    };
    NSArray<UIWindow *> *mine = [external_scene isKindOfClass:[UIWindowScene class]] ? ((UIWindowScene *)external_scene).windows : @[];
    NSString *what;
    if (external_scene) {
        for (UIWindow *w in byLevel(mine)) if (!w.hidden) { [w layoutIfNeeded]; [w drawViewHierarchyInRect:w.frame afterScreenUpdates:NO]; }
        what = [NSString stringWithFormat:@"scene %@", external_scene.session.persistentIdentifier];
    } else {
        CGSize dev = UIScreen.mainScreen.bounds.size;
        CGFloat k = MIN(size.width / dev.width, size.height / dev.height);
        CGContextTranslateCTM(c, (size.width - dev.width * k) / 2, (size.height - dev.height * k) / 2);
        CGContextScaleCTM(c, k, k);
        extern BOOL isim_ui_window_on_screen(UIWindow *w);
        for (UIWindow *w in byLevel(UIApplication.sharedApplication.windows))
            if (!w.hidden && isim_ui_window_on_screen(w)) [w drawViewHierarchyInRect:w.frame afterScreenUpdates:NO];
        what = @"mirrored";
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    BOOL ok = [UIImagePNGRepresentation(img) writeToFile:path atomically:YES];
    NSLog(@"isim: external display shot %@ (%gx%g, %@)%@", path, size.width, size.height, what, ok ? @"" : @": not written");
}

/* script "display connect [WxH]" / "display disconnect" / "display shot PATH" */
void isim_ui_display_event(NSString *args) {
    NSArray *a = [args componentsSeparatedByCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
    NSString *verb = a.firstObject ?: @"";
    if ([verb isEqualToString:@"connect"]) {
        if (external_screen) { NSLog(@"isim: an external display is already connected"); return; }
        int w = 1920, h = 1080;
        if (a.count > 1 && sscanf([a[1] UTF8String], "%dx%d", &w, &h) != 2) { w = 1920; h = 1080; }
        external_screen = [UIScreen _isim_externalScreenWithSize:CGSizeMake(MAX(w, 1), MAX(h, 1))];
        NSLog(@"isim: external display connected (%dx%d)", w, h);
        [NSNotificationCenter.defaultCenter postNotificationName:UIScreenDidConnectNotification object:external_screen];
        accessories_update();
    } else if ([verb isEqualToString:@"disconnect"]) {
        if (!external_screen) return;
        UIScreen *gone = external_screen;
        external_screen = nil;
        accessories_update();                                     /* the scene disconnects, the registrations become unavailable */
        NSLog(@"isim: external display disconnected");
        [NSNotificationCenter.defaultCenter postNotificationName:UIScreenDidDisconnectNotification object:gone];
    } else if ([verb isEqualToString:@"shot"] && a.count > 1) {
        external_shot([[a subarrayWithRange:NSMakeRange(1, a.count - 1)] componentsJoinedByString:@" "]);
    } else NSLog(@"isim: display: unknown command '%@'", args);
}

/* ================= closure confirmation ================= */
@implementation UISceneClosureConfirmation { NSString *_title, *_message; NSArray<UIAlertAction *> *_actions; }
+ (instancetype)confirmationWithTitle:(NSString *)title message:(NSString *)message actions:(NSArray<UIAlertAction *> *)actions {
    UISceneClosureConfirmation *c = [[self alloc] initForIsim];
    c->_title = [title copy]; c->_message = [message copy]; c->_actions = [actions copy] ?: @[];
    return c;
}
- (instancetype)initForIsim { return [super init]; }
- (instancetype)initWithCoder:(NSCoder *)coder {
    if ((self = [super init])) {
        _title = [coder decodeObjectOfClass:[NSString class] forKey:@"title"];
        _message = [coder decodeObjectOfClass:[NSString class] forKey:@"message"];
        _actions = @[];                                           /* actions carry blocks: not archived */
    }
    return self;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:_title forKey:@"title"]; [coder encodeObject:_message forKey:@"message"]; }
- (id)copyWithZone:(NSZone *)z { return [UISceneClosureConfirmation confirmationWithTitle:_title message:_message actions:_actions]; }
- (NSString *)_isim_title { return _title; }
- (NSString *)_isim_message { return _message; }
- (NSArray<UIAlertAction *> *)_isim_actions { return _actions; }
@end

static void close_scene(UIWindowScene *s) {
    [UIApplication.sharedApplication requestSceneSessionDestruction:s.session options:nil errorHandler:^(NSError *e) {
        NSLog(@"isim: closescene: %@", e.localizedDescription);
    }];
}
/* script "closescene [SESSION-ID]": the user closes a window */
void isim_ui_close_scene(NSString *ident) {
    UIApplication *app = UIApplication.sharedApplication;
    UIWindowScene *target = nil;
    for (UIScene *s in app.connectedScenes)
        if ([s isKindOfClass:[UIWindowScene class]] && [s.session.role isEqualToString:UIWindowSceneSessionRoleApplication] &&
            (ident.length ? [s.session.persistentIdentifier isEqualToString:ident] : ((UIWindowScene *)s).keyWindow != nil)) target = (UIWindowScene *)s;
    if (!target) { NSLog(@"isim: closescene: no %@scene", ident.length ? [NSString stringWithFormat:@"%@ ", ident] : @"key "); return; }
    if (!app.supportsMultipleScenes) { NSLog(@"isim: closescene: the app shows one scene (iPad apps with multiple scenes have closable windows)"); return; }
    UISceneClosureConfirmation *conf = target.closureConfirmation;
    NSLog(@"isim: closing scene %@%@", target.session.persistentIdentifier, conf ? @": confirmation shown" : @"");
    if (!conf) { close_scene(target); return; }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:[conf _isim_title] message:[conf _isim_message] preferredStyle:UIAlertControllerStyleAlert];
    BOOL hasClose = NO, hasCancel = NO;
    __weak UIWindowScene *weakScene = target;
    for (UIAlertAction *orig in [conf _isim_actions]) {
        void (^handler)(UIAlertAction *) = [orig valueForKey:@"handler"];
        UIAlertActionStyle style = orig.style;
        if (style == UIAlertActionStyleDestructive) hasClose = YES;
        if (style == UIAlertActionStyleCancel) hasCancel = YES;
        [alert addAction:[UIAlertAction actionWithTitle:orig.title style:style handler:^(UIAlertAction *a) {
            if (handler) handler(orig);
            NSLog(@"isim: scene closure %@", style == UIAlertActionStyleDestructive ? @"confirmed" : style == UIAlertActionStyleCancel ? @"cancelled" : @"action");
            if (style == UIAlertActionStyleDestructive && weakScene) close_scene(weakScene);
        }]];
    }
    if (!hasClose) [alert addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        NSLog(@"isim: scene closure confirmed");
        if (weakScene) close_scene(weakScene);
    }]];
    if (!hasCancel) [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:^(UIAlertAction *a) { NSLog(@"isim: scene closure cancelled"); }]];
    UIViewController *top = (target.keyWindow ?: target.windows.firstObject).rootViewController;
    while (top.presentedViewController) top = top.presentedViewController;
    [top presentViewController:alert animated:YES completion:nil];
}
