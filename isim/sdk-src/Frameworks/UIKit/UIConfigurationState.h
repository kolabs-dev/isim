// isim UIKit: configuration states, cell registrations and scene placements for Objective-C (issue #235).
// Swift has its own API for these (the UIKit overlay's structs and generic types: UICellConfigurationState,
// UICollectionView.CellRegistration, UIWindowScenePlacement ...), so they are declared for Objective-C only.
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITraitCollection.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UITableView.h>
#import <UIKit/UIScene.h>
#import <UIKit/UIStoryboard.h>
#import <UIKit/UIDiffableDataSourceReference.h>

#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

/* ---- configuration states ---- */
typedef NSString *UIConfigurationStateCustomKey NS_TYPED_EXTENSIBLE_ENUM API_AVAILABLE(ios(14.0));

API_AVAILABLE(ios(14.0))
@protocol UIConfigurationState <NSObject, NSCopying, NSSecureCoding>
- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection;
@property (nonatomic, strong) UITraitCollection *traitCollection;
- (nullable id)customStateForKey:(UIConfigurationStateCustomKey)key;
- (void)setCustomState:(nullable id)customState forKey:(UIConfigurationStateCustomKey)key;
- (nullable id)objectForKeyedSubscript:(UIConfigurationStateCustomKey)key;
- (void)setObject:(nullable id)obj forKeyedSubscript:(UIConfigurationStateCustomKey)key;
@end

UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UIViewConfigurationState : NSObject <UIConfigurationState>
- (instancetype)initWithTraitCollection:(UITraitCollection *)traitCollection NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, strong) UITraitCollection *traitCollection;
@property (nonatomic, getter=isDisabled) BOOL disabled;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isFocused) BOOL focused;
@property (nonatomic, getter=isPinned) BOOL pinned API_AVAILABLE(ios(18.0));
@end

typedef NS_ENUM(NSInteger, UICellConfigurationDragState) {
    UICellConfigurationDragStateNone, UICellConfigurationDragStateLifting, UICellConfigurationDragStateDragging
} API_AVAILABLE(ios(14.0));
typedef NS_ENUM(NSInteger, UICellConfigurationDropState) {
    UICellConfigurationDropStateNone, UICellConfigurationDropStateNotTargeted, UICellConfigurationDropStateTargeted
} API_AVAILABLE(ios(14.0));

UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UICellConfigurationState : UIViewConfigurationState
@property (nonatomic, getter=isEditing) BOOL editing;
@property (nonatomic, getter=isExpanded) BOOL expanded;
@property (nonatomic, getter=isSwiped) BOOL swiped;
@property (nonatomic, getter=isReordering) BOOL reordering;
@property (nonatomic) UICellConfigurationDragState cellDragState;
@property (nonatomic) UICellConfigurationDropState cellDropState;
@end

/* configurations re-derived for a state (Apple's UIContentConfiguration requires it; isim calls it when present) */
@interface UIListContentConfiguration (UIConfigurationStateUpdates)
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state;
@end
@interface UIBackgroundConfiguration (UIConfigurationStateUpdates)
- (instancetype)updatedConfigurationForState:(id<UIConfigurationState>)state;
@end

/* the cells' state, the override point and the update handlers: updateConfigurationUsingState: runs before the next
   layout whenever the state changes (selection, highlight, editing, swipe, expansion) or after
   setNeedsUpdateConfiguration; its default implementation calls configurationUpdateHandler */
typedef void (^UICollectionViewCellConfigurationUpdateHandler)(__kindof UICollectionViewCell *cell, UICellConfigurationState *state)
    API_AVAILABLE(ios(15.0));
@interface UICollectionViewCell (UIConfigurationState)
@property (nonatomic, readonly) UICellConfigurationState *configurationState API_AVAILABLE(ios(14.0));
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state API_AVAILABLE(ios(14.0));
@property (nonatomic, copy, nullable) UICollectionViewCellConfigurationUpdateHandler configurationUpdateHandler API_AVAILABLE(ios(15.0));
- (UIBackgroundConfiguration *)defaultBackgroundConfiguration API_AVAILABLE(ios(16.0));
@end

typedef void (^UITableViewCellConfigurationUpdateHandler)(__kindof UITableViewCell *cell, UICellConfigurationState *state)
    API_AVAILABLE(ios(15.0));
@interface UITableViewCell (UIConfigurationState)
@property (nonatomic, readonly) UICellConfigurationState *configurationState API_AVAILABLE(ios(14.0));
- (void)setNeedsUpdateConfiguration API_AVAILABLE(ios(14.0));
- (void)updateConfigurationUsingState:(UICellConfigurationState *)state API_AVAILABLE(ios(14.0));
@property (nonatomic, copy, nullable) UITableViewCellConfigurationUpdateHandler configurationUpdateHandler API_AVAILABLE(ios(15.0));
@end

typedef void (^UITableViewHeaderFooterViewConfigurationUpdateHandler)(__kindof UITableViewHeaderFooterView *headerFooterView,
                                                                      UIViewConfigurationState *state) API_AVAILABLE(ios(15.0));
@interface UITableViewHeaderFooterView (UIConfigurationState)
@property (nonatomic, readonly) UIViewConfigurationState *configurationState API_AVAILABLE(ios(14.0));
- (void)setNeedsUpdateConfiguration API_AVAILABLE(ios(14.0));
- (void)updateConfigurationUsingState:(UIViewConfigurationState *)state API_AVAILABLE(ios(14.0));
@property (nonatomic, copy, nullable) UITableViewHeaderFooterViewConfigurationUpdateHandler configurationUpdateHandler API_AVAILABLE(ios(15.0));
@end

/* ---- cell and supplementary registrations ---- */
typedef void (^UICollectionViewCellRegistrationConfigurationHandler)(__kindof UICollectionViewCell *cell, NSIndexPath *indexPath, id item)
    API_AVAILABLE(ios(14.0));
UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UICollectionViewCellRegistration : NSObject
+ (instancetype)registrationWithCellClass:(Class)cellClass configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)configurationHandler;
+ (instancetype)registrationWithCellNib:(UINib *)cellNib configurationHandler:(UICollectionViewCellRegistrationConfigurationHandler)configurationHandler;
@property (nonatomic, readonly, nullable) Class cellClass;
@property (nonatomic, readonly, nullable) UINib *cellNib;
@property (nonatomic, readonly) UICollectionViewCellRegistrationConfigurationHandler configurationHandler;
@end

typedef void (^UICollectionViewSupplementaryRegistrationConfigurationHandler)(__kindof UICollectionReusableView *supplementaryView,
                                                                             NSString *elementKind, NSIndexPath *indexPath) API_AVAILABLE(ios(14.0));
UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UICollectionViewSupplementaryRegistration : NSObject
+ (instancetype)registrationWithSupplementaryClass:(Class)supplementaryClass elementKind:(NSString *)elementKind
                              configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)configurationHandler;
+ (instancetype)registrationWithSupplementaryNib:(UINib *)supplementaryNib elementKind:(NSString *)elementKind
                            configurationHandler:(UICollectionViewSupplementaryRegistrationConfigurationHandler)configurationHandler;
@property (nonatomic, readonly, nullable) Class supplementaryClass;
@property (nonatomic, readonly, nullable) UINib *supplementaryNib;
@property (nonatomic, readonly) NSString *elementKind;
@property (nonatomic, readonly) UICollectionViewSupplementaryRegistrationConfigurationHandler configurationHandler;
@end

@interface UICollectionView (UICollectionViewRegistrations)
- (__kindof UICollectionViewCell *)dequeueConfiguredReusableCellWithRegistration:(UICollectionViewCellRegistration *)registration
                                                                    forIndexPath:(NSIndexPath *)indexPath item:(id)item API_AVAILABLE(ios(14.0));
- (__kindof UICollectionReusableView *)dequeueConfiguredReusableSupplementaryViewWithRegistration:(UICollectionViewSupplementaryRegistration *)registration
                                                                                     forIndexPath:(NSIndexPath *)indexPath API_AVAILABLE(ios(14.0));
@end

/* ---- diffable data source handlers ---- */
/* a reorder as the data source applies it (NSOrderedCollectionDifference, Apple's difference property, is not in
   isim's Foundation yet) */
UIKIT_EXTERN API_AVAILABLE(ios(15.0)) NS_SWIFT_UI_ACTOR
@interface NSDiffableDataSourceSectionTransaction<SectionIdentifierType, ItemIdentifierType> : NSObject
@property (nonatomic, readonly) SectionIdentifierType sectionIdentifier;
@property (nonatomic, readonly) NSDiffableDataSourceSectionSnapshotReference *initialSnapshot;
@property (nonatomic, readonly) NSDiffableDataSourceSectionSnapshotReference *finalSnapshot;
@end
UIKIT_EXTERN API_AVAILABLE(ios(15.0)) NS_SWIFT_UI_ACTOR
@interface NSDiffableDataSourceTransaction<SectionIdentifierType, ItemIdentifierType> : NSObject
@property (nonatomic, readonly) NSDiffableDataSourceSnapshotReference *initialSnapshot;
@property (nonatomic, readonly) NSDiffableDataSourceSnapshotReference *finalSnapshot;
@property (nonatomic, readonly) NSArray<NSDiffableDataSourceSectionTransaction<SectionIdentifierType, ItemIdentifierType> *> *sectionTransactions;
@end

UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UICollectionViewDiffableDataSourceReorderingHandlers<SectionType, ItemType> : NSObject <NSCopying>
@property (nonatomic, copy, nullable) BOOL (^canReorderItemHandler)(ItemType item);
@property (nonatomic, copy, nullable) void (^willReorderHandler)(NSDiffableDataSourceTransaction<SectionType, ItemType> *transaction);
@property (nonatomic, copy, nullable) void (^didReorderHandler)(NSDiffableDataSourceTransaction<SectionType, ItemType> *transaction);
@end

UIKIT_EXTERN API_AVAILABLE(ios(14.0)) NS_SWIFT_UI_ACTOR
@interface UICollectionViewDiffableDataSourceSectionSnapshotHandlers<ItemType> : NSObject <NSCopying>
@property (nonatomic, copy, nullable) BOOL (^shouldExpandItemHandler)(ItemType item);
@property (nonatomic, copy, nullable) void (^willExpandItemHandler)(ItemType item);
@property (nonatomic, copy, nullable) BOOL (^shouldCollapseItemHandler)(ItemType item);
@property (nonatomic, copy, nullable) void (^willCollapseItemHandler)(ItemType item);
@property (nonatomic, copy, nullable) NSDiffableDataSourceSectionSnapshotReference *_Nonnull (^snapshotForExpandingParentItemHandler)(
    ItemType item, NSDiffableDataSourceSectionSnapshotReference *currentSnapshot);
@end

@interface UICollectionViewDiffableDataSourceReference (UIDiffableDataSourceHandlers)
@property (nonatomic, copy) UICollectionViewDiffableDataSourceReorderingHandlers *reorderingHandlers API_AVAILABLE(ios(14.0));
@property (nonatomic, copy) UICollectionViewDiffableDataSourceSectionSnapshotHandlers *sectionSnapshotHandlers API_AVAILABLE(ios(14.0));
@end

/* ---- window scene placements (iPadOS 17): prominent takes the screen, standard goes beside the others ---- */
UIKIT_EXTERN API_AVAILABLE(ios(17.0)) NS_SWIFT_UI_ACTOR
@interface UIWindowScenePlacement : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
UIKIT_EXTERN API_AVAILABLE(ios(17.0)) NS_SWIFT_UI_ACTOR
@interface UIWindowSceneStandardPlacement : UIWindowScenePlacement
+ (instancetype)standardPlacement;
@end
UIKIT_EXTERN API_AVAILABLE(ios(17.0)) NS_SWIFT_UI_ACTOR
@interface UIWindowSceneProminentPlacement : UIWindowScenePlacement
+ (instancetype)prominentPlacement;
@end
@interface UIWindowSceneActivationRequestOptions (UIWindowScenePlacement)
@property (nonatomic, copy, nullable) UIWindowScenePlacement *placement API_AVAILABLE(ios(17.0));
@end

NS_ASSUME_NONNULL_END
#endif
