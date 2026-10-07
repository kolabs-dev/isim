// isim CoreAudioTypes, part of the AudioToolbox overlay (self-authored, iOS API names): the plain audio data types
// shared by AudioToolbox, CoreMedia and AVFoundation — AudioStreamBasicDescription, AudioBuffer/AudioBufferList (+ UnsafeMutableAudioBufferListPointer),
// AudioStreamPacketDescription, AudioTimeStamp, format IDs and linear-PCM flags. Memory layouts match the C structs.
import Foundation

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

public struct AudioStreamBasicDescription: Equatable, Sendable {
    public var mSampleRate: Float64
    public var mFormatID: AudioFormatID
    public var mFormatFlags: AudioFormatFlags
    public var mBytesPerPacket: UInt32
    public var mFramesPerPacket: UInt32
    public var mBytesPerFrame: UInt32
    public var mChannelsPerFrame: UInt32
    public var mBitsPerChannel: UInt32
    public var mReserved: UInt32
    public init() { mSampleRate = 0; mFormatID = 0; mFormatFlags = 0; mBytesPerPacket = 0; mFramesPerPacket = 0; mBytesPerFrame = 0; mChannelsPerFrame = 0; mBitsPerChannel = 0; mReserved = 0 }
    public init(mSampleRate: Float64, mFormatID: AudioFormatID, mFormatFlags: AudioFormatFlags, mBytesPerPacket: UInt32, mFramesPerPacket: UInt32,
                mBytesPerFrame: UInt32, mChannelsPerFrame: UInt32, mBitsPerChannel: UInt32, mReserved: UInt32) {
        self.mSampleRate = mSampleRate; self.mFormatID = mFormatID; self.mFormatFlags = mFormatFlags; self.mBytesPerPacket = mBytesPerPacket
        self.mFramesPerPacket = mFramesPerPacket; self.mBytesPerFrame = mBytesPerFrame; self.mChannelsPerFrame = mChannelsPerFrame
        self.mBitsPerChannel = mBitsPerChannel; self.mReserved = mReserved
    }
    /// isim: linear PCM described by this format (interleaved unless the non-interleaved flag is set)
    public var _isPCM: Bool { mFormatID == kAudioFormatLinearPCM }
    public var _isFloat: Bool { mFormatFlags & kAudioFormatFlagIsFloat != 0 }
    public var _isNonInterleaved: Bool { mFormatFlags & kAudioFormatFlagIsNonInterleaved != 0 }
    public var _isBigEndian: Bool { mFormatFlags & kAudioFormatFlagIsBigEndian != 0 }
    public var _bytesPerSample: Int { Int(mBitsPerChannel + 7) / 8 }
    /// isim: interleaved bytes per frame (all channels)
    public var _frameBytes: Int { mBytesPerFrame > 0 && !_isNonInterleaved ? Int(mBytesPerFrame) : _bytesPerSample * Int(max(1, mChannelsPerFrame)) }
}

public struct AudioStreamPacketDescription: Equatable, Sendable {
    public var mStartOffset: Int64
    public var mVariableFramesInPacket: UInt32
    public var mDataByteSize: UInt32
    public init() { mStartOffset = 0; mVariableFramesInPacket = 0; mDataByteSize = 0 }
    public init(mStartOffset: Int64, mVariableFramesInPacket: UInt32, mDataByteSize: UInt32) {
        self.mStartOffset = mStartOffset; self.mVariableFramesInPacket = mVariableFramesInPacket; self.mDataByteSize = mDataByteSize
    }
}

public struct AudioBuffer: @unchecked Sendable {
    public var mNumberChannels: UInt32
    public var mDataByteSize: UInt32
    public var mData: UnsafeMutableRawPointer?
    public init() { mNumberChannels = 0; mDataByteSize = 0; mData = nil }
    public init(mNumberChannels: UInt32, mDataByteSize: UInt32, mData: UnsafeMutableRawPointer?) {
        self.mNumberChannels = mNumberChannels; self.mDataByteSize = mDataByteSize; self.mData = mData
    }
}
/// Like C's AudioBufferList: `mBuffers` is the first of `mNumberBuffers` buffers laid out in memory
/// (use UnsafeMutableAudioBufferListPointer to reach the others).
public struct AudioBufferList: @unchecked Sendable {
    public var mNumberBuffers: UInt32
    public var mBuffers: AudioBuffer
    public init() { mNumberBuffers = 0; mBuffers = AudioBuffer() }
    public init(mNumberBuffers: UInt32, mBuffers: AudioBuffer) { self.mNumberBuffers = mNumberBuffers; self.mBuffers = mBuffers }
    public static func sizeInBytes(maximumBuffers: Int) -> Int { MemoryLayout<AudioBufferList>.size + max(0, maximumBuffers - 1) * MemoryLayout<AudioBuffer>.stride }
    public static func allocate(maximumBuffers: Int) -> UnsafeMutableAudioBufferListPointer {
        let n = max(1, maximumBuffers)
        let raw = UnsafeMutableRawPointer.allocate(byteCount: sizeInBytes(maximumBuffers: n), alignment: MemoryLayout<AudioBufferList>.alignment)
        let p = raw.bindMemory(to: AudioBufferList.self, capacity: 1)
        p.pointee.mNumberBuffers = UInt32(n)
        let l = UnsafeMutableAudioBufferListPointer(p)
        for i in 0..<n { l[i] = AudioBuffer() }
        return l
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
        (UnsafeMutableRawPointer(unsafeMutablePointer) + MemoryLayout<AudioBufferList>.offset(of: \AudioBufferList.mBuffers)!).assumingMemoryBound(to: AudioBuffer.self)
    }
    public subscript(i: Int) -> AudioBuffer {
        get { _first[i] }
        nonmutating set { _first[i] = newValue }
    }
}

public struct SMPTETime: Sendable {
    public var mSubframes: Int16 = 0, mSubframeDivisor: Int16 = 0, mCounter: UInt32 = 0, mType: UInt32 = 0, mFlags: UInt32 = 0
    public var mHours: Int16 = 0, mMinutes: Int16 = 0, mSeconds: Int16 = 0, mFrames: Int16 = 0
    public init() {}
}
public struct AudioTimeStampFlags: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let sampleTimeValid = AudioTimeStampFlags(rawValue: 1)
    public static let hostTimeValid = AudioTimeStampFlags(rawValue: 2)
    public static let rateScalarValid = AudioTimeStampFlags(rawValue: 4)
}
public struct AudioTimeStamp: Sendable {
    public var mSampleTime: Float64 = 0
    public var mHostTime: UInt64 = 0
    public var mRateScalar: Float64 = 0
    public var mWordClockTime: UInt64 = 0
    public var mSMPTETime = SMPTETime()
    public var mFlags: AudioTimeStampFlags = []
    public var mReserved: UInt32 = 0
    public init() {}
}
