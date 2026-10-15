#pragma once
/* isim SafariServices for Objective-C: the classes are the SafariServices Swift overlay's (SafariServices.framework
   re-exports libswiftSafariServices.dylib): SFSafariViewController is the same in-app browser as in Swift, on isim's
   WKWebView; the Reading List is kept for the session. Swift uses the overlay; these declarations are hidden from
   Swift. The classes are not subclassable from Objective-C. */
#import <UIKit/UIKit.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class SFSafariViewController;

typedef NS_ENUM(NSInteger, SFSafariViewControllerDismissButtonStyle) {
    SFSafariViewControllerDismissButtonStyleDone = 0,
    SFSafariViewControllerDismissButtonStyleClose,
    SFSafariViewControllerDismissButtonStyleCancel,
};

@interface SFSafariViewControllerConfiguration : NSObject
@property (nonatomic) BOOL entersReaderIfAvailable;
@property (nonatomic) BOOL barCollapsingEnabled;
@end

@protocol SFSafariViewControllerDelegate <NSObject>
@optional
- (void)safariViewControllerDidFinish:(SFSafariViewController *)controller;
- (void)safariViewController:(SFSafariViewController *)controller didCompleteInitialLoad:(BOOL)didLoadSuccessfully;
- (void)safariViewController:(SFSafariViewController *)controller initialLoadDidRedirectToURL:(NSURL *)URL;
- (void)safariViewControllerWillOpenInBrowser:(SFSafariViewController *)controller;
@end

@interface SFSafariViewController : UIViewController
- (instancetype)initWithURL:(NSURL *)URL configuration:(SFSafariViewControllerConfiguration *)configuration NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)URL;
- (instancetype)initWithURL:(NSURL *)URL entersReaderIfAvailable:(BOOL)entersReaderIfAvailable
    API_DEPRECATED_WITH_REPLACEMENT("-initWithURL:configuration:", ios(9.0, 11.0));
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
@property (nonatomic, weak, nullable) id<SFSafariViewControllerDelegate> delegate;
@property (nonatomic, readonly, copy) SFSafariViewControllerConfiguration *configuration;
@property (nonatomic, nullable) UIColor *preferredBarTintColor;
@property (nonatomic, nullable) UIColor *preferredControlTintColor;
@property (nonatomic) SFSafariViewControllerDismissButtonStyle dismissButtonStyle;
@end

FOUNDATION_EXPORT NSString * const SSReadingListErrorDomain;
typedef NS_ENUM(NSInteger, SSReadingListErrorCode) { SSReadingListErrorURLSchemeNotAllowed = 1 };

@interface SSReadingList : NSObject
+ (nullable SSReadingList *)defaultReadingList;
+ (BOOL)supportsURL:(NSURL *)URL;
- (BOOL)addReadingListItemWithURL:(NSURL *)URL title:(nullable NSString *)title previewText:(nullable NSString *)previewText
                            error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END
#endif
