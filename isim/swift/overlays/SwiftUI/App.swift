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

public struct WindowGroup<Content: View>: Scene, _SceneRoot {
    let content: () -> Content
    public init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    public init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) { self.content = content }
    public init(id: String, @ViewBuilder content: @escaping () -> Content) { self.content = content }
    public var body: Never { fatalError() }
    var _rootView: AnyView { AnyView(content()) }
}
@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<S: Scene>(_ s: S) -> S { s }
    public static func buildExpression<S: Scene>(_ s: S) -> S { s }
}

@MainActor func _rootView<A: App>(_ app: A) -> AnyView {
    func find(_ s: Any) -> AnyView? {
        if let r = s as? _SceneRoot { return r._rootView }
        return nil
    }
    return find(app.body) ?? AnyView(EmptyView())
}

final class _SUIAppRoot {
    nonisolated(unsafe) static var makeRoot: (@MainActor () -> AnyView)?
}

extension App {
    /// Entry point used by `@main`: runs UIApplicationMain with a delegate that hosts the first WindowGroup.
    @MainActor public static func main() {
        let app = Self()
        _SUIAppRoot.makeRoot = { _rootView(app) }
        _ = UIApplicationMain(CommandLine.argc, CommandLine.unsafeArgv, nil, NSStringFromClass(_SUIAppDelegate.self))
    }
}

@objc(_SUIAppDelegate) final class _SUIAppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    /// Like SwiftUI on iOS: the WindowGroup lives in a UIWindowScene.
    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let c = UISceneConfiguration(name: "Default Configuration", sessionRole: session.role)
        c.delegateClass = _SUISceneDelegate.self
        return c
    }
}

@objc(_SUISceneDelegate) final class _SUISceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let ws = scene as? UIWindowScene else { return }
        let w = UIWindow(windowScene: ws)
        let root = _SUIAppRoot.makeRoot ?? { AnyView(EmptyView()) }
        w.rootViewController = _SUIHostingController(root: { root() })
        w.tintColor = _accentUIColor()
        window = w
        w.makeKeyAndVisible()
    }
}

// MARK: - Hosting

final class _SUIHostView: UIView {
    let graph: _Graph
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
    public func sizeThatFits(in size: CGSize) -> CGSize { size }
    open override var keyCommands: [UIKeyCommand]? { _suiKeyCommands(graph, target: #selector(_isimSwiftUIShortcut(_:))) }
    @objc func _isimSwiftUIShortcut(_ c: UIKeyCommand) { _suiPerformShortcut(graph, c) }
    open override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: false) { super.pressesBegan(presses, with: event) } }
    open override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) { if !_suiHandlePresses(graph, presses, up: true) { super.pressesEnded(presses, with: event) } }
}
