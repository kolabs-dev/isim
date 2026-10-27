#pragma once
#import <Vision/VNRequest.h>
#import <Vision/VNRequestHandler.h>
#import <CoreVideo/CoreVideo.h>
#import <ImageIO/ImageIO.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class CIImage;
/* isim: no CMSampleBufferRef initializers (isim's CoreMedia has no C sample buffers) */
API_AVAILABLE(ios(11.0))
@interface VNTargetedImageRequest : VNImageBasedRequest
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCompletionHandler:(nullable VNRequestCompletionHandler)completionHandler NS_UNAVAILABLE;
- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCGImage:(CGImageRef)cgImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedCIImage:(CIImage *)ciImage orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedImageData:(NSData *)imageData options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedImageData:(NSData *)imageData options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
- (instancetype)initWithTargetedImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithTargetedImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options completionHandler:(nullable VNRequestCompletionHandler)completionHandler;
@end
NS_ASSUME_NONNULL_END
#endif
