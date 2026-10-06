/* isim Foundation (ARC): NSPredicate (format-string parser, comparison/compound/block predicates),
 * NSExpression, and filtering of arrays/sets/ordered sets.
 * Grammar (Apple's "Predicate Format String Syntax", common subset): AND/&&, OR/||, NOT/!, parentheses;
 * =, ==, !=, <>, <, <=, =<, >, >=, =>, BETWEEN, IN, CONTAINS, BEGINSWITH, ENDSWITH, LIKE, MATCHES with [c], [d],
 * [cd] options; ANY/SOME/ALL/NONE; key paths (with @count/@sum/... operators), SELF, $variables, %@ %K %d %i %u %ld
 * %lu %lld %f %lf %s %c, string/number/TRUE/FALSE/YES/NO/NULL/NIL literals, {a, b} aggregates,
 * TRUEPREDICATE/FALSEPREDICATE, FUNCTION-free arithmetic (+ - * /) on numbers. */
#import <Foundation/Foundation.h>
#include <ctype.h>
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
@implementation NSExpression {
    @public NSExpressionType _type; id _constant; NSString *_keyPath, *_variable, *_function; NSArray *_args, *_collection;
    NSExpression *_operand; id (^_block)(id, NSArray *, NSMutableDictionary *);
}
+ (NSExpression *)expressionForConstantValue:(id)obj { NSExpression *e = [[self alloc] initWithExpressionType:NSConstantValueExpressionType]; e->_constant = obj; return e; }
+ (NSExpression *)expressionForEvaluatedObject { return [[self alloc] initWithExpressionType:NSEvaluatedObjectExpressionType]; }
+ (NSExpression *)expressionForVariable:(NSString *)v { NSExpression *e = [[self alloc] initWithExpressionType:NSVariableExpressionType]; e->_variable = [v copy]; return e; }
+ (NSExpression *)expressionForKeyPath:(NSString *)kp { NSExpression *e = [[self alloc] initWithExpressionType:NSKeyPathExpressionType]; e->_keyPath = [kp copy]; return e; }
+ (NSExpression *)expressionForAggregate:(NSArray<NSExpression *> *)subs { NSExpression *e = [[self alloc] initWithExpressionType:NSAggregateExpressionType]; e->_collection = [subs copy]; return e; }
+ (NSExpression *)expressionForFunction:(NSString *)name arguments:(NSArray *)args {
    NSExpression *e = [[self alloc] initWithExpressionType:NSFunctionExpressionType]; e->_function = [name copy]; e->_args = [args copy]; return e;
}
+ (NSExpression *)expressionForBlock:(id (^)(id, NSArray<NSExpression *> *, NSMutableDictionary *))block arguments:(NSArray<NSExpression *> *)args {
    NSExpression *e = [[self alloc] initWithExpressionType:NSBlockExpressionType]; e->_block = [block copy]; e->_args = [args copy]; return e;
}
+ (NSExpression *)expressionWithFormat:(NSString *)fmt, ... {
    va_list ap; va_start(ap, fmt); NSExpression *e = [self expressionWithFormat:fmt arguments:ap]; va_end(ap); return e;
}
- (instancetype)initWithExpressionType:(NSExpressionType)type { if ((self = [super init])) _type = type; return self; }
- (instancetype)init { return [self initWithExpressionType:NSConstantValueExpressionType]; }
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
- (id)copyWithZone:(NSZone *)z { return self; }
- (NSExpressionType)expressionType { return _type; }
- (id)constantValue { return _constant; }
- (NSString *)keyPath { return _keyPath; }
- (NSString *)variable { return _variable; }
- (NSString *)function { return _function; }
- (NSArray *)arguments { return _args; }
- (id)collection { return _collection; }
- (NSExpression *)operand { return _operand; }
static id arith(NSString *op, id a, id b) {
    double x = [a doubleValue], y = [b doubleValue];
    double r = [op isEqualToString:@"add:to:"] ? x + y : [op isEqualToString:@"from:subtract:"] ? x - y : [op isEqualToString:@"multiply:by:"] ? x * y : [op isEqualToString:@"divide:by:"] ? x / y : 0;
    return r == (long long)r && fabs(r) < 9e15 ? @((long long)r) : @(r);
}
- (id)expressionValueWithObject:(id)object context:(NSMutableDictionary *)context {
    switch (_type) {
    case NSConstantValueExpressionType: return _constant;
    case NSEvaluatedObjectExpressionType: return object;
    case NSVariableExpressionType: return context[_variable];
    case NSKeyPathExpressionType: return [_keyPath isEqualToString:@"SELF"] ? object : [object valueForKeyPath:_keyPath];
    case NSAggregateExpressionType: {
        NSMutableArray *out = [NSMutableArray array];
        for (NSExpression *e in _collection) [out addObject:[e expressionValueWithObject:object context:context] ?: [NSNull null]];
        return out;
    }
    case NSBlockExpressionType: return _block(object, _args, context);
    case NSFunctionExpressionType: {
        NSMutableArray *vals = [NSMutableArray array];
        for (NSExpression *e in _args) [vals addObject:[e expressionValueWithObject:object context:context] ?: [NSNull null]];
        if (vals.count == 2 && [@[@"add:to:", @"from:subtract:", @"multiply:by:", @"divide:by:"] containsObject:_function]) return arith(_function, vals[0], vals[1]);
        if (vals.count == 1 && [vals[0] isKindOfClass:[NSArray class]]) {
            NSArray *a = vals[0];
            if ([_function isEqualToString:@"count:"]) return @(a.count);
            if ([_function isEqualToString:@"sum:"]) return [a valueForKeyPath:@"@sum.self"];
            if ([_function isEqualToString:@"average:"]) return [a valueForKeyPath:@"@avg.self"];
            if ([_function isEqualToString:@"max:"]) return [a valueForKeyPath:@"@max.self"];
            if ([_function isEqualToString:@"min:"]) return [a valueForKeyPath:@"@min.self"];
        }
        if ([_function isEqualToString:@"lowercase:"]) return [vals[0] lowercaseString];
        if ([_function isEqualToString:@"uppercase:"]) return [vals[0] uppercaseString];
        if ([_function isEqualToString:@"now"]) return [NSDate date];
        [NSException raise:NSInvalidArgumentException format:@"Unsupported function expression %@", _function];
        return nil;
    }
    default: return nil;
    }
}
- (NSString *)predicateFormat_isim {
    switch (_type) {
    case NSConstantValueExpressionType:
        if (!_constant || _constant == [NSNull null]) return @"nil";
        if ([_constant isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"\"%@\"", _constant];
        if ([_constant isKindOfClass:[NSArray class]]) {
            NSMutableArray *p = [NSMutableArray array];
            for (id o in _constant) [p addObject:[[NSExpression expressionForConstantValue:o] predicateFormat_isim]];
            return [NSString stringWithFormat:@"{%@}", [p componentsJoinedByString:@", "]];
        }
        return [_constant description];
    case NSEvaluatedObjectExpressionType: return @"SELF";
    case NSVariableExpressionType: return [@"$" stringByAppendingString:_variable];
    case NSKeyPathExpressionType: return _keyPath;
    case NSAggregateExpressionType: return [NSString stringWithFormat:@"{%@}", [[_collection valueForKey:@"predicateFormat_isim"] componentsJoinedByString:@", "]];
    case NSFunctionExpressionType: {
        NSDictionary *ops = @{ @"add:to:": @"+", @"from:subtract:": @"-", @"multiply:by:": @"*", @"divide:by:": @"/" };
        if (ops[_function] && _args.count == 2) return [NSString stringWithFormat:@"%@ %@ %@", [_args[0] predicateFormat_isim], ops[_function], [_args[1] predicateFormat_isim]];
        return [NSString stringWithFormat:@"%@(%@)", _function, [[_args valueForKey:@"predicateFormat_isim"] componentsJoinedByString:@", "]];
    }
    default: return @"<expression>";
    }
}
- (NSString *)description { return [self predicateFormat_isim]; }
- (NSExpression *)_isim_substituting:(NSDictionary *)vars {
    if (_type == NSVariableExpressionType && vars[_variable]) return [NSExpression expressionForConstantValue:vars[_variable]];
    if (_type == NSAggregateExpressionType) {
        NSMutableArray *a = [NSMutableArray array]; for (NSExpression *e in _collection) [a addObject:[e _isim_substituting:vars]];
        return [NSExpression expressionForAggregate:a];
    }
    return self;
}
@end

/* ================= predicates ================= */
@implementation NSPredicate
+ (NSPredicate *)predicateWithValue:(BOOL)value { return [[_IsimValuePredicate_isim alloc] initWithIsimValue:value]; }
+ (NSPredicate *)predicateWithBlock:(BOOL (^)(id, NSDictionary *))block { return [[_IsimBlockPredicate_isim alloc] initWithIsimBlock:block]; }
+ (NSPredicate *)predicateWithFormat:(NSString *)format, ... {
    va_list ap; va_start(ap, format); NSPredicate *p = [self predicateWithFormat:format arguments:ap]; va_end(ap); return p;
}
+ (BOOL)supportsSecureCoding { return YES; }
- (void)encodeWithCoder:(NSCoder *)c {}
- (instancetype)initWithCoder:(NSCoder *)c { return [self init]; }
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
static BOOL test_one(id l, id r, NSPredicateOperatorType t, NSComparisonPredicateOptions o) {
    BOOL nilL = !l || l == [NSNull null], nilR = !r || r == [NSNull null];
    switch (t) {
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
                       @(NSBetweenPredicateOperatorType): @"BETWEEN" };
    NSString *opts = _options ? [NSString stringWithFormat:@"[%@%@]", (_options & NSCaseInsensitivePredicateOption) ? @"c" : @"", (_options & NSDiacriticInsensitivePredicateOption) ? @"d" : @""] : @"";
    NSString *mod = _comparisonPredicateModifier == NSAnyPredicateModifier ? @"ANY " : _comparisonPredicateModifier == NSAllPredicateModifier ? @"ALL " : _comparisonPredicateModifier == 3 ? @"NONE " : @"";
    return [NSString stringWithFormat:@"%@%@ %@%@ %@", mod, [_leftExpression predicateFormat_isim], ops[@(_predicateOperatorType)], opts, [_rightExpression predicateFormat_isim]];
}
- (instancetype)predicateWithSubstitutionVariables:(NSDictionary *)vars {
    return [[NSComparisonPredicate alloc] initWithLeftExpression:[_leftExpression _isim_substituting:vars] rightExpression:[_rightExpression _isim_substituting:vars]
                                                        modifier:_comparisonPredicateModifier type:_predicateOperatorType options:_options];
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
        if ([kp hasPrefix:@"#"]) kp = [kp substringFromIndex:1];
        return [NSExpression expressionForKeyPath:kp];
    }
    pp_fail(p, "unexpected character");
}
static NSExpression *pp_term(pparser *p) {
    NSExpression *e = pp_primary(p);
    for (;;) {
        if (pp_sym(p, @"*")) e = [NSExpression expressionForFunction:@"multiply:by:" arguments:@[e, pp_primary(p)]];
        else if (pp_sym(p, @"/")) e = [NSExpression expressionForFunction:@"divide:by:" arguments:@[e, pp_primary(p)]];
        else return e;
    }
}
static NSExpression *pp_expr(pparser *p) {
    NSExpression *e = pp_term(p);
    for (;;) {
        if (pp_sym(p, @"+")) e = [NSExpression expressionForFunction:@"add:to:" arguments:@[e, pp_term(p)]];
        else if (p->i < p->n && pp_sym(p, @"-")) e = [NSExpression expressionForFunction:@"from:subtract:" arguments:@[e, pp_term(p)]];
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
+ (NSPredicate *)predicateWithFormat:(NSString *)format arguments:(va_list)ap {
    va_list copy; va_copy(copy, ap);
    NSPredicate *p = parse_predicate(format, &copy, nil);
    va_end(copy);
    return p;
}
+ (NSPredicate *)predicateWithFormat:(NSString *)format argumentArray:(NSArray *)args { return parse_predicate(format, NULL, args ?: @[]); }
+ (NSExpression *)_isim_expressionWithFormat:(NSString *)format arguments:(va_list *)ap array:(NSArray *)args {
    pp_jmp top;
    pparser p = { format, 0, format.length, ap, args, 0, &top, "" };
    if (__builtin_setjmp(top)) { raise_parse_error(&p); return nil; }
    return pp_expr(&p);
}
@end
@implementation NSExpression (IsimFormat)
+ (NSExpression *)expressionWithFormat:(NSString *)fmt arguments:(va_list)ap {
    va_list copy; va_copy(copy, ap);
    NSExpression *e = [NSPredicate _isim_expressionWithFormat:fmt arguments:&copy array:nil];
    va_end(copy);
    return e;
}
+ (NSExpression *)expressionWithFormat:(NSString *)fmt argumentArray:(NSArray *)args { return [NSPredicate _isim_expressionWithFormat:fmt arguments:NULL array:args ?: @[]]; }
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
