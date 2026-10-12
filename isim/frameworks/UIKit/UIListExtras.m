/* Table and collection view members from the documentation sweep (#9): the section index collation, table rects
 * and index paths for areas, cell states, interactive movement of collection view items, update items, data source
 * translation. Stored outside the instances (associated objects): apps' subclasses keep their sizes. */
#import "UIKitPrivate.h"
#import <UIKit/UIListExtras.h>
#import <UIKit/UICollectionLayoutExtras.h>
#import <objc/runtime.h>
#import <objc/message.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

/* ================= UILocalizedIndexedCollation ================= */
@implementation UILocalizedIndexedCollation
+ (instancetype)currentCollation { static UILocalizedIndexedCollation *c; if (!c) c = [self new]; return c; }
- (NSArray<NSString *> *)sectionTitles {
    NSMutableArray *a = [NSMutableArray array];
    for (char ch = 'A'; ch <= 'Z'; ch++) [a addObject:[NSString stringWithFormat:@"%c", ch]];
    [a addObject:@"#"];
    return a;
}
- (NSArray<NSString *> *)sectionIndexTitles { return self.sectionTitles; }
- (NSInteger)sectionForSectionIndexTitleAtIndex:(NSInteger)i { return i; }
/* the first letter, without its accents, decides the section (others: #) */
- (NSInteger)sectionForObject:(id)object collationStringSelector:(SEL)selector {
    NSString *s = ((NSString *(*)(id, SEL))objc_msgSend)(object, selector);
    if (![s isKindOfClass:[NSString class]] || !s.length) return 26;
    NSString *first = [[[s substringToIndex:[s rangeOfComposedCharacterSequenceAtIndex:0].length] stringByFoldingWithOptions:NSDiacriticInsensitiveSearch locale:nil] uppercaseString];
    unichar c = first.length ? [first characterAtIndex:0] : '#';
    return c >= 'A' && c <= 'Z' ? c - 'A' : 26;
}
- (NSArray *)sortedArrayFromArray:(NSArray *)array collationStringSelector:(SEL)selector {
    return [array sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *x = ((NSString *(*)(id, SEL))objc_msgSend)(a, selector), *y = ((NSString *(*)(id, SEL))objc_msgSend)(b, selector);
        return [x ?: @"" localizedCaseInsensitiveCompare:y ?: @""];
    }];
}
@end

/* ================= UITableView ================= */
static char kFiller, kReadable, kNoSafeContent, kSepEffect, kSepRef, kFocus, kFocusEditing, kRemembers, kSelfSizing, kHugging;
@interface UITableView (IsimListPrivate)
- (CGFloat)_headerHeight:(NSInteger)s;
- (CGFloat)_footerHeight:(NSInteger)s;
@end
@implementation UITableView (UITableViewExtras)
- (CGFloat)fillerRowHeight { return [get(self, &kFiller) doubleValue]; }
- (void)setFillerRowHeight:(CGFloat)h { put(self, &kFiller, @(h)); isim_ui_set_needs_display(); }
- (BOOL)cellLayoutMarginsFollowReadableWidth { return [get(self, &kReadable) boolValue]; }
- (void)setCellLayoutMarginsFollowReadableWidth:(BOOL)b { put(self, &kReadable, @(b)); }
- (BOOL)insetsContentViewsToSafeArea { return ![get(self, &kNoSafeContent) boolValue]; }
- (void)setInsetsContentViewsToSafeArea:(BOOL)b { put(self, &kNoSafeContent, @(!b)); }
- (UIVisualEffect *)separatorEffect { return get(self, &kSepEffect); }
- (void)setSeparatorEffect:(UIVisualEffect *)e { put(self, &kSepEffect, e); }
- (UITableViewSeparatorInsetReference)separatorInsetReference { NSNumber *n = get(self, &kSepRef); return n ? n.integerValue : UITableViewSeparatorInsetFromAutomaticInsets; }
- (void)setSeparatorInsetReference:(UITableViewSeparatorInsetReference)r { put(self, &kSepRef, @(r)); isim_ui_set_needs_display(); }
- (NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect {
    NSMutableArray *out = [NSMutableArray array];
    for (NSInteger s = 0; s < self.numberOfSections; s++) {
        if (!CGRectIntersectsRect([self rectForSection:s], rect)) continue;
        for (NSInteger r = 0; r < [self numberOfRowsInSection:s]; r++) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:r inSection:s];
            if (CGRectIntersectsRect([self rectForRowAtIndexPath:ip], rect)) [out addObject:ip];
        }
    }
    return out.count ? out : nil;
}
- (CGRect)rectForHeaderInSection:(NSInteger)s {
    CGRect r = [self rectForSection:s];
    if (CGRectIsEmpty(r) && s >= self.numberOfSections) return CGRectZero;
    r.size.height = [self _headerHeight:s];
    return r;
}
- (CGRect)rectForFooterInSection:(NSInteger)s {
    CGRect r = [self rectForSection:s];
    if (CGRectIsEmpty(r) && s >= self.numberOfSections) return CGRectZero;
    CGFloat h = [self _footerHeight:s];
    return CGRectMake(r.origin.x, CGRectGetMaxY(r) - h, r.size.width, h);
}
- (void)scrollToNearestSelectedRowAtScrollPosition:(UITableViewScrollPosition)pos animated:(BOOL)animated {
    NSArray<NSIndexPath *> *sel = self.indexPathsForSelectedRows;
    if (!sel.count) return;
    /* the selected row nearest the middle of what shows */
    CGFloat mid = CGRectGetMidY(self.bounds), best = INFINITY; NSIndexPath *target = nil;
    for (NSIndexPath *ip in sel) { CGFloat d = fabs(CGRectGetMidY([self rectForRowAtIndexPath:ip]) - mid); if (d < best) { best = d; target = ip; } }
    [self scrollToRowAtIndexPath:target atScrollPosition:pos animated:animated];
}
- (BOOL)hasUncommittedUpdates { return NO; }
- (BOOL)hasActiveDrop { return NO; }
- (BOOL)allowsFocus { return [get(self, &kFocus) boolValue]; }
- (void)setAllowsFocus:(BOOL)b { put(self, &kFocus, @(b)); }
- (BOOL)allowsFocusDuringEditing { return [get(self, &kFocusEditing) boolValue]; }
- (void)setAllowsFocusDuringEditing:(BOOL)b { put(self, &kFocusEditing, @(b)); }
- (BOOL)remembersLastFocusedIndexPath { return [get(self, &kRemembers) boolValue]; }
- (void)setRemembersLastFocusedIndexPath:(BOOL)b { put(self, &kRemembers, @(b)); }
- (UITableViewSelfSizingInvalidation)selfSizingInvalidation { NSNumber *n = get(self, &kSelfSizing); return n ? n.integerValue : UITableViewSelfSizingInvalidationEnabled; }
- (void)setSelfSizingInvalidation:(UITableViewSelfSizingInvalidation)v { put(self, &kSelfSizing, @(v)); }
- (UITableViewContentHuggingElements)contentHuggingElements { return [get(self, &kHugging) unsignedIntegerValue]; }
- (void)setContentHuggingElements:(UITableViewContentHuggingElements)e { put(self, &kHugging, @(e)); }
@end

/* index paths as the data source sees them = as shown (isim applies updates at once) */
@implementation UITableView (UITableViewTranslating)
- (NSIndexPath *)presentationIndexPathForDataSourceIndexPath:(NSIndexPath *)ip { return ip; }
- (NSIndexPath *)dataSourceIndexPathForPresentationIndexPath:(NSIndexPath *)ip { return ip; }
- (NSInteger)presentationSectionIndexForDataSourceSectionIndex:(NSInteger)s { return s; }
- (NSInteger)dataSourceSectionIndexForPresentationSectionIndex:(NSInteger)s { return s; }
- (void)performUsingPresentationValues:(void (NS_NOESCAPE ^)(void))actions { actions(); }
@end

static char kMultiBackground, kEditingAccessory, kNoIndent, kFocusStyle, kWhileDragging;
@interface UITableViewCell (IsimListPrivate)
@property (nonatomic) CGFloat _isim_swipe;
@end
@implementation UITableViewCell (UITableViewCellExtras)
- (UIView *)multipleSelectionBackgroundView { return get(self, &kMultiBackground); }
- (void)setMultipleSelectionBackgroundView:(UIView *)v { put(self, &kMultiBackground, v); }
- (UIView *)editingAccessoryView { return get(self, &kEditingAccessory); }
- (void)setEditingAccessoryView:(UIView *)v {
    UIView *old = get(self, &kEditingAccessory);
    if (old != v) [old removeFromSuperview];
    put(self, &kEditingAccessory, v);
    [self setNeedsLayout];
}
- (BOOL)showingDeleteConfirmation { return self._isim_swipe < 0; }
- (BOOL)shouldIndentWhileEditing { return ![get(self, &kNoIndent) boolValue]; }
- (void)setShouldIndentWhileEditing:(BOOL)b { put(self, &kNoIndent, @(!b)); [self setNeedsLayout]; }
- (UITableViewCellFocusStyle)focusStyle { return [get(self, &kFocusStyle) integerValue]; }
- (void)setFocusStyle:(UITableViewCellFocusStyle)s { put(self, &kFocusStyle, @(s)); }
- (BOOL)userInteractionEnabledWhileDragging { return [get(self, &kWhileDragging) boolValue]; }
- (void)setUserInteractionEnabledWhileDragging:(BOOL)b { put(self, &kWhileDragging, @(b)); }
- (void)willTransitionToState:(UITableViewCellStateMask)state {}
- (void)didTransitionToState:(UITableViewCellStateMask)state {}
- (void)dragStateDidChange:(UITableViewCellDragState)dragState {}
@end

/* ================= UICollectionView ================= */
static char kMoving, kCadence, kCVFocus, kCVFocusEditing, kCVRemembers, kCVSelfSizing;
/* the item being moved interactively: its index path, the target index path, the position */
@interface __IsimMovement : NSObject
@property (nonatomic, strong) NSIndexPath *from, *target;
@property (nonatomic) CGPoint position;
@end
@implementation __IsimMovement @end

@implementation UICollectionView (UICollectionViewExtras)
- (BOOL)beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)ip {
    id<UICollectionViewDataSource> ds = self.dataSource;
    if (!ip || ![ds respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)]) return NO;
    if ([ds respondsToSelector:@selector(collectionView:canMoveItemAtIndexPath:)] && ![ds collectionView:self canMoveItemAtIndexPath:ip]) return NO;
    __IsimMovement *m = [__IsimMovement new]; m.from = m.target = ip;
    m.position = [self layoutAttributesForItemAtIndexPath:ip].center;
    put(self, &kMoving, m);
    UICollectionViewCell *c = [self cellForItemAtIndexPath:ip];
    [c dragStateDidChange:UICollectionViewCellDragStateLifting];
    [c dragStateDidChange:UICollectionViewCellDragStateDragging];
    NSLog(@"isim: interactive movement of %ld-%ld began", (long)ip.section, (long)ip.item);
    [self setNeedsLayout]; [self layoutIfNeeded];
    return YES;
}
- (void)updateInteractiveMovementTargetPosition:(CGPoint)p {
    __IsimMovement *m = get(self, &kMoving);
    if (!m) return;
    CGPoint was = m.position;
    m.position = p;
    UICollectionViewLayout *l = self.collectionViewLayout;
    NSIndexPath *t = [l targetIndexPathForInteractivelyMovingItem:m.target withPosition:p];
    if (t && t.section < self.numberOfSections && t.item < [self numberOfItemsInSection:t.section]) m.target = t;
    UICollectionViewLayoutInvalidationContext *ctx = [l invalidationContextForInteractivelyMovingItems:@[m.target] withTargetPosition:p previousIndexPaths:@[m.from] previousPosition:was];
    [l invalidateLayoutWithContext:ctx];
    [self setNeedsLayout]; [self layoutIfNeeded];
}
- (void)_isim_endMovement:(BOOL)commit {
    __IsimMovement *m = get(self, &kMoving);
    if (!m) return;
    put(self, &kMoving, nil);
    UICollectionViewLayout *l = self.collectionViewLayout;
    [l invalidateLayoutWithContext:[l invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:@[commit ? m.target : m.from]
                                                                                         previousIndexPaths:@[m.from] movementCancelled:!commit]];
    [[self cellForItemAtIndexPath:m.from] dragStateDidChange:UICollectionViewCellDragStateNone];
    NSLog(@"isim: interactive movement %@ at %ld-%ld", commit ? @"ended" : @"cancelled", (long)(commit ? m.target : m.from).section, (long)(commit ? m.target : m.from).item);
    if (commit && ![m.target isEqual:m.from]) [self _isim_interactiveMoveFrom:m.from to:m.target];
    else [UIView animateWithDuration:0.25 animations:^{ [self setNeedsLayout]; [self layoutIfNeeded]; }];
}
- (void)endInteractiveMovement { [self _isim_endMovement:YES]; }
- (void)cancelInteractiveMovement { [self _isim_endMovement:NO]; }
- (BOOL)hasActiveDrop { return NO; }
- (BOOL)hasUncommittedUpdates { return NO; }
- (UICollectionViewReorderingCadence)reorderingCadence { return [get(self, &kCadence) integerValue]; }
- (void)setReorderingCadence:(UICollectionViewReorderingCadence)c { put(self, &kCadence, @(c)); }
- (NSArray<NSIndexPath *> *)indexPathsForVisibleSupplementaryElementsOfKind:(NSString *)kind {
    NSMutableArray *out = [NSMutableArray array];
    NSDictionary *supps = [self _isim_supplementaryViews];
    for (NSString *key in supps) {
        NSArray *parts = [key componentsSeparatedByString:@"|"];
        if (parts.count == 3 && [parts[0] isEqualToString:kind] && !((UIView *)supps[key]).hidden)
            [out addObject:[NSIndexPath indexPathForItem:[parts[2] integerValue] inSection:[parts[1] integerValue]]];
    }
    return [out sortedArrayUsingSelector:@selector(compare:)];
}
- (NSIndexPath *)indexPathForSupplementaryView:(UICollectionReusableView *)v {
    NSDictionary *supps = [self _isim_supplementaryViews];
    for (NSString *key in supps) if (supps[key] == v) {
        NSArray *parts = [key componentsSeparatedByString:@"|"];
        if (parts.count == 3) return [NSIndexPath indexPathForItem:[parts[2] integerValue] inSection:[parts[1] integerValue]];
    }
    return nil;
}
- (BOOL)allowsFocus { return [get(self, &kCVFocus) boolValue]; }
- (void)setAllowsFocus:(BOOL)b { put(self, &kCVFocus, @(b)); }
- (BOOL)allowsFocusDuringEditing { return [get(self, &kCVFocusEditing) boolValue]; }
- (void)setAllowsFocusDuringEditing:(BOOL)b { put(self, &kCVFocusEditing, @(b)); }
- (BOOL)remembersLastFocusedIndexPath { return [get(self, &kCVRemembers) boolValue]; }
- (void)setRemembersLastFocusedIndexPath:(BOOL)b { put(self, &kCVRemembers, @(b)); }
- (UICollectionViewSelfSizingInvalidation)selfSizingInvalidation { NSNumber *n = get(self, &kCVSelfSizing); return n ? n.integerValue : UICollectionViewSelfSizingInvalidationEnabled; }
- (void)setSelfSizingInvalidation:(UICollectionViewSelfSizingInvalidation)v { put(self, &kCVSelfSizing, @(v)); }
- (NSIndexPath *)presentationIndexPathForDataSourceIndexPath:(NSIndexPath *)ip { return ip; }
- (NSIndexPath *)dataSourceIndexPathForPresentationIndexPath:(NSIndexPath *)ip { return ip; }
- (NSInteger)presentationSectionIndexForDataSourceSectionIndex:(NSInteger)s { return s; }
- (NSInteger)dataSourceSectionIndexForPresentationSectionIndex:(NSInteger)s { return s; }
- (void)performUsingPresentationValues:(void (NS_NOESCAPE ^)(void))actions { actions(); }
@end

/* the moving item follows the finger above the others (UICollectionView.m, after placing a cell) */
void isim_ui_collection_place_moving(UICollectionView *cv, UICollectionViewCell *c, NSIndexPath *ip) {
    __IsimMovement *m = get(cv, &kMoving);
    if (!m || ![m.from isEqual:ip]) return;
    UICollectionViewLayoutAttributes *a = [cv.collectionViewLayout layoutAttributesForInteractivelyMovingItemAtIndexPath:ip withTargetPosition:m.position];
    [UIView performWithoutAnimation:^{ c.center = a.center; c.transform = a.transform; c.alpha = a.alpha; }];
    [c.superview bringSubviewToFront:c];
}

/* ================= UICollectionViewController ================= */
static char kInstallsMove, kLayoutToLayout, kMovePress;
@interface __IsimMovePress : NSObject
@property (nonatomic, weak) UICollectionView *collectionView;
- (void)pressed:(UILongPressGestureRecognizer *)g;
@end
@implementation __IsimMovePress
- (void)pressed:(UILongPressGestureRecognizer *)g {
    UICollectionView *cv = self.collectionView;
    CGPoint p = [g locationInView:cv];
    switch (g.state) {
    case UIGestureRecognizerStateBegan: {
        NSIndexPath *ip = [cv indexPathForItemAtPoint:p];
        if (!ip || ![cv beginInteractiveMovementForItemAtIndexPath:ip]) { g.enabled = NO; g.enabled = YES; }
        break; }
    case UIGestureRecognizerStateChanged: [cv updateInteractiveMovementTargetPosition:p]; break;
    case UIGestureRecognizerStateEnded: [cv endInteractiveMovement]; break;
    default: [cv cancelInteractiveMovement]; break;
    }
}
@end
@implementation UICollectionViewController (UICollectionViewControllerExtras)
- (BOOL)installsStandardGestureForInteractiveMovement { NSNumber *n = get(self, &kInstallsMove); return n ? n.boolValue : YES; }
- (void)setInstallsStandardGestureForInteractiveMovement:(BOOL)b { put(self, &kInstallsMove, @(b)); if (self.isViewLoaded) isim_ui_collection_controller_movement(self); }
- (BOOL)useLayoutToLayoutNavigationTransitions { return [get(self, &kLayoutToLayout) boolValue]; }
- (void)setUseLayoutToLayoutNavigationTransitions:(BOOL)b { put(self, &kLayoutToLayout, @(b)); }
@end
/* a long press moves items when the data source moves them (UICollectionView.m, when the controller's view loads) */
void isim_ui_collection_controller_movement(UICollectionViewController *vc) {
    UICollectionView *cv = vc.collectionView;
    UILongPressGestureRecognizer *g = get(vc, &kMovePress);
    BOOL want = vc.installsStandardGestureForInteractiveMovement && [cv.dataSource respondsToSelector:@selector(collectionView:moveItemAtIndexPath:toIndexPath:)];
    if (!want) { [g.view removeGestureRecognizer:g]; put(vc, &kMovePress, nil); return; }
    if (g && g.view == cv) return;
    __IsimMovePress *t = [__IsimMovePress new]; t.collectionView = cv;
    g = [[UILongPressGestureRecognizer alloc] initWithTarget:t action:@selector(pressed:)];
    put(g, &kMovePress, t);                       /* (the recognizer keeps its target) */
    [cv addGestureRecognizer:g];
    put(vc, &kMovePress, g);
}

/* ================= reusable views ================= */
@implementation UICollectionReusableView (UICollectionReusableViewExtras)
- (void)willTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout {}
- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout {}
@end
@implementation UICollectionViewCell (UICollectionViewCellExtras)
- (void)dragStateDidChange:(UICollectionViewCellDragState)dragState {}
@end

/* ================= update items ================= */
@implementation UICollectionViewUpdateItem
- (instancetype)initWithIsimAction:(UICollectionUpdateAction)action before:(NSIndexPath *)before after:(NSIndexPath *)after {
    if ((self = [super init])) { _updateAction = action; _indexPathBeforeUpdate = before; _indexPathAfterUpdate = after; }
    return self;
}
- (NSString *)description { return [NSString stringWithFormat:@"<UICollectionViewUpdateItem %ld %@ -> %@>", (long)_updateAction, _indexPathBeforeUpdate, _indexPathAfterUpdate]; }
@end
