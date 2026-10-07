// isim CoreMedia sample buffers (self-authored, iOS API names): CMSampleBuffer, CMFormatDescription and CMBlockBuffer
// as delivered by isim's capture outputs and AVAssetReader and accepted by AVAssetWriter. Adapted: a sample buffer
// holds either one decoded video frame (a CVPixelBuffer) or a run of interleaved linear-PCM audio frames; no
// compressed samples, attachments only as a dictionary, no CMClock / CMSync.
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
}

public final class CMSampleBuffer: @unchecked Sendable {
    public let _imageBuffer: CVImageBuffer?
    public let _block: CMBlockBuffer?
    public let _format: CMFormatDescription?
    public let _numSamples: Int
    public var _timing: CMSampleTimingInfo
    public var _attachments: [String: Any] = [:]
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
    public var dataReadiness: Bool { true }
}

// MARK: - C-style functions
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
public func CMSampleBufferInvalidate(_ sbuf: CMSampleBuffer) -> OSStatus { noErr }
public func CMSampleBufferGetSampleTimingInfo(_ sbuf: CMSampleBuffer, at index: CMItemCount, timingInfoOut: UnsafeMutablePointer<CMSampleTimingInfo>) -> OSStatus {
    timingInfoOut.pointee = sbuf._timing; return noErr
}
/// Copies interleaved PCM frames into the buffer list (one interleaved buffer, or one buffer per channel).
public func CMSampleBufferCopyPCMDataIntoAudioBufferList(_ sbuf: CMSampleBuffer, at frameOffset: Int32, frameCount: Int32,
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
public func CMSampleBufferCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, dataReady: Bool,
                                               makeDataReadyCallback: Any?, refcon: UnsafeMutableRawPointer?, formatDescription: CMVideoFormatDescription,
                                               sampleTiming: UnsafePointer<CMSampleTimingInfo>, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(_imageBuffer: imageBuffer, presentationTime: sampleTiming.pointee.presentationTimeStamp, duration: sampleTiming.pointee.duration)
    return noErr
}
public func CMSampleBufferCreateReadyWithImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer, formatDescription: CMVideoFormatDescription,
                                                     sampleTiming: UnsafePointer<CMSampleTimingInfo>, sampleBufferOut: UnsafeMutablePointer<CMSampleBuffer?>) -> OSStatus {
    sampleBufferOut.pointee = CMSampleBuffer(_imageBuffer: imageBuffer, presentationTime: sampleTiming.pointee.presentationTimeStamp, duration: sampleTiming.pointee.duration)
    return noErr
}
public func CMVideoFormatDescriptionCreateForImageBuffer(allocator: CFAllocator?, imageBuffer: CVImageBuffer,
                                                         formatDescriptionOut: UnsafeMutablePointer<CMVideoFormatDescription?>) -> OSStatus {
    formatDescriptionOut.pointee = CMFormatDescription(_video: imageBuffer._width, height: imageBuffer._height, pixelFormat: imageBuffer._format)
    return noErr
}
public func CMAudioFormatDescriptionCreate(allocator: CFAllocator?, asbd: UnsafePointer<AudioStreamBasicDescription>, layoutSize: Int, layout: UnsafeRawPointer?,
                                           magicCookieSize: Int, magicCookie: UnsafeRawPointer?, extensions: CFDictionary?,
                                           formatDescriptionOut: UnsafeMutablePointer<CMAudioFormatDescription?>) -> OSStatus {
    formatDescriptionOut.pointee = CMFormatDescription(_audio: asbd.pointee)
    return noErr
}
public func CMFormatDescriptionGetMediaType(_ desc: CMFormatDescription) -> CMMediaType { desc.mediaType }
public func CMFormatDescriptionGetMediaSubType(_ desc: CMFormatDescription) -> FourCharCode { desc.mediaSubType }
public func CMVideoFormatDescriptionGetDimensions(_ desc: CMVideoFormatDescription) -> CMVideoDimensions { desc._dimensions }
public func CMAudioFormatDescriptionGetStreamBasicDescription(_ desc: CMAudioFormatDescription) -> UnsafePointer<AudioStreamBasicDescription>? {
    guard desc.mediaType == kCMMediaType_Audio else { return nil }
    return withUnsafePointer(to: &desc._asbd) { $0 }     // stable: a stored property of a class instance
}
public func CMBlockBufferGetDataLength(_ b: CMBlockBuffer) -> Int { b._bytes.count }
public func CMBlockBufferIsEmpty(_ b: CMBlockBuffer) -> Bool { b._bytes.isEmpty }
public func CMBlockBufferCopyDataBytes(_ b: CMBlockBuffer, atOffset offset: Int, dataLength: Int, destination: UnsafeMutableRawPointer) -> OSStatus {
    guard offset >= 0, offset <= b._bytes.count else { return kCMBlockBufferBadOffsetParameterErr }
    guard dataLength >= 0, offset + dataLength <= b._bytes.count else { return kCMBlockBufferBadLengthParameterErr }
    b._bytes.withUnsafeBytes { destination.copyMemory(from: $0.baseAddress! + offset, byteCount: dataLength) }
    return noErr
}
public func CMBlockBufferGetDataPointer(_ b: CMBlockBuffer, atOffset offset: Int, lengthAtOffsetOut: UnsafeMutablePointer<Int>?,
                                        totalLengthOut: UnsafeMutablePointer<Int>?, dataPointerOut: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>?) -> OSStatus {
    guard offset >= 0, offset <= b._bytes.count else { return kCMBlockBufferBadOffsetParameterErr }
    lengthAtOffsetOut?.pointee = b._bytes.count - offset
    totalLengthOut?.pointee = b._bytes.count
    // the array's storage stays put while the block buffer is alive and unmodified
    dataPointerOut?.pointee = b._bytes.withUnsafeMutableBytes { $0.baseAddress.map { ($0 + offset).assumingMemoryBound(to: CChar.self) } }
    return noErr
}
