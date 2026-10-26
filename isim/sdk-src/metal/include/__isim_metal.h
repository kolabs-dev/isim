#pragma once
/* isim Metal on the CPU: the Metal Shading Language standard library (metal_stdlib) as C++, for kernels that
 * tools/mslc.py translates and clang compiles for the guest. Adapted: vectors are clang's ext_vector types (so
 * swizzles work), matrices are classes, textures read and write isim's texture storage (__isim_metal_abi.h), and the
 * SIMD-group width is 1. Self-authored after Apple's Metal Shading Language Specification. */
#include "__isim_metal_abi.h"

/* ---- scalar types ---- */
typedef _Float16 half;
typedef unsigned char uchar;
typedef unsigned short ushort;
typedef unsigned int uint;
typedef unsigned long ulong;
typedef __SIZE_TYPE__ size_t;
typedef __PTRDIFF_TYPE__ ptrdiff_t;

/* ---- vector types (bool vectors are char vectors: clang's bool vectors have no swizzles) ---- */
#define __ISIM_VEC(T, name) \
    typedef T name##2 __attribute__((ext_vector_type(2))); \
    typedef T name##3 __attribute__((ext_vector_type(3))); \
    typedef T name##4 __attribute__((ext_vector_type(4)));
__ISIM_VEC(signed char, bool)
__ISIM_VEC(signed char, char)
__ISIM_VEC(unsigned char, uchar)
__ISIM_VEC(short, short)
__ISIM_VEC(unsigned short, ushort)
__ISIM_VEC(int, int)
__ISIM_VEC(unsigned int, uint)
__ISIM_VEC(long, long)
__ISIM_VEC(unsigned long, ulong)
__ISIM_VEC(_Float16, half)
__ISIM_VEC(float, float)
#undef __ISIM_VEC

template <class T> concept __isim_is_vec = requires { __builtin_vectorelements(T); };
template <class T> struct __isim_elem_t { using type = T; };
template <__isim_is_vec V> struct __isim_elem_t<V> { using type = __remove_cvref(decltype(V{}[0])); };
template <class T> using __isim_elem = typename __isim_elem_t<__remove_cvref(T)>::type;
template <class T> constexpr int __isim_n() { if constexpr (__isim_is_vec<T>) return __builtin_vectorelements(T); else return 1; }
template <class T> concept __isim_float = __is_same(__remove_cvref(T), float) || __is_same(__remove_cvref(T), _Float16);
template <class T> concept __isim_int = __is_integral(__remove_cvref(T)) && !__is_same(__remove_cvref(T), bool);
template <class T> concept __isim_scalar = __isim_float<T> || __isim_int<T> || __is_same(__remove_cvref(T), bool);

namespace metal {
template <class T, int N> using vec = T __attribute__((ext_vector_type(N)));
}
using metal::vec;

/* floatN(...) and the other vector constructors: tools/mslc.py rewrites them to __isim_make<T, N>(...), which takes
 * scalars and vectors in any mix (a single scalar fills every component) */
template <class T, int N, class... A> inline vec<T, N> __isim_make(A... a) {
    vec<T, N> r = {};
    int i = 0;
    auto put = [&](auto x) {
        using X = decltype(x);
        if constexpr (__isim_is_vec<X>) { for (int k = 0; k < __builtin_vectorelements(X); k++) if (i < N) r[i++] = (T)x[k]; }
        else if constexpr (requires { X::__isim_packed_tag; }) { for (int k = 0; k < X::size; k++) if (i < N) r[i++] = (T)x[k]; }
        else if (i < N) r[i++] = (T)x;
    };
    (put(a), ...);
    if (i == 1) for (int k = 1; k < N; k++) r[k] = r[0];
    return r;
}

/* ---- packed vectors: no padding, elements by name and index ---- */
template <class T, int N> struct __isim_packed;
#define __ISIM_PACKED_COMMON(N) \
    static constexpr int size = N; static constexpr bool __isim_packed_tag = true; \
    __isim_packed() = default; \
    T &operator[](int i) { return (&x)[i]; } T operator[](int i) const { return (&x)[i]; } \
    operator vec<T, N>() const { vec<T, N> r; for (int i = 0; i < N; i++) r[i] = (&x)[i]; return r; } \
    __isim_packed(vec<T, N> v) { for (int i = 0; i < N; i++) (&x)[i] = v[i]; } \
    __isim_packed &operator=(vec<T, N> v) { for (int i = 0; i < N; i++) (&x)[i] = v[i]; return *this; }
template <class T> struct __isim_packed<T, 2> { T x, y; __ISIM_PACKED_COMMON(2) __isim_packed(T a, T b) : x(a), y(b) {} };
template <class T> struct __isim_packed<T, 3> { T x, y, z; __ISIM_PACKED_COMMON(3) __isim_packed(T a, T b, T c) : x(a), y(b), z(c) {} };
template <class T> struct __isim_packed<T, 4> {
    T x, y, z, w; __ISIM_PACKED_COMMON(4) __isim_packed(T a, T b, T c, T d) : x(a), y(b), z(c), w(d) {}
};
#undef __ISIM_PACKED_COMMON
#define __ISIM_PACKED(T, name) \
    typedef __isim_packed<T, 2> packed_##name##2; typedef __isim_packed<T, 3> packed_##name##3; typedef __isim_packed<T, 4> packed_##name##4;
__ISIM_PACKED(signed char, char) __ISIM_PACKED(unsigned char, uchar) __ISIM_PACKED(short, short) __ISIM_PACKED(unsigned short, ushort)
__ISIM_PACKED(int, int) __ISIM_PACKED(unsigned int, uint) __ISIM_PACKED(_Float16, half) __ISIM_PACKED(float, float)
#undef __ISIM_PACKED

/* ---- matrices: C columns of R rows, column-major like MSL (float3 columns take 16 bytes) ---- */
namespace metal {
template <class T, int C, int R> struct matrix {
    vec<T, R> columns[C];
    matrix() = default;
    explicit matrix(T d) { for (int c = 0; c < C; c++) { columns[c] = (vec<T, R>)0; if (c < R) columns[c][c] = d; } }
    template <class... V> requires (sizeof...(V) == C && C > 1 && (__isim_is_vec<V> && ...))
    matrix(V... cols) { int c = 0; ((columns[c++] = cols), ...); }
    template <class... S> requires (sizeof...(S) == C * R && (__isim_scalar<S> && ...))
    matrix(S... s) { T v[C * R] = {(T)s...}; for (int c = 0; c < C; c++) for (int r = 0; r < R; r++) columns[c][r] = v[c * R + r]; }
    template <class U> explicit matrix(const matrix<U, C, R> &m) {
        for (int c = 0; c < C; c++) for (int r = 0; r < R; r++) columns[c][r] = (T)m.columns[c][r];
    }
    vec<T, R> &operator[](int c) { return columns[c]; }
    const vec<T, R> &operator[](int c) const { return columns[c]; }
    matrix operator-() const { matrix m; for (int c = 0; c < C; c++) m.columns[c] = -columns[c]; return m; }
    matrix operator+(const matrix &o) const { matrix m; for (int c = 0; c < C; c++) m.columns[c] = columns[c] + o.columns[c]; return m; }
    matrix operator-(const matrix &o) const { matrix m; for (int c = 0; c < C; c++) m.columns[c] = columns[c] - o.columns[c]; return m; }
    matrix operator*(T s) const { matrix m; for (int c = 0; c < C; c++) m.columns[c] = columns[c] * s; return m; }
    friend matrix operator*(T s, const matrix &a) { return a * s; }
    matrix &operator+=(const matrix &o) { return *this = *this + o; }
    matrix &operator-=(const matrix &o) { return *this = *this - o; }
    matrix &operator*=(T s) { return *this = *this * s; }
    vec<T, R> operator*(vec<T, C> v) const { vec<T, R> r = (vec<T, R>)0; for (int c = 0; c < C; c++) r += columns[c] * v[c]; return r; }
    friend vec<T, C> operator*(vec<T, R> v, const matrix &m) {
        vec<T, C> r; for (int c = 0; c < C; c++) { T s = 0; for (int i = 0; i < R; i++) s += v[i] * m.columns[c][i]; r[c] = s; } return r;
    }
    template <int K> matrix<T, K, R> operator*(const matrix<T, K, C> &o) const {
        matrix<T, K, R> m; for (int k = 0; k < K; k++) m.columns[k] = *this * o.columns[k]; return m;
    }
    matrix &operator*=(const matrix<T, C, C> &o) requires (C == R) { return *this = *this * o; }
    bool operator==(const matrix &o) const {
        for (int c = 0; c < C; c++) for (int r = 0; r < R; r++) if (columns[c][r] != o.columns[c][r]) return false;
        return true;
    }
};
template <class T, int C, int R> inline matrix<T, R, C> transpose(const matrix<T, C, R> &m) {
    matrix<T, R, C> t; for (int c = 0; c < C; c++) for (int r = 0; r < R; r++) t.columns[r][c] = m.columns[c][r]; return t;
}
template <class T> inline T determinant(const matrix<T, 2, 2> &m) { return m[0][0] * m[1][1] - m[1][0] * m[0][1]; }
template <class T> inline T determinant(const matrix<T, 3, 3> &m) {
    return m[0][0] * (m[1][1] * m[2][2] - m[2][1] * m[1][2]) - m[1][0] * (m[0][1] * m[2][2] - m[2][1] * m[0][2])
         + m[2][0] * (m[0][1] * m[1][2] - m[1][1] * m[0][2]);
}
template <class T> inline T determinant(const matrix<T, 4, 4> &m) {
    T d = 0;
    for (int c = 0; c < 4; c++) {
        matrix<T, 3, 3> s;
        for (int cc = 0, k = 0; cc < 4; cc++) { if (cc == c) continue; for (int r = 1; r < 4; r++) s.columns[k][r - 1] = m[cc][r]; k++; }
        d += ((c & 1) ? -1 : 1) * m[c][0] * determinant(s);
    }
    return d;
}
}  // namespace metal
using metal::matrix;
#define __ISIM_MAT(T, name) \
    typedef metal::matrix<T, 2, 2> name##2x2; typedef metal::matrix<T, 2, 3> name##2x3; typedef metal::matrix<T, 2, 4> name##2x4; \
    typedef metal::matrix<T, 3, 2> name##3x2; typedef metal::matrix<T, 3, 3> name##3x3; typedef metal::matrix<T, 3, 4> name##3x4; \
    typedef metal::matrix<T, 4, 2> name##4x2; typedef metal::matrix<T, 4, 3> name##4x3; typedef metal::matrix<T, 4, 4> name##4x4;
__ISIM_MAT(float, float) __ISIM_MAT(_Float16, half)
#undef __ISIM_MAT

/* ---- constants ---- */
#define MAXFLOAT 0x1.fffffep127f
#define HUGE_VALF __builtin_huge_valf()
#define INFINITY __builtin_inff()
#define NAN __builtin_nanf("")
#define FLT_MAX 0x1.fffffep127f
#define FLT_MIN 0x1p-126f
#define FLT_EPSILON 0x1p-23f
#define FLT_DIG 6
#define FLT_MANT_DIG 24
#define HALF_MAX ((half)65504.0f)
#define HALF_MIN ((half)6.103515625e-05f)
#define HALF_EPSILON ((half)0.0009765625f)
#define CHAR_BIT 8
#define SCHAR_MAX 127
#define SCHAR_MIN (-128)
#define UCHAR_MAX 255
#define SHRT_MAX 32767
#define SHRT_MIN (-32768)
#define USHRT_MAX 65535
#define INT_MAX 2147483647
#define INT_MIN (-2147483647 - 1)
#define UINT_MAX 4294967295u
#define LONG_MAX 9223372036854775807l
#define LONG_MIN (-9223372036854775807l - 1)
#define ULONG_MAX 18446744073709551615ul
#define M_E_F 2.71828182845904523536028747135266250f
#define M_LOG2E_F 1.44269504088896340735992468100189214f
#define M_LOG10E_F 0.434294481903251827651128918916605082f
#define M_LN2_F 0.693147180559945309417232121458176568f
#define M_LN10_F 2.30258509299404568401799145468436421f
#define M_PI_F 3.14159265358979323846264338327950288f
#define M_PI_2_F 1.57079632679489661923132169163975144f
#define M_PI_4_F 0.785398163397448309615660845819875721f
#define M_1_PI_F 0.318309886183790671537767526745028724f
#define M_2_PI_F 0.636619772367581343075535053490057448f
#define M_2_SQRTPI_F 1.12837916709551257389615890312154517f
#define M_SQRT2_F 1.41421356237309504880168872420969808f
#define M_SQRT1_2_F 0.707106781186547524400844362104849039f
#define M_E_H ((half)M_E_F)
#define M_PI_H ((half)M_PI_F)
#define M_PI_2_H ((half)M_PI_2_F)
#define M_SQRT2_H ((half)M_SQRT2_F)

namespace metal {
template <class T> struct numeric_limits;
template <> struct numeric_limits<float> {
    static constexpr float min() { return FLT_MIN; } static constexpr float max() { return FLT_MAX; }
    static constexpr float lowest() { return -FLT_MAX; } static constexpr float epsilon() { return FLT_EPSILON; }
    static constexpr float infinity() { return __builtin_inff(); } static constexpr float quiet_NaN() { return __builtin_nanf(""); }
    static constexpr bool is_integer = false; static constexpr bool is_signed = true;
};
template <> struct numeric_limits<_Float16> {
    static constexpr _Float16 min() { return HALF_MIN; } static constexpr _Float16 max() { return HALF_MAX; }
    static constexpr _Float16 lowest() { return -HALF_MAX; } static constexpr _Float16 epsilon() { return HALF_EPSILON; }
    static constexpr _Float16 infinity() { return (_Float16)__builtin_inff(); }
    static constexpr _Float16 quiet_NaN() { return (_Float16)__builtin_nanf(""); }
    static constexpr bool is_integer = false; static constexpr bool is_signed = true;
};
#define __ISIM_ILIMITS(T, lo, hi, s) template <> struct numeric_limits<T> { \
    static constexpr T min() { return lo; } static constexpr T max() { return hi; } static constexpr T lowest() { return lo; } \
    static constexpr bool is_integer = true; static constexpr bool is_signed = s; };
__ISIM_ILIMITS(signed char, -128, 127, true) __ISIM_ILIMITS(unsigned char, 0, 255, false)
__ISIM_ILIMITS(short, -32768, 32767, true) __ISIM_ILIMITS(unsigned short, 0, 65535, false)
__ISIM_ILIMITS(int, INT_MIN, INT_MAX, true) __ISIM_ILIMITS(unsigned int, 0, UINT_MAX, false)
__ISIM_ILIMITS(long, LONG_MIN, LONG_MAX, true) __ISIM_ILIMITS(unsigned long, 0, ULONG_MAX, false)
#undef __ISIM_ILIMITS

template <class T, class U> inline T as_type(U v) { static_assert(sizeof(T) == sizeof(U), "as_type: sizes differ"); return __builtin_bit_cast(T, v); }

/* ---- element-wise helpers ---- */
template <class V, class F> inline V __map(V v, F f) {
    if constexpr (__isim_is_vec<V>) { V r; for (int i = 0; i < __builtin_vectorelements(V); i++) r[i] = f(v[i]); return r; }
    else return f(v);
}
template <class V, class F> inline V __map2(V a, V b, F f) {
    if constexpr (__isim_is_vec<V>) { V r; for (int i = 0; i < __builtin_vectorelements(V); i++) r[i] = f(a[i], b[i]); return r; }
    else return f(a, b);
}
template <class V, class F> inline V __map3(V a, V b, V c, F f) {
    if constexpr (__isim_is_vec<V>) { V r; for (int i = 0; i < __builtin_vectorelements(V); i++) r[i] = f(a[i], b[i], c[i]); return r; }
    else return f(a, b, c);
}
template <class T> concept __fv = __isim_float<__isim_elem<T>>;   /* float or half, scalar or vector */
template <class T> concept __iv = __isim_int<__isim_elem<T>>;
template <class T> concept __nv = __fv<T> || __iv<T>;

/* ---- math (float and half; half computes in float) ---- */
#define __ISIM_F1(name, expr) \
    inline float __##name##_f(float x) { return expr; } \
    template <__fv V> inline V name(V v) { return __map(v, [](__isim_elem<V> x) { return (__isim_elem<V>)__##name##_f((float)x); }); }
#define __ISIM_F2(name, expr) \
    inline float __##name##_f(float x, float y) { return expr; } \
    template <__fv V> inline V name(V a, V b) { return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { return (__isim_elem<V>)__##name##_f((float)x, (float)y); }); } \
    template <__fv V> requires __isim_is_vec<V> inline V name(V a, __isim_elem<V> b) { return name(a, (V)b); }
__ISIM_F1(acos, __builtin_acosf(x)) __ISIM_F1(acosh, __builtin_acoshf(x)) __ISIM_F1(asin, __builtin_asinf(x))
__ISIM_F1(asinh, __builtin_asinhf(x)) __ISIM_F1(atan, __builtin_atanf(x)) __ISIM_F1(atanh, __builtin_atanhf(x))
__ISIM_F1(ceil, __builtin_ceilf(x)) __ISIM_F1(cos, __builtin_cosf(x)) __ISIM_F1(cosh, __builtin_coshf(x))
__ISIM_F1(cospi, __builtin_cosf(x * M_PI_F)) __ISIM_F1(exp, __builtin_expf(x)) __ISIM_F1(exp2, __builtin_exp2f(x))
__ISIM_F1(exp10, __builtin_powf(10.0f, x)) __ISIM_F1(fabs, __builtin_fabsf(x)) __ISIM_F1(floor, __builtin_floorf(x))
__ISIM_F1(fract, __builtin_fminf(x - __builtin_floorf(x), 0x1.fffffep-1f)) __ISIM_F1(log, __builtin_logf(x))
__ISIM_F1(log2, __builtin_log2f(x)) __ISIM_F1(log10, __builtin_log10f(x)) __ISIM_F1(rint, __builtin_rintf(x))
__ISIM_F1(round, __builtin_roundf(x)) __ISIM_F1(rsqrt, 1.0f / __builtin_sqrtf(x)) __ISIM_F1(sin, __builtin_sinf(x))
__ISIM_F1(sinh, __builtin_sinhf(x)) __ISIM_F1(sinpi, __builtin_sinf(x * M_PI_F)) __ISIM_F1(sqrt, __builtin_sqrtf(x))
__ISIM_F1(tan, __builtin_tanf(x)) __ISIM_F1(tanh, __builtin_tanhf(x)) __ISIM_F1(tanpi, __builtin_tanf(x * M_PI_F))
__ISIM_F1(trunc, __builtin_truncf(x)) __ISIM_F1(saturate, __builtin_fminf(__builtin_fmaxf(x, 0.0f), 1.0f))
__ISIM_F1(sign, x > 0 ? 1.0f : x < 0 ? -1.0f : x == 0 ? 0.0f : 0.0f)
__ISIM_F2(atan2, __builtin_atan2f(x, y)) __ISIM_F2(copysign, __builtin_copysignf(x, y))
__ISIM_F2(fdim, __builtin_fdimf(x, y)) __ISIM_F2(fmax, __builtin_fmaxf(x, y)) __ISIM_F2(fmin, __builtin_fminf(x, y))
__ISIM_F2(fmod, __builtin_fmodf(x, y)) __ISIM_F2(pow, __builtin_powf(x, y)) __ISIM_F2(powr, __builtin_powf(x, y))
__ISIM_F2(nextafter, __builtin_nextafterf(x, y)) __ISIM_F2(step, y < x ? 0.0f : 1.0f) __ISIM_F2(divide, x / y)
#undef __ISIM_F1
#undef __ISIM_F2
template <__fv V> inline V fma(V a, V b, V c) {
    return __map3(a, b, c, [](__isim_elem<V> x, __isim_elem<V> y, __isim_elem<V> z) { return (__isim_elem<V>)__builtin_fmaf((float)x, (float)y, (float)z); });
}
template <__fv V> inline V mix(V x, V y, V a) { return x + (y - x) * a; }
template <__fv V> requires __isim_is_vec<V> inline V mix(V x, V y, __isim_elem<V> a) { return x + (y - x) * a; }
template <__fv V> inline V smoothstep(V e0, V e1, V x) {
    return __map3(e0, e1, x, [](__isim_elem<V> a, __isim_elem<V> b, __isim_elem<V> v) {
        float t = __saturate_f(((float)v - (float)a) / ((float)b - (float)a)); return (__isim_elem<V>)(t * t * (3.0f - 2.0f * t)); });
}
template <__fv V> requires __isim_is_vec<V> inline V smoothstep(__isim_elem<V> e0, __isim_elem<V> e1, V x) { return smoothstep((V)e0, (V)e1, x); }
template <__fv V> requires __isim_is_vec<V> inline V step(__isim_elem<V> e, V x) { return step((V)e, x); }
template <__fv V> inline V sincos(V x, V &c) { c = cos(x); return sin(x); }
template <__fv V> inline V modf(V x, V &ip) { ip = trunc(x); return x - ip; }
template <__fv V> inline V ldexp(V x, int e) { return __map(x, [e](__isim_elem<V> v) { return (__isim_elem<V>)__builtin_ldexpf((float)v, e); }); }
template <__fv V> inline V frexp(V x, int &e) { return (V)__builtin_frexpf((float)x, &e); }
inline int ilogb(float x) { return __builtin_ilogbf(x); }

/* ---- common: abs, min, max, clamp for floats and integers ---- */
template <__nv V> inline V abs(V v) {
    return __map(v, [](__isim_elem<V> x) { if constexpr (__isim_float<__isim_elem<V>>) return (__isim_elem<V>)__builtin_fabsf((float)x); else return x < 0 ? (__isim_elem<V>)-x : x; });
}
template <__nv V> inline V min(V a, V b) { return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { return y < x ? y : x; }); }
template <__nv V> inline V max(V a, V b) { return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { return x < y ? y : x; }); }
template <__nv V> requires __isim_is_vec<V> inline V min(V a, __isim_elem<V> b) { return min(a, (V)b); }
template <__nv V> requires __isim_is_vec<V> inline V max(V a, __isim_elem<V> b) { return max(a, (V)b); }
template <__nv V> inline V clamp(V x, V lo, V hi) { return min(max(x, lo), hi); }
template <__nv V> requires __isim_is_vec<V> inline V clamp(V x, __isim_elem<V> lo, __isim_elem<V> hi) { return clamp(x, (V)lo, (V)hi); }
template <__nv V> inline V min3(V a, V b, V c) { return min(min(a, b), c); }
template <__nv V> inline V max3(V a, V b, V c) { return max(max(a, b), c); }
template <__nv V> inline V median3(V a, V b, V c) { return max(min(a, b), min(max(a, b), c)); }
template <__fv V> inline V fmin3(V a, V b, V c) { return fmin(fmin(a, b), c); }
template <__fv V> inline V fmax3(V a, V b, V c) { return fmax(fmax(a, b), c); }
template <__fv V> inline V fmedian3(V a, V b, V c) { return median3(a, b, c); }

/* ---- integer ---- */
template <__iv V> inline V absdiff(V a, V b) { return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { return (__isim_elem<V>)(x > y ? x - y : y - x); }); }
template <__iv V> inline V popcount(V v) { return __map(v, [](__isim_elem<V> x) { return (__isim_elem<V>)__builtin_popcountll((unsigned long long)x & ((1ull << (8 * sizeof x - 1) << 1) - 1)); }); }
template <__iv V> inline V clz(V v) {
    return __map(v, [](__isim_elem<V> x) {
        using E = __isim_elem<V>; unsigned long long u = (unsigned long long)x & ((1ull << (8 * sizeof(E) - 1) << 1) - 1);
        return (E)(u ? __builtin_clzll(u) - (64 - 8 * sizeof(E)) : 8 * sizeof(E)); });
}
template <__iv V> inline V ctz(V v) {
    return __map(v, [](__isim_elem<V> x) { using E = __isim_elem<V>; unsigned long long u = (unsigned long long)x & ((1ull << (8 * sizeof(E) - 1) << 1) - 1); return (E)(u ? __builtin_ctzll(u) : 8 * sizeof(E)); });
}
template <__iv V> inline V reverse_bits(V v) {
    return __map(v, [](__isim_elem<V> x) { using E = __isim_elem<V>; unsigned long long u = (unsigned long long)x, r = 0;
        for (unsigned i = 0; i < 8 * sizeof(E); i++) r |= ((u >> i) & 1) << (8 * sizeof(E) - 1 - i); return (E)r; });
}
template <__iv V> inline V rotate(V v, V n) {
    return __map2(v, n, [](__isim_elem<V> x, __isim_elem<V> s) { using E = __isim_elem<V>; constexpr unsigned b = 8 * sizeof(E);
        using U = __make_unsigned(E); U u = (U)x; unsigned k = (unsigned)s % b; return (E)(k ? (U)(u << k | u >> (b - k)) : u); });
}
template <__iv V> inline V mulhi(V a, V b) {
    return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { using E = __isim_elem<V>;
        if constexpr (sizeof(E) == 8) return (E)(((__int128)x * (__int128)y) >> 64); else return (E)(((long)x * (long)y) >> (8 * sizeof(E))); });
}
template <__iv V> inline V mul24(V a, V b) { return a * b; }
template <__iv V> inline V mad24(V a, V b, V c) { return a * b + c; }
template <__iv V> inline V madhi(V a, V b, V c) { return mulhi(a, b) + c; }
template <__iv V> inline V hadd(V a, V b) { return (a >> 1) + (b >> 1) + (a & b & 1); }
template <__iv V> inline V rhadd(V a, V b) { return (a >> 1) + (b >> 1) + ((a | b) & 1); }
template <__iv V> inline V addsat(V a, V b) {
    return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { using E = __isim_elem<V>; E r; return __builtin_add_overflow(x, y, &r) ? (y > 0 ? numeric_limits<E>::max() : numeric_limits<E>::min()) : r; });
}
template <__iv V> inline V subsat(V a, V b) {
    return __map2(a, b, [](__isim_elem<V> x, __isim_elem<V> y) { using E = __isim_elem<V>; E r; return __builtin_sub_overflow(x, y, &r) ? (y < 0 ? numeric_limits<E>::max() : numeric_limits<E>::min()) : r; });
}
template <__iv V> inline V madsat(V a, V b, V c) { return addsat(a * b, c); }
template <__iv V> inline V extract_bits(V x, uint offset, uint bits) {
    return __map(x, [=](__isim_elem<V> v) { using E = __isim_elem<V>; using U = __make_unsigned(E);
        if (bits == 0) return (E)0; U u = (U)((U)v << (8 * sizeof(E) - offset - bits));
        if constexpr ((E)-1 < 0) return (E)((E)u >> (8 * sizeof(E) - bits)); else return (E)(u >> (8 * sizeof(E) - bits)); });
}
template <__iv V> inline V insert_bits(V base, V ins, uint offset, uint bits) {
    return __map2(base, ins, [=](__isim_elem<V> b, __isim_elem<V> i) { using E = __isim_elem<V>; using U = __make_unsigned(E);
        U mask = bits >= 8 * sizeof(E) ? (U)~(U)0 : (U)(((U)1 << bits) - 1); mask = (U)(mask << offset);
        return (E)(((U)b & ~mask) | (((U)i << offset) & mask)); });
}

/* ---- geometric ---- */
template <__fv V> inline __isim_elem<V> dot(V a, V b) {
    if constexpr (__isim_is_vec<V>) { float s = 0; for (int i = 0; i < __builtin_vectorelements(V); i++) s += (float)a[i] * (float)b[i]; return (__isim_elem<V>)s; }
    else return a * b;
}
template <__fv V> inline __isim_elem<V> length_squared(V v) { return dot(v, v); }
template <__fv V> inline __isim_elem<V> length(V v) { return (__isim_elem<V>)__builtin_sqrtf((float)dot(v, v)); }
template <__fv V> inline __isim_elem<V> distance(V a, V b) { return length(a - b); }
template <__fv V> inline __isim_elem<V> distance_squared(V a, V b) { return length_squared(a - b); }
template <__fv V> inline V normalize(V v) { return v * (__isim_elem<V>)(1.0f / __builtin_sqrtf((float)dot(v, v))); }
template <__fv V> requires (__isim_n<V>() == 3) inline V cross(V a, V b) { return a.yzx * b.zxy - a.zxy * b.yzx; }
template <__fv V> inline V faceforward(V n, V i, V nref) { return dot(nref, i) < 0 ? n : -n; }
template <__fv V> inline V reflect(V i, V n) { return i - (__isim_elem<V>)2 * dot(n, i) * n; }
template <__fv V> inline V refract(V i, V n, __isim_elem<V> eta) {
    __isim_elem<V> d = dot(n, i), k = (__isim_elem<V>)1 - eta * eta * ((__isim_elem<V>)1 - d * d);
    return k < 0 ? (V)0 : eta * i - (eta * d + (__isim_elem<V>)__builtin_sqrtf((float)k)) * n;
}

/* ---- relational: comparisons of vectors give masks (-1 or 0 per component) ---- */
template <class V> inline bool all(V v) { if constexpr (__isim_is_vec<V>) { for (int i = 0; i < __builtin_vectorelements(V); i++) if (!v[i]) return false; return true; } else return (bool)v; }
template <class V> inline bool any(V v) { if constexpr (__isim_is_vec<V>) { for (int i = 0; i < __builtin_vectorelements(V); i++) if (v[i]) return true; return false; } else return (bool)v; }
template <class V, class M> inline V select(V a, V b, M c) {
    if constexpr (__isim_is_vec<V>) { V r; for (int i = 0; i < __builtin_vectorelements(V); i++) { bool s; if constexpr (__isim_is_vec<M>) s = c[i]; else s = c; r[i] = s ? b[i] : a[i]; } return r; }
    else return c ? b : a;
}
template <__fv V> inline auto isnan(V v) { if constexpr (__isim_is_vec<V>) return v != v; else return v != v; }
template <__fv V> inline auto isinf(V v) { if constexpr (__isim_is_vec<V>) return __builtin_elementwise_abs(v) == (V)__builtin_inff(); else return __builtin_fabsf((float)v) == __builtin_inff(); }
template <__fv V> inline auto isfinite(V v) { if constexpr (__isim_is_vec<V>) return !(isnan(v) | isinf(v)); else return !(isnan(v) || isinf(v)); }
template <__fv V> inline auto isnormal(V v) { return __map(v, [](__isim_elem<V> x) { return (__isim_elem<V>)__builtin_isnormal((float)x); }) != (V)0; }
template <__fv V> inline auto isordered(V a, V b) { return (a == a) & (b == b); }
template <__fv V> inline auto isunordered(V a, V b) { return !isordered(a, b); }
template <__fv V> inline auto signbit(V v) { return __map(v, [](__isim_elem<V> x) { return (__isim_elem<V>)__builtin_signbit((float)x); }) != (V)0; }

/* ---- packing ---- */
inline uint pack_float_to_unorm4x8(float4 v) {
    uint4 u = __builtin_convertvector(__builtin_elementwise_round(clamp(v, 0.0f, 1.0f) * 255.0f), uint4);
    return u.x | u.y << 8 | u.z << 16 | u.w << 24;
}
inline uint pack_float_to_snorm4x8(float4 v) {
    int4 s = __builtin_convertvector(__builtin_elementwise_round(clamp(v, -1.0f, 1.0f) * 127.0f), int4);
    return (uint)(s.x & 255) | (uint)(s.y & 255) << 8 | (uint)(s.z & 255) << 16 | (uint)(s.w & 255) << 24;
}
inline uint pack_float_to_unorm2x16(float2 v) {
    uint2 u = __builtin_convertvector(__builtin_elementwise_round(clamp(v, 0.0f, 1.0f) * 65535.0f), uint2); return u.x | u.y << 16;
}
inline uint pack_float_to_snorm2x16(float2 v) {
    int2 s = __builtin_convertvector(__builtin_elementwise_round(clamp(v, -1.0f, 1.0f) * 32767.0f), int2);
    return (uint)(s.x & 0xffff) | (uint)(s.y & 0xffff) << 16;
}
inline float4 unpack_unorm4x8_to_float(uint p) { return float4{(float)(p & 255), (float)(p >> 8 & 255), (float)(p >> 16 & 255), (float)(p >> 24)} / 255.0f; }
inline float4 unpack_snorm4x8_to_float(uint p) {
    float4 f = {(float)(signed char)(p & 255), (float)(signed char)(p >> 8 & 255), (float)(signed char)(p >> 16 & 255), (float)(signed char)(p >> 24)};
    return clamp(f / 127.0f, -1.0f, 1.0f);
}
inline float2 unpack_unorm2x16_to_float(uint p) { return float2{(float)(p & 0xffff), (float)(p >> 16)} / 65535.0f; }
inline float2 unpack_snorm2x16_to_float(uint p) { return clamp(float2{(float)(short)(p & 0xffff), (float)(short)(p >> 16)} / 32767.0f, -1.0f, 1.0f); }
inline half4 unpack_unorm4x8_to_half(uint p) { return __builtin_convertvector(unpack_unorm4x8_to_float(p), half4); }
inline uint pack_half_to_unorm4x8(half4 v) { return pack_float_to_unorm4x8(__builtin_convertvector(v, float4)); }

namespace fast { using namespace metal; }
namespace precise { using namespace metal; }
}  // namespace metal

/* ---- atomics: relaxed, on device and threadgroup memory ---- */
namespace metal {
enum memory_order { memory_order_relaxed, memory_order_seq_cst = 5 };
enum class thread_scope { thread, simdgroup, threadgroup, device };
template <class T> struct _atomic { T __v; };
template <class T> using atomic = _atomic<T>;
typedef _atomic<int> atomic_int;
typedef _atomic<uint> atomic_uint;
typedef _atomic<bool> atomic_bool;
typedef _atomic<float> atomic_float;
typedef _atomic<ulong> atomic_ulong;
typedef _atomic<long> atomic_long;
template <class T> inline void atomic_store_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { __atomic_store((T *)&o->__v, &v, __ATOMIC_SEQ_CST); }
template <class T> inline T atomic_load_explicit(volatile _atomic<T> *o, memory_order = memory_order_relaxed) { T r; __atomic_load((T *)&o->__v, &r, __ATOMIC_SEQ_CST); return r; }
template <class T> inline T atomic_exchange_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { T r; __atomic_exchange((T *)&o->__v, &v, &r, __ATOMIC_SEQ_CST); return r; }
template <class T> inline bool atomic_compare_exchange_weak_explicit(volatile _atomic<T> *o, T *expected, T desired, memory_order = memory_order_relaxed, memory_order = memory_order_relaxed) {
    return __atomic_compare_exchange((T *)&o->__v, expected, &desired, false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
}
template <class T> inline bool atomic_compare_exchange_strong_explicit(volatile _atomic<T> *o, T *expected, T desired, memory_order a = memory_order_relaxed, memory_order b = memory_order_relaxed) {
    return atomic_compare_exchange_weak_explicit(o, expected, desired, a, b);
}
template <class T, class F> inline T __atomic_rmw(volatile _atomic<T> *o, F f) {
    T old; __atomic_load((T *)&o->__v, &old, __ATOMIC_RELAXED);
    T next = f(old);
    while (!__atomic_compare_exchange((T *)&o->__v, &old, &next, true, __ATOMIC_SEQ_CST, __ATOMIC_RELAXED)) next = f(old);
    return old;
}
template <class T> inline T atomic_fetch_add_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) {
    if constexpr (__isim_float<T>) return __atomic_rmw(o, [v](T x) { return x + v; }); else return __atomic_fetch_add((T *)&o->__v, v, __ATOMIC_SEQ_CST);
}
template <class T> inline T atomic_fetch_sub_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) {
    if constexpr (__isim_float<T>) return __atomic_rmw(o, [v](T x) { return x - v; }); else return __atomic_fetch_sub((T *)&o->__v, v, __ATOMIC_SEQ_CST);
}
template <class T> inline T atomic_fetch_and_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { return __atomic_fetch_and((T *)&o->__v, v, __ATOMIC_SEQ_CST); }
template <class T> inline T atomic_fetch_or_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { return __atomic_fetch_or((T *)&o->__v, v, __ATOMIC_SEQ_CST); }
template <class T> inline T atomic_fetch_xor_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { return __atomic_fetch_xor((T *)&o->__v, v, __ATOMIC_SEQ_CST); }
template <class T> inline T atomic_fetch_min_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { return __atomic_rmw(o, [v](T x) { return v < x ? v : x; }); }
template <class T> inline T atomic_fetch_max_explicit(volatile _atomic<T> *o, T v, memory_order = memory_order_relaxed) { return __atomic_rmw(o, [v](T x) { return x < v ? v : x; }); }
/* the same on a plain object, for code that passes a non-volatile pointer */
#define __ISIM_ATOMIC_NV(op) template <class T, class... A> inline auto atomic_##op##_explicit(_atomic<T> *o, A... a) { return atomic_##op##_explicit((volatile _atomic<T> *)o, a...); }
__ISIM_ATOMIC_NV(store) __ISIM_ATOMIC_NV(load) __ISIM_ATOMIC_NV(exchange) __ISIM_ATOMIC_NV(compare_exchange_weak) __ISIM_ATOMIC_NV(compare_exchange_strong)
__ISIM_ATOMIC_NV(fetch_add) __ISIM_ATOMIC_NV(fetch_sub) __ISIM_ATOMIC_NV(fetch_and) __ISIM_ATOMIC_NV(fetch_or) __ISIM_ATOMIC_NV(fetch_xor)
__ISIM_ATOMIC_NV(fetch_min) __ISIM_ATOMIC_NV(fetch_max)
#undef __ISIM_ATOMIC_NV
inline void atomic_thread_fence(int, memory_order = memory_order_relaxed, thread_scope = thread_scope::device) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }
}  // namespace metal

/* ---- the running dispatch, barriers and SIMD groups (width 1) ---- */
extern thread_local const __isim_mtl_args *__isim_mtl_cur;
namespace metal {
enum class mem_flags { mem_none = 0, mem_device = 1, mem_threadgroup = 2, mem_texture = 4, mem_threadgroup_imageblock = 8, mem_object_data = 16 };
constexpr mem_flags operator|(mem_flags a, mem_flags b) { return (mem_flags)((int)a | (int)b); }
inline void threadgroup_barrier(mem_flags = mem_flags::mem_none) {
    __atomic_thread_fence(__ATOMIC_SEQ_CST);
    if (__isim_mtl_cur && __isim_mtl_cur->barrier) __isim_mtl_cur->barrier(__isim_mtl_cur->sched);
}
inline void simdgroup_barrier(mem_flags = mem_flags::mem_none) { __atomic_thread_fence(__ATOMIC_SEQ_CST); }
struct simd_vote {
    ulong v; simd_vote(ulong x = 0) : v(x) {}
    explicit operator ulong() const { return v; } bool all() const { return v & 1; } bool any() const { return v & 1; }
};
template <class T> inline T simd_sum(T x) { return x; }
template <class T> inline T simd_product(T x) { return x; }
template <class T> inline T simd_min(T x) { return x; }
template <class T> inline T simd_max(T x) { return x; }
template <class T> inline T simd_and(T x) { return x; }
template <class T> inline T simd_or(T x) { return x; }
template <class T> inline T simd_xor(T x) { return x; }
template <class T> inline T simd_prefix_inclusive_sum(T x) { return x; }
template <class T> inline T simd_prefix_exclusive_sum(T x) { return (T)0; }
template <class T> inline T simd_prefix_inclusive_product(T x) { return x; }
template <class T> inline T simd_prefix_exclusive_product(T x) { return (T)1; }
template <class T> inline T simd_broadcast(T x, ushort) { return x; }
template <class T> inline T simd_broadcast_first(T x) { return x; }
template <class T> inline T simd_shuffle(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_up(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_down(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_xor(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_rotate_up(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_rotate_down(T x, ushort) { return x; }
template <class T> inline T simd_shuffle_and_fill_up(T x, T, ushort) { return x; }
template <class T> inline T simd_shuffle_and_fill_down(T x, T, ushort) { return x; }
inline simd_vote simd_ballot(bool b) { return simd_vote(b ? 1 : 0); }
inline simd_vote simd_active_threads_mask() { return simd_vote(1); }
inline bool simd_all(bool b) { return b; }
inline bool simd_any(bool b) { return b; }
inline bool simd_is_first() { return true; }
inline bool simd_is_helper_thread() { return false; }
}  // namespace metal

/* ---- samplers ---- */
namespace metal {
enum class coord { normalized, pixel };
enum class filter { nearest, linear };
enum class mag_filter { nearest, linear };
enum class min_filter { nearest, linear };
enum class mip_filter { none, nearest, linear };
enum class address { clamp_to_edge, mirrored_clamp_to_edge, repeat, mirrored_repeat, clamp_to_zero, clamp_to_border };
enum class s_address { clamp_to_edge, mirrored_clamp_to_edge, repeat, mirrored_repeat, clamp_to_zero, clamp_to_border };
enum class t_address { clamp_to_edge, mirrored_clamp_to_edge, repeat, mirrored_repeat, clamp_to_zero, clamp_to_border };
enum class r_address { clamp_to_edge, mirrored_clamp_to_edge, repeat, mirrored_repeat, clamp_to_zero, clamp_to_border };
enum class border_color { transparent_black, opaque_black, opaque_white };
enum class compare_func { none, less, less_equal, greater, greater_equal, equal, not_equal, always, never };
struct max_anisotropy { int v; constexpr max_anisotropy(int x) : v(x) {} };
struct lod_clamp { float lo, hi; constexpr lod_clamp(float a, float b) : lo(a), hi(b) {} };
struct sampler {
    unsigned char minf = 0, magf = 0, mipf = 0, s = 0, t = 0, r = 0, norm = 1, border = 0;
    float lodmin = 0, lodmax = 1000;
    constexpr sampler() {}
    template <class... A> constexpr sampler(A... a) { (set(a), ...); }
    explicit sampler(const __isim_mtl_sampler *d) {
        if (d) { minf = d->min_filter; magf = d->mag_filter; mipf = d->mip_filter; s = d->s_address; t = d->t_address;
                 r = d->r_address; norm = d->normalized; border = d->border; lodmin = d->lod_min; lodmax = d->lod_max; }
    }
    constexpr void set(coord c) { norm = c == coord::normalized; }
    constexpr void set(filter f) { minf = magf = (unsigned char)f; }
    constexpr void set(mag_filter f) { magf = (unsigned char)f; }
    constexpr void set(min_filter f) { minf = (unsigned char)f; }
    constexpr void set(mip_filter f) { mipf = (unsigned char)f; }
    constexpr void set(address a) { s = t = r = (unsigned char)a; }
    constexpr void set(s_address a) { s = (unsigned char)a; }
    constexpr void set(t_address a) { t = (unsigned char)a; }
    constexpr void set(r_address a) { r = (unsigned char)a; }
    constexpr void set(border_color b) { border = (unsigned char)b; }
    constexpr void set(compare_func) {}
    constexpr void set(max_anisotropy) {}
    constexpr void set(lod_clamp l) { lodmin = l.lo; lodmax = l.hi; }
};
struct level { float v; constexpr level(float x) : v(x) {} };
struct bias { float v; constexpr bias(float x) : v(x) {} };
struct min_lod_clamp { float v; constexpr min_lod_clamp(float x) : v(x) {} };
enum class access { sample, read, write, read_write };
}  // namespace metal

/* ---- texels: pixel formats (MTLPixelFormat) to and from float4 / int4 / uint4 ---- */
namespace __isim_tx {
inline float srgb_to_linear(float c) { return c <= 0.04045f ? c / 12.92f : __builtin_powf((c + 0.055f) / 1.055f, 2.4f); }
inline float linear_to_srgb(float c) { c = c < 0 ? 0 : c > 1 ? 1 : c; return c <= 0.0031308f ? c * 12.92f : 1.055f * __builtin_powf(c, 1 / 2.4f) - 0.055f; }
inline unsigned unorm(float v, unsigned max) { v = v != v ? 0 : v < 0 ? 0 : v > 1 ? 1 : v; return (unsigned)(v * max + 0.5f); }
inline int snorm(float v, int max) { v = v != v ? 0 : v < -1 ? -1 : v > 1 ? 1 : v; return (int)__builtin_roundf(v * max); }
inline float snf(int v, int max) { float f = (float)v / max; return f < -1 ? -1 : f; }
inline int bpp(uint32_t f) {
    switch (f) {
    case 1: case 10: case 11: case 12: case 13: case 14: return 1;
    case 20: case 22: case 23: case 24: case 25: case 30: case 31: case 32: case 33: case 34: case 40: case 41: case 42: case 43: case 250: return 2;
    case 53: case 54: case 55: case 60: case 62: case 63: case 64: case 65: case 70: case 71: case 72: case 73: case 74: case 80: case 81:
    case 90: case 91: case 92: case 93: case 94: case 252: case 554: case 555: return 4;
    case 103: case 104: case 105: case 110: case 112: case 113: case 114: case 115: case 552: case 553: return 8;
    case 123: case 124: case 125: return 16;
    default: return 4;
    }
}
template <class T> inline T rd(const uint8_t *p) { T v; __builtin_memcpy(&v, p, sizeof v); return v; }
template <class T> inline void wr(uint8_t *p, T v) { __builtin_memcpy(p, &v, sizeof v); }
inline float half_f(uint16_t h) { return (float)__builtin_bit_cast(_Float16, h); }
inline uint16_t f_half(float f) { return __builtin_bit_cast(uint16_t, (_Float16)f); }
/* normalized and float formats as float4 (missing components: 0, alpha 1) */
inline float4 load_f(uint32_t f, const uint8_t *p) {
    switch (f) {
    case 1: return float4{0, 0, 0, p[0] / 255.0f};
    case 10: return float4{p[0] / 255.0f, 0, 0, 1};
    case 11: return float4{srgb_to_linear(p[0] / 255.0f), 0, 0, 1};
    case 12: return float4{snf((signed char)p[0], 127), 0, 0, 1};
    case 20: return float4{rd<uint16_t>(p) / 65535.0f, 0, 0, 1};
    case 22: return float4{snf(rd<int16_t>(p), 32767), 0, 0, 1};
    case 25: return float4{half_f(rd<uint16_t>(p)), 0, 0, 1};
    case 30: return float4{p[0] / 255.0f, p[1] / 255.0f, 0, 1};
    case 31: return float4{srgb_to_linear(p[0] / 255.0f), srgb_to_linear(p[1] / 255.0f), 0, 1};
    case 32: return float4{snf((signed char)p[0], 127), snf((signed char)p[1], 127), 0, 1};
    case 40: { uint16_t v = rd<uint16_t>(p); return float4{(v >> 11) / 31.0f, (v >> 5 & 63) / 63.0f, (v & 31) / 31.0f, 1}; }
    case 55: return float4{rd<float>(p), 0, 0, 1};
    case 60: return float4{rd<uint16_t>(p) / 65535.0f, rd<uint16_t>(p + 2) / 65535.0f, 0, 1};
    case 62: return float4{snf(rd<int16_t>(p), 32767), snf(rd<int16_t>(p + 2), 32767), 0, 1};
    case 65: return float4{half_f(rd<uint16_t>(p)), half_f(rd<uint16_t>(p + 2)), 0, 1};
    case 70: return float4{p[0] / 255.0f, p[1] / 255.0f, p[2] / 255.0f, p[3] / 255.0f};
    case 71: return float4{srgb_to_linear(p[0] / 255.0f), srgb_to_linear(p[1] / 255.0f), srgb_to_linear(p[2] / 255.0f), p[3] / 255.0f};
    case 72: return float4{snf((signed char)p[0], 127), snf((signed char)p[1], 127), snf((signed char)p[2], 127), snf((signed char)p[3], 127)};
    case 80: return float4{p[2] / 255.0f, p[1] / 255.0f, p[0] / 255.0f, p[3] / 255.0f};
    case 81: return float4{srgb_to_linear(p[2] / 255.0f), srgb_to_linear(p[1] / 255.0f), srgb_to_linear(p[0] / 255.0f), p[3] / 255.0f};
    case 90: { uint32_t v = rd<uint32_t>(p); return float4{(v & 1023) / 1023.0f, (v >> 10 & 1023) / 1023.0f, (v >> 20 & 1023) / 1023.0f, (v >> 30) / 3.0f}; }
    case 94: { uint32_t v = rd<uint32_t>(p); return float4{(v >> 20 & 1023) / 1023.0f, (v >> 10 & 1023) / 1023.0f, (v & 1023) / 1023.0f, (v >> 30) / 3.0f}; }
    case 105: return float4{rd<float>(p), rd<float>(p + 4), 0, 1};
    case 110: return float4{rd<uint16_t>(p) / 65535.0f, rd<uint16_t>(p + 2) / 65535.0f, rd<uint16_t>(p + 4) / 65535.0f, rd<uint16_t>(p + 6) / 65535.0f};
    case 112: return float4{snf(rd<int16_t>(p), 32767), snf(rd<int16_t>(p + 2), 32767), snf(rd<int16_t>(p + 4), 32767), snf(rd<int16_t>(p + 6), 32767)};
    case 115: return float4{half_f(rd<uint16_t>(p)), half_f(rd<uint16_t>(p + 2)), half_f(rd<uint16_t>(p + 4)), half_f(rd<uint16_t>(p + 6))};
    case 125: return float4{rd<float>(p), rd<float>(p + 4), rd<float>(p + 8), rd<float>(p + 12)};
    case 250: return float4{rd<uint16_t>(p) / 65535.0f, 0, 0, 1};
    case 252: return float4{rd<float>(p), 0, 0, 1};
    default: return float4{0, 0, 0, 1};
    }
}
inline void store_f(uint32_t f, uint8_t *p, float4 c) {
    switch (f) {
    case 1: p[0] = unorm(c.w, 255); break;
    case 10: p[0] = unorm(c.x, 255); break;
    case 11: p[0] = unorm(linear_to_srgb(c.x), 255); break;
    case 12: p[0] = (uint8_t)snorm(c.x, 127); break;
    case 20: wr<uint16_t>(p, unorm(c.x, 65535)); break;
    case 22: wr<int16_t>(p, snorm(c.x, 32767)); break;
    case 25: wr<uint16_t>(p, f_half(c.x)); break;
    case 30: p[0] = unorm(c.x, 255); p[1] = unorm(c.y, 255); break;
    case 31: p[0] = unorm(linear_to_srgb(c.x), 255); p[1] = unorm(linear_to_srgb(c.y), 255); break;
    case 32: p[0] = (uint8_t)snorm(c.x, 127); p[1] = (uint8_t)snorm(c.y, 127); break;
    case 40: wr<uint16_t>(p, (uint16_t)(unorm(c.x, 31) << 11 | unorm(c.y, 63) << 5 | unorm(c.z, 31))); break;
    case 55: wr<float>(p, c.x); break;
    case 60: wr<uint16_t>(p, unorm(c.x, 65535)); wr<uint16_t>(p + 2, unorm(c.y, 65535)); break;
    case 62: wr<int16_t>(p, snorm(c.x, 32767)); wr<int16_t>(p + 2, snorm(c.y, 32767)); break;
    case 65: wr<uint16_t>(p, f_half(c.x)); wr<uint16_t>(p + 2, f_half(c.y)); break;
    case 70: p[0] = unorm(c.x, 255); p[1] = unorm(c.y, 255); p[2] = unorm(c.z, 255); p[3] = unorm(c.w, 255); break;
    case 71: p[0] = unorm(linear_to_srgb(c.x), 255); p[1] = unorm(linear_to_srgb(c.y), 255); p[2] = unorm(linear_to_srgb(c.z), 255); p[3] = unorm(c.w, 255); break;
    case 72: p[0] = (uint8_t)snorm(c.x, 127); p[1] = (uint8_t)snorm(c.y, 127); p[2] = (uint8_t)snorm(c.z, 127); p[3] = (uint8_t)snorm(c.w, 127); break;
    case 80: p[0] = unorm(c.z, 255); p[1] = unorm(c.y, 255); p[2] = unorm(c.x, 255); p[3] = unorm(c.w, 255); break;
    case 81: p[0] = unorm(linear_to_srgb(c.z), 255); p[1] = unorm(linear_to_srgb(c.y), 255); p[2] = unorm(linear_to_srgb(c.x), 255); p[3] = unorm(c.w, 255); break;
    case 90: wr<uint32_t>(p, unorm(c.x, 1023) | unorm(c.y, 1023) << 10 | unorm(c.z, 1023) << 20 | unorm(c.w, 3) << 30); break;
    case 94: wr<uint32_t>(p, unorm(c.z, 1023) | unorm(c.y, 1023) << 10 | unorm(c.x, 1023) << 20 | unorm(c.w, 3) << 30); break;
    case 105: wr<float>(p, c.x); wr<float>(p + 4, c.y); break;
    case 110: for (int i = 0; i < 4; i++) wr<uint16_t>(p + 2 * i, unorm(c[i], 65535)); break;
    case 112: for (int i = 0; i < 4; i++) wr<int16_t>(p + 2 * i, snorm(c[i], 32767)); break;
    case 115: for (int i = 0; i < 4; i++) wr<uint16_t>(p + 2 * i, f_half(c[i])); break;
    case 125: for (int i = 0; i < 4; i++) wr<float>(p + 4 * i, c[i]); break;
    case 250: wr<uint16_t>(p, unorm(c.x, 65535)); break;
    case 252: wr<float>(p, c.x); break;
    default: break;
    }
}
/* integer formats as uint4 / int4 (the bits; signedness by the caller's type) */
inline int nchan(uint32_t f) {
    switch (f) {
    case 13: case 14: case 23: case 24: case 53: case 54: return 1;
    case 33: case 34: case 63: case 64: case 103: case 104: return 2;
    default: return 4;
    }
}
inline bool sint(uint32_t f) { return f == 14 || f == 24 || f == 34 || f == 54 || f == 64 || f == 74 || f == 104 || f == 114 || f == 124; }
inline int csize(uint32_t f) {
    switch (f) {
    case 13: case 14: case 33: case 34: case 73: case 74: return 1;
    case 23: case 24: case 63: case 64: case 113: case 114: return 2;
    default: return 4;
    }
}
inline int4 load_i(uint32_t f, const uint8_t *p) {
    if (f == 91) { uint32_t v = rd<uint32_t>(p); return int4{(int)(v & 1023), (int)(v >> 10 & 1023), (int)(v >> 20 & 1023), (int)(v >> 30)}; }
    int n = nchan(f), cs = csize(f); bool s = sint(f); int4 r = {0, 0, 0, 1};
    for (int i = 0; i < n; i++) {
        const uint8_t *q = p + i * cs;
        r[i] = cs == 1 ? (s ? (int)(signed char)q[0] : (int)q[0]) : cs == 2 ? (s ? (int)rd<int16_t>(q) : (int)rd<uint16_t>(q)) : rd<int>(q);
    }
    return r;
}
inline void store_i(uint32_t f, uint8_t *p, int4 v) {
    if (f == 91) { wr<uint32_t>(p, (uint32_t)(v.x & 1023) | (uint32_t)(v.y & 1023) << 10 | (uint32_t)(v.z & 1023) << 20 | (uint32_t)(v.w & 3) << 30); return; }
    int n = nchan(f), cs = csize(f);
    for (int i = 0; i < n; i++) {
        uint8_t *q = p + i * cs;
        if (cs == 1) q[0] = (uint8_t)v[i]; else if (cs == 2) wr<uint16_t>(q, (uint16_t)v[i]); else wr<int>(q, v[i]);
    }
}
inline bool is_int(uint32_t f) {
    switch (f) {
    case 13: case 14: case 23: case 24: case 33: case 34: case 53: case 54: case 63: case 64: case 73: case 74: case 91:
    case 103: case 104: case 113: case 114: case 123: case 124: return true;
    default: return false;
    }
}
inline const uint8_t *at(const __isim_mtl_texture *t, uint32_t x, uint32_t y, uint32_t z, uint32_t lod) {
    if (lod >= t->mip_levels) lod = t->mip_levels ? t->mip_levels - 1 : 0;
    return t->levels[lod] + (size_t)z * t->level_bpi[lod] + (size_t)y * t->level_bpr[lod] + (size_t)x * bpp(t->format);
}
inline uint32_t dim(uint32_t d, uint32_t lod) { d >>= lod; return d ? d : 1; }
template <class T> inline vec<T, 4> load(const __isim_mtl_texture *t, uint32_t x, uint32_t y, uint32_t z, uint32_t lod) {
    if (!t || x >= dim(t->width, lod) || y >= dim(t->height, lod)) return vec<T, 4>{0, 0, 0, 0};
    const uint8_t *p = at(t, x, y, z, lod);
    if constexpr (__isim_float<T>) return __builtin_convertvector(load_f(t->format, p), vec<T, 4>);
    else return __builtin_convertvector(load_i(t->format, p), vec<T, 4>);
}
template <class T> inline void store(const __isim_mtl_texture *t, vec<T, 4> v, uint32_t x, uint32_t y, uint32_t z, uint32_t lod) {
    if (!t || x >= dim(t->width, lod) || y >= dim(t->height, lod)) return;
    uint8_t *p = (uint8_t *)at(t, x, y, z, lod);
    if constexpr (__isim_float<T>) store_f(t->format, p, __builtin_convertvector(v, float4));
    else store_i(t->format, p, __builtin_convertvector(v, int4));
}
/* a sampler's addressing: the texel index for coordinate i in [0, n), or -1 for a border texel */
inline int address(int i, int n, int mode) {
    switch (mode) {
    case 2: i %= n; return i < 0 ? i + n : i;                                     /* repeat */
    case 3: { int p = 2 * n; i %= p; if (i < 0) i += p; return i < n ? i : p - 1 - i; }   /* mirrored repeat */
    case 1: if (i < 0) i = -1 - i; return i < n ? i : n - 1;                          /* mirrored clamp to edge */
    case 4: case 5: return i < 0 || i >= n ? -1 : i;                                  /* clamp to zero / border */
    default: return i < 0 ? 0 : i >= n ? n - 1 : i;                                  /* clamp to edge */
    }
}
template <class T> inline vec<T, 4> texel(const __isim_mtl_texture *t, int x, int y, uint32_t z, uint32_t lod, const metal::sampler &s) {
    int w = (int)dim(t->width, lod), h = (int)dim(t->height, lod);
    int ax = address(x, w, s.s), ay = address(y, h, s.t);
    if (ax < 0 || ay < 0) {
        float a = s.border == 0 || s.s == 4 || s.t == 4 ? 0 : 1, c = s.border == 2 ? 1 : 0;
        return vec<T, 4>{(T)c, (T)c, (T)c, (T)a};
    }
    return load<T>(t, ax, ay, z, lod);
}
template <class T> inline vec<T, 4> sample2d(const __isim_mtl_texture *t, const metal::sampler &s, float2 c, uint32_t z, float lod) {
    if (!t) return vec<T, 4>{0, 0, 0, 0};
    uint32_t l = 0;
    if (s.mipf != 0 && t->mip_levels > 1) { float m = lod < s.lodmin ? s.lodmin : lod > s.lodmax ? s.lodmax : lod; l = (uint32_t)(m < 0 ? 0 : m + (s.mipf == 1 ? 0.5f : 0)); if (l >= t->mip_levels) l = t->mip_levels - 1; }
    float w = (float)dim(t->width, l), h = (float)dim(t->height, l);
    float x = s.norm ? c.x * w : c.x, y = s.norm ? c.y * h : c.y;
    bool linear = s.magf == 1 || s.minf == 1;
    if (!linear) return texel<T>(t, (int)__builtin_floorf(x), (int)__builtin_floorf(y), z, l, s);
    x -= 0.5f; y -= 0.5f;
    int x0 = (int)__builtin_floorf(x), y0 = (int)__builtin_floorf(y);
    float fx = x - x0, fy = y - y0;
    float4 a = __builtin_convertvector(texel<T>(t, x0, y0, z, l, s), float4), b = __builtin_convertvector(texel<T>(t, x0 + 1, y0, z, l, s), float4);
    float4 cc = __builtin_convertvector(texel<T>(t, x0, y0 + 1, z, l, s), float4), d = __builtin_convertvector(texel<T>(t, x0 + 1, y0 + 1, z, l, s), float4);
    float4 r = (a * (1 - fx) + b * fx) * (1 - fy) + (cc * (1 - fx) + d * fx) * fy;
    return __builtin_convertvector(r, vec<T, 4>);
}
template <class C> inline uint2 u2(C c) { if constexpr (__isim_is_vec<C>) return uint2{(uint32_t)c[0], (uint32_t)c[1]}; else return uint2{(uint32_t)c, 0}; }
template <class C> inline uint3 u3(C c) { return uint3{(uint32_t)c[0], (uint32_t)c[1], (uint32_t)c[2]}; }
}  // namespace __isim_tx

/* ---- textures ---- */
namespace metal {
struct __texture_base {
    const __isim_mtl_texture *__t = nullptr;
    __texture_base() = default;
    explicit __texture_base(const __isim_mtl_texture *t) : __t(t) {}
    uint get_width(uint lod = 0) const { return __t ? __isim_tx::dim(__t->width, lod) : 0; }
    uint get_height(uint lod = 0) const { return __t ? __isim_tx::dim(__t->height, lod) : 0; }
    uint get_depth(uint lod = 0) const { return __t ? __isim_tx::dim(__t->depth, lod) : 0; }
    uint get_num_mip_levels() const { return __t ? __t->mip_levels : 0; }
    uint get_array_size() const { return __t ? __t->array_length : 0; }
    uint get_num_samples() const { return 1; }
};
template <class T, access A = access::sample> struct texture1d : __texture_base {
    using __texture_base::__texture_base;
    template <class C> vec<T, 4> read(C c, uint lod = 0) const { return __isim_tx::load<T>(__t, (uint)c, 0, 0, lod); }
    template <class C> void write(vec<T, 4> v, C c, uint lod = 0) const { __isim_tx::store<T>(__t, v, (uint)c, 0, 0, lod); }
    vec<T, 4> sample(sampler s, float c) const { return __isim_tx::sample2d<T>(__t, s, float2{c, s.norm ? 0.5f : 0.5f}, 0, 0); }
};
template <class T, access A = access::sample> struct texture2d : __texture_base {
    using __texture_base::__texture_base;
    template <class C> vec<T, 4> read(C c, uint lod = 0) const { uint2 p = __isim_tx::u2(c); return __isim_tx::load<T>(__t, p.x, p.y, 0, lod); }
    template <class C> void write(vec<T, 4> v, C c, uint lod = 0) const { uint2 p = __isim_tx::u2(c); __isim_tx::store<T>(__t, v, p.x, p.y, 0, lod); }
    vec<T, 4> sample(sampler s, float2 c) const { return __isim_tx::sample2d<T>(__t, s, c, 0, 0); }
    vec<T, 4> sample(sampler s, float2 c, int2 o) const {
        return __isim_tx::sample2d<T>(__t, s, s.norm ? c + float2{(float)o.x / get_width(), (float)o.y / get_height()} : c + float2{(float)o.x, (float)o.y}, 0, 0);
    }
    vec<T, 4> sample(sampler s, float2 c, level l) const { return __isim_tx::sample2d<T>(__t, s, c, 0, l.v); }
    vec<T, 4> sample(sampler s, float2 c, bias) const { return __isim_tx::sample2d<T>(__t, s, c, 0, 0); }
    vec<T, 4> sample(sampler s, float2 c, min_lod_clamp) const { return __isim_tx::sample2d<T>(__t, s, c, 0, 0); }
    vec<T, 4> gather(sampler s, float2 c, int2 = int2{0, 0}, int comp = 0) const {
        float w = get_width(), h = get_height(); float x = (s.norm ? c.x * w : c.x) - 0.5f, y = (s.norm ? c.y * h : c.y) - 0.5f;
        int x0 = (int)__builtin_floorf(x), y0 = (int)__builtin_floorf(y);
        return vec<T, 4>{__isim_tx::texel<T>(__t, x0, y0 + 1, 0, 0, s)[comp], __isim_tx::texel<T>(__t, x0 + 1, y0 + 1, 0, 0, s)[comp],
                         __isim_tx::texel<T>(__t, x0 + 1, y0, 0, 0, s)[comp], __isim_tx::texel<T>(__t, x0, y0, 0, 0, s)[comp]};
    }
    void fence() const { __atomic_thread_fence(__ATOMIC_SEQ_CST); }
};
template <class T, access A = access::sample> struct texture2d_array : __texture_base {
    using __texture_base::__texture_base;
    template <class C> vec<T, 4> read(C c, uint slice, uint lod = 0) const { uint2 p = __isim_tx::u2(c); return __isim_tx::load<T>(__t, p.x, p.y, slice, lod); }
    template <class C> void write(vec<T, 4> v, C c, uint slice, uint lod = 0) const { uint2 p = __isim_tx::u2(c); __isim_tx::store<T>(__t, v, p.x, p.y, slice, lod); }
    vec<T, 4> sample(sampler s, float2 c, uint slice) const { return __isim_tx::sample2d<T>(__t, s, c, slice, 0); }
    vec<T, 4> sample(sampler s, float2 c, uint slice, level l) const { return __isim_tx::sample2d<T>(__t, s, c, slice, l.v); }
};
template <class T, access A = access::sample> struct texture3d : __texture_base {
    using __texture_base::__texture_base;
    template <class C> vec<T, 4> read(C c, uint lod = 0) const {
        uint3 p = __isim_tx::u3(c); if (!__t || p.z >= __isim_tx::dim(__t->depth, lod)) return vec<T, 4>{0, 0, 0, 0}; return __isim_tx::load<T>(__t, p.x, p.y, p.z, lod);
    }
    template <class C> void write(vec<T, 4> v, C c, uint lod = 0) const {
        uint3 p = __isim_tx::u3(c); if (!__t || p.z >= __isim_tx::dim(__t->depth, lod)) return; __isim_tx::store<T>(__t, v, p.x, p.y, p.z, lod);
    }
    vec<T, 4> sample(sampler s, float3 c) const {   /* bilinear within the nearest depth plane */
        float d = s.norm ? c.z * get_depth() : c.z; int z = __isim_tx::address((int)__builtin_floorf(d), (int)get_depth(), s.r);
        return z < 0 ? vec<T, 4>{0, 0, 0, 0} : __isim_tx::sample2d<T>(__t, s, c.xy, (uint)z, 0);
    }
};
template <class T, access A = access::sample> struct texture_buffer : __texture_base {
    using __texture_base::__texture_base;
    vec<T, 4> read(uint i) const { return __isim_tx::load<T>(__t, i, 0, 0, 0); }
    void write(vec<T, 4> v, uint i) const { __isim_tx::store<T>(__t, v, i, 0, 0, 0); }
};
}  // namespace metal

/* the wrappers' conversions of the thread-position attributes to the declared type */
template <class T> inline T __isim_pos(const uint32_t *v) {
    if constexpr (__isim_is_vec<T>) { T r = {}; for (int i = 0; i < __builtin_vectorelements(T) && i < 3; i++) r[i] = (__isim_elem<T>)v[i]; return r; }
    else return (T)v[0];
}

#define device
#define constant
#define thread
