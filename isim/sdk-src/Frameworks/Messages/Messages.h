#pragma once
/* isim Messages for Objective-C: iMessage apps and sticker packs. The classes are the Messages Swift overlay's
   (Messages.framework re-exports libswiftMessages.dylib), hosted by isim's Messages app; Swift uses the overlay, so
   these declarations are hidden from Swift. MSMessagesAppViewController and MSStickerBrowserViewController can be
   subclassed. MSCriticalSMSMessenger is Swift only, like Apple's. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const MSMessagesErrorDomain;
FOUNDATION_EXPORT NSString * const MSStickersErrorDomain;
typedef NS_ENUM(NSInteger, MSMessageErrorCode) {
    MSMessageErrorCodeUnknown = -1,
    MSMessageErrorCodeFileNotFound = 1,
    MSMessageErrorCodeFileUnreadable,
    MSMessageErrorCodeImproperFileType,
    MSMessageErrorCodeImproperFileURL,
    MSMessageErrorCodeStickerFileImproperFileAttributes,
    MSMessageErrorCodeStickerFileImproperFileSize,
    MSMessageErrorCodeStickerFileImproperFileFormat,
    MSMessageErrorCodeURLExceedsMaxSize,
    MSMessageErrorCodeSendWhileNotVisible,
    MSMessageErrorCodeSendWithoutRecentInteraction,
    MSMessageErrorCodeAPIUnavailableInPresentationContext,
};
typedef NS_ENUM(NSUInteger, MSMessagesAppPresentationStyle) {
    MSMessagesAppPresentationStyleCompact, MSMessagesAppPresentationStyleExpanded, MSMessagesAppPresentationStyleTranscript,
};
typedef NS_ENUM(NSUInteger, MSMessagesAppPresentationContext) {
    MSMessagesAppPresentationContextMessages, MSMessagesAppPresentationContextMedia,
};
typedef NS_ENUM(NSInteger, MSStickerSize) { MSStickerSizeSmall, MSStickerSizeRegular, MSStickerSizeLarge };

@class MSConversation, MSMessage, MSSticker, MSStickerBrowserView;

@interface MSSession : NSObject <NSSecureCoding>
@end

@interface MSMessageLayout : NSObject <NSCopying>
@end
@interface MSMessageTemplateLayout : MSMessageLayout
@property (nonatomic, nullable, strong) UIImage *image;
@property (nonatomic, nullable, copy) NSURL *mediaFileURL;
@property (nonatomic, nullable, copy) NSString *imageTitle;
@property (nonatomic, nullable, copy) NSString *imageSubtitle;
@property (nonatomic, nullable, copy) NSString *caption;
@property (nonatomic, nullable, copy) NSString *subcaption;
@property (nonatomic, nullable, copy) NSString *trailingCaption;
@property (nonatomic, nullable, copy) NSString *trailingSubcaption;
@end
@interface MSMessageLiveLayout : MSMessageLayout
- (instancetype)initWithAlternateLayout:(MSMessageTemplateLayout *)alternateLayout NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) MSMessageTemplateLayout *alternateLayout;
@end

@interface MSMessage : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithSession:(MSSession *)session;
- (instancetype)init;
@property (nonatomic, readonly, nullable) MSSession *session;
@property (nonatomic, readonly) BOOL isPending;
@property (nonatomic, readonly) NSUUID *senderParticipantIdentifier;
@property (nonatomic, nullable, copy) MSMessageLayout *layout;
@property (nonatomic, nullable, copy) NSURL *URL;
@property (nonatomic, assign) BOOL shouldExpire;
@property (nonatomic, nullable, copy) NSString *accessibilityLabel;
@property (nonatomic, nullable, copy) NSString *summaryText;
@property (nonatomic, nullable, copy) NSError *error;
@end

@interface MSSticker : NSObject
- (nullable instancetype)initWithContentsOfFileURL:(NSURL *)fileURL localizedDescription:(NSString *)localizedDescription error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, strong, readonly) NSURL *imageFileURL;
@property (nonatomic, copy, readonly) NSString *localizedDescription;
@end

@interface MSStickerView : UIView
- (instancetype)initWithFrame:(CGRect)frame sticker:(nullable MSSticker *)sticker;
@property (nonatomic, strong, nullable) MSSticker *sticker;
@property (nonatomic, readonly) NSTimeInterval animationDuration;
- (void)startAnimating;
- (void)stopAnimating;
- (BOOL)isAnimating;
@end

@protocol MSStickerBrowserViewDataSource <NSObject>
- (NSInteger)numberOfStickersInStickerBrowserView:(MSStickerBrowserView *)stickerBrowserView;
- (MSSticker *)stickerBrowserView:(MSStickerBrowserView *)stickerBrowserView stickerAtIndex:(NSInteger)index;
@end
@interface MSStickerBrowserView : UIView
- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithFrame:(CGRect)frame stickerSize:(MSStickerSize)stickerSize;
@property (nonatomic, assign, readonly) MSStickerSize stickerSize;
@property (nonatomic, weak, nullable) id<MSStickerBrowserViewDataSource> dataSource;
@property (nonatomic, assign) CGPoint contentOffset;
@property (nonatomic, assign) UIEdgeInsets contentInset;
- (void)setContentOffset:(CGPoint)contentOffset animated:(BOOL)animated;
- (void)reloadData;
@end
@interface MSStickerBrowserViewController : UIViewController <MSStickerBrowserViewDataSource, NSExtensionRequestHandling>
- (instancetype)initWithStickerSize:(MSStickerSize)stickerSize NS_DESIGNATED_INITIALIZER;
@property (nonatomic, strong, readonly) MSStickerBrowserView *stickerBrowserView;
@property (nonatomic, readonly) MSStickerSize stickerSize;
@end

@interface MSConversation : NSObject
@property (nonatomic, readonly) NSUUID *localParticipantIdentifier;
@property (nonatomic, readonly) NSArray<NSUUID *> *remoteParticipantIdentifiers;
@property (nonatomic, readonly, nullable) MSMessage *selectedMessage;
- (void)insertMessage:(MSMessage *)message completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)insertSticker:(MSSticker *)sticker completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)insertText:(NSString *)text completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)insertAttachment:(NSURL *)URL withAlternateFilename:(nullable NSString *)filename completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)sendMessage:(MSMessage *)message completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)sendSticker:(MSSticker *)sticker completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)sendText:(NSString *)text completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
- (void)sendAttachment:(NSURL *)URL withAlternateFilename:(nullable NSString *)filename completionHandler:(nullable void (^)(NSError * _Nullable error))completionHandler;
@end

@protocol MSMessagesAppTranscriptPresentation
- (CGSize)contentSizeThatFits:(CGSize)size;
@property (nonatomic, readonly) CGFloat messageCornerRadius API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, nullable) UIColor *messageTintColor API_AVAILABLE(ios(26.0));
- (void)invalidateMessageTintColor API_AVAILABLE(ios(26.0));
@end

@interface MSMessagesAppViewController : UIViewController <MSMessagesAppTranscriptPresentation, NSExtensionRequestHandling>
@property (nonatomic, strong, readonly, nullable) MSConversation *activeConversation;
@property (nonatomic, assign, readonly) MSMessagesAppPresentationStyle presentationStyle;
@property (nonatomic, assign, readonly) MSMessagesAppPresentationContext presentationContext;
- (void)requestPresentationStyle:(MSMessagesAppPresentationStyle)presentationStyle;
- (void)dismiss;
- (void)willBecomeActiveWithConversation:(MSConversation *)conversation;
- (void)didBecomeActiveWithConversation:(MSConversation *)conversation;
- (void)willResignActiveWithConversation:(MSConversation *)conversation;
- (void)didResignActiveWithConversation:(MSConversation *)conversation;
- (void)willSelectMessage:(MSMessage *)message conversation:(MSConversation *)conversation;
- (void)didSelectMessage:(MSMessage *)message conversation:(MSConversation *)conversation;
- (void)didReceiveMessage:(MSMessage *)message conversation:(MSConversation *)conversation;
- (void)didStartSendingMessage:(MSMessage *)message conversation:(MSConversation *)conversation;
- (void)didCancelSendingMessage:(MSMessage *)message conversation:(MSConversation *)conversation;
- (void)willTransitionToPresentationStyle:(MSMessagesAppPresentationStyle)presentationStyle;
- (void)didTransitionToPresentationStyle:(MSMessagesAppPresentationStyle)presentationStyle;
@end

API_AVAILABLE(ios(27.0))
@interface MSUPIRequest : NSObject
- (instancetype)initWithValidationToken:(NSString *)validationToken recipients:(NSArray<NSString *> *)recipients;
@property (nonatomic, readonly, copy) NSString *validationToken;
@property (nonatomic, readonly, copy) NSArray<NSString *> *recipients;
- (void)sendWithCompletionHandler:(void (^)(BOOL success))completionHandler;
@end

NS_ASSUME_NONNULL_END
#else
@class MSConversation, MSMessage, MSSticker, MSSession, MSMessagesAppViewController;
#endif
