/* The UI update cycle additions (ARC): UIUpdateLink (iOS 18) and automatic observation tracking (iOS 26; iOS 18 with
 * Info.plist UIObservationTrackingEnabled).
 *
 * UIUpdateLink: per-frame callbacks for a view (while it is in a visible window) or a window scene, run with the
 * display links before each frame is drawn; requiresContinuousUpdates keeps frames coming, otherwise a link runs on
 * the frames that are drawn anyway (adapted: the phases run in Apple's order around the display links and the frame's
 * drawing; the low-latency phases never run).
 *
 * Observation tracking: UIKit runs layoutSubviews, updateProperties, viewWillLayoutSubviews / viewDidLayoutSubviews
 * and view controllers' updateProperties inside Observation's withObservationTracking when the class overrides them
 * (the UIKit overlay exports the tracking function, isim_uikit_observation_track; Objective-C-only apps have no
 * @Observable objects). A change to an @Observable property read there invalidates the view: setNeedsLayout /
 * setNeedsUpdateProperties, like iOS 26. */
#import "UIKitPrivate.h"
#include <dlfcn.h>
#include <objc/runtime.h>
#include <string.h>

/* ================= observation tracking ================= */
typedef void (*isim_obs_track_fn)(void (^body)(void), void (^onChange)(void));
static isim_obs_track_fn obs_track(void) {
    static isim_obs_track_fn f; static BOOL looked;
    if (!looked) { looked = YES; f = (isim_obs_track_fn)dlsym(RTLD_DEFAULT, "isim_uikit_observation_track"); }
    return f;
}
BOOL isim_ui_observation_tracking_enabled(void) {
    static int on = -1;
    if (on < 0) {
        int os = isim_ui_os_major();
        id key = NSBundle.mainBundle.infoDictionary[@"UIObservationTrackingEnabled"];
        on = (os >= 26 || (os >= 18 && [key respondsToSelector:@selector(boolValue)] && [key boolValue])) && obs_track() != NULL;
        if (on) NSLog(@"isim: automatic observation tracking on (iOS %d)", os);
    }
    return on;
}
/* only methods the app's classes override are tracked (UIKit's own code reads no @Observable state) */
static BOOL overridden_by_app(id obj, SEL sel) {
    static NSMapTable *cache;
    if (!cache) cache = [NSMapTable strongToStrongObjectsMapTable];
    Class c = object_getClass(obj);
    NSString *key = [NSString stringWithFormat:@"%p:%s", (__bridge void *)c, sel_getName(sel)];
    NSNumber *v = [cache objectForKey:key];
    if (!v) {
        IMP imp = class_getMethodImplementation(c, sel);
        Dl_info info; BOOL app = YES;
        if (imp && dladdr((void *)imp, &info) && info.dli_fname && strstr(info.dli_fname, "UIKit.framework")) app = NO;
        v = @(app); [cache setObject:v forKey:key];
    }
    return v.boolValue;
}
/* runs body, tracked when enabled; onChange runs on the main queue after a tracked property changed */
void isim_ui_tracked(id owner, SEL sel, void (^body)(void), void (^onChange)(void)) {
    if (!isim_ui_observation_tracking_enabled() || !overridden_by_app(owner, sel)) { body(); return; }
    obs_track()(body, ^{ dispatch_async(dispatch_get_main_queue(), onChange); });
}

/* ================= updateProperties (iOS 26) ================= */
static char k_needs_props;
static BOOL needs_props(id o) { NSNumber *n = objc_getAssociatedObject(o, &k_needs_props); return n ? n.boolValue : YES; }   /* first time: yes */
static void set_needs_props(id o, BOOL v) { objc_setAssociatedObject(o, &k_needs_props, @(v), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
@implementation UIView (UIUpdateProperties)
- (void)updateProperties {}
- (void)setNeedsUpdateProperties { set_needs_props(self, YES); [self setNeedsLayout]; isim_ui_set_needs_layout(); }
- (void)updatePropertiesIfNeeded {
    if (isim_ui_os_major() < 26 || !needs_props(self)) return;
    set_needs_props(self, NO);
    __weak UIView *w = self;
    isim_ui_tracked(self, @selector(updateProperties), ^{ [w updateProperties]; }, ^{ [w setNeedsUpdateProperties]; });
}
@end
@implementation UIViewController (UIUpdateProperties)
- (void)updateProperties {}
- (void)setNeedsUpdateProperties { set_needs_props(self, YES); [self.viewIfLoaded setNeedsLayout]; isim_ui_set_needs_layout(); }
- (void)updatePropertiesIfNeeded {
    if (isim_ui_os_major() < 26 || !needs_props(self)) return;
    set_needs_props(self, NO);
    __weak UIViewController *w = self;
    isim_ui_tracked(self, @selector(updateProperties), ^{ [w updateProperties]; }, ^{ [w setNeedsUpdateProperties]; });
}
@end

/* ================= UIUpdateLink (iOS 18) ================= */
/* Apple's phases in update order; the low-latency ones run only when low-latency event dispatch is confirmed, which
   isim never does (adapted). eventDispatch is isim's old name for beforeEventDispatch (kept for apps built with it). */
@implementation UIUpdateActionPhase { NSInteger _order; NSString *_name; }
static UIUpdateActionPhase *phase(NSInteger order, NSString *name) {
    static NSMutableDictionary *phases;
    if (!phases) phases = [NSMutableDictionary dictionary];
    UIUpdateActionPhase *p = phases[@(order)];
    if (!p) { p = [UIUpdateActionPhase new]; p->_order = order; p->_name = name; phases[@(order)] = p; }
    return p;
}
enum { PH_SCHEDULED, PH_BEFORE_EVENTS, PH_AFTER_EVENTS, PH_BEFORE_LL_EVENTS, PH_AFTER_LL_EVENTS, PH_BEFORE_LINKS, PH_AFTER_LINKS,
       PH_BEFORE_LL_COMMIT, PH_AFTER_LL_COMMIT, PH_BEFORE_COMMIT, PH_AFTER_COMMIT, PH_COMPLETE };
+ (UIUpdateActionPhase *)afterUpdateScheduled { return phase(PH_SCHEDULED, @"afterUpdateScheduled"); }
+ (UIUpdateActionPhase *)beforeEventDispatch { return phase(PH_BEFORE_EVENTS, @"beforeEventDispatch"); }
+ (UIUpdateActionPhase *)eventDispatch { return self.beforeEventDispatch; }
+ (UIUpdateActionPhase *)afterEventDispatch { return phase(PH_AFTER_EVENTS, @"afterEventDispatch"); }
+ (UIUpdateActionPhase *)beforeLowLatencyEventDispatch { return phase(PH_BEFORE_LL_EVENTS, @"beforeLowLatencyEventDispatch"); }
+ (UIUpdateActionPhase *)afterLowLatencyEventDispatch { return phase(PH_AFTER_LL_EVENTS, @"afterLowLatencyEventDispatch"); }
+ (UIUpdateActionPhase *)beforeCADisplayLinkDispatch { return phase(PH_BEFORE_LINKS, @"beforeCADisplayLinkDispatch"); }
+ (UIUpdateActionPhase *)afterCADisplayLinkDispatch { return phase(PH_AFTER_LINKS, @"afterCADisplayLinkDispatch"); }
+ (UIUpdateActionPhase *)beforeLowLatencyCATransactionCommit { return phase(PH_BEFORE_LL_COMMIT, @"beforeLowLatencyCATransactionCommit"); }
+ (UIUpdateActionPhase *)afterLowLatencyCATransactionCommit { return phase(PH_AFTER_LL_COMMIT, @"afterLowLatencyCATransactionCommit"); }
+ (UIUpdateActionPhase *)beforeCATransactionCommit { return phase(PH_BEFORE_COMMIT, @"beforeCATransactionCommit"); }
+ (UIUpdateActionPhase *)afterCATransactionCommit { return phase(PH_AFTER_COMMIT, @"afterCATransactionCommit"); }
+ (UIUpdateActionPhase *)afterUpdateComplete { return phase(PH_COMPLETE, @"afterUpdateComplete"); }
- (NSInteger)_isim_order { return _order; }
- (NSString *)description { return [NSString stringWithFormat:@"<UIUpdateActionPhase %@>", _name]; }
@end

@interface UIUpdateInfo ()
@property (nonatomic, readwrite) CFTimeInterval modelTime, completionDeadlineTime;
@end
static UIUpdateInfo *frame_info;      /* the UI update in progress (render_frame), else nil */
@implementation UIUpdateInfo
+ (instancetype)currentUpdateInfoForWindowScene:(UIWindowScene *)scene {
    return frame_info && scene.activationState != UISceneActivationStateBackground ? (id)frame_info : nil;
}
+ (instancetype)currentUpdateInfoForView:(UIView *)view { return frame_info && view.window ? (id)frame_info : nil; }
- (CFTimeInterval)estimatedPresentationTime { return self.completionDeadlineTime; }
- (BOOL)isImmediatePresentationExpected { return NO; }
- (BOOL)isLowLatencyEventDispatchConfirmed { return NO; }
- (BOOL)isPerformingLowLatencyPhases { return NO; }
@end
@interface __IsimUpdateAction : NSObject
@property (nonatomic, strong) UIUpdateActionPhase *phase;
@property (nonatomic, copy) void (^handler)(UIUpdateLink *, UIUpdateInfo *);
@property (nonatomic, weak) id target;
@property (nonatomic) SEL selector;
@end
@implementation __IsimUpdateAction @end
static NSHashTable<UIUpdateLink *> *update_links;
@interface UIUpdateLink ()
@property (nonatomic, readwrite, strong) UIUpdateInfo *currentUpdateInfo;
@end
@implementation UIUpdateLink { __weak UIView *_view; __weak UIWindowScene *_scene; BOOL _forScene; NSMutableArray<__IsimUpdateAction *> *_actions; }
+ (instancetype)updateLinkForWindowScene:(UIWindowScene *)scene { UIUpdateLink *l = [self new]; l->_scene = scene; l->_forScene = YES; return l; }
+ (instancetype)updateLinkForView:(UIView *)view { UIUpdateLink *l = [self new]; l->_view = view; return l; }
+ (instancetype)updateLinkForWindowScene:(UIWindowScene *)scene actionTarget:(id)target selector:(SEL)sel { UIUpdateLink *l = [self updateLinkForWindowScene:scene]; [l addActionWithTarget:target selector:sel]; return l; }
+ (instancetype)updateLinkForView:(UIView *)view actionTarget:(id)target selector:(SEL)sel { UIUpdateLink *l = [self updateLinkForView:view]; [l addActionWithTarget:target selector:sel]; return l; }
- (instancetype)init {
    if ((self = [super init])) {
        _actions = [NSMutableArray array]; _preferredFrameRateRange = (CAFrameRateRange){ 0, 0, 0 };
        if (!update_links) update_links = [NSHashTable weakObjectsHashTable];
        [update_links addObject:self];
    }
    return self;
}
- (void)_add:(UIUpdateActionPhase *)p handler:(void (^)(UIUpdateLink *, UIUpdateInfo *))h target:(id)t selector:(SEL)s {
    __IsimUpdateAction *a = [__IsimUpdateAction new]; a.phase = p ?: UIUpdateActionPhase.beforeCADisplayLinkDispatch; a.handler = h; a.target = t; a.selector = s;
    [_actions addObject:a];
    [_actions sortUsingComparator:^NSComparisonResult(__IsimUpdateAction *x, __IsimUpdateAction *y) { return [@([x.phase _isim_order]) compare:@([y.phase _isim_order])]; }];
}
- (void)addActionToPhase:(UIUpdateActionPhase *)p handler:(void (^)(UIUpdateLink *, UIUpdateInfo *))h { [self _add:p handler:h target:nil selector:NULL]; }
- (void)addActionToPhase:(UIUpdateActionPhase *)p target:(id)t selector:(SEL)s { [self _add:p handler:nil target:t selector:s]; }
- (void)addActionWithHandler:(void (^)(UIUpdateLink *, UIUpdateInfo *))h { [self _add:nil handler:h target:nil selector:NULL]; }
- (void)addActionWithTarget:(id)t selector:(SEL)s { [self _add:nil handler:nil target:t selector:s]; }
- (void)setEnabled:(BOOL)e { _enabled = e; if (e) isim_ui_set_needs_display(); }
- (void)setRequiresContinuousUpdates:(BOOL)r { _requiresContinuousUpdates = r; if (r && _enabled) isim_ui_set_needs_display(); }
/* a view's link runs while the view is in a visible window; a scene's while the scene is on screen */
- (BOOL)_isim_live {
    if (!_enabled) return NO;
    if (_forScene) { UIWindowScene *s = _scene; return s && s.activationState != UISceneActivationStateBackground; }
    UIView *v = _view; if (!v.window || v.window.hidden) return NO;
    for (UIView *x = v; x; x = x.superview) if (x.hidden || x.alpha <= 0.01) return NO;
    return YES;
}
- (void)_isim_fire:(UIUpdateInfo *)info from:(NSInteger)first to:(NSInteger)last {
    self.currentUpdateInfo = info;
    for (__IsimUpdateAction *a in [_actions copy]) {
        NSInteger o = [a.phase _isim_order];
        if (o < first || o > last) continue;
        if (o == PH_BEFORE_LL_EVENTS || o == PH_AFTER_LL_EVENTS || o == PH_BEFORE_LL_COMMIT || o == PH_AFTER_LL_COMMIT) continue;
        if (a.handler) a.handler(self, info);
        else if (a.target && a.selector) {
            id t = a.target; NSUInteger n = [NSStringFromSelector(a.selector) componentsSeparatedByString:@":"].count - 1;
            if (n == 0) ((void (*)(id, SEL))[t methodForSelector:a.selector])(t, a.selector);
            else if (n == 1) ((void (*)(id, SEL, id))[t methodForSelector:a.selector])(t, a.selector, self);
            else ((void (*)(id, SEL, id, id))[t methodForSelector:a.selector])(t, a.selector, self, info);
        }
    }
    self.currentUpdateInfo = nil;
}
@end
/* a frame (UIApplication.m render_frame) runs the phases in three stages: before the display links (stage 0: update
   scheduled, event dispatch, before display links), after them (stage 1: after display links, before the commit) and
   after the frame is drawn (stage 2: after the commit, update complete). UIUpdateInfo.current(for:) is the frame's
   info from stage 0 to stage 2. */
static void fire_stage(int stage) {
    static const NSInteger first[] = { PH_SCHEDULED, PH_AFTER_LINKS, PH_AFTER_COMMIT }, last[] = { PH_BEFORE_LINKS, PH_BEFORE_COMMIT, PH_COMPLETE };
    if (stage == 0) {
        CFTimeInterval now = isim_time();
        frame_info = [UIUpdateInfo new]; frame_info.modelTime = now; frame_info.completionDeadlineTime = now + 1.0 / 60;
    }
    if (update_links.count) for (UIUpdateLink *l in update_links.allObjects) if ([l _isim_live]) [l _isim_fire:frame_info from:first[stage] to:last[stage]];
    if (stage == 2) frame_info = nil;
}
void isim_ui_update_links_fire(void) { fire_stage(0); }
void isim_ui_update_links_stage(int stage) { fire_stage(stage); }
BOOL isim_ui_update_links_active(void) {
    for (UIUpdateLink *l in update_links.allObjects) if (l.requiresContinuousUpdates && [l _isim_live]) return YES;
    return NO;
}

/* ================= preferred transitions (iOS 18) ================= */
@interface UIZoomTransitionSourceViewProviderContext ()
@property (nonatomic, readwrite, strong) UIViewController *sourceViewController, *zoomedViewController;
@end
@implementation UIZoomTransitionSourceViewProviderContext @end
@implementation UIZoomTransitionOptions
- (id)copyWithZone:(NSZone *)z { UIZoomTransitionOptions *o = [UIZoomTransitionOptions new]; o.dimmingColor = _dimmingColor; o.dimmingVisualEffect = _dimmingVisualEffect; return o; }
@end
@implementation UIViewControllerTransition { int _kind; UIView *(^_provider)(UIZoomTransitionSourceViewProviderContext *); UIZoomTransitionOptions *_options; }
+ (instancetype)_kind:(int)k { UIViewControllerTransition *t = [self new]; t->_kind = k; return t; }
+ (instancetype)zoomWithOptions:(UIZoomTransitionOptions *)o sourceViewProvider:(UIView *(^)(UIZoomTransitionSourceViewProviderContext *))p {
    UIViewControllerTransition *t = [self _kind:1]; t->_options = [o copy]; t->_provider = [p copy]; return t;
}
+ (UIViewControllerTransition *)coverVerticalTransition { return [self _kind:2]; }
+ (UIViewControllerTransition *)flipHorizontalTransition { return [self _kind:3]; }
+ (UIViewControllerTransition *)crossDissolveTransition { return [self _kind:4]; }
+ (UIViewControllerTransition *)partialCurlTransition { return [self _kind:5]; }
- (BOOL)_isim_isZoom { return _kind == 1; }
- (UIModalTransitionStyle)_isim_modalStyle { return _kind == 3 ? UIModalTransitionStyleFlipHorizontal : _kind == 4 ? UIModalTransitionStyleCrossDissolve : _kind == 5 ? UIModalTransitionStylePartialCurl : UIModalTransitionStyleCoverVertical; }
- (UIView *)_isim_sourceViewFrom:(UIViewController *)source zoomed:(UIViewController *)zoomed {
    if (!_provider) return nil;
    UIZoomTransitionSourceViewProviderContext *c = [UIZoomTransitionSourceViewProviderContext new];
    c.sourceViewController = source; c.zoomedViewController = zoomed;
    return _provider(c);
}
@end
static char k_pref_transition;
@implementation UIViewController (UIPreferredTransition)
- (UIViewControllerTransition *)preferredTransition { return objc_getAssociatedObject(self, &k_pref_transition); }
- (void)setPreferredTransition:(UIViewControllerTransition *)t {
    objc_setAssociatedObject(self, &k_pref_transition, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (t && ![t _isim_isZoom]) self.modalTransitionStyle = [t _isim_modalStyle];
}
@end
/* the zoom: view grows from (or shrinks to) the source view's frame; YES when it ran (UINavigation.m, UIApplication.m) */
BOOL isim_ui_zoom_transition(UIViewController *zoomed, UIViewController *source, UIView *zv, UIView *host, BOOL appearing, void (^done)(void)) {
    UIViewControllerTransition *t = zoomed.preferredTransition;
    if (isim_ui_os_major() < 18 || ![t _isim_isZoom]) return NO;
    UIView *src = [t _isim_sourceViewFrom:source zoomed:zoomed];
    if (!src.window || !host) return NO;
    CGRect sr = [src convertRect:src.bounds toView:host], full = zv.frame;
    if (full.size.width <= 0 || full.size.height <= 0) return NO;
    CGFloat sx = sr.size.width / full.size.width, sy = sr.size.height / full.size.height;
    CGAffineTransform small = CGAffineTransformMake(sx, 0, 0, sy, CGRectGetMidX(sr) - CGRectGetMidX(full), CGRectGetMidY(sr) - CGRectGetMidY(full));
    NSLog(@"isim: zoom transition %@ %@ (source %g,%g %gx%g)", appearing ? @"to" : @"from", NSStringFromClass([zoomed class]), sr.origin.x, sr.origin.y, sr.size.width, sr.size.height);
    CGFloat radius = zv.layer.cornerRadius; BOOL clips = zv.clipsToBounds;
    zv.clipsToBounds = YES;
    if (appearing) [UIView performWithoutAnimation:^{ zv.transform = small; zv.alpha = 0.6; zv.layer.cornerRadius = 24; }];
    [UIView animateWithDuration:0.45 delay:0 usingSpringWithDamping:0.9 initialSpringVelocity:0 options:0 animations:^{
        zv.transform = appearing ? CGAffineTransformIdentity : small; zv.alpha = appearing ? 1 : 0;
        zv.layer.cornerRadius = appearing ? radius : 24;
    } completion:^(BOOL f) {
        zv.transform = CGAffineTransformIdentity; zv.alpha = 1; zv.layer.cornerRadius = radius; zv.clipsToBounds = clips;
        if (done) done();
    }];
    return YES;
}
