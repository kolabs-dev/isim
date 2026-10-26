#pragma once
/* isim QuartzCore: CAMetalDisplayLink (iOS 17, issue #329): a display link that hands out a CAMetalLayer's drawables at
 * the display's rate. The class is the Metal Swift overlay's (Metal/CAMetalLayer.swift). */
#if !defined(__swift__)
#import <QuartzCore/CAMetalLayer.h>
#import <QuartzCore/CAFrameRateRange.h>
NS_ASSUME_NONNULL_BEGIN
@class CAMetalDisplayLink;
API_AVAILABLE(ios(17.0))
@interface CAMetalDisplayLinkUpdate : NSObject
@property (readonly, nonatomic) id<CAMetalDrawable> drawable;
@property (readonly, nonatomic) CFTimeInterval targetTimestamp;
@property (readonly, nonatomic) CFTimeInterval targetPresentationTimestamp;
@end
API_AVAILABLE(ios(17.0))
@protocol CAMetalDisplayLinkDelegate
- (void)metalDisplayLink:(CAMetalDisplayLink *)link needsUpdate:(CAMetalDisplayLinkUpdate *)update;
@end
API_AVAILABLE(ios(17.0))
@interface CAMetalDisplayLink : NSObject
- (instancetype)initWithMetalLayer:(CAMetalLayer *)layer;
- (void)addToRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
- (void)removeFromRunLoop:(NSRunLoop *)runloop forMode:(NSRunLoopMode)mode;
- (void)invalidate;
@property (nullable, nonatomic, weak) id<CAMetalDisplayLinkDelegate> delegate;
@property (nonatomic) float preferredFrameLatency;
@property (nonatomic) CAFrameRateRange preferredFrameRateRange;
@property (nonatomic, getter=isPaused) BOOL paused;
@end
NS_ASSUME_NONNULL_END
#endif
