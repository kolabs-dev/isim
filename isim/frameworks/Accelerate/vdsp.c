/* isim Accelerate: vDSP, adapted: isim's own implementation (no host library), single and double precision from one
   template (vdsp_t.h). The FFTs are mixed-radix Cooley-Tukey in double, so any length works; vDSP's packing and
   scaling are Apple's. */
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

/* out[k] = sum_j in[j s] e^{sign 2 pi i j k / n}, unnormalized */
static void fft_rec(const double *ire, const double *iim, size_t s, size_t n, double *ore, double *oim, int sign) {
    if (n == 1) { ore[0] = ire[0]; oim[0] = iim[0]; return; }
    size_t p = 2;
    while (n % p) { p = p == 2 ? 3 : p + 2; if (p * p > n) { p = n; break; } }
    size_t m = n / p;
    for (size_t r = 0; r < p; r++) fft_rec(ire + r * s, iim + r * s, s * p, m, ore + r * m, oim + r * m, sign);
    double tre[p], tim[p], xre[p], xim[p];
    for (size_t k = 0; k < m; k++) {
        for (size_t r = 0; r < p; r++) {
            double a = sign * 2 * M_PI * (double)(r * k) / (double)n, c = cos(a), d = sin(a);
            double yr = ore[r * m + k], yi = oim[r * m + k];
            tre[r] = yr * c - yi * d; tim[r] = yr * d + yi * c;
        }
        for (size_t q = 0; q < p; q++) {
            double sr = 0, si = 0;
            for (size_t r = 0; r < p; r++) {
                double a = sign * 2 * M_PI * (double)((r * q) % p) / (double)p, c = cos(a), d = sin(a);
                sr += tre[r] * c - tim[r] * d; si += tre[r] * d + tim[r] * c;
            }
            xre[q] = sr; xim[q] = si;
        }
        for (size_t q = 0; q < p; q++) { ore[k + q * m] = xre[q]; oim[k + q * m] = xim[q]; }
    }
}

/* sign -1: forward, +1: inverse; unnormalized, in place */
static void isim_cfft(double *re, double *im, size_t n, int sign) {
    if (n < 2) return;
    double *in = malloc(sizeof(double) * n * 2);
    memcpy(in, re, sizeof(double) * n); memcpy(in + n, im, sizeof(double) * n);
    fft_rec(in, in + n, 1, n, re, im, sign);
    free(in);
}

/* the real FFT of 2 * half values packed as even/odd pairs: vDSP's output is twice the DFT, X[half] in im[0] */
static void isim_rfft_packed_forward(double *re, double *im, size_t half) {
    if (!half) return;
    size_t h = half, n = 2 * h;
    isim_cfft(re, im, h, -1);
    double *zr = malloc(sizeof(double) * h * 2), *zi = zr + h;
    memcpy(zr, re, sizeof(double) * h); memcpy(zi, im, sizeof(double) * h);
    re[0] = 2 * (zr[0] + zi[0]); im[0] = 2 * (zr[0] - zi[0]);
    for (size_t k = 1; k < h; k++) {
        double ar = zr[k], ai = zi[k], br = zr[h - k], bi = -zi[h - k];       /* Z[k], conj(Z[h - k]) */
        double er = (ar + br) / 2, ei = (ai + bi) / 2;                          /* even part */
        double or_ = (ai - bi) / 2, oi = -(ar - br) / 2;                        /* odd part: (Z - conj) / 2i */
        double a = -2 * M_PI * (double)k / (double)n, c = cos(a), d = sin(a);
        re[k] = 2 * (er + or_ * c - oi * d); im[k] = 2 * (ei + or_ * d + oi * c);
    }
    free(zr);
}

/* the inverse of the above: from vDSP's packed spectrum to the even/odd pairs, unscaled (a round trip gives 2n x) */
static void isim_rfft_packed_inverse(double *re, double *im, size_t half) {
    if (!half) return;
    size_t h = half, n = 2 * h;
    double *yr = malloc(sizeof(double) * h * 2), *yi = yr + h;
    memcpy(yr, re, sizeof(double) * h); memcpy(yi, im, sizeof(double) * h);
    re[0] = yr[0] + yi[0]; im[0] = yr[0] - yi[0];
    for (size_t k = 1; k < h; k++) {
        double ar = yr[k], ai = yi[k], br = yr[h - k], bi = -yi[h - k];
        double sr = ar + br, si = ai + bi, dr = ar - br, di = ai - bi;
        double a = 2 * M_PI * (double)k / (double)n, c = cos(a), d = sin(a);
        double wr = dr * c - di * d, wi = dr * d + di * c;                      /* e^{+2 pi i k / n} (Y - conj) */
        re[k] = sr - wi; im[k] = si + wr;                                       /* + i w */
    }
    free(yr);
    isim_cfft(re, im, h, +1);
}

/* the lengths Apple's DFT routines accept: f * 2^k with f in 1, 3, 5, 15 */
static int isim_dft_length_ok(size_t n) {
    if (!n) return 0;
    while (n % 2 == 0) n /= 2;
    return n == 1 || n == 3 || n == 5 || n == 15;
}

#define T float
#define D
#define CT DSPComplex
#define SCT DSPSplitComplex
#define FT FFTSetup
#define DFTSETUP vDSP_DFT_Setup
#define DFTSTRUCT struct vDSP_DFT_SetupStruct
#include "vdsp_t.h"
#undef T
#undef D
#undef CT
#undef SCT
#undef FT
#undef DFTSETUP
#undef DFTSTRUCT
#define T double
#define D D
#define CT DSPDoubleComplex
#define SCT DSPDoubleSplitComplex
#define FT FFTSetupD
#define DFTSETUP vDSP_DFT_SetupD
#define DFTSTRUCT struct vDSP_DFT_SetupStructD
#include "vdsp_t.h"

/* conversions: vfix truncates toward zero, vfixr rounds to nearest; both saturate */
#define CONV(name, IN, OUT, op) \
    void vDSP_##name(const IN *A, vDSP_Stride IA, OUT *C, vDSP_Stride IC, vDSP_Length N) { \
        for (vDSP_Length i = 0; i < N; i++) { IN a = A[(long)i * IA]; C[(long)i * IC] = op; } \
    }
#define SAT(x, lo, hi) ((x) != (x) ? 0 : (x) <= (lo) ? (lo) : (x) >= (hi) ? (hi) : (x))
CONV(vspdp, float, double, (double)a)
CONV(vdpsp, double, float, (float)a)
CONV(vfltu8, unsigned char, float, (float)a)
CONV(vflt8, char, float, (float)(signed char)a)
CONV(vflt16, short, float, (float)a)
CONV(vfltu16, unsigned short, float, (float)a)
CONV(vflt32, int, float, (float)a)
CONV(vfix8, float, char, (char)(signed char)SAT(truncf(a), -128.f, 127.f))
CONV(vfix16, float, short, (short)SAT(truncf(a), -32768.f, 32767.f))
CONV(vfix32, float, int, (int)SAT((double)truncf(a), -2147483648.0, 2147483647.0))
CONV(vfixr16, float, short, (short)SAT(roundf(a), -32768.f, 32767.f))
CONV(vfixu8, float, unsigned char, (unsigned char)SAT(truncf(a), 0.f, 255.f))
CONV(vfixru8, float, unsigned char, (unsigned char)SAT(roundf(a), 0.f, 255.f))
CONV(vfltu32, unsigned int, float, (float)a)
CONV(vfixr8, float, char, (char)(signed char)SAT(roundf(a), -128.f, 127.f))
CONV(vfixr32, float, int, (int)SAT((double)roundf(a), -2147483648.0, 2147483647.0))
CONV(vfixu16, float, unsigned short, (unsigned short)SAT(truncf(a), 0.f, 65535.f))
CONV(vfixru16, float, unsigned short, (unsigned short)SAT(roundf(a), 0.f, 65535.f))
CONV(vfixu32, float, unsigned int, (unsigned int)SAT((double)truncf(a), 0.0, 4294967295.0))
CONV(vfixru32, float, unsigned int, (unsigned int)SAT((double)roundf(a), 0.0, 4294967295.0))
