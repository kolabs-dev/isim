#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObjectModel, NSManagedObjectContext, NSEntityMapping, NSPersistentContainer;

@interface NSEntityMapping : NSObject
@property (nullable, copy) NSString *name;
@property (nullable, copy) NSString *sourceEntityName;
@property (nullable, copy) NSString *destinationEntityName;
@end
@interface NSMappingModel : NSObject
+ (nullable NSMappingModel *)mappingModelFromBundles:(nullable NSArray<NSBundle *> *)bundles forSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel;
+ (nullable NSMappingModel *)inferredMappingModelForSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel error:(NSError **)error;
@property (strong) NSArray<NSEntityMapping *> *entityMappings;
@end
@interface NSMigrationManager : NSObject
- (instancetype)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, strong) NSManagedObjectModel *sourceModel;
@property (readonly, strong) NSManagedObjectModel *destinationModel;
@property (nullable, readonly, strong) NSMappingModel *mappingModel;
@property (readonly) float migrationProgress;
@property (readonly, strong) NSMutableDictionary *userInfo;
- (BOOL)migrateStoreFromURL:(NSURL *)sourceURL type:(NSString *)sStoreType options:(nullable NSDictionary *)sOptions withMappingModel:(NSMappingModel *)mappings toDestinationURL:(NSURL *)dURL destinationType:(NSString *)dStoreType destinationOptions:(nullable NSDictionary *)dOptions error:(NSError **)error;
- (void)cancelMigrationWithError:(NSError *)error;
@end

@interface NSMigrationStage : NSObject
@property (copy) NSString *label;
@end
@interface NSLightweightMigrationStage : NSMigrationStage
- (instancetype)initWithVersionChecksum:(NSString *)versionChecksum;
@property (readonly, copy) NSString *versionChecksum;
@end
@interface NSCustomMigrationStage : NSMigrationStage
- (instancetype)initMigratingFromVersion:(NSString *)currentModelChecksum toVersion:(NSString *)nextModelChecksum;
@property (readonly, copy) NSString *currentModelChecksum;
@property (readonly, copy) NSString *nextModelChecksum;
@property (nullable, copy) void (^willMigrateHandler)(NSMigrationManager *, NSError **);
@property (nullable, copy) void (^didMigrateHandler)(NSMigrationManager *, NSError **);
@end
@interface NSStagedMigrationManager : NSObject
- (instancetype)initWithMigrationStages:(NSArray<NSMigrationStage *> *)stages;
@property (copy, readonly) NSArray<NSMigrationStage *> *stages;
@property (nullable, strong) NSPersistentContainer *container;
@end
NS_ASSUME_NONNULL_END
