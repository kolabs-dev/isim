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

