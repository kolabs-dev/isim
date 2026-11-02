#pragma once
/* isim SDK (self-authored): Social — SLComposeServiceViewController, the standard compose sheet of Share extensions.
 * isim draws an iOS-style card: Cancel / title / Post, a text view with the shared text, an optional preview, the
 * configuration items and the characters remaining. Post calls didSelectPost (default: completes the request), Cancel
 * calls didSelectCancel (default: cancels it). SLComposeViewController and SLRequest (posting to social services) are
 * unavailable, like the Simulator, which has no accounts for them: isAvailableForServiceType: is NO, a composer that is
 * presented anyway finishes as cancelled, and an SLRequest is sent without an account to sign it. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

typedef void (^SLComposeSheetConfigurationItemTapHandler)(void);

@interface SLComposeSheetConfigurationItem : NSObject
@property (nonatomic, copy, nullable) NSString *title;
@property (nonatomic, copy, nullable) NSString *value;
@property (nonatomic, assign) BOOL valuePending;
@property (nonatomic, copy, nullable) SLComposeSheetConfigurationItemTapHandler tapHandler;
- (null_unspecified instancetype)init;
@end

@interface SLComposeServiceViewController : UIViewController <UITextViewDelegate>
@property (nonatomic, readonly) UITextView *textView;
@property (nonatomic, readonly, null_unspecified) NSString *contentText;
@property (nonatomic, copy, null_unspecified) NSString *placeholder;
@property (nonatomic, strong, nullable) NSNumber *charactersRemaining;
@property (nonatomic, strong, nullable) UIViewController *autoCompletionViewController;
- (void)presentationAnimationDidFinish;
- (void)didSelectPost;
- (void)didSelectCancel;
- (void)cancel;
- (BOOL)isContentValid;
- (void)validateContent;
- (null_unspecified NSArray *)configurationItems;
- (void)reloadConfigurationItems;
- (void)pushConfigurationViewController:(UIViewController *)viewController;
- (void)popConfigurationViewController;
- (nullable UIView *)loadPreviewView;
@end

/* the social services (deprecated by Apple; none is available on isim) */
FOUNDATION_EXPORT NSString * const SLServiceTypeTwitter;
FOUNDATION_EXPORT NSString * const SLServiceTypeFacebook;
FOUNDATION_EXPORT NSString * const SLServiceTypeSinaWeibo;
FOUNDATION_EXPORT NSString * const SLServiceTypeTencentWeibo;
FOUNDATION_EXPORT NSString * const SLServiceTypeLinkedIn;

typedef NS_ENUM(NSInteger, SLComposeViewControllerResult) { SLComposeViewControllerResultCancelled, SLComposeViewControllerResultDone };
typedef void (^SLComposeViewControllerCompletionHandler)(SLComposeViewControllerResult result);

@interface SLComposeViewController : UIViewController
+ (BOOL)isAvailableForServiceType:(null_unspecified NSString *)serviceType;
+ (null_unspecified SLComposeViewController *)composeViewControllerForServiceType:(null_unspecified NSString *)serviceType;
@property (nonatomic, readonly, null_unspecified) NSString *serviceType;
- (BOOL)setInitialText:(null_unspecified NSString *)text;
- (BOOL)addImage:(null_unspecified UIImage *)image;
- (BOOL)removeAllImages;
- (BOOL)addURL:(null_unspecified NSURL *)url;
- (BOOL)removeAllURLs;
@property (nonatomic, copy, null_unspecified) SLComposeViewControllerCompletionHandler completionHandler;
@end

@class ACAccount;
typedef NS_ENUM(NSInteger, SLRequestMethod) { SLRequestMethodGET, SLRequestMethodPOST, SLRequestMethodDELETE, SLRequestMethodPUT };
/* NSURLRequest and NSHTTPURLResponse are hidden from Swift (Foundation's overlay classes): Swift gets preparedURLRequest()
   and perform(handler:) with URLRequest and HTTPURLResponse from Social's Swift overlay (swift/overlays/Social.swift) */
#if !defined(__swift__)
typedef void (^SLRequestHandler)(NSData * _Nullable responseData, NSHTTPURLResponse * _Nullable urlResponse, NSError * _Nullable error);
#endif

@interface SLRequest : NSObject
+ (null_unspecified SLRequest *)requestForServiceType:(null_unspecified NSString *)serviceType requestMethod:(SLRequestMethod)requestMethod
                                                  URL:(null_unspecified NSURL *)url parameters:(null_unspecified NSDictionary *)parameters;
@property (nonatomic, strong, null_unspecified) ACAccount *account;
@property (nonatomic, readonly) SLRequestMethod requestMethod;
@property (nonatomic, readonly, null_unspecified) NSURL *URL;
@property (nonatomic, readonly, null_unspecified) NSDictionary *parameters;
- (void)addMultipartData:(null_unspecified NSData *)data withName:(null_unspecified NSString *)name type:(null_unspecified NSString *)type
                filename:(null_unspecified NSString *)filename;
#if !defined(__swift__)
- (null_unspecified NSURLRequest *)preparedURLRequest;
- (void)performRequestWithHandler:(null_unspecified SLRequestHandler)handler;
#endif
@end

NS_ASSUME_NONNULL_END
