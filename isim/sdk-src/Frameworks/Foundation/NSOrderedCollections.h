#pragma once
/* isim: NSOrderedSet, NSCountedSet, NSSortDescriptor, NSCache, NSHashTable, NSMapTable, NSPointerArray and the
 * extended NSArray/NSSet/NSDictionary API (Apple spreads these over NSOrderedSet.h, NSSortDescriptor.h, ...). */
#import <Foundation/NSObject.h>
#import <Foundation/NSArray.h>
#import <Foundation/NSSet.h>
#import <Foundation/NSDictionary.h>
#import <Foundation/NSIndexSet.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSEnumerator<ObjectType>;

typedef NS_OPTIONS(NSUInteger, NSSortOptions) { NSSortConcurrent = (1UL << 0), NSSortStable = (1UL << 4) };
typedef NS_OPTIONS(NSUInteger, NSBinarySearchingOptions) {
    NSBinarySearchingFirstEqual = (1UL << 8), NSBinarySearchingLastEqual = (1UL << 9), NSBinarySearchingInsertionIndex = (1UL << 10)
};

@interface NSSortDescriptor : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)sortDescriptorWithKey:(nullable NSString *)key ascending:(BOOL)ascending;
+ (instancetype)sortDescriptorWithKey:(nullable NSString *)key ascending:(BOOL)ascending selector:(nullable SEL)selector;
+ (instancetype)sortDescriptorWithKey:(nullable NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr;
- (instancetype)initWithKey:(nullable NSString *)key ascending:(BOOL)ascending;
- (instancetype)initWithKey:(nullable NSString *)key ascending:(BOOL)ascending selector:(nullable SEL)selector;
- (instancetype)initWithKey:(nullable NSString *)key ascending:(BOOL)ascending comparator:(NSComparator)cmptr;
@property (nullable, readonly, copy) NSString *key;
@property (readonly) BOOL ascending;
@property (nullable, readonly) SEL selector;
@property (readonly) NSComparator comparator;
- (NSComparisonResult)compareObject:(id)object1 toObject:(id)object2;
@property (readonly, retain) id reversedSortDescriptor;
@end

@interface NSArray<ObjectType> (NSExtendedArray)
- (NSArray<ObjectType> *)objectsAtIndexes:(NSIndexSet *)indexes;
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSUInteger)indexOfObject:(ObjectType)anObject inRange:(NSRange)range;
- (NSArray<ObjectType> *)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (NSArray<ObjectType> *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors;
- (NSArray<ObjectType> *)sortedArrayUsingFunction:(NSInteger (NS_NOESCAPE *)(ObjectType, ObjectType, void * _Nullable))comparator context:(nullable void *)context;
- (NSUInteger)indexOfObject:(ObjectType)obj inSortedRange:(NSRange)r options:(NSBinarySearchingOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmp;
- (nullable ObjectType)firstObjectCommonWithArray:(NSArray<ObjectType> *)otherArray;
@end
@interface NSMutableArray<ObjectType> (NSExtendedMutableArray)
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;
- (void)insertObjects:(NSArray<ObjectType> *)objects atIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectsAtIndexes:(NSIndexSet *)indexes withObjects:(NSArray<ObjectType> *)objects;
- (void)removeObjectsInRange:(NSRange)range;
- (void)replaceObjectsInRange:(NSRange)range withObjectsFromArray:(NSArray<ObjectType> *)otherArray;
- (void)setArray:(NSArray<ObjectType> *)otherArray;
- (void)sortUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (void)removeObject:(ObjectType)anObject inRange:(NSRange)range;
@end
@interface NSSet<ObjectType> (NSExtendedSet)
- (NSSet<ObjectType> *)setByAddingObject:(ObjectType)anObject;
- (NSSet<ObjectType> *)setByAddingObjectsFromSet:(NSSet<ObjectType> *)other;
- (NSSet<ObjectType> *)setByAddingObjectsFromArray:(NSArray<ObjectType> *)other;
- (BOOL)isSubsetOfSet:(NSSet<ObjectType> *)otherSet;
- (BOOL)intersectsSet:(NSSet<ObjectType> *)otherSet;
- (BOOL)isEqualToSet:(NSSet<ObjectType> *)otherSet;
- (NSSet<ObjectType> *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, BOOL *stop))predicate;
- (NSArray<ObjectType> *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors;
- (void)makeObjectsPerformSelector:(SEL)aSelector;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, BOOL *stop))block;
@end
@interface NSMutableSet<ObjectType> (NSExtendedMutableSet)
- (void)unionSet:(NSSet<ObjectType> *)otherSet;
- (void)minusSet:(NSSet<ObjectType> *)otherSet;
- (void)intersectSet:(NSSet<ObjectType> *)otherSet;
- (void)setSet:(NSSet<ObjectType> *)otherSet;
@end
@interface NSDictionary<KeyType, ObjectType> (NSExtendedDictionary)
+ (instancetype)dictionaryWithObjects:(NSArray<ObjectType> *)objects forKeys:(NSArray<KeyType <NSCopying>> *)keys;
- (NSArray<KeyType> *)keysSortedByValueUsingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (NSArray<KeyType> *)keysSortedByValueUsingSelector:(SEL)comparator;
- (NSSet<KeyType> *)keysOfEntriesPassingTest:(BOOL (NS_NOESCAPE ^)(KeyType key, ObjectType obj, BOOL *stop))predicate;
- (NSArray<ObjectType> *)objectsForKeys:(NSArray<KeyType> *)keys notFoundMarker:(ObjectType)marker;
- (NSArray<KeyType> *)allKeysForObject:(ObjectType)anObject;
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(KeyType key, ObjectType obj, BOOL *stop))block;
@end
@interface NSMutableDictionary<KeyType, ObjectType> (NSExtendedMutableDictionary)
- (void)removeObjectsForKeys:(NSArray<KeyType> *)keyArray;
- (void)setDictionary:(NSDictionary<KeyType, ObjectType> *)otherDictionary;
@end

@interface NSOrderedSet<__covariant ObjectType> : NSObject <NSCopying, NSMutableCopying, NSSecureCoding, NSFastEnumeration>
@property (readonly) NSUInteger count;
- (ObjectType)objectAtIndex:(NSUInteger)idx;
- (NSUInteger)indexOfObject:(ObjectType)object;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithObjects:(const ObjectType _Nonnull [_Nullable])objects count:(NSUInteger)cnt NS_DESIGNATED_INITIALIZER;
+ (instancetype)orderedSet;
+ (instancetype)orderedSetWithObject:(ObjectType)object;
+ (instancetype)orderedSetWithObjects:(const ObjectType _Nonnull [_Nonnull])objects count:(NSUInteger)cnt;
+ (instancetype)orderedSetWithObjects:(ObjectType)firstObj, ... NS_REQUIRES_NIL_TERMINATION;
+ (instancetype)orderedSetWithOrderedSet:(NSOrderedSet<ObjectType> *)set;
+ (instancetype)orderedSetWithArray:(NSArray<ObjectType> *)array;
+ (instancetype)orderedSetWithSet:(NSSet<ObjectType> *)set;
- (instancetype)initWithObject:(ObjectType)object;
- (instancetype)initWithOrderedSet:(NSOrderedSet<ObjectType> *)set;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
- (instancetype)initWithArray:(NSArray<ObjectType> *)set copyItems:(BOOL)flag;
- (instancetype)initWithSet:(NSSet<ObjectType> *)set;
- (ObjectType)objectAtIndexedSubscript:(NSUInteger)idx;
- (BOOL)containsObject:(ObjectType)object;
@property (nullable, nonatomic, readonly) ObjectType firstObject;
@property (nullable, nonatomic, readonly) ObjectType lastObject;
@property (readonly, strong) NSArray<ObjectType> *array;
@property (readonly, strong) NSSet<ObjectType> *set;
@property (readonly, copy) NSOrderedSet<ObjectType> *reversedOrderedSet;
- (NSArray<ObjectType> *)objectsAtIndexes:(NSIndexSet *)indexes;
- (NSEnumerator<ObjectType> *)objectEnumerator;
- (NSEnumerator<ObjectType> *)reverseObjectEnumerator;
- (BOOL)isEqualToOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (BOOL)intersectsOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (BOOL)intersectsSet:(NSSet<ObjectType> *)set;
- (BOOL)isSubsetOfOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (BOOL)isSubsetOfSet:(NSSet<ObjectType> *)set;
- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))block;
- (NSUInteger)indexOfObjectPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(ObjectType obj, NSUInteger idx, BOOL *stop))predicate;
- (NSArray<ObjectType> *)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (NSArray<ObjectType> *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors;
@end
@interface NSMutableOrderedSet<ObjectType> : NSOrderedSet<ObjectType>
- (void)insertObject:(ObjectType)object atIndex:(NSUInteger)idx;
- (void)removeObjectAtIndex:(NSUInteger)idx;
- (void)replaceObjectAtIndex:(NSUInteger)idx withObject:(ObjectType)object;
- (instancetype)initWithCapacity:(NSUInteger)numItems;
+ (instancetype)orderedSetWithCapacity:(NSUInteger)numItems;
- (void)addObject:(ObjectType)object;
- (void)addObjects:(const ObjectType _Nonnull [_Nullable])objects count:(NSUInteger)count;
- (void)addObjectsFromArray:(NSArray<ObjectType> *)array;
- (void)exchangeObjectAtIndex:(NSUInteger)idx1 withObjectAtIndex:(NSUInteger)idx2;
- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)idx;
- (void)insertObjects:(NSArray<ObjectType> *)objects atIndexes:(NSIndexSet *)indexes;
- (void)setObject:(ObjectType)obj atIndex:(NSUInteger)idx;
- (void)setObject:(ObjectType)obj atIndexedSubscript:(NSUInteger)idx;
- (void)removeObjectsInRange:(NSRange)range;
- (void)removeObjectsAtIndexes:(NSIndexSet *)indexes;
- (void)removeAllObjects;
- (void)removeObject:(ObjectType)object;
- (void)removeObjectsInArray:(NSArray<ObjectType> *)array;
- (void)intersectOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (void)minusOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (void)unionOrderedSet:(NSOrderedSet<ObjectType> *)other;
- (void)intersectSet:(NSSet<ObjectType> *)other;
- (void)minusSet:(NSSet<ObjectType> *)other;
- (void)unionSet:(NSSet<ObjectType> *)other;
- (void)sortUsingComparator:(NSComparator NS_NOESCAPE)cmptr;
- (void)sortUsingDescriptors:(NSArray<NSSortDescriptor *> *)sortDescriptors;
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr;
@end

@interface NSCountedSet<ObjectType> : NSMutableSet<ObjectType>
- (instancetype)initWithCapacity:(NSUInteger)numItems;
- (instancetype)initWithArray:(NSArray<ObjectType> *)array;
- (instancetype)initWithSet:(NSSet<ObjectType> *)set;
- (NSUInteger)countForObject:(ObjectType)object;
@end

@class NSCache;
@protocol NSCacheDelegate <NSObject>
@optional
- (void)cache:(NSCache *)cache willEvictObject:(id)obj;
@end
@interface NSCache<KeyType, ObjectType> : NSObject
@property (copy) NSString *name;
@property (nullable, assign) id<NSCacheDelegate> delegate;
- (nullable ObjectType)objectForKey:(KeyType)key;
- (void)setObject:(ObjectType)obj forKey:(KeyType)key;
- (void)setObject:(ObjectType)obj forKey:(KeyType)key cost:(NSUInteger)g;
- (void)removeObjectForKey:(KeyType)key;
- (void)removeAllObjects;
@property NSUInteger totalCostLimit;
@property NSUInteger countLimit;
@property BOOL evictsObjectsWithDiscardedContent;
@end

typedef NS_OPTIONS(NSUInteger, NSPointerFunctionsOptions) {
    NSPointerFunctionsStrongMemory NS_SWIFT_NAME(strongMemory) = (0UL << 0), NSPointerFunctionsOpaqueMemory NS_SWIFT_NAME(opaqueMemory) = (2UL << 0),
    NSPointerFunctionsMallocMemory NS_SWIFT_NAME(mallocMemory) = (3UL << 0), NSPointerFunctionsMachVirtualMemory NS_SWIFT_NAME(machVirtualMemory) = (4UL << 0),
    NSPointerFunctionsWeakMemory NS_SWIFT_NAME(weakMemory) = (5UL << 0), NSPointerFunctionsObjectPersonality NS_SWIFT_NAME(objectPersonality) = (0UL << 8),
    NSPointerFunctionsOpaquePersonality NS_SWIFT_NAME(opaquePersonality) = (1UL << 8), NSPointerFunctionsObjectPointerPersonality NS_SWIFT_NAME(objectPointerPersonality) = (2UL << 8),
    NSPointerFunctionsCStringPersonality NS_SWIFT_NAME(cStringPersonality) = (3UL << 8), NSPointerFunctionsStructPersonality NS_SWIFT_NAME(structPersonality) = (4UL << 8),
    NSPointerFunctionsIntegerPersonality NS_SWIFT_NAME(integerPersonality) = (5UL << 8), NSPointerFunctionsCopyIn NS_SWIFT_NAME(copyIn) = (1UL << 16)
} NS_SWIFT_NAME(NSPointerFunctions.Options);
@interface NSPointerFunctions : NSObject
@end
typedef NSPointerFunctionsOptions NSHashTableOptions;
typedef NSPointerFunctionsOptions NSMapTableOptions;
@interface NSHashTable<ObjectType> : NSObject <NSCopying, NSFastEnumeration>
- (instancetype)initWithOptions:(NSPointerFunctionsOptions)options capacity:(NSUInteger)initialCapacity NS_DESIGNATED_INITIALIZER;
+ (NSHashTable<ObjectType> *)hashTableWithOptions:(NSPointerFunctionsOptions)options;
+ (NSHashTable<ObjectType> *)weakObjectsHashTable;
@property (readonly) NSUInteger count;
- (nullable ObjectType)member:(nullable ObjectType)object;
- (NSEnumerator<ObjectType> *)objectEnumerator;
- (void)addObject:(nullable ObjectType)object;
- (void)removeObject:(nullable ObjectType)object;
- (void)removeAllObjects;
@property (readonly, copy) NSArray<ObjectType> *allObjects;
@property (nullable, nonatomic, readonly) ObjectType anyObject;
- (BOOL)containsObject:(nullable ObjectType)anObject;
- (void)intersectHashTable:(NSHashTable<ObjectType> *)other;
- (void)unionHashTable:(NSHashTable<ObjectType> *)other;
- (void)minusHashTable:(NSHashTable<ObjectType> *)other;
@property (readonly, copy) NSSet<ObjectType> *setRepresentation;
@end
@interface NSMapTable<KeyType, ObjectType> : NSObject <NSCopying, NSFastEnumeration>
- (instancetype)initWithKeyOptions:(NSPointerFunctionsOptions)keyOptions valueOptions:(NSPointerFunctionsOptions)valueOptions capacity:(NSUInteger)initialCapacity NS_DESIGNATED_INITIALIZER;
+ (NSMapTable<KeyType, ObjectType> *)mapTableWithKeyOptions:(NSPointerFunctionsOptions)keyOptions valueOptions:(NSPointerFunctionsOptions)valueOptions;
+ (NSMapTable<KeyType, ObjectType> *)strongToStrongObjectsMapTable;
+ (NSMapTable<KeyType, ObjectType> *)weakToStrongObjectsMapTable;
+ (NSMapTable<KeyType, ObjectType> *)strongToWeakObjectsMapTable;
+ (NSMapTable<KeyType, ObjectType> *)weakToWeakObjectsMapTable;
- (nullable ObjectType)objectForKey:(nullable KeyType)aKey;
- (void)removeObjectForKey:(nullable KeyType)aKey;
- (void)setObject:(nullable ObjectType)anObject forKey:(nullable KeyType)aKey;
@property (readonly) NSUInteger count;
- (NSEnumerator<KeyType> *)keyEnumerator;
- (nullable NSEnumerator<ObjectType> *)objectEnumerator;
- (void)removeAllObjects;
- (NSDictionary<KeyType, ObjectType> *)dictionaryRepresentation;
@end
@interface NSPointerArray : NSObject <NSFastEnumeration, NSCopying>
- (instancetype)initWithOptions:(NSPointerFunctionsOptions)options NS_DESIGNATED_INITIALIZER;
+ (NSPointerArray *)pointerArrayWithOptions:(NSPointerFunctionsOptions)options;
+ (NSPointerArray *)strongObjectsPointerArray;
+ (NSPointerArray *)weakObjectsPointerArray;
- (nullable void *)pointerAtIndex:(NSUInteger)index;
- (void)addPointer:(nullable void *)pointer;
- (void)removePointerAtIndex:(NSUInteger)index;
- (void)insertPointer:(nullable void *)item atIndex:(NSUInteger)index;
- (void)replacePointerAtIndex:(NSUInteger)index withPointer:(nullable void *)item;
- (void)compact;
@property NSUInteger count;
@property (readonly, copy) NSArray *allObjects;
@end
NS_ASSUME_NONNULL_END
