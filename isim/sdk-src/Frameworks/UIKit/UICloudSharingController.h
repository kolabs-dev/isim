#pragma once
#import <UIKit/UIViewController.h>

@class CKContainer, CKShare, UICloudSharingController;
@protocol UIActivityItemSource;

typedef NS_OPTIONS(NSUInteger, UICloudSharingPermissionOptions) {
    UICloudSharingPermissionStandard = 0,
    UICloudSharingPermissionAllowPublic = 1 << 0,
    UICloudSharingPermissionAllowPrivate = 1 << 1,
    UICloudSharingPermissionAllowReadOnly = 1 << 2,
    UICloudSharingPermissionAllowReadWrite = 1 << 3,
};

@protocol UICloudSharingControllerDelegate <NSObject>
- (void)cloudSharingControllerDidSaveShare:(UICloudSharingController *)csc;
- (void)cloudSharingControllerDidStopSharing:(UICloudSharingController *)csc;
- (NSString *)itemTitleForCloudSharingController:(UICloudSharingController *)csc;
@optional
- (NSData *)itemThumbnailDataForCloudSharingController:(UICloudSharingController *)csc;
- (NSString *)itemTypeForCloudSharingController:(UICloudSharingController *)csc;
@end

typedef void (^UICloudSharingControllerPreparationCompletionHandler)(CKShare *share, CKContainer *container, NSError *error);
typedef void (^UICloudSharingControllerPreparationHandler)(UICloudSharingController *controller, UICloudSharingControllerPreparationCompletionHandler preparationCompletionHandler);

/// isim presents a local sharing sheet. It edits the supplied CKShare but cannot send iCloud invitations.
@interface UICloudSharingController : UIViewController
@property (nullable, nonatomic, weak) id<UICloudSharingControllerDelegate> delegate;
@property (nonatomic) UICloudSharingPermissionOptions availablePermissions;
@property (nullable, nonatomic, readonly) CKShare *share;
@property (nullable, nonatomic, readonly) CKContainer *container;
@property (nullable, nonatomic, strong) id<UIActivityItemSource> activityItemSource;
- (instancetype)initWithShare:(CKShare *)share container:(CKContainer *)container;
- (instancetype)initWithPreparationHandler:(UICloudSharingControllerPreparationHandler)preparationHandler;
@end
