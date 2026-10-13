// isim ActivityKit: Live Activities. Activity.request/update/end write the activity (attributes + content state as
// JSON) to <isim data>/Library/isim/LiveActivities/<id>.plist and tell the device: the home screen asks the app's
// widget extension (ActivityConfiguration) to render the lock-screen view and the Dynamic Island regions, which the
// shell draws on the lock screen and around the island (compact while the app is not in the foreground, minimal when
// two activities run: one attached to the island, one detached; the script command `island` / a tap expands it).
//
// Push updates (adapted): `pushType: .token` gives the activity a push token (`pushToken`, `pushTokenUpdates`), and
// `pushToStartTokenUpdates` a push-to-start token per attributes type. `isim push BUNDLE payload.apns` with an APNs
// liveactivity payload (`aps.event` update / end / start, `content-state`, `timestamp`, `stale-date`,
// `dismissal-date`, `relevance-score`, `alert`, `attributes-type` + `attributes` for start) is applied by the home
// screen (standing in for apsd) to the activity's record; the app sees it through `contentUpdates`,
// `activityStateUpdates` and `Activity.activityUpdates` (a push-started activity), by watching the records.
// Not on isim: broadcast channels (`pushType: .channel`) get no pushes; `frequentPushesEnabled` is false.
import Foundation
import isim_host

public protocol ActivityAttributes: Decodable, Encodable {
    associatedtype ContentState: Decodable, Encodable, Hashable
}
public enum ActivityState: Sendable, Equatable { case active, ended, dismissed, stale, pending }
public struct PushType: Equatable, Sendable {
    let channelID: String?
    init(channel: String? = nil) { channelID = channel }
    public static let token = PushType()
    public static func channel(_ id: String) -> PushType { PushType(channel: id) }
}
public enum ActivityUIDismissalPolicy: Sendable { case `default`, immediate; case after(Date) }
public struct ActivityAuthorizationError: Error, Sendable { public let reason: String }

public struct ActivityContent<State: Decodable & Encodable & Hashable>: Sendable where State: Sendable {
    public let state: State
    public let staleDate: Date?
    public let relevanceScore: Double
    public init(state: State, staleDate: Date?, relevanceScore: Double = 0) { self.state = state; self.staleDate = staleDate; self.relevanceScore = relevanceScore }
}

public struct ActivityAuthorizationInfo: Sendable {
    public init() {}
    public var areActivitiesEnabled: Bool { (Bundle.main.object(forInfoDictionaryKey: "NSSupportsLiveActivities") as? Bool) ?? false }
    public var frequentPushesEnabled: Bool { false }
}

/* how long an ended activity stays on the Lock Screen with the default policy (iOS: up to four hours) */
let _defaultDismissal: TimeInterval = 4 * 3600

enum _ActivityStore {
    static var dir: String {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim"))
        let d = (data as NSString).appendingPathComponent("Library/isim/LiveActivities")
        try? FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true, attributes: nil)
        return d
    }
    static func path(_ id: String) -> String { (dir as NSString).appendingPathComponent(id + ".plist") }
    static func read(_ id: String) -> [String: Any]? { NSDictionary(contentsOfFile: path(id)) as? [String: Any] }
    /// writes the record (keeping what the home screen added, e.g. the push timestamp) and tells the device
    static func write(id: String, type: String, attributes: Data, state: Data, ended: Bool, stale: Date?, extra: [String: Any] = [:], verb: String? = nil) {
        var obj = read(id) ?? [:]
        let fields: [String: Any] = ["id": id, "type": type, "bundle": Bundle.main.bundleIdentifier ?? "", "app": Bundle.main.bundlePath,
                                     "attributes": String(decoding: attributes, as: UTF8.self), "state": String(decoding: state, as: UTF8.self),
                                     "ended": ended, "updated": Date().timeIntervalSince1970, "stale": stale?.timeIntervalSince1970 ?? 0,
                                     "source": "app"]
        obj.merge(fields) { $1 }
        obj.merge(extra) { $1 }
        (obj as NSDictionary).write(toFile: path(id), atomically: true)
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "live-activity", verb ?? (ended ? "end" : "update"), path(id))
    }
    static func hex(_ d: Data) -> String { d.map { String(format: "%02x", $0) }.joined() }
    static func newToken() -> Data { Data((0..<32).map { _ in UInt8.random(in: 0...255) }) }
    static func data(hex: String) -> Data? {
        var d = Data(), i = hex.startIndex
        while i < hex.endIndex {
            let j = hex.index(i, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            guard let b = UInt8(hex[i..<j], radix: 16) else { return nil }
            d.append(b); i = j
        }
        return d
    }
    /// push-to-start tokens: <store>/PushToStart.plist { bundle id: { attributes type: hex } } (the home screen checks it)
    static func pushToStartToken(type: String) -> Data {
        let file = (dir as NSString).appendingPathComponent("PushToStart.plist"), me = Bundle.main.bundleIdentifier ?? ""
        var all = NSDictionary(contentsOfFile: file) as? [String: [String: String]] ?? [:]
        if let h = all[me]?[type], let d = data(hex: h) { return d }
        let t = newToken()
        all[me, default: [:]][type] = hex(t)
        (all as NSDictionary).write(toFile: file, atomically: true)
        return t
    }
}

/// The record watcher: applies changes made outside the app (pushes the home screen applied, stale dates,
/// dismissals) to the app's activities. It reads the records four times a second while the app uses ActivityKit.
enum _ActivityMonitor {
    nonisolated(unsafe) static var handlers: [String: ([String: Any]) -> Void] = [:]
    nonisolated(unsafe) static var timer: DispatchSourceTimer?
    static func register(_ type: String, _ handler: @escaping ([String: Any]) -> Void) {
        if handlers[type] == nil { handlers[type] = handler }
        if timer == nil {
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now() + 0.25, repeating: 0.25)
            t.setEventHandler { poll() }
            t.resume(); timer = t
        }
    }
    static func poll() {
        let me = Bundle.main.bundleIdentifier ?? "", dir = _ActivityStore.dir
        for f in ((try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? []).sorted() where f.hasSuffix(".plist") && f != "PushToStart.plist" {
            guard let rec = NSDictionary(contentsOfFile: (dir as NSString).appendingPathComponent(f)) as? [String: Any],
                  rec["bundle"] as? String == me, let type = rec["type"] as? String, let h = handlers[type] else { continue }
            h(rec)
        }
    }
}

/// the continuations of one async sequence
final class _Continuations<T>: @unchecked Sendable {
    var all: [UUID: AsyncStream<T>.Continuation] = [:]
    let lock = NSLock()
    func stream(initial: T? = nil) -> AsyncStream<T> {
        let k = UUID()
        var cont: AsyncStream<T>.Continuation!
        let s = AsyncStream<T> { cont = $0 }
        lock.lock(); all[k] = cont; lock.unlock()
        cont.onTermination = { _ in self.lock.lock(); self.all[k] = nil; self.lock.unlock() }
        if let v = initial { cont.yield(v) }
        return s
    }
    func yield(_ v: T) { lock.lock(); let cs = Array(all.values); lock.unlock(); for c in cs { c.yield(v) } }
}
final class _TypeStreams: @unchecked Sendable { var updates: AnyObject?; var startTokens = _Continuations<Data>() }
nonisolated(unsafe) var _typeStreams: [String: _TypeStreams] = [:]       /* activityUpdates / push-to-start per attributes type */

public final class Activity<Attributes: ActivityAttributes>: Identifiable, @unchecked Sendable where Attributes.ContentState: Sendable {
    public let id: String
    public let attributes: Attributes
    public private(set) var content: ActivityContent<Attributes.ContentState>
    public private(set) var activityState: ActivityState = .active
    /// the activity's APNs push token (pushType: .token): isim makes one up; an `isim push` payload names it with a
    /// top-level "apns-push-token" to reach this activity
    public var pushToken: Data? { token }
    var token: Data?
    var seenState = ""
    let contents = _Continuations<ActivityContent<Attributes.ContentState>>()
    let states = _Continuations<ActivityState>()
    let tokens = _Continuations<Data>()
    nonisolated(unsafe) static var all: [Activity<Attributes>] { get { _all.compactMap { $0 as? Activity<Attributes> } } }
    /// the ongoing activities (also those a push started or an earlier run of the app requested)
    public static var activities: [Activity<Attributes>] {
        watch(); _ActivityMonitor.poll()
        return all.filter { $0.activityState == .active || $0.activityState == .stale }
    }
    init(id: String = UUID().uuidString, attributes: Attributes, content: ActivityContent<Attributes.ContentState>) {
        self.id = id; self.attributes = attributes; self.content = content
    }
    static var typeName: String { String(describing: Attributes.self) }
    static var streams: _TypeStreams {
        if let s = _typeStreams[typeName] { return s }
        let s = _TypeStreams(); _typeStreams[typeName] = s; return s
    }
    static var updateStreams: _Continuations<Activity<Attributes>> {
        if let u = streams.updates as? _Continuations<Activity<Attributes>> { return u }
        let u = _Continuations<Activity<Attributes>>(); streams.updates = u; return u
    }
    static func watch() { _ActivityMonitor.register(typeName) { apply($0) } }

    func save(verb: String? = nil, extra: [String: Any] = [:]) {
        let enc = JSONEncoder()
        guard let a = try? enc.encode(attributes), let s = try? enc.encode(content.state) else { NSLog("isim ActivityKit: cannot encode the activity"); return }
        seenState = String(decoding: s, as: UTF8.self)
        var x = extra; x["relevance"] = content.relevanceScore
        if let t = token { x["token"] = _ActivityStore.hex(t) }
        _ActivityStore.write(id: id, type: Activity.typeName, attributes: a, state: s, ended: activityState == .ended || activityState == .dismissed,
                             stale: content.staleDate, extra: x, verb: verb)
    }
    func setState(_ s: ActivityState) {
        guard s != activityState else { return }
        activityState = s
        NSLog("isim ActivityKit: Live Activity %@ is %@", id, "\(s)")
        states.yield(s)
    }

    public static func request(attributes: Attributes, content: ActivityContent<Attributes.ContentState>, pushType: PushType? = nil) throws -> Activity<Attributes> {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw ActivityAuthorizationError(reason: "Live Activities need NSSupportsLiveActivities in Info.plist")
        }
        watch()
        let a = Activity(attributes: attributes, content: content)
        if let p = pushType {
            if let ch = p.channelID { NSLog("isim ActivityKit: broadcast channel %@: channel pushes are not delivered on isim", ch) }
            else { a.token = _ActivityStore.newToken() }
        }
        _all.append(a)
        a.save()
        NSLog("isim ActivityKit: requested Live Activity %@ (%@)", a.id, typeName)
        if let t = a.token { NSLog("isim ActivityKit: push token for %@: %@", a.id, _ActivityStore.hex(t)) }
        return a
    }
    @available(*, deprecated)
    public static func request(attributes: Attributes, contentState: Attributes.ContentState, pushType: PushType? = nil) throws -> Activity<Attributes> {
        try request(attributes: attributes, content: ActivityContent(state: contentState, staleDate: nil), pushType: pushType)
    }
    public func update(_ content: ActivityContent<Attributes.ContentState>) async {
        await update(content, alertConfiguration: nil)
    }
    public func update(_ content: ActivityContent<Attributes.ContentState>, alertConfiguration: AlertConfiguration?) async {
        guard activityState == .active || activityState == .stale else { NSLog("isim ActivityKit: %@ has ended; update ignored", id); return }
        self.content = content
        if activityState == .stale, content.staleDate.map({ $0 > Date() }) ?? true { setState(.active) }
        var extra: [String: Any] = [:]
        if let a = alertConfiguration {
            extra = ["alert": ["title": a.title, "body": a.body, "sound": a.soundName], "alertSeq": ((_ActivityStore.read(id)?["alertSeq"] as? Int) ?? 0) + 1]
        }
        save(verb: alertConfiguration == nil ? "update" : "update-alert", extra: extra)
        contents.yield(content)
        NSLog("isim ActivityKit: updated Live Activity %@%@", id, alertConfiguration == nil ? "" : " with an alert")
    }
    public func end(_ content: ActivityContent<Attributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        if let c = content { self.content = c; contents.yield(c) }
        let now = Date().timeIntervalSince1970
        let dismiss: TimeInterval
        switch dismissalPolicy {
        case .immediate: dismiss = now
        case .default: dismiss = now + _defaultDismissal
        case .after(let d): dismiss = min(max(d.timeIntervalSince1970, now), now + _defaultDismissal)
        }
        setState(.ended)
        save(extra: ["dismiss": dismiss])
        NSLog("isim ActivityKit: ended Live Activity %@ (%@)", id, "\(dismissalPolicy)")
    }
    /// every change of the content: the app's own updates and pushes
    public var contentUpdates: AsyncStream<ActivityContent<Attributes.ContentState>> { Activity.watch(); return contents.stream() }
    /// state changes: active → stale (the stale date passed) → ended → dismissed
    public var activityStateUpdates: AsyncStream<ActivityState> { Activity.watch(); return states.stream() }
    /// the push token (at once, when it has one)
    public var pushTokenUpdates: AsyncStream<Data> { tokens.stream(initial: token) }
    /// activities the system started for the app (push-to-start) or that an earlier run of the app requested
    public static var activityUpdates: AsyncStream<Activity<Attributes>> { watch(); return updateStreams.stream() }
    /// the token a server uses to start an activity of this type with a push (iOS 17.2)
    public static var pushToStartToken: Data? { _ActivityStore.pushToStartToken(type: typeName) }
    public static var pushToStartTokenUpdates: AsyncStream<Data> {
        watch()
        let t = _ActivityStore.pushToStartToken(type: typeName)
        NSLog("isim ActivityKit: push-to-start token for %@: %@", typeName, _ActivityStore.hex(t))
        return streams.startTokens.stream(initial: t)
    }

    /// a record changed (or appeared): pushes, the stale date, the dismissal time
    static func apply(_ rec: [String: Any]) {
        guard let id = rec["id"] as? String else { return }
        let now = Date().timeIntervalSince1970, dec = JSONDecoder()
        let ended = rec["ended"] as? Bool ?? false, dismiss = rec["dismiss"] as? Double ?? 0
        let staleT = rec["stale"] as? Double ?? 0, stateJSON = rec["state"] as? String ?? ""
        func content(_ s: Attributes.ContentState) -> ActivityContent<Attributes.ContentState> {
            ActivityContent(state: s, staleDate: staleT > 0 ? Date(timeIntervalSince1970: staleT) : nil, relevanceScore: rec["relevance"] as? Double ?? 0)
        }
        var found = all.first { $0.id == id }
        if found == nil {
            if ended && (dismiss == 0 || now >= dismiss) { return }      /* gone before the app saw it */
            guard let attrs = try? dec.decode(Attributes.self, from: Data((rec["attributes"] as? String ?? "").utf8)),
                  let st = try? dec.decode(Attributes.ContentState.self, from: Data(stateJSON.utf8)) else {
                NSLog("isim ActivityKit: cannot decode Live Activity %@ as %@", id, typeName); return
            }
            let n = Activity(id: id, attributes: attrs, content: content(st))
            n.seenState = stateJSON
            if let h = rec["token"] as? String { n.token = _ActivityStore.data(hex: h) }
            if ended { n.activityState = .ended }
            _all.append(n)
            NSLog("isim ActivityKit: Live Activity %@ (%@) %@", id, typeName, rec["pushStarted"] as? Bool ?? false ? "started by a push" : "found")
            updateStreams.yield(n)
            found = n
        }
        guard let act = found else { return }
        if act.token == nil, let h = rec["token"] as? String, let t = _ActivityStore.data(hex: h) { act.token = t; act.tokens.yield(t) }
        if stateJSON != act.seenState, let st = try? dec.decode(Attributes.ContentState.self, from: Data(stateJSON.utf8)) {
            act.seenState = stateJSON
            act.content = content(st)
            NSLog("isim ActivityKit: Live Activity %@ content updated (%@)", id, rec["source"] as? String ?? "?")
            act.contents.yield(act.content)
            if act.activityState == .stale && (staleT == 0 || staleT > now) { act.setState(.active) }
        }
        if ended && act.activityState != .ended && act.activityState != .dismissed { act.setState(.ended) }
        if ended && dismiss > 0 && now >= dismiss { act.setState(.dismissed) }
        if !ended && act.activityState == .active && staleT > 0 && now >= staleT { act.setState(.stale) }
    }
}
nonisolated(unsafe) var _all: [AnyObject] = []

public struct AlertConfiguration: Sendable {
    let title: String, body: String, soundName: String
    public init(title: String, body: String, sound: AlertSound) {
        self.title = title; self.body = body
        switch sound { case .default: soundName = "default"; case .named(let n): soundName = n }
    }
    public init(title: LocalizedStringResource, body: LocalizedStringResource, sound: AlertSound) {
        self.init(title: title.description, body: body.description, sound: sound)
    }
    public enum AlertSound: Sendable { case `default`; case named(String) }
}

/// For WidgetKit: the JSON of an activity rendered by an ActivityConfiguration (in the widget extension's process).
public enum _IsimActivityRecord {
    public static func load(_ path: String) -> (type: String, attributes: Data, state: Data, ended: Bool)? {
        guard let d = NSDictionary(contentsOfFile: path) as? [String: Any], let t = d["type"] as? String,
              let a = d["attributes"] as? String, let s = d["state"] as? String else { return nil }
        return (t, Data(a.utf8), Data(s.utf8), d["ended"] as? Bool ?? false)
    }
}
