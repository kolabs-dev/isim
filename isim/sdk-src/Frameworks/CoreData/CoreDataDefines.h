#pragma once
#import <Foundation/Foundation.h>
#define COREDATA_EXTERN extern __attribute__((visibility("default")))
NS_ASSUME_NONNULL_BEGIN

COREDATA_EXTERN double NSCoreDataVersionNumber;

/* errors (NSCocoaErrorDomain) */
COREDATA_EXTERN NSString * const NSDetailedErrorsKey;
COREDATA_EXTERN NSString * const NSValidationObjectErrorKey;
COREDATA_EXTERN NSString * const NSValidationKeyErrorKey;
COREDATA_EXTERN NSString * const NSValidationPredicateErrorKey;
COREDATA_EXTERN NSString * const NSValidationValueErrorKey;
COREDATA_EXTERN NSString * const NSAffectedStoresErrorKey;
COREDATA_EXTERN NSString * const NSAffectedObjectsErrorKey;
COREDATA_EXTERN NSString * const NSPersistentStoreSaveConflictsErrorKey;
COREDATA_EXTERN NSString * const NSSQLiteErrorDomain;
enum : NSInteger {
    NSManagedObjectValidationError = 1550,
    NSManagedObjectConstraintValidationError = 1551,
    NSValidationMultipleErrorsError = 1560,
    NSValidationMissingMandatoryPropertyError = 1570,
    NSValidationRelationshipLacksMinimumCountError = 1580,
    NSValidationRelationshipExceedsMaximumCountError = 1590,
    NSValidationRelationshipDeniedDeleteError = 1600,
    NSValidationNumberTooLargeError = 1610,
    NSValidationNumberTooSmallError = 1620,
    NSValidationDateTooLateError = 1630,
    NSValidationDateTooSoonError = 1640,
    NSValidationInvalidDateError = 1650,
    NSValidationStringTooLongError = 1660,
    NSValidationStringTooShortError = 1670,
    NSValidationStringPatternMatchingError = 1680,
    NSValidationInvalidURIError = 1690,
    NSManagedObjectContextLockingError = 132000,
    NSPersistentStoreCoordinatorLockingError = 132010,
    NSManagedObjectReferentialIntegrityError = 133000,
    NSManagedObjectExternalRelationshipError = 133010,
    NSManagedObjectMergeError = 133020,
    NSManagedObjectConstraintMergeError = 133021,
    NSPersistentStoreInvalidTypeError = 134000,
    NSPersistentStoreTypeMismatchError = 134010,
    NSPersistentStoreIncompatibleSchemaError = 134020,
    NSPersistentStoreSaveError = 134030,
    NSPersistentStoreIncompleteSaveError = 134040,
    NSPersistentStoreSaveConflictsError = 134050,
    NSCoreDataError = 134060,
    NSPersistentStoreOperationError = 134070,
    NSPersistentStoreOpenError = 134080,
    NSPersistentStoreTimeoutError = 134090,
    NSPersistentStoreUnsupportedRequestTypeError = 134091,
    NSPersistentStoreIncompatibleVersionHashError = 134100,
    NSMigrationError = 134110,
    NSMigrationConstraintViolationError = 134111,
    NSMigrationCancelledError = 134120,
    NSMigrationMissingSourceModelError = 134130,
    NSMigrationMissingMappingModelError = 134140,
    NSMigrationManagerSourceStoreError = 134150,
    NSMigrationManagerDestinationStoreError = 134160,
    NSEntityMigrationPolicyError = 134170,
    NSSQLiteError = 134180,
    NSInferredMappingModelError = 134190,
    NSExternalRecordImportError = 134200,
};

/* store types and options */
COREDATA_EXTERN NSString * const NSSQLiteStoreType;
COREDATA_EXTERN NSString * const NSInMemoryStoreType;
COREDATA_EXTERN NSString * const NSBinaryStoreType;
COREDATA_EXTERN NSString * const NSStoreTypeKey;
COREDATA_EXTERN NSString * const NSStoreUUIDKey;
COREDATA_EXTERN NSString * const NSReadOnlyPersistentStoreOption;
COREDATA_EXTERN NSString * const NSMigratePersistentStoresAutomaticallyOption;
COREDATA_EXTERN NSString * const NSInferMappingModelAutomaticallyOption;
COREDATA_EXTERN NSString * const NSSQLitePragmasOption;
COREDATA_EXTERN NSString * const NSPersistentHistoryTrackingKey;
COREDATA_EXTERN NSString * const NSPersistentStoreRemoteChangeNotificationPostOptionKey;
COREDATA_EXTERN NSString * const NSPersistentStoreFileProtectionKey;
COREDATA_EXTERN NSString * const NSPersistentStoreTimeoutOption;
COREDATA_EXTERN NSString * const NSStoreModelVersionHashesKey;
COREDATA_EXTERN NSString * const NSStoreModelVersionIdentifiersKey;

/// Things a fetch request can return: managed objects, object IDs, dictionaries, counts.
@protocol NSFetchRequestResult <NSObject>
@end

NS_ASSUME_NONNULL_END
