/* isim Foundation: NSValue/NSNumber, NSArray, NSDictionary, NSSet, NSCountedSet, NSNull (MRC). */
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
/* keyed coding (Apple's NS.special keys); values written by reference or inline are both read */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSValue class]); }
- (instancetype)initWithCoder:(NSCoder *)c {
    if (!(self = [self init])) return nil;
    const char *str = NULL;
    switch ([c decodeIntForKey:@"NS.special"]) {
    case 1: _kind = V_POINT; str = [[c decodeObjectOfClass:[NSString class] forKey:@"NS.pointval"] UTF8String];
            sscanf(str ?: "", "{%lf, %lf}", &_v.pt.x, &_v.pt.y); break;
    case 2: _kind = V_SIZE; str = [[c decodeObjectOfClass:[NSString class] forKey:@"NS.sizeval"] UTF8String];
            sscanf(str ?: "", "{%lf, %lf}", &_v.sz.width, &_v.sz.height); break;
    case 3: _kind = V_RECT; str = [[c decodeObjectOfClass:[NSString class] forKey:@"NS.rectval"] UTF8String];
            sscanf(str ?: "", "{{%lf, %lf}, {%lf, %lf}}", &_v.rect.origin.x, &_v.rect.origin.y, &_v.rect.size.width, &_v.rect.size.height); break;
    case 4: _kind = V_RANGE; _v.r = NSMakeRange((NSUInteger)[c decodeInt64ForKey:@"NS.rangeval.location"], (NSUInteger)[c decodeInt64ForKey:@"NS.rangeval.length"]); break;
    default: [self release]; return nil;                     /* pointers and other types are not archivable */
    }
    return self;
}
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
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSArray class]); }    /* NS.objects */
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithArray:isim_decode_objects(c, @"NS.objects")]; }
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

/* ================= hash index (NSDictionary, NSSet) =================
 * Entries live in insertion-ordered arrays (keys, their hashes, values or counts). Removing one leaves a nil hole, so
 * nothing shifts; the holes are squeezed out before the next ordered walk (enumeration, allKeys, description, ...) or
 * when the arrays fill up. The index is an open-addressing table (linear probing, at most half full) whose slots hold
 * entry position + 1 (0 = empty), so lookup, insertion and removal take O(1) expected time, comparing with -hash
 * first and -isEqual: only on a hash match. */
typedef struct { NSUInteger *slots, mask; } isim_hidx;

static inline NSUInteger hidx_mix(NSUInteger h) { h ^= h >> 33; h *= 0xff51afd7ed558ccdull; h ^= h >> 33; return h; }
static void hidx_put(isim_hidx *x, const NSUInteger *hashes, NSUInteger pos) {
    NSUInteger s = hidx_mix(hashes[pos]) & x->mask;
    while (x->slots[s]) s = (s + 1) & x->mask;
    x->slots[s] = pos + 1;
}
/* index the entries [0, end) (nil keys are holes) in a table with room for `want` of them */
static void hidx_build(isim_hidx *x, id *keys, const NSUInteger *hashes, NSUInteger end, NSUInteger want) {
    NSUInteger size = 8;
    while (size < want * 2) size *= 2;
    free(x->slots); x->slots = calloc(size, sizeof(NSUInteger)); x->mask = size - 1;
    for (NSUInteger i = 0; i < end; i++) if (keys[i]) hidx_put(x, hashes, i);
}
/* make room for one more entry */
static void hidx_reserve(isim_hidx *x, id *keys, const NSUInteger *hashes, NSUInteger end, NSUInteger count) {
    if (!x->slots || (count + 1) * 2 > x->mask + 1) hidx_build(x, keys, hashes, end, (count + 1) * 2);
}
/* the slot of the entry equal to k (whose hash is h), or NSNotFound */
static NSUInteger hidx_find(const isim_hidx *x, id *keys, const NSUInteger *hashes, id k, NSUInteger h) {
    if (!x->slots) return NSNotFound;
    for (NSUInteger s = hidx_mix(h) & x->mask; x->slots[s]; s = (s + 1) & x->mask) {
        NSUInteger p = x->slots[s] - 1;
        if (hashes[p] == h && (keys[p] == k || [keys[p] isEqual:k])) return s;
    }
    return NSNotFound;
}
/* empty slot s, moving later members of its probe run back into the gap (deletion without tombstones) */
static void hidx_del(isim_hidx *x, const NSUInteger *hashes, NSUInteger s) {
    for (NSUInteger j = (s + 1) & x->mask; x->slots[j]; j = (j + 1) & x->mask) {
        NSUInteger home = hidx_mix(hashes[x->slots[j] - 1]) & x->mask;
        if (((j - home) & x->mask) >= ((j - s) & x->mask)) { x->slots[s] = x->slots[j]; s = j; }
    }
    x->slots[s] = 0;
}
static void hidx_clear(isim_hidx *x) { if (x->slots) memset(x->slots, 0, (x->mask + 1) * sizeof(NSUInteger)); }
/* squeeze the holes out of [0, *end), keeping the order (vals and aux may be NULL), and re-index. The vacated tail is
 * nil, so a walk that the caller mutates sees holes rather than stale objects. */
static void hidx_compact(isim_hidx *x, id *keys, id *vals, NSUInteger *aux, NSUInteger *hashes, NSUInteger *end, NSUInteger count) {
    NSUInteger j = 0;
    for (NSUInteger i = 0; i < *end; i++) {
        if (!keys[i]) continue;
        keys[j] = keys[i]; hashes[j] = hashes[i];
        if (vals) vals[j] = vals[i];
        if (aux) aux[j] = aux[i];
        j++;
    }
    for (NSUInteger i = j; i < *end; i++) { keys[i] = nil; if (vals) vals[i] = nil; }
    *end = j;
    hidx_build(x, keys, hashes, j, count * 2);
}

/* ================= NSDictionary / NSMutableDictionary (insertion-ordered, hash-indexed) ================= */
/* _options, _count, _keys and _vals come first: clang's constant dictionaries (NSConstantDictionary: { isa, options,
 * count, keys, objects }) share this prefix; they have none of the later ivars, override -_indexOfKey: and
 * -_isim_compact (ConstantLiterals.mrc.m) and never reach the mutating paths. Keep the order.
 * _count is the number of entries, _end the used length of the arrays (entries and holes); methods that walk the
 * arrays call -_isim_compact first, after which they are the same. */
@implementation NSDictionary { @public NSUInteger _options, _count; id *_keys, *_vals; NSUInteger *_hashes; NSUInteger _cap; unsigned long _mutations; NSUInteger _end; isim_hidx _idx; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSDictionary class]); }    /* NS.keys, NS.objects */
- (instancetype)initWithCoder:(NSCoder *)c {
    NSArray *keys = isim_decode_objects(c, @"NS.keys"), *vals = isim_decode_objects(c, @"NS.objects");
    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:keys.count];
    for (NSUInteger i = 0; i < keys.count && i < vals.count; i++) [d setObject:[vals objectAtIndex:i] forKey:[keys objectAtIndex:i]];
    return [self initWithDictionary:d];
}
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
- (instancetype)initWithDictionary:(NSDictionary *)d { [d _isim_compact]; return [self initWithObjects:d->_vals forKeys:d->_keys count:d->_count]; }
- (void)dealloc {
    for (NSUInteger i = 0; i < _end; i++) if (_keys[i]) { [_keys[i] release]; [_vals[i] release]; }
    free(_keys); free(_vals); free(_hashes); free(_idx.slots); [super dealloc];
}
- (void)_isim_compact { if (_end != _count) hidx_compact(&_idx, _keys, _vals, NULL, _hashes, &_end, _count); }
- (NSUInteger)_indexOfKey:(id)k {
    if (!k) return NSNotFound;
    NSUInteger s = hidx_find(&_idx, _keys, _hashes, k, [k hash]);
    return s == NSNotFound ? NSNotFound : _idx.slots[s] - 1;
}
- (void)_set:(id)o forKey:(id)k {
    if (!o || !k) [NSException raise:NSInvalidArgumentException format:@"*** -[NSDictionary setObject:forKey:]: %s cannot be nil", o ? "key" : "object"];
    NSUInteger h = [k hash], s = hidx_find(&_idx, _keys, _hashes, k, h);
    if (s != NSNotFound) { NSUInteger i = _idx.slots[s] - 1; id old = _vals[i]; _vals[i] = [o retain]; [old release]; _mutations++; return; }
    if (_end == _cap) {
        if (_end - _count > _cap / 4) [self _isim_compact];
        else {
            _cap *= 2;
            _keys = realloc(_keys, _cap * sizeof(id)); _vals = realloc(_vals, _cap * sizeof(id)); _hashes = realloc(_hashes, _cap * sizeof(NSUInteger));
        }
    }
    hidx_reserve(&_idx, _keys, _hashes, _end, _count);
    _keys[_end] = [k copy]; _vals[_end] = [o retain]; _hashes[_end] = h;
    hidx_put(&_idx, _hashes, _end);
    _end++; _count++; _mutations++;
}
- (NSUInteger)count { return _count; }
- (id)objectForKey:(id)k { NSUInteger i = [self _indexOfKey:k]; return i == NSNotFound ? nil : _vals[i]; }
- (id)objectForKeyedSubscript:(id)k { return [self objectForKey:k]; }
- (NSArray *)allKeys { [self _isim_compact]; return [NSArray arrayWithObjects:_keys count:_count]; }
- (NSArray *)allValues { [self _isim_compact]; return [NSArray arrayWithObjects:_vals count:_count]; }
- (void)enumerateKeysAndObjectsUsingBlock:(void (^)(id, id, BOOL *))block {
    [self _isim_compact];
    BOOL stop = NO;
    for (NSUInteger i = 0, n = _count; i < n && !stop; i++) if (_keys[i]) block(_keys[i], _vals[i], &stop);
}
- (BOOL)isEqualToDictionary:(NSDictionary *)o {
    if (o->_count != _count) return NO;
    [self _isim_compact];
    for (NSUInteger i = 0; i < _count; i++) if (![[o objectForKey:_keys[i]] isEqual:_vals[i]]) return NO;
    return YES;
}
- (BOOL)isEqual:(id)o { return [o isKindOfClass:[NSDictionary class]] && [self isEqualToDictionary:o]; }
- (NSUInteger)hash { return _count; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    if (!st->state) [self _isim_compact];
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
    [self _isim_compact];
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
    if (!k) return;
    NSUInteger s = hidx_find(&_idx, _keys, _hashes, k, [k hash]);
    if (s == NSNotFound) return;
    NSUInteger i = _idx.slots[s] - 1;
    id ok = _keys[i], ov = _vals[i];
    hidx_del(&_idx, _hashes, s);
    _keys[i] = _vals[i] = nil; _count--; _mutations++;
    if (i + 1 == _end) _end--;
    [ok release]; [ov release];
}
- (void)removeAllObjects {
    NSUInteger end = _end;
    id *keys = malloc((end + 1) * sizeof(id)), *vals = malloc((end + 1) * sizeof(id));
    memcpy(keys, _keys, end * sizeof(id)); memcpy(vals, _vals, end * sizeof(id));
    memset(_keys, 0, end * sizeof(id)); memset(_vals, 0, end * sizeof(id));
    _count = _end = 0; _mutations++; hidx_clear(&_idx);
    for (NSUInteger i = 0; i < end; i++) if (keys[i]) { [keys[i] release]; [vals[i] release]; }
    free(keys); free(vals);
}
- (void)addEntriesFromDictionary:(NSDictionary *)d { for (id k in d) [self _set:[d objectForKey:k] forKey:k]; }
@end

/* ================= NSSet / NSMutableSet / NSCountedSet (insertion-ordered, hash-indexed) ================= */
/* The objects are stored like NSDictionary's keys (hash index above), without copying. _counts is NSCountedSet's
 * per-object count (NULL in other sets). _a is unused: its ivar offset symbol is exported (isim/abi). */
@implementation NSSet { @public NSMutableArray *_a; id *_objs; NSUInteger *_hashes, *_counts; NSUInteger _count, _end, _cap; unsigned long _mutations; isim_hidx _idx; }
static void set_compact(NSSet *s) { if (s->_end != s->_count) hidx_compact(&s->_idx, s->_objs, NULL, s->_counts, s->_hashes, &s->_end, s->_count); }
static NSUInteger set_find(NSSet *s, id o) { return o ? hidx_find(&s->_idx, s->_objs, s->_hashes, o, [o hash]) : NSNotFound; }
/* the position of o, inserted (retained) if no equal object is there yet */
static NSUInteger set_insert(NSSet *s, id o) {
    NSUInteger h = [o hash], slot = hidx_find(&s->_idx, s->_objs, s->_hashes, o, h);
    if (slot != NSNotFound) return s->_idx.slots[slot] - 1;
    if (s->_end == s->_cap) {
        if (s->_end - s->_count > s->_cap / 4) set_compact(s);
        else {
            s->_cap *= 2;
            s->_objs = realloc(s->_objs, s->_cap * sizeof(id)); s->_hashes = realloc(s->_hashes, s->_cap * sizeof(NSUInteger));
            if (s->_counts) s->_counts = realloc(s->_counts, s->_cap * sizeof(NSUInteger));
        }
    }
    hidx_reserve(&s->_idx, s->_objs, s->_hashes, s->_end, s->_count);
    NSUInteger p = s->_end++;
    s->_objs[p] = [o retain]; s->_hashes[p] = h;
    if (s->_counts) s->_counts[p] = 0;
    hidx_put(&s->_idx, s->_hashes, p);
    s->_count++; s->_mutations++;
    return p;
}
static void set_remove_slot(NSSet *s, NSUInteger slot) {
    NSUInteger p = s->_idx.slots[slot] - 1;
    id o = s->_objs[p];
    hidx_del(&s->_idx, s->_hashes, slot);
    s->_objs[p] = nil; s->_count--; s->_mutations++;
    if (p + 1 == s->_end) s->_end--;
    [o release];
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSSet class]); }    /* NS.objects */
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithArray:isim_decode_objects(c, @"NS.objects")]; }
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
    _cap = n ? n : 4;
    _objs = malloc(_cap * sizeof(id)); _hashes = malloc(_cap * sizeof(NSUInteger));
    for (NSUInteger i = 0; i < n; i++) { if (!o[i]) throw_nil("-[NSSet initWithObjects:count:]"); set_insert(self, o[i]); }
    return self;
}
- (instancetype)initWithArray:(NSArray *)arr {
    NSUInteger n = [arr count];
    id *tmp = malloc((n + 1) * sizeof(id));
    NSUInteger i = 0;
    for (id o in arr) if (i < n) tmp[i++] = o;
    self = [self initWithObjects:tmp count:i];
    free(tmp);
    return self;
}
- (void)dealloc {
    for (NSUInteger i = 0; i < _end; i++) [_objs[i] release];
    free(_objs); free(_hashes); free(_counts); free(_idx.slots); [_a release]; [super dealloc];
}
- (NSUInteger)count { return _count; }
- (id)member:(id)o { NSUInteger s = set_find(self, o); return s == NSNotFound ? nil : _objs[_idx.slots[s] - 1]; }
- (BOOL)containsObject:(id)o { return set_find(self, o) != NSNotFound; }
- (id)anyObject { set_compact(self); return _count ? _objs[0] : nil; }
- (NSArray *)allObjects { set_compact(self); return [NSArray arrayWithObjects:_objs count:_count]; }
- (void)enumerateObjectsUsingBlock:(void (^)(id, BOOL *))block {
    set_compact(self);
    BOOL stop = NO;
    for (NSUInteger i = 0, n = _count; i < n && !stop; i++) if (_objs[i]) block(_objs[i], &stop);
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    if (!st->state) set_compact(self);
    if (st->state >= _count) return 0;
    st->mutationsPtr = &_mutations;
    st->itemsPtr = _objs + st->state;
    NSUInteger n = _count - st->state;
    st->state = _count;
    return n;
}
- (id)copyWithZone:(NSZone *)z { set_compact(self); return [[NSSet alloc] initWithObjects:_objs count:_count]; }
- (NSEnumerator *)objectEnumerator { return array_enum([self allObjects], NO); }
- (id)mutableCopyWithZone:(NSZone *)z { set_compact(self); return [[NSMutableSet alloc] initWithObjects:_objs count:_count]; }
- (BOOL)isEqual:(id)o {
    if (![o isKindOfClass:[NSSet class]] || [o count] != [self count]) return NO;
    for (id x in self) if (![o containsObject:x]) return NO;
    return YES;
}
- (NSUInteger)hash { return _count; }
- (NSString *)description { return [NSString stringWithFormat:@"{(%@)}", [[self allObjects] componentsJoinedByString:@", "]]; }
@end

@implementation NSMutableSet
+ (instancetype)setWithCapacity:(NSUInteger)n { return [[[self alloc] init] autorelease]; }
- (void)addObject:(id)o { if (!o) throw_nil("-[NSMutableSet addObject:]"); set_insert(self, o); }
- (void)removeObject:(id)o { NSUInteger s = set_find(self, o); if (s != NSNotFound) set_remove_slot(self, s); }
- (void)removeAllObjects {
    NSUInteger end = _end;
    id *objs = malloc((end + 1) * sizeof(id));
    memcpy(objs, _objs, end * sizeof(id)); memset(_objs, 0, end * sizeof(id));
    _count = _end = 0; _mutations++; hidx_clear(&_idx);
    for (NSUInteger i = 0; i < end; i++) [objs[i] release];
    free(objs);
}
- (void)addObjectsFromArray:(NSArray *)arr { for (id o in arr) [self addObject:o]; }
@end

@implementation NSCountedSet
/* NSSet's initializers funnel into -initWithObjects:count:, so the counts are set up there */
- (instancetype)initWithObjects:(const id *)objs count:(NSUInteger)n {
    if ((self = [super initWithObjects:NULL count:0])) {
        _counts = calloc(_cap, sizeof(NSUInteger));
        for (NSUInteger i = 0; i < n; i++) [self addObject:objs[i]];
    }
    return self;
}
- (instancetype)initWithCapacity:(NSUInteger)n { return [self initWithObjects:NULL count:0]; }
- (instancetype)initWithArray:(NSArray *)a { if ((self = [self initWithObjects:NULL count:0])) for (id o in a) [self addObject:o]; return self; }
- (instancetype)initWithSet:(NSSet *)s { return [self initWithArray:[s allObjects]]; }
- (void)addObject:(id)o {
    if (!o) throw_nil("-[NSCountedSet addObject:]");
    NSUInteger p = set_insert(self, o);   /* may reallocate _counts */
    _counts[p]++;
}
- (void)removeObject:(id)o {
    NSUInteger s = set_find(self, o);
    if (s == NSNotFound) return;
    if (--_counts[_idx.slots[s] - 1] == 0) set_remove_slot(self, s);
}
- (NSUInteger)countForObject:(id)o { NSUInteger s = set_find(self, o); return s == NSNotFound ? 0 : _counts[_idx.slots[s] - 1]; }
- (id)copyWithZone:(NSZone *)z {
    set_compact(self);
    NSCountedSet *c = [[NSCountedSet alloc] initWithObjects:_objs count:_count];
    for (NSUInteger i = 0; i < _count; i++) c->_counts[i] = _counts[i];
    return c;
}
- (id)mutableCopyWithZone:(NSZone *)z { return [self copyWithZone:z]; }
@end

@implementation NSNull
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { isim_encode_builtin(self, c, [NSNull class]); }
- (instancetype)initWithCoder:(NSCoder *)c { [self release]; return [[NSNull null] retain]; }
+ (NSNull *)null { static NSNull *n; if (!n) n = [[NSNull alloc] init]; return n; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSString *)description { return @"<null>"; }
@end

/* Empty-collection singletons referenced by clang for @[] and @{} (iOS 14+ runtime ABI): the static
 * __NSArray0__struct / __NSDictionary0__struct objects (ConstantLiterals.mrc.m). */
NSArray *__NSArray0__ = (NSArray *)&__NSArray0__struct;
NSDictionary *__NSDictionary0__ = (NSDictionary *)&__NSDictionary0__struct;
