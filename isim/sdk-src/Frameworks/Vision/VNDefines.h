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
NS_ASSUME_NONNULL_END
#endif
