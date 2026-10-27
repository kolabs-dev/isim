#pragma once
#import <PencilKit/PKTool.h>
NS_ASSUME_NONNULL_BEGIN
/* a tool that selects strokes inside the loop drawn with it */
NS_SWIFT_NAME(PKLassoToolReference) __attribute__((swift_bridge("PKLassoTool"))) API_AVAILABLE(ios(13.0))
@interface PKLassoTool : PKTool
- (instancetype)init NS_DESIGNATED_INITIALIZER;
@end
NS_ASSUME_NONNULL_END
