/* isim Core Data (ARC): NSPersistentStore, NSPersistentStoreDescription, NSPersistentStoreCoordinator and
 * NSPersistentContainer. */
#import "CoreDataPrivate.h"

/* ================= NSPersistentStore ================= */
@implementation NSPersistentStore {
    __weak NSPersistentStoreCoordinator *_psc;
    NSString *_config;
    NSDictionary *_options, *_metadata;
}
+ (NSDictionary *)metadataForPersistentStoreWithURL:(NSURL *)url error:(NSError **)error {
    return [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:NSSQLiteStoreType URL:url options:nil error:error];
}
- (instancetype)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)root configurationName:(NSString *)name URL:(NSURL *)url options:(NSDictionary *)options {
    if ((self = [super init])) { _psc = root; _config = [name copy] ?: @"PF_DEFAULT_CONFIGURATION_NAME"; _URL = url; _options = [options copy]; _identifier = [NSUUID UUID].UUIDString; _metadata = @{}; }
    return self;
}
- (BOOL)loadMetadata:(NSError **)error { return YES; }
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator { return _psc; }
- (NSString *)configurationName { return _config; }
- (NSDictionary *)options { return _options; }
- (NSString *)type { return NSSQLiteStoreType; }
- (NSDictionary *)metadata { return _metadata; }
- (void)setMetadata:(NSDictionary *)m { _metadata = [m copy] ?: @{}; }
- (void)didAddToPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)c {}
- (void)willRemoveFromPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)c {}
- (NSString *)description { return [NSString stringWithFormat:@"<%@: %p> (URL: %@)", [self class], self, self.URL]; }
@end

/* ================= NSPersistentStoreDescription ================= */
@implementation NSPersistentStoreDescription {
    NSMutableDictionary *_options, *_pragmas;
}
+ (instancetype)persistentStoreDescriptionWithURL:(NSURL *)url { return [[self alloc] initWithURL:url]; }
- (instancetype)init {
    if ((self = [super init])) {
        _type = NSSQLiteStoreType; _options = [NSMutableDictionary dictionary]; _pragmas = [NSMutableDictionary dictionary];
        _shouldMigrateStoreAutomatically = YES; _shouldInferMappingModelAutomatically = YES; _timeout = 240;
    }
    return self;
}
- (instancetype)initWithURL:(NSURL *)url { if ((self = [self init])) _URL = [url copy]; return self; }
- (NSDictionary *)options { return [_options copy]; }
- (void)setOption:(NSObject *)o forKey:(NSString *)k { if (o) _options[k] = o; else [_options removeObjectForKey:k]; }
- (NSDictionary *)sqlitePragmas { return [_pragmas copy]; }
- (void)setValue:(NSObject *)v forPragmaNamed:(NSString *)n { if (v) _pragmas[n] = v; else [_pragmas removeObjectForKey:n]; }
- (id)copyWithZone:(NSZone *)zone {
    NSPersistentStoreDescription *d = [[NSPersistentStoreDescription alloc] initWithURL:_URL];
    d.type = _type; d.configuration = _configuration; d.readOnly = _readOnly; d.timeout = _timeout;
    d.shouldAddStoreAsynchronously = _shouldAddStoreAsynchronously; d.shouldMigrateStoreAutomatically = _shouldMigrateStoreAutomatically;
    d.shouldInferMappingModelAutomatically = _shouldInferMappingModelAutomatically;
    for (NSString *k in _options) [d setOption:_options[k] forKey:k];
    for (NSString *k in _pragmas) [d setValue:_pragmas[k] forPragmaNamed:k];
    return d;
}
- (NSDictionary *)_cd_storeOptions {
    NSMutableDictionary *o = [_options mutableCopy];
    o[NSMigratePersistentStoresAutomaticallyOption] = @(_shouldMigrateStoreAutomatically);
    o[NSInferMappingModelAutomaticallyOption] = @(_shouldInferMappingModelAutomatically);
    if (_readOnly) o[NSReadOnlyPersistentStoreOption] = @YES;
    if (_pragmas.count) o[NSSQLitePragmasOption] = [_pragmas copy];
    return o;
}
- (NSString *)description { return [NSString stringWithFormat:@"<NSPersistentStoreDescription: %p> (type: %@, url: %@)", self, _type, _URL]; }
@end

/* ================= NSPersistentStoreCoordinator ================= */
@implementation NSPersistentStoreCoordinator {
    NSMutableArray<CDSQLStore *> *_stores;
    NSRecursiveLock *_lock;
    NSHashTable *_contexts;
}
- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)model {
    if ((self = [super init])) {
        _managedObjectModel = model; _stores = [NSMutableArray array]; _lock = [[NSRecursiveLock alloc] init];
        _contexts = [NSHashTable weakObjectsHashTable];
        CDRegisterModel(model);
    }
    return self;
}
- (NSArray *)persistentStores { return [_stores copy]; }
- (NSArray<CDSQLStore *> *)_cd_stores { return [_stores copy]; }
- (CDSQLStore *)_cd_storeForEntity:(NSEntityDescription *)e {
    for (CDSQLStore *s in _stores) {
        NSArray *ents = [_managedObjectModel entitiesForConfiguration:s.configurationName];
        if (!ents || [ents containsObject:e] || [ents containsObject:e._cd_root]) return s;
    }
    return _stores.firstObject;
}
- (void)_cd_registerContext:(NSManagedObjectContext *)c { @synchronized (_contexts) { [_contexts addObject:c]; } }
/* root contexts with automaticallyMergesChangesFromParent merge saves of other contexts on this coordinator */
- (void)_cd_rootContext:(NSManagedObjectContext *)ctx didSave:(NSDictionary *)changes {
    NSArray *all;
    @synchronized (_contexts) { all = _contexts.allObjects; }
    for (NSManagedObjectContext *c in all) {
        if (c == ctx || c.parentContext || !c.automaticallyMergesChangesFromParent) continue;
        [c performBlock:^{ [c _cd_mergeIDChanges:changes]; }];
    }
}
- (void)lock { [_lock lock]; }
- (void)unlock { [_lock unlock]; }
- (BOOL)tryLock { return [_lock tryLock]; }
- (void)performBlock:(void (^)(void))block { void (^b)(void) = [block copy]; dispatch_async(dispatch_get_global_queue(0, 0), ^{ [self lock]; b(); [self unlock]; }); }
- (void)performBlockAndWait:(void (NS_NOESCAPE ^)(void))block { [self lock]; block(); [self unlock]; }
- (NSPersistentStore *)persistentStoreForURL:(NSURL *)url {
    for (NSPersistentStore *s in _stores) if ([s.URL.path isEqualToString:url.path]) return s;
    return nil;
}
- (NSURL *)URLForPersistentStore:(NSPersistentStore *)store { return store.URL; }
- (BOOL)setURL:(NSURL *)url forPersistentStore:(NSPersistentStore *)store { store.URL = url; return YES; }
- (NSPersistentStore *)addPersistentStoreWithType:(NSString *)type configuration:(NSString *)configuration URL:(NSURL *)url options:(NSDictionary *)options error:(NSError **)error {
    if (![type isEqualToString:NSSQLiteStoreType] && ![type isEqualToString:NSInMemoryStoreType]) {
        if (error) *error = CDError(NSPersistentStoreInvalidTypeError, [NSString stringWithFormat:@"Unsupported store type %@ (isim: SQLite and InMemory)", type], nil);
        return nil;
    }
    if (url && [type isEqualToString:NSSQLiteStoreType] && ![url.path isEqualToString:@"/dev/null"] && [self persistentStoreForURL:url]) {
        if (error) *error = CDError(NSPersistentStoreOperationError, @"The store is already added to this coordinator.", nil);
        return nil;
    }
    CDSQLStore *s = [[CDSQLStore alloc] initWithPersistentStoreCoordinator:self configurationName:configuration URL:url ?: [NSURL fileURLWithPath:@"/dev/null"] options:options];
    [s _cd_setType:type];
    [self lock];
    BOOL ok = [s _cd_openWithModel:_managedObjectModel options:options error:error];
    if (ok) { [_stores addObject:s]; [s didAddToPersistentStoreCoordinator:self]; }
    [self unlock];
    return ok ? s : nil;
}
- (void)addPersistentStoreWithDescription:(NSPersistentStoreDescription *)d completionHandler:(void (^)(NSPersistentStoreDescription *, NSError *))block {
    void (^work)(void) = ^{
        NSError *err = nil;
        [self addPersistentStoreWithType:d.type configuration:d.configuration URL:d.URL options:[d _cd_storeOptions] error:&err];
        if (block) block(d, err);
    };
    if (d.shouldAddStoreAsynchronously) dispatch_async(dispatch_get_global_queue(0, 0), work); else work();
}
- (BOOL)removePersistentStore:(NSPersistentStore *)store error:(NSError **)error {
    if (![_stores containsObject:(CDSQLStore *)store]) { if (error) *error = CDError(NSPersistentStoreOperationError, @"The store is not in this coordinator.", nil); return NO; }
    [store willRemoveFromPersistentStoreCoordinator:self];
    [(CDSQLStore *)store _cd_close];
    [_stores removeObject:(CDSQLStore *)store];
    return YES;
}
- (void)setMetadata:(NSDictionary *)metadata forPersistentStore:(NSPersistentStore *)store { store.metadata = metadata; }
- (NSDictionary *)metadataForPersistentStore:(NSPersistentStore *)store { return store.metadata; }
- (NSManagedObjectID *)managedObjectIDForURIRepresentation:(NSURL *)url {
    if (![url.scheme isEqualToString:@"x-coredata"]) return nil;
    NSArray *parts = [url.path componentsSeparatedByString:@"/"];        /* "", Entity, p123 */
    if (parts.count < 3) return nil;
    NSString *ent = parts[parts.count - 2], *last = parts.lastObject;
    NSEntityDescription *e = _managedObjectModel.entitiesByName[ent];
    if (!e || ![last hasPrefix:@"p"]) return nil;
    NSString *storeID = url.host;
    for (CDSQLStore *s in _stores) if (!storeID.length || [s.identifier isEqualToString:storeID])
        return [NSManagedObjectID _cd_idWithEntity:e store:s pk:[last substringFromIndex:1].longLongValue];
    return nil;
}
- (id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error {
    if ([request isKindOfClass:[NSFetchRequest class]]) return [context executeFetchRequest:(NSFetchRequest *)request error:error];
    CDSQLStore *s = _stores.firstObject;
    if (!s) { if (error) *error = CDError(NSCoreDataError, @"This NSPersistentStoreCoordinator has no persistent stores.", nil); return nil; }
    [self lock];
    id r = [s _cd_executeBatch:request context:context error:error];
    [self unlock];
    return r;
}
+ (NSDictionary *)metadataForPersistentStoreOfType:(NSString *)type URL:(NSURL *)url options:(NSDictionary *)options error:(NSError **)error {
    sqlite3 *db = NULL;
    if (sqlite3_open_v2(url.path.UTF8String, &db, SQLITE_OPEN_READONLY, NULL) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        if (error) *error = CDError(260, [NSString stringWithFormat:@"No store at %@", url.path], nil);
        return nil;
    }
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(db, "SELECT Z_KEY, Z_VALUE FROM Z_METADATA", -1, &st, NULL) == SQLITE_OK) {
        while (sqlite3_step(st) == SQLITE_ROW) {
            const char *k = (const char *)sqlite3_column_text(st, 0);
            if (!k) continue;
            if (sqlite3_column_type(st, 1) == SQLITE_BLOB) {
                NSData *d = [NSData dataWithBytes:sqlite3_column_blob(st, 1) length:(NSUInteger)sqlite3_column_bytes(st, 1)];
                id v = [NSPropertyListSerialization propertyListWithData:d options:0 format:NULL error:NULL];
                if (v) m[@(k)] = v;
            } else if (sqlite3_column_text(st, 1)) m[@(k)] = @((const char *)sqlite3_column_text(st, 1));
        }
    }
    sqlite3_finalize(st);
    sqlite3_close(db);
    if (!m.count) { if (error) *error = CDError(NSPersistentStoreInvalidTypeError, @"Not an isim Core Data store", nil); return nil; }
    return m;
}
- (BOOL)destroyPersistentStoreAtURL:(NSURL *)url withType:(NSString *)type options:(NSDictionary *)options error:(NSError **)error {
    NSPersistentStore *s = [self persistentStoreForURL:url];
    if (s) [self removePersistentStore:s error:NULL];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *suffix in @[@"", @"-wal", @"-shm", @"-journal"]) [fm removeItemAtPath:[url.path stringByAppendingString:suffix] error:NULL];
    return YES;
}
- (BOOL)replacePersistentStoreAtURL:(NSURL *)dst destinationOptions:(NSDictionary *)dopts withPersistentStoreFromURL:(NSURL *)src sourceOptions:(NSDictionary *)sopts storeType:(NSString *)type error:(NSError **)error {
    [self destroyPersistentStoreAtURL:dst withType:type options:dopts error:NULL];
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *suffix in @[@"", @"-wal", @"-shm"]) {
        NSString *from = [src.path stringByAppendingString:suffix];
        if (![fm fileExistsAtPath:from]) continue;
        NSData *d = [NSData dataWithContentsOfFile:from];
        if (!d || ![d writeToFile:[dst.path stringByAppendingString:suffix] atomically:YES]) {
            if (error) *error = CDError(NSPersistentStoreOperationError, [NSString stringWithFormat:@"Could not copy %@", from], nil);
            return NO;
        }
    }
    return YES;
}
@end

/* ================= NSPersistentContainer ================= */
@implementation NSPersistentContainer {
    NSManagedObjectContext *_viewContext;
}
+ (instancetype)persistentContainerWithName:(NSString *)name { return [[self alloc] initWithName:name]; }
+ (instancetype)persistentContainerWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model { return [[self alloc] initWithName:name managedObjectModel:model]; }
+ (NSURL *)defaultDirectoryURL {
    NSURL *u = [[NSFileManager defaultManager] URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
    [[NSFileManager defaultManager] createDirectoryAtPath:u.path withIntermediateDirectories:YES attributes:nil error:NULL];
    return u;
}
static NSManagedObjectModel *model_named(NSString *name) {
    for (NSBundle *b in @[[NSBundle mainBundle]]) {
        NSString *p = [b pathForResource:name ofType:@"momd"] ?: [b pathForResource:name ofType:@"mom"];
        if (p) { NSManagedObjectModel *m = [[NSManagedObjectModel alloc] initWithContentsOfURL:[NSURL fileURLWithPath:p]]; if (m) return m; }
    }
    return nil;
}
- (instancetype)initWithName:(NSString *)name {
    NSManagedObjectModel *m = model_named(name);
    if (!m) {
        CD_LOG(@"Failed to load model named %@ (isim: compile the .xcdatamodeld with isim build)", name);
        m = [NSManagedObjectModel mergedModelFromBundles:nil] ?: [[NSManagedObjectModel alloc] init];
    }
    return [self initWithName:name managedObjectModel:m];
}
- (instancetype)initWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model {
    if (!(self = [super init])) return nil;
    _name = [name copy];
    _managedObjectModel = model;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSURL *url = [[[self class] defaultDirectoryURL] URLByAppendingPathComponent:[name stringByAppendingPathExtension:@"sqlite"]];
    _persistentStoreDescriptions = @[[NSPersistentStoreDescription persistentStoreDescriptionWithURL:url]];
    return self;
}
- (NSManagedObjectContext *)viewContext {
    @synchronized (self) {
        if (!_viewContext) {
            _viewContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
            _viewContext.persistentStoreCoordinator = _persistentStoreCoordinator;
        }
        return _viewContext;
    }
}
- (void)loadPersistentStoresWithCompletionHandler:(void (^)(NSPersistentStoreDescription *, NSError *))block {
    for (NSPersistentStoreDescription *d in _persistentStoreDescriptions) [_persistentStoreCoordinator addPersistentStoreWithDescription:d completionHandler:block];
}
- (NSManagedObjectContext *)newBackgroundContext {
    NSManagedObjectContext *c = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    c.persistentStoreCoordinator = _persistentStoreCoordinator;
    return c;
}
- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *))block {
    NSManagedObjectContext *c = [self newBackgroundContext];
    [c performBlock:^{ block(c); }];
}
@end
