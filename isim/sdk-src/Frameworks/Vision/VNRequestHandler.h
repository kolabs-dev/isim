#pragma once
#import <Vision/VNDefines.h>
#import <CoreGraphics/CoreGraphics.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class VNRequest;
typedef NSString *VNImageOption NS_STRING_ENUM;
VN_EXPORT VNImageOption const VNImageOptionProperties API_AVAILABLE(ios(11.0));
VN_EXPORT VNImageOption const VNImageOptionCameraIntrinsics API_AVAILABLE(ios(11.0));
VN_EXPORT VNImageOption const VNImageOptionCIContext API_AVAILABLE(ios(11.0));
/* isim: the options are accepted and not used */
API_AVAILABLE(ios(11.0))
@interface VNImageRequestHandler : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithCGImage:(CGImageRef)image options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithCIImage:(CIImage *)image options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithCIImage:(CIImage *)image orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithURL:(NSURL *)imageURL options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithData:(NSData *)imageData options:(NSDictionary<VNImageOption, id> *)options;
- (instancetype)initWithData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation options:(NSDictionary<VNImageOption, id> *)options;
/* runs the requests in order, synchronously, filling their results and calling their completion handlers */
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests error:(NSError **)error;
@end
API_AVAILABLE(ios(11.0))
@interface VNSequenceRequestHandler : NSObject
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCVPixelBuffer:(CVPixelBufferRef)pixelBuffer orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onCIImage:(CIImage *)image orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageURL:(NSURL *)imageURL orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData error:(NSError **)error;
- (BOOL)performRequests:(NSArray<VNRequest *> *)requests onImageData:(NSData *)imageData orientation:(CGImagePropertyOrientation)orientation error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
#endif
