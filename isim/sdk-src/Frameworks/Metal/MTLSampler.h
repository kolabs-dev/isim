#pragma once
#import <Metal/MTLDefines.h>
#import <Metal/MTLDepthStencil.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice;
typedef NS_ENUM(NSUInteger, MTLSamplerMinMagFilter) { MTLSamplerMinMagFilterNearest = 0, MTLSamplerMinMagFilterLinear = 1 };
typedef NS_ENUM(NSUInteger, MTLSamplerMipFilter) { MTLSamplerMipFilterNotMipmapped = 0, MTLSamplerMipFilterNearest = 1, MTLSamplerMipFilterLinear = 2 };
typedef NS_ENUM(NSUInteger, MTLSamplerAddressMode) {
    MTLSamplerAddressModeClampToEdge = 0, MTLSamplerAddressModeMirrorClampToEdge = 1, MTLSamplerAddressModeRepeat = 2,
    MTLSamplerAddressModeMirrorRepeat = 3, MTLSamplerAddressModeClampToZero = 4, MTLSamplerAddressModeClampToBorderColor = 5,
};
typedef NS_ENUM(NSUInteger, MTLSamplerBorderColor) {
    MTLSamplerBorderColorTransparentBlack = 0, MTLSamplerBorderColorOpaqueBlack = 1, MTLSamplerBorderColorOpaqueWhite = 2,
};
@interface MTLSamplerDescriptor : NSObject <NSCopying>
@property (nonatomic) MTLSamplerMinMagFilter minFilter;
@property (nonatomic) MTLSamplerMinMagFilter magFilter;
@property (nonatomic) MTLSamplerMipFilter mipFilter;
@property (nonatomic) NSUInteger maxAnisotropy;
@property (nonatomic) MTLSamplerAddressMode sAddressMode;
@property (nonatomic) MTLSamplerAddressMode tAddressMode;
@property (nonatomic) MTLSamplerAddressMode rAddressMode;
@property (nonatomic) MTLSamplerBorderColor borderColor;
@property (nonatomic) BOOL normalizedCoordinates;
@property (nonatomic) float lodMinClamp;
@property (nonatomic) float lodMaxClamp;
@property (nonatomic) BOOL lodAverage;
@property (nonatomic) MTLCompareFunction compareFunction;
@property (nonatomic) BOOL supportArgumentBuffers;
@property (nullable, copy, nonatomic) NSString *label;
@end
@protocol MTLSamplerState <NSObject>
@property (nullable, readonly) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) MTLResourceID gpuResourceID;
@end
NS_ASSUME_NONNULL_END
