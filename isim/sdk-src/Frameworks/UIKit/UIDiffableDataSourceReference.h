#pragma once
/* isim: the Objective-C diffable data sources (iOS 13/14): snapshots and section snapshots as objects, and the table
   and collection view data sources driven by them (Swift apps use the generic NSDiffableDataSourceSnapshot,
   UITableViewDiffableDataSource and UICollectionViewDiffableDataSource of the UIKit overlay). UIDiffableReference.m. */
#import <UIKit/UITableView.h>
#import <UIKit/UICollectionView.h>
NS_ASSUME_NONNULL_BEGIN

/* sections and their items, identified by objects (NSCopying / isEqual:) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface NSDiffableDataSourceSnapshotReference : NSObject <NSCopying>
- (instancetype)init;
@property (nonatomic, readonly) NSInteger numberOfItems;
@property (nonatomic, readonly) NSInteger numberOfSections;
@property (nonatomic, readonly) NSArray *sectionIdentifiers;
@property (nonatomic, readonly) NSArray *itemIdentifiers;
@property (nonatomic, readonly) NSArray *reloadedSectionIdentifiers API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) NSArray *reloadedItemIdentifiers API_AVAILABLE(ios(15.0));
@property (nonatomic, readonly) NSArray *reconfiguredItemIdentifiers API_AVAILABLE(ios(15.0));
- (NSInteger)numberOfItemsInSection:(id)sectionIdentifier;
- (NSArray *)itemIdentifiersInSectionWithIdentifier:(id)sectionIdentifier;
- (nullable id)sectionIdentifierForSectionContainingItemIdentifier:(id)itemIdentifier;
- (NSInteger)indexOfItemIdentifier:(id)itemIdentifier NS_SWIFT_NAME(indexOfItemIdentifier(_:));
- (NSInteger)indexOfSectionIdentifier:(id)sectionIdentifier NS_SWIFT_NAME(indexOfSectionIdentifier(_:));
- (void)appendItemsWithIdentifiers:(NSArray *)identifiers;
- (void)appendItemsWithIdentifiers:(NSArray *)identifiers intoSectionWithIdentifier:(id)sectionIdentifier;
- (void)insertItemsWithIdentifiers:(NSArray *)identifiers beforeItemWithIdentifier:(id)itemIdentifier;
- (void)insertItemsWithIdentifiers:(NSArray *)identifiers afterItemWithIdentifier:(id)itemIdentifier;
- (void)deleteItemsWithIdentifiers:(NSArray *)identifiers;
- (void)deleteAllItems;
- (void)moveItemWithIdentifier:(id)fromIdentifier beforeItemWithIdentifier:(id)toIdentifier;
- (void)moveItemWithIdentifier:(id)fromIdentifier afterItemWithIdentifier:(id)toIdentifier;
- (void)reloadItemsWithIdentifiers:(NSArray *)identifiers;
- (void)reconfigureItemsWithIdentifiers:(NSArray *)identifiers API_AVAILABLE(ios(15.0));
- (void)appendSectionsWithIdentifiers:(NSArray *)sectionIdentifiers;
- (void)insertSectionsWithIdentifiers:(NSArray *)sectionIdentifiers beforeSectionWithIdentifier:(id)toSectionIdentifier;
- (void)insertSectionsWithIdentifiers:(NSArray *)sectionIdentifiers afterSectionWithIdentifier:(id)toSectionIdentifier;
- (void)deleteSectionsWithIdentifiers:(NSArray *)sectionIdentifiers;
- (void)moveSectionWithIdentifier:(id)fromSectionIdentifier beforeSectionWithIdentifier:(id)toSectionIdentifier;
- (void)moveSectionWithIdentifier:(id)fromSectionIdentifier afterSectionWithIdentifier:(id)toSectionIdentifier;
- (void)reloadSectionsWithIdentifiers:(NSArray *)sectionIdentifiers;
@end

/* one section's items as an outline: root items, children, expanded parents */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(14.0))
@interface NSDiffableDataSourceSectionSnapshotReference : NSObject <NSCopying>
- (instancetype)init;
- (void)appendItems:(NSArray *)items;
- (void)appendItems:(NSArray *)items intoParentItem:(nullable id)parentItem;
- (void)insertItems:(NSArray *)items beforeItem:(id)beforeIdentifier;
- (void)insertItems:(NSArray *)items afterItem:(id)afterIdentifier;
- (void)deleteItems:(NSArray *)items;
- (void)deleteAllItems;
- (void)expandItems:(NSArray *)items;
- (void)collapseItems:(NSArray *)items;
- (void)replaceChildrenOfParentItem:(id)parentItem withSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot;
- (void)insertSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot beforeItem:(id)item NS_SWIFT_NAME(insert(_:beforeItem:));
- (void)insertSnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot afterItem:(id)item NS_SWIFT_NAME(insert(_:afterItem:));
- (BOOL)isExpanded:(id)item;
- (BOOL)isVisible:(id)item;
- (BOOL)containsItem:(id)item;
- (NSInteger)levelOfItem:(id)item;
- (NSInteger)indexOfItem:(id)item;
- (NSArray *)expandedItems;
- (nullable id)parentOfChildItem:(id)childItem;
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotOfParentItem:(id)parentItem NS_SWIFT_NAME(ofParentItem(_:));
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotOfParentItem:(id)parentItem includingParentItem:(BOOL)includingParentItem
    NS_SWIFT_NAME(ofParentItem(_:includingParentItem:));
@property (nonatomic, readonly) NSArray *items;
@property (nonatomic, readonly) NSArray *rootItems;
@property (nonatomic, readonly) NSArray *visibleItems;
@property (nonatomic, readonly) NSString *visualDescription;
@end

/* ---- data sources ---- */
typedef UICollectionViewCell *_Nullable (^UICollectionViewDiffableDataSourceCellProvider)(UICollectionView *collectionView, NSIndexPath *indexPath, id itemIdentifier)
    NS_SWIFT_NAME(UICollectionViewDiffableDataSourceReferenceCellProvider);
typedef UICollectionReusableView *_Nullable (^UICollectionViewDiffableDataSourceSupplementaryViewProvider)(UICollectionView *collectionView, NSString *elementKind, NSIndexPath *indexPath)
    NS_SWIFT_NAME(UICollectionViewDiffableDataSourceReferenceSupplementaryViewProvider);
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UICollectionViewDiffableDataSourceReference : NSObject <UICollectionViewDataSource>
- (instancetype)initWithCollectionView:(UICollectionView *)collectionView cellProvider:(UICollectionViewDiffableDataSourceCellProvider)cellProvider;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, copy, nullable) UICollectionViewDiffableDataSourceSupplementaryViewProvider supplementaryViewProvider;
- (NSDiffableDataSourceSnapshotReference *)snapshot;
/* the collection view shows the snapshot: inserted and deleted items animate when animating and the sections are the
   same; reloaded and reconfigured items are asked again */
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)snapshot animatingDifferences:(BOOL)animatingDifferences;
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^_Nullable)(void))completion;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)snapshot API_AVAILABLE(ios(15.0));
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)snapshot completion:(void (^_Nullable)(void))completion API_AVAILABLE(ios(15.0));
- (nullable id)itemIdentifierForIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForItemIdentifier:(id)identifier;
- (nullable id)sectionIdentifierForIndex:(NSInteger)index API_AVAILABLE(ios(15.0));
- (NSInteger)indexForSectionIdentifier:(id)identifier API_AVAILABLE(ios(15.0));
/* a section as an outline: its visible items show; expanding and collapsing changes them */
- (NSDiffableDataSourceSectionSnapshotReference *)snapshotForSection:(id)section API_AVAILABLE(ios(14.0));
- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot toSection:(id)sectionIdentifier animatingDifferences:(BOOL)animatingDifferences API_AVAILABLE(ios(14.0));
- (void)applySnapshot:(NSDiffableDataSourceSectionSnapshotReference *)snapshot toSection:(id)sectionIdentifier animatingDifferences:(BOOL)animatingDifferences
           completion:(void (^_Nullable)(void))completion API_AVAILABLE(ios(14.0));
@end

typedef UITableViewCell *_Nullable (^UITableViewDiffableDataSourceCellProvider)(UITableView *tableView, NSIndexPath *indexPath, id itemIdentifier)
    NS_SWIFT_NAME(UITableViewDiffableDataSourceReferenceCellProvider);
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UITableViewDiffableDataSourceReference : NSObject <UITableViewDataSource>
- (instancetype)initWithTableView:(UITableView *)tableView cellProvider:(UITableViewDiffableDataSourceCellProvider)cellProvider;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (NSDiffableDataSourceSnapshotReference *)snapshot;
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)snapshot animatingDifferences:(BOOL)animatingDifferences;
- (void)applySnapshot:(NSDiffableDataSourceSnapshotReference *)snapshot animatingDifferences:(BOOL)animatingDifferences completion:(void (^_Nullable)(void))completion;
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)snapshot API_AVAILABLE(ios(15.0));
- (void)applySnapshotUsingReloadData:(NSDiffableDataSourceSnapshotReference *)snapshot completion:(void (^_Nullable)(void))completion API_AVAILABLE(ios(15.0));
- (nullable id)itemIdentifierForIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForItemIdentifier:(id)identifier;
- (nullable id)sectionIdentifierForIndex:(NSInteger)index API_AVAILABLE(ios(15.0));
- (NSInteger)indexForSectionIdentifier:(id)identifier API_AVAILABLE(ios(15.0));
@property (nonatomic) UITableViewRowAnimation defaultRowAnimation;
@end
NS_ASSUME_NONNULL_END
