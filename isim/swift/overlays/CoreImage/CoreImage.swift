// isim CoreImage Swift overlay: the CVPixelBuffer APIs. isim's CoreVideo is Swift-only, so CIImage(cvPixelBuffer:),
// CIContext.render(_:to:), CIRenderDestination(pixelBuffer:) and the processor kernels' pixelBuffer live here, on top
// of the Objective-C framework's bitmap APIs (adapted: pixels are copied, no IOSurface sharing).
// Formats: 32BGRA / 32ARGB / 32RGBA directly; OneComponent8 / 16 / 16Half / 32Float, depth and disparity as
// luminance (not color managed when float); 24RGB, 14-bit Bayer and 420YpCbCr8BiPlanar through BGRA.
@_exported import CoreImage
import Foundation
import CoreGraphics
import CoreVideo

extension CIImage {
    /// the CIFormat a pixel buffer's single plane maps to without conversion
    static func _isimDirectFormat(_ f: OSType) -> CIFormat? {
        switch f {
        case kCVPixelFormatType_32BGRA: return .BGRA8
        case kCVPixelFormatType_32ARGB: return .ARGB8
        case kCVPixelFormatType_32RGBA: return .RGBA8
        case kCVPixelFormatType_OneComponent8: return .L8
        case kCVPixelFormatType_OneComponent16: return .L16
        case kCVPixelFormatType_OneComponent16Half, kCVPixelFormatType_DepthFloat16, kCVPixelFormatType_DisparityFloat16: return .Lh
        case kCVPixelFormatType_OneComponent32Float, kCVPixelFormatType_DepthFloat32, kCVPixelFormatType_DisparityFloat32: return .Lf
        default: return nil
        }
    }
    static func _isimIsFloat(_ f: CIFormat) -> Bool { f == .Lh || f == .Lf }
    /// isim's Core Graphics objects answer _isimCFTypeID with their CG...GetTypeID value
    static func _isimIsColorSpace(_ o: AnyObject) -> Bool {
        let sel = NSSelectorFromString("_isimCFTypeID")
        guard o.responds(to: sel) else { return false }
        let r: Unmanaged<AnyObject>? = o.perform(sel)
        return r.map { UInt(bitPattern: $0.toOpaque()) } == UInt(CGColorSpaceGetTypeID())
    }

    public convenience init(cvPixelBuffer pixelBuffer: CVPixelBuffer) { self.init(cvPixelBuffer: pixelBuffer, options: nil) }
    public convenience init(cvPixelBuffer pixelBuffer: CVPixelBuffer, options: [CIImageOption: Any]?) {
        let w = CVPixelBufferGetWidth(pixelBuffer), h = CVPixelBufferGetHeight(pixelBuffer), f = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let data: Data, bpr: Int, format: CIFormat
        if let direct = CIImage._isimDirectFormat(f), let base = CVPixelBufferGetBaseAddress(pixelBuffer) {
            bpr = CVPixelBufferGetBytesPerRow(pixelBuffer)
            data = Data(bytes: base, count: bpr * h)
            format = direct
        } else {
            data = Data(pixelBuffer._bgra())
            bpr = w * 4; format = .BGRA8
        }
        var space: CGColorSpace? = CIImage._isimIsFloat(format) ? nil : CGColorSpace(name: CGColorSpace.sRGB)
        if let o = options?[.colorSpace] {
            if o is NSNull { space = nil } else if CIImage._isimIsColorSpace(o as AnyObject) { space = unsafeBitCast(o as AnyObject, to: CGColorSpace.self) }
        }
        self.init(bitmapData: data, bytesPerRow: bpr, size: CGSize(width: w, height: h), format: format, colorSpace: space)
        self.setValue(pixelBuffer, forKey: "isimPixelBuffer")
    }
    public convenience init(cvImageBuffer imageBuffer: CVImageBuffer) { self.init(cvPixelBuffer: imageBuffer, options: nil) }
    public convenience init(cvImageBuffer imageBuffer: CVImageBuffer, options: [CIImageOption: Any]?) { self.init(cvPixelBuffer: imageBuffer, options: options) }
    /// the pixel buffer this image was made from (nil for other images)
    public var pixelBuffer: CVPixelBuffer? { value(forKey: "isimPixelBuffer") as? CVPixelBuffer }
}

/// a bitmap the Objective-C renderer can write, and how to move it into the pixel buffer afterwards
private struct _ISIMTarget {
    let base: UnsafeMutableRawPointer
    let bytesPerRow: Int
    let format: CIFormat
    let finish: (() -> Void)?
    init(_ buffer: CVPixelBuffer) {
        let w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer), f = CVPixelBufferGetPixelFormatType(buffer)
        if let direct = CIImage._isimDirectFormat(f), let b = CVPixelBufferGetBaseAddress(buffer) {
            base = b; bytesPerRow = CVPixelBufferGetBytesPerRow(buffer); format = direct; finish = nil
            return
        }
        let tmp = _ISIMScratch(w * h * 4)
        base = tmp.p; bytesPerRow = w * 4; format = .BGRA8
        finish = { _isimStoreBGRA(tmp.p, into: buffer) }    // keeps the scratch bitmap alive as long as the target
    }
}
private final class _ISIMScratch {
    let p: UnsafeMutableRawPointer
    init(_ n: Int) { p = UnsafeMutableRawPointer.allocate(byteCount: n, alignment: 16); p.initializeMemory(as: UInt8.self, repeating: 0, count: n) }
    deinit { p.deallocate() }
}
/// BGRA (premultiplied, packed rows) into a 24RGB, Bayer or 4:2:0 bi-planar (BT.601) buffer
private func _isimStoreBGRA(_ src: UnsafeMutableRawPointer, into b: CVPixelBuffer) {
    let w = CVPixelBufferGetWidth(b), h = CVPixelBufferGetHeight(b), f = CVPixelBufferGetPixelFormatType(b)
    let s = src.assumingMemoryBound(to: UInt8.self)
    func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double) { let p = s + (y * w + x) * 4; return (Double(p[2]), Double(p[1]), Double(p[0])) }
    func clamp(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v.rounded()))) }
    if f == kCVPixelFormatType_24RGB, let d = CVPixelBufferGetBaseAddress(b)?.assumingMemoryBound(to: UInt8.self) {
        let bpr = CVPixelBufferGetBytesPerRow(b)
        for y in 0..<h { for x in 0..<w { let (r, g, bl) = rgb(x, y); d[y * bpr + 3 * x] = clamp(r); d[y * bpr + 3 * x + 1] = clamp(g); d[y * bpr + 3 * x + 2] = clamp(bl) } }
    } else if f == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
              let yp = CVPixelBufferGetBaseAddressOfPlane(b, 0)?.assumingMemoryBound(to: UInt8.self),
              let cp = CVPixelBufferGetBaseAddressOfPlane(b, 1)?.assumingMemoryBound(to: UInt8.self) {
        let full = f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        let ybpr = CVPixelBufferGetBytesPerRowOfPlane(b, 0), cbpr = CVPixelBufferGetBytesPerRowOfPlane(b, 1)
        for y in 0..<h {
            for x in 0..<w {
                let (r, g, bl) = rgb(x, y), yy = 0.299 * r + 0.587 * g + 0.114 * bl
                yp[y * ybpr + x] = clamp(full ? yy : 16 + yy * 219 / 255)
            }
        }
        for cy in 0..<(h + 1) / 2 {
            for cx in 0..<(w + 1) / 2 {
                var r = 0.0, g = 0.0, bl = 0.0, n = 0.0
                for dy in 0..<2 { for dx in 0..<2 where cx * 2 + dx < w && cy * 2 + dy < h { let c = rgb(cx * 2 + dx, cy * 2 + dy); r += c.0; g += c.1; bl += c.2; n += 1 } }
                r /= n; g /= n; bl /= n
                let k = full ? 1.0 : 224.0 / 255
                cp[cy * cbpr + 2 * cx] = clamp(128 + (-0.168736 * r - 0.331264 * g + 0.5 * bl) * k)
                cp[cy * cbpr + 2 * cx + 1] = clamp(128 + (0.5 * r - 0.418688 * g - 0.081312 * bl) * k)
            }
        }
    } else if let d = CVPixelBufferGetBaseAddress(b) {      // 14-bit Bayer: the mosaic's color of each site
        let bpr = CVPixelBufferGetBytesPerRow(b)
        let pattern: [Int] = f == kCVPixelFormatType_14Bayer_RGGB ? [0, 1, 1, 2] : f == kCVPixelFormatType_14Bayer_GRBG ? [1, 0, 2, 1]
                           : f == kCVPixelFormatType_14Bayer_GBRG ? [1, 2, 0, 1] : [2, 1, 1, 0]
        for y in 0..<h {
            let row = (d + y * bpr).assumingMemoryBound(to: UInt16.self)
            for x in 0..<w { let c = rgb(x, y); let v = [c.0, c.1, c.2][pattern[(y % 2) * 2 + x % 2]]; row[x] = UInt16(max(0, min(16383, (v / 255 * 16383).rounded()))) }
        }
    }
}

extension CIContext {
    public func render(_ image: CIImage, to buffer: CVPixelBuffer) {
        render(image, to: buffer, bounds: CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(buffer), height: CVPixelBufferGetHeight(buffer)), colorSpace: nil)
    }
    public func render(_ image: CIImage, to buffer: CVPixelBuffer, bounds: CGRect, colorSpace: CGColorSpace?) {
        let t = _ISIMTarget(buffer)
        let space = colorSpace ?? (CIImage._isimIsFloat(t.format) ? nil : CGColorSpace(name: CGColorSpace.sRGB))   // float (depth) buffers: not color matched
        withExtendedLifetime(t) {
            render(image, toBitmap: t.base, rowBytes: t.bytesPerRow, bounds: bounds, format: t.format, colorSpace: space)
            t.finish?()
        }
    }
}

extension CIRenderDestination {
    /// a destination that renders into the pixel buffer (formats that need conversion are written when a task finishes)
    public convenience init(pixelBuffer: CVPixelBuffer) {
        let t = _ISIMTarget(pixelBuffer)
        self.init(bitmapData: t.base, width: CVPixelBufferGetWidth(pixelBuffer), height: CVPixelBufferGetHeight(pixelBuffer),
                  bytesPerRow: t.bytesPerRow, format: t.format)
        if let finish = t.finish {
            let block: @convention(block) () -> Void = { finish() }
            setValue(block, forKey: "isimWriteBack")
        }
    }
}

extension CIImageProcessorInput {
    /// nil on isim: processor inputs are main-memory bitmaps (baseAddress), not pixel buffers
    public var pixelBuffer: CVPixelBuffer? { nil }
}
extension CIImageProcessorOutput {
    /// nil on isim: the output is a main-memory bitmap (baseAddress), not a pixel buffer
    public var pixelBuffer: CVPixelBuffer? { nil }
}
