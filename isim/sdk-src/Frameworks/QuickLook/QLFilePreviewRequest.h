#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* what a data-based preview extension is asked to preview */
API_AVAILABLE(ios(15.0))
@interface QLFilePreviewRequest : NSObject
@property (readonly) NSURL *fileURL;
@end
NS_ASSUME_NONNULL_END
