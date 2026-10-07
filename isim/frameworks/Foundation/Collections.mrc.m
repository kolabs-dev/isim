/* isim Foundation: NSValue/NSNumber, NSArray, NSDictionary, NSSet, NSNull (MRC). */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include <stdlib.h>
#include <string.h>
#include "isim_foundation.h"

static void throw_range(const char *where, NSUInteger idx, NSUInteger count) {
    [NSException raise:NSRangeException format:@"*** %s: index %lu beyond bounds [0 .. %ld]", where, (unsigned long)idx, (long)count - 1];
}
static void throw_nil(const char *where) {
    [NSException raise:NSInvalidArgumentException format:@"*** %s: attempt to insert nil object", where];
}

/* ================= NSValue / NSNumber ================= */
enum { V_PTR, V_NONRET, V_RANGE, V_POINT, V_SIZE, V_RECT };
@implementation NSValue { @public int _kind; union { const void *p; NSRange r; CGPoint pt; CGSize sz; CGRect rect; } _v; }
static NSValue *mkval(int kind) { NSValue *v = [[[NSValue alloc] init] autorelease]; v->_kind = kind; return v; }
+ (NSValue *)valueWithPointer:(const void *)p { NSValue *v = mkval(V_PTR); v->_v.p = p; return v; }
+ (NSValue *)valueWithNonretainedObject:(id)o { NSValue *v = mkval(V_NONRET); v->_v.p = o; return v; }
+ (NSValue *)valueWithRange:(NSRange)r { NSValue *v = mkval(V_RANGE); v->_v.r = r; return v; }
+ (NSValue *)valueWithCGPoint:(CGPoint)p { NSValue *v = mkval(V_POINT); v->_v.pt = p; return v; }
+ (NSValue *)valueWithCGSize:(CGSize)s { NSValue *v = mkval(V_SIZE); v->_v.sz = s; return v; }
+ (NSValue *)valueWithCGRect:(CGRect)r { NSValue *v = mkval(V_RECT); v->_v.rect = r; return v; }
- (void *)pointerValue { return (void *)_v.p; }
- (id)nonretainedObjectValue { return (id)_v.p; }
- (NSRange)rangeValue { return _v.r; }
- (CGPoint)CGPointValue { return _v.pt; }
- (CGSize)CGSizeValue { return _v.sz; }
- (CGRect)CGRectValue { return _v.rect; }
- (const char *)objCType {
    switch (_kind) {
    case V_RANGE: return "{_NSRange=QQ}"; case V_POINT: return "{CGPoint=dd}"; case V_SIZE: return "{CGSize=dd}";
    case V_RECT: return "{CGRect={CGPoint=dd}{CGSize=dd}}"; case V_NONRET: return "@"; default: return "^v";
    }
}
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
- (BOOL)isEqualToValue:(NSValue *)o { return [o isKindOfClass:[NSValue class]] && o->_kind == _kind && !memcmp(&_v, &o->_v, sizeof _v); }
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSValue class]] && [self isEqualToValue:o]; }
- (NSUInteger)hash { return (NSUInteger)_v.p ^ _kind; }
- (NSString *)description {
    switch (_kind) {
    case V_RANGE: return NSStringFromRange(_v.r);
    case V_POINT: return [NSString stringWithFormat:@"NSPoint: %@", NSStringFromCGPoint(_v.pt)];
    case V_SIZE: return [NSString stringWithFormat:@"NSSize: %@", NSStringFromCGSize(_v.sz)];
    case V_RECT: return [NSString stringWithFormat:@"NSRect: %@", NSStringFromCGRect(_v.rect)];
    default: return [NSString stringWithFormat:@"<%p>", _v.p];
    }
}
@end

/* NSNumber is a class cluster: every method reads the value through the -_isim_getNumber: primitive. NSNumber
 * instances keep it in their ivars; the constant subclasses for clang's static literals (NSConstantIntegerNumber,
 * NSConstantDoubleNumber, NSConstantFloatNumber) and the CFBoolean singletons (__NSCFBoolean) have their own layouts
 * and override the primitive and -objCType (ConstantLiterals.mrc.m). */
@implementation NSNumber { int _t; union { long long i; unsigned long long u; double d; } _n; }
static NSNumber *mknum(int t) { NSNumber *n = class_createInstance([NSNumber class], 0); n->_t = t; return n; }
static inline isim_numv numv(NSNumber *n) { isim_numv v = { 0 }; [n _isim_getNumber:&v]; return v; }
#define NUMI(sel, type) + (NSNumber *)sel(type)v { NSNumber *n = mknum(ISIM_NUM_INT); n->_n.i = v; return [n autorelease]; }
#define NUMU(sel, type) + (NSNumber *)sel(type)v { NSNumber *n = mknum(ISIM_NUM_UINT); n->_n.u = v; return [n autorelease]; }
NUMI(numberWithChar:, char) NUMU(numberWithUnsignedChar:, unsigned char) NUMI(numberWithShort:, short)
NUMU(numberWithUnsignedShort:, unsigned short) NUMI(numberWithInt:, int) NUMU(numberWithUnsignedInt:, unsigned int)
NUMI(numberWithLong:, long) NUMU(numberWithUnsignedLong:, unsigned long) NUMI(numberWithLongLong:, long long)
NUMU(numberWithUnsignedLongLong:, unsigned long long) NUMI(numberWithInteger:, NSInteger) NUMU(numberWithUnsignedInteger:, NSUInteger)
+ (NSNumber *)numberWithFloat:(float)v { NSNumber *n = mknum(ISIM_NUM_DBL); n->_n.d = v; return [n autorelease]; }
+ (NSNumber *)numberWithDouble:(double)v { NSNumber *n = mknum(ISIM_NUM_DBL); n->_n.d = v; return [n autorelease]; }
/* booleans are the kCFBooleanTrue/False singletons, as on iOS (@YES == [NSNumber numberWithBool:YES]) */
+ (NSNumber *)numberWithBool:(BOOL)v { return isim_bool_number(v); }
- (instancetype)initWithInt:(int)v { _t = ISIM_NUM_INT; _n.i = v; return self; }
- (instancetype)initWithInteger:(NSInteger)v { _t = ISIM_NUM_INT; _n.i = v; return self; }
- (instancetype)initWithDouble:(double)v { _t = ISIM_NUM_DBL; _n.d = v; return self; }
- (instancetype)initWithBool:(BOOL)v {
    if (object_getClass(self) != [NSNumber class]) { _t = ISIM_NUM_BOOL; _n.i = v ? 1 : 0; return self; }   /* a subclass */
    [self release]; return isim_bool_number(v);
}
- (instancetype)initWithLongLong:(long long)v { _t = ISIM_NUM_INT; _n.i = v; return self; }
- (instancetype)initWithUnsignedLongLong:(unsigned long long)v { _t = ISIM_NUM_UINT; _n.u = v; return self; }
- (instancetype)initWithUnsignedInteger:(NSUInteger)v { _t = ISIM_NUM_UINT; _n.u = v; return self; }
- (instancetype)initWithFloat:(float)v { _t = ISIM_NUM_DBL; _n.d = v; return self; }
- (void)_isim_getNumber:(isim_numv *)v { v->t = _t; v->u = _n.u; }
- (long long)longLongValue { isim_numv v = numv(self); return v.t == ISIM_NUM_DBL ? (long long)v.d : v.i; }
- (unsigned long long)unsignedLongLongValue { isim_numv v = numv(self); return v.t == ISIM_NUM_DBL ? (unsigned long long)v.d : v.u; }
- (double)doubleValue { isim_numv v = numv(self); return v.t == ISIM_NUM_DBL ? v.d : v.t == ISIM_NUM_UINT ? (double)v.u : (double)v.i; }
- (char)charValue { return (char)[self longLongValue]; }
- (unsigned char)unsignedCharValue { return (unsigned char)[self longLongValue]; }
- (short)shortValue { return (short)[self longLongValue]; }
- (int)intValue { return (int)[self longLongValue]; }
- (unsigned int)unsignedIntValue { return (unsigned int)[self unsignedLongLongValue]; }
- (long)longValue { return (long)[self longLongValue]; }
- (unsigned long)unsignedLongValue { return (unsigned long)[self unsignedLongLongValue]; }
- (NSInteger)integerValue { return (NSInteger)[self longLongValue]; }
- (NSUInteger)unsignedIntegerValue { return (NSUInteger)[self unsignedLongLongValue]; }
- (float)floatValue { return (float)[self doubleValue]; }
- (BOOL)boolValue { isim_numv v = numv(self); return v.t == ISIM_NUM_DBL ? v.d != 0 : v.i != 0; }
- (NSString *)stringValue { return [self description]; }
- (NSString *)description {
    isim_numv v = numv(self);
    if (v.t == ISIM_NUM_DBL) {
        if ([self objCType][0] == 'f') {   /* float: shortest text that reads back as the same float */
            char b[40];
            for (int prec = 6; prec <= 9; prec++) { snprintf(b, sizeof b, "%.*g", prec, v.d); if ((float)strtod(b, NULL) == (float)v.d) break; }
            return [NSString stringWithUTF8String:b];
        }
        return [NSString stringWithFormat:@"%.17g", v.d];
    }
    if (v.t == ISIM_NUM_UINT) return [NSString stringWithFormat:@"%llu", v.u];
    return [NSString stringWithFormat:@"%lld", v.i];
}
static NSComparisonResult cmp_numv(isim_numv a, isim_numv b) {
    if (a.t == ISIM_NUM_DBL || b.t == ISIM_NUM_DBL) {
        double x = a.t == ISIM_NUM_DBL ? a.d : a.t == ISIM_NUM_UINT ? (double)a.u : (double)a.i;
        double y = b.t == ISIM_NUM_DBL ? b.d : b.t == ISIM_NUM_UINT ? (double)b.u : (double)b.i;
        return x < y ? NSOrderedAscending : x > y ? NSOrderedDescending : NSOrderedSame;
    }
    BOOL an = a.t != ISIM_NUM_UINT && a.i < 0, bn = b.t != ISIM_NUM_UINT && b.i < 0;   /* negative signed values */
    if (an != bn) return an ? NSOrderedAscending : NSOrderedDescending;
    if (an) return a.i < b.i ? NSOrderedAscending : a.i > b.i ? NSOrderedDescending : NSOrderedSame;
    return a.u < b.u ? NSOrderedAscending : a.u > b.u ? NSOrderedDescending : NSOrderedSame;
}
- (NSComparisonResult)compare:(NSNumber *)o { return cmp_numv(numv(self), numv(o)); }
- (BOOL)isEqualToNumber:(NSNumber *)o { return o == self || (o && cmp_numv(numv(self), numv(o)) == NSOrderedSame); }
- (BOOL)isEqualToValue:(NSValue *)o { return [o isKindOfClass:[NSNumber class]] && [self isEqualToNumber:(NSNumber *)o]; }
- (BOOL)_isim_isBool { return numv(self).t == ISIM_NUM_BOOL; }
- (const char *)objCType { int t = numv(self).t; return t == ISIM_NUM_DBL ? "d" : t == ISIM_NUM_UINT ? "Q" : t == ISIM_NUM_BOOL ? "c" : "q"; }
- (BOOL)isEqual:(id)o { return o == self || ([o isKindOfClass:[NSNumber class]] && [self isEqualToNumber:o]); }
- (NSUInteger)hash {
    isim_numv v = numv(self);
    if (v.t == ISIM_NUM_DBL) return v.d != (double)(long long)v.d ? (NSUInteger)(v.d * 2654435761.0) : (NSUInteger)(long long)v.d;
    return (NSUInteger)v.i;
}
- (id)copyWithZone:(NSZone *)z { return [self retain]; }
@end

/* ================= NSArray / NSMutableArray ================= */
/* NSEnumerator over a snapshot array */
@interface __NSArrayEnumerator : NSEnumerator { @public NSArray *_a; NSUInteger _i; BOOL _rev; }
@end
@implementation NSEnumerator
- (id)nextObject { return nil; }
- (NSArray *)allObjects { NSMutableArray *a = [NSMutableArray array]; for (id o; (o = [self nextObject]);) [a addObject:o]; return a; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    static unsigned long nomut;
    st->mutationsPtr = &nomut; st->itemsPtr = buf;
    NSUInteger n = 0;
    for (id o; n < len && (o = [self nextObject]);) buf[n++] = o;
    return n;
}
@end
@implementation __NSArrayEnumerator
- (id)nextObject {
    NSUInteger c = [_a count];
    if (_i >= c) return nil;
    id o = [_a objectAtIndex:_rev ? c - 1 - _i : _i]; _i++; return o;
}
- (void)dealloc { [_a release]; [super dealloc]; }
@end
static NSEnumerator *array_enum(NSArray *a, BOOL rev) {
    __NSArrayEnumerator *e = [[__NSArrayEnumerator alloc] init]; e->_a = [a copy]; e->_rev = rev; return [e autorelease];
}

/* _count and _items come first: clang's constant arrays (NSConstantArray: { isa, count, objects }) share this prefix,
 * so every read-only method below works on them too (ConstantLiterals.mrc.m). Keep the order. */
@implementation NSArray { @public NSUInteger _count; id *_items; NSUInteger _cap; unsigned long _mutations; }
+ (instancetype)array { return [[[self alloc] init] autorelease]; }
+ (instancetype)arrayWithObject:(id)o { return [[[self alloc] initWithObjects:&o count:1] autorelease]; }
+ (instancetype)arrayWithObjects:(const id *)objs count:(NSUInteger)n { return [[[self alloc] initWithObjects:objs count:n] autorelease]; }
+ (instancetype)arrayWithArray:(NSArray *)a { return [[[self alloc] initWithArray:a] autorelease]; }
+ (instancetype)arrayWithObjects:(id)first, ... {
    NSMutableArray *tmp = [NSMutableArray array];
    va_list ap; va_start(ap, first);
    for (id o = first; o; o = va_arg(ap, id)) [tmp addObject:o];
    va_end(ap);
    return [[[self alloc] initWithArray:tmp] autorelease];
}
- (instancetype)init { return [self initWithObjects:NULL count:0]; }
- (instancetype)initWithObjects:(const id *)objs count:(NSUInteger)n {
    _cap = n ? n : 4; _items = malloc(_cap * sizeof(id));
    for (NSUInteger i = 0; i < n; i++) { if (!objs[i]) throw_nil("-[NSArray initWithObjects:count:]"); _items[i] = [objs[i] retain]; }
    _count = n;
    return self;
}
- (instancetype)initWithObjects:(id)first, ... {
    NSMutableArray *tmp = [NSMutableArray array];
    va_list ap; va_start(ap, first);
    for (id o = first; o; o = va_arg(ap, id)) [tmp addObject:o];
    va_end(ap);
    return [self initWithArray:tmp];
}
- (instancetype)initWithArray:(NSArray *)a { return [self initWithObjects:a ? a->_items : NULL count:a ? a->_count : 0]; }
- (void)dealloc { for (NSUInteger i = 0; i < _count; i++) [_items[i] release]; free(_items); [super dealloc]; }
- (NSUInteger)count { return _count; }
- (id)objectAtIndex:(NSUInteger)i { if (i >= _count) throw_range("-[NSArray objectAtIndex:]", i, _count); return _items[i]; }
- (id)objectAtIndexedSubscript:(NSUInteger)i { return [self objectAtIndex:i]; }
- (id)firstObject { return _count ? _items[0] : nil; }
- (id)lastObject { return _count ? _items[_count - 1] : nil; }
- (NSUInteger)indexOfObject:(id)o { for (NSUInteger i = 0; i < _count; i++) if ([_items[i] isEqual:o]) return i; return NSNotFound; }
- (NSUInteger)indexOfObjectIdenticalTo:(id)o { for (NSUInteger i = 0; i < _count; i++) if (_items[i] == o) return i; return NSNotFound; }
- (BOOL)containsObject:(id)o { return [self indexOfObject:o] != NSNotFound; }
- (NSArray *)arrayByAddingObject:(id)o { NSMutableArray *m = [[self mutableCopy] autorelease]; [m addObject:o]; return [[m copy] autorelease]; }
- (NSArray *)arrayByAddingObjectsFromArray:(NSArray *)a { NSMutableArray *m = [[self mutableCopy] autorelease]; [m addObjectsFromArray:a]; return [[m copy] autorelease]; }
- (NSArray *)subarrayWithRange:(NSRange)r {
    if (NSMaxRange(r) > _count) throw_range("-[NSArray subarrayWithRange:]", NSMaxRange(r), _count);
    return [NSArray arrayWithObjects:_items + r.location count:r.length];
}
- (NSString *)componentsJoinedByString:(NSString *)sep {
    NSMutableString *s = [NSMutableString string];
    for (NSUInteger i = 0; i < _count; i++) { if (i) [s appendString:sep]; [s appendString:[_items[i] description]]; }
    return [[s copy] autorelease];
}
- (BOOL)isEqualToArray:(NSArray *)o {
    if (o == self) return YES;
    if (![o isKindOfClass:[NSArray class]] || o->_count != _count) return NO;
    for (NSUInteger i = 0; i < _count; i++) if (![_items[i] isEqual:o->_items[i]]) return NO;
    return YES;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSArray class]] && [self isEqualToArray:o]; }
- (NSUInteger)hash { return _count; }
static void merge_sort(id *a, id *tmp, NSUInteger n, NSComparisonResult (^cmp)(id, id)) {
    if (n < 2) return;
    NSUInteger h = n / 2;
    merge_sort(a, tmp, h, cmp); merge_sort(a + h, tmp, n - h, cmp);
    NSUInteger i = 0, j = h, k = 0;
    while (i < h && j < n) tmp[k++] = cmp(a[j], a[i]) == NSOrderedAscending ? a[j++] : a[i++];
    while (i < h) tmp[k++] = a[i++];
    while (j < n) tmp[k++] = a[j++];
    memcpy(a, tmp, n * sizeof(id));
}
- (NSArray *)sortedArrayUsingComparator:(NSComparator)cmp {
    NSMutableArray *m = [[self mutableCopy] autorelease]; [m sortUsingComparator:cmp]; return [[m copy] autorelease];
}
- (NSArray *)sortedArrayUsingSelector:(SEL)sel {
    NSMutableArray *m = [[self mutableCopy] autorelease]; [m sortUsingSelector:sel]; return [[m copy] autorelease];
}
- (void)makeObjectsPerformSelector:(SEL)s { for (NSUInteger i = 0; i < _count; i++) [_items[i] performSelector:s]; }
- (void)makeObjectsPerformSelector:(SEL)s withObject:(id)a { for (NSUInteger i = 0; i < _count; i++) [_items[i] performSelector:s withObject:a]; }
- (void)enumerateObjectsUsingBlock:(void (^)(id, NSUInteger, BOOL *))block {
    BOOL stop = NO;
    for (NSUInteger i = 0; i < _count && !stop; i++) block(_items[i], i, &stop);
}
- (NSUInteger)indexOfObjectPassingTest:(BOOL (^)(id, NSUInteger, BOOL *))pred {
    BOOL stop = NO;
    for (NSUInteger i = 0; i < _count && !stop; i++) if (pred(_items[i], i, &stop)) return i;
    return NSNotFound;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    if (st->state >= _count) return 0;
    st->mutationsPtr = &_mutations;
    st->itemsPtr = _items + st->state;
    NSUInteger n = _count - st->state;
    st->state = _count;
    return n;
}
- (id)copyWithZone:(NSZone *)z { return [self class] == [NSArray class] ? [self retain] : [[NSArray alloc] initWithArray:self]; }
- (NSEnumerator *)objectEnumerator { return array_enum(self, NO); }
- (NSEnumerator *)reverseObjectEnumerator { return array_enum(self, YES); }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableArray alloc] initWithArray:self]; }
- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithString:@"(\n"];
    for (NSUInteger i = 0; i < _count; i++) [s appendFormat:@"    %@%s\n", _items[i], i + 1 < _count ? "," : ""];
    [s appendString:@")"];
    return s;
}
@end

@implementation NSMutableArray
+ (instancetype)arrayWithCapacity:(NSUInteger)n { return [[[self alloc] initWithCapacity:n] autorelease]; }
- (instancetype)initWithCapacity:(NSUInteger)n { return [self initWithObjects:NULL count:0]; }
- (void)_grow { if (_count == _cap) { _cap = _cap ? _cap * 2 : 4; _items = realloc(_items, _cap * sizeof(id)); } }
- (void)addObject:(id)o { [self insertObject:o atIndex:_count]; }
- (void)insertObject:(id)o atIndex:(NSUInteger)i {
    if (!o) throw_nil("-[NSMutableArray insertObject:atIndex:]");
    if (i > _count) throw_range("-[NSMutableArray insertObject:atIndex:]", i, _count + 1);
    [self _grow];
    memmove(_items + i + 1, _items + i, (_count - i) * sizeof(id));
    _items[i] = [o retain]; _count++; _mutations++;
}
- (void)removeObjectAtIndex:(NSUInteger)i {
    if (i >= _count) throw_range("-[NSMutableArray removeObjectAtIndex:]", i, _count);
    id o = _items[i];
    memmove(_items + i, _items + i + 1, (_count - i - 1) * sizeof(id));
    _count--; _mutations++;
    [o release];
}
- (void)removeLastObject { if (_count) [self removeObjectAtIndex:_count - 1]; }
- (void)replaceObjectAtIndex:(NSUInteger)i withObject:(id)o {
    if (!o) throw_nil("-[NSMutableArray replaceObjectAtIndex:withObject:]");
    if (i >= _count) throw_range("-[NSMutableArray replaceObjectAtIndex:withObject:]", i, _count);
    id old = _items[i]; _items[i] = [o retain]; _mutations++; [old release];
}
- (void)setObject:(id)o atIndexedSubscript:(NSUInteger)i { if (i == _count) [self addObject:o]; else [self replaceObjectAtIndex:i withObject:o]; }
- (void)addObjectsFromArray:(NSArray *)a { for (id o in a) [self addObject:o]; }
- (void)removeAllObjects { while (_count) [self removeObjectAtIndex:_count - 1]; }
- (void)removeObject:(id)o { for (NSUInteger i = _count; i-- > 0;) if ([_items[i] isEqual:o]) [self removeObjectAtIndex:i]; }
- (void)removeObjectIdenticalTo:(id)o { for (NSUInteger i = _count; i-- > 0;) if (_items[i] == o) [self removeObjectAtIndex:i]; }
- (void)removeObjectsInArray:(NSArray *)a { for (id o in a) [self removeObject:o]; }
- (void)exchangeObjectAtIndex:(NSUInteger)a withObjectAtIndex:(NSUInteger)b {
    if (a >= _count || b >= _count) throw_range("-[NSMutableArray exchangeObjectAtIndex:withObjectAtIndex:]", a > b ? a : b, _count);
    id t = _items[a]; _items[a] = _items[b]; _items[b] = t; _mutations++;
}
- (void)sortUsingComparator:(NSComparator)cmp {
    id *tmp = malloc((_count + 1) * sizeof(id));
    merge_sort(_items, tmp, _count, cmp);
    free(tmp); _mutations++;
}
- (void)sortUsingSelector:(SEL)sel {
    [self sortUsingComparator:^NSComparisonResult(id a, id b) { return (NSComparisonResult)(NSInteger)[a performSelector:sel withObject:b]; }];
}
@end

/* ================= NSDictionary / NSMutableDictionary (insertion-ordered, hashed linear probe) ================= */
/* _options, _count, _keys and _vals come first: clang's constant dictionaries (NSConstantDictionary: { isa, options,
 * count, keys, objects }) share this prefix; they have no _hashes and override -_indexOfKey: (ConstantLiterals.mrc.m).
 * Keep the order. */
@implementation NSDictionary { @public NSUInteger _options, _count; id *_keys, *_vals; NSUInteger *_hashes; NSUInteger _cap; unsigned long _mutations; }
+ (instancetype)dictionary { return [[[self alloc] init] autorelease]; }
+ (instancetype)dictionaryWithObject:(id)o forKey:(id)k { return [[[self alloc] initWithObjects:&o forKeys:&k count:1] autorelease]; }
+ (instancetype)dictionaryWithObjects:(const id *)o forKeys:(const id *)k count:(NSUInteger)n { return [[[self alloc] initWithObjects:o forKeys:k count:n] autorelease]; }
+ (instancetype)dictionaryWithDictionary:(NSDictionary *)d { return [[[self alloc] initWithDictionary:d] autorelease]; }
+ (instancetype)dictionaryWithObjectsAndKeys:(id)first, ... {
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    va_list ap; va_start(ap, first);
    for (id o = first; o; o = va_arg(ap, id)) { id k = va_arg(ap, id); [m setObject:o forKey:k]; }
    va_end(ap);
    return [[[self alloc] initWithDictionary:m] autorelease];
}
+ (NSDictionary *)dictionaryWithContentsOfFile:(NSString *)path {
    NSString *s = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL];
    if (!s) return nil;
    id r = isim_plist_parse([s UTF8String], [s lengthOfBytesUsingEncoding:NSUTF8StringEncoding]);
    return [r isKindOfClass:[NSDictionary class]] ? r : nil;
}
- (instancetype)init { return [self initWithObjects:NULL forKeys:NULL count:0]; }
- (instancetype)initWithObjects:(const id *)objs forKeys:(const id *)keys count:(NSUInteger)n {
    _cap = n ? n : 4;
    _keys = malloc(_cap * sizeof(id)); _vals = malloc(_cap * sizeof(id)); _hashes = malloc(_cap * sizeof(NSUInteger));
    for (NSUInteger i = 0; i < n; i++) [self _set:objs[i] forKey:keys[i]];
    return self;
}
- (instancetype)initWithDictionary:(NSDictionary *)d { return [self initWithObjects:d->_vals forKeys:d->_keys count:d->_count]; }
- (void)dealloc {
    for (NSUInteger i = 0; i < _count; i++) { [_keys[i] release]; [_vals[i] release]; }
    free(_keys); free(_vals); free(_hashes); [super dealloc];
}
- (NSUInteger)_indexOfKey:(id)k {
    if (!k) return NSNotFound;
    NSUInteger h = [k hash];
    for (NSUInteger i = 0; i < _count; i++) if (_hashes[i] == h && (_keys[i] == k || [_keys[i] isEqual:k])) return i;
    return NSNotFound;
}
- (void)_set:(id)o forKey:(id)k {
    if (!o || !k) [NSException raise:NSInvalidArgumentException format:@"*** -[NSDictionary setObject:forKey:]: %s cannot be nil", o ? "key" : "object"];
    NSUInteger i = [self _indexOfKey:k];
    if (i != NSNotFound) { id old = _vals[i]; _vals[i] = [o retain]; [old release]; _mutations++; return; }
    if (_count == _cap) {
        _cap *= 2;
        _keys = realloc(_keys, _cap * sizeof(id)); _vals = realloc(_vals, _cap * sizeof(id)); _hashes = realloc(_hashes, _cap * sizeof(NSUInteger));
    }
    _keys[_count] = [k copy]; _vals[_count] = [o retain]; _hashes[_count] = [k hash]; _count++; _mutations++;
}
- (NSUInteger)count { return _count; }
- (id)objectForKey:(id)k { NSUInteger i = [self _indexOfKey:k]; return i == NSNotFound ? nil : _vals[i]; }
- (id)objectForKeyedSubscript:(id)k { return [self objectForKey:k]; }
- (NSArray *)allKeys { return [NSArray arrayWithObjects:_keys count:_count]; }
- (NSArray *)allValues { return [NSArray arrayWithObjects:_vals count:_count]; }
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
    BOOL stop = NO;
    for (NSUInteger i = 0; i < _count && !stop; i++) block(_keys[i], _vals[i], &stop);
}
- (BOOL)isEqualToDictionary:(NSDictionary *)o {
    if (o->_count != _count) return NO;
    for (NSUInteger i = 0; i < _count; i++) if (![[o objectForKey:_keys[i]] isEqual:_vals[i]]) return NO;
    return YES;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSDictionary class]] && [self isEqualToDictionary:o]; }
- (NSUInteger)hash { return _count; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    if (st->state >= _count) return 0;
    st->mutationsPtr = &_mutations;
    st->itemsPtr = _keys + st->state;
    NSUInteger n = _count - st->state;
    st->state = _count;
    return n;
}
- (id)copyWithZone:(NSZone *)z { return [self class] == [NSDictionary class] ? [self retain] : [[NSDictionary alloc] initWithDictionary:self]; }
- (NSEnumerator *)keyEnumerator { return array_enum([self allKeys], NO); }
- (NSEnumerator *)objectEnumerator { return array_enum([self allValues], NO); }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableDictionary alloc] initWithDictionary:self]; }
- (NSString *)description {
    NSMutableString *s = [NSMutableString stringWithString:@"{\n"];
    for (NSUInteger i = 0; i < _count; i++) [s appendFormat:@"    %@ = %@;\n", _keys[i], _vals[i]];
    [s appendString:@"}"];
    return s;
}
@end

@implementation NSMutableDictionary
+ (instancetype)dictionaryWithCapacity:(NSUInteger)n { return [[[self alloc] initWithCapacity:n] autorelease]; }
- (instancetype)initWithCapacity:(NSUInteger)n { return [self initWithObjects:NULL forKeys:NULL count:0]; }
- (void)setObject:(id)o forKey:(id)k { [self _set:o forKey:k]; }
- (void)setObject:(id)o forKeyedSubscript:(id)k { if (o) [self _set:o forKey:k]; else [self removeObjectForKey:k]; }
- (void)removeObjectForKey:(id)k {
    NSUInteger i = [self _indexOfKey:k];
    if (i == NSNotFound) return;
    id ok = _keys[i], ov = _vals[i];
    memmove(_keys + i, _keys + i + 1, (_count - i - 1) * sizeof(id));
    memmove(_vals + i, _vals + i + 1, (_count - i - 1) * sizeof(id));
    memmove(_hashes + i, _hashes + i + 1, (_count - i - 1) * sizeof(NSUInteger));
    _count--; _mutations++;
    [ok release]; [ov release];
}
- (void)removeAllObjects { while (_count) [self removeObjectForKey:_keys[_count - 1]]; }
- (void)addEntriesFromDictionary:(NSDictionary *)d { for (id k in d) [self _set:[d objectForKey:k] forKey:k]; }
@end

/* ================= NSSet / NSMutableSet (array-backed) ================= */
@implementation NSSet { @public NSMutableArray *_a; }
+ (instancetype)set { return [[[self alloc] init] autorelease]; }
+ (instancetype)setWithObject:(id)o { return [[[self alloc] initWithObjects:&o count:1] autorelease]; }
+ (instancetype)setWithObjects:(const id *)o count:(NSUInteger)n { return [[[self alloc] initWithObjects:o count:n] autorelease]; }
+ (instancetype)setWithArray:(NSArray *)a { return [[[self alloc] initWithArray:a] autorelease]; }
+ (instancetype)setWithObjects:(id)first, ... {
    NSMutableArray *tmp = [NSMutableArray array];
    va_list ap; va_start(ap, first);
    for (id o = first; o; o = va_arg(ap, id)) [tmp addObject:o];
    va_end(ap);
    return [[[self alloc] initWithArray:tmp] autorelease];
}
- (instancetype)init { return [self initWithObjects:NULL count:0]; }
- (instancetype)initWithObjects:(const id *)o count:(NSUInteger)n {
    _a = [[NSMutableArray alloc] init];
    for (NSUInteger i = 0; i < n; i++) if (![_a containsObject:o[i]]) [_a addObject:o[i]];
    return self;
}
- (instancetype)initWithArray:(NSArray *)arr {
    _a = [[NSMutableArray alloc] init];
    for (id o in arr) if (![_a containsObject:o]) [_a addObject:o];
    return self;
}
- (void)dealloc { [_a release]; [super dealloc]; }
- (NSUInteger)count { return [_a count]; }
- (id)member:(id)o { NSUInteger i = [_a indexOfObject:o]; return i == NSNotFound ? nil : [_a objectAtIndex:i]; }
- (BOOL)containsObject:(id)o { return [_a containsObject:o]; }
- (id)anyObject { return [_a firstObject]; }
- (NSArray *)allObjects { return [[_a copy] autorelease]; }
- (void)enumerateObjectsUsingBlock:(void (^)(id, BOOL *))block { BOOL stop = NO; for (id o in _a) { block(o, &stop); if (stop) break; } }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len { return [_a countByEnumeratingWithState:st objects:buf count:len]; }
- (id)copyWithZone:(NSZone *)z { return [[NSSet alloc] initWithArray:_a]; }
- (NSEnumerator *)objectEnumerator { return array_enum(_a, NO); }
- (id)mutableCopyWithZone:(NSZone *)z { return [[NSMutableSet alloc] initWithArray:_a]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSSet class]] || [o count] != [self count]) return NO;
    for (id x in _a) if (![o containsObject:x]) return NO;
    return YES;
}
- (NSUInteger)hash { return [_a count]; }
- (NSString *)description { return [NSString stringWithFormat:@"{(%@)}", [_a componentsJoinedByString:@", "]]; }
@end

@implementation NSMutableSet
+ (instancetype)setWithCapacity:(NSUInteger)n { return [[[self alloc] init] autorelease]; }
- (void)addObject:(id)o { if (!o) throw_nil("-[NSMutableSet addObject:]"); if (![_a containsObject:o]) [_a addObject:o]; }
- (void)removeObject:(id)o { [_a removeObject:o]; }
- (void)removeAllObjects { [_a removeAllObjects]; }
- (void)addObjectsFromArray:(NSArray *)arr { for (id o in arr) [self addObject:o]; }
@end

@implementation NSNull
+ (NSNull *)null { static NSNull *n; if (!n) n = [[NSNull alloc] init]; return n; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return @"<null>"; }
@end

/* Empty-collection singletons referenced by clang for @[] and @{} (iOS 14+ runtime ABI): the static
 * __NSArray0__struct / __NSDictionary0__struct objects (ConstantLiterals.mrc.m). */
NSArray *__NSArray0__ = (NSArray *)&__NSArray0__struct;
NSDictionary *__NSDictionary0__ = (NSDictionary *)&__NSDictionary0__struct;
