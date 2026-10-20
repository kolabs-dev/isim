// isim CoreAudioTypes, part of the AudioToolbox overlay (self-authored, iOS API names): the plain audio data types
// shared by AudioToolbox, CoreMedia and AVFoundation. The structs (AudioStreamBasicDescription, AudioBuffer,
// AudioBufferList, AudioStreamPacketDescription, AudioTimeStamp, SMPTETime) are C declarations in the CoreAudioTypes
// clang module (usr/include/CoreAudioTypes); this file adds linear-PCM flags, UnsafeMutableAudioBufferListPointer
// and helpers.
import Foundation
@_exported import CoreAudioTypes

public typealias AudioFormatFlags = UInt32
public typealias AudioChannelLayoutTag = UInt32
// linear PCM flags
public let kAudioFormatFlagIsFloat: AudioFormatFlags = 1 << 0
public let kAudioFormatFlagIsBigEndian: AudioFormatFlags = 1 << 1
public let kAudioFormatFlagIsSignedInteger: AudioFormatFlags = 1 << 2
public let kAudioFormatFlagIsPacked: AudioFormatFlags = 1 << 3
public let kAudioFormatFlagIsAlignedHigh: AudioFormatFlags = 1 << 4
public let kAudioFormatFlagIsNonInterleaved: AudioFormatFlags = 1 << 5
public let kAudioFormatFlagIsNonMixable: AudioFormatFlags = 1 << 6
public let kAudioFormatFlagsNativeEndian: AudioFormatFlags = 0
public let kAudioFormatFlagsNativeFloatPacked: AudioFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked
public let kLinearPCMFormatFlagIsFloat = kAudioFormatFlagIsFloat
public let kLinearPCMFormatFlagIsBigEndian = kAudioFormatFlagIsBigEndian
public let kLinearPCMFormatFlagIsSignedInteger = kAudioFormatFlagIsSignedInteger
public let kLinearPCMFormatFlagIsPacked = kAudioFormatFlagIsPacked
public let kLinearPCMFormatFlagIsNonInterleaved = kAudioFormatFlagIsNonInterleaved

// channel layout tags ((index << 16) | number of channels) and channel labels
public let kAudioChannelLayoutTag_UseChannelDescriptions: AudioChannelLayoutTag = (0 << 16) | 0
public let kAudioChannelLayoutTag_UseChannelBitmap: AudioChannelLayoutTag = (1 << 16) | 0
public let kAudioChannelLayoutTag_Mono: AudioChannelLayoutTag = (100 << 16) | 1
public let kAudioChannelLayoutTag_Stereo: AudioChannelLayoutTag = (101 << 16) | 2
public let kAudioChannelLayoutTag_StereoHeadphones: AudioChannelLayoutTag = (102 << 16) | 2
public let kAudioChannelLayoutTag_MatrixStereo: AudioChannelLayoutTag = (103 << 16) | 2
public let kAudioChannelLayoutTag_MidSide: AudioChannelLayoutTag = (104 << 16) | 2
public let kAudioChannelLayoutTag_XY: AudioChannelLayoutTag = (105 << 16) | 2
public let kAudioChannelLayoutTag_Binaural: AudioChannelLayoutTag = (106 << 16) | 2
public let kAudioChannelLayoutTag_Ambisonic_B_Format: AudioChannelLayoutTag = (107 << 16) | 4
public let kAudioChannelLayoutTag_Quadraphonic: AudioChannelLayoutTag = (108 << 16) | 4
public let kAudioChannelLayoutTag_Pentagonal: AudioChannelLayoutTag = (109 << 16) | 5
public let kAudioChannelLayoutTag_Hexagonal: AudioChannelLayoutTag = (110 << 16) | 6
public let kAudioChannelLayoutTag_Octagonal: AudioChannelLayoutTag = (111 << 16) | 8
public let kAudioChannelLayoutTag_Cube: AudioChannelLayoutTag = (112 << 16) | 8
public let kAudioChannelLayoutTag_MPEG_1_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_Mono
public let kAudioChannelLayoutTag_MPEG_2_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_Stereo
public let kAudioChannelLayoutTag_MPEG_3_0_A: AudioChannelLayoutTag = (113 << 16) | 3
public let kAudioChannelLayoutTag_MPEG_3_0_B: AudioChannelLayoutTag = (114 << 16) | 3
public let kAudioChannelLayoutTag_MPEG_4_0_A: AudioChannelLayoutTag = (115 << 16) | 4
public let kAudioChannelLayoutTag_MPEG_4_0_B: AudioChannelLayoutTag = (116 << 16) | 4
public let kAudioChannelLayoutTag_MPEG_5_0_A: AudioChannelLayoutTag = (117 << 16) | 5
public let kAudioChannelLayoutTag_MPEG_5_0_B: AudioChannelLayoutTag = (118 << 16) | 5
public let kAudioChannelLayoutTag_MPEG_5_0_C: AudioChannelLayoutTag = (119 << 16) | 5
public let kAudioChannelLayoutTag_MPEG_5_0_D: AudioChannelLayoutTag = (120 << 16) | 5
public let kAudioChannelLayoutTag_MPEG_5_1_A: AudioChannelLayoutTag = (121 << 16) | 6
public let kAudioChannelLayoutTag_MPEG_5_1_B: AudioChannelLayoutTag = (122 << 16) | 6
public let kAudioChannelLayoutTag_MPEG_5_1_C: AudioChannelLayoutTag = (123 << 16) | 6
public let kAudioChannelLayoutTag_MPEG_5_1_D: AudioChannelLayoutTag = (124 << 16) | 6
public let kAudioChannelLayoutTag_MPEG_6_1_A: AudioChannelLayoutTag = (125 << 16) | 7
public let kAudioChannelLayoutTag_MPEG_7_1_A: AudioChannelLayoutTag = (126 << 16) | 8
public let kAudioChannelLayoutTag_MPEG_7_1_B: AudioChannelLayoutTag = (127 << 16) | 8
public let kAudioChannelLayoutTag_MPEG_7_1_C: AudioChannelLayoutTag = (128 << 16) | 8
public let kAudioChannelLayoutTag_Emagic_Default_7_1: AudioChannelLayoutTag = (129 << 16) | 8
public let kAudioChannelLayoutTag_SMPTE_DTV: AudioChannelLayoutTag = (130 << 16) | 8
public let kAudioChannelLayoutTag_ITU_1_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_Mono
public let kAudioChannelLayoutTag_ITU_2_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_Stereo
public let kAudioChannelLayoutTag_ITU_2_1: AudioChannelLayoutTag = (131 << 16) | 3
public let kAudioChannelLayoutTag_ITU_2_2: AudioChannelLayoutTag = (132 << 16) | 4
public let kAudioChannelLayoutTag_ITU_3_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_3_0_A
public let kAudioChannelLayoutTag_ITU_3_1: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_4_0_A
public let kAudioChannelLayoutTag_ITU_3_2: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_0_A
public let kAudioChannelLayoutTag_ITU_3_2_1: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_A
public let kAudioChannelLayoutTag_ITU_3_4_1: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_7_1_C
public let kAudioChannelLayoutTag_AAC_3_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_3_0_B
public let kAudioChannelLayoutTag_AAC_Quadraphonic: AudioChannelLayoutTag = kAudioChannelLayoutTag_Quadraphonic
public let kAudioChannelLayoutTag_AAC_4_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_4_0_B
public let kAudioChannelLayoutTag_AAC_5_0: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_0_D
public let kAudioChannelLayoutTag_AAC_5_1: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_5_1_D
public let kAudioChannelLayoutTag_AAC_6_0: AudioChannelLayoutTag = (141 << 16) | 6
public let kAudioChannelLayoutTag_AAC_6_1: AudioChannelLayoutTag = (142 << 16) | 7
public let kAudioChannelLayoutTag_AAC_7_0: AudioChannelLayoutTag = (143 << 16) | 7
public let kAudioChannelLayoutTag_AAC_7_1: AudioChannelLayoutTag = kAudioChannelLayoutTag_MPEG_7_1_B
public let kAudioChannelLayoutTag_AAC_7_1_B: AudioChannelLayoutTag = (183 << 16) | 8
public let kAudioChannelLayoutTag_AAC_7_1_C: AudioChannelLayoutTag = (184 << 16) | 8
public let kAudioChannelLayoutTag_AAC_Octagonal: AudioChannelLayoutTag = (144 << 16) | 8
public let kAudioChannelLayoutTag_DiscreteInOrder: AudioChannelLayoutTag = (147 << 16) | 0
public let kAudioChannelLayoutTag_Unknown: AudioChannelLayoutTag = 0xFFFF0000
public func AudioChannelLayoutTag_GetNumberOfChannels(_ layoutTag: AudioChannelLayoutTag) -> UInt32 { layoutTag & 0x0000_FFFF }
public let kAudioChannelLabel_Unknown: AudioChannelLabel = 0xFFFFFFFF
public let kAudioChannelLabel_Unused: AudioChannelLabel = 0
public let kAudioChannelLabel_UseCoordinates: AudioChannelLabel = 100
public let kAudioChannelLabel_Left: AudioChannelLabel = 1
public let kAudioChannelLabel_Right: AudioChannelLabel = 2
public let kAudioChannelLabel_Center: AudioChannelLabel = 3
public let kAudioChannelLabel_LFEScreen: AudioChannelLabel = 4
public let kAudioChannelLabel_LeftSurround: AudioChannelLabel = 5
public let kAudioChannelLabel_RightSurround: AudioChannelLabel = 6
public let kAudioChannelLabel_LeftCenter: AudioChannelLabel = 7
public let kAudioChannelLabel_RightCenter: AudioChannelLabel = 8
public let kAudioChannelLabel_CenterSurround: AudioChannelLabel = 9
public let kAudioChannelLabel_LeftSurroundDirect: AudioChannelLabel = 10
public let kAudioChannelLabel_RightSurroundDirect: AudioChannelLabel = 11
public let kAudioChannelLabel_TopCenterSurround: AudioChannelLabel = 12
public let kAudioChannelLabel_VerticalHeightLeft: AudioChannelLabel = 13
public let kAudioChannelLabel_VerticalHeightCenter: AudioChannelLabel = 14
public let kAudioChannelLabel_VerticalHeightRight: AudioChannelLabel = 15
public let kAudioChannelLabel_TopBackLeft: AudioChannelLabel = 16
public let kAudioChannelLabel_TopBackCenter: AudioChannelLabel = 17
public let kAudioChannelLabel_TopBackRight: AudioChannelLabel = 18
public let kAudioChannelLabel_RearSurroundLeft: AudioChannelLabel = 33
public let kAudioChannelLabel_RearSurroundRight: AudioChannelLabel = 34
public let kAudioChannelLabel_LeftWide: AudioChannelLabel = 35
public let kAudioChannelLabel_RightWide: AudioChannelLabel = 36
public let kAudioChannelLabel_LFE2: AudioChannelLabel = 37
public let kAudioChannelLabel_LeftTotal: AudioChannelLabel = 38
public let kAudioChannelLabel_RightTotal: AudioChannelLabel = 39
public let kAudioChannelLabel_HearingImpaired: AudioChannelLabel = 40
public let kAudioChannelLabel_Narration: AudioChannelLabel = 41
public let kAudioChannelLabel_Mono: AudioChannelLabel = 42
public let kAudioChannelLabel_DialogCentricMix: AudioChannelLabel = 43
public let kAudioChannelLabel_CenterSurroundDirect: AudioChannelLabel = 44
public let kAudioChannelLabel_Haptic: AudioChannelLabel = 45
public let kAudioChannelLabel_Ambisonic_W: AudioChannelLabel = 200
public let kAudioChannelLabel_Ambisonic_X: AudioChannelLabel = 201
public let kAudioChannelLabel_Ambisonic_Y: AudioChannelLabel = 202
public let kAudioChannelLabel_Ambisonic_Z: AudioChannelLabel = 203
public let kAudioChannelLabel_MS_Mid: AudioChannelLabel = 204
public let kAudioChannelLabel_MS_Side: AudioChannelLabel = 205
public let kAudioChannelLabel_XY_X: AudioChannelLabel = 206
public let kAudioChannelLabel_XY_Y: AudioChannelLabel = 207
public let kAudioChannelLabel_HeadphonesLeft: AudioChannelLabel = 301
public let kAudioChannelLabel_HeadphonesRight: AudioChannelLabel = 302
public let kAudioChannelLabel_Discrete: AudioChannelLabel = 400
public let kAudioChannelLabel_Discrete_0: AudioChannelLabel = (1 << 16) | 0
public let kAudioChannelLabel_Discrete_1: AudioChannelLabel = (1 << 16) | 1

extension AudioStreamBasicDescription: @retroactive Equatable {
    public static func == (a: AudioStreamBasicDescription, b: AudioStreamBasicDescription) -> Bool {
        a.mSampleRate == b.mSampleRate && a.mFormatID == b.mFormatID && a.mFormatFlags == b.mFormatFlags && a.mBytesPerPacket == b.mBytesPerPacket
            && a.mFramesPerPacket == b.mFramesPerPacket && a.mBytesPerFrame == b.mBytesPerFrame && a.mChannelsPerFrame == b.mChannelsPerFrame
            && a.mBitsPerChannel == b.mBitsPerChannel
    }
    /// isim: linear PCM described by this format (interleaved unless the non-interleaved flag is set)
    public var _isPCM: Bool { mFormatID == 0x6C70_636D }
    public var _isFloat: Bool { mFormatFlags & kAudioFormatFlagIsFloat != 0 }
    public var _isNonInterleaved: Bool { mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 }
    public var _isBigEndian: Bool { mFormatFlags & kAudioFormatFlagIsBigEndian != 0 }
    public var _bytesPerSample: Int { Int(mBitsPerChannel + 7) / 8 }
    /// isim: interleaved bytes per frame (all channels)
    public var _frameBytes: Int { mBytesPerFrame > 0 && !_isNonInterleaved ? Int(mBytesPerFrame) : _bytesPerSample * Int(max(1, mChannelsPerFrame)) }
}
extension AudioBufferList {
    public static func sizeInBytes(maximumBuffers: Int) -> Int { MemoryLayout<AudioBufferList>.size + max(0, maximumBuffers - 1) * MemoryLayout<AudioBuffer>.stride }
    /// malloc'd (release with free(list.unsafeMutablePointer)), like the iOS overlay
    public static func allocate(maximumBuffers: Int) -> UnsafeMutableAudioBufferListPointer {
        let n = max(1, maximumBuffers)
        let raw = calloc(1, sizeInBytes(maximumBuffers: n))!
        let p = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        p.pointee.mNumberBuffers = UInt32(n)
        return UnsafeMutableAudioBufferListPointer(p)
    }
}
public struct UnsafeMutableAudioBufferListPointer: RandomAccessCollection, MutableCollection {
    public var unsafeMutablePointer: UnsafeMutablePointer<AudioBufferList>
    public init(_ p: UnsafeMutablePointer<AudioBufferList>) { unsafeMutablePointer = p }
    public init?(_ p: UnsafeMutablePointer<AudioBufferList>?) { guard let p else { return nil }; unsafeMutablePointer = p }
    public var unsafePointer: UnsafePointer<AudioBufferList> { UnsafePointer(unsafeMutablePointer) }
    public var count: Int {
        get { Int(unsafeMutablePointer.pointee.mNumberBuffers) }
        nonmutating set { unsafeMutablePointer.pointee.mNumberBuffers = UInt32(newValue) }
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { count }
    var _first: UnsafeMutablePointer<AudioBuffer> {
        (UnsafeMutableRawPointer(unsafeMutablePointer) + (4 + MemoryLayout<AudioBuffer>.alignment - 1) / MemoryLayout<AudioBuffer>.alignment * MemoryLayout<AudioBuffer>.alignment).assumingMemoryBound(to: AudioBuffer.self)
    }
    public subscript(i: Int) -> AudioBuffer {
        get { _first[i] }
        nonmutating set { _first[i] = newValue }
    }
}

