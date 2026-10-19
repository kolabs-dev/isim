#pragma once
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class UIImage, XCUIScreenshot;

/* Whether an attachment is kept after its test. isim: `isim test -resultBundlePath DIR` saves the kept ones in
 * DIR/<bundle>.attachments/<Class>/<test>/ (isim's results directory, not an .xcresult bundle). */
typedef NS_ENUM(NSInteger, XCTAttachmentLifetime) {
    XCTAttachmentLifetimeKeepAlways = 0,
    XCTAttachmentLifetimeDeleteOnSuccess = 1,
} NS_SWIFT_NAME(XCTAttachment.Lifetime);

/* Data a test keeps with its results (XCTestCase add(_:)): bytes, text, a file, an image or a screenshot. */
@interface XCTAttachment : NSObject
+ (instancetype)attachmentWithData:(NSData *)payload;
+ (instancetype)attachmentWithData:(NSData *)payload uniformTypeIdentifier:(NSString *)identifier;
+ (instancetype)attachmentWithString:(NSString *)string;
+ (instancetype)attachmentWithContentsOfFileAtURL:(NSURL *)url NS_SWIFT_NAME(init(contentsOfFile:));
+ (instancetype)attachmentWithImage:(UIImage *)image;
+ (instancetype)attachmentWithScreenshot:(XCUIScreenshot *)screenshot;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, copy) NSString *name;
@property (readonly, copy) NSString *uniformTypeIdentifier;
/* default: XCTAttachmentLifetimeDeleteOnSuccess (kept when the test fails) */
@property XCTAttachmentLifetime lifetime;
@property (nullable, copy) NSDictionary *userInfo;
@end

NS_ASSUME_NONNULL_END
