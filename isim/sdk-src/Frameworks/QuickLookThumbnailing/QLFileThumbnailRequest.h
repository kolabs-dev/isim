#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN

/* what a Thumbnail extension is asked for */
API_AVAILABLE(ios(13.0))
@interface QLFileThumbnailRequest : NSObject
@property (nonatomic, readonly) CGSize maximumSize;
@property (nonatomic, readonly) CGSize minimumSize;
@property (nonatomic, readonly) CGFloat scale;
@property (nonatomic, copy, readonly) NSURL *fileURL;
@end

NS_ASSUME_NONNULL_END
