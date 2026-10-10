#pragma once
/* isim: UICollectionView, UICollectionViewCell / UICollectionViewListCell / UICollectionReusableView,
   UICollectionViewLayout + UICollectionViewFlowLayout, UICollectionViewCompositionalLayout (NSCollectionLayout*),
   UICollectionLayoutListConfiguration, cell accessories, UICollectionViewController. Compositional layouts scroll
   vertically or horizontally (configuration.scrollDirection), with custom groups, decoration items (section
   backgrounds) and visibleItemsInvalidationHandler; any layout can place decoration views. */
#import <UIKit/UIScrollView.h>
#import <UIKit/UIViewController.h>
#import <UIKit/UITableView.h>
#import <UIKit/UIDynamicAnimator.h>
NS_ASSUME_NONNULL_BEGIN
@class UICollectionView, UICollectionViewLayout, UICollectionViewLayoutAttributes, UIColor;

UIKIT_EXTERN NSString *const UICollectionElementKindSectionHeader;
UIKIT_EXTERN NSString *const UICollectionElementKindSectionFooter;
UIKIT_EXTERN const CGSize UICollectionViewFlowLayoutAutomaticSize;

typedef NS_ENUM(NSUInteger, UICollectionElementCategory) { UICollectionElementCategoryCell, UICollectionElementCategorySupplementaryView, UICollectionElementCategoryDecorationView };
typedef NS_ENUM(NSInteger, UICollectionViewScrollDirection) { UICollectionViewScrollDirectionVertical, UICollectionViewScrollDirectionHorizontal };
typedef NS_OPTIONS(NSUInteger, UICollectionViewScrollPosition) {
    UICollectionViewScrollPositionNone = 0, UICollectionViewScrollPositionTop = 1 << 0, UICollectionViewScrollPositionCenteredVertically = 1 << 1,
    UICollectionViewScrollPositionBottom = 1 << 2, UICollectionViewScrollPositionLeft = 1 << 3, UICollectionViewScrollPositionCenteredHorizontally = 1 << 4,
    UICollectionViewScrollPositionRight = 1 << 5 };

/* ---- reusable views and cells ---- */
NS_SWIFT_UI_ACTOR
@interface UICollectionViewLayoutAttributes : NSObject <NSCopying, UIDynamicItem>
+ (instancetype)layoutAttributesForCellWithIndexPath:(NSIndexPath *)indexPath;
+ (instancetype)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind withIndexPath:(NSIndexPath *)indexPath;
+ (instancetype)layoutAttributesForDecorationViewOfKind:(NSString *)decorationViewKind withIndexPath:(NSIndexPath *)indexPath NS_SWIFT_NAME(init(forDecorationViewOfKind:with:));
@property (nonatomic) CGRect frame;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGSize size;
@property (nonatomic) CGRect bounds;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic) CGFloat alpha;
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic, strong) NSIndexPath *indexPath;
@property (nonatomic, readonly) UICollectionElementCategory representedElementCategory;
@property (nullable, nonatomic, readonly) NSString *representedElementKind;
@end

NS_SWIFT_UI_ACTOR
@interface UICollectionReusableView : UIView
@property (nullable, nonatomic, readonly, copy) NSString *reuseIdentifier;
- (void)prepareForReuse;
- (void)applyLayoutAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes;
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes;
@end

NS_SWIFT_UI_ACTOR
@interface UICollectionViewCell : UICollectionReusableView
@property (nonatomic, readonly) UIView *contentView;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nullable, nonatomic, strong) UIView *selectedBackgroundView;
@property (nullable, nonatomic, copy) id<UIContentConfiguration> contentConfiguration;
@property (nullable, nonatomic, copy) UIBackgroundConfiguration *backgroundConfiguration;
@property (nonatomic) BOOL automaticallyUpdatesContentConfiguration;
@property (nonatomic) BOOL automaticallyUpdatesBackgroundConfiguration;
/* configuration updates (iOS 14): the Swift configurationUpdateHandler runs before the next layout */
- (void)setNeedsUpdateConfiguration;
@end

/* list cell accessories (Swift: the UICellAccessory struct in the UIKit overlay) */
typedef NS_ENUM(NSInteger, UICellAccessoryDisplayedState) { UICellAccessoryDisplayedAlways, UICellAccessoryDisplayedWhenEditing, UICellAccessoryDisplayedWhenNotEditing };
NS_SWIFT_UI_ACTOR
@interface UICellAccessory : NSObject <NSCopying>
@property (nonatomic) UICellAccessoryDisplayedState displayedState;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nullable, nonatomic, strong) UIColor *tintColor;
@end
@interface UICellAccessoryDisclosureIndicator : UICellAccessory @end
@interface UICellAccessoryCheckmark : UICellAccessory @end
@interface UICellAccessoryDetail : UICellAccessory
@property (nullable, nonatomic, copy) void (^actionHandler)(void);
@end
@interface UICellAccessoryDelete : UICellAccessory
@property (nullable, nonatomic, copy) void (^actionHandler)(void);
@end
@interface UICellAccessoryReorder : UICellAccessory @end
@interface UICellAccessoryOutlineDisclosure : UICellAccessory
@property (nullable, nonatomic, copy) void (^actionHandler)(void);
@end
@interface UICellAccessoryLabel : UICellAccessory
- (instancetype)initWithText:(NSString *)text;
@property (nonatomic, readonly, copy) NSString *text;
@end
@interface UICellAccessoryCustomView : UICellAccessory
- (instancetype)initWithCustomView:(UIView *)customView placement:(NSInteger)placement;
@property (nonatomic, readonly, strong) UIView *customView;
@property (nonatomic, readonly) NSInteger placement;     /* 0 leading, 1 trailing */
@end

NS_SWIFT_UI_ACTOR
@interface UICollectionViewListCell : UICollectionViewCell
- (UIListContentConfiguration *)defaultContentConfiguration;
@property (nonatomic, copy) NSArray<UICellAccessory *> *accessories;
@property (nonatomic) NSInteger indentationLevel;
@property (nonatomic) CGFloat indentationWidth;
@end

/* ---- layouts ---- */
NS_SWIFT_UI_ACTOR
@interface UICollectionViewLayout : NSObject <NSCoding>
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nullable, nonatomic, readonly, weak) UICollectionView *collectionView;
- (void)invalidateLayout;
- (void)prepareLayout;
@property (nonatomic, readonly) CGSize collectionViewContentSize;
- (nullable NSArray<__kindof UICollectionViewLayoutAttributes *> *)layoutAttributesForElementsInRect:(CGRect)rect;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds;
- (CGPoint)targetContentOffsetForProposedContentOffset:(CGPoint)proposedContentOffset withScrollingVelocity:(CGPoint)velocity;
/* decoration views: views the layout places (no data source); registered by kind, positioned by
   layoutAttributesForElementsInRect: (UICollectionElementCategoryDecorationView attributes) */
- (void)registerClass:(nullable Class)viewClass forDecorationViewOfKind:(NSString *)elementKind NS_SWIFT_NAME(register(_:forDecorationViewOfKind:));
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForDecorationViewOfKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
/* layout transitions */
- (void)prepareForTransitionToLayout:(UICollectionViewLayout *)newLayout;
- (void)prepareForTransitionFromLayout:(UICollectionViewLayout *)oldLayout;
- (void)finalizeLayoutTransition;
@end

/* the layout between two layouts during an (interactive) transition: attributes interpolated by transitionProgress */
NS_SWIFT_UI_ACTOR
@interface UICollectionViewTransitionLayout : UICollectionViewLayout
- (instancetype)initWithCurrentLayout:(UICollectionViewLayout *)currentLayout nextLayout:(UICollectionViewLayout *)newLayout NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic) CGFloat transitionProgress;
@property (nonatomic, readonly) UICollectionViewLayout *currentLayout;
@property (nonatomic, readonly) UICollectionViewLayout *nextLayout;
- (void)updateValue:(CGFloat)value forAnimatedKey:(NSString *)key;
- (CGFloat)valueForAnimatedKey:(NSString *)key;
@end
typedef void (^UICollectionViewLayoutInteractiveTransitionCompletion)(BOOL completed, BOOL finished);

@protocol UICollectionViewDelegateFlowLayout;
NS_SWIFT_UI_ACTOR
@interface UICollectionViewFlowLayout : UICollectionViewLayout
@property (nonatomic) CGFloat minimumLineSpacing;
@property (nonatomic) CGFloat minimumInteritemSpacing;
@property (nonatomic) CGSize itemSize;
@property (nonatomic) CGSize estimatedItemSize;
@property (nonatomic) UICollectionViewScrollDirection scrollDirection;
@property (nonatomic) CGSize headerReferenceSize;
@property (nonatomic) CGSize footerReferenceSize;
@property (nonatomic) UIEdgeInsets sectionInset;
@property (nonatomic) BOOL sectionHeadersPinToVisibleBounds;
@property (nonatomic) BOOL sectionFootersPinToVisibleBounds;
@end

/* compositional layout (iOS 13) */
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutDimension : NSObject <NSCopying>
+ (instancetype)fractionalWidthDimension:(CGFloat)fractionalWidth;
+ (instancetype)fractionalHeightDimension:(CGFloat)fractionalHeight;
+ (instancetype)absoluteDimension:(CGFloat)absoluteDimension;
+ (instancetype)estimatedDimension:(CGFloat)estimatedDimension;
+ (instancetype)uniformAcrossSiblingsWithEstimate:(CGFloat)estimatedDimension;
@property (nonatomic, readonly) BOOL isFractionalWidth;
@property (nonatomic, readonly) BOOL isFractionalHeight;
@property (nonatomic, readonly) BOOL isAbsolute;
@property (nonatomic, readonly) BOOL isEstimated;
@property (nonatomic, readonly) CGFloat dimension;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutSize : NSObject <NSCopying>
+ (instancetype)sizeWithWidthDimension:(NSCollectionLayoutDimension *)width heightDimension:(NSCollectionLayoutDimension *)height;
@property (nonatomic, readonly) NSCollectionLayoutDimension *widthDimension;
@property (nonatomic, readonly) NSCollectionLayoutDimension *heightDimension;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutSpacing : NSObject <NSCopying>
+ (instancetype)flexibleSpacing:(CGFloat)flexibleSpacing;
+ (instancetype)fixedSpacing:(CGFloat)fixedSpacing;
@property (nonatomic, readonly) CGFloat spacing;
@property (nonatomic, readonly) BOOL isFlexibleSpacing;
@property (nonatomic, readonly) BOOL isFixedSpacing;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutEdgeSpacing : NSObject <NSCopying>
+ (instancetype)spacingForLeading:(nullable NSCollectionLayoutSpacing *)leading top:(nullable NSCollectionLayoutSpacing *)top trailing:(nullable NSCollectionLayoutSpacing *)trailing bottom:(nullable NSCollectionLayoutSpacing *)bottom;
@property (nullable, nonatomic, readonly) NSCollectionLayoutSpacing *leading, *top, *trailing, *bottom;
@end
#ifndef ISIM_NSDIRECTIONALRECTEDGE_DEFINED
#define ISIM_NSDIRECTIONALRECTEDGE_DEFINED 1
typedef NS_OPTIONS(NSUInteger, NSDirectionalRectEdge) {
    NSDirectionalRectEdgeNone = 0, NSDirectionalRectEdgeTop = 1 << 0, NSDirectionalRectEdgeLeading = 1 << 1, NSDirectionalRectEdgeBottom = 1 << 2,
    NSDirectionalRectEdgeTrailing = 1 << 3, NSDirectionalRectEdgeAll = 15 };
#endif
typedef NS_ENUM(NSInteger, NSRectAlignment) {
    NSRectAlignmentNone = 0, NSRectAlignmentTop, NSRectAlignmentTopLeading, NSRectAlignmentLeading, NSRectAlignmentBottomLeading,
    NSRectAlignmentBottom, NSRectAlignmentBottomTrailing, NSRectAlignmentTrailing, NSRectAlignmentTopTrailing };
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutItem : NSObject <NSCopying>
+ (instancetype)itemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize;
@property (nonatomic) NSDirectionalEdgeInsets contentInsets;
@property (nullable, nonatomic, copy) NSCollectionLayoutEdgeSpacing *edgeSpacing;
@property (nonatomic, readonly) NSCollectionLayoutSize *layoutSize;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutSupplementaryItem : NSCollectionLayoutItem
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, readonly) NSString *elementKind;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutBoundarySupplementaryItem : NSCollectionLayoutSupplementaryItem
+ (instancetype)boundarySupplementaryItemWithLayoutSize:(NSCollectionLayoutSize *)layoutSize elementKind:(NSString *)elementKind alignment:(NSRectAlignment)alignment;
@property (nonatomic) BOOL extendsBoundary;
@property (nonatomic) BOOL pinToVisibleBounds;
@property (nonatomic, readonly) NSRectAlignment alignment;
@end
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutGroup : NSCollectionLayoutItem
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray<NSCollectionLayoutItem *> *)subitems;
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count;
+ (instancetype)horizontalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count;
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitems:(NSArray<NSCollectionLayoutItem *> *)subitems;
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize repeatingSubitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count;
+ (instancetype)verticalGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize subitem:(NSCollectionLayoutItem *)subitem count:(NSInteger)count;
@property (nullable, nonatomic, copy) NSCollectionLayoutSpacing *interItemSpacing;
@property (nonatomic, readonly) NSArray<NSCollectionLayoutItem *> *subitems;
@end
/* custom groups (iOS 13): the provider returns each item's frame in the group */
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutGroupCustomItem : NSObject <NSCopying>
+ (instancetype)customItemWithFrame:(CGRect)frame NS_SWIFT_NAME(init(frame:));
+ (instancetype)customItemWithFrame:(CGRect)frame zIndex:(NSInteger)zIndex NS_SWIFT_NAME(init(frame:zIndex:));
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) NSInteger zIndex;
@end
@protocol NSCollectionLayoutEnvironment;
typedef NSArray<NSCollectionLayoutGroupCustomItem *> * _Nonnull (^NSCollectionLayoutGroupCustomItemProvider)(id<NSCollectionLayoutEnvironment> layoutEnvironment);
@interface NSCollectionLayoutGroup (IsimCustom)
+ (instancetype)customGroupWithLayoutSize:(NSCollectionLayoutSize *)layoutSize itemProvider:(NSCollectionLayoutGroupCustomItemProvider)itemProvider NS_SWIFT_NAME(custom(layoutSize:itemProvider:));
@end
/* decoration items (iOS 13): a section background view of a registered decoration kind */
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutDecorationItem : NSCollectionLayoutItem
+ (instancetype)backgroundDecorationItemWithElementKind:(NSString *)elementKind NS_SWIFT_NAME(background(elementKind:));
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, readonly) NSString *elementKind;
@end
/* the items of a section on screen, adjustable while it scrolls (visibleItemsInvalidationHandler) */
NS_SWIFT_UI_ACTOR
@protocol NSCollectionLayoutVisibleItem <NSObject>
@property (nonatomic) CGFloat alpha;
@property (nonatomic) NSInteger zIndex;
@property (nonatomic, getter=isHidden) BOOL hidden;
@property (nonatomic) CGPoint center;
@property (nonatomic) CGAffineTransform transform;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSIndexPath *indexPath;
@property (nonatomic, readonly) CGRect frame;
@property (nonatomic, readonly) CGRect bounds;
@property (nonatomic, readonly) UICollectionElementCategory representedElementCategory;
@property (nullable, nonatomic, readonly) NSString *representedElementKind;
@end
typedef NS_ENUM(NSInteger, UICollectionLayoutSectionOrthogonalScrollingBehavior) {
    UICollectionLayoutSectionOrthogonalScrollingBehaviorNone, UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuous,
    UICollectionLayoutSectionOrthogonalScrollingBehaviorContinuousGroupLeadingBoundary, UICollectionLayoutSectionOrthogonalScrollingBehaviorPaging,
    UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPaging, UICollectionLayoutSectionOrthogonalScrollingBehaviorGroupPagingCentered };
@protocol NSCollectionLayoutContainer <NSObject>
@property (nonatomic, readonly) CGSize contentSize;
@property (nonatomic, readonly) CGSize effectiveContentSize;
@property (nonatomic, readonly) NSDirectionalEdgeInsets contentInsets;
@property (nonatomic, readonly) NSDirectionalEdgeInsets effectiveContentInsets;
@end
@protocol NSCollectionLayoutEnvironment <NSObject>
@property (nonatomic, readonly) id<NSCollectionLayoutContainer> container;
@property (nonatomic, readonly) UITraitCollection *traitCollection;
@end
@class UICollectionLayoutListConfiguration;
NS_SWIFT_UI_ACTOR
@interface NSCollectionLayoutSection : NSObject <NSCopying>
+ (instancetype)sectionWithGroup:(NSCollectionLayoutGroup *)group;
+ (instancetype)sectionWithListConfiguration:(UICollectionLayoutListConfiguration *)configuration layoutEnvironment:(id<NSCollectionLayoutEnvironment>)layoutEnvironment;
@property (nonatomic) NSDirectionalEdgeInsets contentInsets;
@property (nonatomic) CGFloat interGroupSpacing;
@property (nonatomic) UICollectionLayoutSectionOrthogonalScrollingBehavior orthogonalScrollingBehavior;
@property (nonatomic, copy) NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *boundarySupplementaryItems;
@property (nonatomic) BOOL supplementariesFollowContentInsets;
@property (nonatomic, copy) NSArray<NSCollectionLayoutDecorationItem *> *decorationItems;
@property (nullable, nonatomic, copy) void (^visibleItemsInvalidationHandler)(NSArray<id<NSCollectionLayoutVisibleItem>> *visibleItems, CGPoint contentOffset, id<NSCollectionLayoutEnvironment> layoutEnvironment);
@end
NS_SWIFT_UI_ACTOR
@interface UICollectionViewCompositionalLayoutConfiguration : NSObject <NSCopying>
@property (nonatomic) UICollectionViewScrollDirection scrollDirection;
@property (nonatomic) CGFloat interSectionSpacing;
@property (nonatomic, copy) NSArray<NSCollectionLayoutBoundarySupplementaryItem *> *boundarySupplementaryItems;
@end
typedef NSCollectionLayoutSection * _Nullable (^UICollectionViewCompositionalLayoutSectionProvider)(NSInteger section, id<NSCollectionLayoutEnvironment> layoutEnvironment);
NS_SWIFT_UI_ACTOR
@interface UICollectionViewCompositionalLayout : UICollectionViewLayout
- (instancetype)initWithSection:(NSCollectionLayoutSection *)section;
- (instancetype)initWithSection:(NSCollectionLayoutSection *)section configuration:(UICollectionViewCompositionalLayoutConfiguration *)configuration;
- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)sectionProvider;
- (instancetype)initWithSectionProvider:(UICollectionViewCompositionalLayoutSectionProvider)sectionProvider configuration:(UICollectionViewCompositionalLayoutConfiguration *)configuration;
+ (instancetype)layoutWithListConfiguration:(UICollectionLayoutListConfiguration *)configuration;
@property (nonatomic, copy) UICollectionViewCompositionalLayoutConfiguration *configuration;
@end

/* list configuration (iOS 14) */
typedef NS_ENUM(NSInteger, UICollectionLayoutListAppearance) {
    UICollectionLayoutListAppearancePlain, UICollectionLayoutListAppearanceGrouped, UICollectionLayoutListAppearanceInsetGrouped,
    UICollectionLayoutListAppearanceSidebar, UICollectionLayoutListAppearanceSidebarPlain };
typedef NS_ENUM(NSInteger, UICollectionLayoutListHeaderMode) { UICollectionLayoutListHeaderModeNone, UICollectionLayoutListHeaderModeSupplementary, UICollectionLayoutListHeaderModeFirstItemInSection };
typedef NS_ENUM(NSInteger, UICollectionLayoutListFooterMode) { UICollectionLayoutListFooterModeNone, UICollectionLayoutListFooterModeSupplementary };
typedef UISwipeActionsConfiguration * _Nullable (^UICollectionLayoutListSwipeActionsConfigurationProvider)(NSIndexPath *indexPath);
NS_SWIFT_UI_ACTOR
@interface UICollectionLayoutListConfiguration : NSObject <NSCopying>
- (instancetype)initWithAppearance:(UICollectionLayoutListAppearance)appearance;
@property (nonatomic, readonly) UICollectionLayoutListAppearance appearance;
@property (nonatomic) BOOL showsSeparators;
@property (nullable, nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic) UICollectionLayoutListHeaderMode headerMode;
@property (nonatomic) UICollectionLayoutListFooterMode footerMode;
@property (nonatomic) CGFloat headerTopPadding;
@property (nullable, nonatomic, copy) UICollectionLayoutListSwipeActionsConfigurationProvider leadingSwipeActionsConfigurationProvider;
@property (nullable, nonatomic, copy) UICollectionLayoutListSwipeActionsConfigurationProvider trailingSwipeActionsConfigurationProvider;
@end

/* ---- the collection view ---- */
@protocol UICollectionViewDataSource <NSObject>
@required
- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section;
- (__kindof UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView;
- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;
@end
@class UIContextMenuConfiguration;
@protocol UIContextMenuInteractionAnimating, UIContextMenuInteractionCommitAnimating;
@protocol UICollectionViewDelegate <UIScrollViewDelegate>
@optional
- (UICollectionViewTransitionLayout *)collectionView:(UICollectionView *)collectionView transitionLayoutForOldLayout:(UICollectionViewLayout *)fromLayout
                                           newLayout:(UICollectionViewLayout *)toLayout;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didUnhighlightItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)collectionView:(UICollectionView *)collectionView shouldDeselectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView didEndDisplayingCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView willDisplaySupplementaryView:(UICollectionReusableView *)view forElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
/* context menus (UIContextMenuInteraction.h): a long press on an item */
- (nullable UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths point:(CGPoint)point API_AVAILABLE(ios(16.0));
- (nullable UIContextMenuConfiguration *)collectionView:(UICollectionView *)collectionView contextMenuConfigurationForItemAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point API_DEPRECATED("Use collectionView:contextMenuConfigurationForItemsAtIndexPaths:point:", ios(13.0, 16.0));
- (void)collectionView:(UICollectionView *)collectionView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator;
- (void)collectionView:(UICollectionView *)collectionView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
- (void)collectionView:(UICollectionView *)collectionView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
@end
/* prefetching (iOS 10): the items about to scroll into view, before their cells are asked for */
@protocol UICollectionViewDataSourcePrefetching <NSObject>
@required
- (void)collectionView:(UICollectionView *)collectionView prefetchItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
@optional
- (void)collectionView:(UICollectionView *)collectionView cancelPrefetchingForItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
@end
@protocol UICollectionViewDelegateFlowLayout <UICollectionViewDelegate>
@optional
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath;
- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section;
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumLineSpacingForSectionAtIndex:(NSInteger)section;
- (CGFloat)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout minimumInteritemSpacingForSectionAtIndex:(NSInteger)section;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section;
- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section;
@end

NS_SWIFT_UI_ACTOR
@interface UICollectionView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame collectionViewLayout:(UICollectionViewLayout *)layout NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, strong) UICollectionViewLayout *collectionViewLayout;
- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout animated:(BOOL)animated;
- (void)setCollectionViewLayout:(UICollectionViewLayout *)layout animated:(BOOL)animated completion:(void (^ _Nullable)(BOOL finished))completion;
/* an interactive layout transition: update the returned layout's transitionProgress, then finish or cancel */
- (UICollectionViewTransitionLayout *)startInteractiveTransitionToCollectionViewLayout:(UICollectionViewLayout *)layout
                                                                            completion:(nullable UICollectionViewLayoutInteractiveTransitionCompletion)completion;
- (void)finishInteractiveTransition;
- (void)cancelInteractiveTransition;
@property (nullable, nonatomic, weak) id<UICollectionViewDelegate> delegate;
@property (nullable, nonatomic, weak) id<UICollectionViewDataSource> dataSource;
@property (nullable, nonatomic, weak) id<UICollectionViewDataSourcePrefetching> prefetchDataSource;
@property (nonatomic, getter=isPrefetchingEnabled) BOOL prefetchingEnabled;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nonatomic) BOOL allowsSelection;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic) BOOL selectionFollowsFocus;
@property (nonatomic, getter=isEditing) BOOL editing;
- (void)registerClass:(nullable Class)cellClass forCellWithReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(nullable Class)viewClass forSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier;
- (__kindof UICollectionViewCell *)dequeueReusableCellWithReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (__kindof UICollectionReusableView *)dequeueReusableSupplementaryViewOfKind:(NSString *)elementKind withReuseIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
@property (nonatomic, readonly) NSInteger numberOfSections;
- (NSInteger)numberOfItemsInSection:(NSInteger)section;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForItemAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UICollectionViewLayoutAttributes *)layoutAttributesForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForItemAtPoint:(CGPoint)point;
- (nullable NSIndexPath *)indexPathForCell:(UICollectionViewCell *)cell;
- (nullable UICollectionViewCell *)cellForItemAtIndexPath:(NSIndexPath *)indexPath;
@property (nonatomic, readonly) NSArray<__kindof UICollectionViewCell *> *visibleCells;
@property (nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForVisibleItems;
- (nullable UICollectionReusableView *)supplementaryViewForElementKind:(NSString *)elementKind atIndexPath:(NSIndexPath *)indexPath;
- (NSArray<UICollectionReusableView *> *)visibleSupplementaryViewsOfKind:(NSString *)elementKind;
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForSelectedItems;
- (void)selectItemAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition;
- (void)deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void)scrollToItemAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UICollectionViewScrollPosition)scrollPosition animated:(BOOL)animated;
- (void)reloadData;
- (void)insertSections:(NSIndexSet *)sections;
- (void)deleteSections:(NSIndexSet *)sections;
- (void)reloadSections:(NSIndexSet *)sections;
- (void)insertItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)deleteItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)reloadItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)reconfigureItemsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)moveItemAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;
- (void)performBatchUpdates:(void (NS_NOESCAPE ^ _Nullable)(void))updates completion:(void (^ _Nullable)(BOOL finished))completion;
@end

NS_SWIFT_UI_ACTOR
@interface UICollectionViewController : UIViewController <UICollectionViewDataSource, UICollectionViewDelegate>
- (instancetype)initWithCollectionViewLayout:(UICollectionViewLayout *)layout NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (null_resettable, nonatomic, strong) __kindof UICollectionView *collectionView;
@property (nonatomic, readonly) __kindof UICollectionViewLayout *collectionViewLayout;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear;
@end
NS_ASSUME_NONNULL_END
