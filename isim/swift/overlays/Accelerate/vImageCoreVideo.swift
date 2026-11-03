// isim Accelerate Swift overlay (issue #693): vImage and Core Video. vImageCVImageFormat and the converters come from
// the C header; the C functions that take a CVPixelBufferRef are hidden from Swift (Swift's CVPixelBuffer is a Swift
// class), so this file declares them over Swift's CVPixelBuffer, passing the object to the C implementation
// (frameworks/Accelerate/vimage_cv.c) as its opaque pointer. Adapted.
import CoreGraphics
import CoreVideo

@_silgen_name("vImageCVImageFormat_CreateWithCVPixelBuffer") func _c_vImageCVImageFormat_CreateWithCVPixelBuffer(_ b: UnsafeMutableRawPointer?) -> UnsafeMutableRawPointer?
@_silgen_name("vImageBuffer_InitWithCVPixelBuffer")
func _c_vImageBuffer_InitWithCVPixelBuffer(_ buffer: UnsafeMutablePointer<vImage_Buffer>, _ format: UnsafeMutablePointer<vImage_CGImageFormat>,
                                           _ pb: UnsafeMutableRawPointer, _ cv: UnsafeMutableRawPointer?, _ bg: UnsafePointer<CGFloat>?,
                                           _ flags: vImage_Flags) -> vImage_Error
@_silgen_name("vImageBuffer_CopyToCVPixelBuffer")
func _c_vImageBuffer_CopyToCVPixelBuffer(_ buffer: UnsafePointer<vImage_Buffer>, _ format: UnsafePointer<vImage_CGImageFormat>,
                                         _ pb: UnsafeMutableRawPointer, _ cv: UnsafeMutableRawPointer?, _ bg: UnsafePointer<CGFloat>?,
                                         _ flags: vImage_Flags) -> vImage_Error
@_silgen_name("vImageBuffer_InitForCopyFromCVPixelBuffer")
func _c_vImageBuffer_InitForCopyFromCVPixelBuffer(_ buffers: UnsafeMutablePointer<vImage_Buffer>, _ c: UnsafeMutableRawPointer,
                                                  _ pb: UnsafeMutableRawPointer, _ flags: vImage_Flags) -> vImage_Error
@_silgen_name("vImageBuffer_InitForCopyToCVPixelBuffer")
func _c_vImageBuffer_InitForCopyToCVPixelBuffer(_ buffers: UnsafeMutablePointer<vImage_Buffer>, _ c: UnsafeMutableRawPointer,
                                                _ pb: UnsafeMutableRawPointer, _ flags: vImage_Flags) -> vImage_Error

@inline(__always) func _opaque(_ o: AnyObject) -> UnsafeMutableRawPointer { Unmanaged.passUnretained(o).toOpaque() }

public func vImageCVImageFormat_CreateWithCVPixelBuffer(_ buffer: CVPixelBuffer!) -> Unmanaged<vImageCVImageFormat>! {
    guard let buffer, let p = _c_vImageCVImageFormat_CreateWithCVPixelBuffer(_opaque(buffer)) else { return nil }
    return Unmanaged<vImageCVImageFormat>.fromOpaque(p)
}
public func vImageBuffer_InitWithCVPixelBuffer(_ buffer: UnsafeMutablePointer<vImage_Buffer>, _ desiredFormat: UnsafeMutablePointer<vImage_CGImageFormat>,
                                               _ cvPixelBuffer: CVPixelBuffer, _ cvImageFormat: vImageCVImageFormat!, _ backgroundColor: UnsafePointer<CGFloat>!,
                                               _ flags: vImage_Flags) -> vImage_Error {
    _c_vImageBuffer_InitWithCVPixelBuffer(buffer, desiredFormat, _opaque(cvPixelBuffer), cvImageFormat.map(_opaque), backgroundColor, flags)
}
public func vImageBuffer_CopyToCVPixelBuffer(_ buffer: UnsafePointer<vImage_Buffer>, _ bufferFormat: UnsafePointer<vImage_CGImageFormat>,
                                             _ cvPixelBuffer: CVPixelBuffer, _ cvImageFormat: vImageCVImageFormat!, _ backgroundColor: UnsafePointer<CGFloat>!,
                                             _ flags: vImage_Flags) -> vImage_Error {
    _c_vImageBuffer_CopyToCVPixelBuffer(buffer, bufferFormat, _opaque(cvPixelBuffer), cvImageFormat.map(_opaque), backgroundColor, flags)
}
public func vImageBuffer_InitForCopyFromCVPixelBuffer(_ buffers: UnsafeMutablePointer<vImage_Buffer>, _ converter: vImageConverter,
                                                      _ pixelBuffer: CVPixelBuffer, _ flags: vImage_Flags) -> vImage_Error {
    _c_vImageBuffer_InitForCopyFromCVPixelBuffer(buffers, _opaque(converter), _opaque(pixelBuffer), flags)
}
public func vImageBuffer_InitForCopyToCVPixelBuffer(_ buffers: UnsafeMutablePointer<vImage_Buffer>, _ converter: vImageConverter,
                                                    _ pixelBuffer: CVPixelBuffer, _ flags: vImage_Flags) -> vImage_Error {
    _c_vImageBuffer_InitForCopyToCVPixelBuffer(buffers, _opaque(converter), _opaque(pixelBuffer), flags)
}

// MARK: - vImageCVImageFormat

extension vImageCVImageFormat {
    /// the same object as the C interface's const format
    var _c: vImageConstCVImageFormat { unsafeBitCast(self, to: vImageConstCVImageFormat.self) }
    /// Core Video pixel formats (their four-character codes).
    public enum Format: UInt32 {
        case format1Monochrome = 0x01, format2Indexed = 0x02, format4Indexed = 0x04, format8Indexed = 0x08
        case format1IndexedGray_WhiteIsZero = 0x21, format2IndexedGray_WhiteIsZero = 0x22, format4IndexedGray_WhiteIsZero = 0x24
        case format8IndexedGray_WhiteIsZero = 0x28
        case format16BE555 = 0x10, format16LE555 = 0x4C35_3535, format16LE5551 = 0x3535_3531, format16BE565 = 0x4235_3635, format16LE565 = 0x4C35_3635
        case format24RGB = 0x18, format24BGR = 0x3234_4247, format32ARGB = 0x20, format32BGRA = 0x4247_5241, format32ABGR = 0x4142_4752
        case format32RGBA = 0x5247_4241, format64ARGB = 0x6236_3461, format64RGBAHalf = 0x5247_6841, format128RGBAFloat = 0x5247_6641
        case format48RGB = 0x6234_3872, format32AlphaGray = 0x6233_3261, format16Gray = 0x6231_3667
        case format30RGB = 0x5231_306B, format30RGBLEPackedWideGamut = 0x7733_3072, formatARGB2101010LEPacked = 0x6C31_3072
        case format422YpCbCr8 = 0x3276_7579, format4444YpCbCrA8 = 0x7634_3038, format4444YpCbCrA8R = 0x7234_3038, format4444AYpCbCr8 = 0x7934_3038
        case format4444AYpCbCr16 = 0x7934_3136, format444YpCbCr8 = 0x7633_3038, format422YpCbCr16 = 0x7632_3136, format422YpCbCr10 = 0x7632_3130
        case format444YpCbCr10 = 0x7634_3130, format420YpCbCr8Planar = 0x7934_3230, format420YpCbCr8PlanarFullRange = 0x6634_3230
        case format422YpCbCr_4A_8BiPlanar = 0x6132_7679, format420YpCbCr8BiPlanarVideoRange = 0x3432_3076, format420YpCbCr8BiPlanarFullRange = 0x3432_3066
        case format422YpCbCr8_yuvs = 0x7975_7673, format422YpCbCr8FullRange = 0x7975_7666
        case format420YpCbCr10BiPlanarVideoRange = 0x7834_3230, format420YpCbCr10BiPlanarFullRange = 0x7866_3230
        case format422YpCbCr10BiPlanarVideoRange = 0x7834_3232, format422YpCbCr10BiPlanarFullRange = 0x7866_3232
        case format444YpCbCr10BiPlanarVideoRange = 0x7834_3434, format444YpCbCr10BiPlanarFullRange = 0x7866_3434
        case formatOneComponent8 = 0x4C30_3038, formatOneComponent16Half = 0x4C30_3068, formatOneComponent32Float = 0x4C30_3066
        case formatTwoComponent8 = 0x3243_3038, formatTwoComponent16Half = 0x3243_3068, formatTwoComponent32Float = 0x3243_3066
        case formatDepthFloat16 = 0x6864_6570, formatDepthFloat32 = 0x6664_6570, formatDisparityFloat16 = 0x6864_6973, formatDisparityFloat32 = 0x6664_6973
        case format14Bayer_GRBG = 0x6772_6234, format14Bayer_RGGB = 0x7267_6734, format14Bayer_BGGR = 0x6267_6734, format14Bayer_GBRG = 0x6762_7234
    }
    /// Where chroma samples sit (Core Video's kCVImageBufferChromaLocation values).
    public enum ChromaSiting {
        case top, topLeft, bottom, bottomLeft, left, center, dv420
        var cfString: CFString {
            switch self {
            case .top: return "Top" as CFString
            case .topLeft: return "TopLeft" as CFString
            case .bottom: return "Bottom" as CFString
            case .bottomLeft: return "BottomLeft" as CFString
            case .left: return "Left" as CFString
            case .center: return "Center" as CFString
            case .dv420: return "DV 4:2:0" as CFString
            }
        }
        init?(_ s: CFString) {
            for c in [ChromaSiting.top, .topLeft, .bottom, .bottomLeft, .left, .center, .dv420] where (c.cfString as String) == (s as String) { self = c; return }
            return nil
        }
    }
    public static func make(buffer: CVPixelBuffer) -> vImageCVImageFormat? {
        vImageCVImageFormat_CreateWithCVPixelBuffer(buffer)?.takeRetainedValue()
    }
    public static func make(format: vImageCVImageFormat.Format, matrix: vImage_ARGBToYpCbCrMatrix, chromaSiting: vImageCVImageFormat.ChromaSiting,
                            colorSpace: CGColorSpace, alphaIsOpaqueHint: Bool) -> vImageCVImageFormat? {
        var m = matrix
        return vImageCVImageFormat_Create(format.rawValue, &m, chromaSiting.cfString, colorSpace, alphaIsOpaqueHint ? 1 : 0)?.takeRetainedValue()
    }
    public static func make(format: vImageCVImageFormat.Format, colorSpace: CGColorSpace, alphaIsOpaqueHint: Bool) -> vImageCVImageFormat? {
        vImageCVImageFormat_Create(format.rawValue, nil, nil, colorSpace, alphaIsOpaqueHint ? 1 : 0)?.takeRetainedValue()
    }
    public var channelCount: UInt32 { vImageCVImageFormat_GetChannelCount(_c) }
    public var channels: [vImage.BufferType] {
        guard var p = vImageCVImageFormat_GetChannelNames(_c) else { return [] }
        let model = colorSpace?.model
        var out: [vImage.BufferType] = []
        while p.pointee != vImageBufferTypeCode(kvImageBufferTypeCode_EndOfList) {
            if let t = vImage.BufferType(bufferTypeCode: Int(p.pointee), model: model) { out.append(t) }
            p += 1
        }
        return out
    }
    public func channelDescription(bufferType: vImage.BufferType) -> vImageChannelDescription? {
        vImageCVImageFormat_GetChannelDescription(_c, bufferType.bufferTypeCode)?.pointee
    }
    public var formatCode: UInt32 { vImageCVImageFormat_GetFormatCode(_c) }
    public var chromaSiting: vImageCVImageFormat.ChromaSiting? {
        get { vImageCVImageFormat_GetChromaSiting(_c).flatMap { ChromaSiting($0.takeUnretainedValue()) } }
        set { _ = vImageCVImageFormat_SetChromaSiting(self, newValue?.cfString) }
    }
    public var colorSpace: CGColorSpace? {
        get { vImageCVImageFormat_GetColorSpace(_c)?.takeUnretainedValue() }
        set { _ = vImageCVImageFormat_SetColorSpace(self, newValue) }
    }
    public var alphaIsOpaqueHint: Bool {
        get { vImageCVImageFormat_GetAlphaHint(_c) != 0 }
        set { _ = vImageCVImageFormat_SetAlphaHint(self, newValue ? 1 : 0) }
    }
}

// MARK: - converters

extension vImageConverter {
    public static func make(sourceFormat: vImageCVImageFormat, destinationFormat: vImage_CGImageFormat, flags: vImage.Options = .noFlags) throws -> vImageConverter {
        var d = destinationFormat, error = vImage_Error(kvImageNoError)
        guard let c = vImageConverter_CreateForCVToCGImageFormat(sourceFormat, &d, nil, flags.flags, &error) else { throw vImage.Error(vImageError: error) }
        return c.takeRetainedValue()
    }
    public static func make(sourceFormat: vImage_CGImageFormat, destinationFormat: vImageCVImageFormat, flags: vImage.Options = .noFlags) throws -> vImageConverter {
        var s = sourceFormat, error = vImage_Error(kvImageNoError)
        guard let c = vImageConverter_CreateForCGToCVImageFormat(&s, destinationFormat, nil, flags.flags, &error) else { throw vImage.Error(vImageError: error) }
        return c.takeRetainedValue()
    }
}

// MARK: - sizes and pixel buffers

extension vImage.Size {
    public init(cvPixelBuffer: CVPixelBuffer) {
        self.init(width: CVPixelBufferGetWidth(cvPixelBuffer), height: CVPixelBufferGetHeight(cvPixelBuffer))
    }
}

extension vImage.PixelBuffer where Format: SinglePlanePixelFormat {
    /// A copy of a Core Video pixel buffer in the given Core Graphics format (an empty format is filled in).
    public init(copying cvPixelBuffer: CVPixelBuffer, cvImageFormat: vImageCVImageFormat, cgImageFormat: inout vImage_CGImageFormat,
                pixelFormat: Format.Type = Format.self) throws {
        var b = vImage_Buffer()
        try _vImageCheck(vImageBuffer_InitWithCVPixelBuffer(&b, &cgImageFormat, cvPixelBuffer, cvImageFormat, nil, vImage_Flags(kvImageNoFlags)))
        _storage = _Storage(buffer: b, owned: true)
    }
    /// A buffer over one plane of a Core Video pixel buffer (its base address stays valid while the pixel buffer lives).
    public init(referencing cvPixelBuffer: CVPixelBuffer, planeIndex: Int, overrideSize: vImage.Size? = nil, pixelFormat: Format.Type = Format.self) {
        let planar = CVPixelBufferIsPlanar(cvPixelBuffer)
        let base = planar ? CVPixelBufferGetBaseAddressOfPlane(cvPixelBuffer, planeIndex) : CVPixelBufferGetBaseAddress(cvPixelBuffer)
        let w = overrideSize?.width ?? (planar ? CVPixelBufferGetWidthOfPlane(cvPixelBuffer, planeIndex) : CVPixelBufferGetWidth(cvPixelBuffer))
        let h = overrideSize?.height ?? (planar ? CVPixelBufferGetHeightOfPlane(cvPixelBuffer, planeIndex) : CVPixelBufferGetHeight(cvPixelBuffer))
        let rb = planar ? CVPixelBufferGetBytesPerRowOfPlane(cvPixelBuffer, planeIndex) : CVPixelBufferGetBytesPerRow(cvPixelBuffer)
        precondition(base != nil, "vImage.PixelBuffer: the pixel buffer has no plane \(planeIndex)")
        _storage = _Storage(buffer: vImage_Buffer(data: base, height: vImagePixelCount(h), width: vImagePixelCount(w), rowBytes: rb), owned: false)
        _storage.keep = cvPixelBuffer
    }
    /// Copies these pixels, in the given Core Graphics format, into a Core Video pixel buffer.
    public func copy(to cvPixelBuffer: CVPixelBuffer, cvImageFormat: vImageCVImageFormat, cgImageFormat: vImage_CGImageFormat) throws {
        var b = _buffer, f = cgImageFormat
        try _vImageCheck(vImageBuffer_CopyToCVPixelBuffer(&b, &f, cvPixelBuffer, cvImageFormat, nil, vImage_Flags(kvImageNoFlags)))
    }
}
