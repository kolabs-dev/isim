#pragma once
#import <Foundation/NSOrderedCollections.h>
/* isim Foundation (self-authored, Apple's declarations and values): NSMapTable's options and its C functions. Adapted: a
   table made with NSCreateMapTable keeps raw pointers with the callbacks it was made with; the functions work on any
   NSMapTable (an object table's keys and values are its objects). */
NS_ASSUME_NONNULL_BEGIN

static const NSPointerFunctionsOptions NSMapTableStrongMemory = NSPointerFunctionsStrongMemory;
static const NSPointerFunctionsOptions NSMapTableCopyIn = NSPointerFunctionsCopyIn;
static const NSPointerFunctionsOptions NSMapTableObjectPointerPersonality = NSPointerFunctionsObjectPointerPersonality;
static const NSPointerFunctionsOptions NSMapTableWeakMemory = NSPointerFunctionsWeakMemory;

typedef struct { NSUInteger _pi; NSUInteger _si; void *_Nullable _bs; } NSMapEnumerator;

typedef struct {
    NSUInteger (*_Nullable hash)(NSMapTable *table, const void *);
    BOOL (*_Nullable isEqual)(NSMapTable *table, const void *, const void *);
    void (*_Nullable retain)(NSMapTable *table, const void *);
    void (*_Nullable release)(NSMapTable *table, void *);
    NSString *_Nullable (*_Nullable describe)(NSMapTable *table, const void *);
    const void *_Nullable notAKeyMarker;
} NSMapTableKeyCallBacks;
#define NSNotAnIntMapKey ((const void *)NSIntegerMin)
#define NSNotAnIntegerMapKey ((const void *)NSIntegerMin)
#define NSNotAPointerMapKey ((const void *)UINTPTR_MAX)

typedef struct {
    void (*_Nullable retain)(NSMapTable *table, const void *);
    void (*_Nullable release)(NSMapTable *table, void *);
    NSString *_Nullable (*_Nullable describe)(NSMapTable *table, const void *);
} NSMapTableValueCallBacks;

FOUNDATION_EXPORT void NSFreeMapTable(NSMapTable *table);
FOUNDATION_EXPORT void NSResetMapTable(NSMapTable *table);
FOUNDATION_EXPORT BOOL NSCompareMapTables(NSMapTable *table1, NSMapTable *table2);
FOUNDATION_EXPORT NSMapTable *NSCopyMapTableWithZone(NSMapTable *table, NSZone *_Nullable zone);
FOUNDATION_EXPORT BOOL NSMapMember(NSMapTable *table, const void *key, void *_Nullable *_Nullable originalKey, void *_Nullable *_Nullable value);
FOUNDATION_EXPORT void *_Nullable NSMapGet(NSMapTable *table, const void *_Nullable key);
FOUNDATION_EXPORT void NSMapInsert(NSMapTable *table, const void *_Nullable key, const void *_Nullable value);
FOUNDATION_EXPORT void NSMapInsertKnownAbsent(NSMapTable *table, const void *_Nullable key, const void *_Nullable value);
FOUNDATION_EXPORT void *_Nullable NSMapInsertIfAbsent(NSMapTable *table, const void *_Nullable key, const void *_Nullable value);
FOUNDATION_EXPORT void NSMapRemove(NSMapTable *table, const void *_Nullable key);
FOUNDATION_EXPORT NSMapEnumerator NSEnumerateMapTable(NSMapTable *table);
FOUNDATION_EXPORT BOOL NSNextMapEnumeratorPair(NSMapEnumerator *enumerator, void *_Nullable *_Nullable key, void *_Nullable *_Nullable value);
FOUNDATION_EXPORT void NSEndMapTableEnumeration(NSMapEnumerator *enumerator);
FOUNDATION_EXPORT NSUInteger NSCountMapTable(NSMapTable *table);
FOUNDATION_EXPORT NSString *NSStringFromMapTable(NSMapTable *table);
FOUNDATION_EXPORT NSArray *NSAllMapTableKeys(NSMapTable *table);
FOUNDATION_EXPORT NSArray *NSAllMapTableValues(NSMapTable *table);
FOUNDATION_EXPORT NSMapTable *NSCreateMapTableWithZone(NSMapTableKeyCallBacks keyCallBacks, NSMapTableValueCallBacks valueCallBacks,
                                                       NSUInteger capacity, NSZone *_Nullable zone);
FOUNDATION_EXPORT NSMapTable *NSCreateMapTable(NSMapTableKeyCallBacks keyCallBacks, NSMapTableValueCallBacks valueCallBacks, NSUInteger capacity);

FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSIntegerMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableKeyCallBacks NSIntMapKeyCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSIntegerMapValueCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSObjectMapValueCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks;
FOUNDATION_EXPORT const NSMapTableValueCallBacks NSIntMapValueCallBacks;

NS_ASSUME_NONNULL_END
