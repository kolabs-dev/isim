# MetalPerformanceShaders

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [GPU](../COVERAGE.md#gpu) · **Apple:** [MetalPerformanceShaders](https://developer.apple.com/documentation/metalperformanceshaders) · **Issues:** [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

## How isim implements it

- **Approach:** isim's own kernels, on the CPU (`isim/frameworks/MetalPerformanceShaders`), like isim's
  [Metal](Metal.md).
  - Encoding a kernel adds its work to isim's Metal command buffer, so it runs in commit order with the buffer's
    other work.
  - Image kernels read and write textures through their bytes, as float RGBA. Formats: the 8-bit, 16-bit and 32-bit
    unorm, snorm, float and integer formats; BGRA; sRGB (linearized).
  - Matrix products go through isim's [Accelerate](Accelerate.md) BLAS. The decompositions and solvers are isim's own,
    in double precision.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/MetalPerformanceShaders`; Swift imports
  them (there is no Swift overlay).
- **Versus Apple's Simulator:** the results match the definitions of the kernels, not the GPU's bit patterns.
  - Gaussian blurs use a kernel truncated at 3σ.
  - Scaling: bilinear, or Lanczos (a = 3) widened when downscaling.
  - Temporary images, matrices and arrays are ordinary ones (no shared heap).
  - The CNN and RNN layers, ray intersection, SVGF and the other image kernels listed below are not implemented yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MPSKernel`, `MPSSupportsMTLDevice`, `MPSGetPreferredDevice`, `MPSKernelOptions`, `MPSRectNoClip` and the core types (`MPSOffset`, `MPSRegion`, `MPSScaleTransform`, `MPSDataType`, …) | ✅ | ≤17 | adapted; tested (MPSTest, test_mps) |
| `MPSUnaryImageKernel`, `MPSBinaryImageKernel` (offsets, clip rectangles, edge modes zero / clamp / mirror / mirror with edge, in-place encoding, source regions) | ✅ | ≤17 | adapted: every kernel can run in place (isim filters a copy of the source); tested (MPSTest) |
| `MPSImageGaussianBlur`, `MPSImageBox`, `MPSImageTent`, `MPSImageConvolution`, `MPSImageMedian`, `MPSImageLaplacian`, `MPSImageSobel` | ✅ | ≤17 | adapted: separable blurs; tested (MPSTest; HelloMetal, test_metal) |
| `MPSImageAreaMax` / `AreaMin`, `MPSImageDilate` / `Erode` | ✅ | ≤17 | adapted; tested (MPSTest) |
| `MPSImageThresholdBinary`, `BinaryInverse`, `Truncate`, `ToZero`, `ToZeroInverse` | ✅ | ≤17 | adapted: of the luminance (Rec. 601 weights by default); tested (MPSTest) |
| `MPSImageScale`, `MPSImageBilinearScale`, `MPSImageLanczosScale`, `MPSImageConversion`, `MPSImageTranspose` | ✅ | ≤17 | adapted: the conversion's alpha types and background color; its color spaces (`CGColorConversionInfo`) are not applied; tested (MPSTest; HelloMetal) |
| `MPSImageArithmetic` (`MPSImageAdd`, `Subtract`, `Multiply`, `Divide`: scales, bias, strides, clamping) | ✅ | ≤17 | adapted: a stride of 0 broadcasts; tested (MPSTest) |
| `MPSImageStatisticsMinAndMax`, `MeanAndVariance`, `Mean`, `MPSImageIntegral`, `IntegralOfSquares`, the row and column reductions (`MPSImageReduceRowMax` …) | ✅ | ≤17 | adapted; tested (MPSTest) |
| `MPSImageHistogram`, `MPSImageHistogramEqualization` | ✅ | ≤17 | adapted: uint32 counts per channel; equalization by the normalized cumulative histogram; tested (MPSTest) |
| `MPSImage`, `MPSImageDescriptor`, `MPSTemporaryImage`, `MPSImageAllocator` (feature channels in 2-D arrays, batches, sub-images, `readBytes` / `writeBytes` in HWC and CHW) | ✅ | ≤17 | adapted: sub-images and batch images are texture views sharing the image's memory; tested (MPSTest) |
| `MPSMatrix`, `MPSVector` and their descriptors, `MPSTemporaryMatrix`, `MPSTemporaryVector` | ✅ | ≤17 | adapted: Metal buffers, batches `matrixBytes` apart; tested (MPSTest) |
| `MPSMatrixMultiplication`, `MPSMatrixVectorMultiplication`, `MPSMatrixSum` | ✅ | ≤17 | adapted: float32 / float16 through BLAS; transposes, alpha / beta, origins, batches; tested (MPSTest; HelloMetal) |
| `MPSMatrixSoftMax`, `MPSMatrixLogSoftMax`, `MPSMatrixFindTopK`, `MPSMatrixNeuron` (the `MPSCNNNeuronType` activations) | ✅ | ≤17 | adapted; tested (MPSTest) |
| `MPSMatrixDecompositionLU`, `MPSMatrixDecompositionCholesky`, `MPSMatrixSolveTriangular`, `MPSMatrixSolveLU`, `MPSMatrixSolveCholesky` | ✅ | ≤17 | adapted: partial pivoting; status buffers; tested (MPSTest) |
| `MPSNDArray`, `MPSNDArrayDescriptor`, `MPSTemporaryNDArray` (shapes, strided reads and writes, buffers, import / export) | 🟡 | ≤17 | adapted: dimension slicing and transposition change the descriptor's lengths but not how an array is read; tested (MPSTest) |
| The CNN and RNN layers (`MPSCNN*`, `MPSNN*`, `MPSRNN*`), the `MPSNDArray` kernels, `MPSMatrixRandom`, `MPSMatrixBatchNormalization`, `MPSMatrixFullyConnected` | ❌ | ≤17 | not yet |
| Image pyramids, `MPSImageGuidedFilter`, `MPSImageCanny`, `MPSImageEDLines`, `MPSImageFindKeypoints`, `MPSImageEuclideanDistanceTransform`, `MPSImageHistogramSpecification` | ❌ | ≤17 | not yet |
| Ray intersection (`MPSRayIntersector`, acceleration structures), `MPSSVGF`, `MPSTemporalAA` | ❌ | ≤17 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
