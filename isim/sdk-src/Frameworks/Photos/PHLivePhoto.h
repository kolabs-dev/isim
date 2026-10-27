#pragma once
#import <Photos/PhotosTypes.h>
#import <Photos/PHImageManager.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class UIImage;
typedef int32_t PHLivePhotoRequestID API_AVAILABLE(ios(9.1));
static const PHLivePhotoRequestID PHLivePhotoRequestIDInvalid = 0;
PHOTOS_EXTERN NSString *const PHLivePhotoInfoErrorKey API_AVAILABLE(ios(9.1));
PHOTOS_EXTERN NSString *const PHLivePhotoInfoIsDegradedKey API_AVAILABLE(ios(9.1));
PHOTOS_EXTERN NSString *const PHLivePhotoInfoCancelledKey API_AVAILABLE(ios(10));
/* a still image and its paired movie */
API_AVAILABLE(ios(9.1))
@interface PHLivePhoto : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, assign, readonly) CGSize size;
/* from an image file and a movie file (in either order); the handler runs on the main queue, first with the placeholder
   (degraded) when one is given */
+ (PHLivePhotoRequestID)requestLivePhotoWithResourceFileURLs:(NSArray<NSURL *> *)fileURLs placeholderImage:(nullable UIImage *)image
    targetSize:(CGSize)targetSize contentMode:(PHImageContentMode)contentMode
    resultHandler:(void (^)(PHLivePhoto * _Nullable livePhoto, NSDictionary *info))resultHandler;
+ (void)cancelLivePhotoRequestWithRequestID:(PHLivePhotoRequestID)requestID;
@end
NS_ASSUME_NONNULL_END
#endif
