/* isim UIKit: touches/events, screen, window, view controllers, scenes, UIApplication and
 * UIApplicationMain with the simulator event/render loop (ARC). */
#import "UIKitPrivate.h"
#include <objc/message.h>
#import "UIKitInputPrivate.h"
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <dlfcn.h>

/* ================= UITouch / UIEvent ================= */
@interface UITouch ()
@property (nonatomic, readwrite) NSTimeInterval timestamp;
@property (nonatomic, readwrite) UITouchPhase phase;
@property (nonatomic, readwrite) NSUInteger tapCount;
@property (nonatomic, readwrite, strong) UIWindow *window;
@property (nonatomic, readwrite, strong) UIView *view;
@property (nonatomic) CGPoint loc, prev;
@property (nonatomic) int isimFinger;
@end
@implementation UITouch
- (instancetype)initWithIsimView:(UIView *)v window:(UIWindow *)w location:(CGPoint)p time:(NSTimeInterval)t {
    if ((self = [super init])) { _view = v; _window = w; _loc = _prev = p; _timestamp = t; _phase = UITouchPhaseBegan; _tapCount = 1; }
    return self;
}
- (void)_isim_setPhase:(UITouchPhase)ph location:(CGPoint)p time:(NSTimeInterval)t { _phase = ph; _prev = _loc; _loc = p; _timestamp = t; }
- (void)_isim_setView:(UIView *)v { _view = v; }
- (void)_isim_setFinger:(int)f { _isimFinger = f; }
- (int)_isim_finger { return _isimFinger; }
- (void)_isim_setStationary { if (_phase != UITouchPhaseEnded && _phase != UITouchPhaseCancelled) { _phase = UITouchPhaseStationary; _prev = _loc; } }
- (UITouchType)type { return UITouchTypeDirect; }
- (CGFloat)majorRadius { return 20; }
- (CGFloat)majorRadiusTolerance { return 5; }
- (CGFloat)force { return _phase == UITouchPhaseEnded || _phase == UITouchPhaseCancelled ? 0 : 1; }
- (CGFloat)maximumPossibleForce { return 0; }        /* no 3D Touch */
- (CGFloat)altitudeAngle { return M_PI / 2; }
- (CGPoint)preciseLocationInView:(UIView *)v { return [self locationInView:v]; }
- (CGPoint)precisePreviousLocationInView:(UIView *)v { return [self previousLocationInView:v]; }
- (NSArray *)gestureRecognizers {
    NSMutableArray *a = [NSMutableArray array];
    for (UIView *v = _view; v; v = v.superview) for (UIGestureRecognizer *g in v.gestureRecognizers) [a addObject:g];
    return a;
}
- (CGPoint)locationInView:(UIView *)v { return v ? [v _isim_fromWindow:_loc] : _loc; }
- (CGPoint)previousLocationInView:(UIView *)v { return v ? [v _isim_fromWindow:_prev] : _prev; }
@end

@interface UIEvent ()
@property (nonatomic, strong) NSSet *touchSet;
@end
@implementation UIEvent
- (instancetype)initWithIsimTouch:(UITouch *)t { if ((self = [super init])) _touchSet = [NSSet setWithObject:t]; return self; }
- (instancetype)initWithIsimTouches:(NSSet *)ts { if ((self = [super init])) _touchSet = [ts copy]; return self; }
- (UIEventType)type { return UIEventTypeTouches; }
- (UIEventSubtype)subtype { return UIEventSubtypeNone; }
- (NSTimeInterval)timestamp { return _touchSet ? [_touchSet.anyObject timestamp] : isim_time(); }
- (NSSet *)allTouches { return _touchSet; }
- (NSSet *)touchesForView:(UIView *)v {
    NSMutableSet *r = [NSMutableSet set];
    for (UITouch *t in _touchSet) if ([t.view isDescendantOfView:v]) [r addObject:t];
    return r.count ? r : nil;
}
- (NSSet *)touchesForWindow:(UIWindow *)w {
    NSMutableSet *r = [NSMutableSet set];
    for (UITouch *t in _touchSet) if (t.window == w) [r addObject:t];
    return r.count ? r : nil;
}
- (NSSet *)touchesForGestureRecognizer:(UIGestureRecognizer *)g { return g.view ? [self touchesForView:g.view] : nil; }
- (NSArray *)coalescedTouchesForTouch:(UITouch *)t { return t ? @[t] : nil; }
- (NSArray *)predictedTouchesForTouch:(UITouch *)t { return @[]; }
@end

/* ================= UIScreen ================= */
@implementation UIDevice
+ (UIDevice *)currentDevice { static UIDevice *d; if (!d) d = [UIDevice new]; return d; }
- (BOOL)_pad { const struct isim_device *d = isim_ui_device(); return MIN(d->width, d->height) >= 700; }
- (NSString *)name { return [self _pad] ? @"iPad" : @"iPhone"; }
- (NSString *)model { return [self _pad] ? @"iPad" : @"iPhone"; }
- (NSString *)localizedModel { return self.model; }
- (NSString *)systemName { return @"iOS"; }
- (NSString *)systemVersion { const char *v = getenv("ISIM_OS_VERSION"); return v && *v ? @(v) : @"18.0"; }
@dynamic orientation;                       /* UIOrientation.m */
- (UIUserInterfaceIdiom)userInterfaceIdiom { return [self _pad] ? UIUserInterfaceIdiomPad : UIUserInterfaceIdiomPhone; }
- (BOOL)isMultitaskingSupported { return YES; }
- (NSString *)_isim_deviceName { return @(isim_ui_device()->name); }
/* the simulated battery: ISIM_BATTERY="LEVEL [unplugged|charging|full]" (default "1 full"); -1 / unknown unless monitored */
static BOOL battery_monitoring;
- (BOOL)isBatteryMonitoringEnabled { return battery_monitoring; }
- (void)setBatteryMonitoringEnabled:(BOOL)e { battery_monitoring = e; }
- (float)batteryLevel {
    if (!battery_monitoring) return -1;
    const char *e = getenv("ISIM_BATTERY");
    float l = e && *e ? (float)atof(e) : 1;
    return l < 0 ? 0 : l > 1 ? 1 : l;
}
- (UIDeviceBatteryState)batteryState {
    if (!battery_monitoring) return UIDeviceBatteryStateUnknown;
    const char *e = getenv("ISIM_BATTERY"), *w = e ? strchr(e, ' ') : NULL;
    if (!w) return self.batteryLevel >= 1 ? UIDeviceBatteryStateFull : UIDeviceBatteryStateUnplugged;
    while (*w == ' ') w++;
    return !strcmp(w, "charging") ? UIDeviceBatteryStateCharging : !strcmp(w, "full") ? UIDeviceBatteryStateFull : UIDeviceBatteryStateUnplugged;
}
/* one UUID per vendor (bundle identifier without its last component), in the device data like iOS keeps it per device */
- (NSUUID *)identifierForVendor {
    NSString *bid = NSBundle.mainBundle.bundleIdentifier ?: @"app";
    NSRange dot = [bid rangeOfString:@"." options:NSBackwardsSearch];
    NSString *vendor = dot.location != NSNotFound ? [bid substringToIndex:dot.location] : bid;
    extern NSString *isim_data_dir(void);
    NSString *dir = [isim_data_dir() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
    NSString *file = [dir stringByAppendingPathComponent:@"vendor-identifiers.plist"];
    NSMutableDictionary *ids = [[NSDictionary dictionaryWithContentsOfFile:file] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *u = ids[vendor];
    if (![u isKindOfClass:[NSString class]] || ![[NSUUID alloc] initWithUUIDString:u]) { u = NSUUID.UUID.UUIDString; ids[vendor] = u; [ids writeToFile:file atomically:YES]; }
    return [[NSUUID alloc] initWithUUIDString:u];
}
- (BOOL)isProximityMonitoringEnabled { return NO; }          /* no proximity sensor (like an iPad / the Simulator) */
- (void)setProximityMonitoringEnabled:(BOOL)e {}
- (BOOL)proximityState { return NO; }
- (void)playInputClick {}
@end
NSNotificationName const UIDeviceBatteryStateDidChangeNotification = @"UIDeviceBatteryStateDidChangeNotification",
    UIDeviceBatteryLevelDidChangeNotification = @"UIDeviceBatteryLevelDidChangeNotification",
    UIDeviceProximityStateDidChangeNotification = @"UIDeviceProximityStateDidChangeNotification";

@implementation UIScreen
+ (UIScreen *)mainScreen { static UIScreen *s; if (!s) s = [UIScreen new]; return s; }
- (CGRect)bounds { const struct isim_device *d = isim_ui_device(); return CGRectMake(0, 0, d->width, d->height); }
- (CGRect)nativeBounds { CGRect b = self.bounds; CGFloat s = self.scale; return CGRectMake(0, 0, b.size.width * s, b.size.height * s); }
- (CGFloat)scale { return isim_ui_device()->scale; }
- (CGFloat)nativeScale { return self.scale; }
- (NSInteger)maximumFramesPerSecond { return 60; }
- (id<UICoordinateSpace>)coordinateSpace { return (id<UICoordinateSpace>)UIApplication.sharedApplication.keyWindow; }
- (UITraitCollection *)traitCollection { return isim_ui_screen_traits(); }
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
    UITraitCollection *_traitReported; id<UITraitOverrides> _traitOverrides;     /* traits (UITraits.m) */
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
        if (nib || b) isim_ib_vc_set_nib(self, nib, b);           /* loaded by -loadView (UIStoryboard.m) */
    }
    return self;
}
- (instancetype)initWithCoder:(NSCoder *)c { return isim_ib_init_with_coder(self, c); }   /* UIStoryboard.m */
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
    if (isim_ib_vc_load_view(self)) return;      /* storyboard scene or nib */
    UIView *v = [[UIView alloc] initWithFrame:UIScreen.mainScreen.bounds];
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    v.layoutMargins = UIEdgeInsetsMake(0, 16, 0, 16);
    self.view = v;
}
- (void)loadViewIfNeeded { (void)self.view; }
- (UIView *)viewIfLoaded { return _view; }
- (BOOL)isViewLoaded { return _view != nil; }
- (void)viewDidLoad {}
- (NSString *)nibName { return isim_ib_vc_nib_name(self); }
- (NSBundle *)nibBundle { return isim_ib_vc_nib_bundle(self); }
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
/* traits: inherited from the view's parent (or the parent controller / presenter while the view is not loaded), then
   overrideUserInterfaceStyle and traitOverrides; the view (and child controllers) inherit them */
- (UITraitCollection *)_isim_traitsFromBase:(UITraitCollection *)base { return isim_ui_apply_overrides(base, _traitOverrides, _overrideUserInterfaceStyle); }
- (UITraitCollection *)traitCollection {
    UITraitCollection *base;
    if (_view) base = [(id)_view _isim_inheritedTraits];
    else if (_presenting && _presenting.presentedViewController == self) base = _presenting.traitCollection;
    else if (_parent) base = _parent.traitCollection;
    else base = UIApplication.sharedApplication.keyWindow.traitCollection ?: isim_ui_screen_traits();
    return [self _isim_traitsFromBase:base];
}
- (void)_isim_traitsCheck {
    UITraitCollection *t = self.traitCollection, *prev = _traitReported;
    _traitReported = t;
    if (prev && ![prev isEqual:t]) [self traitCollectionDidChange:prev];
}
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
- (void)setOverrideUserInterfaceStyle:(UIUserInterfaceStyle)s {
    if (s == _overrideUserInterfaceStyle) return;
    _overrideUserInterfaceStyle = s;
    if (_view) isim_ui_traits_invalidate(_view); else isim_ui_traits_invalidate(nil);
    isim_ui_set_needs_display();
}
- (id<UITraitOverrides>)traitOverrides {
    if (!_traitOverrides) {
        __weak UIViewController *w = self;
        _traitOverrides = isim_ui_new_trait_overrides(^{ UIViewController *vc = w; if (vc->_view) isim_ui_traits_invalidate(vc->_view); else isim_ui_traits_invalidate(nil); isim_ui_set_needs_display(); });
    }
    return _traitOverrides;
}
- (void)updateTraitsIfNeeded { isim_ui_traits_flush(); }
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
- (void)_isim_setPresented:(UIViewController *)p { _presented = p; }
- (void)_isim_setPresenting:(UIViewController *)p { _presenting = p; }
- (UIViewController *)presentingViewController { return _presenting; }
- (BOOL)_isim_presentsAsSheet {
    if ([self isKindOfClass:NSClassFromString(@"UIAlertController")]) return NO;
    UIModalPresentationStyle st = _modalPresentationStyle;
    return st == UIModalPresentationAutomatic || st == UIModalPresentationPageSheet || st == UIModalPresentationFormSheet;
}
static CGRect sheet_frame(UIViewController *vc, CGRect b) {
    const struct isim_device *d = isim_ui_device();
    if (MIN(b.size.width, b.size.height) >= 700) {                /* iPad: centered card */
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
    if (isim_ui_present(self, vc, a, done)) return;            /* UIPresentation.m: everything but alerts */
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
    if (isim_ui_dismiss(self, a, done)) return;                /* presented by UIPresentation.m */
    /* like UIKit: a child controller (e.g. the root of a presented navigation controller) forwards to its parent */
    if (!_presented && !_presenting && self.parentViewController) { [self.parentViewController dismissViewControllerAnimated:a completion:done]; return; }
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
static UIWindowScene *implicit_scene(void);
@synthesize windowScene = _windowScene;
- (UIWindowScene *)windowScene { return _windowScene ?: implicit_scene(); }
- (void)setWindowScene:(UIWindowScene *)s {
    _windowScene = s;
    NSMutableArray *list = [s valueForKey_isimWindows];
    if (list && [list indexOfObjectIdenticalTo:self] == NSNotFound) [list addObject:self];
}
- (UIWindow *)window { return self; }
- (UIEdgeInsets)safeAreaInsets { const struct isim_device *d = isim_ui_device(); return UIEdgeInsetsMake(d->safe_top, d->safe_left, d->safe_bottom, d->safe_right); }
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
NSNotificationName const UISceneDidDisconnectNotification = @"UISceneDidDisconnectNotification";
NSNotificationName const UISceneWillDeactivateNotification = @"UISceneWillDeactivateNotification";
NSNotificationName const UISceneWillEnterForegroundNotification = @"UISceneWillEnterForegroundNotification";
NSNotificationName const UISceneDidEnterBackgroundNotification = @"UISceneDidEnterBackgroundNotification";
UISceneSessionRole const UIWindowSceneSessionRoleExternalDisplayNonInteractive = @"UIWindowSceneSessionRoleExternalDisplayNonInteractive";
NSErrorDomain const UISceneErrorDomain = @"UISceneErrorDomain";

@interface UISceneSession ()
@property (nonatomic, readwrite, weak) UIScene *scene;
@property (nonatomic, readwrite) UISceneSessionRole role;
@property (nonatomic, readwrite, copy) UISceneConfiguration *configuration;
@property (nonatomic, readwrite) NSString *persistentIdentifier;
@end
@implementation UISceneSession @end
/* UISceneConnectionOptions: UISystemIntegration.m */
@implementation UISceneConfiguration
+ (instancetype)configurationWithName:(NSString *)n sessionRole:(UISceneSessionRole)r { return [[self alloc] initWithName:n sessionRole:r]; }
- (instancetype)initWithName:(NSString *)n sessionRole:(UISceneSessionRole)r { if ((self = [super init])) { _name = [n copy]; _role = [r copy]; } return self; }
- (id)copyWithZone:(NSZone *)z { UISceneConfiguration *c = [[UISceneConfiguration alloc] initWithName:_name sessionRole:_role]; c.sceneClass = _sceneClass; c.delegateClass = _delegateClass; c.storyboard = _storyboard; return c; }
@end

@interface UIScene ()
@property (nonatomic, readwrite) UISceneSession *session;
@property (nonatomic, readwrite) UISceneActivationState activationState;
@end
/* apps without a scene manifest still have a scene on iOS 13+: windows get an implicit one */
static UIWindowScene *implicit_scene(void) {
    static UIWindowScene *scene;
    if (!scene) {
        UISceneSession *session = [UISceneSession new];
        session.role = UIWindowSceneSessionRoleApplication;
        scene = [[UIWindowScene alloc] initWithSession:session connectionOptions:[UISceneConnectionOptions new]];
        session.scene = scene;
        scene.activationState = UISceneActivationStateForegroundActive;
    }
    return scene;
}
@implementation UIScene { NSString *_subtitle; }
- (instancetype)initWithSession:(UISceneSession *)s connectionOptions:(UISceneConnectionOptions *)o {
    if ((self = [super init])) { _session = s; _activationState = UISceneActivationStateUnattached; _title = @""; }
    return self;
}
- (UIResponder *)nextResponder { return UIApplication.sharedApplication; }
- (void)setTitle:(NSString *)t { _title = [t copy] ?: @""; }
- (NSString *)subtitle { return _subtitle ?: @""; }
- (void)setSubtitle:(NSString *)t { _subtitle = [t copy]; }
- (void)openURL:(NSURL *)url options:(UISceneOpenExternalURLOptions *)options completionHandler:(void (^)(BOOL))completion {
    NSDictionary *o = options.universalLinksOnly ? @{ UIApplicationOpenURLOptionUniversalLinksOnly: @YES } : @{};
    [UIApplication.sharedApplication openURL:url options:o completionHandler:completion];
}
@end
@implementation UISceneOpenExternalURLOptions @end
@implementation UISceneActivationRequestOptions @end
@implementation UIWindowSceneActivationRequestOptions @end
@implementation UISceneDestructionRequestOptions @end
@implementation UIWindowSceneDestructionRequestOptions
- (instancetype)init { if ((self = [super init])) _windowDismissalAnimation = UIWindowSceneDismissalAnimationStandard; return self; }
@end
@interface UISceneSessionActivationRequest ()
@property (nonatomic, readwrite) UISceneSessionRole role;
@property (nonatomic, readwrite, nullable) UISceneSession *session;
@end
@implementation UISceneSessionActivationRequest
+ (instancetype)request { return [self requestWithRole:UIWindowSceneSessionRoleApplication]; }
+ (instancetype)requestWithRole:(UISceneSessionRole)role { UISceneSessionActivationRequest *r = [self new]; r.role = role; return r; }
+ (instancetype)requestWithSession:(UISceneSession *)session {
    if (!session) return nil;
    UISceneSessionActivationRequest *r = [self new]; r.role = session.role ?: UIWindowSceneSessionRoleApplication; r.session = session; return r;
}
- (id)copyWithZone:(NSZone *)z { UISceneSessionActivationRequest *r = [UISceneSessionActivationRequest new]; r.role = _role; r.session = _session; r.userActivity = _userActivity; r.options = _options; return r; }
@end
@implementation UISceneSizeRestrictions
- (instancetype)init { if ((self = [super init])) _allowsFullScreen = YES; return self; }
@end
@interface UIWindowSceneGeometry ()
@property (nonatomic, readwrite) CGRect systemFrame;
@property (nonatomic, readwrite) UIInterfaceOrientation interfaceOrientation;
@end
@implementation UIWindowSceneGeometry
- (BOOL)isInteractivelyResizing { return NO; }
- (id)copyWithZone:(NSZone *)z { return self; }
@end
/* a scene's coordinate space: its frame on the screen (split view) */
@interface __IsimSceneSpace : NSObject <UICoordinateSpace>
@property (nonatomic) CGRect frame;
@end
@implementation __IsimSceneSpace
- (CGRect)bounds { return (CGRect){ CGPointZero, _frame.size }; }
static CGPoint space_to_screen(id<UICoordinateSpace> s, CGPoint p) {
    if ([(id)s isKindOfClass:[__IsimSceneSpace class]]) return CGPointMake(p.x + ((__IsimSceneSpace *)s).frame.origin.x, p.y + ((__IsimSceneSpace *)s).frame.origin.y);
    if ([(id)s isKindOfClass:[UIView class]]) { UIView *v = (UIView *)s; CGPoint w = [v convertPoint:p toView:nil]; CGRect wf = v.window.frame; return CGPointMake(w.x + wf.origin.x, w.y + wf.origin.y); }
    return p;
}
static CGPoint space_from_screen(id<UICoordinateSpace> s, CGPoint p) {
    if ([(id)s isKindOfClass:[__IsimSceneSpace class]]) return CGPointMake(p.x - ((__IsimSceneSpace *)s).frame.origin.x, p.y - ((__IsimSceneSpace *)s).frame.origin.y);
    if ([(id)s isKindOfClass:[UIView class]]) { UIView *v = (UIView *)s; CGRect wf = v.window.frame; return [v convertPoint:CGPointMake(p.x - wf.origin.x, p.y - wf.origin.y) fromView:nil]; }
    return p;
}
- (CGPoint)convertPoint:(CGPoint)p toCoordinateSpace:(id<UICoordinateSpace>)s { return space_from_screen(s, space_to_screen(self, p)); }
- (CGPoint)convertPoint:(CGPoint)p fromCoordinateSpace:(id<UICoordinateSpace>)s { return space_from_screen(self, space_to_screen(s, p)); }
@end
@implementation UIWindowScene { NSMutableArray<UIWindow *> *_windows; id<UITraitOverrides> _traitOverrides; CGRect _isimFrame; BOOL _isimHasFrame;
    UISceneSizeRestrictions *_sizeRestrictions; __IsimSceneSpace *_space; }
- (NSMutableArray *)valueForKey_isimWindows { if (!_windows) _windows = [NSMutableArray array]; return _windows; }
- (UIScreen *)screen { return UIScreen.mainScreen; }
- (NSArray *)windows { return [_windows copy] ?: @[]; }
- (UIWindow *)keyWindow { for (UIWindow *w in _windows) if (w.isKeyWindow) return w; return nil; }
/* the scene's frame on the screen: the whole screen, or its side of a split view */
- (CGRect)_isim_frame { return _isimHasFrame ? _isimFrame : UIScreen.mainScreen.bounds; }
- (void)_isim_setFrame:(CGRect)f { _isimFrame = f; _isimHasFrame = YES; }
- (BOOL)_isim_hasFrame { return _isimHasFrame; }
- (UITraitCollection *)_isim_traitsForWindowSize:(CGSize)size { return isim_ui_apply_overrides(isim_ui_traits_for_size(size), _traitOverrides, UIUserInterfaceStyleUnspecified); }
- (UITraitCollection *)traitCollection { return [self _isim_traitsForWindowSize:[self _isim_frame].size]; }
- (id<UITraitOverrides>)traitOverrides {
    if (!_traitOverrides) _traitOverrides = isim_ui_new_trait_overrides(^{ isim_ui_traits_invalidate(nil); isim_ui_set_needs_display(); });
    return _traitOverrides;
}
- (void)updateTraitsIfNeeded { isim_ui_traits_flush(); }
- (id<UICoordinateSpace>)coordinateSpace { if (!_space) _space = [__IsimSceneSpace new]; _space.frame = [self _isim_frame]; return _space; }
- (UISceneSizeRestrictions *)sizeRestrictions {
    if (UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return nil;      /* iPhone scenes are not resizable */
    if (!_sizeRestrictions) { _sizeRestrictions = [UISceneSizeRestrictions new]; _sizeRestrictions.maximumSize = UIScreen.mainScreen.bounds.size; }
    return _sizeRestrictions;
}
- (UIWindowSceneGeometry *)effectiveGeometry {
    UIWindowSceneGeometry *g = [UIWindowSceneGeometry new];
    g.systemFrame = [self _isim_frame]; g.interfaceOrientation = self.interfaceOrientation;
    return g;
}
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
/* Info.plist UIApplicationSceneManifest > UIApplicationSupportsMultipleScenes, on iPad (iPhones show one scene) */
- (BOOL)supportsMultipleScenes {
    NSDictionary *m = NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"];
    return [m isKindOfClass:[NSDictionary class]] && [m[@"UIApplicationSupportsMultipleScenes"] boolValue] && UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad;
}
- (void)_isim_removeScene:(UIScene *)s session:(UISceneSession *)ss { if (s) [_scenes removeObject:s]; if (ss) [_sessions removeObject:ss]; }
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
BOOL isim_sys_can_open_url(NSURL *url);
BOOL isim_sys_route_url(NSURL *url, NSDictionary *options, void (^completion)(BOOL));
- (BOOL)canOpenURL:(NSURL *)url { NSString *s = url.scheme.lowercaseString; return [@[@"http", @"https", @"mailto", @"tel", @"sms", @"app-settings"] containsObject:s ?: @""] || isim_sys_can_open_url(url); }
- (void)openURL:(NSURL *)url options:(NSDictionary *)options completionHandler:(void (^)(BOOL))completion {
    if (isim_sys_route_url(url, options, completion)) return;     /* another app's URL scheme or universal link */
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
- (void)_isim_addScene:(UIScene *)s session:(UISceneSession *)ss { if (s) [_scenes addObject:s]; if (ss) [_sessions addObject:ss]; }
/* push notifications (UISystemIntegration.m): a device token, like the Simulator (Xcode 14+); payloads from `isim push` */
void isim_sys_register_remote(void);
void isim_sys_unregister_remote(void);
BOOL isim_sys_remote_registered(void);
NSInteger isim_sys_badge(void);
void isim_sys_set_badge(NSInteger n);
- (void)registerForRemoteNotifications { isim_sys_register_remote(); }
- (void)unregisterForRemoteNotifications { isim_sys_unregister_remote(); }
- (BOOL)isRegisteredForRemoteNotifications { return isim_sys_remote_registered(); }
/* the home screen shows the badge when the app may badge (UNAuthorizationOptionBadge) */
- (NSInteger)applicationIconBadgeNumber { return isim_sys_badge(); }
- (void)setApplicationIconBadgeNumber:(NSInteger)n { isim_sys_set_badge(n); }
@end

/* ================= UIApplicationMain + run loop ================= */
static UITouch *cur_touch;
static NSMutableArray<UIGestureRecognizer *> *cur_gestures;
static NSTimeInterval last_tap_time; static CGPoint last_tap_point; static NSUInteger last_tap_count;

BOOL isim_ui_window_on_screen(UIWindow *w);
BOOL isim_ui_scenes_split(void);
static UIWindow *top_window(void) {
    UIWindow *best = UIApplication.sharedApplication.keyWindow;
    for (UIWindow *w in UIApplication.sharedApplication.windows)
        if (!w.hidden && ![w _isim_isSystemWindow] && (!best || best.hidden || w.windowLevel > best.windowLevel)) best = w;
    return best && !best.hidden ? best : nil;
}

static UIEvent *cur_event;
static BOOL touch_cancelled;
static NSMutableDictionary<NSNumber *, UITouch *> *active_touches;     /* finger -> touch */
static BOOL view_gets_touch(UITouch *t);

/* A recognizer that cancels touches in its view just recognized: the hit view gets
 * touchesCancelled once and no further touch callbacks for this sequence. */
void isim_ui_gesture_recognized(UIGestureRecognizer *g) {
    if (g.state == UIGestureRecognizerStateBegan && [cur_gestures containsObject:g]) {
        /* other recognizers still waiting give way to an exclusive one (or to anyone, if their delegate says not simultaneous) */
        for (UIGestureRecognizer *o in [cur_gestures copy]) {
            if (o == g || o.state != UIGestureRecognizerStatePossible) continue;
            id<UIGestureRecognizerDelegate> d = g.delegate, od = o.delegate;
            BOOL simul = ([d respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)] && [d gestureRecognizer:g shouldRecognizeSimultaneouslyWithGestureRecognizer:o])
                      || ([od respondsToSelector:@selector(gestureRecognizer:shouldRecognizeSimultaneouslyWithGestureRecognizer:)] && [od gestureRecognizer:o shouldRecognizeSimultaneouslyWithGestureRecognizer:g]);
            if (g._isim_exclusive && !simul) [cur_gestures removeObjectIdenticalTo:o];
        }
    }
    if (!g.cancelsTouchesInView || !cur_touch || touch_cancelled || ![cur_gestures containsObject:g]) return;
    touch_cancelled = YES;
    NSMutableSet *views = [NSMutableSet set];
    for (UITouch *t in active_touches.allValues) if (view_gets_touch(t) && t.view) [views addObject:t.view];
    for (UIView *v in views) {
        NSMutableSet *ts = [NSMutableSet set];
        for (UITouch *t in active_touches.allValues) if (t.view == v) [ts addObject:t];
        [v touchesCancelled:ts withEvent:cur_event];
    }
}

/* Touches. A touch sequence starts with the first finger down and ends when the last finger lifts; the second finger
 * (host Option-drag, script pinch/rotate2/twofinger; ev->pad = 1) joins it. Recognizers collected for the first touch
 * also get later touches inside their view if they handle several touches (pinch, rotation, pan, custom subclasses);
 * a view gets the extra touches if it isMultipleTouchEnabled (or the touch began on another view). */
static NSMutableSet<UITouch *> *all_touches(void) { return [NSMutableSet setWithArray:active_touches.allValues ?: @[]]; }
static BOOL view_gets_touch(UITouch *t) {
    return t == cur_touch || t.view != cur_touch.view || t.view.multipleTouchEnabled;
}
static BOOL synthesizing;
static void handle_touch(const struct isim_event *ev) {
    if (!synthesizing && isim_ui_touch_filtered(ev)) return;              /* VoiceOver, drag sessions (UIKitInputPrivate.h) */
    CGPoint p = CGPointMake(ev->x, ev->y);
    int finger = ev->pad == 1 ? 1 : 0;
    if (!active_touches) active_touches = [NSMutableDictionary dictionary];
    if (ev->type == ISIM_EV_TOUCH_DOWN && active_touches[@(finger)]) {    /* a lost up: end the old touch first */
        struct isim_event up = *ev; up.type = ISIM_EV_TOUCH_UP; handle_touch(&up);
    }
    if (ev->type == ISIM_EV_TOUCH_DOWN && cur_touch && active_touches.count) {
        /* another finger joins the sequence */
        UIWindow *w = cur_touch.window;
        CGPoint wp = CGPointMake(p.x - w.frame.origin.x, p.y - w.frame.origin.y);
        UIView *hit = [w hitTest:wp withEvent:nil] ?: cur_touch.view;
        UITouch *t = [[UITouch alloc] initWithIsimView:hit window:w location:wp time:ev->timestamp];
        [t _isim_setFinger:finger];
        active_touches[@(finger)] = t;
    } else if (ev->type == ISIM_EV_TOUCH_DOWN) {
        /* front-most window (by level) whose frame contains the point and has a view there */
        NSArray *ws = [UIApplication.sharedApplication.windows sortedArrayUsingComparator:^NSComparisonResult(UIWindow *a, UIWindow *b) {
            return a.windowLevel > b.windowLevel ? NSOrderedAscending : a.windowLevel < b.windowLevel ? NSOrderedDescending : NSOrderedSame; }];
        UIWindow *w = nil; UIView *hit = nil;
        for (UIWindow *c in ws) {
            if (c.hidden || !CGRectContainsPoint(c.frame, p) || !isim_ui_window_on_screen(c)) continue;
            hit = [c hitTest:CGPointMake(p.x - c.frame.origin.x, p.y - c.frame.origin.y) withEvent:nil];
            if (hit) { w = c; break; }
        }
        if (!hit) { cur_touch = nil; return; }
        if (!w.isKeyWindow && isim_ui_scenes_split() && w.windowScene && w.windowLevel == UIWindowLevelNormal) [w makeKeyWindow];   /* the touched side of a split view */
        cur_touch = [[UITouch alloc] initWithIsimView:hit window:w location:CGPointMake(p.x - w.frame.origin.x, p.y - w.frame.origin.y) time:ev->timestamp];
        [cur_touch _isim_setFinger:finger];
        [active_touches removeAllObjects];
        active_touches[@(finger)] = cur_touch;
        if (ev->timestamp - last_tap_time < 0.35 && hypot(p.x - last_tap_point.x, p.y - last_tap_point.y) < 20) [cur_touch setValue_isimTapCount:last_tap_count + 1];
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
                id<UIGestureRecognizerDelegate> gd = g.delegate;
                if ([gd respondsToSelector:@selector(gestureRecognizer:shouldReceiveTouch:)] && ![gd gestureRecognizer:g shouldReceiveTouch:cur_touch]) continue;
                [g _isim_beginTouchSequence];         /* forget touches of an earlier sequence it was dropped from */
                [cur_gestures addObject:g];
            }
            if (v == control) aboveControl = YES;
        }
    }
    UITouch *t = active_touches[@(finger)];
    if (!t) return;
    UITouchPhase phase = ev->type == ISIM_EV_TOUCH_DOWN ? UITouchPhaseBegan : ev->type == ISIM_EV_TOUCH_MOVE ? UITouchPhaseMoved : UITouchPhaseEnded;
    CGRect wf = t.window.frame;
    [t _isim_setPhase:phase location:CGPointMake(p.x - wf.origin.x, p.y - wf.origin.y) time:ev->timestamp];
    for (UITouch *o in active_touches.allValues) if (o != t) [o _isim_setStationary];
    UIEvent *e = [[UIEvent alloc] initWithIsimTouches:all_touches()];
    cur_event = e;
    NSSet *set = [NSSet setWithObject:t];
    UIView *v = t.view;
    BOOL toView = view_gets_touch(t);
    /* Began reaches the view before recognizers act on it, as on iOS (no delaysTouchesBegan). */
    if (phase == UITouchPhaseBegan && toView) [v touchesBegan:set withEvent:e];
    for (UIGestureRecognizer *g in [cur_gestures copy]) {
        if (![cur_gestures containsObject:g]) continue;
        if (t != cur_touch && (![g _isim_acceptsExtraTouches] || ![t.view isDescendantOfView:g.view])) continue;
        [g _isim_touch:t phase:phase event:e];
    }
    if (!touch_cancelled && toView) {
        if (phase == UITouchPhaseMoved) [v touchesMoved:set withEvent:e];
        else if (phase == UITouchPhaseEnded) [v touchesEnded:set withEvent:e];
    }
    if (phase == UITouchPhaseEnded) {
        [active_touches removeObjectForKey:@(finger)];
        if (t == cur_touch) { last_tap_time = ev->timestamp; last_tap_point = p; last_tap_count = t.tapCount; }
        if (!active_touches.count) { cur_touch = nil; cur_gestures = nil; cur_event = nil; }
    }
}
/* VoiceOver activation: a tap at a screen point that skips the touch filters */
void isim_ui_synthesize_tap(CGPoint p) {
    synthesizing = YES;
    struct isim_event ev = { .type = ISIM_EV_TOUCH_DOWN, .x = p.x, .y = p.y, .timestamp = isim_time() };
    handle_touch(&ev);
    ev.type = ISIM_EV_TOUCH_UP; ev.timestamp = isim_time() + 0.01;
    handle_touch(&ev);
    synthesizing = NO;
}
/* the touches currently down (drag sessions, VoiceOver) */
NSSet<UITouch *> *isim_ui_active_touches(void) { return all_touches(); }

/* hardware key presses and releases (USB HID usage in ev->pad) for GameController's GCKeyboard */
static void post_hardware_key(const struct isim_event *ev, BOOL down) {
    if (ev->pad <= 0) return;
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimHardwareKey" object:nil
                                                    userInfo:@{ @"usage": @(ev->pad), @"down": @(down), @"key": @(ev->key), @"mods": @(ev->mods) }];
}

/* hardware keyboard / scripted typing goes to the first responder if it accepts key input */
static void handle_key(const struct isim_event *ev) {
    if (ev->type == ISIM_EV_KEY) post_hardware_key(ev, YES);
    if (ev->type == ISIM_EV_KEY) {
        /* Device > Shake: Ctrl+Shift+Z, or the script command `shake` */
        BOOL ctrlShift = (ev->mods & 0x00c0) && (ev->mods & 0x0003);
        if (ev->key == 0x7fff0001 || (ctrlShift && (ev->key == 'z' || ev->key == 'Z'))) { isim_ui_shake(); return; }
        if (isim_ui_hardware_key(ev->pad, ev->key, ev->mods, YES)) return;     /* a UIKeyCommand took it */
    }
    id fr = isim_ui_first_responder();
    /* text navigation and editing shortcuts (arrows, Shift-select, Cmd/Ctrl+A/C/X/V, forward delete) */
    if (ev->type == ISIM_EV_KEY && [fr conformsToProtocol:@protocol(IsimEditableText)] && isim_ui_text_handle_key(fr, ev->pad, ev->mods)) { isim_ui_set_needs_display(); return; }
    if (![fr respondsToSelector:@selector(insertText:)]) return;
    if (ev->type == ISIM_EV_TEXT) [fr insertText:@(ev->text)];
    else if (ev->key == 8) [fr deleteBackward];
    else if (ev->key == 13) [fr insertText:@"\n"];
    else if (ev->key == 9) [fr insertText:@"\t"];
    isim_ui_set_needs_display();
}

static void dump_view(UIView *v, int depth) {
    CGRect f = v.frame;
    NSString *ident = v.accessibilityIdentifier, *label = [v respondsToSelector:@selector(_isim_dumpText)] ? [(id)v _isim_dumpText]
        : [v isKindOfClass:[UILabel class]] ? ((UILabel *)v).text : [v isKindOfClass:[UIButton class]] ? ((UIButton *)v).currentTitle
        : [v isKindOfClass:[UITextField class]] ? [NSString stringWithFormat:@"\"%@\"%@", ((UITextField *)v).text, v.isFirstResponder ? @" (editing)" : @""]
        : [v isKindOfClass:[UIScrollView class]] ? [NSString stringWithFormat:@"offset %g, content %g x %g, inset bottom %g", ((UIScrollView *)v).contentOffset.y,
              ((UIScrollView *)v).contentSize.width, ((UIScrollView *)v).contentSize.height, ((UIScrollView *)v).adjustedContentInset.bottom]
        : [v isKindOfClass:[UISwitch class]] ? (((UISwitch *)v).on ? @"on" : @"off")
        : [v isKindOfClass:[UISlider class]] ? [NSString stringWithFormat:@"%g", ((UISlider *)v).value]
        : [v isKindOfClass:[UISegmentedControl class]] ? [NSString stringWithFormat:@"segment %ld", (long)((UISegmentedControl *)v).selectedSegmentIndex] : nil;
    static int ax = -1;
    if (ax < 0) { const char *e = getenv("ISIM_DUMP_ACCESSIBILITY"); ax = e && *e && strcmp(e, "0"); }   /* ax="label, value, traits" */
    NSString *axs = ax ? isim_ui_accessibility_dump(v) : nil;
    fprintf(stderr, "%*s%s (%g %g; %g x %g)%s%s%s%s%s%s%s%s%s\n", depth * 2, "", class_getName(object_getClass(v)), f.origin.x, f.origin.y, f.size.width, f.size.height,
            v.hidden ? " hidden" : "", v.alpha < 1 ? " alpha<1" : "", ident ? " id=" : "", ident ? ident.UTF8String : "", label ? " text=" : "", label ? label.UTF8String : "",
            axs ? " ax=\"" : "", axs ? axs.UTF8String : "", axs ? "\"" : "");
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
    if (ev->type == ISIM_EV_ID_DOWN && ev->mods == 1) {          /* script "swipeid ID dx dy seconds" */
        double x0 = t.x, y0 = t.y, dx = ev->x, dy = ev->y, dur = fmax(0.05, ev->key / 1000.0), start = isim_time();
        handle_touch(&t);
        [NSTimer scheduledTimerWithTimeInterval:1.0 / 60 repeats:YES block:^(NSTimer *timer) {
            double k = fmin(1, (isim_time() - start) / dur);
            struct isim_event m = { .type = k >= 1 ? ISIM_EV_TOUCH_UP : ISIM_EV_TOUCH_MOVE, .x = x0 + dx * k, .y = y0 + dy * k, .timestamp = isim_time() };
            if (k >= 1) { struct isim_event last = m; last.type = ISIM_EV_TOUCH_MOVE; handle_touch(&last); [timer invalidate]; }
            handle_touch(&m);
        }];
        return;
    }
    handle_touch(&t);
}

@implementation UITouch (IsimTap)
- (void)setValue_isimTapCount:(NSUInteger)n { self.tapCount = n; }
@end

static void render_frame(void) {
    { extern void isim_ui_trait_registrations_tick(void); isim_ui_trait_registrations_tick(); }
    isim_ui_keyboard_check();
    { extern void isim_ui_accessibility_frame_tick(void); isim_ui_accessibility_frame_tick(); }
    isim_ui_display_links_fire();
    isim_ui_update_links_fire();                      /* UIUpdateLink (UIUpdates.m) */
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
    if (isim_ui_scenes_split()) { double black[4] = { 0, 0, 0, 1 }; CGRect sb = UIScreen.mainScreen.bounds; isim_gfx_fill_rounded(0, 0, sb.size.width, sb.size.height, 0, black); }   /* split view divider */
    for (UIWindow *w in ws) if (!w.hidden && isim_ui_window_on_screen(w)) [w _isim_renderFrame];
    isim_frame_end();
}

/* ---- Debug > Simulate Memory Warning (script memorywarning): the app delegate, the notification, every view
   controller in the windows (children and presented ones included) ---- */
NSNotificationName const UIApplicationDidReceiveMemoryWarningNotification = @"UIApplicationDidReceiveMemoryWarningNotification";
static void vc_memory_warning(UIViewController *vc, NSMutableSet *seen) {
    if (!vc || [seen containsObject:vc]) return;
    [seen addObject:vc];
    [vc didReceiveMemoryWarning];
    for (UIViewController *c in vc.childViewControllers) vc_memory_warning(c, seen);
    if (vc.presentedViewController.presentingViewController == vc) vc_memory_warning(vc.presentedViewController, seen);
}
void isim_ui_memory_warning(void) {
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSLog(@"isim: received memory warning");
    if ([d respondsToSelector:@selector(applicationDidReceiveMemoryWarning:)]) [d applicationDidReceiveMemoryWarning:app];
    [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidReceiveMemoryWarningNotification object:app];
    NSMutableSet *seen = [NSMutableSet set];
    for (UIWindow *w in app.windows) vc_memory_warning(w.rootViewController, seen);
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
/* UISystemIntegration.m: launch payloads (quick actions, user activities), state restoration, background work */
NSDictionary *isim_sys_launch_options(void);
void isim_sys_did_finish_launching(BOOL result);
void isim_sys_configure_connection(UISceneConnectionOptions *options, UISceneSession *session);
void isim_sys_scene_connected(UIScene *scene);
BOOL isim_sys_deliver_launch(void);
BOOL isim_sys_open_url(NSString *url);
BOOL isim_sys_background_launch(void);
void isim_sys_after_background_launch(void);
void isim_sys_entered_background(void);
void isim_sys_mark_background(void);
void isim_sys_entered_foreground(void);
void isim_sys_event(const char *text);
static NSDictionary *pending_scene_manifest;     /* launched in the background: the UI scene connects on first foreground */
void isim_ui_scenes_launch(NSDictionary *manifest);
/* the scenes on screen (UIScenes section below): the app's foreground/background moves only them */
static NSArray<UIScene *> *on_screen_scenes(void);
static void each_scene_delegate(void (^f)(UIScene *, id<UISceneDelegate>)) {
    for (UIScene *s in on_screen_scenes()) f(s, s.delegate);
}
BOOL isim_sys_background_audio(void);
static void enter_background(void) {
    if (!isim_sys_background_audio()) isim_audio_suspend(1);       /* like an interrupted audio session (UIBackgroundModes audio + a playback category keep playing) */
    if (backgrounded) return;
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { if ([sd respondsToSelector:@selector(sceneWillResignActive:)]) [sd sceneWillResignActive:s];
        [nc postNotificationName:UISceneWillDeactivateNotification object:s]; });
    if ([d respondsToSelector:@selector(applicationWillResignActive:)]) [d applicationWillResignActive:app];
    [nc postNotificationName:UIApplicationWillResignActiveNotification object:app];
    backgrounded = YES; app.applicationState = UIApplicationStateBackground;
    isim_sys_mark_background();
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateBackground; if ([sd respondsToSelector:@selector(sceneDidEnterBackground:)]) [sd sceneDidEnterBackground:s];
        [nc postNotificationName:UISceneDidEnterBackgroundNotification object:s]; });
    if ([d respondsToSelector:@selector(applicationDidEnterBackground:)]) [d applicationDidEnterBackground:app];
    [nc postNotificationName:UIApplicationDidEnterBackgroundNotification object:app];
    [isim_ui_first_responder() resignFirstResponder];
    isim_sys_entered_background();
}
static void enter_foreground(void) {
    isim_audio_suspend(0);
    if (!backgrounded) { isim_ui_set_needs_display(); return; }
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    isim_sys_entered_foreground();
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateForegroundInactive; if ([sd respondsToSelector:@selector(sceneWillEnterForeground:)]) [sd sceneWillEnterForeground:s];
        [nc postNotificationName:UISceneWillEnterForegroundNotification object:s]; });
    if ([d respondsToSelector:@selector(applicationWillEnterForeground:)]) [d applicationWillEnterForeground:app];
    [nc postNotificationName:UIApplicationWillEnterForegroundNotification object:app];
    /* values changed in Settings (Settings.bundle) while the app was in the background */
    if ([NSUserDefaults.standardUserDefaults respondsToSelector:NSSelectorFromString(@"_isim_reloadFromDisk")] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(NSUserDefaults.standardUserDefaults, NSSelectorFromString(@"_isim_reloadFromDisk")))
        [nc postNotificationName:@"NSUserDefaultsDidChangeNotification" object:NSUserDefaults.standardUserDefaults];
    backgrounded = NO; app.applicationState = UIApplicationStateActive;
    each_scene_delegate(^(UIScene *s, id<UISceneDelegate> sd) { s.activationState = UISceneActivationStateForegroundActive; if ([sd respondsToSelector:@selector(sceneDidBecomeActive:)]) [sd sceneDidBecomeActive:s];
        [nc postNotificationName:UISceneDidActivateNotification object:s]; });
    if ([d respondsToSelector:@selector(applicationDidBecomeActive:)]) [d applicationDidBecomeActive:app];
    [nc postNotificationName:UIApplicationDidBecomeActiveNotification object:app];
    if (pending_scene_manifest) { NSDictionary *m = pending_scene_manifest; pending_scene_manifest = nil; isim_ui_scenes_launch(m); }
    isim_ui_set_needs_layout();
}
static void settings_changed(void) {
    extern void isim_ui_reload_settings(void);
    extern void isim_reapply_time_zone_setting(void);
    isim_ui_reload_settings();
    isim_reapply_time_zone_setting();                 /* Date & Time > Time Zone applies live */
    isim_ui_accessibility_reload_settings();          /* Settings > Accessibility (Dynamic Type, VoiceOver, ...) */
    isim_ui_traits_flush();                           /* appearance, Dynamic Type, contrast, bold text: traitCollectionDidChange: */
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimSettingsChanged" object:nil];
    isim_ui_set_needs_display();
}
static void deliver_url(NSString *s) {
    if (isim_sys_open_url(s)) return;          /* quick actions, user activities, scene URL contexts */
    NSURL *url = [NSURL URLWithString:s];
    if (!url) return;
    extern BOOL isim_ui_open_web_url(NSURL *url);
    if (isim_ui_open_web_url(url)) return;            /* http(s): a universal link of this app, or Safari (UIUniversalLinks.m) */
    UIApplication *app = UIApplication.sharedApplication; id<UIApplicationDelegate> d = app.delegate;
    NSLog(@"isim: opening URL %@ in the app", s);
    if ([d respondsToSelector:@selector(application:openURL:options:)]) [(id)d application:app openURL:url options:@{}];
    [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimOpenURL" object:url];     /* SwiftUI .onOpenURL */
}

static void layout_all(void) {
    isim_ui_traits_flush();
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

/* ================= scenes: connection, multiple windows, sessions =================
 * Scene-based apps connect a scene at launch (the scene manifest, or the app delegate's configuration). On iPad with
 * UIApplicationSupportsMultipleScenes, requestSceneSessionActivation / activateSceneSession(for:) connect more
 * scenes (or bring an existing session back): up to two are on screen side by side (split view: 1/2, 2/3 or 1/3 of
 * the width after their sizeRestrictions.minimumSize, a 10 pt divider), a prominent request takes the whole screen,
 * the others wait in the background (activationState background, their windows neither drawn nor touched).
 * requestSceneSessionDestruction disconnects a scene and discards its session (application:didDiscardSceneSessions:).
 * Open sessions are kept in the app container (Library/isim/SceneSessions.plist: identifier, configuration name,
 * userInfo, state restoration activity) and reconnected on the next launch, like iPadOS restores an app's windows;
 * closing the app in the app switcher discards them (reported by application:didDiscardSceneSessions: next launch). */
static NSDictionary *scene_manifest;
static NSMutableArray<UIWindowScene *> *shown_scenes;            /* on screen, left to right */
static BOOL scenes_multi(void) { return UIApplication.sharedApplication.supportsMultipleScenes; }
static NSArray<UIScene *> *on_screen_scenes(void) {
    NSMutableArray *a = [NSMutableArray arrayWithArray:shown_scenes ?: @[]];
    for (UIScene *s in UIApplication.sharedApplication.connectedScenes) if (![s isKindOfClass:[UIWindowScene class]] && ![a containsObject:s]) [a addObject:s];
    return a;
}
BOOL isim_ui_scenes_split(void) { return shown_scenes.count > 1; }
/* windows of a connected scene that is not on screen are not drawn (their scene waits in the background) */
BOOL isim_ui_window_on_screen(UIWindow *w) {
    UIWindowScene *s = w.windowScene;
    if (!s || !shown_scenes || ![UIApplication.sharedApplication.connectedScenes containsObject:s]) return YES;
    return [shown_scenes containsObject:s];
}
static NSString *sessions_file(void) {
    NSString *d = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/isim"];
    [NSFileManager.defaultManager createDirectoryAtPath:d withIntermediateDirectories:YES attributes:nil error:NULL];
    return [d stringByAppendingPathComponent:@"SceneSessions.plist"];
}
@interface NSUserActivity (IsimPlist)
- (NSDictionary *)_isim_plist;
+ (NSUserActivity *)_isim_activityWithPlist:(NSDictionary *)plist;
@end
/* the open sessions, in the order they were connected, the ones on screen marked */
static NSMutableArray<UISceneSession *> *session_order;
static void save_sessions(void) {
    if (!scenes_multi()) return;
    NSMutableArray *out = [NSMutableArray array];
    for (UISceneSession *ss in session_order) {
        NSMutableDictionary *e = [NSMutableDictionary dictionary];
        e[@"id"] = ss.persistentIdentifier ?: @"";
        if (ss.configuration.name) e[@"config"] = ss.configuration.name;
        if (ss.userInfo && [NSPropertyListSerialization propertyList:ss.userInfo isValidForFormat:NSPropertyListBinaryFormat_v1_0]) e[@"userInfo"] = ss.userInfo;
        if (ss.stateRestorationActivity) e[@"activity"] = [ss.stateRestorationActivity _isim_plist];
        NSUInteger at = [shown_scenes indexOfObjectIdenticalTo:(UIWindowScene *)ss.scene];
        if (at != NSNotFound) e[@"shown"] = @(at + 1);             /* position on screen, 1 = leading */
        [out addObject:e];
    }
    [@{ @"sessions": out } writeToFile:sessions_file() atomically:YES];
}
static void scene_log(void) {
    NSMutableArray *parts = [NSMutableArray array];
    for (UISceneSession *ss in session_order) {
        UIWindowScene *s = (UIWindowScene *)ss.scene;
        if (!s) continue;
        CGRect f = [s respondsToSelector:@selector(_isim_frame)] ? [s _isim_frame] : CGRectZero;
        [parts addObject:[shown_scenes containsObject:s] ? [NSString stringWithFormat:@"%@ (%g..%g)", ss.persistentIdentifier, f.origin.x, CGRectGetMaxX(f)]
                                                       : [NSString stringWithFormat:@"%@ (background)", ss.persistentIdentifier]];
    }
    NSLog(@"isim: scenes: %@", [parts componentsJoinedByString:@", "]);
}

/* ---- layout: the scenes on screen take the whole screen, or split it ---- */
/* transition: the root controllers get viewWillTransitionToSize (a split-view resize; rotation does its own) */
extern id isim_ui_immediate_coordinator(void);
extern void isim_ui_coordinator_finish(id coordinator);
static void apply_scene_frame(UIWindowScene *s, CGRect f, BOOL transition, UIInterfaceOrientation oldOrientation, CGRect old) {
    __IsimSceneSpace *oldSpace = [__IsimSceneSpace new]; oldSpace.frame = old;
    UITraitCollection *oldTraits = [s _isim_traitsForWindowSize:old.size];
    BOOL placed = [s _isim_hasFrame];                   /* a scene's first placement is not an update */
    [s _isim_setFrame:f];
    id coord = transition && !CGSizeEqualToSize(old.size, f.size) ? isim_ui_immediate_coordinator() : nil;
    if (coord) for (UIWindow *w in s.windows) [w.rootViewController viewWillTransitionToSize:f.size withTransitionCoordinator:coord];
    for (UIWindow *w in s.windows) if (!CGRectEqualToRect(w.frame, f)) { w.frame = f; [w setNeedsLayout]; }
    if (coord) isim_ui_coordinator_finish(coord);
    if (placed && (!CGSizeEqualToSize(old.size, f.size) || oldOrientation != s.interfaceOrientation)) {
        id<UIWindowSceneDelegate> d = (id<UIWindowSceneDelegate>)s.delegate;
        if ([d respondsToSelector:@selector(windowScene:didUpdateCoordinateSpace:interfaceOrientation:traitCollection:)])
            [d windowScene:s didUpdateCoordinateSpace:oldSpace interfaceOrientation:oldOrientation traitCollection:oldTraits];
    }
}
static void layout_scenes(BOOL transition, UIInterfaceOrientation oldOrientation, CGSize oldScreen) {
    CGRect screen = UIScreen.mainScreen.bounds;
    CGRect (^was)(UIWindowScene *) = ^CGRect(UIWindowScene *s) { CGRect r = [s _isim_frame]; return oldScreen.width > 0 && CGRectEqualToRect(r, screen) ? CGRectMake(0, 0, oldScreen.width, oldScreen.height) : r; };
    if (shown_scenes.count == 2) {
        CGFloat gap = 10, avail = screen.size.width - gap;
        CGFloat minA = shown_scenes[0].sizeRestrictions.minimumSize.width, minB = shown_scenes[1].sizeRestrictions.minimumSize.width;
        const CGFloat ratios[] = { 0.5, 2.0 / 3, 1.0 / 3 };
        CGFloat left = -1;
        for (int i = 0; i < 3 && left < 0; i++) { CGFloat l = round(avail * ratios[i]); if (l >= minA && avail - l >= minB) left = l; }
        if (left < 0) left = round(avail / 2);
        apply_scene_frame(shown_scenes[0], CGRectMake(0, 0, left, screen.size.height), transition, oldOrientation, was(shown_scenes[0]));
        apply_scene_frame(shown_scenes[1], CGRectMake(left + gap, 0, avail - left, screen.size.height), transition, oldOrientation, was(shown_scenes[1]));
    } else if (shown_scenes.count == 1) apply_scene_frame(shown_scenes[0], screen, transition, oldOrientation, was(shown_scenes[0]));
    isim_ui_traits_invalidate(nil);
    isim_ui_set_needs_layout();
}
void isim_ui_layout_scenes(void) { layout_scenes(YES, shown_scenes.lastObject.interfaceOrientation, CGSizeZero); }
/* after a rotation (UIOrientation.m): the scenes take the new screen; their delegates hear of the old orientation */
void isim_ui_scenes_rotated(UIInterfaceOrientation oldOrientation, CGSize oldScreen) { if (shown_scenes.count) layout_scenes(NO, oldOrientation, oldScreen); }
/* the scene leaves the screen (another took its place) / comes on screen */
static void scene_to_background(UIWindowScene *s) {
    if (![shown_scenes containsObject:s]) return;
    [shown_scenes removeObject:s];
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter; id<UISceneDelegate> d = s.delegate;
    /* like iOS, the scene's state is asked for as it goes to the background (kept with its session) */
    if ([d respondsToSelector:@selector(stateRestorationActivityForScene:)]) s.session.stateRestorationActivity = [d stateRestorationActivityForScene:s];
    if (s.activationState == UISceneActivationStateForegroundActive) {
        s.activationState = UISceneActivationStateForegroundInactive;
        if ([d respondsToSelector:@selector(sceneWillResignActive:)]) [d sceneWillResignActive:s];
        [nc postNotificationName:UISceneWillDeactivateNotification object:s];
    }
    s.activationState = UISceneActivationStateBackground;
    if ([d respondsToSelector:@selector(sceneDidEnterBackground:)]) [d sceneDidEnterBackground:s];
    [nc postNotificationName:UISceneDidEnterBackgroundNotification object:s];
}
static void scene_to_foreground(UIWindowScene *s) {
    NSNotificationCenter *nc = NSNotificationCenter.defaultCenter; id<UISceneDelegate> d = s.delegate;
    if (UIApplication.sharedApplication.applicationState == UIApplicationStateBackground && s.activationState != UISceneActivationStateUnattached) return;
    if (s.activationState == UISceneActivationStateBackground || s.activationState == UISceneActivationStateUnattached) {
        s.activationState = UISceneActivationStateForegroundInactive;
        if ([d respondsToSelector:@selector(sceneWillEnterForeground:)]) [d sceneWillEnterForeground:s];
        [nc postNotificationName:UISceneWillEnterForegroundNotification object:s];
    }
    if (s.activationState != UISceneActivationStateForegroundActive) {
        s.activationState = UISceneActivationStateForegroundActive;
        if ([d respondsToSelector:@selector(sceneDidBecomeActive:)]) [d sceneDidBecomeActive:s];
        [nc postNotificationName:UISceneDidActivateNotification object:s];
    }
}
/* put a scene on screen: next to the requesting / most recent one (split view), or alone (prominent, iPhone) */
static void show_scene(UIWindowScene *s, UISceneActivationRequestOptions *options) {
    if (!shown_scenes) shown_scenes = [NSMutableArray array];
    BOOL prominent = [options isKindOfClass:[UIWindowSceneActivationRequestOptions class]] && ((UIWindowSceneActivationRequestOptions *)options).preferredPresentationStyle == UIWindowScenePresentationStyleProminent;
    if (![shown_scenes containsObject:s]) {
        if (!scenes_multi() || prominent || !s.sizeRestrictions.allowsFullScreen) {
            for (UIWindowScene *o in [shown_scenes copy]) scene_to_background(o);
        } else {
            UIScene *keep = options.requestingScene;
            while (shown_scenes.count >= 2) {               /* the oldest that is not the requesting scene makes room */
                UIWindowScene *drop = shown_scenes.firstObject == keep ? shown_scenes[1] : shown_scenes.firstObject;
                scene_to_background(drop);
            }
            /* scenes too wide to share the screen go alone */
            CGFloat avail = UIScreen.mainScreen.bounds.size.width - 10;
            for (UIWindowScene *o in [shown_scenes copy])
                if (o.sizeRestrictions.minimumSize.width > avail * 2 / 3 || s.sizeRestrictions.minimumSize.width > avail * 2 / 3) scene_to_background(o);
        }
        [shown_scenes addObject:s];
    }
    isim_ui_layout_scenes();
    scene_to_foreground(s);
    UIWindow *w = s.keyWindow ?: s.windows.firstObject;
    if (w && !w.hidden) [w makeKeyWindow];
    save_sessions();
    scene_log();
}

static Class class_named(NSString *name);
/* connects a scene for a new session (session nil) or a stored one; activity: the user activity that asked for it */
/* a session kept from the last run: identifier, configuration (by name), userInfo, state restoration activity */
static UISceneSession *session_from_saved(NSDictionary *e) {
    UISceneSession *ss = [UISceneSession new];
    ss.role = UIWindowSceneSessionRoleApplication;
    ss.persistentIdentifier = [e[@"id"] isKindOfClass:[NSString class]] ? e[@"id"] : [NSString stringWithFormat:@"isim-%08X", arc4random()];
    if ([e[@"config"] isKindOfClass:[NSString class]]) ss.configuration = [UISceneConfiguration configurationWithName:e[@"config"] sessionRole:UIWindowSceneSessionRoleApplication];
    if ([e[@"userInfo"] isKindOfClass:[NSDictionary class]]) ss.userInfo = e[@"userInfo"];
    if ([e[@"activity"] isKindOfClass:[NSDictionary class]]) ss.stateRestorationActivity = [NSUserActivity _isim_activityWithPlist:e[@"activity"]];
    return ss;
}
static UIScene *connect_session_shown(UISceneSession *reuse, NSUserActivity *activity, UISceneActivationRequestOptions *requestOptions, BOOL launch, NSDictionary *saved, BOOL show);
static UIScene *connect_session(UISceneSession *reuse, NSUserActivity *activity, UISceneActivationRequestOptions *requestOptions, BOOL launch, NSDictionary *saved) {
    return connect_session_shown(reuse, activity, requestOptions, launch, saved, YES);
}
static UIScene *connect_session_shown(UISceneSession *reuse, NSUserActivity *activity, UISceneActivationRequestOptions *requestOptions, BOOL launch, NSDictionary *saved, BOOL show) {
    UIApplication *app = UIApplication.sharedApplication;
    NSDictionary *configs = scene_manifest[@"UISceneConfigurations"];
    NSArray *roleConfigs = configs[UIWindowSceneSessionRoleApplication];
    UISceneSession *session = reuse;
    if (!session) {
        session = [UISceneSession new];
        session.role = UIWindowSceneSessionRoleApplication;
        session.persistentIdentifier = saved[@"id"] ?: [NSString stringWithFormat:@"isim-%08X", arc4random()];
        if ([saved[@"userInfo"] isKindOfClass:[NSDictionary class]]) session.userInfo = saved[@"userInfo"];
    }
    UISceneConnectionOptions *options = [UISceneConnectionOptions new];
    extern void isim_sys_configure_connection(UISceneConnectionOptions *options, UISceneSession *session);
    extern void isim_sys_connection_activity(UISceneConnectionOptions *options, NSUserActivity *activity);
    NSUserActivity *kept = session.stateRestorationActivity;        /* a restored session's own state wins */
    if (launch) isim_sys_configure_connection(options, session);   /* launch payloads, saved state restoration */
    if (kept) session.stateRestorationActivity = kept;
    if ([saved[@"activity"] isKindOfClass:[NSDictionary class]]) session.stateRestorationActivity = [NSUserActivity _isim_activityWithPlist:saved[@"activity"]];
    if (activity) isim_sys_connection_activity(options, activity);
    UISceneConfiguration *config = nil;
    id<UIApplicationDelegate> d = app.delegate;
    if ([d respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)])
        config = [d application:app configurationForConnectingSceneSession:session options:options];
    NSString *wantName = config.name ?: saved[@"config"] ?: reuse.configuration.name;
    NSDictionary *plistConfig = roleConfigs.firstObject;
    for (NSDictionary *pc in roleConfigs) if (wantName && [pc[@"UISceneConfigurationName"] isEqualToString:wantName]) plistConfig = pc;
    if (!config) config = [UISceneConfiguration configurationWithName:plistConfig[@"UISceneConfigurationName"] sessionRole:UIWindowSceneSessionRoleApplication];
    if (!config.delegateClass) config.delegateClass = class_named(plistConfig[@"UISceneDelegateClassName"]);
    if (!config.sceneClass) config.sceneClass = class_named(plistConfig[@"UISceneClassName"]) ?: [UIWindowScene class];
    if (!config.storyboard && plistConfig[@"UISceneStoryboardFile"])
        config.storyboard = [UIStoryboard storyboardWithName:plistConfig[@"UISceneStoryboardFile"] bundle:nil];
    session.configuration = config;
    UIScene *scene = [[config.sceneClass alloc] initWithSession:session connectionOptions:options];
    session.scene = scene;
    [app _isim_addScene:scene session:session];
    if (!session_order) session_order = [NSMutableArray array];
    if (![session_order containsObject:session]) [session_order addObject:session];
    if (config.delegateClass) scene.delegate = [config.delegateClass new];
    id<UISceneDelegate> sd = scene.delegate;
    /* a storyboard scene: the window and its initial view controller exist before scene:willConnectToSession: */
    UIWindow *storyboardWindow = config.storyboard && [scene isKindOfClass:[UIWindowScene class]]
        ? isim_ib_storyboard_window(config.storyboard, (UIWindowScene *)scene, sd) : nil;
    [NSNotificationCenter.defaultCenter postNotificationName:UISceneWillConnectNotification object:scene];
    if ([sd respondsToSelector:@selector(scene:willConnectToSession:options:)]) [sd scene:scene willConnectToSession:session options:options];
    if (storyboardWindow.hidden) [storyboardWindow makeKeyAndVisible];
    extern void isim_sys_scene_connected(UIScene *scene);
    if (launch) isim_sys_scene_connected(scene);
    else if (session.stateRestorationActivity && [sd respondsToSelector:@selector(scene:restoreInteractionStateWithUserActivity:)])
        [sd scene:scene restoreInteractionStateWithUserActivity:session.stateRestorationActivity];
    if (!show) return scene;
    if ([scene isKindOfClass:[UIWindowScene class]]) show_scene((UIWindowScene *)scene, requestOptions);
    else scene_to_foreground((UIWindowScene *)scene);
    return scene;
}

/* launch: the app's first scene, or the sessions it had open (iPad, multiple scenes) */
void isim_ui_scenes_launch(NSDictionary *manifest) {
    scene_manifest = manifest ?: @{};
    UIApplication *app = UIApplication.sharedApplication;
    /* sessions discarded in the app switcher since the last launch */
    NSString *discarded = [sessions_file() stringByAppendingString:@".discarded"];
    NSArray *gone = [NSDictionary dictionaryWithContentsOfFile:discarded][@"sessions"];
    if (gone.count) {
        NSMutableSet *set = [NSMutableSet set];
        for (NSDictionary *e in gone) {
            UISceneSession *ss = [UISceneSession new]; ss.role = UIWindowSceneSessionRoleApplication; ss.persistentIdentifier = e[@"id"];
            ss.configuration = [UISceneConfiguration configurationWithName:e[@"config"] sessionRole:UIWindowSceneSessionRoleApplication];
            [set addObject:ss];
        }
        id<UIApplicationDelegate> d = app.delegate;
        if ([d respondsToSelector:@selector(application:didDiscardSceneSessions:)]) [d application:app didDiscardSceneSessions:set];
        NSLog(@"isim: %lu discarded scene session(s)", (unsigned long)set.count);
    }
    [NSFileManager.defaultManager removeItemAtPath:discarded error:NULL];
    NSArray *saved = scenes_multi() ? [NSDictionary dictionaryWithContentsOfFile:sessions_file()][@"sessions"] : nil;
    if (saved.count > 1) {
        /* every session stays open; the ones that were on screen connect again, side by side as before (the others
           connect when they are activated) */
        NSLog(@"isim: restoring %lu scene sessions", (unsigned long)saved.count);
        if (!session_order) session_order = [NSMutableArray array];
        NSMutableArray *entries = [NSMutableArray array];
        for (NSDictionary *e in saved) {
            if (![e isKindOfClass:[NSDictionary class]]) continue;
            UISceneSession *ss = session_from_saved(e);
            [session_order addObject:ss]; [app _isim_addScene:nil session:ss];
            if ([e[@"shown"] boolValue]) [entries addObject:@[ss, e]];
        }
        if (!entries.count) entries = [NSMutableArray arrayWithObject:@[session_order.lastObject, saved.lastObject]];
        [entries sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [a[1][@"shown"] compare:b[1][@"shown"] ?: @0]; }];
        while (entries.count > 2) [entries removeObjectAtIndex:0];
        if (!shown_scenes) shown_scenes = [NSMutableArray array];
        BOOL first = YES;
        for (NSArray *pair in entries) {
            UIScene *s = connect_session_shown(pair[0], nil, nil, first, pair[1], NO);
            first = NO;
            if ([s isKindOfClass:[UIWindowScene class]]) [shown_scenes addObject:(UIWindowScene *)s];
        }
        layout_scenes(NO, UIInterfaceOrientationPortrait, CGSizeZero);
        for (UIWindowScene *s in [shown_scenes copy]) scene_to_foreground(s);
        UIWindow *key = shown_scenes.lastObject.keyWindow ?: shown_scenes.lastObject.windows.firstObject;
        if (key) [key makeKeyWindow];
        save_sessions(); scene_log();
        return;
    }
    connect_session(nil, nil, nil, YES, saved.firstObject);
}
/* the app was closed in the app switcher: its sessions are discarded (told on the next launch) */
void isim_ui_scenes_discarded(void) {
    NSString *f = sessions_file();
    [NSFileManager.defaultManager removeItemAtPath:[f stringByAppendingString:@".discarded"] error:NULL];
    NSData *d = [NSData dataWithContentsOfFile:f];
    if (d) { [d writeToFile:[f stringByAppendingString:@".discarded"] atomically:YES]; [NSFileManager.defaultManager removeItemAtPath:f error:NULL]; }
}
/* the app went to the background: keep each session's state (stateRestorationActivity is set by UISystemIntegration.m) */
void isim_ui_scenes_save(void) { save_sessions(); }

static void scene_error(void (^handler)(NSError *), UISceneErrorCode code, NSString *msg) {
    NSLog(@"isim: scene request failed: %@", msg);
    if (!handler) return;
    NSError *e = [NSError errorWithDomain:UISceneErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey: msg }];
    dispatch_async(dispatch_get_main_queue(), ^{ handler(e); });
}
@implementation UIApplication (UIMultipleScenes)
- (void)requestSceneSessionActivation:(UISceneSession *)session userActivity:(NSUserActivity *)activity options:(UISceneActivationRequestOptions *)options errorHandler:(void (^)(NSError *))errorHandler {
    if (session && ![self.openSessions containsObject:session]) { scene_error(errorHandler, UISceneErrorCodeRequestDenied, @"The scene session is not open."); return; }
    UIScene *existing = session.scene;
    if (existing && [existing isKindOfClass:[UIWindowScene class]]) {             /* an existing session: back on screen */
        NSLog(@"isim: activating scene session %@", session.persistentIdentifier);
        if (activity) {
            id<UISceneDelegate> d = existing.delegate;
            if ([d respondsToSelector:@selector(scene:continueUserActivity:)]) [d scene:existing continueUserActivity:activity];
        }
        show_scene((UIWindowScene *)existing, options);
        return;
    }
    if (!self.supportsMultipleScenes && self.connectedScenes.count) {
        scene_error(errorHandler, UISceneErrorCodeMultipleScenesNotSupported, @"The application does not support multiple scenes.");
        return;
    }
    if (!scene_manifest) scene_manifest = NSBundle.mainBundle.infoDictionary[@"UIApplicationSceneManifest"] ?: @{};
    NSLog(@"isim: activating a new scene%@%@", activity ? @" for " : @"", activity.activityType ?: @"");
    connect_session(session, activity, options, NO, nil);
}
- (void)activateSceneSessionForRequest:(UISceneSessionActivationRequest *)request errorHandler:(void (^)(NSError *))errorHandler {
    if (request.role && ![request.role isEqualToString:UIWindowSceneSessionRoleApplication]) {
        scene_error(errorHandler, UISceneErrorCodeRequestDenied, [NSString stringWithFormat:@"isim has no scenes for the role %@.", request.role]);
        return;
    }
    [self requestSceneSessionActivation:request.session userActivity:request.userActivity options:request.options errorHandler:errorHandler];
}
- (void)requestSceneSessionDestruction:(UISceneSession *)session options:(UISceneDestructionRequestOptions *)options errorHandler:(void (^)(NSError *))errorHandler {
    if (!session || ![self.openSessions containsObject:session]) { scene_error(errorHandler, UISceneErrorCodeRequestDenied, @"The scene session is not open."); return; }
    UIScene *s = session.scene;
    NSLog(@"isim: destroying scene session %@", session.persistentIdentifier);
    if ([s isKindOfClass:[UIWindowScene class]]) {
        BOOL wasShown = [shown_scenes containsObject:(UIWindowScene *)s];
        scene_to_background((UIWindowScene *)s);
        for (UIWindow *w in ((UIWindowScene *)s).windows) { [w.rootViewController _isim_appear:NO]; w.hidden = YES; }
        /* the remaining scene takes the screen; with none left on screen, the most recent other one comes back */
        if (wasShown && !shown_scenes.count) for (UISceneSession *o in session_order.reverseObjectEnumerator)
            if (o != session && [o.scene isKindOfClass:[UIWindowScene class]]) { [shown_scenes addObject:(UIWindowScene *)o.scene]; scene_to_foreground((UIWindowScene *)o.scene); break; }
        isim_ui_layout_scenes();
    }
    if (s) {
        s.activationState = UISceneActivationStateUnattached;
        if ([s.delegate respondsToSelector:@selector(sceneDidDisconnect:)]) [s.delegate sceneDidDisconnect:s];
        [NSNotificationCenter.defaultCenter postNotificationName:UISceneDidDisconnectNotification object:s];
    }
    session.scene = nil;
    [session_order removeObject:session];
    [self _isim_removeScene:s session:session];
    id<UIApplicationDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(application:didDiscardSceneSessions:)]) [d application:self didDiscardSceneSessions:[NSSet setWithObject:session]];
    UIWindow *key = ((UIWindowScene *)shown_scenes.lastObject).keyWindow ?: ((UIWindowScene *)shown_scenes.lastObject).windows.firstObject;
    if (key) [key makeKeyWindow];
    save_sessions();
    scene_log();
}
/* the session's snapshot in the app switcher would be refreshed (isim keeps no snapshots) */
- (void)requestSceneSessionRefresh:(UISceneSession *)session { NSLog(@"isim: scene session %@ refresh requested", session.persistentIdentifier); }
@end

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
        { extern void isim_ui_accessibility_install(void); isim_ui_accessibility_install(); }
        extern void (*isim_main_wakeup_hook)(void);
        isim_main_wakeup_hook = isim_post_wakeup;
        NSLog(@"isim: launching %@ (%@) on %s", title, bundle.bundleIdentifier ?: @"no bundle id", isim_ui_device()->name);

        id<UIApplicationDelegate> d = app.delegate;
        NSDictionary *launchOptions = isim_sys_launch_options();
        BOOL background = isim_sys_background_launch();
        if (background) { backgrounded = YES; app.applicationState = UIApplicationStateBackground; NSLog(@"isim: launched in the background"); }
        if (!background) isim_ib_show_launch_screen();  /* UILaunchScreen / UILaunchStoryboardName while launching */
        /* UIMainStoryboardFile (apps without a scene manifest): window + initial view controller before launch callbacks */
        UIWindow *storyboardWindow = nil;
        if (info[@"UIMainStoryboardFile"] && !info[@"UIApplicationSceneManifest"])
            storyboardWindow = isim_ib_storyboard_window([UIStoryboard storyboardWithName:info[@"UIMainStoryboardFile"] bundle:bundle], nil, d);
        if ([d respondsToSelector:@selector(application:willFinishLaunchingWithOptions:)]) [d application:app willFinishLaunchingWithOptions:launchOptions];
        if ([d respondsToSelector:@selector(application:didFinishLaunchingWithOptions:)]) isim_sys_did_finish_launching([d application:app didFinishLaunchingWithOptions:launchOptions]);
        else if ([d respondsToSelector:@selector(applicationDidFinishLaunching:)]) [d applicationDidFinishLaunching:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidFinishLaunchingNotification object:app];

        NSDictionary *manifest = info[@"UIApplicationSceneManifest"];
        /* scene-based apps: a scene manifest, or a delegate that configures scenes (SwiftUI apps) */
        BOOL scenes = manifest || [app.delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)];
        if (scenes && background) pending_scene_manifest = manifest ?: @{};
        else if (scenes) isim_ui_scenes_launch(manifest ?: @{});
        else if ([d respondsToSelector:@selector(window)] && d.window && d.window.hidden) [d.window makeKeyAndVisible];
        else if (storyboardWindow.hidden) [storyboardWindow makeKeyAndVisible];
        if (!background) { isim_ib_hide_launch_screen(); app.applicationState = UIApplicationStateActive; }
        [NSNotificationCenter.defaultCenter addObserverForName:@"_IsimGlobalPreferencesChanged" object:nil queue:nil usingBlock:^(NSNotification *n) {
            settings_changed();
            isim_shell_request(ISIM_SHELL_SETTINGS, NULL, NULL, NULL);      /* other apps re-read the settings too */
        }];
        if (getenv("ISIM_XCTEST_BUNDLE")) {      /* isim test: hosted unit tests run in the app once it has launched */
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                NSString *path = @(getenv("ISIM_XCTEST_BUNDLE"));
                NSBundle *tb = [NSBundle bundleWithPath:path];
                NSString *exe = [path stringByAppendingPathComponent:tb.infoDictionary[@"CFBundleExecutable"] ?: path.lastPathComponent.stringByDeletingPathExtension];
                if (!dlopen(exe.UTF8String, RTLD_NOW)) { fprintf(stderr, "isim: cannot load test bundle %s: %s\n", exe.UTF8String, dlerror()); exit(70); }
                int (*runTests)(const char *) = (int (*)(const char *))dlsym(RTLD_DEFAULT, "XCTIsimRunTestBundle");
                int rc = runTests ? runTests(path.UTF8String) : 70;
                fflush(NULL);
                _exit(rc);
            });
        }
        if (background) isim_sys_after_background_launch();
        else if (!isim_sys_deliver_launch() && getenv("ISIM_LAUNCH_URL")) { NSString *u = @(getenv("ISIM_LAUNCH_URL")); dispatch_async(dispatch_get_main_queue(), ^{ deliver_url(u); }); }
        if (!background) {
            if ([d respondsToSelector:@selector(applicationDidBecomeActive:)]) [d applicationDidBecomeActive:app];
            [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationDidBecomeActiveNotification object:app];
        }
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
            if ((isim_ui_animations_running() || isim_ui_display_links_active() || isim_ui_update_links_active()) && !backgrounded) { isim_ui_set_needs_display(); if (timeout > 1.0 / 60) timeout = 1.0 / 60; }
            { extern double isim_main_next_due(void); double due = isim_main_next_due(); if (due < timeout) timeout = due; }   /* blocks queued while rendering run right away */
            struct isim_event ev;
            for (int got = isim_next_event(&ev, timeout); got; got = isim_next_event(&ev, 0)) {
                switch (ev.type) {
                case ISIM_EV_QUIT: quit = YES; break;
                case ISIM_EV_TOUCH_DOWN: case ISIM_EV_TOUCH_MOVE: case ISIM_EV_TOUCH_UP: handle_touch(&ev); break;
                case ISIM_EV_REDRAW: isim_ui_set_needs_display(); break;
                case ISIM_EV_TEXT: case ISIM_EV_KEY: handle_key(&ev); break;
                case ISIM_EV_KEY_UP: post_hardware_key(&ev, NO); isim_ui_hardware_key(ev.pad, ev.key, ev.mods, NO); break;
                case ISIM_EV_ID_DOWN: case ISIM_EV_ID_UP: case ISIM_EV_TEXT_DOWN: case ISIM_EV_TEXT_UP: handle_id_touch(&ev); break;
                case ISIM_EV_BACKGROUND: enter_background(); break;
                case ISIM_EV_FOREGROUND: enter_foreground(); break;
                case ISIM_EV_SETTINGS: settings_changed(); break;
                case ISIM_EV_LAUNCH_ID: [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimShellLaunch" object:@(ev.text)]; break;
                case ISIM_EV_OPEN_URL: deliver_url(@(ev.text)); break;
                case ISIM_EV_DEVICE_ORIENTATION: isim_ui_device_orientation_changed(ev.key); break;
                case ISIM_EV_SYSTEM: isim_sys_event(ev.text); break;
                case ISIM_EV_NOTIFICATION_RESPONSE: [NSNotificationCenter.defaultCenter postNotificationName:@"_IsimNotificationResponse" object:@(ev.text)]; break;
                case ISIM_EV_HOVER: isim_ui_hover(ev.x, ev.y, ev.pad == 1); break;
                case ISIM_EV_TEXT_EDITING: isim_ui_text_editing(@(ev.text), ev.key, ev.mods); break;
                case ISIM_EV_VOICEOVER: isim_ui_voiceover_command(@(ev.text)); break;
                case ISIM_EV_DUMP: layout_all();
                    if (ev.text[0]) { extern void isim_ui_write_ax_snapshot(const char *); isim_ui_write_ax_snapshot(ev.text); break; }   /* XCUITest */
                    for (UIWindow *w in UIApplication.sharedApplication.windows) dump_view(w, 0); break;
                default: break;
                }
                if (quit) break;
            }
        }
    }
    @autoreleasepool {
        UIApplication *app = UIApplication.sharedApplication;
        id<UIApplicationDelegate> d = app.delegate;
        for (UIScene *s in app.connectedScenes) {
            if ([s.delegate respondsToSelector:@selector(sceneDidDisconnect:)]) [s.delegate sceneDidDisconnect:s];
            [NSNotificationCenter.defaultCenter postNotificationName:UISceneDidDisconnectNotification object:s];
        }
        if ([d respondsToSelector:@selector(applicationWillTerminate:)]) [d applicationWillTerminate:app];
        [NSNotificationCenter.defaultCenter postNotificationName:UIApplicationWillTerminateNotification object:app];
        NSLog(@"isim: application terminated");
    }
    exit(0);
}
