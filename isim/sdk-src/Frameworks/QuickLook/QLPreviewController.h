#pragma once
#import <UIKit/UIKit.h>
#import <QuickLook/QLPreviewItem.h>
NS_ASSUME_NONNULL_BEGIN
@class QLPreviewController;

typedef NS_ENUM(NSInteger, QLPreviewItemEditingMode) {
    QLPreviewItemEditingModeDisabled = 0, QLPreviewItemEditingModeUpdateContents, QLPreviewItemEditingModeCreateCopy,
} API_AVAILABLE(ios(13.0));

@protocol QLPreviewControllerDataSource <NSObject>
@required
- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)controller;
- (id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index;
@end

@protocol QLPreviewControllerDelegate <NSObject>
@optional
- (void)previewControllerWillDismiss:(QLPreviewController *)controller;
- (void)previewControllerDidDismiss:(QLPreviewController *)controller;
- (BOOL)previewController:(QLPreviewController *)controller shouldOpenURL:(NSURL *)url forPreviewItem:(id<QLPreviewItem>)item;
- (CGRect)previewController:(QLPreviewController *)controller frameForPreviewItem:(id<QLPreviewItem>)item inSourceView:(UIView *_Nullable *_Nonnull)view;
- (nullable UIImage *)previewController:(QLPreviewController *)controller transitionImageForPreviewItem:(id<QLPreviewItem>)item contentRect:(CGRect *)contentRect;
- (nullable UIView *)previewController:(QLPreviewController *)controller transitionViewForPreviewItem:(id<QLPreviewItem>)item;
- (QLPreviewItemEditingMode)previewController:(QLPreviewController *)controller editingModeForPreviewItem:(id<QLPreviewItem>)previewItem API_AVAILABLE(ios(13.0));
- (void)previewController:(QLPreviewController *)controller didUpdateContentsOfPreviewItem:(id<QLPreviewItem>)previewItem API_AVAILABLE(ios(13.0));
- (void)previewController:(QLPreviewController *)controller didSaveEditedCopyOfPreviewItem:(id<QLPreviewItem>)previewItem atURL:(NSURL *)modifiedContentsURL API_AVAILABLE(ios(13.0));
@end

/* isim: presented on its own it shows a bar with Done (left) and Share (right); pushed, it uses the navigation bar.
 * Swipe left / right between items. No Markup (editing modes are reported as disabled). */
@interface QLPreviewController : UIViewController
+ (BOOL)canPreviewItem:(id<QLPreviewItem>)item NS_SWIFT_NAME(canPreview(_:));
@property (nullable, weak, nonatomic) id<QLPreviewControllerDataSource> dataSource;
@property (nullable, weak, nonatomic) id<QLPreviewControllerDelegate> delegate;
@property (nonatomic) NSInteger currentPreviewItemIndex;
@property (readonly, nullable, nonatomic) id<QLPreviewItem> currentPreviewItem;
- (void)reloadData;
- (void)refreshCurrentPreviewItem;
@end
NS_ASSUME_NONNULL_END
