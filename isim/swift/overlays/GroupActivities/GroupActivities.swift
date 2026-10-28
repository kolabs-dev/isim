// isim GroupActivities (self-authored, iOS API names; issue #392): SharePlay activities, sessions, messengers and
// journals over isim's local SharePlay bus (Bus.swift): the isim devices in one simulated call (`shareplay join NAME`)
// share activities, join their sessions, exchange messages and attachments, and keep AVPlayers in step
// (AVPlaybackCoordinator.coordinateWithSession). Unreliable messages are delivered like reliable ones (the bus loses
// nothing).
@_exported import Foundation
import Combine
import UIKit
import CoreGraphics
@_exported import CoreTransferable
import UniformTypeIdentifiers

// MARK: - Activities

/// An app-defined activity people do together over SharePlay.
public protocol GroupActivity: Codable, Sendable, Transferable {
    /// the activity's type, the same on every participant's device
    static var activityIdentifier: String { get }
    /// what the system shows for the activity
    var metadata: GroupActivityMetadata { get async }
}

extension GroupActivity {
    /// the default identifier: the app's bundle identifier and the type's name
    public static var activityIdentifier: String { "\(Bundle.main.bundleIdentifier ?? "app").\(String(describing: Self.self))" }
    public typealias Sessions = GroupSession<Self>.Sessions

    /// Asks whether to share the activity with the call ("SharePlay", "Start Only for Me", "Cancel"). Outside a call:
    /// activationDisabled. ISIM_SHAREPLAY_ACTIVATION=preferred|disabled|cancelled answers without asking.
    public func prepareForActivation() async -> GroupActivityActivationResult {
        let inCall = await MainActor.run { _SPBus.shared.call != nil }
        guard inCall else { return .activationDisabled }
        if let v = _SPBus.env("ISIM_SHAREPLAY_ACTIVATION")?.lowercased() {
            return v.hasPrefix("dis") || v == "only-me" ? .activationDisabled : v.hasPrefix("cancel") ? .cancelled : .activationPreferred
        }
        let title = await metadata.title
        return await withCheckedContinuation { (k: CheckedContinuation<GroupActivityActivationResult, Never>) in
            DispatchQueue.main.async {
                let a = UIAlertController(title: title.map { "Do you want to SharePlay “\($0)”?" } ?? "Do you want to use SharePlay?",
                                          message: "Everyone in the call will be able to join.", preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "SharePlay", style: .default) { _ in k.resume(returning: .activationPreferred) })
                a.addAction(UIAlertAction(title: "Start Only for Me", style: .default) { _ in k.resume(returning: .activationDisabled) })
                a.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in k.resume(returning: .cancelled) })
                guard let top = _SPUI.top() else { k.resume(returning: .activationPreferred); return }
                NSLog("isim GroupActivities: asking whether to SharePlay %@", title ?? "the activity")
                top.present(a, animated: true)
            }
        }
    }

    /// Shares the activity with the call: every participant's app gets a session from sessions(). Returns false outside
    /// a call.
    public func activate() async throws -> Bool {
        let data = try JSONEncoder().encode(self)
        let md = await metadata
        let id: UUID? = await MainActor.run {
            _SPBus.shared.register(Self.activityIdentifier, GroupSession<Self>._make)
            return _SPBus.shared.share(type: Self.activityIdentifier, activity: data,
                                       lifetimeEndsWithInitiator: md.lifetimePolicy == .endsWhenInitiatorLeaves, title: md.title)
        }
        return id != nil
    }

    /// The sessions of this activity type, as they are shared in the call (one already shared is delivered first).
    public static func sessions() -> GroupSession<Self>.Sessions { GroupSession<Self>.Sessions() }

    /// a GroupActivity is shared (ShareLink, drags) as itself
    public static var transferRepresentation: some TransferRepresentation { GroupActivityTransferRepresentation<Self> { $0 } }
}

/// What prepareForActivation decided.
public enum GroupActivityActivationResult: Sendable, Equatable {
    case activationPreferred
    case activationDisabled
    case cancelled
}

/// Shares an item as a group activity (ShareLink, drags): the item becomes the activity `exporting` returns.
public struct GroupActivityTransferRepresentation<Item: Transferable>: TransferRepresentation, @unchecked Sendable {
    let entry: _TransferEntry<Item>
    public init<ActivityType: GroupActivity>(exporting: @escaping @Sendable (Item) async throws -> ActivityType) {
        entry = _TransferEntry(contentType: UTType(exportedAs: "com.apple.group-activity"), importing: nil, exporting: { item in
            let a = try await exporting(item)
            return try JSONSerialization.data(withJSONObject: ["type": ActivityType.activityIdentifier,
                                                               "activity": try JSONEncoder().encode(a).base64EncodedString()])
        })
    }
    public var _isimEntries: [_TransferEntry<Item>] { [entry] }
    public var body: Never { fatalError() }
}

/// What the system shows for an activity: its title, subtitle, preview image, type and how it behaves.
public struct GroupActivityMetadata: Sendable {
    public init() {}
    public var title: String?
    public var subtitle: String?
    public var localizedTitle: String? { get { title } set { title = newValue } }
    public var localizedSubtitle: String? { get { subtitle } set { subtitle = newValue } }
    nonisolated(unsafe) public var previewImage: CGImage?
    public var fallbackURL: URL?
    public var type: ActivityType = .generic
    public var sceneAssociationBehavior: SceneAssociationBehavior = .default
    public var supportsContinuationOnTV = false
    public var preferredBroadcastOptions: BroadcastOptions = []
    public var lifetimePolicy: LifetimePolicy = .automatic
    public var experience: Experience?

    public struct ActivityType: Hashable, Sendable {
        let rawValue: String
        public static let generic = ActivityType(rawValue: "generic")
        public static let listenTogether = ActivityType(rawValue: "listenTogether")
        public static let watchTogether = ActivityType(rawValue: "watchTogether")
        public static let createTogether = ActivityType(rawValue: "createTogether")
        public static let exploreTogether = ActivityType(rawValue: "exploreTogether")
        public static let learnTogether = ActivityType(rawValue: "learnTogether")
        public static let playTogether = ActivityType(rawValue: "playTogether")
        public static let readTogether = ActivityType(rawValue: "readTogether")
        public static let shopTogether = ActivityType(rawValue: "shopTogether")
        public static let workoutTogether = ActivityType(rawValue: "workoutTogether")
    }
    public struct LifetimePolicy: Hashable, Sendable {
        let rawValue: Int
        /// the session ends when every participant has left
        public static let automatic = LifetimePolicy(rawValue: 0)
        /// the session ends when the participant who started it leaves
        public static let endsWhenInitiatorLeaves = LifetimePolicy(rawValue: 1)
    }
    public enum Experience: Hashable, Sendable {
        case listenTogether
        case watchTogether
    }
}

/// Which scene the system brings forward for an activity.
public struct SceneAssociationBehavior: Hashable, Sendable {
    let kind: Int, target: String?
    public static let `default` = SceneAssociationBehavior(kind: 0, target: nil)
    public static let none = SceneAssociationBehavior(kind: 1, target: nil)
    public static func content(_ contentIdentifier: String) -> SceneAssociationBehavior { SceneAssociationBehavior(kind: 2, target: contentIdentifier) }
}

/// How an activity is broadcast to a TV.
public struct BroadcastOptions: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let mirroredVideo = BroadcastOptions(rawValue: 1)
}

// MARK: - Participants

/// A person (a device) in a session.
public struct Participant: Hashable, Identifiable, Sendable {
    public let id: UUID
    /// isim: devices are never near each other
    public var isNearbyWithLocalParticipant: Bool { false }
    init(_ id: UUID) { self.id = id }
}

/// Who a message goes to.
public enum Participants: Sendable, Equatable {
    case all
    case only(Set<Participant>)
    public static func only(_ participant: Participant) -> Participants { .only([participant]) }
}

/// A notice the system shows about a participant's change to the activity.
public struct GroupSessionEvent: Sendable {
    public let originator: Participant
    public let action: Action
    public let url: URL?
    public init(originator: Participant, action: Action, url: URL?) { self.originator = originator; self.action = action; self.url = url }

    public struct Action: Sendable, Hashable {
        let rawValue: String
        public static let play = Action(rawValue: "play")
        public static let pause = Action(rawValue: "pause")
        public static let seek = Action(rawValue: "seek")
        public static let updatedQueue = Action(rawValue: "updatedQueue")
        public static func skip(item: String) -> Action { Action(rawValue: "skip \(item)") }
        public static func updatedQueue(_ change: QueueChange) -> Action { Action(rawValue: "updatedQueue \(change.rawValue)") }

        public struct QueueChange: Sendable, Hashable {
            let rawValue: String
            public static func added(_ item: Item) -> QueueChange { QueueChange(rawValue: "added \(item.rawValue)") }
            public static func setUpNext(_ item: Item) -> QueueChange { QueueChange(rawValue: "setUpNext \(item.rawValue)") }
            public struct Item: Sendable, Hashable {
                let rawValue: String
                public static func song(_ title: String) -> Item { Item(rawValue: "song \(title)") }
                public static func container(_ title: String) -> Item { Item(rawValue: "container \(title)") }
            }
        }
    }
}

/// the error a session is invalidated with
struct _GroupSessionInvalidated: Error, LocalizedError, CustomStringConvertible {
    let why: String
    var errorDescription: String? { why }
    var description: String { why }
}

// MARK: - Sessions

/// A shared activity in the call: its participants join it, follow its activity and talk through messengers.
public final class GroupSession<ActivityType: GroupActivity>: ObservableObject, Identifiable, Hashable, @unchecked Sendable {
    public enum State: Sendable, Equatable {
        case waiting
        case joined
        case invalidated(reason: any Error)
        public static func == (a: State, b: State) -> Bool {
            switch (a, b) {
            case (.waiting, .waiting), (.joined, .joined), (.invalidated, .invalidated): return true
            default: return false
            }
        }
    }

    public let id: UUID
    public let isLocallyInitiated: Bool
    @Published public var activity: ActivityType {
        didSet { if !_applyingRemote { _publishActivity() } }
    }
    @Published public private(set) var state: State = .waiting
    @Published public private(set) var activeParticipants: Set<Participant> = []
    public var localParticipant: Participant { Participant(_SPBus.shared.me) }
    public var sceneSessionIdentifier: String?
    /// isim: spatial coordination is visionOS's; iOS sessions have none
    public var systemCoordinator: SystemCoordinator? { get async { nil } }

    var _version: Int
    var _applyingRemote = false
    let _initiator: UUID
    let _endsWithInitiator: Bool
    var _initiatorSeen = false
    var _done = false
    /// messages with no messenger stream for them yet
    var _pending: [_SPMessage] = []
    var _messengers: [Weak] = []
    var _journals: [WeakJournal] = []
    var _avTransports: [(String, [String: Any]) -> Bool] = []
    struct Weak { weak var m: GroupSessionMessenger? }
    struct WeakJournal { weak var j: GroupSessionJournal? }

    init(_ r: _SPRecord, activity: ActivityType) {
        id = r.id; self.activity = activity; _version = r.version; _initiator = r.initiator; _endsWithInitiator = r.endsWithInitiator
        isLocallyInitiated = r.initiator == _SPBus.shared.me
    }
    static func _make(_ r: _SPRecord) -> _SPSessionBase? {
        guard let a = try? JSONDecoder().decode(ActivityType.self, from: r.activity) else {
            NSLog("isim GroupActivities: cannot decode the %@ activity", r.type); return nil
        }
        return GroupSession(r, activity: a)
    }

    public static func == (a: GroupSession, b: GroupSession) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }

    /// Joins the session: the local participant takes part in its activity and its messages.
    public func join() {
        guard state == .waiting, let p = _SPBus.shared.sessionPath(id, "joined", _SPBus.shared.me.uuidString) else { return }
        _SPBus.touch(p)
        if let e = _SPBus.shared.sessionPath(id, "ever", _SPBus.shared.me.uuidString) { _SPBus.touch(e) }
        state = .joined
        NSLog("isim GroupActivities: joined session %@ (%@)", String(id.uuidString.prefix(8)), ActivityType.activityIdentifier)
        _poll()
    }
    /// Leaves the session; the others keep it.
    public func leave() { _invalidate("The local participant left the session.") }
    /// Ends the session for everyone.
    public func end() {
        if let p = _SPBus.shared.sessionPath(id, "ended") { _SPBus.touch(p) }
        _invalidate("The session ended.")
    }
    /// isim: the app is already in front
    public func requestForegroundPresentation() { NSLog("isim GroupActivities: foreground presentation requested") }
    /// Shows a notice about a participant's change (isim: logged).
    public func showNotice(_ event: GroupSessionEvent) {
        NSLog("isim GroupActivities: notice %@ %@", String(event.originator.id.uuidString.prefix(8)), event.action.rawValue)
    }
    /// Sends a notice to the other participants (isim: they log it).
    public func postEvent(_ event: Event) {
        _send(type: "isim.event", mode: "reliable", data: Data(event.localizedDescription.utf8), to: .all)
    }

    /// A notice a participant posts to the others.
    public struct Event: Sendable {
        public let originator: Participant
        public var localizedDescription: String
        public init(originator: Participant, localizedDescription: String) { self.originator = originator; self.localizedDescription = localizedDescription }
    }

    // MARK: Sessions sequence

    /// The sessions of an activity type, as they are shared.
    public struct Sessions: AsyncSequence, Sendable {
        public typealias Element = GroupSession<ActivityType>
        public struct Iterator: AsyncIteratorProtocol {
            var it: AsyncStream<GroupSession<ActivityType>>.Iterator
            public mutating func next() async -> GroupSession<ActivityType>? { await it.next() }
        }
        public func makeAsyncIterator() -> Iterator {
            let type = ActivityType.activityIdentifier
            let stream = AsyncStream<GroupSession<ActivityType>> { k in
                DispatchQueue.main.async {
                    let bus = _SPBus.shared, key = UUID()
                    var delivered = Set<UUID>()
                    let yield: (_SPSessionBase) -> Void = { s in
                        guard let s = s as? GroupSession<ActivityType>, !s._done, delivered.insert(s.id).inserted else { return }
                        k.yield(s)
                    }
                    bus.streams[type, default: [:]][key] = yield
                    for s in bus.sessions.values { yield(s) }
                    bus.register(type, GroupSession<ActivityType>._make)
                    k.onTermination = { _ in DispatchQueue.main.async { _SPBus.shared.streams[type]?[key] = nil } }
                }
            }
            return Iterator(it: stream.makeAsyncIterator())
        }
    }

    // MARK: the bus

    func _invalidate(_ why: String) {
        guard !_done else { return }
        _done = true
        let bus = _SPBus.shared
        if let p = bus.sessionPath(id, "joined", bus.me.uuidString) { unlink(p) }
        state = .invalidated(reason: _GroupSessionInvalidated(why: why))
        activeParticipants = []
        bus.sessions[id] = nil
        NSLog("isim GroupActivities: session %@ invalidated: %@", String(id.uuidString.prefix(8)), why)
    }

    func _publishActivity() {
        guard let p = _SPBus.shared.callPath("activities", id.uuidString + ".json"), var d = _SPBus.read(p),
              let data = try? JSONEncoder().encode(activity) else { return }
        _version = max(_version, d["version"] as? Int ?? 1) + 1
        d["activity"] = data.base64EncodedString(); d["version"] = _version
        _SPBus.write(p, d)
    }

    func _send(type: String, mode: String, data: Data, to: Participants) {
        let bus = _SPBus.shared
        let targets: Set<UUID>
        switch to {
        case .all: targets = Set(activeParticipants.map(\.id)).subtracting([bus.me])
        case .only(let ps): targets = Set(ps.map(\.id)).subtracting([bus.me])
        }
        let name = String(format: "%.6f-%@.json", Date().timeIntervalSince1970, UUID().uuidString)
        for t in targets {
            guard let p = bus.sessionPath(id, "inbox", t.uuidString, name) else { continue }
            _SPBus.write(p, ["from": bus.me.uuidString, "type": type, "mode": mode, "data": data.base64EncodedString()])
        }
    }

    func _poll() {
        guard !_done else { return }
        let bus = _SPBus.shared
        if let e = bus.sessionPath(id, "ended"), _SPBus.exists(e) { _invalidate("The session ended."); return }
        // the activity, if another participant changed it
        if let p = bus.callPath("activities", id.uuidString + ".json"), let r = _SPRecord(_SPBus.read(p)), r.version > _version,
           let a = try? JSONDecoder().decode(ActivityType.self, from: r.activity) {
            _version = r.version
            _applyingRemote = true; activity = a; _applyingRemote = false
        }
        guard state == .joined, let jd = bus.sessionPath(id, "joined") else { return }
        // the participants: joined, and still in the call
        let members = bus.members()
        var active = Set(_SPBus.list(jd).compactMap(UUID.init(uuidString:)).filter { members.contains($0) || $0 == bus.me }.map(Participant.init))
        active.insert(localParticipant)
        if active != activeParticipants {
            let added = active.subtracting(activeParticipants)
            activeParticipants = active
            if !added.subtracting([localParticipant]).isEmpty { for m in _messengers { m.m?._participantsJoined() } }
        }
        // the lifetime: everyone who joined has left, or the initiator left
        if _endsWithInitiator && !isLocallyInitiated {
            if active.contains(Participant(_initiator)) { _initiatorSeen = true }
            else if _initiatorSeen { if let p = bus.sessionPath(id, "ended") { _SPBus.touch(p) }; _invalidate("The session ended."); return }
        }
        // messages
        if let inbox = bus.sessionPath(id, "inbox", bus.me.uuidString) {
            for f in _SPBus.list(inbox) where f.hasSuffix(".json") {
                let p = (inbox as NSString).appendingPathComponent(f)
                guard let d = _SPBus.read(p) else { continue }
                unlink(p)
                guard let from = (d["from"] as? String).flatMap(UUID.init(uuidString:)), let type = d["type"] as? String,
                      let data = (d["data"] as? String).flatMap({ Data(base64Encoded: $0) }) else { continue }
                _deliver(_SPMessage(type: type, mode: d["mode"] as? String ?? "reliable", data: data, from: Participant(from)))
            }
        }
        for j in _journals { j.j?._poll() }
    }

    func _deliver(_ m: _SPMessage) {
        if m.type == "isim.event" {
            NSLog("isim GroupActivities: event from %@: %@", String(m.from.id.uuidString.prefix(8)), String(decoding: m.data, as: UTF8.self))
            return
        }
        if m.type == "isim.av", let d = (try? JSONSerialization.jsonObject(with: m.data)) as? [String: Any] {
            for t in _avTransports { _ = t(m.type, d) }
            return
        }
        var taken = false
        for w in _messengers { if let me = w.m, me._take(m) { taken = true } }
        if !taken { _pending.append(m) }
    }

    func _beat() {
        guard state == .joined, !_done, let p = _SPBus.shared.sessionPath(id, "joined", _SPBus.shared.me.uuidString) else { return }
        _SPBus.touch(p)
    }
    func _callEnded() { _invalidate("The local participant left the call.") }
}

extension GroupSession: _SPSessionBase {}

struct _SPMessage { let type: String, mode: String, data: Data, from: Participant }

// MARK: - Messengers

/// A message type's identifier on the wire (the type's name, unless it conforms to CustomMessageIdentifiable).
public protocol CustomMessageIdentifiable {
    static var messageIdentifier: String { get }
}

/// Sends messages to a session's participants and receives theirs.
public final class GroupSessionMessenger: @unchecked Sendable {
    public enum DeliveryMode: Sendable, Equatable {
        case reliable
        case unreliable
    }
    /// The context of a received message: who sent it.
    public struct MessageContext: Sendable {
        public var source: Participant
    }

    public let deliveryMode: DeliveryMode
    let _session: AnyObject
    let _send: (String, String, Data, Participants) -> Void
    let _isJoined: () -> Bool
    let _takePending: (String, String) -> [_SPMessage]
    var _streams: [String: [UUID: (_SPMessage) -> Void]] = [:]

    public convenience init<Activity: GroupActivity>(session: GroupSession<Activity>) { self.init(session: session, deliveryMode: .reliable) }
    public init<Activity: GroupActivity>(session: GroupSession<Activity>, deliveryMode: DeliveryMode) {
        self.deliveryMode = deliveryMode
        _session = session
        _send = { [weak session] t, m, d, to in session?._send(type: t, mode: m, data: d, to: to) }
        _isJoined = { [weak session] in session?.state == .joined }
        _takePending = { [weak session] t, m in
            guard let session else { return [] }
            let out = session._pending.filter { $0.type == t && $0.mode == m }
            session._pending.removeAll { $0.type == t && $0.mode == m }
            return out
        }
        let add = { [weak session, weak self] in session?._messengers.append(GroupSession<Activity>.Weak(m: self)) }
        if Thread.isMainThread { add() } else { DispatchQueue.main.sync(execute: add) }
    }

    var _mode: String { deliveryMode == .reliable ? "reliable" : "unreliable" }
    static func _id<M>(_ t: M.Type) -> String { (t as? CustomMessageIdentifiable.Type)?.messageIdentifier ?? String(reflecting: t) }

    func _take(_ m: _SPMessage) -> Bool {
        guard m.mode == _mode, let s = _streams[m.type], !s.isEmpty else { return false }
        for y in s.values { y(m) }
        return true
    }
    func _participantsJoined() {}

    func _sendData(_ type: String, _ data: Data, _ to: Participants) async throws {
        let ok = await MainActor.run { () -> Bool in
            guard _isJoined() else { return false }
            _send(type, _mode, data, to)
            return true
        }
        if !ok { throw _GroupSessionInvalidated(why: "The session is not joined.") }
    }

    public func send(_ value: Data, to participants: Participants = .all) async throws {
        try await _sendData(Self._id(Data.self), value, participants)
    }
    public func send<Message: Encodable & Sendable>(_ value: Message, to participants: Participants = .all) async throws {
        try await _sendData(Self._id(Message.self), try JSONEncoder().encode(value), participants)
    }
    public func send(_ value: Data, to participants: Participants = .all, completion: @escaping @Sendable ((any Error)?) -> Void) {
        Task { do { try await send(value, to: participants); completion(nil) } catch { completion(error) } }
    }
    public func send<Message: Encodable & Sendable>(_ value: Message, to participants: Participants = .all, completion: @escaping @Sendable ((any Error)?) -> Void) {
        Task { do { try await send(value, to: participants); completion(nil) } catch { completion(error) } }
    }

    public func messages(of type: Data.Type) -> Messages<Data> { Messages(messenger: self, decode: { $0 }) }
    public func messages<Message: Decodable & Sendable>(of type: Message.Type) -> Messages<Message> {
        Messages(messenger: self, decode: { try? JSONDecoder().decode(Message.self, from: $0) })
    }

    /// The messages of one type, with their contexts.
    public struct Messages<Message: Sendable>: AsyncSequence, @unchecked Sendable {
        public typealias Element = (Message, MessageContext)
        let messenger: GroupSessionMessenger
        let decode: (Data) -> Message?
        public struct Iterator: AsyncIteratorProtocol {
            var it: AsyncStream<(Message, MessageContext)>.Iterator
            public mutating func next() async -> (Message, MessageContext)? { await it.next() }
        }
        public func makeAsyncIterator() -> Iterator {
            let m = messenger, decode = decode, type = GroupSessionMessenger._id(Message.self)
            let stream = AsyncStream<(Message, MessageContext)> { k in
                DispatchQueue.main.async {
                    let key = UUID()
                    let y: (_SPMessage) -> Void = { msg in if let v = decode(msg.data) { k.yield((v, MessageContext(source: msg.from))) } }
                    m._streams[type, default: [:]][key] = y
                    for msg in m._takePending(type, m._mode) { y(msg) }
                    k.onTermination = { _ in DispatchQueue.main.async { m._streams[type]?[key] = nil } }
                }
            }
            return Iterator(it: stream.makeAsyncIterator())
        }
    }
}

// MARK: - Journals

/// Files (Transferable items) shared with a session's participants, kept while the session lasts.
public final class GroupSessionJournal: @unchecked Sendable {
    /// An item in the journal.
    public struct Attachment: Identifiable, Sendable, Hashable {
        public var id: UUID
        let path: String
        public static func == (a: Attachment, b: Attachment) -> Bool { a.id == b.id }
        public func hash(into h: inout Hasher) { h.combine(id) }
        public func load<AttachmentType: Transferable>(_ type: AttachmentType.Type) async throws -> AttachmentType {
            guard let d = _SPBus.read(path), let data = (d["data"] as? String).flatMap({ Data(base64Encoded: $0) }),
                  let t = (d["contentType"] as? String).flatMap({ UTType($0) }) else { throw _GroupSessionInvalidated(why: "The attachment was removed.") }
            guard let v = try await AttachmentType._isimImport(data, contentType: t) else {
                throw CocoaError(.coderReadCorrupt)
            }
            return v
        }
        public func loadMetadata<MetadataType: Decodable & Sendable>(of type: MetadataType.Type) async throws -> MetadataType {
            guard let d = _SPBus.read(path), let m = (d["metadata"] as? String).flatMap({ Data(base64Encoded: $0) }) else { throw CocoaError(.coderValueNotFound) }
            return try JSONDecoder().decode(MetadataType.self, from: m)
        }
    }

    /// The journal's attachments: the current list, then the list each time it changes.
    public struct Attachments: AsyncSequence, @unchecked Sendable {
        public typealias Element = [Attachment]
        let journal: GroupSessionJournal
        public struct Iterator: AsyncIteratorProtocol {
            var it: AsyncStream<[Attachment]>.Iterator
            public mutating func next() async -> [Attachment]? { await it.next() }
        }
        public func makeAsyncIterator() -> Iterator {
            let j = journal
            let stream = AsyncStream<[Attachment]> { k in
                DispatchQueue.main.async {
                    let key = UUID()
                    j._observers[key] = { k.yield($0) }
                    k.yield(j._current)
                    k.onTermination = { _ in DispatchQueue.main.async { j._observers[key] = nil } }
                }
            }
            return Iterator(it: stream.makeAsyncIterator())
        }
    }

    let _dir: () -> String?
    var _current: [Attachment] = []
    var _observers: [UUID: ([Attachment]) -> Void] = [:]

    public convenience init<Activity: GroupActivity>(session: GroupSession<Activity>) {
        let id = session.id
        self.init(dir: { _SPBus.shared.sessionPath(id, "journal") })
        let add = { [weak session, weak self] in
            session?._journals.append(GroupSession<Activity>.WeakJournal(j: self)); self?._poll()
        }
        if Thread.isMainThread { add() } else { DispatchQueue.main.sync(execute: add) }
    }
    init(dir: @escaping () -> String?) { _dir = dir }

    public var attachments: Attachments { Attachments(journal: self) }

    public func add<ItemType: Transferable>(_ item: ItemType) async throws -> Attachment { try await _add(item, metadata: nil) }
    public func add<ItemType: Transferable, MetadataType: Encodable & Sendable>(_ item: ItemType, metadata: MetadataType) async throws -> Attachment {
        try await _add(item, metadata: try JSONEncoder().encode(metadata))
    }
    func _add<ItemType: Transferable>(_ item: ItemType, metadata: Data?) async throws -> Attachment {
        guard let e = item._isimExportEntries.first, let export = e.exporting else { throw CocoaError(.coderInvalidValue) }
        let data = try await export(item)
        let id = UUID()
        let type = e.contentType.identifier
        return try await MainActor.run {
            guard let dir = _dir() else { throw _GroupSessionInvalidated(why: "Not in a SharePlay call.") }
            let p = (dir as NSString).appendingPathComponent(id.uuidString + ".json")
            var d: [String: Any] = ["id": id.uuidString, "contentType": type, "data": data.base64EncodedString(), "from": _SPBus.shared.me.uuidString,
                                    "added": Date().timeIntervalSince1970]
            if let metadata { d["metadata"] = metadata.base64EncodedString() }
            _SPBus.write(p, d)
            _poll()
            return Attachment(id: id, path: p)
        }
    }
    public func remove(attachment: Attachment) async throws {
        await MainActor.run { unlink(attachment.path); _poll() }
    }

    func _poll() {
        guard let dir = _dir() else { return }
        let files = _SPBus.list(dir).filter { $0.hasSuffix(".json") }
        let ids = files.compactMap { UUID(uuidString: String($0.dropLast(5))) }
        guard ids != _current.map(\.id) else { return }
        // in the order they were added
        let items = ids.map { id -> (Double, Attachment) in
            let p = (dir as NSString).appendingPathComponent(id.uuidString + ".json")
            return (_SPBus.read(p)?["added"] as? Double ?? 0, Attachment(id: id, path: p))
        }.sorted { $0.0 < $1.0 }.map(\.1)
        guard items.map(\.id) != _current.map(\.id) else { return }
        _current = items
        for o in _observers.values { o(items) }
    }
}

// MARK: - Eligibility

/// Whether the device is in a call where SharePlay can start.
public final class GroupStateObserver: ObservableObject, @unchecked Sendable {
    @Published public private(set) var isEligibleForGroupSession: Bool = false
    let key = UUID()
    public convenience init() { self.init(_isim: ()) }
    init(_isim: Void) {
        let setup = { [weak self] in
            guard let self else { return }
            self.isEligibleForGroupSession = _SPBus.shared.call != nil
            _SPBus.shared.callObservers[self.key] = { [weak self] v in self?.isEligibleForGroupSession = v }
        }
        if Thread.isMainThread { setup() } else { DispatchQueue.main.sync(execute: setup) }
    }
    deinit { let k = key; DispatchQueue.main.async { _SPBus.shared.callObservers[k] = nil } }
}

enum _SPUI {
    static func top() -> UIViewController? {
        guard var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController else { return nil }
        while let p = top.presentedViewController { top = p }
        return top
    }
}
