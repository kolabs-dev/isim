/* isim Core Data (ARC): NSPersistentStoreRequest, NSFetchRequest, NSBatchDeleteRequest, NSBatchUpdateRequest
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
