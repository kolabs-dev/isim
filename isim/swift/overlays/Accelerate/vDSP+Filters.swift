// isim Accelerate Swift overlay (issue #543): vDSP.Biquad, vDSP.DCT and vDSP.FFT2D, over isim's C vDSP
// (frameworks/Accelerate). Adapted.
@_exported import Accelerate

// MARK: biquads

public protocol vDSP_BiquadFunctions {
    associatedtype Scalar
    static func makeBiquadSetup(channelCount: vDSP_Length, coefficients: [Double], sectionCount: vDSP_Length) -> OpaquePointer?
    static func applySingle<U, V>(source: U, destination: inout V, delays: UnsafeMutablePointer<Scalar>, setup: vDSP_biquad_Setup,
                                  sectionCount: vDSP_Length, count: vDSP_Length)
        where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Scalar, V.Element == Scalar
    static func applyMulti(setup: vDSP_biquadm_SetupD, pInputs: UnsafeMutablePointer<UnsafePointer<Scalar>>,
                           pOutputs: UnsafeMutablePointer<UnsafeMutablePointer<Scalar>>, count: vDSP_Length)
    static func destroySetup(channelCount: UInt, biquadSetup: OpaquePointer)
}

public protocol vDSP_FloatingPointBiquadFilterable: BinaryFloatingPoint {
    associatedtype BiquadFunctions: vDSP_BiquadFunctions where BiquadFunctions.Scalar == Self
}

extension vDSP {
    public enum VectorizableFloat: vDSP_BiquadFunctions {
        public typealias Scalar = Float
        public static func makeBiquadSetup(channelCount: UInt, coefficients: [Double], sectionCount: UInt) -> OpaquePointer? {
            channelCount == 1 ? vDSP_biquad_CreateSetup(coefficients, sectionCount) : vDSP_biquadm_CreateSetup(coefficients, sectionCount, channelCount)
        }
        public static func applySingle<U, V>(source: U, destination: inout V, delays: UnsafeMutablePointer<Float>, setup: vDSP_biquad_Setup,
                                             sectionCount: vDSP_Length, count: vDSP_Length)
            where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Float, V.Element == Float {
            source.withUnsafeBufferPointer { s in destination.withUnsafeMutableBufferPointer { d in
                vDSP_biquad(setup, delays, s.baseAddress!, 1, d.baseAddress!, 1, count) } }
        }
        public static func applyMulti(setup: vDSP_biquadm_SetupD, pInputs: UnsafeMutablePointer<UnsafePointer<Float>>,
                                      pOutputs: UnsafeMutablePointer<UnsafeMutablePointer<Float>>, count: vDSP_Length) {
            vDSP_biquadm(setup, pInputs, 1, pOutputs, 1, count)
        }
        public static func destroySetup(channelCount: UInt, biquadSetup: OpaquePointer) {
            if channelCount == 1 { vDSP_biquad_DestroySetup(biquadSetup) } else { vDSP_biquadm_DestroySetup(biquadSetup) }
        }
    }
    public enum VectorizableDouble: vDSP_BiquadFunctions {
        public typealias Scalar = Double
        public static func makeBiquadSetup(channelCount: vDSP_Length, coefficients: [Double], sectionCount: vDSP_Length) -> OpaquePointer? {
            channelCount == 1 ? vDSP_biquad_CreateSetupD(coefficients, sectionCount) : vDSP_biquadm_CreateSetupD(coefficients, sectionCount, channelCount)
        }
        public static func applySingle<U, V>(source: U, destination: inout V, delays: UnsafeMutablePointer<Double>, setup: vDSP_biquad_Setup,
                                             sectionCount: vDSP_Length, count: vDSP_Length)
            where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Double, V.Element == Double {
            source.withUnsafeBufferPointer { s in destination.withUnsafeMutableBufferPointer { d in
                vDSP_biquadD(setup, delays, s.baseAddress!, 1, d.baseAddress!, 1, count) } }
        }
        public static func applyMulti(setup: vDSP_biquadm_SetupD, pInputs: UnsafeMutablePointer<UnsafePointer<Double>>,
                                      pOutputs: UnsafeMutablePointer<UnsafeMutablePointer<Double>>, count: vDSP_Length) {
            vDSP_biquadmD(setup, pInputs, 1, pOutputs, 1, count)
        }
        public static func destroySetup(channelCount: UInt, biquadSetup: OpaquePointer) {
            if channelCount == 1 { vDSP_biquad_DestroySetupD(biquadSetup) } else { vDSP_biquadm_DestroySetupD(biquadSetup) }
        }
    }
}
extension Float: vDSP_FloatingPointBiquadFilterable { public typealias BiquadFunctions = vDSP.VectorizableFloat }
extension Double: vDSP_FloatingPointBiquadFilterable { public typealias BiquadFunctions = vDSP.VectorizableDouble }

final class _BiquadState<T: vDSP_FloatingPointBiquadFilterable> {
    let setup: OpaquePointer
    let channelCount: vDSP_Length, sectionCount: vDSP_Length
    var delays: [T]
    init?(coefficients: [Double], channelCount: vDSP_Length, sectionCount: vDSP_Length) {
        guard channelCount > 0, sectionCount > 0, coefficients.count == Int(5 * channelCount * sectionCount),
              let s = T.BiquadFunctions.makeBiquadSetup(channelCount: channelCount, coefficients: coefficients, sectionCount: sectionCount) else { return nil }
        setup = s
        self.channelCount = channelCount; self.sectionCount = sectionCount
        delays = [T](repeating: 0, count: Int(2 * sectionCount + 2))
    }
    deinit { T.BiquadFunctions.destroySetup(channelCount: channelCount, biquadSetup: setup) }
}

extension vDSP {
    /// A cascade of biquadratic IIR sections (b0, b1, b2, a1, a2 each), one or more channels. With several channels, the
    /// input and output hold the channels one after another (each count / channelCount values); the coefficients are
    /// section by section, each coefficient interleaved across the channels (as vDSP_biquadm_CreateSetup).
    public struct Biquad<T: vDSP_FloatingPointBiquadFilterable> {
        let state: _BiquadState<T>
        public init?(coefficients: [Double], channelCount: vDSP_Length, sectionCount: vDSP_Length, ofType: T.Type) {
            guard let s = _BiquadState<T>(coefficients: coefficients, channelCount: channelCount, sectionCount: sectionCount) else { return nil }
            state = s
        }
        public mutating func apply<U, V>(input: U, output: inout V) where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == T, V.Element == T {
            let n = min(input.count, output.count)
            guard n > 0 else { return }
            let st = state
            if st.channelCount == 1 {
                st.delays.withUnsafeMutableBufferPointer { d in
                    T.BiquadFunctions.applySingle(source: input, destination: &output, delays: d.baseAddress!, setup: st.setup,
                                                  sectionCount: st.sectionCount, count: vDSP_Length(n))
                }
                return
            }
            let per = n / Int(st.channelCount)
            input.withUnsafeBufferPointer { i in output.withUnsafeMutableBufferPointer { o in
                var ins = (0..<Int(st.channelCount)).map { UnsafePointer(i.baseAddress! + $0 * per) }
                var outs = (0..<Int(st.channelCount)).map { o.baseAddress! + $0 * per }
                T.BiquadFunctions.applyMulti(setup: st.setup, pInputs: &ins, pOutputs: &outs, count: vDSP_Length(per))
            } }
        }
        public mutating func apply<U>(input: U) -> [T] where U: AccelerateBuffer, U.Element == T {
            var out = [T](repeating: 0, count: input.count)
            apply(input: input, output: &out)
            return out
        }
    }
}

// MARK: DCT (single precision, as Apple's)

extension vDSP {
    public enum DCTTransformType: CaseIterable {
        case II
        case III
        case IV
        public var dctType: vDSP_DCT_Type {
            switch self {
            case .II: return .II
            case .III: return .III
            case .IV: return .IV
            }
        }
    }
    /// The unnormalized DCT-II, -III or -IV of count values (count = f * 2^n, f in 1, 3, 5, 15, n >= 4)
    public class DCT {
        let setup: OpaquePointer
        let count: Int
        public init?(previous: DCT? = nil, count: Int, transformType: DCTTransformType) {
            guard let s = vDSP_DCT_CreateSetup(previous?.setup, vDSP_Length(count), transformType.dctType) else { return nil }
            setup = s
            self.count = count
        }
        deinit { vDSP_DFT_DestroySetup(setup) }
        public func transform<U, V>(_ vector: U, result: inout V) where U: AccelerateBuffer, V: AccelerateMutableBuffer, U.Element == Float, V.Element == Float {
            precondition(vector.count >= count && result.count >= count, "vDSP.DCT: buffers shorter than the transform")
            vector.withUnsafeBufferPointer { a in result.withUnsafeMutableBufferPointer { r in vDSP_DCT_Execute(setup, a.baseAddress!, r.baseAddress!) } }
        }
        public func transform<U>(_ vector: U) -> [Float] where U: AccelerateBuffer, U.Element == Float {
            var r = [Float](repeating: 0, count: count)
            transform(vector, result: &r)
            return r
        }
    }
}

// MARK: 2D real FFT (vDSP_fft2d_zrop's packing)

extension vDSP_FourierTransformFunctions {
    public static func transform2D(fftSetup: OpaquePointer, width: Int, height: Int, source: UnsafePointer<SplitComplex>,
                                   destination: UnsafeMutablePointer<SplitComplex>, direction: FFTDirection) {
        fatalError("isim: transform2D is not available for \(SplitComplex.self)")
    }
}
extension DSPSplitComplex {
    public static func transform2D(fftSetup: OpaquePointer, width: Int, height: Int, source: UnsafePointer<DSPSplitComplex>,
                                   destination: UnsafeMutablePointer<DSPSplitComplex>, direction: FFTDirection) {
        vDSP_fft2d_zrop(fftSetup, source, 1, 0, destination, 1, 0, vDSP_Length(log2(Double(width))), vDSP_Length(log2(Double(height))), direction)
    }
}
extension DSPDoubleSplitComplex {
    public static func transform2D(fftSetup: OpaquePointer, width: Int, height: Int, source: UnsafePointer<DSPDoubleSplitComplex>,
                                   destination: UnsafeMutablePointer<DSPDoubleSplitComplex>, direction: FFTDirection) {
        vDSP_fft2d_zropD(fftSetup, source, 1, 0, destination, 1, 0, vDSP_Length(log2(Double(width))), vDSP_Length(log2(Double(height))), direction)
    }
}

extension vDSP {
    /// A 2D real FFT of a width x height matrix (powers of two) held as width / 2 split complex values per row (even /
    /// odd pairs): forward gives twice the 2D DFT in vDSP's packing; inverse is unscaled.
    public final class FFT2D<T: vDSP_FourierTransformable> {
        let width: Int, height: Int
        let setup: OpaquePointer
        public init?(width: Int, height: Int, ofType: T.Type) {
            guard width >= 2, height >= 1, width & (width - 1) == 0, height & (height - 1) == 0,
                  let s = T.FFTFunctions.makeFFTSetup(log2n: vDSP_Length(log2(Double(max(width, height)))), radix: FFTRadix(kFFTRadix2)) else { return nil }
            self.width = width; self.height = height; setup = s
        }
        deinit { T.FFTFunctions.destroySetup(setup) }
        public func transform(input: T, output: inout T, direction: FourierTransformDirection) {
            withUnsafePointer(to: input) { src in withUnsafeMutablePointer(to: &output) { dst in
                if T.self == DSPSplitComplex.self {
                    DSPSplitComplex.transform2D(fftSetup: setup, width: width, height: height,
                                                source: UnsafeRawPointer(src).assumingMemoryBound(to: DSPSplitComplex.self),
                                                destination: UnsafeMutableRawPointer(dst).assumingMemoryBound(to: DSPSplitComplex.self),
                                                direction: direction.fftDirection)
                } else if T.self == DSPDoubleSplitComplex.self {
                    DSPDoubleSplitComplex.transform2D(fftSetup: setup, width: width, height: height,
                                                      source: UnsafeRawPointer(src).assumingMemoryBound(to: DSPDoubleSplitComplex.self),
                                                      destination: UnsafeMutableRawPointer(dst).assumingMemoryBound(to: DSPDoubleSplitComplex.self),
                                                      direction: direction.fftDirection)
                }
            } }
        }
    }
}
