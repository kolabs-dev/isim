// isim CoreVideo (subset, self-authored with iOS API names): CVPixelBuffer (CVImageBuffer, CVBuffer) in main memory,
// pixel buffer pools and the C accessor functions apps use with AVFoundation capture, AVAssetReader/Writer and Vision.
// Adapted: buffers are plain memory (no IOSurface, no Metal/OpenGL texture caches); locking only counts.
// Formats: 32BGRA, 32ARGB, 32RGBA, 24RGB, OneComponent8 (single plane) and 420YpCbCr8BiPlanar video/full range.
@_exported import Foundation
@_exported import CoreGraphics

public typealias OSType = UInt32
public typealias CVReturn = Int32
public typealias CVOptionFlags = UInt64
public let kCVReturnSuccess: CVReturn = 0
public let kCVReturnFirst: CVReturn = -6660
public let kCVReturnError: CVReturn = -6660
public let kCVReturnInvalidArgument: CVReturn = -6661
public let kCVReturnAllocationFailed: CVReturn = -6662
public let kCVReturnUnsupported: CVReturn = -6663
public let kCVReturnInvalidPixelFormat: CVReturn = -6680
public let kCVReturnInvalidSize: CVReturn = -6681
public let kCVReturnPixelBufferNotCompatible: CVReturn = -6683
public let kCVReturnPoolAllocationFailed: CVReturn = -6690

public let kCVPixelFormatType_32BGRA: OSType = 0x4247_5241                    // 'BGRA'
public let kCVPixelFormatType_32ARGB: OSType = 0x0000_0020
public let kCVPixelFormatType_32RGBA: OSType = 0x5247_4241                    // 'RGBA'
public let kCVPixelFormatType_24RGB: OSType = 0x0000_0018
public let kCVPixelFormatType_OneComponent8: OSType = 0x4C30_3038             // 'L008'
public let kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: OSType = 0x3432_3076   // '420v'
public let kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: OSType = 0x3432_3066    // '420f'

public let kCVPixelBufferPixelFormatTypeKey: CFString = "PixelFormatType" as CFString
public let kCVPixelBufferWidthKey: CFString = "Width" as CFString
public let kCVPixelBufferHeightKey: CFString = "Height" as CFString
public let kCVPixelBufferBytesPerRowAlignmentKey: CFString = "BytesPerRowAlignment" as CFString
public let kCVPixelBufferCGImageCompatibilityKey: CFString = "CGImageCompatibility" as CFString
public let kCVPixelBufferCGBitmapContextCompatibilityKey: CFString = "CGBitmapContextCompatibility" as CFString
public let kCVPixelBufferIOSurfacePropertiesKey: CFString = "IOSurfaceProperties" as CFString
public let kCVPixelBufferMetalCompatibilityKey: CFString = "MetalCompatibility" as CFString
public let kCVPixelBufferPoolMinimumBufferCountKey: CFString = "MinimumBufferCount" as CFString

public struct CVPixelBufferLockFlags: OptionSet, Sendable {
    public let rawValue: CVOptionFlags
    public init(rawValue: CVOptionFlags) { self.rawValue = rawValue }
    public static let readOnly = CVPixelBufferLockFlags(rawValue: 1)
}

/// A pixel buffer in main memory (CVBuffer / CVImageBuffer / CVPixelBuffer are the same class on isim).
public final class CVBuffer: @unchecked Sendable, Hashable {
    public static func == (a: CVBuffer, b: CVBuffer) -> Bool { a === b }
    public func hash(into h: inout Hasher) { h.combine(ObjectIdentifier(self)) }
    public let _width: Int, _height: Int, _format: OSType
    struct Plane { let base: UnsafeMutableRawPointer; let width: Int; let height: Int; let bytesPerRow: Int }
    let _planes: [Plane]
    let _owned: UnsafeMutableRawPointer?
    let _release: (() -> Void)?
    var _locks = 0
    public var _attachments: [String: Any] = [:]

    static func bytesPerPixel(_ f: OSType) -> Int? {
        switch f {
        case kCVPixelFormatType_32BGRA, kCVPixelFormatType_32ARGB, kCVPixelFormatType_32RGBA: return 4
        case kCVPixelFormatType_24RGB: return 3
        case kCVPixelFormatType_OneComponent8: return 1
        default: return nil
        }
    }
    static func isBiPlanar(_ f: OSType) -> Bool { f == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange }

    /// Allocates zeroed storage; nil for unsupported formats or sizes.
    public init?(_width w: Int, height h: Int, format f: OSType) {
        guard w > 0, h > 0 else { return nil }
        _width = w; _height = h; _format = f; _release = nil
        if let bpp = CVBuffer.bytesPerPixel(f) {
            let bpr = (w * bpp + 15) & ~15
            let p = UnsafeMutableRawPointer.allocate(byteCount: bpr * h, alignment: 16)
            p.initializeMemory(as: UInt8.self, repeating: 0, count: bpr * h)
            _owned = p; _planes = [Plane(base: p, width: w, height: h, bytesPerRow: bpr)]
        } else if CVBuffer.isBiPlanar(f) {
            let yb = (w + 15) & ~15, cw = (w + 1) / 2, ch = (h + 1) / 2, cb = (cw * 2 + 15) & ~15
            let total = yb * h + cb * ch
            let p = UnsafeMutableRawPointer.allocate(byteCount: total, alignment: 16)
            p.initializeMemory(as: UInt8.self, repeating: 0, count: yb * h)
            (p + yb * h).initializeMemory(as: UInt8.self, repeating: 128, count: cb * ch)
            _owned = p
            _planes = [Plane(base: p, width: w, height: h, bytesPerRow: yb), Plane(base: p + yb * h, width: cw, height: ch, bytesPerRow: cb)]
        } else { return nil }
    }
    init(_wrapping base: UnsafeMutableRawPointer, width: Int, height: Int, format: OSType, bytesPerRow: Int, release: (() -> Void)?) {
        _width = width; _height = height; _format = format; _owned = nil; _release = release
        _planes = [Plane(base: base, width: width, height: height, bytesPerRow: bytesPerRow)]
    }
    deinit { _owned?.deallocate(); _release?() }

    /// isim: copies tightly packed BGRA pixels (w*4 bytes per row) into this 32BGRA buffer.
    public func _setBGRA(_ src: UnsafeRawPointer) {
        guard _format == kCVPixelFormatType_32BGRA, let p = _planes.first else { return }
        for y in 0..<_height { (p.base + y * p.bytesPerRow).copyMemory(from: src + y * _width * 4, byteCount: _width * 4) }
    }
    /// isim: the pixels as tightly packed premultiplied BGRA (converting from the buffer's format).
    public func _bgra() -> [UInt8] {
        var out = [UInt8](repeating: 255, count: _width * _height * 4)
        let p0 = _planes[0]
        out.withUnsafeMutableBufferPointer { o in
            for y in 0..<_height {
                let row = p0.base.assumingMemoryBound(to: UInt8.self) + y * p0.bytesPerRow
                for x in 0..<_width {
                    let d = (y * _width + x) * 4
                    switch _format {
                    case kCVPixelFormatType_32BGRA: o[d] = row[4 * x]; o[d + 1] = row[4 * x + 1]; o[d + 2] = row[4 * x + 2]; o[d + 3] = row[4 * x + 3]
                    case kCVPixelFormatType_32ARGB: o[d] = row[4 * x + 3]; o[d + 1] = row[4 * x + 2]; o[d + 2] = row[4 * x + 1]; o[d + 3] = row[4 * x]
                    case kCVPixelFormatType_32RGBA: o[d] = row[4 * x + 2]; o[d + 1] = row[4 * x + 1]; o[d + 2] = row[4 * x]; o[d + 3] = row[4 * x + 3]
                    case kCVPixelFormatType_24RGB: o[d] = row[3 * x + 2]; o[d + 1] = row[3 * x + 1]; o[d + 2] = row[3 * x]
                    case kCVPixelFormatType_OneComponent8: o[d] = row[x]; o[d + 1] = row[x]; o[d + 2] = row[x]
                    default:   // bi-planar 4:2:0 (BT.601)
                        let full = _format == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                        let c = _planes[1].base.assumingMemoryBound(to: UInt8.self) + (y / 2) * _planes[1].bytesPerRow + (x / 2) * 2
                        var yy = Double(row[x]); if !full { yy = (yy - 16) * 255 / 219 }
                        let cb = Double(c[0]) - 128, cr = Double(c[1]) - 128
                        func clamp(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v.rounded()))) }
                        o[d + 2] = clamp(yy + 1.402 * cr); o[d + 1] = clamp(yy - 0.344136 * cb - 0.714136 * cr); o[d] = clamp(yy + 1.772 * cb)
                    }
                }
            }
        }
        return out
    }
}
public typealias CVImageBuffer = CVBuffer
public typealias CVPixelBuffer = CVBuffer

public func CVPixelBufferCreate(_ allocator: CFAllocator?, _ width: Int, _ height: Int, _ pixelFormatType: OSType,
                                _ pixelBufferAttributes: CFDictionary?, _ pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    guard width > 0, height > 0 else { return kCVReturnInvalidSize }
    guard let b = CVBuffer(_width: width, height: height, format: pixelFormatType) else { return kCVReturnInvalidPixelFormat }
    pixelBufferOut.pointee = b
    return kCVReturnSuccess
}
public typealias CVPixelBufferReleaseBytesCallback = @convention(c) (UnsafeMutableRawPointer?, UnsafeRawPointer?) -> Void
public func CVPixelBufferCreateWithBytes(_ allocator: CFAllocator?, _ width: Int, _ height: Int, _ pixelFormatType: OSType,
                                         _ baseAddress: UnsafeMutableRawPointer, _ bytesPerRow: Int,
                                         _ releaseCallback: CVPixelBufferReleaseBytesCallback?, _ releaseRefCon: UnsafeMutableRawPointer?,
                                         _ pixelBufferAttributes: CFDictionary?, _ pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    guard width > 0, height > 0 else { return kCVReturnInvalidSize }
    guard CVBuffer.bytesPerPixel(pixelFormatType) != nil else { return kCVReturnInvalidPixelFormat }
    let base = UnsafeRawPointer(baseAddress)
    pixelBufferOut.pointee = CVBuffer(_wrapping: baseAddress, width: width, height: height, format: pixelFormatType, bytesPerRow: bytesPerRow,
                                      release: releaseCallback.map { cb in { cb(releaseRefCon, base) } })
    return kCVReturnSuccess
}
public func CVPixelBufferLockBaseAddress(_ pixelBuffer: CVPixelBuffer, _ lockFlags: CVPixelBufferLockFlags) -> CVReturn { pixelBuffer._locks += 1; return kCVReturnSuccess }
public func CVPixelBufferUnlockBaseAddress(_ pixelBuffer: CVPixelBuffer, _ unlockFlags: CVPixelBufferLockFlags) -> CVReturn {
    guard pixelBuffer._locks > 0 else { return kCVReturnError }
    pixelBuffer._locks -= 1; return kCVReturnSuccess
}
public func CVPixelBufferGetWidth(_ b: CVPixelBuffer) -> Int { b._width }
public func CVPixelBufferGetHeight(_ b: CVPixelBuffer) -> Int { b._height }
public func CVPixelBufferGetPixelFormatType(_ b: CVPixelBuffer) -> OSType { b._format }
public func CVPixelBufferGetBaseAddress(_ b: CVPixelBuffer) -> UnsafeMutableRawPointer? { b._planes.count == 1 ? b._planes[0].base : nil }
public func CVPixelBufferGetBytesPerRow(_ b: CVPixelBuffer) -> Int { b._planes.count == 1 ? b._planes[0].bytesPerRow : 0 }
public func CVPixelBufferGetDataSize(_ b: CVPixelBuffer) -> Int { b._planes.reduce(0) { $0 + $1.bytesPerRow * $1.height } }
public func CVPixelBufferIsPlanar(_ b: CVPixelBuffer) -> Bool { b._planes.count > 1 }
public func CVPixelBufferGetPlaneCount(_ b: CVPixelBuffer) -> Int { b._planes.count > 1 ? b._planes.count : 0 }
public func CVPixelBufferGetWidthOfPlane(_ b: CVPixelBuffer, _ i: Int) -> Int { i < b._planes.count ? b._planes[i].width : 0 }
public func CVPixelBufferGetHeightOfPlane(_ b: CVPixelBuffer, _ i: Int) -> Int { i < b._planes.count ? b._planes[i].height : 0 }
public func CVPixelBufferGetBaseAddressOfPlane(_ b: CVPixelBuffer, _ i: Int) -> UnsafeMutableRawPointer? { i < b._planes.count ? b._planes[i].base : nil }
public func CVPixelBufferGetBytesPerRowOfPlane(_ b: CVPixelBuffer, _ i: Int) -> Int { i < b._planes.count ? b._planes[i].bytesPerRow : 0 }
public func CVPixelBufferGetTypeID() -> UInt { 0x4356_5042 }
public func CVImageBufferGetEncodedSize(_ b: CVImageBuffer) -> CGSize { CGSize(width: b._width, height: b._height) }
public func CVImageBufferGetDisplaySize(_ b: CVImageBuffer) -> CGSize { CGSize(width: b._width, height: b._height) }
public func CVImageBufferGetCleanRect(_ b: CVImageBuffer) -> CGRect { CGRect(x: 0, y: 0, width: b._width, height: b._height) }
public func CVBufferRetain(_ b: CVBuffer?) -> CVBuffer? { b }
public func CVBufferRelease(_ b: CVBuffer?) {}

// MARK: - pools

public final class CVPixelBufferPool: @unchecked Sendable {
    let width: Int, height: Int, format: OSType
    let attributes: [String: Any]
    init(width: Int, height: Int, format: OSType, attributes: [String: Any]) { self.width = width; self.height = height; self.format = format; self.attributes = attributes }
}
func _cvInt(_ d: [String: Any], _ k: CFString) -> Int? {
    let v = d[k as String]
    if let i = v as? Int { return i }
    if let n = v as? NSNumber { return n.integerValue }
    if let u = v as? UInt32 { return Int(u) }
    return nil
}
public func CVPixelBufferPoolCreate(_ allocator: CFAllocator?, _ poolAttributes: CFDictionary?, _ pixelBufferAttributes: CFDictionary?,
                                    _ poolOut: UnsafeMutablePointer<CVPixelBufferPool?>) -> CVReturn {
    let a = (pixelBufferAttributes as NSDictionary? as? [String: Any]) ?? [:]
    guard let w = _cvInt(a, kCVPixelBufferWidthKey), let h = _cvInt(a, kCVPixelBufferHeightKey) else { return kCVReturnInvalidArgument }
    let f = _cvInt(a, kCVPixelBufferPixelFormatTypeKey).map { OSType(truncatingIfNeeded: $0) } ?? kCVPixelFormatType_32BGRA
    poolOut.pointee = CVPixelBufferPool(width: w, height: h, format: f, attributes: a)
    return kCVReturnSuccess
}
/// isim: a pool for buffers of this size and format (AVAssetWriterInputPixelBufferAdaptor).
public func _CVPixelBufferPoolMake(width: Int, height: Int, format: OSType) -> CVPixelBufferPool {
    CVPixelBufferPool(width: width, height: height, format: format, attributes: [kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
                                                                                  kCVPixelBufferPixelFormatTypeKey as String: Int(format)])
}
public func CVPixelBufferPoolCreatePixelBuffer(_ allocator: CFAllocator?, _ pool: CVPixelBufferPool, _ out: UnsafeMutablePointer<CVPixelBuffer?>) -> CVReturn {
    guard let b = CVBuffer(_width: pool.width, height: pool.height, format: pool.format) else { return kCVReturnPoolAllocationFailed }
    out.pointee = b
    return kCVReturnSuccess
}
public func CVPixelBufferPoolGetPixelBufferAttributes(_ pool: CVPixelBufferPool) -> CFDictionary? { pool.attributes as NSDictionary as CFDictionary }
