// Sample: isim's local Game Center — sign-in, the access point, leaderboards (classic, low-is-best,
// recurring with a 6-second period) and a leaderboard set, achievements with descriptions and points from
// isim-GameCenter.json, the dashboard, player photo, friends + friend request composer, saved games with a
// conflict, and the matchmaker (which finds nobody). Results are printed for tests/ui/gamecenter.sh.
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
}

@main
struct HelloGameCenterApp: App {
    var body: some Scene { WindowGroup { RootView() } }
}

struct RootView: View {
    @State private var signedIn = false
    var body: some View {
        NavigationStack {
            List {
                Section("Play") {
                    Button("Post scores") { postScores() }.accessibilityIdentifier("scores")
                    Button("Report achievements") { report() }.accessibilityIdentifier("achievements")
                    Button("Load metadata") { Task { await loadMetadata() } }.accessibilityIdentifier("metadata")
                }
                Section("Game Center") {
                    Button("Dashboard") { present(GKGameCenterViewController(state: .dashboard)) }.accessibilityIdentifier("dashboard")
                    Button("Leaderboard set") { present(GKGameCenterViewController(leaderboardSetID: "dev.isim.gc.set.season1")) }.accessibilityIdentifier("set")
                    Button("Access point on/off") { GKAccessPoint.shared.isActive.toggle() }.accessibilityIdentifier("access-point")
                    Button("Player photo + friends") { photoAndFriends() }.accessibilityIdentifier("photo")
                    Button("Friend request") { try? GKLocalPlayer.local.presentFriendRequestCreator(from: top()) }.accessibilityIdentifier("friend-request")
                }
                Section("Saved games & multiplayer") {
                    Button("Save game") { save() }.accessibilityIdentifier("save")
                    Button("Fetch saved games") { fetch() }.accessibilityIdentifier("fetch")
                    Button("Find match") { findMatch() }.accessibilityIdentifier("match")
                }
                Section { Text(signedIn ? "Signed in as \(GKLocalPlayer.local.alias)" : "Not signed in").accessibilityIdentifier("signed-in") }
            }
            .navigationTitle("Game Center")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            GKLocalPlayer.local.authenticateHandler = { _, error in
                signedIn = GKLocalPlayer.local.isAuthenticated
                print("authenticated: \(signedIn) \(error.map { "\($0)" } ?? "")")
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
            b.loadImage { img, _ in print("leaderboard image \(b.baseLeaderboardID): \(img != nil)") }
        }
        let sets = (try? await GKLeaderboardSet.loadLeaderboardSets()) ?? []
        for s in sets { print("set: \(s.identifier ?? "") \"\(s.title)\" boards=\(((try? await s.loadLeaderboards()) ?? []).map { $0.baseLeaderboardID }.joined(separator: ","))") }
    }
    func photoAndFriends() {
        GKLocalPlayer.local.loadPhoto(for: .normal) { img, e in print("photo: \(img.map { "\(Int($0.size.width))x\(Int($0.size.height))" } ?? "none") \(e == nil)") }
        GKLocalPlayer.local.loadFriends { f, _ in print("friends: \(f?.count ?? -1)") }
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
    func findMatch() {
        let r = GKMatchRequest(); r.minPlayers = 2; r.maxPlayers = 2
        GKMatchmaker.shared().findMatch(for: r) { m, e in print("findMatch: match=\(m != nil) error=\(e != nil)") }
        if let vc = GKMatchmakerViewController(matchRequest: r) {
            vc.matchmakerDelegate = MatchDelegate.shared
            top().present(vc, animated: true)
        }
    }
    func present(_ vc: GKGameCenterViewController) { vc.gameCenterDelegate = GCDelegate.shared; top().present(vc, animated: true) }
    func top() -> UIViewController {
        var t = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!.windows.first { $0.isKeyWindow }!.rootViewController!
        while let p = t.presentedViewController { t = p }
        return t
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
}
