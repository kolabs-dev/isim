// Sample: AVAudioEngine's real-time graph and AudioToolbox's Audio Units on isim — a player node through an equalizer
// whose parameters change while it plays (seen by a real-time tap on the main mixer), varispeed and time/pitch,
// AVAudioSourceNode and AVAudioSinkNode, AVAudioEnvironmentNode (3D positions), play(at:), player time, and the Audio
// Unit C API: AUGraph with RemoteIO + MultiChannelMixer fed by a render callback, the microphone through RemoteIO's
// input bus (ISIM_AUDIO_INPUT), GenericOutput pulled offline through an AUConverter, AudioUnitProcess on a delay.
import UIKit
import AVFoundation
import AudioToolbox

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = EngineViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloAudioEngine: %@", s) }
func f2(_ x: Double) -> String { String(format: "%.2f", x) }
func rms(_ p: UnsafePointer<Float>, _ n: Int) -> Double {
    guard n > 0 else { return 0 }
    var s = 0.0
    for i in 0..<n { s += Double(p[i] * p[i]) }
    return (s / Double(n)).squareRoot()
}
func rms(_ x: [Float]) -> Double { x.withUnsafeBufferPointer { rms($0.baseAddress!, x.count) } }
/// frequency from zero crossings
func frequency(_ x: [Float], rate: Double) -> Double {
    var crossings = 0
    for i in 1..<x.count where (x[i - 1] < 0) != (x[i] < 0) { crossings += 1 }
    return Double(crossings) / 2 / (Double(x.count) / rate)
}
func sine(_ seconds: Double, _ freq: Double, _ format: AVAudioFormat, amp: Float = 0.5) -> AVAudioPCMBuffer {
    let n = AVAudioFrameCount(seconds * format.sampleRate)
    let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
    b.frameLength = n
    for c in 0..<Int(format.channelCount) {
        for i in 0..<Int(n) { b.floatChannelData![c][i] = amp * Float(sin(2 * .pi * freq * Double(i) / format.sampleRate)) }
    }
    return b
}

final class EngineViewController: UIViewController {
    let status = UILabel()
    var lines: [String] = []
    // real-time engine
    let engine = AVAudioEngine()
    let player = AVAudioPlayerNode()
    let eq = AVAudioUnitEQ(numberOfBands: 1)
    var tapRMS: [Double] = []
    var tapFrames = 0
    // Audio Units
    var graph: AUGraph?
    var rio: AudioUnit?
    var phase = 0.0
    var notifyFrames = 0
    var notifyPeak: Float = 0
    var micUnit: AudioUnit?
    var micFrames = 0
    var micPeak: Float = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Audio Engine"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 360, height: 41); view.addSubview(title)
        status.frame = CGRect(x: 20, y: 120, width: 360, height: 600); status.numberOfLines = 0
        status.font = .systemFont(ofSize: 13); status.accessibilityIdentifier = "status"; view.addSubview(status)
        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord)
        try? AVAudioSession.sharedInstance().setActive(true)
        offlineChecks()
        realtimeEngine()
    }
    func report(_ s: String) {
        log(s)
        lines.append(s)
        status.text = lines.suffix(30).joined(separator: "\n")
    }

    // MARK: offline: varispeed, time pitch, 3D, play(at:)

    /// renders `seconds` through `build` (which attaches and connects its nodes and returns the player)
    func render(seconds: Double, rate: Double = 48000, channels: AVAudioChannelCount = 1,
                _ build: (AVAudioEngine, AVAudioFormat) -> Void) -> [[Float]] {
        let e = AVAudioEngine()
        let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: channels)!
        try! e.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        build(e, format)
        try! e.start()
        for case let p as AVAudioPlayerNode in e.attachedNodes { p.play() }
        var out = [[Float]](repeating: [], count: Int(channels))
        let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        while out[0].count < Int(seconds * rate) {
            _ = try! e.renderOffline(AVAudioFrameCount(min(4096, Int(seconds * rate) - out[0].count)), to: chunk)
            for c in 0..<Int(channels) { out[c] += Array(UnsafeBufferPointer(start: chunk.floatChannelData![c], count: Int(chunk.frameLength))) }
        }
        e.stop()
        return out
    }
    func offlineChecks() {
        let mono = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        // varispeed rate 2: twice as fast and an octave up
        var variEnd = -1.0
        let vari = render(seconds: 1.5) { e, f in
            let p = AVAudioPlayerNode(), v = AVAudioUnitVarispeed()
            v.rate = 2
            e.attach(p); e.attach(v)
            e.connect(p, to: v, format: mono); e.connect(v, to: e.mainMixerNode, format: mono)
            p.scheduleBuffer(sine(1, 440, mono)) { variEnd = Double(e.manualRenderingSampleTime) / 48000 }
        }
        report("varispeed end \(f2(variEnd)) freq \(Int(frequency(Array(vari[0][4800..<19200]), rate: 48000).rounded())) after \(f2(rms(Array(vari[0][28800...]))))")
        // time pitch: +1200 cents keeps the length and doubles the frequency
        var pitchEnd = -1.0
        let tp = render(seconds: 1.5) { e, f in
            let p = AVAudioPlayerNode(), t = AVAudioUnitTimePitch()
            t.pitch = 1200
            e.attach(p); e.attach(t)
            e.connect(p, to: t, format: mono); e.connect(t, to: e.mainMixerNode, format: mono)
            p.scheduleBuffer(sine(1, 440, mono)) { pitchEnd = Double(e.manualRenderingSampleTime) / 48000 }
        }
        report("timepitch end \(f2(pitchEnd)) freq \(Int((frequency(Array(tp[0][9600..<33600]), rate: 48000) / 10).rounded()) * 10)")
        // 3D: a mono source to the right, to the left, far away
        func place(_ pos: AVAudio3DPoint, _ model: AVAudioEnvironmentDistanceAttenuationModel = .inverse) -> (Double, Double) {
            let out = render(seconds: 0.5, channels: 2) { e, f in
                let p = AVAudioPlayerNode(), env = AVAudioEnvironmentNode()
                env.distanceAttenuationParameters.distanceAttenuationModel = model
                e.attach(p); e.attach(env)
                e.connect(p, to: env, format: mono)
                e.connect(env, to: e.mainMixerNode, format: AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 2))
                p.position = pos
                p.scheduleBuffer(sine(0.5, 440, mono))
            }
            return (rms(out[0]), rms(out[1]))
        }
        let right = place(AVAudio3DPoint(x: 1, y: 0, z: 0)), left = place(AVAudio3DPoint(x: -1, y: 0, z: 0))
        let ahead = place(AVAudio3DPoint(x: 0, y: 0, z: -1)), far = place(AVAudio3DPoint(x: 0, y: 0, z: -10))
        let linear = place(AVAudio3DPoint(x: 0, y: 0, z: -10), .linear)
        report("environment right \(right.1 > right.0 * 5) left \(left.0 > left.1 * 5) centre \(abs(ahead.0 - ahead.1) < 0.01) far \(f2(far.0 / ahead.0)) linear \(f2(linear.0 / ahead.0))")
        // play(at:) a quarter of a second later; the mixer resamples a 24 kHz player
        let late = render(seconds: 0.5) { e, f in
            let p = AVAudioPlayerNode()
            let f24 = AVAudioFormat(standardFormatWithSampleRate: 24000, channels: 1)!
            e.attach(p)
            e.connect(p, to: e.mainMixerNode, format: f24)
            p.scheduleBuffer(sine(1, 440, f24))
        }
        let first = late[0].firstIndex { abs($0) > 0.01 } ?? -1
        report("resampled player starts at \(first) freq \(Int(frequency(Array(late[0][4800..<19200]), rate: 48000).rounded()))")
        var delayed = -1
        let e2 = AVAudioEngine()
        try! e2.enableManualRenderingMode(.offline, format: mono, maximumFrameCount: 4096)
        let p2 = AVAudioPlayerNode()
        e2.attach(p2); e2.connect(p2, to: e2.mainMixerNode, format: mono)
        p2.scheduleBuffer(sine(1, 440, mono))
        try! e2.start()
        p2.play(at: AVAudioTime(sampleTime: 12000, atRate: 48000))
        let chunk = AVAudioPCMBuffer(pcmFormat: mono, frameCapacity: 4096)!
        var all: [Float] = []
        for _ in 0..<6 { _ = try! e2.renderOffline(4096, to: chunk); all += Array(UnsafeBufferPointer(start: chunk.floatChannelData![0], count: 4096)) }
        delayed = all.firstIndex { abs($0) > 0.01 } ?? -1
        let pt = p2.playerTime(forNodeTime: p2.lastRenderTime!)!
        report("play(at:) starts at \(delayed) playerTime \(pt.sampleTime)")
        e2.stop()
        // the effect's Audio Unit is the same unit AudioUnitSetParameter changes
        let reverb = AVAudioUnitReverb()
        _ = AudioUnitSetParameter(reverb.audioUnit, kReverb2Param_DryWetMix, kAudioUnitScope_Global, 0, 25, 0)
        report("reverb audioUnit wetDryMix \(Int(reverb.wetDryMix))")
        audioUnitsOffline()
    }

    // MARK: real time: live EQ change seen by a mixer tap, source node, sink node from the input

    func realtimeEngine() {
        let mono = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        engine.attach(player); engine.attach(eq)
        engine.connect(player, to: eq, format: mono)
        engine.connect(eq, to: engine.mainMixerNode, format: mono)
        eq.bands[0].filterType = .lowPass; eq.bands[0].frequency = 150; eq.bands[0].bypass = true
        // a generated tone
        var ph = 0.0
        let source = AVAudioSourceNode { _, _, frames, list in
            let abl = UnsafeMutableAudioBufferListPointer(list)
            for i in 0..<Int(frames) {
                let v = Float(sin(ph) * 0.25)
                ph += 2 * .pi * 660 / 48000
                for b in abl { b.mData!.assumingMemoryBound(to: Float.self)[i] = v }
            }
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: mono)
        source.volume = 0
        // the microphone into a sink
        var sinkFrames = 0
        var sinkPeak: Float = 0
        let sink = AVAudioSinkNode { _, frames, list in
            let p = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: list))[0].mData!.assumingMemoryBound(to: Float.self)
            sinkFrames += Int(frames)
            for i in 0..<Int(frames) { sinkPeak = max(sinkPeak, abs(p[i])) }
            return noErr
        }
        engine.attach(sink)
        engine.connect(engine.inputNode, to: sink, format: nil)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 4800, format: nil) { [weak self] b, _ in
            guard let self else { return }
            self.tapFrames += Int(b.frameLength)
            self.tapRMS.append(rms(b.floatChannelData![0], Int(b.frameLength)))
        }
        player.scheduleBuffer(sine(1, 440, mono), at: nil, options: .loops)
        do { try engine.start() } catch { report("engine start failed \(error)") }
        player.play()
        let started = Date()
        // after 0.6 s: the low-pass filter goes on while the same looping buffer plays
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            let before = tapRMS.suffix(3).reduce(0, +) / 3
            eq.bands[0].bypass = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
                let after = tapRMS.suffix(3).reduce(0, +) / 3
                let pt = player.playerTime(forNodeTime: player.lastRenderTime!)!
                let elapsed = Date().timeIntervalSince(started)
                report("realtime tap \(tapFrames > 24000) rms before \(f2(before)) after lowpass \(f2(after)) playerTime \(f2(Double(pt.sampleTime) / 48000 / elapsed))")
                // swap in the source node
                player.stop()
                source.volume = 1
                tapRMS = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [self] in
                    report("source node rms \(f2(tapRMS.suffix(2).reduce(0, +) / 2)) sink frames \(sinkFrames > 9600) peak \(f2(Double(sinkPeak)))")
                    engine.stop()
                    audioUnitsRealtime()
                }
            }
        }
    }

    // MARK: Audio Units

    func audioUnitsOffline() {
        // GenericOutput <- AUConverter (44.1 kHz callback -> 48 kHz), pulled with AudioUnitRender
        var d = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_GenericOutput,
                                          componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var out: AudioUnit?, conv: AudioUnit?
        _ = AudioComponentInstanceNew(AudioComponentFindNext(nil, &d)!, &out)
        d.componentType = kAudioUnitType_FormatConverter; d.componentSubType = kAudioUnitSubType_AUConverter
        let convComp = AudioComponentFindNext(nil, &d)!
        var name: Unmanaged<CFString>?
        _ = AudioComponentCopyName(convComp, &name)
        _ = AudioComponentInstanceNew(convComp, &conv)
        var f441 = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM,
                                               mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2,
                                               mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        var f48 = AudioStreamBasicDescription(mSampleRate: 48000, mFormatID: kAudioFormatLinearPCM,
                                              mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
                                              mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 1, mBitsPerChannel: 32, mReserved: 0)
        let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        _ = AudioUnitSetProperty(conv!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f441, size)
        _ = AudioUnitSetProperty(conv!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &f48, size)
        _ = AudioUnitSetProperty(out!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f48, size)
        _ = AudioUnitSetProperty(out!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &f48, size)
        var cb = AURenderCallbackStruct(inputProc: { refCon, _, _, _, frames, data in
            let vc = Unmanaged<EngineViewController>.fromOpaque(refCon).takeUnretainedValue()
            let p = UnsafeMutableAudioBufferListPointer(data!)[0].mData!.assumingMemoryBound(to: Int16.self)
            for i in 0..<Int(frames) { p[i] = Int16(sin(vc.phase) * 16383); vc.phase += 2 * .pi * 441 / 44100 }
            return noErr
        }, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        _ = AudioUnitSetProperty(conv!, kAudioUnitProperty_SetRenderCallback, kAudioUnitScope_Input, 0, &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        var conn = AudioUnitConnection(sourceAudioUnit: conv, sourceOutputNumber: 0, destInputNumber: 0)
        _ = AudioUnitSetProperty(out!, kAudioUnitProperty_MakeConnection, kAudioUnitScope_Input, 0, &conn, UInt32(MemoryLayout<AudioUnitConnection>.size))
        _ = AudioUnitInitialize(conv!); _ = AudioUnitInitialize(out!)
        var samples: [Float] = []
        var ts = AudioTimeStamp(); ts.mFlags = .sampleTimeValid
        let list = AudioBufferList.allocate(maximumBuffers: 1)
        for _ in 0..<12 {
            list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: 4096 * 4, mData: nil)       // the unit supplies the buffer
            var flags = AudioUnitRenderActionFlags()
            let st = AudioUnitRender(out!, &flags, &ts, 0, 4096, list.unsafeMutablePointer)
            if st != noErr { report("generic output render error \(st)"); break }
            samples += Array(UnsafeBufferPointer(start: list[0].mData!.assumingMemoryBound(to: Float.self), count: 4096))
            ts.mSampleTime += 4096
        }
        free(list.unsafeMutablePointer)
        report("generic output \(name?.takeRetainedValue() as String? ?? "?") freq \(Int(frequency(Array(samples[4800...]), rate: 48000).rounded())) rms \(f2(rms(samples)))")
        _ = AudioComponentInstanceDispose(conv!); _ = AudioComponentInstanceDispose(out!)
        // AudioUnitProcess on a delay: an impulse comes back 0.1 s later
        d.componentType = kAudioUnitType_Effect; d.componentSubType = kAudioUnitSubType_Delay
        var delay: AudioUnit?
        _ = AudioComponentInstanceNew(AudioComponentFindNext(nil, &d)!, &delay)
        var mono = f48
        _ = AudioUnitSetProperty(delay!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &mono, size)
        _ = AudioUnitSetProperty(delay!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &mono, size)
        _ = AudioUnitSetParameter(delay!, kDelayParam_DelayTime, kAudioUnitScope_Global, 0, 0.1, 0)
        _ = AudioUnitSetParameter(delay!, kDelayParam_WetDryMix, kAudioUnitScope_Global, 0, 100, 0)
        _ = AudioUnitSetParameter(delay!, kDelayParam_Feedback, kAudioUnitScope_Global, 0, 0, 0)
        _ = AudioUnitInitialize(delay!)
        var buf = [Float](repeating: 0, count: 9600)
        buf[0] = 1
        var echo = -1
        buf.withUnsafeMutableBytes { raw in
            let l = AudioBufferList.allocate(maximumBuffers: 1)
            l[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress)
            var ts2 = AudioTimeStamp()
            _ = AudioUnitProcess(delay!, nil, &ts2, 9600, l.unsafeMutablePointer)
            free(l.unsafeMutablePointer)
        }
        echo = buf.firstIndex { $0 > 0.5 } ?? -1
        var paramCount: UInt32 = 0
        _ = AudioUnitGetPropertyInfo(delay!, kAudioUnitProperty_ParameterList, kAudioUnitScope_Global, 0, &paramCount, nil)
        report("delay unit echo at \(echo) parameters \(paramCount / 4)")
        _ = AudioComponentInstanceDispose(delay!)
    }

    func audioUnitsRealtime() {
        // AUGraph: render callback -> MultiChannelMixer (bus 0 at half volume) -> RemoteIO
        var g: AUGraph?
        _ = NewAUGraph(&g)
        graph = g
        var io = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO,
                                           componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var mix = AudioComponentDescription(componentType: kAudioUnitType_Mixer, componentSubType: kAudioUnitSubType_MultiChannelMixer,
                                            componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var ioNode = AUNode(), mixNode = AUNode()
        _ = AUGraphAddNode(g!, &io, &ioNode)
        _ = AUGraphAddNode(g!, &mix, &mixNode)
        _ = AUGraphOpen(g!)
        var mixer: AudioUnit?, rioUnit: AudioUnit?
        _ = AUGraphNodeInfo(g!, mixNode, nil, &mixer)
        _ = AUGraphNodeInfo(g!, ioNode, nil, &rioUnit)
        rio = rioUnit
        var buses: UInt32 = 1
        _ = AudioUnitSetProperty(mixer!, kAudioUnitProperty_ElementCount, kAudioUnitScope_Input, 0, &buses, 4)
        var f = AudioStreamBasicDescription(mSampleRate: 44100, mFormatID: kAudioFormatLinearPCM,
                                            mFormatFlags: kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved,
                                            mBytesPerPacket: 4, mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 32, mReserved: 0)
        let size = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        _ = AudioUnitSetProperty(mixer!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f, size)
        _ = AudioUnitSetProperty(mixer!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &f, size)
        _ = AudioUnitSetProperty(rioUnit!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &f, size)
        _ = AudioUnitSetParameter(mixer!, kMultiChannelMixerParam_Volume, kAudioUnitScope_Input, 0, 0.5, 0)
        var cb = AURenderCallbackStruct(inputProc: { refCon, _, _, _, frames, data in
            let vc = Unmanaged<EngineViewController>.fromOpaque(refCon).takeUnretainedValue()
            let abl = UnsafeMutableAudioBufferListPointer(data!)
            for i in 0..<Int(frames) {
                let v = Float(sin(vc.phase) * 0.8)
                vc.phase += 2 * .pi * 441 / 44100
                for b in abl { b.mData!.assumingMemoryBound(to: Float.self)[i] = v }
            }
            return noErr
        }, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        _ = AUGraphSetNodeInputCallback(g!, mixNode, 0, &cb)
        _ = AUGraphConnectNodeInput(g!, mixNode, 0, ioNode, 0)
        _ = AudioUnitAddRenderNotify(rioUnit!, { refCon, flags, _, _, frames, data in
            guard flags.pointee.contains(.unitRenderAction_PostRender), let data else { return noErr }
            let vc = Unmanaged<EngineViewController>.fromOpaque(refCon).takeUnretainedValue()
            let p = UnsafeMutableAudioBufferListPointer(data)[0].mData!.assumingMemoryBound(to: Float.self)
            vc.notifyFrames += Int(frames)
            for i in 0..<Int(frames) { vc.notifyPeak = max(vc.notifyPeak, abs(p[i])) }
            return noErr
        }, Unmanaged.passUnretained(self).toOpaque())
        _ = AUGraphInitialize(g!)
        let st = AUGraphStart(g!)
        var running = DarwinBoolean(false)
        _ = AUGraphIsRunning(g!, &running)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
            report("augraph start \(st) running \(running.boolValue) frames \(notifyFrames > 11025) peak \(f2(Double(notifyPeak)))")
            _ = AUGraphStop(g!)
            _ = DisposeAUGraph(g!)
            remoteIOInput()
        }
    }

    /// RemoteIO with input enabled: the input callback renders bus 1 (the simulated microphone)
    func remoteIOInput() {
        var io = AudioComponentDescription(componentType: kAudioUnitType_Output, componentSubType: kAudioUnitSubType_RemoteIO,
                                           componentManufacturer: kAudioUnitManufacturer_Apple, componentFlags: 0, componentFlagsMask: 0)
        var u: AudioUnit?
        _ = AudioComponentInstanceNew(AudioComponentFindNext(nil, &io)!, &u)
        micUnit = u
        var one: UInt32 = 1, zero: UInt32 = 0
        _ = AudioUnitSetProperty(u!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, 1, &one, 4)
        _ = AudioUnitSetProperty(u!, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, 0, &zero, 4)
        var f = AudioStreamBasicDescription(mSampleRate: 16000, mFormatID: kAudioFormatLinearPCM,
                                            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked, mBytesPerPacket: 2,
                                            mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1, mBitsPerChannel: 16, mReserved: 0)
        _ = AudioUnitSetProperty(u!, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &f, UInt32(MemoryLayout<AudioStreamBasicDescription>.size))
        var cb = AURenderCallbackStruct(inputProc: { refCon, flags, ts, bus, frames, _ in
            let vc = Unmanaged<EngineViewController>.fromOpaque(refCon).takeUnretainedValue()
            let list = AudioBufferList.allocate(maximumBuffers: 1)
            defer { free(list.unsafeMutablePointer) }
            var samples = [Int16](repeating: 0, count: Int(frames))
            return samples.withUnsafeMutableBytes { raw in
                list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(raw.count), mData: raw.baseAddress)
                let st = AudioUnitRender(vc.micUnit!, flags, ts, bus, frames, list.unsafeMutablePointer)
                guard st == noErr else { return st }
                let p = raw.baseAddress!.assumingMemoryBound(to: Int16.self)
                vc.micFrames += Int(frames)
                for i in 0..<Int(frames) { vc.micPeak = max(vc.micPeak, abs(Float(p[i]) / 32768)) }
                return noErr
            }
        }, inputProcRefCon: Unmanaged.passUnretained(self).toOpaque())
        _ = AudioUnitSetProperty(u!, kAudioOutputUnitProperty_SetInputCallback, kAudioUnitScope_Global, 0, &cb, UInt32(MemoryLayout<AURenderCallbackStruct>.size))
        _ = AudioUnitInitialize(u!)
        _ = AudioOutputUnitStart(u!)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [self] in
            _ = AudioOutputUnitStop(u!)
            report("remoteio input frames \(micFrames >= 4800) peak \(f2(Double(micPeak)))")
            _ = AudioComponentInstanceDispose(u!)
            report("done")
        }
    }
}
