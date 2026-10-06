// isim Foundation: key-value observing for Swift — observe(_:options:changeHandler:), NSKeyValueObservation and
// Combine's publisher(for:). isim has no ObjC KVO (no isa-swizzling of setters): a change is reported only when
// the object calls willChangeValue(forKey:)/didChangeValue(forKey:), which isim's own frameworks do for their
// observable properties (AVPlayer.rate/timeControlStatus/status, AVPlayerItem.status, ...). Plain
// `@objc dynamic` properties of app classes are not observed automatically.
import ObjectiveC

public struct NSKeyValueObservingOptions: OptionSet, Sendable, Hashable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let new = NSKeyValueObservingOptions(rawValue: 1)
    public static let old = NSKeyValueObservingOptions(rawValue: 2)
    public static let initial = NSKeyValueObservingOptions(rawValue: 4)
    public static let prior = NSKeyValueObservingOptions(rawValue: 8)
}
public enum NSKeyValueChange: UInt, Sendable { case setting = 1, insertion, removal, replacement }

public struct NSKeyValueObservedChange<Value> {
    public typealias Kind = NSKeyValueChange
    public let kind: Kind
    public let newValue: Value?
    public let oldValue: Value?
    public let indexes: [Int]?   // isim: no IndexSet
    public let isPrior: Bool
}

public class NSKeyValueObservation: NSObject {
    var onInvalidate: (() -> Void)?
    init(_ onInvalidate: @escaping () -> Void) { self.onInvalidate = onInvalidate }
    public func invalidate() { onInvalidate?(); onInvalidate = nil }
    deinit { onInvalidate?() }
}

/// Observers by object and key. Main-thread use, like the frameworks that post changes.
enum _IsimKVO {
    final class Entry { let id: Int; let prior: () -> Void; let fire: () -> Void; init(id: Int, prior: @escaping () -> Void, fire: @escaping () -> Void) { self.id = id; self.prior = prior; self.fire = fire } }
    nonisolated(unsafe) static var table: [ObjectIdentifier: [String: [Entry]]] = [:]
    nonisolated(unsafe) static var nextID = 1
    static func key(_ kp: AnyKeyPath) -> String {
        if let s = kp._kvcKeyPathString { return s }
        // "\Type.a.b" -> "a.b"
        var d = String(describing: kp)
        if d.hasPrefix("\\") { d.removeFirst() }
        if let dot = d.firstIndex(of: ".") { return String(d[d.index(after: dot)...]) }
        return d
    }
    static func entries(_ o: AnyObject, _ k: String) -> [Entry] { table[ObjectIdentifier(o)]?[k] ?? [] }
}

public protocol _KeyValueCodingAndObserving {}
extension NSObject: _KeyValueCodingAndObserving {}

extension _KeyValueCodingAndObserving where Self: NSObject {
    public func observe<Value>(_ keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [],
                               changeHandler: @escaping (Self, NSKeyValueObservedChange<Value>) -> Void) -> NSKeyValueObservation {
        let key = _IsimKVO.key(keyPath), oid = ObjectIdentifier(self), id = _IsimKVO.nextID
        _IsimKVO.nextID += 1
        weak var weakSelf = self
        var last: Value? = self[keyPath: keyPath]
        let entry = _IsimKVO.Entry(id: id, prior: {
            guard options.contains(.prior), let o = weakSelf else { return }
            changeHandler(o, NSKeyValueObservedChange(kind: .setting, newValue: nil, oldValue: options.contains(.old) ? last : nil, indexes: nil, isPrior: true))
        }, fire: {
            guard let o = weakSelf else { return }
            let v = o[keyPath: keyPath]
            let old = last
            last = v
            changeHandler(o, NSKeyValueObservedChange(kind: .setting, newValue: options.contains(.new) ? v : nil,
                                                      oldValue: options.contains(.old) ? old : nil, indexes: nil, isPrior: false))
        })
        _IsimKVO.table[oid, default: [:]][key, default: []].append(entry)
        if options.contains(.initial) {
            changeHandler(self, NSKeyValueObservedChange(kind: .setting, newValue: options.contains(.new) ? last : nil, oldValue: nil, indexes: nil, isPrior: false))
        }
        return NSKeyValueObservation {
            _IsimKVO.table[oid]?[key]?.removeAll { $0.id == id }
            if _IsimKVO.table[oid]?[key]?.isEmpty == true { _IsimKVO.table[oid]?[key] = nil }
            if _IsimKVO.table[oid]?.isEmpty == true { _IsimKVO.table[oid] = nil }
        }
    }

    public func publisher<Value>(for keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [.initial, .new]) -> NSObject.KeyValueObservingPublisher<Self, Value> {
        NSObject.KeyValueObservingPublisher(object: self, keyPath: keyPath, options: options)
    }
}

extension NSObject {
    /// isim: reports a change to observers registered with observe(_:) / publisher(for:).
    public func willChangeValue(forKey key: String) {
        guard !_IsimKVO.table.isEmpty else { return }
        for e in _IsimKVO.entries(self, key) { e.prior() }
    }
    public func didChangeValue(forKey key: String) {
        guard !_IsimKVO.table.isEmpty else { return }
        for e in _IsimKVO.entries(self, key) { e.fire() }
    }

    public struct KeyValueObservingPublisher<Subject: NSObject, Value>: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        public let object: Subject
        public let keyPath: KeyPath<Subject, Value>
        public let options: NSKeyValueObservingOptions
        public init(object: Subject, keyPath: KeyPath<Subject, Value>, options: NSKeyValueObservingOptions) {
            self.object = object; self.keyPath = keyPath; self.options = options
        }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Value, S.Failure == Never {
            let token = _FoundationRef<NSKeyValueObservation?>(nil)
            let sub = _FoundationForwardingSubscription(subscriber, onCancel: { token.value?.invalidate(); token.value = nil })
            subscriber.receive(subscription: sub)
            token.value = object.observe(keyPath, options: options.union(.new)) { _, change in
                if let v = change.newValue { sub.send(v) }
            }
        }
    }
}
