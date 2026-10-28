// isim Core Media: sample buffer copies, and the video format description functions that read its extensions (clean
// aperture, pixel aspect ratio, the keys shared with image buffers) or turn it into a QuickTime / ISO 'ImageDescription'
// (big-endian, as stored in a movie's sample description) and back. Adapted: the image description carries the codec,
// size, name, depth and the extension atoms (avcC, hvcC, pasp, clap, ...); isim writes no other QuickTime fields.
import CoreVideo
import AudioToolbox

// MARK: - sample buffer copies

/// a new sample buffer with the same data and format and copies of the attachments
public func CMSampleBufferCreateCopy(allocator: CFAllocator?, sampleBuffer: CMSampleBuffer, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(_copy: sampleBuffer, timings: nil)
    return noErr
}
/// a copy with new timing: one entry for every sample, one for all of them, or none
public func CMSampleBufferCreateCopyWithNewTiming(allocator: CFAllocator?, sampleBuffer: CMSampleBuffer, sampleTimingEntryCount: CMItemCount,
                                                  sampleTimingArray: UnsafePointer<CMSampleTimingInfo>?, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    guard sampleTimingEntryCount >= 0, sampleTimingEntryCount == 0 || sampleTimingArray != nil else { return kCMSampleBufferError_RequiredParameterMissing }
    guard sampleTimingEntryCount <= 1 || sampleTimingEntryCount == sampleBuffer.numSamples else { return kCMSampleBufferError_InvalidEntryCount }
    let timings = sampleTimingArray.map { Array(UnsafeBufferPointer(start: $0, count: sampleTimingEntryCount)) } ?? []
    sampleBufferOut.pointee = CMSampleBuffer(_copy: sampleBuffer, timings: timings)
    return noErr
}
public let kCMSampleBufferError_InvalidEntryCount: OSStatus = -12738

// MARK: - extensions shared with image buffers

public let kCMFormatDescriptionExtension_CleanAperture: CFString = "CVCleanAperture" as CFString
public let kCMFormatDescriptionKey_CleanApertureWidth: CFString = "Width" as CFString
public let kCMFormatDescriptionKey_CleanApertureHeight: CFString = "Height" as CFString
public let kCMFormatDescriptionKey_CleanApertureHorizontalOffset: CFString = "HorizontalOffset" as CFString
public let kCMFormatDescriptionKey_CleanApertureVerticalOffset: CFString = "VerticalOffset" as CFString
public let kCMFormatDescriptionKey_CleanApertureWidthRational: CFString = "WidthRational" as CFString
public let kCMFormatDescriptionKey_CleanApertureHeightRational: CFString = "HeightRational" as CFString
public let kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational: CFString = "HorizontalOffsetRational" as CFString
public let kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational: CFString = "VerticalOffsetRational" as CFString
public let kCMFormatDescriptionExtension_PixelAspectRatio: CFString = kCVImageBufferPixelAspectRatioKey
public let kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing: CFString = "HorizontalSpacing" as CFString
public let kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing: CFString = "VerticalSpacing" as CFString
public let kCMFormatDescriptionExtension_FieldCount: CFString = kCVImageBufferFieldCountKey
public let kCMFormatDescriptionExtension_ColorPrimaries: CFString = kCVImageBufferColorPrimariesKey
public let kCMFormatDescriptionExtension_TransferFunction: CFString = kCVImageBufferTransferFunctionKey
public let kCMFormatDescriptionExtension_YCbCrMatrix: CFString = kCVImageBufferYCbCrMatrixKey
public let kCMFormatDescriptionExtension_ChromaLocationTopField: CFString = kCVImageBufferChromaLocationTopFieldKey
public let kCMFormatDescriptionExtension_VerbatimImageDescription: CFString = "VerbatimImageDescription" as CFString

let _commonImageBufferKeys: [CFString] = [kCMFormatDescriptionExtension_CleanAperture, kCMFormatDescriptionExtension_PixelAspectRatio,
                                           kCMFormatDescriptionExtension_FieldCount, kCMFormatDescriptionExtension_ColorPrimaries,
                                           kCMFormatDescriptionExtension_TransferFunction, kCMFormatDescriptionExtension_YCbCrMatrix,
                                           kCMFormatDescriptionExtension_ChromaLocationTopField]

/// the extension keys a video format description and its image buffers have in common (their attachments)
public func CMVideoFormatDescriptionGetExtensionKeysCommonWithImageBuffers() -> CFArray { _commonImageBufferKeys as NSArray as CFArray }

/// a number, or a [numerator, denominator] pair under the Rational key
private func _value(_ d: [String: Any], _ key: CFString, _ rational: CFString) -> Double? {
    if let n = d[key as String] as? NSNumber { return n.doubleValue }
    if let r = d[rational as String] as? [NSNumber], r.count == 2, r[1].doubleValue != 0 { return r[0].doubleValue / r[1].doubleValue }
    return nil
}

public func CMVideoFormatDescriptionGetCleanAperture(_ videoDesc: CMVideoFormatDescription, originIsAtTopLeft: Bool) -> CGRect {
    let w = Double(videoDesc._dimensions.width), h = Double(videoDesc._dimensions.height)
    guard let c = videoDesc._extensions[kCMFormatDescriptionExtension_CleanAperture as String] as? [String: Any],
          let cw = _value(c, kCMFormatDescriptionKey_CleanApertureWidth, kCMFormatDescriptionKey_CleanApertureWidthRational),
          let ch = _value(c, kCMFormatDescriptionKey_CleanApertureHeight, kCMFormatDescriptionKey_CleanApertureHeightRational) else {
        return CGRect(x: 0, y: 0, width: w, height: h)
    }
    // the offsets move the aperture's centre from the picture's centre (positive: right and down)
    let hx = _value(c, kCMFormatDescriptionKey_CleanApertureHorizontalOffset, kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational) ?? 0
    let vy = _value(c, kCMFormatDescriptionKey_CleanApertureVerticalOffset, kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational) ?? 0
    let x = (w - cw) / 2 + hx
    let y = originIsAtTopLeft ? (h - ch) / 2 + vy : (h - ch) / 2 - vy
    return CGRect(x: x, y: y, width: cw, height: ch)
}

/// the size to show the picture at: the clean aperture's, widened or narrowed by the pixel aspect ratio
public func CMVideoFormatDescriptionGetPresentationDimensions(_ videoDesc: CMVideoFormatDescription, usePixelAspectRatio: Bool, useCleanAperture: Bool) -> CGSize {
    var size = useCleanAperture ? CMVideoFormatDescriptionGetCleanAperture(videoDesc, originIsAtTopLeft: true).size
                                : CGSize(width: Double(videoDesc._dimensions.width), height: Double(videoDesc._dimensions.height))
    if usePixelAspectRatio, let p = videoDesc._extensions[kCMFormatDescriptionExtension_PixelAspectRatio as String] as? [String: Any],
       let hs = (p[kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing as String] as? NSNumber)?.doubleValue,
       let vs = (p[kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing as String] as? NSNumber)?.doubleValue, hs > 0, vs > 0 {
        size.width = size.width * hs / vs
    }
    return size
}

/// whether the image buffer could be described by the format: same size and pixel format, same shared attachments
public func CMVideoFormatDescriptionMatchesImageBuffer(_ desc: CMVideoFormatDescription, imageBuffer: CVImageBuffer) -> Bool {
    guard desc.mediaType == kCMMediaType_Video, Int(desc._dimensions.width) == imageBuffer._width, Int(desc._dimensions.height) == imageBuffer._height,
          desc.mediaSubType == imageBuffer._format else { return false }
    for k in _commonImageBufferKeys {
        let a = desc._extensions[k as String].map { $0 as AnyObject }, b = CVBufferCopyAttachment(imageBuffer, k, nil)
        switch (a, b) {
        case (nil, nil): continue
        case let (x?, y?): if !(x.isEqual(y)) { return false }
        default: return false
        }
    }
    return true
}

extension CMFormatDescription {
    public func cleanAperture(originIsAtTopLeft: Bool) -> CGRect { CMVideoFormatDescriptionGetCleanAperture(self, originIsAtTopLeft: originIsAtTopLeft) }
    public func presentationDimensions(usePixelAspectRatio: Bool = true, useCleanAperture: Bool = true) -> CGSize {
        CMVideoFormatDescriptionGetPresentationDimensions(self, usePixelAspectRatio: usePixelAspectRatio, useCleanAperture: useCleanAperture)
    }
    public func matchesImageBuffer(_ imageBuffer: CVImageBuffer) -> Bool { CMVideoFormatDescriptionMatchesImageBuffer(self, imageBuffer: imageBuffer) }
}

// MARK: - QuickTime / ISO image descriptions

public let kCMFormatDescriptionBridgeError_AllocationFailed: OSStatus = -12713
public let kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription: OSStatus = -12714
public let kCMFormatDescriptionBridgeError_InvalidFormatDescription: OSStatus = -12715
public let kCMFormatDescriptionBridgeError_UnsupportedSampleDescriptionFlavor: OSStatus = -12717

/// the file format a sample description is written for (the image description's version and vendor differ)
public struct CMImageDescriptionFlavor: RawRepresentable, Hashable, @unchecked Sendable {
    public var rawValue: CFString
    public init(rawValue: CFString) { self.rawValue = rawValue }
    public init(_ rawValue: CFString) { self.rawValue = rawValue }
    public static let quickTimeMovie = CMImageDescriptionFlavor(rawValue: "QuickTimeMovie" as CFString)
    public static let isoFamily = CMImageDescriptionFlavor(rawValue: "ISOFamily" as CFString)
    public static let mobile3GPFamily = CMImageDescriptionFlavor(rawValue: "3GPFamily" as CFString)
    public static let isoFamilyWithAppleExtensions = CMImageDescriptionFlavor(rawValue: "ISOFamilyWithAppleExtensions" as CFString)
    public static func == (a: CMImageDescriptionFlavor, b: CMImageDescriptionFlavor) -> Bool { (a.rawValue as String) == (b.rawValue as String) }
    public func hash(into h: inout Hasher) { h.combine(rawValue as String) }
}

/// the fixed part of an ImageDescription: 86 bytes before the extension atoms
private let _imageDescriptionHeader = 86
/// (offset, size) of the integer fields byte-swapped by CMSwap...ImageDescription (the name is bytes)
private let _imageDescriptionFields: [(Int, Int)] = [(0, 4), (4, 4), (8, 4), (12, 2), (14, 2), (16, 2), (18, 2), (20, 4), (24, 4), (28, 4),
                                                     (32, 2), (34, 2), (36, 4), (40, 4), (44, 4), (48, 2), (82, 2), (84, 2)]
private func _fourCC(_ s: String) -> UInt32 { s.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) } }
private func _fourCCString(_ v: UInt32) -> String { String(decoding: [24, 16, 8, 0].map { UInt8((v >> $0) & 0xff) }, as: UTF8.self) }
private func _knownFlavor(_ f: CMImageDescriptionFlavor?) -> Bool {
    f == nil || [CMImageDescriptionFlavor.quickTimeMovie, .isoFamily, .mobile3GPFamily, .isoFamilyWithAppleExtensions].contains(f!)
}

private struct _BE {
    var b: [UInt8] = []
    mutating func u16(_ v: Int) { b += [UInt8((v >> 8) & 0xff), UInt8(v & 0xff)] }
    mutating func u32(_ v: UInt32) { b += [24, 16, 8, 0].map { UInt8((v >> $0) & 0xff) } }
    mutating func atom(_ type: String, _ body: [UInt8]) { u32(UInt32(8 + body.count)); u32(_fourCC(type)); b += body }
}
private func _u32(_ b: [UInt8], _ i: Int) -> UInt32 { b[i..<i + 4].reduce(0) { $0 << 8 | UInt32($1) } }
private func _u16(_ b: [UInt8], _ i: Int) -> Int { Int(b[i]) << 8 | Int(b[i + 1]) }
private func _rational(_ d: [String: Any], _ key: CFString, _ rational: CFString) -> (Int32, UInt32) {
    if let r = d[rational as String] as? [NSNumber], r.count == 2 { return (r[0].int32Value, r[1].uint32Value) }
    let v = _value(d, key, rational) ?? 0
    return v == v.rounded() ? (Int32(v), 1) : (Int32((v * 1000).rounded()), 1000)
}

/// the format as a big-endian ImageDescription with its extension atoms, in a block buffer
public func CMVideoFormatDescriptionCopyAsBigEndianImageDescriptionBlockBuffer(allocator: CFAllocator?, videoFormatDescription: CMVideoFormatDescription,
                                                                               stringEncoding: CFStringEncoding, flavor: CMImageDescriptionFlavor?,
                                                                               blockBufferOut: UnsafeMutablePointer<CMBlockBuffer?>) -> OSStatus {
    let f = videoFormatDescription
    guard f.mediaType == kCMMediaType_Video else { return kCMFormatDescriptionBridgeError_InvalidFormatDescription }
    guard _knownFlavor(flavor) else { return kCMFormatDescriptionBridgeError_UnsupportedSampleDescriptionFlavor }
    let qt = flavor == nil || flavor == .quickTimeMovie
    var w = _BE()
    w.u32(0); w.u32(f.mediaSubType); w.u32(0); w.u16(0); w.u16(1)       // size (patched), codec, reserved, data reference 1
    w.u16(0); w.u16(0)                                                    // version, revision
    w.u32(qt ? _fourCC("appl") : 0); w.u32(0); w.u32(qt ? 512 : 0)        // vendor, temporal and spatial quality
    w.u16(Int(f._dimensions.width)); w.u16(Int(f._dimensions.height))
    w.u32(0x0048_0000); w.u32(0x0048_0000); w.u32(0); w.u16(1)            // 72 dpi, data size, one frame per sample
    let name = Array(((f._extensions[kCMFormatDescriptionExtension_FormatName as String] as? String) ?? "").utf8.prefix(31))
    w.b += [UInt8(name.count)] + name + [UInt8](repeating: 0, count: 31 - name.count)
    w.u16((f._extensions[kCMFormatDescriptionExtension_Depth as String] as? NSNumber).map { Int($0.int32Value) } ?? 24); w.u16(0xffff)
    let atoms = (f._extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any]) ?? [:]
    for (k, v) in atoms.sorted(by: { $0.key < $1.key }) where k.utf8.count == 4 {
        let body: [UInt8]? = (v as? Data).map(Array.init) ?? (v as? [UInt8])
        if let body { w.atom(k, body) }
    }
    if atoms["pasp"] == nil, let p = f._extensions[kCMFormatDescriptionExtension_PixelAspectRatio as String] as? [String: Any],
       let hs = p[kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing as String] as? NSNumber,
       let vs = p[kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing as String] as? NSNumber {
        var a = _BE(); a.u32(hs.uint32Value); a.u32(vs.uint32Value); w.atom("pasp", a.b)
    }
    if atoms["clap"] == nil, let c = f._extensions[kCMFormatDescriptionExtension_CleanAperture as String] as? [String: Any] {
        var a = _BE()
        for (k, r) in [(kCMFormatDescriptionKey_CleanApertureWidth, kCMFormatDescriptionKey_CleanApertureWidthRational),
                       (kCMFormatDescriptionKey_CleanApertureHeight, kCMFormatDescriptionKey_CleanApertureHeightRational),
                       (kCMFormatDescriptionKey_CleanApertureHorizontalOffset, kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational),
                       (kCMFormatDescriptionKey_CleanApertureVerticalOffset, kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational)] {
            let (n, d) = _rational(c, k, r); a.u32(UInt32(bitPattern: n)); a.u32(d)
        }
        w.atom("clap", a.b)
    }
    let size = UInt32(w.b.count)
    w.b.replaceSubrange(0..<4, with: [24, 16, 8, 0].map { UInt8((size >> $0) & 0xff) })
    blockBufferOut.pointee = CMBlockBuffer(_bytes: w.b)
    return noErr
}

public func CMVideoFormatDescriptionCreateFromBigEndianImageDescriptionData(allocator: CFAllocator?, bigEndianImageDescriptionData: UnsafePointer<UInt8>, size: Int,
                                                                            stringEncoding: CFStringEncoding, flavor: CMImageDescriptionFlavor?,
                                                                            formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    guard _knownFlavor(flavor) else { return kCMFormatDescriptionBridgeError_UnsupportedSampleDescriptionFlavor }
    let b = Array(UnsafeBufferPointer(start: bigEndianImageDescriptionData, count: size))
    guard size >= _imageDescriptionHeader, Int(_u32(b, 0)) <= size, Int(_u32(b, 0)) >= _imageDescriptionHeader else {
        return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription
    }
    let end = Int(_u32(b, 0))
    var ext: [String: Any] = [:]
    let nameLength = min(31, Int(b[50]))
    if nameLength > 0 { ext[kCMFormatDescriptionExtension_FormatName as String] = String(decoding: b[51..<51 + nameLength], as: UTF8.self) }
    ext[kCMFormatDescriptionExtension_Depth as String] = NSNumber(value: _u16(b, 82))
    var atoms: [String: Any] = [:], i = _imageDescriptionHeader
    while i + 8 <= end {
        let l = Int(_u32(b, i)), type = _fourCCString(_u32(b, i + 4))
        guard l >= 8, i + l <= end else { return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription }
        let body = Array(b[(i + 8)..<(i + l)])
        switch type {
        case "pasp" where body.count >= 8:
            ext[kCMFormatDescriptionExtension_PixelAspectRatio as String] = [kCMFormatDescriptionKey_PixelAspectRatioHorizontalSpacing as String: NSNumber(value: _u32(body, 0)),
                                                                             kCMFormatDescriptionKey_PixelAspectRatioVerticalSpacing as String: NSNumber(value: _u32(body, 4))]
        case "clap" where body.count >= 32:
            func pair(_ o: Int) -> [NSNumber] { [NSNumber(value: Int32(bitPattern: _u32(body, o))), NSNumber(value: _u32(body, o + 4))] }
            ext[kCMFormatDescriptionExtension_CleanAperture as String] = [
                kCMFormatDescriptionKey_CleanApertureWidthRational as String: pair(0), kCMFormatDescriptionKey_CleanApertureHeightRational as String: pair(8),
                kCMFormatDescriptionKey_CleanApertureHorizontalOffsetRational as String: pair(16),
                kCMFormatDescriptionKey_CleanApertureVerticalOffsetRational as String: pair(24)]
        default: atoms[type] = Data(body)
        }
        i += l
    }
    if !atoms.isEmpty { ext[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] = atoms }
    ext[kCMFormatDescriptionExtension_VerbatimImageDescription as String] = Data(b[0..<end])
    formatDescriptionOut.pointee = CMFormatDescription(_codec: _u32(b, 4), width: _u16(b, 32), height: _u16(b, 34), extensions: ext)
    return noErr
}

public func CMVideoFormatDescriptionCreateFromBigEndianImageDescriptionBlockBuffer(allocator: CFAllocator?, bigEndianImageDescriptionBlockBuffer: CMBlockBuffer,
                                                                                   stringEncoding: CFStringEncoding, flavor: CMImageDescriptionFlavor?,
                                                                                   formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    bigEndianImageDescriptionBlockBuffer._bytes.withUnsafeBufferPointer { p in
        guard let base = p.baseAddress else { return kCMFormatDescriptionBridgeError_InvalidSerializedSampleDescription }
        return CMVideoFormatDescriptionCreateFromBigEndianImageDescriptionData(allocator: allocator, bigEndianImageDescriptionData: base, size: p.count,
                                                                               stringEncoding: stringEncoding, flavor: flavor, formatDescriptionOut: formatDescriptionOut)
    }
}

/// byte-swaps the ImageDescription's integer fields in place (the extension atoms stay big-endian)
private func _swapImageDescription(_ p: UnsafeMutablePointer<UInt8>, _ size: Int) -> OSStatus {
    guard size >= _imageDescriptionHeader else { return kCMFormatDescriptionBridgeError_InvalidParameter }
    for (o, n) in _imageDescriptionFields {
        for k in 0..<(n / 2) { let t = p[o + k]; p[o + k] = p[o + n - 1 - k]; p[o + n - 1 - k] = t }
    }
    return noErr
}
public func CMSwapBigEndianImageDescriptionToHost(_ imageDescriptionData: UnsafeMutablePointer<UInt8>, _ imageDescriptionSize: Int) -> OSStatus {
    _swapImageDescription(imageDescriptionData, imageDescriptionSize)
}
public func CMSwapHostEndianImageDescriptionToBig(_ imageDescriptionData: UnsafeMutablePointer<UInt8>, _ imageDescriptionSize: Int) -> OSStatus {
    _swapImageDescription(imageDescriptionData, imageDescriptionSize)
}
