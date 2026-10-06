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
@implementation UIDevice
+ (UIDevice *)currentDevice { static UIDevice *d; if (!d) d = [UIDevice new]; return d; }
- (BOOL)_pad { return isim_ui_device()->width >= 700; }
- (NSString *)name { return [self _pad] ? @"iPad" : @"iPhone"; }
- (NSString *)model { return [self _pad] ? @"iPad" : @"iPhone"; }
- (NSString *)localizedModel { return self.model; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)systemVersion { const char *v = getenv("ISIM_OS_VERSION"); return v && *v ? @(v) : @"18.0"; }
- (UIDeviceOrientation)orientation { return UIDeviceOrientationPortrait; }
- (UIUserInterfaceIdiom)userInterfaceIdiom { return [self _pad] ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone; }
- (BOOL)isMultitaskingSupported { return YES; }
- (NSString *)_isim_deviceName { return @(isim_ui_device()->name); }
@end

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
    UIView *_sheetContainer, *_sheetDim, *_sheetBehind;       /* page-sheet presentation */
    UIColor *_sheetWindowBG; BOOL _sheetBehindClipped; CGFloat _sheetBehindRadius;
}
@end

/* iPhone page sheet: a card below the status bar; the presenter shrinks behind it (iOS 13+ card stack).
   Dragging the sheet's top area down dismisses it, unless isModalInPresentation. */
@interface __IsimSheetPan : UIPanGestureRecognizer
@property (nonatomic, weak) UIViewController *sheetController;
@end
@implementation UIViewController
- (instancetype)init { return [self initWithNibName:nil bundle:nil]; }
- (instancetype)initWithNibName:(NSString *)nib bundle:(NSBundle *)b {
    if ((self = [super init])) {
        _children = [NSMutableArray array];
        _modalPresentationStyle = UIModalPresentationAutomatic;      /* iOS 13+: a page sheet on iPhone */
        if (nib) NSLog(@"isim: nib '%@' ignored (nib/storyboard loading is not implemented)", nib);
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithNibName:nil bundle:nil]; }
- (void)encodeWithCoder:(NSCoder *)c {}   /* isim: archiving is not implemented */
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
- (void)setAdditionalSafeAreaInsets:(UIEdgeInsets)i {
    if (UIEdgeInsetsEqualToEdgeInsets(i, _additionalSafeAreaInsets)) return;
    _additionalSafeAreaInsets = i;
    isim_ui_constraints_changed(); [_view setNeedsLayout]; isim_ui_set_needs_layout();
    [self viewSafeAreaInsetsDidChange];
}
- (void)viewSafeAreaInsetsDidChange {}
- (UIResponder *)nextResponder { return _view.superview ?: (UIResponder *)_parent; }
- (UITraitCollection *)traitCollection { return _view ? _view.traitCollection : [UITraitCollection currentTraitCollection]; }
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)s { _overrideUserInterfaceStyle = s; self.view.overrideUserInterfaceStyle = s; }
- (UIStatusBarStyle)preferredStatusBarStyle { return UIStatusBarStyleDefault; }
- (BOOL)prefersStatusBarHidden { return NO; }
- (void)setNeedsStatusBarAppearanceUpdate { isim_ui_set_needs_display(); }

/* appearance callbacks, propagated to children */
/* containers (navigation/tab controllers) forward appearance only to the children on screen */
- (NSArray<UIViewController *> *)_isim_visibleChildren { return _children; }
- (BOOL)_isim_isVisible { return _appearance != 0; }
- (void)_isim_appear:(BOOL)visible {
    if (visible && _appearance == 0) { _appearance = 1; [self viewWillAppear:NO]; for (UIViewController *c in [self _isim_visibleChildren]) [c _isim_appear:YES]; }
    else if (!visible && _appearance) { [self viewWillDisappear:NO]; _appearance = 0; for (UIViewController *c in _children) [c _isim_appear:NO]; [self viewDidDisappear:NO]; }
}
- (void)_isim_didAppear { if (_appearance == 1) { _appearance = 2; [self viewDidAppear:NO]; for (UIViewController *c in [self _isim_visibleChildren]) [c _isim_didAppear]; } [_presented _isim_didAppear]; }

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

/* modal presentation: page sheets (automatic/pageSheet/formSheet) or full-screen covers in the presenter's window */
- (UIViewController *)presentedViewController { return _presented; }
- (UIViewController *)presentingViewController { return _presenting; }
- (BOOL)_isim_presentsAsSheet {
    if ([self isKindOfClass:NSClassFromString(@"UIAlertController")]) return NO;
    UIModalPresentationStyle st = _modalPresentationStyle;
    return st == UIModalPresentationAutomatic || st == UIModalPresentationPageSheet || st == UIModalPresentationFormSheet;
}
static CGRect sheet_frame(UIViewController *vc, CGRect b) {
    const struct isim_device *d = isim_ui_device();
    if (b.size.width >= 700) {                                    /* iPad: centered card */
        BOOL form = vc.modalPresentationStyle == UIModalPresentationFormSheet;
        CGFloat w = form ? 540 : MIN(b.size.width - 80, 704), h = form ? MIN(620, b.size.height - 80) : b.size.height - 2 * (d->safe_top + 24);
        return CGRectMake((b.size.width - w) / 2, (b.size.height - h) / 2, w, h);
    }
    CGFloat top = d->safe_top + 10;
    return CGRectMake(0, top, b.size.width, b.size.height - top);
}
- (void)presentViewController:(UIViewController *)vc animated:(BOOL)a completion:(void (^)(void))done {
    if (_presented) { [_presented presentViewController:vc animated:a completion:done]; return; }
    UIWindow *w = _view.window;
    if (!w) { NSLog(@"isim: presentViewController: presenter is not in a window"); return; }
    _presented = vc; vc->_presenting = self;
    UIView *v = vc.view;
    if (!v.backgroundColor) v.backgroundColor = UIColor.systemBackgroundColor;
    [vc _isim_appear:YES];
    void (^finish)(BOOL) = ^(BOOL f) { [vc _isim_didAppear]; if (done) done(); };
    if (![vc _isim_presentsAsSheet]) {
        v.frame = w.bounds; v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [w addSubview:v];
        if (a && vc.modalPresentationStyle != UIModalPresentationOverFullScreen && ![vc isKindOfClass:NSClassFromString(@"UIAlertController")]) {
            CGRect end = v.frame;                                 /* full screen: slides up from the bottom */
            [UIView performWithoutAnimation:^{ v.frame = CGRectOffset(end, 0, end.size.height); }];
            isim_ui_animate(0.5, 0, 0, 1, 1.0, 0, ^{ v.frame = end; }, finish);
        } else dispatch_async(dispatch_get_main_queue(), ^{ finish(YES); });
        return;
    }
    CGRect b = w.bounds;
    BOOL phone = b.size.width < 700;
    UIView *container = [[UIView alloc] initWithFrame:b];
    container.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    UIView *dim = [[UIView alloc] initWithFrame:b];
    dim.backgroundColor = UIColor.blackColor; dim.alpha = 0;
    dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [container addSubview:dim];
    CGRect end = sheet_frame(vc, b);
    v.autoresizingMask = UIViewAutoresizingNone;
    v.layer.cornerRadius = 10; v.clipsToBounds = YES;
    [container addSubview:v];
    __IsimSheetPan *pan = [[__IsimSheetPan alloc] initWithTarget:vc action:@selector(_isim_sheetPan:)];
    pan.sheetController = vc;
    [v addGestureRecognizer:pan];
    /* the presenter's top-level view shrinks into a card behind the sheet (iPhone, first sheet level) */
    UIView *behind = _view; while (behind.superview && behind.superview != w) behind = behind.superview;
    BOOL stack = phone && behind.superview == w && !_sheetContainer;
    vc->_sheetContainer = container; vc->_sheetDim = dim; vc->_sheetBehind = stack ? behind : nil;
    if (stack) {
        vc->_sheetWindowBG = w.backgroundColor; vc->_sheetBehindClipped = behind.clipsToBounds; vc->_sheetBehindRadius = behind.layer.cornerRadius;
        w.backgroundColor = UIColor.blackColor;
        behind.clipsToBounds = YES; behind.layer.cornerRadius = 10;
    }
    [w addSubview:container];
    [UIView performWithoutAnimation:^{ v.frame = phone ? CGRectOffset(end, 0, b.size.height - end.origin.y) : CGRectOffset(end, 0, b.size.height); }];
    const struct isim_device *d = isim_ui_device();
    CGFloat sc = (b.size.width - 32) / b.size.width;
    CGFloat ty = (d->safe_top - 6) - b.size.height * (1 - sc) / 2;
    void (^anim)(void) = ^{
        v.frame = end;
        dim.alpha = stack ? 0.12 : 0.3;
        if (stack) behind.transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(sc, sc), 0, ty / sc);
    };
    if (a) isim_ui_animate(0.5, 0, 0, 1, 1.0, 0, anim, finish);
    else { [UIView performWithoutAnimation:anim]; dispatch_async(dispatch_get_main_queue(), ^{ finish(YES); }); }
}
- (void)dismissViewControllerAnimated:(BOOL)a completion:(void (^)(void))done {
    UIViewController *target = _presented ?: self;
    UIViewController *presenter = _presented ? self : _presenting;
    if (target->_presented) { [target dismissViewControllerAnimated:NO completion:nil]; }      /* nested presentations go too */
    UIView *container = target->_sheetContainer, *dim = target->_sheetDim, *behind = target->_sheetBehind, *v = target.view;
    if (presenter) { presenter->_presented = nil; target->_presenting = nil; }
    container.userInteractionEnabled = NO;              /* touches reach the presenter while the sheet leaves */
    void (^finish)(BOOL) = ^(BOOL f) {
        [target _isim_appear:NO];
        if (container) {
            [container removeFromSuperview]; [v removeFromSuperview];
            if (behind) {
                behind.transform = CGAffineTransformIdentity;
                behind.clipsToBounds = target->_sheetBehindClipped; behind.layer.cornerRadius = target->_sheetBehindRadius;
                behind.window.backgroundColor = target->_sheetWindowBG;
            }
            target->_sheetContainer = target->_sheetDim = target->_sheetBehind = nil;
            v.layer.cornerRadius = 0; v.clipsToBounds = NO;
            for (UIGestureRecognizer *g in v.gestureRecognizers) if ([g isKindOfClass:[__IsimSheetPan class]]) [v removeGestureRecognizer:g];
        } else [v removeFromSuperview];
        if (done) done();
    };
    BOOL alert = [target isKindOfClass:NSClassFromString(@"UIAlertController")];
    if (!a || alert || (!container && target.modalPresentationStyle == UIModalPresentationOverFullScreen)) {
        if (behind) [UIView performWithoutAnimation:^{ behind.transform = CGAffineTransformIdentity; }];
        dispatch_async(dispatch_get_main_queue(), ^{ finish(YES); });
        return;
    }
    CGFloat h = (v.window ?: (UIView *)v.superview).bounds.size.height;
    isim_ui_animate(0.38, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{
        v.frame = CGRectMake(v.frame.origin.x, h, v.frame.size.width, v.frame.size.height);
        dim.alpha = 0;
        if (behind) behind.transform = CGAffineTransformIdentity;
    }, finish);
}
/* interactive dismissal: follow the finger, then dismiss or spring back */
- (void)_isim_sheetPan:(__IsimSheetPan *)g {
    UIView *v = self.view, *container = _sheetContainer;
    if (!container) return;
    CGRect end = sheet_frame(self, container.bounds);
    CGFloat dy = MAX(0, [g translationInView:container].y);
    if (self.isModalInPresentation) dy = dy > 0 ? 18 * log1p(dy / 18) : 0;   /* rubber-band */
    if (g.state == UIGestureRecognizerStateChanged || g.state == UIGestureRecognizerStateBegan) {
        [UIView performWithoutAnimation:^{ v.frame = CGRectOffset(end, 0, dy); }];
    } else if (g.state == UIGestureRecognizerStateEnded || g.state == UIGestureRecognizerStateCancelled) {
        CGFloat vy = [g velocityInView:container].y;
        if (!self.isModalInPresentation && g.state == UIGestureRecognizerStateEnded && (dy > end.size.height * 0.25 || vy > 900)) {
            [self dismissViewControllerAnimated:YES completion:nil];
        } else isim_ui_animate(0.45, 0, 0, 1, 0.85, 0, ^{ v.frame = end; }, nil);
    }
}
@end
@interface UIGestureRecognizer (IsimTouch)
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event;
@end
@implementation __IsimSheetPan { BOOL _ignoring; }
/* only drags that start in the sheet's top area (grabber / navigation bar) move the sheet */
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (phase == UITouchPhaseBegan) _ignoring = [touch locationInView:self.view].y > 64;
    if (!_ignoring) [super _isim_touch:touch phase:phase event:event];
}
@end

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
- (BOOL)_isim_isSystemWindow { return NO; }
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
static BOOL status_bar_hidden;
- (BOOL)isStatusBarHidden { return status_bar_hidden; }
- (void)_isim_setStatusBarHidden:(BOOL)h {
    if (h == status_bar_hidden) return;
    status_bar_hidden = h; isim_set_status_bar_hidden(h); isim_ui_set_needs_display();
}
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
+ (NSString *)openSettingsURLString { return @"app-settings:"; }
- (BOOL)canOpenURL:(NSURL *)url { NSString *s = url.scheme.lowercaseString; return [@[@"http", @"https", @"mailto", @"tel", @"sms", @"app-settings"] containsObject:s ?: @""]; }
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL))completion {
    NSString *scheme = url.scheme.lowercaseString ?: @"";
    if ([scheme isEqualToString:@"app-settings"] && isim_shell_present()) {
        NSString *settings = [isim_ui_system_apps_dir() stringByAppendingPathComponent:@"Settings.app"];
        NSString *target = [NSString stringWithFormat:@"app-settings:%@", NSBundle.mainBundle.bundleIdentifier ?: @""];
        isim_shell_request(ISIM_SHELL_LAUNCH, settings.UTF8String, [settings stringByAppendingPathComponent:@"Settings"].UTF8String, target.UTF8String);
        NSLog(@"isim: open URL %@ -> Settings", url.absoluteString);
        if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion(YES); });
        return;
    }
    BOOL hostOpen = [@[@"http", @"https", @"mailto"] containsObject:scheme] && isim_open_url(url.absoluteString.UTF8String);
    if ([scheme isEqualToString:@"app-settings"]) NSLog(@"isim: open URL %@ (the app's page in Settings; isim has no Settings app)", url.absoluteString);
    else NSLog(@"isim: open URL %@%@", url.absoluteString, hostOpen ? @" (opened on the host)" : @" (not opened; ISIM_OPEN_URLS=1 opens http/mailto on the host)");
    if (completion) dispatch_async(dispatch_get_main_queue(), ^{ completion([self canOpenURL:url]); });
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
        if (!w.hidden && ![w _isim_isSystemWindow] && (!best || best.hidden || w.windowLevel > best.windowLevel)) best = w;
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
        /* front-most window (by level) whose frame contains the point and has a view there */
        NSArray *ws = [UIApplication.sharedApplication.windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
            return a.windowLevel > b.windowLevel ? NSOrderedAscending : a.windowLevel < b.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
        UIWindow *w = nil; UIView *hit = nil;
        for (UIWindow *c in ws) {
            if (c.hidden || !CGRectContainsPoint(c.frame, p)) continue;
            hit = [c hitTest:CGPointMake(p.x - c.frame.origin.x, p.y - c.frame.origin.y) withEvent:nil];
            if (hit) { w = c; break; }
        }
        if (!hit) { cur_touch = nil; return; }
        cur_touch = [[UITouch alloc] initWithIsimView:hit window:w location:CGPointMake(p.x - w.frame.origin.x, p.y - w.frame.origin.y) time:ev->timestamp];
        if (ev->timestamp - last_tap_time < 0.35 && hypot(p.x - last_tap_point.x, p.y - last_tap_point.y) < 20) [cur_touch setValue_isimTapCount:2];
        cur_gestures = [NSMutableArray array];
        touch_cancelled = NO;
        /* UIKit rule: a tap on a UIControl is not taken over by tap recognizers on its superviews */
        UIControl *control = nil;
        for (UIView *v = hit; v; v = v.superview) if ([v isKindOfClass:[UIControl class]] && ((UIControl *)v).enabled) { control = (UIControl *)v; break; }
        BOOL aboveControl = NO;
        /* like UIScrollView.touchesShouldCancel(in:): dragging a slider does not scroll its scroll view */
        BOOL dragControl = [control isKindOfClass:[UISlider class]];
        for (UIView *v = hit; v; v = v.superview) {
            for (UIGestureRecognizer *g in v.gestureRecognizers) {
                if (!g.enabled || (aboveControl && [g isKindOfClass:[UITapGestureRecognizer class]])) continue;
                if (aboveControl && dragControl && [g isKindOfClass:[UIPanGestureRecognizer class]]) continue;
                [cur_gestures addObject:g];
            }
            if (v == control) aboveControl = YES;
        }
    }
    UITouch *t = cur_touch;
    if (!t) return;
    UITouchPhase phase = ev->type == ISIM_EV_TOUCH_DOWN ? UITouchPhaseBegan : ev->type == ISIM_EV_TOUCH_MOVE ? UITouchPhaseMoved : UITouchPhaseEnded;
    CGRect wf = t.window.frame;
    [t _isim_setPhase:phase location:CGPointMake(p.x - wf.origin.x, p.y - wf.origin.y) time:ev->timestamp];
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
    NSString *ident = v.accessibilityIdentifier, *label = [v isKindOfClass:[UILabel class]] ? ((UILabel *)v).text : [v isKindOfClass:[UIButton class]] ? ((UIButton *)v).currentTitle
        : [v isKindOfClass:[UITextField class]] ? [NSString stringWithFormat:@"\"%@\"%@", ((UITextField *)v).text, v.isFirstResponder ? @" (editing)" : @""]
        : [v isKindOfClass:[UIScrollView class]] ? [NSString stringWithFormat:@"offset %g, content %g x %g, inset bottom %g", ((UIScrollView *)v).contentOffset.y,
              ((UIScrollView *)v).contentSize.width, ((UIScrollView *)v).contentSize.height, ((UIScrollView *)v).adjustedContentInset.bottom]
        : [v isKindOfClass:[UISwitch class]] ? (((UISwitch *)v).on ? @"on" : @"off")
        : [v isKindOfClass:[UISlider class]] ? [NSString stringWithFormat:@"%g", ((UISlider *)v).value]
        : [v isKindOfClass:[UISegmentedControl class]] ? [NSString stringWithFormat:@"segment %ld", (long)((UISegmentedControl *)v).selectedSegmentIndex] : nil;
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
static UIView *find_text(UIView *v, NSString *text, CGRect visible) {
    if (v.hidden || v.alpha <= 0.01) return nil;
    for (UIView *s in v.subviews.reverseObjectEnumerator) { UIView *f = find_text(s, text, visible); if (f) return f; }
    NSString *t = [v isKindOfClass:[UILabel class]] ? ((UILabel *)v).text : [v isKindOfClass:[UIButton class]] ? ((UIButton *)v).currentTitle : nil;
    if (![t isEqualToString:text]) return nil;
    CGRect r = [v convertRect:v.bounds toView:nil];
    return CGRectIntersectsRect(r, visible) ? v : nil;              /* on screen (not scrolled away) */
}
static void handle_id_touch(const struct isim_event *ev) {
    NSString *ident = @(ev->text);
    BOOL byText = ev->type == ISIM_EV_TEXT_DOWN || ev->type == ISIM_EV_TEXT_UP;
    UIView *found = nil;
    NSArray *windows = UIApplication.sharedApplication.windows;
    for (UIWindow *w in windows.reverseObjectEnumerator)
        if (!w.hidden && (found = byText ? find_text(w, ident, w.bounds) : find_identified(w, ident))) break;
    if (!found) { NSLog(byText ? @"isim: no visible view showing text '%@'" : @"isim: no visible view with accessibilityIdentifier '%@'", ident); return; }
    CGRect b = found.bounds;
    CGPoint p = [found convertPoint:CGPointMake(CGRectGetMidX(b), CGRectGetMidY(b)) toView:nil];
    p = [found.window convertPoint:p toView:nil];
    struct isim_event t = *ev;
    t.type = ev->type == ISIM_EV_ID_DOWN || ev->type == ISIM_EV_TEXT_DOWN ? ISIM_EV_TOUCH_DOWN : ISIM_EV_TOUCH_UP;
    t.x = p.x + found.window.frame.origin.x; t.y = p.y + found.window.frame.origin.y;
    handle_touch(&t);
}

@implementation UITouch (IsimTap)
- (void)setValue_isimTapCount:(NSUInteger)n { self.tapCount = n; }
@end

static void render_frame(void) {
    isim_ui_keyboard_check();
    isim_ui_display_links_fire();
    isim_ui_animations_tick();
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

/* ---- shell lifecycle (isim boot): background/foreground, settings, URLs ---- */
NSString *isim_ui_system_apps_dir(void) {
    const char *e = getenv("ISIM_SYSTEM_APPS");
    return e && *e ? @(e) : [[@(isim_bundle_path()) stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"."];
}
/* installed apps: ISIM_APPS or <isim data>/Applications */
NSString *isim_ui_installed_apps_dir(void) {
    const char *e = getenv("ISIM_APPS");
    extern NSString *isim_data_dir(void);
    return e && *e ? @(e) : [isim_data_dir() stringByAppendingPathComponent:@"Applications"];
}
static BOOL backgrounded;
static void each_scene_delegate(void (^f)(UIScene *, id<UISceneDelegate>)) {
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) f(s, s.delegate);
}
static void enter_background(void) {
    isim_audio_suspend(1);          /* like an interrupted audio session */
    if (backgrounded) return;
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { if ([sd respondsToSelector:@selector(sceneWillResignActive:)]) [sd sceneWillResignActive:s]; });
    if ([d respondsToSelector:@selector(applicationWillResignActive:)]) [d applicationWillResignActive:app];
    [nc postNotificationName:UIApplicationWillResignActiveNotification object:app];
    backgrounded = YES; app.applicationState = UIApplicationStateBackground;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateBackground; if ([sd respondsToSelector:@selector(sceneDidEnterBackground:)]) [sd sceneDidEnterBackground:s]; });
    if ([d respondsToSelector:@selector(applicationDidEnterBackground:)]) [d applicationDidEnterBackground:app];
    [nc postNotificationName:UIApplicationDidEnterBackgroundNotification object:app];
    [isim_ui_first_responder() resignFirstResponder];
}
static void enter_foreground(void) {
    isim_audio_suspend(0);
    if (!backgrounded) { isim_ui_set_needs_display(); return; }
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateForegroundInactive; if ([sd respondsToSelector:@selector(sceneWillEnterForeground:)]) [sd sceneWillEnterForeground:s]; });
    if ([d respondsToSelector:@selector(applicationWillEnterForeground:)]) [d applicationWillEnterForeground:app];
    [nc postNotificationName:UIApplicationWillEnterForegroundNotification object:app];
    backgrounded = NO; app.applicationState = UIApplicationStateActive;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateForegroundActive; if ([sd respondsToSelector:@selector(sceneDidBecomeActive:)]) [sd sceneDidBecomeActive:s]; });
    if ([d respondsToSelector:@selector(applicationDidBecomeActive:)]) [d applicationDidBecomeActive:app];
    [nc postNotificationName:UIApplicationDidBecomeActiveNotification object:app];
    isim_ui_set_needs_layout();
}
static void trait_changed(UIView *v) { [v traitCollectionDidChange:nil]; for (UIView *s in v.subviews) trait_changed(s); }
static void settings_changed(void) {
    extern void isim_ui_reload_settings(void);
    extern void isim_reapply_time_zone_setting(void);
    isim_ui_reload_settings();
    isim_reapply_time_zone_setting();                 /* Date & Time > Time Zone applies live */
    for (UIWindow *w in UIApplication.sharedApplication.windows) trait_changed(w);
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimSettingsChanged" object:nil];
    isim_ui_set_needs_display();
}
static void deliver_url(NSString *s) {
    NSURL *url = [NSURL URLWithString:s];
    if (!url) return;
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSLog(@"isim: opening URL %@ in the app", s);
    if ([d respondsToSelector:@selector(application:openURL:options:)]) [(id)d application:app openURL:url options:@{}];
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimOpenURL" object:url];     /* SwiftUI .onOpenURL */
}

static void layout_all(void) {
    for (int i = 0; i < 4 && isim_ui_take_layout(); i++)
    {
        NSArray *ws = UIApplication.sharedApplication.windows;
        isim_ui_layout_roots(ws);
        for (UIWindow *w in ws) [w _isim_layoutPass];
    }
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
        isim_ui_register_app_fonts();
        if ([info[@"UIStatusBarHidden"] boolValue]) { status_bar_hidden = YES; isim_set_status_bar_hidden(1); }
        Class appClass = class_named(principalClassName ?: info[@"NSPrincipalClass"]) ?: [UIApplication class];
        UIApplication *app = [appClass new];
        shared_app = app;
        Class delegateClass = class_named(delegateClassName);
        if (delegateClass) { app.strongDelegate = [delegateClass new]; app.delegate = app.strongDelegate; }
        NSString *title = info[@"CFBundleDisplayName"] ?: info[@"CFBundleName"] ?: info[@"CFBundleExecutable"] ?: @"App";
        isim_display_open(title.UTF8String);
        isim_ui_keyboard_install();
        extern void (*isim_main_wakeup_hook)(void);
        isim_main_wakeup_hook = isim_post_wakeup;
        NSLog(@"isim: launching %@ (%@) on %s", title, bundle.bundleIdentifier ?: @"no bundle id", isim_ui_device()->name);

        id<UIApplicationDelegate> d = app.delegate;
        if ([d respondsToSelector:@selector(application:willFinishLaunchingWithOptions:)]) [d application:app willFinishLaunchingWithOptions:nil];
        if ([d respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) [d application:app didFinishLaunchingWithOptions:nil];
        else if ([d respondsToSelector:@selector(applicationDidFinishLaunching:)]) [d applicationDidFinishLaunching:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidFinishLaunchingNotification object:app];

        NSDictionary *manifest = info[@"UIApplicationSceneManifest"];
        /* scene-based apps: a scene manifest, or a delegate that configures scenes (SwiftUI apps) */
        if (manifest || [app.delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)]) connect_scene(app, manifest ?: @{});
        else if ([d respondsToSelector:@selector(window)] && d.window && d.window.hidden) [d.window makeKeyAndVisible];
        app.applicationState = UIApplicationStateActive;
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimGlobalPreferencesChanged" object:nil queue:nil usingBlock:^(NSNotification *n) {
            settings_changed();
            isim_shell_request(ISIM_SHELL_SETTINGS, NULL, NULL, NULL);      /* other apps re-read the settings too */
        }];
        if (getenv("ISIM_LAUNCH_URL")) { NSString *u = @(getenv("ISIM_LAUNCH_URL")); dispatch_async(dispatch_get_main_queue(), ^{ deliver_url(u); }); }
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
            if (isim_ui_take_display() && !backgrounded) { layout_all(); render_frame(); }
            double timeout = next < 0.5 ? next : 0.5;
            if ((isim_ui_animations_running() || isim_ui_display_links_active()) && !backgrounded) { isim_ui_set_needs_display(); if (timeout > 1.0 / 60) timeout = 1.0 / 60; }
            { extern double isim_main_next_due(void); double due = isim_main_next_due(); if (due < timeout) timeout = due; }   /* blocks queued while rendering run right away */
            struct isim_event ev;
            for (int got = isim_next_event(&ev, timeout); got; got = isim_next_event(&ev, 0)) {
                switch (ev.type) {
                case ISIM_EV_QUIT: quit = YES; break;
                case ISIM_EV_TOUCH_DOWN: case ISIM_EV_TOUCH_MOVE: case ISIM_EV_TOUCH_UP: handle_touch(&ev); break;
                case ISIM_EV_REDRAW: isim_ui_set_needs_display(); break;
                case ISIM_EV_TEXT: case ISIM_EV_KEY: handle_key(&ev); break;
                case ISIM_EV_ID_DOWN: case ISIM_EV_ID_UP: case ISIM_EV_TEXT_DOWN: case ISIM_EV_TEXT_UP: handle_id_touch(&ev); break;
                case ISIM_EV_BACKGROUND: enter_background(); break;
                case ISIM_EV_FOREGROUND: enter_foreground(); break;
                case ISIM_EV_SETTINGS: settings_changed(); break;
                case ISIM_EV_LAUNCH_ID: [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimShellLaunch" object:@(ev.text)]; break;
                case ISIM_EV_OPEN_URL: deliver_url(@(ev.text)); break;
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
