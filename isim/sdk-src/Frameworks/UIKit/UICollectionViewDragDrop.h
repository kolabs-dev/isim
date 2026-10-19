#pragma once
/* isim: collection view drag and drop (Apple declares it in UICollectionView.h) for Objective-C. The classes are the UIKit Swift overlay's (objc_runtime_visible: Objective-C finds
   them through the runtime, so it cannot subclass them or add categories to them; UIKit loads the overlay on first use);
   Swift code uses the overlay's own declarations, so this header is hidden from Swift. */
#import <UIKit/UIKitDefines.h>
#import <UIKit/UICollectionView.h>
#import <UIKit/UIDropInteraction.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIDragItem, UICollectionViewDropProposal;
@protocol UIDragSession, UIDropSession, UIDragAnimating, UICollectionViewDragDelegate, UICollectionViewDropDelegate, UICollectionViewDropCoordinator;
typedef NS_ENUM(NSInteger, UICollectionViewDropIntent) {
    UICollectionViewDropIntentUnspecified, UICollectionViewDropIntentInsertAtDestinationIndexPath,
    UICollectionViewDropIntentInsertIntoDestinationIndexPath,
} API_AVAILABLE(ios(11.0));
ISIM_RUNTIME_VISIBLE NS_SWIFT_UI_ACTOR
@interface UICollectionViewDropProposal : UIDropProposal
- (instancetype)initWithDropOperation:(UIDropOperation)operation intent:(UICollectionViewDropIntent)intent;
@property (nonatomic, readonly) UICollectionViewDropIntent intent;
@end
NS_SWIFT_UI_ACTOR
@protocol UICollectionViewDropItem <NSObject>
@property (nonatomic, readonly) UIDragItem *dragItem;
@property (nullable, nonatomic, readonly) NSIndexPath *sourceIndexPath;
@property (nonatomic, readonly) CGSize previewSize;
@end
NS_SWIFT_UI_ACTOR
@protocol UICollectionViewDropCoordinator <NSObject>
@property (nonatomic, readonly) NSArray<id<UICollectionViewDropItem>> *items;
@property (nullable, nonatomic, readonly) NSIndexPath *destinationIndexPath;
@property (nonatomic, readonly) UICollectionViewDropProposal *proposal;
@property (nonatomic, readonly) id<UIDropSession> session;
- (id<UIDragAnimating>)dropItem:(UIDragItem *)dragItem toItemAtIndexPath:(NSIndexPath *)indexPath;
@end
NS_SWIFT_UI_ACTOR
@protocol UICollectionViewDragDelegate <NSObject>
@required
- (NSArray<UIDragItem *> *)collectionView:(UICollectionView *)collectionView itemsForBeginningDragSession:(id<UIDragSession>)session atIndexPath:(NSIndexPath *)indexPath;
@end
NS_SWIFT_UI_ACTOR
@protocol UICollectionViewDropDelegate <NSObject>
@required
- (void)collectionView:(UICollectionView *)collectionView performDropWithCoordinator:(id<UICollectionViewDropCoordinator>)coordinator;
@optional
- (BOOL)collectionView:(UICollectionView *)collectionView canHandleDropSession:(id<UIDropSession>)session;
- (UICollectionViewDropProposal *)collectionView:(UICollectionView *)collectionView dropSessionDidUpdate:(id<UIDropSession>)session withDestinationIndexPath:(nullable NSIndexPath *)destinationIndexPath;
@end
@interface UICollectionView (UIDragAndDrop)
@property (nullable, nonatomic, weak) id<UICollectionViewDragDelegate> dragDelegate API_AVAILABLE(ios(11.0));
@property (nullable, nonatomic, weak) id<UICollectionViewDropDelegate> dropDelegate API_AVAILABLE(ios(11.0));
@property (nonatomic) BOOL dragInteractionEnabled API_AVAILABLE(ios(11.0));
@property (nonatomic, readonly) BOOL hasActiveDrag API_AVAILABLE(ios(11.0));
@end
NS_ASSUME_NONNULL_END
#endif
