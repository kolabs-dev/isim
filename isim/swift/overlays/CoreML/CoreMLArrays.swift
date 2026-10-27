// isim Core ML: MLShapedArray and MLShapedArraySlice (value-type multidimensional arrays, row-major), and MLTensor
// (iOS 18), evaluated eagerly on the CPU in double precision and converted to its scalar type (issue #376; adapted:
// Apple's runs lazily on the CPU, GPU or Neural Engine). Slices are copies that write back through the subscripts'
// setters.
import Foundation
import CoreVideo

// MARK: - scalars

public protocol MLShapedArrayScalar: Sendable {
    static var multiArrayDataType: MLMultiArrayDataType { get }
    init(_doubleValue v: Double)
    var _doubleValue: Double { get }
}
extension Double: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .double }
    public init(_doubleValue v: Double) { self = v }
    public var _doubleValue: Double { self }
}
extension Float: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .float32 }
    public init(_doubleValue v: Double) { self = Float(v) }
    public var _doubleValue: Double { Double(self) }
}
extension Int32: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .int32 }
    public init(_doubleValue v: Double) { self = Int32(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }
    public var _doubleValue: Double { Double(self) }
}
extension Int8: MLShapedArrayScalar {
    public static var multiArrayDataType: MLMultiArrayDataType { .int8 }
    public init(_doubleValue v: Double) { self = Int8(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }
    public var _doubleValue: Double { Double(self) }
}

/// row-major strides of a shape
func _mlStrides(_ shape: [Int]) -> [Int] {
    var st = [Int](repeating: 1, count: shape.count), acc = 1
    for i in stride(from: shape.count - 1, through: 0, by: -1) { st[i] = acc; acc *= shape[i] }
    return st
}

/// Ranges in a shaped array's subscripts.
public protocol MLShapedArrayRangeExpression {
    func _isimRange(in count: Int) -> Range<Int>
}
extension Range: MLShapedArrayRangeExpression where Bound == Int { public func _isimRange(in count: Int) -> Range<Int> { self } }
extension ClosedRange: MLShapedArrayRangeExpression where Bound == Int { public func _isimRange(in count: Int) -> Range<Int> { lowerBound..<(upperBound + 1) } }
extension PartialRangeFrom: MLShapedArrayRangeExpression where Bound == Int { public func _isimRange(in count: Int) -> Range<Int> { lowerBound..<count } }
extension PartialRangeUpTo: MLShapedArrayRangeExpression where Bound == Int { public func _isimRange(in count: Int) -> Range<Int> { 0..<upperBound } }
extension PartialRangeThrough: MLShapedArrayRangeExpression where Bound == Int { public func _isimRange(in count: Int) -> Range<Int> { 0..<(upperBound + 1) } }

public enum MLShapedArrayBufferLayout: Sendable { case firstMajorContiguous, lastMajorContiguous }

// MARK: - the protocol

public protocol MLShapedArrayProtocol: CustomStringConvertible {
    associatedtype Scalar: MLShapedArrayScalar
    var shape: [Int] { get }
    var scalars: [Scalar] { get set }
    init<S: Sequence>(scalars: S, shape: [Int]) where S.Element == Scalar
}
extension MLShapedArrayProtocol {
    public var strides: [Int] { _mlStrides(shape) }
    public var count: Int { shape.first ?? 1 }
    public var isScalar: Bool { shape.isEmpty }
    public var scalarCount: Int { shape.reduce(1, *) }
    public var scalar: Scalar? { scalarCount == 1 ? scalars.first : nil }
    public var description: String { "\(type(of: self))(shape: \(shape), scalars: \(scalars.prefix(16)))" }
    public init(repeating repeatedValue: Scalar, shape: [Int]) {
        self.init(scalars: [Scalar](repeating: repeatedValue, count: shape.reduce(1, *)), shape: shape)
    }
    public init(_ multiArray: MLMultiArray) {
        self.init(scalars: multiArray._values.map { Scalar(_doubleValue: $0) }, shape: multiArray.shape.map(\.integerValue))
    }
    /// a shaped array of another scalar type, its values converted
    public init<Source: MLShapedArrayProtocol>(converting source: Source) {
        self.init(scalars: source.scalars.map { Scalar(_doubleValue: $0._doubleValue) }, shape: source.shape)
    }
    public init(unsafeUninitializedShape shape: [Int], initializingWith initializer: (inout UnsafeMutableBufferPointer<Scalar>, [Int]) throws -> Void) rethrows {
        let n = shape.reduce(1, *)
        var values = [Scalar](repeating: Scalar(_doubleValue: 0), count: n)
        try values.withUnsafeMutableBufferPointer { try initializer(&$0, _mlStrides(shape)) }
        self.init(scalars: values, shape: shape)
    }
    public init(bytesNoCopy bytes: UnsafeRawPointer, shape: [Int], deallocator: Data.Deallocator) {
        self.init(bytesNoCopy: bytes, shape: shape, strides: _mlStrides(shape), deallocator: deallocator)
    }
    /// isim copies the bytes (then lets the deallocator have them)
    public init(bytesNoCopy bytes: UnsafeRawPointer, shape: [Int], strides: [Int], deallocator: Data.Deallocator) {
        let n = shape.reduce(1, *), sz = MemoryLayout<Scalar>.stride
        var values: [Scalar] = []
        values.reserveCapacity(n)
        for i in 0..<n {
            var rem = i, off = 0
            for d in stride(from: shape.count - 1, through: 0, by: -1) { off += (rem % shape[d]) * strides[d]; rem /= shape[d] }
            values.append(bytes.load(fromByteOffset: off * sz, as: Scalar.self))
        }
        self.init(scalars: values, shape: shape)
        _ = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes), count: 0, deallocator: deallocator)
    }
    public func withUnsafeShapedBufferPointer<R>(_ body: (UnsafeBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try scalars.withUnsafeBufferPointer { try body($0, shape, strides) }
    }
    public mutating func withUnsafeMutableShapedBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        let sh = shape, st = strides
        return try scalars.withUnsafeMutableBufferPointer { try body(&$0, sh, st) }
    }
    public mutating func fill(with value: Scalar) { scalars = [Scalar](repeating: value, count: scalarCount) }

    func _linear(_ index: [Int]) -> Int { zip(index, strides).reduce(0) { $0 + $1.0 * $1.1 } }
    public subscript(scalarAt scalarIndices: Int...) -> Scalar {
        get { scalars[_linear(scalarIndices)] }
        set { scalars[_linear(scalarIndices)] = newValue }
    }
    public subscript<C: Collection>(scalarAt scalarIndices: C) -> Scalar where C.Element == Int {
        get { scalars[_linear(Array(scalarIndices))] }
        set { scalars[_linear(Array(scalarIndices))] = newValue }
    }

    /// the block selected by ranges of the leading dimensions (the rest whole)
    func _block(_ ranges: [Range<Int>]) -> (values: [Scalar], shape: [Int], offsets: [Int]) {
        var rs = ranges
        for d in rs.count..<shape.count { rs.append(0..<shape[d]) }
        let sh = rs.map(\.count), n = sh.reduce(1, *), st = strides
        var offsets: [Int] = []
        offsets.reserveCapacity(n)
        for i in 0..<n {
            var rem = i, off = 0
            for d in stride(from: sh.count - 1, through: 0, by: -1) { off += (rs[d].lowerBound + rem % sh[d]) * st[d]; rem /= sh[d] }
            offsets.append(off)
        }
        return (offsets.map { scalars[$0] }, sh, offsets)
    }
    mutating func _write(_ ranges: [Range<Int>], _ values: [Scalar]) {
        let (_, _, offsets) = _block(ranges)
        for (o, v) in zip(offsets, values) { scalars[o] = v }
    }
    public subscript(_ index: Int) -> MLShapedArraySlice<Scalar> {
        get { let b = _block([index..<(index + 1)]); return MLShapedArraySlice(scalars: b.values, shape: Array(b.shape.dropFirst())) }
        set { _write([index..<(index + 1)], newValue.scalars) }
    }
    public subscript(_ indices: Int...) -> MLShapedArraySlice<Scalar> {
        get { let b = _block(indices.map { $0..<($0 + 1) }); return MLShapedArraySlice(scalars: b.values, shape: Array(b.shape.dropFirst(indices.count))) }
        set { _write(indices.map { $0..<($0 + 1) }, newValue.scalars) }
    }
    public subscript<C: Collection>(_ indices: C) -> MLShapedArraySlice<Scalar> where C.Element == Int {
        get { self[Array(indices).map { $0..<($0 + 1) } as [any MLShapedArrayRangeExpression]].reshaped(to: Array(shape.dropFirst(indices.count))) }
        set { _write(Array(indices).map { $0..<($0 + 1) }, newValue.scalars) }
    }
    public subscript(_ range: Range<Int>) -> MLShapedArraySlice<Scalar> {
        get { let b = _block([range]); return MLShapedArraySlice(scalars: b.values, shape: b.shape) }
        set { _write([range], newValue.scalars) }
    }
    public subscript(_ range: any MLShapedArrayRangeExpression) -> MLShapedArraySlice<Scalar> {
        get { self[range._isimRange(in: count)] }
        set { self[range._isimRange(in: count)] = newValue }
    }
    public subscript(_ ranges: any MLShapedArrayRangeExpression...) -> MLShapedArraySlice<Scalar> {
        get { self[ranges] }
        set { self[ranges] = newValue }
    }
    subscript(_ ranges: [any MLShapedArrayRangeExpression]) -> MLShapedArraySlice<Scalar> {
        get {
            let rs = ranges.enumerated().map { $1._isimRange(in: shape[$0]) }
            let b = _block(rs); return MLShapedArraySlice(scalars: b.values, shape: b.shape)
        }
        set { _write(ranges.enumerated().map { $1._isimRange(in: shape[$0]) }, newValue.scalars) }
    }
    public subscript(_ all: (UnboundedRange_) -> Void) -> MLShapedArraySlice<Scalar> {
        get { MLShapedArraySlice(scalars: scalars, shape: shape) }
        set { scalars = newValue.scalars }
    }

    // shape operations
    public func reshaped(to newShape: [Int]) -> Self {
        precondition(newShape.reduce(1, *) == scalarCount, "reshaped(to: \(newShape)) cannot hold \(scalarCount) scalars")
        return Self(scalars: scalars, shape: newShape)
    }
    public func expandingShape(at axis: Int) -> Self { var s = shape; s.insert(1, at: axis < 0 ? s.count + 1 + axis : axis); return Self(scalars: scalars, shape: s) }
    public func squeezingShape() -> Self { Self(scalars: scalars, shape: shape.filter { $0 != 1 }) }
    public func transposed() -> Self { transposed(permutation: Array((0..<shape.count).reversed())) }
    public func transposed(permutation: [Int]) -> Self {
        let newShape = permutation.map { shape[$0] }, st = strides, n = scalarCount
        var out = [Scalar](repeating: Scalar(_doubleValue: 0), count: n)
        for i in 0..<n {
            var rem = i, off = 0
            for d in stride(from: newShape.count - 1, through: 0, by: -1) { off += (rem % newShape[d]) * st[permutation[d]]; rem /= newShape[d] }
            out[i] = scalars[off]
        }
        return Self(scalars: out, shape: newShape)
    }
    /// isim keeps scalars first-major (row-major): the layout is the same
    public func changingLayout(to layout: MLShapedArrayBufferLayout) -> Self { self }
    public mutating func withUnsafeMutableShapedBufferPointer<R>(using layout: MLShapedArrayBufferLayout,
                                                                  _ body: (inout UnsafeMutableBufferPointer<Scalar>, [Int], [Int]) throws -> R) rethrows -> R {
        try withUnsafeMutableShapedBufferPointer(body)
    }
    public init(scalar: Scalar) { self.init(scalars: [scalar], shape: []) }
    public init(data: Data, shape: [Int]) {
        let values = data.withUnsafeBytes { Array($0.bindMemory(to: Scalar.self).prefix(shape.reduce(1, *))) }
        self.init(scalars: values, shape: shape)
    }
    public init(data: Data, shape: [Int], strides: [Int]) {
        self = data.withUnsafeBytes { Self(bytesNoCopy: $0.baseAddress!, shape: shape, strides: strides, deallocator: .none) }
    }
    public init<S: Sequence>(concatenating arrays: S, alongAxis axis: Int) where S.Element: MLShapedArrayProtocol, S.Element.Scalar == Scalar {
        let parts = Array(arrays)
        guard var shape = parts.first?.shape else { self.init(scalars: [], shape: [0]); return }
        shape[axis] = parts.map { $0.shape[axis] }.reduce(0, +)
        let outer = shape[..<axis].reduce(1, *)
        var values: [Scalar] = []
        for o in 0..<outer {
            for p in parts { let inner = p.shape[axis...].reduce(1, *); values += p.scalars[(o * inner)..<((o + 1) * inner)] }
        }
        self.init(scalars: values, shape: shape)
    }
    /// the identity matrix (a 2-D shaped array)
    public init(identityMatrixOfSize size: Int) {
        var v = [Scalar](repeating: Scalar(_doubleValue: 0), count: size * size)
        for i in 0..<size { v[i * size + i] = Scalar(_doubleValue: 1) }
        self.init(scalars: v, shape: [size, size])
    }
    public init(randomScalarsIn range: ClosedRange<Scalar>, shape: [Int]) where Scalar: BinaryFloatingPoint, Scalar.RawSignificand: FixedWidthInteger {
        self.init(scalars: (0..<shape.reduce(1, *)).map { _ in Scalar.random(in: range) }, shape: shape)
    }
    public init(randomScalarsIn range: ClosedRange<Scalar>, shape: [Int]) where Scalar: FixedWidthInteger {
        self.init(scalars: (0..<shape.reduce(1, *)).map { _ in Scalar.random(in: range) }, shape: shape)
    }
}

// MARK: - the array and its slices

public struct MLShapedArray<Scalar: MLShapedArrayScalar>: MLShapedArrayProtocol, Equatable, Sendable {
    public var shape: [Int]
    public var scalars: [Scalar]
    public init<S: Sequence>(scalars: S, shape: [Int]) where S.Element == Scalar {
        self.scalars = Array(scalars); self.shape = shape
        precondition(self.scalars.count == shape.reduce(1, *), "MLShapedArray: \(self.scalars.count) scalars for the shape \(shape)")
    }
    public static func == (a: Self, b: Self) -> Bool { a.shape == b.shape && a.scalars.map(\._doubleValue) == b.scalars.map(\._doubleValue) }
    /// the scalars of a pixel buffer (isim copies them)
    public init(mutating pixelBuffer: CVPixelBuffer, shape: [Int]) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        let n = shape.reduce(1, *)
        let base = CVPixelBufferGetBaseAddress(pixelBuffer)!
        self.init(scalars: (0..<n).map { base.load(fromByteOffset: $0 * MemoryLayout<Scalar>.stride, as: Scalar.self) }, shape: shape)
    }
    /// isim's shaped arrays are not backed by pixel buffers (nil)
    public func withPixelBufferIfAvailable<R>(_ body: (CVPixelBuffer) throws -> R) rethrows -> R? { nil }
    public mutating func withMutablePixelBufferIfAvailable<R>(_ body: (CVPixelBuffer) throws -> R) rethrows -> R? { nil }
}
extension MLShapedArray: Codable where Scalar: Codable {
    enum CodingKeys: String, CodingKey { case shape, scalars }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(scalars: try c.decode([Scalar].self, forKey: .scalars), shape: try c.decode([Int].self, forKey: .shape))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(shape, forKey: .shape); try c.encode(scalars, forKey: .scalars)
    }
}
public struct MLShapedArraySlice<Scalar: MLShapedArrayScalar>: MLShapedArrayProtocol, Equatable, Sendable {
    public var shape: [Int]
    public var scalars: [Scalar]
    public init<S: Sequence>(scalars: S, shape: [Int]) where S.Element == Scalar { self.scalars = Array(scalars); self.shape = shape }
    public init(mutating pixelBuffer: CVPixelBuffer, shape: [Int]) { let a = MLShapedArray<Scalar>(mutating: pixelBuffer, shape: shape); self.init(scalars: a.scalars, shape: shape) }
    public static func == (a: Self, b: Self) -> Bool { a.shape == b.shape && a.scalars.map(\._doubleValue) == b.scalars.map(\._doubleValue) }
}
extension MLShapedArraySlice: Codable where Scalar: Codable {
    enum CodingKeys: String, CodingKey { case shape, scalars }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(scalars: try c.decode([Scalar].self, forKey: .scalars), shape: try c.decode([Int].self, forKey: .shape))
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(shape, forKey: .shape); try c.encode(scalars, forKey: .scalars)
    }
}
extension MLShapedArray {
    public init(_ slice: MLShapedArraySlice<Scalar>) { self.init(scalars: slice.scalars, shape: slice.shape) }
}
extension MLMultiArray {
    /// a multi-array with the shaped array's shape, type and scalars
    public convenience init<Scalar: MLShapedArrayScalar>(_ shapedArray: MLShapedArray<Scalar>) {
        try! self.init(shape: (shapedArray.shape.isEmpty ? [1] : shapedArray.shape).map { NSNumber(value: $0) }, dataType: Scalar.multiArrayDataType)
        for (i, v) in shapedArray.scalars.enumerated() { self[i] = NSNumber(value: v._doubleValue) }
    }
}
extension MLFeatureValue {
    public convenience init<Scalar: MLShapedArrayScalar>(shapedArray: MLShapedArray<Scalar>) { self.init(multiArray: MLMultiArray(shapedArray)) }
    public func shapedArrayValue<Scalar: MLShapedArrayScalar>(of type: Scalar.Type) -> MLShapedArray<Scalar>? { multiArrayValue.map { MLShapedArray<Scalar>($0) } }
}
