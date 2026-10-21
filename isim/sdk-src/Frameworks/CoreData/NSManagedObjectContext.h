#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSFetchRequest.h>
#import <CoreData/NSMergePolicy.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObject, NSManagedObjectID, NSPersistentStoreCoordinator, NSPersistentStoreRequest, NSPersistentStoreResult;

COREDATA_EXTERN NSNotificationName const NSManagedObjectContextWillSaveNotification;
COREDATA_EXTERN NSNotificationName const NSManagedObjectContextDidSaveNotification;
COREDATA_EXTERN NSNotificationName const NSManagedObjectContextObjectsDidChangeNotification;
COREDATA_EXTERN NSNotificationName const NSManagedObjectContextDidSaveObjectIDsNotification;
COREDATA_EXTERN NSNotificationName const NSManagedObjectContextDidMergeChangesObjectIDsNotification;
COREDATA_EXTERN NSString * const NSInsertedObjectsKey;
COREDATA_EXTERN NSString * const NSUpdatedObjectsKey;
COREDATA_EXTERN NSString * const NSDeletedObjectsKey;
COREDATA_EXTERN NSString * const NSRefreshedObjectsKey;
COREDATA_EXTERN NSString * const NSInvalidatedObjectsKey;
COREDATA_EXTERN NSString * const NSInvalidatedAllObjectsKey;
COREDATA_EXTERN NSString * const NSInsertedObjectIDsKey;
COREDATA_EXTERN NSString * const NSUpdatedObjectIDsKey;
COREDATA_EXTERN NSString * const NSDeletedObjectIDsKey;
COREDATA_EXTERN NSString * const NSRefreshedObjectIDsKey;
COREDATA_EXTERN NSString * const NSInvalidatedObjectIDsKey;
COREDATA_EXTERN NSString * const NSManagedObjectContextQueryGenerationKey;

typedef NS_ENUM(NSUInteger, NSManagedObjectContextConcurrencyType) {
    NSConfinementConcurrencyType NS_SWIFT_NAME(confinementConcurrencyType) = 0x00,
    NSPrivateQueueConcurrencyType NS_SWIFT_NAME(privateQueueConcurrencyType) = 0x01,
    NSMainQueueConcurrencyType NS_SWIFT_NAME(mainQueueConcurrencyType) = 0x02
};

/// A snapshot of the stores' data that contexts can be pinned to. isim: an SQLite read transaction (WAL journal mode) on
/// its own connection per store, kept open while the token lives; in-memory stores do not support it.
@interface NSQueryGenerationToken : NSObject <NSSecureCoding, NSCopying>
@property (class, readonly, strong) NSQueryGenerationToken *currentQueryGenerationToken NS_SWIFT_NAME(current);
@end

/// isim: a context keeps strong references to its registered objects (like retainsRegisteredObjects = YES).
/// Fetches in child contexts go through the parent (so they see its unsaved changes); saves of a child push its
/// changes into the parent; saves of a root context write to the store in one SQLite transaction.
@interface NSManagedObjectContext : NSObject <NSLocking>
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithConcurrencyType:(NSManagedObjectContextConcurrencyType)ct NS_DESIGNATED_INITIALIZER;
- (void)performBlock:(void (^)(void))block NS_SWIFT_NAME(perform(_:));
- (void)performBlockAndWait:(void (NS_NOESCAPE ^)(void))block NS_SWIFT_NAME(performAndWait(_:));
@property (nullable, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nullable, strong) NSManagedObjectContext *parentContext NS_SWIFT_NAME(parent);
@property (nullable, copy) NSString *name;
@property (nullable, nonatomic, strong) NSUndoManager *undoManager;
@property (nonatomic, readonly) BOOL hasChanges;
@property (nonatomic, readonly, strong) NSMutableDictionary *userInfo;
@property (readonly) NSManagedObjectContextConcurrencyType concurrencyType;
- (nullable __kindof NSManagedObject *)objectRegisteredForID:(NSManagedObjectID *)objectID NS_SWIFT_NAME(registeredObject(for:));
- (__kindof NSManagedObject *)objectWithID:(NSManagedObjectID *)objectID NS_SWIFT_NAME(object(with:));
- (nullable __kindof NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)objectID error:(NSError **)error NS_SWIFT_NAME(existingObject(with:));
- (nullable NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error NS_SWIFT_NAME(__fetch(_:));
- (NSUInteger)countForFetchRequest:(NSFetchRequest *)request error:(NSError **)error NS_SWIFT_NAME(__count(for:error:));
- (nullable __kindof NSPersistentStoreResult *)executeRequest:(NSPersistentStoreRequest *)request error:(NSError **)error NS_SWIFT_NAME(execute(_:));
- (void)insertObject:(NSManagedObject *)object NS_SWIFT_NAME(insert(_:));
- (void)deleteObject:(NSManagedObject *)object NS_SWIFT_NAME(delete(_:));
- (void)refreshObject:(NSManagedObject *)object mergeChanges:(BOOL)flag NS_SWIFT_NAME(refresh(_:mergeChanges:));
- (void)detectConflictsForObject:(NSManagedObject *)object;
- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context;
- (void)processPendingChanges;
- (void)assignObject:(id)object toPersistentStore:(NSPersistentStore *)store;
@property (nonatomic, readonly, strong) NSSet<__kindof NSManagedObject *> *insertedObjects;
@property (nonatomic, readonly, strong) NSSet<__kindof NSManagedObject *> *updatedObjects;
@property (nonatomic, readonly, strong) NSSet<__kindof NSManagedObject *> *deletedObjects;
@property (nonatomic, readonly, strong) NSSet<__kindof NSManagedObject *> *registeredObjects;
- (void)undo;
- (void)redo;
- (void)reset;
- (void)rollback;
- (BOOL)save:(NSError **)error;
- (void)refreshAllObjects;
- (void)lock;
- (void)unlock;
- (BOOL)tryLock;
@property (nonatomic) BOOL propagatesDeletesAtEndOfEvent;
@property (nonatomic) BOOL retainsRegisteredObjects;
@property BOOL shouldDeleteInaccessibleFaults;
@property NSTimeInterval stalenessInterval;
@property (strong) id mergePolicy;
- (BOOL)obtainPermanentIDsForObjects:(NSArray<NSManagedObject *> *)objects error:(NSError **)error;
- (void)mergeChangesFromContextDidSaveNotification:(NSNotification *)notification NS_SWIFT_NAME(mergeChanges(fromContextDidSave:));
+ (void)mergeChangesFromRemoteContextSave:(NSDictionary *)changeNotificationData intoContexts:(NSArray<NSManagedObjectContext *> *)contexts NS_SWIFT_NAME(mergeChanges(fromRemoteContextSave:into:));
@property (nonatomic) BOOL automaticallyMergesChangesFromParent;
@property (nullable, copy) NSString *transactionAuthor;
/// The generation the context reads (nil: unpinned, it reads the latest data). Saving, merging and resetting a pinned
/// context move it to a new snapshot of the current data. isim: only root contexts pin; child contexts read through
/// their parent.
@property (nullable, nonatomic, strong, readonly) NSQueryGenerationToken *queryGenerationToken;
- (BOOL)setQueryGenerationFromToken:(nullable NSQueryGenerationToken *)generation error:(NSError **)error NS_SWIFT_NAME(setQueryGenerationFrom(_:));
@end

NS_ASSUME_NONNULL_END
