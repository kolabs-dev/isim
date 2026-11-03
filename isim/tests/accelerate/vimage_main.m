// vImage from C (VImageCTest.app, issue #371): buffers, conversions, geometry, convolution, morphology, histograms,
// alpha compositing, colour matrices, lookup tables, Y'CbCr and Core Graphics interoperation, checked against values
// worked out by hand.
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
#include <CoreVideo/CoreVideo.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int checks, failures;
#define CHECK(cond, what) do { checks++; if (cond) printf("PASS  %s\n", what); else { failures++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)

static vImage_Buffer buf(void *data, size_t w, size_t h, size_t bpp) { return (vImage_Buffer){ data, h, w, w * bpp }; }
static int same8(const uint8_t *a, const uint8_t *b, int n, int tol) {
    for (int i = 0; i < n; i++) if (abs(a[i] - b[i]) > tol) { printf("      [%d] %d != %d\n", i, a[i], b[i]); return 0; }
    return 1;
}

static void buffers(void) {
    vImage_Buffer b;
    CHECK(vImageBuffer_Init(&b, 3, 5, 32, kvImageNoFlags) == kvImageNoError && b.width == 5 && b.height == 3 && b.rowBytes >= 20
          && ((uintptr_t)b.data & 15) == 0, "vImageBuffer_Init");
    CGSize s = vImageBuffer_GetSize(&b);
    CHECK(s.width == 5 && s.height == 3, "vImageBuffer_GetSize");
    vImage_Buffer probe;
    CHECK(vImageBuffer_Init(&probe, 3, 5, 32, kvImageNoAllocate) > 0 && probe.data == NULL && probe.rowBytes >= 20,
          "kvImageNoAllocate: the row bytes and the preferred alignment");
    Pixel_8888 red = { 255, 255, 0, 0 };
    vImageBufferFill_ARGB8888(&b, red, kvImageNoFlags);
    uint8_t *p = (uint8_t *)b.data + b.rowBytes * 2 + 4 * 4;
    CHECK(p[0] == 255 && p[1] == 255 && p[2] == 0 && p[3] == 0, "vImageBufferFill_ARGB8888");
    free(b.data);
    CHECK(vImageBuffer_Init(&b, 0, 5, 8, kvImageNoFlags) == kvImageInvalidParameter, "a zero size is an error");
}

static void conversions(void) {
    uint8_t argb[8] = { 255, 10, 20, 30, 128, 40, 50, 60 }, rgb[6], back[8];
    vImage_Buffer a = buf(argb, 2, 1, 4), r = buf(rgb, 2, 1, 3), bk = buf(back, 2, 1, 4);
    vImageConvert_ARGB8888toRGB888(&a, &r, kvImageNoFlags);
    CHECK(same8(rgb, (uint8_t[]){ 10, 20, 30, 40, 50, 60 }, 6, 0), "ARGB8888toRGB888");
    vImageConvert_RGB888toARGB8888(&r, NULL, 200, &bk, false, kvImageNoFlags);
    CHECK(same8(back, (uint8_t[]){ 200, 10, 20, 30, 200, 40, 50, 60 }, 8, 0), "RGB888toARGB8888 with a constant alpha");
    uint8_t pa[2], pr[2], pg[2], pb[2];
    vImage_Buffer A = buf(pa, 2, 1, 1), R = buf(pr, 2, 1, 1), G = buf(pg, 2, 1, 1), B = buf(pb, 2, 1, 1);
    vImageConvert_ARGB8888toPlanar8(&a, &A, &R, &G, &B, kvImageNoFlags);
    CHECK(pa[1] == 128 && pr[0] == 10 && pg[1] == 50 && pb[0] == 30, "ARGB8888toPlanar8");
    memset(back, 0, sizeof back);
    vImageConvert_Planar8toARGB8888(&A, &R, &G, &B, &bk, kvImageNoFlags);
    CHECK(same8(back, argb, 8, 0), "Planar8toARGB8888 round trip");
    float f[2]; vImage_Buffer F = buf(f, 2, 1, 4);
    vImageConvert_Planar8toPlanarF(&A, &F, 2.0f, 0.0f, kvImageNoFlags);
    CHECK(fabsf(f[0] - 2) < 1e-6f && fabsf(f[1] - 128 * 2.0f / 255) < 1e-6f, "Planar8toPlanarF maps 0...255 to min...max");
    f[0] = 0.5f; f[1] = 3;
    vImageConvert_PlanarFtoPlanar8(&F, &A, 1, 0, kvImageNoFlags);
    CHECK(pa[0] == 128 && pa[1] == 255, "PlanarFtoPlanar8 rounds and clamps");
    uint16_t h16[2]; vImage_Buffer H = buf(h16, 2, 1, 2);
    f[0] = 1.5f; f[1] = -0.25f;
    vImageConvert_PlanarFtoPlanar16F(&F, &H, kvImageNoFlags);
    CHECK(h16[0] == 0x3e00 && h16[1] == 0xb400, "PlanarFtoPlanar16F");
    f[0] = f[1] = 0;
    vImageConvert_Planar16FtoPlanarF(&H, &F, kvImageNoFlags);
    CHECK(f[0] == 1.5f && f[1] == -0.25f, "Planar16FtoPlanarF");
    uint16_t u16[2]; vImage_Buffer U = buf(u16, 2, 1, 2);
    pa[0] = 255; pa[1] = 1;
    vImageConvert_Planar8To16U(&A, &U, kvImageNoFlags);
    CHECK(u16[0] == 65535 && u16[1] == 257, "Planar8To16U");
    f[0] = 2; f[1] = 4;
    vImageConvert_FTo16U(&F, &U, 0, 0.5f, kvImageNoFlags);
    CHECK(u16[0] == 4 && u16[1] == 8, "FTo16U with an offset and scale");
    uint8_t perm[8];
    vImage_Buffer P = buf(perm, 2, 1, 4);
    const uint8_t map[4] = { 3, 2, 1, 0 };
    vImagePermuteChannels_ARGB8888(&a, &P, map, kvImageNoFlags);
    CHECK(same8(perm, (uint8_t[]){ 30, 20, 10, 255, 60, 50, 40, 128 }, 8, 0), "PermuteChannels_ARGB8888");
    uint16_t p565[2]; vImage_Buffer W = buf(p565, 2, 1, 2);
    uint8_t px[8] = { 255, 255, 0, 0, 255, 0, 255, 255 };
    vImage_Buffer X = buf(px, 2, 1, 4);
    vImageConvert_ARGB8888toRGB565(&X, &W, kvImageNoFlags);
    CHECK(p565[0] == 0xf800 && p565[1] == 0x07ff, "ARGB8888toRGB565");
    memset(px, 0, sizeof px);
    vImageConvert_RGB565toARGB8888(255, &W, &X, kvImageNoFlags);
    CHECK(same8(px, (uint8_t[]){ 255, 255, 0, 0, 255, 0, 255, 255 }, 8, 0), "RGB565toARGB8888");
    uint8_t bits[1] = { 0xa0 }, out8[3]; vImage_Buffer bitsB = buf(bits, 3, 1, 1), o8 = buf(out8, 3, 1, 1);
    bitsB.rowBytes = 1;
    vImageConvert_Planar1toPlanar8(&bitsB, &o8, kvImageNoFlags);
    CHECK(out8[0] == 255 && out8[1] == 0 && out8[2] == 255, "Planar1toPlanar8 (most significant bit first)");
}

static void ycbcr(void) {
    vImage_YpCbCrPixelRange full = { 0, 128, 255, 255, 255, 0, 255, 0 };
    vImage_ARGBToYpCbCr to; vImage_YpCbCrToARGB from;
    CHECK(vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &full, &to, kvImageARGB8888, kvImage420Yp8_CbCr8, 0) == 0
          && vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &full, &from, kvImage420Yp8_CbCr8, kvImageARGB8888, 0) == 0,
          "GenerateConversion (ITU-R 601, full range)");
    uint8_t argb[4 * 4 * 4];
    for (int i = 0; i < 16; i++) { argb[i * 4] = 255; argb[i * 4 + 1] = 200; argb[i * 4 + 2] = 100; argb[i * 4 + 3] = 50; }
    uint8_t y[16], cbcr[2 * 2 * 2], back[64];
    vImage_Buffer A = buf(argb, 4, 4, 4), Y = buf(y, 4, 4, 1), C = buf(cbcr, 2, 2, 2), B = buf(back, 4, 4, 4);
    CHECK(vImageConvert_ARGB8888To420Yp8_CbCr8(&A, &Y, &C, &to, NULL, 0) == 0, "ARGB8888To420Yp8_CbCr8");
    CHECK(abs(y[0] - (int)lrint(0.299 * 200 + 0.587 * 100 + 0.114 * 50)) <= 1, "Y' from the 601 matrix");
    CHECK(vImageConvert_420Yp8_CbCr8ToARGB8888(&Y, &C, &B, &from, NULL, 255, 0) == 0, "420Yp8_CbCr8ToARGB8888");
    CHECK(same8(back, argb, 64, 2), "4:2:0 round trip");
    uint8_t uyvy[4 * 2 * 4]; vImage_Buffer Q = buf(uyvy, 4, 4, 2);
    vImageConvert_ARGB8888To422CbYpCrYp8(&A, &Q, &to, NULL, 0);
    memset(back, 0, sizeof back);
    vImageConvert_422CbYpCrYp8ToARGB8888(&Q, &B, &from, NULL, 255, 0);
    CHECK(same8(back, argb, 64, 2), "4:2:2 (uyvy) round trip");
}

static void geometry(void) {
    uint8_t s[6] = { 1, 2, 3, 4, 5, 6 }, d[6];
    vImage_Buffer S = buf(s, 3, 2, 1), D = buf(d, 3, 2, 1);
    vImageHorizontalReflect_Planar8(&S, &D, 0);
    CHECK(same8(d, (uint8_t[]){ 3, 2, 1, 6, 5, 4 }, 6, 0), "HorizontalReflect_Planar8");
    vImageVerticalReflect_Planar8(&S, &D, 0);
    CHECK(same8(d, (uint8_t[]){ 4, 5, 6, 1, 2, 3 }, 6, 0), "VerticalReflect_Planar8");
    uint8_t r[6]; vImage_Buffer R = buf(r, 2, 3, 1);
    vImageRotate90_Planar8(&S, &R, kRotate90DegreesCounterClockwise, 0, 0);
    CHECK(same8(r, (uint8_t[]){ 3, 6, 2, 5, 1, 4 }, 6, 0), "Rotate90 counterclockwise");
    vImageRotate90_Planar8(&S, &R, kRotate90DegreesClockwise, 0, 0);
    CHECK(same8(r, (uint8_t[]){ 4, 1, 5, 2, 6, 3 }, 6, 0), "Rotate90 clockwise");
    uint8_t q[9] = { 0, 0, 0, 0, 0, 200, 0, 0, 0 }, qo[9];
    vImage_Buffer Qs = buf(q, 3, 3, 1), Qd = buf(qo, 3, 3, 1);
    vImageRotate_Planar8(&Qs, &Qd, NULL, (float)M_PI / 2, 0, kvImageBackgroundColorFill);
    CHECK(qo[1] == 200 && qo[5] == 0, "Rotate by pi / 2 (counterclockwise on screen)");
    vImage_AffineTransform shift = { 1, 0, 0, 1, 1, 0 };
    vImageAffineWarp_Planar8(&Qs, &Qd, NULL, &shift, 7, kvImageBackgroundColorFill);
    CHECK(qo[0] == 7 && qo[4] == 0 && qo[3] == 7 && qo[5] == 0 && qo[6] == 7, "AffineWarp translation, background fill");
    vImage_AffineTransform left = { 1, 0, 0, 1, -1, 0 };
    vImageAffineWarp_Planar8(&Qs, &Qd, NULL, &left, 7, kvImageBackgroundColorFill);
    CHECK(qo[4] == 200 && qo[5] == 7, "AffineWarp moves the source to the destination");
    // scaling a constant image keeps it constant; 2x downscaling averages
    uint8_t c[16 * 4], cd[4 * 4];
    for (int i = 0; i < 64; i++) c[i] = (uint8_t)(i % 4 == 0 ? 255 : 90);
    vImage_Buffer Cs = buf(c, 4, 4, 4), Cd = buf(cd, 2, 2, 4);
    vImageScale_ARGB8888(&Cs, &Cd, NULL, 0);
    int constant = 1; for (int i = 0; i < 16; i++) if (cd[i] != (i % 4 == 0 ? 255 : 90)) constant = 0;
    CHECK(constant, "Scale_ARGB8888 keeps a flat image flat");
    float ramp[16], half[8];
    for (int i = 0; i < 16; i++) ramp[i] = (float)i;
    vImage_Buffer Rs = buf(ramp, 16, 1, 4), Rd = buf(half, 8, 1, 4);
    vImageScale_PlanarF(&Rs, &Rd, NULL, 0);
    CHECK(fabsf(half[3] - 6.5f) < 1e-4f && fabsf(half[4] - 8.5f) < 1e-4f, "Scale_PlanarF halves a ramp (away from the edges)");
    uint8_t big[16]; vImage_Buffer Bg = buf(big, 4, 4, 1), Sm = buf((uint8_t[]){ 0, 255, 255, 0 }, 2, 2, 1);
    vImageScale_Planar8(&Sm, &Bg, NULL, 0);
    CHECK(big[0] < 60 && big[3] > 195 && big[12] > 195, "Scale_Planar8 upscales");
    // a homography of a square onto itself is the identity
    const float sq[4][2] = { { 0, 0 }, { 1, 0 }, { 1, 1 }, { 0, 1 } }, wide[4][2] = { { 0, 0 }, { 2, 0 }, { 2, 1 }, { 0, 1 } };
    vImage_PerpsectiveTransform t;
    CHECK(vImageGetPerspectiveWarp(sq, sq, &t, 0) == 0 && fabsf(t.a - 1) < 1e-5f && fabsf(t.d - 1) < 1e-5f && fabsf(t.tx) < 1e-5f && fabsf(t.vx) < 1e-5f,
          "GetPerspectiveWarp: identity");
    CHECK(vImageGetPerspectiveWarp(sq, wide, &t, 0) == 0 && fabsf(t.a - 2) < 1e-5f && fabsf(t.d - 1) < 1e-5f, "GetPerspectiveWarp: a stretch");
    ResamplingFilter filter = vImageNewResamplingFilter(1, 0);
    uint8_t sh[3]; vImage_Buffer Sh = buf(sh, 3, 1, 1), Src = buf((uint8_t[]){ 10, 20, 30 }, 3, 1, 1);
    vImageHorizontalShear_Planar8(&Src, &Sh, 0, 0, 0, 0, filter, 0, kvImageEdgeExtend);
    CHECK(sh[0] == 10 && sh[1] == 20 && sh[2] == 30, "HorizontalShear with no shear copies");
    vImageHorizontalShear_Planar8(&Src, &Sh, 0, 0, 1, 0, filter, 0, kvImageBackgroundColorFill);
    CHECK(sh[0] == 0 && sh[1] == 10 && sh[2] == 20, "HorizontalShear translates");
    vImageDestroyResamplingFilter(filter);
}

static void filters(void) {
    uint8_t imp[25] = { 0 }, o[25];
    imp[12] = 160;
    vImage_Buffer I = buf(imp, 5, 5, 1), O = buf(o, 5, 5, 1);
    const int16_t k[9] = { 1, 2, 1, 2, 4, 2, 1, 2, 1 };
    CHECK(vImageConvolve_Planar8(&I, &O, NULL, 0, 0, k, 3, 3, 16, 0, kvImageEdgeExtend) == 0, "Convolve_Planar8");
    CHECK(o[12] == 40 && o[11] == 20 && o[6] == 10 && o[0] == 0, "the impulse response is the kernel");
    uint8_t t[25];
    vImage_Buffer T = buf(t, 5, 5, 1);
    vImageTentConvolve_Planar8(&I, &T, NULL, 0, 0, 3, 3, 0, kvImageEdgeExtend);
    CHECK(same8(t, o, 25, 0), "TentConvolve 3x3 matches the 1-2-1 kernel");
    vImageBoxConvolve_Planar8(&I, &T, NULL, 0, 0, 3, 3, 0, kvImageEdgeExtend);
    CHECK(t[12] == 18 && t[6] == 18 && t[0] == 0, "BoxConvolve averages");
    CHECK(vImageBoxConvolve_Planar8(&I, &T, NULL, 0, 0, 4, 3, 0, kvImageEdgeExtend) == kvImageInvalidKernelSize, "even kernels are refused");
    CHECK(vImageBoxConvolve_Planar8(&I, &T, NULL, 0, 0, 3, 3, 0, 0) == kvImageInvalidEdgeStyle, "an edge mode is required");
    uint8_t flat[25]; memset(flat, 90, sizeof flat);
    vImage_Buffer Fl = buf(flat, 5, 5, 1);
    vImageConvolve_Planar8(&Fl, &O, NULL, 0, 0, k, 3, 3, 16, 0, kvImageBackgroundColorFill);
    CHECK(o[12] == 90 && o[0] == 51, "background fill darkens the corners (9/16 of the kernel inside)");
    vImageConvolve_Planar8(&Fl, &O, NULL, 0, 0, k, 3, 3, 16, 0, kvImageTruncateKernel);
    CHECK(o[0] == 90 && o[12] == 90, "truncating the kernel keeps a flat image flat");
    float fk[9] = { 0, 0, 0, 0, 0, 1, 0, 0, 0 }, fi[25], fo[25];
    for (int i = 0; i < 25; i++) fi[i] = (float)i;
    vImage_Buffer FI = buf(fi, 5, 5, 4), FO = buf(fo, 5, 5, 4);
    vImageConvolve_PlanarF(&FI, &FO, NULL, 0, 0, fk, 3, 3, 0, kvImageEdgeExtend);
    CHECK(fo[0] == 1 && fo[3] == 4 && fo[4] == 4, "Convolve_PlanarF is a correlation (the kernel is not flipped)");
    const float sx[3] = { 1, 2, 1 }, sy[3] = { 1, 2, 1 };
    float so[25]; vImage_Buffer SO = buf(so, 5, 5, 4);
    float ifl[25] = { 0 }; ifl[12] = 16; vImage_Buffer IF = buf(ifl, 5, 5, 4);
    vImageSepConvolve_PlanarF(&IF, &SO, NULL, 0, 0, sx, 3, sy, 3, 0, 0, kvImageEdgeExtend);
    CHECK(so[12] == 64 && so[6] == 16 && so[11] == 32, "SepConvolve_PlanarF");
    // morphology
    vImageMax_Planar8(&I, &O, NULL, 0, 0, 3, 3, 0);
    CHECK(o[6] == 160 && o[18] == 160 && o[0] == 0, "Max_Planar8 spreads the impulse");
    vImageMin_Planar8(&I, &O, NULL, 0, 0, 3, 3, 0);
    CHECK(o[12] == 0, "Min_Planar8 removes it");
    const uint8_t se[9] = { 0 };
    vImageDilate_Planar8(&I, &O, 0, 0, se, 3, 3, 0);
    CHECK(o[6] == 160 && o[0] == 0, "Dilate_Planar8 with a flat structuring element");
    // histograms
    uint8_t h8[8] = { 50, 50, 60, 70, 80, 90, 100, 100 }, ho[8];
    vImage_Buffer H = buf(h8, 8, 1, 1), HO = buf(ho, 8, 1, 1);
    vImagePixelCount hist[256];
    vImageHistogramCalculation_Planar8(&H, hist, 0);
    CHECK(hist[50] == 2 && hist[100] == 2 && hist[60] == 1 && hist[0] == 0, "HistogramCalculation_Planar8");
    vImageContrastStretch_Planar8(&H, &HO, 0);
    CHECK(ho[0] == 0 && ho[7] == 255 && abs(ho[4] - 153) <= 1, "ContrastStretch_Planar8");
    vImageEqualization_Planar8(&H, &HO, 0);
    CHECK(ho[0] == 0 && ho[7] == 255 && ho[2] < ho[3] && ho[3] < ho[4], "Equalization_Planar8");
    // alpha
    uint8_t pm[4] = { 128, 255, 100, 0 }, pmo[4];
    vImage_Buffer PM = buf(pm, 1, 1, 4), PMO = buf(pmo, 1, 1, 4);
    vImagePremultiplyData_ARGB8888(&PM, &PMO, 0);
    CHECK(pmo[0] == 128 && pmo[1] == 128 && pmo[2] == 50 && pmo[3] == 0, "PremultiplyData_ARGB8888");
    vImageUnpremultiplyData_ARGB8888(&PMO, &PMO, 0);
    CHECK(abs(pmo[1] - 255) <= 1 && abs(pmo[2] - 100) <= 1, "UnpremultiplyData_ARGB8888");
    uint8_t top[4] = { 128, 128, 0, 0 }, bot[4] = { 255, 0, 0, 255 }, bl[4];
    vImage_Buffer TP = buf(top, 1, 1, 4), BT = buf(bot, 1, 1, 4), BL = buf(bl, 1, 1, 4);
    vImagePremultipliedAlphaBlend_ARGB8888(&TP, &BT, &BL, 0);
    CHECK(bl[0] == 255 && bl[1] == 128 && abs(bl[3] - 127) <= 1, "PremultipliedAlphaBlend_ARGB8888");
    uint8_t fl[4] = { 0, 0, 0, 0 }, flo[3];
    vImage_Buffer FLs = buf(fl, 1, 1, 4), FLo = buf(flo, 1, 1, 3);
    vImageFlatten_ARGB8888ToRGB888(&FLs, &FLo, (uint8_t[]){ 255, 10, 20, 30 }, true, 0);
    CHECK(flo[0] == 10 && flo[1] == 20 && flo[2] == 30, "Flatten over the background");
    // colour matrix: swap red and blue, keep alpha and green
    const int16_t m[16] = { 1, 0, 0, 0,  0, 0, 0, 1,  0, 0, 1, 0,  0, 1, 0, 0 };
    uint8_t mm[4] = { 255, 10, 20, 30 }, mo[4];
    vImage_Buffer MM = buf(mm, 1, 1, 4), MO = buf(mo, 1, 1, 4);
    vImageMatrixMultiply_ARGB8888(&MM, &MO, m, 1, NULL, NULL, 0);
    CHECK(same8(mo, (uint8_t[]){ 255, 30, 20, 10 }, 4, 0), "MatrixMultiply_ARGB8888 (pixel x matrix)");
    // lookup tables and gamma
    Pixel_8 inv[256]; for (int i = 0; i < 256; i++) inv[i] = (Pixel_8)(255 - i);
    vImageTableLookUp_Planar8(&H, &HO, inv, 0);
    CHECK(ho[0] == 205 && ho[7] == 155, "TableLookUp_Planar8");
    GammaFunction g = vImageCreateGammaFunction(2.0f, kvImageGamma_UseGammaValue, 0);
    float gi[2] = { 0.5f, -0.5f }, go[2]; vImage_Buffer GI = buf(gi, 2, 1, 4), GO = buf(go, 2, 1, 4);
    vImageGamma_PlanarF(&GI, &GO, g, 0);
    CHECK(fabsf(go[0] - 0.25f) < 1e-6f && fabsf(go[1] + 0.25f) < 1e-6f, "Gamma_PlanarF (sign kept)");
    vImageDestroyGammaFunction(g);
    // flood fill
    uint8_t ff[9] = { 0, 0, 9, 0, 9, 0, 9, 0, 0 };
    vImage_Buffer FF = buf(ff, 3, 3, 1);
    vImageFloodFill_Planar8(&FF, NULL, 0, 0, 5, 4, 0);
    CHECK(ff[0] == 5 && ff[1] == 5 && ff[3] == 5 && ff[8] == 0 && ff[5] == 0, "FloodFill_Planar8, 4-connected");
}

static void core_graphics(void) {
    // BGRA in memory: premultiplied first, 32-bit little-endian words
    vImage_CGImageFormat bgra = { 8, 32, NULL, (CGBitmapInfo)(kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Little), 0, NULL,
                                  kCGRenderingIntentDefault };
    uint8_t px[2 * 2 * 4] = { 255, 0, 0, 255,  0, 255, 0, 255,  0, 0, 255, 255,  10, 20, 30, 255 };   /* b g r a */
    vImage_Buffer b = buf(px, 2, 2, 4);
    vImage_Error e = 0;
    CGImageRef im = vImageCreateCGImageFromBuffer(&b, &bgra, NULL, NULL, 0, &e);
    CHECK(im && e == 0 && CGImageGetWidth(im) == 2, "vImageCreateCGImageFromBuffer");
    vImage_CGImageFormat rgba = { 8, 32, NULL, (CGBitmapInfo)kCGImageAlphaPremultipliedLast, 0, NULL, kCGRenderingIntentDefault };
    vImage_Buffer out;
    CHECK(vImageBuffer_InitWithCGImage(&out, &rgba, NULL, im, 0) == 0 && out.width == 2 && out.height == 2, "vImageBuffer_InitWithCGImage");
    uint8_t *o = out.data;
    CHECK(o[0] == 0 && o[2] == 255 && o[3] == 255 && ((uint8_t *)out.data + out.rowBytes)[4] == 30, "the pixels in RGBA order");
    free(out.data);
    vImage_CGImageFormat own = { 0 };
    CHECK(vImageBuffer_InitWithCGImage(&out, &own, NULL, im, 0) == 0 && own.bitsPerPixel == 32 && own.bitsPerComponent == 8, "an empty format takes the image's");
    free(out.data);
    CGImageRelease(im);
    CHECK(vImageCGImageFormat_GetComponentCount(&rgba) == 4 && vImageCGImageFormat_IsEqual(&rgba, &rgba) && !vImageCGImageFormat_IsEqual(&rgba, &bgra),
          "vImageCGImageFormat_GetComponentCount, IsEqual");
    vImage_CGImageFormat argbF = { 32, 128, NULL, (CGBitmapInfo)(kCGImageAlphaFirst | kCGBitmapFloatComponents | kCGBitmapByteOrder32Little), 0, NULL,
                                   kCGRenderingIntentDefault };
    vImageConverterRef c = vImageConverter_CreateWithCGImageFormat(&bgra, &argbF, NULL, 0, &e);
    float fo[2 * 2 * 4]; vImage_Buffer F = buf(fo, 2, 2, 16);
    CHECK(c && e == 0 && vImageConvert_AnyToAny(c, &b, &F, NULL, 0) == 0, "vImageConverter and AnyToAny");
    CHECK(fo[0] == 1 && fo[1] == 0 && fo[3] == 1 && fabsf(fo[12 + 1] - 30 / 255.f) < 1e-6f, "BGRA8 to ARGB float");
    CHECK(vImageConverter_GetNumberOfSourceBuffers(c) == 1 && vImageConverter_GetSourceBufferOrder(c)[0] == kvImageBufferTypeCode_CGFormat,
          "converter buffer counts and order");
    vImageConverter_Release(c);
    // a float image becomes an 8-bit CGImage
    im = vImageCreateCGImageFromBuffer(&F, &argbF, NULL, NULL, 0, &e);
    CHECK(im && CGImageGetBitsPerComponent(im) == 8, "deeper formats become 8-bit CGImages");
    CGImageRelease(im);
}

/* ---- issue #693 ---- */
static uint32_t word(const void *p, int i) { uint32_t w; memcpy(&w, (const uint8_t *)p + i * 4, 4); return w; }
static void ycbcr_deep(void) {
    /* 16-bit full range */
    vImage_YpCbCrPixelRange f16 = { 0, 32768, 65535, 65535, 65535, 0, 65535, 0 };
    vImage_ARGBToYpCbCr to; vImage_YpCbCrToARGB from;
    CHECK(vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &f16, &to, kvImageARGB16U, kvImage422CbYpCrYp16, 0) == 0
          && vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &f16, &from, kvImage422CbYpCrYp16, kvImageARGB16U, 0) == 0,
          "GenerateConversion for ARGB16U and 16-bit Y'CbCr");
    uint8_t px[8] = { 255, 255, 255, 255, 255, 200, 40, 10 }, back[8];
    uint16_t v216[4];
    vImage_Buffer a = buf(px, 2, 1, 4), y = buf(v216, 2, 1, 4), b = buf(back, 2, 1, 4);
    CHECK(vImageConvert_ARGB8888To422CbYpCrYp16(&a, &y, &to, NULL, 0) == 0 && v216[1] == 65535 && v216[0] < 32768,
          "ARGB8888To422CbYpCrYp16: white has Y' 65535; the pair's Cb (with orange) is below the bias");
    CHECK(vImageConvert_422CbYpCrYp16ToARGB8888(&y, &b, &from, NULL, 99, 0) == 0 && back[0] == 99 && back[1] >= 240 && back[4] == 99,
          "422CbYpCrYp16ToARGB8888 with the given alpha");
    uint16_t px16[4] = { 65535, 0, 65535, 0 }, px16b[4 * 2] = { 0 }, src16[8] = { 65535, 0, 65535, 0, 65535, 0, 65535, 0 };
    vImage_Buffer s16 = buf(src16, 2, 1, 8), d16 = buf(px16b, 2, 1, 8);
    (void)px16;
    CHECK(vImageConvert_ARGB16UTo422CbYpCrYp16(&s16, &y, &to, NULL, 0) == 0 && vImageConvert_422CbYpCrYp16ToARGB16U(&y, &d16, &from, NULL, 65535, 0) == 0
          && px16b[1] < 200 && px16b[2] > 65000 && px16b[3] < 200, "ARGB16U <-> 422CbYpCrYp16: green stays green");
    /* 444AYpCbCr16 keeps alpha */
    uint16_t y416[4]; uint8_t one[4] = { 128, 10, 200, 30 }, oneb[4];
    vImage_Buffer o = buf(one, 1, 1, 4), oy = buf(y416, 1, 1, 8), ob = buf(oneb, 1, 1, 4);
    CHECK(vImageConvert_ARGB8888To444AYpCbCr16(&o, &oy, &to, NULL, 0) == 0 && y416[0] == 128 * 257
          && vImageConvert_444AYpCbCr16ToARGB8888(&oy, &ob, &from, NULL, 0) == 0 && same8(one, oneb, 4, 2), "444AYpCbCr16 round trip with alpha");
    /* 10-bit video range */
    vImage_YpCbCrPixelRange v10 = { 64, 512, 940, 960, 1023, 0, 1023, 0 };
    vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, &v10, &to, kvImageARGB8888, kvImage444CrYpCb10, 0);
    vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_709_2, &v10, &from, kvImage444CrYpCb10, kvImageARGB8888, 0);
    uint8_t white[4] = { 255, 255, 255, 255 }; uint32_t v410;
    vImage_Buffer w = buf(white, 1, 1, 4), wv = buf(&v410, 1, 1, 4);
    CHECK(vImageConvert_ARGB8888To444CrYpCb10(&w, &wv, &to, NULL, 0) == 0 && v410 == (512u << 22 | 940u << 12 | 512u << 2),
          "444CrYpCb10: white is Cr 512, Y' 940, Cb 512 in bits 22, 12 and 2");
    uint8_t col[4] = { 255, 30, 160, 220 }, colb[4]; vImage_Buffer c = buf(col, 1, 1, 4), cb = buf(colb, 1, 1, 4);
    CHECK(vImageConvert_ARGB8888To444CrYpCb10(&c, &wv, &to, NULL, 0) == 0 && vImageConvert_444CrYpCb10ToARGB8888(&wv, &cb, &from, NULL, 255, 0) == 0
          && same8(col, colb, 4, 2), "444CrYpCb10 round trip");
    int16_t q[4]; vImage_Buffer qb = buf(q, 1, 1, 8);
    vImageConvert_ARGB8888To444CrYpCb10(&w, &wv, &to, NULL, 0);
    CHECK(vImageConvert_444CrYpCb10ToARGB16Q12(&wv, &qb, &from, NULL, 4096, 0) == 0 && q[0] == 4096 && abs(q[1] - 4096) < 8, "444CrYpCb10ToARGB16Q12: white is 4096");
    /* v210: six pixels in 16 bytes */
    uint8_t six[24] = { 255, 0, 0, 0, 255, 0, 0, 0, 255, 255, 255, 0, 255, 255, 255, 255, 255, 0, 255, 0, 255, 0, 255, 255 }, sixb[24];
    uint32_t v210[4];
    vImage_Buffer sx = buf(six, 6, 1, 4), sv = buf(v210, 6, 1, 16), sb = buf(sixb, 6, 1, 4);
    sv.rowBytes = 16;
    CHECK(vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(&sx, &sv, &to, NULL, 0) == 0 && (v210[0] >> 10 & 1023) == 64 && (v210[0] & 1023) == 512
          && (v210[0] >> 20 & 1023) == 512, "422CrYpCbYpCbYpCbYpCrYpCrYp10: black is Cb 512, Y' 64, Cr 512 in the first word");
    CHECK(vImageConvert_422CrYpCbYpCbYpCbYpCrYpCrYp10ToARGB8888(&sv, &sb, &from, NULL, 255, 0) == 0 && sixb[1] < 4 && sixb[3] < 4 && sixb[12 + 1] > 240 && sixb[12 + 2] > 240 && sixb[16 + 2] > 200 && sixb[16 + 1] < 40,
          "v210 back to ARGB8888: black stays black, white white, green green");
    sx.width = 4;
    CHECK(vImageConvert_ARGB8888To422CrYpCbYpCbYpCbYpCrYpCrYp10(&sx, &sv, &to, NULL, 0) == kvImageInvalidParameter, "v210 widths are multiples of 6");
    /* 2vuy with an alpha plane */
    vImage_YpCbCrPixelRange f8 = { 0, 128, 255, 255, 255, 0, 255, 0 };
    vImageConvert_ARGBToYpCbCr_GenerateConversion(kvImage_ARGBToYpCbCrMatrix_ITU_R_601_4, &f8, &to, kvImageARGB8888, kvImage422CbYpCrYp8_AA8, 0);
    vImageConvert_YpCbCrToARGB_GenerateConversion(kvImage_YpCbCrToARGBMatrix_ITU_R_601_4, &f8, &from, kvImage422CbYpCrYp8_AA8, kvImageARGB8888, 0);
    uint8_t two[8] = { 10, 50, 50, 50, 240, 50, 50, 50 }, tv[4], ta[2], twob[8];
    vImage_Buffer t = buf(two, 2, 1, 4), tvb = buf(tv, 2, 1, 2), tab = buf(ta, 2, 1, 1), tb = buf(twob, 2, 1, 4);
    CHECK(vImageConvert_ARGB8888To422CbYpCrYp8_AA8(&t, &tvb, &tab, &to, NULL, 0) == 0 && ta[0] == 10 && ta[1] == 240
          && vImageConvert_422CbYpCrYp8_AA8ToARGB8888(&tvb, &tab, &tb, &from, NULL, 0) == 0 && same8(two, twob, 8, 2), "422CbYpCrYp8_AA8 round trip with the alpha plane");
}
static void packed10(void) {
    uint8_t px[4] = { 255, 255, 0, 128 }, back[4];
    uint32_t w10;
    vImage_Buffer a = buf(px, 1, 1, 4), w = buf(&w10, 1, 1, 4), b = buf(back, 1, 1, 4);
    CHECK(vImageConvert_ARGB8888ToARGB2101010(&a, &w, 0, 1023, NULL, 0) == 0 && w10 == (3u << 30 | 1023u << 20 | 514u),
          "ARGB8888ToARGB2101010: A in bits 30-31, R 20-29, G 10-19, B 0-9");
    CHECK(vImageConvert_ARGB2101010ToARGB8888(&w, &b, 0, 1023, NULL, 0) == 0 && same8(px, back, 4, 1), "ARGB2101010ToARGB8888");
    CHECK(vImageConvert_ARGB8888ToRGBA1010102(&a, &w, 0, 1023, NULL, 0) == 0 && w10 == (1023u << 22 | 514u << 2 | 3u), "RGBA1010102: R in bits 22-31, A in 0-1");
    CHECK(vImageConvert_RGBA1010102ToARGB16U(&w, &(vImage_Buffer){ (uint16_t[4]){ 0 }, 1, 1, 8 }, 0, 1023, NULL, 0) == 0, "RGBA1010102ToARGB16U");
    CHECK(vImageConvert_ARGB8888ToXRGB2101010(&a, &w, 64, 940, NULL, 0) == 0 && (w10 >> 20 & 1023) == 940 && (w10 >> 10 & 1023) == 64,
          "XRGB2101010 with a video range: 1.0 is 940, 0.0 is 64");
    CHECK(vImageConvert_XRGB2101010ToARGB8888(&w, 77, &b, 64, 940, NULL, 0) == 0 && back[0] == 77 && back[1] == 255 && back[2] == 0, "XRGB2101010ToARGB8888 with an alpha");
    int16_t q[4] = { 4096, 4096, 0, 2048 }; vImage_Buffer qb = buf(q, 1, 1, 8);
    CHECK(vImageConvert_ARGB16Q12ToARGB2101010(&qb, &w, 0, 1023, 0, 1023, NULL, 0) == 0 && (w10 >> 20 & 1023) == 1023 && (w10 & 1023) == 512,
          "ARGB16Q12ToARGB2101010");
    float ff[4]; vImage_Buffer fb = buf(ff, 1, 1, 16);
    CHECK(vImageConvert_ARGB2101010ToARGBFFFF(&w, &fb, 0, 1023, NULL, 0) == 0 && ff[1] == 1 && fabsf(ff[3] - 512 / 1023.f) < 1e-6f, "ARGB2101010ToARGBFFFF");
    /* the extended-range scale: a 2x1 image becomes 4x2 with the same colour */
    uint32_t sw[2], dw[8];
    uint32_t c = 3u << 30 | 894u << 20 | 384u << 10 | 639u;
    sw[0] = sw[1] = c;
    vImage_Buffer s = buf(sw, 2, 1, 4), d = buf(dw, 4, 2, 4);
    CHECK(vImageScale_XRGB2101010W(&s, &d, NULL, 0) == 0 && word(dw, 5) == c, "vImageScale_XRGB2101010W keeps a flat colour");
    CHECK(vImageHorizontalShear_XRGB2101010W(&s, &(vImage_Buffer){ dw, 1, 2, 8 }, 0, 0, 0, 0,
                                              vImageNewResamplingFilter(1, 0), c, kvImageBackgroundColorFill) == 0 && dw[0] == c, "vImageHorizontalShear_XRGB2101010W");
}
static void more_filters(void) {
    /* indexed: the palette comes from the image */
    uint8_t img[8] = { 10, 10, 10, 10, 200, 200, 200, 200 }, idx1[1] = { 0 }, pal[16];
    vImage_Buffer s = buf(img, 8, 1, 1), d = { idx1, 1, 8, 1 };
    CHECK(vImageConvert_Planar8toIndexed1(&s, &d, NULL, pal, kvImageConvert_DitherNone, 0) == 0 && pal[0] == 10 && pal[1] == 200 && idx1[0] == 0x0f,
          "Planar8toIndexed1: palette {10, 200}, most significant bit first");
    uint8_t four[4] = { 0, 85, 170, 255 }, idx2[1], back[4];
    vImage_Buffer s4 = buf(four, 4, 1, 1), d2 = { idx2, 1, 4, 1 }, b4 = buf(back, 4, 1, 1);
    CHECK(vImageConvert_Planar8toIndexed2(&s4, &d2, NULL, pal, kvImageConvert_DitherNone, 0) == 0 && vImageConvert_Indexed2toPlanar8(&d2, &b4, pal, 0) == 0
          && same8(four, back, 4, 0), "Planar8toIndexed2 and back: four levels exactly");
    uint8_t ramp[16], idx4[8];
    for (int i = 0; i < 16; i++) ramp[i] = (uint8_t)(i * 16);
    vImage_Buffer sr = buf(ramp, 16, 1, 1), d4 = { idx4, 1, 16, 8 };
    CHECK(vImageConvert_Planar8toIndexed4(&sr, &d4, NULL, pal, kvImageConvert_DitherFloydSteinberg, 0) == 0, "Planar8toIndexed4 with Floyd-Steinberg");
    /* a 2 x 2 table over two channels: bilinear in the middle */
    uint16_t table[4] = { 0, 4096, 4096, 0 };
    uint8_t dims[2] = { 2, 2 };
    vImage_Error e;
    vImage_MultidimensionalTable t = vImageMultidimensionalTable_Create(table, 2, 1, dims, kvImageMDTableHint_Float, 0, &e);
    float x0[2] = { 0.5f, 1 }, x1[2] = { 0.5f, 0 }, out[2];
    vImage_Buffer srcs[2] = { buf(x0, 2, 1, 4), buf(x1, 2, 1, 4) }, dests[1] = { buf(out, 2, 1, 4) };
    CHECK(t && e == 0 && vImageMultiDimensionalInterpolatedLookupTable_PlanarF(srcs, dests, NULL, t, kvImageFullInterpolation, 0) == 0
          && fabsf(out[0] - 0.5f) < 1e-5f && fabsf(out[1] - 1) < 1e-5f, "vImageMultiDimensionalInterpolatedLookupTable_PlanarF");
    CHECK(vImageMultidimensionalTable_Retain(t) == 0 && vImageMultidimensionalTable_Release(t) == 0 && vImageMultidimensionalTable_Release(t) == 0,
          "MultidimensionalTable retain and release");
    /* Richardson-Lucy: a 1x1 kernel changes nothing; a blurred spike gets sharper */
    float spike[25] = { 0 }, blurred[25], sharper[25];
    spike[12] = 9;
    float box[9] = { 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f, 1 / 9.f };
    vImage_Buffer sp = buf(spike, 5, 5, 4), bl = buf(blurred, 5, 5, 4), sh = buf(sharper, 5, 5, 4);
    vImageConvolve_PlanarF(&sp, &bl, NULL, 0, 0, box, 3, 3, 0, kvImageEdgeExtend);
    for (int i = 0; i < 25; i++) blurred[i] += 0.01f;
    CHECK(vImageRichardsonLucyDeConvolve_PlanarF(&bl, &sh, NULL, 0, 0, box, NULL, 3, 3, 0, 0, 0, 20, kvImageEdgeExtend) == 0 && sharper[12] > blurred[12] * 2,
          "vImageRichardsonLucyDeConvolve_PlanarF sharpens a blurred spike");
    uint8_t flat[9] = { 50, 50, 50, 50, 50, 50, 50, 50, 50 }, flatb[9]; int16_t k1[1] = { 1 };
    vImage_Buffer fl = buf(flat, 3, 3, 1), flb = buf(flatb, 3, 3, 1);
    CHECK(vImageRichardsonLucyDeConvolve_Planar8(&fl, &flb, NULL, 0, 0, k1, NULL, 1, 1, 0, 0, 1, 0, 0, 5, kvImageEdgeExtend) == 0 && same8(flat, flatb, 9, 0),
          "vImageRichardsonLucyDeConvolve_Planar8 with a 1x1 kernel");
    /* Planar8 -> 16U */
    uint16_t o16[9]; float k3[3] = { 0.25f, 0.5f, 0.25f };
    vImage_Buffer o = buf(o16, 3, 3, 2);
    flat[4] = 50;
    CHECK(vImageSepConvolve_Planar8to16U(&fl, &o, NULL, 0, 0, k3, 3, k3, 3, 257, 1, 0, kvImageEdgeExtend) == 0 && o16[4] == 50 * 257 + 1,
          "vImageSepConvolve_Planar8to16U: sum * scale + bias");
    /* PNG filters */
    uint8_t rows[2][4] = { { 1, 1, 1, 1 }, { 1, 1, 1, 1 } };
    vImage_Buffer pb = { rows, 2, 4, 4 };
    CHECK(vImagePNGDecompressionFilter(&pb, 0, 1, 8, 0, kvImage_PNG_FILTER_VALUE_SUB, 0) == 0 && rows[0][3] == 4, "PNG Sub filter");
    CHECK(vImagePNGDecompressionFilter(&pb, 1, 1, 8, 0, kvImage_PNG_FILTER_VALUE_UP, 0) == 0 && rows[1][2] == 4, "PNG Up filter");
    uint8_t pa[2][2] = { { 10, 20 }, { 5, 5 } };
    vImage_Buffer ppb = { pa, 2, 2, 2 };
    CHECK(vImagePNGDecompressionFilter(&ppb, 1, 1, 8, 0, kvImage_PNG_FILTER_VALUE_PAETH, 0) == 0 && pa[1][0] == 15 && pa[1][1] == 25, "PNG Paeth filter");
    CHECK(vImagePNGDecompressionFilter(&ppb, 1, 1, 8, 1, 0, 0) == kvImageInvalidParameter, "only filter method 0");
    /* colour spaces */
    vImageRGBPrimaries srgb = { 0.64f, 0.30f, 0.15f, 0.3127f, 0.33f, 0.60f, 0.06f, 0.3290f };
    vImageTransferFunction tf = { .c0 = 1, .c1 = 1 / 1.055, .c2 = 0.055 / 1.055, .c3 = 0, .gamma = 2.4, .cutoff = 0.04045, .c4 = 1 / 12.92, .c5 = 0 };
    CGColorSpaceRef cs = vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction(&srgb, &tf, kCGRenderingIntentDefault, 0, &e);
    CFDataRef icc = cs ? CGColorSpaceCopyICCData(cs) : NULL;
    CHECK(cs && e == 0 && CGColorSpaceGetModel(cs) == kCGColorSpaceModelRGB && icc && CFDataGetLength(icc) > 132,
          "vImageCreateRGBColorSpaceWithPrimariesAndTransferFunction: an ICC-based RGB space");
    if (icc) CFRelease(icc);
    CGColorSpaceRelease(cs);
    vImageWhitePoint d65 = { 0.3127f, 0.3290f };
    cs = vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction(&d65, &tf, kCGRenderingIntentDefault, 0, &e);
    CHECK(cs && CGColorSpaceGetModel(cs) == kCGColorSpaceModelMonochrome, "vImageCreateMonochromeColorSpaceWithWhitePointAndTransferFunction");
    CGColorSpaceRelease(cs);
}

static int user_freed;
static void free_user(vImageCVImageFormatRef f, void *u) { user_freed = *(int *)u; }
static void core_video(void) {
    /* a BGRA pixel buffer, read as ARGB8888 with an empty format */
    CVPixelBufferRef pb = NULL;
    CHECK(CVPixelBufferCreate(NULL, 4, 2, kCVPixelFormatType_32BGRA, NULL, &pb) == 0 && pb, "a 4x2 BGRA pixel buffer");
    CVPixelBufferLockBaseAddress(pb, 0);
    uint8_t *base = CVPixelBufferGetBaseAddress(pb);
    for (int y = 0; y < 2; y++) for (int x = 0; x < 4; x++) { uint8_t *p = base + y * CVPixelBufferGetBytesPerRow(pb) + x * 4; p[0] = 30; p[1] = 20; p[2] = 200; p[3] = 255; }
    CVPixelBufferUnlockBaseAddress(pb, 0);
    vImageCVImageFormatRef f = vImageCVImageFormat_CreateWithCVPixelBuffer(pb);
    CHECK(f && vImageCVImageFormat_GetFormatCode(f) == kCVPixelFormatType_32BGRA && vImageCVImageFormat_GetChannelCount(f) == 4
          && vImageCVImageFormat_GetChannelNames(f)[0] == kvImageBufferTypeCode_RGB_Red && vImageCVImageFormat_GetChannelNames(f)[3] == kvImageBufferTypeCode_Alpha,
          "vImageCVImageFormat_CreateWithCVPixelBuffer: BGRA has red, green, blue and alpha");
    vImage_Buffer out; vImage_CGImageFormat fmt = { 0 };
    CHECK(vImageBuffer_InitWithCVPixelBuffer(&out, &fmt, pb, f, NULL, 0) == 0 && fmt.bitsPerPixel == 32 && out.width == 4 && out.height == 2,
          "vImageBuffer_InitWithCVPixelBuffer with an empty format: ARGB8888");
    uint8_t *o = (uint8_t *)out.data + out.rowBytes + 12;
    CHECK(o[0] == 255 && o[1] == 200 && o[2] == 20 && o[3] == 30, "the BGRA pixels as ARGB");
    /* write ARGB back into the pixel buffer */
    for (int i = 0; i < 8; i++) { uint8_t *p = (uint8_t *)out.data + (i / 4) * out.rowBytes + (i % 4) * 4; p[1] = 5; p[2] = 250; p[3] = 9; }
    CHECK(vImageBuffer_CopyToCVPixelBuffer(&out, &fmt, pb, f, NULL, 0) == 0, "vImageBuffer_CopyToCVPixelBuffer");
    CVPixelBufferLockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    base = CVPixelBufferGetBaseAddress(pb);
    CHECK(base[0] == 9 && base[1] == 250 && base[2] == 5, "the pixel buffer holds the new colour in BGRA order");
    CVPixelBufferUnlockBaseAddress(pb, kCVPixelBufferLock_ReadOnly);
    free(out.data);
    vImageCVImageFormat_Release(f);
    CVPixelBufferRelease(pb);

    /* 4:2:0 video range: the planes, the converter's buffer order, and colours both ways */
    CVPixelBufferRef yuv = NULL;
    CHECK(CVPixelBufferCreate(NULL, 4, 2, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange, NULL, &yuv) == 0, "a 4x2 420v pixel buffer");
    CVPixelBufferLockBaseAddress(yuv, 0);
    memset(CVPixelBufferGetBaseAddressOfPlane(yuv, 0), 235, CVPixelBufferGetBytesPerRowOfPlane(yuv, 0) * 2);
    memset(CVPixelBufferGetBaseAddressOfPlane(yuv, 1), 128, CVPixelBufferGetBytesPerRowOfPlane(yuv, 1));
    CVPixelBufferUnlockBaseAddress(yuv, 0);
    f = vImageCVImageFormat_CreateWithCVPixelBuffer(yuv);
    vImageMatrixType mt;
    const vImage_ARGBToYpCbCrMatrix *m = vImageCVImageFormat_GetConversionMatrix(f, &mt);
    CHECK(f && mt == kvImageMatrixType_ARGBToYpCbCrMatrix && m && fabsf(m->R_Yp - 0.299f) < 1e-4f, "a 420v format gets the BT.601 matrix by default");
    const vImageChannelDescription *ld = vImageCVImageFormat_GetChannelDescription(f, kvImageBufferTypeCode_Luminance);
    CHECK(ld && ld->zero == 16 && ld->full == 235, "the luminance channel of a video-range format: 16...235");
    vImage_CGImageFormat argb = { 8, 32, NULL, (CGBitmapInfo)kCGImageAlphaFirst, 0, NULL, kCGRenderingIntentDefault };
    vImage_Error e;
    vImageConverterRef cv2cg = vImageConverter_CreateForCVToCGImageFormat(f, &argb, NULL, 0, &e);
    CHECK(cv2cg && e == 0 && vImageConverter_GetNumberOfSourceBuffers(cv2cg) == 2 && vImageConverter_GetSourceBufferOrder(cv2cg)[0] == kvImageBufferTypeCode_Luminance
          && vImageConverter_GetSourceBufferOrder(cv2cg)[1] == kvImageBufferTypeCode_Chroma && vImageConverter_GetNumberOfDestinationBuffers(cv2cg) == 1,
          "vImageConverter_CreateForCVToCGImageFormat: luminance and chroma planes in");
    vImage_Buffer planes[2];
    CVPixelBufferLockBaseAddress(yuv, kCVPixelBufferLock_ReadOnly);
    CHECK(vImageBuffer_InitForCopyFromCVPixelBuffer(planes, cv2cg, yuv, kvImageNoAllocate) == 0 && planes[0].data == CVPixelBufferGetBaseAddressOfPlane(yuv, 0)
          && planes[1].width == 2 && planes[1].height == 1, "vImageBuffer_InitForCopyFromCVPixelBuffer points at the planes");
    uint8_t px[32]; vImage_Buffer d = buf(px, 4, 2, 4);
    CHECK(vImageConvert_AnyToAny(cv2cg, planes, &d, NULL, 0) == 0 && px[1] == 255 && px[2] == 255 && px[3] == 255, "AnyToAny: Y' 235 is white");
    CVPixelBufferUnlockBaseAddress(yuv, kCVPixelBufferLock_ReadOnly);
    vImageConverter_Release(cv2cg);
    for (int i = 0; i < 8; i++) { px[i * 4] = 255; px[i * 4 + 1] = 0; px[i * 4 + 2] = 0; px[i * 4 + 3] = 255; }
    CHECK(vImageBuffer_CopyToCVPixelBuffer(&d, &argb, yuv, f, NULL, 0) == 0, "vImageBuffer_CopyToCVPixelBuffer into 420v");
    CVPixelBufferLockBaseAddress(yuv, kCVPixelBufferLock_ReadOnly);
    uint8_t yv = *(uint8_t *)CVPixelBufferGetBaseAddressOfPlane(yuv, 0), *cbcr = CVPixelBufferGetBaseAddressOfPlane(yuv, 1);
    CHECK(abs(yv - 41) <= 1 && cbcr[0] >= 238 && abs(cbcr[1] - 110) <= 2, "blue in video range: Y' 41, Cb 240, Cr 110");
    CVPixelBufferUnlockBaseAddress(yuv, kCVPixelBufferLock_ReadOnly);
    /* the matrix from the buffer's attachment */
    CVBufferSetAttachment(yuv, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, kCVAttachmentMode_ShouldPropagate);
    vImageCVImageFormatRef f709 = vImageCVImageFormat_CreateWithCVPixelBuffer(yuv);
    m = vImageCVImageFormat_GetConversionMatrix(f709, NULL);
    CHECK(m && fabsf(m->R_Yp - 0.2126f) < 1e-4f, "the BT.709 matrix from kCVImageBufferYCbCrMatrixKey");
    vImageCVImageFormat_Release(f709);
    CVPixelBufferRelease(yuv);

    /* a format made by hand: v216 (16-bit 4:2:2), round trip through CVPixelBufferCreateWithBytes */
    vImageCVImageFormatRef v216 = vImageCVImageFormat_Create('v216', kvImage_ARGBToYpCbCrMatrix_ITU_R_709_2, NULL, NULL, 1);
    uint16_t raw[2 * 4]; CVPixelBufferRef pv = NULL;
    CHECK(v216 && CVPixelBufferCreateWithBytes(NULL, 2, 1, 'v216', raw, 16, NULL, NULL, NULL, &pv) == 0 && vImageCVImageFormat_GetAlphaHint(v216) == 1,
          "vImageCVImageFormat_Create for v216");
    uint16_t c16[8] = { 65535, 10000, 50000, 30000, 65535, 10000, 50000, 30000 }, back[8];
    vImage_CGImageFormat a16 = { 16, 64, NULL, (CGBitmapInfo)(kCGImageAlphaFirst | kCGBitmapByteOrder16Little), 0, NULL, kCGRenderingIntentDefault };
    vImage_Buffer s16 = buf(c16, 2, 1, 8), b16 = buf(back, 2, 1, 8);
    CHECK(vImageBuffer_CopyToCVPixelBuffer(&s16, &a16, pv, v216, NULL, 0) == 0 && raw[1] > 4096 && raw[1] < 60160, "ARGB16U into v216");
    CHECK(vImageBuffer_InitWithCVPixelBuffer(&b16, &a16, pv, v216, NULL, kvImageNoAllocate) == 0 && abs(back[1] - 10000) < 300 && abs(back[2] - 50000) < 300
          && abs(back[3] - 30000) < 300, "v216 back to ARGB16U");
    CVPixelBufferRelease(pv);
    /* setters and user data */
    static int token = 7;
    CGColorSpaceRef gray = CGColorSpaceCreateDeviceGray();
    CHECK(vImageCVImageFormat_SetAlphaHint(v216, 0) == 0 && vImageCVImageFormat_GetAlphaHint(v216) == 0 && vImageCVImageFormat_SetColorSpace(v216, gray) == 0
          && vImageCVImageFormat_GetColorSpace(v216) == gray && vImageCVImageFormat_SetUserData(v216, &token, free_user) == 0
          && vImageCVImageFormat_GetUserData(v216) == &token, "vImageCVImageFormat setters and user data");
    vImageChannelDescription narrow = { 0, 8192, 50000, 65535 };
    CHECK(vImageCVImageFormat_CopyChannelDescription(v216, &narrow, kvImageBufferTypeCode_Luminance) == 0
          && vImageCVImageFormat_GetChannelDescription(v216, kvImageBufferTypeCode_Luminance)->full == 50000, "vImageCVImageFormat_CopyChannelDescription");
    vImageCVImageFormatRef copy = vImageCVImageFormat_Copy(v216);
    CHECK(copy && vImageCVImageFormat_GetFormatCode(copy) == 'v216' && vImageCVImageFormat_GetChannelDescription(copy, kvImageBufferTypeCode_Luminance)->full == 50000,
          "vImageCVImageFormat_Copy");
    vImageCVImageFormat_Release(copy);
    vImageCVImageFormat_Release(v216);
    CHECK(user_freed == 7, "the user data's release callback runs");
    CGColorSpaceRelease(gray);
    vImageCVImageFormatRef none = vImageCVImageFormat_Create('2vuy', NULL, NULL, NULL, 0);
    CHECK(!vImageConverter_CreateForCVToCGImageFormat(none, &argb, NULL, 0, &e) && e == kvImageCVImageFormat_ConversionMatrix,
          "a Y'CbCr format without a matrix cannot convert");
    vImageCVImageFormat_Release(none);
}

int main(void) {
    buffers(); conversions(); ycbcr(); geometry(); filters(); core_graphics(); ycbcr_deep(); packed10(); more_filters(); core_video();
    printf("vImage C: %d/%d passed\n", checks - failures, checks);
    return failures ? 1 : 0;
}
