// isim ARKit for Objective-C: ARErrorDomain, and the categories for what the overlay's classes cannot declare: the simd
// values (through the overlay's `_isim_` NSArray entry points, ObjC.swift; matrices column by column), the view
// delegates (held through the overlay's boxes) and Apple's setters where the overlay's Bool properties are named isX
// (Swift's Objective-C setter is setIsX:).
#import <ARKit/ARKit.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes
#pragma clang diagnostic ignored "-Wobjc-designated-initializers"

NSString * const ARErrorDomain = @"com.apple.arkit.error";

static NSArray<NSNumber *> *f3(simd_float3 v) { return @[@(v.x), @(v.y), @(v.z)]; }
static simd_float3 tof3(NSArray<NSNumber *> *a) {
    simd_float3 v = {0, 0, 0};
    if (a.count >= 3) { v.x = a[0].floatValue; v.y = a[1].floatValue; v.z = a[2].floatValue; }
    return v;
}
static NSArray<NSNumber *> *m4(simd_float4x4 m) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:16];
    for (int c = 0; c < 4; c++) for (int r = 0; r < 4; r++) [a addObject:@(m.columns[c][r])];
    return a;
}
static simd_float4x4 tom4(NSArray<NSNumber *> *a) {
    simd_float4x4 m = matrix_identity_float4x4;
    if (a.count >= 16) for (int c = 0; c < 4; c++) for (int r = 0; r < 4; r++) m.columns[c][r] = a[c * 4 + r].floatValue;
    return m;
}
static simd_float3x3 tom3(NSArray<NSNumber *> *a) {
    simd_float3x3 m;
    for (int c = 0; c < 3; c++) for (int r = 0; r < 3; r++) m.columns[c][r] = a.count >= 9 ? a[c * 3 + r].floatValue : (c == r);
    return m;
}

@interface NSObject (ISIMARKit)
+ (id)_isim_anchorWithName:(NSString *)name transform:(NSArray *)m;
+ (id)_isim_probeWithName:(NSString *)name transform:(NSArray *)m extent:(NSArray *)e;
+ (id)_isim_queryWithOrigin:(NSArray *)o direction:(NSArray *)d allowingTarget:(NSInteger)t alignment:(NSInteger)a;
- (NSArray<NSNumber *> *)_isim_transform;
- (NSArray<NSNumber *> *)_isim_worldTransform;
- (NSArray<NSNumber *> *)_isim_eulerAngles;
- (NSArray<NSNumber *> *)_isim_intrinsics;
- (NSArray<NSNumber *> *)_isim_projectionMatrix;
- (NSArray<NSNumber *> *)_isim_projectionMatrixForOrientation:(UIInterfaceOrientation)o viewportSize:(CGSize)s zNear:(CGFloat)n zFar:(CGFloat)f;
- (NSArray<NSNumber *> *)_isim_viewMatrixForOrientation:(UIInterfaceOrientation)o;
- (CGPoint)_isim_projectPoint:(NSArray *)p orientation:(UIInterfaceOrientation)o viewportSize:(CGSize)s;
- (NSArray<NSNumber *> *)_isim_center;
- (NSArray<NSNumber *> *)_isim_extent;
- (NSArray<NSNumber *> *)_isim_scale;
- (NSArray<NSNumber *> *)_isim_origin;
- (NSArray<NSNumber *> *)_isim_direction;
- (NSArray<NSNumber *> *)_isim_leftEyeTransform;
- (NSArray<NSNumber *> *)_isim_rightEyeTransform;
- (NSArray<NSNumber *> *)_isim_lookAtPoint;
- (id)_isim_referenceObjectByApplyingTransform:(NSArray *)m;
- (void)_isim_setWorldOrigin:(NSArray *)m;
- (void)_isim_createReferenceObjectWithTransform:(NSArray *)m center:(NSArray *)c extent:(NSArray *)e completionHandler:(id)h;
- (void)_isim_setARDelegate:(id)d;
- (id)_isim_ARDelegate;
- (void)setIsLightEstimationEnabled:(BOOL)v;
- (void)setIsAutoFocusEnabled:(BOOL)v;
- (void)setIsCollaborationEnabled:(BOOL)v;
- (void)setIsWorldTrackingEnabled:(BOOL)v;
@end

@implementation ARAnchor (ISIMSimd)
/* the overlay's factories make the anchor (an Objective-C initializer may return another object) */
- (instancetype)initWithTransform:(simd_float4x4)transform { return [ARAnchor _isim_anchorWithName:nil transform:m4(transform)]; }
- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform { return [ARAnchor _isim_anchorWithName:name transform:m4(transform)]; }
- (simd_float4x4)transform { return tom4([self _isim_transform]); }
@end
@implementation AREnvironmentProbeAnchor (ISIMSimd)
- (instancetype)initWithTransform:(simd_float4x4)transform extent:(simd_float3)extent {
    return [AREnvironmentProbeAnchor _isim_probeWithName:nil transform:m4(transform) extent:f3(extent)];
}
- (instancetype)initWithName:(NSString *)name transform:(simd_float4x4)transform extent:(simd_float3)extent {
    return [AREnvironmentProbeAnchor _isim_probeWithName:name transform:m4(transform) extent:f3(extent)];
}
- (simd_float3)extent { return tof3([self _isim_extent]); }
@end
@implementation ARPlaneAnchor (ISIMSimd)
- (simd_float3)center { return tof3([self _isim_center]); }
@end
@implementation ARFaceAnchor (ISIMSimd)
- (simd_float4x4)leftEyeTransform { return tom4([self _isim_leftEyeTransform]); }
- (simd_float4x4)rightEyeTransform { return tom4([self _isim_rightEyeTransform]); }
- (simd_float3)lookAtPoint { return tof3([self _isim_lookAtPoint]); }
@end
@implementation ARReferenceObject (ISIMSimd)
- (simd_float3)center { return tof3([self _isim_center]); }
- (simd_float3)extent { return tof3([self _isim_extent]); }
- (simd_float3)scale { return tof3([self _isim_scale]); }
- (ARReferenceObject *)referenceObjectByApplyingTransform:(simd_float4x4)transform { return [self _isim_referenceObjectByApplyingTransform:m4(transform)]; }
@end
@implementation ARWorldMap (ISIMSimd)
- (simd_float3)center { return tof3([self _isim_center]); }
- (simd_float3)extent { return tof3([self _isim_extent]); }
@end
@implementation ARCamera (ISIMSimd)
- (simd_float4x4)transform { return tom4([self _isim_transform]); }
- (simd_float3)eulerAngles { return tof3([self _isim_eulerAngles]); }
- (simd_float3x3)intrinsics { return tom3([self _isim_intrinsics]); }
- (simd_float4x4)projectionMatrix { return tom4([self _isim_projectionMatrix]); }
- (simd_float4x4)projectionMatrixForOrientation:(UIInterfaceOrientation)o viewportSize:(CGSize)s zNear:(CGFloat)n zFar:(CGFloat)f {
    return tom4([self _isim_projectionMatrixForOrientation:o viewportSize:s zNear:n zFar:f]);
}
- (simd_float4x4)viewMatrixForOrientation:(UIInterfaceOrientation)o { return tom4([self _isim_viewMatrixForOrientation:o]); }
- (CGPoint)projectPoint:(simd_float3)p orientation:(UIInterfaceOrientation)o viewportSize:(CGSize)s {
    return [self _isim_projectPoint:f3(p) orientation:o viewportSize:s];
}
@end
@implementation ARRaycastQuery (ISIMSimd)
- (instancetype)initWithOrigin:(simd_float3)origin direction:(simd_float3)direction allowingTarget:(ARRaycastTarget)target alignment:(ARRaycastTargetAlignment)alignment {
    return [ARRaycastQuery _isim_queryWithOrigin:f3(origin) direction:f3(direction) allowingTarget:target alignment:alignment];
}
- (simd_float3)origin { return tof3([self _isim_origin]); }
- (simd_float3)direction { return tof3([self _isim_direction]); }
@end
@implementation ARRaycastResult (ISIMSimd)
- (simd_float4x4)worldTransform { return tom4([self _isim_worldTransform]); }
@end
@implementation ARSession (ISIMSimd)
- (void)setWorldOrigin:(simd_float4x4)relativeTransform { [self _isim_setWorldOrigin:m4(relativeTransform)]; }
- (void)createReferenceObjectWithTransform:(simd_float4x4)transform center:(simd_float3)center extent:(simd_float3)extent
                         completionHandler:(void (^)(ARReferenceObject *, NSError *))completionHandler {
    [self _isim_createReferenceObjectWithTransform:m4(transform) center:f3(center) extent:f3(extent) completionHandler:completionHandler];
}
@end

@implementation ARSCNView (ISIMDelegate)
- (id<ARSCNViewDelegate>)delegate { return [self _isim_ARDelegate]; }
- (void)setDelegate:(id<ARSCNViewDelegate>)delegate { [self _isim_setARDelegate:delegate]; }
@end
@implementation ARSKView (ISIMDelegate)
- (id<ARSKViewDelegate>)delegate { return [self _isim_ARDelegate]; }
- (void)setDelegate:(id<ARSKViewDelegate>)delegate { [self _isim_setARDelegate:delegate]; }
@end

@implementation ARConfiguration (ISIMSetters)
- (void)setLightEstimationEnabled:(BOOL)v { [self setIsLightEstimationEnabled:v]; }
@end
#define ISIM_AUTOFOCUS(C) @implementation C (ISIMAutoFocus) - (void)setAutoFocusEnabled:(BOOL)v { [self setIsAutoFocusEnabled:v]; } @end
ISIM_AUTOFOCUS(ARWorldTrackingConfiguration)
ISIM_AUTOFOCUS(AROrientationTrackingConfiguration)
ISIM_AUTOFOCUS(ARImageTrackingConfiguration)
ISIM_AUTOFOCUS(ARObjectScanningConfiguration)
ISIM_AUTOFOCUS(ARBodyTrackingConfiguration)
@implementation ARWorldTrackingConfiguration (ISIMSetters)
- (void)setCollaborationEnabled:(BOOL)v { [self setIsCollaborationEnabled:v]; }
@end
@implementation ARFaceTrackingConfiguration (ISIMSetters)
- (void)setWorldTrackingEnabled:(BOOL)v { [self setIsWorldTrackingEnabled:v]; }
@end
