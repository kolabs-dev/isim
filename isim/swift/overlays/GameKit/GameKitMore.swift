// isim GameKit, continued: achievement descriptions and leaderboard sets (from isim-GameCenter.json),
// saved games (stored in the device data, with conflicts), the local player's listener, and the friend
// request composer (the request goes to the player with that nickname on isim's local Game Center network).
import UIKit
import SwiftUI

// MARK: - Achievement descriptions

open class GKAchievementDescription: NSObject {
    public let identifier: String
    public let groupIdentifier: String?
    public let title: String
    public let achievedDescription: String
    public let unachievedDescription: String
    public let maximumPoints: Int
    public let isHidden: Bool
    public let isReplayable: Bool
    public var rarityPercent: NSNumber? { nil }
    public var releaseState: Int { 1 }
    init(_ d: _GCAchievementDef) {
        identifier = d.id; groupIdentifier = d.group; title = d.title; achievedDescription = d.achieved; unachievedDescription = d.unachieved
        maximumPoints = d.points; isHidden = d.hidden; isReplayable = d.replayable
    }
    /// From the app's isim-GameCenter.json (App Store Connect metadata isn't available locally).
    public class func loadAchievementDescriptions(completionHandler: (([GKAchievementDescription]?, Error?) -> Void)? = nil) {
        let list = _GCConfig.achievements.map(GKAchievementDescription.init)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    public class func loadAchievementDescriptions() async throws -> [GKAchievementDescription] { _GCConfig.achievements.map(GKAchievementDescription.init) }
    open func loadImage(completionHandler: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.achievement(identifier, completed: true)
        DispatchQueue.main.async { completionHandler?(img, nil) }
    }
    open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.achievement(identifier, completed: true) else { throw GKError.unsupported }
        return i
    }
    public class func incompleteAchievementImage() -> UIImage { _GCImages.achievement("", completed: false) ?? UIImage() }
    public class func placeholderCompletedAchievementImage() -> UIImage { _GCImages.achievement("", completed: true) ?? UIImage() }
}

// MARK: - Leaderboard sets

open class GKLeaderboardSet: NSObject {
    open var title: String
    open var identifier: String?
    open var groupIdentifier: String?
    let boards: [String]
    init(_ d: _GCSetDef) { title = d.title; identifier = d.id; boards = d.boards }
    public class func loadLeaderboardSets(completionHandler: (([GKLeaderboardSet]?, Error?) -> Void)? = nil) {
        let list = _GCConfig.sets.map(GKLeaderboardSet.init)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    public class func loadLeaderboardSets() async throws -> [GKLeaderboardSet] { _GCConfig.sets.map(GKLeaderboardSet.init) }
    open func loadLeaderboards(handler: @escaping ([GKLeaderboard]?, Error?) -> Void) {
        let list = boards.map { GKLeaderboard.make($0) }
        DispatchQueue.main.async { handler(list, nil) }
    }
    open func loadLeaderboards() async throws -> [GKLeaderboard] { boards.map { GKLeaderboard.make($0) } }
    /// The set's image from the configuration (a file or asset in the bundle), or a generated placeholder.
    open func loadImage(completionHandler: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.set(identifier ?? "")
        DispatchQueue.main.async { completionHandler?(img, nil) }
    }
    open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.set(identifier ?? "") else { throw GKError.unsupported }
        return i
    }
}

// MARK: - Listener

/// Everything other players and the system tell the game: saved-game changes, invites, turn events, challenges
/// and game activities (iOS splits it into GKSavedGameListener, GKInviteEventListener, GKTurnBasedEventListener,
/// GKChallengeListener and GKGameActivityListener; on isim those names are aliases of this protocol).
public protocol GKLocalPlayerListener: AnyObject {
    func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame])
    func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame)
    func player(_ player: GKPlayer, didAccept invite: GKInvite)
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer])
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool)
    func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge)
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch)
    func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch)
    func player(_ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer])
    func player(_ player: GKPlayer, didReceive challenge: GKChallenge)
    func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer)
    func player(_ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge, byFriend friendPlayer: GKPlayer)
    @available(iOS 26.0, *)
    func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping (Bool) -> Void)
}
extension GKLocalPlayerListener {
    public func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {}
    public func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame) {}
    public func player(_ player: GKPlayer, didAccept invite: GKInvite) {}
    public func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {}
    public func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {}
    public func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {}
    public func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {}
    public func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch) {}
    public func player(_ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer]) {}
    public func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {}
    public func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer) {}
    public func player(_ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge, byFriend friendPlayer: GKPlayer) {}
    @available(iOS 26.0, *)
    public func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping (Bool) -> Void) { completionHandler(false) }
}

// MARK: - Saved games

/// Saved games live in the device data ($ISIM_DATA/Library/GameCenter/<bundle id>/SavedGames), like
/// iCloud-backed Game Center saves outlive the app's container. A name with several versions (from
/// different devices: `isim gamecenter <app> conflict <name>`) is a conflict to resolve.
open class GKSavedGame: NSObject, @unchecked Sendable {
    public let name: String?
    public let deviceName: String?
    public let modificationDate: Date?
    let file: String
    init(name: String, deviceName: String, date: Date, file: String) { self.name = name; self.deviceName = deviceName; modificationDate = date; self.file = file }
    open func loadData(completionHandler handler: ((Data?, Error?) -> Void)? = nil) {
        let d = FileManager.default.contents(atPath: (_GCSaves.dir(name ?? "") as NSString).appendingPathComponent(file))
        DispatchQueue.main.async { handler?(d, d == nil ? GKError(code: .unknown) : nil) }
    }
    open func loadData() async throws -> Data {
        try await withCheckedThrowingContinuation { k in loadData { d, e in if let d { k.resume(returning: d) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
}

enum _GCSaves {
    static var root: String {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return (data as NSString).appendingPathComponent("Library/GameCenter/\(Bundle.main.bundleIdentifier ?? "app")/SavedGames")
    }
    static func dir(_ name: String) -> String { (root as NSString).appendingPathComponent(name.replacingOccurrences(of: "/", with: "_")) }
    static func versions(_ name: String) -> [[String: Any]] {
        guard let d = FileManager.default.contents(atPath: (dir(name) as NSString).appendingPathComponent("versions.json")) else { return [] }
        return (try? JSONSerialization.jsonObject(with: d)) as? [[String: Any]] ?? []
    }
    static func write(_ name: String, _ v: [[String: Any]]) {
        try? FileManager.default.createDirectory(atPath: dir(name), withIntermediateDirectories: true, attributes: nil)
        if let d = try? JSONSerialization.data(withJSONObject: v, options: [.prettyPrinted]) {
            try? d.write(to: URL(fileURLWithPath: (dir(name) as NSString).appendingPathComponent("versions.json")), options: .atomic)
        }
    }
    static func game(_ v: [String: Any]) -> GKSavedGame {
        GKSavedGame(name: v["name"] as? String ?? "", deviceName: v["deviceName"] as? String ?? "", date: Date(timeIntervalSince1970: v["modificationDate"] as? Double ?? 0), file: v["file"] as? String ?? "")
    }
    static var deviceName: String { MainActor.assumeIsolated { UIDevice.current.name } }
    static func store(_ data: Data, name: String, replacing: (([String: Any]) -> Bool)) -> GKSavedGame {
        let file = "\(UUID().uuidString).data"
        try? FileManager.default.createDirectory(atPath: dir(name), withIntermediateDirectories: true, attributes: nil)
        FileManager.default.createFile(atPath: (dir(name) as NSString).appendingPathComponent(file), contents: data, attributes: nil)
        var vs = versions(name)
        for v in vs where replacing(v) { try? FileManager.default.removeItem(atPath: (dir(name) as NSString).appendingPathComponent(v["file"] as? String ?? "-")) }
        vs.removeAll(where: replacing)
        let v: [String: Any] = ["name": name, "deviceName": deviceName, "modificationDate": Date().timeIntervalSince1970, "file": file]
        vs.append(v)
        write(name, vs)
        return game(v)
    }
}

extension GKLocalPlayer {
    /// Saves (or replaces this device's version of) a saved game.
    public func saveGameData(_ data: Data, withName name: String, completionHandler handler: ((GKSavedGame?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { handler?(nil, GKError.notAuthenticated) }; return }
        let dev = _GCSaves.deviceName
        let g = _GCSaves.store(data, name: name) { ($0["deviceName"] as? String) == dev }
        NSLog("isim GameKit: saved game \"%@\" (%ld bytes)", name, data.count)
        DispatchQueue.main.async { MainActor.assumeIsolated { for l in self.listeners { l.player(self, didModifySavedGame: g) } }; handler?(g, nil) }
    }
    public func saveGameData(_ data: Data, withName name: String) async throws -> GKSavedGame {
        try await withCheckedThrowingContinuation { k in saveGameData(data, withName: name) { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// All saved games; a name listed more than once is a conflict (listeners are told).
    public func fetchSavedGames(completionHandler handler: (([GKSavedGame]?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { handler?(nil, GKError.notAuthenticated) }; return }
        let names = (try? FileManager.default.contentsOfDirectory(atPath: _GCSaves.root)) ?? []
        var all: [GKSavedGame] = []
        var conflicts: [[GKSavedGame]] = []
        for n in names.sorted() {
            let gs = _GCSaves.versions(n).map(_GCSaves.game)
            all += gs
            if gs.count > 1 { conflicts.append(gs) }
        }
        DispatchQueue.main.async {
            handler?(all, nil)
            MainActor.assumeIsolated { for c in conflicts { for l in self.listeners { l.player(self, hasConflictingSavedGames: c) } } }
        }
    }
    public func fetchSavedGames() async throws -> [GKSavedGame] {
        try await withCheckedThrowingContinuation { k in fetchSavedGames { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    public func deleteSavedGames(withName name: String, completionHandler handler: ((Error?) -> Void)? = nil) {
        try? FileManager.default.removeItem(atPath: _GCSaves.dir(name))
        NSLog("isim GameKit: deleted saved game \"%@\"", name)
        DispatchQueue.main.async { handler?(nil) }
    }
    public func deleteSavedGames(withName name: String) async throws { deleteSavedGames(withName: name, completionHandler: nil) }
    /// Replaces the conflicting versions with one saved game holding `data`.
    public func resolveConflictingSavedGames(_ conflictingSavedGames: [GKSavedGame], with data: Data, completionHandler handler: (([GKSavedGame]?, Error?) -> Void)? = nil) {
        let names = Set(conflictingSavedGames.compactMap { $0.name })
        let files = Set(conflictingSavedGames.map { $0.file })
        let result = names.sorted().map { n in _GCSaves.store(data, name: n) { files.contains($0["file"] as? String ?? "") } }
        NSLog("isim GameKit: resolved saved-game conflict (%@)", names.sorted().joined(separator: ", "))
        DispatchQueue.main.async { handler?(result, nil) }
    }
    public func resolveConflictingSavedGames(_ conflictingSavedGames: [GKSavedGame], with data: Data) async throws -> [GKSavedGame] {
        try await withCheckedThrowingContinuation { k in resolveConflictingSavedGames(conflictingSavedGames, with: data) { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
}

// MARK: - Friend requests

public protocol GKFriendRequestComposeViewControllerDelegate: AnyObject {
    func friendRequestComposeViewControllerDidFinish(_ viewController: GKFriendRequestComposeViewController)
}

/// The friend request composer: the request goes to the player with that nickname on isim's local Game Center
/// network (test players accept at once; a device's player accepts in Settings > Game Center).
open class GKFriendRequestComposeViewController: UINavigationControllerStandIn {
    weak open var composeViewDelegate: GKFriendRequestComposeViewControllerDelegate?
    var recipients: [String] = []
    var message = ""
    public class func maxNumberOfRecipients() -> Int { 1 }
    open func setMessage(_ message: String?) { self.message = message ?? "" }
    open func addRecipients(withEmailAddresses emailAddresses: [String]) { recipients += emailAddresses }
    open func addRecipients(withPhoneNumbers phoneNumbers: [String]) { recipients += phoneNumbers }
    open func addRecipientPlayers(_ players: [GKPlayer]) { recipients += players.map { $0.alias } }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        embed(_GCFriendRequestView(to: recipients.joined(separator: ", "), message: message) { [weak self] sent, to, text in
            guard let self else { return }
            if sent { for r in to.split(separator: ",") { _GCSocial.sendRequest(to: String(r), message: text) } } else { NSLog("isim GameKit: friend request cancelled") }
            if let d = self.composeViewDelegate { d.friendRequestComposeViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

/// A plain view controller hosting SwiftUI content (GameKit's controllers are UINavigationControllers on iOS).
open class UINavigationControllerStandIn: UIViewController {
    // Game Center UI: the access point hides while it is on screen
    open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); GKAccessPoint.shared.setPresenting(true) }
    // like iOS, the keyboard goes away with the sheet
    open override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); view.endEditing(true) }
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { GKAccessPoint.shared.setPresenting(false) }
    }
    func embed<V: View>(_ v: V) {
        let host = UIHostingController(rootView: v)
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

struct _GCFriendRequestView: View {
    @State var to: String
    @State var message: String
    let done: (Bool, String, String) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Text(verbatim: "To:").foregroundStyle(.secondary)
                        TextField("Email, phone or nickname", text: $to).accessibilityIdentifier("gc-friend-to")
                    }
                    TextField("Message", text: $message).accessibilityIdentifier("gc-friend-message")
                } footer: {
                    Text(verbatim: "The request goes to the player with this nickname on isim’s local Game Center (the other isim devices and test players on this computer).")
                        .accessibilityIdentifier("gc-friend-note")
                }
            }
            .navigationTitle("Friend Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(false, "", "") }.accessibilityIdentifier("gc-friend-cancel") }
                ToolbarItem(placement: .confirmationAction) { Button("Send") { done(true, to, message) }.disabled(to.isEmpty).accessibilityIdentifier("gc-friend-send") }
            }
        }
    }
}
