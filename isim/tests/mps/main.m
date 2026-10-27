// Metal Performance Shaders from Objective-C (MPSTest.app, issue #365): image kernels (blurs, convolution, morphology,
// edges, thresholds, scaling, transposition, arithmetic, statistics, histograms, integral images, reductions), MPSImage
// reads and writes, matrices (products against naive loops, softmax, top-K, neurons, LU and Cholesky decompositions
// and solves) and N-dimensional arrays, and MPSGraph (operations, gradients against finite differences, a linear
// regression trained with SGD, a compiled executable), and MetalFX's spatial and temporal scalers, on isim's CPU
// Metal device. Checks print PASS / FAIL.
#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#import <MetalPerformanceShaders/MetalPerformanceShaders.h>
#import <MetalPerformanceShadersGraph/MetalPerformanceShadersGraph.h>
#import <MetalFX/MetalFX.h>
#include <math.h>
#include <stdio.h>

#pragma clang diagnostic ignored "-Wunguarded-availability-new"   /* the test calls the API of every iOS version */

static int checks, failures;
#define CHECK(cond, ...) do { checks++; char what_[220]; snprintf(what_, sizeof what_, __VA_ARGS__); \
    if (cond) printf("PASS  %s\n", what_); else { failures++; printf("FAIL  %s  (%s:%d)\n", what_, __FILE__, __LINE__); } } while (0)
static BOOL near(double a, double b, double tol) { return fabs(a - b) <= tol; }

static id<MTLDevice> dev;
static id<MTLCommandQueue> queue;

/* a w x h RGBA32Float texture (or one channel R32Float) filled by f(x, y, channel) */
static id<MTLTexture> texture(NSUInteger w, NSUInteger h, int channels, float (^f)(NSUInteger x, NSUInteger y, int c)) {
    MTLTextureDescriptor *d = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:channels == 1 ? MTLPixelFormatR32Float : MTLPixelFormatRGBA32Float
                                                                                 width:w height:h mipmapped:NO];
    d.usage = MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite;
    id<MTLTexture> t = [dev newTextureWithDescriptor:d];
    if (f) {
        float *px = calloc(w * h * (size_t)channels, sizeof(float));
        for (NSUInteger y = 0; y < h; y++) for (NSUInteger x = 0; x < w; x++) for (int c = 0; c < channels; c++) px[(y * w + x) * (size_t)channels + (size_t)c] = f(x, y, c);
        [t replaceRegion:MTLRegionMake2D(0, 0, w, h) mipmapLevel:0 withBytes:px bytesPerRow:w * sizeof(float) * (size_t)channels];
        free(px);
    }
    return t;
}
static float px(id<MTLTexture> t, NSUInteger x, NSUInteger y, int c) {
    int n = t.pixelFormat == MTLPixelFormatR32Float ? 1 : 4;
    float v[4] = { 0 };
    [t getBytes:v bytesPerRow:sizeof(float) * (size_t)n fromRegion:MTLRegionMake2D(x, y, 1, 1) mipmapLevel:0];
    return v[c];
}
static void run(void (^encode)(id<MTLCommandBuffer> cb)) {
    id<MTLCommandBuffer> cb = [queue commandBuffer];
    encode(cb);
    [cb commit];
    [cb waitUntilCompleted];
}

static void images(void) {
    /* a single bright pixel in the middle of a dark 9x9 image */
    id<MTLTexture> dot = texture(9, 9, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : (x == 4 && y == 4 ? 1 : 0); });
    id<MTLTexture> out = texture(9, 9, 4, nil);
    MPSImageGaussianBlur *blur = [[MPSImageGaussianBlur alloc] initWithDevice:dev sigma:1];
    run(^(id<MTLCommandBuffer> cb) { [blur encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    double center = px(out, 4, 4, 0), side = px(out, 5, 4, 0), sum = 0;
    for (NSUInteger y = 0; y < 9; y++) for (NSUInteger x = 0; x < 9; x++) sum += px(out, x, y, 0);
    CHECK(near(center, 0.1592, 0.0005) && near(side, 0.0966, 0.0005) && near(sum, 1, 0.01), "a Gaussian blur of sigma 1 spreads a dot (%.4f, %.4f, sum %.3f)", center, side, sum);
    CHECK(near(px(out, 4, 4, 3), 1, 1e-4), "and keeps an opaque alpha");

    MPSImageBox *box = [[MPSImageBox alloc] initWithDevice:dev kernelWidth:3 kernelHeight:3];
    run(^(id<MTLCommandBuffer> cb) { [box encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    CHECK(near(px(out, 3, 3, 0), 1.0 / 9, 1e-5) && px(out, 2, 2, 0) == 0, "a 3x3 box (%.4f)", px(out, 3, 3, 0));
    MPSImageTent *tent = [[MPSImageTent alloc] initWithDevice:dev kernelWidth:3 kernelHeight:3];
    run(^(id<MTLCommandBuffer> cb) { [tent encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    CHECK(near(px(out, 4, 4, 0), 0.25, 1e-5) && near(px(out, 3, 3, 0), 1.0 / 16, 1e-5), "a 3x3 tent (%.4f)", px(out, 4, 4, 0));

    float sharpen[9] = { 0, -1, 0, -1, 5, -1, 0, -1, 0 };
    MPSImageConvolution *conv = [[MPSImageConvolution alloc] initWithDevice:dev kernelWidth:3 kernelHeight:3 weights:sharpen];
    run(^(id<MTLCommandBuffer> cb) { [conv encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    CHECK(near(px(out, 4, 4, 0), 5, 1e-5) && near(px(out, 4, 3, 0), -1, 1e-5), "a convolution (%.1f, %.1f)", px(out, 4, 4, 0), px(out, 4, 3, 0));

    MPSImageAreaMax *amax = [[MPSImageAreaMax alloc] initWithDevice:dev kernelWidth:3 kernelHeight:3];
    run(^(id<MTLCommandBuffer> cb) { [amax encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    CHECK(px(out, 3, 5, 0) == 1 && px(out, 2, 4, 0) == 0, "area max grows the dot to 3x3");
    float probe[9] = { 0 };
    MPSImageErode *erode = [[MPSImageErode alloc] initWithDevice:dev kernelWidth:3 kernelHeight:3 values:probe];
    run(^(id<MTLCommandBuffer> cb) { [erode encodeToCommandBuffer:cb sourceTexture:dot destinationTexture:out]; });
    CHECK(px(out, 4, 4, 0) == 0, "erosion removes it");

    /* salt noise removed by a median */
    id<MTLTexture> noisy = texture(5, 5, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : (x == 2 && y == 2 ? 1 : 0.5f); });
    MPSImageMedian *median = [[MPSImageMedian alloc] initWithDevice:dev kernelDiameter:3];
    id<MTLTexture> out5 = texture(5, 5, 4, nil);
    run(^(id<MTLCommandBuffer> cb) { [median encodeToCommandBuffer:cb sourceTexture:noisy destinationTexture:out5]; });
    CHECK(near(px(out5, 2, 2, 0), 0.5, 1e-6), "a median removes salt noise");

    /* a vertical edge: Sobel magnitude 4 at the step, 0 elsewhere */
    id<MTLTexture> step = texture(6, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : (x >= 3 ? 1 : 0); });
    id<MTLTexture> edges = texture(6, 4, 1, nil);
    MPSImageSobel *sobel = [[MPSImageSobel alloc] initWithDevice:dev];
    sobel.edgeMode = MPSImageEdgeModeClamp;
    run(^(id<MTLCommandBuffer> cb) { [sobel encodeToCommandBuffer:cb sourceTexture:step destinationTexture:edges]; });
    CHECK(near(px(edges, 2, 1, 0), 4, 1e-4) && near(px(edges, 0, 1, 0), 0, 1e-6), "Sobel finds the edge (%.2f)", px(edges, 2, 1, 0));

    /* thresholds of the luminance */
    id<MTLTexture> ramp = texture(4, 1, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : x * 0.25f + 0.1f; });
    id<MTLTexture> bin = texture(4, 1, 1, nil);
    MPSImageThresholdBinary *th = [[MPSImageThresholdBinary alloc] initWithDevice:dev thresholdValue:0.5f maximumValue:0.8f linearGrayColorTransform:NULL];
    run(^(id<MTLCommandBuffer> cb) { [th encodeToCommandBuffer:cb sourceTexture:ramp destinationTexture:bin]; });
    CHECK(px(bin, 1, 0, 0) == 0 && near(px(bin, 2, 0, 0), 0.8, 1e-6), "a binary threshold");
    MPSImageThresholdTruncate *tr = [[MPSImageThresholdTruncate alloc] initWithDevice:dev thresholdValue:0.5f linearGrayColorTransform:NULL];
    run(^(id<MTLCommandBuffer> cb) { [tr encodeToCommandBuffer:cb sourceTexture:ramp destinationTexture:bin]; });
    CHECK(near(px(bin, 0, 0, 0), 0.1, 1e-5) && near(px(bin, 3, 0, 0), 0.5, 1e-6), "a truncating threshold");

    /* scaling: a ramp of 4 pixels (x / 3) up to 8: destination 2 samples the source at 0.75 */
    id<MTLTexture> small = texture(4, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : (float)x / 3; });
    id<MTLTexture> big = texture(8, 8, 4, nil);
    MPSImageBilinearScale *bil = [[MPSImageBilinearScale alloc] initWithDevice:dev];
    run(^(id<MTLCommandBuffer> cb) { [bil encodeToCommandBuffer:cb sourceTexture:small destinationTexture:big]; });
    CHECK(near(px(big, 0, 0, 0), 0, 1e-5) && near(px(big, 2, 0, 0), 0.25, 1e-5) && near(px(big, 7, 0, 0), 1, 1e-5),
          "bilinear scaling keeps a ramp (%.3f, %.3f)", px(big, 2, 0, 0), px(big, 7, 0, 0));
    MPSImageLanczosScale *lz = [[MPSImageLanczosScale alloc] initWithDevice:dev];
    id<MTLTexture> half = texture(2, 2, 4, nil);
    id<MTLTexture> flat = texture(4, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return 0.6f; });
    run(^(id<MTLCommandBuffer> cb) { [lz encodeToCommandBuffer:cb sourceTexture:flat destinationTexture:half]; });
    CHECK(near(px(half, 1, 1, 0), 0.6, 1e-4), "Lanczos keeps a flat color (%.4f)", px(half, 1, 1, 0));

    id<MTLTexture> wide = texture(3, 2, 4, ^float(NSUInteger x, NSUInteger y, int c) { return (float)(y * 3 + x); });
    id<MTLTexture> tall = texture(2, 3, 4, nil);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSImageTranspose alloc] initWithDevice:dev] encodeToCommandBuffer:cb sourceTexture:wide destinationTexture:tall]; });
    CHECK(px(tall, 1, 2, 0) == 5 && px(tall, 0, 1, 0) == 1, "a transpose");

    /* arithmetic, with a broadcast row */
    id<MTLTexture> a = texture(3, 2, 4, ^float(NSUInteger x, NSUInteger y, int c) { return (float)x + 1; });
    id<MTLTexture> b = texture(3, 2, 4, ^float(NSUInteger x, NSUInteger y, int c) { return y == 0 ? 10 : 99; });
    id<MTLTexture> sum2 = texture(3, 2, 4, nil);
    MPSImageMultiply *mul = [[MPSImageMultiply alloc] initWithDevice:dev];
    mul.secondaryStrideInPixels = MTLSizeMake(1, 0, 1);         /* every row reads row 0 */
    mul.bias = 0.5f;
    run(^(id<MTLCommandBuffer> cb) { [mul encodeToCommandBuffer:cb primaryTexture:a secondaryTexture:b destinationTexture:sum2]; });
    CHECK(near(px(sum2, 2, 1, 0), 30.5, 1e-4), "multiplication with a broadcast row and a bias (%.1f)", px(sum2, 2, 1, 0));
    MPSImageSubtract *sub = [[MPSImageSubtract alloc] initWithDevice:dev];
    sub.minimumValue = 0;
    run(^(id<MTLCommandBuffer> cb) { [sub encodeToCommandBuffer:cb primaryTexture:a secondaryTexture:b destinationTexture:sum2]; });
    CHECK(px(sum2, 0, 0, 0) == 0, "subtraction clamped at the minimum");

    /* statistics */
    id<MTLTexture> vals = texture(4, 2, 4, ^float(NSUInteger x, NSUInteger y, int c) { return (float)(y * 4 + x); });
    id<MTLTexture> stats = texture(2, 1, 4, nil);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSImageStatisticsMinAndMax alloc] initWithDevice:dev] encodeToCommandBuffer:cb sourceTexture:vals destinationTexture:stats]; });
    CHECK(px(stats, 0, 0, 0) == 0 && px(stats, 1, 0, 0) == 7, "the minimum and maximum");
    run(^(id<MTLCommandBuffer> cb) { [[[MPSImageStatisticsMeanAndVariance alloc] initWithDevice:dev] encodeToCommandBuffer:cb sourceTexture:vals destinationTexture:stats]; });
    CHECK(near(px(stats, 0, 0, 0), 3.5, 1e-5) && near(px(stats, 1, 0, 0), 5.25, 1e-4), "the mean and variance (%.2f, %.2f)", px(stats, 0, 0, 0), px(stats, 1, 0, 0));
    id<MTLTexture> integral = texture(4, 2, 4, nil);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSImageIntegral alloc] initWithDevice:dev] encodeToCommandBuffer:cb sourceTexture:vals destinationTexture:integral]; });
    CHECK(px(integral, 3, 1, 0) == 28 && px(integral, 1, 1, 0) == 10, "an integral image (%.0f)", px(integral, 3, 1, 0));
    id<MTLTexture> rows = texture(1, 2, 4, nil);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSImageReduceRowSum alloc] initWithDevice:dev] encodeToCommandBuffer:cb sourceTexture:vals destinationTexture:rows]; });
    CHECK(px(rows, 0, 0, 0) == 6 && px(rows, 0, 1, 0) == 22, "row sums");

    /* a histogram of 4 bins */
    MPSImageHistogramInfo info = { 4, NO, { 0, 0, 0, 0 }, { 8, 8, 8, 8 } };
    MPSImageHistogram *hist = [[MPSImageHistogram alloc] initWithDevice:dev histogramInfo:&info];
    id<MTLBuffer> hb = [dev newBufferWithLength:[hist histogramSizeForSourceFormat:vals.pixelFormat] options:MTLResourceStorageModeShared];
    run(^(id<MTLCommandBuffer> cb) { [hist encodeToCommandBuffer:cb sourceTexture:vals histogram:hb histogramOffset:0]; });
    const uint32_t *h = hb.contents;
    CHECK(hb.length == 48 && h[0] == 2 && h[3] == 2 && h[4] == 2, "a histogram (%u %u %u %u)", h[0], h[1], h[2], h[3]);

    /* MPSImage with 6 feature channels: two slices; written and read back in both layouts */
    MPSImageDescriptor *d = [MPSImageDescriptor imageDescriptorWithChannelFormat:MPSImageFeatureChannelFormatFloat32 width:2 height:1 featureChannels:6];
    MPSImage *img = [[MPSImage alloc] initWithDevice:dev imageDescriptor:d];
    float hwc[12], back[12] = { 0 };
    for (int i = 0; i < 12; i++) hwc[i] = (float)i;
    [img writeBytes:hwc dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
    [img readBytes:back dataLayout:MPSDataLayoutFeatureChannelsxHeightxWidth imageIndex:0];
    CHECK(img.textureType == MTLTextureType2DArray && img.texture.arrayLength == 2 && img.pixelFormat == MTLPixelFormatRGBA32Float,
          "an image of 6 channels is a 2-slice array");
    CHECK(back[0] == 0 && back[1] == 6 && back[2] == 1 && back[11] == 11, "its channels read back in CHW (%.0f %.0f %.0f)", back[0], back[1], back[2]);
    MPSImage *ch = [img subImageWithFeatureChannelRange:NSMakeRange(4, 2)];
    float part[2] = { 0 };
    [ch readBytes:part dataLayout:MPSDataLayoutHeightxWidthxFeatureChannels imageIndex:0];
    CHECK(ch.featureChannels == 2 && ch.texture.arrayLength == 1 && part[0] == 4 && part[1] == 5, "a sub-image of channels 4-5 (%lu, %.0f %.0f)",
          (unsigned long)ch.texture.arrayLength, part[0], part[1]);
}

/* a row-major float32 matrix in a buffer */
static MPSMatrix *matrix(NSUInteger rows, NSUInteger cols, const float *values) {
    MPSMatrixDescriptor *d = [MPSMatrixDescriptor matrixDescriptorWithRows:rows columns:cols rowBytes:cols * sizeof(float) dataType:MPSDataTypeFloat32];
    MPSMatrix *m = [[MPSMatrix alloc] initWithDevice:dev descriptor:d];
    if (values) memcpy(m.data.contents, values, rows * cols * sizeof(float));
    return m;
}
static float at(MPSMatrix *m, NSUInteger r, NSUInteger c) { return ((const float *)((const uint8_t *)m.data.contents + r * m.rowBytes))[c]; }

static void matrices(void) {
    enum { M = 7, K = 5, N = 6 };
    float a[M * K], b[K * N];
    for (int i = 0; i < M * K; i++) a[i] = (float)((i * 7) % 11) - 5;
    for (int i = 0; i < K * N; i++) b[i] = (float)((i * 5) % 13) * 0.5f - 3;
    MPSMatrix *A = matrix(M, K, a), *B = matrix(K, N, b), *C = matrix(M, N, NULL);
    MPSMatrixMultiplication *mm = [[MPSMatrixMultiplication alloc] initWithDevice:dev resultRows:M resultColumns:N interiorColumns:K];
    run(^(id<MTLCommandBuffer> cb) { [mm encodeToCommandBuffer:cb leftMatrix:A rightMatrix:B resultMatrix:C]; });
    double worst = 0;
    for (int i = 0; i < M; i++)
        for (int j = 0; j < N; j++) {
            double s = 0;
            for (int k = 0; k < K; k++) s += a[i * K + k] * b[k * N + j];
            worst = fmax(worst, fabs(s - at(C, i, j)));
        }
    CHECK(worst < 1e-4, "a 7x5 by 5x6 product equals the naive loops (error %.2g)", worst);
    /* transposed left, alpha and beta: C = 2 * A^T(of 5x7) * B + 1 * C */
    MPSMatrix *At = matrix(K, M, NULL);
    for (int i = 0; i < M; i++) for (int k = 0; k < K; k++) ((float *)At.data.contents)[k * M + i] = a[i * K + k];
    float c0 = at(C, 2, 3);
    MPSMatrixMultiplication *mt = [[MPSMatrixMultiplication alloc] initWithDevice:dev transposeLeft:YES transposeRight:NO resultRows:M resultColumns:N
                                                                  interiorColumns:K alpha:2 beta:1];
    run(^(id<MTLCommandBuffer> cb) { [mt encodeToCommandBuffer:cb leftMatrix:At rightMatrix:B resultMatrix:C]; });
    CHECK(near(at(C, 2, 3), 3 * c0, 1e-3), "a transposed product with alpha and beta (%.2f = 3 x %.2f)", at(C, 2, 3), c0);

    /* matrix-vector */
    MPSVectorDescriptor *vd = [MPSVectorDescriptor vectorDescriptorWithLength:K dataType:MPSDataTypeFloat32];
    MPSVector *x = [[MPSVector alloc] initWithDevice:dev descriptor:vd], *y = [[MPSVector alloc] initWithDevice:dev descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:M dataType:MPSDataTypeFloat32]];
    for (int k = 0; k < K; k++) ((float *)x.data.contents)[k] = (float)k;
    MPSMatrixVectorMultiplication *mv = [[MPSMatrixVectorMultiplication alloc] initWithDevice:dev rows:M columns:K];
    run(^(id<MTLCommandBuffer> cb) { [mv encodeToCommandBuffer:cb inputMatrix:A inputVector:x resultVector:y]; });
    double y3 = 0;
    for (int k = 0; k < K; k++) y3 += a[3 * K + k] * k;
    CHECK(near(((float *)y.data.contents)[3], y3, 1e-4), "a matrix-vector product");

    /* softmax rows, top-K */
    float s[6] = { 1, 2, 3, 0, 0, 0 };
    MPSMatrix *S = matrix(2, 3, s), *P = matrix(2, 3, NULL);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSMatrixSoftMax alloc] initWithDevice:dev] encodeToCommandBuffer:cb inputMatrix:S resultMatrix:P]; });
    CHECK(near(at(P, 0, 2), 0.66524, 1e-4) && near(at(P, 1, 1), 1.0 / 3, 1e-5), "softmax rows (%.4f)", at(P, 0, 2));
    run(^(id<MTLCommandBuffer> cb) { [[[MPSMatrixLogSoftMax alloc] initWithDevice:dev] encodeToCommandBuffer:cb inputMatrix:S resultMatrix:P]; });
    CHECK(near(at(P, 0, 2), log(0.66524), 1e-4), "log-softmax");
    float t[5] = { 0.3f, 0.9f, 0.1f, 0.7f, 0.5f };
    MPSMatrix *T = matrix(1, 5, t), *TV = matrix(1, 2, NULL);
    MPSMatrixDescriptor *idd = [MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:2 rowBytes:8 dataType:MPSDataTypeUInt32];
    MPSMatrix *TI = [[MPSMatrix alloc] initWithDevice:dev descriptor:idd];
    run(^(id<MTLCommandBuffer> cb) { [[[MPSMatrixFindTopK alloc] initWithDevice:dev numberOfTopKValues:2] encodeToCommandBuffer:cb inputMatrix:T resultIndexMatrix:TI resultValueMatrix:TV]; });
    const uint32_t *ti = TI.data.contents;
    CHECK(ti[0] == 1 && ti[1] == 3 && near(at(TV, 0, 1), 0.7, 1e-6), "the top 2 values and their indices (%u, %u)", ti[0], ti[1]);

    /* a neuron: ReLU of x - 1 */
    MPSMatrixNeuron *nr = [[MPSMatrixNeuron alloc] initWithDevice:dev];
    [nr setNeuronType:MPSCNNNeuronTypeReLU parameterA:0 parameterB:0 parameterC:0];
    MPSVector *bias = [[MPSVector alloc] initWithDevice:dev descriptor:[MPSVectorDescriptor vectorDescriptorWithLength:3 dataType:MPSDataTypeFloat32]];
    for (int i = 0; i < 3; i++) ((float *)bias.data.contents)[i] = -1;
    run(^(id<MTLCommandBuffer> cb) { [nr encodeToCommandBuffer:cb inputMatrix:S biasVector:bias resultMatrix:P]; });
    CHECK(at(P, 0, 0) == 0 && at(P, 0, 2) == 2, "a ReLU neuron with a bias");

    /* LU: solve A x = b for a 3x3 system */
    float sys[9] = { 2, 1, 1, 4, -6, 0, -2, 7, 2 }, rhs[3] = { 5, -2, 9 };   /* solution (1, 1, 2) */
    MPSMatrix *SA = matrix(3, 3, sys), *LU = matrix(3, 3, NULL), *RB = matrix(3, 1, rhs), *X = matrix(3, 1, NULL);
    MPSMatrix *piv = [[MPSMatrix alloc] initWithDevice:dev descriptor:[MPSMatrixDescriptor matrixDescriptorWithRows:1 columns:3 rowBytes:12 dataType:MPSDataTypeUInt32]];
    id<MTLBuffer> status = [dev newBufferWithLength:4 options:MTLResourceStorageModeShared];
    run(^(id<MTLCommandBuffer> cb) {
        [[[MPSMatrixDecompositionLU alloc] initWithDevice:dev rows:3 columns:3] encodeToCommandBuffer:cb sourceMatrix:SA resultMatrix:LU pivotIndices:piv status:status];
        [[[MPSMatrixSolveLU alloc] initWithDevice:dev transpose:NO order:3 numberOfRightHandSides:1] encodeToCommandBuffer:cb sourceMatrix:LU
                                                                                           rightHandSideMatrix:RB pivotIndices:piv solutionMatrix:X];
    });
    CHECK(*(int32_t *)status.contents == MPSMatrixDecompositionStatusSuccess && near(at(X, 0, 0), 1, 1e-5) && near(at(X, 1, 0), 1, 1e-5) && near(at(X, 2, 0), 2, 1e-5),
          "an LU decomposition solves a system (%.3f, %.3f, %.3f)", at(X, 0, 0), at(X, 1, 0), at(X, 2, 0));
    run(^(id<MTLCommandBuffer> cb) {
        [[[MPSMatrixSolveLU alloc] initWithDevice:dev transpose:YES order:3 numberOfRightHandSides:1] encodeToCommandBuffer:cb sourceMatrix:LU
                                                                                            rightHandSideMatrix:RB pivotIndices:piv solutionMatrix:X];
    });
    double r0 = 2 * at(X, 0, 0) + 4 * at(X, 1, 0) - 2 * at(X, 2, 0);   /* A^T x, first row */
    CHECK(near(r0, 5, 1e-4), "and its transpose (%.4f)", r0);

    /* Cholesky of a symmetric positive-definite matrix */
    float spd[9] = { 4, 12, -16, 12, 37, -43, -16, -43, 98 }, rhs2[3] = { 1, 2, 3 };
    MPSMatrix *SP = matrix(3, 3, spd), *L = matrix(3, 3, NULL), *B2 = matrix(3, 1, rhs2), *X2 = matrix(3, 1, NULL);
    run(^(id<MTLCommandBuffer> cb) {
        [[[MPSMatrixDecompositionCholesky alloc] initWithDevice:dev lower:YES order:3] encodeToCommandBuffer:cb sourceMatrix:SP resultMatrix:L status:status];
        [[[MPSMatrixSolveCholesky alloc] initWithDevice:dev upper:NO order:3 numberOfRightHandSides:1] encodeToCommandBuffer:cb sourceMatrix:L rightHandSideMatrix:B2 solutionMatrix:X2];
    });
    CHECK(near(at(L, 0, 0), 2, 1e-5) && near(at(L, 1, 0), 6, 1e-5) && near(at(L, 2, 2), 3, 1e-4), "a Cholesky factor (2, 6, ..., 3)");
    double check = 4 * at(X2, 0, 0) + 12 * at(X2, 1, 0) - 16 * at(X2, 2, 0);
    CHECK(near(check, 1, 1e-3), "solves with it (%.4f)", check);
    float bad[4] = { 1, 2, 2, 1 };
    MPSMatrix *BD = matrix(2, 2, bad), *BL = matrix(2, 2, NULL);
    run(^(id<MTLCommandBuffer> cb) { [[[MPSMatrixDecompositionCholesky alloc] initWithDevice:dev lower:YES order:2] encodeToCommandBuffer:cb sourceMatrix:BD resultMatrix:BL status:status]; });
    CHECK(*(int32_t *)status.contents == MPSMatrixDecompositionStatusNonPositiveDefinite, "an indefinite matrix is reported");

    /* a triangular solve from the right: X * U = B */
    float up[4] = { 2, 1, 0, 4 }, rb[2] = { 4, 10 };            /* x = (2, 2) */
    MPSMatrix *U = matrix(2, 2, up), *RB2 = matrix(1, 2, rb), *X3 = matrix(1, 2, NULL);
    run(^(id<MTLCommandBuffer> cb) {
        [[[MPSMatrixSolveTriangular alloc] initWithDevice:dev right:YES upper:YES transpose:NO unit:NO order:2 numberOfRightHandSides:1 alpha:1]
            encodeToCommandBuffer:cb sourceMatrix:U rightHandSideMatrix:RB2 solutionMatrix:X3];
    });
    CHECK(near(at(X3, 0, 0), 2, 1e-5) && near(at(X3, 0, 1), 2, 1e-5), "a right-hand triangular solve (%.2f, %.2f)", at(X3, 0, 0), at(X3, 0, 1));

    /* float16 matrices */
    MPSMatrixDescriptor *hd = [MPSMatrixDescriptor matrixDescriptorWithRows:2 columns:2 rowBytes:4 dataType:MPSDataTypeFloat16];
    MPSMatrix *H1 = [[MPSMatrix alloc] initWithDevice:dev descriptor:hd], *H2 = [[MPSMatrix alloc] initWithDevice:dev descriptor:hd];
    _Float16 *h1 = H1.data.contents;
    h1[0] = 1; h1[1] = 2; h1[2] = 3; h1[3] = 4;
    run(^(id<MTLCommandBuffer> cb) { [[[MPSMatrixMultiplication alloc] initWithDevice:dev resultRows:2 resultColumns:2 interiorColumns:2] encodeToCommandBuffer:cb leftMatrix:H1 rightMatrix:H1 resultMatrix:H2]; });
    _Float16 *h2 = H2.data.contents;
    CHECK((float)h2[0] == 7 && (float)h2[3] == 22, "a float16 product");
}


/* ---------------- MPSGraph ---------------- */
static MPSGraphTensorData *data(NSArray<NSNumber *> *shape, const float *values) {
    NSUInteger n = 1;
    for (NSNumber *d in shape) n *= d.unsignedIntegerValue;
    return [[MPSGraphTensorData alloc] initWithDevice:[MPSGraphDevice deviceWithMTLDevice:dev] data:[NSData dataWithBytes:values length:n * sizeof(float)]
                                                shape:shape dataType:MPSDataTypeFloat32];
}
/* the float values of a result */
static NSData *values(MPSGraphTensorData *d) {
    NSUInteger n = 1;
    for (NSNumber *x in d.shape) n *= x.unsignedIntegerValue;
    NSMutableData *out = [NSMutableData dataWithLength:n * sizeof(float)];
    [[d mpsndarray] readBytes:out.mutableBytes strideBytes:NULL];
    return out;
}
static float v0(MPSGraphTensorData *d, NSUInteger i) { return ((const float *)values(d).bytes)[i]; }

static void graph_ops(void) {
    MPSGraph *g = [MPSGraph new];
    MPSGraphTensor *a = [g placeholderWithShape:@[ @2, @3 ] dataType:MPSDataTypeFloat32 name:@"a"];
    MPSGraphTensor *b = [g placeholderWithShape:@[ @3 ] dataType:MPSDataTypeFloat32 name:@"b"];
    MPSGraphTensor *sum = [g additionWithPrimaryTensor:a secondaryTensor:b name:nil];
    MPSGraphTensor *rows = [g reductionSumWithTensor:sum axis:1 name:nil];
    MPSGraphTensor *amax = [g reductionArgMaximumWithTensor:a axis:1 name:nil];
    MPSGraphTensor *mean = [g meanOfTensor:a axes:@[ @0, @1 ] name:nil];
    MPSGraphTensor *sm = [g softMaxWithTensor:a axis:-1 name:nil];
    MPSGraphTensor *cmp = [g greaterThanWithPrimaryTensor:a secondaryTensor:[g constantWithScalar:2 dataType:MPSDataTypeFloat32] name:nil];
    MPSGraphTensor *tr = [g transposeTensor:a dimension:0 withDimension:1 name:nil];
    MPSGraphTensor *mm = [g matrixMultiplicationWithPrimaryTensor:a secondaryTensor:tr name:nil];
    MPSGraphTensor *sl = [g sliceTensor:a dimension:1 start:1 length:2 name:nil];
    MPSGraphTensor *cat = [g concatTensor:a withTensor:a dimension:0 name:nil];
    MPSGraphTensor *rs = [g reshapeTensor:a withShape:@[ @3, @-1 ] name:nil];
    float av[6] = { 1, 5, 3, 4, 2, 6 }, bv[3] = { 10, 20, 30 };
    MPSGraphTensorDataDictionary *r = [g runWithFeeds:@{ a: data(@[ @2, @3 ], av), b: data(@[ @3 ], bv) }
                                        targetTensors:@[ sum, rows, amax, mean, sm, cmp, tr, mm, sl, cat, rs ] targetOperations:nil];
    CHECK([r[sum].shape isEqual:(@[ @2, @3 ])] && v0(r[sum], 4) == 22, "addition broadcasts a row (%.0f)", v0(r[sum], 4));
    CHECK([r[rows].shape isEqual:(@[ @2, @1 ])] && v0(r[rows], 1) == 72, "a reduction keeps its axis (%.0f)", v0(r[rows], 1));
    int32_t am[2];
    [[r[amax] mpsndarray] readBytes:am strideBytes:NULL];
    CHECK(r[amax].dataType == MPSDataTypeInt32 && am[0] == 1 && am[1] == 2, "argmax indices (%d, %d)", am[0], am[1]);
    CHECK(near(v0(r[mean], 0), 3.5, 1e-6), "the mean of all");
    CHECK(near(v0(r[sm], 1), exp(5) / (exp(1) + exp(5) + exp(3)), 1e-5), "softmax along the last axis");
    uint8_t c[6];
    [[r[cmp] mpsndarray] readBytes:c strideBytes:NULL];
    CHECK(r[cmp].dataType == MPSDataTypeBool && c[0] == 0 && c[1] == 1, "a comparison is boolean");
    CHECK([r[tr].shape isEqual:(@[ @3, @2 ])] && v0(r[tr], 1) == 4, "a transpose");
    CHECK([r[mm].shape isEqual:(@[ @2, @2 ])] && v0(r[mm], 0) == 35 && v0(r[mm], 1) == 32, "a x a^T (%.0f, %.0f)", v0(r[mm], 0), v0(r[mm], 1));
    CHECK([r[sl].shape isEqual:(@[ @2, @2 ])] && v0(r[sl], 2) == 2, "a slice");
    CHECK([r[cat].shape isEqual:(@[ @4, @3 ])] && v0(r[cat], 9) == 4, "a concatenation");
    CHECK([r[rs].shape isEqual:(@[ @3, @2 ])], "a reshape with -1");

    /* top-K, sort, cumulative sum, one-hot, gather */
    MPSGraphTensor *x = [g placeholderWithShape:@[ @5 ] dataType:MPSDataTypeFloat32 name:@"x"];
    NSArray *topk = [g topKWithSourceTensor:x k:2 name:nil];
    MPSGraphTensor *sorted = [g sortWithTensor:x axis:0 descending:YES name:nil];
    MPSGraphTensor *cs = [g cumulativeSumWithTensor:x axis:0 name:nil];
    float xv[5] = { 3, 1, 4, 1, 5 };
    MPSGraphTensor *idx = [g constantWithData:[NSData dataWithBytes:(int32_t[]){ 2, 0 } length:8] shape:@[ @2 ] dataType:MPSDataTypeInt32];
    MPSGraphTensor *oh = [g oneHotWithIndicesTensor:idx depth:3 name:nil];
    MPSGraphTensor *ga = [g gatherWithUpdatesTensor:x indicesTensor:idx axis:0 batchDimensions:0 name:nil];
    r = [g runWithFeeds:@{ x: data(@[ @5 ], xv) } targetTensors:@[ topk[0], topk[1], sorted, cs, oh, ga ] targetOperations:nil];
    int32_t ti[2];
    [[r[topk[1]] mpsndarray] readBytes:ti strideBytes:NULL];
    CHECK(v0(r[topk[0]], 0) == 5 && v0(r[topk[0]], 1) == 4 && ti[0] == 4 && ti[1] == 2, "top 2 and their indices");
    CHECK(v0(r[sorted], 0) == 5 && v0(r[sorted], 4) == 1, "a descending sort");
    CHECK(v0(r[cs], 4) == 14 && v0(r[cs], 2) == 8, "a cumulative sum");
    CHECK([r[oh].shape isEqual:(@[ @2, @3 ])] && v0(r[oh], 2) == 1 && v0(r[oh], 3) == 1 && v0(r[oh], 0) == 0, "one-hot rows");
    CHECK(v0(r[ga], 0) == 4 && v0(r[ga], 1) == 3, "a gather");

    /* a 2x2 convolution of ones over 3x3 ones, then 2x2 max pooling */
    MPSGraphTensor *img = [g constantWithScalar:1 shape:@[ @1, @1, @3, @3 ] dataType:MPSDataTypeFloat32];
    MPSGraphTensor *k = [g constantWithScalar:1 shape:@[ @1, @1, @2, @2 ] dataType:MPSDataTypeFloat32];
    MPSGraphConvolution2DOpDescriptor *cd = [MPSGraphConvolution2DOpDescriptor descriptorWithStrideInX:1 strideInY:1 dilationRateInX:1 dilationRateInY:1 groups:1
        paddingStyle:MPSGraphPaddingStyleTF_VALID dataLayout:MPSGraphTensorNamedDataLayoutNCHW weightsLayout:MPSGraphTensorNamedDataLayoutOIHW];
    MPSGraphTensor *conv = [g convolution2DWithSourceTensor:img weightsTensor:k descriptor:cd name:nil];
    MPSGraphPooling2DOpDescriptor *pd = [MPSGraphPooling2DOpDescriptor descriptorWithKernelWidth:2 kernelHeight:2 strideInX:1 strideInY:1
        paddingStyle:MPSGraphPaddingStyleTF_VALID dataLayout:MPSGraphTensorNamedDataLayoutNCHW];
    MPSGraphTensor *pool = [g maxPooling2DWithSourceTensor:conv descriptor:pd name:nil];
    r = [g runWithFeeds:@{} targetTensors:@[ conv, pool ] targetOperations:nil];
    CHECK([r[conv].shape isEqual:(@[ @1, @1, @2, @2 ])] && v0(r[conv], 3) == 4 && [r[pool].shape isEqual:(@[ @1, @1, @1, @1 ])] && v0(r[pool], 0) == 4,
          "a convolution and max pooling");
}

/* d(loss) / d(w) against central differences, for a loss through matmul, ReLU, softmax cross-entropy */
static void graph_gradients(void) {
    MPSGraph *g = [MPSGraph new];
    float xv[6] = { 0.5f, -1, 2, 1, 0.25f, -0.5f }, wv[6] = { 0.1f, -0.2f, 0.3f, 0.4f, -0.5f, 0.6f }, lv[4] = { 1, 0, 0, 1 };
    MPSGraphTensor *x = [g constantWithData:[NSData dataWithBytes:xv length:24] shape:@[ @2, @3 ] dataType:MPSDataTypeFloat32];
    MPSGraphTensor *w = [g placeholderWithShape:@[ @3, @2 ] dataType:MPSDataTypeFloat32 name:@"w"];
    MPSGraphTensor *labels = [g constantWithData:[NSData dataWithBytes:lv length:16] shape:@[ @2, @2 ] dataType:MPSDataTypeFloat32];
    MPSGraphTensor *h = [g reLUWithTensor:[g matrixMultiplicationWithPrimaryTensor:x secondaryTensor:w name:nil] name:nil];
    MPSGraphTensor *loss = [g softMaxCrossEntropyWithSourceTensor:h labelsTensor:labels axis:-1 reductionType:MPSGraphLossReductionTypeMean name:nil];
    MPSGraphTensor *dw = [g gradientForPrimaryTensor:loss withTensors:@[ w ] name:nil][w];
    MPSGraphTensorDataDictionary *r = [g runWithFeeds:@{ w: data(@[ @3, @2 ], wv) } targetTensors:@[ loss, dw ] targetOperations:nil];
    double worst = 0;
    for (int i = 0; i < 6; i++) {
        float wp[6], wm[6];
        memcpy(wp, wv, sizeof wp); memcpy(wm, wv, sizeof wm);
        wp[i] += 1e-3f; wm[i] -= 1e-3f;
        double lp = v0([g runWithFeeds:@{ w: data(@[ @3, @2 ], wp) } targetTensors:@[ loss ] targetOperations:nil][loss], 0);
        double lm = v0([g runWithFeeds:@{ w: data(@[ @3, @2 ], wm) } targetTensors:@[ loss ] targetOperations:nil][loss], 0);
        worst = fmax(worst, fabs((lp - lm) / 2e-3 - v0(r[dw], i)));
    }
    CHECK([r[dw].shape isEqual:(@[ @3, @2 ])] && worst < 2e-3, "gradients through matmul, ReLU and cross-entropy match finite differences (%.2g)", worst);

    /* the gradient of sum((a * b)^2) w.r.t. a broadcast b sums over the broadcast rows */
    MPSGraphTensor *A = [g constantWithScalar:2 shape:@[ @3, @2 ] dataType:MPSDataTypeFloat32];
    MPSGraphTensor *B = [g placeholderWithShape:@[ @2 ] dataType:MPSDataTypeFloat32 name:@"b"];
    MPSGraphTensor *f = [g reductionSumWithTensor:[g squareWithTensor:[g multiplicationWithPrimaryTensor:A secondaryTensor:B name:nil] name:nil] axes:nil name:nil];
    MPSGraphTensor *dB = [g gradientForPrimaryTensor:f withTensors:@[ B ] name:nil][B];
    float bv[2] = { 1, -3 };
    r = [g runWithFeeds:@{ B: data(@[ @2 ], bv) } targetTensors:@[ dB ] targetOperations:nil];
    CHECK([r[dB].shape isEqual:(@[ @2 ])] && near(v0(r[dB], 0), 24, 1e-4) && near(v0(r[dB], 1), -72, 1e-4), "a broadcast operand's gradient (%.1f, %.1f)",
          v0(r[dB], 0), v0(r[dB], 1));
}

/* y = 2x + 1 learned by w and b with SGD */
static void graph_training(void) {
    MPSGraph *g = [MPSGraph new];
    float zero = 0;
    MPSGraphTensor *w = [g variableWithData:[NSData dataWithBytes:&zero length:4] shape:@[ @1 ] dataType:MPSDataTypeFloat32 name:@"w"];
    MPSGraphTensor *b = [g variableWithData:[NSData dataWithBytes:&zero length:4] shape:@[ @1 ] dataType:MPSDataTypeFloat32 name:@"b"];
    MPSGraphTensor *x = [g placeholderWithShape:@[ @8 ] dataType:MPSDataTypeFloat32 name:@"x"], *y = [g placeholderWithShape:@[ @8 ] dataType:MPSDataTypeFloat32 name:@"y"];
    MPSGraphTensor *pred = [g additionWithPrimaryTensor:[g multiplicationWithPrimaryTensor:x secondaryTensor:w name:nil] secondaryTensor:b name:nil];
    MPSGraphTensor *loss = [g meanOfTensor:[g squareWithTensor:[g subtractionWithPrimaryTensor:pred secondaryTensor:y name:nil] name:nil] axes:@[ @0 ] name:nil];
    MPSGraphTensorDictionary *grads = [g gradientForPrimaryTensor:loss withTensors:@[ w, b ] name:nil];
    MPSGraphTensor *lr = [g constantWithScalar:0.1 dataType:MPSDataTypeFloat32];
    MPSGraphOperation *uw = [g applyStochasticGradientDescentWithLearningRateTensor:lr variable:w gradientTensor:grads[w] name:nil];
    MPSGraphOperation *ub = [g applyStochasticGradientDescentWithLearningRateTensor:lr variable:b gradientTensor:grads[b] name:nil];
    float xs[8], ys[8];
    for (int i = 0; i < 8; i++) { xs[i] = (float)i / 4 - 1; ys[i] = 2 * xs[i] + 1; }
    float first = 0, last = 0;
    for (int step = 0; step < 300; step++) {
        MPSGraphTensorDataDictionary *r = [g runWithFeeds:@{ x: data(@[ @8 ], xs), y: data(@[ @8 ], ys) } targetTensors:@[ loss ] targetOperations:@[ uw, ub ]];
        if (step == 0) first = v0(r[loss], 0);
        last = v0(r[loss], 0);
    }
    MPSGraphTensorDataDictionary *r = [g runWithFeeds:@{} targetTensors:@[ w, b ] targetOperations:nil];
    CHECK(first > 1 && last < 1e-4 && near(v0(r[w], 0), 2, 0.01) && near(v0(r[b], 0), 1, 0.01), "SGD learns y = 2x + 1 (w %.3f, b %.3f, loss %.3g -> %.2g)",
          v0(r[w], 0), v0(r[b], 0), first, last);

    /* a compiled executable over the same graph */
    MPSGraphExecutable *e = [g compileWithDevice:nil feeds:@{ x: [[MPSGraphShapedType alloc] initWithShape:@[ @8 ] dataType:MPSDataTypeFloat32] }
                                   targetTensors:@[ pred ] targetOperations:nil compilationDescriptor:nil];
    NSArray<MPSGraphTensorData *> *out = [e runWithMTLCommandQueue:queue inputsArray:@[ data(@[ @8 ], xs) ] resultsArray:nil executionDescriptor:nil];
    CHECK(e.feedTensors.count == 1 && out.count == 1 && near(v0(out[0], 7), ys[7], 0.02), "a compiled executable runs (%.3f)", v0(out[0], 7));

    /* tensor data from a matrix */
    float mv[4] = { 1, 2, 3, 4 };
    MPSMatrix *m = matrix(2, 2, mv);
    MPSGraphTensorData *md = [[MPSGraphTensorData alloc] initWithMPSMatrix:m];
    CHECK([md.shape isEqual:(@[ @2, @2 ])] && v0(md, 3) == 4, "tensor data from an MPSMatrix");
}

static void ndarrays(void) {
    MPSNDArrayDescriptor *d = [MPSNDArrayDescriptor descriptorWithDataType:MPSDataTypeFloat32 shape:@[ @2, @3 ]];
    CHECK(d.numberOfDimensions == 2 && [d lengthOfDimension:0] == 3 && [d lengthOfDimension:1] == 2, "a 2x3 shape: dimension 0 is the innermost");
    MPSNDArray *a = [[MPSNDArray alloc] initWithDevice:dev descriptor:d];
    float v[6] = { 1, 2, 3, 4, 5, 6 }, back[6] = { 0 };
    [a writeBytes:v strideBytes:NULL];
    [a readBytes:back strideBytes:NULL];
    CHECK(!memcmp(v, back, sizeof v) && a.resourceSize == 24, "written and read back packed");
    NSInteger strides[2] = { 8, 24 };                          /* every other float, rows 6 floats apart */
    float sparse[12] = { 0 };
    [a readBytes:sparse strideBytes:strides];
    CHECK(sparse[2] == 2 && sparse[6] == 4, "and with strides");
    MPSNDArray *s = [[MPSNDArray alloc] initWithDevice:dev scalar:2.5];
    float sv = 0;
    [s readBytes:&sv strideBytes:NULL];
    CHECK(sv == 2.5f && [[d getShape] isEqual:(@[ @2, @3 ])], "a scalar array, and the shape back");
}


/* ---------------- MetalFX ---------------- */
static void metalfx(void) {
    /* a vertical edge 4x4 -> 8x8: flat sides stay flat, the edge stays sharp and in range */
    id<MTLTexture> src = texture(4, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : (x >= 2 ? 0.9f : 0.1f); });
    id<MTLTexture> dst = texture(8, 8, 4, nil);
    MTLFXSpatialScalerDescriptor *sd = [MTLFXSpatialScalerDescriptor new];
    sd.inputWidth = 4; sd.inputHeight = 4; sd.outputWidth = 8; sd.outputHeight = 8;
    sd.colorTextureFormat = MTLPixelFormatRGBA32Float; sd.outputTextureFormat = MTLPixelFormatRGBA32Float;
    sd.colorProcessingMode = MTLFXSpatialScalerColorProcessingModeLinear;
    id<MTLFXSpatialScaler> spatial = [sd newSpatialScalerWithDevice:dev];
    spatial.colorTexture = src; spatial.outputTexture = dst;
    run(^(id<MTLCommandBuffer> cb) { [spatial encodeToCommandBuffer:cb]; });
    CHECK([MTLFXSpatialScalerDescriptor supportsDevice:dev] && spatial.outputWidth == 8 && spatial.inputContentWidth == 4, "a spatial scaler");
    CHECK(near(px(dst, 0, 4, 0), 0.1, 1e-3) && near(px(dst, 7, 4, 0), 0.9, 1e-3), "flat sides stay flat (%.3f, %.3f)", px(dst, 0, 4, 0), px(dst, 7, 4, 0));
    BOOL monotone = YES, inRange = YES;
    for (NSUInteger x = 1; x < 8; x++) monotone &= px(dst, x, 4, 0) >= px(dst, x - 1, 4, 0) - 0.05f;   /* the halo dips a little */
    for (NSUInteger x = 0; x < 8; x++) inRange &= px(dst, x, 4, 0) >= 0.05f && px(dst, x, 4, 0) <= 0.95f;   /* sharpening may halo a little */
    CHECK(monotone && inRange && px(dst, 3, 4, 0) < 0.3 && px(dst, 4, 4, 0) > 0.7, "the edge stays sharp, without ringing beyond a slight sharpening halo (%.3f | %.3f)", px(dst, 3, 4, 0), px(dst, 4, 4, 0));

    /* temporal: four jittered frames of a static scene converge; a reset starts over */
    MTLFXTemporalScalerDescriptor *td = [MTLFXTemporalScalerDescriptor new];
    td.inputWidth = 4; td.inputHeight = 4; td.outputWidth = 8; td.outputHeight = 8;
    td.colorTextureFormat = MTLPixelFormatRGBA32Float; td.outputTextureFormat = MTLPixelFormatRGBA32Float; td.motionTextureFormat = MTLPixelFormatRG32Float;
    id<MTLFXTemporalScaler> temporal = [td newTemporalScalerWithDevice:dev];
    id<MTLTexture> flat = texture(4, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return c == 3 ? 1 : 0.5f; });
    id<MTLTexture> still = texture(4, 4, 2, nil), tout = texture(8, 8, 4, nil);
    MTLTextureDescriptor *md = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRG32Float width:4 height:4 mipmapped:NO];
    still = [dev newTextureWithDescriptor:md];
    float zeros[32] = { 0 };
    [still replaceRegion:MTLRegionMake2D(0, 0, 4, 4) mipmapLevel:0 withBytes:zeros bytesPerRow:32];
    temporal.colorTexture = flat; temporal.motionTexture = still; temporal.outputTexture = tout;
    float jit[4][2] = { { 0.25f, -0.25f }, { -0.25f, 0.25f }, { 0.25f, 0.25f }, { -0.25f, -0.25f } };
    for (int f = 0; f < 4; f++) {
        temporal.jitterOffsetX = jit[f][0]; temporal.jitterOffsetY = jit[f][1];
        run(^(id<MTLCommandBuffer> cb) { [temporal encodeToCommandBuffer:cb]; });
    }
    CHECK(near(px(tout, 3, 3, 0), 0.5, 1e-3), "a temporal scaler keeps a static scene (%.3f)", px(tout, 3, 3, 0));
    id<MTLTexture> white = texture(4, 4, 4, ^float(NSUInteger x, NSUInteger y, int c) { return 1; });
    temporal.colorTexture = white;
    run(^(id<MTLCommandBuffer> cb) { [temporal encodeToCommandBuffer:cb]; });
    float blended = px(tout, 3, 3, 0);
    temporal.reset = YES;
    run(^(id<MTLCommandBuffer> cb) { [temporal encodeToCommandBuffer:cb]; });
    CHECK(blended > 0.5 && blended <= 1 && near(px(tout, 3, 3, 0), 1, 1e-3) && !temporal.reset,
          "history is clamped to the new frame, and a reset starts over (%.3f, %.3f)", blended, px(tout, 3, 3, 0));
    CHECK([dev newFence] != nil, "a fence");
}

int main(void) {
    @autoreleasepool {
        dev = MTLCreateSystemDefaultDevice();
        queue = [dev newCommandQueue];
        CHECK(MPSSupportsMTLDevice(dev), "MPS supports the device");
        images();
        matrices();
        ndarrays();
        graph_ops();
        graph_gradients();
        graph_training();
        metalfx();
        printf("mps: %d/%d passed\n", checks - failures, checks);
    }
    return failures ? 1 : 0;
}
