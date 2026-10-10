// iOS 26 typed notification messages: NotificationCenter.MainActorMessage / AsyncMessage, message identifiers,
// observation tokens, posting and async sequences of messages. A message posted from Swift reaches Swift observers as
// the same value (the notification carries its number while it is posted); notifications posted the old way are turned into
// messages with the message type's makeMessage(_:), and messages into notifications for old observers with
// makeNotification(_:).
import Dispatch

@available(iOS 26.0, macOS 26.0, *)
extension NotificationCenter {
    /// Names the message type an `addObserver(of:for:)` call observes (`.didBecomeActive`, `.keyboardWillShow`, …).
    public protocol MessageIdentifier {
        associatedtype MessageType
    }
    /// The identifier the framework messages use: extensions on `MessageIdentifier` return one per message type.
    public struct BaseMessageIdentifier<MessageType>: MessageIdentifier, Sendable {
        public init() {}
    }
    /// What `addObserver(of:for:using:)` returns; pass it to `removeObserver(_:)` to stop observing.
    public struct ObservationToken: Hashable, Sendable {
        fileprivate let id: Int
    }
    /// A message observed and posted on the main actor.
    public protocol MainActorMessage: SendableMetatype {
        associatedtype Subject
        static var name: Notification.Name { get }
        @MainActor static func makeMessage(_ notification: Notification) -> Self?
        @MainActor static func makeNotification(_ message: Self) -> Notification
    }
    /// A message observed asynchronously, posted from any isolation.
    public protocol AsyncMessage: Sendable {
        associatedtype Subject
        static var name: Notification.Name { get }
        static func makeMessage(_ notification: Notification) -> Self?
        static func makeNotification(_ message: Self) -> Notification
    }
}

@available(iOS 26.0, macOS 26.0, *)
extension NotificationCenter.MainActorMessage {
    public static var name: Notification.Name { Notification.Name(String(reflecting: Self.self)) }
    @MainActor public static func makeMessage(_ notification: Notification) -> Self? { nil }
    @MainActor public static func makeNotification(_ message: Self) -> Notification { Notification(name: name, object: nil) }
}
@available(iOS 26.0, macOS 26.0, *)
extension NotificationCenter.AsyncMessage {
    public static var name: Notification.Name { Notification.Name(String(reflecting: Self.self)) }
    public static func makeMessage(_ notification: Notification) -> Self? { nil }
    public static func makeNotification(_ message: Self) -> Notification { Notification(name: name, object: nil) }
}

// ---- the registry of observers behind the tokens ----
private let messageKey = "_IsimNotificationMessage"
private final class MessageObservers: @unchecked Sendable {
    let lock = NSLock()
    var next = 0
    var observers: [Int: (NotificationCenter, NSObjectProtocol)] = [:]
    func add(_ center: NotificationCenter, _ o: NSObjectProtocol) -> Int {
        lock.lock(); defer { lock.unlock() }
        next += 1; observers[next] = (center, o); return next
    }
    func remove(_ id: Int) -> (NotificationCenter, NSObjectProtocol)? {
        lock.lock(); defer { lock.unlock() }
        return observers.removeValue(forKey: id)
    }
}
private let registry = MessageObservers()
/// the messages being posted: a notification carries only their number (posting is synchronous; an observer that
/// delivers later takes its message out before returning)
private final class PostedMessages: @unchecked Sendable {
    let lock = NSLock()
    var next = 0
    var table: [Int: Any] = [:]
    func add(_ m: Any) -> Int { lock.lock(); defer { lock.unlock() }; next += 1; table[next] = m; return next }
    func remove(_ id: Int) { lock.lock(); defer { lock.unlock() }; table.removeValue(forKey: id) }
    func message<M>(in n: Notification, as type: M.Type) -> M? {
        guard let number = n.userInfo?[messageKey] as? NSNumber else { return nil }
        let id = Int(number.int64Value)
        lock.lock(); defer { lock.unlock() }
        return table[id] as? M
    }
}
private let posted = PostedMessages()
/// a notification the old API can't send across isolation: carried as is (delivery is on the poster's thread or main)
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

@available(iOS 26.0, macOS 26.0, *)
extension NotificationCenter {
    // ---- main actor messages ----
    private func addMainActorObserver<Message: MainActorMessage>(_ type: Message.Type, object: AnyObject?,
                                                                 _ observer: @escaping @MainActor (Message) -> Void) -> ObservationToken {
        let box = UncheckedBox(value: observer)
        let o = addObserver(forName: Message.name, object: object, queue: nil) { n in
            let note = UncheckedBox(value: n)
            let message = UncheckedBox(value: posted.message(in: n, as: Message.self))
            let deliver: @MainActor @Sendable () -> Void = {
                if let m = message.value ?? Message.makeMessage(note.value) { box.value(m) }
            }
            if Thread.isMainThread { MainActor.assumeIsolated { deliver() } }
            else { DispatchQueue.main.async { MainActor.assumeIsolated { deliver() } } }
        }
        return ObservationToken(id: registry.add(self, o))
    }
    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject, for identifier: Identifier, using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message, Message.Subject: AnyObject {
        addMainActorObserver(Message.self, object: subject, observer)
    }
    public func addObserver<Identifier: MessageIdentifier, Message: MainActorMessage>(
        of subject: Message.Subject.Type, for identifier: Identifier, using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Identifier.MessageType == Message {
        addMainActorObserver(Message.self, object: nil, observer)
    }
    public func addObserver<Message: MainActorMessage>(
        of subject: Message.Subject? = nil, for messageType: Message.Type, using observer: @escaping @MainActor (Message) -> Void
    ) -> ObservationToken where Message.Subject: AnyObject {
        addMainActorObserver(Message.self, object: subject, observer)
    }
    @MainActor public func post<Message: MainActorMessage>(_ message: Message, subject: Message.Subject) where Message.Subject: AnyObject {
        postMessage(Message.makeNotification(message), message, object: subject)
    }
    @MainActor public func post<Message: MainActorMessage>(_ message: Message, subject: Message.Subject.Type = Message.Subject.self) {
        postMessage(Message.makeNotification(message), message, object: nil)
    }

    // ---- async messages ----
    private func addAsyncObserver<Message: AsyncMessage>(_ type: Message.Type, object: AnyObject?,
                                                        _ observer: @escaping @Sendable (Message) async -> Void) -> ObservationToken {
        let o = addObserver(forName: Message.name, object: object, queue: nil) { n in
            guard let m = posted.message(in: n, as: Message.self) ?? Message.makeMessage(n) else { return }
            Task { await observer(m) }
        }
        return ObservationToken(id: registry.add(self, o))
    }
    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject, for identifier: Identifier, using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Identifier.MessageType == Message, Message.Subject: AnyObject {
        addAsyncObserver(Message.self, object: subject, observer)
    }
    public func addObserver<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject.Type, for identifier: Identifier, using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Identifier.MessageType == Message {
        addAsyncObserver(Message.self, object: nil, observer)
    }
    public func addObserver<Message: AsyncMessage>(
        of subject: Message.Subject? = nil, for messageType: Message.Type, using observer: @escaping @Sendable (Message) async -> Void
    ) -> ObservationToken where Message.Subject: AnyObject {
        addAsyncObserver(Message.self, object: subject, observer)
    }
    public func post<Message: AsyncMessage>(_ message: Message, subject: Message.Subject) where Message.Subject: AnyObject {
        postMessage(Message.makeNotification(message), message, object: subject)
    }
    public func post<Message: AsyncMessage>(_ message: Message, subject: Message.Subject.Type = Message.Subject.self) {
        postMessage(Message.makeNotification(message), message, object: nil)
    }
    /// The messages posted from now on, in order (at most `limit` waiting; older ones are dropped).
    public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject, for identifier: Identifier, bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> where Identifier.MessageType == Message, Message.Subject: AnyObject {
        messageStream(Message.self, object: subject, limit)
    }
    public func messages<Identifier: MessageIdentifier, Message: AsyncMessage>(
        of subject: Message.Subject.Type, for identifier: Identifier, bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> where Identifier.MessageType == Message {
        messageStream(Message.self, object: nil, limit)
    }
    public func messages<Message: AsyncMessage>(
        of subject: Message.Subject? = nil, for messageType: Message.Type, bufferSize limit: Int = 10
    ) -> some AsyncSequence<Message, Never> where Message.Subject: AnyObject {
        messageStream(Message.self, object: subject, limit)
    }
    private func messageStream<Message: AsyncMessage>(_ type: Message.Type, object: AnyObject?, _ limit: Int) -> AsyncStream<Message> {
        AsyncStream(bufferingPolicy: .bufferingNewest(max(1, limit))) { continuation in
            let o = addObserver(forName: Message.name, object: object, queue: nil) { n in
                if let m = posted.message(in: n, as: Message.self) ?? Message.makeMessage(n) { continuation.yield(m) }
            }
            let token = UncheckedBox(value: (self, o))
            continuation.onTermination = { _ in token.value.0.removeObserver(token.value.1) }
        }
    }

    /// Stops the observation `addObserver(of:for:using:)` started.
    public func removeObserver(_ token: ObservationToken) {
        if let (center, o) = registry.remove(token.id) { center.removeObserver(o) }
    }

    private func postMessage(_ made: Notification, _ message: Any, object: AnyObject?) {
        let id = posted.add(message)
        defer { posted.remove(id) }
        var info = made.userInfo ?? [:]
        info[messageKey] = NSNumber(value: Int64(id))
        post(name: made.name, object: object ?? made.object.map { $0 as AnyObject }, userInfo: info)
    }
}
