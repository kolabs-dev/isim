/* Rotation. The device is turned on the host (Ctrl+Left/Right, script `rotate`); the app's interface follows when
 * the orientation is allowed by its Info.plist (or app delegate) and by the top view controller. The screen then
 * takes the new shape: view controllers get viewWillTransition(to:with:) / willTransition(to:with:) with a
 * coordinator, windows are resized and laid out inside one animation, and trait collections change size classes.
 * Without UISupportedInterfaceOrientations in Info.plist an app stays portrait (isim's default). */
#import "UIKitPrivate.h"
#include <math.h>

NSNotificationName const UIDeviceOrientationDidChangeNotification = @"UIDeviceOrientationDidChangeNotification";

static UIDeviceOrientation device_orientation;            /* 0 = not read yet */
static UIInterfaceOrientation interface_orientation = UIInterfaceOrientationPortrait;
static NSInteger generating;

static UIDeviceOrientation current_device_orientation(void) {
    if (!device_orientation) { int o = isim_device_orientation(); device_orientation = o >= 1 && o <= 6 ? (UIDeviceOrientation)o : UIDeviceOrientationPortrait; }
    return device_orientation;
}

@implementation UIDevice (UIDeviceOrientationNotifications)
- (UIDeviceOrientation)orientation { return current_device_orientation(); }
- (BOOL)isGeneratingDeviceOrientationNotifications { return generating > 0; }
- (void)beginGeneratingDeviceOrientationNotifications { generating++; }
- (void)endGeneratingDeviceOrientationNotifications { if (generating > 0) generating--; }
@end

/* ---- which orientations are allowed ---- */
static BOOL is_pad(void) { const struct isim_device *d = isim_ui_device(); return MIN(d->width, d->height) >= 700; }
static UIInterfaceOrientationMask mask_from_strings(NSArray *a) {
    UIInterfaceOrientationMask m = 0;
    for (NSString *s in a) {
        if (![s isKindOfClass:[NSString class]]) continue;
        if ([s isEqualToString:@"UIInterfaceOrientationPortrait"]) m |= UIInterfaceOrientationMaskPortrait;
        else if ([s isEqualToString:@"UIInterfaceOrientationPortraitUpsideDown"]) m |= UIInterfaceOrientationMaskPortraitUpsideDown;
        else if ([s isEqualToString:@"UIInterfaceOrientationLandscapeLeft"]) m |= UIInterfaceOrientationMaskLandscapeLeft;
        else if ([s isEqualToString:@"UIInterfaceOrientationLandscapeRight"]) m |= UIInterfaceOrientationMaskLandscapeRight;
    }
    return m;
}
static UIInterfaceOrientationMask plist_mask(void) {
    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    id a = info[is_pad() ? @"UISupportedInterfaceOrientations~ipad" : @"UISupportedInterfaceOrientations~iphone"] ?: info[@"UISupportedInterfaceOrientations"];
    if ([a isKindOfClass:[NSString class]]) a = [a componentsSeparatedByString:@" "];      /* INFOPLIST_KEY_ build setting form */
    UIInterfaceOrientationMask m = [a isKindOfClass:[NSArray class]] ? mask_from_strings(a) : 0;
    return m ?: UIInterfaceOrientationMaskPortrait;
}
static UIViewController *top_controller(void) {
    UIWindow *w = UIApplication.sharedApplication.keyWindow ?: UIApplication.sharedApplication.windows.firstObject;
    UIViewController *vc = w.rootViewController;
    while (vc.presentedViewController) vc = vc.presentedViewController;
    return vc;
}
@implementation UIApplication (UIRotation)
- (UIInterfaceOrientation)statusBarOrientation { return interface_orientation; }
- (UIInterfaceOrientationMask)supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    id<UIApplicationDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(application:supportedInterfaceOrientationsForWindow:)]) return [d application:self supportedInterfaceOrientationsForWindow:window];
    /* iOS 26: the window scene's delegate replaces the Info.plist value for its scene */
    id<UIWindowSceneDelegate> sd = (id)(window ?: self.keyWindow).windowScene.delegate;
    if ([sd respondsToSelector:@selector(supportedInterfaceOrientationsForWindowScene:)]) return [sd supportedInterfaceOrientationsForWindowScene:(window ?: self.keyWindow).windowScene];
    return plist_mask();
}
@end
static UIInterfaceOrientationMask allowed_mask(void) {
    UIInterfaceOrientationMask app = [UIApplication.sharedApplication supportedInterfaceOrientationsForWindow:UIApplication.sharedApplication.keyWindow];
    UIViewController *vc = top_controller();
    UIInterfaceOrientationMask both = vc ? app & vc.supportedInterfaceOrientations : app;
    if (!both) {
        NSLog(@"isim: Supported orientations has no common orientation with the application, and [%@ shouldAutorotate] is returning YES", vc ? NSStringFromClass([vc class]) : @"-");
        return app ?: UIInterfaceOrientationMaskPortrait;
    }
    return both;
}
static UIInterfaceOrientation choose(UIDeviceOrientation dev, UIInterfaceOrientationMask allowed) {
    if (UIDeviceOrientationIsValidInterfaceOrientation(dev) && (allowed & (1u << dev))) return (UIInterfaceOrientation)dev;
    if (allowed & (1u << interface_orientation)) return interface_orientation;
    const UIInterfaceOrientation order[] = { UIInterfaceOrientationPortrait, UIInterfaceOrientationLandscapeRight, UIInterfaceOrientationLandscapeLeft, UIInterfaceOrientationPortraitUpsideDown };
    for (int i = 0; i < 4; i++) if (allowed & (1u << order[i])) return order[i];
    return UIInterfaceOrientationPortrait;
}

/* ---- the transition coordinator ---- */
@interface __IsimRotationCoordinator : NSObject <UIViewControllerTransitionCoordinator>
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic, strong) NSMutableArray *alongside, *completions;
@property (nonatomic, weak) UIView *container;
@end
@implementation __IsimRotationCoordinator
- (instancetype)init { if ((self = [super init])) { _alongside = [NSMutableArray array]; _completions = [NSMutableArray array]; _transform = CGAffineTransformIdentity; } return self; }
- (BOOL)isAnimated { return _duration > 0; }
- (UIModalPresentationStyle)presentationStyle { return UIModalPresentationNone; }
- (BOOL)initiallyInteractive { return NO; }
- (BOOL)isInterruptible { return NO; }
- (BOOL)isInteractive { return NO; }
- (BOOL)isCancelled { return NO; }
- (NSTimeInterval)transitionDuration { return _duration; }
- (CGFloat)percentComplete { return 0; }
- (CGFloat)completionVelocity { return 1; }
- (UIView *)containerView { return _container ?: UIApplication.sharedApplication.keyWindow; }
- (CGAffineTransform)targetTransform { return _transform; }
- (UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key { return nil; }
- (UIView *)viewForKey:(UITransitionContextViewKey)key { return nil; }
- (BOOL)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))a completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))c {
    if (a) [_alongside addObject:[a copy]];
    if (c) [_completions addObject:[c copy]];
    return YES;
}
- (BOOL)animateAlongsideTransitionInView:(UIView *)v animation:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))a completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))c {
    return [self animateAlongsideTransition:a completion:c];
}
@end

/* a coordinator for an immediate size change (split view resizes, UIApplication.m) */
id isim_ui_immediate_coordinator(void) { __IsimRotationCoordinator *c = [__IsimRotationCoordinator new]; c.duration = 0; return c; }
void isim_ui_coordinator_finish(id coordinator) {
    __IsimRotationCoordinator *c = coordinator;
    for (void (^a)(id) in c.alongside) a(c);
    for (void (^done)(id) in c.completions) done(c);
}

/* ---- view controllers: defaults and forwarding to children ---- */
@implementation UIViewController (UIRotation)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations { return is_pad() ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskAllButUpsideDown; }
- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation { return interface_orientation; }
- (BOOL)shouldAutorotate { return YES; }
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    for (UIViewController *c in self.childViewControllers) [c viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    UIViewController *p = self.presentedViewController;
    if (p && p.presentingViewController == self) [p viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
}
- (void)willTransitionToTraitCollection:(UITraitCollection *)t withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    for (UIViewController *c in self.childViewControllers) [c willTransitionToTraitCollection:t withTransitionCoordinator:coordinator];
    UIViewController *p = self.presentedViewController;
    if (p && p.presentingViewController == self) [p willTransitionToTraitCollection:t withTransitionCoordinator:coordinator];
}
- (void)setNeedsUpdateOfSupportedInterfaceOrientations { dispatch_async(dispatch_get_main_queue(), ^{ isim_ui_device_orientation_changed(0); }); }
+ (void)attemptRotationToDeviceOrientation { isim_ui_device_orientation_changed(0); }
@end

/* containers answer for their visible child (isim: also without the navigation delegate's
   navigationControllerSupportedInterfaceOrientations) */
@implementation UINavigationController (UIRotation)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    id d = self.delegate;
    if ([d respondsToSelector:@selector(navigationControllerSupportedInterfaceOrientations:)]) return [d navigationControllerSupportedInterfaceOrientations:self];
    UIViewController *top = self.topViewController;
    return top ? top.supportedInterfaceOrientations : [super supportedInterfaceOrientations];
}
- (BOOL)shouldAutorotate { UIViewController *top = self.topViewController; return top ? top.shouldAutorotate : YES; }
@end
@implementation UITabBarController (UIRotation)
- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    UIViewController *s = self.selectedViewController;
    return s ? s.supportedInterfaceOrientations : [super supportedInterfaceOrientations];
}
@end

/* turn the interface to o (animated like iOS's rotation: about 0.35 s) */
static void rotate_interface(UIInterfaceOrientation o, BOOL animated) {
    if (o == interface_orientation) return;
    const struct isim_device *d = isim_ui_device();
    CGSize oldSize = CGSizeMake(d->width, d->height);
    BOOL toLandscape = UIInterfaceOrientationIsLandscape(o), wasLandscape = oldSize.width > oldSize.height;
    CGSize newSize = toLandscape == wasLandscape ? oldSize : CGSizeMake(oldSize.height, oldSize.width);
    isim_ui_traits_flush();
    UITraitCollection *oldTraits = isim_ui_screen_traits();
    __IsimRotationCoordinator *coord = [__IsimRotationCoordinator new];
    coord.duration = animated ? 0.35 : 0;
    CGFloat angle = (CGFloat)((toLandscape != wasLandscape) ? M_PI_2 : M_PI);
    coord.transform = CGAffineTransformMakeRotation(o == UIInterfaceOrientationLandscapeRight || interface_orientation == UIInterfaceOrientationLandscapeLeft ? -angle : angle);
    NSArray<UIWindow *> *windows = [UIApplication.sharedApplication.windows copy];
    /* the coming traits, told before the change */
    isim_set_orientation((int)o); isim_ui_device_refresh(); isim_ui_traits_invalidate(nil);
    UITraitCollection *newTraits = isim_ui_screen_traits();
    isim_set_orientation((int)interface_orientation); isim_ui_device_refresh(); isim_ui_traits_invalidate(nil);
    BOOL traitsChange = oldTraits.horizontalSizeClass != newTraits.horizontalSizeClass || oldTraits.verticalSizeClass != newTraits.verticalSizeClass;
    for (UIWindow *w in windows) {
        UIViewController *root = w.rootViewController;
        if (!root) continue;
        if (traitsChange) [root willTransitionToTraitCollection:newTraits withTransitionCoordinator:coord];
        [root viewWillTransitionToSize:newSize withTransitionCoordinator:coord];
    }
    UIInterfaceOrientation oldOrientation = interface_orientation;
    interface_orientation = o;
    isim_set_orientation((int)o);
    isim_ui_device_refresh();
    isim_ui_traits_invalidate(nil);
    extern void isim_ui_scenes_rotated(UIInterfaceOrientation oldOrientation, CGSize oldScreen);
    void (^apply)(void) = ^{
        for (UIWindow *w in windows) {
            CGRect f = w.frame;
            if (CGSizeEqualToSize(f.size, oldSize) && CGPointEqualToPoint(f.origin, CGPointZero)) w.frame = CGRectMake(0, 0, newSize.width, newSize.height);
            [w setNeedsLayout];
            [w layoutIfNeeded];
        }
        isim_ui_scenes_rotated(oldOrientation, oldSize);   /* split views take the new screen; scene delegates hear of it */
        for (void (^a)(id) in coord.alongside) a(coord);
    };
    void (^finish)(BOOL) = ^(BOOL f) {
        for (void (^c)(id) in coord.completions) c(coord);
        isim_ui_set_needs_layout();
    };
    if (animated) [UIView animateWithDuration:coord.duration delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:apply completion:finish];
    else { [UIView performWithoutAnimation:apply]; finish(YES); }
    isim_ui_traits_flush();                           /* traitCollectionDidChange: with the previous traits */
    isim_ui_set_needs_layout();
    NSLog(@"isim: interface orientation %ld (%gx%g)", (long)o, newSize.width, newSize.height);
}

/* the device was turned (o > 0), or the allowed orientations may have changed (o == 0) */
void isim_ui_device_orientation_changed(int o) {
    if (o > 0 && (UIDeviceOrientation)o != current_device_orientation()) {
        device_orientation = (UIDeviceOrientation)o;
        [NSNotificationCenter.defaultCenter postNotificationName:UIDeviceOrientationDidChangeNotification object:UIDevice.currentDevice];
    }
    UIViewController *top = top_controller();
    if (top && !top.shouldAutorotate && o > 0) return;
    if (top && o > 0 && top.prefersInterfaceOrientationLocked && (allowed_mask() & (1u << interface_orientation))) return;   /* iOS 26 orientation lock */
    rotate_interface(choose(current_device_orientation(), allowed_mask()), YES);
}

/* ---- scenes ---- */
@implementation UIWindowSceneGeometryPreferences @end
@implementation UIWindowSceneGeometryPreferencesIOS
- (instancetype)initWithInterfaceOrientations:(UIInterfaceOrientationMask)m { if ((self = [super init])) _interfaceOrientations = m; return self; }
@end
@implementation UIWindowScene (UIRotation)
- (UIInterfaceOrientation)interfaceOrientation { return interface_orientation; }
- (void)requestGeometryUpdateWithPreferences:(UIWindowSceneGeometryPreferences *)p errorHandler:(void (^)(NSError *))errorHandler {
    if (![p isKindOfClass:[UIWindowSceneGeometryPreferencesIOS class]]) {          /* Mac (or other) preferences on iOS */
        if (errorHandler) errorHandler([NSError errorWithDomain:@"UISceneErrorDomain" code:100 userInfo:@{ NSLocalizedDescriptionKey: @"The geometry preferences are not supported on this platform." }]);
        return;
    }
    UIInterfaceOrientationMask want = ((UIWindowSceneGeometryPreferencesIOS *)p).interfaceOrientations;
    UIInterfaceOrientationMask allowed = want & allowed_mask();
    if (!allowed) {
        if (errorHandler) errorHandler([NSError errorWithDomain:@"UISceneErrorDomain" code:101
            userInfo:@{ NSLocalizedDescriptionKey: @"None of the requested orientations are supported by the view controller." }]);
        return;
    }
    /* like iOS 16+: the interface turns to a requested orientation even if the device is not turned */
    UIInterfaceOrientation o = (allowed & (1u << current_device_orientation())) ? (UIInterfaceOrientation)current_device_orientation() : choose(UIDeviceOrientationUnknown, allowed);
    if (!(allowed & (1u << interface_orientation)) || o != interface_orientation) rotate_interface(o, YES);
}
@end

/* an app launched while the device is turned starts in that orientation if it allows it */
@interface __IsimOrientationStartup : NSObject @end
@implementation __IsimOrientationStartup
+ (void)load {
    [NSNotificationCenter.defaultCenter addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:nil usingBlock:^(NSNotification *n) {
        static BOOL done; if (done) return; done = YES;
        if (current_device_orientation() != UIDeviceOrientationPortrait) isim_ui_device_orientation_changed(0);
    }];
}
@end
