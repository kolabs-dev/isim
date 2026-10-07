// Scene modifiers that observe values (Scene.onChange). isim adaptation: a scene is hosted as its root view, so the
// modifier wraps that root view in the matching view modifier; the observed value is re-read whenever the app
// re-renders (e.g. scenePhase changes).
import UIKit

/// A scene with a modifier: `transform` wraps the scene's root views; `apply` records scene-level settings
/// (background tasks, ...; Scenes.swift collects the scenes of App.body).
public struct _ModifiedScene<Base: Scene>: Scene, _SceneRoot, _SceneNode {
    let base: Base
    let transform: @MainActor (AnyView) -> AnyView
    var apply: (@MainActor (_SceneCollector) -> Void)? = nil
    public var body: Never { fatalError() }
    var _rootView: AnyView {
        let inner = (base as? _SceneNode).map { n -> AnyView in let c = _SceneCollector(); n._collect(c); return c.groups.first?.make() ?? AnyView(EmptyView()) }
            ?? (base as? _SceneRoot)?._rootView ?? AnyView(EmptyView())
        return transform(inner)
    }
    @MainActor func _collect(_ c: _SceneCollector) {
        apply?(c)
        let inner = _SceneCollector()
        if let n = base as? _SceneNode { n._collect(inner) } else if let r = base as? _SceneRoot { inner.groups.append((nil, { r._rootView })) }
        let t = transform
        for g in inner.groups { let make = g.make; c.groups.append((g.id, { t(make()) })) }
        c.backgroundTasks += inner.backgroundTasks
    }
}

extension Scene {
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some Scene {
        _ModifiedScene(base: self) { AnyView($0.onChange(of: value, initial: initial, action)) }
    }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some Scene {
        _ModifiedScene(base: self) { AnyView($0.onChange(of: value, initial: initial, action)) }
    }
    @available(iOS, deprecated: 17.0, message: "Use `onChange` with a two or zero parameter action closure instead.")
    public func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some Scene {
        _ModifiedScene(base: self) { AnyView($0.onChange(of: value, perform: action)) }
    }
}
