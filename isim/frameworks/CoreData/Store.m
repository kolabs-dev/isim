/* isim Core Data (ARC): the SQLite store (also used in memory) on the host's SQLite.
 *
 * Layout (isim's own; not Apple's Z-table layout, though it looks similar):
 *   Z_METADATA(Z_KEY, Z_VALUE)        store UUID, type, and the model schema it was written with (binary plist)
 *   Z_ENTITIES(Z_ENT, Z_NAME, Z_SUPER, Z_MAX)  entity numbers; Z_MAX on a root entity = last primary key
 *   Z<ROOT>(Z_PK, Z_ENT, Z_OPT, Z<ATTR>..., Z<TOONE>, Z_ENT_<TOONE>)  one table per inheritance tree
 *   Z_<ROOT>_<REL>(Z_SRC, Z_SRCENT, Z_DST, Z_DSTENT, Z_ORDER)  ordered, inverse-less and many-to-many relationships
 * Dates are REAL seconds since 2001-01-01, UUIDs 16-byte BLOBs, URIs TEXT, Transformable values BLOBs
 * (their value transformer's data), Decimal REAL. Lightweight migration adds tables/columns (and follows
 * renaming identifiers); removed properties are left in place. */
#import "CoreDataPrivate.h"
#include <string.h>

NSString * const NSSQLiteStoreType = @"SQLite";
NSString * const NSInMemoryStoreType = @"InMemory";
NSString * const NSBinaryStoreType = @"Binary";
NSString * const NSStoreTypeKey = @"NSStoreType";
NSString * const NSStoreUUIDKey = @"NSStoreUUID";
NSString * const NSReadOnlyPersistentStoreOption = @"NSReadOnlyPersistentStoreOption";
NSString * const NSMigratePersistentStoresAutomaticallyOption = @"NSMigratePersistentStoresAutomaticallyOption";
NSString * const NSInferMappingModelAutomaticallyOption = @"NSInferMappingModelAutomaticallyOption";
NSString * const NSSQLitePragmasOption = @"NSSQLitePragmasOption";
NSString * const NSPersistentHistoryTrackingKey = @"NSPersistentHistoryTrackingKey";
NSString * const NSPersistentStoreRemoteChangeNotificationPostOptionKey = @"NSPersistentStoreRemoteChangeNotificationOptionKey";
NSString * const NSPersistentStoreFileProtectionKey = @"NSPersistentStoreFileProtectionKey";
NSString * const NSPersistentStoreTimeoutOption = @"NSPersistentStoreTimeoutOption";
NSString * const NSStoreModelVersionHashesKey = @"NSStoreModelVersionHashes";
NSString * const NSStoreModelVersionIdentifiersKey = @"NSStoreModelVersionIdentifiers";

#define SQLITE_TRANSIENT_ ((sqlite3_destructor_type)-1)

static NSString *col_type(NSAttributeType t) {
    switch (t) {
    case NSInteger16AttributeType: case NSInteger32AttributeType: case NSInteger64AttributeType: case NSBooleanAttributeType: return @"INTEGER";
    case NSDoubleAttributeType: case NSFloatAttributeType: case NSDecimalAttributeType: case NSDateAttributeType: return @"REAL";
    case NSStringAttributeType: case NSURIAttributeType: case NSObjectIDAttributeType: return @"TEXT";
    default: return @"BLOB";
    }
}
static NSString *sql_quote(id v) {
    if ([v isKindOfClass:[NSString class]]) return [NSString stringWithFormat:@"'%@'", [v stringByReplacingOccurrencesOfString:@"'" withString:@"''"]];
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    if ([v isKindOfClass:[NSDate class]]) return [NSString stringWithFormat:@"%.17g", [v timeIntervalSinceReferenceDate]];
    return @"NULL";
}

@implementation CDSQLStore {
    sqlite3 *_db;
    NSManagedObjectModel *_model;
    NSMutableDictionary<NSString *, NSNumber *> *_entNums;
    NSMutableDictionary<NSNumber *, NSEntityDescription *> *_numEnts;
    NSString *_storeType;
    BOOL _inTxn;
}
- (NSString *)type { return _storeType ?: NSSQLiteStoreType; }
- (void)_cd_setType:(NSString *)t { _storeType = [t copy]; }
- (void)dealloc { [self _cd_close]; }
- (void)_cd_close { if (_db) { sqlite3_close_v2(_db); _db = NULL; } }

/* ---------------- SQL helpers ---------------- */
- (BOOL)_exec:(NSString *)sql error:(NSError **)error {
    char *msg = NULL;
    if (sqlite3_exec(_db, sql.UTF8String, NULL, NULL, &msg) == SQLITE_OK) return YES;
    NSString *m = msg ? @(msg) : @"?";
    sqlite3_free(msg);
    if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSSQLiteError userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"SQLite error: %@ (%@)", m, sql], @"NSSQLiteErrorDomain": @(sqlite3_errcode(_db)) }];
    else CD_LOG(@"SQLite error: %@ (%@)", m, sql);
    return NO;
}
- (sqlite3_stmt *)_prepare:(NSString *)sql {
    sqlite3_stmt *st = NULL;
    if (sqlite3_prepare_v2(_db, sql.UTF8String, -1, &st, NULL) != SQLITE_OK) { CD_LOG(@"SQLite prepare failed: %s (%@)", sqlite3_errmsg(_db), sql); return NULL; }
    return st;
}
static int64_t pk_of(id v) {
    if ([v isKindOfClass:[NSManagedObject class]]) v = [v objectID];
    if ([v isKindOfClass:[NSManagedObjectID class]]) return [v _cd_pk];
    return [v longLongValue];
}
static void bind(sqlite3_stmt *st, int i, id v) {
    if (!v || v == [NSNull null]) sqlite3_bind_null(st, i);
    else if ([v isKindOfClass:[NSNumber class]]) {
        const char *t = [v objCType];
        if (t && (*t == 'd' || *t == 'f')) sqlite3_bind_double(st, i, [v doubleValue]); else sqlite3_bind_int64(st, i, [v longLongValue]);
    }
    else if ([v isKindOfClass:[NSString class]]) sqlite3_bind_text(st, i, [v UTF8String], -1, SQLITE_TRANSIENT_);
    else if ([v isKindOfClass:[NSData class]]) sqlite3_bind_blob(st, i, [v bytes], (int)[v length], SQLITE_TRANSIENT_);
    else if ([v isKindOfClass:[NSDate class]]) sqlite3_bind_double(st, i, [v timeIntervalSinceReferenceDate]);
    else if ([v isKindOfClass:[NSUUID class]]) { uuid_t b; [v getUUIDBytes:b]; sqlite3_bind_blob(st, i, b, 16, SQLITE_TRANSIENT_); }
    else if ([v isKindOfClass:[NSURL class]]) sqlite3_bind_text(st, i, [[v absoluteString] UTF8String], -1, SQLITE_TRANSIENT_);
    else if ([v isKindOfClass:[NSManagedObject class]] || [v isKindOfClass:[NSManagedObjectID class]]) sqlite3_bind_int64(st, i, pk_of(v));
    else sqlite3_bind_text(st, i, [[v description] UTF8String], -1, SQLITE_TRANSIENT_);
}
static void bind_all(sqlite3_stmt *st, NSArray *args) { for (NSUInteger i = 0; i < args.count; i++) bind(st, (int)i + 1, args[i]); }
static NSData *col_data(sqlite3_stmt *st, int i) { return [NSData dataWithBytes:sqlite3_column_blob(st, i) length:(NSUInteger)sqlite3_column_bytes(st, i)]; }
static NSString *col_text(sqlite3_stmt *st, int i) { const unsigned char *t = sqlite3_column_text(st, i); return t ? @((const char *)t) : nil; }
/* SQL value -> object for an attribute */
static id col_value(sqlite3_stmt *st, int i, NSAttributeDescription *a) {
    if (sqlite3_column_type(st, i) == SQLITE_NULL) return nil;
    switch (a.attributeType) {
    case NSInteger16AttributeType: return @((short)sqlite3_column_int64(st, i));
    case NSInteger32AttributeType: return @((int)sqlite3_column_int64(st, i));
    case NSInteger64AttributeType: return @((long long)sqlite3_column_int64(st, i));
    case NSBooleanAttributeType: return @(sqlite3_column_int64(st, i) != 0);
    case NSDoubleAttributeType: case NSDecimalAttributeType: return @(sqlite3_column_double(st, i));
    case NSFloatAttributeType: return @((float)sqlite3_column_double(st, i));
    case NSStringAttributeType: return col_text(st, i);
    case NSDateAttributeType: return [[NSDate alloc] initWithTimeIntervalSinceReferenceDate:sqlite3_column_double(st, i)];
    case NSBinaryDataAttributeType: return col_data(st, i);
    case NSUUIDAttributeType: { NSData *d = col_data(st, i); return d.length == 16 ? [[NSUUID alloc] initWithUUIDBytes:d.bytes] : nil; }
    case NSURIAttributeType: { NSString *s = col_text(st, i); return s ? [NSURL URLWithString:s] : nil; }
    case NSTransformableAttributeType: return [a _cd_valueFromData:col_data(st, i)];
    default: { int t = sqlite3_column_type(st, i);
        if (t == SQLITE_INTEGER) return @((long long)sqlite3_column_int64(st, i));
        if (t == SQLITE_FLOAT) return @(sqlite3_column_double(st, i));
        if (t == SQLITE_TEXT) return col_text(st, i);
        return col_data(st, i); }
    }
}
/* object value -> SQL argument for an attribute */
static id sql_value(NSAttributeDescription *a, id v) {
    if (!v || v == [NSNull null]) return [NSNull null];
    switch (a.attributeType) {
    case NSTransformableAttributeType: return [a _cd_dataFromValue:v] ?: [NSNull null];
    case NSBooleanAttributeType: return @([v boolValue] ? 1 : 0);
    case NSInteger16AttributeType: case NSInteger32AttributeType: case NSInteger64AttributeType: return [v isKindOfClass:[NSNumber class]] ? @([v longLongValue]) : v;
    case NSDoubleAttributeType: case NSFloatAttributeType: case NSDecimalAttributeType: return [v isKindOfClass:[NSNumber class]] ? @([v doubleValue]) : v;
    default: return v;
    }
}

/* ---------------- opening, schema, migration ---------------- */
- (NSSet *)_columnsOf:(NSString *)table {
    NSMutableSet *s = [NSMutableSet set];
    sqlite3_stmt *st = [self _prepare:[NSString stringWithFormat:@"PRAGMA table_info(%@)", table]];
    while (st && sqlite3_step(st) == SQLITE_ROW) [s addObject:[col_text(st, 1) uppercaseString]];
    sqlite3_finalize(st);
    return s;
}
- (BOOL)_tableExists:(NSString *)t { return [self _columnsOf:t].count > 0; }
- (NSDictionary *)_readMetadata {
    NSMutableDictionary *m = [NSMutableDictionary dictionary];
    sqlite3_stmt *st = [self _prepare:@"SELECT Z_KEY, Z_VALUE FROM Z_METADATA"];
    while (st && sqlite3_step(st) == SQLITE_ROW) {
        NSString *k = col_text(st, 0);
        if (!k) continue;
        if (sqlite3_column_type(st, 1) == SQLITE_BLOB) {
            id v = [NSPropertyListSerialization propertyListWithData:col_data(st, 1) options:0 format:NULL error:NULL];
            if (v) m[k] = v;
        } else if (col_text(st, 1)) m[k] = col_text(st, 1);
    }
    sqlite3_finalize(st);
    return m;
}
- (BOOL)_writeMetadata:(NSDictionary *)md error:(NSError **)error {
    if (![self _exec:@"DELETE FROM Z_METADATA" error:error]) return NO;
    for (NSString *k in md) {
        sqlite3_stmt *st = [self _prepare:@"INSERT INTO Z_METADATA (Z_KEY, Z_VALUE) VALUES (?, ?)"];
        id v = md[k];
        NSData *d = [v isKindOfClass:[NSString class]] ? nil : [NSPropertyListSerialization dataWithPropertyList:v format:NSPropertyListBinaryFormat_v1_0 options:0 error:NULL];
        bind(st, 1, k);
        bind(st, 2, d ?: ([v isKindOfClass:[NSString class]] ? v : [NSNull null]));
        sqlite3_step(st); sqlite3_finalize(st);
    }
    return YES;
}
/* creates missing tables, columns and entity rows (fresh stores and lightweight migration) */
- (BOOL)_ensureSchema:(NSError **)error {
    NSMutableDictionary *existingEnts = [NSMutableDictionary dictionary];
    sqlite3_stmt *st = [self _prepare:@"SELECT Z_ENT, Z_NAME FROM Z_ENTITIES"];
    while (st && sqlite3_step(st) == SQLITE_ROW) existingEnts[col_text(st, 1)] = @(sqlite3_column_int(st, 0));
    sqlite3_finalize(st);
    NSArray *entities = [_model.entities sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    for (NSEntityDescription *e in entities) {                   /* renamed entities keep their number */
        if (!existingEnts[e.name] && e.renamingIdentifier && existingEnts[e.renamingIdentifier]) {
            NSString *old = [@"Z" stringByAppendingString:e.renamingIdentifier.uppercaseString];
            if (!e.superentity && [self _tableExists:old] && ![self _tableExists:e._cd_table] &&
                ![self _exec:[NSString stringWithFormat:@"ALTER TABLE %@ RENAME TO %@", old, e._cd_table] error:error]) return NO;
            if (![self _exec:[NSString stringWithFormat:@"UPDATE Z_ENTITIES SET Z_NAME = %@ WHERE Z_NAME = %@", sql_quote(e.name), sql_quote(e.renamingIdentifier)] error:error]) return NO;
            existingEnts[e.name] = existingEnts[e.renamingIdentifier];
        }
        if (!existingEnts[e.name]) {
            if (![self _exec:[NSString stringWithFormat:@"INSERT INTO Z_ENTITIES (Z_NAME, Z_SUPER, Z_MAX) VALUES (%@, 0, 0)", sql_quote(e.name)] error:error]) return NO;
            existingEnts[e.name] = @(sqlite3_last_insert_rowid(_db));
        }
    }
    for (NSEntityDescription *e in entities)
        if (e.superentity) [self _exec:[NSString stringWithFormat:@"UPDATE Z_ENTITIES SET Z_SUPER = %@ WHERE Z_ENT = %@", existingEnts[e.superentity.name], existingEnts[e.name]] error:NULL];
    _entNums = existingEnts; _numEnts = [NSMutableDictionary dictionary];
    for (NSEntityDescription *e in _model.entities) _numEnts[_entNums[e.name]] = e;
    for (NSEntityDescription *root in entities) {
        if (root.superentity) continue;
        NSString *table = root._cd_table;
        if (![self _tableExists:table] &&
            ![self _exec:[NSString stringWithFormat:@"CREATE TABLE %@ (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER)", table] error:error]) return NO;
        NSMutableSet *cols = [[self _columnsOf:table] mutableCopy];
        for (NSEntityDescription *e in root._cd_family) {
            for (NSPropertyDescription *p in e.properties) {
                if (p.transient) continue;
                if ([p isKindOfClass:[NSAttributeDescription class]]) {
                    NSAttributeDescription *a = (NSAttributeDescription *)p;
                    NSString *c = a._cd_column;
                    if ([cols containsObject:c]) continue;
                    NSString *old = a.renamingIdentifier.length ? [@"Z" stringByAppendingString:a.renamingIdentifier.uppercaseString] : nil;
                    if (old && [cols containsObject:old]) {
                        if (![self _exec:[NSString stringWithFormat:@"ALTER TABLE %@ RENAME COLUMN %@ TO %@", table, old, c] error:error]) return NO;
                        [cols removeObject:old]; [cols addObject:c];
                        continue;
                    }
                    NSString *def = @"";
                    id dv = sql_value(a, a.defaultValue);
                    if (a.defaultValue && dv != [NSNull null] && ![dv isKindOfClass:[NSData class]] && ![dv isKindOfClass:[NSUUID class]])
                        def = [NSString stringWithFormat:@" DEFAULT %@", sql_quote([dv isKindOfClass:[NSURL class]] ? [dv absoluteString] : dv)];
                    if (![self _exec:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@%@", table, c, col_type(a.attributeType), def] error:error]) return NO;
                    [cols addObject:c];
                    if (a.indexed) [self _exec:[NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@_%@_INDEX ON %@ (%@)", table, c, table, c] error:NULL];
                } else if ([p isKindOfClass:[NSRelationshipDescription class]]) {
                    NSRelationshipDescription *r = (NSRelationshipDescription *)p;
                    if (r.toMany) {
                        if (!r._cd_usesJoinTable || r._cd_joinOwner != r) continue;
                        NSString *jt = r._cd_joinTable;
                        if (![self _tableExists:jt]) {
                            if (![self _exec:[NSString stringWithFormat:@"CREATE TABLE %@ (Z_SRC INTEGER, Z_SRCENT INTEGER, Z_DST INTEGER, Z_DSTENT INTEGER, Z_ORDER INTEGER)", jt] error:error]) return NO;
                            [self _exec:[NSString stringWithFormat:@"CREATE INDEX %@_SRC ON %@ (Z_SRC)", jt, jt] error:NULL];
                            [self _exec:[NSString stringWithFormat:@"CREATE INDEX %@_DST ON %@ (Z_DST)", jt, jt] error:NULL];
                        }
                        continue;
                    }
                    NSString *c = r._cd_column;
                    if ([cols containsObject:c]) continue;
                    if (![self _exec:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ INTEGER", table, c] error:error] ||
                        ![self _exec:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ INTEGER", table, r._cd_entColumn] error:error]) return NO;
                    [self _exec:[NSString stringWithFormat:@"CREATE INDEX IF NOT EXISTS %@_%@_INDEX ON %@ (%@)", table, c, table, c] error:NULL];
                    [cols addObject:c]; [cols addObject:r._cd_entColumn.uppercaseString];
                }
            }
        }
    }
    return YES;
}
- (BOOL)_cd_openWithModel:(NSManagedObjectModel *)model options:(NSDictionary *)options error:(NSError **)error {
    _model = model;
    NSString *path = self.URL.path;
    BOOL memory = [_storeType isEqualToString:NSInMemoryStoreType] || !path.length || [path isEqualToString:@"/dev/null"];
    BOOL readOnly = [options[NSReadOnlyPersistentStoreOption] boolValue];
    self.readOnly = readOnly;
    if (!memory) [[NSFileManager defaultManager] createDirectoryAtPath:path.stringByDeletingLastPathComponent withIntermediateDirectories:YES attributes:nil error:NULL];
    int flags = (readOnly && !memory ? SQLITE_OPEN_READONLY : SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE) | SQLITE_OPEN_FULLMUTEX;
    if (sqlite3_open_v2(memory ? ":memory:" : path.UTF8String, &_db, flags, NULL) != SQLITE_OK) {
        NSString *m = _db ? @(sqlite3_errmsg(_db)) : @"out of memory";
        [self _cd_close];
        if (error) *error = CDError(NSPersistentStoreOpenError, [NSString stringWithFormat:@"The store at %@ could not be opened: %@", path, m], @{ @"NSFilePath": path ?: @"" });
        return NO;
    }
    sqlite3_busy_timeout(_db, 5000);
    if (!memory && !readOnly) [self _exec:@"PRAGMA journal_mode = WAL" error:NULL];
    NSDictionary *pragmas = options[NSSQLitePragmasOption];
    for (NSString *k in pragmas) [self _exec:[NSString stringWithFormat:@"PRAGMA %@ = %@", k, pragmas[k]] error:NULL];
    BOOL fresh = ![self _tableExists:@"Z_METADATA"];
    NSDictionary *schema = model._cd_schema;
    NSMutableDictionary *md;
    if (fresh) {
        if (readOnly) { if (error) *error = CDError(NSPersistentStoreOpenError, @"A read-only store does not exist yet.", nil); [self _cd_close]; return NO; }
        md = [NSMutableDictionary dictionaryWithDictionary:@{ NSStoreUUIDKey: [NSUUID UUID].UUIDString, NSStoreTypeKey: self.type,
                                                             @"isimSchema": schema, @"isimFormat": @"isim Core Data SQLite store 1" }];
        if (![self _exec:@"BEGIN" error:error]) return NO;
        BOOL ok = [self _exec:@"CREATE TABLE Z_METADATA (Z_KEY TEXT PRIMARY KEY, Z_VALUE BLOB)" error:error] &&
                  [self _exec:@"CREATE TABLE Z_ENTITIES (Z_ENT INTEGER PRIMARY KEY, Z_NAME TEXT UNIQUE, Z_SUPER INTEGER, Z_MAX INTEGER)" error:error] &&
                  [self _ensureSchema:error] && [self _writeMetadata:md error:error];
        [self _exec:ok ? @"COMMIT" : @"ROLLBACK" error:NULL];
        if (!ok) { [self _cd_close]; return NO; }
    } else {
        md = [[self _readMetadata] mutableCopy];
        NSDictionary *stored = md[@"isimSchema"];
        if (![stored isEqual:schema]) {
            BOOL migrate = [options[NSMigratePersistentStoresAutomaticallyOption] boolValue] && [options[NSInferMappingModelAutomaticallyOption] boolValue];
            if (!migrate || readOnly) {
                if (error) *error = CDError(NSPersistentStoreIncompatibleVersionHashError, @"The model used to open the store is incompatible with the one used to create the store.",
                                            @{ @"sourceURL": self.URL ?: [NSNull null] });
                [self _cd_close];
                return NO;
            }
            for (NSString *name in stored) {                     /* lightweight migration limits */
                NSDictionary *was = stored[name], *now = schema[name];
                if (now && ![was[@"parent"] isEqual:now[@"parent"]]) {
                    if (error) *error = CDError(NSMigrationError, [NSString stringWithFormat:@"isim's lightweight migration cannot change the parent entity of %@.", name], nil);
                    [self _cd_close];
                    return NO;
                }
                for (NSString *a in now[@"attributes"]) if (was[@"attributes"][a] && ![was[@"attributes"][a] isEqual:now[@"attributes"][a]])
                    CD_LOG(@"migration: %@.%@ changed type from %@ to %@; existing values are kept as stored", name, a, was[@"attributes"][a], now[@"attributes"][a]);
            }
            if (![self _exec:@"BEGIN" error:error]) return NO;
            md[@"isimSchema"] = schema;
            BOOL ok = [self _ensureSchema:error] && [self _writeMetadata:md error:error];
            [self _exec:ok ? @"COMMIT" : @"ROLLBACK" error:NULL];
            if (!ok) { [self _cd_close]; return NO; }
            CD_LOG(@"lightweight migration of %@ done", path.lastPathComponent);
        } else if (![self _ensureSchema:error]) { [self _cd_close]; return NO; }
    }
    self.identifier = md[NSStoreUUIDKey];
    NSMutableDictionary *pub = [md mutableCopy];
    pub[NSStoreModelVersionHashesKey] = model.entityVersionHashesByName;
    pub[NSStoreModelVersionIdentifiersKey] = model.versionIdentifiers.allObjects ?: @[];
    [super setMetadata:pub];
    return YES;
}
- (void)setMetadata:(NSDictionary *)metadata {
    [super setMetadata:metadata];
    if (!_db || self.readOnly) return;
    NSMutableDictionary *md = [[self _readMetadata] mutableCopy];
    for (NSString *k in metadata) if ([NSPropertyListSerialization propertyList:metadata[k] isValidForFormat:NSPropertyListBinaryFormat_v1_0] && ![k isEqualToString:NSStoreModelVersionHashesKey]) md[k] = metadata[k];
    [self _writeMetadata:md error:NULL];
}

- (int)_cd_entityNumber:(NSEntityDescription *)e { return [_entNums[e.name] intValue]; }
- (NSEntityDescription *)_cd_entityForNumber:(int)n { return _numEnts[@(n)]; }
- (NSString *)_entList:(NSArray *)family {
    NSMutableArray *nums = [NSMutableArray array];
    for (NSEntityDescription *e in family) [nums addObject:_entNums[e.name] ?: @(-1)];
    return [nums componentsJoinedByString:@", "];
}

/* ---------------- reading ---------------- */
- (NSArray *)_columnsForFamily:(NSArray *)family {
    NSMutableArray *props = [NSMutableArray array];
    NSMutableSet *seen = [NSMutableSet set];
    for (NSEntityDescription *e in family) for (NSPropertyDescription *p in e.properties) {
        if (p.transient || [p isKindOfClass:[NSFetchedPropertyDescription class]] || [p isKindOfClass:[NSExpressionDescription class]]) continue;
        if ([p isKindOfClass:[NSRelationshipDescription class]] && ((NSRelationshipDescription *)p).toMany) continue;
        if ([seen containsObject:p._cd_column]) continue;
        [seen addObject:p._cd_column];
        [props addObject:p];
    }
    return props;
}
- (NSArray<CDSnapshot *> *)_rowsFromSQL:(NSString *)sql args:(NSArray *)args props:(NSArray *)props {
    NSMutableArray *out = [NSMutableArray array];
    sqlite3_stmt *st = [self _prepare:sql];
    if (!st) return out;
    bind_all(st, args);
    NSMutableDictionary *colIndex = [NSMutableDictionary dictionary];
    int c = 3;
    for (NSPropertyDescription *p in props) {
        colIndex[p._cd_column] = @(c);
        c += [p isKindOfClass:[NSRelationshipDescription class]] ? 2 : 1;
    }
    while (sqlite3_step(st) == SQLITE_ROW) {
        int64_t pk = sqlite3_column_int64(st, 0);
        NSEntityDescription *e = _numEnts[@(sqlite3_column_int(st, 1))];
        if (!e) continue;
        CDSnapshot *s = [[CDSnapshot alloc] init];
        s.objectID = [NSManagedObjectID _cd_idWithEntity:e store:self pk:pk];
        s.version = sqlite3_column_int64(st, 2);
        for (NSPropertyDescription *p in e.properties) {
            NSNumber *ci = colIndex[p._cd_column];
            if (!ci || p.transient) continue;
            int i = ci.intValue;
            if ([p isKindOfClass:[NSAttributeDescription class]]) s.values[p.name] = col_value(st, i, (NSAttributeDescription *)p) ?: [NSNull null];
            else if ([p isKindOfClass:[NSRelationshipDescription class]]) {
                NSRelationshipDescription *r = (NSRelationshipDescription *)p;
                if (sqlite3_column_type(st, i) == SQLITE_NULL) { s.values[p.name] = [NSNull null]; continue; }
                NSEntityDescription *de = sqlite3_column_type(st, i + 1) == SQLITE_NULL ? nil : _numEnts[@(sqlite3_column_int(st, i + 1))];
                de = de ?: r.destinationEntity;
                if (de) s.values[p.name] = [NSManagedObjectID _cd_idWithEntity:de store:self pk:sqlite3_column_int64(st, i)];
            }
        }
        [out addObject:s];
    }
    sqlite3_finalize(st);
    return out;
}
- (NSString *)_selectFor:(NSArray *)family props:(NSArray *)props {
    NSMutableString *sql = [NSMutableString stringWithString:@"SELECT Z_PK, Z_ENT, Z_OPT"];
    for (NSPropertyDescription *p in props) {
        [sql appendFormat:@", %@", p._cd_column];
        if ([p isKindOfClass:[NSRelationshipDescription class]]) [sql appendFormat:@", %@", ((NSRelationshipDescription *)p)._cd_entColumn];
    }
    [sql appendFormat:@" FROM %@ WHERE Z_ENT IN (%@)", [family[0] _cd_table], [self _entList:family]];
    return sql;
}
- (NSArray<CDSnapshot *> *)_cd_rowsForEntities:(NSArray *)family where:(NSString *)where args:(NSArray *)args order:(NSString *)order limit:(NSUInteger)limit offset:(NSUInteger)offset {
    if (!_db || !family.count) return @[];
    NSArray *props = [self _columnsForFamily:family];
    NSMutableString *sql = [[self _selectFor:family props:props] mutableCopy];
    if (where.length) [sql appendFormat:@" AND (%@)", where];
    [sql appendFormat:@" ORDER BY %@", order.length ? [order stringByAppendingString:@", Z_PK"] : @"Z_PK"];
    if (limit || offset) [sql appendFormat:@" LIMIT %lld OFFSET %lu", limit ? (long long)limit : -1LL, (unsigned long)offset];
    return [self _rowsFromSQL:sql args:args props:props];
}
- (NSUInteger)_cd_countForEntities:(NSArray *)family where:(NSString *)where args:(NSArray *)args {
    if (!_db || !family.count) return 0;
    NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT COUNT(*) FROM %@ WHERE Z_ENT IN (%@)", [family[0] _cd_table], [self _entList:family]];
    if (where.length) [sql appendFormat:@" AND (%@)", where];
    sqlite3_stmt *st = [self _prepare:sql];
    if (!st) return 0;
    bind_all(st, args);
    NSUInteger n = sqlite3_step(st) == SQLITE_ROW ? (NSUInteger)sqlite3_column_int64(st, 0) : 0;
    sqlite3_finalize(st);
    return n;
}
- (CDSnapshot *)_cd_rowForObjectID:(NSManagedObjectID *)oid {
    NSArray *family = oid.entity._cd_root._cd_family;
    NSArray *props = [self _columnsForFamily:family];
    NSString *sql = [[self _selectFor:family props:props] stringByAppendingString:@" AND Z_PK = ?"];
    return [self _rowsFromSQL:sql args:@[@(oid._cd_pk)] props:props].firstObject;
}
- (NSArray<NSManagedObjectID *> *)_idsFromSQL:(NSString *)sql args:(NSArray *)args defaultEntity:(NSEntityDescription *)de {
    NSMutableArray *ids = [NSMutableArray array];
    sqlite3_stmt *st = [self _prepare:sql];
    if (!st) return ids;
    bind_all(st, args);
    while (sqlite3_step(st) == SQLITE_ROW) {
        NSEntityDescription *e = sqlite3_column_type(st, 1) == SQLITE_NULL ? nil : _numEnts[@(sqlite3_column_int(st, 1))];
        [ids addObject:[NSManagedObjectID _cd_idWithEntity:e ?: de store:self pk:sqlite3_column_int64(st, 0)]];
    }
    sqlite3_finalize(st);
    return ids;
}
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDs:(NSManagedObjectID *)oid relationship:(NSRelationshipDescription *)r {
    if (!_db) return @[];
    if (r._cd_usesJoinTable) {
        NSString *jt = r._cd_joinTable;
        if (r._cd_joinOwner == r)
            return [self _idsFromSQL:[NSString stringWithFormat:@"SELECT Z_DST, Z_DSTENT FROM %@ WHERE Z_SRC = ? ORDER BY Z_ORDER", jt] args:@[@(oid._cd_pk)] defaultEntity:r.destinationEntity];
        return [self _idsFromSQL:[NSString stringWithFormat:@"SELECT Z_SRC, Z_SRCENT FROM %@ WHERE Z_DST = ? ORDER BY Z_SRC", jt] args:@[@(oid._cd_pk)] defaultEntity:r.destinationEntity];
    }
    NSRelationshipDescription *inv = r.inverseRelationship;
    NSEntityDescription *de = r.destinationEntity;
    NSString *sql = [NSString stringWithFormat:@"SELECT Z_PK, Z_ENT FROM %@ WHERE %@ = ? AND Z_ENT IN (%@) ORDER BY Z_PK", de._cd_table, inv._cd_column, [self _entList:de._cd_family]];
    return [self _idsFromSQL:sql args:@[@(oid._cd_pk)] defaultEntity:de];
}
- (NSArray<NSManagedObjectID *> *)_cd_permanentIDsForEntities:(NSArray<NSEntityDescription *> *)entities error:(NSError **)error {
    if (!_db) { if (error) *error = CDError(NSPersistentStoreOperationError, @"The store is closed.", nil); return nil; }
    NSMutableDictionary<NSString *, NSNumber *> *counts = [NSMutableDictionary dictionary];
    for (NSEntityDescription *e in entities) { NSString *root = e._cd_root.name; counts[root] = @(counts[root].longLongValue + 1); }
    BOOL own = !_inTxn;
    if (own && ![self _exec:@"BEGIN IMMEDIATE" error:error]) return nil;
    NSMutableDictionary<NSString *, NSNumber *> *next = [NSMutableDictionary dictionary];
    for (NSString *root in counts) {
        NSNumber *num = _entNums[root];
        [self _exec:[NSString stringWithFormat:@"UPDATE Z_ENTITIES SET Z_MAX = Z_MAX + %lld WHERE Z_ENT = %@", counts[root].longLongValue, num] error:NULL];
        sqlite3_stmt *st = [self _prepare:[NSString stringWithFormat:@"SELECT Z_MAX FROM Z_ENTITIES WHERE Z_ENT = %@", num]];
        int64_t max = st && sqlite3_step(st) == SQLITE_ROW ? sqlite3_column_int64(st, 0) : 0;
        sqlite3_finalize(st);
        next[root] = @(max - counts[root].longLongValue + 1);
    }
    if (own) [self _exec:@"COMMIT" error:NULL];
    NSMutableArray *ids = [NSMutableArray array];
    for (NSEntityDescription *e in entities) {
        NSString *root = e._cd_root.name;
        int64_t pk = next[root].longLongValue;
        next[root] = @(pk + 1);
        [ids addObject:[NSManagedObjectID _cd_idWithEntity:e store:self pk:pk]];
    }
    return ids;
}

/* ---------------- writing ---------------- */
- (void)_columnsAndValuesFor:(NSManagedObject *)o cols:(NSMutableArray *)cols vals:(NSMutableArray *)vals {
    for (NSPropertyDescription *p in o.entity.properties) {
        if (p.transient || [p isKindOfClass:[NSFetchedPropertyDescription class]]) continue;
        if ([p isKindOfClass:[NSAttributeDescription class]]) {
            [cols addObject:p._cd_column];
            [vals addObject:sql_value((NSAttributeDescription *)p, [o _cd_raw:p.name])];
        } else if ([p isKindOfClass:[NSRelationshipDescription class]] && !((NSRelationshipDescription *)p).toMany) {
            NSManagedObject *d = [o _cd_raw:p.name];
            [cols addObject:p._cd_column]; [cols addObject:((NSRelationshipDescription *)p)._cd_entColumn];
            if (d && !d.objectID.temporaryID) { [vals addObject:@(d.objectID._cd_pk)]; [vals addObject:_entNums[d.entity.name] ?: [NSNull null]]; }
            else { [vals addObject:[NSNull null]]; [vals addObject:[NSNull null]]; }
        }
    }
}
- (BOOL)_run:(NSString *)sql args:(NSArray *)args error:(NSError **)error {
    sqlite3_stmt *st = [self _prepare:sql];
    if (!st) { if (error) *error = CDError(NSSQLiteError, [NSString stringWithFormat:@"SQLite prepare failed: %s", sqlite3_errmsg(_db)], nil); return NO; }
    bind_all(st, args);
    int rc = sqlite3_step(st);
    sqlite3_finalize(st);
    if (rc != SQLITE_DONE && rc != SQLITE_ROW) {
        if (error) *error = CDError(NSSQLiteError, [NSString stringWithFormat:@"SQLite error %d: %s", rc, sqlite3_errmsg(_db)], nil);
        return NO;
    }
    return YES;
}
- (BOOL)_writeJoinsFor:(NSManagedObject *)o all:(BOOL)all error:(NSError **)error {
    NSArray *changed = all ? nil : o._cd_changedKeys;
    for (NSRelationshipDescription *r in o.entity.relationshipsByName.allValues) {
        if (r.transient || !r._cd_usesJoinTable || r._cd_joinOwner != r) continue;
        if (!o._cd_values[r.name]) continue;                       /* never loaded: unchanged */
        if (!all && ![changed containsObject:r.name]) continue;
        NSString *jt = r._cd_joinTable;
        int64_t pk = o.objectID._cd_pk;
        if (![self _run:[NSString stringWithFormat:@"DELETE FROM %@ WHERE Z_SRC = ?", jt] args:@[@(pk)] error:error]) return NO;
        NSArray *members = CDToManyArray(o._cd_values[r.name]);
        for (NSUInteger i = 0; i < members.count; i++) {
            NSManagedObject *d = members[i];
            if (d.objectID.temporaryID || d.isDeleted) continue;
            if (![self _run:[NSString stringWithFormat:@"INSERT INTO %@ (Z_SRC, Z_SRCENT, Z_DST, Z_DSTENT, Z_ORDER) VALUES (?, ?, ?, ?, ?)", jt]
                     args:@[@(pk), _entNums[o.entity.name] ?: @0, @(d.objectID._cd_pk), _entNums[d.entity.name] ?: @0, @(i)] error:error]) return NO;
        }
    }
    return YES;
}
- (BOOL)_deleteRows:(NSArray<NSNumber *> *)pks root:(NSEntityDescription *)root error:(NSError **)error {
    if (!pks.count) return YES;
    NSString *list = [pks componentsJoinedByString:@", "];
    if (![self _exec:[NSString stringWithFormat:@"DELETE FROM %@ WHERE Z_PK IN (%@)", root._cd_table, list] error:error]) return NO;
    for (NSEntityDescription *e in _model.entities) for (NSRelationshipDescription *r in e.relationshipsByName.allValues) {
        if (r.transient || r.entity != e) continue;
        if (r._cd_usesJoinTable && r._cd_joinOwner == r) {           /* join rows from or to the deleted rows */
            if ([e._cd_root isEqual:root]) [self _exec:[NSString stringWithFormat:@"DELETE FROM %@ WHERE Z_SRC IN (%@)", r._cd_joinTable, list] error:NULL];
            if ([r.destinationEntity._cd_root isEqual:root]) [self _exec:[NSString stringWithFormat:@"DELETE FROM %@ WHERE Z_DST IN (%@)", r._cd_joinTable, list] error:NULL];
        }
    }
    return YES;
}
- (BOOL)_cd_saveInserted:(NSArray<NSManagedObject *> *)inserted updated:(NSArray<NSManagedObject *> *)updated deleted:(NSArray<NSManagedObject *> *)deleted
             mergePolicy:(NSMergePolicy *)policy error:(NSError **)error {
    if (!_db) { if (error) *error = CDError(NSPersistentStoreSaveError, @"The store is closed.", nil); return NO; }
    if (![self _exec:@"BEGIN IMMEDIATE" error:error]) return NO;
    _inTxn = YES;
    BOOL ok = YES;
    NSMutableArray *conflicts = [NSMutableArray array], *write = [NSMutableArray array];
    for (NSManagedObject *o in updated) {                          /* optimistic locking */
        sqlite3_stmt *st = [self _prepare:[NSString stringWithFormat:@"SELECT Z_OPT FROM %@ WHERE Z_PK = ?", o.entity._cd_table]];
        bind(st, 1, @(o.objectID._cd_pk));
        BOOL exists = st && sqlite3_step(st) == SQLITE_ROW;
        int64_t version = exists ? sqlite3_column_int64(st, 0) : -1;
        sqlite3_finalize(st);
        if (exists && version == o._cd_version) { [write addObject:o]; continue; }
        if (!exists && policy.mergeType != NSErrorMergePolicyType) continue;       /* deleted elsewhere: nothing to write */
        switch (policy.mergeType) {
        case NSErrorMergePolicyType:
            [conflicts addObject:@{ @"object": o, @"oldVersion": @(o._cd_version), @"newVersion": @(version) }];
            break;
        case NSRollbackMergePolicyType: {
            CDSnapshot *s = [self _cd_rowForObjectID:o.objectID];
            if (s) [o _cd_mergeSnapshot:s keepChanges:NO];
            break; }
        case NSOverwriteMergePolicyType:
            [write addObject:o];
            break;
        case NSMergeByPropertyObjectTrumpMergePolicyType: {
            CDSnapshot *s = [self _cd_rowForObjectID:o.objectID];
            if (s) [o _cd_mergeSnapshot:s keepChanges:YES];
            [write addObject:o];
            break; }
        case NSMergeByPropertyStoreTrumpMergePolicyType: {
            CDSnapshot *s = [self _cd_rowForObjectID:o.objectID];
            if (s) {
                NSArray *mine = o._cd_changedKeys;
                NSDictionary *committed = [o._cd_committed copy];
                NSMutableDictionary *theirs = [NSMutableDictionary dictionary];
                for (NSString *k in mine) {
                    id sv = s.values[k], cv = committed[k];
                    if ([cv isKindOfClass:[NSManagedObject class]]) cv = [cv objectID];
                    if (sv == [NSNull null]) sv = nil;
                    if (sv && ![sv isKindOfClass:[NSArray class]] && !(cv && [sv isEqual:cv])) theirs[k] = sv;
                    else if (!sv && cv) theirs[k] = [NSNull null];
                }
                [o _cd_mergeSnapshot:s keepChanges:YES];
                for (NSString *k in theirs) {
                    id v = theirs[k] == [NSNull null] ? nil : theirs[k];
                    if ([v isKindOfClass:[NSManagedObjectID class]]) v = [o.managedObjectContext objectWithID:v];
                    [o _cd_setRaw:v forKey:k];
                }
            }
            [write addObject:o];
            break; }
        }
    }
    if (conflicts.count) {
        [self _exec:@"ROLLBACK" error:NULL];
        _inTxn = NO;
        if (error) *error = CDError(NSManagedObjectMergeError, @"Could not merge changes.", @{ NSPersistentStoreSaveConflictsErrorKey: conflicts });
        return NO;
    }
    for (NSManagedObject *o in inserted) {
        NSMutableArray *cols = [NSMutableArray arrayWithObjects:@"Z_PK", @"Z_ENT", @"Z_OPT", nil];
        NSMutableArray *vals = [NSMutableArray arrayWithObjects:@(o.objectID._cd_pk), _entNums[o.entity.name] ?: @0, @1, nil];
        [self _columnsAndValuesFor:o cols:cols vals:vals];
        NSMutableArray *qs = [NSMutableArray array]; for (NSUInteger i = 0; i < cols.count; i++) [qs addObject:@"?"];
        ok = ok && [self _run:[NSString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", o.entity._cd_table, [cols componentsJoinedByString:@", "], [qs componentsJoinedByString:@", "]] args:vals error:error];
    }
    for (NSManagedObject *o in write) {
        NSMutableArray *cols = [NSMutableArray array], *vals = [NSMutableArray array];
        [self _columnsAndValuesFor:o cols:cols vals:vals];
        NSMutableArray *sets = [NSMutableArray arrayWithObject:@"Z_OPT = Z_OPT + 1"];
        for (NSString *c in cols) [sets addObject:[c stringByAppendingString:@" = ?"]];
        [vals addObject:@(o.objectID._cd_pk)];
        ok = ok && [self _run:[NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE Z_PK = ?", o.entity._cd_table, [sets componentsJoinedByString:@", "]] args:vals error:error];
    }
    for (NSManagedObject *o in inserted) ok = ok && [self _writeJoinsFor:o all:YES error:error];
    for (NSManagedObject *o in write) ok = ok && [self _writeJoinsFor:o all:NO error:error];
    NSMutableDictionary<NSString *, NSMutableArray *> *byRoot = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString *, NSEntityDescription *> *roots = [NSMutableDictionary dictionary];
    for (NSManagedObject *o in deleted) {
        if (o.objectID.temporaryID) continue;
        NSEntityDescription *root = o.entity._cd_root;
        roots[root.name] = root;
        if (!byRoot[root.name]) byRoot[root.name] = [NSMutableArray array];
        [byRoot[root.name] addObject:@(o.objectID._cd_pk)];
    }
    for (NSString *r in byRoot) ok = ok && [self _deleteRows:byRoot[r] root:roots[r] error:error];
    if (!ok) { [self _exec:@"ROLLBACK" error:NULL]; _inTxn = NO; return NO; }
    if (![self _exec:@"COMMIT" error:error]) { [self _exec:@"ROLLBACK" error:NULL]; _inTxn = NO; return NO; }
    _inTxn = NO;
    for (NSManagedObject *o in inserted) o._cd_version = 1;
    for (NSManagedObject *o in write) {
        sqlite3_stmt *st = [self _prepare:[NSString stringWithFormat:@"SELECT Z_OPT FROM %@ WHERE Z_PK = ?", o.entity._cd_table]];
        bind(st, 1, @(o.objectID._cd_pk));
        if (st && sqlite3_step(st) == SQLITE_ROW) o._cd_version = sqlite3_column_int64(st, 0);
        sqlite3_finalize(st);
    }
    return YES;
}

/* ---------------- batch requests ---------------- */
- (NSArray<NSManagedObjectID *> *)_idsMatching:(NSFetchRequest *)fetch entity:(NSEntityDescription *)entity context:(NSManagedObjectContext *)context {
    NSArray *family = fetch.includesSubentities ? entity._cd_family : @[entity];
    NSMutableArray *args = [NSMutableArray array];
    BOOL exact = YES;
    NSString *where = fetch.predicate ? [self _cd_sqlForPredicate:fetch.predicate entity:entity args:args exact:&exact] : nil;
    if (exact) {
        NSMutableString *sql = [NSMutableString stringWithFormat:@"SELECT Z_PK, Z_ENT FROM %@ WHERE Z_ENT IN (%@)", entity._cd_table, [self _entList:family]];
        if (where.length) [sql appendFormat:@" AND (%@)", where];
        return [self _idsFromSQL:sql args:args defaultEntity:entity];
    }
    NSManagedObjectContext *scratch = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
    scratch.persistentStoreCoordinator = self.persistentStoreCoordinator;
    NSFetchRequest *r = [fetch copy];
    r.resultType = NSManagedObjectIDResultType;
    r.includesPendingChanges = NO;
    return [scratch executeFetchRequest:r error:NULL] ?: @[];
}
- (id)_cd_executeBatch:(NSPersistentStoreRequest *)request context:(NSManagedObjectContext *)context error:(NSError **)error {
    if (!_db || self.readOnly) { if (error) *error = CDError(NSPersistentStoreOperationError, @"The store is closed or read-only.", nil); return nil; }
    if ([request isKindOfClass:[NSBatchDeleteRequest class]]) {
        NSBatchDeleteRequest *req = (NSBatchDeleteRequest *)request;
        NSArray *ids = req._cd_objectIDs;
        if (!ids) {
            NSEntityDescription *e = [req.fetchRequest _cd_entityInContext:context] ?: _model.entitiesByName[req.fetchRequest.entityName];
            if (!e) { if (error) *error = CDError(NSCoreDataError, @"NSBatchDeleteRequest: unknown entity", nil); return nil; }
            ids = [self _idsMatching:req.fetchRequest entity:e context:context];
        }
        NSMutableDictionary<NSString *, NSMutableArray *> *byRoot = [NSMutableDictionary dictionary];
        NSMutableDictionary *roots = [NSMutableDictionary dictionary];
        for (NSManagedObjectID *i in ids) {
            NSEntityDescription *root = _model.entitiesByName[i.entity.name]._cd_root ?: i.entity._cd_root;
            roots[root.name] = root;
            if (!byRoot[root.name]) byRoot[root.name] = [NSMutableArray array];
            [byRoot[root.name] addObject:@(i._cd_pk)];
        }
        if (![self _exec:@"BEGIN IMMEDIATE" error:error]) return nil;
        BOOL ok = YES;
        for (NSString *r in byRoot) {
            NSString *list = [byRoot[r] componentsJoinedByString:@", "];
            ok = ok && [self _deleteRows:byRoot[r] root:roots[r] error:error];
            for (NSEntityDescription *e in _model.entities) for (NSRelationshipDescription *rel in e.relationshipsByName.allValues) {
                if (rel.transient || rel.toMany || rel.entity != e || ![rel.destinationEntity._cd_root isEqual:roots[r]]) continue;
                [self _exec:[NSString stringWithFormat:@"UPDATE %@ SET %@ = NULL, %@ = NULL, Z_OPT = Z_OPT + 1 WHERE %@ IN (%@)", e._cd_table, rel._cd_column, rel._cd_entColumn, rel._cd_column, list] error:NULL];
            }
        }
        [self _exec:ok ? @"COMMIT" : @"ROLLBACK" error:NULL];
        if (!ok) return nil;
        id result = req.resultType == NSBatchDeleteResultTypeObjectIDs ? ids : req.resultType == NSBatchDeleteResultTypeCount ? @(ids.count) : @YES;
        return [[NSBatchDeleteResult alloc] _cd_initWithResult:result type:req.resultType];
    }
    if ([request isKindOfClass:[NSBatchUpdateRequest class]]) {
        NSBatchUpdateRequest *req = (NSBatchUpdateRequest *)request;
        NSEntityDescription *e = _model.entitiesByName[req.entityName] ?: req.entity;
        if (!e) { if (error) *error = CDError(NSCoreDataError, @"NSBatchUpdateRequest: unknown entity", nil); return nil; }
        NSFetchRequest *f = [NSFetchRequest fetchRequestWithEntityName:e.name];
        f.entity = e; f.predicate = req.predicate; f.includesSubentities = req.includesSubentities;
        NSArray *ids = [self _idsMatching:f entity:e context:context];
        NSMutableArray *sets = [NSMutableArray arrayWithObject:@"Z_OPT = Z_OPT + 1"], *args = [NSMutableArray array];
        for (id key in req.propertiesToUpdate) {
            NSString *k = [key isKindOfClass:[NSPropertyDescription class]] ? [key name] : key;
            NSAttributeDescription *a = e.attributesByName[k];
            if (!a) { if (error) *error = CDError(NSCoreDataError, [NSString stringWithFormat:@"NSBatchUpdateRequest: %@ is not an attribute of %@", k, e.name], nil); return nil; }
            id v = req.propertiesToUpdate[key];
            if ([v isKindOfClass:[NSExpression class]]) {
                NSExpression *x = v;
                if (x.expressionType == NSKeyPathExpressionType && e.attributesByName[x.keyPath]) { [sets addObject:[NSString stringWithFormat:@"%@ = %@", a._cd_column, e.attributesByName[x.keyPath]._cd_column]]; continue; }
                v = [x expressionValueWithObject:nil context:nil];
            }
            [sets addObject:[a._cd_column stringByAppendingString:@" = ?"]];
            [args addObject:sql_value(a, v)];
        }
        NSMutableArray *pks = [NSMutableArray array];
        for (NSManagedObjectID *i in ids) [pks addObject:@(i._cd_pk)];
        if (![self _exec:@"BEGIN IMMEDIATE" error:error]) return nil;
        BOOL ok = !pks.count || [self _run:[NSString stringWithFormat:@"UPDATE %@ SET %@ WHERE Z_PK IN (%@)", e._cd_table, [sets componentsJoinedByString:@", "], [pks componentsJoinedByString:@", "]] args:args error:error];
        [self _exec:ok ? @"COMMIT" : @"ROLLBACK" error:NULL];
        if (!ok) return nil;
        id result = req.resultType == NSUpdatedObjectIDsResultType ? ids : req.resultType == NSUpdatedObjectsCountResultType ? @(ids.count) : @YES;
        return [[NSBatchUpdateResult alloc] _cd_initWithResult:result type:req.resultType];
    }
    if (error) *error = CDError(NSPersistentStoreUnsupportedRequestTypeError, @"Unsupported request type", nil);
    return nil;
}

/* ---------------- predicates and sort descriptors -> SQL ---------------- */
static BOOL ascii_only(NSString *s) { for (NSUInteger i = 0; i < s.length; i++) if ([s characterAtIndex:i] > 127) return NO; return YES; }
typedef struct { NSString *col; NSAttributeDescription *attr; BOOL objectRef; } cd_col;
static BOOL column_for(NSExpression *e, NSEntityDescription *entity, cd_col *out) {
    if (e.expressionType == NSEvaluatedObjectExpressionType) { out->col = @"Z_PK"; out->attr = nil; out->objectRef = YES; return YES; }
    if (e.expressionType != NSKeyPathExpressionType) return NO;
    NSString *kp = e.keyPath;
    if ([kp isEqualToString:@"self"] || [kp isEqualToString:@"SELF"]) { out->col = @"Z_PK"; out->attr = nil; out->objectRef = YES; return YES; }
    if ([kp rangeOfString:@"."].location != NSNotFound || [kp hasPrefix:@"@"]) return NO;
    NSPropertyDescription *p = entity.propertiesByName[kp];
    if (!p || p.transient) return NO;
    if ([p isKindOfClass:[NSAttributeDescription class]]) {
        NSAttributeDescription *a = (NSAttributeDescription *)p;
        if (a.attributeType == NSTransformableAttributeType || a.attributeType == NSUndefinedAttributeType || a.attributeType == NSObjectIDAttributeType) return NO;
        out->col = a._cd_column; out->attr = a; out->objectRef = NO; return YES;
    }
    if ([p isKindOfClass:[NSRelationshipDescription class]] && !((NSRelationshipDescription *)p).toMany) { out->col = p._cd_column; out->attr = nil; out->objectRef = YES; return YES; }
    return NO;
}
/* constant -> SQL argument for a column, or nil when it cannot be expressed */
static id sql_const(id v, cd_col c) {
    if (c.objectRef) {
        if ([v isKindOfClass:[NSManagedObject class]]) v = [v objectID];
        if (![v isKindOfClass:[NSManagedObjectID class]]) return nil;
        return [v isTemporaryID] ? @(-1) : @([v _cd_pk]);
    }
    switch (c.attr.attributeType) {
    case NSInteger16AttributeType: case NSInteger32AttributeType: case NSInteger64AttributeType: case NSBooleanAttributeType:
    case NSDoubleAttributeType: case NSFloatAttributeType: case NSDecimalAttributeType:
        return [v isKindOfClass:[NSNumber class]] ? v : nil;
    case NSStringAttributeType: return [v isKindOfClass:[NSString class]] ? v : nil;
    case NSDateAttributeType: return [v isKindOfClass:[NSDate class]] ? @([v timeIntervalSinceReferenceDate]) : nil;
    case NSUUIDAttributeType: if ([v isKindOfClass:[NSUUID class]]) { uuid_t b; [v getUUIDBytes:b]; return [NSData dataWithBytes:b length:16]; } return nil;
    case NSURIAttributeType: return [v isKindOfClass:[NSURL class]] ? [v absoluteString] : nil;
    case NSBinaryDataAttributeType: return [v isKindOfClass:[NSData class]] ? v : nil;
    default: return nil;
    }
}
static NSString *cmp_sql(NSComparisonPredicate *p, NSEntityDescription *entity, NSMutableArray *args) {
    if (p.comparisonPredicateModifier != NSDirectPredicateModifier) return nil;
    if (p.options & ~NSCaseInsensitivePredicateOption) return nil;
    BOOL ci = (p.options & NSCaseInsensitivePredicateOption) != 0;
    NSExpression *l = p.leftExpression, *r = p.rightExpression;
    NSPredicateOperatorType op = p.predicateOperatorType;
    cd_col c;
    if (!column_for(l, entity, &c)) {
        if (r.expressionType == NSConstantValueExpressionType || !column_for(r, entity, &c)) return nil;
        if (l.expressionType != NSConstantValueExpressionType) return nil;
        switch (op) {                                             /* constant OP key  ->  key OP' constant */
        case NSLessThanPredicateOperatorType: op = NSGreaterThanPredicateOperatorType; break;
        case NSLessThanOrEqualToPredicateOperatorType: op = NSGreaterThanOrEqualToPredicateOperatorType; break;
        case NSGreaterThanPredicateOperatorType: op = NSLessThanPredicateOperatorType; break;
        case NSGreaterThanOrEqualToPredicateOperatorType: op = NSLessThanOrEqualToPredicateOperatorType; break;
        case NSEqualToPredicateOperatorType: case NSNotEqualToPredicateOperatorType: break;
        default: return nil;
        }
        NSExpression *t = l; l = r; r = t;
    }
    id k;
    if (r.expressionType == NSConstantValueExpressionType) k = r.constantValue;
    else if (r.expressionType == NSAggregateExpressionType) { NSMutableArray *a = [NSMutableArray array]; for (NSExpression *x in r.collection) { if (x.expressionType != NSConstantValueExpressionType) return nil; [a addObject:x.constantValue ?: [NSNull null]]; } k = a; }
    else return nil;
    if (k == [NSNull null]) k = nil;
    BOOL isString = c.attr.attributeType == NSStringAttributeType;
    if (ci && (!isString || ([k isKindOfClass:[NSString class]] && !ascii_only(k)))) return nil;
    NSString *col = ci ? [NSString stringWithFormat:@"lower(%@)", c.col] : c.col;
    id (^conv)(id) = ^id(id v) { id s = sql_const(v, c); if (ci && [s isKindOfClass:[NSString class]]) s = [s lowercaseString]; return s; };
    switch (op) {
    case NSEqualToPredicateOperatorType: case NSNotEqualToPredicateOperatorType: {
        BOOL eq = op == NSEqualToPredicateOperatorType;
        if (!k) return [NSString stringWithFormat:@"%@ IS %@NULL", c.col, eq ? @"" : @"NOT "];
        id v = conv(k);
        if (!v) return nil;
        [args addObject:v];
        return eq ? [NSString stringWithFormat:@"%@ = ?", col] : [NSString stringWithFormat:@"(%@ <> ? OR %@ IS NULL)", col, c.col];
    }
    case NSLessThanPredicateOperatorType: case NSLessThanOrEqualToPredicateOperatorType:
    case NSGreaterThanPredicateOperatorType: case NSGreaterThanOrEqualToPredicateOperatorType: {
        if (c.objectRef || !k) return nil;
        id v = conv(k);
        if (!v || [v isKindOfClass:[NSData class]]) return nil;
        [args addObject:v];
        NSString *o = op == NSLessThanPredicateOperatorType ? @"<" : op == NSLessThanOrEqualToPredicateOperatorType ? @"<=" : op == NSGreaterThanPredicateOperatorType ? @">" : @">=";
        return [NSString stringWithFormat:@"%@ %@ ?", col, o];
    }
    case NSInPredicateOperatorType: {
        if (![k isKindOfClass:[NSArray class]] && ![k isKindOfClass:[NSSet class]] && ![k isKindOfClass:[NSOrderedSet class]]) return nil;
        NSArray *items = CDToManyArray(k);
        if (!items.count) return @"0";
        NSMutableArray *qs = [NSMutableArray array], *vals = [NSMutableArray array];
        for (id x in items) { id v = conv(x); if (!v) return nil; [vals addObject:v]; [qs addObject:@"?"]; }
        [args addObjectsFromArray:vals];
        return [NSString stringWithFormat:@"%@ IN (%@)", col, [qs componentsJoinedByString:@", "]];
    }
    case NSBetweenPredicateOperatorType: {
        NSArray *b = CDToManyArray(k);
        if (b.count != 2 || c.objectRef) return nil;
        id lo = conv(b[0]), hi = conv(b[1]);
        if (!lo || !hi) return nil;
        [args addObject:lo]; [args addObject:hi];
        return [NSString stringWithFormat:@"%@ BETWEEN ? AND ?", col];
    }
    case NSBeginsWithPredicateOperatorType: case NSEndsWithPredicateOperatorType: case NSContainsPredicateOperatorType: case NSLikePredicateOperatorType: {
        if (!isString || ![k isKindOfClass:[NSString class]] || ![k length]) return nil;
        NSString *v = conv(k);
        if (op == NSBeginsWithPredicateOperatorType) { [args addObject:v]; return [NSString stringWithFormat:@"instr(%@, ?) = 1", col]; }
        if (op == NSContainsPredicateOperatorType) { [args addObject:v]; return [NSString stringWithFormat:@"instr(%@, ?) > 0", col]; }
        if (op == NSEndsWithPredicateOperatorType) { [args addObject:v]; [args addObject:v]; return [NSString stringWithFormat:@"substr(%@, -length(?)) = ?", col]; }
        if ([v rangeOfString:@"["].location != NSNotFound || [v rangeOfString:@"\\"].location != NSNotFound) return nil;
        [args addObject:v];
        return [NSString stringWithFormat:@"%@ GLOB ?", col];
    }
    default: return nil;
    }
}
static NSString *pred_sql(NSPredicate *p, NSEntityDescription *entity, NSMutableArray *args, BOOL *exact) {
    if ([p isKindOfClass:[NSCompoundPredicate class]]) {
        NSCompoundPredicate *cp = (NSCompoundPredicate *)p;
        NSMutableArray *parts = [NSMutableArray array];
        if (cp.compoundPredicateType == NSAndPredicateType) {
            for (NSPredicate *s in cp.subpredicates) {
                NSMutableArray *a = [NSMutableArray array]; BOOL ex = YES;
                NSString *q = pred_sql(s, entity, a, &ex);
                if (!ex) *exact = NO;
                if (q) { [parts addObject:[NSString stringWithFormat:@"(%@)", q]]; [args addObjectsFromArray:a]; }
            }
            return parts.count ? [parts componentsJoinedByString:@" AND "] : nil;
        }
        NSMutableArray *all = [NSMutableArray array];
        for (NSPredicate *s in cp.subpredicates) {
            BOOL ex = YES;
            NSString *q = pred_sql(s, entity, all, &ex);
            if (!q || !ex) { *exact = NO; return nil; }
            [parts addObject:[NSString stringWithFormat:@"(%@)", q]];
        }
        if (cp.compoundPredicateType == NSNotPredicateType) {
            if (parts.count != 1) { *exact = NO; return nil; }
            [args addObjectsFromArray:all];
            return [NSString stringWithFormat:@"NOT %@", parts[0]];
        }
        [args addObjectsFromArray:all];
        return parts.count ? [parts componentsJoinedByString:@" OR "] : @"0";
    }
    if ([p isKindOfClass:[NSComparisonPredicate class]]) {
        NSMutableArray *a = [NSMutableArray array];
        NSString *q = cmp_sql((NSComparisonPredicate *)p, entity, a);
        if (!q) { *exact = NO; return nil; }
        [args addObjectsFromArray:a];
        return q;
    }
    NSString *f = p.predicateFormat;
    if ([f isEqualToString:@"TRUEPREDICATE"]) return @"1";
    if ([f isEqualToString:@"FALSEPREDICATE"]) return @"0";
    *exact = NO;
    return nil;
}
- (NSString *)_cd_sqlForPredicate:(NSPredicate *)predicate entity:(NSEntityDescription *)entity args:(NSMutableArray *)args exact:(BOOL *)exact {
    BOOL ex = YES;
    NSString *s = pred_sql(predicate, entity, args, &ex);
    if (exact) *exact = ex;
    return s;
}
- (NSString *)_cd_sqlForSortDescriptors:(NSArray<NSSortDescriptor *> *)sorts entity:(NSEntityDescription *)entity {
    NSMutableArray *parts = [NSMutableArray array];
    for (NSSortDescriptor *sd in sorts) {
        if (sd.selector != @selector(compare:) || !sd.key) return nil;
        NSAttributeDescription *a = entity.attributesByName[sd.key];
        if (!a || a.transient || a.attributeType == NSTransformableAttributeType || a.attributeType == NSBinaryDataAttributeType || a.attributeType == NSURIAttributeType) return nil;
        [parts addObject:[NSString stringWithFormat:@"%@ %@", a._cd_column, sd.ascending ? @"ASC" : @"DESC"]];
    }
    return [parts componentsJoinedByString:@", "];
}
@end
