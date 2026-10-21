#pragma once
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAsset;
API_AVAILABLE(ios(9))
@interface PHAssetResource : NSObject
@property (nonatomic, assign, readonly) PHAssetResourceType type;
@property (nonatomic, copy, readonly) NSString *assetLocalIdentifier;
@property (nonatomic, copy, readonly) NSString *uniformTypeIdentifier;
@property (nonatomic, copy, readonly) NSString *originalFilename;
+ (NSArray<PHAssetResource *> *)assetResourcesForAsset:(PHAsset *)asset;
@end
NS_ASSUME_NONNULL_END
#endif
