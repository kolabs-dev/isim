#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAsset, UIImage, CLLocation, PHContentEditingOutput;
API_AVAILABLE(ios(8))
@interface PHAssetChangeRequest : NSObject
+ (instancetype)creationRequestForAssetFromImage:(UIImage *)image;
+ (nullable instancetype)creationRequestForAssetFromImageAtFileURL:(NSURL *)fileURL;
+ (nullable instancetype)creationRequestForAssetFromVideoAtFileURL:(NSURL *)fileURL;
@property (nonatomic, strong, readonly, nullable) PHObjectPlaceholder *placeholderForCreatedAsset;
/* assets: an NSArray or a PHFetchResult of PHAssets */
+ (void)deleteAssets:(id<NSFastEnumeration>)assets;
+ (instancetype)changeRequestForAsset:(PHAsset *)asset;
@property (nonatomic, strong, nullable) NSDate *creationDate;
@property (nonatomic, strong, nullable) CLLocation *location;
@property (nonatomic, assign, getter=isFavorite) BOOL favorite;
@property (nonatomic, assign, getter=isHidden) BOOL hidden;
/* an edit to store with the asset (the rendered file and its adjustments) */
@property (nonatomic, strong, nullable) PHContentEditingOutput *contentEditingOutput;
- (void)revertAssetContentToOriginal;
@end
API_AVAILABLE(ios(9))
@interface PHAssetResourceCreationOptions : NSObject
@property (nonatomic, copy, nullable) NSString *originalFilename;
@property (nonatomic, copy, nullable) NSString *uniformTypeIdentifier;
@property (nonatomic, assign) BOOL shouldMoveFile;
@end
/* isim: a photo, a video, or a Live Photo (a photo and its paired video) per asset */
API_AVAILABLE(ios(9))
@interface PHAssetCreationRequest : PHAssetChangeRequest
+ (instancetype)creationRequestForAsset;
+ (BOOL)supportsAssetResourceTypes:(NSArray<NSNumber *> *)types;
- (void)addResourceWithType:(PHAssetResourceType)type fileURL:(NSURL *)fileURL options:(nullable PHAssetResourceCreationOptions *)options;
- (void)addResourceWithType:(PHAssetResourceType)type data:(NSData *)data options:(nullable PHAssetResourceCreationOptions *)options;
@end
NS_ASSUME_NONNULL_END
#endif
