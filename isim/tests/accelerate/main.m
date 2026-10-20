// Accelerate from C (AccelerateCTest.app, issue #279): BLAS, LAPACK, vDSP and vForce, checked against references
// computed here in double (naive sums, a naive DFT) and against identities (A A^-1 = I, A v = lambda v, ...).
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
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
    vforce();
    printf("accelerate c: %d/%d passed\n", checks - failures, checks);
    return failures != 0;
}
