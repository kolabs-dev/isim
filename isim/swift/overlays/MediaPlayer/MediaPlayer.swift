// isim MediaPlayer: MPNowPlayingInfoCenter, MPRemoteCommandCenter, MPMediaItemArtwork, MPVolumeView (this file) and the
// music library (MusicLibrary.swift). Self-authored.
// - Now Playing info goes to the device's Control Center and lock screen (isim boot: the shell draws title, artist,
//   artwork, progress and the transport buttons), and is logged when it changes.
// - Remote commands come from those buttons and from the `remote NAME [ARG]` script/control command (play, pause,
//   toggle, stop, next, previous, skipforward [s], skipback [s], seek SECONDS, rate R, like, dislike, bookmark,
//   repeat off|one|all, shuffle off|items|collections, rating N, language ID, nolanguage ID).
// - MPNowPlayingSession (iOS 16): per-session info centers and command centers, published from AVPlayers.
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
public let MPNowPlayingInfoPropertyPlaybackProgress = "MPNowPlayingInfoPropertyPlaybackProgress"
public let MPNowPlayingInfoPropertyChapterNumber = "MPNowPlayingInfoPropertyChapterNumber"
public let MPNowPlayingInfoPropertyChapterCount = "MPNowPlayingInfoPropertyChapterCount"
public let MPNowPlayingInfoPropertyAvailableLanguageOptions = "MPNowPlayingInfoPropertyAvailableLanguageOptions"
public let MPNowPlayingInfoPropertyCurrentLanguageOptions = "MPNowPlayingInfoPropertyCurrentLanguageOptions"
public let MPNowPlayingInfoCollectionIdentifier = "MPNowPlayingInfoCollectionIdentifier"
public let MPNowPlayingInfoPropertyExternalContentIdentifier = "MPNowPlayingInfoPropertyExternalContentIdentifier"
public let MPNowPlayingInfoPropertyExternalUserProfileIdentifier = "MPNowPlayingInfoPropertyExternalUserProfileIdentifier"
public let MPNowPlayingInfoPropertyServiceIdentifier = "MPNowPlayingInfoPropertyServiceIdentifier"
public let MPNowPlayingInfoPropertyExcludeFromSuggestions = "MPNowPlayingInfoPropertyExcludeFromSuggestions"

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
            let progress = Self.number(nowPlayingInfo?[MPNowPlayingInfoPropertyPlaybackProgress])
            let summary = nowPlayingInfo == nil ? "cleared" : title + (artist.map { " — \($0)" } ?? "") + (elapsed.map { String(format: " @ %.1f s", $0) } ?? "")
                + (progress.map { String(format: " (%.0f%%)", $0 * 100) } ?? "")
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
        let duration = Self.number(info[MPMediaItemPropertyPlaybackDuration]) ?? 0
        // the elapsed time, or the playback progress (0...1) of the duration
        let elapsed = Self.number(info[MPNowPlayingInfoPropertyElapsedPlaybackTime]) ?? Self.number(info[MPNowPlayingInfoPropertyPlaybackProgress]).map { $0 * duration } ?? 0
        let c = String(format: "%.3f %.3f %.3f", duration, elapsed, rate)
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
public enum MPRepeatType: Int, Sendable { case off = 0, one, all }
public enum MPShuffleType: Int, Sendable { case off = 0, items, collections }
open class MPChangeRepeatModeCommandEvent: MPRemoteCommandEvent {
    public let repeatType: MPRepeatType
    public let preservesRepeatMode: Bool
    init(command: MPRemoteCommand, repeatType: MPRepeatType) { self.repeatType = repeatType; preservesRepeatMode = false; super.init(command: command) }
}
open class MPChangeShuffleModeCommandEvent: MPRemoteCommandEvent {
    public let shuffleType: MPShuffleType
    public let preservesShuffleMode: Bool
    init(command: MPRemoteCommand, shuffleType: MPShuffleType) { self.shuffleType = shuffleType; preservesShuffleMode = false; super.init(command: command) }
}
open class MPRatingCommandEvent: MPRemoteCommandEvent {
    public let rating: Float
    init(command: MPRemoteCommand, rating: Float) { self.rating = rating; super.init(command: command) }
}
public enum MPChangeLanguageOptionSetting: Int, Sendable { case none = 0, nowPlayingItemOnly, permanent }
open class MPChangeLanguageOptionCommandEvent: MPRemoteCommandEvent {
    public let languageOption: MPNowPlayingInfoLanguageOption
    public let setting: MPChangeLanguageOptionSetting
    init(command: MPRemoteCommand, option: MPNowPlayingInfoLanguageOption) { languageOption = option; setting = .nowPlayingItemOnly; super.init(command: command) }
}

// MARK: - language options

public enum MPNowPlayingInfoLanguageOptionType: UInt, Sendable { case audible = 0, legible }
public let MPLanguageOptionCharacteristicIsMainProgramContent = "public.main-program-content"
public let MPLanguageOptionCharacteristicIsAuxiliaryContent = "public.auxiliary-content"
public let MPLanguageOptionCharacteristicContainsOnlyForcedSubtitles = "public.subtitles.forced-only"
public let MPLanguageOptionCharacteristicTranscribesSpokenDialog = "public.accessibility.transcribes-spoken-dialog"
public let MPLanguageOptionCharacteristicDescribesMusicAndSound = "public.accessibility.describes-music-and-sound"
public let MPLanguageOptionCharacteristicEasyToRead = "public.easy-to-read"
public let MPLanguageOptionCharacteristicDescribesVideo = "public.accessibility.describes-video"
public let MPLanguageOptionCharacteristicLanguageTranslation = "public.translation"
public let MPLanguageOptionCharacteristicDubbedTranslation = "public.translation.dubbed"
public let MPLanguageOptionCharacteristicVoiceOverTranslation = "public.translation.voice-over"

/// an audio track or subtitles the app offers (MPNowPlayingInfoPropertyAvailableLanguageOptions)
open class MPNowPlayingInfoLanguageOption: NSObject {
    public let languageOptionType: MPNowPlayingInfoLanguageOptionType
    public let languageTag: String?
    public let languageOptionCharacteristics: [String]?
    public let displayName: String?
    public let identifier: String?
    public init(type languageOptionType: MPNowPlayingInfoLanguageOptionType, languageTag: String, characteristics languageOptionCharacteristics: [String]?,
                displayName: String, identifier: String) {
        self.languageOptionType = languageOptionType; self.languageTag = languageTag; self.languageOptionCharacteristics = languageOptionCharacteristics
        self.displayName = displayName; self.identifier = identifier
    }
    /// the system's "Auto" subtitles choice
    open var isAutomaticLegibleLanguageOption: Bool { languageOptionType == .legible && identifier == "isim.automatic" }
    open var isAutomaticAudibleLanguageOption: Bool { languageOptionType == .audible && identifier == "isim.automatic" }
}
open class MPNowPlayingInfoLanguageOptionGroup: NSObject {
    public let languageOptions: [MPNowPlayingInfoLanguageOption]
    public let defaultLanguageOption: MPNowPlayingInfoLanguageOption?
    public let allowEmptySelection: Bool
    public init(languageOptions: [MPNowPlayingInfoLanguageOption], defaultLanguageOption: MPNowPlayingInfoLanguageOption?, allowEmptySelection: Bool) {
        self.languageOptions = languageOptions; self.defaultLanguageOption = defaultLanguageOption; self.allowEmptySelection = allowEmptySelection
    }
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
open class MPChangeRepeatModeCommand: MPRemoteCommand { open var currentRepeatType: MPRepeatType = .off }
open class MPChangeShuffleModeCommand: MPRemoteCommand { open var currentShuffleType: MPShuffleType = .off }
open class MPRatingCommand: MPRemoteCommand {
    open var minimumRating: Float = 0
    open var maximumRating: Float = 5
}

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
    public let enableLanguageOptionCommand = MPRemoteCommand(name: "language")
    public let disableLanguageOptionCommand = MPRemoteCommand(name: "nolanguage")
    public let ratingCommand = MPRatingCommand(name: "rating")
    var timer: Timer?
    /// the session's info center, for the language options a command names (MPNowPlayingSession)
    weak var _infoCenter: MPNowPlayingInfoCenter?
    public override init() { super.init() }

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
            // an active Now Playing session takes the commands, as on iOS
            (MPNowPlayingSession._active?.remoteCommandCenter ?? self)._deliver(line)
        }
    }
    func _deliver(_ line: String) {
        do {
            let parts = line.split(separator: " ").map(String.init)
            guard let name = parts.first?.lowercased() else { return }
            let arg = parts.count > 1 ? Double(parts[1]) : nil
            let all: [MPRemoteCommand] = [playCommand, pauseCommand, stopCommand, togglePlayPauseCommand, nextTrackCommand, previousTrackCommand,
                                          skipForwardCommand, skipBackwardCommand, seekForwardCommand, seekBackwardCommand, changePlaybackPositionCommand,
                                          changePlaybackRateCommand, changeRepeatModeCommand, changeShuffleModeCommand, likeCommand, dislikeCommand,
                                          bookmarkCommand, ratingCommand, enableLanguageOptionCommand, disableLanguageOptionCommand]
            guard let cmd = all.first(where: { $0.name == name }) else { NSLog("isim MediaPlayer: unknown remote command '%@'", line); return }
            let word = parts.count > 1 ? parts[1].lowercased() : ""
            let event: MPRemoteCommandEvent
            switch cmd {
            case let c as MPChangeRepeatModeCommand:
                event = MPChangeRepeatModeCommandEvent(command: c, repeatType: word == "one" ? .one : word == "all" ? .all : .off)
            case let c as MPChangeShuffleModeCommand:
                event = MPChangeShuffleModeCommandEvent(command: c, shuffleType: word == "items" ? .items : word == "collections" ? .collections : .off)
            case let c as MPRatingCommand:
                event = MPRatingCommandEvent(command: c, rating: max(c.minimumRating, min(c.maximumRating, Float(arg ?? 0))))
            case _ where cmd === enableLanguageOptionCommand || cmd === disableLanguageOptionCommand:
                // the option the app offered with that identifier (or display name)
                let id = parts.count > 1 ? parts[1] : ""
                let info = (_infoCenter ?? MPNowPlayingInfoCenter.shared).nowPlayingInfo
                let groups = info?[MPNowPlayingInfoPropertyAvailableLanguageOptions] as? [MPNowPlayingInfoLanguageOptionGroup] ?? []
                guard let option = groups.flatMap(\.languageOptions).first(where: { $0.identifier == id || $0.displayName == id }) else {
                    NSLog("isim MediaPlayer: no language option '%@' in the Now Playing info", id); return
                }
                event = MPChangeLanguageOptionCommandEvent(command: cmd, option: option)
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

// MARK: - Now Playing sessions (iOS 16)

public protocol MPNowPlayingSessionDelegate: NSObjectProtocol {
    func nowPlayingSessionDidChangeActive(_ nowPlayingSession: MPNowPlayingSession)
    func nowPlayingSessionDidChangeCanBecomeActive(_ nowPlayingSession: MPNowPlayingSession)
}
extension MPNowPlayingSessionDelegate {
    public func nowPlayingSessionDidChangeActive(_ nowPlayingSession: MPNowPlayingSession) {}
    public func nowPlayingSessionDidChangeCanBecomeActive(_ nowPlayingSession: MPNowPlayingSession) {}
}

/// An app's Now Playing for some players: its own info center and command center. The active session is what the
/// system shows and sends commands to; with automaticallyPublishesNowPlayingInfo its info follows the first player.
open class MPNowPlayingSession: NSObject {
    nonisolated(unsafe) static weak var _active: MPNowPlayingSession?
    public private(set) var players: [AVPlayer]
    public let nowPlayingInfoCenter = MPNowPlayingInfoCenter()
    public let remoteCommandCenter = MPRemoteCommandCenter()
    open weak var delegate: MPNowPlayingSessionDelegate?
    open var automaticallyPublishesNowPlayingInfo = false { didSet { if automaticallyPublishesNowPlayingInfo { _publish() } } }
    var timer: Timer?
    public init(players: [AVPlayer]) {
        self.players = players
        super.init()
        remoteCommandCenter._infoCenter = nowPlayingInfoCenter
        timer = Timer._isimScheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?._publish() }
    }
    deinit { timer?.invalidate() }
    open var isActive: Bool { Self._active === self }
    /// a session can become active while it has a player
    open var canBecomeActive: Bool { !players.isEmpty }
    open func becomeActiveIfPossible(completion: ((Bool) -> Void)? = nil) {
        let ok = canBecomeActive
        if ok && !isActive {
            let old = Self._active
            Self._active = self
            remoteCommandCenter._startPolling()
            NSLog("isim MediaPlayer: Now Playing session active")
            old?.delegate?.nowPlayingSessionDidChangeActive(old!)
            delegate?.nowPlayingSessionDidChangeActive(self)
            _publish(force: true)
        }
        DispatchQueue.main.async { completion?(ok) }
    }
    open func becomeActiveIfPossible() async -> Bool { await withCheckedContinuation { k in becomeActiveIfPossible { k.resume(returning: $0) } } }
    open func addPlayer(_ player: AVPlayer) {
        let could = canBecomeActive
        players.append(player)
        if could != canBecomeActive { delegate?.nowPlayingSessionDidChangeCanBecomeActive(self) }
    }
    open func removePlayer(_ player: AVPlayer) {
        let could = canBecomeActive
        players.removeAll { $0 === player }
        if could != canBecomeActive { delegate?.nowPlayingSessionDidChangeCanBecomeActive(self) }
    }
    /// the first player's item: duration, elapsed time and rate (the app's own keys kept)
    var lastPublished = ""
    func _publish(force: Bool = false) {
        guard automaticallyPublishesNowPlayingInfo, let p = players.first, let item = p.currentItem else {
            if force && isActive { MPNowPlayingInfoCenter.shared.nowPlayingInfo = nowPlayingInfoCenter.nowPlayingInfo }
            return
        }
        var info = nowPlayingInfoCenter.nowPlayingInfo ?? [:]
        let d = item.duration.seconds, t = p.currentTime().seconds
        if d.isFinite { info[MPMediaItemPropertyPlaybackDuration] = NSNumber(value: d) }
        if t.isFinite { info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = NSNumber(value: t) }
        info[MPNowPlayingInfoPropertyPlaybackRate] = NSNumber(value: p.rate)
        info[MPNowPlayingInfoPropertyMediaType] = NSNumber(value: MPNowPlayingInfoMediaType.audio.rawValue)
        let key = String(format: "%.0f %.0f %.1f", d.isFinite ? d : 0, t.isFinite ? t : 0, p.rate)
        guard force || key != lastPublished else { return }
        lastPublished = key
        nowPlayingInfoCenter.nowPlayingInfo = info
        nowPlayingInfoCenter.playbackState = p.rate > 0 ? .playing : .paused
        // the active session is what the system shows
        if isActive { MPNowPlayingInfoCenter.shared.nowPlayingInfo = info; MPNowPlayingInfoCenter.shared.playbackState = nowPlayingInfoCenter.playbackState }
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
