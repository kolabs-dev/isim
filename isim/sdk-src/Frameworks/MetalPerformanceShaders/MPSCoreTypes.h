// isim MetalPerformanceShaders (self-authored, Apple's interface): the core types
#pragma once
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
/* the vector types: <simd/simd.h> when the SDK has it, else Apple's layout */
#if __has_include(<simd/simd.h>)
#include <simd/simd.h>
#elif !defined(MPS_ISIM_SIMD)
#define MPS_ISIM_SIMD 1
typedef float simd_float2 __attribute__((__ext_vector_type__(2)));
typedef float simd_float3 __attribute__((__ext_vector_type__(3)));
typedef float simd_float4 __attribute__((__ext_vector_type__(4)));
typedef unsigned char simd_uchar16 __attribute__((__ext_vector_type__(16)));
typedef simd_float2 vector_float2;
typedef simd_float3 vector_float3;
typedef simd_float4 vector_float4;
typedef simd_uchar16 vector_uchar16;
#endif

#define MPS_EXPORT extern __attribute__((visibility("default")))

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, MPSKernelOptions) {
    MPSKernelOptionsNone = 0,
    MPSKernelOptionsSkipAPIValidation = 1U << 0,
    MPSKernelOptionsAllowReducedPrecision = 1U << 1,
    MPSKernelOptionsDisableInternalTiling = 1U << 2,
    MPSKernelOptionsInsertDebugGroups = 1U << 3,
    MPSKernelOptionsVerbose = 1U << 4,
} API_AVAILABLE(ios(9.0));

/* what a kernel reads outside its source image */
typedef NS_ENUM(NSUInteger, MPSImageEdgeMode) {
    MPSImageEdgeModeZero,             /* (0, 0, 0, 1) without alpha, (0, 0, 0, 0) with alpha */
    MPSImageEdgeModeClamp = 1,        /* the nearest edge pixel */
    MPSImageEdgeModeMirror API_AVAILABLE(ios(14.0)),
    MPSImageEdgeModeMirrorWithEdge API_AVAILABLE(ios(14.0)),
    MPSImageEdgeModeConstant API_AVAILABLE(ios(14.0)),
} API_AVAILABLE(ios(9.0));

typedef NS_ENUM(NSUInteger, MPSImageFeatureChannelFormat) {
    MPSImageFeatureChannelFormatNone = 0,
    MPSImageFeatureChannelFormatUnorm8 = 1,
    MPSImageFeatureChannelFormatUnorm16 = 2,
    MPSImageFeatureChannelFormatFloat16 = 3,
    MPSImageFeatureChannelFormatFloat32 = 4,
    MPSImageFeatureChannelFormat_reserved0 API_AVAILABLE(ios(14.0)) = 5,
    MPSImageFeatureChannelFormatCount,
} API_AVAILABLE(ios(10.0));

typedef NS_ENUM(uint32_t, MPSDataType) {
    MPSDataTypeInvalid = 0,
    MPSDataTypeFloatBit = 0x10000000,
    MPSDataTypeFloat32 = MPSDataTypeFloatBit | 32,
    MPSDataTypeFloat16 = MPSDataTypeFloatBit | 16,
    MPSDataTypeComplexBit API_AVAILABLE(ios(16.0)) = 0x01000000,
    MPSDataTypeComplexFloat32 API_AVAILABLE(ios(16.0)) = MPSDataTypeFloatBit | MPSDataTypeComplexBit | 64,
    MPSDataTypeComplexFloat16 API_AVAILABLE(ios(16.0)) = MPSDataTypeFloatBit | MPSDataTypeComplexBit | 32,
    MPSDataTypeSignedBit = 0x20000000,
    MPSDataTypeIntBit = MPSDataTypeSignedBit,
    MPSDataTypeInt4 API_AVAILABLE(ios(18.0)) = MPSDataTypeSignedBit | 4,
    MPSDataTypeInt8 = MPSDataTypeSignedBit | 8,
    MPSDataTypeInt16 = MPSDataTypeSignedBit | 16,
    MPSDataTypeInt32 = MPSDataTypeSignedBit | 32,
    MPSDataTypeInt64 API_AVAILABLE(ios(14.1)) = MPSDataTypeSignedBit | 64,
    MPSDataTypeUInt4 API_AVAILABLE(ios(18.0)) = 4,
    MPSDataTypeUInt8 = 8,
    MPSDataTypeUInt16 = 16,
    MPSDataTypeUInt32 = 32,
    MPSDataTypeUInt64 API_AVAILABLE(ios(14.1)) = 64,
    MPSDataTypeAlternateEncodingBit API_AVAILABLE(ios(14.0)) = 0x80000000,
    MPSDataTypeBool API_AVAILABLE(ios(14.0)) = MPSDataTypeAlternateEncodingBit | 8,
    MPSDataTypeBFloat16 API_AVAILABLE(ios(17.0)) = MPSDataTypeAlternateEncodingBit | MPSDataTypeFloat16,
    MPSDataTypeNormalizedBit = 0x40000000,
    MPSDataTypeUnorm1 = MPSDataTypeNormalizedBit | 1,
    MPSDataTypeUnorm8 = MPSDataTypeNormalizedBit | 8,
} API_AVAILABLE(ios(10.0));

/* the size of an element of the type, in bytes (0 for the sub-byte types) */
static inline size_t MPSSizeofMPSDataType(uint32_t type) { return (size_t)((type & 0xffff) >> 3); }

typedef struct { NSInteger x, y, z; } MPSOffset;
typedef struct { double x, y, z; } MPSOrigin;
typedef struct { double width, height, depth; } MPSSize;
typedef struct { MPSOrigin origin; MPSSize size; } MPSRegion;
typedef struct { double scaleX, scaleY, translateX, translateY; } MPSScaleTransform;
typedef struct { NSUInteger start, length; } MPSDimensionSlice;

/* the region of all of a texture (clipRect's default) */
MPS_EXPORT const MTLRegion MPSRectNoClip API_AVAILABLE(ios(9.0));

typedef NS_ENUM(NSUInteger, MPSAlphaType) {
    MPSAlphaTypeNonPremultiplied = 0,
    MPSAlphaTypeAlphaIsOne = 1,
    MPSAlphaTypePremultiplied = 2,
} API_AVAILABLE(ios(10.0));

typedef NS_ENUM(NSUInteger, MPSDataLayout) {
    MPSDataLayoutHeightxWidthxFeatureChannels = 0,
    MPSDataLayoutFeatureChannelsxHeightxWidth = 1,
} API_AVAILABLE(ios(11.0));

typedef struct {
    NSUInteger featureChannelOffset;
    NSUInteger numberOfFeatureChannelsToReadWrite;
} MPSImageReadWriteParams;

typedef NS_ENUM(NSUInteger, MPSPurgeableState) {
    MPSPurgeableStateAllocationDeferred = 0,
    MPSPurgeableStateKeepCurrent = MTLPurgeableStateKeepCurrent,
    MPSPurgeableStateNonVolatile = MTLPurgeableStateNonVolatile,
    MPSPurgeableStateVolatile = MTLPurgeableStateVolatile,
    MPSPurgeableStateEmpty = MTLPurgeableStateEmpty,
} API_AVAILABLE(ios(11.0));

typedef NSArray<NSNumber *> MPSShape;

/* whether MPS runs on the device (isim: on isim's CPU device, yes) */
MPS_EXPORT BOOL MPSSupportsMTLDevice(__nullable id<MTLDevice> device) API_AVAILABLE(ios(9.0));
MPS_EXPORT __nullable id<MTLDevice> MPSGetPreferredDevice(NSUInteger options) API_AVAILABLE(ios(13.0));

NS_ASSUME_NONNULL_END
