// isim Accelerate Swift overlay: the buffer protocols, the vDSP and vForce namespaces, windows and the Fourier transforms.
// The element-wise overloads are generated (vDSP+Generated.swift, from tools/gen-accelerate-swift.py). Adapted: the
// work is done by isim's own C vDSP and vForce (frameworks/Accelerate).
@_exported import Accelerate
import Foundation

/// A contiguous buffer that Accelerate's Swift functions read.
public protocol AccelerateBuffer<Element> {
    associatedtype Element
    var count: Int { get }
    func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Element>) throws -> R) rethrows -> R
}

/// A contiguous buffer that Accelerate's Swift functions write.
public protocol AccelerateMutableBuffer<Element>: AccelerateBuffer {
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
        public var dftDirection: vDSP_DFT_Direction { self == .forward ? .FORWARD : .INVERSE }
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

/// The DFT functions vDSP.DFT calls for its element type (vDSP.VectorizableFloat, vDSP.VectorizableDouble).
public protocol vDSP_DFTFunctions {
    associatedtype Scalar
    static func makeDFTSetup<T>(previous: vDSP.DFT<T>?, count: Int, direction: vDSP.FourierTransformDirection,
                                transformType: vDSP.DFTTransformType) -> OpaquePointer?
        where T: vDSP_FloatingPointDiscreteFourierTransformable
    static func transform<U, V>(dftSetup: OpaquePointer, inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Scalar, V.Element == Scalar
    static func destroySetup(_ setup: OpaquePointer)
}

public protocol vDSP_FloatingPointDiscreteFourierTransformable: BinaryFloatingPoint {
    associatedtype DFTFunctions: vDSP_DFTFunctions where DFTFunctions.Scalar == Self
}
extension Float: vDSP_FloatingPointDiscreteFourierTransformable { public typealias DFTFunctions = vDSP.VectorizableFloat }
extension Double: vDSP_FloatingPointDiscreteFourierTransformable { public typealias DFTFunctions = vDSP.VectorizableDouble }

/// Creating and destroying the setup of a vDSP.DiscreteFourierTransform (the four vDSP.DFT…Functions types).
public protocol vDSP_DiscreteTransformLifecycleFunctions {
    static func makeDiscreteFourierTransform(previous: OpaquePointer?, count: Int, direction: vDSP.FourierTransformDirection,
                                             transformType: vDSP.DFTTransformType) throws -> OpaquePointer
    static func destroySetup(_ setup: OpaquePointer)
}

/// An element type of vDSP.DiscreteFourierTransform: Float and Double (split complex), DSPComplex and DSPDoubleComplex
/// (interleaved).
public protocol vDSP_DiscreteFourierTransformable {
    associatedtype DiscreteFourierTransformFunctions: vDSP_DiscreteTransformLifecycleFunctions
}
extension Float: vDSP_DiscreteFourierTransformable {
    public typealias DiscreteFourierTransformFunctions = vDSP.DFTSinglePrecisionSplitComplexFunctions
}
extension Double: vDSP_DiscreteFourierTransformable {
    public typealias DiscreteFourierTransformFunctions = vDSP.DFTDoublePrecisionSplitComplexFunctions
}
extension DSPComplex: vDSP_DiscreteFourierTransformable {
    public typealias DiscreteFourierTransformFunctions = vDSP.DFTSinglePrecisionInterleavedFunctions
}
extension DSPDoubleComplex: vDSP_DiscreteFourierTransformable {
    public typealias DiscreteFourierTransformFunctions = vDSP.DFTDoublePrecisionInterleavedFunctions
}

@inline(__always)
func _dftExecute<E, U: AccelerateBuffer, V: AccelerateMutableBuffer>(
    _ ir: U, _ ii: U, _ or: inout V, _ oi: inout V,
    _ f: (UnsafePointer<E>, UnsafePointer<E>, UnsafeMutablePointer<E>, UnsafeMutablePointer<E>) -> Void) where U.Element == E, V.Element == E {
    ir.withUnsafeBufferPointer { ir in ii.withUnsafeBufferPointer { ii in or.withUnsafeMutableBufferPointer { or in oi.withUnsafeMutableBufferPointer { oi in
        f(ir.baseAddress!, ii.baseAddress!, or.baseAddress!, oi.baseAddress!)
    } } } }
}

extension vDSP.VectorizableFloat: vDSP_DFTFunctions {
    public static func makeDFTSetup<T>(previous: vDSP.DFT<T>?, count: Int, direction: vDSP.FourierTransformDirection,
                                       transformType: vDSP.DFTTransformType) -> OpaquePointer?
        where T: vDSP_FloatingPointDiscreteFourierTransformable {
        transformType == .complexComplex ? vDSP_DFT_zop_CreateSetup(previous?.dftSetup, vDSP_Length(count), direction.dftDirection)
                                         : vDSP_DFT_zrop_CreateSetup(previous?.dftSetup, vDSP_Length(count), direction.dftDirection)
    }
    public static func transform<U, V>(dftSetup: OpaquePointer, inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Float, V.Element == Float {
        _dftExecute(inputReal, inputImaginary, &outputReal, &outputImaginary) { vDSP_DFT_Execute(dftSetup, $0, $1, $2, $3) }
    }
    public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_DestroySetup(setup) }
}
extension vDSP.VectorizableDouble: vDSP_DFTFunctions {
    public static func makeDFTSetup<T>(previous: vDSP.DFT<T>?, count: Int, direction: vDSP.FourierTransformDirection,
                                       transformType: vDSP.DFTTransformType) -> OpaquePointer?
        where T: vDSP_FloatingPointDiscreteFourierTransformable {
        transformType == .complexComplex ? vDSP_DFT_zop_CreateSetupD(previous?.dftSetup, vDSP_Length(count), direction.dftDirection)
                                         : vDSP_DFT_zrop_CreateSetupD(previous?.dftSetup, vDSP_Length(count), direction.dftDirection)
    }
    public static func transform<U, V>(dftSetup: OpaquePointer, inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Double, V.Element == Double {
        _dftExecute(inputReal, inputImaginary, &outputReal, &outputImaginary) { vDSP_DFT_ExecuteD(dftSetup, $0, $1, $2, $3) }
    }
    public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_DestroySetupD(setup) }
}

extension vDSP {
    @available(iOS, introduced: 13.0, deprecated: 17.0, message: "Use vDSP.DiscreteFourierTransform")
    public final class DFT<T: vDSP_FloatingPointDiscreteFourierTransformable> {
        let dftSetup: OpaquePointer
        let count: Int
        public init?(previous: DFT<T>? = nil, count: Int, direction: FourierTransformDirection, transformType: DFTTransformType, ofType: T.Type) {
            guard let s = T.DFTFunctions.makeDFTSetup(previous: previous, count: count, direction: direction, transformType: transformType)
            else { return nil }
            dftSetup = s
            self.count = transformType == .complexComplex ? count : count / 2
        }
        deinit { T.DFTFunctions.destroySetup(dftSetup) }
        public func transform<U: AccelerateBuffer, V: AccelerateMutableBuffer>(inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V) where U.Element == T, V.Element == T {
            precondition(inputReal.count >= count && inputImaginary.count >= count && outputReal.count >= count && outputImaginary.count >= count,
                         "vDSP.DFT: buffers shorter than the transform")
            T.DFTFunctions.transform(dftSetup: dftSetup, inputReal: inputReal, inputImaginary: inputImaginary, outputReal: &outputReal, outputImaginary: &outputImaginary)
        }
        public func transform<U: AccelerateBuffer>(inputReal: U, inputImaginary: U) -> (real: [T], imaginary: [T]) where U.Element == T {
            var r = [T](repeating: 0, count: count), i = [T](repeating: 0, count: count)
            transform(inputReal: inputReal, inputImaginary: inputImaginary, outputReal: &r, outputImaginary: &i)
            return (r, i)
        }
    }

    /// Why a vDSP.DiscreteFourierTransform can't be made: the count isn't one the routines support (f * 2^n, f in 1, 3, 5,
    /// 15; even for a complex-real transform).
    public enum DFTError: Error, LocalizedError {
        case invalidInterleavedCount(count: Int)
        case invalidSplitComplexCount(count: Int, transformType: vDSP.DFTTransformType)
        public var errorDescription: String? {
            switch self {
            case .invalidInterleavedCount(let count):
                return "\(count) is not a valid count for an interleaved discrete Fourier transform."
            case .invalidSplitComplexCount(let count, let transformType):
                return "\(count) is not a valid count for a split-complex \(transformType == .complexComplex ? "complex-complex" : "complex-real") discrete Fourier transform."
            }
        }
    }

    public struct DFTSinglePrecisionSplitComplexFunctions: vDSP_DiscreteTransformLifecycleFunctions {
        public static func makeDiscreteFourierTransform(previous: OpaquePointer?, count: Int, direction: vDSP.FourierTransformDirection,
                                                        transformType: vDSP.DFTTransformType) throws -> OpaquePointer {
            let s = transformType == .complexComplex ? vDSP_DFT_zop_CreateSetup(previous, vDSP_Length(count), direction.dftDirection)
                                                     : vDSP_DFT_zrop_CreateSetup(previous, vDSP_Length(count), direction.dftDirection)
            guard let s else { throw DFTError.invalidSplitComplexCount(count: count, transformType: transformType) }
            return s
        }
        public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_DestroySetup(setup) }
    }
    public struct DFTDoublePrecisionSplitComplexFunctions: vDSP_DiscreteTransformLifecycleFunctions {
        public static func makeDiscreteFourierTransform(previous: OpaquePointer?, count: Int, direction: vDSP.FourierTransformDirection,
                                                        transformType: vDSP.DFTTransformType) throws -> OpaquePointer {
            let s = transformType == .complexComplex ? vDSP_DFT_zop_CreateSetupD(previous, vDSP_Length(count), direction.dftDirection)
                                                     : vDSP_DFT_zrop_CreateSetupD(previous, vDSP_Length(count), direction.dftDirection)
            guard let s else { throw DFTError.invalidSplitComplexCount(count: count, transformType: transformType) }
            return s
        }
        public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_DestroySetupD(setup) }
    }
    public struct DFTSinglePrecisionInterleavedFunctions: vDSP_DiscreteTransformLifecycleFunctions {
        public static func makeDiscreteFourierTransform(previous: OpaquePointer?, count: Int, direction: vDSP.FourierTransformDirection,
                                                        transformType: vDSP.DFTTransformType) throws -> OpaquePointer {
            guard let s = vDSP_DFT_Interleaved_CreateSetup(previous, vDSP_Length(count), direction.dftDirection,
                                                           transformType == .complexComplex ? .interleaved_ComplextoComplex : .interleaved_RealtoComplex)
            else { throw DFTError.invalidInterleavedCount(count: count) }
            return s
        }
        public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_Interleaved_DestroySetup(setup) }
    }
    public struct DFTDoublePrecisionInterleavedFunctions: vDSP_DiscreteTransformLifecycleFunctions {
        public static func makeDiscreteFourierTransform(previous: OpaquePointer?, count: Int, direction: vDSP.FourierTransformDirection,
                                                        transformType: vDSP.DFTTransformType) throws -> OpaquePointer {
            guard let s = vDSP_DFT_Interleaved_CreateSetupD(previous, vDSP_Length(count), direction.dftDirection,
                                                            transformType == .complexComplex ? .interleaved_ComplextoComplex : .interleaved_RealtoComplex)
            else { throw DFTError.invalidInterleavedCount(count: count) }
            return s
        }
        public static func destroySetup(_ setup: OpaquePointer) { vDSP_DFT_Interleaved_DestroySetupD(setup) }
    }

    /// A discrete Fourier transform of split complex (Float, Double) or interleaved (DSPComplex, DSPDoubleComplex)
    /// values. A complex-real transform of count values works on count / 2 complex values (vDSP's real packing).
    @available(iOS 17.0, *)
    public final class DiscreteFourierTransform<T: vDSP_DiscreteFourierTransformable> {
        let dftSetup: OpaquePointer
        let count: Int
        @available(*, deprecated, renamed: "init(previousDFT:count:direction:transformType:ofType:)")
        public convenience init(previous: DiscreteFourierTransform<Float>?, count: Int, direction: FourierTransformDirection,
                                transformType: DFTTransformType, ofType: T.Type) throws {
            // Only a Float transform's setup can be shared with another Float transform.
            try self.init(previousDFT: T.self == Float.self ? unsafeBitCast(previous, to: DiscreteFourierTransform<T>?.self) : nil,
                          count: count, direction: direction, transformType: transformType, ofType: ofType)
        }
        public init(previousDFT: DiscreteFourierTransform<T>? = nil, count: Int, direction: FourierTransformDirection,
                    transformType: DFTTransformType, ofType: T.Type) throws {
            dftSetup = try T.DiscreteFourierTransformFunctions.makeDiscreteFourierTransform(
                previous: previousDFT?.dftSetup, count: count, direction: direction, transformType: transformType)
            self.count = transformType == .complexComplex ? count : count / 2
        }
        deinit { T.DiscreteFourierTransformFunctions.destroySetup(dftSetup) }

        func _check(_ counts: Int...) {
            precondition(counts.allSatisfy { $0 >= count }, "vDSP.DiscreteFourierTransform: buffers shorter than the transform")
        }
    }
}

@available(iOS 17.0, *)
extension vDSP.DiscreteFourierTransform where T == Float {
    public func transform<U, V>(inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Float, V.Element == Float {
        _check(inputReal.count, inputImaginary.count, outputReal.count, outputImaginary.count)
        _dftExecute(inputReal, inputImaginary, &outputReal, &outputImaginary) { vDSP_DFT_Execute(dftSetup, $0, $1, $2, $3) }
    }
    public func transform<U>(real: U, imaginary: U) -> (real: [Float], imaginary: [Float]) where U: AccelerateBuffer, U.Element == Float {
        var r = [Float](repeating: 0, count: count), i = [Float](repeating: 0, count: count)
        transform(inputReal: real, inputImaginary: imaginary, outputReal: &r, outputImaginary: &i)
        return (r, i)
    }
}

@available(iOS 17.0, *)
extension vDSP.DiscreteFourierTransform where T == Double {
    public func transform<U, V>(inputReal: U, inputImaginary: U, outputReal: inout V, outputImaginary: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Double, V.Element == Double {
        _check(inputReal.count, inputImaginary.count, outputReal.count, outputImaginary.count)
        _dftExecute(inputReal, inputImaginary, &outputReal, &outputImaginary) { vDSP_DFT_ExecuteD(dftSetup, $0, $1, $2, $3) }
    }
    public func transform<U>(real: U, imaginary: U) -> (real: [Double], imaginary: [Double]) where U: AccelerateBuffer, U.Element == Double {
        var r = [Double](repeating: 0, count: count), i = [Double](repeating: 0, count: count)
        transform(inputReal: real, inputImaginary: imaginary, outputReal: &r, outputImaginary: &i)
        return (r, i)
    }
}

@available(iOS 17.0, *)
extension vDSP.DiscreteFourierTransform where T == DSPComplex {
    public func transform<U, V>(input: U, output: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == DSPComplex, V.Element == DSPComplex {
        _check(input.count, output.count)
        input.withUnsafeBufferPointer { i in output.withUnsafeMutableBufferPointer { o in
            vDSP_DFT_Interleaved_Execute(dftSetup, i.baseAddress!, o.baseAddress!) } }
    }
    public func transform<U>(input: U) -> [DSPComplex] where U: AccelerateBuffer, U.Element == DSPComplex {
        var o = [DSPComplex](repeating: DSPComplex(), count: count)
        transform(input: input, output: &o)
        return o
    }
}

@available(iOS 17.0, *)
extension vDSP.DiscreteFourierTransform where T == DSPDoubleComplex {
    public func transform<U, V>(input: U, output: inout V)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == DSPDoubleComplex, V.Element == DSPDoubleComplex {
        _check(input.count, output.count)
        input.withUnsafeBufferPointer { i in output.withUnsafeMutableBufferPointer { o in
            vDSP_DFT_Interleaved_ExecuteD(dftSetup, i.baseAddress!, o.baseAddress!) } }
    }
    public func transform<U>(input: U) -> [DSPDoubleComplex] where U: AccelerateBuffer, U.Element == DSPDoubleComplex {
        var o = [DSPDoubleComplex](repeating: DSPDoubleComplex(), count: count)
        transform(input: input, output: &o)
        return o
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
