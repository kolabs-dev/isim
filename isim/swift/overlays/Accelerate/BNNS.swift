// isim Accelerate overlay: BNNS's Swift API (issue #823), over isim's C BNNS (frameworks/Accelerate/bnns*.c, issue #808):
// the BNNS namespace's types, BNNSNDArrayDescriptor / BNNSTensor helpers, the direct functions, the optimizers, the
// random generator and nearest neighbors. The layer classes are in BNNS+Layers.swift.

public enum BNNS {}

// MARK: - small helpers

@inline(__always) func _bnnsArray8(_ t: (Int, Int, Int, Int, Int, Int, Int, Int)) -> [Int] { [t.0, t.1, t.2, t.3, t.4, t.5, t.6, t.7] }
@inline(__always) func _bnnsTuple8(_ a: [Int]) -> (Int, Int, Int, Int, Int, Int, Int, Int) {
    let p = a + [Int](repeating: 0, count: max(0, 8 - a.count))
    return (p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7])
}
@inline(__always) func _bnnsCheck(_ r: Int32, _ e: BNNS.Error = .layerApplyFail) throws { if r != 0 { throw e } }
/// Runs `body` with a pointer to a copy of an optional value (nil gives a nil pointer).
func _bnnsWithOptional<T, R>(_ v: T?, _ body: (UnsafeMutablePointer<T>?) throws -> R) rethrows -> R {
    guard var v = v else { return try body(nil) }
    return try withUnsafeMutablePointer(to: &v) { try body($0) }
}
func _bnnsBits(_ t: BNNSDataType) -> Int {
    switch t {
    case BNNSDataTypeFloat16, BNNSDataTypeBFloat16: return 16
    case BNNSDataTypeFloat32: return 32
    case BNNSDataTypeBoolean: return 8
    default: return Int(t.rawValue & 0xff)
    }
}
/// Axis numbers as BNNS's axis bit mask.
func _bnnsAxisFlags(_ axes: [Int]?) -> UInt32 { (axes ?? []).reduce(0) { $0 | (1 << UInt32($1)) } }

// MARK: - Error, Norm, LearningPhase, DescriptorType

extension BNNS {
    public enum Error: Swift.Error {
        case layerApplyFail
        case unableToCreateLayer
        case arrayDescriptorInvalidData
        case optimizerStepFail
    }

    @frozen public struct Norm: Equatable {
        public var rawValue: Float
        public init(rawValue: Float) { self.rawValue = rawValue }
        public static var l1: BNNS.Norm { Norm(rawValue: 1) }
        public static var taxicab: BNNS.Norm { Norm(rawValue: 1) }
        public static var l2: BNNS.Norm { Norm(rawValue: 2) }
        public static var euclidean: BNNS.Norm { Norm(rawValue: 2) }
        public static var lInfinity: BNNS.Norm { Norm(rawValue: .infinity) }
        public static var maximum: BNNS.Norm { Norm(rawValue: .infinity) }
    }

    @frozen public enum LearningPhase: Hashable, Sendable {
        case training
        case inference
    }

    public enum DescriptorType: Hashable {
        case constant
        case sample
        case parameter
        var bnns: BNNSDescriptorType {
            switch self {
            case .constant: return BNNSConstant
            case .sample: return BNNSSample
            case .parameter: return BNNSParameter
            }
        }
    }
}
extension BNNS.Norm: Sendable {}
extension BNNS.Norm: BitwiseCopyable {}

// MARK: - data layouts and shapes

extension BNNS {
    public enum DataLayout: CaseIterable, Hashable {
        case vector
        case matrixRowMajor
        case matrixColumnMajor
        case matrixFirstMajor
        case matrixLastMajor
        case imageCHW
        case tensor3DFirstMajor
        case tensor3DLastMajor
        case convolutionWeightsOIHW
        case tensor4DFirstMajor
        case tensor4DLastMajor
        case tensor5DFirstMajor
        case tensor5DLastMajor
        case tensor6DFirstMajor
        case tensor6DLastMajor
        case tensor7DFirstMajor
        case tensor7DLastMajor
        case tensor8DFirstMajor
        case tensor8DLastMajor
        case tensor3DSNE
        case tensor3DNSE

        public static var allCases: [BNNS.DataLayout] {
            [.vector, .matrixRowMajor, .matrixColumnMajor, .matrixFirstMajor, .matrixLastMajor, .imageCHW, .tensor3DFirstMajor,
             .tensor3DLastMajor, .convolutionWeightsOIHW, .tensor4DFirstMajor, .tensor4DLastMajor, .tensor5DFirstMajor,
             .tensor5DLastMajor, .tensor6DFirstMajor, .tensor6DLastMajor, .tensor7DFirstMajor, .tensor7DLastMajor,
             .tensor8DFirstMajor, .tensor8DLastMajor, .tensor3DSNE, .tensor3DNSE]
        }
        public var rank: Int { Int(BNNSDataLayoutGetRank(bnns)) }
        var bnns: BNNSDataLayout {
            switch self {
            case .vector: return BNNSDataLayoutVector
            case .matrixRowMajor: return BNNSDataLayoutRowMajorMatrix
            case .matrixColumnMajor: return BNNSDataLayoutColumnMajorMatrix
            case .matrixFirstMajor: return BNNSDataLayout2DFirstMajor
            case .matrixLastMajor: return BNNSDataLayout2DLastMajor
            case .imageCHW: return BNNSDataLayoutImageCHW
            case .tensor3DFirstMajor: return BNNSDataLayout3DFirstMajor
            case .tensor3DLastMajor: return BNNSDataLayout3DLastMajor
            case .convolutionWeightsOIHW: return BNNSDataLayoutConvolutionWeightsOIHW
            case .tensor4DFirstMajor: return BNNSDataLayout4DFirstMajor
            case .tensor4DLastMajor: return BNNSDataLayout4DLastMajor
            case .tensor5DFirstMajor: return BNNSDataLayout5DFirstMajor
            case .tensor5DLastMajor: return BNNSDataLayout5DLastMajor
            case .tensor6DFirstMajor: return BNNSDataLayout6DFirstMajor
            case .tensor6DLastMajor: return BNNSDataLayout6DLastMajor
            case .tensor7DFirstMajor: return BNNSDataLayout7DFirstMajor
            case .tensor7DLastMajor: return BNNSDataLayout7DLastMajor
            case .tensor8DFirstMajor: return BNNSDataLayout8DFirstMajor
            case .tensor8DLastMajor: return BNNSDataLayout8DLastMajor
            case .tensor3DSNE: return BNNSDataLayoutSNE
            case .tensor3DNSE: return BNNSDataLayoutNSE
            }
        }
        init?(_ l: BNNSDataLayout) {
            guard let m = DataLayout.allCases.first(where: { $0.bnns == l }) else { return nil }
            self = m
        }
        /// The layout used for a size array without one: vector, row-major matrix, then last-major tensors.
        static func defaultLayout(rank: Int) -> DataLayout {
            switch rank {
            case 1: return .vector
            case 2: return .matrixRowMajor
            case 3: return .tensor3DLastMajor
            case 4: return .tensor4DLastMajor
            case 5: return .tensor5DLastMajor
            case 6: return .tensor6DLastMajor
            case 7: return .tensor7DLastMajor
            default: return .tensor8DLastMajor
            }
        }
    }

    public enum Shape {
        case vector(_: Int, stride: Int = 0)
        case matrixColumnMajor(_: Int, _: Int, stride: (Int, Int) = (0, 0))
        case matrixRowMajor(_: Int, _: Int, stride: (Int, Int) = (0, 0))
        case matrixFirstMajor(_: Int, _: Int, stride: (Int, Int) = (0, 0))
        case matrixLastMajor(_: Int, _: Int, stride: (Int, Int) = (0, 0))
        case imageCHW(_: Int, _: Int, _: Int, stride: (Int, Int, Int) = (0, 0, 0))
        case tensor3DFirstMajor(_: Int, _: Int, _: Int, stride: (Int, Int, Int) = (0, 0, 0))
        case tensor3DLastMajor(_: Int, _: Int, _: Int, stride: (Int, Int, Int) = (0, 0, 0))
        case tensor3DSNE(_: Int, _: Int, _: Int, stride: (Int, Int, Int) = (0, 0, 0))
        case tensor3DNSE(_: Int, _: Int, _: Int, stride: (Int, Int, Int) = (0, 0, 0))
        case convolutionWeightsOIHW(_: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int) = (0, 0, 0, 0))
        case tensor4DFirstMajor(_: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int) = (0, 0, 0, 0))
        case tensor4DLastMajor(_: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int) = (0, 0, 0, 0))
        case tensor5DFirstMajor(_: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0))
        case tensor5DLastMajor(_: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0))
        case tensor6DFirstMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0))
        case tensor6DLastMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0))
        case tensor7DFirstMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0))
        case tensor7DLastMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0))
        case tensor8DFirstMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0, 0))
        case tensor8DLastMajor(_: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, _: Int, stride: (Int, Int, Int, Int, Int, Int, Int, Int) = (0, 0, 0, 0, 0, 0, 0, 0))

        public init(_ size: [Int], dataLayout: BNNS.DataLayout? = nil, stride: [Int]? = nil) {
            let layout = dataLayout ?? DataLayout.defaultLayout(rank: size.count)
            self = Shape._make(layout, size, stride ?? [])
        }

        static func _make(_ layout: DataLayout, _ size: [Int], _ stride: [Int]) -> Shape {
            let s = size + [Int](repeating: 1, count: max(0, 8 - size.count)), t = stride + [Int](repeating: 0, count: max(0, 8 - stride.count))
            switch layout {
            case .vector: return .vector(s[0], stride: t[0])
            case .matrixColumnMajor: return .matrixColumnMajor(s[0], s[1], stride: (t[0], t[1]))
            case .matrixRowMajor: return .matrixRowMajor(s[0], s[1], stride: (t[0], t[1]))
            case .matrixFirstMajor: return .matrixFirstMajor(s[0], s[1], stride: (t[0], t[1]))
            case .matrixLastMajor: return .matrixLastMajor(s[0], s[1], stride: (t[0], t[1]))
            case .imageCHW: return .imageCHW(s[0], s[1], s[2], stride: (t[0], t[1], t[2]))
            case .tensor3DFirstMajor: return .tensor3DFirstMajor(s[0], s[1], s[2], stride: (t[0], t[1], t[2]))
            case .tensor3DLastMajor: return .tensor3DLastMajor(s[0], s[1], s[2], stride: (t[0], t[1], t[2]))
            case .tensor3DSNE: return .tensor3DSNE(s[0], s[1], s[2], stride: (t[0], t[1], t[2]))
            case .tensor3DNSE: return .tensor3DNSE(s[0], s[1], s[2], stride: (t[0], t[1], t[2]))
            case .convolutionWeightsOIHW: return .convolutionWeightsOIHW(s[0], s[1], s[2], s[3], stride: (t[0], t[1], t[2], t[3]))
            case .tensor4DFirstMajor: return .tensor4DFirstMajor(s[0], s[1], s[2], s[3], stride: (t[0], t[1], t[2], t[3]))
            case .tensor4DLastMajor: return .tensor4DLastMajor(s[0], s[1], s[2], s[3], stride: (t[0], t[1], t[2], t[3]))
            case .tensor5DFirstMajor: return .tensor5DFirstMajor(s[0], s[1], s[2], s[3], s[4], stride: (t[0], t[1], t[2], t[3], t[4]))
            case .tensor5DLastMajor: return .tensor5DLastMajor(s[0], s[1], s[2], s[3], s[4], stride: (t[0], t[1], t[2], t[3], t[4]))
            case .tensor6DFirstMajor: return .tensor6DFirstMajor(s[0], s[1], s[2], s[3], s[4], s[5], stride: (t[0], t[1], t[2], t[3], t[4], t[5]))
            case .tensor6DLastMajor: return .tensor6DLastMajor(s[0], s[1], s[2], s[3], s[4], s[5], stride: (t[0], t[1], t[2], t[3], t[4], t[5]))
            case .tensor7DFirstMajor: return .tensor7DFirstMajor(s[0], s[1], s[2], s[3], s[4], s[5], s[6], stride: (t[0], t[1], t[2], t[3], t[4], t[5], t[6]))
            case .tensor7DLastMajor: return .tensor7DLastMajor(s[0], s[1], s[2], s[3], s[4], s[5], s[6], stride: (t[0], t[1], t[2], t[3], t[4], t[5], t[6]))
            case .tensor8DFirstMajor: return .tensor8DFirstMajor(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], stride: (t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]))
            case .tensor8DLastMajor: return .tensor8DLastMajor(s[0], s[1], s[2], s[3], s[4], s[5], s[6], s[7], stride: (t[0], t[1], t[2], t[3], t[4], t[5], t[6], t[7]))
            }
        }

        /// (layout, sizes, strides) of the shape.
        var _parts: (DataLayout, [Int], [Int]) {
            switch self {
            case let .vector(a, s): return (.vector, [a], [s])
            case let .matrixColumnMajor(a, b, s): return (.matrixColumnMajor, [a, b], [s.0, s.1])
            case let .matrixRowMajor(a, b, s): return (.matrixRowMajor, [a, b], [s.0, s.1])
            case let .matrixFirstMajor(a, b, s): return (.matrixFirstMajor, [a, b], [s.0, s.1])
            case let .matrixLastMajor(a, b, s): return (.matrixLastMajor, [a, b], [s.0, s.1])
            case let .imageCHW(a, b, c, s): return (.imageCHW, [a, b, c], [s.0, s.1, s.2])
            case let .tensor3DFirstMajor(a, b, c, s): return (.tensor3DFirstMajor, [a, b, c], [s.0, s.1, s.2])
            case let .tensor3DLastMajor(a, b, c, s): return (.tensor3DLastMajor, [a, b, c], [s.0, s.1, s.2])
            case let .tensor3DSNE(a, b, c, s): return (.tensor3DSNE, [a, b, c], [s.0, s.1, s.2])
            case let .tensor3DNSE(a, b, c, s): return (.tensor3DNSE, [a, b, c], [s.0, s.1, s.2])
            case let .convolutionWeightsOIHW(a, b, c, d, s): return (.convolutionWeightsOIHW, [a, b, c, d], [s.0, s.1, s.2, s.3])
            case let .tensor4DFirstMajor(a, b, c, d, s): return (.tensor4DFirstMajor, [a, b, c, d], [s.0, s.1, s.2, s.3])
            case let .tensor4DLastMajor(a, b, c, d, s): return (.tensor4DLastMajor, [a, b, c, d], [s.0, s.1, s.2, s.3])
            case let .tensor5DFirstMajor(a, b, c, d, e, s): return (.tensor5DFirstMajor, [a, b, c, d, e], [s.0, s.1, s.2, s.3, s.4])
            case let .tensor5DLastMajor(a, b, c, d, e, s): return (.tensor5DLastMajor, [a, b, c, d, e], [s.0, s.1, s.2, s.3, s.4])
            case let .tensor6DFirstMajor(a, b, c, d, e, f, s): return (.tensor6DFirstMajor, [a, b, c, d, e, f], [s.0, s.1, s.2, s.3, s.4, s.5])
            case let .tensor6DLastMajor(a, b, c, d, e, f, s): return (.tensor6DLastMajor, [a, b, c, d, e, f], [s.0, s.1, s.2, s.3, s.4, s.5])
            case let .tensor7DFirstMajor(a, b, c, d, e, f, g, s): return (.tensor7DFirstMajor, [a, b, c, d, e, f, g], [s.0, s.1, s.2, s.3, s.4, s.5, s.6])
            case let .tensor7DLastMajor(a, b, c, d, e, f, g, s): return (.tensor7DLastMajor, [a, b, c, d, e, f, g], [s.0, s.1, s.2, s.3, s.4, s.5, s.6])
            case let .tensor8DFirstMajor(a, b, c, d, e, f, g, h, s): return (.tensor8DFirstMajor, [a, b, c, d, e, f, g, h], [s.0, s.1, s.2, s.3, s.4, s.5, s.6, s.7])
            case let .tensor8DLastMajor(a, b, c, d, e, f, g, h, s): return (.tensor8DLastMajor, [a, b, c, d, e, f, g, h], [s.0, s.1, s.2, s.3, s.4, s.5, s.6, s.7])
            }
        }
        public var rank: Int { _parts.1.count }
        public var size: (Int, Int, Int, Int, Int, Int, Int, Int) { _bnnsTuple8(_parts.1) }
        public var stride: (Int, Int, Int, Int, Int, Int, Int, Int) { _bnnsTuple8(_parts.2) }
        public var layout: BNNSDataLayout { _parts.0.bnns }
        /// The number of elements one array of this shape spans (strides honoured; 0 strides are packed).
        public var batchStride: Int {
            let (l, size, stride) = _parts
            let firstMajor = (l.bnns.rawValue & 0xffff) == 0x8001
            let r = size.count
            var next = 1, span = 1
            for j in 0..<r {
                let k = firstMajor ? r - 1 - j : j
                let s = stride[j] != 0 ? stride[j] : next
                next = s * size[k]
                span = max(span, next)
            }
            return span
        }
    }
}
extension BNNS.Shape: ExpressibleByArrayLiteral {
    public typealias ArrayLiteralElement = Int
    public init(arrayLiteral: BNNS.Shape.ArrayLiteralElement...) { self.init(arrayLiteral) }
}

// MARK: - scalars

public protocol BNNSScalar {
    static var bnnsDataType: BNNSDataType { get }
}
extension Float: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeFloat32 } }
extension Float16: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeFloat16 } }
extension Int8: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeInt8 } }
extension Int16: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeInt16 } }
extension Int32: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeInt32 } }
extension UInt8: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeUInt8 } }
extension UInt16: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeUInt16 } }
extension UInt32: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeUInt32 } }
extension Bool: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeBoolean } }
extension Int64: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeInt64 } }
extension UInt64: BNNSScalar { public static var bnnsDataType: BNNSDataType { BNNSDataTypeUInt64 } }

// MARK: - the C types' conveniences

extension BNNSDataType {
    public static var float16: BNNSDataType { BNNSDataTypeFloat16 }
    public static var float: BNNSDataType { BNNSDataTypeFloat32 }
    public static var int8: BNNSDataType { BNNSDataTypeInt8 }
    public static var int16: BNNSDataType { BNNSDataTypeInt16 }
    public static var int32: BNNSDataType { BNNSDataTypeInt32 }
    public static var indexed8: BNNSDataType { BNNSDataTypeIndexed8 }
    public static var uint8: BNNSDataType { BNNSDataTypeUInt8 }
    public static var uint16: BNNSDataType { BNNSDataTypeUInt16 }
    public static var uint32: BNNSDataType { BNNSDataTypeUInt32 }
}
extension BNNSPoolingFunction {
    public static var max: BNNSPoolingFunction { BNNSPoolingFunctionMax }
    public static var average: BNNSPoolingFunction { BNNSPoolingFunctionAverage }
}
extension BNNSActivationFunction {
    public static var identity: BNNSActivationFunction { BNNSActivationFunctionIdentity }
    public static var rectifiedLinear: BNNSActivationFunction { BNNSActivationFunctionRectifiedLinear }
    public static var leakyRectifiedLinear: BNNSActivationFunction { BNNSActivationFunctionLeakyRectifiedLinear }
    public static var sigmoid: BNNSActivationFunction { BNNSActivationFunctionSigmoid }
    public static var tanh: BNNSActivationFunction { BNNSActivationFunctionTanh }
    public static var scaledTanh: BNNSActivationFunction { BNNSActivationFunctionScaledTanh }
    public static var abs: BNNSActivationFunction { BNNSActivationFunctionAbs }
    public static var linear: BNNSActivationFunction { BNNSActivationFunctionLinear }
    public static var clamp: BNNSActivationFunction { BNNSActivationFunctionClamp }
    public static var integerLinearSaturate: BNNSActivationFunction { BNNSActivationFunctionIntegerLinearSaturate }
    public static var integerLinearSaturatePerChannel: BNNSActivationFunction { BNNSActivationFunctionIntegerLinearSaturatePerChannel }
    public static var softmax: BNNSActivationFunction { BNNSActivationFunctionSoftmax }
}
extension BNNSFlags: OptionSet {
    public typealias ArrayLiteralElement = BNNSFlags
    public typealias Element = BNNSFlags
}
extension BNNSFlags {
    public static var useClientPointer: BNNSFlags { BNNSFlagsUseClientPtr }
}
extension BNNSFilterParameters {
    public init(options: BNNSFlags, threadCount: Int, allocator: BNNSAlloc?, deallocator: BNNSFree?) {
        self.init(flags: options.rawValue, n_threads: threadCount, alloc_memory: allocator, free_memory: deallocator)
    }
    public var options: BNNSFlags { get { BNNSFlags(rawValue: flags) } set { flags = newValue.rawValue } }
    public var threadCount: Int { get { n_threads } set { n_threads = newValue } }
    public var allocator: BNNSAlloc? { get { alloc_memory } set { alloc_memory = newValue } }
    public var deallocator: BNNSFree? { get { free_memory } set { free_memory = newValue } }
}
extension BNNSImageStackDescriptor {
    public init(width: Int, height: Int, channels: Int, row_stride: Int, image_stride: Int, data_type: BNNSDataType) {
        self.init(width: width, height: height, channels: channels, row_stride: row_stride, image_stride: image_stride,
                  data_type: data_type, data_scale: 1, data_bias: 0)
    }
}
extension BNNSVectorDescriptor {
    public init(size: Int, data_type: BNNSDataType) { self.init(size: size, data_type: data_type, data_scale: 1, data_bias: 0) }
}
extension BNNSLayerData {
    public init(data: UnsafeRawPointer?, data_type: BNNSDataType, data_scale: Float = 1, data_bias: Float = 0) {
        self.init(data: data, data_type: data_type, data_scale: data_scale, data_bias: data_bias, data_table: nil)
    }
    public static var zero: BNNSLayerData { BNNSLayerData() }
    public static func indexed8(data: UnsafePointer<Int8>?, data_table: UnsafePointer<Float>) -> BNNSLayerData {
        BNNSLayerData(data: data, data_type: BNNSDataTypeIndexed8, data_scale: 1, data_bias: 0, data_table: data_table)
    }
}
extension BNNSActivation {
    public init(function: BNNSActivationFunction, alpha: Float = .nan, beta: Float = .nan) {
        self.init()
        self.function = function; self.alpha = alpha; self.beta = beta
    }
    public static var identity: BNNSActivation { BNNSActivation(function: BNNSActivationFunctionIdentity) }
    public static func integerLinearSaturate(scale: Int32 = 1, offset: Int32 = 0, shift: Int32 = 0) -> BNNSActivation {
        var a = BNNSActivation(function: BNNSActivationFunctionIntegerLinearSaturate)
        a.iscale = scale; a.ioffset = offset; a.ishift = shift
        return a
    }
    public static func integerLinearSaturatePerChannel(scale: UnsafePointer<Int32>, offset: UnsafePointer<Int32>, shift: UnsafePointer<Int32>) -> BNNSActivation {
        var a = BNNSActivation(function: BNNSActivationFunctionIntegerLinearSaturatePerChannel)
        a.iscale_per_channel = scale; a.ioffset_per_channel = offset; a.ishift_per_channel = shift
        return a
    }
}
extension BNNSConvolutionLayerParameters {
    public init(x_stride: Int, y_stride: Int, x_padding: Int, y_padding: Int, k_width: Int, k_height: Int, in_channels: Int,
                out_channels: Int, weights: BNNSLayerData) {
        self.init(x_stride: x_stride, y_stride: y_stride, x_padding: x_padding, y_padding: y_padding, k_width: k_width,
                  k_height: k_height, in_channels: in_channels, out_channels: out_channels, weights: weights, bias: .zero,
                  activation: .identity)
    }
}
extension BNNSPoolingLayerParameters {
    public init(x_stride: Int, y_stride: Int, x_padding: Int, y_padding: Int, k_width: Int, k_height: Int, in_channels: Int,
                out_channels: Int, pooling_function: BNNSPoolingFunction) {
        self.init(x_stride: x_stride, y_stride: y_stride, x_padding: x_padding, y_padding: y_padding, k_width: k_width,
                  k_height: k_height, in_channels: in_channels, out_channels: out_channels, pooling_function: pooling_function,
                  bias: .zero, activation: .identity)
    }
}
extension BNNSFullyConnectedLayerParameters {
    public init(in_size: Int, out_size: Int, weights: BNNSLayerData) {
        self.init(in_size: in_size, out_size: out_size, weights: weights, bias: .zero, activation: .identity)
    }
}

// MARK: - BNNSNDArrayDescriptor

extension BNNSNDArrayDescriptor {
    public init(dataType: BNNSDataType, shape: BNNS.Shape) {
        self.init(flags: BNNSNDArrayFlagBackpropSet, layout: shape.layout, size: shape.size, stride: shape.stride, data: nil,
                  data_type: dataType, table_data: nil, table_data_type: BNNSDataTypeFloat32, data_scale: 1, data_bias: 0)
    }
    public init?(data: UnsafeMutableRawBufferPointer, scalarType: any BNNSScalar.Type, shape: BNNS.Shape) {
        self.init(data: data, scalarType: scalarType, shape: shape, batchSize: 1)
    }
    public init?<T>(data: UnsafeMutableBufferPointer<T>, shape: BNNS.Shape) where T: BNNSScalar {
        self.init(data: data, shape: shape, batchSize: 1)
    }
    public init?(data: UnsafeMutableRawBufferPointer, scalarType: any BNNSScalar.Type, shape: BNNS.Shape, batchSize: Int) {
        let t = scalarType.bnnsDataType
        guard data.count >= (shape.batchStride * batchSize * _bnnsBits(t) + 7) / 8 else { return nil }
        self.init(dataType: t, shape: shape)
        self.data = data.baseAddress
    }
    public init?<T>(data: UnsafeMutableBufferPointer<T>, shape: BNNS.Shape, batchSize: Int) where T: BNNSScalar {
        guard data.count >= shape.batchStride * batchSize else { return nil }
        self.init(dataType: T.bnnsDataType, shape: shape)
        self.data = UnsafeMutableRawPointer(data.baseAddress)
    }

    public var shape: BNNS.Shape {
        let l = BNNS.DataLayout(layout) ?? .vector
        let r = l.rank
        return BNNS.Shape._make(l, Array(_bnnsArray8(size).prefix(r)), Array(_bnnsArray8(stride).prefix(r)))
    }
    public var dataSize: Int { withUnsafePointer(to: self) { BNNSNDArrayGetDataSize($0) } }

    public static func allocateUninitialized(scalarType: any BNNSScalar.Type, shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor {
        var d = BNNSNDArrayDescriptor(dataType: scalarType.bnnsDataType, shape: shape)
        let bytes = (shape.batchStride * batchSize * _bnnsBits(d.data_type) + 7) / 8
        d.data = UnsafeMutableRawPointer.allocate(byteCount: max(bytes, 1), alignment: 64)
        return d
    }
    public static func allocate<C>(initializingFrom source: C, shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor
        where C: Collection, C.Element: BNNSScalar {
        let d = allocateUninitialized(scalarType: C.Element.self, shape: shape, batchSize: batchSize)
        let n = min(source.count, shape.batchStride * batchSize)
        let p = d.data!.bindMemory(to: C.Element.self, capacity: max(n, 1))
        for (i, v) in source.prefix(n).enumerated() { (p + i).initialize(to: v) }
        return d
    }
    public static func allocate<T>(repeating repeatedValue: T, shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor where T: BNNSScalar {
        allocate(initializingFrom: [T](repeating: repeatedValue, count: shape.batchStride * batchSize), shape: shape, batchSize: batchSize)
    }
    public static func allocate<Scalar>(randomIn range: ClosedRange<Scalar>, shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor
        where Scalar: BNNSScalar, Scalar: FixedWidthInteger {
        var g = SystemRandomNumberGenerator()
        return allocate(randomIn: range, using: &g, shape: shape, batchSize: batchSize)
    }
    public static func allocate<Scalar>(randomIn range: ClosedRange<Scalar>, shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor
        where Scalar: BNNSScalar, Scalar: BinaryFloatingPoint, Scalar.RawSignificand: FixedWidthInteger {
        var g = SystemRandomNumberGenerator()
        return allocate(randomIn: range, using: &g, shape: shape, batchSize: batchSize)
    }
    public static func allocate<Scalar, Generator>(randomIn range: ClosedRange<Scalar>, using generator: inout Generator, shape: BNNS.Shape,
                                                   batchSize: Int = 1) -> BNNSNDArrayDescriptor
        where Scalar: BNNSScalar, Scalar: FixedWidthInteger, Generator: RandomNumberGenerator {
        let n = shape.batchStride * batchSize
        return allocate(initializingFrom: (0..<n).map { _ in Scalar.random(in: range, using: &generator) }, shape: shape, batchSize: batchSize)
    }
    public static func allocate<Scalar, Generator>(randomIn range: ClosedRange<Scalar>, using generator: inout Generator, shape: BNNS.Shape,
                                                   batchSize: Int = 1) -> BNNSNDArrayDescriptor
        where Scalar: BNNSScalar, Scalar: BinaryFloatingPoint, Generator: RandomNumberGenerator, Scalar.RawSignificand: FixedWidthInteger {
        let n = shape.batchStride * batchSize
        return allocate(initializingFrom: (0..<n).map { _ in Scalar.random(in: range, using: &generator) }, shape: shape, batchSize: batchSize)
    }
    public static func allocate<Scalar>(randomUniformUsing generator: BNNS.RandomGenerator, range: ClosedRange<Scalar>, shape: BNNS.Shape,
                                        batchSize: Int = 1) -> BNNSNDArrayDescriptor? where Scalar: BNNSScalar, Scalar: BinaryFloatingPoint {
        var d = allocateUninitialized(scalarType: Scalar.self, shape: shape, batchSize: batchSize)
        d.size = _bnnsTuple8([shape.batchStride * batchSize]); d.layout = BNNSDataLayoutVector; d.stride = _bnnsTuple8([])
        let r = BNNSRandomFillUniformFloat(generator.bnnsRandomGenerator, &d, Float(range.lowerBound), Float(range.upperBound))
        var out = d; out.layout = shape.layout; out.size = shape.size; out.stride = shape.stride
        if r != 0 { out.deallocate(); return nil }
        return out
    }
    public static func allocate<Scalar>(randomUniformUsing generator: BNNS.RandomGenerator, range: ClosedRange<Scalar>, shape: BNNS.Shape,
                                        batchSize: Int = 1) -> BNNSNDArrayDescriptor? where Scalar: BNNSScalar, Scalar: FixedWidthInteger {
        var d = allocateUninitialized(scalarType: Scalar.self, shape: shape, batchSize: batchSize)
        d.size = _bnnsTuple8([shape.batchStride * batchSize]); d.layout = BNNSDataLayoutVector; d.stride = _bnnsTuple8([])
        let r = BNNSRandomFillUniformInt(generator.bnnsRandomGenerator, &d, Int64(range.lowerBound), Int64(range.upperBound))
        var out = d; out.layout = shape.layout; out.size = shape.size; out.stride = shape.stride
        if r != 0 { out.deallocate(); return nil }
        return out
    }
    public static func allocate<Scalar>(randomNormalUsing generator: BNNS.RandomGenerator, mean: Scalar, standardDeviation: Scalar,
                                        shape: BNNS.Shape, batchSize: Int = 1) -> BNNSNDArrayDescriptor?
        where Scalar: BNNSScalar, Scalar: BinaryFloatingPoint {
        var d = allocateUninitialized(scalarType: Scalar.self, shape: shape, batchSize: batchSize)
        d.size = _bnnsTuple8([shape.batchStride * batchSize]); d.layout = BNNSDataLayoutVector; d.stride = _bnnsTuple8([])
        let r = BNNSRandomFillNormalFloat(generator.bnnsRandomGenerator, &d, Float(mean), Float(standardDeviation))
        var out = d; out.layout = shape.layout; out.size = shape.size; out.stride = shape.stride
        if r != 0 { out.deallocate(); return nil }
        return out
    }
    public func makeArray<T>(of scalarType: T.Type, batchSize: Int = 1) -> [T]? {
        guard let data = data else { return nil }
        let n = shape.batchStride * batchSize
        if let s = T.self as? any BNNSScalar.Type, s.bnnsDataType != data_type { return nil }
        guard MemoryLayout<T>.stride * 8 == _bnnsBits(data_type) else { return nil }
        let p = data.bindMemory(to: T.self, capacity: n)
        return Array(UnsafeBufferPointer(start: p, count: n))
    }
    public func deallocate() { data?.deallocate() }

    /// The pointer `n` batch elements in.
    func _data(batch: Int) -> UnsafeMutableRawPointer? {
        data.map { $0 + batch * shape.batchStride * _bnnsBits(data_type) / 8 }
    }
}

// MARK: - BNNSTensor

extension BNNSTensor {
    /// Contiguous first-major strides for a shape.
    static func _defaultStride(_ shape: [Int]) -> [Int] {
        var s = [Int](repeating: 1, count: shape.count), next = 1
        for k in Swift.stride(from: shape.count - 1, through: 0, by: -1) { s[k] = next; next *= shape[k] }
        return s
    }
    public init(dataType: BNNSDataType, shape: [Int], stride: [Int]) {
        self.init()
        let st = stride.isEmpty ? BNNSTensor._defaultStride(shape) : stride
        self.data_type = dataType
        self.rank = UInt8(shape.count)
        self.shape = _bnnsTuple8(shape)
        self.stride = _bnnsTuple8(st)
    }
    public init(shape: [Int], stride: [Int], dataType: BNNSDataType) { self.init(dataType: dataType, shape: shape, stride: stride) }
    public init(data: UnsafeMutableRawBufferPointer, shape: [Int], stride: [Int], dataType: BNNSDataType) {
        self.init(dataType: dataType, shape: shape, stride: stride)
        self.data = data.baseAddress
        self.data_size_in_bytes = data.count
    }
    public init<T>(data: UnsafeMutableBufferPointer<T>, shape: [Int], stride: [Int]) where T: BNNSScalar {
        self.init(data: UnsafeMutableRawBufferPointer(data), shape: shape, stride: stride, dataType: T.bnnsDataType)
    }
    public init<T>(initializingFrom source: some AccelerateBuffer<T>, shape: [Int], stride: [Int]) where T: BNNSScalar {
        self.init(dataType: T.bnnsDataType, shape: shape, stride: stride)
        allocate(initializingFrom: source)
    }
    public var count: Int {
        let r = Int(rank)
        return withUnsafeBytes(of: shape) { Array($0.bindMemory(to: Int.self).prefix(r)) }.reduce(1, *)
    }
    public mutating func allocate<T>(as scalarType: T.Type, count: Int) where T: BNNSScalar {
        let p = UnsafeMutablePointer<T>.allocate(capacity: max(count, 1))
        data = UnsafeMutableRawPointer(p)
        data_size_in_bytes = count * MemoryLayout<T>.stride
        data_type = T.bnnsDataType
    }
    public mutating func allocate<T>(initializingFrom source: some AccelerateBuffer<T>) where T: BNNSScalar {
        let n = source.count
        allocate(as: T.self, count: n)
        let p = data!.bindMemory(to: T.self, capacity: max(n, 1))
        source.withUnsafeBufferPointer { b in for i in 0..<n { (p + i).initialize(to: b[i]) } }
    }
    public static func allocateUninitialized(scalarType: any BNNSScalar.Type, shape: [Int], stride: [Int]) -> BNNSTensor {
        var t = BNNSTensor(dataType: scalarType.bnnsDataType, shape: shape, stride: stride)
        let bytes = withUnsafePointer(to: t) { BNNSTensorGetAllocationSize($0) }
        let n = bytes == Int.max ? 0 : bytes
        t.data = UnsafeMutableRawPointer.allocate(byteCount: max(n, 1), alignment: 64)
        t.data_size_in_bytes = n
        return t
    }
    public static func allocate<C>(initializingFrom source: C, shape: [Int], stride: [Int]) -> BNNSTensor where C: AccelerateBuffer, C.Element: BNNSScalar {
        var t = BNNSTensor(dataType: C.Element.bnnsDataType, shape: shape, stride: stride)
        t.allocate(initializingFrom: source)
        return t
    }
    public static func allocate<T>(repeating repeatedValue: T, shape: [Int], stride: [Int]) -> BNNSTensor where T: BNNSScalar {
        allocate(initializingFrom: [T](repeating: repeatedValue, count: shape.reduce(1, *)), shape: shape, stride: stride)
    }
    public func makeArray<T>(of scalarType: T.Type) -> [T] where T: BNNSScalar {
        guard let data = data else { return [] }
        let n = data_size_in_bytes / MemoryLayout<T>.stride
        return Array(UnsafeBufferPointer(start: data.bindMemory(to: T.self, capacity: n), count: n))
    }
    public func deallocate() { data?.deallocate() }
}

extension vImage.PixelBuffer where Format: StaticPixelFormat, Format.ComponentType: BNNSScalar {
    /// The pixels as a first-major tensor (height, width, channels), without copying.
    public func withBNNSTensor<R>(_ body: (BNNSTensor) throws -> R) rethrows -> R {
        try withUnsafeVImageBuffers { buffers in
            let b = buffers[0], c = Format.channelCount, cs = MemoryLayout<Format.ComponentType>.stride
            let raw = UnsafeMutableRawBufferPointer(start: b.data, count: b.rowBytes * Int(b.height))
            let t = BNNSTensor(data: raw, shape: [Int(b.height), Int(b.width), c], stride: [b.rowBytes / cs, c, 1],
                               dataType: Format.ComponentType.bnnsDataType)
            return try body(t)
        }
    }
}

// MARK: - activation functions

extension BNNS {
    public enum ActivationFunction {
        case identity
        case rectifiedLinear
        case leakyRectifiedLinear(alpha: Float)
        case sigmoid
        case logSigmoid
        case tanh
        case scaledTanh(alpha: Float, beta: Float)
        case abs
        case linear(alpha: Float)
        case clamp(bounds: ClosedRange<Float>)
        case softmax
        case geluApproximation(alpha: Float, beta: Float)
        case geluApproximation2(alpha: Float, beta: Float)
        case gumbel(alpha: Float, beta: Float)
        case gumbelMax(alpha: Float, beta: Float)
        case hardSigmoid(alpha: Float, beta: Float)
        case softplus(alpha: Float, beta: Float)
        case softsign
        case elu(alpha: Float)
        case selu
        case celu(alpha: Float)
        case clampedLeakyRectifiedLinear(alpha: Float, beta: Float)
        case linearWithBias(alpha: Float, beta: Float)
        case logSoftmax
        case hardShrink(alpha: Float)
        case softShrink(alpha: Float)
        case tanhShrink
        case threshold(alpha: Float, beta: Float)
        case hardSwish(alpha: Float, beta: Float)
        case silu

        public var bnnsActivation: BNNSActivation {
            func a(_ f: BNNSActivationFunction, _ al: Float = 0, _ be: Float = 0) -> BNNSActivation {
                BNNSActivation(function: f, alpha: al, beta: be)
            }
            switch self {
            case .identity: return a(BNNSActivationFunctionIdentity)
            case .rectifiedLinear: return a(BNNSActivationFunctionRectifiedLinear)
            case let .leakyRectifiedLinear(al): return a(BNNSActivationFunctionLeakyRectifiedLinear, al)
            case .sigmoid: return a(BNNSActivationFunctionSigmoid)
            case .logSigmoid: return a(BNNSActivationFunctionLogSigmoid)
            case .tanh: return a(BNNSActivationFunctionTanh)
            case let .scaledTanh(al, be): return a(BNNSActivationFunctionScaledTanh, al, be)
            case .abs: return a(BNNSActivationFunctionAbs)
            case let .linear(al): return a(BNNSActivationFunctionLinear, al)
            case let .clamp(b): return a(BNNSActivationFunctionClamp, b.lowerBound, b.upperBound)
            case .softmax: return a(BNNSActivationFunctionSoftmax)
            case let .geluApproximation(al, be): return a(BNNSActivationFunctionGELUApproximation, al, be)
            case let .geluApproximation2(al, be): return a(BNNSActivationFunctionGELUApproximation2, al, be)
            case let .gumbel(al, be): return a(BNNSActivationFunctionGumbel, al, be)
            case let .gumbelMax(al, be): return a(BNNSActivationFunctionGumbelMax, al, be)
            case let .hardSigmoid(al, be): return a(BNNSActivationFunctionHardSigmoid, al, be)
            case let .softplus(al, be): return a(BNNSActivationFunctionSoftplus, al, be)
            case .softsign: return a(BNNSActivationFunctionSoftsign)
            case let .elu(al): return a(BNNSActivationFunctionELU, al)
            case .selu: return a(BNNSActivationFunctionSELU)
            case let .celu(al): return a(BNNSActivationFunctionCELU, al)
            case let .clampedLeakyRectifiedLinear(al, be): return a(BNNSActivationFunctionClampedLeakyRectifiedLinear, al, be)
            case let .linearWithBias(al, be): return a(BNNSActivationFunctionLinearWithBias, al, be)
            case .logSoftmax: return a(BNNSActivationFunctionLogSoftmax)
            case let .hardShrink(al): return a(BNNSActivationFunctionHardShrink, al)
            case let .softShrink(al): return a(BNNSActivationFunctionSoftShrink, al)
            case .tanhShrink: return a(BNNSActivationFunctionTanhShrink)
            case let .threshold(al, be): return a(BNNSActivationFunctionThreshold, al, be)
            case let .hardSwish(al, be): return a(BNNSActivationFunctionHardSwish, al, be)
            case .silu: return a(BNNSActivationFunctionSiLU)
            }
        }
    }
}

// MARK: - enumerations of the layers and functions

extension BNNS {
    public enum ArithmeticUnaryFunction: CaseIterable, Hashable {
        case squareRoot, reciprocalSquareRoot, floor, ceil, round, sin, cos, tan, asin, acos, atan, sinh, cosh, tanh, asinh,
             acosh, atanh, exp, exp2, log, log2, abs, sign, negate, reciprocal, square, erf
        public static var allCases: [BNNS.ArithmeticUnaryFunction] {
            [.squareRoot, .reciprocalSquareRoot, .floor, .ceil, .round, .sin, .cos, .tan, .asin, .acos, .atan, .sinh, .cosh, .tanh,
             .asinh, .acosh, .atanh, .exp, .exp2, .log, .log2, .abs, .sign, .negate, .reciprocal, .square, .erf]
        }
        public typealias AllCases = [BNNS.ArithmeticUnaryFunction]
        public var bnnsArithmeticFunction: BNNSArithmeticFunction {
            switch self {
            case .squareRoot: return BNNSArithmeticSquareRoot
            case .reciprocalSquareRoot: return BNNSArithmeticReciprocalSquareRoot
            case .floor: return BNNSArithmeticFloor
            case .ceil: return BNNSArithmeticCeil
            case .round: return BNNSArithmeticRound
            case .sin: return BNNSArithmeticSin
            case .cos: return BNNSArithmeticCos
            case .tan: return BNNSArithmeticTan
            case .asin: return BNNSArithmeticAsin
            case .acos: return BNNSArithmeticAcos
            case .atan: return BNNSArithmeticAtan
            case .sinh: return BNNSArithmeticSinh
            case .cosh: return BNNSArithmeticCosh
            case .tanh: return BNNSArithmeticTanh
            case .asinh: return BNNSArithmeticAsinh
            case .acosh: return BNNSArithmeticAcosh
            case .atanh: return BNNSArithmeticAtanh
            case .exp: return BNNSArithmeticExp
            case .exp2: return BNNSArithmeticExp2
            case .log: return BNNSArithmeticLog
            case .log2: return BNNSArithmeticLog2
            case .abs: return BNNSArithmeticAbs
            case .sign: return BNNSArithmeticSign
            case .negate: return BNNSArithmeticNegate
            case .reciprocal: return BNNSArithmeticReciprocal
            case .square: return BNNSArithmeticSquare
            case .erf: return BNNSArithmeticErf
            }
        }
    }
    public enum ArithmeticBinaryFunction: CaseIterable, Hashable {
        case add, subtract, multiply, multiplyNoNaN, divide, divideNoNaN, pow, max, min, flooringDivide, truncatingDivide,
             truncatingRemainder
        public static var allCases: [BNNS.ArithmeticBinaryFunction] {
            [.add, .subtract, .multiply, .multiplyNoNaN, .divide, .divideNoNaN, .pow, .max, .min, .flooringDivide, .truncatingDivide,
             .truncatingRemainder]
        }
        public typealias AllCases = [BNNS.ArithmeticBinaryFunction]
        public var bnnsArithmeticFunction: BNNSArithmeticFunction {
            switch self {
            case .add: return BNNSArithmeticAdd
            case .subtract: return BNNSArithmeticSubtract
            case .multiply: return BNNSArithmeticMultiply
            case .multiplyNoNaN: return BNNSArithmeticMultiplyNoNaN
            case .divide: return BNNSArithmeticDivide
            case .divideNoNaN: return BNNSArithmeticDivideNoNaN
            case .pow: return BNNSArithmeticPow
            case .max: return BNNSArithmeticMaximum
            case .min: return BNNSArithmeticMinimum
            case .flooringDivide: return BNNSArithmeticFloorDivide
            case .truncatingDivide: return BNNSArithmeticTruncDivide
            case .truncatingRemainder: return BNNSArithmeticTruncRemainder
            }
        }
    }
    public enum ArithmeticTernaryFunction: Hashable {
        case multiplyAdd
        public var bnnsArithmeticFunction: BNNSArithmeticFunction { BNNSArithmeticMultiplyAdd }
    }
    public enum ReductionFunction {
        case max
        case min
        case maxIndex
        case argMax
        case minIndex
        case argMin
        case mean
        case meanNonZero
        case sum
        case sumOfSquares
        case sumOfLogs(epsilon: Float)
        case sumOfAbsolutes
        case logicalOr
        case any
        case logicalAnd
        case all
        case l2Norm
        case logSumExp
        case product
        public var bnnsReduceFunction: BNNSReduceFunction {
            switch self {
            case .max: return BNNSReduceFunctionMax
            case .min: return BNNSReduceFunctionMin
            case .maxIndex, .argMax: return BNNSReduceFunctionArgMax
            case .minIndex, .argMin: return BNNSReduceFunctionArgMin
            case .mean: return BNNSReduceFunctionMean
            case .meanNonZero: return BNNSReduceFunctionMeanNonZero
            case .sum: return BNNSReduceFunctionSum
            case .sumOfSquares: return BNNSReduceFunctionSumSquare
            case .sumOfLogs: return BNNSReduceFunctionSumLog
            case .sumOfAbsolutes: return BNNSReduceFunctionL1Norm
            case .logicalOr, .any: return BNNSReduceFunctionLogicalOr
            case .logicalAnd, .all: return BNNSReduceFunctionLogicalAnd
            case .l2Norm: return BNNSReduceFunctionL2Norm
            case .logSumExp: return BNNSReduceFunctionLogSumExp
            case .product: return BNNSReduceFunctionProduct
            }
        }
        var epsilon: Float { if case let .sumOfLogs(e) = self { return e }; return 0 }
    }
    @frozen public struct RelationalOperator {
        @usableFromInline internal var value: BNNSRelationalOperator
        @usableFromInline @inline(__always) internal init(_ value: BNNSRelationalOperator) { self.value = value }
        @inlinable public static var equal: BNNS.RelationalOperator { Self(BNNSRelationalOperatorEqual) }
        @inlinable public static var less: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLess) }
        @inlinable public static var lessEqual: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLessEqual) }
        @inlinable public static var greater: BNNS.RelationalOperator { Self(BNNSRelationalOperatorGreater) }
        @inlinable public static var greaterEqual: BNNS.RelationalOperator { Self(BNNSRelationalOperatorGreaterEqual) }
        @inlinable public static var notEqual: BNNS.RelationalOperator { Self(BNNSRelationalOperatorNotEqual) }
        @inlinable public static var and: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalAND) }
        @inlinable public static var or: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalOR) }
        @inlinable public static var not: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalNOT) }
        @inlinable public static var nand: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalNAND) }
        @inlinable public static var nor: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalNOR) }
        @inlinable public static var xor: BNNS.RelationalOperator { Self(BNNSRelationalOperatorLogicalXOR) }
    }
    public enum ShuffleType: Hashable {
        case depthToSpaceNCHW
        case spaceToDepthNCHW
    }
    public enum InterpolationMethod: Hashable {
        case linear
        case nearestNeighbor
    }
    public enum GradientClipping {
        case none
        case byValue(bounds: ClosedRange<Float>)
        case byNorm(threshold: Float)
        case byGlobalNorm(threshold: Float, globalNorm: Float = 0)
    }
}
extension BNNS.RelationalOperator: Sendable {}
extension BNNS.RelationalOperator: BitwiseCopyable {}

// MARK: - direct functions

extension BNNS {
    public static func copy(_ source: BNNSNDArrayDescriptor, to destination: BNNSNDArrayDescriptor,
                            filterParameters: BNNSFilterParameters? = nil) throws {
        var s = source, d = destination
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSCopy(&d, &s, fp)) }
    }
    public static func transpose(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, firstTransposeAxis: Int,
                                 secondTransposeAxis: Int, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSTranspose(&o, &i, firstTransposeAxis, secondTransposeAxis, fp)) }
    }
    public static func tile(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSTile(&i, &o, fp)) }
    }
    public static func tileBackward(outputGradient: BNNSNDArrayDescriptor, generatingInputGradient inputGradient: BNNSNDArrayDescriptor,
                                    filterParameters: BNNSFilterParameters? = nil) throws {
        var g = outputGradient, ig = inputGradient
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSTileBackward(&ig, &g, fp)) }
    }
    public static func copyBandPart(_ source: BNNSNDArrayDescriptor, to destination: BNNSNDArrayDescriptor, lowerBandCount: Int?,
                                    upperBandCount: Int?, filterParameters: BNNSFilterParameters? = nil) throws {
        var s = source, d = destination
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSBandPart(Int32(lowerBandCount ?? -1), Int32(upperBandCount ?? -1), &s, &d, fp))
        }
    }
    public static func shuffle(_ shuffleType: BNNS.ShuffleType, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                               filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, o = output
        let t = shuffleType == .depthToSpaceNCHW ? BNNSShuffleTypeDepthToSpaceNCHW : BNNSShuffleTypeSpaceToDepthNCHW
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSShuffle(t, &i, &o, fp)) }
    }
    public static func gather(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int,
                              filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSGather(axis, &i, &x, &o, fp)) }
    }
    public static func gatherND(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSGatherND(&i, &x, &o, fp)) }
    }
    public static func scatter(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int,
                               reductionFunction: BNNS.ReductionFunction, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSScatter(axis, reductionFunction.bnnsReduceFunction, &i, &x, &o, fp)) }
    }
    public static func scatterND(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 reductionFunction: BNNS.ReductionFunction, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSScatterND(reductionFunction.bnnsReduceFunction, &i, &x, &o, fp)) }
    }
    public static func scatter(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int,
                               filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSScatter(axis, BNNSReduceFunctionNone, &i, &x, &o, fp)) }
    }
    public static func scatterND(input: BNNSNDArrayDescriptor, indices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                 filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, x = indices, o = output
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSScatterND(BNNSReduceFunctionNone, &i, &x, &o, fp)) }
    }
    public static func applyTopK(k: Int, input: BNNSNDArrayDescriptor, bestValues: BNNSNDArrayDescriptor, bestIndices: BNNSNDArrayDescriptor,
                                 axis: Int, batchSize: Int, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, v = bestValues, x = bestIndices
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSDirectApplyTopK(k, axis, batchSize, &i, input.shape.batchStride, &v, bestValues.shape.batchStride, &x,
                                               bestIndices.shape.batchStride, fp))
        }
    }
    public static func applyInTopK(k: Int, input: BNNSNDArrayDescriptor, testIndices: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                   axis: Int, batchSize: Int, filterParameters: BNNSFilterParameters? = nil) throws {
        var i = input, t = testIndices, o = output
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSDirectApplyInTopK(k, axis, batchSize, &i, input.shape.batchStride, &t, testIndices.shape.batchStride, &o,
                                                 output.shape.batchStride, fp))
        }
    }
    public static func compare(_ inputA: BNNSNDArrayDescriptor, _ inputB: BNNSNDArrayDescriptor, using relationalOperator: BNNS.RelationalOperator,
                               output: BNNSNDArrayDescriptor) throws {
        var a = inputA, b = inputB, o = output
        try _bnnsCheck(BNNSCompareTensor(&a, &b, relationalOperator.value, &o))
    }
    public static func applyReduction(_ reductionFunction: BNNS.ReductionFunction, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                      weights: BNNSNDArrayDescriptor?, filterParameters: BNNSFilterParameters? = nil) throws {
        var p = BNNSLayerParametersReduction(i_desc: input, o_desc: output, w_desc: weights ?? BNNSNDArrayDescriptor(),
                                             reduce_func: reductionFunction.bnnsReduceFunction, epsilon: reductionFunction.epsilon)
        try _bnnsWithOptional(filterParameters) { fp in try _bnnsCheck(BNNSDirectApplyReduction(&p, fp)) }
    }
    public static func applyActivation(activation: BNNS.ActivationFunction, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor,
                                       batchSize: Int, filterParameters: BNNSFilterParameters? = nil) throws {
        try applyActivation(activation: activation, axes: [], input: input, output: output, batchSize: batchSize, filterParameters: filterParameters)
    }
    public static func applyActivation(activation: BNNS.ActivationFunction, axes: [Int], input: BNNSNDArrayDescriptor,
                                       output: BNNSNDArrayDescriptor, batchSize: Int, filterParameters: BNNSFilterParameters? = nil) throws {
        var p = BNNSLayerParametersActivation(i_desc: input, o_desc: output, activation: activation.bnnsActivation, axis_flags: _bnnsAxisFlags(axes))
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSDirectApplyActivationBatch(&p, fp, batchSize, input.shape.batchStride, output.shape.batchStride))
        }
    }
    public static func matrixMultiplicationWorkspaceSize(inputA: BNNSNDArrayDescriptor, transposed transposeA: Bool, inputB: BNNSNDArrayDescriptor,
                                                         transposed transposeB: Bool, output: BNNSNDArrayDescriptor, alpha: Float,
                                                         filterParameters: BNNSFilterParameters? = nil) -> Int? {
        var a = inputA, b = inputB, o = output
        let n = _bnnsWithOptional(filterParameters) { fp in BNNSMatMulWorkspaceSize(transposeA, transposeB, alpha, &a, &b, &o, fp) }
        return n < 0 ? nil : n
    }
    public static func applyMatrixMultiplication(inputA: BNNSNDArrayDescriptor, transposed transposeA: Bool, inputB: BNNSNDArrayDescriptor,
                                                 transposed transposeB: Bool, output: BNNSNDArrayDescriptor, alpha: Float,
                                                 workspace: UnsafeMutableRawBufferPointer?, filterParameters: BNNSFilterParameters? = nil) throws {
        var a = inputA, b = inputB, o = output
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSMatMul(transposeA, transposeB, alpha, &a, &b, &o, workspace?.baseAddress, fp))
        }
    }
    static func _quantize(_ f: BNNSQuantizerFunction, batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int?,
                          scale: BNNSNDArrayDescriptor?, bias: BNNSNDArrayDescriptor?, filterParameters: BNNSFilterParameters?) throws {
        var p = BNNSLayerParametersQuantization(axis_mask: axis.map { 1 << $0 } ?? 0, function: f, i_desc: input, o_desc: output,
                                                scale: scale ?? BNNSNDArrayDescriptor(), bias: bias ?? BNNSNDArrayDescriptor())
        try _bnnsWithOptional(filterParameters) { fp in
            try _bnnsCheck(BNNSDirectApplyQuantizer(&p, fp, batchSize, input.shape.batchStride, output.shape.batchStride))
        }
    }
    public static func quantize(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int? = nil,
                                scale: BNNSNDArrayDescriptor?, bias: BNNSNDArrayDescriptor?, filterParameters: BNNSFilterParameters? = nil) throws {
        try _quantize(BNNSQuantizerFunctionQuantize, batchSize: batchSize, input: input, output: output, axis: axis, scale: scale, bias: bias,
                      filterParameters: filterParameters)
    }
    public static func dequantize(batchSize: Int, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axis: Int? = nil,
                                  scale: BNNSNDArrayDescriptor?, bias: BNNSNDArrayDescriptor?, filterParameters: BNNSFilterParameters? = nil) throws {
        try _quantize(BNNSQuantizerFunctionDequantize, batchSize: batchSize, input: input, output: output, axis: axis, scale: scale, bias: bias,
                      filterParameters: filterParameters)
    }
    public static func computeNorm(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axes: [Int]? = nil) throws {
        var i = input, o = output
        try _bnnsCheck(BNNSComputeNorm(&o, &i, BNNSL2Norm, _bnnsAxisFlags(axes)))
    }
    public static func computeNormBackward(input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axes: [Int]? = nil,
                                           outputGradient: BNNSNDArrayDescriptor, generatingInputGradient inputGradient: BNNSNDArrayDescriptor) throws {
        guard let x = input.data, let y = output.data else { throw BNNS.Error.arrayDescriptorInvalidData }
        var g = outputGradient, ig = inputGradient
        try _bnnsCheck(BNNSComputeNormBackward(x, &ig, y, &g, BNNSL2Norm, _bnnsAxisFlags(axes)))
    }
    public static func clip(to bounds: ClosedRange<Float>, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor) throws {
        var i = input, o = output
        try _bnnsCheck(BNNSClipByValue(&o, &i, bounds.lowerBound, bounds.upperBound))
    }
    public static func clipByNorm(threshold: Float, input: BNNSNDArrayDescriptor, output: BNNSNDArrayDescriptor, axes: [Int]? = nil) throws {
        var i = input, o = output
        try _bnnsCheck(BNNSClipByNorm(&o, &i, threshold, _bnnsAxisFlags(axes)))
    }
    public static func clipByGlobalNorm(threshold: Float, inputs: [BNNSNDArrayDescriptor], outputs: [BNNSNDArrayDescriptor], globalNorm: Float = 0) throws {
        guard inputs.count == outputs.count else { throw BNNS.Error.arrayDescriptorInvalidData }
        var i = inputs, o = outputs
        try i.withUnsafeMutableBufferPointer { ib in
            try o.withUnsafeMutableBufferPointer { ob in
                var ip: [UnsafePointer<BNNSNDArrayDescriptor>] = (0..<ib.count).map { UnsafePointer(ib.baseAddress! + $0) }
                var op: [UnsafeMutablePointer<BNNSNDArrayDescriptor>] = (0..<ob.count).map { ob.baseAddress! + $0 }
                try _bnnsCheck(BNNSClipByGlobalNorm(&op, &ip, inputs.count, threshold, globalNorm))
            }
        }
    }
}

// MARK: - optimizers

public protocol BNNSOptimizer {
    func step(parameters: [BNNSNDArrayDescriptor], gradients: [BNNSNDArrayDescriptor], accumulators: [BNNSNDArrayDescriptor],
              filterParameters: BNNSFilterParameters?) throws
    var bnnsOptimizerFunction: BNNSOptimizerFunction { get }
    var accumulatorCountMultiplier: Int { get }
}
extension BNNSOptimizer {
    public func step(parameters: [BNNSNDArrayDescriptor], gradients: [BNNSNDArrayDescriptor], accumulators: [BNNSNDArrayDescriptor],
                     filterParameters: BNNSFilterParameters? = nil) throws {
        try _bnnsOptimizerStep(self, parameters: parameters, gradients: gradients, accumulators: accumulators, filterParameters: filterParameters)
    }
}
protocol _BNNSOptimizerFields {
    func _withFields<R>(_ body: (UnsafeRawPointer) throws -> R) rethrows -> R
}
func _bnnsOptimizerStep(_ o: any BNNSOptimizer, parameters: [BNNSNDArrayDescriptor], gradients: [BNNSNDArrayDescriptor],
                        accumulators: [BNNSNDArrayDescriptor], filterParameters: BNNSFilterParameters?) throws {
    guard parameters.count == gradients.count, let f = o as? _BNNSOptimizerFields else { throw BNNS.Error.optimizerStepFail }
    var p = parameters, g = gradients, a = accumulators
    try p.withUnsafeMutableBufferPointer { pb in
        try g.withUnsafeMutableBufferPointer { gb in
            try a.withUnsafeMutableBufferPointer { ab in
                var pp: [UnsafeMutablePointer<BNNSNDArrayDescriptor>] = (0..<pb.count).map { pb.baseAddress! + $0 }
                var gp: [UnsafePointer<BNNSNDArrayDescriptor>] = (0..<gb.count).map { UnsafePointer(gb.baseAddress! + $0) }
                var ap: [UnsafeMutablePointer<BNNSNDArrayDescriptor>?] = (0..<ab.count).map { ab.baseAddress! + $0 }
                let r: Int32 = f._withFields { fields in
                    _bnnsWithOptional(filterParameters) { fp in
                        ap.isEmpty ? BNNSOptimizerStep(o.bnnsOptimizerFunction, fields, pp.count, &pp, &gp, nil, fp)
                                   : BNNSOptimizerStep(o.bnnsOptimizerFunction, fields, pp.count, &pp, &gp, &ap, fp)
                    }
                }
                try _bnnsCheck(r, .optimizerStepFail)
            }
        }
    }
}
/// The clipping fields of a "with clipping" optimizer structure.
func _bnnsClipping(_ c: BNNS.GradientClipping) -> (BNNSOptimizerClippingFunction, Float, Float, Float, Float) {
    switch c {
    case .none: return (BNNSOptimizerClippingNone, 0, 0, 0, 0)
    case let .byValue(b): return (BNNSOptimizerClippingByValue, b.lowerBound, b.upperBound, 0, 0)
    case let .byNorm(t): return (BNNSOptimizerClippingByNorm, 0, 0, t, 0)
    case let .byGlobalNorm(t, n): return (BNNSOptimizerClippingByGlobalNorm, 0, 0, t, n)
    }
}
func _bnnsGradientClipping(_ f: BNNSOptimizerClippingFunction, _ mn: Float, _ mx: Float, _ norm: Float, _ use: Float) -> BNNS.GradientClipping {
    switch f {
    case BNNSOptimizerClippingByValue: return .byValue(bounds: mn...mx)
    case BNNSOptimizerClippingByNorm: return .byNorm(threshold: norm)
    case BNNSOptimizerClippingByGlobalNorm: return .byGlobalNorm(threshold: norm, globalNorm: use)
    default: return .none
    }
}

extension BNNS {
    public struct SGDMomentumOptimizer: BNNSOptimizer, _BNNSOptimizerFields {
        var f = BNNSOptimizerSGDMomentumWithClippingFields()
        public var accumulatorCountMultiplier: Int { 1 }
        public var learningRate: Float { get { f.learning_rate } set { f.learning_rate = newValue } }
        public var momentum: Float { get { f.momentum } set { f.momentum = newValue } }
        public var gradientScale: Float { get { f.gradient_scale } set { f.gradient_scale = newValue } }
        public var regularizationScale: Float { get { f.regularization_scale } set { f.regularization_scale = newValue } }
        public var gradientBounds: ClosedRange<Float>? {
            get { if case let .byValue(b) = gradientClipping { return b }; return nil }
            set { gradientClipping = newValue.map { .byValue(bounds: $0) } ?? .none }
        }
        public var usesNestrovMomentum: Bool { get { f.nesterov } set { f.nesterov = newValue } }
        public var usesNesterovMomentum: Bool { get { f.nesterov } set { f.nesterov = newValue } }
        public var regularizationFunction: BNNSOptimizerRegularizationFunction { get { f.regularization_func } set { f.regularization_func = newValue } }
        public var sgdMomentumVariant: BNNSOptimizerSGDMomentumVariant { get { f.sgd_momentum_variant } set { f.sgd_momentum_variant = newValue } }
        public var gradientClipping: BNNS.GradientClipping {
            get { _bnnsGradientClipping(f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) }
            set { (f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) = _bnnsClipping(newValue) }
        }
        public init(learningRate: Float, momentum: Float, gradientScale: Float, regularizationScale: Float,
                    clipsGradientsTo gradientBounds: ClosedRange<Float>? = nil, usesNestrovMomentum: Bool,
                    regularizationFunction: BNNSOptimizerRegularizationFunction, sgdMomentumVariant: BNNSOptimizerSGDMomentumVariant) {
            self.init(learningRate: learningRate, momentum: momentum, gradientScale: gradientScale, regularizationScale: regularizationScale,
                      clipsGradientsTo: gradientBounds, usesNesterovMomentum: usesNestrovMomentum, regularizationFunction: regularizationFunction,
                      sgdMomentumVariant: sgdMomentumVariant)
        }
        public init(learningRate: Float, momentum: Float, gradientScale: Float, regularizationScale: Float,
                    clipsGradientsTo gradientBounds: ClosedRange<Float>? = nil, usesNesterovMomentum: Bool,
                    regularizationFunction: BNNSOptimizerRegularizationFunction, sgdMomentumVariant: BNNSOptimizerSGDMomentumVariant) {
            self.init(learningRate: learningRate, momentum: momentum, gradientScale: gradientScale, regularizationScale: regularizationScale,
                      gradientClipping: gradientBounds.map { .byValue(bounds: $0) } ?? .none, usesNesterovMomentum: usesNesterovMomentum,
                      regularizationFunction: regularizationFunction, sgdMomentumVariant: sgdMomentumVariant)
        }
        public init(learningRate: Float, momentum: Float = 0, gradientScale: Float, regularizationScale: Float, gradientClipping: BNNS.GradientClipping,
                    usesNesterovMomentum: Bool = false, regularizationFunction: BNNSOptimizerRegularizationFunction,
                    sgdMomentumVariant: BNNSOptimizerSGDMomentumVariant) {
            self.learningRate = learningRate; self.momentum = momentum; self.gradientScale = gradientScale
            self.regularizationScale = regularizationScale; self.gradientClipping = gradientClipping
            self.usesNesterovMomentum = usesNesterovMomentum; self.regularizationFunction = regularizationFunction
            self.sgdMomentumVariant = sgdMomentumVariant
        }
        public var bnnsOptimizerFunction: BNNSOptimizerFunction { BNNSOptimizerFunctionSGDMomentumWithClipping }
        func _withFields<R>(_ body: (UnsafeRawPointer) throws -> R) rethrows -> R { var c = f; return try withUnsafePointer(to: &c) { try body($0) } }
    }

    public struct AdamOptimizer: BNNSOptimizer, _BNNSOptimizerFields {
        var f = BNNSOptimizerAdamWithClippingFields()
        public var usesAMSGrad = false
        public var accumulatorCountMultiplier: Int { usesAMSGrad ? 3 : 2 }
        public var learningRate: Float { get { f.learning_rate } set { f.learning_rate = newValue } }
        public var beta1: Float { get { f.beta1 } set { f.beta1 = newValue } }
        public var beta2: Float { get { f.beta2 } set { f.beta2 = newValue } }
        public var timeStep: Float { get { f.time_step } set { f.time_step = newValue } }
        public var epsilon: Float { get { f.epsilon } set { f.epsilon = newValue } }
        public var gradientScale: Float { get { f.gradient_scale } set { f.gradient_scale = newValue } }
        public var regularizationScale: Float { get { f.regularization_scale } set { f.regularization_scale = newValue } }
        public var gradientBounds: ClosedRange<Float>? {
            get { if case let .byValue(b) = gradientClipping { return b }; return nil }
            set { gradientClipping = newValue.map { .byValue(bounds: $0) } ?? .none }
        }
        public var regularizationFunction: BNNSOptimizerRegularizationFunction { get { f.regularization_func } set { f.regularization_func = newValue } }
        public var gradientClipping: BNNS.GradientClipping {
            get { _bnnsGradientClipping(f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) }
            set { (f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) = _bnnsClipping(newValue) }
        }
        public init(learningRate: Float, beta1: Float, beta2: Float, timeStep: Float, epsilon: Float, gradientScale: Float, regularizationScale: Float,
                    clipsGradientsTo gradientBounds: ClosedRange<Float>? = nil, regularizationFunction: BNNSOptimizerRegularizationFunction) {
            self.init(learningRate: learningRate, beta1: beta1, beta2: beta2, timeStep: timeStep, epsilon: epsilon, gradientScale: gradientScale,
                      regularizationScale: regularizationScale, gradientClipping: gradientBounds.map { .byValue(bounds: $0) } ?? .none,
                      regularizationFunction: regularizationFunction)
        }
        public init(learningRate: Float = 0.001, beta1: Float = 0.9, beta2: Float = 0.999, timeStep: Float, epsilon: Float = 1e-8, gradientScale: Float,
                    regularizationScale: Float, gradientClipping: BNNS.GradientClipping, regularizationFunction: BNNSOptimizerRegularizationFunction,
                    usesAMSGrad: Bool = false) {
            self.learningRate = learningRate; self.beta1 = beta1; self.beta2 = beta2; self.timeStep = timeStep; self.epsilon = epsilon
            self.gradientScale = gradientScale; self.regularizationScale = regularizationScale; self.gradientClipping = gradientClipping
            self.regularizationFunction = regularizationFunction; self.usesAMSGrad = usesAMSGrad
        }
        public var bnnsOptimizerFunction: BNNSOptimizerFunction {
            usesAMSGrad ? BNNSOptimizerFunctionAdamAMSGradWithClipping : BNNSOptimizerFunctionAdamWithClipping
        }
        func _withFields<R>(_ body: (UnsafeRawPointer) throws -> R) rethrows -> R { var c = f; return try withUnsafePointer(to: &c) { try body($0) } }
    }

    public struct AdamWOptimizer: BNNSOptimizer, _BNNSOptimizerFields {
        var f = BNNSOptimizerAdamWithClippingFields()
        var amsgrad = false
        public var accumulatorCountMultiplier: Int { amsgrad ? 3 : 2 }
        public var learningRate: Float { get { f.learning_rate } set { f.learning_rate = newValue } }
        public var beta1: Float { get { f.beta1 } set { f.beta1 = newValue } }
        public var beta2: Float { get { f.beta2 } set { f.beta2 = newValue } }
        public var timeStep: Float { get { f.time_step } set { f.time_step = newValue } }
        public var epsilon: Float { get { f.epsilon } set { f.epsilon = newValue } }
        public var gradientScale: Float { get { f.gradient_scale } set { f.gradient_scale = newValue } }
        public var weightDecay: Float { get { f.regularization_scale } set { f.regularization_scale = newValue } }
        public var gradientClipping: BNNS.GradientClipping {
            get { _bnnsGradientClipping(f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) }
            set { (f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) = _bnnsClipping(newValue) }
        }
        public init(learningRate: Float = 0.001, beta1: Float = 0.9, beta2: Float = 0.999, timeStep: Float = 1, epsilon: Float = 1e-8,
                    gradientScale: Float, weightDecay: Float = 1e-2, gradientClipping: BNNS.GradientClipping, usesAMSGrad: Bool = false) {
            self.learningRate = learningRate; self.beta1 = beta1; self.beta2 = beta2; self.timeStep = timeStep; self.epsilon = epsilon
            self.gradientScale = gradientScale; self.weightDecay = weightDecay; self.gradientClipping = gradientClipping; amsgrad = usesAMSGrad
        }
        public var bnnsOptimizerFunction: BNNSOptimizerFunction {
            amsgrad ? BNNSOptimizerFunctionAdamWAMSGradWithClipping : BNNSOptimizerFunctionAdamWWithClipping
        }
        func _withFields<R>(_ body: (UnsafeRawPointer) throws -> R) rethrows -> R { var c = f; return try withUnsafePointer(to: &c) { try body($0) } }
    }

    public struct RMSPropOptimizer: BNNSOptimizer, _BNNSOptimizerFields {
        var f = BNNSOptimizerRMSPropWithClippingFields()
        public var accumulatorCountMultiplier: Int { 1 + (centered ? 1 : 0) + (momentum != 0 ? 1 : 0) }
        public var learningRate: Float { get { f.learning_rate } set { f.learning_rate = newValue } }
        public var alpha: Float { get { f.alpha } set { f.alpha = newValue } }
        public var epsilon: Float { get { f.epsilon } set { f.epsilon = newValue } }
        public var centered: Bool { get { f.centered } set { f.centered = newValue } }
        public var momentum: Float { get { f.momentum } set { f.momentum = newValue } }
        public var gradientScale: Float { get { f.gradient_scale } set { f.gradient_scale = newValue } }
        public var regularizationScale: Float { get { f.regularization_scale } set { f.regularization_scale = newValue } }
        public var gradientBounds: ClosedRange<Float>? {
            get { if case let .byValue(b) = gradientClipping { return b }; return nil }
            set { gradientClipping = newValue.map { .byValue(bounds: $0) } ?? .none }
        }
        public var regularizationFunction: BNNSOptimizerRegularizationFunction { get { f.regularization_func } set { f.regularization_func = newValue } }
        public var gradientClipping: BNNS.GradientClipping {
            get { _bnnsGradientClipping(f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) }
            set { (f.clipping_func, f.clip_gradients_min, f.clip_gradients_max, f.clip_gradients_max_norm, f.clip_gradients_use_norm) = _bnnsClipping(newValue) }
        }
        public init(learningRate: Float, alpha: Float, epsilon: Float, centered: Bool, momentum: Float, gradientScale: Float, regularizationScale: Float,
                    clipsGradientsTo gradientBounds: ClosedRange<Float>? = nil, regularizationFunction: BNNSOptimizerRegularizationFunction) {
            self.init(learningRate: learningRate, alpha: alpha, epsilon: epsilon, centered: centered, momentum: momentum, gradientScale: gradientScale,
                      regularizationScale: regularizationScale, gradientClipping: gradientBounds.map { .byValue(bounds: $0) } ?? .none,
                      regularizationFunction: regularizationFunction)
        }
        public init(learningRate: Float = 1e-2, alpha: Float = 0.99, epsilon: Float = 1e-8, centered: Bool, momentum: Float = 0, gradientScale: Float,
                    regularizationScale: Float, gradientClipping: BNNS.GradientClipping, regularizationFunction: BNNSOptimizerRegularizationFunction) {
            self.learningRate = learningRate; self.alpha = alpha; self.epsilon = epsilon; self.centered = centered; self.momentum = momentum
            self.gradientScale = gradientScale; self.regularizationScale = regularizationScale; self.gradientClipping = gradientClipping
            self.regularizationFunction = regularizationFunction
        }
        public var bnnsOptimizerFunction: BNNSOptimizerFunction { BNNSOptimizerFunctionRMSPropWithClipping }
        func _withFields<R>(_ body: (UnsafeRawPointer) throws -> R) rethrows -> R { var c = f; return try withUnsafePointer(to: &c) { try body($0) } }
    }
}

// MARK: - random generator and nearest neighbors

extension BNNS {
    public enum RandomGeneratorMethod: Hashable {
        case aesCtr
    }
    public class RandomGeneratorState {
        let bytes: [UInt8]
        init(bytes: [UInt8]) { self.bytes = bytes }
    }
    public class RandomGenerator {
        let bnnsRandomGenerator: BNNSRandomGenerator
        public init?(method: BNNS.RandomGeneratorMethod, seed: UInt64? = nil, filterParameters: BNNSFilterParameters? = nil) {
            let g: BNNSRandomGenerator? = _bnnsWithOptional(filterParameters) { fp in
                if let seed = seed { return BNNSCreateRandomGeneratorWithSeed(BNNSRandomGeneratorMethodAES_CTR, seed, fp) }
                return BNNSCreateRandomGenerator(BNNSRandomGeneratorMethodAES_CTR, fp)
            }
            guard let g = g else { return nil }
            bnnsRandomGenerator = g
        }
        deinit { BNNSDestroyRandomGenerator(bnnsRandomGenerator) }
        public var state: BNNS.RandomGeneratorState {
            get {
                let n = BNNSRandomGeneratorStateSize(bnnsRandomGenerator)
                var b = [UInt8](repeating: 0, count: n)
                _ = b.withUnsafeMutableBytes { BNNSRandomGeneratorGetState(bnnsRandomGenerator, n, $0.baseAddress!) }
                return RandomGeneratorState(bytes: b)
            }
            set {
                var b = newValue.bytes
                _ = b.withUnsafeMutableBytes { BNNSRandomGeneratorSetState(bnnsRandomGenerator, $0.count, $0.baseAddress!) }
            }
        }
    }

    public struct NearestNeighbors {
        final class _Box {
            let knn: BNNSNearestNeighbors?
            init(_ k: BNNSNearestNeighbors?) { knn = k }
            deinit { if let k = knn { BNNSDestroyNearestNeighbors(k) } }
        }
        let box: _Box
        let neighborCount: Int
        public init(capacity: Int, dimensionCount: Int, neighborCount: Int, dataType: BNNSDataType) {
            box = _Box(BNNSCreateNearestNeighbors(UInt32(capacity), UInt32(dimensionCount), UInt32(neighborCount), dataType, nil))
            self.neighborCount = neighborCount
        }
        public func append(samples: BNNSNDArrayDescriptor) {
            guard let d = samples.data else { return }
            let s = samples.shape._parts.1
            let n = s.count >= 2 ? s[1] : 1   /* samples × features, the features first */
            guard let k = box.knn else { return }
            _ = BNNSNearestNeighborsLoad(k, UInt32(n), d)
        }
        public func apply(index: Int?, outputIndices: BNNSNDArrayDescriptor, outputDistances: BNNSNDArrayDescriptor) {
            guard let k = box.knn else { return }
            _ = BNNSNearestNeighborsGetInfo(k, Int32(index ?? -1), outputIndices.data?.assumingMemoryBound(to: Int32.self),
                                            outputDistances.data)
        }
    }
}
