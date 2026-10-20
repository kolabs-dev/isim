#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSPersistentStoreCoordinator.h>
#import <CoreData/NSFetchRequest.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObject, NSManagedObjectID, NSManagedObjectContext, NSEntityDescription, NSPropertyDescription, NSRelationshipDescription, NSIncrementalStoreNode;

/// A store an app implements: register its class with +[NSPersistentStoreCoordinator registerStoreClass:forStoreType:],
/// then add a store of that type. isim's contexts call it like Apple's: executeRequest:withContext:error: for fetches
/// (NSFetchRequest, the context's request with its entity set; managed objects or object IDs back) and saves
/// (NSSaveChangesRequest), newValuesForObjectWithID: when a fault fires, newValueForRelationship: for to-many (and
/// missing to-one) relationships, and obtainPermanentIDsForObjects: before inserted objects are saved.
@interface NSIncrementalStore : NSPersistentStore
- (BOOL)loadMetadata:(NSError **)error;
- (nullable id)executeRequest:(NSPersistentStoreRequest *)request withContext:(nullable NSManagedObjectContext *)context error:(NSError **)error NS_SWIFT_NAME(execute(_:with:));
- (nullable NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error NS_SWIFT_NAME(newValuesForObject(with:with:));
- (nullable id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(nullable NSManagedObjectContext *)context error:(NSError **)error NS_SWIFT_NAME(newValue(forRelationship:forObjectWith:with:));
+ (id)identifierForNewStoreAtURL:(NSURL *)storeURL NS_SWIFT_NAME(identifierForNewStore(at:));
- (nullable NSArray<NSManagedObjectID *> *)obtainPermanentIDsForObjects:(NSArray<NSManagedObject *> *)array error:(NSError **)error NS_SWIFT_NAME(obtainPermanentIDs(for:));
- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray<NSManagedObjectID *> *)objectIDs NS_SWIFT_NAME(managedObjectContextDidRegisterObjects(with:));
- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray<NSManagedObjectID *> *)objectIDs NS_SWIFT_NAME(managedObjectContextDidUnregisterObjects(with:));
- (NSManagedObjectID *)newObjectIDForEntity:(NSEntityDescription *)entity referenceObject:(id)data NS_SWIFT_NAME(newObjectID(for:referenceObject:));
- (id)referenceObjectForObjectID:(NSManagedObjectID *)objectID NS_SWIFT_NAME(referenceObject(for:));
@end

/// An object's values as an incremental store returns them: attribute values (NSNull for nil) and to-one relationships
/// as NSManagedObjectID (NSNull for none); to-many relationships may be left out (they are asked for when used).
@interface NSIncrementalStoreNode : NSObject
- (instancetype)initWithObjectID:(NSManagedObjectID *)objectID withValues:(NSDictionary<NSString *, id> *)values version:(uint64_t)version;
- (void)updateWithValues:(NSDictionary<NSString *, id> *)values version:(uint64_t)version;
@property (nonatomic, readonly, strong) NSManagedObjectID *objectID;
@property (nonatomic, readonly) uint64_t version;
- (nullable id)valueForPropertyDescription:(NSPropertyDescription *)prop NS_SWIFT_NAME(value(for:));
@end

@interface NSSaveChangesRequest : NSPersistentStoreRequest
- (instancetype)initWithInsertedObjects:(nullable NSSet<NSManagedObject *> *)insertedObjects updatedObjects:(nullable NSSet<NSManagedObject *> *)updatedObjects deletedObjects:(nullable NSSet<NSManagedObject *> *)deletedObjects lockedObjects:(nullable NSSet<NSManagedObject *> *)lockedObjects NS_SWIFT_NAME(init(inserted:updated:deleted:locked:));
@property (nullable, readonly, strong) NSSet<NSManagedObject *> *insertedObjects;
@property (nullable, readonly, strong) NSSet<NSManagedObject *> *updatedObjects;
@property (nullable, readonly, strong) NSSet<NSManagedObject *> *deletedObjects;
@property (nullable, readonly, strong) NSSet<NSManagedObject *> *lockedObjects;
@end

@interface NSPersistentStoreCoordinator (NSIncrementalStore)
/// Maps a store type to an NSPersistentStore subclass (nil removes it); addPersistentStoreWithType: then creates that
/// class, calls its loadMetadata:, and adds it.
+ (void)registerStoreClass:(nullable Class)storeClass forStoreType:(NSString *)storeType;
/// The registered types (SQLite and InMemory, isim's own, included) and their classes (NSValue pointers).
@property (class, readonly, strong) NSDictionary<NSString *, NSValue *> *registeredStoreTypes;
@end
NS_ASSUME_NONNULL_END
