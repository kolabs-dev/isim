// isim AudioToolbox: Audio File Services (AudioFile*), Extended Audio File Services (ExtAudioFile*), Audio Converter
// Services (AudioConverter*) and Audio Queue Services (AudioQueue* output and input). Self-authored, iOS API names and
// constants; C-style functions over opaque handles, like the real framework.
// Adapted:
// - Files: linear-PCM WAV/AIFF/CAF are read and written directly (any bit depth/endianness). Compressed files (m4a/AAC,
//   MP3, ALAC, FLAC, ...) are decoded by the host's ffmpeg/GStreamer and then present 48 kHz stereo float32 packets;
//   writing a compressed file type stores PCM and encodes it with ffmpeg on close.
// - Converters: linear PCM to linear PCM (sample format, channel count, sample rate by linear interpolation).
//   Converters to or from compressed formats return kAudioConverterErr_FormatNotSupported.
// - Queues: output queues play through the host mixer (silently paced in real time when headless); input queues read
//   the simulated microphone (ISIM_AUDIO_INPUT). Callbacks run on an internal thread, or on the dispatch queue given.
//   No Audio Units (AUGraph, AudioComponent), no queue processing taps or timelines.
import Foundation
import isim_host
@_exported import _AudioToolboxTypes

/// Darwin's Boolean (isim has no Darwin overlay for C's MacTypes Boolean)
public struct DarwinBoolean: ExpressibleByBooleanLiteral, Equatable, Sendable, CustomStringConvertible {
    public var _value: UInt8
    public init(_ value: Bool) { _value = value ? 1 : 0 }
    public init(booleanLiteral value: Bool) { self.init(value) }
    public var boolValue: Bool { _value != 0 }
    public var description: String { boolValue.description }
}
public typealias AudioFileTypeID = UInt32
public typealias AudioFilePropertyID = UInt32
public typealias ExtAudioFilePropertyID = UInt32
public typealias AudioConverterPropertyID = UInt32
public typealias AudioQueueParameterID = UInt32
public typealias AudioQueueParameterValue = Float32

public struct AudioFilePermissions: RawRepresentable, Sendable, Equatable {
    public let rawValue: Int8
    public init(rawValue: Int8) { self.rawValue = rawValue }
    public static let readPermission = AudioFilePermissions(rawValue: 1)
    public static let writePermission = AudioFilePermissions(rawValue: 2)
    public static let readWritePermission = AudioFilePermissions(rawValue: 3)
}
public struct AudioFileFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let eraseFile = AudioFileFlags(rawValue: 1)
    public static let dontPageAlignAudioData = AudioFileFlags(rawValue: 2)
}

public let kAudioFileWAVEType: AudioFileTypeID = 0x5741_5645       // 'WAVE'
public let kAudioFileAIFFType: AudioFileTypeID = 0x4149_4646       // 'AIFF'
public let kAudioFileAIFCType: AudioFileTypeID = 0x4149_4643       // 'AIFC'
public let kAudioFileCAFType: AudioFileTypeID = 0x6361_6666        // 'caff'
public let kAudioFileM4AType: AudioFileTypeID = 0x6D34_6166        // 'm4af'
public let kAudioFileMPEG4Type: AudioFileTypeID = 0x6D70_3466      // 'mp4f'
public let kAudioFileMP3Type: AudioFileTypeID = 0x4D50_4733        // 'MPG3'
public let kAudioFileAAC_ADTSType: AudioFileTypeID = 0x6164_7473   // 'adts'
public let kAudioFileFLACType: AudioFileTypeID = 0x666C_6163       // 'flac'

public let kAudioFilePropertyFileFormat: AudioFilePropertyID = 0x6666_6D74          // 'ffmt'
public let kAudioFilePropertyDataFormat: AudioFilePropertyID = 0x6466_6D74          // 'dfmt'
public let kAudioFilePropertyAudioDataByteCount: AudioFilePropertyID = 0x6263_6E74  // 'bcnt'
public let kAudioFilePropertyAudioDataPacketCount: AudioFilePropertyID = 0x7063_6E74 // 'pcnt'
public let kAudioFilePropertyMaximumPacketSize: AudioFilePropertyID = 0x7073_7A65   // 'psze'
public let kAudioFilePropertyPacketSizeUpperBound: AudioFilePropertyID = 0x706B_7562 // 'pkub'
public let kAudioFilePropertyEstimatedDuration: AudioFilePropertyID = 0x6564_7572   // 'edur'
public let kAudioFilePropertyIsOptimized: AudioFilePropertyID = 0x6F70_7469         // 'opti'
public let kAudioFilePropertyMagicCookieData: AudioFilePropertyID = 0x6D67_6963     // 'mgic'

public let kExtAudioFileProperty_FileDataFormat: ExtAudioFilePropertyID = 0x6666_6D74    // 'ffmt'
public let kExtAudioFileProperty_ClientDataFormat: ExtAudioFilePropertyID = 0x6366_6D74  // 'cfmt'
public let kExtAudioFileProperty_FileLengthFrames: ExtAudioFilePropertyID = 0x2366_726D  // '#frm'
public let kExtAudioFileProperty_AudioFile: ExtAudioFilePropertyID = 0x6166_696C         // 'afil'

public let kAudioConverterCurrentInputStreamDescription: AudioConverterPropertyID = 0x6163_6964   // 'acid'
public let kAudioConverterCurrentOutputStreamDescription: AudioConverterPropertyID = 0x6163_6F64  // 'acod'
public let kAudioConverterSampleRateConverterQuality: AudioConverterPropertyID = 0x7372_6371     // 'srcq'

public let kAudioQueueParam_Volume: AudioQueueParameterID = 1
public let kAudioQueueParam_PlayRate: AudioQueueParameterID = 2
public let kAudioQueueParam_Pitch: AudioQueueParameterID = 3
public let kAudioQueueParam_VolumeRampTime: AudioQueueParameterID = 4
public let kAudioQueueParam_Pan: AudioQueueParameterID = 13
public let kAudioQueueProperty_IsRunning: AudioQueuePropertyID = 0x6171_7275       // 'aqrn'
public let kAudioQueueProperty_StreamDescription: AudioQueuePropertyID = 0x6171_6674  // 'aqft'
public let kAudioQueueProperty_CurrentLevelMeter: AudioQueuePropertyID = 0x6171_6D76  // 'aqmv'
public let kAudioQueueProperty_EnableLevelMetering: AudioQueuePropertyID = 0x6171_6D65 // 'aqme'

// errors
public let kAudio_UnimplementedError: OSStatus = -4
public let kAudio_FileNotFoundError: OSStatus = -43
public let kAudio_ParamError: OSStatus = -50
public let kAudio_MemFullError: OSStatus = -108
public let kAudioFileUnspecifiedError: OSStatus = 0x7768_743F                  // 'wht?'
public let kAudioFileUnsupportedFileTypeError: OSStatus = 0x7479_703F          // 'typ?'
public let kAudioFileUnsupportedDataFormatError: OSStatus = 0x666D_743F        // 'fmt?'
public let kAudioFileUnsupportedPropertyError: OSStatus = 0x7074_793F          // 'pty?'
public let kAudioFileBadPropertySizeError: OSStatus = 0x2173_697A              // '!siz'
public let kAudioFilePermissionsError: OSStatus = 0x7072_6D3F                  // 'prm?'
public let kAudioFileNotOptimizedError: OSStatus = 0x6F70_7469                 // 'opti'
public let kAudioFileInvalidFileError: OSStatus = 0x6474_613F                  // 'dta?'
public let kAudioFileEndOfFileError: OSStatus = -39
public let kAudioFileInvalidPacketOffsetError: OSStatus = -40
public let kAudioFileOperationNotSupportedError: OSStatus = 0x6F70_3F3F        // 'op??'
public let kAudioFileNotOpenError: OSStatus = -38
public let kExtAudioFileError_InvalidProperty: OSStatus = -66561
public let kExtAudioFileError_InvalidDataFormat: OSStatus = -66566
public let kExtAudioFileError_NonPCMClientFormat: OSStatus = -66563
public let kExtAudioFileError_InvalidSeek: OSStatus = -66568
public let kAudioConverterErr_FormatNotSupported: OSStatus = 0x666D_743F       // 'fmt?'
public let kAudioConverterErr_OperationNotSupported: OSStatus = 0x6F70_3F3F    // 'op??'
public let kAudioConverterErr_PropertyNotSupported: OSStatus = 0x7072_6F70     // 'prop'
public let kAudioConverterErr_InvalidInputSize: OSStatus = 0x696E_737A         // 'insz'
public let kAudioConverterErr_InvalidOutputSize: OSStatus = 0x6F74_737A        // 'otsz'
public let kAudioQueueErr_InvalidBuffer: OSStatus = -66687
public let kAudioQueueErr_BufferEmpty: OSStatus = -66686
public let kAudioQueueErr_InvalidParameter: OSStatus = -66678
public let kAudioQueueErr_InvalidPropertySize: OSStatus = -66683
public let kAudioQueueErr_InvalidProperty: OSStatus = -66682
public let kAudioQueueErr_EnqueueDuringReset: OSStatus = -66632

// MARK: - PCM sample conversion

enum _PCM {
    static func describe(_ d: AudioStreamBasicDescription) -> String {
        "\(Int(d.mSampleRate)) Hz, \(d.mChannelsPerFrame) ch, \(d.mBitsPerChannel)-bit \(d._isFloat ? "float" : "int")\(d._isNonInterleaved ? " non-interleaved" : "")"
    }
    static func valid(_ d: AudioStreamBasicDescription) -> Bool {
        d._isPCM && d.mSampleRate > 0 && d.mChannelsPerFrame > 0 && [8, 16, 24, 32, 64].contains(Int(d.mBitsPerChannel))
            && (!d._isFloat || d.mBitsPerChannel == 32 || d.mBitsPerChannel == 64)
    }
    /// float32 interleaved stereo at 48 kHz: what the host decoder and mixer use
    static let hostFormat = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
                                                        mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked, mBytesPerPacket: 8,
                                                        mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
    static func sample(_ p: UnsafeRawPointer, _ d: AudioStreamBasicDescription) -> Float {
        let bs = d._bytesPerSample
        var v: UInt64 = 0
        for k in 0..<bs { v |= UInt64(p.load(fromByteOffset: d._isBigEndian ? bs - 1 - k : k, as: UInt8.self)) << (8 * UInt64(k)) }
        if d._isFloat { return bs == 8 ? Float(Double(bitPattern: v)) : Float(bitPattern: UInt32(truncatingIfNeeded: v)) }
        if bs == 1 && d.mFormatFlags & kAudioFormatFlagIsSignedInteger == 0 { return (Float(v) - 128) / 128 }
        let shift = 64 - 8 * bs
        return Float(Double(Int64(bitPattern: v << UInt64(shift)) >> Int64(shift)) / Double(Int64(1) << Int64(8 * bs - 1)))
    }
    static func store(_ x: Float, _ p: UnsafeMutableRawPointer, _ d: AudioStreamBasicDescription) {
        let bs = d._bytesPerSample
        var v: UInt64
        if d._isFloat { v = bs == 8 ? Double(x).bitPattern : UInt64(x.bitPattern) }
        else {
            let c = Double(max(-1, min(1, x)))
            if bs == 1 && d.mFormatFlags & kAudioFormatFlagIsSignedInteger == 0 { v = UInt64(max(0, min(255, (c * 128 + 128).rounded()))) }
            else {
                let m = Double(Int64(1) << Int64(8 * bs - 1)) - 1
                v = UInt64(bitPattern: Int64((c * m).rounded()))
            }
        }
        for k in 0..<bs { p.storeBytes(of: UInt8(truncatingIfNeeded: v >> (8 * UInt64(k))), toByteOffset: d._isBigEndian ? bs - 1 - k : k, as: UInt8.self) }
    }
    /// interleaved bytes -> channels
    static func decode(_ bytes: UnsafeRawBufferPointer, _ d: AudioStreamBasicDescription) -> [[Float]] {
        let ch = Int(d.mChannelsPerFrame), fb = d._frameBytes, bs = d._bytesPerSample
        let n = fb > 0 ? bytes.count / fb : 0
        var out = [[Float]](repeating: [Float](repeating: 0, count: n), count: ch)
        guard let base = bytes.baseAddress else { return out }
        for f in 0..<n { for c in 0..<ch { out[c][f] = sample(base + f * fb + c * bs, d) } }
        return out
    }
    static func encode(_ chans: [[Float]], _ d: AudioStreamBasicDescription) -> [UInt8] {
        let ch = Int(d.mChannelsPerFrame), fb = d._frameBytes, bs = d._bytesPerSample
        let n = chans.first?.count ?? 0
        var out = [UInt8](repeating: 0, count: n * fb)
        out.withUnsafeMutableBytes { o in
            for f in 0..<n { for c in 0..<ch { store(chans[min(c, chans.count - 1)][f], o.baseAddress! + f * fb + c * bs, d) } }
        }
        return out
    }
    /// channel count and sample rate conversion
    static func adapt(_ x: [[Float]], from: AudioStreamBasicDescription, to: AudioStreamBasicDescription) -> [[Float]] {
        var y = x
        let tc = Int(to.mChannelsPerFrame)
        if y.count != tc {
            if tc == 1 { let n = y.first?.count ?? 0; var m = [Float](repeating: 0, count: n); for c in y { for i in 0..<n { m[i] += c[i] / Float(y.count) } }; y = [m] }
            else { y = (0..<tc).map { y[min($0, y.count - 1)] } }
        }
        if from.mSampleRate != to.mSampleRate, from.mSampleRate > 0 {
            let r = from.mSampleRate / to.mSampleRate
            y = y.map { c in
                let n = Int((Double(c.count) / r).rounded())
                return (0..<n).map { i in
                    let p = Double(i) * r, i0 = Int(p), t = Float(p - Double(i0))
                    let a = c[min(i0, c.count - 1)], b = c[min(i0 + 1, c.count - 1)]
                    return a + (b - a) * t
                }
            }
        }
        return y
    }
    /// fills a buffer list (interleaved or one buffer per channel) with `chans` frames; returns frames written
    static func fill(_ list: UnsafeMutableAudioBufferListPointer, _ chans: [[Float]], _ d: AudioStreamBasicDescription, from: Int, count: Int) -> Int {
        let bs = d._bytesPerSample
        if d._isNonInterleaved {
            var n = count
            for (c, b) in list.enumerated() { n = min(n, Int(b.mDataByteSize) / bs); _ = c }
            for c in 0..<list.count {
                guard let p = list[c].mData else { continue }
                for i in 0..<n { store(chans[min(c, chans.count - 1)][from + i], p + i * bs, d) }
                list[c].mDataByteSize = UInt32(n * bs)
            }
            return n
        }
        guard list.count > 0, let p = list[0].mData else { return 0 }
        let fb = d._frameBytes, ch = Int(d.mChannelsPerFrame)
        let n = min(count, Int(list[0].mDataByteSize) / fb)
        for i in 0..<n { for c in 0..<ch { store(chans[min(c, chans.count - 1)][from + i], p + i * fb + c * bs, d) } }
        list[0].mDataByteSize = UInt32(n * fb)
        return n
    }
    /// reads `frames` frames from a buffer list
    static func read(_ list: UnsafeMutableAudioBufferListPointer, _ d: AudioStreamBasicDescription, frames: Int) -> [[Float]] {
        let bs = d._bytesPerSample, ch = Int(d.mChannelsPerFrame)
        if d._isNonInterleaved {
            return (0..<ch).map { c in
                guard c < list.count, let p = list[c].mData else { return [Float](repeating: 0, count: frames) }
                let n = min(frames, Int(list[c].mDataByteSize) / bs)
                return (0..<frames).map { i in i < n ? sample(p + i * bs, d) : 0 }
            }
        }
        guard list.count > 0, let p = list[0].mData else { return [[Float]](repeating: [], count: ch) }
        let n = min(frames, Int(list[0].mDataByteSize) / max(1, d._frameBytes))
        return decode(UnsafeRawBufferPointer(start: p, count: n * d._frameBytes), d)
    }
}
func _pcmFormat(rate: Double, channels: Int, bits: Int, float: Bool, bigEndian: Bool = false, nonInterleaved: Bool = false) -> AudioStreamBasicDescription {
    var flags = (float ? kAudioFormatFlagIsFloat : (bits > 8 ? kAudioFormatFlagIsSignedInteger : 0)) | kAudioFormatFlagIsPacked
    if bigEndian { flags |= kAudioFormatFlagIsBigEndian }
    if nonInterleaved { flags |= kAudioFormatFlagIsNonInterleaved }
    let fb = UInt32(nonInterleaved ? bits / 8 : bits / 8 * channels)
    return AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: flags, mBytesPerPacket: fb, mFramesPerPacket: 1,
                                       mBytesPerFrame: fb, mChannelsPerFrame: UInt32(channels), mBitsPerChannel: UInt32(bits), mReserved: 0)
}
func _handle(_ o: AnyObject) -> OpaquePointer { OpaquePointer(Unmanaged.passRetained(o).toOpaque()) }
func _object<T: AnyObject>(_ p: OpaquePointer?, _ t: T.Type) -> T? {
    guard let p else { return nil }
    return Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(p)).takeUnretainedValue() as? T
}
func _release(_ p: OpaquePointer) { Unmanaged<AnyObject>.fromOpaque(UnsafeRawPointer(p)).release() }
func _put<T>(_ v: T, _ size: UnsafeMutablePointer<UInt32>, _ out: UnsafeMutableRawPointer) -> OSStatus {
    guard Int(size.pointee) >= MemoryLayout<T>.size else { return kAudioFileBadPropertySizeError }
    out.storeBytes(of: v, as: T.self)
    size.pointee = UInt32(MemoryLayout<T>.size)
    return noErr_
}
let noErr_: OSStatus = 0

// MARK: - Audio File Services

final class _AudioFile {
    let path: String
    let type: AudioFileTypeID
    var format: AudioStreamBasicDescription
    var data: [UInt8]                  // packed audio data in `format`
    let writable: Bool
    var dirty = false
    init(path: String, type: AudioFileTypeID, format: AudioStreamBasicDescription, data: [UInt8], writable: Bool) {
        self.path = path; self.type = type; self.format = format; self.data = data; self.writable = writable
    }
    var packetCount: Int { data.count / max(1, format._frameBytes) }

    static func typeFor(_ path: String) -> AudioFileTypeID {
        switch (path as NSString).pathExtension.lowercased() {
        case "wav", "wave": return kAudioFileWAVEType
        case "aif", "aiff": return kAudioFileAIFFType
        case "aifc": return kAudioFileAIFCType
        case "caf": return kAudioFileCAFType
        case "m4a": return kAudioFileM4AType
        case "mp4": return kAudioFileMPEG4Type
        case "mp3": return kAudioFileMP3Type
        case "aac": return kAudioFileAAC_ADTSType
        case "flac": return kAudioFileFLACType
        default: return 0
        }
    }
    /// Opens a file: PCM WAV/AIFF/CAF natively, anything else through the host decoder (48 kHz stereo float).
    static func open(_ path: String, writable: Bool) -> (_AudioFile?, OSStatus) {
        guard let d = FileManager.default.contents(atPath: path) else { return (nil, kAudio_FileNotFoundError) }
        let b = [UInt8](d)
        if let f = parsePCM(b, path: path, writable: writable) { return (f, noErr_) }
        var out: UnsafeMutablePointer<Float>? = nil
        var frames = 0, channels: Int32 = 0, rate = 0.0
        guard isim_audio_decode_file(path, &out, &frames, &channels, &rate) != 0, let pcm = out else { return (nil, kAudioFileUnsupportedFileTypeError) }
        defer { isim_audio_free(pcm) }
        let bytes = [UInt8](UnsafeRawBufferPointer(start: pcm, count: frames * Int(channels) * 4))
        let fmt = _pcmFormat(rate: rate, channels: Int(channels), bits: 32, float: true)
        return (_AudioFile(path: path, type: typeFor(path), format: fmt, data: bytes, writable: writable), noErr_)
    }
    static func parsePCM(_ b: [UInt8], path: String, writable: Bool) -> _AudioFile? {
        func be32(_ o: Int) -> UInt32 { UInt32(b[o]) << 24 | UInt32(b[o + 1]) << 16 | UInt32(b[o + 2]) << 8 | UInt32(b[o + 3]) }
        func le32(_ o: Int) -> UInt32 { UInt32(b[o]) | UInt32(b[o + 1]) << 8 | UInt32(b[o + 2]) << 16 | UInt32(b[o + 3]) << 24 }
        func be16(_ o: Int) -> UInt16 { UInt16(b[o]) << 8 | UInt16(b[o + 1]) }
        func le16(_ o: Int) -> UInt16 { UInt16(b[o]) | UInt16(b[o + 1]) << 8 }
        func tag(_ o: Int) -> String { String(decoding: b[o..<o + 4], as: UTF8.self) }
        guard b.count >= 12 else { return nil }
        if tag(0) == "RIFF", tag(8) == "WAVE" {
            var o = 12, fmt: AudioStreamBasicDescription?
            while o + 8 <= b.count {
                let size = Int(le32(o + 4))
                if tag(o) == "fmt " {
                    let t = Int(le16(o + 8)), ch = Int(le16(o + 10)), rate = Double(le32(o + 12)), bits = Int(le16(o + 22))
                    guard t == 1 || t == 3 || t == 0xFFFE else { return nil }
                    fmt = _pcmFormat(rate: rate, channels: ch, bits: bits, float: t == 3 || (t == 0xFFFE && bits == 32 && size >= 40 && le16(o + 32) == 3))
                } else if tag(o) == "data", let f = fmt {
                    return _AudioFile(path: path, type: kAudioFileWAVEType, format: f, data: Array(b[(o + 8)..<min(b.count, o + 8 + size)]), writable: writable)
                }
                o += 8 + size + (size & 1)
            }
            return nil
        }
        if tag(0) == "FORM", tag(8) == "AIFF" || tag(8) == "AIFC" {
            var o = 12, fmt: AudioStreamBasicDescription?
            while o + 8 <= b.count {
                let size = Int(be32(o + 4))
                if tag(o) == "COMM" {
                    let ch = Int(be16(o + 8)), bits = Int(be16(o + 14))
                    // 80-bit extended sample rate
                    let exp = Int(be16(o + 16) & 0x7FFF) - 16383, mant = UInt64(be32(o + 18)) << 32 | UInt64(be32(o + 22))
                    let rate = Double(mant) * pow(2, Double(exp - 63))
                    if tag(8) == "AIFC", size >= 22, ["sowt"].contains(tag(o + 26)) { fmt = _pcmFormat(rate: rate, channels: ch, bits: bits, float: false) }
                    else if tag(8) == "AIFC", size >= 22, !["NONE", "twos"].contains(tag(o + 26)) { return nil }
                    else { fmt = _pcmFormat(rate: rate, channels: ch, bits: bits, float: false, bigEndian: true) }
                } else if tag(o) == "SSND", let f = fmt {
                    let off = Int(be32(o + 8))
                    return _AudioFile(path: path, type: tag(8) == "AIFC" ? kAudioFileAIFCType : kAudioFileAIFFType, format: f,
                                      data: Array(b[(o + 16 + off)..<min(b.count, o + 8 + size)]), writable: writable)
                }
                o += 8 + size + (size & 1)
            }
            return nil
        }
        if tag(0) == "caff" {
            var o = 8, fmt: AudioStreamBasicDescription?
            while o + 12 <= b.count {
                let size = Int(Int64(bitPattern: UInt64(be32(o + 4)) << 32 | UInt64(be32(o + 8))))
                let body = o + 12
                if tag(o) == "desc" {
                    let rate = Double(bitPattern: UInt64(be32(body)) << 32 | UInt64(be32(body + 4)))
                    guard be32(body + 8) == kAudioFormatLinearPCM else { return nil }
                    let flags = be32(body + 12), ch = Int(be32(body + 24)), bits = Int(be32(body + 28))
                    // CAF flags: bit 0 float, bit 1 little-endian
                    fmt = _pcmFormat(rate: rate, channels: ch, bits: bits, float: flags & 1 != 0, bigEndian: flags & 2 == 0)
                } else if tag(o) == "data", let f = fmt {
                    let end = size < 0 ? b.count : min(b.count, body + size)
                    return _AudioFile(path: path, type: kAudioFileCAFType, format: f, data: Array(b[(body + 4)..<end]), writable: writable)
                }
                guard size >= 0 else { break }
                o = body + size
            }
            return nil
        }
        return nil
    }
    /// Writes the file: PCM containers directly; other types as WAV then encoded by the host's ffmpeg.
    func flush() -> OSStatus {
        guard writable, dirty else { return noErr_ }
        dirty = false
        let f = format
        var out = Data()
        func s(_ x: String) { out.append(contentsOf: Array(x.utf8)) }
        func le(_ v: Int, _ n: Int) { for k in 0..<n { out.append(UInt8(truncatingIfNeeded: v >> (8 * k))) } }
        func be(_ v: UInt64, _ n: Int) { for k in (0..<n).reversed() { out.append(UInt8(truncatingIfNeeded: v >> (8 * UInt64(k)))) } }
        switch type {
        case kAudioFileCAFType:
            s("caff"); be(1, 2); be(0, 2)
            s("desc"); be(32, 8); be(f.mSampleRate.bitPattern, 8); be(UInt64(kAudioFormatLinearPCM), 4)
            be(UInt64((f._isFloat ? 1 : 0) | (f._isBigEndian ? 0 : 2)), 4); be(UInt64(f._frameBytes), 4); be(1, 4)
            be(UInt64(f.mChannelsPerFrame), 4); be(UInt64(f.mBitsPerChannel), 4)
            s("data"); be(UInt64(data.count + 4), 8); be(0, 4); out.append(contentsOf: data)
        case kAudioFileAIFFType, kAudioFileAIFCType:
            var d = data
            if !f._isBigEndian { let bs = f._bytesPerSample; for i in stride(from: 0, to: d.count - bs + 1, by: bs) { d[i..<i + bs].reverse() } }
            s("FORM"); be(UInt64(4 + 26 + 16 + d.count), 4); s("AIFF")
            s("COMM"); be(18, 4); be(UInt64(f.mChannelsPerFrame), 2); be(UInt64(d.count / max(1, f._frameBytes)), 4); be(UInt64(f.mBitsPerChannel), 2)
            let e = Int(log2(f.mSampleRate)), mant = UInt64(f.mSampleRate * pow(2, Double(63 - e)))
            be(UInt64(e + 16383), 2); be(mant, 8)
            s("SSND"); be(UInt64(8 + d.count), 4); be(0, 4); be(0, 4); out.append(contentsOf: d)
        default:     // WAV (and the intermediate for compressed types)
            var d = data
            if f._isBigEndian { let bs = f._bytesPerSample; for i in stride(from: 0, to: d.count - bs + 1, by: bs) { d[i..<i + bs].reverse() } }
            s("RIFF"); le(36 + d.count, 4); s("WAVE"); s("fmt "); le(16, 4); le(f._isFloat ? 3 : 1, 2); le(Int(f.mChannelsPerFrame), 2)
            le(Int(f.mSampleRate), 4); le(Int(f.mSampleRate) * f._frameBytes, 4); le(f._frameBytes, 2); le(Int(f.mBitsPerChannel), 2)
            s("data"); le(d.count, 4); out.append(contentsOf: d)
        }
        if [kAudioFileWAVEType, kAudioFileCAFType, kAudioFileAIFFType, kAudioFileAIFCType].contains(type) {
            return FileManager.default.createFile(atPath: path, contents: out) ? noErr_ : kAudioFilePermissionsError
        }
        let tmp = NSTemporaryDirectory() + "isim-audiofile-\(UUID().uuidString).wav"
        guard FileManager.default.createFile(atPath: tmp, contents: out) else { return kAudioFilePermissionsError }
        defer { try? FileManager.default.removeItem(atPath: tmp) }
        try? FileManager.default.removeItem(atPath: path)
        return isim_media_transcode(tmp, path) != 0 ? noErr_ : kAudioFileUnspecifiedError
    }
}

func _cfPath(_ u: CFURL) -> String? { unsafeBitCast(u, to: NSURL.self).path }

public func AudioFileOpenURL(_ inFileRef: CFURL, _ inPermissions: AudioFilePermissions, _ inFileTypeHint: AudioFileTypeID,
                             _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    guard let path = _cfPath(inFileRef) else { return kAudio_ParamError }
    let (f, st) = _AudioFile.open(path, writable: inPermissions != .readPermission)
    guard let f else { return st }
    outAudioFile.pointee = _handle(f)
    return noErr_
}
public func AudioFileCreateWithURL(_ inFileRef: CFURL, _ inFileType: AudioFileTypeID, _ inFormat: UnsafePointer<AudioStreamBasicDescription>,
                                   _ inFlags: AudioFileFlags, _ outAudioFile: UnsafeMutablePointer<AudioFileID?>) -> OSStatus {
    guard let path = _cfPath(inFileRef) else { return kAudio_ParamError }
    let fmt = inFormat.pointee
    guard _PCM.valid(fmt) else { NSLog("isim AudioToolbox: AudioFileCreateWithURL writes linear PCM (encode with ExtAudioFile or AVAudioFile)"); return kAudioFileUnsupportedDataFormatError }
    if FileManager.default.fileExists(atPath: path) && !inFlags.contains(.eraseFile) { return kAudioFilePermissionsError }
    guard FileManager.default.createFile(atPath: path, contents: nil) else { return kAudioFilePermissionsError }
    let f = _AudioFile(path: path, type: inFileType, format: fmt, data: [], writable: true)
    f.dirty = true
    outAudioFile.pointee = _handle(f)
    return noErr_
}
@discardableResult public func AudioFileClose(_ inAudioFile: AudioFileID) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    let st = f.flush()
    _release(inAudioFile)
    return st
}
public func AudioFileOptimize(_ inAudioFile: AudioFileID) -> OSStatus { noErr_ }
public func AudioFileGetPropertyInfo(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ outDataSize: UnsafeMutablePointer<UInt32>?,
                                     _ isWritable: UnsafeMutablePointer<UInt32>?) -> OSStatus {
    guard _object(inAudioFile, _AudioFile.self) != nil else { return kAudioFileNotOpenError }
    let size: Int
    switch inPropertyID {
    case kAudioFilePropertyDataFormat: size = MemoryLayout<AudioStreamBasicDescription>.size
    case kAudioFilePropertyFileFormat, kAudioFilePropertyMaximumPacketSize, kAudioFilePropertyPacketSizeUpperBound, kAudioFilePropertyIsOptimized: size = 4
    case kAudioFilePropertyAudioDataByteCount, kAudioFilePropertyAudioDataPacketCount, kAudioFilePropertyEstimatedDuration: size = 8
    default: return kAudioFileUnsupportedPropertyError
    }
    outDataSize?.pointee = UInt32(size); isWritable?.pointee = 0
    return noErr_
}
public func AudioFileGetProperty(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ ioDataSize: UnsafeMutablePointer<UInt32>,
                                 _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    switch inPropertyID {
    case kAudioFilePropertyDataFormat: return _put(f.format, ioDataSize, outPropertyData)
    case kAudioFilePropertyFileFormat: return _put(f.type, ioDataSize, outPropertyData)
    case kAudioFilePropertyAudioDataByteCount: return _put(UInt64(f.data.count), ioDataSize, outPropertyData)
    case kAudioFilePropertyAudioDataPacketCount: return _put(UInt64(f.packetCount), ioDataSize, outPropertyData)
    case kAudioFilePropertyMaximumPacketSize, kAudioFilePropertyPacketSizeUpperBound: return _put(UInt32(f.format._frameBytes), ioDataSize, outPropertyData)
    case kAudioFilePropertyEstimatedDuration: return _put(Double(f.packetCount) / f.format.mSampleRate, ioDataSize, outPropertyData)
    case kAudioFilePropertyIsOptimized: return _put(UInt32(1), ioDataSize, outPropertyData)
    default: return kAudioFileUnsupportedPropertyError
    }
}
public func AudioFileSetProperty(_ inAudioFile: AudioFileID, _ inPropertyID: AudioFilePropertyID, _ inDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    kAudioFileUnsupportedPropertyError
}
public func AudioFileReadBytes(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ inStartingByte: Int64, _ ioNumBytes: UnsafeMutablePointer<UInt32>,
                               _ outBuffer: UnsafeMutableRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard inStartingByte >= 0 else { return kAudioFileInvalidPacketOffsetError }
    let start = Int(inStartingByte), n = max(0, min(Int(ioNumBytes.pointee), f.data.count - start))
    if n > 0 { f.data.withUnsafeBytes { outBuffer.copyMemory(from: $0.baseAddress! + start, byteCount: n) } }
    ioNumBytes.pointee = UInt32(n)
    return n == 0 && ioNumBytes.pointee == 0 && start >= f.data.count ? kAudioFileEndOfFileError : noErr_
}
public func AudioFileReadPacketData(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ ioNumBytes: UnsafeMutablePointer<UInt32>,
                                    _ outPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64,
                                    _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ outBuffer: UnsafeMutableRawPointer?) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    let fb = f.format._frameBytes
    let start = Int(inStartingPacket)
    guard start >= 0 else { return kAudioFileInvalidPacketOffsetError }
    let n = max(0, min(Int(ioNumPackets.pointee), Int(ioNumBytes.pointee) / fb, f.packetCount - start))
    if n > 0, let out = outBuffer { f.data.withUnsafeBytes { out.copyMemory(from: $0.baseAddress! + start * fb, byteCount: n * fb) } }
    ioNumPackets.pointee = UInt32(n); ioNumBytes.pointee = UInt32(n * fb)
    return noErr_
}
public func AudioFileReadPackets(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ outNumBytes: UnsafeMutablePointer<UInt32>,
                                 _ outPacketDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64,
                                 _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ outBuffer: UnsafeMutableRawPointer?) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    outNumBytes.pointee = ioNumPackets.pointee * UInt32(f.format._frameBytes)
    return AudioFileReadPacketData(inAudioFile, inUseCache, outNumBytes, outPacketDescriptions, inStartingPacket, ioNumPackets, outBuffer)
}
public func AudioFileWriteBytes(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ inStartingByte: Int64, _ ioNumBytes: UnsafeMutablePointer<UInt32>,
                                _ inBuffer: UnsafeRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    guard f.writable else { return kAudioFilePermissionsError }
    let start = Int(inStartingByte), n = Int(ioNumBytes.pointee)
    if f.data.count < start + n { f.data += [UInt8](repeating: 0, count: start + n - f.data.count) }
    f.data.withUnsafeMutableBytes { ($0.baseAddress! + start).copyMemory(from: inBuffer, byteCount: n) }
    f.dirty = true
    return noErr_
}
public func AudioFileWritePackets(_ inAudioFile: AudioFileID, _ inUseCache: Bool, _ inNumBytes: UInt32,
                                  _ inPacketDescriptions: UnsafePointer<AudioStreamPacketDescription>?, _ inStartingPacket: Int64,
                                  _ ioNumPackets: UnsafeMutablePointer<UInt32>, _ inBuffer: UnsafeRawPointer) -> OSStatus {
    guard let f = _object(inAudioFile, _AudioFile.self) else { return kAudioFileNotOpenError }
    var n = UInt32(min(Int(inNumBytes), Int(ioNumPackets.pointee) * f.format._frameBytes))
    let st = AudioFileWriteBytes(inAudioFile, inUseCache, inStartingPacket * Int64(f.format._frameBytes), &n, inBuffer)
    ioNumPackets.pointee = n / UInt32(f.format._frameBytes)
    return st
}

// MARK: - Extended Audio File Services

final class _ExtAudioFile {
    let file: _AudioFile
    var client: AudioStreamBasicDescription
    var position = 0                     // in file frames
    var decoded: [[Float]]?              // file samples (lazily, for reading)
    init(file: _AudioFile) { self.file = file; client = file.format }
    var samples: [[Float]] {
        if let d = decoded { return d }
        let d = file.data.withUnsafeBytes { _PCM.decode($0, file.format) }
        decoded = d
        return d
    }
}
public func ExtAudioFileOpenURL(_ inURL: CFURL, _ outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus {
    guard let path = _cfPath(inURL) else { return kAudio_ParamError }
    let (f, st) = _AudioFile.open(path, writable: false)
    guard let f else { return st }
    outExtAudioFile.pointee = _handle(_ExtAudioFile(file: f))
    return noErr_
}
/// isim: PCM file formats are written directly; a compressed format (AAC in m4a, ...) is written as 48 kHz PCM and
/// encoded by the host's ffmpeg when the file is disposed.
public func ExtAudioFileCreateWithURL(_ inURL: CFURL, _ inFileType: AudioFileTypeID, _ inStreamDesc: UnsafePointer<AudioStreamBasicDescription>,
                                      _ inChannelLayout: UnsafeRawPointer?, _ inFlags: UInt32, _ outExtAudioFile: UnsafeMutablePointer<ExtAudioFileRef?>) -> OSStatus {
    guard let path = _cfPath(inURL) else { return kAudio_ParamError }
    var fmt = inStreamDesc.pointee
    if !fmt._isPCM {
        fmt = _pcmFormat(rate: fmt.mSampleRate > 0 ? fmt.mSampleRate : 44100, channels: Int(max(1, fmt.mChannelsPerFrame)), bits: 16, float: false)
    }
    guard _PCM.valid(fmt) else { return kExtAudioFileError_InvalidDataFormat }
    if FileManager.default.fileExists(atPath: path) && inFlags & AudioFileFlags.eraseFile.rawValue == 0 { return kAudioFilePermissionsError }
    if fmt._isNonInterleaved { fmt = _pcmFormat(rate: fmt.mSampleRate, channels: Int(fmt.mChannelsPerFrame), bits: Int(fmt.mBitsPerChannel), float: fmt._isFloat) }
    let f = _AudioFile(path: path, type: inFileType, format: fmt, data: [], writable: true)
    f.dirty = true
    outExtAudioFile.pointee = _handle(_ExtAudioFile(file: f))
    return noErr_
}
@discardableResult public func ExtAudioFileDispose(_ inExtAudioFile: ExtAudioFileRef) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    let st = e.file.flush()
    _release(inExtAudioFile)
    return st
}
public func ExtAudioFileGetPropertyInfo(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ outSize: UnsafeMutablePointer<UInt32>?,
                                        _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    switch inPropertyID {
    case kExtAudioFileProperty_FileDataFormat, kExtAudioFileProperty_ClientDataFormat: outSize?.pointee = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    case kExtAudioFileProperty_FileLengthFrames: outSize?.pointee = 8
    default: return kExtAudioFileError_InvalidProperty
    }
    outWritable?.pointee = DarwinBoolean(inPropertyID == kExtAudioFileProperty_ClientDataFormat)
    return noErr_
}
public func ExtAudioFileGetProperty(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>,
                                    _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    switch inPropertyID {
    case kExtAudioFileProperty_FileDataFormat: return _put(e.file.format, ioPropertyDataSize, outPropertyData)
    case kExtAudioFileProperty_ClientDataFormat: return _put(e.client, ioPropertyDataSize, outPropertyData)
    case kExtAudioFileProperty_FileLengthFrames: return _put(Int64(e.file.packetCount), ioPropertyDataSize, outPropertyData)
    default: return kExtAudioFileError_InvalidProperty
    }
}
public func ExtAudioFileSetProperty(_ inExtAudioFile: ExtAudioFileRef, _ inPropertyID: ExtAudioFilePropertyID, _ inPropertyDataSize: UInt32,
                                    _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    guard inPropertyID == kExtAudioFileProperty_ClientDataFormat else { return kExtAudioFileError_InvalidProperty }
    guard Int(inPropertyDataSize) >= MemoryLayout<AudioStreamBasicDescription>.size else { return kAudioFileBadPropertySizeError }
    let c = inPropertyData.load(as: AudioStreamBasicDescription.self)
    guard _PCM.valid(c) else { return kExtAudioFileError_NonPCMClientFormat }
    e.client = c
    return noErr_
}
/// Reads up to *ioNumberFrames client frames, converted to the client format.
public func ExtAudioFileRead(_ inExtAudioFile: ExtAudioFileRef, _ ioNumberFrames: UnsafeMutablePointer<UInt32>, _ ioData: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    let ratio = e.file.format.mSampleRate / e.client.mSampleRate
    let want = Int(ioNumberFrames.pointee)
    let srcFrames = min(e.file.packetCount - e.position, Int((Double(want) * ratio).rounded(.up)))
    guard srcFrames > 0 else { ioNumberFrames.pointee = 0; let l = UnsafeMutableAudioBufferListPointer(ioData); for i in 0..<l.count { l[i].mDataByteSize = 0 }; return noErr_ }
    let chunk = e.samples.map { Array($0[e.position..<(e.position + srcFrames)]) }
    let conv = _PCM.adapt(chunk, from: e.file.format, to: e.client)
    let n = _PCM.fill(UnsafeMutableAudioBufferListPointer(ioData), conv, e.client, from: 0, count: min(want, conv.first?.count ?? 0))
    e.position += min(srcFrames, Int((Double(n) * ratio).rounded()))
    ioNumberFrames.pointee = UInt32(n)
    return noErr_
}
public func ExtAudioFileWrite(_ inExtAudioFile: ExtAudioFileRef, _ inNumberFrames: UInt32, _ ioData: UnsafePointer<AudioBufferList>) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    guard e.file.writable else { return kAudioFilePermissionsError }
    let x = _PCM.read(UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: ioData)), e.client, frames: Int(inNumberFrames))
    let y = _PCM.adapt(x, from: e.client, to: e.file.format)
    e.file.data += _PCM.encode(y, e.file.format)
    e.file.dirty = true
    e.position = e.file.packetCount
    return noErr_
}
public func ExtAudioFileWriteAsync(_ inExtAudioFile: ExtAudioFileRef, _ inNumberFrames: UInt32, _ ioData: UnsafePointer<AudioBufferList>?) -> OSStatus {
    guard let ioData else { return noErr_ }          // NULL primes the async writer
    return ExtAudioFileWrite(inExtAudioFile, inNumberFrames, ioData)
}
public func ExtAudioFileSeek(_ inExtAudioFile: ExtAudioFileRef, _ inFrameOffset: Int64) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    let p = Int((Double(inFrameOffset) * e.file.format.mSampleRate / e.client.mSampleRate).rounded())
    guard p >= 0, p <= e.file.packetCount else { return kExtAudioFileError_InvalidSeek }
    e.position = p
    return noErr_
}
public func ExtAudioFileTell(_ inExtAudioFile: ExtAudioFileRef, _ outFrameOffset: UnsafeMutablePointer<Int64>) -> OSStatus {
    guard let e = _object(inExtAudioFile, _ExtAudioFile.self) else { return kAudio_ParamError }
    outFrameOffset.pointee = Int64((Double(e.position) * e.client.mSampleRate / e.file.format.mSampleRate).rounded())
    return noErr_
}

// MARK: - Audio Converter Services

final class _AudioConverter {
    let from: AudioStreamBasicDescription, to: AudioStreamBasicDescription
    var pending: [[Float]]               // converted frames not yet handed out
    init(from: AudioStreamBasicDescription, to: AudioStreamBasicDescription) {
        self.from = from; self.to = to; pending = [[Float]](repeating: [], count: Int(to.mChannelsPerFrame))
    }
}
public func AudioConverterNew(_ inSourceFormat: UnsafePointer<AudioStreamBasicDescription>, _ inDestinationFormat: UnsafePointer<AudioStreamBasicDescription>,
                              _ outAudioConverter: UnsafeMutablePointer<AudioConverterRef?>) -> OSStatus {
    let a = inSourceFormat.pointee, b = inDestinationFormat.pointee
    guard _PCM.valid(a), _PCM.valid(b) else {
        NSLog("isim AudioToolbox: AudioConverter supports linear PCM only (%@ -> %@); encode with AVAssetWriter/AVAudioFile, decode with AVAudioFile/ExtAudioFile",
              a._isPCM ? _PCM.describe(a) : "compressed", b._isPCM ? _PCM.describe(b) : "compressed")
        return kAudioConverterErr_FormatNotSupported
    }
    outAudioConverter.pointee = _handle(_AudioConverter(from: a, to: b))
    return noErr_
}
@discardableResult public func AudioConverterDispose(_ inAudioConverter: AudioConverterRef) -> OSStatus { _release(inAudioConverter); return noErr_ }
@discardableResult public func AudioConverterReset(_ inAudioConverter: AudioConverterRef) -> OSStatus {
    guard let c = _object(inAudioConverter, _AudioConverter.self) else { return kAudio_ParamError }
    c.pending = [[Float]](repeating: [], count: Int(c.to.mChannelsPerFrame))
    return noErr_
}
public func AudioConverterGetProperty(_ inAudioConverter: AudioConverterRef, _ inPropertyID: AudioConverterPropertyID, _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>,
                                      _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    guard let c = _object(inAudioConverter, _AudioConverter.self) else { return kAudio_ParamError }
    switch inPropertyID {
    case kAudioConverterCurrentInputStreamDescription: return _put(c.from, ioPropertyDataSize, outPropertyData)
    case kAudioConverterCurrentOutputStreamDescription: return _put(c.to, ioPropertyDataSize, outPropertyData)
    default: return kAudioConverterErr_PropertyNotSupported
    }
}
public func AudioConverterSetProperty(_ inAudioConverter: AudioConverterRef, _ inPropertyID: AudioConverterPropertyID, _ inPropertyDataSize: UInt32,
                                      _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    inPropertyID == kAudioConverterSampleRateConverterQuality ? noErr_ : kAudioConverterErr_PropertyNotSupported
}
/// Converts a whole buffer (interleaved formats).
public func AudioConverterConvertBuffer(_ inAudioConverter: AudioConverterRef, _ inInputDataSize: UInt32, _ inInputData: UnsafeRawPointer,
                                        _ ioOutputDataSize: UnsafeMutablePointer<UInt32>, _ outOutputData: UnsafeMutableRawPointer) -> OSStatus {
    guard let c = _object(inAudioConverter, _AudioConverter.self) else { return kAudio_ParamError }
    guard c.from.mSampleRate == c.to.mSampleRate else { return kAudioConverterErr_OperationNotSupported }   // like iOS: rate conversion needs FillComplexBuffer
    let x = _PCM.decode(UnsafeRawBufferPointer(start: inInputData, count: Int(inInputDataSize)), c.from)
    let bytes = _PCM.encode(_PCM.adapt(x, from: c.from, to: c.to), c.to)
    guard bytes.count <= Int(ioOutputDataSize.pointee) else { return kAudioConverterErr_InvalidOutputSize }
    bytes.withUnsafeBytes { outOutputData.copyMemory(from: $0.baseAddress!, byteCount: bytes.count) }
    ioOutputDataSize.pointee = UInt32(bytes.count)
    return noErr_
}
/// Pulls input through `inInputDataProc` until *ioOutputDataPacketSize packets are produced or the proc returns no data/an error.
public func AudioConverterFillComplexBuffer(_ inAudioConverter: AudioConverterRef, _ inInputDataProc: AudioConverterComplexInputDataProc,
                                            _ inInputDataProcUserData: UnsafeMutableRawPointer?, _ ioOutputDataPacketSize: UnsafeMutablePointer<UInt32>,
                                            _ outOutputData: UnsafeMutablePointer<AudioBufferList>,
                                            _ outPacketDescription: UnsafeMutablePointer<AudioStreamPacketDescription>?) -> OSStatus {
    guard let c = _object(inAudioConverter, _AudioConverter.self) else { return kAudio_ParamError }
    let want = Int(ioOutputDataPacketSize.pointee)
    var status = noErr_
    while (c.pending.first?.count ?? 0) < want {
        let ich = Int(c.from.mChannelsPerFrame)
        let list = AudioBufferList.allocate(maximumBuffers: c.from._isNonInterleaved ? ich : 1)
        defer { free(list.unsafeMutablePointer) }
        var packets = UInt32(max(1, Int(Double(want - (c.pending.first?.count ?? 0)) * c.from.mSampleRate / c.to.mSampleRate)))
        status = inInputDataProc(inAudioConverter, &packets, list.unsafeMutablePointer, nil, inInputDataProcUserData)
        if packets == 0 || status != noErr_ { break }
        let x = _PCM.read(list, c.from, frames: Int(packets))
        let y = _PCM.adapt(x, from: c.from, to: c.to)
        for i in 0..<c.pending.count { c.pending[i] += y[min(i, y.count - 1)] }
    }
    let have = c.pending.first?.count ?? 0
    let n = _PCM.fill(UnsafeMutableAudioBufferListPointer(outOutputData), c.pending, c.to, from: 0, count: min(want, have))
    for i in 0..<c.pending.count { c.pending[i].removeFirst(min(n, c.pending[i].count)) }
    ioOutputDataPacketSize.pointee = UInt32(n)
    return n > 0 ? noErr_ : status
}

// MARK: - Audio Queue Services

public typealias AudioQueueOutputCallbackBlock = (AudioQueueRef, AudioQueueBufferRef) -> Void
public typealias AudioQueueInputCallbackBlock = (AudioQueueRef, AudioQueueBufferRef, UnsafePointer<AudioTimeStamp>, UInt32, UnsafePointer<AudioStreamPacketDescription>?) -> Void

final class _AudioQueue: @unchecked Sendable {
    let input: Bool
    let format: AudioStreamBasicDescription
    var out: ((AudioQueueRef, AudioQueueBufferRef) -> Void)?
    var inp: AudioQueueInputCallbackBlock?
    let callbackQueue: DispatchQueue?
    var handle: AudioQueueRef!
    var buffers: [AudioQueueBufferRef] = []
    var queued: [AudioQueueBufferRef] = []
    let lock = NSCondition()
    var running = false, paused = false, stopping = false, disposed = false
    var threadRunning = false
    weak var loopThread: Thread?
    var volume: Float = 1
    var framesDone: Int64 = 0
    var stream: Int32 = 0
    var listeners: [(AudioQueuePropertyListenerProc, UnsafeMutableRawPointer?)] = []
    var metering = false
    var level = AudioQueueLevelMeterState(mAveragePower: 0, mPeakPower: 0)
    init(input: Bool, format: AudioStreamBasicDescription, queue: DispatchQueue?) { self.input = input; self.format = format; callbackQueue = queue }

    func deliver(_ b: AudioQueueBufferRef, _ t: AudioTimeStamp, _ packets: UInt32) {
        let call = { [self] in
            if input { var ts = t; inp?(handle, b, &ts, packets, nil) } else { out?(handle, b) }
        }
        if let q = callbackQueue { q.async(execute: call) } else { call() }
    }
    func setRunning(_ r: Bool) {
        running = r
        for (proc, data) in listeners { proc(data, handle, kAudioQueueProperty_IsRunning) }
    }
    func loop() {
        loopThread = Thread.current
        let rate = format.mSampleRate
        let t0 = Date().timeIntervalSince1970
        var paced = 0.0                   // seconds of audio handled since start (headless pacing)
        if input { _ = isim_audio_input_start() }
        while true {
            lock.lock()
            while (queued.isEmpty || paused) && !stopping && !disposed { lock.wait(until: Date().addingTimeInterval(0.05)) }
            if stopping || disposed { lock.unlock(); break }
            let b = queued.removeFirst()
            lock.unlock()
            if input {
                let frames = Int(b.pointee.mAudioDataBytesCapacity) / format._frameBytes
                let need = Int((Double(frames) * 48000 / rate).rounded(.up))
                var got: [Float] = []
                while got.count < need * 2 && !stopping && !disposed {
                    var tmp = [Float](repeating: 0, count: (need - got.count / 2) * 2)
                    let n = tmp.withUnsafeMutableBufferPointer { isim_audio_input_read($0.baseAddress!, need - got.count / 2) }
                    if n > 0 { got += tmp[0..<(n * 2)] } else { Thread.sleep(forTimeInterval: 0.01) }
                }
                if stopping || disposed { break }
                let st = [(0..<need).map { got[2 * $0] }, (0..<need).map { got[2 * $0 + 1] }]
                let y = _PCM.adapt(st, from: _PCM.hostFormat, to: format)
                let bytes = _PCM.encode(y.map { Array($0.prefix(frames)) }, format)
                bytes.withUnsafeBytes { b.pointee.mAudioData.copyMemory(from: $0.baseAddress!, byteCount: bytes.count) }
                b.pointee.mAudioDataByteSize = UInt32(bytes.count)
                meter(y)
                var ts = AudioTimeStamp(); ts.mSampleTime = Double(framesDone); ts.mFlags = .sampleTimeValid
                framesDone += Int64(frames)
                deliver(b, ts, UInt32(frames))
            } else {
                let x = _PCM.decode(UnsafeRawBufferPointer(start: b.pointee.mAudioData, count: Int(b.pointee.mAudioDataByteSize)), format)
                let frames = x.first?.count ?? 0
                meter(x)
                let st = _PCM.adapt(x, from: format, to: _PCM.hostFormat)
                let n = st.first?.count ?? 0
                if stream > 0 && n > 0 {
                    var inter = [Float](repeating: 0, count: n * 2)
                    for i in 0..<n { inter[2 * i] = st[0][i] * volume; inter[2 * i + 1] = st[1][i] * volume }
                    var done = 0
                    while done < n && !stopping && !disposed {
                        let w = inter.withUnsafeBufferPointer { isim_audio_stream_write(stream, $0.baseAddress! + 2 * done, n - done) }
                        done += w
                        if w == 0 { Thread.sleep(forTimeInterval: 0.005) }
                    }
                } else {
                    // no audio device: pace in real time
                    paced += Double(frames) / rate
                    let ahead = t0 + paced - Date().timeIntervalSince1970
                    if ahead > 0 { Thread.sleep(forTimeInterval: ahead) }
                }
                framesDone += Int64(frames)
                if !disposed { deliver(b, AudioTimeStamp(), 0) }
            }
        }
        if input { isim_audio_input_stop() }
    }
    func meter(_ x: [[Float]]) {
        guard metering, let c = x.first, !c.isEmpty else { return }
        var s: Float = 0, p: Float = 0
        for v in c { s += v * v; p = max(p, abs(v)) }
        level = AudioQueueLevelMeterState(mAveragePower: (s / Float(c.count)).squareRoot(), mPeakPower: p)
    }
    func start() -> OSStatus {
        lock.lock(); defer { lock.unlock() }
        if running { paused = false; if stream > 0 { isim_audio_stream_control(stream, 0, Double(volume)) }; lock.broadcast(); return noErr_ }
        stopping = false; paused = false
        if !input { stream = isim_audio_stream_open(1) }
        threadRunning = true
        setRunning(true)
        Thread.detachNewThread { [self] in loop(); lock.lock(); threadRunning = false; lock.unlock() }
        return noErr_
    }
    func stop() {
        lock.lock(); stopping = true; lock.broadcast(); lock.unlock()
        while Thread.current !== loopThread { lock.lock(); let r = threadRunning; lock.unlock(); if !r { break }; Thread.sleep(forTimeInterval: 0.005) }
        if stream > 0 { isim_audio_stream_close(stream); stream = 0 }
        lock.lock(); queued.removeAll(); lock.unlock()
        if running { setRunning(false) }
    }
}

public func AudioQueueNewOutput(_ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inCallbackProc: AudioQueueOutputCallback, _ inUserData: UnsafeMutableRawPointer?,
                                _ inCallbackRunLoop: AnyObject?, _ inCallbackRunLoopMode: CFString?, _ inFlags: UInt32,
                                _ outAQ: UnsafeMutablePointer<AudioQueueRef?>) -> OSStatus {
    guard _PCM.valid(inFormat.pointee) else { return kAudioFileUnsupportedDataFormatError }
    let q = _AudioQueue(input: false, format: inFormat.pointee, queue: inCallbackRunLoop != nil ? .main : nil)
    let ud = inUserData
    q.out = { aq, b in inCallbackProc(ud, aq, b) }
    q.handle = _handle(q); outAQ.pointee = q.handle
    return noErr_
}
public func AudioQueueNewOutputWithDispatchQueue(_ outAQ: UnsafeMutablePointer<AudioQueueRef?>, _ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inFlags: UInt32,
                                                 _ inCallbackDispatchQueue: DispatchQueue, _ inCallbackBlock: @escaping AudioQueueOutputCallbackBlock) -> OSStatus {
    guard _PCM.valid(inFormat.pointee) else { return kAudioFileUnsupportedDataFormatError }
    let q = _AudioQueue(input: false, format: inFormat.pointee, queue: inCallbackDispatchQueue)
    q.out = inCallbackBlock
    q.handle = _handle(q); outAQ.pointee = q.handle
    return noErr_
}
/// isim: input comes from the simulated microphone (ISIM_AUDIO_INPUT=file|mic; silence otherwise).
public func AudioQueueNewInput(_ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inCallbackProc: AudioQueueInputCallback, _ inUserData: UnsafeMutableRawPointer?,
                               _ inCallbackRunLoop: AnyObject?, _ inCallbackRunLoopMode: CFString?, _ inFlags: UInt32,
                               _ outAQ: UnsafeMutablePointer<AudioQueueRef?>) -> OSStatus {
    guard _PCM.valid(inFormat.pointee) else { return kAudioFileUnsupportedDataFormatError }
    let q = _AudioQueue(input: true, format: inFormat.pointee, queue: inCallbackRunLoop != nil ? .main : nil)
    let ud = inUserData
    q.inp = { aq, b, t, n, d in inCallbackProc(ud, aq, b, t, n, d) }
    q.handle = _handle(q); outAQ.pointee = q.handle
    return noErr_
}
public func AudioQueueNewInputWithDispatchQueue(_ outAQ: UnsafeMutablePointer<AudioQueueRef?>, _ inFormat: UnsafePointer<AudioStreamBasicDescription>, _ inFlags: UInt32,
                                                _ inCallbackDispatchQueue: DispatchQueue, _ inCallbackBlock: @escaping AudioQueueInputCallbackBlock) -> OSStatus {
    guard _PCM.valid(inFormat.pointee) else { return kAudioFileUnsupportedDataFormatError }
    let q = _AudioQueue(input: true, format: inFormat.pointee, queue: inCallbackDispatchQueue)
    q.inp = inCallbackBlock
    q.handle = _handle(q); outAQ.pointee = q.handle
    return noErr_
}
public func AudioQueueAllocateBuffer(_ inAQ: AudioQueueRef, _ inBufferByteSize: UInt32, _ outBuffer: UnsafeMutablePointer<AudioQueueBufferRef?>) -> OSStatus {
    AudioQueueAllocateBufferWithPacketDescriptions(inAQ, inBufferByteSize, 0, outBuffer)
}
public func AudioQueueAllocateBufferWithPacketDescriptions(_ inAQ: AudioQueueRef, _ inBufferByteSize: UInt32, _ inNumberPacketDescriptions: UInt32,
                                                           _ outBuffer: UnsafeMutablePointer<AudioQueueBufferRef?>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    let data = UnsafeMutableRawPointer.allocate(byteCount: max(1, Int(inBufferByteSize)), alignment: 16)
    let pd = inNumberPacketDescriptions > 0 ? UnsafeMutablePointer<AudioStreamPacketDescription>.allocate(capacity: Int(inNumberPacketDescriptions)) : nil
    let b = AudioQueueBufferRef.allocate(capacity: 1)
    b.initialize(to: AudioQueueBuffer(mAudioDataBytesCapacity: inBufferByteSize, mAudioData: data, mAudioDataByteSize: 0, mUserData: nil,
                                      mPacketDescriptionCapacity: inNumberPacketDescriptions, mPacketDescriptions: pd, mPacketDescriptionCount: 0))
    q.lock.lock(); q.buffers.append(b); q.lock.unlock()
    outBuffer.pointee = b
    return noErr_
}
public func AudioQueueFreeBuffer(_ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.lock.lock(); defer { q.lock.unlock() }
    guard let i = q.buffers.firstIndex(of: inBuffer) else { return kAudioQueueErr_InvalidBuffer }
    q.buffers.remove(at: i); q.queued.removeAll { $0 == inBuffer }
    inBuffer.pointee.mAudioData.deallocate(); inBuffer.pointee.mPacketDescriptions?.deallocate(); inBuffer.deallocate()
    return noErr_
}
public func AudioQueueEnqueueBuffer(_ inAQ: AudioQueueRef, _ inBuffer: AudioQueueBufferRef, _ inNumPacketDescs: UInt32,
                                    _ inPacketDescs: UnsafePointer<AudioStreamPacketDescription>?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.lock.lock(); defer { q.lock.unlock() }
    guard q.buffers.contains(inBuffer) else { return kAudioQueueErr_InvalidBuffer }
    if !q.input && inBuffer.pointee.mAudioDataByteSize == 0 { return kAudioQueueErr_BufferEmpty }
    q.queued.append(inBuffer); q.lock.broadcast()
    return noErr_
}
public func AudioQueuePrime(_ inAQ: AudioQueueRef, _ inNumberOfFramesToPrepare: UInt32, _ outNumberOfFramesPrepared: UnsafeMutablePointer<UInt32>?) -> OSStatus {
    outNumberOfFramesPrepared?.pointee = inNumberOfFramesToPrepare; return noErr_
}
public func AudioQueueStart(_ inAQ: AudioQueueRef, _ inStartTime: UnsafePointer<AudioTimeStamp>?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    return q.start()
}
public func AudioQueuePause(_ inAQ: AudioQueueRef) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.lock.lock(); q.paused = true; q.lock.unlock()
    if q.stream > 0 { isim_audio_stream_control(q.stream, 1, Double(q.volume)) }
    return noErr_
}
/// inImmediate false: plays what is queued first (isim waits for the queue to drain).
public func AudioQueueStop(_ inAQ: AudioQueueRef, _ inImmediate: Bool) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    if !inImmediate && !q.input {
        DispatchQueue.global().async {
            while true { q.lock.lock(); let empty = q.queued.isEmpty; q.lock.unlock(); if empty || q.disposed { break }; Thread.sleep(forTimeInterval: 0.01) }
            q.stop()
        }
        return noErr_
    }
    q.stop()
    return noErr_
}
public func AudioQueueFlush(_ inAQ: AudioQueueRef) -> OSStatus { noErr_ }
public func AudioQueueReset(_ inAQ: AudioQueueRef) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.lock.lock(); q.queued.removeAll(); q.lock.unlock()
    return noErr_
}
public func AudioQueueDispose(_ inAQ: AudioQueueRef, _ inImmediate: Bool) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.disposed = true
    q.stop()
    for b in q.buffers { b.pointee.mAudioData.deallocate(); b.pointee.mPacketDescriptions?.deallocate(); b.deallocate() }
    q.buffers.removeAll()
    _release(inAQ)
    return noErr_
}
public func AudioQueueSetParameter(_ inAQ: AudioQueueRef, _ inParamID: AudioQueueParameterID, _ inValue: AudioQueueParameterValue) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    switch inParamID {
    case kAudioQueueParam_Volume: q.volume = max(0, min(1, inValue))
    case kAudioQueueParam_PlayRate, kAudioQueueParam_Pitch, kAudioQueueParam_VolumeRampTime, kAudioQueueParam_Pan: break   // accepted, not applied
    default: return kAudioQueueErr_InvalidParameter
    }
    return noErr_
}
public func AudioQueueGetParameter(_ inAQ: AudioQueueRef, _ inParamID: AudioQueueParameterID, _ outValue: UnsafeMutablePointer<AudioQueueParameterValue>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    outValue.pointee = inParamID == kAudioQueueParam_Volume ? q.volume : inParamID == kAudioQueueParam_PlayRate ? 1 : 0
    return noErr_
}
public func AudioQueueGetProperty(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ outData: UnsafeMutableRawPointer, _ ioDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    switch inID {
    case kAudioQueueProperty_IsRunning: return _put(UInt32(q.running ? 1 : 0), ioDataSize, outData)
    case kAudioQueueProperty_StreamDescription: return _put(q.format, ioDataSize, outData)
    case kAudioQueueProperty_EnableLevelMetering: return _put(UInt32(q.metering ? 1 : 0), ioDataSize, outData)
    case kAudioQueueProperty_CurrentLevelMeter: return _put(q.level, ioDataSize, outData)
    default: return kAudioQueueErr_InvalidProperty
    }
}
public func AudioQueueGetPropertySize(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ outDataSize: UnsafeMutablePointer<UInt32>) -> OSStatus {
    switch inID {
    case kAudioQueueProperty_StreamDescription: outDataSize.pointee = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
    case kAudioQueueProperty_CurrentLevelMeter: outDataSize.pointee = UInt32(MemoryLayout<AudioQueueLevelMeterState>.size)
    default: outDataSize.pointee = 4
    }
    return noErr_
}
public func AudioQueueSetProperty(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inData: UnsafeRawPointer, _ inDataSize: UInt32) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    if inID == kAudioQueueProperty_EnableLevelMetering { q.metering = inData.load(as: UInt32.self) != 0; return noErr_ }
    return kAudioQueueErr_InvalidProperty
}
public func AudioQueueAddPropertyListener(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    guard inID == kAudioQueueProperty_IsRunning else { return kAudioQueueErr_InvalidProperty }
    q.listeners.append((inProc, inUserData))
    return noErr_
}
public func AudioQueueRemovePropertyListener(_ inAQ: AudioQueueRef, _ inID: AudioQueuePropertyID, _ inProc: AudioQueuePropertyListenerProc, _ inUserData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    q.listeners.removeAll { $0.1 == inUserData }
    return noErr_
}
/// Sample time of the audio played (or recorded) so far.
public func AudioQueueGetCurrentTime(_ inAQ: AudioQueueRef, _ inTimeline: OpaquePointer?, _ outTimeStamp: UnsafeMutablePointer<AudioTimeStamp>?,
                                     _ outTimelineDiscontinuity: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    guard let q = _object(inAQ, _AudioQueue.self) else { return kAudio_ParamError }
    var ts = AudioTimeStamp(); ts.mSampleTime = Double(q.framesDone); ts.mFlags = .sampleTimeValid
    outTimeStamp?.pointee = ts
    outTimelineDiscontinuity?.pointee = false
    return noErr_
}
