#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObjectModel, NSManagedObjectID, NSManagedObjectContext, NSPersistentStoreRequest, NSPersistentStoreCoordinator;

/// isim: NSSQLiteStoreType (the host's SQLite, isim's own table layout) and NSInMemoryStoreType (an in-memory
/// SQLite database; a SQLite store at /dev/null is in memory too).
@interface NSPersistentStore : NSObject
+ (nullable NSDictionary<NSString *, id> *)metadataForPersistentStoreWithURL:(NSURL *)url error:(NSError **)error;
- (instancetype)initWithPersistentStoreCoordinator:(nullable NSPersistentStoreCoordinator *)root configurationName:(nullable NSString *)name URL:(NSURL *)url options:(nullable NSDictionary *)options NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)loadMetadata:(NSError **)error;
@property (nullable, readonly, weak) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, copy) NSString *configurationName;
@property (nullable, readonly, strong) NSDictionary *options;
@property (nullable, strong) NSURL *URL;
@property (copy) NSString *identifier;
@property (readonly, copy) NSString *type;
@property (getter=isReadOnly) BOOL readOnly;
@property (null_resettable, strong) NSDictionary<NSString *, id> *metadata;
- (void)didAddToPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)coordinator;
- (void)willRemoveFromPersistentStoreCoordinator:(nullable NSPersistentStoreCoordinator *)coordinator;
@end

@interface NSPersistentStoreDescription : NSObject <NSCopying>
+ (instancetype)persistentStoreDescriptionWithURL:(NSURL *)URL;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithURL:(NSURL *)url;
@property (copy) NSString *type;
@property (nullable, copy) NSString *configuration;
@property (nullable, copy) NSURL *URL;
@property (nonatomic, readonly) NSDictionary<NSString *, NSObject *> *options;
- (void)setOption:(nullable NSObject *)option forKey:(NSString *)key;
@property (getter=isReadOnly) BOOL readOnly;
@property NSTimeInterval timeout;
@property (nonatomic, readonly) NSDictionary<NSString *, NSObject *> *sqlitePragmas;
- (void)setValue:(nullable NSObject *)value forPragmaNamed:(NSString *)name;
@property BOOL shouldAddStoreAsynchronously;
@property BOOL shouldMigrateStoreAutomatically;
@property BOOL shouldInferMappingModelAutomatically;
@end

@interface NSPersistentStoreCoordinator : NSObject <NSLocking>
- (instancetype)initWithManagedObjectModel:(NSManagedObjectModel *)model NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, strong) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong) NSArray<__kindof NSPersistentStore *> *persistentStores;
@property (nullable, copy) NSString *name;
- (nullable __kindof NSPersistentStore *)persistentStoreForURL:(NSURL *)URL;
- (NSURL *)URLForPersistentStore:(NSPersistentStore *)store;
- (BOOL)setURL:(NSURL *)url forPersistentStore:(NSPersistentStore *)store;
- (nullable __kindof NSPersistentStore *)addPersistentStoreWithType:(NSString *)storeType configuration:(nullable NSString *)configuration URL:(nullable NSURL *)storeURL options:(nullable NSDictionary *)options error:(NSError **)error NS_SWIFT_NAME(addPersistentStore(ofType:configurationName:at:options:));
- (void)addPersistentStoreWithDescription:(NSPersistentStoreDescription *)storeDescription completionHandler:(void (^)(NSPersistentStoreDescription *, NSError * _Nullable))block NS_SWIFT_NAME(addPersistentStore(with:completionHandler:));
- (BOOL)removePersistentStore:(NSPersistentStore *)store error:(NSError **)error NS_SWIFT_NAME(remove(_:));
- (void)setMetadata:(nullable NSDictionary<NSString *, id> *)metadata forPersistentStore:(NSPersistentStore *)store;
- (NSDictionary<NSString *, id> *)metadataForPersistentStore:(NSPersistentStore *)store;
- (nullable NSManagedObjectID *)managedObjectIDForURIRepresentation:(NSURL *)url NS_SWIFT_NAME(managedObjectID(forURIRepresentation:));
- (nullable id)executeRequest:(NSPersistentStoreRequest *)request withContext:(NSManagedObjectContext *)context error:(NSError **)error NS_SWIFT_NAME(execute(_:with:));
+ (nullable NSDictionary<NSString *, id> *)metadataForPersistentStoreOfType:(NSString *)storeType URL:(NSURL *)url options:(nullable NSDictionary *)options error:(NSError **)error;
- (BOOL)destroyPersistentStoreAtURL:(NSURL *)url withType:(NSString *)storeType options:(nullable NSDictionary *)options error:(NSError **)error NS_SWIFT_NAME(destroyPersistentStore(at:ofType:options:));
- (BOOL)replacePersistentStoreAtURL:(NSURL *)destinationURL destinationOptions:(nullable NSDictionary *)destinationOptions withPersistentStoreFromURL:(NSURL *)sourceURL sourceOptions:(nullable NSDictionary *)sourceOptions storeType:(NSString *)storeType error:(NSError **)error NS_SWIFT_NAME(replacePersistentStore(at:destinationOptions:withPersistentStoreFrom:sourceOptions:ofType:));
- (void)performBlock:(void (^)(void))block NS_SWIFT_NAME(perform(_:));
- (void)performBlockAndWait:(void (NS_NOESCAPE ^)(void))block NS_SWIFT_NAME(performAndWait(_:));
- (void)lock;
- (void)unlock;
- (BOOL)tryLock;
@end

/// The Core Data stack: the model named like the container (<name>.momd / .mom in the main bundle), a
/// coordinator, a main-queue viewContext and one SQLite store in Library/Application Support/<name>.sqlite.
@interface NSPersistentContainer : NSObject
+ (instancetype)persistentContainerWithName:(NSString *)name;
+ (instancetype)persistentContainerWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model;
+ (NSURL *)defaultDirectoryURL;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name managedObjectModel:(NSManagedObjectModel *)model NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (copy, readonly) NSString *name;
@property (strong, readonly) NSManagedObjectContext *viewContext;
@property (strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (copy) NSArray<NSPersistentStoreDescription *> *persistentStoreDescriptions;
- (void)loadPersistentStoresWithCompletionHandler:(void (^)(NSPersistentStoreDescription *, NSError * _Nullable))block NS_SWIFT_NAME(loadPersistentStores(completionHandler:));
- (NSManagedObjectContext *)newBackgroundContext;
- (void)performBackgroundTask:(void (^)(NSManagedObjectContext *))block;
@end

NS_ASSUME_NONNULL_END
