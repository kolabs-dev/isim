/* isim Foundation: the classes and objects behind clang's constant Objective-C literals (MRC).
 *
 * clang >= 23 (-fobjc-constant-literals, the default for new deployment targets) emits literals as static objects
 * instead of +arrayWithObjects:count: / +numberWithInt: calls:
 *   @[a, b]   { isa = NSConstantArray, count, objects }                  __DATA,__objc_arrayobj
 *   @{k: v}   { isa = NSConstantDictionary, options, count, keys, objects } __DATA,__objc_dictobj (string keys only)
 *   @42       { isa = NSConstantIntegerNumber, const char *encoding, long long value }  __DATA,__objc_intobj
 *   @2.5      { isa = NSConstantDoubleNumber, double }                   __DATA,__objc_doubleobj
 *   @2.5f     { isa = NSConstantFloatNumber, float }                     __DATA,__objc_floatobj
 *   @YES/@NO  &__kCFBooleanTrue / &__kCFBooleanFalse
 *   @[] / @{} &__NSArray0__struct / &__NSDictionary0__struct
 * The array and dictionary layouts are prefixes of NSArray's and NSDictionary's ivars (Collections.mrc.m), so the
 * inherited methods read them directly; numbers override NSNumber's -_isim_getNumber: primitive. All of them are
 * immortal: retain/release/autorelease do nothing and copy returns the object itself. */
#import <Foundation/Foundation.h>
#include <objc/isim_internal.h>
#include "isim_foundation.h"

struct isim_const_array { Class isa; NSUInteger count; id *objects; };
struct isim_const_dict { Class isa; NSUInteger options, count; id *keys, *objects; };
struct isim_const_int { Class isa; const char *encoding; long long value; };
struct isim_const_double { Class isa; double value; };
struct isim_const_float { Class isa; float value; };
struct isim_const_bool { Class isa; uintptr_t value; };

#define IMMORTAL \
    - (instancetype)retain { return self; } \
    - (oneway void)release {} \
    - (instancetype)autorelease { return self; } \
    - (NSUInteger)retainCount { return NSUIntegerMax; } \
    - (id)copyWithZone:(NSZone *)z { return self; } \
    - (id)copy { return self; }

static unsigned long no_mutations;   /* fast-enumeration mutation counter of immutable objects */

/* ---------------- arrays ---------------- */
@interface NSConstantArray : NSArray @end
@implementation NSConstantArray
IMMORTAL
- (Class)classForCoder { return [NSArray class]; }
- (Class)classForKeyedArchiver { return [NSArray class]; }
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    struct isim_const_array *a = (struct isim_const_array *)self;
    if (st->state >= a->count) return 0;
    st->mutationsPtr = &no_mutations;
    st->itemsPtr = a->objects + st->state;
    NSUInteger n = a->count - st->state;
    st->state = a->count;
    return n;
}
@end

/* @[] */
@interface __NSArray0 : NSConstantArray @end
@implementation __NSArray0 @end

/* ---------------- dictionaries ---------------- */
@interface NSConstantDictionary : NSDictionary @end
@implementation NSConstantDictionary
IMMORTAL
- (Class)classForCoder { return [NSDictionary class]; }
- (Class)classForKeyedArchiver { return [NSDictionary class]; }
/* string keys, sorted by clang; a linear scan (identity first) keeps lookups independent of that order. A key written
 * twice in the literal (clang warns) appears twice; the last one wins, as with +dictionaryWithObjects:forKeys:count:. */
- (NSUInteger)_indexOfKey:(id)k {
    struct isim_const_dict *d = (struct isim_const_dict *)self;
    if (!k) return NSNotFound;
    for (NSUInteger i = d->count; i-- > 0;) if (d->keys[i] == k) return i;
    for (NSUInteger i = d->count; i-- > 0;) if ([d->keys[i] isEqual:k]) return i;
    return NSNotFound;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id *)buf count:(NSUInteger)len {
    struct isim_const_dict *d = (struct isim_const_dict *)self;
    if (st->state >= d->count) return 0;
    st->mutationsPtr = &no_mutations;
    st->itemsPtr = d->keys + st->state;
    NSUInteger n = d->count - st->state;
    st->state = d->count;
    return n;
}
@end

/* @{} */
@interface __NSDictionary0 : NSConstantDictionary @end
@implementation __NSDictionary0 @end

/* ---------------- numbers ---------------- */
#define NUMBER_CLASS \
    IMMORTAL \
    - (Class)classForCoder { return [NSNumber class]; } \
    - (Class)classForKeyedArchiver { return [NSNumber class]; }

@interface NSConstantIntegerNumber : NSNumber @end
@implementation NSConstantIntegerNumber
NUMBER_CLASS
- (void)_isim_getNumber:(isim_numv *)v {
    struct isim_const_int *n = (struct isim_const_int *)self;
    char e = n->encoding ? n->encoding[0] : 'q';
    v->t = e == 'B' ? ISIM_NUM_BOOL : (e == 'C' || e == 'S' || e == 'I' || e == 'L' || e == 'Q') ? ISIM_NUM_UINT : ISIM_NUM_INT;
    v->i = n->value;
}
- (const char *)objCType { const char *e = ((struct isim_const_int *)self)->encoding; return e ? e : "q"; }
@end

@interface NSConstantDoubleNumber : NSNumber @end
@implementation NSConstantDoubleNumber
NUMBER_CLASS
- (void)_isim_getNumber:(isim_numv *)v { v->t = ISIM_NUM_DBL; v->d = ((struct isim_const_double *)self)->value; }
- (const char *)objCType { return "d"; }
@end

@interface NSConstantFloatNumber : NSNumber @end
@implementation NSConstantFloatNumber
NUMBER_CLASS
- (void)_isim_getNumber:(isim_numv *)v { v->t = ISIM_NUM_DBL; v->d = ((struct isim_const_float *)self)->value; }
- (const char *)objCType { return "f"; }
@end

/* kCFBooleanTrue / kCFBooleanFalse: @YES, @NO, +numberWithBool: */
@interface __NSCFBoolean : NSNumber @end
@implementation __NSCFBoolean
NUMBER_CLASS
- (void)_isim_getNumber:(isim_numv *)v { v->t = ISIM_NUM_BOOL; v->i = ((struct isim_const_bool *)self)->value != 0; }
- (const char *)objCType { return "c"; }
@end

/* ---------------- the static objects clang references ---------------- */
extern char isim_class_NSArray0 __asm__("_OBJC_CLASS_$___NSArray0");
extern char isim_class_NSDictionary0 __asm__("_OBJC_CLASS_$___NSDictionary0");
extern char isim_class_NSCFBoolean __asm__("_OBJC_CLASS_$___NSCFBoolean");

struct isim_const_array __NSArray0__struct = { (Class)&isim_class_NSArray0, 0, NULL };
struct isim_const_dict __NSDictionary0__struct = { (Class)&isim_class_NSDictionary0, 0, 0, NULL, NULL };
struct isim_const_bool __kCFBooleanTrue = { (Class)&isim_class_NSCFBoolean, 1 };
struct isim_const_bool __kCFBooleanFalse = { (Class)&isim_class_NSCFBoolean, 0 };

NSNumber *isim_bool_number(BOOL v) { return (NSNumber *)(v ? &__kCFBooleanTrue : &__kCFBooleanFalse); }
