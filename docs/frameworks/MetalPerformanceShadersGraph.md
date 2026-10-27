# MetalPerformanceShadersGraph

<!-- generated:header (isim/tools/coverage-summary.py; do not edit by hand) -->
<!-- /generated:header -->

**Area:** [GPU](../COVERAGE.md#gpu) · **Apple:** [MetalPerformanceShadersGraph](https://developer.apple.com/documentation/metalperformanceshadersgraph) · **Issues:** [`area:gpu`](https://github.com/kolabs-dev/isim/issues?q=is%3Aissue+is%3Aopen+label%3Aarea%3Agpu)

## How isim implements it

- **Approach:** isim's own graph evaluator on the CPU (`isim/frameworks/MetalPerformanceShadersGraph`).
  - Each operation evaluates its inputs into values, in double precision, stored in its output's data type: integers
    truncated, booleans 0 or 1.
  - A run evaluates each operation it needs once. Variables keep their values between runs. A run's assignments
    (`assign`, `applyStochasticGradientDescent`) apply at its end, after its target tensors are computed from the old
    values.
  - **Gradients** (`gradients(of:with:)`) are symbolic, reverse mode. Each differentiable operation adds the operations
    of its inputs' gradients; gradients of broadcast operands are summed back to their shapes.
  - Compiling keeps the graph, its feeds (in the order the placeholders were made) and its targets. `runAsync` runs at
    once, then calls the handlers.
- **Objective-C / C interface:** Apple's headers in `isim/sdk-src/Frameworks/MetalPerformanceShadersGraph`, with
  Apple's Swift names; Swift imports them.
- **Versus Apple's Simulator:**
  - The results are double-precision evaluations, not the GPU's; float16 is rounded only when stored.
  - Control flow, RNNs, FFTs, quantization, scatter, image resizing, sparse tensors and the other operation families
    below are not implemented yet.

## API

| API / feature | Status | iOS | Notes |
|---|---|---|---|
| `MPSGraph` (`run(feeds:targetTensors:targetOperations:)`, with a command queue, into a results dictionary, `runAsync`, `options`, `placeholderTensors`), `MPSGraphExecutionDescriptor` | ✅ | ≤17 | adapted (see above); tested (MPSTest, test_mps; HelloMetal, test_metal) |
| `MPSGraphTensor`, `MPSGraphOperation`, `MPSGraphShapedType`, `MPSGraphDevice` | ✅ | ≤17 | adapted: shapes inferred where the inputs' are known; tested (MPSTest) |
| `MPSGraphTensorData` (from data, Metal buffers, `MPSMatrix`, `MPSVector`, `MPSNDArray`, image batches; `mpsndarray()`) | ✅ | ≤17 | adapted: row-major, the last dimension fastest; image batches as N x H x W x C float32; tested (MPSTest) |
| `compile(with:feeds:targetTensors:targetOperations:compilationDescriptor:)`, `MPSGraphExecutable` (`run`, `runAsync`, `specialize`), `MPSGraphCompilationDescriptor`, `MPSGraphExecutableExecutionDescriptor` | ✅ | ≤17 | adapted: nothing is specialized; tested (MPSTest) |
| Placeholders, constants, variables (`variable(with:)`, `variableFromTensor`, `read`, `assign`) | ✅ | ≤17 | adapted; tested (MPSTest; HelloMetal) |
| Element-wise math: the unary operations (exponents, logarithms, roots, trigonometric and hyperbolic functions, rounding, `erf`, tests), the binary ones (arithmetic, powers, minimum / maximum, comparisons, logical operations, `atan2`, modulo), `select`, `clamp` | ✅ | ≤17 | adapted: NumPy broadcasting; tested (MPSTest) |
| `matrixMultiplication(primary:secondary:)` | ✅ | ≤17 | adapted: batched, the batch dimensions broadcast; tested (MPSTest; HelloMetal) |
| Reductions (sum, maximum, minimum, product, arg-maximum / minimum, and, or), `mean`, `variance`, `normalize` | ✅ | ≤17 | adapted: the reduced axes kept with length 1; tested (MPSTest) |
| Activations: `reLU`, `sigmoid`, `softMax`, `leakyReLU` and their gradient operations | ✅ | ≤17 | adapted; tested (MPSTest) |
| Shapes: `reshape`, `transpose`, `sliceTensor`, `concatTensor(s)`, `broadcast`, `shapeOf`, `cast`, `expandDims`, `squeeze`, `flatten2D`, `tileTensor`, `padTensor`, `reverse`, `stack`, `split` | ✅ | ≤17 | adapted: padding by constant, zero, reflect, symmetric, clamp to edge and periodic; tested (MPSTest) |
| `softMaxCrossEntropy` and its gradient, `MPSGraphLossReductionType` | ✅ | ≤17 | adapted; tested (MPSTest) |
| `gradients(of:with:)` | ✅ | ≤17 | adapted: through the arithmetic, matrix, reduction, activation, shape, loss, convolution, pooling, gather, top-K and cumulative-sum operations; tested against finite differences (MPSTest) |
| `stochasticGradientDescent`, `applyStochasticGradientDescent`, `adam` | ✅ | ≤17 | adapted; tested (MPSTest: a linear regression trained with SGD) |
| `convolution2D`, `MPSGraphConvolution2DOpDescriptor`, `maxPooling2D`, `avgPooling2D`, `MPSGraphPooling2DOpDescriptor` | ✅ | ≤17 | adapted: NCHW / NHWC sources, OIHW / HWIO weights, strides, dilation, groups, explicit / valid / same padding; tested (MPSTest) |
| `gather`, `gatherAlongAxis`, `oneHot`, `topK`, `sort`, `argSort`, the cumulative operations, `randomUniformTensor`, `dropout` | 🟡 | ≤17 | adapted: `gather` without batch dimensions; tested (MPSTest) |
| Control flow (`if`, `while`, `for`), RNN / LSTM / GRU, FFTs, quantization, scatter, image resizing and sampling, sparse tensors, `stencil`, `scaledDotProductAttention`, the other pooling and convolution forms (3-D, transposed, gradients), bitwise operations, complex numbers | ❌ | ≤17 | not yet |

## Not yet in isim

<!-- generated:missing (isim/tools/api-coverage.py, coverage-summary.py; do not edit by hand) -->
<!-- /generated:missing -->
