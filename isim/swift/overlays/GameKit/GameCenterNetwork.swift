// isim's local Game Center network (adapted). Real Game Center is a server; isim has none, so every isim device on
// this computer (each device data directory, $ISIM_DATA) is a Game Center player, and the players share one
// directory: $ISIM_GAMECENTER (default ~/.local/share/isim-gamecenter). Nothing is sent to Apple.
//
//   players/<id>.json                       a player: alias, device, test (a test player made by `isim gamecenter`)
//   friends/<a>+<b>                         a friendship (ids sorted)
//   friend-requests/<from>+<to>.json        a pending friend request
//   inbox/<id>/<time>-<uuid>.json           events for a player (invites, turns, challenges, ...), drained by its apps
//   games/<bundle id>/scores/<id>.json      a player's scores: leaderboard id -> [{value, context, date}]
//   games/<bundle id>/challenges/<id>.json  score and achievement challenges
//   games/<bundle id>/matchmaking/...       real-time matchmaking tickets and matches (GameKitMultiplayer.swift)
//   games/<bundle id>/turnbased/<id>.json   turn-based matches
//
// Files are written whole and renamed into place; read-modify-write of shared files holds a lock (a directory
// created next to the file). `isim gamecenter` (tools/isim-services.py) reads and writes the same files.
import Foundation
import UIKit

enum _GCNet {
    static func env(_ name: String) -> String? {
        guard let v = ProcessInfo.processInfo.environment[name], !v.isEmpty else { return nil }
        return v
    }
    static var home: String { env("HOME") ?? "/tmp" }
    /// the device data ($ISIM_DATA)
    static var deviceData: String { env("ISIM_DATA") ?? (home as NSString).appendingPathComponent(".local/share/isim") }
    /// the shared network directory
    static var root: String { env("ISIM_GAMECENTER") ?? (home as NSString).appendingPathComponent(".local/share/isim-gamecenter") }
    static var bundleID: String { Bundle.main.bundleIdentifier ?? "app" }
    static func path(_ parts: String...) -> String { parts.reduce(root) { ($0 as NSString).appendingPathComponent($1) } }
    static func gamePath(_ parts: String...) -> String { parts.reduce(path("games", bundleID)) { ($0 as NSString).appendingPathComponent($1) } }

    // MARK: files

    static func read(_ p: String) -> Any? {
        guard let d = FileManager.default.contents(atPath: p) else { return nil }
        return try? JSONSerialization.jsonObject(with: d)
    }
    static func readDict(_ p: String) -> [String: Any]? { read(p) as? [String: Any] }
    static func write(_ p: String, _ obj: Any) {
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted, .sortedKeys]) else { return }
        let tmp = "\(p).isim-tmp-\(getpid())-\(UInt32.random(in: 0...UInt32.max))"
        guard FileManager.default.createFile(atPath: tmp, contents: d, attributes: nil) else { NSLog("isim GameKit: cannot write %@", p); return }
        if rename(tmp, p) != 0 { unlink(tmp) }
    }
    static func list(_ dir: String) -> [String] { ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { !$0.contains(".isim-tmp-") && !$0.hasSuffix(".lock") }.sorted() }
    static func remove(_ p: String) { try? FileManager.default.removeItem(atPath: p) }
    static func exists(_ p: String) -> Bool { FileManager.default.fileExists(atPath: p) }

    /// Runs `body` holding a lock on `p`: a directory `p.lock` holding the time it was taken (older than 5 s: stale).
    static func locked<T>(_ p: String, _ body: () -> T) -> T {
        let lock = p + ".lock", stamp = lock + "/t"
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        let start = Date()
        while mkdir(lock, 0o755) != 0 {
            if let d = FileManager.default.contents(atPath: stamp), let t = Double(String(decoding: d, as: UTF8.self)),
               Date().timeIntervalSince1970 - t > 5 {
                unlink(stamp); rmdir(lock); continue
            }
            if Date().timeIntervalSince(start) > 10 { break }
            usleep(2000)
        }
        FileManager.default.createFile(atPath: stamp, contents: Data(String(Date().timeIntervalSince1970).utf8), attributes: nil)
        defer { unlink(stamp); rmdir(lock) }
        return body()
    }
    /// read-modify-write of a JSON dictionary under its lock; `body` returns false to leave the file as it was
    @discardableResult
    static func update(_ p: String, _ body: (inout [String: Any]) -> Bool) -> [String: Any] {
        locked(p) {
            var d = readDict(p) ?? [:]
            if body(&d) { write(p, d) }
            return d
        }
    }

    // MARK: players

    struct Player { let id: String, alias: String, device: String, test: Bool }
    static func player(_ id: String) -> Player? {
        guard let d = readDict(path("players", "\(id).json")) else { return nil }
        return Player(id: id, alias: d["alias"] as? String ?? "Player", device: d["device"] as? String ?? "", test: d["test"] as? Bool ?? false)
    }
    static func players() -> [Player] { list(path("players")).filter { $0.hasSuffix(".json") }.compactMap { player(String($0.dropLast(5))) } }

    nonisolated(unsafe) static var cachedMe: String?
    /// This device's player id: made once and kept in the device data (Library/GameCenter/player.json).
    static var me: String {
        if let c = cachedMe { return c }
        let file = (deviceData as NSString).appendingPathComponent("Library/GameCenter/player.json")
        var id = readDict(file)?["id"] as? String
        if id == nil {
            let new = String(format: "%010u", UInt32.random(in: 1_000_000_000...UInt32.max))
            write(file, ["id": new])
            id = new
        }
        cachedMe = id
        return id!
    }
    /// Publishes this device's player (alias from Settings > Game Center) on the network.
    static func register() {
        let p = path("players", "\(me).json")
        let old = readDict(p)
        let device = MainActor.assumeIsolated { UIDevice.current.name }
        if old?["alias"] as? String != _GC.alias || old?["device"] as? String != device {
            write(p, ["id": me, "alias": _GC.alias, "device": device, "test": false, "data": deviceData])
        }
    }

    // MARK: friends

    static func pair(_ a: String, _ b: String) -> String { a < b ? "\(a)+\(b)" : "\(b)+\(a)" }
    static func friendIDs(of id: String = me) -> [String] {
        list(path("friends")).compactMap { f in
            let ids = f.split(separator: "+").map(String.init)
            guard ids.count == 2, ids.contains(id) else { return nil }
            return ids[0] == id ? ids[1] : ids[0]
        }
    }
    static func befriend(_ a: String, _ b: String) {
        write(path("friends", pair(a, b)), ["since": Date().timeIntervalSince1970])
        remove(path("friend-requests", "\(a)+\(b).json")); remove(path("friend-requests", "\(b)+\(a).json"))
    }
    /// Sends a friend request; a test player (no device behind it) accepts at once.
    static func requestFriend(_ to: Player, message: String) {
        if to.test { befriend(me, to.id); NSLog("isim GameKit: friend request to %@ accepted (test player)", to.alias); return }
        if exists(path("friend-requests", "\(to.id)+\(me).json")) { befriend(me, to.id); return }    // they asked first
        write(path("friend-requests", "\(me)+\(to.id).json"), ["from": me, "to": to.id, "message": message, "date": Date().timeIntervalSince1970])
        post(to.id, ["kind": "friendRequest", "from": me])
    }
    /// recent players: met in a match (per player, newest first)
    static func recentIDs() -> [String] {
        let d = readDict(path("recent", "\(me).json")) ?? [:]
        return d.keys.sorted { (d[$0] as? Double ?? 0) > (d[$1] as? Double ?? 0) }
    }
    static func met(_ ids: [String]) {
        let others = ids.filter { $0 != me }
        guard !others.isEmpty else { return }
        update(path("recent", "\(me).json")) { d in
            for o in others { d[o] = Date().timeIntervalSince1970 }
            return true
        }
    }

    // MARK: scores

    static func scoresFile(_ id: String) -> String { gamePath("scores", "\(id).json") }
    /// a player's scores in this game: leaderboard id -> [{value, context, date}]
    static func scores(of id: String) -> [String: [[String: Any]]] {
        readDict(scoresFile(id)) as? [String: [[String: Any]]] ?? [:]
    }
    static func addScore(_ v: Int, context: Int, board: String, player id: String) {
        update(scoresFile(id)) { all in
            var list = all[board] as? [[String: Any]] ?? []
            list.append(["value": v, "context": context, "date": Date().timeIntervalSince1970])
            if list.count > 200 { list.removeFirst(list.count - 200) }
            all[board] = list
            return true
        }
    }
    /// every player with scores in this game
    static func scoredPlayers() -> [String] { list(gamePath("scores")).filter { $0.hasSuffix(".json") }.map { String($0.dropLast(5)) } }

    // MARK: inbox

    /// Leaves an event for a player's apps (picked up within a quarter of a second while one runs).
    static func post(_ to: String, _ event: [String: Any]) {
        var e = event
        e["game"] = e["game"] ?? bundleID
        e["date"] = Date().timeIntervalSince1970
        write(path("inbox", to, String(format: "%.6f-%@.json", Date().timeIntervalSince1970, UUID().uuidString)), e)
    }
    /// takes this player's events for this app (others stay for their apps)
    static func drain() -> [[String: Any]] {
        let dir = path("inbox", me)
        var out: [[String: Any]] = []
        for f in list(dir) where f.hasSuffix(".json") {
            let p = (dir as NSString).appendingPathComponent(f)
            guard let e = readDict(p) else { continue }
            if let g = e["game"] as? String, g != bundleID, g != "*" { continue }
            remove(p)
            out.append(e)
        }
        return out
    }

    nonisolated(unsafe) static var poller: DispatchSourceTimer?
    nonisolated(unsafe) static var handlers: [String: ([String: Any]) -> Void] = [:]
    /// Starts watching this player's inbox (after sign-in). Events are handled on the main queue.
    static func startPolling() {
        guard poller == nil else { return }
        MainActor.assumeIsolated { _GCEvents.install() }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(250))
        t.setEventHandler {
            guard GKLocalPlayer.local.isAuthenticated else { return }
            for e in drain() {
                let kind = e["kind"] as? String ?? ""
                if let h = handlers[kind] { h(e) } else { NSLog("isim GameKit: event %@ ignored", kind) }
            }
            for k in tickers.keys.sorted() { tickers[k]?() }
        }
        poller = t
        t.resume()
    }
    /// work repeated with every poll (matchmaking, match files), by name
    nonisolated(unsafe) static var tickers: [String: () -> Void] = [:]
}
