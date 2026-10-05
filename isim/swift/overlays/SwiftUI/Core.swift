// isim SwiftUI — an independent re-implementation of a SwiftUI subset on top of isim's UIKit.
// Not Apple's SwiftUI: views are evaluated into a node tree, laid out with SwiftUI-like
// proposal/response layout, and rendered as UIKit views. State is stored per structural
// position (identity path). See docs/compatibility-matrix.md for the supported API.
@_exported import UIKit
@_exported import Foundation
@_exported import Combine

// MARK: - View

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { fatalError("Never has no body") }
}

/// Views implemented by isim directly (no body).
@MainActor protocol _PrimitiveView {
    func _makeNode(_ ctx: _Context) -> _Node
}

// MARK: - ViewBuilder

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<Content: View>(_ content: Content) -> Content { content }
    public static func buildBlock<each Content: View>(_ content: repeat each Content) -> TupleView<(repeat each Content)> {
        TupleView(repeat each content)
    }
    public static func buildExpression<Content: View>(_ content: Content) -> Content { content }
    public static func buildOptional<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { _ConditionalContent(storage: .trueContent(first)) }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { _ConditionalContent(storage: .falseContent(second)) }
    public static func buildIf<Content: View>(_ content: Content?) -> Content? { content }
    public static func buildLimitedAvailability<Content: View>(_ content: Content) -> AnyView { AnyView(content) }
}

public struct EmptyView: View, _PrimitiveView {
    public init() {}
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _GroupNode(path: ctx.path, children: []) }
}

public struct TupleView<T>: View, _PrimitiveView {
    public var value: T
    let children: [any View]
    public init(_ value: T) { self.value = value; self.children = [] }
    init<each V: View>(_ v: repeat each V) where T == (repeat each V) {
        self.value = (repeat each v)
        var list: [any View] = []
        repeat list.append(each v)
        self.children = list
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _GroupNode(path: ctx.path, children: children.enumerated().map { i, c in _resolve(c, ctx.child("\(i)")) })
    }
}

public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View, _PrimitiveView {
    enum Storage { case trueContent(TrueContent), falseContent(FalseContent) }
    let storage: Storage
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        switch storage {
        case .trueContent(let v): return _resolve(v, ctx.child("T"))
        case .falseContent(let v): return _resolve(v, ctx.child("F"))
        }
    }
}

extension Optional: View where Wrapped: View {
    public var body: Never { fatalError() }
}
extension Optional: _PrimitiveView where Wrapped: View {
    func _makeNode(_ ctx: _Context) -> _Node {
        switch self {
        case .some(let v): return _resolve(v, ctx.child("some"))
        case .none: return _GroupNode(path: ctx.path, children: [])
        }
    }
}

public struct AnyView: View, _PrimitiveView {
    let view: any View
    public init<V: View>(_ view: V) { self.view = view }
    public init<V: View>(erasing view: V) { self.view = view }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _resolve(view, ctx.child(_typeName(type(of: view)))) }
}

public struct Group<Content: View>: View, _PrimitiveView {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { _resolve(content, ctx) }
}

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content: View>: View, _PrimitiveView {
    public var data: Data
    public var content: (Data.Element) -> Content
    let id: (Data.Element) -> ID
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content; self.id = { $0[keyPath: id] }
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        _GroupNode(path: ctx.path, children: data.map { e in _resolve(content(e), ctx.child("id:\(id(e))")) })
    }
}
extension ForEach where Data.Element: Identifiable, ID == Data.Element.ID {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.content = content; self.id = { $0.id }
    }
}
extension ForEach where Data == Range<Int>, ID == Int {
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = data; self.content = content; self.id = { $0 }
    }
}

func _typeName(_ t: Any.Type) -> String { String(describing: t) }

// MARK: - Resolution (view value -> node), with state attachment

/// Evaluates a view at a structural position: attaches property-wrapper storage
/// (@State, @FocusState, @Environment, ...) for that position, then builds its node.
@MainActor func _resolve(_ view: any View, _ ctx: _Context) -> _Node {
    if let r = view as? any UIViewRepresentable { _attach(view, ctx); return _representableNode(r, ctx) }
    if let r = view as? any UIViewControllerRepresentable { _attach(view, ctx); return _vcRepresentableNode(r, ctx) }
    if let p = view as? _PrimitiveView {
        _attach(view, ctx)
        return p._makeNode(ctx)
    }
    _attach(view, ctx)
    return _evaluateBody(view, ctx)
}
@MainActor func _representableNode<R: UIViewRepresentable>(_ r: R, _ ctx: _Context) -> _Node {
    _RepresentableNode(path: ctx.path, rep: r, env: ctx.environment, graph: ctx.graph)
}
@MainActor func _vcRepresentableNode<R: UIViewControllerRepresentable>(_ r: R, _ ctx: _Context) -> _Node {
    _VCRepresentableNode(path: ctx.path, rep: r, env: ctx.environment, graph: ctx.graph)
}
@MainActor private func _evaluateBody<V: View>(_ view: V, _ ctx: _Context) -> _Node {
    ctx.graph.evaluations += 1
    return _resolve(view.body, ctx.child(_typeName(V.Body.self)))
}

/// Property wrappers that need per-position storage or environment values conform to this.
@MainActor protocol _DynamicProperty {
    func _install(_ ctx: _Context, label: String)
}
@MainActor func _attach(_ view: Any, _ ctx: _Context) {
    let m = Mirror(reflecting: view)
    guard m.displayStyle == .struct || m.displayStyle == .class else { return }
    for child in m.children {
        if let d = child.value as? _DynamicProperty { d._install(ctx, label: child.label ?? "?") }
    }
}

// MARK: - DynamicProperty, State, Binding

public protocol DynamicProperty {}

final class _StateStorage<Value>: _AnyStorage {
    var value: Value
    init(_ v: Value) { value = v }
}
class _AnyStorage {}

@propertyWrapper
public struct State<Value>: DynamicProperty, _DynamicProperty {
    final class Box { var storage: _StateStorage<Value>?; var initial: Value; weak var graph: _Graph?; init(_ v: Value) { initial = v } }
    let box: Box
    public init(wrappedValue value: Value) { box = Box(value) }
    public init(initialValue value: Value) { box = Box(value) }
    public var wrappedValue: Value {
        get { box.storage?.value ?? box.initial }
        nonmutating set {
            if let s = box.storage { s.value = newValue; box.graph?.invalidate() } else { box.initial = newValue }
        }
    }
    public var projectedValue: Binding<Value> {
        let b = box
        return Binding(get: { b.storage?.value ?? b.initial }, set: { v in
            if let s = b.storage { s.value = v; b.graph?.invalidate() } else { b.initial = v }
        })
    }
    func _install(_ ctx: _Context, label: String) {
        let key = ctx.path + "#" + label
        if let s = ctx.graph.storage[key] as? _StateStorage<Value> { box.storage = s }
        else { let s = _StateStorage(box.initial); ctx.graph.storage[key] = s; box.storage = s }
        ctx.graph.usedKeys.insert(key)
        box.graph = ctx.graph
    }
}
extension State where Value: ExpressibleByNilLiteral {
    public init() { self.init(wrappedValue: nil) }
}

@propertyWrapper @dynamicMemberLookup
public struct Binding<Value> {
    let get: () -> Value
    let set: (Value) -> Void
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
    public static func constant(_ value: Value) -> Binding<Value> { Binding(get: { value }, set: { _ in }) }
    public var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
    public var projectedValue: Binding<Value> { self }
    public init(projectedValue: Binding<Value>) { self = projectedValue }
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        let g = get, s = set
        return Binding<Subject>(get: { g()[keyPath: keyPath] }, set: { v in var whole = g(); whole[keyPath: keyPath] = v; s(whole) })
    }
}
extension Binding: DynamicProperty {}

// MARK: - FocusState

@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty, _DynamicProperty {
    final class Box { var storage: _StateStorage<Value>?; let initial: Value; weak var graph: _Graph?; init(_ v: Value) { initial = v } }
    let box: Box
    public init() where Value == Bool { box = Box(false) }
    public init<T: Hashable>() where Value == T? { box = Box(nil) }
    public var wrappedValue: Value {
        get { box.storage?.value ?? box.initial }
        nonmutating set { if let s = box.storage, s.value != newValue { s.value = newValue; box.graph?.invalidate() } }
    }
    public var projectedValue: Binding { Binding(box: box) }
    @propertyWrapper
    public struct Binding {
        let box: Box
        public var wrappedValue: Value {
            get { box.storage?.value ?? box.initial }
            nonmutating set { if let s = box.storage, s.value != newValue { s.value = newValue; box.graph?.invalidate() } }
        }
        public var projectedValue: Binding { self }
    }
    func _install(_ ctx: _Context, label: String) {
        let key = ctx.path + "#" + label
        if let s = ctx.graph.storage[key] as? _StateStorage<Value> { box.storage = s }
        else { let s = _StateStorage(box.initial); ctx.graph.storage[key] = s; box.storage = s }
        ctx.graph.usedKeys.insert(key)
        box.graph = ctx.graph
    }
}

// MARK: - Environment

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues: CustomStringConvertible {
    var values: [ObjectIdentifier: Any] = [:]
    public init() {}
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { values[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { values[ObjectIdentifier(key)] = newValue }
    }
    public var description: String { "EnvironmentValues(\(values.count) values)" }
}

@propertyWrapper
public struct Environment<Value>: DynamicProperty, _DynamicProperty {
    final class Box { var value: Value?; init() {} }
    let keyPath: KeyPath<EnvironmentValues, Value>
    let box = Box()
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { self.keyPath = keyPath }
    public var wrappedValue: Value {
        if let v = box.value { return v }
        return EnvironmentValues()[keyPath: keyPath]
    }
    func _install(_ ctx: _Context, label: String) { box.value = ctx.environment[keyPath: keyPath] }
}

struct _ColorSchemeKey: EnvironmentKey { static var defaultValue: ColorScheme { .light } }
struct _FontKey: EnvironmentKey { static var defaultValue: Font? { nil } }
struct _ForegroundKey: EnvironmentKey { static var defaultValue: Color? { nil } }
struct _TintKey: EnvironmentKey { static var defaultValue: Color? { nil } }
struct _LineLimitKey: EnvironmentKey { static var defaultValue: (Int?, Int?) { (nil, nil) } }
struct _MultilineAlignmentKey: EnvironmentKey { static var defaultValue: TextAlignment { .leading } }
struct _EnabledKey: EnvironmentKey { static var defaultValue: Bool { true } }
struct _OpenURLKey: EnvironmentKey { static var defaultValue: OpenURLAction { OpenURLAction(handler: { _ in .systemAction }) } }
struct _DismissKey: EnvironmentKey { static var defaultValue: DismissAction { DismissAction(action: {}) } }
struct _LocaleKey: EnvironmentKey { static var defaultValue: Locale { Locale.current } }
struct _ListContextKey: EnvironmentKey { static var defaultValue: Bool { false } }
struct _TextFieldTraitsKey: EnvironmentKey { static var defaultValue: _TextTraits { _TextTraits() } }

struct _TextTraits {
    var keyboardType: UIKeyboardType = .default
    var autocorrectionDisabled = false
    var autocapitalization: TextInputAutocapitalization? = nil
    var submitLabel: UIReturnKeyType = .default
}

extension EnvironmentValues {
    public var colorScheme: ColorScheme { get { self[_ColorSchemeKey.self] } set { self[_ColorSchemeKey.self] = newValue } }
    public var font: Font? { get { self[_FontKey.self] } set { self[_FontKey.self] = newValue } }
    public var isEnabled: Bool { get { self[_EnabledKey.self] } set { self[_EnabledKey.self] = newValue } }
    public var openURL: OpenURLAction { get { self[_OpenURLKey.self] } set { self[_OpenURLKey.self] = newValue } }
    public var dismiss: DismissAction { get { self[_DismissKey.self] } set { self[_DismissKey.self] = newValue } }
    public var locale: Locale { get { self[_LocaleKey.self] } set { self[_LocaleKey.self] = newValue } }
    public var multilineTextAlignment: TextAlignment { get { self[_MultilineAlignmentKey.self] } set { self[_MultilineAlignmentKey.self] = newValue } }
    public var lineLimit: Int? { get { self[_LineLimitKey.self].1 } set { self[_LineLimitKey.self] = (nil, newValue) } }
    var _foreground: Color? { get { self[_ForegroundKey.self] } set { self[_ForegroundKey.self] = newValue } }
    var _tint: Color? { get { self[_TintKey.self] } set { self[_TintKey.self] = newValue } }
    var _lineRange: (Int?, Int?) { get { self[_LineLimitKey.self] } set { self[_LineLimitKey.self] = newValue } }
    var _inList: Bool { get { self[_ListContextKey.self] } set { self[_ListContextKey.self] = newValue } }
    var _textTraits: _TextTraits { get { self[_TextFieldTraitsKey.self] } set { self[_TextFieldTraitsKey.self] = newValue } }
}

public enum ColorScheme: Hashable, CaseIterable, Sendable { case light, dark }

public struct OpenURLAction {
    public struct Result: Sendable {
        let kind: Int
        public static let handled = Result(kind: 0)
        public static let discarded = Result(kind: 1)
        public static let systemAction = Result(kind: 2)
        public static func systemAction(_ url: URL) -> Result { Result(kind: 2) }
    }
    let handler: (URL) -> Result
    public init(handler: @escaping (URL) -> Result) { self.handler = handler }
    @MainActor public func callAsFunction(_ url: URL) {
        let r = handler(url)
        if r.kind == 2 { UIApplication.shared.open(url, options: [:], completionHandler: nil) }
    }
    @MainActor public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {
        let r = handler(url)
        if r.kind == 2 { UIApplication.shared.open(url, options: [:], completionHandler: completion) } else { completion(r.kind == 0) }
    }
}

public struct DismissAction {
    let action: () -> Void
    @MainActor public func callAsFunction() { action() }
}

// MARK: - Context

/// Evaluation context: structural path, environment, and the graph that owns state.
@MainActor final class _Context {
    let graph: _Graph
    let path: String
    var environment: EnvironmentValues
    var nav: _NavLevel?
    init(graph: _Graph, path: String, environment: EnvironmentValues, nav: _NavLevel?) {
        self.graph = graph; self.path = path; self.environment = environment; self.nav = nav
    }
    func child(_ component: String) -> _Context { _Context(graph: graph, path: path + "/" + component, environment: environment, nav: nav) }
    func with(_ update: (inout EnvironmentValues) -> Void) -> _Context {
        var env = environment; update(&env)
        return _Context(graph: graph, path: path, environment: env, nav: nav)
    }
}
