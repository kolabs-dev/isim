// isim GameKit, continued: achievement descriptions and leaderboard sets (from isim-GameCenter.json),
// saved games (stored in the device data, with conflicts), the local player's listener, and the friend
// request composer (the request goes to the player with that nickname on isim's local Game Center network).
import UIKit
import SwiftUI

// MARK: - Achievement descriptions

@objc(GKAchievementDescription) open class GKAchievementDescription: NSObject {
    @objc public let identifier: String
    @objc public let groupIdentifier: String?
    @objc public let title: String
    @objc public let achievedDescription: String
    @objc public let unachievedDescription: String
    @objc public let maximumPoints: Int
    @objc public let isHidden: Bool
    @objc public let isReplayable: Bool
    @objc public var rarityPercent: NSNumber? { nil }
    @available(iOS 18.4, *) public var releaseState: GKReleaseState { .of(_def?.prereleased ?? false) }
    @available(iOS 18.4, *) @objc(releaseState) var _isimReleaseState: UInt { releaseState.rawValue }
    init(_ d: _GCAchievementDef) {
        identifier = d.id; groupIdentifier = d.group; title = d.title; achievedDescription = d.achieved; unachievedDescription = d.unachieved
        maximumPoints = d.points; isHidden = d.hidden; isReplayable = d.replayable
    }
    /// From the app's isim-GameCenter.json (App Store Connect metadata isn't available locally).
    @objc public class func loadAchievementDescriptions(completionHandler: (([GKAchievementDescription]?, Error?) -> Void)? = nil) {
        let list = _GCConfig.achievements.map(GKAchievementDescription.init)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    @nonobjc public class func loadAchievementDescriptions() async throws -> [GKAchievementDescription] { _GCConfig.achievements.map(GKAchievementDescription.init) }
    @objc open func loadImage(completionHandler: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.achievement(identifier, completed: true)
        DispatchQueue.main.async { completionHandler?(img, nil) }
    }
    @nonobjc open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.achievement(identifier, completed: true) else { throw GKError._unsupported }
        return i
    }
    @objc public class func incompleteAchievementImage() -> UIImage { _GCImages.achievement("", completed: false) ?? UIImage() }
    @objc public class func placeholderCompletedAchievementImage() -> UIImage { _GCImages.achievement("", completed: true) ?? UIImage() }
}

// MARK: - Leaderboard sets

@objc(GKLeaderboardSet) open class GKLeaderboardSet: NSObject {
    @objc open var title: String
    @objc open var identifier: String?
    @objc open var groupIdentifier: String?
    @objc let boards: [String]
    init(_ d: _GCSetDef) { title = d.title; identifier = d.id; boards = d.boards }
    @objc public class func loadLeaderboardSets(completionHandler: (([GKLeaderboardSet]?, Error?) -> Void)? = nil) {
        let list = _GCConfig.sets.map(GKLeaderboardSet.init)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    @nonobjc public class func loadLeaderboardSets() async throws -> [GKLeaderboardSet] { _GCConfig.sets.map(GKLeaderboardSet.init) }
    @objc open func loadLeaderboards(handler: @escaping ([GKLeaderboard]?, Error?) -> Void) {
        let list = boards.map { GKLeaderboard.make($0) }
        DispatchQueue.main.async { handler(list, nil) }
    }
    @nonobjc open func loadLeaderboards() async throws -> [GKLeaderboard] { boards.map { GKLeaderboard.make($0) } }
    /// The set's image from the configuration (a file or asset in the bundle), or a generated placeholder.
    @objc open func loadImage(completionHandler: ((UIImage?, Error?) -> Void)? = nil) {
        let img = _GCImages.set(identifier ?? "")
        DispatchQueue.main.async { completionHandler?(img, nil) }
    }
    @nonobjc open func loadImage() async throws -> UIImage {
        guard let i = _GCImages.set(identifier ?? "") else { throw GKError._unsupported }
        return i
    }
}

// MARK: - Listeners

/// Saved-game changes from other devices.
@objc(GKSavedGameListener) public protocol GKSavedGameListener: NSObjectProtocol {
    @objc(player:didModifySavedGame:) optional func player(_ player: GKPlayer, didModifySavedGame savedGame: GKSavedGame)
    @objc(player:hasConflictingSavedGames:) optional func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame])
}
/// Invites the player accepted, and match requests from the Games app or Contacts.
@objc(GKInviteEventListener) public protocol GKInviteEventListener: NSObjectProtocol {
    @objc(player:didAcceptInvite:) optional func player(_ player: GKPlayer, didAccept invite: GKInvite)
    @objc(player:didRequestMatchWithRecipients:) optional func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer])
}
/// Turn-based match events: turns, ended matches, quit requests and exchanges.
@objc(GKTurnBasedEventListener) public protocol GKTurnBasedEventListener: NSObjectProtocol {
    @objc(player:didRequestMatchWithOtherPlayers:) optional func player(_ player: GKPlayer, didRequestMatchWithOtherPlayers playersToInvite: [GKPlayer])
    @objc(player:receivedTurnEventForMatch:didBecomeActive:)
    optional func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool)
    @objc(player:matchEnded:) optional func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch)
    @objc(player:receivedExchangeRequest:forMatch:)
    optional func player(_ player: GKPlayer, receivedExchangeRequest exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch)
    @objc(player:receivedExchangeCancellation:forMatch:)
    optional func player(_ player: GKPlayer, receivedExchangeCancellation exchange: GKTurnBasedExchange, for match: GKTurnBasedMatch)
    @objc(player:receivedExchangeReplies:forCompletedExchange:forMatch:)
    optional func player(_ player: GKPlayer, receivedExchangeReplies replies: [GKTurnBasedExchangeReply], forCompletedExchange exchange: GKTurnBasedExchange,
                         for match: GKTurnBasedMatch)
    @objc(player:wantsToQuitMatch:) optional func player(_ player: GKPlayer, wantsToQuitMatch match: GKTurnBasedMatch)
}
/// Challenges received, accepted and completed.
@objc(GKChallengeListener) public protocol GKChallengeListener: NSObjectProtocol {
    @objc(player:wantsToPlayChallenge:) optional func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge)
    @objc(player:didReceiveChallenge:) optional func player(_ player: GKPlayer, didReceive challenge: GKChallenge)
    @objc(player:didCompleteChallenge:issuedByFriend:) optional func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer)
    @objc(player:issuedChallengeWasCompleted:byFriend:)
    optional func player(_ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge, byFriend friendPlayer: GKPlayer)
}
/// Game activities the player starts from the Games app (iOS 26).
@objc(GKGameActivityListener) public protocol GKGameActivityListener: NSObjectProtocol {
    @available(iOS 26.0, *)
    @objc(player:wantsToPlayGameActivity:completionHandler:)
    optional func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping (Bool) -> Void)
}
/// Everything other players and the system tell the game; register one with GKLocalPlayer.register(_:).
@objc(GKLocalPlayerListener) public protocol GKLocalPlayerListener: GKChallengeListener, GKInviteEventListener, GKSavedGameListener,
                                                                     GKTurnBasedEventListener, GKGameActivityListener {}

// MARK: - Saved games

/// Saved games live in the device data ($ISIM_DATA/Library/GameCenter/<bundle id>/SavedGames), like
/// iCloud-backed Game Center saves outlive the app's container. A name with several versions (from
/// different devices: `isim gamecenter <app> conflict <name>`) is a conflict to resolve.
@objc(GKSavedGame) open class GKSavedGame: NSObject, @unchecked Sendable {
    @objc public let name: String?
    @objc public let deviceName: String?
    @objc public let modificationDate: Date?
    @objc let file: String
    @objc init(name: String, deviceName: String, date: Date, file: String) { self.name = name; self.deviceName = deviceName; modificationDate = date; self.file = file }
    @objc open func loadData(completionHandler handler: ((Data?, Error?) -> Void)? = nil) {
        let d = FileManager.default.contents(atPath: (_GCSaves.dir(name ?? "") as NSString).appendingPathComponent(file))
        DispatchQueue.main.async { handler?(d, d == nil ? GKError(code: .unknown) : nil) }
    }
    @nonobjc open func loadData() async throws -> Data {
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
    @objc public func saveGameData(_ data: Data, withName name: String, completionHandler handler: ((GKSavedGame?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { handler?(nil, GKError._notAuthenticated) }; return }
        let dev = _GCSaves.deviceName
        let g = _GCSaves.store(data, name: name) { ($0["deviceName"] as? String) == dev }
        NSLog("isim GameKit: saved game \"%@\" (%ld bytes)", name, data.count)
        DispatchQueue.main.async { MainActor.assumeIsolated { for l in self.listeners { l.player?(self, didModifySavedGame: g) } }; handler?(g, nil) }
    }
    @nonobjc public func saveGameData(_ data: Data, withName name: String) async throws -> GKSavedGame {
        try await withCheckedThrowingContinuation { k in saveGameData(data, withName: name) { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// All saved games; a name listed more than once is a conflict (listeners are told).
    @objc public func fetchSavedGames(completionHandler handler: (([GKSavedGame]?, Error?) -> Void)? = nil) {
        guard isAuthenticated else { DispatchQueue.main.async { handler?(nil, GKError._notAuthenticated) }; return }
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
            MainActor.assumeIsolated { for c in conflicts { for l in self.listeners { l.player?(self, hasConflictingSavedGames: c) } } }
        }
    }
    @nonobjc public func fetchSavedGames() async throws -> [GKSavedGame] {
        try await withCheckedThrowingContinuation { k in fetchSavedGames { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    @objc public func deleteSavedGames(withName name: String, completionHandler handler: ((Error?) -> Void)? = nil) {
        try? FileManager.default.removeItem(atPath: _GCSaves.dir(name))
        NSLog("isim GameKit: deleted saved game \"%@\"", name)
        DispatchQueue.main.async { handler?(nil) }
    }
    @nonobjc public func deleteSavedGames(withName name: String) async throws { deleteSavedGames(withName: name, completionHandler: nil) }
    /// Replaces the conflicting versions with one saved game holding `data`.
    @objc(resolveConflictingSavedGames:withData:completionHandler:) public func resolveConflictingSavedGames(_ conflictingSavedGames: [GKSavedGame], with data: Data, completionHandler handler: (([GKSavedGame]?, Error?) -> Void)? = nil) {
        let names = Set(conflictingSavedGames.compactMap { $0.name })
        let files = Set(conflictingSavedGames.map { $0.file })
        let result = names.sorted().map { n in _GCSaves.store(data, name: n) { files.contains($0["file"] as? String ?? "") } }
        NSLog("isim GameKit: resolved saved-game conflict (%@)", names.sorted().joined(separator: ", "))
        DispatchQueue.main.async { handler?(result, nil) }
    }
    @nonobjc public func resolveConflictingSavedGames(_ conflictingSavedGames: [GKSavedGame], with data: Data) async throws -> [GKSavedGame] {
        try await withCheckedThrowingContinuation { k in resolveConflictingSavedGames(conflictingSavedGames, with: data) { g, e in if let g { k.resume(returning: g) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
}

// MARK: - Friend requests

public protocol GKFriendRequestComposeViewControllerDelegate: AnyObject {
    func friendRequestComposeViewControllerDidFinish(_ viewController: GKFriendRequestComposeViewController)
}

/// The friend request composer: the request goes to the player with that nickname on isim's local Game Center
/// network (test players accept at once; a device's player accepts in Settings > Game Center).
@objc(GKFriendRequestComposeViewController) open class GKFriendRequestComposeViewController: UINavigationController {
    weak open var composeViewDelegate: GKFriendRequestComposeViewControllerDelegate?
    @objc var recipients: [String] = []
    @objc var _message = ""
    @objc public class func maxNumberOfRecipients() -> Int { 1 }
    @objc open func setMessage(_ message: String?) { self._message = message ?? "" }
    @objc open func addRecipients(withEmailAddresses emailAddresses: [String]) { recipients += emailAddresses }
    @objc open func addRecipients(withPhoneNumbers phoneNumbers: [String]) { recipients += phoneNumbers }
    @objc open func addRecipientPlayers(_ players: [GKPlayer]) { recipients += players.map { $0.alias } }
    @objc open override func viewWillAppear(_ animated: Bool) { super.viewWillAppear(animated); _gcSheetWillAppear() }
    @objc open override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); _gcSheetWillDisappear() }
    @objc open override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); _gcSheetDidDisappear() }
    @objc open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        _gcEmbed(_GCFriendRequestView(to: recipients.joined(separator: ", "), message: _message) { [weak self] sent, to, text in
            guard let self else { return }
            if sent { for r in to.split(separator: ",") { _GCSocial.sendRequest(to: String(r), message: text) } } else { NSLog("isim GameKit: friend request cancelled") }
            if let d = self.composeViewDelegate { d.friendRequestComposeViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

/// GameKit's sheets (the matchmakers, the friend request and challenge composers) are UINavigationControllers, as on
/// iOS: their root is the SwiftUI content, whose NavigationStack title and toolbar go to this controller's bar. While
/// one is on screen the access point hides, and like iOS the keyboard goes away with the sheet.
extension UINavigationController {
    func _gcEmbed<V: View>(_ v: V) {
        setViewControllers([UIHostingController(rootView: v)], animated: false)
    }
    func _gcSheetWillAppear() { GKAccessPoint.shared.setPresenting(true) }
    func _gcSheetWillDisappear() { view.endEditing(true) }
    func _gcSheetDidDisappear() { if presentingViewController == nil { GKAccessPoint.shared.setPresenting(false) } }
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
