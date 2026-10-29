#pragma once
/* isim CoreSpotlight for Objective-C: the classes are the CoreSpotlight Swift overlay's (CoreSpotlight.framework
   re-exports libswiftCoreSpotlight.dylib): CSSearchableIndex stores items, with all their attributes, in the device-wide
   Spotlight index the home screen searches, and choosing a result continues a CSSearchableItemActionType user activity
   in the app, like Swift. CSSearchQuery runs Spotlight's query language over the app's items; CSUserQuery (iOS 18)
   searches what the user types, with suggestions. Spotlight asks the index delegate, or the app's index extension
   (CSIndexExtensionRequestHandler), to reindex (`isim spotlight reindex APP`), and the import extension
   (CSImportExtension) to fill in the attributes of the app's documents. Swift uses the overlay; these declarations are
   hidden from Swift. The classes are not subclassable from Objective-C, except the extensions' principal classes. */
#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT double CoreSpotlightVersionNumber;
FOUNDATION_EXPORT NSString * const CSSearchableItemActionType;
FOUNDATION_EXPORT NSString * const CSSearchableItemActivityIdentifier;
FOUNDATION_EXPORT NSString * const CSQueryContinuationActionType;
FOUNDATION_EXPORT NSString * const CSSearchQueryString;
FOUNDATION_EXPORT NSString * const CSActionIdentifier API_AVAILABLE(ios(15.0));
FOUNDATION_EXPORT NSString * const CSMailboxInbox API_AVAILABLE(ios(11.0));
FOUNDATION_EXPORT NSString * const CSMailboxDrafts API_AVAILABLE(ios(11.0));
FOUNDATION_EXPORT NSString * const CSMailboxSent API_AVAILABLE(ios(11.0));
FOUNDATION_EXPORT NSString * const CSMailboxJunk API_AVAILABLE(ios(11.0));
FOUNDATION_EXPORT NSString * const CSMailboxTrash API_AVAILABLE(ios(11.0));
FOUNDATION_EXPORT NSString * const CSMailboxArchive API_AVAILABLE(ios(11.0));

FOUNDATION_EXPORT NSErrorDomain const CSIndexErrorDomain;
typedef NS_ERROR_ENUM(CSIndexErrorDomain, CSIndexErrorCode) {
    CSIndexErrorCodeUnknownError = -1,
    CSIndexErrorCodeIndexUnavailableError = -1000,
    CSIndexErrorCodeInvalidItemError = -1001,
    CSIndexErrorCodeInvalidClientStateError = -1002,
    CSIndexErrorCodeRemoteConnectionError = -1003,
    CSIndexErrorCodeQuotaExceeded = -1004,
    CSIndexErrorCodeIndexingUnsupported = -1005,
    CSIndexErrorCodeMismatchedClientState API_AVAILABLE(ios(17.0)) = -1006,
};
FOUNDATION_EXPORT NSErrorDomain const CSSearchQueryErrorDomain API_AVAILABLE(ios(10.0));
typedef NS_ERROR_ENUM(CSSearchQueryErrorDomain, CSSearchQueryErrorCode) {
    CSSearchQueryErrorCodeUnknown = -2000,
    CSSearchQueryErrorCodeIndexUnreachable = -2001,
    CSSearchQueryErrorCodeInvalidQuery = -2002,
    CSSearchQueryErrorCodeCancelled = -2003,
} API_AVAILABLE(ios(10.0));

/* ---------------- people, custom attributes, localized strings ---------------- */
@interface CSPerson : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithDisplayName:(nullable NSString *)displayName handles:(NSArray<NSString *> *)handles handleIdentifier:(NSString *)handleIdentifier;
@property (readonly, nullable) NSString *displayName;
@property (readonly) NSArray<NSString *> *handles;
@property (readonly) NSString *handleIdentifier;
@property (copy, nullable) NSString *contactIdentifier;
@end

@interface CSCustomAttributeKey : NSObject <NSCopying, NSSecureCoding>
/* nil when the name is not a valid key name (letters, digits and _; not starting with com.apple or MDItem) */
- (nullable instancetype)initWithKeyName:(NSString *)keyName;
- (nullable instancetype)initWithKeyName:(NSString *)keyName searchable:(BOOL)searchable searchableByDefault:(BOOL)searchableByDefault
                                  unique:(BOOL)unique multiValued:(BOOL)multiValued;
@property (readonly) NSString *keyName;
@property (readonly, getter=isSearchable) BOOL searchable;
@property (readonly, getter=isSearchableByDefault) BOOL searchableByDefault;
@property (readonly, getter=isUnique) BOOL unique;
@property (readonly, getter=isMultiValued) BOOL multiValued;
@end

@interface CSLocalizedString : NSString
- (instancetype)initWithLocalizedStrings:(NSDictionary *)localizedStrings;
- (NSString *)localizedString;
@end

/* ---------------- the attribute set ---------------- */
@interface CSSearchableItemAttributeSet : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithItemContentType:(NSString *)itemContentType API_DEPRECATED("Use initWithContentType:", ios(9.0, 14.0));
- (instancetype)initWithContentType:(UTType *)contentType API_AVAILABLE(ios(14.0));
@property (nullable, copy) NSString *contentType;
@property (nullable, copy) UTType *sharedItemContentType API_AVAILABLE(ios(16.0));
- (void)setValue:(nullable id<NSSecureCoding>)value forCustomKey:(CSCustomAttributeKey *)key;
- (nullable id<NSSecureCoding>)valueForCustomKey:(CSCustomAttributeKey *)key;
@property (nullable, copy) NSArray<NSString *> *accountHandles;
@property (nullable, copy) NSString *accountIdentifier;
@property (nullable, copy) NSString *acquisitionMake;
@property (nullable, copy) NSString *acquisitionModel;
@property (copy) NSArray<NSString *> *actionIdentifiers;
@property (nullable, strong) NSDate *addedDate;
@property (nullable, copy) NSArray<CSPerson *> *additionalRecipients;
@property (nullable, copy) NSString *album;
@property (nullable, strong) NSNumber *allDay;
@property (nullable, copy) NSArray<NSString *> *alternateNames;
@property (nullable, strong) NSNumber *altitude;
@property (nullable, strong) NSNumber *aperture;
@property (nullable, copy) NSString *artist;
@property (nullable, copy) NSArray<NSString *> *audiences;
@property (nullable, strong) NSNumber *audioBitRate;
@property (nullable, strong) NSNumber *audioChannelCount;
@property (nullable, copy) NSString *audioEncodingApplication;
@property (nullable, strong) NSNumber *audioSampleRate;
@property (nullable, strong) NSNumber *audioTrackNumber;
@property (nullable, copy) NSArray<NSString *> *authorAddresses;
@property (nullable, copy) NSArray<NSString *> *authorEmailAddresses;
@property (nullable, copy) NSArray<NSString *> *authorNames;
@property (nullable, copy) NSArray<CSPerson *> *authors;
@property (nullable, strong) NSNumber *bitsPerSample;
@property (nullable, copy) NSString *cameraOwner;
@property (nullable, copy) NSString *city;
@property (nullable, copy) NSArray<NSString *> *codecs;
@property (nullable, copy) NSString *colorSpace;
@property (nullable, copy) NSString *comment;
@property (nullable, strong) NSDate *completionDate;
@property (nullable, copy) NSString *composer;
@property (nullable, copy) NSArray<NSString *> *contactKeywords;
@property (nullable, copy) NSString *containerDisplayName;
@property (nullable, copy) NSString *containerIdentifier;
@property (nullable, strong) NSNumber *containerOrder;
@property (nullable, copy) NSString *containerTitle;
@property (nullable, strong) NSDate *contentCreationDate;
@property (nullable, copy) NSString *contentDescription;
@property (nullable, strong) NSDate *contentModificationDate;
@property (nullable, strong) NSNumber *contentRating;
@property (nullable, copy) NSArray<NSString *> *contentSources;
@property (nullable, copy) NSArray<NSString *> *contentTypeTree;
@property (nullable, strong) NSURL *contentURL;
@property (nullable, copy) NSArray<NSString *> *contributors;
@property (nullable, copy) NSString *copyright;
@property (nullable, copy) NSString *country;
@property (nullable, copy) NSArray<NSString *> *coverage;
@property (nullable, copy) NSString *creator;
@property (nullable, strong) NSURL *darkThumbnailURL;
@property (nullable, strong) NSNumber *deliveryType;
@property (nullable, copy) NSString *director;
@property (nullable, copy) NSString *displayName;
@property (nullable, copy) NSString *domainIdentifier;
@property (nullable, strong) NSDate *downloadedDate;
@property (nullable, strong) NSDate *dueDate;
@property (nullable, strong) NSNumber *duration;
@property (nullable, copy) NSArray<NSString *> *editors;
@property (nullable, copy) NSArray<NSString *> *emailAddresses;
@property (nullable, copy) NSDictionary *emailHeaders;
@property (nullable, copy) NSArray<NSString *> *encodingApplications;
@property (nullable, strong) NSDate *endDate;
@property (nullable, copy) NSString *EXIFVersion;
@property (nullable, copy) NSString *EXIFGPSVersion;
@property (nullable, strong) NSNumber *exposureMode;
@property (nullable, copy) NSString *exposureProgram;
@property (nullable, strong) NSNumber *exposureTime;
@property (nullable, copy) NSString *exposureTimeString;
@property (nullable, strong) NSNumber *fNumber;
@property (nullable, strong) NSNumber *fileSize;
@property (nullable, strong) NSNumber *flashOn;
@property (nullable, strong) NSNumber *focalLength;
@property (nullable, copy) NSArray<NSString *> *fontNames;
@property (nullable, copy) NSString *fullyFormattedAddress;
@property (nullable, strong) NSNumber *generalMIDISequence;
@property (nullable, copy) NSString *genre;
@property (nullable, copy) NSString *GPSAreaInformation;
@property (nullable, strong) NSDate *GPSDateStamp;
@property (nullable, strong) NSNumber *GPSDestBearing;
@property (nullable, strong) NSNumber *GPSDestDistance;
@property (nullable, strong) NSNumber *GPSDestLatitude;
@property (nullable, strong) NSNumber *GPSDestLongitude;
@property (nullable, strong) NSNumber *GPSDifferental;
@property (nullable, copy) NSString *GPSMapDatum;
@property (nullable, copy) NSString *GPSMeasureMode;
@property (nullable, copy) NSString *GPSProcessingMethod;
@property (nullable, copy) NSString *GPSStatus;
@property (nullable, strong) NSNumber *GPSTrack;
@property (nullable, strong) NSNumber *GPSDOP;
@property (nullable, strong) NSNumber *hasAlphaChannel;
@property (nullable, copy) NSString *headline;
@property (nullable, copy) NSArray<CSPerson *> *hiddenAdditionalRecipients;
@property (nullable, copy) NSData *HTMLContentData;
@property (nullable, copy) NSString *identifier;
@property (nullable, strong) NSNumber *imageDirection;
@property (nullable, copy) NSArray<NSDate *> *importantDates;
@property (nullable, copy) NSString *information;
@property (nullable, copy) NSArray<NSString *> *instantMessageAddresses;
@property (nullable, copy) NSString *instructions;
@property (nullable, strong) NSNumber *isPriority;
@property (nullable, strong) NSNumber *ISOSpeed;
@property (nullable, copy) NSString *keySignature;
@property (nullable, copy) NSArray<NSString *> *keywords;
@property (nullable, copy) NSString *kind;
@property (nullable, copy) NSArray<NSString *> *languages;
@property (nullable, strong) NSDate *lastUsedDate;
@property (nullable, strong) NSNumber *latitude;
@property (nullable, copy) NSArray<NSString *> *layerNames;
@property (nullable, copy) NSString *lensModel;
@property (strong) NSNumber *likelyJunk;
@property (nullable, strong) NSNumber *local;
@property (nullable, strong) NSNumber *longitude;
@property (nullable, copy) NSString *lyricist;
@property (nullable, copy) NSArray<NSString *> *mailboxIdentifiers;
@property (nullable, strong) NSNumber *maxAperture;
@property (nullable, copy) NSArray<NSString *> *mediaTypes;
@property (nullable, strong) NSDate *metadataModificationDate;
@property (nullable, copy) NSString *meteringMode;
@property (nullable, copy) NSString *musicalGenre;
@property (nullable, copy) NSString *musicalInstrumentCategory;
@property (nullable, copy) NSString *musicalInstrumentName;
@property (nullable, copy) NSString *namedLocation;
@property (nullable, copy) NSArray<NSString *> *organizations;
@property (nullable, strong) NSNumber *orientation;
@property (nullable, copy) NSString *originalFormat;
@property (nullable, copy) NSString *originalSource;
@property (nullable, strong) NSNumber *pageCount;
@property (nullable, strong) NSNumber *pageHeight;
@property (nullable, strong) NSNumber *pageWidth;
@property (nullable, copy) NSArray<NSString *> *participants;
@property (nullable, copy) NSString *path;
@property (nullable, copy) NSArray<NSString *> *performers;
@property (nullable, copy) NSArray<NSString *> *phoneNumbers;
@property (nullable, strong) NSNumber *pixelCount;
@property (nullable, strong) NSNumber *pixelHeight;
@property (nullable, strong) NSNumber *pixelWidth;
@property (nullable, strong) NSNumber *playCount;
@property (nullable, copy) NSString *postalCode;
@property (nullable, copy) NSArray<CSPerson *> *primaryRecipients;
@property (nullable, copy) NSString *producer;
@property (nullable, copy) NSString *profileName;
@property (nullable, copy) NSArray<NSString *> *projects;
@property (nullable, copy) NSArray<NSString *> *providerDataTypeIdentifiers;
@property (nullable, copy) NSArray<NSString *> *providerFileTypeIdentifiers;
@property (nullable, copy) NSArray<NSString *> *providerInPlaceFileTypeIdentifiers;
@property (nullable, copy) NSArray<NSString *> *publishers;
@property (nullable, strong) NSNumber *rankingHint;
@property (nullable, strong) NSNumber *rating;
@property (nullable, copy) NSString *ratingDescription;
@property (nullable, copy) NSArray<NSString *> *recipientAddresses;
@property (nullable, copy) NSArray<NSString *> *recipientEmailAddresses;
@property (nullable, copy) NSArray<NSString *> *recipientNames;
@property (nullable, strong) NSDate *recordingDate;
@property (nullable, strong) NSNumber *redEyeOn;
@property (nullable, copy) NSString *relatedUniqueIdentifier;
@property (nullable, strong) NSNumber *resolutionHeightDPI;
@property (nullable, strong) NSNumber *resolutionWidthDPI;
@property (nullable, copy) NSString *rights;
@property (nullable, copy) NSString *role;
@property (nullable, copy) NSString *securityMethod;
@property (nullable, strong) NSNumber *speed;
@property (nullable, strong) NSDate *startDate;
@property (nullable, copy) NSString *stateOrProvince;
@property (nullable, strong) NSNumber *streamable;
@property (nullable, copy) NSString *subThoroughfare;
@property (nullable, copy) NSString *subject;
@property (nullable, strong) NSNumber *supportsNavigation;
@property (nullable, strong) NSNumber *supportsPhoneCall;
@property (nullable, strong) NSNumber *tempo;
@property (nullable, copy) NSString *textContent;
@property (nullable, copy) NSString *textContentSummary;
@property (nullable, copy) NSString *theme;
@property (nullable, copy) NSString *thoroughfare;
@property (nullable, copy) NSData *thumbnailData;
@property (nullable, strong) NSURL *thumbnailURL;
@property (nullable, copy) NSString *timeSignature;
@property (nullable, strong) NSDate *timestamp;
@property (nullable, copy) NSString *title;
@property (nullable, strong) NSNumber *totalBitRate;
@property (nullable, copy) NSString *transcribedTextContent;
@property (nullable, strong) NSURL *URL;
@property (nullable, strong) NSNumber *userCreated;
@property (nullable, strong) NSNumber *userCurated;
@property (nullable, strong) NSNumber *userOwned;
@property (nullable, copy) NSString *version;
@property (nullable, strong) NSNumber *videoBitRate;
@property (nullable, copy) NSString *weakRelatedUniqueIdentifier;
@property (nullable, strong) NSNumber *whiteBalance;
@end

/* ---------------- items and the index ---------------- */
typedef NS_OPTIONS(NSUInteger, CSSearchableItemUpdateListenerOptions) {
    CSSearchableItemUpdateListenerOptionDefault = 0,
    CSSearchableItemUpdateListenerOptionSummarization = 1 << 1,
    CSSearchableItemUpdateListenerOptionPriority = 1 << 2,
} API_AVAILABLE(ios(18.0));

@interface CSSearchableItem : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithUniqueIdentifier:(nullable NSString *)uniqueIdentifier domainIdentifier:(nullable NSString *)domainIdentifier
                            attributeSet:(CSSearchableItemAttributeSet *)attributeSet;
@property (copy) NSString *uniqueIdentifier;
@property (nullable, copy) NSString *domainIdentifier;
@property (strong) CSSearchableItemAttributeSet *attributeSet;
@property (copy, null_resettable) NSDate *expirationDate;
@property (assign) BOOL isUpdate API_AVAILABLE(ios(16.0));
@property (assign) CSSearchableItemUpdateListenerOptions updateListenerOptions API_AVAILABLE(ios(18.0));
- (NSComparisonResult)compareByRank:(CSSearchableItem *)other API_AVAILABLE(ios(16.0));
@end

@protocol CSSearchableIndexDelegate;

@interface CSSearchableIndex : NSObject
+ (BOOL)isIndexingAvailable;
+ (instancetype)defaultSearchableIndex;
- (instancetype)initWithName:(NSString *)name;
- (instancetype)initWithName:(NSString *)name protectionClass:(nullable NSFileProtectionType)protectionClass;
@property (weak, nullable) id<CSSearchableIndexDelegate> indexDelegate;
- (void)indexSearchableItems:(NSArray<CSSearchableItem *> *)items completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers
                           completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteSearchableItemsWithDomainIdentifiers:(NSArray<NSString *> *)domainIdentifiers
                                 completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)deleteAllSearchableItemsWithCompletionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
/* batches: the client state is kept with the batch's items */
- (void)beginIndexBatch;
- (void)endIndexBatchWithClientState:(NSData *)clientState completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler;
- (void)endIndexBatchWithExpectedClientState:(nullable NSData *)expectedClientState newClientState:(NSData *)newClientState
                           completionHandler:(void (^ _Nullable)(NSError * _Nullable error))completionHandler API_AVAILABLE(ios(17.0));
- (void)fetchLastClientStateWithCompletionHandler:(void (^)(NSData * _Nullable clientState, NSError * _Nullable error))completionHandler;
- (void)fetchDataForBundleIdentifier:(NSString *)bundleIdentifier itemIdentifier:(NSString *)itemIdentifier contentType:(UTType *)contentType
                   completionHandler:(void (^)(NSData * _Nullable data, NSError * _Nullable error))completionHandler API_AVAILABLE(ios(17.0));
@end

/* the app's object that reindexes items when Spotlight asks (`isim spotlight reindex|items|throttle APP`) */
@protocol CSSearchableIndexDelegate <NSObject>
@required
- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexAllSearchableItemsWithAcknowledgementHandler:(void (^)(void))acknowledgementHandler;
- (void)searchableIndex:(CSSearchableIndex *)searchableIndex reindexSearchableItemsWithIdentifiers:(NSArray<NSString *> *)identifiers
 acknowledgementHandler:(void (^)(void))acknowledgementHandler;
@optional
- (void)searchableIndexDidThrottle:(CSSearchableIndex *)searchableIndex;
- (void)searchableIndexDidFinishThrottle:(CSSearchableIndex *)searchableIndex;
- (nullable NSData *)dataForSearchableIndex:(CSSearchableIndex *)searchableIndex itemIdentifier:(NSString *)itemIdentifier
                             typeIdentifier:(NSString *)typeIdentifier error:(NSError **)outError;
- (nullable NSURL *)fileURLForSearchableIndex:(CSSearchableIndex *)searchableIndex itemIdentifier:(NSString *)itemIdentifier
                               typeIdentifier:(NSString *)typeIdentifier inPlace:(BOOL)inPlace error:(NSError **)outError;
- (void)searchableItemsDidUpdate:(NSArray<CSSearchableItem *> *)items API_AVAILABLE(ios(18.0));
- (void)searchableItemsForIdentifiers:(NSArray<NSString *> *)identifiers
               searchableItemsHandler:(void (^)(NSArray<CSSearchableItem *> *items))searchableItemsHandler API_AVAILABLE(ios(18.0));
- (void)searchableItemsForIdentifiers:(NSArray<NSString *> *)identifiers protectionClass:(NSFileProtectionType)protectionClass
               searchableItemsHandler:(void (^)(NSArray<CSSearchableItem *> *items))searchableItemsHandler API_AVAILABLE(ios(18.0));
@end

/* extensions: the principal class of a com.apple.spotlight.index / com.apple.spotlight.import extension */
@interface CSIndexExtensionRequestHandler : NSObject <NSExtensionRequestHandling, CSSearchableIndexDelegate>
@end
API_AVAILABLE(ios(15.0))
@interface CSImportExtension : NSObject <NSExtensionRequestHandling>
- (BOOL)updateAttributes:(CSSearchableItemAttributeSet *)attributes forFileAtURL:(NSURL *)contentURL error:(NSError **)error;
@end

/* ---------------- queries ---------------- */
typedef NS_OPTIONS(NSUInteger, CSSearchQuerySourceOptions) {
    CSSearchQuerySourceOptionDefault = 0,
    CSSearchQuerySourceOptionAllowMail = 1 << 0,
} API_AVAILABLE(ios(16.0));

API_AVAILABLE(ios(16.0))
@interface CSSearchQueryContext : NSObject <NSSecureCoding, NSCopying>
@property (copy) NSArray<NSString *> *fetchAttributes;
@property (copy) NSArray<NSString *> *filterQueries;
@property (copy, nullable) NSString *keyboardLanguage;
@property (assign) CSSearchQuerySourceOptions sourceOptions;
@end

/* Spotlight's query language: title == "Coffee*"cd && rating >= 4, InRange(...), $time.today(-7), * == "word"w */
@interface CSSearchQuery : NSObject
- (instancetype)initWithQueryString:(NSString *)queryString queryContext:(nullable CSSearchQueryContext *)queryContext API_AVAILABLE(ios(16.0));
- (instancetype)initWithQueryString:(NSString *)queryString attributes:(nullable NSArray<NSString *> *)attributes
    API_DEPRECATED("Use initWithQueryString:queryContext:", ios(10.0, 18.0));
@property (readonly, getter=isCancelled) BOOL cancelled;
@property (readonly) NSUInteger foundItemCount;
@property (nullable, copy) void (^foundItemsHandler)(NSArray<CSSearchableItem *> *items);
@property (nullable, copy) void (^completionHandler)(NSError * _Nullable error);
@property (copy) NSArray<NSFileProtectionType> *protectionClasses;
- (void)start;
- (void)cancel;
@end

/* ---------------- user queries (iOS 18) ---------------- */
typedef NS_ENUM(NSInteger, CSSuggestionKind) {
    CSSuggestionKindNone,
    CSSuggestionKindCustom,
    CSSuggestionKindDefault,
} API_AVAILABLE(ios(18.0));
typedef NS_ENUM(NSInteger, CSUserInteraction) {
    CSUserInteractionSelect,
    CSUserInteractionDefault = CSUserInteractionSelect,
    CSUserInteractionFocus,
} API_AVAILABLE(ios(18.0));

API_AVAILABLE(ios(18.0))
@interface CSSuggestion : NSObject <NSSecureCoding, NSCopying>
@property (readonly, copy) NSAttributedString *localizedAttributedSuggestion;
@property (readonly) CSSuggestionKind suggestionKind;
- (NSComparisonResult)compareByRank:(CSSuggestion *)other;
- (NSComparisonResult)compare:(CSSuggestion *)other;
@end

API_AVAILABLE(ios(18.0))
@interface CSUserQueryContext : CSSearchQueryContext
+ (instancetype)userQueryContext;
+ (instancetype)userQueryContextWithCurrentSuggestion:(nullable CSSuggestion *)currentSuggestion;
@property (assign) NSInteger maxResultCount;
@property (assign) NSInteger maxSuggestionCount;
@property (assign) BOOL enableRankedResults;
@property (assign) NSInteger maxRankedResultCount;
@property (assign) BOOL disableSemanticSearch;
@end

API_AVAILABLE(ios(18.0))
@interface CSUserQuery : CSSearchQuery
+ (void)prepare;
- (instancetype)initWithUserQueryString:(nullable NSString *)userQueryString userQueryContext:(nullable CSUserQueryContext *)userQueryContext;
@property (nullable, copy) void (^foundSuggestionsHandler)(NSArray<CSSuggestion *> *suggestions);
@property (readonly) NSInteger foundSuggestionCount;
- (void)userEngagedWithItem:(CSSearchableItem *)item visibleItems:(NSArray<CSSearchableItem *> *)visibleItems userInteractionType:(CSUserInteraction)userInteractionType;
- (void)userEngagedWithSuggestion:(CSSuggestion *)suggestion visibleSuggestions:(NSArray<CSSuggestion *> *)visibleSuggestions userInteractionType:(CSUserInteraction)userInteractionType;
@end

NS_ASSUME_NONNULL_END
#endif
