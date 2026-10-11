/* isim Core Data (ARC): NSPersistentStoreRequest, NSFetchRequest and batch insert/delete/update requests
 * and their results. */
#import "CoreDataPrivate.h"

@implementation NSPersistentStoreRequest
- (NSPersistentStoreRequestType)requestType { return NSFetchRequestType; }
- (id)copyWithZone:(NSZone *)zone { NSPersistentStoreRequest *r = [[[self class] alloc] init]; r.affectedStores = self.affectedStores; return r; }
@end

@implementation NSFetchRequest {
    NSString *_entityName;
}
+ (instancetype)fetchRequestWithEntityName:(NSString *)name { return [[self alloc] initWithEntityName:name]; }
- (instancetype)init {
    if ((self = [super init])) { _includesSubentities = YES; _includesPropertyValues = YES; _returnsObjectsAsFaults = YES; _includesPendingChanges = YES; }
    return self;
}
- (instancetype)initWithEntityName:(NSString *)name { if ((self = [self init])) _entityName = [name copy]; return self; }
- (NSPersistentStoreRequestType)requestType { return NSFetchRequestType; }
- (NSString *)entityName { return _entity.name ?: _entityName; }
- (void)setEntity:(NSEntityDescription *)e { _entity = e; if (e.name) _entityName = e.name; }
- (NSEntityDescription *)_cd_entityInContext:(NSManagedObjectContext *)ctx {
    NSEntityDescription *named = [ctx _cd_entityNamed:self.entityName];
    return named ?: _entity;
}
- (NSArray *)execute:(NSError **)error {
    NSManagedObjectContext *ctx = [NSManagedObjectContext _cd_current];
    if (!ctx) {
        CD_LOG(@"-[NSFetchRequest execute:] must run inside a managed object context's perform block");
        if (error) *error = CDError(NSCoreDataError, @"-execute: was called outside of a context's perform block", nil);
        return nil;
    }
    return [ctx executeFetchRequest:self error:error];
}
- (id)copyWithZone:(NSZone *)zone {
    NSFetchRequest *r = [[NSFetchRequest alloc] initWithEntityName:_entityName];
    r->_entity = _entity;
    r.predicate = self.predicate; r.sortDescriptors = self.sortDescriptors; r.fetchLimit = self.fetchLimit; r.fetchOffset = self.fetchOffset;
    r.fetchBatchSize = self.fetchBatchSize; r.resultType = self.resultType; r.includesSubentities = self.includesSubentities;
    r.includesPropertyValues = self.includesPropertyValues; r.returnsObjectsAsFaults = self.returnsObjectsAsFaults;
    r.relationshipKeyPathsForPrefetching = self.relationshipKeyPathsForPrefetching; r.includesPendingChanges = self.includesPendingChanges;
    r.returnsDistinctResults = self.returnsDistinctResults; r.propertiesToFetch = self.propertiesToFetch; r.propertiesToGroupBy = self.propertiesToGroupBy;
    r.havingPredicate = self.havingPredicate; r.shouldRefreshRefetchedObjects = self.shouldRefreshRefetchedObjects; r.affectedStores = self.affectedStores;
    return r;
}
- (void)encodeWithCoder:(NSCoder *)c { [c encodeObject:_entityName forKey:@"entityName"]; }
- (instancetype)initWithCoder:(NSCoder *)c { return [self initWithEntityName:[c decodeObjectForKey:@"entityName"]]; }
- (NSString *)description {
    return [NSString stringWithFormat:@"<NSFetchRequest: %p> (entity: %@; predicate: (%@); sortDescriptors: (%@); type: %lu; limit %lu)", self, self.entityName,
            self.predicate.predicateFormat ?: @"null", [[self.sortDescriptors valueForKey:@"key"] componentsJoinedByString:@", "], (unsigned long)self.resultType, (unsigned long)self.fetchLimit];
}
@end

@implementation NSPersistentStoreResult
@end
@implementation NSBatchDeleteResult { id _result; NSBatchDeleteRequestResultType _type; }
- (instancetype)_cd_initWithResult:(id)result type:(NSBatchDeleteRequestResultType)type { if ((self = [super init])) { _result = result; _type = type; } return self; }
- (id)result { return _result; }
- (NSBatchDeleteRequestResultType)resultType { return _type; }
@end
@implementation NSBatchUpdateResult { id _result; NSBatchUpdateRequestResultType _type; }
- (instancetype)_cd_initWithResult:(id)result type:(NSBatchUpdateRequestResultType)type { if ((self = [super init])) { _result = result; _type = type; } return self; }
- (id)result { return _result; }
- (NSBatchUpdateRequestResultType)resultType { return _type; }
@end
@implementation NSBatchInsertResult { id _result; NSBatchInsertRequestResultType _type; }
- (instancetype)_cd_initWithResult:(id)result type:(NSBatchInsertRequestResultType)type { if ((self = [super init])) { _result = result; _type = type; } return self; }
- (id)result { return _result; }
- (NSBatchInsertRequestResultType)resultType { return _type; }
@end

@implementation NSBatchInsertRequest {
    NSString *_name; NSEntityDescription *_entity; NSArray *_objects;
    BOOL (^_dictionaryHandler)(NSMutableDictionary *); BOOL (^_managedObjectHandler)(NSManagedObject *);
}
- (instancetype)initWithEntityName:(NSString *)name objects:(NSArray *)objects { if ((self = [super init])) { _name = [name copy]; _objects = [objects copy]; } return self; }
- (instancetype)initWithEntity:(NSEntityDescription *)entity objects:(NSArray *)objects { if ((self = [self initWithEntityName:entity.name objects:objects])) _entity = entity; return self; }
- (instancetype)initWithEntityName:(NSString *)name dictionaryHandler:(BOOL (^)(NSMutableDictionary *))handler { if ((self = [self initWithEntityName:name objects:nil])) _dictionaryHandler = [handler copy]; return self; }
- (instancetype)initWithEntity:(NSEntityDescription *)entity dictionaryHandler:(BOOL (^)(NSMutableDictionary *))handler { if ((self = [self initWithEntityName:entity.name dictionaryHandler:handler])) _entity = entity; return self; }
- (instancetype)initWithEntityName:(NSString *)name managedObjectHandler:(BOOL (^)(NSManagedObject *))handler { if ((self = [self initWithEntityName:name objects:nil])) _managedObjectHandler = [handler copy]; return self; }
- (instancetype)initWithEntity:(NSEntityDescription *)entity managedObjectHandler:(BOOL (^)(NSManagedObject *))handler { if ((self = [self initWithEntityName:entity.name managedObjectHandler:handler])) _entity = entity; return self; }
- (NSPersistentStoreRequestType)requestType { return NSBatchInsertRequestType; }
- (NSString *)entityName { return _name; }
- (NSEntityDescription *)entity { return _entity; }
- (NSArray *)objectsToInsert { return _objects; }
- (BOOL (^)(NSMutableDictionary<NSString *, id> *))dictionaryHandler { return _dictionaryHandler; }
- (BOOL (^)(NSManagedObject *))managedObjectHandler { return _managedObjectHandler; }
- (NSEntityDescription *)_cd_entityInContext:(NSManagedObjectContext *)context { return _entity ?: [context _cd_entityNamed:_name]; }
@end

@implementation NSBatchDeleteRequest { NSFetchRequest *_fetch; NSArray *_ids; }
- (instancetype)initWithFetchRequest:(NSFetchRequest *)fetch { if ((self = [super init])) _fetch = [fetch copy]; return self; }
- (instancetype)initWithObjectIDs:(NSArray<NSManagedObjectID *> *)objects {
    NSManagedObjectID *first = objects.firstObject;
    if ((self = [self initWithFetchRequest:[NSFetchRequest fetchRequestWithEntityName:first.entity.name ?: @""]])) _ids = [objects copy];
    return self;
}
- (NSPersistentStoreRequestType)requestType { return NSBatchDeleteRequestType; }
- (NSFetchRequest *)fetchRequest { return _fetch; }
- (NSArray *)_cd_objectIDs { return _ids; }
@end

@implementation NSBatchUpdateRequest { NSString *_name; NSEntityDescription *_entity; }
+ (instancetype)batchUpdateRequestWithEntityName:(NSString *)name { return [[self alloc] initWithEntityName:name]; }
- (instancetype)initWithEntityName:(NSString *)name { if ((self = [self initWithEntity:(NSEntityDescription *_Nonnull)nil])) _name = [name copy]; return self; }
- (instancetype)initWithEntity:(NSEntityDescription *)e { if ((self = [super init])) { _entity = e; _name = e.name; _includesSubentities = YES; } return self; }
- (NSPersistentStoreRequestType)requestType { return NSBatchUpdateRequestType; }
- (NSString *)entityName { return _name; }
- (NSEntityDescription *)entity { return _entity; }
@end

/* ---------------- persistent history (local store transactions) ---------------- */
@implementation NSPersistentHistoryToken { int64_t _number; }
+ (BOOL)supportsSecureCoding { return YES; }
+ (instancetype)_cd_token:(int64_t)n { NSPersistentHistoryToken *t = [self new]; t->_number = n; return t; }
- (int64_t)_cd_number { return _number; }
- (id)copyWithZone:(NSZone *)zone { return self; }
- (void)encodeWithCoder:(NSCoder *)coder { [coder encodeInt64:_number forKey:@"transactionNumber"]; }
- (instancetype)initWithCoder:(NSCoder *)coder { if ((self = [super init])) _number = [coder decodeInt64ForKey:@"transactionNumber"]; return self; }
@end

@implementation NSPersistentHistoryChange { int64_t _number; NSManagedObjectID *_objectID; NSPersistentHistoryChangeType _type; __weak NSPersistentHistoryTransaction *_transaction; }
+ (instancetype)_cd_change:(int64_t)n objectID:(NSManagedObjectID *)oid type:(NSPersistentHistoryChangeType)type { NSPersistentHistoryChange *c = [self new]; c->_number = n; c->_objectID = oid; c->_type = type; return c; }
- (int64_t)changeID { return _number; }
- (NSManagedObjectID *)changedObjectID { return _objectID; }
- (NSPersistentHistoryChangeType)changeType { return _type; }
- (NSDictionary *)tombstone { return nil; }
- (NSSet *)updatedProperties { return nil; }
- (NSPersistentHistoryTransaction *)transaction { return _transaction; }
- (void)_cd_setTransaction:(NSPersistentHistoryTransaction *)t { _transaction = t; }
@end

@implementation NSPersistentHistoryTransaction { int64_t _number; NSString *_store, *_author, *_context; NSDate *_timestamp; NSArray *_changes; NSPersistentHistoryToken *_token; }
+ (instancetype)_cd_transaction:(int64_t)n storeID:(NSString *)store author:(NSString *)author context:(NSString *)context changes:(NSArray *)changes {
    NSPersistentHistoryTransaction *t = [self new]; t->_number = n; t->_store = [store copy]; t->_author = [author copy]; t->_context = [context copy];
    t->_timestamp = [NSDate date]; t->_token = [NSPersistentHistoryToken _cd_token:n]; t->_changes = [changes copy];
    for (NSPersistentHistoryChange *c in changes) [c _cd_setTransaction:t]; return t;
}
- (int64_t)transactionNumber { return _number; }
- (NSPersistentHistoryToken *)token { return _token; }
- (NSDate *)timestamp { return _timestamp; }
- (NSString *)author { return _author; }
- (NSString *)contextName { return _context; }
- (NSString *)storeID { return _store; }
- (NSArray *)changes { return _changes; }
- (NSNotification *)objectIDNotification {
    NSMutableSet *ins = [NSMutableSet set], *upd = [NSMutableSet set], *del = [NSMutableSet set];
    for (NSPersistentHistoryChange *c in _changes) [(c.changeType == NSPersistentHistoryChangeTypeInsert ? ins : c.changeType == NSPersistentHistoryChangeTypeUpdate ? upd : del) addObject:c.changedObjectID];
    return [NSNotification notificationWithName:NSManagedObjectContextDidSaveObjectIDsNotification object:nil userInfo:@{ NSInsertedObjectIDsKey: ins, NSUpdatedObjectIDsKey: upd, NSDeletedObjectIDsKey: del }];
}
@end

@implementation NSPersistentHistoryChangeRequest { BOOL _delete; int64_t _number; NSDate *_date; }
+ (instancetype)_request:(BOOL)del date:(NSDate *)date number:(int64_t)n { NSPersistentHistoryChangeRequest *r = [self new]; r->_delete = del; r->_date = date; r->_number = n; r.resultType = del ? NSPersistentHistoryResultTypeStatusOnly : NSPersistentHistoryResultTypeTransactionsAndChanges; return r; }
+ (instancetype)fetchHistoryAfterDate:(NSDate *)date { return [self _request:NO date:date number:0]; }
+ (instancetype)fetchHistoryAfterToken:(NSPersistentHistoryToken *)token { return [self _request:NO date:nil number:token._cd_number]; }
+ (instancetype)fetchHistoryAfterTransaction:(NSPersistentHistoryTransaction *)transaction { return [self _request:NO date:nil number:transaction.transactionNumber]; }
+ (instancetype)deleteHistoryBeforeDate:(NSDate *)date { return [self _request:YES date:date number:0]; }
+ (instancetype)deleteHistoryBeforeToken:(NSPersistentHistoryToken *)token { return [self _request:YES date:nil number:token._cd_number]; }
+ (instancetype)deleteHistoryBeforeTransaction:(NSPersistentHistoryTransaction *)transaction { return [self _request:YES date:nil number:transaction.transactionNumber]; }
- (NSPersistentStoreRequestType)requestType { return NSFetchRequestType; }
- (BOOL)_cd_delete { return _delete; }
- (int64_t)_cd_number { return _number; }
- (NSDate *)_cd_date { return _date; }
@end
@implementation NSPersistentHistoryResult { id _result; NSPersistentHistoryResultType _type; }
- (instancetype)_cd_initWithResult:(id)result type:(NSPersistentHistoryResultType)type { if ((self = [super init])) { _result = result; _type = type; } return self; }
- (id)result { return _result; }
- (NSPersistentHistoryResultType)resultType { return _type; }
@end
