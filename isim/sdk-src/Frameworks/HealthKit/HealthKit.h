#pragma once
/* isim HealthKit for Objective-C: the classes are the HealthKit Swift overlay's (HealthKit.framework re-exports
   libswiftHealthKit.dylib): a local Health store like the Simulator's, the Health Access sheet, samples kept in the device
   data and shared by all apps. Swift uses the overlay; these declarations are hidden from Swift. Not from Objective-C
   yet: HKStatisticsCollectionQuery and dateOfBirthComponents (isim's Foundation has no NSDateComponents). The classes
   are not subclassable from Objective-C. */
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const HKErrorDomain;
typedef NS_ENUM(NSInteger, HKErrorCode) {
    HKNoError = 0, HKErrorHealthDataUnavailable, HKErrorHealthDataRestricted, HKErrorInvalidArgument, HKErrorAuthorizationDenied,
    HKErrorAuthorizationNotDetermined, HKErrorDatabaseInaccessible, HKErrorUserCanceled, HKErrorAnotherWorkoutSessionStarted,
    HKErrorUserExitedWorkoutSession, HKErrorRequiredAuthorizationDenied, HKErrorNoData, HKErrorWorkoutActivityNotAllowed,
    HKErrorDataSizeExceeded, HKErrorBackgroundWorkoutSessionNotAllowed,
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

/* workouts (issue #418): kept in the device's Health database; a live workout's data on iPhone (iOS 26) is isim's simulation */
typedef NS_ENUM(NSUInteger, HKWorkoutActivityType) {
    HKWorkoutActivityTypeAmericanFootball = 1, HKWorkoutActivityTypeArchery = 2,
    HKWorkoutActivityTypeAustralianFootball = 3, HKWorkoutActivityTypeBadminton = 4, HKWorkoutActivityTypeBaseball = 5,
    HKWorkoutActivityTypeBasketball = 6, HKWorkoutActivityTypeBowling = 7, HKWorkoutActivityTypeBoxing = 8,
    HKWorkoutActivityTypeClimbing = 9, HKWorkoutActivityTypeCricket = 10, HKWorkoutActivityTypeCrossTraining = 11,
    HKWorkoutActivityTypeCurling = 12, HKWorkoutActivityTypeCycling = 13, HKWorkoutActivityTypeElliptical = 16,
    HKWorkoutActivityTypeEquestrianSports = 17, HKWorkoutActivityTypeFencing = 18, HKWorkoutActivityTypeFishing = 19,
    HKWorkoutActivityTypeFunctionalStrengthTraining = 20, HKWorkoutActivityTypeGolf = 21,
    HKWorkoutActivityTypeGymnastics = 22, HKWorkoutActivityTypeHandball = 23, HKWorkoutActivityTypeHiking = 24,
    HKWorkoutActivityTypeHockey = 25, HKWorkoutActivityTypeHunting = 26, HKWorkoutActivityTypeLacrosse = 27,
    HKWorkoutActivityTypeMartialArts = 28, HKWorkoutActivityTypeMindAndBody = 29,
    HKWorkoutActivityTypePaddleSports = 31, HKWorkoutActivityTypePlay = 32,
    HKWorkoutActivityTypePreparationAndRecovery = 33, HKWorkoutActivityTypeRacquetball = 34,
    HKWorkoutActivityTypeRowing = 35, HKWorkoutActivityTypeRugby = 36, HKWorkoutActivityTypeRunning = 37,
    HKWorkoutActivityTypeSailing = 38, HKWorkoutActivityTypeSkatingSports = 39, HKWorkoutActivityTypeSnowSports = 40,
    HKWorkoutActivityTypeSoccer = 41, HKWorkoutActivityTypeSoftball = 42, HKWorkoutActivityTypeSquash = 43,
    HKWorkoutActivityTypeStairClimbing = 44, HKWorkoutActivityTypeSurfingSports = 45,
    HKWorkoutActivityTypeSwimming = 46, HKWorkoutActivityTypeTableTennis = 47, HKWorkoutActivityTypeTennis = 48,
    HKWorkoutActivityTypeTrackAndField = 49, HKWorkoutActivityTypeTraditionalStrengthTraining = 50,
    HKWorkoutActivityTypeVolleyball = 51, HKWorkoutActivityTypeWalking = 52, HKWorkoutActivityTypeWaterFitness = 53,
    HKWorkoutActivityTypeWaterPolo = 54, HKWorkoutActivityTypeWaterSports = 55, HKWorkoutActivityTypeWrestling = 56,
    HKWorkoutActivityTypeYoga = 57, HKWorkoutActivityTypeBarre = 58, HKWorkoutActivityTypeCoreTraining = 59,
    HKWorkoutActivityTypeCrossCountrySkiing = 60, HKWorkoutActivityTypeDownhillSkiing = 61,
    HKWorkoutActivityTypeFlexibility = 62, HKWorkoutActivityTypeHighIntensityIntervalTraining = 63,
    HKWorkoutActivityTypeJumpRope = 64, HKWorkoutActivityTypeKickboxing = 65, HKWorkoutActivityTypePilates = 66,
    HKWorkoutActivityTypeSnowboarding = 67, HKWorkoutActivityTypeStairs = 68, HKWorkoutActivityTypeStepTraining = 69,
    HKWorkoutActivityTypeWheelchairWalkPace = 70, HKWorkoutActivityTypeWheelchairRunPace = 71,
    HKWorkoutActivityTypeTaiChi = 72, HKWorkoutActivityTypeMixedCardio = 73, HKWorkoutActivityTypeHandCycling = 74,
    HKWorkoutActivityTypeDiscSports = 75, HKWorkoutActivityTypeFitnessGaming = 76,
    HKWorkoutActivityTypeCardioDance = 77, HKWorkoutActivityTypeSocialDance = 78, HKWorkoutActivityTypePickleball = 79,
    HKWorkoutActivityTypeCooldown = 80, HKWorkoutActivityTypeSwimBikeRun = 82, HKWorkoutActivityTypeTransition = 83,
    HKWorkoutActivityTypeUnderwaterDiving = 84, HKWorkoutActivityTypeOther = 3000,
};
typedef NS_ENUM(NSInteger, HKWorkoutSessionLocationType) { HKWorkoutSessionLocationTypeUnknown = 1, HKWorkoutSessionLocationTypeIndoor, HKWorkoutSessionLocationTypeOutdoor };
typedef NS_ENUM(NSInteger, HKWorkoutSwimmingLocationType) { HKWorkoutSwimmingLocationTypeUnknown = 0, HKWorkoutSwimmingLocationTypePool, HKWorkoutSwimmingLocationTypeOpenWater };
typedef NS_ENUM(NSInteger, HKWorkoutEventType) {
    HKWorkoutEventTypePause = 1, HKWorkoutEventTypeResume, HKWorkoutEventTypeLap, HKWorkoutEventTypeMarker, HKWorkoutEventTypeMotionPaused,
    HKWorkoutEventTypeMotionResumed, HKWorkoutEventTypeSegment, HKWorkoutEventTypePauseOrResumeRequest,
};
typedef NS_ENUM(NSInteger, HKWorkoutSessionState) {
    HKWorkoutSessionStateNotStarted = 1, HKWorkoutSessionStateRunning, HKWorkoutSessionStateEnded, HKWorkoutSessionStatePaused,
    HKWorkoutSessionStatePrepared, HKWorkoutSessionStateStopped,
} API_AVAILABLE(ios(17.0));
typedef NS_ENUM(NSInteger, HKWorkoutSessionType) { HKWorkoutSessionTypePrimary = 0, HKWorkoutSessionTypeMirrored } API_AVAILABLE(ios(17.0));
FOUNDATION_EXPORT NSString * const HKWorkoutTypeIdentifier;
FOUNDATION_EXPORT NSString * const HKWorkoutRouteTypeIdentifier;
FOUNDATION_EXPORT NSString * const HKDataTypeIdentifierHeartbeatSeries;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceSwimming;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierSwimmingStrokeCount;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceWheelchair;
FOUNDATION_EXPORT HKQuantityTypeIdentifier const HKQuantityTypeIdentifierDistanceDownhillSnowSports;
FOUNDATION_EXPORT NSString * const HKMetadataKeyIndoorWorkout;
FOUNDATION_EXPORT NSString * const HKMetadataKeyCoachedWorkout;
FOUNDATION_EXPORT NSString * const HKMetadataKeyWorkoutBrandName;
FOUNDATION_EXPORT NSString * const HKWorkoutSortIdentifierDuration;
FOUNDATION_EXPORT NSString * const HKWorkoutSortIdentifierTotalDistance;
FOUNDATION_EXPORT NSString * const HKWorkoutSortIdentifierTotalEnergyBurned;
FOUNDATION_EXPORT NSString * const HKWorkoutSortIdentifierTotalSwimmingStrokeCount;
FOUNDATION_EXPORT NSString * const HKWorkoutSortIdentifierTotalFlightsClimbed;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkout;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutType;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutDuration;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutTotalDistance;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutTotalEnergyBurned;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutTotalSwimmingStrokeCount;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutTotalFlightsClimbed;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutSumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutMinimumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutMaximumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutAverageQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityType;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityStartDate;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityEndDate;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityDuration;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivitySumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityMinimumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityMaximumQuantity;
FOUNDATION_EXPORT NSString * const HKPredicateKeyPathWorkoutActivityAverageQuantity;

@interface HKWorkoutConfiguration : NSObject <NSCopying, NSSecureCoding>
@property (assign) HKWorkoutActivityType activityType;
@property (assign) HKWorkoutSessionLocationType locationType;
@property (assign) HKWorkoutSwimmingLocationType swimmingLocationType;
@property (copy, nullable) HKQuantity *lapLength;
@end
@interface HKWorkoutEvent : NSObject <NSSecureCoding, NSCopying>
@property (readonly, assign) HKWorkoutEventType type;
@property (readonly, copy) NSDateInterval *dateInterval;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *metadata;
+ (instancetype)workoutEventWithType:(HKWorkoutEventType)type dateInterval:(NSDateInterval *)dateInterval metadata:(nullable NSDictionary<NSString *, id> *)metadata;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKWorkoutActivity : NSObject <NSSecureCoding, NSCopying>
@property (readonly, strong) NSUUID *UUID;
@property (readonly, copy) HKWorkoutConfiguration *workoutConfiguration;
@property (readonly, strong) NSDate *startDate;
@property (readonly, strong, nullable) NSDate *endDate;
@property (readonly, copy, nullable) NSDictionary<NSString *, id> *metadata;
@property (readonly, assign) NSTimeInterval duration;
@property (readonly, copy) NSArray<HKWorkoutEvent *> *workoutEvents;
@property (readonly, copy) NSDictionary<HKQuantityType *, HKStatistics *> *allStatistics;
- (instancetype)initWithWorkoutConfiguration:(HKWorkoutConfiguration *)workoutConfiguration startDate:(NSDate *)startDate
                                     endDate:(nullable NSDate *)endDate metadata:(nullable NSDictionary<NSString *, id> *)metadata;
- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKWorkout : HKSample
@property (readonly, assign) HKWorkoutActivityType workoutActivityType;
@property (readonly, assign) NSTimeInterval duration;
@property (readonly, copy, nullable) NSArray<HKWorkoutEvent *> *workoutEvents;
@property (readonly, copy) NSArray<HKWorkoutActivity *> *workoutActivities;
@property (readonly, copy) NSDictionary<HKQuantityType *, HKStatistics *> *allStatistics;
@property (readonly, strong, nullable) HKQuantity *totalEnergyBurned API_DEPRECATED("Use statisticsForType:", ios(8.0, 18.0));
@property (readonly, strong, nullable) HKQuantity *totalDistance API_DEPRECATED("Use statisticsForType:", ios(8.0, 27.2));
@property (readonly, strong, nullable) HKQuantity *totalSwimmingStrokeCount API_DEPRECATED("Use statisticsForType:", ios(10.0, 18.0));
@property (readonly, strong, nullable) HKQuantity *totalFlightsClimbed API_DEPRECATED("Use statisticsForType:", ios(11.0, 18.0));
- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType;
@end
@interface HKSeriesType : HKSampleType
+ (instancetype)workoutRouteType;
+ (instancetype)heartbeatSeriesType;
@end
@interface HKObjectType (HKSeriesType)
+ (nullable HKSeriesType *)seriesTypeForIdentifier:(NSString *)identifier;
@end
@interface HKSeriesSample : HKSample
@property (readonly) NSUInteger count;
@end
@interface HKWorkoutRoute : HKSeriesSample
@end
@interface HKWorkoutRouteQuery : HKQuery
- (instancetype)initWithRoute:(HKWorkoutRoute *)workoutRoute
                  dataHandler:(void (^)(HKWorkoutRouteQuery *query, NSArray<CLLocation *> * _Nullable routeData, BOOL done, NSError * _Nullable error))dataHandler;
- (instancetype)initWithRoute:(HKWorkoutRoute *)workoutRoute dateInterval:(NSDateInterval *)dateInterval
                  dataHandler:(void (^)(HKWorkoutRouteQuery *query, NSArray<CLLocation *> * _Nullable routeData, BOOL done, NSError * _Nullable error))dataHandler;
@end
@interface HKQuery (HKWorkoutPredicates)
+ (NSPredicate *)predicateForWorkoutsWithWorkoutActivityType:(HKWorkoutActivityType)workoutActivityType;
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)operatorType duration:(NSTimeInterval)duration;
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)operatorType quantityType:(HKQuantityType *)quantityType sumQuantity:(HKQuantity *)sumQuantity;
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)operatorType quantityType:(HKQuantityType *)quantityType minimumQuantity:(HKQuantity *)minimumQuantity;
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)operatorType quantityType:(HKQuantityType *)quantityType maximumQuantity:(HKQuantity *)maximumQuantity;
+ (NSPredicate *)predicateForWorkoutsWithOperatorType:(NSPredicateOperatorType)operatorType quantityType:(HKQuantityType *)quantityType averageQuantity:(HKQuantity *)averageQuantity;
+ (NSPredicate *)predicateForWorkoutsWithActivityPredicate:(NSPredicate *)activityPredicate;
+ (NSPredicate *)predicateForWorkoutActivitiesWithWorkoutActivityType:(HKWorkoutActivityType)workoutActivityType;
+ (NSPredicate *)predicateForWorkoutActivitiesWithOperatorType:(NSPredicateOperatorType)operatorType duration:(NSTimeInterval)duration;
+ (NSPredicate *)predicateForWorkoutActivitiesWithStartDate:(nullable NSDate *)startDate endDate:(nullable NSDate *)endDate options:(HKQueryOptions)options;
+ (NSPredicate *)predicateForObjectsFromWorkout:(HKWorkout *)workout;
@end

@class HKWorkoutSession, HKLiveWorkoutBuilder;
@interface HKSeriesBuilder : NSObject
- (void)discard;
- (instancetype)init NS_UNAVAILABLE;
@end
@interface HKWorkoutRouteBuilder : HKSeriesBuilder
- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore device:(nullable HKDevice *)device;
- (void)insertRouteData:(NSArray<CLLocation *> *)routeData completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)addMetadata:(NSDictionary<NSString *, id> *)metadata completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)finishRouteWithWorkout:(HKWorkout *)workout metadata:(nullable NSDictionary<NSString *, id> *)metadata
                    completion:(void (^)(HKWorkoutRoute * _Nullable workoutRoute, NSError * _Nullable error))completion;
@end
@interface HKWorkoutBuilder : NSObject
@property (readonly, copy, nullable) HKDevice *device;
@property (readonly, copy, nullable) NSDate *startDate;
@property (readonly, copy, nullable) NSDate *endDate;
@property (readonly, copy) HKWorkoutConfiguration *workoutConfiguration;
@property (readonly, copy) NSDictionary<NSString *, id> *metadata;
@property (readonly, copy) NSArray<HKWorkoutEvent *> *workoutEvents;
@property (readonly, copy) NSArray<HKWorkoutActivity *> *workoutActivities;
@property (readonly, copy) NSDictionary<HKQuantityType *, HKStatistics *> *allStatistics;
- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore configuration:(HKWorkoutConfiguration *)configuration device:(nullable HKDevice *)device;
- (void)beginCollectionWithStartDate:(NSDate *)startDate completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)addSamples:(NSArray<HKSample *> *)samples completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)addWorkoutEvents:(NSArray<HKWorkoutEvent *> *)workoutEvents completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)addMetadata:(NSDictionary<NSString *, id> *)metadata completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)addWorkoutActivity:(HKWorkoutActivity *)workoutActivity completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)updateActivityWithUUID:(NSUUID *)UUID endDate:(NSDate *)endDate completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)updateActivityWithUUID:(NSUUID *)UUID addMedatata:(NSDictionary<NSString *, id> *)metadata completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)endCollectionWithEndDate:(NSDate *)endDate completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (void)finishWorkoutWithCompletion:(void (^)(HKWorkout * _Nullable workout, NSError * _Nullable error))completion;
- (void)discardWorkout;
- (NSTimeInterval)elapsedTimeAtDate:(NSDate *)date;
- (nullable HKStatistics *)statisticsForType:(HKQuantityType *)quantityType;
- (nullable __kindof HKSeriesBuilder *)seriesBuilderForType:(HKSeriesType *)seriesType;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(17.0))
@protocol HKWorkoutSessionDelegate <NSObject>
- (void)workoutSession:(HKWorkoutSession *)workoutSession didChangeToState:(HKWorkoutSessionState)toState fromState:(HKWorkoutSessionState)fromState date:(NSDate *)date;
- (void)workoutSession:(HKWorkoutSession *)workoutSession didFailWithError:(NSError *)error;
@optional
- (void)workoutSession:(HKWorkoutSession *)workoutSession didGenerateEvent:(HKWorkoutEvent *)event;
- (void)workoutSession:(HKWorkoutSession *)workoutSession didBeginActivityWithConfiguration:(HKWorkoutConfiguration *)workoutConfiguration date:(NSDate *)date;
- (void)workoutSession:(HKWorkoutSession *)workoutSession didEndActivityWithConfiguration:(HKWorkoutConfiguration *)workoutConfiguration date:(NSDate *)date;
- (void)workoutSession:(HKWorkoutSession *)workoutSession didReceiveDataFromRemoteWorkoutSession:(NSArray<NSData *> *)data;
- (void)workoutSession:(HKWorkoutSession *)workoutSession didDisconnectFromRemoteDeviceWithError:(nullable NSError *)error;
@end
API_AVAILABLE(ios(17.0))
@interface HKWorkoutSession : NSObject <NSSecureCoding>
@property (weak, nullable) id<HKWorkoutSessionDelegate> delegate;
@property (readonly) HKWorkoutSessionType type;
@property (readonly) HKWorkoutSessionState state;
@property (readonly, copy) HKWorkoutConfiguration *workoutConfiguration;
@property (readonly, nullable) NSDate *startDate;
@property (readonly, nullable) NSDate *endDate;
@property (readonly, copy) HKWorkoutActivity *currentActivity;
@property (readonly) HKWorkoutActivityType activityType;
@property (readonly) HKWorkoutSessionLocationType locationType;
- (nullable instancetype)initWithHealthStore:(HKHealthStore *)healthStore configuration:(HKWorkoutConfiguration *)workoutConfiguration
                                       error:(NSError **)error API_AVAILABLE(ios(26.0));
- (HKLiveWorkoutBuilder *)associatedWorkoutBuilder API_AVAILABLE(ios(26.0));
- (void)prepare;
- (void)startActivityWithDate:(nullable NSDate *)date;
- (void)pause;
- (void)resume;
- (void)stopActivityWithDate:(nullable NSDate *)date;
- (void)end;
- (void)beginNewActivityWithConfiguration:(HKWorkoutConfiguration *)workoutConfiguration date:(NSDate *)date metadata:(nullable NSDictionary<NSString *, id> *)metadata;
- (void)endCurrentActivityOnDate:(NSDate *)date;
- (void)sendDataToRemoteWorkoutSession:(NSData *)data completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
- (instancetype)init NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(26.0))
@interface HKLiveWorkoutDataSource : NSObject
@property (readonly, copy) NSSet<HKQuantityType *> *typesToCollect;
- (instancetype)initWithHealthStore:(HKHealthStore *)healthStore workoutConfiguration:(nullable HKWorkoutConfiguration *)configuration;
- (void)enableCollectionForType:(HKQuantityType *)quantityType predicate:(nullable NSPredicate *)predicate;
- (void)disableCollectionForType:(HKQuantityType *)quantityType;
- (instancetype)init NS_UNAVAILABLE;
@end
API_AVAILABLE(ios(26.0))
@protocol HKLiveWorkoutBuilderDelegate <NSObject>
- (void)workoutBuilder:(HKLiveWorkoutBuilder *)workoutBuilder didCollectDataOfTypes:(NSSet<HKSampleType *> *)collectedTypes;
- (void)workoutBuilderDidCollectEvent:(HKLiveWorkoutBuilder *)workoutBuilder;
@optional
- (void)workoutBuilder:(HKLiveWorkoutBuilder *)workoutBuilder didBeginActivity:(HKWorkoutActivity *)workoutActivity;
- (void)workoutBuilder:(HKLiveWorkoutBuilder *)workoutBuilder didEndActivity:(HKWorkoutActivity *)workoutActivity;
@end
API_AVAILABLE(ios(26.0))
@interface HKLiveWorkoutBuilder : HKWorkoutBuilder
@property (weak, nullable) id<HKLiveWorkoutBuilderDelegate> delegate;
@property (readonly, weak, nullable) HKWorkoutSession *workoutSession;
@property (assign) BOOL shouldCollectWorkoutEvents;
@property (strong, nullable) HKLiveWorkoutDataSource *dataSource;
@property (readonly, copy, nullable) HKWorkoutActivity *currentWorkoutActivity;
@property (readonly) NSTimeInterval elapsedTime;
@end

@interface HKHealthStore (HKWorkout)
@property (copy, nullable) void (^workoutSessionMirroringStartHandler)(HKWorkoutSession *mirroredSession) API_AVAILABLE(ios(17.0));
- (void)recoverActiveWorkoutSessionWithCompletion:(void (^)(HKWorkoutSession * _Nullable session, NSError * _Nullable error))completion API_AVAILABLE(ios(26.0));
- (void)startWatchAppWithWorkoutConfiguration:(HKWorkoutConfiguration *)workoutConfiguration completion:(void (^)(BOOL success, NSError * _Nullable error))completion;
@end

NS_ASSUME_NONNULL_END
#endif
