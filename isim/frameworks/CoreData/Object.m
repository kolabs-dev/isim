/* isim Core Data (ARC): NSManagedObjectID and NSManagedObject — per-object value dictionaries, faults,
 * change tracking, relationship maintenance (inverses), validation, and the dynamic @NSManaged / @dynamic
 * accessors that +resolveInstanceMethod: installs from the class's declared property types. */
#import "CoreDataPrivate.h"
#include <objc/runtime.h>
#include <string.h>

/* ================= CDSnapshot ================= */
@implementation CDSnapshot
- (instancetype)init { if ((self = [super init])) _values = [NSMutableDictionary dictionary]; return self; }
@end

NSArray *CDToManyArray(id v) {
    if (!v || v == [NSNull null]) return @[];
    if ([v isKindOfClass:[NSOrderedSet class]]) return [v array];
    if ([v isKindOfClass:[NSSet class]]) return [v allObjects];
    if ([v isKindOfClass:[NSArray class]]) return v;
    return @[v];
}

/* ================= NSManagedObjectID ================= */
@implementation NSManagedObjectID {
    NSEntityDescription *_entity;
    __weak NSPersistentStore *_store;
    NSString *_storeID, *_temp, *_rootName;
    int64_t _pk;
}
+ (instancetype)_cd_idWithEntity:(NSEntityDescription *)e store:(NSPersistentStore *)s pk:(int64_t)pk {
    NSManagedObjectID *o = [[self alloc] init];
    o->_entity = e; o->_store = s; o->_storeID = s.identifier ?: @""; o->_pk = pk; o->_rootName = e._cd_root.name;
    return o;
}
+ (instancetype)_cd_temporaryIDWithEntity:(NSEntityDescription *)e {
    NSManagedObjectID *o = [[self alloc] init];
    o->_entity = e; o->_temp = [NSUUID UUID].UUIDString; o->_rootName = e._cd_root.name;
    return o;
}
- (NSEntityDescription *)entity { return _entity; }
- (NSPersistentStore *)persistentStore { return _store; }
- (BOOL)isTemporaryID { return _temp != nil; }
- (int64_t)_cd_pk { return _pk; }
- (NSURL *)URIRepresentation {
    if (_temp) return [NSURL URLWithString:[NSString stringWithFormat:@"x-coredata:///%@/t%@", _entity.name, _temp]];
    return [NSURL URLWithString:[NSString stringWithFormat:@"x-coredata://%@/%@/p%lld", _storeID, _entity.name, (long long)_pk]];
}
- (BOOL)isEqual:(id)other {
    if (other == self) return YES;
    if (![other isKindOfClass:[NSManagedObjectID class]]) return NO;
    NSManagedObjectID *o = other;
    if (_temp || o->_temp) return _temp && o->_temp && [_temp isEqualToString:o->_temp];
    return _pk == o->_pk && [_rootName isEqualToString:o->_rootName] && [_storeID isEqualToString:o->_storeID];
}
- (NSUInteger)hash { return _temp ? _temp.hash : (NSUInteger)_pk * 2654435761u ^ _rootName.hash; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (NSString *)description { return [NSString stringWithFormat:@"%@", self.URIRepresentation.absoluteString]; }
@end

@implementation NSNumber (NSFetchedResultSupport)
@end
@implementation NSDictionary (NSFetchedResultSupport)
@end

/* ================= relationship proxies (mutableSetValueForKey:) ================= */
@interface CDSetProxy : NSMutableSet
@property (weak) NSManagedObject *owner;
@property (strong) NSRelationshipDescription *rel;
@property BOOL ready;
@end
@implementation CDSetProxy
- (void)_push { if (self.ready) [self.owner setValue:[NSSet setWithArray:self.allObjects] forKey:self.rel.name]; }
- (void)addObject:(id)o { [super addObject:o]; [self _push]; }
- (void)removeObject:(id)o { [super removeObject:o]; [self _push]; }
- (void)removeAllObjects { BOOL r = self.ready; self.ready = NO; for (id o in self.allObjects) [super removeObject:o]; self.ready = r; [self _push]; }
@end
@interface CDOrderedSetProxy : NSMutableOrderedSet
@property (weak) NSManagedObject *owner;
@property (strong) NSRelationshipDescription *rel;
@property BOOL ready;
@end
@implementation CDOrderedSetProxy
- (void)_push { if (self.ready) [self.owner setValue:[NSOrderedSet orderedSetWithArray:self.array] forKey:self.rel.name]; }
- (void)addObject:(id)o { [super addObject:o]; [self _push]; }
- (void)removeObject:(id)o { [super removeObject:o]; [self _push]; }
- (void)insertObject:(id)o atIndex:(NSUInteger)i { [super insertObject:o atIndex:i]; [self _push]; }
- (void)removeObjectAtIndex:(NSUInteger)i { [super removeObjectAtIndex:i]; [self _push]; }
- (void)removeAllObjects { [super removeAllObjects]; [self _push]; }
@end

/* ================= NSManagedObject ================= */
@implementation NSManagedObject {
    __weak NSManagedObjectContext *_ctx;
    NSEntityDescription *_entity;
    NSManagedObjectID *_oid;
    NSMutableDictionary *_values, *_committed;
    NSMutableSet *_eventKeys;
    BOOL _fault;
    int64_t _version;
    void (^_willChangeHandler)(void);
    id _observationToken;
}

+ (BOOL)contextShouldIgnoreUnmodeledPropertyChanges { return YES; }
+ (NSEntityDescription *)entity {
    NSEntityDescription *e = CDEntityForClass(self);
    if (!e) CD_LOG(@"+entity: no entity is registered for class %@ (load a model that uses it first)", NSStringFromClass(self));
    return e;
}
+ (NSFetchRequest *)fetchRequest {
    NSEntityDescription *e = CDEntityForClass(self);
    NSString *n = e.name;
    if (!n) { n = NSStringFromClass(self); NSRange dot = [n rangeOfString:@"." options:NSBackwardsSearch]; if (dot.location != NSNotFound) n = [n substringFromIndex:dot.location + 1]; }
    NSFetchRequest *r = [NSFetchRequest fetchRequestWithEntityName:n];
    if (e) r.entity = e;
    return r;
}
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key {
    NSEntityDescription *e = CDEntityForClass(self);
    if (e.propertiesByName[key]) return NO;                    /* the managed accessors notify themselves */
    return [super automaticallyNotifiesObserversForKey:key];
}

- (instancetype)init {
    NSEntityDescription *e = CDEntityForClass([self class]);
    if (!e) { CD_LOG(@"Failed to call designated initializer on NSManagedObject class '%@'", NSStringFromClass([self class])); }
    return [self initWithEntity:e insertIntoManagedObjectContext:nil];
}
- (instancetype)initWithEntity:(NSEntityDescription *)entity insertIntoManagedObjectContext:(NSManagedObjectContext *)context {
    if (!(self = [super init])) return nil;
    _entity = entity;
    _values = [NSMutableDictionary dictionary];
    _committed = [NSMutableDictionary dictionary];
    _eventKeys = [NSMutableSet set];
    for (NSPropertyDescription *p in entity.properties) {
        if ([p isKindOfClass:[NSAttributeDescription class]]) {
            id d = ((NSAttributeDescription *)p).defaultValue;
            if (d) _values[p.name] = d;
        } else if ([p isKindOfClass:[NSRelationshipDescription class]] && ((NSRelationshipDescription *)p).toMany)
            _values[p.name] = ((NSRelationshipDescription *)p).ordered ? [NSMutableOrderedSet orderedSet] : [NSMutableSet set];
    }
    if (context) [context insertObject:self];
    return self;
}
- (instancetype)initWithContext:(NSManagedObjectContext *)moc {
    NSEntityDescription *e = CDEntityForClass([self class]);
    if (!e) {
        NSManagedObjectModel *m = moc.persistentStoreCoordinator.managedObjectModel;
        NSManagedObjectContext *c = moc;
        while (!m && c.parentContext) { c = c.parentContext; m = c.persistentStoreCoordinator.managedObjectModel; }
        for (NSEntityDescription *x in m.entities) if (x._cd_objectClass == [self class]) { e = x; break; }
        if (e) CDRegisterModel(m);
    }
    if (!e) { CD_LOG(@"An NSManagedObject of class '%@' must have a valid NSEntityDescription.", NSStringFromClass([self class])); return nil; }
    return [self initWithEntity:e insertIntoManagedObjectContext:moc];
}
- (instancetype)_cd_initFaultWithEntity:(NSEntityDescription *)entity {
    if (!(self = [self initWithEntity:entity insertIntoManagedObjectContext:nil])) return nil;
    [_values removeAllObjects];
    _fault = YES;
    return self;
}

- (NSManagedObjectContext *)managedObjectContext { return _ctx; }
- (void)_cd_setContext:(NSManagedObjectContext *)c { _ctx = c; }
- (NSEntityDescription *)entity { return _entity; }
- (NSManagedObjectID *)objectID { if (!_oid) _oid = [NSManagedObjectID _cd_temporaryIDWithEntity:_entity]; return _oid; }
- (void)_cd_setObjectID:(NSManagedObjectID *)oid { _oid = oid; }
- (int64_t)_cd_version { return _version; }
- (void)set_cd_version:(int64_t)v { _version = v; }
- (BOOL)isInserted { return [_ctx _cd_isInserted:self]; }
- (BOOL)isUpdated { return [_ctx _cd_isUpdated:self]; }
- (BOOL)isDeleted { return [_ctx _cd_isDeleted:self]; }
- (BOOL)hasChanges { return self.isInserted || self.isDeleted || (self.isUpdated && self._cd_changedKeys.count); }
- (BOOL)hasPersistentChangedValues {
    for (NSString *k in self._cd_changedKeys) if (!((NSPropertyDescription *)_entity.propertiesByName[k]).transient) return YES;
    return NO;
}
- (BOOL)isFault { return _fault; }
- (BOOL)_cd_isFault { return _fault; }
- (NSUInteger)faultingState { return _fault ? 1 : 0; }
- (BOOL)hasFaultForRelationshipNamed:(NSString *)key { return _fault || !_values[key]; }
- (NSArray<NSManagedObjectID *> *)objectIDsForRelationshipNamed:(NSString *)key {
    NSRelationshipDescription *r = _entity.relationshipsByName[key];
    if (!r) return @[];
    if (r.toMany && !_values[key] && _ctx) return [_ctx _cd_relatedIDs:self relationship:r];
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObject *o in CDToManyArray([self _cd_raw:key])) [ids addObject:o.objectID];
    return ids;
}

- (NSMutableDictionary *)_cd_values { return _values; }
- (NSDictionary *)_cd_committed { return _committed; }
- (NSMutableSet *)_cd_changedKeysSinceEvent { return _eventKeys; }

/* ---------------- faults and snapshots ---------------- */
- (void)_cd_fire {
    if (!_fault) return;
    _fault = NO;
    NSManagedObjectContext *ctx = _ctx;
    CDSnapshot *s = ctx && _oid ? [ctx _cd_snapshotForObjectID:_oid] : nil;
    if (!s) { if (ctx && _oid && !_oid.temporaryID) CD_LOG(@"could not fulfill a fault for %@ (the object was deleted?)", _oid); return; }
    [self _cd_applySnapshot:s];
    [self awakeFromFetch];
}
static id object_value(NSManagedObjectContext *ctx, NSRelationshipDescription *r, id v) {
    if (!v || v == [NSNull null]) return nil;
    if (!r) return v;
    if (r.toMany) {
        NSMutableArray *objs = [NSMutableArray array];
        for (NSManagedObjectID *i in v) { NSManagedObject *o = [ctx objectWithID:i]; if (o) [objs addObject:o]; }
        return r.ordered ? [NSMutableOrderedSet orderedSetWithArray:objs] : [NSMutableSet setWithArray:objs];
    }
    return [ctx objectWithID:v];
}
static id committed_copy(id v) {
    if ([v isKindOfClass:[NSOrderedSet class]]) return [NSOrderedSet orderedSetWithArray:[v array]];
    if ([v isKindOfClass:[NSSet class]]) return [NSSet setWithArray:[v allObjects]];
    return v;
}
- (void)_cd_applySnapshot:(CDSnapshot *)s {
    _fault = NO;
    _version = s.version;
    NSDictionary<NSString *, NSRelationshipDescription *> *rels = _entity.relationshipsByName;
    [_values removeAllObjects]; [_committed removeAllObjects];
    for (NSString *k in s.values) {
        id v = object_value(_ctx, rels[k], s.values[k]);
        if (v) { _values[k] = v; _committed[k] = committed_copy(v); }
    }
}
- (void)_cd_mergeSnapshot:(CDSnapshot *)s keepChanges:(BOOL)keep {
    if (_fault) return;                                        /* loads fresh values when fired */
    NSArray *changed = keep ? self._cd_changedKeys : @[];
    NSMutableDictionary *mine = [NSMutableDictionary dictionary];
    for (NSString *k in changed) if (_values[k]) mine[k] = _values[k];
    NSDictionary<NSString *, NSRelationshipDescription *> *rels = _entity.relationshipsByName;
    for (NSPropertyDescription *p in _entity.properties) {
        NSString *k = p.name;
        if (p.transient) continue;
        BOOL toMany = [p isKindOfClass:[NSRelationshipDescription class]] && ((NSRelationshipDescription *)p).toMany;
        if (toMany && !s.values[k]) {                          /* unknown in the source: reload lazily */
            if (![changed containsObject:k]) { [_values removeObjectForKey:k]; [_committed removeObjectForKey:k]; }
            continue;
        }
        id v = object_value(_ctx, rels[k], s.values[k]);
        if (v) _committed[k] = committed_copy(v); else [_committed removeObjectForKey:k];
        if ([changed containsObject:k]) continue;
        [self willChangeValueForKey:k];
        if (v) _values[k] = v; else [_values removeObjectForKey:k];
        [self didChangeValueForKey:k];
    }
    for (NSString *k in mine) _values[k] = mine[k];
    _version = s.version;
}
- (void)_cd_turnIntoFault {
    if (_fault) return;
    [self willTurnIntoFault];
    [_values removeAllObjects]; [_committed removeAllObjects]; [_eventKeys removeAllObjects];
    _fault = YES;
    [self didTurnIntoFault];
}
- (void)_cd_commit {
    [_committed removeAllObjects];
    for (NSString *k in _values) _committed[k] = committed_copy(_values[k]);
}
- (void)_cd_resetToCommitted {
    for (NSPropertyDescription *p in _entity.properties) [self willChangeValueForKey:p.name];
    [_values removeAllObjects];
    for (NSString *k in _committed) {
        id v = _committed[k];
        _values[k] = [v isKindOfClass:[NSOrderedSet class]] ? [v mutableCopy] : [v isKindOfClass:[NSSet class]] ? [v mutableCopy] : v;
    }
    for (NSPropertyDescription *p in _entity.properties) [self didChangeValueForKey:p.name];
}
- (NSArray<NSString *> *)_cd_changedKeys {
    if (_fault) return @[];
    NSMutableArray *keys = [NSMutableArray array];
    for (NSPropertyDescription *p in _entity.properties) {
        NSString *k = p.name;
        if ([p isKindOfClass:[NSFetchedPropertyDescription class]]) continue;
        id a = _values[k], b = _committed[k];
        BOOL toMany = [p isKindOfClass:[NSRelationshipDescription class]] && ((NSRelationshipDescription *)p).toMany;
        if (toMany && !a) continue;
        if (toMany && !b) { if ([a count]) [keys addObject:k]; continue; }
        if (a == b) continue;
        if (!a || !b) { [keys addObject:k]; continue; }
        if (toMany) {
            BOOL same = [a count] == [b count];
            if (same && [a isKindOfClass:[NSOrderedSet class]]) same = [[a array] isEqualToArray:[b array]];
            else if (same) for (id x in a) if (![b containsObject:x]) { same = NO; break; }
            if (!same) [keys addObject:k];
        } else if ([p isKindOfClass:[NSRelationshipDescription class]] || ![a isEqual:b]) [keys addObject:k];
    }
    return keys;
}
- (CDSnapshot *)_cd_snapshotForChild {
    [self _cd_fire];
    CDSnapshot *s = [[CDSnapshot alloc] init];
    s.objectID = self.objectID; s.version = _version;
    NSDictionary<NSString *, NSRelationshipDescription *> *rels = _entity.relationshipsByName;
    for (NSString *k in _values) {
        NSRelationshipDescription *r = rels[k];
        id v = _values[k];
        if (!r) s.values[k] = v;
        else if (r.toMany) { NSMutableArray *ids = [NSMutableArray array]; for (NSManagedObject *o in CDToManyArray(v)) [ids addObject:o.objectID]; s.values[k] = ids; }
        else s.values[k] = [v objectID];
    }
    for (NSString *k in rels) if (!rels[k].toMany && !_values[k]) s.values[k] = [NSNull null];
    return s;
}

/* ---------------- raw values ---------------- */
- (id)_cd_raw:(NSString *)key {
    [self _cd_fire];
    id v = _values[key];
    if (v) return v == [NSNull null] ? nil : v;
    NSRelationshipDescription *r = _entity.relationshipsByName[key];
    if (r.toMany) {                                            /* lazily loaded to-many relationship */
        NSManagedObjectContext *ctx = _ctx;
        NSMutableArray *objs = [NSMutableArray array];
        if (ctx && (!_oid.temporaryID || ctx.parentContext))
            for (NSManagedObjectID *i in [ctx _cd_relatedIDs:self relationship:r]) { NSManagedObject *o = [ctx objectWithID:i]; if (o) [objs addObject:o]; }
        v = r.ordered ? [NSMutableOrderedSet orderedSetWithArray:objs] : [NSMutableSet setWithArray:objs];
        _values[key] = v;
        _committed[key] = committed_copy(v);
        return v;
    }
    return nil;
}
- (void)_cd_setRaw:(id)value forKey:(NSString *)key {
    [self _cd_fire];
    if (value) _values[key] = value; else [_values removeObjectForKey:key];
}
static void touched(NSManagedObject *o, NSString *key) {
    [o->_eventKeys addObject:key];
    [o->_ctx _cd_objectDidChange:o];
}
- (void)_cd_setTracked:(id)value forKey:(NSString *)key {
    [self _cd_fire];
    NSRelationshipDescription *r = _entity.relationshipsByName[key];
    if (r.toMany) { NSArray *a = CDToManyArray(value); value = r.ordered ? [NSMutableOrderedSet orderedSetWithArray:a] : [NSMutableSet setWithArray:a]; }
    [self willChangeValueForKey:key];
    if (value) _values[key] = value; else [_values removeObjectForKey:key];
    [self didChangeValueForKey:key];
    touched(self, key);
}
/* to-many: new membership (adds/removes computed), inverses kept in sync */
- (void)_cd_setToMany:(NSArray *)members relationship:(NSRelationshipDescription *)r {
    NSString *key = r.name;
    id cur = [self _cd_raw:key];
    NSArray *old = CDToManyArray(cur);
    NSMutableArray *added = [NSMutableArray array], *removed = [NSMutableArray array];
    for (id o in members) if (![cur containsObject:o]) [added addObject:o];
    NSSet *newSet = [NSSet setWithArray:members];
    for (id o in old) if (![newSet containsObject:o]) [removed addObject:o];
    BOOL reorder = r.ordered && ![old isEqualToArray:members];
    if (!added.count && !removed.count && !reorder) return;
    [self willChangeValueForKey:key];
    _values[key] = r.ordered ? [NSMutableOrderedSet orderedSetWithArray:members] : [NSMutableSet setWithArray:members];
    [self didChangeValueForKey:key];
    touched(self, key);
    NSRelationshipDescription *inv = r.inverseRelationship;
    if (!inv) return;
    for (NSManagedObject *d in removed) {
        if (inv.toMany) [d _cd_rawRemove:self key:inv.name];
        else if ([d _cd_raw:inv.name] == self) [d _cd_rawSetToOne:nil key:inv.name];
    }
    for (NSManagedObject *d in added) {
        if (inv.toMany) [d _cd_rawAdd:self key:inv.name];
        else {
            NSManagedObject *prev = [d _cd_raw:inv.name];
            if (prev == self) continue;
            if (prev) [prev _cd_rawRemove:d key:key];
            [d _cd_rawSetToOne:self key:inv.name];
        }
    }
}
- (void)_cd_rawAdd:(id)o key:(NSString *)key {
    id set = [self _cd_raw:key];
    if ([set containsObject:o]) return;
    [self willChangeValueForKey:key]; [set addObject:o]; [self didChangeValueForKey:key];
    touched(self, key);
}
- (void)_cd_rawRemove:(id)o key:(NSString *)key {
    id set = [self _cd_raw:key];
    if (![set containsObject:o]) return;
    [self willChangeValueForKey:key]; [set removeObject:o]; [self didChangeValueForKey:key];
    touched(self, key);
}
- (void)_cd_rawSetToOne:(id)o key:(NSString *)key {
    [self _cd_fire];
    if (_values[key] == o) return;
    [self willChangeValueForKey:key];
    if (o) _values[key] = o; else [_values removeObjectForKey:key];
    [self didChangeValueForKey:key];
    touched(self, key);
}
- (void)_cd_relationship:(NSRelationshipDescription *)r add:(NSArray *)adds remove:(NSArray *)removes {
    if (!adds.count && !removes.count) return;
    NSMutableArray *m = [CDToManyArray([self _cd_raw:r.name]) mutableCopy];
    for (id o in removes) [m removeObject:o];
    for (id o in adds) if (![m containsObject:o]) [m addObject:o];
    [self _cd_setToMany:m relationship:r];
}
- (void)_cd_setToOne:(NSManagedObject *)n relationship:(NSRelationshipDescription *)r {
    NSString *key = r.name;
    NSManagedObject *old = [self _cd_raw:key];
    if (old == n) return;
    [self _cd_rawSetToOne:n key:key];
    NSRelationshipDescription *inv = r.inverseRelationship;
    if (!inv) return;
    if (old) {
        if (inv.toMany) [old _cd_rawRemove:self key:inv.name];
        else if ([old _cd_raw:inv.name] == self) [old _cd_rawSetToOne:nil key:inv.name];
    }
    if (n) {
        if (inv.toMany) [n _cd_rawAdd:self key:inv.name];
        else {
            NSManagedObject *m = [n _cd_raw:inv.name];
            if (m && m != self) [m _cd_rawSetToOne:nil key:key];
            [n _cd_rawSetToOne:self key:inv.name];
        }
    }
}

/* ---------------- KVC ---------------- */
- (id)primitiveValueForKey:(NSString *)key {
    if (!_entity.propertiesByName[key]) return [super valueForKey:key];
    return [self _cd_raw:key];
}
- (void)setPrimitiveValue:(id)value forKey:(NSString *)key {
    NSPropertyDescription *p = _entity.propertiesByName[key];
    if (!p) { [super setValue:value forKey:key]; return; }
    if ([p isKindOfClass:[NSRelationshipDescription class]] && ((NSRelationshipDescription *)p).toMany) {
        NSRelationshipDescription *r = (NSRelationshipDescription *)p;
        NSArray *a = CDToManyArray(value);
        [self _cd_setRaw:(r.ordered ? [NSMutableOrderedSet orderedSetWithArray:a] : [NSMutableSet setWithArray:a]) forKey:key];
    } else [self _cd_setRaw:value forKey:key];
    touched(self, key);
}
- (id)valueForKey:(NSString *)key {
    NSPropertyDescription *p = _entity.propertiesByName[key];
    if (!p) return [super valueForKey:key];
    if ([p isKindOfClass:[NSFetchedPropertyDescription class]]) {
        NSFetchRequest *req = [((NSFetchedPropertyDescription *)p).fetchRequest copy];
        if (req.predicate) req.predicate = [req.predicate predicateWithSubstitutionVariables:@{ @"FETCH_SOURCE": self }];
        return _ctx ? [_ctx executeFetchRequest:req error:NULL] : @[];
    }
    [self willAccessValueForKey:key];
    id v = [self _cd_raw:key];
    [self didAccessValueForKey:key];
    if ([v isKindOfClass:[NSMutableOrderedSet class]]) return [NSOrderedSet orderedSetWithArray:[v array]];
    if ([v isKindOfClass:[NSMutableSet class]]) return [NSSet setWithArray:[v allObjects]];
    return v;
}
- (void)setValue:(id)value forKey:(NSString *)key {
    NSPropertyDescription *p = _entity.propertiesByName[key];
    if (!p) { [super setValue:value forKey:key]; return; }
    if (value == [NSNull null]) value = nil;
    if ([p isKindOfClass:[NSRelationshipDescription class]]) {
        NSRelationshipDescription *r = (NSRelationshipDescription *)p;
        if (r.toMany) [self _cd_setToMany:CDToManyArray(value) relationship:r];
        else [self _cd_setToOne:value relationship:r];
        return;
    }
    [self _cd_fire];
    id old = _values[key];
    if (old == value || (old && value && [old isEqual:value] && [old class] == [value class])) return;
    [self willChangeValueForKey:key];
    if (value) _values[key] = value; else [_values removeObjectForKey:key];
    [self didChangeValueForKey:key];
    touched(self, key);
}
- (NSMutableSet *)mutableSetValueForKey:(NSString *)key {
    NSRelationshipDescription *r = _entity.relationshipsByName[key];
    if (!r.toMany) return [NSMutableSet setWithArray:CDToManyArray([self valueForKey:key])];
    CDSetProxy *p = [[CDSetProxy alloc] init];
    p.owner = self; p.rel = r;
    for (id o in CDToManyArray([self _cd_raw:key])) [p addObject:o];
    p.ready = YES;
    return p;
}
- (NSMutableOrderedSet *)mutableOrderedSetValueForKey:(NSString *)key {
    NSRelationshipDescription *r = _entity.relationshipsByName[key];
    if (!r.toMany) return [NSMutableOrderedSet orderedSetWithArray:CDToManyArray([self valueForKey:key])];
    CDOrderedSetProxy *p = [[CDOrderedSetProxy alloc] init];
    p.owner = self; p.rel = r;
    for (id o in CDToManyArray([self _cd_raw:key])) [p addObject:o];
    p.ready = YES;
    return p;
}
- (void)willAccessValueForKey:(NSString *)key { [self _cd_fire]; }
- (void)didAccessValueForKey:(NSString *)key {}
- (void)willChangeValueForKey:(NSString *)key {
    if (_willChangeHandler) _willChangeHandler();
    [super willChangeValueForKey:key];
}
- (void)didChangeValueForKey:(NSString *)key { [super didChangeValueForKey:key]; }
- (void)_isim_setWillChangeHandler:(void (^)(void))h { _willChangeHandler = [h copy]; }
- (id)_isim_observationToken { return _observationToken; }
- (void)_isim_setObservationToken:(id)t { _observationToken = t; }

- (NSDictionary *)committedValuesForKeys:(NSArray<NSString *> *)keys {
    [self _cd_fire];
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in keys ?: [_entity.propertiesByName allKeys]) {
        if (!_entity.propertiesByName[k]) continue;
        id v = _committed[k];
        if (!v && _entity.relationshipsByName[k].toMany) { [self _cd_raw:k]; v = _committed[k]; }
        d[k] = v ?: [NSNull null];
    }
    return d;
}
- (NSDictionary *)changedValues {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in self._cd_changedKeys) d[k] = [self valueForKey:k] ?: [NSNull null];
    return d;
}
- (NSDictionary *)changedValuesForCurrentEvent {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSString *k in _eventKeys) d[k] = _committed[k] ?: [NSNull null];
    return d;
}

/* ---------------- lifecycle hooks ---------------- */
- (void)awakeFromFetch {}
- (void)awakeFromInsert {}
- (void)awakeFromSnapshotEvents:(NSSnapshotEventType)flags {}
- (void)prepareForDeletion {}
- (void)willSave {}
- (void)didSave {}
- (void)willTurnIntoFault {}
- (void)didTurnIntoFault {}

/* ---------------- validation ---------------- */
static NSError *verror(NSInteger code, NSManagedObject *o, NSString *key, id value, NSString *msg) {
    NSMutableDictionary *info = [NSMutableDictionary dictionaryWithObject:o forKey:NSValidationObjectErrorKey];
    if (key) info[NSValidationKeyErrorKey] = key;
    if (value) info[NSValidationValueErrorKey] = value;
    return CDError(code, msg, info);
}
- (BOOL)validateValue:(id *)ioValue forKey:(NSString *)key error:(NSError **)error {
    NSPropertyDescription *p = _entity.propertiesByName[key];
    id value = ioValue ? *ioValue : nil;
    if (value == [NSNull null]) value = nil;
    NSError *err = nil;
    if (p && !p.transient) {
        if ([p isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *a = (NSAttributeDescription *)p;
            if (!value && !a.optional) err = verror(NSValidationMissingMandatoryPropertyError, self, key, nil, [NSString stringWithFormat:@"%@ is a required value.", key]);
            else if ([value isKindOfClass:[NSNumber class]] && (a._cd_minValue || a._cd_maxValue)) {
                double v = [value doubleValue];
                if (a._cd_minValue && v < a._cd_minValue.doubleValue) err = verror(NSValidationNumberTooSmallError, self, key, value, [NSString stringWithFormat:@"%@ is too small.", key]);
                else if (a._cd_maxValue && v > a._cd_maxValue.doubleValue) err = verror(NSValidationNumberTooLargeError, self, key, value, [NSString stringWithFormat:@"%@ is too large.", key]);
            } else if ([value isKindOfClass:[NSString class]]) {
                NSUInteger len = [value length];
                if (a._cd_minValue && len < (NSUInteger)a._cd_minValue.integerValue) err = verror(NSValidationStringTooShortError, self, key, value, [NSString stringWithFormat:@"%@ is too short.", key]);
                else if (a._cd_maxValue && len > (NSUInteger)a._cd_maxValue.integerValue) err = verror(NSValidationStringTooLongError, self, key, value, [NSString stringWithFormat:@"%@ is too long.", key]);
                else if (a._cd_regex.length && ![[NSPredicate predicateWithFormat:@"SELF MATCHES %@", a._cd_regex] evaluateWithObject:value])
                    err = verror(NSValidationStringPatternMatchingError, self, key, value, [NSString stringWithFormat:@"%@ does not match its pattern.", key]);
            }
        } else if ([p isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *r = (NSRelationshipDescription *)p;
            if (!r.toMany) { if (!value && !r.optional) err = verror(NSValidationMissingMandatoryPropertyError, self, key, nil, [NSString stringWithFormat:@"%@ is a required value.", key]); }
            else {
                NSUInteger n = [value count];
                if ((!r.optional || n) && r.minCount && n < r.minCount) err = verror(NSValidationRelationshipLacksMinimumCountError, self, key, value, [NSString stringWithFormat:@"Too few items in %@.", key]);
                else if (r.maxCount && n > r.maxCount) err = verror(NSValidationRelationshipExceedsMaximumCountError, self, key, value, [NSString stringWithFormat:@"Too many items in %@.", key]);
                else if (!r.optional && !n && !r.minCount) err = verror(NSValidationRelationshipLacksMinimumCountError, self, key, value, [NSString stringWithFormat:@"%@ must not be empty.", key]);
            }
        }
        if (!err && value) {
            NSArray *preds = p.validationPredicates, *warn = p.validationWarnings;
            for (NSUInteger i = 0; i < preds.count; i++) if (![preds[i] evaluateWithObject:value]) {
                err = verror(NSManagedObjectValidationError, self, key, value, i < warn.count ? warn[i] : [NSString stringWithFormat:@"%@ is invalid.", key]);
                NSMutableDictionary *info = [err.userInfo mutableCopy]; info[NSValidationPredicateErrorKey] = preds[i];
                err = [NSError errorWithDomain:err.domain code:err.code userInfo:info];
                break;
            }
        }
    }
    if (!err && key.length) {                                  /* -validate<Key>:error: */
        NSString *selName = [NSString stringWithFormat:@"validate%@%@:error:", [key substringToIndex:1].uppercaseString, [key substringFromIndex:1]];
        SEL sel = NSSelectorFromString(selName);
        if ([self respondsToSelector:sel]) {
            id v = value; NSError *e2 = nil;
            BOOL ok = ((BOOL (*)(id, SEL, id *, NSError **))[self methodForSelector:sel])(self, sel, &v, &e2);
            if (!ok) err = e2 ?: verror(NSManagedObjectValidationError, self, key, value, [NSString stringWithFormat:@"%@ is invalid.", key]);
            else if (ioValue) *ioValue = v;
        }
    }
    if (err) { if (error) *error = err; return NO; }
    return YES;
}
static BOOL collect(NSArray *errors, NSError **error) {
    if (!errors.count) return YES;
    if (error) *error = errors.count == 1 ? errors[0] : CDError(NSValidationMultipleErrorsError, @"Multiple validation errors occurred.", @{ NSDetailedErrorsKey: errors });
    return NO;
}
- (BOOL)_cd_validateAll:(NSError **)error {
    NSMutableArray *errs = [NSMutableArray array];
    for (NSPropertyDescription *p in _entity.properties) {
        if (p.transient || [p isKindOfClass:[NSFetchedPropertyDescription class]]) continue;
        id v = [self valueForKey:p.name];
        NSError *e = nil;
        if (![self validateValue:&v forKey:p.name error:&e] && e) {
            if (e.code == NSValidationMultipleErrorsError) [errs addObjectsFromArray:e.userInfo[NSDetailedErrorsKey]]; else [errs addObject:e];
        }
    }
    return collect(errs, error);
}
- (BOOL)validateForInsert:(NSError **)error { return [self _cd_validateAll:error]; }
- (BOOL)validateForUpdate:(NSError **)error { return [self _cd_validateAll:error]; }
- (BOOL)validateForDelete:(NSError **)error {
    NSMutableArray *errs = [NSMutableArray array];
    for (NSRelationshipDescription *r in _entity.relationshipsByName.allValues) {
        if (r.deleteRule != NSDenyDeleteRule) continue;
        NSMutableArray *live = [NSMutableArray array];
        for (NSManagedObject *o in CDToManyArray([self _cd_raw:r.name])) if (!o.isDeleted) [live addObject:o];
        if (live.count) [errs addObject:verror(NSValidationRelationshipDeniedDeleteError, self, r.name, live, [NSString stringWithFormat:@"%@ is not empty (delete rule Deny).", r.name])];
    }
    return collect(errs, error);
}

- (NSString *)description {
    NSString *data;
    if (_fault) data = @"<fault>";
    else {
        NSMutableArray *parts = [NSMutableArray array];
        for (NSPropertyDescription *p in _entity.properties) {
            id v = _values[p.name];
            NSString *s;
            if ([p isKindOfClass:[NSRelationshipDescription class]]) {
                if (((NSRelationshipDescription *)p).toMany) s = v ? [NSString stringWithFormat:@"<relationship, %lu objects>", (unsigned long)[v count]] : @"<relationship fault>";
                else s = v ? [[v objectID] description] : @"nil";
            } else s = v ? [v description] : @"nil";
            [parts addObject:[NSString stringWithFormat:@"    %@ = %@;", p.name, s]];
        }
        data = [NSString stringWithFormat:@"{\n%@\n}", [parts componentsJoinedByString:@"\n"]];
    }
    return [NSString stringWithFormat:@"<%@: %p> (entity: %@; id: %@; data: %@)", NSStringFromClass([self class]), self, _entity.name, self.objectID, data];
}

/* ---------------- dynamic accessors (@NSManaged / @dynamic) ---------------- */
static NSMutableDictionary<NSString *, NSString *> *sel_keys;
static NSString *lower_first(NSString *s) { return s.length ? [[s substringToIndex:1].lowercaseString stringByAppendingString:[s substringFromIndex:1]] : s; }
static NSString *key_for(SEL sel, int kind);
enum { K_GET, K_SET, K_PGET, K_PSET, K_ADDOBJ, K_REMOBJ, K_ADDSET, K_REMSET, K_INSAT, K_REMAT, K_REPLAT, K_INSIDX, K_REMIDX, K_REPLIDX };
static const struct { const char *prefix, *suffix; int kind; } forms[] = {
    { "setPrimitive", ":", K_PSET }, { "primitive", "", K_PGET },
    { "insertObject:in", "AtIndex:", K_INSAT }, { "removeObjectFrom", "AtIndex:", K_REMAT },
    { "replaceObjectIn", "AtIndex:withObject:", K_REPLAT },
    { "insert", ":atIndexes:", K_INSIDX }, { "remove", "AtIndexes:", K_REMIDX },
    { "add", "Object:", K_ADDOBJ }, { "remove", "Object:", K_REMOBJ },
    { "set", ":", K_SET }, { "add", ":", K_ADDSET }, { "remove", ":", K_REMSET },
};
static NSString *key_for(SEL sel, int kind) {
    NSString *name = NSStringFromSelector(sel);
    NSString *ck = [NSString stringWithFormat:@"%d:%@", kind, name];
    @synchronized ([NSManagedObject class]) { NSString *k = sel_keys[ck]; if (k) return k; }
    NSString *key = name;
    if (kind != K_GET) {
        for (size_t i = 0; i < sizeof forms / sizeof *forms; i++) {
            if (forms[i].kind != kind) continue;
            NSString *p = @(forms[i].prefix), *s = @(forms[i].suffix);
            if ([name hasPrefix:p] && [name hasSuffix:s] && name.length > p.length + s.length) {
                key = lower_first([name substringWithRange:NSMakeRange(p.length, name.length - p.length - s.length)]);
                break;
            }
        }
    }
    @synchronized ([NSManagedObject class]) { if (!sel_keys) sel_keys = [NSMutableDictionary dictionary]; sel_keys[ck] = key; }
    return key;
}
#define KEY(kind) key_for(_cmd, kind)
static id g_obj(NSManagedObject *self, SEL _cmd) { return [self valueForKey:KEY(K_GET)]; }
static long long g_q(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] longLongValue]; }
static unsigned long long g_Q(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] unsignedLongLongValue]; }
static int g_i(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] intValue]; }
static unsigned g_I(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] unsignedIntValue]; }
static short g_s(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] shortValue]; }
static unsigned short g_S(NSManagedObject *self, SEL _cmd) { return (unsigned short)[[self valueForKey:KEY(K_GET)] unsignedIntValue]; }
static signed char g_c(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] charValue]; }
static unsigned char g_C(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] unsignedCharValue]; }
static bool g_B(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] boolValue]; }
static double g_d(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] doubleValue]; }
static float g_f(NSManagedObject *self, SEL _cmd) { return [[self valueForKey:KEY(K_GET)] floatValue]; }
static void s_obj(NSManagedObject *self, SEL _cmd, id v) { [self setValue:v forKey:KEY(K_SET)]; }
static void s_q(NSManagedObject *self, SEL _cmd, long long v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_Q(NSManagedObject *self, SEL _cmd, unsigned long long v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_i(NSManagedObject *self, SEL _cmd, int v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_I(NSManagedObject *self, SEL _cmd, unsigned v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_s(NSManagedObject *self, SEL _cmd, short v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_S(NSManagedObject *self, SEL _cmd, unsigned short v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_c(NSManagedObject *self, SEL _cmd, signed char v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_C(NSManagedObject *self, SEL _cmd, unsigned char v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_B(NSManagedObject *self, SEL _cmd, bool v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_d(NSManagedObject *self, SEL _cmd, double v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static void s_f(NSManagedObject *self, SEL _cmd, float v) { [self setValue:@(v) forKey:KEY(K_SET)]; }
static id pg_obj(NSManagedObject *self, SEL _cmd) { return [self primitiveValueForKey:KEY(K_PGET)]; }
static void ps_obj(NSManagedObject *self, SEL _cmd, id v) { [self setPrimitiveValue:v forKey:KEY(K_PSET)]; }
static NSRelationshipDescription *rel_of(NSManagedObject *self, NSString *key) { return self.entity.relationshipsByName[key]; }
static void m_addobj(NSManagedObject *self, SEL _cmd, id o) { NSString *k = KEY(K_ADDOBJ); if (o) [self _cd_relationship:rel_of(self, k) add:@[o] remove:nil]; }
static void m_remobj(NSManagedObject *self, SEL _cmd, id o) { NSString *k = KEY(K_REMOBJ); if (o) [self _cd_relationship:rel_of(self, k) add:nil remove:@[o]]; }
static void m_addset(NSManagedObject *self, SEL _cmd, id s) { NSString *k = KEY(K_ADDSET); [self _cd_relationship:rel_of(self, k) add:CDToManyArray(s) remove:nil]; }
static void m_remset(NSManagedObject *self, SEL _cmd, id s) { NSString *k = KEY(K_REMSET); [self _cd_relationship:rel_of(self, k) add:nil remove:CDToManyArray(s)]; }
static NSMutableArray *ordered_members(NSManagedObject *self, NSString *k) { return [CDToManyArray([self _cd_raw:k]) mutableCopy]; }
static void m_insat(NSManagedObject *self, SEL _cmd, id o, NSUInteger i) {
    NSString *k = KEY(K_INSAT); NSMutableArray *m = ordered_members(self, k);
    [m removeObject:o]; [m insertObject:o atIndex:MIN(i, m.count)];
    [self _cd_setToMany:m relationship:rel_of(self, k)];
}
static void m_remat(NSManagedObject *self, SEL _cmd, NSUInteger i) {
    NSString *k = KEY(K_REMAT); NSMutableArray *m = ordered_members(self, k);
    if (i < m.count) [m removeObjectAtIndex:i];
    [self _cd_setToMany:m relationship:rel_of(self, k)];
}
static void m_replat(NSManagedObject *self, SEL _cmd, NSUInteger i, id o) {
    NSString *k = KEY(K_REPLAT); NSMutableArray *m = ordered_members(self, k);
    if (i < m.count) { [m removeObject:o]; m[MIN(i, m.count - 1)] = o; }
    [self _cd_setToMany:m relationship:rel_of(self, k)];
}
static void m_insidx(NSManagedObject *self, SEL _cmd, NSArray *objs, NSIndexSet *idx) {
    NSString *k = KEY(K_INSIDX); NSMutableArray *m = ordered_members(self, k);
    __block NSUInteger j = 0;
    NSArray *list = CDToManyArray(objs);
    [idx enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { if (j < list.count) { [m removeObject:list[j]]; [m insertObject:list[j++] atIndex:MIN(i, m.count)]; } }];
    [self _cd_setToMany:m relationship:rel_of(self, k)];
}
static void m_remidx(NSManagedObject *self, SEL _cmd, NSIndexSet *idx) {
    NSString *k = KEY(K_REMIDX); NSMutableArray *m = ordered_members(self, k);
    NSMutableIndexSet *valid = [NSMutableIndexSet indexSet];
    [idx enumerateIndexesUsingBlock:^(NSUInteger i, BOOL *stop) { if (i < m.count) [valid addIndex:i]; }];
    [m removeObjectsAtIndexes:valid];
    [self _cd_setToMany:m relationship:rel_of(self, k)];
}

static char declared_type(Class cls, NSString *key) {
    objc_property_t p = class_getProperty(cls, key.UTF8String);
    const char *a = p ? property_getAttributes(p) : NULL;
    if (a && a[0] == 'T') return a[1] == 'r' ? a[2] : a[1];
    return 0;
}
static BOOL is_dynamic_property(Class cls, NSString *key) {
    objc_property_t p = class_getProperty(cls, key.UTF8String);
    const char *a = p ? property_getAttributes(p) : NULL;
    return a && strstr(a, ",D") != NULL;
}
+ (BOOL)resolveInstanceMethod:(SEL)sel {
    if (self == [NSManagedObject class]) return [super resolveInstanceMethod:sel];
    NSString *name = NSStringFromSelector(sel);
    NSUInteger colons = [name componentsSeparatedByString:@":"].count - 1;
    NSEntityDescription *entity = CDEntityForClass(self);
    BOOL (^known)(NSString *) = ^BOOL(NSString *k) { return entity.propertiesByName[k] != nil || is_dynamic_property(self, k); };
    BOOL (^knownRel)(NSString *) = ^BOOL(NSString *k) {
        if (entity) return entity.relationshipsByName[k] != nil;
        char t = declared_type(self, k); return t == '@' && is_dynamic_property(self, k);
    };
    IMP imp = NULL; const char *types = NULL;
    if (colons == 0) {
        if (known(name)) {
            char t = declared_type(self, name);
            switch (t) {
            case 'q': case 'l': imp = (IMP)g_q; types = "q@:"; break;
            case 'Q': case 'L': imp = (IMP)g_Q; types = "Q@:"; break;
            case 'i': imp = (IMP)g_i; types = "i@:"; break;
            case 'I': imp = (IMP)g_I; types = "I@:"; break;
            case 's': imp = (IMP)g_s; types = "s@:"; break;
            case 'S': imp = (IMP)g_S; types = "S@:"; break;
            case 'c': imp = (IMP)g_c; types = "c@:"; break;
            case 'C': imp = (IMP)g_C; types = "C@:"; break;
            case 'B': imp = (IMP)g_B; types = "B@:"; break;
            case 'd': imp = (IMP)g_d; types = "d@:"; break;
            case 'f': imp = (IMP)g_f; types = "f@:"; break;
            default: imp = (IMP)g_obj; types = "@@:"; break;
            }
        } else if ([name hasPrefix:@"primitive"] && known(key_for(sel, K_PGET))) { imp = (IMP)pg_obj; types = "@@:"; }
    } else {
        int kinds[] = { K_PSET, K_INSAT, K_REMAT, K_REPLAT, K_INSIDX, K_REMIDX, K_ADDOBJ, K_REMOBJ, K_SET, K_ADDSET, K_REMSET };
        for (size_t i = 0; i < sizeof kinds / sizeof *kinds && !imp; i++) {
            int kind = kinds[i];
            BOOL formMatches = NO;
            for (size_t f = 0; f < sizeof forms / sizeof *forms; f++)
                if (forms[f].kind == kind && [name hasPrefix:@(forms[f].prefix)] && [name hasSuffix:@(forms[f].suffix)] &&
                    name.length > strlen(forms[f].prefix) + strlen(forms[f].suffix)) formMatches = YES;
            if (!formMatches) continue;
            NSString *k = key_for(sel, kind);
            NSUInteger want = kind == K_REPLAT || kind == K_INSAT || kind == K_INSIDX ? 2 : 1;
            if (colons != want) continue;
            switch (kind) {
            case K_PSET: if (known(k)) { imp = (IMP)ps_obj; types = "v@:@"; } break;
            case K_SET:
                if (known(k)) {
                    switch (declared_type(self, k)) {
                    case 'q': case 'l': imp = (IMP)s_q; types = "v@:q"; break;
                    case 'Q': case 'L': imp = (IMP)s_Q; types = "v@:Q"; break;
                    case 'i': imp = (IMP)s_i; types = "v@:i"; break;
                    case 'I': imp = (IMP)s_I; types = "v@:I"; break;
                    case 's': imp = (IMP)s_s; types = "v@:s"; break;
                    case 'S': imp = (IMP)s_S; types = "v@:S"; break;
                    case 'c': imp = (IMP)s_c; types = "v@:c"; break;
                    case 'C': imp = (IMP)s_C; types = "v@:C"; break;
                    case 'B': imp = (IMP)s_B; types = "v@:B"; break;
                    case 'd': imp = (IMP)s_d; types = "v@:d"; break;
                    case 'f': imp = (IMP)s_f; types = "v@:f"; break;
                    default: imp = (IMP)s_obj; types = "v@:@"; break;
                    }
                }
                break;
            case K_ADDOBJ: if (knownRel(k)) { imp = (IMP)m_addobj; types = "v@:@"; } break;
            case K_REMOBJ: if (knownRel(k)) { imp = (IMP)m_remobj; types = "v@:@"; } break;
            case K_ADDSET: if (knownRel(k)) { imp = (IMP)m_addset; types = "v@:@"; } break;
            case K_REMSET: if (knownRel(k)) { imp = (IMP)m_remset; types = "v@:@"; } break;
            case K_INSAT: if (knownRel(k)) { imp = (IMP)m_insat; types = "v@:@Q"; } break;
            case K_REMAT: if (knownRel(k)) { imp = (IMP)m_remat; types = "v@:Q"; } break;
            case K_REPLAT: if (knownRel(k)) { imp = (IMP)m_replat; types = "v@:Q@"; } break;
            case K_INSIDX: if (knownRel(k)) { imp = (IMP)m_insidx; types = "v@:@@"; } break;
            case K_REMIDX: if (knownRel(k)) { imp = (IMP)m_remidx; types = "v@:@"; } break;
            }
        }
    }
    if (imp) { class_addMethod(self, sel, imp, types); return YES; }
    return [super resolveInstanceMethod:sel];
}
@end
