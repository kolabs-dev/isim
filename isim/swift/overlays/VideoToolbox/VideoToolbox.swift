// isim VideoToolbox (self-authored, iOS API names): decompression and compression sessions over the host's
// libavcodec (isim_vcodec_* decodes H.264 / HEVC, isim_venc_* encodes with libx264 / libx265), pixel transfer
// sessions (format conversion and scaling) and VTCreateCGImageFromCVPixelBuffer.
// Adapted: frames are decoded and encoded synchronously, in the calling thread, and come out in presentation order
// (the encoder makes no B-frames); output callbacks are Swift closures (Apple's are C function pointers, so a closure
// that captures nothing converts the same way). Decoded frames are 8-bit BT.601.
@_exported import CoreMedia
@_exported import CoreVideo
import CoreGraphics
@_exported import AudioToolbox  // OSStatus (MacTypes), as Apple's CoreMedia exports CoreAudioTypes
import isim_host

// MARK: - errors and flags

public let kVTPropertyNotSupportedErr: OSStatus = -12900
public let kVTPropertyReadOnlyErr: OSStatus = -12901
public let kVTParameterErr: OSStatus = -12902
public let kVTInvalidSessionErr: OSStatus = -12903
public let kVTAllocationFailedErr: OSStatus = -12904
public let kVTPixelTransferNotSupportedErr: OSStatus = -12905
public let kVTCouldNotFindVideoDecoderErr: OSStatus = -12906
public let kVTCouldNotCreateInstanceErr: OSStatus = -12907
public let kVTCouldNotFindVideoEncoderErr: OSStatus = -12908
public let kVTVideoDecoderBadDataErr: OSStatus = -12909
public let kVTVideoDecoderUnsupportedDataFormatErr: OSStatus = -12910
public let kVTVideoDecoderMalfunctionErr: OSStatus = -12911
public let kVTVideoEncoderMalfunctionErr: OSStatus = -12912
public let kVTVideoDecoderNotAvailableNowErr: OSStatus = -12913
public let kVTImageRotationNotSupportedErr: OSStatus = -12914
public let kVTVideoEncoderNotAvailableNowErr: OSStatus = -12915
public let kVTFormatDescriptionChangeNotSupportedErr: OSStatus = -12916
public let kVTInsufficientSourceColorDataErr: OSStatus = -12917
public let kVTCouldNotCreateColorCorrectionDataErr: OSStatus = -12918
public let kVTColorSyncTransformConvertFailedErr: OSStatus = -12919
public let kVTVideoDecoderAuthorizationErr: OSStatus = -12210
public let kVTVideoEncoderAuthorizationErr: OSStatus = -12211
public let kVTColorCorrectionPixelTransferFailedErr: OSStatus = -12212
public let kVTMultiPassStorageIdentifierMismatchErr: OSStatus = -12213
public let kVTMultiPassStorageInvalidErr: OSStatus = -12214
public let kVTFrameSiloInvalidTimeStampErr: OSStatus = -12215
public let kVTFrameSiloInvalidTimeRangeErr: OSStatus = -12216
public let kVTCouldNotFindTemporalFilterErr: OSStatus = -12217
public let kVTPixelTransferNotPermittedErr: OSStatus = -12218
public let kVTColorCorrectionImageRotationFailedErr: OSStatus = -12219
public let kVTVideoDecoderRemovedErr: OSStatus = -17690

public struct VTDecodeFrameFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let _EnableAsynchronousDecompression = VTDecodeFrameFlags(rawValue: 1 << 0)
    public static let _DoNotOutputFrame = VTDecodeFrameFlags(rawValue: 1 << 1)
    public static let _1xRealTimePlayback = VTDecodeFrameFlags(rawValue: 1 << 2)
    public static let _EnableTemporalProcessing = VTDecodeFrameFlags(rawValue: 1 << 3)
}
public struct VTDecodeInfoFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let asynchronous = VTDecodeInfoFlags(rawValue: 1 << 0)
    public static let frameDropped = VTDecodeInfoFlags(rawValue: 1 << 1)
    public static let imageBufferModifiable = VTDecodeInfoFlags(rawValue: 1 << 2)
}
public struct VTEncodeInfoFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let asynchronous = VTEncodeInfoFlags(rawValue: 1 << 0)
    public static let frameDropped = VTEncodeInfoFlags(rawValue: 1 << 1)
}

// MARK: - properties

public let kVTDecompressionPropertyKey_RealTime = "RealTime" as CFString
public let kVTDecompressionPropertyKey_ThreadCount = "ThreadCount" as CFString
public let kVTDecompressionPropertyKey_MaximizePowerEfficiency = "MaximizePowerEfficiency" as CFString
public let kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder = "UsingHardwareAcceleratedVideoDecoder" as CFString
public let kVTDecompressionPropertyKey_PixelBufferPool = "PixelBufferPool" as CFString
public let kVTCompressionPropertyKey_RealTime = "RealTime" as CFString
public let kVTCompressionPropertyKey_AverageBitRate = "AverageBitRate" as CFString
public let kVTCompressionPropertyKey_DataRateLimits = "DataRateLimits" as CFString
public let kVTCompressionPropertyKey_MaxKeyFrameInterval = "MaxKeyFrameInterval" as CFString
public let kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration = "MaxKeyFrameIntervalDuration" as CFString
public let kVTCompressionPropertyKey_ExpectedFrameRate = "ExpectedFrameRate" as CFString
public let kVTCompressionPropertyKey_AllowFrameReordering = "AllowFrameReordering" as CFString
public let kVTCompressionPropertyKey_ProfileLevel = "ProfileLevel" as CFString
public let kVTCompressionPropertyKey_Quality = "Quality" as CFString
public let kVTCompressionPropertyKey_H264EntropyMode = "H264EntropyMode" as CFString
public let kVTCompressionPropertyKey_UsingHardwareAcceleratedVideoEncoder = "UsingHardwareAcceleratedVideoEncoder" as CFString
public let kVTCompressionPropertyKey_NumberOfPendingFrames = "NumberOfPendingFrames" as CFString
public let kVTEncodeFrameOptionKey_ForceKeyFrame = "ForceKeyFrame" as CFString
public let kVTProfileLevel_H264_Baseline_AutoLevel = "H264_Baseline_AutoLevel" as CFString
public let kVTProfileLevel_H264_Main_AutoLevel = "H264_Main_AutoLevel" as CFString
public let kVTProfileLevel_H264_High_AutoLevel = "H264_High_AutoLevel" as CFString
public let kVTProfileLevel_H264_ConstrainedBaseline_AutoLevel = "H264_ConstrainedBaseline_AutoLevel" as CFString
public let kVTProfileLevel_H264_ConstrainedHigh_AutoLevel = "H264_ConstrainedHigh_AutoLevel" as CFString
public let kVTProfileLevel_HEVC_Main_AutoLevel = "HEVC_Main_AutoLevel" as CFString
public let kVTProfileLevel_HEVC_Main10_AutoLevel = "HEVC_Main10_AutoLevel" as CFString
public let kVTPixelTransferPropertyKey_ScalingMode = "ScalingMode" as CFString
public let kVTScalingMode_Normal = "Normal" as CFString
public let kVTScalingMode_CropSourceToCleanAperture = "CropSourceToCleanAperture" as CFString
public let kVTScalingMode_Letterbox = "Letterbox" as CFString
public let kVTScalingMode_Trim = "Trim" as CFString

/// A VideoToolbox session: decompression, compression or pixel transfer.
public typealias VTSession = AnyObject

/// what every session keeps: its properties
open class _VTSessionBase: NSObject {
    var properties: [String: Any] = [:]
    var invalid = false
    func _supports(_ key: String) -> Bool { true }
}
@discardableResult public func VTSessionSetProperty(_ session: VTSession, key propertyKey: CFString, value propertyValue: CFTypeRef?) -> OSStatus {
    guard let s = session as? _VTSessionBase else { return kVTParameterErr }
    if s.invalid { return kVTInvalidSessionErr }
    s.properties[propertyKey as String] = propertyValue
    return noErr
}
@discardableResult public func VTSessionSetProperties(_ session: VTSession, propertyDictionary: CFDictionary) -> OSStatus {
    guard let s = session as? _VTSessionBase, let d = propertyDictionary as NSDictionary as? [String: Any] else { return kVTParameterErr }
    for (k, v) in d { s.properties[k] = v }
    return noErr
}
@discardableResult public func VTSessionCopyProperty(_ session: VTSession, key propertyKey: CFString, allocator: CFAllocator?, valueOut propertyValueOut: UnsafeMutableRawPointer?) -> OSStatus {
    guard let s = session as? _VTSessionBase, let out = propertyValueOut else { return kVTParameterErr }
    let key = propertyKey as String
    let v: Any? = key == (kVTDecompressionPropertyKey_UsingHardwareAcceleratedVideoDecoder as String) ? false
        : key == (kVTCompressionPropertyKey_NumberOfPendingFrames as String) ? 0 : s.properties[key]
    guard let v else { return kVTPropertyNotSupportedErr }
    out.assumingMemoryBound(to: AnyObject?.self).pointee = v as AnyObject
    return noErr
}
func _vtNumber(_ v: Any?) -> Double? {
    (v as? NSNumber)?.doubleValue ?? (v as? Double) ?? (v as? Int).map(Double.init) ?? (v as? UInt32).map(Double.init) ?? (v as? Int32).map(Double.init)
}
func _vtBool(_ v: Any?) -> Bool? { (v as? Bool) ?? (v as? NSNumber)?.boolValue }

/// isim: whether the host can decode the codec (H.264 and HEVC with the host's libavcodec)
public func VTIsHardwareDecodeSupported(_ codecType: CMVideoCodecType) -> Bool { codecType == kCMVideoCodecType_H264 || codecType == kCMVideoCodecType_HEVC }

// MARK: - pixels

/// writes tightly packed BGRA into a pixel buffer of any of isim's writable formats (BGRA, ARGB, RGBA, 420v / 420f)
func _vtWrite(_ px: [UInt8], width w: Int, height h: Int, into b: CVPixelBuffer) {
    CVPixelBufferLockBaseAddress(b, [])
    defer { CVPixelBufferUnlockBaseAddress(b, []) }
    let f = b._format
    if f == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange || f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
        let full = f == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        guard let y0 = CVPixelBufferGetBaseAddressOfPlane(b, 0)?.assumingMemoryBound(to: UInt8.self),
              let c0 = CVPixelBufferGetBaseAddressOfPlane(b, 1)?.assumingMemoryBound(to: UInt8.self) else { return }
        let yb = CVPixelBufferGetBytesPerRowOfPlane(b, 0), cb = CVPixelBufferGetBytesPerRowOfPlane(b, 1)
        func clamp(_ v: Double) -> UInt8 { UInt8(max(0, min(255, v.rounded()))) }
        for y in 0 ..< min(h, b._height) {
            for x in 0 ..< min(w, b._width) {
                let p = (y * w + x) * 4
                let (bl, g, r) = (Double(px[p]), Double(px[p + 1]), Double(px[p + 2]))
                let luma = 0.299 * r + 0.587 * g + 0.114 * bl
                y0[y * yb + x] = clamp(full ? luma : 16 + luma * 219 / 255)
                if x % 2 == 0 && y % 2 == 0 {
                    let u = (bl - luma) / 1.772, v = (r - luma) / 1.402
                    c0[(y / 2) * cb + x] = clamp(128 + (full ? u : u * 224 / 255)); c0[(y / 2) * cb + x + 1] = clamp(128 + (full ? v : v * 224 / 255))
                }
            }
        }
        return
    }
    guard let base = CVPixelBufferGetBaseAddress(b)?.assumingMemoryBound(to: UInt8.self) else { return }
    let bpr = CVPixelBufferGetBytesPerRow(b)
    for y in 0 ..< min(h, b._height) {
        for x in 0 ..< min(w, b._width) {
            let p = (y * w + x) * 4, o = base + y * bpr + x * 4
            switch f {
            case kCVPixelFormatType_32ARGB: o[0] = px[p + 3]; o[1] = px[p + 2]; o[2] = px[p + 1]; o[3] = px[p]
            case kCVPixelFormatType_32RGBA: o[0] = px[p + 2]; o[1] = px[p + 1]; o[2] = px[p]; o[3] = px[p + 3]
            default: o[0] = px[p]; o[1] = px[p + 1]; o[2] = px[p + 2]; o[3] = px[p + 3]
            }
        }
    }
}
/// BGRA scaled to w x h (bilinear)
func _vtScale(_ px: [UInt8], _ sw: Int, _ sh: Int, to w: Int, _ h: Int) -> [UInt8] {
    if sw == w && sh == h { return px }
    var out = [UInt8](repeating: 0, count: w * h * 4)
    for y in 0 ..< h {
        let fy = max(0, (Double(y) + 0.5) * Double(sh) / Double(h) - 0.5), y0 = min(sh - 1, Int(fy)), y1 = min(sh - 1, y0 + 1), ty = fy - Double(y0)
        for x in 0 ..< w {
            let fx = max(0, (Double(x) + 0.5) * Double(sw) / Double(w) - 0.5), x0 = min(sw - 1, Int(fx)), x1 = min(sw - 1, x0 + 1), tx = fx - Double(x0)
            for c in 0 ..< 4 {
                let a = Double(px[(y0 * sw + x0) * 4 + c]) * (1 - tx) + Double(px[(y0 * sw + x1) * 4 + c]) * tx
                let b = Double(px[(y1 * sw + x0) * 4 + c]) * (1 - tx) + Double(px[(y1 * sw + x1) * 4 + c]) * tx
                out[(y * w + x) * 4 + c] = UInt8(max(0, min(255, (a * (1 - ty) + b * ty).rounded())))
            }
        }
    }
    return out
}
func _vtPixelBuffer(_ px: [UInt8], width: Int, height: Int, format: OSType) -> CVPixelBuffer? {
    var out: CVPixelBuffer?
    guard CVPixelBufferCreate(nil, width, height, format, nil, &out) == kCVReturnSuccess, let b = out else { return nil }
    _vtWrite(px, width: width, height: height, into: b)
    return b
}

// MARK: - decompression

public typealias VTDecompressionOutputCallback = (_ decompressionOutputRefCon: UnsafeMutableRawPointer?, _ sourceFrameRefCon: UnsafeMutableRawPointer?,
                                                  _ status: OSStatus, _ infoFlags: VTDecodeInfoFlags, _ imageBuffer: CVImageBuffer?,
                                                  _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime) -> Void
public typealias VTDecompressionOutputHandler = (_ status: OSStatus, _ infoFlags: VTDecodeInfoFlags, _ imageBuffer: CVImageBuffer?,
                                                 _ presentationTimeStamp: CMTime, _ presentationDuration: CMTime) -> Void
public struct VTDecompressionOutputCallbackRecord {
    public var decompressionOutputCallback: VTDecompressionOutputCallback?
    public var decompressionOutputRefCon: UnsafeMutableRawPointer?
    public init() {}
    public init(decompressionOutputCallback: VTDecompressionOutputCallback?, decompressionOutputRefCon: UnsafeMutableRawPointer?) {
        self.decompressionOutputCallback = decompressionOutputCallback; self.decompressionOutputRefCon = decompressionOutputRefCon
    }
}

public final class VTDecompressionSession: _VTSessionBase, @unchecked Sendable {
    let format: CMFormatDescription
    let hevc: Bool
    var decoder: OpaquePointer?
    let outputFormat: OSType
    let callback: VTDecompressionOutputCallbackRecord?
    let lock = NSLock()
    /// frames in the decoder: (pts, duration, refcon, handler), sorted by pts — frames come out in presentation order
    var pending: [(pts: CMTime, duration: CMTime, refcon: UnsafeMutableRawPointer?, handler: VTDecompressionOutputHandler?)] = []
    init?(_ f: CMFormatDescription, attributes: [String: Any], callback: VTDecompressionOutputCallbackRecord?) {
        format = f; hevc = f.mediaSubType == kCMVideoCodecType_HEVC
        guard hevc || f.mediaSubType == kCMVideoCodecType_H264, let d = isim_vcodec_open(hevc ? "hevc" : "h264") else { return nil }
        decoder = d
        outputFormat = _vtNumber(attributes[kCVPixelBufferPixelFormatTypeKey as String]).map { OSType($0) } ?? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        self.callback = callback
        super.init()
    }
    deinit { if let d = decoder { isim_vcodec_close(d) } }

    /// AVCC samples to Annex-B access units, the parameter sets before key frames
    func units(_ sb: CMSampleBuffer) -> [(unit: [UInt8], timing: CMSampleTimingInfo)] {
        guard let block = sb._block else { return [] }
        let config = format._atom(hevc ? "hvcC" : "avcC") ?? []
        let sets = hevc ? _H26x.hvccSets(config) : _H26x.avccSets(config)
        let lengthSize = hevc ? (config.count > 21 ? Int(config[21] & 3) + 1 : 4) : (config.count > 4 ? Int(config[4] & 3) + 1 : 4)
        let bytes = block._bytes
        var out: [([UInt8], CMSampleTimingInfo)] = []
        for i in 0 ..< max(1, sb._numSamples) {
            guard let r = sb._sampleRange(i) else { continue }
            var unit: [UInt8] = []
            if _isimSampleIsSync(sb, i) { for s in sets { unit += [0, 0, 0, 1] + s } }
            var p = r.lowerBound
            while p + lengthSize <= r.upperBound {
                var n = 0
                for k in 0 ..< lengthSize { n = n << 8 | Int(bytes[p + k]) }
                p += lengthSize
                guard n > 0, p + n <= r.upperBound else { break }
                unit += [0, 0, 0, 1]; unit += bytes[p ..< p + n]; p += n
            }
            out.append((unit, i < sb._timings.count ? sb._timings[i] : sb._timing))
        }
        return out
    }
    func decode(_ sb: CMSampleBuffer, flags: VTDecodeFrameFlags, refcon: UnsafeMutableRawPointer?, handler: VTDecompressionOutputHandler?) -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        if invalid { return kVTInvalidSessionErr }
        guard let fmt = sb._format, fmt == format || fmt.mediaSubType == format.mediaSubType else { return kVTVideoDecoderUnsupportedDataFormatErr }
        for (unit, timing) in units(sb) {
            pending.append((timing.presentationTimeStamp, timing.duration, refcon, flags.contains(._DoNotOutputFrame) ? { _, _, _, _, _ in } : handler))
            pending.sort { $0.pts < $1.pts }
            if unit.withUnsafeBufferPointer({ isim_vcodec_send(decoder, $0.baseAddress, Int32($0.count)) }) < 0 {
                emit()
                if unit.withUnsafeBufferPointer({ isim_vcodec_send(decoder, $0.baseAddress, Int32($0.count)) }) < 0 {
                    let p = pending.removeLast()
                    deliver(kVTVideoDecoderBadDataErr, nil, p)
                    continue
                }
            }
            emit()
        }
        return noErr
    }
    /// hands decoded frames to the output callback or handler
    func emit() {
        var w: Int32 = 0, h: Int32 = 0
        while let d = decoder, isim_vcodec_receive(d, &w, &h) == 1 {
            var px = [UInt8](repeating: 0, count: Int(w) * Int(h) * 4)
            px.withUnsafeMutableBufferPointer { isim_vcodec_frame_bgra(d, $0.baseAddress!) }
            let p = pending.isEmpty ? (pts: CMTime.invalid, duration: CMTime.invalid, refcon: nil, handler: nil) : pending.removeFirst()
            deliver(noErr, _vtPixelBuffer(px, width: Int(w), height: Int(h), format: outputFormat), p)
        }
    }
    func deliver(_ status: OSStatus, _ image: CVPixelBuffer?, _ p: (pts: CMTime, duration: CMTime, refcon: UnsafeMutableRawPointer?, handler: VTDecompressionOutputHandler?)) {
        if let h = p.handler { h(status, [], image, p.pts, p.duration); return }
        callback?.decompressionOutputCallback?(callback?.decompressionOutputRefCon, p.refcon, status, [], image, p.pts, p.duration)
    }
    /// the decoder's delayed frames (frame reordering)
    func finish() {
        lock.lock(); defer { lock.unlock() }
        guard let d = decoder else { return }
        _ = isim_vcodec_send(d, nil, 0)
        emit()
        isim_vcodec_flush(d)
        for p in pending { deliver(noErr, nil, p) }       // nothing came out for them: dropped
        pending.removeAll()
    }
}

@discardableResult public func VTDecompressionSessionCreate(allocator: CFAllocator?, formatDescription videoFormatDescription: CMVideoFormatDescription,
                                         decoderSpecification videoDecoderSpecification: CFDictionary?, imageBufferAttributes destinationImageBufferAttributes: CFDictionary?,
                                         outputCallback: UnsafePointer<VTDecompressionOutputCallbackRecord>?,
                                         decompressionSessionOut: UnsafeMutablePointer<VTDecompressionSession?>) -> OSStatus {
    let attrs = destinationImageBufferAttributes.flatMap { $0 as NSDictionary as? [String: Any] } ?? [:]
    guard videoFormatDescription.mediaType == kCMMediaType_Video else { return kVTParameterErr }
    guard let s = VTDecompressionSession(videoFormatDescription, attributes: attrs, callback: outputCallback?.pointee) else { return kVTCouldNotFindVideoDecoderErr }
    decompressionSessionOut.pointee = s
    return noErr
}
@discardableResult public func VTDecompressionSessionDecodeFrame(_ session: VTDecompressionSession, sampleBuffer: CMSampleBuffer, flags decodeFlags: VTDecodeFrameFlags,
                                              frameRefcon sourceFrameRefCon: UnsafeMutableRawPointer?, infoFlagsOut: UnsafeMutablePointer<VTDecodeInfoFlags>?) -> OSStatus {
    infoFlagsOut?.pointee = []
    return session.decode(sampleBuffer, flags: decodeFlags, refcon: sourceFrameRefCon, handler: nil)
}
@discardableResult public func VTDecompressionSessionDecodeFrame(_ session: VTDecompressionSession, sampleBuffer: CMSampleBuffer, flags decodeFlags: VTDecodeFrameFlags,
                                              infoFlagsOut: UnsafeMutablePointer<VTDecodeInfoFlags>?, outputHandler: @escaping VTDecompressionOutputHandler) -> OSStatus {
    infoFlagsOut?.pointee = []
    return session.decode(sampleBuffer, flags: decodeFlags, refcon: nil, handler: outputHandler)
}
/// frames are decoded synchronously: nothing is outstanding
@discardableResult public func VTDecompressionSessionWaitForAsynchronousFrames(_ session: VTDecompressionSession) -> OSStatus { session.invalid ? kVTInvalidSessionErr : noErr }
@discardableResult public func VTDecompressionSessionFinishDelayedFrames(_ session: VTDecompressionSession) -> OSStatus {
    if session.invalid { return kVTInvalidSessionErr }
    session.finish(); return noErr
}
public func VTDecompressionSessionCanAcceptFormatDescription(_ session: VTDecompressionSession, formatDescription newFormatDesc: CMFormatDescription) -> Bool {
    newFormatDesc.mediaSubType == session.format.mediaSubType && newFormatDesc._atom(session.hevc ? "hvcC" : "avcC") == session.format._atom(session.hevc ? "hvcC" : "avcC")
}
@discardableResult public func VTDecompressionSessionCopyBlackPixelBuffer(_ session: VTDecompressionSession, pixelBufferOut: UnsafeMutablePointer<CVPixelBuffer?>) -> OSStatus {
    let d = CMVideoFormatDescriptionGetDimensions(session.format)
    let w = max(2, Int(d.width)), h = max(2, Int(d.height))
    var black = [UInt8](repeating: 0, count: w * h * 4)
    for i in stride(from: 3, to: black.count, by: 4) { black[i] = 255 }
    pixelBufferOut.pointee = _vtPixelBuffer(black, width: w, height: h, format: session.outputFormat)
    return noErr
}
public func VTDecompressionSessionInvalidate(_ session: VTDecompressionSession) {
    session.lock.lock(); session.invalid = true
    if let d = session.decoder { isim_vcodec_close(d); session.decoder = nil }
    session.lock.unlock()
}

// MARK: - compression

public typealias VTCompressionOutputCallback = (_ outputCallbackRefCon: UnsafeMutableRawPointer?, _ sourceFrameRefCon: UnsafeMutableRawPointer?,
                                                _ status: OSStatus, _ infoFlags: VTEncodeInfoFlags, _ sampleBuffer: CMSampleBuffer?) -> Void
public typealias VTCompressionOutputHandler = (_ status: OSStatus, _ infoFlags: VTEncodeInfoFlags, _ sampleBuffer: CMSampleBuffer?) -> Void

public final class VTCompressionSession: _VTSessionBase, @unchecked Sendable {
    let width: Int, height: Int, codec: CMVideoCodecType
    let callback: VTCompressionOutputCallback?
    let refcon: UnsafeMutableRawPointer?
    var encoder: OpaquePointer?
    var frameNumber: Int64 = 0
    var format: CMFormatDescription?
    let lock = NSLock()
    /// frames in the encoder, in order: they come out in order (no reordering)
    var pending: [(pts: CMTime, duration: CMTime, refcon: UnsafeMutableRawPointer?, handler: VTCompressionOutputHandler?)] = []
    lazy var pool: CVPixelBufferPool = _CVPixelBufferPoolMake(width: width, height: height, format: kCVPixelFormatType_32BGRA)
    init(width: Int, height: Int, codec: CMVideoCodecType, callback: VTCompressionOutputCallback?, refcon: UnsafeMutableRawPointer?) {
        self.width = width; self.height = height; self.codec = codec; self.callback = callback; self.refcon = refcon
        super.init()
    }
    deinit { if let e = encoder { isim_venc_close(e) } }
    var hevc: Bool { codec == kCMVideoCodecType_HEVC }

    func open() -> Bool {
        if encoder != nil { return true }
        let p = properties
        let fps = _vtNumber(p[kVTCompressionPropertyKey_ExpectedFrameRate as String]) ?? 30
        let bitrate = Int(_vtNumber(p[kVTCompressionPropertyKey_AverageBitRate as String]) ?? 0)
        var gop = Int(_vtNumber(p[kVTCompressionPropertyKey_MaxKeyFrameInterval as String]) ?? 0)
        if gop == 0, let d = _vtNumber(p[kVTCompressionPropertyKey_MaxKeyFrameIntervalDuration as String]), d > 0 { gop = Int((d * fps).rounded()) }
        let level = p[kVTCompressionPropertyKey_ProfileLevel as String].map { "\($0)" } ?? ""
        let profile = level.contains("Baseline") ? "baseline" : level.contains("Main") && !hevc ? "main" : level.contains("High") ? "high" : nil
        let realtime = _vtBool(p[kVTCompressionPropertyKey_RealTime as String]) ?? false
        encoder = isim_venc_open(hevc ? "hevc" : "h264", Int32(width), Int32(height), fps, bitrate, Int32(gop), profile, realtime ? 1 : 0)
        return encoder != nil
    }
    func encode(_ image: CVImageBuffer, pts: CMTime, duration: CMTime, properties fp: [String: Any]?, refcon r: UnsafeMutableRawPointer?, handler: VTCompressionOutputHandler?) -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        if invalid { return kVTInvalidSessionErr }
        guard open() else { return kVTCouldNotFindVideoEncoderErr }
        var px = image._bgra()
        if image._width != width || image._height != height { px = _vtScale(px, image._width, image._height, to: width, height) }
        let key = _vtBool(fp?[kVTEncodeFrameOptionKey_ForceKeyFrame as String]) ?? false
        pending.append((pts, duration, r, handler))
        let st = px.withUnsafeBufferPointer { isim_venc_send_bgra(encoder, $0.baseAddress, frameNumber, key ? 1 : 0) }
        frameNumber += 1
        if st < 0 { let p = pending.removeLast(); deliver(kVTVideoEncoderMalfunctionErr, nil, p); return kVTVideoEncoderMalfunctionErr }
        emit()
        return noErr
    }
    func emit() {
        var out = [UInt8](repeating: 0, count: max(1 << 16, width * height * 4))
        var pts: Int64 = 0, dts: Int64 = 0, key: Int32 = 0
        while let e = encoder {
            let n = out.withUnsafeMutableBufferPointer { isim_venc_receive(e, $0.baseAddress!, Int32($0.count), &pts, &dts, &key) }
            guard n > 0 else { break }
            let p = pending.isEmpty ? (pts: CMTime.invalid, duration: CMTime.invalid, refcon: nil, handler: nil) : pending.removeFirst()
            deliver(noErr, sample(Array(out[0 ..< Int(n)]), key: key != 0, pts: p.pts, duration: p.duration), p)
        }
    }
    /// an access unit as a sample buffer: AVCC (4-byte lengths), the parameter sets in the format description
    func sample(_ annexB: [UInt8], key: Bool, pts: CMTime, duration: CMTime) -> CMSampleBuffer? {
        var nals: [[UInt8]] = [], i = 0, start = -1
        while i + 3 <= annexB.count {
            if annexB[i] == 0 && annexB[i + 1] == 0 && annexB[i + 2] == 1 {
                if start >= 0 { var end = i; while end > start && annexB[end - 1] == 0 { end -= 1 }; nals.append(Array(annexB[start ..< end])) }
                i += 3; start = i
            } else { i += 1 }
        }
        if start >= 0 && start < annexB.count { nals.append(Array(annexB[start...])) }
        func type(_ n: [UInt8]) -> Int { hevc ? Int((n.first ?? 0) >> 1) & 0x3f : Int((n.first ?? 0) & 0x1f) }
        let setTypes: Set<Int> = hevc ? [32, 33, 34] : [7, 8]
        let sets = nals.filter { setTypes.contains(type($0)) }
        if !sets.isEmpty {
            var f: CMFormatDescription?
            let ptrs = sets.map { s -> UnsafePointer<UInt8> in let m = UnsafeMutablePointer<UInt8>.allocate(capacity: s.count); m.initialize(from: s, count: s.count); return UnsafePointer(m) }
            defer { for p in ptrs { UnsafeMutablePointer(mutating: p).deallocate() } }
            let sizes = sets.map(\.count)
            ptrs.withUnsafeBufferPointer { pp in sizes.withUnsafeBufferPointer { ss in
                if hevc { _ = CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: nil, parameterSetCount: sets.count, parameterSetPointers: pp.baseAddress!,
                                                                                   parameterSetSizes: ss.baseAddress!, nalUnitHeaderLength: 4, extensions: nil, formatDescriptionOut: &f) }
                else { _ = CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil, parameterSetCount: sets.count, parameterSetPointers: pp.baseAddress!,
                                                                               parameterSetSizes: ss.baseAddress!, nalUnitHeaderLength: 4, formatDescriptionOut: &f) }
            } }
            if let f, format == nil || format!._atom(hevc ? "hvcC" : "avcC") != f._atom(hevc ? "hvcC" : "avcC") { format = f }
        }
        guard let format else { return nil }
        var data: [UInt8] = []
        for n in nals where !setTypes.contains(type(n)) {
            data += [UInt8(n.count >> 24 & 255), UInt8(n.count >> 16 & 255), UInt8(n.count >> 8 & 255), UInt8(n.count & 255)] + n
        }
        let block = CMBlockBuffer(_bytes: data)
        var timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: pts, decodeTimeStamp: .invalid)
        var size = data.count
        var sb: CMSampleBuffer?
        CMSampleBufferCreateReady(allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: 1, sampleTimingEntryCount: 1,
                                  sampleTimingArray: &timing, sampleSizeEntryCount: 1, sampleSizeArray: &size, sampleBufferOut: &sb)
        if let sb, !key, let a = CMSampleBufferGetSampleAttachmentsArray(sb, createIfNecessary: true) as? [NSMutableDictionary], let d = a.first {
            d[kCMSampleAttachmentKey_NotSync as String as NSString] = true
            d[kCMSampleAttachmentKey_DependsOnOthers as String as NSString] = true
        }
        return sb
    }
    func deliver(_ status: OSStatus, _ sb: CMSampleBuffer?, _ p: (pts: CMTime, duration: CMTime, refcon: UnsafeMutableRawPointer?, handler: VTCompressionOutputHandler?)) {
        if let h = p.handler { h(status, [], sb); return }
        callback?(refcon, p.refcon, status, [], sb)
    }
    /// ends the stream: the encoder gives up its frames (a later frame starts a new one)
    func complete() {
        lock.lock(); defer { lock.unlock() }
        guard let e = encoder else { return }
        _ = isim_venc_send_bgra(e, nil, 0, 0)
        emit()
        isim_venc_close(e); encoder = nil
        for p in pending { deliver(noErr, nil, p) }
        pending.removeAll()
    }
}

@discardableResult public func VTCompressionSessionCreate(allocator: CFAllocator?, width: Int32, height: Int32, codecType: CMVideoCodecType, encoderSpecification: CFDictionary?,
                                       imageBufferAttributes sourceImageBufferAttributes: CFDictionary?, compressedDataAllocator: CFAllocator?,
                                       outputCallback: VTCompressionOutputCallback?, refcon outputCallbackRefCon: UnsafeMutableRawPointer?,
                                       compressionSessionOut: UnsafeMutablePointer<VTCompressionSession?>) -> OSStatus {
    guard codecType == kCMVideoCodecType_H264 || codecType == kCMVideoCodecType_HEVC else { return kVTCouldNotFindVideoEncoderErr }
    guard width > 0, height > 0, width % 2 == 0, height % 2 == 0 else { return kVTParameterErr }
    let s = VTCompressionSession(width: Int(width), height: Int(height), codec: codecType, callback: outputCallback, refcon: outputCallbackRefCon)
    guard s.open() else { return kVTCouldNotFindVideoEncoderErr }      // the host has the encoder
    isim_venc_close(s.encoder); s.encoder = nil                        // opened again with the session's properties
    compressionSessionOut.pointee = s
    return noErr
}
@discardableResult public func VTCompressionSessionPrepareToEncodeFrames(_ session: VTCompressionSession) -> OSStatus {
    session.lock.lock(); defer { session.lock.unlock() }
    return session.open() ? noErr : kVTCouldNotFindVideoEncoderErr
}
@discardableResult public func VTCompressionSessionEncodeFrame(_ session: VTCompressionSession, imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime,
                                            frameProperties: CFDictionary?, sourceFrameRefcon sourceFrameRefCon: UnsafeMutableRawPointer?,
                                            infoFlagsOut: UnsafeMutablePointer<VTEncodeInfoFlags>?) -> OSStatus {
    infoFlagsOut?.pointee = []
    return session.encode(imageBuffer, pts: presentationTimeStamp, duration: duration, properties: frameProperties.flatMap { $0 as NSDictionary as? [String: Any] },
                          refcon: sourceFrameRefCon, handler: nil)
}
@discardableResult public func VTCompressionSessionEncodeFrame(_ session: VTCompressionSession, imageBuffer: CVImageBuffer, presentationTimeStamp: CMTime, duration: CMTime,
                                            frameProperties: CFDictionary?, infoFlagsOut: UnsafeMutablePointer<VTEncodeInfoFlags>?,
                                            outputHandler: @escaping VTCompressionOutputHandler) -> OSStatus {
    infoFlagsOut?.pointee = []
    return session.encode(imageBuffer, pts: presentationTimeStamp, duration: duration, properties: frameProperties.flatMap { $0 as NSDictionary as? [String: Any] },
                          refcon: nil, handler: outputHandler)
}
/// every frame up to (here: including) the time comes out
@discardableResult public func VTCompressionSessionCompleteFrames(_ session: VTCompressionSession, untilPresentationTimeStamp completeUntilPresentationTimeStamp: CMTime) -> OSStatus {
    if session.invalid { return kVTInvalidSessionErr }
    session.complete(); return noErr
}
public func VTCompressionSessionGetPixelBufferPool(_ session: VTCompressionSession) -> CVPixelBufferPool? { session.invalid ? nil : session.pool }
public func VTCompressionSessionInvalidate(_ session: VTCompressionSession) {
    session.lock.lock(); session.invalid = true
    if let e = session.encoder { isim_venc_close(e); session.encoder = nil }
    session.lock.unlock()
}

// MARK: - pixel transfer

public final class VTPixelTransferSession: _VTSessionBase, @unchecked Sendable {}
@discardableResult public func VTPixelTransferSessionCreate(allocator: CFAllocator?, pixelTransferSessionOut: UnsafeMutablePointer<VTPixelTransferSession?>) -> OSStatus {
    pixelTransferSessionOut.pointee = VTPixelTransferSession(); return noErr
}
/// copies `source` into `destination`, converting the pixel format and scaling to its size by the session's scaling
/// mode: Normal / CropSourceToCleanAperture stretch, Letterbox fits (black bars), Trim fills (cropping the overflow)
@discardableResult public func VTPixelTransferSessionTransferImage(_ session: VTPixelTransferSession, from sourceBuffer: CVPixelBuffer, to destinationBuffer: CVPixelBuffer) -> OSStatus {
    if session.invalid { return kVTInvalidSessionErr }
    let sw = sourceBuffer._width, sh = sourceBuffer._height, dw = destinationBuffer._width, dh = destinationBuffer._height
    guard sw > 0, sh > 0, dw > 0, dh > 0 else { return kVTParameterErr }
    let mode = session.properties[kVTPixelTransferPropertyKey_ScalingMode as String].map { "\($0)" } ?? (kVTScalingMode_Normal as String)
    let src = sourceBuffer._bgra()
    var out: [UInt8]
    if mode == kVTScalingMode_Letterbox as String || mode == kVTScalingMode_Trim as String {
        let s = mode == kVTScalingMode_Letterbox as String ? min(Double(dw) / Double(sw), Double(dh) / Double(sh)) : max(Double(dw) / Double(sw), Double(dh) / Double(sh))
        let w = max(1, Int((Double(sw) * s).rounded())), h = max(1, Int((Double(sh) * s).rounded()))
        let scaled = _vtScale(src, sw, sh, to: w, h)
        out = [UInt8](repeating: 0, count: dw * dh * 4)
        for i in stride(from: 3, to: out.count, by: 4) { out[i] = 255 }
        let ox = (dw - w) / 2, oy = (dh - h) / 2
        for y in 0 ..< dh {
            let sy = y - oy
            guard sy >= 0, sy < h else { continue }
            for x in 0 ..< dw {
                let sx = x - ox
                guard sx >= 0, sx < w else { continue }
                for c in 0 ..< 4 { out[(y * dw + x) * 4 + c] = scaled[(sy * w + sx) * 4 + c] }
            }
        }
    } else {
        out = _vtScale(src, sw, sh, to: dw, dh)
    }
    _vtWrite(out, width: dw, height: dh, into: destinationBuffer)
    return noErr
}
public func VTPixelTransferSessionInvalidate(_ session: VTPixelTransferSession) { session.invalid = true }

// MARK: - images

@discardableResult public func VTCreateCGImageFromCVPixelBuffer(_ pixelBuffer: CVPixelBuffer, options: CFDictionary?, imageOut: UnsafeMutablePointer<CGImage?>) -> OSStatus {
    let w = pixelBuffer._width, h = pixelBuffer._height
    guard w > 0, h > 0, let provider = CGDataProvider(data: Data(pixelBuffer._bgra()) as CFData) else { return kVTParameterErr }
    imageOut.pointee = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    return imageOut.pointee == nil ? kVTParameterErr : noErr
}
