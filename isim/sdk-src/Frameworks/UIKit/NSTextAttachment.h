#pragma once
/* isim SDK: NSTextAttachment and text attachment view providers (self-authored, API-compatible names).
 * Adapted: an attachment character (U+FFFC with NSAttachmentAttributeName) takes the attachment's bounds in the line
 * (its image's size when the bounds are empty) and draws its image there; with a view provider (TextKit 2 text views)
 * its view sits at that place instead. File wrappers are not supported (isim's Foundation has no NSFileWrapper). */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKitDefines.h>
NS_ASSUME_NONNULL_BEGIN
@class UIImage, UIView, NSTextContainer, NSTextLayoutManager, NSTextAttachmentViewProvider;
@protocol NSTextLocation;

enum { NSAttachmentCharacter NS_SWIFT_NAME(NSTextAttachment.character) = 0xFFFC };

@protocol NSTextAttachmentContainer <NSObject>
- (nullable UIImage *)imageForBounds:(CGRect)imageBounds textContainer:(nullable NSTextContainer *)textContainer characterIndex:(NSUInteger)charIndex;
- (CGRect)attachmentBoundsForTextContainer:(nullable NSTextContainer *)textContainer proposedLineFragment:(CGRect)lineFrag glyphPosition:(CGPoint)position
                            characterIndex:(NSUInteger)charIndex;
@end

API_AVAILABLE(ios(15.0))
@protocol NSTextAttachmentLayout <NSObject>
- (nullable UIImage *)imageForBounds:(CGRect)bounds attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes location:(id<NSTextLocation>)location
                       textContainer:(nullable NSTextContainer *)textContainer;
- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes location:(id<NSTextLocation>)location
                          textContainer:(nullable NSTextContainer *)textContainer proposedLineFragment:(CGRect)proposedLineFragment position:(CGPoint)position;
- (nullable NSTextAttachmentViewProvider *)viewProviderForParentView:(nullable UIView *)parentView location:(id<NSTextLocation>)location
                                                       textContainer:(nullable NSTextContainer *)textContainer;
@end

@interface NSTextAttachment : NSObject <NSTextAttachmentContainer, NSTextAttachmentLayout, NSSecureCoding>
- (instancetype)initWithData:(nullable NSData *)contentData ofType:(nullable NSString *)uti NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithImage:(UIImage *)image API_AVAILABLE(ios(13.0));
+ (NSTextAttachment *)textAttachmentWithImage:(UIImage *)image NS_SWIFT_UNAVAILABLE("Use init(image:)") API_AVAILABLE(ios(13.0));
@property (nullable, copy) NSData *contents;
@property (nullable, copy) NSString *fileType;
@property (nullable, strong) UIImage *image;
@property CGRect bounds;
@property CGFloat lineLayoutPadding API_AVAILABLE(ios(15.0));
@property BOOL allowsTextAttachmentView API_AVAILABLE(ios(15.0));
@property (readonly) BOOL usesTextAttachmentView API_AVAILABLE(ios(15.0));
+ (nullable Class)textAttachmentViewProviderClassForFileType:(NSString *)fileType API_AVAILABLE(ios(15.0));
+ (void)registerTextAttachmentViewProviderClass:(Class)textAttachmentViewProviderClass forFileType:(NSString *)fileType
    NS_SWIFT_NAME(registerViewProviderClass(_:forFileType:)) API_AVAILABLE(ios(15.0));
@end

@interface NSAttributedString (NSAttributedStringAttachmentConveniences)
+ (instancetype)attributedStringWithAttachment:(NSTextAttachment *)attachment NS_SWIFT_NAME(init(attachment:));
+ (instancetype)attributedStringWithAttachment:(NSTextAttachment *)attachment attributes:(NSDictionary<NSAttributedStringKey, id> *)attributes
    NS_SWIFT_NAME(init(attachment:attributes:)) API_AVAILABLE(ios(17.0));
@end

/* the view of an attachment in a TextKit 2 text view: loadView sets view (a subclass's override, or the default
   image view) */
API_AVAILABLE(ios(15.0))
@interface NSTextAttachmentViewProvider : NSObject
- (instancetype)initWithTextAttachment:(NSTextAttachment *)textAttachment parentView:(nullable UIView *)parentView
                     textLayoutManager:(nullable NSTextLayoutManager *)textLayoutManager location:(id<NSTextLocation>)location NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nullable, readonly, weak) NSTextAttachment *textAttachment;
@property (nullable, readonly, weak) NSTextLayoutManager *textLayoutManager;
@property (readonly, strong) id<NSTextLocation> location;
@property (nullable, strong) UIView *view;
- (void)loadView;
@property BOOL tracksTextAttachmentViewBounds;
- (CGRect)attachmentBoundsForAttributes:(NSDictionary<NSAttributedStringKey, id> *)attributes location:(id<NSTextLocation>)location
                          textContainer:(nullable NSTextContainer *)textContainer proposedLineFragment:(CGRect)proposedLineFragment position:(CGPoint)position;
@end
NS_ASSUME_NONNULL_END
