// isim SwiftUI: scenes beyond one WindowGroup, and the app's integration with the system.
//  - several scenes in App.body (WindowGroups by id; the first is shown at launch), scene modifiers
//  - @UIApplicationDelegateAdaptor (the delegate gets every UIApplicationDelegate call SwiftUI does not handle)
//  - (.onContinueUserActivity / .userActivity: UserActivity.swift)
//  - .backgroundTask(.appRefresh(id)) (BackgroundTasks launches: script `bgtask BUNDLE ID`), .backgroundTask(.urlSession(id))
//    (a background URLSession's events: the action runs where a UIKit app's handleEventsForBackgroundURLSession would)
//  - openWindow / dismissWindow: isim shows one scene per app; on iPad with UIApplicationSupportsMultipleScenes the
//    requested WindowGroup replaces the window's content (dismissWindow goes back); on iPhone they do nothing, like iOS.
import UIKit

// MARK: - scene collection

@MainActor final class _SceneCollector {
    var groups: [(id: String?, make: () -> AnyView)] = []
    var backgroundTasks: [(id: String, kind: String, run: @Sendable () async -> Void)] = []
}
protocol _SceneNode { @MainActor func _collect(_ c: _SceneCollector) }

public struct _TupleScene<each S: Scene>: Scene, _SceneNode {
    let scenes: (repeat each S)
    public var body: Never { fatalError() }
    @MainActor func _collect(_ c: _SceneCollector) {
        for s in repeat each scenes { (s as? _SceneNode)?._collect(c) }
    }
}
extension SceneBuilder {
    public static func buildBlock<each S: Scene>(_ s: repeat each S) -> _TupleScene<repeat each S> { _TupleScene(scenes: (repeat each s)) }
    public static func buildIf<S: Scene>(_ s: S?) -> _OptionalScene<S> { _OptionalScene(scene: s) }
}
public struct _OptionalScene<S: Scene>: Scene, _SceneNode {
    let scene: S?
    public var body: Never { fatalError() }
    @MainActor func _collect(_ c: _SceneCollector) { if let s = scene { (s as? _SceneNode)?._collect(c) } }
}

/* scene modifiers: _ModifiedScene (SceneModifiers.swift) */

@MainActor func _collectScenes<A: App>(_ app: A) -> _SceneCollector {
    let c = _SceneCollector()
    let body = app.body
    if let n = body as? _SceneNode { n._collect(c) } else if let r = body as? _SceneRoot { c.groups.append((nil, { r._rootView })) }
    return c
}

// MARK: - scene modifiers

public struct BackgroundTask<Request, Response>: Sendable {
    let identifier: String
    let kind: String
    public static func appRefresh(_ identifier: String) -> BackgroundTask<Void, Void> where Request == Void, Response == Void { .init(identifier: identifier, kind: "appRefresh") }
    public static func urlSession(_ identifier: String) -> BackgroundTask<Void, Void> where Request == Void, Response == Void { .init(identifier: identifier, kind: "urlSession") }
}
extension Scene {
    /// Runs `action` when the system launches the app for this background task (a BGAppRefreshTaskRequest submitted
    /// with the same identifier; isim: script `bgtask BUNDLE-ID ID`), or, for `.urlSession(id)`, when the background
    /// URLSession with that identifier has events for the app (its delegate events follow; the system may suspend
    /// the app once the action returns).
    public func backgroundTask(_ task: BackgroundTask<Void, Void>, action: @escaping @Sendable () async -> Void) -> some Scene {
        _ModifiedScene(base: self, transform: { $0 }, apply: { c in c.backgroundTasks.append((task.identifier, task.kind, action)) })
    }
    public func handlesExternalEvents(matching conditions: Set<String>) -> some Scene { _ModifiedScene(base: self, transform: { $0 }) }
    public func commands<C>(@_SceneCommandsBuilder content: () -> C) -> some Scene { _ModifiedScene(base: self, transform: { $0 }) }
    public func defaultSize(width: CGFloat, height: CGFloat) -> some Scene { _ModifiedScene(base: self, transform: { $0 }) }
    public func defaultSize(_ size: CGSize) -> some Scene { _ModifiedScene(base: self, transform: { $0 }) }
}
@resultBuilder public struct _SceneCommandsBuilder {
    public static func buildBlock<each C>(_ c: repeat each C) -> Int { 0 }
}

/// SwiftUI runs its .backgroundTask actions when UIKit launches a pending task (works without BGTaskScheduler
/// registration); BackgroundTasks asks whether SwiftUI claims an identifier before reporting a missing handler.
@MainActor final class _SUIBackgroundTasks {
    static var tasks: [(id: String, kind: String, run: @Sendable () async -> Void)] = []
    static var observers: [NSObjectProtocol] = []
    static func install(_ t: [(id: String, kind: String, run: @Sendable () async -> Void)]) {
        tasks = t
        guard observers.isEmpty, !t.isEmpty else { return }
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimSwiftUIBackgroundTask"), object: nil, queue: nil) { n in
            guard let box = n.object as? NSMutableDictionary, let ident = box["identifier"] as? String else { return }
            MainActor.assumeIsolated { if _SUIBackgroundTasks.tasks.contains(where: { $0.id == ident && $0.kind != "urlSession" }) { box.setObject(true, forKey: "handled" as NSString) } }
        })
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimBackgroundTaskLaunch"), object: nil, queue: nil) { n in
            guard let ident = n.object as? String else { return }
            MainActor.assumeIsolated {
                guard let t = _SUIBackgroundTasks.tasks.first(where: { $0.id == ident && $0.kind != "urlSession" }) else { return }
                NSLog("isim SwiftUI: background task %@ (.backgroundTask)", ident)
                let run = t.run
                let bg = UIApplication.shared.beginBackgroundTask(withName: ident, expirationHandler: nil)
                Task.detached { await run(); NSLog("isim SwiftUI: background task %@ finished", ident); await MainActor.run { UIApplication.shared.endBackgroundTask(bg) } }
            }
        })
        // a background URLSession's events (UIKit; the box carries the completion that lets the app be suspended)
        observers.append(NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimSwiftUIBackgroundURLSession"), object: nil, queue: nil) { n in
            guard let box = n.object as? NSMutableDictionary, let ident = box["identifier"] as? String else { return }
            nonisolated(unsafe) let done = box["completion"] as AnyObject?
            MainActor.assumeIsolated {
                guard let t = _SUIBackgroundTasks.tasks.first(where: { $0.id == ident && $0.kind == "urlSession" }) else { return }
                box.setObject(true, forKey: "handled" as NSString)
                NSLog("isim SwiftUI: background URL session %@ (.backgroundTask(.urlSession))", ident)
                let run = t.run
                Task.detached {
                    await run()
                    NSLog("isim SwiftUI: background URL session task %@ finished", ident)
                    if let done { unsafeBitCast(done, to: (@convention(block) () -> Void).self)() }
                }
            }
        })
    }
}

// MARK: - @UIApplicationDelegateAdaptor

@MainActor @propertyWrapper
public struct UIApplicationDelegateAdaptor<DelegateType: NSObject & UIApplicationDelegate>: DynamicProperty {
    public let wrappedValue: DelegateType
    public init(_ delegateType: DelegateType.Type = DelegateType.self) {
        if let d = _SUIAppRoot.adaptor as? DelegateType { wrappedValue = d; return }
        let d = delegateType.init()
        _SUIAppRoot.adaptor = d
        wrappedValue = d
    }
    public var projectedValue: DelegateType { wrappedValue }
}

// MARK: - windows

public struct OpenWindowAction {
    @MainActor public func callAsFunction(id: String) { _SUIWindows.open(id) }
    @MainActor public func callAsFunction<D: Codable & Hashable>(value: D) { _SUIWindows.open(nil) }
    @MainActor public func callAsFunction<D: Codable & Hashable>(id: String, value: D) { _SUIWindows.open(id) }
}
public struct DismissWindowAction {
    @MainActor public func callAsFunction() { _SUIWindows.dismiss() }
    @MainActor public func callAsFunction(id: String) { _SUIWindows.dismiss() }
}
struct _OpenWindowKey: EnvironmentKey { static var defaultValue: OpenWindowAction { OpenWindowAction() } }
struct _DismissWindowKey: EnvironmentKey { static var defaultValue: DismissWindowAction { DismissWindowAction() } }
extension EnvironmentValues {
    public var openWindow: OpenWindowAction { self[_OpenWindowKey.self] }
    public var dismissWindow: DismissWindowAction { self[_DismissWindowKey.self] }
    /// iPad apps with UIApplicationSupportsMultipleScenes; false on iPhone.
    @MainActor public var supportsMultipleWindows: Bool { _SUIWindows.supported }
}

@MainActor final class _SUIWindows {
    static var groups: [(id: String?, make: () -> AnyView)] = []
    static var stack: [String?] = []
    static weak var window: UIWindow?
    static var supported: Bool {
        let multi = (Bundle.main.object(forInfoDictionaryKey: "UIApplicationSceneManifest") as? [String: Any])?["UIApplicationSupportsMultipleScenes"] as? Bool ?? false
        return UIDevice.current.userInterfaceIdiom == .pad && multi
    }
    static func show(_ id: String?) {
        guard let g = groups.first(where: { $0.id == id }) ?? (id == nil ? groups.first : nil), let w = window else { return }
        let make = g.make
        w.rootViewController = _SUIHostingController(root: { make() })
    }
    static func open(_ id: String?) {
        guard supported else { NSLog("isim SwiftUI: openWindow(id: %@) ignored (multiple windows need an iPad and UIApplicationSupportsMultipleScenes)", id ?? "nil"); return }
        guard groups.contains(where: { $0.id == id }) else { NSLog("isim SwiftUI: openWindow: no WindowGroup with id %@", id ?? "nil"); return }
        stack.append(id)
        NSLog("isim SwiftUI: openWindow(id: %@) (isim shows one window per app: it replaces the current one)", id ?? "nil")
        show(id)
    }
    static func dismiss() {
        guard supported, stack.count > 1 else { NSLog("isim SwiftUI: dismissWindow ignored"); return }
        stack.removeLast()
        NSLog("isim SwiftUI: dismissWindow -> %@", stack.last.flatMap { $0 } ?? "main")
        show(stack.last ?? nil)
    }
}

// MARK: - @SceneStorage persistence (state restoration)

@MainActor enum _SUISceneState {
    static func activity() -> NSUserActivity {
        let a = NSUserActivity(activityType: "isim.swiftui.scenestorage")
        var vals: [String: Any] = [:]
        for (k, v) in _sceneValues {
            if v is String || v is Int || v is Double || v is Bool { vals[k] = v }
        }
        a.addUserInfoEntries(from: ["_IsimSceneStorage": vals])
        return a
    }
    static func restore(_ a: NSUserActivity?) {
        guard let vals = a?.userInfo?["_IsimSceneStorage"] as? [String: Any] else { return }
        for (k, v) in vals where _sceneValues[k] == nil { _sceneValues[k] = v }
        NSLog("isim SwiftUI: restored %ld @SceneStorage value(s)", vals.count)
    }
}
