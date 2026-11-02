#pragma once
/* isim SDK (self-authored): braille translation (iOS 26) over the host's liblouis: the tables are liblouis's language
 * tables (AXBrailleTable), translation gives Unicode braille (U+2800...) and back-translation reads it. Without liblouis
 * there are no tables. Swift refines the locales, the language and the input index (the Accessibility overlay). */
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN

API_AVAILABLE(ios(26.0))
@interface AXBrailleTable : NSObject <NSSecureCoding>
- (nullable instancetype)initWithIdentifier:(NSString *)identifier;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, readonly, copy) NSString *localizedName;
@property (nonatomic, readonly, copy) NSString *providerIdentifier;
@property (nonatomic, readonly, copy) NSString *localizedProviderName;
@property (nonatomic, readonly) BOOL isEightDot;
/* the language's identifier (Swift: Locale.Language) and the locales' identifiers (Swift: Set<Locale>) */
@property (nonatomic, readonly, copy) NSString *language NS_REFINED_FOR_SWIFT;
@property (nonatomic, readonly, copy) NSSet<NSString *> *locales NS_REFINED_FOR_SWIFT;
+ (NSSet<AXBrailleTable *> *)tablesForLocale:(NSString *)localeIdentifier NS_REFINED_FOR_SWIFT;
+ (nullable AXBrailleTable *)defaultTableForLocale:(NSString *)localeIdentifier NS_REFINED_FOR_SWIFT;
+ (NSSet<NSString *> *)supportedLocales NS_REFINED_FOR_SWIFT;
+ (NSSet<AXBrailleTable *> *)languageAgnosticTables;
@end

API_AVAILABLE(ios(26.0))
@interface AXBrailleTranslationResult : NSObject <NSSecureCoding>
@property (nonatomic, readonly, copy) NSString *resultString;
/* the UTF-16 index in the input of the result's character at this UTF-16 index, or NSNotFound */
- (NSUInteger)inputIndexForResultIndex:(NSUInteger)resultIndex NS_REFINED_FOR_SWIFT;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@end

API_AVAILABLE(ios(26.0))
@interface AXBrailleTranslator : NSObject
- (instancetype)initWithBrailleTable:(AXBrailleTable *)brailleTable;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
- (AXBrailleTranslationResult *)translatePrintText:(NSString *)printText;
- (AXBrailleTranslationResult *)backTranslateBraille:(NSString *)braille;
@end

NS_ASSUME_NONNULL_END
