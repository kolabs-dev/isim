#pragma once
/* isim: text lists (NSParagraphStyle.textLists): a list's marker format ("{decimal}.", "{disc}") and the marker of each
   item. TextKit 2 gives a list paragraph an NSTextListElement (NSTextLayoutManager.h) whose string starts with its
   marker. NSTextList.m. */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN

/* a marker format: one of these placeholders, optionally inside other text ("({lower-roman})") */
typedef NSString *NSTextListMarkerFormat NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(NSTextList.MarkerFormat);
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerBox NS_SWIFT_NAME(box) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerCheck NS_SWIFT_NAME(check) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerCircle NS_SWIFT_NAME(circle) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerDiamond NS_SWIFT_NAME(diamond) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerDisc NS_SWIFT_NAME(disc) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerHyphen NS_SWIFT_NAME(hyphen) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerSquare NS_SWIFT_NAME(square) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerLowercaseHexadecimal NS_SWIFT_NAME(lowercaseHexadecimal) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerUppercaseHexadecimal NS_SWIFT_NAME(uppercaseHexadecimal) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerOctal NS_SWIFT_NAME(octal) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerLowercaseAlpha NS_SWIFT_NAME(lowercaseAlpha) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerUppercaseAlpha NS_SWIFT_NAME(uppercaseAlpha) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerLowercaseLatin NS_SWIFT_NAME(lowercaseLatin) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerUppercaseLatin NS_SWIFT_NAME(uppercaseLatin) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerLowercaseRoman NS_SWIFT_NAME(lowercaseRoman) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerUppercaseRoman NS_SWIFT_NAME(uppercaseRoman) API_AVAILABLE(ios(7.0));
UIKIT_EXTERN NSTextListMarkerFormat const NSTextListMarkerDecimal NS_SWIFT_NAME(decimal) API_AVAILABLE(ios(7.0));

typedef NS_OPTIONS(NSUInteger, NSTextListOptions) {
    NSTextListPrependEnclosingMarker = (1 << 0),     /* a nested list's markers start with its parent's ("1.2") */
} NS_SWIFT_NAME(NSTextList.Options) API_AVAILABLE(ios(16.0));

API_AVAILABLE(ios(7.0))
@interface NSTextList : NSObject <NSSecureCoding, NSCopying>
- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)markerFormat options:(NSTextListOptions)options
                  startingItemNumber:(NSInteger)startingItemNumber NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(16.0));
- (instancetype)initWithMarkerFormat:(NSTextListMarkerFormat)markerFormat options:(NSUInteger)options;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
@property (readonly, copy) NSTextListMarkerFormat markerFormat;
@property (readonly) NSTextListOptions listOptions;
@property NSInteger startingItemNumber;
/* numbered (not a bullet) */
@property (readonly, getter=isOrdered) BOOL ordered API_AVAILABLE(ios(16.0));
- (NSString *)markerForItemNumber:(NSInteger)itemNumber NS_SWIFT_NAME(marker(forItemNumber:));
@end
NS_ASSUME_NONNULL_END
