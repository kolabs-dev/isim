/* isim Core Data (ARC): NSManagedObjectContext — object registry, change tracking and notifications, delete
 * rules, fetching (store SQL + in-memory pending changes), saving (to the store, or into a parent context),
 * merging, queues (perform / performAndWait), and NSMergePolicy. */
#import "CoreDataPrivate.h"

NSNotificationName const NSManagedObjectContextWillSaveNotification = @"NSManagedObjectContextWillSaveNotification";
NSNotificationName const NSManagedObjectContextDidSaveNotification = @"NSManagingContextDidSaveChangesNotification";
NSNotificationName const NSManagedObjectContextObjectsDidChangeNotification = @"NSObjectsChangedInManagingContextNotification";
NSNotificationName const NSManagedObjectContextDidSaveObjectIDsNotification = @"NSManagedObjectContextDidSaveObjectIDsNotification";
NSNotificationName const NSManagedObjectContextDidMergeChangesObjectIDsNotification = @"NSManagedObjectContextDidMergeChangesObjectIDsNotification";
NSString * const NSInsertedObjectsKey = @"inserted";
NSString * const NSUpdatedObjectsKey = @"updated";
NSString * const NSDeletedObjectsKey = @"deleted";
NSString * const NSRefreshedObjectsKey = @"refreshed";
NSString * const NSInvalidatedObjectsKey = @"invalidated";
NSString * const NSInvalidatedAllObjectsKey = @"invalidatedAll";
NSString * const NSInsertedObjectIDsKey = @"inserted_objectIDs";
NSString * const NSUpdatedObjectIDsKey = @"updated_objectIDs";
NSString * const NSDeletedObjectIDsKey = @"deleted_objectIDs";
NSString * const NSRefreshedObjectIDsKey = @"refreshed_objectIDs";
NSString * const NSInvalidatedObjectIDsKey = @"invalidated_objectIDs";
NSString * const NSManagedObjectContextQueryGenerationKey = @"managedObjectContextQueryGeneration";

/* ================= NSMergePolicy ================= */
@implementation NSMergePolicy
- (id)initWithMergeType:(NSMergePolicyType)ty { if ((self = [super init])) _mergeType = ty; return self; }
static NSMergePolicy *policy(NSMergePolicyType t) {
    static NSMergePolicy *p[5];
    static dispatch_once_t once;
    dispatch_once(&once, ^{ for (int i = 0; i < 5; i++) p[i] = [[NSMergePolicy alloc] initWithMergeType:(NSMergePolicyType)i]; });
    return p[t];
}
+ (NSMergePolicy *)errorMergePolicy { return policy(NSErrorMergePolicyType); }
+ (NSMergePolicy *)rollbackMergePolicy { return policy(NSRollbackMergePolicyType); }
+ (NSMergePolicy *)overwriteMergePolicy { return policy(NSOverwriteMergePolicyType); }
+ (NSMergePolicy *)mergeByPropertyObjectTrumpMergePolicy { return policy(NSMergeByPropertyObjectTrumpMergePolicyType); }
+ (NSMergePolicy *)mergeByPropertyStoreTrumpMergePolicy { return policy(NSMergeByPropertyStoreTrumpMergePolicyType); }
- (NSString *)description { return [NSString stringWithFormat:@"<NSMergePolicy: %p> type %lu", self, (unsigned long)_mergeType]; }
@end
id NSErrorMergePolicy, NSMergeByPropertyStoreTrumpMergePolicy, NSMergeByPropertyObjectTrumpMergePolicy, NSOverwriteMergePolicy, NSRollbackMergePolicy;
__attribute__((constructor)) static void cd_policies(void) {
    NSErrorMergePolicy = policy(NSErrorMergePolicyType);
    NSMergeByPropertyStoreTrumpMergePolicy = policy(NSMergeByPropertyStoreTrumpMergePolicyType);
    NSMergeByPropertyObjectTrumpMergePolicy = policy(NSMergeByPropertyObjectTrumpMergePolicyType);
    NSOverwriteMergePolicy = policy(NSOverwriteMergePolicyType);
    NSRollbackMergePolicy = policy(NSRollbackMergePolicyType);
}

static __thread __unsafe_unretained NSManagedObjectContext *cd_current;

/* ================= NSManagedObjectContext ================= */
@implementation NSManagedObjectContext {
    NSManagedObjectContextConcurrencyType _type;
    dispatch_queue_t _queue;
    NSMutableDictionary<NSManagedObjectID *, NSManagedObject *> *_registered;
    NSMutableDictionary<NSManagedObjectID *, NSManagedObjectID *> *_tempToPermanent;
    NSMutableSet *_inserted, *_updated, *_deleted;
    NSMutableSet *_pInserted, *_pUpdated, *_pDeleted;
    BOOL _pScheduled;
    NSHashTable *_children;
    NSRecursiveLock *_lock;
    NSMutableDictionary *_userInfo;
    NSPersistentStoreCoordinator *_psc;
    NSManagedObjectContext *_parent;
}
@synthesize userInfo = _userInfo;
+ (NSManagedObjectContext *)_cd_current { return cd_current; }

- (instancetype)initWithConcurrencyType:(NSManagedObjectContextConcurrencyType)ct {
    if (!(self = [super init])) return nil;
    _type = ct;
    if (ct == NSPrivateQueueConcurrencyType) _queue = dispatch_queue_create("NSManagedObjectContext", DISPATCH_QUEUE_SERIAL);
    _registered = [NSMutableDictionary dictionary];
    _tempToPermanent = [NSMutableDictionary dictionary];
    _inserted = [NSMutableSet set]; _updated = [NSMutableSet set]; _deleted = [NSMutableSet set];
    _pInserted = [NSMutableSet set]; _pUpdated = [NSMutableSet set]; _pDeleted = [NSMutableSet set];
    _children = [NSHashTable weakObjectsHashTable];
    _lock = [[NSRecursiveLock alloc] init];
    _userInfo = [NSMutableDictionary dictionary];
    _mergePolicy = NSErrorMergePolicy;
    _retainsRegisteredObjects = YES;
    _propagatesDeletesAtEndOfEvent = YES;
    _shouldDeleteInaccessibleFaults = YES;
    _stalenessInterval = -1;
    return self;
}
- (NSManagedObjectContextConcurrencyType)concurrencyType { return _type; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSManagedObjectContext: %p>%@", self, self.name ? [@" " stringByAppendingString:self.name] : @""]; }

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator { return _psc ?: _parent.persistentStoreCoordinator; }
- (void)setPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)c {
    _psc = c;
    if (c) { CDRegisterModel(c.managedObjectModel); [c _cd_registerContext:self]; }
}
- (NSManagedObjectContext *)parentContext { return _parent; }
- (void)setParentContext:(NSManagedObjectContext *)p { _parent = p; [p _cd_registerChild:self]; }
- (void)_cd_registerChild:(NSManagedObjectContext *)child { @synchronized (_children) { [_children addObject:child]; } }

/* ---------------- queues ---------------- */
- (void)_cd_run:(void (^)(void))block {
    NSManagedObjectContext *prev = cd_current;
    cd_current = self;
    @autoreleasepool { block(); }
    [self processPendingChanges];
    cd_current = prev;
}
- (void)performBlock:(void (^)(void))block {
    void (^b)(void) = [block copy];
    dispatch_queue_t q = _type == NSPrivateQueueConcurrencyType ? _queue : dispatch_get_main_queue();
    dispatch_async(q, ^{ [self _cd_run:b]; });
}
- (void)performBlockAndWait:(void (NS_NOESCAPE ^)(void))block {
    if (_type == NSPrivateQueueConcurrencyType) dispatch_sync(_queue, ^{ [self _cd_run:block]; });
    else if (_type == NSConfinementConcurrencyType || [NSThread isMainThread]) [self _cd_run:block];
    else dispatch_sync(dispatch_get_main_queue(), ^{ [self _cd_run:block]; });
}
- (void)lock { [_lock lock]; }
- (void)unlock { [_lock unlock]; }
- (BOOL)tryLock { return [_lock tryLock]; }

/* ---------------- registry ---------------- */
- (NSEntityDescription *)_cd_entityNamed:(NSString *)name {
    return name ? self.persistentStoreCoordinator.managedObjectModel.entitiesByName[name] : nil;
}
- (void)_cd_registerObject:(NSManagedObject *)o {
    _registered[o.objectID] = o;
    [o _cd_setContext:self];
}
- (void)_cd_unregister:(NSManagedObject *)o {
    [_registered removeObjectForKey:o.objectID];
    [_inserted removeObject:o]; [_updated removeObject:o]; [_deleted removeObject:o];
}
- (NSManagedObject *)objectRegisteredForID:(NSManagedObjectID *)oid {
    if (!oid) return nil;
    NSManagedObject *o = _registered[oid];
    if (!o && _tempToPermanent[oid]) o = _registered[_tempToPermanent[oid]];
    return o;
}
- (NSManagedObject *)objectWithID:(NSManagedObjectID *)oid {
    if (!oid) return nil;
    NSManagedObject *o = [self objectRegisteredForID:oid];
    if (o) return o;
    NSEntityDescription *e = oid.entity;
    o = [[e._cd_objectClass alloc] _cd_initFaultWithEntity:e];
    [o _cd_setObjectID:oid];
    [self _cd_registerObject:o];
    return o;
}
- (NSManagedObject *)existingObjectWithID:(NSManagedObjectID *)oid error:(NSError **)error {
    NSManagedObject *o = [self objectRegisteredForID:oid];
    if (o && ![o _cd_isFault] && ![_deleted containsObject:o]) return o;
    CDSnapshot *s = oid.temporaryID && !_parent ? nil : [self _cd_snapshotForObjectID:oid];
    if (!s) {
        if (error) *error = CDError(NSManagedObjectReferentialIntegrityError, [NSString stringWithFormat:@"The object %@ could not be found.", oid], nil);
        return nil;
    }
    o = [self objectWithID:oid];
    if ([o _cd_isFault]) { [o _cd_applySnapshot:s]; [o awakeFromFetch]; }
    return o;
}
- (NSManagedObject *)_cd_objectForSnapshot:(CDSnapshot *)s {
    NSManagedObject *o = [self objectRegisteredForID:s.objectID];
    if (o) {
        if ([o _cd_isFault]) { [o _cd_applySnapshot:s]; [o awakeFromFetch]; }
        return o;
    }
    NSEntityDescription *e = s.objectID.entity;
    o = [[e._cd_objectClass alloc] _cd_initFaultWithEntity:e];
    [o _cd_setObjectID:s.objectID];
    [self _cd_registerObject:o];
    [o _cd_applySnapshot:s];
    [o awakeFromFetch];
    return o;
}
- (CDSnapshot *)_cd_snapshotForObjectID:(NSManagedObjectID *)oid {
    NSManagedObjectContext *p = _parent;
    if (p) {
        __block CDSnapshot *s = nil;
        [p performBlockAndWait:^{
            NSManagedObject *po = [p objectRegisteredForID:oid];
            if (po) { if (![p _cd_isDeleted:po]) s = [po _cd_snapshotForChild]; }
            else s = [p _cd_snapshotForObjectID:oid];
        }];
        return s;
    }
    NSPersistentStoreCoordinator *c = self.persistentStoreCoordinator;
    if (oid.temporaryID) return nil;
    CDSQLStore *store = (CDSQLStore *)oid.persistentStore ?: [c _cd_storeForEntity:oid.entity];
    if (![store isKindOfClass:[CDSQLStore class]]) return nil;
    [c lock];
    CDSnapshot *s = [store _cd_rowForObjectID:oid];
    [c unlock];
    return s;
}
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDsForID:(NSManagedObjectID *)oid relationship:(NSRelationshipDescription *)r {
    NSManagedObjectContext *p = _parent;
    if (p) {
        __block NSArray *ids = @[];
        [p performBlockAndWait:^{
            NSManagedObject *po = [p objectRegisteredForID:oid];
            if (po) {
                NSMutableArray *a = [NSMutableArray array];
                for (NSManagedObject *x in CDToManyArray([po _cd_raw:r.name])) if (![p _cd_isDeleted:x]) [a addObject:x.objectID];
                ids = a;
            } else ids = [p _cd_relatedIDsForID:oid relationship:r];
        }];
        return ids;
    }
    if (oid.temporaryID) return @[];
    NSPersistentStoreCoordinator *c = self.persistentStoreCoordinator;
    CDSQLStore *store = (CDSQLStore *)oid.persistentStore ?: [c _cd_storeForEntity:oid.entity];
    if (![store isKindOfClass:[CDSQLStore class]]) return @[];
    [c lock];
    NSArray *ids = [store _cd_relatedIDs:oid relationship:r];
    [c unlock];
    return ids;
}
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDs:(NSManagedObject *)o relationship:(NSRelationshipDescription *)r {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObjectID *i in [self _cd_relatedIDsForID:o.objectID relationship:r]) {
        NSManagedObject *x = [self objectRegisteredForID:i];
        if (x && [_deleted containsObject:x]) continue;
        [ids addObject:i];
    }
    return ids;
}

/* ---------------- change tracking ---------------- */
- (BOOL)_cd_isInserted:(NSManagedObject *)o { return [_inserted containsObject:o]; }
- (BOOL)_cd_isUpdated:(NSManagedObject *)o { return [_updated containsObject:o]; }
- (BOOL)_cd_isDeleted:(NSManagedObject *)o { return [_deleted containsObject:o]; }
- (void)_cd_schedule {
    if (_pScheduled) return;
    _pScheduled = YES;
    dispatch_queue_t q = _type == NSPrivateQueueConcurrencyType ? _queue : dispatch_get_main_queue();
    dispatch_async(q, ^{ if (self->_pScheduled) [self processPendingChanges]; });
}
- (void)_cd_objectDidChange:(NSManagedObject *)o {
    if (!o || [_deleted containsObject:o]) return;
    if (![_inserted containsObject:o]) { [_updated addObject:o]; [_pUpdated addObject:o]; }
    [self _cd_schedule];
}
- (void)insertObject:(NSManagedObject *)o {
    if (!o) return;
    if ([_deleted containsObject:o]) { [_deleted removeObject:o]; [_pDeleted removeObject:o]; [self _cd_schedule]; return; }
    if ([_inserted containsObject:o]) return;
    [self _cd_registerObject:o];
    [_inserted addObject:o]; [_pInserted addObject:o];
    [self _cd_schedule];
    [o awakeFromInsert];
}
- (void)deleteObject:(NSManagedObject *)o {
    if (!o || o.managedObjectContext != self || [_deleted containsObject:o]) return;
    [o _cd_fire];
    [o prepareForDeletion];
    BOOL wasInserted = [_inserted containsObject:o];
    if (wasInserted) { [_inserted removeObject:o]; [_pInserted removeObject:o]; }
    else { [_deleted addObject:o]; [_pDeleted addObject:o]; }
    [_updated removeObject:o]; [_pUpdated removeObject:o];
    for (NSRelationshipDescription *r in o.entity.relationshipsByName.allValues) {
        if (r.deleteRule == NSDenyDeleteRule || r.deleteRule == NSNoActionDeleteRule) continue;
        NSArray *dest = CDToManyArray([o _cd_raw:r.name]);
        NSRelationshipDescription *inv = r.inverseRelationship;
        for (NSManagedObject *d in dest) {
            if (r.deleteRule == NSCascadeDeleteRule) [self deleteObject:d];
            else if (inv) {                                      /* nullify: drop the object from the other side */
                if (inv.toMany) [d _cd_relationship:inv add:nil remove:@[o]];
                else if ([d _cd_raw:inv.name] == o) [d _cd_setTracked:nil forKey:inv.name];
            }
        }
    }
    if (wasInserted) { [_registered removeObjectForKey:o.objectID]; [_pDeleted addObject:o]; }
    [self _cd_schedule];
}
- (void)processPendingChanges {
    _pScheduled = NO;
    if (!_pInserted.count && !_pUpdated.count && !_pDeleted.count) return;
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (_pInserted.count) info[NSInsertedObjectsKey] = [_pInserted copy];
    if (_pUpdated.count) info[NSUpdatedObjectsKey] = [_pUpdated copy];
    if (_pDeleted.count) info[NSDeletedObjectsKey] = [_pDeleted copy];
    NSArray *touchedObjs = [[_pInserted.allObjects arrayByAddingObjectsFromArray:_pUpdated.allObjects] arrayByAddingObjectsFromArray:_pDeleted.allObjects];
    [_pInserted removeAllObjects]; [_pUpdated removeAllObjects]; [_pDeleted removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification object:self userInfo:info];
    for (NSManagedObject *o in touchedObjs) [o._cd_changedKeysSinceEvent removeAllObjects];
}
- (BOOL)hasChanges { return _inserted.count || _deleted.count || _updated.count; }
- (NSSet *)insertedObjects { return [_inserted copy]; }
- (NSSet *)updatedObjects { return [_updated copy]; }
- (NSSet *)deletedObjects { return [_deleted copy]; }
- (NSSet *)registeredObjects { return [NSSet setWithArray:_registered.allValues]; }
- (void)assignObject:(id)object toPersistentStore:(NSPersistentStore *)store {}
- (void)detectConflictsForObject:(NSManagedObject *)object {}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {}
- (void)undo { [self.undoManager undo]; }
- (void)redo { [self.undoManager redo]; }

- (void)rollback {
    [self processPendingChanges];
    NSSet *ins = [_inserted copy], *upd = [_updated copy], *del = [_deleted copy];
    for (NSManagedObject *o in ins) { [_registered removeObjectForKey:o.objectID]; }
    [_inserted removeAllObjects]; [_updated removeAllObjects]; [_deleted removeAllObjects];
    for (NSManagedObject *o in upd) [o _cd_resetToCommitted];
    for (NSManagedObject *o in del) [o _cd_resetToCommitted];
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (ins.count) info[NSDeletedObjectsKey] = ins;
    if (del.count) info[NSInsertedObjectsKey] = del;
    if (upd.count) info[NSRefreshedObjectsKey] = upd;
    if (info.count) [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification object:self userInfo:info];
}
- (void)reset {
    for (NSManagedObject *o in _registered.allValues) { [o _cd_turnIntoFault]; [o _cd_setContext:nil]; }
    [_registered removeAllObjects]; [_tempToPermanent removeAllObjects];
    [_inserted removeAllObjects]; [_updated removeAllObjects]; [_deleted removeAllObjects];
    [_pInserted removeAllObjects]; [_pUpdated removeAllObjects]; [_pDeleted removeAllObjects];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification object:self userInfo:@{ NSInvalidatedAllObjectsKey: @[] }];
}
- (void)refreshObject:(NSManagedObject *)o mergeChanges:(BOOL)flag {
    if (!o || o.managedObjectContext != self || [_inserted containsObject:o]) return;
    if (!flag) {
        [_updated removeObject:o]; [_pUpdated removeObject:o];
        if ([_deleted containsObject:o]) { [_deleted removeObject:o]; [_pDeleted removeObject:o]; }
        [o _cd_turnIntoFault];
        return;
    }
    CDSnapshot *s = [self _cd_snapshotForObjectID:o.objectID];
    if (s) [o _cd_mergeSnapshot:s keepChanges:YES];
}
- (void)refreshAllObjects {
    for (NSManagedObject *o in _registered.allValues) {
        if ([_inserted containsObject:o]) continue;
        [self refreshObject:o mergeChanges:o.hasChanges];
    }
}

/* ---------------- predicates with objects from any context ---------------- */
static id norm_value(NSManagedObjectContext *ctx, id v) {
    if ([v isKindOfClass:[NSManagedObject class]]) return ((NSManagedObject *)v).managedObjectContext == ctx ? v : [ctx objectWithID:[v objectID]];
    if ([v isKindOfClass:[NSManagedObjectID class]]) return [ctx objectWithID:v];
    if ([v isKindOfClass:[NSArray class]] || [v isKindOfClass:[NSSet class]] || [v isKindOfClass:[NSOrderedSet class]]) {
        BOOL any = NO;
        for (id x in v) if ([x isKindOfClass:[NSManagedObject class]] || [x isKindOfClass:[NSManagedObjectID class]]) { any = YES; break; }
        if (!any) return v;
        NSMutableArray *a = [NSMutableArray array];
        for (id x in v) [a addObject:norm_value(ctx, x)];
        return a;
    }
    return v;
}
static NSExpression *norm_expr(NSManagedObjectContext *ctx, NSExpression *e) {
    if (e.expressionType == NSConstantValueExpressionType) {
        id v = norm_value(ctx, e.constantValue);
        return v == e.constantValue ? e : [NSExpression expressionForConstantValue:v];
    }
    if (e.expressionType == NSAggregateExpressionType) {
        NSMutableArray *items = [NSMutableArray array]; BOOL changed = NO;
        for (NSExpression *x in e.collection) { NSExpression *n = norm_expr(ctx, x); changed |= n != x; [items addObject:n]; }
        return changed ? [NSExpression expressionForAggregate:items] : e;
    }
    return e;
}
static NSPredicate *norm_pred(NSManagedObjectContext *ctx, NSPredicate *p) {
    if ([p isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *c = (NSCompoundPredicate *)p;
        NSMutableArray *subs = [NSMutableArray array]; BOOL changed = NO;
        for (NSPredicate *s in c.subpredicates) { NSPredicate *n = norm_pred(ctx, s); changed |= n != s; [subs addObject:n]; }
        return changed ? [[NSCompoundPredicate alloc] initWithType:c.compoundPredicateType subpredicates:subs] : p;
    }
    if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSComparisonPredicate *c = (NSComparisonPredicate *)p;
        if (c.predicateOperatorType == NSCustomSelectorPredicateOperatorType) return p;
        NSExpression *l = norm_expr(ctx, c.leftExpression), *r = norm_expr(ctx, c.rightExpression);
        if (l == c.leftExpression && r == c.rightExpression) return p;
        return [NSComparisonPredicate predicateWithLeftExpression:l rightExpression:r modifier:c.comparisonPredicateModifier type:c.predicateOperatorType options:c.options];
    }
    return p;
}

/* ---------------- fetching ---------------- */
- (BOOL)_cd_hasChangesForFamily:(NSArray *)family {
    for (NSSet *set in @[_inserted, _updated, _deleted])
        for (NSManagedObject *o in set) if ([family containsObject:o.entity]) return YES;
    return NO;
}
static NSArray *apply_window(NSArray *a, NSUInteger offset, NSUInteger limit) {
    if (offset >= a.count) return offset ? @[] : a;
    NSUInteger n = a.count - offset;
    if (limit && limit < n) n = limit;
    return offset || n != a.count ? [a subarrayWithRange:NSMakeRange(offset, n)] : a;
}
/* managed objects for a request; *count set instead when countOnly and the store can count */
- (NSArray *)_cd_objectsFor:(NSFetchRequest *)req entity:(NSEntityDescription *)entity countOnly:(BOOL)countOnly count:(NSUInteger *)countOut error:(NSError **)error {
    NSArray *family = req.includesSubentities ? entity._cd_family : @[entity];
    NSPredicate *pred = req.predicate ? norm_pred(self, req.predicate) : nil;
    BOOL pending = req.includesPendingChanges && [self _cd_hasChangesForFamily:family];
    NSMutableArray *objects = [NSMutableArray array];
    BOOL done = NO, filtered = NO;
    NSManagedObjectContext *p = _parent;
    if (p) {
        NSFetchRequest *pr = [req copy];
        pr.resultType = NSManagedObjectIDResultType;
        pr.predicate = pred;
        if (pending) { pr.fetchLimit = 0; pr.fetchOffset = 0; }
        __block NSArray *ids = nil; __block NSError *perr = nil;
        [p performBlockAndWait:^{ ids = [p _cd_executeFetch:pr error:&perr]; }];
        if (!ids) { if (error) *error = perr; return nil; }
        for (NSManagedObjectID *i in ids) [objects addObject:[self objectWithID:i]];
        done = !pending; filtered = YES;
    } else {
        NSPersistentStoreCoordinator *c = self.persistentStoreCoordinator;
        NSArray *stores = c._cd_stores;
        if (!stores.count) {
            if (error) *error = CDError(NSCoreDataError, @"This NSPersistentStoreCoordinator has no persistent stores. It cannot perform a save or fetch operation.", nil);
            if (!c) return nil;
        }
        [c lock];
        for (CDSQLStore *store in stores) {
            NSMutableArray *args = [NSMutableArray array];
            BOOL exact = YES;
            NSString *where = pred ? [store _cd_sqlForPredicate:pred entity:entity args:args exact:&exact] : nil;
            NSString *order = req.sortDescriptors.count ? [store _cd_sqlForSortDescriptors:req.sortDescriptors entity:entity] : nil;
            BOOL sqlAll = !pending && exact && stores.count == 1 && (order || !req.sortDescriptors.count);
            if (sqlAll && countOnly && countOut) {
                NSUInteger n = [store _cd_countForEntities:family where:where args:args];
                n = req.fetchOffset >= n ? 0 : n - req.fetchOffset;
                if (req.fetchLimit && req.fetchLimit < n) n = req.fetchLimit;
                *countOut = n;
                [c unlock];
                return nil;
            }
            NSArray *rows = [store _cd_rowsForEntities:family where:where args:args order:sqlAll ? order : nil
                                                 limit:sqlAll ? req.fetchLimit : 0 offset:sqlAll ? req.fetchOffset : 0];
            for (CDSnapshot *s in rows) [objects addObject:[self _cd_objectForSnapshot:s]];
            done = sqlAll; filtered = exact;
        }
        [c unlock];
    }
    if (done) return objects;
    if (pending) {
        for (NSManagedObject *o in _inserted) if ([family containsObject:o.entity] && ![objects containsObject:o]) [objects addObject:o];
        for (NSManagedObject *o in _updated) if ([family containsObject:o.entity] && ![objects containsObject:o]) [objects addObject:o];
        for (NSManagedObject *o in _deleted) [objects removeObject:o];
        filtered = NO;
    }
    NSArray *result = objects;
    if (pred && !filtered) {
        NSMutableArray *keep = [NSMutableArray array];
        for (NSManagedObject *o in objects) if ([pred evaluateWithObject:o]) [keep addObject:o];
        result = keep;
    }
    if (req.sortDescriptors.count) result = [result sortedArrayUsingDescriptors:req.sortDescriptors];
    return apply_window(result, req.fetchOffset, req.fetchLimit);
}
static id dict_value(NSManagedObject *o, NSString *key) {
    id v = [o valueForKeyPath:key];
    if ([v isKindOfClass:[NSManagedObject class]]) return [v objectID];
    return v;
}
static id aggregate(NSExpression *e, NSArray *objects) {
    if (e.expressionType == NSFunctionExpressionType && e.arguments.count == 1 && e.arguments[0].expressionType == NSKeyPathExpressionType) {
        NSString *f = e.function, *kp = e.arguments[0].keyPath;
        NSMutableArray *vals = [NSMutableArray array];
        for (NSManagedObject *o in objects) { id v = [o valueForKeyPath:kp]; if (v) [vals addObject:v]; }
        if ([f isEqualToString:@"count:"]) return @(vals.count);
        if ([f isEqualToString:@"sum:"]) return [vals valueForKeyPath:@"@sum.self"];
        if ([f isEqualToString:@"average:"]) return vals.count ? [vals valueForKeyPath:@"@avg.self"] : nil;
        if ([f isEqualToString:@"min:"]) return [vals valueForKeyPath:@"@min.self"];
        if ([f isEqualToString:@"max:"]) return [vals valueForKeyPath:@"@max.self"];
    }
    return objects.count ? [e expressionValueWithObject:objects[0] context:nil] : nil;
}
- (NSArray *)_cd_dictionariesFor:(NSArray *)objects request:(NSFetchRequest *)req entity:(NSEntityDescription *)entity {
    NSArray *props = req.propertiesToFetch;
    if (!props.count) { NSMutableArray *a = [NSMutableArray array]; for (NSPropertyDescription *p in entity.properties) if ([p isKindOfClass:[NSAttributeDescription class]]) [a addObject:p]; props = a; }
    BOOL hasAggregate = NO;
    for (id p in props) if ([p isKindOfClass:[NSExpressionDescription class]]) hasAggregate = YES;
    NSMutableArray *out = [NSMutableArray array];
    NSArray *groupBy = req.propertiesToGroupBy;
    if (groupBy.count || hasAggregate) {
        NSMutableArray *groupKeys = [NSMutableArray array];
        for (id g in groupBy) [groupKeys addObject:[g isKindOfClass:[NSPropertyDescription class]] ? [g name] : g];
        NSMutableArray *groups = [NSMutableArray array], *groupValues = [NSMutableArray array];
        for (NSManagedObject *o in objects) {
            NSMutableArray *gv = [NSMutableArray array];
            for (NSString *k in groupKeys) [gv addObject:dict_value(o, k) ?: [NSNull null]];
            NSUInteger i = [groupValues indexOfObject:gv];
            if (i == NSNotFound) { [groupValues addObject:gv]; [groups addObject:[NSMutableArray arrayWithObject:o]]; }
            else [groups[i] addObject:o];
        }
        if (!groupKeys.count && !groups.count) { [groups addObject:[NSMutableArray array]]; [groupValues addObject:@[]]; }
        for (NSUInteger i = 0; i < groups.count; i++) {
            NSMutableDictionary *d = [NSMutableDictionary dictionary];
            for (id p in props) {
                if ([p isKindOfClass:[NSExpressionDescription class]]) { id v = aggregate([p expression], groups[i]); if (v) d[[p name]] = v; }
                else { NSString *k = [p isKindOfClass:[NSPropertyDescription class]] ? [p name] : p; id v = [groups[i] count] ? dict_value(groups[i][0], k) : nil; if (v) d[k] = v; }
            }
            if (!req.havingPredicate || [req.havingPredicate evaluateWithObject:d]) [out addObject:d];
        }
        return out;
    }
    for (NSManagedObject *o in objects) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (id p in props) {
            NSString *k = [p isKindOfClass:[NSPropertyDescription class]] ? [p name] : p;
            id v = dict_value(o, k);
            if (v) d[k] = v;
        }
        if (req.returnsDistinctResults && [out containsObject:d]) continue;
        [out addObject:d];
    }
    return out;
}
- (NSArray *)_cd_executeFetch:(NSFetchRequest *)req error:(NSError **)error {
    NSEntityDescription *entity = [req _cd_entityInContext:self];
    if (!entity) {
        if (error) *error = CDError(NSCoreDataError, [NSString stringWithFormat:@"executeFetchRequest:error: A fetch request must have an entity (%@).", req.entityName], nil);
        return nil;
    }
    if (req.resultType == NSCountResultType) {
        NSUInteger n = [self _cd_count:req error:error];
        return n == NSNotFound ? nil : @[@(n)];
    }
    NSArray *objects = [self _cd_objectsFor:req entity:entity countOnly:NO count:NULL error:error];
    if (!objects) return nil;
    switch (req.resultType) {
    case NSManagedObjectIDResultType: { NSMutableArray *ids = [NSMutableArray array]; for (NSManagedObject *o in objects) [ids addObject:o.objectID]; return ids; }
    case NSDictionaryResultType: return [self _cd_dictionariesFor:objects request:req entity:entity];
    default:
        if (req.shouldRefreshRefetchedObjects) for (NSManagedObject *o in objects) if (!o.hasChanges) [self refreshObject:o mergeChanges:NO];
        return objects;
    }
}
- (NSUInteger)_cd_count:(NSFetchRequest *)req error:(NSError **)error {
    NSEntityDescription *entity = [req _cd_entityInContext:self];
    if (!entity) { if (error) *error = CDError(NSCoreDataError, @"countForFetchRequest:error: A fetch request must have an entity.", nil); return NSNotFound; }
    NSUInteger n = NSNotFound;
    NSArray *objects = [self _cd_objectsFor:req entity:entity countOnly:YES count:&n error:error];
    if (n != NSNotFound) return n;
    return objects ? objects.count : NSNotFound;
}
- (NSArray *)executeFetchRequest:(NSFetchRequest *)request error:(NSError **)error { return [self _cd_executeFetch:request error:error]; }
- (NSUInteger)countForFetchRequest:(NSFetchRequest *)request error:(NSError **)error { return [self _cd_count:request error:error]; }
- (NSPersistentStoreResult *)executeRequest:(NSPersistentStoreRequest *)request error:(NSError **)error {
    if ([request isKindOfClass:[NSBatchDeleteRequest class]] || [request isKindOfClass:[NSBatchUpdateRequest class]])
        return [self.persistentStoreCoordinator executeRequest:request withContext:self error:error];
    if (error) *error = CDError(NSPersistentStoreUnsupportedRequestTypeError, @"executeRequest: supports NSBatchDeleteRequest and NSBatchUpdateRequest on isim (use executeFetchRequest:error: for fetches)", nil);
    return nil;
}

/* ---------------- permanent IDs ---------------- */
- (void)_cd_replaceID:(NSManagedObject *)o with:(NSManagedObjectID *)nid {
    NSManagedObjectID *old = o.objectID;
    [_registered removeObjectForKey:old];
    [o _cd_setObjectID:nid];
    _registered[nid] = o;
    _tempToPermanent[old] = nid;
}
- (NSPersistentStoreCoordinator *)_cd_rootCoordinator {
    NSManagedObjectContext *c = self;
    while (c->_parent) c = c->_parent;
    return c.persistentStoreCoordinator;
}
- (BOOL)_cd_assignPermanentIDs:(NSArray<NSManagedObject *> *)objects error:(NSError **)error {
    NSMutableArray *temp = [NSMutableArray array], *entities = [NSMutableArray array];
    for (NSManagedObject *o in objects) if (o.objectID.temporaryID) { [temp addObject:o]; [entities addObject:o.entity]; }
    if (!temp.count) return YES;
    NSPersistentStoreCoordinator *c = [self _cd_rootCoordinator];
    CDSQLStore *store = [c _cd_storeForEntity:entities[0]];
    if (!store) { if (error) *error = CDError(NSCoreDataError, @"This NSPersistentStoreCoordinator has no persistent stores. It cannot perform a save operation.", nil); return NO; }
    [c lock];
    NSArray *ids = [store _cd_permanentIDsForEntities:entities error:error];
    [c unlock];
    if (!ids) return NO;
    for (NSUInteger i = 0; i < temp.count; i++) [self _cd_replaceID:temp[i] with:ids[i]];
    return YES;
}
- (BOOL)obtainPermanentIDsForObjects:(NSArray<NSManagedObject *> *)objects error:(NSError **)error { return [self _cd_assignPermanentIDs:objects error:error]; }

/* ---------------- saving ---------------- */
static NSSet *ids_of(NSArray *objects) { NSMutableSet *s = [NSMutableSet set]; for (NSManagedObject *o in objects) [s addObject:o.objectID]; return s; }
- (BOOL)_cd_saveToStore:(NSArray *)ins updated:(NSArray *)upd deleted:(NSArray *)del error:(NSError **)error {
    NSPersistentStoreCoordinator *c = self.persistentStoreCoordinator;
    CDSQLStore *store = c._cd_stores.firstObject;
    if (!store) { if (error) *error = CDError(NSCoreDataError, @"This NSPersistentStoreCoordinator has no persistent stores. It cannot perform a save operation.", nil); return NO; }
    if (store.readOnly) { if (error) *error = CDError(NSPersistentStoreSaveError, @"The persistent store is read-only.", nil); return NO; }
    if (![self _cd_assignPermanentIDs:ins error:error]) return NO;
    NSMergePolicy *mp = [self.mergePolicy isKindOfClass:[NSMergePolicy class]] ? self.mergePolicy : NSErrorMergePolicy;
    [c lock];
    BOOL ok = [store _cd_saveInserted:ins updated:upd deleted:del mergePolicy:mp error:error];
    [c unlock];
    return ok;
}
- (BOOL)_cd_pushToParent:(NSArray *)ins updated:(NSArray *)upd deleted:(NSArray *)del error:(NSError **)error {
    NSMutableArray *insSnaps = [NSMutableArray array], *updSnaps = [NSMutableArray array], *delIDs = [NSMutableArray array];
    for (NSManagedObject *o in ins) [insSnaps addObject:[o _cd_snapshotForChild]];
    for (NSManagedObject *o in upd) {
        CDSnapshot *full = [o _cd_snapshotForChild], *s = [[CDSnapshot alloc] init];
        s.objectID = o.objectID;
        for (NSString *k in o._cd_changedKeys) s.values[k] = full.values[k] ?: [NSNull null];
        [updSnaps addObject:s];
    }
    for (NSManagedObject *o in del) [delIDs addObject:o.objectID];
    NSManagedObjectContext *p = _parent;
    [p performBlockAndWait:^{
        void (^apply)(NSManagedObject *, CDSnapshot *) = ^(NSManagedObject *po, CDSnapshot *s) {
            NSDictionary *rels = po.entity.relationshipsByName;
            for (NSString *k in s.values) {
                id v = s.values[k];
                NSRelationshipDescription *r = rels[k];
                if (v == [NSNull null]) v = nil;
                else if (r.toMany) { NSMutableArray *a = [NSMutableArray array]; for (NSManagedObjectID *i in v) [a addObject:[p objectWithID:i]]; v = a; }
                else if (r) v = [p objectWithID:v];
                [po _cd_setTracked:v forKey:k];
            }
        };
        NSMutableArray *created = [NSMutableArray array];
        for (CDSnapshot *s in insSnaps) {
            NSEntityDescription *e = s.objectID.entity;
            NSManagedObject *po = [p objectRegisteredForID:s.objectID];
            if (!po) {
                po = [[e._cd_objectClass alloc] initWithEntity:e insertIntoManagedObjectContext:nil];
                [po _cd_setObjectID:s.objectID];
                [p _cd_registerObject:po];
                [p->_inserted addObject:po]; [p->_pInserted addObject:po];
            }
            [created addObject:po];
        }
        for (NSUInteger i = 0; i < insSnaps.count; i++) apply(created[i], insSnaps[i]);
        for (CDSnapshot *s in updSnaps) { NSManagedObject *po = [p objectWithID:s.objectID]; [po _cd_fire]; apply(po, s); }
        for (NSManagedObjectID *i in delIDs) { NSManagedObject *po = [p objectRegisteredForID:i] ?: [p objectWithID:i]; [p deleteObject:po]; }
        [p _cd_schedule];
    }];
    NSDictionary *idChanges = @{ NSInsertedObjectIDsKey: ids_of(ins), NSUpdatedObjectIDsKey: ids_of(upd), NSDeletedObjectIDsKey: ids_of(del) };
    [p _cd_notifyChildren:idChanges except:self];
    return YES;
}
- (void)_cd_notifyChildren:(NSDictionary *)idChanges except:(NSManagedObjectContext *)except {
    NSArray *kids;
    @synchronized (_children) { kids = _children.allObjects; }
    for (NSManagedObjectContext *k in kids) {
        if (k == except || !k.automaticallyMergesChangesFromParent) continue;
        [k performBlock:^{ [k _cd_mergeIDChanges:idChanges]; }];
    }
}
- (BOOL)save:(NSError **)error {
    [self processPendingChanges];
    if (!self.hasChanges) return YES;
    NSMutableArray *errs = [NSMutableArray array];
    void (^addErr)(NSError *) = ^(NSError *e) {
        if (!e) return;
        if (e.code == NSValidationMultipleErrorsError) [errs addObjectsFromArray:e.userInfo[NSDetailedErrorsKey]]; else [errs addObject:e];
    };
    for (NSManagedObject *o in _inserted.allObjects) { NSError *e = nil; if (![o validateForInsert:&e]) addErr(e); }
    for (NSManagedObject *o in _updated.allObjects) { NSError *e = nil; if (o.hasPersistentChangedValues && ![o validateForUpdate:&e]) addErr(e); }
    for (NSManagedObject *o in _deleted.allObjects) { NSError *e = nil; if (![o validateForDelete:&e]) addErr(e); }
    if (errs.count) {
        if (error) *error = errs.count == 1 ? errs[0] : CDError(NSValidationMultipleErrorsError, @"Multiple validation errors occurred.", @{ NSDetailedErrorsKey: errs });
        return NO;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextWillSaveNotification object:self userInfo:nil];
    NSMutableArray *all = [NSMutableArray arrayWithArray:_inserted.allObjects];
    [all addObjectsFromArray:_updated.allObjects]; [all addObjectsFromArray:_deleted.allObjects];
    for (NSManagedObject *o in all) [o willSave];
    [self processPendingChanges];
    NSArray *ins = _inserted.allObjects, *del = _deleted.allObjects, *allUpd = _updated.allObjects;
    NSMutableArray *upd = [NSMutableArray array];
    for (NSManagedObject *o in allUpd) if (o._cd_changedKeys.count) [upd addObject:o];
    BOOL ok = _parent ? [self _cd_pushToParent:ins updated:upd deleted:del error:error] : [self _cd_saveToStore:ins updated:upd deleted:del error:error];
    if (!ok) return NO;
    for (NSManagedObject *o in ins) [o _cd_commit];
    for (NSManagedObject *o in allUpd) [o _cd_commit];
    for (NSManagedObject *o in del) { [_registered removeObjectForKey:o.objectID]; }
    [_inserted removeAllObjects]; [_updated removeAllObjects]; [_deleted removeAllObjects];
    [_pInserted removeAllObjects]; [_pUpdated removeAllObjects]; [_pDeleted removeAllObjects];
    for (NSManagedObject *o in del) [o _cd_setContext:nil];
    NSArray *saved = [[ins arrayByAddingObjectsFromArray:upd] arrayByAddingObjectsFromArray:del];
    for (NSManagedObject *o in saved) [o didSave];
    NSDictionary *idChanges = @{ NSInsertedObjectIDsKey: ids_of(ins), NSUpdatedObjectIDsKey: ids_of(upd), NSDeletedObjectIDsKey: ids_of(del) };
    NSDictionary *info = @{ NSInsertedObjectsKey: [NSSet setWithArray:ins], NSUpdatedObjectsKey: [NSSet setWithArray:upd], NSDeletedObjectsKey: [NSSet setWithArray:del] };
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveNotification object:self userInfo:info];
    [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextDidSaveObjectIDsNotification object:self userInfo:idChanges];
    if (!_parent) [self.persistentStoreCoordinator _cd_rootContext:self didSave:idChanges];
    [self _cd_notifyChildren:idChanges except:nil];
    return YES;
}

/* ---------------- merging ---------------- */
- (void)_cd_mergeIDChanges:(NSDictionary *)changes {
    NSMutableSet *ins = [NSMutableSet set], *ref = [NSMutableSet set], *del = [NSMutableSet set];
    for (NSManagedObjectID *i in changes[NSDeletedObjectIDsKey]) {
        NSManagedObject *o = [self objectRegisteredForID:i];
        if (!o) continue;
        [self _cd_unregister:o];
        [del addObject:o];
    }
    for (NSManagedObjectID *i in changes[NSUpdatedObjectIDsKey]) {
        NSManagedObject *o = [self objectRegisteredForID:i];
        if (!o) continue;
        if (![o _cd_isFault]) { CDSnapshot *s = [self _cd_snapshotForObjectID:o.objectID]; if (s) [o _cd_mergeSnapshot:s keepChanges:YES]; }
        [ref addObject:o];
    }
    for (NSManagedObjectID *i in changes[NSInsertedObjectIDsKey]) {
        NSManagedObject *o = [self objectRegisteredForID:i];
        if (o && ![o _cd_isFault]) { CDSnapshot *s = [self _cd_snapshotForObjectID:o.objectID]; if (s) [o _cd_mergeSnapshot:s keepChanges:YES]; [ref addObject:o]; continue; }
        [ins addObject:[self objectWithID:i]];
    }
    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    if (ins.count) info[NSInsertedObjectsKey] = ins;
    if (ref.count) info[NSRefreshedObjectsKey] = ref;
    if (del.count) info[NSDeletedObjectsKey] = del;
    if (info.count) [[NSNotificationCenter defaultCenter] postNotificationName:NSManagedObjectContextObjectsDidChangeNotification object:self userInfo:info];
    [self _cd_notifyChildren:changes except:nil];
}
static NSSet *ids_from(id collection, NSPersistentStoreCoordinator *c) {
    NSMutableSet *s = [NSMutableSet set];
    for (id x in collection) {
        if ([x isKindOfClass:[NSManagedObject class]]) [s addObject:[x objectID]];
        else if ([x isKindOfClass:[NSManagedObjectID class]]) [s addObject:x];
        else if ([x isKindOfClass:[NSURL class]]) { NSManagedObjectID *i = [c managedObjectIDForURIRepresentation:x]; if (i) [s addObject:i]; }
        else if ([x isKindOfClass:[NSString class]]) { NSManagedObjectID *i = [c managedObjectIDForURIRepresentation:[NSURL URLWithString:x]]; if (i) [s addObject:i]; }
    }
    return s;
}
- (void)mergeChangesFromContextDidSaveNotification:(NSNotification *)note {
    NSDictionary *u = note.userInfo;
    NSPersistentStoreCoordinator *c = self.persistentStoreCoordinator;
    [self _cd_mergeIDChanges:@{ NSInsertedObjectIDsKey: ids_from(u[NSInsertedObjectsKey] ?: u[NSInsertedObjectIDsKey], c),
                                NSUpdatedObjectIDsKey: ids_from(u[NSUpdatedObjectsKey] ?: u[NSUpdatedObjectIDsKey], c),
                                NSDeletedObjectIDsKey: ids_from(u[NSDeletedObjectsKey] ?: u[NSDeletedObjectIDsKey], c) }];
}
+ (void)mergeChangesFromRemoteContextSave:(NSDictionary *)data intoContexts:(NSArray<NSManagedObjectContext *> *)contexts {
    for (NSManagedObjectContext *ctx in contexts) {
        NSPersistentStoreCoordinator *c = ctx.persistentStoreCoordinator;
        NSDictionary *changes = @{ NSInsertedObjectIDsKey: ids_from(data[NSInsertedObjectsKey] ?: data[NSInsertedObjectIDsKey], c),
                                   NSUpdatedObjectIDsKey: ids_from(data[NSUpdatedObjectsKey] ?: data[NSUpdatedObjectIDsKey], c),
                                   NSDeletedObjectIDsKey: ids_from(data[NSDeletedObjectsKey] ?: data[NSDeletedObjectIDsKey], c) };
        [ctx performBlockAndWait:^{ [ctx _cd_mergeIDChanges:changes]; }];
    }
}
@end
