#pragma once
#import <Foundation/NSObject.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSIndexSet;
@interface NSEnumerator<ObjectType> : NSObject <NSFastEnumeration>
- (nullable ObjectType)nextObject;
@property (readonly, copy) NSArray<ObjectType> *allObjects;
@end
typedef NS_OPTIONS(NSUInteger, NSEnumerationOptions) { NSEnumerationConcurrent = (1UL << 0), NSEnumerationReverse = (1UL << 1) };

@interface NSArray<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSSecureCoding, NSFastEnumeration>
@property (readonly) NSUInteger count;
- (ObjectType)objectAtIndex:(NSUInteger)index;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObjects:(const ObjectType _Nonnull [_Nullable])objects count:(NSUInteger)cnt NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
+ (instancetype)array;
+ (instancetype)arrayWithObject:(ObjectType)anObject;
+ (instancetype)arrayWithObjects:(const ObjectType _Nonnull [_Nonnull])objects count:(NSUInteger)cnt;
+ (instancetype)arrayWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)arrayWithArray:(NSArray<ObjectType> *)array;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;
- (NSEnumerator<ObjectType> *)objectEnumerator;
- (NSEnumerator<ObjectType> *)reverseObjectEnumerator;
@property (nullable, nonatomic, readonly) ObjectType firstObject;
@property (nullable, nonatomic, readonly) ObjectType lastObject;
- (BOOL)containsObject:(ObjectType)anObject;
- (NSUInteger)indexOfObject:(ObjectType)anObject;
- (NSUInteger)indexOfObjectIdenticalTo:(ObjectType)anObject;
- (NSArray<ObjectType> *)arrayByAddingObject:(ObjectType)anObject;
- (NSArray<ObjectType> *)arrayByAddingObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (NSString *)componentsJoinedByString:(NSString *)separator;
- (NSArray<ObjectType> *)subarrayWithRange:(NSRange)range;
- (BOOL)isEqualToArray:(NSArray<ObjectType> *)otherArray;
- (NSArray<ObjectType> *)sortedArrayUsingSelector:(SEL)comparator;
- (NSArray<ObjectType> *)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (void)makeObjectsPerformSelector:(SEL)aSelector;
- (void)makeObjectsPerformSelector:(SEL)aSelector withObject:(nullable id)argument;
- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexOfObjectPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
@end

@interface NSMutableArray<ObjectType> : NSArray<ObjectType>
- (void)addObject:(ObjectType)anObject;
- (void)insertObject:(ObjectType)anObject atIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(ObjectType)anObject;
- (instancetype)initWithCapacity:(NSUInteger)numItems NS_DESIGNATED_INITIALIZER;
+ (instancetype)arrayWithCapacity:(NSUInteger)numItems;
- (void)addObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (void)removeAllObjects;
- (void)removeObject:(ObjectType)anObject;
- (void)removeObjectIdenticalTo:(ObjectType)anObject;
- (void)removeObjectsInArray:(NSArray<ObjectType> *)otherArray;
- (void)setObject:(ObjectType)obj atIndexedSubscript:(NSUInteger)idx;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)sortUsingSelector:(SEL)comparator;
- (void)sortUsingComparator:(NSComparator NS_NOESCAPE)cmptr;
@end
NS_ASSUME_NONNULL_END
