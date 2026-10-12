/* UIViewController members from the documentation sweep (#9) (ARC): layout margins and extended layout, content scroll
 * views, status bar and orientation lock children, child transitions, action targets, unwind lookups, zoom transition
 * options. Stored values are associated objects (the class's instance size must not change). Appearance forwarding
 * and viewIsAppearing: UIApplication.m. */
#import "UIKitPrivate.h"
#import <UIKit/UIViewControllerExtras.h>
#import <objc/runtime.h>

NSExceptionName const UIViewControllerHierarchyInconsistencyException = @"UIViewControllerHierarchyInconsistencyException";

static char k_respects, k_edges, k_opaque, k_scrolls, k_captures, k_focus, k_restores, k_tracking;
static NSNumber *num(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void set_num(id o, const void *k, NSNumber *n) { objc_setAssociatedObject(o, k, n, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@implementation UIViewController (UIViewControllerExtras)
- (BOOL)viewRespectsSystemMinimumLayoutMargins { NSNumber *n = num(self, &k_respects); return n ? n.boolValue : YES; }
- (void)setViewRespectsSystemMinimumLayoutMargins:(BOOL)b { set_num(self, &k_respects, @(b)); [self.viewIfLoaded setNeedsLayout]; }
/* iPhone 16 pt at the sides; regular width (iPad, large iPhones in landscape) 20 pt */
- (NSDirectionalEdgeInsets)systemMinimumLayoutMargins {
    CGFloat side = self.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassRegular ? 20 : 16;
    return NSDirectionalEdgeInsetsMake(0, side, 0, side);
}
- (void)viewLayoutMarginsDidChange {}
- (UIRectEdge)edgesForExtendedLayout { NSNumber *n = num(self, &k_edges); return n ? n.unsignedIntegerValue : UIRectEdgeAll; }
- (void)setEdgesForExtendedLayout:(UIRectEdge)e { set_num(self, &k_edges, @(e)); [self.viewIfLoaded.superview setNeedsLayout]; isim_ui_set_needs_layout(); }
- (BOOL)extendedLayoutIncludesOpaqueBars { return num(self, &k_opaque).boolValue; }
- (void)setExtendedLayoutIncludesOpaqueBars:(BOOL)b { set_num(self, &k_opaque, @(b)); isim_ui_set_needs_layout(); }
- (void)setContentScrollView:(UIScrollView *)sv forEdge:(NSDirectionalRectEdge)edge {
    NSMapTable *m = objc_getAssociatedObject(self, &k_scrolls);
    if (!m) { m = [NSMapTable strongToWeakObjectsMapTable]; objc_setAssociatedObject(self, &k_scrolls, m, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
    for (NSUInteger bit = 1; bit <= NSDirectionalRectEdgeTrailing; bit <<= 1)
        if (edge & bit) { if (sv) [m setObject:sv forKey:@(bit)]; else [m removeObjectForKey:@(bit)]; }
    isim_ui_set_needs_layout();
}
- (UIScrollView *)contentScrollViewForEdge:(NSDirectionalRectEdge)edge {
    NSMapTable *m = objc_getAssociatedObject(self, &k_scrolls);
    for (NSUInteger bit = 1; bit <= NSDirectionalRectEdgeTrailing; bit <<= 1) if ((edge & bit) && [m objectForKey:@(bit)]) return [m objectForKey:@(bit)];
    return nil;
}
- (UIViewController *)childViewControllerForStatusBarStyle { return nil; }
- (UIViewController *)childViewControllerForStatusBarHidden { return nil; }
- (UIViewController *)childViewControllerForInterfaceOrientationLock { return nil; }
- (BOOL)modalPresentationCapturesStatusBarAppearance { return num(self, &k_captures).boolValue; }
- (void)setModalPresentationCapturesStatusBarAppearance:(BOOL)b { set_num(self, &k_captures, @(b)); isim_ui_set_needs_display(); }
/* the from view leaves its superview, the to view takes its place (the animations block runs with the duration) */
- (void)transitionFromViewController:(UIViewController *)from toViewController:(UIViewController *)to duration:(NSTimeInterval)d
                             options:(UIViewAnimationOptions)o animations:(void (^)(void))animations completion:(void (^)(BOOL))completion {
    if (from.parentViewController != self || to.parentViewController != self)
        [NSException raise:UIViewControllerHierarchyInconsistencyException format:@"Children view controllers %@ and %@ must have a common parent view controller when calling -[UIViewController transitionFromViewController:toViewController:duration:options:animations:completion:]", from, to];
    UIView *fv = from.view, *host = fv.superview;
    UIView *tv = to.view;
    tv.frame = fv.frame;
    [host insertSubview:tv aboveSubview:fv];
    BOOL fwd = self.shouldAutomaticallyForwardAppearanceMethods && self.viewIfLoaded.window != nil;
    if (fwd) { [from beginAppearanceTransition:NO animated:d > 0]; [to beginAppearanceTransition:YES animated:d > 0]; }
    void (^done)(BOOL) = ^(BOOL finished) {
        [fv removeFromSuperview];
        if (fwd) { [from endAppearanceTransition]; [to endAppearanceTransition]; }
        if (completion) completion(finished);
    };
    if (d > 0 && animations) [UIView animateWithDuration:d delay:0 options:o animations:animations completion:done];
    else { if (animations) animations(); dispatch_async(dispatch_get_main_queue(), ^{ done(YES); }); }
}
- (UIViewController *)targetViewControllerForAction:(SEL)action sender:(id)sender {
    for (UIViewController *vc = self; vc; vc = vc.parentViewController ?: vc.presentingViewController)
        if ([vc canPerformAction:action withSender:sender] || [vc respondsToSelector:action]) return vc;
    return nil;
}
- (UIPresentationController *)activePresentationController { return self.presentingViewController ? self.presentationController : nil; }
- (UIViewController *)childViewControllerContainingSegueSource:(UIStoryboardUnwindSegueSource *)source {
    UIViewController *src = source.sourceViewController;
    for (UIViewController *c in self.childViewControllers)
        for (UIViewController *x = src; x; x = x.parentViewController ?: x.presentingViewController) if (x == c) return c;
    return nil;
}
- (UIViewController *)separateSecondaryViewControllerForSplitViewController:(UISplitViewController *)split { return nil; }
- (BOOL)disablesAutomaticKeyboardDismissal { return self.modalPresentationStyle == UIModalPresentationFormSheet; }
- (BOOL)performsActionsWhilePresentingModally { return NO; }
- (BOOL)restoresFocusAfterTransition { NSNumber *n = num(self, &k_restores); return n ? n.boolValue : YES; }
- (void)setRestoresFocusAfterTransition:(BOOL)b { set_num(self, &k_restores, @(b)); }
- (NSString *)focusGroupIdentifier { return objc_getAssociatedObject(self, &k_focus); }
- (void)setFocusGroupIdentifier:(NSString *)s { objc_setAssociatedObject(self, &k_focus, s, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (NSString *)interactionActivityTrackingBaseName { return objc_getAssociatedObject(self, &k_tracking); }
- (void)setInteractionActivityTrackingBaseName:(NSString *)s { objc_setAssociatedObject(self, &k_tracking, s, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(id)container {}
@end

/* the controller that decides the status bar: the top presented controller (one presented over part of the screen only
   if it captures the status bar), then the children it names */
UIViewController *isim_ui_status_bar_owner(UIViewController *root, BOOL hidden) {
    UIViewController *vc = root;
    for (UIViewController *p = root.presentedViewController; p; p = p.presentedViewController) {
        UIModalPresentationStyle s = p.modalPresentationStyle;
        BOOL partial = s == UIModalPresentationFormSheet || s == UIModalPresentationPopover || s == UIModalPresentationOverCurrentContext
                    || s == UIModalPresentationCurrentContext || s == UIModalPresentationCustom;
        if (!partial || p.modalPresentationCapturesStatusBarAppearance) vc = p;
    }
    for (UIViewController *c; vc && (c = hidden ? vc.childViewControllerForStatusBarHidden : vc.childViewControllerForStatusBarStyle); ) vc = c;
    return vc;
}

/* ---- zoom transition options ---- */
@implementation UIZoomTransitionAlignmentRectContext { UIView *_sourceView; UIViewController *_zoomed; }
- (UIView *)sourceView { return _sourceView; }
- (UIViewController *)zoomedViewController { return _zoomed; }
@end
@implementation UIZoomTransitionInteractionContext { CGPoint _location; CGVector _velocity; BOOL _willBegin; }
- (CGPoint)location { return _location; }
- (CGVector)velocity { return _velocity; }
- (BOOL)willBegin { return _willBegin; }
@end
UIZoomTransitionAlignmentRectContext *isim_ui_zoom_alignment_context(UIView *source, UIViewController *zoomed) {
    UIZoomTransitionAlignmentRectContext *c = [UIZoomTransitionAlignmentRectContext new];
    [c setValue:source forKey:@"_sourceView"]; [c setValue:zoomed forKey:@"_zoomed"];
    return c;
}
UIZoomTransitionInteractionContext *isim_ui_zoom_interaction_context(CGPoint location, CGVector velocity, BOOL willBegin) {
    UIZoomTransitionInteractionContext *c = [UIZoomTransitionInteractionContext new];
    [c setValue:[NSValue valueWithCGPoint:location] forKey:@"_location"];
    [c setValue:[NSValue valueWithCGVector:velocity] forKey:@"_velocity"];
    [c setValue:@(willBegin) forKey:@"_willBegin"];
    return c;
}
static char k_align, k_dismiss;
@implementation UIZoomTransitionOptions (UIViewControllerExtras)
- (CGRect (^)(UIZoomTransitionAlignmentRectContext *))alignmentRectProvider { return objc_getAssociatedObject(self, &k_align); }
- (void)setAlignmentRectProvider:(CGRect (^)(UIZoomTransitionAlignmentRectContext *))b { objc_setAssociatedObject(self, &k_align, b, OBJC_ASSOCIATION_COPY_NONATOMIC); }
- (BOOL (^)(UIZoomTransitionInteractionContext *))interactiveDismissShouldBegin { return objc_getAssociatedObject(self, &k_dismiss); }
- (void)setInteractiveDismissShouldBegin:(BOOL (^)(UIZoomTransitionInteractionContext *))b { objc_setAssociatedObject(self, &k_dismiss, b, OBJC_ASSOCIATION_COPY_NONATOMIC); }
@end
