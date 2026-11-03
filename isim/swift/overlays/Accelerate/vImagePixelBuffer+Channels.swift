// isim Accelerate Swift overlay (issue #814): vImage.PixelBuffer's compositing, premultiplication, flattening, channel
// operations, flood fill, histograms of interleaved formats, interleaving and the remaining conversions, over isim's C
// vImage. Adapted.
@_exported import Accelerate
import CoreGraphics

extension vImage {
    /// How alphaComposite combines a top layer with the buffer.
    public enum CompositeMode<ComponentType> {
        case nonpremultiplied
        case nonpremultipliedToPremultiplied
        case premultiplied
        case premultipliedWithConstantAlpha(ComponentType)
    }
    /// A blend mode of premultipliedAlphaBlend (RGBA).
    public enum BlendMode { case darken, lighten, multiply, screen }
    /// Where alpha is in a four-channel pixel.
    public enum ChannelOrdering { case ARGB, RGBA }
    /// Which neighbours a flood fill spreads to.
    public enum FloodFillConnectivity {
        case edges, edgesAndCorners
        var _c: Int32 { self == .edges ? 4 : 8 }
    }
}

/// vImage's channel mask: channel 0 is the high bit of four.
func _mask(_ channels: [UInt8]) -> UInt8 {
    channels.reduce(0) { m, c in precondition(c < 4, "vImage: channel \(c) out of range"); return m | (0x8 >> c) }
}
typealias _VB3 = (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    /// fn(a, b, c) on three buffers.
    func _call3<A, B>(_ b: vImage.PixelBuffer<A>, _ c: vImage.PixelBuffer<B>,
                      _ fn: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>) -> vImage_Error) {
        var x = _buffer, y = b._buffer, z = c._buffer
        let e = fn(&x, &y, &z)
        precondition(e >= 0, "vImage: error \(e)")
    }
    /// fn(self, self) in place.
    func _inPlace(_ fn: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>) -> vImage_Error) { _call2(self, fn) }
}

// MARK: compositing

extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    /// Composites a top layer over this buffer (alpha first).
    public func alphaComposite(_ mode: vImage.CompositeMode<Pixel_8>, topLayer: vImage.PixelBuffer<Format>, destination: vImage.PixelBuffer<Format>) {
        topLayer._call3(self, destination) { t, b, d in
            switch mode {
            case .nonpremultiplied: return vImageAlphaBlend_ARGB8888(t, b, d, 0)
            case .nonpremultipliedToPremultiplied: return vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGB8888(t, b, d, 0)
            case .premultiplied: return vImagePremultipliedAlphaBlend_ARGB8888(t, b, d, 0)
            case .premultipliedWithConstantAlpha(let a): return vImagePremultipliedConstAlphaBlend_ARGB8888(t, a, b, d, 0)
            }
        }
    }
    /// Blends a premultiplied RGBA top layer with this buffer.
    public func premultipliedAlphaBlend(_ mode: vImage.BlendMode, topLayer: vImage.PixelBuffer<Format>, destination: vImage.PixelBuffer<Format>) {
        let fn: _VB3
        switch mode {
        case .darken: fn = vImagePremultipliedAlphaBlendDarken_RGBA8888
        case .lighten: fn = vImagePremultipliedAlphaBlendLighten_RGBA8888
        case .multiply: fn = vImagePremultipliedAlphaBlendMultiply_RGBA8888
        case .screen: fn = vImagePremultipliedAlphaBlendScreen_RGBA8888
        }
        topLayer._call3(self, destination) { fn($0, $1, $2, 0) }
    }
    public func premultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImagePremultiplyData_ARGB8888($0, $1, 0) : vImagePremultiplyData_RGBA8888($0, $1, 0) }
    }
    public func unpremultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImageUnpremultiplyData_ARGB8888($0, $1, 0) : vImageUnpremultiplyData_RGBA8888($0, $1, 0) }
    }
    /// Composites over a background colour and drops alpha.
    public func flatten(channelOrdering: vImage.ChannelOrdering, backgroundColor: Pixel_8888, isPremultiplied: Bool,
                        destination: vImage.PixelBuffer<vImage.Interleaved8x3>) {
        var bg = [backgroundColor.0, backgroundColor.1, backgroundColor.2, backgroundColor.3]
        _call2(destination) { channelOrdering == .ARGB ? vImageFlatten_ARGB8888ToRGB888($0, $1, &bg, isPremultiplied, 0)
                                                       : vImageFlatten_RGBA8888ToRGB888($0, $1, &bg, isPremultiplied, 0) }
    }
    /// Drops alpha.
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x3>, channelOrdering: vImage.ChannelOrdering) {
        _call2(destination) { channelOrdering == .ARGB ? vImageConvert_ARGB8888toRGB888($0, $1, 0) : vImageConvert_RGBA8888toRGB888($0, $1, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func alphaComposite(_ mode: vImage.CompositeMode<Pixel_F>, topLayer: vImage.PixelBuffer<Format>, destination: vImage.PixelBuffer<Format>) {
        topLayer._call3(self, destination) { t, b, d in
            switch mode {
            case .nonpremultiplied: return vImageAlphaBlend_ARGBFFFF(t, b, d, 0)
            case .nonpremultipliedToPremultiplied: return vImageAlphaBlend_NonpremultipliedToPremultiplied_ARGBFFFF(t, b, d, 0)
            case .premultiplied: return vImagePremultipliedAlphaBlend_ARGBFFFF(t, b, d, 0)
            case .premultipliedWithConstantAlpha(let a): return vImagePremultipliedConstAlphaBlend_ARGBFFFF(t, a, b, d, 0)
            }
        }
    }
    public func premultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImagePremultiplyData_ARGBFFFF($0, $1, 0) : vImagePremultiplyData_RGBAFFFF($0, $1, 0) }
    }
    public func unpremultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImageUnpremultiplyData_ARGBFFFF($0, $1, 0) : vImageUnpremultiplyData_RGBAFFFF($0, $1, 0) }
    }
    public func flatten(channelOrdering: vImage.ChannelOrdering, backgroundColor: Pixel_FFFF, isPremultiplied: Bool,
                        destination: vImage.PixelBuffer<vImage.InterleavedFx3>) {
        var bg = [backgroundColor.0, backgroundColor.1, backgroundColor.2, backgroundColor.3]
        _call2(destination) { channelOrdering == .ARGB ? vImageFlatten_ARGBFFFFToRGBFFF($0, $1, &bg, isPremultiplied, 0)
                                                       : vImageFlatten_RGBAFFFFToRGBFFF($0, $1, &bg, isPremultiplied, 0) }
    }
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx3>, channelOrdering: vImage.ChannelOrdering) {
        _call2(destination) { channelOrdering == .ARGB ? vImageConvert_ARGBFFFFtoRGBFFF($0, $1, 0) : vImageConvert_RGBAFFFFtoRGBFFF($0, $1, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func premultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImagePremultiplyData_ARGB16U($0, $1, 0) : vImagePremultiplyData_RGBA16U($0, $1, 0) }
    }
    public func unpremultiply(channelOrdering: vImage.ChannelOrdering) {
        _inPlace { channelOrdering == .ARGB ? vImageUnpremultiplyData_ARGB16U($0, $1, 0) : vImageUnpremultiplyData_RGBA16U($0, $1, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx4 {
    /// Premultiplies RGBA half floats in place.
    public func premultiply() { _inPlace { vImagePremultiplyData_RGBA16F($0, $1, 0) } }
    public func unpremultiply() { _inPlace { vImageUnpremultiplyData_RGBA16F($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format == vImage.Planar8 {
    /// Premultiplies by an alpha plane, in place.
    public func premultiply(alpha: vImage.PixelBuffer<Format>) { _call3(alpha, self) { vImagePremultiplyData_Planar8($0, $1, $2, 0) } }
    public func unpremultiply(alpha: vImage.PixelBuffer<Format>) { _call3(alpha, self) { vImageUnpremultiplyData_Planar8($0, $1, $2, 0) } }
    public func overwriteChannels(withScalar value: Pixel_8) {
        var b = _buffer; precondition(vImageOverwriteChannelsWithScalar_Planar8(value, &b, 0) >= 0)
    }
    public func floodFill(from seed: CGPoint, newColor: Pixel_8, connectivity: vImage.FloodFillConnectivity) {
        var b = _buffer
        precondition(vImageFloodFill_Planar8(&b, nil, vImagePixelCount(seed.x), vImagePixelCount(seed.y), newColor, connectivity._c, 0) >= 0)
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func premultiply(alpha: vImage.PixelBuffer<Format>) { _call3(alpha, self) { vImagePremultiplyData_PlanarF($0, $1, $2, 0) } }
    public func unpremultiply(alpha: vImage.PixelBuffer<Format>) { _call3(alpha, self) { vImageUnpremultiplyData_PlanarF($0, $1, $2, 0) } }
    public func overwriteChannels(withScalar value: Pixel_F) {
        var b = _buffer; precondition(vImageOverwriteChannelsWithScalar_PlanarF(value, &b, 0) >= 0)
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16F {
    public func overwriteChannels(withScalar value: Pixel_16F) {
        var b = _buffer; precondition(vImageOverwriteChannelsWithScalar_Planar16F(value, &b, 0) >= 0)
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func floodFill(from seed: CGPoint, newColor: Pixel_16U, connectivity: vImage.FloodFillConnectivity) {
        var b = _buffer
        precondition(vImageFloodFill_Planar16U(&b, nil, vImagePixelCount(seed.x), vImagePixelCount(seed.y), newColor, connectivity._c, 0) >= 0)
    }
}

// MARK: channels

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    /// Copies the given channels from another buffer of the format, the others from this one.
    func _overwrite(_ channels: [UInt8], _ other: vImage.PixelBuffer<Format>, _ destination: vImage.PixelBuffer<Format>) {
        precondition(other.size == size && destination.size == size, "vImage.PixelBuffer.overwriteChannels: the buffers differ in size")
        let n = Format.channelCount, set = Set(channels.map(Int.init)), s = _buffer, o = other._buffer, d = destination._buffer
        for y in 0..<height {
            let sr = s.data.advanced(by: y * s.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
            let or = o.data.advanced(by: y * o.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
            let dr = d.data.advanced(by: y * d.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
            for x in 0..<width { for c in 0..<n { dr[x * n + c] = set.contains(c) ? or[x * n + c] : sr[x * n + c] } }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func overwriteChannels(_ channels: [UInt8], withInterleavedBuffer buffer: vImage.PixelBuffer<Format>, destination: vImage.PixelBuffer<Format>) {
        _overwrite(channels, buffer, destination)
    }
    public func overwriteChannels(_ channels: [UInt8], withPixel pixel: Pixel_8888, destination: vImage.PixelBuffer<Format>) {
        var p = [pixel.0, pixel.1, pixel.2, pixel.3]
        _call2(destination) { vImageOverwriteChannelsWithPixel_ARGB8888(&p, $0, $1, _mask(channels), 0) }
    }
    public func overwriteChannels(_ channels: [UInt8], withPlanarBuffer buffer: vImage.PixelBuffer<vImage.Planar8>, destination: vImage.PixelBuffer<Format>) {
        buffer._call3(self, destination) { vImageOverwriteChannels_ARGB8888($0, $1, $2, _mask(channels), 0) }
    }
    public func overwriteChannels(_ channels: [UInt8], withScalar value: Pixel_8, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageOverwriteChannelsWithScalar_ARGB8888(value, $0, $1, _mask(channels), 0) }
    }
    public func extractChannel(at index: Int, destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { vImageExtractChannel_ARGB8888($0, $1, index, 0) }
    }
    public func floodFill(from seed: CGPoint, newColor: Pixel_8888, connectivity: vImage.FloodFillConnectivity) {
        var b = _buffer, c = [newColor.0, newColor.1, newColor.2, newColor.3]
        precondition(vImageFloodFill_ARGB8888(&b, nil, vImagePixelCount(seed.x), vImagePixelCount(seed.y), &c, connectivity._c, 0) >= 0)
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func overwriteChannels(_ channels: [UInt8], withInterleavedBuffer buffer: vImage.PixelBuffer<Format>, destination: vImage.PixelBuffer<Format>) {
        _overwrite(channels, buffer, destination)
    }
    public func overwriteChannels(_ channels: [UInt8], withPixel pixel: Pixel_FFFF, destination: vImage.PixelBuffer<Format>) {
        var p = [pixel.0, pixel.1, pixel.2, pixel.3]
        _call2(destination) { vImageOverwriteChannelsWithPixel_ARGBFFFF(&p, $0, $1, _mask(channels), 0) }
    }
    public func overwriteChannels(_ channels: [UInt8], withPlanarBuffer buffer: vImage.PixelBuffer<vImage.PlanarF>, destination: vImage.PixelBuffer<Format>) {
        buffer._call3(self, destination) { vImageOverwriteChannels_ARGBFFFF($0, $1, $2, _mask(channels), 0) }
    }
    public func overwriteChannels(_ channels: [UInt8], withScalar value: Pixel_F, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageOverwriteChannelsWithScalar_ARGBFFFF(value, $0, $1, _mask(channels), 0) }
    }
    public func extractChannel(at index: Int, destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _call2(destination) { vImageExtractChannel_ARGBFFFF($0, $1, index, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func overwriteChannels(_ channels: [UInt8], withPixel pixel: Pixel_ARGB_16U, destination: vImage.PixelBuffer<Format>) {
        var p = [pixel.0, pixel.1, pixel.2, pixel.3]
        _call2(destination) { vImageOverwriteChannelsWithPixel_ARGB16U(&p, $0, $1, _mask(channels), 0) }
    }
    public func extractChannel(at index: Int, destination: vImage.PixelBuffer<vImage.Planar16U>) {
        _call2(destination) { vImageExtractChannel_ARGB16U($0, $1, index, 0) }
    }
    public func floodFill(from seed: CGPoint, newColor: Pixel_ARGB_16U, connectivity: vImage.FloodFillConnectivity) {
        var b = _buffer, c = [newColor.0, newColor.1, newColor.2, newColor.3]
        precondition(vImageFloodFill_ARGB16U(&b, nil, vImagePixelCount(seed.x), vImagePixelCount(seed.y), &c, connectivity._c, 0) >= 0)
    }
}

// MARK: histograms

extension vImage.PixelBuffer {
    public typealias Histogram888 = ([vImagePixelCount], [vImagePixelCount], [vImagePixelCount])
    public typealias Histogram8888 = ([vImagePixelCount], [vImagePixelCount], [vImagePixelCount], [vImagePixelCount])
    public typealias HistogramFFF = ([vImagePixelCount], [vImagePixelCount], [vImagePixelCount])
    public typealias HistogramFFFF = ([vImagePixelCount], [vImagePixelCount], [vImagePixelCount], [vImagePixelCount])
}

func _withHistogramPointers<R>(_ h: inout [[vImagePixelCount]], _ body: (UnsafeMutablePointer<UnsafeMutablePointer<vImagePixelCount>?>) -> R) -> R {
    let bins = h.map(\.count), flat = UnsafeMutablePointer<vImagePixelCount>.allocate(capacity: max(1, bins.reduce(0, +)))
    defer { flat.deallocate() }
    var ptrs: [UnsafeMutablePointer<vImagePixelCount>?] = [], offset = 0
    for (i, n) in bins.enumerated() { (flat + offset).initialize(from: h[i], count: n); ptrs.append(flat + offset); offset += n }
    let r = body(&ptrs)
    offset = 0
    for (i, n) in bins.enumerated() { h[i] = Array(UnsafeBufferPointer(start: flat + offset, count: n)); offset += n }
    return r
}

extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func histogram() -> Histogram8888 {
        var h = [[vImagePixelCount]](repeating: [vImagePixelCount](repeating: 0, count: 256), count: 4), b = _buffer
        _ = _withHistogramPointers(&h) { vImageHistogramCalculation_ARGB8888(&b, $0, 0) }
        return (h[0], h[1], h[2], h[3])
    }
    public func specifyHistogram(_ histogram: Histogram8888, destination: vImage.PixelBuffer<Format>) {
        var h = [histogram.0, histogram.1, histogram.2, histogram.3]
        _call2(destination) { s, d in _withHistogramPointers(&h) { p in
            p.withMemoryRebound(to: UnsafePointer<vImagePixelCount>?.self, capacity: 4) { vImageHistogramSpecification_ARGB8888(s, d, $0, 0) } } }
    }
    public func equalizeHistogram(destination: vImage.PixelBuffer<Format>) { _call2(destination) { vImageEqualization_ARGB8888($0, $1, 0) } }
    public func contrastStretch(destination: vImage.PixelBuffer<Format>) { _call2(destination) { vImageContrastStretch_ARGB8888($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x3 {
    public func histogram() -> Histogram888 {
        let a = array
        var h = [[vImagePixelCount]](repeating: [vImagePixelCount](repeating: 0, count: 256), count: 3)
        for i in 0..<a.count { h[i % 3][Int(a[i])] += 1 }
        return (h[0], h[1], h[2])
    }
    /// Per channel, through planar buffers.
    public func specifyHistogram(_ histogram: Histogram888, destination: vImage.PixelBuffer<Format>) {
        let src = planarBuffers(), dst = destination.planarBuffers(), hs = [histogram.0, histogram.1, histogram.2]
        for c in 0..<3 { src[c]._call2(dst[c]) { vImageHistogramSpecification_Planar8($0, $1, hs[c], 0) } }
        destination.interleave(planarSourceBuffers: dst)
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    /// Bins over 0...1.
    public func histogram(binCount: Int) -> HistogramFFFF {
        var h = [[vImagePixelCount]](repeating: [vImagePixelCount](repeating: 0, count: binCount), count: 4), b = _buffer
        _ = _withHistogramPointers(&h) { vImageHistogramCalculation_ARGBFFFF(&b, $0, UInt32(binCount), 0, 1, 0) }
        return (h[0], h[1], h[2], h[3])
    }
    public func specifyHistogram(_ histogram: HistogramFFFF, destination: vImage.PixelBuffer<Format>) {
        var h = [histogram.0, histogram.1, histogram.2, histogram.3]
        _call2(destination) { s, d in _withHistogramPointers(&h) { p in
            p.withMemoryRebound(to: UnsafePointer<vImagePixelCount>?.self, capacity: 4) {
                vImageHistogramSpecification_ARGBFFFF(s, d, nil, $0, UInt32(histogram.0.count), 0, 1, 0) } } }
    }
    public func equalizeHistogram(binCount: Int, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageEqualization_ARGBFFFF($0, $1, nil, UInt32(binCount), 0, 1, 0) }
    }
    public func contrastStretch(binCount: Int, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageContrastStretch_ARGBFFFF($0, $1, nil, UInt32(binCount), 0, 1, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx3 {
    public func histogram(binCount: Int) -> HistogramFFF {
        let a = array
        var h = [[vImagePixelCount]](repeating: [vImagePixelCount](repeating: 0, count: binCount), count: 3)
        for i in 0..<a.count { h[i % 3][min(binCount - 1, max(0, Int(a[i] * Float(binCount))))] += 1 }
        return (h[0], h[1], h[2])
    }
    public func specifyHistogram(_ histogram: HistogramFFF, destination: vImage.PixelBuffer<Format>) {
        let src = planarBuffers(), dst = destination.planarBuffers(), hs = [histogram.0, histogram.1, histogram.2]
        for c in 0..<3 { src[c]._call2(dst[c]) { vImageHistogramSpecification_PlanarF($0, $1, nil, hs[c], UInt32(hs[c].count), 0, 1, 0) } }
        destination.interleave(planarSourceBuffers: dst)
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func histogram(binCount: Int) -> [vImagePixelCount] {
        var h = [vImagePixelCount](repeating: 0, count: binCount), b = _buffer
        _ = vImageHistogramCalculation_PlanarF(&b, &h, UInt32(binCount), 0, 1, 0)
        return h
    }
    public func specifyHistogram(_ histogram: [vImagePixelCount], destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageHistogramSpecification_PlanarF($0, $1, nil, histogram, UInt32(histogram.count), 0, 1, 0) }
    }
    public func equalizeHistogram(binCount: Int, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageEqualization_PlanarF($0, $1, nil, UInt32(binCount), 0, 1, 0) }
    }
    public func contrastStretch(binCount: Int, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageContrastStretch_PlanarF($0, $1, nil, UInt32(binCount), 0, 1, 0) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func specifyHistogram(_ histogram: [vImagePixelCount], destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageHistogramSpecification_Planar8($0, $1, histogram, 0) }
    }
}

// MARK: interleaving

/// An interleaved format and the planar format of its channels.
public protocol _vImageInterleaved: SinglePlanePixelFormat {
    associatedtype _Planar: SinglePlanePixelFormat where _Planar.ComponentType == ComponentType
}
extension vImage.Interleaved8x2: _vImageInterleaved { public typealias _Planar = vImage.Planar8 }
extension vImage.Interleaved8x3: _vImageInterleaved { public typealias _Planar = vImage.Planar8 }
extension vImage.Interleaved8x4: _vImageInterleaved { public typealias _Planar = vImage.Planar8 }
extension vImage.InterleavedFx2: _vImageInterleaved { public typealias _Planar = vImage.PlanarF }
extension vImage.InterleavedFx3: _vImageInterleaved { public typealias _Planar = vImage.PlanarF }
extension vImage.InterleavedFx4: _vImageInterleaved { public typealias _Planar = vImage.PlanarF }
extension vImage.Interleaved16Ux2: _vImageInterleaved { public typealias _Planar = vImage.Planar16U }
extension vImage.Interleaved16Ux4: _vImageInterleaved { public typealias _Planar = vImage.Planar16U }
extension vImage.Interleaved16Fx2: _vImageInterleaved { public typealias _Planar = vImage.Planar16F }
extension vImage.Interleaved16Fx4: _vImageInterleaved { public typealias _Planar = vImage.Planar16F }

/// Copies components between an interleaved buffer and planar buffers.
func _interleave<T>(_ interleaved: vImage_Buffer, _ planes: [vImage_Buffer], _ type: T.Type, toPlanes: Bool) {
    let n = planes.count, w = Int(interleaved.width), h = Int(interleaved.height)
    precondition(planes.allSatisfy { Int($0.width) == w && Int($0.height) == h }, "vImage: the planar buffers differ in size")
    for y in 0..<h {
        let ir = interleaved.data.advanced(by: y * interleaved.rowBytes).assumingMemoryBound(to: T.self)
        for c in 0..<n {
            let pr = planes[c].data.advanced(by: y * planes[c].rowBytes).assumingMemoryBound(to: T.self)
            if toPlanes { for x in 0..<w { pr[x] = ir[x * n + c] } } else { for x in 0..<w { ir[x * n + c] = pr[x] } }
        }
    }
}

extension vImage.PixelBuffer where Format: _vImageInterleaved {
    /// An interleaved buffer of the planar buffers' values.
    public init(planarBuffers: [vImage.PixelBuffer<Format._Planar>]) {
        precondition(planarBuffers.count == Format.channelCount, "vImage.PixelBuffer: \(Format.channelCount) planar buffers needed")
        self.init(size: planarBuffers[0].size)
        interleave(planarSourceBuffers: planarBuffers)
    }
    /// New planar buffers, one per channel.
    public func planarBuffers() -> [vImage.PixelBuffer<Format._Planar>] {
        let out = (0..<Format.channelCount).map { _ in vImage.PixelBuffer<Format._Planar>(size: size) }
        deinterleave(planarDestinationBuffers: out)
        return out
    }
    public func interleave(planarSourceBuffers: [vImage.PixelBuffer<Format._Planar>]) {
        precondition(planarSourceBuffers.count == Format.channelCount, "vImage.PixelBuffer: \(Format.channelCount) planar buffers needed")
        _interleave(_buffer, planarSourceBuffers.map(\._buffer), Format.ComponentType.self, toPlanes: false)
    }
    public func deinterleave(planarDestinationBuffers: [vImage.PixelBuffer<Format._Planar>]) {
        precondition(planarDestinationBuffers.count == Format.channelCount, "vImage.PixelBuffer: \(Format.channelCount) planar buffers needed")
        _interleave(_buffer, planarDestinationBuffers.map(\._buffer), Format.ComponentType.self, toPlanes: true)
    }
    public func deinterleave<D: MultiplePlanePixelFormat>(destination: vImage.PixelBuffer<D>) where D.PlanarPixelFormat == Format._Planar {
        precondition(D.planeCount == Format.channelCount, "vImage.PixelBuffer.deinterleave: the channel counts differ")
        _interleave(_buffer, destination._buffers, Format.ComponentType.self, toPlanes: true)
    }
}
extension vImage.PixelBuffer where Format: MultiplePlanePixelFormat {
    /// A multiple-plane buffer of an interleaved buffer's channels.
    public init<I: _vImageInterleaved>(interleavedBuffer: vImage.PixelBuffer<I>) where I._Planar == Format.PlanarPixelFormat {
        precondition(I.channelCount == Format.planeCount, "vImage.PixelBuffer: the channel counts differ")
        self.init(size: interleavedBuffer.size)
        _interleave(interleavedBuffer._buffer, _buffers, I.ComponentType.self, toPlanes: true)
    }
    public func interleave<I: _vImageInterleaved>(destination: vImage.PixelBuffer<I>) where I._Planar == Format.PlanarPixelFormat {
        precondition(I.channelCount == Format.planeCount, "vImage.PixelBuffer.interleave: the channel counts differ")
        _interleave(destination._buffer, _buffers, I.ComponentType.self, toPlanes: false)
    }
    /// New planar buffers with copies of the planes.
    public func planarBuffers() -> [vImage.PixelBuffer<Format.PlanarPixelFormat>] {
        (0..<Format.planeCount).map { i in let p = vImage.PixelBuffer<Format.PlanarPixelFormat>(size: size); _plane(i).copy(to: p); return p }
    }
}

// MARK: conversions between component types (per component, through planar buffers width x channels wide)

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat, Format.ComponentType == Pixel_8 {
    func _to8F<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_Planar8toPlanarF($0, $1, 1, 0, 0) } }
    func _to816U<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_Planar8To16U($0, $1, 0) } }
    func _to816F<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_Planar8toPlanar16F($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format: SinglePlanePixelFormat, Format.ComponentType == Pixel_F {
    func _toF8<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_PlanarFtoPlanar8($0, $1, 1, 0, 0) } }
    func _toF16F<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_PlanarFtoPlanar16F($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format: SinglePlanePixelFormat, Format.ComponentType == Pixel_16F {
    func _to16FF<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_Planar16FtoPlanarF($0, $1, 0) } }
    func _to16F8<F: SinglePlanePixelFormat>(_ d: vImage.PixelBuffer<F>) { _callWide(d) { vImageConvert_Planar16FtoPlanar8($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux2 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x2>) { _callWide(destination) { vImageConvert_16UToPlanar8($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Ux4 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x4>) { _callWide(destination) { vImageConvert_16UToPlanar8($0, $1, 0) } }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x2 {
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx2>) { _to8F(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Ux2>) { _to816U(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Fx2>) { _to816F(destination) }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x3 {
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx3>) { _to8F(destination) }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Ux4>) { _to816U(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Fx4>) { _to816F(destination) }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx2 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x2>) { _toF8(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Fx2>) { _toF16F(destination) }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx3 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x3>) { _toF8(destination) }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved16Fx4>) { _toF16F(destination) }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx2 {
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx2>) { _to16FF(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x2>) { _to16F8(destination) }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved16Fx4 {
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx4>) { _to16FF(destination) }
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x4>) { _to16F8(destination) }
}

// MARK: Y'CbCr

extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    /// ARGB from a luma plane and a half-size interleaved chroma plane (4:2:0 bi-planar).
    public init(lumaSource: vImage.PixelBuffer<vImage.Planar8>, chromaSource: vImage.PixelBuffer<vImage.Interleaved8x2>,
                conversionInfo: vImage_YpCbCrToARGB) {
        self.init(size: lumaSource.size)
        convert(lumaSource: lumaSource, chromaSource: chromaSource, conversionInfo: conversionInfo)
    }
    public func convert(lumaSource: vImage.PixelBuffer<vImage.Planar8>, chromaSource: vImage.PixelBuffer<vImage.Interleaved8x2>,
                        conversionInfo: vImage_YpCbCrToARGB) {
        var info = conversionInfo
        lumaSource._call3(chromaSource, self) { vImageConvert_420Yp8_CbCr8ToARGB8888($0, $1, $2, &info, nil, 255, 0) }
    }
}
