#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class NSManagedObjectModel, NSManagedObjectContext, NSManagedObject, NSEntityDescription, NSEntityMapping, NSPersistentContainer,
       NSMigrationManager, NSStagedMigrationManager;

typedef NS_ENUM(NSUInteger, NSEntityMappingType) {
    NSUndefinedEntityMappingType = 0x00,
    NSCustomEntityMappingType = 0x01,
    NSAddEntityMappingType = 0x02,
    NSRemoveEntityMappingType = 0x03,
    NSCopyEntityMappingType = 0x04,
    NSTransformEntityMappingType = 0x05,
};

/* the variables a property mapping's value expression sees */
COREDATA_EXTERN NSString * const NSMigrationManagerKey;
COREDATA_EXTERN NSString * const NSMigrationSourceObjectKey;
COREDATA_EXTERN NSString * const NSMigrationDestinationObjectKey;
COREDATA_EXTERN NSString * const NSMigrationEntityMappingKey;
COREDATA_EXTERN NSString * const NSMigrationPropertyMappingKey;
COREDATA_EXTERN NSString * const NSMigrationEntityPolicyKey;

@interface NSPropertyMapping : NSObject
@property (nullable, copy) NSString *name;
@property (nullable, strong) NSExpression *valueExpression;
@property (nullable, strong) NSDictionary *userInfo;
@end

@interface NSEntityMapping : NSObject
@property (null_resettable, copy) NSString *name;
@property NSEntityMappingType mappingType;
@property (nullable, copy) NSString *sourceEntityName;
@property (nullable, copy) NSData *sourceEntityVersionHash;
@property (nullable, copy) NSString *destinationEntityName;
@property (nullable, copy) NSData *destinationEntityVersionHash;
@property (nullable, strong) NSArray<NSPropertyMapping *> *attributeMappings;
@property (nullable, strong) NSArray<NSPropertyMapping *> *relationshipMappings;
@property (nullable, strong) NSExpression *sourceExpression;
@property (nullable, strong) NSDictionary *userInfo;
@property (nullable, copy) NSString *entityMigrationPolicyClassName;
@end

@interface NSMappingModel : NSObject
+ (nullable NSMappingModel *)mappingModelFromBundles:(nullable NSArray<NSBundle *> *)bundles forSourceModel:(nullable NSManagedObjectModel *)sourceModel destinationModel:(nullable NSManagedObjectModel *)destinationModel NS_SWIFT_NAME(init(from:forSourceModel:destinationModel:));
+ (nullable NSMappingModel *)inferredMappingModelForSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel error:(NSError **)error;
- (nullable instancetype)initWithContentsOfURL:(nullable NSURL *)url;
@property (null_resettable, strong) NSArray<NSEntityMapping *> *entityMappings;
@property (readonly, copy) NSDictionary<NSString *, NSEntityMapping *> *entityMappingsByName;
@end

/* How one entity mapping migrates: subclass and name it in entityMigrationPolicyClassName. */
@interface NSEntityMigrationPolicy : NSObject
- (BOOL)beginEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(begin(_:with:));
- (BOOL)createDestinationInstancesForSourceInstance:(NSManagedObject *)sInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(createDestinationInstances(forSource:in:manager:));
- (BOOL)endInstanceCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(endInstanceCreation(forMapping:manager:));
- (BOOL)createRelationshipsForDestinationInstance:(NSManagedObject *)dInstance entityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(createRelationships(forDestination:in:manager:));
- (BOOL)endRelationshipCreationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(endRelationshipCreation(forMapping:manager:));
- (BOOL)performCustomValidationForEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(performCustomValidation(forMapping:manager:));
- (BOOL)endEntityMapping:(NSEntityMapping *)mapping manager:(NSMigrationManager *)manager error:(NSError **)error NS_SWIFT_NAME(end(_:manager:));
@end

@interface NSMigrationManager : NSObject
- (instancetype)initWithSourceModel:(NSManagedObjectModel *)sourceModel destinationModel:(NSManagedObjectModel *)destinationModel NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)migrateStoreFromURL:(NSURL *)sourceURL type:(NSString *)sStoreType options:(nullable NSDictionary *)sOptions withMappingModel:(nullable NSMappingModel *)mappings toDestinationURL:(NSURL *)dURL destinationType:(NSString *)dStoreType destinationOptions:(nullable NSDictionary *)dOptions error:(NSError **)error NS_SWIFT_NAME(migrateStore(from:sourceType:options:with:toDestinationURL:destinationType:destinationOptions:));
@property BOOL usesStoreSpecificMigrationManager;
- (void)reset;
@property (readonly, strong) NSMappingModel *mappingModel;
@property (readonly, strong) NSManagedObjectModel *sourceModel;
@property (readonly, strong) NSManagedObjectModel *destinationModel;
@property (readonly, strong) NSManagedObjectContext *sourceContext;
@property (readonly, strong) NSManagedObjectContext *destinationContext;
- (nullable NSEntityDescription *)sourceEntityForEntityMapping:(NSEntityMapping *)mEntity NS_SWIFT_NAME(sourceEntity(for:));
- (nullable NSEntityDescription *)destinationEntityForEntityMapping:(NSEntityMapping *)mEntity NS_SWIFT_NAME(destinationEntity(for:));
- (void)associateSourceInstance:(NSManagedObject *)sourceInstance withDestinationInstance:(NSManagedObject *)destinationInstance forEntityMapping:(NSEntityMapping *)entityMapping NS_SWIFT_NAME(associate(sourceInstance:withDestinationInstance:for:));
- (NSArray<__kindof NSManagedObject *> *)destinationInstancesForEntityMappingNamed:(NSString *)mappingName sourceInstances:(nullable NSArray<__kindof NSManagedObject *> *)sourceInstances NS_SWIFT_NAME(destinationInstances(forEntityMappingName:sourceInstances:));
- (NSArray<__kindof NSManagedObject *> *)sourceInstancesForEntityMappingNamed:(NSString *)mappingName destinationInstances:(nullable NSArray<__kindof NSManagedObject *> *)destinationInstances NS_SWIFT_NAME(sourceInstances(forEntityMappingName:destinationInstances:));
@property (readonly, strong) NSEntityMapping *currentEntityMapping;
@property (readonly) float migrationProgress;
@property (nullable, strong) NSDictionary *userInfo;
- (void)cancelMigrationWithError:(NSError *)error NS_SWIFT_NAME(cancelMigrationWithError(_:));
@end

/* staged migration (iOS 17) */
@interface NSManagedObjectModelReference : NSObject
- (instancetype)initWithModel:(NSManagedObjectModel *)model versionChecksum:(NSString *)versionChecksum;
- (instancetype)initWithFileURL:(NSURL *)fileURL versionChecksum:(NSString *)versionChecksum;
- (instancetype)initWithEntityVersionHashes:(NSDictionary *)versionHash inBundle:(nullable NSBundle *)bundle versionChecksum:(NSString *)versionChecksum NS_SWIFT_NAME(init(entityVersionHashes:in:versionChecksum:));
- (instancetype)initWithName:(NSString *)modelName inBundle:(nullable NSBundle *)bundle versionChecksum:(NSString *)versionChecksum NS_SWIFT_NAME(init(name:in:versionChecksum:));
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, strong) NSManagedObjectModel *resolvedModel;
@property (readonly, copy) NSString *versionChecksum;
@end

@interface NSMigrationStage : NSObject
@property (nullable, copy) NSString *label;
@end
@interface NSLightweightMigrationStage : NSMigrationStage
- (instancetype)initWithVersionChecksums:(NSArray<NSString *> *)versionChecksums NS_SWIFT_NAME(init(_:));
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, copy) NSArray<NSString *> *versionChecksums;
@end
@interface NSCustomMigrationStage : NSMigrationStage
- (instancetype)initWithCurrentModelReference:(NSManagedObjectModelReference *)currentModel nextModelReference:(NSManagedObjectModelReference *)nextModel NS_SWIFT_NAME(init(migratingFrom:to:));
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, strong) NSManagedObjectModelReference *currentModel;
@property (readonly, strong) NSManagedObjectModelReference *nextModel;
@property (nullable, copy) BOOL (^willMigrateHandler)(NSStagedMigrationManager *migrationManager, NSCustomMigrationStage *migrationStage, NSError **error) NS_REFINED_FOR_SWIFT;
@property (nullable, copy) BOOL (^didMigrateHandler)(NSStagedMigrationManager *migrationManager, NSCustomMigrationStage *migrationStage, NSError **error) NS_REFINED_FOR_SWIFT;
@end
@interface NSStagedMigrationManager : NSObject
- (instancetype)initWithMigrationStages:(NSArray<NSMigrationStage *> *)stages NS_SWIFT_NAME(init(_:));
- (instancetype)init NS_UNAVAILABLE;
@property (readonly, copy) NSArray<NSMigrationStage *> *stages;
@property (nullable, readonly, strong) NSPersistentContainer *container;
@end
NS_ASSUME_NONNULL_END
