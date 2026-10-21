#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#import <Photos/PHFetchOptions.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAssetCollection, CLLocation;
API_AVAILABLE(ios(8))
@interface PHAsset : PHObject
@property (nonatomic, assign, readonly) PHAssetMediaType mediaType;
@property (nonatomic, assign, readonly) PHAssetMediaSubtype mediaSubtypes;
@property (nonatomic, assign, readonly) NSUInteger pixelWidth;
@property (nonatomic, assign, readonly) NSUInteger pixelHeight;
@property (nonatomic, strong, readonly, nullable) NSDate *creationDate;
@property (nonatomic, strong, readonly, nullable) NSDate *modificationDate;
/* isim: nil (the library has no locations) */
@property (nonatomic, strong, readonly, nullable) CLLocation *location;
@property (nonatomic, assign, readonly) NSTimeInterval duration;
@property (nonatomic, assign, readonly, getter=isHidden) BOOL hidden;
@property (nonatomic, assign, readonly, getter=isFavorite) BOOL favorite;
@property (nonatomic, strong, readonly, nullable) NSString *burstIdentifier;
@property (nonatomic, assign, readonly) BOOL representsBurst;
@property (nonatomic, assign, readonly) PHAssetSourceType sourceType;
- (BOOL)canPerformEditOperation:(PHAssetEditOperation)editOperation;
+ (PHFetchResult<PHAsset *> *)fetchAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options;
+ (nullable PHFetchResult<PHAsset *> *)fetchKeyAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithOptions:(nullable PHFetchOptions *)options;
@end
NS_ASSUME_NONNULL_END
#endif
