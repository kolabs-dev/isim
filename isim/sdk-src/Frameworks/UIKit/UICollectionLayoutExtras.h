#pragma once
/* isim: collection view layout members from the documentation sweep (#9): anchored supplementary items (badges),
   orthogonal scrolling properties, content insets references, invalidation contexts, update and appearance
   animations, interactive movement and layout direction hooks of UICollectionViewLayout, flow layout section inset
   references. UICollectionLayoutExtras.m (with hooks in UICollectionView.m). Categories and new classes (no ivars in
   existing classes). */
#import <UIKit/UICollectionView.h>
#import <UIKit/UIListExtras.h>
NS_ASSUME_NONNULL_BEGIN

/* ---- anchors and supplementary items ---- */
/* a point on an item's edges, offset in points or in fractions of the supplementary item's size */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface NSCollectionLayoutAnchor : NSObject <NSCopying>
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges NS_SWIFT_NAME(init(edges:));
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges absoluteOffset:(CGPoint)absoluteOffset NS_SWIFT_NAME(init(edges:absoluteOffset:));
+ (instancetype)layoutAnchorWithEdges:(NSDirectionalRectEdge)edges fractionalOffset:(CGPoint)fractionalOffset NS_SWIFT_NAME(init(edges:fractionalOffset:));
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) NSDirectionalRectEdge edges;
@property (nonatomic, readonly) CGPoint offset;
@property (nonatomic, readonly) BOOL isAbsoluteOffset;
@property (nonatomic, readonly) BOOL isFractionalOffset;
@end
@interface NSCollectionLayoutSupplementaryItem (NSCollectionLayoutAnchoring)
/* a supplementary view attached to an item or group (a badge): its containerAnchor point on the item meets its
   itemAnchor point (default: the same edges) */
+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor NS_SWIFT_NAME(init(layoutSize:elementKind:containerAnchor:));
+ (instancetype)supplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind
                                containerAnchor:(NSCollectionLayoutAnchor *)containerAnchor itemAnchor:(NSCollectionLayoutAnchor *)itemAnchor
    NS_SWIFT_NAME(init(layoutSize:elementKind:containerAnchor:itemAnchor:));
@property (nullable, nonatomic, readonly) NSCollectionLayoutAnchor *containerAnchor;
@property (nullable, nonatomic, readonly) NSCollectionLayoutAnchor *itemAnchor;
@end
@interface NSCollectionLayoutItem (NSCollectionLayoutSupplementaryItems)
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize supplementaryItems:(NSArray<NSCollectionLayoutSupplementaryItem *> *)supplementaryItems
    NS_SWIFT_NAME(init(layoutSize:supplementaryItems:));
@property (nonatomic, readonly) NSArray<NSCollectionLayoutSupplementaryItem *> *supplementaryItems;
@end
@interface NSCollectionLayoutGroup (NSCollectionLayoutSupplementaryItems)
/* a group's supplementary items attach to the group's frame (its first item's index path) */
@property (nonatomic, copy) NSArray<NSCollectionLayoutSupplementaryItem *> *supplementaryItems;
@end
@interface NSCollectionLayoutDimension (NSCollectionLayoutUniform)
/* the dimension is the largest of its siblings' (uniformAcrossSiblings(estimate:)) */
@property (nonatomic, readonly) BOOL isUniformAcrossSiblings API_AVAILABLE(ios(17.0));
@end

/* ---- sections ---- */
typedef NS_ENUM(NSInteger, UIContentInsetsReference) { UIContentInsetsReferenceAutomatic, UIContentInsetsReferenceNone, UIContentInsetsReferenceSafeArea,
    UIContentInsetsReferenceLayoutMargins, UIContentInsetsReferenceReadableContent } API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, UICollectionLayoutSectionOrthogonalScrollingBounce) { UICollectionLayoutSectionOrthogonalScrollingBounceAutomatic,
    UICollectionLayoutSectionOrthogonalScrollingBounceAlways, UICollectionLayoutSectionOrthogonalScrollingBounceNever }
    NS_SWIFT_NAME(UICollectionLayoutSectionOrthogonalScrollingProperties.Bounce) API_AVAILABLE(ios(17.0));
typedef CGFloat UICollectionLayoutSectionOrthogonalScrollingDecelerationRate NS_TYPED_EXTENSIBLE_ENUM
    NS_SWIFT_NAME(UICollectionLayoutSectionOrthogonalScrollingProperties.DecelerationRate) API_AVAILABLE(ios(17.0));
UIKIT_EXTERN const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateAutomatic NS_SWIFT_NAME(automatic);
UIKIT_EXTERN const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateNormal NS_SWIFT_NAME(normal);
UIKIT_EXTERN const UICollectionLayoutSectionOrthogonalScrollingDecelerationRate UICollectionLayoutSectionOrthogonalScrollingDecelerationRateFast NS_SWIFT_NAME(fast);
/* the orthogonally scrolling band's deceleration and bounce */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(17.0))
@interface UICollectionLayoutSectionOrthogonalScrollingProperties : NSObject <NSCopying>
@property (nonatomic) UICollectionLayoutSectionOrthogonalScrollingDecelerationRate decelerationRate;
@property (nonatomic) UICollectionLayoutSectionOrthogonalScrollingBounce bounce;
@end
typedef void (^NSCollectionLayoutSectionVisibleItemsInvalidationHandler)(NSArray<id<NSCollectionLayoutVisibleItem>> *visibleItems, CGPoint contentOffset,
    id<NSCollectionLayoutEnvironment> layoutEnvironment) API_AVAILABLE(ios(13.0));
@interface NSCollectionLayoutSection (NSCollectionLayoutSectionExtras)
@property (nonatomic, readonly) UICollectionLayoutSectionOrthogonalScrollingProperties *orthogonalScrollingProperties API_AVAILABLE(ios(17.0));
/* what contentInsets are measured from: layout margins or the readable width widen them (automatic, none, safe area:
   the collection view's adjusted content insets) */
@property (nonatomic) UIContentInsetsReference contentInsetsReference API_AVAILABLE(ios(14.0));
@property (nonatomic) UIContentInsetsReference supplementaryContentInsetsReference API_AVAILABLE(ios(16.0));
@end
@interface UICollectionViewCompositionalLayoutConfiguration (UICollectionViewCompositionalLayoutConfigurationExtras)
@property (nonatomic) UIContentInsetsReference contentInsetsReference API_AVAILABLE(ios(14.0));
@end

/* ---- invalidation contexts ---- */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(7.0))
@interface UICollectionViewLayoutInvalidationContext : NSObject
@property (nonatomic, readonly) BOOL invalidateEverything;
@property (nonatomic, readonly) BOOL invalidateDataSourceCounts;
- (void)invalidateItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)invalidateSupplementaryElementsOfKind:(NSString *)elementKind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)invalidateDecorationElementsOfKind:(NSString *)elementKind atIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *invalidatedItemIndexPaths;
@property (nullable, nonatomic, readonly) NSDictionary<NSString *, NSArray<NSIndexPath *> *> *invalidatedSupplementaryIndexPaths;
@property (nullable, nonatomic, readonly) NSDictionary<NSString *, NSArray<NSIndexPath *> *> *invalidatedDecorationIndexPaths;
/* moves the content (the collection view's contentOffset) and grows it with the invalidation */
@property (nonatomic) CGPoint contentOffsetAdjustment;
@property (nonatomic) CGSize contentSizeAdjustment;
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *previousIndexPathsForInteractivelyMovingItems API_AVAILABLE(ios(9.0));
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *targetIndexPathsForInteractivelyMovingItems API_AVAILABLE(ios(9.0));
@property (nonatomic, readonly) CGPoint interactiveMovementTarget API_AVAILABLE(ios(9.0));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(7.0))
@interface UICollectionViewFlowLayoutInvalidationContext : UICollectionViewLayoutInvalidationContext
@property (nonatomic) BOOL invalidateFlowLayoutDelegateMetrics;
@property (nonatomic) BOOL invalidateFlowLayoutAttributes;
@end

typedef NS_ENUM(NSInteger, UICollectionViewFlowLayoutSectionInsetReference) { UICollectionViewFlowLayoutSectionInsetFromContentInset,
    UICollectionViewFlowLayoutSectionInsetFromSafeArea, UICollectionViewFlowLayoutSectionInsetFromLayoutMargins }
    NS_SWIFT_NAME(UICollectionViewFlowLayout.SectionInsetReference) API_AVAILABLE(ios(11.0));
@interface UICollectionViewFlowLayout (UICollectionViewFlowLayoutExtras)
/* what sectionInset is measured from: the content insets (default), the safe area or the layout margins */
@property (nonatomic) UICollectionViewFlowLayoutSectionInsetReference sectionInsetReference API_AVAILABLE(ios(11.0));
@end

/* ---- the layout's hooks ---- */
@interface UICollectionViewLayout (UICollectionViewLayoutExtras)
/* the classes a layout makes its attributes and invalidation contexts of */
@property (class, nonatomic, readonly) Class layoutAttributesClass;
@property (class, nonatomic, readonly) Class invalidationContextClass API_AVAILABLE(ios(7.0));
- (void)invalidateLayoutWithContext:(UICollectionViewLayoutInvalidationContext *)context API_AVAILABLE(ios(7.0));
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForBoundsChange:(CGRect)newBounds API_AVAILABLE(ios(7.0));
- (BOOL)shouldInvalidateLayoutForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes
                                    withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes API_AVAILABLE(ios(8.0));
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForPreferredLayoutAttributes:(UICollectionViewLayoutAttributes *)preferredAttributes
                                                                        withOriginalAttributes:(UICollectionViewLayoutAttributes *)originalAttributes API_AVAILABLE(ios(8.0));
/* interactive movement: where the moving item is shown, and which index path its position means */
- (UICollectionViewLayoutAttributes *)layoutAttributesForInteractivelyMovingItemAtIndexPath:(NSIndexPath *)indexPath
                                                                         withTargetPosition:(CGPoint)position API_AVAILABLE(ios(9.0));
- (NSIndexPath *)targetIndexPathForInteractivelyMovingItem:(NSIndexPath *)previousIndexPath withPosition:(CGPoint)position API_AVAILABLE(ios(9.0));
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForInteractivelyMovingItems:(NSArray<NSIndexPath *> *)targetIndexPaths
    withTargetPosition:(CGPoint)targetPosition previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths previousPosition:(CGPoint)previousPosition API_AVAILABLE(ios(9.0));
- (UICollectionViewLayoutInvalidationContext *)invalidationContextForEndingInteractiveMovementOfItemsToFinalIndexPaths:(NSArray<NSIndexPath *> *)indexPaths
    previousIndexPaths:(NSArray<NSIndexPath *> *)previousIndexPaths movementCancelled:(BOOL)movementCancelled API_AVAILABLE(ios(9.0));
/* batch updates: the changes before they animate, then the end; where appearing elements start and disappearing ones
   end (nil: they fade) */
- (void)prepareForCollectionViewUpdates:(NSArray<UICollectionViewUpdateItem *> *)updateItems;
- (void)finalizeCollectionViewUpdates;
- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingItemAtIndexPath:(NSIndexPath *)itemIndexPath;
- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingItemAtIndexPath:(NSIndexPath *)itemIndexPath;
- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath;
- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingSupplementaryElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)elementIndexPath;
- (nullable UICollectionViewLayoutAttributes *)initialLayoutAttributesForAppearingDecorationElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)decorationIndexPath;
- (nullable UICollectionViewLayoutAttributes *)finalLayoutAttributesForDisappearingDecorationElementOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)decorationIndexPath;
- (NSArray<NSIndexPath *> *)indexPathsToInsertForSupplementaryViewOfKind:(NSString *)elementKind;
- (NSArray<NSIndexPath *> *)indexPathsToDeleteForSupplementaryViewOfKind:(NSString *)elementKind;
- (NSArray<NSIndexPath *> *)indexPathsToInsertForDecorationViewOfKind:(NSString *)elementKind;
- (NSArray<NSIndexPath *> *)indexPathsToDeleteForDecorationViewOfKind:(NSString *)elementKind;
/* an animated bounds change (rotation, resizing) */
- (void)prepareForAnimatedBoundsChange:(CGRect)oldBounds;
- (void)finalizeAnimatedBoundsChange;
/* right to left: a layout written for left to right is mirrored (flipsHorizontallyInOppositeLayoutDirection) */
@property (nonatomic, readonly) UIUserInterfaceLayoutDirection developmentLayoutDirection;
@property (nonatomic, readonly) BOOL flipsHorizontallyInOppositeLayoutDirection;
@end
NS_ASSUME_NONNULL_END
