// isim GameKit, continued: achievement descriptions and leaderboard sets (from isim-GameCenter.json),
// saved games (stored in the device data, with conflicts), the friend request composer, and the
// matchmaking UI. isim's Game Center is local and has one player: the friend request is not sent,
// matchmaking finds nobody (no real-time or turn-based matches), challenges and invites never arrive.
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
    open func loadImage(completionHandler: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.bundleImage(_GCConfig.sets.first { $0.id == identifier }?.image) ?? _GCImages.leaderboard(identifier ?? "set")
        DispatchQueue.main.async { completionHandler?(img, nil) }
    }
}

// MARK: - Listener

public protocol GKLocalPlayerListener: AnyObject {
    func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame])
    func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame)
    func player(_ player: GKPlayer, didAccept invite: GKInvite)
    func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer])
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool)
    func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge)
}
extension GKLocalPlayerListener {
    public func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {}
    public func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame) {}
    public func player(_ player: GKPlayer, didAccept invite: GKInvite) {}
    public func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {}
    public func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {}
    public func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {}
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

/// The friend request composer. isim's Game Center is local: the request is not sent anywhere.
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
        embed(_GCFriendRequestView(to: recipients.joined(separator: ", "), message: message) { [weak self] sent, to in
            guard let self else { return }
            NSLog(sent ? "isim GameKit: friend request to %@ not sent (isim's Game Center is local)" : "isim GameKit: friend request cancelled%@", sent ? to : "")
            if let d = self.composeViewDelegate { d.friendRequestComposeViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

/// A plain view controller hosting SwiftUI content (GameKit's controllers are UINavigationControllers on iOS).
open class UINavigationControllerStandIn: UIViewController {
    // Game Center UI: the access point hides while it is on screen
    open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); GKAccessPoint.shared.setPresenting(true) }
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
    let done: (Bool, String) -> Void
    @State private var sent = false
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
                    Text(verbatim: sent ? "isim’s Game Center is local: the request was not sent." : "Friend requests aren’t delivered on isim: there are no other players.")
                        .accessibilityIdentifier("gc-friend-note")
                }
            }
            .navigationTitle("Friend Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(false, "") }.accessibilityIdentifier("gc-friend-cancel") }
                ToolbarItem(placement: .confirmationAction) { Button("Send") { sent = true; done(true, to) }.disabled(to.isEmpty).accessibilityIdentifier("gc-friend-send") }
            }
        }
    }
}

// MARK: - Matchmaking (no other players on isim)

open class GKMatchRequest: NSObject {
    public enum MatchType: UInt, Sendable { case peerToPeer = 0, hosted = 1, turnBased = 2 }
    open var minPlayers = 2
    open var maxPlayers = 4
    open var defaultNumberOfPlayers = 2
    open var playerGroup = 0
    open var playerAttributes: UInt32 = 0
    open var inviteMessage: String?
    open var recipients: [GKPlayer]?
    open var queueName: String?
    open var properties: [String: Any]?
    open var recipientResponseHandler: ((GKPlayer, Int) -> Void)?
    public class func maxPlayersAllowedForMatch(of matchType: MatchType) -> Int { matchType == .turnBased ? 16 : 4 }
}

public protocol GKMatchDelegate: AnyObject {
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer)
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState)
    func match(_ match: GKMatch, didFailWithError error: Error?)
}
extension GKMatchDelegate {
    public func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {}
    public func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {}
    public func match(_ match: GKMatch, didFailWithError error: Error?) {}
}
public enum GKPlayerConnectionState: Int, Sendable { case unknown = 0, connected = 1, disconnected = 2 }

/// Never created on isim (no other players); declared so games build.
open class GKMatch: NSObject {
    public enum SendDataMode: Int, Sendable { case reliable = 0, unreliable = 1 }
    weak open var delegate: GKMatchDelegate?
    open var players: [GKPlayer] { [] }
    open var expectedPlayerCount: Int { 0 }
    open func send(_ data: Data, to players: [GKPlayer], dataMode mode: SendDataMode) throws { throw GKError.unsupported }
    open func sendData(toAllPlayers data: Data, with mode: SendDataMode) throws { throw GKError.unsupported }
    open func disconnect() {}
}

open class GKMatchmaker: NSObject {
    nonisolated(unsafe) static let instance = GKMatchmaker()
    open class func shared() -> GKMatchmaker { instance }
    /// Fails: isim's local Game Center has no other players to match with.
    open func findMatch(for request: GKMatchRequest, withCompletionHandler h: ((GKMatch?, Error?) -> Void)? = nil) {
        NSLog("isim GameKit: findMatch: no other players on isim's local Game Center")
        DispatchQueue.main.async { h?(nil, GKError.unsupported) }
    }
    open func findMatch(for request: GKMatchRequest) async throws -> GKMatch { throw GKError.unsupported }
    open func findPlayers(forHostedRequest request: GKMatchRequest, withCompletionHandler h: (([GKPlayer]?, Error?) -> Void)? = nil) {
        DispatchQueue.main.async { h?(nil, GKError.unsupported) }
    }
    open func cancel() {}
    open func startBrowsingForNearbyPlayers(handler: ((GKPlayer, Bool) -> Void)? = nil) {}
    open func stopBrowsingForNearbyPlayers() {}
    open func queryActivity(completionHandler: ((Int, Error?) -> Void)? = nil) { DispatchQueue.main.async { completionHandler?(0, nil) } }
}

open class GKInvite: NSObject {
    open var sender: GKPlayer { GKLocalPlayer.local }
    open var isHosted: Bool { false }
    open var playerGroup: Int { 0 }
}

/// Never received on isim (one player); listing returns nothing.
open class GKChallenge: NSObject {
    public class func loadReceivedChallenges(completionHandler: (([GKChallenge]?, Error?) -> Void)? = nil) { DispatchQueue.main.async { completionHandler?([], nil) } }
    open func decline() {}
}

public protocol GKMatchmakerViewControllerDelegate: AnyObject {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController)
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error)
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch)
}
extension GKMatchmakerViewControllerDelegate {
    public func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {}
}

/// The matchmaking sheet: invite players / find players. On isim nobody is found; Cancel closes it.
open class GKMatchmakerViewController: UINavigationControllerStandIn {
    weak open var matchmakerDelegate: GKMatchmakerViewControllerDelegate?
    public let matchRequest: GKMatchRequest
    open var isHosted = false
    open var canStartWithMinimumPlayers = false
    public init?(matchRequest request: GKMatchRequest) { matchRequest = request; super.init(nibName: nil, bundle: nil) }
    public init?(invite: GKInvite) { matchRequest = GKMatchRequest(); super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { matchRequest = GKMatchRequest(); super.init(nibName: nil, bundle: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        NSLog("isim GameKit: matchmaker for %ld-%ld players (no other players on isim)", matchRequest.minPlayers, matchRequest.maxPlayers)
        embed(_GCMatchmakerView(request: matchRequest, turnBased: false) { [weak self] in
            guard let self else { return }
            if let d = self.matchmakerDelegate { d.matchmakerViewControllerWasCancelled(self) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

public protocol GKTurnBasedMatchmakerViewControllerDelegate: AnyObject {
    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController)
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error)
}

open class GKTurnBasedMatchmakerViewController: UINavigationControllerStandIn {
    weak open var turnBasedMatchmakerDelegate: GKTurnBasedMatchmakerViewControllerDelegate?
    public let matchRequest: GKMatchRequest
    open var showExistingMatches = true
    public init(matchRequest request: GKMatchRequest) { matchRequest = request; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { matchRequest = GKMatchRequest(); super.init(nibName: nil, bundle: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        embed(_GCMatchmakerView(request: matchRequest, turnBased: true) { [weak self] in
            guard let self else { return }
            if let d = self.turnBasedMatchmakerDelegate { d.turnBasedMatchmakerViewControllerWasCancelled(self) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

/// Never created on isim; loadMatches returns no matches.
open class GKTurnBasedMatch: NSObject {
    open var matchID: String { "" }
    open var participants: [Any] { [] }
    open var matchData: Data? { nil }
    public class func loadMatches(completionHandler: (([GKTurnBasedMatch]?, Error?) -> Void)? = nil) { DispatchQueue.main.async { completionHandler?([], nil) } }
    public class func loadMatches() async throws -> [GKTurnBasedMatch] { [] }
    public class func find(for request: GKMatchRequest, withCompletionHandler h: @escaping (GKTurnBasedMatch?, Error?) -> Void) { DispatchQueue.main.async { h(nil, GKError.unsupported) } }
}

struct _GCMatchmakerView: View {
    let request: GKMatchRequest, turnBased: Bool, cancel: () -> Void
    @State private var searched = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        _GCAvatar(name: _GC.alias, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: _GC.alias).font(.system(size: 16, weight: .semibold))
                            Text(verbatim: "Ready").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                    ForEach(1..<max(2, request.minPlayers), id: \.self) { i in
                        HStack(spacing: 12) {
                            ZStack { Circle().fill(_GCStyle.fill); Image(systemName: "plus").foregroundStyle(.secondary) }.frame(width: 40, height: 40)
                            Text(verbatim: searched ? "No player found" : "Invite a Player").foregroundStyle(.secondary)
                        }
                        .accessibilityIdentifier("gc-match-slot-\(i)")
                    }
                } header: { Text(verbatim: "\(request.minPlayers)–\(request.maxPlayers) players") } footer: {
                    Text(verbatim: searched ? "No players found: isim’s Game Center is local, with only you on this device."
                                            : "Find players, or invite friends. (isim’s Game Center has no other players.)")
                        .accessibilityIdentifier("gc-match-note")
                }
                Section {
                    Button { searched = true; NSLog("isim GameKit: matchmaking found no players") } label: {
                        Text(verbatim: turnBased ? "Start a New Match" : "Find Players").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("gc-match-find")
                }
            }
            .navigationTitle(turnBased ? "Turn-Based Game" : "Game Center")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() }.accessibilityIdentifier("gc-match-cancel") } }
        }
    }
}
