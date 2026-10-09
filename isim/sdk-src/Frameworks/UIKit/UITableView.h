#pragma once
/* isim: UITableView, UITableViewCell, UITableViewHeaderFooterView, UIListContentConfiguration,
   UIContextualAction / UISwipeActionsConfiguration, NSIndexPath (UIKitAdditions). */
#import <UIKit/UIScrollView.h>
#import <UIKit/UIControl.h>
#import <UIKit/UIViewController.h>
#import <Foundation/NSIndexPath.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIColor, UIFont, UILabel, UIImageView, UITableView, UIRefreshControl;

@interface NSIndexPath (UIKitAdditions)
+ (instancetype)indexPathForRow:(NSInteger)row inSection:(NSInteger)section;
+ (instancetype)indexPathForItem:(NSInteger)item inSection:(NSInteger)section;
@property (nonatomic, readonly) NSInteger section;
@property (nonatomic, readonly) NSInteger row;
@property (nonatomic, readonly) NSInteger item;
@end

/* content configurations (iOS 14) */
NS_SWIFT_UI_ACTOR
@interface UIListContentTextProperties : NSObject <NSCopying>
@property (nonatomic, strong) UIFont *font;
@property (nonatomic, strong) UIColor *color;
@property (nonatomic) NSTextAlignment alignment;
@property (nonatomic) NSInteger numberOfLines;
@end
NS_SWIFT_UI_ACTOR
@interface UIListContentImageProperties : NSObject <NSCopying>
@property (nullable, nonatomic, strong) UIColor *tintColor;
@property (nonatomic) CGSize reservedLayoutSize;
@property (nonatomic) CGSize maximumSize;
@property (nonatomic) CGFloat cornerRadius;
@end
/* Swift: the UIContentConfiguration / UIContentView protocols of the UIKit overlay (custom configurations are Swift
   values there); ObjC configurations make their content view */
@protocol UIContentConfiguration <NSObject, NSCopying>
@optional
- (__kindof UIView *)makeContentView;
@end
NS_SWIFT_UI_ACTOR
@interface UIListContentConfiguration : NSObject <UIContentConfiguration>
+ (instancetype)cellConfiguration;
+ (instancetype)subtitleCellConfiguration;
+ (instancetype)valueCellConfiguration;
+ (instancetype)sidebarCellConfiguration;
+ (instancetype)groupedHeaderConfiguration;
+ (instancetype)groupedFooterConfiguration;
+ (instancetype)plainHeaderConfiguration;
+ (instancetype)plainFooterConfiguration;
+ (instancetype)headerConfiguration;
+ (instancetype)footerConfiguration;
@property (nullable, nonatomic, copy) NSString *text;
@property (nullable, nonatomic, copy) NSString *secondaryText;
@property (nullable, nonatomic, strong) UIImage *image;
@property (nonatomic, readonly) UIListContentTextProperties *textProperties;
@property (nonatomic, readonly) UIListContentTextProperties *secondaryTextProperties;
@property (nonatomic, readonly) UIListContentImageProperties *imageProperties;
@property (nonatomic) BOOL prefersSideBySideTextAndSecondaryText;
@property (nonatomic) CGFloat textToSecondaryTextVerticalPadding;
@property (nonatomic) NSDirectionalEdgeInsets directionalLayoutMargins;
@end
NS_SWIFT_UI_ACTOR
@interface UIListContentView : UIView
- (instancetype)initWithConfiguration:(UIListContentConfiguration *)configuration;
@property (nonatomic, copy) UIListContentConfiguration *configuration;
@end
NS_SWIFT_UI_ACTOR
@interface UIBackgroundConfiguration : NSObject <NSCopying>
+ (instancetype)listPlainCellConfiguration;
+ (instancetype)listGroupedCellConfiguration;
+ (instancetype)clearConfiguration;
@property (nullable, nonatomic, strong) UIColor *backgroundColor;
@property (nonatomic) CGFloat cornerRadius;
@end

typedef NS_ENUM(NSInteger, UITableViewCellStyle) { UITableViewCellStyleDefault, UITableViewCellStyleValue1, UITableViewCellStyleValue2, UITableViewCellStyleSubtitle };
typedef NS_ENUM(NSInteger, UITableViewCellAccessoryType) {
    UITableViewCellAccessoryNone, UITableViewCellAccessoryDisclosureIndicator, UITableViewCellAccessoryDetailDisclosureButton,
    UITableViewCellAccessoryCheckmark, UITableViewCellAccessoryDetailButton };
typedef NS_ENUM(NSInteger, UITableViewCellSelectionStyle) { UITableViewCellSelectionStyleNone, UITableViewCellSelectionStyleBlue, UITableViewCellSelectionStyleGray, UITableViewCellSelectionStyleDefault };
typedef NS_ENUM(NSInteger, UITableViewCellEditingStyle) { UITableViewCellEditingStyleNone, UITableViewCellEditingStyleDelete, UITableViewCellEditingStyleInsert };
typedef NS_ENUM(NSInteger, UITableViewCellSeparatorStyle) { UITableViewCellSeparatorStyleNone, UITableViewCellSeparatorStyleSingleLine };

NS_SWIFT_UI_ACTOR
@interface UITableViewCell : UIView
- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, strong) UIView *contentView;
@property (nullable, nonatomic, readonly, strong) UILabel *textLabel;
@property (nullable, nonatomic, readonly, strong) UILabel *detailTextLabel;
@property (nullable, nonatomic, readonly, strong) UIImageView *imageView;
@property (nullable, nonatomic, readonly, copy) NSString *reuseIdentifier;
- (void)prepareForReuse;
@property (nonatomic) UITableViewCellAccessoryType accessoryType;
@property (nullable, nonatomic, strong) UIView *accessoryView;
@property (nonatomic) UITableViewCellAccessoryType editingAccessoryType;
@property (nonatomic) UITableViewCellSelectionStyle selectionStyle;
@property (nonatomic, getter=isSelected) BOOL selected;
@property (nonatomic, getter=isHighlighted) BOOL highlighted;
- (void)setSelected:(BOOL)selected animated:(BOOL)animated;
- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated;
@property (nonatomic, getter=isEditing) BOOL editing;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
@property (nonatomic) BOOL showsReorderControl;
@property (nonatomic) UIEdgeInsets separatorInset;
@property (nonatomic) NSInteger indentationLevel;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nullable, nonatomic, strong) UIView *selectedBackgroundView;
@property (nullable, nonatomic, copy) id<UIContentConfiguration> contentConfiguration;
- (UIListContentConfiguration *)defaultContentConfiguration;
@property (nullable, nonatomic, copy) UIBackgroundConfiguration *backgroundConfiguration;
@property (nonatomic) BOOL automaticallyUpdatesContentConfiguration;
@end

NS_SWIFT_UI_ACTOR
@interface UITableViewHeaderFooterView : UIView
- (instancetype)initWithReuseIdentifier:(nullable NSString *)reuseIdentifier NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (nonatomic, readonly, strong) UIView *contentView;
@property (nullable, nonatomic, readonly, strong) UILabel *textLabel;
@property (nullable, nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nullable, nonatomic, copy) id<UIContentConfiguration> contentConfiguration;
- (UIListContentConfiguration *)defaultContentConfiguration;
- (void)prepareForReuse;
@end

typedef NS_ENUM(NSInteger, UIContextualActionStyle) { UIContextualActionStyleNormal, UIContextualActionStyleDestructive };
@class UIContextualAction;
typedef void (^UIContextualActionHandler)(UIContextualAction *action, UIView *sourceView, void (^completionHandler)(BOOL actionPerformed));
NS_SWIFT_UI_ACTOR
@interface UIContextualAction : NSObject
+ (instancetype)contextualActionWithStyle:(UIContextualActionStyle)style title:(nullable NSString *)title handler:(UIContextualActionHandler)handler;
@property (nonatomic, readonly) UIContextualActionStyle style;
@property (nonatomic, copy, readonly) UIContextualActionHandler handler;
@property (nullable, nonatomic, copy) NSString *title;
@property (nullable, nonatomic, copy) UIColor *backgroundColor;
@property (nullable, nonatomic, copy) UIImage *image;
@end
NS_SWIFT_UI_ACTOR
@interface UISwipeActionsConfiguration : NSObject
+ (instancetype)configurationWithActions:(NSArray<UIContextualAction *> *)actions;
@property (nonatomic, copy, readonly) NSArray<UIContextualAction *> *actions;
@property (nonatomic) BOOL performsFirstActionWithFullSwipe;
@end

typedef NS_ENUM(NSInteger, UITableViewStyle) { UITableViewStylePlain, UITableViewStyleGrouped, UITableViewStyleInsetGrouped };
typedef NS_ENUM(NSInteger, UITableViewScrollPosition) { UITableViewScrollPositionNone, UITableViewScrollPositionTop, UITableViewScrollPositionMiddle, UITableViewScrollPositionBottom };
typedef NS_ENUM(NSInteger, UITableViewRowAnimation) {
    UITableViewRowAnimationFade, UITableViewRowAnimationRight, UITableViewRowAnimationLeft, UITableViewRowAnimationTop, UITableViewRowAnimationBottom,
    UITableViewRowAnimationNone, UITableViewRowAnimationMiddle, UITableViewRowAnimationAutomatic = 100 };
UIKIT_EXTERN const CGFloat UITableViewAutomaticDimension;

@protocol UITableViewDataSource <NSObject>
@required
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section;
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath;
@optional
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView;
- (nullable NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section;
- (nullable NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section;
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath;
- (nullable NSArray<NSString *> *)sectionIndexTitlesForTableView:(UITableView *)tableView;
- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index;
@end
/* the magnifying glass at the top of a section index (jumps to the top of the table) */
UIKIT_EXTERN NSString *const UITableViewIndexSearch NS_SWIFT_NAME(UITableView.indexSearch);

/* prefetching: rows about to come on screen in the scrolling direction (a screen ahead) */
@protocol UITableViewDataSourcePrefetching <NSObject>
@required
- (void)tableView:(UITableView *)tableView prefetchRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
@optional
- (void)tableView:(UITableView *)tableView cancelPrefetchingForRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
@end

@class UIContextMenuConfiguration;
@protocol UIContextMenuInteractionAnimating, UIContextMenuInteractionCommitAnimating;
@protocol UITableViewDelegate <UIScrollViewDelegate>
@optional
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section;
- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section;
- (nullable UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section;
- (nullable UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath;
- (BOOL)tableView:(UITableView *)tableView shouldHighlightRowAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath;
- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSString *)tableView:(UITableView *)tableView titleForDeleteConfirmationButtonForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView leadingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable UISwipeActionsConfiguration *)tableView:(UITableView *)tableView trailingSwipeActionsConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath;
- (NSInteger)tableView:(UITableView *)tableView indentationLevelForRowAtIndexPath:(NSIndexPath *)indexPath;
/* context menus (UIContextMenuInteraction.h): a long press on a row */
- (nullable UIContextMenuConfiguration *)tableView:(UITableView *)tableView contextMenuConfigurationForRowAtIndexPath:(NSIndexPath *)indexPath point:(CGPoint)point;
- (void)tableView:(UITableView *)tableView willPerformPreviewActionForMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(id<UIContextMenuInteractionCommitAnimating>)animator;
- (void)tableView:(UITableView *)tableView willDisplayContextMenuWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
- (void)tableView:(UITableView *)tableView willEndContextMenuInteractionWithConfiguration:(UIContextMenuConfiguration *)configuration animator:(nullable id<UIContextMenuInteractionAnimating>)animator;
@end

NS_SWIFT_UI_ACTOR
@interface UITableView : UIScrollView
- (instancetype)initWithFrame:(CGRect)frame style:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithFrame:(CGRect)frame;
@property (nonatomic, readonly) UITableViewStyle style;
@property (nullable, nonatomic, weak) id<UITableViewDataSource> dataSource;
@property (nullable, nonatomic, weak) id<UITableViewDelegate> delegate;
@property (nonatomic) CGFloat rowHeight;
@property (nonatomic) CGFloat sectionHeaderHeight;
@property (nonatomic) CGFloat sectionFooterHeight;
@property (nonatomic) CGFloat estimatedRowHeight;
@property (nonatomic) CGFloat estimatedSectionHeaderHeight;
@property (nonatomic) CGFloat estimatedSectionFooterHeight;
@property (nonatomic) CGFloat sectionHeaderTopPadding;
@property (nonatomic) UIEdgeInsets separatorInset;
@property (nonatomic) UITableViewCellSeparatorStyle separatorStyle;
@property (nullable, nonatomic, strong) UIColor *separatorColor;
@property (nullable, nonatomic, strong) UIView *backgroundView;
@property (nullable, nonatomic, strong) UIView *tableHeaderView;
@property (nullable, nonatomic, strong) UIView *tableFooterView;
@property (nonatomic) BOOL allowsSelection;
@property (nonatomic) BOOL allowsMultipleSelection;
@property (nonatomic) BOOL allowsSelectionDuringEditing;
@property (nonatomic) BOOL allowsMultipleSelectionDuringEditing;
@property (nonatomic, getter=isEditing) BOOL editing;
- (void)setEditing:(BOOL)editing animated:(BOOL)animated;
@property (nonatomic, readonly) NSInteger numberOfSections;
- (NSInteger)numberOfRowsInSection:(NSInteger)section;
- (void)reloadData;
- (void)reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reloadRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)reconfigureRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths;
- (void)insertRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteRowsAtIndexPaths:(NSArray<NSIndexPath *> *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation;
- (void)insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation;
- (void)moveRowAtIndexPath:(NSIndexPath *)indexPath toIndexPath:(NSIndexPath *)newIndexPath;
- (void)beginUpdates;
- (void)endUpdates;
- (void)performBatchUpdates:(void (NS_NOESCAPE ^ _Nullable)(void))updates completion:(void (^ _Nullable)(BOOL finished))completion;
- (void)registerClass:(nullable Class)cellClass forCellReuseIdentifier:(NSString *)identifier;
- (void)registerClass:(nullable Class)aClass forHeaderFooterViewReuseIdentifier:(NSString *)identifier;
- (nullable __kindof UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier;
- (__kindof UITableViewCell *)dequeueReusableCellWithIdentifier:(NSString *)identifier forIndexPath:(NSIndexPath *)indexPath;
- (nullable __kindof UITableViewHeaderFooterView *)dequeueReusableHeaderFooterViewWithIdentifier:(NSString *)identifier;
- (nullable __kindof UITableViewCell *)cellForRowAtIndexPath:(NSIndexPath *)indexPath;
- (nullable NSIndexPath *)indexPathForCell:(UITableViewCell *)cell;
- (nullable NSIndexPath *)indexPathForRowAtPoint:(CGPoint)point;
@property (nonatomic, readonly) NSArray<__kindof UITableViewCell *> *visibleCells;
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForVisibleRows;
- (CGRect)rectForRowAtIndexPath:(NSIndexPath *)indexPath;
- (CGRect)rectForSection:(NSInteger)section;
- (nullable UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section;
@property (nullable, nonatomic, readonly) NSIndexPath *indexPathForSelectedRow;
@property (nullable, nonatomic, readonly) NSArray<NSIndexPath *> *indexPathsForSelectedRows;
- (void)selectRowAtIndexPath:(nullable NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition;
- (void)deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void)scrollToRowAtIndexPath:(NSIndexPath *)indexPath atScrollPosition:(UITableViewScrollPosition)scrollPosition animated:(BOOL)animated;
/* section index (the titles from sectionIndexTitlesForTableView: along the trailing edge; tap or drag to jump) */
@property (nonatomic) NSInteger sectionIndexMinimumDisplayRowCount;
@property (nullable, nonatomic, strong) UIColor *sectionIndexColor;
@property (nullable, nonatomic, strong) UIColor *sectionIndexBackgroundColor;
@property (nullable, nonatomic, strong) UIColor *sectionIndexTrackingBackgroundColor;
- (void)reloadSectionIndexTitles;
@property (nullable, nonatomic, weak) id<UITableViewDataSourcePrefetching> prefetchDataSource;
@property (nonatomic, getter=isPrefetchingEnabled) BOOL prefetchingEnabled;
- (nullable UITableViewHeaderFooterView *)footerViewForSection:(NSInteger)section;
@end

NS_SWIFT_UI_ACTOR
@interface UITableViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>
- (instancetype)initWithStyle:(UITableViewStyle)style NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (null_resettable, nonatomic, strong) UITableView *tableView;
@property (nonatomic) BOOL clearsSelectionOnViewWillAppear;
@end
NS_ASSUME_NONNULL_END
