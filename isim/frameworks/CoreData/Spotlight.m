/* isim Core Data (ARC): NSCoreDataCoreSpotlightDelegate over isim's CoreSpotlight, which is loaded and called at run time
 * (Apple's selectors; CoreSpotlight's classes come from its Swift overlay). */
#import "CoreDataPrivate.h"
#include <dlfcn.h>

NSNotificationName const NSCoreDataCoreSpotlightDelegateIndexDidUpdateNotification = @"NSCoreDataCoreSpotlightDelegateIndexDidUpdate";

/* the CoreSpotlight selectors used here */
@protocol CDSpotlightAttributeSet <NSObject>
- (instancetype)initWithItemContentType:(NSString *)type;
@property (copy) NSString *title;
@property (copy) NSString *displayName;
@property (copy) NSString *contentDescription;
@property (copy) NSArray<NSString *> *keywords;
@end
@protocol CDSpotlightItem <NSObject>
- (instancetype)initWithUniqueIdentifier:(NSString *)uid domainIdentifier:(NSString *)domain attributeSet:(id)set;
@end
@protocol CDSpotlightIndex <NSObject>
+ (instancetype)defaultSearchableIndex;
- (instancetype)initWithName:(NSString *)name;
- (void)indexSearchableItems:(NSArray *)items completionHandler:(void (^)(NSError *))handler;
- (void)deleteSearchableItemsWithIdentifiers:(NSArray<NSString *> *)ids completionHandler:(void (^)(NSError *))handler;
- (void)deleteSearchableItemsWithDomainIdentifiers:(NSArray<NSString *> *)domains completionHandler:(void (^)(NSError *))handler;
@end

static Class spotlight_class(NSString *name) {
    Class c = NSClassFromString(name);
    if (!c) { dlopen("/System/Library/Frameworks/CoreSpotlight.framework/CoreSpotlight", RTLD_NOW | RTLD_GLOBAL); c = NSClassFromString(name); }
    return c;
}
static BOOL indexed_entity(NSEntityDescription *e) {
    for (NSPropertyDescription *p in e.properties) if (p.indexedBySpotlight && !p.transient) return YES;
    return NO;
}

@implementation NSCoreDataCoreSpotlightDelegate {
    NSPersistentStoreDescription *_description;
    __weak NSPersistentStoreCoordinator *_psc;
    id _observer;
    BOOL _enabled;
}
- (instancetype)initForStoreWithDescription:(NSPersistentStoreDescription *)description coordinator:(NSPersistentStoreCoordinator *)psc {
    if ((self = [super init])) { _description = [description copy]; _psc = psc; }
    return self;
}
- (BOOL)isIndexingEnabled { return _enabled; }
- (NSPersistentStore *)_cd_store {
    NSPersistentStoreCoordinator *c = _psc;
    return (_description.URL ? [c persistentStoreForURL:_description.URL] : nil) ?: c.persistentStores.firstObject;
}
- (NSString *)domainIdentifier { return self._cd_store.identifier ?: [NSBundle mainBundle].bundleIdentifier ?: @"CoreData"; }
- (NSString *)indexName { return nil; }
- (id<CDSpotlightIndex>)_cd_index {
    Class cls = spotlight_class(@"CSSearchableIndex");
    if (!cls) return nil;
    NSString *name = self.indexName;
    return name ? [(id<CDSpotlightIndex>)[cls alloc] initWithName:name] : [(Class<CDSpotlightIndex>)cls defaultSearchableIndex];
}

- (void)startSpotlightIndexing {
    if (_enabled) return;
    _enabled = YES;
    __weak NSCoreDataCoreSpotlightDelegate *weakSelf = self;
    _observer = [[NSNotificationCenter defaultCenter] addObserverForName:NSManagedObjectContextDidSaveObjectIDsNotification object:nil queue:nil usingBlock:^(NSNotification *note) {
        NSManagedObjectContext *ctx = note.object;
        NSCoreDataCoreSpotlightDelegate *me = weakSelf;
        if (!me || ctx.parentContext || ctx.persistentStoreCoordinator != me->_psc) return;
        NSMutableArray *changed = [NSMutableArray array];
        for (NSManagedObjectID *i in note.userInfo[NSInsertedObjectIDsKey]) [changed addObject:i];
        for (NSManagedObjectID *i in note.userInfo[NSUpdatedObjectIDsKey]) [changed addObject:i];
        NSMutableArray *gone = [NSMutableArray array];
        for (NSManagedObjectID *i in note.userInfo[NSDeletedObjectIDsKey]) if (indexed_entity(i.entity)) [gone addObject:i.URIRepresentation.absoluteString];
        [me _cd_indexObjectIDs:changed deletedIdentifiers:gone completion:nil];
    }];
    [self _cd_reindexAll:nil];
}
- (void)stopSpotlightIndexing {
    _enabled = NO;
    if (_observer) [[NSNotificationCenter defaultCenter] removeObserver:_observer];
    _observer = nil;
}
- (void)dealloc { if (_observer) [[NSNotificationCenter defaultCenter] removeObserver:_observer]; }
- (void)deleteSpotlightIndexWithCompletionHandler:(void (^)(NSError *))completionHandler {
    id<CDSpotlightIndex> index = self._cd_index;
    if (!index) { if (completionHandler) completionHandler(CDError(NSCoreDataError, @"CoreSpotlight is not available.", nil)); return; }
    [index deleteSearchableItemsWithDomainIdentifiers:@[self.domainIdentifier] completionHandler:^(NSError *e) { if (completionHandler) completionHandler(e); }];
}

/* values of the attributes indexed by Spotlight */
- (id)_cd_defaultAttributeSetForObject:(NSManagedObject *)object {
    NSMutableArray *texts = [NSMutableArray array];
    for (NSPropertyDescription *p in object.entity.properties) {
        if (!p.indexedBySpotlight || p.transient || ![p isKindOfClass:[NSAttributeDescription class]]) continue;
        id v = [object valueForKey:p.name];
        if (!v || v == [NSNull null]) continue;
        [texts addObject:[v isKindOfClass:[NSString class]] ? v : [v description]];
    }
    NSString *title = nil;
    NSString *display = object.entity.coreSpotlightDisplayNameExpression;
    if (display.length) {
        id v = [[NSExpression expressionWithFormat:display argumentArray:@[]] expressionValueWithObject:object context:nil];
        if (v && v != [NSNull null]) title = [v description];
    }
    if (!texts.count && !title) return nil;
    Class cls = spotlight_class(@"CSSearchableItemAttributeSet");
    if (!cls) return nil;
    id<CDSpotlightAttributeSet> set = [(id<CDSpotlightAttributeSet>)[cls alloc] initWithItemContentType:@"public.item"];
    set.title = title ?: texts.firstObject;
    set.displayName = set.title;
    NSArray *rest = title ? texts : [texts subarrayWithRange:NSMakeRange(1, texts.count - 1)];
    if (rest.count) { set.contentDescription = [rest componentsJoinedByString:@", "]; set.keywords = rest; }
    return set;
}
- (id)attributeSetForObject:(NSManagedObject *)object { return [self _cd_defaultAttributeSetForObject:object]; }
- (void)searchableIndex:(id)searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void))acknowledgementHandler { [self _cd_reindexAll:acknowledgementHandler]; }
- (void)searchableIndex:(id)searchableIndex reindexSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers acknowledgementHandler:(void (^)(void))acknowledgementHandler {
    [self _cd_reindexIdentifiers:identifiers acknowledgementHandler:acknowledgementHandler];
}
- (void)_cd_reindexAll:(void (^)(void))acknowledgementHandler {
    NSPersistentStoreCoordinator *c = _psc;
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    ctx.persistentStoreCoordinator = c;
    [ctx performBlock:^{
        NSMutableArray *ids = [NSMutableArray array];
        for (NSEntityDescription *e in c.managedObjectModel.entities) {
            if (!indexed_entity(e) || e.abstract) continue;
            NSFetchRequest *r = [NSFetchRequest fetchRequestWithEntityName:e.name];
            r.includesSubentities = NO; r.resultType = NSManagedObjectIDResultType;
            [ids addObjectsFromArray:[ctx executeFetchRequest:r error:NULL] ?: @[]];
        }
        [self _cd_indexObjectIDs:ids deletedIdentifiers:@[] completion:acknowledgementHandler];
    }];
}
- (void)_cd_reindexIdentifiers:(NSArray<NSString *> *)identifiers acknowledgementHandler:(void (^)(void))acknowledgementHandler {
    NSMutableArray *ids = [NSMutableArray array];
    for (NSString *s in identifiers) { NSManagedObjectID *i = [_psc managedObjectIDForURIRepresentation:[NSURL URLWithString:s]]; if (i) [ids addObject:i]; }
    [self _cd_indexObjectIDs:ids deletedIdentifiers:@[] completion:acknowledgementHandler];
}
/* builds the items in a private context, then indexes them and posts the did-update notification */
- (void)_cd_indexObjectIDs:(NSArray<NSManagedObjectID *> *)ids deletedIdentifiers:(NSArray<NSString *> *)gone completion:(void (^)(void))completion {
    id<CDSpotlightIndex> index = self._cd_index;
    Class itemClass = spotlight_class(@"CSSearchableItem");
    if (!index || !itemClass) { if (completion) completion(); return; }
    NSManagedObjectContext *ctx = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    ctx.persistentStoreCoordinator = _psc;
    NSString *domain = self.domainIdentifier, *storeID = self._cd_store.identifier ?: @"";
    [ctx performBlock:^{
        NSMutableArray *items = [NSMutableArray array], *removed = [gone mutableCopy];
        for (NSManagedObjectID *i in ids) {
            if (!indexed_entity(i.entity)) continue;
            NSManagedObject *o = [ctx existingObjectWithID:i error:NULL];
            id set = o ? [self attributeSetForObject:o] : nil;
            NSString *uid = i.URIRepresentation.absoluteString;
            if (set) [items addObject:[(id<CDSpotlightItem>)[itemClass alloc] initWithUniqueIdentifier:uid domainIdentifier:domain attributeSet:set]];
            else [removed addObject:uid];                         /* nothing to index (any more) */
        }
        dispatch_group_t g = dispatch_group_create();
        if (items.count) { dispatch_group_enter(g); [index indexSearchableItems:items completionHandler:^(NSError *e) { dispatch_group_leave(g); }]; }
        if (removed.count) { dispatch_group_enter(g); [index deleteSearchableItemsWithIdentifiers:removed completionHandler:^(NSError *e) { dispatch_group_leave(g); }]; }
        dispatch_group_notify(g, dispatch_get_global_queue(0, 0), ^{
            if (items.count || removed.count)
                [[NSNotificationCenter defaultCenter] postNotificationName:NSCoreDataCoreSpotlightDelegateIndexDidUpdateNotification object:self userInfo:@{ NSStoreUUIDKey: storeID }];
            if (completion) completion();
        });
    }];
}
@end
