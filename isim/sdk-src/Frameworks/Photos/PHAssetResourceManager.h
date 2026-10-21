#pragma once
#import <Photos/PHAssetResource.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
typedef void (^PHAssetResourceProgressHandler)(double progress);
typedef int32_t PHAssetResourceDataRequestID;
API_AVAILABLE(ios(9))
@interface PHAssetResourceRequestOptions : NSObject <NSCopying>
@property (nonatomic, assign, getter=isNetworkAccessAllowed) BOOL networkAccessAllowed;
@property (nonatomic, copy, nullable) PHAssetResourceProgressHandler progressHandler;
@end
/* isim: the data is read in chunks on a background queue */
API_AVAILABLE(ios(9))
@interface PHAssetResourceManager : NSObject
+ (PHAssetResourceManager *)defaultManager;
- (PHAssetResourceDataRequestID)requestDataForAssetResource:(PHAssetResource *)resource options:(nullable PHAssetResourceRequestOptions *)options dataReceivedHandler:(void (^)(NSData *data))handler completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)writeDataForAssetResource:(PHAssetResource *)resource toFile:(NSURL *)fileURL options:(nullable PHAssetResourceRequestOptions *)options completionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (void)cancelDataRequest:(PHAssetResourceDataRequestID)requestID;
@end
NS_ASSUME_NONNULL_END
#endif
