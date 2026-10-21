#pragma once
/* isim ARKit: reference images and objects, point clouds and world maps (they hold their data). */
#import <ARKit/ARError.h>
#import <UIKit/UIKit.h>
#import <ImageIO/ImageIO.h>
#import <SceneKit/SceneKitTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class ARAnchor;
@interface ARReferenceImage : NSObject
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly) CGSize physicalSize;
@property (nonatomic, readonly, nullable) NSString *resourceGroupName;
- (instancetype)initWithCGImage:(CGImageRef)image orientation:(CGImagePropertyOrientation)orientation physicalWidth:(CGFloat)physicalWidth;
+ (nullable NSSet<ARReferenceImage *> *)referenceImagesInGroupNamed:(NSString *)name bundle:(nullable NSBundle *)bundle;
- (void)validateWithCompletionHandler:(void (^)(NSError * _Nullable error))completionHandler;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface ARPointCloud : NSObject <NSSecureCoding>
@property (nonatomic, readonly) NSUInteger count;
@end
@interface ARReferenceObject : NSObject <NSSecureCoding>
@property (class, nonatomic, readonly) NSString *archiveExtension;
@property (nonatomic, copy, nullable) NSString *name;
@property (nonatomic, readonly) simd_float3 center;
@property (nonatomic, readonly) simd_float3 extent;
@property (nonatomic, readonly) simd_float3 scale;
@property (nonatomic, readonly) ARPointCloud *rawFeaturePoints;
@property (nonatomic, readonly, nullable) NSString *resourceGroupName;
- (nullable instancetype)initWithArchiveURL:(NSURL *)url error:(NSError **)error;
+ (nullable NSSet<ARReferenceObject *> *)referenceObjectsInGroupNamed:(NSString *)name bundle:(nullable NSBundle *)bundle;
- (BOOL)exportObjectToURL:(NSURL *)url previewImage:(nullable UIImage *)previewImage error:(NSError **)error;
- (ARReferenceObject *)referenceObjectByApplyingTransform:(simd_float4x4)transform;
- (nullable ARReferenceObject *)referenceObjectByMergingObject:(ARReferenceObject *)object error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface ARWorldMap : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly) simd_float3 center;
@property (nonatomic, readonly) simd_float3 extent;
@property (nonatomic, copy) NSArray<ARAnchor *> *anchors;
@property (nonatomic, readonly) ARPointCloud *rawFeaturePoints;
@end
NS_ASSUME_NONNULL_END
#endif
