#pragma once
#include <_isim_cdefs.h>
__BEGIN_DECLS
#define M_PI 3.14159265358979323846264338327950288
#define M_PI_2 1.57079632679489661923132169163975144
#define M_PI_4 0.785398163397448309615660845819875721
#define M_E 2.71828182845904523536028747135266250
#define M_SQRT2 1.41421356237309504880168872420969808
#define INFINITY __builtin_inff()
#define NAN __builtin_nanf("")
#define isnan(x) __builtin_isnan(x)
#define isinf(x) __builtin_isinf(x)
#define isfinite(x) __builtin_isfinite(x)
#define signbit(x) __builtin_signbit(x)
double sin(double); double cos(double); double tan(double); double asin(double); double acos(double);
double atan(double); double atan2(double, double); double sqrt(double); double pow(double, double);
double exp(double); double log(double); double log10(double); double log2(double);
double floor(double); double ceil(double); double round(double); double trunc(double); double fmod(double, double);
double fabs(double); double fmin(double, double); double fmax(double, double); double hypot(double, double);
long lround(double); double rint(double);
float sinf(float); float cosf(float); float sqrtf(float); float floorf(float); float ceilf(float);
float roundf(float); float fabsf(float); float fminf(float, float); float fmaxf(float, float); float powf(float, float); float fmodf(float, float);
__END_DECLS
