#pragma once
/* isim: UIActivityViewController — a share sheet with a preview of the items, a row of Share extensions (the app's own
   and, under `isim boot`, those of installed apps), Copy (to UIPasteboard.general), Action extensions and the app's own
   UIActivity objects. Extensions are filtered by their NSExtensionActivationRule and hosted in the app's process (their
   view controller is presented as a sheet; completeRequest / cancelRequest come back here). No AirDrop, Messages, Mail. */
#import <UIKit/UIViewController.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIActivityViewController, NSItemProvider, LPLinkMetadata, INPerson;
@protocol NSItemProviderWriting;

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
/* rich previews and share recipients (LinkPresentation and Intents are not in isim's SDK: not asked) */
- (nullable LPLinkMetadata *)activityViewControllerLinkMetadata:(UIActivityViewController *)activityViewController API_AVAILABLE(ios(13.0));
- (NSArray<INPerson *> *)activityViewControllerShareRecipients:(UIActivityViewController *)activityViewController API_AVAILABLE(ios(18.0));
@end

/* an item made when an activity needs it (iOS 6): the placeholder stands in until then; subclasses override item
   (activityType says which activity asks) */
@interface UIActivityItemProvider : NSOperation <UIActivityItemSource>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithPlaceholderItem:(id)placeholderItem NS_DESIGNATED_INITIALIZER;
@property (nullable, nonatomic, strong, readonly) id placeholderItem;
@property (nullable, nonatomic, copy, readonly) UIActivityType activityType;
@property (nonnull, nonatomic, readonly) id item;
@end

/* ---- activity items configurations (iOS 13): item providers with metadata, shared by the share sheet ---- */
typedef NSString *UIActivityItemsConfigurationMetadataKey NS_TYPED_ENUM API_AVAILABLE(ios(13.0));
UIKIT_EXTERN UIActivityItemsConfigurationMetadataKey const UIActivityItemsConfigurationMetadataKeyTitle, UIActivityItemsConfigurationMetadataKeyMessageBody,
    UIActivityItemsConfigurationMetadataKeyLinkPresentationMetadata API_AVAILABLE(ios(15.0)),
    UIActivityItemsConfigurationMetadataKeyShareRecipients API_AVAILABLE(ios(18.0)),
    UIActivityItemsConfigurationMetadataKeyCollaborationModeRestrictions API_AVAILABLE(ios(18.0));
typedef NSString *UIActivityItemsConfigurationPreviewIntent NS_TYPED_ENUM API_AVAILABLE(ios(13.0));
UIKIT_EXTERN UIActivityItemsConfigurationPreviewIntent const UIActivityItemsConfigurationPreviewIntentFullSize, UIActivityItemsConfigurationPreviewIntentThumbnail;
typedef NSString *UIActivityItemsConfigurationInteraction NS_TYPED_ENUM API_AVAILABLE(ios(13.0));
UIKIT_EXTERN UIActivityItemsConfigurationInteraction const UIActivityItemsConfigurationInteractionShare,
    UIActivityItemsConfigurationInteractionCopy API_AVAILABLE(ios(16.4));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@protocol UIActivityItemsConfigurationReading <NSObject>
@property (nonatomic, readonly, copy) NSArray<NSItemProvider *> *itemProvidersForActivityItemsConfiguration;
@optional
- (BOOL)activityItemsConfigurationSupportsInteraction:(UIActivityItemsConfigurationInteraction)interaction;
- (nullable id)activityItemsConfigurationMetadataForKey:(UIActivityItemsConfigurationMetadataKey)key;
- (nullable id)activityItemsConfigurationMetadataForItemAtIndex:(NSInteger)index key:(UIActivityItemsConfigurationMetadataKey)key;
- (nullable NSItemProvider *)activityItemsConfigurationPreviewForItemAtIndex:(NSInteger)index intent:(UIActivityItemsConfigurationPreviewIntent)intent suggestedSize:(CGSize)suggestedSize;
@property (nonatomic, readonly, copy) NSArray<UIActivity *> *applicationActivitiesForActivityItemsConfiguration;
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UIActivityItemsConfiguration : NSObject <UIActivityItemsConfigurationReading>
+ (instancetype)activityItemsConfigurationWithObjects:(NSArray<id<NSItemProviderWriting>> *)objects NS_SWIFT_UNAVAILABLE("use init(objects:)");
+ (instancetype)activityItemsConfigurationWithItemProviders:(NSArray<NSItemProvider *> *)itemProviders NS_SWIFT_UNAVAILABLE("use init(itemProviders:)");
- (instancetype)initWithObjects:(NSArray<id<NSItemProviderWriting>> *)objects;
- (instancetype)initWithItemProviders:(NSArray<NSItemProvider *> *)itemProviders NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, nonatomic, strong) id localObject;
@property (nonatomic, copy) NSArray<UIActivityItemsConfigurationInteraction> *supportedInteractions;
@property (nullable, nonatomic, copy) id _Nullable (^metadataProvider)(UIActivityItemsConfigurationMetadataKey key);
@property (nullable, nonatomic, copy) id _Nullable (^perItemMetadataProvider)(NSInteger index, UIActivityItemsConfigurationMetadataKey key);
@property (nullable, nonatomic, copy) NSItemProvider *_Nullable (^previewProvider)(NSInteger index, UIActivityItemsConfigurationPreviewIntent intent, CGSize suggestedSize);
@property (nullable, nonatomic, copy) NSArray<UIActivity *> *(^applicationActivitiesProvider)(void);
@end
/* responders (and scenes) that give the activity items for the share menu / sharing the scene (iOS 15) */
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(15.0))
@protocol UIActivityItemsConfigurationProviding <NSObject>
@property (nullable, nonatomic, readonly, strong) id<UIActivityItemsConfigurationReading> activityItemsConfiguration;
@end

@interface UIResponder (UIActivityItemsConfiguration) <UIActivityItemsConfigurationProviding>
@property (nullable, nonatomic, strong) id<UIActivityItemsConfigurationReading> activityItemsConfiguration API_AVAILABLE(ios(15.0));
@end
/* iOS 18: collaboration (isim shares copies only: stored) and the sections the sheet may leave out */
typedef NS_ENUM(NSInteger, UIActivityCollaborationMode) { UIActivityCollaborationModeSendCopy = 0, UIActivityCollaborationModeCollaborate = 1 } API_AVAILABLE(ios(18.0));
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(18.0)) NS_SWIFT_NAME(UIActivityViewController.CollaborationModeRestriction)
@interface UIActivityCollaborationModeRestriction : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithDisabledMode:(UIActivityCollaborationMode)disabledMode;
- (instancetype)initWithDisabledMode:(UIActivityCollaborationMode)disabledMode alertTitle:(NSString *)alertTitle alertMessage:(NSString *)alertMessage;
- (instancetype)initWithDisabledMode:(UIActivityCollaborationMode)disabledMode alertTitle:(NSString *)alertTitle alertMessage:(NSString *)alertMessage alertDismissButtonTitle:(NSString *)alertDismissButtonTitle;
- (instancetype)initWithDisabledMode:(UIActivityCollaborationMode)disabledMode alertTitle:(NSString *)alertTitle alertMessage:(NSString *)alertMessage
             alertDismissButtonTitle:(NSString *)alertDismissButtonTitle alertRecoverySuggestionButtonTitle:(NSString *)alertRecoverySuggestionButtonTitle
      alertRecoverySuggestionButtonLaunchURL:(NSURL *)alertRecoverySuggestionButtonLaunchURL NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly) UIActivityCollaborationMode disabledMode;
@property (nullable, nonatomic, readonly) NSString *alertTitle, *alertMessage, *alertDismissButtonTitle, *alertRecoverySuggestionButtonTitle;
@property (nullable, nonatomic, readonly) NSURL *alertRecoverySuggestionButtonLaunchURL;
@end
typedef NS_OPTIONS(NSUInteger, UIActivitySectionTypes) { UIActivitySectionTypesNone = 0, UIActivitySectionTypesPeopleSuggestions = 1 << 0 } API_AVAILABLE(ios(18.0));

typedef void (^UIActivityViewControllerCompletionWithItemsHandler)(UIActivityType _Nullable activityType, BOOL completed, NSArray * _Nullable returnedItems, NSError * _Nullable activityError);

NS_SWIFT_UI_ACTOR
@interface UIActivityViewController : UIViewController
- (instancetype)initWithActivityItems:(NSArray *)activityItems applicationActivities:(nullable NSArray<__kindof UIActivity *> *)applicationActivities;
@property (nullable, nonatomic, copy) UIActivityViewControllerCompletionWithItemsHandler completionWithItemsHandler;
@property (nullable, nonatomic, copy) NSArray<UIActivityType> *excludedActivityTypes;
@property (nonatomic) BOOL allowsProminentActivity;
@end
@interface UIActivityViewController (UIActivityItemsConfiguration)
/* the configuration's item providers, its title metadata in the preview, its application activities */
- (instancetype)initWithActivityItemsConfiguration:(id<UIActivityItemsConfigurationReading>)activityItemsConfiguration API_AVAILABLE(ios(14.0));
/* isim's sheet has no people suggestions: stored */
@property (nonatomic) UIActivitySectionTypes excludedActivitySectionTypes API_AVAILABLE(ios(18.0));
@end
NS_ASSUME_NONNULL_END
