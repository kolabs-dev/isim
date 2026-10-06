/* isim Foundation (ARC): NSValueTransformer (named registry, the built-in boolean/nil transformers) and
 * NSSecureUnarchiveFromDataTransformer / NSKeyedUnarchiveFromDataTransformer (keyed archives; Core Data's
 * Transformable attributes use them). */
#import <Foundation/Foundation.h>

NSValueTransformerName const NSNegateBooleanTransformerName = @"NSNegateBoolean";
NSValueTransformerName const NSIsNilTransformerName = @"NSIsNil";
NSValueTransformerName const NSIsNotNilTransformerName = @"NSIsNotNil";
NSValueTransformerName const NSUnarchiveFromDataTransformerName = @"NSUnarchiveFromData";
NSValueTransformerName const NSKeyedUnarchiveFromDataTransformerName = @"NSKeyedUnarchiveFromData";
NSValueTransformerName const NSSecureUnarchiveFromDataTransformerName = @"NSSecureUnarchiveFromData";

@interface _IsimBoolTransformer : NSValueTransformer { @public int _kind; }   /* 0 negate, 1 is nil, 2 is not nil */
@end
@implementation _IsimBoolTransformer
+ (Class)transformedValueClass { return [NSNumber class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)v {
    if (_kind == 0) return @(![v boolValue]);
    return @(_kind == 1 ? v == nil : v != nil);
}
- (id)reverseTransformedValue:(id)v { return _kind == 0 ? @(![v boolValue]) : nil; }
@end

/* unsecured keyed unarchiving (NSKeyedUnarchiveFromData / NSUnarchiveFromData) */
@interface _IsimKeyedUnarchiveTransformer : NSValueTransformer
@end
@implementation _IsimKeyedUnarchiveTransformer
+ (Class)transformedValueClass { return [NSObject class]; }
+ (BOOL)allowsReverseTransformation { return YES; }
- (id)transformedValue:(id)v { return [v isKindOfClass:[NSData class]] ? [NSKeyedUnarchiver unarchiveObjectWithData:v] : nil; }
- (id)reverseTransformedValue:(id)v { return v ? [NSKeyedArchiver archivedDataWithRootObject:v] : nil; }
@end

static NSMutableDictionary<NSString *, NSValueTransformer *> *registry(void) {
    static NSMutableDictionary *r;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        r = [NSMutableDictionary dictionary];
        for (int k = 0; k < 3; k++) {
            _IsimBoolTransformer *t = [_IsimBoolTransformer new]; t->_kind = k;
            r[k == 0 ? NSNegateBooleanTransformerName : k == 1 ? NSIsNilTransformerName : NSIsNotNilTransformerName] = t;
        }
        r[NSKeyedUnarchiveFromDataTransformerName] = [_IsimKeyedUnarchiveTransformer new];
        r[NSUnarchiveFromDataTransformerName] = r[NSKeyedUnarchiveFromDataTransformerName];
        r[NSSecureUnarchiveFromDataTransformerName] = [NSSecureUnarchiveFromDataTransformer new];
    });
    return r;
}

@implementation NSValueTransformer
+ (void)setValueTransformer:(NSValueTransformer *)t forName:(NSValueTransformerName)name {
    NSMutableDictionary *r = registry();
    @synchronized (r) { if (t) r[name] = t; else [r removeObjectForKey:name]; }
}
+ (NSValueTransformer *)valueTransformerForName:(NSValueTransformerName)name {
    NSMutableDictionary *r = registry();
    NSValueTransformer *t;
    @synchronized (r) { t = r[name]; }
    if (!t) {   /* Apple: a class name registers an instance of that NSValueTransformer subclass on first use */
        Class c = NSClassFromString(name);
        if (c && [c isSubclassOfClass:[NSValueTransformer class]]) { t = [c new]; @synchronized (r) { r[name] = t; } }
    }
    return t;
}
+ (NSArray<NSValueTransformerName> *)valueTransformerNames { NSMutableDictionary *r = registry(); @synchronized (r) { return r.allKeys; } }
+ (Class)transformedValueClass { return [NSObject class]; }
+ (BOOL)allowsReverseTransformation { return NO; }
- (id)transformedValue:(id)value { return value; }
- (id)reverseTransformedValue:(id)value {
    if (![[self class] allowsReverseTransformation]) {
        [NSException raise:NSInvalidArgumentException format:@"%@ does not support reverse transformation", [self class]];
        return nil;
    }
    return [self transformedValue:value];
}
@end

@implementation NSSecureUnarchiveFromDataTransformer
+ (NSArray<Class> *)allowedTopLevelClasses {
    return @[[NSArray class], [NSDictionary class], [NSSet class], [NSString class], [NSNumber class], [NSDate class],
             [NSData class], [NSURL class], [NSUUID class], [NSNull class]];
}
+ (BOOL)allowsReverseTransformation { return YES; }
+ (Class)transformedValueClass { return [NSObject class]; }
- (id)transformedValue:(id)value {
    if (![value isKindOfClass:[NSData class]]) return nil;
    NSError *err = nil;
    id o = [NSKeyedUnarchiver unarchivedObjectOfClasses:[NSSet setWithArray:[[self class] allowedTopLevelClasses]] fromData:value error:&err];
    if (!o && err) NSLog(@"NSSecureUnarchiveFromDataTransformer: %@", err);
    return o;
}
- (id)reverseTransformedValue:(id)value {
    if (!value) return nil;
    BOOL allowed = NO;
    for (Class c in [[self class] allowedTopLevelClasses]) if ([value isKindOfClass:c]) { allowed = YES; break; }
    if (!allowed) { NSLog(@"NSSecureUnarchiveFromDataTransformer: %@ is not an allowed top-level class", [value class]); return nil; }
    NSError *err = nil;
    NSData *d = [NSKeyedArchiver archivedDataWithRootObject:value requiringSecureCoding:YES error:&err];
    if (!d && err) NSLog(@"NSSecureUnarchiveFromDataTransformer: %@", err);
    return d;
}
@end
