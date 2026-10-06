/* Modal presentation: presentation controllers, sheets with detents, popovers, modal transition styles,
 * custom and interactive transitions, transition coordinators. (UIAlertController keeps its own path in
 * UIApplication.m; everything else presented with present(_:animated:) comes here.)
 *
 *  - Styles: .fullScreen / .currentContext (the presenter disappears underneath), .overFullScreen /
 *    .overCurrentContext (it stays visible; the "context" styles cover the nearest definesPresentationContext
 *    controller's view, else the root's), .pageSheet / .formSheet / .automatic (iPhone sheets, iPad centered
 *    cards), .popover (iPad, or iPhone when the adaptive delegate returns .none; otherwise a sheet), .custom
 *    (the transitioning delegate's UIPresentationController).
 *  - Transition styles: cover vertical (slide), cross dissolve (fade), flip horizontal (2D squash/unfold,
 *    adapted), partial curl (adapted: presented as cover vertical).
 *  - Custom transitions: UIViewControllerTransitioningDelegate animators get a transition context (container,
 *    from/to controllers and views, final frames, completeTransition); interaction controllers
 *    (UIPercentDrivenInteractiveTransition) scrub the animator's UIView animations through an engine timeline,
 *    or its interruptible animator.
 *  - Sheets (UISheetPresentationController): detents (.medium, .large, custom), grabber, dimming above
 *    largestUndimmedDetentIdentifier (taps pass through below it), the presenter shrinks into a card at the
 *    large detent, dragging moves between detents or dismisses (isModalInPresentation rubber-bands),
 *    prefersScrollingExpandsWhenScrolledToEdge, animateChanges, selectedDetentIdentifier. */
#import "UIKitPrivate.h"
#import <UIKit/UIPresentationController.h>
#import <UIKit/UISplitViewController.h>
#include <math.h>

UITransitionContextViewControllerKey const UITransitionContextFromViewControllerKey = @"UITransitionContextFromViewController";
UITransitionContextViewControllerKey const UITransitionContextToViewControllerKey = @"UITransitionContextToViewController";
UITransitionContextViewKey const UITransitionContextFromViewKey = @"UITransitionContextFromView";
UITransitionContextViewKey const UITransitionContextToViewKey = @"UITransitionContextToView";
const UISheetPresentationControllerDetentIdentifier UISheetPresentationControllerDetentIdentifierMedium = @"com.apple.UIKit.medium";
const UISheetPresentationControllerDetentIdentifier UISheetPresentationControllerDetentIdentifierLarge = @"com.apple.UIKit.large";
const CGFloat UISheetPresentationControllerAutomaticDimension = -1;
const CGFloat UISheetPresentationControllerDetentInactive = -2;

@class __IsimPresentation;
static char kPresentation, kPC, kTransitionStyle, kTransitioningDelegate, kDefinesContext, kProvidesContext, kPreferredSize, kCoordinator;
@interface __IsimWeakBox : NSObject
@property (nonatomic, weak) id value;
@end
@implementation __IsimWeakBox @end

static BOOL compact_width(UIView *v) { CGFloat w = v.window ? v.window.bounds.size.width : isim_ui_device()->width; return w < 700; }

/* ================= transition context & coordinator ================= */
@interface __IsimTransitionContext : NSObject <UIViewControllerContextTransitioning, UIViewControllerTransitionCoordinator>
@property (nonatomic, strong) UIView *containerView;
@property (nonatomic, getter=isAnimated) BOOL animated;
@property (nonatomic, getter=isInteractive) BOOL interactive;
@property (nonatomic, getter=isCancelled) BOOL cancelled;
@property (nonatomic) BOOL completed;
@property (nonatomic) UIModalPresentationStyle presentationStyle;
@property (nonatomic, strong) UIViewController *fromVC, *toVC;
@property (nonatomic, strong) UIView *fromView, *toView;
@property (nonatomic) CGRect toFinal, fromFinal, toInitial, fromInitial;
@property (nonatomic, strong) id<UIViewControllerAnimatedTransitioning> animator;
@property (nonatomic) NSTimeInterval duration;
@property (nonatomic, copy) void (^onComplete)(BOOL completed);
@property (nonatomic, strong) NSMutableArray *alongside, *alongsideCompletions;
@property (nonatomic) BOOL started;
- (void)_isim_runAlongside;
@end
@implementation __IsimTransitionContext
- (instancetype)init { if ((self = [super init])) { _alongside = [NSMutableArray array]; _alongsideCompletions = [NSMutableArray array]; } return self; }
- (BOOL)transitionWasCancelled { return _cancelled; }
- (NSTimeInterval)transitionDuration { return _duration; }
- (CGAffineTransform)targetTransform { return CGAffineTransformIdentity; }
- (void)updateInteractiveTransition:(CGFloat)p {}
- (void)finishInteractiveTransition { _cancelled = NO; }
- (void)cancelInteractiveTransition { _cancelled = YES; }
- (void)pauseInteractiveTransition {}
- (UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)k {
    return [k isEqualToString:UITransitionContextFromViewControllerKey] ? _fromVC : [k isEqualToString:UITransitionContextToViewControllerKey] ? _toVC : nil;
}
- (UIView *)viewForKey:(UITransitionContextViewKey)k {
    return [k isEqualToString:UITransitionContextFromViewKey] ? _fromView : [k isEqualToString:UITransitionContextToViewKey] ? _toView : nil;
}
- (CGRect)initialFrameForViewController:(UIViewController *)vc { return vc == _toVC ? _toInitial : vc == _fromVC ? _fromInitial : CGRectZero; }
- (CGRect)finalFrameForViewController:(UIViewController *)vc { return vc == _toVC ? _toFinal : vc == _fromVC ? _fromFinal : CGRectZero; }
- (void)completeTransition:(BOOL)did {
    if (_completed) return;
    _completed = YES;
    id<UIViewControllerAnimatedTransitioning> a = _animator;
    void (^c)(BOOL) = _onComplete; _onComplete = nil;
    if (c) c(did);
    if ([a respondsToSelector:@selector(animationEnded:)]) [a animationEnded:did];
    NSArray *cs = [_alongsideCompletions copy]; [_alongsideCompletions removeAllObjects];
    for (void (^b)(id) in cs) b(self);
}
- (BOOL)initiallyInteractive { return NO; }
- (BOOL)isInterruptible { return NO; }
- (CGFloat)percentComplete { return 0; }
- (CGFloat)completionVelocity { return 1; }
- (BOOL)animateAlongsideTransitionInView:(UIView *)v animation:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))a completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))c {
    return [self animateAlongsideTransition:a completion:c];
}
/* animations alongside: queued until the transition animation starts, then run in an animation of the same length */
- (BOOL)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))a completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))c {
    if (c) [_alongsideCompletions addObject:[c copy]];
    if (!a) return YES;
    if (_started) { __weak __IsimTransitionContext *ws = self; isim_ui_animate(_animated ? _duration : 0, 0, 0, 0, 0, 0, ^{ a(ws); }, nil); }
    else [_alongside addObject:[a copy]];
    return YES;
}
/* the transition animation starts now (inside a timeline capture for interactive transitions) */
- (void)_isim_runAlongside {
    _started = YES;
    NSArray *as = [_alongside copy]; [_alongside removeAllObjects];
    if (!as.count) return;
    __weak __IsimTransitionContext *ws = self;
    isim_ui_animate(_animated ? _duration : 0, 0, 0, 0, 0, 0, ^{ for (void (^a)(id) in as) a(ws); }, nil);
}
@end

/* ================= presentation controllers ================= */
@interface UIPresentationController ()
@property (nonatomic, readwrite, strong) UIView *containerView;
@property (nonatomic) UIModalPresentationStyle _isim_style;
- (void)_isim_setPresentingVC:(UIViewController *)p;
@end
@implementation UIPresentationController
- (instancetype)initWithPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting {
    if ((self = [super init])) { _presentedViewController = presented; _presentingViewController = presenting; self._isim_style = UIModalPresentationCustom; }
    return self;
}
- (UIModalPresentationStyle)presentationStyle { return self._isim_style; }
- (void)_isim_setPresentingVC:(UIViewController *)p { if (p) _presentingViewController = p; }
- (UIModalPresentationStyle)adaptivePresentationStyle { return [self adaptivePresentationStyleForTraitCollection:self.traitCollection]; }
- (UIModalPresentationStyle)adaptivePresentationStyleForTraitCollection:(UITraitCollection *)t { return self.presentationStyle; }
- (UIView *)presentedView { return _presentedViewController.view; }
- (CGRect)frameOfPresentedViewInContainerView { return _containerView ? _containerView.bounds : UIScreen.mainScreen.bounds; }
- (BOOL)shouldPresentInFullscreen { return YES; }
- (BOOL)shouldRemovePresentersView { return self._isim_style == UIModalPresentationFullScreen || self._isim_style == UIModalPresentationCurrentContext; }
- (void)containerViewWillLayoutSubviews {}
- (void)containerViewDidLayoutSubviews {}
- (void)presentationTransitionWillBegin {}
- (void)presentationTransitionDidEnd:(BOOL)c {}
- (void)dismissalTransitionWillBegin {}
- (void)dismissalTransitionDidEnd:(BOOL)c {}
- (CGSize)sizeForChildContentContainer:(id)c withParentContainerSize:(CGSize)s { return s; }
- (void)preferredContentSizeDidChangeForChildContentContainer:(id)c {}
- (UITraitCollection *)traitCollection { return _containerView ? _containerView.traitCollection : _presentingViewController.traitCollection; }
- (void)traitCollectionDidChange:(UITraitCollection *)p {}
@end

/* ---- sheets ---- */
@interface __IsimDetentContext : NSObject <UISheetPresentationControllerDetentResolutionContext>
@property (nonatomic, strong) UITraitCollection *containerTraitCollection;
@property (nonatomic) CGFloat maximumDetentValue;
@end
@implementation __IsimDetentContext @end

@implementation UISheetPresentationControllerDetent {
    CGFloat (^_resolver)(id<UISheetPresentationControllerDetentResolutionContext>);
    int _kind;                                      /* 0 medium, 1 large, 2 custom */
}
+ (instancetype)_isim_kind:(int)k ident:(NSString *)i { UISheetPresentationControllerDetent *d = [self new]; d->_kind = k; d->_identifier = [i copy]; return d; }
+ (instancetype)mediumDetent { return [self _isim_kind:0 ident:UISheetPresentationControllerDetentIdentifierMedium]; }
+ (instancetype)largeDetent { return [self _isim_kind:1 ident:UISheetPresentationControllerDetentIdentifierLarge]; }
+ (instancetype)customDetentWithIdentifier:(NSString *)i resolver:(CGFloat (^)(id<UISheetPresentationControllerDetentResolutionContext>))r {
    UISheetPresentationControllerDetent *d = [self _isim_kind:2 ident:i ?: [NSString stringWithFormat:@"isim.custom.%p", r]];
    d->_resolver = [r copy];
    return d;
}
- (CGFloat)resolvedValueInContext:(id<UISheetPresentationControllerDetentResolutionContext>)c {
    CGFloat max = c.maximumDetentValue;
    if (_kind == 1) return max;
    if (_kind == 0) return floor(isim_ui_device()->height / 2);
    CGFloat v = _resolver ? _resolver(c) : max;
    return v == UISheetPresentationControllerDetentInactive ? v : fmin(max, fmax(0, v));
}
@end

@interface UISheetPresentationController ()
@property (nonatomic, weak) __IsimPresentation *_isim_p;
- (void)_isim_select:(NSString *)i;
@end
@interface __IsimPresentation : NSObject
- (void)sheetDetentsChanged:(BOOL)animated;
@end

@implementation UISheetPresentationController
@dynamic delegate;
- (instancetype)initWithPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting {
    if ((self = [super initWithPresentedViewController:presented presentingViewController:presenting])) {
        self._isim_style = UIModalPresentationPageSheet;
        _detents = @[[UISheetPresentationControllerDetent largeDetent]];
        _prefersScrollingExpandsWhenScrolledToEdge = YES;
        _preferredCornerRadius = UISheetPresentationControllerAutomaticDimension;
    }
    return self;
}
- (void)setDetents:(NSArray *)d { _detents = d.count ? [d copy] : @[[UISheetPresentationControllerDetent largeDetent]]; [self._isim_p sheetDetentsChanged:NO]; }
- (void)setSelectedDetentIdentifier:(NSString *)i { _selectedDetentIdentifier = [i copy]; [self._isim_p sheetDetentsChanged:_isim_animating]; }
- (void)setLargestUndimmedDetentIdentifier:(NSString *)i { _largestUndimmedDetentIdentifier = [i copy]; [self._isim_p sheetDetentsChanged:_isim_animating]; }
- (void)setPrefersGrabberVisible:(BOOL)g { _prefersGrabberVisible = g; [self._isim_p sheetDetentsChanged:NO]; }
static BOOL _isim_animating;
- (void)animateChanges:(void (^)(void))changes {
    _isim_animating = YES;
    if (changes) changes();
    _isim_animating = NO;
}
- (void)invalidateDetents { [self._isim_p sheetDetentsChanged:NO]; }
- (void)_isim_select:(NSString *)i { _selectedDetentIdentifier = [i copy]; }      /* the user dragged to a detent: no relayout */
@end

/* ---- popovers ---- */
@interface UIPopoverPresentationController ()
@property (nonatomic, readwrite) UIPopoverArrowDirection arrowDirection;
@end
@implementation UIPopoverPresentationController
@dynamic delegate;
- (instancetype)initWithPresentedViewController:(UIViewController *)presented presentingViewController:(UIViewController *)presenting {
    if ((self = [super initWithPresentedViewController:presented presentingViewController:presenting])) {
        self._isim_style = UIModalPresentationPopover; _permittedArrowDirections = UIPopoverArrowDirectionAny; _arrowDirection = UIPopoverArrowDirectionUnknown;
    }
    return self;
}
- (UIModalPresentationStyle)adaptivePresentationStyleForTraitCollection:(UITraitCollection *)t { return compact_width(self.presentingViewController.viewIfLoaded) ? UIModalPresentationPageSheet : UIModalPresentationPopover; }
@end

/* the popover card: background with an arrow towards the source */
@interface __IsimPopoverView : UIView
@property (nonatomic) UIPopoverArrowDirection arrow;
@property (nonatomic) CGFloat arrowOffset;                /* along the edge, from the card's origin */
@property (nonatomic, strong) UIColor *fill;
@end
@implementation __IsimPopoverView
#define ARROW 13.0
- (void)_isim_drawContent {
    CGSize s = self.bounds.size;
    CGRect body = CGRectMake(0, 0, s.width, s.height);
    if (_arrow == UIPopoverArrowDirectionUp) { body.origin.y += ARROW; body.size.height -= ARROW; }
    else if (_arrow == UIPopoverArrowDirectionDown) body.size.height -= ARROW;
    else if (_arrow == UIPopoverArrowDirectionLeft) { body.origin.x += ARROW; body.size.width -= ARROW; }
    else if (_arrow == UIPopoverArrowDirectionRight) body.size.width -= ARROW;
    double sh[4] = { 0, 0, 0, 0.06 };
    for (int i = 3; i >= 1; i--) isim_gfx_fill_rounded(body.origin.x - i * 2, body.origin.y - i * 2 + 2, body.size.width + i * 4, body.size.height + i * 4, 13 + i * 2, sh);
    double c[4]; isim_ui_rgba(_fill ?: UIColor.systemBackgroundColor, c);
    isim_gfx_fill_rounded(body.origin.x, body.origin.y, body.size.width, body.size.height, 13, c);
    double a = _arrowOffset;
    isim_path_begin();
    switch (_arrow) {
    case UIPopoverArrowDirectionUp: isim_path_move(a - ARROW, ARROW + 0.5); isim_path_line(a, 0); isim_path_line(a + ARROW, ARROW + 0.5); break;
    case UIPopoverArrowDirectionDown: isim_path_move(a - ARROW, s.height - ARROW - 0.5); isim_path_line(a, s.height); isim_path_line(a + ARROW, s.height - ARROW - 0.5); break;
    case UIPopoverArrowDirectionLeft: isim_path_move(ARROW + 0.5, a - ARROW); isim_path_line(0, a); isim_path_line(ARROW + 0.5, a + ARROW); break;
    case UIPopoverArrowDirectionRight: isim_path_move(s.width - ARROW - 0.5, a - ARROW); isim_path_line(s.width, a); isim_path_line(s.width - ARROW - 0.5, a + ARROW); break;
    default: break;
    }
    isim_path_close(); isim_path_fill(c);
}
@end

/* ================= the transition view: one per presentation, above the presenter ================= */
@interface __IsimTransitionView : UIView
@property (nonatomic, weak) __IsimPresentation *presentation;
@end

@interface __IsimSheetDrag : UIPanGestureRecognizer
@property (nonatomic, weak) __IsimPresentation *presentation;
@property (nonatomic, weak) UIScrollView *heldScroll;
@end

@interface __IsimGrabber : UIView
@end
@implementation __IsimGrabber
- (void)_isim_drawContent { double c[4]; isim_ui_rgba(UIColor.tertiaryLabelColor, c); CGSize s = self.bounds.size; isim_gfx_fill_rounded(0, 0, s.width, s.height, s.height / 2, c); }
@end

/* ================= a presentation ================= */
enum { P_FULL, P_SHEET, P_POPOVER, P_FORMCARD };          /* layout kinds */
@interface __IsimPresentation () <UIGestureRecognizerDelegate>
@property (nonatomic, weak) UIViewController *presenter;
@property (nonatomic, strong) UIViewController *presented;
@property (nonatomic, strong) UIPresentationController *pc;
@property (nonatomic) UIModalPresentationStyle style;            /* after adaptation */
@property (nonatomic) int kind;
@property (nonatomic, strong) __IsimTransitionView *container;
@property (nonatomic, strong) UIView *dim;
@property (nonatomic, strong) __IsimPopoverView *popoverCard;
@property (nonatomic, strong) __IsimGrabber *grabber;
@property (nonatomic, strong) __IsimSheetDrag *drag;
@property (nonatomic, weak) UIView *behind;                     /* sheet card stack: the presenter's top view */
@property (nonatomic, strong) UIColor *windowBG; @property (nonatomic) BOOL behindClipped; @property (nonatomic) CGFloat behindRadius;
@property (nonatomic, weak) UIViewController *coveredRoot;     /* .fullScreen/.currentContext: disappears underneath */
@property (nonatomic, strong) __IsimTransitionContext *context;
@property (nonatomic, strong) id<UIViewControllerInteractiveTransitioning> interaction;
@property (nonatomic) CGFloat sheetTop, dragStartTop;
@property (nonatomic) BOOL dismissing, presentingNow;
- (void)layoutContainer;
- (BOOL)passesTouchesAt:(CGPoint)pt;
- (void)tappedOutside;
- (BOOL)dragAcceptsTouch:(UITouch *)t heldScroll:(UIScrollView * __strong *)held;
- (void)sheetDragged:(__IsimSheetDrag *)g;
@end

@implementation __IsimTransitionView
- (void)layoutSubviews {
    __IsimPresentation *p = self.presentation;
    [p.pc containerViewWillLayoutSubviews];
    [super layoutSubviews];
    [p layoutContainer];
    [p.pc containerViewDidLayoutSubviews];
}
/* below an undimmed sheet detent, and outside a popover's card, touches go through to the presenter */
- (UIView *)hitTest:(CGPoint)pt withEvent:(UIEvent *)e {
    UIView *h = [super hitTest:pt withEvent:e];
    __IsimPresentation *p = self.presentation;
    if ((h == self || h == p.dim) && [p passesTouchesAt:pt]) return nil;
    return h;
}
- (void)touchesEnded:(NSSet *)t withEvent:(UIEvent *)e { [self.presentation tappedOutside]; }
@end

@implementation __IsimPresentation
/* ---- geometry ---- */
- (CGFloat)H { return _container.bounds.size.height; }
- (CGFloat)largeTop { return isim_ui_device()->safe_top + 10; }
- (UISheetPresentationController *)sheet { return [_pc isKindOfClass:[UISheetPresentationController class]] ? (UISheetPresentationController *)_pc : nil; }
/* detent tops (y of the sheet's top edge), sorted from the top (largest) down, with their identifiers */
- (NSArray<NSArray *> *)detentTops {
    UISheetPresentationController *s = [self sheet];
    __IsimDetentContext *ctx = [__IsimDetentContext new];
    ctx.containerTraitCollection = _container.traitCollection;
    CGFloat H = [self H], large = H - [self largeTop];
    ctx.maximumDetentValue = large;
    NSMutableArray *out = [NSMutableArray array];
    for (UISheetPresentationControllerDetent *d in s.detents ?: @[[UISheetPresentationControllerDetent largeDetent]]) {
        CGFloat v = [d resolvedValueInContext:ctx];
        if (v == UISheetPresentationControllerDetentInactive || v <= 0) continue;
        [out addObject:@[@(H - v), d.identifier ?: @""]];
    }
    if (!out.count) [out addObject:@[@(H - large), UISheetPresentationControllerDetentIdentifierLarge]];
    [out sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) { return [a[0] compare:b[0]]; }];
    return out;
}
- (CGFloat)topForIdentifier:(NSString *)ident {
    NSArray *tops = [self detentTops];
    for (NSArray *t in tops) if ([t[1] isEqualToString:ident ?: @""]) return [t[0] doubleValue];
    return [tops.lastObject[0] doubleValue];                       /* default: the smallest detent */
}
- (NSString *)identifierForTop:(CGFloat)top { for (NSArray *t in [self detentTops]) if (fabs([t[0] doubleValue] - top) < 0.5) return t[1]; return nil; }
- (CGRect)presentedFrame {
    CGRect b = _container.bounds;
    switch (_kind) {
    case P_SHEET: return CGRectMake(0, _sheetTop, b.size.width, MAX(0, b.size.height - _sheetTop));
    case P_FORMCARD: {
        BOOL form = _style == UIModalPresentationFormSheet;
        CGSize pref = _presented.preferredContentSize;
        const struct isim_device *d = isim_ui_device();
        CGFloat w = form ? (pref.width > 0 ? pref.width : 540) : MIN(b.size.width - 80, 704);
        CGFloat h = form ? (pref.height > 0 ? pref.height : MIN(620, b.size.height - 80)) : b.size.height - 2 * (d->safe_top + 24);
        return CGRectMake(floor((b.size.width - w) / 2), floor((b.size.height - h) / 2), w, h);
    }
    case P_POPOVER: return [self popoverContentFrame];
    default: return _pc ? _pc.frameOfPresentedViewInContainerView : b;
    }
}

/* ---- sheet state ---- */
- (CGFloat)dimMax { return 0.3; }
- (void)applySheetTop:(CGFloat)top {
    _sheetTop = top;
    UIView *v = _presented.view;
    CGRect f = [self presentedFrame];
    if (!CGRectEqualToRect(v.frame, f)) v.frame = f;
    _grabber.frame = CGRectMake(floor(f.size.width / 2 - 18), f.origin.y + 5, 36, 5);
    NSArray *tops = [self detentTops];
    CGFloat H = [self H], smallest = [tops.lastObject[0] doubleValue], large = [tops.firstObject[0] doubleValue];
    /* dimming: off at or below the largest undimmed detent, ramping up towards the next larger detent */
    NSString *und = [self sheet].largestUndimmedDetentIdentifier;
    CGFloat dim;
    if (und) {
        CGFloat ut = [self topForIdentifier:und], next = ut;
        for (NSArray *t in tops) if ([t[0] doubleValue] < ut - 0.5) next = [t[0] doubleValue];
        dim = ut - next < 1 ? 0 : [self dimMax] * fmin(1, fmax(0, (ut - top) / (ut - next)));
    } else dim = [self dimMax] * fmin(1, fmax(0, (H - top) / fmax(1, H - smallest)));
    /* card stack: the presenter shrinks as the sheet reaches the large detent */
    UIView *behind = _behind;
    if (behind) {
        CGFloat ref = tops.count > 1 ? [tops[1][0] doubleValue] : H;
        CGFloat q = ref - large < 1 ? 1 : fmin(1, fmax(0, (ref - top) / (ref - large)));
        const struct isim_device *d = isim_ui_device();
        CGFloat W = _container.bounds.size.width, sc = (W - 32) / W, ty = (d->safe_top - 6) - H * (1 - sc) / 2;
        CGFloat s = 1 - (1 - sc) * q;
        behind.transform = CGAffineTransformTranslate(CGAffineTransformMakeScale(s, s), 0, ty * q / s);
        behind.layer.cornerRadius = 10 * q;
        dim = fmin(dim, 0.12 + 0.18 * (1 - q));
    }
    _dim.alpha = dim;
}
- (void)sheetDetentsChanged:(BOOL)animated {
    if (_kind != P_SHEET || !_container || _dismissing || _presentingNow) return;
    CGFloat top = [self topForIdentifier:[self sheet].selectedDetentIdentifier];
    if (animated) isim_ui_animate(0.45, 0, 0, 1, 0.9, 0, ^{ [self applySheetTop:top]; }, nil);
    else [UIView performWithoutAnimation:^{ [self applySheetTop:top]; }];
    _grabber.hidden = ![self sheet].prefersGrabberVisible;
}
- (BOOL)passesTouchesAt:(CGPoint)pt {
    if (_kind == P_SHEET) return _dim.alpha < 0.01;
    if (_kind == P_POPOVER)
        for (UIView *v in ((UIPopoverPresentationController *)_pc).passthroughViews) if (CGRectContainsPoint([v convertRect:v.bounds toView:_container], pt)) return YES;
    return NO;
}
- (void)tappedOutside {
    if (_dismissing || _presentingNow) return;
    if ((_kind == P_SHEET && _dim.alpha >= 0.01) || _kind == P_FORMCARD) { [self userDismissAttempt]; return; }
    if (_kind == P_POPOVER) {
        UIPopoverPresentationController *pop = (UIPopoverPresentationController *)_pc;
        id<UIPopoverPresentationControllerDelegate> d = pop.delegate;
        if ([d respondsToSelector:@selector(popoverPresentationControllerShouldDismissPopover:)] && ![d popoverPresentationControllerShouldDismissPopover:pop]) return;
        [self userDismissAttempt];
    }
}
/* swipe down / tap outside: ask the delegate, then dismiss (or report the attempt for modal-in-presentation) */
- (void)userDismissAttempt {
    id<UIAdaptivePresentationControllerDelegate> d = _pc.delegate;
    if (_presented.isModalInPresentation || ([d respondsToSelector:@selector(presentationControllerShouldDismiss:)] && ![d presentationControllerShouldDismiss:_pc])) {
        if ([d respondsToSelector:@selector(presentationControllerDidAttemptToDismiss:)]) [d presentationControllerDidAttemptToDismiss:_pc];
        if (_kind == P_SHEET) isim_ui_animate(0.45, 0, 0, 1, 0.85, 0, ^{ [self applySheetTop:[self topForIdentifier:[self sheet].selectedDetentIdentifier]]; }, nil);
        return;
    }
    if ([d respondsToSelector:@selector(presentationControllerWillDismiss:)]) [d presentationControllerWillDismiss:_pc];
    UIPresentationController *pc = _pc;
    [_presented dismissViewControllerAnimated:YES completion:^{
        if ([d respondsToSelector:@selector(presentationControllerDidDismiss:)]) [d presentationControllerDidDismiss:pc];
        if ([pc isKindOfClass:[UIPopoverPresentationController class]]) {
            id<UIPopoverPresentationControllerDelegate> pd = (id)d;
            if ([pd respondsToSelector:@selector(popoverPresentationControllerDidDismissPopover:)]) [pd popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)pc];
        }
    }];
}

/* ---- sheet dragging ---- */
- (BOOL)atLargestDetent { return fabs(_sheetTop - [[self detentTops].firstObject[0] doubleValue]) < 1; }
/* iPad sheets (centered cards): follow the finger down, then dismiss or spring back */
- (void)cardDragged:(__IsimSheetDrag *)g {
    UIView *v = _presented.view;
    CGRect home = [self presentedFrame];
    CGFloat dy = [g translationInView:_container].y;
    dy = dy > 0 ? (_presented.isModalInPresentation ? 18 * log1p(dy / 18) : dy) : -12 * log1p(-dy / 12);
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        [UIView performWithoutAnimation:^{ v.frame = CGRectOffset(home, 0, dy); }];
        return;
    }
    CGFloat vy = g.state == UIGestureRecognizerStateEnded ? [g velocityInView:_container].y : 0;
    if (g.state == UIGestureRecognizerStateEnded && (dy > home.size.height * 0.25 || vy > 900)) { [self userDismissAttempt]; if (!_dismissing) isim_ui_animate(0.45, 0, 0, 1, 0.85, 0, ^{ v.frame = home; }, nil); return; }
    isim_ui_animate(0.45, 0, 0, 1, 0.85, 0, ^{ v.frame = home; }, nil);
}
- (void)sheetDragged:(__IsimSheetDrag *)g {
    if (_dismissing || _presentingNow) return;
    if (_kind == P_FORMCARD) { [self cardDragged:g]; return; }
    CGFloat dy = [g translationInView:_container].y;
    NSArray *tops = [self detentTops];
    CGFloat large = [tops.firstObject[0] doubleValue], smallest = [tops.lastObject[0] doubleValue];
    if (g.state == UIGestureRecognizerStateBegan) _dragStartTop = _sheetTop;
    CGFloat top = _dragStartTop + dy;
    if (top < large) top = large - 18 * log1p((large - top) / 18);                       /* rubber band above the largest detent */
    BOOL modal = _presented.isModalInPresentation;
    if (top > smallest && modal) top = smallest + 18 * log1p((top - smallest) / 18);
    if (g.state == UIGestureRecognizerStateBegan || g.state == UIGestureRecognizerStateChanged) {
        [UIView performWithoutAnimation:^{ [self applySheetTop:top]; }];
        return;
    }
    UIScrollView *held = g.heldScroll; if (held) { held.scrollEnabled = YES; g.heldScroll = nil; }
    CGFloat vy = g.state == UIGestureRecognizerStateEnded ? [g velocityInView:_container].y : 0;
    CGFloat projected = top + vy * 0.2;
    CGFloat H = [self H];
    if (g.state == UIGestureRecognizerStateEnded && projected > smallest + (H - smallest) * 0.5 && (top > smallest + 20 || vy > 900)) {
        [self userDismissAttempt];
        return;
    }
    NSString *ident = nil; CGFloat best = CGFLOAT_MAX;
    for (NSArray *t in tops) { CGFloat d = fabs([t[0] doubleValue] - projected); if (d < best) { best = d; ident = t[1]; } }
    UISheetPresentationController *s = [self sheet];
    BOOL changed = ![ident isEqualToString:s.selectedDetentIdentifier ?: tops.lastObject[1]];
    CGFloat target = [self topForIdentifier:ident];
    if (changed) {
        [s _isim_select:ident];
        id<UISheetPresentationControllerDelegate> d = s.delegate;
        if ([d respondsToSelector:@selector(sheetPresentationControllerDidChangeSelectedDetentIdentifier:)]) [d sheetPresentationControllerDidChangeSelectedDetentIdentifier:s];
        NSLog(@"isim: sheet detent %@", ident);
    }
    isim_ui_animate(0.45, 0, 0, 1, 0.9, 0, ^{ [self applySheetTop:target]; }, nil);
}
/* which touches move the sheet: the top area, content that does not scroll, and scroll views while the sheet can still
   expand (prefersScrollingExpandsWhenScrolledToEdge) */
- (BOOL)dragAcceptsTouch:(UITouch *)t heldScroll:(UIScrollView * __strong *)held {
    UIView *v = _presented.view;
    CGPoint p = [t locationInView:v];
    if (p.y <= 64) return YES;
    UIScrollView *sv = nil;
    for (UIView *x = t.view; x && x != v; x = x.superview) if ([x isKindOfClass:[UIScrollView class]]) { sv = (UIScrollView *)x; break; }
    if (!sv) return YES;
    UISheetPresentationController *s = [self sheet];
    if (s.prefersScrollingExpandsWhenScrolledToEdge && ![self atLargestDetent] && sv.contentOffset.y <= -sv.adjustedContentInset.top + 0.5) { *held = sv; return YES; }
    return NO;
}

/* ---- popover geometry ---- */
- (CGRect)anchorRect {
    UIPopoverPresentationController *pop = (UIPopoverPresentationController *)_pc;
    if (pop.barButtonItem) {
        Class bb = NSClassFromString(@"__IsimBarButton");
        NSMutableArray *stack = [NSMutableArray arrayWithObject:_container.window ?: (UIView *)_presenter.view.window];
        while (stack.count) {
            UIView *v = stack.lastObject; [stack removeLastObject];
            if ([v isKindOfClass:bb] && [v respondsToSelector:@selector(item)] && [v performSelector:@selector(item)] == pop.barButtonItem) return [v convertRect:v.bounds toView:_container];
            [stack addObjectsFromArray:v.subviews];
        }
    }
    UIView *src = pop.sourceView ?: _presenter.view;
    CGRect r = CGRectIsEmpty(pop.sourceRect) && CGRectEqualToRect(pop.sourceRect, CGRectZero) ? src.bounds : pop.sourceRect;
    return [src convertRect:r toView:_container];
}
- (CGRect)popoverCardFrame {
    UIPopoverPresentationController *pop = (UIPopoverPresentationController *)_pc;
    CGRect b = _container.bounds, a = [self anchorRect];
    const struct isim_device *d = isim_ui_device();
    CGRect safe = CGRectMake(10, d->safe_top + 6, b.size.width - 20, b.size.height - d->safe_top - d->safe_bottom - 12);
    CGSize want = _presented.preferredContentSize;
    if (want.width <= 0) want.width = 320;
    if (want.height <= 0) want.height = 400;
    UIPopoverArrowDirection perm = pop.permittedArrowDirections ?: UIPopoverArrowDirectionAny;
    CGFloat below = CGRectGetMaxY(safe) - CGRectGetMaxY(a) - ARROW, above = a.origin.y - safe.origin.y - ARROW;
    CGFloat right = CGRectGetMaxX(safe) - CGRectGetMaxX(a) - ARROW, left = a.origin.x - safe.origin.x - ARROW;
    UIPopoverArrowDirection dir = UIPopoverArrowDirectionUnknown;
    if ((perm & UIPopoverArrowDirectionUp) && below >= MIN(want.height, 200)) dir = UIPopoverArrowDirectionUp;
    else if ((perm & UIPopoverArrowDirectionDown) && above >= MIN(want.height, 200)) dir = UIPopoverArrowDirectionDown;
    else if ((perm & UIPopoverArrowDirectionLeft) && right >= MIN(want.width, 200)) dir = UIPopoverArrowDirectionLeft;
    else if ((perm & UIPopoverArrowDirectionRight) && left >= MIN(want.width, 200)) dir = UIPopoverArrowDirectionRight;
    else dir = below >= above ? UIPopoverArrowDirectionUp : UIPopoverArrowDirectionDown;
    pop.arrowDirection = dir;
    CGFloat w = MIN(want.width, safe.size.width), h;
    CGRect f;
    if (dir == UIPopoverArrowDirectionUp || dir == UIPopoverArrowDirectionDown) {
        h = MIN(want.height, dir == UIPopoverArrowDirectionUp ? below : above);
        CGFloat x = fmin(fmax(safe.origin.x, CGRectGetMidX(a) - w / 2), CGRectGetMaxX(safe) - w);
        f = dir == UIPopoverArrowDirectionUp ? CGRectMake(x, CGRectGetMaxY(a), w, h + ARROW) : CGRectMake(x, a.origin.y - h - ARROW, w, h + ARROW);
        _popoverCard.arrowOffset = fmin(fmax(20, CGRectGetMidX(a) - x), w - 20);
    } else {
        w = MIN(want.width, dir == UIPopoverArrowDirectionLeft ? right : left); h = MIN(want.height, safe.size.height);
        CGFloat y = fmin(fmax(safe.origin.y, CGRectGetMidY(a) - h / 2), CGRectGetMaxY(safe) - h);
        f = dir == UIPopoverArrowDirectionLeft ? CGRectMake(CGRectGetMaxX(a), y, w + ARROW, h) : CGRectMake(a.origin.x - w - ARROW, y, w + ARROW, h);
        _popoverCard.arrowOffset = fmin(fmax(20, CGRectGetMidY(a) - y), h - 20);
    }
    _popoverCard.arrow = dir;
    return f;
}
- (CGRect)popoverContentFrame {
    CGRect f = _popoverCard.frame;
    switch (_popoverCard.arrow) {
    case UIPopoverArrowDirectionUp: return CGRectMake(f.origin.x, f.origin.y + ARROW, f.size.width, f.size.height - ARROW);
    case UIPopoverArrowDirectionDown: return CGRectMake(f.origin.x, f.origin.y, f.size.width, f.size.height - ARROW);
    case UIPopoverArrowDirectionLeft: return CGRectMake(f.origin.x + ARROW, f.origin.y, f.size.width - ARROW, f.size.height);
    case UIPopoverArrowDirectionRight: return CGRectMake(f.origin.x, f.origin.y, f.size.width - ARROW, f.size.height);
    default: return f;
    }
}
- (void)layoutContainer {
    if (_presentingNow || _dismissing) return;
    if (_kind == P_POPOVER) { _popoverCard.frame = [self popoverCardFrame]; _presented.view.frame = [self popoverContentFrame]; [_popoverCard setNeedsDisplay]; }
    else if (_kind == P_SHEET) [UIView performWithoutAnimation:^{ [self applySheetTop:self.sheetTop]; }];
    else if (!_context.animator) _presented.view.frame = [self presentedFrame];
}

/* ---- presenting ---- */
static UIView *top_view(UIViewController *vc) { UIView *v = vc.view, *w = v.window; while (v.superview && v.superview != w) v = v.superview; return v; }
static UIViewController *context_root(UIViewController *vc, BOOL contextStyle) {
    if (contextStyle) for (UIViewController *x = vc; x; x = x.parentViewController) if (x.definesPresentationContext) return x;
    UIViewController *c = vc;
    while (c.parentViewController) c = c.parentViewController;
    return c;
}
- (void)present:(BOOL)animated done:(void (^)(void))done {
    UIViewController *presenter = _presenter, *vc = _presented;
    UIWindow *w = presenter.view.window;
    BOOL contextStyle = _style == UIModalPresentationCurrentContext || _style == UIModalPresentationOverCurrentContext;
    UIViewController *ctxRoot = context_root(presenter, contextStyle);
    CGRect cf = contextStyle ? [ctxRoot.view convertRect:ctxRoot.view.bounds toView:w] : w.bounds;
    __IsimTransitionView *c = [[__IsimTransitionView alloc] initWithFrame:cf];
    c.presentation = self;
    if (!contextStyle) c.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    c.accessibilityIdentifier = @"isim-presentation";
    _container = c; _pc.containerView = c;
    if (_kind == P_FULL && _pc.shouldRemovePresentersView) _coveredRoot = ctxRoot;
    [w addSubview:c];
    UIView *v = vc.view;
    if (!v.backgroundColor && _kind != P_POPOVER) v.backgroundColor = UIColor.systemBackgroundColor;
    _presentingNow = YES;
    __IsimTransitionContext *ctx = [__IsimTransitionContext new];          /* the transition coordinator during WillBegin */
    ctx.containerView = c; ctx.animated = animated; ctx.presentationStyle = _style;
    ctx.fromVC = presenter; ctx.toVC = vc;
    ctx.toView = _pc.presentedView ?: v; ctx.fromView = _pc.shouldRemovePresentersView ? presenter.view : nil;
    ctx.fromInitial = ctx.fromFinal = [presenter.view convertRect:presenter.view.bounds toView:c];
    _context = ctx;
    __weak __IsimPresentation *wp = self;
    ctx.onComplete = ^(BOOL completed) { [wp finishPresenting:completed done:done]; };
    [_pc presentationTransitionWillBegin];
    [vc _isim_appear:YES];

    id<UIViewControllerTransitioningDelegate> td = vc.transitioningDelegate;
    id<UIViewControllerAnimatedTransitioning> anim = [td respondsToSelector:@selector(animationControllerForPresentedController:presentingController:sourceController:)]
        ? [td animationControllerForPresentedController:vc presentingController:presenter sourceController:presenter] : nil;
    if (anim && _kind == P_FULL) {                        /* custom animator: it adds the view and calls completeTransition */
        ctx.animator = anim;
        ctx.toFinal = [self presentedFrame];
        ctx.duration = [anim transitionDuration:ctx];
        id<UIViewControllerInteractiveTransitioning> inter = [td respondsToSelector:@selector(interactionControllerForPresentation:)] ? [td interactionControllerForPresentation:anim] : nil;
        NSLog(@"isim: custom presentation transition%@", inter ? @" (interactive)" : @"");
        if (inter) { ctx.interactive = YES; _interaction = inter; [inter startInteractiveTransition:ctx]; }
        else { [anim animateTransition:ctx]; [ctx _isim_runAlongside]; }
        return;
    }
    switch (_kind) {
    case P_SHEET: [self presentSheet:animated]; break;
    case P_POPOVER: [self presentPopover:animated]; break;
    case P_FORMCARD: [self presentCard:animated]; break;
    default: [self presentFull:animated]; break;
    }
}
/* full screen / over context: slide up, fade or flip */
- (void)presentFull:(BOOL)animated {
    UIView *c = _container, *v = _pc.presentedView ?: _presented.view;
    CGRect end = [self presentedFrame];
    __IsimTransitionContext *ctx = _context;
    ctx.toFinal = end;
    [UIView performWithoutAnimation:^{ v.frame = end; v.alpha = 1; v.transform = CGAffineTransformIdentity; }];
    if (CGRectEqualToRect(end, c.bounds)) v.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [c addSubview:v];
    void (^complete)(BOOL) = ^(BOOL f) { [ctx completeTransition:YES]; };
    UIModalTransitionStyle ts = _presented.modalTransitionStyle;
    if (!animated) { ctx.duration = 0; [ctx _isim_runAlongside]; dispatch_async(dispatch_get_main_queue(), ^{ complete(YES); }); return; }
    if (ts == UIModalTransitionStyleCrossDissolve) {
        ctx.duration = 0.35;
        [UIView performWithoutAnimation:^{ v.alpha = 0; }];
        isim_ui_animate(0.35, 0, 0, 0, 0, 0, ^{ v.alpha = 1; }, complete);
    } else if (ts == UIModalTransitionStyleFlipHorizontal) {
        /* adapted (2D): the presenter folds to its vertical axis, then the presented view unfolds */
        ctx.duration = 0.5;
        UIView *behind = top_view(_presenter);
        if (behind == c) behind = nil;
        v.hidden = YES;
        isim_ui_animate(0.25, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ behind.transform = CGAffineTransformMakeScale(0.02, 1); }, ^(BOOL f) {
            [UIView performWithoutAnimation:^{ behind.transform = CGAffineTransformIdentity; v.hidden = NO; v.transform = CGAffineTransformMakeScale(0.02, 1); }];
            isim_ui_animate(0.25, 0, UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ v.transform = CGAffineTransformIdentity; }, complete);
        });
    } else {
        if (ts == UIModalTransitionStylePartialCurl) NSLog(@"isim: partial curl shown as cover vertical (adapted)");
        ctx.duration = 0.5;
        [UIView performWithoutAnimation:^{ v.frame = CGRectOffset(end, 0, c.bounds.size.height); }];
        isim_ui_animate(0.5, 0, 0, 1, 1.0, 0, ^{ v.frame = end; }, complete);
    }
    [ctx _isim_runAlongside];
}
/* iPad form/page sheet: a centered card over a dimming view */
- (void)presentCard:(BOOL)animated {
    UIView *c = _container, *v = _presented.view;
    _dim = [[UIView alloc] initWithFrame:c.bounds];
    _dim.backgroundColor = UIColor.blackColor; _dim.alpha = 0;
    _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [c addSubview:_dim];
    CGRect end = [self presentedFrame];
    v.autoresizingMask = UIViewAutoresizingNone; v.layer.cornerRadius = 10; v.clipsToBounds = YES;
    [c addSubview:v];
    _drag = [[__IsimSheetDrag alloc] initWithTarget:self action:@selector(sheetDragged:)];
    _drag.presentation = self;
    [v addGestureRecognizer:_drag];
    [UIView performWithoutAnimation:^{ v.frame = CGRectOffset(end, 0, c.bounds.size.height); }];
    __IsimTransitionContext *ctx = _context; ctx.duration = animated ? 0.5 : 0; ctx.toFinal = end;
    void (^anim)(void) = ^{ v.frame = end; self.dim.alpha = 0.3; };
    if (animated) isim_ui_animate(0.5, 0, 0, 1, 1.0, 0, anim, ^(BOOL f) { [ctx completeTransition:YES]; });
    else { [UIView performWithoutAnimation:anim]; dispatch_async(dispatch_get_main_queue(), ^{ [ctx completeTransition:YES]; }); }
    [ctx _isim_runAlongside];
}
/* iPhone sheet: detents, grabber, dimming, card stack */
- (void)presentSheet:(BOOL)animated {
    UIView *c = _container, *v = _presented.view;
    UISheetPresentationController *s = [self sheet];
    s._isim_p = self;
    _dim = [[UIView alloc] initWithFrame:c.bounds];
    _dim.backgroundColor = UIColor.blackColor; _dim.alpha = 0;
    _dim.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [c addSubview:_dim];
    v.autoresizingMask = UIViewAutoresizingNone;
    v.layer.cornerRadius = s.preferredCornerRadius > 0 ? s.preferredCornerRadius : 10; v.clipsToBounds = YES;
    v.layer.shadowColor = UIColor.blackColor.CGColor; v.layer.shadowOpacity = 0.12; v.layer.shadowRadius = 6; v.layer.shadowOffset = CGSizeMake(0, -1);
    [c addSubview:v];
    _grabber = [__IsimGrabber new];
    _grabber.userInteractionEnabled = NO;
    _grabber.hidden = !s.prefersGrabberVisible;
    _grabber.accessibilityIdentifier = @"isim-sheet-grabber";
    [c addSubview:_grabber];
    _drag = [[__IsimSheetDrag alloc] initWithTarget:self action:@selector(sheetDragged:)];
    _drag.presentation = self;
    [v addGestureRecognizer:_drag];
    /* the presenter's top-level view becomes a card behind the first-level sheet */
    UIView *behind = top_view(_presenter);
    UIWindow *w = c.window;
    if (behind && behind.superview == w && ![behind isKindOfClass:[__IsimTransitionView class]] && ![behind isKindOfClass:NSClassFromString(@"UIAlertController")]) {
        _behind = behind;
        _windowBG = w.backgroundColor; _behindClipped = behind.clipsToBounds; _behindRadius = behind.layer.cornerRadius;
        w.backgroundColor = UIColor.blackColor;
        behind.clipsToBounds = YES;
    }
    CGFloat top = [self topForIdentifier:s.selectedDetentIdentifier];
    [UIView performWithoutAnimation:^{ [self applySheetTop:c.bounds.size.height]; }];
    __IsimTransitionContext *ctx = _context; ctx.duration = animated ? 0.5 : 0;
    void (^anim)(void) = ^{ [self applySheetTop:top]; };
    if (animated) isim_ui_animate(0.5, 0, 0, 1, 1.0, 0, anim, ^(BOOL f) { [ctx completeTransition:YES]; });
    else { [UIView performWithoutAnimation:anim]; dispatch_async(dispatch_get_main_queue(), ^{ [ctx completeTransition:YES]; }); }
    ctx.toFinal = [self presentedFrame];
    [ctx _isim_runAlongside];
}
/* popover: a card with an arrow pointing at the source */
- (void)presentPopover:(BOOL)animated {
    UIView *c = _container, *v = _presented.view;
    UIPopoverPresentationController *pop = (UIPopoverPresentationController *)_pc;
    id<UIPopoverPresentationControllerDelegate> d = pop.delegate;
    if ([d respondsToSelector:@selector(prepareForPopoverPresentation:)]) [d prepareForPopoverPresentation:pop];
    _popoverCard = [__IsimPopoverView new];
    _popoverCard.fill = pop.backgroundColor ?: v.backgroundColor ?: UIColor.systemBackgroundColor;
    _popoverCard.userInteractionEnabled = NO;
    _popoverCard.accessibilityIdentifier = @"isim-popover";
    [c addSubview:_popoverCard];
    _popoverCard.frame = [self popoverCardFrame];
    v.frame = [self popoverContentFrame];
    v.autoresizingMask = UIViewAutoresizingNone;
    if (!v.backgroundColor) v.backgroundColor = _popoverCard.fill;
    v.layer.cornerRadius = 13; v.clipsToBounds = YES;
    [c addSubview:v];
    NSLog(@"isim: popover shown, arrow %@", @{ @1: @"up", @2: @"down", @4: @"left", @8: @"right" }[@(pop.arrowDirection)] ?: @"?");
    __IsimTransitionContext *ctx = _context; ctx.duration = animated ? 0.25 : 0; ctx.toFinal = v.frame;
    UIView *card = _popoverCard;
    [UIView performWithoutAnimation:^{ card.alpha = 0; v.alpha = 0; }];
    isim_ui_animate(animated ? 0.25 : 0, 0, UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ card.alpha = 1; v.alpha = 1; }, ^(BOOL f) { [ctx completeTransition:YES]; });
    [ctx _isim_runAlongside];
}
- (void)finishPresenting:(BOOL)completed done:(void (^)(void))done {
    _presentingNow = NO;
    [_pc presentationTransitionDidEnd:completed];
    if (!completed) {                                         /* an interactive presentation was cancelled */
        [_presented _isim_appear:NO];
        [_presenter _isim_setPresented:nil]; [_presented _isim_setPresenting:nil];
        [(_pc.presentedView ?: _presented.view) removeFromSuperview];
        [_container removeFromSuperview];
        objc_setAssociatedObject(_presented, &kPresentation, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (_coveredRoot) [_coveredRoot _isim_appear:NO];         /* the presenter is covered (full screen / current context) */
    [_presented _isim_didAppear];
    [_container setNeedsLayout];
    if (done) done();
}

/* ---- dismissing ---- */
- (void)dismiss:(BOOL)animated done:(void (^)(void))done {
    _dismissing = YES;
    UIViewController *presenter = _presenter, *vc = _presented;
    [presenter _isim_setPresented:nil]; [vc _isim_setPresenting:nil];
    _container.userInteractionEnabled = NO;
    UIView *v = _pc.presentedView ?: vc.view;
    __IsimTransitionContext *ctx = [__IsimTransitionContext new];
    ctx.containerView = _container; ctx.animated = animated; ctx.presentationStyle = _style;
    ctx.fromVC = vc; ctx.toVC = presenter; ctx.fromView = v; ctx.toView = _pc.shouldRemovePresentersView ? presenter.view : nil;
    ctx.fromInitial = v.frame; ctx.fromFinal = v.frame; ctx.toFinal = [presenter.view convertRect:presenter.view.bounds toView:_container];
    _context = ctx;
    __strong __IsimPresentation *keep = self;
    ctx.onComplete = ^(BOOL completed) { [keep finishDismissing:completed done:done]; };
    [_pc dismissalTransitionWillBegin];
    if (_coveredRoot) [_coveredRoot _isim_appear:YES];
    id<UIViewControllerTransitioningDelegate> td = vc.transitioningDelegate;
    id<UIViewControllerAnimatedTransitioning> anim = [td respondsToSelector:@selector(animationControllerForDismissedController:)] ? [td animationControllerForDismissedController:vc] : nil;
    if (anim && _kind == P_FULL) {
        ctx.animator = anim;
        ctx.duration = [anim transitionDuration:ctx];
        id<UIViewControllerInteractiveTransitioning> inter = [td respondsToSelector:@selector(interactionControllerForDismissal:)] ? [td interactionControllerForDismissal:anim] : nil;
        NSLog(@"isim: custom dismissal transition%@", inter ? @" (interactive)" : @"");
        if (inter) { ctx.interactive = YES; _interaction = inter; [inter startInteractiveTransition:ctx]; }
        else { [anim animateTransition:ctx]; [ctx _isim_runAlongside]; }
        return;
    }
    void (^complete)(BOOL) = ^(BOOL f) { [ctx completeTransition:YES]; };
    if (!animated) { ctx.duration = 0; [ctx _isim_runAlongside]; dispatch_async(dispatch_get_main_queue(), ^{ complete(YES); }); return; }
    CGFloat H = _container.bounds.size.height;
    UIView *dim = _dim, *card = _popoverCard;
    switch (_kind) {
    case P_SHEET: {
        ctx.duration = 0.38;
        isim_ui_animate(0.38, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ [self applySheetTop:H]; dim.alpha = 0; if (self.behind) { self.behind.transform = CGAffineTransformIdentity; self.behind.layer.cornerRadius = 0; } }, complete);
        break;
    }
    case P_POPOVER: {
        ctx.duration = 0.2;
        isim_ui_animate(0.2, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ card.alpha = 0; v.alpha = 0; }, complete);
        break;
    }
    case P_FORMCARD: {
        ctx.duration = 0.38;
        isim_ui_animate(0.38, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ v.frame = CGRectOffset(v.frame, 0, H); dim.alpha = 0; }, complete);
        break;
    }
    default: {
        UIModalTransitionStyle ts = vc.modalTransitionStyle;
        if (ts == UIModalTransitionStyleCrossDissolve) {
            ctx.duration = 0.35;
            isim_ui_animate(0.35, 0, 0, 0, 0, 0, ^{ v.alpha = 0; }, complete);
        } else if (ts == UIModalTransitionStyleFlipHorizontal) {
            ctx.duration = 0.5;
            UIView *behind = top_view(presenter);
            isim_ui_animate(0.25, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ v.transform = CGAffineTransformMakeScale(0.02, 1); }, ^(BOOL f) {
                [UIView performWithoutAnimation:^{ v.hidden = YES; behind.transform = CGAffineTransformMakeScale(0.02, 1); }];
                isim_ui_animate(0.25, 0, UIViewAnimationOptionCurveEaseOut, 0, 0, 0, ^{ behind.transform = CGAffineTransformIdentity; }, complete);
            });
        } else {
            ctx.duration = 0.38;
            isim_ui_animate(0.38, 0, UIViewAnimationOptionCurveEaseIn, 0, 0, 0, ^{ v.frame = CGRectOffset(v.frame, 0, H); }, complete);
        }
    }
    }
    [ctx _isim_runAlongside];
}
- (void)finishDismissing:(BOOL)completed done:(void (^)(void))done {
    UIView *v = _pc.presentedView ?: _presented.view;
    if (!completed) {                                         /* an interactive dismissal was cancelled */
        _dismissing = NO;
        [_presenter _isim_setPresented:_presented]; [_presented _isim_setPresenting:_presenter];
        _container.userInteractionEnabled = YES;
        [_pc dismissalTransitionDidEnd:NO];
        if (_coveredRoot) [_coveredRoot _isim_appear:NO];
        return;
    }
    [_presented _isim_appear:NO];
    UIView *behind = _behind;
    if (behind) {
        behind.transform = CGAffineTransformIdentity;
        behind.clipsToBounds = _behindClipped; behind.layer.cornerRadius = _behindRadius;
        behind.window.backgroundColor = _windowBG;
    }
    if (_drag) [v removeGestureRecognizer:_drag];
    [v removeFromSuperview];
    [_container removeFromSuperview];
    [UIView performWithoutAnimation:^{ v.alpha = 1; v.transform = CGAffineTransformIdentity; v.hidden = NO; }];
    if (_kind != P_FULL) { v.layer.cornerRadius = 0; v.clipsToBounds = NO; v.layer.shadowOpacity = 0; }
    [_pc dismissalTransitionDidEnd:YES];
    _pc.containerView = nil;
    if (_coveredRoot) [_coveredRoot _isim_didAppear];
    objc_setAssociatedObject(_presented, &kPresentation, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (done) done();
}
@end

/* ================= sheet drag recognizer ================= */
@implementation __IsimSheetDrag { BOOL _ignoring; }
- (void)_isim_touch:(UITouch *)touch phase:(UITouchPhase)phase event:(UIEvent *)event {
    if (phase == UITouchPhaseBegan) {
        UIScrollView *held = nil;
        _ignoring = ![self.presentation dragAcceptsTouch:touch heldScroll:&held];
        if (!_ignoring && held) { held.scrollEnabled = NO; self.heldScroll = held; }
    }
    if (!_ignoring) [super _isim_touch:touch phase:phase event:event];
    if (phase == UITouchPhaseEnded && self.heldScroll && (self.state == UIGestureRecognizerStatePossible || self.state == UIGestureRecognizerStateFailed)) {
        self.heldScroll.scrollEnabled = YES; self.heldScroll = nil;
    }
}
@end

/* ================= entry points (UIApplication.m) ================= */
BOOL isim_ui_present(UIViewController *presenter, UIViewController *vc, BOOL animated, void (^done)(void)) {
    if ([vc isKindOfClass:[UIAlertController class]]) return NO;
    UIWindow *w = presenter.viewIfLoaded.window;
    if (!w) return NO;
    BOOL compact = w.bounds.size.width < 700;
    UIModalPresentationStyle req = vc.modalPresentationStyle;
    if (req == UIModalPresentationAutomatic) req = UIModalPresentationPageSheet;
    id<UIViewControllerTransitioningDelegate> td = vc.transitioningDelegate;
    UIPresentationController *pc = nil;
    if (req == UIModalPresentationCustom && [td respondsToSelector:@selector(presentationControllerForPresentedViewController:presentingViewController:sourceViewController:)])
        pc = [td presentationControllerForPresentedViewController:vc presentingViewController:presenter sourceViewController:presenter];
    if (!pc) pc = vc.presentationController;
    [pc _isim_setPresentingVC:presenter];
    UIModalPresentationStyle style = req;
    if (compact && (req == UIModalPresentationPopover || req == UIModalPresentationFormSheet || req == UIModalPresentationPageSheet)) {
        UIModalPresentationStyle adapted = UIModalPresentationPageSheet;
        id<UIAdaptivePresentationControllerDelegate> d = pc.delegate;
        if ([d respondsToSelector:@selector(adaptivePresentationStyleForPresentationController:traitCollection:)]) adapted = [d adaptivePresentationStyleForPresentationController:pc traitCollection:w.traitCollection];
        else if ([d respondsToSelector:@selector(adaptivePresentationStyleForPresentationController:)]) adapted = [d adaptivePresentationStyleForPresentationController:pc];
        style = adapted == UIModalPresentationNone ? req : adapted;
        if (style == UIModalPresentationAutomatic) style = UIModalPresentationPageSheet;
        if (req == UIModalPresentationPopover && style != UIModalPresentationPopover) NSLog(@"isim: popover adapted to a %@ on iPhone", style == UIModalPresentationPageSheet || style == UIModalPresentationFormSheet ? @"sheet" : @"full-screen presentation");
    }
    __IsimPresentation *p = [__IsimPresentation new];
    p.presenter = presenter; p.presented = vc; p.style = style;
    if (style == UIModalPresentationPopover) p.kind = P_POPOVER;
    else if (style == UIModalPresentationPageSheet || style == UIModalPresentationFormSheet) p.kind = compact ? P_SHEET : P_FORMCARD;
    else p.kind = P_FULL;
    if (p.kind == P_SHEET && ![pc isKindOfClass:[UISheetPresentationController class]]) {    /* an adapted popover: its sheet */
        UISheetPresentationController *s = [[UISheetPresentationController alloc] initWithPresentedViewController:vc presentingViewController:presenter];
        s.delegate = (id)pc.delegate;
        pc = s;
    }
    if (p.kind == P_FULL && ([pc isKindOfClass:[UISheetPresentationController class]] || [pc isKindOfClass:[UIPopoverPresentationController class]])) {
        pc = [[UIPresentationController alloc] initWithPresentedViewController:vc presentingViewController:presenter];
    }
    if ([pc isMemberOfClass:[UIPresentationController class]]) pc._isim_style = style;
    p.pc = pc;
    objc_setAssociatedObject(vc, &kPresentation, p, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [presenter _isim_setPresented:vc]; [vc _isim_setPresenting:presenter];
    [p present:animated done:done];
    return YES;
}
BOOL isim_ui_dismiss(UIViewController *caller, BOOL animated, void (^done)(void)) {
    UIViewController *target = caller.presentedViewController ?: caller;
    __IsimPresentation *p = objc_getAssociatedObject(target, &kPresentation);
    if (!p) return NO;
    if (p.dismissing) return YES;
    if (target.presentedViewController) [target dismissViewControllerAnimated:NO completion:nil];     /* nested presentations go first */
    [p dismiss:animated done:done];
    return YES;
}

/* ================= interactive transitions ================= */
@implementation UIPercentDrivenInteractiveTransition {
    __IsimTransitionContext *_ctx; id _tl; id<UIViewImplicitlyAnimating> _pa;
}
- (instancetype)init { if ((self = [super init])) { _completionSpeed = 1; _wantsInteractiveStart = YES; } return self; }
- (CGFloat)duration { return _ctx.duration; }
- (void)startInteractiveTransition:(id<UIViewControllerContextTransitioning>)c {
    _ctx = (__IsimTransitionContext *)c;
    id<UIViewControllerAnimatedTransitioning> a = _ctx.animator;
    if ([a respondsToSelector:@selector(interruptibleAnimatorForTransition:)]) {
        _pa = [a interruptibleAnimatorForTransition:c];
        [_pa pauseAnimation];
        _pa.fractionComplete = _percentComplete;
        [_ctx _isim_runAlongside];
        return;
    }
    _tl = isim_ui_timeline_create(fmax(_ctx.duration, 0.01), nil);
    isim_ui_timeline_capture_begin(_tl);
    [a animateTransition:c];
    [_ctx _isim_runAlongside];
    isim_ui_timeline_capture_end();
    isim_ui_timeline_set(_tl, _percentComplete * _ctx.duration, YES, 1);
}
- (void)updateInteractiveTransition:(CGFloat)p {
    _percentComplete = fmin(1, fmax(0, p));
    if (_pa) _pa.fractionComplete = _percentComplete;
    else if (_tl) isim_ui_timeline_set(_tl, _percentComplete * _ctx.duration, YES, 1);
    [_ctx updateInteractiveTransition:_percentComplete];
}
- (void)pauseInteractiveTransition {
    if (_pa) [_pa pauseAnimation];
    else if (_tl) isim_ui_timeline_set(_tl, isim_ui_timeline_time(_tl), YES, 1);
}
- (void)finishInteractiveTransition {
    [_ctx finishInteractiveTransition];
    CGFloat sp = _completionSpeed > 0 ? _completionSpeed : 1;
    if (_pa) { _pa.reversed = NO; [_pa continueAnimationWithTimingParameters:nil durationFactor:1 / sp]; }
    else if (_tl) isim_ui_timeline_set(_tl, isim_ui_timeline_time(_tl), NO, sp);
}
- (void)cancelInteractiveTransition {
    [_ctx cancelInteractiveTransition];
    CGFloat sp = _completionSpeed > 0 ? _completionSpeed : 1;
    if (_pa) { _pa.reversed = YES; [_pa continueAnimationWithTimingParameters:nil durationFactor:1 / sp]; }
    else if (_tl) isim_ui_timeline_set(_tl, isim_ui_timeline_time(_tl), NO, -sp);
}
@end

/* ================= UIViewController (UIPresentation) ================= */
@implementation UIViewController (UIPresentation)
- (UIModalTransitionStyle)modalTransitionStyle { return (UIModalTransitionStyle)[objc_getAssociatedObject(self, &kTransitionStyle) integerValue]; }
- (void)setModalTransitionStyle:(UIModalTransitionStyle)s { objc_setAssociatedObject(self, &kTransitionStyle, @(s), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (id<UIViewControllerTransitioningDelegate>)transitioningDelegate { return ((__IsimWeakBox *)objc_getAssociatedObject(self, &kTransitioningDelegate)).value; }
- (void)setTransitioningDelegate:(id<UIViewControllerTransitioningDelegate>)d {
    __IsimWeakBox *b = [__IsimWeakBox new]; b.value = d;
    objc_setAssociatedObject(self, &kTransitioningDelegate, b, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}
- (BOOL)definesPresentationContext { return [objc_getAssociatedObject(self, &kDefinesContext) boolValue]; }
- (void)setDefinesPresentationContext:(BOOL)d { objc_setAssociatedObject(self, &kDefinesContext, @(d), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (BOOL)providesPresentationContextTransitionStyle { return [objc_getAssociatedObject(self, &kProvidesContext) boolValue]; }
- (void)setProvidesPresentationContextTransitionStyle:(BOOL)d { objc_setAssociatedObject(self, &kProvidesContext, @(d), OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
- (CGSize)preferredContentSize { NSValue *v = objc_getAssociatedObject(self, &kPreferredSize); return v ? v.CGSizeValue : CGSizeZero; }
- (void)setPreferredContentSize:(CGSize)s {
    if (CGSizeEqualToSize(s, self.preferredContentSize)) return;
    objc_setAssociatedObject(self, &kPreferredSize, [NSValue valueWithCGSize:s], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self.parentViewController preferredContentSizeDidChangeForChildContentContainer:self];
    __IsimPresentation *p = objc_getAssociatedObject(self, &kPresentation);
    if (p) { [p.pc preferredContentSizeDidChangeForChildContentContainer:self]; [p.container setNeedsLayout]; }
}
- (void)preferredContentSizeDidChangeForChildContentContainer:(id)c {}
- (UIPresentationController *)presentationController {
    __IsimPresentation *p = objc_getAssociatedObject(self, &kPresentation);
    if (p.pc) return p.pc;
    UIModalPresentationStyle st = self.modalPresentationStyle;
    Class want = st == UIModalPresentationPopover ? [UIPopoverPresentationController class]
        : (st == UIModalPresentationAutomatic || st == UIModalPresentationPageSheet || st == UIModalPresentationFormSheet) ? [UISheetPresentationController class]
        : [UIPresentationController class];
    UIPresentationController *pc = objc_getAssociatedObject(self, &kPC);
    if (![pc isMemberOfClass:want]) {
        pc = [[want alloc] initWithPresentedViewController:self presentingViewController:nil];
        objc_setAssociatedObject(self, &kPC, pc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return pc;
}
- (UISheetPresentationController *)sheetPresentationController {
    UIModalPresentationStyle st = self.modalPresentationStyle;
    if (st != UIModalPresentationAutomatic && st != UIModalPresentationPageSheet && st != UIModalPresentationFormSheet) {
        __IsimPresentation *p = objc_getAssociatedObject(self, &kPresentation);
        return [p.pc isKindOfClass:[UISheetPresentationController class]] ? (UISheetPresentationController *)p.pc : nil;
    }
    UIPresentationController *pc = self.presentationController;
    return [pc isKindOfClass:[UISheetPresentationController class]] ? (UISheetPresentationController *)pc : nil;
}
- (UIPopoverPresentationController *)popoverPresentationController {
    if (self.modalPresentationStyle != UIModalPresentationPopover) return nil;
    UIPresentationController *pc = objc_getAssociatedObject(self, &kPC) ?: self.presentationController;
    return [pc isKindOfClass:[UIPopoverPresentationController class]] ? (UIPopoverPresentationController *)pc : nil;
}
- (BOOL)isBeingPresented { __IsimPresentation *p = objc_getAssociatedObject(self, &kPresentation); return p.presentingNow; }
- (BOOL)isBeingDismissed { __IsimPresentation *p = objc_getAssociatedObject(self, &kPresentation); return p.dismissing && p.container.superview != nil; }
- (id<UIViewControllerTransitionCoordinator>)transitionCoordinator {
    for (UIViewController *vc in @[self, self.presentedViewController ?: self]) {
        __IsimPresentation *p = objc_getAssociatedObject(vc, &kPresentation);
        if (p && (p.presentingNow || (p.dismissing && !p.context.completed))) return p.context;
    }
    return objc_getAssociatedObject(self, &kCoordinator);
}
- (void)showViewController:(UIViewController *)vc sender:(id)sender {
    UINavigationController *nav = [self isKindOfClass:[UINavigationController class]] ? (UINavigationController *)self : self.navigationController;
    if (nav) [nav pushViewController:vc animated:YES];
    else [self presentViewController:vc animated:YES completion:nil];
}
- (void)showDetailViewController:(UIViewController *)vc sender:(id)sender {
    UISplitViewController *split = self.splitViewController;
    if (split && split != self) [split showDetailViewController:vc sender:sender];
    else [self showViewController:vc sender:sender];
}
@end

