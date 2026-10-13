#pragma once
#import <Foundation/Foundation.h>
#import <CoreImage/CIImage.h>
NS_ASSUME_NONNULL_BEGIN
/* isim: processors run on the CPU; inputs and the output are main-memory bitmaps (baseAddress / bytesPerRow / format).
 * The Swift overlay adds pixelBuffer (nil: no CVPixelBuffer backs them); there are no Metal textures or IOSurfaces. */
@protocol CIImageProcessorInput
@property (nonatomic, readonly) CGRect region;
@property (nonatomic, readonly) size_t bytesPerRow;
@property (nonatomic, readonly) CIFormat format;
@property (readonly, nonatomic) const void *baseAddress NS_RETURNS_INNER_POINTER;
@property (nonatomic, readonly) uint64_t digest;
@property (nonatomic, readonly) NSUInteger roiTileIndex;
@property (nonatomic, readonly) NSUInteger roiTileCount;
@end
@protocol CIImageProcessorOutput
@property (nonatomic, readonly) CGRect region;
@property (nonatomic, readonly) size_t bytesPerRow;
@property (nonatomic, readonly) CIFormat format;
@property (readonly, nonatomic) void *baseAddress NS_RETURNS_INNER_POINTER;
@property (nonatomic, readonly) uint64_t digest;
@end
@interface CIImageProcessorKernel : NSObject
+ (BOOL)processWithInputs:(nullable NSArray<id<CIImageProcessorInput>> *)inputs arguments:(nullable NSDictionary<NSString *, id> *)arguments
    output:(id<CIImageProcessorOutput>)output error:(NSError **)error;
+ (CGRect)roiForInput:(int)inputIndex arguments:(nullable NSDictionary<NSString *, id> *)arguments outputRect:(CGRect)outputRect;
+ (NSArray *)roiTileArrayForInput:(int)inputIndex arguments:(nullable NSDictionary<NSString *, id> *)arguments outputRect:(CGRect)outputRect API_AVAILABLE(ios(16.0));
+ (CIFormat)formatForInputAtIndex:(int)inputIndex;
@property (class, readonly) CIFormat outputFormat;
@property (class, readonly) BOOL outputIsOpaque;
@property (class, readonly) BOOL synchronizeInputs;
+ (nullable CIImage *)applyWithExtent:(CGRect)extent inputs:(nullable NSArray<CIImage *> *)inputs arguments:(nullable NSDictionary<NSString *, id> *)args
    error:(NSError **)error;
@end
/* processors with several outputs (iOS 17) */
@interface CIImageProcessorKernel (MultipleOutputSupport)
+ (nullable NSArray<CIImage *> *)applyWithExtents:(NSArray<CIVector *> *)extents inputs:(nullable NSArray<CIImage *> *)inputs
    arguments:(nullable NSDictionary<NSString *, id> *)args error:(NSError **)error API_AVAILABLE(ios(17.0));
+ (BOOL)processWithInputs:(nullable NSArray<id<CIImageProcessorInput>> *)inputs arguments:(nullable NSDictionary<NSString *, id> *)arguments
    outputs:(NSArray<id<CIImageProcessorOutput>> *)outputs error:(NSError **)error API_AVAILABLE(ios(17.0));
+ (CIFormat)outputFormatAtIndex:(int)outputIndex arguments:(nullable NSDictionary<NSString *, id> *)arguments API_AVAILABLE(ios(17.0));
@end
@class CIVector;
NS_ASSUME_NONNULL_END
