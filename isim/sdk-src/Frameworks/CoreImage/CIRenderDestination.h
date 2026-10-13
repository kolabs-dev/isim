#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
#import <CoreImage/CIContext.h>
#import <CoreImage/CIKernel.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSUInteger, CIRenderDestinationAlphaMode) {
    CIRenderDestinationAlphaNone = 0, CIRenderDestinationAlphaPremultiplied = 1, CIRenderDestinationAlphaUnpremultiplied = 2
};
/* isim: bitmap destinations (and CVPixelBuffers through the Swift overlay); tasks run synchronously on the CPU */
@interface CIRenderDestination : NSObject
- (instancetype)initWithBitmapData:(void *)data width:(NSUInteger)width height:(NSUInteger)height bytesPerRow:(NSUInteger)bytesPerRow format:(CIFormat)format;
@property (readonly) NSUInteger width;
@property (readonly) NSUInteger height;
@property CIRenderDestinationAlphaMode alphaMode;
@property (getter=isFlipped) BOOL flipped;
@property (getter=isDithered) BOOL dithered;
@property (getter=isClamped) BOOL clamped;
@property (nullable, nonatomic) CGColorSpaceRef colorSpace;
@property (nullable, nonatomic, retain) CIBlendKernel *blendKernel;
@property BOOL blendsInDestinationColorSpace;
@property (nullable, nonatomic, retain) NSURL *captureTraceURL API_AVAILABLE(ios(16.0));
@end
@interface CIRenderInfo : NSObject
@property (readonly) NSTimeInterval kernelExecutionTime;
@property (readonly) NSTimeInterval kernelCompileTime API_AVAILABLE(ios(16.0));
@property (readonly) NSInteger passCount;
@property (readonly) NSInteger pixelsProcessed;
@end
@interface CIRenderTask : NSObject
- (nullable CIRenderInfo *)waitUntilCompletedAndReturnError:(NSError **)error;
@end
@interface CIContext (CIRenderDestination)
- (nullable CIRenderTask *)startTaskToRender:(CIImage *)image fromRect:(CGRect)fromRect toDestination:(CIRenderDestination *)destination
    atPoint:(CGPoint)atPoint error:(NSError **)error;
- (nullable CIRenderTask *)startTaskToRender:(CIImage *)image toDestination:(CIRenderDestination *)destination error:(NSError **)error;
- (BOOL)prepareRender:(CIImage *)image fromRect:(CGRect)fromRect toDestination:(CIRenderDestination *)destination atPoint:(CGPoint)atPoint error:(NSError **)error;
- (nullable CIRenderTask *)startTaskToClear:(CIRenderDestination *)destination error:(NSError **)error;
@end
NS_ASSUME_NONNULL_END
