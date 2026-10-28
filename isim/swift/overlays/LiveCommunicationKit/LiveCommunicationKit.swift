// isim LiveCommunicationKit (adapted, on isim's CallKit engine): a ConversationManager owns a CallKit provider, so its
// conversations get the system call UI (incoming banner or full screen, ringtone, in-call screen, the call pill) and
// the audio session like CallKit calls. What the user does there arrives as conversation actions (join, end, mute,
// pause, tones) given to the manager's delegate; the app's own actions (perform(_:)) are checked like CallKit's
// requests, then given to the delegate too; fulfilling or failing an action changes the conversation (state, mute,
// pause), and the delegate hears conversationChanged. An action not completed by its timeoutDate fails after
// conversationManager(_:timedOutPerforming:). SetTranslatingAction (iOS 26) has no CallKit counterpart: it goes to
// the delegate alone. Ended conversations go to the app's recents (ConversationHistoryManager, iOS 26) unless the
// configuration excludes them: $ISIM_DATA/Library/isim/Conversations/<bundle ID>.json. Stubs, like Apple's Simulator:
// TelephonyConversationManager has no cellular services (isim has no telephony); LiveAssistance extensions are not run.
// Same API as Apple's; Swift only, like Apple's.
import Foundation
import AVFoundation
import CallKit

// MARK: - handles

@available(iOS 17.4, *)
public struct Handle: Hashable, Sendable, Codable {
    public enum Kind: Hashable, Sendable, Codable { case generic, phoneNumber, emailAddress }
    public var type: Kind
    public var value: String
    public var displayName: String
    public init(type: Kind, value: String, displayName: String?) { self.type = type; self.value = value; self.displayName = displayName ?? value }
    var cx: CXHandle { CXHandle(type: type == .phoneNumber ? .phoneNumber : type == .emailAddress ? .emailAddress : .generic, value: value) }
}

// MARK: - conversations

@available(iOS 17.4, *)
public final class Conversation: @unchecked Sendable, Hashable, CustomStringConvertible {
    public enum State: Hashable, Sendable { case idle, joining, joined, leaving, left, paused }
    public enum EndedReason: Hashable, Sendable { case failed, remoteEnded, unanswered, joinedElsewhere, declinedElsewhere }
    public enum Event: Sendable {
        case conversationStartedConnecting(Date)
        case conversationConnected(Date)
        case conversationUpdated(Update)
        case conversationEnded(Date, EndedReason)
    }
    public struct Capabilities: OptionSet, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let pausing = Capabilities(rawValue: 1 << 0)
        public static let merging = Capabilities(rawValue: 1 << 1)
        public static let unmerging = Capabilities(rawValue: 1 << 2)
        public static let playingTones = Capabilities(rawValue: 1 << 3)
        public static let video = Capabilities(rawValue: 1 << 4)
    }
    public struct Update: Hashable, Sendable {
        public var localMember: Handle?
        public var members: Set<Handle>?
        public var activeRemoteMembers: Set<Handle>?
        public var capabilities: Capabilities?
        public init(localMember: Handle? = nil, members: Set<Handle>? = nil, activeRemoteMembers: Set<Handle>? = nil, capabilities: Capabilities? = nil) {
            self.localMember = localMember; self.members = members; self.activeRemoteMembers = activeRemoteMembers; self.capabilities = capabilities
        }
    }

    public let uuid: UUID
    public internal(set) var state: State
    public internal(set) var localMember: Handle?
    public internal(set) var members: Set<Handle> = []
    public internal(set) var activeRemoteMembers: Set<Handle> = []
    public internal(set) var capabilities: Capabilities = []
    public internal(set) var isMuted = false
    public internal(set) var isVideo = false
    let isOutgoing: Bool
    var started = Date(), connected: Date?

    init(uuid: UUID, outgoing: Bool, state: State) { self.uuid = uuid; isOutgoing = outgoing; self.state = state }
    func apply(_ u: Update) {
        if let m = u.localMember { localMember = m }
        if let m = u.members { members = m }
        if let m = u.activeRemoteMembers { activeRemoteMembers = m }
        if let c = u.capabilities { capabilities = c; isVideo = isVideo || c.contains(.video) }
    }
    var remote: Handle? { activeRemoteMembers.sorted { $0.value < $1.value }.first ?? members.filter { $0 != localMember }.sorted { $0.value < $1.value }.first }
    var cxUpdate: CXCallUpdate {
        let u = CXCallUpdate()
        if let r = remote { u.remoteHandle = r.cx; u.localizedCallerName = r.displayName }
        u.supportsHolding = capabilities.contains(.pausing)
        u.supportsGrouping = capabilities.contains(.merging)
        u.supportsUngrouping = capabilities.contains(.unmerging)
        u.supportsDTMF = capabilities.contains(.playingTones)
        u.hasVideo = isVideo
        return u
    }
    public static func == (a: Conversation, b: Conversation) -> Bool { a.uuid == b.uuid }
    public func hash(into h: inout Hasher) { h.combine(uuid) }
    public var description: String { "Conversation(\(uuid.uuidString), \(state))" }
}

// MARK: - actions

@available(iOS 17.4, *)
open class ConversationAction: @unchecked Sendable, CustomStringConvertible {
    public enum State: Hashable, Sendable { case idle, running, complete, failed(reason: String) }
    public let uuid = UUID()
    public let conversationUUID: UUID
    public let timeoutDate: Date
    public internal(set) var state: State = .idle
    var cx: CXCallAction?
    weak var manager: ConversationManager?
    init(conversationUUID: UUID, timeout: Date) { self.conversationUUID = conversationUUID; timeoutDate = timeout }
    public convenience init(conversationUUID: UUID, timeoutDate: Date) { self.init(conversationUUID: conversationUUID, timeout: timeoutDate) }

    /// the action is done: the conversation changes
    public func fulfill() { finish(nil) }
    public func fail() { finish("failed") }
    func finish(_ failure: String?) {
        guard state == .running || state == .idle else { NSLog("isim: LiveCommunicationKit: %@ was already completed", "\(self)"); return }
        state = failure.map { .failed(reason: $0) } ?? .complete
        manager?.completed(self, ok: failure == nil)
        if let cx { failure == nil ? cx.fulfill() : cx.fail() }
        if failure == nil, self is StartConversationAction, let m = manager, let c = m.conversations.first(where: { $0.uuid == conversationUUID }) {
            m.provider.reportCall(with: c.uuid, updated: c.cxUpdate)   // the call UI shows the handle's display name
        }
    }
    var name: String { "action" }
    func makeCX() -> CXCallAction? { nil }
    public var description: String { "\(type(of: self))(\(conversationUUID.uuidString))" }
}

@available(iOS 17.4, *)
public final class StartConversationAction: ConversationAction, @unchecked Sendable {
    public let handles: [Handle]
    public let isVideo: Bool
    public init(conversationUUID: UUID, handles: [Handle], isVideo: Bool) {
        self.handles = handles; self.isVideo = isVideo
        super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30))
    }
    public func fulfill(dateStarted: Date) { fulfill() }
    override var name: String { "start" }
    override func makeCX() -> CXCallAction? {
        guard let first = handles.first else { return nil }
        let a = CXStartCallAction(call: conversationUUID, handle: first.cx)
        a.isVideo = isVideo
        return a
    }
}
@available(iOS 17.4, *)
public final class JoinConversationAction: ConversationAction, @unchecked Sendable {
    public init(conversationUUID: UUID) { super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    public func fulfill(dateConnected: Date) { fulfill() }
    override var name: String { "join" }
    override func makeCX() -> CXCallAction? { CXAnswerCallAction(call: conversationUUID) }
}
@available(iOS 17.4, *)
public final class EndConversationAction: ConversationAction, @unchecked Sendable {
    public init(conversationUUID: UUID) { super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    public func fulfill(dateEnded: Date) { fulfill() }
    override var name: String { "end" }
    override func makeCX() -> CXCallAction? { CXEndCallAction(call: conversationUUID) }
}
@available(iOS 17.4, *)
public final class MuteConversationAction: ConversationAction, @unchecked Sendable {
    public let isMuted: Bool
    public init(conversationUUID: UUID, isMuted: Bool) { self.isMuted = isMuted; super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    override var name: String { isMuted ? "mute" : "unmute" }
    override func makeCX() -> CXCallAction? { CXSetMutedCallAction(call: conversationUUID, muted: isMuted) }
}
@available(iOS 17.4, *)
public final class PauseConversationAction: ConversationAction, @unchecked Sendable {
    public let isPaused: Bool
    public init(conversationUUID: UUID, isPaused: Bool) { self.isPaused = isPaused; super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    override var name: String { isPaused ? "pause" : "resume" }
    override func makeCX() -> CXCallAction? { CXSetHeldCallAction(call: conversationUUID, onHold: isPaused) }
}
@available(iOS 17.4, *)
public final class MergeConversationAction: ConversationAction, @unchecked Sendable {
    public let conversationUUIDToMergeWith: UUID
    public init(conversationUUID: UUID, conversationUUIDToMergeWith: UUID) {
        self.conversationUUIDToMergeWith = conversationUUIDToMergeWith
        super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30))
    }
    override var name: String { "merge" }
    override func makeCX() -> CXCallAction? { CXSetGroupCallAction(call: conversationUUID, callUUIDToGroupWith: conversationUUIDToMergeWith) }
}
@available(iOS 17.4, *)
public final class UnmergeConversationAction: ConversationAction, @unchecked Sendable {
    public init(conversationUUID: UUID) { super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    override var name: String { "unmerge" }
    override func makeCX() -> CXCallAction? { CXSetGroupCallAction(call: conversationUUID, callUUIDToGroupWith: nil) }
}
@available(iOS 17.4, *)
public final class PlayToneAction: ConversationAction, @unchecked Sendable {
    public enum Tone: Hashable, Sendable { case single, softPause, hardPause }
    public let digits: String
    public let tone: Tone
    public init(conversationUUID: UUID, digits: String, tone: Tone) { self.digits = digits; self.tone = tone; super.init(conversationUUID: conversationUUID, timeout: Date(timeIntervalSinceNow: 30)) }
    override var name: String { "tones \(digits)" }
    override func makeCX() -> CXCallAction? {
        CXPlayDTMFCallAction(call: conversationUUID, digits: digits, type: tone == .single ? .singleTone : tone == .softPause ? .softPause : .hardPause)
    }
}
@available(iOS 26.0, *)
public final class SetTranslatingAction: ConversationAction, @unchecked Sendable {
    public enum TranslationEngine: Hashable, Sendable { case `default`, custom }
    public let isTranslating: Bool
    public let localLanguage: Locale.Language
    public let remoteLanguage: Locale.Language
    var engine: TranslationEngine?
    public init(conversationID: UUID, isTranslating: Bool, localLanguage: Locale.Language, remoteLanguage: Locale.Language) {
        self.isTranslating = isTranslating; self.localLanguage = localLanguage; self.remoteLanguage = remoteLanguage
        super.init(conversationUUID: conversationID, timeout: Date(timeIntervalSinceNow: 30))
    }
    /// translating with the system's engine or the app's own
    public func fulfill(using engine: TranslationEngine) { self.engine = engine; fulfill() }
    override var name: String { isTranslating ? "translate" : "stop translating" }
}

// MARK: - the manager

@available(iOS 17.4, *)
public protocol ConversationManagerDelegate: AnyObject, Sendable {
    func conversationManagerDidBegin(_ manager: ConversationManager)
    func conversationManagerDidReset(_ manager: ConversationManager)
    func conversationManager(_ manager: ConversationManager, conversationChanged conversation: Conversation)
    func conversationManager(_ manager: ConversationManager, perform action: ConversationAction)
    func conversationManager(_ manager: ConversationManager, timedOutPerforming action: ConversationAction)
    func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession)
    func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession)
}
@available(iOS 17.4, *)
extension ConversationManagerDelegate {
    public func conversationManagerDidBegin(_ manager: ConversationManager) {}
    public func conversationManager(_ manager: ConversationManager, didActivate audioSession: AVAudioSession) {}
    public func conversationManager(_ manager: ConversationManager, didDeactivate audioSession: AVAudioSession) {}
}

@available(iOS 17.4, *)
public final class ConversationManager: @unchecked Sendable {
    public struct Configuration: Hashable, Sendable {
        public var ringtoneName: String?
        public var iconTemplateImageData: Data?
        public var maximumConversationGroups: Int
        public var maximumConversationsPerConversationGroup: Int
        public var includesConversationInRecents: Bool
        public var supportsVideo: Bool
        public var supportedHandleTypes: Set<Handle.Kind>
        public var supportsAudioTranslation: Bool
        public init(ringtoneName: String?, iconTemplateImageData: Data?, maximumConversationGroups: Int, maximumConversationsPerConversationGroup: Int,
                    includesConversationInRecents: Bool, supportsVideo: Bool, supportedHandleTypes: Set<Handle.Kind>) {
            self.init(ringtoneName: ringtoneName, iconTemplateImageData: iconTemplateImageData, maximumConversationGroups: maximumConversationGroups,
                      maximumConversationsPerConversationGroup: maximumConversationsPerConversationGroup,
                      includesConversationInRecents: includesConversationInRecents, supportsVideo: supportsVideo,
                      supportedHandleTypes: supportedHandleTypes, supportsAudioTranslation: false)
        }
        public init(ringtoneName: String?, iconTemplateImageData: Data?, maximumConversationGroups: Int, maximumConversationsPerConversationGroup: Int,
                    includesConversationInRecents: Bool, supportsVideo: Bool, supportedHandleTypes: Set<Handle.Kind>, supportsAudioTranslation: Bool) {
            self.ringtoneName = ringtoneName; self.iconTemplateImageData = iconTemplateImageData
            self.maximumConversationGroups = maximumConversationGroups
            self.maximumConversationsPerConversationGroup = maximumConversationsPerConversationGroup
            self.includesConversationInRecents = includesConversationInRecents; self.supportsVideo = supportsVideo
            self.supportedHandleTypes = supportedHandleTypes; self.supportsAudioTranslation = supportsAudioTranslation
        }
    }

    public let configuration: Configuration
    public weak var delegate: (any ConversationManagerDelegate)? {
        didSet { if delegate != nil { DispatchQueue.main.async { [self] in self.delegate?.conversationManagerDidBegin(self) } } }
    }
    let provider: CXProvider
    let controller = CXCallController()
    private let bridge: _Bridge
    private var byUUID: [UUID: Conversation] = [:]
    private var order: [UUID] = []
    private var running: [ConversationAction] = []
    private var invalidated = false
    nonisolated(unsafe) static weak var current: ConversationManager?

    public convenience init(configuration: Configuration) { self.init(configuration, ()) }
    private init(_ configuration: Configuration, _: Void) {
        self.configuration = configuration
        let c = CXProviderConfiguration()
        c.ringtoneSound = configuration.ringtoneName
        c.iconTemplateImageData = configuration.iconTemplateImageData
        c.maximumCallGroups = configuration.maximumConversationGroups
        c.maximumCallsPerCallGroup = configuration.maximumConversationsPerConversationGroup
        c.includesCallsInRecents = configuration.includesConversationInRecents
        c.supportsVideo = configuration.supportsVideo
        c.supportedHandleTypes = Set(configuration.supportedHandleTypes.map { $0 == .phoneNumber ? .phoneNumber : $0 == .emailAddress ? .emailAddress : .generic })
        provider = CXProvider(configuration: c)
        bridge = _Bridge()
        bridge.manager = self
        provider.setDelegate(bridge, queue: .main)
        Self.current = self
    }

    /// the conversations that have not ended, oldest first
    public var conversations: [Conversation] { order.compactMap { byUUID[$0] }.filter { $0.state != .left } }
    public var pendingActions: [ConversationAction] { running }
    public func pendingConversationActions(of type: ConversationAction.Type, for conversation: Conversation) -> [ConversationAction] {
        running.filter { Swift.type(of: $0) == type && $0.conversationUUID == conversation.uuid }
    }

    public func reportNewIncomingConversation(uuid: UUID, update: Conversation.Update) async throws {
        guard !invalidated else { throw CXErrorCodeIncomingCallError(.unknown) }
        let c = Conversation(uuid: uuid, outgoing: false, state: .idle)
        c.apply(update)
        try await provider.reportNewIncomingCall(with: uuid, update: c.cxUpdate)
        add(c)
        changed(c)
    }

    /// what the app's conversation did: connecting, connected, its members, ended
    public func reportConversationEvent(_ event: Conversation.Event, for conversation: Conversation) {
        guard let c = byUUID[conversation.uuid] else { NSLog("isim: LiveCommunicationKit: an event for an unknown conversation %@", conversation.uuid.uuidString); return }
        switch event {
        case .conversationStartedConnecting(let d):
            provider.reportOutgoingCall(with: c.uuid, startedConnectingAt: d)
            c.state = .joining
        case .conversationConnected(let d):
            provider.reportOutgoingCall(with: c.uuid, connectedAt: d)
            c.connected = d; c.state = .joined
        case .conversationUpdated(let u):
            c.apply(u)
            provider.reportCall(with: c.uuid, updated: c.cxUpdate)
        case .conversationEnded(let d, let why):
            let r: CXCallEndedReason
            switch why {
            case .failed: r = .failed
            case .remoteEnded: r = .remoteEnded
            case .unanswered: r = .unanswered
            case .joinedElsewhere: r = .answeredElsewhere
            case .declinedElsewhere: r = .declinedElsewhere
            }
            provider.reportCall(with: c.uuid, endedAt: d, reason: r)
            ended(c, at: d, status: why == .unanswered ? "missed" : why == .joinedElsewhere ? "answeredElsewhere" : c.connected == nil ? "cancelled" : "connected")
            return
        }
        changed(c)
    }

    /// the app's own actions: checked like CallKit's requests (an unknown conversation, too many, …), then given to the
    /// delegate to perform
    public func perform(_ actions: [ConversationAction]) async throws {
        guard !invalidated else { throw CXErrorCodeRequestTransactionError(.unknownCallProvider) }
        var cxActions: [CXAction] = []
        for a in actions {
            a.manager = self
            if let cx = a.makeCX() { a.cx = cx; bridge.mine[cx.uuid] = a; cxActions.append(cx) }
            else if !(a is StartConversationAction) { start(a) }
            else { throw CXErrorCodeRequestTransactionError(.invalidAction) }
        }
        guard !cxActions.isEmpty else { return }
        do { try await controller.request(CXTransaction(actions: cxActions)) }
        catch { for a in actions { if let cx = a.cx { bridge.mine[cx.uuid] = nil } }; throw error }
    }

    public func invalidate() {
        invalidated = true
        for c in conversations { ended(c, at: Date(), status: "cancelled") }
        provider.invalidate()
    }

    /// a push payload reporting an incoming conversation (proposed: the payload's "uuid", "handle", "displayName", "isVideo")
    public class func reportNewIncomingVoIPPushPayload(_ payload: [AnyHashable: Any]) async throws {
        guard let m = current else { throw CXErrorCodeIncomingCallError(.unknown) }
        let uuid = (payload["uuid"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        let handle = Handle(type: .generic, value: payload["handle"] as? String ?? "unknown", displayName: payload["displayName"] as? String)
        try await m.reportNewIncomingConversation(uuid: uuid, update: Conversation.Update(members: [handle], activeRemoteMembers: [handle],
                                                                                         capabilities: (payload["isVideo"] as? Bool) == true ? .video : []))
    }

    // MARK: internals

    func add(_ c: Conversation) { byUUID[c.uuid] = c; if !order.contains(c.uuid) { order.append(c.uuid) } }
    func changed(_ c: Conversation) {
        NSLog("isim: LiveCommunicationKit: conversation %@ is %@", c.uuid.uuidString, "\(c.state)")
        let d = delegate
        DispatchQueue.main.async { d?.conversationManager(self, conversationChanged: c) }
    }
    /// gives an action to the delegate, with its timeout
    func start(_ a: ConversationAction) {
        a.manager = self
        a.state = .running
        running.append(a)
        NSLog("isim: LiveCommunicationKit: perform %@ %@", a.name, a.conversationUUID.uuidString)
        guard let d = delegate else { a.fail(); return }
        d.conversationManager(self, perform: a)
        let wait = max(0, a.timeoutDate.timeIntervalSinceNow)
        DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self, weak a] in
            guard let self, let a, a.state == .running else { return }
            NSLog("isim: LiveCommunicationKit: %@ timed out", a.name)
            self.delegate?.conversationManager(self, timedOutPerforming: a)
            a.finish("timed out")
        }
    }
    func completed(_ a: ConversationAction, ok: Bool) {
        running.removeAll { $0 === a }
        guard ok else { return }
        switch a {
        case let s as StartConversationAction:
            let c = Conversation(uuid: s.conversationUUID, outgoing: true, state: .joining)
            c.members = Set(s.handles); c.isVideo = s.isVideo
            add(c); changed(c)
        case is JoinConversationAction:
            guard let c = byUUID[a.conversationUUID] else { return }
            c.connected = Date(); c.state = .joined; changed(c)
        case is EndConversationAction:
            guard let c = byUUID[a.conversationUUID] else { return }
            ended(c, at: Date(), status: c.connected != nil ? "connected" : c.isOutgoing ? "cancelled" : "missed")
        case let m as MuteConversationAction:
            guard let c = byUUID[a.conversationUUID] else { return }
            c.isMuted = m.isMuted; changed(c)
        case let p as PauseConversationAction:
            guard let c = byUUID[a.conversationUUID] else { return }
            c.state = p.isPaused ? .paused : .joined; changed(c)
        default:
            if let c = byUUID[a.conversationUUID] { changed(c) }
        }
    }
    func ended(_ c: Conversation, at date: Date, status: String) {
        guard c.state != .left else { return }
        c.state = .left
        changed(c)
        if configuration.includesConversationInRecents {
            _Recents.add(_RecentRecord(id: c.uuid, date: c.started, duration: c.connected.map { date.timeIntervalSince($0) } ?? 0,
                               outgoing: c.isOutgoing, status: status,
                               handles: c.members.filter { $0 != c.localMember }.sorted { $0.value < $1.value }, isRead: c.isOutgoing))
        }
    }

    /// CallKit's provider delegate: the system's actions become conversation actions
    final class _Bridge: NSObject, CXProviderDelegate, @unchecked Sendable {
        weak var manager: ConversationManager?
        var mine: [UUID: ConversationAction] = [:]
        func providerDidReset(_ provider: CXProvider) {
            guard let m = manager else { return }
            m.delegate?.conversationManagerDidReset(m)
        }
        func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
            guard let m = manager else { return }
            m.delegate?.conversationManager(m, didActivate: audioSession)
        }
        func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
            guard let m = manager else { return }
            m.delegate?.conversationManager(m, didDeactivate: audioSession)
        }
        func give(_ cx: CXCallAction, _ make: () -> ConversationAction) {
            guard let m = manager else { cx.fail(); return }
            let a = mine.removeValue(forKey: cx.uuid) ?? make()
            a.cx = cx
            m.start(a)
        }
        func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
            give(action) { StartConversationAction(conversationUUID: action.callUUID, handles: [Handle(type: .generic, value: action.handle.value, displayName: nil)], isVideo: action.isVideo) }
        }
        func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) { give(action) { JoinConversationAction(conversationUUID: action.callUUID) } }
        func provider(_ provider: CXProvider, perform action: CXEndCallAction) { give(action) { EndConversationAction(conversationUUID: action.callUUID) } }
        func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
            give(action) { MuteConversationAction(conversationUUID: action.callUUID, isMuted: action.isMuted) }
        }
        func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) {
            give(action) { PauseConversationAction(conversationUUID: action.callUUID, isPaused: action.isOnHold) }
        }
        func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) {
            give(action) {
                action.callUUIDToGroupWith.map { MergeConversationAction(conversationUUID: action.callUUID, conversationUUIDToMergeWith: $0) }
                    ?? UnmergeConversationAction(conversationUUID: action.callUUID)
            }
        }
        func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) {
            give(action) {
                PlayToneAction(conversationUUID: action.callUUID, digits: action.digits,
                               tone: action.type == .softPause ? .softPause : action.type == .hardPause ? .hardPause : .single)
            }
        }
    }
}

// MARK: - recents (iOS 26)

@available(iOS 26.0, *)
public final class ConversationHistoryManager: @unchecked Sendable {
    public static let sharedInstance = ConversationHistoryManager()
    public struct RecentConversation: Hashable, Sendable, Identifiable {
        public enum Direction: Hashable, Sendable, Codable { case incoming, outgoing }
        public enum Status: Hashable, Sendable, Codable { case unknown, connected, missed, cancelled, answeredElsewhere }
        public let id: UUID
        public let date: Date
        public let duration: TimeInterval
        public let direction: Direction
        public let status: Status
        public let handles: [Handle]
        public let isRead: Bool
    }
    /// posted (NotificationCenter) when the recents change
    public struct ConversationHistoryDidUpdate: Hashable, Sendable {
        public init() {}
        static let name = Notification.Name("ConversationHistoryDidUpdate")
    }
    init() {}
    /// the app's recent conversations that match, newest first
    public func recentConversations(matching predicate: Predicate<RecentConversation>) async throws -> [RecentConversation] {
        try _Recents.all().map(RecentConversation.init).filter { try predicate.evaluate($0) }.sorted { $0.date > $1.date }
    }
    public func markConversationAsRead(_ conversation: RecentConversation) async throws { try await markConversationsAsRead([conversation]) }
    public func markConversationsAsRead(_ conversations: [RecentConversation]) async throws {
        let ids = Set(conversations.map(\.id))
        _Recents.update { list in for i in list.indices where ids.contains(list[i].id) { list[i].isRead = true } }
    }
}
/// one recent conversation as the device keeps it (every iOS version records them; reading them is iOS 26)
@available(iOS 17.4, *)
struct _RecentRecord: Codable {
    var id: UUID, date: Date, duration: TimeInterval
    var outgoing: Bool
    var status: String                 // connected, missed, cancelled, answeredElsewhere, unknown
    var handles: [Handle]
    var isRead: Bool
}
@available(iOS 26.0, *)
extension ConversationHistoryManager.RecentConversation {
    init(_ r: _RecentRecord) {
        id = r.id; date = r.date; duration = r.duration; direction = r.outgoing ? .outgoing : .incoming
        status = ["connected": .connected, "missed": .missed, "cancelled": .cancelled, "answeredElsewhere": .answeredElsewhere][r.status] ?? .unknown
        handles = r.handles; isRead = r.isRead
    }
}

/// the app's recents: $ISIM_DATA/Library/isim/Conversations/<bundle ID>.json
@available(iOS 17.4, *)
enum _Recents {
    static let lock = NSLock()
    static var path: String {
        let env = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        let dir = env.isEmpty ? NSHomeDirectory() + "/.local/share/isim" : env
        return dir + "/Library/isim/Conversations/\(Bundle.main.bundleIdentifier ?? "app").json"
    }
    static func load() -> [_RecentRecord] {
        guard let d = FileManager.default.contents(atPath: path) else { return [] }
        let dec = JSONDecoder(); dec.dateDecodingStrategy = .secondsSince1970
        return (try? dec.decode([_RecentRecord].self, from: d)) ?? []
    }
    static func all() -> [_RecentRecord] { lock.lock(); defer { lock.unlock() }; return load() }
    static func update(_ f: (inout [_RecentRecord]) -> Void) {
        lock.lock()
        var list = load()
        f(&list)
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let enc = JSONEncoder(); enc.dateEncodingStrategy = .secondsSince1970; enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let d = try? enc.encode(list) { FileManager.default.createFile(atPath: path, contents: d) }
        lock.unlock()
        NotificationCenter.default.post(name: Notification.Name("ConversationHistoryDidUpdate"), object: nil)
    }
    static func add(_ r: _RecentRecord) {
        update { $0.append(r) }
        NSLog("isim: LiveCommunicationKit: %@ conversation in recents (%@)", r.outgoing ? "outgoing" : "incoming", r.status)
    }
}

// MARK: - cellular (iOS 26; stub: isim has no telephony)

@available(iOS 26.0, *)
public struct CellularService: Hashable, Sendable, Identifiable {
    public let id: UUID
    public let label: String
}
@available(iOS 26.0, *)
public struct StartCellularConversationAction: Hashable, Sendable {
    public var handle: Handle
    public var cellularService: CellularService?
    public init(_ handle: Handle, cellularService: CellularService?) { self.handle = handle; self.cellularService = cellularService }
    public init(_ recent: ConversationHistoryManager.RecentConversation) {
        self.init(recent.handles.first ?? Handle(type: .phoneNumber, value: "", displayName: nil), cellularService: nil)
    }
}
@available(iOS 26.0, *)
public final class TelephonyConversationManager: @unchecked Sendable {
    public static let sharedInstance = TelephonyConversationManager()
    init() {}
    /// none: isim has no cellular radio (like Apple's Simulator)
    public var cellularServices: [CellularService] { [] }
    public func startCellularConversation(_ action: StartCellularConversationAction) async throws {
        NSLog("isim: LiveCommunicationKit: no cellular service for a call to %@", action.handle.value)
        throw CocoaError(.featureUnsupported)
    }
}

// MARK: - live assistance (iOS 26; stub: the extensions are not run)

@available(iOS 26.0, *)
public enum LiveAssistanceLaunchReason: Hashable, Sendable, Codable { case signIn, additionalInfo }
@available(iOS 26.0, *)
public enum LiveAssistance {
    public static let extensionPointName = "com.apple.livecommunicationkit.live-assistance"
    public static let containerAppLaunchActivityType = "com.apple.livecommunicationkit.live-assistance.launch"
    public static let containerAppLaunchRequestIDKey = "requestID"
    public static let containerAppLaunchReasonKey = "reason"
    /// back to the call the request came from (isim: logged; no live assistance call is running)
    public static func returnToCall(requestID: UUID) { NSLog("isim: LiveCommunicationKit: return to the call of request %@", requestID.uuidString) }
}
@available(iOS 26.0, *)
public protocol LiveAssistanceExtensionConfiguration: Sendable {}
@available(iOS 26.0, *)
public protocol LiveAssistanceExtension {
    func prepareAssistanceRequest(_ request: LiveAssistanceRequest) async throws -> LiveAssistanceRequest.Response
    func resumeRequest(_ request: LiveAssistanceRequest) async throws -> LiveAssistanceRequest.Response
}
@available(iOS 26.0, *)
public struct LiveAssistanceRequest: Hashable, Sendable, Identifiable {
    public enum Response: Hashable, Sendable { case proceed, requiresUserInput(reason: LiveAssistanceLaunchReason) }
    public let id: UUID
    public let url: URL
}
@available(iOS 26.0, *)
public enum LiveAssistanceRequestError: Error, Hashable, Sendable { case cannotFulfill(message: String?), unknown(message: String) }
