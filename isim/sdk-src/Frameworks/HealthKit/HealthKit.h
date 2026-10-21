#pragma once
/* isim HealthKit for Objective-C: the classes are the HealthKit Swift overlay's (HealthKit.framework re-exports
   libswiftHealthKit.dylib): a local Health store like the Simulator's, the Health Access sheet, samples kept in the device
   data and shared by all apps. Swift uses the overlay; these declarations are hidden from Swift. Not from Objective-C
   yet: HKStatisticsCollectionQuery and dateOfBirthComponents (isim's Foundation has no NSDateComponents), workouts. The
   classes are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const HKErrorDomain;
typedef NS_ENUM(NSInteger, HKErrorCode) {
    HKNoError = 0, HKErrorHealthDataUnavailable, HKErrorHealthDataRestricted, HKErrorInvalidArgument, HKErrorAuthorizationDenied,
    HKErrorAuthorizationNotDetermined, HKErrorDatabaseInaccessible, HKErrorUserCanceled, HKErrorAnotherWorkoutSessionStarted,
    HKErrorUserExitedWorkoutSession, HKErrorRequiredAuthorizationDenied, HKErrorNoData, HKErrorWorkoutActivityNotAllowed,
    HKErrorDataSizeExceeded,
};
typedef NS_ENUM(NSInteger, HKAuthorizationStatus) { HKAuthorizationStatusNotDetermined = 0, HKAuthorizationStatusSharingDenied, HKAuthorizationStatusSharingAuthorized };
typedef NS_ENUM(NSInteger, HKAuthorizationRequestStatus) { HKAuthorizationRequestStatusUnknown = 0, HKAuthorizationRequestStatusShouldRequest, HKAuthorizationRequestStatusUnnecessary };
typedef NS_ENUM(NSInteger, HKBiologicalSex) { HKBiologicalSexNotSet = 0, HKBiologicalSexFemale, HKBiologicalSexMale, HKBiologicalSexOther };
typedef NS_ENUM(NSInteger, HKQuantityAggregationStyle) {
    HKQuantityAggregationStyleCumulative = 0, HKQuantityAggregationStyleDiscreteArithmetic, HKQuantityAggregationStyleDiscreteTemporallyWeighted,
    HKQuantityAggregationStyleDiscreteEquivalentContinuousLevel,
};
typedef NS_ENUM(NSInteger, HKMetricPrefix) {
    HKMetricPrefixNone = 0, HKMetricPrefixPico = 1, HKMetricPrefixNano, HKMetricPrefixMicro, HKMetricPrefixMilli, HKMetricPrefixCenti,
    HKMetricPrefixDeci, HKMetricPrefixDeca, HKMetricPrefixHecto, HKMetricPrefixKilo, HKMetricPrefixMega, HKMetricPrefixGiga,
    HKMetricPrefixTera, HKMetricPrefixFemto = 13,
};
typedef NS_ENUM(NSInteger, HKCategoryValueSleepAnalysis) {
    HKCategoryValueSleepAnalysisInBed = 0, HKCategoryValueSleepAnalysisAsleepUnspecified = 1, HKCategoryValueSleepAnalysisAwake = 2,
    HKCategoryValueSleepAnalysisAsleepCore = 3, HKCategoryValueSleepAnalysisAsleepDeep = 4, HKCategoryValueSleepAnalysisAsleepREM = 5,
};
typedef NS_OPTIONS(NSUInteger, HKQueryOptions) { HKQueryOptionNone = 0, HKQueryOptionStrictStartDate = 1 << 0, HKQueryOptionStrictEndDate = 1 << 1 };
typedef NS_OPTIONS(NSUInteger, HKStatisticsOptions) {
    HKStatisticsOptionNone = 0, HKStatisticsOptionSeparateBySource = 1 << 0, HKStatisticsOptionDiscreteAverage = 1 << 1,
    HKStatisticsOptionDiscreteMin = 1 << 2, HKStatisticsOptionDiscreteMax = 1 << 3, HKStatisticsOptionCumulativeSum = 1 << 4,
    HKStatisticsOptionMostRecent = 1 << 5, HKStatisticsOptionDuration = 1 << 6,
};

typedef NSString * HKQuantityTypeIdentifier NS_TYPED_ENUM;
typedef NSString * HKCategoryTypeIdentifier NS_TYPED_ENUM;
typedef NSString * HKCharacteristicTypeIdentifier NS_TYPED_ENUM;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierStepCount;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceWalkingRunning;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceCycling;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierActiveEnergyBurned;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBasalEnergyBurned;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierFlightsClimbed;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierAppleExerciseTime;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierHeartRate;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierRestingHeartRate;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierHeartRateVariabilitySDNN;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierOxygenSaturation;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierRespiratoryRate;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBodyTemperature;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBloodPressureSystolic;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBloodPressureDiastolic;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBodyMass;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBodyMassIndex;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierBodyFatPercentage;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierHeight;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierLeanBodyMass;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDietaryWater;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDietaryEnergyConsumed;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDietaryProtein;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDietaryCaffeine;
FOUNDATION_EXPORT HKCategoryTypeIdentifier const HKCategoryTypeIdentifierSleepAnalysis;
FOUNDATION_EXPORT HKCategoryTypeIdentifier const HKCategoryTypeIdentifierMindfulSession;
FOUNDATION_EXPORT HKCategoryTypeIdentifier const HKCategoryTypeIdentifierAppleStandHour;
FOUNDATION_EXPORT HKCategoryTypeIdentifier const HKCategoryTypeIdentifierHighHeartRateEvent;
FOUNDATION_EXPORT HKCharacteristicTypeIdentifier const HKCharacteristicTypeIdentifierBiologicalSex;
FOUNDATION_EXPORT HKCharacteristicTypeIdentifier const HKCharacteristicTypeIdentifierDateOfBirth;
FOUNDATION_EXPORT HKCharacteristicTypeIdentifier const HKCharacteristicTypeIdentifierBloodType;
FOUNDATION_EXPORT NSString * const HKSampleSortIdentifierStartDate;
FOUNDATION_EXPORT NSString * const HKSampleSortIdentifierEndDate;
FOUNDATION_EXPORT NSString * const HKMetadataKeyWasUserEntered;
FOUNDATION_EXPORT NSString * const HKMetadataKeyExternalUUID;
FOUNDATION_EXPORT NSUInteger const HKObjectQueryNoLimit;

@class HKQuantityType, HKCategoryType, HKCharacteristicType, HKWorkoutType;
@interface HKObjectType : NSObject <NSCopying>
@property (readonly, strong) NSString *identifier;
+ (nullable HKQuantityType *)quantityTypeForIdentifier:(HKQuantityTypeIdentifier)identifier;
+ (nullable HKCategoryType *)categoryTypeForIdentifier:(HKCategoryTypeIdentifier)identifier;
+ (nullable HKCharacteristicType *)characteristicTypeForIdentifier:(HKCharacteristicTypeIdentifier)identifier;
+ (HKWorkoutType *)workoutType;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKCharacteristicType : HKObjectType
@end
@interface HKSampleType : HKObjectType
@property (readonly, getter=isMinimumDurationRestricted) BOOL minimumDurationRestricted;
@property (readonly, getter=isMaximumDurationRestricted) BOOL maximumDurationRestricted;
@end
@class HKUnit;
@interface HKQuantityType : HKSampleType
@property (readonly) HKQuantityAggregationStyle aggregationStyle;
- (BOOL)isCompatibleWithUnit:(HKUnit *)unit;
@end
@interface HKCategoryType : HKSampleType
@end
@interface HKWorkoutType : HKSampleType
@end

@interface HKUnit : NSObject <NSCopying>
@property (readonly, strong) NSString *unitString;
+ (instancetype)unitFromString:(NSString *)string;
+ (instancetype)countUnit;
+ (instancetype)meterUnit;
+ (instancetype)meterUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)mileUnit;
+ (instancetype)footUnit;
+ (instancetype)inchUnit;
+ (instancetype)yardUnit;
+ (instancetype)gramUnit;
+ (instancetype)gramUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)poundUnit;
+ (instancetype)ounceUnit;
+ (instancetype)secondUnit;
+ (instancetype)secondUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)minuteUnit;
+ (instancetype)hourUnit;
+ (instancetype)dayUnit;
+ (instancetype)literUnit;
+ (instancetype)literUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)fluidOunceUSUnit;
+ (instancetype)kilocalorieUnit;
+ (instancetype)largeCalorieUnit;
+ (instancetype)smallCalorieUnit;
+ (instancetype)jouleUnit;
+ (instancetype)jouleUnitWithMetricPrefix:(HKMetricPrefix)prefix;
+ (instancetype)percentUnit;
+ (instancetype)degreeCelsiusUnit;
+ (instancetype)millimeterOfMercuryUnit;
- (HKUnit *)unitDividedByUnit:(HKUnit *)unit;
- (HKUnit *)unitMultipliedByUnit:(HKUnit *)unit;
- (HKUnit *)reciprocalUnit;
- (BOOL)isNull;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKQuantity : NSObject <NSCopying>
+ (instancetype)quantityWithUnit:(HKUnit *)unit doubleValue:(double)value;
- (BOOL)isCompatibleWithUnit:(HKUnit *)unit;
- (double)doubleValueForUnit:(HKUnit *)unit;
- (NSComparisonResult)compare:(HKQuantity *)quantity;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface HKSource : NSObject
@property (readonly) NSString *name;
@property (readonly) NSString *bundleIdentifier;
+ (HKSource *)defaultSource;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKSourceRevision : NSObject
@property (readonly) HKSource *source;
@property (readonly, nullable) NSString *version;
- (instancetype)initWithSource:(HKSource *)source version:(nullable NSString *)version;
@end
@interface HKDevice : NSObject
+ (HKDevice *)localDevice;
@property (readonly, nullable) NSString *name;
@property (readonly, nullable) NSString *manufacturer;
@property (readonly, nullable) NSString *model;
@end

@interface HKObject : NSObject
@property (readonly, strong) NSUUID *UUID;
@property (readonly, strong) HKSourceRevision *sourceRevision;
@property (readonly, strong, nullable) HKDevice *device;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *metadata;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKSample : HKObject
@property (readonly, strong) HKSampleType *sampleType;
@property (readonly, strong) NSDate *startDate;
@property (readonly, strong) NSDate *endDate;
@property (readonly) BOOL hasUndeterminedDuration;
@end
@interface HKQuantitySample : HKSample
@property (readonly, strong) HKQuantityType *quantityType;
@property (readonly, strong) HKQuantity *quantity;
@property (readonly, assign) NSInteger count;
+ (instancetype)quantitySampleWithType:(HKQuantityType *)quantityType quantity:(HKQuantity *)quantity startDate:(NSDate *)startDate endDate:(NSDate *)endDate;
+ (instancetype)quantitySampleWithType:(HKQuantityType *)quantityType quantity:(HKQuantity *)quantity startDate:(NSDate *)startDate endDate:(NSDate *)endDate
                              metadata:(nullable NSDictionary<NSString *, id> *)metadata;
@end
@interface HKCategorySample : HKSample
@property (readonly, strong) HKCategoryType *categoryType;
@property (readonly) NSInteger value;
+ (instancetype)categorySampleWithType:(HKCategoryType *)type value:(NSInteger)value startDate:(NSDate *)startDate endDate:(NSDate *)endDate;
+ (instancetype)categorySampleWithType:(HKCategoryType *)type value:(NSInteger)value startDate:(NSDate *)startDate endDate:(NSDate *)endDate
                              metadata:(nullable NSDictionary<NSString *, id> *)metadata;
@end

@interface HKBiologicalSexObject : NSObject
@property (readonly) HKBiologicalSex biologicalSex;
@end

@interface HKQuery : NSObject
@property (readonly, strong, nullable) HKObjectType *objectType;
@property (readonly, strong, nullable) HKSampleType *sampleType;
@property (readonly, strong, nullable) NSPredicate *predicate;
+ (NSPredicate *)predicateForSamplesWithStartDate:(nullable NSDate *)startDate endDate:(nullable NSDate *)endDate options:(HKQueryOptions)options;
+ (NSPredicate *)predicateForObjectsFromSource:(HKSource *)source;
+ (NSPredicate *)predicateForObjectsFromSources:(NSSet<HKSource *> *)sources;
+ (NSPredicate *)predicateForObjectWithUUID:(NSUUID *)UUID;
+ (NSPredicate *)predicateForObjectsWithUUIDs:(NSSet<NSUUID *> *)UUIDs;
+ (NSPredicate *)predicateForObjectsWithMetadataKey:(NSString *)key;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKSampleQuery : HKQuery
@property (readonly) NSUInteger limit;
@property (readonly, copy, nullable) NSArray<NSSortDescriptor *> *sortDescriptors;
- (instancetype)initWithSampleType:(HKSampleType *)sampleType predicate:(nullable NSPredicate *)predicate limit:(NSUInteger)limit
                   sortDescriptors:(nullable NSArray<NSSortDescriptor *> *)sortDescriptors
                    resultsHandler:(void (^)(HKSampleQuery *query, NSArray<__kindof HKSample *> * _Nullable results, NSError * _Nullable error))resultsHandler;
@end
@interface HKStatistics : NSObject
@property (readonly, strong) HKQuantityType *quantityType;
@property (readonly, strong) NSDate *startDate;
@property (readonly, strong) NSDate *endDate;
@property (readonly, strong, nullable) NSArray<HKSource *> *sources;
- (nullable HKQuantity *)sumQuantity;
- (nullable HKQuantity *)averageQuantity;
- (nullable HKQuantity *)minimumQuantity;
- (nullable HKQuantity *)maximumQuantity;
- (nullable HKQuantity *)mostRecentQuantity;
- (nullable HKQuantity *)sumQuantityForSource:(HKSource *)source;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKStatisticsQuery : HKQuery
- (instancetype)initWithQuantityType:(HKQuantityType *)quantityType quantitySamplePredicate:(nullable NSPredicate *)quantitySamplePredicate
                             options:(HKStatisticsOptions)options
                   completionHandler:(void (^)(HKStatisticsQuery *query, HKStatistics * _Nullable result, NSError * _Nullable error))handler;
@end
@interface HKStatisticsCollection : NSObject
- (NSArray<HKStatistics *> *)statistics;
- (nullable HKStatistics *)statisticsForDate:(NSDate *)date;
- (NSSet<HKSource *> *)sources;
- (instancetype)init NS_UNAVAILABLE;
@end
typedef void (^HKObserverQueryCompletionHandler)(void);
@interface HKObserverQuery : HKQuery
- (instancetype)initWithSampleType:(HKSampleType *)sampleType predicate:(nullable NSPredicate *)predicate
                     updateHandler:(void (^)(HKObserverQuery *query, HKObserverQueryCompletionHandler completionHandler, NSError * _Nullable error))updateHandler;
@end

/* anchored object queries: the samples added and deleted since an anchor (the device's Health database numbers its changes) */
@interface HKQueryAnchor : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)anchorFromValue:(NSUInteger)value;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKDeletedObject : NSObject
@property (readonly, strong) NSUUID *UUID;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *metadata;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKAnchoredObjectQuery : HKQuery
- (instancetype)initWithType:(HKSampleType *)type predicate:(nullable NSPredicate *)predicate anchor:(nullable HKQueryAnchor *)anchor limit:(NSUInteger)limit
              resultsHandler:(void (^)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> * _Nullable sampleObjects,
                                       NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error))handler;
@property (nonatomic, copy, nullable) void (^updateHandler)(HKAnchoredObjectQuery *query, NSArray<__kindof HKSample *> * _Nullable addedObjects,
                                                           NSArray<HKDeletedObject *> * _Nullable deletedObjects, HKQueryAnchor * _Nullable newAnchor, NSError * _Nullable error);
@end
@interface HKSourceQuery : HKQuery
- (instancetype)initWithSampleType:(HKSampleType *)sampleType samplePredicate:(nullable NSPredicate *)objectPredicate
                 completionHandler:(void (^)(HKSourceQuery *query, NSSet<HKSource *> * _Nullable sources, NSError * _Nullable error))completionHandler;
@end
typedef NS_ENUM(NSInteger, HKUpdateFrequency) { HKUpdateFrequencyImmediate = 1, HKUpdateFrequencyHourly, HKUpdateFrequencyDaily, HKUpdateFrequencyWeekly };

@interface HKHealthStore : NSObject
+ (BOOL)isHealthDataAvailable;
- (BOOL)supportsHealthRecords;
- (HKAuthorizationStatus)authorizationStatusForType:(HKObjectType *)type;
- (void)requestAuthorizationToShareTypes:(nullable NSSet<HKSampleType *> *)typesToShare readTypes:(nullable NSSet<HKObjectType *> *)typesToRead
                              completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)getRequestStatusForAuthorizationToShareTypes:(NSSet<HKSampleType *> *)typesToShare readTypes:(NSSet<HKObjectType *> *)typesToRead
                                          completion:(void (^)(HKAuthorizationRequestStatus requestStatus, NSError * _Nullable error))completion;
- (void)saveObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)saveObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)deleteObject:(HKObject *)object withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)deleteObjects:(NSArray<HKObject *> *)objects withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (nullable HKBiologicalSexObject *)biologicalSexWithError:(NSError **)error;
- (void)executeQuery:(HKQuery *)query;
- (void)stopQuery:(HKQuery *)query;
/* background delivery (adapted: kept per app; while the app runs its observer queries fire on changes) */
- (void)enableBackgroundDeliveryForType:(HKObjectType *)type frequency:(HKUpdateFrequency)frequency
                         withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)disableBackgroundDeliveryForType:(HKObjectType *)type withCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)disableAllBackgroundDeliveryWithCompletion:(void (^)(BOOL success, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
#endif
