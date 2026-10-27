#pragma once
#import <Photos/PhotosTypes.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAsset, UIImage, AVAsset, AVAudioMix, AVPlayerItem, AVAssetExportSession;
typedef NS_ENUM(NSInteger, PHImageRequestOptionsVersion) {
    PHImageRequestOptionsVersionCurrent = 0, PHImageRequestOptionsVersionUnadjusted, PHImageRequestOptionsVersionOriginal,
};
typedef NS_ENUM(NSInteger, PHImageRequestOptionsDeliveryMode) {
    PHImageRequestOptionsDeliveryModeOpportunistic = 0, PHImageRequestOptionsDeliveryModeHighQualityFormat = 1, PHImageRequestOptionsDeliveryModeFastFormat = 2,
};
typedef NS_ENUM(NSInteger, PHImageRequestOptionsResizeMode) {
    PHImageRequestOptionsResizeModeNone = 0, PHImageRequestOptionsResizeModeFast, PHImageRequestOptionsResizeModeExact,
};
typedef NS_ENUM(NSInteger, PHImageContentMode) {
    PHImageContentModeAspectFit = 0, PHImageContentModeAspectFill = 1, PHImageContentModeDefault = PHImageContentModeAspectFit,
};
typedef NS_ENUM(NSInteger, PHVideoRequestOptionsVersion) { PHVideoRequestOptionsVersionCurrent = 0, PHVideoRequestOptionsVersionOriginal };
typedef NS_ENUM(NSInteger, PHVideoRequestOptionsDeliveryMode) {
    PHVideoRequestOptionsDeliveryModeAutomatic = 0, PHVideoRequestOptionsDeliveryModeHighQualityFormat = 1,
    PHVideoRequestOptionsDeliveryModeMediumQualityFormat = 2, PHVideoRequestOptionsDeliveryModeFastFormat = 3,
};
typedef int32_t PHImageRequestID;
static const PHImageRequestID PHInvalidImageRequestID = 0;
PHOTOS_EXTERN CGSize const PHImageManagerMaximumSize;
PHOTOS_EXTERN NSString * const PHImageResultIsInCloudKey;
PHOTOS_EXTERN NSString * const PHImageResultIsDegradedKey;
PHOTOS_EXTERN NSString * const PHImageResultRequestIDKey;
PHOTOS_EXTERN NSString * const PHImageCancelledKey;
PHOTOS_EXTERN NSString * const PHImageErrorKey;
typedef void (^PHAssetImageProgressHandler)(double progress, NSError * _Nullable error, BOOL *stop, NSDictionary * _Nullable info);
typedef void (^PHAssetVideoProgressHandler)(double progress, NSError * _Nullable error, BOOL *stop, NSDictionary * _Nullable info);
API_AVAILABLE(ios(8))
@interface PHImageRequestOptions : NSObject <NSCopying>
@property (nonatomic, assign) PHImageRequestOptionsVersion version;
@property (nonatomic, assign) PHImageRequestOptionsDeliveryMode deliveryMode;
@property (nonatomic, assign) PHImageRequestOptionsResizeMode resizeMode;
@property (nonatomic, assign) CGRect normalizedCropRect;
@property (nonatomic, assign, getter=isNetworkAccessAllowed) BOOL networkAccessAllowed;
@property (nonatomic, assign, getter=isSynchronous) BOOL synchronous;
@property (nonatomic, copy, nullable) PHAssetImageProgressHandler progressHandler;
@property (nonatomic) BOOL allowSecondaryDegradedImage API_AVAILABLE(ios(17));
@end
API_AVAILABLE(ios(8))
@interface PHVideoRequestOptions : NSObject
@property (nonatomic, assign, getter=isNetworkAccessAllowed) BOOL networkAccessAllowed;
@property (nonatomic, assign) PHVideoRequestOptionsVersion version;
@property (nonatomic, assign) PHVideoRequestOptionsDeliveryMode deliveryMode;
@property (nonatomic, copy, nullable) PHAssetVideoProgressHandler progressHandler;
@end
@class PHLivePhoto;
API_AVAILABLE(ios(9.1))
@interface PHLivePhotoRequestOptions : NSObject <NSCopying>
@property (nonatomic, assign) PHImageRequestOptionsVersion version;
@property (nonatomic, assign) PHImageRequestOptionsDeliveryMode deliveryMode;
@property (nonatomic, assign, getter=isNetworkAccessAllowed) BOOL networkAccessAllowed;
@property (nonatomic, copy, nullable) PHAssetImageProgressHandler progressHandler;
@property (nonatomic, assign) BOOL preferHDR API_AVAILABLE(ios(18));
@end
/* isim: images are the library files scaled to the target size; asynchronous requests answer on the main queue, video
   requests on a background queue */
API_AVAILABLE(ios(8))
@interface PHImageManager : NSObject
+ (PHImageManager *)defaultManager;
- (PHImageRequestID)requestImageForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options resultHandler:(void (^)(UIImage * _Nullable result, NSDictionary * _Nullable info))resultHandler;
- (PHImageRequestID)requestImageDataAndOrientationForAsset:(PHAsset *)asset options:(nullable PHImageRequestOptions *)options resultHandler:(void (^)(NSData * _Nullable imageData, NSString * _Nullable dataUTI, CGImagePropertyOrientation orientation, NSDictionary * _Nullable info))resultHandler API_AVAILABLE(ios(13));
- (void)cancelImageRequest:(PHImageRequestID)requestID;
/* a Live Photo asset's PHLivePhoto, on the main queue */
- (PHImageRequestID)requestLivePhotoForAsset:(PHAsset *)asset targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHLivePhotoRequestOptions *)options resultHandler:(void (^)(PHLivePhoto * _Nullable livePhoto, NSDictionary * _Nullable info))resultHandler API_AVAILABLE(ios(9.1));
- (PHImageRequestID)requestPlayerItemForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options resultHandler:(void (^)(AVPlayerItem * _Nullable playerItem, NSDictionary * _Nullable info))resultHandler;
- (PHImageRequestID)requestExportSessionForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options exportPreset:(NSString *)exportPreset resultHandler:(void (^)(AVAssetExportSession * _Nullable exportSession, NSDictionary * _Nullable info))resultHandler;
- (PHImageRequestID)requestAVAssetForVideo:(PHAsset *)asset options:(nullable PHVideoRequestOptions *)options resultHandler:(void (^)(AVAsset * _Nullable asset, AVAudioMix * _Nullable audioMix, NSDictionary * _Nullable info))resultHandler;
@end
/* isim: requests are not cached (nothing to warm up) */
API_AVAILABLE(ios(8))
@interface PHCachingImageManager : PHImageManager
@property (nonatomic, assign) BOOL allowsCachingHighQualityImages;
- (void)startCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options;
- (void)stopCachingImagesForAssets:(NSArray<PHAsset *> *)assets targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode options:(nullable PHImageRequestOptions *)options;
- (void)stopCachingImagesForAllAssets;
@end
NS_ASSUME_NONNULL_END
#endif
