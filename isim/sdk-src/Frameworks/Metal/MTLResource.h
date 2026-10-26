#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
@protocol MTLDevice, MTLHeap;
typedef NS_ENUM(NSUInteger, MTLPurgeableState) {
    MTLPurgeableStateKeepCurrent = 1, MTLPurgeableStateNonVolatile = 2, MTLPurgeableStateVolatile = 3, MTLPurgeableStateEmpty = 4,
};
typedef NS_ENUM(NSUInteger, MTLCPUCacheMode) { MTLCPUCacheModeDefaultCache = 0, MTLCPUCacheModeWriteCombined = 1 };
typedef NS_ENUM(NSUInteger, MTLStorageMode) {
    MTLStorageModeShared = 0, MTLStorageModeManaged = 1, MTLStorageModePrivate = 2, MTLStorageModeMemoryless = 3,
};
typedef NS_ENUM(NSUInteger, MTLHazardTrackingMode) {
    MTLHazardTrackingModeDefault = 0, MTLHazardTrackingModeUntracked = 1, MTLHazardTrackingModeTracked = 2,
};
#define MTLResourceCPUCacheModeShift 0
#define MTLResourceStorageModeShift 4
#define MTLResourceHazardTrackingModeShift 8
typedef NS_OPTIONS(NSUInteger, MTLResourceOptions) {
    MTLResourceCPUCacheModeDefaultCache NS_SWIFT_NAME(cpuCacheModeDefaultCache) = MTLCPUCacheModeDefaultCache << MTLResourceCPUCacheModeShift,
    MTLResourceCPUCacheModeWriteCombined = MTLCPUCacheModeWriteCombined << MTLResourceCPUCacheModeShift,
    MTLResourceStorageModeShared NS_SWIFT_NAME(storageModeShared) = MTLStorageModeShared << MTLResourceStorageModeShift,
    MTLResourceStorageModeManaged = MTLStorageModeManaged << MTLResourceStorageModeShift,
    MTLResourceStorageModePrivate = MTLStorageModePrivate << MTLResourceStorageModeShift,
    MTLResourceStorageModeMemoryless = MTLStorageModeMemoryless << MTLResourceStorageModeShift,
    MTLResourceHazardTrackingModeDefault NS_SWIFT_NAME(hazardTrackingModeDefault) = MTLHazardTrackingModeDefault << MTLResourceHazardTrackingModeShift,
    MTLResourceHazardTrackingModeUntracked = MTLHazardTrackingModeUntracked << MTLResourceHazardTrackingModeShift,
    MTLResourceHazardTrackingModeTracked = MTLHazardTrackingModeTracked << MTLResourceHazardTrackingModeShift,
};
@protocol MTLAllocation <NSObject>
@property (readonly) NSUInteger allocatedSize;
@end
@protocol MTLResource <MTLAllocation>
@property (nullable, copy, atomic) NSString *label;
@property (readonly) id<MTLDevice> device;
@property (readonly) MTLCPUCacheMode cpuCacheMode;
@property (readonly) MTLStorageMode storageMode;
@property (readonly) MTLHazardTrackingMode hazardTrackingMode;
@property (readonly) MTLResourceOptions resourceOptions;
- (MTLPurgeableState)setPurgeableState:(MTLPurgeableState)state NS_SWIFT_NAME(setPurgeableState(_:));
@property (nullable, readonly) id<MTLHeap> heap;
@property (readonly) NSUInteger heapOffset;
- (void)makeAliasable;
- (BOOL)isAliasable;
@end
NS_ASSUME_NONNULL_END
