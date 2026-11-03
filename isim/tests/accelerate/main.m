// Accelerate from C (AccelerateCTest.app, issue #279): BLAS, LAPACK, vDSP and vForce, checked against references
// computed here in double (naive sums, a naive DFT) and against identities (A A^-1 = I, A v = lambda v, ...).
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

static int close_d(const double *a, const double *b, int n, double tol) {
    for (int i = 0; i < n; i++) if (fabs(a[i] - b[i]) > tol * (1 + fabs(b[i]))) { printf("      [%d] %.9g != %.9g\n", i, a[i], b[i]); return 0; }
    return 1;
}
static int close_f(const float *a, const double *b, int n, double tol) {
    for (int i = 0; i < n; i++) if (fabs(a[i] - b[i]) > tol * (1 + fabs(b[i]))) { printf("      [%d] %.9g != %.9g\n", i, a[i], b[i]); return 0; }
    return 1;
}

/* the reference DFT: X[k] = sum_j x[j] e^{sign 2 pi i j k / n} */
static void dft(const double *re, const double *im, double *ore, double *oim, int n, int sign) {
    for (int k = 0; k < n; k++) {
        double sr = 0, si = 0;
        for (int j = 0; j < n; j++) {
            double a = sign * 2 * M_PI * (double)j * k / n;
            sr += re[j] * cos(a) - im[j] * sin(a); si += re[j] * sin(a) + im[j] * cos(a);
        }
        ore[k] = sr; oim[k] = si;
    }
}

static void blas(void) {
    double x[] = {1, 2, 3, 4}, y[] = {5, 6, 7, 8};
    CHECK(cblas_ddot(4, x, 1, y, 1) == 70 && cblas_ddot(2, x, 2, y, -2) == 1 * 7 + 3 * 5, "ddot, strides and negative increments");
    CHECK(fabs(cblas_dnrm2(4, x, 1) - sqrt(30)) < 1e-12 && cblas_dasum(4, (double[]){-1, 2, -3, 4}, 1) == 10, "dnrm2, dasum");
    CHECK(cblas_idamax(4, (double[]){1, -9, 3, 9}, 1) == 1, "idamax: the first largest magnitude");
    double z[4]; memcpy(z, y, sizeof z); cblas_daxpy(4, 2, x, 1, z, 1);
    CHECK(close_d(z, (double[]){7, 10, 13, 16}, 4, 0), "daxpy");
    float fx[] = {1, 2, 3}; cblas_sscal(3, 0.5f, fx, 1);
    CHECK(fx[0] == 0.5f && fx[2] == 1.5f, "sscal");
    /* C (2x3) = A (2x4) B (4x3) */
    double A[] = {1, 2, 3, 4, 5, 6, 7, 8}, B[12], C[6], R[6] = {0};
    for (int i = 0; i < 12; i++) B[i] = i - 5;
    for (int i = 0; i < 2; i++) for (int j = 0; j < 3; j++) for (int k = 0; k < 4; k++) R[i * 3 + j] += A[i * 4 + k] * B[k * 3 + j];
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 4, 1, A, 4, B, 3, 0, C, 3);
    CHECK(close_d(C, R, 6, 1e-12), "dgemm row-major");
    /* the same product column-major: C^T = B^T A^T */
    double Ct[6];
    cblas_dgemm(CblasColMajor, CblasNoTrans, CblasNoTrans, 3, 2, 4, 1, B, 3, A, 4, 0, Ct, 3);
    CHECK(close_d(Ct, R, 6, 1e-12), "dgemm column-major");
    double Ctt[6] = {1, 1, 1, 1, 1, 1}, R2[6];
    for (int i = 0; i < 6; i++) R2[i] = 2 * R[i] + 3;
    cblas_dgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 3, 4, 2, A, 4, B, 3, 3, Ctt, 3);
    CHECK(close_d(Ctt, R2, 6, 1e-12), "dgemm alpha and beta");
    double At[8];
    for (int i = 0; i < 2; i++) for (int k = 0; k < 4; k++) At[k * 2 + i] = A[i * 4 + k];
    cblas_dgemm(CblasRowMajor, CblasTrans, CblasNoTrans, 2, 3, 4, 1, At, 2, B, 3, 0, C, 3);
    CHECK(close_d(C, R, 6, 1e-12), "dgemm transposed A");
    double v[4] = {1, 0, -1, 2}, gv[2] = {0, 0};
    cblas_dgemv(CblasRowMajor, CblasNoTrans, 2, 4, 1, A, 4, v, 1, 0, gv, 1);
    CHECK(gv[0] == 1 - 3 + 8 && gv[1] == 5 - 7 + 16, "dgemv");
    float sA[] = {1, 2, 3, 4}, sB[] = {5, 6, 7, 8}, sC[4];
    cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, 1, sA, 2, sB, 2, 0, sC, 2);
    CHECK(sC[0] == 19 && sC[1] == 22 && sC[2] == 43 && sC[3] == 50, "sgemm");
    double L[] = {2, 0, 0, 1, 3, 0, 4, 5, 6}, b[] = {2, 7, 32};   /* lower triangular, row-major */
    cblas_dtrsv(CblasRowMajor, CblasLower, CblasNoTrans, CblasNonUnit, 3, L, 3, b, 1);
    CHECK(close_d(b, (double[]){1, 2, 3}, 3, 1e-12), "dtrsv");
}

static void lapack(void) {
    /* column-major 3x3 */
    double A[] = {4, -2, 1, 3, 6, -4, 2, 1, 8}, Ao[9], B[] = {12, -25, 32}, x[3];
    memcpy(Ao, A, sizeof A); memcpy(x, B, sizeof B);
    __CLPK_integer n = 3, nrhs = 1, lda = 3, ipiv[3], info = -1;
    dgesv_(&n, &nrhs, A, &lda, ipiv, x, &lda, &info);
    double r[3] = {0};
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) r[i] += Ao[j * 3 + i] * x[j];
    CHECK(info == 0 && close_d(r, B, 3, 1e-10), "dgesv: A x = b");
    memcpy(A, Ao, sizeof A);
    dgetrf_(&n, &n, A, &lda, ipiv, &info);
    double work[9]; __CLPK_integer lwork = 9;
    dgetri_(&n, A, &lda, ipiv, work, &lwork, &info);
    double I[9] = {0};
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) for (int k = 0; k < 3; k++) I[j * 3 + i] += Ao[k * 3 + i] * A[j * 3 + k];
    CHECK(info == 0 && close_d(I, (double[]){1, 0, 0, 0, 1, 0, 0, 0, 1}, 9, 1e-10), "dgetrf + dgetri: A A^-1 = I");
    double S[] = {4, 2, -2, 2, 10, 2, -2, 2, 5}, So[9], sb[] = {2, 4, 6}, sx[3];
    memcpy(So, S, sizeof S); memcpy(sx, sb, sizeof sb);
    char lo = 'L';
    dposv_(&lo, &n, &nrhs, S, &lda, sx, &lda, &info);
    double sr[3] = {0};
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) sr[i] += So[j * 3 + i] * sx[j];
    CHECK(info == 0 && close_d(sr, sb, 3, 1e-10), "dposv (Cholesky)");
    double notpd[] = {1, 2, 2, 1};
    __CLPK_integer two = 2;
    dpotrf_(&lo, &two, notpd, &two, &info);
    CHECK(info == 2, "dpotrf: not positive definite");
    /* least squares: fit y = a + b t through 4 points */
    double M[] = {1, 1, 1, 1, 0, 1, 2, 3}, y[] = {1, 3, 4, 7};
    __CLPK_integer m = 4, nn = 2, ldm = 4, lw = 64; double w[64]; char no = 'N';
    dgels_(&no, &m, &nn, &nrhs, M, &ldm, y, &ldm, w, &lw, &info);
    CHECK(info == 0 && fabs(y[0] - 0.9) < 1e-10 && fabs(y[1] - 1.9) < 1e-10, "dgels: least squares");
    double E[] = {2, 1, 0, 1, 2, 1, 0, 1, 2}, Eo[9], ev[3]; char v = 'V', up = 'U';
    memcpy(Eo, E, sizeof E);
    dsyev_(&v, &up, &n, E, &lda, ev, w, &lw, &info);
    int ok = info == 0 && fabs(ev[0] - (2 - sqrt(2))) < 1e-10 && fabs(ev[1] - 2) < 1e-10 && fabs(ev[2] - (2 + sqrt(2))) < 1e-10;
    for (int k = 0; k < 3; k++) for (int i = 0; i < 3; i++) {
        double av = 0;
        for (int j = 0; j < 3; j++) av += Eo[j * 3 + i] * E[k * 3 + j];
        if (fabs(av - ev[k] * E[k * 3 + i]) > 1e-10) ok = 0;
    }
    CHECK(ok, "dsyev: ascending eigenvalues, A v = lambda v");
    float fA[] = {2, 1, 1, 3}, fb[] = {3, 5}; __CLPK_integer fip[2];
    sgesv_(&two, &nrhs, fA, &two, fip, fb, &two, &info);
    CHECK(info == 0 && fabsf(fb[0] - 0.8f) < 1e-5f && fabsf(fb[1] - 1.4f) < 1e-5f, "sgesv");
    double sing[] = {1, 2, 2, 4};
    dgetrf_(&two, &two, sing, &two, fip, &info);
    CHECK(info == 2, "dgetrf: singular");
}

static void vdsp(void) {
    float a[] = {1, -2, 3, -4, 5}, b[] = {2, 2, 2, 2, 2}, c[5];
    vDSP_vadd(a, 1, b, 1, c, 1, 5);
    CHECK(close_f(c, (double[]){3, 0, 5, -2, 7}, 5, 0), "vadd");
    vDSP_vsub(b, 1, a, 1, c, 1, 5);
    CHECK(close_f(c, (double[]){-1, -4, 1, -6, 3}, 5, 0), "vsub: A - B with B first");
    vDSP_vdiv(b, 1, a, 1, c, 1, 5);
    CHECK(close_f(c, (double[]){0.5, -1, 1.5, -2, 2.5}, 5, 0), "vdiv: A / B with B first");
    float s = 10; vDSP_vsmul(a, 2, &s, c, 1, 3);
    CHECK(close_f(c, (double[]){10, 30, 50}, 3, 0), "vsmul with a stride");
    float sum, mean, rms, mx, mn; vDSP_Length imax;
    vDSP_sve(a, 1, &sum, 5); vDSP_meanv(a, 1, &mean, 5); vDSP_rmsqv(a, 1, &rms, 5);
    vDSP_maxvi(a, 1, &mx, &imax, 5); vDSP_minv(a, 1, &mn, 5);
    CHECK(sum == 3 && fabsf(mean - 0.6f) < 1e-6f && fabsf(rms - sqrtf(11)) < 1e-5f && mx == 5 && imax == 4 && mn == -4, "reductions");
    float d; vDSP_dotpr(a, 1, b, 1, &d, 5);
    CHECK(d == 6, "dotpr");
    double ramp[5]; double r0 = 1, dr = 0.5; vDSP_vrampD(&r0, &dr, ramp, 1, 5);
    CHECK(close_d(ramp, (double[]){1, 1.5, 2, 2.5, 3}, 5, 0), "vrampD");
    double g0 = 0, g1 = 1, gen[5]; vDSP_vgenD(&g0, &g1, gen, 1, 5);
    CHECK(close_d(gen, (double[]){0, 0.25, 0.5, 0.75, 1}, 5, 1e-15), "vgenD");
    float lo = -1, hi = 2; vDSP_vclip(a, 1, &lo, &hi, c, 1, 5);
    CHECK(close_f(c, (double[]){1, -1, 2, -1, 2}, 5, 0), "vclip");
    float srt[] = {3, 1, 2}; vDSP_vsort(srt, 3, -1);
    CHECK(srt[0] == 3 && srt[2] == 1, "vsort descending");
    /* C (2x2) = A (2x3) * B (3x2) */
    float mA[] = {1, 2, 3, 4, 5, 6}, mB[] = {7, 8, 9, 10, 11, 12}, mC[4];
    vDSP_mmul(mA, 1, mB, 1, mC, 1, 2, 2, 3);
    CHECK(mC[0] == 58 && mC[1] == 64 && mC[2] == 139 && mC[3] == 154, "mmul");
    float mT[6]; vDSP_mtrans(mA, 1, mT, 1, 3, 2);
    CHECK(mT[0] == 1 && mT[1] == 4 && mT[2] == 2 && mT[5] == 6, "mtrans");
    /* correlation and convolution */
    float sig[] = {1, 2, 3, 4, 5, 6}, k[] = {1, 0, -1}, cr[4], cv[4];
    vDSP_conv(sig, 1, k, 1, cr, 1, 4, 3);
    vDSP_conv(sig, 1, k + 2, -1, cv, 1, 4, 3);
    CHECK(close_f(cr, (double[]){-2, -2, -2, -2}, 4, 0) && close_f(cv, (double[]){2, 2, 2, 2}, 4, 0), "conv: correlation and convolution");
    float hann[8]; vDSP_hann_window(hann, 8, vDSP_HANN_DENORM);
    double href[8]; for (int i = 0; i < 8; i++) href[i] = 0.5 * (1 - cos(2 * M_PI * i / 8));
    CHECK(close_f(hann, href, 8, 1e-6), "hann_window");
    /* complex */
    float re[] = {1, 0, 3}, im[] = {0, 1, -4}, mags[3], abs_[3];
    DSPSplitComplex z = {re, im};
    vDSP_zvmags(&z, 1, mags, 1, 3); vDSP_zvabs(&z, 1, abs_, 1, 3);
    CHECK(mags[2] == 25 && abs_[2] == 5 && mags[1] == 1, "zvmags, zvabs");
    DSPComplex inter[] = {{1, 2}, {3, 4}}; float zr[2], zi[2]; DSPSplitComplex zz = {zr, zi};
    vDSP_ctoz(inter, 2, &zz, 1, 2);
    CHECK(zr[0] == 1 && zi[0] == 2 && zr[1] == 3 && zi[1] == 4, "ctoz");
    /* conversions */
    float fl[] = {1.6f, -1.6f, 300, -2.5f}; short sh[4]; unsigned char u8[4];
    vDSP_vfix16(fl, 1, sh, 1, 4);
    CHECK(sh[0] == 1 && sh[1] == -1 && sh[2] == 300, "vfix16 truncates");
    vDSP_vfixr16(fl, 1, sh, 1, 4);
    CHECK(sh[0] == 2 && sh[1] == -2, "vfixr16 rounds");
    vDSP_vfixu8(fl, 1, u8, 1, 4);
    CHECK(u8[0] == 1 && u8[2] == 255 && u8[3] == 0, "vfixu8 saturates");
    double dd[2]; vDSP_vspdp(fl, 1, dd, 1, 2);
    CHECK(dd[0] == (double)1.6f, "vspdp");
}

static void ffts(void) {
    enum { N = 16 };
    double x[N], zero[N] = {0}, Xr[N], Xi[N];
    for (int i = 0; i < N; i++) x[i] = sin(2 * M_PI * 3 * i / N) + 0.5 * cos(2 * M_PI * 5 * i / N) + 0.25 * i;
    dft(x, zero, Xr, Xi, N, -1);
    /* complex FFT in place */
    double cr[N], ci[N]; memcpy(cr, x, sizeof x); memset(ci, 0, sizeof ci);
    DSPDoubleSplitComplex c = {cr, ci};
    FFTSetupD setup = vDSP_create_fftsetupD(4, kFFTRadix2);
    vDSP_fft_zipD(setup, &c, 1, 4, kFFTDirection_Forward);
    CHECK(close_d(cr, Xr, N, 1e-9) && close_d(ci, Xi, N, 1e-9), "fft_zipD forward = DFT");
    vDSP_fft_zipD(setup, &c, 1, 4, kFFTDirection_Inverse);
    for (int i = 0; i < N; i++) cr[i] /= N;
    CHECK(close_d(cr, x, N, 1e-9), "fft_zipD inverse, unscaled (N x)");
    /* real FFT: even/odd packing, 2 x the DFT, Nyquist in imagp[0] */
    double pr[N / 2], pi[N / 2]; DSPDoubleSplitComplex p = {pr, pi};
    vDSP_ctozD((const DSPDoubleComplex *)x, 2, &p, 1, N / 2);
    vDSP_fft_zripD(setup, &p, 1, 4, kFFTDirection_Forward);
    int ok = fabs(pr[0] - 2 * Xr[0]) < 1e-9 && fabs(pi[0] - 2 * Xr[N / 2]) < 1e-9;
    for (int k = 1; k < N / 2; k++) ok = ok && fabs(pr[k] - 2 * Xr[k]) < 1e-9 && fabs(pi[k] - 2 * Xi[k]) < 1e-9;
    CHECK(ok, "fft_zripD forward: packed, twice the DFT");
    vDSP_fft_zripD(setup, &p, 1, 4, kFFTDirection_Inverse);
    double back[N]; vDSP_ztocD(&p, 1, (DSPDoubleComplex *)back, 2, N / 2);
    for (int i = 0; i < N; i++) back[i] /= 2 * N;
    CHECK(close_d(back, x, N, 1e-9), "fft_zripD round trip is 2N x");
    vDSP_destroy_fftsetupD(setup);
    /* single precision */
    float fr[N], fi[N]; for (int i = 0; i < N; i++) { fr[i] = (float)x[i]; fi[i] = 0; }
    DSPSplitComplex fc = {fr, fi};
    FFTSetup fs = vDSP_create_fftsetup(4, kFFTRadix2);
    vDSP_fft_zip(fs, &fc, 1, 4, kFFTDirection_Forward);
    CHECK(close_f(fr, Xr, N, 1e-4) && close_f(fi, Xi, N, 1e-4), "fft_zip (float)");
    vDSP_destroy_fftsetup(fs);
    /* the DFT API, a length that is not a power of two */
    enum { M = 12 };
    double ir[M], ii[M], o_r[M], o_i[M], rr[M], ri[M];
    for (int i = 0; i < M; i++) { ir[i] = cos(i * 0.7) + i; ii[i] = sin(i * 1.3); }
    dft(ir, ii, rr, ri, M, -1);
    vDSP_DFT_SetupD d = vDSP_DFT_zop_CreateSetupD(NULL, M, vDSP_DFT_FORWARD);
    vDSP_DFT_ExecuteD(d, ir, ii, o_r, o_i);
    CHECK(d && close_d(o_r, rr, M, 1e-9) && close_d(o_i, ri, M, 1e-9), "DFT_zop length 12");
    vDSP_DFT_DestroySetupD(d);
    CHECK(vDSP_DFT_zop_CreateSetupD(NULL, 7, vDSP_DFT_FORWARD) == NULL, "DFT: unsupported length 7");
    /* real DFT of 24 values (12 pairs) */
    double xr24[24], z24[24] = {0}, Xr24[24], Xi24[24];
    for (int i = 0; i < 24; i++) xr24[i] = sin(i * 0.4) * (i % 5);
    dft(xr24, z24, Xr24, Xi24, 24, -1);
    double er[12], ei[12], qr[12], qi[12];
    for (int i = 0; i < 12; i++) { er[i] = xr24[2 * i]; ei[i] = xr24[2 * i + 1]; }
    vDSP_DFT_SetupD rd = vDSP_DFT_zrop_CreateSetupD(NULL, 24, vDSP_DFT_FORWARD);
    vDSP_DFT_ExecuteD(rd, er, ei, qr, qi);
    ok = rd && fabs(qr[0] - 2 * Xr24[0]) < 1e-9 && fabs(qi[0] - 2 * Xr24[12]) < 1e-9;
    for (int k = 1; k < 12; k++) ok = ok && fabs(qr[k] - 2 * Xr24[k]) < 1e-9 && fabs(qi[k] - 2 * Xi24[k]) < 1e-9;
    CHECK(ok, "DFT_zrop length 24");
    vDSP_DFT_DestroySetupD(rd);
}

/* complex BLAS (issue #543): interleaved real / imaginary pairs, checked against products worked by hand */
typedef struct { double re, im; } zc;
static int close_z(const zc *a, const zc *b, int n, double tol) {
    for (int i = 0; i < n; i++)
        if (fabs(a[i].re - b[i].re) > tol || fabs(a[i].im - b[i].im) > tol) {
            printf("      [%d] %.9g%+.9gi != %.9g%+.9gi\n", i, a[i].re, a[i].im, b[i].re, b[i].im); return 0;
        }
    return 1;
}
static void complex_blas(void) {
    zc x[] = {{1, 2}, {3, -1}}, y[] = {{0, 1}, {2, 2}}, r;
    cblas_zdotu_sub(2, x, 1, y, 1, &r);                         /* (1+2i)i + (3-i)(2+2i) = (-2+i) + (8+4i) */
    CHECK(close_z(&r, &(zc){6, 5}, 1, 1e-12), "zdotu_sub");
    cblas_zdotc_sub(2, x, 1, y, 1, &r);                         /* (1-2i)i + (3+i)(2+2i) = (2+i) + (4+8i) */
    CHECK(close_z(&r, &(zc){6, 9}, 1, 1e-12), "zdotc_sub");
    CHECK(fabs(cblas_dznrm2(2, x, 1) - sqrt(15)) < 1e-12 && cblas_dzasum(2, x, 1) == 7, "dznrm2, dzasum");
    CHECK(cblas_izamax(3, (zc[]){{1, 1}, {-2, 1}, {0, 3}}, 1) == 1, "izamax: |re| + |im|, the first largest");
    zc z[2] = {{1, 0}, {0, 1}}, al = {0, 2};
    cblas_zaxpy(2, &al, x, 1, z, 1);                            /* z + 2i x */
    CHECK(close_z(z, (zc[]){{-3, 2}, {2, 7}}, 2, 1e-12), "zaxpy");
    cblas_zdscal(2, 0.5, z, 1);
    CHECK(close_z(z, (zc[]){{-1.5, 1}, {1, 3.5}}, 2, 1e-12), "zdscal");
    float cx[] = {1, 1, 2, -2};
    cblas_cscal(2, (float[]){0, 1}, cx, 1);                     /* i(1+i) = -1+i, i(2-2i) = 2+2i */
    CHECK(cx[0] == -1 && cx[1] == 1 && cx[2] == 2 && cx[3] == 2, "cscal");
    float cr[2]; cblas_cdotc_sub(2, cx, 1, cx, 1, cr);
    CHECK(cr[0] == 10 && cr[1] == 0 && fabsf(cblas_scnrm2(2, cx, 1) - sqrtf(10)) < 1e-6f, "cdotc_sub, scnrm2");
    zc ga = {3, 4}, gb = {0, 5}, gs; double gc;
    cblas_zrotg(&ga, &gb, &gc, &gs);                            /* r = (a/|a|) sqrt(|a|^2 + |b|^2) = (3+4i)/5 * sqrt 50 */
    CHECK(fabs(gc - 5 / sqrt(50)) < 1e-12 && close_z(&ga, &(zc){3 * sqrt(2), 4 * sqrt(2)}, 1, 1e-12), "zrotg");

    /* A = [[1+i, 2], [0, 3-i]] (row-major) */
    zc A[] = {{1, 1}, {2, 0}, {0, 0}, {3, -1}}, v[] = {{1, 0}, {0, 1}}, w[2], one = {1, 0}, zero = {0, 0};
    cblas_zgemv(CblasRowMajor, CblasNoTrans, 2, 2, &one, A, 2, v, 1, &zero, w, 1);
    CHECK(close_z(w, (zc[]){{1, 3}, {1, 3}}, 2, 1e-12), "zgemv");
    cblas_zgemv(CblasRowMajor, CblasConjTrans, 2, 2, &one, A, 2, v, 1, &zero, w, 1);   /* A^H v */
    CHECK(close_z(w, (zc[]){{1, -1}, {1, 3}}, 2, 1e-12), "zgemv conjugate-transposed");
    zc Acm[] = {{1, 1}, {0, 0}, {2, 0}, {3, -1}};               /* the same A, column-major */
    cblas_zgemv(CblasColMajor, CblasNoTrans, 2, 2, &one, Acm, 2, v, 1, &zero, w, 1);
    CHECK(close_z(w, (zc[]){{1, 3}, {1, 3}}, 2, 1e-12), "zgemv column-major");
    zc C[4];
    cblas_zgemm(CblasRowMajor, CblasNoTrans, CblasConjTrans, 2, 2, 2, &one, A, 2, A, 2, &zero, C, 2);   /* A A^H */
    CHECK(close_z(C, (zc[]){{6, 0}, {6, 2}, {6, -2}, {10, 0}}, 4, 1e-12), "zgemm A A^H");
    zc H[4] = {{2, 0}, {1, -1}, {99, 99}, {3, 0}};              /* Hermitian, upper triangle stored: [[2, 1-i], [1+i, 3]] */
    cblas_zhemv(CblasRowMajor, CblasUpper, 2, &one, H, 2, v, 1, &zero, w, 1);
    CHECK(close_z(w, (zc[]){{3, 1}, {1, 4}}, 2, 1e-12), "zhemv: the other triangle is the conjugate");
    zc K[4] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
    cblas_zherk(CblasRowMajor, CblasUpper, CblasNoTrans, 2, 2, 1, A, 2, 0, K, 2);
    CHECK(close_z(K, (zc[]){{6, 0}, {6, 2}, {0, 0}, {10, 0}}, 4, 1e-12), "zherk (upper triangle only)");
    zc G[4] = {{0, 0}, {0, 0}, {0, 0}, {0, 0}};
    cblas_zgerc(CblasRowMajor, 2, 2, &one, x, 1, y, 1, G, 2);   /* x y^H */
    CHECK(close_z(G, (zc[]){{2, -1}, {6, 2}, {-1, -3}, {4, -8}}, 4, 1e-12), "zgerc");
    zc b[2] = {{1, 3}, {1, 3}};                                 /* A x = b with x = v */
    cblas_ztrsv(CblasRowMajor, CblasUpper, CblasNoTrans, CblasNonUnit, 2, A, 2, b, 1);
    CHECK(close_z(b, v, 2, 1e-12), "ztrsv");
    zc B[4] = {{1, 3}, {2, 0}, {1, 3}, {3, -1}};                /* A X = B, X = [[1, 0], [i, 1]] */
    cblas_ztrsm(CblasRowMajor, CblasLeft, CblasUpper, CblasNoTrans, CblasNonUnit, 2, 2, &one, A, 2, B, 2);
    CHECK(close_z(B, (zc[]){{1, 0}, {0, 0}, {0, 1}, {1, 0}}, 4, 1e-12), "ztrsm");
    zc X[4] = {{1, 0}, {0, 0}, {0, 1}, {1, 0}}, AX[4];
    memcpy(AX, X, sizeof X);
    cblas_ztrmm(CblasRowMajor, CblasLeft, CblasUpper, CblasNoTrans, CblasNonUnit, 2, 2, &one, A, 2, AX, 2);
    cblas_ztrsm(CblasRowMajor, CblasLeft, CblasUpper, CblasNoTrans, CblasNonUnit, 2, 2, &one, A, 2, AX, 2);
    CHECK(close_z(AX, X, 4, 1e-12), "ztrmm then ztrsm round trip (left)");
    memcpy(AX, X, sizeof X);
    cblas_ztrmm(CblasRowMajor, CblasRight, CblasUpper, CblasConjTrans, CblasNonUnit, 2, 2, &one, A, 2, AX, 2);
    cblas_ztrsm(CblasRowMajor, CblasRight, CblasUpper, CblasConjTrans, CblasNonUnit, 2, 2, &one, A, 2, AX, 2);
    CHECK(close_z(AX, X, 4, 1e-12), "ztrmm then ztrsm round trip (right, conjugate-transposed)");
    zc S[4] = {{1, 2}, {0, 1}, {99, 99}, {2, 0}}, SB[4], SBr[4];  /* complex symmetric (not Hermitian): [[1+2i, i], [i, 2]] */
    cblas_zsymm(CblasRowMajor, CblasLeft, CblasUpper, 2, 2, &one, S, 2, X, 2, &zero, SB, 2);
    CHECK(close_z(SB, (zc[]){{0, 2}, {0, 1}, {0, 3}, {2, 0}}, 4, 1e-12), "zsymm");
    zc Sfull[4] = {{1, 2}, {0, 1}, {0, 1}, {2, 0}};
    cblas_zgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, 2, 2, 2, &one, Sfull, 2, X, 2, &zero, SBr, 2);
    CHECK(close_z(SB, SBr, 4, 1e-12), "zsymm equals zgemm with the full matrix");
}

/* more LAPACK (issue #543): SVD, the nonsymmetric eigenproblem, banded / tridiagonal and complex drivers, checked
   against the identities that define them (A = U S V^T, A v = lambda v, ...) and known values */
static double svd_resid(int m, int n, const double *A, const double *s, const double *U, int ldu, const double *VT, int ldvt, int k) {
    double worst = 0;
    for (int i = 0; i < m; i++) for (int j = 0; j < n; j++) {
        double r = 0;
        for (int l = 0; l < k; l++) r += U[l * ldu + i] * s[l] * VT[j * ldvt + l];
        worst = fmax(worst, fabs(r - A[j * m + i]));
    }
    return worst;
}
static double orth_resid(int rows, int cols, const double *Q, int ld, int bycol) {   /* Q^T Q - I (columns) or Q Q^T - I (rows) */
    double worst = 0;
    for (int a = 0; a < cols; a++) for (int b = 0; b < cols; b++) {
        double d = 0;
        for (int i = 0; i < rows; i++) d += bycol ? Q[a * ld + i] * Q[b * ld + i] : Q[i * ld + a] * Q[i * ld + b];
        worst = fmax(worst, fabs(d - (a == b)));
    }
    return worst;
}
static void lapack_more(void) {
    __CLPK_integer info, lw = 256, one = 1; double work[256]; char A_ = 'A', S_ = 'S', N_ = 'N', V_ = 'V', U_ = 'U', L_ = 'L';
    /* A (2x3, column-major) = [[3, 2, 2], [2, 3, -2]]: singular values 5 and 3 */
    double A[] = {3, 2, 2, 3, 2, -2}, a[6], s[2], U[4], VT[9];
    __CLPK_integer m = 2, n = 3, two = 2, three = 3;
    memcpy(a, A, sizeof A);
    dgesvd_(&A_, &A_, &m, &n, a, &two, s, U, &two, VT, &three, work, &lw, &info);
    CHECK(info == 0 && fabs(s[0] - 5) < 1e-12 && fabs(s[1] - 3) < 1e-12, "dgesvd: singular values (wide matrix)");
    CHECK(svd_resid(2, 3, A, s, U, 2, VT, 3, 2) < 1e-12 && orth_resid(2, 2, U, 2, 1) < 1e-12 && orth_resid(3, 3, VT, 3, 0) < 1e-12,
          "dgesvd 'A': A = U S VT, U and VT orthogonal (VT completed to 3x3)");
    /* the transpose (3x2, tall), thin factors */
    double At[] = {3, 2, 2, 2, 3, -2}, U3[6], VT2[4];
    memcpy(a, At, sizeof At);
    dgesvd_(&S_, &S_, &three, &two, a, &three, s, U3, &three, VT2, &two, work, &lw, &info);
    CHECK(info == 0 && svd_resid(3, 2, At, s, U3, 3, VT2, 2, 2) < 1e-12 && orth_resid(3, 2, U3, 3, 1) < 1e-12, "dgesvd 'S' (tall matrix)");
    __CLPK_integer qw = -1; double opt = 0;
    dgesvd_(&N_, &N_, &three, &two, a, &three, s, U3, &three, VT2, &two, &opt, &qw, &info);
    CHECK(info == 0 && opt >= 1, "dgesvd: workspace query");
    /* rank-deficient 4x3 (third column = first + second): a zero singular value, full U still orthogonal */
    double R[] = {1, 0, 2, 1, 0, 1, 1, 3, 1, 1, 3, 4}, r[12], sr[3], UR[16], VR[9]; __CLPK_integer four = 4, iw[24];
    memcpy(r, R, sizeof R);
    dgesdd_(&A_, &four, &three, r, &four, sr, UR, &four, VR, &three, work, &lw, iw, &info);
    CHECK(info == 0 && sr[2] < 1e-12 && sr[0] >= sr[1] && svd_resid(4, 3, R, sr, UR, 4, VR, 3, 3) < 1e-12 && orth_resid(4, 4, UR, 4, 1) < 1e-12,
          "dgesdd 'A': a rank-deficient matrix");
    float fA[] = {3, 2, 2, 3, 2, -2}, fs[2], fU[4], fVT[9], fw[64]; __CLPK_integer flw = 64;
    sgesvd_(&N_, &N_, &m, &n, fA, &two, fs, fU, &two, fVT, &three, fw, &flw, &info);
    CHECK(info == 0 && fabsf(fs[0] - 5) < 1e-5f && fabsf(fs[1] - 3) < 1e-5f, "sgesvd: values only");

    /* geev: a rotation block (eigenvalues +-i) and 2 on the diagonal, conjugated by a non-orthogonal T */
    double E[16] = {0}, Eo[16], wr[4], wi[4], vl[16], vr[16];
    double base[16] = {0, 1, 0, 0,  -1, 0, 0, 0,  0, 0, 2, 0,  0, 0, 0, -3};   /* column-major */
    double T[16] = {1, 1, 0, 2,  0, 1, 1, 0,  1, 0, 1, 1,  0, 0, 1, 3}, Ti[16], tmp[16] = {0};
    memcpy(Ti, T, sizeof T); __CLPK_integer piv[4];
    dgetrf_(&four, &four, Ti, &four, piv, &info); dgetri_(&four, Ti, &four, piv, work, &lw, &info);
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) for (int k = 0; k < 4; k++) tmp[j * 4 + i] += T[k * 4 + i] * base[j * 4 + k];
    for (int i = 0; i < 4; i++) for (int j = 0; j < 4; j++) for (int k = 0; k < 4; k++) E[j * 4 + i] += tmp[k * 4 + i] * Ti[j * 4 + k];
    memcpy(Eo, E, sizeof E);
    dgeev_(&V_, &V_, &four, E, &four, wr, wi, vl, &four, vr, &four, work, &lw, &info);
    int found[3] = {0}, pairs_ok = 1;
    for (int j = 0; j < 4; j++) {
        if (fabs(wr[j]) < 1e-9 && fabs(fabs(wi[j]) - 1) < 1e-9) found[0]++;
        if (fabs(wr[j] - 2) < 1e-9 && fabs(wi[j]) < 1e-9) found[1]++;
        if (fabs(wr[j] + 3) < 1e-9 && fabs(wi[j]) < 1e-9) found[2]++;
        if (wi[j] > 0 && !(j + 1 < 4 && wi[j + 1] == -wi[j] && wr[j + 1] == wr[j])) pairs_ok = 0;
    }
    CHECK(info == 0 && found[0] == 2 && found[1] == 1 && found[2] == 1 && pairs_ok, "dgeev: eigenvalues, conjugate pairs adjacent (positive first)");
    /* A v = lambda v and u^H A = lambda u^H for every eigenvalue, from LAPACK's real storage of complex vectors */
    double worst = 0, nrm = 0;
    for (int j = 0; j < 4; j++) {
        double vre[4], vim[4] = {0}, ure[4], uim[4] = {0}, lr = wr[j], li = wi[j];
        for (int i = 0; i < 4; i++) {
            if (wi[j] == 0) { vre[i] = vr[j * 4 + i]; ure[i] = vl[j * 4 + i]; }
            else if (wi[j] > 0) { vre[i] = vr[j * 4 + i]; vim[i] = vr[(j + 1) * 4 + i]; ure[i] = vl[j * 4 + i]; uim[i] = vl[(j + 1) * 4 + i]; }
            else { vre[i] = vr[(j - 1) * 4 + i]; vim[i] = -vr[j * 4 + i]; ure[i] = vl[(j - 1) * 4 + i]; uim[i] = -vl[j * 4 + i]; }
        }
        double vn = 0;
        for (int i = 0; i < 4; i++) vn += vre[i] * vre[i] + vim[i] * vim[i];
        nrm = fmax(nrm, fabs(vn - 1));
        for (int i = 0; i < 4; i++) {
            double ar = 0, ai = 0, br = 0, bi = 0;               /* (A v)_i and (u^H A)_i = sum_k conj(u_k) A_ki */
            for (int k = 0; k < 4; k++) {
                ar += Eo[k * 4 + i] * vre[k]; ai += Eo[k * 4 + i] * vim[k];
                br += Eo[i * 4 + k] * ure[k]; bi -= Eo[i * 4 + k] * uim[k];
            }
            worst = fmax(worst, fabs(ar - (lr * vre[i] - li * vim[i])) + fabs(ai - (lr * vim[i] + li * vre[i])));
            worst = fmax(worst, fabs(br - (lr * ure[i] + li * uim[i])) + fabs(bi - (li * ure[i] - lr * uim[i])));
        }
    }
    CHECK(worst < 1e-9 && nrm < 1e-12, "dgeev: A v = lambda v, u^H A = lambda u^H, unit eigenvectors");
    float sE[] = {2, 0, 0, 3}, swr[2], swi[2], svr[4]; float sw[16]; __CLPK_integer slw = 16;
    sgeev_(&N_, &V_, &two, sE, &two, swr, swi, NULL, &one, svr, &two, sw, &slw, &info);
    CHECK(info == 0 && ((swr[0] == 2 && swr[1] == 3) || (swr[0] == 3 && swr[1] == 2)) && swi[0] == 0, "sgeev: right vectors only");

    /* banded: the 5x5 matrix with 4 on the diagonal, -1 below, 2 and 1 on the first two superdiagonals (kl 1, ku 2) */
    double D5[25] = {0};
    for (int i = 0; i < 5; i++) { D5[i * 5 + i] = 4; if (i + 1 < 5) D5[i * 5 + i + 1] = -1; if (i + 1 < 5) D5[(i + 1) * 5 + i] = 2; if (i + 2 < 5) D5[(i + 2) * 5 + i] = 1; }
    double xb[5] = {1, -2, 3, 0.5, 2}, bb[5] = {0}, AB[6 * 5] = {0};
    for (int i = 0; i < 5; i++) for (int j = 0; j < 5; j++) bb[i] += D5[j * 5 + i] * xb[j];
    __CLPK_integer kl = 1, ku = 2, ldab = 2 * 1 + 2 + 1, five = 5, bpiv[5];
    for (int j = 0; j < 5; j++) for (int i = 0; i < 5; i++) if (i - j <= kl && j - i <= ku) AB[j * ldab + kl + ku + i - j] = D5[j * 5 + i];
    double bsol[5]; memcpy(bsol, bb, sizeof bb);
    dgbsv_(&five, &kl, &ku, &one, AB, &ldab, bpiv, bsol, &five, &info);
    CHECK(info == 0 && close_d(bsol, xb, 5, 1e-12), "dgbsv: banded LU solves A x = b");
    double bt[5] = {0}; char T_ = 'T';
    for (int i = 0; i < 5; i++) for (int j = 0; j < 5; j++) bt[i] += D5[i * 5 + j] * xb[j];     /* A^T x */
    dgbtrs_(&T_, &five, &kl, &ku, &one, AB, &ldab, bpiv, bt, &five, &info);
    CHECK(info == 0 && close_d(bt, xb, 5, 1e-12), "dgbtrs 'T': A^T x = b with the same factors");
    /* pivoting: a zero on the diagonal */
    double Z3[9] = {0, 1, 0,  2, 0, 1,  0, 3, 1}, zb[3] = {2, 1, 4}, ZAB[4 * 3] = {0};  /* column-major, kl = ku = 1 */
    __CLPK_integer k1 = 1, ld4 = 4, zp[3];
    for (int j = 0; j < 3; j++) for (int i = 0; i < 3; i++) if (abs(i - j) <= 1) ZAB[j * 4 + 2 + i - j] = Z3[j * 3 + i];
    double zx[3]; memcpy(zx, zb, sizeof zb);
    dgbsv_(&three, &k1, &k1, &one, ZAB, &ld4, zp, zx, &three, &info);
    double zr[3] = {0};
    for (int i = 0; i < 3; i++) for (int j = 0; j < 3; j++) zr[i] += Z3[j * 3 + i] * zx[j];
    CHECK(info == 0 && close_d(zr, zb, 3, 1e-12), "dgbsv: row interchanges");
    /* positive-definite band (tridiagonal 2, -1): upper and lower storage */
    double PU[2 * 4], PL[2 * 4], pb[4] = {1, 0, 0, 1}, pu[4], pl[4];
    for (int j = 0; j < 4; j++) { PU[j * 2 + 1] = 2; PU[j * 2] = j ? -1 : 0; PL[j * 2] = 2; PL[j * 2 + 1] = j < 3 ? -1 : 0; }
    memcpy(pu, pb, sizeof pb); memcpy(pl, pb, sizeof pb);
    __CLPK_integer kd = 1, ld2 = 2;
    dpbsv_(&U_, &four, &kd, &one, PU, &ld2, pu, &four, &info);
    __CLPK_integer info2;
    dpbsv_(&L_, &four, &kd, &one, PL, &ld2, pl, &four, &info2);
    CHECK(info == 0 && info2 == 0 && close_d(pu, (double[]){1, 1, 1, 1}, 4, 1e-12) && close_d(pl, (double[]){1, 1, 1, 1}, 4, 1e-12),
          "dpbsv: upper and lower band Cholesky");
    double nb[2 * 2] = {0, 1, 2, 1}; __CLPK_integer two_ = 2;          /* [[1, 2], [2, 1]] upper band: not positive definite */
    dpbtrf_(&U_, &two_, &kd, nb, &ld2, &info);
    CHECK(info == 2, "dpbtrf: not positive definite");
    double dl[3] = {1, 1, 1}, dd[4] = {0, 2, 2, 2}, du[3] = {1, 1, 1}, tb[4], tx[4] = {1, 2, 3, 4};
    tb[0] = dd[0] * tx[0] + du[0] * tx[1];
    for (int i = 1; i < 3; i++) tb[i] = dl[i - 1] * tx[i - 1] + dd[i] * tx[i] + du[i] * tx[i + 1];
    tb[3] = dl[2] * tx[2] + dd[3] * tx[3];
    dgtsv_(&four, &one, dl, dd, du, tb, &four, &info);
    CHECK(info == 0 && close_d(tb, tx, 4, 1e-12), "dgtsv: tridiagonal with a zero leading diagonal (pivots)");
    float fdl[1] = {1}, fd[2] = {2, 2}, fdu[1] = {1}, fb2[2] = {3, 3};
    sgtsv_(&two, &one, fdl, fd, fdu, fb2, &two, &info);
    CHECK(info == 0 && fabsf(fb2[0] - 1) < 1e-6f && fabsf(fb2[1] - 1) < 1e-6f, "sgtsv");

    /* complex: A (column-major) = [[2, 1+i], [1-i, 3]] (Hermitian positive definite, eigenvalues 1 and 4) */
    __CLPK_doublecomplex H[4] = {{2, 0}, {1, -1}, {1, 1}, {3, 0}}, Ho[4], hb[2], hx[2] = {{1, 2}, {-1, 0.5}};
    memcpy(Ho, H, sizeof H);
    for (int i = 0; i < 2; i++) {
        double re = 0, im = 0;
        for (int k = 0; k < 2; k++) { __CLPK_doublecomplex aa = Ho[k * 2 + i], xx = hx[k]; re += aa.r * xx.r - aa.i * xx.i; im += aa.r * xx.i + aa.i * xx.r; }
        hb[i].r = re; hb[i].i = im;
    }
    __CLPK_doublecomplex sol[2]; __CLPK_integer zp2[2];
    memcpy(sol, hb, sizeof hb);
    zgesv_(&two, &one, H, &two, zp2, sol, &two, &info);
    CHECK(info == 0 && close_z((zc *)sol, (zc *)hx, 2, 1e-12), "zgesv");
    memcpy(H, Ho, sizeof H); memcpy(sol, hb, sizeof hb);
    zposv_(&U_, &two, &one, H, &two, sol, &two, &info);
    CHECK(info == 0 && close_z((zc *)sol, (zc *)hx, 2, 1e-12), "zposv (upper)");
    memcpy(H, Ho, sizeof H); memcpy(sol, hb, sizeof hb);
    zposv_(&L_, &two, &one, H, &two, sol, &two, &info);
    CHECK(info == 0 && close_z((zc *)sol, (zc *)hx, 2, 1e-12), "zposv (lower)");
    memcpy(H, Ho, sizeof H);
    double hw[2], rw[8]; __CLPK_doublecomplex zw[16]; __CLPK_integer zlw = 16;
    zheev_(&V_, &L_, &two, H, &two, hw, zw, &zlw, rw, &info);
    worst = 0;
    for (int j = 0; j < 2; j++)
        for (int i = 0; i < 2; i++) {
            double re = 0, im = 0;
            for (int k = 0; k < 2; k++) { __CLPK_doublecomplex aa = Ho[k * 2 + i], vv = H[j * 2 + k]; re += aa.r * vv.r - aa.i * vv.i; im += aa.r * vv.i + aa.i * vv.r; }
            worst = fmax(worst, fabs(re - hw[j] * H[j * 2 + i].r) + fabs(im - hw[j] * H[j * 2 + i].i));
        }
    CHECK(info == 0 && fabs(hw[0] - 1) < 1e-12 && fabs(hw[1] - 4) < 1e-12 && worst < 1e-12, "zheev: eigenvalues 1, 4 and A v = lambda v");
    __CLPK_complex cA[4] = {{0, 1}, {1, 0}, {2, 0}, {0, -1}}, cb[2] = {{2, 1}, {1, -1}}; __CLPK_integer cp[2];   /* [[i, 2], [1, -i]] x = b */
    cgesv_(&two, &one, cA, &two, cp, cb, &two, &info);
    __CLPK_complex cAo[4] = {{0, 1}, {1, 0}, {2, 0}, {0, -1}}; float cr = 0, ci = 0, err = 0;
    for (int i = 0; i < 2; i++) {
        cr = 0; ci = 0;
        for (int k = 0; k < 2; k++) { cr += cAo[k * 2 + i].r * cb[k].r - cAo[k * 2 + i].i * cb[k].i; ci += cAo[k * 2 + i].r * cb[k].i + cAo[k * 2 + i].i * cb[k].r; }
        float er = i == 0 ? 2 : 1, ei = i == 0 ? 1 : -1;
        err = fmaxf(err, fabsf(cr - er) + fabsf(ci - ei));
    }
    CHECK(info == 0 && err < 1e-5f, "cgesv");
}

/* more vDSP (issue #543): FFT forms against the reference DFT, the 2D real packing, biquads against their recurrence */
static void vdsp_more(void) {
    /* radix 3 and 5 */
    for (int radix = 3; radix <= 5; radix += 2) {
        int n = radix * 4;
        double re[20], im[20], rr[20], ri[20]; float fr[20], fi[20], orr[20], oi[20];
        for (int i = 0; i < n; i++) { re[i] = sin(i * 0.7) + i % 3; im[i] = cos(i * 1.3); fr[i] = (float)re[i]; fi[i] = (float)im[i]; }
        dft(re, im, rr, ri, n, -1);
        FFTSetup st = vDSP_create_fftsetup(2, radix == 3 ? kFFTRadix3 : kFFTRadix5);
        DSPSplitComplex a = {fr, fi}, c = {orr, oi};
        if (radix == 3) vDSP_fft3_zop(st, &a, 1, &c, 1, 2, kFFTDirection_Forward); else vDSP_fft5_zop(st, &a, 1, &c, 1, 2, kFFTDirection_Forward);
        vDSP_destroy_fftsetup(st);
        CHECK(st && close_f(orr, rr, n, 1e-4) && close_f(oi, ri, n, 1e-4), radix == 3 ? "vDSP_fft3_zop: 12 points" : "vDSP_fft5_zop: 20 points");
    }
    /* multiple signals: 3 signals of 8, signal stride 10 */
    double mre[30] = {0}, mim[30] = {0};
    for (int m = 0; m < 3; m++) for (int i = 0; i < 8; i++) { mre[m * 10 + i] = m + i * 0.5; mim[m * 10 + i] = (i % 2) - m; }
    FFTSetupD sd = vDSP_create_fftsetupD(4, kFFTRadix2);
    DSPDoubleSplitComplex mc = {mre, mim};
    vDSP_fftm_zipD(sd, &mc, 1, 10, 3, 3, kFFTDirection_Forward);
    int ok = 1;
    for (int m = 0; m < 3; m++) {
        double ir[8], ii[8], orr[8], oi[8];
        for (int i = 0; i < 8; i++) { ir[i] = m + i * 0.5; ii[i] = (i % 2) - m; }
        dft(ir, ii, orr, oi, 8, -1);
        ok &= close_d(mre + m * 10, orr, 8, 1e-12) && close_d(mim + m * 10, oi, 8, 1e-12);
    }
    CHECK(ok, "vDSP_fftm_zipD: each signal's FFT");
    /* fftm_zrop equals fft_zrop per signal */
    double xr[8] = {1, 3, 5, 7, 2, 4, 6, 8}, xi[8] = {2, 4, 6, 8, 1, 3, 5, 7}, yr[8], yi[8], zr[4], zi[4];
    DSPDoubleSplitComplex xa = {xr, xi}, ya = {yr, yi};
    vDSP_fftm_zropD(sd, &xa, 1, 4, &ya, 1, 4, 3, 2, kFFTDirection_Forward);
    DSPDoubleSplitComplex x1 = {xr + 4, xi + 4}, z1 = {zr, zi};
    vDSP_fft_zropD(sd, &x1, 1, &z1, 1, 3, kFFTDirection_Forward);
    CHECK(close_d(yr + 4, zr, 4, 1e-12) && close_d(yi + 4, zi, 4, 1e-12), "vDSP_fftm_zropD: the second signal equals vDSP_fft_zropD");
    /* 2D complex 4 x 8 against the naive 2D DFT */
    enum { R = 4, Cn = 8 };
    double gr[R * Cn], gi[R * Cn], wr[R * Cn] = {0}, wi[R * Cn] = {0};
    for (int i = 0; i < R * Cn; i++) { gr[i] = sin(i * 0.37); gi[i] = (i % 5) * 0.25; }
    for (int u = 0; u < R; u++) for (int v = 0; v < Cn; v++)
        for (int r = 0; r < R; r++) for (int c = 0; c < Cn; c++) {
            double t = -2 * M_PI * ((double)u * r / R + (double)v * c / Cn);
            wr[u * Cn + v] += gr[r * Cn + c] * cos(t) - gi[r * Cn + c] * sin(t);
            wi[u * Cn + v] += gr[r * Cn + c] * sin(t) + gi[r * Cn + c] * cos(t);
        }
    double hr[R * Cn], hi[R * Cn]; memcpy(hr, gr, sizeof gr); memcpy(hi, gi, sizeof gi);
    DSPDoubleSplitComplex g2 = {hr, hi};
    vDSP_fft2d_zipD(sd, &g2, 1, 0, 3, 2, kFFTDirection_Forward);
    CHECK(close_d(hr, wr, R * Cn, 1e-10) && close_d(hi, wi, R * Cn, 1e-10), "vDSP_fft2d_zipD: 4 rows of 8 against the 2D DFT");
    /* 2D real 4 x 8 (4 complex per row): packing and the round trip */
    double img[R * Cn], pr[R * Cn / 2], pi_[R * Cn / 2], fr2[R * Cn] = {0}, fi2[R * Cn] = {0};
    for (int i = 0; i < R * Cn; i++) img[i] = cos(i * 0.21) + (i % 3);
    for (int u = 0; u < R; u++) for (int v = 0; v < Cn; v++)
        for (int r = 0; r < R; r++) for (int c = 0; c < Cn; c++) {
            double t = -2 * M_PI * ((double)u * r / R + (double)v * c / Cn);
            fr2[u * Cn + v] += img[r * Cn + c] * cos(t); fi2[u * Cn + v] += img[r * Cn + c] * sin(t);
        }
    for (int i = 0; i < R * Cn / 2; i++) { pr[i] = img[2 * i]; pi_[i] = img[2 * i + 1]; }
    DSPDoubleSplitComplex p2 = {pr, pi_};
    vDSP_fft2d_zripD(sd, &p2, 1, 0, 3, 2, kFFTDirection_Forward);
    ok = fabs(pr[0] - 2 * fr2[0]) < 1e-10 && fabs(pr[4] - 2 * fr2[2 * Cn]) < 1e-10                  /* DC column: rows 0, 1 = bins 0, R/2 */
         && fabs(pr[8] - 2 * fr2[1 * Cn]) < 1e-10 && fabs(pr[12] - 2 * fi2[1 * Cn]) < 1e-10          /* rows 2, 3 = bin 1 */
         && fabs(pi_[0] - 2 * fr2[4]) < 1e-10 && fabs(pi_[4] - 2 * fr2[2 * Cn + 4]) < 1e-10;         /* Nyquist column */
    for (int u = 0; u < R; u++) for (int k = 1; k < 4; k++)
        ok &= fabs(pr[u * 4 + k] - 2 * fr2[u * Cn + k]) < 1e-10 && fabs(pi_[u * 4 + k] - 2 * fi2[u * Cn + k]) < 1e-10;
    CHECK(ok, "vDSP_fft2d_zripD: twice the 2D DFT, DC and Nyquist columns packed down their columns");
    vDSP_fft2d_zripD(sd, &p2, 1, 0, 3, 2, kFFTDirection_Inverse);
    ok = 1;
    for (int i = 0; i < R * Cn / 2; i++) ok &= fabs(pr[i] - 2 * R * Cn * img[2 * i]) < 1e-9 && fabs(pi_[i] - 2 * R * Cn * img[2 * i + 1]) < 1e-9;
    CHECK(ok, "vDSP_fft2d_zripD: the round trip gives 2 * rows * columns * x");
    vDSP_destroy_fftsetupD(sd);
    /* interleaved DFT */
    DSPComplex iv[16], ov[16]; double ir2[16], ii2[16], or2[16], oi2[16];
    for (int i = 0; i < 16; i++) { iv[i].real = (float)(i % 4); iv[i].imag = (float)sin(i); ir2[i] = iv[i].real; ii2[i] = iv[i].imag; }
    dft(ir2, ii2, or2, oi2, 16, -1);
    vDSP_DFT_Interleaved_Setup is = vDSP_DFT_Interleaved_CreateSetup(NULL, 16, vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_ComplextoComplex);
    vDSP_DFT_Interleaved_Execute(is, iv, ov);
    vDSP_DFT_Interleaved_DestroySetup(is);
    ok = is != NULL;
    for (int i = 0; i < 16; i++) ok &= fabs(ov[i].real - or2[i]) < 1e-4 && fabs(ov[i].imag - oi2[i]) < 1e-4;
    CHECK(ok, "vDSP_DFT_Interleaved_Execute: complex");
    CHECK(vDSP_DFT_Interleaved_CreateSetup(NULL, 7, vDSP_DFT_FORWARD, vDSP_DFT_Interleaved_ComplextoComplex) == NULL, "vDSP_DFT_Interleaved_CreateSetup: unsupported length");

    /* biquads: a two-section filter, against the recurrence; state carries across calls */
    double coef[10] = {0.2, 0.3, 0.1, -0.5, 0.25,  1, -0.4, 0.2, 0.1, -0.05};
    double x[12], ref[12], s1[12];
    for (int i = 0; i < 12; i++) x[i] = (i == 0) + 0.5 * sin(i);
    for (int sec = 0; sec < 2; sec++) {
        const double *c = coef + 5 * sec; const double *in = sec ? s1 : x; double *out = sec ? ref : s1;
        for (int n = 0; n < 12; n++) {
            double v = c[0] * in[n];
            if (n >= 1) v += c[1] * in[n - 1] - c[3] * out[n - 1];
            if (n >= 2) v += c[2] * in[n - 2] - c[4] * out[n - 2];
            out[n] = v;
        }
    }
    vDSP_biquad_SetupD bq = vDSP_biquad_CreateSetupD(coef, 2);
    double delay[6] = {0}, y[12];
    vDSP_biquadD(bq, delay, x, 1, y, 1, 5);
    vDSP_biquadD(bq, delay, x + 5, 1, y + 5, 1, 7);
    CHECK(bq && close_d(y, ref, 12, 1e-12) && fabs(delay[4] - ref[11]) < 1e-12 && fabs(delay[5] - ref[10]) < 1e-12,
          "vDSP_biquadD: two sections, split across calls; Delay ends with the last outputs");
    vDSP_biquad_DestroySetupD(bq);
    float fx[12], fy[12], fd[6] = {0};
    for (int i = 0; i < 12; i++) fx[i] = (float)x[i];
    vDSP_biquad_Setup fbq = vDSP_biquad_CreateSetup(coef, 2);
    vDSP_biquad(fbq, fd, fx, 1, fy, 1, 12);
    vDSP_biquad_DestroySetup(fbq);
    CHECK(close_f(fy, ref, 12, 1e-5), "vDSP_biquad (single precision)");
    /* multichannel: channel 0 uses the two sections, channel 1 a pass-through and a gain of 2; coefficients interleaved by channel */
    double mcoef[20];
    double ch1[10] = {1, 0, 0, 0, 0,  2, 0, 0, 0, 0};
    for (int sec = 0; sec < 2; sec++) for (int k = 0; k < 5; k++) { mcoef[(sec * 5 + k) * 2] = coef[sec * 5 + k]; mcoef[(sec * 5 + k) * 2 + 1] = ch1[sec * 5 + k]; }
    vDSP_biquadm_SetupD bqm = vDSP_biquadm_CreateSetupD(mcoef, 2, 2);
    double out0[12], out1[12]; const double *ins[2] = {x, x}; double *outs[2] = {out0, out1};
    vDSP_biquadmD(bqm, ins, 1, outs, 1, 12);
    ok = close_d(out0, ref, 12, 1e-12);
    for (int i = 0; i < 12; i++) ok &= fabs(out1[i] - 2 * x[i]) < 1e-12;
    CHECK(bqm && ok, "vDSP_biquadmD: per-channel sections from channel-interleaved coefficients");
    vDSP_biquadm_DestroySetupD(bqm);

    /* DCT: II against its definition, III undoes II up to N / 2 */
    float dx[16], dX[16], dback[16]; double dref[16];
    for (int i = 0; i < 16; i++) dx[i] = (float)(i + 1);
    for (int k = 0; k < 16; k++) { dref[k] = 0; for (int j = 0; j < 16; j++) dref[k] += dx[j] * cos(M_PI / 16 * (j + 0.5) * k); }
    vDSP_DFT_Setup d2 = vDSP_DCT_CreateSetup(NULL, 16, vDSP_DCT_II), d3 = vDSP_DCT_CreateSetup(d2, 16, vDSP_DCT_III);
    vDSP_DCT_Execute(d2, dx, dX);
    vDSP_DCT_Execute(d3, dX, dback);
    ok = d2 && d3 && close_f(dX, dref, 16, 1e-5);
    for (int i = 0; i < 16; i++) ok &= fabsf(dback[i] - 8 * dx[i]) < 1e-3f;
    CHECK(ok, "vDSP_DCT_Execute: DCT-II, and DCT-III(DCT-II(x)) = N/2 x");
    vDSP_DFT_DestroySetup(d2); vDSP_DFT_DestroySetup(d3);
    CHECK(vDSP_DCT_CreateSetup(NULL, 8, vDSP_DCT_II) == NULL, "vDSP_DCT_CreateSetup: lengths below 16 are refused");

    /* vector functions */
    float va[] = {3, -4, 1.5f, -0.25f}, vb[] = {4, 3, 2, 1}, vc[8], vd[8];
    vDSP_vdist(va, 1, vb, 1, vc, 1, 4);
    CHECK(vc[0] == 5 && vc[1] == 5, "vDSP_vdist");
    float mean, sd2;
    vDSP_normalize((float[]){2, 4, 4, 4, 5, 5, 7, 9}, 1, vc, 1, &mean, &sd2, 8);
    float nmean, nsd;
    vDSP_normalize((float[]){2, 4, 4, 4, 5, 5, 7, 9}, 1, NULL, 1, &nmean, &nsd, 8);
    CHECK(mean == 5 && sd2 == 2 && vc[0] == -1.5f && nmean == 5 && nsd == 2, "vDSP_normalize: population deviation, NULL output");
    vDSP_vpoly((float[]){2, -3, 1}, 1, (float[]){0, 1, 2, 3}, 1, vc, 1, 4, 2);   /* 2x^2 - 3x + 1 */
    CHECK(vc[0] == 1 && vc[1] == 0 && vc[2] == 3 && vc[3] == 10, "vDSP_vpoly: highest order first");
    float h = 1;
    vDSP_vtrapz((float[]){0, 1, 2, 3}, 1, &h, vc, 1, 4);
    vDSP_vsimps((float[]){0, 1, 4, 9, 16}, 1, &h, vd, 1, 4);
    CHECK(vc[3] == 4.5f && fabsf(vd[2] - 8.0f / 3) < 1e-6f, "vDSP_vtrapz, vDSP_vsimps");
    vDSP_vrsum((float[]){5, 1, 2, 3}, 1, &h, vc, 1, 4);
    CHECK(vc[0] == 0 && vc[3] == 6, "vDSP_vrsum: C[0] = 0, skips A[0]");
    vDSP_vswsum((float[]){1, 2, 3, 4, 5}, 1, vc, 1, 3, 3);
    CHECK(vc[0] == 6 && vc[2] == 12, "vDSP_vswsum");
    vDSP_Length idx[] = {4, 1};
    vDSP_vgathr((float[]){10, 20, 30, 40}, idx, 1, vc, 1, 2);
    CHECK(vc[0] == 40 && vc[1] == 10, "vDSP_vgathr: 1-based indices");
    float lo = -1, hi2 = 1;
    vDSP_viclip((float[]){-2, -0.5f, 0.5f, 2}, 1, &lo, &hi2, vc, 1, 4);
    CHECK(vc[0] == -2 && vc[1] == -1 && vc[2] == 1 && vc[3] == 2, "vDSP_viclip");
    float ref1 = 1;
    vDSP_vdbcon((float[]){10, 100}, 1, &ref1, vc, 1, 2, 1);
    CHECK(fabsf(vc[0] - 20) < 1e-5f && fabsf(vc[1] - 40) < 1e-5f, "vDSP_vdbcon: amplitude");
    float st = 1, step = 0.5f;
    vDSP_vrampmul((float[]){2, 2, 2}, 1, &st, &step, vc, 1, 3);
    CHECK(vc[0] == 2 && vc[2] == 4 && st == 2.5f, "vDSP_vrampmul: updates the start");
    float pol[4], rect[4];
    vDSP_polar((float[]){0, 2, -3, 0}, 2, pol, 2, 2);
    vDSP_rect(pol, 2, rect, 2, 2);
    CHECK(pol[0] == 2 && fabsf(pol[1] - (float)M_PI_2) < 1e-6f && fabsf(rect[2] + 3) < 1e-5f, "vDSP_polar, vDSP_rect");
    vDSP_Length last, count;
    vDSP_nzcros((float[]){1, -1, -2, 3, 4, -1}, 1, 10, &last, &count, 6);
    CHECK(count == 3 && last == 5, "vDSP_nzcros");
    vDSP_vaddsub(vb, 1, va, 1, vc, 1, vd, 1, 4);
    CHECK(vc[0] == 7 && vd[0] == -1, "vDSP_vaddsub: O0 = I1 + I0, O1 = I1 - I0");
    double dq[6] = {0, 0, 1, 2, 3, 4}, dco[5] = {1, 0, 0, 0.5, 0}, dout[6] = {0};
    vDSP_deq22D(dq, 1, dco, dout, 1, 4);
    CHECK(dout[2] == 1 && dout[3] == 1.5 && dout[4] == 2.25, "vDSP_deq22D");
}

/* Quadrature (issue #543) */
static void f_sin(void *arg, size_t n, const double *x, double *y) { (void)arg; for (size_t i = 0; i < n; i++) y[i] = sin(x[i]); }
static void f_rsqrt(void *arg, size_t n, const double *x, double *y) { (*(int *)arg)++; for (size_t i = 0; i < n; i++) y[i] = 1 / sqrt(x[i]); }
static void f_poly(void *arg, size_t n, const double *x, double *y) { (void)arg; for (size_t i = 0; i < n; i++) y[i] = 3 * x[i] * x[i] + 1; }
static void f_nan(void *arg, size_t n, const double *x, double *y) { (void)arg; for (size_t i = 0; i < n; i++) y[i] = x[i] > 0.5 ? NAN : 1; }
static void quadrature(void) {
    quadrature_integrate_function fs = {f_sin, NULL}, fp = {f_poly, NULL}, fn = {f_nan, NULL};
    int calls = 0;
    quadrature_integrate_function fr = {f_rsqrt, &calls};
    quadrature_integrate_options o = {QUADRATURE_INTEGRATE_QNG, 1e-10, 0, 0, 0};
    quadrature_status st; double err;
    double v = quadrature_integrate(&fp, 0, 2, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_SUCCESS && fabs(v - 10) < 1e-12, "quadrature QNG: a polynomial exactly");
    o.integrator = QUADRATURE_INTEGRATE_QAG; o.qag_points_per_interval = 21; o.max_intervals = 20;
    v = quadrature_integrate(&fs, 0, M_PI, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_SUCCESS && fabs(v - 2) < 1e-12 && err <= 1e-10, "quadrature QAG: sin over [0, pi]");
    v = quadrature_integrate(&fs, M_PI, 0, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_SUCCESS && fabs(v + 2) < 1e-12, "quadrature: reversed bounds change the sign");
    o.integrator = QUADRATURE_INTEGRATE_QAGS; o.max_intervals = 200; o.abs_tolerance = 1e-9;
    v = quadrature_integrate(&fr, 0, 1, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_SUCCESS && fabs(v - 2) < 1e-8 && calls > 1, "quadrature QAGS: 1/sqrt(x) over [0, 1] (end-point singularity)");
    o.max_intervals = 3;
    v = quadrature_integrate(&fr, 0, 1, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_INTEGRATE_MAX_EVAL_ERROR, "quadrature: too few intervals");
    o.integrator = QUADRATURE_INTEGRATE_QAG; o.qag_points_per_interval = 17;
    quadrature_integrate(&fs, 0, 1, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_INVALID_ARG_ERROR, "quadrature: invalid points per interval");
    o.qag_points_per_interval = 61; o.max_intervals = 10;
    quadrature_integrate(&fn, 0, 1, &o, &st, &err, 0, NULL);
    CHECK(st == QUADRATURE_INTEGRATE_BAD_BEHAVIOUR_ERROR, "quadrature: a non-finite integrand");
}

void newlapack(int *checks, int *failures);   /* newlapack.c, compiled with ACCELERATE_NEW_LAPACK */
void ilp64(int *checks, int *failures);       /* ilp64.c, with ACCELERATE_LAPACK_ILP64 too */
void sparse_solvers(int *checks, int *failures);   /* sparse.c: Sparse Solvers (issue #807) */
void sparse_blas(int *checks, int *failures);      /* sparse_blas.c: Sparse BLAS (issue #819) */

static void vforce(void) {
    double x[] = {0.5, 1, 2, 4}, y[] = {2, 3, 0.5, -1}, z[4]; int n = 4;
    vvsqrt(z, x, &n);
    CHECK(close_d(z, (double[]){sqrt(0.5), 1, sqrt(2), 2}, 4, 1e-15), "vvsqrt");
    vvpow(z, y, x, &n);
    CHECK(close_d(z, (double[]){0.25, 1, sqrt(2), 0.25}, 4, 1e-15), "vvpow: x ^ y, exponents first");
    vvdiv(z, y, x, &n);
    CHECK(close_d(z, (double[]){4, 3, 0.25, -0.25}, 4, 1e-15), "vvdiv: y / x");
    vvatan2(z, y, x, &n);
    CHECK(fabs(z[0] - atan2(2, 0.5)) < 1e-15, "vvatan2: atan2(y, x)");
    float fx[] = {0, 0.5f, 1.5f, -2.5f}, fz[4], fc[4];
    vvsincosf(fz, fc, fx, &n);
    CHECK(fz[0] == 0 && fc[0] == 1 && fabsf(fz[1] - sinf(0.5f)) < 1e-7f, "vvsincosf");
    vvnintf(fz, fx, &n);
    CHECK(fz[2] == 2 && fz[3] == -2, "vvnintf: to nearest even");
    vvintf(fz, fx, &n);
    CHECK(fz[2] == 1 && fz[3] == -2, "vvintf: truncation");
    vvrecf(fz, (float[]){2, 4, 0.5f, -1}, &n);
    CHECK(fz[0] == 0.5f && fz[2] == 2, "vvrecf");
    float e3 = 3; vvpowsf(fz, &e3, (float[]){1, 2, 3, 4}, &n);
    CHECK(fz[3] == 64, "vvpowsf");
}

int main(void) {
    blas();
    lapack();
    vdsp();
    ffts();
    complex_blas();
    lapack_more();
    newlapack(&checks, &failures);
    ilp64(&checks, &failures);
    sparse_solvers(&checks, &failures);
    sparse_blas(&checks, &failures);
    vdsp_more();
    quadrature();
    vforce();
    printf("accelerate c: %d/%d passed\n", checks - failures, checks);
    return failures != 0;
}
