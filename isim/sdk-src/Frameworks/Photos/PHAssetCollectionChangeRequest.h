#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class PHAsset, PHAssetCollection;
API_AVAILABLE(ios(8))
@interface PHAssetCollectionChangeRequest : NSObject
+ (instancetype)creationRequestForAssetCollectionWithTitle:(NSString *)title;
@property (nonatomic, strong, readonly) PHObjectPlaceholder *placeholderForCreatedAssetCollection;
+ (void)deleteAssetCollections:(id<NSFastEnumeration>)assetCollections;
/* nil for a smart album */
+ (nullable instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection;
+ (nullable instancetype)changeRequestForAssetCollection:(PHAssetCollection *)assetCollection assets:(PHFetchResult<PHAsset *> *)assets;
@property (nonatomic, strong) NSString *title;
- (void)addAssets:(id<NSFastEnumeration>)assets;
- (void)insertAssets:(id<NSFastEnumeration>)assets atIndexes:(NSIndexSet *)indexes;
- (void)removeAssets:(id<NSFastEnumeration>)assets;
- (void)removeAssetsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceAssetsAtIndexes:(NSIndexSet *)indexes withAssets:(id<NSFastEnumeration>)assets;
- (void)moveAssetsAtIndexes:(NSIndexSet *)fromIndexes toIndex:(NSUInteger)toIndex;
@end
NS_ASSUME_NONNULL_END
#endif
