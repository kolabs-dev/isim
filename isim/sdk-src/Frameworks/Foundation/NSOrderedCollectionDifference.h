#pragma once
/* isim Foundation (self-authored, Apple's declarations and values): NSOrderedCollectionChange and
   NSOrderedCollectionDifference, the changes between two ordered collections (NSArray / NSOrderedSet differences:
   removals by their index in the old collection, insertions by their index in the new one). Adapted: the difference is a
   longest common subsequence of the two; inferMoves pairs a removal and an insertion of equal objects (associatedIndex). */
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSIndexSet.h>
#import <Foundation/NSOrderedSet.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, NSCollectionChangeType) {
    NSCollectionChangeInsert,
    NSCollectionChangeRemove
};

@interface NSOrderedCollectionChange<ObjectType> : NSObject
+ (NSOrderedCollectionChange<ObjectType> *)changeWithObject:(nullable ObjectType)anObject type:(NSCollectionChangeType)type
                                                      index:(NSUInteger)index NS_SWIFT_UNAVAILABLE("use init(object:type:index:)");
+ (NSOrderedCollectionChange<ObjectType> *)changeWithObject:(nullable ObjectType)anObject type:(NSCollectionChangeType)type
                                                      index:(NSUInteger)index associatedIndex:(NSUInteger)associatedIndex
    NS_SWIFT_UNAVAILABLE("use init(object:type:index:associatedIndex:)");
@property (readonly, strong, nullable) ObjectType object;
@property (readonly) NSCollectionChangeType changeType;
@property (readonly) NSUInteger index;
/* the paired change's index (a move), else NSNotFound */
@property (readonly) NSUInteger associatedIndex;
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithObject:(nullable ObjectType)anObject type:(NSCollectionChangeType)type index:(NSUInteger)index;
- (instancetype)initWithObject:(nullable ObjectType)anObject type:(NSCollectionChangeType)type index:(NSUInteger)index
               associatedIndex:(NSUInteger)associatedIndex NS_DESIGNATED_INITIALIZER;
@end

typedef NS_OPTIONS(NSUInteger, NSOrderedCollectionDifferenceCalculationOptions) {
    NSOrderedCollectionDifferenceCalculationOmitInsertedObjects = (1 << 0UL),
    NSOrderedCollectionDifferenceCalculationOmitRemovedObjects = (1 << 1UL),
    NSOrderedCollectionDifferenceCalculationInferMoves = (1 << 2UL)
};

@interface NSOrderedCollectionDifference<ObjectType> : NSObject <NSFastEnumeration>
- (instancetype)initWithChanges:(NSArray<NSOrderedCollectionChange<ObjectType> *> *)changes;
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(nullable NSArray<ObjectType> *)insertedObjects
                        removeIndexes:(NSIndexSet *)removes removedObjects:(nullable NSArray<ObjectType> *)removedObjects
                    additionalChanges:(NSArray<NSOrderedCollectionChange<ObjectType> *> *)changes NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(nullable NSArray<ObjectType> *)insertedObjects
                        removeIndexes:(NSIndexSet *)removes removedObjects:(nullable NSArray<ObjectType> *)removedObjects;
- (instancetype)init NS_UNAVAILABLE;
@property (strong, readonly) NSArray<NSOrderedCollectionChange<ObjectType> *> *insertions;
@property (strong, readonly) NSArray<NSOrderedCollectionChange<ObjectType> *> *removals;
@property (assign, readonly) BOOL hasChanges;
- (NSOrderedCollectionDifference<id> *)differenceByTransformingChangesWithBlock:
    (NSOrderedCollectionChange<id> *(NS_NOESCAPE ^)(NSOrderedCollectionChange<ObjectType> *))block NS_SWIFT_NAME(transformingChanges(_:));
- (instancetype)inverseDifference;
@end

@interface NSArray<ObjectType> (NSArrayDiffing)
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromArray:(NSArray<ObjectType> *)other
                                                       withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
                                              usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj1, ObjectType obj2))block;
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromArray:(NSArray<ObjectType> *)other
                                                       withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options;
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromArray:(NSArray<ObjectType> *)other;
/* nil when the difference does not apply to this array */
- (nullable NSArray<ObjectType> *)arrayByApplyingDifference:(NSOrderedCollectionDifference<ObjectType> *)difference;
@end
@interface NSMutableArray<ObjectType> (NSMutableArrayDiffing)
- (void)applyDifference:(NSOrderedCollectionDifference<ObjectType> *)difference;
@end
@interface NSOrderedSet<ObjectType> (NSOrderedSetDiffing)
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromOrderedSet:(NSOrderedSet<ObjectType> *)other
                                                            withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
                                                   usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj1, ObjectType obj2))block;
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromOrderedSet:(NSOrderedSet<ObjectType> *)other
                                                            withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options;
- (NSOrderedCollectionDifference<ObjectType> *)differenceFromOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (nullable NSOrderedSet<ObjectType> *)orderedSetByApplyingDifference:(NSOrderedCollectionDifference<ObjectType> *)difference;
@end
@interface NSMutableOrderedSet<ObjectType> (NSMutableOrderedSetDiffing)
- (void)applyDifference:(NSOrderedCollectionDifference<ObjectType> *)difference;
@end

NS_ASSUME_NONNULL_END
