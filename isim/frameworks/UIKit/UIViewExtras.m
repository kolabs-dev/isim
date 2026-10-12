/* UIView members from the documentation sweep (#9): the update constraints pass, layout margins (preserving the
 * superview's, insetting from the safe area), alignment rects, baseline views, constraints affecting layout,
 * content size category limits, system and repeated animations. Stored outside the instances (associated objects):
 * apps' subclasses keep their sizes. */
#import "UIKitPrivate.h"
#import <UIKit/UIViewExtras.h>
#import <objc/runtime.h>

static char kPreserves, kNoSafeAreaMargins, kFocusPriority, kMinCategory, kMaxCategory, kIgnoresInvert;
static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

/* ---- the update constraints pass ---- */
static NSHashTable<UIView *> *needs_update(void) {
    static NSHashTable *t;
    if (!t) t = [NSHashTable weakObjectsHashTable];
    return t;
}
void isim_ui_mark_needs_update_constraints(UIView *v) {
    if (!v) return;
    [needs_update() addObject:v];
    isim_ui_constraints_changed();
}
/* a class that overrides updateConstraints (or a controller that overrides updateViewConstraints) gets the pass
   when its view first enters a window, like UIKit's first constraint pass */
static BOOL overrides(Class c, Class base, SEL sel) { return c != base && class_getMethodImplementation(c, sel) != class_getMethodImplementation(base, sel); }
void isim_ui_view_entered_window(UIView *v) {
    UIViewController *vc = v._isim_viewController;
    if (overrides(v.class, [UIView class], @selector(updateConstraints)) || [v.class requiresConstraintBasedLayout]
        || (vc && overrides(vc.class, [UIViewController class], @selector(updateViewConstraints))))
        isim_ui_mark_needs_update_constraints(v);
}
static int depth_of(UIView *v) { int d = 0; for (UIView *s = v.superview; s; s = s.superview) d++; return d; }
/* deepest first (subviews before their superviews, as in UIKit's bottom-up pass); a view controller's root view
   asks its controller (whose default updateViewConstraints sends the view updateConstraints) */
static void run_updates(NSArray<UIView *> *views) {
    NSArray *sorted = [views sortedArrayUsingComparator:^NSComparisonResult(UIView *a, UIView *b) {
        int da = depth_of(a), db = depth_of(b); return da > db ? NSOrderedAscending : da < db ? NSOrderedDescending : NSOrderedSame;
    }];
    for (UIView *v in sorted) {
        [needs_update() removeObject:v];
        UIViewController *vc = v._isim_viewController;
        if (vc) [vc updateViewConstraints]; else [v updateConstraints];
    }
}
void isim_ui_update_constraints_pass(void) {
    for (int round = 0; round < 4; round++) {                 /* (an update may ask for another) */
        NSMutableArray *views = [NSMutableArray array];
        for (UIView *v in needs_update()) if (v.window || [v isKindOfClass:[UIWindow class]]) [views addObject:v];
        if (!views.count) return;
        run_updates(views);
    }
}
void isim_ui_update_constraints_in(UIView *root) {
    NSMutableArray *views = [NSMutableArray array];
    for (UIView *v in needs_update()) if (v == root || [v isDescendantOfView:root]) [views addObject:v];
    if (views.count) run_updates(views);
}

/* ---- layout margins ---- */
/* the margins constraints and the margins guide use: the view's own, at least the part of the superview's it
   overlaps when it preserves them */
UIEdgeInsets isim_ui_effective_margins(UIView *v) {
    UIEdgeInsets m = v.layoutMargins;
    UIView *sup = v.superview;
    if (!sup || ![get(v, &kPreserves) boolValue]) return m;
    UIEdgeInsets sm = isim_ui_effective_margins(sup);
    CGRect f = v.frame; CGSize s = sup.bounds.size;
    m.left = fmax(m.left, sm.left - CGRectGetMinX(f));
    m.right = fmax(m.right, sm.right - (s.width - CGRectGetMaxX(f)));
    m.top = fmax(m.top, sm.top - CGRectGetMinY(f));
    m.bottom = fmax(m.bottom, sm.bottom - (s.height - CGRectGetMaxY(f)));
    return m;
}
CGRect isim_ui_margins_rect(UIView *v) {
    CGRect r = v.insetsLayoutMarginsFromSafeArea ? UIEdgeInsetsInsetRect(v.bounds, v.safeAreaInsets) : v.bounds;
    return UIEdgeInsetsInsetRect(r, isim_ui_effective_margins(v));
}
UIEdgeInsets isim_ui_alignment_insets(id item) {
    if (![item isKindOfClass:[UIView class]]) return UIEdgeInsetsZero;
    static IMP base;
    if (!base) base = class_getMethodImplementation([UIView class], @selector(alignmentRectInsets));
    if (class_getMethodImplementation([item class], @selector(alignmentRectInsets)) == base) return UIEdgeInsetsZero;   /* (the common case, fast) */
    return [(UIView *)item alignmentRectInsets];
}

/* ---- content size category limits ---- */
UITraitCollection *isim_ui_clamp_content_size(UIView *v, UITraitCollection *t) {
    NSString *lo = get(v, &kMinCategory), *hi = get(v, &kMaxCategory);
    if (!lo && !hi) return t;
    UIContentSizeCategory c = t.preferredContentSizeCategory, want = c;
    if ([c isEqualToString:UIContentSizeCategoryUnspecified]) return t;
    if (lo && UIContentSizeCategoryCompareToCategory(want, lo) == NSOrderedAscending) want = lo;
    if (hi && UIContentSizeCategoryCompareToCategory(want, hi) == NSOrderedDescending) want = hi;
    if ([want isEqualToString:c]) return t;
    return [t traitCollectionByModifyingTraits:^(id<UIMutableTraits> m) { m.preferredContentSizeCategory = want; }];
}

@implementation UIView (UIViewExtras)
- (BOOL)preservesSuperviewLayoutMargins { return [get(self, &kPreserves) boolValue]; }
- (void)setPreservesSuperviewLayoutMargins:(BOOL)p { put(self, &kPreserves, @(p)); isim_ui_constraints_changed(); [self setNeedsLayout]; }
- (BOOL)insetsLayoutMarginsFromSafeArea { return ![get(self, &kNoSafeAreaMargins) boolValue]; }
- (void)setInsetsLayoutMarginsFromSafeArea:(BOOL)i { put(self, &kNoSafeAreaMargins, @(!i)); isim_ui_constraints_changed(); [self setNeedsLayout]; }
- (void)layoutMarginsDidChange {}
- (UIEdgeInsets)alignmentRectInsets { return UIEdgeInsetsZero; }
- (CGRect)alignmentRectForFrame:(CGRect)frame { return UIEdgeInsetsInsetRect(frame, self.alignmentRectInsets); }
- (CGRect)frameForAlignmentRect:(CGRect)r {
    UIEdgeInsets i = self.alignmentRectInsets;
    return CGRectMake(r.origin.x - i.left, r.origin.y - i.top, r.size.width + i.left + i.right, r.size.height + i.top + i.bottom);
}
- (UIView *)viewForFirstBaselineLayout { return self; }
- (UIView *)viewForLastBaselineLayout { return self; }
- (BOOL)needsUpdateConstraints { return [needs_update() containsObject:self]; }
+ (BOOL)requiresConstraintBasedLayout { return NO; }
/* the active constraints that involve the view in that axis */
- (NSArray<NSLayoutConstraint *> *)constraintsAffectingLayoutForAxis:(UILayoutConstraintAxis)axis {
    NSMutableArray *out = [NSMutableArray array];
    BOOL (^horizontal)(NSLayoutAttribute) = ^BOOL(NSLayoutAttribute a) {
        switch (a) {
        case NSLayoutAttributeLeft: case NSLayoutAttributeRight: case NSLayoutAttributeLeading: case NSLayoutAttributeTrailing:
        case NSLayoutAttributeWidth: case NSLayoutAttributeCenterX: case NSLayoutAttributeLeftMargin: case NSLayoutAttributeRightMargin:
        case NSLayoutAttributeLeadingMargin: case NSLayoutAttributeTrailingMargin: case NSLayoutAttributeCenterXWithinMargins: return YES;
        default: return NO;
        }
    };
    for (NSLayoutConstraint *c in [NSLayoutConstraint _isim_active]) {
        if (c.firstItem != self && c.secondItem != self) continue;
        NSLayoutAttribute a = c.firstItem == self ? c.firstAttribute : c.secondAttribute;
        if (horizontal(a) == (axis == UILayoutConstraintAxisHorizontal)) [out addObject:c];
    }
    return out;
}
- (BOOL)hasAmbiguousLayout { return NO; }
- (void)exerciseAmbiguityInLayout {}
- (BOOL)canBecomeFocused { return NO; }
- (UIFocusGroupPriority)focusGroupPriority { return [get(self, &kFocusPriority) integerValue]; }
- (void)setFocusGroupPriority:(UIFocusGroupPriority)p { put(self, &kFocusPriority, @(p)); }
- (UIContentSizeCategory)minimumContentSizeCategory { return get(self, &kMinCategory); }
- (void)setMinimumContentSizeCategory:(UIContentSizeCategory)c { put(self, &kMinCategory, [c copy]); isim_ui_traits_invalidate(self); isim_ui_set_needs_layout(); }
- (UIContentSizeCategory)maximumContentSizeCategory { return get(self, &kMaxCategory); }
- (void)setMaximumContentSizeCategory:(UIContentSizeCategory)c { put(self, &kMaxCategory, [c copy]); isim_ui_traits_invalidate(self); isim_ui_set_needs_layout(); }
- (NSString *)appliedContentSizeCategoryLimitsDescription {
    NSMutableArray *parts = [NSMutableArray array];
    for (UIView *v = self; v; v = v.superview) {
        NSString *lo = get(v, &kMinCategory), *hi = get(v, &kMaxCategory);
        if (lo || hi) [parts addObject:[NSString stringWithFormat:@"<%@: %p> minimum %@, maximum %@", v.class, v, lo ?: @"none", hi ?: @"none"]];
    }
    return parts.count ? [parts componentsJoinedByString:@"\n"] : @"No content size category limits";
}
- (BOOL)accessibilityIgnoresInvertColors { return [get(self, &kIgnoresInvert) boolValue]; }
- (void)setAccessibilityIgnoresInvertColors:(BOOL)i { put(self, &kIgnoresInvert, @(i)); }
/* delete: the views shrink and fade (with the parallel animations), then leave their superviews */
+ (void)performSystemAnimation:(UISystemAnimation)animation onViews:(NSArray<UIView *> *)views options:(UIViewAnimationOptions)options
                    animations:(void (^)(void))parallel completion:(void (^)(BOOL))completion {
    NSArray *vs = [views copy];
    [UIView animateWithDuration:0.3 delay:0 options:options animations:^{
        for (UIView *v in vs) { v.alpha = 0; v.transform = CGAffineTransformMakeScale(0.75, 0.75); }
        if (parallel) parallel();
    } completion:^(BOOL finished) {
        for (UIView *v in vs) { [v removeFromSuperview]; v.alpha = 1; v.transform = CGAffineTransformIdentity; }
        NSLog(@"isim: system animation delete removed %lu view(s)", (unsigned long)vs.count);
        if (completion) completion(finished);
    }];
}
/* inside an animation block: these animations run count times (autoreversing ones go back and forth) */
+ (void)modifyAnimationsWithRepeatCount:(CGFloat)count autoreverses:(BOOL)autoreverses animations:(void (NS_NOESCAPE ^)(void))animations {
    NSTimeInterval d = [UIView inheritedAnimationDuration];
    if (d <= 0 || count <= 0) { animations(); return; }
    void (^block)(void) = [animations copy];
    [UIView _isim_animateWithDuration:d delay:0 curve:0 controlPoints:CGRectZero damping:1 velocity:0 plays:(NSInteger)ceil(count)
                          autoreverse:autoreverses animations:block completion:nil];
}
@end

