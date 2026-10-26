#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
/* issue #329: how a vertex function's [[stage_in]] attributes are read from the vertex buffers */
typedef NS_ENUM(NSUInteger, MTLVertexFormat) {
    MTLVertexFormatInvalid = 0,
    MTLVertexFormatUChar2 NS_SWIFT_NAME(uchar2) = 1, MTLVertexFormatUChar3 NS_SWIFT_NAME(uchar3) = 2, MTLVertexFormatUChar4 NS_SWIFT_NAME(uchar4) = 3,
    MTLVertexFormatChar2 = 4, MTLVertexFormatChar3 = 5, MTLVertexFormatChar4 = 6,
    MTLVertexFormatUChar2Normalized NS_SWIFT_NAME(uchar2Normalized) = 7, MTLVertexFormatUChar3Normalized NS_SWIFT_NAME(uchar3Normalized) = 8,
    MTLVertexFormatUChar4Normalized NS_SWIFT_NAME(uchar4Normalized) = 9,
    MTLVertexFormatChar2Normalized = 10, MTLVertexFormatChar3Normalized = 11, MTLVertexFormatChar4Normalized = 12,
    MTLVertexFormatUShort2 NS_SWIFT_NAME(ushort2) = 13, MTLVertexFormatUShort3 NS_SWIFT_NAME(ushort3) = 14, MTLVertexFormatUShort4 NS_SWIFT_NAME(ushort4) = 15,
    MTLVertexFormatShort2 = 16, MTLVertexFormatShort3 = 17, MTLVertexFormatShort4 = 18,
    MTLVertexFormatUShort2Normalized NS_SWIFT_NAME(ushort2Normalized) = 19, MTLVertexFormatUShort3Normalized NS_SWIFT_NAME(ushort3Normalized) = 20,
    MTLVertexFormatUShort4Normalized NS_SWIFT_NAME(ushort4Normalized) = 21,
    MTLVertexFormatShort2Normalized = 22, MTLVertexFormatShort3Normalized = 23, MTLVertexFormatShort4Normalized = 24,
    MTLVertexFormatHalf2 = 25, MTLVertexFormatHalf3 = 26, MTLVertexFormatHalf4 = 27,
    MTLVertexFormatFloat = 28, MTLVertexFormatFloat2 = 29, MTLVertexFormatFloat3 = 30, MTLVertexFormatFloat4 = 31,
    MTLVertexFormatInt = 32, MTLVertexFormatInt2 = 33, MTLVertexFormatInt3 = 34, MTLVertexFormatInt4 = 35,
    MTLVertexFormatUInt NS_SWIFT_NAME(uint) = 36, MTLVertexFormatUInt2 NS_SWIFT_NAME(uint2) = 37, MTLVertexFormatUInt3 NS_SWIFT_NAME(uint3) = 38,
    MTLVertexFormatUInt4 NS_SWIFT_NAME(uint4) = 39,
    MTLVertexFormatInt1010102Normalized = 40, MTLVertexFormatUInt1010102Normalized NS_SWIFT_NAME(uint1010102Normalized) = 41,
    MTLVertexFormatUChar4Normalized_BGRA NS_SWIFT_NAME(uchar4Normalized_bgra) = 42,
    MTLVertexFormatUChar NS_SWIFT_NAME(uchar) = 45, MTLVertexFormatChar = 46, MTLVertexFormatUCharNormalized NS_SWIFT_NAME(ucharNormalized) = 47,
    MTLVertexFormatCharNormalized = 48, MTLVertexFormatUShort NS_SWIFT_NAME(ushort) = 49, MTLVertexFormatShort = 50,
    MTLVertexFormatUShortNormalized NS_SWIFT_NAME(ushortNormalized) = 51, MTLVertexFormatShortNormalized = 52, MTLVertexFormatHalf = 53,
    MTLVertexFormatFloatRG11B10 = 54, MTLVertexFormatFloatRGB9E5 = 55,
};
typedef NS_ENUM(NSUInteger, MTLVertexStepFunction) {
    MTLVertexStepFunctionConstant = 0, MTLVertexStepFunctionPerVertex = 1, MTLVertexStepFunctionPerInstance = 2,
    MTLVertexStepFunctionPerPatch = 3, MTLVertexStepFunctionPerPatchControlPoint = 4,
};
static const NSUInteger MTLBufferLayoutStrideDynamic = NSUIntegerMax;

@interface MTLVertexBufferLayoutDescriptor : NSObject <NSCopying>
@property (assign, nonatomic) NSUInteger stride;
@property (assign, nonatomic) MTLVertexStepFunction stepFunction;
@property (assign, nonatomic) NSUInteger stepRate;
@end
@interface MTLVertexBufferLayoutDescriptorArray : NSObject
- (MTLVertexBufferLayoutDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(nullable MTLVertexBufferLayoutDescriptor *)bufferDesc atIndexedSubscript:(NSUInteger)index;
@end
@interface MTLVertexAttributeDescriptor : NSObject <NSCopying>
@property (assign, nonatomic) MTLVertexFormat format;
@property (assign, nonatomic) NSUInteger offset;
@property (assign, nonatomic) NSUInteger bufferIndex;
@end
@interface MTLVertexAttributeDescriptorArray : NSObject
- (MTLVertexAttributeDescriptor *)objectAtIndexedSubscript:(NSUInteger)index;
- (void)setObject:(nullable MTLVertexAttributeDescriptor *)attributeDesc atIndexedSubscript:(NSUInteger)index;
@end
@interface MTLVertexDescriptor : NSObject <NSCopying>
+ (MTLVertexDescriptor *)vertexDescriptor NS_SWIFT_UNAVAILABLE("use MTLVertexDescriptor()");
@property (readonly) MTLVertexBufferLayoutDescriptorArray *layouts;
@property (readonly) MTLVertexAttributeDescriptorArray *attributes;
- (void)reset;
@end
NS_ASSUME_NONNULL_END
