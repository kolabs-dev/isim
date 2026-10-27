#pragma once
#import <Foundation/NSOrderedCollections.h>
/* isim Foundation (self-authored, Apple's declarations and values): NSHashTable's options and its C functions. Adapted: a
   table made with NSCreateHashTable keeps raw pointers with the callbacks it was made with; the functions work on any
   NSHashTable (an object table's items are its objects). */
NS_ASSUME_NONNULL_BEGIN

static const NSPointerFunctionsOptions NSHashTableStrongMemory = NSPointerFunctionsStrongMemory;
static const NSPointerFunctionsOptions NSHashTableCopyIn = NSPointerFunctionsCopyIn;
static const NSPointerFunctionsOptions NSHashTableObjectPointerPersonality = NSPointerFunctionsObjectPointerPersonality;
static const NSPointerFunctionsOptions NSHashTableWeakMemory = NSPointerFunctionsWeakMemory;

typedef struct { NSUInteger _pi; NSUInteger _si; void *_Nullable _bs; } NSHashEnumerator;

typedef struct {
    NSUInteger (*_Nullable hash)(NSHashTable *table, const void *);
    BOOL (*_Nullable isEqual)(NSHashTable *table, const void *, const void *);
    void (*_Nullable retain)(NSHashTable *table, const void *);
    void (*_Nullable release)(NSHashTable *table, void *);
    NSString *_Nullable (*_Nullable describe)(NSHashTable *table, const void *);
} NSHashTableCallBacks;

FOUNDATION_EXPORT void NSFreeHashTable(NSHashTable *table);
FOUNDATION_EXPORT void NSResetHashTable(NSHashTable *table);
FOUNDATION_EXPORT BOOL NSCompareHashTables(NSHashTable *table1, NSHashTable *table2);
FOUNDATION_EXPORT NSHashTable *NSCopyHashTableWithZone(NSHashTable *table, NSZone *_Nullable zone);
FOUNDATION_EXPORT void *NSHashGet(NSHashTable *table, const void *_Nullable pointer);
FOUNDATION_EXPORT void NSHashInsert(NSHashTable *table, const void *_Nullable pointer);
FOUNDATION_EXPORT void NSHashInsertKnownAbsent(NSHashTable *table, const void *_Nullable pointer);
FOUNDATION_EXPORT void *_Nullable NSHashInsertIfAbsent(NSHashTable *table, const void *_Nullable pointer);
FOUNDATION_EXPORT void NSHashRemove(NSHashTable *table, const void *_Nullable pointer);
FOUNDATION_EXPORT NSHashEnumerator NSEnumerateHashTable(NSHashTable *table);
FOUNDATION_EXPORT void *_Nullable NSNextHashEnumeratorItem(NSHashEnumerator *enumerator);
FOUNDATION_EXPORT void NSEndHashTableEnumeration(NSHashEnumerator *enumerator);
FOUNDATION_EXPORT NSUInteger NSCountHashTable(NSHashTable *table);
FOUNDATION_EXPORT NSString *NSStringFromHashTable(NSHashTable *table);
FOUNDATION_EXPORT NSArray *NSAllHashTableObjects(NSHashTable *table);
FOUNDATION_EXPORT NSHashTable *NSCreateHashTableWithZone(NSHashTableCallBacks callBacks, NSUInteger capacity, NSZone *_Nullable zone);
FOUNDATION_EXPORT NSHashTable *NSCreateHashTable(NSHashTableCallBacks callBacks, NSUInteger capacity);

FOUNDATION_EXPORT const NSHashTableCallBacks NSIntegerHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSObjectHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSOwnedPointerHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSPointerToStructHashCallBacks;
FOUNDATION_EXPORT const NSHashTableCallBacks NSIntHashCallBacks;

NS_ASSUME_NONNULL_END
