// isim MediaPlayer (subset): MPNowPlayingInfoCenter, MPRemoteCommandCenter, MPMediaItemArtwork, MPVolumeView.
// Self-authored. isim has no lock screen or Control Center: now-playing info is stored (and logged when it
// changes), and remote commands come from the `remote NAME [ARG]` script/control command (play, pause, toggle,
// stop, next, previous, skipforward [s], skipback [s], seek SECONDS, rate R, like, dislike, bookmark).
// MPVolumeView is a stub (a slider that does not change the host volume). No music library.
@_exported import Foundation
import UIKit
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
            let elapsed = (nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? NSNumber)?.doubleValue
                ?? nowPlayingInfo?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? Double
            let summary = nowPlayingInfo == nil ? "cleared" : title + (artist.map { " — \($0)" } ?? "") + (elapsed.map { String(format: " @ %.1f s", $0) } ?? "")
            if summary != lastSummary { lastSummary = summary; NSLog("isim MediaPlayer: now playing %@", summary) }
        }
    }
    open var playbackState: MPNowPlayingPlaybackState = .unknown {
        didSet { NSLog("isim MediaPlayer: playback state %@", ["unknown", "playing", "paused", "stopped", "interrupted"][Int(playbackState.rawValue)]) }
    }
    var lastSummary = ""
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
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?._poll() }
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
            let status = cmd._send(event)
            NSLog("isim MediaPlayer: remote command %@ -> %@", line, status == .success ? "success" : "status \(status.rawValue)")
        }
    }
}

/// Stub: a volume slider that does not change the host's volume (isim has no system volume).
open class MPVolumeView: UIView {
    open var showsVolumeSlider = true { didSet { slider.isHidden = !showsVolumeSlider } }
    open var showsRouteButton = false
    open var isWirelessRouteActive: Bool { false }
    let slider = UISlider()
    public override init(frame: CGRect) {
        super.init(frame: frame)
        slider.value = 1
        slider.accessibilityIdentifier = "isim-volume-slider"
        addSubview(slider)
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open override func layoutSubviews() { super.layoutSubviews(); slider.frame = bounds }
    open override func sizeThatFits(_ size: CGSize) -> CGSize { CGSize(width: size.width, height: 34) }
}
