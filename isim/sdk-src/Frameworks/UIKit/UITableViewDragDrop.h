#pragma once
/* isim: table view drag and drop (Apple declares it in UITableView.h) for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UITableView.h>
#import <UIKit/UIDropInteraction.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIDragItem, UITableViewDropProposal;
@protocol UIDragSession, UIDropSession, UIDragAnimating, UITableViewDragDelegate, UITableViewDropDelegate, UITableViewDropCoordinator;
typedef NS_ENUM(NSInteger, UITableViewDropIntent) {
    UITableViewDropIntentUnspecified, UITableViewDropIntentInsertAtDestinationIndexPath,
    UITableViewDropIntentInsertIntoDestinationIndexPath, UITableViewDropIntentAutomatic,
} API_AVAILABLE(ios(11.0));
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UITableViewDropProposal : UIDropProposal
- (instancetype)initWithDropOperation:(UIDropOperation)operation intent:(UITableViewDropIntent)intent;
@property (nonatomic, readonly) UITableViewDropIntent intent;
@end
NS_SWIFT_UI_ACTOR
@protocol UITableViewDropItem <NSObject>
@property (nonatomic, readonly) UIDragItem *dragItem;
@property (nullable, nonatomic, readonly) NSIndexPath *sourceIndexPath;
@property (nonatomic, readonly) CGSize previewSize;
@end
NS_SWIFT_UI_ACTOR
@protocol UITableViewDropCoordinator <NSObject>
@property (nonatomic, readonly) NSArray<id<UITableViewDropItem>> *items;
@property (nullable, nonatomic, readonly) NSIndexPath *destinationIndexPath;
@property (nonatomic, readonly) UITableViewDropProposal *proposal;
@property (nonatomic, readonly) id<UIDropSession> session;
- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toRowAtIndexPath:(NSIndexPath *)indexPath;
@end
NS_SWIFT_UI_ACTOR
@protocol UITableViewDragDelegate <NSObject>
@required
- (NSArray<UIDragItem *> *)tableView:(UITableView *)tableView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath;
@optional
- (void)tableView:(UITableView *)tableView dragSessionWillBegin:(id<UIDragSession>)session;
- (void)tableView:(UITableView *)tableView dragSessionDidEnd:(id<UIDragSession>)session;
@end
NS_SWIFT_UI_ACTOR
@protocol UITableViewDropDelegate <NSObject>
@required
- (void)tableView:(UITableView *)tableView performDropWithCoordinator:(id<UITableViewDropCoordinator>)coordinator;
@optional
- (BOOL)tableView:(UITableView *)tableView canHandleDropSession:(id<UIDropSession>)session;
- (UITableViewDropProposal *)tableView:(UITableView *)tableView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(nullable NSIndexPath *)destinationIndexPath;
@end
@interface UITableView (UIDragAndDrop)
@property (nullable, nonatomic, weak) id<UITableViewDragDelegate> dragDelegate API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, weak) id<UITableViewDropDelegate> dropDelegate API_AVAILABLE(ios(11.0));
@property (nonatomic) BOOL dragInteractionEnabled API_AVAILABLE(ios(11.0));
@property (nonatomic, readonly) BOOL hasActiveDrag API_AVAILABLE(ios(11.0));
@end
NS_ASSUME_NONNULL_END
#endif
