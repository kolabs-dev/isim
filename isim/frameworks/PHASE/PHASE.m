// isim PHASE for Objective-C: the C constants, and the members with simd values (the classes are the PHASE Swift
// overlay's, which passes simd values to Objective-C as arrays of numbers).
#import <PHASE/PHASE.h>

#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   /* the class is Swift's: these members are only here */

NSErrorDomain const PHASEErrorDomain = @"PHASEErrorDomain";
NSErrorDomain const PHASESoundEventErrorDomain = @"PHASESoundEventErrorDomain";
NSErrorDomain const PHASEAssetErrorDomain = @"PHASEAssetErrorDomain";
PHASESpatialCategory const PHASESpatialCategoryDirectPathTransmission = @"PHASESpatialCategoryDirectPathTransmission";
PHASESpatialCategory const PHASESpatialCategoryEarlyReflections = @"PHASESpatialCategoryEarlyReflections";
PHASESpatialCategory const PHASESpatialCategoryLateReverb = @"PHASESpatialCategoryLateReverb";

static NSArray<NSNumber *> *m4(simd_float4x4 m) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:16];
    for (int c = 0; c < 4; c++) for (int r = 0; r < 4; r++) [a addObject:@(m.columns[c][r])];
    return a;
}
static simd_float4x4 tom4(NSArray<NSNumber *> *a) {
    simd_float4x4 m = {{{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}};
    if (a.count == 16) for (int c = 0; c < 4; c++) for (int r = 0; r < 4; r++) m.columns[c][r] = a[c * 4 + r].floatValue;
    return m;
}

@interface PHASEObject (ISIMSwift)
- (NSArray<NSNumber *> *)_isim_transform;
- (void)set_isim_transform:(NSArray<NSNumber *> *)m;
- (NSArray<NSNumber *> *)_isim_worldTransform;
- (void)set_isim_worldTransform:(NSArray<NSNumber *> *)m;
@end
@implementation PHASEObject (ISIMSimd)
+ (simd_float3)right { return (simd_float3){1, 0, 0}; }
+ (simd_float3)up { return (simd_float3){0, 1, 0}; }
+ (simd_float3)forward { return (simd_float3){0, 0, -1}; }
- (simd_float4x4)transform { return tom4([self _isim_transform]); }
- (void)setTransform:(simd_float4x4)transform { [self set_isim_transform:m4(transform)]; }
- (simd_float4x4)worldTransform { return tom4([self _isim_worldTransform]); }
- (void)setWorldTransform:(simd_float4x4)worldTransform { [self set_isim_worldTransform:m4(worldTransform)]; }
@end

@interface PHASEEnvelopeSegment (ISIMSwift)
+ (PHASEEnvelopeSegment *)_isim_segmentWithEndX:(double)x y:(double)y curveType:(PHASECurveType)curveType;
- (NSArray<NSNumber *> *)_isim_endPoint;
- (void)set_isim_endPoint:(NSArray<NSNumber *> *)p;
@end
@implementation PHASEEnvelopeSegment (ISIMSimd)
- (instancetype)initWithEndPoint:(simd_double2)endPoint curveType:(PHASECurveType)curveType { return [PHASEEnvelopeSegment _isim_segmentWithEndX:endPoint.x y:endPoint.y curveType:curveType]; }
- (simd_double2)endPoint { NSArray<NSNumber *> *p = [self _isim_endPoint]; return (simd_double2){p[0].doubleValue, p[1].doubleValue}; }
- (void)setEndPoint:(simd_double2)endPoint { [self set_isim_endPoint:@[ @(endPoint.x), @(endPoint.y) ]]; }
@end

@interface PHASEEnvelope (ISIMSwift)
+ (nullable PHASEEnvelope *)_isim_envelopeWithStartX:(double)x y:(double)y segments:(NSArray<PHASEEnvelopeSegment *> *)segments;
- (NSArray<NSNumber *> *)_isim_startPoint;
@end
@implementation PHASEEnvelope (ISIMSimd)
- (nullable instancetype)initWithStartPoint:(simd_double2)startPoint segments:(NSArray<PHASEEnvelopeSegment *> *)segments {
    return [PHASEEnvelope _isim_envelopeWithStartX:startPoint.x y:startPoint.y segments:segments];
}
- (simd_double2)startPoint { NSArray<NSNumber *> *p = [self _isim_startPoint]; return (simd_double2){p[0].doubleValue, p[1].doubleValue}; }
@end

@interface PHASEAmbientMixerDefinition (ISIMSwift)
+ (PHASEAmbientMixerDefinition *)_isim_definitionWithChannelLayout:(AVAudioChannelLayout *)layout orientation:(NSArray<NSNumber *> *)q identifier:(nullable NSString *)identifier;
- (NSArray<NSNumber *> *)_isim_orientation;
@end
@implementation PHASEAmbientMixerDefinition (ISIMSimd)
static NSArray<NSNumber *> *quat(simd_quatf q) { return @[ @(q.vector.x), @(q.vector.y), @(q.vector.z), @(q.vector.w) ]; }
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout orientation:(simd_quatf)orientation {
    return [PHASEAmbientMixerDefinition _isim_definitionWithChannelLayout:layout orientation:quat(orientation) identifier:nil];
}
- (instancetype)initWithChannelLayout:(AVAudioChannelLayout *)layout orientation:(simd_quatf)orientation identifier:(NSString *)identifier {
    return [PHASEAmbientMixerDefinition _isim_definitionWithChannelLayout:layout orientation:quat(orientation) identifier:identifier];
}
- (simd_quatf)orientation { NSArray<NSNumber *> *q = [self _isim_orientation]; simd_quatf r = { { q[0].floatValue, q[1].floatValue, q[2].floatValue, q[3].floatValue } }; return r; }
@end
