// isim SwiftUI: @AppStorage (UserDefaults-backed state; views re-render when a key they may read changes)
// and @SceneStorage (kept for the app's lifetime under a per-scene key; isim has one scene).
import Foundation

let _appStorageChanged = Notification.Name("_IsimAppStorageChanged")

@propertyWrapper
public struct AppStorage<Value>: DynamicProperty, _DynamicProperty {
    let key: String, defaultValue: Value, store: UserDefaults
    let read: (UserDefaults, String) -> Value?
    let write: (UserDefaults, String, Value) -> Void
    init(_ key: String, _ defaultValue: Value, _ store: UserDefaults?, read: @escaping (UserDefaults, String) -> Value?,
         write: @escaping (UserDefaults, String, Value) -> Void) {
        self.key = key; self.defaultValue = defaultValue; self.store = store ?? .standard; self.read = read; self.write = write
    }
    public var wrappedValue: Value {
        get { read(store, key) ?? defaultValue }
        nonmutating set {
            write(store, key, newValue)
            NotificationCenter.default.post(name: _appStorageChanged, object: key as NSString)
        }
    }
    public var projectedValue: Binding<Value> {
        let s = self
        return Binding(get: { s.wrappedValue }, set: { s.wrappedValue = $0 })
    }
    func _install(_ ctx: _Context, label: String) {
        let g = ctx.graph
        if g.appStorageObserver == nil {
            g.appStorageObserver = NotificationCenter.default.addObserver(forName: _appStorageChanged, object: nil, queue: nil) { [weak g] (_: Notification) in
                g?.invalidate()
            }
        }
    }
}

private func plist<T>(_ d: UserDefaults, _ k: String) -> T? { d.object(forKey: k) as? T }
private func setPlist<T>(_ d: UserDefaults, _ k: String, _ v: T) { d.set(v, forKey: k) }

extension AppStorage where Value == Bool {
    public init(wrappedValue: Bool, _ key: String, store: UserDefaults? = nil) { self.init(key, wrappedValue, store, read: plist, write: setPlist) }
}
extension AppStorage where Value == Int {
    public init(wrappedValue: Int, _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { ($0.object(forKey: $1) as? NSNumber)?.integerValue }, write: setPlist)
    }
}
extension AppStorage where Value == Double {
    public init(wrappedValue: Double, _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { ($0.object(forKey: $1) as? NSNumber)?.doubleValue }, write: setPlist)
    }
}
extension AppStorage where Value == String {
    public init(wrappedValue: String, _ key: String, store: UserDefaults? = nil) { self.init(key, wrappedValue, store, read: plist, write: setPlist) }
}
extension AppStorage where Value == Data {
    public init(wrappedValue: Data, _ key: String, store: UserDefaults? = nil) { self.init(key, wrappedValue, store, read: plist, write: setPlist) }
}
extension AppStorage where Value == URL {
    public init(wrappedValue: URL, _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { ($0.string(forKey: $1)).flatMap { URL(string: $0) } }, write: { $0.set($2.absoluteString, forKey: $1) })
    }
}
extension AppStorage where Value: RawRepresentable, Value.RawValue == Int {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { ($0.object(forKey: $1) as? NSNumber).flatMap { Value(rawValue: $0.integerValue) } },
                  write: { $0.set($2.rawValue, forKey: $1) })
    }
}
extension AppStorage where Value: RawRepresentable, Value.RawValue == String {
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) {
        self.init(key, wrappedValue, store, read: { $0.string(forKey: $1).flatMap { Value(rawValue: $0) } }, write: { $0.set($2.rawValue, forKey: $1) })
    }
}
extension AppStorage where Value: ExpressibleByNilLiteral {
    public init(_ key: String, store: UserDefaults? = nil) where Value == Bool? {
        self.init(key, nil, store, read: { .some($0.object(forKey: $1) as? Bool) }, write: { d, k, v in if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Int? {
        self.init(key, nil, store, read: { .some(($0.object(forKey: $1) as? NSNumber)?.integerValue) }, write: { d, k, v in if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Double? {
        self.init(key, nil, store, read: { .some(($0.object(forKey: $1) as? NSNumber)?.doubleValue) }, write: { d, k, v in if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == String? {
        self.init(key, nil, store, read: { .some($0.string(forKey: $1)) }, write: { d, k, v in if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } })
    }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Data? {
        self.init(key, nil, store, read: { .some($0.object(forKey: $1) as? Data) }, write: { d, k, v in if let v { d.set(v, forKey: k) } else { d.removeObject(forKey: k) } })
    }
}

/// @SceneStorage: per-scene UI state (isim keeps it for the app's lifetime).
@propertyWrapper
public struct SceneStorage<Value>: DynamicProperty, _DynamicProperty {
    nonisolated(unsafe) static var values: [String: Any] { get { _sceneValues } set { _sceneValues = newValue } }
    let key: String, defaultValue: Value
    final class Box { weak var graph: _Graph? }
    let box = Box()
    public var wrappedValue: Value {
        get { _sceneValues[key] as? Value ?? defaultValue }
        nonmutating set { _sceneValues[key] = newValue; box.graph?.invalidate() }
    }
    public var projectedValue: Binding<Value> { let s = self; return Binding(get: { s.wrappedValue }, set: { s.wrappedValue = $0 }) }
    func _install(_ ctx: _Context, label: String) { box.graph = ctx.graph }
}
nonisolated(unsafe) var _sceneValues: [String: Any] = [:]
extension SceneStorage where Value == Bool { public init(wrappedValue: Bool, _ key: String) { self.key = key; defaultValue = wrappedValue } }
extension SceneStorage where Value == Int { public init(wrappedValue: Int, _ key: String) { self.key = key; defaultValue = wrappedValue } }
extension SceneStorage where Value == Double { public init(wrappedValue: Double, _ key: String) { self.key = key; defaultValue = wrappedValue } }
extension SceneStorage where Value == String { public init(wrappedValue: String, _ key: String) { self.key = key; defaultValue = wrappedValue } }
extension SceneStorage where Value: RawRepresentable, Value.RawValue == String { public init(wrappedValue: Value, _ key: String) { self.key = key; defaultValue = wrappedValue } }
extension SceneStorage where Value: RawRepresentable, Value.RawValue == Int { public init(wrappedValue: Value, _ key: String) { self.key = key; defaultValue = wrappedValue } }

extension View {
    public func defaultAppStorage(_ store: UserDefaults) -> some View { self }
}
