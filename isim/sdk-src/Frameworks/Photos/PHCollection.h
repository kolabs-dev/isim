#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#import <Photos/PHFetchOptions.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAsset;
API_AVAILABLE(ios(8))
@interface PHCollection : PHObject
@property (nonatomic, assign, readonly) BOOL canContainAssets;
@property (nonatomic, assign, readonly) BOOL canContainCollections;
@property (nonatomic, strong, readonly, nullable) NSString *localizedTitle;
- (BOOL)canPerformEditOperation:(PHCollectionEditOperation)anOperation;
/* isim: the user's albums (no folders) */
+ (PHFetchResult<PHCollection *> *)fetchTopLevelUserCollectionsWithOptions:(nullable PHFetchOptions *)options;
@end
API_AVAILABLE(ios(8))
@interface PHAssetCollection : PHCollection
@property (nonatomic, assign, readonly) PHAssetCollectionType assetCollectionType;
@property (nonatomic, assign, readonly) PHAssetCollectionSubtype assetCollectionSubtype;
@property (nonatomic, assign, readonly) NSUInteger estimatedAssetCount;
@property (nonatomic, strong, readonly, nullable) NSDate *startDate;
@property (nonatomic, strong, readonly, nullable) NSDate *endDate;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsWithType:(PHAssetCollectionType)type subtype:(PHAssetCollectionSubtype)subtype options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAssetCollection *> *)fetchAssetCollectionsContainingAsset:(PHAsset *)asset withType:(PHAssetCollectionType)type options:(nullable PHFetchOptions *)options;
@end
NS_ASSUME_NONNULL_END
#endif
