// isim SwiftUI: a hook for DynamicProperty wrappers defined in other isim modules (CoreData's @FetchRequest and
// @SectionedFetchRequest): they install like the built-in ones -- per-position storage that survives
// re-evaluation, the environment, and a way to re-render. Not iOS API (underscored).

public protocol _IsimInstallableDynamicProperty: DynamicProperty {
    @MainActor func _isimInstall(_ site: _IsimDynamicPropertySite)
}

@MainActor public struct _IsimDynamicPropertySite {
    let ctx: _Context
    let key: String
    public var environment: EnvironmentValues { ctx.environment }
    /// The object kept for this view position (created by `make` the first time).
    public func storage<T: AnyObject>(_ make: () -> T) -> T {
        ctx.graph.usedKeys.insert(key)
        if let s = ctx.graph.storage[key] as? T { return s }
        let s = make()
        ctx.graph.storage[key] = s
        return s
    }
    /// Re-renders the view graph (callable from any thread).
    public var invalidate: @Sendable () -> Void {
        let g = ctx.graph
        return { [weak g] in g?.invalidate() }
    }
}
