#pragma once
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(8))
@interface PHFetchOptions : NSObject <NSCopying>
@property (nonatomic, strong, nullable) NSPredicate *predicate;
@property (nonatomic, strong, nullable) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (nonatomic, assign) BOOL includeHiddenAssets;
@property (nonatomic, assign) BOOL includeAllBurstAssets;
@property (nonatomic, assign) PHAssetSourceType includeAssetSourceTypes;
@property (nonatomic, assign, readwrite) NSUInteger fetchLimit;
@property (nonatomic, assign) BOOL wantsIncrementalChangeDetails;
@end
NS_ASSUME_NONNULL_END
#endif
