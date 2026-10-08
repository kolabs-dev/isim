/* isim Foundation (ARC): NSCoder, NSKeyedArchiver, NSKeyedUnarchiver.
 * Archives use Apple's keyed-archive layout: a property list (binary by default) with
 *   $archiver = NSKeyedArchiver, $version = 100000, $top = { root = UID }, $objects = [ "$null", ... ]
 * where objects are strings/numbers/data stored directly, or dictionaries of coded keys plus
 * "$class" -> { $classname, $classes }. Foundation's own classes (NSArray, NSDictionary, NSSet, NSString,
 * NSDate, NSURL, NSUUID, NSValue, NSNull, NSData, NSOrderedSet, ...) are coded with Apple's keys
 * (NS.objects, NS.keys, NS.time, NS.string, ...), so archives interoperate. */
#import <Foundation/Foundation.h>
#include <objc/runtime.h>
#include <objc/message.h>
#include "isim_foundation.h"

NSString *const NSKeyedArchiveRootObjectKey = @"root";
NSString *const NSInvalidArchiveOperationException = @"NSInvalidArchiveOperationException";
NSString *const NSInvalidUnarchiveOperationException = @"NSInvalidUnarchiveOperationException";

/* ================= NSCoder (abstract) ================= */
@implementation NSCoder
- (BOOL)allowsKeyedCoding { return NO; }
- (BOOL)requiresSecureCoding { return NO; }
- (NSDecodingFailurePolicy)decodingFailurePolicy { return NSDecodingFailurePolicyRaiseException; }
- (NSError *)error { return nil; }
- (void)failWithError:(NSError *)error {}
- (NSSet *)allowedClasses { return nil; }
#define ABSTRACT { [NSException raise:NSInvalidArgumentException format:@"*** -[NSCoder %s]: cannot be sent to an abstract object of class %@: Create a concrete instance!", sel_getName(_cmd), [self class]]; }
- (void)encodeObject:(id)o forKey:(NSString *)k ABSTRACT
- (void)encodeConditionalObject:(id)o forKey:(NSString *)k { [self encodeObject:o forKey:k]; }
- (void)encodeBool:(BOOL)v forKey:(NSString *)k { [self encodeObject:@(v) forKey:k]; }
- (void)encodeInt:(int)v forKey:(NSString *)k { [self encodeInt64:v forKey:k]; }
- (void)encodeInt32:(int32_t)v forKey:(NSString *)k { [self encodeInt64:v forKey:k]; }
- (void)encodeInteger:(NSInteger)v forKey:(NSString *)k { [self encodeInt64:v forKey:k]; }
- (void)encodeInt64:(int64_t)v forKey:(NSString *)k ABSTRACT
- (void)encodeFloat:(float)v forKey:(NSString *)k { [self encodeDouble:v forKey:k]; }
- (void)encodeDouble:(double)v forKey:(NSString *)k ABSTRACT
- (void)encodeBytes:(const uint8_t *)b length:(NSUInteger)n forKey:(NSString *)k ABSTRACT
- (void)encodeRootObject:(id)o { [self encodeObject:o forKey:NSKeyedArchiveRootObjectKey]; }
- (BOOL)containsValueForKey:(NSString *)k { return NO; }
- (id)decodeObjectForKey:(NSString *)k { return nil; }
- (id)decodeTopLevelObjectForKey:(NSString *)k error:(NSError **)e { return [self decodeObjectForKey:k]; }
- (BOOL)decodeBoolForKey:(NSString *)k { return [[self decodeObjectForKey:k] boolValue]; }
- (int)decodeIntForKey:(NSString *)k { return (int)[self decodeInt64ForKey:k]; }
- (int32_t)decodeInt32ForKey:(NSString *)k { return (int32_t)[self decodeInt64ForKey:k]; }
- (NSInteger)decodeIntegerForKey:(NSString *)k { return (NSInteger)[self decodeInt64ForKey:k]; }
- (int64_t)decodeInt64ForKey:(NSString *)k { return [[self decodeObjectForKey:k] longLongValue]; }
- (float)decodeFloatForKey:(NSString *)k { return (float)[self decodeDoubleForKey:k]; }
- (double)decodeDoubleForKey:(NSString *)k { return [[self decodeObjectForKey:k] doubleValue]; }
- (const uint8_t *)decodeBytesForKey:(NSString *)k returnedLength:(NSUInteger *)n { if (n) *n = 0; return NULL; }
- (id)decodeObjectOfClass:(Class)c forKey:(NSString *)k { return [self decodeObjectOfClasses:[NSSet setWithObject:c] forKey:k]; }
- (id)decodeObjectOfClasses:(NSSet *)classes forKey:(NSString *)k { return [self decodeObjectForKey:k]; }
- (NSArray *)decodeArrayOfObjectsOfClass:(Class)c forKey:(NSString *)k { return [self decodeObjectOfClasses:[NSSet setWithObjects:[NSArray class], c, nil] forKey:k]; }
- (NSDictionary *)decodeDictionaryWithKeysOfClass:(Class)kc objectsOfClass:(Class)oc forKey:(NSString *)k { return [self decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], kc, oc, nil] forKey:k]; }
@end

@implementation NSObject (NSKeyedArchiverObjectSubstitution)
- (Class)classForKeyedArchiver { return [self class]; }
+ (NSArray<NSString *> *)classFallbacksForKeyedArchiver { return @[]; }
@end

/* the archived class name of a class and its superclass chain */
static NSString *coded_name(Class c, NSDictionary *instanceMap, NSDictionary *globalMap) {
    NSString *n = instanceMap[NSStringFromClass(c)] ?: globalMap[NSStringFromClass(c)];
    return n ?: NSStringFromClass(c);
}
static NSMutableDictionary *archiver_global_names, *unarchiver_global_classes;

/* ================= NSKeyedArchiver ================= */
@implementation NSKeyedArchiver {
    NSMutableArray *_objects;                    /* $objects */
    NSMutableDictionary<NSValue *, _IsimPlistUID *> *_uids;   /* object identity -> uid */
    NSMutableArray *_keepAlive;
    NSMutableDictionary<NSString *, _IsimPlistUID *> *_classUIDs;
    NSMutableArray<NSMutableDictionary *> *_stack;
    NSMutableDictionary *_top;
    NSMutableDictionary *_names;
    NSData *_encoded;
    BOOL _secure, _finished;
}
@synthesize outputFormat = _outputFormat;
- (instancetype)init { return [self initRequiringSecureCoding:YES]; }
- (instancetype)initRequiringSecureCoding:(BOOL)secure {
    if ((self = [super init])) {
        _objects = [NSMutableArray arrayWithObject:@"$null"]; _uids = [NSMutableDictionary dictionary]; _keepAlive = [NSMutableArray array];
        _classUIDs = [NSMutableDictionary dictionary]; _stack = [NSMutableArray array]; _top = [NSMutableDictionary dictionary];
        _names = [NSMutableDictionary dictionary]; _secure = secure; _outputFormat = NSPropertyListBinaryFormat_v1_0;
    }
    return self;
}
+ (NSData *)archivedDataWithRootObject:(id)object requiringSecureCoding:(BOOL)secure error:(NSError **)error {
    NSKeyedArchiver *a = [[NSKeyedArchiver alloc] initRequiringSecureCoding:secure];
    if (secure && object && ![[object classForKeyedArchiver] respondsToSelector:@selector(supportsSecureCoding)] && ![a _isim_isPlistType:object]) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:4866 userInfo:@{ @"NSDebugDescription": [NSString stringWithFormat:@"This coder requires that coded objects conform to NSSecureCoding (%@)", [object class]] }];
        return nil;
    }
    [a encodeObject:object forKey:NSKeyedArchiveRootObjectKey];
    [a finishEncoding];
    return a.encodedData;
}
+ (NSData *)archivedDataWithRootObject:(id)rootObject { return [self archivedDataWithRootObject:rootObject requiringSecureCoding:NO error:NULL]; }
+ (BOOL)archiveRootObject:(id)rootObject toFile:(NSString *)path { return [[self archivedDataWithRootObject:rootObject] writeToFile:path atomically:YES]; }
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)requiresSecureCoding { return _secure; }
- (void)setRequiresSecureCoding:(BOOL)v { _secure = v; }
+ (void)setClassName:(NSString *)n forClass:(Class)c {
    @synchronized (self) { if (!archiver_global_names) archiver_global_names = [NSMutableDictionary dictionary]; archiver_global_names[NSStringFromClass(c)] = n; }
}
- (void)setClassName:(NSString *)n forClass:(Class)c { _names[NSStringFromClass(c)] = n; }
+ (NSString *)classNameForClass:(Class)c { return archiver_global_names[NSStringFromClass(c)]; }
- (NSString *)classNameForClass:(Class)c { return _names[NSStringFromClass(c)]; }
- (NSMutableDictionary *)_current { return _stack.lastObject ?: _top; }
- (BOOL)_isim_isPlistType:(id)o {
    return [o isKindOfClass:[NSString class]] || [o isKindOfClass:[NSNumber class]] || [o isKindOfClass:[NSData class]] ||
           [o isKindOfClass:[NSArray class]] || [o isKindOfClass:[NSDictionary class]] || [o isKindOfClass:[NSSet class]] || [o isKindOfClass:[NSDate class]] ||
           [o isKindOfClass:[NSNull class]] || [o isKindOfClass:[NSURL class]] || [o isKindOfClass:[NSValue class]] || [o isKindOfClass:[NSOrderedSet class]];
}
- (_IsimPlistUID *)_classUID:(Class)cls {
    NSString *name = coded_name(cls, _names, archiver_global_names);
    _IsimPlistUID *u = _classUIDs[name];
    if (u) return u;
    NSMutableArray *chain = [NSMutableArray array];
    for (Class c = cls; c; c = class_getSuperclass(c)) {
        NSString *cn = coded_name(c, _names, archiver_global_names);
        /* Apple's concrete Foundation classes archive under their public names */
        [chain addObject:cn];
    }
    u = [_IsimPlistUID uidWithValue:_objects.count];
    [_objects addObject:@{ @"$classname": name, @"$classes": chain }];
    _classUIDs[name] = u;
    return u;
}
/* the public class an object archives as (concrete subclasses map to NSArray, NSMutableArray, ...) */
static Class archive_class(id o) {
    static NSArray *publics;
    if (!publics) publics = @[[NSMutableArray class], [NSArray class], [NSMutableDictionary class], [NSDictionary class], [NSCountedSet class], [NSMutableSet class], [NSSet class],
                              [NSMutableOrderedSet class], [NSOrderedSet class], [NSMutableString class], [NSString class], [NSMutableData class], [NSData class],
                              [NSDate class], [NSURL class], [NSNumber class], [NSValue class], [NSNull class], [NSUUID class], [NSLocale class], [NSTimeZone class],
                              [NSMutableIndexSet class], [NSIndexSet class]];
    Class c = [o classForKeyedArchiver] ?: [o class];
    for (Class p in publics) if ([c isSubclassOfClass:p]) {
        /* Swift subclasses of Foundation classes keep their own class */
        if (c != p && !strchr(class_getName(c), '.') && strncmp(class_getName(c), "_Tt", 3) && [NSStringFromClass(c) hasPrefix:@"__"]) return p;
        if (c == p || [NSStringFromClass(c) hasPrefix:@"__"] || [NSStringFromClass(c) hasPrefix:@"_Isim"]) return p;
        return c;
    }
    return c;
}
/* the Foundation class whose coding a class inherits (custom subclasses that override encodeWithCoder: / initWithCoder:
   are coded through their own methods, which call super) */
static Class builtin_base(Class c) {
    static NSArray *bases;
    if (!bases) bases = @[[NSArray class], [NSDictionary class], [NSSet class], [NSString class], [NSDate class], [NSURL class],
                          [NSNull class], [NSValue class], [NSLocale class], [NSTimeZone class]];
    for (Class b in bases) if ([c isSubclassOfClass:b]) return b;
    return Nil;
}
static BOOL overrides(Class c, Class base, SEL s) {
    return base && c != base && class_getMethodImplementation(c, s) != class_getMethodImplementation(base, s);
}
- (_IsimPlistUID *)_encode:(id)object {
    if (!object) return [_IsimPlistUID uidWithValue:0];
    id<NSKeyedArchiverDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(archiver:willEncodeObject:)]) { object = [d archiver:self willEncodeObject:object]; if (!object) return [_IsimPlistUID uidWithValue:0]; }
    NSValue *key = [NSValue valueWithNonretainedObject:object];
    _IsimPlistUID *existing = _uids[key];
    if (existing) return existing;
    Class cls = archive_class(object);
    /* plain property-list leaves go straight into $objects */
    if ((cls == [NSString class] && [object isKindOfClass:[NSString class]]) || cls == [NSNumber class] || (cls == [NSData class] && [object isKindOfClass:[NSData class]])) {
        _IsimPlistUID *u = [_IsimPlistUID uidWithValue:_objects.count];
        [_objects addObject:cls == [NSString class] ? [object copy] : cls == [NSData class] ? [NSData dataWithData:object] : object];
        _uids[key] = u; [_keepAlive addObject:object];
        return u;
    }
    if (_secure && ![cls respondsToSelector:@selector(supportsSecureCoding)])
        [NSException raise:NSInvalidArchiveOperationException format:@"This coder requires that coded objects conform to NSSecureCoding (%@)", cls];
    _IsimPlistUID *u = [_IsimPlistUID uidWithValue:_objects.count];
    NSMutableDictionary *dict = [NSMutableDictionary dictionary];
    [_objects addObject:dict];
    _uids[key] = u; [_keepAlive addObject:object];
    [_stack addObject:dict];
    [self _encodeContentsOf:object asClass:cls];
    [_stack removeLastObject];
    dict[@"$class"] = [self _classUID:cls];
    if ([d respondsToSelector:@selector(archiver:didEncodeObject:)]) [d archiver:self didEncodeObject:object];
    return u;
}
- (NSArray *)_uidsFor:(id<NSFastEnumeration>)items { NSMutableArray *a = [NSMutableArray array]; for (id o in items) [a addObject:[self _encode:o]]; return a; }
- (void)_encodeContentsOf:(id)o asClass:(Class)cls {
    if (overrides([o class], builtin_base([o class]), @selector(encodeWithCoder:))) { [o encodeWithCoder:self]; return; }
    [self _isim_encodeBuiltin:o asClass:cls];
}
/* the keys of Foundation's own classes (Apple's), into the object being encoded; their encodeWithCoder: calls this */
- (void)_isim_encodeBuiltin:(id)o asClass:(Class)cls {
    NSMutableDictionary *cur = self._current;
    if ([cls isSubclassOfClass:[NSArray class]] && [o isKindOfClass:[NSArray class]]) cur[@"NS.objects"] = [self _uidsFor:o];
    else if ([cls isSubclassOfClass:[NSOrderedSet class]] && [o isKindOfClass:[NSOrderedSet class]]) cur[@"NS.objects"] = [self _uidsFor:[o array]];
    else if ([cls isSubclassOfClass:[NSSet class]] && [o isKindOfClass:[NSSet class]]) {
        if ([o isKindOfClass:[NSCountedSet class]]) { NSMutableArray *all = [NSMutableArray array]; for (id x in o) for (NSUInteger i = 0; i < [o countForObject:x]; i++) [all addObject:x]; cur[@"NS.objects"] = [self _uidsFor:all]; }
        else cur[@"NS.objects"] = [self _uidsFor:o];
    }
    else if ([cls isSubclassOfClass:[NSDictionary class]] && [o isKindOfClass:[NSDictionary class]]) {
        NSArray *keys = [o allKeys];
        NSMutableArray *vals = [NSMutableArray array]; for (id k in keys) [vals addObject:o[k]];
        cur[@"NS.keys"] = [self _uidsFor:keys]; cur[@"NS.objects"] = [self _uidsFor:vals];
    }
    else if ([cls isSubclassOfClass:[NSString class]] && [o isKindOfClass:[NSString class]]) cur[@"NS.string"] = [NSString stringWithString:o];
    else if (cls == [NSMutableData class]) cur[@"NS.data"] = [NSData dataWithData:o];
    else if ([cls isSubclassOfClass:[NSDate class]]) cur[@"NS.time"] = @([o timeIntervalSinceReferenceDate]);
    else if ([cls isSubclassOfClass:[NSURL class]]) { cur[@"NS.base"] = [self _encode:nil]; cur[@"NS.relative"] = [self _encode:[o absoluteString]]; }
    else if ([cls isSubclassOfClass:[NSNull class]]) {}
    else if (cls == [NSUUID class]) { uuid_t b; [o getUUIDBytes:b]; cur[@"NS.uuidbytes"] = [NSData dataWithBytes:b length:16]; }
    else if ([cls isSubclassOfClass:[NSLocale class]]) cur[@"NS.identifier"] = [self _encode:[o localeIdentifier]];
    else if ([cls isSubclassOfClass:[NSTimeZone class]]) cur[@"NS.name"] = [self _encode:[o name]];
    else if ([cls isSubclassOfClass:[NSIndexSet class]] && [o isKindOfClass:[NSIndexSet class]]) {
        NSIndexSet *s = o; NSUInteger rc = [s _rangeCount];
        cur[@"NSRangeCount"] = @(rc);
        if (rc == 1) { NSRange r = [s _rangeAtIndex:0]; cur[@"NSLocation"] = @(r.location); cur[@"NSLength"] = @(r.length); }
        else if (rc > 1) {
            NSMutableData *d = [NSMutableData data];
            for (NSUInteger i = 0; i < rc; i++) { NSRange r = [s _rangeAtIndex:i]; for (NSUInteger v = r.location, k = 0; k < 2; v = r.length, k++) { do { uint8_t b = (uint8_t)(v & 0x7F); v >>= 7; if (v) b |= 0x80; [d appendBytes:&b length:1]; } while (v); } }
            cur[@"NSRangeData"] = d;
        }
    }
    else if ([cls isSubclassOfClass:[NSValue class]] && ![o isKindOfClass:[NSNumber class]]) {
        const char *t = [o objCType];
        if (!strncmp(t, "{CGPoint", 8)) { cur[@"NS.special"] = @1; cur[@"NS.pointval"] = NSStringFromCGPoint([o CGPointValue]); }
        else if (!strncmp(t, "{CGSize", 7)) { cur[@"NS.special"] = @2; cur[@"NS.sizeval"] = NSStringFromCGSize([o CGSizeValue]); }
        else if (!strncmp(t, "{CGRect", 7)) { cur[@"NS.special"] = @3; cur[@"NS.rectval"] = NSStringFromCGRect([o CGRectValue]); }
        else if (!strncmp(t, "{_NSRange", 9)) { NSRange r = [o rangeValue]; cur[@"NS.special"] = @4; cur[@"NS.rangeval.location"] = @(r.location); cur[@"NS.rangeval.length"] = @(r.length); }
    }
    else if ([o respondsToSelector:@selector(encodeWithCoder:)]) [o encodeWithCoder:self];
    else [NSException raise:NSInvalidArgumentException format:@"-[%@ encodeWithCoder:]: unrecognized selector (the class does not conform to NSCoding)", [o class]];
}
- (void)encodeObject:(id)object forKey:(NSString *)key {
    _IsimPlistUID *u = [self _encode:object];
    if (object || !_stack.count) self._current[key] = u;
}
- (void)encodeConditionalObject:(id)object forKey:(NSString *)key { [self encodeObject:object forKey:key]; }
- (void)encodeBool:(BOOL)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeInt64:(int64_t)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeInt:(int)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeInt32:(int32_t)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeInteger:(NSInteger)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeDouble:(double)v forKey:(NSString *)k { self._current[k] = @(v); }
- (void)encodeFloat:(float)v forKey:(NSString *)k { self._current[k] = @((double)v); }
- (void)encodeBytes:(const uint8_t *)b length:(NSUInteger)n forKey:(NSString *)k { self._current[k] = [NSData dataWithBytes:b length:n]; }
- (void)finishEncoding {
    if (_finished) return;
    _finished = YES;
    NSDictionary *plist = @{ @"$archiver": @"NSKeyedArchiver", @"$version": @100000, @"$top": _top, @"$objects": _objects };
    _encoded = _outputFormat == NSPropertyListXMLFormat_v1_0 ? [isim_plist_write_xml(plist) dataUsingEncoding:NSUTF8StringEncoding] : isim_plist_binary(plist);
    id<NSKeyedArchiverDelegate> d = self.delegate;
    if ([d respondsToSelector:@selector(archiverDidFinish:)]) [d archiverDidFinish:self];
}
- (NSData *)encodedData { if (!_finished) [self finishEncoding]; return _encoded; }
@end

/* ================= NSKeyedUnarchiver ================= */
@implementation NSKeyedUnarchiver {
    NSArray *_objects;
    NSDictionary *_top;
    NSMutableDictionary<NSNumber *, id> *_decoded;
    NSMutableArray<NSDictionary *> *_stack;
    NSMutableDictionary *_classes;
    NSSet *_allowed;
    NSMutableArray *_bytesKeepAlive;
    BOOL _secure;
    NSError *_error;
}
@synthesize decodingFailurePolicy = _decodingFailurePolicy;
- (instancetype)initForReadingFromData:(NSData *)data error:(NSError **)error {
    if (!(self = [super init])) return nil;
    NSDictionary *plist = data ? isim_plist_read(data.bytes, data.length, NSPropertyListImmutable, NULL) : nil;
    if (![plist isKindOfClass:[NSDictionary class]] || ![plist[@"$objects"] isKindOfClass:[NSArray class]] || ![plist[@"$top"] isKindOfClass:[NSDictionary class]]) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:4864 userInfo:@{ @"NSDebugDescription": @"The data isn’t in the correct format." }];
        return nil;
    }
    _objects = plist[@"$objects"]; _top = plist[@"$top"];
    _decoded = [NSMutableDictionary dictionary]; _stack = [NSMutableArray array]; _classes = [NSMutableDictionary dictionary]; _bytesKeepAlive = [NSMutableArray array];
    _secure = YES; _decodingFailurePolicy = NSDecodingFailurePolicySetErrorAndReturn;
    return self;
}
- (instancetype)initForReadingWithData:(NSData *)data { NSKeyedUnarchiver *u = [self initForReadingFromData:data error:NULL]; u->_secure = NO; return u; }
- (BOOL)allowsKeyedCoding { return YES; }
- (BOOL)requiresSecureCoding { return _secure; }
- (void)setRequiresSecureCoding:(BOOL)v { _secure = v; }
- (NSError *)error { return _error; }
- (void)failWithError:(NSError *)e { if (!_error) _error = e; }
- (NSSet *)allowedClasses { return _allowed; }
+ (void)setClass:(Class)c forClassName:(NSString *)n {
    @synchronized (self) { if (!unarchiver_global_classes) unarchiver_global_classes = [NSMutableDictionary dictionary]; if (c) unarchiver_global_classes[n] = c; else [unarchiver_global_classes removeObjectForKey:n]; }
}
- (void)setClass:(Class)c forClassName:(NSString *)n { if (c) _classes[n] = c; else [_classes removeObjectForKey:n]; }
+ (Class)classForClassName:(NSString *)n { return unarchiver_global_classes[n]; }
- (Class)classForClassName:(NSString *)n { return _classes[n]; }
+ (id)unarchivedObjectOfClasses:(NSSet<Class> *)classes fromData:(NSData *)data error:(NSError **)error {
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:error];
    if (!u) return nil;
    u->_allowed = classes;
    id root = [u decodeObjectOfClasses:classes forKey:NSKeyedArchiveRootObjectKey];
    if (u->_error && error) *error = u->_error;
    [u finishDecoding];
    return u->_error ? nil : root;
}
+ (id)unarchivedObjectOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error { return [self unarchivedObjectOfClasses:[NSSet setWithObject:cls] fromData:data error:error]; }
+ (id)unarchivedArrayOfObjectsOfClass:(Class)cls fromData:(NSData *)data error:(NSError **)error { return [self unarchivedObjectOfClasses:[NSSet setWithObjects:[NSArray class], cls, nil] fromData:data error:error]; }
+ (id)unarchivedDictionaryWithKeysOfClass:(Class)kc objectsOfClass:(Class)vc fromData:(NSData *)data error:(NSError **)error {
    return [self unarchivedObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], kc, vc, nil] fromData:data error:error];
}
+ (id)unarchiveObjectWithData:(NSData *)data {
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
    if (!u) [NSException raise:NSInvalidArgumentException format:@"*** -[NSKeyedUnarchiver initForReadingWithData:]: incomprehensible archive"];
    u->_secure = NO;
    id root = [u decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    [u finishDecoding];
    return root;
}
+ (id)unarchiveTopLevelObjectWithData:(NSData *)data error:(NSError **)error {
    NSKeyedUnarchiver *u = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:error];
    if (!u) return nil;
    u->_secure = NO;
    id root = [u decodeObjectForKey:NSKeyedArchiveRootObjectKey];
    if (u->_error && error) *error = u->_error;
    return root;
}
+ (id)unarchiveObjectWithFile:(NSString *)path { NSData *d = [NSData dataWithContentsOfFile:path]; return d ? [self unarchiveObjectWithData:d] : nil; }
- (void)finishDecoding { id<NSKeyedUnarchiverDelegate> d = self.delegate; if ([d respondsToSelector:@selector(unarchiverDidFinish:)]) [d unarchiverDidFinish:self]; }
- (NSDictionary *)_current { return _stack.lastObject ?: _top; }
- (BOOL)containsValueForKey:(NSString *)key { return self._current[key] != nil; }
- (void)_fail:(NSString *)message code:(NSInteger)code {
    NSError *e = [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:@{ @"NSDebugDescription": message }];
    if (_decodingFailurePolicy == NSDecodingFailurePolicyRaiseException) [NSException raise:NSInvalidUnarchiveOperationException format:@"%@", message];
    [self failWithError:e];
}
- (Class)_classFor:(NSDictionary *)classDict {
    NSString *name = classDict[@"$classname"];
    Class c = _classes[name] ?: unarchiver_global_classes[name] ?: NSClassFromString(name);
    if (!c) for (NSString *fallback in classDict[@"$classes"]) { c = _classes[fallback] ?: NSClassFromString(fallback); if (c) break; }
    if (!c) {
        id<NSKeyedUnarchiverDelegate> d = self.delegate;
        if ([d respondsToSelector:@selector(unarchiver:cannotDecodeObjectOfClassName:originalClasses:)]) c = [d unarchiver:self cannotDecodeObjectOfClassName:name originalClasses:classDict[@"$classes"] ?: @[]];
    }
    return c;
}
- (BOOL)_allowed:(Class)c classes:(NSSet *)classes {
    if (!_secure || !classes) return YES;
    for (Class a in classes) if ([c isSubclassOfClass:a]) return YES;
    /* Foundation's plist types inside allowed collections */
    for (Class a in classes) if ([a isSubclassOfClass:[NSArray class]] || [a isSubclassOfClass:[NSDictionary class]] || [a isSubclassOfClass:[NSSet class]])
        if ([c isSubclassOfClass:[NSString class]] || [c isSubclassOfClass:[NSNumber class]]) return YES;
    return NO;
}
- (id)_decodeUID:(_IsimPlistUID *)uid classes:(NSSet *)classes {
    if (![uid isKindOfClass:[_IsimPlistUID class]]) return uid == nil ? nil : uid;
    uint64_t idx = uid.value;
    if (idx == 0 || idx >= _objects.count) return nil;
    id cached = _decoded[@(idx)];
    if (cached) return cached == [NSNull null] && ![_objects[idx] isKindOfClass:[NSDictionary class]] ? nil : cached;
    id raw = _objects[idx];
    if (![raw isKindOfClass:[NSDictionary class]] || !raw[@"$class"]) {
        if (_secure && classes && ![self _allowed:[raw class] classes:classes] && ![raw isKindOfClass:[NSString class]] && ![raw isKindOfClass:[NSNumber class]] && ![raw isKindOfClass:[NSData class]]) {
            [self _fail:[NSString stringWithFormat:@"value for key is not an allowed class (%@)", [raw class]] code:4864]; return nil;
        }
        _decoded[@(idx)] = raw;
        return raw;
    }
    NSDictionary *classDict = [self _decodeRawClass:raw[@"$class"]];
    Class c = [self _classFor:classDict];
    if (!c) { [self _fail:[NSString stringWithFormat:@"cannot decode object of class (%@) for key; the class may be defined in source code or a library that is not linked", classDict[@"$classname"]] code:4864]; return nil; }
    if (_secure && classes && ![self _allowed:c classes:classes]) {
        [self _fail:[NSString stringWithFormat:@"value for key is not one of the allowed classes: %@ (got %@)", classes, c] code:4864]; return nil;
    }
    if (_secure && ![c respondsToSelector:@selector(supportsSecureCoding)] && ![self _isFoundation:c]) {
        [self _fail:[NSString stringWithFormat:@"class '%@' does not adopt NSSecureCoding", c] code:4864]; return nil;
    }
    [_stack addObject:raw];
    NSSet *saved = _allowed; if (classes) _allowed = classes;
    id obj = [self _decodeObjectOfClass:c dict:raw index:idx];
    _allowed = saved;
    [_stack removeLastObject];
    id<NSKeyedUnarchiverDelegate> d = self.delegate;
    if (obj && [d respondsToSelector:@selector(unarchiver:didDecodeObject:)]) obj = [d unarchiver:self didDecodeObject:obj];
    if (obj) _decoded[@(idx)] = obj;
    return obj;
}
- (BOOL)_isFoundation:(Class)c {
    for (Class f in @[[NSArray class], [NSDictionary class], [NSSet class], [NSOrderedSet class], [NSString class], [NSData class], [NSDate class], [NSURL class],
                      [NSNumber class], [NSValue class], [NSNull class], [NSUUID class], [NSLocale class], [NSTimeZone class], [NSIndexSet class]])
        if ([c isSubclassOfClass:f]) return YES;
    return NO;
}
- (id)_isim_value:(id)v { return [v isKindOfClass:[_IsimPlistUID class]] ? [self _decodeUID:v classes:nil] : v; }
- (NSDictionary *)_decodeRawClass:(_IsimPlistUID *)u { return [u isKindOfClass:[_IsimPlistUID class]] && u.value < _objects.count ? _objects[u.value] : @{}; }
- (NSArray *)_objectsFrom:(NSArray *)uids {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:uids.count];
    for (_IsimPlistUID *u in uids) { id o = [self _decodeUID:u classes:_allowed]; [out addObject:o ?: [NSNull null]]; }
    return out;
}
/* NS.objects-style lists of references (NSArray, NSSet, NSDictionary's keys and objects); missing objects are NSNull */
- (NSArray *)_isim_decodeObjectsForKey:(NSString *)key { id l = self._current[key]; return [self _objectsFrom:[l isKindOfClass:[NSArray class]] ? l : @[]]; }
- (id)_decodeObjectOfClass:(Class)c dict:(NSDictionary *)raw index:(uint64_t)idx {
    if (overrides(c, builtin_base(c), @selector(initWithCoder:))) return [self _decodeGeneric:c index:idx];
    if ([c isSubclassOfClass:[NSArray class]]) {
        NSArray *items = [self _objectsFrom:raw[@"NS.objects"] ?: @[]];
        return [c isSubclassOfClass:[NSMutableArray class]] ? [items mutableCopy] : [c isEqual:[NSArray class]] ? [items copy] : [[c alloc] initWithArray:items];
    }
    if ([c isSubclassOfClass:[NSOrderedSet class]]) { NSArray *items = [self _objectsFrom:raw[@"NS.objects"] ?: @[]]; return [[c alloc] initWithArray:items]; }
    if ([c isSubclassOfClass:[NSSet class]]) {
        NSArray *items = [self _objectsFrom:raw[@"NS.objects"] ?: @[]];
        if ([c isSubclassOfClass:[NSCountedSet class]]) return [[NSCountedSet alloc] initWithArray:items];
        return [c isSubclassOfClass:[NSMutableSet class]] ? [NSMutableSet setWithArray:items] : [NSSet setWithArray:items];
    }
    if ([c isSubclassOfClass:[NSDictionary class]]) {
        NSArray *keys = [self _objectsFrom:raw[@"NS.keys"] ?: @[]], *vals = [self _objectsFrom:raw[@"NS.objects"] ?: @[]];
        NSMutableDictionary *d = [NSMutableDictionary dictionaryWithCapacity:keys.count];
        for (NSUInteger i = 0; i < keys.count && i < vals.count; i++) d[keys[i]] = vals[i];
        return [c isSubclassOfClass:[NSMutableDictionary class]] ? d : [d copy];
    }
    if ([c isSubclassOfClass:[NSString class]]) {
        id s = raw[@"NS.string"]; if ([s isKindOfClass:[_IsimPlistUID class]]) s = [self _decodeUID:s classes:nil];
        if (!s && [raw[@"NS.bytes"] isKindOfClass:[NSData class]]) s = [[NSString alloc] initWithData:raw[@"NS.bytes"] encoding:NSUTF8StringEncoding];
        return [c isSubclassOfClass:[NSMutableString class]] ? [NSMutableString stringWithString:s ?: @""] : [s copy] ?: @"";
    }
    if ([c isSubclassOfClass:[NSData class]]) {
        id d = raw[@"NS.data"] ?: raw[@"NS.bytes"]; if ([d isKindOfClass:[_IsimPlistUID class]]) d = [self _decodeUID:d classes:nil];
        return [c isSubclassOfClass:[NSMutableData class]] ? [NSMutableData dataWithData:d ?: [NSData data]] : [NSData dataWithData:d ?: [NSData data]];
    }
    if ([c isSubclassOfClass:[NSDate class]]) return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[raw[@"NS.time"] doubleValue]];
    if ([c isSubclassOfClass:[NSURL class]]) {
        NSURL *base = [self _decodeUID:raw[@"NS.base"] classes:nil];
        NSString *rel = [self _decodeUID:raw[@"NS.relative"] classes:nil];
        return rel ? [NSURL URLWithString:rel relativeToURL:base] : nil;
    }
    if ([c isSubclassOfClass:[NSNull class]]) return [NSNull null];
    if ([c isSubclassOfClass:[NSUUID class]]) { NSData *b = raw[@"NS.uuidbytes"]; return b.length == 16 ? [[NSUUID alloc] initWithUUIDBytes:b.bytes] : nil; }
    if ([c isSubclassOfClass:[NSLocale class]]) return [NSLocale localeWithLocaleIdentifier:[self _decodeUID:raw[@"NS.identifier"] classes:nil] ?: @""];
    if ([c isSubclassOfClass:[NSTimeZone class]]) return [NSTimeZone timeZoneWithName:[self _decodeUID:raw[@"NS.name"] classes:nil] ?: @"GMT"];
    if ([c isSubclassOfClass:[NSIndexSet class]]) {
        NSMutableIndexSet *s = [NSMutableIndexSet indexSet];
        NSUInteger rc = [raw[@"NSRangeCount"] unsignedIntegerValue];
        if (rc == 1) [s addIndexesInRange:NSMakeRange([raw[@"NSLocation"] unsignedIntegerValue], [raw[@"NSLength"] unsignedIntegerValue])];
        else if (rc > 1) {
            NSData *d = raw[@"NSRangeData"]; const uint8_t *p = d.bytes, *end = p + d.length;
            for (NSUInteger i = 0; i < rc && p < end; i++) {
                NSUInteger vals[2] = {0, 0};
                for (int k = 0; k < 2; k++) { NSUInteger v = 0; int shift = 0; while (p < end) { uint8_t b = *p++; v |= (NSUInteger)(b & 0x7F) << shift; shift += 7; if (!(b & 0x80)) break; } vals[k] = v; }
                [s addIndexesInRange:NSMakeRange(vals[0], vals[1])];
            }
        }
        return [c isSubclassOfClass:[NSMutableIndexSet class]] ? s : [s copy];
    }
    if ([c isSubclassOfClass:[NSValue class]] && ![c isSubclassOfClass:[NSNumber class]]) {
        switch ([raw[@"NS.special"] intValue]) {
        case 1: { CGPoint p = {0, 0}; sscanf([[self _isim_value:raw[@"NS.pointval"]] UTF8String] ?: "", "{%lf, %lf}", &p.x, &p.y); return [NSValue valueWithCGPoint:p]; }
        case 2: { CGSize s = {0, 0}; sscanf([[self _isim_value:raw[@"NS.sizeval"]] UTF8String] ?: "", "{%lf, %lf}", &s.width, &s.height); return [NSValue valueWithCGSize:s]; }
        case 3: { CGRect r = {{0, 0}, {0, 0}}; sscanf([[self _isim_value:raw[@"NS.rectval"]] UTF8String] ?: "", "{{%lf, %lf}, {%lf, %lf}}", &r.origin.x, &r.origin.y, &r.size.width, &r.size.height); return [NSValue valueWithCGRect:r]; }
        case 4: return [NSValue valueWithRange:NSMakeRange([raw[@"NS.rangeval.location"] unsignedIntegerValue], [raw[@"NS.rangeval.length"] unsignedIntegerValue])];
        default: return nil;
        }
    }
    return [self _decodeGeneric:c index:idx];
}
- (id)_decodeGeneric:(Class)c index:(uint64_t)idx {
    id obj = [c alloc];
    if (![obj respondsToSelector:@selector(initWithCoder:)]) { [self _fail:[NSString stringWithFormat:@"class %@ does not implement initWithCoder:", c] code:4864]; return nil; }
    /* register before decoding so cyclic references resolve to the same object */
    _decoded[@(idx)] = obj;
    id result = [obj initWithCoder:self];
    if (result != obj) { if (result) _decoded[@(idx)] = result; else [_decoded removeObjectForKey:@(idx)]; }
    if ([result respondsToSelector:@selector(awakeAfterUsingCoder:)]) result = [result awakeAfterUsingCoder:self];
    return result;
}
- (id)decodeObjectForKey:(NSString *)key { return [self _decodeUID:self._current[key] classes:_secure ? _allowed : nil]; }
- (id)decodeObjectOfClasses:(NSSet *)classes forKey:(NSString *)key {
    id v = self._current[key];
    if (!v) return nil;
    return [self _decodeUID:v classes:classes];
}
- (id)decodeObjectOfClass:(Class)c forKey:(NSString *)key { return [self decodeObjectOfClasses:[NSSet setWithObject:c] forKey:key]; }
- (id)decodeTopLevelObjectForKey:(NSString *)key error:(NSError **)error {
    id v = [self decodeObjectForKey:key];
    if (_error && error) *error = _error;
    return v;
}
- (BOOL)decodeBoolForKey:(NSString *)k { return [self._current[k] boolValue]; }
- (int64_t)decodeInt64ForKey:(NSString *)k { return [self._current[k] longLongValue]; }
- (int)decodeIntForKey:(NSString *)k { return [self._current[k] intValue]; }
- (int32_t)decodeInt32ForKey:(NSString *)k { return [self._current[k] intValue]; }
- (NSInteger)decodeIntegerForKey:(NSString *)k { return [self._current[k] integerValue]; }
- (double)decodeDoubleForKey:(NSString *)k { return [self._current[k] doubleValue]; }
- (float)decodeFloatForKey:(NSString *)k { return [self._current[k] floatValue]; }
- (const uint8_t *)decodeBytesForKey:(NSString *)k returnedLength:(NSUInteger *)n {
    NSData *d = self._current[k];
    if (![d isKindOfClass:[NSData class]]) { if (n) *n = 0; return NULL; }
    [_bytesKeepAlive addObject:d];
    if (n) *n = d.length;
    return d.bytes;
}
@end

@implementation NSObject (IsimAwakeAfterUsingCoder)
- (id)awakeAfterUsingCoder:(NSCoder *)coder { return self; }
@end

/* For Foundation's own classes' encodeWithCoder: / initWithCoder: (also reached by a subclass's super call). Keyed coding
   only, like Apple's for these classes on iOS. */
void isim_encode_builtin(id object, NSCoder *coder, Class base) {
    if (![coder isKindOfClass:[NSKeyedArchiver class]])
        [NSException raise:NSInvalidArgumentException format:@"*** -[%@ encodeWithCoder:]: only supports keyed coders", base];
    [(NSKeyedArchiver *)coder _isim_encodeBuiltin:object asClass:base];
}
NSArray *isim_decode_objects(NSCoder *coder, NSString *key) {
    if ([coder isKindOfClass:[NSKeyedUnarchiver class]]) return [(NSKeyedUnarchiver *)coder _isim_decodeObjectsForKey:key];
    id v = [coder decodeObjectForKey:key];
    return [v isKindOfClass:[NSArray class]] ? v : @[];
}

/* NSNumber and NSCharacterSet support secure coding (the other classes declare it in their own implementation) */
#define SECURE(cls) @implementation cls (IsimSecureCoding) + (BOOL)supportsSecureCoding { return YES; } @end
SECURE(NSNumber) SECURE(NSCharacterSet)
