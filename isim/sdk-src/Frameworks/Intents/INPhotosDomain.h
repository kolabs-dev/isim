/* isim Intents: the photos domain (issue #411). Imported by <Intents/Intents.h>. isim: "show photos from Apple Park",
 * "find photos of Anna", "show my Vacation album", "play a slideshow of my Vacation album" (or `siri intent
 * SearchForPhotos album=NAME location=PLACE people=NAME terms=WORD`). The photos domain continues in the app: Siri
 * opens it with the intent in its NSUserActivity's interaction, as iOS does. */
#pragma once
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, INPhotoAttributeOptions) {
    INPhotoAttributeOptionPhoto = (1UL << 0),
    INPhotoAttributeOptionVideo = (1UL << 1),
    INPhotoAttributeOptionGIF NS_SWIFT_NAME(GIF) = (1UL << 2),
    INPhotoAttributeOptionFlash = (1UL << 3),
    INPhotoAttributeOptionLandscapeOrientation = (1UL << 4),
    INPhotoAttributeOptionPortraitOrientation = (1UL << 5),
    INPhotoAttributeOptionFavorite = (1UL << 6),
    INPhotoAttributeOptionSelfie = (1UL << 7),
    INPhotoAttributeOptionFrontFacingCamera = (1UL << 8),
    INPhotoAttributeOptionScreenshot = (1UL << 9),
    INPhotoAttributeOptionBurstPhoto = (1UL << 10),
    INPhotoAttributeOptionHDRPhoto = (1UL << 11),
    INPhotoAttributeOptionSquarePhoto = (1UL << 12),
    INPhotoAttributeOptionPanoramaPhoto = (1UL << 13),
    INPhotoAttributeOptionTimeLapseVideo = (1UL << 14),
    INPhotoAttributeOptionSlowMotionVideo = (1UL << 15),
    INPhotoAttributeOptionNoirFilter = (1UL << 16),
    INPhotoAttributeOptionChromeFilter = (1UL << 17),
    INPhotoAttributeOptionInstantFilter = (1UL << 18),
    INPhotoAttributeOptionTonalFilter = (1UL << 19),
    INPhotoAttributeOptionTransferFilter = (1UL << 20),
    INPhotoAttributeOptionMonoFilter = (1UL << 21),
    INPhotoAttributeOptionFadeFilter = (1UL << 22),
    INPhotoAttributeOptionProcessFilter = (1UL << 23),
    INPhotoAttributeOptionPortraitPhoto API_AVAILABLE(ios(11.0)) = (1UL << 24),
    INPhotoAttributeOptionLivePhoto API_AVAILABLE(ios(11.0)) = (1UL << 25),
    INPhotoAttributeOptionLoopPhoto API_AVAILABLE(ios(11.0)) = (1UL << 26),
    INPhotoAttributeOptionBouncePhoto API_AVAILABLE(ios(11.0)) = (1UL << 27),
    INPhotoAttributeOptionLongExposurePhoto API_AVAILABLE(ios(11.0)) = (1UL << 28),
} API_AVAILABLE(ios(10.0));

/* ---------------- searching for photos ---------------- */
API_AVAILABLE(ios(10.0))
@interface INSearchForPhotosIntent : INIntent
- (instancetype)initWithDateCreated:(nullable INDateComponentsRange *)dateCreated locationCreated:(nullable IN_PLACEMARK)locationCreated albumName:(nullable NSString *)albumName searchTerms:(nullable NSArray<NSString *> *)searchTerms includedAttributes:(INPhotoAttributeOptions)includedAttributes excludedAttributes:(INPhotoAttributeOptions)excludedAttributes peopleInPhoto:(nullable NSArray<INPerson *> *)peopleInPhoto IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) INDateComponentsRange *dateCreated;
@property (readonly, copy, nullable) IN_PLACEMARK locationCreated IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) NSString *albumName;
@property (readonly, copy, nullable) NSArray<NSString *> *searchTerms;
@property (readonly, assign) INConditionalOperator searchTermsOperator;
@property (readonly, assign) INPhotoAttributeOptions includedAttributes;
@property (readonly, assign) INPhotoAttributeOptions excludedAttributes;
@property (readonly, copy, nullable) NSArray<INPerson *> *peopleInPhoto;
@property (readonly, assign) INConditionalOperator peopleInPhotoOperator;
@end
typedef NS_ENUM(NSInteger, INSearchForPhotosIntentResponseCode) {
    INSearchForPhotosIntentResponseCodeUnspecified = 0,
    INSearchForPhotosIntentResponseCodeReady,
    INSearchForPhotosIntentResponseCodeContinueInApp,
    INSearchForPhotosIntentResponseCodeFailure,
    INSearchForPhotosIntentResponseCodeFailureRequiringAppLaunch,
    INSearchForPhotosIntentResponseCodeFailureAppConfigurationRequired,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INSearchForPhotosIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSearchForPhotosIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSearchForPhotosIntentResponseCode code;
@property (readwrite, copy, nullable) NSNumber *searchResultsCount NS_REFINED_FOR_SWIFT;
@end
API_AVAILABLE(ios(10.0))
@protocol INSearchForPhotosIntentHandling <NSObject>
@required
- (void)handleSearchForPhotos:(INSearchForPhotosIntent *)intent completion:(void (^)(INSearchForPhotosIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmSearchForPhotos:(INSearchForPhotosIntent *)intent completion:(void (^)(INSearchForPhotosIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveDateCreatedForSearchForPhotos:(INSearchForPhotosIntent *)intent withCompletion:(void (^)(INDateComponentsRangeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveDateCreated(for:with:));
- (void)resolveLocationCreatedForSearchForPhotos:(INSearchForPhotosIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveLocationCreated(for:with:));
- (void)resolveAlbumNameForSearchForPhotos:(INSearchForPhotosIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveAlbumName(for:with:));
- (void)resolveSearchTermsForSearchForPhotos:(INSearchForPhotosIntent *)intent withCompletion:(void (^)(NSArray<INStringResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveSearchTerms(for:with:)) API_AVAILABLE(ios(11.0));
- (void)resolvePeopleInPhotoForSearchForPhotos:(INSearchForPhotosIntent *)intent withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolvePeopleInPhoto(for:with:));
@end

/* ---------------- a slideshow ---------------- */
API_AVAILABLE(ios(10.0))
@interface INStartPhotoPlaybackIntent : INIntent
- (instancetype)initWithDateCreated:(nullable INDateComponentsRange *)dateCreated locationCreated:(nullable IN_PLACEMARK)locationCreated albumName:(nullable NSString *)albumName searchTerms:(nullable NSArray<NSString *> *)searchTerms includedAttributes:(INPhotoAttributeOptions)includedAttributes excludedAttributes:(INPhotoAttributeOptions)excludedAttributes peopleInPhoto:(nullable NSArray<INPerson *> *)peopleInPhoto IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) INDateComponentsRange *dateCreated;
@property (readonly, copy, nullable) IN_PLACEMARK locationCreated IN_REFINED_FOR_SWIFT_CL;
@property (readonly, copy, nullable) NSString *albumName;
@property (readonly, copy, nullable) NSArray<NSString *> *searchTerms;
@property (readonly, assign) INConditionalOperator searchTermsOperator;
@property (readonly, assign) INPhotoAttributeOptions includedAttributes;
@property (readonly, assign) INPhotoAttributeOptions excludedAttributes;
@property (readonly, copy, nullable) NSArray<INPerson *> *peopleInPhoto;
@property (readonly, assign) INConditionalOperator peopleInPhotoOperator;
@end
typedef NS_ENUM(NSInteger, INStartPhotoPlaybackIntentResponseCode) {
    INStartPhotoPlaybackIntentResponseCodeUnspecified = 0,
    INStartPhotoPlaybackIntentResponseCodeReady,
    INStartPhotoPlaybackIntentResponseCodeContinueInApp,
    INStartPhotoPlaybackIntentResponseCodeFailure,
    INStartPhotoPlaybackIntentResponseCodeFailureRequiringAppLaunch,
    INStartPhotoPlaybackIntentResponseCodeFailureAppConfigurationRequired,
} API_AVAILABLE(ios(10.0));
API_AVAILABLE(ios(10.0))
@interface INStartPhotoPlaybackIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INStartPhotoPlaybackIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INStartPhotoPlaybackIntentResponseCode code;
@property (readwrite, copy, nullable) NSNumber *searchResultsCount NS_REFINED_FOR_SWIFT;
@end
API_AVAILABLE(ios(10.0))
@protocol INStartPhotoPlaybackIntentHandling <NSObject>
@required
- (void)handleStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent completion:(void (^)(INStartPhotoPlaybackIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent completion:(void (^)(INStartPhotoPlaybackIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveDateCreatedForStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent withCompletion:(void (^)(INDateComponentsRangeResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveDateCreated(for:with:));
- (void)resolveLocationCreatedForStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent withCompletion:(void (^)(INPlacemarkResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveLocationCreated(for:with:));
- (void)resolveAlbumNameForStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveAlbumName(for:with:));
- (void)resolvePeopleInPhotoForStartPhotoPlayback:(INStartPhotoPlaybackIntent *)intent withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolvePeopleInPhoto(for:with:));
@end

/* the photos domain */
API_AVAILABLE(ios(10.0))
@protocol INPhotosDomainHandling <INSearchForPhotosIntentHandling, INStartPhotoPlaybackIntentHandling>
@end

INTENTS_EXTERN NSString *const INSearchForPhotosIntentIdentifier API_AVAILABLE(ios(10.0));
INTENTS_EXTERN NSString *const INStartPhotoPlaybackIntentIdentifier API_AVAILABLE(ios(10.0));

NS_ASSUME_NONNULL_END
