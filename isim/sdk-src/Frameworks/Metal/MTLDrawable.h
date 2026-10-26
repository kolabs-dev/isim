#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
/* a drawable of CAMetalLayer (QuartzCore): presenting it shows its texture in the layer (issue #329) */
@protocol MTLDrawable;
typedef void (^MTLDrawablePresentedHandler)(id<MTLDrawable>);
@protocol MTLDrawable <NSObject>
- (void)present;
- (void)presentAtTime:(CFTimeInterval)presentationTime NS_SWIFT_NAME(present(at:));
- (void)presentAfterMinimumDuration:(CFTimeInterval)duration NS_SWIFT_NAME(present(afterMinimumDuration:));
- (void)addPresentedHandler:(MTLDrawablePresentedHandler)block;
@property (readonly) CFTimeInterval presentedTime;
@property (readonly) NSUInteger drawableID;
@end
NS_ASSUME_NONNULL_END
