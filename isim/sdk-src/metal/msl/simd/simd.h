#pragma once
/* isim Metal on the CPU: <simd/simd.h> as Metal Shading Language sees it, for headers shared by Swift and Metal: the
 * simd_ and vector_ names of MSL's vector and matrix types (defined by isim's metal_stdlib) */
#define __ISIM_SIMD(t) typedef t##2 simd_##t##2; typedef t##3 simd_##t##3; typedef t##4 simd_##t##4; \
    typedef t##2 vector_##t##2; typedef t##3 vector_##t##3; typedef t##4 vector_##t##4; \
    typedef packed_##t##2 simd_packed_##t##2; typedef packed_##t##4 simd_packed_##t##4;
__ISIM_SIMD(float) __ISIM_SIMD(half) __ISIM_SIMD(int) __ISIM_SIMD(uint) __ISIM_SIMD(short) __ISIM_SIMD(ushort)
__ISIM_SIMD(char) __ISIM_SIMD(uchar)
#undef __ISIM_SIMD
typedef float simd_float1; typedef half simd_half1; typedef int simd_int1; typedef uint simd_uint1;
typedef float vector_float1; typedef int vector_int1; typedef uint vector_uint1;
#define __ISIM_SIMD_MAT(t) typedef t##2x2 simd_##t##2x2; typedef t##2x3 simd_##t##2x3; typedef t##2x4 simd_##t##2x4; \
    typedef t##3x2 simd_##t##3x2; typedef t##3x3 simd_##t##3x3; typedef t##3x4 simd_##t##3x4; \
    typedef t##4x2 simd_##t##4x2; typedef t##4x3 simd_##t##4x3; typedef t##4x4 simd_##t##4x4; \
    typedef t##2x2 matrix_##t##2x2; typedef t##3x3 matrix_##t##3x3; typedef t##4x4 matrix_##t##4x4; \
    typedef t##2x3 matrix_##t##2x3; typedef t##2x4 matrix_##t##2x4; typedef t##3x2 matrix_##t##3x2; \
    typedef t##3x4 matrix_##t##3x4; typedef t##4x2 matrix_##t##4x2; typedef t##4x3 matrix_##t##4x3;
__ISIM_SIMD_MAT(float) __ISIM_SIMD_MAT(half)
#undef __ISIM_SIMD_MAT
