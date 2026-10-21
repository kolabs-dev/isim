#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObject;

/* merge policies */
COREDATA_EXTERN id NSErrorMergePolicy;
COREDATA_EXTERN id NSMergeByPropertyStoreTrumpMergePolicy;
COREDATA_EXTERN id NSMergeByPropertyObjectTrumpMergePolicy;
COREDATA_EXTERN id NSOverwriteMergePolicy;
COREDATA_EXTERN id NSRollbackMergePolicy;

typedef NS_ENUM(NSUInteger, NSMergePolicyType) {
    NSErrorMergePolicyType NS_SWIFT_NAME(errorMergePolicyType) = 0x00,
    NSMergeByPropertyStoreTrumpMergePolicyType NS_SWIFT_NAME(mergeByPropertyStoreTrumpMergePolicyType) = 0x01,
    NSMergeByPropertyObjectTrumpMergePolicyType NS_SWIFT_NAME(mergeByPropertyObjectTrumpMergePolicyType) = 0x02,
    NSOverwriteMergePolicyType NS_SWIFT_NAME(overwriteMergePolicyType) = 0x03,
    NSRollbackMergePolicyType NS_SWIFT_NAME(rollbackMergePolicyType) = 0x04
};

/// isim: optimistic locking per row; on a conflicting save the policy decides per object (error: the save
/// fails with NSManagedObjectMergeError; object trump / overwrite: this context's values win; store trump:
/// the stored values win for the conflicting object's properties; rollback: this context's changes to it are dropped).
@class NSMergeConflict, NSConstraintConflict;
@interface NSMergePolicy : NSObject
@property (class, readonly, strong) NSMergePolicy *errorMergePolicy NS_SWIFT_NAME(error);
@property (class, readonly, strong) NSMergePolicy *rollbackMergePolicy NS_SWIFT_NAME(rollback);
@property (class, readonly, strong) NSMergePolicy *overwriteMergePolicy NS_SWIFT_NAME(overwrite);
@property (class, readonly, strong) NSMergePolicy *mergeByPropertyObjectTrumpMergePolicy NS_SWIFT_NAME(mergeByPropertyObjectTrump);
@property (class, readonly, strong) NSMergePolicy *mergeByPropertyStoreTrumpMergePolicy NS_SWIFT_NAME(mergeByPropertyStoreTrump);
@property (readonly) NSMergePolicyType mergeType;
- (id)initWithMergeType:(NSMergePolicyType)ty NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(merge:));
- (instancetype)init NS_UNAVAILABLE;
/// Resolves a failed save's conflicts (NSMergeConflict and NSConstraintConflict objects): the default calls the two
/// methods below. Subclasses override them, and usually call super. Apple's names; isim's save calls them.
- (BOOL)resolveConflicts:(NSArray *)list error:(NSError **)error NS_SWIFT_NAME(resolve(mergeConflicts:));
- (BOOL)resolveOptimisticLockingVersionConflicts:(NSArray<NSMergeConflict *> *)list error:(NSError **)error NS_SWIFT_NAME(resolve(optimisticLockingVersionConflicts:));
- (BOOL)resolveConstraintConflicts:(NSArray<NSConstraintConflict *> *)list error:(NSError **)error NS_SWIFT_NAME(resolve(constraintConflicts:));
@end

/// An optimistic-locking conflict: the object's row changed (or was deleted: newVersionNumber 0, no persisted
/// snapshot) in the store since the context read it. Snapshots map property names to values (NSNull for nil,
/// to-one relationships as NSManagedObjectID).
@interface NSMergeConflict : NSObject
@property (readonly, strong) NSManagedObject *sourceObject;
@property (nullable, readonly, strong) NSDictionary<NSString *, id> *objectSnapshot;
@property (nullable, readonly, strong) NSDictionary<NSString *, id> *cachedSnapshot;
@property (nullable, readonly, strong) NSDictionary<NSString *, id> *persistedSnapshot;
@property (readonly) NSUInteger newVersionNumber;
@property (readonly) NSUInteger oldVersionNumber;
- (instancetype)initWithSource:(NSManagedObject *)srcObject newVersion:(NSUInteger)newvers oldVersion:(NSUInteger)oldvers cachedSnapshot:(nullable NSDictionary<NSString *, id> *)cachesnap persistedSnapshot:(nullable NSDictionary<NSString *, id> *)persnap NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

/// A uniqueness-constraint conflict: inserted objects whose constraint values match a stored row (databaseObject)
/// or each other (databaseObject nil).
@interface NSConstraintConflict : NSObject
@property (readonly, copy) NSArray<NSString *> *constraint;
@property (readonly, copy) NSDictionary<NSString *, id> *constraintValues;
@property (nullable, readonly, strong) NSManagedObject *databaseObject;
@property (nullable, readonly, copy) NSDictionary<NSString *, id> *databaseSnapshot;
@property (readonly, copy) NSArray<NSManagedObject *> *conflictingObjects;
@property (readonly, copy) NSArray<NSDictionary *> *conflictingSnapshots;
- (instancetype)initWithConstraint:(NSArray<NSString *> *)contraint databaseObject:(nullable NSManagedObject *)databaseObject databaseSnapshot:(nullable NSDictionary *)databaseSnapshot conflictingObjects:(NSArray<NSManagedObject *> *)conflictingObjects conflictingSnapshots:(NSArray *)conflictingSnapshots NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
