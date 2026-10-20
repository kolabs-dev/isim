#pragma once
/* vForce (vecLib's vForce.h): elementwise math over arrays; the count is passed by pointer. Two-input functions
   take (result, y, x, n): vvpowf(z, y, x, n) is z = x^y, vvdivf z = y / x, vvatan2f z = atan2(y, x). */
#include <Accelerate/vecLibTypes.h>

#define VFORCE1(n) VECLIB_EXTERN void vv##n##f(float *, const float *, const int *); VECLIB_EXTERN void vv##n(double *, const double *, const int *);
#define VFORCE2(n) VECLIB_EXTERN void vv##n##f(float *, const float *, const float *, const int *); VECLIB_EXTERN void vv##n(double *, const double *, const double *, const int *);
VFORCE1(sin) VFORCE1(cos) VFORCE1(tan) VFORCE1(asin) VFORCE1(acos) VFORCE1(atan) VFORCE1(sinh) VFORCE1(cosh) VFORCE1(tanh)
VFORCE1(asinh) VFORCE1(acosh) VFORCE1(atanh) VFORCE1(exp) VFORCE1(exp2) VFORCE1(expm1) VFORCE1(log) VFORCE1(log2) VFORCE1(log10)
VFORCE1(log1p) VFORCE1(logb) VFORCE1(sqrt) VFORCE1(rsqrt) VFORCE1(rec) VFORCE1(fabs) VFORCE1(floor) VFORCE1(ceil) VFORCE1(nint)
VFORCE1(int) VFORCE1(sinpi) VFORCE1(cospi) VFORCE1(tanpi) VFORCE1(cbrt)
VFORCE2(atan2) VFORCE2(pow) VFORCE2(div) VFORCE2(fmod) VFORCE2(remainder) VFORCE2(copysign) VFORCE2(nextafter)
#undef VFORCE1
#undef VFORCE2
/* z = x ^ y for one exponent y */
VECLIB_EXTERN void vvpowsf(float *, const float *, const float *, const int *);
VECLIB_EXTERN void vvpows(double *, const double *, const double *, const int *);
VECLIB_EXTERN void vvsincosf(float *, float *, const float *, const int *);
VECLIB_EXTERN void vvsincos(double *, double *, const double *, const int *);
