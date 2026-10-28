// isim AudioToolbox: Audio File Streams (AudioFileStreamOpen and friends). Adapted: isim's own incremental parser for
// WAV, AIFF/AIFC and CAF (PCM, and CAF's packet table for compressed data), MP3 (MPEG audio frames, an ID3v2 tag
// skipped) and ADTS AAC (raw packets without their ADTS headers, with an AudioSpecificConfig magic cookie). Bytes
// arrive in any pieces; properties are reported as soon as they are known (ReadyToProducePackets last), then packets,
// with packet descriptions for variable-size formats.
import Foundation

public let kAudioFileStreamError_UnsupportedFileType: OSStatus = 0x7479_703F      // 'typ?'
public let kAudioFileStreamError_UnsupportedDataFormat: OSStatus = 0x666D_743F    // 'fmt?'
public let kAudioFileStreamError_UnsupportedProperty: OSStatus = 0x7074_793F      // 'pty?'
public let kAudioFileStreamError_BadPropertySize: OSStatus = 0x2173_697A          // '!siz'
public let kAudioFileStreamError_NotOptimized: OSStatus = 0x6F70_746D             // 'optm'
public let kAudioFileStreamError_InvalidPacketOffset: OSStatus = 0x7063_6B3F      // 'pck?'
public let kAudioFileStreamError_InvalidFile: OSStatus = 0x6474_613F              // 'dta?'
public let kAudioFileStreamError_ValueUnknown: OSStatus = 0x756E_6B3F             // 'unk?'
public let kAudioFileStreamError_DataUnavailable: OSStatus = 0x6D6F_7265          // 'more'
public let kAudioFileStreamError_IllegalOperation: OSStatus = 0x6E6F_7065         // 'nope'
public let kAudioFileStreamError_UnspecifiedError: OSStatus = 0x7768_743F         // 'wht?'
public let kAudioFileStreamError_DiscontinuityCantRecover: OSStatus = 0x6473_6321 // 'dsc!'

public let kAudioFileStreamProperty_ReadyToProducePackets: AudioFileStreamPropertyID = 0x7265_6479   // 'redy'
public let kAudioFileStreamProperty_FileFormat: AudioFileStreamPropertyID = 0x6666_6D74               // 'ffmt'
public let kAudioFileStreamProperty_DataFormat: AudioFileStreamPropertyID = 0x6466_6D74               // 'dfmt'
public let kAudioFileStreamProperty_FormatList: AudioFileStreamPropertyID = 0x666C_7374               // 'flst'
public let kAudioFileStreamProperty_MagicCookieData: AudioFileStreamPropertyID = 0x6D67_6963          // 'mgic'
public let kAudioFileStreamProperty_AudioDataByteCount: AudioFileStreamPropertyID = 0x6263_6E74       // 'bcnt'
public let kAudioFileStreamProperty_AudioDataPacketCount: AudioFileStreamPropertyID = 0x7063_6E74     // 'pcnt'
public let kAudioFileStreamProperty_MaximumPacketSize: AudioFileStreamPropertyID = 0x7073_7A65        // 'psze'
public let kAudioFileStreamProperty_DataOffset: AudioFileStreamPropertyID = 0x646F_6666               // 'doff'
public let kAudioFileStreamProperty_ChannelLayout: AudioFileStreamPropertyID = 0x636D_6170            // 'cmap'
public let kAudioFileStreamProperty_PacketToFrame: AudioFileStreamPropertyID = 0x706B_6672            // 'pkfr'
public let kAudioFileStreamProperty_FrameToPacket: AudioFileStreamPropertyID = 0x6672_706B            // 'frpk'
public let kAudioFileStreamProperty_RestrictsRandomAccess: AudioFileStreamPropertyID = 0x7272_6170    // 'rrap'
public let kAudioFileStreamProperty_PacketToRollDistance: AudioFileStreamPropertyID = 0x706B_726C     // 'pkrl'
public let kAudioFileStreamProperty_PreviousIndependentPacket: AudioFileStreamPropertyID = 0x7069_6E64 // 'pind'
public let kAudioFileStreamProperty_NextIndependentPacket: AudioFileStreamPropertyID = 0x6E69_6E64    // 'nind'
public let kAudioFileStreamProperty_PacketToDependencyInfo: AudioFileStreamPropertyID = 0x706B_6470   // 'pkdp'
public let kAudioFileStreamProperty_PacketToByte: AudioFileStreamPropertyID = 0x706B_6279             // 'pkby'
public let kAudioFileStreamProperty_ByteToPacket: AudioFileStreamPropertyID = 0x6279_706B             // 'bypk'
public let kAudioFileStreamProperty_PacketTableInfo: AudioFileStreamPropertyID = 0x706E_666F          // 'pnfo'
public let kAudioFileStreamProperty_PacketSizeUpperBound: AudioFileStreamPropertyID = 0x706B_7562     // 'pkub'
public let kAudioFileStreamProperty_AverageBytesPerPacket: AudioFileStreamPropertyID = 0x6162_7070    // 'abpp'
public let kAudioFileStreamProperty_BitRate: AudioFileStreamPropertyID = 0x6272_6174                  // 'brat'
public let kAudioFileStreamProperty_InfoDictionary: AudioFileStreamPropertyID = 0x696E_666F           // 'info'

final class _AudioFileStream {
    let client: UnsafeMutableRawPointer?
    let propertyProc: AudioFileStream_PropertyListenerProc
    let packetsProc: AudioFileStream_PacketsProc
    var type: AudioFileTypeID
    var buffer: [UInt8] = []
    var consumed: Int64 = 0                     // stream bytes before buffer[0]
    var ready = false
    var format = AudioStreamBasicDescription()
    var dataOffset: Int64 = 0
    var byteCount: Int64?, packetCount: Int64?
    var maxPacket: UInt32 = 0
    var cookie: [UInt8] = []
    var info: [String: Any] = [:]
    var tableInfo: AudioFilePacketTableInfo?
    var cafPacketSizes: [Int] = []              // CAF packet table (variable packets)
    var packetIndex: Int64 = 0                  // packets delivered (for CAF tables)
    var dataEnd: Int64 = .max
    var headerDone = false
    var bitRate: UInt32 = 0
    var packetsSeen: Int64 = 0, bytesSeen: Int64 = 0
    var packetOffsets: [Int64] = []             // byte offsets of the packets seen (variable packets)
    var cached: Set<AudioFileStreamPropertyID> = []
    init(_ c: UnsafeMutableRawPointer?, _ p: @escaping AudioFileStream_PropertyListenerProc, _ k: @escaping AudioFileStream_PacketsProc, _ t: AudioFileTypeID) {
        client = c; propertyProc = p; packetsProc = k; type = t
    }
    var handle: AudioFileStreamID { AudioFileStreamID(Unmanaged.passUnretained(self).toOpaque()) }
    static func from(_ h: AudioFileStreamID) -> _AudioFileStream { Unmanaged<_AudioFileStream>.fromOpaque(UnsafeRawPointer(h)).takeUnretainedValue() }

    func announce(_ id: AudioFileStreamPropertyID) {
        var flags = AudioFileStreamPropertyFlags()
        propertyProc(client ?? UnsafeMutableRawPointer(bitPattern: 1)!, handle, id, &flags)
        if flags.contains(.cacheProperty) { cached.insert(id) }
    }
    var variable: Bool { format.mBytesPerPacket == 0 }

    // MARK: parsing

    func parse() -> OSStatus {
        if !headerDone {
            let st = parseHeader()
            if st != noErr_ { return st }
            if !headerDone { return noErr_ }      // more bytes needed
        }
        deliverPackets()
        return noErr_
    }
    func be16(_ o: Int) -> Int { Int(buffer[o]) << 8 | Int(buffer[o + 1]) }
    func be32(_ o: Int) -> Int { be16(o) << 16 | be16(o + 2) }
    func be64(_ o: Int) -> Int64 { Int64(be32(o)) << 32 | Int64(be32(o + 4)) }
    func le16(_ o: Int) -> Int { Int(buffer[o]) | Int(buffer[o + 1]) << 8 }
    func le32(_ o: Int) -> Int { le16(o) | le16(o + 2) << 16 }
    func tag(_ o: Int) -> String { String(bytes: buffer[o..<o + 4], encoding: .ascii) ?? "" }

    func sniff() -> AudioFileTypeID {
        guard buffer.count >= 12 else { return 0 }
        if tag(0) == "RIFF" && tag(8) == "WAVE" { return kAudioFileWAVEType }
        if tag(0) == "FORM" && tag(8) == "AIFF" { return kAudioFileAIFFType }
        if tag(0) == "FORM" && tag(8) == "AIFC" { return kAudioFileAIFCType }
        if tag(0) == "caff" { return kAudioFileCAFType }
        if tag(0).hasPrefix("ID3") { return kAudioFileMP3Type }
        if buffer[0] == 0xFF && buffer[1] & 0xF6 == 0xF0 { return kAudioFileAAC_ADTSType }
        if buffer[0] == 0xFF && buffer[1] & 0xE0 == 0xE0 { return kAudioFileMP3Type }
        return 0
    }

    func parseHeader() -> OSStatus {
        if type == 0 || ![kAudioFileWAVEType, kAudioFileAIFFType, kAudioFileAIFCType, kAudioFileCAFType, kAudioFileMP3Type, kAudioFileAAC_ADTSType].contains(type) {
            if buffer.count < 12 { return noErr_ }
            type = sniff()
            if type == 0 { return kAudioFileStreamError_UnsupportedFileType }
        } else if buffer.count >= 12 {
            let s = sniff()
            if s != 0 { type = s }
        }
        switch type {
        case kAudioFileWAVEType: return parseRIFF()
        case kAudioFileAIFFType, kAudioFileAIFCType: return parseAIFF()
        case kAudioFileCAFType: return parseCAF()
        case kAudioFileMP3Type, kAudioFileAAC_ADTSType: return parseFrames()
        default: return kAudioFileStreamError_UnsupportedFileType
        }
    }

    func becomeReady(dataAt offset: Int) {
        // the header is consumed: the buffer starts with audio data
        dataOffset = consumed + Int64(offset)
        buffer.removeFirst(offset)
        consumed = dataOffset
        headerDone = true
        announce(kAudioFileStreamProperty_FileFormat)
        announce(kAudioFileStreamProperty_DataFormat)
        if !cookie.isEmpty { announce(kAudioFileStreamProperty_MagicCookieData) }
        announce(kAudioFileStreamProperty_DataOffset)
        if byteCount != nil { announce(kAudioFileStreamProperty_AudioDataByteCount) }
        if packetCount != nil { announce(kAudioFileStreamProperty_AudioDataPacketCount) }
        if maxPacket > 0 { announce(kAudioFileStreamProperty_MaximumPacketSize) }
        ready = true
        announce(kAudioFileStreamProperty_ReadyToProducePackets)
    }

    func parseRIFF() -> OSStatus {
        var o = 12
        var fmt = false
        while o + 8 <= buffer.count {
            let id = tag(o), size = le32(o + 4)
            if id == "data" {
                guard fmt else { return kAudioFileStreamError_InvalidFile }
                byteCount = Int64(size)
                packetCount = Int64(size) / Int64(max(1, format.mBytesPerPacket))
                dataEnd = consumed + Int64(o + 8) + Int64(size)
                becomeReady(dataAt: o + 8)
                return noErr_
            }
            guard o + 8 + size <= buffer.count else { return noErr_ }
            if id == "fmt " && size >= 16 {
                let tagID = le16(o + 8), ch = le16(o + 10), rate = le32(o + 12), bits = le16(o + 22)
                guard tagID == 1 || tagID == 3 || tagID == 0xFFFE else { return kAudioFileStreamError_UnsupportedDataFormat }
                let float = tagID == 3 || (tagID == 0xFFFE && size >= 40 && le16(o + 32) == 3)
                format = _pcmFormat(rate: Double(rate), channels: ch, bits: bits, float: float)
                maxPacket = format.mBytesPerPacket
                bitRate = UInt32(rate * ch * bits)
                fmt = true
            }
            o += 8 + size + (size & 1)
        }
        return noErr_
    }

    func parseAIFF() -> OSStatus {
        var o = 12
        var comm = false
        while o + 8 <= buffer.count {
            let id = tag(o), size = be32(o + 4)
            if id == "SSND" {
                guard comm, o + 16 <= buffer.count else { return comm ? noErr_ : kAudioFileStreamError_InvalidFile }
                let offset = be32(o + 8)
                byteCount = Int64(size - 8 - offset)
                packetCount = byteCount! / Int64(max(1, format.mBytesPerPacket))
                dataEnd = consumed + Int64(o + 16 + offset) + byteCount!
                guard o + 16 + offset <= buffer.count else { return noErr_ }
                becomeReady(dataAt: o + 16 + offset)
                return noErr_
            }
            guard o + 8 + size <= buffer.count else { return noErr_ }
            if id == "COMM" && size >= 18 {
                let ch = be16(o + 8), bits = be16(o + 14)
                // the 80-bit extended rate
                let exp = be16(o + 16) & 0x7FFF, mant = UInt64(be32(o + 18)) << 32 | UInt64(be32(o + 22))
                let rate = Double(mant) * pow(2, Double(exp - 16383 - 63))
                if type == kAudioFileAIFCType && size >= 22 {
                    let comp = tag(o + 26)
                    guard comp == "NONE" || comp == "twos" || comp == "sowt" || comp == "fl32" else { return kAudioFileStreamError_UnsupportedDataFormat }
                    format = _pcmFormat(rate: rate, channels: ch, bits: comp == "fl32" ? 32 : bits, float: comp == "fl32", bigEndian: comp != "sowt")
                } else {
                    format = _pcmFormat(rate: rate, channels: ch, bits: bits, float: false, bigEndian: true)
                }
                maxPacket = format.mBytesPerPacket
                bitRate = UInt32(rate * Double(ch * bits))
                comm = true
            }
            o += 8 + size + (size & 1)
        }
        return noErr_
    }

    func parseCAF() -> OSStatus {
        var o = 8
        var desc = false
        while o + 12 <= buffer.count {
            let id = tag(o), size = be64(o + 4)
            if id == "data" {
                guard desc, o + 16 <= buffer.count else { return desc ? noErr_ : kAudioFileStreamError_InvalidFile }
                if size >= 4 { byteCount = size - 4; dataEnd = consumed + Int64(o + 16) + size - 4 }
                if !variable, let b = byteCount { packetCount = b / Int64(max(1, format.mBytesPerPacket)) }
                becomeReady(dataAt: o + 16)
                return noErr_
            }
            guard size >= 0, o + 12 + Int(size) <= buffer.count else { return noErr_ }
            let p = o + 12
            switch id {
            case "desc":
                let bits = UInt64(bitPattern: be64(p))
                format.mSampleRate = Double(bitPattern: bits)
                format.mFormatID = UInt32(be32(p + 8))
                format.mFormatFlags = UInt32(be32(p + 12))
                format.mBytesPerPacket = UInt32(be32(p + 16))
                format.mFramesPerPacket = UInt32(be32(p + 20))
                format.mChannelsPerFrame = UInt32(be32(p + 24))
                format.mBitsPerChannel = UInt32(be32(p + 28))
                if format.mFormatID == kAudioFormatLinearPCM {
                    // CAF's flags: little endian (2), float (1); isim's PCM is packed
                    let float = format.mFormatFlags & 1 != 0, little = format.mFormatFlags & 2 != 0
                    format = _pcmFormat(rate: format.mSampleRate, channels: Int(format.mChannelsPerFrame), bits: Int(format.mBitsPerChannel), float: float, bigEndian: !little)
                }
                format.mBytesPerFrame = format.mFramesPerPacket == 1 ? format.mBytesPerPacket : 0
                maxPacket = format.mBytesPerPacket
                desc = true
            case "kuki": cookie = [UInt8](buffer[p..<p + Int(size)])
            case "pakt" where size >= 24:
                packetCount = be64(p)
                tableInfo = AudioFilePacketTableInfo(mNumberValidFrames: be64(p + 8), mPrimingFrames: Int32(be32(p + 16)), mRemainderFrames: Int32(be32(p + 20)))
                var q = p + 24
                let end = p + Int(size)
                while q < end {
                    var v = 0
                    while q < end { let c = buffer[q]; q += 1; v = v << 7 | Int(c & 0x7F); if c & 0x80 == 0 { break } }
                    cafPacketSizes.append(v)
                }
                maxPacket = UInt32(cafPacketSizes.max() ?? 0)
            case "info":
                // string pairs: key NUL value NUL
                let parts = buffer[p + 4..<p + Int(size)].split(separator: 0, omittingEmptySubsequences: false).map { String(decoding: $0, as: UTF8.self) }
                var i = 0
                while i + 1 < parts.count { info[parts[i]] = parts[i + 1]; i += 2 }
            default: break
            }
            o += 12 + Int(size)
        }
        return noErr_
    }

    /// MP3 and ADTS: an ID3v2 tag, then frames
    func parseFrames() -> OSStatus {
        var o = 0
        if buffer.count >= 10 && tag(0).hasPrefix("ID3") {
            let size = Int(buffer[6] & 0x7F) << 21 | Int(buffer[7] & 0x7F) << 14 | Int(buffer[8] & 0x7F) << 7 | Int(buffer[9] & 0x7F)
            o = 10 + size + (buffer[5] & 0x10 != 0 ? 10 : 0)
            if o > buffer.count { return noErr_ }
        }
        // the first frame's header gives the format
        while o + 7 <= buffer.count {
            if type == kAudioFileAAC_ADTSType, let f = adts(o) {
                let freqs = [96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, 11025, 8000, 7350]
                format = AudioStreamBasicDescription()
                format.mSampleRate = Double(freqs[min(12, f.freq)])
                format.mFormatID = kAudioFormatMPEG4AAC
                format.mFormatFlags = UInt32(f.profile + 1)
                format.mFramesPerPacket = 1024
                format.mChannelsPerFrame = UInt32(max(1, f.channels))
                // AudioSpecificConfig: object type, frequency index, channel configuration
                let objectType = f.profile + 1
                cookie = [UInt8(objectType << 3 | f.freq >> 1), UInt8((f.freq & 1) << 7 | f.channels << 3)]
                maxPacket = 8191
                becomeReady(dataAt: o)
                return noErr_
            }
            if type == kAudioFileMP3Type, let f = mpeg(o) {
                format = AudioStreamBasicDescription()
                format.mSampleRate = Double(f.rate)
                format.mFormatID = kAudioFormatMPEGLayer3
                format.mFramesPerPacket = UInt32(f.samples)
                format.mChannelsPerFrame = UInt32(f.channels)
                maxPacket = 2881
                bitRate = UInt32(f.bitrate)
                becomeReady(dataAt: o)
                return noErr_
            }
            o += 1                                    // resynchronize
        }
        return noErr_
    }
    func adts(_ o: Int) -> (length: Int, header: Int, profile: Int, freq: Int, channels: Int)? {
        guard o + 7 <= buffer.count, buffer[o] == 0xFF, buffer[o + 1] & 0xF6 == 0xF0 else { return nil }
        let crc = buffer[o + 1] & 1 == 0
        let profile = Int(buffer[o + 2] >> 6), freq = Int(buffer[o + 2] >> 2 & 0x0F)
        let channels = Int(buffer[o + 2] & 1) << 2 | Int(buffer[o + 3] >> 6)
        let length = Int(buffer[o + 3] & 3) << 11 | Int(buffer[o + 4]) << 3 | Int(buffer[o + 5] >> 5)
        guard freq < 13, length >= 7 else { return nil }
        return (length, crc ? 9 : 7, profile, freq, channels)
    }
    func mpeg(_ o: Int) -> (length: Int, rate: Int, samples: Int, channels: Int, bitrate: Int)? {
        guard o + 4 <= buffer.count, buffer[o] == 0xFF, buffer[o + 1] & 0xE0 == 0xE0 else { return nil }
        let version = Int(buffer[o + 1] >> 3 & 3), layer = Int(buffer[o + 1] >> 1 & 3)
        let bitrateIndex = Int(buffer[o + 2] >> 4), rateIndex = Int(buffer[o + 2] >> 2 & 3), padding = Int(buffer[o + 2] >> 1 & 1)
        guard version != 1, layer == 1, bitrateIndex != 0, bitrateIndex != 15, rateIndex != 3 else { return nil }   // Layer III
        let v1 = version == 3
        let bitrates = v1 ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320] : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        let rates = [[11025, 12000, 8000], [0, 0, 0], [22050, 24000, 16000], [44100, 48000, 32000]][version]
        let rate = rates[rateIndex], bitrate = bitrates[bitrateIndex] * 1000
        let samples = v1 ? 1152 : 576
        let length = samples / 8 * bitrate / rate + padding
        let channels = buffer[o + 3] >> 6 == 3 ? 1 : 2
        return (length, rate, samples, channels, bitrate)
    }

    func deliverPackets() {
        if type == kAudioFileMP3Type || type == kAudioFileAAC_ADTSType { deliverFrames(); return }
        // the data chunk's bytes only
        let available = Int(min(Int64(buffer.count), max(0, dataEnd - consumed)))
        guard available > 0 else { return }
        if !variable {
            let bpp = Int(format.mBytesPerPacket)
            let n = available / bpp * bpp
            guard n > 0 else { return }
            buffer.withUnsafeBytes { packetsProc(client ?? UnsafeMutableRawPointer(bitPattern: 1)!, UInt32(n), UInt32(n / bpp), $0.baseAddress!, nil) }
            packetsSeen += Int64(n / bpp); bytesSeen += Int64(n)
            buffer.removeFirst(n); consumed += Int64(n)
        } else if !cafPacketSizes.isEmpty {
            var descs: [AudioStreamPacketDescription] = []
            var off = 0
            while Int(packetIndex) < cafPacketSizes.count, off + cafPacketSizes[Int(packetIndex)] <= available {
                let size = cafPacketSizes[Int(packetIndex)]
                descs.append(AudioStreamPacketDescription(mStartOffset: Int64(off), mVariableFramesInPacket: 0, mDataByteSize: UInt32(size)))
                packetOffsets.append(consumed - dataOffset + Int64(off))
                off += size; packetIndex += 1
            }
            guard !descs.isEmpty else { return }
            buffer.withUnsafeBytes { b in descs.withUnsafeMutableBufferPointer { packetsProc(client ?? UnsafeMutableRawPointer(bitPattern: 1)!, UInt32(off), UInt32($0.count), b.baseAddress!, $0.baseAddress) } }
            packetsSeen += Int64(descs.count); bytesSeen += Int64(off)
            buffer.removeFirst(off); consumed += Int64(off)
        }
    }
    func deliverFrames() {
        var o = 0
        var descs: [AudioStreamPacketDescription] = []
        var payload: [UInt8] = []
        let adtsStream = type == kAudioFileAAC_ADTSType
        while true {
            if adtsStream {
                guard let f = adts(o) else { if o + 7 <= buffer.count && buffer[o] != 0xFF { o += 1; continue } else { break } }
                guard o + f.length <= buffer.count else { break }
                descs.append(AudioStreamPacketDescription(mStartOffset: Int64(payload.count), mVariableFramesInPacket: 0, mDataByteSize: UInt32(f.length - f.header)))
                packetOffsets.append(consumed - dataOffset + Int64(o))
                payload += buffer[o + f.header..<o + f.length]
                o += f.length
            } else {
                guard let f = mpeg(o) else {
                    if o + 4 <= buffer.count && !(buffer[o] == 0xFF && buffer[o + 1] & 0xE0 == 0xE0) { o += 1; continue }
                    // a "TAG" (ID3v1) at the end, or bytes that are not a frame
                    if o + 4 <= buffer.count && mpeg(o) == nil && buffer[o] == 0xFF { o += 1; continue }
                    break
                }
                guard o + f.length <= buffer.count else { break }
                descs.append(AudioStreamPacketDescription(mStartOffset: Int64(payload.count), mVariableFramesInPacket: 0, mDataByteSize: UInt32(f.length)))
                packetOffsets.append(consumed - dataOffset + Int64(o))
                payload += buffer[o..<o + f.length]
                bitRate = UInt32(f.bitrate)
                o += f.length
            }
        }
        if !descs.isEmpty {
            payload.withUnsafeBytes { b in descs.withUnsafeMutableBufferPointer { packetsProc(client ?? UnsafeMutableRawPointer(bitPattern: 1)!, UInt32(payload.count), UInt32($0.count), b.baseAddress!, $0.baseAddress) } }
            packetsSeen += Int64(descs.count); bytesSeen += Int64(payload.count)
        }
        if o > 0 { buffer.removeFirst(o); consumed += Int64(o) }
    }
    var averageBytesPerPacket: Double {
        if !variable { return Double(format.mBytesPerPacket) }
        if packetsSeen > 0 { return Double(bytesSeen) / Double(packetsSeen) }
        if type == kAudioFileMP3Type, bitRate > 0, format.mSampleRate > 0 { return Double(bitRate) / 8 * Double(format.mFramesPerPacket) / format.mSampleRate }
        return 0
    }
}

public func AudioFileStreamOpen(_ inClientData: UnsafeMutableRawPointer?, _ inPropertyListenerProc: @escaping AudioFileStream_PropertyListenerProc,
                                _ inPacketsProc: @escaping AudioFileStream_PacketsProc, _ inFileTypeHint: AudioFileTypeID,
                                _ outAudioFileStream: UnsafeMutablePointer<AudioFileStreamID?>) -> OSStatus {
    let s = _AudioFileStream(inClientData, inPropertyListenerProc, inPacketsProc, inFileTypeHint)
    outAudioFileStream.pointee = AudioFileStreamID(Unmanaged.passRetained(s).toOpaque())
    return noErr_
}
public func AudioFileStreamParseBytes(_ inAudioFileStream: AudioFileStreamID, _ inDataByteSize: UInt32, _ inData: UnsafeRawPointer?, _ inFlags: AudioFileStreamParseFlags) -> OSStatus {
    let s = _AudioFileStream.from(inAudioFileStream)
    if inFlags.contains(.discontinuity) && s.headerDone && s.variable {
        // after a seek: frames resynchronize; CAF tables can't
        s.buffer = []
        if s.type == kAudioFileCAFType && !s.cafPacketSizes.isEmpty { return kAudioFileStreamError_DiscontinuityCantRecover }
    }
    guard inDataByteSize > 0, let inData else { return noErr_ }
    s.buffer += UnsafeRawBufferPointer(start: inData, count: Int(inDataByteSize))
    return s.parse()
}
public func AudioFileStreamSeek(_ inAudioFileStream: AudioFileStreamID, _ inPacketOffset: Int64, _ outDataByteOffset: UnsafeMutablePointer<Int64>,
                                _ ioFlags: UnsafeMutablePointer<AudioFileStreamSeekFlags>) -> OSStatus {
    let s = _AudioFileStream.from(inAudioFileStream)
    guard s.ready else { return kAudioFileStreamError_IllegalOperation }
    guard inPacketOffset >= 0 else { return kAudioFileStreamError_InvalidPacketOffset }
    ioFlags.pointee = []
    if !s.variable {
        outDataByteOffset.pointee = inPacketOffset * Int64(s.format.mBytesPerPacket)
    } else if !s.cafPacketSizes.isEmpty {
        guard inPacketOffset <= Int64(s.cafPacketSizes.count) else { return kAudioFileStreamError_InvalidPacketOffset }
        outDataByteOffset.pointee = Int64(s.cafPacketSizes.prefix(Int(inPacketOffset)).reduce(0, +))
        s.packetIndex = inPacketOffset
    } else if Int(inPacketOffset) < s.packetOffsets.count {
        outDataByteOffset.pointee = s.packetOffsets[Int(inPacketOffset)]
    } else {
        outDataByteOffset.pointee = Int64((Double(inPacketOffset) * s.averageBytesPerPacket).rounded())
        ioFlags.pointee = .offsetIsEstimated
    }
    s.buffer = []
    s.consumed = s.dataOffset + outDataByteOffset.pointee
    return noErr_
}
public func AudioFileStreamGetPropertyInfo(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID,
                                           _ outPropertyDataSize: UnsafeMutablePointer<UInt32>?, _ outWritable: UnsafeMutablePointer<DarwinBoolean>?) -> OSStatus {
    let s = _AudioFileStream.from(inAudioFileStream)
    let size: Int
    switch inPropertyID {
    case kAudioFileStreamProperty_ReadyToProducePackets, kAudioFileStreamProperty_FileFormat, kAudioFileStreamProperty_MaximumPacketSize,
         kAudioFileStreamProperty_PacketSizeUpperBound, kAudioFileStreamProperty_BitRate, kAudioFileStreamProperty_RestrictsRandomAccess: size = 4
    case kAudioFileStreamProperty_DataFormat: size = MemoryLayout<AudioStreamBasicDescription>.size
    case kAudioFileStreamProperty_FormatList: size = MemoryLayout<AudioFormatListItem>.size
    case kAudioFileStreamProperty_MagicCookieData:
        guard !s.cookie.isEmpty else { return kAudioFileStreamError_ValueUnknown }
        size = s.cookie.count
    case kAudioFileStreamProperty_AudioDataByteCount, kAudioFileStreamProperty_AudioDataPacketCount, kAudioFileStreamProperty_DataOffset: size = 8
    case kAudioFileStreamProperty_AverageBytesPerPacket: size = 8
    case kAudioFileStreamProperty_PacketToFrame, kAudioFileStreamProperty_FrameToPacket: size = MemoryLayout<AudioFramePacketTranslation>.size
    case kAudioFileStreamProperty_PacketToByte, kAudioFileStreamProperty_ByteToPacket: size = MemoryLayout<AudioBytePacketTranslation>.size
    case kAudioFileStreamProperty_PacketTableInfo:
        guard s.tableInfo != nil else { return kAudioFileStreamError_ValueUnknown }
        size = MemoryLayout<AudioFilePacketTableInfo>.size
    case kAudioFileStreamProperty_PacketToRollDistance: size = MemoryLayout<AudioPacketRollDistanceTranslation>.size
    case kAudioFileStreamProperty_PreviousIndependentPacket, kAudioFileStreamProperty_NextIndependentPacket: size = MemoryLayout<AudioIndependentPacketTranslation>.size
    case kAudioFileStreamProperty_PacketToDependencyInfo: size = MemoryLayout<AudioPacketDependencyInfoTranslation>.size
    case kAudioFileStreamProperty_InfoDictionary: size = MemoryLayout<UnsafeRawPointer>.size
    default: return kAudioFileStreamError_UnsupportedProperty
    }
    outPropertyDataSize?.pointee = UInt32(size)
    outWritable?.pointee = false
    return noErr_
}
public func AudioFileStreamGetProperty(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID,
                                       _ ioPropertyDataSize: UnsafeMutablePointer<UInt32>, _ outPropertyData: UnsafeMutableRawPointer) -> OSStatus {
    let s = _AudioFileStream.from(inAudioFileStream)
    func put<T>(_ v: T) -> OSStatus {
        guard ioPropertyDataSize.pointee >= UInt32(MemoryLayout<T>.size) else { return kAudioFileStreamError_BadPropertySize }
        outPropertyData.storeBytes(of: v, as: T.self)
        ioPropertyDataSize.pointee = UInt32(MemoryLayout<T>.size)
        return noErr_
    }
    func known() -> Bool { s.headerDone }
    switch inPropertyID {
    case kAudioFileStreamProperty_ReadyToProducePackets: return put(UInt32(s.ready ? 1 : 0))
    case kAudioFileStreamProperty_FileFormat: return s.type == 0 ? kAudioFileStreamError_ValueUnknown : put(s.type)
    case kAudioFileStreamProperty_DataFormat: return known() ? put(s.format) : kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_FormatList:
        return known() ? put(AudioFormatListItem(mASBD: s.format, mChannelLayoutTag: (100 << 16) | s.format.mChannelsPerFrame)) : kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_MagicCookieData:
        guard !s.cookie.isEmpty else { return kAudioFileStreamError_ValueUnknown }
        guard ioPropertyDataSize.pointee >= UInt32(s.cookie.count) else { return kAudioFileStreamError_BadPropertySize }
        s.cookie.withUnsafeBytes { outPropertyData.copyMemory(from: $0.baseAddress!, byteCount: s.cookie.count) }
        ioPropertyDataSize.pointee = UInt32(s.cookie.count)
        return noErr_
    case kAudioFileStreamProperty_AudioDataByteCount: return s.byteCount.map { put(UInt64($0)) } ?? kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_AudioDataPacketCount: return s.packetCount.map { put(UInt64($0)) } ?? kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_MaximumPacketSize, kAudioFileStreamProperty_PacketSizeUpperBound:
        return known() ? put(s.maxPacket) : kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_DataOffset: return known() ? put(s.dataOffset) : kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_BitRate:
        guard s.bitRate > 0 || s.averageBytesPerPacket > 0 else { return kAudioFileStreamError_ValueUnknown }
        let rate = s.bitRate > 0 ? s.bitRate : UInt32(s.averageBytesPerPacket * 8 * s.format.mSampleRate / Double(max(1, s.format.mFramesPerPacket)))
        return put(rate)
    case kAudioFileStreamProperty_AverageBytesPerPacket:
        let a = s.averageBytesPerPacket
        return a > 0 ? put(Float64(a)) : kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_RestrictsRandomAccess: return put(UInt32(0))
    case kAudioFileStreamProperty_PacketTableInfo: return s.tableInfo.map { put($0) } ?? kAudioFileStreamError_ValueUnknown
    case kAudioFileStreamProperty_PacketToFrame, kAudioFileStreamProperty_FrameToPacket:
        guard known(), ioPropertyDataSize.pointee >= UInt32(MemoryLayout<AudioFramePacketTranslation>.size) else { return kAudioFileStreamError_BadPropertySize }
        var t = outPropertyData.load(as: AudioFramePacketTranslation.self)
        let fpp = Int64(max(1, s.format.mFramesPerPacket))
        if inPropertyID == kAudioFileStreamProperty_PacketToFrame { t.mFrame = t.mPacket * fpp } else { t.mPacket = t.mFrame / fpp; t.mFrameOffsetInPacket = UInt32(t.mFrame % fpp) }
        return put(t)
    case kAudioFileStreamProperty_PacketToByte, kAudioFileStreamProperty_ByteToPacket:
        guard known(), ioPropertyDataSize.pointee >= UInt32(MemoryLayout<AudioBytePacketTranslation>.size) else { return kAudioFileStreamError_BadPropertySize }
        var t = outPropertyData.load(as: AudioBytePacketTranslation.self)
        let avg = s.averageBytesPerPacket
        guard avg > 0 else { return kAudioFileStreamError_ValueUnknown }
        if inPropertyID == kAudioFileStreamProperty_PacketToByte {
            if s.variable, Int(t.mPacket) < s.packetOffsets.count { t.mByte = s.packetOffsets[Int(t.mPacket)]; t.mFlags = [] }
            else { t.mByte = Int64(Double(t.mPacket) * avg); t.mFlags = s.variable ? .bytePacketTranslationFlag_IsEstimate : [] }
        } else {
            t.mPacket = Int64(Double(t.mByte) / avg)
            t.mByteOffsetInPacket = UInt32(Double(t.mByte) - Double(t.mPacket) * avg)
            t.mFlags = s.variable ? .bytePacketTranslationFlag_IsEstimate : []
        }
        return put(t)
    case kAudioFileStreamProperty_PacketToRollDistance:
        var t = outPropertyData.load(as: AudioPacketRollDistanceTranslation.self)
        t.mRollDistance = 0
        return put(t)
    case kAudioFileStreamProperty_PreviousIndependentPacket, kAudioFileStreamProperty_NextIndependentPacket:
        var t = outPropertyData.load(as: AudioIndependentPacketTranslation.self)
        t.mIndependentlyDecodablePacket = inPropertyID == kAudioFileStreamProperty_PreviousIndependentPacket ? max(0, t.mPacket - 1) : t.mPacket + 1
        return put(t)
    case kAudioFileStreamProperty_PacketToDependencyInfo:
        var t = outPropertyData.load(as: AudioPacketDependencyInfoTranslation.self)
        t.mIsIndependentlyDecodable = 1; t.mNumberPrerollPackets = 0
        return put(t)
    case kAudioFileStreamProperty_InfoDictionary:
        var d = s.info
        if s.bitRate > 0 { d["bit rate"] = String(s.bitRate) }
        return put(Unmanaged.passRetained(d as CFDictionary))
    default: return kAudioFileStreamError_UnsupportedProperty
    }
}
public func AudioFileStreamSetProperty(_ inAudioFileStream: AudioFileStreamID, _ inPropertyID: AudioFileStreamPropertyID, _ inPropertyDataSize: UInt32, _ inPropertyData: UnsafeRawPointer) -> OSStatus {
    kAudioFileStreamError_IllegalOperation
}
public func AudioFileStreamClose(_ inAudioFileStream: AudioFileStreamID) -> OSStatus {
    Unmanaged<_AudioFileStream>.fromOpaque(UnsafeRawPointer(inAudioFileStream)).release()
    return noErr_
}
