#pragma once
/* isim: UIActivityViewController — a share sheet with a preview of the items, Copy (to UIPasteboard.general) and
   the app's own UIActivity objects. There are no other apps to share to on isim (no AirDrop, Messages, Mail rows). */
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIActivityViewController;

typedef NSString *UIActivityType NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(UIActivity.ActivityType);
UIKIT_EXTERN UIActivityType const UIActivityTypePostToFacebook, UIActivityTypePostToTwitter, UIActivityTypePostToWeibo,
    UIActivityTypeMessage, UIActivityTypeMail, UIActivityTypePrint, UIActivityTypeCopyToPasteboard, UIActivityTypeAssignToContact,
    UIActivityTypeSaveToCameraRoll, UIActivityTypeAddToReadingList, UIActivityTypePostToFlickr, UIActivityTypePostToVimeo,
    UIActivityTypePostToTencentWeibo, UIActivityTypeAirDrop, UIActivityTypeOpenInIBooks, UIActivityTypeMarkupAsPDF,
    UIActivityTypeSharePlay, UIActivityTypeCollaborationInviteWithLink, UIActivityTypeCollaborationCopyLink, UIActivityTypeAddToHomeScreen;
typedef NS_ENUM(NSInteger, UIActivityCategory) { UIActivityCategoryAction, UIActivityCategoryShare };

NS_SWIFT_UI_ACTOR
@interface UIActivity : NSObject
@property (class, nonatomic, readonly) UIActivityCategory activityCategory;
@property (nullable, nonatomic, readonly) UIActivityType activityType;
@property (nullable, nonatomic, readonly) NSString *activityTitle;
@property (nullable, nonatomic, readonly) UIImage *activityImage;
- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems;
- (void)prepareWithActivityItems:(NSArray *)activityItems;
@property (nullable, nonatomic, readonly) UIViewController *activityViewController;
- (void)performActivity;
- (void)activityDidFinish:(BOOL)completed;
@end

NS_SWIFT_UI_ACTOR
@protocol UIActivityItemSource <NSObject>
@required
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController;
- (nullable id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(nullable UIActivityType)activityType;
@optional
- (NSString *)activityViewController:(UIActivityViewController *)activityViewController subjectForActivityType:(nullable UIActivityType)activityType;
@end

typedef void (^UIActivityViewControllerCompletionWithItemsHandler)(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError);

NS_SWIFT_UI_ACTOR
@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)activityItems applicationActivities:(nullable NSArray<__kindof UIActivity *> *)applicationActivities;
@property (nullable, nonatomic, copy) UIActivityViewControllerCompletionWithItemsHandler completionWithItemsHandler;
@property (nullable, nonatomic, copy) NSArray<UIActivityType> *excludedActivityTypes;
@property (nonatomic) BOOL allowsProminentActivity;
@end
NS_ASSUME_NONNULL_END
