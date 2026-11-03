// isim Accelerate Swift overlay: vImage's Swift API (issue #371) over isim's C vImage (frameworks/Accelerate/vimage*.c):
// the vImage namespace (errors, options, sizes, edge modes, rotations), the vImage_Buffer / vImage_CGImageFormat /
// vImageConverter extensions, and vImage.PixelBuffer for the single-plane pixel formats with its core operations.
// Adapted.
@_exported import Accelerate
import CoreGraphics

public enum vImage {
    /// vImage's error codes.
    public enum Error: Int, Swift.Error {
        case noError = 0
        case roiLargerThanInputBuffer = -21766
        case invalidKernelSize = -21767
        case invalidEdgeStyle = -21768
        case invalidOffset_X = -21769
        case invalidOffset_Y = -21770
        case memoryAllocationError = -21771
        case nullPointerArgument = -21772
        case invalidParameter = -21773
        case bufferSizeMismatch = -21774
        case unknownFlagsBit = -21775
        case internalError = -21776
        case invalidRowBytes = -21777
        case invalidImageFormat = -21778
        case colorSyncIsAbsent = -21779
        case outOfPlaceOperationRequired = -21780
        case invalidImageObject = -21781
        case invalidCVImageFormat = -21782
        case unsupportedConversion = -21783
        case coreVideoIsAbsent = -21784
        public init(vImageError: vImage_Error) { self = Error(rawValue: vImageError) ?? .internalError }
    }

    /// The flags vImage's functions take.
    public struct Options: OptionSet, Sendable {
        public let rawValue: vImage_Flags
        public init(rawValue: vImage_Flags) { self.rawValue = rawValue }
        public static let noFlags = Options([])
        public static let leaveAlphaUnchanged = Options(rawValue: vImage_Flags(kvImageLeaveAlphaUnchanged))
        public static let copyInPlace = Options(rawValue: vImage_Flags(kvImageCopyInPlace))
        public static let backgroundColorFill = Options(rawValue: vImage_Flags(kvImageBackgroundColorFill))
        public static let imageExtend = Options(rawValue: vImage_Flags(kvImageEdgeExtend))
        public static let doNotTile = Options(rawValue: vImage_Flags(kvImageDoNotTile))
        public static let highQualityResampling = Options(rawValue: vImage_Flags(kvImageHighQualityResampling))
        public static let truncateKernel = Options(rawValue: vImage_Flags(kvImageTruncateKernel))
        public static let getTempBufferSize = Options(rawValue: vImage_Flags(kvImageGetTempBufferSize))
        public static let printDiagnosticsToConsole = Options(rawValue: vImage_Flags(kvImagePrintDiagnosticsToConsole))
        public static let noAllocate = Options(rawValue: vImage_Flags(kvImageNoAllocate))
        public static let hdrContent = Options(rawValue: vImage_Flags(kvImageHDRContent))
        public static let doNotClamp = Options(rawValue: vImage_Flags(kvImageDoNotClamp))
        public var flags: vImage_Flags { rawValue }
    }

    /// A size in pixels.
    public struct Size: Hashable, Sendable {
        public let width: Int
        public let height: Int
        public init(width: Int, height: Int) { self.width = width; self.height = height }
        public init(width: vImagePixelCount, height: vImagePixelCount) { self.init(width: Int(width), height: Int(height)) }
        public init?(exactly size: CGSize) {
            guard let w = Int(exactly: size.width), let h = Int(exactly: size.height) else { return nil }
            self.init(width: w, height: h)
        }
        public init?<T: BinaryInteger>(exactWidth width: T, height: T) {
            guard let w = Int(exactly: width), let h = Int(exactly: height) else { return nil }
            self.init(width: w, height: h)
        }
    }

    /// How a filter treats the pixels beyond the edges.
    public enum EdgeMode<PixelType> {
        case copyInPlace
        case extend
        case fill(backgroundColor: PixelType)
        case truncateKernel
        var _flags: vImage_Flags {
            switch self {
            case .copyInPlace: return vImage_Flags(kvImageCopyInPlace)
            case .extend: return vImage_Flags(kvImageEdgeExtend)
            case .fill: return vImage_Flags(kvImageBackgroundColorFill)
            case .truncateKernel: return vImage_Flags(kvImageTruncateKernel)
            }
        }
        var _background: PixelType? { if case .fill(let c) = self { return c }; return nil }
    }

    /// A rotation: quarter turns, or any angle.
    public enum Rotation {
        case clockwise0Degrees, clockwise90Degrees, clockwise180Degrees, clockwise270Degrees
        case counterClockwise0Degrees, counterClockwise90Degrees, counterClockwise180Degrees, counterClockwise270Degrees
        case angleInDegrees(Float)
        case angleInRadians(Float)
        /// quarter turns counterclockwise, or nil for an arbitrary angle
        var _quarterTurns: UInt8? {
            switch self {
            case .clockwise0Degrees, .counterClockwise0Degrees: return 0
            case .counterClockwise90Degrees, .clockwise270Degrees: return 1
            case .clockwise180Degrees, .counterClockwise180Degrees: return 2
            case .clockwise90Degrees, .counterClockwise270Degrees: return 3
            case .angleInDegrees, .angleInRadians: return nil
            }
        }
        var _radians: Float {
            switch self {
            case .angleInDegrees(let d): return d * .pi / 180
            case .angleInRadians(let r): return r
            default: return Float(_quarterTurns ?? 0) * .pi / 2
            }
        }
    }

    /// The axis a reflection flips over.
    public enum ReflectionAxis { case horizontal, vertical }

    /// What a converter's buffers hold.
    public enum BufferType: Int {
        case coreGraphics, chunky, indexed, alpha, monochrome, rgbRed, rgbGreen, rgbBlue, cmykCyan, cmykMagenta, cmykYellow, cmykBlack
        case labL, labA, labB, xyzX, xyzY, xyzZ, luminance, chroma, Cb, Cr, YCbCr
        public init?(bufferTypeCode: Int, model: CGColorSpaceModel?) {
            switch bufferTypeCode {
            case Int(kvImageBufferTypeCode_CGFormat): self = .coreGraphics
            case Int(kvImageBufferTypeCode_Chunky): self = .chunky
            case Int(kvImageBufferTypeCode_Indexed): self = .indexed
            case Int(kvImageBufferTypeCode_Alpha): self = .alpha
            case Int(kvImageBufferTypeCode_Luminance): self = .luminance
            case Int(kvImageBufferTypeCode_Chroma): self = .chroma
            case Int(kvImageBufferTypeCode_Cb): self = .Cb
            case Int(kvImageBufferTypeCode_Cr): self = .Cr
            case 1...4:
                let i = bufferTypeCode - 1
                switch model?.rawValue {   // monochrome 0, CMYK 2, Lab 3, XYZ 7 (CGColorSpaceModel's values)
                case 0?: if i == 0 { self = .monochrome } else { return nil }
                case 2?: self = [.cmykCyan, .cmykMagenta, .cmykYellow, .cmykBlack][i]
                case 3?: if i < 3 { self = [.labL, .labA, .labB][i] } else { return nil }
                case 7?: if i < 3 { self = [.xyzX, .xyzY, .xyzZ][i] } else { return nil }
                default: if i < 3 { self = [.rgbRed, .rgbGreen, .rgbBlue][i] } else { return nil }
                }
            default: return nil
            }
        }
        public var bufferTypeCode: vImageBufferTypeCode {
            switch self {
            case .coreGraphics: return vImageBufferTypeCode(kvImageBufferTypeCode_CGFormat)
            case .chunky: return vImageBufferTypeCode(kvImageBufferTypeCode_Chunky)
            case .indexed: return vImageBufferTypeCode(kvImageBufferTypeCode_Indexed)
            case .alpha: return vImageBufferTypeCode(kvImageBufferTypeCode_Alpha)
            case .monochrome, .rgbRed, .cmykCyan, .labL, .xyzX: return 1
            case .rgbGreen, .cmykMagenta, .labA, .xyzY: return 2
            case .rgbBlue, .cmykYellow, .labB, .xyzZ: return 3
            case .cmykBlack: return 4
            case .luminance, .YCbCr: return vImageBufferTypeCode(kvImageBufferTypeCode_Luminance)
            case .chroma: return vImageBufferTypeCode(kvImageBufferTypeCode_Chroma)
            case .Cb: return vImageBufferTypeCode(kvImageBufferTypeCode_Cb)
            case .Cr: return vImageBufferTypeCode(kvImageBufferTypeCode_Cr)
            }
        }
    }
}

@inline(__always) func _vImageCheck(_ e: vImage_Error) throws {
    if e < 0 { throw vImage.Error(vImageError: e) }
}

// MARK: - vImage_Buffer

extension vImage_Buffer {
    public init(width: Int, height: Int, bitsPerPixel: UInt32) throws {
        self.init()
        try _vImageCheck(vImageBuffer_Init(&self, vImagePixelCount(height), vImagePixelCount(width), bitsPerPixel, vImage_Flags(kvImageNoFlags)))
    }
    public init(size: CGSize, bitsPerPixel: UInt32) throws {
        try self.init(width: Int(size.width), height: Int(size.height), bitsPerPixel: bitsPerPixel)
    }
    /// A buffer in the image's own format.
    public init(cgImage: CGImage, flags: vImage.Options = .noFlags) throws {
        self.init()
        var format = vImage_CGImageFormat()
        try _vImageCheck(vImageBuffer_InitWithCGImage(&self, &format, nil, cgImage, flags.flags))
    }
    public init(cgImage: CGImage, format: vImage_CGImageFormat, flags: vImage.Options = .noFlags) throws {
        self.init()
        var format = format
        try _vImageCheck(vImageBuffer_InitWithCGImage(&self, &format, nil, cgImage, flags.flags))
    }
    public var size: CGSize { CGSize(width: CGFloat(width), height: CGFloat(height)) }
    /// Frees the pixels of a buffer vImage allocated.
    public func free() { Darwin.free(data) }
    public func createCGImage(format: vImage_CGImageFormat, flags: vImage.Options = .noFlags) throws -> CGImage {
        var buffer = self, format = format, error = vImage_Error(kvImageNoError)
        guard let image = vImageCreateCGImageFromBuffer(&buffer, &format, nil, nil, flags.flags, &error) else {
            throw vImage.Error(vImageError: error == 0 ? vImage_Error(kvImageInternalError) : error)
        }
        return image.takeRetainedValue()
    }
    public func copy(destinationBuffer: inout vImage_Buffer, pixelSize: Int, flags: vImage.Options = .noFlags) throws {
        var source = self
        try _vImageCheck(vImageCopyBuffer(&source, &destinationBuffer, pixelSize, flags.flags))
    }
    public static func preferredAlignmentAndRowBytes(width: Int, height: Int, bitsPerPixel: UInt32) throws -> (alignment: Int, rowBytes: Int) {
        var b = vImage_Buffer()
        let r = vImageBuffer_Init(&b, vImagePixelCount(height), vImagePixelCount(width), bitsPerPixel, vImage_Flags(kvImageNoAllocate))
        try _vImageCheck(r)
        return (r, b.rowBytes)
    }
}

// MARK: - vImage_CGImageFormat

extension vImage_CGImageFormat {
    public init?(cgImage: CGImage) {
        guard let cs = cgImage.colorSpace else { return nil }
        self.init(bitsPerComponent: UInt32(cgImage.bitsPerComponent), bitsPerPixel: UInt32(cgImage.bitsPerPixel),
                  colorSpace: Unmanaged.passRetained(cs), bitmapInfo: cgImage.bitmapInfo, version: 0, decode: nil,
                  renderingIntent: cgImage.renderingIntent)
    }
    public init?(bitsPerComponent: Int, bitsPerPixel: Int, colorSpace: CGColorSpace, bitmapInfo: CGBitmapInfo,
                 renderingIntent: CGColorRenderingIntent = .defaultIntent) {
        guard bitsPerComponent > 0, bitsPerPixel >= bitsPerComponent else { return nil }
        self.init(bitsPerComponent: UInt32(bitsPerComponent), bitsPerPixel: UInt32(bitsPerPixel),
                  colorSpace: Unmanaged.passRetained(colorSpace), bitmapInfo: bitmapInfo, version: 0, decode: nil,
                  renderingIntent: renderingIntent)
        var copy = self
        if vImageCGImageFormat_GetComponentCount(&copy) == 0 { return nil }
    }
    // (the formats keep their colour space: a vImage_CGImageFormat is a C struct with no deinit to release it)
    public var componentCount: Int { var f = self; return Int(vImageCGImageFormat_GetComponentCount(&f)) }
}

// MARK: - vImageConverter

extension vImageConverter {
    public static func make(sourceFormat: vImage_CGImageFormat, destinationFormat: vImage_CGImageFormat,
                            flags: vImage.Options = .noFlags) throws -> vImageConverter {
        var s = sourceFormat, d = destinationFormat, error = vImage_Error(kvImageNoError)
        guard let c = vImageConverter_CreateWithCGImageFormat(&s, &d, nil, flags.flags, &error) else { throw vImage.Error(vImageError: error) }
        return c.takeRetainedValue()
    }
    public func convert(source: vImage_Buffer, destination: inout vImage_Buffer, flags: vImage.Options = .noFlags) throws {
        var s = source
        try _vImageCheck(vImageConvert_AnyToAny(self, &s, &destination, nil, flags.flags))
    }
    public func mustOperateOutOfPlace(source: vImage_Buffer, destination: vImage_Buffer, flags: vImage.Options = .noFlags) throws -> Bool {
        var s = source, d = destination
        let r = vImageConverter_MustOperateOutOfPlace(self, &s, &d, flags.flags)
        if r == vImage_Error(kvImageOutOfPlaceOperationRequired) { return true }
        try _vImageCheck(r)
        return false
    }
    public var sourceBufferCount: Int { Int(vImageConverter_GetNumberOfSourceBuffers(self)) }
    public var destinationBufferCount: Int { Int(vImageConverter_GetNumberOfDestinationBuffers(self)) }
    public func sourceBuffers(colorSpace: CGColorSpace) -> [vImage.BufferType?] {
        _types(vImageConverter_GetSourceBufferOrder(self), colorSpace)
    }
    public func destinationBuffers(colorSpace: CGColorSpace) -> [vImage.BufferType?] {
        _types(vImageConverter_GetDestinationBufferOrder(self), colorSpace)
    }
    private func _types(_ order: UnsafePointer<vImageBufferTypeCode>?, _ cs: CGColorSpace) -> [vImage.BufferType?] {
        guard var p = order else { return [] }
        var out: [vImage.BufferType?] = []
        while p.pointee != vImageBufferTypeCode(kvImageBufferTypeCode_EndOfList) {
            out.append(vImage.BufferType(bufferTypeCode: Int(p.pointee), model: cs.model)); p += 1
        }
        return out
    }
}

// MARK: - pixel formats

/// A pixel format of a vImage.PixelBuffer.
public protocol PixelFormat {
    associatedtype ComponentType
}
/// A pixel format whose layout is known statically.
public protocol StaticPixelFormat: PixelFormat {
    static var bitCountPerPixel: Int { get }
    static var channelCount: Int { get }
}
/// A pixel format held in one buffer (planar, or interleaved channels).
public protocol SinglePlanePixelFormat: StaticPixelFormat {}
/// A pixel format a vImage.PixelBuffer can be made from a CGImage in.
public protocol InitializableFromCGImage: StaticPixelFormat {
    static var bitCountPerComponent: Int { get }
}
/// A pixel format held in one planar buffer per channel.
public protocol MultiplePlanePixelFormat: StaticPixelFormat {
    associatedtype PlanarPixelFormat: SinglePlanePixelFormat
    static var planeCount: Int { get }
    static var bitCountPerPlanarPixel: Int { get }
}
extension StaticPixelFormat {
    /// The bits of one channel's value.
    static var _componentBits: Int { MemoryLayout<ComponentType>.size * 8 }
}

extension vImage {
    public struct Planar8: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_8
        public static let bitCountPerComponent = 8, channelCount = 1, bitCountPerPixel = 8
    }
    public struct PlanarF: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_F
        public static let bitCountPerComponent = 32, channelCount = 1, bitCountPerPixel = 32
        /// A half's bits as a float.
        public static func makePixel(_ value: Pixel_16F) -> Pixel_F { _halfToFloat([value])[0] }
    }
    public struct Planar16U: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16U
        public static let bitCountPerComponent = 16, channelCount = 1, bitCountPerPixel = 16
    }
    public struct Planar16F: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16F
        public static let bitCountPerComponent = 16, channelCount = 1, bitCountPerPixel = 16
        /// A float as a half's bits.
        public static func makePixel(_ value: Pixel_F) -> Pixel_16F { _floatToHalf([value])[0] }
    }
    public struct Interleaved8x2: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_8
        public static let bitCountPerComponent = 8, channelCount = 2, bitCountPerPixel = 16
    }
    public struct Interleaved8x3: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_8
        public static let bitCountPerComponent = 8, channelCount = 3, bitCountPerPixel = 24
    }
    public struct Interleaved8x4: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_8
        public static let bitCountPerComponent = 8, channelCount = 4, bitCountPerPixel = 32
    }
    public struct InterleavedFx2: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_F
        public static let bitCountPerComponent = 32, channelCount = 2, bitCountPerPixel = 64
        public static func makePixel(_ value: Pixel_16F16F) -> Pixel_FF { let f = _halfToFloat([value.0, value.1]); return (f[0], f[1]) }
    }
    public struct InterleavedFx3: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_F
        public static let bitCountPerComponent = 32, channelCount = 3, bitCountPerPixel = 96
    }
    public struct InterleavedFx4: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_F
        public static let bitCountPerComponent = 32, channelCount = 4, bitCountPerPixel = 128
        public static func makePixel(_ value: Pixel_ARGB_16F) -> Pixel_FFFF {
            let f = _halfToFloat([value.0, value.1, value.2, value.3]); return (f[0], f[1], f[2], f[3])
        }
    }
    public struct Interleaved16Ux2: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16U
        public static let bitCountPerComponent = 16, channelCount = 2, bitCountPerPixel = 32
    }
    public struct Interleaved16Ux4: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16U
        public static let bitCountPerComponent = 16, channelCount = 4, bitCountPerPixel = 64
    }
    public struct Interleaved16Fx2: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16F
        public static let bitCountPerComponent = 16, channelCount = 2, bitCountPerPixel = 32
        public static func makePixel(_ value: Pixel_FF) -> Pixel_16F16F { let h = _floatToHalf([value.0, value.1]); return (h[0], h[1]) }
    }
    public struct Interleaved16Fx4: SinglePlanePixelFormat, InitializableFromCGImage {
        public typealias ComponentType = Pixel_16F
        public static let bitCountPerComponent = 16, channelCount = 4, bitCountPerPixel = 64
        public static func makePixel(_ value: Pixel_FFFF) -> Pixel_ARGB_16F {
            let h = _floatToHalf([value.0, value.1, value.2, value.3]); return (h[0], h[1], h[2], h[3])
        }
    }

    // the multiple-plane formats: one Planar8 or PlanarF buffer per channel
    public struct Planar8x2: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_8; public typealias PlanarPixelFormat = Planar8
        public static let planeCount = 2, channelCount = 2, bitCountPerPlanarPixel = 8, bitCountPerPixel = 16
    }
    public struct Planar8x3: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_8; public typealias PlanarPixelFormat = Planar8
        public static let planeCount = 3, channelCount = 3, bitCountPerPlanarPixel = 8, bitCountPerPixel = 24
    }
    public struct Planar8x4: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_8; public typealias PlanarPixelFormat = Planar8
        public static let planeCount = 4, channelCount = 4, bitCountPerPlanarPixel = 8, bitCountPerPixel = 32
    }
    public struct PlanarFx2: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_F; public typealias PlanarPixelFormat = PlanarF
        public static let planeCount = 2, channelCount = 2, bitCountPerPlanarPixel = 32, bitCountPerPixel = 64
    }
    public struct PlanarFx3: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_F; public typealias PlanarPixelFormat = PlanarF
        public static let planeCount = 3, channelCount = 3, bitCountPerPlanarPixel = 32, bitCountPerPixel = 96
    }
    public struct PlanarFx4: MultiplePlanePixelFormat {
        public typealias ComponentType = Pixel_F; public typealias PlanarPixelFormat = PlanarF
        public static let planeCount = 4, channelCount = 4, bitCountPerPlanarPixel = 32, bitCountPerPixel = 128
    }

    /// A pixel format known only at run time: the buffers a vImageConverter reads or writes for a Core Video pixel
    /// buffer (vImageConverter.makeCVToCGPixelBuffers, PixelBuffer(referencing:converter:destinationPixelFormat:)).
    public struct DynamicPixelFormat: PixelFormat {
        public typealias ComponentType = UInt8
    }
}

func _halfToFloat(_ h: [Pixel_16F]) -> [Pixel_F] {
    var h = h, f = [Pixel_F](repeating: 0, count: h.count)
    h.withUnsafeMutableBytes { hp in f.withUnsafeMutableBytes { fp in
        var s = vImage_Buffer(data: hp.baseAddress!, height: 1, width: vImagePixelCount(hp.count / 2), rowBytes: hp.count)
        var d = vImage_Buffer(data: fp.baseAddress!, height: 1, width: vImagePixelCount(fp.count / 4), rowBytes: fp.count)
        _ = vImageConvert_Planar16FtoPlanarF(&s, &d, vImage_Flags(kvImageNoFlags))
    } }
    return f
}
func _floatToHalf(_ f: [Pixel_F]) -> [Pixel_16F] {
    var f = f, h = [Pixel_16F](repeating: 0, count: f.count)
    f.withUnsafeMutableBytes { fp in h.withUnsafeMutableBytes { hp in
        var s = vImage_Buffer(data: fp.baseAddress!, height: 1, width: vImagePixelCount(fp.count / 4), rowBytes: fp.count)
        var d = vImage_Buffer(data: hp.baseAddress!, height: 1, width: vImagePixelCount(hp.count / 2), rowBytes: hp.count)
        _ = vImageConvert_PlanarFtoPlanar16F(&s, &d, vImage_Flags(kvImageNoFlags))
    } }
    return h
}

// MARK: - PixelBuffer

extension vImage {
    /// An image buffer of a pixel format (one vImage_Buffer per plane), which frees the pixels it allocated.
    public struct PixelBuffer<Format: PixelFormat> {
        final class _Storage {
            var buffers: [vImage_Buffer]
            let owned: Bool
            var keep: Any?                  // what the pixels belong to (a CVPixelBuffer, the source buffers), kept alive
            init(buffers: [vImage_Buffer], owned: Bool) { self.buffers = buffers; self.owned = owned }
            convenience init(buffer: vImage_Buffer, owned: Bool) { self.init(buffers: [buffer], owned: owned) }
            deinit { if owned { for b in buffers { Darwin.free(b.data) } } }
        }
        let _storage: _Storage
        var _buffer: vImage_Buffer { _storage.buffers[0] }
        var _buffers: [vImage_Buffer] { _storage.buffers }
        init(_storage: _Storage) { self._storage = _storage }
    }
}

func _vImageAllocate(width: Int, height: Int, bitsPerPixel: Int) -> vImage_Buffer {
    var b = vImage_Buffer()
    precondition(vImageBuffer_Init(&b, vImagePixelCount(height), vImagePixelCount(width), UInt32(bitsPerPixel),
                                   vImage_Flags(kvImageNoFlags)) == 0, "vImage.PixelBuffer: could not allocate \(width) x \(height)")
    return b
}

extension vImage.PixelBuffer {
    public var width: Int { Int(_buffer.width) }
    public var height: Int { Int(_buffer.height) }
    public var size: vImage.Size { vImage.Size(width: width, height: height) }
    public func withUnsafeVImageBuffers<R>(_ body: ([vImage_Buffer]) throws -> R) rethrows -> R { try body(_buffers) }
}

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    public init(width: Int, height: Int, pixelFormat: Format.Type = Format.self) {
        self.init(_storage: _Storage(buffer: _vImageAllocate(width: width, height: height, bitsPerPixel: Format.bitCountPerPixel), owned: true))
    }
    public init(size: vImage.Size, pixelFormat: Format.Type = Format.self) {
        self.init(width: size.width, height: size.height, pixelFormat: pixelFormat)
    }
    /// A buffer over memory the caller owns.
    public init(data: UnsafeMutableRawPointer, width: Int, height: Int, byteCountPerRow: Int, pixelFormat: Format.Type = Format.self) {
        self.init(_storage: _Storage(buffer: vImage_Buffer(data: data, height: vImagePixelCount(height), width: vImagePixelCount(width),
                                                           rowBytes: byteCountPerRow), owned: false))
    }
    public init(data: UnsafeMutableRawPointer, width: Int, height: Int, byteCountPerRow: Int?, pixelFormat: Format.Type = Format.self) {
        self.init(data: data, width: width, height: height,
                  byteCountPerRow: byteCountPerRow ?? width * Format.bitCountPerPixel / 8, pixelFormat: pixelFormat)
    }
    /// A buffer of the pixel values, row by row.
    public init<U: AccelerateBuffer>(pixelValues: U, size: vImage.Size, pixelFormat: Format.Type = Format.self) where U.Element == Format.ComponentType {
        self.init(size: size, pixelFormat: pixelFormat)
        let n = size.width * Format.channelCount
        precondition(pixelValues.count >= n * size.height, "vImage.PixelBuffer: too few pixel values")
        let b = _buffer
        pixelValues.withUnsafeBufferPointer { src in
            for y in 0..<size.height {
                let row = b.data.advanced(by: y * b.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
                for i in 0..<n { row[i] = src[y * n + i] }
            }
        }
    }

    public var channelCount: Int { Format.channelCount }
    public var byteCountPerPixel: Int { Format.bitCountPerPixel / 8 }
    public var bytesPerRow: Int { _buffer.rowBytes }
    /// The elements per row, padding included.
    public var rowStride: Int { _buffer.rowBytes / (Format._componentBits / 8) }
    /// The number of elements, padding included.
    public var count: Int { rowStride * height }
    /// The pixel values row by row, without the padding.
    public var array: [Format.ComponentType] {
        let n = width * channelCount, b = _buffer
        var out: [Format.ComponentType] = []
        out.reserveCapacity(n * height)
        for y in 0..<height {
            let row = b.data.advanced(by: y * b.rowBytes).assumingMemoryBound(to: Format.ComponentType.self)
            out.append(contentsOf: UnsafeBufferPointer(start: row, count: n))
        }
        return out
    }
    /// The pixel values row by row as another element type (the bytes reinterpreted), channelCount values per pixel.
    public func makeArray<U>(of type: U.Type, channelCount: Int) -> [U] {
        let n = width * channelCount, b = _buffer
        precondition(n * MemoryLayout<U>.stride <= b.rowBytes, "vImage.PixelBuffer.makeArray: more values than a row holds")
        var out: [U] = []
        out.reserveCapacity(n * height)
        for y in 0..<height {
            let row = b.data.advanced(by: y * b.rowBytes).assumingMemoryBound(to: U.self)
            out.append(contentsOf: UnsafeBufferPointer(start: row, count: n))
        }
        return out
    }
    public func withUnsafeVImageBuffer<R>(_ body: (vImage_Buffer) throws -> R) rethrows -> R { try body(_buffer) }
    public func withUnsafePointerToVImageBuffer<R>(_ body: (UnsafePointer<vImage_Buffer>) throws -> R) rethrows -> R {
        try withUnsafePointer(to: &_storage.buffers[0], body)
    }
    public func withUnsafeBufferPointer<R>(_ body: (UnsafeBufferPointer<Format.ComponentType>) throws -> R) rethrows -> R {
        try body(UnsafeBufferPointer(start: _buffer.data.assumingMemoryBound(to: Format.ComponentType.self), count: count))
    }
    public func withUnsafeMutableBufferPointer<R>(_ body: (inout UnsafeMutableBufferPointer<Format.ComponentType>) throws -> R) rethrows -> R {
        var p = UnsafeMutableBufferPointer(start: _buffer.data.assumingMemoryBound(to: Format.ComponentType.self), count: count)
        return try body(&p)
    }
    /// A sub-rectangle sharing these pixels.
    public func withUnsafeRegionOfInterest<R>(_ regionOfInterest: CGRect, _ body: (vImage.PixelBuffer<Format>) throws -> R) rethrows -> R {
        try body(_region(regionOfInterest))
    }
    func _region(_ rect: CGRect) -> vImage.PixelBuffer<Format> {
        let r = rect.integral.intersection(CGRect(x: 0, y: 0, width: width, height: height))
        let b = _buffer
        let p = b.data.advanced(by: Int(r.minY) * b.rowBytes + Int(r.minX) * byteCountPerPixel)
        let sub = vImage.PixelBuffer(data: p, width: Int(r.width), height: Int(r.height), byteCountPerRow: b.rowBytes, pixelFormat: Format.self)
        sub._storage.keep = _storage
        return sub
    }
    /// A new buffer with a copy of a sub-rectangle.
    public func cropped(to rect: CGRect) -> vImage.PixelBuffer<Format> {
        let r = _region(rect), out = vImage.PixelBuffer<Format>(size: r.size)
        r.copy(to: out)
        return out
    }
    /// Copies the destination-sized rectangle at a point into the destination.
    public func crop(at point: CGPoint, destination: vImage.PixelBuffer<Format>) {
        _region(CGRect(origin: point, size: CGSize(width: destination.width, height: destination.height))).copy(to: destination)
    }
    public func makeCGImage(cgImageFormat: vImage_CGImageFormat) -> CGImage? {
        var b = _buffer, f = cgImageFormat, e = vImage_Error(kvImageNoError)
        return vImageCreateCGImageFromBuffer(&b, &f, nil, nil, vImage_Flags(kvImageNoFlags), &e)?.takeRetainedValue()
    }
    public func copy(to destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageCopyBuffer($0, $1, self.byteCountPerPixel, vImage_Flags(kvImageNoFlags)) }
    }

    func _call2<F>(_ destination: vImage.PixelBuffer<F>, _ fn: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>) -> vImage_Error) {
        var s = _buffer, d = destination._buffer
        let e = fn(&s, &d)
        precondition(e >= 0, "vImage: error \(e)")
    }
}

extension vImage.PixelBuffer where Format: InitializableFromCGImage {
    /// A buffer in the given Core Graphics format of an image (an empty format takes the image's own).
    public init(cgImage: CGImage, cgImageFormat: inout vImage_CGImageFormat, pixelFormat: Format.Type = Format.self) throws {
        var b = vImage_Buffer()
        try _vImageCheck(vImageBuffer_InitWithCGImage(&b, &cgImageFormat, nil, cgImage, vImage_Flags(kvImageNoFlags)))
        self.init(_storage: _Storage(buffer: b, owned: true))
    }
    /// A buffer of an image in the pixel format, and the Core Graphics format it was read in (the image's colour space,
    /// or sRGB / gray when the image's doesn't fit).
    public static func makePixelBufferAndCGImageFormat(cgImage: CGImage, pixelFormat: Format.Type = Format.self) throws
        -> (pixelBuffer: vImage.PixelBuffer<Format>, cgImageFormat: vImage_CGImageFormat) {
        let isFloat = Format.ComponentType.self == Pixel_F.self || Format.ComponentType.self == Pixel_16F.self
        let gray = Format.channelCount <= 2
        let cs: CGColorSpace = (cgImage.colorSpace.flatMap { ($0.numberOfComponents == 1) == gray ? $0 : nil })
            ?? (gray ? CGColorSpaceCreateDeviceGray() : CGColorSpaceCreateDeviceRGB())
        var info = CGBitmapInfo(rawValue: 0)
        switch Format.channelCount {
        case 2, 4: info.insert(CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue))
        default: info.insert(CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue))
        }
        if isFloat { info.insert(.floatComponents) }
        if Format.bitCountPerComponent == 16 { info.insert(.byteOrder16Little) } else if Format.bitCountPerComponent == 32 { info.insert(.byteOrder32Little) }
        guard var f = vImage_CGImageFormat(bitsPerComponent: Format.bitCountPerComponent, bitsPerPixel: Format.bitCountPerPixel,
                                           colorSpace: cs, bitmapInfo: info) else { throw vImage.Error.invalidImageFormat }
        let b = try vImage.PixelBuffer<Format>(cgImage: cgImage, cgImageFormat: &f, pixelFormat: pixelFormat)
        return (b, f)
    }
}

extension vImage.PixelBuffer where Format == vImage.DynamicPixelFormat {
    /// A buffer of an image in its own Core Graphics format.
    public static func makeDynamicPixelBufferAndCGImageFormat(cgImage: CGImage) throws
        -> (pixelBuffer: vImage.PixelBuffer<vImage.DynamicPixelFormat>, cgImageFormat: vImage_CGImageFormat) {
        guard var f = vImage_CGImageFormat(cgImage: cgImage) else { throw vImage.Error.invalidImageFormat }
        var b = vImage_Buffer()
        try _vImageCheck(vImageBuffer_InitWithCGImage(&b, &f, nil, cgImage, vImage_Flags(kvImageNoFlags)))
        return (vImage.PixelBuffer(_storage: _Storage(buffer: b, owned: true)), f)
    }
}

// MARK: - multiple-plane buffers

extension vImage.PixelBuffer where Format: MultiplePlanePixelFormat {
    public init(width: Int, height: Int, pixelFormat: Format.Type = Format.self) {
        self.init(_storage: _Storage(buffers: (0..<Format.planeCount).map { _ in
            _vImageAllocate(width: width, height: height, bitsPerPixel: Format.bitCountPerPlanarPixel) }, owned: true))
    }
    public init(size: vImage.Size, pixelFormat: Format.Type = Format.self) {
        self.init(width: size.width, height: size.height, pixelFormat: pixelFormat)
    }
    /// A buffer over the planar buffers (sharing their pixels).
    public init(planarBuffers: [vImage.PixelBuffer<Format.PlanarPixelFormat>], pixelFormat: Format.Type = Format.self) {
        precondition(planarBuffers.count == Format.planeCount, "vImage.PixelBuffer: \(Format.planeCount) planar buffers needed")
        precondition(Set(planarBuffers.map(\.size)).count == 1, "vImage.PixelBuffer: the planar buffers differ in size")
        self.init(_storage: _Storage(buffers: planarBuffers.map(\._buffer), owned: false))
        _storage.keep = planarBuffers.map(\._storage)
    }
    public var channelCount: Int { Format.channelCount }
    public func withUnsafePixelBuffer<R>(at index: Int, _ body: (vImage.PixelBuffer<Format.PlanarPixelFormat>) throws -> R) rethrows -> R {
        try body(_plane(index))
    }
    public func withUnsafePixelBuffers<R>(_ body: ([vImage.PixelBuffer<Format.PlanarPixelFormat>]) throws -> R) rethrows -> R {
        try body((0..<Format.planeCount).map(_plane))
    }
    func _plane(_ i: Int) -> vImage.PixelBuffer<Format.PlanarPixelFormat> {
        let p = vImage.PixelBuffer<Format.PlanarPixelFormat>(_storage: .init(buffer: _buffers[i], owned: false))
        p._storage.keep = _storage
        return p
    }
}

// MARK: operations by format

/// The per-format C functions the generic operations below call.
public protocol _vImageGeometry: SinglePlanePixelFormat {
    static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { get }
    static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { get }
    static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { get }
}

extension vImage.PixelBuffer where Format: _vImageGeometry {
    public func scale(destination: vImage.PixelBuffer<Format>) { _call2(destination) { Format._scale($0, $1, nil, vImage_Flags(kvImageNoFlags)) } }
    public func reflect(over axis: vImage.ReflectionAxis, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { axis == .horizontal ? Format._reflectH($0, $1, vImage_Flags(kvImageNoFlags)) : Format._reflectV($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
}

extension vImage.Planar8: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_Planar8 }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_Planar8 }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_Planar8 }
}
extension vImage.PlanarF: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_PlanarF }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_PlanarF }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_PlanarF }
}
extension vImage.Planar16U: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_Planar16U }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_Planar16U }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_Planar16U }
}
extension vImage.Planar16F: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_Planar16F }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_Planar16F }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_Planar16F }
}
extension vImage.Interleaved8x4: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_ARGB8888 }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_ARGB8888 }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_ARGB8888 }
}
extension vImage.InterleavedFx4: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_ARGBFFFF }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_ARGBFFFF }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_ARGBFFFF }
}
extension vImage.Interleaved16Ux4: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_ARGB16U }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_ARGB16U }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_ARGB16U }
}
extension vImage.Interleaved16Fx4: _vImageGeometry {
    public static var _scale: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, UnsafeMutableRawPointer?, vImage_Flags) -> vImage_Error { vImageScale_ARGB16F }
    public static var _reflectH: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageHorizontalReflect_ARGB16F }
    public static var _reflectV: (UnsafePointer<vImage_Buffer>, UnsafePointer<vImage_Buffer>, vImage_Flags) -> vImage_Error { vImageVerticalReflect_ARGB16F }
}

// rotation: quarter turns go through Rotate90, other angles through Rotate
extension vImage.PixelBuffer where Format == vImage.Planar8 {
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_8? = nil, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            if let q = rotation._quarterTurns { return vImageRotate90_Planar8(s, d, q, backgroundColor ?? 0, vImage_Flags(kvImageBackgroundColorFill)) }
            return vImageRotate_Planar8(s, d, nil, rotation._radians, backgroundColor ?? 0, vImage_Flags(kvImageBackgroundColorFill))
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_F? = nil, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { s, d in
            if let q = rotation._quarterTurns { return vImageRotate90_PlanarF(s, d, q, backgroundColor ?? 0, vImage_Flags(kvImageBackgroundColorFill)) }
            return vImageRotate_PlanarF(s, d, nil, rotation._radians, backgroundColor ?? 0, vImage_Flags(kvImageBackgroundColorFill))
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x4 {
    public func rotate(_ rotation: vImage.Rotation, backgroundColor: Pixel_8888? = nil, destination: vImage.PixelBuffer<Format>) {
        var bg = [UInt8](repeating: 0, count: 4)
        if let c = backgroundColor { bg = [c.0, c.1, c.2, c.3] }
        _call2(destination) { s, d in
            if let q = rotation._quarterTurns { return vImageRotate90_ARGB8888(s, d, q, bg, vImage_Flags(kvImageBackgroundColorFill)) }
            return vImageRotate_ARGB8888(s, d, nil, rotation._radians, bg, vImage_Flags(kvImageBackgroundColorFill))
        }
    }
    public func permuteChannels(to permuteMap: (UInt8, UInt8, UInt8, UInt8), destination: vImage.PixelBuffer<Format>) {
        let map = [permuteMap.0, permuteMap.1, permuteMap.2, permuteMap.3]
        _call2(destination) { vImagePermuteChannels_ARGB8888($0, $1, map, vImage_Flags(kvImageNoFlags)) }
    }
    /// Converts to floats: 0...255 becomes 0...1.
    public func convert(to destination: vImage.PixelBuffer<vImage.InterleavedFx4>) {
        let w = width, h = height, src = _buffer, dst = destination._buffer
        for y in 0..<h {
            let s = src.data.advanced(by: y * src.rowBytes).assumingMemoryBound(to: UInt8.self)
            let d = dst.data.advanced(by: y * dst.rowBytes).assumingMemoryBound(to: Float.self)
            for i in 0..<w * 4 { d[i] = Float(s[i]) / 255 }
        }
    }
    /// Drops the first channel (alpha in ARGB).
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x3>) {
        _call2(destination) { vImageConvert_ARGB8888toRGB888($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
    public func boxConvolve(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8888>, destination: vImage.PixelBuffer<Format>) {
        var bg = [UInt8](repeating: 0, count: 4)
        if let c = edgeMode._background { bg = [c.0, c.1, c.2, c.3] }
        _call2(destination) { vImageBoxConvolve_ARGB8888($0, $1, nil, 0, 0, UInt32(kernelSize.height), UInt32(kernelSize.width), bg, edgeMode._flags) }
    }
    public func tentConvolve(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8888>, destination: vImage.PixelBuffer<Format>) {
        var bg = [UInt8](repeating: 0, count: 4)
        if let c = edgeMode._background { bg = [c.0, c.1, c.2, c.3] }
        _call2(destination) { vImageTentConvolve_ARGB8888($0, $1, nil, 0, 0, UInt32(kernelSize.height), UInt32(kernelSize.width), bg, edgeMode._flags) }
    }
}
extension vImage.PixelBuffer where Format == vImage.InterleavedFx4 {
    /// Converts to 8 bits: 0...1 becomes 0...255.
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        let w = width, h = height, src = _buffer, dst = destination._buffer
        for y in 0..<h {
            let s = src.data.advanced(by: y * src.rowBytes).assumingMemoryBound(to: Float.self)
            let d = dst.data.advanced(by: y * dst.rowBytes).assumingMemoryBound(to: UInt8.self)
            for i in 0..<w * 4 { d[i] = UInt8(max(0, min(255, (s[i] * 255).rounded()))) }
        }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar8 {
    /// Converts to floats: 0...255 becomes 0...1.
    public func convert(to destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _call2(destination) { vImageConvert_Planar8toPlanarF($0, $1, 1, 0, vImage_Flags(kvImageNoFlags)) }
    }
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar16U>) {
        _call2(destination) { vImageConvert_Planar8To16U($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar16F>) {
        _call2(destination) { vImageConvert_Planar8toPlanar16F($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
    /// The 256-bin histogram.
    public func histogram() -> [vImagePixelCount] {
        var h = [vImagePixelCount](repeating: 0, count: 256), b = _buffer
        _ = vImageHistogramCalculation_Planar8(&b, &h, vImage_Flags(kvImageNoFlags))
        return h
    }
    public func boxConvolve(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageBoxConvolve_Planar8($0, $1, nil, 0, 0, UInt32(kernelSize.height), UInt32(kernelSize.width), edgeMode._background ?? 0, edgeMode._flags) }
    }
    public func tentConvolve(kernelSize: vImage.Size, edgeMode: vImage.EdgeMode<Pixel_8>, destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageTentConvolve_Planar8($0, $1, nil, 0, 0, UInt32(kernelSize.height), UInt32(kernelSize.width), edgeMode._background ?? 0, edgeMode._flags) }
    }
    public func equalizeHistogram(destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageEqualization_Planar8($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
    public func contrastStretch(destination: vImage.PixelBuffer<Format>) {
        _call2(destination) { vImageContrastStretch_Planar8($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.PlanarF {
    /// Converts to 8 bits: 0...1 becomes 0...255.
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { vImageConvert_PlanarFtoPlanar8($0, $1, 1, 0, vImage_Flags(kvImageNoFlags)) }
    }
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar16F>) {
        _call2(destination) { vImageConvert_PlanarFtoPlanar16F($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16F {
    public func convert(to destination: vImage.PixelBuffer<vImage.PlanarF>) {
        _call2(destination) { vImageConvert_Planar16FtoPlanarF($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { vImageConvert_Planar16FtoPlanar8($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Planar16U {
    public func convert(to destination: vImage.PixelBuffer<vImage.Planar8>) {
        _call2(destination) { vImageConvert_16UToPlanar8($0, $1, vImage_Flags(kvImageNoFlags)) }
    }
}
extension vImage.PixelBuffer where Format == vImage.Interleaved8x3 {
    public func permuteChannels(to permuteMap: (UInt8, UInt8, UInt8), destination: vImage.PixelBuffer<Format>) {
        let map = [permuteMap.0, permuteMap.1, permuteMap.2]
        _call2(destination) { vImagePermuteChannels_RGB888($0, $1, map, vImage_Flags(kvImageNoFlags)) }
    }
    /// Adds an opaque first channel (alpha in ARGB).
    public func convert(to destination: vImage.PixelBuffer<vImage.Interleaved8x4>) {
        _call2(destination) { vImageConvert_RGB888toARGB8888($0, nil, 255, $1, false, vImage_Flags(kvImageNoFlags)) }
    }
}
