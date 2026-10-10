#pragma once
/* isim: full-page screenshots (iOS 13). The window scene's screenshot service asks its delegate for a PDF of the whole
   document (more than fits on screen) when a screenshot is taken; isim asks for it with the script command
   `fullpage PATH`, which writes the PDF to PATH and logs its page and rect ("isim: full page ..."). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
#import <UIKit/UIScene.h>
NS_ASSUME_NONNULL_BEGIN
@protocol UIScreenshotServiceDelegate;
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@interface UIScreenshotService : NSObject
@property (nonatomic, weak, nullable) id<UIScreenshotServiceDelegate> delegate;
@property (nonatomic, weak, readonly, nullable) UIWindowScene *windowScene;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end
@interface UIWindowScene (UIScreenshotService)
@property (nonatomic, readonly, nullable) UIScreenshotService *screenshotService API_AVAILABLE(ios(13.0));
@end
NS_SWIFT_UI_ACTOR API_AVAILABLE(ios(13.0))
@protocol UIScreenshotServiceDelegate <NSObject>
@optional
/* the PDF of the full document, the index of the page shown on screen, and the visible rect in PDF coordinates */
- (void)screenshotService:(UIScreenshotService *)screenshotService
    generatePDFRepresentationWithCompletion:(void (^)(NSData *_Nullable PDFData, NSInteger indexOfCurrentPage, CGRect rectInCurrentPage))completionHandler;
@end
NS_ASSUME_NONNULL_END
