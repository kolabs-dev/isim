// isim GameKit: a local Game Center. There is no connection to Apple's servers: the local player is the
// device's player (Settings > Game Center: signed in or not, nickname), and leaderboard scores and
// achievements are stored on the device, per app (in the app's container). Like iOS, signing in shows
// a "Welcome back" banner, completed achievements show a banner, and GKGameCenterViewController shows
// the player's leaderboards and achievements, with titles, descriptions and points from the app's
// isim-GameCenter.json (GameCenterConfig.swift). Saved games are kept in the device data. There are no
// other players: friends lists are empty, matchmaking finds nobody, challenges and invites never arrive.
import UIKit
import SwiftUI

public let GKErrorDomain = "GKErrorDomain"
public struct GKError: Error, CustomNSError, Sendable {
    public enum Code: Int, Sendable { case unknown = 1, cancelled = 2, communicationsFailure = 3, userDenied = 4, invalidCredentials = 5, notAuthenticated = 6, gameUnrecognized = 15, notSupported = 26 }
    public let code: Code
    public static var errorDomain: String { GKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] {
        [NSLocalizedDescriptionKey: code == .notAuthenticated ? "The local player is not signed in to Game Center (isim Settings > Game Center)." : "This Game Center feature is not available on isim."]
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
    /// leaderboard id -> [{value, context, date}]
    static func scores() -> [String: [[String: Any]]] { UserDefaults.standard.dictionary(forKey: scoresKey) as? [String: [[String: Any]]] ?? [:] }
    static func addScore(_ v: Int, context: Int, board: String) {
        var all = scores()
        var list = all[board] ?? []
        list.append(["value": v, "context": context, "date": Date().timeIntervalSince1970])
        if list.count > 200 { list.removeFirst(list.count - 200) }
        all[board] = list
        UserDefaults.standard.set(all, forKey: scoresKey)
    }
    static func best(_ board: String) -> [String: Any]? { scores()[board]?.max { ($0["value"] as? Int ?? 0) < ($1["value"] as? Int ?? 0) } }
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

/// iOS-style Game Center banner: slides down from the top with a spring, then slides away.
@MainActor enum _GCBanner {
    enum Kind { case player, achievement(String) }
    static var window: UIWindow?
    static func show(title: String, subtitle: String, kind: Kind) {
        window?.isHidden = true
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.windowLevel = UIWindow.Level(rawValue: 2100)
        w.isUserInteractionEnabled = false
        w.backgroundColor = .clear
        let width = min(UIScreen.main.bounds.width - 24, 380), height: CGFloat = 64
        let host = UIHostingController(rootView: _GCBannerView(title: title, subtitle: subtitle, kind: kind))
        host.view.backgroundColor = .clear
        let root = UIViewController(); root.view.backgroundColor = .clear
        root.addChild(host)
        let card = host.view!
        card.frame = CGRect(x: (UIScreen.main.bounds.width - width) / 2, y: -height - 10, width: width, height: height)
        root.view.addSubview(card)
        host.didMove(toParent: root)
        w.rootViewController = root
        window = w
        w.isHidden = false
        NSLog("isim GameKit: banner: %@ — %@", title, subtitle)
        let top = max(w.safeAreaInsets.top, 20)
        UIView.animate(withDuration: 0.6, delay: 0, usingSpringWithDamping: 0.78, initialSpringVelocity: 0, options: [], animations: {
            card.frame.origin.y = top + 4
        }, completion: { _ in
            UIView.animate(withDuration: 0.35, delay: 2.4, options: [.curveEaseIn], animations: {
                card.frame.origin.y = -height - 10
            }, completion: { _ in if window === w { w.isHidden = true; window = nil } })
        })
    }
}

struct _GCBannerView: View {
    let title: String, subtitle: String, kind: _GCBanner.Kind
    var body: some View {
        HStack(spacing: 12) {
            switch kind {
            case .player: _GCAvatar(name: _GC.alias, size: 40)
            case .achievement(let id): _GCMedal(achievement: _GCAchievement(id: id, percent: 100, date: Date()), size: 40)
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
open class GKPlayer: GKBasePlayer {
    open var alias: String { _GC.alias }
    open var gamePlayerID: String { "isim-local-player" }
    open var teamPlayerID: String { "isim-local-player" }
    open var isInvitable: Bool { false }
    /// A generated monogram (the player's initials on a gray circle), like Game Center's default avatar.
    open func loadPhoto(for size: PhotoSize, withCompletionHandler h: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.monogram(alias, size: size == .small ? 64 : 128)
        DispatchQueue.main.async { h?(img, img == nil ? GKError.unsupported : nil) }
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
    open var isAuthenticated: Bool { authenticated && _GC.signedIn }
    open var isUnderage: Bool { false }
    open var isMultiplayerGamingRestricted: Bool { true }
    open var isPersonalizedCommunicationRestricted: Bool { true }
    open var authenticateHandler: ((UIViewController?, Error?) -> Void)? {
        didSet {
            guard let h = authenticateHandler else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated {
                    if _GC.signedIn {
                        self.authenticated = true
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
    /// No other players on isim's local Game Center: the friends list is empty.
    open func loadFriends(_ h: @escaping ([GKPlayer]?, Error?) -> Void) { DispatchQueue.main.async { h([], nil) } }
    open func loadFriends() async throws -> [GKPlayer] { [] }
    open func loadRecentPlayers(completionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) { DispatchQueue.main.async { h?([], nil) } }
    open func loadChallengableFriends(completionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) { DispatchQueue.main.async { h?([], nil) } }
    public enum FriendsAuthorizationStatus: Int, Sendable { case notDetermined = 0, restricted = 1, denied = 2, authorized = 3 }
    open func loadFriendsAuthorizationStatus(_ h: @escaping (FriendsAuthorizationStatus, Error?) -> Void) { DispatchQueue.main.async { h(.authorized, nil) } }
    open func loadFriendsAuthorizationStatus() async throws -> FriendsAuthorizationStatus { .authorized }
    /// Shows the friend request composer (nothing is sent on isim).
    @MainActor open func presentFriendRequestCreator(from viewController: UIViewController) throws {
        viewController.present(GKFriendRequestComposeViewController(), animated: true, completion: nil)
    }
    // listeners (saved-game conflicts, ...)
    var listeners: [GKLocalPlayerListener] = []
    open func register(_ listener: GKLocalPlayerListener) { if !listeners.contains(where: { $0 === listener }) { listeners.append(listener) } }
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
    /// The leaderboard's image from the configuration, or a generated placeholder.
    open func loadImage(completionHandler h: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.leaderboard(baseLeaderboardID)
        DispatchQueue.main.async { h?(img, nil) }
    }
    open func loadImage() async throws -> UIImage {
        try await withCheckedThrowingContinuation { k in loadImage { i, e in if let i { k.resume(returning: i) } else { k.resume(throwing: e ?? GKError.unsupported) } } }
    }
    /// score entries in this leaderboard's period (the current occurrence of a recurring one)
    func entriesInScope(_ timeScope: TimeScope) -> [[String: Any]] {
        let def = _GCConfig.board(baseLeaderboardID)
        let (s, e) = def.occurrence(offset: occurrenceOffset)
        let now = Date()
        return (_GC.scores()[baseLeaderboardID] ?? []).filter { r in
            let d = Date(timeIntervalSince1970: r["date"] as? Double ?? 0)
            guard d >= s && d < e else { return false }
            switch timeScope {
            case .today: return Calendar.current.isDateInToday(d)
            case .week: return now.timeIntervalSince(d) < 7 * 86400
            case .allTime: return true
            }
        }
    }

    public class func submitScore(_ score: Int, context: Int, player: GKPlayer, leaderboardIDs: [String], completionHandler: @escaping (Error?) -> Void) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler(GKError.notAuthenticated) }; return }
        for id in leaderboardIDs { _GC.addScore(score, context: context, board: id) }
        NSLog("isim GameKit: score %ld submitted to %@", score, leaderboardIDs.joined(separator: ", "))
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
    open class Entry: NSObject {
        public let player: GKPlayer
        public let rank: Int, score: Int, context: Int
        public let date: Date
        open var formattedScore: String { String(score) }
        init(score: Int, context: Int, date: Date) { player = GKLocalPlayer.local; rank = 1; self.score = score; self.context = context; self.date = date }
    }
    /// The local player's entry (the only player on isim) and the requested range.
    open func loadEntries(for playerScope: PlayerScope, timeScope: TimeScope, range: NSRange,
                          completionHandler: @escaping (Entry?, [Entry]?, Int, Error?) -> Void) {
        let low = _GCConfig.board(baseLeaderboardID).sortLow
        let e = entriesInScope(timeScope).max(by: { a, b in let x = a["value"] as? Int ?? 0, y = b["value"] as? Int ?? 0; return low ? x > y : x < y }).map { Entry(score: $0["value"] as? Int ?? 0, context: $0["context"] as? Int ?? 0, date: Date(timeIntervalSince1970: $0["date"] as? Double ?? 0)) }
        DispatchQueue.main.async { completionHandler(e, e.map { [$0] } ?? [], e == nil ? 0 : 1, nil) }
    }
    open func loadEntries(for playerScope: PlayerScope, timeScope: TimeScope, range: NSRange) async throws -> (Entry?, [Entry], Int) {
        await withCheckedContinuation { k in loadEntries(for: playerScope, timeScope: timeScope, range: range) { a, b, c, _ in k.resume(returning: (a, b ?? [], c)) } }
    }
    open func submitScore(_ score: Int, context: Int, player: GKPlayer, completionHandler: @escaping (Error?) -> Void) {
        GKLeaderboard.submitScore(score, context: context, player: player, leaderboardIDs: [baseLeaderboardID], completionHandler: completionHandler)
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
