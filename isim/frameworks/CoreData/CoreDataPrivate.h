/* isim Core Data: internal interfaces shared by the framework's files. */
#pragma once
#import <CoreData/CoreData.h>
#include <sqlite3.h>

#define CD_LOG(...) NSLog(@"CoreData: " __VA_ARGS__)
NSError *CDError(NSInteger code, NSString *message, NSDictionary *extra);

/* ---------------- model ---------------- */
NSString *CDAttributeTypeName(NSAttributeType t);
NSAttributeType CDAttributeTypeFromName(NSString *name);
NSString *CDDeleteRuleName(NSDeleteRule r);
NSEntityDescription *CDEntityForClass(Class cls);          /* registered by coordinators / models in use */
void CDRegisterModel(NSManagedObjectModel *model);
Class CDClassNamed(NSString *name);                         /* ObjC name, Module.Class, .Class (main module) */

@interface NSManagedObjectModel (CDPrivate)
+ (instancetype)_cd_modelWithPlist:(NSDictionary *)plist error:(NSError **)error;
- (void)_cd_link;                                           /* resolve names, inverses, inheritance */
- (NSDictionary *)_cd_schema;                               /* what the SQLite layout depends on (store metadata) */
@end

@interface NSEntityDescription (CDPrivate)
- (void)_cd_setModel:(NSManagedObjectModel *)model;
- (void)_cd_setSuperentity:(NSEntityDescription *)entity;
- (NSEntityDescription *)_cd_root;
- (NSArray<NSEntityDescription *> *)_cd_family;             /* self + subentities, recursively */
- (Class)_cd_objectClass;
- (NSString *)_cd_table;
@property (nonatomic, copy) NSString *_cd_parentName;
@property (nonatomic, copy) NSString *_cd_codeGenerationType;
@end

@interface NSPropertyDescription (CDPrivate)
- (void)_cd_setEntity:(NSEntityDescription *)entity;
- (NSString *)_cd_column;
@end

@interface NSAttributeDescription (CDPrivate)
@property (nonatomic, copy) NSString *_cd_minValue, *_cd_maxValue, *_cd_regex;
- (id)_cd_valueFromData:(NSData *)data;                      /* Transformable */
- (NSData *)_cd_dataFromValue:(id)value;
@end

@interface NSRelationshipDescription (CDPrivate)
@property (nonatomic, copy) NSString *_cd_destinationName, *_cd_inverseName;
- (BOOL)_cd_usesJoinTable;                                  /* to-many that is ordered, inverse-less or many-to-many */
- (NSRelationshipDescription *)_cd_joinOwner;               /* the side whose join table holds the rows */
- (NSString *)_cd_joinTable;
- (NSString *)_cd_entColumn;                                /* to-one: column with the destination's entity number */
@end

/* ---------------- object IDs ---------------- */
@interface NSManagedObjectID (CDPrivate)
+ (instancetype)_cd_idWithEntity:(NSEntityDescription *)entity store:(NSPersistentStore *)store pk:(int64_t)pk;
+ (instancetype)_cd_temporaryIDWithEntity:(NSEntityDescription *)entity;
@property (readonly) int64_t _cd_pk;
@end

/* a row as exchanged between a store (or parent context) and a context: attribute values (NSNull for nil),
 * to-one relationships as NSManagedObjectID / NSNull, to-many as NSArray of IDs or absent (loaded lazily) */
@interface CDSnapshot : NSObject
@property (strong) NSManagedObjectID *objectID;
@property (strong) NSMutableDictionary<NSString *, id> *values;
@property int64_t version;
@end

/* ---------------- managed objects ---------------- */
@interface NSManagedObject (CDPrivate)
- (instancetype)_cd_initFaultWithEntity:(NSEntityDescription *)entity __attribute__((objc_method_family(init)));
- (void)_cd_setContext:(NSManagedObjectContext *)context;
- (void)_cd_setObjectID:(NSManagedObjectID *)objectID;
- (BOOL)_cd_isFault;
- (void)_cd_fire;
- (void)_cd_applySnapshot:(CDSnapshot *)snapshot;           /* values + committed snapshot; not a fault any more */
- (void)_cd_mergeSnapshot:(CDSnapshot *)snapshot keepChanges:(BOOL)keep;
- (void)_cd_turnIntoFault;
- (void)_cd_commit;                                         /* after a save: committed := current */
- (void)_cd_resetToCommitted;                               /* rollback */
- (NSMutableDictionary *)_cd_values;
- (NSDictionary *)_cd_committed;
- (NSArray<NSString *> *)_cd_changedKeys;
@property int64_t _cd_version;
- (id)_cd_raw:(NSString *)key;                              /* current value; loads lazy relationships; nil for NSNull */
- (void)_cd_setRaw:(id)value forKey:(NSString *)key;         /* no tracking */
- (void)_cd_setTracked:(id)value forKey:(NSString *)key;     /* KVO + change tracking, no inverse maintenance */
- (BOOL)_cd_validateAll:(NSError **)error;
- (void)_cd_setToMany:(NSArray *)members relationship:(NSRelationshipDescription *)r;
- (void)_cd_relationship:(NSRelationshipDescription *)r add:(NSArray *)objects remove:(NSArray *)objects;
- (void)_cd_setToOne:(NSManagedObject *)value relationship:(NSRelationshipDescription *)r;
- (CDSnapshot *)_cd_snapshotForChild;                       /* current values as IDs (to-many only when loaded) */
- (NSMutableSet *)_cd_changedKeysSinceEvent;
@end
NSArray *CDToManyArray(id value);                           /* NSSet / NSOrderedSet / NSArray -> NSArray */

/* ---------------- stores ---------------- */
@interface CDSQLStore : NSPersistentStore
- (void)_cd_setType:(NSString *)type;
- (BOOL)_cd_openWithModel:(NSManagedObjectModel *)model options:(NSDictionary *)options error:(NSError **)error;
- (void)_cd_close;
- (int)_cd_entityNumber:(NSEntityDescription *)entity;
- (NSEntityDescription *)_cd_entityForNumber:(int)n;
- (NSArray<CDSnapshot *> *)_cd_rowsForEntities:(NSArray<NSEntityDescription *> *)family where:(NSString *)where args:(NSArray *)args
                                        order:(NSString *)order limit:(NSUInteger)limit offset:(NSUInteger)offset;
- (NSUInteger)_cd_countForEntities:(NSArray<NSEntityDescription *> *)family where:(NSString *)where args:(NSArray *)args;
- (CDSnapshot *)_cd_rowForObjectID:(NSManagedObjectID *)oid;
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDs:(NSManagedObjectID *)oid relationship:(NSRelationshipDescription *)r;
- (NSArray<NSManagedObjectID *> *)_cd_permanentIDsForEntities:(NSArray<NSEntityDescription *> *)entities error:(NSError **)error;
/* one transaction; conflicts (version changed in the store) are resolved with the merge policy */
- (BOOL)_cd_saveInserted:(NSArray<NSManagedObject *> *)inserted updated:(NSArray<NSManagedObject *> *)updated
                 deleted:(NSArray<NSManagedObject *> *)deleted mergePolicy:(NSMergePolicy *)policy error:(NSError **)error;
- (id)_cd_executeBatch:(NSPersistentStoreRequest *)request context:(NSManagedObjectContext *)context error:(NSError **)error;
/* predicate -> SQL (superset); *exact = NO when part of it must be checked in memory */
- (NSString *)_cd_sqlForPredicate:(NSPredicate *)predicate entity:(NSEntityDescription *)entity args:(NSMutableArray *)args exact:(BOOL *)exact;
- (NSString *)_cd_sqlForSortDescriptors:(NSArray<NSSortDescriptor *> *)sorts entity:(NSEntityDescription *)entity;
@end

@interface NSPersistentStoreDescription (CDPrivate)
- (NSDictionary *)_cd_storeOptions;
@end

/* ---------------- coordinator ---------------- */
@interface NSPersistentStoreCoordinator (CDPrivate)
- (NSArray<CDSQLStore *> *)_cd_stores;
- (CDSQLStore *)_cd_storeForEntity:(NSEntityDescription *)entity;
- (void)_cd_registerContext:(NSManagedObjectContext *)context;
- (void)_cd_rootContext:(NSManagedObjectContext *)context didSave:(NSDictionary *)idChanges;
@end

/* ---------------- contexts ---------------- */
@interface NSManagedObjectContext (CDPrivate)
- (void)_cd_registerObject:(NSManagedObject *)object;
- (void)_cd_objectDidChange:(NSManagedObject *)object;
- (NSManagedObject *)_cd_objectForSnapshot:(CDSnapshot *)snapshot;
- (CDSnapshot *)_cd_snapshotForObjectID:(NSManagedObjectID *)oid;
- (NSArray<NSManagedObjectID *> *)_cd_relatedIDs:(NSManagedObject *)object relationship:(NSRelationshipDescription *)r;
- (BOOL)_cd_isInserted:(NSManagedObject *)o;
- (BOOL)_cd_isUpdated:(NSManagedObject *)o;
- (BOOL)_cd_isDeleted:(NSManagedObject *)o;
- (NSArray *)_cd_executeFetch:(NSFetchRequest *)request error:(NSError **)error;
- (NSUInteger)_cd_count:(NSFetchRequest *)request error:(NSError **)error;
- (NSEntityDescription *)_cd_entityNamed:(NSString *)name;
- (void)_cd_mergeIDChanges:(NSDictionary *)idChanges;
- (void)_cd_registerChild:(NSManagedObjectContext *)child;
+ (NSManagedObjectContext *)_cd_current;                     /* the context whose perform block is running */
@end

/* ---------------- fetch requests ---------------- */
@interface NSFetchRequest (CDPrivate)
- (NSEntityDescription *)_cd_entityInContext:(NSManagedObjectContext *)context;
@end
@interface NSBatchDeleteRequest (CDPrivate)
@property (readonly) NSArray<NSManagedObjectID *> *_cd_objectIDs;
@end
@interface NSBatchDeleteResult (CDPrivate)
- (instancetype)_cd_initWithResult:(id)result type:(NSBatchDeleteRequestResultType)type __attribute__((objc_method_family(init)));
@end
@interface NSBatchUpdateResult (CDPrivate)
- (instancetype)_cd_initWithResult:(id)result type:(NSBatchUpdateRequestResultType)type __attribute__((objc_method_family(init)));
@end
