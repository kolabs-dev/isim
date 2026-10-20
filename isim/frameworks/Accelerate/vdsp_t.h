/* isim Accelerate: vDSP for one element type (included by vdsp.c with T = float, then T = double and the D suffix). */
#define V2(n, d) vDSP_##n##d
#define V1(n, d) V2(n, d)
#define V(n) V1(n, D)
#define AT(p, i, s) (p)[(long)(i) * (s)]

void V(vadd)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) + AT(B, i, IB);
}
void V(vsub)(const T *B, vDSP_Stride IB, const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) - AT(B, i, IB);
}
void V(vmul)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) * AT(B, i, IB);
}
void V(vdiv)(const T *B, vDSP_Stride IB, const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) / AT(B, i, IB);
}
void V(vsadd)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T b = *B; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) + b;
}
void V(vsmul)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T b = *B; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) * b;
}
void V(vsdiv)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T b = *B; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = AT(A, i, IA) / b;
}
void V(svdiv)(const T *A, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    T a = *A; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = a / AT(B, i, IB);
}
void V(vsmsa)(const T *A, vDSP_Stride IA, const T *B, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    T b = *B, c = *C; for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = AT(A, i, IA) * b + c;
}
void V(vma)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = AT(A, i, IA) * AT(B, i, IB) + AT(C, i, IC);
}
void V(vam)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = (AT(A, i, IA) + AT(B, i, IB)) * AT(C, i, IC);
}
void V(vsma)(const T *A, vDSP_Stride IA, const T *B, const T *C, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N) {
    T b = *B; for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = AT(A, i, IA) * b + AT(C, i, IC);
}
void V(vneg)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) { for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = -AT(A, i, IA); }
void V(vabs)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(C, i, IC) = a < 0 ? -a : a; }
}
void V(vsq)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(C, i, IC) = a * a; }
}
void V(vssq)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(C, i, IC) = a < 0 ? -a * a : a * a; }
}
void V(vmax)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA), b = AT(B, i, IB); AT(C, i, IC) = a > b ? a : b; }
}
void V(vmin)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA), b = AT(B, i, IB); AT(C, i, IC) = a < b ? a : b; }
}
void V(vclip)(const T *A, vDSP_Stride IA, const T *B, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    T lo = *B, hi = *C;
    for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(D_, i, ID) = a < lo ? lo : a > hi ? hi : a; }
}
void V(vthr)(const T *A, vDSP_Stride IA, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T b = *B; for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(C, i, IC) = a >= b ? a : b; }
}
void V(vlim)(const T *A, vDSP_Stride IA, const T *B, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    T b = *B, c = *C; for (vDSP_Length i = 0; i < N; i++) AT(D_, i, ID) = AT(A, i, IA) >= b ? c : -c;
}
void V(vclr)(T *C, vDSP_Stride IC, vDSP_Length N) { for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = 0; }
void V(vfill)(const T *A, T *C, vDSP_Stride IC, vDSP_Length N) { T a = *A; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = a; }
void V(vramp)(const T *A, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T a = *A, b = *B; for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = a + (T)i * b;
}
void V(vgen)(const T *A, const T *B, T *C, vDSP_Stride IC, vDSP_Length N) {
    T a = *A, b = *B;
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = N > 1 ? a + (b - a) * (T)i / (T)(N - 1) : a;
}
void V(vrvrs)(T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N / 2; i++) { T t = AT(C, i, IC); AT(C, i, IC) = AT(C, N - 1 - i, IC); AT(C, N - 1 - i, IC) = t; }
}
static int V(_cmp_up)(const void *a, const void *b) { T x = *(const T *)a, y = *(const T *)b; return x < y ? -1 : x > y; }
static int V(_cmp_down)(const void *a, const void *b) { T x = *(const T *)a, y = *(const T *)b; return x > y ? -1 : x < y; }
void V(vsort)(T *C, vDSP_Length N, int Order) { qsort(C, N, sizeof(T), Order < 0 ? V(_cmp_down) : V(_cmp_up)); }
void V(vlint)(const T *A, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length N, vDSP_Length M) {
    for (vDSP_Length i = 0; i < N; i++) {
        T b = AT(B, i, IB);
        long k = (long)b;
        if (k < 0) k = 0;
        if (M > 1 && (vDSP_Length)k > M - 2) k = (long)M - 2;
        T a0 = A[k], a1 = M > 1 ? A[k + 1] : a0;
        AT(C, i, IC) = a0 + (b - (T)k) * (a1 - a0);
    }
}
void V(vintb)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C, T *D_, vDSP_Stride ID, vDSP_Length N) {
    T c = *C; for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); AT(D_, i, ID) = a + c * (AT(B, i, IB) - a); }
}

/* reductions (summed in double) */
void V(sve)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { double s = 0; for (vDSP_Length i = 0; i < N; i++) s += AT(A, i, IA); *C = (T)s; }
void V(svesq)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) {
    double s = 0; for (vDSP_Length i = 0; i < N; i++) { double a = AT(A, i, IA); s += a * a; } *C = (T)s;
}
void V(svemg)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { double s = 0; for (vDSP_Length i = 0; i < N; i++) s += fabs((double)AT(A, i, IA)); *C = (T)s; }
void V(meanv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { V(sve)(A, IA, C, N); if (N) *C /= (T)N; }
void V(meamgv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { V(svemg)(A, IA, C, N); if (N) *C /= (T)N; }
void V(measqv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { V(svesq)(A, IA, C, N); if (N) *C /= (T)N; }
void V(rmsqv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) { V(measqv)(A, IA, C, N); *C = (T)sqrt((double)*C); }
void V(maxv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) {
    T m = -INFINITY; for (vDSP_Length i = 0; i < N; i++) if (AT(A, i, IA) > m) m = AT(A, i, IA); *C = m;
}
void V(minv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) {
    T m = INFINITY; for (vDSP_Length i = 0; i < N; i++) if (AT(A, i, IA) < m) m = AT(A, i, IA); *C = m;
}
void V(maxmgv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) {
    T m = 0; for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); a = a < 0 ? -a : a; if (a > m) m = a; } *C = m;
}
void V(minmgv)(const T *A, vDSP_Stride IA, T *C, vDSP_Length N) {
    T m = INFINITY; for (vDSP_Length i = 0; i < N; i++) { T a = AT(A, i, IA); a = a < 0 ? -a : a; if (a < m) m = a; } *C = m;
}
/* the index is in A's elements (i * IA), the first of equal values */
void V(maxvi)(const T *A, vDSP_Stride IA, T *C, vDSP_Length *I, vDSP_Length N) {
    T m = -INFINITY; vDSP_Length k = 0;
    for (vDSP_Length i = 0; i < N; i++) if (AT(A, i, IA) > m) { m = AT(A, i, IA); k = i; }
    *C = m; *I = k * (vDSP_Length)IA;
}
void V(minvi)(const T *A, vDSP_Stride IA, T *C, vDSP_Length *I, vDSP_Length N) {
    T m = INFINITY; vDSP_Length k = 0;
    for (vDSP_Length i = 0; i < N; i++) if (AT(A, i, IA) < m) { m = AT(A, i, IA); k = i; }
    *C = m; *I = k * (vDSP_Length)IA;
}
void V(dotpr)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Length N) {
    double s = 0; for (vDSP_Length i = 0; i < N; i++) s += (double)AT(A, i, IA) * AT(B, i, IB); *C = (T)s;
}
void V(distancesq)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Length N) {
    double s = 0; for (vDSP_Length i = 0; i < N; i++) { double d = (double)AT(A, i, IA) - AT(B, i, IB); s += d * d; } *C = (T)s;
}
void V(mmul)(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C, vDSP_Stride IC, vDSP_Length M, vDSP_Length N, vDSP_Length P_) {
    for (vDSP_Length i = 0; i < M; i++)
        for (vDSP_Length j = 0; j < N; j++) {
            double s = 0;
            for (vDSP_Length k = 0; k < P_; k++) s += (double)AT(A, i * P_ + k, IA) * AT(B, k * N + j, IB);
            AT(C, i * N + j, IC) = (T)s;
        }
}
/* C (M x N) is the transpose of A (N x M) */
void V(mtrans)(const T *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length M, vDSP_Length N) {
    for (vDSP_Length i = 0; i < M; i++) for (vDSP_Length j = 0; j < N; j++) AT(C, i * N + j, IC) = AT(A, j * M + i, IA);
}
void V(conv)(const T *A, vDSP_Stride IA, const T *F, vDSP_Stride IF, T *C, vDSP_Stride IC, vDSP_Length N, vDSP_Length P_) {
    for (vDSP_Length n = 0; n < N; n++) {
        double s = 0;
        for (vDSP_Length p = 0; p < P_; p++) s += (double)AT(A, n + p, IA) * F[(long)p * IF];
        AT(C, n, IC) = (T)s;
    }
}
static void V(_window)(T *C, vDSP_Length N, int Flag, double a0, double a1, double a2, double scale) {
    vDSP_Length n = (Flag & vDSP_HALF_WINDOW) ? (N + 1) / 2 : N;
    for (vDSP_Length i = 0; i < n; i++) {
        double t = 2 * M_PI * (double)i / (double)N;
        C[i] = (T)(scale * (a0 - a1 * cos(t) + a2 * cos(2 * t)));
    }
}
void V(hann_window)(T *C, vDSP_Length N, int Flag) { V(_window)(C, N, Flag, 0.5, 0.5, 0, (Flag & vDSP_HANN_NORM) ? 1.6329931618554521 : 1); }
void V(hamm_window)(T *C, vDSP_Length N, int Flag) { V(_window)(C, N, Flag, 0.54, 0.46, 0, 1); }
void V(blkman_window)(T *C, vDSP_Length N, int Flag) { V(_window)(C, N, Flag, 0.42, 0.5, 0.08, 1); }

/* complex vectors: interleaved (strides in T values, 2 = contiguous) and split */
void V(ctoz)(const CT *C, vDSP_Stride IC, const SCT *Z, vDSP_Stride IZ, vDSP_Length N) {
    const T *c = (const T *)C;
    for (vDSP_Length i = 0; i < N; i++) { AT(Z->realp, i, IZ) = c[(long)i * IC]; AT(Z->imagp, i, IZ) = c[(long)i * IC + 1]; }
}
void V(ztoc)(const SCT *Z, vDSP_Stride IZ, CT *C, vDSP_Stride IC, vDSP_Length N) {
    T *c = (T *)C;
    for (vDSP_Length i = 0; i < N; i++) { c[(long)i * IC] = AT(Z->realp, i, IZ); c[(long)i * IC + 1] = AT(Z->imagp, i, IZ); }
}
void V(zvadd)(const SCT *A, vDSP_Stride IA, const SCT *B, vDSP_Stride IB, const SCT *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        AT(C->realp, i, IC) = AT(A->realp, i, IA) + AT(B->realp, i, IB); AT(C->imagp, i, IC) = AT(A->imagp, i, IA) + AT(B->imagp, i, IB);
    }
}
/* C = B - A, as Apple's */
void V(zvsub)(const SCT *A, vDSP_Stride IA, const SCT *B, vDSP_Stride IB, const SCT *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) {
        AT(C->realp, i, IC) = AT(B->realp, i, IB) - AT(A->realp, i, IA); AT(C->imagp, i, IC) = AT(B->imagp, i, IB) - AT(A->imagp, i, IA);
    }
}
void V(zvmul)(const SCT *A, vDSP_Stride IA, const SCT *B, vDSP_Stride IB, const SCT *C, vDSP_Stride IC, vDSP_Length N, int Conjugate) {
    for (vDSP_Length i = 0; i < N; i++) {
        T ar = AT(A->realp, i, IA), ai = Conjugate < 0 ? -AT(A->imagp, i, IA) : AT(A->imagp, i, IA);
        T br = AT(B->realp, i, IB), bi = AT(B->imagp, i, IB);
        AT(C->realp, i, IC) = ar * br - ai * bi; AT(C->imagp, i, IC) = ar * bi + ai * br;
    }
}
void V(zvabs)(const SCT *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = (T)hypot((double)AT(A->realp, i, IA), (double)AT(A->imagp, i, IA));
}
void V(zvmags)(const SCT *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { T r = AT(A->realp, i, IA), m = AT(A->imagp, i, IA); AT(C, i, IC) = r * r + m * m; }
}
void V(zvphas)(const SCT *A, vDSP_Stride IA, T *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) AT(C, i, IC) = (T)atan2((double)AT(A->imagp, i, IA), (double)AT(A->realp, i, IA));
}
void V(zvconj)(const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length N) {
    for (vDSP_Length i = 0; i < N; i++) { AT(C->realp, i, IC) = AT(A->realp, i, IA); AT(C->imagp, i, IC) = -AT(A->imagp, i, IA); }
}

/* FFTs: computed in double (fft.c), whatever the setup's size, for lengths up to 2^Log2n */
struct V(_setup) { vDSP_Length log2n; };
FT V(create_fftsetup)(vDSP_Length Log2n, FFTRadix Radix) {
    if (Radix != kFFTRadix2 || Log2n > 24) return NULL;      /* isim: radix 2 only */
    struct V(_setup) *s = malloc(sizeof *s);
    if (s) s->log2n = Log2n;
    return (FT)s;
}
void V(destroy_fftsetup)(FT Setup) { free(Setup); }
static void V(_zop)(const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    size_t n = (size_t)1 << Log2N;
    double *re = malloc(sizeof(double) * n * 2), *im = re + n;
    for (size_t i = 0; i < n; i++) { re[i] = AT(A->realp, i, IA); im[i] = AT(A->imagp, i, IA); }
    isim_cfft(re, im, n, Direction == kFFTDirection_Forward ? -1 : +1);
    for (size_t i = 0; i < n; i++) { AT(C->realp, i, IC) = (T)re[i]; AT(C->imagp, i, IC) = (T)im[i]; }
    free(re);
}
void V(fft_zip)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) { (void)Setup; V(_zop)(C, IC, C, IC, Log2N, Direction); }
void V(fft_zop)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; V(_zop)(A, IA, C, IC, Log2N, Direction);
}
static void V(_zrop)(const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, size_t half, int forward) {
    double *re = malloc(sizeof(double) * (half ? half : 1) * 2), *im = re + (half ? half : 1);
    for (size_t i = 0; i < half; i++) { re[i] = AT(A->realp, i, IA); im[i] = AT(A->imagp, i, IA); }
    if (forward) isim_rfft_packed_forward(re, im, half); else isim_rfft_packed_inverse(re, im, half);
    for (size_t i = 0; i < half; i++) { AT(C->realp, i, IC) = (T)re[i]; AT(C->imagp, i, IC) = (T)im[i]; }
    free(re);
}
void V(fft_zrip)(FT Setup, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; if (Log2N > 0) V(_zrop)(C, IC, C, IC, (size_t)1 << (Log2N - 1), Direction == kFFTDirection_Forward);
}
void V(fft_zrop)(FT Setup, const SCT *A, vDSP_Stride IA, const SCT *C, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction) {
    (void)Setup; if (Log2N > 0) V(_zrop)(A, IA, C, IC, (size_t)1 << (Log2N - 1), Direction == kFFTDirection_Forward);
}

/* the DFT API */
struct V(_dfts) { vDSP_Length length; int forward, real; };
DFTSETUP V1(DFT_zop_CreateSetup, D)(DFTSETUP Previous, vDSP_Length Length, vDSP_DFT_Direction Direction) {
    (void)Previous;
    if (!isim_dft_length_ok(Length)) return NULL;
    struct V(_dfts) *s = malloc(sizeof *s);
    s->length = Length; s->forward = Direction == vDSP_DFT_FORWARD; s->real = 0;
    return (DFTSETUP)s;
}
DFTSETUP V1(DFT_zrop_CreateSetup, D)(DFTSETUP Previous, vDSP_Length Length, vDSP_DFT_Direction Direction) {
    (void)Previous;
    if (Length < 2 || Length % 2 || !isim_dft_length_ok(Length / 2)) return NULL;
    struct V(_dfts) *s = malloc(sizeof *s);
    s->length = Length; s->forward = Direction == vDSP_DFT_FORWARD; s->real = 1;
    return (DFTSETUP)s;
}
void V1(DFT_Execute, D)(const DFTSTRUCT *Setup, const T *Ir, const T *Ii, T *Or, T *Oi) {
    const struct V(_dfts) *s = (const struct V(_dfts) *)Setup;
    size_t n = s->real ? s->length / 2 : s->length;
    double *re = malloc(sizeof(double) * (n ? n : 1) * 2), *im = re + (n ? n : 1);
    for (size_t i = 0; i < n; i++) { re[i] = Ir[i]; im[i] = Ii[i]; }
    if (!s->real) isim_cfft(re, im, n, s->forward ? -1 : +1);
    else if (s->forward) isim_rfft_packed_forward(re, im, n);
    else isim_rfft_packed_inverse(re, im, n);
    for (size_t i = 0; i < n; i++) { Or[i] = (T)re[i]; Oi[i] = (T)im[i]; }
    free(re);
}
void V1(DFT_DestroySetup, D)(DFTSETUP Setup) { free(Setup); }

#undef V2
#undef V1
#undef V
#undef AT
