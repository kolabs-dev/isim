// isim ActivityKit: Live Activities. Activity.request/update/end write the activity (attributes + content state as
// JSON) to <isim data>/Library/isim/LiveActivities/<id>.json and tell the device: the home screen asks the app's
// widget extension (ActivityConfiguration) to render the lock-screen view and the Dynamic Island regions, which the
// shell draws on the lock screen and around the island (compact while the app is not in the foreground; the
// script command `island` / a long press shows the expanded view). Push updates (pushType .token) are not delivered.
import Foundation
import isim_host

public protocol ActivityAttributes: Decodable, Encodable {
    associatedtype ContentState: Decodable, Encodable, Hashable
}
public enum ActivityState: Sendable, Equatable { case active, ended, dismissed, stale, pending }
public struct PushType: Equatable, Sendable { public static let token = PushType(); public static func channel(_ id: String) -> PushType { PushType() } }
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

enum _ActivityStore {
    static var dir: String {
        let data = ProcessInfo.processInfo.environment["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 }
            ?? (((ProcessInfo.processInfo.environment["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim"))
        let d = (data as NSString).appendingPathComponent("Library/isim/LiveActivities")
        try? FileManager.default.createDirectory(atPath: d, withIntermediateDirectories: true, attributes: nil)
        return d
    }
    static func write(id: String, type: String, attributes: Data, state: Data, ended: Bool, stale: Date?) {
        let obj: [String: Any] = ["id": id, "type": type, "bundle": Bundle.main.bundleIdentifier ?? "", "app": Bundle.main.bundlePath,
                                  "attributes": String(decoding: attributes, as: UTF8.self), "state": String(decoding: state, as: UTF8.self),
                                  "ended": ended, "updated": Date().timeIntervalSince1970, "stale": stale?.timeIntervalSince1970 ?? 0]
        let path = (dir as NSString).appendingPathComponent(id + ".plist")
        (obj as NSDictionary).write(toFile: path, atomically: true)
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "live-activity", ended ? "end" : "update", path)
    }
}

public final class Activity<Attributes: ActivityAttributes>: Identifiable, @unchecked Sendable where Attributes.ContentState: Sendable {
    public let id: String
    public let attributes: Attributes
    public private(set) var content: ActivityContent<Attributes.ContentState>
    public private(set) var activityState: ActivityState = .active
    public var pushToken: Data? { nil }
    nonisolated(unsafe) static var all: [Activity<Attributes>] { get { _all.compactMap { $0 as? Activity<Attributes> } } }
    public static var activities: [Activity<Attributes>] { all.filter { $0.activityState == .active } }
    init(attributes: Attributes, content: ActivityContent<Attributes.ContentState>) {
        id = UUID().uuidString; self.attributes = attributes; self.content = content
    }
    static var typeName: String { String(describing: Attributes.self) }
    func save() {
        let enc = JSONEncoder()
        guard let a = try? enc.encode(attributes), let s = try? enc.encode(content.state) else { NSLog("isim ActivityKit: cannot encode the activity"); return }
        _ActivityStore.write(id: id, type: Activity.typeName, attributes: a, state: s, ended: activityState != .active, stale: content.staleDate)
    }
    public static func request(attributes: Attributes, content: ActivityContent<Attributes.ContentState>, pushType: PushType? = nil) throws -> Activity<Attributes> {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw ActivityAuthorizationError(reason: "Live Activities need NSSupportsLiveActivities in Info.plist")
        }
        let a = Activity(attributes: attributes, content: content)
        _all.append(a)
        a.save()
        NSLog("isim ActivityKit: requested Live Activity %@ (%@)", a.id, typeName)
        return a
    }
    @available(*, deprecated)
    public static func request(attributes: Attributes, contentState: Attributes.ContentState, pushType: PushType? = nil) throws -> Activity<Attributes> {
        try request(attributes: attributes, content: ActivityContent(state: contentState, staleDate: nil), pushType: pushType)
    }
    public func update(_ content: ActivityContent<Attributes.ContentState>) async {
        self.content = content; save()
        NSLog("isim ActivityKit: updated Live Activity %@", id)
    }
    public func update(_ content: ActivityContent<Attributes.ContentState>, alertConfiguration: AlertConfiguration?) async { await update(content) }
    public func end(_ content: ActivityContent<Attributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {
        if let c = content { self.content = c }
        activityState = .ended; save()
        NSLog("isim ActivityKit: ended Live Activity %@", id)
    }
    public var contentUpdates: AsyncStream<ActivityContent<Attributes.ContentState>> { AsyncStream { $0.yield(content); $0.finish() } }
    public var activityStateUpdates: AsyncStream<ActivityState> { AsyncStream { $0.yield(activityState); $0.finish() } }
}
nonisolated(unsafe) var _all: [AnyObject] = []

public struct AlertConfiguration: Sendable {
    public init(title: String, body: String, sound: AlertSound) {}
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
