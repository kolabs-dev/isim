/* isim Core Data (ARC): migration — mapping models (entity and property mappings, inferred from names and renaming
 * identifiers), NSMigrationManager's three-phase pipeline through each mapping's NSEntityMigrationPolicy (destination
 * instances, then relationships, then custom validation) between two stores, and staged migration
 * (NSStagedMigrationManager: custom stages run their handlers on a container of the stage's model before and after the
 * store moves to the next model; lightweight stages are isim's automatic schema migration). */
#import "CoreDataPrivate.h"

NSString * const NSMigrationManagerKey = @"manager";
NSString * const NSMigrationSourceObjectKey = @"source";
NSString * const NSMigrationDestinationObjectKey = @"destination";
NSString * const NSMigrationEntityMappingKey = @"entityMapping";
NSString * const NSMigrationPropertyMappingKey = @"propertyMapping";
NSString * const NSMigrationEntityPolicyKey = @"entityPolicy";
NSString * const NSPersistentStoreStagedMigrationManagerOptionKey = @"NSPersistentStoreStagedMigrationManagerOptionKey";

@implementation NSPropertyMapping
- (NSString *)description { return [NSString stringWithFormat:@"<NSPropertyMapping %@ = %@>", _name, _valueExpression]; }
@end

@implementation NSEntityMapping { NSString *_name; }
- (NSString *)name { return _name ?: [NSString stringWithFormat:@"%@To%@", _sourceEntityName ?: @"", _destinationEntityName ?: @""]; }
- (void)setName:(NSString *)name { _name = [name copy]; }
- (NSString *)description { return [NSString stringWithFormat:@"<NSEntityMapping %@ %@ -> %@ type %lu>", self.name, _sourceEntityName, _destinationEntityName, (unsigned long)_mappingType]; }
@end

/* an attribute or relationship's value from the source instance: `$source.<name>` */
static NSPropertyMapping *source_mapping(NSString *destination, NSString *source) {
    NSPropertyMapping *m = [NSPropertyMapping new];
    m.name = destination;
    m.valueExpression = [NSExpression expressionWithFormat:[NSString stringWithFormat:@"$source.%@", source]];
    return m;
}

@implementation NSMappingModel { NSArray<NSEntityMapping *> *_entityMappings; }
+ (NSMappingModel *)mappingModelFromBundles:(NSArray *)bundles forSourceModel:(NSManagedObjectModel *)source destinationModel:(NSManagedObjectModel *)destination {
    /* isim does not read compiled mapping models (.cdm); a mapping is inferred from the two models */
    if (!source || !destination) return nil;
    return [self inferredMappingModelForSourceModel:source destinationModel:destination error:NULL];
}
+ (NSMappingModel *)inferredMappingModelForSourceModel:(NSManagedObjectModel *)source destinationModel:(NSManagedObjectModel *)destination error:(NSError **)error {
    NSMappingModel *m = [self new]; NSMutableArray *maps = [NSMutableArray array];
    NSMutableSet *mappedSources = [NSMutableSet set];
    for (NSEntityDescription *d in destination.entities) {
        NSEntityDescription *s = source.entitiesByName[d.renamingIdentifier ?: d.name] ?: source.entitiesByName[d.name];
        NSEntityMapping *e = [NSEntityMapping new];
        e.destinationEntityName = d.name; e.destinationEntityVersionHash = d.versionHash;
        if (!s) { e.mappingType = NSAddEntityMappingType; e.name = [NSString stringWithFormat:@"Add%@", d.name]; [maps addObject:e]; continue; }
        [mappedSources addObject:s.name];
        e.sourceEntityName = s.name; e.sourceEntityVersionHash = s.versionHash;
        e.mappingType = [s.versionHash isEqual:d.versionHash] ? NSCopyEntityMappingType : NSTransformEntityMappingType;
        e.name = [NSString stringWithFormat:@"%@To%@", s.name, d.name];
        NSMutableArray *attrs = [NSMutableArray array], *rels = [NSMutableArray array];
        for (NSString *n in d.attributesByName) {
            NSAttributeDescription *a = d.attributesByName[n];
            if (a.transient) continue;
            NSString *from = s.attributesByName[a.renamingIdentifier ?: n] ? (a.renamingIdentifier ?: n) : (s.attributesByName[n] ? n : nil);
            NSPropertyMapping *pm = from ? source_mapping(n, from) : [NSPropertyMapping new];
            pm.name = n;
            [attrs addObject:pm];
        }
        for (NSString *n in d.relationshipsByName) {
            NSRelationshipDescription *r = d.relationshipsByName[n];
            NSString *from = s.relationshipsByName[r.renamingIdentifier ?: n] ? (r.renamingIdentifier ?: n) : (s.relationshipsByName[n] ? n : nil);
            if (!from) continue;
            NSPropertyMapping *pm = [NSPropertyMapping new];
            pm.name = n;
            pm.userInfo = @{ @"sourceRelationship": from };
            [rels addObject:pm];
        }
        e.attributeMappings = attrs; e.relationshipMappings = rels;
        [maps addObject:e];
    }
    for (NSEntityDescription *s in source.entities) if (![mappedSources containsObject:s.name]) {
        NSEntityMapping *e = [NSEntityMapping new];
        e.mappingType = NSRemoveEntityMappingType; e.sourceEntityName = s.name; e.sourceEntityVersionHash = s.versionHash;
        e.name = [NSString stringWithFormat:@"Remove%@", s.name];
        [maps addObject:e];
    }
    m.entityMappings = maps;
    return m;
}
- (instancetype)initWithContentsOfURL:(NSURL *)url {
    CD_LOG(@"NSMappingModel: isim does not read compiled mapping models (%@); infer one or build it in code", url.lastPathComponent);
    return nil;
}
- (NSArray *)entityMappings { return _entityMappings ?: @[]; }
- (void)setEntityMappings:(NSArray *)maps { _entityMappings = [maps copy]; }
- (NSDictionary *)entityMappingsByName {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    for (NSEntityMapping *e in self.entityMappings) d[e.name] = e;
    return d;
}
@end

/* ================= the migration manager ================= */
@interface NSMigrationManager ()
@property (readwrite, strong) NSMappingModel *mappingModel;
@property (readwrite, strong) NSManagedObjectContext *sourceContext;
@property (readwrite, strong) NSManagedObjectContext *destinationContext;
@property (readwrite, strong) NSEntityMapping *currentEntityMapping;
@property (readwrite) float migrationProgress;
@end

@implementation NSMigrationManager {
    BOOL _cancelled; NSError *_cancelError;
    /* entity mapping name -> source objectID -> destination instances (and back) */
    NSMutableDictionary<NSString *, NSMapTable *> *_forward, *_backward;
}
- (instancetype)initWithSourceModel:(NSManagedObjectModel *)source destinationModel:(NSManagedObjectModel *)destination {
    if ((self = [super init])) { _sourceModel = source; _destinationModel = destination; [self reset]; } return self;
}
- (void)reset {
    _forward = [NSMutableDictionary dictionary]; _backward = [NSMutableDictionary dictionary];
    _cancelled = NO; _cancelError = nil; _migrationProgress = 0; _currentEntityMapping = nil;
}
- (void)cancelMigrationWithError:(NSError *)error { _cancelled = YES; _cancelError = error; }
- (NSEntityDescription *)sourceEntityForEntityMapping:(NSEntityMapping *)m { return m.sourceEntityName ? _sourceModel.entitiesByName[m.sourceEntityName] : nil; }
- (NSEntityDescription *)destinationEntityForEntityMapping:(NSEntityMapping *)m { return m.destinationEntityName ? _destinationModel.entitiesByName[m.destinationEntityName] : nil; }

- (void)associateSourceInstance:(NSManagedObject *)s withDestinationInstance:(NSManagedObject *)d forEntityMapping:(NSEntityMapping *)m {
    NSString *k = m.name;
    if (!_forward[k]) { _forward[k] = [NSMapTable strongToStrongObjectsMapTable]; _backward[k] = [NSMapTable strongToStrongObjectsMapTable]; }
    NSMutableArray *ds = [_forward[k] objectForKey:s.objectID]; if (!ds) { ds = [NSMutableArray array]; [_forward[k] setObject:ds forKey:s.objectID]; }
    [ds addObject:d];
    NSMutableArray *ss = [_backward[k] objectForKey:d]; if (!ss) { ss = [NSMutableArray array]; [_backward[k] setObject:ss forKey:d]; }
    [ss addObject:s];
}
- (NSArray *)destinationInstancesForEntityMappingNamed:(NSString *)name sourceInstances:(NSArray *)sources {
    NSMapTable *t = _forward[name];
    if (!t) return @[];
    NSMutableArray *out = [NSMutableArray array];
    if (sources) { for (NSManagedObject *s in sources) [out addObjectsFromArray:[t objectForKey:s.objectID] ?: @[]]; }
    else for (id k in t) [out addObjectsFromArray:[t objectForKey:k]];
    return out;
}
- (NSArray *)sourceInstancesForEntityMappingNamed:(NSString *)name destinationInstances:(NSArray *)destinations {
    NSMapTable *t = _backward[name];
    if (!t) return @[];
    NSMutableArray *out = [NSMutableArray array];
    if (destinations) { for (NSManagedObject *d in destinations) [out addObjectsFromArray:[t objectForKey:d] ?: @[]]; }
    else for (id k in t) [out addObjectsFromArray:[t objectForKey:k]];
    return out;
}
/* the destination instance a source object migrated to (any mapping) */
- (NSManagedObject *)_destinationFor:(NSManagedObject *)source {
    for (NSString *k in _forward) { NSArray *d = [_forward[k] objectForKey:source.objectID]; if (d.count) return d[0]; }
    return nil;
}
- (NSFetchRequest *)fetchRequestForSourceEntityNamed:(NSString *)name predicateString:(NSString *)p {
    NSFetchRequest *r = [NSFetchRequest fetchRequestWithEntityName:name];
    r.predicate = [NSPredicate predicateWithFormat:p];
    r.includesSubentities = NO;
    return r;
}

- (NSEntityMigrationPolicy *)_policyFor:(NSEntityMapping *)m {
    Class c = m.entityMigrationPolicyClassName.length ? NSClassFromString(m.entityMigrationPolicyClassName) : Nil;
    if (m.entityMigrationPolicyClassName.length && !c) CD_LOG(@"migration: no class %@ for %@; using NSEntityMigrationPolicy", m.entityMigrationPolicyClassName, m.name);
    return [[(c ?: [NSEntityMigrationPolicy class]) alloc] init];
}
- (BOOL)_cancelledError:(NSError **)error {
    if (!_cancelled) return NO;
    if (error) *error = _cancelError ?: CDError(NSMigrationCancelledError, @"Migration was cancelled.", nil);
    return YES;
}

- (BOOL)migrateStoreFromURL:(NSURL *)sourceURL type:(NSString *)sourceType options:(NSDictionary *)sourceOptions withMappingModel:(NSMappingModel *)mapping
           toDestinationURL:(NSURL *)destinationURL destinationType:(NSString *)destinationType destinationOptions:(NSDictionary *)destinationOptions error:(NSError **)error {
    NSError *cancel = _cancelled ? (_cancelError ?: CDError(NSMigrationCancelledError, @"Migration was cancelled.", nil)) : nil;
    [self reset];
    if (cancel) { if (error) *error = cancel; return NO; }
    self.mappingModel = mapping ?: [NSMappingModel inferredMappingModelForSourceModel:_sourceModel destinationModel:_destinationModel error:error];
    if (!self.mappingModel) return NO;
    /* the source store, read-only, with the source model */
    NSPersistentStoreCoordinator *sourcePSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_sourceModel];
    NSMutableDictionary *so = [NSMutableDictionary dictionaryWithDictionary:sourceOptions ?: @{}];
    so[NSReadOnlyPersistentStoreOption] = @YES;
    if (![sourcePSC addPersistentStoreWithType:sourceType configuration:nil URL:sourceURL options:so error:error]) return NO;
    /* a new destination store; migrating in place goes through a temporary file */
    BOOL inPlace = [sourceURL.standardizedURL isEqual:destinationURL.standardizedURL];
    NSURL *target = inPlace ? [destinationURL URLByAppendingPathExtension:@"isim-migrating"] : destinationURL;
    for (NSString *suffix in @[ @"", @"-wal", @"-shm" ]) [[NSFileManager defaultManager] removeItemAtPath:[target.path stringByAppendingString:suffix] error:NULL];
    NSPersistentStoreCoordinator *destPSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:_destinationModel];
    if (![destPSC addPersistentStoreWithType:destinationType configuration:nil URL:target options:destinationOptions error:error]) return NO;
    self.sourceContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    self.sourceContext.persistentStoreCoordinator = sourcePSC;
    self.destinationContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    self.destinationContext.persistentStoreCoordinator = destPSC;

    NSArray<NSEntityMapping *> *maps = self.mappingModel.entityMappings;
    NSMutableArray<NSEntityMigrationPolicy *> *policies = [NSMutableArray array];
    for (NSEntityMapping *m in maps) [policies addObject:[self _policyFor:m]];
    NSUInteger steps = MAX(1, maps.count * 3), done = 0;
    BOOL ok = YES;
    /* phase 1: destination instances */
    for (NSUInteger i = 0; ok && i < maps.count; i++) {
        NSEntityMapping *m = maps[i]; NSEntityMigrationPolicy *p = policies[i];
        self.currentEntityMapping = m;
        ok = [p beginEntityMapping:m manager:self error:error];
        if (ok && m.mappingType != NSRemoveEntityMappingType && m.mappingType != NSAddEntityMappingType && m.sourceEntityName) {
            NSArray *sources = [self.sourceContext executeFetchRequest:[self fetchRequestForSourceEntityNamed:m.sourceEntityName predicateString:@"TRUEPREDICATE"] error:error];
            if (!sources) ok = NO;
            for (NSManagedObject *s in sources) {
                if (!ok || [self _cancelledError:error]) { ok = NO; break; }
                ok = [p createDestinationInstancesForSourceInstance:s entityMapping:m manager:self error:error];
            }
        }
        ok = ok && [p endInstanceCreationForEntityMapping:m manager:self error:error];
        self.migrationProgress = (float)++done / steps;
    }
    /* phase 2: relationships */
    for (NSUInteger i = 0; ok && i < maps.count; i++) {
        NSEntityMapping *m = maps[i]; NSEntityMigrationPolicy *p = policies[i];
        self.currentEntityMapping = m;
        for (NSManagedObject *d in [self destinationInstancesForEntityMappingNamed:m.name sourceInstances:nil]) {
            if (!ok || [self _cancelledError:error]) { ok = NO; break; }
            ok = [p createRelationshipsForDestinationInstance:d entityMapping:m manager:self error:error];
        }
        ok = ok && [p endRelationshipCreationForEntityMapping:m manager:self error:error];
        self.migrationProgress = (float)++done / steps;
    }
    /* phase 3: validation, the save, the end of each mapping */
    for (NSUInteger i = 0; ok && i < maps.count; i++) {
        self.currentEntityMapping = maps[i];
        ok = [policies[i] performCustomValidationForEntityMapping:maps[i] manager:self error:error];
    }
    ok = ok && ![self _cancelledError:error] && [self.destinationContext save:error];
    for (NSUInteger i = 0; ok && i < maps.count; i++) {
        self.currentEntityMapping = maps[i];
        ok = [policies[i] endEntityMapping:maps[i] manager:self error:error];
        self.migrationProgress = (float)++done / steps;
    }
    for (NSPersistentStore *s in destPSC.persistentStores.copy) [destPSC removePersistentStore:s error:NULL];
    for (NSPersistentStore *s in sourcePSC.persistentStores.copy) [sourcePSC removePersistentStore:s error:NULL];
    if (!ok) {
        for (NSString *suffix in @[ @"", @"-wal", @"-shm" ]) [[NSFileManager defaultManager] removeItemAtPath:[target.path stringByAppendingString:suffix] error:NULL];
        return NO;
    }
    if (inPlace) {
        for (NSString *suffix in @[ @"", @"-wal", @"-shm" ]) {
            NSString *from = [target.path stringByAppendingString:suffix], *to = [destinationURL.path stringByAppendingString:suffix];
            [[NSFileManager defaultManager] removeItemAtPath:to error:NULL];
            if ([[NSFileManager defaultManager] fileExistsAtPath:from]) [[NSFileManager defaultManager] moveItemAtPath:from toPath:to error:NULL];
        }
    }
    self.migrationProgress = 1;
    CD_LOG(@"migration: %@ migrated with %lu entity mappings", destinationURL.lastPathComponent, (unsigned long)maps.count);
    return YES;
}
@end

/* ================= entity migration policies ================= */
@implementation NSEntityMigrationPolicy
- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error { return YES; }
- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)source entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    NSEntityDescription *de = [manager destinationEntityForEntityMapping:mapping];
    if (!de) return YES;
    NSManagedObject *d = [NSEntityDescription insertNewObjectForEntityForName:de.name inManagedObjectContext:manager.destinationContext];
    NSMutableDictionary *vars = [@{ NSMigrationManagerKey: manager, NSMigrationSourceObjectKey: source, NSMigrationDestinationObjectKey: d,
                                    NSMigrationEntityMappingKey: mapping, NSMigrationEntityPolicyKey: self } mutableCopy];
    NSArray *maps = mapping.attributeMappings;
    if (!maps) {   /* no attribute mappings: the attributes of the same name */
        NSMutableArray *m = [NSMutableArray array];
        for (NSString *n in de.attributesByName) if (source.entity.attributesByName[n] && !de.attributesByName[n].transient) [m addObject:source_mapping(n, n)];
        maps = m;
    }
    for (NSPropertyMapping *pm in maps) {
        if (!pm.name || !pm.valueExpression || !de.attributesByName[pm.name]) continue;
        vars[NSMigrationPropertyMappingKey] = pm;
        id v = nil;
        @try { v = [pm.valueExpression expressionValueWithObject:source context:vars]; }
        @catch (NSException *e) { CD_LOG(@"migration: %@.%@: %@", de.name, pm.name, e.reason); }
        [d setValue:(v == [NSNull null] ? nil : v) forKey:pm.name];
    }
    [manager associateSourceInstance:source withDestinationInstance:d forEntityMapping:mapping];
    return YES;
}
- (BOOL)endInstanceCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error { return YES; }
- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)d entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error {
    NSManagedObject *source = [manager sourceInstancesForEntityMappingNamed:mapping.name destinationInstances:@[ d ]].firstObject;
    if (!source) return YES;
    NSArray *maps = mapping.relationshipMappings;
    NSMutableArray *pairs = [NSMutableArray array];
    if (maps) { for (NSPropertyMapping *pm in maps) if (pm.name) [pairs addObject:@[ pm.name, pm.userInfo[@"sourceRelationship"] ?: pm.name ]]; }
    else for (NSString *n in d.entity.relationshipsByName) if (source.entity.relationshipsByName[n]) [pairs addObject:@[ n, n ]];
    /* relationship mappings with a value expression (destinationInstancesForEntityMappingNamed:... over $source) */
    NSMutableDictionary *vars = [@{ NSMigrationManagerKey: manager, NSMigrationSourceObjectKey: source, NSMigrationDestinationObjectKey: d,
                                    NSMigrationEntityMappingKey: mapping, NSMigrationEntityPolicyKey: self } mutableCopy];
    for (NSPropertyMapping *pm in maps) {
        NSRelationshipDescription *r = pm.name ? d.entity.relationshipsByName[pm.name] : nil;
        if (!r || !pm.valueExpression) continue;
        vars[NSMigrationPropertyMappingKey] = pm;
        id v = nil;
        @try { v = [pm.valueExpression expressionValueWithObject:source context:vars]; }
        @catch (NSException *e) { CD_LOG(@"migration: %@.%@: %@", d.entity.name, pm.name, e.reason); continue; }
        if (r.toMany) {
            NSArray *list = [v isKindOfClass:[NSArray class]] ? v : [v respondsToSelector:@selector(allObjects)] ? [v allObjects] : v ? @[ v ] : @[];
            [d setValue:r.ordered ? [NSOrderedSet orderedSetWithArray:list] : [NSSet setWithArray:list] forKey:r.name];
        } else [d setValue:[v isKindOfClass:[NSArray class]] ? [v firstObject] : (v == [NSNull null] ? nil : v) forKey:r.name];
        [pairs filterUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(NSArray *pair, NSDictionary *b) { return ![pair[0] isEqual:pm.name]; }]];
    }
    for (NSArray *pair in pairs) {
        NSRelationshipDescription *r = d.entity.relationshipsByName[pair[0]];
        if (!r || !source.entity.relationshipsByName[pair[1]]) continue;
        id value = [source valueForKey:pair[1]];
        if (r.toMany) {
            NSMutableArray *targets = [NSMutableArray array];
            for (NSManagedObject *o in ([value respondsToSelector:@selector(allObjects)] ? [value allObjects] : value ?: @[])) { NSManagedObject *t = [manager _destinationFor:o]; if (t) [targets addObject:t]; }
            if (r.ordered) [d setValue:[NSOrderedSet orderedSetWithArray:targets] forKey:r.name];
            else [d setValue:[NSSet setWithArray:targets] forKey:r.name];
        } else {
            [d setValue:value ? [manager _destinationFor:value] : nil forKey:r.name];
        }
    }
    return YES;
}
- (BOOL)endRelationshipCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error { return YES; }
- (BOOL)performCustomValidationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error { return YES; }
- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error { return YES; }
@end

/* ================= staged migration ================= */
/* the bundle's compiled models (.momd folders) at its resource root */
static NSArray<NSURL *> *ModelDirectories(NSBundle *b) {
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:b.resourcePath error:NULL])
        if ([f.pathExtension isEqualToString:@"momd"]) [out addObject:[NSURL fileURLWithPath:[b.resourcePath stringByAppendingPathComponent:f]]];
    return out;
}

@implementation NSManagedObjectModelReference { NSManagedObjectModel *_model; NSURL *_url; NSString *_name; NSBundle *_bundle; NSDictionary *_hashes; }
- (instancetype)initWithModel:(NSManagedObjectModel *)model versionChecksum:(NSString *)checksum { if ((self = [super init])) { _model = model; _versionChecksum = [checksum copy]; } return self; }
- (instancetype)initWithFileURL:(NSURL *)url versionChecksum:(NSString *)checksum { if ((self = [super init])) { _url = url; _versionChecksum = [checksum copy]; } return self; }
- (instancetype)initWithEntityVersionHashes:(NSDictionary *)hashes inBundle:(NSBundle *)bundle versionChecksum:(NSString *)checksum {
    if ((self = [super init])) { _hashes = [hashes copy]; _bundle = bundle; _versionChecksum = [checksum copy]; } return self;
}
- (instancetype)initWithName:(NSString *)name inBundle:(NSBundle *)bundle versionChecksum:(NSString *)checksum {
    if ((self = [super init])) { _name = [name copy]; _bundle = bundle; _versionChecksum = [checksum copy]; } return self;
}
- (NSManagedObjectModel *)resolvedModel {
    if (_model) return _model;
    NSBundle *b = _bundle ?: [NSBundle mainBundle];
    if (_url) _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:_url];
    else if (_name) {
        /* a model version: Name.mom inside some .momd, or Name.momd */
        NSURL *u = [b URLForResource:_name withExtension:@"momd"] ?: [b URLForResource:_name withExtension:@"mom"];
        if (!u) for (NSURL *momd in ModelDirectories(b)) {
            NSURL *m = [momd URLByAppendingPathComponent:[_name stringByAppendingPathExtension:@"mom"]];
            if ([[NSFileManager defaultManager] fileExistsAtPath:m.path]) { u = m; break; }
        }
        if (u) _model = [[NSManagedObjectModel alloc] initWithContentsOfURL:u];
    } else if (_hashes) {
        for (NSURL *momd in ModelDirectories(b)) {
            for (NSString *f in [[NSFileManager defaultManager] contentsOfDirectoryAtPath:momd.path error:NULL]) {
                if (![f.pathExtension isEqualToString:@"mom"]) continue;
                NSManagedObjectModel *m = [[NSManagedObjectModel alloc] initWithContentsOfURL:[momd URLByAppendingPathComponent:f]];
                if ([m.entityVersionHashesByName isEqual:_hashes]) { _model = m; break; }
            }
            if (_model) break;
        }
    }
    if (!_model) CD_LOG(@"staged migration: model reference %@ did not resolve", _name ?: _url.lastPathComponent ?: _versionChecksum);
    else if (_versionChecksum.length && ![_model.versionChecksum isEqualToString:_versionChecksum])
        CD_LOG(@"staged migration: model %@ has checksum %@, not %@", _name ?: @"", _model.versionChecksum, _versionChecksum);
    return _model;
}
@end

@implementation NSMigrationStage
@end
@implementation NSLightweightMigrationStage
- (instancetype)initWithVersionChecksums:(NSArray<NSString *> *)checksums { if ((self = [super init])) _versionChecksums = [checksums copy]; return self; }
@end
@implementation NSCustomMigrationStage
- (instancetype)initWithCurrentModelReference:(NSManagedObjectModelReference *)current nextModelReference:(NSManagedObjectModelReference *)next {
    if ((self = [super init])) { _currentModel = current; _nextModel = next; } return self;
}
@end

@interface NSStagedMigrationManager ()
@property (nullable, readwrite, strong) NSPersistentContainer *container;
@end
@implementation NSStagedMigrationManager
- (instancetype)initWithMigrationStages:(NSArray *)stages { if ((self = [super init])) _stages = [stages copy]; return self; }

/* a container of `model` on the store (for a stage's handler), opened with isim's lightweight migration */
- (NSPersistentContainer *)_containerFor:(NSManagedObjectModel *)model type:(NSString *)type URL:(NSURL *)url options:(NSDictionary *)options error:(NSError **)error {
    NSPersistentContainer *c = [[NSPersistentContainer alloc] initWithName:url.lastPathComponent.stringByDeletingPathExtension managedObjectModel:model];
    NSPersistentStoreDescription *d = [NSPersistentStoreDescription persistentStoreDescriptionWithURL:url];
    d.type = type;
    d.shouldAddStoreAsynchronously = NO;
    for (NSString *k in options) if (![k isEqualToString:NSPersistentStoreStagedMigrationManagerOptionKey]) [d setOption:options[k] forKey:k];
    [d setOption:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
    [d setOption:@YES forKey:NSInferMappingModelAutomaticallyOption];
    c.persistentStoreDescriptions = @[ d ];
    __block NSError *err = nil;
    [c loadPersistentStoresWithCompletionHandler:^(NSPersistentStoreDescription *desc, NSError *e) { err = e; }];
    if (err) { if (error) *error = err; return nil; }
    return c;
}
- (void)_close:(NSPersistentContainer *)c {
    for (NSPersistentStore *s in c.persistentStoreCoordinator.persistentStores.copy) [c.persistentStoreCoordinator removePersistentStore:s error:NULL];
}
/* runs the custom stages from the store's model on, before the store opens with the final model */
- (BOOL)_cd_migrateStoreAtURL:(NSURL *)url type:(NSString *)type options:(NSDictionary *)options toModel:(NSManagedObjectModel *)target error:(NSError **)error {
    if (![[NSFileManager defaultManager] fileExistsAtPath:url.path]) return YES;
    for (NSUInteger guard = 0; guard <= _stages.count; guard++) {
        NSDictionary *md = [NSPersistentStoreCoordinator metadataForPersistentStoreOfType:type URL:url options:nil error:NULL];
        if (!md || [target isConfiguration:nil compatibleWithStoreMetadata:md]) return YES;
        NSCustomMigrationStage *stage = nil;
        for (NSMigrationStage *s in _stages) {
            if (![s isKindOfClass:[NSCustomMigrationStage class]]) continue;
            NSManagedObjectModel *m = ((NSCustomMigrationStage *)s).currentModel.resolvedModel;
            if (m && [m isConfiguration:nil compatibleWithStoreMetadata:md]) { stage = (NSCustomMigrationStage *)s; break; }
        }
        if (!stage) return YES;   /* lightweight from here: isim's automatic schema migration when the store opens */
        CD_LOG(@"staged migration: %@ from %@ to %@", stage.label ?: @"custom stage", stage.currentModel.versionChecksum, stage.nextModel.versionChecksum);
        if (stage.willMigrateHandler) {
            NSPersistentContainer *c = [self _containerFor:stage.currentModel.resolvedModel type:type URL:url options:options error:error];
            if (!c) return NO;
            self.container = c;
            BOOL ok = stage.willMigrateHandler(self, stage, error);
            [self _close:c]; self.container = nil;
            if (!ok) return NO;
        }
        NSManagedObjectModel *next = stage.nextModel.resolvedModel;
        if (!next) { if (error) *error = CDError(NSMigrationMissingSourceModelError, @"A custom migration stage's next model did not resolve.", nil); return NO; }
        NSPersistentContainer *c = [self _containerFor:next type:type URL:url options:options error:error];
        if (!c) return NO;
        if (stage.didMigrateHandler) {
            self.container = c;
            BOOL ok = stage.didMigrateHandler(self, stage, error);
            self.container = nil;
            if (!ok) { [self _close:c]; return NO; }
        }
        [self _close:c];
    }
    return YES;
}
@end
