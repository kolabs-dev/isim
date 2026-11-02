#pragma once
#import <Foundation/Foundation.h>
#include <simd/simd.h>   /* simd_float2 for VNContour and the landmarks, matrix_float3x3 for the homography */
#if !defined(__swift__)
NS_ASSUME_NONNULL_BEGIN
#ifdef __cplusplus
#define VN_EXPORT extern "C"
#else
#define VN_EXPORT extern
#endif
NS_ASSUME_NONNULL_END
#endif
