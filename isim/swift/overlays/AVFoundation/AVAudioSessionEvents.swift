// isim AVFoundation: AVAudioSession routes, interruptions and route changes (self-authored, iOS API names).
// The host has one output; isim reports the built-in speaker (and microphone) until a script changes the route.
// Interruptions and route changes come from the `audio` script/control command (adapted, like the Simulator's
// lack of phone calls): `audio interrupt begin`, `audio interrupt end [resume]`, `audio route headphones|speaker|
// bluetooth|carplay|airplay|usb`. As on iOS, an interruption pauses AVAudioPlayers; nothing resumes on its own.
import Foundation
import isim_host

extension AVAudioSession {
    public struct Port: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let builtInSpeaker = Port(rawValue: "Speaker")
        public static let builtInReceiver = Port(rawValue: "Receiver")
        public static let builtInMic = Port(rawValue: "MicrophoneBuiltIn")
        public static let headphones = Port(rawValue: "Headphones")
        public static let headsetMic = Port(rawValue: "MicrophoneWired")
        public static let bluetoothA2DP = Port(rawValue: "BluetoothA2DPOutput")
        public static let bluetoothHFP = Port(rawValue: "BluetoothHFP")
        public static let bluetoothLE = Port(rawValue: "BluetoothLE")
        public static let carAudio = Port(rawValue: "CarAudio")
        public static let airPlay = Port(rawValue: "AirPlay")
        public static let HDMI = Port(rawValue: "HDMIOutput")
        public static let usbAudio = Port(rawValue: "USBAudio")
        public static let lineOut = Port(rawValue: "LineOut")
        public static let lineIn = Port(rawValue: "LineIn")
    }
    public enum InterruptionType: UInt, Sendable { case ended = 0, began = 1 }
    public struct InterruptionOptions: OptionSet, Sendable {
        public let rawValue: UInt
        public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let shouldResume = InterruptionOptions(rawValue: 1)
    }
    public enum InterruptionReason: UInt, Sendable { case `default` = 0, appWasSuspended = 1, builtInMicMuted = 2, routeDisconnected = 4 }
    public enum RouteChangeReason: UInt, Sendable {
        case unknown = 0, newDeviceAvailable = 1, oldDeviceUnavailable = 2, categoryChange = 3, override = 4, wakeFromSleep = 6,
             noSuitableRouteForCategory = 7, routeConfigurationChange = 8
    }
    public enum PortOverride: UInt, Sendable { case none = 0, speaker = 0x73706B72 }
    public enum SilenceSecondaryAudioHintType: UInt, Sendable { case end = 0, begin = 1 }

    public var currentRoute: AVAudioSessionRouteDescription { _AudioSessionEvents.route }
    public var availableInputs: [AVAudioSessionPortDescription]? { _AudioSessionEvents.route.inputs }
    public var preferredInput: AVAudioSessionPortDescription? { nil }
    public func setPreferredInput(_ inPort: AVAudioSessionPortDescription?) throws {}
    public func overrideOutputAudioPort(_ portOverride: PortOverride) throws {
        if portOverride == .speaker { _AudioSessionEvents.setRoute("speaker", reason: .override) }
    }
    public var maximumOutputNumberOfChannels: Int { 2 }
    public var outputNumberOfChannels: Int { 2 }
    public var preferredSampleRate: Double { 48000 }
    public var allowHapticsAndSystemSoundsDuringRecording: Bool { false }
}
public let AVAudioSessionInterruptionTypeKey = "AVAudioSessionInterruptionTypeKey"
public let AVAudioSessionInterruptionOptionKey = "AVAudioSessionInterruptionOptionKey"
public let AVAudioSessionInterruptionReasonKey = "AVAudioSessionInterruptionReasonKey"
public let AVAudioSessionInterruptionWasSuspendedKey = "AVAudioSessionInterruptionWasSuspendedKey"
public let AVAudioSessionRouteChangeReasonKey = "AVAudioSessionRouteChangeReasonKey"
public let AVAudioSessionRouteChangePreviousRouteKey = "AVAudioSessionRouteChangePreviousRouteKey"
public let AVAudioSessionSilenceSecondaryAudioHintTypeKey = "AVAudioSessionSilenceSecondaryAudioHintTypeKey"

open class AVAudioSessionPortDescription: NSObject, @unchecked Sendable {
    public let portType: AVAudioSession.Port
    public let portName: String
    public let uid: String
    public var channels: [AnyObject]? { nil }
    public var hasHardwareVoiceCallProcessing: Bool { portType == .builtInMic }
    init(_ t: AVAudioSession.Port, _ name: String) { portType = t; portName = name; uid = t.rawValue }
}
open class AVAudioSessionRouteDescription: NSObject, @unchecked Sendable {
    public let inputs: [AVAudioSessionPortDescription]
    public let outputs: [AVAudioSessionPortDescription]
    init(inputs: [AVAudioSessionPortDescription], outputs: [AVAudioSessionPortDescription]) { self.inputs = inputs; self.outputs = outputs }
    open override var description: String { "<AVAudioSessionRouteDescription inputs=\(inputs.map(\.portType.rawValue)) outputs=\(outputs.map(\.portType.rawValue))>" }
}

/// Polls the `audio` script command queue (host_capture.c) on the main run loop.
enum _AudioSessionEvents {
    final class WeakPlayer { weak var p: AVAudioPlayer?; init(_ p: AVAudioPlayer) { self.p = p } }
    nonisolated(unsafe) static var players: [WeakPlayer] = []
    nonisolated(unsafe) static var timer: Timer?
    nonisolated(unsafe) static var interrupted = false
    nonisolated(unsafe) static var route = make("speaker")

    static func make(_ name: String) -> AVAudioSessionRouteDescription {
        let mic = AVAudioSessionPortDescription(.builtInMic, "iPhone Microphone")
        switch name {
        case "headphones": return .init(inputs: [mic], outputs: [.init(.headphones, "Headphones")])
        case "headset": return .init(inputs: [.init(.headsetMic, "Headset Microphone")], outputs: [.init(.headphones, "Headphones")])
        case "bluetooth": return .init(inputs: [mic], outputs: [.init(.bluetoothA2DP, "Bluetooth Headphones")])
        case "carplay", "car": return .init(inputs: [mic], outputs: [.init(.carAudio, "CarPlay")])
        case "airplay": return .init(inputs: [mic], outputs: [.init(.airPlay, "AirPlay")])
        case "usb": return .init(inputs: [mic], outputs: [.init(.usbAudio, "USB Audio")])
        case "hdmi": return .init(inputs: [mic], outputs: [.init(.HDMI, "HDMI")])
        case "receiver": return .init(inputs: [mic], outputs: [.init(.builtInReceiver, "Receiver")])
        default: return .init(inputs: [mic], outputs: [.init(.builtInSpeaker, "Speaker")])
        }
    }
    static func register(_ p: AVAudioPlayer) {
        players.removeAll { $0.p == nil }
        players.append(WeakPlayer(p))
        start()
    }
    static func start() {
        let go = {
            guard timer == nil else { return }
            let t = Timer(timeInterval: 0.1, repeats: true) { _ in poll() }
            RunLoop.main.add(t, forMode: .common)
            timer = t
        }
        if Thread.isMainThread { go() } else { DispatchQueue.main.async(execute: go) }
    }
    static func poll() {
        var buf = [CChar](repeating: 0, count: 64)
        while isim_audio_session_poll(&buf, 64) != 0 {
            let words = String(cString: buf).lowercased().split(separator: " ").map(String.init)
            guard let cmd = words.first else { continue }
            if cmd == "interrupt" || cmd == "interruption" {
                let begin = words.count < 2 || words[1] == "begin" || words[1] == "began"
                interrupt(begin: begin, resume: words.contains("resume"))
            } else if cmd == "route", words.count > 1 {
                setRoute(words[1], reason: nil)
            } else if cmd == "silence" || cmd == "secondary" {
                let begin = words.count < 2 || words[1] == "begin"
                NotificationCenter.default.post(name: AVAudioSession.silenceSecondaryAudioHintNotification, object: AVAudioSession.sharedInstance(),
                                                userInfo: [AVAudioSessionSilenceSecondaryAudioHintTypeKey: NSNumber(value: (begin ? AVAudioSession.SilenceSecondaryAudioHintType.begin : .end).rawValue)])
            } else if cmd == "reset" {
                NotificationCenter.default.post(name: AVAudioSession.mediaServicesWereResetNotification, object: AVAudioSession.sharedInstance())
            } else {
                NSLog("isim AVFoundation: unknown audio command '%@' (interrupt begin|end [resume], route NAME, silence begin|end, reset)", String(cString: buf))
            }
        }
    }
    static func interrupt(begin: Bool, resume: Bool) {
        let s = AVAudioSession.sharedInstance()
        if begin {
            interrupted = true
            for w in players { if let p = w.p, p.isPlaying { p.pause() } }
            NSLog("isim AVFoundation: audio session interruption began")
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: s,
                                            userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.began.rawValue),
                                                       AVAudioSessionInterruptionReasonKey: NSNumber(value: AVAudioSession.InterruptionReason.default.rawValue)])
        } else {
            interrupted = false
            NSLog("isim AVFoundation: audio session interruption ended%@", resume ? " (should resume)" : "")
            NotificationCenter.default.post(name: AVAudioSession.interruptionNotification, object: s,
                                            userInfo: [AVAudioSessionInterruptionTypeKey: NSNumber(value: AVAudioSession.InterruptionType.ended.rawValue),
                                                       AVAudioSessionInterruptionOptionKey: NSNumber(value: (resume ? AVAudioSession.InterruptionOptions.shouldResume : []).rawValue)])
        }
    }
    static func setRoute(_ name: String, reason: AVAudioSession.RouteChangeReason?) {
        let old = route
        let new = make(name)
        guard new.outputs.first?.portType != old.outputs.first?.portType else { return }
        route = new
        // iOS: plugging something in is "new device available"; going back to the speaker is "old device unavailable"
        let r = reason ?? (new.outputs.first?.portType == .builtInSpeaker ? .oldDeviceUnavailable : .newDeviceAvailable)
        NSLog("isim AVFoundation: audio route changed to %@", new.outputs.first?.portName ?? name)
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionRouteChangeReasonKey: NSNumber(value: r.rawValue),
                                                   AVAudioSessionRouteChangePreviousRouteKey: old])
    }
}
extension AVAudioSession {
    public static let mediaServicesWereLostNotification = Notification.Name("AVAudioSessionMediaServicesWereLostNotification")
    public static let mediaServicesWereResetNotification = Notification.Name("AVAudioSessionMediaServicesWereResetNotification")
}
