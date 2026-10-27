#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <QuickLookThumbnailing/QLThumbnailGenerator.h>
#if !defined(__swift__)
#import <UniformTypeIdentifiers/UTType.h>
#endif
NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSUInteger, QLThumbnailGenerationRequestRepresentationTypes) {
    QLThumbnailGenerationRequestRepresentationTypeIcon = 1 << 0,
    QLThumbnailGenerationRequestRepresentationTypeLowQualityThumbnail = 1 << 1,
    QLThumbnailGenerationRequestRepresentationTypeThumbnail = 1 << 2,
    QLThumbnailGenerationRequestRepresentationTypeAll = NSUIntegerMax
} NS_SWIFT_NAME(QLThumbnailGenerationRequest.RepresentationTypes) API_AVAILABLE(ios(13.0));

/* what to make a thumbnail of, at what size (points) and scale, and which kinds. The content type is Objective-C
 * only here; Swift gets the UTType property from isim's QuickLookThumbnailing overlay. */
API_AVAILABLE(ios(13.0)) NS_SWIFT_NAME(QLThumbnailGenerator.Request)
@interface QLThumbnailGenerationRequest : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithFileAtURL:(NSURL *)url size:(CGSize)size scale:(CGFloat)scale
              representationTypes:(QLThumbnailGenerationRequestRepresentationTypes)representationTypes NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;
@property (nonatomic, assign) CGFloat minimumDimension;
@property (nonatomic, assign) BOOL iconMode;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, readonly) QLThumbnailGenerationRequestRepresentationTypes representationTypes;
#if !defined(__swift__)
@property (nonatomic, copy, null_resettable) UTType *contentType API_AVAILABLE(ios(16.0));
#endif
/* isim: what the overlay's contentType uses (nil: from the file) */
@property (nonatomic, copy, nullable) NSString *_isimContentTypeIdentifier NS_SWIFT_NAME(_isimContentTypeIdentifier);
@property (nonatomic, readonly) NSURL *_isimURL NS_SWIFT_NAME(_isimFileURL);
@end

NS_ASSUME_NONNULL_END
