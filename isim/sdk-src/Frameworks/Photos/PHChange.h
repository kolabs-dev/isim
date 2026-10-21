#pragma once
#import <Photos/PHObject.h>
#import <Photos/PHFetchResult.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
API_AVAILABLE(ios(8))
@interface PHObjectChangeDetails<ObjectType : PHObject *> : NSObject
@property (atomic, strong, readonly) ObjectType objectBeforeChanges;
@property (atomic, strong, readonly, nullable) ObjectType objectAfterChanges;
@property (atomic, readonly) BOOL assetContentChanged;
@property (atomic, readonly) BOOL objectWasDeleted;
@end
/* isim: the indexes compare the fetch result with the same fetch run again */
API_AVAILABLE(ios(8))
@interface PHFetchResultChangeDetails<ObjectType : PHObject *> : NSObject
@property (atomic, strong, readonly) PHFetchResult<ObjectType> *fetchResultBeforeChanges;
@property (atomic, strong, readonly) PHFetchResult<ObjectType> *fetchResultAfterChanges;
@property (atomic, readonly) BOOL hasIncrementalChanges;
@property (atomic, strong, readonly, nullable) NSIndexSet *removedIndexes;
@property (atomic, strong, readonly) NSArray<ObjectType> *removedObjects;
@property (atomic, strong, readonly, nullable) NSIndexSet *insertedIndexes;
@property (atomic, strong, readonly) NSArray<ObjectType> *insertedObjects;
@property (atomic, strong, readonly, nullable) NSIndexSet *changedIndexes;
@property (atomic, strong, readonly) NSArray<ObjectType> *changedObjects;
- (void)enumerateMovesWithBlock:(void (^)(NSUInteger fromIndex, NSUInteger toIndex))handler;
@property (atomic, readonly) BOOL hasMoves;
+ (instancetype)changeDetailsFromFetchResult:(PHFetchResult<ObjectType> *)fromResult toFetchResult:(PHFetchResult<ObjectType> *)toResult changedObjects:(NSArray<ObjectType> *)changedObjects;
@end
API_AVAILABLE(ios(8))
@interface PHChange : NSObject
- (nullable PHObjectChangeDetails *)changeDetailsForObject:(PHObject *)object;
- (nullable PHFetchResultChangeDetails *)changeDetailsForFetchResult:(PHFetchResult *)object;
@end
NS_ASSUME_NONNULL_END
#endif
