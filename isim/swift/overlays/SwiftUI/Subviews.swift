// isim SwiftUI (iOS 18): custom containers — `Group(subviews:)` / `ForEach(subviews:)` with `Subview` and
// `SubviewsCollection`, `Group(sections:)` / `ForEach(sections:)` with `SectionConfiguration`, container values
// (`ContainerValueKey`, `ContainerValues`, `.containerValue(_:_:)`) and the `@Entry` macro (SwiftUIMacros plugin).
// The content resolves once where the container declares it (its views, as a stack would splice them: groups,
// ForEach, conditionals and custom views' bodies); a subview placed under another environment (`.font`, ...) resolves
// again there, with the same identity (state) as before.
import UIKit

// MARK: - Container values

public protocol ContainerValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
public struct ContainerValues {
    var values: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: ContainerValueKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
}
/// `.containerValue(\.x, v)`: a value the view carries for the container it is in.
final class _ContainerValueNode: _WrapperNode {
    let apply: (inout ContainerValues) -> Void
    init(path: String, apply: @escaping (inout ContainerValues) -> Void, child: _Node) {
        self.apply = apply; super.init(path: path, child: child); tag = child.tag
    }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
extension View {
    public func containerValue<V>(_ keyPath: WritableKeyPath<ContainerValues, V>, _ value: V) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("cv"))
            let apply: (inout ContainerValues) -> Void = { $0[keyPath: keyPath] = value }
            // on a group (ForEach, Group) or a section: every view (or the section) carries it
            if n is _GroupNode { n.children = n.children.map { _ContainerValueNode(path: $0.path + "/cv", apply: apply, child: $0) }; return n }
            if let s = n as? _SectionNode { s.containerValues.append(apply); return s }
            return _ContainerValueNode(path: ctx.path, apply: apply, child: n)
        }
    }
}
/// The container values of a resolved view: the innermost value of each key wins.
@MainActor func _containerValues(_ n: _Node) -> ContainerValues {
    var chain: [_ContainerValueNode] = []
    var x: _Node? = n
    while let c = x { if let v = c as? _ContainerValueNode { chain.append(v) }; x = c.children.count == 1 ? c.children[0] : nil }
    var out = ContainerValues()
    for v in chain.reversed() { v.apply(&out) }
    return out
}

// MARK: - Subview

/// One view of a container's content.
public struct Subview: View, Identifiable, _PrimitiveView {
    public struct ID: Hashable, Sendable { let path: String }
    let node: _Node
    let source: (view: any View, path: String)?
    let envRev: Int
    public var id: ID { ID(path: node.path) }
    public var containerValues: ContainerValues { MainActor.assumeIsolated { _containerValues(node) } }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        // placed under the environment it was resolved in: the node itself; elsewhere (a copy under `.font`, ...) it
        // resolves again there, as a view of that place
        if ctx.environment._rev == envRev || source == nil { return node }
        return _resolve(source!.view, ctx)
    }
}

/// The views of a container's content, in order.
public struct SubviewsCollection: RandomAccessCollection, View, _PrimitiveView {
    let items: [Subview]
    public typealias Element = Subview
    public typealias Index = Int
    public typealias SubSequence = SubviewsCollectionSlice
    public var startIndex: Int { 0 }
    public var endIndex: Int { items.count }
    public subscript(i: Int) -> Subview { items[i] }
    public subscript(r: Range<Int>) -> SubviewsCollectionSlice { SubviewsCollectionSlice(items: Array(items[r]), startIndex: r.lowerBound) }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GroupNode(path: ctx.path, children: items.map { $0._makeNode(ctx) }) }
}
public struct SubviewsCollectionSlice: RandomAccessCollection, View, _PrimitiveView {
    let items: [Subview]
    public let startIndex: Int
    public typealias Element = Subview
    public typealias Index = Int
    public typealias SubSequence = SubviewsCollectionSlice
    public var endIndex: Int { startIndex + items.count }
    public subscript(i: Int) -> Subview { items[i - startIndex] }
    public subscript(r: Range<Int>) -> SubviewsCollectionSlice { SubviewsCollectionSlice(items: Array(items[(r.lowerBound - startIndex)..<(r.upperBound - startIndex)]), startIndex: r.lowerBound) }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GroupNode(path: ctx.path, children: items.map { $0._makeNode(ctx) }) }
}

@MainActor func _subview(_ n: _Node, _ ctx: _Context) -> Subview {
    Subview(node: n, source: n.source, envRev: ctx.environment._rev)
}
/// Resolves a container's content and splits it into its views.
@MainActor func _subviews(_ content: any View, _ ctx: _Context) -> SubviewsCollection {
    let root = _resolve(content, ctx)
    return SubviewsCollection(items: _flatten([root]).map { _subview($0, ctx) })
}

// MARK: - Sections

public struct SectionConfiguration: Identifiable {
    public struct ID: Hashable, Sendable { let path: String }
    public let id: ID
    public let header: SubviewsCollection
    public let content: SubviewsCollection
    public let footer: SubviewsCollection
    public let containerValues: ContainerValues
}
public struct SectionCollection: RandomAccessCollection {
    let items: [SectionConfiguration]
    public typealias Element = SectionConfiguration
    public typealias Index = Int
    public var startIndex: Int { 0 }
    public var endIndex: Int { items.count }
    public subscript(i: Int) -> SectionConfiguration { items[i] }
}
/// The sections of a container's content; views outside a Section form sections without header and footer.
@MainActor func _sections(_ content: any View, _ ctx: _Context) -> SectionCollection {
    let nodes = _flattenGroups([_resolve(content, ctx)])
    var out: [SectionConfiguration] = [], loose: [_Node] = []
    func flush() {
        guard !loose.isEmpty else { return }
        out.append(SectionConfiguration(id: .init(path: loose[0].path + "#implicit"), header: SubviewsCollection(items: []),
                                        content: SubviewsCollection(items: loose.map { _subview($0, ctx) }), footer: SubviewsCollection(items: []),
                                        containerValues: ContainerValues()))
        loose = []
    }
    for n in nodes {
        guard let s = n as? _SectionNode else { loose.append(n); continue }
        flush()
        var cv = ContainerValues()
        for a in s.containerValues { a(&cv) }
        out.append(SectionConfiguration(id: .init(path: s.path), header: SubviewsCollection(items: s.header.map { _flatten([$0]).map { _subview($0, ctx) } } ?? []),
                                        content: SubviewsCollection(items: _flatten(s.rows).map { _subview($0, ctx) }),
                                        footer: SubviewsCollection(items: s.footer.map { _flatten([$0]).map { _subview($0, ctx) } } ?? []),
                                        containerValues: cv))
    }
    flush()
    return SectionCollection(items: out)
}

// MARK: - Group(subviews:), Group(sections:)

struct _SubviewsGroup<Result: View>: View, _PrimitiveView {
    let content: any View
    let transform: (SubviewsCollection) -> Result
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let subs = _subviews(content, ctx.child("subviews"))
        return _resolve(transform(subs), ctx.child("result"))
    }
}
struct _SectionsGroup<Result: View>: View, _PrimitiveView {
    let content: any View
    let transform: (SectionCollection) -> Result
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let secs = _sections(content, ctx.child("sections"))
        return _resolve(transform(secs), ctx.child("result"))
    }
}
extension Group where Content: View {
    /// The views of `view`, for a container to lay out as it likes.
    public init<Base: View, Result: View>(subviews view: Base, @ViewBuilder transform: @escaping (SubviewsCollection) -> Result) where Content == _SubviewsGroupContent<Result> {
        self.init { _SubviewsGroupContent<Result>(base: _SubviewsGroup(content: view, transform: transform)) }
    }
    /// The sections of `view`.
    public init<Base: View, Result: View>(sections view: Base, @ViewBuilder transform: @escaping (SectionCollection) -> Result) where Content == _SubviewsGroupContent<Result> {
        self.init { _SubviewsGroupContent<Result>(base: _SectionsGroup(content: view, transform: transform)) }
    }
}
public struct _SubviewsGroupContent<Result: View>: View, _PrimitiveView {
    let base: any _PrimitiveView
    init(base: any _PrimitiveView) { self.base = base }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { base._makeNode(ctx) }
}

// MARK: - ForEach(subviews:), ForEach(sections:)

/// ForEach over subviews or sections: the collection resolves when the ForEach does (it needs the context).
public struct _LazySubviews<Element>: RandomAccessCollection {
    let make: @MainActor (_Context) -> [Element]
    var resolved: [Element] = []
    public var startIndex: Int { 0 }
    public var endIndex: Int { resolved.count }
    public subscript(i: Int) -> Element { resolved[i] }
}
protocol _ContextCollection { @MainActor func _resolved(_ ctx: _Context) -> Self }
extension _LazySubviews: _ContextCollection {
    @MainActor func _resolved(_ ctx: _Context) -> _LazySubviews { var c = self; c.resolved = make(ctx); return c }
}
extension ForEach where Content: View {
    public init<V: View>(subviews view: V, @ViewBuilder content: @escaping (Subview) -> Content) where Data == _LazySubviews<Subview>, ID == Subview.ID {
        self.init(_data: _LazySubviews(make: { ctx in Array(_subviews(view, ctx.child("subviews"))) }), _id: { $0.id }, _content: content)
    }
    public init<V: View>(sections view: V, @ViewBuilder content: @escaping (SectionConfiguration) -> Content) where Data == _LazySubviews<SectionConfiguration>, ID == SectionConfiguration.ID {
        self.init(_data: _LazySubviews(make: { ctx in Array(_sections(view, ctx.child("sections"))) }), _id: { $0.id }, _content: content)
    }
}

// MARK: - @Entry

/// `@Entry var name: Type = default` in an extension of EnvironmentValues, ContainerValues, FocusedValues or Transaction:
/// the key type and the accessors (expanded by isim's SwiftUIMacros plugin).
@attached(accessor) @attached(peer, names: prefixed(__Key_))
public macro Entry() = #externalMacro(module: "SwiftUIMacros", type: "EntryMacro")
