// isim AudioToolbox (subset): System Sound Services — AudioServicesCreateSystemSoundID, AudioServicesPlaySystemSound,
// AudioServicesPlayAlertSound, completions, kSystemSoundID_Vibrate. Self-authored.
// - Sounds created from files are decoded by the host (any format ffmpeg/GStreamer reads) and played by the mixer.
// - Built-in system sound IDs (1000...4094: key clicks, tinks, alerts) are Apple's recordings, which isim does not
//   ship: they play short synthesized tones instead (adapted).
// - Vibration (kSystemSoundID_Vibrate, alert sounds): the host has no haptics; like UIKit's feedback generators, isim
//   logs it ("isim: haptic vibrate") and shows a large ring in the middle of the screen (adapted).
@_exported import Foundation
import isim_host

public typealias OSStatus = Int32     // MacTypes (isim has no CoreServices module)
public typealias SystemSoundID = UInt32
// CoreAudioTypes format IDs (four-char codes), used in AVAudioRecorder/AVAudioFile settings
public typealias AudioFormatID = UInt32
public let kAudioFormatLinearPCM: AudioFormatID = 0x6C70_636D        // 'lpcm'
public let kAudioFormatMPEG4AAC: AudioFormatID = 0x6161_6320         // 'aac '
public let kAudioFormatAppleLossless: AudioFormatID = 0x616C_6163    // 'alac'
public let kAudioFormatMPEGLayer3: AudioFormatID = 0x2E6D_7033       // '.mp3'
public let kAudioFormatFLAC: AudioFormatID = 0x666C_6163             // 'flac'
public let kAudioFormatOpus: AudioFormatID = 0x6F70_7573             // 'opus'
public let kAudioFormatAppleIMA4: AudioFormatID = 0x696D_6134        // 'ima4'
public let kAudioFormatULaw: AudioFormatID = 0x756C_6177             // 'ulaw'
public let kAudioFormatALaw: AudioFormatID = 0x616C_6177             // 'alaw'
public typealias AudioServicesSystemSoundCompletionProc = @convention(c) (SystemSoundID, UnsafeMutableRawPointer?) -> Void
public let kSystemSoundID_Vibrate: SystemSoundID = 4095
public let kSystemSoundID_UserPreferredAlert: SystemSoundID = 0x1000
public let kSystemSoundID_FlashScreen: SystemSoundID = 0x0FFE
public let kAudioServicesNoError: OSStatus = 0
public let kAudioServicesUnsupportedPropertyError: OSStatus = 0x7074_793F       // 'pty?'
public let kAudioServicesBadPropertySizeError: OSStatus = 0x2173_697A          // '!siz'
public let kAudioServicesBadSpecifierError: OSStatus = 0x7370_633F             // 'spc?'
public let kAudioServicesSystemSoundUnspecifiedError: OSStatus = -1500
public let kAudioServicesSystemSoundClientTimedOutError: OSStatus = -1501
public let kAudioServicesSystemSoundExceededMaximumDurationError: OSStatus = -1502

enum _SystemSounds {
    struct Sound { let buffer: Int32; let duration: Double }
    nonisolated(unsafe) static var sounds: [SystemSoundID: Sound] = [:]
    nonisolated(unsafe) static var synthesized: [SystemSoundID: Sound] = [:]
    nonisolated(unsafe) static var completions: [SystemSoundID: (AudioServicesSystemSoundCompletionProc, UnsafeMutableRawPointer?)] = [:]
    nonisolated(unsafe) static var nextID: SystemSoundID = 0x2000_0001

    /// A sound standing in for an Apple system sound (adapted: Apple's recordings are not shipped):
    /// - 1200...1211: the dial pad's DTMF tones (0-9, *, #) at their standard frequency pairs;
    /// - 1108 (camera shutter): two short noise bursts;
    /// - 1100...1130 and 1103...1105 style UI sounds: clicks (key press, lock, tock);
    /// - other IDs: a two-note chime whose pitch depends on the ID (new mail, sent, alerts, ...).
    static func tone(_ id: SystemSoundID) -> Sound? {
        if let s = synthesized[id] { return s }
        let rate = 48000.0
        let dtmf: [(Double, Double)] = [(941, 1336), (697, 1209), (697, 1336), (697, 1477), (770, 1209), (770, 1336), (770, 1477),
                                        (852, 1209), (852, 1336), (852, 1477), (941, 1209), (941, 1477)]
        let kind = (1200...1211).contains(id) ? 0 : id == 1108 ? 1 : (1100...1130).contains(id) ? 2 : 3
        let dur = [0.2, 0.18, 0.03, 0.35][kind]
        let n = Int(rate * dur)
        var pcm = [Float](repeating: 0, count: n)
        var seed: UInt32 = 0x1234_5678
        let base = 880 * pow(2, Double(Int(id) % 12) / 12)
        for i in 0..<n {
            let t = Double(i) / rate
            var v: Double
            switch kind {
            case 0:
                let (lo, hi) = dtmf[Int(id) - 1200]
                v = (sin(2 * .pi * lo * t) + sin(2 * .pi * hi * t)) * 0.2 * min(1, (dur - t) * 200)
            case 1:
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Double(Int32(bitPattern: seed)) / Double(Int32.max)
                let burst = t < 0.06 ? exp(-t * 60) : t > 0.09 ? exp(-(t - 0.09) * 45) : 0
                v = noise * burst * 0.4
            case 2: v = sin(2 * .pi * 1800 * t) * exp(-t * 180) * 0.35
            default:
                let f = t < dur / 2 ? base * 1.5 : base * 2
                v = sin(2 * .pi * f * t) * exp(-(t.truncatingRemainder(dividingBy: dur / 2)) * 9) * 0.35
            }
            pcm[i] = Float(v)
        }
        let b = pcm.withUnsafeBufferPointer { isim_audio_buffer_create($0.baseAddress, n, 1, rate) }
        guard b > 0 else { return nil }
        let s = Sound(buffer: b, duration: dur)
        synthesized[id] = s
        return s
    }
    /// IDs that are vibrations on iOS (peek, pop, nope and the like) rather than sounds
    static func isHaptic(_ id: SystemSoundID) -> Bool { id == kSystemSoundID_Vibrate || (1519...1521).contains(id) }
    static func play(_ id: SystemSoundID, alert: Bool, completion: (() -> Void)?) {
        if isHaptic(id) || alert {
            NSLog("isim AudioToolbox: vibrate (no haptics on this host)")
            if let f = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_isim_haptic_vibrate") {      // RTLD_DEFAULT: UIKit, when loaded
                unsafeBitCast(f, to: (@convention(c) () -> Void).self)()
            }
        }
        var duration = 0.0
        if !isHaptic(id) {
            let s = sounds[id] ?? (id < 0x2000_0000 ? tone(id) : nil)
            if let s { _ = isim_audio_play(s.buffer, 1, 0); duration = s.duration }
        } else { duration = 0.4 }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            if let (proc, data) = completions[id] { proc(id, data) }
            completion?()
        }
    }
}

public func AudioServicesCreateSystemSoundID(_ inFileURL: CFURL, _ outSystemSoundID: UnsafeMutablePointer<SystemSoundID>) -> OSStatus {
    let url = unsafeBitCast(inFileURL, to: NSURL.self)
    guard let path = url.path else { return kAudioServicesBadSpecifierError }
    var out: UnsafeMutablePointer<Float>? = nil
    var frames = 0, channels: Int32 = 0, rate = 0.0
    guard isim_audio_decode_file(path, &out, &frames, &channels, &rate) != 0, let pcm = out else {
        NSLog("isim AudioToolbox: cannot load system sound %@", path)
        return kAudioServicesSystemSoundUnspecifiedError
    }
    let b = isim_audio_buffer_create(pcm, frames, channels, rate)
    isim_audio_free(pcm)
    let id = _SystemSounds.nextID
    _SystemSounds.nextID += 1
    _SystemSounds.sounds[id] = .init(buffer: b, duration: Double(frames) / rate)
    outSystemSoundID.pointee = id
    return kAudioServicesNoError
}
@discardableResult
public func AudioServicesDisposeSystemSoundID(_ inSystemSoundID: SystemSoundID) -> OSStatus {
    guard let s = _SystemSounds.sounds.removeValue(forKey: inSystemSoundID) else { return kAudioServicesBadSpecifierError }
    if s.buffer > 0 { isim_audio_buffer_release(s.buffer) }
    _SystemSounds.completions[inSystemSoundID] = nil
    return kAudioServicesNoError
}
public func AudioServicesPlaySystemSound(_ inSystemSoundID: SystemSoundID) { _SystemSounds.play(inSystemSoundID, alert: false, completion: nil) }
public func AudioServicesPlayAlertSound(_ inSystemSoundID: SystemSoundID) { _SystemSounds.play(inSystemSoundID, alert: true, completion: nil) }
public func AudioServicesPlaySystemSoundWithCompletion(_ inSystemSoundID: SystemSoundID, _ inCompletionBlock: (@Sendable () -> Void)?) {
    _SystemSounds.play(inSystemSoundID, alert: false, completion: inCompletionBlock)
}
public func AudioServicesPlayAlertSoundWithCompletion(_ inSystemSoundID: SystemSoundID, _ inCompletionBlock: (@Sendable () -> Void)?) {
    _SystemSounds.play(inSystemSoundID, alert: true, completion: inCompletionBlock)
}
/// isim: the completion runs on the main queue (the run loop arguments are ignored).
@discardableResult
public func AudioServicesAddSystemSoundCompletion(_ inSystemSoundID: SystemSoundID, _ inRunLoop: AnyObject?, _ inRunLoopMode: AnyObject?,
                                                  _ inCompletionRoutine: AudioServicesSystemSoundCompletionProc, _ inClientData: UnsafeMutableRawPointer?) -> OSStatus {
    _SystemSounds.completions[inSystemSoundID] = (inCompletionRoutine, inClientData)
    return kAudioServicesNoError
}
public func AudioServicesRemoveSystemSoundCompletion(_ inSystemSoundID: SystemSoundID) { _SystemSounds.completions[inSystemSoundID] = nil }
