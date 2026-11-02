#pragma once
/* isim NaturalLanguage for Objective-C (issue #701): the classes are the NaturalLanguage Swift overlay's
   (NaturalLanguage.framework re-exports libswiftNaturalLanguage.dylib); Swift uses the overlay, so these declarations
   are hidden from Swift. Tokenizing, tagging and language recognition use isim's rules, embeddings the host's fastText
   vectors (ISIM_WORD_VECTORS); see the Swift overlay. */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
@class MLModel;

/* ---- NLLanguage ---- */
typedef NSString *NLLanguage NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NLLanguage const NLLanguageUndetermined;
FOUNDATION_EXPORT NLLanguage const NLLanguageAmharic, NLLanguageArabic, NLLanguageArmenian, NLLanguageBengali, NLLanguageBulgarian,
    NLLanguageBurmese, NLLanguageCatalan, NLLanguageCherokee, NLLanguageCroatian, NLLanguageCzech, NLLanguageDanish, NLLanguageDutch,
    NLLanguageEnglish, NLLanguageFinnish, NLLanguageFrench, NLLanguageGeorgian, NLLanguageGerman, NLLanguageGreek, NLLanguageGujarati,
    NLLanguageHebrew, NLLanguageHindi, NLLanguageHungarian, NLLanguageIcelandic, NLLanguageIndonesian, NLLanguageItalian,
    NLLanguageJapanese, NLLanguageKannada, NLLanguageKhmer, NLLanguageKorean, NLLanguageLao, NLLanguageMalay, NLLanguageMalayalam,
    NLLanguageMarathi, NLLanguageMongolian, NLLanguageNorwegian, NLLanguageOriya, NLLanguagePersian, NLLanguagePolish,
    NLLanguagePortuguese, NLLanguagePunjabi, NLLanguageRomanian, NLLanguageRussian, NLLanguageSimplifiedChinese, NLLanguageSinhalese,
    NLLanguageSlovak, NLLanguageSpanish, NLLanguageSwedish, NLLanguageTamil, NLLanguageTelugu, NLLanguageThai, NLLanguageTibetan,
    NLLanguageTraditionalChinese, NLLanguageTurkish, NLLanguageUkrainian, NLLanguageUrdu, NLLanguageVietnamese;
FOUNDATION_EXPORT NLLanguage const NLLanguageKazakh API_AVAILABLE(ios(16.0));
FOUNDATION_EXPORT NLLanguage const NLLanguageKurdish, NLLanguageLithuanian, NLLanguageLatvian, NLLanguageSlovenian, NLLanguageEstonian,
    NLLanguageSerbian, NLLanguageTagalog API_AVAILABLE(ios(17.0));

/* ---- NLScript ---- */
typedef NSString *NLScript NS_TYPED_EXTENSIBLE_ENUM API_AVAILABLE(ios(17.0));
FOUNDATION_EXPORT NLScript const NLScriptUndetermined, NLScriptArabic, NLScriptArmenian, NLScriptBengali, NLScriptCanadianAboriginalSyllabics,
    NLScriptCherokee, NLScriptCyrillic, NLScriptDevanagari, NLScriptEthiopic, NLScriptGeorgian, NLScriptGreek, NLScriptGujarati,
    NLScriptGurmukhi, NLScriptHebrew, NLScriptJapanese, NLScriptKannada, NLScriptKhmer, NLScriptKorean, NLScriptLao, NLScriptLatin,
    NLScriptMalayalam, NLScriptMongolian, NLScriptMyanmar, NLScriptOriya, NLScriptSimplifiedChinese, NLScriptSinhala, NLScriptTamil,
    NLScriptTelugu, NLScriptThai, NLScriptTibetan, NLScriptTraditionalChinese API_AVAILABLE(ios(17.0));

/* ---- NLTagScheme, NLTag ---- */
typedef NSString *NLTagScheme NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NLTagScheme const NLTagSchemeTokenType, NLTagSchemeLexicalClass, NLTagSchemeNameType, NLTagSchemeNameTypeOrLexicalClass,
    NLTagSchemeLemma, NLTagSchemeLanguage, NLTagSchemeScript;
FOUNDATION_EXPORT NLTagScheme const NLTagSchemeSentimentScore API_AVAILABLE(ios(13.0));

typedef NSString *NLTag NS_TYPED_EXTENSIBLE_ENUM;
FOUNDATION_EXPORT NLTag const NLTagWord, NLTagPunctuation, NLTagWhitespace, NLTagOther;
FOUNDATION_EXPORT NLTag const NLTagNoun, NLTagVerb, NLTagAdjective, NLTagAdverb, NLTagPronoun, NLTagDeterminer, NLTagParticle,
    NLTagPreposition, NLTagNumber, NLTagConjunction, NLTagInterjection, NLTagClassifier, NLTagIdiom, NLTagOtherWord,
    NLTagSentenceTerminator, NLTagOpenQuote, NLTagCloseQuote, NLTagOpenParenthesis, NLTagCloseParenthesis, NLTagWordJoiner, NLTagDash,
    NLTagOtherPunctuation, NLTagParagraphBreak, NLTagOtherWhitespace;
FOUNDATION_EXPORT NLTag const NLTagPersonalName, NLTagPlaceName, NLTagOrganizationName;

typedef NS_ENUM(NSInteger, NLTokenUnit) {
    NLTokenUnitWord,
    NLTokenUnitSentence,
    NLTokenUnitParagraph,
    NLTokenUnitDocument
};

/* ---- NLTokenizer ---- */
typedef NS_OPTIONS(NSUInteger, NLTokenizerAttributes) {
    NLTokenizerAttributeNumeric  = 1 << 0,
    NLTokenizerAttributeSymbolic = 1 << 1,
    NLTokenizerAttributeEmoji    = 1 << 2,
};

@interface NLTokenizer : NSObject
- (instancetype)initWithUnit:(NLTokenUnit)unit NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) NLTokenUnit unit;
@property (nullable, nonatomic, retain) NSString *string;
- (void)setLanguage:(NLLanguage)language;
- (NSRange)tokenRangeAtIndex:(NSUInteger)characterIndex;
- (NSRange)tokenRangeForRange:(NSRange)range API_AVAILABLE(ios(14.0));
- (NSArray<NSValue *> *)tokensForRange:(NSRange)range;
- (void)enumerateTokensInRange:(NSRange)range
                    usingBlock:(void (NS_NOESCAPE ^)(NSRange tokenRange, NLTokenizerAttributes flags, BOOL *stop))block;
@end

/* ---- NLLanguageRecognizer ---- */
@interface NLLanguageRecognizer : NSObject
+ (nullable NLLanguage)dominantLanguageForString:(NSString *)string;
- (instancetype)init NS_DESIGNATED_INITIALIZER;
- (void)processString:(NSString *)string;
@property (nullable, nonatomic, readonly, copy) NLLanguage dominantLanguage;
- (NSDictionary<NLLanguage, NSNumber *> *)languageHypothesesWithMaximum:(NSUInteger)maxHypotheses;
- (void)reset;
@property (nonatomic, copy) NSDictionary<NLLanguage, NSNumber *> *languageHints;
@property (nonatomic, copy) NSArray<NLLanguage> *languageConstraints;
@end

/* ---- NLGazetteer ---- */
API_AVAILABLE(ios(13.0))
@interface NLGazetteer : NSObject
+ (nullable instancetype)gazetteerWithContentsOfURL:(NSURL *)url error:(NSError **)error;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url error:(NSError **)error;
- (nullable instancetype)initWithData:(NSData *)data error:(NSError **)error;
- (nullable instancetype)initWithDictionary:(NSDictionary<NSString *, NSArray<NSString *> *> *)dictionary
                                   language:(nullable NLLanguage)language error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
- (nullable NSString *)labelForString:(NSString *)string;
@property (nullable, nonatomic, readonly, copy) NLLanguage language;
@property (nonatomic, readonly, copy) NSData *data;
+ (BOOL)writeGazetteerForDictionary:(NSDictionary<NSString *, NSArray<NSString *> *> *)dictionary language:(nullable NLLanguage)language
                              toURL:(NSURL *)url error:(NSError **)error;
@end

/* ---- NLModel ---- */
typedef NS_ENUM(NSInteger, NLModelType) {
    NLModelTypeClassifier,
    NLModelTypeSequence
};

@interface NLModelConfiguration : NSObject <NSCopying, NSSecureCoding>
@property (nonatomic, readonly) NLModelType type;
@property (nullable, nonatomic, readonly, copy) NLLanguage language;
@property (nonatomic, readonly) NSUInteger revision;
+ (NSIndexSet *)supportedRevisionsForType:(NLModelType)type;
+ (NSUInteger)currentRevisionForType:(NLModelType)type;
@end

@interface NLModel : NSObject
+ (nullable instancetype)modelWithContentsOfURL:(NSURL *)url error:(NSError **)error;
+ (nullable instancetype)modelWithMLModel:(MLModel *)mlModel error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NLModelConfiguration *configuration;
- (nullable NSString *)predictedLabelForString:(NSString *)string;
- (NSArray<NSString *> *)predictedLabelsForTokens:(NSArray<NSString *> *)tokens;
- (NSDictionary<NSString *, NSNumber *> *)predictedLabelHypothesesForString:(NSString *)string maximumCount:(NSUInteger)maximumCount
    API_AVAILABLE(ios(14.0));
- (NSArray<NSDictionary<NSString *, NSNumber *> *> *)predictedLabelHypothesesForTokens:(NSArray<NSString *> *)tokens
                                                                         maximumCount:(NSUInteger)maximumCount API_AVAILABLE(ios(14.0));
@end

/* ---- NLTagger ---- */
typedef NS_OPTIONS(NSUInteger, NLTaggerOptions) {
    NLTaggerOmitWords        = 1 << 0,
    NLTaggerOmitPunctuation  = 1 << 1,
    NLTaggerOmitWhitespace   = 1 << 2,
    NLTaggerOmitOther        = 1 << 3,
    NLTaggerJoinNames        = 1 << 4,
    NLTaggerJoinContractions = 1 << 5,
};

@interface NLTagger : NSObject
- (instancetype)initWithTagSchemes:(NSArray<NLTagScheme> *)tagSchemes NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSArray<NLTagScheme> *tagSchemes;
@property (nullable, nonatomic, retain) NSString *string;
+ (NSArray<NLTagScheme> *)availableTagSchemesForUnit:(NLTokenUnit)unit language:(NLLanguage)language;
- (NSRange)tokenRangeAtIndex:(NSUInteger)characterIndex unit:(NLTokenUnit)unit;
- (NSRange)tokenRangeForRange:(NSRange)range unit:(NLTokenUnit)unit API_AVAILABLE(ios(14.0));
@property (nullable, nonatomic, readonly, copy) NLLanguage dominantLanguage;
- (void)enumerateTagsInRange:(NSRange)range unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme options:(NLTaggerOptions)options
                  usingBlock:(void (NS_NOESCAPE ^)(NLTag _Nullable tag, NSRange tokenRange, BOOL *stop))block;
- (nullable NLTag)tagAtIndex:(NSUInteger)characterIndex unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme
                  tokenRange:(nullable NSRangePointer)tokenRange;
- (NSArray<NLTag> *)tagsInRange:(NSRange)range unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme options:(NLTaggerOptions)options
                    tokenRanges:(NSArray<NSValue *> * _Nullable * _Nullable)tokenRanges;
- (NSDictionary<NLTag, NSNumber *> *)tagHypothesesAtIndex:(NSUInteger)characterIndex unit:(NLTokenUnit)unit scheme:(NLTagScheme)scheme
                                             maximumCount:(NSUInteger)maximumCount tokenRange:(nullable NSRangePointer)tokenRange
    API_AVAILABLE(ios(14.0));
- (void)setLanguage:(NLLanguage)language range:(NSRange)range;
- (void)setModels:(NSArray<NLModel *> *)models forTagScheme:(NLTagScheme)tagScheme;
- (NSArray<NLModel *> *)modelsForTagScheme:(NLTagScheme)tagScheme;
- (void)setGazetteers:(NSArray<NLGazetteer *> *)gazetteers forTagScheme:(NLTagScheme)tagScheme API_AVAILABLE(ios(13.0));
- (NSArray<NLGazetteer *> *)gazetteersForTagScheme:(NLTagScheme)tagScheme API_AVAILABLE(ios(13.0));
@end

/* ---- NLEmbedding ---- */
typedef NS_ENUM(NSInteger, NLDistanceType) {
    NLDistanceTypeCosine
} API_AVAILABLE(ios(13.0));
typedef double NLDistance API_AVAILABLE(ios(13.0));

API_AVAILABLE(ios(13.0))
@interface NLEmbedding : NSObject
+ (nullable NLEmbedding *)wordEmbeddingForLanguage:(NLLanguage)language;
+ (nullable NLEmbedding *)wordEmbeddingForLanguage:(NLLanguage)language revision:(NSUInteger)revision;
+ (nullable NLEmbedding *)sentenceEmbeddingForLanguage:(NLLanguage)language API_AVAILABLE(ios(14.0));
+ (nullable NLEmbedding *)sentenceEmbeddingForLanguage:(NLLanguage)language revision:(NSUInteger)revision API_AVAILABLE(ios(14.0));
+ (nullable instancetype)embeddingWithContentsOfURL:(NSURL *)url error:(NSError **)error;
- (instancetype)init NS_UNAVAILABLE;
- (BOOL)containsString:(NSString *)string;
- (NLDistance)distanceBetweenString:(NSString *)firstString andString:(NSString *)secondString distanceType:(NLDistanceType)distanceType;
- (void)enumerateNeighborsForString:(NSString *)string maximumCount:(NSUInteger)maxCount distanceType:(NLDistanceType)distanceType
                         usingBlock:(void (NS_NOESCAPE ^)(NSString *neighbor, NLDistance distance, BOOL *stop))block;
- (void)enumerateNeighborsForString:(NSString *)string maximumCount:(NSUInteger)maxCount maximumDistance:(NLDistance)maxDistance
                       distanceType:(NLDistanceType)distanceType
                         usingBlock:(void (NS_NOESCAPE ^)(NSString *neighbor, NLDistance distance, BOOL *stop))block;
- (nullable NSArray<NSString *> *)neighborsForString:(NSString *)string maximumCount:(NSUInteger)maxCount
                                        distanceType:(NLDistanceType)distanceType;
- (nullable NSArray<NSString *> *)neighborsForString:(NSString *)string maximumCount:(NSUInteger)maxCount
                                     maximumDistance:(NLDistance)maxDistance distanceType:(NLDistanceType)distanceType;
- (nullable NSArray<NSNumber *> *)vectorForString:(NSString *)string;
- (BOOL)getVector:(float *)vector forString:(NSString *)string;
- (void)enumerateNeighborsForVector:(NSArray<NSNumber *> *)vector maximumCount:(NSUInteger)maxCount distanceType:(NLDistanceType)distanceType
                         usingBlock:(void (NS_NOESCAPE ^)(NSString *neighbor, NLDistance distance, BOOL *stop))block;
- (void)enumerateNeighborsForVector:(NSArray<NSNumber *> *)vector maximumCount:(NSUInteger)maxCount maximumDistance:(NLDistance)maxDistance
                       distanceType:(NLDistanceType)distanceType
                         usingBlock:(void (NS_NOESCAPE ^)(NSString *neighbor, NLDistance distance, BOOL *stop))block;
- (nullable NSArray<NSString *> *)neighborsForVector:(NSArray<NSNumber *> *)vector maximumCount:(NSUInteger)maxCount
                                        distanceType:(NLDistanceType)distanceType;
- (nullable NSArray<NSString *> *)neighborsForVector:(NSArray<NSNumber *> *)vector maximumCount:(NSUInteger)maxCount
                                     maximumDistance:(NLDistance)maxDistance distanceType:(NLDistanceType)distanceType;
@property (nonatomic, readonly) NSUInteger dimension;
@property (nonatomic, readonly) NSUInteger vocabularySize;
@property (nullable, nonatomic, readonly, copy) NLLanguage language;
@property (nonatomic, readonly) NSUInteger revision;
+ (NSIndexSet *)supportedRevisionsForLanguage:(NLLanguage)language;
+ (NSUInteger)currentRevisionForLanguage:(NLLanguage)language;
+ (NSIndexSet *)supportedSentenceEmbeddingRevisionsForLanguage:(NLLanguage)language API_AVAILABLE(ios(14.0));
+ (NSUInteger)currentSentenceEmbeddingRevisionForLanguage:(NLLanguage)language API_AVAILABLE(ios(14.0));
+ (BOOL)writeEmbeddingForDictionary:(NSDictionary<NSString *, NSArray<NSNumber *> *> *)dictionary language:(nullable NLLanguage)language
                           revision:(NSUInteger)revision toURL:(NSURL *)url error:(NSError **)error;
@end

/* ---- NLContextualEmbedding (iOS 17) ---- */
typedef NSString *NLContextualEmbeddingKey NS_TYPED_ENUM API_AVAILABLE(ios(17.0));
FOUNDATION_EXPORT NLContextualEmbeddingKey const NLContextualEmbeddingKeyLanguages, NLContextualEmbeddingKeyScripts,
    NLContextualEmbeddingKeyRevision API_AVAILABLE(ios(17.0));

typedef NS_ENUM(NSInteger, NLContextualEmbeddingAssetsResult) {
    NLContextualEmbeddingAssetsResultAvailable,
    NLContextualEmbeddingAssetsResultNotAvailable,
    NLContextualEmbeddingAssetsResultError
} API_AVAILABLE(ios(17.0));

@class NLContextualEmbeddingResult;

API_AVAILABLE(ios(17.0))
@interface NLContextualEmbedding : NSObject
+ (nullable instancetype)contextualEmbeddingWithModelIdentifier:(NSString *)modelIdentifier;
+ (NSArray<NLContextualEmbedding *> *)contextualEmbeddingsForValues:(NSDictionary<NLContextualEmbeddingKey, id> *)valuesDictionary;
+ (nullable instancetype)contextualEmbeddingWithLanguage:(NLLanguage)language;
+ (nullable instancetype)contextualEmbeddingWithScript:(NLScript)script;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *modelIdentifier;
@property (nonatomic, readonly, copy) NSArray<NLLanguage> *languages;
@property (nonatomic, readonly, copy) NSArray<NLScript> *scripts;
@property (nonatomic, readonly) NSUInteger revision;
@property (nonatomic, readonly) NSUInteger dimension;
@property (nonatomic, readonly) NSUInteger maximumSequenceLength;
- (BOOL)loadWithError:(NSError **)error;
- (void)unload;
- (nullable NLContextualEmbeddingResult *)embeddingResultForString:(NSString *)string language:(nullable NLLanguage)language
                                                             error:(NSError **)error;
@property (nonatomic, readonly) BOOL hasAvailableAssets;
- (void)requestEmbeddingAssetsWithCompletionHandler:(void (^)(NLContextualEmbeddingAssetsResult result,
                                                              NSError * _Nullable error))completionHandler;
@end

API_AVAILABLE(ios(17.0))
@interface NLContextualEmbeddingResult : NSObject
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *string;
@property (nonatomic, readonly, copy) NLLanguage language;
@property (nonatomic, readonly) NSUInteger sequenceLength;
- (void)enumerateTokenVectorsInRange:(NSRange)range
                          usingBlock:(void (NS_NOESCAPE ^)(NSArray<NSNumber *> *tokenVector, NSRange tokenRange, BOOL *stop))block;
- (nullable NSArray<NSNumber *> *)tokenVectorAtIndex:(NSUInteger)characterIndex tokenRange:(nullable NSRangePointer)tokenRange;
@end

NS_ASSUME_NONNULL_END
#endif
