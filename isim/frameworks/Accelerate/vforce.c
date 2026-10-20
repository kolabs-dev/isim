/* isim Accelerate: vForce, adapted: libm applied to each element. Two-input functions take (z, y, x, n). */
#include <Accelerate/Accelerate.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

static double sinpi_(double x) { return sin(M_PI * fmod(x, 2.0)); }
static double cospi_(double x) { return cos(M_PI * fmod(x, 2.0)); }
static double tanpi_(double x) { return tan(M_PI * fmod(x, 1.0)); }
static float sinpif_(float x) { return (float)sinpi_(x); }
static float cospif_(float x) { return (float)cospi_(x); }
static float tanpif_(float x) { return (float)tanpi_(x); }
static double rsqrt_(double x) { return 1 / sqrt(x); }
static float rsqrtf_(float x) { return 1 / sqrtf(x); }
static double rec_(double x) { return 1 / x; }
static float recf_(float x) { return 1 / x; }

#define F1(name, fd, ff) \
    void vv##name##f(float *z, const float *x, const int *n) { for (int i = 0; i < *n; i++) z[i] = ff(x[i]); } \
    void vv##name(double *z, const double *x, const int *n) { for (int i = 0; i < *n; i++) z[i] = fd(x[i]); }
#define F2(name, expr) \
    void vv##name##f(float *z, const float *y, const float *x, const int *n) { \
        for (int i = 0; i < *n; i++) { float Y = y[i], X = x[i]; z[i] = (float)(expr); } } \
    void vv##name(double *z, const double *y, const double *x, const int *n) { \
        for (int i = 0; i < *n; i++) { double Y = y[i], X = x[i]; z[i] = (expr); } }
F1(sin, sin, sinf) F1(cos, cos, cosf) F1(tan, tan, tanf) F1(asin, asin, asinf) F1(acos, acos, acosf) F1(atan, atan, atanf)
F1(sinh, sinh, sinhf) F1(cosh, cosh, coshf) F1(tanh, tanh, tanhf) F1(asinh, asinh, asinhf) F1(acosh, acosh, acoshf)
F1(atanh, atanh, atanhf) F1(exp, exp, expf) F1(exp2, exp2, exp2f) F1(expm1, expm1, expm1f) F1(log, log, logf)
F1(log2, log2, log2f) F1(log10, log10, log10f) F1(log1p, log1p, log1pf) F1(logb, logb, logbf) F1(sqrt, sqrt, sqrtf)
F1(rsqrt, rsqrt_, rsqrtf_) F1(rec, rec_, recf_) F1(fabs, fabs, fabsf) F1(floor, floor, floorf) F1(ceil, ceil, ceilf)
F1(nint, rint, rintf) F1(int, trunc, truncf) F1(sinpi, sinpi_, sinpif_) F1(cospi, cospi_, cospif_)
F1(tanpi, tanpi_, tanpif_) F1(cbrt, cbrt, cbrtf)
F2(atan2, atan2(Y, X)) F2(pow, pow(X, Y)) F2(div, Y / X) F2(fmod, fmod(Y, X)) F2(remainder, remainder(Y, X))
F2(copysign, copysign(Y, X)) F2(nextafter, nextafter(Y, X))

void vvpowsf(float *z, const float *y, const float *x, const int *n) { for (int i = 0; i < *n; i++) z[i] = powf(x[i], *y); }
void vvpows(double *z, const double *y, const double *x, const int *n) { for (int i = 0; i < *n; i++) z[i] = pow(x[i], *y); }
void vvsincosf(float *s, float *c, const float *x, const int *n) { for (int i = 0; i < *n; i++) { s[i] = sinf(x[i]); c[i] = cosf(x[i]); } }
void vvsincos(double *s, double *c, const double *x, const int *n) { for (int i = 0; i < *n; i++) { s[i] = sin(x[i]); c[i] = cos(x[i]); } }
