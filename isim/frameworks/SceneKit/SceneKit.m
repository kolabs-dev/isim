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
