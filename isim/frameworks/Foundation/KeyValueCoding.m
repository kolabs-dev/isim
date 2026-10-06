/* isim Foundation (ARC): key-value coding (valueForKey:, setValue:forKey:, key paths, collection operators)
 * and key-value observing.
 *
 * KVC follows Apple's search order: accessor methods (key, getKey, isKey, _key / setKey:, _setKey:), then
 * instance variables (_key, _isKey, key, isKey) when +accessInstanceVariablesDirectly; scalars and common
 * structs are boxed in NSNumber/NSValue.
 * KVO: instead of Apple's dynamic "NSKVONotifying_" subclasses, the observed key's setter is wrapped in place
 * (once per class that defines it) by a trampoline that sends will/didChangeValueForKey: when the object has
 * observers. Manual will/didChange notifications, options (new, old, initial, prior), contexts and key paths
 * (dotted paths are observed on their first key) are supported. */
#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include <pthread.h>
#include <string.h>
#include <ctype.h>
#include "isim_foundation.h"

NSExceptionName const NSUndefinedKeyException = @"NSUnknownKeyException";
NSKeyValueChangeKey const NSKeyValueChangeKindKey = @"kind", NSKeyValueChangeNewKey = @"new", NSKeyValueChangeOldKey = @"old",
    NSKeyValueChangeIndexesKey = @"indexes", NSKeyValueChangeNotificationIsPriorKey = @"notificationIsPrior";
NSString *const NSAverageKeyValueOperator = @"avg", *const NSCountKeyValueOperator = @"count", *const NSDistinctUnionOfArraysKeyValueOperator = @"distinctUnionOfArrays",
    *const NSDistinctUnionOfObjectsKeyValueOperator = @"distinctUnionOfObjects", *const NSDistinctUnionOfSetsKeyValueOperator = @"distinctUnionOfSets",
    *const NSMaximumKeyValueOperator = @"max", *const NSMinimumKeyValueOperator = @"min", *const NSSumKeyValueOperator = @"sum",
    *const NSUnionOfArraysKeyValueOperator = @"unionOfArrays", *const NSUnionOfObjectsKeyValueOperator = @"unionOfObjects", *const NSUnionOfSetsKeyValueOperator = @"unionOfSets";

void object_setIvar_isim(id obj, Ivar v, id value);
/* ---------------- boxing by type encoding ---------------- */
static const char *skip_qualifiers(const char *t) { while (*t && strchr("rnNoORV", *t)) t++; return t; }
static NSString *cap(NSString *key) { return key.length ? [[key substringToIndex:1].uppercaseString stringByAppendingString:[key substringFromIndex:1]] : key; }

static id call_getter(id obj, SEL sel, const char *ret) {
    IMP imp = class_getMethodImplementation(object_getClass(obj), sel);
    ret = skip_qualifiers(ret);
    switch (*ret) {
    case '@': case '#': return ((id (*)(id, SEL))imp)(obj, sel);
    case 'c': return @(((char (*)(id, SEL))imp)(obj, sel));
    case 'B': return @(((BOOL (*)(id, SEL))imp)(obj, sel) ? YES : NO);
    case 'C': return @(((unsigned char (*)(id, SEL))imp)(obj, sel));
    case 's': return @(((short (*)(id, SEL))imp)(obj, sel));
    case 'S': return @(((unsigned short (*)(id, SEL))imp)(obj, sel));
    case 'i': return @(((int (*)(id, SEL))imp)(obj, sel));
    case 'I': return @(((unsigned int (*)(id, SEL))imp)(obj, sel));
    case 'l': case 'q': return @(((long long (*)(id, SEL))imp)(obj, sel));
    case 'L': case 'Q': return @(((unsigned long long (*)(id, SEL))imp)(obj, sel));
    case 'f': return @(((float (*)(id, SEL))imp)(obj, sel));
    case 'd': return @(((double (*)(id, SEL))imp)(obj, sel));
    case '{':
        if (!strncmp(ret, "{CGPoint", 8)) return [NSValue valueWithCGPoint:((CGPoint (*)(id, SEL))imp)(obj, sel)];
        if (!strncmp(ret, "{CGSize", 7)) return [NSValue valueWithCGSize:((CGSize (*)(id, SEL))imp)(obj, sel)];
        if (!strncmp(ret, "{CGRect", 7)) return [NSValue valueWithCGRect:((CGRect (*)(id, SEL))imp)(obj, sel)];
        if (!strncmp(ret, "{_NSRange", 9)) return [NSValue valueWithRange:((NSRange (*)(id, SEL))imp)(obj, sel)];
        return nil;
    case 'v': ((void (*)(id, SEL))imp)(obj, sel); return nil;
    default: return nil;
    }
}
static BOOL call_setter(id obj, SEL sel, const char *arg, id value, NSString *key) {
    IMP imp = class_getMethodImplementation(object_getClass(obj), sel);
    arg = skip_qualifiers(arg);
    if (*arg != '@' && *arg != '#' && !value) { [obj setNilValueForKey:key]; return YES; }
    switch (*arg) {
    case '@': case '#': ((void (*)(id, SEL, id))imp)(obj, sel, value); return YES;
    case 'c': ((void (*)(id, SEL, char))imp)(obj, sel, [value charValue]); return YES;
    case 'B': ((void (*)(id, SEL, BOOL))imp)(obj, sel, [value boolValue]); return YES;
    case 'C': ((void (*)(id, SEL, unsigned char))imp)(obj, sel, [value unsignedCharValue]); return YES;
    case 's': ((void (*)(id, SEL, short))imp)(obj, sel, [value shortValue]); return YES;
    case 'S': ((void (*)(id, SEL, unsigned short))imp)(obj, sel, (unsigned short)[value unsignedIntValue]); return YES;
    case 'i': ((void (*)(id, SEL, int))imp)(obj, sel, [value intValue]); return YES;
    case 'I': ((void (*)(id, SEL, unsigned int))imp)(obj, sel, [value unsignedIntValue]); return YES;
    case 'l': case 'q': ((void (*)(id, SEL, long long))imp)(obj, sel, [value longLongValue]); return YES;
    case 'L': case 'Q': ((void (*)(id, SEL, unsigned long long))imp)(obj, sel, [value unsignedLongLongValue]); return YES;
    case 'f': ((void (*)(id, SEL, float))imp)(obj, sel, [value floatValue]); return YES;
    case 'd': ((void (*)(id, SEL, double))imp)(obj, sel, [value doubleValue]); return YES;
    case '{':
        if (!strncmp(arg, "{CGPoint", 8)) { ((void (*)(id, SEL, CGPoint))imp)(obj, sel, [value CGPointValue]); return YES; }
        if (!strncmp(arg, "{CGSize", 7)) { ((void (*)(id, SEL, CGSize))imp)(obj, sel, [value CGSizeValue]); return YES; }
        if (!strncmp(arg, "{CGRect", 7)) { ((void (*)(id, SEL, CGRect))imp)(obj, sel, [value CGRectValue]); return YES; }
        if (!strncmp(arg, "{_NSRange", 9)) { ((void (*)(id, SEL, NSRange))imp)(obj, sel, [value rangeValue]); return YES; }
        return NO;
    default: return NO;
    }
}
/* the second argument's type in a method type encoding ("v24@0:8q16" -> "q16") */
static const char *arg_type(const char *types, int index) {
    const char *t = types;
    for (int i = 0; i <= index + 3 && t && *t; i++) {     /* return type, self, _cmd, then the arguments */
        t = skip_qualifiers(t);
        if (i == index + 3) return t;
        /* skip one type */
        if (*t == '{' || *t == '(' || *t == '[') {
            char open = *t, close = open == '{' ? '}' : open == '(' ? ')' : ']'; int depth = 0;
            do { if (*t == open) depth++; else if (*t == close) depth--; t++; } while (*t && depth);
        } else if (*t == '^') { t++; if (*t == '{') { int depth = 0; do { if (*t == '{') depth++; else if (*t == '}') depth--; t++; } while (*t && depth); } else t++; }
        else if (*t == '@' && t[1] == '?') t += 2;
        else if (*t == '@' && t[1] == '"') { t += 2; while (*t && *t != '"') t++; if (*t) t++; }
        else t++;
        while (isdigit((unsigned char)*t) || *t == '-') t++;
    }
    return t;
}
static Ivar find_ivar(Class cls, NSString *key) {
    NSArray *names = @[[@"_" stringByAppendingString:key], [@"_is" stringByAppendingString:cap(key)], key, [@"is" stringByAppendingString:cap(key)]];
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        unsigned n = 0; Ivar *list = class_copyIvarList(c, &n);
        for (NSString *want in names)
            for (unsigned i = 0; i < n; i++) if (!strcmp(ivar_getName(list[i]) ?: "", want.UTF8String) && *(ivar_getTypeEncoding(list[i]) ?: "")) { Ivar v = list[i]; free(list); return v; }   /* Swift-only stored properties have no type encoding: not KVC-visible */
        free(list);
    }
    return NULL;
}
static id ivar_value(id obj, Ivar v) {
    const char *t = skip_qualifiers(ivar_getTypeEncoding(v) ?: "@");
    char *p = (char *)(__bridge void *)obj + ivar_getOffset(v);
    switch (*t) {
    case '@': case '#': return (__bridge id)*(void **)(void *)p;
    case 'c': return @(*(char *)p); case 'B': return @(*(BOOL *)p ? YES : NO); case 'C': return @(*(unsigned char *)p);
    case 's': return @(*(short *)p); case 'S': return @(*(unsigned short *)p);
    case 'i': return @(*(int *)p); case 'I': return @(*(unsigned int *)p);
    case 'l': case 'q': return @(*(long long *)p); case 'L': case 'Q': return @(*(unsigned long long *)p);
    case 'f': return @(*(float *)p); case 'd': return @(*(double *)p);
    case '{':
        if (!strncmp(t, "{CGPoint", 8)) return [NSValue valueWithCGPoint:*(CGPoint *)p];
        if (!strncmp(t, "{CGSize", 7)) return [NSValue valueWithCGSize:*(CGSize *)p];
        if (!strncmp(t, "{CGRect", 7)) return [NSValue valueWithCGRect:*(CGRect *)p];
        return nil;
    default: return nil;
    }
}
static BOOL set_ivar(id obj, Ivar v, id value, NSString *key) {
    const char *t = skip_qualifiers(ivar_getTypeEncoding(v) ?: "@");
    char *p = (char *)(__bridge void *)obj + ivar_getOffset(v);
    if (*t != '@' && *t != '#' && *t && !value) { [obj setNilValueForKey:key]; return YES; }
    switch (*t) {
    case '@': case '#': object_setIvar_isim(obj, v, value); return YES;
    case 'c': *(char *)p = [value charValue]; return YES; case 'B': *(BOOL *)p = [value boolValue]; return YES;
    case 'C': *(unsigned char *)p = [value unsignedCharValue]; return YES;
    case 's': *(short *)p = [value shortValue]; return YES; case 'S': *(unsigned short *)p = (unsigned short)[value unsignedIntValue]; return YES;
    case 'i': *(int *)p = [value intValue]; return YES; case 'I': *(unsigned int *)p = [value unsignedIntValue]; return YES;
    case 'l': case 'q': *(long long *)p = [value longLongValue]; return YES;
    case 'L': case 'Q': *(unsigned long long *)p = [value unsignedLongLongValue]; return YES;
    case 'f': *(float *)p = [value floatValue]; return YES; case 'd': *(double *)p = [value doubleValue]; return YES;
    default: return NO;
    }
}
/* strong ivar store (ARC objects): retain new, release old */
void object_setIvar_isim(id obj, Ivar v, id value) {
    void **slot = (void **)(void *)((char *)(__bridge void *)obj + ivar_getOffset(v));
    void *old = *slot;
    *slot = value ? (__bridge_retained void *)value : NULL;
    if (old) (void)(__bridge_transfer id)old;
}

@implementation NSObject (NSKeyValueCoding)
+ (BOOL)accessInstanceVariablesDirectly { return YES; }
- (id)valueForKey:(NSString *)key {
    if (!key) [NSException raise:NSInvalidArgumentException format:@"-[%@ valueForKey:]: attempt to retrieve a value for a nil key", [self class]];
    Class cls = object_getClass(self);
    NSString *C = cap(key);
    for (NSString *name in @[key, [@"get" stringByAppendingString:C], [@"is" stringByAppendingString:C], [@"_" stringByAppendingString:key]]) {
        SEL sel = NSSelectorFromString(name);
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            char ret[64] = "@";
            const char *types = method_getTypeEncoding(m);
            if (types) { const char *e = types; while (*e && !isdigit((unsigned char)*e)) e++; size_t n = (size_t)(e - types); if (n && n < sizeof ret) { memcpy(ret, types, n); ret[n] = 0; } }
            return call_getter(self, sel, ret);
        }
    }
    if ([[self class] accessInstanceVariablesDirectly]) {
        Ivar v = find_ivar(cls, key);
        if (v) return ivar_value(self, v);
    }
    return [self valueForUndefinedKey:key];
}
- (void)setValue:(id)value forKey:(NSString *)key {
    if (!key) [NSException raise:NSInvalidArgumentException format:@"-[%@ setValue:forKey:]: attempt to set a value for a nil key", [self class]];
    Class cls = object_getClass(self);
    NSString *C = cap(key);
    for (NSString *name in @[[NSString stringWithFormat:@"set%@:", C], [NSString stringWithFormat:@"_set%@:", C]]) {
        SEL sel = NSSelectorFromString(name);
        Method m = class_getInstanceMethod(cls, sel);
        if (m) {
            const char *types = method_getTypeEncoding(m) ?: "v@:@";
            if (call_setter(self, sel, arg_type(types, 0), value, key)) return;
        }
    }
    if ([[self class] accessInstanceVariablesDirectly]) {
        Ivar v = find_ivar(cls, key);
        if (v) {
            [self willChangeValueForKey:key];
            BOOL ok = set_ivar(self, v, value, key);
            [self didChangeValueForKey:key];
            if (ok) return;
        }
    }
    [self setValue:value forUndefinedKey:key];
}
- (id)valueForUndefinedKey:(NSString *)key {
    @throw [NSException exceptionWithName:NSUndefinedKeyException
                                   reason:[NSString stringWithFormat:@"[<%@ %p> valueForUndefinedKey:]: this class is not key value coding-compliant for the key %@.", [self class], self, key]
                                 userInfo:@{ @"NSTargetObjectUserInfoKey": self, @"NSUnknownUserInfoKey": key }];
}
- (void)setValue:(id)value forUndefinedKey:(NSString *)key {
    @throw [NSException exceptionWithName:NSUndefinedKeyException
                                   reason:[NSString stringWithFormat:@"[<%@ %p> setValue:forUndefinedKey:]: this class is not key value coding-compliant for the key %@.", [self class], self, key]
                                 userInfo:@{ @"NSTargetObjectUserInfoKey": self, @"NSUnknownUserInfoKey": key }];
}
- (void)setNilValueForKey:(NSString *)key {
    [NSException raise:NSInvalidArgumentException format:@"[<%@ %p> setNilValueForKey]: could not set nil as the value for the key %@.", [self class], self, key];
}
- (id)valueForKeyPath:(NSString *)keyPath {
    NSRange dot = [keyPath rangeOfString:@"."];
    if ([keyPath hasPrefix:@"@"] && ![self isKindOfClass:[NSArray class]] && ![self isKindOfClass:[NSSet class]]) {}
    if (dot.location == NSNotFound) return [self valueForKey:keyPath];
    id first = [self valueForKey:[keyPath substringToIndex:dot.location]];
    return [first valueForKeyPath:[keyPath substringFromIndex:dot.location + 1]];
}
- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
    NSRange dot = [keyPath rangeOfString:@"." options:NSBackwardsSearch];
    if (dot.location == NSNotFound) { [self setValue:value forKey:keyPath]; return; }
    [[self valueForKeyPath:[keyPath substringToIndex:dot.location]] setValue:value forKey:[keyPath substringFromIndex:dot.location + 1]];
}
- (NSDictionary<NSString *, id> *)dictionaryWithValuesForKeys:(NSArray<NSString *> *)keys {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in keys) d[k] = [self valueForKey:k] ?: [NSNull null];
    return d;
}
- (void)setValuesForKeysWithDictionary:(NSDictionary<NSString *, id> *)values {
    [values enumerateKeysAndObjectsUsingBlock:^(NSString *k, id v, BOOL *stop) { [self setValue:v == [NSNull null] ? nil : v forKey:k]; }];
}
- (BOOL)validateValue:(inout id *)ioValue forKey:(NSString *)inKey error:(out NSError **)outError { return YES; }
- (NSMutableArray *)mutableArrayValueForKey:(NSString *)key {
    id v = [self valueForKey:key];
    if ([v isKindOfClass:[NSMutableArray class]]) return v;
    NSMutableArray *m = [v mutableCopy] ?: [NSMutableArray array];
    [self setValue:m forKey:key];
    return m;
}
@end

/* ---------------- collection operators ---------------- */
static id collection_operator(id collection, NSString *keyPath) {
    NSRange dot = [keyPath rangeOfString:@"."];
    NSString *op = [keyPath substringWithRange:NSMakeRange(1, (dot.location == NSNotFound ? keyPath.length : dot.location) - 1)];
    NSString *rest = dot.location == NSNotFound ? nil : [keyPath substringFromIndex:dot.location + 1];
    NSArray *items = [collection isKindOfClass:[NSSet class]] ? [collection allObjects] : collection;
    if ([op isEqualToString:@"count"]) return @(items.count);
    NSMutableArray *vals = [NSMutableArray array];
    for (id o in items) { id v = rest ? [o valueForKeyPath:rest] : o; if (v && v != [NSNull null]) [vals addObject:v]; }
    if ([op isEqualToString:@"sum"] || [op isEqualToString:@"avg"]) {
        double s = 0; for (id v in vals) s += [v doubleValue];
        if ([op isEqualToString:@"avg"]) return vals.count ? @(s / (double)vals.count) : nil;
        return @(s);
    }
    if ([op isEqualToString:@"max"] || [op isEqualToString:@"min"]) {
        id best = nil;
        for (id v in vals) if (!best || ([op isEqualToString:@"max"] ? [v compare:best] == NSOrderedDescending : [v compare:best] == NSOrderedAscending)) best = v;
        return best;
    }
    if ([op isEqualToString:@"unionOfObjects"]) return vals;
    if ([op isEqualToString:@"distinctUnionOfObjects"]) {
        NSMutableArray *out = [NSMutableArray array]; for (id v in vals) if (![out containsObject:v]) [out addObject:v]; return out;
    }
    if ([op isEqualToString:@"unionOfArrays"] || [op isEqualToString:@"distinctUnionOfArrays"] || [op isEqualToString:@"unionOfSets"] || [op isEqualToString:@"distinctUnionOfSets"]) {
        NSMutableArray *out = [NSMutableArray array];
        BOOL distinct = [op hasPrefix:@"distinct"];
        for (id arr in items) for (id o in ([arr isKindOfClass:[NSSet class]] ? [arr allObjects] : arr)) {
            id v = rest ? [o valueForKeyPath:rest] : o;
            if (v && (!distinct || ![out containsObject:v])) [out addObject:v];
        }
        return [op hasSuffix:@"Sets"] ? [NSSet setWithArray:out] : out;
    }
    [NSException raise:NSInvalidArgumentException format:@"[<%@ %p> valueForKeyPath:]: unknown operator @%@", [collection class], collection, op];
    return nil;
}
@implementation NSArray (NSKeyValueCoding)
- (id)valueForKey:(NSString *)key {
    if ([key hasPrefix:@"@"]) return [key isEqualToString:@"@count"] ? @(self.count) : collection_operator(self, key);
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:self.count];
    for (id o in self) [out addObject:[o valueForKey:key] ?: [NSNull null]];
    return out;
}
- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) return collection_operator(self, keyPath);
    return [super valueForKeyPath:keyPath];
}
- (void)setValue:(id)value forKey:(NSString *)key { for (id o in self) [o setValue:value forKey:key]; }
@end
@implementation NSSet (NSKeyValueCoding)
- (id)valueForKey:(NSString *)key {
    if ([key hasPrefix:@"@"]) return [key isEqualToString:@"@count"] ? @(self.count) : collection_operator(self, key);
    NSMutableSet *out = [NSMutableSet set];
    for (id o in self) { id v = [o valueForKey:key]; if (v) [out addObject:v]; }
    return out;
}
- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath hasPrefix:@"@"]) return collection_operator(self, keyPath);
    return [super valueForKeyPath:keyPath];
}
- (void)setValue:(id)value forKey:(NSString *)key { for (id o in self) [o setValue:value forKey:key]; }
@end
@implementation NSDictionary (NSKeyValueCoding)
- (id)valueForKey:(NSString *)key {
    if ([key hasPrefix:@"@"]) return [super valueForKey:[key substringFromIndex:1]];
    return [self objectForKey:key];
}
@end
@implementation NSMutableDictionary (NSKeyValueCoding)
- (void)setValue:(id)value forKey:(NSString *)key { if (value) self[key] = value; else [self removeObjectForKey:key]; }
@end

/* ================= key-value observing ================= */
@interface _IsimKVOObservance : NSObject
@property (nonatomic, unsafe_unretained) id observer;
@property (nonatomic, copy) NSString *keyPath;
@property (nonatomic) NSKeyValueObservingOptions options;
@property (nonatomic) void *context;
@property (nonatomic, strong) NSMutableArray *pendingOld;      /* old values captured in willChange (stack) */
@end
@implementation _IsimKVOObservance
@end
static const char kObservancesKey = 0;
static pthread_mutex_t kvo_lock = PTHREAD_MUTEX_INITIALIZER;
static NSMutableDictionary<NSString *, NSValue *> *swizzled;   /* "Class|sel" -> original IMP */

static NSMutableDictionary<NSString *, NSMutableArray<_IsimKVOObservance *> *> *observances(id obj, BOOL create) {
    NSMutableDictionary *d = objc_getAssociatedObject(obj, &kObservancesKey);
    if (!d && create) { d = [NSMutableDictionary dictionary]; objc_setAssociatedObject(obj, &kObservancesKey, d, OBJC_ASSOCIATION_RETAIN); }
    return d;
}
static NSString *first_key(NSString *keyPath) { NSRange r = [keyPath rangeOfString:@"."]; return r.location == NSNotFound ? keyPath : [keyPath substringToIndex:r.location]; }

/* which original setter to run: the first swizzled class from the object's class up (re-entered through
 * [super setX:], the next one above) */
static __thread struct { void *obj; SEL sel; Class level; int depth; } kvo_stack[16];
static __thread int kvo_sp;
static IMP original_for(id self, SEL _cmd, BOOL *notify) {
    Class start = object_getClass(self);
    *notify = YES;
    for (int i = kvo_sp - 1; i >= 0; i--)
        if (kvo_stack[i].obj == (__bridge void *)self && kvo_stack[i].sel == _cmd) { start = class_getSuperclass(kvo_stack[i].level); *notify = NO; break; }
    pthread_mutex_lock(&kvo_lock);
    IMP imp = NULL; Class found = Nil;
    for (Class c = start; c && !imp; c = class_getSuperclass(c)) {
        NSValue *v = swizzled[[NSString stringWithFormat:@"%s|%s", class_getName(c), sel_getName(_cmd)]];
        if (v) { imp = (IMP)v.pointerValue; found = c; }
    }
    pthread_mutex_unlock(&kvo_lock);
    if (kvo_sp < 16) { kvo_stack[kvo_sp].obj = (__bridge void *)self; kvo_stack[kvo_sp].sel = _cmd; kvo_stack[kvo_sp].level = found; kvo_sp++; }
    return imp;
}
static NSString *key_for_setter(SEL sel) {
    const char *s = sel_getName(sel);                 /* "setFooBar:" -> "fooBar" */
    if (s[0] == '_') s++;
    NSString *k = [@(s + 3) substringToIndex:strlen(s + 3) - 1];
    return k.length ? [[k substringToIndex:1].lowercaseString stringByAppendingString:[k substringFromIndex:1]] : k;
}
#define TRAMPOLINE(name, T) \
static void name(id self, SEL _cmd, T v) { \
    BOOL notify; IMP orig = original_for(self, _cmd, &notify); \
    NSString *key = notify && observances(self, NO).count ? key_for_setter(_cmd) : nil; \
    if (key) [self willChangeValueForKey:key]; \
    if (orig) ((void (*)(id, SEL, T))orig)(self, _cmd, v); \
    if (kvo_sp > 0) kvo_sp--; \
    if (key) [self didChangeValueForKey:key]; \
}
TRAMPOLINE(kvo_set_id, id)
TRAMPOLINE(kvo_set_char, char)
TRAMPOLINE(kvo_set_short, short)
TRAMPOLINE(kvo_set_int, int)
TRAMPOLINE(kvo_set_long, long long)
TRAMPOLINE(kvo_set_float, float)
TRAMPOLINE(kvo_set_double, double)
TRAMPOLINE(kvo_set_point, CGPoint)
TRAMPOLINE(kvo_set_size, CGSize)
TRAMPOLINE(kvo_set_rect, CGRect)
TRAMPOLINE(kvo_set_range, NSRange)

static void install_setter_hook(id obj, NSString *key) {
    SEL sel = NSSelectorFromString([NSString stringWithFormat:@"set%@:", cap(key)]);
    Class cls = object_getClass(obj);
    Method m = class_getInstanceMethod(cls, sel);
    if (!m) return;                                    /* no setter: only manual notifications */
    /* the class that defines the method */
    Class def = cls;
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        Class sup = class_getSuperclass(c);
        Method sm = sup ? class_getInstanceMethod(sup, sel) : NULL;
        if (!sm || sm != m) { def = c; break; }
    }
    NSString *mapKey = [NSString stringWithFormat:@"%s|%s", class_getName(def), sel_getName(sel)];
    pthread_mutex_lock(&kvo_lock);
    if (!swizzled) swizzled = [NSMutableDictionary dictionary];
    BOOL done = swizzled[mapKey] != nil;
    pthread_mutex_unlock(&kvo_lock);
    if (done) return;
    const char *t = skip_qualifiers(arg_type(method_getTypeEncoding(m) ?: "v@:@", 0));
    IMP tramp = NULL;
    switch (*t) {
    case '@': case '#': tramp = (IMP)kvo_set_id; break;
    case 'c': case 'C': case 'B': tramp = (IMP)kvo_set_char; break;
    case 's': case 'S': tramp = (IMP)kvo_set_short; break;
    case 'i': case 'I': tramp = (IMP)kvo_set_int; break;
    case 'l': case 'L': case 'q': case 'Q': tramp = (IMP)kvo_set_long; break;
    case 'f': tramp = (IMP)kvo_set_float; break;
    case 'd': tramp = (IMP)kvo_set_double; break;
    case '{':
        if (!strncmp(t, "{CGPoint", 8)) tramp = (IMP)kvo_set_point;
        else if (!strncmp(t, "{CGSize", 7)) tramp = (IMP)kvo_set_size;
        else if (!strncmp(t, "{CGRect", 7)) tramp = (IMP)kvo_set_rect;
        else if (!strncmp(t, "{_NSRange", 9)) tramp = (IMP)kvo_set_range;
        break;
    default: break;
    }
    if (!tramp) return;
    IMP orig = method_setImplementation(m, tramp);
    pthread_mutex_lock(&kvo_lock);
    swizzled[mapKey] = [NSValue valueWithPointer:(const void *)orig];
    pthread_mutex_unlock(&kvo_lock);
}

@implementation NSObject (NSKeyValueObserving)
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey, id> *)change context:(void *)context {
    [NSException raise:NSInternalInconsistencyException format:@"%@: An -observeValueForKeyPath:ofObject:change:context: message was received but not handled.\nKey path: %@", self, keyPath];
}
@end
@implementation NSObject (NSKeyValueObserverRegistration)
- (void)addObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath options:(NSKeyValueObservingOptions)options context:(void *)context {
    _IsimKVOObservance *o = [_IsimKVOObservance new];
    o.observer = observer; o.keyPath = keyPath; o.options = options; o.context = context; o.pendingOld = [NSMutableArray array];
    NSString *key = first_key(keyPath);
    @synchronized (self) {
        NSMutableDictionary *d = observances(self, YES);
        NSMutableArray *list = d[key] ?: (d[key] = [NSMutableArray array]);
        [list addObject:o];
    }
    install_setter_hook(self, key);
    if (options & NSKeyValueObservingOptionInitial) {
        NSMutableDictionary *change = [@{ NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting) } mutableCopy];
        if (options & NSKeyValueObservingOptionNew) change[NSKeyValueChangeNewKey] = [self valueForKeyPath:keyPath] ?: [NSNull null];
        [observer observeValueForKeyPath:keyPath ofObject:self change:change context:context];
    }
}
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath context:(void *)context {
    @synchronized (self) {
        NSMutableArray *list = observances(self, NO)[first_key(keyPath)];
        for (_IsimKVOObservance *o in [list copy])
            if (o.observer == observer && [o.keyPath isEqualToString:keyPath] && o.context == context) { [list removeObject:o]; return; }
    }
    [NSException raise:NSRangeException format:@"Cannot remove an observer <%@ %p> for the key path \"%@\" from <%@ %p> because it is not registered as an observer.", [observer class], observer, keyPath, [self class], self];
}
- (void)removeObserver:(NSObject *)observer forKeyPath:(NSString *)keyPath {
    @synchronized (self) {
        NSMutableArray *list = observances(self, NO)[first_key(keyPath)];
        for (_IsimKVOObservance *o in [list reverseObjectEnumerator].allObjects)
            if (o.observer == observer && [o.keyPath isEqualToString:keyPath]) { [list removeObject:o]; return; }
    }
    [NSException raise:NSRangeException format:@"Cannot remove an observer <%@ %p> for the key path \"%@\" from <%@ %p> because it is not registered as an observer.", [observer class], observer, keyPath, [self class], self];
}
@end
@implementation NSObject (NSKeyValueObserverNotification)
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key { return YES; }
+ (NSSet<NSString *> *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
    SEL s = NSSelectorFromString([@"keyPathsForValuesAffecting" stringByAppendingString:cap(key)]);
    if ([self respondsToSelector:s]) return ((NSSet *(*)(id, SEL))objc_msgSend)(self, s);
    return [NSSet set];
}
- (NSArray<_IsimKVOObservance *> *)_isim_observancesForKey:(NSString *)key {
    @synchronized (self) {
        NSMutableArray *out = [NSMutableArray arrayWithArray:observances(self, NO)[key] ?: @[]];
        return out;
    }
}
- (void)willChangeValueForKey:(NSString *)key {
    NSArray *list = [self _isim_observancesForKey:key];
    for (_IsimKVOObservance *o in list) {
        id old = (o.options & NSKeyValueObservingOptionOld) ? [self valueForKeyPath:o.keyPath] : nil;
        [o.pendingOld addObject:old ?: [NSNull null]];
        if (o.options & NSKeyValueObservingOptionPrior) {
            NSMutableDictionary *change = [@{ NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting), NSKeyValueChangeNotificationIsPriorKey: @YES } mutableCopy];
            if (o.options & NSKeyValueObservingOptionOld) change[NSKeyValueChangeOldKey] = old ?: [NSNull null];
            [o.observer observeValueForKeyPath:o.keyPath ofObject:self change:change context:o.context];
        }
    }
}
- (void)didChangeValueForKey:(NSString *)key {
    NSArray *list = [self _isim_observancesForKey:key];
    for (_IsimKVOObservance *o in list) {
        id old = o.pendingOld.lastObject; if (o.pendingOld.count) [o.pendingOld removeLastObject];
        NSMutableDictionary *change = [@{ NSKeyValueChangeKindKey: @(NSKeyValueChangeSetting) } mutableCopy];
        if (o.options & NSKeyValueObservingOptionOld) change[NSKeyValueChangeOldKey] = old ?: [NSNull null];
        if (o.options & NSKeyValueObservingOptionNew) change[NSKeyValueChangeNewKey] = [self valueForKeyPath:o.keyPath] ?: [NSNull null];
        if (o.observer) [o.observer observeValueForKeyPath:o.keyPath ofObject:self change:change context:o.context];
    }
    /* dependent keys (keyPathsForValuesAffecting<Key>) */
    NSDictionary *all = observances(self, NO);
    for (NSString *other in all.allKeys) {
        if ([other isEqualToString:key]) continue;
        if ([[[self class] keyPathsForValuesAffectingValueForKey:other] containsObject:key]) { [self willChangeValueForKey:other]; [self didChangeValueForKey:other]; }
    }
}
- (void)willChange:(NSKeyValueChange)change valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key { [self willChangeValueForKey:key]; }
- (void)didChange:(NSKeyValueChange)change valuesAtIndexes:(NSIndexSet *)indexes forKey:(NSString *)key { [self didChangeValueForKey:key]; }
@end
