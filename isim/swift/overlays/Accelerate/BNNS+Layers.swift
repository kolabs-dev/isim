// isim Accelerate overlay: BNNS's layer classes (issue #823), each a BNNSFilter from isim's C BNNS (issue #808).

// MARK: - apply helpers

func _bnnsData(_ d: BNNSNDArrayDescriptor) throws -> UnsafeMutableRawPointer {
    guard let p = d.data else { throw BNNS.Error.arrayDescriptorInvalidData }
    return p
}
func _bnnsApply(_ f: BNNSFilter, _ batch: Int, _ i: BNNSNDArrayDescriptor, _ o: BNNSNDArrayDescriptor) throws {
    try _bnnsCheck(BNNSFilterApplyBatch(f, batch, try _bnnsData(i), i.shape.batchStride, try _bnnsData(o), o.shape.batchStride))
}
func _bnnsBackward(_ f: BNNSFilter, _ batch: Int, _ input: BNNSNDArrayDescriptor, _ output: BNNSNDArrayDescriptor,
                   _ outputGradient: BNNSNDArrayDescriptor, _ inputGradient: BNNSNDArrayDescriptor?,
                   _ weightsGradient: BNNSNDArrayDescriptor? = nil, _ biasGradient: BNNSNDArrayDescriptor? = nil) throws {
    var og = outputGradient
    let r: Int32 = _bnnsWithOptional(inputGradient) { ig in
        _bnnsWithOptional(weightsGradient) { wg in
            _bnnsWithOptional(biasGradient) { bg in
                BNNSFilterApplyBackwardBatch(f, batch, input.data, input.shape.batchStride, ig, inputGradient?.shape.batchStride ?? 0,
                                             output.data, output.shape.batchStride, &og, outputGradient.shape.batchStride, wg, bg)
            }
        }
    }
    try _bnnsCheck(r)
}
func _bnnsPadding(_ p: BNNS.ConvolutionPadding) -> (x: Int, y: Int, pad: (Int, Int, Int, Int)) {
    switch p {
    case let .symmetric(x, y): return (x, y, (0, 0, 0, 0))
    case let .asymmetric(l, r, u, d): return (0, 0, (l, r, u, d))
    }
}

// MARK: - the layer classes

extension BNNS {
    public class Layer {
        final public let bnnsFilter: BNNSFilter
        init(bnnsFilter: BNNSFilter) { self.bnnsFilter = bnnsFilter }
        deinit { BNNSFilterDestroy(bnnsFilter) }
    }

    public class UnaryLayer: BNNS.Layer {
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            try _bnnsApply(bnnsFilter, batchSize, input, output)
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor) throws {
            try _bnnsBackward(bnnsFilter, batchSize, input, output, outputGradient, inputGradient)
        }
    }

    public class BinaryLayer: BNNS.Layer {
        public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            try _bnnsCheck(BNNSFilterApplyTwoInputBatch(bnnsFilter, batchSize, try _bnnsData(inputA), inputA.shape.batchStride, try _bnnsData(inputB),
                                                        inputB.shape.batchStride, try _bnnsData(output), output.shape.batchStride))
        }
        public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                  outputGradient: BNNSNDArrayDescriptor, generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                                  generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor) throws {
            var og = outputGradient, ga = inputAGradient, gb = inputBGradient
            try _bnnsCheck(BNNSFilterApplyBackwardTwoInputBatch(bnnsFilter, batchSize, inputA.data, inputA.shape.batchStride, &ga, ga.shape.batchStride,
                                                                inputB.data, inputB.shape.batchStride, &gb, gb.shape.batchStride, output.data,
                                                                output.shape.batchStride, &og, og.shape.batchStride, nil, nil))
        }
    }

    public class ActivationLayer: BNNS.UnaryLayer {
        convenience public init?(function activationFunction: BNNS.ActivationFunction, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 filterParameters: BNNSFilterParameters? = nil) {
            self.init(function: activationFunction, axes: [], input: input, output: output, filterParameters: filterParameters)
        }
    }

    public enum ConvolutionPadding {
        case symmetric(x: Int, y: Int)
        case asymmetric(left: Int, right: Int, up: Int, down: Int)
        public static var zero: BNNS.ConvolutionPadding { .symmetric(x: 0, y: 0) }
    }
    public enum ConvolutionType: Hashable {
        case standard
        case transposed
    }

    public class ConvolutionLayer: BNNS.UnaryLayer {
        convenience public init?(type convolutionType: BNNS.ConvolutionType, input: BNNSNDArrayDescriptor, weights: BNNSNDArrayDescriptor,
                                 output: BNNSNDArrayDescriptor, bias: BNNSNDArrayDescriptor?, padding: BNNS.ConvolutionPadding,
                                 activation: BNNS.ActivationFunction, groupCount: Int, stride: (x: Int, y: Int), dilationStride: (x: Int, y: Int),
                                 filterParameters: BNNSFilterParameters? = nil) {
            let pd = _bnnsPadding(padding)
            var p = BNNSLayerParametersConvolution(i_desc: input, w_desc: weights, o_desc: output, bias: bias ?? BNNSNDArrayDescriptor(),
                                                   activation: activation.bnnsActivation, x_stride: stride.x, y_stride: stride.y,
                                                   x_dilation_stride: dilationStride.x, y_dilation_stride: dilationStride.y,
                                                   x_padding: pd.x, y_padding: pd.y, groups: groupCount, pad: pd.pad)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in
                convolutionType == .transposed ? BNNSFilterCreateLayerTransposedConvolution(&p, fp) : BNNSFilterCreateLayerConvolution(&p, fp)
            }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                  generatingWeightsGradient weightsGradient: BNNSNDArrayDescriptor? = nil,
                                  generatingBiasGradient biasGradient: BNNSNDArrayDescriptor? = nil) throws {
            try _bnnsBackward(bnnsFilter, batchSize, input, output, outputGradient, inputGradient, weightsGradient, biasGradient)
        }
    }

    public class FullyConnectedLayer: BNNS.ConvolutionLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, weights: BNNSNDArrayDescriptor,
                                 bias: BNNSNDArrayDescriptor?, activation: BNNS.ActivationFunction, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersFullyConnected(i_desc: input, w_desc: weights, o_desc: output, bias: bias ?? BNNSNDArrayDescriptor(),
                                                      activation: activation.bnnsActivation)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerFullyConnected(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public enum PoolingType {
        case max(indices: UnsafeMutableBufferPointer<Int>? = nil, xDilationStride: Int = 0, yDilationStride: Int = 0)
        case unMax(indices: UnsafeMutableBufferPointer<Int>? = nil, xDilationStride: Int = 0, yDilationStride: Int = 0)
        case average(countIncludesPadding: Bool)
        case l2Norm
        case maxEx(indicesDescriptor: BNNSNDArrayDescriptor? = nil, xDilationStride: Int = 0, yDilationStride: Int = 0)
        case unMaxEx(indicesDescriptor: BNNSNDArrayDescriptor, xDilationStride: Int = 0, yDilationStride: Int = 0)
        public var bnnsPoolingFunction: BNNSPoolingFunction {
            switch self {
            case .max, .maxEx: return BNNSPoolingFunctionMax
            case .unMax, .unMaxEx: return BNNSPoolingFunctionUnMax
            case let .average(inc): return inc ? BNNSPoolingFunctionAverageCountIncludePadding : BNNSPoolingFunctionAverageCountExcludePadding
            case .l2Norm: return BNNSPoolingFunctionL2Norm
            }
        }
        var dilation: (Int, Int) {
            switch self {
            case let .max(_, x, y), let .unMax(_, x, y): return (x, y)
            case let .maxEx(_, x, y): return (x, y)
            case let .unMaxEx(_, x, y): return (x, y)
            default: return (0, 0)
            }
        }
    }

    public class PoolingLayer: BNNS.Layer {
        var poolingType: BNNS.PoolingType = .l2Norm
        convenience public init?(type poolingType: BNNS.PoolingType, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 bias: BNNSNDArrayDescriptor?, activation: BNNS.ActivationFunction, kernelSize: (width: Int, height: Int),
                                 stride: (x: Int, y: Int), padding: BNNS.ConvolutionPadding, filterParameters: BNNSFilterParameters? = nil) {
            let pd = _bnnsPadding(padding), dil = poolingType.dilation
            var p = BNNSLayerParametersPooling(i_desc: input, o_desc: output, bias: bias ?? BNNSNDArrayDescriptor(),
                                               activation: activation.bnnsActivation, pooling_function: poolingType.bnnsPoolingFunction,
                                               k_width: kernelSize.width, k_height: kernelSize.height, x_stride: stride.x, y_stride: stride.y,
                                               x_dilation_stride: dil.0, y_dilation_stride: dil.1, x_padding: pd.x, y_padding: pd.y, pad: pd.pad)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerPooling(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
            self.poolingType = poolingType
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            let i = try _bnnsData(input), o = try _bnnsData(output)
            switch poolingType {
            case let .max(indices?, _, _):
                try _bnnsCheck(BNNSPoolingFilterApplyBatch(bnnsFilter, batchSize, i, input.shape.batchStride, o, output.shape.batchStride,
                                                           indices.baseAddress, output.shape.batchStride))
            case let .maxEx(desc?, _, _):
                try _bnnsCheck(BNNSPoolingFilterApplyBatchEx(bnnsFilter, batchSize, i, input.shape.batchStride, o, output.shape.batchStride,
                                                             desc.data_type, desc.data, desc.shape.batchStride))
            default:
                try _bnnsApply(bnnsFilter, batchSize, input, output)
            }
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                  generatingBiasGradient biasGradient: BNNSNDArrayDescriptor? = nil) throws {
            try _bnnsBackward(bnnsFilter, batchSize, input, output, outputGradient, inputGradient, nil, biasGradient)
        }
    }

    public class PermuteLayer: BNNS.UnaryLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, permutation: [Int],
                                 filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersPermute(i_desc: input, o_desc: output, permutation: _bnnsTuple8(permutation))
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerPermute(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class GramLayer: BNNS.UnaryLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, alpha: Float, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersGram(alpha: alpha, i_desc: input, o_desc: output)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerGram(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class DropoutLayer: BNNS.UnaryLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, rate: Float, seed: UInt32, control: UInt8,
                                 filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersDropout(i_desc: input, o_desc: output, rate: rate, seed: seed, control: control)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerDropout(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class ResizeLayer: BNNS.UnaryLayer {
        convenience public init?(interpolationMethod: BNNS.InterpolationMethod, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 alignsCorners: Bool, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersResize(method: interpolationMethod == .linear ? BNNSInterpolationMethodLinear : BNNSInterpolationMethodNearest,
                                              i_desc: input, o_desc: output, align_corners: alignsCorners)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerResize(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public enum PaddingMode {
        case constantBitPattern(UInt32)
        case constantScalar(Float)
        case reflect
        case symmetric
        public var bnnsPaddingMode: BNNSPaddingMode {
            switch self {
            case .constantBitPattern, .constantScalar: return BNNSPaddingModeConstant
            case .reflect: return BNNSPaddingModeReflect
            case .symmetric: return BNNSPaddingModeSymmetric
            }
        }
        public var paddingBitPattern: UInt32 {
            switch self {
            case let .constantBitPattern(b): return b
            case let .constantScalar(v): return v.bitPattern
            default: return 0
            }
        }
    }

    public class PaddingLayer: BNNS.UnaryLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, mode: BNNS.PaddingMode, size: [(x: Int, y: Int)],
                                 filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersPadding()
            p.i_desc = input; p.o_desc = output; p.padding_mode = mode.bnnsPaddingMode; p.padding_value = mode.paddingBitPattern
            withUnsafeMutableBytes(of: &p.padding_size) { raw in
                let s = raw.bindMemory(to: Int.self)
                for (k, v) in size.prefix(8).enumerated() { s[2 * k] = v.x; s[2 * k + 1] = v.y }
            }
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerPadding(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class ReductionLayer: BNNS.UnaryLayer {
        convenience public init?(function reductionFunction: BNNS.ReductionFunction, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 weights: BNNSNDArrayDescriptor?, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersReduction(i_desc: input, o_desc: output, w_desc: weights ?? BNNSNDArrayDescriptor(),
                                                 reduce_func: reductionFunction.bnnsReduceFunction, epsilon: reductionFunction.epsilon)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerReduction(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                  generatingWeightsGradient weightsGradient: BNNSNDArrayDescriptor? = nil) throws {
            try _bnnsBackward(bnnsFilter, batchSize, input, output, outputGradient, inputGradient, weightsGradient)
        }
    }

    public class EmbeddingLayer: BNNS.Layer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, dictionary: BNNSNDArrayDescriptor, paddingIndex: Int,
                                 maximumNorm: Float, normType: BNNS.Norm, scalesGradientByFrequency: Bool, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersEmbedding(flags: scalesGradientByFrequency ? BNNSEmbeddingFlagScaleGradientByFrequency : BNNSEmbeddingFlags(rawValue: 0),
                                                 i_desc: input, o_desc: output, dictionary: dictionary, padding_idx: paddingIndex,
                                                 max_norm: maximumNorm, norm_type: normType.rawValue)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerEmbedding(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            try _bnnsApply(bnnsFilter, batchSize, input, output)
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingWeightsGradient weightsGradient: BNNSNDArrayDescriptor) throws {
            try _bnnsBackward(bnnsFilter, batchSize, input, output, outputGradient, nil, weightsGradient)
        }
    }

    public enum NormalizationType {
        case batch(movingMean: BNNSNDArrayDescriptor?, movingVariance: BNNSNDArrayDescriptor?)
        case instance(movingMean: BNNSNDArrayDescriptor?, movingVariance: BNNSNDArrayDescriptor?)
        case layer(normalizationAxis: Int)
        case group(groupCount: Int)
        var filterType: BNNSFilterType {
            switch self {
            case .batch: return BNNSBatchNorm
            case .instance: return BNNSInstanceNorm
            case .layer: return BNNSLayerNorm
            case .group: return BNNSGroupNorm
            }
        }
        func parameters(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, beta: BNNSNDArrayDescriptor?, gamma: BNNSNDArrayDescriptor?,
                        momentum: Float, epsilon: Float, activation: BNNS.ActivationFunction) -> BNNSLayerParametersNormalization {
            var p = BNNSLayerParametersNormalization()
            p.i_desc = input; p.o_desc = output
            p.beta_desc = beta ?? BNNSNDArrayDescriptor(); p.gamma_desc = gamma ?? BNNSNDArrayDescriptor()
            p.momentum = momentum; p.epsilon = epsilon; p.activation = activation.bnnsActivation
            switch self {
            case let .batch(m, v), let .instance(m, v):
                p.moving_mean_desc = m ?? BNNSNDArrayDescriptor(); p.moving_variance_desc = v ?? BNNSNDArrayDescriptor()
            case let .layer(axis): p.normalization_axis = axis
            case let .group(n): p.num_groups = n
            }
            return p
        }
    }

    public class NormalizationLayer: BNNS.Layer {
        convenience public init?(type normalization: BNNS.NormalizationType, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 beta: BNNSNDArrayDescriptor, gamma: BNNSNDArrayDescriptor, momentum: Float = 0, epsilon: Float,
                                 activation: BNNS.ActivationFunction, filterParameters: BNNSFilterParameters? = nil) {
            var p = normalization.parameters(input: input, output: output, beta: beta, gamma: gamma, momentum: momentum, epsilon: epsilon,
                                             activation: activation)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerNormalization(normalization.filterType, &p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, for learningPhase: BNNS.LearningPhase) throws {
            try _bnnsCheck(BNNSNormalizationFilterApplyBatch(bnnsFilter, batchSize, try _bnnsData(input), input.shape.batchStride, try _bnnsData(output),
                                                             output.shape.batchStride, learningPhase == .training))
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                  generatingBetaGradient betaGradient: BNNSNDArrayDescriptor? = nil,
                                  generatingGammaGradient gammaGradient: BNNSNDArrayDescriptor? = nil) throws {
            var ig = inputGradient, og = outputGradient
            let r: Int32 = _bnnsWithOptional(betaGradient) { bg in
                _bnnsWithOptional(gammaGradient) { gg in
                    BNNSNormalizationFilterApplyBackwardBatch(bnnsFilter, batchSize, &ig, ig.shape.batchStride, output.data, output.shape.batchStride,
                                                              &og, og.shape.batchStride, bg, gg)
                }
            }
            try _bnnsCheck(r)
        }
    }

    // MARK: arithmetic

    static func _arithmeticApply(_ f: BNNSFilter, _ batch: Int, _ inputs: [(BNNSNDArrayDescriptor, BNNS.DescriptorType)],
                                 _ output: BNNSNDArrayDescriptor) throws {
        var ptrs: [UnsafeRawPointer?] = try inputs.map { UnsafeRawPointer(try _bnnsData($0.0)) }
        var strides = inputs.map { $0.1 == .sample ? $0.0.shape.batchStride : 0 }
        let r: Int32 = ptrs.withUnsafeMutableBufferPointer { pb in
            pb.baseAddress!.withMemoryRebound(to: UnsafeRawPointer.self, capacity: pb.count) { pp in
                BNNSArithmeticFilterApplyBatch(f, batch, inputs.count, pp, &strides, output.data!, output.shape.batchStride)
            }
        }
        try _bnnsCheck(r)
    }
    static func _arithmeticBackward(_ f: BNNSFilter, _ batch: Int, _ inputs: [(BNNSNDArrayDescriptor, BNNS.DescriptorType)],
                                    _ gradients: [BNNSNDArrayDescriptor], _ output: BNNSNDArrayDescriptor, _ outputGradient: BNNSNDArrayDescriptor) throws {
        var ptrs: [UnsafeRawPointer?] = inputs.map { UnsafeRawPointer($0.0.data) }
        var strides = inputs.map { $0.1 == .sample ? $0.0.shape.batchStride : 0 }
        var grads = gradients, og = outputGradient
        var gstrides = gradients.enumerated().map { inputs[$0.offset].1 == .sample ? $0.element.shape.batchStride : 0 }
        let r: Int32 = grads.withUnsafeMutableBufferPointer { gb in
            var gp: [UnsafeMutablePointer<BNNSNDArrayDescriptor>] = (0..<gb.count).map { gb.baseAddress! + $0 }
            return BNNSArithmeticFilterApplyBackwardBatch(f, batch, inputs.count, &ptrs, &strides, &gp, &gstrides, output.data,
                                                          output.shape.batchStride, &og, og.shape.batchStride)
        }
        try _bnnsCheck(r)
    }
    static func _arithmeticFilter(_ fn: BNNSArithmeticFunction, _ fields: UnsafeMutableRawPointer, _ activation: BNNS.ActivationFunction,
                                  _ filterParameters: BNNSFilterParameters?) -> BNNSFilter? {
        var p = BNNSLayerParametersArithmetic(arithmetic_function: fn, arithmetic_function_fields: fields, activation: activation.bnnsActivation)
        return _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerArithmetic(&p, fp) }
    }

    public class UnaryArithmeticLayer: BNNS.Layer {
        var types: [BNNS.DescriptorType] = []
        convenience public init?(input: BNNSNDArrayDescriptor, inputDescriptorType: BNNS.DescriptorType, output: BNNSNDArrayDescriptor,
                                 outputDescriptorType: BNNS.DescriptorType, function: BNNS.ArithmeticUnaryFunction,
                                 activation: BNNS.ActivationFunction = .identity, filterParameters: BNNSFilterParameters? = nil) {
            var u = BNNSArithmeticUnary(in: input, in_type: inputDescriptorType.bnns, out: output, out_type: outputDescriptorType.bnns)
            let f: BNNSFilter? = withUnsafeMutablePointer(to: &u) { BNNS._arithmeticFilter(function.bnnsArithmeticFunction, $0, activation, filterParameters) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
            types = [inputDescriptorType]
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticApply(bnnsFilter, batchSize, [(input, types[0])], output)
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticBackward(bnnsFilter, batchSize, [(input, types[0])], [inputGradient], output, outputGradient)
        }
    }

    public class BinaryArithmeticLayer: BNNS.Layer {
        var types: [BNNS.DescriptorType] = []
        convenience public init?(inputA: BNNSNDArrayDescriptor, inputADescriptorType: BNNS.DescriptorType, inputB: BNNSNDArrayDescriptor,
                                 inputBDescriptorType: BNNS.DescriptorType, output: BNNSNDArrayDescriptor, outputDescriptorType: BNNS.DescriptorType,
                                 function: BNNS.ArithmeticBinaryFunction, activation: BNNS.ActivationFunction = .identity,
                                 filterParameters: BNNSFilterParameters? = nil) {
            var u = BNNSArithmeticBinary(in1: inputA, in1_type: inputADescriptorType.bnns, in2: inputB, in2_type: inputBDescriptorType.bnns,
                                         out: output, out_type: outputDescriptorType.bnns)
            let f: BNNSFilter? = withUnsafeMutablePointer(to: &u) { BNNS._arithmeticFilter(function.bnnsArithmeticFunction, $0, activation, filterParameters) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
            types = [inputADescriptorType, inputBDescriptorType]
        }
        public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticApply(bnnsFilter, batchSize, [(inputA, types[0]), (inputB, types[1])], output)
        }
        public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                  outputGradient: BNNSNDArrayDescriptor, generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                                  generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticBackward(bnnsFilter, batchSize, [(inputA, types[0]), (inputB, types[1])], [inputAGradient, inputBGradient],
                                         output, outputGradient)
        }
    }

    public class TernaryArithmeticLayer: BNNS.Layer {
        var types: [BNNS.DescriptorType] = []
        convenience public init?(inputA: BNNSNDArrayDescriptor, inputADescriptorType: BNNS.DescriptorType, inputB: BNNSNDArrayDescriptor,
                                 inputBDescriptorType: BNNS.DescriptorType, inputC: BNNSNDArrayDescriptor, inputCDescriptorType: BNNS.DescriptorType,
                                 output: BNNSNDArrayDescriptor, outputDescriptorType: BNNS.DescriptorType, function: BNNS.ArithmeticTernaryFunction,
                                 activation: BNNS.ActivationFunction = .identity, filterParameters: BNNSFilterParameters? = nil) {
            var u = BNNSArithmeticTernary(in1: inputA, in1_type: inputADescriptorType.bnns, in2: inputB, in2_type: inputBDescriptorType.bnns,
                                          in3: inputC, in3_type: inputCDescriptorType.bnns, out: output, out_type: outputDescriptorType.bnns)
            let f: BNNSFilter? = withUnsafeMutablePointer(to: &u) { BNNS._arithmeticFilter(function.bnnsArithmeticFunction, $0, activation, filterParameters) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
            types = [inputADescriptorType, inputBDescriptorType, inputCDescriptorType]
        }
        public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, inputC: BNNSNDArrayDescriptor,
                          output: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticApply(bnnsFilter, batchSize, [(inputA, types[0]), (inputB, types[1]), (inputC, types[2])], output)
        }
        public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, inputC: BNNSNDArrayDescriptor,
                                  output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                                  generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor,
                                  generatingInputCGradient inputCGradient: BNNSNDArrayDescriptor) throws {
            try BNNS._arithmeticBackward(bnnsFilter, batchSize, [(inputA, types[0]), (inputB, types[1]), (inputC, types[2])],
                                         [inputAGradient, inputBGradient, inputCGradient], output, outputGradient)
        }
    }

    // MARK: matrix product

    public class BroadcastMatrixMultiplyLayer: BNNS.Layer {
        var aIsWeights = false, bIsWeights = false
        convenience public init?(inputA: BNNSNDArrayDescriptor, transposed transposeA: Bool, isWeights aIsWeights: Bool, inputB: BNNSNDArrayDescriptor,
                                 transposed transposeB: Bool, isWeights bIsWeights: Bool, output: BNNSNDArrayDescriptor, alpha: Float,
                                 accumulatesToOutput: Bool, isQuadratic: Bool, filterParameters: BNNSFilterParameters? = nil) {
            var p = BNNSLayerParametersBroadcastMatMul(alpha: alpha, beta: accumulatesToOutput ? 1 : 0, transA: transposeA, transB: transposeB,
                                                       quadratic: isQuadratic, a_is_weights: aIsWeights, b_is_weights: bIsWeights,
                                                       iA_desc: inputA, iB_desc: inputB, o_desc: output)
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerBroadcastMatMul(&p, fp) }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
            self.aIsWeights = aIsWeights; self.bIsWeights = bIsWeights
        }
        public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
            if aIsWeights { return try _bnnsApply(bnnsFilter, batchSize, inputB, output) }
            if bIsWeights { return try _bnnsApply(bnnsFilter, batchSize, inputA, output) }
            try _bnnsCheck(BNNSFilterApplyTwoInputBatch(bnnsFilter, batchSize, try _bnnsData(inputA), inputA.shape.batchStride, try _bnnsData(inputB),
                                                        inputB.shape.batchStride, try _bnnsData(output), output.shape.batchStride))
        }
        public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                  outputGradient: BNNSNDArrayDescriptor, generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                                  generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor) throws {
            if aIsWeights {
                return try _bnnsBackward(bnnsFilter, batchSize, inputB, output, outputGradient, inputBGradient, inputAGradient)
            }
            if bIsWeights {
                return try _bnnsBackward(bnnsFilter, batchSize, inputA, output, outputGradient, inputAGradient, inputBGradient)
            }
            var og = outputGradient, ga = inputAGradient, gb = inputBGradient
            try _bnnsCheck(BNNSFilterApplyBackwardTwoInputBatch(bnnsFilter, batchSize, inputA.data, inputA.shape.batchStride, &ga, ga.shape.batchStride,
                                                                inputB.data, inputB.shape.batchStride, &gb, gb.shape.batchStride, output.data,
                                                                output.shape.batchStride, &og, og.shape.batchStride, nil, nil))
        }
    }

    // MARK: loss

    public enum LossFunction {
        public struct YoloParameters {
            public init(huberDelta: Float, gridColumnCount: Int, gridRowsCount: Int, anchorBoxCount: Int, anchorBoxSize: Int, rescore: Bool,
                        xyScale: Float, whScale: Float, objectScale: Float, noObjectScale: Float, classificationScale: Float,
                        objectMinimumIoU: Float, noObjectMaximumIoU: Float, anchorsData: UnsafeMutablePointer<Float>) {
                self.huberDelta = huberDelta; self.gridColumnCount = gridColumnCount; self.gridRowsCount = gridRowsCount
                self.anchorBoxCount = anchorBoxCount; self.anchorBoxSize = anchorBoxSize; self.rescore = rescore; self.xyScale = xyScale
                self.whScale = whScale; self.objectScale = objectScale; self.noObjectScale = noObjectScale
                self.classificationScale = classificationScale; self.objectMinimumIoU = objectMinimumIoU
                self.noObjectMaximumIoU = noObjectMaximumIoU; self.anchorsData = anchorsData
            }
            public let huberDelta: Float
            public let gridColumnCount: Int
            public let gridRowsCount: Int
            public let anchorBoxCount: Int
            public let anchorBoxSize: Int
            public let rescore: Bool
            public let xyScale: Float
            public let whScale: Float
            public let objectScale: Float
            public let noObjectScale: Float
            public let classificationScale: Float
            public let objectMinimumIoU: Float
            public let noObjectMaximumIoU: Float
            public let anchorsData: UnsafeMutablePointer<Float>
        }
        case softmaxCrossEntropy(labelSmoothing: Float)
        case sigmoidCrossEntropy(labelSmoothing: Float)
        case huber(huberDelta: Float)
        case yolo(parameters: BNNS.LossFunction.YoloParameters)
        case meanSquareError
        case log
        case cosineDistance
        case hinge
        case meanAbsoluteError
        case categoricalCrossEntropy
        public var bnnsLossFunction: BNNSLossFunction {
            switch self {
            case .softmaxCrossEntropy: return BNNSLossFunctionSoftmaxCrossEntropy
            case .sigmoidCrossEntropy: return BNNSLossFunctionSigmoidCrossEntropy
            case .huber: return BNNSLossFunctionHuber
            case .yolo: return BNNSLossFunctionYolo
            case .meanSquareError: return BNNSLossFunctionMeanSquareError
            case .log: return BNNSLossFunctionLog
            case .cosineDistance: return BNNSLossFunctionCosineDistance
            case .hinge: return BNNSLossFunctionHinge
            case .meanAbsoluteError: return BNNSLossFunctionMeanAbsoluteError
            case .categoricalCrossEntropy: return BNNSLossFunctionCategoricalCrossEntropy
            }
        }
    }
    public enum LossReduction: Hashable {
        case none
        case sum
        case weightedMean
        case reductionMean
        case zeroWeightMean
        public var bnnsLossReductionFunction: BNNSLossReductionFunction {
            switch self {
            case .none: return BNNSLossReductionNone
            case .sum: return BNNSLossReductionSum
            case .weightedMean: return BNNSLossReductionWeightedMean
            case .reductionMean: return BNNSLossReductionMean
            case .zeroWeightMean: return BNNSLossReductionNonZeroWeightMean
            }
        }
    }

    public class LossLayer: BNNS.Layer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, lossFunction: BNNS.LossFunction,
                                 lossReduction: BNNS.LossReduction, filterParameters: BNNSFilterParameters? = nil) {
            let fn = lossFunction.bnnsLossFunction, red = lossReduction.bnnsLossReductionFunction
            let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in
                switch lossFunction {
                case let .softmaxCrossEntropy(s):
                    var p = BNNSLayerParametersLossSoftmaxCrossEntropy(function: fn, i_desc: input, o_desc: output, reduction: red, label_smooth: s)
                    return BNNSFilterCreateLayerLoss(&p, fp)
                case let .sigmoidCrossEntropy(s):
                    var p = BNNSLayerParametersLossSigmoidCrossEntropy(function: fn, i_desc: input, o_desc: output, reduction: red, label_smooth: s)
                    return BNNSFilterCreateLayerLoss(&p, fp)
                case let .huber(d):
                    var p = BNNSLayerParametersLossHuber(function: fn, i_desc: input, o_desc: output, reduction: red, huber_delta: d)
                    return BNNSFilterCreateLayerLoss(&p, fp)
                case let .yolo(y):
                    var p = BNNSLayerParametersLossYolo(function: fn, i_desc: input, o_desc: output, reduction: red, huber_delta: y.huberDelta,
                                                        number_of_grid_columns: y.gridColumnCount, number_of_grid_rows: y.gridRowsCount,
                                                        number_of_anchor_boxes: y.anchorBoxCount, anchor_box_size: y.anchorBoxSize, rescore: y.rescore,
                                                        scale_xy: y.xyScale, scale_wh: y.whScale, scale_object: y.objectScale,
                                                        scale_no_object: y.noObjectScale, scale_classification: y.classificationScale,
                                                        object_minimum_iou: y.objectMinimumIoU, no_object_maximum_iou: y.noObjectMaximumIoU,
                                                        anchors_data: y.anchorsData)
                    return BNNSFilterCreateLayerLoss(&p, fp)
                default:
                    var p = BNNSLayerParametersLossBase(function: fn, i_desc: input, o_desc: output, reduction: red)
                    return BNNSFilterCreateLayerLoss(&p, fp)
                }
            }
            guard let f = f else { return nil }
            self.init(bnnsFilter: f)
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, labels: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                          generatingInputGradient inputGradient: BNNSNDArrayDescriptor) throws {
            try apply(batchSize: batchSize, input: input, labels: labels, output: output, weights: nil, broadcastsWeights: false,
                      generatingInputGradient: inputGradient)
        }
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, labels: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                          weights: BNNSNDArrayDescriptor?, broadcastsWeights: Bool, generatingInputGradient inputGradient: BNNSNDArrayDescriptor) throws {
            var ig = inputGradient
            let wcount = weights.map { broadcastsWeights ? 1 : $0.shape.batchStride * batchSize } ?? 0
            let i = try _bnnsData(input), l = try _bnnsData(labels), o = try _bnnsData(output)
            let r: Int32 = ig.data == nil
                ? BNNSLossFilterApplyBatch(bnnsFilter, batchSize, i, input.shape.batchStride, l, labels.shape.batchStride, weights?.data, wcount, o, nil, 0)
                : BNNSLossFilterApplyBatch(bnnsFilter, batchSize, i, input.shape.batchStride, l, labels.shape.batchStride, weights?.data, wcount, o,
                                           &ig, ig.shape.batchStride)
            try _bnnsCheck(r)
        }
    }

    // MARK: fused layers

    public class FusedLayer: BNNS.Layer {
        public func apply(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, for learningPhase: BNNS.LearningPhase) throws {
            try _bnnsCheck(BNNSFusedFilterApplyBatch(bnnsFilter, batchSize, try _bnnsData(input), input.shape.batchStride, try _bnnsData(output),
                                                     output.shape.batchStride, learningPhase == .training))
        }
        public func applyBackward(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                  generatingParameterGradients parameterGradients: [BNNSNDArrayDescriptor]) throws {
            var ig = inputGradient, og = outputGradient, pg = parameterGradients
            let r: Int32 = pg.withUnsafeMutableBufferPointer { pb in
                var pp: [UnsafeMutablePointer<BNNSNDArrayDescriptor>?] = (0..<max(pb.count, 4)).map { $0 < pb.count ? pb.baseAddress! + $0 : nil }
                return BNNSFusedFilterApplyBackwardBatch(bnnsFilter, batchSize, input.data, input.shape.batchStride, &ig, ig.shape.batchStride,
                                                         output.data, output.shape.batchStride, &og, og.shape.batchStride, &pp)
            }
            try _bnnsCheck(r)
        }
    }

    public class FusedConvolutionNormalizationLayer: BNNS.FusedLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, convolutionWeights: BNNSNDArrayDescriptor,
                                 convolutionBias: BNNSNDArrayDescriptor?, convolutionStride: (x: Int, y: Int), convolutionDilationStride: (x: Int, y: Int),
                                 convolutionPadding: BNNS.ConvolutionPadding, normalization: BNNS.NormalizationType, normalizationBeta: BNNSNDArrayDescriptor,
                                 normalizationGamma: BNNSNDArrayDescriptor, normalizationMomentum: Float, normalizationEpsilon: Float,
                                 normalizationActivation: BNNS.ActivationFunction, filterParameters: BNNSFilterParameters? = nil) {
            let params: [any FusableLayerParameters] = [
                BNNS.FusedConvolutionParameters(type: .standard, weights: convolutionWeights, bias: convolutionBias, stride: convolutionStride,
                                                dilationStride: convolutionDilationStride, groupSize: 1, padding: convolutionPadding),
                BNNS.FusedNormalizationParameters(type: normalization, beta: normalizationBeta, gamma: normalizationGamma,
                                                  momentum: normalizationMomentum, epsilon: normalizationEpsilon, activation: normalizationActivation)]
            guard let f = _bnnsFusedFilter([input], output, params, filterParameters) else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class FusedFullyConnectedNormalizationLayer: BNNS.FusedLayer {
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, fullyConnectedWeights: BNNSNDArrayDescriptor,
                                 fullyConnectedBias: BNNSNDArrayDescriptor?, normalization: BNNS.NormalizationType, normalizationBeta: BNNSNDArrayDescriptor,
                                 normalizationGamma: BNNSNDArrayDescriptor, normalizationMomentum: Float, normalizationEpsilon: Float,
                                 normalizationActivation: BNNS.ActivationFunction, filterParameters: BNNSFilterParameters? = nil) {
            let params: [any FusableLayerParameters] = [
                BNNS.FusedFullyConnectedParameters(weights: fullyConnectedWeights, bias: fullyConnectedBias),
                BNNS.FusedNormalizationParameters(type: normalization, beta: normalizationBeta, gamma: normalizationGamma,
                                                  momentum: normalizationMomentum, epsilon: normalizationEpsilon, activation: normalizationActivation)]
            guard let f = _bnnsFusedFilter([input], output, params, filterParameters) else { return nil }
            self.init(bnnsFilter: f)
        }
    }

    public class FusedParametersLayer: BNNS.FusedLayer {
        var types: [BNNS.DescriptorType] = []
        convenience public init?(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, fusedLayerParameters: [any FusableLayerParameters],
                                 filterParameters: BNNSFilterParameters? = nil) {
            guard let f = _bnnsFusedFilter([input], output, fusedLayerParameters, filterParameters) else { return nil }
            self.init(bnnsFilter: f)
            types = _bnnsFusedInputTypes(fusedLayerParameters, 1)
        }
        func _applyMulti(_ batch: Int, _ inputs: [BNNSNDArrayDescriptor], _ output: BNNSNDArrayDescriptor, _ phase: BNNS.LearningPhase) throws {
            var ptrs: [UnsafeRawPointer?] = try inputs.map { UnsafeRawPointer(try _bnnsData($0)) }
            let strides = inputs.enumerated().map { (types.count > $0.offset && types[$0.offset] != .sample) ? 0 : $0.element.shape.batchStride }
            let r: Int32 = ptrs.withUnsafeMutableBufferPointer { pb in
                pb.baseAddress!.withMemoryRebound(to: UnsafeRawPointer.self, capacity: pb.count) { pp in
                    BNNSFusedFilterApplyMultiInputBatch(bnnsFilter, batch, inputs.count, pp, strides, output.data!, output.shape.batchStride,
                                                        phase == .training)
                }
            }
            try _bnnsCheck(r)
        }
        func _backwardMulti(_ batch: Int, _ inputs: [BNNSNDArrayDescriptor], _ gradients: [BNNSNDArrayDescriptor], _ output: BNNSNDArrayDescriptor,
                            _ outputGradient: BNNSNDArrayDescriptor, _ parameterGradients: [BNNSNDArrayDescriptor]) throws {
            var ptrs: [UnsafeRawPointer?] = inputs.map { UnsafeRawPointer($0.data) }
            var strides = inputs.map { $0.shape.batchStride }
            var grads = gradients, og = outputGradient, pg = parameterGradients
            let gstrides = gradients.map { $0.shape.batchStride }
            let r: Int32 = grads.withUnsafeMutableBufferPointer { gb in
                pg.withUnsafeMutableBufferPointer { pb in
                    var gp: [UnsafeMutablePointer<BNNSNDArrayDescriptor>] = (0..<gb.count).map { gb.baseAddress! + $0 }
                    var pp: [UnsafeMutablePointer<BNNSNDArrayDescriptor>?] = (0..<max(pb.count, 4)).map { $0 < pb.count ? pb.baseAddress! + $0 : nil }
                    return BNNSFusedFilterApplyBackwardMultiInputBatch(bnnsFilter, batch, inputs.count, &ptrs, &strides, &gp, gstrides, output.data,
                                                                       output.shape.batchStride, &og, og.shape.batchStride, &pp)
                }
            }
            try _bnnsCheck(r)
        }
    }

    // MARK: crop and resize

    public class CropResizeLayer {
        public enum BoxCoordinateMode: Hashable {
            case cornersHeightFirst
            case cornersWidthFirst
            case centerSizeHeightFirst
            case centerSizeWidthFirst
        }
        public enum LinearSamplingMode: Hashable {
            case `default`
            case alignCorners
            case unalignCorners
            case strictAlignCorners
            case offsetCorners
        }
        var params: BNNSLayerParametersCropResize
        public init(coordinatesAreNormalized: Bool, spatialScale: Float, extrapolationValue: Float = 0,
                    samplingMode: BNNS.CropResizeLayer.LinearSamplingMode = .default, boxCoordinateMode: BNNS.CropResizeLayer.BoxCoordinateMode) {
            let sm: BNNSLinearSamplingMode
            switch samplingMode {
            case .default: sm = BNNSLinearSamplingDefault
            case .alignCorners: sm = BNNSLinearSamplingAlignCorners
            case .unalignCorners: sm = BNNSLinearSamplingUnalignCorners
            case .strictAlignCorners: sm = BNNSLinearSamplingStrictAlignCorners
            case .offsetCorners: sm = BNNSLinearSamplingOffsetCorners
            }
            let bm: BNNSBoxCoordinateMode
            switch boxCoordinateMode {
            case .cornersHeightFirst: bm = BNNSCornersHeightFirst
            case .cornersWidthFirst: bm = BNNSCornersWidthFirst
            case .centerSizeHeightFirst: bm = BNNSCenterSizeHeightFirst
            case .centerSizeWidthFirst: bm = BNNSCenterSizeWidthFirst
            }
            params = BNNSLayerParametersCropResize(normalized_coordinates: coordinatesAreNormalized, spatial_scale: spatialScale,
                                                   extrapolation_value: extrapolationValue, sampling_mode: sm, box_coordinate_mode: bm,
                                                   method: BNNSInterpolationMethodLinear)
        }
        public func apply(input: BNNSNDArrayDescriptor, regionOfInterest: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                          filterParameters: BNNSFilterParameters? = nil) throws {
            var p = params, i = input, r = regionOfInterest, o = output
            try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSCropResize(&p, &i, &r, &o, fp)) }
        }
        public func applyBackward(regionOfInterest: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                                  generatingInputGradient inputGradient: BNNSNDArrayDescriptor, filterParameters: BNNSFilterParameters? = nil) throws {
            var p = params, ig = inputGradient, r = regionOfInterest, og = outputGradient
            try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSCropResizeBackward(&p, &ig, &r, &og, fp)) }
        }
    }

    // MARK: sparse weights

    public enum SparsityType: Hashable {
        case unstructured
    }
    public struct SparseParameters {
        public init(type: BNNS.SparsityType = .unstructured, ratio: (numerator: UInt32, denominator: UInt32), targetSystem: BNNSTargetSystem) {
            self.type = type; self.ratio = ratio; self.targetSystem = targetSystem
        }
        public let type: BNNS.SparsityType
        public let ratio: (numerator: UInt32, denominator: UInt32)
        public let targetSystem: BNNSTargetSystem
        var bnns: BNNSSparsityParameters {
            BNNSSparsityParameters(flags: 0, sparsity_ratio: (ratio.numerator, ratio.denominator), sparsity_type: BNNSSparsityTypeUnstructured,
                                   target_system: targetSystem)
        }
    }
    public enum SparseLayout {
        case coo(indices: BNNSNDArrayDescriptor)
        case csr(columnIndices: BNNSNDArrayDescriptor, rowStarts: BNNSNDArrayDescriptor)
    }
}

extension BNNS.ActivationLayer {
    convenience public init?(function activationFunction: BNNS.ActivationFunction, axes: [Int], input: BNNSNDArrayDescriptor,
                             output: BNNSNDArrayDescriptor, filterParameters: BNNSFilterParameters? = nil) {
        var p = BNNSLayerParametersActivation(i_desc: input, o_desc: output, activation: activationFunction.bnnsActivation,
                                              axis_flags: _bnnsAxisFlags(axes))
        let f: BNNSFilter? = _bnnsWithOptional(filterParameters) { fp in BNNSFilterCreateLayerActivation(&p, fp) }
        guard let f = f else { return nil }
        self.init(bnnsFilter: f)
    }
}

extension BNNS.FullyConnectedLayer {
    public static func sparsify(batchSize: Int = 1, inputLayout layout: BNNS.SparseLayout, inputDenseShape: BNNSNDArrayDescriptor,
                                inputValues: BNNSNDArrayDescriptor, output: inout BNNSNDArrayDescriptor, sparseParameters: BNNS.SparseParameters? = nil,
                                workspace: UnsafeMutableRawBufferPointer? = nil, filterParameters: BNNSFilterParameters? = nil) throws {
        var shape = inputDenseShape, values = inputValues
        let sp = sparseParameters?.bnns
        try _bnnsWithOptional(sp) { spp in
            try _bnnsWithOptional(filterParameters) { fp in
                switch layout {
                case let .coo(indices):
                    var ix = indices
                    try _bnnsCheck(BNNSNDArrayFullyConnectedSparsifySparseCOO(&shape, &ix, &values, &output, spp, batchSize, workspace?.baseAddress,
                                                                              workspace?.count ?? 0, fp))
                case let .csr(columnIndices, rowStarts):
                    var ci = columnIndices, rs = rowStarts
                    try _bnnsCheck(BNNSNDArrayFullyConnectedSparsifySparseCSR(&shape, &ci, &rs, &values, &output, spp, batchSize,
                                                                              workspace?.baseAddress, workspace?.count ?? 0, fp))
                }
            }
        }
    }
}

extension BNNS.FusedParametersLayer {
    convenience public init?(inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                             fusedLayerParameters: [any FusableLayerParameters], filterParameters: BNNSFilterParameters? = nil) {
        guard let f = _bnnsFusedFilter([inputA, inputB], output, fusedLayerParameters, filterParameters) else { return nil }
        self.init(bnnsFilter: f)
        types = _bnnsFusedInputTypes(fusedLayerParameters, 2)
    }
    public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                      for learningPhase: BNNS.LearningPhase) throws {
        try _applyMulti(batchSize, [inputA, inputB], output, learningPhase)
    }
    public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                              outputGradient: BNNSNDArrayDescriptor, generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                              generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor,
                              generatingParameterGradients parameterGradients: [BNNSNDArrayDescriptor]) throws {
        try _backwardMulti(batchSize, [inputA, inputB], [inputAGradient, inputBGradient], output, outputGradient, parameterGradients)
    }
    convenience public init?(inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, inputC: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                             fusedLayerParameters: [any FusableLayerParameters], filterParameters: BNNSFilterParameters? = nil) {
        guard let f = _bnnsFusedFilter([inputA, inputB, inputC], output, fusedLayerParameters, filterParameters) else { return nil }
        self.init(bnnsFilter: f)
        types = _bnnsFusedInputTypes(fusedLayerParameters, 3)
    }
    public func apply(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, inputC: BNNSNDArrayDescriptor,
                      output: BNNSNDArrayDescriptor, for learningPhase: BNNS.LearningPhase) throws {
        try _applyMulti(batchSize, [inputA, inputB, inputC], output, learningPhase)
    }
    public func applyBackward(batchSize: Int, inputA: BNNSNDArrayDescriptor, inputB: BNNSNDArrayDescriptor, inputC: BNNSNDArrayDescriptor,
                              output: BNNSNDArrayDescriptor, outputGradient: BNNSNDArrayDescriptor,
                              generatingInputAGradient inputAGradient: BNNSNDArrayDescriptor,
                              generatingInputBGradient inputBGradient: BNNSNDArrayDescriptor,
                              generatingInputCGradient inputCGradient: BNNSNDArrayDescriptor,
                              generatingParameterGradients parameterGradients: [BNNSNDArrayDescriptor]) throws {
        try _backwardMulti(batchSize, [inputA, inputB, inputC], [inputAGradient, inputBGradient, inputCGradient], output, outputGradient,
                           parameterGradients)
    }
}

// MARK: - fusable layer parameters

public protocol FusableLayerParameters {}

extension BNNS {
    public struct FusedConvolutionParameters: FusableLayerParameters {
        public init(type: BNNS.ConvolutionType, weights: BNNSNDArrayDescriptor, bias: BNNSNDArrayDescriptor?, stride: (x: Int, y: Int),
                    dilationStride: (x: Int, y: Int), groupSize: Int, padding: BNNS.ConvolutionPadding) {
            self.type = type; self.weights = weights; self.bias = bias; self.stride = stride; self.dilationStride = dilationStride
            self.groupSize = groupSize; self.padding = padding
        }
        public var type: BNNS.ConvolutionType
        public var weights: BNNSNDArrayDescriptor
        public var bias: BNNSNDArrayDescriptor?
        public var stride: (x: Int, y: Int)
        public var dilationStride: (x: Int, y: Int)
        public var groupSize: Int
        public var padding: BNNS.ConvolutionPadding
    }
    public struct FusedFullyConnectedParameters: FusableLayerParameters {
        public init(weights: BNNSNDArrayDescriptor, bias: BNNSNDArrayDescriptor?) { self.weights = weights; self.bias = bias }
        public var weights: BNNSNDArrayDescriptor
        public var bias: BNNSNDArrayDescriptor?
    }
    public struct FusedNormalizationParameters: FusableLayerParameters {
        public init(type: BNNS.NormalizationType, beta: BNNSNDArrayDescriptor? = nil, gamma: BNNSNDArrayDescriptor? = nil, momentum: Float = 0,
                    epsilon: Float, activation: BNNS.ActivationFunction) {
            self.type = type; self.beta = beta; self.gamma = gamma; self.momentum = momentum; self.epsilon = epsilon; self.activation = activation
        }
        public var type: BNNS.NormalizationType
        public var beta: BNNSNDArrayDescriptor?
        public var gamma: BNNSNDArrayDescriptor?
        public var momentum: Float
        public var epsilon: Float
        public var activation: BNNS.ActivationFunction
    }
    public struct FusedQuantizationParameters: FusableLayerParameters {
        public init(scale: BNNSNDArrayDescriptor?, bias: BNNSNDArrayDescriptor?) { self.scale = scale; self.bias = bias }
        public var axis: Int?
        public var scale: BNNSNDArrayDescriptor?
        public var bias: BNNSNDArrayDescriptor?
    }
    public struct FusedDequantizationParameters: FusableLayerParameters {
        public init(scale: BNNSNDArrayDescriptor?, bias: BNNSNDArrayDescriptor?) { self.scale = scale; self.bias = bias }
        public var axis: Int?
        public var scale: BNNSNDArrayDescriptor?
        public var bias: BNNSNDArrayDescriptor?
    }
    public struct FusedUnaryArithmeticParameters: FusableLayerParameters {
        public var inputDescriptorType: BNNS.DescriptorType
        public var outputDescriptorType: BNNS.DescriptorType
        public var function: BNNS.ArithmeticUnaryFunction
        public init(inputDescriptorType: BNNS.DescriptorType, outputDescriptorType: BNNS.DescriptorType, function: BNNS.ArithmeticUnaryFunction) {
            self.inputDescriptorType = inputDescriptorType; self.outputDescriptorType = outputDescriptorType; self.function = function
        }
    }
    public struct FusedBinaryArithmeticParameters: FusableLayerParameters {
        public var inputADescriptorType: BNNS.DescriptorType
        public var inputBDescriptorType: BNNS.DescriptorType
        public var outputDescriptorType: BNNS.DescriptorType
        public var function: BNNS.ArithmeticBinaryFunction
        public init(inputADescriptorType: BNNS.DescriptorType, inputBDescriptorType: BNNS.DescriptorType, outputDescriptorType: BNNS.DescriptorType,
                    function: BNNS.ArithmeticBinaryFunction) {
            self.inputADescriptorType = inputADescriptorType; self.inputBDescriptorType = inputBDescriptorType
            self.outputDescriptorType = outputDescriptorType; self.function = function
        }
    }
    public struct FusedTernaryArithmeticParameters: FusableLayerParameters {
        public var inputADescriptorType: BNNS.DescriptorType
        public var inputBDescriptorType: BNNS.DescriptorType
        public var inputCDescriptorType: BNNS.DescriptorType
        public var outputDescriptorType: BNNS.DescriptorType
        public var function: BNNS.ArithmeticTernaryFunction
        public init(inputADescriptorType: BNNS.DescriptorType, inputBDescriptorType: BNNS.DescriptorType, inputCDescriptorType: BNNS.DescriptorType,
                    outputDescriptorType: BNNS.DescriptorType, function: BNNS.ArithmeticTernaryFunction) {
            self.inputADescriptorType = inputADescriptorType; self.inputBDescriptorType = inputBDescriptorType
            self.inputCDescriptorType = inputCDescriptorType; self.outputDescriptorType = outputDescriptorType; self.function = function
        }
    }
}

func _bnnsFusedInputTypes(_ params: [any FusableLayerParameters], _ n: Int) -> [BNNS.DescriptorType] {
    switch params.first {
    case let u as BNNS.FusedUnaryArithmeticParameters: return [u.inputDescriptorType]
    case let b as BNNS.FusedBinaryArithmeticParameters: return [b.inputADescriptorType, b.inputBDescriptorType]
    case let t as BNNS.FusedTernaryArithmeticParameters: return [t.inputADescriptorType, t.inputBDescriptorType, t.inputCDescriptorType]
    default: return [BNNS.DescriptorType](repeating: .sample, count: n)
    }
}

/// Two fused filters: the first from `inputs` to an intermediate with the output's shape (float when the second quantizes),
/// the second from that intermediate to `output`.
func _bnnsFusedFilter(_ inputs: [BNNSNDArrayDescriptor], _ output: BNNSNDArrayDescriptor, _ params: [any FusableLayerParameters],
                      _ filterParameters: BNNSFilterParameters?) -> BNNSFilter? {
    guard params.count == 2, let input = inputs.first else { return nil }
    var mid = output
    mid.data = nil
    if params[1] is BNNS.FusedQuantizationParameters || params[1] is BNNS.FusedDequantizationParameters {
        mid.data_type = BNNSDataTypeFloat32; mid.data_scale = 1; mid.data_bias = 0
    }
    var types: [BNNSFilterType] = []
    var conv = BNNSLayerParametersConvolution(), fc = BNNSLayerParametersFullyConnected(), norm = BNNSLayerParametersNormalization()
    var quant = BNNSLayerParametersQuantization()
    var arith = BNNSLayerParametersArithmetic(arithmetic_function: BNNSArithmeticAdd, arithmetic_function_fields: UnsafeMutableRawPointer(bitPattern: 1)!,
                                              activation: .identity)
    var u = BNNSArithmeticUnary(), b = BNNSArithmeticBinary(), t = BNNSArithmeticTernary()
    for (k, p) in params.enumerated() {
        let i = k == 0 ? input : mid, o = k == 0 ? mid : output
        switch p {
        case let c as BNNS.FusedConvolutionParameters:
            let pd = _bnnsPadding(c.padding)
            conv = BNNSLayerParametersConvolution(i_desc: i, w_desc: c.weights, o_desc: o, bias: c.bias ?? BNNSNDArrayDescriptor(),
                                                  activation: .identity, x_stride: c.stride.x, y_stride: c.stride.y,
                                                  x_dilation_stride: c.dilationStride.x, y_dilation_stride: c.dilationStride.y,
                                                  x_padding: pd.x, y_padding: pd.y, groups: c.groupSize, pad: pd.pad)
            types.append(c.type == .transposed ? BNNSTransposedConvolution : BNNSConvolution)
        case let f as BNNS.FusedFullyConnectedParameters:
            fc = BNNSLayerParametersFullyConnected(i_desc: i, w_desc: f.weights, o_desc: o, bias: f.bias ?? BNNSNDArrayDescriptor(), activation: .identity)
            types.append(BNNSFullyConnected)
        case let n as BNNS.FusedNormalizationParameters:
            norm = n.type.parameters(input: i, output: o, beta: n.beta, gamma: n.gamma, momentum: n.momentum, epsilon: n.epsilon, activation: n.activation)
            types.append(n.type.filterType)
        case let q as BNNS.FusedQuantizationParameters:
            quant = BNNSLayerParametersQuantization(axis_mask: q.axis.map { 1 << $0 } ?? 0, function: BNNSQuantizerFunctionQuantize, i_desc: i, o_desc: o,
                                                    scale: q.scale ?? BNNSNDArrayDescriptor(), bias: q.bias ?? BNNSNDArrayDescriptor())
            types.append(BNNSQuantization)
        case let q as BNNS.FusedDequantizationParameters:
            quant = BNNSLayerParametersQuantization(axis_mask: q.axis.map { 1 << $0 } ?? 0, function: BNNSQuantizerFunctionDequantize, i_desc: i, o_desc: o,
                                                    scale: q.scale ?? BNNSNDArrayDescriptor(), bias: q.bias ?? BNNSNDArrayDescriptor())
            types.append(BNNSQuantization)
        case let a as BNNS.FusedUnaryArithmeticParameters:
            u = BNNSArithmeticUnary(in: i, in_type: a.inputDescriptorType.bnns, out: o, out_type: a.outputDescriptorType.bnns)
            arith.arithmetic_function = a.function.bnnsArithmeticFunction
            types.append(BNNSArithmetic)
        case let a as BNNS.FusedBinaryArithmeticParameters:
            guard inputs.count >= 2 else { return nil }
            b = BNNSArithmeticBinary(in1: inputs[0], in1_type: a.inputADescriptorType.bnns, in2: inputs[1], in2_type: a.inputBDescriptorType.bnns,
                                     out: o, out_type: a.outputDescriptorType.bnns)
            arith.arithmetic_function = a.function.bnnsArithmeticFunction
            types.append(BNNSArithmetic)
        case let a as BNNS.FusedTernaryArithmeticParameters:
            guard inputs.count >= 3 else { return nil }
            t = BNNSArithmeticTernary(in1: inputs[0], in1_type: a.inputADescriptorType.bnns, in2: inputs[1], in2_type: a.inputBDescriptorType.bnns,
                                      in3: inputs[2], in3_type: a.inputCDescriptorType.bnns, out: o, out_type: a.outputDescriptorType.bnns)
            arith.arithmetic_function = a.function.bnnsArithmeticFunction
            types.append(BNNSArithmetic)
        default:
            return nil
        }
    }
    return withUnsafeMutablePointer(to: &conv) { cp in withUnsafeMutablePointer(to: &fc) { fp in withUnsafeMutablePointer(to: &norm) { np in
        withUnsafeMutablePointer(to: &quant) { qp in withUnsafeMutablePointer(to: &u) { up in withUnsafeMutablePointer(to: &b) { bp in
            withUnsafeMutablePointer(to: &t) { tp in withUnsafeMutablePointer(to: &arith) { ap -> BNNSFilter? in
                switch params[0] {
                case is BNNS.FusedUnaryArithmeticParameters: ap.pointee.arithmetic_function_fields = UnsafeMutableRawPointer(up)
                case is BNNS.FusedBinaryArithmeticParameters: ap.pointee.arithmetic_function_fields = UnsafeMutableRawPointer(bp)
                case is BNNS.FusedTernaryArithmeticParameters: ap.pointee.arithmetic_function_fields = UnsafeMutableRawPointer(tp)
                default: break
                }
                var ptrs: [UnsafeRawPointer] = []
                for (k, ty) in types.enumerated() {
                    switch ty {
                    case BNNSConvolution, BNNSTransposedConvolution: ptrs.append(UnsafeRawPointer(cp))
                    case BNNSFullyConnected: ptrs.append(UnsafeRawPointer(fp))
                    case BNNSQuantization: ptrs.append(UnsafeRawPointer(qp))
                    case BNNSArithmetic: ptrs.append(UnsafeRawPointer(ap))
                    default: ptrs.append(UnsafeRawPointer(np))
                    }
                    _ = k
                }
                let f: BNNSFilter? = ptrs.withUnsafeMutableBufferPointer { pb in
                    pb.baseAddress!.withMemoryRebound(to: UnsafeRawPointer.self, capacity: pb.count) { pp in
                        _bnnsWithOptional(filterParameters) { fpp in BNNSFilterCreateFusedLayer(types.count, types, pp, fpp) }
                    }
                }
                return f
            } }
        } } }
    } } }
}
