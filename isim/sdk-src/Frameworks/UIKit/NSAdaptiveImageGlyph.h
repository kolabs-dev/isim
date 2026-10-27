#pragma once
/* isim: adaptive image glyphs (Genmoji, iOS 18): an emoji-like image in attributed text (NSAdaptiveImageGlyphAttributeName
   on an attachment character). isim keeps the image content and its identifier; it has no Genmoji to create them,
   and text does not draw them yet (NSTextList.m). */
#import <Foundation/Foundation.h>
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UTType;
UIKIT_EXTERN NSAttributedStringKey const NSAdaptiveImageGlyphAttributeName API_AVAILABLE(ios(18.0));

API_AVAILABLE(ios(18.0)) NS_SWIFT_SENDABLE
@interface NSAdaptiveImageGlyph : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithImageContent:(NSData *)imageContent NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (readonly, copy) NSData *imageContent;
/* identifies the image (the same content, the same identifier) */
@property (readonly, copy) NSString *contentIdentifier;
/* the image's description (alt text) */
@property (readonly, copy) NSString *contentDescription;
/* the content's type: public.heic */
@property (class, readonly, copy) UTType *contentType;
@end
NS_ASSUME_NONNULL_END
