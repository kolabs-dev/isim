// vImage from C (VImageCTest.app, issue #371): buffers, conversions, geometry, convolution, morphology, histograms,
// alpha compositing, colour matrices, lookup tables, Y'CbCr and Core Graphics interoperation, checked against values
// worked out by hand.
#include <Accelerate/Accelerate.h>
#include <CoreGraphics/CoreGraphics.h>
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

int main(void) {
    buffers(); conversions(); ycbcr(); geometry(); filters(); core_graphics();
    printf("vImage C: %d/%d passed\n", checks - failures, checks);
    return failures ? 1 : 0;
}
