/* isim Core Data (ARC): managed object models — entities, attributes, relationships, fetched properties —
 * built in code or loaded from isim-compiled models. `isim build` compiles an Xcode .xcdatamodeld into
 * <Name>.momd/<Version>.mom files that are XML property lists in isim's own format (key "isimFormat" =
 * "isim-managed-object-model"); they are not Apple's binary .mom files. See docs/COREDATA.md. */
#import "CoreDataPrivate.h"
#include <objc/runtime.h>

double NSCoreDataVersionNumber = 1400.0;
NSString * const NSDetailedErrorsKey = @"NSDetailedErrors";
NSString * const NSValidationObjectErrorKey = @"NSValidationErrorObject";
NSString * const NSValidationKeyErrorKey = @"NSValidationErrorKey";
NSString * const NSValidationPredicateErrorKey = @"NSValidationErrorPredicate";
NSString * const NSValidationValueErrorKey = @"NSValidationErrorValue";
NSString * const NSAffectedStoresErrorKey = @"NSAffectedStoresErrorKey";
NSString * const NSAffectedObjectsErrorKey = @"NSAffectedObjectsErrorKey";
NSString * const NSPersistentStoreSaveConflictsErrorKey = @"conflictList";
NSString * const NSSQLiteErrorDomain = @"NSSQLiteErrorDomain";

NSError *CDError(NSInteger code, NSString *message, NSDictionary *extra) {
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (message) { info[NSLocalizedDescriptionKey] = message; info[@"NSDebugDescription"] = message; }
    if (extra) [info addEntriesFromDictionary:extra];
    return [NSError errorWithDomain:NSCocoaErrorDomain code:code userInfo:info];
}

/* ================= names ================= */
static NSDictionary<NSString *, NSNumber *> *type_names(void) {
    static NSDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        d = @{ @"Undefined": @(NSUndefinedAttributeType), @"Integer 16": @(NSInteger16AttributeType), @"Integer 32": @(NSInteger32AttributeType),
               @"Integer 64": @(NSInteger64AttributeType), @"Decimal": @(NSDecimalAttributeType), @"Double": @(NSDoubleAttributeType),
               @"Float": @(NSFloatAttributeType), @"String": @(NSStringAttributeType), @"Boolean": @(NSBooleanAttributeType),
               @"Date": @(NSDateAttributeType), @"Binary": @(NSBinaryDataAttributeType), @"UUID": @(NSUUIDAttributeType),
               @"URI": @(NSURIAttributeType), @"Transformable": @(NSTransformableAttributeType), @"ObjectID": @(NSObjectIDAttributeType),
               @"Composite": @(NSCompositeAttributeType) };
    });
    return d;
}
NSString *CDAttributeTypeName(NSAttributeType t) {
    for (NSString *k in type_names()) if ([type_names()[k] unsignedIntegerValue] == t) return k;
    return @"Undefined";
}
NSAttributeType CDAttributeTypeFromName(NSString *name) {
    NSNumber *n = type_names()[name];
    if (!n && [name isEqualToString:@"Binary Data"]) return NSBinaryDataAttributeType;
    return n ? (NSAttributeType)n.unsignedIntegerValue : NSUndefinedAttributeType;
}
NSString *CDDeleteRuleName(NSDeleteRule r) {
    switch (r) { case NSNullifyDeleteRule: return @"Nullify"; case NSCascadeDeleteRule: return @"Cascade"; case NSDenyDeleteRule: return @"Deny"; default: return @"No Action"; }
}
static NSDeleteRule delete_rule(NSString *s) {
    if ([s isEqualToString:@"Cascade"]) return NSCascadeDeleteRule;
    if ([s isEqualToString:@"Deny"]) return NSDenyDeleteRule;
    if ([s isEqualToString:@"No Action"] || [s isEqualToString:@"NoAction"]) return NSNoActionDeleteRule;
    return NSNullifyDeleteRule;
}

/* ================= class lookup / registry ================= */
static NSString *main_module(void) {
    static NSString *m;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSString *exe = [NSBundle mainBundle].infoDictionary[@"CFBundleExecutable"] ?: [NSProcessInfo processInfo].processName;
        NSMutableString *s = [NSMutableString string];
        for (NSUInteger i = 0; i < exe.length; i++) {
            unichar c = [exe characterAtIndex:i];
            BOOL ok = (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '_';
            [s appendFormat:@"%C", (unichar)(ok ? c : '_')];
        }
        m = s;
    });
    return m;
}
static Class swift_class(NSString *module, NSString *name) {
    NSString *mangled = [NSString stringWithFormat:@"_TtC%lu%@%lu%@", (unsigned long)module.length, module, (unsigned long)name.length, name];
    return NSClassFromString(mangled);
}
Class CDClassNamed(NSString *name) {
    if (!name.length) return Nil;
    if ([name hasPrefix:@"."]) name = [name substringFromIndex:1];
    Class c = NSClassFromString(name);
    if (c) return c;
    NSRange dot = [name rangeOfString:@"." options:NSBackwardsSearch];
    if (dot.location != NSNotFound) {
        c = swift_class([name substringToIndex:dot.location], [name substringFromIndex:dot.location + 1]);
        if (c) return c;
        return NSClassFromString([name substringFromIndex:dot.location + 1]);
    }
    return swift_class(main_module(), name);
}

static NSMutableDictionary<NSString *, NSEntityDescription *> *class_registry(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}
void CDRegisterModel(NSManagedObjectModel *model) {
    NSMutableDictionary *r = class_registry();
    @synchronized (r) {
        for (NSEntityDescription *e in model.entities) {
            Class c = e._cd_objectClass;
            if (c && c != [NSManagedObject class]) r[NSStringFromClass(c)] = e;
            r[[@"entity:" stringByAppendingString:e.name ?: @""]] = e;
        }
    }
}
NSEntityDescription *CDEntityForClass(Class cls) {
    NSMutableDictionary *r = class_registry();
    @synchronized (r) {
        NSEntityDescription *e = r[NSStringFromClass(cls)];
        if (e) return e;
        NSString *n = NSStringFromClass(cls);                     /* Module.Class -> Class, _TtC..: last component */
        NSRange dot = [n rangeOfString:@"." options:NSBackwardsSearch];
        if (dot.location != NSNotFound) n = [n substringFromIndex:dot.location + 1];
        return r[[@"entity:" stringByAppendingString:n]];
    }
}

static NSData *hash_data(NSString *s) {
    uint64_t h[4] = { 1469598103934665603ull, 1099511628211ull, 0x9e3779b97f4a7c15ull, 0xc2b2ae3d27d4eb4full };
    const char *c = s.UTF8String;
    for (size_t i = 0; c[i]; i++) for (int k = 0; k < 4; k++) h[k] = (h[k] ^ (uint8_t)c[i]) * (1099511628211ull + 2 * k);
    return [NSData dataWithBytes:h length:sizeof h];
}

/* ================= NSPropertyDescription ================= */
@implementation NSPropertyDescription {
    __weak NSEntityDescription *_entity;
    NSArray *_predicates, *_warnings;
}
- (instancetype)init { if ((self = [super init])) { _optional = YES; _predicates = @[]; _warnings = @[]; } return self; }
- (NSEntityDescription *)entity { return _entity; }
- (void)_cd_setEntity:(NSEntityDescription *)e { _entity = e; }
- (NSString *)_cd_column { return [@"Z" stringByAppendingString:self.name.uppercaseString]; }
- (NSArray<NSPredicate *> *)validationPredicates { return _predicates; }
- (NSArray *)validationWarnings { return _warnings; }
- (void)setValidationPredicates:(NSArray<NSPredicate *> *)p withValidationWarnings:(NSArray<NSString *> *)w { _predicates = [p copy] ?: @[]; _warnings = [w copy] ?: @[]; }
- (NSData *)versionHash { return hash_data([NSString stringWithFormat:@"%@|%@|%d|%d|%@", [self class], self.name, self.optional, self.transient, self.versionHashModifier]); }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:self.name forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)coder { if ((self = [self init])) self.name = [coder decodeObjectForKey:@"name"]; return self; }
- (NSString *)description { return [NSString stringWithFormat:@"(<%@: %p>), name %@, isOptional %d, isTransient %d, entity %@", [self class], self, self.name, self.optional, self.transient, self.entity.name]; }
@end

/* ================= NSAttributeDescription ================= */
@implementation NSAttributeDescription { NSString *_minValue, *_maxValue, *_regex; }
@synthesize attributeValueClassName = _attributeValueClassName;
- (void)setAttributeValueClassName:(NSString *)n { _attributeValueClassName = [n copy]; }
- (NSString *)_cd_minValue { return _minValue; }
- (void)set_cd_minValue:(NSString *)v { _minValue = [v copy]; }
- (NSString *)_cd_maxValue { return _maxValue; }
- (void)set_cd_maxValue:(NSString *)v { _maxValue = [v copy]; }
- (NSString *)_cd_regex { return _regex; }
- (void)set_cd_regex:(NSString *)v { _regex = [v copy]; }
- (NSString *)attributeValueClassName {
    if (_attributeValueClassName) return _attributeValueClassName;
    switch (self.attributeType) {
    case NSInteger16AttributeType: case NSInteger32AttributeType: case NSInteger64AttributeType: case NSDoubleAttributeType:
    case NSFloatAttributeType: case NSBooleanAttributeType: case NSDecimalAttributeType: return @"NSNumber";
    case NSStringAttributeType: return @"NSString";
    case NSDateAttributeType: return @"NSDate";
    case NSBinaryDataAttributeType: return @"NSData";
    case NSUUIDAttributeType: return @"NSUUID";
    case NSURIAttributeType: return @"NSURL";
    default: return nil;
    }
}
/* Transformable: the keyed-archive transformers run "in reverse" to make data (like Core Data on iOS) */
static BOOL unarchiving_transformer(NSString *name, NSValueTransformer *t) {
    return [t isKindOfClass:[NSSecureUnarchiveFromDataTransformer class]] || [name isEqualToString:NSKeyedUnarchiveFromDataTransformerName] ||
           [name isEqualToString:NSUnarchiveFromDataTransformerName];
}
- (NSValueTransformer *)_cd_transformer:(NSString **)nameOut {
    NSString *name = self.valueTransformerName.length ? self.valueTransformerName : NSKeyedUnarchiveFromDataTransformerName;
    if (nameOut) *nameOut = name;
    NSValueTransformer *t = [NSValueTransformer valueTransformerForName:name];
    if (!t) CD_LOG(@"no value transformer named %@ for %@.%@", name, self.entity.name, self.name);
    return t;
}
- (NSData *)_cd_dataFromValue:(id)value {
    if (!value) return nil;
    NSString *name; NSValueTransformer *t = [self _cd_transformer:&name];
    if (!t) return nil;
    id d = unarchiving_transformer(name, t) ? [t reverseTransformedValue:value] : [t transformedValue:value];
    return [d isKindOfClass:[NSData class]] ? d : nil;
}
- (id)_cd_valueFromData:(NSData *)data {
    if (!data) return nil;
    NSString *name; NSValueTransformer *t = [self _cd_transformer:&name];
    if (!t) return nil;
    return unarchiving_transformer(name, t) ? [t transformedValue:data] : [t reverseTransformedValue:data];
}
- (NSData *)versionHash { return hash_data([NSString stringWithFormat:@"attr|%@|%lu|%d|%d|%@", self.name, (unsigned long)self.attributeType, self.optional, self.transient, self.versionHashModifier]); }
- (NSString *)description { return [NSString stringWithFormat:@"%@, attributeType %lu, attributeValueClassName %@, defaultValue %@", [super description], (unsigned long)self.attributeType, self.attributeValueClassName, self.defaultValue]; }
@end

/* ================= NSRelationshipDescription ================= */
@implementation NSRelationshipDescription {
    __weak NSEntityDescription *_destination;
    __weak NSRelationshipDescription *_inverse;
    NSString *_destName, *_invName;
}
- (instancetype)init { if ((self = [super init])) { _maxCount = 1; _deleteRule = NSNullifyDeleteRule; } return self; }
- (NSEntityDescription *)destinationEntity { return _destination; }
- (void)setDestinationEntity:(NSEntityDescription *)e { _destination = e; _destName = e.name; }
- (NSRelationshipDescription *)inverseRelationship { return _inverse; }
- (void)setInverseRelationship:(NSRelationshipDescription *)r { _inverse = r; _invName = r.name; }
- (NSString *)_cd_destinationName { return _destName; }
- (void)set_cd_destinationName:(NSString *)n { _destName = [n copy]; }
- (NSString *)_cd_inverseName { return _invName; }
- (void)set_cd_inverseName:(NSString *)n { _invName = [n copy]; }
- (BOOL)isToMany { return _maxCount != 1; }
- (BOOL)_cd_usesJoinTable {
    if (!self.toMany) return NO;
    return self.ordered || !_inverse || _inverse.toMany;
}
- (NSRelationshipDescription *)_cd_joinOwner {
    NSRelationshipDescription *inv = _inverse;
    if (!inv || !inv.toMany) return self;                 /* ordered with a to-one inverse, or no inverse: this side */
    if (self.ordered != inv.ordered) return self.ordered ? self : inv;
    NSString *a = [NSString stringWithFormat:@"%@.%@", self.entity._cd_root.name, self.name];
    NSString *b = [NSString stringWithFormat:@"%@.%@", inv.entity._cd_root.name, inv.name];
    return [a compare:b] != NSOrderedDescending ? self : inv;
}
- (NSString *)_cd_joinTable {
    NSRelationshipDescription *o = self._cd_joinOwner;
    return [NSString stringWithFormat:@"Z_%@_%@", o.entity._cd_root.name.uppercaseString, o.name.uppercaseString];
}
- (NSString *)_cd_entColumn { return [@"Z_ENT_" stringByAppendingString:self.name.uppercaseString]; }
- (NSData *)versionHash { return hash_data([NSString stringWithFormat:@"rel|%@|%@|%@|%lu|%d", self.name, _destName, _invName, (unsigned long)_maxCount, self.ordered]); }
- (NSString *)description { return [NSString stringWithFormat:@"%@, destination entity %@, inverseRelationship %@, minCount %lu, maxCount %lu, isOrdered %d, deleteRule %@",
                                    [super description], _destName, _invName, (unsigned long)_minCount, (unsigned long)_maxCount, self.ordered, CDDeleteRuleName(_deleteRule)]; }
@end

@implementation NSFetchedPropertyDescription
@end
@implementation NSExpressionDescription
@end

/* ================= NSEntityDescription ================= */
@implementation NSEntityDescription {
    __weak NSManagedObjectModel *_model;
    __weak NSEntityDescription *_super;
    NSArray *_own, *_subs;
    NSString *_className, *_parentName, *_codegen;
    Class _cls;
}
+ (NSEntityDescription *)entityForName:(NSString *)name inManagedObjectContext:(NSManagedObjectContext *)context {
    return [context _cd_entityNamed:name];
}
+ (NSManagedObject *)insertNewObjectForEntityForName:(NSString *)name inManagedObjectContext:(NSManagedObjectContext *)context {
    NSEntityDescription *e = [context _cd_entityNamed:name];
    if (!e) { [NSException raise:NSInternalInconsistencyException format:@"+entityForName: could not locate an entity named '%@' in this model.", name]; return nil; }
    return [[e._cd_objectClass alloc] initWithEntity:e insertIntoManagedObjectContext:context];
}
- (instancetype)init { if ((self = [super init])) { _own = @[]; _subs = @[]; _uniquenessConstraints = @[]; } return self; }
- (NSManagedObjectModel *)managedObjectModel { return _model; }
- (void)_cd_setModel:(NSManagedObjectModel *)m { _model = m; }
- (NSEntityDescription *)superentity { return _super; }
- (void)_cd_setSuperentity:(NSEntityDescription *)e { _super = e; _parentName = e.name; }
- (NSString *)_cd_parentName { return _parentName; }
- (void)set_cd_parentName:(NSString *)n { _parentName = [n copy]; }
- (NSString *)_cd_codeGenerationType { return _codegen; }
- (void)set_cd_codeGenerationType:(NSString *)n { _codegen = [n copy]; }
- (NSString *)managedObjectClassName { return _className.length ? _className : @"NSManagedObject"; }
- (void)setManagedObjectClassName:(NSString *)n { _className = [n copy]; _cls = Nil; }
- (Class)_cd_objectClass {
    if (!_cls) {
        Class c = CDClassNamed(self.managedObjectClassName);
        if (!c || ![c isSubclassOfClass:[NSManagedObject class]]) {
            if (_className.length && ![_className isEqualToString:@"NSManagedObject"])
                CD_LOG(@"warning: unable to load class named '%@' for entity '%@'. Class not found, using default NSManagedObject instead.", _className, self.name);
            c = [NSManagedObject class];
        }
        _cls = c;
    }
    return _cls;
}
- (NSArray *)subentities { return _subs; }
- (void)setSubentities:(NSArray *)subs { _subs = [subs copy] ?: @[]; for (NSEntityDescription *s in _subs) [s _cd_setSuperentity:self]; }
- (NSDictionary *)subentitiesByName { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSEntityDescription *s in _subs) d[s.name] = s; return d; }
- (NSArray *)properties {
    NSEntityDescription *sup = _super;
    if (!sup) return _own;
    NSMutableArray *all = [sup.properties mutableCopy];
    NSMutableSet *mine = [NSMutableSet set];
    for (NSPropertyDescription *p in _own) [mine addObject:p.name];
    for (NSInteger i = (NSInteger)all.count - 1; i >= 0; i--) if ([mine containsObject:[all[i] name]]) [all removeObjectAtIndex:i];
    [all addObjectsFromArray:_own];
    return all;
}
- (void)setProperties:(NSArray *)props { _own = [props copy] ?: @[]; for (NSPropertyDescription *p in _own) [p _cd_setEntity:self]; }
- (NSDictionary *)propertiesByName { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSPropertyDescription *p in self.properties) d[p.name] = p; return d; }
- (NSDictionary *)attributesByName {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSPropertyDescription *p in self.properties) if ([p isKindOfClass:[NSAttributeDescription class]]) d[p.name] = p;
    return d;
}
- (NSDictionary *)relationshipsByName {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSPropertyDescription *p in self.properties) if ([p isKindOfClass:[NSRelationshipDescription class]]) d[p.name] = p;
    return d;
}
- (NSArray *)relationshipsWithDestinationEntity:(NSEntityDescription *)e {
    NSMutableArray *a = [NSMutableArray array];
    for (NSRelationshipDescription *r in self.relationshipsByName.allValues) if ([e isKindOfEntity:r.destinationEntity]) [a addObject:r];
    return a;
}
- (BOOL)isKindOfEntity:(NSEntityDescription *)e {
    for (NSEntityDescription *x = self; x; x = x.superentity) if (x == e || [x.name isEqualToString:e.name]) return YES;
    return NO;
}
- (NSEntityDescription *)_cd_root { NSEntityDescription *e = self; while (e.superentity) e = e.superentity; return e; }
- (NSArray *)_cd_family {
    NSMutableArray *a = [NSMutableArray arrayWithObject:self];
    for (NSEntityDescription *s in _subs) [a addObjectsFromArray:s._cd_family];
    return a;
}
- (NSString *)_cd_table { return [@"Z" stringByAppendingString:self._cd_root.name.uppercaseString]; }
- (NSData *)versionHash {
    NSMutableString *s = [NSMutableString stringWithFormat:@"%@|%@|%d|%@", self.name, _parentName, self.abstract, self.versionHashModifier];
    for (NSPropertyDescription *p in _own) [s appendString:p.versionHash.description];
    return hash_data(s);
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id __unsafe_unretained *)buf count:(NSUInteger)len {
    return [self.properties countByEnumeratingWithState:st objects:buf count:len];
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeObject:self.name forKey:@"name"]; }
- (instancetype)initWithCoder:(NSCoder *)coder { if ((self = [self init])) self.name = [coder decodeObjectForKey:@"name"]; return self; }
- (NSString *)description { return [NSString stringWithFormat:@"(<NSEntityDescription: %p>) name %@, managedObjectClassName %@, superentity %@, properties %@", self, self.name, self.managedObjectClassName, _parentName, [self.properties valueForKey:@"name"]]; }
@end

/* ================= NSManagedObjectModel ================= */
@implementation NSManagedObjectModel {
    NSArray *_entities;
    NSMutableDictionary<NSString *, NSArray *> *_configs;
    NSMutableDictionary<NSString *, NSFetchRequest *> *_templates;
}
- (instancetype)init {
    if ((self = [super init])) { _entities = @[]; _configs = [NSMutableDictionary dictionary]; _templates = [NSMutableDictionary dictionary]; _versionIdentifiers = [NSSet set]; }
    return self;
}
- (NSArray *)entities { return _entities; }
- (void)setEntities:(NSArray *)entities {
    _entities = [entities copy] ?: @[];
    for (NSEntityDescription *e in _entities) [e _cd_setModel:self];
    [self _cd_link];
}
- (NSDictionary *)entitiesByName { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSEntityDescription *e in _entities) if (e.name) d[e.name] = e; return d; }
- (NSArray *)configurations { return _configs.allKeys; }
- (NSArray *)entitiesForConfiguration:(NSString *)c { return c && ![c isEqualToString:@"PF_DEFAULT_CONFIGURATION_NAME"] && ![c isEqualToString:@"Default"] ? _configs[c] : _entities; }
- (void)setEntities:(NSArray *)entities forConfiguration:(NSString *)c { _configs[c] = [entities copy]; }
- (void)setFetchRequestTemplate:(NSFetchRequest *)r forName:(NSString *)n { if (r) _templates[n] = r; else [_templates removeObjectForKey:n]; }
- (NSFetchRequest *)fetchRequestTemplateForName:(NSString *)n { return _templates[n]; }
- (NSDictionary *)fetchRequestTemplatesByName { return [_templates copy]; }
- (NSFetchRequest *)fetchRequestFromTemplateWithName:(NSString *)n substitutionVariables:(NSDictionary *)vars {
    NSFetchRequest *t = _templates[n];
    if (!t) return nil;
    NSFetchRequest *r = [t copy];
    if (r.predicate && vars.count) r.predicate = [r.predicate predicateWithSubstitutionVariables:vars];
    return r;
}
- (NSDictionary *)entityVersionHashesByName { NSMutableDictionary *d = [NSMutableDictionary dictionary]; for (NSEntityDescription *e in _entities) d[e.name] = e.versionHash; return d; }
- (NSString *)versionChecksum {
    NSMutableString *s = [NSMutableString string];
    for (NSString *k in [self.entityVersionHashesByName.allKeys sortedArrayUsingSelector:@selector(compare:)]) [s appendString:[self.entityVersionHashesByName[k] description]];
    NSData *h = hash_data(s);
    return [h base64EncodedStringWithOptions:0];
}
- (BOOL)isConfiguration:(NSString *)c compatibleWithStoreMetadata:(NSDictionary *)metadata {
    NSDictionary *schema = metadata[@"isimSchema"];
    return schema ? [schema isEqual:self._cd_schema] : NO;
}
- (NSUInteger)countByEnumeratingWithState:(NSFastEnumerationState *)st objects:(id __unsafe_unretained *)buf count:(NSUInteger)len {
    return [_entities countByEnumeratingWithState:st objects:buf count:len];
}
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder {}
- (instancetype)initWithCoder:(NSCoder *)coder { return [self init]; }
- (NSString *)description { return [NSString stringWithFormat:@"(<NSManagedObjectModel: %p>) isEditable 1, entities %@", self, [_entities valueForKey:@"name"]]; }

- (void)_cd_link {
    NSDictionary *byName = self.entitiesByName;
    for (NSEntityDescription *e in _entities) {               /* inheritance from names (compiled models) */
        if (!e.superentity && e._cd_parentName) {
            NSEntityDescription *p = byName[e._cd_parentName];
            if (p) { [e _cd_setSuperentity:p]; if (![p.subentities containsObject:e]) p.subentities = [p.subentities arrayByAddingObject:e]; }
        }
    }
    for (NSEntityDescription *e in _entities) {
        for (NSPropertyDescription *p in e.properties) {
            if (![p isKindOfClass:[NSRelationshipDescription class]]) continue;
            NSRelationshipDescription *r = (NSRelationshipDescription *)p;
            if (!r.destinationEntity && r._cd_destinationName) r.destinationEntity = byName[r._cd_destinationName];
            if (!r.inverseRelationship && r._cd_inverseName && r.destinationEntity) {
                NSRelationshipDescription *inv = r.destinationEntity.relationshipsByName[r._cd_inverseName];
                if (inv) r.inverseRelationship = inv;
            }
        }
    }
}

/* the layout a SQLite store depends on: entity tree, attribute columns/types, relationship storage */
- (NSDictionary *)_cd_schema {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    for (NSEntityDescription *e in _entities) {
        NSMutableDictionary *attrs = [NSMutableDictionary dictionary], *rels = [NSMutableDictionary dictionary];
        for (NSPropertyDescription *p in e.properties) {
            if (p.transient) continue;
            if ([p isKindOfClass:[NSAttributeDescription class]]) attrs[p.name] = CDAttributeTypeName(((NSAttributeDescription *)p).attributeType);
            else if ([p isKindOfClass:[NSRelationshipDescription class]]) {
                NSRelationshipDescription *r = (NSRelationshipDescription *)p;
                rels[p.name] = [NSString stringWithFormat:@"%@ %@%@%@", r.destinationEntity.name, r.toMany ? @"many" : @"one",
                                r.ordered ? @" ordered" : @"", r._cd_usesJoinTable ? [@" join " stringByAppendingString:r._cd_joinTable] : @""];
            }
        }
        out[e.name] = @{ @"parent": e.superentity.name ?: @"", @"attributes": attrs, @"relationships": rels };
    }
    return out;
}

/* ---------------- loading compiled models ---------------- */
static id plist_default(id v, NSAttributeType t) {
    if (!v) return nil;
    if (t == NSDateAttributeType && [v isKindOfClass:[NSNumber class]]) return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:[v doubleValue]];
    if (t == NSUUIDAttributeType && [v isKindOfClass:[NSString class]]) return [[NSUUID alloc] initWithUUIDString:v];
    if (t == NSURIAttributeType && [v isKindOfClass:[NSString class]]) return [NSURL URLWithString:v];
    return v;
}
+ (instancetype)_cd_modelWithPlist:(NSDictionary *)plist error:(NSError **)error {
    if (![plist isKindOfClass:[NSDictionary class]] || ![plist[@"isimFormat"] isEqual:@"isim-managed-object-model"]) {
        if (error) *error = CDError(NSCoreDataError, @"not an isim-compiled managed object model (rebuild the app with isim build)", nil);
        return nil;
    }
    NSManagedObjectModel *m = [[self alloc] init];
    NSMutableArray *entities = [NSMutableArray array];
    for (NSDictionary *ed in plist[@"entities"]) {
        NSEntityDescription *e = [[NSEntityDescription alloc] init];
        e.name = ed[@"name"];
        if (ed[@"className"]) e.managedObjectClassName = ed[@"className"];
        e.abstract = [ed[@"abstract"] boolValue];
        e._cd_parentName = ed[@"parent"];
        e._cd_codeGenerationType = ed[@"codeGenerationType"];
        e.userInfo = ed[@"userInfo"];
        e.renamingIdentifier = ed[@"renamingIdentifier"];
        e.versionHashModifier = ed[@"versionHashModifier"];
        if (ed[@"uniquenessConstraints"]) e.uniquenessConstraints = ed[@"uniquenessConstraints"];
        NSMutableArray *props = [NSMutableArray array];
        for (NSDictionary *ad in ed[@"attributes"]) {
            NSAttributeDescription *a = [[NSAttributeDescription alloc] init];
            a.name = ad[@"name"];
            a.attributeType = CDAttributeTypeFromName(ad[@"type"]);
            a.optional = [ad[@"optional"] boolValue];
            a.transient = [ad[@"transient"] boolValue];
            a.indexed = [ad[@"indexed"] boolValue];
            a.defaultValue = plist_default(ad[@"defaultValue"], a.attributeType);
            a.valueTransformerName = ad[@"valueTransformerName"];
            if (ad[@"customClassName"]) a.attributeValueClassName = ad[@"customClassName"];
            a.allowsExternalBinaryDataStorage = [ad[@"allowsExternalBinaryDataStorage"] boolValue];
            a.renamingIdentifier = ad[@"renamingIdentifier"];
            a.userInfo = ad[@"userInfo"];
            a._cd_minValue = ad[@"minValue"]; a._cd_maxValue = ad[@"maxValue"]; a._cd_regex = ad[@"regularExpression"];
            [props addObject:a];
        }
        for (NSDictionary *rd in ed[@"relationships"]) {
            NSRelationshipDescription *r = [[NSRelationshipDescription alloc] init];
            r.name = rd[@"name"];
            r._cd_destinationName = rd[@"destination"];
            r._cd_inverseName = rd[@"inverse"];
            r.optional = [rd[@"optional"] boolValue];
            r.transient = [rd[@"transient"] boolValue];
            r.ordered = [rd[@"ordered"] boolValue];
            BOOL toMany = [rd[@"toMany"] boolValue];
            r.minCount = [rd[@"minCount"] unsignedIntegerValue];
            r.maxCount = toMany ? [rd[@"maxCount"] unsignedIntegerValue] : 1;
            if (toMany && r.maxCount == 1) r.maxCount = 0;     /* 0 = unbounded */
            r.deleteRule = delete_rule(rd[@"deleteRule"]);
            r.renamingIdentifier = rd[@"renamingIdentifier"];
            r.userInfo = rd[@"userInfo"];
            [props addObject:r];
        }
        for (NSDictionary *fd in ed[@"fetchedProperties"]) {
            NSFetchedPropertyDescription *f = [[NSFetchedPropertyDescription alloc] init];
            f.name = fd[@"name"];
            NSFetchRequest *req = [NSFetchRequest fetchRequestWithEntityName:fd[@"entity"]];
            if ([fd[@"predicate"] length]) req.predicate = [NSPredicate predicateWithFormat:fd[@"predicate"] argumentArray:nil];
            f.fetchRequest = req;
            [props addObject:f];
        }
        e.properties = props;
        [entities addObject:e];
    }
    m.entities = entities;
    NSDictionary *byName = m.entitiesByName;
    for (NSDictionary *ed in plist[@"entities"])                 /* fetched property requests get their entity */
        for (NSDictionary *fd in ed[@"fetchedProperties"]) {
            NSEntityDescription *owner = byName[ed[@"name"]];
            NSFetchedPropertyDescription *f = owner.propertiesByName[fd[@"name"]];
            f.fetchRequest.entity = byName[fd[@"entity"]];
        }
    for (NSDictionary *rd in plist[@"fetchRequests"]) {
        NSFetchRequest *r = [NSFetchRequest fetchRequestWithEntityName:rd[@"entity"]];
        r.entity = byName[rd[@"entity"]];
        if ([rd[@"predicate"] length]) r.predicate = [NSPredicate predicateWithFormat:rd[@"predicate"] argumentArray:nil];
        if (rd[@"fetchLimit"]) r.fetchLimit = [rd[@"fetchLimit"] unsignedIntegerValue];
        [m setFetchRequestTemplate:r forName:rd[@"name"]];
    }
    NSDictionary *configs = plist[@"configurations"];
    for (NSString *c in configs) {
        NSMutableArray *list = [NSMutableArray array];
        for (NSString *n in configs[c]) if (byName[n]) [list addObject:byName[n]];
        [m setEntities:list forConfiguration:c];
    }
    if ([plist[@"versionIdentifiers"] count]) m.versionIdentifiers = [NSSet setWithArray:plist[@"versionIdentifiers"]];
    return m;
}

- (instancetype)initWithContentsOfURL:(NSURL *)url {
    NSString *path = url.path;
    BOOL dir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&dir]) { CD_LOG(@"no model at %@", path); return nil; }
    if (dir) {                                                   /* .momd: VersionInfo.plist names the current version */
        NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:[path stringByAppendingPathComponent:@"VersionInfo.plist"]];
        NSString *current = info[@"NSManagedObjectModel_CurrentVersionName"];
        NSString *file = current ? [path stringByAppendingPathComponent:[current stringByAppendingPathExtension:@"mom"]] : nil;
        if (!file || ![[NSFileManager defaultManager] fileExistsAtPath:file]) {
            NSArray *moms = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:NULL] filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"self ENDSWITH '.mom'"]];
            file = moms.count ? [path stringByAppendingPathComponent:moms.firstObject] : nil;
        }
        if (!file) { CD_LOG(@"no .mom in %@", path); return nil; }
        path = file;
    }
    NSData *data = [NSData dataWithContentsOfFile:path];
    NSError *err = nil;
    id plist = data ? [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:&err] : nil;
    NSManagedObjectModel *m = plist ? [NSManagedObjectModel _cd_modelWithPlist:plist error:&err] : nil;
    if (!m) { CD_LOG(@"could not load the model at %@: %@", path, err.localizedDescription ?: @"unreadable"); return nil; }
    return m;
}

+ (NSManagedObjectModel *)mergedModelFromBundles:(NSArray<NSBundle *> *)bundles {
    NSMutableArray *models = [NSMutableArray array];
    for (NSBundle *b in bundles.count ? bundles : @[[NSBundle mainBundle]]) {
        NSArray *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:b.resourcePath ?: b.bundlePath error:NULL];
        for (NSString *n in items) {
            if (![n hasSuffix:@".momd"] && ![n hasSuffix:@".mom"]) continue;
            NSManagedObjectModel *m = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:[(b.resourcePath ?: b.bundlePath) stringByAppendingPathComponent:n]]];
            if (m) [models addObject:m];
        }
    }
    return [self modelByMergingModels:models];
}
+ (NSManagedObjectModel *)modelByMergingModels:(NSArray<NSManagedObjectModel *> *)models {
    if (models.count == 1) return models.firstObject;
    NSManagedObjectModel *m = [[NSManagedObjectModel alloc] init];
    NSMutableArray *all = [NSMutableArray array];
    for (NSManagedObjectModel *x in models) [all addObjectsFromArray:x.entities];
    m.entities = all;
    return m;
}
@end
