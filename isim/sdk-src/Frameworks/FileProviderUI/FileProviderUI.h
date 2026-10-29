#pragma once
/* isim FileProviderUI (adapted): a file provider app's UI extension (NSExtensionPointIdentifier
   com.apple.fileprovider-actionsui). The document picker and browser list its NSExtensionFileProviderActions in the
   menu of the provider's items and present its FPUIActionExtensionViewController when one is chosen; it also shows
   (prepareForError:) when syncing the domain fails with NSFileProviderErrorNotAuthenticated. The view controller and
   context are the FileProviderUI Swift overlay's (FileProviderUI.framework re-exports libswiftFileProviderUI.dylib), so
   their declarations below are hidden from Swift. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <FileProvider/FileProvider.h>
NS_ASSUME_NONNULL_BEGIN

typedef NSString *FPUIActionIdentifier NS_EXTENSIBLE_STRING_ENUM;
FOUNDATION_EXPORT NSErrorDomain const FPUIErrorDomain;
typedef NS_ENUM(NSUInteger, FPUIExtensionErrorCode) {
    FPUIExtensionErrorCodeUserCancelled = 0,
    FPUIExtensionErrorCodeFailed = 1,
};

#if !defined(__swift__)
@interface FPUIActionExtensionContext : NSExtensionContext
@property (nonatomic, readonly, copy, nullable) NSFileProviderDomainIdentifier domainIdentifier;
- (void)completeRequest;
- (void)completeRequestReturningItems:(nullable NSArray *)items completionHandler:(void (^ _Nullable)(BOOL expired))completionHandler NS_UNAVAILABLE;
- (void)cancelRequestWithError:(NSError *)error;
@end

@interface FPUIActionExtensionViewController : UIViewController
@property (nonatomic, readonly, strong) FPUIActionExtensionContext *extensionContext;
- (void)prepareForError:(NSError *)error;
- (void)prepareForActionWithIdentifier:(FPUIActionIdentifier)actionIdentifier itemIdentifiers:(NSArray<NSFileProviderItemIdentifier> *)itemIdentifiers;
@end
#else
@class FPUIActionExtensionContext, FPUIActionExtensionViewController;
#endif

NS_ASSUME_NONNULL_END
