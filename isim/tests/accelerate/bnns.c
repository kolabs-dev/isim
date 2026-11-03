// BNNS from C (issue #808): descriptors and data types, the layer filters with their batch and backward applies, the
// direct functions, the optimizers, the random generator and nearest neighbors.
#include <Accelerate/Accelerate.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#define CHECK(cond, what) do { (*checks)++; if (cond) printf("PASS  %s\n", what); else { (*failures)++; printf("FAIL  %s  (line %d)\n", what, __LINE__); } } while (0)
#define CLOSE(a, b) (fabsf((float)(a) - (float)(b)) < 1e-4f * (1 + fabsf((float)(b))))

static BNNSNDArrayDescriptor vec(void *data, size_t n, BNNSDataType t) {
    BNNSNDArrayDescriptor d; memset(&d, 0, sizeof d);
    d.layout = BNNSDataLayoutVector; d.size[0] = n; d.data = data; d.data_type = t;
    return d;
}
static BNNSNDArrayDescriptor desc2(void *data, BNNSDataLayout l, size_t s0, size_t s1) {
    BNNSNDArrayDescriptor d; memset(&d, 0, sizeof d);
    d.layout = l; d.size[0] = s0; d.size[1] = s1; d.data = data; d.data_type = BNNSDataTypeFloat32;
    return d;
}
static BNNSNDArrayDescriptor chw(void *data, size_t w, size_t h, size_t c) {
    BNNSNDArrayDescriptor d; memset(&d, 0, sizeof d);
    d.layout = BNNSDataLayoutImageCHW; d.size[0] = w; d.size[1] = h; d.size[2] = c; d.data = data; d.data_type = BNNSDataTypeFloat32;
    return d;
}
static int allclose(const float *a, const float *b, size_t n) {
    for (size_t i = 0; i < n; i++) if (!CLOSE(a[i], b[i])) { printf("      [%zu] %g != %g\n", i, a[i], b[i]); return 0; }
    return 1;
}

static void types_and_layouts(int *checks, int *failures) {
    CHECK(BNNSDataTypeFloat32 == 0x10020 && BNNSDataTypeFloat16 == 0x10010 && BNNSDataTypeBFloat16 == 0x18010 &&
          BNNSDataTypeInt8 == 0x20008 && BNNSDataTypeUInt8 == 0x40008 && BNNSDataTypeIndexed8 == 0x80008 &&
          BNNSDataTypeBoolean == 0x100008, "bnns: data type values are Apple's");
    CHECK(BNNSDataLayoutVector == 0x10000 && BNNSDataLayoutRowMajorMatrix == 0x20000 && BNNSDataLayoutImageCHW == 0x30000 &&
          BNNSDataLayout4DFirstMajor == 0x48001 && BNNSActivationFunctionGELU == 34, "bnns: layout and activation values are Apple's");
    CHECK(sizeof(BNNSNDArrayDescriptor) == 176 && sizeof(BNNSActivation) == 48 && sizeof(BNNSFilterParameters) == 32 &&
          sizeof(BNNSTensor) == 160, "bnns: structure sizes match Apple's");
    CHECK(BNNSDataLayoutGetRank(BNNSDataLayout3DLastMajor) == 3 && BNNSDataLayoutGetRank(BNNSDataLayoutVector) == 1 &&
          BNNSDataLayoutGetRank((BNNSDataLayout)0x12345) == SIZE_MAX, "BNNSDataLayoutGetRank");
    float buf[12];
    BNNSNDArrayDescriptor m = desc2(buf, BNNSDataLayoutRowMajorMatrix, 4, 3);
    CHECK(BNNSNDArrayGetDataSize(&m) == 48, "BNNSNDArrayGetDataSize: dense matrix");
    m.stride[0] = 1; m.stride[1] = 8;
    CHECK(BNNSNDArrayGetDataSize(&m) == (2 * 8 + 4) * 4, "BNNSNDArrayGetDataSize: row stride");
    BNNSTensor t; memset(&t, 0, sizeof t);
    t.data_type = BNNSDataTypeFloat16; t.rank = 2; t.shape[0] = 3; t.shape[1] = 5; t.stride[0] = 5; t.stride[1] = 1;
    CHECK(BNNSTensorGetAllocationSize(&t) == 30, "BNNSTensorGetAllocationSize");
    t.shape[0] = -1;
    CHECK(BNNSTensorGetAllocationSize(&t) == SIZE_MAX, "BNNSTensorGetAllocationSize: dynamic shape");

    /* conversions through BNNSCopy */
    float src[5] = {1.5f, -2.25f, 1000.0f, 0.1f, -0.0f};
    uint16_t h[5]; float back[5];
    BNNSNDArrayDescriptor s = vec(src, 5, BNNSDataTypeFloat32), hd = vec(h, 5, BNNSDataTypeFloat16), bd = vec(back, 5, BNNSDataTypeFloat32);
    CHECK(BNNSCopy(&hd, &s, NULL) == 0 && h[0] == 0x3e00 && h[1] == 0xc080 && h[2] == 0x63d0, "BNNSCopy: Float32 to Float16");
    BNNSCopy(&bd, &hd, NULL);
    CHECK(back[0] == 1.5f && back[1] == -2.25f && back[2] == 1000.0f && fabsf(back[3] - 0.1f) < 1e-4f, "BNNSCopy: Float16 to Float32");
    uint16_t bf[5]; BNNSNDArrayDescriptor bfd = vec(bf, 5, BNNSDataTypeBFloat16);
    BNNSCopy(&bfd, &s, NULL); BNNSCopy(&bd, &bfd, NULL);
    CHECK(bf[0] == 0x3fc0 && back[2] == 1000.0f, "BNNSCopy: BFloat16");
    int8_t q[5]; BNNSNDArrayDescriptor qd = vec(q, 5, BNNSDataTypeInt8);
    qd.data_scale = 0.5f; qd.data_bias = 1.0f;
    BNNSCopy(&qd, &s, NULL);
    CHECK(q[0] == 1 && q[1] == -6 && q[2] == 127, "BNNSCopy: Int8 with scale, bias and saturation");
    BNNSCopy(&bd, &qd, NULL);
    CHECK(back[0] == 1.5f && back[1] == -2.0f && back[2] == 64.5f, "BNNSCopy: Int8 back to float uses scale and bias");
    uint8_t packed[2] = {0x21, 0x43};   /* UInt4: 1, 2, 3, 4 */
    BNNSNDArrayDescriptor u4 = vec(packed, 4, BNNSDataTypeUInt4), b4 = vec(back, 4, BNNSDataTypeFloat32);
    BNNSCopy(&b4, &u4, NULL);
    CHECK(back[0] == 1 && back[1] == 2 && back[2] == 3 && back[3] == 4, "BNNSCopy: UInt4 unpacks two per byte");
    uint8_t idx[3] = {2, 0, 1}; float table[3] = {10, 20, 30};
    BNNSNDArrayDescriptor ix = vec(idx, 3, BNNSDataTypeIndexed8);
    ix.table_data = table; ix.table_data_type = BNNSDataTypeFloat32;
    BNNSNDArrayDescriptor b3 = vec(back, 3, BNNSDataTypeFloat32);
    CHECK(BNNSCopy(&bd, &ix, NULL) != 0, "BNNSCopy: mismatched sizes fail");
    BNNSCopy(&b3, &ix, NULL);
    CHECK(back[0] == 30 && back[1] == 10 && back[2] == 20, "BNNSCopy: Indexed8 looks up the table");
    int64_t big[2] = {9007199254740993ll, -5}, bigo[2];
    BNNSNDArrayDescriptor b1 = vec(big, 2, BNNSDataTypeInt64), b2 = vec(bigo, 2, BNNSDataTypeInt64);
    CHECK(BNNSCopy(&b2, &b1, NULL) == 0 && bigo[0] == big[0] && bigo[1] == -5, "BNNSCopy: Int64 is exact");
}

static void direct_functions(int *checks, int *failures) {
    /* matrix product with a broadcast batch: A 2x(2x3), B 3x2 */
    float A[12] = {1, 2, 3, 4, 5, 6, 1, 0, 0, 0, 1, 0}, B[6] = {1, 2, 3, 4, 5, 6}, C[8];
    BNNSNDArrayDescriptor ad, bd, cd; memset(&ad, 0, sizeof ad); memset(&bd, 0, sizeof bd); memset(&cd, 0, sizeof cd);
    ad.layout = BNNSDataLayout3DFirstMajor; ad.size[0] = 2; ad.size[1] = 2; ad.size[2] = 3; ad.data = A; ad.data_type = BNNSDataTypeFloat32;
    bd.layout = BNNSDataLayout2DFirstMajor; bd.size[0] = 3; bd.size[1] = 2; bd.data = B; bd.data_type = BNNSDataTypeFloat32;
    cd.layout = BNNSDataLayout3DFirstMajor; cd.size[0] = 2; cd.size[1] = 2; cd.size[2] = 2; cd.data = C; cd.data_type = BNNSDataTypeFloat32;
    float wantC[8] = {22, 28, 49, 64, 1, 2, 3, 4};
    CHECK(BNNSMatMulWorkspaceSize(false, false, 1, &ad, &bd, &cd, NULL) >= 0 && BNNSMatMul(false, false, 1, &ad, &bd, &cd, NULL, NULL) == 0 &&
          allclose(C, wantC, 8), "BNNSMatMul: first-major batch with B broadcast");
    float At[6] = {1, 4, 2, 5, 3, 6}, C2[4];
    BNNSNDArrayDescriptor atd = bd; atd.data = At; atd.size[0] = 3; atd.size[1] = 2;
    BNNSNDArrayDescriptor c2 = bd; c2.data = C2; c2.size[0] = 2; c2.size[1] = 2;
    BNNSDirectApplyBroadcastMatMul(true, false, 0.5f, &atd, &bd, &c2, NULL);
    float wantC2[4] = {11, 14, 24.5f, 32};
    CHECK(allclose(C2, wantC2, 4), "BNNSDirectApplyBroadcastMatMul: transposed A, alpha");

    /* transpose, tile, compare */
    float m[6] = {1, 2, 3, 4, 5, 6}, mt[6];
    BNNSNDArrayDescriptor md = desc2(m, BNNSDataLayout2DLastMajor, 3, 2), mtd = desc2(mt, BNNSDataLayout2DLastMajor, 2, 3);
    float wantT[6] = {1, 4, 2, 5, 3, 6};
    CHECK(BNNSTranspose(&mtd, &md, 0, 1, NULL) == 0 && allclose(mt, wantT, 6), "BNNSTranspose");
    float tile[12]; BNNSNDArrayDescriptor td = desc2(tile, BNNSDataLayout2DLastMajor, 6, 2);
    float wantTile[12] = {1, 2, 3, 1, 2, 3, 4, 5, 6, 4, 5, 6};
    CHECK(BNNSTile(&md, &td, NULL) == 0 && allclose(tile, wantTile, 12), "BNNSTile");
    float back[6] = {0}; BNNSNDArrayDescriptor bk = md; bk.data = back;
    float wantBack[6] = {2, 4, 6, 8, 10, 12};
    CHECK(BNNSTileBackward(&bk, &td, NULL) == 0 && allclose(back, wantBack, 6), "BNNSTileBackward sums the tiles");
    float x0[4] = {1, 2, 3, 4}, x1[4] = {4, 2, 1, 4}; uint8_t cmp[4];
    BNNSNDArrayDescriptor c0 = vec(x0, 4, BNNSDataTypeFloat32), c1 = vec(x1, 4, BNNSDataTypeFloat32), co = vec(cmp, 4, BNNSDataTypeBoolean);
    CHECK(BNNSCompareTensor(&c0, &c1, BNNSRelationalOperatorLess, &co) == 0 && cmp[0] == 1 && cmp[1] == 0 && cmp[2] == 0 && cmp[3] == 0,
          "BNNSCompareTensor: less");
    BNNSCompareTensor(&c0, &c1, BNNSRelationalOperatorGreaterEqual, &co);
    CHECK(cmp[0] == 0 && cmp[1] == 1 && cmp[2] == 1 && cmp[3] == 1, "BNNSCompareTensor: greater or equal");

    /* reductions */
    float r3[24], rout[8];
    for (int i = 0; i < 24; i++) r3[i] = (float)(i + 1);
    BNNSLayerParametersReduction rp; memset(&rp, 0, sizeof rp);
    rp.i_desc.layout = BNNSDataLayout3DLastMajor; rp.i_desc.size[0] = 4; rp.i_desc.size[1] = 2; rp.i_desc.size[2] = 3;
    rp.i_desc.data = r3; rp.i_desc.data_type = BNNSDataTypeFloat32;
    rp.o_desc = rp.i_desc; rp.o_desc.size[0] = 1; rp.o_desc.data = rout;
    rp.reduce_func = BNNSReduceFunctionSum;
    float wantSum[6] = {10, 26, 42, 58, 74, 90};
    CHECK(BNNSDirectApplyReduction(&rp, NULL) == 0 && allclose(rout, wantSum, 6), "BNNSDirectApplyReduction: sum over dimension 0");
    rp.reduce_func = BNNSReduceFunctionArgMax; rp.o_desc.size[0] = 4; rp.o_desc.size[2] = 1;
    float wantArg[8] = {2, 2, 2, 2, 2, 2, 2, 2};
    CHECK(BNNSDirectApplyReduction(&rp, NULL) == 0 && allclose(rout, wantArg, 8), "BNNSDirectApplyReduction: argmax");
    rp.reduce_func = BNNSReduceFunctionMean; rp.o_desc.size[0] = 1; rp.o_desc.size[1] = 1; rp.o_desc.size[2] = 1;
    CHECK(BNNSDirectApplyReduction(&rp, NULL) == 0 && CLOSE(rout[0], 12.5f), "BNNSDirectApplyReduction: mean of everything");

    /* gather and scatter */
    float gin[6] = {1, 2, 3, 4, 5, 6}, gout[4], gidx[2] = {2, 0};
    BNNSNDArrayDescriptor gi = desc2(gin, BNNSDataLayout2DLastMajor, 3, 2), go = desc2(gout, BNNSDataLayout2DLastMajor, 2, 2);
    BNNSNDArrayDescriptor gx = vec(gidx, 2, BNNSDataTypeFloat32);
    float wantG[4] = {3, 1, 6, 4};
    CHECK(BNNSGather(0, &gi, &gx, &go, NULL) == 0 && allclose(gout, wantG, 4), "BNNSGather along dimension 0");
    float sout[6] = {0}; BNNSNDArrayDescriptor so = gi; so.data = sout;
    float wantS[6] = {1, 0, 3, 4, 0, 6};
    int32_t sidx[2] = {2, 0}; BNNSNDArrayDescriptor sx = vec(sidx, 2, BNNSDataTypeInt32);
    CHECK(BNNSScatter(0, BNNSReduceFunctionSum, &go, &sx, &so, NULL) == 0 && allclose(sout, wantS, 6), "BNNSScatter with sum");
    int32_t nd[4] = {1, 0, 2, 1}; float ndo[2];
    BNNSNDArrayDescriptor ndx = desc2(nd, BNNSDataLayout2DLastMajor, 2, 2); ndx.data_type = BNNSDataTypeInt32;
    BNNSNDArrayDescriptor ndd = vec(ndo, 2, BNNSDataTypeFloat32);
    CHECK(BNNSGatherND(&gi, &ndx, &ndd, NULL) == 0 && ndo[0] == 2 && ndo[1] == 6, "BNNSGatherND picks elements");

    /* top-k */
    float tk[6] = {3, 9, 1, 7, 7, 2}, best[2]; int32_t bidx[2];
    BNNSNDArrayDescriptor tki = vec(tk, 6, BNNSDataTypeFloat32), tkv = vec(best, 2, BNNSDataTypeFloat32), tkx = vec(bidx, 2, BNNSDataTypeInt32);
    CHECK(BNNSDirectApplyTopK(2, 0, 1, &tki, 6, &tkv, 2, &tkx, 2, NULL) == 0 && best[0] == 9 && best[1] == 7 && bidx[0] == 1 && bidx[1] == 3,
          "BNNSDirectApplyTopK: values and the first of tied indices");
    int32_t ti[1] = {4}; uint8_t in1[1];
    BNNSNDArrayDescriptor tti = vec(ti, 1, BNNSDataTypeInt32), tto = vec(in1, 1, BNNSDataTypeBoolean);
    CHECK(BNNSDirectApplyInTopK(2, 0, 1, &tki, 6, &tti, 1, &tto, 1, NULL) == 0 && in1[0] == 1, "BNNSDirectApplyInTopK counts ties");

    /* band part, clipping, norms */
    float bp[9] = {1, 1, 1, 1, 1, 1, 1, 1, 1}, bpo[9];
    BNNSNDArrayDescriptor bpi = desc2(bp, BNNSDataLayout2DLastMajor, 3, 3), bpd = bpi; bpd.data = bpo;
    float wantBP[9] = {1, 0, 0, 1, 1, 0, 0, 1, 1};
    CHECK(BNNSBandPart(1, 0, &bpi, &bpd, NULL) == 0 && allclose(bpo, wantBP, 9), "BNNSBandPart: one subdiagonal, no superdiagonal");
    float cv[3] = {-3, 0.5f, 4}, cvo[3];
    BNNSNDArrayDescriptor cvi = vec(cv, 3, BNNSDataTypeFloat32), cvd = vec(cvo, 3, BNNSDataTypeFloat32);
    CHECK(BNNSClipByValue(&cvd, &cvi, -1, 1) == 0 && cvo[0] == -1 && cvo[1] == 0.5f && cvo[2] == 1, "BNNSClipByValue");
    float n34[2] = {3, 4}, n34o[2], nrm[1];
    BNNSNDArrayDescriptor ni = vec(n34, 2, BNNSDataTypeFloat32), no = vec(n34o, 2, BNNSDataTypeFloat32), nn = vec(nrm, 1, BNNSDataTypeFloat32);
    CHECK(BNNSClipByNorm(&no, &ni, 1, 0) == 0 && CLOSE(n34o[0], 0.6f) && CLOSE(n34o[1], 0.8f), "BNNSClipByNorm");
    CHECK(BNNSComputeNorm(&nn, &ni, BNNSL2Norm, 0) == 0 && CLOSE(nrm[0], 5), "BNNSComputeNorm");
    BNNSNDArrayDescriptor *dl[1] = {&no}; const BNNSNDArrayDescriptor *sl[1] = {&ni};
    CHECK(BNNSClipByGlobalNorm(dl, sl, 1, 2.5f, 0) == 0 && CLOSE(n34o[0], 1.5f), "BNNSClipByGlobalNorm");

    /* depth to space / pixel shuffle on a 1x1x4 image */
    float ps[4] = {1, 2, 3, 4}, pso[4];
    BNNSNDArrayDescriptor psi = chw(ps, 1, 1, 4), psd = chw(pso, 2, 2, 1);
    float wantPS[4] = {1, 2, 3, 4};
    CHECK(BNNSShuffle(BNNSShuffleTypePixelShuffleNCHW, &psi, &psd, NULL) == 0 && allclose(pso, wantPS, 4), "BNNSShuffle: pixel shuffle");
    float back4[4]; BNNSNDArrayDescriptor psb = psi; psb.data = back4;
    CHECK(BNNSShuffle(BNNSShuffleTypePixelUnshuffleNCHW, &psd, &psb, NULL) == 0 && allclose(back4, ps, 4), "BNNSShuffle: unshuffle undoes it");

    /* crop and resize: the whole 2x2 image to 3x3, bilinear */
    float img[4] = {0, 1, 2, 3}, crop[9], roi[4] = {0, 0, 1, 1};
    BNNSLayerParametersCropResize cr; memset(&cr, 0, sizeof cr);
    cr.normalized_coordinates = true; cr.method = BNNSInterpolationMethodLinear;
    BNNSNDArrayDescriptor imd = chw(img, 2, 2, 1), crd = chw(crop, 3, 3, 1), roid = desc2(roi, BNNSDataLayout2DLastMajor, 4, 1);
    float wantCrop[9] = {0, 0.5f, 1, 1, 1.5f, 2, 2, 2.5f, 3};
    CHECK(BNNSCropResize(&cr, &imd, &roid, &crd, NULL) == 0 && allclose(crop, wantCrop, 9), "BNNSCropResize: bilinear");

    /* quantizer */
    float qf[3] = {0.5f, 1.0f, -1.0f}; int8_t qo[3];
    BNNSLayerParametersQuantization qp; memset(&qp, 0, sizeof qp);
    float scale = 10, bias = 1;
    qp.function = BNNSQuantizerFunctionQuantize; qp.i_desc = vec(qf, 3, BNNSDataTypeFloat32); qp.o_desc = vec(qo, 3, BNNSDataTypeInt8);
    qp.scale = vec(&scale, 1, BNNSDataTypeFloat32); qp.bias = vec(&bias, 1, BNNSDataTypeFloat32);
    CHECK(BNNSDirectApplyQuantizer(&qp, NULL, 1, 3, 3) == 0 && qo[0] == 6 && qo[1] == 11 && qo[2] == -9, "BNNSDirectApplyQuantizer: y = scale*x + bias");
}

static void layers(int *checks, int *failures) {
    /* fully connected 3 -> 2 with bias and ReLU, batch of 2 */
    float W[6] = {1, 0, -1, 2, 1, 0}, b[2] = {5, -1}, x[6] = {1, 2, 3, -1, 0, 1}, y[4];
    BNNSLayerParametersFullyConnected fc; memset(&fc, 0, sizeof fc);
    fc.i_desc = vec(NULL, 3, BNNSDataTypeFloat32); fc.o_desc = vec(NULL, 2, BNNSDataTypeFloat32);
    fc.w_desc = desc2(W, BNNSDataLayoutRowMajorMatrix, 3, 2); fc.bias = vec(b, 2, BNNSDataTypeFloat32);
    fc.activation.function = BNNSActivationFunctionRectifiedLinear;
    BNNSFilter f = BNNSFilterCreateLayerFullyConnected(&fc, NULL);
    W[0] = 99;   /* the filter keeps its own copy */
    float wantFC[4] = {3, 3, 3, 0};   /* rows [1, 0, -1] and [2, 1, 0], bias (5, -1), ReLU */
    CHECK(f && BNNSFilterApplyBatch(f, 2, x, 3, y, 2) == 0 && allclose(y, wantFC, 4), "fully connected layer: batch, bias, ReLU, copied weights");
    BNNSNDArrayDescriptor wp = BNNSGetPointer(f, BNNSPointerSpecifierAlpha);
    CHECK(wp.data && ((float *)wp.data)[0] == 1 && wp.data != W, "BNNSGetPointer: the filter's weights");
    /* linear layer backward against finite differences */
    W[0] = 1;
    fc.activation.function = BNNSActivationFunctionIdentity;
    BNNSFilter lin = BNNSFilterCreateLayerFullyConnected(&fc, NULL);
    float dy[2] = {1, 2}, dx[3], dW[6], db[2];
    BNNSNDArrayDescriptor dyd = vec(dy, 2, BNNSDataTypeFloat32), dxd = vec(dx, 3, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor dWd = desc2(dW, BNNSDataLayoutRowMajorMatrix, 3, 2), dbd = vec(db, 2, BNNSDataTypeFloat32);
    float yo[2]; BNNSFilterApply(lin, x, yo);
    float wantdx[3] = {1 * 1 + 2 * 2, 0 + 2 * 1, -1 + 0}, wantdW[6] = {1, 2, 3, 2, 4, 6};
    CHECK(BNNSFilterApplyBackwardBatch(lin, 1, x, 3, &dxd, 3, yo, 2, &dyd, 2, &dWd, &dbd) == 0 && allclose(dx, wantdx, 3) &&
          allclose(dW, wantdW, 6) && db[0] == 1 && db[1] == 2, "fully connected backward: input, weight and bias gradients");
    BNNSFilterDestroy(f); BNNSFilterDestroy(lin);

    /* convolution: 3x3 input, 2x2 kernel, one channel, stride 1, padding 0 */
    float img[9] = {1, 2, 3, 4, 5, 6, 7, 8, 9}, k[4] = {1, 0, 0, -1}, co[4], cb = 1;
    BNNSLayerParametersConvolution cp; memset(&cp, 0, sizeof cp);
    cp.i_desc = chw(NULL, 3, 3, 1); cp.o_desc = chw(NULL, 2, 2, 1);
    cp.w_desc.layout = BNNSDataLayoutConvolutionWeightsOIHW; cp.w_desc.size[0] = 2; cp.w_desc.size[1] = 2; cp.w_desc.size[2] = 1; cp.w_desc.size[3] = 1;
    cp.w_desc.data = k; cp.w_desc.data_type = BNNSDataTypeFloat32;
    cp.bias = vec(&cb, 1, BNNSDataTypeFloat32);
    BNNSFilter cf = BNNSFilterCreateLayerConvolution(&cp, NULL);
    float wantConv[4] = {-3, -3, -3, -3};
    CHECK(cf && BNNSFilterApply(cf, img, co) == 0 && allclose(co, wantConv, 4), "convolution layer");
    float cdy[4] = {1, 1, 1, 1}, cdx[9], cdw[4], cdb[1];
    BNNSNDArrayDescriptor cdyd = chw(cdy, 2, 2, 1), cdxd = chw(cdx, 3, 3, 1), cdwd = cp.w_desc, cdbd = vec(cdb, 1, BNNSDataTypeFloat32);
    cdwd.data = cdw;
    float wantcdx[9] = {1, 1, 0, 1, 0, -1, 0, -1, -1}, wantcdw[4] = {12, 16, 24, 28};
    CHECK(BNNSFilterApplyBackwardBatch(cf, 1, img, 9, &cdxd, 9, co, 4, &cdyd, 4, &cdwd, &cdbd) == 0 && allclose(cdx, wantcdx, 9) &&
          allclose(cdw, wantcdw, 4) && cdb[0] == 4, "convolution backward");
    BNNSFilterDestroy(cf);
    /* rotated weights give the flipped kernel */
    cp.w_desc.layout = BNNSDataLayoutConvolutionWeightsOIHrWr;
    cf = BNNSFilterCreateLayerConvolution(&cp, NULL);
    float wantRot[4] = {5, 5, 5, 5};
    CHECK(cf && BNNSFilterApply(cf, img, co) == 0 && allclose(co, wantRot, 4), "convolution with OIHrWr weights");
    BNNSFilterDestroy(cf);
    /* transposed convolution: the adjoint of the convolution */
    cp.w_desc.layout = BNNSDataLayoutConvolutionWeightsOIHW;
    cp.i_desc = chw(NULL, 2, 2, 1); cp.o_desc = chw(NULL, 3, 3, 1); cp.bias.data = NULL;
    BNNSFilter tf = BNNSFilterCreateLayerTransposedConvolution(&cp, NULL);
    float tin[4] = {1, 1, 1, 1}, tout[9];
    CHECK(tf && BNNSFilterApply(tf, tin, tout) == 0 && allclose(tout, wantcdx, 9), "transposed convolution");
    BNNSFilterDestroy(tf);
    /* the older creator */
    BNNSImageStackDescriptor is = {3, 3, 1, 3, 9, BNNSDataTypeFloat32, 0, 0}, os = {2, 2, 1, 2, 4, BNNSDataTypeFloat32, 0, 0};
    BNNSConvolutionLayerParameters old; memset(&old, 0, sizeof old);
    old.k_width = 2; old.k_height = 2; old.in_channels = 1; old.out_channels = 1;
    old.weights.data = k; old.weights.data_type = BNNSDataTypeFloat32;
    old.bias.data = &cb; old.bias.data_type = BNNSDataTypeFloat32;
    BNNSFilter of = BNNSFilterCreateConvolutionLayer(&is, &os, &old, NULL);
    CHECK(of && BNNSFilterApply(of, img, co) == 0 && allclose(co, wantConv, 4), "BNNSFilterCreateConvolutionLayer");
    BNNSFilterDestroy(of);

    /* pooling */
    float pin[16]; for (int i = 0; i < 16; i++) pin[i] = (float)i;
    BNNSLayerParametersPooling pp; memset(&pp, 0, sizeof pp);
    pp.i_desc = chw(NULL, 4, 4, 1); pp.o_desc = chw(NULL, 2, 2, 1);
    pp.pooling_function = BNNSPoolingFunctionMax; pp.k_width = 2; pp.k_height = 2; pp.x_stride = 2; pp.y_stride = 2;
    BNNSFilter pf = BNNSFilterCreateLayerPooling(&pp, NULL);
    float pout[4]; size_t pidx[4];
    float wantMax[4] = {5, 7, 13, 15};
    CHECK(pf && BNNSPoolingFilterApplyBatch(pf, 1, pin, 16, pout, 4, pidx, 4) == 0 && allclose(pout, wantMax, 4) && pidx[0] == 5 && pidx[3] == 15,
          "max pooling with indices");
    float pdy[4] = {1, 2, 3, 4}, pdx[16];
    BNNSNDArrayDescriptor pdyd = chw(pdy, 2, 2, 1), pdxd = chw(pdx, 4, 4, 1);
    CHECK(BNNSPoolingFilterApplyBackwardBatch(pf, 1, pin, 16, &pdxd, 16, pout, 4, &pdyd, 4, NULL, pidx, 4) == 0 && pdx[5] == 1 &&
          pdx[15] == 4 && pdx[0] == 0, "max pooling backward routes to the maxima");
    BNNSFilterDestroy(pf);
    pp.pooling_function = BNNSPoolingFunctionAverageCountIncludePadding;
    pf = BNNSFilterCreateLayerPooling(&pp, NULL);
    float wantAvg[4] = {2.5f, 4.5f, 10.5f, 12.5f};
    CHECK(pf && BNNSFilterApply(pf, pin, pout) == 0 && allclose(pout, wantAvg, 4), "average pooling");
    BNNSFilterDestroy(pf);

    /* activation layer: softmax, and leaky ReLU with a trainable alpha */
    float av[3] = {1, 2, 3}, ao[3];
    BNNSLayerParametersActivation ap; memset(&ap, 0, sizeof ap);
    ap.i_desc = vec(NULL, 3, BNNSDataTypeFloat32); ap.o_desc = ap.i_desc; ap.activation.function = BNNSActivationFunctionSoftmax;
    BNNSFilter af = BNNSFilterCreateLayerActivation(&ap, NULL);
    double e1 = exp(1), e2 = exp(2), e3 = exp(3), es = e1 + e2 + e3;
    float wantSM[3] = {(float)(e1 / es), (float)(e2 / es), (float)(e3 / es)};
    CHECK(af && BNNSFilterApply(af, av, ao) == 0 && allclose(ao, wantSM, 3), "softmax activation layer");
    BNNSFilterDestroy(af);
    float lv[3] = {-2, 0.5f, 3};
    ap.activation.function = BNNSActivationFunctionLeakyRectifiedLinear; ap.activation.alpha = 0.1f;
    af = BNNSFilterCreateLayerActivation(&ap, NULL);
    BNNSNDArrayDescriptor alpha = BNNSGetPointer(af, BNNSPointerSpecifierAlpha);
    CHECK(af && alpha.data && *(float *)alpha.data == 0.1f, "BNNSGetPointer: leaky ReLU alpha");
    *(float *)alpha.data = 0.5f;
    float wantLeaky[3] = {-1, 0.5f, 3};
    CHECK(BNNSFilterApply(af, lv, ao) == 0 && allclose(ao, wantLeaky, 3), "leaky ReLU uses the updated alpha");
    float ldy[3] = {1, 1, 1}, ldx[3], lda[1];
    BNNSNDArrayDescriptor ldyd = vec(ldy, 3, BNNSDataTypeFloat32), ldxd = vec(ldx, 3, BNNSDataTypeFloat32), ldad = vec(lda, 1, BNNSDataTypeFloat32);
    float wantLdx[3] = {0.5f, 1, 1};
    CHECK(BNNSFilterApplyBackwardBatch(af, 1, lv, 3, &ldxd, 3, ao, 3, &ldyd, 3, &ldad, NULL) == 0 && allclose(ldx, wantLdx, 3) && lda[0] == -2,
          "leaky ReLU backward: input and alpha gradients");
    BNNSFilterDestroy(af);
    float gl[2] = {-1, 1}, glo[2];
    BNNSActivation ga; memset(&ga, 0, sizeof ga); ga.function = BNNSActivationFunctionGELU;
    BNNSVectorDescriptor v2 = {2, BNNSDataTypeFloat32, 0, 0};
    BNNSFilter gf = BNNSFilterCreateVectorActivationLayer(&v2, &v2, &ga, NULL);
    CHECK(gf && BNNSFilterApply(gf, gl, glo) == 0 && CLOSE(glo[0], -0.158655f) && CLOSE(glo[1], 0.841345f), "GELU (vector activation creator)");
    BNNSFilterDestroy(gf);

    /* batch normalization in training and inference */
    float bn_in[4] = {1, 3, 5, 7}, bn_out[4], mm[1] = {0}, mv[1] = {1}, gam[1] = {2}, bet[1] = {1};
    BNNSLayerParametersNormalization np; memset(&np, 0, sizeof np);
    np.i_desc = vec(NULL, 1, BNNSDataTypeFloat32); np.o_desc = np.i_desc;
    np.gamma_desc = vec(gam, 1, BNNSDataTypeFloat32); np.beta_desc = vec(bet, 1, BNNSDataTypeFloat32);
    np.moving_mean_desc = vec(mm, 1, BNNSDataTypeFloat32); np.moving_variance_desc = vec(mv, 1, BNNSDataTypeFloat32);
    np.momentum = 0.5f; np.epsilon = 0;
    BNNSFilter nf = BNNSFilterCreateLayerNormalization(BNNSBatchNorm, &np, NULL);
    float s5 = sqrtf(5);
    float wantBN[4] = {1 - 6 / s5, 1 - 2 / s5, 1 + 2 / s5, 1 + 6 / s5};
    CHECK(nf && BNNSNormalizationFilterApplyBatch(nf, 4, bn_in, 1, bn_out, 1, true) == 0 && allclose(bn_out, wantBN, 4) &&
          CLOSE(mm[0], 2) && CLOSE(mv[0], 3), "batch norm training: batch statistics, moving statistics updated");
    float bdy[4] = {1, 0, 0, 0}, bdx[4], dbeta[1], dgamma[1];
    BNNSNDArrayDescriptor bdyd = vec(bdy, 1, BNNSDataTypeFloat32), bdxd = vec(bdx, 1, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor dbd2 = vec(dbeta, 1, BNNSDataTypeFloat32), dgd = vec(dgamma, 1, BNNSDataTypeFloat32);
    CHECK(BNNSNormalizationFilterApplyBackwardBatch(nf, 4, &bdxd, 1, bn_out, 1, &bdyd, 1, &dbd2, &dgd) == 0 && dbeta[0] == 1 &&
          CLOSE(dgamma[0], -3 / s5) && CLOSE(bdx[0] + bdx[1] + bdx[2] + bdx[3], 0), "batch norm backward");
    CHECK(BNNSNormalizationFilterApplyBatch(nf, 1, bn_in, 1, bn_out, 1, false) == 0 && CLOSE(bn_out[0], 2 * (1 - 2) / sqrtf(3) + 1),
          "batch norm inference uses the moving statistics");
    BNNSFilterDestroy(nf);
    float ln_in[4] = {1, 2, 3, 4}, ln_out[4];
    memset(&np, 0, sizeof np);
    np.i_desc = vec(NULL, 4, BNNSDataTypeFloat32); np.o_desc = np.i_desc; np.epsilon = 0;
    nf = BNNSFilterCreateLayerNormalization(BNNSLayerNorm, &np, NULL);
    float sd = sqrtf(1.25f);
    float wantLN[4] = {-1.5f / sd, -0.5f / sd, 0.5f / sd, 1.5f / sd};
    CHECK(nf && BNNSFilterApply(nf, ln_in, ln_out) == 0 && allclose(ln_out, wantLN, 4), "layer norm");
    BNNSFilterDestroy(nf);

    /* arithmetic: a (sample) + b (constant, broadcast), then the backward */
    float a3[3] = {1, 2, 3}, cst[1] = {10}, ar[3];
    BNNSArithmeticBinary bin; memset(&bin, 0, sizeof bin);
    bin.in1 = vec(NULL, 3, BNNSDataTypeFloat32); bin.in1_type = BNNSSample;
    bin.in2 = vec(cst, 1, BNNSDataTypeFloat32); bin.in2_type = BNNSConstant;
    bin.out = vec(NULL, 3, BNNSDataTypeFloat32); bin.out_type = BNNSSample;
    BNNSLayerParametersArithmetic arp; memset(&arp, 0, sizeof arp);
    arp.arithmetic_function = BNNSArithmeticMultiply; arp.arithmetic_function_fields = &bin;
    BNNSFilter arf = BNNSFilterCreateLayerArithmetic(&arp, NULL);
    const void *ins[2] = {a3, cst}; size_t ist[2] = {3, 0};
    float wantAr[3] = {10, 20, 30};
    CHECK(arf && BNNSArithmeticFilterApplyBatch(arf, 1, 2, ins, ist, ar, 3) == 0 && allclose(ar, wantAr, 3), "arithmetic layer: multiply with a broadcast constant");
    float ady[3] = {1, 1, 1}, adx[3], adc[1];
    BNNSNDArrayDescriptor adyd = vec(ady, 3, BNNSDataTypeFloat32), adxd = vec(adx, 3, BNNSDataTypeFloat32), adcd = vec(adc, 1, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor *ads[2] = {&adxd, &adcd}; size_t adst[2] = {3, 0};
    CHECK(BNNSArithmeticFilterApplyBackwardBatch(arf, 1, 2, ins, ist, ads, adst, ar, 3, &adyd, 3) == 0 && adx[0] == 10 && adc[0] == 6,
          "arithmetic backward: sample and constant gradients");
    BNNSFilterDestroy(arf);

    /* tensor contraction and broadcast matrix product layers */
    float ta[6] = {1, 2, 3, 4, 5, 6}, tb[6] = {1, 0, 0, 1, 1, 1}, tc[4];
    BNNSLayerParametersTensorContraction tcp; memset(&tcp, 0, sizeof tcp);
    tcp.operation = "a_ij, b_jk -> c_ik"; tcp.alpha = 1;
    tcp.iA_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 2, 3); tcp.iB_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 3, 2);
    tcp.o_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 2, 2);
    BNNSFilter tcf = BNNSFilterCreateLayerTensorContraction(&tcp, NULL);
    /* A(i,j) = ta[i + 2j]: [[1,3,5],[2,4,6]]; B(j,k) = tb[j + 3k]: [[1,1],[0,1],[0,1]] */
    float wantTC[4] = {1, 2, 9, 12};
    CHECK(tcf && BNNSFilterApplyTwoInput(tcf, ta, tb, tc) == 0 && allclose(tc, wantTC, 4), "tensor contraction layer");
    BNNSFilterDestroy(tcf);
    BNNSLayerParametersBroadcastMatMul bmp; memset(&bmp, 0, sizeof bmp);
    bmp.alpha = 1; bmp.iA_desc = desc2(NULL, BNNSDataLayout2DFirstMajor, 2, 3); bmp.iB_desc = desc2(tb, BNNSDataLayout2DFirstMajor, 3, 2);
    bmp.o_desc = desc2(NULL, BNNSDataLayout2DFirstMajor, 2, 2); bmp.b_is_weights = true;
    BNNSFilter bmf = BNNSFilterCreateLayerBroadcastMatMul(&bmp, NULL);
    /* row-major: A = [[1,2,3],[4,5,6]], B = [[1,0],[0,1],[1,1]] */
    float wantBM[4] = {4, 5, 10, 11};
    CHECK(bmf && BNNSFilterApply(bmf, ta, tc) == 0 && allclose(tc, wantBM, 4), "broadcast matrix product layer with weights");
    BNNSFilterDestroy(bmf);

    /* permute, padding, resize, dropout, embedding, Gram, reduction */
    BNNSLayerParametersPermute prm; memset(&prm, 0, sizeof prm);
    prm.i_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 3, 2); prm.o_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 2, 3);
    prm.permutation[0] = 1; prm.permutation[1] = 0;
    BNNSFilter pmf = BNNSFilterCreateLayerPermute(&prm, NULL);
    float pmo[6]; float wantPM[6] = {1, 4, 2, 5, 3, 6};
    CHECK(pmf && BNNSFilterApply(pmf, ta, pmo) == 0 && allclose(pmo, wantPM, 6), "permute layer");
    BNNSFilterDestroy(pmf);
    BNNSLayerParametersPadding pdp; memset(&pdp, 0, sizeof pdp);
    pdp.i_desc = vec(NULL, 3, BNNSDataTypeFloat32); pdp.o_desc = vec(NULL, 6, BNNSDataTypeFloat32);
    pdp.padding_size[0][0] = 2; pdp.padding_size[0][1] = 1; pdp.padding_mode = BNNSPaddingModeReflect;
    BNNSFilter pdf = BNNSFilterCreateLayerPadding(&pdp, NULL);
    float pdo[6]; float wantPad[6] = {3, 2, 1, 2, 3, 2};
    CHECK(pdf && BNNSFilterApply(pdf, a3, pdo) == 0 && allclose(pdo, wantPad, 6), "padding layer: reflect");
    BNNSFilterDestroy(pdf);
    BNNSLayerParametersResize rsp; memset(&rsp, 0, sizeof rsp);
    rsp.method = BNNSInterpolationMethodLinear; rsp.align_corners = true;
    rsp.i_desc = vec(NULL, 3, BNNSDataTypeFloat32); rsp.o_desc = vec(NULL, 5, BNNSDataTypeFloat32);
    BNNSFilter rsf = BNNSFilterCreateLayerResize(&rsp, NULL);
    float rso[5]; float wantRs[5] = {1, 1.5f, 2, 2.5f, 3};
    CHECK(rsf && BNNSFilterApply(rsf, a3, rso) == 0 && allclose(rso, wantRs, 5), "resize layer: linear, aligned corners");
    BNNSFilterDestroy(rsf);
    BNNSLayerParametersDropout dp; memset(&dp, 0, sizeof dp);
    dp.i_desc = vec(NULL, 1000, BNNSDataTypeFloat32); dp.o_desc = dp.i_desc; dp.rate = 0.25f; dp.seed = 7;
    BNNSFilter df = BNNSFilterCreateLayerDropout(&dp, NULL);
    float *ones = malloc(1000 * sizeof(float)), *dro = malloc(1000 * sizeof(float));
    for (int i = 0; i < 1000; i++) ones[i] = 1;
    int zeros = 0; float sum = 0;
    CHECK(df && BNNSFilterApply(df, ones, dro) == 0, "dropout layer applies");
    for (int i = 0; i < 1000; i++) { zeros += dro[i] == 0; sum += dro[i]; }
    CHECK(zeros > 180 && zeros < 320 && fabsf(sum / 1000 - 1) < 0.15f, "dropout drops about a quarter and rescales the rest");
    free(ones); free(dro); BNNSFilterDestroy(df);
    float dict[6] = {1, 2, 3, 4, 5, 6}; int32_t eidx[2] = {2, 0}; float eo[4];
    BNNSLayerParametersEmbedding ep; memset(&ep, 0, sizeof ep);
    ep.i_desc = vec(NULL, 2, BNNSDataTypeInt32); ep.o_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 2, 2);
    ep.dictionary = desc2(dict, BNNSDataLayout2DLastMajor, 2, 3); ep.padding_idx = 99;
    BNNSFilter ef = BNNSFilterCreateLayerEmbedding(&ep, NULL);
    float wantEm[4] = {5, 6, 1, 2};
    CHECK(ef && BNNSFilterApply(ef, eidx, eo) == 0 && allclose(eo, wantEm, 4), "embedding layer");
    BNNSFilterDestroy(ef);
    BNNSLayerParametersGram gp; memset(&gp, 0, sizeof gp);
    gp.alpha = 1; gp.i_desc = chw(NULL, 2, 1, 2); gp.o_desc = desc2(NULL, BNNSDataLayout2DLastMajor, 2, 2);
    BNNSFilter grf = BNNSFilterCreateLayerGram(&gp, NULL);
    float gin[4] = {1, 2, 3, 4}, gout[4]; float wantGram[4] = {5, 11, 11, 25};
    CHECK(grf && BNNSFilterApply(grf, gin, gout) == 0 && allclose(gout, wantGram, 4), "Gram layer");
    BNNSFilterDestroy(grf);

    /* fused: fully connected -> batch norm */
    float fW[2] = {1, 2}, fx[2] = {1, 3}, fo[2];
    BNNSLayerParametersFullyConnected ffc; memset(&ffc, 0, sizeof ffc);
    ffc.i_desc = vec(NULL, 1, BNNSDataTypeFloat32); ffc.o_desc = vec(NULL, 2, BNNSDataTypeFloat32);
    ffc.w_desc = desc2(fW, BNNSDataLayoutRowMajorMatrix, 1, 2);
    BNNSLayerParametersNormalization fnp; memset(&fnp, 0, sizeof fnp);
    fnp.i_desc = vec(NULL, 2, BNNSDataTypeFloat32); fnp.o_desc = fnp.i_desc; fnp.epsilon = 0;
    BNNSFilterType ft[2] = {BNNSFullyConnected, BNNSBatchNorm};
    const void *fps[2] = {&ffc, &fnp};
    BNNSFilter ff = BNNSFilterCreateFusedLayer(2, ft, fps, NULL);
    float fout[4];
    CHECK(ff && BNNSFusedFilterApplyBatch(ff, 2, fx, 1, fout, 2, true) == 0 && CLOSE(fout[0], -1) && CLOSE(fout[1], -1) &&
          CLOSE(fout[2], 1) && CLOSE(fout[3], 1), "fused fully connected and batch norm");
    (void)fo;
    BNNSFilterDestroy(ff);

    /* loss: softmax cross entropy and mean square error */
    float logits[3] = {1, 2, 3}, onehot[3] = {0, 0, 1}, loss[1], lgrad[3];
    BNNSLayerParametersLossSoftmaxCrossEntropy lp; memset(&lp, 0, sizeof lp);
    lp.function = BNNSLossFunctionSoftmaxCrossEntropy; lp.i_desc = vec(NULL, 3, BNNSDataTypeFloat32);
    lp.o_desc = vec(NULL, 1, BNNSDataTypeFloat32); lp.reduction = BNNSLossReductionSum;
    BNNSFilter lf = BNNSFilterCreateLayerLoss(&lp, NULL);
    BNNSNDArrayDescriptor lgd = vec(lgrad, 3, BNNSDataTypeFloat32);
    CHECK(lf && BNNSLossFilterApplyBatch(lf, 1, logits, 3, onehot, 3, NULL, 0, loss, &lgd, 3) == 0 && CLOSE(loss[0], -log(e3 / es)) &&
          CLOSE(lgrad[2], e3 / es - 1) && CLOSE(lgrad[0], e1 / es), "softmax cross entropy loss and gradient");
    BNNSFilterDestroy(lf);
    BNNSLayerParametersLossBase mp; memset(&mp, 0, sizeof mp);
    mp.function = BNNSLossFunctionMeanSquareError; mp.i_desc = vec(NULL, 3, BNNSDataTypeFloat32);
    mp.o_desc = vec(NULL, 1, BNNSDataTypeFloat32); mp.reduction = BNNSLossReductionMean;
    lf = BNNSFilterCreateLayerLoss(&mp, NULL);
    CHECK(lf && BNNSLossFilterApplyBatch(lf, 1, logits, 3, onehot, 3, NULL, 0, loss, NULL, 0) == 0 && CLOSE(loss[0], (1 + 4 + 4) / 3.0f),
          "mean square error loss");
    BNNSFilterDestroy(lf);
    BNNSLayerParametersLossYolo yp; memset(&yp, 0, sizeof yp);
    yp.function = BNNSLossFunctionYolo; yp.i_desc = vec(NULL, 3, BNNSDataTypeFloat32);
    CHECK(BNNSFilterCreateLayerLoss(&yp, NULL) == NULL, "YOLO loss is not in isim: creation fails");
    BNNSLayerParametersMultiheadAttention mha; memset(&mha, 0, sizeof mha);
    CHECK(BNNSFilterCreateLayerMultiheadAttention(&mha, NULL) == NULL, "multihead attention is not in isim: creation fails");
}

static void training(int *checks, int *failures) {
    /* SGD with momentum (variant 0) over two steps */
    float w[2] = {1, 2}, g[2] = {0.5f, -1}, v[2] = {0, 0};
    BNNSNDArrayDescriptor wd = vec(w, 2, BNNSDataTypeFloat32), gd = vec(g, 2, BNNSDataTypeFloat32), vd = vec(v, 2, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor *params[1] = {&wd}, *acc[1] = {&vd};
    const BNNSNDArrayDescriptor *grads[1] = {&gd};
    BNNSOptimizerSGDMomentumFields sgd; memset(&sgd, 0, sizeof sgd);
    sgd.learning_rate = 0.1f; sgd.momentum = 0.9f; sgd.gradient_scale = 1;
    BNNSOptimizerStep(BNNSOptimizerFunctionSGDMomentum, &sgd, 1, params, grads, acc, NULL);
    CHECK(CLOSE(w[0], 0.95f) && CLOSE(v[0], -0.05f), "SGD with momentum: first step");
    BNNSOptimizerStep(BNNSOptimizerFunctionSGDMomentum, &sgd, 1, params, grads, acc, NULL);
    CHECK(CLOSE(v[0], -0.095f) && CLOSE(w[0], 0.855f) && CLOSE(w[1], 2.29f), "SGD with momentum: second step");
    /* Adam, first step moves each weight by about the learning rate */
    float aw[2] = {1, 1}, ag[2] = {0.3f, -2}, m1[2] = {0}, m2[2] = {0};
    BNNSNDArrayDescriptor awd = vec(aw, 2, BNNSDataTypeFloat32), agd = vec(ag, 2, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor m1d = vec(m1, 2, BNNSDataTypeFloat32), m2d = vec(m2, 2, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor *ap[1] = {&awd}, *aacc[2] = {&m1d, &m2d};
    const BNNSNDArrayDescriptor *ag1[1] = {&agd};
    BNNSOptimizerAdamFields adam; memset(&adam, 0, sizeof adam);
    adam.learning_rate = 0.01f; adam.beta1 = 0.9f; adam.beta2 = 0.999f; adam.time_step = 1; adam.epsilon = 1e-8f; adam.gradient_scale = 1;
    CHECK(BNNSOptimizerStep(BNNSOptimizerFunctionAdam, &adam, 1, ap, ag1, aacc, NULL) == 0 && CLOSE(aw[0], 0.99f) && CLOSE(aw[1], 1.01f),
          "Adam: the first step is the learning rate");
    /* RMSProp */
    float rw[1] = {1}, rg[1] = {2}, rn[1] = {0};
    BNNSNDArrayDescriptor rwd = vec(rw, 1, BNNSDataTypeFloat32), rgd = vec(rg, 1, BNNSDataTypeFloat32), rnd = vec(rn, 1, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor *rp[1] = {&rwd}, *racc[1] = {&rnd};
    const BNNSNDArrayDescriptor *rgs[1] = {&rgd};
    BNNSOptimizerRMSPropFields rms; memset(&rms, 0, sizeof rms);
    rms.learning_rate = 0.1f; rms.alpha = 0.9f; rms.epsilon = 0; rms.gradient_scale = 1;
    CHECK(BNNSOptimizerStep(BNNSOptimizerFunctionRMSProp, &rms, 1, rp, rgs, racc, NULL) == 0 && CLOSE(rn[0], 0.4f) &&
          CLOSE(rw[0], 1 - 0.1f * 2 / sqrtf(0.4f)), "RMSProp");
    /* clipping by value through the "with clipping" fields */
    float cw[1] = {0}, cg[1] = {5};
    BNNSNDArrayDescriptor cwd = vec(cw, 1, BNNSDataTypeFloat32), cgd = vec(cg, 1, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor *cp[1] = {&cwd};
    const BNNSNDArrayDescriptor *cgs[1] = {&cgd};
    BNNSOptimizerSGDMomentumWithClippingFields sc; memset(&sc, 0, sizeof sc);
    sc.learning_rate = 1; sc.gradient_scale = 1; sc.clipping_func = BNNSOptimizerClippingByValue; sc.clip_gradients_min = -1; sc.clip_gradients_max = 1;
    CHECK(BNNSOptimizerStep(BNNSOptimizerFunctionSGDMomentumWithClipping, &sc, 1, cp, cgs, NULL, NULL) == 0 && cw[0] == -1,
          "SGD with clipping by value");

    /* a tiny training loop: fit y = 2x + 1 with a fully connected layer, its backward and SGD */
    float W[1] = {0}, B[1] = {0};
    BNNSLayerParametersFullyConnected fc; memset(&fc, 0, sizeof fc);
    fc.i_desc = vec(NULL, 1, BNNSDataTypeFloat32); fc.o_desc = vec(NULL, 1, BNNSDataTypeFloat32);
    fc.w_desc = desc2(W, BNNSDataLayoutRowMajorMatrix, 1, 1); fc.bias = vec(B, 1, BNNSDataTypeFloat32);
    BNNSFilterParameters fp; memset(&fp, 0, sizeof fp); fp.flags = BNNSFlagsUseClientPtr;
    BNNSFilter f = BNNSFilterCreateLayerFullyConnected(&fc, &fp);
    BNNSLayerParametersLossBase lb; memset(&lb, 0, sizeof lb);
    lb.function = BNNSLossFunctionMeanSquareError; lb.i_desc = vec(NULL, 1, BNNSDataTypeFloat32); lb.o_desc = lb.i_desc;
    lb.reduction = BNNSLossReductionMean;
    BNNSFilter lf = BNNSFilterCreateLayerLoss(&lb, NULL);
    float xs[4] = {0, 1, 2, 3}, ys[4] = {1, 3, 5, 7}, out[4], dout[4], dW[1], dB[1], loss = 0;
    BNNSNDArrayDescriptor doutd = vec(dout, 1, BNNSDataTypeFloat32), dWd = desc2(dW, BNNSDataLayoutRowMajorMatrix, 1, 1), dBd = vec(dB, 1, BNNSDataTypeFloat32);
    BNNSNDArrayDescriptor Wd = fc.w_desc, Bd = fc.bias;
    BNNSNDArrayDescriptor *ps[2] = {&Wd, &Bd};
    const BNNSNDArrayDescriptor *gs[2] = {&dWd, &dBd};
    BNNSOptimizerSGDMomentumFields plain; memset(&plain, 0, sizeof plain);
    plain.learning_rate = 0.1f; plain.gradient_scale = 1;
    for (int it = 0; it < 300; it++) {
        BNNSFilterApplyBatch(f, 4, xs, 1, out, 1);
        BNNSLossFilterApplyBatch(lf, 4, out, 1, ys, 1, NULL, 0, &loss, &doutd, 1);
        BNNSFilterApplyBackwardBatch(f, 4, xs, 1, NULL, 0, out, 1, &doutd, 1, &dWd, &dBd);
        BNNSOptimizerStep(BNNSOptimizerFunctionSGDMomentum, &plain, 2, ps, gs, NULL, NULL);
    }
    CHECK(fabsf(W[0] - 2) < 0.01f && fabsf(B[0] - 1) < 0.02f && loss < 1e-3f, "training loop: fully connected + MSE + SGD fits y = 2x + 1");
    BNNSFilterDestroy(f); BNNSFilterDestroy(lf);

    /* random generator: seeded, reproducible through its state */
    BNNSRandomGenerator rg1 = BNNSCreateRandomGeneratorWithSeed(BNNSRandomGeneratorMethodAES_CTR, 42, NULL);
    float r1[1000], r2[5];
    BNNSNDArrayDescriptor rd = vec(r1, 1000, BNNSDataTypeFloat32);
    size_t ss = BNNSRandomGeneratorStateSize(rg1);
    void *state = malloc(ss);
    CHECK(rg1 && ss > 0 && BNNSRandomGeneratorGetState(rg1, ss, state) == 0, "random generator: create with a seed, get its state");
    BNNSRandomFillUniformFloat(rg1, &rd, -1, 1);
    float mn = 2, mx = -2; double mean = 0;
    for (int i = 0; i < 1000; i++) { if (r1[i] < mn) mn = r1[i]; if (r1[i] > mx) mx = r1[i]; mean += r1[i]; }
    CHECK(mn >= -1 && mx < 1 && fabs(mean / 1000) < 0.1, "BNNSRandomFillUniformFloat stays in range");
    BNNSRandomGeneratorSetState(rg1, ss, state);
    BNNSNDArrayDescriptor rd2 = vec(r2, 5, BNNSDataTypeFloat32);
    BNNSRandomFillUniformFloat(rg1, &rd2, -1, 1);
    CHECK(memcmp(r1, r2, sizeof r2) == 0, "BNNSRandomGeneratorSetState replays the stream");
    BNNSRandomFillNormalFloat(rg1, &rd, 5, 2);
    mean = 0; double var = 0;
    for (int i = 0; i < 1000; i++) mean += r1[i];
    mean /= 1000;
    for (int i = 0; i < 1000; i++) var += (r1[i] - mean) * (r1[i] - mean);
    CHECK(fabs(mean - 5) < 0.3 && fabs(sqrt(var / 1000) - 2) < 0.3, "BNNSRandomFillNormalFloat");
    int32_t ri[100]; BNNSNDArrayDescriptor rid = vec(ri, 100, BNNSDataTypeInt32);
    int inr = BNNSRandomFillUniformInt(rg1, &rid, 3, 5) == 0;
    for (int i = 0; i < 100; i++) if (ri[i] < 3 || ri[i] > 5) inr = 0;
    CHECK(inr, "BNNSRandomFillUniformInt: inclusive range");
    float probs[3] = {0, 1, 0}, cat[4];
    BNNSNDArrayDescriptor pd = vec(probs, 3, BNNSDataTypeFloat32), cd = vec(cat, 4, BNNSDataTypeFloat32);
    CHECK(BNNSRandomFillCategoricalFloat(rg1, &cd, &pd, false) == 0 && cat[0] == 1 && cat[3] == 1, "BNNSRandomFillCategoricalFloat");
    free(state); BNNSDestroyRandomGenerator(rg1);

    /* nearest neighbors */
    BNNSNearestNeighbors knn = BNNSCreateNearestNeighbors(10, 2, 2, BNNSDataTypeFloat32, NULL);
    float pts[8] = {0, 0, 1, 0, 0, 3, 5, 5};
    int nidx[2]; float ndist[2];
    CHECK(knn && BNNSNearestNeighborsLoad(knn, 4, pts) == 0 && BNNSNearestNeighborsGetInfo(knn, 0, nidx, ndist) == 0 &&
          nidx[0] == 1 && nidx[1] == 2 && CLOSE(ndist[0], 1) && CLOSE(ndist[1], 3), "nearest neighbors: sorted indices and distances");
    int all[8];
    CHECK(BNNSNearestNeighborsGetInfo(knn, -1, all, NULL) == 0 && all[6] == 2 && all[7] == 1, "nearest neighbors: every sample");
    BNNSDestroyNearestNeighbors(knn);
}

static int graph_log_called;
static void graph_log(BNNSGraphMessageLevel lvl, const char *msg, const char *loc, bnns_user_message_data_t *data) {
    (void)loc; (void)data; if (lvl == BNNSGraphMessageLevelError && strstr(msg, "not documented")) graph_log_called = 1;
}
static void graph(int *checks, int *failures) {
    bnns_graph_compile_options_t o = BNNSGraphCompileOptionsMakeDefault();
    BNNSGraphCompileOptionsSetTargetSingleThread(o, true);
    BNNSGraphCompileOptionsSetOptimizationPreference(o, BNNSGraphOptimizationPreferenceIRSize);
    BNNSGraphCompileOptionsSetOutputPath(o, "/tmp/out.bnnsir");
    CHECK(o.data && BNNSGraphCompileOptionsGetTargetSingleThread(o) && !BNNSGraphCompileOptionsGetGenerateDebugInfo(o) &&
          BNNSGraphCompileOptionsGetOptimizationPreference(o) == BNNSGraphOptimizationPreferenceIRSize &&
          strcmp(BNNSGraphCompileOptionsGetOutputPath(o), "/tmp/out.bnnsir") == 0 && BNNSGraphCompileOptionsGetOutputFD(o) == -1,
          "BNNSGraphCompileOptions: set and get");
    BNNSGraphCompileOptionsSetMessageLogCallback(o, graph_log, NULL);
    bnns_graph_t g = BNNSGraphCompileFromFile("/nonexistent/model.mlmodelc", NULL, o);
    CHECK(g.data == NULL && graph_log_called, "BNNSGraphCompileFromFile: Apple's compiled models fail cleanly, with a log message");
    bnns_graph_context_t c = BNNSGraphContextMake(g);
    CHECK(c.data == NULL && BNNSGraphGetArgumentCount(g, NULL) == 0, "BNNSGraphContextMake of no graph fails");
    BNNSGraphCompileOptionsDestroy(o);
}

void bnns(int *checks, int *failures) {
    types_and_layouts(checks, failures);
    direct_functions(checks, failures);
    layers(checks, failures);
    training(checks, failures);
    graph(checks, failures);
}
