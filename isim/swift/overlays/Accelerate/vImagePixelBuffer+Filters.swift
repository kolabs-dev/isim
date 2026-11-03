// isim Accelerate Swift overlay (issue #814): vImage.PixelBuffer's convolution, morphology, rotation and scaling
// operations for the formats Apple has them on, over isim's C vImage (frameworks/Accelerate/vimage*.c). Adapted.
@_exported import Accelerate
import CoreGraphics

extension vImage {
    /// A two-dimensional kernel: a convolution kernel, or a morphology structuring element.
    public struct ConvolutionKernel2D<ComponentType> {
        public let values: [ComponentType]
        public let width: vImagePixelCount
        public let height: vImagePixelCount
        public init(values: [ComponentType], width: Int, height: Int) {
            precondition(width % 2 == 1 && height % 2 == 1, "vImage.ConvolutionKernel2D: the width and height must be odd")
            precondition(values.count == width * height, "vImage.ConvolutionKernel2D: width x height values needed")
            self.values = values; self.width = vImagePixelCount(width); self.height = vImagePixelCount(height)
        }
        public init(values: [ComponentType], size: vImage.Size) { self.init(values: values, width: size.width, height: size.height) }
    }
    /// A structuring element for morphology: a kernel of the image's component type.
    public typealias StructuringElement<T> = ConvolutionKernel2D<T>

    /// Common one-dimensional kernels.
    public struct ConvolutionKernel {
        public static let gaussian1Dx3: [Float] = [1, 2, 1].map { $0 / 4 }
        public static let gaussian1Dx5: [Float] = [1, 4, 6, 4, 1].map { $0 / 16 }
        public static let gaussian1Dx7: [Float] = [1, 6, 15, 20, 15, 6, 1].map { $0 / 64 }
    }

    /// A morphology operation.
    public enum MorphologyOperation<ComponentType> {
        case dilate(structuringElement: vImage.ConvolutionKernel2D<ComponentType>)
        case erode(structuringElement: vImage.ConvolutionKernel2D<ComponentType>)
        case maximize(kernelSize: vImage.Size)
        case minimize(kernelSize: vImage.Size)
        public var structuringElement: vImage.ConvolutionKernel2D<ComponentType>? {
            switch self {
            case .dilate(let e), .erode(let e): return e
            case .maximize, .minimize: return nil
            }
        }
        public var width: vImagePixelCount {
            switch self {
            case .dilate(let e), .erode(let e): return e.width
            case .maximize(let s), .minimize(let s): return vImagePixelCount(s.width)
            }
        }
        public var height: vImagePixelCount {
            switch self {
            case .dilate(let e), .erode(let e): return e.height
            case .maximize(let s), .minimize(let s): return vImagePixelCount(s.height)
            }
        }
    }
}

// MARK: helpers

typealias _VB = UnsafePointer<vImage_Buffer>

@inline(__always) func _bytes<T, R>(_ value: T, as: R.Type, _ body: (UnsafePointer<R>) -> vImage_Error) -> vImage_Error {
    withUnsafeBytes(of: value) { body($0.bindMemory(to: R.self).baseAddress!) }
}
@inline(__always) func _fp16(_ on: Bool) -> vImage_Flags { on ? vImage_Flags(kvImageUseFP16Accumulator) : 0 }
extension vImage.EdgeMode {
    func _color(_ zero: PixelType) -> PixelType { _background ?? zero }
}
extension vImage.Rotation {
    /// A rotation in vImage's C sense: quarter turns, or radians, with a background colour fill.
    func _run(_ q: (UInt8) -> vImage_Error, _ any: (Float) -> vImage_Error) -> vImage_Error {
        if let t = _quarterTurns { return q(t) }
        return any(_radians)
    }
}
let _bgFill = vImage_Flags(kvImageBackgroundColorFill)

// MARK: convolution

extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Int16>, divisor: Int32? = nil, bias: Int32? = nil,
                         edgeMode: vImage.EdgeMode<Pixel_8>, destination: vImage.PixelBuffer<Format>) {
        let d = divisor ?? max(1, kernel.values.reduce(0) { $0 + Int32($1) })
        _call2(destination) { vImageConvolveWithBias_Planar8($0, $1, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width),
                                                             d, bias ?? 0, edgeMode._color(0), edgeMode._flags) }
    }
    public func separableConvolve(horizontalKernel: [Float], verticalKernel: [Float], bias: Float = 0,
                                  edgeMode: vImage.EdgeMode<Pixel_16U>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageSepConvolve_Planar8($0, $1, nil, 0, 0, horizontalKernel, UInt32(horizontalKernel.count), verticalKernel,
                                                        UInt32(verticalKernel.count), bias, edgeMode._color(0), edgeMode._flags) }
    }
    public func applyMorphology(operation: vImage.MorphologyOperation<Pixel_8>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            switch operation {
            case .dilate(let e): return vImageDilate_Planar8(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .erode(let e): return vImageErode_Planar8(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .maximize(let k): return vImageMax_Planar8(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            case .minimize(let k): return vImageMin_Planar8(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Float>, bias: Float? = nil, edgeMode: vImage.EdgeMode<Pixel_F>,
                         destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageConvolveWithBias_PlanarF($0, $1, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width),
                                                             bias ?? 0, edgeMode._color(0), edgeMode._flags) }
    }
    public func separableConvolve(horizontalKernel: [Float], verticalKernel: [Float], bias: Float = 0,
                                  edgeMode: vImage.EdgeMode<Pixel_F>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageSepConvolve_PlanarF($0, $1, nil, 0, 0, horizontalKernel, UInt32(horizontalKernel.count), verticalKernel,
                                                        UInt32(verticalKernel.count), bias, edgeMode._color(0), edgeMode._flags) }
    }
    public func applyMorphology(operation: vImage.MorphologyOperation<Pixel_F>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            switch operation {
            case .dilate(let e): return vImageDilate_PlanarF(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .erode(let e): return vImageErode_PlanarF(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .maximize(let k): return vImageMax_PlanarF(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            case .minimize(let k): return vImageMin_PlanarF(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func separableConvolve(horizontalKernel: [Float], verticalKernel: [Float], bias: Float = 0,
                                  edgeMode: vImage.EdgeMode<Pixel_16U>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageSepConvolve_Planar16U($0, $1, nil, 0, 0, horizontalKernel, UInt32(horizontalKernel.count), verticalKernel,
                                                          UInt32(verticalKernel.count), bias, edgeMode._color(0), edgeMode._flags) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16F {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Float>, bias: Float? = nil, edgeMode: vImage.EdgeMode<Pixel_16F>,
                         useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageConvolveWithBias_Planar16F($0, $1, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width),
                                                               bias ?? 0, edgeMode._color(0), edgeMode._flags | _fp16(useFloat16Accumulator)) }
    }
    public func separableConvolve(horizontalKernel: [Float], verticalKernel: [Float], bias: Float = 0, edgeMode: vImage.EdgeMode<Pixel_16F>,
                                  useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageSepConvolve_Planar16F($0, $1, nil, 0, 0, horizontalKernel, UInt32(horizontalKernel.count), verticalKernel,
                                                          UInt32(verticalKernel.count), bias, edgeMode._color(0),
                                                          edgeMode._flags | _fp16(useFloat16Accumulator)) }
    }
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_16F? = nil, useFloat16Accumulator: Bool,
                       destination: vImage.PixelBuffer<Format>) {
        let bg = backgroundColor ?? 0
        _call2(destination) { s, d in rotation._run({ vImageRotate90_Planar16F(s, d, $0, bg, 0) },
                                                    { vImageRotate_Planar16F(s, d, nil, $0, bg, _bgFill | _fp16(useFloat16Accumulator)) }) }
    }
    public func scale(useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageScale_Planar16F($0, $1, nil, _fp16(useFloat16Accumulator)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Int16>, divisor: Int32? = nil, bias: Int32? = nil,
                         edgeMode: vImage.EdgeMode<Pixel_8888>, destination: vImage.PixelBuffer<Format>) {
        let d = divisor ?? max(1, kernel.values.reduce(0) { $0 + Int32($1) })
        let bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, dst in _bytes(bg, as: UInt8.self) {
            vImageConvolveWithBias_ARGB8888(s, dst, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width), d, bias ?? 0, $0, edgeMode._flags) } }
    }
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Float>, bias: Float? = nil, edgeMode: vImage.EdgeMode<Pixel_8888>,
                         destination: vImage.PixelBuffer<Format>) {
        let bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, d in _bytes(bg, as: UInt8.self) {
            vImageConvolveFloatKernel_ARGB8888(s, d, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width), bias ?? 0, $0, edgeMode._flags) } }
    }
    /// A kernel, divisor and bias per channel.
    public func convolve(with kernels: (vImage.ConvolutionKernel2D<Int16>, vImage.ConvolutionKernel2D<Int16>, vImage.ConvolutionKernel2D<Int16>,
                                        vImage.ConvolutionKernel2D<Int16>),
                         divisors: (Int32, Int32, Int32, Int32)? = nil, biases: (Int32, Int32, Int32, Int32) = (0, 0, 0, 0),
                         edgeMode: vImage.EdgeMode<Pixel_8888>, destination: vImage.PixelBuffer<Format>) {
        let ks = [kernels.0, kernels.1, kernels.2, kernels.3]
        precondition(Set(ks.map { [$0.width, $0.height] }).count == 1, "vImage.PixelBuffer.convolve: the four kernels differ in size")
        let divs = divisors.map { [$0.0, $0.1, $0.2, $0.3] } ?? ks.map { k in max(1, k.values.reduce(0) { $0 + Int32($1) }) }
        let bs = [biases.0, biases.1, biases.2, biases.3], bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, d in
            ks[0].values.withUnsafeBufferPointer { k0 in ks[1].values.withUnsafeBufferPointer { k1 in
            ks[2].values.withUnsafeBufferPointer { k2 in ks[3].values.withUnsafeBufferPointer { k3 in
                var ptrs: [UnsafePointer<Int16>?] = [k0.baseAddress, k1.baseAddress, k2.baseAddress, k3.baseAddress]
                return _bytes(bg, as: UInt8.self) { c in
                    vImageConvolveMultiKernel_ARGB8888(s, d, nil, 0, 0, &ptrs, UInt32(ks[0].height), UInt32(ks[0].width), divs, bs, c, edgeMode._flags) }
            } } } }
        }
    }
    public func separableConvolve(horizontalKernel: [Float], verticalKernel: [Float], bias: Float = 0,
                                  edgeMode: vImage.EdgeMode<Pixel_8888>, destination: vImage.PixelBuffer<Format>) {
        let bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, d in _bytes(bg, as: UInt8.self) {
            vImageSepConvolve_ARGB8888(s, d, nil, 0, 0, horizontalKernel, UInt32(horizontalKernel.count), verticalKernel,
                                       UInt32(verticalKernel.count), bias, $0, edgeMode._flags) } }
    }
    public func boxConvolved(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8888>) -> vImage.PixelBuffer<Format> {
        let out = vImage.PixelBuffer<Format>(size: size); boxConvolve(kernelSize: kernelSize, edgeMode: edgeMode, destination: out); return out
    }
    public func tentConvolved(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8888>) -> vImage.PixelBuffer<Format> {
        let out = vImage.PixelBuffer<Format>(size: size); tentConvolve(kernelSize: kernelSize, edgeMode: edgeMode, destination: out); return out
    }
    public func applyMorphology(operation: vImage.MorphologyOperation<Pixel_8>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            switch operation {
            case .dilate(let e): return vImageDilate_ARGB8888(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .erode(let e): return vImageErode_ARGB8888(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .maximize(let k): return vImageMax_ARGB8888(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            case .minimize(let k): return vImageMin_ARGB8888(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Float>, bias: Float? = nil, edgeMode: vImage.EdgeMode<Pixel_FFFF>,
                         destination: vImage.PixelBuffer<Format>) {
        let bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, d in _bytes(bg, as: Float.self) {
            vImageConvolveWithBias_ARGBFFFF(s, d, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width), bias ?? 0, $0, edgeMode._flags) } }
    }
    public func applyMorphology(operation: vImage.MorphologyOperation<Pixel_F>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            switch operation {
            case .dilate(let e): return vImageDilate_ARGBFFFF(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .erode(let e): return vImageErode_ARGBFFFF(s, d, 0, 0, e.values, e.height, e.width, 0)
            case .maximize(let k): return vImageMax_ARGBFFFF(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            case .minimize(let k): return vImageMin_ARGBFFFF(s, d, nil, 0, 0, vImagePixelCount(k.height), vImagePixelCount(k.width), 0)
            }
        }
    }
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_FFFF? = nil, destination: vImage.PixelBuffer<Format>) {
        let bg = backgroundColor ?? (0, 0, 0, 0)
        _call2(destination) { s, d in _bytes(bg, as: Float.self) { c in
            rotation._run({ vImageRotate90_ARGBFFFF(s, d, $0, c, 0) }, { vImageRotate_ARGBFFFF(s, d, nil, $0, c, _bgFill) }) } }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx4 {
    public func convolve(with kernel: vImage.ConvolutionKernel2D<Float>, bias: Float? = nil, edgeMode: vImage.EdgeMode<Pixel_ARGB_16F>,
                         useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        let bg = edgeMode._color((0, 0, 0, 0))
        _call2(destination) { s, d in _bytes(bg, as: UInt16.self) {
            vImageConvolveWithBias_ARGB16F(s, d, nil, 0, 0, kernel.values, UInt32(kernel.height), UInt32(kernel.width), bias ?? 0, $0,
                                           edgeMode._flags | _fp16(useFloat16Accumulator)) } }
    }
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_ARGB_16F? = nil, useFloat16Accumulator: Bool,
                       destination: vImage.PixelBuffer<Format>) {
        let bg = backgroundColor ?? (0, 0, 0, 0)
        _call2(destination) { s, d in _bytes(bg, as: UInt16.self) { c in
            rotation._run({ vImageRotate90_ARGB16F(s, d, $0, c, 0) },
                          { vImageRotate_ARGB16F(s, d, nil, $0, c, _bgFill | _fp16(useFloat16Accumulator)) }) } }
    }
    public func scale(useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageScale_ARGB16F($0, $1, nil, _fp16(useFloat16Accumulator)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx2 {
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_16F16F? = nil, useFloat16Accumulator: Bool,
                       destination: vImage.PixelBuffer<Format>) {
        let bg = backgroundColor ?? (0, 0)
        _call2(destination) { s, d in _bytes(bg, as: UInt16.self) { c in
            rotation._run({ vImageRotate90_CbCr16F(s, d, $0, c, 0) },
                          { vImageRotate_CbCr16F(s, d, nil, $0, c, _bgFill | _fp16(useFloat16Accumulator)) }) } }
    }
    public func scale(useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageScale_CbCr16F($0, $1, nil, _fp16(useFloat16Accumulator)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_ARGB_16U? = nil, destination: vImage.PixelBuffer<Format>) {
        let bg = backgroundColor ?? (0, 0, 0, 0)
        _call2(destination) { s, d in _bytes(bg, as: UInt16.self) { c in
            rotation._run({ vImageRotate90_ARGB16U(s, d, $0, c, 0) }, { vImageRotate_ARGB16U(s, d, nil, $0, c, _bgFill) }) } }
    }
}
