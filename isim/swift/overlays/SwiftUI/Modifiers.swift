// isim SwiftUI: view modifiers.
import UIKit

/// A view built by a closure over the context (most modifiers).
struct _Modified<Content: View>: View, _PrimitiveView {
    let content: Content
    let make: @MainActor (_Context, Content) -> _Node
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { make(ctx, content) }
}
extension View {
    func _modify(_ make: @escaping @MainActor (_Context, Self) -> _Node) -> _Modified<Self> { _Modified(content: self, make: make) }
    /// Environment-only modifier: evaluates the content with an updated environment.
    func _env(_ update: @escaping (inout EnvironmentValues) -> Void) -> _Modified<Self> {
        _modify { ctx, c in _resolve(c, ctx.child("e").with(update)) }
    }
}

// MARK: - ViewModifier

public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifier_Content<Self>
    @ViewBuilder @MainActor func body(content: Self.Content) -> Self.Body
}
public struct _ViewModifier_Content<Modifier: ViewModifier>: View, _PrimitiveView {
    let make: @MainActor (_Context) -> _Node
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node { make(ctx) }
}
public struct ModifiedContent<Content, Modifier> {
    public var content: Content
    public var modifier: Modifier
    public init(content: Content, modifier: Modifier) { self.content = content; self.modifier = modifier }
}
extension ModifiedContent: View, _PrimitiveView where Content: View, Modifier: ViewModifier {
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let c = content
        let inner = _ViewModifier_Content<Modifier>(make: { cctx in _resolve(c, cctx.child("content")) })
        _attach(modifier, ctx)
        return _resolve(modifier.body(content: inner), ctx.child("m"))
    }
}
extension View {
    public func modifier<M: ViewModifier>(_ m: M) -> ModifiedContent<Self, M> { ModifiedContent(content: self, modifier: m) }
}

// MARK: - Environment-style modifiers

extension View {
    public func font(_ font: Font?) -> some View { _env { $0.font = font } }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View {
        _modify { ctx, c in _resolve(c, ctx.child("e").with { $0._foreground = _color(of: style, ctx.environment) }) }
    }
    public func foregroundColor(_ color: Color?) -> some View { _env { $0._foreground = color } }
    public func tint(_ color: Color?) -> some View { _env { $0._tint = color } }
    public func accentColor(_ color: Color?) -> some View { _env { $0._tint = color } }
    public func multilineTextAlignment(_ a: TextAlignment) -> some View { _env { $0.multilineTextAlignment = a } }
    public func lineLimit(_ n: Int?) -> some View { _env { $0._lineRange = (nil, n) } }
    public func lineLimit(_ r: ClosedRange<Int>) -> some View { _env { $0._lineRange = (r.lowerBound, r.upperBound) } }
    public func lineLimit(_ r: PartialRangeFrom<Int>) -> some View { _env { $0._lineRange = (r.lowerBound, nil) } }
    public func lineLimit(_ n: Int, reservesSpace: Bool) -> some View { _env { $0._lineRange = (reservesSpace ? n : nil, n) } }
    public func disabled(_ disabled: Bool) -> some View {
        _modify { ctx, c in
            let node = _resolve(c, ctx.child("e").with { if disabled { $0.isEnabled = false } })
            let p = _ViewPropsNode(path: ctx.path, child: node); p.disabled = disabled; if disabled { p.rowAction = nil }
            return p
        }
    }
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View { _env { $0[keyPath: keyPath] = value } }
    public func keyboardType(_ type: UIKeyboardType) -> some View { _env { $0._textTraits.keyboardType = type } }
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View { _env { $0._textTraits.autocorrectionDisabled = disable } }
    public func textInputAutocapitalization(_ a: TextInputAutocapitalization?) -> some View { _env { $0._textTraits.autocapitalization = a } }
    public func submitLabel(_ l: SubmitLabel) -> some View { _env { $0._textTraits.submitLabel = l.value } }
    public func preferredColorScheme(_ scheme: ColorScheme?) -> some View {
        _modify { ctx, c in
            if let s = scheme { ctx.graph.postRender.append { [weak g = ctx.graph] in g?.hostView?.window?.overrideUserInterfaceStyle = s == .dark ? .dark : .light } }
            return _resolve(c, ctx.child("e"))
        }
    }
}

// MARK: - Layout modifiers

extension View {
    public func padding(_ insets: EdgeInsets) -> some View {
        _modify { ctx, c in _PaddingNode(path: ctx.path, insets: insets, child: _resolve(c, ctx.child("p"))) }
    }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let l = length ?? 16
        return padding(EdgeInsets(top: edges.contains(.top) ? l : 0, leading: edges.contains(.leading) ? l : 0,
                                  bottom: edges.contains(.bottom) ? l : 0, trailing: edges.contains(.trailing) ? l : 0))
    }
    public func padding(_ length: CGFloat) -> some View { padding(.all, length) }
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        _modify { ctx, c in
            let f = _FrameNode(path: ctx.path, child: _resolve(c, ctx.child("f")))
            f.width = width; f.height = height; f.alignment = alignment
            return f
        }
    }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                      minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View {
        _modify { ctx, c in
            let f = _FrameNode(path: ctx.path, child: _resolve(c, ctx.child("f")))
            f.minWidth = minWidth; f.maxWidth = maxWidth; f.minHeight = minHeight; f.maxHeight = maxHeight; f.alignment = alignment
            return f
        }
    }
    public func background<S: ShapeStyle>(_ style: S) -> some View {
        _modify { ctx, c in
            if let m = style as? Material {
                return _BackgroundNode(path: ctx.path, color: nil, cornerRadius: 0, background: _MaterialNode(path: ctx.path + "/mat", kind: .rect, material: m), child: _resolve(c, ctx.child("b")))
            }
            return _BackgroundNode(path: ctx.path, color: _color(of: style, ctx.environment), cornerRadius: 0, background: nil, child: _resolve(c, ctx.child("b")))
        }
    }
    public func background<B: View>(alignment: Alignment = .center, @ViewBuilder content: () -> B) -> some View {
        let b = content()
        return _modify { ctx, c in _BackgroundNode(path: ctx.path, color: nil, cornerRadius: 0, background: _resolve(b, ctx.child("bg")), child: _resolve(c, ctx.child("b"))) }
    }
    public func cornerRadius(_ r: CGFloat) -> some View {
        _modify { ctx, c in
            let n = _BackgroundNode(path: ctx.path, color: nil, cornerRadius: r, background: nil, child: _resolve(c, ctx.child("r")))
            return n
        }
    }
    public func opacity(_ o: Double) -> some View {
        _modify { ctx, c in let p = _ViewPropsNode(path: ctx.path, child: _resolve(c, ctx.child("o"))); p.alpha = o; return p }
    }
    public func hidden() -> some View {
        _modify { ctx, c in let p = _ViewPropsNode(path: ctx.path, child: _resolve(c, ctx.child("h"))); p.hidden = true; return p }
    }
    public func layoutPriority(_ value: Double) -> some View {
        _modify { ctx, c in _PriorityNode(path: ctx.path, priority: value, child: _resolve(c, ctx.child("lp"))) }
    }
    public func fixedSize() -> some View { fixedSize(horizontal: true, vertical: true) }
    /// The child's ideal size on the fixed axes, whatever is proposed (text then never wraps or truncates).
    public func fixedSize(horizontal: Bool, vertical: Bool) -> some View {
        _modify { ctx, c in _FixedSizeNode(path: ctx.path, horizontal: horizontal, vertical: vertical, child: _resolve(c, ctx.child("fx"))) }
    }
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View {
        _modify { ctx, c in _IgnoreSafeAreaNode(path: ctx.path, edges: edges, child: _resolve(c, ctx.child("isa"))) }
    }
    public func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View { ignoresSafeArea(.all, edges: edges) }
    public func id<ID: Hashable>(_ id: ID) -> some View { _modify { ctx, c in _IDNode(path: ctx.path, tag: "\(id)", child: _resolve(c, ctx.child("id:\(id)"))) } }
    public func tag<V: Hashable>(_ tag: V) -> some View { self }
    public func clipped() -> some View { self }
}

final class _PriorityNode: _WrapperNode {
    let priority: Double
    init(path: String, priority: Double, child: _Node) { self.priority = priority; super.init(path: path, child: child) }
    override var layoutPriority: Double { priority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

// MARK: - Accessibility

extension View {
    public func accessibilityIdentifier(_ identifier: String) -> some View {
        _modify { ctx, c in let n = _resolve(c, ctx.child("a")); _tagDeepest(n) { $0.accessibilityIdentifier = identifier }; return n }
    }
    public func accessibilityLabel(_ label: Text) -> some View {
        _modify { ctx, c in let n = _resolve(c, ctx.child("a")); let s = label.string; _tagDeepest(n) { $0.accessibilityLabel = s }; return n }
    }
    public func accessibilityLabel(_ key: LocalizedStringKey) -> some View { accessibilityLabel(Text(key)) }
    @_disfavoredOverload public func accessibilityLabel<S: StringProtocol>(_ label: S) -> some View { accessibilityLabel(Text(label)) }
    public func accessibilityHint(_ hint: Text) -> some View { self }
    public func accessibilityHidden(_ hidden: Bool) -> some View { self }
}
/// Accessibility attributes go to the interactive element (text field, control) when there is one.
@MainActor func _tagDeepest(_ n: _Node, _ apply: (_Node) -> Void) {
    // the interactive element inside (switch, text field, button) carries the attributes, as in UIKit
    func find(_ x: _Node) -> _Node? {
        if x is _SwitchNode || x is _TextFieldNode || x is _ButtonNode { return x }
        for c in _flatten(x.children) { if let f = find(c) { return f } }
        return nil
    }
    apply(find(n) ?? n)
}

// MARK: - Focus

extension View {
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View {
        _modify { ctx, c in
            let link = _FocusLink(get: { condition.wrappedValue }, set: { condition.wrappedValue = $0 })
            let inner = ctx.child("f")
            _registerFocus(inner, link)
            return _resolve(c, inner)
        }
    }
    public func focused<V: Hashable>(_ binding: FocusState<V?>.Binding, equals value: V) -> some View {
        _modify { ctx, c in
            let link = _FocusLink(get: { binding.wrappedValue == value }, set: { binding.wrappedValue = $0 ? value : (binding.wrappedValue == value ? nil : binding.wrappedValue) })
            let inner = ctx.child("f")
            _registerFocus(inner, link)
            return _resolve(c, inner)
        }
    }
}
/// The focus link is found by the text field at (or directly under) the modified position.
@MainActor func _registerFocus(_ ctx: _Context, _ link: _FocusLink) {
    ctx.graph.focusLinks.append((ctx.path, link))
}

// MARK: - Lifecycle & change observation

extension View {
    public func onAppear(perform action: (() -> Void)? = nil) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#appear"
            ctx.graph.usedAppear.insert(key)
            if !ctx.graph.appeared.contains(key) {
                ctx.graph.appeared.insert(key)
                if let a = action { ctx.graph.postRender.append(a) }
            }
            return _resolve(c, ctx.child("l"))
        }
    }
    public func onDisappear(perform action: (() -> Void)? = nil) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#disappear"
            ctx.graph.usedAppear.insert(key)
            ctx.graph.appeared.insert(key)
            if let a = action { ctx.graph.disappearActions[key] = a }
            return _resolve(c, ctx.child("l"))
        }
    }
    public func task(priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#task"
            ctx.graph.usedTasks.insert(key)
            if ctx.graph.tasks[key] == nil {
                let g = ctx.graph
                g.postRender.append { g.tasks[key] = Task { @MainActor in await action() } }
                ctx.graph.tasks[key] = Task {}   // placeholder until started after this render
            }
            return _resolve(c, ctx.child("l"))
        }
    }
    public func task<T: Equatable>(id value: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#task", vkey = key + "#id"
            let g = ctx.graph
            g.usedTasks.insert(key); g.usedChanges.insert(vkey)
            let old = g.changeValues[vkey] as? T
            if g.tasks[key] == nil || old != value {
                g.tasks[key]?.cancel()
                g.changeValues[vkey] = value
                g.postRender.append { g.tasks[key] = Task { @MainActor in await action() } }
                g.tasks[key] = Task {}
            }
            return _resolve(c, ctx.child("l"))
        }
    }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some View {
        _modify { ctx, c in
            let key = ctx.path + "#change"
            let g = ctx.graph
            g.usedChanges.insert(key)
            if let old = g.changeValues[key] as? V {
                if old != value { g.postRender.append { action(old, value) } }
            } else if initial { g.postRender.append { action(value, value) } }
            g.changeValues[key] = value
            return _resolve(c, ctx.child("l"))
        }
    }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View {
        onChange(of: value, initial: initial) { (_: V, _: V) in action() }
    }
    @_disfavoredOverload
    public func onChange<V: Equatable>(of value: V, perform action: @escaping (V) -> Void) -> some View {
        onChange(of: value, initial: false) { (_: V, new: V) in action(new) }
    }
    public func onSubmit(of triggers: Any? = nil, _ action: @escaping () -> Void) -> some View {
        _modify { ctx, c in
            ctx.graph.submitActions[ctx.path] = action
            return _resolve(c, ctx.child("s"))
        }
    }
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View {
        _modify { ctx, c in _ButtonNode(path: ctx.path, child: _resolve(c, ctx.child("tap")), action: action, inList: ctx.environment._inList, enabled: true) }
    }
    public func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View { self }
    public func labelStyle<S>(_ style: S) -> some View { self }
    public func textFieldStyle<S>(_ style: S) -> some View { self }
    public func toggleStyle<S>(_ style: S) -> some View { self }
    public func contentShape<S>(_ shape: S) -> some View { self }
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View { self }
}
public struct ScrollDismissesKeyboardMode: Sendable {
    public static let automatic = ScrollDismissesKeyboardMode(), immediately = ScrollDismissesKeyboardMode()
    public static let interactively = ScrollDismissesKeyboardMode(), never = ScrollDismissesKeyboardMode()
}
public struct Animation: Equatable, Sendable {
    public static let `default` = Animation(), easeInOut = Animation(), easeIn = Animation(), easeOut = Animation(), linear = Animation(), spring = Animation()
}
@MainActor public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result { try body() }

public struct SafeAreaRegions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let container = SafeAreaRegions(rawValue: 1), keyboard = SafeAreaRegions(rawValue: 2), all = SafeAreaRegions(rawValue: 3)
}

/// Extends past the safe area on the given edges when it is laid out against them (see _Graph.extendIntoSafeArea).
final class _IgnoreSafeAreaNode: _WrapperNode {
    let edges: Edge.Set
    init(path: String, edges: Edge.Set, child: _Node) { self.edges = edges; super.init(path: path, child: child) }
    override var ignoresSafeArea: Bool { true }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}

final class _FixedSizeNode: _WrapperNode {
    let horizontal: Bool, vertical: Bool
    init(path: String, horizontal: Bool, vertical: Bool, child: _Node) { self.horizontal = horizontal; self.vertical = vertical; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    func proposal(_ p: _Proposal) -> _Proposal { _Proposal(width: horizontal ? nil : p.width, height: vertical ? nil : p.height) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(proposal(p)) }
    override func place(_ rect: CGRect) {
        frame = rect
        let s = child.sizeThatFits(proposal(_Proposal(width: rect.width, height: rect.height)))
        child.place(CGRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2, width: s.width, height: s.height))
    }
}
