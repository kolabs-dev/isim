#pragma once
/* isim MessageUI for Objective-C: the compose sheets are the MessageUI Swift overlay's (MessageUI.framework re-exports
   libswiftMessageUI.dylib); canSendMail / canSendText follow ISIM_MAIL / ISIM_MESSAGES (see the overlay). Swift uses
   the overlay; these declarations are hidden from Swift. The classes are not subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MFMailComposeViewController, MFMessageComposeViewController;
typedef NS_ENUM(NSInteger, MFMailComposeResult) { MFMailComposeResultCancelled, MFMailComposeResultSaved, MFMailComposeResultSent, MFMailComposeResultFailed };
typedef NS_ENUM(NSInteger, MessageComposeResult) { MessageComposeResultCancelled, MessageComposeResultSent, MessageComposeResultFailed };
FOUNDATION_EXPORT NSErrorDomain const MFMailComposeErrorDomain;
typedef NS_ENUM(NSInteger, MFMailComposeErrorCode) { MFMailComposeErrorCodeSaveFailed, MFMailComposeErrorCodeSendFailed };
FOUNDATION_EXPORT NSString * const MFMessageComposeViewControllerAttachmentURL;
FOUNDATION_EXPORT NSString * const MFMessageComposeViewControllerAttachmentAlternateFilename;
FOUNDATION_EXPORT NSString * const MFMessageComposeViewControllerTextMessageAvailabilityKey;
FOUNDATION_EXPORT NSNotificationName const MFMessageComposeViewControllerTextMessageAvailabilityDidChangeNotification;
@protocol MFMailComposeViewControllerDelegate <NSObject>
@optional
- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(nullable NSError *)error;
@end
@protocol MFMessageComposeViewControllerDelegate <NSObject>
@required
- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result;
@end
@interface MFMailComposeViewController : UINavigationController
+ (BOOL)canSendMail;
@property (nonatomic, nullable, weak) id<MFMailComposeViewControllerDelegate> mailComposeDelegate;
- (void)setSubject:(NSString *)subject;
- (void)setToRecipients:(nullable NSArray<NSString *> *)toRecipients;
- (void)setCcRecipients:(nullable NSArray<NSString *> *)ccRecipients;
- (void)setBccRecipients:(nullable NSArray<NSString *> *)bccRecipients;
- (void)setMessageBody:(NSString *)body isHTML:(BOOL)isHTML;
- (void)addAttachmentData:(NSData *)attachment mimeType:(NSString *)mimeType fileName:(NSString *)filename;
- (void)setPreferredSendingEmailAddress:(NSString *)emailAddress;
@end
@interface MFMessageComposeViewController : UINavigationController
+ (BOOL)canSendText;
+ (BOOL)canSendSubject;
+ (BOOL)canSendAttachments;
+ (BOOL)isSupportedAttachmentUTI:(NSString *)uti;
@property (nonatomic, nullable, weak) id<MFMessageComposeViewControllerDelegate> messageComposeDelegate;
- (void)disableUserAttachments;
@property (nonatomic, nullable, copy) NSArray<NSString *> *recipients;
@property (nonatomic, nullable, copy) NSString *body;
@property (nonatomic, nullable, copy) NSString *subject;
@property (nonatomic, nullable, readonly, copy) NSArray<NSDictionary *> *attachments;
- (BOOL)addAttachmentURL:(NSURL *)attachmentURL withAlternateFilename:(nullable NSString *)alternateFilename;
- (BOOL)addAttachmentData:(NSData *)attachmentData typeIdentifier:(NSString *)uti filename:(NSString *)filename;
@end
NS_ASSUME_NONNULL_END
#else
@class MFMailComposeViewController, MFMessageComposeViewController;
#endif
