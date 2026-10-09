/* isim Foundation (ARC): NSPredicate (format-string parser, comparison/compound/block predicates),
 * NSExpression, and filtering of arrays/sets/ordered sets.
 * Grammar (Apple's "Predicate Format String Syntax", common subset): AND/&&, OR/||, NOT/!, parentheses;
 * =, ==, !=, <>, <, <=, =<, >, >=, =>, BETWEEN, IN, CONTAINS, BEGINSWITH, ENDSWITH, LIKE, MATCHES with [c], [d],
 * [cd] options; ANY/SOME/ALL/NONE; key paths (with @count/@sum/... operators), SELF, $variables, %@ %K %d %i %u %ld
 * %lu %lld %f %lf %s %c, string/number/TRUE/FALSE/YES/NO/NULL/NIL literals, {a, b} aggregates,
 * TRUEPREDICATE/FALSEPREDICATE, FUNCTION-free arithmetic (+ - * /) on numbers. */
#import <Foundation/Foundation.h>
#include <ctype.h>
#include <math.h>
#include <stdlib.h>
#include <objc/message.h>
typedef void *pp_jmp[5];   /* __builtin_setjmp buffer (no setjmp in isim's libSystem) */
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include "isim_foundation.h"

@interface _IsimValuePredicate_isim : NSPredicate
- (instancetype)initWithIsimValue:(BOOL)value;
@end
@interface _IsimBlockPredicate_isim : NSPredicate
- (instancetype)initWithIsimBlock:(BOOL (^)(id, NSDictionary *))block;
@end
@interface NSExpression (IsimPrivate)
- (NSString *)predicateFormat_isim;
- (NSExpression *)_isim_substituting:(NSDictionary *)vars;
@end
@interface NSPredicate (IsimPrivate)
+ (NSExpression *)_isim_expressionWithFormat:(NSString *)format arguments:(va_list *)ap array:(NSArray *)args;
@end

/* ================= NSExpression ================= */
/* FIRST / LAST / SIZE in "array[FIRST]" (objectFrom:withIndex:) */
@interface _IsimIndexSymbol_isim : NSObject <NSCopying, NSSecureCoding>
@property (copy) NSString *name;
@end
@implementation _IsimIndexSymbol_isim
+ (instancetype)symbol:(NSString *)n { static NSMutableDictionary *all; @synchronized (self) { if (!all) all = [NSMutableDictionary dictionary];
    _IsimIndexSymbol_isim *s = all[n]; if (!s) { s = [self new]; s.name = n; all[n] = s; } return s; } }
- (id)copyWithZone:(NSZone *)z { return self; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_name forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [_IsimIndexSymbol_isim symbol:[c decodeObjectOfClass:[NSString class] forKey:@"name"] ?: @"FIRST"]; }
- (NSString *)description { return _name; }
@end

@implementation NSExpression {
    @public NSExpressionType _type; id _constant; NSString *_keyPath, *_variable, *_function; NSArray *_args; id _collection;
    NSExpression *_operand, *_left, *_right; NSPredicate *_predicate; id (^_block)(id, NSArray *, NSMutableDictionary *);
}
+ (NSExpression *)expressionWithFormat:(NSString *)fmt arguments:(va_list)ap {
    va_list copy; va_copy(copy, ap);
    NSExpression *e = [NSPredicate _isim_expressionWithFormat:fmt arguments:&copy array:nil];
    va_end(copy);
    return e;
}
+ (NSExpression *)expressionWithFormat:(NSString *)fmt argumentArray:(NSArray *)args { return [NSPredicate _isim_expressionWithFormat:fmt arguments:NULL array:args ?: @[]]; }
+ (NSExpression *)expressionForConstantValue:(id)obj { NSExpression *e = [[self alloc] initWithExpressionType:NSConstantValueExpressionType]; e->_constant = obj; return e; }
+ (NSExpression *)expressionForEvaluatedObject { return [[self alloc] initWithExpressionType:NSEvaluatedObjectExpressionType]; }
+ (NSExpression *)expressionForVariable:(NSString *)v { NSExpression *e = [[self alloc] initWithExpressionType:NSVariableExpressionType]; e->_variable = [v copy]; return e; }
+ (NSExpression *)expressionForKeyPath:(NSString *)kp { NSExpression *e = [[self alloc] initWithExpressionType:NSKeyPathExpressionType]; e->_keyPath = [kp copy]; return e; }
+ (NSExpression *)expressionForAggregate:(NSArray<NSExpression *> *)subs { NSExpression *e = [[self alloc] initWithExpressionType:NSAggregateExpressionType]; e->_collection = [subs copy]; return e; }
+ (NSExpression *)expressionForAnyKey { return [[self alloc] initWithExpressionType:NSAnyKeyExpressionType]; }
+ (NSExpression *)expressionForSymbolicString:(NSString *)s {
    return [@[@"FIRST", @"LAST", @"SIZE"] containsObject:s] ? [self expressionForConstantValue:[_IsimIndexSymbol_isim symbol:s]] : nil;
}
+ (NSExpression *)expressionForFunction:(NSString *)name arguments:(NSArray *)args {
    NSExpression *e = [[self alloc] initWithExpressionType:NSFunctionExpressionType]; e->_function = [name copy]; e->_args = [args copy]; return e;
}
/* FUNCTION(operand, 'selector:', args...): a method of the operand's value */
+ (NSExpression *)expressionForFunction:(NSExpression *)target selectorName:(NSString *)name arguments:(NSArray *)args {
    NSExpression *e = [self expressionForFunction:name arguments:args ?: @[]]; e->_operand = target; return e;
}
+ (NSExpression *)expressionForBlock:(id (^)(id, NSArray<NSExpression *> *, NSMutableDictionary *))block arguments:(NSArray<NSExpression *> *)args {
    NSExpression *e = [[self alloc] initWithExpressionType:NSBlockExpressionType]; e->_block = [block copy]; e->_args = [args copy]; return e;
}
+ (NSExpression *)expressionForSubquery:(NSExpression *)collection usingIteratorVariable:(NSString *)variable predicate:(NSPredicate *)predicate {
    NSExpression *e = [[self alloc] initWithExpressionType:NSSubqueryExpressionType];
    e->_collection = collection; e->_variable = [variable copy]; e->_predicate = predicate; return e;
}
static NSExpression *set_expr(NSExpressionType t, NSExpression *l, NSExpression *r) {
    NSExpression *e = [[NSExpression alloc] initWithExpressionType:t]; e->_left = l; e->_right = r; return e;
}
+ (NSExpression *)expressionForUnionSet:(NSExpression *)l with:(NSExpression *)r { return set_expr(NSUnionSetExpressionType, l, r); }
+ (NSExpression *)expressionForIntersectSet:(NSExpression *)l with:(NSExpression *)r { return set_expr(NSIntersectSetExpressionType, l, r); }
+ (NSExpression *)expressionForMinusSet:(NSExpression *)l with:(NSExpression *)r { return set_expr(NSMinusSetExpressionType, l, r); }
+ (NSExpression *)expressionForConditional:(NSPredicate *)predicate trueExpression:(NSExpression *)t falseExpression:(NSExpression *)f {
    NSExpression *e = [[self alloc] initWithExpressionType:NSConditionalExpressionType]; e->_predicate = predicate; e->_left = t; e->_right = f; return e;
}
+ (NSExpression *)expressionWithFormat:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt); NSExpression *e = [self expressionWithFormat:fmt arguments:ap]; va_end(ap); return e;
}
- (instancetype)initWithExpressionType:(NSExpressionType)type { if ((self = [super init])) _type = type; return self; }
- (instancetype)init { return [self initWithExpressionType:NSConstantValueExpressionType]; }
/* archived as its format (and constant values as objects) */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    if (_type == NSBlockExpressionType) [NSException raise:NSInvalidArgumentException format:@"Block expressions cannot be archived"];
    if (_type == NSConstantValueExpressionType) [c encodeObject:_constant forKey:@"NSConstantValue"];
    else [c encodeObject:[self predicateFormat_isim] forKey:@"NSExpressionFormat"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSString *fmt = [c decodeObjectOfClass:[NSString class] forKey:@"NSExpressionFormat"];
    if (fmt) return [NSExpression expressionWithFormat:fmt argumentArray:@[]];
    NSSet *classes = [NSSet setWithObjects:[NSString class], [NSNumber class], [NSDate class], [NSData class], [NSArray class], [NSDictionary class], [NSSet class], [NSNull class], [NSURL class], [NSUUID class], nil];
    return [NSExpression expressionForConstantValue:[c decodeObjectOfClasses:classes forKey:@"NSConstantValue"]];
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSExpressionType)expressionType { return _type; }
- (id)constantValue {
    if (_type != NSConstantValueExpressionType) [NSException raise:NSInternalInconsistencyException format:@"-constantValue only defined for constant value expressions"];
    return _constant;
}
- (NSString *)keyPath { return _keyPath; }
- (NSString *)variable { return _variable; }
- (NSString *)function { return _function; }
- (NSArray *)arguments { return _args; }
- (id)collection { return _collection; }
- (NSExpression *)operand { return _operand ?: (_type == NSFunctionExpressionType ? [NSExpression expressionForConstantValue:nil] : nil); }
- (NSPredicate *)predicate { return _predicate; }
- (NSExpression *)leftExpression { return _left; }
- (NSExpression *)rightExpression { return _right; }
- (NSExpression *)trueExpression { return _left; }
- (NSExpression *)falseExpression { return _right; }
- (id (^)(id, NSArray<NSExpression *> *, NSMutableDictionary *))expressionBlock { return _block; }
- (void)allowEvaluation {}

static id number_result(double r) { return r == (long long)r && fabs(r) < 9e15 ? @((long long)r) : @(r); }
static NSArray *as_array(id v) {
    if ([v isKindOfClass:[NSArray class]]) return v;
    if ([v isKindOfClass:[NSSet class]]) return [v allObjects];
    if ([v isKindOfClass:[NSOrderedSet class]]) return [v array];
    if ([v isKindOfClass:[NSDictionary class]]) return [v allValues];
    return v && v != [NSNull null] ? @[v] : @[];
}
static NSArray *numbers_of(id v) {
    NSMutableArray *out = [NSMutableArray array];
    for (id x in as_array(v)) if ([x isKindOfClass:[NSNumber class]]) [out addObject:x];
    return out;
}
/* the built-in functions of Apple's NSExpression (expressionForFunction:arguments:) */
static id call_builtin(NSString *f, NSArray *v) {
    NSUInteger n = v.count;
    id a = n > 0 ? v[0] : nil, b = n > 1 ? v[1] : nil;
    if (a == [NSNull null]) a = nil;
    if (b == [NSNull null]) b = nil;
    double x = [a respondsToSelector:@selector(doubleValue)] ? [a doubleValue] : 0, y = [b respondsToSelector:@selector(doubleValue)] ? [b doubleValue] : 0;
    long long ix = [a respondsToSelector:@selector(longLongValue)] ? [a longLongValue] : 0, iy = [b respondsToSelector:@selector(longLongValue)] ? [b longLongValue] : 0;
    /* aggregates over a collection */
    if ([f isEqualToString:@"count:"]) return @(as_array(a).count);
    if ([f isEqualToString:@"sum:"] || [f isEqualToString:@"average:"] || [f isEqualToString:@"stddev:"]) {
        NSArray *nums = numbers_of(a); double s = 0; for (NSNumber *k in nums) s += k.doubleValue;
        if ([f isEqualToString:@"sum:"]) return number_result(s);
        if (!nums.count) return nil;
        double mean = s / nums.count;
        if ([f isEqualToString:@"average:"]) return @(mean);
        double var = 0; for (NSNumber *k in nums) var += (k.doubleValue - mean) * (k.doubleValue - mean);
        return @(sqrt(var / nums.count));
    }
    if ([f isEqualToString:@"min:"] || [f isEqualToString:@"max:"]) {
        id best = nil; BOOL max = [f isEqualToString:@"max:"];
        for (id k in as_array(a)) if (k != [NSNull null] && (!best || [k compare:best] == (max ? NSOrderedDescending : NSOrderedAscending))) best = k;
        return best;
    }
    if ([f isEqualToString:@"median:"]) {
        NSArray *s = [numbers_of(a) sortedArrayUsingSelector:@selector(compare:)];
        if (!s.count) return nil;
        return s.count % 2 ? s[s.count / 2] : number_result(([s[s.count / 2 - 1] doubleValue] + [s[s.count / 2] doubleValue]) / 2);
    }
    if ([f isEqualToString:@"mode:"]) {
        NSCountedSet *c = [NSCountedSet setWithArray:as_array(a)]; NSUInteger top = 0;
        for (id k in c) top = MAX(top, [c countForObject:k]);
        NSMutableArray *out = [NSMutableArray array];
        for (id k in as_array(a)) if ([c countForObject:k] == top && ![out containsObject:k]) [out addObject:k];
        return out;
    }
    /* arithmetic */
    if ([f isEqualToString:@"add:to:"]) return number_result(x + y);
    if ([f isEqualToString:@"from:subtract:"]) return number_result(x - y);
    if ([f isEqualToString:@"multiply:by:"]) return number_result(x * y);
    if ([f isEqualToString:@"divide:by:"]) return number_result(x / y);
    if ([f isEqualToString:@"modulus:by:"]) return @(iy ? ix % iy : 0);
    if ([f isEqualToString:@"sqrt:"]) return @(sqrt(x));
    if ([f isEqualToString:@"log:"]) return @(log10(x));
    if ([f isEqualToString:@"ln:"]) return @(log(x));
    if ([f isEqualToString:@"raise:toPower:"]) return number_result(pow(x, y));
    if ([f isEqualToString:@"exp:"]) return @(exp(x));
    if ([f isEqualToString:@"ceiling:"]) return number_result(ceil(x));
    if ([f isEqualToString:@"floor:"]) return number_result(floor(x));
    if ([f isEqualToString:@"trunc:"]) return number_result(trunc(x));
    if ([f isEqualToString:@"abs:"]) return number_result(fabs(x));
    if ([f isEqualToString:@"random"]) return @(arc4random() / (double)UINT32_MAX);
    if ([f isEqualToString:@"random:"]) { NSArray *c = as_array(a); return c.count ? c[arc4random_uniform((uint32_t)c.count)] : nil; }
    if ([f isEqualToString:@"now"]) return [NSDate date];
    /* bits */
    if ([f isEqualToString:@"bitwiseAnd:with:"]) return @(ix & iy);
    if ([f isEqualToString:@"bitwiseOr:with:"]) return @(ix | iy);
    if ([f isEqualToString:@"bitwiseXor:with:"]) return @(ix ^ iy);
    if ([f isEqualToString:@"leftshift:by:"]) return @(ix << iy);
    if ([f isEqualToString:@"rightshift:by:"]) return @(ix >> iy);
    if ([f isEqualToString:@"onesComplement:"]) return @(~ix);
    /* strings, misc */
    if ([f isEqualToString:@"lowercase:"]) return [a lowercaseString];
    if ([f isEqualToString:@"uppercase:"]) return [a uppercaseString];
    if ([f isEqualToString:@"length:"]) return @([a length]);
    if ([f isEqualToString:@"noindex:"]) return a;
    if ([f isEqualToString:@"distanceToLocation:fromLocation:"]) {
        SEL d = NSSelectorFromString(@"distanceFromLocation:");
        return [a respondsToSelector:d] ? @(((double (*)(id, SEL, id))objc_msgSend)(a, d, b)) : nil;
    }
    if ([f isEqualToString:@"castObject:toType:"]) {
        NSString *type = b;
        if ([type isEqualToString:@"NSString"]) return [a isKindOfClass:[NSString class]] ? a : [a description];
        if ([type isEqualToString:@"NSNumber"]) return [a isKindOfClass:[NSDate class]] ? @([a timeIntervalSinceReferenceDate]) : [a isKindOfClass:[NSNumber class]] ? a : @([a doubleValue]);
        if ([type isEqualToString:@"NSDate"]) return [a isKindOfClass:[NSDate class]] ? a : [NSDate dateWithTimeIntervalSinceReferenceDate:x];
        if ([type isEqualToString:@"NSDecimalNumber"]) return [NSDecimalNumber decimalNumberWithString:[a description]];
        return a;
    }
    if ([f isEqualToString:@"objectFrom:withIndex:"]) {
        if ([a isKindOfClass:[NSDictionary class]]) return [a objectForKey:b];
        NSArray *c = as_array(a);
        if ([b isKindOfClass:[_IsimIndexSymbol_isim class]]) {
            NSString *s = [b name];
            if ([s isEqualToString:@"SIZE"]) return @(c.count);
            if ([s isEqualToString:@"FIRST"]) return c.firstObject;
            return c.lastObject;
        }
        return iy >= 0 && (NSUInteger)iy < c.count ? c[(NSUInteger)iy] : nil;
    }
    [NSException raise:NSInvalidArgumentException format:@"Unsupported function expression %@", f];
    return nil;
}
static NSSet *as_set(id v) { return [NSSet setWithArray:as_array(v)]; }
- (id)expressionValueWithObject:(id)object context:(NSMutableDictionary *)context {
    switch (_type) {
    case NSConstantValueExpressionType: return _constant;
    case NSEvaluatedObjectExpressionType: return object;
    case NSVariableExpressionType: return context[_variable];
    case NSKeyPathExpressionType: return [_keyPath isEqualToString:@"SELF"] ? object : [object valueForKeyPath:_keyPath];
    case NSAnyKeyExpressionType: return [object isKindOfClass:[NSDictionary class]] ? [object allValues] : object;
    case NSAggregateExpressionType: {
        NSMutableArray *out = [NSMutableArray array];
        for (NSExpression *e in _collection) [out addObject:[e expressionValueWithObject:object context:context] ?: [NSNull null]];
        return out;
    }
    case NSBlockExpressionType: return _block(object, _args, context);
    case NSSubqueryExpressionType: {
        /* the members of the collection for which the predicate holds, with $variable bound to each */
        id coll = [_collection isKindOfClass:[NSExpression class]] ? [(NSExpression *)_collection expressionValueWithObject:object context:context] : _collection;
        NSMutableArray *out = [NSMutableArray array];
        NSMutableDictionary *vars = context ? [context mutableCopy] : [NSMutableDictionary dictionary];
        for (id item in as_array(coll)) {
            vars[_variable] = item;
            if ([_predicate evaluateWithObject:item substitutionVariables:vars]) [out addObject:item];
        }
        return out;
    }
    case NSUnionSetExpressionType: case NSIntersectSetExpressionType: case NSMinusSetExpressionType: {
        NSMutableSet *s = [as_set([_left expressionValueWithObject:object context:context]) mutableCopy];
        NSSet *r = as_set([_right expressionValueWithObject:object context:context]);
        if (_type == NSUnionSetExpressionType) [s unionSet:r]; else if (_type == NSIntersectSetExpressionType) [s intersectSet:r]; else [s minusSet:r];
        return s;
    }
    case NSConditionalExpressionType: {
        BOOL c = [_predicate evaluateWithObject:object substitutionVariables:context];
        return [(c ? _left : _right) expressionValueWithObject:object context:context];
    }
    case NSFunctionExpressionType: {
        NSMutableArray *vals = [NSMutableArray array];
        for (NSExpression *e in _args) [vals addObject:[e expressionValueWithObject:object context:context] ?: [NSNull null]];
        if (_operand) {                                 /* FUNCTION(target, 'selector:', args): an object-returning method */
            id target = [_operand expressionValueWithObject:object context:context];
            SEL sel = NSSelectorFromString(_function);
            if (![target respondsToSelector:sel]) [NSException raise:NSInvalidArgumentException format:@"%@ does not respond to %@", target, _function];
            switch (vals.count) {
            case 0: return ((id (*)(id, SEL))objc_msgSend)(target, sel);
            case 1: return ((id (*)(id, SEL, id))objc_msgSend)(target, sel, vals[0] == [NSNull null] ? nil : vals[0]);
            default: return ((id (*)(id, SEL, id, id))objc_msgSend)(target, sel, vals[0] == [NSNull null] ? nil : vals[0], vals[1] == [NSNull null] ? nil : vals[1]);
            }
        }
        return call_builtin(_function, vals);
    }
    default: return nil;
    }
}
static NSString *quoted(NSString *s) {
    return [NSString stringWithFormat:@"\"%@\"", [[s stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"] stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];
}
- (NSString *)predicateFormat_isim {
    switch (_type) {
    case NSConstantValueExpressionType:
        if (!_constant || _constant == [NSNull null]) return @"nil";
        if ([_constant isKindOfClass:[NSString class]]) return quoted(_constant);
        if ([_constant isKindOfClass:[_IsimIndexSymbol_isim class]]) return [_constant name];
        if ([_constant isKindOfClass:[NSArray class]]) {
            NSMutableArray *p = [NSMutableArray array];
            for (id o in _constant) [p addObject:[[NSExpression expressionForConstantValue:o] predicateFormat_isim]];
            return [NSString stringWithFormat:@"{%@}", [p componentsJoinedByString:@", "]];
        }
        if ([_constant isKindOfClass:[NSDate class]]) return [NSString stringWithFormat:@"CAST(%.6f, \"NSDate\")", [_constant timeIntervalSinceReferenceDate]];
        return [_constant description];
    case NSEvaluatedObjectExpressionType: return @"SELF";
    case NSVariableExpressionType: return [@"$" stringByAppendingString:_variable];
    case NSKeyPathExpressionType: return _keyPath;
    case NSAnyKeyExpressionType: return @"ANYKEY";
    case NSAggregateExpressionType: return [NSString stringWithFormat:@"{%@}", [[_collection valueForKey:@"predicateFormat_isim"] componentsJoinedByString:@", "]];
    case NSSubqueryExpressionType:
        return [NSString stringWithFormat:@"SUBQUERY(%@, $%@, %@)", [_collection isKindOfClass:[NSExpression class]] ? [_collection predicateFormat_isim] : [_collection description], _variable, _predicate.predicateFormat];
    case NSUnionSetExpressionType: return [NSString stringWithFormat:@"%@ UNION %@", [_left predicateFormat_isim], [_right predicateFormat_isim]];
    case NSIntersectSetExpressionType: return [NSString stringWithFormat:@"%@ INTERSECT %@", [_left predicateFormat_isim], [_right predicateFormat_isim]];
    case NSMinusSetExpressionType: return [NSString stringWithFormat:@"%@ MINUS %@", [_left predicateFormat_isim], [_right predicateFormat_isim]];
    case NSConditionalExpressionType: return [NSString stringWithFormat:@"TERNARY(%@, %@, %@)", _predicate.predicateFormat, [_left predicateFormat_isim], [_right predicateFormat_isim]];
    case NSBlockExpressionType: return @"BLOCK";
    case NSFunctionExpressionType: {
        NSDictionary *ops = @{ @"add:to:": @"+", @"from:subtract:": @"-", @"multiply:by:": @"*", @"divide:by:": @"/", @"raise:toPower:": @"**" };
        NSArray *args = [_args valueForKey:@"predicateFormat_isim"];
        if (_operand && [_function isEqualToString:@"valueForKeyPath:"] && _args.count == 1 && [_args[0] expressionType] == NSConstantValueExpressionType)
            return [NSString stringWithFormat:@"%@.%@", [_operand predicateFormat_isim], [_args[0] constantValue]];     /* $x.name */
        if (_operand) return [NSString stringWithFormat:@"FUNCTION(%@, %@%@%@)", [_operand predicateFormat_isim], quoted(_function), args.count ? @", " : @"", [args componentsJoinedByString:@", "]];
        if (ops[_function] && _args.count == 2) return [NSString stringWithFormat:@"%@ %@ %@", args[0], ops[_function], args[1]];
        if ([_function isEqualToString:@"objectFrom:withIndex:"] && _args.count == 2) return [NSString stringWithFormat:@"%@[%@]", args[0], args[1]];
        if ([_function isEqualToString:@"castObject:toType:"] && _args.count == 2) return [NSString stringWithFormat:@"CAST(%@, %@)", args[0], args[1]];
        if (![_function hasSuffix:@":"]) return [NSString stringWithFormat:@"%@()", _function];
        return [NSString stringWithFormat:@"%@(%@)", _function, [args componentsJoinedByString:@", "]];
    }
    default: return @"<expression>";
    }
}
- (NSString *)description { return [self predicateFormat_isim]; }
static NSArray *subst_all(NSArray *a, NSDictionary *vars) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSExpression *e in a) [out addObject:[e _isim_substituting:vars]];
    return out;
}
- (NSExpression *)_isim_substituting:(NSDictionary *)vars {
    switch (_type) {
    case NSVariableExpressionType: return vars[_variable] ? [NSExpression expressionForConstantValue:vars[_variable]] : self;
    case NSAggregateExpressionType: return [NSExpression expressionForAggregate:subst_all(_collection, vars)];
    case NSFunctionExpressionType: {
        NSExpression *e = [NSExpression expressionForFunction:_function arguments:subst_all(_args, vars)];
        e->_operand = [_operand _isim_substituting:vars];
        return e;
    }
    case NSSubqueryExpressionType: {
        NSMutableDictionary *inner = [vars mutableCopy]; [inner removeObjectForKey:_variable];     /* the iterator stays a variable */
        return [NSExpression expressionForSubquery:[_collection isKindOfClass:[NSExpression class]] ? [_collection _isim_substituting:vars] : _collection
                             usingIteratorVariable:_variable predicate:[_predicate predicateWithSubstitutionVariables:inner]];
    }
    case NSUnionSetExpressionType: case NSIntersectSetExpressionType: case NSMinusSetExpressionType:
        return set_expr(_type, [_left _isim_substituting:vars], [_right _isim_substituting:vars]);
    case NSConditionalExpressionType:
        return [NSExpression expressionForConditional:[_predicate predicateWithSubstitutionVariables:vars] trueExpression:[_left _isim_substituting:vars] falseExpression:[_right _isim_substituting:vars]];
    default: return self;
    }
}
@end

/* ================= predicates ================= */
static NSPredicate *parse_predicate(NSString *format, va_list *ap, NSArray *args);
@implementation NSPredicate
+ (NSPredicate *)predicateWithFormat:(NSString *)format arguments:(va_list)ap {
    va_list copy; va_copy(copy, ap);
    NSPredicate *p = parse_predicate(format, &copy, nil);
    va_end(copy);
    return p;
}
+ (NSPredicate *)predicateWithFormat:(NSString *)format argumentArray:(NSArray *)args { return parse_predicate(format, NULL, args ?: @[]); }
+ (NSPredicate *)predicateWithValue:(BOOL)value { return [[_IsimValuePredicate_isim alloc] initWithIsimValue:value]; }
+ (NSPredicate *)predicateWithBlock:(BOOL (^)(id, NSDictionary *))block { return [[_IsimBlockPredicate_isim alloc] initWithIsimBlock:block]; }
+ (NSPredicate *)predicateWithFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format); NSPredicate *p = [self predicateWithFormat:format arguments:ap]; va_end(ap); return p;
}
/* archived as its format string (block predicates cannot be archived, as on iOS) */
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {
    if ([self.predicateFormat containsString:@"BLOCK"]) [NSException raise:NSInvalidArgumentException format:@"Block predicates cannot be archived"];
    [c encodeObject:self.predicateFormat forKey:@"NSPredicateFormat"];
}
- (instancetype)initWithCoder:(NSCoder *)c {
    NSString *fmt = [c decodeObjectOfClass:[NSString class] forKey:@"NSPredicateFormat"];
    return fmt.length ? [NSPredicate predicateWithFormat:fmt argumentArray:@[]] : [NSPredicate predicateWithValue:NO];
}
- (id)copyWithZone:(NSZone *)z { return self; }
- (BOOL)evaluateWithObject:(id)object { return [self evaluateWithObject:object substitutionVariables:nil]; }
- (BOOL)evaluateWithObject:(id)object substitutionVariables:(NSDictionary *)vars { return NO; }
- (NSString *)predicateFormat { return @""; }
- (NSString *)description { return self.predicateFormat; }
- (instancetype)predicateWithSubstitutionVariables:(NSDictionary *)vars { return self; }
- (void)allowEvaluation {}
@end

@implementation _IsimValuePredicate_isim { BOOL _v; }
- (instancetype)initWithIsimValue:(BOOL)v { if ((self = [super init])) _v = v; return self; }
- (BOOL)evaluateWithObject:(id)o substitutionVariables:(NSDictionary *)vars { return _v; }
- (NSString *)predicateFormat { return _v ? @"TRUEPREDICATE" : @"FALSEPREDICATE"; }
@end
@implementation _IsimBlockPredicate_isim { BOOL (^_block)(id, NSDictionary *); }
- (instancetype)initWithIsimBlock:(BOOL (^)(id, NSDictionary *))b { if ((self = [super init])) _block = [b copy]; return self; }
- (BOOL)evaluateWithObject:(id)o substitutionVariables:(NSDictionary *)vars { return _block(o, vars); }
- (NSString *)predicateFormat { return @"BLOCKPREDICATE"; }
@end

@implementation NSCompoundPredicate
+ (NSCompoundPredicate *)andPredicateWithSubpredicates:(NSArray<NSPredicate *> *)s { return [[self alloc] initWithType:NSAndPredicateType subpredicates:s]; }
+ (NSCompoundPredicate *)orPredicateWithSubpredicates:(NSArray<NSPredicate *> *)s { return [[self alloc] initWithType:NSOrPredicateType subpredicates:s]; }
+ (NSCompoundPredicate *)notPredicateWithSubpredicate:(NSPredicate *)p { return [[self alloc] initWithType:NSNotPredicateType subpredicates:@[p]]; }
- (instancetype)initWithType:(NSCompoundPredicateType)type subpredicates:(NSArray<NSPredicate *> *)subs {
    if ((self = [super init])) { _compoundPredicateType = type; _subpredicates = [subs copy]; }
    return self;
}
- (BOOL)evaluateWithObject:(id)o substitutionVariables:(NSDictionary *)vars {
    switch (_compoundPredicateType) {
    case NSNotPredicateType: return ![_subpredicates.firstObject evaluateWithObject:o substitutionVariables:vars];
    case NSAndPredicateType: for (NSPredicate *p in _subpredicates) if (![p evaluateWithObject:o substitutionVariables:vars]) return NO; return YES;
    default: for (NSPredicate *p in _subpredicates) if ([p evaluateWithObject:o substitutionVariables:vars]) return YES; return NO;
    }
}
- (NSString *)predicateFormat {
    if (_compoundPredicateType == NSNotPredicateType) return [NSString stringWithFormat:@"NOT %@", [_subpredicates.firstObject predicateFormat]];
    NSMutableArray *parts = [NSMutableArray array];
    for (NSPredicate *p in _subpredicates) [parts addObject:[p isKindOfClass:[NSCompoundPredicate class]] ? [NSString stringWithFormat:@"(%@)", p.predicateFormat] : p.predicateFormat];
    return [parts componentsJoinedByString:_compoundPredicateType == NSAndPredicateType ? @" AND " : @" OR "];
}
- (instancetype)predicateWithSubstitutionVariables:(NSDictionary *)vars {
    NSMutableArray *subs = [NSMutableArray array];
    for (NSPredicate *p in _subpredicates) [subs addObject:[p predicateWithSubstitutionVariables:vars]];
    return [[NSCompoundPredicate alloc] initWithType:_compoundPredicateType subpredicates:subs];
}
@end

@implementation NSComparisonPredicate
+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)l rightExpression:(NSExpression *)r modifier:(NSComparisonPredicateModifier)m type:(NSPredicateOperatorType)t options:(NSComparisonPredicateOptions)o {
    return [[self alloc] initWithLeftExpression:l rightExpression:r modifier:m type:t options:o];
}
- (instancetype)initWithLeftExpression:(NSExpression *)l rightExpression:(NSExpression *)r modifier:(NSComparisonPredicateModifier)m type:(NSPredicateOperatorType)t options:(NSComparisonPredicateOptions)o {
    if ((self = [super init])) { _leftExpression = l; _rightExpression = r; _comparisonPredicateModifier = m; _predicateOperatorType = t; _options = o; }
    return self;
}
/* the left value's method, called with the right value, returns the BOOL result */
- (instancetype)initWithLeftExpression:(NSExpression *)l rightExpression:(NSExpression *)r customSelector:(SEL)sel {
    if ((self = [self initWithLeftExpression:l rightExpression:r modifier:NSDirectPredicateModifier type:NSCustomSelectorPredicateOperatorType options:0])) _customSelector = sel;
    return self;
}
+ (NSPredicate *)predicateWithLeftExpression:(NSExpression *)l rightExpression:(NSExpression *)r customSelector:(SEL)sel {
    return [[self alloc] initWithLeftExpression:l rightExpression:r customSelector:sel];
}
static NSString *fold(NSString *s, NSComparisonPredicateOptions o) {
    NSStringCompareOptions m = 0;
    if (o & NSCaseInsensitivePredicateOption) m |= NSCaseInsensitiveSearch;
    if (o & NSDiacriticInsensitivePredicateOption) m |= NSDiacriticInsensitiveSearch;
    return m ? [s stringByFoldingWithOptions:m locale:nil] : s;
}
static NSComparisonResult compare_values(id a, id b, NSComparisonPredicateOptions o) {
    if ([a isKindOfClass:[NSString class]] && [b isKindOfClass:[NSString class]]) return [fold(a, o) compare:fold(b, o)];
    if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]]) return [a compare:b];
    if ([a respondsToSelector:@selector(compare:)]) return [a compare:b];
    return NSOrderedSame;
}
static BOOL equal_values(id a, id b, NSComparisonPredicateOptions o) {
    if (a == b) return YES;
    if (!a || a == [NSNull null] || !b || b == [NSNull null]) return (!a || a == [NSNull null]) && (!b || b == [NSNull null]);
    if ([a isKindOfClass:[NSString class]] && [b isKindOfClass:[NSString class]]) return [fold(a, o) isEqualToString:fold(b, o)];
    if ([a isKindOfClass:[NSNumber class]] && [b isKindOfClass:[NSNumber class]]) return [a compare:b] == NSOrderedSame;
    return [a isEqual:b];
}
static NSString *like_to_regex(NSString *pattern) {
    NSMutableString *out = [NSMutableString stringWithString:@"^"];
    for (NSUInteger i = 0; i < pattern.length; i++) {
        unichar c = [pattern characterAtIndex:i];
        if (c == '*') [out appendString:@".*"];
        else if (c == '?') [out appendString:@"."];
        else if (c == '\\' && i + 1 < pattern.length) { i++; [out appendString:[NSRegularExpression escapedPatternForString:[pattern substringWithRange:NSMakeRange(i, 1)]]]; }
        else [out appendString:[NSRegularExpression escapedPatternForString:[pattern substringWithRange:NSMakeRange(i, 1)]]];
    }
    [out appendString:@"$"];
    return out;
}
enum { ISIM_UTI_CONFORMS = 2000, ISIM_UTI_EQUALS = 2001 };   /* "UTI-CONFORMS-TO", "UTI-EQUALS" */
extern BOOL isim_uti_conforms(NSString *have, NSString *want);   /* ItemProvider.m */
static BOOL test_one(id l, id r, NSPredicateOperatorType t, NSComparisonPredicateOptions o) {
    BOOL nilL = !l || l == [NSNull null], nilR = !r || r == [NSNull null];
    switch ((int)t) {
    case ISIM_UTI_CONFORMS: return [l isKindOfClass:[NSString class]] && [r isKindOfClass:[NSString class]] && isim_uti_conforms(l, r);
    case ISIM_UTI_EQUALS: return [l isKindOfClass:[NSString class]] && [r isKindOfClass:[NSString class]] && [l caseInsensitiveCompare:r] == NSOrderedSame;
    case NSEqualToPredicateOperatorType: return equal_values(l, r, o);
    case NSNotEqualToPredicateOperatorType: return !equal_values(l, r, o);
    case NSLessThanPredicateOperatorType: return !nilL && !nilR && compare_values(l, r, o) == NSOrderedAscending;
    case NSLessThanOrEqualToPredicateOperatorType: return !nilL && !nilR && compare_values(l, r, o) != NSOrderedDescending;
    case NSGreaterThanPredicateOperatorType: return !nilL && !nilR && compare_values(l, r, o) == NSOrderedDescending;
    case NSGreaterThanOrEqualToPredicateOperatorType: return !nilL && !nilR && compare_values(l, r, o) != NSOrderedAscending;
    case NSBeginsWithPredicateOperatorType: case NSEndsWithPredicateOperatorType: {
        if (![l isKindOfClass:[NSString class]] || ![r isKindOfClass:[NSString class]]) return NO;
        NSString *a = fold(l, o), *b = fold(r, o);
        return t == NSBeginsWithPredicateOperatorType ? [a hasPrefix:b] : [a hasSuffix:b];
    }
    case NSLikePredicateOperatorType: case NSMatchesPredicateOperatorType: {
        if (![l isKindOfClass:[NSString class]] || ![r isKindOfClass:[NSString class]]) return NO;
        NSString *pat = t == NSLikePredicateOperatorType ? like_to_regex(r) : [NSString stringWithFormat:@"^(?:%@)$", r];
        NSRegularExpressionOptions ro = (o & NSCaseInsensitivePredicateOption) ? NSRegularExpressionCaseInsensitive : 0;
        NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pat options:ro | NSRegularExpressionDotMatchesLineSeparators error:NULL];
        NSString *subject = (o & NSDiacriticInsensitivePredicateOption) ? fold(l, NSDiacriticInsensitivePredicateOption) : l;
        return re && [re firstMatchInString:subject options:0 range:NSMakeRange(0, subject.length)] != nil;
    }
    case NSInPredicateOperatorType: case NSContainsPredicateOperatorType: {
        id coll = t == NSInPredicateOperatorType ? r : l, item = t == NSInPredicateOperatorType ? l : r;
        if ([coll isKindOfClass:[NSString class]]) {
            if (![item isKindOfClass:[NSString class]]) return NO;
            return [fold(coll, o) rangeOfString:fold(item, o)].location != NSNotFound;
        }
        if ([coll isKindOfClass:[NSDictionary class]]) coll = [coll allValues];
        if ([coll isKindOfClass:[NSSet class]] || [coll isKindOfClass:[NSOrderedSet class]]) coll = [coll valueForKey:@"self"] ?: coll;
        if ([coll respondsToSelector:@selector(countByEnumeratingWithState:objects:count:)])
            for (id x in coll) if (equal_values(x, item, o)) return YES;
        return NO;
    }
    case NSBetweenPredicateOperatorType: {
        if (![r isKindOfClass:[NSArray class]] || [r count] != 2 || nilL) return NO;
        return compare_values(l, r[0], o) != NSOrderedAscending && compare_values(l, r[1], o) != NSOrderedDescending;
    }
    default: return NO;
    }
}
- (BOOL)evaluateWithObject:(id)o substitutionVariables:(NSDictionary *)vars {
    NSMutableDictionary *ctx = vars ? [vars mutableCopy] : [NSMutableDictionary dictionary];
    id l = [_leftExpression expressionValueWithObject:o context:ctx];
    id r = [_rightExpression expressionValueWithObject:o context:ctx];
    if (_predicateOperatorType == NSCustomSelectorPredicateOperatorType && _customSelector)
        return [l respondsToSelector:_customSelector] && ((BOOL (*)(id, SEL, id))objc_msgSend)(l, _customSelector, r);
    if (_comparisonPredicateModifier == NSDirectPredicateModifier) return test_one(l, r, _predicateOperatorType, _options);
    id coll = [l isKindOfClass:[NSSet class]] ? [l allObjects] : [l isKindOfClass:[NSOrderedSet class]] ? [l array] : l;
    if (![coll isKindOfClass:[NSArray class]]) coll = coll ? @[coll] : @[];
    if (_comparisonPredicateModifier == NSAnyPredicateModifier) { for (id x in coll) if (test_one(x, r, _predicateOperatorType, _options)) return YES; return NO; }
    BOOL none = _comparisonPredicateModifier == 3;   /* NONE (internal: ALL NOT) */
    for (id x in coll) { BOOL v = test_one(x, r, _predicateOperatorType, _options); if (none ? v : !v) return NO; }
    return YES;
}
- (NSString *)predicateFormat {
    static NSDictionary *ops;
    if (!ops) ops = @{ @(NSLessThanPredicateOperatorType): @"<", @(NSLessThanOrEqualToPredicateOperatorType): @"<=", @(NSGreaterThanPredicateOperatorType): @">",
                       @(NSGreaterThanOrEqualToPredicateOperatorType): @">=", @(NSEqualToPredicateOperatorType): @"==", @(NSNotEqualToPredicateOperatorType): @"!=",
                       @(NSMatchesPredicateOperatorType): @"MATCHES", @(NSLikePredicateOperatorType): @"LIKE", @(NSBeginsWithPredicateOperatorType): @"BEGINSWITH",
                       @(NSEndsWithPredicateOperatorType): @"ENDSWITH", @(NSInPredicateOperatorType): @"IN", @(NSContainsPredicateOperatorType): @"CONTAINS",
                       @(NSBetweenPredicateOperatorType): @"BETWEEN", @(ISIM_UTI_CONFORMS): @"UTI-CONFORMS-TO", @(ISIM_UTI_EQUALS): @"UTI-EQUALS" };
    if (_predicateOperatorType == NSCustomSelectorPredicateOperatorType && _customSelector)
        return [NSString stringWithFormat:@"%@ %@ %@", [_leftExpression predicateFormat_isim], NSStringFromSelector(_customSelector), [_rightExpression predicateFormat_isim]];
    NSString *opts = _options ? [NSString stringWithFormat:@"[%@%@]", (_options & NSCaseInsensitivePredicateOption) ? @"c" : @"", (_options & NSDiacriticInsensitivePredicateOption) ? @"d" : @""] : @"";
    NSString *mod = _comparisonPredicateModifier == NSAnyPredicateModifier ? @"ANY " : _comparisonPredicateModifier == NSAllPredicateModifier ? @"ALL " : _comparisonPredicateModifier == 3 ? @"NONE " : @"";
    return [NSString stringWithFormat:@"%@%@ %@%@ %@", mod, [_leftExpression predicateFormat_isim], ops[@(_predicateOperatorType)], opts, [_rightExpression predicateFormat_isim]];
}
- (instancetype)predicateWithSubstitutionVariables:(NSDictionary *)vars {
    NSComparisonPredicate *c = [[NSComparisonPredicate alloc] initWithLeftExpression:[_leftExpression _isim_substituting:vars] rightExpression:[_rightExpression _isim_substituting:vars]
                                                                           modifier:_comparisonPredicateModifier type:_predicateOperatorType options:_options];
    c->_customSelector = _customSelector;
    return c;
}
@end

/* ================= format parser ================= */
typedef struct {
    NSString *s; NSUInteger i, n;
    va_list *ap; NSArray *argArray; NSUInteger argIndex;
    pp_jmp *jb; char err[160];
} pparser;
static void pp_ws(pparser *p) { while (p->i < p->n && isspace([p->s characterAtIndex:p->i])) p->i++; }
/* isim has no Objective-C exception unwinding: parse errors jump back to the caller (setjmp), which raises */
static void pp_fail(pparser *p, const char *what) __attribute__((noreturn));
static void pp_fail(pparser *p, const char *what) {
    snprintf(p->err, sizeof p->err, "%s at %lu", what, (unsigned long)p->i);
    __builtin_longjmp(*p->jb, 1);
}
static BOOL pp_word(pparser *p, NSString *word) {     /* case-insensitive keyword followed by a non-identifier char */
    pp_ws(p);
    NSUInteger l = word.length;
    if (p->i + l > p->n) return NO;
    if ([[p->s substringWithRange:NSMakeRange(p->i, l)] caseInsensitiveCompare:word] != NSOrderedSame) return NO;
    if (isalpha([word characterAtIndex:0]) && p->i + l < p->n) { unichar c = [p->s characterAtIndex:p->i + l]; if (isalnum(c) || c == '_') return NO; }
    p->i += l; return YES;
}
static BOOL pp_sym(pparser *p, NSString *sym) {
    pp_ws(p);
    if (p->i + sym.length > p->n || ![[p->s substringWithRange:NSMakeRange(p->i, sym.length)] isEqualToString:sym]) return NO;
    p->i += sym.length; return YES;
}
static id next_arg(pparser *p, char kind, int lng) {
    if (p->argArray) { if (p->argIndex >= p->argArray.count) pp_fail(p, "missing argument"); return p->argArray[p->argIndex++]; }
    if (!p->ap) pp_fail(p, "missing argument");
    switch (kind) {
    case '@': case 'K': { id o = va_arg(*p->ap, id); return o; }
    case 'd': case 'i': return lng >= 1 ? @(va_arg(*p->ap, long long)) : @(va_arg(*p->ap, int));
    case 'u': return lng >= 1 ? @(va_arg(*p->ap, unsigned long long)) : @(va_arg(*p->ap, unsigned int));
    case 'f': case 'g': case 'e': return @(va_arg(*p->ap, double));
    case 's': { const char *c = va_arg(*p->ap, const char *); return c ? @(c) : nil; }
    case 'c': { int c = va_arg(*p->ap, int); char b[2] = { (char)c, 0 }; return @(b); }
    default: return nil;
    }
}
static NSPredicate *pp_or(pparser *p);
static NSExpression *pp_expr(pparser *p);
static NSExpression *pp_primary(pparser *p) {
    pp_ws(p);
    if (p->i >= p->n) pp_fail(p, "unexpected end");
    unichar c = [p->s characterAtIndex:p->i];
    if (c == '(') { p->i++; NSExpression *e = pp_expr(p); if (!pp_sym(p, @")")) pp_fail(p, "expected )"); return e; }
    if (c == '{') {
        p->i++; NSMutableArray *items = [NSMutableArray array];
        pp_ws(p);
        if (!pp_sym(p, @"}")) {
            do { [items addObject:pp_expr(p)]; } while (pp_sym(p, @","));
            if (!pp_sym(p, @"}")) pp_fail(p, "expected }");
        }
        BOOL allConst = YES; for (NSExpression *e in items) if (e.expressionType != NSConstantValueExpressionType) allConst = NO;
        if (allConst) { NSMutableArray *v = [NSMutableArray array]; for (NSExpression *e in items) [v addObject:e.constantValue ?: [NSNull null]]; return [NSExpression expressionForConstantValue:v]; }
        return [NSExpression expressionForAggregate:items];
    }
    if (c == '\'' || c == '"') {
        unichar q = c; p->i++;
        NSMutableString *out = [NSMutableString string];
        while (p->i < p->n && [p->s characterAtIndex:p->i] != q) {
            unichar ch = [p->s characterAtIndex:p->i];
            if (ch == '\\' && p->i + 1 < p->n) {
                p->i++; unichar e = [p->s characterAtIndex:p->i];
                [out appendString:e == 'n' ? @"\n" : e == 't' ? @"\t" : [p->s substringWithRange:NSMakeRange(p->i, 1)]];
            } else {
                NSRange r = [p->s rangeOfComposedCharacterSequenceAtIndex:p->i];
                [out appendString:[p->s substringWithRange:r]]; p->i = NSMaxRange(r) - 1;
            }
            p->i++;
        }
        if (p->i >= p->n) pp_fail(p, "unterminated string");
        p->i++;
        return [NSExpression expressionForConstantValue:out];
    }
    if (c == '%') {
        p->i++;
        int lng = 0;
        while (p->i < p->n && strchr("lqhz", (char)[p->s characterAtIndex:p->i])) { if ([p->s characterAtIndex:p->i] != 'h') lng++; p->i++; }
        if (p->i >= p->n) pp_fail(p, "bad format specifier");
        char k = (char)[p->s characterAtIndex:p->i++];
        id v = next_arg(p, k, lng);
        if (k == 'K') return [NSExpression expressionForKeyPath:[v description]];
        return [NSExpression expressionForConstantValue:v];
    }
    if (c == '$') {
        p->i++; NSUInteger s = p->i;
        while (p->i < p->n && (isalnum([p->s characterAtIndex:p->i]) || [p->s characterAtIndex:p->i] == '_')) p->i++;
        return [NSExpression expressionForVariable:[p->s substringWithRange:NSMakeRange(s, p->i - s)]];
    }
    if (isdigit(c) || ((c == '-' || c == '+') && p->i + 1 < p->n && isdigit([p->s characterAtIndex:p->i + 1]))) {
        NSUInteger s = p->i; p->i++;
        BOOL isFloat = NO;
        while (p->i < p->n) {
            unichar d = [p->s characterAtIndex:p->i];
            if (isdigit(d)) p->i++;
            else if ((d == '.' || d == 'e' || d == 'E') && !(d == '.' && p->i + 1 < p->n && [p->s characterAtIndex:p->i + 1] == '.')) { isFloat = YES; p->i++; }
            else break;
        }
        NSString *num = [p->s substringWithRange:NSMakeRange(s, p->i - s)];
        return [NSExpression expressionForConstantValue:isFloat ? @(num.doubleValue) : @(num.longLongValue)];
    }
    if (pp_word(p, @"SUBQUERY")) {                     /* SUBQUERY(collection, $x, predicate) */
        if (!pp_sym(p, @"(")) pp_fail(p, "expected ( after SUBQUERY");
        NSExpression *coll = pp_expr(p);
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in SUBQUERY");
        NSExpression *var = pp_primary(p);
        if (var.expressionType != NSVariableExpressionType) pp_fail(p, "expected a $variable in SUBQUERY");
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in SUBQUERY");
        NSPredicate *pred = pp_or(p);
        if (!pp_sym(p, @")")) pp_fail(p, "expected ) after SUBQUERY");
        return [NSExpression expressionForSubquery:coll usingIteratorVariable:var.variable predicate:pred];
    }
    if (pp_word(p, @"FUNCTION")) {                     /* FUNCTION(target, 'selector:', args...) */
        if (!pp_sym(p, @"(")) pp_fail(p, "expected ( after FUNCTION");
        NSExpression *target = pp_expr(p);
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in FUNCTION");
        NSExpression *sel = pp_expr(p);
        if (sel.expressionType != NSConstantValueExpressionType || ![sel.constantValue isKindOfClass:[NSString class]]) pp_fail(p, "expected a selector name in FUNCTION");
        NSMutableArray *args = [NSMutableArray array];
        while (pp_sym(p, @",")) [args addObject:pp_expr(p)];
        if (!pp_sym(p, @")")) pp_fail(p, "expected ) after FUNCTION");
        return [NSExpression expressionForFunction:target selectorName:sel.constantValue arguments:args];
    }
    if (pp_word(p, @"TERNARY")) {                      /* TERNARY(predicate, true expression, false expression) */
        if (!pp_sym(p, @"(")) pp_fail(p, "expected ( after TERNARY");
        NSPredicate *pred = pp_or(p);
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in TERNARY");
        NSExpression *t = pp_expr(p);
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in TERNARY");
        NSExpression *f = pp_expr(p);
        if (!pp_sym(p, @")")) pp_fail(p, "expected ) after TERNARY");
        return [NSExpression expressionForConditional:pred trueExpression:t falseExpression:f];
    }
    if (pp_word(p, @"CAST")) {                         /* CAST(expression, 'NSDate' | 'NSNumber' | 'NSString' | 'NSDecimalNumber') */
        if (!pp_sym(p, @"(")) pp_fail(p, "expected ( after CAST");
        NSExpression *v = pp_expr(p);
        if (!pp_sym(p, @",")) pp_fail(p, "expected , in CAST");
        NSExpression *t = pp_expr(p);
        if (!pp_sym(p, @")")) pp_fail(p, "expected ) after CAST");
        NSExpression *e = [NSExpression expressionForFunction:@"castObject:toType:" arguments:@[v, t]];
        if (v.expressionType == NSConstantValueExpressionType && t.expressionType == NSConstantValueExpressionType)
            return [NSExpression expressionForConstantValue:[e expressionValueWithObject:nil context:nil]];   /* CAST(123.0, "NSDate") is a constant */
        return e;
    }
    if (pp_word(p, @"ANYKEY")) return [NSExpression expressionForAnyKey];
    if (pp_word(p, @"TRUE") || pp_word(p, @"YES")) return [NSExpression expressionForConstantValue:@YES];
    if (pp_word(p, @"FALSE") || pp_word(p, @"NO")) return [NSExpression expressionForConstantValue:@NO];
    if (pp_word(p, @"NULL") || pp_word(p, @"NIL")) return [NSExpression expressionForConstantValue:nil];
    if (pp_word(p, @"SELF")) {
        if (pp_sym(p, @".")) { NSExpression *rest = pp_primary(p); return [NSExpression expressionForKeyPath:rest.keyPath]; }
        return [NSExpression expressionForEvaluatedObject];
    }
    if (c == '@' || isalpha(c) || c == '_' || c == '#') {
        NSUInteger s = p->i; p->i++;
        while (p->i < p->n) {
            unichar d = [p->s characterAtIndex:p->i];
            if (isalnum(d) || d == '_' || d == '@') p->i++;
            else if (d == '.' && p->i + 1 < p->n && (isalpha([p->s characterAtIndex:p->i + 1]) || [p->s characterAtIndex:p->i + 1] == '@' || [p->s characterAtIndex:p->i + 1] == '_')) p->i++;
            else break;
        }
        NSString *kp = [p->s substringWithRange:NSMakeRange(s, p->i - s)];
        /* a function: "now()", "sum:(numbers)", "raise:toPower:(2, 3)" */
        NSUInteger save = p->i;
        NSMutableString *fn = [kp mutableCopy];
        while (p->i < p->n && [p->s characterAtIndex:p->i] == ':') {
            [fn appendString:@":"]; p->i++;
            NSUInteger w = p->i;
            while (p->i < p->n && (isalnum([p->s characterAtIndex:p->i]) || [p->s characterAtIndex:p->i] == '_')) p->i++;
            if (p->i < p->n && [p->s characterAtIndex:p->i] == ':') [fn appendString:[p->s substringWithRange:NSMakeRange(w, p->i - w)]];
            else { p->i = w; break; }
        }
        if (p->i < p->n && [p->s characterAtIndex:p->i] == '(' && ![kp containsString:@"."]) {
            p->i++;
            NSMutableArray *args = [NSMutableArray array];
            if (!pp_sym(p, @")")) {
                do { [args addObject:pp_expr(p)]; } while (pp_sym(p, @","));
                if (!pp_sym(p, @")")) pp_fail(p, "expected ) after function arguments");
            }
            return [NSExpression expressionForFunction:fn arguments:args];
        }
        p->i = save;
        if ([kp hasPrefix:@"#"]) kp = [kp substringFromIndex:1];
        return [NSExpression expressionForKeyPath:kp];
    }
    pp_fail(p, "unexpected character");
}
/* postfix: array[index], with FIRST / LAST / SIZE */
/* "$x.name", "SUBQUERY(...).@count": a key path applied to the value of an expression that is not one */
static NSExpression *pp_keypath_suffix(pparser *p, NSExpression *e) {
    NSUInteger s = p->i;
    while (p->i < p->n) {
        unichar d = [p->s characterAtIndex:p->i];
        if (isalnum(d) || d == '_' || d == '@' || (d == '.' && p->i + 1 < p->n && (isalpha([p->s characterAtIndex:p->i + 1]) || [p->s characterAtIndex:p->i + 1] == '@'))) p->i++;
        else break;
    }
    NSString *kp = [p->s substringWithRange:NSMakeRange(s, p->i - s)];
    return [NSExpression expressionForFunction:e selectorName:@"valueForKeyPath:" arguments:@[[NSExpression expressionForConstantValue:kp]]];
}
static NSExpression *pp_postfix(pparser *p) {
    NSExpression *e = pp_primary(p);
    for (;;) {
        if (p->i + 1 < p->n && [p->s characterAtIndex:p->i] == '.' && e.expressionType != NSKeyPathExpressionType &&
            (isalpha([p->s characterAtIndex:p->i + 1]) || [p->s characterAtIndex:p->i + 1] == '@' || [p->s characterAtIndex:p->i + 1] == '_')) {
            p->i++;
            e = pp_keypath_suffix(p, e);
            continue;
        }
        pp_ws(p);
        if (p->i < p->n && [p->s characterAtIndex:p->i] == '[') {
            p->i++;
            NSExpression *idx;
            if (pp_word(p, @"FIRST")) idx = [NSExpression expressionForConstantValue:[_IsimIndexSymbol_isim symbol:@"FIRST"]];
            else if (pp_word(p, @"LAST")) idx = [NSExpression expressionForConstantValue:[_IsimIndexSymbol_isim symbol:@"LAST"]];
            else if (pp_word(p, @"SIZE")) idx = [NSExpression expressionForConstantValue:[_IsimIndexSymbol_isim symbol:@"SIZE"]];
            else idx = pp_expr(p);
            if (!pp_sym(p, @"]")) pp_fail(p, "expected ]");
            e = [NSExpression expressionForFunction:@"objectFrom:withIndex:" arguments:@[e, idx]];
        } else return e;
    }
}
static NSExpression *pp_unary(pparser *p) {
    pp_ws(p);
    if (p->i + 1 < p->n && [p->s characterAtIndex:p->i] == '-' && !isdigit([p->s characterAtIndex:p->i + 1])) {
        p->i++;
        return [NSExpression expressionForFunction:@"from:subtract:" arguments:@[[NSExpression expressionForConstantValue:@0], pp_unary(p)]];
    }
    NSExpression *e = pp_postfix(p);
    if (pp_sym(p, @"**")) e = [NSExpression expressionForFunction:@"raise:toPower:" arguments:@[e, pp_unary(p)]];   /* right-associative */
    return e;
}
static NSExpression *pp_term(pparser *p) {
    NSExpression *e = pp_unary(p);
    for (;;) {
        pp_ws(p);
        if (p->i + 1 < p->n && [p->s characterAtIndex:p->i] == '*' && [p->s characterAtIndex:p->i + 1] == '*') return e;
        if (pp_sym(p, @"*")) e = [NSExpression expressionForFunction:@"multiply:by:" arguments:@[e, pp_unary(p)]];
        else if (pp_sym(p, @"/")) e = [NSExpression expressionForFunction:@"divide:by:" arguments:@[e, pp_unary(p)]];
        else return e;
    }
}
static NSExpression *pp_sum(pparser *p) {
    NSExpression *e = pp_term(p);
    for (;;) {
        if (pp_sym(p, @"+")) e = [NSExpression expressionForFunction:@"add:to:" arguments:@[e, pp_term(p)]];
        else if (p->i < p->n && pp_sym(p, @"-")) e = [NSExpression expressionForFunction:@"from:subtract:" arguments:@[e, pp_term(p)]];
        else return e;
    }
}
/* set expressions: a UNION b, a INTERSECT b, a MINUS b */
static NSExpression *pp_expr(pparser *p) {
    NSExpression *e = pp_sum(p);
    for (;;) {
        if (pp_word(p, @"UNION")) e = [NSExpression expressionForUnionSet:e with:pp_sum(p)];
        else if (pp_word(p, @"INTERSECT")) e = [NSExpression expressionForIntersectSet:e with:pp_sum(p)];
        else if (pp_word(p, @"MINUS")) e = [NSExpression expressionForMinusSet:e with:pp_sum(p)];
        else return e;
    }
}
static NSComparisonPredicateOptions pp_options(pparser *p) {
    NSComparisonPredicateOptions o = 0;
    pp_ws(p);
    if (p->i < p->n && [p->s characterAtIndex:p->i] == '[') {
        p->i++;
        while (p->i < p->n && [p->s characterAtIndex:p->i] != ']') {
            unichar c = [p->s characterAtIndex:p->i++];
            if (c == 'c') o |= NSCaseInsensitivePredicateOption; else if (c == 'd') o |= NSDiacriticInsensitivePredicateOption; else if (c == 'n') o |= NSNormalizedPredicateOption;
        }
        p->i++;
    }
    return o;
}
static NSPredicate *pp_comparison(pparser *p) {
    pp_ws(p);
    if (pp_word(p, @"TRUEPREDICATE")) return [NSPredicate predicateWithValue:YES];
    if (pp_word(p, @"FALSEPREDICATE")) return [NSPredicate predicateWithValue:NO];
    NSUInteger save = p->i;
    if (pp_sym(p, @"(")) {
        /* parenthesized predicate, unless it is an arithmetic sub-expression */
        pp_jmp *outer = p->jb, local;
        p->jb = &local;
        if (!__builtin_setjmp(local)) {
            NSPredicate *inner = pp_or(p);
            if (pp_sym(p, @")")) { p->jb = outer; return inner; }
        }
        p->jb = outer;
        p->i = save;
    }
    NSComparisonPredicateModifier mod = NSDirectPredicateModifier;
    if (pp_word(p, @"ANY") || pp_word(p, @"SOME")) mod = NSAnyPredicateModifier;
    else if (pp_word(p, @"ALL")) mod = NSAllPredicateModifier;
    else if (pp_word(p, @"NONE")) mod = (NSComparisonPredicateModifier)3;
    NSExpression *l = pp_expr(p);
    NSPredicateOperatorType t;
    BOOL negate = NO;
    if (pp_sym(p, @"==") || pp_sym(p, @"=")) t = NSEqualToPredicateOperatorType;
    else if (pp_sym(p, @"!=") || pp_sym(p, @"<>")) t = NSNotEqualToPredicateOperatorType;
    else if (pp_sym(p, @"<=") || pp_sym(p, @"=<")) t = NSLessThanOrEqualToPredicateOperatorType;
    else if (pp_sym(p, @">=") || pp_sym(p, @"=>")) t = NSGreaterThanOrEqualToPredicateOperatorType;
    else if (pp_sym(p, @"<")) t = NSLessThanPredicateOperatorType;
    else if (pp_sym(p, @">")) t = NSGreaterThanPredicateOperatorType;
    else {
        if (pp_word(p, @"NOT")) negate = YES;
        if (pp_word(p, @"BETWEEN")) t = NSBetweenPredicateOperatorType;
        else if (pp_word(p, @"IN")) t = NSInPredicateOperatorType;
        else if (pp_word(p, @"CONTAINS")) t = NSContainsPredicateOperatorType;
        else if (pp_word(p, @"BEGINSWITH")) t = NSBeginsWithPredicateOperatorType;
        else if (pp_word(p, @"ENDSWITH")) t = NSEndsWithPredicateOperatorType;
        else if (pp_word(p, @"LIKE")) t = NSLikePredicateOperatorType;
        else if (pp_word(p, @"MATCHES")) t = NSMatchesPredicateOperatorType;
        else if (pp_word(p, @"UTI-CONFORMS-TO")) t = (NSPredicateOperatorType)ISIM_UTI_CONFORMS;
        else if (pp_word(p, @"UTI-EQUALS")) t = (NSPredicateOperatorType)ISIM_UTI_EQUALS;
        else pp_fail(p, "expected an operator");
    }
    NSComparisonPredicateOptions o = pp_options(p);
    NSExpression *r = pp_expr(p);
    NSPredicate *cp = [NSComparisonPredicate predicateWithLeftExpression:l rightExpression:r modifier:mod type:t options:o];
    return negate ? [NSCompoundPredicate notPredicateWithSubpredicate:cp] : cp;
}
static NSPredicate *pp_not(pparser *p) {
    if (pp_word(p, @"NOT") || pp_sym(p, @"!")) return [NSCompoundPredicate notPredicateWithSubpredicate:pp_not(p)];
    return pp_comparison(p);
}
static NSPredicate *pp_and(pparser *p) {
    NSMutableArray *subs = [NSMutableArray arrayWithObject:pp_not(p)];
    while (pp_word(p, @"AND") || pp_sym(p, @"&&")) [subs addObject:pp_not(p)];
    return subs.count == 1 ? subs[0] : [NSCompoundPredicate andPredicateWithSubpredicates:subs];
}
static NSPredicate *pp_or(pparser *p) {
    NSMutableArray *subs = [NSMutableArray arrayWithObject:pp_and(p)];
    while (pp_word(p, @"OR") || pp_sym(p, @"||")) [subs addObject:pp_and(p)];
    return subs.count == 1 ? subs[0] : [NSCompoundPredicate orPredicateWithSubpredicates:subs];
}
static void raise_parse_error(pparser *p) {
    [NSException raise:NSInvalidArgumentException format:@"Unable to parse the format string \"%@\" (%s)", p->s, p->err];
}
static NSPredicate *parse_predicate(NSString *format, va_list *ap, NSArray *args) {
    pp_jmp top;
    pparser p = { format, 0, format.length, ap, args, 0, &top, "" };
    if (__builtin_setjmp(top)) { raise_parse_error(&p); return nil; }
    NSPredicate *pred = pp_or(&p);
    pp_ws(&p);
    if (p.i < p.n) pp_fail(&p, "unexpected trailing text");
    return pred;
}
@implementation NSPredicate (IsimFormat)
+ (NSExpression *)_isim_expressionWithFormat:(NSString *)format arguments:(va_list *)ap array:(NSArray *)args {
    pp_jmp top;
    pparser p = { format, 0, format.length, ap, args, 0, &top, "" };
    if (__builtin_setjmp(top)) { raise_parse_error(&p); return nil; }
    return pp_expr(&p);
}
@end

/* ================= filtering ================= */
@implementation NSArray (NSPredicateSupport)
- (NSArray *)filteredArrayUsingPredicate:(NSPredicate *)predicate {
    NSMutableArray *out = [NSMutableArray array];
    for (id o in self) if ([predicate evaluateWithObject:o]) [out addObject:o];
    return out;
}
@end
@implementation NSMutableArray (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)predicate {
    for (NSUInteger i = self.count; i-- > 0;) if (![predicate evaluateWithObject:self[i]]) [self removeObjectAtIndex:i];
}
@end
@implementation NSSet (NSPredicateSupport)
- (NSSet *)filteredSetUsingPredicate:(NSPredicate *)predicate {
    NSMutableSet *out = [NSMutableSet set];
    for (id o in self) if ([predicate evaluateWithObject:o]) [out addObject:o];
    return out;
}
@end
@implementation NSMutableSet (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)predicate { for (id o in self.allObjects) if (![predicate evaluateWithObject:o]) [self removeObject:o]; }
@end
@implementation NSOrderedSet (NSPredicateSupport)
- (NSOrderedSet *)filteredOrderedSetUsingPredicate:(NSPredicate *)p { return [NSOrderedSet orderedSetWithArray:[self.array filteredArrayUsingPredicate:p]]; }
@end
@implementation NSMutableOrderedSet (NSPredicateSupport)
- (void)filterUsingPredicate:(NSPredicate *)p { for (id o in self.array) if (![p evaluateWithObject:o]) [self removeObject:o]; }
@end
