#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
typedef struct { NSUInteger x, y, z; } MTLOrigin;
typedef struct { NSUInteger width, height, depth; } MTLSize;
typedef struct { MTLOrigin origin; MTLSize size; } MTLRegion;
typedef struct { uint64_t _impl; } MTLResourceID;
typedef struct { double x, y; } MTLSamplePosition;
typedef struct { uint64_t location, length; } MTLRange;
MTL_INLINE MTLOrigin MTLOriginMake(NSUInteger x, NSUInteger y, NSUInteger z) { MTLOrigin o = {x, y, z}; return o; }
MTL_INLINE MTLSize MTLSizeMake(NSUInteger width, NSUInteger height, NSUInteger depth) { MTLSize s = {width, height, depth}; return s; }
MTL_INLINE MTLRegion MTLRegionMake1D(NSUInteger x, NSUInteger width) { MTLRegion r = {{x, 0, 0}, {width, 1, 1}}; return r; }
MTL_INLINE MTLRegion MTLRegionMake2D(NSUInteger x, NSUInteger y, NSUInteger width, NSUInteger height) { MTLRegion r = {{x, y, 0}, {width, height, 1}}; return r; }
MTL_INLINE MTLRegion MTLRegionMake3D(NSUInteger x, NSUInteger y, NSUInteger z, NSUInteger width, NSUInteger height, NSUInteger depth) {
    MTLRegion r = {{x, y, z}, {width, height, depth}}; return r;
}
MTL_INLINE MTLSamplePosition MTLSamplePositionMake(float x, float y) { MTLSamplePosition p = {x, y}; return p; }
typedef double MTLTimestamp;
NS_ASSUME_NONNULL_END
