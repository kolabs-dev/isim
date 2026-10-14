// Sample: the audio module names apps import (issue #223), each checked by an "am" log line and shown in a list.
// - import AVFAudio: AVAudioSession, AVAudioFormat, AVAudioEngine (isim's AVFoundation, re-exported)
// - import AudioUnit: AudioComponentDescription, AudioComponentFindNext, a RemoteIO unit's stream format
// - import CoreAudio / CoreAudioTypes: AudioStreamBasicDescription, format IDs and linear PCM flags
import SwiftUI
import AVFAudio
import AudioUnit
import CoreAudio
import CoreAudioTypes

var rows: [(String, String)] = []
func log(_ key: String, _ value: String) { print("am \(key) \(value)"); rows.append((key, value)) }

func runChecks() {
    // AVFAudio
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.playback, mode: .default)
    log("session", "category=\(session.category.rawValue)")
    let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2)!
    let asbd = format.streamDescription.pointee
    log("format", "rate=\(Int(asbd.mSampleRate)) channels=\(asbd.mChannelsPerFrame) lpcm=\(asbd.mFormatID == kAudioFormatLinearPCM) "
        + "float=\(asbd.mFormatFlags & kAudioFormatFlagIsFloat != 0)")
    let engine = AVAudioEngine()
    log("engine", "mixer=\(type(of: engine.mainMixerNode)) output=\(type(of: engine.outputNode))")

    // AudioUnit
    var desc = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO,
                                         componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
    var unit: AudioUnit?
    if let component = AudioComponentFindNext(nil, &desc), AudioComponentInstanceNew(component, &unit) == noErr, let unit {
        var stream = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kAudioFormatFlagsNativeFloatPacked,
                                                 mBytesPerPacket: 8, mFramesPerPacket: 1, mBytesPerFrame: 8, mChannelsPerFrame: 2,
                                                 mBitsPerChannel: 32, mReserved: 0)
        let set = AudioUnitSetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &stream,
                                       UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        var back = AudioStreamBasicDescription(), size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        let get = AudioUnitGetProperty(unit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &back, &size)
        log("remoteio", "set=\(set) get=\(get) rate=\(Int(back.mSampleRate)) channels=\(back.mChannelsPerFrame)")
        _ = AudioComponentInstanceDispose(unit)
    } else {
        log("remoteio", "not found")
    }

    // CoreAudio / CoreAudioTypes
    let buffers = AudioBufferList(mNumberBuffers: 1, mBuffers: AudioBuffer(mNumberChannels: 2, mDataByteSize: 512, mData: nil))
    log("types", "buffers=\(buffers.mNumberBuffers) bytes=\(buffers.mBuffers.mDataByteSize) asbd=\(MemoryLayout<AudioStreamBasicDescription>.size) "
        + "aac=\(String(format: "%08x", kAudioFormatMPEG4AAC))")
    print("am reported")
}

struct ContentView: View {
    let results: [(String, String)]
    var body: some View {
        NavigationStack {
            List(results.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 2) {
                    Text(results[i].0).font(.headline)
                    Text(results[i].1).font(.caption.monospaced()).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Audio Modules")
        }
    }
}

@main
struct HelloAudioModulesApp: App {
    init() { runChecks() }
    var body: some Scene { WindowGroup { ContentView(results: rows) } }
}
