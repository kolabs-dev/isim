// isim CoreMedia sample buffers (self-authored, iOS API names): CMSampleBuffer, CMFormatDescription and CMBlockBuffer
// as delivered by isim's capture outputs and AVAssetReader and accepted by AVAssetWriter. A sample buffer holds one
// decoded video frame (a CVPixelBuffer), a run of interleaved linear-PCM audio frames, or compressed samples (H.264,
// HEVC, AAC, ... in a block buffer, with per-sample sizes, timing and attachments; the format description carries
// the codec's configuration atoms / magic cookie). Block buffers copy the memory they are given (adapted).
// Clocks and timebases: Clock.swift.
@_exported import CoreVideo
import AudioToolbox

public typealias CMItemCount = Int
public typealias FourCharCode = UInt32
public typealias CMMediaType = FourCharCode
public let kCMMediaType_Video: CMMediaType = 0x7669_6465     // 'vide'
public let kCMMediaType_Audio: CMMediaType = 0x736F_756E     // 'soun'
public let kCMMediaType_Metadata: CMMediaType = 0x6D65_7461  // 'meta'
public let noErr: OSStatus = 0
public let kCMSampleBufferError_InvalidMediaFormat: OSStatus = -12743
public let kCMSampleBufferError_RequiredParameterMissing: OSStatus = -12731
public let kCMSampleBufferError_ArrayTooSmall: OSStatus = -12737
public let kCMBlockBufferBadOffsetParameterErr: OSStatus = -12703
public let kCMBlockBufferBadLengthParameterErr: OSStatus = -12704
public let kCMFormatDescriptionError_InvalidParameter: OSStatus = -12710
public let kCMSampleBufferError_BufferHasNoSampleSizes: OSStatus = -12735
public let kCMSampleBufferError_BufferHasNoSampleTimingInfo: OSStatus = -12736
public let kCMBlockBufferStructureAllocationFailedErr: OSStatus = -12700
public let kCMFormatDescriptionBridgeError_InvalidParameter: OSStatus = -12712
public typealias CMVideoCodecType = FourCharCode
public let kCMVideoCodecType_H264: CMVideoCodecType = 0x6176_6331           // 'avc1'
public let kCMVideoCodecType_HEVC: CMVideoCodecType = 0x6876_6331           // 'hvc1'
public let kCMVideoCodecType_HEVCWithAlpha: CMVideoCodecType = 0x6D75_7861  // 'muxa'
public let kCMVideoCodecType_JPEG: CMVideoCodecType = 0x6A70_6567           // 'jpeg'
public let kCMVideoCodecType_MPEG4Video: CMVideoCodecType = 0x6D70_3476     // 'mp4v'
public let kCMVideoCodecType_AppleProRes422: CMVideoCodecType = 0x6170_636E // 'apcn'
public let kCMVideoCodecType_AppleProRes4444: CMVideoCodecType = 0x6170_3468 // 'ap4h'
public let kCMVideoCodecType_VP9: CMVideoCodecType = 0x7670_3039            // 'vp09'
public let kCMVideoCodecType_AV1: CMVideoCodecType = 0x6176_3031            // 'av01'
public let kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms = "SampleDescriptionExtensionAtoms" as CFString
public let kCMFormatDescriptionExtension_FormatName = "FormatName" as CFString
public let kCMFormatDescriptionExtension_Depth = "Depth" as CFString
public let kCMSampleAttachmentKey_NotSync = "NotSync" as CFString
public let kCMSampleAttachmentKey_PartialSync = "PartialSync" as CFString
public let kCMSampleAttachmentKey_DependsOnOthers = "DependsOnOthers" as CFString
public let kCMSampleAttachmentKey_IsDependedOnByOthers = "IsDependedOnByOthers" as CFString
public let kCMSampleAttachmentKey_DisplayImmediately = "DisplayImmediately" as CFString
public let kCMSampleAttachmentKey_DoNotDisplay = "DoNotDisplay" as CFString
public let kCMSampleBufferAttachmentKey_ResetDecoderBeforeDecoding = "ResetDecoderBeforeDecoding" as CFString
public let kCMSampleBufferAttachmentKey_TrimDurationAtStart = "TrimDurationAtStart" as CFString
public typealias CMAttachmentMode = UInt32
public let kCMAttachmentMode_ShouldNotPropagate: CMAttachmentMode = 0
public let kCMAttachmentMode_ShouldPropagate: CMAttachmentMode = 1
public typealias CMBlockBufferFlags = UInt32
public let kCMBlockBufferAssureMemoryNowFlag: CMBlockBufferFlags = 1
public let kCMBlockBufferAlwaysCopyDataFlag: CMBlockBufferFlags = 2

public struct CMVideoDimensions: Equatable, Sendable {
    public var width: Int32
    public var height: Int32
    public init(width: Int32, height: Int32) { self.width = width; self.height = height }
}
public struct CMSampleTimingInfo: Sendable {
    public var duration: CMTime
    public var presentationTimeStamp: CMTime
    public var decodeTimeStamp: CMTime
    public init(duration: CMTime, presentationTimeStamp: CMTime, decodeTimeStamp: CMTime) {
        self.duration = duration; self.presentationTimeStamp = presentationTimeStamp; self.decodeTimeStamp = decodeTimeStamp
    }
    public static let invalid = CMSampleTimingInfo(duration: .invalid, presentationTimeStamp: .invalid, decodeTimeStamp: .invalid)
}

public final class CMFormatDescription: @unchecked Sendable, Hashable {
    public static func == (a: CMFormatDescription, b: CMFormatDescription) -> Bool {
        a.mediaType == b.mediaType && a.mediaSubType == b.mediaSubType && a._dimensions == b._dimensions && a._asbd == b._asbd
    }
    public func hash(into h: inout Hasher) { h.combine(mediaType); h.combine(mediaSubType) }
    public let mediaType: CMMediaType
    public let mediaSubType: FourCharCode
    let _dimensions: CMVideoDimensions
    var _asbd: AudioStreamBasicDescription
    /// isim: format description extensions (kCMFormatDescriptionExtension_*), e.g. the codec configuration atoms
    public var _extensions: [String: Any] = [:]
    /// isim: an audio codec's magic cookie (AAC: the esds payload)
    public var _cookie: [UInt8]?
    /// isim: a compressed video format (codec four-char code, coded size, extensions)
    public init(_codec codec: FourCharCode, width w: Int, height h: Int, extensions: [String: Any]) {
        mediaType = kCMMediaType_Video; mediaSubType = codec; _dimensions = CMVideoDimensions(width: Int32(w), height: Int32(h)); _asbd = AudioStreamBasicDescription()
        _extensions = extensions
    }
    /// isim: the configuration atom of a compressed video format ("avcC", "hvcC", ...)
    public func _atom(_ name: String) -> [UInt8]? {
        guard let atoms = _extensions[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] as? [String: Any] else { return nil }
        if let d = atoms[name] as? Data { return Array(d) }
        if let d = atoms[name] as? [UInt8] { return d }
        return nil
    }
    public init(_video w: Int, height h: Int, pixelFormat: OSType) {
        mediaType = kCMMediaType_Video; mediaSubType = pixelFormat; _dimensions = CMVideoDimensions(width: Int32(w), height: Int32(h)); _asbd = AudioStreamBasicDescription()
    }
    public init(_audio asbd: AudioStreamBasicDescription) {
        mediaType = kCMMediaType_Audio; mediaSubType = asbd.mFormatID; _dimensions = CMVideoDimensions(width: 0, height: 0); _asbd = asbd
    }
    public var dimensions: CMVideoDimensions { _dimensions }
    public var audioStreamBasicDescription: AudioStreamBasicDescription? { mediaType == kCMMediaType_Audio ? _asbd : nil }
}
public typealias CMVideoFormatDescription = CMFormatDescription
public typealias CMAudioFormatDescription = CMFormatDescription

public final class CMBlockBuffer: @unchecked Sendable {
    public var _bytes: [UInt8]
    public init(_bytes: [UInt8]) { self._bytes = _bytes }
    public var dataLength: Int { _bytes.count }
    public var isEmpty: Bool { _bytes.isEmpty }
}

public final class CMSampleBuffer: @unchecked Sendable {
    public let _imageBuffer: CVImageBuffer?
    public let _block: CMBlockBuffer?
    public let _format: CMFormatDescription?
    public let _numSamples: Int
    public var _timing: CMSampleTimingInfo
    public var _attachments: [String: Any] = [:]
    /// isim: compressed samples: the size and timing of each sample in the block buffer, and their attachments
    public var _sizes: [Int] = []
    public var _timings: [CMSampleTimingInfo] = []
    public var _sampleAttachments: [NSMutableDictionary] = []
    public var _ready = true
    /// isim: compressed (or other) samples in a block buffer
    public init(_block block: CMBlockBuffer?, format: CMFormatDescription?, count: Int, timings: [CMSampleTimingInfo], sizes: [Int]) {
        _imageBuffer = nil; _block = block; _format = format; _numSamples = count
        _timings = timings; _sizes = sizes
        if timings.count == 1 && count > 1, timings[0].duration.isNumeric {
            // one timing entry for several samples: each sample lasts the entry's duration
            _timing = CMSampleTimingInfo(duration: CMTimeMultiply(timings[0].duration, multiplier: Int32(count)), presentationTimeStamp: timings[0].presentationTimeStamp,
                                         decodeTimeStamp: timings[0].decodeTimeStamp)
        } else if let first = timings.first {
            let total = timings.reduce(CMTime.zero) { $1.duration.isNumeric ? $0 + $1.duration : $0 }
            let pts = timings.map(\.presentationTimeStamp).filter(\.isNumeric).min() ?? first.presentationTimeStamp
            _timing = CMSampleTimingInfo(duration: total, presentationTimeStamp: pts, decodeTimeStamp: first.decodeTimeStamp)
        } else { _timing = .invalid }
    }
    /// the bytes of sample `i` within the block buffer
    public func _sampleRange(_ i: Int) -> Range<Int>? {
        guard let b = _block else { return nil }
        if _sizes.count == 1 && _numSamples > 1 { let s = _sizes[0]; return i * s..<min(b.dataLength, (i + 1) * s) }
        guard i < _sizes.count else { return i == 0 && _sizes.isEmpty ? 0..<b.dataLength : nil }
        let start = _sizes[0..<i].reduce(0, +)
        return start..<min(b.dataLength, start + _sizes[i])
    }
    /// isim: a video frame
    public init(_imageBuffer b: CVImageBuffer, presentationTime: CMTime, duration: CMTime) {
        _imageBuffer = b; _block = nil; _numSamples = 1
        _format = CMFormatDescription(_video: b._width, height: b._height, pixelFormat: b._format)
        _timing = CMSampleTimingInfo(duration: duration, presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
    }
    /// isim: interleaved linear PCM described by asbd (frames = bytes / bytesPerFrame)
    public init(_audio bytes: [UInt8], format asbd: AudioStreamBasicDescription, presentationTime: CMTime) {
        _imageBuffer = nil; _block = CMBlockBuffer(_bytes: bytes)
        _format = CMFormatDescription(_audio: asbd)
        let frames = asbd._frameBytes > 0 ? bytes.count / asbd._frameBytes : 0
        _numSamples = frames
        _timing = CMSampleTimingInfo(duration: CMTime(value: Int64(frames), timescale: Int32(asbd.mSampleRate.rounded())), presentationTimeStamp: presentationTime, decodeTimeStamp: .invalid)
    }
    public var imageBuffer: CVImageBuffer? { _imageBuffer }
    public var presentationTimeStamp: CMTime { _timing.presentationTimeStamp }
    public var outputPresentationTimeStamp: CMTime { _timing.presentationTimeStamp }
    public var decodeTimeStamp: CMTime { _timing.decodeTimeStamp }
    public var duration: CMTime { _timing.duration }
    public var outputDuration: CMTime { _timing.duration }
    public var numSamples: CMItemCount { _numSamples }
    public var formatDescription: CMFormatDescription? { _format }
    public var dataBuffer: CMBlockBuffer? { _block }
    public var totalSampleSize: Int { _block?.dataLength ?? 0 }
    public var isValid: Bool { true }
    public var dataReadiness: Bool { _ready }
    public var dataIsReady: Bool { _ready }
    public var sampleSize: Int { totalSampleSize }
    public func sampleTimingInfos() throws -> [CMSampleTimingInfo] { _timings.isEmpty ? [_timing] : _timings }
    public func sampleSize(at index: Int) -> Int { _sampleRange(index)?.count ?? 0 }
}

// MARK: - C-style functions
@discardableResult
public func CMSampleBufferCreate(allocator: CFAllocator?, dataBuffer: CMBlockBuffer?, dataReady: Bool, makeDataReadyCallback: Any?, refcon: UnsafeMutableRawPointer?,
                                 formatDescription: CMFormatDescription?, sampleCount: CMItemCount, sampleTimingEntryCount: CMItemCount,
                                 sampleTimingArray: UnsafePointer<CMSampleTimingInfo>?, sampleSizeEntryCount: CMItemCount, sampleSizeArray: UnsafePointer<Int>?,
                                 sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    let timings = sampleTimingArray.map { Array(UnsafeBufferPointer(start: $0, count: sampleTimingEntryCount)) } ?? []
    let sizes = sampleSizeArray.map { Array(UnsafeBufferPointer(start: $0, count: sampleSizeEntryCount)) } ?? []
    if let f = formatDescription, f.mediaType == kCMMediaType_Audio, f._asbd._isPCM, let b = dataBuffer {
        // linear PCM: frames, like the isim audio sample buffers
        let sb = CMSampleBuffer(_audio: b._bytes, format: f._asbd, presentationTime: timings.first?.presentationTimeStamp ?? .zero)
        sampleBufferOut.pointee = sb
        return noErr
    }
    let sb = CMSampleBuffer(_block: dataBuffer, format: formatDescription, count: sampleCount, timings: timings, sizes: sizes)
    sb._ready = dataReady
    sampleBufferOut.pointee = sb
    return noErr
}
@discardableResult
public func CMSampleBufferCreateReady(allocator: CFAllocator?, dataBuffer: CMBlockBuffer?, formatDescription: CMFormatDescription?, sampleCount: CMItemCount,
                                      sampleTimingEntryCount: CMItemCount, sampleTimingArray: UnsafePointer<CMSampleTimingInfo>?, sampleSizeEntryCount: CMItemCount,
                                      sampleSizeArray: UnsafePointer<Int>?, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    CMSampleBufferCreate(allocator: allocator, dataBuffer: dataBuffer, dataReady: true, makeDataReadyCallback: nil, refcon: nil, formatDescription: formatDescription,
                         sampleCount: sampleCount, sampleTimingEntryCount: sampleTimingEntryCount, sampleTimingArray: sampleTimingArray,
                         sampleSizeEntryCount: sampleSizeEntryCount, sampleSizeArray: sampleSizeArray, sampleBufferOut: sampleBufferOut)
}
@discardableResult public func CMSampleBufferSetDataReady(_ sbuf: CMSampleBuffer) -> OSStatus { sbuf._ready = true; return noErr }
@discardableResult public func CMSampleBufferMakeDataReady(_ sbuf: CMSampleBuffer) -> OSStatus { sbuf._ready = true; return noErr }
@discardableResult
public func CMSampleBufferSetDataBuffer(_ sbuf: CMSampleBuffer, newValue dataBuffer: CMBlockBuffer) -> OSStatus {
    if let b = sbuf._block { b._bytes = dataBuffer._bytes; return noErr }
    return kCMSampleBufferError_RequiredParameterMissing
}
public func CMSampleBufferGetSampleSize(_ sbuf: CMSampleBuffer, at sampleIndex: CMItemCount) -> Int { sbuf.sampleSize(at: sampleIndex) }
@discardableResult
public func CMSampleBufferGetSampleSizeArray(_ sbuf: CMSampleBuffer, entryCount: CMItemCount, arrayToFill: UnsafeMutablePointer<Int>?, entriesNeededOut: UnsafeMutablePointer<CMItemCount>?) -> OSStatus {
    let sizes = sbuf._sizes.isEmpty ? (sbuf.imageBuffer == nil ? [sbuf.totalSampleSize] : []) : sbuf._sizes
    entriesNeededOut?.pointee = sizes.count
    if sizes.isEmpty { return kCMSampleBufferError_BufferHasNoSampleSizes }
    guard let a = arrayToFill else { return noErr }
    guard entryCount >= sizes.count else { return kCMSampleBufferError_ArrayTooSmall }
    for (i, v) in sizes.enumerated() { a[i] = v }
    return noErr
}
@discardableResult
public func CMSampleBufferGetSampleTimingInfoArray(_ sbuf: CMSampleBuffer, entryCount: CMItemCount, arrayToFill: UnsafeMutablePointer<CMSampleTimingInfo>?,
                                                   entriesNeededOut: UnsafeMutablePointer<CMItemCount>?) -> OSStatus {
    let t = sbuf._timings.isEmpty ? [sbuf._timing] : sbuf._timings
    entriesNeededOut?.pointee = t.count
    guard let a = arrayToFill else { return noErr }
    guard entryCount >= t.count else { return kCMSampleBufferError_ArrayTooSmall }
    for (i, v) in t.enumerated() { a[i] = v }
    return noErr
}
/// the per-sample attachment dictionaries (mutable, like iOS's), created on request
public func CMSampleBufferGetSampleAttachmentsArray(_ sbuf: CMSampleBuffer, createIfNecessary: Bool) -> CFArray? {
    if sbuf._sampleAttachments.isEmpty {
        guard createIfNecessary else { return nil }
        sbuf._sampleAttachments = (0..<max(1, sbuf._numSamples)).map { _ in NSMutableDictionary() }
    }
    return sbuf._sampleAttachments as NSArray as CFArray
}
/// isim: whether sample `i` is a sync sample (no kCMSampleAttachmentKey_NotSync)
public func _isimSampleIsSync(_ sbuf: CMSampleBuffer, _ i: Int) -> Bool {
    guard i < sbuf._sampleAttachments.count else { return true }
    return (sbuf._sampleAttachments[i][kCMSampleAttachmentKey_NotSync as String] as? Bool) != true
}
// attachments (CMAttachmentBearer) of sample buffers and pixel buffers
public func CMSetAttachment(_ target: AnyObject, key: CFString, value: AnyObject?, attachmentMode: CMAttachmentMode) {
    if let s = target as? CMSampleBuffer { s._attachments[key as String] = value }
    else if let b = target as? CVBuffer { b._attachments[key as String] = value }
}
public func CMGetAttachment(_ target: AnyObject, key: CFString, attachmentModeOut: UnsafeMutablePointer<CMAttachmentMode>?) -> AnyObject? {
    attachmentModeOut?.pointee = kCMAttachmentMode_ShouldPropagate
    if let s = target as? CMSampleBuffer { return s._attachments[key as String] as AnyObject? }
    if let b = target as? CVBuffer { return b._attachments[key as String] as AnyObject? }
    return nil
}
public func CMRemoveAttachment(_ target: AnyObject, key: CFString) {
    if let s = target as? CMSampleBuffer { s._attachments[key as String] = nil } else if let b = target as? CVBuffer { b._attachments[key as String] = nil }
}
public func CMRemoveAllAttachments(_ target: AnyObject) {
    if let s = target as? CMSampleBuffer { s._attachments = [:] } else if let b = target as? CVBuffer { b._attachments = [:] }
}
public func CMCopyDictionaryOfAttachments(allocator: CFAllocator?, target: AnyObject, attachmentMode: CMAttachmentMode) -> CFDictionary? {
    if let s = target as? CMSampleBuffer { return s._attachments as NSDictionary as CFDictionary }
    if let b = target as? CVBuffer { return b._attachments as NSDictionary as CFDictionary }
    return nil
}
public func CMSampleBufferGetImageBuffer(_ sbuf: CMSampleBuffer) -> CVImageBuffer? { sbuf._imageBuffer }
public func CMSampleBufferGetPresentationTimeStamp(_ sbuf: CMSampleBuffer) -> CMTime { sbuf.presentationTimeStamp }
public func CMSampleBufferGetOutputPresentationTimeStamp(_ sbuf: CMSampleBuffer) -> CMTime { sbuf.presentationTimeStamp }
public func CMSampleBufferGetDecodeTimeStamp(_ sbuf: CMSampleBuffer) -> CMTime { sbuf.decodeTimeStamp }
public func CMSampleBufferGetDuration(_ sbuf: CMSampleBuffer) -> CMTime { sbuf.duration }
public func CMSampleBufferGetNumSamples(_ sbuf: CMSampleBuffer) -> CMItemCount { sbuf.numSamples }
public func CMSampleBufferGetFormatDescription(_ sbuf: CMSampleBuffer) -> CMFormatDescription? { sbuf._format }
public func CMSampleBufferGetDataBuffer(_ sbuf: CMSampleBuffer) -> CMBlockBuffer? { sbuf._block }
public func CMSampleBufferGetTotalSampleSize(_ sbuf: CMSampleBuffer) -> Int { sbuf.totalSampleSize }
public func CMSampleBufferIsValid(_ sbuf: CMSampleBuffer) -> Bool { true }
public func CMSampleBufferDataIsReady(_ sbuf: CMSampleBuffer) -> Bool { true }
@discardableResult public func CMSampleBufferInvalidate(_ sbuf: CMSampleBuffer) -> OSStatus { noErr }
@discardableResult public func CMSampleBufferGetSampleTimingInfo(_ sbuf: CMSampleBuffer, at index: CMItemCount, timingInfoOut: UnsafeMutablePointer<CMSampleTimingInfo>) -> OSStatus {
    timingInfoOut.pointee = sbuf._timing; return noErr
}
/// Copies interleaved PCM frames into the buffer list (one interleaved buffer, or one buffer per channel).
@discardableResult public func CMSampleBufferCopyPCMDataIntoAudioBufferList(_ sbuf: CMSampleBuffer, at frameOffset: Int32, frameCount: Int32,
                                                        into bufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
    guard let asbd = sbuf._format?._asbd, let block = sbuf._block, asbd._isPCM else { return kCMSampleBufferError_InvalidMediaFormat }
    let fb = asbd._frameBytes, ch = Int(max(1, asbd.mChannelsPerFrame)), bs = asbd._bytesPerSample
    guard frameOffset >= 0, Int(frameOffset + frameCount) <= sbuf._numSamples else { return kCMSampleBufferError_ArrayTooSmall }
    let list = UnsafeMutableAudioBufferListPointer(bufferList)
    block._bytes.withUnsafeBytes { src in
        if list.count == 1 {
            guard let d = list[0].mData else { return }
            let n = min(Int(frameCount) * fb, Int(list[0].mDataByteSize))
            d.copyMemory(from: src.baseAddress! + Int(frameOffset) * fb, byteCount: n)
            list[0].mDataByteSize = UInt32(n)
        } else {
            for c in 0..<min(ch, list.count) {
                guard let d = list[c].mData else { continue }
                let n = min(Int(frameCount), Int(list[c].mDataByteSize) / bs)
                for f in 0..<n { (d + f * bs).copyMemory(from: src.baseAddress! + (Int(frameOffset) + f) * fb + c * bs, byteCount: bs) }
                list[c].mDataByteSize = UInt32(n * bs)
            }
        }
    }
    return noErr
}
@discardableResult public func CMSampleBufferCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, dataReady: Bool,
                                               makeDataReadyCallback: Any?, refcon: UnsafeMutableRawPointer?, formatDescription: CMVideoFormatDescription,
                                               sampleTiming: UnsafePointer<CMSampleTimingInfo>, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(_imageBuffer: imageBuffer, presentationTime: sampleTiming.pointee.presentationTimeStamp, duration: sampleTiming.pointee.duration)
    return noErr
}
@discardableResult public func CMSampleBufferCreateReadyWithImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, formatDescription: CMVideoFormatDescription,
                                                     sampleTiming: UnsafePointer<CMSampleTimingInfo>, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(_imageBuffer: imageBuffer, presentationTime: sampleTiming.pointee.presentationTimeStamp, duration: sampleTiming.pointee.duration)
    return noErr
}
@discardableResult public func CMVideoFormatDescriptionCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer,
                                                         formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    formatDescriptionOut.pointee = CMFormatDescription(_video: imageBuffer._width, height: imageBuffer._height, pixelFormat: imageBuffer._format)
    return noErr
}
@discardableResult public func CMAudioFormatDescriptionCreate(allocator: CFAllocator?, asbd: UnsafePointer<AudioStreamBasicDescription>, layoutSize: Int, layout: UnsafeRawPointer?,
                                           magicCookieSize: Int, magicCookie: UnsafeRawPointer?, extensions: CFDictionary?,
                                           formatDescriptionOut: UnsafeMutablePointer<CMAudioFormatDescription?>) -> OSStatus {
    let f = CMFormatDescription(_audio: asbd.pointee)
    if let c = magicCookie, magicCookieSize > 0 { f._cookie = Array(UnsafeRawBufferPointer(start: c, count: magicCookieSize)) }
    f._extensions = (extensions as NSDictionary?) as? [String: Any] ?? [:]
    formatDescriptionOut.pointee = f
    return noErr
}
public func CMFormatDescriptionGetMediaType(_ desc: CMFormatDescription) -> CMMediaType { desc.mediaType }
public func CMFormatDescriptionGetExtensions(_ desc: CMFormatDescription) -> CFDictionary? { desc._extensions.isEmpty ? nil : desc._extensions as NSDictionary as CFDictionary }
public func CMFormatDescriptionGetExtension(_ desc: CMFormatDescription, extensionKey: CFString) -> AnyObject? { desc._extensions[extensionKey as String] as AnyObject? }
public func CMFormatDescriptionEqual(_ a: CMFormatDescription?, otherFormatDescription b: CMFormatDescription?) -> Bool { a == b }
@discardableResult
public func CMFormatDescriptionCreate(allocator: CFAllocator?, mediaType: CMMediaType, mediaSubType: FourCharCode, extensions: CFDictionary?,
                                      formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
    let ext = (extensions as NSDictionary?) as? [String: Any] ?? [:]
    if mediaType == kCMMediaType_Video { formatDescriptionOut.pointee = CMFormatDescription(_codec: mediaSubType, width: 0, height: 0, extensions: ext) }
    else {
        var asbd = AudioStreamBasicDescription(); asbd.mFormatID = mediaSubType
        let f = CMFormatDescription(_audio: asbd); f._extensions = ext
        formatDescriptionOut.pointee = f
    }
    return noErr
}
@discardableResult
public func CMVideoFormatDescriptionCreate(allocator: CFAllocator?, codecType: CMVideoCodecType, width: Int32, height: Int32, extensions: CFDictionary?,
                                           formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    formatDescriptionOut.pointee = CMFormatDescription(_codec: codecType, width: Int(width), height: Int(height), extensions: (extensions as NSDictionary?) as? [String: Any] ?? [:])
    return noErr
}
public func CMVideoFormatDescriptionGetCodecType(_ desc: CMVideoFormatDescription) -> CMVideoCodecType { desc.mediaSubType }
/// An H.264 format from its SPS and PPS: the avcC configuration record is built from them (size from the SPS).
@discardableResult
public func CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: CFAllocator?, parameterSetCount: Int, parameterSetPointers: UnsafePointer<UnsafePointer<UInt8>>,
                                                                parameterSetSizes: UnsafePointer<Int>, nalUnitHeaderLength: Int32,
                                                                formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
    let sets = (0..<parameterSetCount).map { Array(UnsafeBufferPointer(start: parameterSetPointers[$0], count: parameterSetSizes[$0])) }
    let sps = sets.filter { ($0.first ?? 0) & 0x1f == 7 }, pps = sets.filter { ($0.first ?? 0) & 0x1f == 8 }
    guard let s0 = sps.first, s0.count >= 4, !pps.isEmpty, [1, 2, 4].contains(nalUnitHeaderLength) else { return kCMFormatDescriptionError_InvalidParameter }
    var avcc: [UInt8] = [1, s0[1], s0[2], s0[3], 0xfc | UInt8(nalUnitHeaderLength - 1), 0xe0 | UInt8(sps.count)]
    for p in sps { avcc += [UInt8(p.count >> 8), UInt8(p.count & 255)] + p }
    avcc.append(UInt8(pps.count))
    for p in pps { avcc += [UInt8(p.count >> 8), UInt8(p.count & 255)] + p }
    let (w, h) = _H26x.spsSize(s0, hevc: false)
    formatDescriptionOut.pointee = CMFormatDescription(_codec: kCMVideoCodecType_H264, width: w, height: h,
        extensions: [kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String: ["avcC": Data(avcc)]])
    return noErr
}
@discardableResult
public func CMVideoFormatDescriptionGetH264ParameterSetAtIndex(_ desc: CMFormatDescription, parameterSetIndex: Int, parameterSetPointerOut: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
                                                               parameterSetSizeOut: UnsafeMutablePointer<Int>?, parameterSetCountOut: UnsafeMutablePointer<Int>?,
                                                               nalUnitHeaderLengthOut: UnsafeMutablePointer<Int32>?) -> OSStatus {
    guard let avcc = desc._atom("avcC") else { return kCMFormatDescriptionBridgeError_InvalidParameter }
    let sets = _H26x.avccSets(avcc)
    parameterSetCountOut?.pointee = sets.count
    nalUnitHeaderLengthOut?.pointee = Int32((avcc.count > 4 ? avcc[4] & 3 : 3) + 1)
    if parameterSetPointerOut != nil || parameterSetSizeOut != nil {
        guard parameterSetIndex < sets.count else { return kCMFormatDescriptionBridgeError_InvalidParameter }
        parameterSetSizeOut?.pointee = sets[parameterSetIndex].count
        parameterSetPointerOut?.pointee = desc._keep(sets[parameterSetIndex])
    }
    return noErr
}
@discardableResult
public func CMVideoFormatDescriptionCreateFromHEVCParameterSets(allocator: CFAllocator?, parameterSetCount: Int, parameterSetPointers: UnsafePointer<UnsafePointer<UInt8>>,
                                                                parameterSetSizes: UnsafePointer<Int>, nalUnitHeaderLength: Int32, extensions: CFDictionary?,
                                                                formatDescriptionOut: UnsafeMutablePointer<CMFormatDescription?>) -> OSStatus {
    let sets = (0..<parameterSetCount).map { Array(UnsafeBufferPointer(start: parameterSetPointers[$0], count: parameterSetSizes[$0])) }
    let types: [UInt8] = [32, 33, 34]                             // VPS, SPS, PPS
    let groups = types.map { t in sets.filter { (($0.first ?? 0) >> 1) & 0x3f == t } }
    guard let sps = groups[1].first, sps.count > 14 else { return kCMFormatDescriptionError_InvalidParameter }
    var hvcc = [UInt8](repeating: 0, count: 23)
    hvcc[0] = 1
    // general profile_tier_level (12 bytes) from the SPS (after the 2-byte NAL header and 1 byte of ids)
    let ptl = _H26x.unescape(Array(sps[2...]))
    for i in 0..<12 where i + 1 < ptl.count { hvcc[1 + i] = ptl[1 + i] }
    hvcc[13] = 0xf0; hvcc[14] = 0; hvcc[15] = 0xfc; hvcc[16] = 0xfd; hvcc[17] = 0xf8; hvcc[18] = 0xf8; hvcc[19] = 0; hvcc[20] = 0
    hvcc[21] = 0x0f | UInt8((nalUnitHeaderLength - 1) & 3)
    hvcc[22] = UInt8(groups.filter { !$0.isEmpty }.count)
    for (t, g) in zip(types, groups) where !g.isEmpty {
        hvcc += [0x80 | t, UInt8(g.count >> 8), UInt8(g.count & 255)]
        for p in g { hvcc += [UInt8(p.count >> 8), UInt8(p.count & 255)] + p }
    }
    let (w, h) = _H26x.spsSize(sps, hevc: true)
    var ext = (extensions as NSDictionary?) as? [String: Any] ?? [:]
    ext[kCMFormatDescriptionExtension_SampleDescriptionExtensionAtoms as String] = ["hvcC": Data(hvcc)]
    formatDescriptionOut.pointee = CMFormatDescription(_codec: kCMVideoCodecType_HEVC, width: w, height: h, extensions: ext)
    return noErr
}
@discardableResult
public func CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(_ desc: CMFormatDescription, parameterSetIndex: Int, parameterSetPointerOut: UnsafeMutablePointer<UnsafePointer<UInt8>?>?,
                                                               parameterSetSizeOut: UnsafeMutablePointer<Int>?, parameterSetCountOut: UnsafeMutablePointer<Int>?,
                                                               nalUnitHeaderLengthOut: UnsafeMutablePointer<Int32>?) -> OSStatus {
    guard let hvcc = desc._atom("hvcC") else { return kCMFormatDescriptionBridgeError_InvalidParameter }
    let sets = _H26x.hvccSets(hvcc)
    parameterSetCountOut?.pointee = sets.count
    nalUnitHeaderLengthOut?.pointee = Int32((hvcc.count > 21 ? hvcc[21] & 3 : 3) + 1)
    if parameterSetPointerOut != nil || parameterSetSizeOut != nil {
        guard parameterSetIndex < sets.count else { return kCMFormatDescriptionBridgeError_InvalidParameter }
        parameterSetSizeOut?.pointee = sets[parameterSetIndex].count
        parameterSetPointerOut?.pointee = desc._keep(sets[parameterSetIndex])
    }
    return noErr
}
public func CMAudioFormatDescriptionGetMagicCookie(_ desc: CMAudioFormatDescription, sizeOut: UnsafeMutablePointer<Int>?) -> UnsafeRawPointer? {
    guard let c = desc._cookie, !c.isEmpty else { sizeOut?.pointee = 0; return nil }
    sizeOut?.pointee = c.count
    return UnsafeRawPointer(desc._keep(c))
}
public func CMFormatDescriptionGetMediaSubType(_ desc: CMFormatDescription) -> FourCharCode { desc.mediaSubType }
public func CMVideoFormatDescriptionGetDimensions(_ desc: CMVideoFormatDescription) -> CMVideoDimensions { desc._dimensions }
public func CMAudioFormatDescriptionGetStreamBasicDescription(_ desc: CMAudioFormatDescription) -> UnsafePointer<AudioStreamBasicDescription>? {
    guard desc.mediaType == kCMMediaType_Audio else { return nil }
    return withUnsafePointer(to: &desc._asbd) { $0 }     // stable: a stored property of a class instance
}
public func CMBlockBufferGetDataLength(_ b: CMBlockBuffer) -> Int { b._bytes.count }
/// isim: the memory is copied (a block buffer owns its bytes); a nil memoryBlock gives zeroed bytes
@discardableResult
public func CMBlockBufferCreateWithMemoryBlock(allocator: CFAllocator?, memoryBlock: UnsafeMutableRawPointer?, blockLength: Int, blockAllocator: CFAllocator?,
                                               customBlockSource: UnsafePointer<Any>?, offsetToData: Int, dataLength: Int, flags: CMBlockBufferFlags,
                                               blockBufferOut: UnsafeMutablePointer<CMBlockBuffer?>) -> OSStatus {
    guard offsetToData >= 0, dataLength >= 0, offsetToData + dataLength <= blockLength else { return kCMBlockBufferBadLengthParameterErr }
    let bytes = memoryBlock.map { Array(UnsafeRawBufferPointer(start: $0 + offsetToData, count: dataLength)) } ?? [UInt8](repeating: 0, count: dataLength)
    blockBufferOut.pointee = CMBlockBuffer(_bytes: bytes)
    return noErr
}
@discardableResult
public func CMBlockBufferCreateEmpty(allocator: CFAllocator?, capacity subBlockCapacity: UInt32, flags: CMBlockBufferFlags, blockBufferOut: UnsafeMutablePointer<CMBlockBuffer?>) -> OSStatus {
    blockBufferOut.pointee = CMBlockBuffer(_bytes: []); return noErr
}
@discardableResult
public func CMBlockBufferAppendMemoryBlock(_ b: CMBlockBuffer, memoryBlock: UnsafeMutableRawPointer?, length: Int, blockAllocator: CFAllocator?,
                                           customBlockSource: UnsafePointer<Any>?, offsetToData: Int, dataLength: Int, flags: CMBlockBufferFlags) -> OSStatus {
    b._bytes += memoryBlock.map { Array(UnsafeRawBufferPointer(start: $0 + offsetToData, count: dataLength)) } ?? [UInt8](repeating: 0, count: dataLength)
    return noErr
}
@discardableResult
public func CMBlockBufferAppendBufferReference(_ b: CMBlockBuffer, targetBBuf: CMBlockBuffer, offsetToData: Int, dataLength: Int, flags: CMBlockBufferFlags) -> OSStatus {
    let n = dataLength == 0 ? targetBBuf._bytes.count - offsetToData : dataLength
    guard offsetToData >= 0, n >= 0, offsetToData + n <= targetBBuf._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    b._bytes += targetBBuf._bytes[offsetToData..<(offsetToData + n)]
    return noErr
}
@discardableResult
public func CMBlockBufferReplaceDataBytes(with sourceBytes: UnsafeRawPointer, blockBuffer: CMBlockBuffer, offsetIntoDestination: Int, dataLength: Int) -> OSStatus {
    guard offsetIntoDestination >= 0, offsetIntoDestination + dataLength <= blockBuffer._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    blockBuffer._bytes.withUnsafeMutableBytes { ($0.baseAddress! + offsetIntoDestination).copyMemory(from: sourceBytes, byteCount: dataLength) }
    return noErr
}
@discardableResult
public func CMBlockBufferFillDataBytes(with fillByte: CChar, blockBuffer: CMBlockBuffer, offsetIntoDestination: Int, dataLength: Int) -> OSStatus {
    guard offsetIntoDestination >= 0, offsetIntoDestination + dataLength <= blockBuffer._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    for i in offsetIntoDestination..<(offsetIntoDestination + dataLength) { blockBuffer._bytes[i] = UInt8(bitPattern: fillByte) }
    return noErr
}
@discardableResult
public func CMBlockBufferAssureBlockMemory(_ b: CMBlockBuffer) -> OSStatus { noErr }
public func CMBlockBufferIsRangeContiguous(_ b: CMBlockBuffer, atOffset offset: Int, length: Int) -> Bool { true }
@discardableResult
public func CMBlockBufferCreateContiguous(allocator: CFAllocator?, sourceBuffer: CMBlockBuffer, blockAllocator: CFAllocator?, customBlockSource: UnsafePointer<Any>?,
                                          offsetToData: Int, dataLength: Int, flags: CMBlockBufferFlags, blockBufferOut: UnsafeMutablePointer<CMBlockBuffer?>) -> OSStatus {
    let n = dataLength == 0 ? sourceBuffer._bytes.count - offsetToData : dataLength
    guard offsetToData >= 0, n >= 0, offsetToData + n <= sourceBuffer._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    blockBufferOut.pointee = CMBlockBuffer(_bytes: Array(sourceBuffer._bytes[offsetToData..<(offsetToData + n)]))
    return noErr
}
@discardableResult
public func CMBlockBufferAccessDataBytes(_ b: CMBlockBuffer, atOffset offset: Int, length: Int, temporaryBlock: UnsafeMutableRawPointer, returnedPointerOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> OSStatus {
    guard offset >= 0, offset + length <= b._bytes.count else { return kCMBlockBufferBadOffsetParameterErr }
    returnedPointerOut.pointee = b._bytes.withUnsafeMutableBytes { $0.baseAddress.map { ($0 + offset).assumingMemoryBound(to: CChar.self) } }
    return noErr
}
public func CMBlockBufferIsEmpty(_ b: CMBlockBuffer) -> Bool { b._bytes.isEmpty }
@discardableResult public func CMBlockBufferCopyDataBytes(_ b: CMBlockBuffer, atOffset offset: Int, dataLength: Int, destination: UnsafeMutableRawPointer) -> OSStatus {
    guard offset >= 0, offset <= b._bytes.count else { return kCMBlockBufferBadOffsetParameterErr }
    guard dataLength >= 0, offset + dataLength <= b._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    b._bytes.withUnsafeBytes { destination.copyMemory(from: $0.baseAddress! + offset, byteCount: dataLength) }
    return noErr
}
@discardableResult public func CMBlockBufferGetDataPointer(_ b: CMBlockBuffer, atOffset offset: Int, lengthAtOffsetOut: UnsafeMutablePointer<Int>?,
                                        totalLengthOut: UnsafeMutablePointer<Int>?, dataPointerOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> OSStatus {
    guard offset >= 0, offset <= b._bytes.count else { return kCMBlockBufferBadOffsetParameterErr }
    lengthAtOffsetOut?.pointee = b._bytes.count - offset
    totalLengthOut?.pointee = b._bytes.count
    // the array's storage stays put while the block buffer is alive and unmodified
    dataPointerOut?.pointee = b._bytes.withUnsafeMutableBytes { $0.baseAddress.map { ($0 + offset).assumingMemoryBound(to: CChar.self) } }
    return noErr
}


extension CMFormatDescription {
    /// keeps bytes alive as long as the format description (pointers handed out by the parameter-set accessors)
    func _keep(_ bytes: [UInt8]) -> UnsafePointer<UInt8> {
        let p = UnsafeMutablePointer<UInt8>.allocate(capacity: max(1, bytes.count))
        p.initialize(from: bytes, count: bytes.count)
        _CMKept.lock.lock(); _CMKept.pointers[ObjectIdentifier(self), default: []].append(p); _CMKept.lock.unlock()
        return UnsafePointer(p)
    }
}
enum _CMKept {
    nonisolated(unsafe) static var pointers: [ObjectIdentifier: [UnsafeMutablePointer<UInt8>]] = [:]
    static let lock = NSLock()
}

/// H.264 / HEVC helpers: parameter sets out of configuration records, the coded size from an SPS.
public enum _H26x {
    /// removes emulation-prevention bytes (00 00 03 -> 00 00)
    public static func unescape(_ b: [UInt8]) -> [UInt8] {
        var out: [UInt8] = []; out.reserveCapacity(b.count)
        var zeros = 0
        for x in b {
            if zeros >= 2 && x == 3 { zeros = 0; continue }
            out.append(x)
            zeros = x == 0 ? zeros + 1 : 0
        }
        return out
    }
    public static func avccSets(_ c: [UInt8]) -> [[UInt8]] {
        guard c.count > 6 else { return [] }
        var sets: [[UInt8]] = [], i = 6
        for k in 0..<2 {
            let n = k == 0 ? Int(c[5] & 0x1f) : (i < c.count ? Int(c[i]) : 0)
            if k == 1 { i += 1 }
            for _ in 0..<n {
                guard i + 2 <= c.count else { return sets }
                let l = Int(c[i]) << 8 | Int(c[i + 1]); i += 2
                guard i + l <= c.count else { return sets }
                sets.append(Array(c[i..<(i + l)])); i += l
            }
        }
        return sets
    }
    public static func hvccSets(_ c: [UInt8]) -> [[UInt8]] {
        guard c.count > 23 else { return [] }
        var sets: [[UInt8]] = [], i = 23
        for _ in 0..<Int(c[22]) {
            guard i + 3 <= c.count else { return sets }
            let n = Int(c[i + 1]) << 8 | Int(c[i + 2]); i += 3
            for _ in 0..<n {
                guard i + 2 <= c.count else { return sets }
                let l = Int(c[i]) << 8 | Int(c[i + 1]); i += 2
                guard i + l <= c.count else { return sets }
                sets.append(Array(c[i..<(i + l)])); i += l
            }
        }
        return sets
    }
    struct Bits {
        let b: [UInt8]; var pos = 0
        mutating func u(_ n: Int) -> Int { var v = 0; for _ in 0..<n { let byte = pos / 8 < b.count ? b[pos / 8] : 0; v = v << 1 | Int((byte >> (7 - UInt8(pos % 8))) & 1); pos += 1 }; return v }
        mutating func ue() -> Int { var z = 0; while u(1) == 0 && z < 32 { z += 1 }; return (1 << z) - 1 + u(z) }
        mutating func se() -> Int { let k = ue(); return k % 2 == 1 ? (k + 1) / 2 : -(k / 2) }
    }
    /// the cropped picture size an SPS describes (0, 0 when it cannot be read)
    public static func spsSize(_ nal: [UInt8], hevc: Bool) -> (Int, Int) {
        var r = Bits(b: unescape(Array(nal.dropFirst(hevc ? 2 : 1))))
        if hevc {
            _ = r.u(4); let maxSub = r.u(3); _ = r.u(1)
            _ = r.u(96)                                               // general profile_tier_level
            var subProfile = [Bool](), subLevel = [Bool]()
            for _ in 0..<maxSub { subProfile.append(r.u(1) == 1); subLevel.append(r.u(1) == 1) }
            if maxSub > 0 { for _ in maxSub..<8 { _ = r.u(2) } }
            for i in 0..<maxSub { if subProfile[i] { _ = r.u(88) }; if subLevel[i] { _ = r.u(8) } }
            _ = r.ue(); let chroma = r.ue(); if chroma == 3 { _ = r.u(1) }
            var w = r.ue(), h = r.ue()
            if r.u(1) == 1 {
                let sx = chroma == 1 || chroma == 2 ? 2 : 1, sy = chroma == 1 ? 2 : 1
                let l = r.ue(), rr = r.ue(), t = r.ue(), b = r.ue()
                w -= sx * (l + rr); h -= sy * (t + b)
            }
            return (w, h)
        }
        let profile = r.u(8); _ = r.u(16); _ = r.ue()
        var chroma = 1
        if [100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135].contains(profile) {
            chroma = r.ue(); if chroma == 3 { _ = r.u(1) }
            _ = r.ue(); _ = r.ue(); _ = r.u(1)
            if r.u(1) == 1 {
                for i in 0..<(chroma != 3 ? 8 : 12) where r.u(1) == 1 {
                    var last = 8, next = 8
                    for _ in 0..<(i < 6 ? 16 : 64) where next != 0 { next = (last + r.se() + 256) % 256; last = next == 0 ? last : next }
                }
            }
        }
        _ = r.ue()
        let poc = r.ue()
        if poc == 0 { _ = r.ue() } else if poc == 1 { _ = r.u(1); _ = r.se(); _ = r.se(); let n = r.ue(); for _ in 0..<n { _ = r.se() } }
        _ = r.ue(); _ = r.u(1)
        let wmbs = r.ue() + 1, hmapu = r.ue() + 1
        let frameOnly = r.u(1)
        if frameOnly == 0 { _ = r.u(1) }
        _ = r.u(1)
        var w = wmbs * 16, h = (2 - frameOnly) * hmapu * 16
        if r.u(1) == 1 {
            let sx = chroma == 0 || chroma == 3 ? 1 : 2, sy = (chroma == 1 ? 2 : 1) * (2 - frameOnly)
            let l = r.ue(), rr = r.ue(), t = r.ue(), b = r.ue()
            w -= sx * (l + rr); h -= sy * (t + b)
        }
        return (w, h)
    }
}
