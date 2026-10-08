#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@protocol QLPreviewItem <NSObject>
@property (readonly, nullable, nonatomic) NSURL *previewItemURL;
@optional
@property (readonly, nullable, nonatomic) NSString *previewItemTitle;
@end
/* file URLs are preview items, as on iOS */
@interface NSURL (QLPreviewConvenienceAdditions) <QLPreviewItem>
@end
NS_ASSUME_NONNULL_END
