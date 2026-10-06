#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSEntityDescription, NSPersistentStore, NSManagedObjectID;

typedef NS_ENUM(NSUInteger, NSPersistentStoreRequestType) {
    NSFetchRequestType NS_SWIFT_NAME(fetchRequestType) = 1,
    NSSaveRequestType NS_SWIFT_NAME(saveRequestType),
    NSBatchInsertRequestType NS_SWIFT_NAME(batchInsertRequestType) = 5,
    NSBatchUpdateRequestType NS_SWIFT_NAME(batchUpdateRequestType) = 6,
    NSBatchDeleteRequestType NS_SWIFT_NAME(batchDeleteRequestType) = 7
};

@interface NSPersistentStoreRequest : NSObject <NSCopying>
@property (nullable, nonatomic, strong) NSArray<NSPersistentStore *> *affectedStores;
@property (readonly) NSPersistentStoreRequestType requestType;
@end

typedef NS_OPTIONS(NSUInteger, NSFetchRequestResultType) {
    NSManagedObjectResultType NS_SWIFT_NAME(managedObjectResultType) = 0x00,
    NSManagedObjectIDResultType NS_SWIFT_NAME(managedObjectIDResultType) = 0x01,
    NSDictionaryResultType NS_SWIFT_NAME(dictionaryResultType) = 0x02,
    NSCountResultType NS_SWIFT_NAME(countResultType) = 0x04
};

/// isim: predicates on attributes (comparisons, BEGINSWITH/ENDSWITH/CONTAINS without options, IN, BETWEEN,
/// AND/OR/NOT, to-one relationship and SELF equality) run as SQL WHERE clauses; anything else is evaluated
/// in memory with NSPredicate. Unsaved changes in the context (and its parents) are always included.
@interface NSFetchRequest<__covariant ResultType : id<NSFetchRequestResult>> : NSPersistentStoreRequest <NSCoding>
+ (instancetype)fetchRequestWithEntityName:(NSString *)entityName;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithEntityName:(NSString *)entityName;
- (nullable NSArray<ResultType> *)execute:(NSError **)error NS_SWIFT_NAME(execute());
@property (nullable, nonatomic, strong) NSEntityDescription *entity;
@property (nullable, nonatomic, readonly, strong) NSString *entityName;
@property (nullable, nonatomic, strong) NSPredicate *predicate;
@property (nullable, nonatomic, strong) NSArray<NSSortDescriptor *> *sortDescriptors;
@property (nonatomic) NSUInteger fetchLimit;
@property (nonatomic) NSUInteger fetchOffset;
@property (nonatomic) NSUInteger fetchBatchSize;
@property (nonatomic) NSFetchRequestResultType resultType;
@property (nonatomic) BOOL includesSubentities;
@property (nonatomic) BOOL includesPropertyValues;
@property (nonatomic) BOOL returnsObjectsAsFaults;
@property (nullable, nonatomic, copy) NSArray<NSString *> *relationshipKeyPathsForPrefetching;
@property (nonatomic) BOOL includesPendingChanges;
@property (nonatomic) BOOL returnsDistinctResults;
@property (nullable, nonatomic, copy) NSArray *propertiesToFetch;
@property (nullable, nonatomic, copy) NSArray *propertiesToGroupBy;
@property (nullable, nonatomic, strong) NSPredicate *havingPredicate;
@property (nonatomic) BOOL shouldRefreshRefetchedObjects;
@end

@interface NSPersistentStoreResult : NSObject
@end

typedef NS_ENUM(NSUInteger, NSBatchDeleteRequestResultType) {
    NSBatchDeleteResultTypeStatusOnly NS_SWIFT_NAME(resultTypeStatusOnly) = 0x0,
    NSBatchDeleteResultTypeObjectIDs NS_SWIFT_NAME(resultTypeObjectIDs) = 0x1,
    NSBatchDeleteResultTypeCount NS_SWIFT_NAME(resultTypeCount) = 0x2,
};
typedef NS_ENUM(NSUInteger, NSBatchUpdateRequestResultType) {
    NSStatusOnlyResultType NS_SWIFT_NAME(statusOnlyResultType) = 0x0,
    NSUpdatedObjectIDsResultType NS_SWIFT_NAME(updatedObjectIDsResultType) = 0x1,
    NSUpdatedObjectsCountResultType NS_SWIFT_NAME(updatedObjectsCountResultType) = 0x2
};

/// isim: deletes rows directly in the store (no delete rules run; to-one keys and join rows that point at
/// deleted rows are cleared). Contexts are not updated: merge the result's object IDs with
/// +[NSManagedObjectContext mergeChangesFromRemoteContextSave:intoContexts:].
@interface NSBatchDeleteRequest : NSPersistentStoreRequest
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetch NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObjectIDs:(NSArray<NSManagedObjectID *> *)objects;
@property NSBatchDeleteRequestResultType resultType;
@property (readonly, copy) NSFetchRequest *fetchRequest;
@end

@interface NSBatchUpdateRequest : NSPersistentStoreRequest
+ (instancetype)batchUpdateRequestWithEntityName:(NSString *)entityName;
- (instancetype)initWithEntityName:(NSString *)entityName;
- (instancetype)initWithEntity:(NSEntityDescription *)entity NS_DESIGNATED_INITIALIZER;
@property (copy, readonly) NSString *entityName;
@property (strong, readonly) NSEntityDescription *entity;
@property (nullable, strong) NSPredicate *predicate;
@property BOOL includesSubentities;
@property NSBatchUpdateRequestResultType resultType;
@property (nullable, copy) NSDictionary *propertiesToUpdate;
@end

@interface NSBatchDeleteResult : NSPersistentStoreResult
@property (nullable, strong, readonly) id result;
@property (readonly) NSBatchDeleteRequestResultType resultType;
@end
@interface NSBatchUpdateResult : NSPersistentStoreResult
@property (nullable, strong, readonly) id result;
@property (readonly) NSBatchUpdateRequestResultType resultType;
@end

NS_ASSUME_NONNULL_END
