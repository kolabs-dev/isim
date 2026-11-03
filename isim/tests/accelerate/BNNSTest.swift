// BNNS from Swift (issue #823): the BNNS namespace over isim's C BNNS (issue #808): shapes and descriptors, layers with
// their backward applies, the direct functions, the optimizers, the random generator and nearest neighbors.
import Foundation
import Accelerate

func bnnsSwiftChecks() {
    // shapes and descriptors
    let s: BNNS.Shape = [3, 2]
    check(s.rank == 2 && s.size.0 == 3 && s.size.1 == 2 && s.layout == BNNSDataLayoutRowMajorMatrix && s.batchStride == 6,
          "BNNS.Shape from an array literal")
    check(BNNS.Shape.tensor3DFirstMajor(2, 3, 4).batchStride == 24 && BNNS.Shape.vector(5, stride: 2).batchStride == 10
          && BNNS.DataLayout.tensor4DLastMajor.rank == 4 && BNNS.DataLayout.allCases.count == 21, "BNNS.Shape.batchStride, DataLayout")
    let x = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3] as [Float], shape: .vector(3))
    check(x.data_type == BNNSDataTypeFloat32 && x.dataSize == 12 && x.makeArray(of: Float.self) == [1, 2, 3]
          && x.shape.batchStride == 3, "BNNSNDArrayDescriptor.allocate(initializingFrom:), makeArray, dataSize, shape")
    let filled = BNNSNDArrayDescriptor.allocate(repeating: Int32(7), shape: .matrixRowMajor(2, 2))
    check(filled.makeArray(of: Int32.self) == [7, 7, 7, 7] && Int32.bnnsDataType == .int32 && Float16.bnnsDataType == .float16,
          "allocate(repeating:), BNNSScalar")
    var fp = BNNSFilterParameters(options: .useClientPointer, threadCount: 2, allocator: nil, deallocator: nil)
    check(fp.options.contains(.useClientPointer) && fp.threadCount == 2, "BNNSFilterParameters(options:threadCount:...)")
    fp.options = []

    // a fully connected layer: apply and backward
    let w = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 0, -1, 2, 1, 0] as [Float], shape: .matrixRowMajor(3, 2))
    let b = BNNSNDArrayDescriptor.allocate(initializingFrom: [5, -1] as [Float], shape: .vector(2))
    let fin = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3, -1, 0, 1] as [Float], shape: .vector(3), batchSize: 2)
    let fout = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(2), batchSize: 2)
    if let fc = BNNS.FullyConnectedLayer(input: fin, output: fout, weights: w, bias: b, activation: .rectifiedLinear) {
        try? fc.apply(batchSize: 2, input: fin, output: fout)
        check(fout.makeArray(of: Float.self, batchSize: 2) == [3, 3, 3, 0], "BNNS.FullyConnectedLayer.apply (batch, ReLU)")
    } else { check(false, "BNNS.FullyConnectedLayer") }
    if let lin = BNNS.FullyConnectedLayer(input: x, output: fout, weights: w, bias: nil, activation: .identity) {
        let one = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(2))
        try? lin.apply(batchSize: 1, input: x, output: one)
        let dy = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2] as [Float], shape: .vector(2))
        let dx = BNNSNDArrayDescriptor.allocate(repeating: Float(0), shape: .vector(3))
        let dw = BNNSNDArrayDescriptor.allocate(repeating: Float(0), shape: .matrixRowMajor(3, 2))
        try? lin.applyBackward(batchSize: 1, input: x, output: one, outputGradient: dy, generatingInputGradient: dx, generatingWeightsGradient: dw)
        check(dx.makeArray(of: Float.self) == [5, 2, -1] && dw.makeArray(of: Float.self) == [1, 2, 3, 2, 4, 6],
              "BNNS.FullyConnectedLayer.applyBackward: input and weight gradients")
    } else { check(false, "BNNS.FullyConnectedLayer (linear)") }

    // convolution and pooling
    let img = BNNSNDArrayDescriptor.allocate(initializingFrom: (1...9).map { Float($0) }, shape: .imageCHW(3, 3, 1))
    let k = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 0, 0, -1] as [Float], shape: .convolutionWeightsOIHW(2, 2, 1, 1))
    let co = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .imageCHW(2, 2, 1))
    let conv = BNNS.ConvolutionLayer(type: .standard, input: img, weights: k, output: co, bias: nil, padding: .zero, activation: .identity,
                                     groupCount: 1, stride: (1, 1), dilationStride: (1, 1))
    try? conv?.apply(batchSize: 1, input: img, output: co)
    check(conv != nil && co.makeArray(of: Float.self) == [-4, -4, -4, -4], "BNNS.ConvolutionLayer")
    let pin = BNNSNDArrayDescriptor.allocate(initializingFrom: (0..<16).map { Float($0) }, shape: .imageCHW(4, 4, 1))
    let po = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .imageCHW(2, 2, 1))
    let pool = BNNS.PoolingLayer(type: .max(), input: pin, output: po, bias: nil, activation: .identity, kernelSize: (2, 2), stride: (2, 2),
                                 padding: .zero)
    try? pool?.apply(batchSize: 1, input: pin, output: po)
    check(pool != nil && po.makeArray(of: Float.self) == [5, 7, 13, 15], "BNNS.PoolingLayer (max)")
    check(BNNS.PoolingLayer(type: .unMax(), input: pin, output: po, bias: nil, activation: .identity, kernelSize: (2, 2), stride: (2, 2),
                            padding: .zero) == nil, "BNNS.PoolingLayer: unpooling is not in isim (nil)")

    // activation layer with axes, normalization
    let av = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3, 1, 2, 3] as [Float], shape: .matrixRowMajor(3, 2))
    let ao = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .matrixRowMajor(3, 2))
    let sm = BNNS.ActivationLayer(function: .softmax, axes: [0], input: av, output: ao)
    try? sm?.apply(batchSize: 1, input: av, output: ao)
    let e = [exp(1.0), exp(2.0), exp(3.0)], es = e.reduce(0, +)
    check(close(ao.makeArray(of: Float.self) ?? [], [e[0] / es, e[1] / es, e[2] / es, e[0] / es, e[1] / es, e[2] / es], 1e-6),
          "BNNS.ActivationLayer: softmax over an axis")
    let neg = BNNSNDArrayDescriptor.allocate(initializingFrom: [-2, 0.5, 3] as [Float], shape: .vector(3))
    let o3 = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(3))
    try? BNNS.applyActivation(activation: .leakyRectifiedLinear(alpha: 0.5), input: neg, output: o3, batchSize: 1)
    check(o3.makeArray(of: Float.self) == [-1, 0.5, 3], "BNNS.applyActivation")
    let nin = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 3, 5, 7] as [Float], shape: .vector(1), batchSize: 4)
    let nout = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(1), batchSize: 4)
    let gamma = BNNSNDArrayDescriptor.allocate(initializingFrom: [2] as [Float], shape: .vector(1))
    let beta = BNNSNDArrayDescriptor.allocate(initializingFrom: [1] as [Float], shape: .vector(1))
    let norm = BNNS.NormalizationLayer(type: .batch(movingMean: nil, movingVariance: nil), input: nin, output: nout, beta: beta, gamma: gamma,
                                       epsilon: 0, activation: .identity)
    try? norm?.apply(batchSize: 4, input: nin, output: nout, for: .training)
    let r5 = Float(5).squareRoot()
    check(close(nout.makeArray(of: Float.self, batchSize: 4) ?? [], [Double(1 - 6 / r5), Double(1 - 2 / r5), Double(1 + 2 / r5), Double(1 + 6 / r5)], 1e-6),
          "BNNS.NormalizationLayer (batch, training)")

    // arithmetic layers and the matrix product layer
    let c10 = BNNSNDArrayDescriptor.allocate(initializingFrom: [10] as [Float], shape: .vector(1))
    let aout = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(3))
    let mul = BNNS.BinaryArithmeticLayer(inputA: x, inputADescriptorType: .sample, inputB: c10, inputBDescriptorType: .constant, output: aout,
                                         outputDescriptorType: .sample, function: .multiply)
    try? mul?.apply(batchSize: 1, inputA: x, inputB: c10, output: aout)
    check(aout.makeArray(of: Float.self) == [10, 20, 30], "BNNS.BinaryArithmeticLayer: multiply by a constant")
    let sq = BNNS.UnaryArithmeticLayer(input: x, inputDescriptorType: .sample, output: aout, outputDescriptorType: .sample, function: .square)
    try? sq?.apply(batchSize: 1, input: x, output: aout)
    check(aout.makeArray(of: Float.self) == [1, 4, 9] && BNNS.ArithmeticUnaryFunction.allCases.count == 27, "BNNS.UnaryArithmeticLayer: square")
    let ma = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3, 4] as [Float], shape: .matrixFirstMajor(2, 2))
    let mo = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .matrixFirstMajor(2, 2))
    let bmm = BNNS.BroadcastMatrixMultiplyLayer(inputA: ma, transposed: false, isWeights: false, inputB: ma, transposed: false, isWeights: false,
                                                output: mo, alpha: 1, accumulatesToOutput: false, isQuadratic: false)
    try? bmm?.apply(batchSize: 1, inputA: ma, inputB: ma, output: mo)
    check(mo.makeArray(of: Float.self) == [7, 10, 15, 22], "BNNS.BroadcastMatrixMultiplyLayer")

    // loss
    let logits = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3] as [Float], shape: .vector(3))
    let labels = BNNSNDArrayDescriptor.allocate(initializingFrom: [0, 0, 1] as [Float], shape: .vector(3))
    let lossOut = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(1))
    let lossGrad = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(3))
    let loss = BNNS.LossLayer(input: logits, output: lossOut, lossFunction: .softmaxCrossEntropy(labelSmoothing: 0), lossReduction: .sum)
    try? loss?.apply(batchSize: 1, input: logits, labels: labels, output: lossOut, generatingInputGradient: lossGrad)
    check(close(lossOut.makeArray(of: Float.self) ?? [], [-log(e[2] / es)], 1e-5)
          && close(lossGrad.makeArray(of: Float.self) ?? [], [e[0] / es, e[1] / es, e[2] / es - 1], 1e-5), "BNNS.LossLayer: softmax cross entropy")

    // fused fully connected and batch norm
    let fw = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2] as [Float], shape: .matrixRowMajor(1, 2))
    let fx = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 3] as [Float], shape: .vector(1), batchSize: 2)
    let fy = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(2), batchSize: 2)
    let fused = BNNS.FusedParametersLayer(input: fx, output: fy, fusedLayerParameters: [
        BNNS.FusedFullyConnectedParameters(weights: fw, bias: nil),
        BNNS.FusedNormalizationParameters(type: .batch(movingMean: nil, movingVariance: nil), epsilon: 0, activation: .identity)])
    try? fused?.apply(batchSize: 2, input: fx, output: fy, for: .training)
    check(close(fy.makeArray(of: Float.self, batchSize: 2) ?? [], [-1, -1, 1, 1], 1e-5), "BNNS.FusedParametersLayer: fully connected and batch norm")

    // direct functions
    let m23 = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2, 3, 4, 5, 6] as [Float], shape: .matrixLastMajor(3, 2))
    let m32 = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .matrixLastMajor(2, 3))
    try? BNNS.transpose(input: m23, output: m32, firstTransposeAxis: 0, secondTransposeAxis: 1)
    check(m32.makeArray(of: Float.self) == [1, 4, 2, 5, 3, 6], "BNNS.transpose")
    let half = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float16.self, shape: .vector(3))
    try? BNNS.copy(x, to: half)
    check(half.makeArray(of: Float16.self) == [1, 2, 3], "BNNS.copy: Float to Float16")
    try? BNNS.applyMatrixMultiplication(inputA: ma, transposed: true, inputB: ma, transposed: false, output: mo, alpha: 1, workspace: nil)
    check(mo.makeArray(of: Float.self) == [10, 14, 14, 20], "BNNS.applyMatrixMultiplication (transposed A)")
    let sum = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .matrixLastMajor(1, 2))
    try? BNNS.applyReduction(.sum, input: m23, output: sum, weights: nil)
    check(sum.makeArray(of: Float.self) == [6, 15], "BNNS.applyReduction")
    let idx = BNNSNDArrayDescriptor.allocate(initializingFrom: [2, 0] as [Int32], shape: .vector(2))
    let g = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .matrixLastMajor(2, 2))
    try? BNNS.gather(input: m23, indices: idx, output: g, axis: 0)
    check(g.makeArray(of: Float.self) == [3, 1, 6, 4], "BNNS.gather")
    let cmp = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Bool.self, shape: .vector(3))
    try? BNNS.compare(x, labels, using: .greater, output: cmp)
    check(cmp.makeArray(of: Bool.self) == [true, true, true], "BNNS.compare")
    let n = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(1))
    let v34 = BNNSNDArrayDescriptor.allocate(initializingFrom: [3, 4] as [Float], shape: .vector(2))
    try? BNNS.computeNorm(input: v34, output: n)
    check(n.makeArray(of: Float.self) == [5], "BNNS.computeNorm")
    let clipped = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(2))
    try? BNNS.clipByNorm(threshold: 1, input: v34, output: clipped)
    check(close(clipped.makeArray(of: Float.self) ?? [], [0.6, 0.8], 1e-6), "BNNS.clipByNorm")
    let q8 = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Int8.self, shape: .vector(3))
    let sc = BNNSNDArrayDescriptor.allocate(initializingFrom: [10] as [Float], shape: .vector(1))
    try? BNNS.quantize(batchSize: 1, input: x, output: q8, scale: sc, bias: nil)
    check(q8.makeArray(of: Int8.self) == [10, 20, 30], "BNNS.quantize")
    let best = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(1))
    let bestIdx = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Int32.self, shape: .vector(1))
    try? BNNS.applyTopK(k: 1, input: x, bestValues: best, bestIndices: bestIdx, axis: 0, batchSize: 1)
    check(best.makeArray(of: Float.self) == [3] && bestIdx.makeArray(of: Int32.self) == [2], "BNNS.applyTopK")

    // optimizers
    let pw = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 2] as [Float], shape: .vector(2))
    let pg = BNNSNDArrayDescriptor.allocate(initializingFrom: [0.5, -1] as [Float], shape: .vector(2))
    let acc = BNNSNDArrayDescriptor.allocate(repeating: Float(0), shape: .vector(2))
    let sgd = BNNS.SGDMomentumOptimizer(learningRate: 0.1, momentum: 0.9, gradientScale: 1, regularizationScale: 0, gradientClipping: .none,
                                        regularizationFunction: BNNSOptimizerRegularizationNone, sgdMomentumVariant: BNNSSGDMomentumVariant0)
    try? sgd.step(parameters: [pw], gradients: [pg], accumulators: [acc])
    check(close(pw.makeArray(of: Float.self) ?? [], [0.95, 2.1], 1e-6) && sgd.accumulatorCountMultiplier == 1, "BNNS.SGDMomentumOptimizer.step")
    let aw = BNNSNDArrayDescriptor.allocate(initializingFrom: [1, 1] as [Float], shape: .vector(2))
    let ag = BNNSNDArrayDescriptor.allocate(initializingFrom: [0.3, -2] as [Float], shape: .vector(2))
    let m1 = BNNSNDArrayDescriptor.allocate(repeating: Float(0), shape: .vector(2)), m2 = BNNSNDArrayDescriptor.allocate(repeating: Float(0), shape: .vector(2))
    let adam = BNNS.AdamOptimizer(learningRate: 0.01, timeStep: 1, gradientScale: 1, regularizationScale: 0, gradientClipping: .none,
                                  regularizationFunction: BNNSOptimizerRegularizationNone)
    try? adam.step(parameters: [aw], gradients: [ag], accumulators: [m1, m2])
    check(close(aw.makeArray(of: Float.self) ?? [], [0.99, 1.01], 1e-5) && adam.accumulatorCountMultiplier == 2, "BNNS.AdamOptimizer.step")
    var rms = BNNS.RMSPropOptimizer(centered: true, momentum: 0.5, gradientScale: 1, regularizationScale: 0, gradientClipping: .byValue(bounds: -1...1),
                                    regularizationFunction: BNNSOptimizerRegularizationNone)
    rms.learningRate = 0.05
    check(rms.accumulatorCountMultiplier == 3 && rms.gradientBounds == -1...1 && rms.learningRate == 0.05, "BNNS.RMSPropOptimizer properties")

    // random generator, nearest neighbors, BNNSTensor, PixelBuffer.withBNNSTensor
    if let rg = BNNS.RandomGenerator(method: .aesCtr, seed: 42) {
        let st = rg.state
        let r1 = BNNSNDArrayDescriptor.allocate(randomUniformUsing: rg, range: Float(-1)...Float(1), shape: .vector(100))
        rg.state = st
        let r2 = BNNSNDArrayDescriptor.allocate(randomUniformUsing: rg, range: Float(-1)...Float(1), shape: .vector(100))
        let a1 = r1?.makeArray(of: Float.self) ?? [], a2 = r2?.makeArray(of: Float.self) ?? []
        check(a1.count == 100 && a1 == a2 && a1.allSatisfy { $0 >= -1 && $0 <= 1 }, "BNNS.RandomGenerator: seeded, replayed through its state")
    } else { check(false, "BNNS.RandomGenerator") }
    let knn = BNNS.NearestNeighbors(capacity: 4, dimensionCount: 2, neighborCount: 1, dataType: .float)
    knn.append(samples: BNNSNDArrayDescriptor.allocate(initializingFrom: [0, 0, 1, 0, 5, 5] as [Float], shape: .matrixRowMajor(2, 3)))
    let ni = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Int32.self, shape: .vector(1))
    let nd = BNNSNDArrayDescriptor.allocateUninitialized(scalarType: Float.self, shape: .vector(1))
    knn.apply(index: 0, outputIndices: ni, outputDistances: nd)
    check(ni.makeArray(of: Int32.self) == [1] && nd.makeArray(of: Float.self) == [1], "BNNS.NearestNeighbors")
    let t = BNNSTensor.allocate(initializingFrom: [1, 2, 3, 4, 5, 6] as [Float], shape: [2, 3], stride: [])
    check(t.count == 6 && t.rank == 2 && t.stride.0 == 3 && t.makeArray(of: Float.self) == [1, 2, 3, 4, 5, 6], "BNNSTensor.allocate, makeArray")
    t.deallocate()
    let pb = vImage.PixelBuffer<vImage.Interleaved8x4>(width: 3, height: 2)
    pb.withBNNSTensor { tensor in
        check(tensor.rank == 3 && tensor.shape.0 == 2 && tensor.shape.1 == 3 && tensor.shape.2 == 4 && tensor.data_type == .uint8,
              "vImage.PixelBuffer.withBNNSTensor")
    }
}
