/* isim Intents: the ride booking domain (issue #411). Imported by <Intents/Intents.h>. isim: "get me a ride to Apple
 * Park", "where's my ride", "cancel my ride" (or `siri intent RequestRide dropOff=PLACE pickup=PLACE`). Places are
 * CLPlacemarks (IN_PLACEMARK: an object in Swift, typed by isim's Intents overlay); Siri finds a named place in
 * CoreLocation's offline gazetteer, or passes the name alone. Siri lists the app's ride options, then confirms the ride
 * before booking it, as iOS does. */
#pragma once
NS_ASSUME_NONNULL_BEGIN

/* prices */
API_AVAILABLE(ios(10.0))
@interface INPriceRange : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithRangeBetweenPrice:(NSDecimalNumber *)firstPrice andPrice:(NSDecimalNumber *)secondPrice currencyCode:(NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithMaximumPrice:(NSDecimalNumber *)maximumPrice currencyCode:(NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithMinimumPrice:(NSDecimalNumber *)minimumPrice currencyCode:(NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithPrice:(NSDecimalNumber *)price currencyCode:(NSString *)currencyCode;
@property (readonly, nullable) NSDecimalNumber *minimumPrice;
@property (readonly, nullable) NSDecimalNumber *maximumPrice;
@property (readonly) NSString *currencyCode;
@end
API_AVAILABLE(ios(10.0))
@interface INRideFareLineItem : NSObject <NSCopying, NSSecureCoding>
- (null_unspecified instancetype)initWithTitle:(null_unspecified NSString *)title price:(null_unspecified NSDecimalNumber *)price currencyCode:(null_unspecified NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
@property (readonly, null_unspecified) NSString *title;
@property (readonly, null_unspecified) NSDecimalNumber *price;
@property (readonly, null_unspecified) NSString *currencyCode;
@end
API_AVAILABLE(ios(10.0))
@interface INRidePartySizeOption : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithPartySizeRange:(NSRange)partySizeRange sizeDescription:(NSString *)sizeDescription priceRange:(nullable INPriceRange *)priceRange NS_DESIGNATED_INITIALIZER;
@property (readonly) NSRange partySizeRange;
@property (readonly) NSString *sizeDescription;
@property (readonly, nullable) INPriceRange *priceRange;
@end

/* a kind of ride the app offers (UberX, a shared ride, …) */
API_AVAILABLE(ios(10.0))
@interface INRideOption : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithName:(NSString *)name estimatedPickupDate:(NSDate *)estimatedPickupDate NS_DESIGNATED_INITIALIZER;
@property (readwrite, copy) NSString *name;
@property (readwrite, copy) NSDate *estimatedPickupDate;
@property (readwrite, copy, nullable) INPriceRange *priceRange;
@property (readwrite, copy, nullable) NSNumber *usesMeteredFare NS_REFINED_FOR_SWIFT;
@property (readwrite, copy, nullable) NSString *disclaimerMessage;
@property (readwrite, copy, nullable) NSArray<INRidePartySizeOption *> *availablePartySizeOptions;
@property (readwrite, copy, nullable) NSString *availablePartySizeOptionsSelectionPrompt;
@property (readwrite, copy, nullable) NSString *specialPricing;
@property (readwrite, copy, nullable) INImage *specialPricingBadgeImage;
@property (readwrite, copy, nullable) NSArray<INRideFareLineItem *> *fareLineItems;
@property (readwrite, strong, nullable) NSUserActivity *userActivityForBookingInApplication;
@property (readwrite, copy, nullable) NSString *identifier API_AVAILABLE(ios(11.0));
@end

/* the driver and the car */
API_AVAILABLE(ios(10.0))
@interface INRideDriver : INPerson
- (instancetype)initWithPhoneNumber:(NSString *)phoneNumber nameComponents:(nullable NSPersonNameComponents *)nameComponents displayName:(nullable NSString *)displayName image:(nullable INImage *)image rating:(nullable NSString *)rating NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(10.2));
- (instancetype)initWithHandle:(NSString *)handle displayName:(nullable NSString *)displayName image:(nullable INImage *)image rating:(nullable NSString *)rating phoneNumber:(nullable NSString *)phoneNumber API_DEPRECATED("Use the designated initializer instead", ios(10.0, 10.0));
- (instancetype)initWithHandle:(NSString *)handle nameComponents:(NSPersonNameComponents *)nameComponents image:(nullable INImage *)image rating:(nullable NSString *)rating phoneNumber:(nullable NSString *)phoneNumber API_DEPRECATED("Use the designated initializer instead", ios(10.0, 10.0));
- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle nameComponents:(nullable NSPersonNameComponents *)nameComponents displayName:(nullable NSString *)displayName image:(nullable INImage *)image rating:(nullable NSString *)rating phoneNumber:(nullable NSString *)phoneNumber API_DEPRECATED("Use the designated initializer instead", ios(10.0, 10.2));
@property (readonly, copy, nullable) NSString *rating;
@property (readonly, copy, nullable) NSString *phoneNumber;
@end
API_AVAILABLE(ios(10.0))
@interface INRideVehicle : NSObject <NSCopying, NSSecureCoding>
@property (readwrite, copy, nullable) IN_LOCATION location IN_REFINED_FOR_SWIFT_CL;
@property (readwrite, copy, nullable) NSString *registrationPlate;
@property (readwrite, copy, nullable) NSString *manufacturer;
@property (readwrite, copy, nullable) NSString *model;
@property (readwrite, copy, nullable) INImage *mapAnnotationImage;
@end

/* how a ride ended */
typedef NS_OPTIONS(NSUInteger, INRideFeedbackTypeOptions) {
    INRideFeedbackTypeOptionRate = (1UL << 0),
    INRideFeedbackTypeOptionTip = (1UL << 1),
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(10.0))
@interface INRideCompletionStatus : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)completed;
+ (instancetype)completedWithSettledPaymentAmount:(INCurrencyAmount *)settledPaymentAmount NS_SWIFT_NAME(completed(settled:));
+ (instancetype)completedWithOutstandingPaymentAmount:(INCurrencyAmount *)outstandingPaymentAmount NS_SWIFT_NAME(completed(outstanding:));
+ (instancetype)completedWithFeedbackType:(INRideFeedbackTypeOptions)feedbackType NS_SWIFT_NAME(completed(feedbackType:)) API_AVAILABLE(ios(11.0));
+ (instancetype)canceledByService;
+ (instancetype)canceledByUser;
+ (instancetype)canceledMissedPickup;
@property (readwrite, strong, nullable) NSUserActivity *completionUserActivity;
@property (readonly, getter=isCompleted) BOOL completed;
@property (readonly, getter=isCanceled) BOOL canceled;
@property (readonly, getter=isMissedPickup) BOOL missedPickup;
@property (readonly, copy, nullable) INCurrencyAmount *paymentAmount;
@property (readonly) INRideFeedbackTypeOptions feedbackType API_AVAILABLE(ios(11.0));
@property (readonly, getter=isOutstanding) BOOL outstanding;
@property (readwrite, copy, nullable) NSSet<INCurrencyAmount *> *defaultTippingOptions API_AVAILABLE(ios(11.0));
@end

/* where a ride is */
typedef NS_ENUM(NSInteger, INRidePhase) {
    INRidePhaseUnknown = 0,
    INRidePhaseReceived,
    INRidePhaseConfirmed,
    INRidePhaseOngoing,
    INRidePhaseCompleted,
    INRidePhaseApproachingPickup,
    INRidePhasePickup,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INRideStatus : NSObject <NSCopying, NSSecureCoding>
@property (readwrite, copy, nullable) NSString *rideIdentifier;
@property (readwrite, assign) INRidePhase phase;
@property (readwrite, copy, nullable) INRideCompletionStatus *completionStatus;
@property (readwrite, copy, nullable) INRideVehicle *vehicle;
@property (readwrite, copy, nullable) INRideDriver *driver;
@property (readwrite, copy, nullable) NSDate *estimatedPickupDate;
@property (readwrite, copy, nullable) NSDate *estimatedDropOffDate;
@property (readwrite, copy, nullable) NSDate *estimatedPickupEndDate;
@property (readwrite, copy, nullable) INDateComponentsRange *scheduledPickupTime API_AVAILABLE(ios(10.3));
@property (readwrite, copy, nullable) IN_PLACEMARK pickupLocation IN_REFINED_FOR_SWIFT_CL;
@property (readwrite, copy, nullable) NSArray *waypoints IN_REFINED_FOR_SWIFT_CL;
@property (readwrite, copy, nullable) IN_PLACEMARK dropOffLocation IN_REFINED_FOR_SWIFT_CL;
@property (readwrite, copy, nullable) INRideOption *rideOption;
@property (readwrite, strong, nullable) NSUserActivity *userActivityForCancelingInApplication;
@property (readwrite, copy, nullable) NSArray<NSUserActivity *> *additionalActionActivities API_AVAILABLE(ios(10.3));
@end

/* ---------------- ride options ---------------- */
API_AVAILABLE(ios(10.0))
@interface INListRideOptionsIntent : INIntent
- (instancetype)initWithPickupLocation:(nullable IN_PLACEMARK)pickupLocation dropOffLocation:(nullable IN_PLACEMARK)dropOffLocation IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) IN_PLACEMARK pickupLocation IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) IN_PLACEMARK dropOffLocation IN_REFINED_FOR_SWIFT_CL;
@end
typedef NS_ENUM(NSInteger, INListRideOptionsIntentResponseCode) {
    INListRideOptionsIntentResponseCodeUnspecified = 0,
    INListRideOptionsIntentResponseCodeReady,
    INListRideOptionsIntentResponseCodeInProgress,
    INListRideOptionsIntentResponseCodeSuccess,
    INListRideOptionsIntentResponseCodeFailure,
    INListRideOptionsIntentResponseCodeFailureRequiringAppLaunch,
    INListRideOptionsIntentResponseCodeFailureRequiringAppLaunchMustVerifyCredentials,
    INListRideOptionsIntentResponseCodeFailureRequiringAppLaunchNoServiceInArea,
    INListRideOptionsIntentResponseCodeFailureRequiringAppLaunchServiceTemporarilyUnavailable,
    INListRideOptionsIntentResponseCodeFailureRequiringAppLaunchPreviousRideNeedsCompletion,
    INListRideOptionsIntentResponseCodeFailurePreviousRideNeedsFeedback API_AVAILABLE(ios(11.0)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INListRideOptionsIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INListRideOptionsIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INListRideOptionsIntentResponseCode code;
@property (readwrite, copy, nullable) NSArray<INRideOption *> *rideOptions;
@property (readwrite, copy, nullable) NSArray<INPaymentMethod *> *paymentMethods;
@property (readwrite, copy, nullable) NSDate *expirationDate;
@end
API_AVAILABLE(ios(10.0))
@protocol INListRideOptionsIntentHandling <NSObject>
@required
- (void)handleListRideOptions:(INListRideOptionsIntent *)intent completion:(void (^)(INListRideOptionsIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmListRideOptions:(INListRideOptionsIntent *)intent completion:(void (^)(INListRideOptionsIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolvePickupLocationForListRideOptions:(INListRideOptionsIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePickupLocation(for:with:));
- (void)resolveDropOffLocationForListRideOptions:(INListRideOptionsIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveDropOffLocation(for:with:));
@end

/* ---------------- booking a ride ---------------- */
API_AVAILABLE(ios(10.0))
@interface INRequestRideIntent : INIntent
- (instancetype)initWithPickupLocation:(nullable IN_PLACEMARK)pickupLocation dropOffLocation:(nullable IN_PLACEMARK)dropOffLocation rideOptionName:(nullable INSpeakableString *)rideOptionName partySize:(nullable NSNumber *)partySize paymentMethod:(nullable INPaymentMethod *)paymentMethod scheduledPickupTime:(nullable INDateComponentsRange *)scheduledPickupTime NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(10.3));
@property (readonly, copy, nullable) IN_PLACEMARK pickupLocation IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) IN_PLACEMARK dropOffLocation IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) INSpeakableString *rideOptionName;
@property (readonly, copy, nullable) NSNumber *partySize NS_REFINED_FOR_SWIFT;
@property (readonly, copy, nullable) INPaymentMethod *paymentMethod;
@property (readonly, copy, nullable) INDateComponentsRange *scheduledPickupTime API_AVAILABLE(ios(10.3));
@end
typedef NS_ENUM(NSInteger, INRequestRideIntentResponseCode) {
    INRequestRideIntentResponseCodeUnspecified = 0,
    INRequestRideIntentResponseCodeReady,
    INRequestRideIntentResponseCodeInProgress,
    INRequestRideIntentResponseCodeSuccess,
    INRequestRideIntentResponseCodeFailure,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunch,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunchMustVerifyCredentials,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunchNoServiceInArea,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunchServiceTemporarilyUnavailable,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunchPreviousRideNeedsCompletion,
    INRequestRideIntentResponseCodeFailureRequiringAppLaunchRideScheduledTooFar API_AVAILABLE(ios(10.3)),
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INRequestRideIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INRequestRideIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INRequestRideIntentResponseCode code;
@property (readwrite, copy, nullable) INRideStatus *rideStatus;
@end
API_AVAILABLE(ios(10.0))
@protocol INRequestRideIntentHandling <NSObject>
@required
- (void)handleRequestRide:(INRequestRideIntent *)intent completion:(void (^)(INRequestRideIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmRequestRide:(INRequestRideIntent *)intent completion:(void (^)(INRequestRideIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolvePickupLocationForRequestRide:(INRequestRideIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePickupLocation(for:with:));
- (void)resolveDropOffLocationForRequestRide:(INRequestRideIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveDropOffLocation(for:with:));
- (void)resolveRideOptionNameForRequestRide:(INRequestRideIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveRideOptionName(for:with:));
- (void)resolvePartySizeForRequestRide:(INRequestRideIntent *)intent withCompletion:(void (^)(INIntegerResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePartySize(for:with:));
- (void)resolveScheduledPickupTimeForRequestRide:(INRequestRideIntent *)intent withCompletion:(void (^)(INDateComponentsRangeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveScheduledPickupTime(for:with:)) API_AVAILABLE(ios(10.3));
@end

/* ---------------- the ride's status ---------------- */
API_AVAILABLE(ios(10.0))
@interface INGetRideStatusIntent : INIntent
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@end
typedef NS_ENUM(NSInteger, INGetRideStatusIntentResponseCode) {
    INGetRideStatusIntentResponseCodeUnspecified = 0,
    INGetRideStatusIntentResponseCodeReady,
    INGetRideStatusIntentResponseCodeInProgress,
    INGetRideStatusIntentResponseCodeSuccess,
    INGetRideStatusIntentResponseCodeFailure,
    INGetRideStatusIntentResponseCodeFailureRequiringAppLaunch,
    INGetRideStatusIntentResponseCodeFailureRequiringAppLaunchMustVerifyCredentials,
    INGetRideStatusIntentResponseCodeFailureRequiringAppLaunchServiceTemporarilyUnavailable,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INGetRideStatusIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INGetRideStatusIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INGetRideStatusIntentResponseCode code;
@property (readwrite, copy, nullable) INRideStatus *rideStatus;
@end
/* isim: Siri shows each update the app sends while its answer is on screen */
API_AVAILABLE(ios(10.0))
@protocol INGetRideStatusIntentResponseObserver <NSObject>
- (void)getRideStatusResponseDidUpdate:(INGetRideStatusIntentResponse *)response NS_SWIFT_NAME(didUpdate(getRideStatus:));
@end
API_AVAILABLE(ios(10.0))
@protocol INGetRideStatusIntentHandling <NSObject>
@required
- (void)handleGetRideStatus:(INGetRideStatusIntent *)intent completion:(void (^)(INGetRideStatusIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
- (void)startSendingUpdatesForGetRideStatus:(INGetRideStatusIntent *)intent toObserver:(id<INGetRideStatusIntentResponseObserver>)observer NS_SWIFT_NAME(startSendingUpdates(for:to:));
- (void)stopSendingUpdatesForGetRideStatus:(INGetRideStatusIntent *)intent NS_SWIFT_NAME(stopSendingUpdates(for:));
@optional
- (void)confirmGetRideStatus:(INGetRideStatusIntent *)intent completion:(void (^)(INGetRideStatusIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
@end

/* ---------------- cancelling a ride, and feedback ---------------- */
API_AVAILABLE(ios(11.0))
@interface INCancelRideIntent : INIntent
- (instancetype)initWithRideIdentifier:(NSString *)rideIdentifier;
@property (readonly, copy) NSString *rideIdentifier;
@end
typedef NS_ENUM(NSInteger, INCancelRideIntentResponseCode) {
    INCancelRideIntentResponseCodeUnspecified = 0,
    INCancelRideIntentResponseCodeReady,
    INCancelRideIntentResponseCodeSuccess,
    INCancelRideIntentResponseCodeFailure,
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INCancelRideIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INCancelRideIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INCancelRideIntentResponseCode code;
@property (readwrite, copy, nullable) INCurrencyAmount *cancellationFee;
@property (readwrite, copy, nullable) NSDateComponents *cancellationFeeThreshold;
@end
API_AVAILABLE(ios(11.0))
@protocol INCancelRideIntentHandling <NSObject>
@required
- (void)handleCancelRide:(INCancelRideIntent *)intent completion:(void (^)(INCancelRideIntentResponse *response))completion NS_SWIFT_NAME(handle(cancelRide:completion:));
@optional
- (void)confirmCancelRide:(INCancelRideIntent *)intent completion:(void (^)(INCancelRideIntentResponse *response))completion NS_SWIFT_NAME(confirm(cancelRide:completion:));
@end
API_AVAILABLE(ios(11.0))
@interface INSendRideFeedbackIntent : INIntent
- (instancetype)initWithRideIdentifier:(NSString *)rideIdentifier;
@property (readonly) NSString *rideIdentifier;
@property (readwrite, copy, nullable) NSNumber *rating;
@property (readwrite, copy, nullable) INCurrencyAmount *tip;
@end
typedef NS_ENUM(NSInteger, INSendRideFeedbackIntentResponseCode) {
    INSendRideFeedbackIntentResponseCodeUnspecified = 0,
    INSendRideFeedbackIntentResponseCodeReady,
    INSendRideFeedbackIntentResponseCodeSuccess,
    INSendRideFeedbackIntentResponseCodeFailure,
} API_AVAILABLE(ios(11.0));
API_AVAILABLE(ios(11.0))
@interface INSendRideFeedbackIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSendRideFeedbackIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSendRideFeedbackIntentResponseCode code;
@end
API_AVAILABLE(ios(11.0))
@protocol INSendRideFeedbackIntentHandling <NSObject>
@required
- (void)handleSendRideFeedback:(INSendRideFeedbackIntent *)sendRideFeedbackintent completion:(void (^)(INSendRideFeedbackIntentResponse *response))completion NS_SWIFT_NAME(handle(sendRideFeedback:completion:));
@optional
- (void)confirmSendRideFeedback:(INSendRideFeedbackIntent *)sendRideFeedbackIntent completion:(void (^)(INSendRideFeedbackIntentResponse *response))completion NS_SWIFT_NAME(confirm(sendRideFeedback:completion:));
@end

/* the ride booking domain */
API_AVAILABLE(ios(10.0))
@protocol INRidesharingDomainHandling <INListRideOptionsIntentHandling, INRequestRideIntentHandling, INGetRideStatusIntentHandling, INCancelRideIntentHandling, INSendRideFeedbackIntentHandling>
@end

INTENTS_EXTERN NSString *const INListRideOptionsIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INRequestRideIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INGetRideStatusIntentIdentifier API_AVAILABLE(ios(10.0));

NS_ASSUME_NONNULL_END
