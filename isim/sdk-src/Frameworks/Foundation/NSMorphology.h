#pragma once
/* isim SDK (self-authored, Apple's declarations): automatic grammar agreement. Morphology (gender, number, part of
   speech...), terms of address, inflection rules, and inflecting attributed strings. Adapted (frameworks/Foundation/
   Inflection.m): isim's own agreement rules for English, Spanish, French, Italian and Portuguese. */
#import <Foundation/NSObject.h>
#import <Foundation/NSAttributedString.h>
NS_ASSUME_NONNULL_BEGIN
@class NSString, NSArray<ObjectType>;

typedef NS_ENUM(NSInteger, NSGrammaticalGender) {
    NSGrammaticalGenderNotSet = 0, NSGrammaticalGenderFeminine, NSGrammaticalGenderMasculine, NSGrammaticalGenderNeuter
};
typedef NS_ENUM(NSInteger, NSGrammaticalPartOfSpeech) {
    NSGrammaticalPartOfSpeechNotSet = 0, NSGrammaticalPartOfSpeechDeterminer, NSGrammaticalPartOfSpeechPronoun, NSGrammaticalPartOfSpeechLetter,
    NSGrammaticalPartOfSpeechAdverb, NSGrammaticalPartOfSpeechParticle, NSGrammaticalPartOfSpeechAdjective, NSGrammaticalPartOfSpeechAdposition,
    NSGrammaticalPartOfSpeechVerb, NSGrammaticalPartOfSpeechNoun, NSGrammaticalPartOfSpeechConjunction, NSGrammaticalPartOfSpeechNumeral,
    NSGrammaticalPartOfSpeechInterjection, NSGrammaticalPartOfSpeechPreposition, NSGrammaticalPartOfSpeechAbbreviation
};
typedef NS_ENUM(NSInteger, NSGrammaticalNumber) {
    NSGrammaticalNumberNotSet = 0, NSGrammaticalNumberSingular, NSGrammaticalNumberZero, NSGrammaticalNumberPlural,
    NSGrammaticalNumberPluralTwo, NSGrammaticalNumberPluralFew, NSGrammaticalNumberPluralMany
};
typedef NS_ENUM(NSInteger, NSGrammaticalCase) {
    NSGrammaticalCaseNotSet = 0, NSGrammaticalCaseNominative, NSGrammaticalCaseAccusative, NSGrammaticalCaseDative, NSGrammaticalCaseGenitive,
    NSGrammaticalCasePrepositional, NSGrammaticalCaseAblative, NSGrammaticalCaseAdessive, NSGrammaticalCaseAllative, NSGrammaticalCaseElative,
    NSGrammaticalCaseIllative, NSGrammaticalCaseEssive, NSGrammaticalCaseInessive, NSGrammaticalCaseLocative, NSGrammaticalCaseTranslative
};
typedef NS_ENUM(NSInteger, NSGrammaticalPronounType) {
    NSGrammaticalPronounTypeNotSet = 0, NSGrammaticalPronounTypePersonal, NSGrammaticalPronounTypeReflexive, NSGrammaticalPronounTypePossessive
};
typedef NS_ENUM(NSInteger, NSGrammaticalPerson) {
    NSGrammaticalPersonNotSet = 0, NSGrammaticalPersonFirst, NSGrammaticalPersonSecond, NSGrammaticalPersonThird
};
typedef NS_ENUM(NSInteger, NSGrammaticalDetermination) {
    NSGrammaticalDeterminationNotSet = 0, NSGrammaticalDeterminationIndependent, NSGrammaticalDeterminationDependent
};
typedef NS_ENUM(NSInteger, NSGrammaticalDefiniteness) {
    NSGrammaticalDefinitenessNotSet = 0, NSGrammaticalDefinitenessIndefinite, NSGrammaticalDefinitenessDefinite
};

@interface NSMorphology : NSObject <NSCopying, NSSecureCoding>
@property NSGrammaticalGender grammaticalGender;
@property NSGrammaticalPartOfSpeech partOfSpeech;
@property NSGrammaticalNumber number;
@property NSGrammaticalCase grammaticalCase;
@property NSGrammaticalDetermination determination;
@property NSGrammaticalPerson grammaticalPerson;
@property NSGrammaticalPronounType pronounType;
@property NSGrammaticalDefiniteness definiteness;
@property (readonly, getter=isUnspecified) BOOL unspecified;
/* the user's morphology (isim: unspecified; set no term of address in Settings) */
@property (class, readonly) NSMorphology *userMorphology;
/* isim-private: `string` inflected for `language` ("en", "es"...) to the number (NSGrammaticalNumber, 0: from a numeral
   in the string) and gender (NSGrammaticalGender, 0: unchanged) */
+ (NSString *)_isim_inflectString:(NSString *)string language:(NSString *)language number:(NSInteger)number gender:(NSInteger)gender
                     partOfSpeech:(NSInteger)partOfSpeech;
@end

@interface NSMorphologyPronoun : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithPronoun:(NSString *)pronoun morphology:(NSMorphology *)morphology dependentMorphology:(nullable NSMorphology *)dependentMorphology;
@property (readonly, copy) NSString *pronoun;
@property (readonly, copy) NSMorphology *morphology;
@property (readonly, copy, nullable) NSMorphology *dependentMorphology;
@end

@interface NSTermOfAddress : NSObject <NSCopying, NSSecureCoding>
+ (instancetype)neutral;
+ (instancetype)feminine;
+ (instancetype)masculine;
@property (class, readonly) NSTermOfAddress *currentUser;
+ (instancetype)localizedForLanguageIdentifier:(NSString *)language withPronouns:(NSArray<NSMorphologyPronoun *> *)pronouns;
@property (readonly, nullable, copy) NSString *languageIdentifier;
@property (readonly, nullable, copy) NSArray<NSMorphologyPronoun *> *pronouns;
/* isim-private: the gender this term of address agrees with (NSGrammaticalGender) */
@property (readonly) NSInteger _isimGender;
@end

@interface NSInflectionRule : NSObject <NSCopying, NSSecureCoding>
@property (class, readonly) NSInflectionRule *automaticRule;
+ (BOOL)canInflectLanguage:(NSString *)language;
@property (class, readonly) BOOL canInflectPreferredLocalization;
@end
@interface NSInflectionRuleExplicit : NSInflectionRule
- (instancetype)initWithMorphology:(NSMorphology *)morphology;
@property (readonly, copy) NSMorphology *morphology;
@end

FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionRuleAttributeName NS_SWIFT_NAME(inflectionRule);
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAlternativeAttributeName NS_SWIFT_NAME(inflectionAlternative);
FOUNDATION_EXPORT NSAttributedStringKey const NSMorphologyAttributeName NS_SWIFT_NAME(morphology);
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionReferentConceptAttributeName NS_SWIFT_NAME(inflectionReferentConcept);
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementArgumentAttributeName NS_SWIFT_NAME(inflectionAgreementArgument);
FOUNDATION_EXPORT NSAttributedStringKey const NSInflectionAgreementConceptAttributeName NS_SWIFT_NAME(inflectionAgreementConcept);

@interface NSAttributedString (NSInflection)
/* the runs with an inflection rule (NSInflectionRuleAttributeName), inflected to agree */
- (NSAttributedString *)attributedStringByInflectingString NS_SWIFT_NAME(inflecting());
@end
NS_ASSUME_NONNULL_END
