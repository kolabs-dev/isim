#pragma once
/* isim SDK (self-authored): Intents — SiriKit.
 * isim (adapted): Siri is simulated by the home screen. It has no speech recognition: the script command `siri PHRASE`
 * understands a few fixed English phrasings of the domains below ("send a message to Anna saying Hello", "call Anna",
 * ...), and `siri intent CLASS key=value ...` builds an intent directly (docs/SCRIPTING.md). Siri then runs the intent
 * in the app's Intents extension (NSExtensionPointIdentifier com.apple.intents-service, IntentsSupported in its
 * NSExtensionAttributes; INExtension handler(for:)) or, for INIntentsSupported in the app's Info.plist, in the app
 * (application(_:handlerFor:)): resolve each parameter (success / needsValue / disambiguation / confirmationRequired /
 * unsupported / notRequired), confirm, handle; the questions and the response are shown in isim's Siri UI.
 * Domains: messages (INSendMessageIntent, INSearchForMessagesIntent), calls (INStartCallIntent), media
 * (INPlayMediaIntent), lists and notes (INAddTasksIntent, INCreateNoteIntent), and custom intents: `isim build`
 * generates their classes from .intentdefinition files and copies the definition into the bundle, where Siri reads
 * their parameters and dialogs (`siri intent OrderSoupIntent soup=...`). INInteraction donations and INVoiceShortcutCenter's shortcuts are kept
 * per app in its container / the device data; voice shortcuts are matched by the simulated Siri.
 * INFocusStatusCenter (the Focus status): INFocusStatusCenter.h. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Intents/INFocusStatusCenter.h>   /* the Focus status of the device (INFocusStatusCenter.h) */
#import <CoreLocation/CoreLocation.h>      /* CLRegion (INLocationRelevanceProvider; from Swift, the overlay's) */
#import <UserNotifications/UserNotifications.h>   /* UNNotificationContentProviding (communication notifications) */
NS_ASSUME_NONNULL_BEGIN

#ifndef INTENTS_EXTERN
#define INTENTS_EXTERN extern __attribute__((visibility("default")))
#endif

@class INIntent, INIntentResponse, INImage, INShortcut, INPerson, INPersonHandle, INSpeakableString, INMessage, INMediaItem, INTask, INTaskList, INNote, INNoteContent;

/* ---------------- authorization ---------------- */
typedef NS_ENUM(NSInteger, INSiriAuthorizationStatus) {
    INSiriAuthorizationStatusNotDetermined = 0,
    INSiriAuthorizationStatusRestricted,
    INSiriAuthorizationStatusDenied,
    INSiriAuthorizationStatusAuthorized,
};
/* isim: requestSiriAuthorization shows the system alert (the app's NSSiriUsageDescription) once; the answer is
   remembered in the app's defaults (_ISIMPrivacy.siri; Settings > the app > Siri). ISIM_SIRI_PERMISSION=allow|deny
   answers without the alert. */
@interface INPreferences : NSObject
+ (INSiriAuthorizationStatus)siriAuthorizationStatus;
+ (void)requestSiriAuthorization:(void (^)(INSiriAuthorizationStatus status))handler;
+ (NSString *)siriLanguageCode;
@end

/* ---------------- vocabulary ---------------- */
typedef NS_ENUM(NSInteger, INVocabularyStringType) {
    INVocabularyStringTypeContactName = 1,
    INVocabularyStringTypeContactGroupName,
    INVocabularyStringTypePhotoTag = 100,
    INVocabularyStringTypePhotoAlbumName,
    INVocabularyStringTypeWorkoutActivityName = 200,
    INVocabularyStringTypeCarProfileName = 300,
    INVocabularyStringTypeCarName,
    INVocabularyStringTypePaymentsOrganizationName = 400,
    INVocabularyStringTypePaymentsAccountNickname,
    INVocabularyStringTypeNotebookItemTitle = 500,
    INVocabularyStringTypeNotebookItemGroupName,
    INVocabularyStringTypeMediaPlaylistTitle = 700,
    INVocabularyStringTypeMediaMusicArtistName,
    INVocabularyStringTypeMediaAudiobookTitle,
    INVocabularyStringTypeMediaAudiobookAuthorName,
    INVocabularyStringTypeMediaShowTitle,
};
@protocol INSpeakable;
/* isim (adapted): the app's user-specific vocabulary is kept in its container (Library/isim/Vocabulary.plist, per string
   type, newest first as on iOS). The simulated Siri has no speech recognition: it uses the vocabulary to spell what was
   said the app's way, matching a spoken name case- and diacritic-insensitively, or one of a speakable's
   alternativeSpeakableMatches ("cafe noir" -> "Café Noir"), before it sends the intent to the app. */
@interface INVocabulary : NSObject
+ (instancetype)sharedVocabulary NS_SWIFT_NAME(shared());
- (void)setVocabularyStrings:(NSOrderedSet<NSString *> *)vocabulary ofType:(INVocabularyStringType)type;
- (void)setVocabulary:(NSOrderedSet<id<INSpeakable>> *)vocabulary ofType:(INVocabularyStringType)type API_AVAILABLE(ios(11.0));
- (void)removeAllVocabularyStrings;
@end

/* ---------------- shared types ---------------- */
@interface INImage : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)imageNamed:(NSString *)name;
+ (instancetype)systemImageNamed:(NSString *)systemImageName;
+ (instancetype)imageWithImageData:(NSData *)imageData;
+ (nullable instancetype)imageWithURL:(NSURL *)URL;
+ (instancetype)imageWithUIImage:(UIImage *)image;
@end

/* something Siri can say and recognize: a speakable string, a custom type */
@protocol INSpeakable <NSObject>
@property (readonly, copy) NSString *spokenPhrase;
@property (readonly, copy, nullable) NSString *pronunciationHint;
@property (readonly, copy, nullable) NSString *vocabularyIdentifier;
@property (readonly, copy, nullable) NSArray<id<INSpeakable>> *alternativeSpeakableMatches;
@property (readonly, copy, nullable) NSString *identifier API_AVAILABLE(ios(11.0));
@end
@interface INSpeakableString : NSObject <INSpeakable, NSCopying, NSSecureCoding>
- (instancetype)initWithVocabularyIdentifier:(NSString *)vocabularyIdentifier spokenPhrase:(NSString *)spokenPhrase pronunciationHint:(nullable NSString *)pronunciationHint;
- (instancetype)initWithIdentifier:(NSString *)identifier spokenPhrase:(NSString *)spokenPhrase pronunciationHint:(nullable NSString *)pronunciationHint;
- (instancetype)initWithSpokenPhrase:(NSString *)spokenPhrase;
@property (readonly, copy, nullable) NSString *vocabularyIdentifier;
@property (readonly, copy, nullable) NSString *identifier;
@property (readonly, copy) NSString *spokenPhrase;
@property (readonly, copy, nullable) NSString *pronunciationHint;
@property (readonly, copy, nullable) NSArray<id<INSpeakable>> *alternativeSpeakableMatches;
@end

typedef NS_ENUM(NSInteger, INPersonHandleType) {
    INPersonHandleTypeUnknown = 0,
    INPersonHandleTypeEmailAddress,
    INPersonHandleTypePhoneNumber,
};
typedef NSString *INPersonHandleLabel NS_TYPED_EXTENSIBLE_ENUM;
@interface INPersonHandle : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithValue:(nullable NSString *)value type:(INPersonHandleType)type;
- (instancetype)initWithValue:(nullable NSString *)value type:(INPersonHandleType)type label:(nullable INPersonHandleLabel)label;
@property (readonly, copy, nullable) NSString *value;
@property (readonly) INPersonHandleType type;
@property (readonly, copy, nullable) INPersonHandleLabel label;
@end

typedef NS_ENUM(NSInteger, INPersonSuggestionType) {
    INPersonSuggestionTypeNone = 0,
    INPersonSuggestionTypeSocialProfile,
    INPersonSuggestionTypeInstantMessageAddress,
};
@interface INPerson : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle nameComponents:(nullable NSPersonNameComponents *)nameComponents displayName:(nullable NSString *)displayName image:(nullable INImage *)image contactIdentifier:(nullable NSString *)contactIdentifier customIdentifier:(nullable NSString *)customIdentifier;
- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle nameComponents:(nullable NSPersonNameComponents *)nameComponents displayName:(nullable NSString *)displayName image:(nullable INImage *)image contactIdentifier:(nullable NSString *)contactIdentifier customIdentifier:(nullable NSString *)customIdentifier isMe:(BOOL)isMe;
- (instancetype)initWithPersonHandle:(INPersonHandle *)personHandle nameComponents:(nullable NSPersonNameComponents *)nameComponents displayName:(nullable NSString *)displayName image:(nullable INImage *)image contactIdentifier:(nullable NSString *)contactIdentifier customIdentifier:(nullable NSString *)customIdentifier aliases:(nullable NSArray<INPersonHandle *> *)aliases suggestionType:(INPersonSuggestionType)suggestionType;
@property (readonly, copy, nullable) INPersonHandle *personHandle;
@property (readonly, copy, nullable) NSPersonNameComponents *nameComponents;
@property (readonly, copy) NSString *displayName;
@property (readonly, copy, nullable) INImage *image;
@property (readonly, copy, nullable) NSString *contactIdentifier;
@property (readonly, copy, nullable) NSString *customIdentifier;
@property (readonly, copy, nullable) NSArray<INPersonHandle *> *aliases;
@property (readonly) INPersonSuggestionType suggestionType;
@property (readonly) BOOL isMe;
@end

/* ---------------- intents and responses ---------------- */
typedef NS_ENUM(NSInteger, INIntentHandlingStatus) {
    INIntentHandlingStatusUnspecified = 0,
    INIntentHandlingStatusReady,
    INIntentHandlingStatusInProgress,
    INIntentHandlingStatusSuccess,
    INIntentHandlingStatusFailure,
    INIntentHandlingStatusDeferredToApplication,
    INIntentHandlingStatusUserConfirmationRequired,
};
typedef NS_ENUM(NSInteger, INInteractionDirection) {
    INInteractionDirectionUnspecified = 0,
    INInteractionDirectionOutgoing,
    INInteractionDirectionIncoming,
};

@interface INIntent : NSObject <NSCopying, NSSecureCoding>
@property (readonly, copy) NSString *identifier;
@property (readonly, copy, nullable) NSString *intentDescription;
@property (copy, nullable) NSString *suggestedInvocationPhrase;
/* isim-private: a property-list form (used between Siri, extensions and apps) */
- (NSDictionary *)_isim_plist;
+ (nullable INIntent *)_isim_intentWithPlist:(NSDictionary *)plist;
@end

@interface INIntentResponse : NSObject <NSCopying, NSSecureCoding>
@property (readwrite, strong, nullable) NSUserActivity *userActivity;
@end
/* Custom intents (.intentdefinition, generated by `isim build` like Xcode): INIntent, INIntentResponse and INObject
   subclasses declare their parameters as @NSManaged / @dynamic properties; isim provides their accessors at run time
   (+resolveInstanceMethod:), kept with the object's values. */

/* A custom type of an intent definition (an object with an identifier and a display string) */
API_AVAILABLE(ios(13.0))
@interface INObject : NSObject <INSpeakable, NSCopying, NSSecureCoding>
- (instancetype)initWithIdentifier:(nullable NSString *)identifier displayString:(NSString *)displayString pronunciationHint:(nullable NSString *)pronunciationHint subtitleString:(nullable NSString *)subtitleString displayImage:(nullable INImage *)displayImage NS_SWIFT_NAME(init(identifier:display:pronunciationHint:subtitle:image:)) API_AVAILABLE(ios(14.0));
- (instancetype)initWithIdentifier:(nullable NSString *)identifier displayString:(NSString *)displayString subtitleString:(nullable NSString *)subtitleString displayImage:(nullable INImage *)displayImage NS_SWIFT_NAME(init(identifier:display:subtitle:image:)) API_AVAILABLE(ios(14.0));
- (instancetype)initWithIdentifier:(nullable NSString *)identifier displayString:(NSString *)displayString pronunciationHint:(nullable NSString *)pronunciationHint NS_SWIFT_NAME(init(identifier:display:pronunciationHint:));
- (instancetype)initWithIdentifier:(nullable NSString *)identifier displayString:(NSString *)displayString NS_SWIFT_NAME(init(identifier:display:));
@property (readonly, copy, nullable) NSString *identifier;
@property (readonly, copy) NSString *displayString;
@property (readonly, copy, nullable) NSString *pronunciationHint;
@property (readwrite, copy, nullable) NSString *subtitleString API_AVAILABLE(ios(14.0));
@property (readwrite, copy, nullable) INImage *displayImage API_AVAILABLE(ios(14.0));
@property (readwrite, copy, nullable) NSArray<INSpeakableString *> *alternativeSpeakableMatches;
@property (readonly, copy) NSString *spokenPhrase;
@property (readonly, copy, nullable) NSString *vocabularyIdentifier;
@end

/* Dynamic options (a parameter's provide<Parameter>OptionsCollection(for:with:)): the values, in sections. Siri lists
   them when the parameter needs a value (isim: its choice list, one row per item, section titles as subtitles). */
API_AVAILABLE(ios(14.0))
@interface INObjectSection<__covariant ObjectType> : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTitle:(nullable NSString *)title items:(NSArray<ObjectType> *)items NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSString *title;
@property (readonly, copy) NSArray<ObjectType> *items;
@end
API_AVAILABLE(ios(14.0))
@interface INObjectCollection<__covariant ObjectType> : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithSections:(NSArray<INObjectSection<ObjectType> *> *)sections NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithItems:(NSArray<ObjectType> *)items;
@property (readonly, copy) NSArray<INObjectSection<ObjectType> *> *sections;
@property (readonly, copy) NSArray<ObjectType> *allItems;
@property (assign) BOOL usesIndexedCollation;
@end

/* an amount of money */
@interface INCurrencyAmount : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithAmount:(NSDecimalNumber *)amount currencyCode:(NSString *)currencyCode NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSDecimalNumber *amount;
@property (readonly, copy, nullable) NSString *currencyCode;
@end

/* ---------------- resolution results ---------------- */
@interface INIntentResolutionResult : NSObject
+ (instancetype)needsValue NS_SWIFT_NAME(needsValue());
+ (instancetype)notRequired NS_SWIFT_NAME(notRequired());
+ (instancetype)unsupported NS_SWIFT_NAME(unsupported());
+ (instancetype)unsupportedWithReason:(NSInteger)reason NS_SWIFT_NAME(unsupported(withReason:));
+ (instancetype)confirmationRequiredWithItemToConfirm:(nullable id)itemToConfirm forReason:(NSInteger)reason NS_SWIFT_NAME(confirmationRequired(with:forReason:));
@end
@interface INPersonResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedPerson:(INPerson *)resolvedPerson NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithPeopleToDisambiguate:(NSArray<INPerson *> *)peopleToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithPersonToConfirm:(nullable INPerson *)personToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INStringResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedString:(NSString *)resolvedString NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithStringsToDisambiguate:(NSArray<NSString *> *)stringsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithStringToConfirm:(nullable NSString *)stringToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INSpeakableStringResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedString:(INSpeakableString *)resolvedString NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithStringsToDisambiguate:(NSArray<INSpeakableString *> *)stringsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithStringToConfirm:(nullable INSpeakableString *)stringToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INBooleanResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedValue:(BOOL)resolvedValue NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithValueToConfirm:(nullable NSNumber *)valueToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INIntegerResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedValue:(NSInteger)resolvedValue NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithValueToConfirm:(nullable NSNumber *)valueToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INDoubleResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedValue:(double)resolvedValue NS_SWIFT_NAME(success(with:));
+ (instancetype)confirmationRequiredWithValueToConfirm:(nullable NSNumber *)valueToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
API_AVAILABLE(ios(13.0))
@interface INURLResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedURL:(NSURL *)resolvedURL NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithURLsToDisambiguate:(NSArray<NSURL *> *)urlsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithURLToConfirm:(nullable NSURL *)urlToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@class INObject;
API_AVAILABLE(ios(13.0))
@interface INObjectResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedObject:(INObject *)resolvedObject NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithObjectsToDisambiguate:(NSArray<INObject *> *)objectsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithObjectToConfirm:(nullable INObject *)objectToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
/* the resolution result of an enumeration parameter (generated <Enum>ResolutionResult subclasses wrap these) */
API_AVAILABLE(ios(13.0))
@interface INEnumResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedValue:(NSInteger)resolvedValue NS_REFINED_FOR_SWIFT;
+ (instancetype)confirmationRequiredWithValueToConfirm:(NSInteger)valueToConfirm NS_REFINED_FOR_SWIFT;
@end
@interface INDateComponentsResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedDateComponents:(NSDateComponents *)resolvedDateComponents NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithDateComponentsToDisambiguate:(NSArray<NSDateComponents *> *)dateComponentsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithDateComponentsToConfirm:(nullable NSDateComponents *)dateComponentsToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
API_AVAILABLE(ios(11.0))
@interface INCurrencyAmountResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedCurrencyAmount:(INCurrencyAmount *)resolvedCurrencyAmount NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithCurrencyAmountsToDisambiguate:(NSArray<INCurrencyAmount *> *)currencyAmountsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithCurrencyAmountToConfirm:(nullable INCurrencyAmount *)currencyAmountToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end

/* ---------------- messages ---------------- */
typedef NS_ENUM(NSInteger, INOutgoingMessageType) {
    INOutgoingMessageTypeUnknown = 0,
    INOutgoingMessageTypeOutgoingMessageText,
    INOutgoingMessageTypeOutgoingMessageAudio,
};
typedef NS_ENUM(NSInteger, INMessageType) {
    INMessageTypeUnspecified = 0,
    INMessageTypeText,
    INMessageTypeAudio,
};
@interface INMessage : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithIdentifier:(NSString *)identifier content:(nullable NSString *)content dateSent:(nullable NSDate *)dateSent sender:(nullable INPerson *)sender recipients:(nullable NSArray<INPerson *> *)recipients;
- (instancetype)initWithIdentifier:(NSString *)identifier content:(nullable NSString *)content dateSent:(nullable NSDate *)dateSent sender:(nullable INPerson *)sender recipients:(nullable NSArray<INPerson *> *)recipients messageType:(INMessageType)messageType;
@property (readonly, copy) NSString *identifier;
@property (readonly, copy, nullable) NSString *conversationIdentifier;
@property (readonly, copy, nullable) NSString *content;
@property (readonly, copy, nullable) NSDate *dateSent;
@property (readonly, copy, nullable) INPerson *sender;
@property (readonly, copy, nullable) NSArray<INPerson *> *recipients;
@property (readonly) INMessageType messageType;
@end

@interface INSendMessageIntent : INIntent
- (instancetype)initWithRecipients:(nullable NSArray<INPerson *> *)recipients outgoingMessageType:(INOutgoingMessageType)outgoingMessageType content:(nullable NSString *)content speakableGroupName:(nullable INSpeakableString *)speakableGroupName conversationIdentifier:(nullable NSString *)conversationIdentifier serviceName:(nullable NSString *)serviceName sender:(nullable INPerson *)sender attachments:(nullable NSArray *)attachments;
- (instancetype)initWithRecipients:(nullable NSArray<INPerson *> *)recipients outgoingMessageType:(INOutgoingMessageType)outgoingMessageType content:(nullable NSString *)content speakableGroupName:(nullable INSpeakableString *)speakableGroupName conversationIdentifier:(nullable NSString *)conversationIdentifier serviceName:(nullable NSString *)serviceName sender:(nullable INPerson *)sender;
@property (readonly, copy, nullable) NSArray<INPerson *> *recipients;
@property (readonly) INOutgoingMessageType outgoingMessageType;
@property (readonly, copy, nullable) NSString *content;
@property (readonly, copy, nullable) INSpeakableString *speakableGroupName;
@property (readonly, copy, nullable) NSString *conversationIdentifier;
@property (readonly, copy, nullable) NSString *serviceName;
@property (readonly, copy, nullable) INPerson *sender;
@end
/* communication notifications: UNNotificationContent.updating(from:) (UserNotifications) */
API_AVAILABLE(ios(15.0))
@interface INSendMessageIntent (UNNotificationContentProviding) <UNNotificationContentProviding>
@end
typedef NS_ENUM(NSInteger, INSendMessageIntentResponseCode) {
    INSendMessageIntentResponseCodeUnspecified = 0,
    INSendMessageIntentResponseCodeReady,
    INSendMessageIntentResponseCodeInProgress,
    INSendMessageIntentResponseCodeSuccess,
    INSendMessageIntentResponseCodeFailure,
    INSendMessageIntentResponseCodeFailureRequiringAppLaunch,
    INSendMessageIntentResponseCodeFailureMessageServiceNotAvailable,
    INSendMessageIntentResponseCodeFailureRequiringInAppAuthentication,
};
@interface INSendMessageIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSendMessageIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSendMessageIntentResponseCode code;
@property (copy, nullable) INMessage *sentMessage;
@property (copy, nullable) NSArray<INMessage *> *sentMessages;
@end
typedef NS_ENUM(NSInteger, INSendMessageRecipientUnsupportedReason) {
    INSendMessageRecipientUnsupportedReasonNoAccount = 1,
    INSendMessageRecipientUnsupportedReasonOffline,
    INSendMessageRecipientUnsupportedReasonMessagingServiceNotEnabledForRecipient,
    INSendMessageRecipientUnsupportedReasonNoValidHandle,
    INSendMessageRecipientUnsupportedReasonRequestedHandleInvalid,
    INSendMessageRecipientUnsupportedReasonNoHandleForLabel,
    INSendMessageRecipientUnsupportedReasonRequiringInAppAuthentication,
};
@interface INSendMessageRecipientResolutionResult : INPersonResolutionResult
+ (instancetype)unsupportedForReason:(INSendMessageRecipientUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult;
@end
@protocol INSendMessageIntentHandling <NSObject>
@required
- (void)handleSendMessage:(INSendMessageIntent *)intent completion:(void (^)(INSendMessageIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmSendMessage:(INSendMessageIntent *)intent completion:(void (^)(INSendMessageIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveRecipientsForSendMessage:(INSendMessageIntent *)intent completion:(void (^)(NSArray<INSendMessageRecipientResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveRecipients(for:with:));
- (void)resolveContentForSendMessage:(INSendMessageIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveContent(for:with:));
- (void)resolveSpeakableGroupNameForSendMessage:(INSendMessageIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveSpeakableGroupName(for:with:));
@end

typedef NS_OPTIONS(NSUInteger, INMessageAttributeOptions) {
    INMessageAttributeOptionRead = (1UL << 0),
    INMessageAttributeOptionUnread = (1UL << 1),
    INMessageAttributeOptionFlagged = (1UL << 2),
    INMessageAttributeOptionUnflagged = (1UL << 3),
    INMessageAttributeOptionPlayed = (1UL << 4),
};
@interface INDateComponentsRange : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithStartDateComponents:(nullable NSDateComponents *)startDateComponents endDateComponents:(nullable NSDateComponents *)endDateComponents;
@property (readonly, copy, nullable) NSDateComponents *startDateComponents;
@property (readonly, copy, nullable) NSDateComponents *endDateComponents;
@end
API_AVAILABLE(ios(10.0))
@interface INDateComponentsRangeResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedDateComponentsRange:(INDateComponentsRange *)resolvedDateComponentsRange NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithDateComponentsRangesToDisambiguate:(NSArray<INDateComponentsRange *> *)dateComponentsRangesToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithDateComponentsRangeToConfirm:(nullable INDateComponentsRange *)dateComponentsRangeToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end

/* places (CLPlacemark): the rides and photos domains. CLPlacemark is the CoreLocation Swift overlay's class, so Swift sees
   these as objects (NS_REFINED_FOR_SWIFT) and isim's Intents overlay gives them their CLPlacemark types. */
#if !defined(__swift__)
#define IN_PLACEMARK CLPlacemark *
#define IN_LOCATION CLLocation *
#define IN_REFINED_FOR_SWIFT_CL
#else
#define IN_PLACEMARK id
#define IN_LOCATION id
#define IN_REFINED_FOR_SWIFT_CL NS_REFINED_FOR_SWIFT
#endif
API_AVAILABLE(ios(10.0))
@interface INPlacemarkResolutionResult : INIntentResolutionResult
#if !defined(__swift__)
+ (instancetype)successWithResolvedPlacemark:(CLPlacemark *)resolvedPlacemark;
+ (instancetype)disambiguationWithPlacemarksToDisambiguate:(NSArray<CLPlacemark *> *)placemarksToDisambiguate;
+ (instancetype)confirmationRequiredWithPlacemarkToConfirm:(nullable CLPlacemark *)placemarkToConfirm;
#else   /* typed in the Intents overlay */
+ (instancetype)successWithResolvedPlacemark:(id)resolvedPlacemark NS_SWIFT_NAME(__success(with:));
+ (instancetype)disambiguationWithPlacemarksToDisambiguate:(NSArray *)placemarksToDisambiguate NS_SWIFT_NAME(__disambiguation(with:));
+ (instancetype)confirmationRequiredWithPlacemarkToConfirm:(nullable id)placemarkToConfirm NS_SWIFT_NAME(__confirmationRequired(with:));
#endif
@end
#if !defined(__swift__)
/* a place for an intent: CLPlacemark (INIntentsAdditions). isim: postalAddress is a CNPostalAddress (Contacts), read by key */
@interface CLPlacemark (INIntentsAdditions)
+ (instancetype)placemarkWithLocation:(CLLocation *)location name:(nullable NSString *)name postalAddress:(nullable id)postalAddress API_AVAILABLE(ios(10.0));
@end
#endif

/* how several values of a parameter combine (photos: searchTerms, peopleInPhoto) */
typedef NS_ENUM(NSInteger, INConditionalOperator) {
    INConditionalOperatorAll = 0,
    INConditionalOperatorAny,
    INConditionalOperatorNone,
} API_AVAILABLE(ios(10.0));
@interface INSearchForMessagesIntent : INIntent
- (instancetype)initWithRecipients:(nullable NSArray<INPerson *> *)recipients senders:(nullable NSArray<INPerson *> *)senders searchTerms:(nullable NSArray<NSString *> *)searchTerms attributes:(INMessageAttributeOptions)attributes dateTimeRange:(nullable INDateComponentsRange *)dateTimeRange identifiers:(nullable NSArray<NSString *> *)identifiers notificationIdentifiers:(nullable NSArray<NSString *> *)notificationIdentifiers speakableGroupNames:(nullable NSArray<INSpeakableString *> *)speakableGroupNames conversationIdentifiers:(nullable NSArray<NSString *> *)conversationIdentifiers;
@property (readonly, copy, nullable) NSArray<INPerson *> *recipients;
@property (readonly, copy, nullable) NSArray<INPerson *> *senders;
@property (readonly, copy, nullable) NSArray<NSString *> *searchTerms;
@property (readonly) INMessageAttributeOptions attributes;
@property (readonly, copy, nullable) INDateComponentsRange *dateTimeRange;
@property (readonly, copy, nullable) NSArray<NSString *> *identifiers;
@property (readonly, copy, nullable) NSArray<INSpeakableString *> *speakableGroupNames;
@property (readonly, copy, nullable) NSArray<NSString *> *conversationIdentifiers;
@end
typedef NS_ENUM(NSInteger, INSearchForMessagesIntentResponseCode) {
    INSearchForMessagesIntentResponseCodeUnspecified = 0,
    INSearchForMessagesIntentResponseCodeReady,
    INSearchForMessagesIntentResponseCodeInProgress,
    INSearchForMessagesIntentResponseCodeSuccess,
    INSearchForMessagesIntentResponseCodeFailure,
    INSearchForMessagesIntentResponseCodeFailureRequiringAppLaunch,
    INSearchForMessagesIntentResponseCodeFailureMessageServiceNotAvailable,
    INSearchForMessagesIntentResponseCodeFailureMessageTooManyResults,
    INSearchForMessagesIntentResponseCodeFailureRequiringInAppAuthentication,
};
@interface INSearchForMessagesIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSearchForMessagesIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSearchForMessagesIntentResponseCode code;
@property (copy, nullable) NSArray<INMessage *> *messages;
@end
@protocol INSearchForMessagesIntentHandling <NSObject>
@required
- (void)handleSearchForMessages:(INSearchForMessagesIntent *)intent completion:(void (^)(INSearchForMessagesIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmSearchForMessages:(INSearchForMessagesIntent *)intent completion:(void (^)(INSearchForMessagesIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveRecipientsForSearchForMessages:(INSearchForMessagesIntent *)intent withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveRecipients(for:with:));
- (void)resolveSendersForSearchForMessages:(INSearchForMessagesIntent *)intent withCompletion:(void (^)(NSArray<INPersonResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveSenders(for:with:));
@end

/* editing and unsending a sent message (iOS 16). isim: "edit my last message to say TEXT", "unsend my last message" (or
   `siri intent EditMessage message=ID content=TEXT`, `siri intent UnsendMessages messages=ID,ID`); Siri finds the last
   message it sent with the app (its INSendMessageIntentResponse's sentMessage) when none is named. */
API_AVAILABLE(ios(16.0))
@interface INEditMessageIntent : INIntent
- (instancetype)initWithMessageIdentifier:(nullable NSString *)messageIdentifier editedContent:(nullable NSString *)editedContent NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSString *messageIdentifier;
@property (readonly, copy, nullable) NSString *editedContent;
@end
API_AVAILABLE(ios(16.0))
typedef NS_ENUM(NSInteger, INEditMessageIntentResponseCode) {
    INEditMessageIntentResponseCodeUnspecified = 0,
    INEditMessageIntentResponseCodeReady,
    INEditMessageIntentResponseCodeInProgress,
    INEditMessageIntentResponseCodeSuccess,
    INEditMessageIntentResponseCodeFailure,
    INEditMessageIntentResponseCodeFailureRequiringAppLaunch,
    INEditMessageIntentResponseCodeFailureMessageNotFound,
    INEditMessageIntentResponseCodeFailurePastEditTimeLimit,
    INEditMessageIntentResponseCodeFailureMessageTypeUnsupported,
    INEditMessageIntentResponseCodeFailureUnsupportedOnService,
    INEditMessageIntentResponseCodeFailureMessageServiceNotAvailable,
    INEditMessageIntentResponseCodeFailureRequiringInAppAuthentication,
};
API_AVAILABLE(ios(16.0))
@interface INEditMessageIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INEditMessageIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INEditMessageIntentResponseCode code;
@end
API_AVAILABLE(ios(16.0))
@protocol INEditMessageIntentHandling <NSObject>
@required
- (void)handleEditMessage:(INEditMessageIntent *)intent completion:(void (^)(INEditMessageIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmEditMessage:(INEditMessageIntent *)intent completion:(void (^)(INEditMessageIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveEditedContentForEditMessage:(INEditMessageIntent *)intent withCompletion:(void (^)(INStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveEditedContent(for:with:));
@end
API_AVAILABLE(ios(16.0))
@interface INUnsendMessagesIntent : INIntent
- (instancetype)initWithMessageIdentifiers:(nullable NSArray<NSString *> *)messageIdentifiers NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSArray<NSString *> *messageIdentifiers;
@end
API_AVAILABLE(ios(16.0))
typedef NS_ENUM(NSInteger, INUnsendMessagesIntentResponseCode) {
    INUnsendMessagesIntentResponseCodeUnspecified = 0,
    INUnsendMessagesIntentResponseCodeReady,
    INUnsendMessagesIntentResponseCodeInProgress,
    INUnsendMessagesIntentResponseCodeSuccess,
    INUnsendMessagesIntentResponseCodeFailure,
    INUnsendMessagesIntentResponseCodeFailureRequiringAppLaunch,
    INUnsendMessagesIntentResponseCodeFailureMessageNotFound,
    INUnsendMessagesIntentResponseCodeFailurePastUnsendTimeLimit,
    INUnsendMessagesIntentResponseCodeFailureMessageTypeUnsupported,
    INUnsendMessagesIntentResponseCodeFailureUnsupportedOnService,
    INUnsendMessagesIntentResponseCodeFailureMessageServiceNotAvailable,
    INUnsendMessagesIntentResponseCodeFailureRequiringInAppAuthentication,
};
API_AVAILABLE(ios(16.0))
@interface INUnsendMessagesIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INUnsendMessagesIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INUnsendMessagesIntentResponseCode code;
@end
API_AVAILABLE(ios(16.0))
@protocol INUnsendMessagesIntentHandling <NSObject>
@required
- (void)handleUnsendMessages:(INUnsendMessagesIntent *)intent completion:(void (^)(INUnsendMessagesIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmUnsendMessages:(INUnsendMessagesIntent *)intent completion:(void (^)(INUnsendMessagesIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
@end

/* ---------------- calls ---------------- */
typedef NS_ENUM(NSInteger, INCallCapability) {
    INCallCapabilityUnknown = 0,
    INCallCapabilityAudioCall,
    INCallCapabilityVideoCall,
};
typedef NS_ENUM(NSInteger, INCallDestinationType) {
    INCallDestinationTypeUnknown = 0,
    INCallDestinationTypeNormal,
    INCallDestinationTypeEmergency,
    INCallDestinationTypeVoicemail,
    INCallDestinationTypeRedial,
    INCallDestinationTypeCallBack,
};
typedef NS_ENUM(NSInteger, INCallAudioRoute) {
    INCallAudioRouteUnknown = 0,
    INCallAudioRouteSpeakerphoneAudioRoute,
    INCallAudioRouteBluetoothAudioRoute,
};
typedef NS_ENUM(NSInteger, INCallRecordType) {
    INCallRecordTypeUnknown = 0,
    INCallRecordTypeOutgoing,
    INCallRecordTypeMissed,
    INCallRecordTypeReceived,
    INCallRecordTypeLatest,
    INCallRecordTypeVoicemail,
    INCallRecordTypeRinging,
    INCallRecordTypeInProgress,
    INCallRecordTypeOnHold,
};
@interface INStartCallIntent : INIntent
- (instancetype)initWithCallRecordFilter:(nullable id)callRecordFilter callRecordToCallBack:(nullable id)callRecordToCallBack audioRoute:(INCallAudioRoute)audioRoute destinationType:(INCallDestinationType)destinationType contacts:(nullable NSArray<INPerson *> *)contacts callCapability:(INCallCapability)callCapability;
- (instancetype)initWithAudioRoute:(INCallAudioRoute)audioRoute destinationType:(INCallDestinationType)destinationType contacts:(nullable NSArray<INPerson *> *)contacts recordTypeForRedialing:(INCallRecordType)recordTypeForRedialing callCapability:(INCallCapability)callCapability;
@property (readonly) INCallAudioRoute audioRoute;
@property (readonly) INCallDestinationType destinationType;
@property (readonly, copy, nullable) NSArray<INPerson *> *contacts;
@property (readonly) INCallCapability callCapability;
@end
API_AVAILABLE(ios(15.0))
@interface INStartCallIntent (UNNotificationContentProviding) <UNNotificationContentProviding>
@end
typedef NS_ENUM(NSInteger, INStartCallIntentResponseCode) {
    INStartCallIntentResponseCodeUnspecified = 0,
    INStartCallIntentResponseCodeReady,
    INStartCallIntentResponseCodeContinueInApp,
    INStartCallIntentResponseCodeUserConfirmationRequired,
    INStartCallIntentResponseCodeFailure,
    INStartCallIntentResponseCodeFailureRequiringAppLaunch,
    INStartCallIntentResponseCodeFailureCallingServiceNotAvailable,
    INStartCallIntentResponseCodeFailureContactNotSupportedByApp,
    INStartCallIntentResponseCodeFailureAirplaneModeEnabled,
    INStartCallIntentResponseCodeFailureUnableToHandOff,
    INStartCallIntentResponseCodeFailureAppConfigurationRequired,
    INStartCallIntentResponseCodeFailureCallInProgress,
    INStartCallIntentResponseCodeFailureCallRinging,
    INStartCallIntentResponseCodeFailureRequiringInAppAuthentication,
};
@interface INStartCallIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INStartCallIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INStartCallIntentResponseCode code;
@end
typedef NS_ENUM(NSInteger, INStartCallContactUnsupportedReason) {
    INStartCallContactUnsupportedReasonNoContactFound = 1,
    INStartCallContactUnsupportedReasonMultipleContactsUnsupported,
    INStartCallContactUnsupportedReasonNoHandleForLabel,
    INStartCallContactUnsupportedReasonInvalidHandle,
    INStartCallContactUnsupportedReasonUnsupportedMmiUssd,
    INStartCallContactUnsupportedReasonNoCallHistoryForRedial,
    INStartCallContactUnsupportedReasonNoUsableHandleForRedial,
    INStartCallContactUnsupportedReasonRequiringInAppAuthentication,
};
@interface INStartCallContactResolutionResult : INPersonResolutionResult
+ (instancetype)unsupportedForReason:(INStartCallContactUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithPersonResolutionResult:(INPersonResolutionResult *)personResolutionResult;
@end
@protocol INStartCallIntentHandling <NSObject>
@required
- (void)handleStartCall:(INStartCallIntent *)intent completion:(void (^)(INStartCallIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmStartCall:(INStartCallIntent *)intent completion:(void (^)(INStartCallIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveContactsForStartCall:(INStartCallIntent *)intent withCompletion:(void (^)(NSArray<INStartCallContactResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveContacts(for:with:));
@end

/* ---------------- media ---------------- */
typedef NS_ENUM(NSInteger, INMediaItemType) {
    INMediaItemTypeUnknown = 0,
    INMediaItemTypeSong,
    INMediaItemTypeAlbum,
    INMediaItemTypeArtist,
    INMediaItemTypeGenre,
    INMediaItemTypePlaylist,
    INMediaItemTypePodcastShow,
    INMediaItemTypePodcastEpisode,
    INMediaItemTypePodcastPlaylist,
    INMediaItemTypeMusicStation,
    INMediaItemTypeAudioBook,
    INMediaItemTypeMovie,
    INMediaItemTypeTVShow,
    INMediaItemTypeTVShowEpisode,
    INMediaItemTypeMusicVideo,
    INMediaItemTypePodcastStation,
    INMediaItemTypeRadioStation,
    INMediaItemTypeStation,
    INMediaItemTypeMusic,
    INMediaItemTypeAlgorithmicRadioStation,
    INMediaItemTypeNews,
};
@interface INMediaItem : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithIdentifier:(nullable NSString *)identifier title:(nullable NSString *)title type:(INMediaItemType)type artwork:(nullable INImage *)artwork;
- (instancetype)initWithIdentifier:(nullable NSString *)identifier title:(nullable NSString *)title type:(INMediaItemType)type artwork:(nullable INImage *)artwork artist:(nullable NSString *)artist;
@property (readonly, copy, nullable) NSString *identifier;
@property (readonly, copy, nullable) NSString *title;
@property (readonly) INMediaItemType type;
@property (readonly, copy, nullable) INImage *artwork;
@property (readonly, copy, nullable) NSString *artist;
@end
typedef NS_ENUM(NSInteger, INMediaSortOrder) {
    INMediaSortOrderUnknown = 0,
    INMediaSortOrderNewest,
    INMediaSortOrderOldest,
    INMediaSortOrderBest,
    INMediaSortOrderWorst,
    INMediaSortOrderPopular,
    INMediaSortOrderUnpopular,
    INMediaSortOrderTrending,
    INMediaSortOrderRecommended,
};
typedef NS_ENUM(NSInteger, INMediaReference) {
    INMediaReferenceUnknown = 0,
    INMediaReferenceCurrentlyPlaying,
    INMediaReferenceMy,
};
@interface INMediaSearch : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithMediaType:(INMediaItemType)mediaType sortOrder:(INMediaSortOrder)sortOrder mediaName:(nullable NSString *)mediaName artistName:(nullable NSString *)artistName albumName:(nullable NSString *)albumName genreNames:(nullable NSArray<NSString *> *)genreNames moodNames:(nullable NSArray<NSString *> *)moodNames releaseDate:(nullable INDateComponentsRange *)releaseDate reference:(INMediaReference)reference mediaIdentifier:(nullable NSString *)mediaIdentifier;
@property (readonly) INMediaSortOrder sortOrder;
@property (readonly) INMediaReference reference;
@property (readonly) INMediaItemType mediaType;
@property (readonly, copy, nullable) NSString *mediaName;
@property (readonly, copy, nullable) NSString *artistName;
@property (readonly, copy, nullable) NSString *albumName;
@property (readonly, copy, nullable) NSArray<NSString *> *genreNames;
@property (readonly, copy, nullable) NSArray<NSString *> *moodNames;
@property (readonly, copy, nullable) NSString *mediaIdentifier;
@end
typedef NS_ENUM(NSInteger, INPlaybackQueueLocation) {
    INPlaybackQueueLocationUnknown = 0,
    INPlaybackQueueLocationNow,
    INPlaybackQueueLocationNext,
    INPlaybackQueueLocationLater,
};
typedef NS_ENUM(NSInteger, INPlaybackRepeatMode) {
    INPlaybackRepeatModeUnknown = 0,
    INPlaybackRepeatModeNone,
    INPlaybackRepeatModeAll,
    INPlaybackRepeatModeOne,
};
@interface INPlayMediaIntent : INIntent
- (instancetype)initWithMediaItems:(nullable NSArray<INMediaItem *> *)mediaItems mediaContainer:(nullable INMediaItem *)mediaContainer playShuffled:(nullable NSNumber *)playShuffled playbackRepeatMode:(INPlaybackRepeatMode)playbackRepeatMode resumePlayback:(nullable NSNumber *)resumePlayback playbackQueueLocation:(INPlaybackQueueLocation)playbackQueueLocation playbackSpeed:(nullable NSNumber *)playbackSpeed mediaSearch:(nullable INMediaSearch *)mediaSearch;
@property (readonly, copy, nullable) NSArray<INMediaItem *> *mediaItems;
@property (readonly, copy, nullable) INMediaItem *mediaContainer;
@property (readonly, copy, nullable) NSNumber *playShuffled;
@property (readonly) INPlaybackRepeatMode playbackRepeatMode;
@property (readonly, copy, nullable) NSNumber *resumePlayback;
@property (readonly) INPlaybackQueueLocation playbackQueueLocation;
@property (readonly, copy, nullable) NSNumber *playbackSpeed;
@property (readonly, copy, nullable) INMediaSearch *mediaSearch;
@end
typedef NS_ENUM(NSInteger, INPlayMediaIntentResponseCode) {
    INPlayMediaIntentResponseCodeUnspecified = 0,
    INPlayMediaIntentResponseCodeReady,
    INPlayMediaIntentResponseCodeContinueInApp,
    INPlayMediaIntentResponseCodeInProgress,
    INPlayMediaIntentResponseCodeSuccess,
    INPlayMediaIntentResponseCodeHandleInApp,
    INPlayMediaIntentResponseCodeFailure,
    INPlayMediaIntentResponseCodeFailureRequiringAppLaunch,
    INPlayMediaIntentResponseCodeFailureUnknownMediaType,
    INPlayMediaIntentResponseCodeFailureNoUnplayedContent,
    INPlayMediaIntentResponseCodeFailureRestrictedContent,
    INPlayMediaIntentResponseCodeFailureMaxStreamLimitReached,
};
@interface INPlayMediaIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INPlayMediaIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INPlayMediaIntentResponseCode code;
@property (copy, nullable) NSDictionary<NSString *, id> *nowPlayingInfo;
@end
@interface INMediaItemResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedMediaItem:(INMediaItem *)resolvedMediaItem NS_SWIFT_NAME(success(with:));
+ (NSArray<INMediaItemResolutionResult *> *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)resolvedMediaItems NS_SWIFT_NAME(successes(with:));
+ (instancetype)disambiguationWithMediaItemsToDisambiguate:(NSArray<INMediaItem *> *)mediaItemsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithMediaItemToConfirm:(nullable INMediaItem *)mediaItemToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
typedef NS_ENUM(NSInteger, INPlayMediaMediaItemUnsupportedReason) {
    INPlayMediaMediaItemUnsupportedReasonLoginRequired = 1,
    INPlayMediaMediaItemUnsupportedReasonSubscriptionRequired,
    INPlayMediaMediaItemUnsupportedReasonUnsupportedMediaType,
    INPlayMediaMediaItemUnsupportedReasonExplicitContentSettings,
    INPlayMediaMediaItemUnsupportedReasonCellularDataSettings,
    INPlayMediaMediaItemUnsupportedReasonRestrictedContent,
    INPlayMediaMediaItemUnsupportedReasonServiceUnavailable,
    INPlayMediaMediaItemUnsupportedReasonRegionRestriction,
};
@interface INPlayMediaMediaItemResolutionResult : INMediaItemResolutionResult
+ (NSArray<INPlayMediaMediaItemResolutionResult *> *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)resolvedMediaItems NS_SWIFT_NAME(successes(with:));
+ (instancetype)unsupportedForReason:(INPlayMediaMediaItemUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)mediaItemResolutionResult;
@end
@protocol INPlayMediaIntentHandling <NSObject>
@required
- (void)handlePlayMedia:(INPlayMediaIntent *)intent completion:(void (^)(INPlayMediaIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmPlayMedia:(INPlayMediaIntent *)intent completion:(void (^)(INPlayMediaIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveMediaItemsForPlayMedia:(INPlayMediaIntent *)intent withCompletion:(void (^)(NSArray<INPlayMediaMediaItemResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveMediaItems(for:with:));
- (void)resolvePlayShuffledForPlayMedia:(INPlayMediaIntent *)intent withCompletion:(void (^)(INBooleanResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolvePlayShuffled(for:with:));
@end

/* adding media to the library or a playlist, and searching for it (iOS 13). isim: "add NAME to my library", "add NAME
   to my PLAYLIST playlist", "add this song to ...", "search for NAME in APP" / "find NAME in APP" (or `siri intent
   AddMedia media=NAME playlist=NAME`, `siri intent SearchForMedia media=NAME`). */
typedef NS_ENUM(NSInteger, INMediaDestinationType) {
    INMediaDestinationTypeUnknown = 0,
    INMediaDestinationTypeLibrary,
    INMediaDestinationTypePlaylist,
} API_AVAILABLE(ios(13.0));
/* Swift: INMediaDestinationReference; the API uses the INMediaDestination enum (.library, .playlist(name)) */
API_AVAILABLE(ios(13.0)) NS_SWIFT_NAME(INMediaDestinationReference)
@interface INMediaDestination : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)libraryDestination NS_SWIFT_NAME(library());
+ (instancetype)playlistDestinationWithName:(NSString *)playlistName NS_SWIFT_NAME(playlistDestination(withName:));
@property (readonly) INMediaDestinationType mediaDestinationType;
@property (readonly, copy, nullable) NSString *playlistName;
@end
API_AVAILABLE(ios(13.0))
@interface INMediaDestinationResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedMediaDestination:(INMediaDestination *)resolvedMediaDestination NS_SWIFT_NAME(__success(with:));
+ (instancetype)disambiguationWithMediaDestinationsToDisambiguate:(NSArray<INMediaDestination *> *)mediaDestinationsToDisambiguate NS_SWIFT_NAME(__disambiguation(with:));
+ (instancetype)confirmationRequiredWithMediaDestinationToConfirm:(nullable INMediaDestination *)mediaDestinationToConfirm NS_SWIFT_NAME(__confirmationRequired(with:));
@end

API_AVAILABLE(ios(13.0))
@interface INAddMediaIntent : INIntent
- (instancetype)initWithMediaItems:(nullable NSArray<INMediaItem *> *)mediaItems mediaSearch:(nullable INMediaSearch *)mediaSearch mediaDestination:(nullable INMediaDestination *)mediaDestination NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(__mediaItems:mediaSearch:mediaDestination:));
@property (readonly, copy, nullable) NSArray<INMediaItem *> *mediaItems;
@property (readonly, copy, nullable) INMediaSearch *mediaSearch;
@property (readonly, copy, nullable) INMediaDestination *mediaDestination NS_SWIFT_NAME(__mediaDestination);
@end
typedef NS_ENUM(NSInteger, INAddMediaIntentResponseCode) {
    INAddMediaIntentResponseCodeUnspecified = 0,
    INAddMediaIntentResponseCodeReady,
    INAddMediaIntentResponseCodeInProgress,
    INAddMediaIntentResponseCodeSuccess,
    INAddMediaIntentResponseCodeHandleInApp,
    INAddMediaIntentResponseCodeFailure,
    INAddMediaIntentResponseCodeFailureRequiringAppLaunch,
} API_AVAILABLE(ios(13.0));
API_AVAILABLE(ios(13.0))
@interface INAddMediaIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INAddMediaIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INAddMediaIntentResponseCode code;
@end
typedef NS_ENUM(NSInteger, INAddMediaMediaItemUnsupportedReason) {
    INAddMediaMediaItemUnsupportedReasonLoginRequired = 1,
    INAddMediaMediaItemUnsupportedReasonSubscriptionRequired,
    INAddMediaMediaItemUnsupportedReasonUnsupportedMediaType,
    INAddMediaMediaItemUnsupportedReasonExplicitContentSettings,
    INAddMediaMediaItemUnsupportedReasonCellularDataSettings,
    INAddMediaMediaItemUnsupportedReasonRestrictedContent,
    INAddMediaMediaItemUnsupportedReasonServiceUnavailable,
    INAddMediaMediaItemUnsupportedReasonRegionRestriction,
};
API_AVAILABLE(ios(13.0))
@interface INAddMediaMediaItemResolutionResult : INMediaItemResolutionResult
+ (NSArray<INAddMediaMediaItemResolutionResult *> *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)resolvedMediaItems NS_SWIFT_NAME(successes(with:));
+ (instancetype)unsupportedForReason:(INAddMediaMediaItemUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)mediaItemResolutionResult;
@end
typedef NS_ENUM(NSInteger, INAddMediaMediaDestinationUnsupportedReason) {
    INAddMediaMediaDestinationUnsupportedReasonPlaylistNameNotFound = 1,
    INAddMediaMediaDestinationUnsupportedReasonPlaylistNotEditable,
} API_AVAILABLE(ios(13.0));
API_AVAILABLE(ios(13.0))
@interface INAddMediaMediaDestinationResolutionResult : INMediaDestinationResolutionResult
+ (instancetype)unsupportedForReason:(INAddMediaMediaDestinationUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithMediaDestinationResolutionResult:(INMediaDestinationResolutionResult *)mediaDestinationResolutionResult;
@end
API_AVAILABLE(ios(13.0))
@protocol INAddMediaIntentHandling <NSObject>
@required
- (void)handleAddMedia:(INAddMediaIntent *)intent completion:(void (^)(INAddMediaIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmAddMedia:(INAddMediaIntent *)intent completion:(void (^)(INAddMediaIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveMediaItemsForAddMedia:(INAddMediaIntent *)intent withCompletion:(void (^)(NSArray<INAddMediaMediaItemResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveMediaItems(for:with:));
- (void)resolveMediaDestinationForAddMedia:(INAddMediaIntent *)intent withCompletion:(void (^)(INAddMediaMediaDestinationResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveMediaDestination(for:with:));
@end

API_AVAILABLE(ios(13.0))
@interface INSearchForMediaIntent : INIntent
- (instancetype)initWithMediaItems:(nullable NSArray<INMediaItem *> *)mediaItems mediaSearch:(nullable INMediaSearch *)mediaSearch NS_DESIGNATED_INITIALIZER;
@property (readonly, copy, nullable) NSArray<INMediaItem *> *mediaItems;
@property (readonly, copy, nullable) INMediaSearch *mediaSearch;
@end
typedef NS_ENUM(NSInteger, INSearchForMediaIntentResponseCode) {
    INSearchForMediaIntentResponseCodeUnspecified = 0,
    INSearchForMediaIntentResponseCodeReady,
    INSearchForMediaIntentResponseCodeContinueInApp,
    INSearchForMediaIntentResponseCodeInProgress,
    INSearchForMediaIntentResponseCodeSuccess,
    INSearchForMediaIntentResponseCodeFailure,
    INSearchForMediaIntentResponseCodeFailureRequiringAppLaunch,
} API_AVAILABLE(ios(13.0));
API_AVAILABLE(ios(13.0))
@interface INSearchForMediaIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INSearchForMediaIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INSearchForMediaIntentResponseCode code;
@property (copy, nullable) NSArray<INMediaItem *> *mediaItems;
@end
typedef NS_ENUM(NSInteger, INSearchForMediaMediaItemUnsupportedReason) {
    INSearchForMediaMediaItemUnsupportedReasonLoginRequired = 1,
    INSearchForMediaMediaItemUnsupportedReasonSubscriptionRequired,
    INSearchForMediaMediaItemUnsupportedReasonUnsupportedMediaType,
    INSearchForMediaMediaItemUnsupportedReasonExplicitContentSettings,
    INSearchForMediaMediaItemUnsupportedReasonCellularDataSettings,
    INSearchForMediaMediaItemUnsupportedReasonRestrictedContent,
    INSearchForMediaMediaItemUnsupportedReasonServiceUnavailable,
    INSearchForMediaMediaItemUnsupportedReasonRegionRestriction,
};
API_AVAILABLE(ios(13.0))
@interface INSearchForMediaMediaItemResolutionResult : INMediaItemResolutionResult
+ (NSArray<INSearchForMediaMediaItemResolutionResult *> *)successesWithResolvedMediaItems:(NSArray<INMediaItem *> *)resolvedMediaItems NS_SWIFT_NAME(successes(with:));
+ (instancetype)unsupportedForReason:(INSearchForMediaMediaItemUnsupportedReason)reason NS_SWIFT_NAME(unsupported(forReason:));
- (instancetype)initWithMediaItemResolutionResult:(INMediaItemResolutionResult *)mediaItemResolutionResult;
@end
API_AVAILABLE(ios(13.0))
@protocol INSearchForMediaIntentHandling <NSObject>
@required
- (void)handleSearchForMedia:(INSearchForMediaIntent *)intent completion:(void (^)(INSearchForMediaIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmSearchForMedia:(INSearchForMediaIntent *)intent completion:(void (^)(INSearchForMediaIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveMediaItemsForSearchForMedia:(INSearchForMediaIntent *)intent withCompletion:(void (^)(NSArray<INSearchForMediaMediaItemResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveMediaItems(for:with:));
@end

/* ---------------- lists and notes ---------------- */
typedef NS_ENUM(NSInteger, INTaskStatus) {
    INTaskStatusUnknown = 0,
    INTaskStatusNotCompleted,
    INTaskStatusCompleted,
};
typedef NS_ENUM(NSInteger, INTaskType) {
    INTaskTypeUnknown = 0,
    INTaskTypeNotCompletable,
    INTaskTypeCompletable,
};
typedef NS_ENUM(NSInteger, INTaskPriority) {
    INTaskPriorityUnknown = 0,
    INTaskPriorityNotFlagged,
    INTaskPriorityFlagged,
};
@interface INTask : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTitle:(INSpeakableString *)title status:(INTaskStatus)status taskType:(INTaskType)taskType spatialEventTrigger:(nullable id)spatialEventTrigger temporalEventTrigger:(nullable id)temporalEventTrigger createdDateComponents:(nullable NSDateComponents *)createdDateComponents modifiedDateComponents:(nullable NSDateComponents *)modifiedDateComponents identifier:(nullable NSString *)identifier;
- (instancetype)initWithTitle:(INSpeakableString *)title status:(INTaskStatus)status taskType:(INTaskType)taskType spatialEventTrigger:(nullable id)spatialEventTrigger temporalEventTrigger:(nullable id)temporalEventTrigger createdDateComponents:(nullable NSDateComponents *)createdDateComponents modifiedDateComponents:(nullable NSDateComponents *)modifiedDateComponents identifier:(nullable NSString *)identifier priority:(INTaskPriority)priority;
@property (readonly, copy) INSpeakableString *title;
@property (readonly) INTaskStatus status;
@property (readonly) INTaskType taskType;
@property (readonly) INTaskPriority priority;
@property (readonly, copy, nullable) NSDateComponents *createdDateComponents;
@property (readonly, copy, nullable) NSDateComponents *modifiedDateComponents;
@property (readonly, copy, nullable) NSString *identifier;
@end
@interface INTaskList : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTitle:(INSpeakableString *)title tasks:(NSArray<INTask *> *)tasks groupName:(nullable INSpeakableString *)groupName createdDateComponents:(nullable NSDateComponents *)createdDateComponents modifiedDateComponents:(nullable NSDateComponents *)modifiedDateComponents identifier:(nullable NSString *)identifier;
@property (readonly, copy) INSpeakableString *title;
@property (readonly, copy) NSArray<INTask *> *tasks;
@property (readonly, copy, nullable) INSpeakableString *groupName;
@property (readonly, copy, nullable) NSDateComponents *createdDateComponents;
@property (readonly, copy, nullable) NSDateComponents *modifiedDateComponents;
@property (readonly, copy, nullable) NSString *identifier;
@end
@interface INAddTasksIntent : INIntent
- (instancetype)initWithTargetTaskList:(nullable INTaskList *)targetTaskList taskTitles:(nullable NSArray<INSpeakableString *> *)taskTitles spatialEventTrigger:(nullable id)spatialEventTrigger temporalEventTrigger:(nullable id)temporalEventTrigger priority:(INTaskPriority)priority;
- (instancetype)initWithTargetTaskList:(nullable INTaskList *)targetTaskList taskTitles:(nullable NSArray<INSpeakableString *> *)taskTitles spatialEventTrigger:(nullable id)spatialEventTrigger temporalEventTrigger:(nullable id)temporalEventTrigger;
@property (readonly, copy, nullable) INTaskList *targetTaskList;
@property (readonly, copy, nullable) NSArray<INSpeakableString *> *taskTitles;
@property (readonly) INTaskPriority priority;
@end
typedef NS_ENUM(NSInteger, INAddTasksIntentResponseCode) {
    INAddTasksIntentResponseCodeUnspecified = 0,
    INAddTasksIntentResponseCodeReady,
    INAddTasksIntentResponseCodeInProgress,
    INAddTasksIntentResponseCodeSuccess,
    INAddTasksIntentResponseCodeFailure,
    INAddTasksIntentResponseCodeFailureRequiringAppLaunch,
};
@interface INAddTasksIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INAddTasksIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INAddTasksIntentResponseCode code;
@property (copy, nullable) INTaskList *modifiedTaskList;
@property (copy, nullable) NSArray<INTask *> *addedTasks;
@end
@interface INTaskListResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedTaskList:(INTaskList *)resolvedTaskList NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithTaskListsToDisambiguate:(NSArray<INTaskList *> *)taskListsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithTaskListToConfirm:(nullable INTaskList *)taskListToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@interface INAddTasksTargetTaskListResolutionResult : INTaskListResolutionResult
- (instancetype)initWithTaskListResolutionResult:(INTaskListResolutionResult *)taskListResolutionResult;
@end
@protocol INAddTasksIntentHandling <NSObject>
@required
- (void)handleAddTasks:(INAddTasksIntent *)intent completion:(void (^)(INAddTasksIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmAddTasks:(INAddTasksIntent *)intent completion:(void (^)(INAddTasksIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveTargetTaskListForAddTasks:(INAddTasksIntent *)intent completion:(void (^)(INAddTasksTargetTaskListResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveTargetTaskList(for:with:));
- (void)resolveTaskTitlesForAddTasks:(INAddTasksIntent *)intent withCompletion:(void (^)(NSArray<INSpeakableStringResolutionResult *> *resolutionResults))completion NS_SWIFT_NAME(resolveTaskTitles(for:with:));
@end

@interface INNoteContent : NSObject <NSSecureCoding, NSCopying>
@end
@interface INTextNoteContent : INNoteContent
- (instancetype)initWithText:(nullable NSString *)text;
@property (readonly, copy, nullable) NSString *text;
@end
@interface INNote : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTitle:(INSpeakableString *)title contents:(NSArray<INNoteContent *> *)contents groupName:(nullable INSpeakableString *)groupName createdDateComponents:(nullable NSDateComponents *)createdDateComponents modifiedDateComponents:(nullable NSDateComponents *)modifiedDateComponents identifier:(nullable NSString *)identifier;
@property (readonly, copy) INSpeakableString *title;
@property (readonly, copy) NSArray<INNoteContent *> *contents;
@property (readonly, copy, nullable) INSpeakableString *groupName;
@property (readonly, copy, nullable) NSDateComponents *createdDateComponents;
@property (readonly, copy, nullable) NSDateComponents *modifiedDateComponents;
@property (readonly, copy, nullable) NSString *identifier;
@end
@interface INCreateNoteIntent : INIntent
- (instancetype)initWithTitle:(nullable INSpeakableString *)title content:(nullable INNoteContent *)content groupName:(nullable INSpeakableString *)groupName;
@property (readonly, copy, nullable) INSpeakableString *title;
@property (readonly, copy, nullable) INNoteContent *content;
@property (readonly, copy, nullable) INSpeakableString *groupName;
@end
typedef NS_ENUM(NSInteger, INCreateNoteIntentResponseCode) {
    INCreateNoteIntentResponseCodeUnspecified = 0,
    INCreateNoteIntentResponseCodeReady,
    INCreateNoteIntentResponseCodeInProgress,
    INCreateNoteIntentResponseCodeSuccess,
    INCreateNoteIntentResponseCodeFailure,
    INCreateNoteIntentResponseCodeFailureRequiringAppLaunch,
};
@interface INCreateNoteIntentResponse : INIntentResponse
- (instancetype)initWithCode:(INCreateNoteIntentResponseCode)code userActivity:(nullable NSUserActivity *)userActivity NS_DESIGNATED_INITIALIZER;
@property (readonly) INCreateNoteIntentResponseCode code;
@property (copy, nullable) INNote *createdNote;
@end
@interface INNoteContentResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedNoteContent:(INNoteContent *)resolvedNoteContent NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithNoteContentsToDisambiguate:(NSArray<INNoteContent *> *)noteContentsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithNoteContentToConfirm:(nullable INNoteContent *)noteContentToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
@end
@protocol INCreateNoteIntentHandling <NSObject>
@required
- (void)handleCreateNote:(INCreateNoteIntent *)intent completion:(void (^)(INCreateNoteIntentResponse *response))completion NS_SWIFT_NAME(handle(intent:completion:));
@optional
- (void)confirmCreateNote:(INCreateNoteIntent *)intent completion:(void (^)(INCreateNoteIntentResponse *response))completion NS_SWIFT_NAME(confirm(intent:completion:));
- (void)resolveTitleForCreateNote:(INCreateNoteIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveTitle(for:with:));
- (void)resolveContentForCreateNote:(INCreateNoteIntent *)intent withCompletion:(void (^)(INNoteContentResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveContent(for:with:));
- (void)resolveGroupNameForCreateNote:(INCreateNoteIntent *)intent withCompletion:(void (^)(INSpeakableStringResolutionResult *resolutionResult))completion NS_SWIFT_NAME(resolveGroupName(for:with:));
@end

/* ---------------- interactions (donations) ---------------- */
/* isim: donations are kept in the app's container (Library/isim/Interactions.plist); the Shortcuts app lists them as
   the app's Siri Suggestions, and running one runs its intent like Siri. Not in isim: dateInterval (isim's Foundation
   has no NSDateInterval class; the donation date is recorded) */
@interface INInteraction : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithIntent:(INIntent *)intent response:(nullable INIntentResponse *)response NS_DESIGNATED_INITIALIZER;
- (void)donateInteractionWithCompletion:(void (^_Nullable)(NSError *_Nullable error))completion NS_SWIFT_NAME(donate(completion:));
+ (void)deleteAllInteractionsWithCompletion:(void (^_Nullable)(NSError *_Nullable error))completion NS_SWIFT_NAME(deleteAll(completion:));
+ (void)deleteInteractionsWithIdentifiers:(NSArray<NSString *> *)identifiers completion:(void (^_Nullable)(NSError *_Nullable error))completion NS_SWIFT_NAME(delete(with:completion:));
+ (void)deleteInteractionsWithGroupIdentifier:(NSString *)groupIdentifier completion:(void (^_Nullable)(NSError *_Nullable error))completion NS_SWIFT_NAME(delete(with:completion:));
@property (readonly, copy) INIntent *intent;
@property (readonly, copy, nullable) INIntentResponse *intentResponse;
@property (readonly) INIntentHandlingStatus intentHandlingStatus;
@property (assign) INInteractionDirection direction;
@property (copy) NSString *identifier;
@property (copy, nullable) NSString *groupIdentifier;
@end
@interface NSUserActivity (IntentsAdditions)
/* the interaction Siri continues in the app (.continueInApp, failureRequiringAppLaunch) */
@property (readonly, nullable, nonatomic) INInteraction *interaction;
@property (copy, nullable, nonatomic) NSString *suggestedInvocationPhrase;
@end

/* ---------------- shortcuts and voice shortcuts ---------------- */
@interface INShortcut : NSObject <NSSecureCoding, NSCopying>
- (nullable instancetype)initWithIntent:(INIntent *)intent;
- (instancetype)initWithUserActivity:(NSUserActivity *)userActivity;
@property (readonly, copy, nullable) INIntent *intent;
@property (readonly, strong, nullable) NSUserActivity *userActivity;
@end
@interface INVoiceShortcut : NSObject <NSSecureCoding, NSCopying>
@property (readonly, strong) NSUUID *identifier;
@property (readonly, copy) NSString *invocationPhrase;
@property (readonly, copy) INShortcut *shortcut;
@end
/* isim: voice shortcuts live in <isim data>/Library/Siri/VoiceShortcuts.plist; an app sees its own. The simulated Siri
   runs one when `siri PHRASE` matches its invocation phrase (case-insensitive). */
@interface INVoiceShortcutCenter : NSObject
@property (class, readonly, strong) INVoiceShortcutCenter *sharedCenter;
- (void)getAllVoiceShortcutsWithCompletion:(void (^)(NSArray<INVoiceShortcut *> *_Nullable voiceShortcuts, NSError *_Nullable error))completionHandler;
- (void)getVoiceShortcutWithIdentifier:(NSUUID *)identifier completion:(void (^)(INVoiceShortcut *_Nullable voiceShortcut, NSError *_Nullable error))completionHandler NS_SWIFT_NAME(getVoiceShortcut(with:completion:));
- (void)setShortcutSuggestions:(NSArray<INShortcut *> *)suggestions;
@end

/* ---------------- relevant shortcuts ---------------- */
/* isim (adapted): INRelevantShortcutStore keeps the app's relevant shortcuts in its container
   (Library/isim/RelevantShortcuts.plist). isim has no Siri watch face or Smart Stack: the Shortcuts app lists the ones
   relevant now among the app's Siri Suggestions (a date provider's interval holds now; daily-routine and location
   providers count as relevant), titled by the watch template, and running one runs its intent or user activity. */
API_AVAILABLE(ios(12.0))
@interface INRelevanceProvider : NSObject <NSCopying, NSSecureCoding>
@end
API_AVAILABLE(ios(12.0))
@interface INDateRelevanceProvider : INRelevanceProvider
- (instancetype)initWithStartDate:(NSDate *)startDate endDate:(nullable NSDate *)endDate NS_DESIGNATED_INITIALIZER NS_SWIFT_NAME(init(start:end:));
@property (readonly, copy) NSDate *startDate;
@property (readonly, copy, nullable) NSDate *endDate;
@end
API_AVAILABLE(ios(12.0))
@interface INLocationRelevanceProvider : INRelevanceProvider
#if !defined(__swift__)
- (instancetype)initWithRegion:(CLRegion *)region NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) CLRegion *region;
#else   /* CLRegion is the CoreLocation Swift overlay's class: init(region:) and region are in the Intents overlay */
- (instancetype)initWithRegion:(id)region NS_DESIGNATED_INITIALIZER NS_REFINED_FOR_SWIFT;
@property (readonly, copy) id region NS_REFINED_FOR_SWIFT;
#endif
@end
typedef NS_ENUM(NSInteger, INDailyRoutineSituation) {
    INDailyRoutineSituationMorning = 0,
    INDailyRoutineSituationEvening,
    INDailyRoutineSituationHome,
    INDailyRoutineSituationWork,
    INDailyRoutineSituationSchool,
    INDailyRoutineSituationGym,
    INDailyRoutineSituationCommute API_AVAILABLE(ios(13.0)),
    INDailyRoutineSituationHeadphonesConnected API_AVAILABLE(ios(13.0)),
    INDailyRoutineSituationActiveWorkout API_AVAILABLE(ios(13.0)),
    INDailyRoutineSituationPhysicalActivityIncomplete API_AVAILABLE(ios(13.0)),
} API_AVAILABLE(ios(12.0)) NS_SWIFT_NAME(INDailyRoutineRelevanceProvider.Situation);
API_AVAILABLE(ios(12.0))
@interface INDailyRoutineRelevanceProvider : INRelevanceProvider
- (instancetype)initWithSituation:(INDailyRoutineSituation)situation NS_DESIGNATED_INITIALIZER;
@property (readonly) INDailyRoutineSituation situation;
@end
API_AVAILABLE(ios(12.0))
@interface INDefaultCardTemplate : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithTitle:(NSString *)title NS_DESIGNATED_INITIALIZER;
@property (copy) NSString *title;
@property (copy, nullable) NSString *subtitle;
@property (copy, nullable) INImage *image;
@end
typedef NS_ENUM(NSInteger, INRelevantShortcutRole) {
    INRelevantShortcutRoleAction = 0,
    INRelevantShortcutRoleInformation,
} API_AVAILABLE(ios(12.0));
API_AVAILABLE(ios(12.0))
@interface INRelevantShortcut : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithShortcut:(INShortcut *)shortcut NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) INShortcut *shortcut;
@property (copy) NSArray<INRelevanceProvider *> *relevanceProviders;
@property (copy, nullable) INDefaultCardTemplate *watchTemplate;
@property (assign) INRelevantShortcutRole shortcutRole;
@property (copy, nullable) NSString *widgetKind API_AVAILABLE(ios(15.0));
@end
API_AVAILABLE(ios(12.0))
@interface INRelevantShortcutStore : NSObject
@property (class, readonly, strong) INRelevantShortcutStore *defaultStore NS_SWIFT_NAME(default);
- (void)setRelevantShortcuts:(NSArray<INRelevantShortcut *> *)shortcuts completionHandler:(void (^_Nullable)(NSError *_Nullable error))completionHandler;
@end

/* ---------------- handling ---------------- */
@protocol INIntentHandlerProviding <NSObject>
- (nullable id)handlerForIntent:(INIntent *)intent NS_SWIFT_NAME(handler(for:));
@end
/* the principal class of an Intents extension (com.apple.intents-service) */
@interface INExtension : NSObject <INIntentHandlerProviding>
@end

/* ---------------- parameters (Intents UI) ---------------- */
@interface INParameter : NSObject <NSSecureCoding, NSCopying>
+ (instancetype)parameterForClass:(Class)aClass keyPath:(NSString *)keyPath;
@property (readonly) Class parameterClass;
@property (readonly, copy) NSString *parameterKeyPath;
@end

NS_ASSUME_NONNULL_END

/* ---------------- payments, rides, workouts and photos (issue #411) ---------------- */
#import <Intents/INPaymentsDomain.h>
#import <Intents/INRidesharingDomain.h>
#import <Intents/INWorkoutsDomain.h>
#import <Intents/INPhotosDomain.h>
