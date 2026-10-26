// isim AVFoundation (AVFAudio): channel layouts, compressed buffers and AVAudioConverter. Self-authored, iOS API names.
// - AVAudioConverter runs on AudioToolbox's AudioConverter (AudioServices.swift): linear PCM conversion (sample format,
//   interleaving, channels, sample rate) and AAC encoding / AAC and MP3 decoding through the host's libavcodec
//   (passthrough). convert(to:from:) converts PCM in one call without rate conversion, as on iOS.
// - Adapted: dither, priming and the sample rate converter's quality and algorithm are kept but not applied (isim has
//   one resampler); the bit rate strategy is kept, AAC encodes at a constant bit rate.
import Foundation
import AudioToolbox

public typealias AVAudioPacketCount = UInt32

// MARK: - channel layouts

/// A channel layout: a layout tag, or a bitmap or list of channel descriptions (AudioChannelLayout).
@objc(AVAudioChannelLayout) open class AVAudioChannelLayout: NSObject, NSSecureCoding, @unchecked Sendable {
    @objc let _storage: UnsafeMutableRawPointer
    @objc let _size: Int
    @objc static func size(descriptions n: Int) -> Int {
        MemoryLayout<AudioChannelLayout>.size + max(0, n - 1) * MemoryLayout<AudioChannelDescription>.stride
    }
    /// nil for the tags that need a bitmap or descriptions (UseChannelBitmap, UseChannelDescriptions)
    @objc public convenience init?(layoutTag: AudioChannelLayoutTag) {
        guard layoutTag != kAudioChannelLayoutTag_UseChannelDescriptions, layoutTag != kAudioChannelLayoutTag_UseChannelBitmap else { return nil }
        var l = AudioChannelLayout()
        l.mChannelLayoutTag = layoutTag
        self.init(layout: &l)
    }
    @objc public init(layout: UnsafePointer<AudioChannelLayout>) {
        let n = layout.pointee.mChannelLayoutTag == kAudioChannelLayoutTag_UseChannelDescriptions ? Int(layout.pointee.mNumberChannelDescriptions) : 0
        _size = Self.size(descriptions: n)
        _storage = calloc(1, _size)!
        _storage.copyMemory(from: UnsafeRawPointer(layout), byteCount: MemoryLayout<AudioChannelLayout>.size - MemoryLayout<AudioChannelDescription>.stride)
        let descs = UnsafeRawPointer(layout) + MemoryLayout<AudioChannelLayout>.offset(of: \.mChannelDescriptions)!
        _storage.advanced(by: MemoryLayout<AudioChannelLayout>.offset(of: \.mChannelDescriptions)!)
            .copyMemory(from: descs, byteCount: n * MemoryLayout<AudioChannelDescription>.stride)
        if n == 0 { _storage.assumingMemoryBound(to: AudioChannelLayout.self).pointee.mNumberChannelDescriptions = 0 }
    }
    deinit { free(_storage) }
    @objc open var layout: UnsafePointer<AudioChannelLayout> { UnsafePointer(_storage.assumingMemoryBound(to: AudioChannelLayout.self)) }
    @objc open var layoutTag: AudioChannelLayoutTag { layout.pointee.mChannelLayoutTag }
    @objc open var channelCount: AVAudioChannelCount {
        let l = layout.pointee
        switch l.mChannelLayoutTag {
        case kAudioChannelLayoutTag_UseChannelDescriptions: return l.mNumberChannelDescriptions
        case kAudioChannelLayoutTag_UseChannelBitmap: return UInt32(l.mChannelBitmap.rawValue.nonzeroBitCount)
        default: return AudioChannelLayoutTag_GetNumberOfChannels(l.mChannelLayoutTag)
        }
    }
    /// the layout's bytes (AVChannelLayoutKey)
    @objc var _data: Data { Data(bytes: _storage, count: _size) }
    @objc open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? AVAudioChannelLayout else { return false }
        return o._data == _data
    }
    @objc open override var hash: Int { Int(layoutTag) }
    @objc open override var description: String { "<AVAudioChannelLayout tag 0x\(String(layoutTag, radix: 16)), \(channelCount) channels>" }
    @objc public static var supportsSecureCoding: Bool { true }
    @objc open func encode(with coder: NSCoder) { coder.encode(_data, forKey: "layout") }
    @objc public required convenience init?(coder: NSCoder) {
        guard let d = coder.decodeObject(forKey: "layout") as? Data, d.count >= MemoryLayout<AudioChannelLayout>.size - MemoryLayout<AudioChannelDescription>.stride else { return nil }
        var buf = [UInt8](d) + [UInt8](repeating: 0, count: MemoryLayout<AudioChannelLayout>.size)
        self.init(layout: buf.withUnsafeMutableBytes { UnsafePointer($0.baseAddress!.assumingMemoryBound(to: AudioChannelLayout.self)) })
        _ = buf
    }
}

// MARK: - compressed buffers

/// Packets of a compressed format (AAC, ALAC, ...) with their packet descriptions.
@objc(AVAudioCompressedBuffer) open class AVAudioCompressedBuffer: AVAudioBuffer {
    @objc public let packetCapacity: AVAudioPacketCount
    @objc public let maximumPacketSize: Int
    @objc public let byteCapacity: UInt32
    @objc public let data: UnsafeMutableRawPointer
    @objc open var packetCount: AVAudioPacketCount = 0
    @objc open var byteLength: UInt32 = 0
    @objc let _descs: UnsafeMutablePointer<AudioStreamPacketDescription>?
    /// formats with variable packet sizes (AAC): `maximumPacketSize` bytes per packet at most
    @objc public init(format: AVAudioFormat, packetCapacity: AVAudioPacketCount, maximumPacketSize: Int) {
        self.packetCapacity = packetCapacity
        let constant = Int(format.streamDescription.pointee.mBytesPerPacket)
        self.maximumPacketSize = constant > 0 ? constant : maximumPacketSize
        byteCapacity = UInt32(max(1, Int(packetCapacity) * self.maximumPacketSize))
        data = calloc(1, Int(byteCapacity))!
        if constant == 0 {
            _descs = .allocate(capacity: max(1, Int(packetCapacity)))
            _descs!.initialize(repeating: AudioStreamPacketDescription(), count: max(1, Int(packetCapacity)))
        } else { _descs = nil }
        super.init(format: format)
    }
    /// formats with a constant packet size (bytes per packet in the stream description)
    @objc public convenience init(format: AVAudioFormat, packetCapacity: AVAudioPacketCount) {
        self.init(format: format, packetCapacity: packetCapacity, maximumPacketSize: Int(format.streamDescription.pointee.mBytesPerPacket))
    }
    deinit { free(data); _descs?.deallocate() }
    @objc open var packetDescriptions: UnsafeMutablePointer<AudioStreamPacketDescription>? { _descs }
    var _abl: UnsafeMutableAudioBufferListPointer?
    @objc open override var mutableAudioBufferList: UnsafeMutablePointer<AudioBufferList> {
        if _abl == nil { _abl = AudioBufferList.allocate(maximumBuffers: 1) }
        _abl![0] = AudioBuffer(mNumberChannels: format.channelCount, mDataByteSize: byteLength, mData: data)
        return _abl!.unsafeMutablePointer
    }
    @objc open override func copy(with zone: NSZone? = nil) -> Any {
        let b = AVAudioCompressedBuffer(format: format, packetCapacity: packetCapacity, maximumPacketSize: maximumPacketSize)
        b.data.copyMemory(from: data, byteCount: Int(byteLength))
        if let s = _descs, let d = b._descs { d.update(from: s, count: Int(packetCount)) }
        b.packetCount = packetCount; b.byteLength = byteLength
        return b
    }
    @objc open override func mutableCopy(with zone: NSZone? = nil) -> Any { copy(with: zone) }
}

// MARK: - converter

public enum AVAudioConverterPrimeMethod: Int, @unchecked Sendable { case pre = 0, normal = 1, none = 2 }
public struct AVAudioConverterPrimeInfo: Sendable, Equatable {
    public var leadingFrames: AVAudioFrameCount
    public var trailingFrames: AVAudioFrameCount
    public init() { leadingFrames = 0; trailingFrames = 0 }
    public init(leadingFrames: AVAudioFrameCount, trailingFrames: AVAudioFrameCount) { self.leadingFrames = leadingFrames; self.trailingFrames = trailingFrames }
}
public enum AVAudioConverterInputStatus: Int, @unchecked Sendable { case haveData = 0, noDataNow = 1, endOfStream = 2 }
public enum AVAudioConverterOutputStatus: Int, @unchecked Sendable { case haveData = 0, inputRanDry = 1, endOfStream = 2, error = 3 }
public typealias AVAudioConverterInputBlock = (AVAudioPacketCount, UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer?

public let AVSampleRateConverterAlgorithm_Normal = "AVSampleRateConverterAlgorithm_Normal"
public let AVSampleRateConverterAlgorithm_Mastering = "AVSampleRateConverterAlgorithm_Mastering"
public let AVSampleRateConverterAlgorithm_MinimumPhase = "AVSampleRateConverterAlgorithm_MinimumPhase"
public let AVAudioBitRateStrategy_Constant = "AVAudioBitRateStrategy_Constant"
public let AVAudioBitRateStrategy_LongTermAverage = "AVAudioBitRateStrategy_LongTermAverage"
public let AVAudioBitRateStrategy_VariableConstrained = "AVAudioBitRateStrategy_VariableConstrained"
public let AVAudioBitRateStrategy_Variable = "AVAudioBitRateStrategy_Variable"
public let AVEncoderBitRateStrategyKey = "AVEncoderBitRateStrategyKey"
public let AVEncoderBitRatePerChannelKey = "AVEncoderBitRatePerChannelKey"

/// what the input proc reports while a convert call runs
final class _ConverterInput {
    let block: AVAudioConverterInputBlock
    var current: AVAudioBuffer?                     // kept alive while the converter reads it
    var noDataNow = false, ended = false
    init(_ b: @escaping AVAudioConverterInputBlock) { block = b }
}
private let _noDataNowStatus: OSStatus = 0x6E6F_646E          // 'nodn': ends one call, not the stream

private let _converterInputProc: AudioConverterComplexInputDataProc = { _, ioPackets, ioData, outDescs, user in
    let input = Unmanaged<_ConverterInput>.fromOpaque(user!).takeUnretainedValue()
    if input.ended { ioPackets.pointee = 0; return noErr }
    var status = AVAudioConverterInputStatus.haveData
    let buffer = input.block(ioPackets.pointee, &status)
    input.current = buffer
    switch status {
    case .noDataNow: input.noDataNow = true; ioPackets.pointee = 0; return _noDataNowStatus
    case .endOfStream: input.ended = true; ioPackets.pointee = 0; return noErr
    case .haveData: break
    }
    let list = UnsafeMutableAudioBufferListPointer(ioData)
    if let pcm = buffer as? AVAudioPCMBuffer {
        let src = UnsafeMutableAudioBufferListPointer(pcm.mutableAudioBufferList)
        for i in 0..<min(list.count, src.count) { list[i] = src[i] }
        ioPackets.pointee = pcm.frameLength
    } else if let c = buffer as? AVAudioCompressedBuffer {
        list[0] = AudioBuffer(mNumberChannels: c.format.channelCount, mDataByteSize: c.byteLength, mData: c.data)
        outDescs?.pointee = c.packetDescriptions
        ioPackets.pointee = c.packetCount
    } else { ioPackets.pointee = 0; input.ended = true }
    if ioPackets.pointee == 0 { input.ended = true }
    return noErr
}

@objc(AVAudioConverter) open class AVAudioConverter: NSObject {
    @objc public let inputFormat: AVAudioFormat
    @objc public let outputFormat: AVAudioFormat
    @objc var _ref: AudioConverterRef?
    @objc var _ended = false
    @objc(initFromFormat:toFormat:) public init?(from fromFormat: AVAudioFormat, to toFormat: AVAudioFormat) {
        inputFormat = fromFormat; outputFormat = toFormat
        var ref: AudioConverterRef?
        guard AudioConverterNew(fromFormat.streamDescription, toFormat.streamDescription, &ref) == noErr, let ref else { return nil }
        _ref = ref
        super.init()
        if let cookie = fromFormat.magicCookie { magicCookie = cookie }
        primeMethod = fromFormat._isPCM && toFormat._isPCM ? .none : .normal
    }
    deinit { if let r = _ref { AudioConverterDispose(r) } }
    /// back to the start of a stream (after endOfStream, or to drop buffered input)
    @objc open func reset() { if let r = _ref { AudioConverterReset(r) }; _ended = false }

    /// for each output channel the input channel it takes (-1: silence); empty: the default mapping
    @objc open var channelMap: [NSNumber] = []
    /// mix all input channels down when the output has fewer (otherwise the first ones are kept)
    @objc open var downmix = false
    @objc open var dither = false
    @objc open var sampleRateConverterQuality: Int = AVAudioQuality.max.rawValue
    @objc open var sampleRateConverterAlgorithm: String? = AVSampleRateConverterAlgorithm_Normal
    open var primeMethod: AVAudioConverterPrimeMethod = .normal
    open var primeInfo: AVAudioConverterPrimeInfo {
        get {
            guard let r = _ref else { return AVAudioConverterPrimeInfo() }
            var p: (UInt32, UInt32) = (0, 0), size: UInt32 = 8           // AudioConverterPrimeInfo: leading, trailing frames
            _ = withUnsafeMutableBytes(of: &p) { AudioConverterGetProperty(r, kAudioConverterPrimeInfo, &size, $0.baseAddress!) }
            return _primeInfo ?? AVAudioConverterPrimeInfo(leadingFrames: p.0, trailingFrames: p.1)
        }
        set { _primeInfo = newValue }
    }
    var _primeInfo: AVAudioConverterPrimeInfo?
    /// the codec's magic cookie: the encoder's (an esds) when encoding; set the decoder's when decoding
    @objc open var magicCookie: Data? {
        get {
            guard let r = _ref else { return _cookie }
            var size: UInt32 = 0
            guard AudioConverterGetPropertyInfo(r, kAudioConverterCompressionMagicCookie, &size, nil) == noErr, size > 0 else { return _cookie }
            var bytes = [UInt8](repeating: 0, count: Int(size))
            guard AudioConverterGetProperty(r, kAudioConverterCompressionMagicCookie, &size, &bytes) == noErr else { return _cookie }
            return Data(bytes.prefix(Int(size)))
        }
        set {
            _cookie = newValue
            guard let r = _ref, let d = newValue else { return }
            _ = d.withUnsafeBytes { AudioConverterSetProperty(r, kAudioConverterDecompressionMagicCookie, UInt32(d.count), $0.baseAddress!) }
        }
    }
    @objc var _cookie: Data?
    @objc open var maximumOutputPacketSize: Int {
        guard let r = _ref else { return 0 }
        var v: UInt32 = 0, size: UInt32 = 4
        _ = AudioConverterGetProperty(r, kAudioConverterPropertyMaximumOutputPacketSize, &size, &v)
        return Int(v)
    }
    @objc var _encodes: Bool { inputFormat._isPCM && !outputFormat._isPCM }
    /// the encoder's bit rate (bits per second); 0 when not encoding
    @objc open var bitRate: Int {
        get {
            guard _encodes, let r = _ref else { return 0 }
            var v: UInt32 = 0, size: UInt32 = 4
            _ = AudioConverterGetProperty(r, kAudioConverterEncodeBitRate, &size, &v)
            return Int(v)
        }
        set {
            guard _encodes, let r = _ref else { return }
            var v = UInt32(max(0, newValue))
            _ = AudioConverterSetProperty(r, kAudioConverterEncodeBitRate, 4, &v)
        }
    }
    @objc open var bitRateStrategy: String?
    @objc static let _aacRates: [NSNumber] = [8000, 11025, 12000, 16000, 22050, 24000, 32000, 44100, 48000]
    @objc var _aacBitRates: [NSNumber] {
        let ch = Int(max(1, outputFormat.channelCount))
        return [32000, 48000, 64000, 96000, 128000, 160000, 192000, 256000, 320000].filter { $0 <= 320000 * ch && $0 >= 16000 * ch }.map { NSNumber(value: $0) }
    }
    @objc open var availableEncodeBitRates: [NSNumber]? { _encodes ? _aacBitRates : nil }
    @objc open var applicableEncodeBitRates: [NSNumber]? { _encodes ? _aacBitRates : nil }
    @objc open var availableEncodeSampleRates: [NSNumber]? { _encodes ? Self._aacRates : nil }
    @objc open var applicableEncodeSampleRates: [NSNumber]? { _encodes ? Self._aacRates : nil }
    @objc open var availableEncodeChannelLayoutTags: [NSNumber]? {
        guard _encodes else { return nil }
        return [kAudioChannelLayoutTag_Mono, kAudioChannelLayoutTag_Stereo, kAudioChannelLayoutTag_AAC_3_0, kAudioChannelLayoutTag_AAC_4_0,
                kAudioChannelLayoutTag_AAC_5_0, kAudioChannelLayoutTag_AAC_5_1, kAudioChannelLayoutTag_AAC_6_0, kAudioChannelLayoutTag_AAC_6_1,
                kAudioChannelLayoutTag_AAC_7_0, kAudioChannelLayoutTag_AAC_7_1].map { NSNumber(value: $0) }
    }

    @objc static func _error(_ status: OSStatus) -> NSError { NSError(domain: NSOSStatusErrorDomain, code: Int(status)) }

    /// Linear PCM to linear PCM in one call: sample format, interleaving and channels (channelMap, downmix), at the
    /// same sample rate (as on iOS; use convert(to:error:withInputFrom:) to resample).
    @objc(convertToBuffer:fromBuffer:error:) open func convert(to outputBuffer: AVAudioPCMBuffer, from inputBuffer: AVAudioPCMBuffer) throws {
        guard inputFormat._isPCM, outputFormat._isPCM, inputFormat.sampleRate == outputFormat.sampleRate else {
            throw Self._error(kAudioConverterErr_FormatNotSupported)
        }
        guard inputBuffer.format.isEqual(inputFormat), outputBuffer.format.isEqual(outputFormat) else { throw Self._error(kAudio_ParamError) }
        let n = Int(inputBuffer.frameLength)
        guard n <= Int(outputBuffer.frameCapacity) else { throw Self._error(kAudioConverterErr_InvalidOutputSize) }
        inputBuffer._syncFromRaw()
        let x = inputBuffer.channels.map { Array(UnsafeBufferPointer(start: $0, count: n)) }
        let y = _map(x, outputs: Int(outputFormat.channelCount), frames: n)
        for (c, dst) in outputBuffer.channels.enumerated() { y[c].withUnsafeBufferPointer { dst.update(from: $0.baseAddress!, count: n) } }
        outputBuffer.frameLength = AVAudioFrameCount(n)
        outputBuffer._syncToRaw()
    }
    /// the output channels from the input ones: channelMap, else downmix (averaging), mono to every channel, or the
    /// first channels (extra outputs silent)
    @objc func _map(_ x: [[Float]], outputs: Int, frames n: Int) -> [[Float]] {
        let silence = [Float](repeating: 0, count: n)
        if !channelMap.isEmpty {
            return (0..<outputs).map { c in
                let k = c < channelMap.count ? Int(channelMap[c].intValue) : -1
                return k >= 0 && k < x.count ? x[k] : silence
            }
        }
        if x.count == 1 { return [[Float]](repeating: x[0], count: outputs) }
        if outputs < x.count && downmix {
            if outputs == 1 {
                var m = silence
                for ch in x { for i in 0..<n { m[i] += ch[i] } }
                let k = 1 / Float(x.count)
                return [m.map { $0 * k }]
            }
            // to stereo (or more): fold the extra channels into the first ones in turn
            var out = Array(x.prefix(outputs))
            var counts = [Float](repeating: 1, count: outputs)
            for (j, ch) in x.enumerated().dropFirst(outputs) {
                let t = j % outputs
                for i in 0..<n { out[t][i] += ch[i] }
                counts[t] += 1
            }
            for t in 0..<outputs { let k = 1 / counts[t]; out[t] = out[t].map { $0 * k } }
            return out
        }
        return (0..<outputs).map { $0 < x.count ? x[$0] : silence }
    }

    /// Converts what `inputBlock` supplies (on demand) into `outputBuffer`: PCM or compressed, with rate conversion,
    /// encoding and decoding. Returns haveData, inputRanDry (the block had no data now), endOfStream or error.
    open func convert(to outputBuffer: AVAudioBuffer, error outError: NSErrorPointer, withInputFrom inputBlock: @escaping AVAudioConverterInputBlock) -> AVAudioConverterOutputStatus {
        guard let r = _ref else { outError?.pointee = Self._error(kAudio_ParamError); return .error }
        if _ended { return .endOfStream }
        let input = _ConverterInput(inputBlock)
        let user = Unmanaged.passUnretained(input).toOpaque()
        var status: OSStatus
        var packets: UInt32
        if let pcm = outputBuffer as? AVAudioPCMBuffer {
            pcm.frameLength = pcm.frameCapacity
            packets = pcm.frameCapacity
            status = AudioConverterFillComplexBuffer(r, _converterInputProc, user, &packets, pcm.mutableAudioBufferList, nil)
            pcm.frameLength = packets
        } else if let c = outputBuffer as? AVAudioCompressedBuffer {
            let list = AudioBufferList.allocate(maximumBuffers: 1)
            defer { free(list.unsafeMutablePointer) }
            list[0] = AudioBuffer(mNumberChannels: c.format.channelCount, mDataByteSize: c.byteCapacity, mData: c.data)
            packets = c.packetCapacity
            status = AudioConverterFillComplexBuffer(r, _converterInputProc, user, &packets, list.unsafeMutablePointer, c.packetDescriptions)
            c.packetCount = packets
            c.byteLength = packets > 0 ? list[0].mDataByteSize : 0
            if c.packetDescriptions == nil { c.byteLength = packets * UInt32(c.maximumPacketSize) }
        } else {
            outError?.pointee = Self._error(kAudio_ParamError)
            return .error
        }
        input.current = nil
        if status != noErr && status != _noDataNowStatus {
            outError?.pointee = Self._error(status)
            return .error
        }
        if input.noDataNow { return .inputRanDry }
        if packets == 0 { _ended = true; return .endOfStream }
        return .haveData
    }
}

