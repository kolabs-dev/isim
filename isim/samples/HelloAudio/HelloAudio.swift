// Sample: audio beyond playback on isim — AVSpeechSynthesizer (espeak-ng on the host), AudioToolbox system sounds,
// AVAudioEngine effects rendered offline (EQ, reverb, time pitch, delay, distortion), AVAudioRecorder and an input
// node tap fed by ISIM_AUDIO_INPUT, AVAudioFile writing/reading (WAV, and AAC via the host's ffmpeg),
// MPNowPlayingInfoCenter / MPRemoteCommandCenter (commands from the `remote` script command) and MPVolumeView.
import UIKit
import AVFoundation
import AudioToolbox
import MediaPlayer

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AudioViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

func log(_ s: String) { NSLog("HelloAudio: %@", s) }
func f2(_ x: Double) -> String { String(format: "%.2f", x) }
func rms(_ b: AVAudioPCMBuffer, from: Int = 0, to: Int? = nil) -> Double {
    let p = b.floatChannelData![0], end = to ?? Int(b.frameLength)
    guard end > from else { return 0 }
    var s = 0.0
    for i in from..<end { s += Double(p[i] * p[i]) }
    return (s / Double(end - from)).squareRoot()
}

final class AudioViewController: UIViewController, AVSpeechSynthesizerDelegate, AVAudioRecorderDelegate {
    let synth = AVSpeechSynthesizer()
    let label = UILabel()
    var recorder: AVAudioRecorder?
    let engine = AVAudioEngine()
    var tapFrames = 0
    var tapPeak: Float = 0
    var soundID: SystemSoundID = 0
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let title = UILabel(); title.text = "Audio"; title.font = .systemFont(ofSize: 34, weight: .bold)
        title.frame = CGRect(x: 20, y: 64, width: 300, height: 41); view.addSubview(title)
        label.frame = CGRect(x: 20, y: 120, width: 362, height: 60); label.numberOfLines = 2
        label.accessibilityIdentifier = "spoken"; view.addSubview(label)
        let speak = UIButton(type: .system); speak.setTitle("Speak", for: .normal); speak.accessibilityIdentifier = "speak"
        speak.frame = CGRect(x: 20, y: 190, width: 120, height: 44)
        speak.addTarget(self, action: #selector(speakTapped), for: .touchUpInside); view.addSubview(speak)
        let volume = MPVolumeView(frame: CGRect(x: 20, y: 250, width: 362, height: 34)); view.addSubview(volume)

        try? AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try? AVAudioSession.sharedInstance().setActive(true)
        synth.delegate = self
        voices()
        systemSounds()
        effects()
        writeAndReadFiles()
        nowPlaying()
        AVAudioApplication.requestRecordPermission { granted in
            log("record permission \(granted)")
            self.record()
            self.inputTap()
        }
    }

    // MARK: speech
    func voices() {
        let all = AVSpeechSynthesisVoice.speechVoices()
        let fr = AVSpeechSynthesisVoice(language: "fr-FR")
        log("voices \(all.count > 10) fr=\(fr?.language ?? "nil") \(fr?.name ?? "")")
        let u = AVSpeechUtterance(string: "Testing one two three")
        var frames = 0, rate = 0.0, peak: Float = 0
        synth.write(u) { buffer in
            guard let b = buffer as? AVAudioPCMBuffer else { return }
            frames += Int(b.frameLength); rate = b.format.sampleRate
            for i in 0..<Int(b.frameLength) { peak = max(peak, abs(b.floatChannelData![0][i])) }
            if b.frameLength == 0 { log("speech rendered \(f2(Double(frames) / rate)) s, audible \(peak > 0.05)") }
        }
    }
    @objc func speakTapped() {
        let u = AVSpeechUtterance(string: "Hello from the isim speech synthesizer")
        u.voice = AVSpeechSynthesisVoice(language: "en-US")
        u.rate = AVSpeechUtteranceDefaultSpeechRate
        synth.speak(u)
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didStart u: AVSpeechUtterance) { log("speech didStart speaking=\(s.isSpeaking)") }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, willSpeakRangeOfSpeechString r: NSRange, utterance u: AVSpeechUtterance) {
        let w = (u.speechString as NSString).substring(with: r)
        label.text = w
        log("speech word \(w)")
    }
    func speechSynthesizer(_ s: AVSpeechSynthesizer, didFinish u: AVSpeechUtterance) { log("speech didFinish") }

    // MARK: AudioToolbox
    func systemSounds() {
        AudioServicesPlaySystemSoundWithCompletion(1104) { log("system sound 1104 completed") }
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    // MARK: effects, rendered offline
    func sine(_ seconds: Double, _ freq: Double, _ format: AVAudioFormat) -> AVAudioPCMBuffer {
        let n = AVAudioFrameCount(seconds * format.sampleRate)
        let b = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: n)!
        b.frameLength = n
        for c in 0..<Int(format.channelCount) {
            for i in 0..<Int(n) { b.floatChannelData![c][i] = Float(0.5 * sin(2 * .pi * freq * Double(i) / format.sampleRate)) }
        }
        return b
    }
    /// Renders `seconds` of a 1 s, 440 Hz tone through `effect`; returns the output and when the buffer finished.
    func render(_ effect: AVAudioUnitEffect?, seconds: Double = 2) -> (AVAudioPCMBuffer, Double) {
        let engine = AVAudioEngine(), player = AVAudioPlayerNode()
        let format = AVAudioFormat(standardFormatWithSampleRate: 48000, channels: 1)!
        engine.attach(player)
        if let effect {
            engine.attach(effect)
            engine.connect(player, to: effect, format: format)
            engine.connect(effect, to: engine.mainMixerNode, format: format)
        } else { engine.connect(player, to: engine.mainMixerNode, format: format) }
        try! engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096)
        try! engine.start()
        var finishedAt = -1.0
        player.scheduleBuffer(sine(1, 440, format)) { finishedAt = Double(engine.manualRenderingSampleTime) / 48000 }
        player.play()
        let out = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(seconds * 48000))!
        let chunk = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096)!
        while out.frameLength < out.frameCapacity {
            let n = min(4096, out.frameCapacity - out.frameLength)
            _ = try! engine.renderOffline(n, to: chunk)
            memcpy(out.floatChannelData![0] + Int(out.frameLength), chunk.floatChannelData![0], Int(chunk.frameLength) * 4)
            out.frameLength += chunk.frameLength
        }
        engine.stop()
        return (out, finishedAt)
    }
    func effects() {
        let (dry, dryEnd) = render(nil)
        let eq = AVAudioUnitEQ(numberOfBands: 1)
        eq.bands[0].filterType = .lowPass; eq.bands[0].frequency = 150; eq.bands[0].bypass = false
        let (low, _) = render(eq)
        let boost = AVAudioUnitEQ(numberOfBands: 1)
        boost.bands[0].filterType = .parametric; boost.bands[0].frequency = 440; boost.bands[0].gain = 12; boost.bands[0].bandwidth = 1; boost.bands[0].bypass = false
        let (boosted, _) = render(boost)
        let reverb = AVAudioUnitReverb(); reverb.loadFactoryPreset(.largeHall); reverb.wetDryMix = 50
        let (wet, _) = render(reverb)
        let pitch = AVAudioUnitTimePitch(); pitch.rate = 2
        let (_, fastEnd) = render(pitch)
        let delay = AVAudioUnitDelay(); delay.delayTime = 0.25; delay.feedback = 30; delay.wetDryMix = 50
        let (echo, _) = render(delay)
        let dist = AVAudioUnitDistortion(); dist.loadFactoryPreset(.multiDistortedCubed); dist.wetDryMix = 100
        let (crushed, _) = render(dist)
        let tail = Int(1.2 * 48000)
        log("effects dry rms \(f2(rms(dry, to: 48000))) end \(f2(dryEnd)) tail \(f2(rms(dry, from: tail)))")
        log("effects eq lowpass \(rms(low, to: 48000) < rms(dry, to: 48000) * 0.5) boost \(rms(boosted, to: 48000) > rms(dry, to: 48000) * 2)")
        log("effects reverb tail \(rms(wet, from: tail) > 0.001)")
        log("effects timepitch rate2 end \(f2(fastEnd))")
        log("effects delay tail \(rms(echo, from: Int(1.05 * 48000), to: Int(1.2 * 48000)) > 0.01) distortion \(rms(crushed, to: 48000) > rms(dry, to: 48000))")
    }

    // MARK: files
    func writeAndReadFiles() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let wav = docs.appendingPathComponent("tone.wav"), m4a = docs.appendingPathComponent("tone.m4a")
        do {
            for url in [wav, m4a] {
                let f = try AVAudioFile(forWriting: url, settings: [AVFormatIDKey: url == wav ? kAudioFormatLinearPCM : kAudioFormatMPEG4AAC,
                                                                     AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1])
                try f.write(from: sine(0.5, 880, format))
                f.close()
            }
            let back = try AVAudioFile(forReading: wav), backAAC = try AVAudioFile(forReading: m4a)
            log("file wav \(f2(Double(back.length) / back.fileFormat.sampleRate)) s; m4a \(f2(Double(backAAC.length) / backAAC.fileFormat.sampleRate)) s")
            var id: SystemSoundID = 0
            let st = AudioServicesCreateSystemSoundID(wav as CFURL, &id)
            soundID = id
            AudioServicesPlaySystemSoundWithCompletion(id) { log("custom system sound completed (status \(st))") }
        } catch { log("file error \(error)") }
    }

    // MARK: recording
    func record() {
        let url = docs.appendingPathComponent("memo.m4a")
        do {
            let r = try AVAudioRecorder(url: url, settings: [AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: 44100, AVNumberOfChannelsKey: 1,
                                                             AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue])
            r.delegate = self; r.isMeteringEnabled = true
            recorder = r
            r.record(forDuration: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                r.updateMeters()
                log("recorder metering \(r.averagePower(forChannel: 0) > -20) recording=\(r.isRecording)")
            }
        } catch { log("recorder error \(error)") }
    }
    func audioRecorderDidFinishRecording(_ r: AVAudioRecorder, successfully flag: Bool) {
        do {
            let f = try AVAudioFile(forReading: r.url)
            let b = AVAudioPCMBuffer(pcmFormat: f.processingFormat, frameCapacity: AVAudioFrameCount(f.length))!
            try f.read(into: b)
            log("recorded \(flag) \(f2(Double(f.length) / f.fileFormat.sampleRate)) s rms \(f2(rms(b)))")
            let player = try AVAudioPlayer(contentsOf: r.url)
            log("recording plays back: duration \(f2(player.duration))")
        } catch { log("recording read error \(error)") }
    }
    func inputTap() {
        let input = engine.inputNode
        let fmt = input.outputFormat(forBus: 0)
        input.installTap(onBus: 0, bufferSize: 4800, format: fmt) { [weak self] b, _ in
            guard let self else { return }
            self.tapFrames += Int(b.frameLength)
            for i in 0..<Int(b.frameLength) { self.tapPeak = max(self.tapPeak, abs(b.floatChannelData![0][i])) }
        }
        try? engine.start()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            input.removeTap(onBus: 0)
            log("input tap \(self.tapFrames >= 24000) frames, \(Int(fmt.sampleRate)) Hz \(fmt.channelCount) ch, peak \(f2(Double(self.tapPeak)))")
        }
    }

    // MARK: MediaPlayer
    func nowPlaying() {
        let center = MPRemoteCommandCenter.shared()
        var info: [String: Any] = [MPMediaItemPropertyTitle: "Test Tone", MPMediaItemPropertyArtist: "isim",
                                   MPMediaItemPropertyPlaybackDuration: 30.0, MPNowPlayingInfoPropertyElapsedPlaybackTime: 0.0,
                                   MPNowPlayingInfoPropertyPlaybackRate: 1.0]
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        _ = center.playCommand.addTarget { _ in log("remote play"); return .success }
        _ = center.pauseCommand.addTarget { _ in log("remote pause"); return .success }
        center.skipForwardCommand.preferredIntervals = [NSNumber(value: 15)]
        _ = center.skipForwardCommand.addTarget { e in
            log("remote skip \(Int((e as! MPSkipIntervalCommandEvent).interval))"); return .success
        }
        _ = center.changePlaybackPositionCommand.addTarget { e in
            let t = (e as! MPChangePlaybackPositionCommandEvent).positionTime
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = t
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            log("remote seek \(Int(t))"); return .success
        }
        center.nextTrackCommand.isEnabled = false
    }
}
