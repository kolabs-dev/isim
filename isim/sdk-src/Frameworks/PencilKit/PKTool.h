#pragma once
#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/* the base of the tools a canvas draws, erases or selects with (Swift: the PKTool protocol) */
NS_REFINED_FOR_SWIFT API_AVAILABLE(ios(13.0))
@interface PKTool : NSObject <NSCopying>
- (instancetype)init NS_UNAVAILABLE;
@end
NS_ASSUME_NONNULL_END
