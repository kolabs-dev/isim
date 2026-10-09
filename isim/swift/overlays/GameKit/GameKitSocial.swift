// isim GameKit, the social parts of the local Game Center network (GameCenterNetwork.swift): friends (with the
// friends-list permission prompt), friend requests, challenges, and the events other players send (invites, turns,
// challenges, game activities), delivered to the GKLocalPlayerListeners on the main queue.
import UIKit
import SwiftUI

// MARK: - Friends

enum _GCSocial {
    static let statusKey = "_ISIMGameCenterFriendsAuthorization"
    static var status: GKLocalPlayer.FriendsAuthorizationStatus {
        GKLocalPlayer.FriendsAuthorizationStatus(rawValue: UserDefaults.standard.integer(forKey: statusKey)) ?? .notDetermined
    }
    static func friends(_ ids: [String]?) -> [GKPlayer] {
        let all = _GCNet.friendIDs()
        let chosen = ids.map { want in all.filter { id in want.contains("A:_\(id)") || want.contains("T:_\(id)") } } ?? all
        return chosen.map(GKPlayer._make).sorted { $0.alias < $1.alias }
    }
    /// Like iOS 14.5+: the app needs NSGKFriendListUsageDescription, and the player is asked once per app
    /// ("Don't Allow" / "OK"; ISIM_GAMECENTER_FRIENDS_PERMISSION=allow|deny answers without asking).
    static func loadFriends(_ ids: [String]?, _ h: @escaping ([GKPlayer]?, Error?) -> Void) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard GKLocalPlayer.local.isAuthenticated else { h(nil, GKError.notAuthenticated); return }
                let usage = Bundle.main.object(forInfoDictionaryKey: "NSGKFriendListUsageDescription") as? String ?? ""
                guard !usage.isEmpty else {
                    NSLog("isim GameKit: loadFriends needs NSGKFriendListUsageDescription in the app's Info.plist")
                    h(nil, GKError(code: .friendListDescriptionMissing)); return
                }
                func answer(_ s: GKLocalPlayer.FriendsAuthorizationStatus) {
                    UserDefaults.standard.set(s.rawValue, forKey: statusKey)
                    if s == .authorized { let f = friends(ids); NSLog("isim GameKit: %ld friends", f.count); h(f, nil) }
                    else { h(nil, GKError(code: .friendListDenied)) }
                }
                switch status {
                case .authorized, .denied, .restricted: answer(status)
                case .notDetermined:
                    if let v = ProcessInfo.processInfo.environment["ISIM_GAMECENTER_FRIENDS_PERMISSION"]?.lowercased(), !v.isEmpty {
                        answer(v.hasPrefix("allow") || v == "ok" || v == "yes" ? .authorized : .denied); return
                    }
                    let a = UIAlertController(title: "Allow “\(_GCApp.name)” to access your Game Center friends?", message: usage, preferredStyle: .alert)
                    a.addAction(UIAlertAction(title: "Don’t Allow", style: .cancel) { _ in answer(.denied) })
                    a.addAction(UIAlertAction(title: "OK", style: .default) { _ in answer(.authorized) })
                    guard var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController else { answer(.denied); return }
                    while let p = top.presentedViewController { top = p }
                    NSLog("isim GameKit: asking for access to the friends list")
                    top.present(a, animated: true, completion: nil)
                @unknown default: answer(.denied)
                }
            }
        }
    }
    /// A friend request to the player with this nickname (email addresses and phone numbers: the nickname before
    /// the "@"). Returns the player it went to, or nil.
    @discardableResult
    static func sendRequest(to recipient: String, message: String) -> _GCNet.Player? {
        let name = recipient.split(separator: "@").first.map(String.init)?.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        guard let p = _GCNet.players().first(where: { $0.id != _GCNet.me && $0.alias.lowercased() == name }) else {
            NSLog("isim GameKit: friend request to %@ not sent: no player with that nickname on isim's local Game Center", recipient)
            return nil
        }
        _GCNet.requestFriend(p, message: message)
        NSLog("isim GameKit: friend request sent to %@", p.alias)
        return p
    }
}

// MARK: - Events from other players

public typealias GKChallengeListener = GKLocalPlayerListener
public typealias GKInviteEventListener = GKLocalPlayerListener
public typealias GKTurnBasedEventListener = GKLocalPlayerListener
public typealias GKSavedGameListener = GKLocalPlayerListener

@MainActor enum _GCEvents {
    /// deliveries waiting for a registered listener
    static var waiting: [(GKLocalPlayerListener) -> Void] = []
    static func deliver(_ f: @escaping (GKLocalPlayerListener) -> Void) {
        let ls = GKLocalPlayer.local.listeners
        if ls.isEmpty { waiting.append(f); return }
        for l in ls { f(l) }
    }
    static func flush() {
        let ls = GKLocalPlayer.local.listeners
        guard !ls.isEmpty, !waiting.isEmpty else { return }
        let w = waiting; waiting = []
        for f in w { for l in ls { f(l) } }
    }
    static func install() {
        _GCNet.handlers["friendRequest"] = { e in
            let from = _GCNet.player(e["from"] as? String ?? "")?.alias ?? "A player"
            NSLog("isim GameKit: friend request from %@ (accept in Settings > Game Center)", from)
        }
        _GCNet.handlers["challenge"] = { e in MainActor.assumeIsolated { _GCChallenges.received(e["challenge"] as? String ?? "") } }
        _GCNet.handlers["challengeCompleted"] = { e in MainActor.assumeIsolated { _GCChallenges.completedByFriend(e["challenge"] as? String ?? "") } }
        _GCNet.handlers["activity"] = { e in MainActor.assumeIsolated { _GCActivities.requested(e) } }
        _GCMultiplayer.installHandlers()
    }
}

// MARK: - Challenges

public enum GKChallengeState: Int, Sendable { case invalid = 0, pending = 1, completed = 2, declined = 3 }

/// A score or achievement challenge between friends, kept on the local network (games/<bundle id>/challenges).
open class GKChallenge: NSObject {
    var _id = ""
    var _rec: [String: Any] = [:]
    static func _make(_ rec: [String: Any]) -> GKChallenge {
        let c: GKChallenge = (rec["kind"] as? String) == "achievement" ? GKAchievementChallenge() : GKScoreChallenge()
        c._id = rec["id"] as? String ?? ""; c._rec = rec
        return c
    }
    open var issuingPlayer: GKPlayer? { (_rec["from"] as? String).map(GKPlayer._make) }
    open var receivingPlayer: GKPlayer? { (_rec["to"] as? String).map(GKPlayer._make) }
    open var state: GKChallengeState { GKChallengeState(rawValue: _rec["state"] as? Int ?? 0) ?? .invalid }
    open var issueDate: Date { Date(timeIntervalSince1970: _rec["issued"] as? Double ?? 0) }
    open var completionDate: Date? { (_rec["completed"] as? Double).map { Date(timeIntervalSince1970: $0) } }
    open var message: String? { _rec["message"] as? String }
    /// The pending challenges other players sent the local player.
    public class func loadReceivedChallenges(completionHandler: (([GKChallenge]?, Error?) -> Void)? = nil) {
        guard GKLocalPlayer.local.isAuthenticated else { DispatchQueue.main.async { completionHandler?(nil, GKError.notAuthenticated) }; return }
        let list = _GCChallenges.all().filter { ($0["to"] as? String) == _GCNet.me && ($0["state"] as? Int) == GKChallengeState.pending.rawValue }
            .sorted { ($0["issued"] as? Double ?? 0) < ($1["issued"] as? Double ?? 0) }.map(GKChallenge._make)
        DispatchQueue.main.async { completionHandler?(list, nil) }
    }
    public class func loadReceivedChallenges() async throws -> [GKChallenge] {
        try await withCheckedThrowingContinuation { k in loadReceivedChallenges { l, e in if let l { k.resume(returning: l) } else { k.resume(throwing: e ?? GKError(code: .unknown)) } } }
    }
    /// Declines a received challenge (the issuer sees it declined).
    open func decline() {
        guard (_rec["to"] as? String) == _GCNet.me, state == .pending else { return }
        _rec = _GCChallenges.set(_id) { $0["state"] = GKChallengeState.declined.rawValue }
        NSLog("isim GameKit: challenge %@ declined", _id)
    }
    open override func isEqual(_ object: Any?) -> Bool { (object as? GKChallenge)?._id == _id }
    open override var hash: Int { _id.hashValue }
}

/// Beat a friend's score on a leaderboard.
open class GKScoreChallenge: GKChallenge {
    open var leaderboardEntry: GKLeaderboard.Entry? {
        guard let board = _rec["board"] as? String, let from = _rec["from"] as? String else { return nil }
        return GKLeaderboard.Entry(player: GKPlayer._make(from), rank: 0, score: _rec["score"] as? Int ?? 0, context: _rec["context"] as? Int ?? 0,
                                   date: issueDate, board: _GCConfig.board(board))
    }
    /// the leaderboard the challenge is on
    open var leaderboardID: String? { _rec["board"] as? String }
}

/// Earn an achievement a friend has.
open class GKAchievementChallenge: GKChallenge {
    open var achievement: GKAchievement? {
        guard let id = _rec["achievement"] as? String else { return nil }
        let a = GKAchievement(identifier: id); a.percentComplete = 100
        return a
    }
}

enum _GCChallenges {
    static var dir: String { _GCNet.gamePath("challenges") }
    static func file(_ id: String) -> String { (dir as NSString).appendingPathComponent("\(id).json") }
    static func all() -> [[String: Any]] { _GCNet.list(dir).filter { $0.hasSuffix(".json") }.compactMap { _GCNet.readDict((dir as NSString).appendingPathComponent($0)) } }
    @discardableResult
    static func set(_ id: String, _ body: @escaping (inout [String: Any]) -> Void) -> [String: Any] {
        _GCNet.update(file(id)) { d in guard !d.isEmpty else { return false }; body(&d); return true }
    }
    /// Sends a challenge to each player (score: beat `score` on `board`; achievement: earn `achievement`).
    @MainActor static func issue(_ base: [String: Any], to players: [GKPlayer], message: String?) {
        for p in players {
            let id = UUID().uuidString
            var rec = base
            rec["id"] = id; rec["from"] = _GCNet.me; rec["to"] = p._id; rec["state"] = GKChallengeState.pending.rawValue
            rec["issued"] = Date().timeIntervalSince1970; rec["message"] = message ?? ""
            _GCNet.write(file(id), rec)
            _GCNet.post(p._id, ["kind": "challenge", "challenge": id])
            NSLog("isim GameKit: %@ challenge sent to %@", base["kind"] as? String ?? "", p.alias)
        }
    }
    /// A challenge arrived: listeners get `didReceive`; tapping the banner is `wantsToPlay`.
    @MainActor static func received(_ id: String) {
        guard let rec = _GCNet.readDict(file(id)) else { return }
        let c = GKChallenge._make(rec)
        let from = c.issuingPlayer?.alias ?? "A friend"
        let what = (rec["kind"] as? String) == "achievement"
            ? "Earn “\(_GCText.title(rec["achievement"] as? String ?? ""))”"
            : "Beat \(_GCConfig.board(rec["board"] as? String ?? "").formatted(rec["score"] as? Int ?? 0)) on \(_GCConfig.board(rec["board"] as? String ?? "").title)"
        NSLog("isim GameKit: challenge from %@: %@", from, what)
        _GCEvents.deliver { l in l.player(GKLocalPlayer.local, didReceive: c) }
        _GCBanner.show(title: "\(from) challenged you", subtitle: what, kind: .other(from)) {
            _GCEvents.deliver { l in l.player(GKLocalPlayer.local, wantsToPlay: c) }
        }
    }
    /// the issuer's side: a friend completed a challenge we sent
    @MainActor static func completedByFriend(_ id: String) {
        guard let rec = _GCNet.readDict(file(id)) else { return }
        let c = GKChallenge._make(rec)
        guard let friend = c.receivingPlayer else { return }
        NSLog("isim GameKit: %@ completed your challenge", friend.alias)
        _GCEvents.deliver { l in l.player(GKLocalPlayer.local, issuedChallengeWasCompleted: c, byFriend: friend) }
    }
    @MainActor static func complete(_ rec: [String: Any]) {
        let id = rec["id"] as? String ?? ""
        let done = set(id) { $0["state"] = GKChallengeState.completed.rawValue; $0["completed"] = Date().timeIntervalSince1970 }
        let c = GKChallenge._make(done)
        let issuer = c.issuingPlayer ?? GKLocalPlayer.local
        NSLog("isim GameKit: challenge from %@ completed", issuer.alias)
        if let from = rec["from"] as? String { _GCNet.post(from, ["kind": "challengeCompleted", "challenge": id]) }
        _GCEvents.deliver { l in l.player(GKLocalPlayer.local, didComplete: c, issuedByFriend: issuer) }
        _GCBanner.show(title: "Challenge Completed", subtitle: "You beat \(issuer.alias)’s challenge", kind: .other(issuer.alias))
    }
    private static func pending(_ kind: String) -> [[String: Any]] {
        all().filter { ($0["to"] as? String) == _GCNet.me && ($0["kind"] as? String) == kind && ($0["state"] as? Int) == GKChallengeState.pending.rawValue }
    }
    /// a submitted score completes the pending score challenges it beats
    static func scoreSubmitted(_ score: Int, board: String) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                let low = _GCConfig.board(board).sortLow
                for r in pending("score") where (r["board"] as? String) == board {
                    let target = r["score"] as? Int ?? 0
                    if low ? score < target : score > target { complete(r) }
                }
            }
        }
    }
    static func achievementCompleted(_ id: String) {
        DispatchQueue.main.async {
            MainActor.assumeIsolated { for r in pending("achievement") where (r["achievement"] as? String) == id { complete(r) } }
        }
    }
}

public typealias GKChallengeComposeHandler = (UIViewController, Bool, [GKPlayer]?) -> Void

extension GKLeaderboard.Entry {
    /// The challenge composer for this score: pick friends and a message; Send challenges them to beat it.
    @MainActor public func challengeComposeController(withMessage message: String?, players: [GKPlayer]?, completion completionHandler: GKChallengeComposeHandler? = nil) -> UIViewController {
        let base: [String: Any] = ["kind": "score", "board": board.id, "score": score, "context": context]
        return _GCChallengeComposeController(base: base, title: "Beat \(formattedScore) on \(board.title)", message: message, players: players ?? [], done: completionHandler)
    }
}

extension GKAchievement {
    /// The challenge composer for this achievement: Send challenges the friends to earn it.
    @MainActor public func challengeComposeController(withMessage message: String?, players: [GKPlayer]?, completion completionHandler: GKChallengeComposeHandler? = nil) -> UIViewController {
        _GCChallengeComposeController(base: ["kind": "achievement", "achievement": identifier], title: "Earn “\(_GCText.title(identifier))”",
                                      message: message, players: players ?? [], done: completionHandler)
    }
    /// Challenges players to earn this achievement without showing the composer.
    public func issueChallenge(toPlayers playerIDs: [GKPlayer]?, message: String?) {
        let id = identifier
        DispatchQueue.main.async { MainActor.assumeIsolated { _GCChallenges.issue(["kind": "achievement", "achievement": id], to: playerIDs ?? [], message: message) } }
    }
}

final class _GCChallengeComposeController: UINavigationControllerStandIn {
    let base: [String: Any], what: String, message: String?, players: [GKPlayer], done: GKChallengeComposeHandler?
    init(base: [String: Any], title: String, message: String?, players: [GKPlayer], done: GKChallengeComposeHandler?) {
        self.base = base; what = title; self.message = message; self.players = players; self.done = done
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        let friends = _GCNet.friendIDs().map(GKPlayer._make).sorted { $0.alias < $1.alias }
        embed(_GCChallengeComposeView(what: what, message: message ?? "", friends: friends, chosen: Set(players.map { $0._id })) { [weak self] sent, ids, text in
            guard let self else { return }
            let chosen = friends.filter { ids.contains($0._id) }
            if sent { _GCChallenges.issue(self.base, to: chosen, message: text) } else { NSLog("isim GameKit: challenge cancelled") }
            if let d = self.done { d(self, sent, sent ? chosen : nil) } else { self.dismiss(animated: true, completion: nil) }
        })
    }
}

struct _GCChallengeComposeView: View {
    let what: String
    @State var message: String
    let friends: [GKPlayer]
    @State var chosen: Set<String>
    let done: (Bool, Set<String>, String) -> Void
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: what).font(.system(size: 15, weight: .semibold)).accessibilityIdentifier("gc-challenge-what")
                    TextField("Message", text: $message).accessibilityIdentifier("gc-challenge-message")
                }
                Section {
                    if friends.isEmpty { Text(verbatim: "No friends to challenge yet.").foregroundStyle(.secondary) }
                    ForEach(friends, id: \._id) { f in
                        Button {
                            if chosen.contains(f._id) { chosen.remove(f._id) } else { chosen.insert(f._id) }
                        } label: {
                            HStack(spacing: 12) {
                                _GCAvatar(name: f.alias, size: 36)
                                Text(verbatim: f.alias).foregroundStyle(.primary)
                                Spacer()
                                if chosen.contains(f._id) { Image(systemName: "checkmark").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.accentColor) }
                            }
                        }
                        .accessibilityIdentifier("gc-challenge-friend-\(f.alias)")
                    }
                } header: { Text(verbatim: "Friends") }
            }
            .navigationTitle("Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { done(false, [], message) }.accessibilityIdentifier("gc-challenge-cancel") }
                ToolbarItem(placement: .confirmationAction) { Button("Send") { done(true, chosen, message) }.disabled(chosen.isEmpty).accessibilityIdentifier("gc-challenge-send") }
            }
        }
    }
}
