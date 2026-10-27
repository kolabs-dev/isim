#pragma once
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
NS_ASSUME_NONNULL_BEGIN
/* a point of a stroke path: where, when (seconds from the path's creation), how large, opaque and hard the nib was */
NS_SWIFT_NAME(PKStrokePointReference) __attribute__((swift_bridge("PKStrokePoint"))) API_AVAILABLE(ios(14.0))
@interface PKStrokePoint : NSObject <NSCopying>
- (instancetype)initWithLocation:(CGPoint)location timeOffset:(NSTimeInterval)timeOffset size:(CGSize)size opacity:(CGFloat)opacity
                           force:(CGFloat)force azimuth:(CGFloat)azimuth altitude:(CGFloat)altitude;
- (instancetype)initWithLocation:(CGPoint)location timeOffset:(NSTimeInterval)timeOffset size:(CGSize)size opacity:(CGFloat)opacity
                           force:(CGFloat)force azimuth:(CGFloat)azimuth altitude:(CGFloat)altitude secondaryScale:(CGFloat)secondaryScale
    API_AVAILABLE(ios(17.0));
- (instancetype)initWithLocation:(CGPoint)location timeOffset:(NSTimeInterval)timeOffset size:(CGSize)size opacity:(CGFloat)opacity
                           force:(CGFloat)force azimuth:(CGFloat)azimuth altitude:(CGFloat)altitude secondaryScale:(CGFloat)secondaryScale
                       threshold:(CGFloat)threshold API_AVAILABLE(ios(18.0));
- (instancetype)initWithLocation:(CGPoint)location timeOffset:(NSTimeInterval)timeOffset size:(CGSize)size opacity:(CGFloat)opacity
                           force:(CGFloat)force azimuth:(CGFloat)azimuth altitude:(CGFloat)altitude secondaryScale:(CGFloat)secondaryScale
                       threshold:(CGFloat)threshold lateralJitter:(CGFloat)lateralJitter NS_DESIGNATED_INITIALIZER API_AVAILABLE(ios(26.0));
- (instancetype)init NS_UNAVAILABLE;
@property (nonatomic, readonly) CGPoint location;
@property (nonatomic, readonly) NSTimeInterval timeOffset;
@property (nonatomic, readonly) CGSize size;
@property (nonatomic, readonly) CGFloat opacity;
@property (nonatomic, readonly) CGFloat force;
@property (nonatomic, readonly) CGFloat azimuth;
@property (nonatomic, readonly) CGFloat altitude;
@property (nonatomic, readonly) CGFloat secondaryScale API_AVAILABLE(ios(17.0));
@property (nonatomic, readonly) CGFloat threshold API_AVAILABLE(ios(18.0));
@property (nonatomic, readonly) CGFloat lateralJitter API_AVAILABLE(ios(26.0));
@end
NS_ASSUME_NONNULL_END
