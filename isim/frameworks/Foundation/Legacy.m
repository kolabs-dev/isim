/* isim Foundation (ARC): the older Objective-C API apps and libraries still use. Self-authored.
 * - NSPurgeableData and NSDiscardableContent (content discarded only on request or by an NSCache eviction)
 * - NSOrderedCollectionChange / NSOrderedCollectionDifference and the NSArray / NSOrderedSet diffing methods (a longest
 *   common subsequence; inferMoves pairs a removal with an insertion of an equal object)
 * - the NSMapTable / NSHashTable C functions: NSCreateMapTable / NSCreateHashTable tables keep raw pointers with their
 *   callbacks; the functions also work on object tables
 * - NSURLConnection over an NSURLSession task, its delegate called on the run loops it is scheduled on or its queue */
#import <Foundation/Foundation.h>
#import <CoreFoundation/CoreFoundation.h>
#include <stdlib.h>

/* ================= NSPurgeableData / NSDiscardableContent ================= */
@implementation NSPurgeableData { NSUInteger _accessCount; BOOL _discarded; }
- (instancetype)initWithBytes:(const void *)b length:(NSUInteger)n {
    if ((self = [super initWithBytes:b length:n])) _accessCount = 1;      /* created accessed, as on iOS */
    return self;
}
- (instancetype)initWithBytesNoCopy:(void *)b length:(NSUInteger)n freeWhenDone:(BOOL)f {
    if ((self = [super initWithBytesNoCopy:b length:n freeWhenDone:f])) _accessCount = 1;
    return self;
}
- (BOOL)beginContentAccess {
    @synchronized (self) { if (_discarded) return NO; _accessCount++; return YES; }
}
- (void)endContentAccess {
    @synchronized (self) {
        if (!_accessCount) [NSException raise:NSGenericException format:@"-[NSPurgeableData endContentAccess] without a matching beginContentAccess"];
        _accessCount--;
    }
}
- (void)discardContentIfPossible {
    @synchronized (self) {
        if (_accessCount || _discarded) return;
        _discarded = YES;
        [super setLength:0];
    }
}
- (BOOL)isContentDiscarded { @synchronized (self) { return _discarded; } }
@end

/* a proxy that keeps its object's content accessed while it lives */
@interface __IsimContentAccessingProxy : NSProxy { @public id _target; }
@end
@implementation __IsimContentAccessingProxy
- (void)dealloc { [_target endContentAccess]; }
- (NSMethodSignature *)methodSignatureForSelector:(SEL)sel { return [_target methodSignatureForSelector:sel]; }
- (void)forwardInvocation:(NSInvocation *)inv { [inv invokeWithTarget:_target]; }
- (id)forwardingTargetForSelector:(SEL)sel { return _target; }
@end
@implementation NSObject (NSDiscardableContentProxy)
- (id)autoContentAccessingProxy {
    if (![self conformsToProtocol:@protocol(NSDiscardableContent)]) return self;
    if (![(id<NSDiscardableContent>)self beginContentAccess]) return nil;
    __IsimContentAccessingProxy *p = [__IsimContentAccessingProxy alloc];
    p->_target = self;
    return p;
}
@end

/* ================= NSOrderedCollectionChange / NSOrderedCollectionDifference ================= */
@implementation NSOrderedCollectionChange
+ (instancetype)changeWithObject:(id)o type:(NSCollectionChangeType)t index:(NSUInteger)i { return [[self alloc] initWithObject:o type:t index:i]; }
+ (instancetype)changeWithObject:(id)o type:(NSCollectionChangeType)t index:(NSUInteger)i associatedIndex:(NSUInteger)a {
    return [[self alloc] initWithObject:o type:t index:i associatedIndex:a];
}
- (instancetype)initWithObject:(id)o type:(NSCollectionChangeType)t index:(NSUInteger)i { return [self initWithObject:o type:t index:i associatedIndex:NSNotFound]; }
- (instancetype)initWithObject:(id)o type:(NSCollectionChangeType)t index:(NSUInteger)i associatedIndex:(NSUInteger)a {
    if ((self = [super init])) { _object = o; _changeType = t; _index = i; _associatedIndex = a; }
    return self;
}
- (BOOL)isEqual:(id)other {
    if (![other isKindOfClass:[NSOrderedCollectionChange class]]) return NO;
    NSOrderedCollectionChange *c = other;
    return c.changeType == _changeType && c.index == _index && c.associatedIndex == _associatedIndex && (c.object == _object || [c.object isEqual:_object]);
}
- (NSUInteger)hash { return _index * 31 + (NSUInteger)_changeType; }
- (NSString *)description {
    return [NSString stringWithFormat:@"<%@ %@ %lu%@: %@>", NSStringFromClass([self class]), _changeType == NSCollectionChangeInsert ? @"insert" : @"remove",
            (unsigned long)_index, _associatedIndex == NSNotFound ? @"" : [NSString stringWithFormat:@" (moved %lu)", (unsigned long)_associatedIndex], _object];
}
@end

@implementation NSOrderedCollectionDifference { NSArray *_all; }
static NSArray *sorted_by_index(NSArray<NSOrderedCollectionChange *> *a) {
    return [a sortedArrayUsingComparator:^NSComparisonResult(NSOrderedCollectionChange *x, NSOrderedCollectionChange *y) {
        return x.index < y.index ? NSOrderedAscending : x.index > y.index ? NSOrderedDescending : NSOrderedSame;
    }];
}
- (instancetype)initWithChanges:(NSArray<NSOrderedCollectionChange *> *)changes {
    return [self initWithInsertIndexes:[NSIndexSet indexSet] insertedObjects:nil removeIndexes:[NSIndexSet indexSet] removedObjects:nil additionalChanges:changes];
}
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes
                       removedObjects:(NSArray *)removedObjects {
    return [self initWithInsertIndexes:inserts insertedObjects:insertedObjects removeIndexes:removes removedObjects:removedObjects additionalChanges:@[]];
}
- (instancetype)initWithInsertIndexes:(NSIndexSet *)inserts insertedObjects:(NSArray *)insertedObjects removeIndexes:(NSIndexSet *)removes
                       removedObjects:(NSArray *)removedObjects additionalChanges:(NSArray<NSOrderedCollectionChange *> *)changes {
    if ((insertedObjects && insertedObjects.count != inserts.count) || (removedObjects && removedObjects.count != removes.count))
        [NSException raise:NSInvalidArgumentException format:@"NSOrderedCollectionDifference: the objects do not match the indexes"];
    if ((self = [super init])) {
        NSMutableArray *ins = [NSMutableArray array], *rem = [NSMutableArray array];
        __block NSUInteger k = 0;
        [inserts enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
            [ins addObject:[[NSOrderedCollectionChange alloc] initWithObject:insertedObjects ? insertedObjects[k] : nil type:NSCollectionChangeInsert index:i]]; k++;
        }];
        k = 0;
        [removes enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) {
            [rem addObject:[[NSOrderedCollectionChange alloc] initWithObject:removedObjects ? removedObjects[k] : nil type:NSCollectionChangeRemove index:i]]; k++;
        }];
        for (NSOrderedCollectionChange *c in changes) [c.changeType == NSCollectionChangeInsert ? ins : rem addObject:c];
        _insertions = sorted_by_index(ins); _removals = sorted_by_index(rem);
        for (NSArray *side in @[_insertions, _removals])
            for (NSUInteger i = 1; i < side.count; i++)
                if (((NSOrderedCollectionChange *)side[i]).index == ((NSOrderedCollectionChange *)side[i - 1]).index)
                    [NSException raise:NSInvalidArgumentException format:@"NSOrderedCollectionDifference: two changes of one kind at index %lu",
                                       (unsigned long)((NSOrderedCollectionChange *)side[i]).index];
        /* enumeration order: removals from the highest index down, then insertions from the lowest up */
        _all = [_removals.reverseObjectEnumerator.allObjects arrayByAddingObjectsFromArray:_insertions];
    }
    return self;
}
- (BOOL)hasChanges { return _all.count > 0; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)state objects:(__unsafe_unretained id _Nullable [])buffer count:(NSUInteger)len {
    return [_all countByEnumeratingWithState:state objects:buffer count:len];
}
- (NSOrderedCollectionDifference *)differenceByTransformingChangesWithBlock:(NSOrderedCollectionChange *(NS_NOESCAPE ^)(NSOrderedCollectionChange *))block {
    NSMutableArray *out = [NSMutableArray array];
    for (NSOrderedCollectionChange *c in _all) [out addObject:block(c)];
    return [[NSOrderedCollectionDifference alloc] initWithChanges:out];
}
- (instancetype)inverseDifference {
    NSMutableArray *out = [NSMutableArray array];
    for (NSOrderedCollectionChange *c in _all)
        [out addObject:[[NSOrderedCollectionChange alloc] initWithObject:c.object
                                                                     type:c.changeType == NSCollectionChangeInsert ? NSCollectionChangeRemove : NSCollectionChangeInsert
                                                                    index:c.index associatedIndex:c.associatedIndex]];
    return [[[self class] alloc] initWithChanges:out];
}
- (NSString *)description { return [NSString stringWithFormat:@"<%@ removals %@ insertions %@>", NSStringFromClass([self class]), _removals, _insertions]; }
@end

/* the changes from `old` to `new`: what a longest common subsequence leaves out of each */
static NSOrderedCollectionDifference *diff(NSArray *new, NSArray *old, NSOrderedCollectionDifferenceCalculationOptions options,
                                           BOOL (NS_NOESCAPE ^eq)(id, id)) {
    NSUInteger n = old.count, m = new.count;
    uint32_t *t = calloc((n + 1) * (m + 1), sizeof(uint32_t));               /* t[i][j]: LCS of old[i..] and new[j..] */
    #define T(i, j) t[(i) * (m + 1) + (j)]
    for (NSUInteger i = n; i-- > 0;)
        for (NSUInteger j = m; j-- > 0;)
            T(i, j) = eq(old[i], new[j]) ? T(i + 1, j + 1) + 1 : MAX(T(i + 1, j), T(i, j + 1));
    NSMutableIndexSet *removed = [NSMutableIndexSet indexSet], *inserted = [NSMutableIndexSet indexSet];
    NSUInteger i = 0, j = 0;
    while (i < n && j < m) {
        if (eq(old[i], new[j]) && T(i, j) == T(i + 1, j + 1) + 1) { i++; j++; }
        else if (T(i + 1, j) >= T(i, j + 1)) [removed addIndex:i++];
        else [inserted addIndex:j++];
    }
    while (i < n) [removed addIndex:i++];
    while (j < m) [inserted addIndex:j++];
    #undef T
    free(t);
    NSMutableArray *rem = [NSMutableArray array], *ins = [NSMutableArray array];
    [removed enumerateIndexesUsingBlock:^(NSUInteger k, BOOL *stop) { [rem addObject:@[@(k), old[k]]]; }];
    [inserted enumerateIndexesUsingBlock:^(NSUInteger k, BOOL *stop) { [ins addObject:@[@(k), new[k]]]; }];
    NSMutableDictionary<NSNumber *, NSNumber *> *moveOfRemoval = [NSMutableDictionary dictionary], *moveOfInsertion = [NSMutableDictionary dictionary];
    if (options & NSOrderedCollectionDifferenceCalculationInferMoves)
        for (NSArray *r in rem)
            for (NSArray *in in ins)
                if (!moveOfInsertion[in[0]] && eq(r[1], in[1])) { moveOfRemoval[r[0]] = in[0]; moveOfInsertion[in[0]] = r[0]; break; }
    NSMutableArray *changes = [NSMutableArray array];
    for (NSArray *r in rem)
        [changes addObject:[[NSOrderedCollectionChange alloc] initWithObject:(options & NSOrderedCollectionDifferenceCalculationOmitRemovedObjects) ? nil : r[1]
                                                                        type:NSCollectionChangeRemove index:[r[0] unsignedIntegerValue]
                                                             associatedIndex:moveOfRemoval[r[0]] ? moveOfRemoval[r[0]].unsignedIntegerValue : NSNotFound]];
    for (NSArray *in in ins)
        [changes addObject:[[NSOrderedCollectionChange alloc] initWithObject:(options & NSOrderedCollectionDifferenceCalculationOmitInsertedObjects) ? nil : in[1]
                                                                        type:NSCollectionChangeInsert index:[in[0] unsignedIntegerValue]
                                                             associatedIndex:moveOfInsertion[in[0]] ? moveOfInsertion[in[0]].unsignedIntegerValue : NSNotFound]];
    return [[NSOrderedCollectionDifference alloc] initWithChanges:changes];
}
/* the collection the difference makes of `base`, or nil when it does not apply */
static NSMutableArray *apply(NSArray *base, NSOrderedCollectionDifference *d) {
    NSMutableArray *a = [base mutableCopy];
    NSMutableDictionary<NSNumber *, id> *removedAt = [NSMutableDictionary dictionary];
    for (NSOrderedCollectionChange *c in d.removals.reverseObjectEnumerator) {
        if (c.index >= a.count) return nil;
        removedAt[@(c.index)] = a[c.index];
        [a removeObjectAtIndex:c.index];
    }
    for (NSOrderedCollectionChange *c in d.insertions) {
        id o = c.object ?: (c.associatedIndex != NSNotFound ? removedAt[@(c.associatedIndex)] : nil);
        if (!o || c.index > a.count) return nil;
        [a insertObject:o atIndex:c.index];
    }
    return a;
}
static BOOL (^const isEqualTest)(id, id) = ^BOOL(id a, id b) { return [a isEqual:b]; };

@implementation NSArray (NSArrayDiffing)
- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
                                  usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block {
    return diff(self, other, options, block);
}
- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options {
    return diff(self, other, options, isEqualTest);
}
- (NSOrderedCollectionDifference *)differenceFromArray:(NSArray *)other { return diff(self, other, 0, isEqualTest); }
- (NSArray *)arrayByApplyingDifference:(NSOrderedCollectionDifference *)difference { return [apply(self, difference) copy]; }
@end
@implementation NSMutableArray (NSMutableArrayDiffing)
- (void)applyDifference:(NSOrderedCollectionDifference *)difference {
    NSArray *r = apply(self, difference);
    if (!r) [NSException raise:NSInvalidArgumentException format:@"-[NSMutableArray applyDifference:]: the difference does not apply"];
    [self setArray:r];
}
@end
@implementation NSOrderedSet (NSOrderedSetDiffing)
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options
                                       usingEquivalenceTest:(BOOL (NS_NOESCAPE ^)(id, id))block {
    return diff(self.array, other.array, options, block);
}
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other withOptions:(NSOrderedCollectionDifferenceCalculationOptions)options {
    return diff(self.array, other.array, options, isEqualTest);
}
- (NSOrderedCollectionDifference *)differenceFromOrderedSet:(NSOrderedSet *)other { return diff(self.array, other.array, 0, isEqualTest); }
- (NSOrderedSet *)orderedSetByApplyingDifference:(NSOrderedCollectionDifference *)difference {
    NSArray *r = apply(self.array, difference);
    return r ? [NSOrderedSet orderedSetWithArray:r] : nil;
}
@end
@implementation NSMutableOrderedSet (NSMutableOrderedSetDiffing)
- (void)applyDifference:(NSOrderedCollectionDifference *)difference {
    NSArray *r = apply(self.array, difference);
    if (!r) [NSException raise:NSInvalidArgumentException format:@"-[NSMutableOrderedSet applyDifference:]: the difference does not apply"];
    [self removeAllObjects];
    [self addObjectsFromArray:r];
}
@end

/* ================= NSMapTable / NSHashTable C functions ================= */
/* the callbacks */
static NSUInteger ptr_hash(id t, const void *p) { return (NSUInteger)p >> 3 ^ (NSUInteger)p; }
static BOOL ptr_equal(id t, const void *a, const void *b) { return a == b; }
static NSString *ptr_describe(id t, const void *p) { return [NSString stringWithFormat:@"%p", p]; }
static NSString *int_describe(id t, const void *p) { return [NSString stringWithFormat:@"%ld", (long)(intptr_t)p]; }
static void owned_release(id t, void *p) { free(p); }
static NSUInteger obj_hash(id t, const void *p) { return [(__bridge id)p hash]; }
static BOOL obj_equal(id t, const void *a, const void *b) { return a == b || [(__bridge id)a isEqual:(__bridge id)b]; }
static void obj_retain(id t, const void *p) { if (p) CFRetain(p); }
static void obj_release(id t, void *p) { if (p) CFRelease(p); }
static NSString *obj_describe(id t, const void *p) { return [(__bridge id)p description]; }
static NSUInteger struct_hash(id t, const void *p) { return (NSUInteger)*(const int *)p; }
static BOOL struct_equal(id t, const void *a, const void *b) { return *(const int *)a == *(const int *)b; }

#define MAP_KEY(h, e, r, rel, d, marker) { (NSUInteger (*)(NSMapTable *, const void *))h, (BOOL (*)(NSMapTable *, const void *, const void *))e, \
    (void (*)(NSMapTable *, const void *))r, (void (*)(NSMapTable *, void *))rel, (NSString *(*)(NSMapTable *, const void *))d, marker }
#define MAP_VALUE(r, rel, d) { (void (*)(NSMapTable *, const void *))r, (void (*)(NSMapTable *, void *))rel, (NSString *(*)(NSMapTable *, const void *))d }
#define HASH_CB(h, e, r, rel, d) { (NSUInteger (*)(NSHashTable *, const void *))h, (BOOL (*)(NSHashTable *, const void *, const void *))e, \
    (void (*)(NSHashTable *, const void *))r, (void (*)(NSHashTable *, void *))rel, (NSString *(*)(NSHashTable *, const void *))d }
const NSMapTableKeyCallBacks NSIntegerMapKeyCallBacks = MAP_KEY(ptr_hash, ptr_equal, NULL, NULL, int_describe, NSNotAnIntegerMapKey);
const NSMapTableKeyCallBacks NSIntMapKeyCallBacks = MAP_KEY(ptr_hash, ptr_equal, NULL, NULL, int_describe, NSNotAnIntMapKey);
const NSMapTableKeyCallBacks NSNonOwnedPointerMapKeyCallBacks = MAP_KEY(ptr_hash, ptr_equal, NULL, NULL, ptr_describe, NULL);
const NSMapTableKeyCallBacks NSNonOwnedPointerOrNullMapKeyCallBacks = MAP_KEY(ptr_hash, ptr_equal, NULL, NULL, ptr_describe, NSNotAPointerMapKey);
const NSMapTableKeyCallBacks NSNonRetainedObjectMapKeyCallBacks = MAP_KEY(obj_hash, obj_equal, NULL, NULL, obj_describe, NULL);
const NSMapTableKeyCallBacks NSObjectMapKeyCallBacks = MAP_KEY(obj_hash, obj_equal, obj_retain, obj_release, obj_describe, NULL);
const NSMapTableKeyCallBacks NSOwnedPointerMapKeyCallBacks = MAP_KEY(ptr_hash, ptr_equal, NULL, owned_release, ptr_describe, NULL);
const NSMapTableValueCallBacks NSIntegerMapValueCallBacks = MAP_VALUE(NULL, NULL, int_describe);
const NSMapTableValueCallBacks NSIntMapValueCallBacks = MAP_VALUE(NULL, NULL, int_describe);
const NSMapTableValueCallBacks NSNonOwnedPointerMapValueCallBacks = MAP_VALUE(NULL, NULL, ptr_describe);
const NSMapTableValueCallBacks NSObjectMapValueCallBacks = MAP_VALUE(obj_retain, obj_release, obj_describe);
const NSMapTableValueCallBacks NSNonRetainedObjectMapValueCallBacks = MAP_VALUE(NULL, NULL, obj_describe);
const NSMapTableValueCallBacks NSOwnedPointerMapValueCallBacks = MAP_VALUE(NULL, owned_release, ptr_describe);
const NSHashTableCallBacks NSIntegerHashCallBacks = HASH_CB(ptr_hash, ptr_equal, NULL, NULL, int_describe);
const NSHashTableCallBacks NSIntHashCallBacks = HASH_CB(ptr_hash, ptr_equal, NULL, NULL, int_describe);
const NSHashTableCallBacks NSNonOwnedPointerHashCallBacks = HASH_CB(ptr_hash, ptr_equal, NULL, NULL, ptr_describe);
const NSHashTableCallBacks NSNonRetainedObjectHashCallBacks = HASH_CB(obj_hash, obj_equal, NULL, NULL, obj_describe);
const NSHashTableCallBacks NSObjectHashCallBacks = HASH_CB(obj_hash, obj_equal, obj_retain, obj_release, obj_describe);
const NSHashTableCallBacks NSOwnedPointerHashCallBacks = HASH_CB(ptr_hash, ptr_equal, NULL, owned_release, ptr_describe);
const NSHashTableCallBacks NSPointerToStructHashCallBacks = HASH_CB(struct_hash, struct_equal, NULL, owned_release, ptr_describe);

/* a chained hash table of raw pointers, with the callbacks of a map (keys and values) or a hash table (items) */
typedef struct pnode { void *key, *value; struct pnode *next; } pnode;
typedef struct {
    NSUInteger (*hash)(id, const void *);
    BOOL (*equal)(id, const void *, const void *);
    void (*kretain)(id, const void *), (*krelease)(id, void *), (*vretain)(id, const void *), (*vrelease)(id, void *);
    NSString *(*kdescribe)(id, const void *), *(*vdescribe)(id, const void *);
    const void *marker;
    pnode **buckets;
    NSUInteger nbuckets, count;
} ptable;
static NSUInteger pt_hash(ptable *t, id owner, const void *k) { return t->hash ? t->hash(owner, k) : ptr_hash(owner, k); }
static BOOL pt_equal(ptable *t, id owner, const void *a, const void *b) { return t->equal ? t->equal(owner, a, b) : a == b; }
static void pt_init(ptable *t, NSUInteger capacity) {
    t->nbuckets = 16; while (t->nbuckets < capacity) t->nbuckets *= 2;
    t->buckets = calloc(t->nbuckets, sizeof(pnode *)); t->count = 0;
}
static pnode *pt_find(ptable *t, id owner, const void *k) {
    for (pnode *n = t->buckets[pt_hash(t, owner, k) % t->nbuckets]; n; n = n->next) if (pt_equal(t, owner, n->key, k)) return n;
    return NULL;
}
static void pt_grow(ptable *t, id owner) {
    NSUInteger nb = t->nbuckets * 2;
    pnode **b = calloc(nb, sizeof(pnode *));
    for (NSUInteger i = 0; i < t->nbuckets; i++)
        for (pnode *n = t->buckets[i], *next; n; n = next) { next = n->next; NSUInteger h = pt_hash(t, owner, n->key) % nb; n->next = b[h]; b[h] = n; }
    free(t->buckets); t->buckets = b; t->nbuckets = nb;
}
/* insert or replace; returns the existing node when `ifAbsent` and the key is there */
static pnode *pt_put(ptable *t, id owner, const void *k, const void *v, BOOL ifAbsent) {
    if (t->marker && k == t->marker) [NSException raise:NSInvalidArgumentException format:@"the table's not-a-key marker cannot be a key"];
    pnode *n = pt_find(t, owner, k);
    if (n && ifAbsent) return n;
    if (t->kretain) t->kretain(owner, k);
    if (t->vretain) t->vretain(owner, v);
    if (n) {
        if (t->krelease) t->krelease(owner, n->key);
        if (t->vrelease) t->vrelease(owner, n->value);
        n->key = (void *)k; n->value = (void *)v;
        return NULL;
    }
    if (t->count >= t->nbuckets) pt_grow(t, owner);
    n = malloc(sizeof *n); n->key = (void *)k; n->value = (void *)v;
    NSUInteger h = pt_hash(t, owner, k) % t->nbuckets; n->next = t->buckets[h]; t->buckets[h] = n;
    t->count++;
    return NULL;
}
static void pt_remove(ptable *t, id owner, const void *k) {
    pnode **pp = &t->buckets[pt_hash(t, owner, k) % t->nbuckets];
    for (pnode *n = *pp; n; pp = &n->next, n = *pp)
        if (pt_equal(t, owner, n->key, k)) {
            *pp = n->next; t->count--;
            if (t->krelease) t->krelease(owner, n->key);
            if (t->vrelease) t->vrelease(owner, n->value);
            free(n);
            return;
        }
}
static void pt_reset(ptable *t, id owner) {
    for (NSUInteger i = 0; i < t->nbuckets; i++) {
        for (pnode *n = t->buckets[i], *next; n; n = next) {
            next = n->next;
            if (t->krelease) t->krelease(owner, n->key);
            if (t->vrelease) t->vrelease(owner, n->value);
            free(n);
        }
        t->buckets[i] = NULL;
    }
    t->count = 0;
}
/* every node, in table order */
static NSArray<NSValue *> *pt_nodes(ptable *t) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:t->count];
    for (NSUInteger i = 0; i < t->nbuckets; i++) for (pnode *n = t->buckets[i]; n; n = n->next) [a addObject:[NSValue valueWithPointer:n]];
    return a;
}

/* NSCreateMapTable's tables: an NSMapTable whose keys and values are raw pointers */
@interface __IsimCMapTable : NSMapTable { @public ptable _t; NSMapTableKeyCallBacks _kc; NSMapTableValueCallBacks _vc; }
@end
@implementation __IsimCMapTable
- (void)dealloc { pt_reset(&_t, self); free(_t.buckets); }
- (id)objectForKey:(id)key { pnode *n = pt_find(&_t, self, (__bridge void *)key); return n ? (__bridge id)n->value : nil; }
- (void)setObject:(id)obj forKey:(id)key { pt_put(&_t, self, (__bridge void *)key, (__bridge void *)obj, NO); }
- (void)removeObjectForKey:(id)key { pt_remove(&_t, self, (__bridge void *)key); }
- (NSUInteger)count { return _t.count; }
- (void)removeAllObjects { pt_reset(&_t, self); }
- (NSEnumerator *)keyEnumerator {
    NSMutableArray *a = [NSMutableArray array];
    for (NSValue *v in pt_nodes(&_t)) [a addObject:[NSValue valueWithPointer:((pnode *)v.pointerValue)->key]];
    return a.objectEnumerator;
}
- (NSEnumerator *)objectEnumerator {
    NSMutableArray *a = [NSMutableArray array];
    for (NSValue *v in pt_nodes(&_t)) [a addObject:[NSValue valueWithPointer:((pnode *)v.pointerValue)->value]];
    return a.objectEnumerator;
}
- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSValue *v in pt_nodes(&_t)) d[[NSValue valueWithPointer:((pnode *)v.pointerValue)->key]] = [NSValue valueWithPointer:((pnode *)v.pointerValue)->value];
    return d;
}
- (id)copyWithZone:(NSZone *)zone { return (__bridge_transfer id)(__bridge void *)NSCopyMapTableWithZone(self, zone); }
- (NSString *)description { return NSStringFromMapTable(self); }
@end

/* NSCreateHashTable's tables: an NSHashTable of raw pointers */
@interface __IsimCHashTable : NSHashTable { @public ptable _t; NSHashTableCallBacks _cb; }
@end
@implementation __IsimCHashTable
- (void)dealloc { pt_reset(&_t, self); free(_t.buckets); }
- (id)member:(id)o { pnode *n = pt_find(&_t, self, (__bridge void *)o); return n ? (__bridge id)n->key : nil; }
- (void)addObject:(id)o { pt_put(&_t, self, (__bridge void *)o, NULL, NO); }
- (void)removeObject:(id)o { pt_remove(&_t, self, (__bridge void *)o); }
- (NSUInteger)count { return _t.count; }
- (void)removeAllObjects { pt_reset(&_t, self); }
- (BOOL)containsObject:(id)o { return pt_find(&_t, self, (__bridge void *)o) != NULL; }
- (NSArray *)allObjects {
    NSMutableArray *a = [NSMutableArray array];
    for (NSValue *v in pt_nodes(&_t)) [a addObject:[NSValue valueWithPointer:((pnode *)v.pointerValue)->key]];
    return a;
}
- (NSEnumerator *)objectEnumerator { return self.allObjects.objectEnumerator; }
- (id)copyWithZone:(NSZone *)zone { return (__bridge_transfer id)(__bridge void *)NSCopyHashTableWithZone(self, zone); }
- (NSString *)description { return NSStringFromHashTable(self); }
@end

static __IsimCMapTable *CM(NSMapTable *t) { return [t isKindOfClass:[__IsimCMapTable class]] ? (__IsimCMapTable *)t : nil; }
static __IsimCHashTable *CH(NSHashTable *t) { return [t isKindOfClass:[__IsimCHashTable class]] ? (__IsimCHashTable *)t : nil; }

NSMapTable *NSCreateMapTableWithZone(NSMapTableKeyCallBacks kc, NSMapTableValueCallBacks vc, NSUInteger capacity, NSZone *zone) {
    __IsimCMapTable *m = [[__IsimCMapTable alloc] initWithKeyOptions:NSPointerFunctionsOpaqueMemory valueOptions:NSPointerFunctionsOpaqueMemory capacity:0];
    m->_kc = kc; m->_vc = vc;
    m->_t.hash = (void *)kc.hash; m->_t.equal = (void *)kc.isEqual; m->_t.kretain = (void *)kc.retain; m->_t.krelease = (void *)kc.release;
    m->_t.kdescribe = (void *)kc.describe; m->_t.marker = kc.notAKeyMarker;
    m->_t.vretain = (void *)vc.retain; m->_t.vrelease = (void *)vc.release; m->_t.vdescribe = (void *)vc.describe;
    pt_init(&m->_t, capacity);
    return (__bridge NSMapTable *)CFBridgingRetain(m);              /* (returned retained, freed with NSFreeMapTable) */
}
NSMapTable *NSCreateMapTable(NSMapTableKeyCallBacks kc, NSMapTableValueCallBacks vc, NSUInteger capacity) { return NSCreateMapTableWithZone(kc, vc, capacity, NULL); }
void NSFreeMapTable(NSMapTable *t) { NSResetMapTable(t); CFRelease((__bridge CFTypeRef)t); }
void NSResetMapTable(NSMapTable *t) { [t removeAllObjects]; }
BOOL NSCompareMapTables(NSMapTable *a, NSMapTable *b) {
    if (NSCountMapTable(a) != NSCountMapTable(b)) return NO;
    NSMapEnumerator e = NSEnumerateMapTable(a);
    void *k, *v; BOOL same = YES;
    while (same && NSNextMapEnumeratorPair(&e, &k, &v)) { void *ok, *ov; same = NSMapMember(b, k, &ok, &ov) && ov == v; }
    NSEndMapTableEnumeration(&e);
    return same;
}
NSMapTable *NSCopyMapTableWithZone(NSMapTable *t, NSZone *zone) {
    __IsimCMapTable *c = CM(t);
    if (!c) return (__bridge NSMapTable *)CFBridgingRetain([t copy]);
    NSMapTable *n = NSCreateMapTableWithZone(c->_kc, c->_vc, c->_t.count, zone);
    for (NSValue *v in pt_nodes(&c->_t)) NSMapInsert(n, ((pnode *)v.pointerValue)->key, ((pnode *)v.pointerValue)->value);
    return n;
}
BOOL NSMapMember(NSMapTable *t, const void *key, void **originalKey, void **value) {
    __IsimCMapTable *c = CM(t);
    if (c) {
        pnode *n = pt_find(&c->_t, c, key);
        if (!n) return NO;
        if (originalKey) *originalKey = n->key;
        if (value) *value = n->value;
        return YES;
    }
    id v = [t objectForKey:(__bridge id)key];
    if (!v) return NO;
    for (id k in t) if (k == (__bridge id)key || [k isEqual:(__bridge id)key]) { if (originalKey) *originalKey = (__bridge void *)k; break; }
    if (value) *value = (__bridge void *)v;
    return YES;
}
void *NSMapGet(NSMapTable *t, const void *key) {
    __IsimCMapTable *c = CM(t);
    if (c) { pnode *n = pt_find(&c->_t, c, key); return n ? n->value : NULL; }
    return (__bridge void *)[t objectForKey:(__bridge id)key];
}
void NSMapInsert(NSMapTable *t, const void *key, const void *value) {
    __IsimCMapTable *c = CM(t);
    if (c) pt_put(&c->_t, c, key, value, NO);
    else [t setObject:(__bridge id)value forKey:(__bridge id)key];
}
void NSMapInsertKnownAbsent(NSMapTable *t, const void *key, const void *value) {
    if (NSMapMember(t, key, NULL, NULL)) [NSException raise:NSInvalidArgumentException format:@"NSMapInsertKnownAbsent: the key is already in the table"];
    NSMapInsert(t, key, value);
}
void *NSMapInsertIfAbsent(NSMapTable *t, const void *key, const void *value) {
    void *existing;
    if (NSMapMember(t, key, &existing, NULL)) return existing;
    NSMapInsert(t, key, value);
    return NULL;
}
void NSMapRemove(NSMapTable *t, const void *key) {
    __IsimCMapTable *c = CM(t);
    if (c) pt_remove(&c->_t, c, key); else [t removeObjectForKey:(__bridge id)key];
}
/* an enumerator holds a snapshot: (key, value) pairs */
NSMapEnumerator NSEnumerateMapTable(NSMapTable *t) {
    NSMutableArray *pairs = [NSMutableArray array];
    __IsimCMapTable *c = CM(t);
    if (c) for (NSValue *v in pt_nodes(&c->_t)) [pairs addObject:@[[NSValue valueWithPointer:((pnode *)v.pointerValue)->key], [NSValue valueWithPointer:((pnode *)v.pointerValue)->value]]];
    else for (id k in t.keyEnumerator.allObjects) [pairs addObject:@[[NSValue valueWithPointer:(__bridge void *)k], [NSValue valueWithPointer:(__bridge void *)[t objectForKey:k]]]];
    NSMapEnumerator e = { 0, pairs.count, (void *)CFBridgingRetain(@[pairs, t]) };
    return e;
}
BOOL NSNextMapEnumeratorPair(NSMapEnumerator *e, void **key, void **value) {
    if (!e->_bs || e->_pi >= e->_si) return NO;
    NSArray *pair = ((__bridge NSArray *)e->_bs)[0][e->_pi++];
    if (key) *key = [pair[0] pointerValue];
    if (value) *value = [pair[1] pointerValue];
    return YES;
}
void NSEndMapTableEnumeration(NSMapEnumerator *e) { if (e->_bs) CFRelease(e->_bs); e->_bs = NULL; }
NSUInteger NSCountMapTable(NSMapTable *t) { return t.count; }
NSString *NSStringFromMapTable(NSMapTable *t) {
    __IsimCMapTable *c = CM(t);
    NSMutableString *s = [NSMutableString string];
    NSMapEnumerator e = NSEnumerateMapTable(t);
    void *k, *v;
    while (NSNextMapEnumeratorPair(&e, &k, &v)) {
        NSString *ks = c ? (c->_t.kdescribe ? c->_t.kdescribe(t, k) : ptr_describe(t, k)) : [(__bridge id)k description];
        NSString *vs = c ? (c->_t.vdescribe ? c->_t.vdescribe(t, v) : ptr_describe(t, v)) : [(__bridge id)v description];
        [s appendFormat:@"%@ = %@;\n", ks, vs];
    }
    NSEndMapTableEnumeration(&e);
    return s;
}
NSArray *NSAllMapTableKeys(NSMapTable *t) {
    NSMutableArray *a = [NSMutableArray array];
    NSMapEnumerator e = NSEnumerateMapTable(t);
    void *k;
    while (NSNextMapEnumeratorPair(&e, &k, NULL)) [a addObject:CM(t) ? [NSValue valueWithPointer:k] : (__bridge id)k];
    NSEndMapTableEnumeration(&e);
    return a;
}
NSArray *NSAllMapTableValues(NSMapTable *t) {
    NSMutableArray *a = [NSMutableArray array];
    NSMapEnumerator e = NSEnumerateMapTable(t);
    void *v;
    while (NSNextMapEnumeratorPair(&e, NULL, &v)) [a addObject:CM(t) ? [NSValue valueWithPointer:v] : (__bridge id)v];
    NSEndMapTableEnumeration(&e);
    return a;
}

NSHashTable *NSCreateHashTableWithZone(NSHashTableCallBacks cb, NSUInteger capacity, NSZone *zone) {
    __IsimCHashTable *h = [[__IsimCHashTable alloc] initWithOptions:NSPointerFunctionsOpaqueMemory capacity:0];
    h->_cb = cb;
    h->_t.hash = (void *)cb.hash; h->_t.equal = (void *)cb.isEqual; h->_t.kretain = (void *)cb.retain; h->_t.krelease = (void *)cb.release;
    h->_t.kdescribe = (void *)cb.describe;
    pt_init(&h->_t, capacity);
    return (__bridge NSHashTable *)CFBridgingRetain(h);             /* (returned retained, freed with NSFreeHashTable) */
}
NSHashTable *NSCreateHashTable(NSHashTableCallBacks cb, NSUInteger capacity) { return NSCreateHashTableWithZone(cb, capacity, NULL); }
void NSFreeHashTable(NSHashTable *t) { NSResetHashTable(t); CFRelease((__bridge CFTypeRef)t); }
void NSResetHashTable(NSHashTable *t) { [t removeAllObjects]; }
BOOL NSCompareHashTables(NSHashTable *a, NSHashTable *b) {
    if (NSCountHashTable(a) != NSCountHashTable(b)) return NO;
    NSHashEnumerator e = NSEnumerateHashTable(a);
    BOOL same = YES; void *p;
    while (same && (p = NSNextHashEnumeratorItem(&e))) same = NSHashGet(b, p) != NULL;
    NSEndHashTableEnumeration(&e);
    return same;
}
NSHashTable *NSCopyHashTableWithZone(NSHashTable *t, NSZone *zone) {
    __IsimCHashTable *c = CH(t);
    if (!c) return (__bridge NSHashTable *)CFBridgingRetain([t copy]);
    NSHashTable *n = NSCreateHashTableWithZone(c->_cb, c->_t.count, zone);
    for (NSValue *v in pt_nodes(&c->_t)) NSHashInsert(n, ((pnode *)v.pointerValue)->key);
    return n;
}
void *NSHashGet(NSHashTable *t, const void *p) {
    __IsimCHashTable *c = CH(t);
    if (c) { pnode *n = pt_find(&c->_t, c, p); return n ? n->key : NULL; }
    return (__bridge void *)[t member:(__bridge id)p];
}
void NSHashInsert(NSHashTable *t, const void *p) {
    __IsimCHashTable *c = CH(t);
    if (c) pt_put(&c->_t, c, p, NULL, NO); else [t addObject:(__bridge id)p];
}
void NSHashInsertKnownAbsent(NSHashTable *t, const void *p) {
    if (NSHashGet(t, p)) [NSException raise:NSInvalidArgumentException format:@"NSHashInsertKnownAbsent: the item is already in the table"];
    NSHashInsert(t, p);
}
void *NSHashInsertIfAbsent(NSHashTable *t, const void *p) {
    void *existing = NSHashGet(t, p);
    if (existing) return existing;
    NSHashInsert(t, p);
    return NULL;
}
void NSHashRemove(NSHashTable *t, const void *p) {
    __IsimCHashTable *c = CH(t);
    if (c) pt_remove(&c->_t, c, p); else [t removeObject:(__bridge id)p];
}
NSHashEnumerator NSEnumerateHashTable(NSHashTable *t) {
    NSMutableArray *items = [NSMutableArray array];
    __IsimCHashTable *c = CH(t);
    if (c) for (NSValue *v in pt_nodes(&c->_t)) [items addObject:[NSValue valueWithPointer:((pnode *)v.pointerValue)->key]];
    else for (id o in t.allObjects) [items addObject:[NSValue valueWithPointer:(__bridge void *)o]];
    NSHashEnumerator e = { 0, items.count, (void *)CFBridgingRetain(@[items, t]) };
    return e;
}
void *NSNextHashEnumeratorItem(NSHashEnumerator *e) {
    if (!e->_bs || e->_pi >= e->_si) return NULL;
    return [((__bridge NSArray *)e->_bs)[0][e->_pi++] pointerValue];
}
void NSEndHashTableEnumeration(NSHashEnumerator *e) { if (e->_bs) CFRelease(e->_bs); e->_bs = NULL; }
NSUInteger NSCountHashTable(NSHashTable *t) { return t.count; }
NSString *NSStringFromHashTable(NSHashTable *t) {
    __IsimCHashTable *c = CH(t);
    NSMutableString *s = [NSMutableString string];
    NSHashEnumerator e = NSEnumerateHashTable(t);
    void *p;
    while ((p = NSNextHashEnumeratorItem(&e)))
        [s appendFormat:@"%@;\n", c ? (c->_t.kdescribe ? c->_t.kdescribe(t, p) : ptr_describe(t, p)) : [(__bridge id)p description]];
    NSEndHashTableEnumeration(&e);
    return s;
}
NSArray *NSAllHashTableObjects(NSHashTable *t) {
    if (!CH(t)) return t.allObjects;
    return CH(t).allObjects;
}

/* ================= NSURLConnection ================= */
extern NSArray *isim_url_protocol_registered(void);

/* an authentication challenge's sender: answers the session's challenge */
@interface __IsimConnectionChallengeSender : NSObject <NSURLAuthenticationChallengeSender>
@property (copy) void (^completion)(NSURLSessionAuthChallengeDisposition, NSURLCredential *);
@end
@implementation __IsimConnectionChallengeSender
- (void)answer:(NSURLSessionAuthChallengeDisposition)d credential:(NSURLCredential *)c {
    void (^h)(NSURLSessionAuthChallengeDisposition, NSURLCredential *) = self.completion;
    self.completion = nil;
    if (h) h(d, c);
}
- (void)useCredential:(NSURLCredential *)credential forAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self answer:NSURLSessionAuthChallengeUseCredential credential:credential];
}
- (void)continueWithoutCredentialForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self answer:NSURLSessionAuthChallengeUseCredential credential:nil];
}
- (void)cancelAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge { [self answer:NSURLSessionAuthChallengeCancelAuthenticationChallenge credential:nil]; }
- (void)performDefaultHandlingForAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self answer:NSURLSessionAuthChallengePerformDefaultHandling credential:nil];
}
- (void)rejectProtectionSpaceAndContinueWithChallenge:(NSURLAuthenticationChallenge *)challenge {
    [self answer:NSURLSessionAuthChallengeRejectProtectionSpace credential:nil];
}
@end

@interface NSURLConnection () <NSURLSessionDataDelegate, NSURLSessionDownloadDelegate>
@end
@implementation NSURLConnection {
    id _delegate;                                    /* retained until the connection finishes, as on iOS */
    NSURLRequest *_original, *_current;
    NSMutableArray<NSArray *> *_schedules;           /* (run loop, mode) */
    NSOperationQueue *_delegateQueue;
    NSURLSession *_session;
    NSURLSessionTask *_task;
    BOOL _started, _done;
}
+ (BOOL)canHandleRequest:(NSURLRequest *)request {
    NSString *scheme = request.URL.scheme.lowercaseString;
    if ([@[@"http", @"https", @"file", @"data"] containsObject:scheme ?: @""]) return YES;
    for (Class c in isim_url_protocol_registered()) if ([c canInitWithRequest:request]) return YES;
    return NO;
}
+ (NSURLConnection *)connectionWithRequest:(NSURLRequest *)request delegate:(id)delegate { return [[self alloc] initWithRequest:request delegate:delegate]; }
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id)delegate { return [self initWithRequest:request delegate:delegate startImmediately:YES]; }
- (instancetype)initWithRequest:(NSURLRequest *)request delegate:(id)delegate startImmediately:(BOOL)start {
    if (!request) return nil;
    if ((self = [super init])) {
        _original = [request copy]; _current = _original; _delegate = delegate;
        _schedules = [NSMutableArray array];
        if (start) [self start];
    }
    return self;
}
- (NSURLRequest *)originalRequest { return _original; }
- (NSURLRequest *)currentRequest { @synchronized (self) { return _current; } }
- (void)scheduleInRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode {
    @synchronized (self) {
        for (NSArray *s in _schedules) if (s[0] == rl && [s[1] isEqualToString:mode]) return;
        [_schedules addObject:@[rl, mode]];
    }
}
- (void)unscheduleFromRunLoop:(NSRunLoop *)rl forMode:(NSRunLoopMode)mode {
    @synchronized (self) {
        for (NSUInteger i = 0; i < _schedules.count; i++)
            if (_schedules[i][0] == rl && [_schedules[i][1] isEqualToString:mode]) { [_schedules removeObjectAtIndex:i]; break; }
    }
}
- (void)setDelegateQueue:(NSOperationQueue *)queue { @synchronized (self) { _delegateQueue = queue; } }
/* runs `block` where the delegate is called: its queue, or the first of its run loops to run it; `wait` blocks the
   session's queue until it has run (callbacks that answer) */
- (void)_deliver:(void (^)(void))block wait:(BOOL)wait {
    NSOperationQueue *q; NSArray *schedules;
    @synchronized (self) { q = _delegateQueue; schedules = [_schedules copy]; }
    dispatch_semaphore_t done = wait ? dispatch_semaphore_create(0) : nil;
    __block BOOL ran = NO;
    void (^once)(void) = ^{
        @synchronized (self) { if (ran) return; ran = YES; }
        block();
        if (done) dispatch_semaphore_signal(done);
    };
    if (q) [q addOperationWithBlock:once];
    else if (schedules.count) for (NSArray *s in schedules) [(NSRunLoop *)s[0] performInModes:@[s[1]] block:once];
    else once();
    if (done) dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
}
- (void)start {
    @synchronized (self) {
        if (_started) return;
        _started = YES;
        if (!_schedules.count && !_delegateQueue) [_schedules addObject:@[NSRunLoop.currentRunLoop, NSDefaultRunLoopMode]];
    }
    [self _deliver:^{
        id d = self->_delegate;
        if ([d respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)]) {
            NSURLRequest *r = [d connection:self willSendRequest:self->_original redirectResponse:nil];
            if (!r) { [self _finish]; return; }
            @synchronized (self) { self->_current = [r copy]; }
        }
        [self _startTask];
    } wait:NO];
}
- (void)_startTask {
    NSOperationQueue *sq = [NSOperationQueue new];
    sq.maxConcurrentOperationCount = 1;
    _session = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration delegate:self delegateQueue:sq];
    BOOL download = [_delegate respondsToSelector:@selector(connectionDidFinishDownloading:destinationURL:)];
    NSURLRequest *r = self.currentRequest;
    _task = download ? [_session downloadTaskWithRequest:r] : [_session dataTaskWithRequest:r];
    [_task resume];
}
- (void)cancel {
    @synchronized (self) { if (_done) return; _done = YES; }
    [_task cancel];
    [_session invalidateAndCancel];
    _delegate = nil;
}
- (void)_finish {
    @synchronized (self) { _done = YES; }
    [_session finishTasksAndInvalidate];
    _delegate = nil;
}
- (BOOL)_cancelled { @synchronized (self) { return _done; } }

/* ---- the session's callbacks, passed on ---- */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response
        newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest *))completionHandler {
    __block NSURLRequest *next = request;
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:willSendRequest:redirectResponse:)])
        [self _deliver:^{ next = [d connection:self willSendRequest:request redirectResponse:response]; } wait:YES];
    if (next) @synchronized (self) { _current = [next copy]; }
    completionHandler(next);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
 completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    id d = _delegate;
    BOOL modern = [d respondsToSelector:@selector(connection:willSendRequestForAuthenticationChallenge:)];
    BOOL old = [d respondsToSelector:@selector(connection:didReceiveAuthenticationChallenge:)];
    if (!modern && !old) { completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil); return; }
    __IsimConnectionChallengeSender *sender = [__IsimConnectionChallengeSender new];
    sender.completion = completionHandler;
    NSURLAuthenticationChallenge *c = [[NSURLAuthenticationChallenge alloc] initWithAuthenticationChallenge:challenge sender:sender];
    [self _deliver:^{
        if (modern) [d connection:self willSendRequestForAuthenticationChallenge:c];
        else if ([d respondsToSelector:@selector(connection:canAuthenticateAgainstProtectionSpace:)] &&
                 ![d connection:self canAuthenticateAgainstProtectionSpace:c.protectionSpace])
            [sender performDefaultHandlingForAuthenticationChallenge:c];
        else [d connection:self didReceiveAuthenticationChallenge:c];
    } wait:NO];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task needNewBodyStream:(void (^)(NSInputStream *))completionHandler {
    __block NSInputStream *s = nil;
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:needNewBodyStream:)])
        [self _deliver:^{ s = [d connection:self needNewBodyStream:task.currentRequest]; } wait:YES];
    completionHandler(s);
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didSendBodyData:(int64_t)sent totalBytesSent:(int64_t)total
    totalBytesExpectedToSend:(int64_t)expected {
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:didSendBodyData:totalBytesWritten:totalBytesExpectedToWrite:)])
        [self _deliver:^{ if (![self _cancelled]) [d connection:self didSendBodyData:(NSInteger)sent totalBytesWritten:(NSInteger)total totalBytesExpectedToWrite:(NSInteger)expected]; } wait:NO];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:didReceiveResponse:)])
        [self _deliver:^{ if (![self _cancelled]) [d connection:self didReceiveResponse:response]; } wait:NO];
    completionHandler(NSURLSessionResponseAllow);
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task didReceiveData:(NSData *)data {
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:didReceiveData:)])
        [self _deliver:^{ if (![self _cancelled]) [d connection:self didReceiveData:data]; } wait:NO];
}
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)task willCacheResponse:(NSCachedURLResponse *)proposed
 completionHandler:(void (^)(NSCachedURLResponse *))completionHandler {
    __block NSCachedURLResponse *r = proposed;
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:willCacheResponse:)])
        [self _deliver:^{ r = [d connection:self willCacheResponse:proposed]; } wait:YES];
    completionHandler(r);
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didWriteData:(int64_t)written
 totalBytesWritten:(int64_t)total totalBytesExpectedToWrite:(int64_t)expected {
    id d = _delegate;
    if ([d respondsToSelector:@selector(connection:didWriteData:totalBytesWritten:expectedTotalBytes:)])
        [self _deliver:^{ if (![self _cancelled]) [d connection:self didWriteData:written totalBytesWritten:total expectedTotalBytes:expected]; } wait:NO];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)task didFinishDownloadingToURL:(NSURL *)location {
    id d = _delegate;
    [self _deliver:^{ if (![self _cancelled]) [d connectionDidFinishDownloading:self destinationURL:location]; } wait:YES];   /* (the file goes after) */
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    id d = _delegate;
    if (!d || [self _cancelled]) { [self _finish]; return; }
    [self _deliver:^{
        if (error) { if ([d respondsToSelector:@selector(connection:didFailWithError:)]) [d connection:self didFailWithError:error]; }
        else if ([d respondsToSelector:@selector(connectionDidFinishLoading:)]) [d connectionDidFinishLoading:self];
        [self _finish];
    } wait:NO];
}
@end

@implementation NSURLConnection (NSURLConnectionSynchronousLoading)
+ (NSData *)sendSynchronousRequest:(NSURLRequest *)request returningResponse:(NSURLResponse **)response error:(NSError **)error {
    __block NSData *data = nil; __block NSURLResponse *resp = nil; __block NSError *err = nil;
    dispatch_semaphore_t done = dispatch_semaphore_create(0);
    NSURLSession *s = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    [[s dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        data = d; resp = r; err = e;
        dispatch_semaphore_signal(done);
    }] resume];
    dispatch_semaphore_wait(done, DISPATCH_TIME_FOREVER);
    [s finishTasksAndInvalidate];
    if (response) *response = resp;
    if (error) *error = err;
    return err ? nil : (data ?: [NSData data]);
}
@end
@implementation NSURLConnection (NSURLConnectionQueuedLoading)
+ (void)sendAsynchronousRequest:(NSURLRequest *)request queue:(NSOperationQueue *)queue
              completionHandler:(void (^)(NSURLResponse *, NSData *, NSError *))handler {
    NSURLSession *s = [NSURLSession sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration];
    [[s dataTaskWithRequest:request completionHandler:^(NSData *d, NSURLResponse *r, NSError *e) {
        [queue addOperationWithBlock:^{ handler(r, e ? nil : d, e); }];
    }] resume];
    [s finishTasksAndInvalidate];
}
@end
