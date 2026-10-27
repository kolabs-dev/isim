#pragma once
#import <Foundation/Foundation.h>
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define VN_EXPORT extern "C"
#else
#define VN_EXPORT extern
#endif
/* simd_float2 for VNContour and the face landmark functions: <simd/simd.h> when the SDK has it */
#if __has_include(<simd/simd.h>)
#include <simd/simd.h>
#elif !defined(VN_ISIM_SIMD_FLOAT2)
#define VN_ISIM_SIMD_FLOAT2 1
typedef float simd_float2 __attribute__((__ext_vector_type__(2)));
typedef simd_float2 vector_float2;
#endif
/* matrix_float3x3 for VNImageHomographicAlignmentObservation (Apple's layout) */
#if !__has_include(<simd/simd.h>)
typedef float simd_float3 __attribute__((__ext_vector_type__(3)));
typedef float simd_float4 __attribute__((__ext_vector_type__(4)));
#ifndef ISIM_SIMD_MATRIX_TYPES
#define ISIM_SIMD_MATRIX_TYPES 1
typedef struct { simd_float3 columns[3]; } simd_float3x3;
typedef struct { simd_float4 columns[4]; } simd_float4x4;
#endif
typedef simd_float3x3 matrix_float3x3;
#endif
NS_ASSUME_NONNULL_END
#endif
