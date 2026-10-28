// isim's SharePlay bus (adapted, issue #392). Real SharePlay rides a FaceTime call through Apple's servers; isim has
// none, so the isim devices on this computer that are "in the same call" share one directory: $ISIM_SHAREPLAY (default
// ~/.local/share/isim-shareplay). A device joins a call with the `shareplay join NAME` script command (or
// ISIM_SHAREPLAY_CALL=NAME at launch); the call it is in is kept in its device data (Library/SharePlay/call), so every
// app on the device sees it. Nothing is sent to Apple.
//
//   calls/<call>/members/<participant>.json                 a device in the call: {id, beat} (a heartbeat each second)
//   calls/<call>/activities/<session>.json                  an activity shared in the call: {id, type, activity, version, ...}
//   calls/<call>/sessions/<session>/joined/<participant>    participants that joined the session
//   calls/<call>/sessions/<session>/ever/<participant>      participants that ever joined (the session ends when they all left)
//   calls/<call>/sessions/<session>/ended                   the session ended
//   calls/<call>/sessions/<session>/inbox/<participant>/…   messages for a participant: {from, type, mode, data}
//   calls/<call>/sessions/<session>/journal/<attachment>.json   journal attachments: {id, type, data, metadata, from}
//
// Each app polls the directory 20 times a second on the main queue. Files are written whole and renamed into place.
import Foundation

final class _SPBus: @unchecked Sendable {  // used on the main queue only
    static let shared = _SPBus()

    static func env(_ name: String) -> String? {
        guard let v = ProcessInfo.processInfo.environment[name], !v.isEmpty else { return nil }
        return v
    }
    static var home: String { env("HOME") ?? "/tmp" }
    let root: String = env("ISIM_SHAREPLAY") ?? (home as NSString).appendingPathComponent(".local/share/isim-shareplay")
    let deviceDir: String = ((env("ISIM_DATA") ?? (home as NSString).appendingPathComponent(".local/share/isim")) as NSString)
        .appendingPathComponent("Library/SharePlay")
    /// this device's participant identifier (kept in the device data)
    let me: UUID
    /// the call this device is in
    private(set) var call: String?
    private var timer: DispatchSourceTimer?
    private var lastBeat = 0.0
    /// live sessions of this process, by session id
    var sessions: [UUID: _SPSessionBase] = [:]
    /// session ids already turned into sessions (or ended), so they are not made twice
    private var seen: Set<UUID> = []
    /// activity types this process knows (sessions() or activate() was called): identifier -> makes a session
    private var factories: [String: (_SPRecord) -> _SPSessionBase?] = [:]
    /// the sessions() streams, by activity identifier
    var streams: [String: [UUID: (_SPSessionBase) -> Void]] = [:]
    /// GroupStateObservers to tell when the call changes
    var callObservers: [UUID: (Bool) -> Void] = [:]

    private init() {
        let idFile = (deviceDir as NSString).appendingPathComponent("participant")
        if let s = try? String(contentsOfFile: idFile, encoding: .utf8), let u = UUID(uuidString: s.trimmingCharacters(in: .whitespacesAndNewlines)) {
            me = u
        } else {
            me = UUID()
            try? FileManager.default.createDirectory(atPath: deviceDir, withIntermediateDirectories: true)
            try? me.uuidString.write(toFile: idFile, atomically: true, encoding: .utf8)
        }
        let callFile = (deviceDir as NSString).appendingPathComponent("call")
        if let c = _SPBus.env("ISIM_SHAREPLAY_CALL") {
            call = c
            try? FileManager.default.createDirectory(atPath: deviceDir, withIntermediateDirectories: true)
            try? c.write(toFile: callFile, atomically: true, encoding: .utf8)
        } else if let c = try? String(contentsOfFile: callFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            call = c
        }
        if let call { NSLog("isim GroupActivities: in the SharePlay call %@ as %@", call, String(me.uuidString.prefix(8))) }
        start()
    }

    // MARK: the call

    /// the `shareplay` script command: join NAME, leave, status
    func command(_ args: [String]) {
        switch args.first {
        case "join":
            setCall(args.count > 1 ? args[1] : "isim")
        case "leave":
            setCall(nil)
        default:
            let others = call.map { _ in members().filter { $0 != me }.count } ?? 0
            NSLog("isim GroupActivities: %@", call.map { "in the SharePlay call \($0) with \(others) other participant(s), \(sessions.count) session(s)" } ?? "not in a SharePlay call")
        }
    }

    func setCall(_ c: String?) {
        guard c != call else { return }
        if call != nil {
            for s in sessions.values { s._callEnded() }
            if let p = memberPath() { unlink(p) }
        }
        call = c
        seen = []
        let callFile = (deviceDir as NSString).appendingPathComponent("call")
        if let c {
            try? FileManager.default.createDirectory(atPath: deviceDir, withIntermediateDirectories: true)
            try? c.write(toFile: callFile, atomically: true, encoding: .utf8)
            lastBeat = 0
            NSLog("isim GroupActivities: joined the SharePlay call %@ as %@", c, String(me.uuidString.prefix(8)))
        } else {
            unlink(callFile)
            NSLog("isim GroupActivities: left the SharePlay call")
        }
        for o in callObservers.values { o(c != nil) }
        poll()
    }

    // MARK: paths and files

    func callPath(_ parts: String...) -> String? {
        guard let call else { return nil }
        return parts.reduce(((root as NSString).appendingPathComponent("calls") as NSString).appendingPathComponent(call)) { ($0 as NSString).appendingPathComponent($1) }
    }
    func sessionPath(_ id: UUID, _ parts: String...) -> String? {
        guard let base = callPath("sessions", id.uuidString) else { return nil }
        return parts.reduce(base) { ($0 as NSString).appendingPathComponent($1) }
    }
    private func memberPath() -> String? { callPath("members", me.uuidString + ".json") }

    static func read(_ p: String) -> [String: Any]? {
        guard let d = FileManager.default.contents(atPath: p) else { return nil }
        return (try? JSONSerialization.jsonObject(with: d)) as? [String: Any]
    }
    static func write(_ p: String, _ obj: Any) {
        try? FileManager.default.createDirectory(atPath: (p as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        guard let d = try? JSONSerialization.data(withJSONObject: obj, options: [.sortedKeys]) else { return }
        let tmp = "\(p).isim-tmp-\(getpid())-\(UInt32.random(in: 0...UInt32.max))"
        guard FileManager.default.createFile(atPath: tmp, contents: d) else { NSLog("isim GroupActivities: cannot write %@", p); return }
        if rename(tmp, p) != 0 { unlink(tmp) }
    }
    static func touch(_ p: String) { write(p, ["t": Date().timeIntervalSince1970]) }
    static func list(_ dir: String) -> [String] {
        ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).filter { !$0.contains(".isim-tmp-") }.sorted()
    }
    static func exists(_ p: String) -> Bool { FileManager.default.fileExists(atPath: p) }

    /// the participants in the call whose heartbeat is fresh
    func members() -> Set<UUID> {
        guard let dir = callPath("members") else { return [] }
        let now = Date().timeIntervalSince1970
        var out: Set<UUID> = []
        for f in _SPBus.list(dir) where f.hasSuffix(".json") {
            guard let d = _SPBus.read((dir as NSString).appendingPathComponent(f)), let beat = d["beat"] as? Double, now - beat < 4,
                  let id = UUID(uuidString: String(f.dropLast(5))) else { continue }
            out.insert(id)
        }
        return out
    }

    // MARK: activities

    func register(_ identifier: String, _ make: @escaping (_SPRecord) -> _SPSessionBase?) {
        if factories[identifier] == nil { factories[identifier] = make; scan() }
    }

    /// shares an activity in the call; returns its session (locally initiated)
    func share(type: String, activity: Data, lifetimeEndsWithInitiator: Bool, title: String?) -> UUID? {
        let id = UUID()
        guard let p = callPath("activities", id.uuidString + ".json") else { return nil }
        _SPBus.write(p, ["id": id.uuidString, "type": type, "activity": activity.base64EncodedString(), "version": 1, "initiator": me.uuidString,
                         "created": Date().timeIntervalSince1970, "endsWithInitiator": lifetimeEndsWithInitiator, "title": title ?? ""])
        NSLog("isim GroupActivities: shared %@ %@ in the call", type, title.map { "“\($0)”" } ?? "")
        scan()
        return id
    }

    private func scan() {
        guard let dir = callPath("activities") else { return }
        for f in _SPBus.list(dir) where f.hasSuffix(".json") {
            guard let id = UUID(uuidString: String(f.dropLast(5))), !seen.contains(id) else { continue }
            guard let r = _SPRecord(_SPBus.read((dir as NSString).appendingPathComponent(f))) else { continue }
            if let e = sessionPath(id, "ended"), _SPBus.exists(e) { seen.insert(id); continue }
            guard let make = factories[r.type] else { continue }
            seen.insert(id)
            guard let s = make(r) else { continue }
            sessions[id] = s
            for y in (streams[r.type] ?? [:]).values { y(s) }
        }
    }

    func start() {
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now(), repeating: .milliseconds(50))
        t.setEventHandler { _SPBus.shared.poll() }
        t.resume()
        timer = t
    }

    func poll() {
        guard call != nil else { return }
        let now = Date().timeIntervalSince1970
        if now - lastBeat >= 1, let p = memberPath() {
            lastBeat = now
            _SPBus.write(p, ["id": me.uuidString, "beat": now])
            for s in sessions.values { s._beat() }
        }
        scan()
        for s in Array(sessions.values) { s._poll() }
    }
}

/// the `shareplay` script command (UIKit's system events call it when the app uses GroupActivities)
@_cdecl("isim_shareplay_command")
public func _isim_shareplay_command(_ args: UnsafePointer<CChar>) {
    let w = String(cString: args).split(separator: " ").map(String.init)
    if Thread.isMainThread { _SPBus.shared.command(w) } else { DispatchQueue.main.async { _SPBus.shared.command(w) } }
}

/// an activity record on the bus
struct _SPRecord {
    let id: UUID, type: String, activity: Data, version: Int, initiator: UUID, endsWithInitiator: Bool
    init?(_ d: [String: Any]?) {
        guard let d, let id = (d["id"] as? String).flatMap(UUID.init(uuidString:)), let type = d["type"] as? String,
              let a = (d["activity"] as? String).flatMap({ Data(base64Encoded: $0) }),
              let ini = (d["initiator"] as? String).flatMap(UUID.init(uuidString:)) else { return nil }
        self.id = id; self.type = type; activity = a; version = d["version"] as? Int ?? 1; initiator = ini
        endsWithInitiator = d["endsWithInitiator"] as? Bool ?? false
    }
}

/// what the bus needs from a GroupSession<A> of any activity type
protocol _SPSessionBase: AnyObject {
    func _poll()
    func _beat()
    func _callEnded()
}
