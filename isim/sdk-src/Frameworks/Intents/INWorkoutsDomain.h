/* isim Intents: the workouts domain (issue #411). Imported by <Intents/Intents.h>. isim: "start a 5 mile run", "start an
 * indoor cycle", "pause my workout", "resume my workout", "end my workout", "cancel my workout" (or `siri intent
 * StartWorkout name=run goal=5 unit=mile location=outdoor`). Workout apps usually answer handleInApp: Siri hands the
 * intent to the app's application(_:handle:completionHandler:) in the background, as iOS does. */
#pragma once
NS_ASSUME_NONNULL_BEGIN

typedef NSString *INWorkoutNameIdentifier NS_TYPED_ENUM API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierRun API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierSit API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierSteps API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierStand API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierMove API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierWalk API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierYoga API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierDance API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierCrosstraining API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierElliptical API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierRower API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierCycle API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierStairs API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierOther API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierIndoorrun API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierIndoorcycle API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierIndoorwalk API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierExercise API_AVAILABLE(ios(10.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierHike API_AVAILABLE(ios(12.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierHighIntensityIntervalTraining API_AVAILABLE(ios(12.0));
INTENTS_EXTERN INWorkoutNameIdentifier const INWorkoutNameIdentifierSwim API_AVAILABLE(ios(12.0));

typedef NS_ENUM(NSInteger, INWorkoutGoalUnitType) {
    INWorkoutGoalUnitTypeUnknown = 0,
    INWorkoutGoalUnitTypeInch,
    INWorkoutGoalUnitTypeMeter,
    INWorkoutGoalUnitTypeFoot,
    INWorkoutGoalUnitTypeMile,
    INWorkoutGoalUnitTypeYard,
    INWorkoutGoalUnitTypeSecond,
    INWorkoutGoalUnitTypeMinute,
    INWorkoutGoalUnitTypeHour,
    INWorkoutGoalUnitTypeJoule,
    INWorkoutGoalUnitTypeKiloCalorie,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INWorkoutGoalUnitTypeResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedWorkoutGoalUnitType:(INWorkoutGoalUnitType)resolvedWorkoutGoalUnitType NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithWorkoutGoalUnitTypeToConfirm:(INWorkoutGoalUnitType)workoutGoalUnitTypeToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
typedef NS_ENUM(NSInteger, INWorkoutLocationType) {
    INWorkoutLocationTypeUnknown = 0,
    INWorkoutLocationTypeOutdoor,
    INWorkoutLocationTypeIndoor,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INWorkoutLocationTypeResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedWorkoutLocationType:(INWorkoutLocationType)resolvedWorkoutLocationType NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithWorkoutLocationTypeToConfirm:(INWorkoutLocationType)workoutLocationTypeToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end

/* ---------------- starting a workout ---------------- */
API_AVAILABLE(ios(10.0))
@interface INStartWorkoutIntent : INIntent
- (instancetype)initWithWorkoutName:(nullable INSpeakableString *)workoutName goalValue:(nullable NSNumber *)goalValue workoutGoalUnitType:(INWorkoutGoalUnitType)workoutGoalUnitType workoutLocationType:(INWorkoutLocationType)workoutLocationType isOpenEnded:(nullable NSNumber *)isOpenEnded NS_REFINED_FOR_SWIFT;
@property (readonly, copy, nullable) INSpeakableString *workoutName;
@property (readonly, copy, nullable) NSNumber *goalValue NS_REFINED_FOR_SWIFT;
@property (readonly) INWorkoutGoalUnitType workoutGoalUnitType;
@property (readonly) INWorkoutLocationType workoutLocationType;
@property (readonly, copy, nullable) NSNumber *isOpenEnded NS_REFINED_FOR_SWIFT;
@end
typedef NS_ENUM(NSInteger, INStartWorkoutIntentResponseCode) {
    INStartWorkoutIntentResponseCodeUnspecified = 0,
    INStartWorkoutIntentResponseCodeReady,
    INStartWorkoutIntentResponseCodeContinueInApp API_DEPRECATED("INStartWorkoutIntentResponseCodeContinueInApp is deprecated on iOS. Please use INStartWorkoutIntentResponseCodeHandleInApp instead", ios(10.0, 12.0)),
    INStartWorkoutIntentResponseCodeFailure,
    INStartWorkoutIntentResponseCodeFailureRequiringAppLaunch,
    INStartWorkoutIntentResponseCodeFailureOngoingWorkout,
    INStartWorkoutIntentResponseCodeFailureNoMatchingWorkout,
    INStartWorkoutIntentResponseCodeSuccess API_AVAILABLE(ios(11.0)),
    INStartWorkoutIntentResponseCodeHandleInApp API_AVAILABLE(ios(11.0)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INStartWorkoutIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INStartWorkoutIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INStartWorkoutIntentResponseCode code;
@end
API_AVAILABLE(ios(10.0))
@protocol INStartWorkoutIntentHandling <NSObject>
@required
- (void)handleStartWorkout:(INStartWorkoutIntent *)intent completion:(void (^)(INStartWorkoutIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmStartWorkout:(INStartWorkoutIntent *)intent completion:(void (^)(INStartWorkoutIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveWorkoutNameForStartWorkout:(INStartWorkoutIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveWorkoutName(for:with:));
- (void)resolveGoalValueForStartWorkout:(INStartWorkoutIntent *)intent withCompletion:(void (^)(INDoubleResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveGoalValue(for:with:));
- (void)resolveWorkoutGoalUnitTypeForStartWorkout:(INStartWorkoutIntent *)intent withCompletion:(void (^)(INWorkoutGoalUnitTypeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveWorkoutGoalUnitType(for:with:));
- (void)resolveWorkoutLocationTypeForStartWorkout:(INStartWorkoutIntent *)intent withCompletion:(void (^)(INWorkoutLocationTypeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveWorkoutLocationType(for:with:));
- (void)resolveIsOpenEndedForStartWorkout:(INStartWorkoutIntent *)intent withCompletion:(void (^)(INBooleanResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveIsOpenEnded(for:with:));
@end

/* ---------------- pausing, resuming, ending and cancelling it ---------------- */
#define IN_WORKOUT_CONTROL(Verb) \
API_AVAILABLE(ios(10.0)) \
@interface IN##Verb##WorkoutIntent : INIntent \
- (instancetype)initWithWorkoutName:(nullable INSpeakableString *)workoutName; \
@property (readonly, copy, nullable) INSpeakableString *workoutName; \
@end \
typedef NS_ENUM(NSInteger, IN##Verb##WorkoutIntentResponseCode) { \
    IN##Verb##WorkoutIntentResponseCodeUnspecified = 0, \
    IN##Verb##WorkoutIntentResponseCodeReady, \
    IN##Verb##WorkoutIntentResponseCodeContinueInApp API_DEPRECATED("ContinueInApp is deprecated on iOS. Please use HandleInApp instead", ios(10.0, 12.0)), \
    IN##Verb##WorkoutIntentResponseCodeFailure, \
    IN##Verb##WorkoutIntentResponseCodeFailureRequiringAppLaunch, \
    IN##Verb##WorkoutIntentResponseCodeFailureNoMatchingWorkout, \
    IN##Verb##WorkoutIntentResponseCodeHandleInApp API_AVAILABLE(ios(11.0)), \
    IN##Verb##WorkoutIntentResponseCodeSuccess API_AVAILABLE(ios(11.0)), \
} API_AVAILABLE(ios(10.0)); \
API_AVAILABLE(ios(10.0)) \
@interface IN##Verb##WorkoutIntentResponse : INIntentResponse \
- (instancetype)initWithCode:(IN##Verb##WorkoutIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER; \
@property (readonly) IN##Verb##WorkoutIntentResponseCode code; \
@end \
API_AVAILABLE(ios(10.0)) \
@protocol IN##Verb##WorkoutIntentHandling <NSObject> \
@required \
- (void)handle##Verb##Workout:(IN##Verb##WorkoutIntent *)intent completion:(void (^)(IN##Verb##WorkoutIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:)); \
@optional \
- (void)confirm##Verb##Workout:(IN##Verb##WorkoutIntent *)intent completion:(void (^)(IN##Verb##WorkoutIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:)); \
- (void)resolveWorkoutNameFor##Verb##Workout:(IN##Verb##WorkoutIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveWorkoutName(for:with:)); \
@end
IN_WORKOUT_CONTROL(Pause)
IN_WORKOUT_CONTROL(Resume)
IN_WORKOUT_CONTROL(End)
IN_WORKOUT_CONTROL(Cancel)
#undef IN_WORKOUT_CONTROL

/* the workouts domain */
API_AVAILABLE(ios(10.0))
@protocol INWorkoutsDomainHandling <INStartWorkoutIntentHandling, INPauseWorkoutIntentHandling, INEndWorkoutIntentHandling, INCancelWorkoutIntentHandling, INResumeWorkoutIntentHandling>
@end

INTENTS_EXTERN NSString *const INStartWorkoutIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INPauseWorkoutIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INResumeWorkoutIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INEndWorkoutIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INCancelWorkoutIntentIdentifier API_AVAILABLE(ios(10.0));

NS_ASSUME_NONNULL_END
