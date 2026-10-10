/* Scene, window, screen and app members from the documentation sweep (#9) (ARC): Settings URLs, protected data (the
 * shell's lock screen), Shake to Undo's alert, default-app checks, reduced resource usage (Low Power Mode), scene
 * activation conditions, system protection, pointer lock, the status bar manager, windowing behaviours and control
 * styles, activation actions / interactions, the window drag interaction, screen modes and display properties, the
 * fixed coordinate space and the window's aspect-fit safe area guide. */
#import "UIKitPrivate.h"
#import <UIKit/UIWindowSceneExtras.h>
#import <objc/runtime.h>

NSString *const UIApplicationOpenSettingsURLString = @"app-settings:";
NSString *const UIApplicationOpenNotificationSettingsURLString = @"app-settings:notifications";
NSString *const UIApplicationOpenDefaultApplicationsSettingsURLString = @"app-settings:default-apps";
NSExceptionName const UIApplicationInvalidInterfaceOrientationException = @"UIApplicationInvalidInterfaceOrientationException";
UIApplicationExtensionPointIdentifier const UIApplicationKeyboardExtensionPointIdentifier = @"com.apple.keyboard-service";
NSNotificationName const UIApplicationSystemPrefersReducedResourceUsageDidChangeNotification = @"UIApplicationSystemPrefersReducedResourceUsageDidChangeNotification";
NSErrorDomain const UIApplicationCategoryDefaultErrorDomain = @"UIApplicationCategoryDefaultErrorDomain";
NSString *const UIApplicationCategoryDefaultStatusLastProvidedDateErrorKey = @"UIApplicationCategoryDefaultStatusLastProvidedDateErrorKey";
NSString *const UIApplicationCategoryDefaultRetryAvailabilityDateErrorKey = @"UIApplicationCategoryDefaultRetryAvailabilityDateErrorKey";
UISceneSessionRole const UIWindowSceneSessionRoleAssistiveAccessApplication = @"UIWindowSceneSessionRoleAssistiveAccessApplication";
NSNotificationName const UIPointerLockStateDidChangeNotification = @"UIPointerLockStateDidChangeNotification";
NSString *const UIPointerLockStateSceneUserInfoKey = @"UIPointerLockStateSceneUserInfoKey";

extern NSDictionary *isim_global_preferences(void);
static BOOL is_pad(void) { return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad; }
static UIViewController *top_controller(UIWindow *w) {
    UIViewController *vc = (w ?: UIApplication.sharedApplication.keyWindow).rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}

/* ================= UIApplication ================= */
static BOOL protected_unavailable, shake_to_edit_off, remote_events, reduced_usage;
/* the shell locked or unlocked the device (script `lock` / `unlock`) */
void isim_ui_protected_data(BOOL available) {
    if (protected_unavailable == !available) return;
    if (available) protected_unavailable = NO;          /* "will become unavailable": still available while it is told */
    UIApplication *app = UIApplication.sharedApplication;
    id<UIApplicationDelegate> d = app.delegate;
    NSLog(@"isim: protected data %@", available ? @"available" : @"unavailable");
    if (available) {
        if ([d respondsToSelector:@selector(applicationProtectedDataDidBecomeAvailable:)]) [d applicationProtectedDataDidBecomeAvailable:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationProtectedDataDidBecomeAvailable object:app];
    } else {
        if ([d respondsToSelector:@selector(applicationProtectedDataWillBecomeUnavailable:)]) [d applicationProtectedDataWillBecomeUnavailable:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationProtectedDataWillBecomeUnavailable object:app];
        protected_unavailable = YES;
    }
}
/* Shake to Undo: a shake offers to undo or redo the first responder's last change (Settings > Accessibility > Touch) */
void isim_ui_shake_to_edit(UIResponder *r) {
    if (shake_to_edit_off || !UIAccessibilityIsShakeToUndoEnabled()) return;
    NSUndoManager *um = r.undoManager;
    if (!um.canUndo && !um.canRedo) return;
    UIViewController *vc = top_controller(nil);
    if (!vc || vc.presentedViewController) return;
    NSString *title = um.canUndo ? (um.undoActionName.length ? [@"Undo " stringByAppendingString:um.undoActionName] : @"Undo")
                                 : (um.redoActionName.length ? [@"Redo " stringByAppendingString:um.redoActionName] : @"Redo");
    UIAlertController *a = [UIAlertController alertControllerWithTitle:title message:nil preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    BOOL undo = um.canUndo;
    [a addAction:[UIAlertAction actionWithTitle:undo ? @"Undo" : @"Redo" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x) {
        if (undo) [um undo]; else [um redo];
        NSLog(@"isim: shake to %@", undo ? @"undo" : @"redo");
    }]];
    a.view.accessibilityIdentifier = @"isim-shake-to-undo";
    NSLog(@"isim: shake to undo alert \"%@\"", title);
    [vc presentViewController:a animated:YES completion:nil];
}
static void power_changed(void) {
    BOOL now = NSProcessInfo.processInfo.lowPowerModeEnabled;
    if (now == reduced_usage) return;
    reduced_usage = now;
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationSystemPrefersReducedResourceUsageDidChangeNotification object:UIApplication.sharedApplication];
}
__attribute__((constructor)) static void watch_power(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        reduced_usage = NSProcessInfo.processInfo.lowPowerModeEnabled;
        [NSNotificationCenter.defaultCenter addObserverForName:NSProcessInfoPowerStateDidChangeNotification object:nil queue:nil usingBlock:^(NSNotification *n) { power_changed(); }];
    });
}
@implementation UIApplication (UISceneExtras)
- (BOOL)isProtectedDataAvailable { return !protected_unavailable; }
- (BOOL)applicationSupportsShakeToEdit { return !shake_to_edit_off; }
- (void)setApplicationSupportsShakeToEdit:(BOOL)b { shake_to_edit_off = !b; }
- (void)beginReceivingRemoteControlEvents { if (!remote_events) NSLog(@"isim: receiving remote control events"); remote_events = YES; }
- (void)endReceivingRemoteControlEvents { if (remote_events) NSLog(@"isim: no longer receiving remote control events"); remote_events = NO; }
/* adapted: the system prefers reduced resource usage in Low Power Mode */
- (BOOL)systemPrefersReducedResourceUsage { return NSProcessInfo.processInfo.lowPowerModeEnabled; }
/* the default browser is Settings > Apps > Default Apps (preference ISIMDefaultBrowser, a bundle identifier) */
- (BOOL)isDefaultForCategory:(UIApplicationCategory)category error:(NSError **)error {
    if (category != UIApplicationCategoryWebBrowser) {
        if (error) *error = [NSError errorWithDomain:UIApplicationCategoryDefaultErrorDomain code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Unknown category" }];
        return NO;
    }
    NSString *browser = isim_global_preferences()[@"ISIMDefaultBrowser"];
    return [browser isEqualToString:NSBundle.mainBundle.bundleIdentifier];
}
@end
@interface UIApplicationShortcutIcon ()
@property (nonatomic, copy) NSString *_isim_symbolName;
@end
@implementation UIApplicationShortcutIcon (UISceneExtras)
/* adapted: a person symbol (isim's quick action menu draws symbols, not contact pictures) */
+ (instancetype)iconWithContact:(CNContact *)contact { UIApplicationShortcutIcon *i = [self new]; i._isim_symbolName = @"person.crop.circle"; return i; }
@end

/* ================= scenes ================= */
@implementation UISceneActivationConditions
- (instancetype)init {
    if ((self = [super init])) {
        _canActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:YES];
        _prefersToActivateForTargetContentIdentifierPredicate = [NSPredicate predicateWithValue:NO];
    }
    return self;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
@end
@implementation UISceneSystemProtectionManager
- (BOOL)isUserAuthenticationEnabled { return NO; }
@end
@implementation UIPointerLockState { __weak UIScene *_scene; }
- (BOOL)isLocked {
    UIScene *s = _scene;
    if (!is_pad() || ![s isKindOfClass:[UIWindowScene class]]) return NO;
    extern BOOL isim_ui_scenes_split(void);
    if (isim_ui_scenes_split()) return NO;                  /* only full-screen scenes lock the pointer */
    UIWindow *w = ((UIWindowScene *)s).keyWindow ?: ((UIWindowScene *)s).windows.firstObject;
    UIViewController *vc = top_controller(w);
    UIViewController *child = vc.childViewControllerForPointerLock ?: vc;
    return child.prefersPointerLocked;
}
@end
static char k_conditions, k_protection, k_lock, k_behaviors, k_statusbar;
@implementation UIScene (UISceneExtras)
- (UISceneActivationConditions *)activationConditions {
    UISceneActivationConditions *c = objc_getAssociatedObject(self, &k_conditions);
    if (!c) { c = [UISceneActivationConditions new]; objc_setAssociatedObject(self, &k_conditions, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return c;
}
- (void)setActivationConditions:(UISceneActivationConditions *)c { objc_setAssociatedObject(self, &k_conditions, c, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UISceneSystemProtectionManager *)systemProtectionManager {
    UISceneSystemProtectionManager *m = objc_getAssociatedObject(self, &k_protection);
    if (!m) { m = [UISceneSystemProtectionManager new]; objc_setAssociatedObject(self, &k_protection, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return m;
}
- (UIPointerLockState *)pointerLockState {
    if (!is_pad()) return nil;
    UIPointerLockState *p = objc_getAssociatedObject(self, &k_lock);
    if (!p) { p = [UIPointerLockState new]; [p setValue:self forKey:@"_scene"]; objc_setAssociatedObject(self, &k_lock, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return p;
}
@end
/* the scene that opens content with a target content identifier: one that prefers it, else (one scene only) one
   that can (UIApplication.m's activation requests) */
UIScene *isim_ui_scene_for_target(NSString *ident) {
    if (!ident) return nil;
    UIScene *can = nil;
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) {
        UISceneActivationConditions *c = s.activationConditions;
        if ([c.prefersToActivateForTargetContentIdentifierPredicate evaluateWithObject:ident]) return s;
        if (!can && [c.canActivateForTargetContentIdentifierPredicate evaluateWithObject:ident]) can = s;
    }
    return UIApplication.sharedApplication.supportsMultipleScenes ? nil : can;
}
@implementation UISceneConnectionOptions (UISceneExtras)
/* isim delivers a launching notification response to the notification center's delegate only */
- (UNNotificationResponse *)notificationResponse { return nil; }
- (CKShareMetadata *)cloudKitShareMetadata { return nil; }
- (GCGameControllerActivationContext *)gameControllerActivationContext { return nil; }
@end

/* ---- windowing ---- */
@implementation UISceneWindowingBehaviors
- (instancetype)init { if ((self = [super init])) { _closable = YES; _miniaturizable = YES; } return self; }
@end
@implementation UISceneWindowingControlStyle { NSString *_name; }
+ (instancetype)_isim_named:(NSString *)n {
    static NSMutableDictionary *all; if (!all) all = [NSMutableDictionary dictionary];
    UISceneWindowingControlStyle *s = all[n];
    if (!s) { s = [super new]; s->_name = n; all[n] = s; }
    return s;
}
+ (UISceneWindowingControlStyle *)automaticStyle { return [self _isim_named:@"automatic"]; }
+ (UISceneWindowingControlStyle *)minimalStyle { return [self _isim_named:@"minimal"]; }
+ (UISceneWindowingControlStyle *)unifiedStyle { return [self _isim_named:@"unified"]; }
- (NSString *)description { return [NSString stringWithFormat:@"<UISceneWindowingControlStyle %@>", _name]; }
@end
/* the status bar of a scene: its style and visibility follow the top view controller (UIApplication.m draws it) */
@implementation UIStatusBarManager { __weak UIWindowScene *_scene; }
- (UIViewController *)_top { UIWindowScene *s = _scene; return top_controller(s.keyWindow ?: s.windows.firstObject); }
- (UIStatusBarStyle)statusBarStyle { UIViewController *vc = [self _top]; return vc ? vc.preferredStatusBarStyle : UIStatusBarStyleDefault; }
- (BOOL)isStatusBarHidden {
    if (UIApplication.sharedApplication.isStatusBarHidden) return YES;
    UIViewController *vc = [self _top];
    if (vc.prefersStatusBarHidden) return YES;
    UIWindowScene *s = _scene;
    return !is_pad() && UIInterfaceOrientationIsLandscape(s.interfaceOrientation);   /* iPhone landscape: no status bar */
}
- (CGRect)statusBarFrame {
    if (self.isStatusBarHidden) return CGRectZero;
    /* iPhones: 54 pt with the Dynamic Island (under its safe area top), the notch's safe area top, 20 with a Home button;
       iPad: its safe area top */
    const struct isim_device *d = isim_ui_device();
    CGFloat h = d->has_island ? 54 : d->safe_top > 20 ? d->safe_top : 20;
    UIWindowScene *s = _scene;
    return CGRectMake(0, 0, s.coordinateSpace.bounds.size.width, h);
}
@end
@implementation UIWindowScene (UISceneExtras)
- (UISceneWindowingBehaviors *)windowingBehaviors {
    UISceneWindowingBehaviors *b = objc_getAssociatedObject(self, &k_behaviors);
    if (!b) { b = [UISceneWindowingBehaviors new]; objc_setAssociatedObject(self, &k_behaviors, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return b;
}
- (UIStatusBarManager *)statusBarManager {
    UIStatusBarManager *m = objc_getAssociatedObject(self, &k_statusbar);
    if (!m) { m = [UIStatusBarManager new]; [m setValue:self forKey:@"_scene"]; objc_setAssociatedObject(self, &k_statusbar, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return m;
}
@end
@implementation UIWindowSceneGeometry (UISceneExtras)
- (BOOL)isInterfaceOrientationLocked { return top_controller(nil).prefersInterfaceOrientationLocked; }
@end
@implementation UIWindowSceneGeometryPreferencesMac
- (instancetype)initWithSystemFrame:(CGRect)f { if ((self = [super init])) _systemFrame = f; return self; }
@end

/* ---- view controller preferences ---- */
@implementation UIViewController (UISceneExtras)
- (BOOL)prefersInterfaceOrientationLocked { return NO; }
- (void)setNeedsUpdateOfPrefersInterfaceOrientationLocked { NSLog(@"isim: interface orientation %@", self.prefersInterfaceOrientationLocked ? @"locked" : @"unlocked"); }
- (BOOL)prefersPointerLocked { return NO; }
- (UIViewController *)childViewControllerForPointerLock { return nil; }
- (void)setNeedsUpdateOfPrefersPointerLocked {
    UIWindowScene *s = self.viewIfLoaded.window.windowScene;
    if (!s) return;
    UIPointerLockState *p = s.pointerLockState;
    NSLog(@"isim: pointer %@", p.locked ? @"locked" : @"unlocked");
    [NSNotificationCenter.defaultCenter postNotificationName:UIPointerLockStateDidChangeNotification object:p userInfo:@{ UIPointerLockStateSceneUserInfoKey: s }];
}
- (UIStatusBarAnimation)preferredStatusBarUpdateAnimation { return UIStatusBarAnimationFade; }
@end

/* ---- activation actions and interactions ---- */
@implementation UIWindowSceneActivationConfiguration
- (instancetype)initWithUserActivity:(NSUserActivity *)a { if ((self = [super init])) _userActivity = a; return self; }
@end
static void activate_configuration(UIWindowSceneActivationConfiguration *c, void (^errorHandler)(NSError *)) {
    UISceneSessionActivationRequest *r = [UISceneSessionActivationRequest request];
    r.userActivity = c.userActivity;
    r.options = c.options;
    NSLog(@"isim: activating a window scene for %@", c.userActivity.activityType);
    [UIApplication.sharedApplication activateSceneSessionForRequest:r errorHandler:errorHandler];
}
@implementation UIWindowSceneActivationAction
+ (instancetype)actionWithIdentifier:(NSString *)identifier alternateAction:(UIAction *)alternate configurationProvider:(UIWindowSceneActivationActionConfigurationProvider)provider {
    return [self actionWithIdentifier:identifier alternateAction:alternate configurationProvider:provider errorHandler:nil];
}
+ (instancetype)actionWithIdentifier:(NSString *)identifier alternateAction:(UIAction *)alternate configurationProvider:(UIWindowSceneActivationActionConfigurationProvider)provider
                        errorHandler:(void (^)(NSError *))errorHandler {
    UIWindowSceneActivationActionConfigurationProvider p = [provider copy];
    void (^eh)(NSError *) = [errorHandler copy];
    /* without multiple windows (iPhone) the alternate action runs instead */
    UIWindowSceneActivationAction *a = [self actionWithTitle:alternate && !UIApplication.sharedApplication.supportsMultipleScenes ? alternate.title : @"Open in New Window"
                                                       image:[UIImage systemImageNamed:@"macwindow.badge.plus"] identifier:identifier
                                                     handler:^(UIAction *x) {
        if (alternate && !UIApplication.sharedApplication.supportsMultipleScenes) {
            UIActionHandler h = [alternate valueForKey:@"handler"];
            if (h) h(alternate);
            return;
        }
        UIWindowSceneActivationConfiguration *c = p ? p((UIWindowSceneActivationAction *)x) : nil;
        if (c) activate_configuration(c, eh);
    }];
    return a;
}
@end
@implementation UIWindowSceneActivationInteraction {
    UIWindowSceneActivationInteractionConfigurationProvider _provider; void (^_errorHandler)(NSError *);
    UIPinchGestureRecognizer *_pinch; __weak UIView *_view;
}
- (instancetype)initWithConfigurationProvider:(UIWindowSceneActivationInteractionConfigurationProvider)p errorHandler:(void (^)(NSError *))e {
    if ((self = [super init])) {
        _provider = [p copy]; _errorHandler = [e copy];
        _pinch = [[UIPinchGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_pinched:)];
    }
    return self;
}
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { [_view removeGestureRecognizer:_pinch]; }
- (void)didMoveToView:(UIView *)v { _view = v; if (v) [v addGestureRecognizer:_pinch]; }
/* a pinch out past 1.5x opens the configuration */
- (void)_isim_pinched:(UIPinchGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateEnded || g.scale < 1.5) return;
    UIWindowSceneActivationConfiguration *c = _provider ? _provider(self, [g locationInView:_view]) : nil;
    if (c) activate_configuration(c, _errorHandler);
}
@end
@implementation UIWindowSceneDragInteraction { UIPanGestureRecognizer *_pan; __weak UIView *_view; }
- (instancetype)init {
    if ((self = [super init])) _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(_isim_panned:)];
    return self;
}
- (UIGestureRecognizer *)gestureForFailureRelationships { return _pan; }
- (UIView *)view { return _view; }
- (void)willMoveToView:(UIView *)v { [_view removeGestureRecognizer:_pan]; }
- (void)didMoveToView:(UIView *)v { _view = v; if (v) [v addGestureRecognizer:_pan]; }
/* adapted: isim's windows fill the screen (or a split view half) and don't move */
- (void)_isim_panned:(UIPanGestureRecognizer *)g {
    if (g.state == UIGestureRecognizerStateEnded) {
        CGPoint t = [g translationInView:_view];
        NSLog(@"isim: window drag %.0f,%.0f (isim's windows don't move)", t.x, t.y);
    }
}
@end

/* ================= screens ================= */
@implementation UIScreenMode { CGSize _size; }
+ (instancetype)_isim_modeWithSize:(CGSize)s { UIScreenMode *m = [self new]; m->_size = s; return m; }
- (CGSize)size { return _size; }
- (CGFloat)pixelAspectRatio { return 1; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[UIScreenMode class]] && CGSizeEqualToSize(((UIScreenMode *)o)->_size, _size); }
- (NSUInteger)hash { return (NSUInteger)(_size.width * 10000 + _size.height); }
- (NSString *)description { return [NSString stringWithFormat:@"<UIScreenMode %gx%g>", _size.width, _size.height]; }
@end
/* portrait-up coordinates of the main screen */
@interface __IsimFixedSpace : NSObject <UICoordinateSpace>
@end
@implementation __IsimFixedSpace
static CGSize portrait_size(void) { CGSize s = UIScreen.mainScreen.bounds.size; return CGSizeMake(fmin(s.width, s.height), fmax(s.width, s.height)); }
- (CGRect)bounds { return (CGRect){ CGPointZero, portrait_size() }; }
static UIInterfaceOrientation orientation(void) { return UIApplication.sharedApplication.statusBarOrientation; }
static CGPoint to_fixed(CGPoint p) {
    CGSize f = portrait_size();
    switch (orientation()) {
        case UIInterfaceOrientationLandscapeRight: return CGPointMake(f.width - p.y, p.x);
        case UIInterfaceOrientationLandscapeLeft: return CGPointMake(p.y, f.height - p.x);
        case UIInterfaceOrientationPortraitUpsideDown: return CGPointMake(f.width - p.x, f.height - p.y);
        default: return p;
    }
}
static CGPoint from_fixed(CGPoint q) {
    CGSize f = portrait_size();
    switch (orientation()) {
        case UIInterfaceOrientationLandscapeRight: return CGPointMake(q.y, f.width - q.x);
        case UIInterfaceOrientationLandscapeLeft: return CGPointMake(f.height - q.y, q.x);
        case UIInterfaceOrientationPortraitUpsideDown: return CGPointMake(f.width - q.x, f.height - q.y);
        default: return q;
    }
}
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id<UICoordinateSpace>)s { return [UIScreen.mainScreen.coordinateSpace convertPoint:from_fixed(p) toCoordinateSpace:s]; }
- (CGPoint)convertPoint:(CGPoint)p fromCoordinateSpace:(id<UICoordinateSpace>)s { return to_fixed([UIScreen.mainScreen.coordinateSpace convertPoint:p fromCoordinateSpace:s]); }
- (CGRect)convertRect:(CGRect)r toCoordinateSpace:(id<UICoordinateSpace>)s { return isim_ui_space_convert_rect(self, r, s, YES); }
- (CGRect)convertRect:(CGRect)r fromCoordinateSpace:(id<UICoordinateSpace>)s { return isim_ui_space_convert_rect(self, r, s, NO); }
@end
static char k_mode, k_overscan, k_dimming;
@implementation UIScreen (UISceneExtras)
- (UIScreenMode *)_isim_nativeMode {
    CGSize b = self.bounds.size; CGFloat sc = self.scale;
    CGSize px = CGSizeMake(fmin(b.width, b.height) * sc, fmax(b.width, b.height) * sc);
    if (self != UIScreen.mainScreen) px = CGSizeMake(b.width * sc, b.height * sc);     /* external displays: landscape */
    return [UIScreenMode _isim_modeWithSize:px];
}
- (NSArray<UIScreenMode *> *)availableModes { return @[[self _isim_nativeMode]]; }
- (UIScreenMode *)preferredMode { return [self _isim_nativeMode]; }
- (UIScreenMode *)currentMode { return objc_getAssociatedObject(self, &k_mode) ?: [self _isim_nativeMode]; }
/* adapted: the only mode is the native one; setting another is logged */
- (void)setCurrentMode:(UIScreenMode *)m {
    if (m && ![m isEqual:[self _isim_nativeMode]]) { NSLog(@"isim: screen mode %@ is not available", m); return; }
    objc_setAssociatedObject(self, &k_mode, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (UIScreen *)mirroredScreen { return nil; }
- (UIScreenOverscanCompensation)overscanCompensation { return [objc_getAssociatedObject(self, &k_overscan) integerValue]; }
- (void)setOverscanCompensation:(UIScreenOverscanCompensation)o { objc_setAssociatedObject(self, &k_overscan, @(o), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (UIEdgeInsets)overscanCompensationInsets { return UIEdgeInsetsZero; }     /* isim's displays have no overscan */
- (CFTimeInterval)calibratedLatency { return 0; }
- (CGFloat)currentEDRHeadroom { return 1; }
- (CGFloat)potentialEDRHeadroom { return 1; }
- (id<UICoordinateSpace>)fixedCoordinateSpace {
    static __IsimFixedSpace *s; if (!s) s = [__IsimFixedSpace new];
    return s;
}
- (UIScreenReferenceDisplayModeStatus)referenceDisplayModeStatus { return UIScreenReferenceDisplayModeStatusNotSupported; }
- (BOOL)wantsSoftwareDimming { return [objc_getAssociatedObject(self, &k_dimming) boolValue]; }
- (void)setWantsSoftwareDimming:(BOOL)b { objc_setAssociatedObject(self, &k_dimming, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end

/* ================= windows ================= */
@implementation UIResponder (UISceneExtras)
- (NSUndoManager *)undoManager { return self.nextResponder.undoManager; }
@end
/* the largest rect of the aspect ratio inside the safe area, centred (constraints to the safe area guide) */
@interface __IsimAspectFitGuide : UILayoutGuide <UILayoutGuideAspectFitting>
@property (nonatomic, strong) NSArray<NSLayoutConstraint *> *isimRatio;
@end
@implementation __IsimAspectFitGuide { CGFloat _aspectRatio; }
- (CGFloat)aspectRatio { return _aspectRatio; }
- (void)setAspectRatio:(CGFloat)r {
    _aspectRatio = r;
    [NSLayoutConstraint deactivateConstraints:_isimRatio ?: @[]];
    UILayoutGuide *safe = self.owningView.safeAreaLayoutGuide;
    if (!safe) { _isimRatio = nil; return; }
    NSMutableArray *c = [NSMutableArray array];
    if (r > 0) {
        [c addObject:[self.widthAnchor constraintEqualToAnchor:self.heightAnchor multiplier:r]];
        NSLayoutConstraint *w = [self.widthAnchor constraintEqualToAnchor:safe.widthAnchor]; w.priority = UILayoutPriorityDefaultHigh;
        NSLayoutConstraint *h = [self.heightAnchor constraintEqualToAnchor:safe.heightAnchor]; h.priority = UILayoutPriorityDefaultHigh;
        [c addObjectsFromArray:@[w, h]];
    } else {
        [c addObjectsFromArray:@[[self.widthAnchor constraintEqualToAnchor:safe.widthAnchor], [self.heightAnchor constraintEqualToAnchor:safe.heightAnchor]]];
    }
    _isimRatio = c;
    [NSLayoutConstraint activateConstraints:c];
    [self.owningView setNeedsLayout];
}
@end
static char k_aspect, k_resize;
@implementation UIWindow (UISceneExtras)
- (UILayoutGuide<UILayoutGuideAspectFitting> *)safeAreaAspectFitLayoutGuide {
    __IsimAspectFitGuide *g = objc_getAssociatedObject(self, &k_aspect);
    if (g) return g;
    g = [__IsimAspectFitGuide new];
    g.identifier = @"UIWindowSafeAreaAspectFitLayoutGuide";
    objc_setAssociatedObject(self, &k_aspect, g, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addLayoutGuide:g];
    UILayoutGuide *safe = self.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [g.centerXAnchor constraintEqualToAnchor:safe.centerXAnchor], [g.centerYAnchor constraintEqualToAnchor:safe.centerYAnchor],
        [g.widthAnchor constraintLessThanOrEqualToAnchor:safe.widthAnchor], [g.heightAnchor constraintLessThanOrEqualToAnchor:safe.heightAnchor]]];
    g.aspectRatio = 0;
    return g;
}
- (NSUndoManager *)undoManager {
    static char k_undo;
    NSUndoManager *u = objc_getAssociatedObject(self, &k_undo);
    if (!u) { u = [NSUndoManager new]; objc_setAssociatedObject(self, &k_undo, u, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    return u;
}
- (BOOL)canResizeToFitContent { return [objc_getAssociatedObject(self, &k_resize) boolValue]; }
- (void)setCanResizeToFitContent:(BOOL)b { objc_setAssociatedObject(self, &k_resize, @(b), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@end
