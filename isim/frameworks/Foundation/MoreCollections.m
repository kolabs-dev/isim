/* isim Foundation (ARC): NSIndexSet, NSOrderedSet, NSCountedSet, NSCache, NSHashTable, NSMapTable,
 * NSPointerArray, NSSortDescriptor, and the NSArray/NSSet/NSDictionary API built on them. */
#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <pthread.h>
#include <stdlib.h>
#include <string.h>
#include "isim_foundation.h"

/* ================= NSIndexSet ================= */
static BOOL NSEqualRanges_isim(NSRange a, NSRange b) { return a.location == b.location && a.length == b.length; }
@interface NSIndexSet () {
    @public NSRange *_r; NSUInteger _n, _cap, _count;
}
@end
@implementation NSIndexSet
+ (instancetype)indexSet { return [self new]; }
+ (instancetype)indexSetWithIndex:(NSUInteger)i { return [[self alloc] initWithIndex:i]; }
+ (instancetype)indexSetWithIndexesInRange:(NSRange)r { return [[self alloc] initWithIndexesInRange:r]; }
- (instancetype)init { return [self initWithIndexesInRange:NSMakeRange(0, 0)]; }
- (instancetype)initWithIndex:(NSUInteger)i { return [self initWithIndexesInRange:NSMakeRange(i, 1)]; }
- (instancetype)initWithIndexesInRange:(NSRange)r {
    if ((self = [super init])) { _cap = 4; _r = calloc(_cap, sizeof(NSRange)); if (r.length) { _r[0] = r; _n = 1; _count = r.length; } }
    return self;
}
- (instancetype)initWithIndexSet:(NSIndexSet *)s {
    if ((self = [self init])) { [self _addRangesOf:s]; }
    return self;
}
- (void)dealloc { free(_r); }
- (void)_addRangesOf:(NSIndexSet *)s { for (NSUInteger i = 0; i < s->_n; i++) [self _add:s->_r[i]]; }
/* insert a range keeping ranges sorted, disjoint and coalesced */
- (void)_add:(NSRange)r {
    if (!r.length) return;
    NSUInteger lo = r.location, hi = NSMaxRange(r);
    NSUInteger i = 0;
    while (i < _n && NSMaxRange(_r[i]) < lo) i++;
    NSUInteger j = i;
    while (j < _n && _r[j].location <= hi) { lo = MIN(lo, _r[j].location); hi = MAX(hi, NSMaxRange(_r[j])); j++; }
    NSUInteger removed = j - i;
    if (removed == 0) {
        if (_n + 1 > _cap) { _cap *= 2; _r = realloc(_r, _cap * sizeof(NSRange)); }
        memmove(_r + i + 1, _r + i, (_n - i) * sizeof(NSRange)); _n++;
    } else if (removed > 1) {
        memmove(_r + i + 1, _r + j, (_n - j) * sizeof(NSRange)); _n -= removed - 1;
    }
    _r[i] = NSMakeRange(lo, hi - lo);
    [self _recount];
}
- (void)_remove:(NSRange)r {
    if (!r.length) return;
    NSUInteger lo = r.location, hi = NSMaxRange(r);
    NSRange *out = calloc(_n * 2 + 1, sizeof(NSRange)); NSUInteger k = 0;
    for (NSUInteger i = 0; i < _n; i++) {
        NSRange a = _r[i]; NSUInteger a0 = a.location, a1 = NSMaxRange(a);
        if (a1 <= lo || a0 >= hi) { out[k++] = a; continue; }
        if (a0 < lo) out[k++] = NSMakeRange(a0, lo - a0);
        if (a1 > hi) out[k++] = NSMakeRange(hi, a1 - hi);
    }
    free(_r); _r = out; _n = k; _cap = MAX(k, (NSUInteger)4); _r = realloc(_r, _cap * sizeof(NSRange));
    [self _recount];
}
- (void)_recount { _count = 0; for (NSUInteger i = 0; i < _n; i++) _count += _r[i].length; }
- (id)copyWithZone:(NSZone *)z { return [[NSIndexSet alloc] initWithIndexSet:self]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableIndexSet alloc] initWithIndexSet:self]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (NSUInteger)count { return _count; }
- (NSUInteger)_rangeCount { return _n; }
- (NSRange)_rangeAtIndex:(NSUInteger)i { return _r[i]; }
- (NSUInteger)firstIndex { return _n ? _r[0].location : NSNotFound; }
- (NSUInteger)lastIndex { return _n ? NSMaxRange(_r[_n - 1]) - 1 : NSNotFound; }
- (BOOL)containsIndex:(NSUInteger)v { for (NSUInteger i = 0; i < _n; i++) if (NSLocationInRange(v, _r[i])) return YES; return NO; }
- (BOOL)containsIndexesInRange:(NSRange)r {
    if (!r.length) return NO;
    for (NSUInteger i = 0; i < _n; i++) if (r.location >= _r[i].location && NSMaxRange(r) <= NSMaxRange(_r[i])) return YES;
    return NO;
}
- (BOOL)containsIndexes:(NSIndexSet *)s { for (NSUInteger i = 0; i < s->_n; i++) if (![self containsIndexesInRange:s->_r[i]]) return NO; return YES; }
- (BOOL)intersectsIndexesInRange:(NSRange)r {
    for (NSUInteger i = 0; i < _n; i++) if (_r[i].location < NSMaxRange(r) && r.location < NSMaxRange(_r[i])) return YES;
    return NO;
}
- (NSUInteger)countOfIndexesInRange:(NSRange)r {
    NSUInteger c = 0;
    for (NSUInteger i = 0; i < _n; i++) {
        NSUInteger lo = MAX(_r[i].location, r.location), hi = MIN(NSMaxRange(_r[i]), NSMaxRange(r));
        if (hi > lo) c += hi - lo;
    }
    return c;
}
- (NSUInteger)indexGreaterThanIndex:(NSUInteger)v { return v == NSNotFound ? NSNotFound : [self indexGreaterThanOrEqualToIndex:v + 1]; }
- (NSUInteger)indexGreaterThanOrEqualToIndex:(NSUInteger)v {
    for (NSUInteger i = 0; i < _n; i++) { if (NSLocationInRange(v, _r[i])) return v; if (_r[i].location > v) return _r[i].location; }
    return NSNotFound;
}
- (NSUInteger)indexLessThanIndex:(NSUInteger)v { return v == 0 ? NSNotFound : [self indexLessThanOrEqualToIndex:v - 1]; }
- (NSUInteger)indexLessThanOrEqualToIndex:(NSUInteger)v {
    for (NSUInteger i = _n; i-- > 0;) { if (NSLocationInRange(v, _r[i])) return v; if (NSMaxRange(_r[i]) - 1 < v) return NSMaxRange(_r[i]) - 1; }
    return NSNotFound;
}
- (NSUInteger)getIndexes:(NSUInteger *)buf maxCount:(NSUInteger)max inIndexRange:(NSRangePointer)range {
    NSUInteger k = 0, lo = range ? range->location : 0, hi = range ? NSMaxRange(*range) : NSUIntegerMax;
    NSUInteger last = lo;
    for (NSUInteger i = 0; i < _n && k < max; i++)
        for (NSUInteger v = MAX(_r[i].location, lo); v < NSMaxRange(_r[i]) && v < hi && k < max; v++) { buf[k++] = v; last = v + 1; }
    if (range) { NSUInteger end = NSMaxRange(*range); range->location = k ? last : end; range->length = end > range->location ? end - range->location : 0; }
    return k;
}
- (BOOL)isEqualToIndexSet:(NSIndexSet *)o {
    if (o->_n != _n) return NO;
    for (NSUInteger i = 0; i < _n; i++) if (!NSEqualRanges_isim(_r[i], o->_r[i])) return NO;
    return YES;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSIndexSet class]] && [self isEqualToIndexSet:o]; }
- (NSUInteger)hash { return _count ^ (_n ? _r[0].location : 0); }
- (void)enumerateIndexesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block {
    BOOL stop = NO;
    if (opts & NSEnumerationReverse) {
        for (NSUInteger i = _n; i-- > 0 && !stop;) for (NSUInteger v = NSMaxRange(_r[i]); v-- > _r[i].location && !stop;) block(v, &stop);
    } else {
        for (NSUInteger i = 0; i < _n && !stop; i++) for (NSUInteger v = _r[i].location; v < NSMaxRange(_r[i]) && !stop; v++) block(v, &stop);
    }
}
- (void)enumerateIndexesUsingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block { [self enumerateIndexesWithOptions:0 usingBlock:block]; }
- (void)enumerateIndexesInRange:(NSRange)range options:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))block {
    [self enumerateIndexesWithOptions:opts usingBlock:^(NSUInteger idx, BOOL *stop) { if (NSLocationInRange(idx, range)) block(idx, stop); }];
}
- (void)enumerateRangesWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))block {
    BOOL stop = NO;
    if (opts & NSEnumerationReverse) { for (NSUInteger i = _n; i-- > 0 && !stop;) block(_r[i], &stop); }
    else for (NSUInteger i = 0; i < _n && !stop; i++) block(_r[i], &stop);
}
- (void)enumerateRangesUsingBlock:(void (NS_NOESCAPE ^)(NSRange range, BOOL *stop))block { [self enumerateRangesWithOptions:0 usingBlock:block]; }
- (NSUInteger)indexPassingTest:(BOOL (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))predicate {
    __block NSUInteger found = NSNotFound;
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) { if (predicate(idx, stop)) { found = idx; *stop = YES; } }];
    return found;
}
- (NSIndexSet *)indexesPassingTest:(BOOL (NS_NOESCAPE ^)(NSUInteger idx, BOOL *stop))predicate {
    NSMutableIndexSet *out = [NSMutableIndexSet indexSet];
    [self enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) { if (predicate(idx, stop)) [out addIndex:idx]; }];
    return out;
}
- (NSString *)description {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSUInteger i = 0; i < _n; i++) [parts addObject:_r[i].length == 1 ? [NSString stringWithFormat:@"%lu", (unsigned long)_r[i].location] : [NSString stringWithFormat:@"%lu-%lu", (unsigned long)_r[i].location, (unsigned long)NSMaxRange(_r[i]) - 1]];
    return [NSString stringWithFormat:@"<%@: %p>[number of indexes: %lu (in %lu ranges), indexes: (%@)]", [self class], self, (unsigned long)_count, (unsigned long)_n, [parts componentsJoinedByString:@" "]];
}
@end
@implementation NSMutableIndexSet
- (id)copyWithZone:(NSZone *)z { return [[NSIndexSet alloc] initWithIndexSet:self]; }
- (void)addIndex:(NSUInteger)v { [self _add:NSMakeRange(v, 1)]; }
- (void)addIndexesInRange:(NSRange)r { [self _add:r]; }
- (void)addIndexes:(NSIndexSet *)s { [self _addRangesOf:s]; }
- (void)removeIndex:(NSUInteger)v { [self _remove:NSMakeRange(v, 1)]; }
- (void)removeIndexesInRange:(NSRange)r { [self _remove:r]; }
- (void)removeIndexes:(NSIndexSet *)s { NSIndexSet *c = [s copy]; for (NSUInteger i = 0; i < c->_n; i++) [self _remove:c->_r[i]]; }
- (void)removeAllIndexes { _n = 0; _count = 0; }
- (void)shiftIndexesStartingAtIndex:(NSUInteger)index by:(NSInteger)delta {
    NSMutableIndexSet *keep = [NSMutableIndexSet indexSet];
    [self enumerateIndexesUsingBlock:^(NSUInteger v, BOOL *stop) {
        if (v < index) [keep addIndex:v];
        else if (delta >= 0 || v >= index + (NSUInteger)(-delta)) [keep addIndex:(NSUInteger)((NSInteger)v + delta)];
    }];
    [self removeAllIndexes]; [self _addRangesOf:keep];
}
@end

/* ================= NSArray / NSMutableArray additions ================= */
@implementation NSArray (IsimExtended)
- (NSArray *)objectsAtIndexes:(NSIndexSet *)indexes {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:indexes.count];
    [indexes enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [out addObject:[self objectAtIndex:i]]; }];
    return out;
}
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))predicate {
    NSMutableIndexSet *out = [NSMutableIndexSet indexSet];
    [self enumerateObjectsUsingBlock:^(id o, NSUInteger i, BOOL *stop) { if (predicate(o, i, stop)) [out addIndex:i]; }];
    return out;
}
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))block {
    if (!(opts & NSEnumerationReverse)) { [self enumerateObjectsUsingBlock:block]; return; }
    BOOL stop = NO;
    for (NSUInteger i = self.count; i-- > 0 && !stop;) block(self[i], i, &stop);
}
- (void)enumerateObjectsAtIndexes:(NSIndexSet *)s options:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))block {
    [s enumerateIndexesWithOptions:opts usingBlock:^(NSUInteger i, BOOL *stop) { block(self[i], i, stop); }];
}
- (NSUInteger)indexOfObjectWithOptions:(NSEnumerationOptions)opts passingTest:(BOOL (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))predicate {
    __block NSUInteger found = NSNotFound;
    [self enumerateObjectsWithOptions:opts usingBlock:^(id o, NSUInteger i, BOOL *stop) { if (predicate(o, i, stop)) { found = i; *stop = YES; } }];
    return found;
}
- (NSUInteger)indexOfObject:(id)o inRange:(NSRange)r {
    for (NSUInteger i = r.location; i < NSMaxRange(r); i++) if ([self[i] isEqual:o]) return i;
    return NSNotFound;
}
- (NSArray *)sortedArrayWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr { return [self sortedArrayUsingComparator:cmptr]; }
- (NSArray *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)descriptors {
    return [self sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        for (NSSortDescriptor *d in descriptors) { NSComparisonResult r = [d compareObject:a toObject:b]; if (r != NSOrderedSame) return r; }
        return NSOrderedSame;
    }];
}
- (NSArray *)sortedArrayUsingFunction:(NSInteger (*)(id, id, void *))comparator context:(void *)context {
    return [self sortedArrayUsingComparator:^NSComparisonResult(id a, id b) { return (NSComparisonResult)comparator(a, b, context); }];
}
- (NSUInteger)indexOfObject:(id)obj inSortedRange:(NSRange)r options:(NSBinarySearchingOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmp {
    NSUInteger lo = r.location, hi = NSMaxRange(r);
    while (lo < hi) {
        NSUInteger mid = lo + (hi - lo) / 2;
        NSComparisonResult c = cmp(self[mid], obj);
        if (c == NSOrderedAscending || (c == NSOrderedSame && (opts & NSBinarySearchingLastEqual))) lo = mid + 1; else hi = mid;
    }
    if (opts & NSBinarySearchingInsertionIndex) return lo;
    if (opts & NSBinarySearchingLastEqual) return lo > r.location && cmp(self[lo - 1], obj) == NSOrderedSame ? lo - 1 : NSNotFound;
    return lo < NSMaxRange(r) && cmp(self[lo], obj) == NSOrderedSame ? lo : NSNotFound;
}
- (id)firstObjectCommonWithArray:(NSArray *)other { for (id o in self) if ([other containsObject:o]) return o; return nil; }
- (NSArray *)arrayByAddingObjectsFromSet_isim:(NSSet *)s { return [self arrayByAddingObjectsFromArray:s.allObjects]; }
@end
@implementation NSMutableArray (IsimExtended)
- (void)removeObjectsAtIndexes:(NSIndexSet *)s { [s enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger i, BOOL *stop) { [self removeObjectAtIndex:i]; }]; }
- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)s {
    __block NSUInteger k = 0;
    [s enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [self insertObject:objects[k++] atIndex:i]; }];
}
- (void)replaceObjectsAtIndexes:(NSIndexSet *)s withObjects:(NSArray *)objects {
    __block NSUInteger k = 0;
    [s enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [self replaceObjectAtIndex:i withObject:objects[k++]]; }];
}
- (void)removeObjectsInRange:(NSRange)r { for (NSUInteger i = NSMaxRange(r); i-- > r.location;) [self removeObjectAtIndex:i]; }
- (void)replaceObjectsInRange:(NSRange)r withObjectsFromArray:(NSArray *)a {
    [self removeObjectsInRange:r];
    for (NSUInteger i = 0; i < a.count; i++) [self insertObject:a[i] atIndex:r.location + i];
}
- (void)setArray:(NSArray *)a { [self removeAllObjects]; [self addObjectsFromArray:a]; }
- (void)sortUsingDescriptors:(NSArray<NSSortDescriptor *> *)descriptors { [self setArray:[self sortedArrayUsingDescriptors:descriptors]]; }
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr { [self sortUsingComparator:cmptr]; }
- (void)removeObject:(id)o inRange:(NSRange)r { for (NSUInteger i = NSMaxRange(r); i-- > r.location;) if ([self[i] isEqual:o]) [self removeObjectAtIndex:i]; }
@end

/* ================= NSSet / NSDictionary additions ================= */
@implementation NSSet (IsimExtended)
- (NSSet *)setByAddingObject:(id)o { NSMutableSet *s = [self mutableCopy]; [s addObject:o]; return s; }
- (NSSet *)setByAddingObjectsFromSet:(NSSet *)o { NSMutableSet *s = [self mutableCopy]; [s unionSet:o]; return s; }
- (NSSet *)setByAddingObjectsFromArray:(NSArray *)a { NSMutableSet *s = [self mutableCopy]; [s addObjectsFromArray:a]; return s; }
- (BOOL)isSubsetOfSet:(NSSet *)o { for (id x in self) if (![o containsObject:x]) return NO; return YES; }
- (BOOL)intersectsSet:(NSSet *)o { for (id x in self) if ([o containsObject:x]) return YES; return NO; }
- (BOOL)isEqualToSet:(NSSet *)o { return self.count == o.count && [self isSubsetOfSet:o]; }
- (NSSet *)objectsPassingTest:(BOOL (NS_NOESCAPE ^)(id obj, BOOL *stop))predicate {
    NSMutableSet *out = [NSMutableSet set];
    [self enumerateObjectsUsingBlock:^(id o, BOOL *stop) { if (predicate(o, stop)) [out addObject:o]; }];
    return out;
}
- (NSArray *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)d { return [self.allObjects sortedArrayUsingDescriptors:d]; }
- (void)makeObjectsPerformSelector:(SEL)sel { [self.allObjects makeObjectsPerformSelector:sel]; }
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id obj, BOOL *stop))block { [self enumerateObjectsUsingBlock:block]; }
@end
@implementation NSMutableSet (IsimExtended)
- (void)unionSet:(NSSet *)o { for (id x in o) [self addObject:x]; }
- (void)minusSet:(NSSet *)o { for (id x in o) [self removeObject:x]; }
- (void)intersectSet:(NSSet *)o { for (id x in self.allObjects) if (![o containsObject:x]) [self removeObject:x]; }
- (void)setSet:(NSSet *)o { [self removeAllObjects]; [self unionSet:o]; }
@end
@implementation NSDictionary (IsimExtended)
+ (instancetype)dictionaryWithObjects:(NSArray *)objects forKeys:(NSArray *)keys {
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:keys.count];
    for (NSUInteger i = 0; i < keys.count; i++) d[keys[i]] = objects[i];
    return [[self alloc] initWithDictionary:d];
}
- (NSArray *)keysSortedByValueUsingComparator:(NSComparator NS_NOESCAPE)cmptr {
    return [self.allKeys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) { return cmptr(self[a], self[b]); }];
}
- (NSArray *)keysSortedByValueUsingSelector:(SEL)sel {
    return [self.allKeys sortedArrayUsingComparator:^NSComparisonResult(id a, id b) { return ((NSComparisonResult (*)(id, SEL, id))[self[a] methodForSelector:sel])(self[a], sel, self[b]); }];
}
- (NSSet *)keysOfEntriesPassingTest:(BOOL (NS_NOESCAPE ^)(id key, id obj, BOOL *stop))predicate {
    NSMutableSet *out = [NSMutableSet set];
    [self enumerateKeysAndObjectsUsingBlock:^(id k, id v, BOOL *stop) { if (predicate(k, v, stop)) [out addObject:k]; }];
    return out;
}
- (NSArray *)objectsForKeys:(NSArray *)keys notFoundMarker:(id)marker {
    NSMutableArray *out = [NSMutableArray array]; for (id k in keys) [out addObject:self[k] ?: marker]; return out;
}
- (NSArray *)allKeysForObject:(id)o { NSMutableArray *out = [NSMutableArray array]; for (id k in self) if ([self[k] isEqual:o]) [out addObject:k]; return out; }
- (void)enumerateKeysAndObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id key, id obj, BOOL *stop))block { [self enumerateKeysAndObjectsUsingBlock:block]; }
@end
@implementation NSMutableDictionary (IsimExtended)
- (void)removeObjectsForKeys:(NSArray *)keys { for (id k in keys) [self removeObjectForKey:k]; }
- (void)setDictionary:(NSDictionary *)d { [self removeAllObjects]; [self addEntriesFromDictionary:d]; }
@end

/* ================= NSOrderedSet ================= */
@interface NSOrderedSet () { @public NSMutableArray *_a; NSMutableSet *_s; }
@end
@implementation NSOrderedSet
+ (instancetype)orderedSet { return [self new]; }
+ (instancetype)orderedSetWithObject:(id)o { return [[self alloc] initWithArray:@[o]]; }
+ (instancetype)orderedSetWithObjects:(const id *)objs count:(NSUInteger)n { return [[self alloc] initWithObjects:objs count:n]; }
+ (instancetype)orderedSetWithObjects:(id)first, ... {
    NSMutableArray *a = [NSMutableArray array];
    va_list ap; va_start(ap, first); for (id o = first; o; o = va_arg(ap, id)) [a addObject:o]; va_end(ap);
    return [[self alloc] initWithArray:a];
}
+ (instancetype)orderedSetWithArray:(NSArray *)a { return [[self alloc] initWithArray:a]; }
+ (instancetype)orderedSetWithSet:(NSSet *)s { return [[self alloc] initWithSet:s]; }
+ (instancetype)orderedSetWithOrderedSet:(NSOrderedSet *)s { return [[self alloc] initWithOrderedSet:s]; }
- (instancetype)init { if ((self = [super init])) { _a = [NSMutableArray array]; _s = [NSMutableSet set]; } return self; }
- (instancetype)initWithObjects:(const id *)objs count:(NSUInteger)n { if ((self = [self init])) for (NSUInteger i = 0; i < n; i++) [self _append:objs[i]]; return self; }
- (instancetype)initWithArray:(NSArray *)a { if ((self = [self init])) for (id o in a) [self _append:o]; return self; }
- (instancetype)initWithArray:(NSArray *)a copyItems:(BOOL)copy { if ((self = [self init])) for (id o in a) [self _append:copy ? [o copy] : o]; return self; }
- (instancetype)initWithSet:(NSSet *)s { return [self initWithArray:s.allObjects]; }
- (instancetype)initWithOrderedSet:(NSOrderedSet *)s { return [self initWithArray:s.array]; }
- (instancetype)initWithObject:(id)o { return [self initWithArray:@[o]]; }
- (void)_append:(id)o { if (o && ![_s containsObject:o]) { [_s addObject:o]; [_a addObject:o]; } }
- (id)copyWithZone:(NSZone *)z { return [[NSOrderedSet alloc] initWithArray:_a]; }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableOrderedSet alloc] initWithArray:_a]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (NSUInteger)count { return _a.count; }
- (id)objectAtIndex:(NSUInteger)i { return _a[i]; }
- (id)objectAtIndexedSubscript:(NSUInteger)i { return _a[i]; }
- (NSUInteger)indexOfObject:(id)o { return [_s containsObject:o] ? [_a indexOfObject:o] : NSNotFound; }
- (BOOL)containsObject:(id)o { return [_s containsObject:o]; }
- (id)firstObject { return _a.firstObject; }
- (id)lastObject { return _a.lastObject; }
- (NSArray *)array { return [_a copy]; }
- (NSSet *)set { return [_s copy]; }
- (NSArray *)objectsAtIndexes:(NSIndexSet *)s { return [_a objectsAtIndexes:s]; }
- (NSOrderedSet *)reversedOrderedSet { return [NSOrderedSet orderedSetWithArray:_a.reverseObjectEnumerator.allObjects]; }
- (NSEnumerator *)objectEnumerator { return [_a objectEnumerator]; }
- (NSEnumerator *)reverseObjectEnumerator { return [_a reverseObjectEnumerator]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(__unsafe_unretained id *)buf count:(NSUInteger)len { return [_a countByEnumeratingWithState:st objects:buf count:len]; }
- (BOOL)isEqualToOrderedSet:(NSOrderedSet *)o { return [_a isEqualToArray:o->_a]; }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSOrderedSet class]] && [self isEqualToOrderedSet:o]; }
- (NSUInteger)hash { return _a.count; }
- (BOOL)intersectsOrderedSet:(NSOrderedSet *)o { for (id x in _a) if ([o containsObject:x]) return YES; return NO; }
- (BOOL)intersectsSet:(NSSet *)o { for (id x in _a) if ([o containsObject:x]) return YES; return NO; }
- (BOOL)isSubsetOfOrderedSet:(NSOrderedSet *)o { for (id x in _a) if (![o containsObject:x]) return NO; return YES; }
- (BOOL)isSubsetOfSet:(NSSet *)o { for (id x in _a) if (![o containsObject:x]) return NO; return YES; }
- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))block { [_a enumerateObjectsUsingBlock:block]; }
- (void)enumerateObjectsWithOptions:(NSEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))block { [_a enumerateObjectsWithOptions:opts usingBlock:block]; }
- (NSUInteger)indexOfObjectPassingTest:(BOOL (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))predicate { return [_a indexOfObjectPassingTest:predicate]; }
- (NSIndexSet *)indexesOfObjectsPassingTest:(BOOL (NS_NOESCAPE ^)(id obj, NSUInteger idx, BOOL *stop))predicate { return [_a indexesOfObjectsPassingTest:predicate]; }
- (NSArray *)sortedArrayUsingComparator:(NSComparator NS_NOESCAPE)cmptr { return [_a sortedArrayUsingComparator:cmptr]; }
- (NSArray *)sortedArrayUsingDescriptors:(NSArray<NSSortDescriptor *> *)d { return [_a sortedArrayUsingDescriptors:d]; }
- (NSString *)description { return [NSString stringWithFormat:@"{(\n%@\n)}", [[_a valueForKey:@"description"] componentsJoinedByString:@",\n"]]; }
@end
@implementation NSMutableOrderedSet
+ (instancetype)orderedSetWithCapacity:(NSUInteger)n { return [self new]; }
- (instancetype)initWithCapacity:(NSUInteger)n { return [self init]; }
- (id)copyWithZone:(NSZone *)z { return [[NSOrderedSet alloc] initWithArray:_a]; }
- (void)addObject:(id)o { [self _append:o]; }
- (void)addObjects:(const id *)objs count:(NSUInteger)n { for (NSUInteger i = 0; i < n; i++) [self _append:objs[i]]; }
- (void)addObjectsFromArray:(NSArray *)a { for (id o in a) [self _append:o]; }
- (void)insertObject:(id)o atIndex:(NSUInteger)i { if (![_s containsObject:o]) { [_s addObject:o]; [_a insertObject:o atIndex:i]; } }
- (void)insertObjects:(NSArray *)objects atIndexes:(NSIndexSet *)s { __block NSUInteger k = 0; [s enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { [self insertObject:objects[k++] atIndex:i]; }]; }
- (void)removeObject:(id)o { if ([_s containsObject:o]) { [_a removeObjectAtIndex:[_a indexOfObject:o]]; [_s removeObject:o]; } }
- (void)removeObjectAtIndex:(NSUInteger)i { id o = _a[i]; [_a removeObjectAtIndex:i]; [_s removeObject:o]; }
- (void)removeObjectsAtIndexes:(NSIndexSet *)s { [s enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger i, BOOL *stop) { [self removeObjectAtIndex:i]; }]; }
- (void)removeObjectsInArray:(NSArray *)a { for (id o in a) [self removeObject:o]; }
- (void)removeObjectsInRange:(NSRange)r { for (NSUInteger i = NSMaxRange(r); i-- > r.location;) [self removeObjectAtIndex:i]; }
- (void)removeAllObjects { [_a removeAllObjects]; [_s removeAllObjects]; }
- (void)replaceObjectAtIndex:(NSUInteger)i withObject:(id)o {
    id old = _a[i];
    if ([old isEqual:o]) { _a[i] = o; return; }
    if ([_s containsObject:o]) return;
    [_s removeObject:old]; [_s addObject:o]; _a[i] = o;
}
- (void)setObject:(id)o atIndexedSubscript:(NSUInteger)i { if (i == _a.count) [self addObject:o]; else [self replaceObjectAtIndex:i withObject:o]; }
- (void)setObject:(id)o atIndex:(NSUInteger)i { [self setObject:o atIndexedSubscript:i]; }
- (void)exchangeObjectAtIndex:(NSUInteger)a withObjectAtIndex:(NSUInteger)b { [_a exchangeObjectAtIndex:a withObjectAtIndex:b]; }
- (void)moveObjectsAtIndexes:(NSIndexSet *)indexes toIndex:(NSUInteger)idx {
    NSArray *moving = [_a objectsAtIndexes:indexes];
    [_a removeObjectsAtIndexes:indexes];
    for (NSUInteger k = 0; k < moving.count; k++) [_a insertObject:moving[k] atIndex:idx + k];
}
- (void)unionOrderedSet:(NSOrderedSet *)o { for (id x in o->_a) [self _append:x]; }
- (void)unionSet:(NSSet *)o { for (id x in o) [self _append:x]; }
- (void)intersectOrderedSet:(NSOrderedSet *)o { for (id x in [_a copy]) if (![o containsObject:x]) [self removeObject:x]; }
- (void)intersectSet:(NSSet *)o { for (id x in [_a copy]) if (![o containsObject:x]) [self removeObject:x]; }
- (void)minusOrderedSet:(NSOrderedSet *)o { for (id x in o->_a) [self removeObject:x]; }
- (void)minusSet:(NSSet *)o { for (id x in o) [self removeObject:x]; }
- (void)sortUsingComparator:(NSComparator NS_NOESCAPE)cmptr { [_a sortUsingComparator:cmptr]; }
- (void)sortUsingDescriptors:(NSArray<NSSortDescriptor *> *)d { [_a sortUsingDescriptors:d]; }
- (void)sortWithOptions:(NSSortOptions)opts usingComparator:(NSComparator NS_NOESCAPE)cmptr { [_a sortUsingComparator:cmptr]; }
@end

/* ================= NSCountedSet ================= */
@implementation NSCountedSet { NSMutableArray *_items; NSMutableArray<NSNumber *> *_cnt; }
/* NSSet's initializers funnel into -initWithObjects:count:, so storage is set up there */
- (instancetype)initWithObjects:(const id *)objs count:(NSUInteger)n {
    if ((self = [super initWithObjects:NULL count:0])) {
        _items = [NSMutableArray array]; _cnt = [NSMutableArray array];
        for (NSUInteger i = 0; i < n; i++) [self addObject:objs[i]];
    }
    return self;
}
- (instancetype)init { return [self initWithObjects:NULL count:0]; }
- (instancetype)initWithCapacity:(NSUInteger)n { return [self initWithObjects:NULL count:0]; }
- (instancetype)initWithArray:(NSArray *)a { if ((self = [self initWithObjects:NULL count:0])) for (id o in a) [self addObject:o]; return self; }
- (instancetype)initWithSet:(NSSet *)s { return [self initWithArray:s.allObjects]; }
- (NSUInteger)_indexOf:(id)o { return [_items indexOfObject:o]; }
- (void)addObject:(id)o { NSUInteger i = [self _indexOf:o]; if (i == NSNotFound) { [_items addObject:o]; [_cnt addObject:@1]; } else _cnt[i] = @(_cnt[i].unsignedIntegerValue + 1); }
- (void)removeObject:(id)o {
    NSUInteger i = [self _indexOf:o]; if (i == NSNotFound) return;
    NSUInteger c = _cnt[i].unsignedIntegerValue;
    if (c <= 1) { [_items removeObjectAtIndex:i]; [_cnt removeObjectAtIndex:i]; } else _cnt[i] = @(c - 1);
}
- (void)removeAllObjects { [_items removeAllObjects]; [_cnt removeAllObjects]; }
- (NSUInteger)countForObject:(id)o { NSUInteger i = [self _indexOf:o]; return i == NSNotFound ? 0 : _cnt[i].unsignedIntegerValue; }
- (NSUInteger)count { return _items.count; }
- (id)member:(id)o { NSUInteger i = [self _indexOf:o]; return i == NSNotFound ? nil : _items[i]; }
- (BOOL)containsObject:(id)o { return [self _indexOf:o] != NSNotFound; }
- (id)anyObject { return _items.firstObject; }
- (NSArray *)allObjects { return [_items copy]; }
- (NSEnumerator *)objectEnumerator { return [_items objectEnumerator]; }
- (void)enumerateObjectsUsingBlock:(void (NS_NOESCAPE ^)(id obj, BOOL *stop))block { BOOL stop = NO; for (id o in [_items copy]) { block(o, &stop); if (stop) break; } }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(__unsafe_unretained id *)buf count:(NSUInteger)len { return [_items countByEnumeratingWithState:st objects:buf count:len]; }
- (id)copyWithZone:(NSZone *)z { NSCountedSet *c = [NSCountedSet new]; for (NSUInteger i = 0; i < _items.count; i++) for (NSUInteger k = 0; k < _cnt[i].unsignedIntegerValue; k++) [c addObject:_items[i]]; return c; }
- (id)mutableCopyWithZone:(NSZone *)z { return [self copyWithZone:z]; }
@end

/* ================= NSSortDescriptor ================= */
@implementation NSSortDescriptor { SEL _sel; NSComparator _cmp; }
+ (instancetype)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)asc { return [[self alloc] initWithKey:key ascending:asc]; }
+ (instancetype)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)asc selector:(SEL)sel { return [[self alloc] initWithKey:key ascending:asc selector:sel]; }
+ (instancetype)sortDescriptorWithKey:(NSString *)key ascending:(BOOL)asc comparator:(NSComparator)cmp { return [[self alloc] initWithKey:key ascending:asc comparator:cmp]; }
- (instancetype)initWithKey:(NSString *)key ascending:(BOOL)asc { return [self initWithKey:key ascending:asc selector:@selector(compare:)]; }
- (instancetype)initWithKey:(NSString *)key ascending:(BOOL)asc selector:(SEL)sel {
    if ((self = [super init])) { _key = [key copy]; _ascending = asc; _sel = sel ?: @selector(compare:); }
    return self;
}
- (instancetype)initWithKey:(NSString *)key ascending:(BOOL)asc comparator:(NSComparator)cmp {
    if ((self = [super init])) { _key = [key copy]; _ascending = asc; _cmp = [cmp copy]; }
    return self;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithKey:nil ascending:YES]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (SEL)selector { return _cmp ? NULL : _sel; }
- (NSComparator)comparator {
    if (_cmp) return _cmp;
    SEL sel = _sel;
    return ^NSComparisonResult(id a, id b) { return ((NSComparisonResult (*)(id, SEL, id))objc_msgSend)(a, sel, b); };
}
- (NSComparisonResult)compareObject:(id)a toObject:(id)b {
    id va = _key ? [a valueForKeyPath:_key] : a, vb = _key ? [b valueForKeyPath:_key] : b;
    NSComparisonResult r;
    if (va == vb) r = NSOrderedSame;
    else if (!va || va == [NSNull null]) r = NSOrderedAscending;
    else if (!vb || vb == [NSNull null]) r = NSOrderedDescending;
    else if (_cmp) r = _cmp(va, vb);
    else r = ((NSComparisonResult (*)(id, SEL, id))objc_msgSend)(va, _sel, vb);
    return _ascending ? r : (NSComparisonResult)(-r);
}
- (id)reversedSortDescriptor {
    return _cmp ? [[NSSortDescriptor alloc] initWithKey:_key ascending:!_ascending comparator:_cmp] : [[NSSortDescriptor alloc] initWithKey:_key ascending:!_ascending selector:_sel];
}
- (NSString *)description { return [NSString stringWithFormat:@"(%@, %@, %@)", _key, _ascending ? @"ascending" : @"descending", _cmp ? @"comparator" : NSStringFromSelector(_sel)]; }
@end

/* ================= NSCache ================= */
@interface _IsimCacheEntry : NSObject
@property (nonatomic, strong) id key, object;
@property (nonatomic) NSUInteger cost;
@end
@implementation _IsimCacheEntry @end
@implementation NSCache { NSMutableDictionary *_map; NSMutableArray<_IsimCacheEntry *> *_lru; NSUInteger _totalCost; pthread_mutex_t _lock; }
- (instancetype)init {
    if ((self = [super init])) { _map = [NSMutableDictionary dictionary]; _lru = [NSMutableArray array]; _name = @""; _evictsObjectsWithDiscardedContent = YES; pthread_mutex_init(&_lock, NULL); }
    return self;
}
- (void)dealloc { pthread_mutex_destroy(&_lock); }
- (id)objectForKey:(id)key {
    if (!key) return nil;
    pthread_mutex_lock(&_lock);
    _IsimCacheEntry *e = _map[[NSValue valueWithNonretainedObject:key]] ?: [self _entryForEqualKey:key];
    if (e) { [_lru removeObjectIdenticalTo:e]; [_lru addObject:e]; }
    id o = e.object;
    pthread_mutex_unlock(&_lock);
    return o;
}
/* keys are compared with isEqual: like NSDictionary (Apple's NSCache does not copy keys) */
- (_IsimCacheEntry *)_entryForEqualKey:(id)key { for (_IsimCacheEntry *e in _lru) if ([e.key isEqual:key]) return e; return nil; }
- (void)setObject:(id)obj forKey:(id)key { [self setObject:obj forKey:key cost:0]; }
- (void)setObject:(id)obj forKey:(id)key cost:(NSUInteger)cost {
    if (!key || !obj) return;
    NSMutableArray *evicted = [NSMutableArray array];
    pthread_mutex_lock(&_lock);
    _IsimCacheEntry *e = [self _entryForEqualKey:key];
    if (e) { _totalCost -= e.cost; [_lru removeObjectIdenticalTo:e]; [_map removeObjectForKey:[NSValue valueWithNonretainedObject:e.key]]; }
    e = [_IsimCacheEntry new]; e.key = key; e.object = obj; e.cost = cost;
    [_lru addObject:e]; _map[[NSValue valueWithNonretainedObject:key]] = e; _totalCost += cost;
    while (_lru.count > 1 && ((_countLimit && _lru.count > _countLimit) || (_totalCostLimit && _totalCost > _totalCostLimit))) {
        _IsimCacheEntry *old = _lru.firstObject;
        [_lru removeObjectAtIndex:0]; [_map removeObjectForKey:[NSValue valueWithNonretainedObject:old.key]]; _totalCost -= old.cost;
        [evicted addObject:old.object];
    }
    pthread_mutex_unlock(&_lock);
    id<NSCacheDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(cache:willEvictObject:)]) for (id o in evicted) [d cache:self willEvictObject:o];
}
- (void)removeObjectForKey:(id)key {
    if (!key) return;
    pthread_mutex_lock(&_lock);
    _IsimCacheEntry *e = [self _entryForEqualKey:key];
    if (e) { [_lru removeObjectIdenticalTo:e]; [_map removeObjectForKey:[NSValue valueWithNonretainedObject:e.key]]; _totalCost -= e.cost; }
    pthread_mutex_unlock(&_lock);
    id<NSCacheDelegate> d = self.delegate;
    if (e && [d respondsToSelector:@selector(cache:willEvictObject:)]) [d cache:self willEvictObject:e.object];
}
- (void)removeAllObjects {
    pthread_mutex_lock(&_lock);
    NSArray *all = [_lru valueForKey:@"object"];
    [_lru removeAllObjects]; [_map removeAllObjects]; _totalCost = 0;
    pthread_mutex_unlock(&_lock);
    id<NSCacheDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(cache:willEvictObject:)]) for (id o in all) [d cache:self willEvictObject:o];
}
@end

/* ================= weak/strong boxes for NSHashTable, NSMapTable, NSPointerArray ================= */
@interface _IsimRef : NSObject { @public __weak id _weak; id _strong; BOOL _isWeak; }
@end
@implementation _IsimRef
static _IsimRef *ref(id o, BOOL weak) { _IsimRef *r = [_IsimRef new]; r->_isWeak = weak; if (weak) r->_weak = o; else r->_strong = o; return r; }
- (id)object { return _isWeak ? _weak : _strong; }
@end
static BOOL is_weak(NSPointerFunctionsOptions o) { return (o & 0xFF) == NSPointerFunctionsWeakMemory; }
static BOOL is_identity(NSPointerFunctionsOptions o) { return (o & 0xFF00) == NSPointerFunctionsObjectPointerPersonality; }
static BOOL same(id a, id b, BOOL identity) { return a == b || (!identity && [a isEqual:b]); }

@implementation NSHashTable { NSMutableArray<_IsimRef *> *_refs; NSPointerFunctionsOptions _opts; }
+ (instancetype)hashTableWithOptions:(NSPointerFunctionsOptions)o { return [[self alloc] initWithOptions:o capacity:0]; }
+ (NSHashTable *)weakObjectsHashTable { return [self hashTableWithOptions:NSPointerFunctionsWeakMemory]; }
- (instancetype)init { return [self initWithOptions:NSPointerFunctionsStrongMemory capacity:0]; }
- (instancetype)initWithOptions:(NSPointerFunctionsOptions)o capacity:(NSUInteger)c { if ((self = [super init])) { _opts = o; _refs = [NSMutableArray array]; } return self; }
- (void)_compact { for (NSUInteger i = _refs.count; i-- > 0;) if (!_refs[i].object) [_refs removeObjectAtIndex:i]; }
- (id)member:(id)o { [self _compact]; for (_IsimRef *r in _refs) if (same(r.object, o, is_identity(_opts))) return r.object; return nil; }
- (BOOL)containsObject:(id)o { return o && [self member:o] != nil; }
- (void)addObject:(id)o { if (!o || [self containsObject:o]) return; [_refs addObject:ref((_opts & NSPointerFunctionsCopyIn) ? [o copy] : o, is_weak(_opts))]; }
- (void)removeObject:(id)o { for (NSUInteger i = _refs.count; i-- > 0;) if (same(_refs[i].object, o, is_identity(_opts))) [_refs removeObjectAtIndex:i]; }
- (void)removeAllObjects { [_refs removeAllObjects]; }
- (NSUInteger)count { [self _compact]; return _refs.count; }
- (NSArray *)allObjects { [self _compact]; NSMutableArray *a = [NSMutableArray array]; for (_IsimRef *r in _refs) { id o = r.object; if (o) [a addObject:o]; } return a; }
- (id)anyObject { return self.allObjects.firstObject; }
- (NSSet *)setRepresentation { return [NSSet setWithArray:self.allObjects]; }
- (NSEnumerator *)objectEnumerator { return [self.allObjects objectEnumerator]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(__unsafe_unretained id *)buf count:(NSUInteger)len {
    if (st->state == 0) objc_setAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:), self.allObjects, OBJC_ASSOCIATION_RETAIN);
    NSArray *snap = objc_getAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:));
    return [snap countByEnumeratingWithState:st objects:buf count:len];
}
- (void)unionHashTable:(NSHashTable *)o { for (id x in o.allObjects) [self addObject:x]; }
- (void)minusHashTable:(NSHashTable *)o { for (id x in o.allObjects) [self removeObject:x]; }
- (void)intersectHashTable:(NSHashTable *)o { for (id x in self.allObjects) if (![o containsObject:x]) [self removeObject:x]; }
- (id)copyWithZone:(NSZone *)z { NSHashTable *h = [[NSHashTable alloc] initWithOptions:_opts capacity:0]; for (id o in self.allObjects) [h addObject:o]; return h; }
@end

@implementation NSMapTable { NSMutableArray<_IsimRef *> *_keys, *_vals; NSPointerFunctionsOptions _ko, _vo; }
+ (instancetype)mapTableWithKeyOptions:(NSPointerFunctionsOptions)k valueOptions:(NSPointerFunctionsOptions)v { return [[self alloc] initWithKeyOptions:k valueOptions:v capacity:0]; }
+ (NSMapTable *)strongToStrongObjectsMapTable { return [self mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory]; }
+ (NSMapTable *)weakToStrongObjectsMapTable { return [self mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory]; }
+ (NSMapTable *)strongToWeakObjectsMapTable { return [self mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsWeakMemory]; }
+ (NSMapTable *)weakToWeakObjectsMapTable { return [self mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsWeakMemory]; }
- (instancetype)init { return [self initWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory capacity:0]; }
- (instancetype)initWithKeyOptions:(NSPointerFunctionsOptions)k valueOptions:(NSPointerFunctionsOptions)v capacity:(NSUInteger)c {
    if ((self = [super init])) { _ko = k; _vo = v; _keys = [NSMutableArray array]; _vals = [NSMutableArray array]; }
    return self;
}
- (void)_compact { for (NSUInteger i = _keys.count; i-- > 0;) if (!_keys[i].object || !_vals[i].object) { [_keys removeObjectAtIndex:i]; [_vals removeObjectAtIndex:i]; } }
- (NSUInteger)_indexOfKey:(id)k { for (NSUInteger i = 0; i < _keys.count; i++) if (same(_keys[i].object, k, is_identity(_ko))) return i; return NSNotFound; }
- (id)objectForKey:(id)k { if (!k) return nil; [self _compact]; NSUInteger i = [self _indexOfKey:k]; return i == NSNotFound ? nil : _vals[i].object; }
- (void)setObject:(id)o forKey:(id)k {
    if (!k) return;
    if (!o) { [self removeObjectForKey:k]; return; }
    NSUInteger i = [self _indexOfKey:k];
    _IsimRef *vr = ref(o, is_weak(_vo));
    if (i == NSNotFound) { [_keys addObject:ref((_ko & NSPointerFunctionsCopyIn) ? [k copy] : k, is_weak(_ko))]; [_vals addObject:vr]; }
    else _vals[i] = vr;
}
- (void)removeObjectForKey:(id)k { NSUInteger i = [self _indexOfKey:k]; if (i != NSNotFound) { [_keys removeObjectAtIndex:i]; [_vals removeObjectAtIndex:i]; } }
- (void)removeAllObjects { [_keys removeAllObjects]; [_vals removeAllObjects]; }
- (NSUInteger)count { [self _compact]; return _keys.count; }
- (NSEnumerator *)keyEnumerator { [self _compact]; return [[_keys valueForKey:@"object"] objectEnumerator]; }
- (NSEnumerator *)objectEnumerator { [self _compact]; return [[_vals valueForKey:@"object"] objectEnumerator]; }
- (NSDictionary *)dictionaryRepresentation { [self _compact]; NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSUInteger i = 0; i < _keys.count; i++) d[_keys[i].object] = _vals[i].object; return d; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(__unsafe_unretained id *)buf count:(NSUInteger)len {
    if (st->state == 0) { [self _compact]; objc_setAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:), [_keys valueForKey:@"object"], OBJC_ASSOCIATION_RETAIN); }
    NSArray *snap = objc_getAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:));
    return [snap countByEnumeratingWithState:st objects:buf count:len];
}
- (id)copyWithZone:(NSZone *)z { NSMapTable *m = [[NSMapTable alloc] initWithKeyOptions:_ko valueOptions:_vo capacity:0]; [self _compact]; for (NSUInteger i = 0; i < _keys.count; i++) [m setObject:_vals[i].object forKey:_keys[i].object]; return m; }
@end

@implementation NSPointerArray { NSMutableArray<_IsimRef *> *_refs; NSPointerFunctionsOptions _opts; }
+ (NSPointerArray *)weakObjectsPointerArray { return [[self alloc] initWithOptions:NSPointerFunctionsWeakMemory]; }
+ (NSPointerArray *)strongObjectsPointerArray { return [[self alloc] initWithOptions:NSPointerFunctionsStrongMemory]; }
+ (NSPointerArray *)pointerArrayWithOptions:(NSPointerFunctionsOptions)o { return [[self alloc] initWithOptions:o]; }
- (instancetype)initWithOptions:(NSPointerFunctionsOptions)o { if ((self = [super init])) { _opts = o; _refs = [NSMutableArray array]; } return self; }
- (instancetype)init { return [self initWithOptions:NSPointerFunctionsStrongMemory]; }
- (NSUInteger)count { return _refs.count; }
- (void)setCount:(NSUInteger)n { while (_refs.count > n) [_refs removeLastObject]; while (_refs.count < n) [_refs addObject:ref(nil, is_weak(_opts))]; }
- (void *)pointerAtIndex:(NSUInteger)i { return (__bridge void *)_refs[i].object; }
- (void)addPointer:(void *)p { [_refs addObject:ref((__bridge id)p, is_weak(_opts))]; }
- (void)removePointerAtIndex:(NSUInteger)i { [_refs removeObjectAtIndex:i]; }
- (void)insertPointer:(void *)p atIndex:(NSUInteger)i { [_refs insertObject:ref((__bridge id)p, is_weak(_opts)) atIndex:i]; }
- (void)replacePointerAtIndex:(NSUInteger)i withPointer:(void *)p { _refs[i] = ref((__bridge id)p, is_weak(_opts)); }
- (void)compact { for (NSUInteger i = _refs.count; i-- > 0;) if (!_refs[i].object) [_refs removeObjectAtIndex:i]; }
- (NSArray *)allObjects { NSMutableArray *a = [NSMutableArray array]; for (_IsimRef *r in _refs) { id o = r.object; if (o) [a addObject:o]; } return a; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(__unsafe_unretained id *)buf count:(NSUInteger)len {
    if (st->state == 0) objc_setAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:), self.allObjects, OBJC_ASSOCIATION_RETAIN);
    NSArray *snap = objc_getAssociatedObject(self, @selector(countByEnumeratingWithState:objects:count:));
    return [snap countByEnumeratingWithState:st objects:buf count:len];
}
- (id)copyWithZone:(NSZone *)z { NSPointerArray *p = [[NSPointerArray alloc] initWithOptions:_opts]; for (_IsimRef *r in _refs) [p addPointer:(__bridge void *)r.object]; return p; }
@end
