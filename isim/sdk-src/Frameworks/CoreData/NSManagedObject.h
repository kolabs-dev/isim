#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSFetchRequest.h>
NS_ASSUME_NONNULL_BEGIN
@class NSEntityDescription, NSManagedObjectContext, NSPersistentStore;

@interface NSNumber (NSFetchedResultSupport) <NSFetchRequestResult>
@end
@interface NSDictionary (NSFetchedResultSupport) <NSFetchRequestResult>
@end

/// Identifies a managed object in a store: x-coredata://<store UUID>/<Entity>/p<primary key> (temporary IDs:
/// x-coredata:///<Entity>/t<UUID> until the object is saved or obtainPermanentIDsForObjects:error:).
@interface NSManagedObjectID : NSObject <NSCopying, NSFetchRequestResult>
@property (readonly, strong) NSEntityDescription *entity;
@property (nullable, readonly, weak) NSPersistentStore *persistentStore;
@property (readonly, getter=isTemporaryID) BOOL temporaryID;
- (NSURL *)URIRepresentation;
@end

typedef NS_OPTIONS(NSUInteger, NSSnapshotEventType) {
    NSSnapshotEventUndoInsertion = 1 << 1,
    NSSnapshotEventUndoDeletion = 1 << 2,
    NSSnapshotEventUndoUpdate = 1 << 3,
    NSSnapshotEventRollback = 1 << 4,
    NSSnapshotEventRefresh = 1 << 5,
    NSSnapshotEventMergePolicy = 1 << 6
};

/// isim: values live in a per-object dictionary (KVC); @NSManaged / @dynamic properties get accessor
/// implementations at run time (+resolveInstanceMethod:, typed from the property's declared type), including
/// to-many add<Key>Object: / remove<Key>Object: / add<Key>: / remove<Key>: and primitive<Key> accessors.
@interface NSManagedObject : NSObject <NSFetchRequestResult>
@property (class, readonly) BOOL contextShouldIgnoreUnmodeledPropertyChanges;
+ (NSEntityDescription *)entity;
+ (NSFetchRequest *)fetchRequest;
- (__kindof NSManagedObject *)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(nullable NSManagedObjectContext *)context NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithContext:(NSManagedObjectContext *)moc;
@property (nullable, nonatomic, readonly, weak) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, readonly, strong) NSEntityDescription *entity;
@property (nonatomic, readonly, strong) NSManagedObjectID *objectID;
@property (nonatomic, getter=isInserted, readonly) BOOL inserted;
@property (nonatomic, getter=isUpdated, readonly) BOOL updated;
@property (nonatomic, getter=isDeleted, readonly) BOOL deleted;
@property (nonatomic, readonly) BOOL hasChanges;
@property (nonatomic, readonly) BOOL hasPersistentChangedValues;
- (BOOL)hasFaultForRelationshipNamed:(NSString *)key;
- (NSArray<NSManagedObjectID *> *)objectIDsForRelationshipNamed:(NSString *)key;
@property (nonatomic, getter=isFault, readonly) BOOL fault;
@property (nonatomic, readonly) NSUInteger faultingState;
- (void)willAccessValueForKey:(nullable NSString *)key;
- (void)didAccessValueForKey:(nullable NSString *)key;
- (void)willChangeValueForKey:(NSString *)key;
- (void)didChangeValueForKey:(NSString *)key;
- (void)awakeFromFetch NS_REQUIRES_SUPER;
- (void)awakeFromInsert NS_REQUIRES_SUPER;
- (void)awakeFromSnapshotEvents:(NSSnapshotEventType)flags NS_REQUIRES_SUPER;
- (void)prepareForDeletion NS_REQUIRES_SUPER;
- (void)willSave;
- (void)didSave;
- (void)willTurnIntoFault;
- (void)didTurnIntoFault;
- (nullable id)valueForKey:(NSString *)key;
- (void)setValue:(nullable id)value forKey:(NSString *)key;
- (nullable id)primitiveValueForKey:(NSString *)key;
- (void)setPrimitiveValue:(nullable id)value forKey:(NSString *)key;
- (NSMutableSet *)mutableSetValueForKey:(NSString *)key;
- (NSMutableOrderedSet *)mutableOrderedSetValueForKey:(NSString *)key;
- (NSDictionary<NSString *, id> *)committedValuesForKeys:(nullable NSArray<NSString *> *)keys;
- (NSDictionary<NSString *, id> *)changedValues;
- (NSDictionary<NSString *, id> *)changedValuesForCurrentEvent;
- (BOOL)validateValue:(id _Nullable * _Nonnull)value forKey:(NSString *)key error:(NSError **)error;
- (BOOL)validateForDelete:(NSError **)error;
- (BOOL)validateForInsert:(NSError **)error;
- (BOOL)validateForUpdate:(NSError **)error;
/* isim-internal (used by the CoreData Swift overlay's ObservableObject conformance); not iOS API */
- (void)_isim_setWillChangeHandler:(nullable void (^)(void))handler;
@property (nullable, strong, setter=_isim_setObservationToken:) id _isim_observationToken;
@end

NS_ASSUME_NONNULL_END
