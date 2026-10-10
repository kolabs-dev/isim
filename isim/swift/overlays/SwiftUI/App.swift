// isim SwiftUI: app lifecycle and UIKit hosting.
import UIKit

// MARK: - App & Scene

@MainActor @preconcurrency
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
    @MainActor @preconcurrency init()
}
@MainActor @preconcurrency
public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
}
extension Never: Scene {}
protocol _SceneRoot { @MainActor var _rootView: AnyView { get } }

public struct WindowGroup<Content: View>: Scene, _SceneRoot, _SceneNode {
    let content: () -> Content
    var id: String?
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) { self.content = content }
    public init(id: String, @ViewBuilder content: @escaping () -> Content) { self.content = content; self.id = id }
    public init(_ title: LocalizedStringKey, id: String, @ViewBuilder content: @escaping () -> Content) { self.content = content; self.id = id }
    /// a window for a value (openWindow(value:)); isim shows it with a nil value
    public init<D: Codable & Hashable>(for type: D.Type, @ViewBuilder content: @escaping (Binding<D?>) -> Content) {
        self.content = { content(_WindowGroupValue.binding(D.self)) }
        id = _SUIWindows.typeID(D.self)
    }
    /// a window for a value with an id (openWindow(id:value:))
    public init<D: Codable & Hashable>(id: String, for type: D.Type, @ViewBuilder content: @escaping (Binding<D?>) -> Content) {
        self.content = { content(_WindowGroupValue.binding(D.self)) }
        self.id = id
    }
    public var body: Never { fatalError() }
    var _rootView: AnyView { AnyView(content()) }
    @MainActor func _collect(_ c: _SceneCollector) { let make = content; c.groups.append((id, { AnyView(make()) })) }
}
/// The value of the window being made (openWindow(value:)), as a binding its content can change.
enum _WindowGroupValue {
    @MainActor static func binding<D: Codable>(_ t: D.Type) -> Binding<D?> {
        let box = _SUIWindows.currentBox
        return Binding(get: { box?.data.flatMap { try? JSONDecoder().decode(D.self, from: $0) } },
                       set: { box?.data = $0.flatMap { try? JSONEncoder().encode($0) }; box?.changed?() })
    }
}
@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<S: Scene>(_ s: S) -> S { s }
    public static func buildExpression<S: Scene>(_ s: S) -> S { s }
}

/// the first WindowGroup of App.body (Scenes.swift collects every scene)
@MainActor func _rootView<A: App>(_ app: A) -> AnyView {
    let c = _collectScenes(app)
    _SUIWindows.groups = c.groups
    _SUIWindows.stack = [c.groups.first?.id ?? nil]
    return c.groups.first?.make() ?? AnyView(EmptyView())
}

final class _SUIAppRoot {
    nonisolated(unsafe) static var makeRoot: (@MainActor () -> AnyView)?
    nonisolated(unsafe) static var makeRootController: (@MainActor () -> UIViewController)?    /* DocumentGroup */
    nonisolated(unsafe) static var adaptor: NSObject?            /* @UIApplicationDelegateAdaptor */
}

extension App {
    /// Entry point used by `@main`: runs UIApplicationMain with a delegate that hosts the first WindowGroup.
    @MainActor public static func main() {
        let app = Self()
        let scenes = _collectScenes(app)
        _SUIBackgroundTasks.install(scenes.backgroundTasks)     /* before launch: background launches have no UI */
        _SUIAppRoot.makeRootController = scenes.rootController
        _SUIAppRoot.makeRoot = { _rootView(app) }
        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(_SUIAppDelegate.self))
    }
}

@objc(_SUIAppDelegate) final class _SUIAppDelegate: UIResponder, UIApplicationDelegate {
    var adaptor: UIApplicationDelegate? { _SUIAppRoot.adaptor as? UIApplicationDelegate }
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        adaptor?.application?(application, willFinishLaunchingWithOptions: launchOptions) ?? true
    }
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        adaptor?.application?(application, didFinishLaunchingWithOptions: launchOptions) ?? true
    }
    /// Like SwiftUI on iOS: the WindowGroup lives in a UIWindowScene. A delegate adaptor's configuration may name
    /// its own scene delegate class: it gets the scene callbacks SwiftUI's does not handle.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let custom = adaptor?.application?(application, configurationForConnecting: session, options: options), let cls = custom.delegateClass as? NSObject.Type {
            _SUISceneDelegate.forwardClass = cls
        }
        let c = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        c.delegateClass = _SUISceneDelegate.self
        return c
    }
    /// every other UIApplicationDelegate method goes to the @UIApplicationDelegateAdaptor delegate
    override func responds(to sel: Selector) -> Bool { super.responds(to: sel) || (_SUIAppRoot.adaptor?.responds(to: sel) ?? false) }
    override func forwardingTarget(for sel: Selector) -> Any? {
        if let a = _SUIAppRoot.adaptor, a.responds(to: sel) { return a }
        return super.forwardingTarget(for: sel)
    }
}

@objc(_SUISceneDelegate) final class _SUISceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    nonisolated(unsafe) static var forwardClass: NSObject.Type?
    var forward: NSObject?
    override func responds(to sel: Selector) -> Bool { super.responds(to: sel) || (forward?.responds(to: sel) ?? false) }
    override func forwardingTarget(for sel: Selector) -> Any? {
        if let f = forward, f.responds(to: sel) { return f }
        return super.forwardingTarget(for: sel)
    }
    /// @SceneStorage values are saved with the scene's state restoration activity
    func stateRestorationActivity(for scene: UIScene) -> NSUserActivity? { _SUISceneState.activity() }
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let cls = _SUISceneDelegate.forwardClass { forward = cls.init() }
        _SUISceneState.restore(session.stateRestorationActivity)
        if let f = forward as? UISceneDelegate { f.scene?(scene, willConnectTo: session, options: connectionOptions) }
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        _ = _SUIAppRoot.makeRoot?()                               // (collects the scenes of App.body)
        // the window's WindowGroup: an openWindow request, or the one it showed before (relaunch), else the first
        let opened = connectionOptions.userActivities.first { $0.activityType == _SUIWindows.activityType }
        var target = _SUIWindows.sessionInfo(session)
        if let info = opened?.userInfo {
            let id = info["id"] as? String
            target = (id?.isEmpty == false ? id : nil, info["value"] as? Data)
            var u = session.userInfo ?? [:]
            var record: [String: Any] = ["id": id ?? ""]
            if let v = info["value"] { record["value"] = v }
            u["isim.window"] = record
            session.userInfo = u
        }
        let root = _SUIWindows.root(id: target?.id, value: target?.value, session: session)
        if target == nil, let rc = _SUIAppRoot.makeRootController { w.rootViewController = rc() }
        else {
            let make = root.make, h = _SUIHostingController(root: { make() })
            let box = root.box
            root.box.changed = { [weak h, weak session] in
                // the window is now the one for the new value (openWindow(value:) finds it by it)
                if let session, var record = session.userInfo?["isim.window"] as? [String: Any] {
                    record["value"] = box.data
                    var u = session.userInfo ?? [:]; u["isim.window"] = record; session.userInfo = u
                }
                h?.graph.invalidate()
            }
            w.rootViewController = h
        }
        w.tintColor = _accentUIColor()
        window = w
        _SUIWindows.window = w
        w.makeKeyAndVisible()
    }
}

// MARK: - Hosting

final class _SUIHostView: UIView {
    let graph: _Graph
    /// a presented sheet whose background stays interactive: touches outside the content go to the presenter
    var passthrough = false
    @objc var _isim_passesTouchesOutsideContent: Bool { passthrough }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        return passthrough && v === self ? nil : v
    }
    init(graph: _Graph) {
        self.graph = graph
        super.init(frame: .zero)
        graph.hostView = self
        backgroundColor = .systemBackground
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func layoutSubviews() {
        super.layoutSubviews()
        graph.render(bounds: bounds, safeArea: safeAreaInsets, traits: traitCollection)
    }
    override func traitCollectionDidChange(_ previous: UITraitCollection?) { setNeedsLayout() }
}

class _SUIHostingController: UIViewController {
    let graph: _Graph
    init(root: @escaping () -> any View) {
        graph = _Graph(root: root)
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func loadView() { view = _SUIHostView(graph: graph) }
    override var keyCommands: [UIKeyCommand]? { _suiKeyCommands(graph, target: #selector(_isimSwiftUIShortcut(_:))) }
    @objc func _isimSwiftUIShortcut(_ c: UIKeyCommand) { _suiPerformShortcut(graph, c) }
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: false) { super.pressesBegan(presses, with: event) } }
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: true) { super.pressesEnded(presses, with: event) } }
}

final class _RootBox<C> { var get: (() -> C)? }

/// UIKit integration: hosts a SwiftUI view hierarchy in a view controller.
open class UIHostingController<Content: View>: UIViewController {
    let graph: _Graph
    public var rootView: Content { didSet { graph.invalidate() } }
    public init(rootView: Content) {
        self.rootView = rootView
        let box = _RootBox<Content>()
        graph = _Graph(root: { () -> any View in box.get?() ?? EmptyView() })
        super.init(nibName: nil, bundle: nil)
        box.get = { [unowned self] in self.rootView }
    }
    public required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    open override func loadView() { view = _SUIHostView(graph: graph) }
    /// The content's size for a proposal (its ideal size along infinite or zero dimensions).
    public func sizeThatFits(in size: CGSize) -> CGSize { graph.measure(size, traits: traitCollection) }
    open override var keyCommands: [UIKeyCommand]? { _suiKeyCommands(graph, target: #selector(_isimSwiftUIShortcut(_:))) }
    @objc func _isimSwiftUIShortcut(_ c: UIKeyCommand) { _suiPerformShortcut(graph, c) }
    open override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: false) { super.pressesBegan(presses, with: event) } }
    open override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: true) { super.pressesEnded(presses, with: event) } }
}
