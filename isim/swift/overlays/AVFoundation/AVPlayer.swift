// isim AVFoundation: video/audio playback — AVPlayerItem, AVPlayer, AVQueuePlayer, AVPlayerLooper, AVPlayerLayer,
// periodic/boundary time observers, AVPlayerItemDidPlayToEndTime, key-value observing of status/rate/
// timeControlStatus, readyForDisplay (Foundation KVO: the observable properties are @objc and these classes post
// will/didChangeValue(forKey:) themselves — automaticallyNotifiesObservers(forKey:) is false).
// Decoding runs in the host's ffmpeg (host_media.c): frames stream into an image that AVPlayerLayer draws, the
// soundtrack streams into the audio mixer. The clock is the host's monotonic clock; only rate 1 plays sound
// (other positive rates play video only); reverse playback is not supported.
import UIKit
import isim_host

// MARK: - AVPlayerItem

open class AVPlayerItem: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, readyToPlay, failed }
    public let asset: AVAsset
    public let automaticallyLoadedAssetKeys: [String]
    @objc open private(set) var status: Status = .unknown
    open private(set) var error: Error?
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { false }
    open var forwardPlaybackEndTime: CMTime = .invalid
    open var reversePlaybackEndTime: CMTime = .invalid
    open var preferredForwardBufferDuration: TimeInterval = 0
    open var preferredPeakBitRate: Double = 0
    open var canUseNetworkResourcesForLiveStreamingWhilePaused = false
    open var audioTimePitchAlgorithm: String?
    /// playback position while this item is not playing (seconds)
    var _position: Double = 0
    weak var _player: AVPlayer?
    var _info: _AVMediaInfo?

    public init(asset: AVAsset, automaticallyLoadedAssetKeys: [String]? = nil) {
        self.asset = asset
        self.automaticallyLoadedAssetKeys = automaticallyLoadedAssetKeys ?? []
        super.init()
        _load()
    }
    public convenience init(asset: AVAsset) { self.init(asset: asset, automaticallyLoadedAssetKeys: nil) }
    public convenience init(url URL: URL) { self.init(asset: AVURLAsset(url: URL), automaticallyLoadedAssetKeys: nil) }

    /// Probes the asset off the main thread, then becomes ready (or fails) on the main queue, like iOS.
    func _load() {
        let asset = self.asset
        DispatchQueue.global().async {
            let info = asset._media
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self._info = info
                self.willChangeValue(forKey: "presentationSize")
                if let info, info.ok { self._setStatus(.readyToPlay) }
                else { self.error = _avLoadError(asset); self._setStatus(.failed) }
                self.didChangeValue(forKey: "presentationSize")
                self._player?._itemStatusChanged(self)
            }
        }
    }
    func _setStatus(_ s: Status) {
        guard s != status else { return }
        willChangeValue(forKey: "status"); status = s; didChangeValue(forKey: "status")
        if s == .failed {
            NSLog("isim AVFoundation: AVPlayerItem failed: %@", (error as NSError?)?.userInfo[NSLocalizedFailureReasonErrorKey] as? String ?? "")
        }
    }

    open var duration: CMTime {
        guard status == .readyToPlay, let i = _info else { return .indefinite }
        return i.duration > 0 ? CMTime(seconds: i.duration, preferredTimescale: 600) : .indefinite
    }
    var _durationSeconds: Double? {
        guard let i = _info, i.ok, i.duration > 0 else { return nil }
        if forwardPlaybackEndTime.isNumeric { return min(i.duration, forwardPlaybackEndTime.seconds) }
        return i.duration
    }
    @objc open var presentationSize: CGSize { guard let i = _info, i.hasVideo else { return .zero }; return CGSize(width: i.width, height: i.height) }
    open func currentTime() -> CMTime { CMTime(seconds: _player?.currentItem === self ? _player!._now() : _position, preferredTimescale: 600) }
    open var currentDate: Date? { nil }
    open var isPlaybackLikelyToKeepUp: Bool { status == .readyToPlay }
    open var isPlaybackBufferFull: Bool { false }
    open var isPlaybackBufferEmpty: Bool { status != .readyToPlay }
    open var loadedTimeRanges: [NSValue] { status == .readyToPlay ? [NSValue(timeRange: CMTimeRange(start: .zero, duration: duration))] : [] }
    open var seekableTimeRanges: [NSValue] { loadedTimeRanges }
    open var canPlayFastForward: Bool { true }
    open var canPlaySlowForward: Bool { true }
    open var canPlayReverse: Bool { false }
    open var canStepForward: Bool { true }
    open var canStepBackward: Bool { true }
    open var tracks: [AVPlayerItemTrack] { asset.tracks.map { AVPlayerItemTrack(assetTrack: $0) } }

    open func seek(to time: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        if let p = _player, p.currentItem === self { p.seek(to: time, completionHandler: completionHandler ?? { _ in }) }
        else { _position = max(0, time.isNumeric ? time.seconds : 0); completionHandler?(true) }
    }
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: ((Bool) -> Void)? = nil) {
        seek(to: time, completionHandler: completionHandler)
    }
    open func cancelPendingSeeks() {}
    open func step(byCount n: Int) {
        let fps = _info?.fps ?? 30
        seek(to: CMTime(seconds: max(0, currentTime().seconds + Double(n) / fps), preferredTimescale: 600))
    }
    /// A fresh item for the same asset (AVPlayerLooper replicas).
    func _replica() -> AVPlayerItem {
        let r = AVPlayerItem(asset: asset, automaticallyLoadedAssetKeys: automaticallyLoadedAssetKeys)
        r.forwardPlaybackEndTime = forwardPlaybackEndTime
        return r
    }

    public static let didPlayToEndTimeNotification = Notification.Name("AVPlayerItemDidPlayToEndTimeNotification")
    public static let failedToPlayToEndTimeNotification = Notification.Name("AVPlayerItemFailedToPlayToEndTimeNotification")
    public static let playbackStalledNotification = Notification.Name("AVPlayerItemPlaybackStalledNotification")
    public static let timeJumpedNotification = Notification.Name("AVPlayerItemTimeJumpedNotification")
    public static let newAccessLogEntryNotification = Notification.Name("AVPlayerItemNewAccessLogEntryNotification")
    public static let newErrorLogEntryNotification = Notification.Name("AVPlayerItemNewErrorLogEntryNotification")
}
public let AVPlayerItemFailedToPlayToEndTimeErrorKey = "AVPlayerItemFailedToPlayToEndTimeErrorKey"
extension Notification.Name {
    public static let AVPlayerItemDidPlayToEndTime = AVPlayerItem.didPlayToEndTimeNotification
    public static let AVPlayerItemFailedToPlayToEndTime = AVPlayerItem.failedToPlayToEndTimeNotification
    public static let AVPlayerItemPlaybackStalled = AVPlayerItem.playbackStalledNotification
    public static let AVPlayerItemTimeJumped = AVPlayerItem.timeJumpedNotification
    public static let AVPlayerItemNewAccessLogEntry = AVPlayerItem.newAccessLogEntryNotification
    public static let AVPlayerItemNewErrorLogEntry = AVPlayerItem.newErrorLogEntryNotification
}

open class AVPlayerItemTrack: NSObject {
    public let assetTrack: AVAssetTrack?
    open var isEnabled = true
    open var currentVideoFrameRate: Float { assetTrack?.nominalFrameRate ?? 0 }
    init(assetTrack: AVAssetTrack) { self.assetTrack = assetTrack }
}

// MARK: - AVPlayer

/// Drives players once per display frame while they play (or wait for a frame).
final class _AVTicker: NSObject {
    nonisolated(unsafe) static let shared = _AVTicker()
    var players: [ObjectIdentifier: AVPlayer] = [:]
    var link: CADisplayLink?
    func add(_ p: AVPlayer) {
        players[ObjectIdentifier(p)] = p
        if link == nil {
            let l = CADisplayLink(target: self, selector: #selector(tick))
            l.add(to: RunLoop.main, forMode: RunLoop.Mode.common.rawValue)
            link = l
        }
    }
    func remove(_ p: AVPlayer) {
        players[ObjectIdentifier(p)] = nil
        if players.isEmpty { link?.invalidate(); link = nil }
    }
    @objc func tick() { for p in Array(players.values) { p._tick() } }
}

open class AVPlayer: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, readyToPlay, failed }
    @objc public enum TimeControlStatus: Int, Sendable { case paused = 0, waitingToPlayAtSpecifiedRate, playing }
    @objc public enum ActionAtItemEnd: Int, Sendable { case advance = 0, pause, none }
    public struct WaitingReason: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let toMinimizeStalls = WaitingReason(rawValue: "AVPlayerWaitingToMinimizeStallsReason")
        public static let evaluatingBufferingRate = WaitingReason(rawValue: "AVPlayerWaitingWhileEvaluatingBufferingRateReason")
        public static let noItemToPlay = WaitingReason(rawValue: "AVPlayerWaitingWithNoItemToPlayReason")
    }

    @objc open private(set) var currentItem: AVPlayerItem?
    @objc open private(set) var status: Status = .readyToPlay
    open private(set) var error: Error?
    @objc open private(set) var timeControlStatus: TimeControlStatus = .paused
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { false }
    open private(set) var reasonForWaitingToPlay: WaitingReason?
    open var actionAtItemEnd: ActionAtItemEnd = .pause
    open var automaticallyWaitsToMinimizeStalling = true
    open var preventsDisplaySleepDuringVideoPlayback = true
    open var allowsExternalPlayback = true
    open var isExternalPlaybackActive: Bool { false }
    open var appliesMediaSelectionCriteriaAutomatically = true
    open var audiovisualBackgroundPlaybackPolicy: Int = 0
    open var defaultRate: Float = 1
    open var volume: Float = 1 { didSet { _applyAudio() } }
    open var isMuted = false { didSet { _applyAudio() } }

    /// rate: 0 = paused. Setting it starts or stops playback, like on iOS.
    @objc open var rate: Float {
        get { _rate }
        set {
            var r = newValue
            if r < 0 { NSLog("isim AVFoundation: reverse playback is not supported; pausing"); r = 0 }
            guard r != _rate else { return }
            let t = _now()
            willChangeValue(forKey: "rate")
            _rate = r
            _anchor = t; _anchorWall = isim_time()
            didChangeValue(forKey: "rate")
            _updateState()
            _firePeriodic(force: true)
        }
    }
    var _rate: Float = 0
    var _anchor: Double = 0          // media time at _anchorWall
    var _anchorWall: Double = 0
    var _media: Int32 = 0            // host playback session
    var _mediaStart: Double = 0
    var _frame: Int32 = 0            // current frame image (host handle owned by the session)
    var _framePTS: Double = -1
    var _needsFrame = false
    var _lastTick: Double = -1
    var _layers: [_AVWeakLayer] = []
    var _periodic: [_AVPeriodicObserver] = []
    var _boundary: [_AVBoundaryObserver] = []
    var _ended = false

    public override init() { super.init() }
    public init(playerItem item: AVPlayerItem?) {
        super.init()
        if let item { _setItem(item) }
    }
    public convenience init(url URL: URL) { self.init(playerItem: AVPlayerItem(url: URL)) }
    deinit { _closeMedia() }

    open func play() { rate = defaultRate > 0 ? defaultRate : 1 }
    open func pause() { rate = 0 }
    open func playImmediately(atRate r: Float) { rate = r }
    open func replaceCurrentItem(with item: AVPlayerItem?) {
        if let cur = currentItem, cur !== item { cur._position = _now(); cur._player = nil }
        _setItem(item)
    }
    func _setItem(_ item: AVPlayerItem?) {
        _closeMedia()
        willChangeValue(forKey: "currentItem")
        currentItem = item
        item?._player = self
        didChangeValue(forKey: "currentItem")
        _anchor = item?._position ?? 0; _anchorWall = isim_time(); _ended = false
        _frame = 0; _framePTS = -1
        _layersChanged()
        _itemStatusChanged(item)
    }
    func _itemStatusChanged(_ item: AVPlayerItem?) {
        guard item === currentItem else { return }
        if item?.status == .failed {
            error = item?.error
        }
        if item?.status == .readyToPlay { _anchorWall = isim_time(); _openMedia(at: _anchor) }
        _updateState()
    }

    // MARK: time
    func _now() -> Double {
        guard timeControlStatus == .playing else { return _anchor }
        var t = _anchor + (isim_time() - _anchorWall) * Double(_rate)
        if let d = currentItem?._durationSeconds { t = min(t, d) }
        return max(0, t)
    }
    open func currentTime() -> CMTime { CMTime(seconds: _now(), preferredTimescale: 600) }

    open func seek(to time: CMTime) { seek(to: time, completionHandler: { _ in }) }
    open func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {
        var t = time.isNumeric ? time.seconds : 0
        if let d = currentItem?._durationSeconds { t = min(t, d) }
        t = max(0, t)
        _anchor = t; _anchorWall = isim_time(); _ended = false
        currentItem?._position = t
        if currentItem?.status == .readyToPlay { _openMedia(at: t) }
        _lastTick = t
        if let item = currentItem { NotificationCenter.default.post(name: AVPlayerItem.timeJumpedNotification, object: item) }
        _firePeriodic(force: true)
        DispatchQueue.main.async { completionHandler(true) }
    }
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) { seek(to: time) }
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping (Bool) -> Void) {
        seek(to: time, completionHandler: completionHandler)
    }
    open func seek(to date: Date) {}
    open func seek(to time: CMTime) async -> Bool {
        await withCheckedContinuation { c in seek(to: time) { c.resume(returning: $0) } }
    }

    // MARK: observers
    open func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping @Sendable (CMTime) -> Void) -> Any {
        let o = _AVPeriodicObserver(interval: max(0.01, interval.isNumeric ? interval.seconds : 1), queue: queue, block: block)
        _periodic.append(o)
        o.fire(_now(), force: true)
        _updateTicking()
        return o
    }
    open func addBoundaryTimeObserver(forTimes times: [NSValue], queue: DispatchQueue?, using block: @escaping @Sendable () -> Void) -> Any {
        let o = _AVBoundaryObserver(times: times.map { $0.timeValue.seconds }.filter { $0.isFinite }, queue: queue, block: block)
        _boundary.append(o)
        return o
    }
    open func removeTimeObserver(_ observer: Any) {
        let o = observer as AnyObject
        _periodic.removeAll { $0 === o }
        _boundary.removeAll { $0 === o }
        _updateTicking()
    }
    func _firePeriodic(force: Bool) { let t = _now(); for o in _periodic { o.fire(t, force: force) } }

    // MARK: state
    func _updateState() {
        let item = currentItem
        let newStatus: TimeControlStatus
        var reason: WaitingReason? = nil
        if _rate == 0 { newStatus = .paused }
        else if item == nil { newStatus = .waitingToPlayAtSpecifiedRate; reason = .noItemToPlay }
        else if item?.status != .readyToPlay { newStatus = item?.status == .failed ? .paused : .waitingToPlayAtSpecifiedRate; reason = newStatus == .paused ? nil : .evaluatingBufferingRate }
        else { newStatus = .playing }
        if newStatus != timeControlStatus {
            let t = _now()
            willChangeValue(forKey: "timeControlStatus")
            timeControlStatus = newStatus
            _anchor = t; _anchorWall = isim_time()
            didChangeValue(forKey: "timeControlStatus")
        }
        reasonForWaitingToPlay = reason
        if newStatus == .playing, _media == 0, item?.status == .readyToPlay { _openMedia(at: _anchor) }
        _applyAudio()
        _updateTicking()
    }
    func _applyAudio() {
        guard _media != 0 else { return }
        let paused = timeControlStatus != .playing || _rate != 1
        isim_media_set_audio(_media, paused ? 1 : 0, isMuted ? 0 : Double(volume))
    }
    func _updateTicking() {
        if timeControlStatus == .playing || _needsFrame || (!_periodic.isEmpty && timeControlStatus != .paused) { _AVTicker.shared.add(self) }
        else { _AVTicker.shared.remove(self) }
    }

    // MARK: media session
    func _openMedia(at t: Double) {
        _closeMedia()
        guard let item = currentItem, let info = item._info, info.ok, let url = item.asset._url else { return }
        let path = url.isFileURL ? url.path : url.absoluteString
        _media = isim_media_open(path, t, info.width, info.height, info.fps, info.hasVideo ? 1 : 0, info.hasAudio ? 1 : 0, isMuted ? 0 : Double(volume))
        _mediaStart = t
        _needsFrame = info.hasVideo && _media != 0
        _applyAudio()
        _updateTicking()
    }
    func _closeMedia() {
        if _media != 0 { isim_media_close(_media); _media = 0 }
        if _frame != 0 { _frame = 0; _framePTS = -1; _layersChanged() }
    }

    func _tick() {
        let t = _now()
        if _media != 0 {
            var eof: Int32 = 0, pts = 0.0
            let img = isim_media_video_frame(_media, t, &eof, &pts)
            if img != 0 && (img != _frame || pts != _framePTS) {
                let first = _frame == 0
                _frame = img; _framePTS = pts
                _needsFrame = false
                if first { for l in _layers { l.layer?._readyChanged() } }
                _layersChanged()
            }
            if eof != 0 && currentItem?._durationSeconds == nil && timeControlStatus == .playing { _reachedEnd(); return }
        }
        if timeControlStatus == .playing {
            if !_boundary.isEmpty, _lastTick >= 0 {
                for o in _boundary { o.check(from: _lastTick, to: t) }
            }
            for o in _periodic { o.fire(t, force: false) }
            if let d = currentItem?._durationSeconds, t >= d - 1e-6, !_ended { _lastTick = t; _reachedEnd(); return }
        }
        _lastTick = t
        _updateTicking()
    }

    func _reachedEnd() {
        guard let item = currentItem else { return }
        _ended = true
        let end = item._durationSeconds ?? _now()
        _anchor = end; _anchorWall = isim_time()
        item._position = end
        NotificationCenter.default.post(name: AVPlayerItem.didPlayToEndTimeNotification, object: item)
        guard currentItem === item else { return }          // an observer replaced the item or seeked
        if !_ended { return }
        switch actionAtItemEnd {
        case .advance: _advance()
        case .pause: rate = 0
        case .none:
            willChangeValue(forKey: "timeControlStatus"); timeControlStatus = .paused; didChangeValue(forKey: "timeControlStatus")
            _anchor = end; _updateTicking()
        }
    }
    func _advance() { rate = 0 }

    // MARK: layers
    func _attach(_ l: AVPlayerLayer) { _layers.removeAll { $0.layer == nil || $0.layer === l }; _layers.append(_AVWeakLayer(l)) }
    func _detach(_ l: AVPlayerLayer) { _layers.removeAll { $0.layer == nil || $0.layer === l } }
    func _layersChanged() { for w in _layers { w.layer?.setNeedsDisplay() } }

    public static let rateDidChangeNotification = Notification.Name("AVPlayerRateDidChangeNotification")
    public static var eligibleForHDRPlayback: Bool { false }
}

final class _AVWeakLayer { weak var layer: AVPlayerLayer?; init(_ l: AVPlayerLayer) { layer = l } }

final class _AVPeriodicObserver: NSObject {
    let interval: Double, queue: DispatchQueue?, block: @Sendable (CMTime) -> Void
    var lastIndex = Int.min
    init(interval: Double, queue: DispatchQueue?, block: @escaping @Sendable (CMTime) -> Void) { self.interval = interval; self.queue = queue; self.block = block }
    func fire(_ t: Double, force: Bool) {
        let idx = Int((t / interval).rounded(.down))
        guard force || idx != lastIndex else { return }
        lastIndex = idx
        let time = CMTime(seconds: t, preferredTimescale: 600), b = block
        if let q = queue, q !== DispatchQueue.main { q.async { b(time) } } else { b(time) }
    }
}
final class _AVBoundaryObserver: NSObject {
    let times: [Double], queue: DispatchQueue?, block: @Sendable () -> Void
    init(times: [Double], queue: DispatchQueue?, block: @escaping @Sendable () -> Void) { self.times = times; self.queue = queue; self.block = block }
    func check(from a: Double, to b: Double) {
        guard b > a else { return }
        for t in times where t > a && t <= b {
            let blk = block
            if let q = queue, q !== DispatchQueue.main { q.async { blk() } } else { blk() }
        }
    }
}

// MARK: - AVQueuePlayer, AVPlayerLooper

open class AVQueuePlayer: AVPlayer, @unchecked Sendable {
    var _queue: [AVPlayerItem] = []
    public override init() { super.init(); actionAtItemEnd = .advance }
    public init(items: [AVPlayerItem]) {
        super.init()
        actionAtItemEnd = .advance
        _queue = items
        if let first = items.first { _setItem(first) }
    }
    public override init(playerItem item: AVPlayerItem?) {
        super.init()
        actionAtItemEnd = .advance
        if let item { _queue = [item]; _setItem(item) }
    }
    open func items() -> [AVPlayerItem] { _queue }
    open func advanceToNextItem() {
        guard !_queue.isEmpty else { return }
        let old = _queue.removeFirst()
        old._player = nil
        _setItem(_queue.first)
        _updateState()
    }
    open func canInsert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) -> Bool { !_queue.contains { $0 === item } }
    open func insert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) {
        guard canInsert(item, after: afterItem) else { return }
        if let a = afterItem, let i = _queue.firstIndex(where: { $0 === a }) { _queue.insert(item, at: i + 1) } else { _queue.append(item) }
        if currentItem == nil { _setItem(_queue.first); _updateState() }
    }
    open func remove(_ item: AVPlayerItem) {
        if item === currentItem { advanceToNextItem(); return }
        _queue.removeAll { $0 === item }
    }
    open func removeAllItems() { _queue.removeAll(); _setItem(nil); _updateState() }
    override func _advance() {
        advanceToNextItem()
        if currentItem == nil { rate = 0 }
    }
}

open class AVPlayerLooper: NSObject, @unchecked Sendable {
    @objc public enum Status: Int, Sendable { case unknown = 0, ready, failed, cancelled }
    public private(set) var status: Status = .unknown
    public private(set) var error: Error?
    public private(set) var loopCount = 0
    public private(set) var loopingPlayerItems: [AVPlayerItem] = []
    weak var player: AVQueuePlayer?
    let template: AVPlayerItem
    let range: CMTimeRange
    var observer: NSObjectProtocol?
    var disabled = false

    public init(player: AVQueuePlayer, templateItem: AVPlayerItem, timeRange: CMTimeRange = .invalid) {
        self.player = player; template = templateItem; range = timeRange
        super.init()
        player.removeAllItems()
        for _ in 0..<2 { player.insert(makeReplica(), after: nil) }
        status = .ready
        observer = NotificationCenter.default.addObserver(forName: AVPlayerItem.didPlayToEndTimeNotification, object: nil, queue: nil) { [weak self] n in
            guard let self, let item = n.object as? AVPlayerItem, self.loopingPlayerItems.contains(where: { $0 === item }), !self.disabled,
                  let p = self.player else { return }
            self.loopCount += 1
            self.loopingPlayerItems.removeAll { $0 === item }
            p.insert(self.makeReplica(), after: nil)
        }
    }
    public convenience init(player: AVQueuePlayer, templateItem: AVPlayerItem) { self.init(player: player, templateItem: templateItem, timeRange: .invalid) }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    func makeReplica() -> AVPlayerItem {
        let r = template._replica()
        if range.isValid && range.duration.isNumeric {
            r._position = range.start.seconds
            r.forwardPlaybackEndTime = range.end
        }
        loopingPlayerItems.append(r)
        return r
    }
    open func disableLooping() { disabled = true; status = .cancelled }
}

// MARK: - AVPlayerLayer

public struct AVLayerVideoGravity: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let resizeAspect = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspect")
    public static let resizeAspectFill = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspectFill")
    public static let resize = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResize")
}

/// Draws the player's current video frame (isim: a CALayer drawn by UIKit's renderer each frame).
open class AVPlayerLayer: CALayer {
    public override init() { super.init() }
    public convenience init(player: AVPlayer?) { self.init(); self.player = player }
    open var player: AVPlayer? {
        didSet {
            guard oldValue !== player else { return }
            oldValue?._detach(self); player?._attach(self)
            _readyChanged()
            setNeedsDisplay()
        }
    }
    open var videoGravity: AVLayerVideoGravity = .resizeAspect { didSet { setNeedsDisplay() } }
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { false }
    open var pixelBufferAttributes: [String: Any]?
    var _wasReady = false
    @objc open var isReadyForDisplay: Bool { (player?._frame ?? 0) != 0 }
    func _readyChanged() {
        let r = isReadyForDisplay
        guard r != _wasReady else { return }
        willChangeValue(forKey: "readyForDisplay"); willChangeValue(forKey: "isReadyForDisplay")
        _wasReady = r
        didChangeValue(forKey: "readyForDisplay"); didChangeValue(forKey: "isReadyForDisplay")
    }
    /// The rectangle the video occupies within the layer's bounds.
    open var videoRect: CGRect {
        guard let size = player?.currentItem?.presentationSize, size.width > 0, size.height > 0 else { return .zero }
        return AVMakeRect(aspectRatio: size, gravity: videoGravity, in: bounds)
    }
    open override func draw(in ctx: CGContext) {
        guard let p = player, p._frame != 0, let size = p.currentItem?.presentationSize, size.width > 0 else { return }
        let b = bounds
        let r = AVMakeRect(aspectRatio: size, gravity: videoGravity, in: b)
        isim_gfx_save()
        isim_gfx_clip_rounded(b.minX, b.minY, b.width, b.height, 0)
        isim_image_draw(p._frame, r.minX, r.minY, r.width, r.height, nil, 1)
        isim_gfx_restore()
    }
}

func AVMakeRect(aspectRatio size: CGSize, gravity: AVLayerVideoGravity, in b: CGRect) -> CGRect {
    if gravity == .resize { return b }
    let sx = b.width / size.width, sy = b.height / size.height
    let s = gravity == .resizeAspectFill ? max(sx, sy) : min(sx, sy)
    let w = size.width * s, h = size.height * s
    return CGRect(x: b.midX - w / 2, y: b.midY - h / 2, width: w, height: h)
}
public func AVMakeRect(aspectRatio: CGSize, insideRect boundingRect: CGRect) -> CGRect {
    guard aspectRatio.width > 0, aspectRatio.height > 0 else { return .zero }
    return AVMakeRect(aspectRatio: aspectRatio, gravity: .resizeAspect, in: boundingRect)
}
