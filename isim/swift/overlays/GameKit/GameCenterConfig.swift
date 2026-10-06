// isim's local Game Center configuration: the App Store Connect metadata a game would have (leaderboard
// titles, types, recurrence and sets; achievement titles, descriptions, points), read from
// isim-GameCenter.json in the app bundle (`isim build` copies an isim-GameCenter.json found next to the
// .xcodeproj; the Info.plist key ISIMGameCenterConfiguration may name another bundle file).
// The format is isim's own (see docs/GAMECENTER.md). Without it, titles are derived from identifiers.
import Foundation
import UIKit

struct _GCBoardDef {
    let id: String, title: String
    var recurring = false
    var start = Date(timeIntervalSince1970: 0)
    var duration: TimeInterval = 86400
    var sortLow = false
    var format = "integer"
    var image: String?
    /// the current occurrence of a recurring leaderboard (start, end)
    func occurrence(at now: Date = Date(), offset: Int = 0) -> (Date, Date) {
        guard recurring, duration > 0 else { return (Date.distantPast, Date.distantFuture) }
        let k = floor(now.timeIntervalSince(start) / duration) + Double(offset)
        let s = start.addingTimeInterval(k * duration)
        return (s, s.addingTimeInterval(duration))
    }
}
struct _GCAchievementDef {
    let id: String, title: String
    var points = 0, hidden = false, replayable = false
    var unachieved = "", achieved = ""
    var image: String?
    var group: String?
}
struct _GCSetDef { let id: String, title: String; var boards: [String]; var image: String? }

enum _GCConfig {
    nonisolated(unsafe) static var cached: (boards: [_GCBoardDef], sets: [_GCSetDef], achievements: [_GCAchievementDef])?
    static var boards: [_GCBoardDef] { load().boards }
    static var sets: [_GCSetDef] { load().sets }
    static var achievements: [_GCAchievementDef] { load().achievements }
    static func board(_ id: String) -> _GCBoardDef { boards.first { $0.id == id } ?? _GCBoardDef(id: id, title: _GCText.title(id)) }
    static func achievement(_ id: String) -> _GCAchievementDef? { achievements.first { $0.id == id } }

    /// "P1D", "P1W", "PT1H", "PT30M", "PT10S", "P1DT12H"
    static func duration(_ s: String?) -> TimeInterval? {
        guard let s, s.hasPrefix("P") else { return nil }
        var total: TimeInterval = 0, num = "", time = false
        for ch in s.dropFirst() {
            if ch == "T" { time = true; continue }
            if ch.isNumber || ch == "." { num.append(ch); continue }
            let n = Double(num) ?? 0; num = ""
            switch (ch, time) {
            case ("Y", false): total += n * 365 * 86400
            case ("M", false): total += n * 30 * 86400
            case ("W", false): total += n * 7 * 86400
            case ("D", false): total += n * 86400
            case ("H", true): total += n * 3600
            case ("M", true): total += n * 60
            case ("S", true): total += n
            default: return nil
            }
        }
        return total > 0 ? total : nil
    }

    /// "2025-01-01T00:00:00Z" (UTC) -> Date
    static func utcDate(_ s: String) -> Date? {
        let parts = s.split(whereSeparator: { "-T:Z".contains($0) }).map { Int($0) }
        guard parts.count >= 3, let y = parts[0], let m = parts[1], let d = parts[2] else { return nil }
        let hh = parts.count > 3 ? parts[3] ?? 0 : 0, mm = parts.count > 4 ? parts[4] ?? 0 : 0, ss = parts.count > 5 ? parts[5] ?? 0 : 0
        // days from 1970-01-01 (civil calendar)
        let yy = m <= 2 ? y - 1 : y
        let era = (yy >= 0 ? yy : yy - 399) / 400
        let yoe = yy - era * 400
        let doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146097 + doe - 719468
        return Date(timeIntervalSince1970: Double(days * 86400 + hh * 3600 + mm * 60 + ss))
    }

    static func load() -> (boards: [_GCBoardDef], sets: [_GCSetDef], achievements: [_GCAchievementDef]) {
        if let c = cached { return c }
        var boards: [_GCBoardDef] = [], sets: [_GCSetDef] = [], achs: [_GCAchievementDef] = []
        let name = Bundle.main.object(forInfoDictionaryKey: "ISIMGameCenterConfiguration") as? String ?? "isim-GameCenter.json"
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent(name)
        if let data = FileManager.default.contents(atPath: path),
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            for b in root["leaderboards"] as? [[String: Any]] ?? [] {
                guard let id = b["id"] as? String else { continue }
                var d = _GCBoardDef(id: id, title: b["title"] as? String ?? _GCText.title(id))
                d.recurring = (b["type"] as? String) == "recurring"
                if let s = b["start"] as? String, let date = utcDate(s) { d.start = date }
                if let dur = duration(b["duration"] as? String) { d.duration = dur }
                d.sortLow = (b["sortOrder"] as? String)?.lowercased() == "low"
                d.format = b["format"] as? String ?? "integer"
                d.image = b["image"] as? String
                boards.append(d)
            }
            for s in root["leaderboardSets"] as? [[String: Any]] ?? [] {
                guard let id = s["id"] as? String else { continue }
                sets.append(_GCSetDef(id: id, title: s["title"] as? String ?? _GCText.title(id), boards: s["leaderboards"] as? [String] ?? [], image: s["image"] as? String))
            }
            for a in root["achievements"] as? [[String: Any]] ?? [] {
                guard let id = a["id"] as? String else { continue }
                var d = _GCAchievementDef(id: id, title: a["title"] as? String ?? _GCText.title(id))
                d.points = a["points"] as? Int ?? 0
                d.hidden = a["hidden"] as? Bool ?? false
                d.replayable = a["replayable"] as? Bool ?? false
                d.unachieved = a["unachievedDescription"] as? String ?? ""
                d.achieved = a["achievedDescription"] as? String ?? d.unachieved
                d.image = a["image"] as? String
                d.group = a["groupIdentifier"] as? String
                achs.append(d)
            }
            NSLog("isim GameKit: local Game Center configuration %@ (%ld leaderboards, %ld sets, %ld achievements)", name, boards.count, sets.count, achs.count)
        }
        let c = (boards, sets, achs)
        cached = c
        return c
    }
}

/// Generated images (SVG drawn by the host): player monograms, leaderboard and achievement placeholders.
enum _GCImages {
    static var dir: String {
        let d = (NSHomeDirectory() as NSString).appendingPathComponent("Library/Caches/isim-GameCenter")
        try? FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true, attributes: nil)
        return d
    }
    static func svg(_ key: String, _ body: String, size: Int) -> UIImage? {
        let safe = String(key.map { $0.isLetter || $0.isNumber ? $0 : "_" })
        let path = (dir as NSString).appendingPathComponent("\(safe)-\(size).svg")
        if !FileManager.default.fileExists(atPath: path) {
            let doc = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(size)\" height=\"\(size)\" viewBox=\"0 0 100 100\">\(body)</svg>"
            FileManager.default.createFile(atPath: path, contents: Data(doc.utf8), attributes: nil)
        }
        return UIImage(contentsOfFile: path)
    }
    static func escape(_ s: String) -> String {
        var o = ""
        for ch in s { switch ch { case "<": o += "&lt;"; case ">": o += "&gt;"; case "&": o += "&amp;"; case "\"": o += "&quot;"; default: o.append(ch) } }
        return o
    }
    /// gray circle with the player's initials, like Game Center's monogram avatars
    static func monogram(_ name: String, size: Int = 120) -> UIImage? {
        svg("player-\(name)", "<circle cx=\"50\" cy=\"50\" r=\"50\" fill=\"#8E8E93\"/><text x=\"50\" y=\"50\" dy=\"0.35em\" text-anchor=\"middle\" font-family=\"sans-serif\" font-weight=\"600\" font-size=\"40\" fill=\"#FFFFFF\">\(escape(_GCText.initials(name)))</text>", size: size)
    }
    static func bundleImage(_ name: String?) -> UIImage? {
        guard let name else { return nil }
        return UIImage(named: name) ?? UIImage(contentsOfFile: (Bundle.main.bundlePath as NSString).appendingPathComponent(name))
    }
    static func leaderboard(_ id: String) -> UIImage? {
        bundleImage(_GCConfig.board(id).image) ?? svg("board-\(id)", "<rect width=\"100\" height=\"100\" rx=\"22\" fill=\"#0A84FF\"/><path d=\"M28 70V48h12v22zM44 70V32h12v38zM60 70V56h12v14z\" fill=\"#FFFFFF\"/>", size: 120)
    }
    static func achievement(_ id: String, completed: Bool) -> UIImage? {
        if completed, let img = bundleImage(_GCConfig.achievement(id)?.image) { return img }
        return completed
            ? svg("ach-done", "<circle cx=\"50\" cy=\"50\" r=\"50\" fill=\"#FF9F0A\"/><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"none\" stroke=\"#FFFFFF\" stroke-opacity=\"0.55\" stroke-width=\"3\"/><path d=\"M50 24l7.6 15.6 17.2 2.5-12.4 12.1 2.9 17.1L50 63.2l-15.3 8.1 2.9-17.1-12.4-12.1 17.2-2.5z\" fill=\"#FFFFFF\"/>", size: 120)
            : svg("ach-incomplete", "<circle cx=\"50\" cy=\"50\" r=\"50\" fill=\"#C7C7CC\"/><circle cx=\"50\" cy=\"50\" r=\"40\" fill=\"none\" stroke=\"#FFFFFF\" stroke-opacity=\"0.6\" stroke-width=\"3\"/>", size: 120)
    }
}
