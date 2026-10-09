// isim GameKit: a local Game Center. There is no connection to Apple's servers: the local player is the
// device's player (Settings > Game Center: signed in or not, nickname), and the other players are the other isim
// devices on this computer plus test players made with `isim gamecenter` (GameCenterNetwork.swift). Like iOS,
// signing in shows a "Welcome back" banner, completed achievements show a banner, and GKGameCenterViewController
// shows the game's leaderboards (every player's best score, ranked) and the player's achievements, with titles,
// descriptions and points from the app's isim-GameCenter.json (GameCenterConfig.swift). Saved games are kept in the
// device data. Friends, matches, challenges and invites are in GameKitSocial.swift and GameKitMultiplayer.swift.
import UIKit
import SwiftUI

public let GKErrorDomain = "GKErrorDomain"
public struct GKError: Error, CustomNSError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 1, cancelled = 2, communicationsFailure = 3, userDenied = 4, invalidCredentials = 5, notAuthenticated = 6,
             authenticationInProgress = 7, invalidPlayer = 8, scoreNotSet = 9, parentalControlsBlocked = 10,
             playerStatusExceedsMaximumLength = 11, playerStatusInvalid = 12, matchRequestInvalid = 13, underage = 14,
             gameUnrecognized = 15, notSupported = 16, invalidParameter = 17, unexpectedConnection = 18, challengeInvalid = 19,
             turnBasedMatchDataTooLarge = 20, turnBasedTooManySessions = 21, turnBasedInvalidParticipant = 22,
             turnBasedInvalidTurn = 23, turnBasedInvalidState = 24, invitationsDisabled = 25, playerPhotoFailure = 26,
             ubiquityContainerUnavailable = 27, matchNotConnected = 28, gameSessionRequestInvalid = 29,
             restrictedToAutomatch = 30, apiNotAvailable = 31, notAuthorized = 32, connectionTimeout = 33, apiObsolete = 34,
             iCloudUnavailable = 35, lockdownMode = 36, appUnlisted = 37,
             friendListDescriptionMissing = 100, friendListRestricted = 101, friendListDenied = 102, friendRequestNotAvailable = 103
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    init(code: Code) { self.code = code }
    public static var errorDomain: String { GKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        let text: String
        switch code {
        case .notAuthenticated: text = "The local player is not signed in to Game Center (isim Settings > Game Center)."
        case .cancelled: text = "The requested operation has been cancelled."
        case .friendListDescriptionMissing: text = "The app's Info.plist has no NSGKFriendListUsageDescription."
        case .friendListDenied: text = "The player did not allow access to their friends list."
        case .invalidPlayer: text = "The player is not on isim's local Game Center."
        case .turnBasedInvalidTurn: text = "It is not the local player's turn."
        case .turnBasedInvalidParticipant: text = "The participant is not in the match."
        case .turnBasedInvalidState: text = "The match is not in a state that allows this."
        case .turnBasedMatchDataTooLarge: text = "The match data is larger than matchDataMaximumSize."
        case .matchNotConnected: text = "The players are not connected."
        case .challengeInvalid: text = "The challenge is not valid."
        case .invalidParameter: text = "An invalid parameter was passed."
        default: text = "This Game Center feature is not available on isim."
        }
        return [NSLocalizedDescriptionKey: text]
    }
    static let notAuthenticated = GKError(code: .notAuthenticated)
    static let unsupported = GKError(code: .notSupported)
}

// MARK: - Device settings and storage

enum _GC {
    static var global: UserDefaults? { UserDefaults(suiteName: ".GlobalPreferences") }
    static var signedIn: Bool { (global?.object(forKey: "ISIMGameCenterSignedIn") as? Bool) ?? true }
    static var alias: String {
        let a = global?.string(forKey: "ISIMGameCenterNickname") ?? ""
        return a.isEmpty ? "Player" : a
    }
    static let scoresKey = "_ISIMGameCenterScores", achievementsKey = "_ISIMGameCenterAchievements"
    /// the local player's scores in this game: leaderboard id -> [{value, context, date}] (on the local network)
    static func scores() -> [String: [[String: Any]]] { _GCNet.scores(of: _GCNet.me) }
    static func addScore(_ v: Int, context: Int, board: String) { _GCNet.addScore(v, context: context, board: board, player: _GCNet.me) }
    /// isim before 0.13 kept scores in the app's preferences: move them to the network once
    static func migrateScores() {
        guard let old = UserDefaults.standard.dictionary(forKey: scoresKey) as? [String: [[String: Any]]] else { return }
        _GCNet.update(_GCNet.scoresFile(_GCNet.me)) { all in
            for (board, list) in old { all[board] = list + (all[board] as? [[String: Any]] ?? []) }
            return true
        }
        UserDefaults.standard.removeObject(forKey: scoresKey)
    }
    /// achievement id -> {percent, date}
    static func achievements() -> [String: [String: Any]] { UserDefaults.standard.dictionary(forKey: achievementsKey) as? [String: [String: Any]] ?? [:] }
    static func setAchievement(_ id: String, percent: Double) -> Bool {
        var all = achievements()
        let old = all[id]?["percent"] as? Double ?? 0
        guard percent > old else { return false }
        all[id] = ["percent": percent, "date": Date().timeIntervalSince1970]
        UserDefaults.standard.set(all, forKey: achievementsKey)
        return old < 100 && percent >= 100
    }
    static func reset() { UserDefaults.standard.removeObject(forKey: achievementsKey) }
}

/// iOS-style Game Center banner: slides down from the top with a spring, then slides away. A banner with a `tap`
/// action (an invite, a challenge) stays longer and can be tapped (accessibility identifier "gc-banner").
@MainActor enum _GCBanner {
    enum Kind { case player, achievement(String), other(String) }
    static var window: UIWindow?
    static func show(title: String, subtitle: String, kind: Kind, tap: (() -> Void)? = nil) {
        window?.isHidden = true
        let width = min(UIScreen.main.bounds.width - 24, 380), height: CGFloat = 64
        let w = UIWindow(frame: CGRect(x: (UIScreen.main.bounds.width - width) / 2, y: -height - 10, width: width, height: height))
        w.windowLevel = UIWindow.Level(rawValue: 2100)
        w.isUserInteractionEnabled = tap != nil
        w.backgroundColor = .clear
        let host = UIHostingController(rootView: _GCBannerView(title: title, subtitle: subtitle, kind: kind))
        host.view.backgroundColor = .clear
        let root = UIViewController(); root.view.backgroundColor = .clear
        root.addChild(host)
        host.view.frame = CGRect(x: 0, y: 0, width: width, height: height)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        if let tap {
            let b = UIButton(type: .custom)
            b.frame = host.view.frame
            b.accessibilityIdentifier = "gc-banner"
            b.accessibilityLabel = title
            b.addAction(UIAction { _ in
                NSLog("isim GameKit: banner tapped: %@", title)
                w.isHidden = true
                if window === w { window = nil }
                tap()
            }, for: .touchUpInside)
            root.view.addSubview(b)
        }
        w.rootViewController = root
        window = w
        w.isHidden = false
        NSLog("isim GameKit: banner: %@ — %@", title, subtitle)
        let top = max(UIApplication.shared.windows.first?.safeAreaInsets.top ?? 0, 20)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0, options: [], animations: {
            w.frame.origin.y = top + 4
        }, completion: nil)
        // a fixed time on screen (not an animation delay, so it holds with animations off)
        DispatchQueue.main.asyncAfter(deadline: .now() + (tap == nil ? 3 : 8)) {
            MainActor.assumeIsolated {
                guard window === w else { return }
                UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseIn], animations: {
                    w.frame.origin.y = -height - 10
                }, completion: { _ in if window === w { w.isHidden = true; window = nil } })
            }
        }
    }
}

struct _GCBannerView: View {
    let title: String, subtitle: String, kind: _GCBanner.Kind
    var body: some View {
        HStack(spacing: 12) {
            switch kind {
            case .player: _GCAvatar(name: _GC.alias, size: 40)
            case .achievement(let id): _GCMedal(achievement: _GCAchievement(id: id, percent: 100, date: Date()), size: 40)
            case .other(let name): _GCAvatar(name: name, size: 40)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: title).font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(verbatim: subtitle).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Image(systemName: "gamecontroller").font(.system(size: 15)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
    }
}

// MARK: - Players

open class GKBasePlayer: NSObject {
    open var displayName: String { _GC.alias }
}
/// A Game Center player: the local player, another isim device on this computer, or a test player
/// (`isim gamecenter player add`). Players are equal when they are the same player.
open class GKPlayer: GKBasePlayer {
    /// the player's id on isim's local Game Center network ("" for a guest)
    var _id = ""
    var _alias = ""
    var _guest: String?
    static func _make(_ id: String) -> GKPlayer {
        if id == _GCNet.me { return GKLocalPlayer.local }
        let p = GKPlayer()
        p._id = id
        p._alias = _GCNet.player(id)?.alias ?? "Player"
        return p
    }
    open var alias: String { _alias }
    open override var displayName: String { alias }
    open var gamePlayerID: String { _guest.map { "G:\($0)" } ?? "A:_\(_id)" }
    open var teamPlayerID: String { _guest.map { "G:\($0)" } ?? "T:_\(_id)" }
    open var guestIdentifier: String? { _guest }
    /// Invitable: another device's player (test players cannot play matches).
    open var isInvitable: Bool { !(_GCNet.player(_id)?.test ?? true) }
    public class func anonymousGuestPlayer(withIdentifier guestIdentifier: String?) -> Self {
        let p = self.init()
        p._guest = guestIdentifier ?? UUID().uuidString
        p._alias = "Guest"
        return p
    }
    public required override init() { super.init() }
    open override func isEqual(_ object: Any?) -> Bool {
        guard let o = object as? GKPlayer else { return false }
        return o._id == _id && o._guest == _guest
    }
    open override var hash: Int { _id.hashValue ^ (_guest?.hashValue ?? 0) }
    open override var description: String { "<GKPlayer: \(alias) \(gamePlayerID)>" }
    /// A generated monogram (the player's initials on a gray circle), like Game Center's default avatar.
    open func loadPhoto(for size: PhotoSize, withCompletionHandler h: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.monogram(alias, size: size == .small ? 64 : 128)
        DispatchQueue.main.async { h?(img, img == nil ? GKError(code: .playerPhotoFailure) : nil) }
    }
    open func loadPhoto(for size: PhotoSize) async throws -> UIImage {
        try await withCheckedThrowingContinuation { k in loadPhoto(for: size) { i, e in if let i { k.resume(returning: i) } else { k.resume(throwing: e ?? GKError.unsupported) } } }
    }
    open func scopedIDsArePersistent() -> Bool { true }
    public enum PhotoSize: Int, Sendable { case small, normal }
}

open class GKLocalPlayer: GKPlayer {
    nonisolated(unsafe) public static let local = GKLocalPlayer()
    @available(*, deprecated) public class func localPlayer() -> GKLocalPlayer { local }
    private var authenticated = false
    open override var alias: String { _GC.alias }
    open override var displayName: String { _GC.alias }
    open override var gamePlayerID: String { "A:_\(_GCNet.me)" }
    open override var teamPlayerID: String { "T:_\(_GCNet.me)" }
    open override var isInvitable: Bool { true }
    open override func isEqual(_ object: Any?) -> Bool { (object as? GKPlayer).map { $0 === self || ($0._guest == nil && $0._id == _GCNet.me) } ?? false }
    open override var hash: Int { _GCNet.me.hashValue }
    public required init() { super.init(); _id = _GCNet.me }
    open var isAuthenticated: Bool { authenticated && _GC.signedIn }
    open var isUnderage: Bool { false }
    /// Matches are played with the other isim devices on this computer.
    open var isMultiplayerGamingRestricted: Bool { false }
    open var isPersonalizedCommunicationRestricted: Bool { false }
    open var authenticateHandler: ((UIViewController?, Error?) -> Void)? {
        didSet {
            guard let h = authenticateHandler else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated {
                    if _GC.signedIn {
                        self.authenticated = true
                        _GCNet.register()
                        _GC.migrateScores()
                        _GCNet.startPolling()
                        _GCBanner.show(title: "Welcome back, \(_GC.alias)", subtitle: "Game Center", kind: .player)
                        h(nil, nil)
                        if GKAccessPoint.shared.isActive { GKAccessPoint.shared.update() }
                    } else {
                        NSLog("isim GameKit: not signed in to Game Center (isim Settings > Game Center)")
                        h(nil, GKError.notAuthenticated)
                    }
                }
            }
        }
    }
    /// The player's friends on isim's local Game Center (asks for access first, like iOS 14.5 and later).
    open func loadFriends(_ h: @escaping ([GKPlayer]?, Error?) -> Void) { _GCSocial.loadFriends(nil, h) }
    open func loadFriends() async throws -> [GKPlayer] {
        try await withCheckedThrowingContinuation { k in loadFriends { f, e in if let f { k.resume(returning: f) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    open func loadFriends(identifiedBy identifiers: [String], completionHandler h: @escaping ([GKPlayer]?, Error?) -> Void) { _GCSocial.loadFriends(identifiers, h) }
    /// Players met in matches, newest first.
    open func loadRecentPlayers(completionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { h?(nil, GKError.notAuthenticated) }; return }
        let list = _GCNet.recentIDs().map(GKPlayer._make)
        DispatchQueue.main.async { h?(list, nil) }
    }
    open func loadRecentPlayers() async throws -> [GKPlayer] {
        try await withCheckedThrowingContinuation { k in loadRecentPlayers { f, e in if let f { k.resume(returning: f) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Friends who can be challenged (all of them on isim).
    open func loadChallengableFriends(completionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { h?(nil, GKError.notAuthenticated) }; return }
        let list = _GCNet.friendIDs().map(GKPlayer._make).sorted { $0.alias < $1.alias }
        DispatchQueue.main.async { h?(list, nil) }
    }
    open func loadChallengableFriends() async throws -> [GKPlayer] {
        try await withCheckedThrowingContinuation { k in loadChallengableFriends { f, e in if let f { k.resume(returning: f) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    public enum FriendsAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted = 1, denied = 2, authorized = 3 }
    open func loadFriendsAuthorizationStatus(_ h: @escaping (FriendsAuthorizationStatus, Error?) -> Void) {
        let s = _GCSocial.status
        DispatchQueue.main.async { h(s, nil) }
    }
    open func loadFriendsAuthorizationStatus() async throws -> FriendsAuthorizationStatus { _GCSocial.status }
    /// Shows the friend request composer; the request goes to the player with that nickname on the local network.
    @MainActor open func presentFriendRequestCreator(from viewController: UIViewController) throws {
        guard isAuthenticated else { throw GKError.notAuthenticated }
        viewController.present(GKFriendRequestComposeViewController(), animated: true, completion: nil)
    }
    // listeners (saved-game conflicts, invites, turns, challenges, game activities)
    var listeners: [GKLocalPlayerListener] = []
    open func register(_ listener: GKLocalPlayerListener) {
        if !listeners.contains(where: { $0 === listener }) { listeners.append(listener) }
        DispatchQueue.main.async { MainActor.assumeIsolated { _GCEvents.flush() } }
    }
    open func unregisterListener(_ listener: GKLocalPlayerListener) { listeners.removeAll { $0 === listener } }
    open func unregisterAllListeners() { listeners.removeAll() }
}

// MARK: - Leaderboards

open class GKLeaderboard: NSObject {
    public enum PlayerScope: Int, Sendable { case global = 0, friendsOnly = 1 }
    public enum TimeScope: Int, Sendable { case today = 0, week = 1, allTime = 2 }
    public enum LeaderboardType: Int, Sendable { case classic, recurring }
    open var baseLeaderboardID: String = ""
    open var title: String?
    open var type: LeaderboardType = .classic
    open var groupIdentifier: String?
    /// recurring leaderboards: the occurrence this object describes
    open var startDate: Date?
    open var nextStartDate: Date?
    open var duration: TimeInterval = 0
    var occurrenceOffset = 0
    static func make(_ id: String, offset: Int = 0) -> GKLeaderboard {
        let def = _GCConfig.board(id), b = GKLeaderboard()
        b.baseLeaderboardID = id; b.title = def.title; b.type = def.recurring ? .recurring : .classic
        if def.recurring {
            let (s, e) = def.occurrence(offset: offset)
            b.startDate = s; b.nextStartDate = e; b.duration = def.duration; b.occurrenceOffset = offset
        }
        return b
    }
    /// recurring: the previous occurrence (its own scores)
    open func loadPreviousOccurrence(completionHandler h: @escaping (GKLeaderboard?, Error?) -> Void) {
        let b: GKLeaderboard? = type == .recurring ? GKLeaderboard.make(baseLeaderboardID, offset: occurrenceOffset - 1) : nil
        DispatchQueue.main.async { h(b, nil) }
    }
    open func loadPreviousOccurrence() async throws -> GKLeaderboard? {
        await withCheckedContinuation { k in loadPreviousOccurrence { b, _ in k.resume(returning: b) } }
    }
    /// The leaderboard's image from the configuration (a file or asset in the bundle), or a generated placeholder.
    open func loadImage(completionHandler h: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.leaderboard(baseLeaderboardID)
        DispatchQueue.main.async { h?(img, nil) }
    }
    open func loadImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation { k in loadImage { i, e in if let i { k.resume(returning: i) } else { k.resume(throwing: e ?? GKError.unsupported) } } }
    }
    /// every player's best score in this leaderboard's period (the current occurrence of a recurring one) and the
    /// time scope, best first (ties: the earlier score first)
    func ranked(_ timeScope: TimeScope, players only: Set<String>? = nil) -> [Entry] {
        let def = _GCConfig.board(baseLeaderboardID)
        let (s, e) = def.occurrence(offset: occurrenceOffset)
        let now = Date()
        var best: [(String, Int, Int, Date)] = []
        for pid in _GCNet.scoredPlayers() where only?.contains(pid) ?? true {
            let mine = (_GCNet.scores(of: pid)[baseLeaderboardID] ?? []).compactMap { r -> (Int, Int, Date)? in
                guard let v = r["value"] as? Int else { return nil }
                let d = Date(timeIntervalSince1970: r["date"] as? Double ?? 0)
                guard d >= s && d < e else { return nil }
                switch timeScope {
                case .today: guard Calendar.current.isDateInToday(d) else { return nil }
                case .week: guard now.timeIntervalSince(d) < 7 * 86400 else { return nil }
                case .allTime: break
                }
                return (v, r["context"] as? Int ?? 0, d)
            }
            let top = mine.min { a, b in a.0 != b.0 ? (def.sortLow ? a.0 < b.0 : a.0 > b.0) : a.2 < b.2 }
            if let top { best.append((pid, top.0, top.1, top.2)) }
        }
        best.sort { a, b in a.1 != b.1 ? (def.sortLow ? a.1 < b.1 : a.1 > b.1) : a.3 < b.3 }
        return best.enumerated().map { i, r in Entry(player: GKPlayer._make(r.0), rank: i + 1, score: r.1, context: r.2, date: r.3, board: def) }
    }

    public class func submitScore(_ score: Int, context: Int, player: GKPlayer, leaderboardIDs: [String], completionHandler: @escaping (Error?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler(GKError.notAuthenticated) }; return }
        guard player === GKLocalPlayer.local || player.isEqual(GKLocalPlayer.local) else { DispatchQueue.main.async { completionHandler(GKError(code: .invalidPlayer)) }; return }
        for id in leaderboardIDs { _GC.addScore(score, context: context, board: id) }
        NSLog("isim GameKit: score %ld submitted to %@", score, leaderboardIDs.joined(separator: ", "))
        for id in leaderboardIDs { _GCChallenges.scoreSubmitted(score, board: id) }
        DispatchQueue.main.async { completionHandler(nil) }
    }
    public class func submitScore(_ score: Int, context: Int, player: GKPlayer, leaderboardIDs: [String]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            submitScore(score, context: context, player: player, leaderboardIDs: leaderboardIDs) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    public class func loadLeaderboards(IDs: [String]?, completionHandler: @escaping ([GKLeaderboard]?, Error?) -> Void) {
        let ids = IDs ?? Array(Set(_GC.scores().keys).union(_GCConfig.boards.map { $0.id })).sorted()
        let boards = ids.map { GKLeaderboard.make($0) }
        DispatchQueue.main.async { completionHandler(boards, nil) }
    }
    public class func loadLeaderboards(IDs: [String]?) async throws -> [GKLeaderboard] {
        await withCheckedContinuation { k in loadLeaderboards(IDs: IDs) { b, _ in k.resume(returning: b ?? []) } }
    }
    /// A player's best score; `formattedScore` follows the leaderboard's score format from the configuration.
    open class Entry: NSObject {
        public let player: GKPlayer
        public let rank: Int, score: Int, context: Int
        public let date: Date
        let board: _GCBoardDef
        open var formattedScore: String { board.formatted(score) }
        init(player: GKPlayer, rank: Int, score: Int, context: Int, date: Date, board: _GCBoardDef) {
            self.player = player; self.rank = rank; self.score = score; self.context = context; self.date = date; self.board = board
        }
        open override var description: String { "<GKLeaderboard.Entry #\(rank) \(player.alias) \(formattedScore)>" }
    }
    /// The local player's entry, the entries in `range` (1-based ranks) and the number of players with a score.
    /// `.friendsOnly`: the local player and their friends.
    open func loadEntries(for playerScope: PlayerScope, timeScope: TimeScope, range: NSRange,
                          completionHandler: @escaping (Entry?, [Entry]?, Int, Error?) -> Void) {
        guard range.location >= 1, range.length >= 1, range.length <= 100 else {
            DispatchQueue.main.async { completionHandler(nil, nil, 0, GKError(code: .invalidParameter)) }; return
        }
        let me = _GCNet.me
        let all = ranked(timeScope, players: playerScope == .friendsOnly ? Set(_GCNet.friendIDs() + [me]) : nil)
        let local = all.first { $0.player === GKLocalPlayer.local }
        let page = Array(all.dropFirst(range.location - 1).prefix(range.length))
        DispatchQueue.main.async { completionHandler(local, page, all.count, nil) }
    }
    open func loadEntries(for playerScope: PlayerScope, timeScope: TimeScope, range: NSRange) async throws -> (Entry?, [Entry], Int) {
        try await withCheckedThrowingContinuation { k in
            loadEntries(for: playerScope, timeScope: timeScope, range: range) { a, b, c, e in if let e { k.resume(throwing: e) } else { k.resume(returning: (a, b ?? [], c)) } }
        }
    }
    /// The entries of the given players (ranked among all players).
    open func loadEntries(for players: [GKPlayer], timeScope: TimeScope, completionHandler: @escaping (Entry?, [Entry]?, Error?) -> Void) {
        let all = ranked(timeScope)
        let ids = Set(players.map { $0 === GKLocalPlayer.local ? _GCNet.me : $0._id })
        let local = all.first { $0.player === GKLocalPlayer.local }
        let list = all.filter { ids.contains($0.player === GKLocalPlayer.local ? _GCNet.me : $0.player._id) }
        DispatchQueue.main.async { completionHandler(local, list, nil) }
    }
    open func loadEntries(for players: [GKPlayer], timeScope: TimeScope) async throws -> (Entry?, [Entry]) {
        await withCheckedContinuation { k in loadEntries(for: players, timeScope: timeScope) { a, b, _ in k.resume(returning: (a, b ?? [])) } }
    }
    open func submitScore(_ score: Int, context: Int, player: GKPlayer, completionHandler: @escaping (Error?) -> Void) {
        GKLeaderboard.submitScore(score, context: context, player: player, leaderboardIDs: [baseLeaderboardID], completionHandler: completionHandler)
    }
    open func submitScore(_ score: Int, context: Int, player: GKPlayer) async throws {
        try await GKLeaderboard.submitScore(score, context: context, player: player, leaderboardIDs: [baseLeaderboardID])
    }
}

// MARK: - Achievements

open class GKAchievement: NSObject {
    open var identifier: String
    open var percentComplete: Double = 0
    open var showsCompletionBanner = false
    open var isCompleted: Bool { percentComplete >= 100 }
    open var lastReportedDate = Date()
    public init(identifier: String?) { self.identifier = identifier ?? "" }
    public override convenience init() { self.init(identifier: nil) }
    public class func report(_ achievements: [GKAchievement], withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler?(GKError.notAuthenticated) }; return }
        for a in achievements {
            let completedNow = _GC.setAchievement(a.identifier, percent: min(100, max(0, a.percentComplete)))
            NSLog("isim GameKit: achievement %@ %.0f%%", a.identifier, a.percentComplete)
            if completedNow { _GCChallenges.achievementCompleted(a.identifier) }
            if completedNow && a.showsCompletionBanner {
                let id = a.identifier, name = _GCText.title(id)
                DispatchQueue.main.async { MainActor.assumeIsolated { _GCBanner.show(title: name, subtitle: "Achievement Earned", kind: .achievement(id)) } }
            }
        }
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    public class func report(_ achievements: [GKAchievement]) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            report(achievements) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    public class func loadAchievements(completionHandler: (([GKAchievement]?, Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler?(nil, GKError.notAuthenticated) }; return }
        let list = _GC.achievements().map { id, v -> GKAchievement in
            let a = GKAchievement(identifier: id); a.percentComplete = v["percent"] as? Double ?? 0
            a.lastReportedDate = Date(timeIntervalSince1970: v["date"] as? Double ?? 0); return a
        }
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    public class func loadAchievements() async throws -> [GKAchievement] {
        await withCheckedContinuation { k in loadAchievements { l, _ in k.resume(returning: l ?? []) } }
    }
    public class func resetAchievements(completionHandler: ((Error?) -> Void)? = nil) {
        _GC.reset()
        DispatchQueue.main.async { completionHandler?(nil) }
    }
}

// MARK: - Dashboard

@objc public protocol GKGameCenterControllerDelegate: NSObjectProtocol {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController)
}

public enum GKGameCenterViewControllerState: Int, Sendable { case `default` = -1, leaderboards = 0, achievements = 1, challenges = 2, localPlayerProfile = 3, dashboard = 4, localPlayerFriendsList = 5 }

/// The player's Game Center: leaderboards (best score per board) and achievements, as stored on isim.
open class GKGameCenterViewController: UIViewController {
    weak open var gameCenterDelegate: GKGameCenterControllerDelegate?
    var onFinish: (() -> Void)?
    open var leaderboardIdentifier: String? { get { focusLeaderboard } set { focusLeaderboard = newValue } }
    open var viewState: GKGameCenterViewControllerState { get { state } set { state = newValue } }
    var state: GKGameCenterViewControllerState = .dashboard
    var focusLeaderboard: String?
    public init(state: GKGameCenterViewControllerState) { self.state = state; super.init(nibName: nil, bundle: nil) }
    public init(leaderboardID: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope) {
        state = .leaderboards; focusLeaderboard = leaderboardID; super.init(nibName: nil, bundle: nil)
    }
    public init(achievementID: String) { state = .achievements; super.init(nibName: nil, bundle: nil) }
    public init(leaderboardSetID: String) { state = .leaderboards; focusSet = leaderboardSetID; super.init(nibName: nil, bundle: nil) }
    public init(player: GKPlayer) { state = .localPlayerProfile; super.init(nibName: nil, bundle: nil) }
    var focusSet: String?
    public required init?(coder: NSCoder) { super.init(nibName: nil, bundle: nil) }

    // the access point hides while Game Center is on screen
    open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); GKAccessPoint.shared.setPresenting(true) }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { GKAccessPoint.shared.setPresenting(false) }
    }

    open override func viewDidLoad() {
        super.viewDidLoad()
        // like iOS: a material backdrop, so the game shows through (blurred) behind Game Center
        view.backgroundColor = .clear
        let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterial))
        backdrop.frame = view.bounds
        backdrop.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(backdrop)
        let initial: [_GCRoute]
        switch state {
        case .leaderboards: initial = focusLeaderboard.map { [.leaderboard($0)] } ?? focusSet.map { [.leaderboardSet($0)] } ?? [.leaderboards]
        case .localPlayerFriendsList: initial = [.friends]
        case .achievements: initial = [.achievements]
        default: initial = []
        }
        let host = UIHostingController(rootView: _GCDashboard(initial: initial) { [weak self] in
            guard let self else { return }
            if let d = self.gameCenterDelegate { d.gameCenterViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
            let f = self.onFinish; self.onFinish = nil; f?()
        })
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

/// The Game Center access point: a floating bubble with the player's monogram in a corner of the
/// screen while `isActive` (and the player is signed in); tapping it opens the dashboard.
open class GKAccessPoint: NSObject {
    nonisolated(unsafe) public static let shared = GKAccessPoint()
    public enum Location: Int, Sendable { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    open var isActive = false { didSet { DispatchQueue.main.async { MainActor.assumeIsolated { self.update() } } } }
    open var location: Location = .topLeading { didSet { if isActive { DispatchQueue.main.async { MainActor.assumeIsolated { self.update() } } } } }
    open var showHighlights = false
    open var isFocused = false
    open private(set) var isPresentingGameCenter = false
    @MainActor func setPresenting(_ on: Bool) { isPresentingGameCenter = on; update() }
    open var isVisible: Bool { MainActor.assumeIsolated { window != nil && !(window?.isHidden ?? true) } }
    open var frameInScreenCoordinates: CGRect { MainActor.assumeIsolated { window?.frame ?? .zero } }
    @MainActor var window: UIWindow?

    @MainActor func update() {
        let show = isActive && GKLocalPlayer.local.isAuthenticated && !isPresentingGameCenter
        guard show else { window?.isHidden = true; window = nil; return }
        let size: CGFloat = 48, screen = UIScreen.main.bounds
        let top = UIApplication.shared.windows.first?.safeAreaInsets.top ?? 47
        let x = location == .topLeading || location == .bottomLeading ? 16 : screen.width - size - 16
        let y = location == .topLeading || location == .topTrailing ? max(top, 20) + 4 : screen.height - size - 40
        let w = window ?? UIWindow(frame: .zero)
        w.frame = CGRect(x: x, y: y, width: size, height: size)
        w.windowLevel = UIWindow.Level(rawValue: 1900)
        w.backgroundColor = .clear
        let b = UIButton(type: .custom)
        b.frame = CGRect(x: 0, y: 0, width: size, height: size)
        b.setImage(_GCImages.monogram(_GC.alias, size: 96), for: .normal)
        b.layer.cornerRadius = size / 2
        b.clipsToBounds = true
        b.accessibilityIdentifier = "gc-access-point"
        b.addAction(UIAction { [weak self] _ in self?.trigger(state: .dashboard) {} }, for: .touchUpInside)
        let root = UIViewController(); root.view.backgroundColor = .clear
        root.view.addSubview(b)
        w.rootViewController = root
        window = w
        w.isHidden = false
        NSLog("isim GameKit: access point shown (%@)", ["top leading", "top trailing", "bottom leading", "bottom trailing"][location.rawValue])
    }
    /// Opens the Game Center dashboard (like tapping the access point).
    open func trigger(handler: @escaping () -> Void) { trigger(state: .dashboard, handler: handler) }
    open func trigger(state: GKGameCenterViewControllerState, handler: @escaping () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.present(GKGameCenterViewController(state: state), handler) } }
    }
    open func trigger(leaderboardID: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope, handler: @escaping () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.present(GKGameCenterViewController(leaderboardID: leaderboardID, playerScope: playerScope, timeScope: timeScope), handler) } }
    }
    open func trigger(achievementID: String, handler: @escaping () -> Void) {
        DispatchQueue.main.async { MainActor.assumeIsolated { self.present(GKGameCenterViewController(achievementID: achievementID), handler) } }
    }
    @MainActor func present(_ vc: GKGameCenterViewController, _ handler: @escaping () -> Void) {
        guard var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController else { return }
        while let p = top.presentedViewController { top = p }
        NSLog("isim GameKit: access point opens Game Center")
        GKAccessPoint.shared.setPresenting(true)
        vc.onFinish = handler
        top.present(vc, animated: true, completion: nil)
    }
}
