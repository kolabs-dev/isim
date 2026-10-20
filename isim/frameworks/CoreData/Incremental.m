/* isim Core Data (ARC): NSIncrementalStore (a store an app implements), NSIncrementalStoreNode, NSSaveChangesRequest,
 * and the bridge contexts use to read, fetch, save and get permanent IDs through such a store. */
#import "CoreDataPrivate.h"

@implementation NSIncrementalStoreNode { NSDictionary *_values; }
- (instancetype)initWithObjectID:(NSManagedObjectID *)objectID withValues:(NSDictionary<NSString *, id> *)values version:(uint64_t)version {
    if ((self = [super init])) { _objectID = objectID; _values = [values copy] ?: @{}; _version = version; }
    return self;
}
- (void)updateWithValues:(NSDictionary<NSString *, id> *)values version:(uint64_t)version { _values = [values copy] ?: @{}; _version = version; }
- (id)valueForPropertyDescription:(NSPropertyDescription *)prop { return _values[prop.name]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSIncrementalStoreNode: %p> %@ v%llu %@", self, _objectID, (unsigned long long)_version, _values]; }
@end

@implementation NSSaveChangesRequest
- (instancetype)initWithInsertedObjects:(NSSet *)insertedObjects updatedObjects:(NSSet *)updatedObjects deletedObjects:(NSSet *)deletedObjects lockedObjects:(NSSet *)lockedObjects {
    if ((self = [super init])) { _insertedObjects = insertedObjects; _updatedObjects = updatedObjects; _deletedObjects = deletedObjects; _lockedObjects = lockedObjects; }
    return self;
}
- (NSPersistentStoreRequestType)requestType { return NSSaveRequestType; }
@end

static NSError *unimplemented(NSIncrementalStore *s, SEL sel) {
    return CDError(NSPersistentStoreOperationError, [NSString stringWithFormat:@"%@ does not implement %@ (an NSIncrementalStore subclass must).", [s class], NSStringFromSelector(sel)], nil);
}

@implementation NSIncrementalStore
- (BOOL)loadMetadata:(NSError **)error { if (error) *error = unimplemented(self, _cmd); return NO; }
- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error { if (error) *error = unimplemented(self, _cmd); return nil; }
- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error { if (error) *error = unimplemented(self, _cmd); return nil; }
- (id)newValueForRelationship:(NSRelationshipDescription *)relationship forObjectWithID:(NSManagedObjectID *)objectID withContext:(NSManagedObjectContext *)context error:(NSError **)error { if (error) *error = unimplemented(self, _cmd); return nil; }
+ (id)identifierForNewStoreAtURL:(NSURL *)storeURL { return [NSUUID UUID].UUIDString; }
/* default: UUID strings as reference objects */
- (NSArray<NSManagedObjectID *> *)obtainPermanentIDsForObjects:(NSArray<NSManagedObject *> *)array error:(NSError **)error {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSManagedObject *o in array) [ids addObject:[self newObjectIDForEntity:o.entity referenceObject:[NSUUID UUID].UUIDString]];
    return ids;
}
- (void)managedObjectContextDidRegisterObjectsWithIDs:(NSArray<NSManagedObjectID *> *)objectIDs {}
- (void)managedObjectContextDidUnregisterObjectsWithIDs:(NSArray<NSManagedObjectID *> *)objectIDs {}
- (NSManagedObjectID *)newObjectIDForEntity:(NSEntityDescription *)entity referenceObject:(id)data { return [NSManagedObjectID _cd_idWithEntity:entity store:self reference:data]; }
- (id)referenceObjectForObjectID:(NSManagedObjectID *)objectID { return objectID._cd_reference; }

/* ---------------- the context's side ---------------- */
- (CDSnapshot *)_cd_snapshotForObjectID:(NSManagedObjectID *)oid context:(NSManagedObjectContext *)ctx {
    NSError *e = nil;
    NSIncrementalStoreNode *node = [self newValuesForObjectWithID:oid withContext:ctx error:&e];
    if (!node) { if (e) CD_LOG(@"%@ newValuesForObjectWithID %@: %@", [self class], oid, e.localizedDescription); return nil; }
    CDSnapshot *s = [[CDSnapshot alloc] init];
    s.objectID = oid;
    s.version = (int64_t)node.version;
    for (NSPropertyDescription *p in oid.entity.properties) {
        if (p.transient || [p isKindOfClass:[NSFetchedPropertyDescription class]] || [p isKindOfClass:[NSExpressionDescription class]]) continue;
        id v = [node valueForPropertyDescription:p];
        if ([p isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *r = (NSRelationshipDescription *)p;
            if (r.toMany) {                                       /* given: kept as IDs; otherwise asked for when used */
                if (v && v != [NSNull null]) s.values[p.name] = [self _cd_ids:v];
                continue;
            }
            if (!v) v = [self newValueForRelationship:r forObjectWithID:oid withContext:ctx error:NULL];
            if ([v isKindOfClass:[NSManagedObject class]]) v = [v objectID];
            s.values[p.name] = [v isKindOfClass:[NSManagedObjectID class]] ? v : [NSNull null];
        } else s.values[p.name] = v ?: [NSNull null];
    }
    return s;
}
- (NSArray<NSManagedObjectID *> *)_cd_ids:(id)collection {
    NSMutableArray *ids = [NSMutableArray array];
    id items = [collection isKindOfClass:[NSOrderedSet class]] ? [collection array] : collection;
    if (![items conformsToProtocol:@protocol(NSFastEnumeration)]) return ids;
    for (id x in items) {
        if ([x isKindOfClass:[NSManagedObjectID class]]) [ids addObject:x];
        else if ([x isKindOfClass:[NSManagedObject class]]) [ids addObject:[x objectID]];
    }
    return ids;
}
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDs:(NSManagedObjectID *)oid relationship:(NSRelationshipDescription *)r context:(NSManagedObjectContext *)ctx {
    NSError *e = nil;
    id v = [self newValueForRelationship:r forObjectWithID:oid withContext:ctx error:&e];
    if (!v && e) CD_LOG(@"%@ newValueForRelationship %@ of %@: %@", [self class], r.name, oid, e.localizedDescription);
    if ([v isKindOfClass:[NSManagedObjectID class]]) return @[v];
    return v && v != [NSNull null] ? [self _cd_ids:v] : @[];
}
- (NSArray *)_cd_fetch:(NSFetchRequest *)request context:(NSManagedObjectContext *)ctx error:(NSError **)error {
    id result = [self executeRequest:request withContext:ctx error:error];
    if (![result isKindOfClass:[NSArray class]]) {
        if (result && error) *error = CDError(NSPersistentStoreOperationError, [NSString stringWithFormat:@"%@ returned %@ for a fetch request (an array was expected).", [self class], [result class]], nil);
        return nil;
    }
    NSMutableArray *objects = [NSMutableArray array];
    for (id x in result) {
        if ([x isKindOfClass:[NSManagedObject class]]) [objects addObject:x];
        else if ([x isKindOfClass:[NSManagedObjectID class]]) [objects addObject:[ctx objectWithID:x]];
    }
    return objects;
}
- (BOOL)_cd_saveInserted:(NSArray *)ins updated:(NSArray *)upd deleted:(NSArray *)del context:(NSManagedObjectContext *)ctx error:(NSError **)error {
    NSSaveChangesRequest *r = [[NSSaveChangesRequest alloc] initWithInsertedObjects:ins.count ? [NSSet setWithArray:ins] : nil
                                                                     updatedObjects:upd.count ? [NSSet setWithArray:upd] : nil
                                                                     deletedObjects:del.count ? [NSSet setWithArray:del] : nil lockedObjects:nil];
    return [self executeRequest:r withContext:ctx error:error] != nil;
}
@end

/* ---------------- registered store types ---------------- */
static NSMutableDictionary<NSString *, Class> *cd_storeClasses(void) {
    static NSMutableDictionary *d;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ d = [NSMutableDictionary dictionary]; });
    return d;
}
Class CDRegisteredStoreClass(NSString *type) { @synchronized (cd_storeClasses()) { return cd_storeClasses()[type]; } }

@implementation NSPersistentStoreCoordinator (NSIncrementalStore)
+ (void)registerStoreClass:(Class)storeClass forStoreType:(NSString *)storeType {
    if (!storeType.length) return;
    if (storeClass && ![storeClass isSubclassOfClass:[NSPersistentStore class]]) { CD_LOG(@"registerStoreClass: %@ is not an NSPersistentStore subclass", storeClass); return; }
    @synchronized (cd_storeClasses()) { cd_storeClasses()[storeType] = storeClass; }
}
+ (NSDictionary<NSString *, NSValue *> *)registeredStoreTypes {
    NSMutableDictionary *out = [NSMutableDictionary dictionary];
    out[NSSQLiteStoreType] = [NSValue valueWithPointer:(__bridge const void *)[CDSQLStore class]];
    out[NSInMemoryStoreType] = [NSValue valueWithPointer:(__bridge const void *)[CDSQLStore class]];
    @synchronized (cd_storeClasses()) {
        for (NSString *t in cd_storeClasses()) out[t] = [NSValue valueWithPointer:(__bridge const void *)cd_storeClasses()[t]];
    }
    return out;
}
@end
