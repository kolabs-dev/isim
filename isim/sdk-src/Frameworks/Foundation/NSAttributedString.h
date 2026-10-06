#pragma once
#import <Foundation/NSObject.h>
#import <Foundation/NSString.h>
#import <Foundation/NSDictionary.h>
NS_ASSUME_NONNULL_BEGIN
@class NSURL, NSError;
typedef NSString *NSAttributedStringKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSAttributedString.Key);

@interface NSAttributedString : NSObject <NSCopying, NSMutableCopying, NSSecureCoding>
@property (readonly, copy) NSString *string;
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location effectiveRange:(nullable NSRangePointer)range;
@end

typedef NS_OPTIONS(NSUInteger, NSAttributedStringEnumerationOptions) {
    NSAttributedStringEnumerationReverse NS_SWIFT_NAME(reverse) = (1UL << 1),
    NSAttributedStringEnumerationLongestEffectiveRangeNotRequired NS_SWIFT_NAME(longestEffectiveRangeNotRequired) = (1UL << 20)
} NS_SWIFT_NAME(NSAttributedString.EnumerationOptions);

@interface NSAttributedString (NSExtendedAttributedString)
@property (readonly) NSUInteger length;
- (nullable id)attribute:(NSAttributedStringKey)attrName atIndex:(NSUInteger)location effectiveRange:(nullable NSRangePointer)range;
- (NSAttributedString *)attributedSubstringFromRange:(NSRange)range;
- (NSDictionary<NSAttributedStringKey, id> *)attributesAtIndex:(NSUInteger)location longestEffectiveRange:(nullable NSRangePointer)range inRange:(NSRange)rangeLimit;
- (nullable id)attribute:(NSAttributedStringKey)attrName atIndex:(NSUInteger)location longestEffectiveRange:(nullable NSRangePointer)range inRange:(NSRange)rangeLimit;
- (BOOL)isEqualToAttributedString:(NSAttributedString *)other;
- (instancetype)initWithString:(NSString *)str;
- (instancetype)initWithString:(NSString *)str attributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs;
- (instancetype)initWithAttributedString:(NSAttributedString *)attrStr;
- (void)enumerateAttributesInRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(NSDictionary<NSAttributedStringKey, id> *attrs, NSRange range, BOOL *stop))block;
- (void)enumerateAttribute:(NSAttributedStringKey)attrName inRange:(NSRange)enumerationRange options:(NSAttributedStringEnumerationOptions)opts usingBlock:(void (NS_NOESCAPE ^)(id _Nullable value, NSRange range, BOOL *stop))block;
@end

@interface NSMutableAttributedString : NSAttributedString
- (void)replaceCharactersInRange:(NSRange)range withString:(NSString *)str;
- (void)setAttributes:(nullable NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;
@end

@interface NSMutableAttributedString (NSExtendedMutableAttributedString)
/* isim: a snapshot copy of the characters; edits to it are not reflected in the receiver. */
@property (readonly, retain) NSMutableString *mutableString;
- (void)addAttribute:(NSAttributedStringKey)name value:(id)value range:(NSRange)range;
- (void)addAttributes:(NSDictionary<NSAttributedStringKey, id> *)attrs range:(NSRange)range;
- (void)removeAttribute:(NSAttributedStringKey)name range:(NSRange)range;
- (void)replaceCharactersInRange:(NSRange)range withAttributedString:(NSAttributedString *)attrString;
- (void)insertAttributedString:(NSAttributedString *)attrString atIndex:(NSUInteger)loc;
- (void)appendAttributedString:(NSAttributedString *)attrString;
- (void)deleteCharactersInRange:(NSRange)range;
- (void)setAttributedString:(NSAttributedString *)attrString;
- (void)beginEditing;
- (void)endEditing;
@end

/* Foundation's own attribute keys (UIKit adds font, color, paragraph style, link, ...). */
FOUNDATION_EXPORT NSAttributedStringKey const NSInlinePresentationIntentAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSAlternateDescriptionAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSImageURLAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSLanguageIdentifierAttributeName;
FOUNDATION_EXPORT NSAttributedStringKey const NSPresentationIntentAttributeName;

typedef NS_OPTIONS(NSUInteger, NSInlinePresentationIntent) {
    NSInlinePresentationIntentEmphasized = 1 << 0, NSInlinePresentationIntentStronglyEmphasized = 1 << 1,
    NSInlinePresentationIntentCode = 1 << 2, NSInlinePresentationIntentStrikethrough = 1 << 5,
    NSInlinePresentationIntentSoftBreak = 1 << 6, NSInlinePresentationIntentLineBreak = 1 << 7,
    NSInlinePresentationIntentInlineHTML = 1 << 8, NSInlinePresentationIntentBlockHTML = 1 << 9
} NS_SWIFT_NAME(InlinePresentationIntent);
NS_ASSUME_NONNULL_END
