// Sample: isim's local Game Center — sign-in, the access point, leaderboards (classic, low-is-best with an image,
// recurring with a 6-second period, fixed point) ranked across players, a leaderboard set, achievements with
// descriptions and points from isim-GameCenter.json, the dashboard, player photo, friends (with the permission
// prompt) and the friend request composer, challenges, saved games with a conflict, real-time matches (automatch and
// invites, data between devices), turn-based matches and game activities (iOS 26). The other players are other isim
// devices running this sample, or test players made with `isim gamecenter`. Results are printed for
// tests/ui/test_gamecenter.py.
import SwiftUI
import GameKit

final class Listener: NSObject, GKLocalPlayerListener {
    static let shared = Listener()
    func player(_ player: GKPlayer, hasConflictingSavedGames savedGames: [GKSavedGame]) {
        print("saved games conflict: \(savedGames.count) versions of \(savedGames.first?.name ?? "-") from \(savedGames.compactMap { $0.deviceName }.sorted().joined(separator: ","))")
        GKLocalPlayer.local.resolveConflictingSavedGames(savedGames, with: Data("merged".utf8)) { games, _ in
            print("resolved: \(games?.count ?? 0) saved game")
            games?.first?.loadData { d, _ in print("resolved data: \(d.map { String(decoding: $0, as: UTF8.self) } ?? "-")") }
        }
    }
    func player(_ player: GKPlayer, didReceive challenge: GKChallenge) {
        print("challenge received: \(challenge is GKScoreChallenge ? "score" : "achievement") from \(challenge.issuingPlayer?.alias ?? "-") \"\(challenge.message ?? "")\"")
    }
    func player(_ player: GKPlayer, wantsToPlay challenge: GKChallenge) {
        if let c = challenge as? GKScoreChallenge { print("wants to play challenge: beat \(c.leaderboardEntry?.formattedScore ?? "-")") }
    }
    func player(_ player: GKPlayer, didComplete challenge: GKChallenge, issuedByFriend friendPlayer: GKPlayer) {
        print("challenge completed: issued by \(friendPlayer.alias) state=\(challenge.state.rawValue)")
    }
    func player(_ player: GKPlayer, issuedChallengeWasCompleted challenge: GKChallenge, byFriend friendPlayer: GKPlayer) {
        print("my challenge was completed by \(friendPlayer.alias)")
    }
    func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        print("invite accepted from \(invite.sender.alias)")
        guard let vc = GKMatchmakerViewController(invite: invite) else { return }
        vc.matchmakerDelegate = MatchDelegate.shared
        top().present(vc, animated: true)
    }
    func player(_ player: GKPlayer, receivedTurnEventFor match: GKTurnBasedMatch, didBecomeActive: Bool) {
        Turns.shared.match = match
        let mine = match.currentParticipant?.player?.isEqual(GKLocalPlayer.local) ?? false
        print("turn event: \(mine ? "my turn" : "their turn") active=\(didBecomeActive) data=\(match.matchData.map { String(decoding: $0, as: UTF8.self) } ?? "-")")
        if didBecomeActive, top() is GKTurnBasedMatchmakerViewController { top().dismiss(animated: true) }
    }
    func player(_ player: GKPlayer, matchEnded match: GKTurnBasedMatch) {
        let me = match.participants.first { $0.player?.isEqual(GKLocalPlayer.local) ?? false }
        print("turn-based match ended: my outcome=\(me?.matchOutcome.rawValue ?? -1) data=\(match.matchData.map { String(decoding: $0, as: UTF8.self) } ?? "-")")
    }
    @available(iOS 26.0, *)
    func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping (Bool) -> Void) {
        print("wants to play activity \(activity.activityDefinition.identifier) \"\(activity.activityDefinition.title)\" party=\(activity.partyCode ?? "-") arena=\(activity.properties["arena"] ?? "-")")
        activity.start()
        activity.setScore(on: board("dev.isim.gc.high_score"), to: 3000)
        activity.setAchievementCompleted(GKAchievement(identifier: "dev.isim.gc.first_win"))
        activity.pause(); activity.resume()
        activity.end()
        print("activity ended: state=\(activity.state.rawValue) scores=\(activity.leaderboardScores.count) achievements=\(activity.achievements.count)")
        completionHandler(true)
    }
}

func board(_ id: String) -> GKLeaderboard { let b = GKLeaderboard(); b.baseLeaderboardID = id; return b }

func top() -> UIViewController {
    var t = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!.windows.first { $0.isKeyWindow }!.rootViewController!
    while let p = t.presentedViewController { t = p }
    return t
}

@main
struct HelloGameCenterApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

struct RootView: View {
    @State private var signedIn = false
    /// (title, accessibility identifier, action): a grid of small buttons, so all fit on the screen
    var actions: [(String, String, () -> Void)] {
        [("Post scores", "scores", postScores), ("Report achievements", "achievements", report),
         ("Load metadata", "metadata", { Task { await loadMetadata() } }), ("Load entries", "entries", { Task { await loadEntries() } }),
         ("Dashboard", "dashboard", { present(GKGameCenterViewController(state: .dashboard)) }),
         ("Leaderboard set", "set", { present(GKGameCenterViewController(leaderboardSetID: "dev.isim.gc.set.season1")) }),
         ("Access point", "access-point", { GKAccessPoint.shared.isActive.toggle() }),
         ("Photo + friends", "photo", photoAndFriends),
         ("Friend request", "friend-request", { try? GKLocalPlayer.local.presentFriendRequestCreator(from: top()) }),
         ("Challenges", "challenges", loadChallenges), ("Beat challenge", "beat", beatChallenge), ("Challenge friends", "challenge", challengeFriends),
         ("Save game", "save", save), ("Fetch saves", "fetch", fetch),
         ("Matchmaker", "match", findMatch), ("Automatch", "automatch", automatch),
         ("Send hello", "send", { Realtime.shared.hello() }), ("Leave match", "leave", { Realtime.shared.leave() }),
         ("Turn-based", "turn-based", turnBased), ("Take turn", "take-turn", { Turns.shared.take() }),
         ("End match", "end-match", { Turns.shared.end() }), ("Load matches", "load-matches", { Turns.shared.load() }),
         ("Activities", "activities", activities)]
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(actions, id: \.1) { a in
                        Button(action: a.2) { Text(a.0).font(.system(size: 13)).frame(maxWidth: .infinity, minHeight: 36) }
                            .buttonStyle(.bordered)
                            .accessibilityIdentifier(a.1)
                    }
                }
                .padding(12)
                Text(signedIn ? "Signed in as \(GKLocalPlayer.local.alias)" : "Not signed in").accessibilityIdentifier("signed-in")
            }
            .navigationTitle("Game Center")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            GKLocalPlayer.local.authenticateHandler = { _, error in
                signedIn = GKLocalPlayer.local.isAuthenticated
                print("authenticated: \(signedIn) \(error.map { "\($0)" } ?? "")")
                print("player: \(GKLocalPlayer.local.alias) scoped=\(GKLocalPlayer.local.gamePlayerID.hasPrefix("A:_"))")
                GKLocalPlayer.local.register(Listener.shared)
                GKAccessPoint.shared.location = .topTrailing
                GKAccessPoint.shared.isActive = true
            }
        }
    }

    func postScores() {
        GKLeaderboard.submitScore(1200, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.high_score", "dev.isim.gc.daily"]) { _ in
            GKLeaderboard.submitScore(900, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.high_score"]) { _ in }
            GKLeaderboard.submitScore(42, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.fastest"]) { _ in }
            GKLeaderboard.submitScore(731, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.distance"]) { _ in }
            GKLeaderboard.submitScore(58, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.fastest"]) { _ in print("scores posted") }
        }
    }
    func report() {
        let a = GKAchievement(identifier: "dev.isim.gc.first_win"); a.percentComplete = 100; a.showsCompletionBanner = true
        let b = GKAchievement(identifier: "dev.isim.gc.collector"); b.percentComplete = 40
        GKAchievement.report([a, b]) { e in print("achievements reported \(e == nil)") }
    }
    func loadMetadata() async {
        let descs = (try? await GKAchievementDescription.loadAchievementDescriptions()) ?? []
        for d in descs { print("achievement description: \(d.identifier) \"\(d.title)\" \(d.maximumPoints) points hidden=\(d.isHidden) \"\(d.unachievedDescription)\"") }
        let boards = (try? await GKLeaderboard.loadLeaderboards(IDs: nil)) ?? []
        for b in boards {
            let (local, _, total) = (try? await b.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 10))) ?? (nil, [], 0)
            var line = "leaderboard: \(b.baseLeaderboardID) \"\(b.title ?? "")\" type=\(b.type == .recurring ? "recurring" : "classic") best=\(local?.score ?? -1) players=\(total)"
            if b.type == .recurring, let s = b.startDate, let n = b.nextStartDate { line += " period=\(Int(n.timeIntervalSince(s).rounded()))s" }
            print(line)
            if b.type == .recurring, let prev = try? await b.loadPreviousOccurrence() {
                let (p, _, _) = (try? await prev.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 10))) ?? (nil, [], 0)
                print("previous occurrence best=\(p?.score ?? -1)")
            }
            b.loadImage { img, _ in print("leaderboard image \(b.baseLeaderboardID): \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none")") }
        }
        let sets = (try? await GKLeaderboardSet.loadLeaderboardSets()) ?? []
        for s in sets {
            print("set: \(s.identifier ?? "") \"\(s.title)\" boards=\(((try? await s.loadLeaderboards()) ?? []).map { $0.baseLeaderboardID }.joined(separator: ","))")
            let img = try? await s.loadImage()
            print("set image \(s.identifier ?? ""): \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none")")
        }
    }
    /// every player's entries, ranks, formatted scores; a range; friends only
    func loadEntries() async {
        let boards = (try? await GKLeaderboard.loadLeaderboards(IDs: ["dev.isim.gc.high_score", "dev.isim.gc.fastest", "dev.isim.gc.distance"])) ?? []
        for b in boards {
            guard let (local, entries, total) = try? await b.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 1, length: 10)) else { continue }
            print("entries \(b.baseLeaderboardID): \(entries.map { "\($0.rank). \($0.player.alias) \($0.formattedScore)" }.joined(separator: "; ")) | me=#\(local?.rank ?? 0) of \(total)")
            if let (_, page, _) = try? await b.loadEntries(for: .global, timeScope: .allTime, range: NSRange(location: 2, length: 1)) {
                print("range 2 \(b.baseLeaderboardID): \(page.map { "\($0.rank). \($0.player.alias)" }.joined(separator: "; "))")
            }
            if let (_, friends, n) = try? await b.loadEntries(for: .friendsOnly, timeScope: .allTime, range: NSRange(location: 1, length: 10)) {
                print("friends only \(b.baseLeaderboardID): \(friends.map { $0.player.alias }.joined(separator: ",")) of \(n)")
            }
        }
    }
    func photoAndFriends() {
        GKLocalPlayer.local.loadPhoto(for: .normal) { img, e in print("photo: \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none") \(e == nil)") }
        GKLocalPlayer.local.loadFriendsAuthorizationStatus { s, _ in
            print("friends authorization: \(s.rawValue)")
            GKLocalPlayer.local.loadFriends { f, e in
                print("friends: \(f?.count ?? -1) \((f ?? []).map { $0.alias }.joined(separator: ","))\(e.map { " error \(($0 as NSError).code)" } ?? "")")
                GKLocalPlayer.local.loadFriendsAuthorizationStatus { s, _ in print("friends authorization: \(s.rawValue)") }
                GKLocalPlayer.local.loadRecentPlayers { r, _ in print("recent players: \((r ?? []).map { $0.alias }.joined(separator: ","))") }
            }
        }
    }
    func loadChallenges() {
        GKChallenge.loadReceivedChallenges { list, _ in
            print("challenges: \((list ?? []).map { c in "\(c is GKScoreChallenge ? "score" : "achievement") from \(c.issuingPlayer?.alias ?? "-") state=\(c.state.rawValue)" }.joined(separator: "; "))")
        }
    }
    func beatChallenge() {
        GKLeaderboard.submitScore(1600, context: 0, player: GKLocalPlayer.local, leaderboardIDs: ["dev.isim.gc.high_score"]) { _ in print("posted 1600") }
    }
    func challengeFriends() {
        let a = GKAchievement(identifier: "dev.isim.gc.first_win")
        let vc = a.challengeComposeController(withMessage: "Can you win too?", players: nil) { vc, sent, players in
            print("challenge sent=\(sent) to \((players ?? []).map { $0.alias }.joined(separator: ","))")
            vc.dismiss(animated: true)
        }
        top().present(vc, animated: true)
    }
    func save() {
        GKLocalPlayer.local.saveGameData(Data("level 3".utf8), withName: "slot1") { g, e in
            print("saved: \(g?.name ?? "-") on \(g?.deviceName ?? "-") \(e == nil)")
        }
    }
    func fetch() {
        GKLocalPlayer.local.fetchSavedGames { games, _ in
            print("fetched: \((games ?? []).map { "\($0.name ?? "")@\($0.deviceName ?? "")" }.sorted().joined(separator: ","))")
        }
    }
    /// the matchmaker sheet (find players or invite friends)
    func findMatch() {
        let r = GKMatchRequest(); r.minPlayers = 2; r.maxPlayers = 2
        r.recipientResponseHandler = { p, resp in print("invite response from \(p.alias): \(resp.rawValue)") }
        if let vc = GKMatchmakerViewController(matchRequest: r) {
            vc.matchmakerDelegate = MatchDelegate.shared
            top().present(vc, animated: true)
        }
    }
    /// automatching without UI
    func automatch() {
        let r = GKMatchRequest(); r.minPlayers = 2; r.maxPlayers = 2
        GKMatchmaker.shared().findMatch(for: r) { m, e in
            print("findMatch: match=\(m != nil) error=\(e != nil)")
            if let m { Realtime.shared.use(m) }
        }
    }
    func turnBased() {
        let r = GKMatchRequest(); r.minPlayers = 2; r.maxPlayers = 2
        let vc = GKTurnBasedMatchmakerViewController(matchRequest: r)
        vc.turnBasedMatchmakerDelegate = TurnDelegate.shared
        top().present(vc, animated: true)
    }
    func activities() {
        if #available(iOS 26.0, *) {
            GKGameActivityDefinition.loadGameActivityDefinitions { defs, _ in
                for d in defs ?? [] {
                    print("activity definition: \(d.identifier) \"\(d.title)\" party=\(d.supportsPartyCode) players=\(d.minPlayers?.intValue ?? 0)-\(d.maxPlayers?.intValue ?? 0) style=\(d.playStyle.rawValue)")
                    d.loadLeaderboards { b, _ in print("activity leaderboards: \((b ?? []).map { $0.baseLeaderboardID }.joined(separator: ","))") }
                    let a = GKGameActivity(definition: d)
                    a.start()
                    print("activity started: state=\(a.state.rawValue) party code valid=\(a.partyCode.map(GKGameActivity.isValidPartyCode) ?? false)")
                    a.end()
                }
            }
        } else {
            print("game activities need iOS 26")
        }
    }
    func present(_ vc: GKGameCenterViewController) { vc.gameCenterDelegate = GCDelegate.shared; top().present(vc, animated: true) }
}

/// the real-time match in play
final class Realtime: NSObject, GKMatchDelegate {
    static let shared = Realtime()
    var match: GKMatch?
    func use(_ m: GKMatch) {
        match = m; m.delegate = self
        print("match: expecting \(m.expectedPlayerCount) more")
    }
    func hello() {
        guard let m = match else { print("no match"); return }
        do { try m.sendData(toAllPlayers: Data("hello from \(GKLocalPlayer.local.alias)".utf8), with: .reliable); print("sent hello") }
        catch { print("send failed: \((error as NSError).code)") }
    }
    func leave() { match?.disconnect(); match = nil; print("left match") }
    func match(_ match: GKMatch, player: GKPlayer, didChange state: GKPlayerConnectionState) {
        print("match player \(player.alias) state=\(state.rawValue) players=\(match.players.count) expecting=\(match.expectedPlayerCount)")
    }
    func match(_ match: GKMatch, didReceive data: Data, fromRemotePlayer player: GKPlayer) {
        print("received: \(String(decoding: data, as: UTF8.self)) from \(player.alias)")
    }
}

final class Turns: NSObject {
    static let shared = Turns()
    var match: GKTurnBasedMatch?
    /// appends a move to the match data and passes the turn on
    func take() {
        guard let m = match else { print("no turn-based match"); return }
        m.loadMatchData { d, _ in
            let moves = d.map { String(decoding: $0, as: UTF8.self) } ?? ""
            let next = moves.isEmpty ? "\(GKLocalPlayer.local.alias)" : "\(moves),\(GKLocalPlayer.local.alias)"
            let others = m.participants.filter { !($0.player?.isEqual(GKLocalPlayer.local) ?? false) }
            m.endTurn(withNextParticipants: others, turnTimeout: GKTurnTimeoutDefault, match: Data(next.utf8)) { e in
                print("ended turn: \(next) error=\(e.map { "\(($0 as NSError).code)" } ?? "none") status=\(m.status.rawValue)")
            }
        }
    }
    func end() {
        guard let m = match else { print("no turn-based match"); return }
        for p in m.participants { p.matchOutcome = (p.player?.isEqual(GKLocalPlayer.local) ?? false) ? .won : .lost }
        m.endMatchInTurn(withMatch: m.matchData ?? Data()) { e in print("ended match: error=\(e.map { "\(($0 as NSError).code)" } ?? "none") status=\(m.status.rawValue)") }
    }
    func load() {
        GKTurnBasedMatch.loadMatches { ms, _ in
            print("matches: \((ms ?? []).map { "\($0.status.rawValue):\($0.participants.compactMap { $0.player?.alias }.joined(separator: "+"))" }.joined(separator: "; "))")
        }
    }
}

final class GCDelegate: NSObject, GKGameCenterControllerDelegate {
    static let shared = GCDelegate()
    func gameCenterViewControllerDidFinish(_ vc: GKGameCenterViewController) { print("dashboard closed"); vc.dismiss(animated: true) }
}
final class MatchDelegate: NSObject, GKMatchmakerViewControllerDelegate {
    static let shared = MatchDelegate()
    func matchmakerViewControllerWasCancelled(_ vc: GKMatchmakerViewController) { print("matchmaker cancelled"); vc.dismiss(animated: true) }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, didFailWithError error: Error) { print("matchmaker failed") }
    func matchmakerViewController(_ vc: GKMatchmakerViewController, didFind match: GKMatch) {
        print("matchmaker found: \(match.players.map { $0.alias }.joined(separator: ","))")
        Realtime.shared.use(match)
        vc.dismiss(animated: true)
    }
}
final class TurnDelegate: NSObject, GKTurnBasedMatchmakerViewControllerDelegate {
    static let shared = TurnDelegate()
    func turnBasedMatchmakerViewControllerWasCancelled(_ vc: GKTurnBasedMatchmakerViewController) { print("turn-based matchmaker cancelled"); vc.dismiss(animated: true) }
    func turnBasedMatchmakerViewController(_ vc: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) { print("turn-based matchmaker failed") }
}
