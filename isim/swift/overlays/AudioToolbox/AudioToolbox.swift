// isim AudioToolbox (subset): System Sound Services — AudioServicesCreateSystemSoundID, AudioServicesPlaySystemSound,
// AudioServicesPlayAlertSound, completions, kSystemSoundID_Vibrate. Self-authored.
// - Sounds created from files are decoded by the host (any format ffmpeg/GStreamer reads) and played by the mixer.
// - Built-in system sound IDs (1000...4094: key clicks, tinks, alerts) are Apple's recordings, which isim does not
//   ship: they play short synthesized tones instead (adapted).
// - Vibration (kSystemSoundID_Vibrate, alert sounds) is logged only: the host has no haptics.
// No Audio Queues, Audio Units or Audio File/Converter services.
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

    /// A short tone standing in for an Apple system sound: clicks for keyboard IDs, a two-note chime otherwise.
    static func tone(_ id: SystemSoundID) -> Sound? {
        if let s = synthesized[id] { return s }
        let rate = 48000.0
        let click = (1100...1130).contains(id)
        let dur = click ? 0.03 : 0.35
        let n = Int(rate * dur)
        var pcm = [Float](repeating: 0, count: n)
        for i in 0..<n {
            let t = Double(i) / rate
            let f = click ? 1800.0 : (t < dur / 2 ? 1318.5 : 1760.0)
            let env = click ? exp(-t * 180) : exp(-(t.truncatingRemainder(dividingBy: dur / 2)) * 9)
            pcm[i] = Float(sin(2 * .pi * f * t) * env * 0.35)
        }
        let b = pcm.withUnsafeBufferPointer { isim_audio_buffer_create($0.baseAddress, n, 1, rate) }
        guard b > 0 else { return nil }
        let s = Sound(buffer: b, duration: dur)
        synthesized[id] = s
        return s
    }
    static func play(_ id: SystemSoundID, alert: Bool, completion: (() -> Void)?) {
        if id == kSystemSoundID_Vibrate || alert { NSLog("isim AudioToolbox: vibrate (no haptics on this host)") }
        var duration = 0.0
        if id != kSystemSoundID_Vibrate {
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
