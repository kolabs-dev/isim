#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSNotification.h>
NS_ASSUME_NONNULL_BEGIN
@class NSArray<ObjectType>, NSString;
typedef NSString *NSLocaleKey NS_TYPED_ENUM;
FOUNDATION_EXPORT NSLocaleKey const NSLocaleIdentifier, NSLocaleLanguageCode, NSLocaleCountryCode, NSLocaleScriptCode,
    NSLocaleDecimalSeparator, NSLocaleGroupingSeparator, NSLocaleCurrencySymbol, NSLocaleCurrencyCode, NSLocaleUsesMetricSystem,
    NSLocaleCalendarIdentifier;
FOUNDATION_EXPORT NSNotificationName const NSCurrentLocaleDidChangeNotification;
typedef NS_ENUM(NSUInteger, NSLocaleLanguageDirection) {
    NSLocaleLanguageDirectionUnknown = 0, NSLocaleLanguageDirectionLeftToRight = 1, NSLocaleLanguageDirectionRightToLeft = 2,
    NSLocaleLanguageDirectionTopToBottom = 3, NSLocaleLanguageDirectionBottomToTop = 4
};
@interface NSLocale : NSObject <NSCopying, NSSecureCoding>
@property (class, readonly, copy) NSLocale *currentLocale;
@property (class, readonly, strong) NSLocale *autoupdatingCurrentLocale;
@property (class, readonly, copy) NSLocale *systemLocale;
@property (class, readonly, copy) NSArray<NSString *> *preferredLanguages;
@property (class, readonly, copy) NSArray<NSString *> *availableLocaleIdentifiers;
+ (instancetype)localeWithLocaleIdentifier:(NSString *)ident;
- (instancetype)initWithLocaleIdentifier:(NSString *)string NS_DESIGNATED_INITIALIZER;
- (nullable id)objectForKey:(NSLocaleKey)key;
- (nullable NSString *)displayNameForKey:(NSLocaleKey)key value:(id)value;
@property (readonly, copy) NSString *localeIdentifier;
@property (nullable, readonly, copy) NSString *languageCode;
@property (nullable, readonly, copy) NSString *countryCode;
@property (nullable, readonly, copy) NSString *regionCode;
@property (nullable, readonly, copy) NSString *scriptCode;
@property (readonly, copy) NSString *calendarIdentifier;
@property (readonly, copy) NSString *decimalSeparator;
@property (readonly, copy) NSString *groupingSeparator;
@property (nullable, readonly, copy) NSString *currencySymbol;
@property (nullable, readonly, copy) NSString *currencyCode;
@property (readonly) BOOL usesMetricSystem;
- (nullable NSString *)localizedStringForLocaleIdentifier:(NSString *)localeIdentifier;
- (nullable NSString *)localizedStringForLanguageCode:(NSString *)languageCode;
- (nullable NSString *)localizedStringForCountryCode:(NSString *)countryCode;
- (nullable NSString *)localizedStringForScriptCode:(NSString *)scriptCode;
- (nullable NSString *)localizedStringForCurrencyCode:(NSString *)currencyCode;
- (nullable NSString *)localizedStringForCalendarIdentifier:(NSString *)calendarIdentifier;
+ (NSLocaleLanguageDirection)characterDirectionForLanguage:(NSString *)isoLangCode;
@end
NS_ASSUME_NONNULL_END
