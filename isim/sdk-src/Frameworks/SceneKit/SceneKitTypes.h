#pragma once
/* isim SceneKit: SCNVector3, SCNVector4 (SCNQuaternion), SCNMatrix4 and their functions (SCNFloat is float on iOS), the
 * same layout as the SceneKit Swift overlay's structs; the exported functions are in SceneKit.framework. The simd types
 * come from <simd/simd.h> when the SDK has it, else from the minimal typedefs below (Apple's layout). */
#import <Foundation/Foundation.h>
#if !defined(__swift__)
#if __has_include(<simd/simd.h>)
#include <simd/simd.h>
#else
typedef float simd_float2 __attribute__((__ext_vector_type__(2)));
typedef float simd_float3 __attribute__((__ext_vector_type__(3)));
typedef float simd_float4 __attribute__((__ext_vector_type__(4)));
typedef struct { simd_float3 columns[3]; } simd_float3x3;
typedef struct { simd_float4 columns[4]; } simd_float4x4;
typedef struct { simd_float4 vector; } simd_quatf;
typedef simd_float2 vector_float2;
typedef simd_float3 vector_float3;
typedef simd_float4 vector_float4;
typedef simd_float3x3 matrix_float3x3;
typedef simd_float4x4 matrix_float4x4;
static const simd_float4x4 matrix_identity_float4x4 = {{{1, 0, 0, 0}, {0, 1, 0, 0}, {0, 0, 1, 0}, {0, 0, 0, 1}}};
#endif
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define SCN_EXPORT extern "C"
#else
#define SCN_EXPORT extern
#endif
typedef float SCNFloat;
typedef struct SCNVector3 { float x, y, z; } SCNVector3;
typedef struct SCNVector4 { float x, y, z, w; } SCNVector4;
typedef SCNVector4 SCNQuaternion;
typedef struct SCNMatrix4 {
    float m11, m12, m13, m14;
    float m21, m22, m23, m24;
    float m31, m32, m33, m34;
    float m41, m42, m43, m44;
} SCNMatrix4;
SCN_EXPORT const SCNVector3 SCNVector3Zero;
SCN_EXPORT const SCNVector4 SCNVector4Zero;
SCN_EXPORT const SCNMatrix4 SCNMatrix4Identity;
SCN_EXPORT BOOL SCNVector3EqualToVector3(SCNVector3 a, SCNVector3 b);
SCN_EXPORT BOOL SCNVector4EqualToVector4(SCNVector4 a, SCNVector4 b);
SCN_EXPORT BOOL SCNMatrix4IsIdentity(SCNMatrix4 m);
SCN_EXPORT BOOL SCNMatrix4EqualToMatrix4(SCNMatrix4 a, SCNMatrix4 b);
SCN_EXPORT SCNMatrix4 SCNMatrix4MakeRotation(float angle, float x, float y, float z);
SCN_EXPORT SCNMatrix4 SCNMatrix4Rotate(SCNMatrix4 m, float angle, float x, float y, float z);
SCN_EXPORT SCNMatrix4 SCNMatrix4Invert(SCNMatrix4 m);
SCN_EXPORT SCNMatrix4 SCNMatrix4Mult(SCNMatrix4 a, SCNMatrix4 b);
NS_INLINE SCNVector3 SCNVector3Make(float x, float y, float z) { SCNVector3 v = {x, y, z}; return v; }
NS_INLINE SCNVector4 SCNVector4Make(float x, float y, float z, float w) { SCNVector4 v = {x, y, z, w}; return v; }
NS_INLINE SCNMatrix4 SCNMatrix4MakeTranslation(float tx, float ty, float tz) {
    SCNMatrix4 m = SCNMatrix4Identity; m.m41 = tx; m.m42 = ty; m.m43 = tz; return m;
}
NS_INLINE SCNMatrix4 SCNMatrix4MakeScale(float sx, float sy, float sz) {
    SCNMatrix4 m = SCNMatrix4Identity; m.m11 = sx; m.m22 = sy; m.m33 = sz; return m;
}
NS_INLINE SCNMatrix4 SCNMatrix4Translate(SCNMatrix4 m, float tx, float ty, float tz) { m.m41 += tx; m.m42 += ty; m.m43 += tz; return m; }
NS_INLINE SCNMatrix4 SCNMatrix4Scale(SCNMatrix4 m, float sx, float sy, float sz) { return SCNMatrix4Mult(SCNMatrix4MakeScale(sx, sy, sz), m); }
NS_INLINE SCNMatrix4 SCNMatrix4FromMat4(simd_float4x4 m) {
    SCNMatrix4 r;
    memcpy(&r, &m, sizeof r);
    return r;
}
NS_INLINE simd_float4x4 SCNMatrix4ToMat4(SCNMatrix4 m) {
    simd_float4x4 r;
    memcpy(&r, &m, sizeof r);
    return r;
}
NS_INLINE SCNVector3 SCNVector3FromFloat3(simd_float3 v) { return SCNVector3Make(v.x, v.y, v.z); }
NS_INLINE SCNVector4 SCNVector4FromFloat4(simd_float4 v) { return SCNVector4Make(v.x, v.y, v.z, v.w); }
NS_INLINE simd_float3 SCNVector3ToFloat3(SCNVector3 v) { simd_float3 r = {v.x, v.y, v.z}; return r; }
NS_INLINE simd_float4 SCNVector4ToFloat4(SCNVector4 v) { simd_float4 r = {v.x, v.y, v.z, v.w}; return r; }
@interface NSValue (SceneKitAdditions)
+ (NSValue *)valueWithSCNVector3:(SCNVector3)v;
+ (NSValue *)valueWithSCNVector4:(SCNVector4)v;
+ (NSValue *)valueWithSCNMatrix4:(SCNMatrix4)v;
@property (nonatomic, readonly) SCNVector3 SCNVector3Value;
@property (nonatomic, readonly) SCNVector4 SCNVector4Value;
@property (nonatomic, readonly) SCNMatrix4 SCNMatrix4Value;
@end
NS_ASSUME_NONNULL_END
#endif
