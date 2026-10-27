#pragma once
#import <PencilKit/PKInk.h>
#import <PencilKit/PKStrokePath.h>
NS_ASSUME_NONNULL_BEGIN
/* how a stroke's ink was laid down (the grain of textured inks) */
NS_SWIFT_NAME(PKStrokeRenderStateReference) __attribute__((swift_bridge("PKStroke.RenderState"))) API_AVAILABLE(ios(26.0))
@interface PKStrokeRenderState : NSObject <NSCopying, NSSecureCoding>
- (instancetype)initWithGrainOffset:(CGPoint)grainOffset NS_DESIGNATED_INITIALIZER;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) CGPoint grainOffset;
@property (nonatomic, readonly) PKContentVersion requiredContentVersion;
@end

/* a stroke: an ink along a path, transformed and optionally masked */
NS_SWIFT_NAME(PKStrokeReference) __attribute__((swift_bridge("PKStroke"))) API_AVAILABLE(ios(14.0))
@interface PKStroke : NSObject <NSCopying>
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)strokePath transform:(CGAffineTransform)transform mask:(nullable UIBezierPath *)mask;
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)strokePath transform:(CGAffineTransform)transform mask:(nullable UIBezierPath *)mask
                 randomSeed:(uint32_t)randomSeed API_AVAILABLE(ios(16.0));
- (instancetype)initWithInk:(PKInk *)ink strokePath:(PKStrokePath *)strokePath transform:(CGAffineTransform)transform mask:(nullable UIBezierPath *)mask
                 randomSeed:(uint32_t)randomSeed strokeID:(NSUUID *)strokeID renderGroupID:(nullable NSUUID *)renderGroupID
                renderState:(nullable PKStrokeRenderState *)renderState NS_DESIGNATED_INITIALIZER
    NS_SWIFT_NAME(init(ink:strokePath:transform:mask:randomSeed:strokeID:renderGroupID:renderState:)) API_AVAILABLE(ios(26.0));
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) PKInk *ink;
@property (nonatomic, readonly) CGAffineTransform transform;
@property (nonatomic, readonly) PKStrokePath *path;
@property (nonatomic, readonly, nullable) UIBezierPath *mask;
/* the bounds of the stroke as drawn (its width included), in drawing coordinates */
@property (nonatomic, readonly) CGRect renderBounds;
/* the parametric ranges of the path that the mask leaves visible */
@property (nonatomic, readonly) NSArray<PKFloatRange *> *maskedPathRanges;
@property (nonatomic, readonly) uint32_t randomSeed API_AVAILABLE(ios(16.0));
@property (nonatomic, readonly) PKContentVersion requiredContentVersion API_AVAILABLE(ios(17.0));
@property (nonatomic, readonly) NSUUID *strokeID API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, nullable) NSUUID *renderGroupID API_AVAILABLE(ios(26.0));
@property (nonatomic, readonly, nullable) PKStrokeRenderState *renderState API_AVAILABLE(ios(26.0));
- (PKStroke *)substrokeWithRange:(PKFloatRange *)range NS_SWIFT_NAME(substroke(with:)) API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
