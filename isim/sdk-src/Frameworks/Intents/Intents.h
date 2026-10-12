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
 * (INPlayMediaIntent), lists and notes (INAddTasksIntent, INCreateNoteIntent). Custom intents (.intentdefinition
 * files) are not supported: use App Intents. INInteraction donations and INVoiceShortcutCenter's shortcuts are kept
 * per app in its container / the device data; voice shortcuts are matched by the simulated Siri.
 * INFocusStatusCenter (the Focus status): INFocusStatusCenter.h. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Intents/INFocusStatusCenter.h>   /* the Focus status of the device (INFocusStatusCenter.h) */
NS_ASSUME_NONNULL_BEGIN

#ifndef INTENTS_EXTERN
#define INTENTS_EXTERN extern __attribute__((visibility("default")))
#endif

@class INIntent, INIntentResponse, INImage, INPerson, INPersonHandle, INSpeakableString, INMessage, INMediaItem, INTask, INTaskList, INNote, INNoteContent;

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

/* ---------------- shared types ---------------- */
@interface INImage : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)imageNamed:(NSString *)name;
+ (instancetype)systemImageNamed:(NSString *)systemImageName;
+ (instancetype)imageWithImageData:(NSData *)imageData;
+ (nullable instancetype)imageWithURL:(NSURL *)URL;
+ (instancetype)imageWithUIImage:(UIImage *)image;
@end

@interface INSpeakableString : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithVocabularyIdentifier:(NSString *)vocabularyIdentifier spokenPhrase:(NSString *)spokenPhrase pronunciationHint:(nullable NSString *)pronunciationHint;
- (instancetype)initWithIdentifier:(NSString *)identifier spokenPhrase:(NSString *)spokenPhrase pronunciationHint:(nullable NSString *)pronunciationHint;
- (instancetype)initWithSpokenPhrase:(NSString *)spokenPhrase;
@property (readonly, copy, nullable) NSString *vocabularyIdentifier;
@property (readonly, copy, nullable) NSString *identifier;
@property (readonly, copy) NSString *spokenPhrase;
@property (readonly, copy, nullable) NSString *pronunciationHint;
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
@interface INDateComponentsResolutionResult : INIntentResolutionResult
+ (instancetype)successWithResolvedDateComponents:(NSDateComponents *)resolvedDateComponents NS_SWIFT_NAME(success(with:));
+ (instancetype)disambiguationWithDateComponentsToDisambiguate:(NSArray<NSDateComponents *> *)dateComponentsToDisambiguate NS_SWIFT_NAME(disambiguation(with:));
+ (instancetype)confirmationRequiredWithDateComponentsToConfirm:(nullable NSDateComponents *)dateComponentsToConfirm NS_SWIFT_NAME(confirmationRequired(with:));
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
