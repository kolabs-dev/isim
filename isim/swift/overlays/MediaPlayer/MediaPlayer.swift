// isim MediaPlayer: MPNowPlayingInfoCenter, MPRemoteCommandCenter, MPMediaItemArtwork, MPVolumeView (this file) and the
// music library (MusicLibrary.swift). Self-authored.
// - Now Playing info goes to the device's Control Center and lock screen (isim boot: the shell draws title, artist,
//   artwork, progress and the transport buttons), and is logged when it changes.
// - Remote commands come from those buttons and from the `remote NAME [ARG]` script/control command (play, pause,
//   toggle, stop, next, previous, skipforward [s], skipback [s], seek SECONDS, rate R, like, dislike, bookmark).
// - MPVolumeView's slider is the device volume (isim's own, shared with Control Center and the `volume up|down`
//   command: every app of the device plays at it; the host's volume never changes).
@_exported import Foundation
import UIKit
import AVFoundation
import isim_host

public let MPMediaItemPropertyTitle = "title"
public let MPMediaItemPropertyArtist = "artist"
public let MPMediaItemPropertyAlbumTitle = "albumTitle"
public let MPMediaItemPropertyAlbumArtist = "albumArtist"
public let MPMediaItemPropertyGenre = "genre"
public let MPMediaItemPropertyComposer = "composer"
public let MPMediaItemPropertyPlaybackDuration = "playbackDuration"
public let MPMediaItemPropertyArtwork = "artwork"
public let MPMediaItemPropertyAlbumTrackNumber = "albumTrackNumber"
public let MPMediaItemPropertyMediaType = "mediaType"
public let MPMediaItemPropertyPersistentID = "persistentID"
public let MPNowPlayingInfoPropertyElapsedPlaybackTime = "MPNowPlayingInfoPropertyElapsedPlaybackTime"
public let MPNowPlayingInfoPropertyPlaybackRate = "MPNowPlayingInfoPropertyPlaybackRate"
public let MPNowPlayingInfoPropertyDefaultPlaybackRate = "MPNowPlayingInfoPropertyDefaultPlaybackRate"
public let MPNowPlayingInfoPropertyPlaybackQueueIndex = "MPNowPlayingInfoPropertyPlaybackQueueIndex"
public let MPNowPlayingInfoPropertyPlaybackQueueCount = "MPNowPlayingInfoPropertyPlaybackQueueCount"
public let MPNowPlayingInfoPropertyMediaType = "MPNowPlayingInfoPropertyMediaType"
public let MPNowPlayingInfoPropertyIsLiveStream = "MPNowPlayingInfoPropertyIsLiveStream"
public let MPNowPlayingInfoPropertyAssetURL = "MPNowPlayingInfoPropertyAssetURL"
public let MPNowPlayingInfoPropertyCurrentPlaybackDate = "MPNowPlayingInfoPropertyCurrentPlaybackDate"

public enum MPNowPlayingInfoMediaType: UInt, Sendable { case none = 0, audio, video }
public enum MPNowPlayingPlaybackState: UInt, Sendable { case unknown = 0, playing, paused, stopped, interrupted }

open class MPMediaItemArtwork: NSObject {
    public let bounds: CGRect
    let handler: (CGSize) -> UIImage
    public init(boundsSize: CGSize, requestHandler: @escaping @Sendable (CGSize) -> UIImage) {
        bounds = CGRect(origin: .zero, size: boundsSize); handler = requestHandler
    }
    public convenience init(image: UIImage) { self.init(boundsSize: image.size) { _ in image } }
    open func image(at size: CGSize) -> UIImage? { handler(size) }
}

open class MPNowPlayingInfoCenter: NSObject {
    nonisolated(unsafe) static let shared = MPNowPlayingInfoCenter()
    open class func `default`() -> MPNowPlayingInfoCenter { shared }
    open var nowPlayingInfo: [String: Any]? {
        didSet {
            let title = nowPlayingInfo?[MPMediaItemPropertyTitle] as? String ?? "-"
            let artist = nowPlayingInfo?[MPMediaItemPropertyArtist] as? String
            let elapsed = Self.number(nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime])
            let summary = nowPlayingInfo == nil ? "cleared" : title + (artist.map { " — \($0)" } ?? "") + (elapsed.map { String(format: " @ %.1f s", $0) } ?? "")
            if summary != lastSummary { lastSummary = summary; NSLog("isim MediaPlayer: now playing %@", summary) }
            publish()
        }
    }
    open var playbackState: MPNowPlayingPlaybackState = .unknown {
        didSet {
            NSLog("isim MediaPlayer: playback state %@", ["unknown", "playing", "paused", "stopped", "interrupted"][Int(playbackState.rawValue)])
            publish()
        }
    }
    var lastSummary = ""
    var artworkFile: (artwork: MPMediaItemArtwork, path: String)?
    static func number(_ v: Any?) -> Double? { (v as? NSNumber)?.doubleValue ?? v as? Double ?? (v as? Int).map(Double.init) ?? (v as? Float).map(Double.init) }
    /// the playback rate the system shows: the info's rate, or the playback state when the info has none
    var rate: Double {
        if let r = Self.number(nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackRate]) { return playbackState == .paused ? 0 : r }
        return playbackState == .playing ? 1 : 0
    }
    /// sends the info to the device's Control Center and lock screen (isim boot)
    func publish() {
        guard isim_shell_present() != 0 else { return }
        guard let info = nowPlayingInfo else { isim_shell_request(40, "nowplaying", "", ""); return }
        let field = { (k: String) in (info[k] as? String ?? "").replacingOccurrences(of: "\u{1f}", with: " ") }
        var art = ""
        if let a = info[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork {
            if let f = artworkFile, f.artwork === a { art = f.path }
            else if let png = a.image(at: CGSize(width: 120, height: 120))?.pngData() {
                let path = NSTemporaryDirectory() + "isim-nowplaying-\(ProcessInfo.processInfo.processIdentifier).png"
                if FileManager.default.createFile(atPath: path, contents: png) { art = path; artworkFile = (a, path) }
            }
        }
        let b = [field(MPMediaItemPropertyTitle), field(MPMediaItemPropertyArtist), field(MPMediaItemPropertyAlbumTitle), art].joined(separator: "\u{1f}")
        let c = String(format: "%.3f %.3f %.3f", Self.number(info[MPMediaItemPropertyPlaybackDuration]) ?? 0,
                       Self.number(info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) ?? 0, rate)
        isim_shell_request(40, "nowplaying", b.isEmpty ? " " : b, c)
    }
}

public enum MPRemoteCommandHandlerStatus: Int, Sendable { case success = 0, noSuchContent = 100, noActionableNowPlayingItem = 110, deviceNotFound = 120, commandFailed = 200 }
public enum MPSeekCommandEventType: UInt, Sendable { case beginSeeking = 0, endSeeking }

open class MPRemoteCommandEvent: NSObject {
    public let command: MPRemoteCommand
    public let timestamp: TimeInterval
    init(command: MPRemoteCommand) { self.command = command; timestamp = isim_time() }
}
open class MPSkipIntervalCommandEvent: MPRemoteCommandEvent {
    public let interval: TimeInterval
    init(command: MPRemoteCommand, interval: TimeInterval) { self.interval = interval; super.init(command: command) }
}
open class MPChangePlaybackPositionCommandEvent: MPRemoteCommandEvent {
    public let positionTime: TimeInterval
    init(command: MPRemoteCommand, position: TimeInterval) { positionTime = position; super.init(command: command) }
}
open class MPChangePlaybackRateCommandEvent: MPRemoteCommandEvent {
    public let playbackRate: Float
    init(command: MPRemoteCommand, rate: Float) { playbackRate = rate; super.init(command: command) }
}
open class MPSeekCommandEvent: MPRemoteCommandEvent {
    public let type: MPSeekCommandEventType
    init(command: MPRemoteCommand, type: MPSeekCommandEventType) { self.type = type; super.init(command: command) }
}
open class MPFeedbackCommandEvent: MPRemoteCommandEvent {
    public let isNegative: Bool
    init(command: MPRemoteCommand, negative: Bool) { isNegative = negative; super.init(command: command) }
}

open class MPRemoteCommand: NSObject {
    let name: String
    open var isEnabled = true
    var handlers: [(id: NSObject, block: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus)] = []
    var selectorTargets: [(target: NSObject, action: Selector)] = []
    init(name: String) { self.name = name }
    open func addTarget(handler: @escaping (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus) -> Any {
        let token = NSObject()
        handlers.append((token, handler))
        MPRemoteCommandCenter._shared._startPolling()
        return token
    }
    open func addTarget(_ target: Any, action: Selector) {
        if let t = target as? NSObject { selectorTargets.append((t, action)); MPRemoteCommandCenter._shared._startPolling() }
    }
    open func removeTarget(_ target: Any?) {
        guard let t = target as? NSObject else { handlers.removeAll(); selectorTargets.removeAll(); return }
        handlers.removeAll { $0.id === t }
        selectorTargets.removeAll { $0.target === t }
    }
    open func removeTarget(_ target: Any?, action: Selector?) {
        guard let t = target as? NSObject else { selectorTargets.removeAll(); return }
        selectorTargets.removeAll { $0.target === t && (action == nil || $0.action == action!) }
    }
    func _send(_ e: MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        guard isEnabled else { return .commandFailed }
        var status = MPRemoteCommandHandlerStatus.noActionableNowPlayingItem
        for h in handlers { status = h.block(e) }
        for t in selectorTargets { _ = t.target.perform(t.action, with: e); status = .success }
        return status
    }
}
open class MPSkipIntervalCommand: MPRemoteCommand { open var preferredIntervals: [NSNumber] = [NSNumber(value: 15)] }
open class MPFeedbackCommand: MPRemoteCommand {
    open var isActive = false
    open var localizedTitle = ""
    open var localizedShortTitle = ""
}
open class MPChangePlaybackRateCommand: MPRemoteCommand { open var supportedPlaybackRates: [NSNumber] = [0.5, 1, 1.5, 2].map { NSNumber(value: $0) } }
open class MPChangePlaybackPositionCommand: MPRemoteCommand {}
open class MPChangeRepeatModeCommand: MPRemoteCommand {}
open class MPChangeShuffleModeCommand: MPRemoteCommand {}

open class MPRemoteCommandCenter: NSObject {
    nonisolated(unsafe) static let _shared = MPRemoteCommandCenter()
    open class func shared() -> MPRemoteCommandCenter { _shared }
    public let playCommand = MPRemoteCommand(name: "play")
    public let pauseCommand = MPRemoteCommand(name: "pause")
    public let stopCommand = MPRemoteCommand(name: "stop")
    public let togglePlayPauseCommand = MPRemoteCommand(name: "toggle")
    public let nextTrackCommand = MPRemoteCommand(name: "next")
    public let previousTrackCommand = MPRemoteCommand(name: "previous")
    public let skipForwardCommand = MPSkipIntervalCommand(name: "skipforward")
    public let skipBackwardCommand = MPSkipIntervalCommand(name: "skipback")
    public let seekForwardCommand = MPRemoteCommand(name: "seekforward")
    public let seekBackwardCommand = MPRemoteCommand(name: "seekback")
    public let changePlaybackPositionCommand = MPChangePlaybackPositionCommand(name: "seek")
    public let changePlaybackRateCommand = MPChangePlaybackRateCommand(name: "rate")
    public let changeRepeatModeCommand = MPChangeRepeatModeCommand(name: "repeat")
    public let changeShuffleModeCommand = MPChangeShuffleModeCommand(name: "shuffle")
    public let likeCommand = MPFeedbackCommand(name: "like")
    public let dislikeCommand = MPFeedbackCommand(name: "dislike")
    public let bookmarkCommand = MPFeedbackCommand(name: "bookmark")
    public let enableLanguageOptionCommand = MPRemoteCommand(name: "enablelanguage")
    public let disableLanguageOptionCommand = MPRemoteCommand(name: "disablelanguage")
    var timer: Timer?

    func _startPolling() {
        guard timer == nil else { return }
        // the command center takes the remote commands (UIKit's remoteControlReceived(with:) no longer gets them)
        NotificationCenter.default.post(name: Notification.Name("_IsimRemoteCommandCenterActive"), object: nil)
        timer = Timer._isimScheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?._poll() }
    }
    func _poll() {
        var buf = [CChar](repeating: 0, count: 64)
        while isim_remote_command_poll(&buf, 64) != 0 {
            let line = String(cString: buf).trimmingCharacters(in: .whitespaces)
            let parts = line.split(separator: " ").map(String.init)
            guard let name = parts.first?.lowercased() else { continue }
            let arg = parts.count > 1 ? Double(parts[1]) : nil
            let all: [MPRemoteCommand] = [playCommand, pauseCommand, stopCommand, togglePlayPauseCommand, nextTrackCommand, previousTrackCommand,
                                          skipForwardCommand, skipBackwardCommand, seekForwardCommand, seekBackwardCommand, changePlaybackPositionCommand,
                                          changePlaybackRateCommand, changeRepeatModeCommand, changeShuffleModeCommand, likeCommand, dislikeCommand,
                                          bookmarkCommand]
            guard let cmd = all.first(where: { $0.name == name }) else { NSLog("isim MediaPlayer: unknown remote command '%@'", line); continue }
            let event: MPRemoteCommandEvent
            switch cmd {
            case let c as MPSkipIntervalCommand: event = MPSkipIntervalCommandEvent(command: c, interval: arg ?? c.preferredIntervals.first?.doubleValue ?? 15)
            case let c as MPChangePlaybackPositionCommand: event = MPChangePlaybackPositionCommandEvent(command: c, position: arg ?? 0)
            case let c as MPChangePlaybackRateCommand: event = MPChangePlaybackRateCommandEvent(command: c, rate: Float(arg ?? 1))
            case let c as MPFeedbackCommand: event = MPFeedbackCommandEvent(command: c, negative: c === dislikeCommand)
            default: event = cmd === seekForwardCommand || cmd === seekBackwardCommand ? MPSeekCommandEvent(command: cmd, type: arg == 0 ? .endSeeking : .beginSeeking) : MPRemoteCommandEvent(command: cmd)
            }
            var target = cmd, sent = event
            // like iOS, a toggle reaches play or pause when the app only handles those
            if cmd === togglePlayPauseCommand && cmd.handlers.isEmpty && cmd.selectorTargets.isEmpty {
                target = MPNowPlayingInfoCenter.shared.rate > 0 ? pauseCommand : playCommand
                sent = MPRemoteCommandEvent(command: target)
            }
            let status = target._send(sent)
            NSLog("isim MediaPlayer: remote command %@ -> %@", line, status == .success ? "success" : "status \(status.rawValue)")
        }
    }
}

/// The device volume slider (and the route button: the audio route picker).
open class MPVolumeView: UIView {
    open var showsVolumeSlider = true { didSet { slider.isHidden = !showsVolumeSlider } }
    open var showsRouteButton = false { didSet { routeButton.isHidden = !showsRouteButton; setNeedsLayout() } }
    open var isWirelessRouteActive: Bool { AVAudioSession.sharedInstance().currentRoute.outputs.contains { $0.portType == .airPlay } }
    open var isWirelessRoutesAvailable: Bool { true }
    let slider = UISlider()
    let routeButton = UIButton(type: .system)
    var observer: NSObjectProtocol?
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    public required init?(coder: NSCoder) { super.init(coder: coder); setup() }
    func setup() {
        slider.value = Float(isim_device_volume())
        slider.accessibilityIdentifier = "isim-volume-slider"
        slider.minimumValueImage = UIImage(systemName: "speaker.fill")
        slider.maximumValueImage = UIImage(systemName: "speaker.wave.3.fill")
        slider.addTarget(self, action: #selector(changed), for: .valueChanged)
        addSubview(slider)
        routeButton.setImage(UIImage(systemName: "airplayaudio"), for: .normal)
        routeButton.accessibilityIdentifier = "isim-volume-route"
        routeButton.accessibilityLabel = "AirPlay"
        routeButton.isHidden = true
        routeButton.addTarget(self, action: #selector(route), for: .touchUpInside)
        addSubview(routeButton)
        observer = NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { [weak self] n in
            guard let t = n.object as? String, t.hasPrefix("volume "), let v = Float(t.dropFirst(7)) else { return }
            MainActor.assumeIsolated { self?.slider.value = v }
        }
    }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    /// the device volume: this app plays at it now, the device (Control Center, other apps) hears about it
    @objc func changed() {
        let v = Double(slider.value)
        isim_device_volume_set(v, 1)
        if isim_shell_present() != 0 { isim_shell_request(40, "volume", String(format: "%.4f", v), "") }
        NotificationCenter.default.post(name: Notification.Name("_IsimSystemEvent"), object: String(format: "volume %.4f", v) as NSString)
    }
    @objc func route() { AVAudioSession._isimShowRoutePicker(from: routeButton) }
    open override func layoutSubviews() {
        super.layoutSubviews()
        let rb: CGFloat = showsRouteButton ? 34 : 0
        slider.frame = CGRect(x: 0, y: 0, width: bounds.width - rb, height: bounds.height)
        routeButton.frame = CGRect(x: bounds.width - rb, y: 0, width: rb, height: bounds.height)
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: 34) }
    open func volumeSliderRect(forBounds bounds: CGRect) -> CGRect { slider.frame }
    open func routeButtonRect(forBounds bounds: CGRect) -> CGRect { routeButton.frame }
}
