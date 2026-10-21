#pragma once
#import <Photos/PhotosTypes.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
/* isim: the objects of a fetch, taken when it ran (Swift's PHFetchResult is a different, generic class) */
API_AVAILABLE(ios(8))
@interface PHFetchResult<ObjectType> : NSObject <NSCopying, NSFastEnumeration>
@property (readonly) NSUInteger count;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;
- (BOOL)containsObject:(ObjectType)anObject;
- (NSUInteger)indexOfObject:(ObjectType)anObject;
- (NSUInteger)indexOfObject:(ObjectType)anObject inRange:(NSRange)range;
@property (nonatomic, readonly, nullable) ObjectType firstObject;
@property (nonatomic, readonly, nullable) ObjectType lastObject;
- (NSArray<ObjectType> *)objectsAtIndexes:(NSIndexSet *)indexes;
- (void)enumerateObjectsUsingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)countOfAssetsWithMediaType:(PHAssetMediaType)mediaType;
@end
NS_ASSUME_NONNULL_END
#endif
