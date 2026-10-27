/* isim QuickLook internals: Quick Look Preview extensions (QLPreviewExtensions.m) hosted by QLPreviewController's
   pages (QuickLook.m) */
#import <QuickLook/QuickLook.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

/* an installed com.apple.quicklook.preview extension */
@interface __IsimQLExtension : NSObject
@property (nonatomic, copy) NSString *path, *bundleID, *executable;
@property (nonatomic, copy, nullable) NSString *principal, *storyboard;
@property (nonatomic, copy) NSArray<NSString *> *types;             /* QLSupportedContentTypes */
@property (nonatomic, copy) NSArray<NSDictionary *> *declarations;  /* its app's (and its own) type declarations */
@end
/* the extension that previews a file, if any */
__IsimQLExtension *_Nullable isim_ql_extension_for(NSURL *url);
/* the extension of an extension point (com.apple.quicklook.preview, com.apple.quicklook.thumbnail) for a file */
__IsimQLExtension *_Nullable isim_ql_extension_for_point(NSURL *url, NSString *point);

@class __IsimQLExtensionHost;
@protocol __IsimQLExtensionHostDelegate <NSObject>
- (UIViewController *)extensionHostParentViewController:(__IsimQLExtensionHost *)host;
/* a data-based extension's reply as a file (nil: it failed: the generic page) and its title */
- (void)extensionHost:(__IsimQLExtensionHost *)host showFile:(nullable NSURL *)file title:(nullable NSString *)title;
@end

/* a page's content for an extension: a view-based extension's view, or a spinner until a data-based one replies */
@interface __IsimQLExtensionHost : UIView
- (instancetype)initWithExtension:(__IsimQLExtension *)x url:(NSURL *)url;
@property (nonatomic, weak) id<__IsimQLExtensionHostDelegate> delegate;
@property (nonatomic, readonly) NSString *kindName;                 /* view / data */
- (void)stop;
@end

@interface QLFilePreviewRequest ()
- (instancetype)_isimInitWithFileURL:(NSURL *)url __attribute__((objc_method_family(init)));
@end
@interface QLPreviewReply ()
- (NSString *)_isimKindName;
- (nullable NSURL *)_isimWriteTo:(NSString *)dir base:(NSString *)base error:(NSError **)error;
@end

NS_ASSUME_NONNULL_END
