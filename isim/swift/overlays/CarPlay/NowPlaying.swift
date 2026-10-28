// isim CarPlay: the Now Playing template (MediaPlayer's Now Playing info and remote commands), thumbnails and the
// sports modes.
import CoreMedia
import Foundation
import MediaPlayer
import UIKit

@objc(CPNowPlayingButton)
open class CPNowPlayingButton: NSObject, NSSecureCoding {
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    var _isSelected: Bool = false
    @objc open var isSelected: Bool {
        @objc(isSelected) get { _isSelected }
        @objc(setSelected:) set { _isSelected = newValue; _CPCar.shared.setNeedsRender() }
    }
    var _handler: ((CPNowPlayingButton) -> Void)?
    @objc public init(handler: ((CPNowPlayingButton) -> Void)?) { _handler = handler; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(isEnabled, forKey: "enabled"); c.encode(isSelected, forKey: "selected") }
    public required init?(coder c: NSCoder) {
        _isEnabled = c.containsValue(forKey: "enabled") ? c.decodeBool(forKey: "enabled") : true
        _isSelected = c.decodeBool(forKey: "selected")
        super.init()
    }
    func _tap() { if isEnabled { _handler?(self) } }
    /// the SF Symbol CarPlay draws for it, and its name in `carplay dump`
    var _symbol: String { "•••" }
    var _name: String { "button" }
}
@objc(CPNowPlayingShuffleButton) open class CPNowPlayingShuffleButton: CPNowPlayingButton {
    override var _symbol: String { "shuffle" }
    override var _name: String { "shuffle" }
}
@objc(CPNowPlayingRepeatButton) open class CPNowPlayingRepeatButton: CPNowPlayingButton {
    override var _symbol: String { "repeat" }
    override var _name: String { "repeat" }
}
@objc(CPNowPlayingAddToLibraryButton) open class CPNowPlayingAddToLibraryButton: CPNowPlayingButton {
    override var _symbol: String { "plus" }
    override var _name: String { "add-to-library" }
}
@objc(CPNowPlayingMoreButton) open class CPNowPlayingMoreButton: CPNowPlayingButton {
    override var _symbol: String { "•••" }   // drawn as text
    override var _name: String { "more" }
}
@objc(CPNowPlayingPlaybackRateButton) open class CPNowPlayingPlaybackRateButton: CPNowPlayingButton {
    override var _symbol: String { "1×" }   // drawn as text
    override var _name: String { "rate" }
}
@objc(CPNowPlayingImageButton)
open class CPNowPlayingImageButton: CPNowPlayingButton {
    @objc open private(set) var image: UIImage?
    @objc public init(image: UIImage, handler: ((CPNowPlayingButton) -> Void)?) { self.image = image; super.init(handler: handler) }
    public required init?(coder c: NSCoder) { image = c.decodeObject(of: UIImage.self, forKey: "image"); super.init(coder: c) }
    override var _name: String { "image" }
}

@objc(CPNowPlayingTemplateObserver)
public protocol CPNowPlayingTemplateObserver: NSObjectProtocol {
    @objc optional func nowPlayingTemplateUpNextButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate)
    @objc optional func nowPlayingTemplateAlbumArtistButtonTapped(_ nowPlayingTemplate: CPNowPlayingTemplate)
}

/// the app's Now Playing screen: CarPlay draws MPNowPlayingInfoCenter's info (title, artist, album, artwork, the
/// elapsed time) and sends MPRemoteCommandCenter's commands for its transport buttons
@objc(CPNowPlayingTemplate)
open class CPNowPlayingTemplate: CPTemplate {
    nonisolated(unsafe) static let _shared = CPNowPlayingTemplate(_shared: ())
    @objc(sharedTemplate) open class var shared: CPNowPlayingTemplate { _shared }
    @objc open private(set) var nowPlayingButtons: [CPNowPlayingButton] = []
    var _isUpNextButtonEnabled: Bool = false
    @objc open var isUpNextButtonEnabled: Bool {
        @objc(isUpNextButtonEnabled) get { _isUpNextButtonEnabled }
        @objc(setUpNextButtonEnabled:) set { _isUpNextButtonEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var upNextTitle: String = "Up Next" { didSet { _CPCar.shared.setNeedsRender() } }
    var _isAlbumArtistButtonEnabled: Bool = false
    @objc open var isAlbumArtistButtonEnabled: Bool {
        @objc(isAlbumArtistButtonEnabled) get { _isAlbumArtistButtonEnabled }
        @objc(setAlbumArtistButtonEnabled:) set { _isAlbumArtistButtonEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var allowsMiniPlayer: Bool = true
    @objc open var nowPlayingMode: CPNowPlayingMode? { didSet { _CPCar.shared.setNeedsRender() } }
    var _observers = NSHashTable<AnyObject>.weakObjects()

    init(_shared: Void) { super.init() }
    public required init?(coder c: NSCoder) { super.init(coder: c) }
    @objc open func updateNowPlayingButtons(_ nowPlayingButtons: [CPNowPlayingButton]) {
        self.nowPlayingButtons = Array(nowPlayingButtons.prefix(5)); _CPCar.shared.setNeedsRender()
    }
    @objc(addObserver:) open func add(_ observer: any CPNowPlayingTemplateObserver) { _observers.add(observer) }
    @objc(removeObserver:) open func remove(_ observer: any CPNowPlayingTemplateObserver) { _observers.remove(observer) }
    func _upNext() {
        guard isUpNextButtonEnabled else { return }
        for o in _observers.allObjects { (o as? CPNowPlayingTemplateObserver)?.nowPlayingTemplateUpNextButtonTapped?(self) }
    }
    func _albumArtist() {
        guard isAlbumArtistButtonEnabled else { return }
        for o in _observers.allObjects { (o as? CPNowPlayingTemplateObserver)?.nowPlayingTemplateAlbumArtistButtonTapped?(self) }
    }
    override var _barTitle: String? { "Now Playing" }
    override var _hasBar: Bool { true }

    /// what it shows: MPNowPlayingInfoCenter's info
    struct _Info { var title = "Not Playing", artist = "", album = "", artwork: UIImage?, duration = 0.0, elapsed = 0.0, playing = false }
    var _info: _Info {
        var i = _Info()
        let c = MPNowPlayingInfoCenter.default()
        guard let d = c.nowPlayingInfo else { return i }
        let num = { (k: String) -> Double? in (d[k] as? NSNumber)?.doubleValue }
        i.title = d[MPMediaItemPropertyTitle] as? String ?? ""
        i.artist = d[MPMediaItemPropertyArtist] as? String ?? ""
        i.album = d[MPMediaItemPropertyAlbumTitle] as? String ?? ""
        i.artwork = (d[MPMediaItemPropertyArtwork] as? MPMediaItemArtwork)?.image(at: CGSize(width: 240, height: 240))
        i.duration = num(MPMediaItemPropertyPlaybackDuration) ?? 0
        i.elapsed = num(MPNowPlayingInfoPropertyElapsedPlaybackTime) ?? (num(MPNowPlayingInfoPropertyPlaybackProgress) ?? 0) * i.duration
        let rate = num(MPNowPlayingInfoPropertyPlaybackRate)
        i.playing = c.playbackState == .playing || (c.playbackState != .paused && (rate ?? 0) > 0)
        return i
    }
    /// a transport button: the app's MPRemoteCommandCenter command ("play", "pause", "next", "previous", ...)
    static func _command(_ name: String) {
        // UIKit's queue of remote commands, which the app's MPRemoteCommandCenter takes (as from Control Center)
        typealias Post = @convention(c) (UnsafePointer<CChar>) -> Void
        NSLog("isim CarPlay: Now Playing %@", name)
        guard let f = _uikit("isim_media_remote_post", Post.self) else { return }
        f(name)
    }
}

// MARK: - playback configurations (iOS 26)

@objc(CPPlaybackConfiguration)
open class CPPlaybackConfiguration: NSObject, NSSecureCoding {
    @objc(CPPlaybackPresentation) public enum Presentation: Int, @unchecked Sendable { case none = 0, audio, video }
    @objc(CPPlaybackAction) public enum Action: Int, @unchecked Sendable { case none = 0, play, pause, replay }
    @objc open private(set) var preferredPresentation: CPPlaybackConfiguration.Presentation
    @objc open private(set) var playbackAction: CPPlaybackConfiguration.Action
    // CMTime is a Swift struct in isim's CoreMedia: these are Swift only
    open private(set) var elapsedTime: CMTime
    open private(set) var duration: CMTime
    public init(preferredPresentation: CPPlaybackConfiguration.Presentation, playbackAction: CPPlaybackConfiguration.Action, elapsedTime: CMTime, duration: CMTime) {
        self.preferredPresentation = preferredPresentation; self.playbackAction = playbackAction; self.elapsedTime = elapsedTime; self.duration = duration
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(preferredPresentation.rawValue, forKey: "presentation"); c.encode(playbackAction.rawValue, forKey: "action")
        c.encode(elapsedTime.seconds, forKey: "elapsed"); c.encode(duration.seconds, forKey: "duration")
    }
    public required init?(coder c: NSCoder) {
        preferredPresentation = .init(rawValue: c.decodeInteger(forKey: "presentation")) ?? .none
        playbackAction = .init(rawValue: c.decodeInteger(forKey: "action")) ?? .none
        elapsedTime = CMTime(seconds: c.decodeDouble(forKey: "elapsed"), preferredTimescale: 600)
        duration = CMTime(seconds: c.decodeDouble(forKey: "duration"), preferredTimescale: 600)
        super.init()
    }
}

// MARK: - thumbnails and overlays (iOS 26)

@objc(CPImageOverlay)
open class CPImageOverlay: NSObject, NSSecureCoding {
    @objc(CPImageOverlayAlignment) public enum Alignment: Int, @unchecked Sendable { case leading = 0, center, trailing }
    @objc open private(set) var alignment: CPImageOverlay.Alignment
    @objc open private(set) var image: UIImage?
    @objc open private(set) var text: String?
    @objc open private(set) var textColor: UIColor?
    @objc open private(set) var backgroundColor: UIColor?
    @objc public init(image: UIImage, alignment: CPImageOverlay.Alignment) { self.image = image; self.alignment = alignment; super.init() }
    @objc public init(text: String, textColor: UIColor, backgroundColor: UIColor, alignment: CPImageOverlay.Alignment) {
        self.text = text; self.textColor = textColor; self.backgroundColor = backgroundColor; self.alignment = alignment
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(text, forKey: "text"); c.encode(alignment.rawValue, forKey: "alignment"); c.encode(image, forKey: "image") }
    public required init?(coder c: NSCoder) {
        text = c.decodeObject(of: NSString.self, forKey: "text") as String?
        image = c.decodeObject(of: UIImage.self, forKey: "image")
        alignment = .init(rawValue: c.decodeInteger(forKey: "alignment")) ?? .leading
        super.init()
    }
}

@objc(CPNowPlayingSportsTeamLogo)
open class CPNowPlayingSportsTeamLogo: NSObject, NSSecureCoding {
    @objc open private(set) var logo: UIImage?
    @objc open private(set) var initials: String?
    @objc public init(teamLogo: UIImage) { logo = teamLogo; super.init() }
    @objc public init(teamInitials: String) { initials = teamInitials; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(initials, forKey: "initials"); c.encode(logo, forKey: "logo") }
    public required init?(coder c: NSCoder) {
        initials = c.decodeObject(of: NSString.self, forKey: "initials") as String?
        logo = c.decodeObject(of: UIImage.self, forKey: "logo")
        super.init()
    }
}

@objc(CPNowPlayingSportsTeam)
open class CPNowPlayingSportsTeam: NSObject, NSSecureCoding {
    @objc open private(set) var name: String
    @objc open private(set) var logo: CPNowPlayingSportsTeamLogo
    @objc open private(set) var teamStandings: String?
    @objc open private(set) var eventScore: String
    @objc open private(set) var possessionIndicator: UIImage?
    @objc open private(set) var isFavorite: Bool
    @objc public init(name: String, logo: CPNowPlayingSportsTeamLogo, teamStandings: String?, eventScore: String, possessionIndicator: UIImage?, favorite: Bool) {
        self.name = name; self.logo = logo; self.teamStandings = teamStandings; self.eventScore = eventScore
        self.possessionIndicator = possessionIndicator; isFavorite = favorite
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {
        c.encode(name, forKey: "name"); c.encode(logo, forKey: "logo"); c.encode(teamStandings, forKey: "standings")
        c.encode(eventScore, forKey: "score"); c.encode(isFavorite, forKey: "favorite")
    }
    public required init?(coder c: NSCoder) {
        guard let n = c.decodeObject(of: NSString.self, forKey: "name") as String?,
              let l = c.decodeObject(of: CPNowPlayingSportsTeamLogo.self, forKey: "logo") else { return nil }
        name = n; logo = l
        teamStandings = c.decodeObject(of: NSString.self, forKey: "standings") as String?
        eventScore = (c.decodeObject(of: NSString.self, forKey: "score") as String?) ?? ""
        isFavorite = c.decodeBool(forKey: "favorite")
        super.init()
    }
}

@objc(CPNowPlayingSportsClock)
open class CPNowPlayingSportsClock: NSObject, NSSecureCoding {
    @objc open private(set) var timeValue: TimeInterval
    @objc open private(set) var countsUp: Bool
    @objc open private(set) var isPaused: Bool
    @objc public init(elapsedTime: TimeInterval, paused: Bool) { timeValue = elapsedTime; countsUp = true; isPaused = paused; super.init() }
    @objc public init(timeRemaining: TimeInterval, paused: Bool) { timeValue = timeRemaining; countsUp = false; isPaused = paused; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(timeValue, forKey: "time"); c.encode(countsUp, forKey: "up"); c.encode(isPaused, forKey: "paused") }
    public required init?(coder c: NSCoder) {
        timeValue = c.decodeDouble(forKey: "time"); countsUp = c.decodeBool(forKey: "up"); isPaused = c.decodeBool(forKey: "paused")
        super.init()
    }
}

@objc(CPNowPlayingSportsEventStatus)
open class CPNowPlayingSportsEventStatus: NSObject, NSSecureCoding {
    @objc open private(set) var eventStatusText: [String]?
    @objc open private(set) var eventStatusImage: UIImage?
    @objc open private(set) var eventClock: CPNowPlayingSportsClock?
    @objc public init(eventStatusText: [String]?, eventStatusImage: UIImage?, eventClock: CPNowPlayingSportsClock?) {
        self.eventStatusText = eventStatusText; self.eventStatusImage = eventStatusImage; self.eventClock = eventClock
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(eventStatusText, forKey: "text"); c.encode(eventClock, forKey: "clock") }
    public required init?(coder c: NSCoder) {
        eventStatusText = c.decodeObject(of: [NSArray.self, NSString.self], forKey: "text") as? [String]
        eventClock = c.decodeObject(of: CPNowPlayingSportsClock.self, forKey: "clock")
        super.init()
    }
}

@objc(CPSportsOverlay)
open class CPSportsOverlay: NSObject, NSSecureCoding {
    @objc open private(set) var leftTeam: CPNowPlayingSportsTeam
    @objc open private(set) var rightTeam: CPNowPlayingSportsTeam
    @objc open private(set) var eventStatus: CPNowPlayingSportsEventStatus?
    @objc public init(leftTeam: CPNowPlayingSportsTeam, rightTeam: CPNowPlayingSportsTeam, eventStatus: CPNowPlayingSportsEventStatus?) {
        self.leftTeam = leftTeam; self.rightTeam = rightTeam; self.eventStatus = eventStatus
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(leftTeam, forKey: "left"); c.encode(rightTeam, forKey: "right"); c.encode(eventStatus, forKey: "status") }
    public required init?(coder c: NSCoder) {
        guard let l = c.decodeObject(of: CPNowPlayingSportsTeam.self, forKey: "left"), let r = c.decodeObject(of: CPNowPlayingSportsTeam.self, forKey: "right") else { return nil }
        leftTeam = l; rightTeam = r
        eventStatus = c.decodeObject(of: CPNowPlayingSportsEventStatus.self, forKey: "status")
        super.init()
    }
}

@objc(CPThumbnailImage)
open class CPThumbnailImage: NSObject, NSSecureCoding {
    @objc open var image: UIImage { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var imageOverlay: CPImageOverlay? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var sportsOverlay: CPSportsOverlay? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc public init(image: UIImage) { self.image = image; super.init() }
    @objc public init(image: UIImage, imageOverlay: CPImageOverlay?, sportsOverlay: CPSportsOverlay?) {
        self.image = image; self.imageOverlay = imageOverlay; self.sportsOverlay = sportsOverlay
        super.init()
    }
    /// the largest image CarPlay draws for a thumbnail of this aspect ratio (width / height)
    @objc open class func maximumImageSize(forAspectRatio aspectRatio: CGFloat) -> CGSize {
        let r = aspectRatio > 0 ? aspectRatio : 1
        return r >= 1 ? CGSize(width: 180, height: 180 / r) : CGSize(width: 180 * r, height: 180)
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(image, forKey: "image"); c.encode(imageOverlay, forKey: "overlay"); c.encode(sportsOverlay, forKey: "sports") }
    public required init?(coder c: NSCoder) {
        image = c.decodeObject(of: UIImage.self, forKey: "image") ?? UIImage()
        imageOverlay = c.decodeObject(of: CPImageOverlay.self, forKey: "overlay")
        sportsOverlay = c.decodeObject(of: CPSportsOverlay.self, forKey: "sports")
        super.init()
    }
}

// MARK: - Now Playing modes (iOS 26)

@objc(CPNowPlayingMode)
open class CPNowPlayingMode: NSObject, NSSecureCoding {
    nonisolated(unsafe) static let _default = CPNowPlayingMode()
    @objc(defaultNowPlayingMode) open class var `default`: CPNowPlayingMode { _default }
    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) {}
    public required init?(coder c: NSCoder) { super.init() }
}

@objc(CPNowPlayingModeSports)
open class CPNowPlayingModeSports: CPNowPlayingMode {
    @objc open var leftTeam: CPNowPlayingSportsTeam { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var rightTeam: CPNowPlayingSportsTeam { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var eventStatus: CPNowPlayingSportsEventStatus? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var backgroundArtwork: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc public init(leftTeam: CPNowPlayingSportsTeam, rightTeam: CPNowPlayingSportsTeam, eventStatus: CPNowPlayingSportsEventStatus?, backgroundArtwork: UIImage?) {
        self.leftTeam = leftTeam; self.rightTeam = rightTeam; self.eventStatus = eventStatus; self.backgroundArtwork = backgroundArtwork
        super.init()
    }
    public override func encode(with c: NSCoder) { c.encode(leftTeam, forKey: "left"); c.encode(rightTeam, forKey: "right"); c.encode(eventStatus, forKey: "status") }
    public required init?(coder c: NSCoder) {
        guard let l = c.decodeObject(of: CPNowPlayingSportsTeam.self, forKey: "left"), let r = c.decodeObject(of: CPNowPlayingSportsTeam.self, forKey: "right") else { return nil }
        leftTeam = l; rightTeam = r
        eventStatus = c.decodeObject(of: CPNowPlayingSportsEventStatus.self, forKey: "status")
        super.init(coder: c)
    }
}
