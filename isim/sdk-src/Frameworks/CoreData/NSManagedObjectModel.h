#pragma once
#import <Foundation/Foundation.h>
#import <CoreData/CoreDataDefines.h>
#import <CoreData/NSFetchRequest.h>
NS_ASSUME_NONNULL_BEGIN
@class NSEntityDescription, NSPropertyDescription, NSAttributeDescription, NSRelationshipDescription,
       NSManagedObjectContext, NSManagedObjectModel, NSManagedObject;

/// isim: +mergedModelFromBundles: and NSPersistentContainer read isim-compiled models (<Name>.momd with
/// JSON .mom files written by `isim build`); see docs/COREDATA.md for the format.
@interface NSManagedObjectModel : NSObject <NSCoding, NSCopying, NSFastEnumeration>
+ (nullable NSManagedObjectModel *)mergedModelFromBundles:(nullable NSArray<NSBundle *> *)bundles;
+ (nullable NSManagedObjectModel *)modelByMergingModels:(nullable NSArray<NSManagedObjectModel *> *)models;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;
@property (readonly, copy) NSDictionary<NSString *, NSEntityDescription *> *entitiesByName;
@property (strong) NSArray<NSEntityDescription *> *entities;
@property (readonly, strong) NSArray<NSString *> *configurations;
- (nullable NSArray<NSEntityDescription *> *)entitiesForConfiguration:(nullable NSString *)configuration;
- (void)setEntities:(NSArray<NSEntityDescription *> *)entities forConfiguration:(NSString *)configuration;
- (void)setFetchRequestTemplate:(nullable NSFetchRequest *)fetchRequestTemplate forName:(NSString *)name;
- (nullable NSFetchRequest *)fetchRequestTemplateForName:(NSString *)name;
- (nullable NSFetchRequest *)fetchRequestFromTemplateWithName:(NSString *)name substitutionVariables:(NSDictionary<NSString *, id> *)variables;
@property (readonly, copy) NSDictionary<NSString *, NSFetchRequest *> *fetchRequestTemplatesByName;
@property (copy) NSSet *versionIdentifiers;
@property (readonly, copy) NSDictionary<NSString *, NSData *> *entityVersionHashesByName;
@property (nullable, readonly, copy) NSString *versionChecksum;
- (BOOL)isConfiguration:(nullable NSString *)configuration compatibleWithStoreMetadata:(NSDictionary<NSString *, id> *)metadata;
@property (nullable, nonatomic, strong) NSDictionary *localizationDictionary;
@end

@interface NSEntityDescription : NSObject <NSCoding, NSCopying, NSFastEnumeration>
+ (nullable NSEntityDescription *)entityForName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context NS_SWIFT_NAME(entity(forEntityName:in:));
+ (__kindof NSManagedObject *)insertNewObjectForEntityForName:(NSString *)entityName inManagedObjectContext:(NSManagedObjectContext *)context NS_SWIFT_NAME(insertNewObject(forEntityName:into:));
@property (readonly, assign) NSManagedObjectModel *managedObjectModel;
@property (null_resettable, copy) NSString *managedObjectClassName;
@property (nullable, copy) NSString *name;
@property (getter=isAbstract) BOOL abstract;
@property (readonly, copy) NSDictionary<NSString *, NSEntityDescription *> *subentitiesByName;
@property (strong) NSArray<NSEntityDescription *> *subentities;
@property (nullable, readonly, assign) NSEntityDescription *superentity;
@property (readonly, copy) NSDictionary<NSString *, __kindof NSPropertyDescription *> *propertiesByName;
@property (strong) NSArray<__kindof NSPropertyDescription *> *properties;
@property (nullable, nonatomic, strong) NSDictionary *userInfo;
@property (readonly, copy) NSDictionary<NSString *, NSAttributeDescription *> *attributesByName;
@property (readonly, copy) NSDictionary<NSString *, NSRelationshipDescription *> *relationshipsByName;
- (NSArray<NSRelationshipDescription *> *)relationshipsWithDestinationEntity:(NSEntityDescription *)entity;
- (BOOL)isKindOfEntity:(NSEntityDescription *)entity;
@property (readonly, copy) NSData *versionHash;
@property (nullable, copy) NSString *versionHashModifier;
@property (nullable, copy) NSString *renamingIdentifier;
@property (strong) NSArray<NSArray<id> *> *uniquenessConstraints;
@property (nullable, copy) NSString *coreSpotlightDisplayNameExpression;
@end

@interface NSPropertyDescription : NSObject <NSCoding, NSCopying>
@property (nonatomic, readonly, assign) NSEntityDescription *entity;
@property (nonatomic, copy) NSString *name;
@property (getter=isOptional) BOOL optional;
@property (getter=isTransient) BOOL transient;
@property (readonly, strong) NSArray<NSPredicate *> *validationPredicates;
@property (readonly, strong) NSArray *validationWarnings;
- (void)setValidationPredicates:(nullable NSArray<NSPredicate *> *)validationPredicates withValidationWarnings:(nullable NSArray<NSString *> *)validationWarnings;
@property (nullable, nonatomic, strong) NSDictionary *userInfo;
@property (getter=isIndexed) BOOL indexed;
@property (readonly, copy) NSData *versionHash;
@property (nullable, copy) NSString *versionHashModifier;
@property (getter=isIndexedBySpotlight) BOOL indexedBySpotlight;
@property (nullable, copy) NSString *renamingIdentifier;
@end

typedef NS_ENUM(NSUInteger, NSAttributeType) {
    NSUndefinedAttributeType NS_SWIFT_NAME(undefinedAttributeType) = 0,
    NSInteger16AttributeType NS_SWIFT_NAME(integer16AttributeType) = 100,
    NSInteger32AttributeType NS_SWIFT_NAME(integer32AttributeType) = 200,
    NSInteger64AttributeType NS_SWIFT_NAME(integer64AttributeType) = 300,
    NSDecimalAttributeType NS_SWIFT_NAME(decimalAttributeType) = 400,
    NSDoubleAttributeType NS_SWIFT_NAME(doubleAttributeType) = 500,
    NSFloatAttributeType NS_SWIFT_NAME(floatAttributeType) = 600,
    NSStringAttributeType NS_SWIFT_NAME(stringAttributeType) = 700,
    NSBooleanAttributeType NS_SWIFT_NAME(booleanAttributeType) = 800,
    NSDateAttributeType NS_SWIFT_NAME(dateAttributeType) = 900,
    NSBinaryDataAttributeType NS_SWIFT_NAME(binaryDataAttributeType) = 1000,
    NSUUIDAttributeType NS_SWIFT_NAME(UUIDAttributeType) = 1100,
    NSURIAttributeType NS_SWIFT_NAME(URIAttributeType) = 1200,
    NSTransformableAttributeType NS_SWIFT_NAME(transformableAttributeType) = 1800,
    NSObjectIDAttributeType NS_SWIFT_NAME(objectIDAttributeType) = 2000,
    NSCompositeAttributeType NS_SWIFT_NAME(compositeAttributeType) = 2100,
};

@interface NSAttributeDescription : NSPropertyDescription
@property NSAttributeType attributeType;
@property (nullable, copy) NSString *attributeValueClassName;
@property (nullable, retain) id defaultValue;
@property (nullable, copy) NSString *valueTransformerName;
@property BOOL allowsExternalBinaryDataStorage;
@property BOOL preservesValueInHistoryOnDeletion;
@property BOOL allowsCloudEncryption;
@end

typedef NS_ENUM(NSUInteger, NSDeleteRule) {
    NSNoActionDeleteRule NS_SWIFT_NAME(noActionDeleteRule),
    NSNullifyDeleteRule NS_SWIFT_NAME(nullifyDeleteRule),
    NSCascadeDeleteRule NS_SWIFT_NAME(cascadeDeleteRule),
    NSDenyDeleteRule NS_SWIFT_NAME(denyDeleteRule)
};

@interface NSRelationshipDescription : NSPropertyDescription
@property (nullable, nonatomic, assign) NSEntityDescription *destinationEntity;
@property (nullable, nonatomic, assign) NSRelationshipDescription *inverseRelationship;
@property NSUInteger maxCount;
@property NSUInteger minCount;
@property NSDeleteRule deleteRule;
@property (getter=isToMany, readonly) BOOL toMany;
@property (getter=isOrdered) BOOL ordered;
@end

@interface NSFetchedPropertyDescription : NSPropertyDescription
@property (nullable, strong) NSFetchRequest *fetchRequest;
@end

@interface NSExpressionDescription : NSPropertyDescription
@property (nullable, strong) NSExpression *expression;
@property NSAttributeType expressionResultType;
@end

NS_ASSUME_NONNULL_END
