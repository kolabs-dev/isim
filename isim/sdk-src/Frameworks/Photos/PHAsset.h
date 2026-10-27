#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#import <Photos/PHFetchOptions.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAssetCollection, CLLocation, PHContentEditingInput, PHContentEditingInputRequestOptions;
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
@property (nonatomic, assign, readonly) PHAssetPlaybackStyle playbackStyle API_AVAILABLE(ios(11));
/* whether the asset carries an edit */
@property (nonatomic, assign, readonly) BOOL hasAdjustments API_AVAILABLE(ios(15));
- (BOOL)canPerformEditOperation:(PHAssetEditOperation)editOperation;
+ (PHFetchResult<PHAsset *> *)fetchAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithLocalIdentifiers:(NSArray<NSString *> *)identifiers options:(nullable PHFetchOptions *)options;
+ (nullable PHFetchResult<PHAsset *> *)fetchKeyAssetsInAssetCollection:(PHAssetCollection *)assetCollection options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithMediaType:(PHAssetMediaType)mediaType options:(nullable PHFetchOptions *)options;
+ (PHFetchResult<PHAsset *> *)fetchAssetsWithOptions:(nullable PHFetchOptions *)options;
@end
typedef NSUInteger PHContentEditingInputRequestID API_AVAILABLE(ios(8));
PHOTOS_EXTERN NSString *const PHContentEditingInputResultIsInCloudKey;
PHOTOS_EXTERN NSString *const PHContentEditingInputCancelledKey;
PHOTOS_EXTERN NSString *const PHContentEditingInputErrorKey;
@interface PHAsset (PHContentEditingInput)
/* the input on the main queue: the asset as it is, or the original with the stored adjustments when the options'
   canHandleAdjustmentData accepts them */
- (PHContentEditingInputRequestID)requestContentEditingInputWithOptions:(nullable PHContentEditingInputRequestOptions *)options
    completionHandler:(void (^)(PHContentEditingInput * _Nullable contentEditingInput, NSDictionary *info))completionHandler API_AVAILABLE(ios(8));
- (void)cancelContentEditingInputRequest:(PHContentEditingInputRequestID)requestID API_AVAILABLE(ios(8));
@end
NS_ASSUME_NONNULL_END
#endif
