#pragma once
/* isim Foundation: app extension requests (self-authored). Share and Action extensions get an NSExtensionContext with
 * the host's items (NSExtensionItem with NSItemProvider attachments); isim hosts them in the host app's process
 * (UIActivityViewController) and completeRequest / cancelRequest return to it. */
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSError.h>
#import <Foundation/NSURL.h>
#import <Foundation/NSAttributedString.h>
#import <Foundation/NSItemProvider.h>
NS_ASSUME_NONNULL_BEGIN
@class NSExtensionContext;

@protocol NSExtensionRequestHandling <NSObject>
- (void)beginRequestWithExtensionContext:(NSExtensionContext *)context;
@end

@interface NSExtensionItem : NSObject <NSCopying>
@property (nonatomic, copy, nullable) NSAttributedString *attributedTitle;
@property (nonatomic, copy, nullable) NSAttributedString *attributedContentText;
@property (nonatomic, copy, nullable) NSArray<NSItemProvider *> *attachments;
@property (nonatomic, copy, nullable) NSDictionary *userInfo;
@end

FOUNDATION_EXPORT NSString * const NSExtensionItemAttributedTitleKey;
FOUNDATION_EXPORT NSString * const NSExtensionItemAttributedContentTextKey;
FOUNDATION_EXPORT NSString * const NSExtensionItemAttachmentsKey;
FOUNDATION_EXPORT NSString * const NSExtensionItemsAndErrorsKey;
FOUNDATION_EXPORT NSString * const NSExtensionJavaScriptPreprocessingResultsKey;
FOUNDATION_EXPORT NSString * const NSExtensionJavaScriptFinalizeArgumentKey;
FOUNDATION_EXPORT NSString * const NSExtensionHostWillEnterForegroundNotification;
FOUNDATION_EXPORT NSString * const NSExtensionHostDidEnterBackgroundNotification;
FOUNDATION_EXPORT NSString * const NSExtensionHostWillResignActiveNotification;
FOUNDATION_EXPORT NSString * const NSExtensionHostDidBecomeActiveNotification;

@interface NSExtensionContext : NSObject
@property (nonatomic, readonly, copy) NSArray *inputItems;
- (void)completeRequestReturningItems:(nullable NSArray *)items completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler NS_SWIFT_NAME(completeRequest(returningItems:completionHandler:));
- (void)cancelRequestWithError:(NSError *)error NS_SWIFT_NAME(cancelRequest(withError:));
/* isim: extensions hosted in an app cannot open URLs (like Share extensions on iOS): the handler gets NO */
- (void)openURL:(NSURL *)URL completionHandler:(void (^ _Nullable)(BOOL success))completionHandler NS_SWIFT_NAME(open(_:completionHandler:));
@end

NS_ASSUME_NONNULL_END
