#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN

/* a Thumbnail extension's answer: a drawing (in a bitmap context of the size, at the request's scale; origin at the
 * bottom left, or UIKit's current context) or an image file */
API_AVAILABLE(ios(13.0))
@interface QLThumbnailReply : NSObject
+ (instancetype)replyWithContextSize:(CGSize)contextSize drawingBlock:(BOOL (^)(CGContextRef context))drawingBlock
    NS_SWIFT_NAME(init(contextSize:drawing:));
+ (instancetype)replyWithContextSize:(CGSize)contextSize currentContextDrawingBlock:(BOOL (^)(void))drawingBlock
    NS_SWIFT_NAME(init(contextSize:currentContextDrawing:));
+ (instancetype)replyWithImageFileURL:(NSURL *)fileURL NS_SWIFT_NAME(init(imageFileURL:));
@property (nonatomic, copy, nullable) NSString *extensionBadge API_AVAILABLE(ios(15.0));
@end

NS_ASSUME_NONNULL_END
