// isim Core ML: MLTensor (iOS 18), a multidimensional array with math, evaluated eagerly on the CPU (adapted: values
// are kept as doubles and rounded to the scalar type after each operation; Apple's tensors run lazily on any compute
// device). Broadcasting follows NumPy's rules.
import Foundation

public protocol MLTensorScalar: Sendable {
    static var _isimKind: Int { get }          // 0 float, 1 integer, 2 bool
    init(_tensorValue v: Double)
    var _tensorValue: Double { get }
}
extension Float: MLTensorScalar { public static var _isimKind: Int { 0 }; public init(_tensorValue v: Double) { self = Float(v) }; public var _tensorValue: Double { Double(self) } }
extension Int32: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = Int32(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension Int16: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = Int16(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension Int8: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = Int8(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension UInt32: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = UInt32(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension UInt16: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = UInt16(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension UInt8: MLTensorScalar { public static var _isimKind: Int { 1 }; public init(_tensorValue v: Double) { self = UInt8(clamping: Int(v.isFinite ? v.rounded(.towardZero) : 0)) }; public var _tensorValue: Double { Double(self) } }
extension Bool: MLTensorScalar { public static var _isimKind: Int { 2 }; public init(_tensorValue v: Double) { self = v != 0 }; public var _tensorValue: Double { self ? 1 : 0 } }

/// Ranges in a tensor's subscripts: an index, a range (with a stride), a new axis, ...
public protocol MLTensorRangeExpression {
    func _isimTensorRange(_ count: Int) -> _MLTensorRange
}
/// isim: what a range expression selects along an axis
public enum _MLTensorRange: Sendable { case indices([Int], keepsAxis: Bool), newAxis, squeeze, fill }
/// isim: a range expression made by one of MLTensorRangeExpression's static members
public struct _MLTensorRangeValue: MLTensorRangeExpression {
    let r: (Int) -> _MLTensorRange
    init(_ r: @escaping (Int) -> _MLTensorRange) { self.r = r }
    public func _isimTensorRange(_ count: Int) -> _MLTensorRange { r(count) }
}
extension Int: MLTensorRangeExpression { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices([self < 0 ? count + self : self], keepsAxis: false) } }
extension Range: MLTensorRangeExpression where Bound == Int { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices(Array(self), keepsAxis: true) } }
extension ClosedRange: MLTensorRangeExpression where Bound == Int { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices(Array(self), keepsAxis: true) } }
extension PartialRangeFrom: MLTensorRangeExpression where Bound == Int { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices(Array(lowerBound..<count), keepsAxis: true) } }
extension PartialRangeUpTo: MLTensorRangeExpression where Bound == Int { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices(Array(0..<upperBound), keepsAxis: true) } }
extension PartialRangeThrough: MLTensorRangeExpression where Bound == Int { public func _isimTensorRange(_ count: Int) -> _MLTensorRange { .indices(Array(0...upperBound), keepsAxis: true) } }
extension MLTensorRangeExpression where Self == _MLTensorRangeValue {
    public static var newAxis: any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .newAxis } }
    public static var squeezeAxis: any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .squeeze } }
    public static var fillAll: any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .fill } }
    public static func index(_ i: Int) -> any MLTensorRangeExpression { i }
    public static func range(_ r: Range<Int>, stride: Int) -> any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .indices(Array(Swift.stride(from: r.lowerBound, to: r.upperBound, by: stride)), keepsAxis: true) } }
    public static func closedRange(_ r: ClosedRange<Int>, stride: Int) -> any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .indices(Array(Swift.stride(from: r.lowerBound, through: r.upperBound, by: stride)), keepsAxis: true) } }
    public static func partialRangeFrom(_ r: PartialRangeFrom<Int>, stride: Int) -> any MLTensorRangeExpression { _MLTensorRangeValue { (n: Int) in .indices(Array(Swift.stride(from: r.lowerBound, to: n, by: stride)), keepsAxis: true) } }
    public static func partialRangeUpTo(_ r: PartialRangeUpTo<Int>, stride: Int) -> any MLTensorRangeExpression { _MLTensorRangeValue { (_: Int) in .indices(Array(Swift.stride(from: 0, to: r.upperBound, by: stride)), keepsAxis: true) } }
}

public struct MLTensor: Sendable, CustomStringConvertible {
    public enum PaddingMode: Sendable { case constant(Float), reflection, symmetric }
    public enum ResizeMethod: Sendable { case nearestNeighbor, bilinear(alignCorners: Bool) }

    var _values: [Double]
    public let shape: [Int]
    public let scalarType: any MLTensorScalar.Type
    init(_ values: [Double], _ shape: [Int], _ type: any MLTensorScalar.Type) {
        self.shape = shape; scalarType = type
        _values = type._isimKind == 0 ? values.map { Double(Float($0)) } : values.map { type.init(_tensorValue: $0)._tensorValue }
    }
    public var rank: Int { shape.count }
    public var scalarCount: Int { shape.reduce(1, *) }
    public var isScalar: Bool { shape.isEmpty }
    public var description: String { "MLTensor(shape: \(shape), scalarType: \(scalarType), \(_values.prefix(16)))" }
    public var customMirror: Mirror { Mirror(self, children: ["shape": shape, "scalarType": "\(scalarType)"]) }

    // MARK: making tensors
    public init<Scalar: MLTensorScalar & MLShapedArrayScalar>(_ shapedArray: MLShapedArray<Scalar>) {
        self.init(shapedArray.scalars.map(\._tensorValue), shapedArray.shape, Scalar.self)
    }
    public init<Scalar: MLTensorScalar>(_ scalars: [Scalar]) { self.init(scalars.map(\._tensorValue), [scalars.count], Scalar.self) }
    public init<Scalar: MLTensorScalar>(_ scalar: Scalar) { self.init([scalar._tensorValue], [], Scalar.self) }
    public init(_ tensor: MLTensor, scalarType: any MLTensorScalar.Type) { self.init(tensor._values, tensor.shape, scalarType) }
    public init(shape: [Int], scalars: some Collection<Float>) { self.init(scalars.map(Double.init), shape, Float.self) }
    public init<Scalar: MLTensorScalar>(shape: [Int], scalars: some Collection<Scalar>, scalarType: Scalar.Type) { self.init(scalars.map(\._tensorValue), shape, scalarType) }
    public init(repeating value: Float, shape: [Int]) { self.init([Double](repeating: Double(value), count: shape.reduce(1, *)), shape, Float.self) }
    public init<Scalar: MLTensorScalar>(repeating value: Scalar, shape: [Int], scalarType: Scalar.Type) {
        self.init([Double](repeating: value._tensorValue, count: shape.reduce(1, *)), shape, scalarType)
    }
    public init(zeros shape: [Int], scalarType: any MLTensorScalar.Type = Float.self) { self.init([Double](repeating: 0, count: shape.reduce(1, *)), shape, scalarType) }
    public init(ones shape: [Int], scalarType: any MLTensorScalar.Type = Float.self) { self.init([Double](repeating: 1, count: shape.reduce(1, *)), shape, scalarType) }
    public init(rangeFrom start: Float, to end: Float, by stride: Float.Stride) {
        let v = Array(Swift.stride(from: start, to: end, by: stride)).map(Double.init); self.init(v, [v.count], Float.self)
    }
    public init<Scalar: MLTensorScalar & Strideable>(rangeFrom start: Scalar, to end: Scalar, by stride: Scalar.Stride, scalarType: Scalar.Type) {
        let v = Array(Swift.stride(from: start, to: end, by: stride)).map(\._tensorValue); self.init(v, [v.count], scalarType)
    }
    public init(linearSpaceFrom start: Float, through end: Float, count: Int) {
        let v = (0..<count).map { count > 1 ? Double(start) + Double(end - start) * Double($0) / Double(count - 1) : Double(start) }
        self.init(v, [count], Float.self)
    }
    public init<Scalar: MLTensorScalar>(linearSpaceFrom start: Scalar, through end: Scalar, count: Int, scalarType: Scalar.Type) {
        let a = start._tensorValue, b = end._tensorValue
        self.init((0..<count).map { count > 1 ? a + (b - a) * Double($0) / Double(count - 1) : a }, [count], scalarType)
    }
    public init(randomUniform shape: [Int], in range: Range<Float> = 0..<1, seed: UInt64? = nil, scalarType: any MLTensorScalar.Type = Float.self) {
        var g = _MLRandom(seed)
        self.init((0..<shape.reduce(1, *)).map { _ in Double(range.lowerBound) + Double(range.upperBound - range.lowerBound) * g.next() }, shape, scalarType)
    }
    public init<Scalar: MLTensorScalar & BinaryFloatingPoint>(randomNormal shape: [Int], mean: Scalar = 0, standardDeviation: Scalar = 1, seed: UInt64? = nil, scalarType: Scalar.Type) {
        var g = _MLRandom(seed)
        self.init((0..<shape.reduce(1, *)).map { _ in
            let u = Swift.max(1e-12, g.next()), v = g.next()
            return Double(mean) + Double(standardDeviation) * (-2 * Foundation.log(u)).squareRoot() * Foundation.cos(2 * .pi * v)
        }, shape, scalarType)
    }
    public init(shape: [Int], data: Data, scalarType: any MLTensorScalar.Type) {
        let n = shape.reduce(1, *)
        let v: [Double] = data.withUnsafeBytes { b in
            switch scalarType {
            case is Float.Type: return b.bindMemory(to: Float.self).prefix(n).map(Double.init)
            case is Int32.Type: return b.bindMemory(to: Int32.self).prefix(n).map(Double.init)
            case is Int16.Type: return b.bindMemory(to: Int16.self).prefix(n).map(Double.init)
            case is Int8.Type: return b.bindMemory(to: Int8.self).prefix(n).map(Double.init)
            case is UInt32.Type: return b.bindMemory(to: UInt32.self).prefix(n).map(Double.init)
            case is UInt16.Type: return b.bindMemory(to: UInt16.self).prefix(n).map(Double.init)
            case is UInt8.Type: return b.bindMemory(to: UInt8.self).prefix(n).map(Double.init)
            default: return b.bindMemory(to: UInt8.self).prefix(n).map { $0 != 0 ? 1 : 0 }
            }
        }
        self.init(v, shape, scalarType)
    }
    public init(bytesNoCopy bytes: UnsafeRawBufferPointer, shape: [Int], scalarType: any MLTensorScalar.Type, deallocator: Data.Deallocator) {
        self.init(shape: shape, data: Data(bytes), scalarType: scalarType)
        _ = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: bytes.baseAddress!), count: 0, deallocator: deallocator)
    }
    public init(unsafeUninitializedShape shape: [Int], scalarType: any MLTensorScalar.Type, initializingWith initializer: (UnsafeMutableRawBufferPointer) throws -> Void) rethrows {
        let size: Int
        switch scalarType {
        case is Float.Type, is Int32.Type, is UInt32.Type: size = 4
        case is Int16.Type, is UInt16.Type: size = 2
        default: size = 1
        }
        var bytes = Data(count: shape.reduce(1, *) * size)
        try bytes.withUnsafeMutableBytes { try initializer($0) }
        self.init(shape: shape, data: bytes, scalarType: scalarType)
    }
    public init(concatenating tensors: some Collection<MLTensor>, alongAxis axis: Int) {
        let parts = Array(tensors)
        let a = axis < 0 ? parts[0].rank + axis : axis
        var shape = parts[0].shape
        shape[a] = parts.map { $0.shape[a] }.reduce(0, +)
        let outer = shape[..<a].reduce(1, *)
        var v: [Double] = []
        for o in 0..<outer { for p in parts { let inner = p.shape[a...].reduce(1, *); v += p._values[(o * inner)..<((o + 1) * inner)] } }
        self.init(v, shape, parts[0].scalarType)
    }
    public init(stacking tensors: some Collection<MLTensor>, alongAxis axis: Int = 0) {
        let parts = Array(tensors)
        let a = axis < 0 ? parts[0].rank + 1 + axis : axis
        self.init(concatenating: parts.map { $0.expandingShape(at: a) }, alongAxis: a)
    }
    public init(_ tensors: some Collection<MLTensor>, alongAxis axis: Int = 0) { self.init(stacking: tensors, alongAxis: axis) }

    /// the tensor's values as a shaped array of `type`
    public func shapedArray<Scalar: MLTensorScalar & MLShapedArrayScalar>(of type: Scalar.Type) async -> MLShapedArray<Scalar> {
        MLShapedArray(scalars: _values.map { Scalar(_doubleValue: $0) }, shape: shape)
    }
    public func cast<Scalar: MLTensorScalar>(to type: Scalar.Type) -> MLTensor { MLTensor(_values, shape, type) }
    public func cast(like other: MLTensor) -> MLTensor { MLTensor(_values, shape, other.scalarType) }

    // MARK: helpers
    var _strides: [Int] { _mlStrides(shape) }
    func _map(_ f: (Double) -> Double) -> MLTensor { MLTensor(_values.map(f), shape, scalarType) }
    func _mapFloat(_ f: (Double) -> Double) -> MLTensor { MLTensor(_values.map(f), shape, scalarType._isimKind == 0 ? scalarType : Float.self) }
    static func _broadcast(_ a: [Int], _ b: [Int]) -> [Int] {
        let n = Swift.max(a.count, b.count)
        return (0..<n).map { i in
            let x = i - (n - a.count) >= 0 ? a[i - (n - a.count)] : 1, y = i - (n - b.count) >= 0 ? b[i - (n - b.count)] : 1
            precondition(x == y || x == 1 || y == 1, "MLTensor: shapes \(a) and \(b) do not broadcast")
            return Swift.max(x, y)
        }
    }
    func _expanded(to s: [Int]) -> [Double] {
        if shape == s { return _values }
        let pad = s.count - shape.count, st = _strides, n = s.reduce(1, *)
        return (0..<n).map { i in
            var rem = i, off = 0
            for d in stride(from: s.count - 1, through: 0, by: -1) {
                let idx = rem % s[d]; rem /= s[d]
                if d >= pad, shape[d - pad] != 1 { off += idx * st[d - pad] }
            }
            return _values[off]
        }
    }
    static func _zip(_ a: MLTensor, _ b: MLTensor, bool: Bool = false, _ f: (Double, Double) -> Double) -> MLTensor {
        let s = _broadcast(a.shape, b.shape)
        let x = a._expanded(to: s), y = b._expanded(to: s)
        return MLTensor(zip(x, y).map(f), s, bool ? Bool.self : a.scalarType)
    }
    func _axes(_ axes: [Int]) -> [Int] { axes.map { $0 < 0 ? rank + $0 : $0 } }
    /// reduces along axes (all when empty)
    func _reduce(_ axes: [Int], keepRank: Bool, bool: Bool = false, float: Bool = false, _ f: ([Double]) -> Double) -> MLTensor {
        let ax = Set(axes.isEmpty ? Array(0..<rank) : _axes(axes))
        let outShape = shape.enumerated().map { ax.contains($0.offset) ? 1 : $0.element }
        var groups = [[Double]](repeating: [], count: outShape.reduce(1, *))
        let ost = _mlStrides(outShape)
        for i in 0..<scalarCount {
            var rem = i, o = 0
            for d in stride(from: rank - 1, through: 0, by: -1) { let idx = rem % shape[d]; rem /= shape[d]; if !ax.contains(d) { o += idx * ost[d] } }
            groups[o].append(_values[i])
        }
        let finalShape = keepRank ? outShape : shape.enumerated().filter { !ax.contains($0.offset) }.map(\.element)
        return MLTensor(groups.map(f), finalShape, bool ? Bool.self : float && scalarType._isimKind != 0 ? Float.self : scalarType)
    }
    /// for each position along `axis` (moved last), the values; with `rebuild` putting them back
    func _alongAxis(_ axis: Int, _ f: ([Double]) -> [Double]) -> MLTensor {
        let a = axis < 0 ? rank + axis : axis
        let outer = shape[..<a].reduce(1, *), n = shape[a], inner = shape[(a + 1)...].reduce(1, *)
        var out = _values
        for o in 0..<outer { for i in 0..<inner {
            let idx = (0..<n).map { o * n * inner + $0 * inner + i }
            let r = f(idx.map { _values[$0] })
            for (k, j) in idx.enumerated() { out[j] = r[k] }
        } }
        return MLTensor(out, shape, scalarType)
    }

    // MARK: element-wise math
    public static func + (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, +) }
    public static func - (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, -) }
    public static func * (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, *) }
    public static func / (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b) { a.scalarType._isimKind == 0 ? $0 / $1 : ($1 == 0 ? 0 : ($0 / $1).rounded(.towardZero)) } }
    public static func % (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b) { $1 == 0 ? 0 : $0.truncatingRemainder(dividingBy: $1) } }
    public static func + (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a + MLTensor([b._tensorValue], [], a.scalarType) }
    public static func - (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a - MLTensor([b._tensorValue], [], a.scalarType) }
    public static func * (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a * MLTensor([b._tensorValue], [], a.scalarType) }
    public static func / (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a / MLTensor([b._tensorValue], [], a.scalarType) }
    public static func + (a: some MLTensorScalar, b: MLTensor) -> MLTensor { MLTensor([a._tensorValue], [], b.scalarType) + b }
    public static func - (a: some MLTensorScalar, b: MLTensor) -> MLTensor { MLTensor([a._tensorValue], [], b.scalarType) - b }
    public static func * (a: some MLTensorScalar, b: MLTensor) -> MLTensor { MLTensor([a._tensorValue], [], b.scalarType) * b }
    public static func / (a: some MLTensorScalar, b: MLTensor) -> MLTensor { MLTensor([a._tensorValue], [], b.scalarType) / b }
    public static prefix func - (a: MLTensor) -> MLTensor { a._map { -$0 } }
    public static func += (a: inout MLTensor, b: MLTensor) { a = a + b }
    public static func -= (a: inout MLTensor, b: MLTensor) { a = a - b }
    public static func *= (a: inout MLTensor, b: MLTensor) { a = a * b }
    public static func /= (a: inout MLTensor, b: MLTensor) { a = a / b }
    public static func %= (a: inout MLTensor, b: MLTensor) { a = a % b }
    public static func .== (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 == $1 ? 1 : 0 } }
    public static func .!= (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 != $1 ? 1 : 0 } }
    public static func .< (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 < $1 ? 1 : 0 } }
    public static func .<= (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 <= $1 ? 1 : 0 } }
    public static func .> (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 > $1 ? 1 : 0 } }
    public static func .>= (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 >= $1 ? 1 : 0 } }
    public static func .== (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .== MLTensor([b._tensorValue], [], a.scalarType) }
    public static func .!= (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .!= MLTensor([b._tensorValue], [], a.scalarType) }
    public static func .< (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .< MLTensor([b._tensorValue], [], a.scalarType) }
    public static func .<= (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .<= MLTensor([b._tensorValue], [], a.scalarType) }
    public static func .> (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .> MLTensor([b._tensorValue], [], a.scalarType) }
    public static func .>= (a: MLTensor, b: some MLTensorScalar) -> MLTensor { a .>= MLTensor([b._tensorValue], [], a.scalarType) }
    public static prefix func .! (a: MLTensor) -> MLTensor { MLTensor(a._values.map { $0 == 0 ? 1 : 0 }, a.shape, Bool.self) }
    public static func .& (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 != 0 && $1 != 0 ? 1 : 0 } }
    public static func .| (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { $0 != 0 || $1 != 0 ? 1 : 0 } }
    public static func .^ (a: MLTensor, b: MLTensor) -> MLTensor { _zip(a, b, bool: true) { ($0 != 0) != ($1 != 0) ? 1 : 0 } }

    public func abs() -> MLTensor { _map { Swift.abs($0) } }
    public func sign() -> MLTensor { _map { $0 > 0 ? 1 : $0 < 0 ? -1 : 0 } }
    public func squared() -> MLTensor { _map { $0 * $0 } }
    public func squareRoot() -> MLTensor { _mapFloat { $0.squareRoot() } }
    public func rsqrt() -> MLTensor { _mapFloat { 1 / $0.squareRoot() } }
    public func reciprocal() -> MLTensor { _mapFloat { 1 / $0 } }
    public func exp() -> MLTensor { _mapFloat { Foundation.exp($0) } }
    public func exp2() -> MLTensor { _mapFloat { Foundation.exp2($0) } }
    public func log() -> MLTensor { _mapFloat { Foundation.log($0) } }
    public func sin() -> MLTensor { _mapFloat { Foundation.sin($0) } }
    public func cos() -> MLTensor { _mapFloat { Foundation.cos($0) } }
    public func tan() -> MLTensor { _mapFloat { Foundation.tan($0) } }
    public func asin() -> MLTensor { _mapFloat { Foundation.asin($0) } }
    public func acos() -> MLTensor { _mapFloat { Foundation.acos($0) } }
    public func atan() -> MLTensor { _mapFloat { Foundation.atan($0) } }
    public func sinh() -> MLTensor { _mapFloat { Foundation.sinh($0) } }
    public func cosh() -> MLTensor { _mapFloat { Foundation.cosh($0) } }
    public func tanh() -> MLTensor { _mapFloat { Foundation.tanh($0) } }
    public func asinh() -> MLTensor { _mapFloat { Foundation.asinh($0) } }
    public func acosh() -> MLTensor { _mapFloat { Foundation.acosh($0) } }
    public func atanh() -> MLTensor { _mapFloat { Foundation.atanh($0) } }
    public func floor() -> MLTensor { _map { $0.rounded(.down) } }
    public func ceil() -> MLTensor { _map { $0.rounded(.up) } }
    public func round() -> MLTensor { _map { $0.rounded(.toNearestOrEven) } }
    public func pow(_ exponent: MLTensor) -> MLTensor { MLTensor._zip(self, exponent) { Foundation.pow($0, $1) } }
    public func pow(_ exponent: some MLTensorScalar) -> MLTensor { _map { Foundation.pow($0, exponent._tensorValue) } }
    public func clamped(to range: ClosedRange<Float>) -> MLTensor { _map { Swift.min(Double(range.upperBound), Swift.max(Double(range.lowerBound), $0)) } }
    public func clamped<Scalar: MLTensorScalar & Comparable>(to range: ClosedRange<Scalar>) -> MLTensor {
        _map { Swift.min(range.upperBound._tensorValue, Swift.max(range.lowerBound._tensorValue, $0)) }
    }
    /// `other` where `mask` is true, these values elsewhere
    public func replacing(with other: MLTensor, where mask: MLTensor) -> MLTensor {
        let s = MLTensor._broadcast(MLTensor._broadcast(shape, other.shape), mask.shape)
        let a = _expanded(to: s), b = other._expanded(to: s), m = mask._expanded(to: s)
        return MLTensor((0..<a.count).map { m[$0] != 0 ? b[$0] : a[$0] }, s, scalarType)
    }
    public func replacing(with value: some MLTensorScalar, where mask: MLTensor) -> MLTensor { replacing(with: MLTensor([value._tensorValue], [], scalarType), where: mask) }

    // MARK: reductions
    public func sum(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank) { $0.reduce(0, +) } }
    public func sum(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank) { $0.reduce(0, +) } }
    public func product(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank) { $0.reduce(1, *) } }
    public func product(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank) { $0.reduce(1, *) } }
    public func mean(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank, float: true) { $0.reduce(0, +) / Double($0.count) } }
    public func mean(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank, float: true) { $0.reduce(0, +) / Double($0.count) } }
    public func max(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank) { $0.max() ?? 0 } }
    public func max(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank) { $0.max() ?? 0 } }
    public func min(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank) { $0.min() ?? 0 } }
    public func min(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank) { $0.min() ?? 0 } }
    public func all(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank, bool: true) { $0.allSatisfy { $0 != 0 } ? 1 : 0 } }
    public func all(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank, bool: true) { $0.allSatisfy { $0 != 0 } ? 1 : 0 } }
    public func any(keepRank: Bool = false) -> MLTensor { _reduce([], keepRank: keepRank, bool: true) { $0.contains { $0 != 0 } ? 1 : 0 } }
    public func any(alongAxes axes: Int..., keepRank: Bool = false) -> MLTensor { _reduce(axes, keepRank: keepRank, bool: true) { $0.contains { $0 != 0 } ? 1 : 0 } }
    public func argmax() -> MLTensor { MLTensor([Double(_values.indices.max { _values[$0] < _values[$1] } ?? 0)], [], Int32.self) }
    public func argmin() -> MLTensor { MLTensor([Double(_values.indices.min { _values[$0] < _values[$1] } ?? 0)], [], Int32.self) }
    public func argmax(alongAxis axis: Int, keepRank: Bool = false) -> MLTensor {
        MLTensor(_reduce([axis], keepRank: keepRank) { v in Double(v.indices.max { v[$0] < v[$1] } ?? 0) }._values,
                 _reduce([axis], keepRank: keepRank) { _ in 0 }.shape, Int32.self)
    }
    public func argmin(alongAxis axis: Int, keepRank: Bool = false) -> MLTensor {
        MLTensor(_reduce([axis], keepRank: keepRank) { v in Double(v.indices.min { v[$0] < v[$1] } ?? 0) }._values,
                 _reduce([axis], keepRank: keepRank) { _ in 0 }.shape, Int32.self)
    }
    public func softmax(alongAxis axis: Int = -1) -> MLTensor {
        MLTensor(_alongAxis(axis) { v in let m = v.max() ?? 0; let e = v.map { Foundation.exp($0 - m) }; let s = e.reduce(0, +); return e.map { $0 / s } }._values, shape, Float.self)
    }
    public func cumulativeSum(alongAxis axis: Int) -> MLTensor { _alongAxis(axis) { v in var s = 0.0; return v.map { s += $0; return s } } }
    public func cumulativeProduct(alongAxis axis: Int) -> MLTensor { _alongAxis(axis) { v in var s = 1.0; return v.map { s *= $0; return s } } }
    public func argsort(alongAxis axis: Int = -1, descendingOrder: Bool = false) -> MLTensor {
        MLTensor(_alongAxis(axis) { v in v.indices.sorted { descendingOrder ? v[$0] > v[$1] : v[$0] < v[$1] }.map(Double.init) }._values, shape, Int32.self)
    }
    /// the k largest values along the last axis, and their indices
    public func topK(_ k: Int) -> (values: MLTensor, indices: MLTensor) {
        let n = shape.last ?? 1, outer = scalarCount / Swift.max(1, n)
        var vals: [Double] = [], idx: [Double] = []
        for o in 0..<outer {
            let row = Array(_values[(o * n)..<((o + 1) * n)])
            let order = row.indices.sorted { row[$0] > row[$1] }.prefix(k)
            vals += order.map { row[$0] }; idx += order.map(Double.init)
        }
        let s = Array(shape.dropLast()) + [Swift.min(k, n)]
        return (MLTensor(vals, s, scalarType), MLTensor(idx, s, Int32.self))
    }

    // MARK: linear algebra
    /// matrix product of the last two axes, broadcast over the others (vectors are promoted as in NumPy)
    public func matmul(_ other: MLTensor) -> MLTensor {
        var a = self, b = other
        let vecA = a.rank == 1, vecB = b.rank == 1
        if vecA { a = a.expandingShape(at: 0) }
        if vecB { b = b.expandingShape(at: 1) }
        let m = a.shape[a.rank - 2], k = a.shape[a.rank - 1], k2 = b.shape[b.rank - 2], n = b.shape[b.rank - 1]
        precondition(k == k2, "matmul: \(a.shape) x \(b.shape)")
        let batch = MLTensor._broadcast(Array(a.shape.dropLast(2)), Array(b.shape.dropLast(2)))
        let A = MLTensor(a._values, a.shape, a.scalarType)._expanded(to: batch + [m, k]), B = b._expanded(to: batch + [k, n])
        let count = batch.reduce(1, *)
        var out = [Double](repeating: 0, count: count * m * n)
        for t in 0..<count { for i in 0..<m { for j in 0..<n {
            var s = 0.0
            for p in 0..<k { s += A[t * m * k + i * k + p] * B[t * k * n + p * n + j] }
            out[t * m * n + i * n + j] = s
        } } }
        var shape = batch + [m, n]
        if vecB { shape.removeLast() }
        if vecA { shape.remove(at: shape.count - (vecB ? 1 : 2)) }
        return MLTensor(out, shape, scalarType)
    }
    /// keeps the band of `lowerBandCount` diagonals below and `upperBandCount` above the main one (-1: all)
    public func bandPart(lowerBandCount: Int, upperBandCount: Int) -> MLTensor {
        let m = shape[rank - 2], n = shape[rank - 1]
        return MLTensor(_values.enumerated().map { i, v in
            let r = (i / n) % m, c = i % n
            return (lowerBandCount < 0 || r - c <= lowerBandCount) && (upperBandCount < 0 || c - r <= upperBandCount) ? v : 0
        }, shape, scalarType)
    }

    // MARK: shapes
    public func reshaped(to newShape: [Int]) -> MLTensor {
        var s = newShape
        if let i = s.firstIndex(of: -1) { s[i] = scalarCount / Swift.max(1, s.filter { $0 != -1 }.reduce(1, *)) }
        precondition(s.reduce(1, *) == scalarCount, "reshaped(to: \(newShape)) cannot hold \(scalarCount) scalars")
        return MLTensor(_values, s, scalarType)
    }
    public func flattened() -> MLTensor { reshaped(to: [scalarCount]) }
    public func expandingShape(at axes: Int...) -> MLTensor {
        var s = shape
        for a in axes.sorted() { s.insert(1, at: a < 0 ? s.count + 1 + a : a) }
        return MLTensor(_values, s, scalarType)
    }
    public func squeezingShape() -> MLTensor { MLTensor(_values, shape.filter { $0 != 1 }, scalarType) }
    public func squeezingShape(at axes: Int...) -> MLTensor {
        let ax = Set(_axes(axes))
        return MLTensor(_values, shape.enumerated().filter { !(ax.contains($0.offset) && $0.element == 1) }.map(\.element), scalarType)
    }
    public func transposed() -> MLTensor { transposed(permutation: Array((0..<rank).reversed())) }
    public func transposed(permutation: Int...) -> MLTensor { transposed(permutation: permutation) }
    public func transposed(permutation: [Int]) -> MLTensor {
        let s = permutation.map { shape[$0] }, st = _strides, n = scalarCount
        var out = [Double](repeating: 0, count: n)
        for i in 0..<n {
            var rem = i, off = 0
            for d in stride(from: s.count - 1, through: 0, by: -1) { off += (rem % s[d]) * st[permutation[d]]; rem /= s[d] }
            out[i] = _values[off]
        }
        return MLTensor(out, s, scalarType)
    }
    public func concatenated(with other: MLTensor, alongAxis axis: Int) -> MLTensor { MLTensor(concatenating: [self, other], alongAxis: axis) }
    public func split(count: Int, alongAxis axis: Int = 0) -> [MLTensor] {
        let a = axis < 0 ? rank + axis : axis
        return split(sizes: [Int](repeating: shape[a] / count, count: count), alongAxis: a)
    }
    public func split(sizes: [Int], alongAxis axis: Int = 0) -> [MLTensor] {
        let a = axis < 0 ? rank + axis : axis
        var start = 0
        return sizes.map { size in
            defer { start += size }
            return _select(a, Array(start..<(start + size)))
        }
    }
    public func unstacked(alongAxis axis: Int = 0) -> [MLTensor] {
        let a = axis < 0 ? rank + axis : axis
        return (0..<shape[a]).map { _select(a, [$0]).squeezingShape(at: a) }
    }
    /// the values at `indices` along `axis`
    func _select(_ axis: Int, _ indices: [Int]) -> MLTensor {
        let outer = shape[..<axis].reduce(1, *), n = shape[axis], inner = shape[(axis + 1)...].reduce(1, *)
        var out: [Double] = []
        out.reserveCapacity(outer * indices.count * inner)
        for o in 0..<outer { for i in indices { let base = o * n * inner + i * inner; out += _values[base..<(base + inner)] } }
        var s = shape; s[axis] = indices.count
        return MLTensor(out, s, scalarType)
    }
    public func gathering(atIndices indices: MLTensor, alongAxis axis: Int = 0) -> MLTensor {
        let a = axis < 0 ? rank + axis : axis
        let picked = _select(a, indices._values.map { Int($0) })
        var s = shape
        s.replaceSubrange(a...a, with: indices.shape)
        return MLTensor(picked._values, s, scalarType)
    }
    public func gathering(atIndices indices: MLTensor) -> MLTensor { gathering(atIndices: indices, alongAxis: 0) }
    public func replacing(with values: MLTensor, atIndices indices: MLTensor, alongAxis axis: Int) -> MLTensor {
        let a = axis < 0 ? rank + axis : axis
        var out = _values
        let outer = shape[..<a].reduce(1, *), n = shape[a], inner = shape[(a + 1)...].reduce(1, *)
        let idx = indices._values.map { Int($0) }
        for o in 0..<outer { for (k, i) in idx.enumerated() { for j in 0..<inner {
            out[o * n * inner + i * inner + j] = values._values[(o * idx.count * inner + k * inner + j) % Swift.max(1, values.scalarCount)]
        } } }
        return MLTensor(out, shape, scalarType)
    }
    public func replacing(atIndices indices: MLTensor, with value: some MLTensorScalar, alongAxis axis: Int) -> MLTensor {
        replacing(with: MLTensor([value._tensorValue], [], scalarType), atIndices: indices, alongAxis: axis)
    }
    public func reversed(alongAxes axes: Int...) -> MLTensor {
        var t = self
        for a in _axes(axes) { t = t._select(a, Array((0..<shape[a]).reversed())) }
        return t
    }
    public func tiled(multiples: [Int]) -> MLTensor {
        var t = self
        for (a, m) in multiples.enumerated() where m > 1 { t = MLTensor(concatenating: [MLTensor](repeating: t, count: m), alongAxis: a) }
        return t
    }
    public func padded(forSizes sizes: [(before: Int, after: Int)], with value: Float = 0) -> MLTensor { padded(forSizes: sizes, mode: .constant(value)) }
    public func padded(forSizes sizes: [(before: Int, after: Int)], mode: PaddingMode) -> MLTensor {
        let s = shape.enumerated().map { $0.element + (sizes.count > $0.offset ? sizes[$0.offset].before + sizes[$0.offset].after : 0) }
        let st = _strides, n = s.reduce(1, *)
        let out: [Double] = (0..<n).map { i in
            var rem = i, off = 0, outside = false
            for d in stride(from: s.count - 1, through: 0, by: -1) {
                var idx = rem % s[d] - (sizes.count > d ? sizes[d].before : 0); rem /= s[d]
                if idx < 0 || idx >= shape[d] {
                    switch mode {
                    case .constant: outside = true
                    case .reflection: idx = idx < 0 ? -idx : 2 * (shape[d] - 1) - idx
                    case .symmetric: idx = idx < 0 ? -idx - 1 : 2 * shape[d] - 1 - idx
                    }
                    idx = Swift.max(0, Swift.min(shape[d] - 1, idx))
                }
                off += idx * st[d]
            }
            if outside, case .constant(let v) = mode { return Double(v) }
            return _values[off]
        }
        return MLTensor(out, s, scalarType)
    }
    /// resizes the last two axes (height, width)
    public func resized(to size: (newHeight: Int, newWidth: Int), method: ResizeMethod = .nearestNeighbor) -> MLTensor {
        let h = shape[rank - 2], w = shape[rank - 1], outer = scalarCount / (h * w)
        var out: [Double] = []
        for o in 0..<outer {
            let plane = Array(_values[(o * h * w)..<((o + 1) * h * w)])
            for y in 0..<size.newHeight { for x in 0..<size.newWidth {
                switch method {
                case .nearestNeighbor:
                    out.append(plane[Swift.min(h - 1, y * h / size.newHeight) * w + Swift.min(w - 1, x * w / size.newWidth)])
                case .bilinear(let align):
                    let fy = align && size.newHeight > 1 ? Double(y) * Double(h - 1) / Double(size.newHeight - 1) : (Double(y) + 0.5) * Double(h) / Double(size.newHeight) - 0.5
                    let fx = align && size.newWidth > 1 ? Double(x) * Double(w - 1) / Double(size.newWidth - 1) : (Double(x) + 0.5) * Double(w) / Double(size.newWidth) - 0.5
                    let y0 = Swift.max(0, Swift.min(h - 1, Int(fy.rounded(.down)))), x0 = Swift.max(0, Swift.min(w - 1, Int(fx.rounded(.down))))
                    let y1 = Swift.min(h - 1, y0 + 1), x1 = Swift.min(w - 1, x0 + 1)
                    let ay = Swift.max(0, Swift.min(1, fy - Double(y0))), ax = Swift.max(0, Swift.min(1, fx - Double(x0)))
                    out.append((plane[y0 * w + x0] * (1 - ax) + plane[y0 * w + x1] * ax) * (1 - ay) + (plane[y1 * w + x0] * (1 - ax) + plane[y1 * w + x1] * ax) * ay)
                }
            } }
        }
        return MLTensor(out, Array(shape.dropLast(2)) + [size.newHeight, size.newWidth], scalarType)
    }

    // MARK: subscripts
    public subscript(_ ranges: (any MLTensorRangeExpression)?...) -> MLTensor { _sliced(ranges) }
    public subscript(_ all: UnboundedRange, _ rest: (any MLTensorRangeExpression)?...) -> MLTensor { _sliced([nil] + rest) }
    public subscript(_ a: (any MLTensorRangeExpression)?, _ all: UnboundedRange, _ rest: (any MLTensorRangeExpression)?...) -> MLTensor { _sliced([a, nil] + rest) }
    public subscript(_ a: (any MLTensorRangeExpression)?, _ b: (any MLTensorRangeExpression)?, _ all: UnboundedRange,
                     _ rest: (any MLTensorRangeExpression)?...) -> MLTensor { _sliced([a, b, nil] + rest) }
    public subscript(_ a: (any MLTensorRangeExpression)?, _ b: (any MLTensorRangeExpression)?, _ c: (any MLTensorRangeExpression)?, _ all: UnboundedRange,
                     _ rest: (any MLTensorRangeExpression)?...) -> MLTensor { _sliced([a, b, c, nil] + rest) }
    /// nil is a whole axis; fillAll stands for the whole axes up to the rest
    func _sliced(_ ranges: [(any MLTensorRangeExpression)?]) -> MLTensor {
        var t = self, axis = 0
        let consuming = ranges.filter { r in
            guard let r else { return true }
            switch r._isimTensorRange(1) { case .newAxis, .fill: return false; default: return true }
        }.count
        for r in ranges {
            guard let r else { axis += 1; continue }
            switch r._isimTensorRange(axis < t.rank ? t.shape[axis] : 1) {
            case .newAxis: t = t.expandingShape(at: axis); axis += 1
            case .fill: axis += Swift.max(0, rank - consuming)
            case .squeeze: t = t.squeezingShape(at: axis)
            case .indices(let idx, let keeps):
                t = t._select(axis, idx.map { $0 < 0 ? t.shape[axis] + $0 : $0 })
                if keeps { axis += 1 } else { t = t.squeezingShape(at: axis) }
            }
        }
        return t
    }
}

/// a seeded generator (SplitMix64) for random tensors
struct _MLRandom {
    var state: UInt64
    init(_ seed: UInt64?) { state = seed ?? UInt64.random(in: 0...UInt64.max) }
    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9; z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
}
