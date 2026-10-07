// Scene modifiers that observe values (Scene.onChange). isim adaptation: a scene is hosted as its root view, so the
// modifier wraps that root view in the matching view modifier; the observed value is re-read whenever the app
// re-renders (e.g. scenePhase changes).
import UIKit

public struct _ModifiedScene<Base: Scene>: Scene, _SceneRoot {
    let base: Base
    let transform: @MainActor (AnyView) -> AnyView
    public var body: Never { fatalError() }
    var _rootView: AnyView {
        let inner = (base as? _SceneRoot)?._rootView ?? AnyView(EmptyView())
        return transform(inner)
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
