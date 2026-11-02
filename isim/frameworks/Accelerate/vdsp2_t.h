/* isim Accelerate: more of vDSP for one element type (issue #543), included by vdsp.c after vdsp_t.h with the same
   T / D / CT / SCT / FT. Adapted: the FFTs reuse isim_cfft (double, any length); packing and scaling are Apple's
   ("Understanding data packing for Fourier transforms"). */
#define V2(n, d) vDSP_##n##d
#define V1(n, d) V2(n, d)
#define V(n) V1(n, D)
#define AT(p, i, s) (p)[(long)(i) * (s)]

/* ---------------- FFT variants ---------------- */
/* a complex FFT of n values at stride s (in place or from A to C) */
static void V(_cfft_strided)(const SCT *A, long ia, const SCT *C, long ic, size_t n, int sign) {
    double *re = malloc(sizeof(double) * (n ? n : 1) * 2), *im = re + (n ? n : 1);
    for (size_t i = 0; i < n; i++) { re[i] = A->realp[(long)i * ia]; im[i] = A->imagp[(long)i * ia]; }
    isim_cfft(re, im, n, sign);
    for (size_t i = 0; i < n; i++) { C->realp[(long)i * ic] = (T)re[i]; C->imagp[(long)i * ic] = (T)im[i]; }
    free(re);
}
static void V(_rfft_strided)(const SCT *A, long ia, const SCT *C, long ic, size_t half, int forward) {
    double *re = malloc(sizeof(double) * (half ? half : 1) * 2), *im = re + (half ? half : 1);
    for (size_t i = 0; i < half; i++) { re[i] = A->realp[(long)i * ia]; im[i] = A->imagp[(long)i * ia]; }
    if (forward) isim_rfft_packed_forward(re, im, half); else isim_rfft_packed_inverse(re, im, half);
    for (size_t i = 0; i < half; i++) { C->realp[(long)i * ic] = (T)re[i]; C->imagp[(long)i * ic] = (T)im[i]; }
    free(re);
}
#define SIGN(d) ((d) == kFFTDirection_Forward ? -1 : +1)
void V(fft_zipt)(FT Setup, const SCT *C, vDSP_Stride IC, const SCT *Buffer, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; (void)Buffer; V(_cfft_strided)(C, IC, C, IC, (size_t)1 << Log2N, SIGN(Direction));
}
void V(fft_zopt)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, const SCT *Buffer, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; (void)Buffer; V(_cfft_strided)(A, IA, C, IC, (size_t)1 << Log2N, SIGN(Direction));
}
void V(fft_zript)(FT Setup, const SCT *C, vDSP_Stride IC, const SCT *Buffer, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; (void)Buffer; if (Log2N > 0) V(_rfft_strided)(C, IC, C, IC, (size_t)1 << (Log2N - 1), Direction == kFFTDirection_Forward);
}
void V(fft_zropt)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, const SCT *Buffer, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; (void)Buffer; if (Log2N > 0) V(_rfft_strided)(A, IA, C, IC, (size_t)1 << (Log2N - 1), Direction == kFFTDirection_Forward);
}
/* radix 3 and 5: lengths 3 * 2^n and 5 * 2^n */
void V(fft3_zop)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; V(_cfft_strided)(A, IA, C, IC, (size_t)3 << Log2N, SIGN(Direction));
}
void V(fft5_zop)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; V(_cfft_strided)(A, IA, C, IC, (size_t)5 << Log2N, SIGN(Direction));
}
/* multiple signals: M signals of 2^Log2N, element stride I, signal stride IM (in elements) */
void V(fftm_zop)(FT Setup, const SCT *A, vDSP_Stride IA, vDSP_Stride IMA, const SCT *C, vDSP_Stride IC, vDSP_Stride IMC, vDSP_Length Log2N,
                 vDSP_Length M, FFTDirection Direction) {
    (void)Setup;
    for (vDSP_Length m = 0; m < M; m++) {
        SCT a = { A->realp + (long)m * IMA, A->imagp + (long)m * IMA }, c = { C->realp + (long)m * IMC, C->imagp + (long)m * IMC };
        V(_cfft_strided)(&a, IA, &c, IC, (size_t)1 << Log2N, SIGN(Direction));
    }
}
void V(fftm_zip)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Stride IM, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    V(fftm_zop)(Setup, C, IC, IM, C, IC, IM, Log2N, M, Direction);
}
void V(fftm_zopt)(FT Setup, const SCT *A, vDSP_Stride IA, vDSP_Stride IMA, const SCT *C, vDSP_Stride IC, vDSP_Stride IMC, const SCT *Buffer,
                  vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    (void)Buffer; V(fftm_zop)(Setup, A, IA, IMA, C, IC, IMC, Log2N, M, Direction);
}
void V(fftm_zipt)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Stride IM, const SCT *Buffer, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    (void)Buffer; V(fftm_zop)(Setup, C, IC, IM, C, IC, IM, Log2N, M, Direction);
}
void V(fftm_zrop)(FT Setup, const SCT *A, vDSP_Stride IA, vDSP_Stride IMA, const SCT *C, vDSP_Stride IC, vDSP_Stride IMC, vDSP_Length Log2N,
                  vDSP_Length M, FFTDirection Direction) {
    (void)Setup;
    if (Log2N == 0) return;
    for (vDSP_Length m = 0; m < M; m++) {
        SCT a = { A->realp + (long)m * IMA, A->imagp + (long)m * IMA }, c = { C->realp + (long)m * IMC, C->imagp + (long)m * IMC };
        V(_rfft_strided)(&a, IA, &c, IC, (size_t)1 << (Log2N - 1), Direction == kFFTDirection_Forward);
    }
}
void V(fftm_zrip)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Stride IM, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    V(fftm_zrop)(Setup, C, IC, IM, C, IC, IM, Log2N, M, Direction);
}
void V(fftm_zropt)(FT Setup, const SCT *A, vDSP_Stride IA, vDSP_Stride IMA, const SCT *C, vDSP_Stride IC, vDSP_Stride IMC, const SCT *Buffer,
                   vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    (void)Buffer; V(fftm_zrop)(Setup, A, IA, IMA, C, IC, IMC, Log2N, M, Direction);
}
void V(fftm_zript)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Stride IM, const SCT *Buffer, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction) {
    (void)Buffer; V(fftm_zrop)(Setup, C, IC, IM, C, IC, IM, Log2N, M, Direction);
}

/* 2D complex: 2^Log2N1 rows of 2^Log2N0 elements; IA0 / IC0 the element stride, IA1 / IC1 the row stride (0: rows
   follow each other). Each row, then each column. */
void V(fft2d_zop)(FT Setup, const SCT *A, vDSP_Stride IA0, vDSP_Stride IA1, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1,
                  vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    (void)Setup;
    size_t n0 = (size_t)1 << Log2N0, n1 = (size_t)1 << Log2N1;
    long ra = IA1 ? IA1 : IA0 * (long)n0, rc = IC1 ? IC1 : IC0 * (long)n0;
    for (size_t r = 0; r < n1; r++) {
        SCT a = { A->realp + (long)r * ra, A->imagp + (long)r * ra }, c = { C->realp + (long)r * rc, C->imagp + (long)r * rc };
        V(_cfft_strided)(&a, IA0, &c, IC0, n0, SIGN(Direction));
    }
    for (size_t k = 0; k < n0; k++) {
        SCT c = { C->realp + (long)k * IC0, C->imagp + (long)k * IC0 };
        V(_cfft_strided)(&c, rc, &c, rc, n1, SIGN(Direction));
    }
}
void V(fft2d_zip)(FT Setup, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    V(fft2d_zop)(Setup, C, IC0, IC1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
void V(fft2d_zopt)(FT Setup, const SCT *A, vDSP_Stride IA0, vDSP_Stride IA1, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, const SCT *Buffer,
                   vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    (void)Buffer; V(fft2d_zop)(Setup, A, IA0, IA1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
void V(fft2d_zipt)(FT Setup, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, const SCT *Buffer, vDSP_Length Log2N0, vDSP_Length Log2N1,
                   FFTDirection Direction) {
    (void)Buffer; V(fft2d_zop)(Setup, C, IC0, IC1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
/* 2D real: 2^Log2N1 rows of 2^Log2N0 real values packed even/odd (2^(Log2N0 - 1) complex per row). Rows first, packed
   as 1D (DC in realp, Nyquist in imagp of each row's element 0); then columns: complex columns with the complex
   FFT, and the DC (realp) and Nyquist (imagp) columns of element 0 as real sequences, each packed down its column as
   the 1D real format (row pairs 2k, 2k + 1 hold bin k; rows 0 and 1 the column's DC and Nyquist). Forward: twice the
   2D DFT; inverse: unscaled (a round trip gives 2 * rows * columns). */
void V(fft2d_zrop)(FT Setup, const SCT *A, vDSP_Stride IA0, vDSP_Stride IA1, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1,
                   vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    (void)Setup;
    if (Log2N0 == 0) return;
    size_t w = (size_t)1 << (Log2N0 - 1), rows = (size_t)1 << Log2N1, nc = 2 * w;
    long ra = IA1 ? IA1 : IA0 * (long)w, rc = IC1 ? IC1 : IC0 * (long)w;
    double *Yr = calloc(rows * nc, sizeof(double)), *Yi = calloc(rows * nc, sizeof(double));   /* full spectrum, row-major */
#define YR(u, v) Yr[(size_t)(u) * nc + (v)]
#define YI(u, v) Yi[(size_t)(u) * nc + (v)]
    if (Direction == kFFTDirection_Forward) {
        for (size_t r = 0; r < rows; r++)                        /* the real matrix */
            for (size_t k = 0; k < w; k++) { YR(r, 2 * k) = A->realp[(long)r * ra + (long)k * IA0]; YR(r, 2 * k + 1) = A->imagp[(long)r * ra + (long)k * IA0]; }
        double *cr = malloc(sizeof(double) * (rows > nc ? rows : nc) * 2), *ci = cr + (rows > nc ? rows : nc);
        for (size_t r = 0; r < rows; r++) {
            for (size_t v = 0; v < nc; v++) { cr[v] = YR(r, v); ci[v] = 0; }
            isim_cfft(cr, ci, nc, -1);
            for (size_t v = 0; v < nc; v++) { YR(r, v) = cr[v]; YI(r, v) = ci[v]; }
        }
        for (size_t v = 0; v < nc; v++) {
            for (size_t u = 0; u < rows; u++) { cr[u] = YR(u, v); ci[u] = YI(u, v); }
            isim_cfft(cr, ci, rows, -1);
            for (size_t u = 0; u < rows; u++) { YR(u, v) = 2 * cr[u]; YI(u, v) = 2 * ci[u]; }
        }
        free(cr);
        /* pack */
        for (size_t u = 0; u < rows; u++)
            for (size_t k = 1; k < w; k++) { C->realp[(long)u * rc + (long)k * IC0] = (T)YR(u, k); C->imagp[(long)u * rc + (long)k * IC0] = (T)YI(u, k); }
        for (int half = 0; half < 2; half++) {                   /* column v = 0 (into realp), v = nc / 2 (into imagp) */
            size_t v = half ? w : 0;
            T *col = half ? C->imagp : C->realp;
            if (rows == 1) { col[0] = (T)YR(0, v); continue; }
            col[0] = (T)YR(0, v); col[rc] = (T)YR(rows / 2, v);
            for (size_t u = 1; u < rows / 2; u++) { col[(long)(2 * u) * rc] = (T)YR(u, v); col[(long)(2 * u + 1) * rc] = (T)YI(u, v); }
        }
    } else {
        /* unpack into the full Hermitian spectrum, then the unscaled inverse 2D DFT */
        for (size_t u = 0; u < rows; u++)
            for (size_t k = 1; k < w; k++) {
                YR(u, k) = A->realp[(long)u * ra + (long)k * IA0]; YI(u, k) = A->imagp[(long)u * ra + (long)k * IA0];
                YR((rows - u) % rows, nc - k) = YR(u, k); YI((rows - u) % rows, nc - k) = -YI(u, k);
            }
        for (int half = 0; half < 2; half++) {
            size_t v = half ? w : 0;
            const T *col = half ? A->imagp : A->realp;
            if (rows == 1) { YR(0, v) = col[0]; continue; }
            YR(0, v) = col[0]; YR(rows / 2, v) = col[ra];
            for (size_t u = 1; u < rows / 2; u++) {
                YR(u, v) = col[(long)(2 * u) * ra]; YI(u, v) = col[(long)(2 * u + 1) * ra];
                YR(rows - u, v) = YR(u, v); YI(rows - u, v) = -YI(u, v);
            }
        }
        double *cr = malloc(sizeof(double) * (rows > nc ? rows : nc) * 2), *ci = cr + (rows > nc ? rows : nc);
        for (size_t v = 0; v < nc; v++) {
            for (size_t u = 0; u < rows; u++) { cr[u] = YR(u, v); ci[u] = YI(u, v); }
            isim_cfft(cr, ci, rows, +1);
            for (size_t u = 0; u < rows; u++) { YR(u, v) = cr[u]; YI(u, v) = ci[u]; }
        }
        for (size_t r = 0; r < rows; r++) {
            for (size_t v = 0; v < nc; v++) { cr[v] = YR(r, v); ci[v] = YI(r, v); }
            isim_cfft(cr, ci, nc, +1);
            for (size_t k = 0; k < w; k++) { C->realp[(long)r * rc + (long)k * IC0] = (T)cr[2 * k]; C->imagp[(long)r * rc + (long)k * IC0] = (T)cr[2 * k + 1]; }
        }
        free(cr);
    }
#undef YR
#undef YI
    free(Yr); free(Yi);
}
void V(fft2d_zrip)(FT Setup, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    V(fft2d_zrop)(Setup, C, IC0, IC1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
void V(fft2d_zropt)(FT Setup, const SCT *A, vDSP_Stride IA0, vDSP_Stride IA1, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, const SCT *Buffer,
                    vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction) {
    (void)Buffer; V(fft2d_zrop)(Setup, A, IA0, IA1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
void V(fft2d_zript)(FT Setup, const SCT *C, vDSP_Stride IC0, vDSP_Stride IC1, const SCT *Buffer, vDSP_Length Log2N0, vDSP_Length Log2N1,
                    FFTDirection Direction) {
    (void)Buffer; V(fft2d_zrop)(Setup, C, IC0, IC1, C, IC0, IC1, Log2N0, Log2N1, Direction);
}
#undef SIGN

/* ---------------- the interleaved DFT ---------------- */
struct V(_idft) { vDSP_Length length; int forward, real; };
IDFTSETUP V1(DFT_Interleaved_CreateSetup, D)(IDFTSETUP Previous, vDSP_Length Length, vDSP_DFT_Direction Direction, vDSP_DFT_RealtoComplex RealtoComplex) {
    (void)Previous;
    if (!isim_dft_length_ok(Length) || (RealtoComplex && Length % 2)) return NULL;
    struct V(_idft) *s = malloc(sizeof *s);
    if (!s) return NULL;
    s->length = Length; s->forward = Direction == vDSP_DFT_FORWARD; s->real = RealtoComplex == vDSP_DFT_Interleaved_RealtoComplex;
    return (IDFTSETUP)s;
}
/* complex: Length interleaved complex values; real: Length real values as Length / 2 pairs, the result packed as the
   split real DFT (DC and Nyquist in element 0) */
void V1(DFT_Interleaved_Execute, D)(const IDFTSTRUCT *Setup, const CT *Iri, CT *Ori) {
    const struct V(_idft) *s = (const struct V(_idft) *)Setup;
    size_t n = s->real ? s->length / 2 : s->length;
    double *re = malloc(sizeof(double) * (n ? n : 1) * 2), *im = re + (n ? n : 1);
    for (size_t i = 0; i < n; i++) { re[i] = Iri[i].real; im[i] = Iri[i].imag; }
    if (!s->real) isim_cfft(re, im, n, s->forward ? -1 : +1);
    else if (s->forward) isim_rfft_packed_forward(re, im, n);
    else isim_rfft_packed_inverse(re, im, n);
    for (size_t i = 0; i < n; i++) { Ori[i].real = (T)re[i]; Ori[i].imag = (T)im[i]; }
    free(re);
}
void V1(DFT_Interleaved_DestroySetup, D)(IDFTSETUP Setup) { free(Setup); }

/* ---------------- biquads ---------------- */
/* direct form 1: y = b0 x + b1 x[-1] + b2 x[-2] - a1 y[-1] - a2 y[-2], sections in cascade */
struct V(_bq) { vDSP_Length M; double c[]; };
BQSETUP V1(biquad_CreateSetup, D)(const double *Coefficients, vDSP_Length M) {
    struct V(_bq) *s = malloc(sizeof *s + sizeof(double) * 5 * (M ? M : 1));
    if (!s) return NULL;
    s->M = M;
    memcpy(s->c, Coefficients, sizeof(double) * 5 * M);
    return (BQSETUP)s;
}
void V1(biquad_DestroySetup, D)(BQSETUP Setup) { free(Setup); }
/* Delay[2m], Delay[2m + 1]: section m's last two inputs (newest first); Delay[2M], Delay[2M + 1]: the filter's last two outputs */
void V(biquad)(const BQSTRUCT *Setup, T *Delay, const T *X, vDSP_Stride IX, T *Y, vDSP_Stride IY, vDSP_Length N) {
    const struct V(_bq) *s = (const struct V(_bq) *)Setup;
    vDSP_Length M = s->M;
    for (vDSP_Length n = 0; n < N; n++) {
        double x = AT(X, n, IX);
        for (vDSP_Length m = 0; m < M; m++) {
            const double *c = s->c + 5 * m;
            double x1 = Delay[2 * m], x2 = Delay[2 * m + 1];
            double y1 = Delay[2 * m + 2], y2 = Delay[2 * m + 3];       /* the next section's inputs = this section's outputs */
            double y = c[0] * x + c[1] * x1 + c[2] * x2 - c[3] * y1 - c[4] * y2;
            Delay[2 * m + 1] = (T)x1; Delay[2 * m] = (T)x;
            x = y;
            if (m == M - 1) { Delay[2 * M + 1] = Delay[2 * M]; Delay[2 * M] = (T)y; }
        }
        AT(Y, n, IY) = (T)x;
    }
}
/* multichannel: coefficients section by section, each coefficient interleaved across the channels */
struct V(_bqm) { vDSP_Length M, N; double *c; T *state; bool *active; };
BQMSETUP V1(biquadm_CreateSetup, D)(const double *coeffs, vDSP_Length M, vDSP_Length N) {
    struct V(_bqm) *s = calloc(1, sizeof *s);
    if (!s) return NULL;
    s->M = M; s->N = N;
    s->c = malloc(sizeof(double) * 5 * (M * N ? M * N : 1));
    s->state = calloc(4 * (M * N ? M * N : 1), sizeof(T));
    s->active = malloc(M * N ? M * N : 1);
    for (vDSP_Length m = 0; m < M; m++)
        for (int k = 0; k < 5; k++)
            for (vDSP_Length ch = 0; ch < N; ch++) s->c[(ch * M + m) * 5 + k] = coeffs[(m * 5 + k) * N + ch];
    memset(s->active, 1, M * N ? M * N : 1);
    return (BQMSETUP)s;
}
void V1(biquadm_DestroySetup, D)(BQMSETUP setup) {
    struct V(_bqm) *s = (struct V(_bqm) *)setup;
    if (s) { free(s->c); free(s->state); free(s->active); free(s); }
}
void V(biquadm)(BQMSETUP setup, const T **X, vDSP_Stride IX, T **Y, vDSP_Stride IY, vDSP_Length N) {
    struct V(_bqm) *s = (struct V(_bqm) *)setup;
    for (vDSP_Length ch = 0; ch < s->N; ch++)
        for (vDSP_Length n = 0; n < N; n++) {
            double x = AT(X[ch], n, IX);
            for (vDSP_Length m = 0; m < s->M; m++) {
                if (!s->active[m * s->N + ch]) continue;
                const double *c = s->c + (ch * s->M + m) * 5;
                T *st = s->state + (ch * s->M + m) * 4;                  /* x1, x2, y1, y2 */
                double y = c[0] * x + c[1] * st[0] + c[2] * st[1] - c[3] * st[2] - c[4] * st[3];
                st[1] = st[0]; st[0] = (T)x; st[3] = st[2]; st[2] = (T)y;
                x = y;
            }
            AT(Y[ch], n, IY) = (T)x;
        }
}
void V1(biquadm_ResetState, D)(BQMSETUP setup) {
    struct V(_bqm) *s = (struct V(_bqm) *)setup;
    memset(s->state, 0, sizeof(T) * 4 * s->M * s->N);
}
void V1(biquadm_CopyState, D)(BQMSETUP dest, const BQMSTRUCT *src) {
    struct V(_bqm) *d = (struct V(_bqm) *)dest; const struct V(_bqm) *s = (const struct V(_bqm) *)src;
    if (d->M == s->M && d->N == s->N) memcpy(d->state, s->state, sizeof(T) * 4 * s->M * s->N);
}
/* coefficients for sections [start_sec, start_sec + nsec) and channels [start_chn, start_chn + nchn), laid out as at creation */
void V1(biquadm_SetCoefficientsDouble, D)(BQMSETUP setup, const double *coeffs, vDSP_Length start_sec, vDSP_Length start_chn,
                                          vDSP_Length nsec, vDSP_Length nchn) {
    struct V(_bqm) *s = (struct V(_bqm) *)setup;
    for (vDSP_Length m = 0; m < nsec; m++)
        for (int k = 0; k < 5; k++)
            for (vDSP_Length ch = 0; ch < nchn; ch++)
                s->c[((start_chn + ch) * s->M + start_sec + m) * 5 + k] = coeffs[(m * 5 + k) * nchn + ch];
}
/* isim applies targets at once (no ramping) */
void V1(biquadm_SetTargetsDouble, D)(BQMSETUP setup, const double *targets, double interp_rate, double interp_threshold, vDSP_Length start_sec,
                                     vDSP_Length start_chn, vDSP_Length nsec, vDSP_Length nchn) {
    (void)interp_rate; (void)interp_threshold;
    V1(biquadm_SetCoefficientsDouble, D)(setup, targets, start_sec, start_chn, nsec, nchn);
}
void V1(biquadm_SetActiveFilters, D)(BQMSETUP setup, const bool *filter_states) {
    struct V(_bqm) *s = (struct V(_bqm) *)setup;
    memcpy(s->active, filter_states, s->M * s->N);
}

/* ---------------- vector functions ---------------- */
void V(deq22)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length n = 2; n < N + 2; n++)
        AT(C, n, IC) = AT(A, n, IA) * B[0] + AT(A, n - 1, IA) * B[1] + AT(A, n - 2, IA) * B[2] - AT(C, n - 1, IC) * B[3] - AT(C, n - 2, IC) * B[4];
}
void V(vdist)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = (T)hypot(AT(A, i, IA), AT(B, i, IB));
}
void V(vpythg)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C, vDSP_Stride IC, const T *D_, vDSP_Stride ID, T *E,
               vDSP_Stride IE, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(E, i, IE) = (T)hypot(AT(A, i, IA) - AT(C, i, IC), AT(B, i, IB) - AT(D_, i, ID));
}
/* mean and (population) standard deviation; C, when not NULL, gets (A - mean) / deviation */
void V(normalize)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, T *Mean, T *StandardDeviation, vDSP_Length N) {
    double s = 0, q = 0;
    for (vDSP_Length i = 0; i < N; i++) s += AT(A, i, IA);
    double mean = N ? s / N : 0;
    for (vDSP_Length i = 0; i < N; i++) { double d = AT(A, i, IA) - mean; q += d * d; }
    double sd = N ? sqrt(q / N) : 0;
    *Mean = (T)mean; *StandardDeviation = (T)sd;
    if (C) for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = (T)((AT(A, i, IA) - mean) / sd);
}
void V(zvmov)(const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { AT(C->realp, i, IC) = AT(A->realp, i, IA); AT(C->imagp, i, IC) = AT(A->imagp, i, IA); }
}
/* A[0] the highest-order coefficient of a degree-P polynomial */
void V(vpoly)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N, vDSP_Length P) {
    for (vDSP_Length i = 0; i < N; i++) {
        double x = AT(B, i, IB), y = 0;
        for (vDSP_Length p = 0; p <= P; p++) y = y * x + AT(A, p, IA);
        AT(C, i, IC) = (T)y;
    }
}
void V(vtrapz)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    double s = 0, h = *B;
    for (vDSP_Length i = 0; i < N; i++) { if (i) s += h * (AT(A, i - 1, IA) + AT(A, i, IA)) / 2; AT(C, i, IC) = (T)s; }
}
void V(vsimps)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    double h = *B;
    if (N > 0) AT(C, 0, IC) = 0;
    if (N > 1) AT(C, 1, IC) = (T)(h * (AT(A, 0, IA) + AT(A, 1, IA)) / 2);
    for (vDSP_Length i = 2; i < N; i++)
        AT(C, i, IC) = (T)(AT(C, i - 2, IC) + h / 3 * (AT(A, i - 2, IA) + 4 * (double)AT(A, i - 1, IA) + AT(A, i, IA)));
}
/* running sum, scaled: C[0] = 0, C[n] = C[n - 1] + S A[n] */
void V(vrsum)(const T *A, vDSP_Stride IA, const T *S, T *C, vDSP_Stride IC, vDSP_Length N) {
    double s = 0;
    for (vDSP_Length i = 0; i < N; i++) { if (i) s += (double)*S * AT(A, i, IA); AT(C, i, IC) = (T)s; }
}
void V(vswsum)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N, vDSP_Length P) {
    for (vDSP_Length i = 0; i < N; i++) { double s = 0; for (vDSP_Length p = 0; p < P; p++) s += AT(A, i + p, IA); AT(C, i, IC) = (T)s; }
}
void V(desamp)(const T *A, vDSP_Stride DF, const T *F, T *C, vDSP_Length N, vDSP_Length P) {
    for (vDSP_Length i = 0; i < N; i++) { double s = 0; for (vDSP_Length p = 0; p < P; p++) s += (double)A[(long)i * DF + (long)p] * F[p]; C[i] = (T)s; }
}
void V(vcmprs)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    vDSP_Length k = 0;
    for (vDSP_Length i = 0; i < N; i++) if (AT(B, i, IB) != 0) { AT(C, k, IC) = AT(A, i, IA); k++; }
}
/* B: 1-based indices into A */
void V(vgathr)(const T *A, const vDSP_Length *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = A[AT(B, i, IB) - 1];
}
void V(vtmerg)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        double t = N > 1 ? (double)i / (double)(N - 1) : 0;
        AT(C, i, IC) = (T)(AT(A, i, IA) + (AT(B, i, IB) - (double)AT(A, i, IA)) * t);
    }
}
void V(vswap)(T *A, vDSP_Stride IA, T *B, vDSP_Stride IB, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T t = AT(A, i, IA); AT(A, i, IA) = AT(B, i, IB); AT(B, i, IB) = t; }
}
void V(vthres)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) >= *B ? AT(A, i, IA) : 0;
}
void V(vthrsc)(const T *A, vDSP_Stride IA, const T *B, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = AT(A, i, IA) >= *B ? *C : -*C;
}
/* inverted clip: values outside (B, C) pass; inside, they go to B (negative) or C */
void V(viclip)(const T *A, vDSP_Stride IA, const T *B, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        T a = AT(A, i, IA);
        AT(D_, i, ID) = (a <= *B || a >= *C) ? a : a < 0 ? *B : *C;
    }
}
void V(vnabs)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(C, i, IC) = a < 0 ? a : -a; }
}
void V(vfrac)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { double a = AT(A, i, IA); AT(C, i, IC) = (T)(a - trunc(a)); }
}
/* decibels: F = 0 power (10 log10 A / B), 1 amplitude (20 log10 A / B) */
void V(vdbcon)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N, unsigned int F) {
    double k = F ? 20 : 10;
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = (T)(k * log10((double)AT(A, i, IA) / *B));
}
void V(vrampmul)(const T *I, vDSP_Stride IS, T *Start, const T *Step, T *O, vDSP_Stride OS, vDSP_Length N) {
    T g = *Start;
    for (vDSP_Length i = 0; i < N; i++) { AT(O, i, OS) = g * AT(I, i, IS); g += *Step; }
    *Start = g;
}
void V(vrampmul2)(const T *I0, const T *I1, vDSP_Stride IS, T *Start, const T *Step, T *O0, T *O1, vDSP_Stride OS, vDSP_Length N) {
    T g = *Start;
    for (vDSP_Length i = 0; i < N; i++) { AT(O0, i, OS) = g * AT(I0, i, IS); AT(O1, i, OS) = g * AT(I1, i, IS); g += *Step; }
    *Start = g;
}
/* the index is in A's elements (i * IA), the first of equal magnitudes */
void V(maxmgvi)(const T *A, vDSP_Stride IA, T *C, vDSP_Length *I, vDSP_Length N) {
    T m = -1; vDSP_Length k = 0;
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); a = a < 0 ? -a : a; if (a > m) { m = a; k = i; } }
    *C = N ? m : 0; *I = k * (vDSP_Length)IA;
}
void V(minmgvi)(const T *A, vDSP_Stride IA, T *C, vDSP_Length *I, vDSP_Length N) {
    T m = INFINITY; vDSP_Length k = 0;
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); a = a < 0 ? -a : a; if (a < m) { m = a; k = i; } }
    *C = N ? m : 0; *I = k * (vDSP_Length)IA;
}
void V(sve_svesq)(const T *A, vDSP_Stride IA, T *Sum, T *SumOfSquares, vDSP_Length N) {
    double s = 0, q = 0;
    for (vDSP_Length i = 0; i < N; i++) { double a = AT(A, i, IA); s += a; q += a * a; }
    *Sum = (T)s; *SumOfSquares = (T)q;
}
/* pairs (x, y) <-> (radius, angle); IA / IC: the stride between pairs, in elements */
void V(polar)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        double x = A[(long)i * IA], y = A[(long)i * IA + 1];
        C[(long)i * IC] = (T)hypot(x, y); C[(long)i * IC + 1] = (T)atan2(y, x);
    }
}
void V(rect)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        double r = A[(long)i * IA], t = A[(long)i * IA + 1];
        C[(long)i * IC] = (T)(r * cos(t)); C[(long)i * IC + 1] = (T)(r * sin(t));
    }
}
/* zero crossings (sign changes) up to B of them: C the element index (i * IA) of the last one found, D their count */
void V(nzcros)(const T *A, vDSP_Stride IA, vDSP_Length B, vDSP_Length *C, vDSP_Length *D_, vDSP_Length N) {
    vDSP_Length count = 0, last = 0;
    for (vDSP_Length i = 1; i < N && count < B; i++) {
        T p = AT(A, i - 1, IA), q = AT(A, i, IA);
        if ((p < 0) != (q < 0)) { count++; last = i * (vDSP_Length)IA; }
    }
    *C = last; *D_ = count;
}
/* O0 = I1 + I0, O1 = I1 - I0 */
void V(vaddsub)(const T *I0, vDSP_Stride I0S, const T *I1, vDSP_Stride I1S, T *O0, vDSP_Stride O0S, T *O1, vDSP_Stride O1S, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        T a = AT(I0, i, I0S), b = AT(I1, i, I1S);
        AT(O0, i, O0S) = b + a; AT(O1, i, O1S) = b - a;
    }
}

#undef V2
#undef V1
#undef V
#undef AT
