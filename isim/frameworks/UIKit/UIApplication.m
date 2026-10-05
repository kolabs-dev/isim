/* isim UIKit: touches/events, screen, window, view controllers, scenes, UIApplication and
 * UIApplicationMain with the simulator event/render loop (ARC). */
#import "UIKitPrivate.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>

/* ================= UITouch / UIEvent ================= */
@interface UITouch ()
@property (nonatomic, readwrite) NSTimeInterval timestamp;
@property (nonatomic, readwrite) UITouchPhase phase;
@property (nonatomic, readwrite) NSUInteger tapCount;
@property (nonatomic, readwrite, strong) UIWindow *window;
@property (nonatomic, readwrite, strong) UIView *view;
@property (nonatomic) CGPoint loc, prev;
@end
@implementation UITouch
- (instancetype)initWithIsimView:(UIView *)v window:(UIWindow *)w location:(CGPoint)p time:(NSTimeInterval)t {
    if ((self = [super init])) { _view = v; _window = w; _loc = _prev = p; _timestamp = t; _phase = UITouchPhaseBegan; _tapCount = 1; }
    return self;
}
- (void)_isim_setPhase:(UITouchPhase)ph location:(CGPoint)p time:(NSTimeInterval)t { _phase = ph; _prev = _loc; _loc = p; _timestamp = t; }
- (void)_isim_setView:(UIView *)v { _view = v; }
- (UITouchType)type { return UITouchTypeDirect; }
- (CGPoint)locationInView:(UIView *)v { return v ? [v _isim_fromWindow:_loc] : _loc; }
- (CGPoint)previousLocationInView:(UIView *)v { return v ? [v _isim_fromWindow:_prev] : _prev; }
@end

@interface UIEvent ()
@property (nonatomic, strong) NSSet *touchSet;
@end
@implementation UIEvent
- (instancetype)initWithIsimTouch:(UITouch *)t { if ((self = [super init])) _touchSet = [NSSet setWithObject:t]; return self; }
- (UIEventType)type { return UIEventTypeTouches; }
- (NSTimeInterval)timestamp { return [_touchSet.anyObject timestamp]; }
- (NSSet *)allTouches { return _touchSet; }
- (NSSet *)touchesForView:(UIView *)v { UITouch *t = _touchSet.anyObject; return [t.view isDescendantOfView:v] ? _touchSet : nil; }
- (NSSet *)touchesForWindow:(UIWindow *)w { UITouch *t = _touchSet.anyObject; return t.window == w ? _touchSet : nil; }
@end

/* ================= UIScreen ================= */
@implementation UIScreen
+ (UIScreen *)mainScreen { static UIScreen *s; if (!s) s = [UIScreen new]; return s; }
- (CGRect)bounds { const struct isim_device *d = isim_ui_device(); return CGRectMake(0, 0, d->width, d->height); }
- (CGRect)nativeBounds { CGRect b = self.bounds; CGFloat s = self.scale; return CGRectMake(0, 0, b.size.width * s, b.size.height * s); }
- (CGFloat)scale { return isim_ui_device()->scale; }
- (CGFloat)nativeScale { return self.scale; }
- (NSInteger)maximumFramesPerSecond { return 60; }
- (id<UICoordinateSpace>)coordinateSpace { return (id<UICoordinateSpace>)UIApplication.sharedApplication.keyWindow; }
- (UITraitCollection *)traitCollection { return [UITraitCollection traitCollectionWithUserInterfaceStyle:isim_ui_style()]; }
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
@end

/* ================= UIViewController ================= */
@interface UIViewController () {
    UIView *_view;
    NSMutableArray<UIViewController *> *_children;
    __weak UIViewController *_parent;
    UIViewController *_presented;
    __weak UIViewController *_presenting;
    UINavigationItem *_navItem;
    int _appearance;   /* 0 none, 1 will appear, 2 appeared */
}
@end
@implementation UIViewController
- (instancetype)init { return [self initWithNibName:nil bundle:nil]; }
- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)b {
    if ((self = [super init])) {
        _children = [NSMutableArray array];
        if (nib) NSLog(@"isim: nib '%@' ignored (nib/storyboard loading is not implemented)", nib);
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithNibName:nil bundle:nil]; }
- (UIView *)view {
    if (!_view) {
        [self loadView];
        if (!_view) [NSException raise:NSInternalInconsistencyException format:@"-[%@ loadView] did not set a view", [self class]];
        [_view _isim_setViewController:self];
        [self viewDidLoad];
    }
    return _view;
}
- (void)setView:(UIView *)v { [_view _isim_setViewController:nil]; _view = v; [v _isim_setViewController:self]; }
- (void)loadView {
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
    self.view = v;
}
- (void)loadViewIfNeeded { (void)self.view; }
- (UIView *)viewIfLoaded { return _view; }
- (BOOL)isViewLoaded { return _view != nil; }
- (void)viewDidLoad {}
- (NSString *)nibName { return nil; }
- (NSBundle *)nibBundle { return nil; }
- (void)viewWillAppear:(BOOL)a {}
- (void)viewDidAppear:(BOOL)a {}
- (void)viewWillDisappear:(BOOL)a {}
- (void)viewDidDisappear:(BOOL)a {}
- (void)viewWillLayoutSubviews {}
- (void)viewDidLayoutSubviews {}
- (void)updateViewConstraints {}
- (void)didReceiveMemoryWarning {}
- (void)setTitle:(NSString *)t { _title = [t copy]; self.navigationItem.title = t; }
- (UINavigationItem *)navigationItem { if (!_navItem) _navItem = [UINavigationItem new]; return _navItem; }
- (UIResponder *)nextResponder { return _view.superview ?: (UIResponder *)_parent; }
- (UITraitCollection *)traitCollection { return _view ? _view.traitCollection : [UITraitCollection currentTraitCollection]; }
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)s { _overrideUserInterfaceStyle = s; self.view.overrideUserInterfaceStyle = s; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleDefault; }
- (BOOL)prefersStatusBarHidden { return NO; }
- (void)setNeedsStatusBarAppearanceUpdate { isim_ui_set_needs_display(); }

/* appearance callbacks, propagated to children */
- (void)_isim_appear:(BOOL)visible {
    if (visible && _appearance == 0) { _appearance = 1; [self viewWillAppear:NO]; for (UIViewController *c in _children) [c _isim_appear:YES]; }
    else if (!visible && _appearance) { [self viewWillDisappear:NO]; _appearance = 0; for (UIViewController *c in _children) [c _isim_appear:NO]; [self viewDidDisappear:NO]; }
}
- (void)_isim_didAppear { if (_appearance == 1) { _appearance = 2; [self viewDidAppear:NO]; for (UIViewController *c in _children) [c _isim_didAppear]; } [_presented _isim_didAppear]; }

/* containment */
- (UIViewController *)parentViewController { return _parent; }
- (NSArray *)childViewControllers { return [_children copy]; }
- (void)_isim_setParent:(UIViewController *)p { _parent = p; }
- (void)addChildViewController:(UIViewController *)c {
    if (c->_parent == self) return;
    [c removeFromParentViewController];
    [c willMoveToParentViewController:self];
    [_children addObject:c]; [c _isim_setParent:self];
}
- (void)removeFromParentViewController { UIViewController *p = _parent; if (p) [p->_children removeObjectIdenticalTo:self]; _parent = nil; }
- (void)willMoveToParentViewController:(UIViewController *)p {}
- (void)didMoveToParentViewController:(UIViewController *)p {}

/* modal presentation: full-screen cover inside the presenter's window */
- (UIViewController *)presentedViewController { return _presented; }
- (UIViewController *)presentingViewController { return _presenting; }
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)a completion:(void (^)(void))done {
    if (_presented) { [_presented presentViewController:vc animated:a completion:done]; return; }
    UIWindow *w = _view.window;
    if (!w) { NSLog(@"isim: presentViewController: presenter is not in a window"); return; }
    _presented = vc; vc->_presenting = self;
    UIView *v = vc.view;
    v.frame = w.bounds; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    if (!v.backgroundColor) v.backgroundColor = UIColor.systemBackgroundColor;
    [vc _isim_appear:YES];
    [w addSubview:v];
    dispatch_async(dispatch_get_main_queue(), ^{ [vc _isim_didAppear]; if (done) done(); });
}
- (void)dismissViewControllerAnimated:(BOOL)a completion:(void (^)(void))done {
    UIViewController *target = _presented ?: self;
    UIViewController *presenter = _presented ? self : _presenting;
    [target _isim_appear:NO];
    [target.view removeFromSuperview];
    if (presenter) { presenter->_presented = nil; target->_presenting = nil; }
    if (done) dispatch_async(dispatch_get_main_queue(), done);
}
@end
@implementation UINavigationItem @end

@interface UIWindowScene (IsimWindows)
- (NSMutableArray *)valueForKey_isimWindows;
@end
@interface UITouch (IsimTap)
- (void)setValue_isimTapCount:(NSUInteger)n;
@end

/* ================= UIWindow ================= */
const UIWindowLevel UIWindowLevelNormal = 0, UIWindowLevelAlert = 2000, UIWindowLevelStatusBar = 1000;
@implementation UIWindow
- (instancetype)initWithFrame:(CGRect)f {
    if ((self = [super initWithFrame:f])) { self.screen = UIScreen.mainScreen; self.hidden = YES; [UIApplication.sharedApplication _isim_addWindow:self]; [self _isim_movedToWindow:self]; }
    return self;
}
- (instancetype)initWithWindowScene:(UIWindowScene *)scene {
    if ((self = [self initWithFrame:UIScreen.mainScreen.bounds])) self.windowScene = scene;
    return self;
}
- (void)setWindowScene:(UIWindowScene *)s {
    _windowScene = s;
    NSMutableArray *list = [s valueForKey_isimWindows];
    if (list && [list indexOfObjectIdenticalTo:self] == NSNotFound) [list addObject:self];
}
- (UIWindow *)window { return self; }
- (UIEdgeInsets)safeAreaInsets { const struct isim_device *d = isim_ui_device(); return UIEdgeInsetsMake(d->safe_top, 0, d->safe_bottom, 0); }
- (BOOL)isKeyWindow { return UIApplication.sharedApplication.keyWindow == self; }
- (BOOL)canBecomeKeyWindow { return YES; }
- (void)becomeKeyWindow {}
- (void)resignKeyWindow {}
- (void)makeKeyWindow { [UIApplication.sharedApplication _isim_windowBecameKey:self]; }
- (void)makeKeyAndVisible {
    self.hidden = NO;
    [self makeKeyWindow];
    [_rootViewController _isim_appear:YES];
    [self setNeedsLayout];
    UIViewController *root = _rootViewController;
    dispatch_async(dispatch_get_main_queue(), ^{ [root _isim_didAppear]; });
}
- (void)setRootViewController:(UIViewController *)vc {
    if (vc == _rootViewController) return;
    UIViewController *old = _rootViewController;
    if (old.isViewLoaded) { if (!self.hidden) [old _isim_appear:NO]; [old.view removeFromSuperview]; }
    _rootViewController = vc;
    if (!vc) return;
    UIView *v = vc.view;
    v.frame = self.bounds;
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:v atIndex:0];
    if (!self.hidden) { [vc _isim_appear:YES]; dispatch_async(dispatch_get_main_queue(), ^{ [vc _isim_didAppear]; }); }
}
- (UIResponder *)nextResponder { return (UIResponder *)_windowScene ?: (UIResponder *)UIApplication.sharedApplication; }
- (void)sendEvent:(UIEvent *)e {}
- (void)_isim_renderFrame { [self _isim_render]; }
@end

/* ================= scenes ================= */
UISceneSessionRole const UIWindowSceneSessionRoleApplication = @"UIWindowSceneSessionRoleApplication";
NSNotificationName const UISceneWillConnectNotification = @"UISceneWillConnectNotification";
NSNotificationName const UISceneDidActivateNotification = @"UISceneDidActivateNotification";

@interface UISceneSession ()
@property (nonatomic, readwrite, weak) UIScene *scene;
@property (nonatomic, readwrite) UISceneSessionRole role;
@property (nonatomic, readwrite, copy) UISceneConfiguration *configuration;
@property (nonatomic, readwrite) NSString *persistentIdentifier;
@end
@implementation UISceneSession @end
@implementation UISceneConnectionOptions
- (NSSet *)URLContexts { return [NSSet set]; }
- (NSSet *)userActivities { return [NSSet set]; }
@end
@implementation UISceneConfiguration
+ (instancetype)configurationWithName:(NSString *)n sessionRole:(UISceneSessionRole)r { return [[self alloc] initWithName:n sessionRole:r]; }
- (instancetype)initWithName:(NSString *)n sessionRole:(UISceneSessionRole)r { if ((self = [super init])) { _name = [n copy]; _role = [r copy]; } return self; }
- (id)copyWithZone:(NSZone *)z { UISceneConfiguration *c = [[UISceneConfiguration alloc] initWithName:_name sessionRole:_role]; c.sceneClass = _sceneClass; c.delegateClass = _delegateClass; c.storyboard = _storyboard; return c; }
@end

@interface UIScene ()
@property (nonatomic, readwrite) UISceneSession *session;
@property (nonatomic, readwrite) UISceneActivationState activationState;
@end
@implementation UIScene
- (instancetype)initWithSession:(UISceneSession *)s connectionOptions:(UISceneConnectionOptions *)o {
    if ((self = [super init])) { _session = s; _activationState = UISceneActivationStateUnattached; _title = @""; }
    return self;
}
- (UIResponder *)nextResponder { return UIApplication.sharedApplication; }
@end
@implementation UIWindowScene { NSMutableArray<UIWindow *> *_windows; }
- (NSMutableArray *)valueForKey_isimWindows { if (!_windows) _windows = [NSMutableArray array]; return _windows; }
- (UIScreen *)screen { return UIScreen.mainScreen; }
- (NSArray *)windows { return [_windows copy] ?: @[]; }
- (UIWindow *)keyWindow { for (UIWindow *w in _windows) if (w.isKeyWindow) return w; return nil; }
- (UITraitCollection *)traitCollection { return [UITraitCollection currentTraitCollection]; }
- (id)coordinateSpace { return UIScreen.mainScreen.coordinateSpace; }
@end

/* ================= UIApplication ================= */
NSNotificationName const UIApplicationDidFinishLaunchingNotification = @"UIApplicationDidFinishLaunchingNotification",
    UIApplicationDidBecomeActiveNotification = @"UIApplicationDidBecomeActiveNotification",
    UIApplicationWillResignActiveNotification = @"UIApplicationWillResignActiveNotification",
    UIApplicationDidEnterBackgroundNotification = @"UIApplicationDidEnterBackgroundNotification",
    UIApplicationWillEnterForegroundNotification = @"UIApplicationWillEnterForegroundNotification",
    UIApplicationWillTerminateNotification = @"UIApplicationWillTerminateNotification";

static UIApplication *shared_app;
@interface UIApplication ()
@property (nonatomic, strong) id strongDelegate;
@property (nonatomic, readwrite) UIApplicationState applicationState;
@end
@implementation UIApplication {
    NSMutableArray<UIWindow *> *_allWindows;    /* isim: strong (Apple keeps windows weakly) */
    __weak UIWindow *_key;
    NSMutableSet<UIScene *> *_scenes;
    NSMutableSet<UISceneSession *> *_sessions;
}
+ (UIApplication *)sharedApplication { return shared_app; }
- (instancetype)init {
    if ((self = [super init])) { _allWindows = [NSMutableArray array]; _scenes = [NSMutableSet set]; _sessions = [NSMutableSet set]; _applicationState = UIApplicationStateInactive; if (!shared_app) shared_app = self; }
    return self;
}
- (void)_isim_addWindow:(UIWindow *)w { if ([_allWindows indexOfObjectIdenticalTo:w] == NSNotFound) [_allWindows addObject:w]; }
- (void)_isim_windowBecameKey:(UIWindow *)w { UIWindow *old = _key; if (old == w) return; [old resignKeyWindow]; _key = w; [w becomeKeyWindow]; isim_ui_set_needs_display(); }
- (UIWindow *)keyWindow { return _key; }
- (NSArray *)windows { return [_allWindows copy]; }
- (NSSet *)connectedScenes { return [_scenes copy]; }
- (NSSet *)openSessions { return [_sessions copy]; }
- (BOOL)supportsMultipleScenes { return NO; }
- (UIResponder *)nextResponder { return [self.delegate isKindOfClass:[UIResponder class]] ? (UIResponder *)self.delegate : nil; }
- (void)sendEvent:(UIEvent *)e {}
- (void)beginIgnoringInteractionEvents {}
- (void)endIgnoringInteractionEvents {}
- (BOOL)sendAction:(SEL)action to:(id)target from:(id)sender forEvent:(UIEvent *)event {
    if (!target) {
        for (UIResponder *r = [sender isKindOfClass:[UIResponder class]] ? sender : nil; r; r = r.nextResponder)
            if ([r respondsToSelector:action]) { target = r; break; }
    }
    if (!target) return NO;
    ((void (*)(id, SEL, id, id))[target methodForSelector:action])(target, action, sender, event);
    return YES;
}
- (void)_isim_addScene:(UIScene *)s session:(UISceneSession *)ss { [_scenes addObject:s]; [_sessions addObject:ss]; }
@end

/* ================= UIApplicationMain + run loop ================= */
static UITouch *cur_touch;
static NSMutableArray<UIGestureRecognizer *> *cur_gestures;
static NSTimeInterval last_tap_time; static CGPoint last_tap_point;

static UIWindow *top_window(void) {
    UIWindow *best = UIApplication.sharedApplication.keyWindow;
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (!w.hidden && (!best || best.hidden || w.windowLevel > best.windowLevel)) best = w;
    return best && !best.hidden ? best : nil;
}

static UIEvent *cur_event;
static BOOL touch_cancelled;

/* A recognizer that cancels touches in its view just recognized: the hit view gets
 * touchesCancelled once and no further touch callbacks for this sequence. */
void isim_ui_gesture_recognized(UIGestureRecognizer *g) {
    if (!g.cancelsTouchesInView || !cur_touch || touch_cancelled || ![cur_gestures containsObject:g]) return;
    touch_cancelled = YES;
    [cur_touch.view touchesCancelled:cur_event.allTouches withEvent:cur_event];
}

static void handle_touch(const struct isim_event *ev) {
    CGPoint p = CGPointMake(ev->x, ev->y);
    if (ev->type == ISIM_EV_TOUCH_DOWN) {
        UIWindow *w = top_window();
        UIView *hit = [w hitTest:p withEvent:nil];
        if (!hit) { cur_touch = nil; return; }
        cur_touch = [[UITouch alloc] initWithIsimView:hit window:w location:p time:ev->timestamp];
        if (ev->timestamp - last_tap_time < 0.35 && hypot(p.x - last_tap_point.x, p.y - last_tap_point.y) < 20) [cur_touch setValue_isimTapCount:2];
        cur_gestures = [NSMutableArray array];
        touch_cancelled = NO;
        for (UIView *v = hit; v; v = v.superview) for (UIGestureRecognizer *g in v.gestureRecognizers) if (g.enabled) [cur_gestures addObject:g];
    }
    UITouch *t = cur_touch;
    if (!t) return;
    UITouchPhase phase = ev->type == ISIM_EV_TOUCH_DOWN ? UITouchPhaseBegan : ev->type == ISIM_EV_TOUCH_MOVE ? UITouchPhaseMoved : UITouchPhaseEnded;
    [t _isim_setPhase:phase location:p time:ev->timestamp];
    UIEvent *e = [[UIEvent alloc] initWithIsimTouch:t];
    cur_event = e;
    NSSet *set = e.allTouches;
    UIView *v = t.view;
    /* Began reaches the view before recognizers act on it, as on iOS (no delaysTouchesBegan). */
    if (phase == UITouchPhaseBegan) [v touchesBegan:set withEvent:e];
    for (UIGestureRecognizer *g in [cur_gestures copy]) [g _isim_touch:t phase:phase event:e];
    if (!touch_cancelled) {
        if (phase == UITouchPhaseMoved) [v touchesMoved:set withEvent:e];
        else if (phase == UITouchPhaseEnded) [v touchesEnded:set withEvent:e];
    }
    if (phase == UITouchPhaseEnded) { last_tap_time = ev->timestamp; last_tap_point = p; cur_touch = nil; cur_gestures = nil; cur_event = nil; }
}

/* hardware keyboard / scripted typing goes to the first responder if it accepts key input */
static void handle_key(const struct isim_event *ev) {
    id fr = isim_ui_first_responder();
    if (![fr respondsToSelector:@selector(insertText:)]) return;
    if (ev->type == ISIM_EV_TEXT) [fr insertText:@(ev->text)];
    else if (ev->key == 8) [fr deleteBackward];
    else if (ev->key == 13) [fr insertText:@"\n"];
    else if (ev->key == 9) [fr insertText:@"\t"];
    isim_ui_set_needs_display();
}

static void dump_view(UIView *v, int depth) {
    CGRect f = v.frame;
    NSString *ident = v.accessibilityIdentifier, *label = [v isKindOfClass:[UILabel class]] ? ((UILabel *)v).text : [v isKindOfClass:[UIButton class]] ? ((UIButton *)v).currentTitle : nil;
    fprintf(stderr, "%*s%s (%g %g; %g x %g)%s%s%s%s%s%s\n", depth * 2, "", class_getName(object_getClass(v)), f.origin.x, f.origin.y, f.size.width, f.size.height,
            v.hidden ? " hidden" : "", v.alpha < 1 ? " alpha<1" : "", ident ? " id=" : "", ident ? ident.UTF8String : "", label ? " text=" : "", label ? label.UTF8String : "");
    for (UIView *s in v.subviews) dump_view(s, depth + 1);
}

/* scripted touches addressed by accessibilityIdentifier (ISIM_SCRIPT tapid/holdid) */
static UIView *find_identified(UIView *v, NSString *ident) {
    if (v.hidden || v.alpha <= 0.01) return nil;
    for (UIView *s in v.subviews.reverseObjectEnumerator) { UIView *f = find_identified(s, ident); if (f) return f; }
    return [v.accessibilityIdentifier isEqualToString:ident] ? v : nil;
}
static void handle_id_touch(const struct isim_event *ev) {
    NSString *ident = @(ev->text);
    UIView *found = nil;
    NSArray *windows = UIApplication.sharedApplication.windows;
    for (UIWindow *w in windows.reverseObjectEnumerator) if (!w.hidden && (found = find_identified(w, ident))) break;
    if (!found) { NSLog(@"isim: no visible view with accessibilityIdentifier '%@'", ident); return; }
    CGRect b = found.bounds;
    CGPoint p = [found convertPoint:CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b)) toView:nil];
    p = [found.window convertPoint:p toView:nil];
    struct isim_event t = *ev;
    t.type = ev->type == ISIM_EV_ID_DOWN ? ISIM_EV_TOUCH_DOWN : ISIM_EV_TOUCH_UP;
    t.x = p.x + found.window.frame.origin.x; t.y = p.y + found.window.frame.origin.y;
    handle_touch(&t);
}

@implementation UITouch (IsimTap)
- (void)setValue_isimTapCount:(NSUInteger)n { self.tapCount = n; }
@end

static void render_frame(void) {
    UIWindow *key = top_window();
    UIViewController *vc = key.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    UIStatusBarStyle st = vc ? vc.preferredStatusBarStyle : UIStatusBarStyleDefault;
    UIView *styleSource = vc.viewIfLoaded ?: key;
    BOOL dark = (styleSource ? styleSource.traitCollection.userInterfaceStyle : isim_ui_style()) == UIUserInterfaceStyleDark;
    isim_set_status_bar_style(st == UIStatusBarStyleLightContent ? 0 : st == UIStatusBarStyleDarkContent ? 1 : !dark);
    isim_frame_begin();
    NSArray *ws = [UIApplication.sharedApplication.windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
        return a.windowLevel < b.windowLevel ? NSOrderedAscending : a.windowLevel > b.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
    for (UIWindow *w in ws) if (!w.hidden) [w _isim_renderFrame];
    isim_frame_end();
}

static void layout_all(void) {
    for (int i = 0; i < 4 && isim_ui_take_layout(); i++)
        for (UIWindow *w in UIApplication.sharedApplication.windows) { isim_ui_layout_window(w); [w _isim_layoutPass]; }
}

static Class class_named(NSString *name) {
    if (!name.length) return Nil;
    Class c = NSClassFromString(name);
    if (!c) NSLog(@"isim: class '%@' not found", name);
    return c;
}

static void connect_scene(UIApplication *app, NSDictionary *manifest) {
    NSDictionary *configs = manifest[@"UISceneConfigurations"];
    NSArray *roleConfigs = configs[UIWindowSceneSessionRoleApplication];
    UISceneSession *session = [UISceneSession new];
    session.role = UIWindowSceneSessionRoleApplication;
    session.persistentIdentifier = [NSString stringWithFormat:@"isim-%08X", arc4random()];
    UISceneConnectionOptions *options = [UISceneConnectionOptions new];
    UISceneConfiguration *config = nil;
    id<UIApplicationDelegate> d = app.delegate;
    if ([d respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)])
        config = [d application:app configurationForConnectingSceneSession:session options:options];
    NSDictionary *plistConfig = roleConfigs.firstObject;
    for (NSDictionary *pc in roleConfigs) if (config.name && [pc[@"UISceneConfigurationName"] isEqualToString:config.name]) plistConfig = pc;
    if (!config) config = [UISceneConfiguration configurationWithName:plistConfig[@"UISceneConfigurationName"] sessionRole:UIWindowSceneSessionRoleApplication];
    if (!config.delegateClass) config.delegateClass = class_named(plistConfig[@"UISceneDelegateClassName"]);
    if (!config.sceneClass) config.sceneClass = class_named(plistConfig[@"UISceneClassName"]) ?: [UIWindowScene class];
    if (plistConfig[@"UISceneStoryboardFile"]) NSLog(@"isim: UISceneStoryboardFile '%@' ignored (storyboards are not implemented)", plistConfig[@"UISceneStoryboardFile"]);
    session.configuration = config;
    UIScene *scene = [[config.sceneClass alloc] initWithSession:session connectionOptions:options];
    session.scene = scene;
    [app _isim_addScene:scene session:session];
    if (config.delegateClass) scene.delegate = [config.delegateClass new];
    id<UISceneDelegate> sd = scene.delegate;
    [NSNotificationCenter.defaultCenter postNotificationName:UISceneWillConnectNotification object:scene];
    if ([sd respondsToSelector:@selector(scene:willConnectToSession:options:)]) [sd scene:scene willConnectToSession:session options:options];
    scene.activationState = UISceneActivationStateForegroundInactive;
    if ([sd respondsToSelector:@selector(sceneWillEnterForeground:)]) [sd sceneWillEnterForeground:scene];
    scene.activationState = UISceneActivationStateForegroundActive;
    if ([sd respondsToSelector:@selector(sceneDidBecomeActive:)]) [sd sceneDidBecomeActive:scene];
    [NSNotificationCenter.defaultCenter postNotificationName:UISceneDidActivateNotification object:scene];
}

int UIApplicationMain(int argc, char *argv[], NSString *principalClassName, NSString *delegateClassName) {
    @autoreleasepool {
        NSBundle *bundle = NSBundle.mainBundle;
        NSDictionary *info = bundle.infoDictionary;
        Class appClass = class_named(principalClassName ?: info[@"NSPrincipalClass"]) ?: [UIApplication class];
        UIApplication *app = [appClass new];
        shared_app = app;
        Class delegateClass = class_named(delegateClassName);
        if (delegateClass) { app.strongDelegate = [delegateClass new]; app.delegate = app.strongDelegate; }
        NSString *title = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: info[@"CFBundleExecutable"] ?: @"App";
        isim_display_open(title.UTF8String);
        NSLog(@"isim: launching %@ (%@) on %s", title, bundle.bundleIdentifier ?: @"no bundle id", isim_ui_device()->name);

        id<UIApplicationDelegate> d = app.delegate;
        if ([d respondsToSelector:@selector(application:willFinishLaunchingWithOptions:)]) [d application:app willFinishLaunchingWithOptions:nil];
        if ([d respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) [d application:app didFinishLaunchingWithOptions:nil];
        else if ([d respondsToSelector:@selector(applicationDidFinishLaunching:)]) [d applicationDidFinishLaunching:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidFinishLaunchingNotification object:app];

        NSDictionary *manifest = info[@"UIApplicationSceneManifest"];
        if (manifest) connect_scene(app, manifest);
        else if ([d respondsToSelector:@selector(window)] && d.window && d.window.hidden) [d.window makeKeyAndVisible];
        app.applicationState = UIApplicationStateActive;
        if ([d respondsToSelector:@selector(applicationDidBecomeActive:)]) [d applicationDidBecomeActive:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:app];
    }

    int lastMinute = -1;
    for (BOOL quit = NO; !quit;) {
        @autoreleasepool {
            NSTimeInterval next = [NSRunLoop.mainRunLoop _isim_fireDue];
            layout_all();
            time_t now = time(NULL); struct tm tm; localtime_r(&now, &tm);
            if (tm.tm_min != lastMinute) { lastMinute = tm.tm_min; isim_ui_set_needs_display(); }
            if (isim_ui_take_display()) { layout_all(); render_frame(); }
            double timeout = next < 0.5 ? next : 0.5;
            struct isim_event ev;
            for (int got = isim_next_event(&ev, timeout); got; got = isim_next_event(&ev, 0)) {
                switch (ev.type) {
                case ISIM_EV_QUIT: quit = YES; break;
                case ISIM_EV_TOUCH_DOWN: case ISIM_EV_TOUCH_MOVE: case ISIM_EV_TOUCH_UP: handle_touch(&ev); break;
                case ISIM_EV_REDRAW: isim_ui_set_needs_display(); break;
                case ISIM_EV_TEXT: case ISIM_EV_KEY: handle_key(&ev); break;
                case ISIM_EV_ID_DOWN: case ISIM_EV_ID_UP: handle_id_touch(&ev); break;
                case ISIM_EV_DUMP: layout_all(); for (UIWindow *w in UIApplication.sharedApplication.windows) dump_view(w, 0); break;
                default: break;
                }
                if (quit) break;
            }
        }
    }
    @autoreleasepool {
        UIApplication *app = UIApplication.sharedApplication;
        id<UIApplicationDelegate> d = app.delegate;
        for (UIScene *s in app.connectedScenes) if ([s.delegate respondsToSelector:@selector(sceneDidDisconnect:)]) [s.delegate sceneDidDisconnect:s];
        if ([d respondsToSelector:@selector(applicationWillTerminate:)]) [d applicationWillTerminate:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillTerminateNotification object:app];
        NSLog(@"isim: application terminated");
    }
    exit(0);
}
