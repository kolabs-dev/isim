// isim Accelerate Swift overlay: the buffer protocols, the vDSP and vForce namespaces, windows and the Fourier transforms.
// The element-wise overloads are generated (vDSP+Generated.swift, from tools/gen-accelerate-swift.py). Adapted: the
// work is done by isim's own C vDSP and vForce (frameworks/Accelerate).
@_exported import Accelerate

/// A contiguous buffer that Accelerate's Swift functions read.
public protocol AccelerateBuffer {
    associatedtype Element
    var count: Int { get }
    func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R
}

/// A contiguous buffer that Accelerate's Swift functions write.
public protocol AccelerateMutableBuffer: AccelerateBuffer {
    mutating func withUnsafeMutableBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R
}

extension Array: AccelerateMutableBuffer {}
extension ContiguousArray: AccelerateMutableBuffer {}
extension ArraySlice: AccelerateMutableBuffer {}
extension UnsafeBufferPointer: AccelerateBuffer {
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R { try body(self) }
}
extension UnsafeMutableBufferPointer: AccelerateMutableBuffer {
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R {
        try body(UnsafeBufferPointer(self))
    }
    public mutating func withUnsafeMutableBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Element>) throws -> R) rethrows -> R {
        try body(&self)
    }
}

public enum vDSP {
    public enum SortOrder: Int32 {
        case ascending = 1
        case descending = -1
    }
    public enum RoundingMode {
        case towardZero
        case towardNearestInteger
    }
    public enum WindowSequence {
        case hanningNormalized
        case hanningDenormalized
        case hamming
        case blackman
    }
    public enum FourierTransformDirection {
        case forward
        case inverse
        public var fftDirection: FFTDirection { self == .forward ? FFTDirection(kFFTDirection_Forward) : FFTDirection(kFFTDirection_Inverse) }
        public var dftDirection: vDSP_DFT_Direction { self == .forward ? vDSP_DFT_FORWARD : vDSP_DFT_INVERSE }
    }
    public enum Radix {
        case radix2
        case radix3
        case radix5
        public var fftRadix: FFTRadix {
            switch self {
            case .radix2: return FFTRadix(kFFTRadix2)
            case .radix3: return FFTRadix(kFFTRadix3)
            case .radix5: return FFTRadix(kFFTRadix5)
            }
        }
    }
    public enum DFTTransformType {
        case complexComplex
        case complexReal
    }
}

public enum vForce {}

// MARK: windows

public protocol vDSP_FloatingPointGeneratable: BinaryFloatingPoint {}
extension Float: vDSP_FloatingPointGeneratable {}
extension Double: vDSP_FloatingPointGeneratable {}

extension vDSP {
    public static func window<T: vDSP_FloatingPointGeneratable>(ofType: T.Type, usingSequence sequence: WindowSequence, count: Int, isHalfWindow: Bool) -> [T] {
        let n = isHalfWindow ? (count + 1) / 2 : count
        var flag = isHalfWindow ? Int32(vDSP_HALF_WINDOW) : 0
        if case .hanningNormalized = sequence { flag |= Int32(vDSP_HANN_NORM) }
        if T.self == Double.self {
            var w = [Double](repeating: 0, count: Swift.max(count, 1))
            switch sequence {
            case .hanningNormalized, .hanningDenormalized: vDSP_hann_windowD(&w, vDSP_Length(count), flag)
            case .hamming: vDSP_hamm_windowD(&w, vDSP_Length(count), flag)
            case .blackman: vDSP_blkman_windowD(&w, vDSP_Length(count), flag)
            }
            return w.prefix(n).map { T($0) }
        }
        var w = [Float](repeating: 0, count: Swift.max(count, 1))
        switch sequence {
        case .hanningNormalized, .hanningDenormalized: vDSP_hann_window(&w, vDSP_Length(count), flag)
        case .hamming: vDSP_hamm_window(&w, vDSP_Length(count), flag)
        case .blackman: vDSP_blkman_window(&w, vDSP_Length(count), flag)
        }
        return w.prefix(n).map { T($0) }
    }
}

// MARK: FFT (real, out of place: vDSP_fft_zrop's packing)

public protocol vDSP_FourierTransformable {
    associatedtype FFTFunctions: vDSP_FourierTransformFunctions where FFTFunctions.SplitComplex == Self
}
public protocol vDSP_FourierTransformFunctions {
    associatedtype SplitComplex
    static func makeFFTSetup(log2n: vDSP_Length, radix: FFTRadix) -> OpaquePointer?
    static func transform(fftSetup: OpaquePointer, log2n: vDSP_Length, source: UnsafePointer<SplitComplex>, destination: UnsafeMutablePointer<SplitComplex>, direction: FFTDirection)
    static func destroySetup(_ setup: OpaquePointer)
}
extension DSPSplitComplex: vDSP_FourierTransformable, vDSP_FourierTransformFunctions {
    public typealias FFTFunctions = DSPSplitComplex
    public static func makeFFTSetup(log2n: vDSP_Length, radix: FFTRadix) -> OpaquePointer? { vDSP_create_fftsetup(log2n, radix) }
    public static func transform(fftSetup: OpaquePointer, log2n: vDSP_Length, source: UnsafePointer<DSPSplitComplex>, destination: UnsafeMutablePointer<DSPSplitComplex>, direction: FFTDirection) {
        vDSP_fft_zrop(fftSetup, source, 1, destination, 1, log2n, direction)
    }
    public static func destroySetup(_ setup: OpaquePointer) { vDSP_destroy_fftsetup(setup) }
}
extension DSPDoubleSplitComplex: vDSP_FourierTransformable, vDSP_FourierTransformFunctions {
    public typealias FFTFunctions = DSPDoubleSplitComplex
    public static func makeFFTSetup(log2n: vDSP_Length, radix: FFTRadix) -> OpaquePointer? { vDSP_create_fftsetupD(log2n, radix) }
    public static func transform(fftSetup: OpaquePointer, log2n: vDSP_Length, source: UnsafePointer<DSPDoubleSplitComplex>, destination: UnsafeMutablePointer<DSPDoubleSplitComplex>, direction: FFTDirection) {
        vDSP_fft_zropD(fftSetup, source, 1, destination, 1, log2n, direction)
    }
    public static func destroySetup(_ setup: OpaquePointer) { vDSP_destroy_fftsetupD(setup) }
}

extension vDSP {
    /// A real FFT of 2^log2n values packed as even/odd pairs in a split complex (vDSP_ctoz): forward gives twice the DFT
    /// with the Nyquist value in imagp[0]; inverse is unscaled.
    public final class FFT<T: vDSP_FourierTransformable> {
        let log2n: vDSP_Length
        let setup: OpaquePointer
        public init?(log2n: vDSP_Length, radix: Radix, ofType: T.Type) {
            guard let s = T.FFTFunctions.makeFFTSetup(log2n: log2n, radix: radix.fftRadix) else { return nil }
            self.log2n = log2n
            self.setup = s
        }
        deinit { T.FFTFunctions.destroySetup(setup) }
        public func forward(input: T, output: inout T) { transform(input: input, output: &output, direction: .forward) }
        public func inverse(input: T, output: inout T) { transform(input: input, output: &output, direction: .inverse) }
        public func transform(input: T, output: inout T, direction: FourierTransformDirection) {
            withUnsafePointer(to: input) { src in
                T.FFTFunctions.transform(fftSetup: setup, log2n: log2n, source: src, destination: &output, direction: direction.fftDirection)
            }
        }
    }
}

// MARK: DFT (any length f * 2^n, f in 1, 3, 5, 15; complex-complex or complex-real)

public protocol vDSP_FloatingPointDiscreteFourierTransformable: BinaryFloatingPoint {}
extension Float: vDSP_FloatingPointDiscreteFourierTransformable {}
extension Double: vDSP_FloatingPointDiscreteFourierTransformable {}

final class _DFTSetup<T: vDSP_FloatingPointDiscreteFourierTransformable> {
    let pointer: OpaquePointer
    let count: Int
    init?(count: Int, direction: vDSP.FourierTransformDirection, transformType: vDSP.DFTTransformType) {
        let d = direction.dftDirection
        let p: OpaquePointer?
        if T.self == Double.self {
            p = transformType == .complexComplex ? vDSP_DFT_zop_CreateSetupD(nil, vDSP_Length(count), d) : vDSP_DFT_zrop_CreateSetupD(nil, vDSP_Length(count), d)
        } else {
            p = transformType == .complexComplex ? vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(count), d) : vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(count), d)
        }
        guard let p else { return nil }
        pointer = p
        self.count = transformType == .complexComplex ? count : count / 2
    }
    deinit { if T.self == Double.self { vDSP_DFT_DestroySetupD(pointer) } else { vDSP_DFT_DestroySetup(pointer) } }
    func execute<A: AccelerateBuffer, B: AccelerateBuffer, C: AccelerateMutableBuffer, D: AccelerateMutableBuffer>(
        _ ir: A, _ ii: B, _ or: inout C, _ oi: inout D) where A.Element == T, B.Element == T, C.Element == T, D.Element == T {
        precondition(ir.count >= count && ii.count >= count && or.count >= count && oi.count >= count, "vDSP DFT: buffers shorter than the transform")
        ir.withUnsafeBufferPointer { ir in ii.withUnsafeBufferPointer { ii in or.withUnsafeMutableBufferPointer { or in oi.withUnsafeMutableBufferPointer { oi in
            if T.self == Double.self {
                vDSP_DFT_ExecuteD(pointer, UnsafeRawPointer(ir.baseAddress!).assumingMemoryBound(to: Double.self),
                                  UnsafeRawPointer(ii.baseAddress!).assumingMemoryBound(to: Double.self),
                                  UnsafeMutableRawPointer(or.baseAddress!).assumingMemoryBound(to: Double.self),
                                  UnsafeMutableRawPointer(oi.baseAddress!).assumingMemoryBound(to: Double.self))
            } else {
                vDSP_DFT_Execute(pointer, UnsafeRawPointer(ir.baseAddress!).assumingMemoryBound(to: Float.self),
                                 UnsafeRawPointer(ii.baseAddress!).assumingMemoryBound(to: Float.self),
                                 UnsafeMutableRawPointer(or.baseAddress!).assumingMemoryBound(to: Float.self),
                                 UnsafeMutableRawPointer(oi.baseAddress!).assumingMemoryBound(to: Float.self))
            }
        } } } }
    }
}

extension vDSP {
    @available(iOS, introduced: 13.0, deprecated: 17.0, message: "Use vDSP.DiscreteFourierTransform")
    public final class DFT<T: vDSP_FloatingPointDiscreteFourierTransformable> {
        let setup: _DFTSetup<T>
        public init?(previous: DFT<T>? = nil, count: Int, direction: FourierTransformDirection, transformType: DFTTransformType, ofType: T.Type) {
            guard let s = _DFTSetup<T>(count: count, direction: direction, transformType: transformType) else { return nil }
            setup = s
        }
        public func transform<U: AccelerateBuffer, V: AccelerateMutableBuffer>(inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V) where U.Element == T, V.Element == T {
            setup.execute(inputReal, inputImaginary, &outputReal, &outputImaginary)
        }
        public func transform<U: AccelerateBuffer>(inputReal: U, inputImaginary: U) -> (real: [T], imaginary: [T]) where U.Element == T {
            var r = [T](repeating: 0, count: setup.count), i = [T](repeating: 0, count: setup.count)
            setup.execute(inputReal, inputImaginary, &r, &i)
            return (r, i)
        }
    }

    public enum DiscreteFourierTransformError: Error {
        case invalidCount
    }

    @available(iOS 17.0, *)
    public final class DiscreteFourierTransform<Element: vDSP_FloatingPointDiscreteFourierTransformable> {
        public enum TransformType {
            case complexComplex
            case complexReal
        }
        let setup: _DFTSetup<Element>
        public init(previous: DiscreteFourierTransform<Element>? = nil, count: Int, direction: FourierTransformDirection,
                    transformType: TransformType, ofType: Element.Type) throws {
            guard let s = _DFTSetup<Element>(count: count, direction: direction, transformType: transformType == .complexComplex ? .complexComplex : .complexReal)
            else { throw DiscreteFourierTransformError.invalidCount }
            setup = s
        }
        public func transform<U: AccelerateBuffer, V: AccelerateMutableBuffer>(inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V) where U.Element == Element, V.Element == Element {
            setup.execute(inputReal, inputImaginary, &outputReal, &outputImaginary)
        }
        public func transform<U: AccelerateBuffer>(inputReal: U, inputImaginary: U) -> (real: [Element], imaginary: [Element]) where U.Element == Element {
            var r = [Element](repeating: 0, count: setup.count), i = [Element](repeating: 0, count: setup.count)
            setup.execute(inputReal, inputImaginary, &r, &i)
            return (r, i)
        }
    }
}

// MARK: helpers for the generated overloads

typealias _vDSPUnary<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafeMutablePointer<E>?, vDSP_Stride, vDSP_Length) -> Void
typealias _vDSPBinary<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafePointer<E>?, vDSP_Stride, UnsafeMutablePointer<E>?, vDSP_Stride, vDSP_Length) -> Void
typealias _vDSPScalar<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafePointer<E>?, UnsafeMutablePointer<E>?, vDSP_Stride, vDSP_Length) -> Void
typealias _vDSPReduce<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafeMutablePointer<E>?, vDSP_Length) -> Void
typealias _vDSPPair<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafePointer<E>?, vDSP_Stride, UnsafeMutablePointer<E>?, vDSP_Length) -> Void
typealias _vDSPConv<E> = (UnsafePointer<E>?, vDSP_Stride, UnsafePointer<E>?, vDSP_Stride, UnsafeMutablePointer<E>?, vDSP_Stride, vDSP_Length, vDSP_Length) -> Void
typealias _vForceUnary<E> = (UnsafeMutablePointer<E>?, UnsafePointer<E>?, UnsafePointer<Int32>?) -> Void
typealias _vForceBinary<E> = (UnsafeMutablePointer<E>?, UnsafePointer<E>?, UnsafePointer<E>?, UnsafePointer<Int32>?) -> Void

func _array<E>(_ n: Int, _ fill: (inout UnsafeMutableBufferPointer<E>) -> Void) -> [E] {
    [E](unsafeUninitializedCapacity: n) { b, c in fill(&b); c = n }
}
func _map<E, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ a: U, _ r: inout V, _ f: _vDSPUnary<E>) where U.Element == E, V.Element == E {
    let n = min(a.count, r.count); guard n > 0 else { return }
    a.withUnsafeBufferPointer { a in r.withUnsafeMutableBufferPointer { r in f(a.baseAddress, 1, r.baseAddress, 1, vDSP_Length(n)) } }
}
func _zip<E, T: AccelerateBuffer, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ a: T, _ b: U, _ r: inout V, _ f: _vDSPBinary<E>) where T.Element == E, U.Element == E, V.Element == E {
    let n = min(a.count, b.count, r.count); guard n > 0 else { return }
    a.withUnsafeBufferPointer { a in b.withUnsafeBufferPointer { b in r.withUnsafeMutableBufferPointer { r in
        f(a.baseAddress, 1, b.baseAddress, 1, r.baseAddress, 1, vDSP_Length(n)) } } }
}
func _scalar<E, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ a: U, _ s: E, _ r: inout V, _ f: _vDSPScalar<E>) where U.Element == E, V.Element == E {
    let n = min(a.count, r.count); guard n > 0 else { return }
    var s = s
    a.withUnsafeBufferPointer { a in r.withUnsafeMutableBufferPointer { r in f(a.baseAddress, 1, &s, r.baseAddress, 1, vDSP_Length(n)) } }
}
func _reduce<E: BinaryFloatingPoint, U: AccelerateBuffer>(_ a: U, _ f: _vDSPReduce<E>) -> E where U.Element == E {
    var v: E = 0
    a.withUnsafeBufferPointer { a in f(a.baseAddress, 1, &v, vDSP_Length(a.count)) }
    return v
}
func _pair<E: BinaryFloatingPoint, U: AccelerateBuffer, V: AccelerateBuffer>(_ a: U, _ b: V, _ f: _vDSPPair<E>) -> E where U.Element == E, V.Element == E {
    var v: E = 0
    a.withUnsafeBufferPointer { a in b.withUnsafeBufferPointer { b in f(a.baseAddress, 1, b.baseAddress, 1, &v, vDSP_Length(min(a.count, b.count))) } }
    return v
}
func _conv<E, T: AccelerateBuffer, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ a: T, _ k: U, _ r: inout V, reversed: Bool, _ f: _vDSPConv<E>) where T.Element == E, U.Element == E, V.Element == E {
    let n = min(r.count, a.count - k.count), p = k.count
    guard n > 0, p > 0 else { return }
    a.withUnsafeBufferPointer { a in k.withUnsafeBufferPointer { k in r.withUnsafeMutableBufferPointer { r in
        if reversed { f(a.baseAddress, 1, k.baseAddress! + (p - 1), -1, r.baseAddress, 1, vDSP_Length(n), vDSP_Length(p)) }
        else { f(a.baseAddress, 1, k.baseAddress, 1, r.baseAddress, 1, vDSP_Length(n), vDSP_Length(p)) }
    } } }
}
func _vv<E, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ a: U, _ r: inout V, _ f: _vForceUnary<E>) where U.Element == E, V.Element == E {
    var n = Int32(min(a.count, r.count)); guard n > 0 else { return }
    a.withUnsafeBufferPointer { a in r.withUnsafeMutableBufferPointer { r in f(r.baseAddress, a.baseAddress, &n) } }
}
func _vv2<E, T: AccelerateBuffer, U: AccelerateBuffer, V: AccelerateMutableBuffer>(_ y: T, _ x: U, _ r: inout V, _ f: _vForceBinary<E>) where T.Element == E, U.Element == E, V.Element == E {
    var n = Int32(min(y.count, x.count, r.count)); guard n > 0 else { return }
    y.withUnsafeBufferPointer { y in x.withUnsafeBufferPointer { x in r.withUnsafeMutableBufferPointer { r in f(r.baseAddress, y.baseAddress, x.baseAddress, &n) } } }
}
