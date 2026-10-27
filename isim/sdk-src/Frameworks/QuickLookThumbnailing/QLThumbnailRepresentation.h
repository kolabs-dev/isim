#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, QLThumbnailRepresentationType) {
    QLThumbnailRepresentationTypeIcon = 0,
    QLThumbnailRepresentationTypeLowQualityThumbnail = 1,
    QLThumbnailRepresentationTypeThumbnail = 2,
} NS_SWIFT_NAME(QLThumbnailRepresentation.RepresentationType) API_AVAILABLE(ios(13.0));

/* a thumbnail or an icon: its image and where the file's content is in it */
API_AVAILABLE(ios(13.0))
@interface QLThumbnailRepresentation : NSObject
@property (readonly) QLThumbnailRepresentationType type;
@property (readonly) CGImageRef CGImage;
@property (strong, readonly) UIImage *UIImage;
@property (readonly) CGRect contentRect API_AVAILABLE(ios(15.0));
@end

NS_ASSUME_NONNULL_END
