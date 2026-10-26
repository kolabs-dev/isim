#pragma once
#import <Metal/MTLDefines.h>
NS_ASSUME_NONNULL_BEGIN
/* declared for MTLCommandBuffer; drawables come with render pipelines (issue #329) */
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
