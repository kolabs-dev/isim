// AVFoundation's coordinated playback (issue #392): AVPlaybackCoordinator, AVPlayerPlaybackCoordinator (an AVPlayer's
// rate and time kept in step with other participants'), AVDelegatingPlaybackCoordinator (the app plays; the coordinator
// issues play, pause and seek commands to its delegate), suspensions, participants and AVPlaybackCoordinationMedium
// (coordinators connected in one process). Adapted: a coordinator talks through a transport, a GroupSession
// (GroupActivities' coordinateWithSession) or a medium. Each change is a state (rate, item time, the wall-clock time it
// held, the item's identifier) that the other coordinators apply, extrapolated to now.
import Foundation
import CoreMedia

/// isim: how a playback coordinator reaches the others (a group session, or a coordination medium)
public protocol _AVCoordinationTransport: AnyObject {
    /// sends a state to the other participants
    func _send(_ state: [String: Any], from coordinator: AVPlaybackCoordinator)
    /// the other participants
    var _otherParticipants: [UUID] { get }
}

extension AVCoordinatedPlaybackSuspension {
    public struct Reason: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public init(_ rawValue: String) { self.rawValue = rawValue }
        public static let audioSessionInterrupted = Reason("AVCoordinatedPlaybackSuspensionReasonAudioSessionInterrupted")
        public static let stallRecovery = Reason("AVCoordinatedPlaybackSuspensionReasonStallRecovery")
        public static let playingInterstitial = Reason("AVCoordinatedPlaybackSuspensionReasonPlayingInterstitial")
        public static let coordinatedPlaybackNotPossible = Reason("AVCoordinatedPlaybackSuspensionReasonCoordinatedPlaybackNotPossible")
        public static let userActionRequired = Reason("AVCoordinatedPlaybackSuspensionReasonUserActionRequired")
        public static let userIsChangingCurrentTime = Reason("AVCoordinatedPlaybackSuspensionReasonUserIsChangingCurrentTime")
    }
}

extension AVPlayer.WaitingReason {
    public static let waitingForCoordinatedPlayback = AVPlayer.WaitingReason(rawValue: "AVPlayerWaitingForCoordinatedPlaybackReason")
}

/// A break in coordination: while it lasts, the coordinator neither follows nor leads the group.
@objc(AVCoordinatedPlaybackSuspension) open class AVCoordinatedPlaybackSuspension: NSObject, @unchecked Sendable {
    public let reason: Reason
    @objc public let beginDate = Date()
    weak var _coordinator: AVPlaybackCoordinator?
    var _ended = false
    init(_ reason: Reason, _ c: AVPlaybackCoordinator) { self.reason = reason; _coordinator = c }
    /// rejoins the group's playback
    @objc open func end() { _end(nil) }
    /// rejoins and moves everyone to `time`
    open func end(proposingNewTime time: CMTime) { _end(time) }
    func _end(_ time: CMTime?) {
        guard !_ended else { return }
        _ended = true
        _coordinator?._suspensionEnded(self, proposing: time)
    }
}

/// Another participant in coordinated playback.
@objc(AVCoordinatedPlaybackParticipant) open class AVCoordinatedPlaybackParticipant: NSObject, @unchecked Sendable {
    @objc public let identifier: UUID
    open internal(set) var suspensionReasons: [AVCoordinatedPlaybackSuspension.Reason] = []
    @objc open internal(set) var isReadyToPlay = true
    init(_ id: UUID) { identifier = id }
    open override func isEqual(_ object: Any?) -> Bool { (object as? AVCoordinatedPlaybackParticipant)?.identifier == identifier }
    open override var hash: Int { identifier.hashValue }
}

/// Keeps playback in step with other participants.
@objc(AVPlaybackCoordinator) open class AVPlaybackCoordinator: NSObject, @unchecked Sendable {
    public static let otherParticipantsDidChangeNotification = Notification.Name("AVPlaybackCoordinatorOtherParticipantsDidChangeNotification")
    public static let suspensionReasonsDidChangeNotification = Notification.Name("AVPlaybackCoordinatorSuspensionReasonsDidChangeNotification")
    /// isim: the transport (set by coordinateWithSession or a medium)
    public weak var _transport: _AVCoordinationTransport? { didSet { _participantsChanged() } }
    /// isim: this participant's identifier
    public var _localID = UUID()
    var _suspensions: [AVCoordinatedPlaybackSuspension] = []
    var _participants: [UUID: AVCoordinatedPlaybackParticipant] = [:]
    var _limits: [AVCoordinatedPlaybackSuspension.Reason: Int] = [:]

    override init() { super.init() }
    @objc open var otherParticipants: [AVCoordinatedPlaybackParticipant] {
        (_transport?._otherParticipants ?? []).filter { $0 != _localID }.map { id in _participants[id] ?? { let p = AVCoordinatedPlaybackParticipant(id); _participants[id] = p; return p }() }
    }
    open var suspensionReasons: [AVCoordinatedPlaybackSuspension.Reason] { _suspensions.map(\.reason) }
    open var suspensionReasonsThatTriggerWaiting: [AVCoordinatedPlaybackSuspension.Reason] = [.stallRecovery]
    @objc open var pauseSnapsToMediaTimeOfOriginator = true
    open func participantLimitForWaitingOutSuspensions(withReason reason: AVCoordinatedPlaybackSuspension.Reason) -> Int { _limits[reason] ?? .max }
    open func setParticipantLimit(_ participantLimit: Int, forWaitingOutSuspensionsWithReason reason: AVCoordinatedPlaybackSuspension.Reason) {
        _limits[reason] = participantLimit
    }
    /// pauses coordination: the group's changes are not applied here, this participant's are not sent
    open func beginSuspension(for suspensionReason: AVCoordinatedPlaybackSuspension.Reason) -> AVCoordinatedPlaybackSuspension {
        let s = AVCoordinatedPlaybackSuspension(suspensionReason, self)
        _suspensions.append(s)
        NotificationCenter.default.post(name: Self.suspensionReasonsDidChangeNotification, object: self)
        return s
    }
    /// the item time the group expects at a host time (seconds of the host clock)
    open func expectedItemTime(atHostTime hostClockTime: CMTime) -> CMTime {
        let now = ProcessInfo.processInfo.systemUptime
        let t = _state.time + (hostClockTime.isNumeric ? hostClockTime.seconds - now : 0) * Double(_state.rate) + (Date().timeIntervalSince1970 - _state.wall) * Double(_state.rate)
        return CMTime(seconds: max(0, t), preferredTimescale: 600)
    }

    // MARK: the shared state

    struct _State { var rate: Float = 0; var time: Double = 0; var wall: Double = Date().timeIntervalSince1970; var item: String? }
    var _state = _State()
    var _suspended: Bool { !_suspensions.isEmpty }

    /// sends this participant's change to the others
    func _broadcast(rate: Float, time: Double, item: String?) {
        _state = _State(rate: rate, time: time, wall: Date().timeIntervalSince1970, item: item)
        guard !_suspended else { return }
        var s: [String: Any] = ["rate": Double(rate), "time": time, "wall": _state.wall, "from": _localID.uuidString]
        if let item { s["item"] = item }
        _transport?._send(s, from: self)
    }
    /// isim: a state from another participant
    public func _receive(_ s: [String: Any]) {
        guard let r = s["rate"] as? Double, let t = s["time"] as? Double, let w = s["wall"] as? Double else { return }
        let from = (s["from"] as? String).flatMap(UUID.init(uuidString:))
        guard from != _localID else { return }
        _state = _State(rate: Float(r), time: t, wall: w, item: s["item"] as? String)
        guard !_suspended else { return }
        let now = r > 0 ? t + (Date().timeIntervalSince1970 - w) * r : t
        _apply(rate: Float(r), time: now, item: s["item"] as? String, originator: from.map { AVCoordinatedPlaybackParticipant($0) })
    }
    func _apply(rate: Float, time: Double, item: String?, originator: AVCoordinatedPlaybackParticipant?) {}
    func _currentState() -> (rate: Float, time: Double, item: String?) { (_state.rate, _state.time, _state.item) }
    func _suspensionEnded(_ s: AVCoordinatedPlaybackSuspension, proposing time: CMTime?) {
        _suspensions.removeAll { $0 === s }
        NotificationCenter.default.post(name: Self.suspensionReasonsDidChangeNotification, object: self)
        guard !_suspended else { return }
        if let time, time.isNumeric {
            let c = _currentState()
            _apply(rate: c.rate, time: time.seconds, item: c.item, originator: nil)
            _broadcast(rate: c.rate, time: time.seconds, item: c.item)
        } else {
            // catch up with the group
            let now = _state.rate > 0 ? _state.time + (Date().timeIntervalSince1970 - _state.wall) * Double(_state.rate) : _state.time
            _apply(rate: _state.rate, time: now, item: _state.item, originator: nil)
        }
    }
    /// isim: the transport's participants changed
    public func _participantsChanged() {
        NotificationCenter.default.post(name: Self.otherParticipantsDidChangeNotification, object: self)
    }
    /// isim: a new participant joined: it is sent the current state
    public func _sendCurrentState() {
        let c = _currentState()
        guard !_suspended else { return }
        _broadcast(rate: c.rate, time: c.time, item: c.item)
    }
}

@objc public protocol AVPlayerPlaybackCoordinatorDelegate: NSObjectProtocol {
    /// the identifier the participants know the item by (default: its asset's URL)
    @objc(playbackCoordinator:identifierForPlayerItem:)
    optional func playbackCoordinator(_ coordinator: AVPlayerPlaybackCoordinator, identifierFor playerItem: AVPlayerItem) -> String
    @objc(playbackCoordinator:interstitialTimeRangesForPlayerItem:)
    optional func playbackCoordinator(_ coordinator: AVPlayerPlaybackCoordinator, interstitialTimeRangesFor playerItem: AVPlayerItem) -> [NSValue]
}

/// An AVPlayer's coordinator: its rate changes and seeks go to the group; the group's are applied to the player.
@objc(AVPlayerPlaybackCoordinator) open class AVPlayerPlaybackCoordinator: AVPlaybackCoordinator, @unchecked Sendable {
    @objc open private(set) weak var player: AVPlayer?
    @objc open weak var delegate: (any AVPlayerPlaybackCoordinatorDelegate)?
    var _applying = false
    init(_player p: AVPlayer) { player = p; super.init() }
    @objc open private(set) var playbackCoordinationMedium: AVPlaybackCoordinationMedium?
    /// connects to a medium (nil: disconnects)
    @objc(coordinateUsingPlaybackCoordinationMedium:error:)
    open func coordinate(using medium: AVPlaybackCoordinationMedium?) throws {
        playbackCoordinationMedium?._remove(self)
        playbackCoordinationMedium = medium
        medium?._add(self)
        _transport = medium
    }
    func _itemID() -> String? {
        guard let item = player?.currentItem else { return nil }
        return delegate?.playbackCoordinator?(self, identifierFor: item) ?? (item.asset as? AVURLAsset)?.url.absoluteString
    }
    override func _currentState() -> (rate: Float, time: Double, item: String?) {
        guard let p = player else { return super._currentState() }
        return (p.rate, p.currentTime().seconds, _itemID())
    }
    /// the player changed by the app
    func _playerChanged() {
        guard !_applying, let p = player, _transport != nil else { return }
        _broadcast(rate: p.rate, time: p.currentTime().seconds, item: _itemID())
    }
    override func _apply(rate: Float, time: Double, item: String?, originator: AVCoordinatedPlaybackParticipant?) {
        guard let p = player else { return }
        if let item, let mine = _itemID(), item != mine { return }        // another item: not coordinated
        _applying = true
        defer { _applying = false }
        if rate > 0 || pauseSnapsToMediaTimeOfOriginator { p.seek(to: CMTime(seconds: time, preferredTimescale: 600)) }
        p.rate = rate
    }
}

/// Coordinated playback for an app's own player: commands go to the playback control delegate.
@objc public protocol AVPlaybackCoordinatorPlaybackControlDelegate: NSObjectProtocol {
    @objc(playbackCoordinator:didIssuePlayCommand:completionHandler:)
    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue playCommand: AVDelegatingPlaybackCoordinatorPlayCommand, completionHandler: @escaping () -> Void)
    @objc(playbackCoordinator:didIssuePauseCommand:completionHandler:)
    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue pauseCommand: AVDelegatingPlaybackCoordinatorPauseCommand, completionHandler: @escaping () -> Void)
    @objc(playbackCoordinator:didIssueSeekCommand:completionHandler:)
    func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue seekCommand: AVDelegatingPlaybackCoordinatorSeekCommand, completionHandler: @escaping () -> Void)
    @objc(playbackCoordinator:didIssueBufferingCommand:completionHandler:)
    optional func playbackCoordinator(_ coordinator: AVDelegatingPlaybackCoordinator, didIssue bufferingCommand: AVDelegatingPlaybackCoordinatorBufferingCommand, completionHandler: @escaping () -> Void)
}

public struct AVDelegatingPlaybackCoordinatorRateChangeOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let playImmediately = AVDelegatingPlaybackCoordinatorRateChangeOptions(rawValue: 1 << 0)
}
public struct AVDelegatingPlaybackCoordinatorSeekOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let resumeImmediately = AVDelegatingPlaybackCoordinatorSeekOptions(rawValue: 1 << 0)
}

@objc(AVDelegatingPlaybackCoordinatorPlaybackControlCommand) open class AVDelegatingPlaybackCoordinatorPlaybackControlCommand: NSObject, @unchecked Sendable {
    @objc public let originator: AVCoordinatedPlaybackParticipant?
    @objc public let expectedCurrentItemIdentifier: String
    init(_ originator: AVCoordinatedPlaybackParticipant?, _ item: String) { self.originator = originator; expectedCurrentItemIdentifier = item }
}
@objc(AVDelegatingPlaybackCoordinatorPlayCommand) open class AVDelegatingPlaybackCoordinatorPlayCommand: AVDelegatingPlaybackCoordinatorPlaybackControlCommand, @unchecked Sendable {
    @objc public let rate: Float
    public let itemTime: CMTime
    public let hostClockTime: CMTime
    init(_ o: AVCoordinatedPlaybackParticipant?, _ item: String, rate: Float, time: Double) {
        self.rate = rate; itemTime = CMTime(seconds: time, preferredTimescale: 600)
        hostClockTime = CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 1_000_000_000)
        super.init(o, item)
    }
}
@objc(AVDelegatingPlaybackCoordinatorPauseCommand) open class AVDelegatingPlaybackCoordinatorPauseCommand: AVDelegatingPlaybackCoordinatorPlaybackControlCommand, @unchecked Sendable {
    @objc public let shouldBufferInAnticipationOfPlayback: Bool
    @objc public let anticipatedPlaybackRate: Float
    override init(_ o: AVCoordinatedPlaybackParticipant?, _ item: String) { shouldBufferInAnticipationOfPlayback = false; anticipatedPlaybackRate = 0; super.init(o, item) }
}
@objc(AVDelegatingPlaybackCoordinatorSeekCommand) open class AVDelegatingPlaybackCoordinatorSeekCommand: AVDelegatingPlaybackCoordinatorPlaybackControlCommand, @unchecked Sendable {
    public let itemTime: CMTime
    @objc public let shouldBufferInAnticipationOfPlayback: Bool
    @objc public let anticipatedPlaybackRate: Float
    @objc public let completionDueDate: Date?
    init(_ o: AVCoordinatedPlaybackParticipant?, _ item: String, time: Double, rate: Float) {
        itemTime = CMTime(seconds: time, preferredTimescale: 600)
        shouldBufferInAnticipationOfPlayback = rate > 0; anticipatedPlaybackRate = rate; completionDueDate = nil
        super.init(o, item)
    }
}
@objc(AVDelegatingPlaybackCoordinatorBufferingCommand) open class AVDelegatingPlaybackCoordinatorBufferingCommand: AVDelegatingPlaybackCoordinatorPlaybackControlCommand, @unchecked Sendable {
    @objc public let anticipatedPlaybackRate: Float
    @objc public let completionDueDate: Date?
    init(_ o: AVCoordinatedPlaybackParticipant?, _ item: String, rate: Float) { anticipatedPlaybackRate = rate; completionDueDate = nil; super.init(o, item) }
}

/// The app plays; the coordinator tells it what the group does, through commands to its delegate.
@objc(AVDelegatingPlaybackCoordinator) open class AVDelegatingPlaybackCoordinator: AVPlaybackCoordinator, @unchecked Sendable {
    @objc open private(set) weak var playbackControlDelegate: (any AVPlaybackCoordinatorPlaybackControlDelegate)?
    @objc open private(set) var currentItemIdentifier: String?
    @objc public init(playbackControlDelegate: any AVPlaybackCoordinatorPlaybackControlDelegate) {
        self.playbackControlDelegate = playbackControlDelegate
        super.init()
    }
    var _now: Double { _state.rate > 0 ? _state.time + (Date().timeIntervalSince1970 - _state.wall) * Double(_state.rate) : _state.time }
    /// the group plays (or pauses) at `rate` from the current time; the local delegate is told too
    open func coordinateRateChange(to rate: Float, options: AVDelegatingPlaybackCoordinatorRateChangeOptions = []) {
        let t = _now
        _apply(rate: rate, time: t, item: currentItemIdentifier, originator: nil)
        _broadcast(rate: rate, time: t, item: currentItemIdentifier)
    }
    open func coordinateSeek(to time: CMTime, options: AVDelegatingPlaybackCoordinatorSeekOptions = []) {
        let rate = options.contains(.resumeImmediately) ? max(_state.rate, 1) : _state.rate
        let t = time.isNumeric ? time.seconds : 0
        _seek(t, rate: rate, originator: nil)
        _broadcast(rate: rate, time: t, item: currentItemIdentifier)
    }
    /// moves to another item (nil: none); its timing starts at zero unless a timebase proposes one
    open func transitionToItem(withIdentifier itemIdentifier: String?, proposingInitialTimingBasedOn snapshotTimebase: CMTimebase?) {
        _transition(itemIdentifier, snapshotTimebase.map { CMTimebaseGetTime($0).seconds } ?? 0, snapshotTimebase.map { Float(CMTimebaseGetRate($0)) } ?? 0)
    }
    func _transition(_ itemIdentifier: String?, _ t: Double, _ r: Float) {
        currentItemIdentifier = itemIdentifier
        _state = _State(rate: r, time: t, wall: Date().timeIntervalSince1970, item: itemIdentifier)
        _broadcast(rate: r, time: t, item: itemIdentifier)
    }
    /// issues the current state to the delegate again
    @objc open func reapplyCurrentItemStateToPlaybackControlDelegate() {
        _apply(rate: _state.rate, time: _now, item: currentItemIdentifier, originator: nil)
    }
    func _seek(_ t: Double, rate: Float, originator: AVCoordinatedPlaybackParticipant?) {
        _state.time = t; _state.wall = Date().timeIntervalSince1970; _state.rate = rate
        playbackControlDelegate?.playbackCoordinator(self, didIssue: AVDelegatingPlaybackCoordinatorSeekCommand(originator, currentItemIdentifier ?? "", time: t, rate: rate)) {}
        if rate > 0 { _issuePlay(rate, t, originator) }
    }
    func _issuePlay(_ rate: Float, _ t: Double, _ o: AVCoordinatedPlaybackParticipant?) {
        playbackControlDelegate?.playbackCoordinator(self, didIssue: AVDelegatingPlaybackCoordinatorPlayCommand(o, currentItemIdentifier ?? "", rate: rate, time: t)) {}
    }
    override func _apply(rate: Float, time: Double, item: String?, originator: AVCoordinatedPlaybackParticipant?) {
        if let item, item != currentItemIdentifier { currentItemIdentifier = item }
        let moved = abs(time - _now) > 0.25
        _state = _State(rate: rate, time: time, wall: Date().timeIntervalSince1970, item: item ?? currentItemIdentifier)
        if moved && rate == 0 {
            playbackControlDelegate?.playbackCoordinator(self, didIssue: AVDelegatingPlaybackCoordinatorSeekCommand(originator, currentItemIdentifier ?? "", time: time, rate: 0)) {}
        }
        if rate > 0 { _issuePlay(rate, time, originator) }
        else { playbackControlDelegate?.playbackCoordinator(self, didIssue: AVDelegatingPlaybackCoordinatorPauseCommand(originator, currentItemIdentifier ?? "")) {} }
    }
}

/// Coordinators connected in this process (iOS 26): each follows the others.
@objc(AVPlaybackCoordinationMedium) open class AVPlaybackCoordinationMedium: NSObject, _AVCoordinationTransport, @unchecked Sendable {
    var _members: [AVPlayerPlaybackCoordinator] = []
    @objc public override init() { super.init() }
    @objc open var connectedPlaybackCoordinators: [AVPlayerPlaybackCoordinator] { _members }
    func _add(_ c: AVPlayerPlaybackCoordinator) {
        _members.append(c)
        for m in _members { m._participantsChanged() }
    }
    func _remove(_ c: AVPlayerPlaybackCoordinator) {
        _members.removeAll { $0 === c }
        for m in _members { m._participantsChanged() }
    }
    public func _send(_ state: [String: Any], from coordinator: AVPlaybackCoordinator) {
        for m in _members where m !== coordinator { DispatchQueue.main.async { m._receive(state) } }
    }
    public var _otherParticipants: [UUID] { _members.map(\._localID) }
}

extension AVPlayer {
    /// the player's coordinator (made on first use)
    @objc open var playbackCoordinator: AVPlayerPlaybackCoordinator {
        if let c = objc_getAssociatedObject(self, &_avCoordinatorKey) as? AVPlayerPlaybackCoordinator { return c }
        let c = AVPlayerPlaybackCoordinator(_player: self)
        objc_setAssociatedObject(self, &_avCoordinatorKey, c, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return c
    }
    /// the player's rate or time changed: its coordinator (if any) tells the group
    func _coordinatedChange() {
        (objc_getAssociatedObject(self, &_avCoordinatorKey) as? AVPlayerPlaybackCoordinator)?._playerChanged()
    }
}
nonisolated(unsafe) private var _avCoordinatorKey = 0

// MARK: - Objective-C (AVFoundation.h): the members whose Swift types Objective-C cannot see (reason strings, option
// sets, CMTime as its four fields for the categories in frameworks/AVFoundation/AVFoundation.m)

extension CMTime {
    init(_isimParts v: Int64, _ ts: Int32, _ f: UInt32, _ e: Int64) { self.init(value: v, timescale: ts, flags: CMTimeFlags(rawValue: f), epoch: e) }
}
extension AVCoordinatedPlaybackSuspension {
    @objc(reason) public var _isimReason: String { reason.rawValue }
    @objc(_isim_endProposingNewTimeValue:timescale:flags:epoch:)
    public func _isimEnd(_ v: Int64, _ ts: Int32, _ f: UInt32, _ e: Int64) { end(proposingNewTime: CMTime(_isimParts: v, ts, f, e)) }
}
extension AVCoordinatedPlaybackParticipant {
    @objc(suspensionReasons) public var _isimSuspensionReasons: [String] { suspensionReasons.map(\.rawValue) }
}
extension AVPlaybackCoordinator {
    @objc(suspensionReasons) public var _isimSuspensionReasons: [String] { suspensionReasons.map(\.rawValue) }
    @objc(suspensionReasonsThatTriggerWaiting) public var _isimSuspensionReasonsThatTriggerWaiting: [String] {
        get { suspensionReasonsThatTriggerWaiting.map(\.rawValue) }
        set { suspensionReasonsThatTriggerWaiting = newValue.map(AVCoordinatedPlaybackSuspension.Reason.init(rawValue:)) }
    }
    @objc(participantLimitForWaitingOutSuspensionsWithReason:)
    public func _isimParticipantLimit(_ reason: String) -> Int { participantLimitForWaitingOutSuspensions(withReason: .init(rawValue: reason)) }
    @objc(setParticipantLimit:forWaitingOutSuspensionsWithReason:)
    public func _isimSetParticipantLimit(_ limit: Int, _ reason: String) { setParticipantLimit(limit, forWaitingOutSuspensionsWithReason: .init(rawValue: reason)) }
    @objc(beginSuspensionForReason:)
    public func _isimBeginSuspension(_ reason: String) -> AVCoordinatedPlaybackSuspension { beginSuspension(for: .init(rawValue: reason)) }
    @objc(_isim_expectedItemTimeAtHostTimeValue:timescale:flags:epoch:)
    public func _isimExpectedItemTime(_ v: Int64, _ ts: Int32, _ f: UInt32, _ e: Int64) -> [NSNumber] {
        expectedItemTime(atHostTime: CMTime(_isimParts: v, ts, f, e))._isimParts
    }
}
extension AVDelegatingPlaybackCoordinatorPlayCommand {
    @objc(_isim_itemTime) public var _isimItemTime: [NSNumber] { itemTime._isimParts }
    @objc(_isim_hostClockTime) public var _isimHostClockTime: [NSNumber] { hostClockTime._isimParts }
}
extension AVDelegatingPlaybackCoordinatorSeekCommand {
    @objc(_isim_itemTime) public var _isimItemTime: [NSNumber] { itemTime._isimParts }
}
extension AVDelegatingPlaybackCoordinator {
    @objc(coordinateRateChangeToRate:options:)
    public func _isimCoordinateRateChange(_ rate: Float, _ options: UInt) { coordinateRateChange(to: rate, options: .init(rawValue: options)) }
    @objc(_isim_coordinateSeekToTimeValue:timescale:flags:epoch:options:)
    public func _isimCoordinateSeek(_ v: Int64, _ ts: Int32, _ f: UInt32, _ e: Int64, _ options: UInt) {
        coordinateSeek(to: CMTime(_isimParts: v, ts, f, e), options: .init(rawValue: options))
    }
    /// the Objective-C method: a CMTimebaseRef is the overlay's CMTimebase object (C cannot make one yet)
    @objc(_isim_transitionToItemWithIdentifier:timebase:)
    public func _isimTransition(_ itemIdentifier: String?, _ timebase: UnsafeRawPointer?) {
        transitionToItem(withIdentifier: itemIdentifier, proposingInitialTimingBasedOn: timebase.map { Unmanaged<CMTimebase>.fromOpaque($0).takeUnretainedValue() })
    }
}
