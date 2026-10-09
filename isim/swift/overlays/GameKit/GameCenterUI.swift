// The Game Center dashboard (GKGameCenterViewController), drawn in SwiftUI like iOS's Game Center UI:
// the game's icon and name, the player's monogram, leaderboard cards with rank and score, achievement medals
// with progress rings, and a leaderboard page with Today / This Week / All Time.
// isim's Game Center is local: the players are the isim devices on this computer and test players
// (GameCenterNetwork.swift). Titles, descriptions, points, recurrence, score formats and sets come from the app's
// isim-GameCenter.json; without it titles are derived from the identifiers ("dev.example.highest_level" -> "Highest Level").
import Foundation
import UIKit
import SwiftUI

enum _GCText {
    /// "com.example.game.highest_level" -> "Highest Level"
    static func title(_ id: String) -> String {
        let last = id.split(separator: ".").last.map(String.init) ?? id
        var words: [String] = [], cur = ""
        for ch in last {
            if ch == "_" || ch == "-" || ch == " " { if !cur.isEmpty { words.append(cur); cur = "" }; continue }
            if ch.isUppercase, let p = cur.last, p.isLowercase { words.append(cur); cur = "" }
            cur.append(ch)
        }
        if !cur.isEmpty { words.append(cur) }
        return words.map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }
    static func initials(_ name: String) -> String {
        let parts = name.split(separator: " ").prefix(2)
        let s = parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
        return s.isEmpty ? "?" : s
    }
    static func number(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? String(n)
    }
    static func date(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: d)
    }
}

struct _GCApp {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Game"
    }
    /// the app icon, as isim-build lays it out (isim-assets.plist)
    static var icon: UIImage? {
        let dir = Bundle.main.bundlePath as NSString
        guard let assets = NSDictionary(contentsOfFile: dir.appendingPathComponent("isim-assets.plist")) as? [String: Any],
              let icons = assets["appIcons"] as? [String: Any], let files = (icons["AppIcon"] ?? icons.values.first) as? [[String: Any]] else { return nil }
        let usable = files.filter { ($0["appearance"] as? String ?? "any") == "any" }
        guard let f = usable.last?["file"] as? String ?? files.first?["file"] as? String else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(f))
    }
}

enum _GCScope: Int, CaseIterable { case today, week, allTime
    var label: String { ["Today", "This Week", "All Time"][rawValue] }
    func includes(_ d: Date) -> Bool {
        switch self {
        case .allTime: return true
        case .week: return Date().timeIntervalSince(d) < 7 * 86400
        case .today: return Calendar.current.isDateInToday(d)
        }
    }
}

struct _GCBoard: Identifiable {
    let id: String
    var def: _GCBoardDef { _GCConfig.board(id) }
    var title: String { def.title }
    /// every player's best score, ranked
    func entries(_ scope: _GCScope) -> [GKLeaderboard.Entry] {
        GKLeaderboard.make(id).ranked(GKLeaderboard.TimeScope(rawValue: scope.rawValue) ?? .allTime)
    }
    func mine(_ scope: _GCScope) -> GKLeaderboard.Entry? { entries(scope).first { $0.player === GKLocalPlayer.local } }
    /// "Resets in 3h 20m" for recurring leaderboards
    var resetLine: String? {
        guard def.recurring else { return nil }
        let left = Int(def.occurrence().1.timeIntervalSinceNow)
        let d = left / 86400, h = (left % 86400) / 3600, m = (left % 3600) / 60, sec = left % 60
        let t = d > 0 ? "\(d)d \(h)h" : h > 0 ? "\(h)h \(m)m" : m > 0 ? "\(m)m \(sec)s" : "\(sec)s"
        return "Recurring · resets in \(t)"
    }
    /// configured leaderboards first (in file order), then any other boards with scores
    static var all: [_GCBoard] {
        let configured = _GCConfig.boards.map { $0.id }
        return (configured + _GC.scores().keys.sorted().filter { !configured.contains($0) }).map { _GCBoard(id: $0) }
    }
}

struct _GCAchievement: Identifiable {
    let id: String, percent: Double, date: Date
    var def: _GCAchievementDef? { _GCConfig.achievement(id) }
    var title: String { def?.title ?? _GCText.title(id) }
    var completed: Bool { percent >= 100 }
    var detail: String { (completed ? def?.achieved : def?.unachieved) ?? "" }
    var points: Int { def?.points ?? 0 }
    /// reported achievements plus the configured ones not started yet (hidden ones stay hidden)
    static var all: [_GCAchievement] {
        let reported = _GC.achievements()
        var list = reported.map { id, v in
            _GCAchievement(id: id, percent: v["percent"] as? Double ?? 0, date: Date(timeIntervalSince1970: v["date"] as? Double ?? 0))
        }
        for d in _GCConfig.achievements where reported[d.id] == nil && !d.hidden {
            list.append(_GCAchievement(id: d.id, percent: 0, date: .distantPast))
        }
        return list.sorted { ($0.completed ? 0 : 1, $1.date, $0.title) < ($1.completed ? 0 : 1, $0.date, $1.title) }
    }
}

// MARK: - Pieces

struct _GCAvatar: View {
    let name: String, size: CGFloat
    var body: some View {
        ZStack {
            Circle().fill(Color(uiColor: .systemGray2))
            Text(verbatim: _GCText.initials(name)).font(.system(size: size * 0.4, weight: .semibold, design: .rounded)).foregroundStyle(.white)
        }
        .frame(width: size, height: size)
    }
}

/// Achievement medal: earned ones are colored with a star, others show a progress ring.
struct _GCMedal: View {
    let achievement: _GCAchievement, size: CGFloat
    static let palette: [Color] = [.orange, .blue, .green, .pink, .purple, .teal, .indigo, .red]
    var color: Color { _GCMedal.palette[abs(achievement.id.hashValue % _GCMedal.palette.count)] }
    var body: some View {
        ZStack {
            if achievement.completed {
                Circle().fill(color)
                Circle().stroke(Color.white.opacity(0.55), lineWidth: max(1.5, size / 28)).padding(size * 0.09)
                Image(systemName: "star.fill").font(.system(size: size * 0.38, weight: .semibold)).foregroundStyle(.white)
            } else {
                Circle().fill(_GCStyle.fill)
                Circle().trim(from: 0, to: CGFloat(achievement.percent / 100))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: max(2.5, size / 16), lineCap: .round))
                    .rotationEffect(.degrees(-90)).padding(size * 0.06)
                Text(verbatim: "\(Int(achievement.percent))%").font(.system(size: size * 0.24, weight: .semibold)).foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Game Center pages sit on a material backdrop (the game shows through, blurred); cards are translucent.
enum _GCStyle {
    static let card = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.09) : UIColor(white: 1, alpha: 0.6) })
    static let fill = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(white: 1, alpha: 0.12) : UIColor(white: 0, alpha: 0.06) })
}

struct _GCCard<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(_GCStyle.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct _GCSectionHeader: View {
    let title: String, action: (() -> Void)?
    var body: some View {
        Button { action?() } label: {
            HStack(spacing: 6) {
                Text(verbatim: title).font(.system(size: 22, weight: .bold)).foregroundStyle(.primary)
                if action != nil { Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundStyle(.secondary) }
                Spacer()
            }
        }
        .disabled(action == nil)
        .padding(.top, 18).padding(.bottom, 8)
    }
}

struct _GCRowDivider: View {
    var inset: CGFloat = 72
    var body: some View { Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5).padding(.leading, inset) }
}

/// iOS-style segmented control
struct _GCSegments: View {
    @Binding var scope: _GCScope
    var body: some View {
        HStack(spacing: 2) {
            ForEach(_GCScope.allCases, id: \.rawValue) { s in
                Button { scope = s } label: {
                    Text(verbatim: s.label).font(.system(size: 13, weight: s == scope ? .semibold : .regular)).foregroundStyle(.primary)
                        .frame(maxWidth: .infinity).frame(height: 28)
                        .background(s == scope ? _GCStyle.card : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                }
                .accessibilityIdentifier("gc-scope-\(s.rawValue)")
            }
        }
        .padding(2)
        .background(_GCStyle.fill, in: RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Pages

enum _GCRoute: Hashable { case leaderboards, leaderboard(String), achievements, leaderboardSet(String), friends }

struct _GCDashboard: View {
    let close: () -> Void
    @State private var path: [_GCRoute]
    init(initial: [_GCRoute], close: @escaping () -> Void) { self.close = close; _path = State(initialValue: initial) }
    static func title(_ r: _GCRoute?) -> String {
        switch r {
        case nil: return _GCApp.name
        case .leaderboards?: return "Leaderboards"
        case .leaderboard(let id)?: return _GCConfig.board(id).title
        case .achievements?: return "Achievements"
        case .leaderboardSet(let id)?: return _GCConfig.sets.first { $0.id == id }?.title ?? _GCText.title(id)
        case .friends?: return "Friends"
        }
    }
    var body: some View {
        let top = path.last
        VStack(spacing: 0) {
            _GCBar(title: top == nil ? "" : _GCDashboard.title(top),
                   backTitle: path.isEmpty ? nil : _GCDashboard.title(path.count >= 2 ? path[path.count - 2] : nil),
                   back: { path.removeLast() }, close: close)
            Group {
                switch top {
                case nil: _GCHome(open: { path.append($0) })
                case .leaderboards?: _GCLeaderboards(open: { path.append($0) })
                case .leaderboard(let id)?: _GCLeaderboardPage(board: _GCBoard(id: id))
                case .achievements?: _GCAchievements()
                case .leaderboardSet(let id)?: _GCLeaderboards(open: { path.append($0) }, setID: id)
                case .friends?: _GCFriends()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(path.count)
        }
    }
}

/// Transparent navigation bar: back chevron with the previous page's title, centered title, close button.
struct _GCBar: View {
    let title: String, backTitle: String?, back: () -> Void, close: () -> Void
    var body: some View {
        ZStack {
            Text(verbatim: title).font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary).lineLimit(1).padding(.horizontal, 90)
            HStack {
                if let backTitle {
                    Button(action: back) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left").font(.system(size: 19, weight: .semibold))
                            Text(verbatim: backTitle).font(.system(size: 17)).lineLimit(1)
                        }
                        .foregroundStyle(Color.accentColor)
                    }
                    .accessibilityIdentifier("gc-back")
                }
                Spacer()
                _GCClose(close: close)
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 16)
    }
}

struct _GCClose: View {
    let close: () -> Void
    var body: some View {
        Button(action: close) {
            ZStack {
                Circle().fill(_GCStyle.fill)
                Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary)
            }
            .frame(width: 30, height: 30)
        }
        .accessibilityIdentifier("gc-done")
    }
}

struct _GCHome: View {
    let open: (_GCRoute) -> Void
    var body: some View {
        let boards = _GCBoard.all, achievements = _GCAchievement.all
        let done = achievements.filter { $0.completed }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // game header
                VStack(spacing: 10) {
                    if let icon = _GCApp.icon {
                        Image(uiImage: icon).resizable().frame(width: 88, height: 88).clipShape(RoundedRectangle(cornerRadius: 20))
                    } else {
                        ZStack { RoundedRectangle(cornerRadius: 20).fill(Color(uiColor: .systemGray4))
                            Image(systemName: "gamecontroller").font(.system(size: 34)).foregroundStyle(.white) }
                        .frame(width: 88, height: 88)
                    }
                    Text(verbatim: _GCApp.name).font(.system(size: 26, weight: .bold)).foregroundStyle(.primary)
                    HStack(spacing: 8) {
                        _GCAvatar(name: _GC.alias, size: 26)
                        Text(verbatim: _GC.alias).font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 4).padding(.bottom, 6)

                _GCSectionHeader(title: "Leaderboards", action: boards.isEmpty ? nil : { open(.leaderboards) })
                _GCCard {
                    if boards.isEmpty {
                        Text(verbatim: "Play to post your first score.").font(.system(size: 15)).foregroundStyle(.secondary).padding(16)
                    }
                    ForEach(Array(boards.prefix(4).enumerated()), id: \.element.id) { i, b in
                        if i > 0 { _GCRowDivider() }
                        Button { open(.leaderboard(b.id)) } label: { _GCBoardRow(board: b) }
                            .accessibilityIdentifier("gc-board-\(b.id)")
                    }
                }

                _GCSectionHeader(title: "Achievements", action: achievements.isEmpty ? nil : { open(.achievements) })
                _GCCard {
                    if achievements.isEmpty {
                        Text(verbatim: "No achievements yet.").font(.system(size: 15)).foregroundStyle(.secondary).padding(16)
                    } else {
                        Button { open(.achievements) } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Text(verbatim: "\(done) of \(achievements.count) Completed" + (_GCConfig.achievements.isEmpty ? "" : " · \(achievements.filter { $0.completed }.reduce(0) { $0 + $1.points }) points"))
                                    .font(.system(size: 15, weight: .semibold)).foregroundStyle(.primary).accessibilityIdentifier("gc-achievements-summary")
                                HStack(spacing: 6) {
                                    ForEach(achievements.prefix(6)) { a in _GCMedal(achievement: a, size: 54) }
                                    Spacer()
                                }
                            }
                            .padding(16)
                        }
                        .accessibilityIdentifier("gc-achievements")
                    }
                }

                Text(verbatim: "Game Center on isim is local: the players are the isim devices on this computer.")
                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(.top, 16)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
    }
}

struct _GCBoardRow: View {
    let board: _GCBoard
    var body: some View {
        let best = board.mine(.allTime)
        HStack(spacing: 14) {
            _GCBoardIcon(id: board.id, symbol: "list.number")
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: board.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
                Text(verbatim: best.map { "#\($0.rank) · \($0.formattedScore)" } ?? "No score yet").font(.system(size: 14)).foregroundStyle(.secondary)
                if let r = board.resetLine { Text(verbatim: r).font(.system(size: 12)).foregroundStyle(.secondary) }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(uiColor: .tertiaryLabel))
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}

struct _GCLeaderboards: View {
    let open: (_GCRoute) -> Void
    var setID: String? = nil
    var body: some View {
        let boards = setID.map { id in (_GCConfig.sets.first { $0.id == id }?.boards ?? []).map { _GCBoard(id: $0) } } ?? _GCBoard.all
        let sets = setID == nil ? _GCConfig.sets : []
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !sets.isEmpty {
                    _GCCard {
                        ForEach(Array(sets.enumerated()), id: \.element.id) { i, s in
                            if i > 0 { _GCRowDivider() }
                            Button { open(.leaderboardSet(s.id)) } label: {
                                HStack(spacing: 14) {
                                    _GCBoardIcon(id: s.id, symbol: "square.grid.2x2")
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(verbatim: s.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                        Text(verbatim: "\(s.boards.count) leaderboards").font(.system(size: 14)).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color(uiColor: .tertiaryLabel))
                                }
                                .padding(.horizontal, 14).padding(.vertical, 12)
                            }
                            .accessibilityIdentifier("gc-set-\(s.id)")
                        }
                    }
                }
                _GCCard {
                    ForEach(Array(boards.enumerated()), id: \.element.id) { i, b in
                        if i > 0 { _GCRowDivider() }
                        Button { open(.leaderboard(b.id)) } label: { _GCBoardRow(board: b) }
                            .accessibilityIdentifier("gc-board-\(b.id)")
                    }
                }
            }
            .padding(16)
        }

    }
}

struct _GCBoardIcon: View {
    let id: String, symbol: String
    var body: some View {
        if let img = _GCImages.bundleImage(_GCConfig.board(id).image) {
            Image(uiImage: img).resizable().frame(width: 44, height: 44).clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.accentColor)
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)
        }
    }
}

struct _GCFriends: View {
    var body: some View {
        let friends = _GCNet.friendIDs().map(GKPlayer._make).sorted { $0.alias < $1.alias }
        ScrollView {
            if friends.isEmpty {
                VStack(spacing: 12) {
                    Text(verbatim: "No Friends Yet").font(.system(size: 20, weight: .bold)).padding(.top, 40)
                    Text(verbatim: "Friends are the players of the other isim devices on this computer, and test players.")
                        .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                .padding(24)
            } else {
                _GCCard {
                    ForEach(Array(friends.enumerated()), id: \.element._id) { i, f in
                        if i > 0 { _GCRowDivider(inset: 66) }
                        HStack(spacing: 12) {
                            _GCAvatar(name: f.alias, size: 40)
                            Text(verbatim: f.alias).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .accessibilityIdentifier("gc-friend-\(f.alias)")
                    }
                }
                .padding(16)
            }
        }
    }
}

struct _GCLeaderboardPage: View {
    let board: _GCBoard
    @State private var scope: _GCScope = .allTime
    var body: some View {
        let entries = board.entries(scope)
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                _GCSegments(scope: $scope)
                _GCCard {
                    if entries.isEmpty {
                        Text(verbatim: scope == .allTime ? "No scores yet." : "No scores \(scope == .today ? "today" : "this week").")
                            .font(.system(size: 15)).foregroundStyle(.secondary).padding(16)
                    }
                    ForEach(Array(entries.prefix(50).enumerated()), id: \.offset) { i, e in
                        if i > 0 { _GCRowDivider(inset: 94) }
                        let me = e.player === GKLocalPlayer.local
                        HStack(spacing: 12) {
                            Text(verbatim: "\(e.rank)").font(.system(size: 17, weight: .bold)).foregroundStyle(.primary).frame(width: 28)
                            _GCAvatar(name: e.player.alias, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(verbatim: e.player.alias).font(.system(size: 16, weight: .semibold)).foregroundStyle(me ? Color.accentColor : .primary)
                                Text(verbatim: _GCText.date(e.date)).font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(verbatim: e.formattedScore).font(.system(size: 17, weight: .semibold)).foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .accessibilityIdentifier("gc-entry-\(e.rank)")
                    }
                }
                if let r = board.resetLine { Text(verbatim: r).font(.system(size: 13)).foregroundStyle(.secondary).accessibilityIdentifier("gc-board-reset") }
                Text(verbatim: entries.count == 1 ? "1 player" : "\(entries.count) players").font(.system(size: 12)).foregroundStyle(.secondary)
                    .accessibilityIdentifier("gc-board-players")
            }
            .padding(16)
        }

    }
}

struct _GCAchievements: View {
    var body: some View {
        let all = _GCAchievement.all
        let done = all.filter { $0.completed }.count
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "\(done) of \(all.count) Completed").font(.system(size: 15, weight: .semibold)).foregroundStyle(.secondary)
                _GCCard {
                    ForEach(Array(all.enumerated()), id: \.element.id) { i, a in
                        if i > 0 { _GCRowDivider(inset: 84) }
                        HStack(spacing: 14) {
                            _GCMedal(achievement: a, size: 56)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: a.title).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                                if !a.detail.isEmpty { Text(verbatim: a.detail).font(.system(size: 13)).foregroundStyle(.primary).lineLimit(2) }
                                Text(verbatim: (a.completed ? "Completed · \(_GCText.date(a.date))" : "\(Int(a.percent))% complete") + (a.points > 0 ? " · \(a.points) points" : ""))
                                    .font(.system(size: 13)).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .accessibilityIdentifier("gc-achievement-\(a.id)")
                    }
                }
            }
            .padding(16)
        }

    }
}
