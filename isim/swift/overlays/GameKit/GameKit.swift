// isim GameKit stand-in. Game Center needs Apple's servers and an Apple Account, which isim does not
// have: the local player never authenticates (the authenticate handler receives a "not available"
// error, as on a device without Game Center), and score/achievement reports fail quietly with the
// same error. Classes exist so apps that integrate Game Center build and run.
import UIKit

public let GKErrorDomain = "GKErrorDomain"
public struct GKError: Error, CustomNSError, Sendable {
    public enum Code: Int, Sendable { case unknown = 1, cancelled = 2, communicationsFailure = 3, userDenied = 4, invalidCredentials = 5, notAuthenticated = 6, gameUnrecognized = 15, notSupported = 26 }
    public let code: Code
    public static var errorDomain: String { GKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: "Game Center is not available on isim."] }
    static let unavailable = GKError(code: .notSupported)
}

open class GKBasePlayer: NSObject {
    open var displayName: String { "Player" }
}
open class GKPlayer: GKBasePlayer {
    open var alias: String { "Player" }
    open var gamePlayerID: String { "" }
    open var teamPlayerID: String { "" }
    open var isInvitable: Bool { false }
}

open class GKLocalPlayer: GKPlayer {
    nonisolated(unsafe) public static let local = GKLocalPlayer()
    @available(*, deprecated) public class func localPlayer() -> GKLocalPlayer { local }
    open var isAuthenticated: Bool { false }
    open var isUnderage: Bool { false }
    open var isMultiplayerGamingRestricted: Bool { true }
    open var authenticateHandler: ((UIViewController?, Error?) -> Void)? {
        didSet {
            guard let h = authenticateHandler else { return }
            NSLog("isim GameKit: Game Center is not available on isim (the local player is not authenticated)")
            DispatchQueue.main.async { h(nil, GKError.unavailable) }
        }
    }
}

open class GKLeaderboard: NSObject {
    public enum PlayerScope: Int, Sendable { case global = 0, friendsOnly = 1 }
    public enum TimeScope: Int, Sendable { case today = 0, week = 1, allTime = 2 }
    public enum LeaderboardType: Int, Sendable { case classic, recurring }
    open var baseLeaderboardID: String = ""
    open var title: String?
    public class func submitScore(_ score: Int, context: Int, player: GKPlayer, leaderboardIDs: [String], completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(GKError.unavailable) }
    }
    public class func submitScore(_ score: Int, context: Int, player: GKPlayer, leaderboardIDs: [String]) async throws { throw GKError.unavailable }
    public class func loadLeaderboards(IDs: [String]?, completionHandler: @escaping ([GKLeaderboard]?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, GKError.unavailable) }
    }
    public class func loadLeaderboards(IDs: [String]?) async throws -> [GKLeaderboard] { throw GKError.unavailable }
}

open class GKAchievement: NSObject {
    open var identifier: String
    open var percentComplete: Double = 0
    open var showsCompletionBanner = false
    open var isCompleted: Bool { percentComplete >= 100 }
    public init(identifier: String?) { self.identifier = identifier ?? "" }
    public override convenience init() { self.init(identifier: nil) }
    public class func report(_ achievements: [GKAchievement], withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(GKError.unavailable) }
    }
    public class func report(_ achievements: [GKAchievement]) async throws { throw GKError.unavailable }
    public class func loadAchievements(completionHandler: (([GKAchievement]?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(nil, GKError.unavailable) }
    }
    public class func resetAchievements(completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(GKError.unavailable) }
    }
}

@objc public protocol GKGameCenterControllerDelegate: NSObjectProtocol {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController)
}

public enum GKGameCenterViewControllerState: Int, Sendable { case `default` = -1, leaderboards = 0, achievements = 1, challenges = 2, localPlayerProfile = 3, dashboard = 4, localPlayerFriendsList = 5 }

/// Shows a placeholder explaining that Game Center is unavailable (only reachable when an app
/// presents it without checking isAuthenticated).
open class GKGameCenterViewController: UIViewController {
    weak open var gameCenterDelegate: GKGameCenterControllerDelegate?
    public init(state: GKGameCenterViewControllerState) { super.init(nibName: nil, bundle: nil) }
    public init(leaderboardID: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope) { super.init(nibName: nil, bundle: nil) }
    public init(achievementID: String) { super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { super.init(nibName: nil, bundle: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Game Center is not available on isim."
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        let done = UIButton(type: .system)
        done.setTitle("Done", for: .normal)
        done.translatesAutoresizingMaskIntoConstraints = false
        done.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            if let d = self.gameCenterDelegate { d.gameCenterViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        }, for: .touchUpInside)
        view.addSubview(label); view.addSubview(done)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -40),
            done.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            done.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }
}

open class GKAccessPoint: NSObject {
    nonisolated(unsafe) public static let shared = GKAccessPoint()
    public enum Location: Int, Sendable { case topLeading, topTrailing, bottomLeading, bottomTrailing }
    open var isActive = false
    open var location: Location = .topLeading
    open var isVisible: Bool { false }
}
