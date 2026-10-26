// isim SceneKit for Objective-C: SceneKit's vector and matrix functions in C (the Swift overlay's are Swift functions),
// NSValue's SceneKit additions, and the categories for what the overlay's classes cannot declare: the struct properties
// (through the overlay's `_isim_` NSArray entry points, ObjC.swift), Apple's setters where the overlay's Bool properties
// are named isX (Swift's Objective-C setter is setIsX:), and the class factories.
#import <SceneKit/SceneKit.h>
#include <math.h>
#pragma clang diagnostic ignored "-Wobjc-protocol-method-implementation"   // the categories implement what the header declares on the classes

const SCNVector3 SCNVector3Zero = {0, 0, 0};
const SCNVector4 SCNVector4Zero = {0, 0, 0, 0};
const SCNMatrix4 SCNMatrix4Identity = {1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1};

BOOL SCNVector3EqualToVector3(SCNVector3 a, SCNVector3 b) { return a.x == b.x && a.y == b.y && a.z == b.z; }
BOOL SCNVector4EqualToVector4(SCNVector4 a, SCNVector4 b) { return a.x == b.x && a.y == b.y && a.z == b.z && a.w == b.w; }
BOOL SCNMatrix4EqualToMatrix4(SCNMatrix4 a, SCNMatrix4 b) { return memcmp(&a, &b, sizeof a) == 0; }
BOOL SCNMatrix4IsIdentity(SCNMatrix4 m) { return SCNMatrix4EqualToMatrix4(m, SCNMatrix4Identity); }

/* row-vector convention, as SceneKit: a then b */
SCNMatrix4 SCNMatrix4Mult(SCNMatrix4 a, SCNMatrix4 b) {
    const float *x = &a.m11, *y = &b.m11;
    SCNMatrix4 r;
    float *o = &r.m11;
    for (int i = 0; i < 4; i++)
        for (int j = 0; j < 4; j++) {
            float s = 0;
            for (int k = 0; k < 4; k++) s += x[i * 4 + k] * y[k * 4 + j];
            o[i * 4 + j] = s;
        }
    return r;
}

/* the rotation by `angle` radians about the axis (x, y, z), as the overlay's (a quaternion's matrix) */
SCNMatrix4 SCNMatrix4MakeRotation(float angle, float x, float y, float z) {
    float len = sqrtf(x * x + y * y + z * z);
    if (len == 0) return SCNMatrix4Identity;
    x /= len; y /= len; z /= len;
    float c = cosf(angle), s = sinf(angle), t = 1 - c;
    SCNMatrix4 m = SCNMatrix4Identity;
    m.m11 = t * x * x + c;     m.m12 = t * x * y + s * z; m.m13 = t * x * z - s * y;
    m.m21 = t * x * y - s * z; m.m22 = t * y * y + c;     m.m23 = t * y * z + s * x;
    m.m31 = t * x * z + s * y; m.m32 = t * y * z - s * x; m.m33 = t * z * z + c;
    return m;
}
SCNMatrix4 SCNMatrix4Rotate(SCNMatrix4 m, float angle, float x, float y, float z) { return SCNMatrix4Mult(SCNMatrix4MakeRotation(angle, x, y, z), m); }

SCNMatrix4 SCNMatrix4Invert(SCNMatrix4 m) {
    const float *a = &m.m11;
    float inv[16];
    inv[0] = a[5]*a[10]*a[15] - a[5]*a[11]*a[14] - a[9]*a[6]*a[15] + a[9]*a[7]*a[14] + a[13]*a[6]*a[11] - a[13]*a[7]*a[10];
    inv[4] = -a[4]*a[10]*a[15] + a[4]*a[11]*a[14] + a[8]*a[6]*a[15] - a[8]*a[7]*a[14] - a[12]*a[6]*a[11] + a[12]*a[7]*a[10];
    inv[8] = a[4]*a[9]*a[15] - a[4]*a[11]*a[13] - a[8]*a[5]*a[15] + a[8]*a[7]*a[13] + a[12]*a[5]*a[11] - a[12]*a[7]*a[9];
    inv[12] = -a[4]*a[9]*a[14] + a[4]*a[10]*a[13] + a[8]*a[5]*a[14] - a[8]*a[6]*a[13] - a[12]*a[5]*a[10] + a[12]*a[6]*a[9];
    inv[1] = -a[1]*a[10]*a[15] + a[1]*a[11]*a[14] + a[9]*a[2]*a[15] - a[9]*a[3]*a[14] - a[13]*a[2]*a[11] + a[13]*a[3]*a[10];
    inv[5] = a[0]*a[10]*a[15] - a[0]*a[11]*a[14] - a[8]*a[2]*a[15] + a[8]*a[3]*a[14] + a[12]*a[2]*a[11] - a[12]*a[3]*a[10];
    inv[9] = -a[0]*a[9]*a[15] + a[0]*a[11]*a[13] + a[8]*a[1]*a[15] - a[8]*a[3]*a[13] - a[12]*a[1]*a[11] + a[12]*a[3]*a[9];
    inv[13] = a[0]*a[9]*a[14] - a[0]*a[10]*a[13] - a[8]*a[1]*a[14] + a[8]*a[2]*a[13] + a[12]*a[1]*a[10] - a[12]*a[2]*a[9];
    inv[2] = a[1]*a[6]*a[15] - a[1]*a[7]*a[14] - a[5]*a[2]*a[15] + a[5]*a[3]*a[14] + a[13]*a[2]*a[7] - a[13]*a[3]*a[6];
    inv[6] = -a[0]*a[6]*a[15] + a[0]*a[7]*a[14] + a[4]*a[2]*a[15] - a[4]*a[3]*a[14] - a[12]*a[2]*a[7] + a[12]*a[3]*a[6];
    inv[10] = a[0]*a[5]*a[15] - a[0]*a[7]*a[13] - a[4]*a[1]*a[15] + a[4]*a[3]*a[13] + a[12]*a[1]*a[7] - a[12]*a[3]*a[5];
    inv[14] = -a[0]*a[5]*a[14] + a[0]*a[6]*a[13] + a[4]*a[1]*a[14] - a[4]*a[2]*a[13] - a[12]*a[1]*a[6] + a[12]*a[2]*a[5];
    inv[3] = -a[1]*a[6]*a[11] + a[1]*a[7]*a[10] + a[5]*a[2]*a[11] - a[5]*a[3]*a[10] - a[9]*a[2]*a[7] + a[9]*a[3]*a[6];
    inv[7] = a[0]*a[6]*a[11] - a[0]*a[7]*a[10] - a[4]*a[2]*a[11] + a[4]*a[3]*a[10] + a[8]*a[2]*a[7] - a[8]*a[3]*a[6];
    inv[11] = -a[0]*a[5]*a[11] + a[0]*a[7]*a[9] + a[4]*a[1]*a[11] - a[4]*a[3]*a[9] - a[8]*a[1]*a[7] + a[8]*a[3]*a[5];
    inv[15] = a[0]*a[5]*a[10] - a[0]*a[6]*a[9] - a[4]*a[1]*a[10] + a[4]*a[2]*a[9] + a[8]*a[1]*a[6] - a[8]*a[2]*a[5];
    float det = a[0] * inv[0] + a[1] * inv[4] + a[2] * inv[8] + a[3] * inv[12];
    if (det == 0) return m;
    SCNMatrix4 r;
    float *o = &r.m11;
    for (int i = 0; i < 16; i++) o[i] = inv[i] / det;
    return r;
}

@implementation NSValue (SceneKitAdditions)
+ (NSValue *)valueWithSCNVector3:(SCNVector3)v { return [NSValue valueWithBytes:&v objCType:@encode(SCNVector3)]; }
+ (NSValue *)valueWithSCNVector4:(SCNVector4)v { return [NSValue valueWithBytes:&v objCType:@encode(SCNVector4)]; }
+ (NSValue *)valueWithSCNMatrix4:(SCNMatrix4)v { return [NSValue valueWithBytes:&v objCType:@encode(SCNMatrix4)]; }
- (SCNVector3)SCNVector3Value { SCNVector3 v = {0}; [self getValue:&v size:sizeof v]; return v; }
- (SCNVector4)SCNVector4Value { SCNVector4 v = {0}; [self getValue:&v size:sizeof v]; return v; }
- (SCNMatrix4)SCNMatrix4Value { SCNMatrix4 v = {0}; [self getValue:&v size:sizeof v]; return v; }
@end

static NSArray<NSNumber *> *v3(SCNVector3 v) { return @[@(v.x), @(v.y), @(v.z)]; }
static SCNVector3 to3(NSArray<NSNumber *> *a) { return SCNVector3Make(a[0].floatValue, a[1].floatValue, a[2].floatValue); }
static NSArray<NSNumber *> *v4(SCNVector4 v) { return @[@(v.x), @(v.y), @(v.z), @(v.w)]; }
static SCNVector4 to4(NSArray<NSNumber *> *a) { return SCNVector4Make(a[0].floatValue, a[1].floatValue, a[2].floatValue, a[3].floatValue); }
static NSArray<NSNumber *> *f3(simd_float3 v) { return @[@(v.x), @(v.y), @(v.z)]; }
static simd_float3 tof3(NSArray<NSNumber *> *a) { simd_float3 v = {a[0].floatValue, a[1].floatValue, a[2].floatValue}; return v; }
/* m11 … m44, the order of both SCNMatrix4's fields and simd_float4x4's columns */
static NSArray<NSNumber *> *m16(const float *m) {
    NSMutableArray *a = [NSMutableArray arrayWithCapacity:16];
    for (int i = 0; i < 16; i++) [a addObject:@(m[i])];
    return a;
}
static void from16(NSArray<NSNumber *> *a, float *m) { for (int i = 0; i < 16; i++) m[i] = a[i].floatValue; }

@interface NSObject (ISIMSceneKit)
- (void)setIsHidden:(BOOL)v;
- (void)setIsPaused:(BOOL)v;
- (void)setIsPlaying:(BOOL)v;
- (void)setIsJitteringEnabled:(BOOL)v;
- (NSArray<NSNumber *> *)_isim_position; - (void)set_isim_position:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_worldPosition; - (void)set_isim_worldPosition:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_scale; - (void)set_isim_scale:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_eulerAngles; - (void)set_isim_eulerAngles:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_orientation; - (void)set_isim_orientation:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_rotation; - (void)set_isim_rotation:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_transform; - (void)set_isim_transform:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_worldTransform; - (void)set_isim_worldTransform:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_simdPosition; - (void)set_isim_simdPosition:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_simdWorldPosition; - (void)set_isim_simdWorldPosition:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_simdScale; - (void)set_isim_simdScale:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_simdEulerAngles; - (void)set_isim_simdEulerAngles:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_convertPosition:(NSArray<NSNumber *> *)p toNode:(id)node;
- (NSArray<NSNumber *> *)_isim_convertPosition:(NSArray<NSNumber *> *)p fromNode:(id)node;
- (NSArray<NSNumber *> *)_isim_projectPoint:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_unprojectPoint:(NSArray<NSNumber *> *)p;
- (nullable instancetype)initWithNamed:(NSString *)name;
- (nullable instancetype)initWithNamed:(NSString *)name inDirectory:(nullable NSString *)directory options:(nullable NSDictionary *)options;
- (nullable instancetype)initWithUrl:(NSURL *)url options:(nullable NSDictionary *)options error:(NSError **)error;
/* issue #330 */
- (void)setIsDoubleSided:(BOOL)v; - (void)setIsLitPerPixel:(BOOL)v; - (void)setIsGeodesic:(BOOL)v; - (void)setIsEnabled:(BOOL)v;
- (void)setIsIncremental:(BOOL)v; - (void)setIsGimbalLockEnabled:(BOOL)v; - (void)setIsAffectedByGravity:(BOOL)v;
- (void)setIsRemovedOnCompletion:(BOOL)v; - (void)setIsAdditive:(BOOL)v; - (void)setIsCumulative:(BOOL)v;
- (void)setIsTemporalAntialiasingEnabled:(BOOL)v;
- (instancetype)initWithGeometry:(nullable id)geometry;
- (instancetype)initWithSources:(NSArray *)sources elements:(nullable NSArray *)elements;
/* Swift initializers: the init family whatever their selectors say (they consume the receiver and return +1) */
- (instancetype)_isim_initWithData:(NSData *)data semantic:(NSString *)semantic layout:(NSArray<NSNumber *> *)layout __attribute__((objc_method_family(init)));
- (instancetype)initWithData:(nullable NSData *)data primitiveType:(NSInteger)t primitiveCount:(NSInteger)n bytesPerIndex:(NSInteger)b;
- (instancetype)initWithWidth:(CGFloat)w height:(CGFloat)h;
- (instancetype)initWithWidth:(CGFloat)w height:(CGFloat)h length:(CGFloat)l;
- (instancetype)initWithWidth:(CGFloat)w height:(CGFloat)h length:(CGFloat)l chamferRadius:(CGFloat)c;
- (instancetype)initWithRadius:(CGFloat)r;
- (instancetype)initWithRadius:(CGFloat)r height:(CGFloat)h;
- (instancetype)initWithTopRadius:(CGFloat)t bottomRadius:(CGFloat)b height:(CGFloat)h;
- (instancetype)initWithInnerRadius:(CGFloat)i outerRadius:(CGFloat)o height:(CGFloat)h;
- (instancetype)initWithCapRadius:(CGFloat)r height:(CGFloat)h;
- (instancetype)initWithRingRadius:(CGFloat)r pipeRadius:(CGFloat)p;
- (instancetype)initWithContents:(id)contents;
- (instancetype)initWithCaAnimation:(id)animation;
- (instancetype)initWithAnimation:(id)animation;
- (instancetype)initWithTarget:(nullable id)target;
- (instancetype)initWithType:(NSInteger)type shape:(nullable id)shape;
- (instancetype)_isim_initWithGeometry:(id)geometry options:(nullable NSDictionary *)options __attribute__((objc_method_family(init)));
- (instancetype)_isim_initWithNode:(id)node options:(nullable NSDictionary *)options __attribute__((objc_method_family(init)));
- (instancetype)initWithDevice:(nullable id)device options:(nullable NSDictionary *)options;
- (void)_isim_lookAt:(NSArray<NSNumber *> *)p;
- (NSArray<NSNumber *> *)_isim_boundingBox; - (void)_isim_setBoundingBox:(NSArray<NSNumber *> *)b;
- (NSArray<NSNumber *> *)_isim_pivot; - (void)set_isim_pivot:(NSArray<NSNumber *> *)v;
- (NSArray *)_isim_hitTestFrom:(NSArray<NSNumber *> *)a to:(NSArray<NSNumber *> *)b options:(nullable NSDictionary *)options;
- (NSArray<NSNumber *> *)_isim_contentsTransform; - (void)set_isim_contentsTransform:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_projectionTransform; - (void)set_isim_projectionTransform:(NSArray<NSNumber *> *)v;
+ (id)_isim_moveBy:(NSArray<NSNumber *> *)d duration:(NSTimeInterval)t;
+ (id)_isim_moveTo:(NSArray<NSNumber *> *)p duration:(NSTimeInterval)t;
+ (id)_isim_rotateByAngle:(CGFloat)a aroundAxis:(NSArray<NSNumber *> *)axis duration:(NSTimeInterval)t;
+ (id)_isim_rotateToAxisAngle:(NSArray<NSNumber *> *)a duration:(NSTimeInterval)t;
- (NSArray<NSNumber *> *)_isim_velocity; - (void)set_isim_velocity:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_angularVelocity; - (void)set_isim_angularVelocity:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_velocityFactor; - (void)set_isim_velocityFactor:(NSArray<NSNumber *> *)v;
- (void)_isim_applyForce:(NSArray<NSNumber *> *)f impulse:(BOOL)i;
- (void)_isim_applyForce:(NSArray<NSNumber *> *)f atPosition:(NSArray<NSNumber *> *)p impulse:(BOOL)i;
- (void)_isim_applyTorque:(NSArray<NSNumber *> *)t impulse:(BOOL)i;
- (NSArray<NSNumber *> *)_isim_gravity; - (void)set_isim_gravity:(NSArray<NSNumber *> *)v;
- (NSArray<NSNumber *> *)_isim_contactPoint; - (NSArray<NSNumber *> *)_isim_contactNormal;
- (NSArray<NSNumber *> *)_isim_localCoordinates; - (NSArray<NSNumber *> *)_isim_worldCoordinates;
- (NSArray<NSNumber *> *)_isim_localNormal; - (NSArray<NSNumber *> *)_isim_worldNormal; - (NSArray<NSNumber *> *)_isim_modelTransform;
@end

@implementation SCNNode (ISIMObjC)
+ (instancetype)node { return [[self alloc] init]; }
- (void)setHidden:(BOOL)v { [self setIsHidden:v]; }
- (SCNVector3)position { return to3([self _isim_position]); }
- (void)setPosition:(SCNVector3)v { [self set_isim_position:v3(v)]; }
- (SCNVector3)worldPosition { return to3([self _isim_worldPosition]); }
- (void)setWorldPosition:(SCNVector3)v { [self set_isim_worldPosition:v3(v)]; }
- (SCNVector3)scale { return to3([self _isim_scale]); }
- (void)setScale:(SCNVector3)v { [self set_isim_scale:v3(v)]; }
- (SCNVector3)eulerAngles { return to3([self _isim_eulerAngles]); }
- (void)setEulerAngles:(SCNVector3)v { [self set_isim_eulerAngles:v3(v)]; }
- (SCNQuaternion)orientation { return to4([self _isim_orientation]); }
- (void)setOrientation:(SCNQuaternion)v { [self set_isim_orientation:v4(v)]; }
- (SCNVector4)rotation { return to4([self _isim_rotation]); }
- (void)setRotation:(SCNVector4)v { [self set_isim_rotation:v4(v)]; }
- (SCNMatrix4)transform { SCNMatrix4 m; from16([self _isim_transform], &m.m11); return m; }
- (void)setTransform:(SCNMatrix4)m { [self set_isim_transform:m16(&m.m11)]; }
- (SCNMatrix4)worldTransform { SCNMatrix4 m; from16([self _isim_worldTransform], &m.m11); return m; }
- (void)setWorldTransform:(SCNMatrix4)m { [self set_isim_worldTransform:m16(&m.m11)]; }
- (simd_float3)simdPosition { return tof3([self _isim_simdPosition]); }
- (void)setSimdPosition:(simd_float3)v { [self set_isim_simdPosition:f3(v)]; }
- (simd_float3)simdWorldPosition { return tof3([self _isim_simdWorldPosition]); }
- (void)setSimdWorldPosition:(simd_float3)v { [self set_isim_simdWorldPosition:f3(v)]; }
- (simd_float3)simdScale { return tof3([self _isim_simdScale]); }
- (void)setSimdScale:(simd_float3)v { [self set_isim_simdScale:f3(v)]; }
- (simd_float3)simdEulerAngles { return tof3([self _isim_simdEulerAngles]); }
- (void)setSimdEulerAngles:(simd_float3)v { [self set_isim_simdEulerAngles:f3(v)]; }
- (simd_float4x4)simdTransform { simd_float4x4 m; from16([self _isim_transform], (float *)&m); return m; }
- (void)setSimdTransform:(simd_float4x4)m { [self set_isim_transform:m16((const float *)&m)]; }
- (simd_float4x4)simdWorldTransform { simd_float4x4 m; from16([self _isim_worldTransform], (float *)&m); return m; }
- (void)setSimdWorldTransform:(simd_float4x4)m { [self set_isim_worldTransform:m16((const float *)&m)]; }
- (SCNVector3)convertPosition:(SCNVector3)p toNode:(SCNNode *)node { return to3([self _isim_convertPosition:v3(p) toNode:node]); }
- (SCNVector3)convertPosition:(SCNVector3)p fromNode:(SCNNode *)node { return to3([self _isim_convertPosition:v3(p) fromNode:node]); }
@end

@implementation SCNScene (ISIMObjC)
+ (instancetype)scene { return [[self alloc] init]; }
+ (instancetype)sceneNamed:(NSString *)name { return [[self alloc] initWithNamed:name]; }
+ (instancetype)sceneNamed:(NSString *)name inDirectory:(NSString *)directory options:(NSDictionary *)options {
    return [[self alloc] initWithNamed:name inDirectory:directory options:options];
}
+ (instancetype)sceneWithURL:(NSURL *)url options:(NSDictionary *)options error:(NSError **)error {
    return [[self alloc] initWithUrl:url options:options error:error];
}
- (void)setPaused:(BOOL)v { [self setIsPaused:v]; }
@end

@implementation SCNView (ISIMObjC)
- (void)setPlaying:(BOOL)v { [self setIsPlaying:v]; }
- (void)setJitteringEnabled:(BOOL)v { [self setIsJitteringEnabled:v]; }
- (SCNVector3)projectPoint:(SCNVector3)p { return to3([self _isim_projectPoint:v3(p)]); }
- (SCNVector3)unprojectPoint:(SCNVector3)p { return to3([self _isim_unprojectPoint:v3(p)]); }
@end

/* ---- issue #330: the renderer's classes ---- */

SCNGeometrySourceSemantic const SCNGeometrySourceSemanticVertex = @"kGeometrySourceSemanticVertex";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticNormal = @"kGeometrySourceSemanticNormal";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticColor = @"kGeometrySourceSemanticColor";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticTexcoord = @"kGeometrySourceSemanticTexcoord";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticTangent = @"kGeometrySourceSemanticTangent";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticVertexCrease = @"kGeometrySourceSemanticVertexCrease";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticEdgeCrease = @"kGeometrySourceSemanticEdgeCrease";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticBoneWeights = @"kGeometrySourceSemanticBoneWeights";
SCNGeometrySourceSemantic const SCNGeometrySourceSemanticBoneIndices = @"kGeometrySourceSemanticBoneIndices";
SCNLightingModel const SCNLightingModelPhong = @"SCNLightingModelPhong";
SCNLightingModel const SCNLightingModelBlinn = @"SCNLightingModelBlinn";
SCNLightingModel const SCNLightingModelLambert = @"SCNLightingModelLambert";
SCNLightingModel const SCNLightingModelConstant = @"SCNLightingModelConstant";
SCNLightingModel const SCNLightingModelPhysicallyBased = @"SCNLightingModelPhysicallyBased";
SCNLightingModel const SCNLightingModelShadowOnly = @"SCNLightingModelShadowOnly";
SCNLightType const SCNLightTypeAmbient = @"ambient";
SCNLightType const SCNLightTypeOmni = @"omni";
SCNLightType const SCNLightTypeDirectional = @"directional";
SCNLightType const SCNLightTypeSpot = @"spot";
SCNLightType const SCNLightTypeIES = @"ies";
SCNLightType const SCNLightTypeProbe = @"probe";
SCNLightType const SCNLightTypeArea = @"area";
SCNPhysicsShapeOption const SCNPhysicsShapeTypeKey = @"SCNPhysicsShapeTypeKey";
SCNPhysicsShapeOption const SCNPhysicsShapeKeepAsCompoundKey = @"SCNPhysicsShapeKeepAsCompoundKey";
SCNPhysicsShapeOption const SCNPhysicsShapeScaleKey = @"SCNPhysicsShapeScaleKey";
SCNPhysicsShapeOption const SCNPhysicsShapeCollisionMarginKey = @"SCNPhysicsShapeCollisionMarginKey";
SCNPhysicsShapeType const SCNPhysicsShapeTypeBoundingBox = @"boundingBox";
SCNPhysicsShapeType const SCNPhysicsShapeTypeConvexHull = @"convexHull";
SCNPhysicsShapeType const SCNPhysicsShapeTypeConcavePolyhedron = @"concavePolyhedron";
SCNHitTestOption const SCNHitTestFirstFoundOnlyKey = @"firstFoundOnly";
SCNHitTestOption const SCNHitTestSortResultsKey = @"sortResults";
SCNHitTestOption const SCNHitTestClipToZRangeKey = @"clipToZRange";
SCNHitTestOption const SCNHitTestBackFaceCullingKey = @"backFaceCulling";
SCNHitTestOption const SCNHitTestBoundingBoxOnlyKey = @"boundingBoxOnly";
SCNHitTestOption const SCNHitTestIgnoreChildNodesKey = @"ignoreChildNodes";
SCNHitTestOption const SCNHitTestRootNodeKey = @"rootNode";
SCNHitTestOption const SCNHitTestIgnoreHiddenNodesKey = @"ignoreHiddenNodes";
SCNHitTestOption const SCNHitTestOptionCategoryBitMask = @"categoryBitMask";
SCNHitTestOption const SCNHitTestOptionSearchMode = @"searchMode";

static BOOL box6(NSArray<NSNumber *> *b, SCNVector3 *min, SCNVector3 *max) {
    if (b.count < 6) return NO;
    if (min) *min = SCNVector3Make(b[0].floatValue, b[1].floatValue, b[2].floatValue);
    if (max) *max = SCNVector3Make(b[3].floatValue, b[4].floatValue, b[5].floatValue);
    return !(b[0].floatValue == 0 && b[1].floatValue == 0 && b[2].floatValue == 0 && b[3].floatValue == 0 && b[4].floatValue == 0 && b[5].floatValue == 0);
}
static NSArray<NSNumber *> *array6(const SCNVector3 *min, const SCNVector3 *max) {
    SCNVector3 a = min ? *min : SCNVector3Zero, b = max ? *max : SCNVector3Zero;
    return @[@(a.x), @(a.y), @(a.z), @(b.x), @(b.y), @(b.z)];
}

@implementation SCNNode (ISIMObjCRenderer)
+ (instancetype)nodeWithGeometry:(SCNGeometry *)geometry { return [[self alloc] initWithGeometry:geometry]; }
- (void)setPaused:(BOOL)v { [self setIsPaused:v]; }
- (void)lookAt:(SCNVector3)p { [self _isim_lookAt:v3(p)]; }
- (SCNMatrix4)pivot { SCNMatrix4 m; from16([self _isim_pivot], &m.m11); return m; }
- (void)setPivot:(SCNMatrix4)m { [self set_isim_pivot:m16(&m.m11)]; }
- (BOOL)getBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max { return box6([self _isim_boundingBox], min, max); }
- (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max { [self _isim_setBoundingBox:array6(min, max)]; }
- (NSArray<SCNHitTestResult *> *)hitTestWithSegmentFromPoint:(SCNVector3)a toPoint:(SCNVector3)b options:(NSDictionary *)options {
    return [self _isim_hitTestFrom:v3(a) to:v3(b) options:options];
}
@end

@implementation SCNGeometry (ISIMObjC)
+ (instancetype)geometry { return [[self alloc] init]; }
+ (instancetype)geometryWithSources:(NSArray<SCNGeometrySource *> *)sources elements:(NSArray<SCNGeometryElement *> *)elements {
    return [[self alloc] initWithSources:sources elements:elements];
}
- (BOOL)getBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max { return box6([self _isim_boundingBox], min, max); }
- (void)setBoundingBoxMin:(SCNVector3 *)min max:(SCNVector3 *)max { [self _isim_setBoundingBox:array6(min, max)]; }
@end

@implementation SCNGeometrySource (ISIMObjC)
+ (instancetype)geometrySourceWithData:(NSData *)data semantic:(SCNGeometrySourceSemantic)semantic vectorCount:(NSInteger)n
                       floatComponents:(BOOL)f componentsPerVector:(NSInteger)c bytesPerComponent:(NSInteger)b dataOffset:(NSInteger)o
                            dataStride:(NSInteger)s {
    return [[self alloc] _isim_initWithData:data semantic:semantic layout:@[@(n), @(f), @(c), @(b), @(o), @(s)]];
}
+ (instancetype)geometrySourceWithVertices:(const SCNVector3 *)v count:(NSInteger)n {
    return [self geometrySourceWithData:[NSData dataWithBytes:v length:(NSUInteger)n * sizeof *v] semantic:SCNGeometrySourceSemanticVertex
                            vectorCount:n floatComponents:YES componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:sizeof *v];
}
+ (instancetype)geometrySourceWithNormals:(const SCNVector3 *)v count:(NSInteger)n {
    return [self geometrySourceWithData:[NSData dataWithBytes:v length:(NSUInteger)n * sizeof *v] semantic:SCNGeometrySourceSemanticNormal
                            vectorCount:n floatComponents:YES componentsPerVector:3 bytesPerComponent:4 dataOffset:0 dataStride:sizeof *v];
}
+ (instancetype)geometrySourceWithTextureCoordinates:(const CGPoint *)t count:(NSInteger)n {
    /* CGPoint holds doubles */
    return [self geometrySourceWithData:[NSData dataWithBytes:t length:(NSUInteger)n * sizeof *t] semantic:SCNGeometrySourceSemanticTexcoord
                            vectorCount:n floatComponents:YES componentsPerVector:2 bytesPerComponent:sizeof(CGFloat) dataOffset:0 dataStride:sizeof *t];
}
@end

@implementation SCNGeometryElement (ISIMObjC)
+ (instancetype)geometryElementWithData:(NSData *)data primitiveType:(SCNGeometryPrimitiveType)t primitiveCount:(NSInteger)n bytesPerIndex:(NSInteger)b {
    return [[self alloc] initWithData:data primitiveType:t primitiveCount:n bytesPerIndex:b];
}
@end

@implementation SCNPlane (ISIMObjC)
+ (instancetype)planeWithWidth:(CGFloat)w height:(CGFloat)h { return [[self alloc] initWithWidth:w height:h]; }
@end
@implementation SCNBox (ISIMObjC)
+ (instancetype)boxWithWidth:(CGFloat)w height:(CGFloat)h length:(CGFloat)l chamferRadius:(CGFloat)c {
    return [[self alloc] initWithWidth:w height:h length:l chamferRadius:c];
}
@end
@implementation SCNPyramid (ISIMObjC)
+ (instancetype)pyramidWithWidth:(CGFloat)w height:(CGFloat)h length:(CGFloat)l { return [[self alloc] initWithWidth:w height:h length:l]; }
@end
@implementation SCNSphere (ISIMObjC)
+ (instancetype)sphereWithRadius:(CGFloat)r { return [[self alloc] initWithRadius:r]; }
- (void)setGeodesic:(BOOL)v { [self setIsGeodesic:v]; }
@end
@implementation SCNCylinder (ISIMObjC)
+ (instancetype)cylinderWithRadius:(CGFloat)r height:(CGFloat)h { return [[self alloc] initWithRadius:r height:h]; }
@end
@implementation SCNCone (ISIMObjC)
+ (instancetype)coneWithTopRadius:(CGFloat)t bottomRadius:(CGFloat)b height:(CGFloat)h { return [[self alloc] initWithTopRadius:t bottomRadius:b height:h]; }
@end
@implementation SCNTube (ISIMObjC)
+ (instancetype)tubeWithInnerRadius:(CGFloat)i outerRadius:(CGFloat)o height:(CGFloat)h { return [[self alloc] initWithInnerRadius:i outerRadius:o height:h]; }
@end
@implementation SCNCapsule (ISIMObjC)
+ (instancetype)capsuleWithCapRadius:(CGFloat)r height:(CGFloat)h { return [[self alloc] initWithCapRadius:r height:h]; }
@end
@implementation SCNTorus (ISIMObjC)
+ (instancetype)torusWithRingRadius:(CGFloat)r pipeRadius:(CGFloat)p { return [[self alloc] initWithRingRadius:r pipeRadius:p]; }
@end
@implementation SCNFloor (ISIMObjC)
+ (instancetype)floor { return [[self alloc] init]; }
@end

@implementation SCNMaterialProperty (ISIMObjC)
+ (instancetype)materialPropertyWithContents:(id)contents { return [[self alloc] initWithContents:contents]; }
- (SCNMatrix4)contentsTransform { SCNMatrix4 m; from16([self _isim_contentsTransform], &m.m11); return m; }
- (void)setContentsTransform:(SCNMatrix4)m { [self set_isim_contentsTransform:m16(&m.m11)]; }
@end
@implementation SCNMaterial (ISIMObjC)
+ (instancetype)material { return [[self alloc] init]; }
- (void)setDoubleSided:(BOOL)v { [self setIsDoubleSided:v]; }
- (void)setLitPerPixel:(BOOL)v { [self setIsLitPerPixel:v]; }
@end
@implementation SCNLight (ISIMObjC)
+ (instancetype)light { return [[self alloc] init]; }
@end
@implementation SCNCamera (ISIMObjC)
+ (instancetype)camera { return [[self alloc] init]; }
- (SCNMatrix4)projectionTransform { SCNMatrix4 m; from16([self _isim_projectionTransform], &m.m11); return m; }
- (void)setProjectionTransform:(SCNMatrix4)m { [self set_isim_projectionTransform:m16(&m.m11)]; }
@end

@implementation SCNAction (ISIMObjC)
+ (SCNAction *)moveBy:(SCNVector3)d duration:(NSTimeInterval)t { return [self _isim_moveBy:v3(d) duration:t]; }
+ (SCNAction *)moveTo:(SCNVector3)p duration:(NSTimeInterval)t { return [self _isim_moveTo:v3(p) duration:t]; }
+ (SCNAction *)rotateByAngle:(CGFloat)a aroundAxis:(SCNVector3)axis duration:(NSTimeInterval)t {
    return [self _isim_rotateByAngle:a aroundAxis:v3(axis) duration:t];
}
+ (SCNAction *)rotateToAxisAngle:(SCNVector4)a duration:(NSTimeInterval)t { return [self _isim_rotateToAxisAngle:v4(a) duration:t]; }
@end
@implementation SCNAnimation (ISIMObjC)
+ (instancetype)animationWithCAAnimation:(CAAnimation *)a { return [[self alloc] initWithCaAnimation:a]; }
- (void)setRemovedOnCompletion:(BOOL)v { [self setIsRemovedOnCompletion:v]; }
- (void)setAdditive:(BOOL)v { [self setIsAdditive:v]; }
- (void)setCumulative:(BOOL)v { [self setIsCumulative:v]; }
@end
@implementation SCNAnimationPlayer (ISIMObjC)
+ (instancetype)animationPlayerWithAnimation:(SCNAnimation *)a { return [[self alloc] initWithAnimation:a]; }
@end

@implementation SCNConstraint (ISIMObjC)
- (void)setEnabled:(BOOL)v { [self setIsEnabled:v]; }
- (void)setIncremental:(BOOL)v { [self setIsIncremental:v]; }
@end
@implementation SCNLookAtConstraint (ISIMObjC)
+ (instancetype)lookAtConstraintWithTarget:(SCNNode *)target { return [[self alloc] initWithTarget:target]; }
- (void)setGimbalLockEnabled:(BOOL)v { [self setIsGimbalLockEnabled:v]; }
@end
@implementation SCNBillboardConstraint (ISIMObjC)
+ (instancetype)billboardConstraint { return [[self alloc] init]; }
@end
@implementation SCNDistanceConstraint (ISIMObjC)
+ (instancetype)distanceConstraintWithTarget:(SCNNode *)target { return [[self alloc] initWithTarget:target]; }
@end
@implementation SCNReplicatorConstraint (ISIMObjC)
+ (instancetype)replicatorConstraintWithTarget:(SCNNode *)target { return [[self alloc] initWithTarget:target]; }
@end

@implementation SCNPhysicsShape (ISIMObjC)
+ (instancetype)shapeWithGeometry:(SCNGeometry *)g options:(NSDictionary *)o { return [[self alloc] _isim_initWithGeometry:g options:o]; }
+ (instancetype)shapeWithNode:(SCNNode *)n options:(NSDictionary *)o { return [[self alloc] _isim_initWithNode:n options:o]; }
@end
@implementation SCNPhysicsBody (ISIMObjC)
+ (instancetype)bodyWithType:(SCNPhysicsBodyType)t shape:(SCNPhysicsShape *)s { return [[self alloc] initWithType:t shape:s]; }
- (void)setAffectedByGravity:(BOOL)v { [self setIsAffectedByGravity:v]; }
- (SCNVector3)velocity { return to3([self _isim_velocity]); }
- (void)setVelocity:(SCNVector3)v { [self set_isim_velocity:v3(v)]; }
- (SCNVector4)angularVelocity { return to4([self _isim_angularVelocity]); }
- (void)setAngularVelocity:(SCNVector4)v { [self set_isim_angularVelocity:v4(v)]; }
- (SCNVector3)velocityFactor { return to3([self _isim_velocityFactor]); }
- (void)setVelocityFactor:(SCNVector3)v { [self set_isim_velocityFactor:v3(v)]; }
- (void)applyForce:(SCNVector3)f impulse:(BOOL)i { [self _isim_applyForce:v3(f) impulse:i]; }
- (void)applyForce:(SCNVector3)f atPosition:(SCNVector3)p impulse:(BOOL)i { [self _isim_applyForce:v3(f) atPosition:v3(p) impulse:i]; }
- (void)applyTorque:(SCNVector4)t impulse:(BOOL)i { [self _isim_applyTorque:v4(t) impulse:i]; }
@end
@implementation SCNPhysicsWorld (ISIMObjC)
- (SCNVector3)gravity { return to3([self _isim_gravity]); }
- (void)setGravity:(SCNVector3)v { [self set_isim_gravity:v3(v)]; }
@end
@implementation SCNPhysicsContact (ISIMObjC)
- (SCNVector3)contactPoint { return to3([self _isim_contactPoint]); }
- (SCNVector3)contactNormal { return to3([self _isim_contactNormal]); }
@end
@implementation SCNHitTestResult (ISIMObjC)
- (SCNVector3)localCoordinates { return to3([self _isim_localCoordinates]); }
- (SCNVector3)worldCoordinates { return to3([self _isim_worldCoordinates]); }
- (SCNVector3)localNormal { return to3([self _isim_localNormal]); }
- (SCNVector3)worldNormal { return to3([self _isim_worldNormal]); }
- (SCNMatrix4)modelTransform { SCNMatrix4 m; from16([self _isim_modelTransform], &m.m11); return m; }
@end

@implementation SCNRenderer (ISIMObjC)
+ (instancetype)rendererWithDevice:(id<MTLDevice>)device options:(NSDictionary *)options { return [[self alloc] initWithDevice:device options:options]; }
- (void)setPlaying:(BOOL)v { [self setIsPlaying:v]; }
- (void)setJitteringEnabled:(BOOL)v { [self setIsJitteringEnabled:v]; }
- (SCNVector3)projectPoint:(SCNVector3)p { return to3([self _isim_projectPoint:v3(p)]); }
- (SCNVector3)unprojectPoint:(SCNVector3)p { return to3([self _isim_unprojectPoint:v3(p)]); }
@end
@implementation SCNView (ISIMObjCRenderer)
- (void)setTemporalAntialiasingEnabled:(BOOL)v { [self setIsTemporalAntialiasingEnabled:v]; }
@end
