// isim GameKit: a local Game Center. There is no connection to Apple's servers: the local player is the
// device's player (Settings > Game Center: signed in or not, nickname), and leaderboard scores and
// achievements are stored on the device, per app (in the app's container). Like iOS, signing in shows
// a "Welcome back" banner, completed achievements show a banner, and GKGameCenterViewController shows
// the player's leaderboards and achievements. Other players, friends, challenges and multiplayer
// matchmaking are not available.
import UIKit

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

/// iOS-style Game Center banner at the top of the screen.
@MainActor enum _GCBanner {
    static var window: UIWindow?
    static func show(title: String, subtitle: String) {
        window?.isHidden = true
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.windowLevel = UIWindow.Level(rawValue: 2100)
        w.isUserInteractionEnabled = false
        let root = UIViewController(); root.view.backgroundColor = .clear
        let card = UIView()
        card.backgroundColor = UIColor.secondarySystemBackground.withAlphaComponent(0.97)
        card.layer.cornerRadius = 18
        card.layer.shadowColor = UIColor.black.cgColor; card.layer.shadowOpacity = 0.2; card.layer.shadowRadius = 10
        card.translatesAutoresizingMaskIntoConstraints = false
        let icon = UILabel(); icon.text = "🎮"; icon.font = .systemFont(ofSize: 26)
        let t = UILabel(); t.text = title; t.font = .systemFont(ofSize: 15, weight: .semibold)
        let st = UILabel(); st.text = subtitle; st.font = .systemFont(ofSize: 13); st.textColor = .secondaryLabel
        let texts = UIStackView(arrangedSubviews: [t, st]); texts.axis = .vertical; texts.spacing = 1
        let row = UIStackView(arrangedSubviews: [icon, texts]); row.spacing = 12; row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(row)
        root.view.addSubview(card)
        NSLayoutConstraint.activate([
            card.topAnchor.constraint(equalTo: root.view.safeAreaLayoutGuide.topAnchor, constant: 6),
            card.centerXAnchor.constraint(equalTo: root.view.centerXAnchor),
            card.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: root.view.leadingAnchor, constant: 12),
            row.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
            row.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
            row.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
        ])
        w.rootViewController = root
        window = w
        w.isHidden = false
        NSLog("isim GameKit: banner: %@ — %@", title, subtitle)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { if window === w { w.isHidden = true; window = nil } }
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
    open func loadPhoto(for size: PhotoSize, withCompletionHandler h: ((UIImage?, Error?) -> Void)? = nil) { h?(nil, GKError.unsupported) }
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
                        _GCBanner.show(title: "Welcome back, \(_GC.alias)", subtitle: "isim Game Center (local)")
                        h(nil, nil)
                    } else {
                        NSLog("isim GameKit: not signed in to Game Center (isim Settings > Game Center)")
                        h(nil, GKError.notAuthenticated)
                    }
                }
            }
        }
    }
    open func loadFriends(_ h: @escaping ([GKPlayer]?, Error?) -> Void) { h([], nil) }
}

// MARK: - Leaderboards

open class GKLeaderboard: NSObject {
    public enum PlayerScope: Int, Sendable { case global = 0, friendsOnly = 1 }
    public enum TimeScope: Int, Sendable { case today = 0, week = 1, allTime = 2 }
    public enum LeaderboardType: Int, Sendable { case classic, recurring }
    open var baseLeaderboardID: String = ""
    open var title: String?
    open var type: LeaderboardType = .classic

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
        let ids = IDs ?? Array(_GC.scores().keys).sorted()
        let boards = ids.map { id -> GKLeaderboard in let b = GKLeaderboard(); b.baseLeaderboardID = id; b.title = id; return b }
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
        let e = _GC.best(baseLeaderboardID).map { Entry(score: $0["value"] as? Int ?? 0, context: $0["context"] as? Int ?? 0, date: Date(timeIntervalSince1970: $0["date"] as? Double ?? 0)) }
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
                let name = a.identifier
                DispatchQueue.main.async { MainActor.assumeIsolated { _GCBanner.show(title: "Achievement Earned", subtitle: name) } }
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
    var state: GKGameCenterViewControllerState = .dashboard
    var focusLeaderboard: String?
    public init(state: GKGameCenterViewControllerState) { self.state = state; super.init(nibName: nil, bundle: nil) }
    public init(leaderboardID: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope) {
        state = .leaderboards; focusLeaderboard = leaderboardID; super.init(nibName: nil, bundle: nil)
    }
    public init(achievementID: String) { state = .achievements; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(nibName: nil, bundle: nil) }

    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scroll)
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.titleLabel?.font = .systemFont(ofSize: 17, weight: .semibold)
        done.translatesAutoresizingMaskIntoConstraints = false
        done.accessibilityIdentifier = "gc-done"
        done.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if let d = self.gameCenterDelegate { d.gameCenterViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        }, for: .touchUpInside)
        view.addSubview(done)
        let stack = UIStackView(); stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(stack)
        NSLayoutConstraint.activate([
            done.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            scroll.topAnchor.constraint(equalTo: done.bottomAnchor, constant: 4),
            scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor), scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.leadingAnchor.constraint(equalTo: scroll.frameLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scroll.frameLayoutGuide.trailingAnchor, constant: -20),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
        ])
        func label(_ t: String, _ f: UIFont, _ c: UIColor = .label) -> UILabel { let l = UILabel(); l.text = t; l.font = f; l.textColor = c; l.numberOfLines = 0; return l }
        stack.addArrangedSubview(label("Game Center", .systemFont(ofSize: 34, weight: .bold)))
        stack.addArrangedSubview(label("\(_GC.alias) · isim local Game Center (scores and achievements stay on this device)", .systemFont(ofSize: 13), .secondaryLabel))
        func card(_ rows: [(String, String)], empty: String) -> UIView {
            let c = UIView(); c.backgroundColor = .secondarySystemGroupedBackground; c.layer.cornerRadius = 12
            let s = UIStackView(); s.axis = .vertical; s.spacing = 10; s.translatesAutoresizingMaskIntoConstraints = false
            if rows.isEmpty { s.addArrangedSubview(label(empty, .systemFont(ofSize: 15), .secondaryLabel)) }
            for (l, r) in rows {
                let a = label(l, .systemFont(ofSize: 15)), b = label(r, .monospacedDigitSystemFont(ofSize: 15, weight: .semibold), .secondaryLabel)
                b.textAlignment = .right
                let row = UIStackView(arrangedSubviews: [a, b]); row.spacing = 8
                s.addArrangedSubview(row)
            }
            c.addSubview(s)
            NSLayoutConstraint.activate([s.topAnchor.constraint(equalTo: c.topAnchor, constant: 14), s.bottomAnchor.constraint(equalTo: c.bottomAnchor, constant: -14),
                                         s.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 16), s.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -16)])
            return c
        }
        if state != .achievements {
            stack.addArrangedSubview(label("LEADERBOARDS", .systemFont(ofSize: 13), .secondaryLabel))
            let boards = _GC.scores().keys.sorted().filter { focusLeaderboard == nil || $0 == focusLeaderboard }
            let rows = boards.map { b -> (String, String) in ("\(b)", "#1 · \(_GC.best(b)?["value"] as? Int ?? 0)") }
            stack.addArrangedSubview(card(rows, empty: focusLeaderboard.map { "No score yet on \($0)." } ?? "No scores yet."))
        }
        if state != .leaderboards {
            stack.addArrangedSubview(label("ACHIEVEMENTS", .systemFont(ofSize: 13), .secondaryLabel))
            let rows = _GC.achievements().sorted { $0.key < $1.key }.map { id, v -> (String, String) in
                let p = v["percent"] as? Double ?? 0
                return (id, p >= 100 ? "✓ Earned" : "\(Int(p))%")
            }
            stack.addArrangedSubview(card(rows, empty: "No achievements yet."))
        }
    }
}

open class GKAccessPoint: NSObject {
    nonisolated(unsafe) public static let shared = GKAccessPoint()
    public enum Location: Int, Sendable { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    open var isActive = false
    open var location: Location = .topLeading
    open var showHighlights = false
    open var isVisible: Bool { false }
    open func trigger(handler: @escaping () -> Void) { handler() }
}
