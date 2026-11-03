// isim Accelerate Swift overlay (issue #814): vImage.PixelBuffer's affine and perspective transforms and shears, and
// vImage_PerpsectiveTransform's Swift API, over isim's C vImage. Adapted.
@_exported import Accelerate
import CoreGraphics
import simd

extension vImage {
    /// The direction of a shear.
    public enum ShearDirection { case horizontal, vertical }
}

extension vImage_PerpsectiveTransform {
    /// Four corners: top left, top right, bottom left, bottom right.
    public typealias QuadrilateralPoints = (simd_float2, simd_float2, simd_float2, simd_float2)
    /// How a perspective warp samples the source.
    public enum Interpolation {
        case nearest, linear
        var _c: vImage_WarpInterpolation { self == .nearest ? kvImageInterpolationNearest : kvImageInterpolationLinear }
    }
    /// The transform mapping one quadrilateral onto another (nil when the points are degenerate).
    public init?(source: QuadrilateralPoints, destination: QuadrilateralPoints) {
        func flat(_ q: QuadrilateralPoints) -> [Float] { [q.0.x, q.0.y, q.1.x, q.1.y, q.2.x, q.2.y, q.3.x, q.3.y] }
        var t = vImage_PerpsectiveTransform()
        let s = flat(source), d = flat(destination)
        let e = s.withUnsafeBytes { sp in d.withUnsafeBytes { dp in
            vImageGetPerspectiveWarp(sp.baseAddress!.assumingMemoryBound(to: (Float, Float).self),
                                     dp.baseAddress!.assumingMemoryBound(to: (Float, Float).self), &t, 0) } }
        guard e == kvImageNoError else { return nil }
        self = t
    }
}

func _affine(_ t: CGAffineTransform) -> vImage_AffineTransform {
    vImage_AffineTransform(a: Float(t.a), b: Float(t.b), c: Float(t.c), d: Float(t.d), tx: Float(t.tx), ty: Float(t.ty))
}

// MARK: affine transforms

extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_8? = nil, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { vImageAffineWarpCG_Planar8($0, $1, nil, &t, backgroundColor ?? 0, _bgFill) }
    }
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_8, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { vImagePerspectiveWarp_Planar8($0, $1, nil, &t, interpolation._c, backgroundColor, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_F? = nil, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { vImageAffineWarpCG_PlanarF($0, $1, nil, &t, backgroundColor ?? 0, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_16U, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { vImagePerspectiveWarp_Planar16U($0, $1, nil, &t, interpolation._c, backgroundColor, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16F {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_16F? = nil, useFloat16Accumulator: Bool,
                          destination: vImage.PixelBuffer<Format>) {
        var t = _affine(transform)
        _call2(destination) { vImageAffineWarp_Planar16F($0, $1, nil, &t, backgroundColor ?? 0, _bgFill | _fp16(useFloat16Accumulator)) }
    }
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_16F, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { vImagePerspectiveWarp_Planar16F($0, $1, nil, &t, interpolation._c, backgroundColor, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_8888? = nil, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { s, d in _bytes(backgroundColor ?? (0, 0, 0, 0), as: UInt8.self) { vImageAffineWarpCG_ARGB8888(s, d, nil, &t, $0, _bgFill) } }
    }
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_8888, destination: vImage.PixelBuffer<Format>) {
        var t = transform, bg = [backgroundColor.0, backgroundColor.1, backgroundColor.2, backgroundColor.3]
        _call2(destination) { vImagePerspectiveWarp_ARGB8888($0, $1, nil, &t, interpolation._c, &bg, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_FFFF? = nil, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { s, d in _bytes(backgroundColor ?? (0, 0, 0, 0), as: Float.self) { vImageAffineWarpCG_ARGBFFFF(s, d, nil, &t, $0, _bgFill) } }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_ARGB_16U? = nil, destination: vImage.PixelBuffer<Format>) {
        var t = transform
        _call2(destination) { s, d in _bytes(backgroundColor ?? (0, 0, 0, 0), as: UInt16.self) { vImageAffineWarpCG_ARGB16U(s, d, nil, &t, $0, _bgFill) } }
    }
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_ARGB_16U, destination: vImage.PixelBuffer<Format>) {
        var t = transform, bg = [backgroundColor.0, backgroundColor.1, backgroundColor.2, backgroundColor.3]
        _call2(destination) { vImagePerspectiveWarp_ARGB16U($0, $1, nil, &t, interpolation._c, &bg, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx4 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_ARGB_16F? = nil, useFloat16Accumulator: Bool,
                          destination: vImage.PixelBuffer<Format>) {
        var t = _affine(transform)
        _call2(destination) { s, d in _bytes(backgroundColor ?? (0, 0, 0, 0), as: UInt16.self) {
            vImageAffineWarp_ARGB16F(s, d, nil, &t, $0, _bgFill | _fp16(useFloat16Accumulator)) } }
    }
    public func transform(_ transform: vImage_PerpsectiveTransform, interpolation: vImage_PerpsectiveTransform.Interpolation,
                          backgroundColor: Pixel_ARGB_16F, destination: vImage.PixelBuffer<Format>) {
        var t = transform, bg = [backgroundColor.0, backgroundColor.1, backgroundColor.2, backgroundColor.3]
        _call2(destination) { vImagePerspectiveWarp_ARGB16F($0, $1, nil, &t, interpolation._c, &bg, _bgFill) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx2 {
    public func transform(_ transform: CGAffineTransform, backgroundColor: Pixel_16F16F? = nil, useFloat16Accumulator: Bool,
                          destination: vImage.PixelBuffer<Format>) {
        var t = _affine(transform)
        _call2(destination) { s, d in _bytes(backgroundColor ?? (0, 0), as: UInt16.self) {
            vImageAffineWarp_CbCr16F(s, d, nil, &t, $0, _bgFill | _fp16(useFloat16Accumulator)) } }
    }
}

// MARK: shears

typealias _ShearD<C> = (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImagePixelCount, vImagePixelCount, Double, Double,
                        ResamplingFilter, C, vImage_Flags) -> vImage_Error
typealias _ShearF<C> = (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImagePixelCount, vImagePixelCount, Float, Float,
                        ResamplingFilter, C, vImage_Flags) -> vImage_Error

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    func _shear<T: BinaryFloatingPoint, C>(_ direction: vImage.ShearDirection, _ translate: T, _ slope: T, _ filter: ResamplingFilter, _ color: C,
                                           _ flags: vImage_Flags, _ destination: vImage.PixelBuffer<Format>, _ h: _ShearD<C>, _ v: _ShearD<C>) {
        _call2(destination) { (direction == .horizontal ? h : v)($0, $1, 0, 0, Double(translate), Double(slope), filter, color, flags) }
    }
    func _shearF<C>(_ direction: vImage.ShearDirection, _ translate: Float, _ slope: Float, _ filter: ResamplingFilter, _ color: C,
                    _ flags: vImage_Flags, _ destination: vImage.PixelBuffer<Format>, _ h: _ShearF<C>, _ v: _ShearF<C>) {
        _call2(destination) { (direction == .horizontal ? h : v)($0, $1, 0, 0, translate, slope, filter, color, flags) }
    }
}
func _shearColor<T, E>(_ c: T?, _ zero: T, _ body: (UnsafePointer<E>) -> Void) {
    withUnsafeBytes(of: c ?? zero) { body($0.bindMemory(to: E.self).baseAddress!) }
}

extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_8? = nil, destination: vImage.PixelBuffer<Format>) {
        _shear(direction, translate, slope, resamplingFilter, backgroundColor ?? 0, _bgFill, destination, vImageHorizontalShearD_Planar8, vImageVerticalShearD_Planar8)
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_F? = nil, destination: vImage.PixelBuffer<Format>) {
        _shear(direction, translate, slope, resamplingFilter, backgroundColor ?? 0, _bgFill, destination, vImageHorizontalShearD_PlanarF, vImageVerticalShearD_PlanarF)
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func shear(direction: vImage.ShearDirection, translate: Float, slope: Float, resamplingFilter: ResamplingFilter,
                      backgroundColor: Pixel_16U? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearF(direction, translate, slope, resamplingFilter, backgroundColor ?? 0, _bgFill, destination, vImageHorizontalShear_Planar16U, vImageVerticalShear_Planar16U)
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16F {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_16F? = nil, useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _shear(direction, translate, slope, resamplingFilter, backgroundColor ?? 0, _bgFill | _fp16(useFloat16Accumulator), destination,
               vImageHorizontalShearD_Planar16F, vImageVerticalShearD_Planar16F)
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x2 {
    public func shear(direction: vImage.ShearDirection, translate: Float, slope: Float, resamplingFilter: ResamplingFilter,
                      backgroundColor: Pixel_88? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0)) { (c: UnsafePointer<UInt8>) in
            _shearF(direction, translate, slope, resamplingFilter, c, _bgFill, destination, vImageHorizontalShear_CbCr8, vImageVerticalShear_CbCr8) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_8888? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0, 0, 0)) { (c: UnsafePointer<UInt8>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill, destination, vImageHorizontalShearD_ARGB8888, vImageVerticalShearD_ARGB8888) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_FFFF? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0, 0, 0)) { (c: UnsafePointer<Float>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill, destination, vImageHorizontalShearD_ARGBFFFF, vImageVerticalShearD_ARGBFFFF) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_ARGB_16U? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0, 0, 0)) { (c: UnsafePointer<UInt16>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill, destination, vImageHorizontalShearD_ARGB16U, vImageVerticalShearD_ARGB16U) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux2 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_16U16U? = nil, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0)) { (c: UnsafePointer<UInt16>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill, destination, vImageHorizontalShearD_CbCr16U, vImageVerticalShearD_CbCr16U) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx4 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_ARGB_16F? = nil, useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0, 0, 0)) { (c: UnsafePointer<UInt16>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill | _fp16(useFloat16Accumulator), destination,
                   vImageHorizontalShearD_ARGB16F, vImageVerticalShearD_ARGB16F) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx2 {
    public func shear<T: BinaryFloatingPoint>(direction: vImage.ShearDirection, translate: T, slope: T, resamplingFilter: ResamplingFilter,
                                              backgroundColor: Pixel_16F16F? = nil, useFloat16Accumulator: Bool, destination: vImage.PixelBuffer<Format>) {
        _shearColor(backgroundColor, (0, 0)) { (c: UnsafePointer<UInt16>) in
            _shear(direction, translate, slope, resamplingFilter, c, _bgFill | _fp16(useFloat16Accumulator), destination,
                   vImageHorizontalShearD_CbCr16F, vImageVerticalShearD_CbCr16F) }
    }
}
