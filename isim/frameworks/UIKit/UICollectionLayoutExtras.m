/* Collection view layout members from the documentation sweep (#9): anchored supplementary items (badges), the
 * orthogonal scrolling properties, content insets references, invalidation contexts, the layout's update, appearance,
 * interactive movement and direction hooks, flow layout section inset references. Stored outside the instances of the
 * existing classes (associated objects). Hooks in UICollectionView.m. */
#import "UIKitPrivate.h"
#import <UIKit/UICollectionLayoutExtras.h>
#import <objc/runtime.h>

static id get(id o, const void *k) { return objc_getAssociatedObject(o, k); }
static void put(id o, const void *k, id v) { objc_setAssociatedObject(o, k, v, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }

@interface NSCollectionLayoutItem (IsimLayoutPrivate)
- (void)_isim_setLayoutSize:(NSCollectionLayoutSize *)s;
- (CGFloat)_isim_resolveW:(CGFloat)w H:(CGFloat)h;
@end
@interface NSCollectionLayoutSupplementaryItem (IsimLayoutPrivate)
- (void)_isim_setKind:(NSString *)k;
@end
@interface NSCollectionLayoutDimension (IsimLayoutPrivate)
- (CGFloat)_isim_resolveW:(CGFloat)w H:(CGFloat)h;
- (int)_isim_kind;
@end

/* ================= anchors ================= */
@implementation NSCollectionLayoutAnchor
+ (instancetype)_isim_edges:(NSDirectionalRectEdge)e offset:(CGPoint)o fractional:(BOOL)f {
    NSCollectionLayoutAnchor *a = [super new]; a->_edges = e; a->_offset = o; a->_isFractionalOffset = f; a->_isAbsoluteOffset = !f; return a;
}
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)e { return [self _isim_edges:e offset:CGPointZero fractional:NO]; }
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)e absoluteOffset:(CGPoint)o { return [self _isim_edges:e offset:o fractional:NO]; }
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)e fractionalOffset:(CGPoint)o { return [self _isim_edges:e offset:o fractional:YES]; }
- (id)copyWithZone:(NSZone *)z { return self; }
/* the anchor's point in a rect (an axis without an edge: its middle), offset */
- (CGPoint)_isim_pointIn:(CGRect)r size:(CGSize)supp {
    NSDirectionalRectEdge e = _edges;
    CGFloat x = (e & NSDirectionalRectEdgeLeading) ? CGRectGetMinX(r) : (e & NSDirectionalRectEdgeTrailing) ? CGRectGetMaxX(r) : CGRectGetMidX(r);
    CGFloat y = (e & NSDirectionalRectEdgeTop) ? CGRectGetMinY(r) : (e & NSDirectionalRectEdgeBottom) ? CGRectGetMaxY(r) : CGRectGetMidY(r);
    return _isFractionalOffset ? CGPointMake(x + _offset.x * supp.width, y + _offset.y * supp.height) : CGPointMake(x + _offset.x, y + _offset.y);
}
@end

static char kContainerAnchor, kItemAnchor, kSupplementaryItems;
static id make_anchored(Class cls, NSCollectionLayoutSize *size, NSString *kind, NSCollectionLayoutAnchor *container, NSCollectionLayoutAnchor *_Nullable item) {
    NSCollectionLayoutSupplementaryItem *s = [cls itemWithLayoutSize:size];
    [s _isim_setKind:kind];
    put(s, &kContainerAnchor, container); put(s, &kItemAnchor, item);
    return s;
}
@implementation NSCollectionLayoutSupplementaryItem (NSCollectionLayoutAnchoring)
+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)kind containerAnchor:(NSCollectionLayoutAnchor *)container {
    return make_anchored(self, size, kind, container, nil);
}
+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)size elementKind:(NSString *)kind containerAnchor:(NSCollectionLayoutAnchor *)container
                                     itemAnchor:(NSCollectionLayoutAnchor *)item {
    return make_anchored(self, size, kind, container, item);
}
- (NSCollectionLayoutAnchor *)containerAnchor { return get(self, &kContainerAnchor); }
- (NSCollectionLayoutAnchor *)itemAnchor { return get(self, &kItemAnchor); }
@end
@implementation NSCollectionLayoutItem (NSCollectionLayoutSupplementaryItems)
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)size supplementaryItems:(NSArray<NSCollectionLayoutSupplementaryItem *> *)items {
    NSCollectionLayoutItem *i = [self itemWithLayoutSize:size];
    put(i, &kSupplementaryItems, [items copy]);
    return i;
}
- (NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems { return get(self, &kSupplementaryItems) ?: @[]; }
@end
@implementation NSCollectionLayoutGroup (NSCollectionLayoutSupplementaryItems)
- (NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems { return get(self, &kSupplementaryItems) ?: @[]; }
- (void)setSupplementaryItems:(NSArray<NSCollectionLayoutSupplementaryItem *> *)items { put(self, &kSupplementaryItems, [items copy]); }
@end
/* an item's (or group's) supplementary items, placed by their anchors on its frame (the compositional layout) */
void isim_ui_add_item_supplementaries(NSCollectionLayoutItem *item, CGRect frame, NSIndexPath *ip, Class cls, NSMutableArray *out) {
    NSArray<NSCollectionLayoutSupplementaryItem *> *items = get(item, &kSupplementaryItems);
    for (NSCollectionLayoutSupplementaryItem *s in items) {
        CGFloat w = [(id)s.layoutSize.widthDimension _isim_resolveW:frame.size.width H:frame.size.height];
        CGFloat h = [(id)s.layoutSize.heightDimension _isim_resolveW:frame.size.width H:frame.size.height];
        NSCollectionLayoutAnchor *ca = s.containerAnchor ?: [NSCollectionLayoutAnchor layoutAnchorWithEdges:NSDirectionalRectEdgeTop | NSDirectionalRectEdgeTrailing];
        NSCollectionLayoutAnchor *ia = s.itemAnchor ?: [NSCollectionLayoutAnchor layoutAnchorWithEdges:ca.edges];
        CGPoint cp = [ca _isim_pointIn:frame size:CGSizeMake(w, h)];
        CGPoint sp = s.itemAnchor ? [ia _isim_pointIn:CGRectMake(0, 0, w, h) size:CGSizeMake(w, h)] : [[NSCollectionLayoutAnchor layoutAnchorWithEdges:ca.edges] _isim_pointIn:CGRectMake(0, 0, w, h) size:CGSizeZero];
        UICollectionViewLayoutAttributes *a = [cls layoutAttributesForSupplementaryViewOfKind:s.elementKind withIndexPath:ip];
        a.frame = CGRectMake(cp.x - sp.x, cp.y - sp.y, w, h);
        a.zIndex = s.zIndex ?: 1;
        [out addObject:a];
    }
}
/* the supplementary attributes made among a section's cells go with its supplementaries */
void isim_ui_split_supplementaries(NSMutableArray *cells, NSMutableArray *supps) {
    NSIndexSet *moved = [cells indexesOfObjectsPassingTest:^BOOL(UICollectionViewLayoutAttributes *a, NSUInteger i, BOOL *stop) {
        return a.representedElementCategory == UICollectionElementCategorySupplementaryView; }];
    if (!moved.count) return;
    [supps addObjectsFromArray:[cells objectsAtIndexes:moved]];
    [cells removeObjectsAtIndexes:moved];
}
@implementation NSCollectionLayoutDimension (NSCollectionLayoutUniform)
- (BOOL)isUniformAcrossSiblings { return [self _isim_kind] == 4; }
@end

/* ================= sections ================= */
const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateAutomatic = 0;
const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateNormal = 0.998;
const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateFast = 0.99;
@implementation UICollectionLayoutSectionOrthogonalScrollingProperties
- (id)copyWithZone:(NSZone *)z { UICollectionLayoutSectionOrthogonalScrollingProperties *p = [[self class] new]; p.decelerationRate = _decelerationRate; p.bounce = _bounce; return p; }
@end
static char kOrtho, kInsetsRef, kSuppInsetsRef, kConfigInsetsRef;
@implementation NSCollectionLayoutSection (NSCollectionLayoutSectionExtras)
- (UICollectionLayoutSectionOrthogonalScrollingProperties *)orthogonalScrollingProperties {
    UICollectionLayoutSectionOrthogonalScrollingProperties *p = get(self, &kOrtho);
    if (!p) { p = [UICollectionLayoutSectionOrthogonalScrollingProperties new]; put(self, &kOrtho, p); }
    return p;
}
- (UIContentInsetsReference)contentInsetsReference { return [get(self, &kInsetsRef) integerValue]; }
- (void)setContentInsetsReference:(UIContentInsetsReference)r { put(self, &kInsetsRef, @(r)); }
- (UIContentInsetsReference)supplementaryContentInsetsReference { return [get(self, &kSuppInsetsRef) integerValue]; }
- (void)setSupplementaryContentInsetsReference:(UIContentInsetsReference)r { put(self, &kSuppInsetsRef, @(r)); }
@end
@implementation UICollectionViewCompositionalLayoutConfiguration (UICollectionViewCompositionalLayoutConfigurationExtras)
- (UIContentInsetsReference)contentInsetsReference { return [get(self, &kConfigInsetsRef) integerValue]; }
- (void)setContentInsetsReference:(UIContentInsetsReference)r { put(self, &kConfigInsetsRef, @(r)); }
@end
/* the room a content insets reference adds to a section's leading / trailing insets (the layout already keeps out of
   the adjusted content insets: automatic, none and safe area add nothing) */
NSDirectionalEdgeInsets isim_ui_reference_insets(NSDirectionalEdgeInsets in, NSCollectionLayoutSection *sec, UICollectionViewCompositionalLayoutConfiguration *config, UICollectionView *cv) {
    UIContentInsetsReference r = sec.contentInsetsReference ?: config.contentInsetsReference;
    UIEdgeInsets ai = cv.adjustedContentInset; CGFloat l = 0, t = 0;
    if (r == UIContentInsetsReferenceLayoutMargins) { UIEdgeInsets m = cv.layoutMargins; l = m.left - ai.left; t = m.right - ai.right; }
    else if (r == UIContentInsetsReferenceReadableContent) { CGRect g = cv.readableContentGuide.layoutFrame; l = CGRectGetMinX(g) - ai.left; t = cv.bounds.size.width - CGRectGetMaxX(g) - ai.right; }
    BOOL rtl = cv.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    in.leading += fmax(0, rtl ? t : l); in.trailing += fmax(0, rtl ? l : t);
    return in;
}
/* the band's deceleration and bounce (UICollectionView.m, for an orthogonally scrolling section) */
void isim_ui_apply_ortho_properties(UIScrollView *band, NSCollectionLayoutSection *sec) {
    UICollectionLayoutSectionOrthogonalScrollingProperties *p = get(sec, &kOrtho);
    if (!p) return;
    if (p.decelerationRate > 0) band.decelerationRate = p.decelerationRate;
    if (p.bounce == UICollectionLayoutSectionOrthogonalScrollingBounceNever) { band.bounces = NO; band.alwaysBounceHorizontal = NO; }
    else if (p.bounce == UICollectionLayoutSectionOrthogonalScrollingBounceAlways) { band.bounces = YES; band.alwaysBounceHorizontal = YES; }
}

/* ================= invalidation contexts ================= */
@implementation UICollectionViewLayoutInvalidationContext {
    NSMutableArray *_items; NSMutableDictionary *_supps, *_decos;
@public
    BOOL _everything, _counts; NSArray *_prevMoving, *_targetMoving; CGPoint _moveTarget;
}
- (BOOL)invalidateEverything { return _everything; }
- (BOOL)invalidateDataSourceCounts { return _everything || _counts; }
- (void)invalidateItemsAtIndexPaths:(NSArray<NSIndexPath *> *)ips { if (!_items) _items = [NSMutableArray array]; [_items addObjectsFromArray:ips]; }
- (void)invalidateSupplementaryElementsOfKind:(NSString *)kind atIndexPaths:(NSArray<NSIndexPath *> *)ips {
    if (!_supps) _supps = [NSMutableDictionary dictionary];
    _supps[kind] = [(_supps[kind] ?: @[]) arrayByAddingObjectsFromArray:ips];
}
- (void)invalidateDecorationElementsOfKind:(NSString *)kind atIndexPaths:(NSArray<NSIndexPath *> *)ips {
    if (!_decos) _decos = [NSMutableDictionary dictionary];
    _decos[kind] = [(_decos[kind] ?: @[]) arrayByAddingObjectsFromArray:ips];
}
- (NSArray<NSIndexPath *> *)invalidatedItemIndexPaths { return [_items copy]; }
- (NSDictionary *)invalidatedSupplementaryIndexPaths { return [_supps copy]; }
- (NSDictionary *)invalidatedDecorationIndexPaths { return [_decos copy]; }
- (NSArray<NSIndexPath *> *)previousIndexPathsForInteractivelyMovingItems { return _prevMoving; }
- (NSArray<NSIndexPath *> *)targetIndexPathsForInteractivelyMovingItems { return _targetMoving; }
- (CGPoint)interactiveMovementTarget { return _moveTarget; }
@end
@implementation UICollectionViewFlowLayoutInvalidationContext
- (instancetype)init { if ((self = [super init])) { _invalidateFlowLayoutDelegateMetrics = YES; _invalidateFlowLayoutAttributes = YES; } return self; }
@end
UICollectionViewLayoutInvalidationContext *isim_ui_everything_context(UICollectionViewLayout *layout) {
    UICollectionViewLayoutInvalidationContext *c = [[[layout class] invalidationContextClass] new];
    if (![c isKindOfClass:[UICollectionViewLayoutInvalidationContext class]]) c = [UICollectionViewLayoutInvalidationContext new];
    c->_everything = YES;
    return c;
}

static char kSectionInsetRef;
@implementation UICollectionViewFlowLayout (UICollectionViewFlowLayoutExtras)
- (UICollectionViewFlowLayoutSectionInsetReference)sectionInsetReference { return [get(self, &kSectionInsetRef) integerValue]; }
- (void)setSectionInsetReference:(UICollectionViewFlowLayoutSectionInsetReference)r { put(self, &kSectionInsetRef, @(r)); [self invalidateLayout]; }
@end
/* the room a flow layout's section inset reference adds (it already keeps out of the adjusted content insets) */
UIEdgeInsets isim_ui_flow_reference_insets(UIEdgeInsets in, UICollectionViewFlowLayout *layout, UICollectionView *cv) {
    UICollectionViewFlowLayoutSectionInsetReference r = layout.sectionInsetReference;
    if (r == UICollectionViewFlowLayoutSectionInsetFromContentInset) return in;
    UIEdgeInsets ai = cv.adjustedContentInset, ref = r == UICollectionViewFlowLayoutSectionInsetFromLayoutMargins ? cv.layoutMargins : cv.safeAreaInsets;
    in.left += fmax(0, ref.left - ai.left); in.right += fmax(0, ref.right - ai.right);
    return in;
}

/* ================= UICollectionViewLayout ================= */
@implementation UICollectionViewLayout (UICollectionViewLayoutExtras)
+ (Class)layoutAttributesClass { return [UICollectionViewLayoutAttributes class]; }
+ (Class)invalidationContextClass {
    return [self isSubclassOfClass:[UICollectionViewFlowLayout class]] ? [UICollectionViewFlowLayoutInvalidationContext class] : [UICollectionViewLayoutInvalidationContext class];
}
/* the layout prepares again before the next pass; the content moves by the context's offset adjustment */
- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context {
    [self _isim_invalidate];
    UICollectionView *cv = self.collectionView;
    CGPoint adj = context.contentOffsetAdjustment;
    if (cv && (adj.x != 0 || adj.y != 0)) { CGPoint o = cv.contentOffset; cv.contentOffset = CGPointMake(o.x + adj.x, o.y + adj.y); }
}
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)b {
    UICollectionViewLayoutInvalidationContext *c = [[[self class] invalidationContextClass] new];
    CGRect o = self.collectionView.bounds;
    c.contentSizeAdjustment = CGSizeMake(b.size.width - o.size.width, b.size.height - o.size.height);
    return c;
}
- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferred withOriginalAttributes:(UICollectionViewLayoutAttributes *)original {
    return !CGSizeEqualToSize(preferred.size, original.size);
}
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferred
                                                                        withOriginalAttributes:(UICollectionViewLayoutAttributes *)original {
    UICollectionViewLayoutInvalidationContext *c = [[[self class] invalidationContextClass] new];
    if (original.representedElementCategory == UICollectionElementCategoryCell) [c invalidateItemsAtIndexPaths:@[original.indexPath]];
    else if (original.representedElementKind) [c invalidateSupplementaryElementsOfKind:original.representedElementKind atIndexPaths:@[original.indexPath]];
    return c;
}
- (UICollectionViewLayoutAttributes *)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath *)ip withTargetPosition:(CGPoint)position {
    UICollectionViewLayoutAttributes *a = [[self layoutAttributesForItemAtIndexPath:ip] copy] ?: [[[self class] layoutAttributesClass] layoutAttributesForCellWithIndexPath:ip];
    a.center = position; a.zIndex = NSIntegerMax / 2;
    a.transform = CGAffineTransformMakeScale(1.05, 1.05);           /* lifted, as UIKit shows it */
    return a;
}
/* the item under the position (else where it was) */
- (NSIndexPath *)targetIndexPathForInteractivelyMovingItem:(NSIndexPath *)previous withPosition:(CGPoint)position {
    for (UICollectionViewLayoutAttributes *a in [self layoutAttributesForElementsInRect:CGRectMake(position.x - 1, position.y - 1, 2, 2)])
        if (a.representedElementCategory == UICollectionElementCategoryCell && CGRectContainsPoint(a.frame, position)) return a.indexPath;
    return previous;
}
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForInteractivelyMovingItems:(NSArray<NSIndexPath *> *)targets withTargetPosition:(CGPoint)p
                                                                         previousIndexPaths:(NSArray<NSIndexPath *> *)previous previousPosition:(CGPoint)pp {
    UICollectionViewLayoutInvalidationContext *c = [[[self class] invalidationContextClass] new];
    c->_targetMoving = [targets copy]; c->_prevMoving = [previous copy]; c->_moveTarget = p;
    return c;
}
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:(NSArray<NSIndexPath *> *)finals
                                                                                                    previousIndexPaths:(NSArray<NSIndexPath *> *)previous movementCancelled:(BOOL)cancelled {
    UICollectionViewLayoutInvalidationContext *c = [[[self class] invalidationContextClass] new];
    c->_targetMoving = [finals copy]; c->_prevMoving = [previous copy];
    return c;
}
- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)items {}
- (void)finalizeCollectionViewUpdates {}
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingDecorationElementOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { return nil; }
- (UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingDecorationElementOfKind:(NSString *)k atIndexPath:(NSIndexPath *)ip { return nil; }
- (NSArray<NSIndexPath *> *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)k { return @[]; }
- (NSArray<NSIndexPath *> *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)k { return @[]; }
- (NSArray<NSIndexPath *> *)indexPathsToInsertForDecorationViewOfKind:(NSString *)k { return @[]; }
- (NSArray<NSIndexPath *> *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)k { return @[]; }
- (void)prepareForAnimatedBoundsChange:(CGRect)oldBounds {}
- (void)finalizeAnimatedBoundsChange {}
- (UIUserInterfaceLayoutDirection)developmentLayoutDirection { return UIUserInterfaceLayoutDirectionLeftToRight; }
- (BOOL)flipsHorizontallyInOppositeLayoutDirection { return NO; }
@end
