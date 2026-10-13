#pragma once
/* isim: table and collection view members from the documentation sweep (#9): section index collation, rects and
   index paths for areas, cell states and transitions, interactive movement, update items, data source translation.
   UIListExtras.m (with hooks in UITableView.m and UICollectionView.m). Categories (no ivars: the classes' sizes must
   not change for apps' subclasses). */
#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>
NS_ASSUME_NONNULL_BEGIN
@class UIVisualEffect;

/* ---- section index collation ---- */
/* the sections of an index: A to Z and # (isim: the Latin alphabet in every language) */
NS_SWIFT_UI_ACTOR
@interface UILocalizedIndexedCollation : NSObject
+ (instancetype)currentCollation;
@property (nonatomic, readonly) NSArray<NSString *> *sectionTitles;
@property (nonatomic, readonly) NSArray<NSString *> *sectionIndexTitles;
- (NSInteger)sectionForSectionIndexTitleAtIndex:(NSInteger)indexTitleIndex NS_SWIFT_NAME(section(forSectionIndexTitle:));
- (NSInteger)sectionForObject:(id)object collationStringSelector:(SEL)selector NS_SWIFT_NAME(section(for:collationStringSelector:));
- (NSArray *)sortedArrayFromArray:(NSArray *)array collationStringSelector:(SEL)selector NS_SWIFT_NAME(sortedArray(from:collationStringSelector:));
@end

/* ---- table views ---- */
typedef NS_ENUM(NSInteger, UITableViewSeparatorInsetReference) { UITableViewSeparatorInsetFromCellEdges, UITableViewSeparatorInsetFromAutomaticInsets }
    NS_SWIFT_NAME(UITableView.SeparatorInsetReference) API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSInteger, UITableViewSelfSizingInvalidation) { UITableViewSelfSizingInvalidationDisabled, UITableViewSelfSizingInvalidationEnabled,
    UITableViewSelfSizingInvalidationEnabledIncludingConstraints } NS_SWIFT_NAME(UITableView.SelfSizingInvalidation) API_AVAILABLE(ios(16.0));
typedef NS_OPTIONS(NSUInteger, UITableViewContentHuggingElements) { UITableViewContentHuggingElementsNone = 0,
    UITableViewContentHuggingElementsSectionHeaders = 1 << 0 } API_AVAILABLE(ios(26.0));
@interface UITableView (UITableViewExtras)
/* plain tables: the height of the empty rows below the content (0: the row height) */
@property (nonatomic) CGFloat fillerRowHeight API_AVAILABLE(ios(15.0));
/* the cells' margins follow the readable content guide (isim: stored) */
@property (nonatomic) BOOL cellLayoutMarginsFollowReadableWidth;
@property (nonatomic) BOOL insetsContentViewsToSafeArea API_AVAILABLE(ios(11.0));        /* isim: stored */
@property (nullable, nonatomic, copy) UIVisualEffect *separatorEffect;                    /* isim: stored */
/* fromCellEdges: separatorInset.left is measured from the cell's edge (automatic: from the content's leading margin) */
@property (nonatomic) UITableViewSeparatorInsetReference separatorInsetReference API_AVAILABLE(ios(11.0));
- (nullable NSArray<NSIndexPath *> *)indexPathsForRowsInRect:(CGRect)rect;
- (CGRect)rectForHeaderInSection:(NSInteger)section;
- (CGRect)rectForFooterInSection:(NSInteger)section;
- (void)scrollToNearestSelectedRowAtScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated;
/* isim applies updates at once: NO; no drop session over the table: NO */
@property (nonatomic, readonly) BOOL hasUncommittedUpdates API_AVAILABLE(ios(11.0));
@property (nonatomic, readonly) BOOL hasActiveDrop API_AVAILABLE(ios(11.0));
/* keyboard focus (UIFocus.h): rows take focus when allowsFocus (or the delegate says so) */
@property (nonatomic) BOOL allowsFocus API_AVAILABLE(ios(15.0));
@property (nonatomic) BOOL allowsFocusDuringEditing API_AVAILABLE(ios(15.0));
@property (nonatomic) BOOL remembersLastFocusedIndexPath API_AVAILABLE(ios(9.0));
@property (nonatomic) UITableViewSelfSizingInvalidation selfSizingInvalidation API_AVAILABLE(ios(16.0));   /* isim: stored */
@property (nonatomic) UITableViewContentHuggingElements contentHuggingElements API_AVAILABLE(ios(26.0));  /* isim: stored */
@end

typedef NS_OPTIONS(NSUInteger, UITableViewCellStateMask) { UITableViewCellStateDefaultMask = 0, UITableViewCellStateShowingEditControlMask = 1 << 0,
    UITableViewCellStateShowingDeleteConfirmationMask = 1 << 1 } NS_SWIFT_NAME(UITableViewCell.StateMask);
typedef NS_ENUM(NSInteger, UITableViewCellFocusStyle) { UITableViewCellFocusStyleDefault, UITableViewCellFocusStyleCustom } NS_SWIFT_NAME(UITableViewCell.FocusStyle);
typedef NS_ENUM(NSInteger, UITableViewCellDragState) { UITableViewCellDragStateNone, UITableViewCellDragStateLifting, UITableViewCellDragStateDragging }
    NS_SWIFT_NAME(UITableViewCell.DragState) API_AVAILABLE(ios(11.0));
@interface UITableViewCell (UITableViewCellExtras)
/* the selected background when the table allows multiple selection */
@property (nullable, nonatomic, strong) UIView *multipleSelectionBackgroundView;
/* shown instead of accessoryView while editing */
@property (nullable, nonatomic, strong) UIView *editingAccessoryView;
/* the swipe actions are open */
@property (nonatomic, readonly) BOOL showingDeleteConfirmation;
/* editing indents the content past the delete control (default YES) */
@property (nonatomic) BOOL shouldIndentWhileEditing;
@property (nonatomic) UITableViewCellFocusStyle focusStyle API_AVAILABLE(ios(9.0));         /* isim: stored */
@property (nonatomic) BOOL userInteractionEnabledWhileDragging API_AVAILABLE(ios(11.0));    /* isim: stored */
/* the cell's editing state (edit control, delete confirmation) is about to change / changed */
- (void)willTransitionToState:(UITableViewCellStateMask)state;
- (void)didTransitionToState:(UITableViewCellStateMask)state;
- (void)dragStateDidChange:(UITableViewCellDragState)dragState API_AVAILABLE(ios(11.0));
@end

/* ---- collection views ---- */
typedef NS_ENUM(NSInteger, UICollectionViewReorderingCadence) { UICollectionViewReorderingCadenceImmediate, UICollectionViewReorderingCadenceFast,
    UICollectionViewReorderingCadenceSlow } NS_SWIFT_NAME(UICollectionView.ReorderingCadence) API_AVAILABLE(ios(11.0));
typedef NS_ENUM(NSInteger, UICollectionViewSelfSizingInvalidation) { UICollectionViewSelfSizingInvalidationDisabled, UICollectionViewSelfSizingInvalidationEnabled,
    UICollectionViewSelfSizingInvalidationEnabledIncludingConstraints } NS_SWIFT_NAME(UICollectionView.SelfSizingInvalidation) API_AVAILABLE(ios(16.0));
typedef NS_ENUM(NSInteger, UICollectionViewCellDragState) { UICollectionViewCellDragStateNone, UICollectionViewCellDragStateLifting,
    UICollectionViewCellDragStateDragging } NS_SWIFT_NAME(UICollectionViewCell.DragState) API_AVAILABLE(ios(11.0));

/* index paths as the data source sees them and as the collection view shows them (isim applies updates at once:
   they are the same) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(11.0))
@protocol UIDataSourceTranslating <NSObject>
- (nullable NSIndexPath *)presentationIndexPathForDataSourceIndexPath:(nullable NSIndexPath *)dataSourceIndexPath;
- (nullable NSIndexPath *)dataSourceIndexPathForPresentationIndexPath:(nullable NSIndexPath *)presentationIndexPath;
- (NSInteger)presentationSectionIndexForDataSourceSectionIndex:(NSInteger)dataSourceSectionIndex;
- (NSInteger)dataSourceSectionIndexForPresentationSectionIndex:(NSInteger)presentationSectionIndex;
- (void)performUsingPresentationValues:(void (NS_NOESCAPE ^)(void))actionsToTranslate;
@end

@interface UICollectionView (UICollectionViewExtras) <UIDataSourceTranslating>
/* interactive movement: the item follows the target position; ending moves it in the data source */
- (BOOL)beginInteractiveMovementForItemAtIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(9.0));
- (void)updateInteractiveMovementTargetPosition:(CGPoint)targetPosition API_AVAILABLE(ios(9.0));
- (void)endInteractiveMovement API_AVAILABLE(ios(9.0));
- (void)cancelInteractiveMovement API_AVAILABLE(ios(9.0));
@property (nonatomic, readonly) BOOL hasActiveDrop API_AVAILABLE(ios(11.0));
@property (nonatomic, readonly) BOOL hasUncommittedUpdates API_AVAILABLE(ios(11.0));
@property (nonatomic) UICollectionViewReorderingCadence reorderingCadence API_AVAILABLE(ios(11.0));    /* isim: stored (moves are immediate) */
- (NSArray<NSIndexPath *> *)indexPathsForVisibleSupplementaryElementsOfKind:(NSString *)elementKind API_AVAILABLE(ios(9.0));
- (nullable NSIndexPath *)indexPathForSupplementaryView:(UICollectionReusableView *)supplementaryView API_AVAILABLE(ios(16.0));
@property (nonatomic) BOOL allowsFocus API_AVAILABLE(ios(15.0));                          /* items take keyboard focus (UIFocus.h) */
@property (nonatomic) BOOL allowsFocusDuringEditing API_AVAILABLE(ios(15.0));
@property (nonatomic) BOOL remembersLastFocusedIndexPath API_AVAILABLE(ios(9.0));
@property (nonatomic) UICollectionViewSelfSizingInvalidation selfSizingInvalidation API_AVAILABLE(ios(16.0));   /* isim: stored */
@end
@interface UITableView (UITableViewTranslating) <UIDataSourceTranslating>
@end

@interface UICollectionViewController (UICollectionViewControllerExtras)
/* a long press picks an item up and drags it to a new place (interactive movement; default YES) */
@property (nonatomic) BOOL installsStandardGestureForInteractiveMovement API_AVAILABLE(ios(9.0));
@property (nonatomic) BOOL useLayoutToLayoutNavigationTransitions;         /* isim: stored */
@end

@interface UICollectionReusableView (UICollectionReusableViewExtras)
- (void)willTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout;
- (void)didTransitionFromLayout:(UICollectionViewLayout *)oldLayout toLayout:(UICollectionViewLayout *)newLayout;
@end
@interface UICollectionViewCell (UICollectionViewCellExtras)
- (void)dragStateDidChange:(UICollectionViewCellDragState)dragState API_AVAILABLE(ios(11.0));
@end

/* the changes of a batch update, as the layout's prepareForCollectionViewUpdates: sees them */
typedef NS_ENUM(NSInteger, UICollectionUpdateAction) { UICollectionUpdateActionInsert, UICollectionUpdateActionDelete, UICollectionUpdateActionReload,
    UICollectionUpdateActionMove, UICollectionUpdateActionNone } NS_SWIFT_NAME(UICollectionViewUpdateItem.Action);
NS_SWIFT_UI_ACTOR
@interface UICollectionViewUpdateItem : NSObject
@property (nullable, nonatomic, readonly) NSIndexPath *indexPathBeforeUpdate;
@property (nullable, nonatomic, readonly) NSIndexPath *indexPathAfterUpdate;
@property (nonatomic, readonly) UICollectionUpdateAction updateAction;
@end
NS_ASSUME_NONNULL_END
