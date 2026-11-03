#pragma once
/* vDSP (vecLib's vDSP.h): vector arithmetic, reductions, conversions, matrix multiply, convolution and the FFTs.
   Strides are in elements; the "D" functions are double precision. */
#include <Accelerate/vecLibTypes.h>

typedef unsigned long vDSP_Length;
typedef long vDSP_Stride;
typedef struct DSPComplex { float real; float imag; } DSPComplex;
typedef struct DSPSplitComplex { float *realp; float *imagp; } DSPSplitComplex;
typedef struct DSPDoubleComplex { double real; double imag; } DSPDoubleComplex;
typedef struct DSPDoubleSplitComplex { double *realp; double *imagp; } DSPDoubleSplitComplex;
typedef int FFTDirection;
typedef int FFTRadix;
enum { kFFTDirection_Forward = +1, kFFTDirection_Inverse = -1 };
enum { kFFTRadix2 = 0, kFFTRadix3 = 1, kFFTRadix5 = 2 };
enum { vDSP_HALF_WINDOW = 1, vDSP_HANN_DENORM = 0, vDSP_HANN_NORM = 2 };
typedef struct OpaqueFFTSetup *FFTSetup;
typedef struct OpaqueFFTSetupD *FFTSetupD;
typedef enum __attribute__((enum_extensibility(closed))) : int { vDSP_DFT_FORWARD = +1, vDSP_DFT_INVERSE = -1 } vDSP_DFT_Direction;
typedef struct vDSP_DFT_SetupStruct *vDSP_DFT_Setup;
typedef struct vDSP_DFT_SetupStructD *vDSP_DFT_SetupD;
typedef struct vDSP_DFT_Interleaved_SetupStruct *vDSP_DFT_Interleaved_Setup;
typedef struct vDSP_DFT_Interleaved_SetupStructD *vDSP_DFT_Interleaved_SetupD;
typedef enum __attribute__((enum_extensibility(closed))) : bool {
    vDSP_DFT_Interleaved_ComplextoComplex = false, vDSP_DFT_Interleaved_RealtoComplex = true
} vDSP_DFT_RealtoComplex;
typedef enum __attribute__((enum_extensibility(closed))) : int { vDSP_DCT_II = 2, vDSP_DCT_III = 3, vDSP_DCT_IV = 4 } vDSP_DCT_Type;
typedef struct vDSP_biquad_SetupStruct *vDSP_biquad_Setup;
typedef struct vDSP_biquad_SetupStructD *vDSP_biquad_SetupD;
typedef struct vDSP_biquadm_SetupStruct *vDSP_biquadm_Setup;
typedef struct vDSP_biquadm_SetupStructD *vDSP_biquadm_SetupD;

#define VDSP_DECL(T, S, C, SC, F, D) \
    VECLIB_EXTERN void vDSP_vadd##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    /* C = A - B (B comes first) */ \
    VECLIB_EXTERN void vDSP_vsub##D(const T *B, vDSP_Stride IB, const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vmul##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    /* C = A / B (B comes first) */ \
    VECLIB_EXTERN void vDSP_vdiv##D(const T *B, vDSP_Stride IB, const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsadd##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsmul##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsdiv##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_svdiv##D(const T *A, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsmsa##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vma##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C_, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vam##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C_, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsma##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, vDSP_Stride IC, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vneg##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vabs##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsq##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vssq##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vmax##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vmin##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vclip##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vthr##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vlim##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vclr##D(T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vfill##D(const T *A, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vramp##D(const T *A, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vgen##D(const T *A, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vrvrs##D(T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsort##D(T *C_, vDSP_Length N, int Order); \
    VECLIB_EXTERN void vDSP_vlint##D(const T *A, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N, vDSP_Length M); \
    VECLIB_EXTERN void vDSP_vintb##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_sve##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_svesq##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_svemg##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_meanv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_meamgv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_measqv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_rmsqv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_maxv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_minv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_maxmgv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_minmgv##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_maxvi##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length *I, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_minvi##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length *I, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_dotpr##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_distancesq##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Length N); \
    /* C (M x N) = A (M x P) * B (P x N), row-major */ \
    VECLIB_EXTERN void vDSP_mmul##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length M, vDSP_Length N, vDSP_Length P); \
    VECLIB_EXTERN void vDSP_mtrans##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length M, vDSP_Length N); \
    /* correlation (IF > 0) or convolution (F at its last element, IF < 0): C[n] = sum_p A[n + p] F[p IF] */ \
    VECLIB_EXTERN void vDSP_conv##D(const T *A, vDSP_Stride IA, const T *F, vDSP_Stride IF, T *C_, vDSP_Stride IC, vDSP_Length N, vDSP_Length P); \
    VECLIB_EXTERN void vDSP_hann_window##D(T *C_, vDSP_Length N, int Flag); \
    VECLIB_EXTERN void vDSP_hamm_window##D(T *C_, vDSP_Length N, int Flag); \
    VECLIB_EXTERN void vDSP_blkman_window##D(T *C_, vDSP_Length N, int Flag); \
    VECLIB_EXTERN void vDSP_ctoz##D(const C *C_, vDSP_Stride IC, const SC *Z, vDSP_Stride IZ, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_ztoc##D(const SC *Z, vDSP_Stride IZ, C *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvadd##D(const SC *A, vDSP_Stride IA, const SC *B, vDSP_Stride IB, const SC *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvsub##D(const SC *A, vDSP_Stride IA, const SC *B, vDSP_Stride IB, const SC *C_, vDSP_Stride IC, vDSP_Length N); \
    /* Conjugate -1: A conjugated */ \
    VECLIB_EXTERN void vDSP_zvmul##D(const SC *A, vDSP_Stride IA, const SC *B, vDSP_Stride IB, const SC *C_, vDSP_Stride IC, vDSP_Length N, int Conjugate); \
    VECLIB_EXTERN void vDSP_zvabs##D(const SC *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvmags##D(const SC *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvphas##D(const SC *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvconj##D(const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN F vDSP_create_fftsetup##D(vDSP_Length Log2n, FFTRadix Radix); \
    VECLIB_EXTERN void vDSP_destroy_fftsetup##D(F _Nullable Setup); \
    VECLIB_EXTERN void vDSP_fft_zip##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft_zop##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction); \
    /* real FFT: the input packed as even/odd (vDSP_ctoz); forward: twice the DFT, Nyquist in imagp[0]; inverse: unscaled */ \
    VECLIB_EXTERN void vDSP_fft_zrip##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft_zrop##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction);
VDSP_DECL(float, s, DSPComplex, DSPSplitComplex, FFTSetup, )
VDSP_DECL(double, d, DSPDoubleComplex, DSPDoubleSplitComplex, FFTSetupD, D)
#undef VDSP_DECL


/* issue #543: more FFTs (temporary-buffer forms, radix 3 and 5, multiple signals, 2D), the interleaved DFT, biquads and
   vector functions; in each precision (names with D: double) */
#define VDSP_MORE(T, CT, SC, F, IDS, IDSS, BQ, BQS, BQM, BQMS, D) \
    VECLIB_EXTERN void vDSP_fft_zipt##D(F Setup, const SC *C_, vDSP_Stride IC, const SC *Buffer, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft_zopt##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, const SC *Buffer, vDSP_Length Log2N, \
                                        FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft_zript##D(F Setup, const SC *C_, vDSP_Stride IC, const SC *Buffer, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft_zropt##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, const SC *Buffer, vDSP_Length Log2N, \
                                         FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft3_zop##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft5_zop##D(F Setup, const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length Log2N, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zip##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Stride IM, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zipt##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Stride IM, const SC *Buffer, vDSP_Length Log2N, vDSP_Length M, \
                                         FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zop##D(F Setup, const SC *A, vDSP_Stride IA, vDSP_Stride IMA, const SC *C_, vDSP_Stride IC, vDSP_Stride IMC, \
                                        vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zopt##D(F Setup, const SC *A, vDSP_Stride IA, vDSP_Stride IMA, const SC *C_, vDSP_Stride IC, vDSP_Stride IMC, \
                                         const SC *Buffer, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zrip##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Stride IM, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zript##D(F Setup, const SC *C_, vDSP_Stride IC, vDSP_Stride IM, const SC *Buffer, vDSP_Length Log2N, vDSP_Length M, \
                                          FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zrop##D(F Setup, const SC *A, vDSP_Stride IA, vDSP_Stride IMA, const SC *C_, vDSP_Stride IC, vDSP_Stride IMC, \
                                         vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fftm_zropt##D(F Setup, const SC *A, vDSP_Stride IA, vDSP_Stride IMA, const SC *C_, vDSP_Stride IC, vDSP_Stride IMC, \
                                          const SC *Buffer, vDSP_Length Log2N, vDSP_Length M, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zip##D(F Setup, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, vDSP_Length Log2N0, vDSP_Length Log2N1, \
                                         FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zipt##D(F Setup, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, const SC *Buffer, vDSP_Length Log2N0, \
                                          vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zop##D(F Setup, const SC *A, vDSP_Stride IA0, vDSP_Stride IA1, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, \
                                         vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zopt##D(F Setup, const SC *A, vDSP_Stride IA0, vDSP_Stride IA1, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, \
                                          const SC *Buffer, vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zrip##D(F Setup, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, vDSP_Length Log2N0, vDSP_Length Log2N1, \
                                          FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zript##D(F Setup, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, const SC *Buffer, vDSP_Length Log2N0, \
                                           vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zrop##D(F Setup, const SC *A, vDSP_Stride IA0, vDSP_Stride IA1, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, \
                                          vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN void vDSP_fft2d_zropt##D(F Setup, const SC *A, vDSP_Stride IA0, vDSP_Stride IA1, const SC *C_, vDSP_Stride IC0, vDSP_Stride IC1, \
                                           const SC *Buffer, vDSP_Length Log2N0, vDSP_Length Log2N1, FFTDirection Direction); \
    VECLIB_EXTERN IDS _Nullable vDSP_DFT_Interleaved_CreateSetup##D(IDS _Nullable Previous, vDSP_Length Length, vDSP_DFT_Direction Direction, \
                                                                   vDSP_DFT_RealtoComplex RealtoComplex); \
    VECLIB_EXTERN void vDSP_DFT_Interleaved_Execute##D(const IDSS *Setup, const CT *Iri, CT *Ori); \
    VECLIB_EXTERN void vDSP_DFT_Interleaved_DestroySetup##D(IDS _Nullable Setup); \
    VECLIB_EXTERN BQ _Nullable vDSP_biquad_CreateSetup##D(const double *Coefficients, vDSP_Length M); \
    VECLIB_EXTERN void vDSP_biquad_DestroySetup##D(BQ _Nullable Setup); \
    VECLIB_EXTERN void vDSP_biquad##D(const BQS *Setup, T *Delay, const T *X, vDSP_Stride IX, T *Y, vDSP_Stride IY, vDSP_Length N); \
    VECLIB_EXTERN BQM _Nullable vDSP_biquadm_CreateSetup##D(const double *coeffs, vDSP_Length M, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_biquadm_DestroySetup##D(BQM _Nullable setup); \
    VECLIB_EXTERN void vDSP_biquadm##D(BQM setup, const T *_Nonnull *_Nonnull X, vDSP_Stride IX, T *_Nonnull *_Nonnull Y, vDSP_Stride IY, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_biquadm_ResetState##D(BQM setup); \
    VECLIB_EXTERN void vDSP_biquadm_CopyState##D(BQM dest, const BQMS *src); \
    VECLIB_EXTERN void vDSP_biquadm_SetCoefficientsDouble##D(BQM setup, const double *coeffs, vDSP_Length start_sec, vDSP_Length start_chn, \
                                                             vDSP_Length nsec, vDSP_Length nchn); \
    VECLIB_EXTERN void vDSP_biquadm_SetTargetsDouble##D(BQM setup, const double *targets, double interp_rate, double interp_threshold, \
                                                        vDSP_Length start_sec, vDSP_Length start_chn, vDSP_Length nsec, vDSP_Length nchn); \
    VECLIB_EXTERN void vDSP_biquadm_SetActiveFilters##D(BQM setup, const bool *filter_states); \
    VECLIB_EXTERN void vDSP_deq22##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vdist##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vpythg##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, const T *C_, vDSP_Stride IC, const T *D_, \
                                      vDSP_Stride ID, T *E, vDSP_Stride IE, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_normalize##D(const T *A, vDSP_Stride IA, T *_Nullable C_, vDSP_Stride IC, T *Mean, T *StandardDeviation, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_zvmov##D(const SC *A, vDSP_Stride IA, const SC *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vpoly##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N, vDSP_Length P); \
    VECLIB_EXTERN void vDSP_vtrapz##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vsimps##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vrsum##D(const T *A, vDSP_Stride IA, const T *S, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vswsum##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N, vDSP_Length P); \
    VECLIB_EXTERN void vDSP_desamp##D(const T *A, vDSP_Stride DF, const T *F_, T *C_, vDSP_Length N, vDSP_Length P); \
    VECLIB_EXTERN void vDSP_vcmprs##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vgathr##D(const T *A, const vDSP_Length *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vtmerg##D(const T *A, vDSP_Stride IA, const T *B, vDSP_Stride IB, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vswap##D(T *A, vDSP_Stride IA, T *B, vDSP_Stride IB, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vthres##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vthrsc##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_viclip##D(const T *A, vDSP_Stride IA, const T *B, const T *C_, T *D_, vDSP_Stride ID, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vnabs##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vfrac##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vdbcon##D(const T *A, vDSP_Stride IA, const T *B, T *C_, vDSP_Stride IC, vDSP_Length N, unsigned int F_); \
    VECLIB_EXTERN void vDSP_vrampmul##D(const T *I, vDSP_Stride IS, T *Start, const T *Step, T *O, vDSP_Stride OS, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vrampmul2##D(const T *I0, const T *I1, vDSP_Stride IS, T *Start, const T *Step, T *O0, T *O1, vDSP_Stride OS, \
                                         vDSP_Length N); \
    VECLIB_EXTERN void vDSP_maxmgvi##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length *I, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_minmgvi##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Length *I, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_sve_svesq##D(const T *A, vDSP_Stride IA, T *Sum, T *SumOfSquares, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_polar##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_rect##D(const T *A, vDSP_Stride IA, T *C_, vDSP_Stride IC, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_nzcros##D(const T *A, vDSP_Stride IA, vDSP_Length B, vDSP_Length *C_, vDSP_Length *D_, vDSP_Length N); \
    VECLIB_EXTERN void vDSP_vaddsub##D(const T *I0, vDSP_Stride I0S, const T *I1, vDSP_Stride I1S, T *O0, vDSP_Stride O0S, T *O1, vDSP_Stride O1S, \
                                       vDSP_Length N);
VDSP_MORE(float, DSPComplex, DSPSplitComplex, FFTSetup, vDSP_DFT_Interleaved_Setup, struct vDSP_DFT_Interleaved_SetupStruct, vDSP_biquad_Setup,
          struct vDSP_biquad_SetupStruct, vDSP_biquadm_Setup, struct vDSP_biquadm_SetupStruct, )
VDSP_MORE(double, DSPDoubleComplex, DSPDoubleSplitComplex, FFTSetupD, vDSP_DFT_Interleaved_SetupD, struct vDSP_DFT_Interleaved_SetupStructD,
          vDSP_biquad_SetupD, struct vDSP_biquad_SetupStructD, vDSP_biquadm_SetupD, struct vDSP_biquadm_SetupStructD, D)
#undef VDSP_MORE
/* the DCT, single precision */
VECLIB_EXTERN vDSP_DFT_Setup _Nullable vDSP_DCT_CreateSetup(vDSP_DFT_Setup _Nullable Previous, vDSP_Length Length, vDSP_DCT_Type Type);
VECLIB_EXTERN void vDSP_DCT_Execute(const struct vDSP_DFT_SetupStruct *Setup, const float *Input, float *Output);

/* conversions */
VECLIB_EXTERN void vDSP_vspdp(const float *A, vDSP_Stride IA, double *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vdpsp(const double *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfltu8(const unsigned char *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vflt8(const char *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vflt16(const short *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfltu16(const unsigned short *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vflt32(const int *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfix8(const float *A, vDSP_Stride IA, char *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfix16(const float *A, vDSP_Stride IA, short *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfix32(const float *A, vDSP_Stride IA, int *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixr16(const float *A, vDSP_Stride IA, short *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixu8(const float *A, vDSP_Stride IA, unsigned char *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixru8(const float *A, vDSP_Stride IA, unsigned char *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfltu32(const unsigned int *A, vDSP_Stride IA, float *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixr8(const float *A, vDSP_Stride IA, char *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixr32(const float *A, vDSP_Stride IA, int *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixu16(const float *A, vDSP_Stride IA, unsigned short *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixru16(const float *A, vDSP_Stride IA, unsigned short *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixu32(const float *A, vDSP_Stride IA, unsigned int *C, vDSP_Stride IC, vDSP_Length N);
VECLIB_EXTERN void vDSP_vfixru32(const float *A, vDSP_Stride IA, unsigned int *C, vDSP_Stride IC, vDSP_Length N);

/* the DFT API: any length the routines support (f * 2^n, f in 1, 3, 5, 15), complex or real */
VECLIB_EXTERN vDSP_DFT_Setup _Nullable vDSP_DFT_zop_CreateSetup(vDSP_DFT_Setup _Nullable Previous, vDSP_Length Length, vDSP_DFT_Direction Direction);
VECLIB_EXTERN vDSP_DFT_Setup _Nullable vDSP_DFT_zrop_CreateSetup(vDSP_DFT_Setup _Nullable Previous, vDSP_Length Length, vDSP_DFT_Direction Direction);
VECLIB_EXTERN void vDSP_DFT_Execute(const struct vDSP_DFT_SetupStruct *Setup, const float *Ir, const float *Ii, float *Or, float *Oi);
VECLIB_EXTERN void vDSP_DFT_DestroySetup(vDSP_DFT_Setup _Nullable Setup);
VECLIB_EXTERN vDSP_DFT_SetupD _Nullable vDSP_DFT_zop_CreateSetupD(vDSP_DFT_SetupD _Nullable Previous, vDSP_Length Length, vDSP_DFT_Direction Direction);
VECLIB_EXTERN vDSP_DFT_SetupD _Nullable vDSP_DFT_zrop_CreateSetupD(vDSP_DFT_SetupD _Nullable Previous, vDSP_Length Length, vDSP_DFT_Direction Direction);
VECLIB_EXTERN void vDSP_DFT_ExecuteD(const struct vDSP_DFT_SetupStructD *Setup, const double *Ir, const double *Ii, double *Or, double *Oi);
VECLIB_EXTERN void vDSP_DFT_DestroySetupD(vDSP_DFT_SetupD _Nullable Setup);
