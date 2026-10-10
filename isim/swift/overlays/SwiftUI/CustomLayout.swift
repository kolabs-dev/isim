// isim SwiftUI: the Layout protocol (custom layouts with sizeThatFits / placeSubviews, caches, layout values),
// AnyLayout and the stock HStackLayout / VStackLayout / ZStackLayout / GridLayout, `.position`, alignment guides
// (`.alignmentGuide`, custom AlignmentID; honoured by HStack / VStack / ZStack), `containerRelativeFrame`,
// `safeAreaInset`, `safeAreaPadding` and `contentMargins`.
import UIKit

// MARK: - Proposals, dimensions, alignment IDs

public struct ProposedViewSize: Equatable, Sendable {
    public var width: CGFloat?, height: CGFloat?
    public init(width: CGFloat?, height: CGFloat?) { self.width = width; self.height = height }
    public init(_ size: CGSize) { width = size.width; height = size.height }
    public static let zero = ProposedViewSize(width: 0, height: 0)
    public static let unspecified = ProposedViewSize(width: nil, height: nil)
    public static let infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize {
        CGSize(width: width ?? size.width, height: height ?? size.height)
    }
    var _p: _Proposal { _Proposal(width: width.map { $0.isInfinite ? 1e6 : $0 }, height: height.map { $0.isInfinite ? 1e6 : $0 }) }
}

public protocol AlignmentID { static func defaultValue(in context: ViewDimensions) -> CGFloat }
/// Custom alignment IDs get numbers from 100 on (0-2 are leading/center/trailing, top/center/bottom).
@MainActor final class _AlignmentRegistry {
    static var ids: [ObjectIdentifier: Int] = [:]
    static var defaults: [Int: (ViewDimensions) -> CGFloat] = [:]
    static func id(_ t: AlignmentID.Type) -> Int {
        if let i = ids[ObjectIdentifier(t)] { return i }
        let i = 100 + ids.count
        ids[ObjectIdentifier(t)] = i; defaults[i] = { t.defaultValue(in: $0) }
        return i
    }
}
extension HorizontalAlignment {
    public init(_ id: AlignmentID.Type) { self.init(id: MainActor.assumeIsolated { _AlignmentRegistry.id(id) }) }
}
extension VerticalAlignment {
    public init(_ id: AlignmentID.Type) { self.init(id: MainActor.assumeIsolated { _AlignmentRegistry.id(id) }) }
}

/// A view's size and alignment guides (explicit `.alignmentGuide` values or the defaults).
public struct ViewDimensions: Equatable {
    public let width: CGFloat, height: CGFloat
    let node: _Node?
    public static func == (a: ViewDimensions, b: ViewDimensions) -> Bool { a.width == b.width && a.height == b.height }
    public subscript(guide: HorizontalAlignment) -> CGFloat { MainActor.assumeIsolated { _guide(node, CGSize(width: width, height: height), horizontal: true, guide.id) } }
    public subscript(guide: VerticalAlignment) -> CGFloat { MainActor.assumeIsolated { _guide(node, CGSize(width: width, height: height), horizontal: false, guide.id) } }
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { MainActor.assumeIsolated { _explicitGuide(node, CGSize(width: width, height: height), horizontal: true, guide.id) } }
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? { MainActor.assumeIsolated { _explicitGuide(node, CGSize(width: width, height: height), horizontal: false, guide.id) } }
}

final class _AlignmentGuideNode: _WrapperNode {
    let horizontal: Bool, id: Int, compute: (ViewDimensions) -> CGFloat
    init(path: String, horizontal: Bool, id: Int, compute: @escaping (ViewDimensions) -> CGFloat, child: _Node) {
        self.horizontal = horizontal; self.id = id; self.compute = compute; super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
@MainActor func _explicitGuide(_ n: _Node?, _ s: CGSize, horizontal: Bool, _ id: Int) -> CGFloat? {
    var x = n
    while let c = x {
        if let g = c as? _AlignmentGuideNode, g.horizontal == horizontal, g.id == id {
            return g.compute(ViewDimensions(width: s.width, height: s.height, node: g.child))
        }
        if let st = c as? _StackNode { return _stackGuide(st, s, horizontal: horizontal, id) }
        x = c.children.count == 1 && !(c is _ZStackNode) ? c.children[0] : nil
    }
    return nil
}
/// A stack's explicit guide comes from its first child that has one (offset by where the stack puts that child).
@MainActor func _stackGuide(_ st: _StackNode, _ s: CGSize, horizontal: Bool, _ id: Int) -> CGFloat? {
    let nodes = _flatten(st.children)
    guard !nodes.isEmpty else { return nil }
    let sizes = _stackSizes(nodes, axis: st.axis, spacing: st.spacing, _Proposal(width: s.width, height: s.height))
    let along = horizontal == (st.axis == .horizontal)
    let crossID = st.axis == .vertical ? st.alignment.horizontal.id : st.alignment.vertical.id
    let guided = along ? nil : _guidedAxis(nodes, sizes, horizontal: horizontal, crossID)
    var pos: CGFloat = 0
    for (i, n) in nodes.enumerated() {
        let size = sizes[i]
        if let g = _explicitGuide(n, size, horizontal: horizontal, id) {
            if along { return pos + g }
            let extent = horizontal ? s.width : s.height, w = horizontal ? size.width : size.height
            if let gd = guided { return max(0, (extent - gd.extent) / 2) + gd.offsets[i] + g }
            let off: CGFloat = crossID == 0 ? 0 : crossID == 2 ? extent - w : (extent - w) / 2
            return off + g
        }
        pos += size[st.axis] + st.spacing
    }
    return nil
}
@MainActor func _guide(_ n: _Node?, _ s: CGSize, horizontal: Bool, _ id: Int) -> CGFloat {
    if let e = _explicitGuide(n, s, horizontal: horizontal, id) { return e }
    let extent = horizontal ? s.width : s.height
    switch id {
    case 0: return 0
    case 1: return extent / 2
    case 2: return extent
    default: return _AlignmentRegistry.defaults[id]?(ViewDimensions(width: s.width, height: s.height, node: nil)) ?? 0
    }
}
@MainActor func _hasGuides(_ nodes: [_Node], horizontal: Bool, _ id: Int) -> Bool {
    if id >= 100 { return true }
    return nodes.contains { _explicitGuide($0, .zero, horizontal: horizontal, id) != nil }
}
/// Offsets that line up the children's guides along one axis, and the extent they cover (nil: no explicit guides,
/// the stack's plain leading/center/trailing placement applies).
@MainActor func _guidedAxis(_ nodes: [_Node], _ sizes: [CGSize], horizontal: Bool, _ id: Int) -> (offsets: [CGFloat], extent: CGFloat)? {
    guard !nodes.isEmpty, _hasGuides(nodes, horizontal: horizontal, id) else { return nil }
    let g = nodes.indices.map { _guide(nodes[$0], sizes[$0], horizontal: horizontal, id) }
    let maxG = g.max() ?? 0
    let offsets = g.map { maxG - $0 }
    let extent = nodes.indices.map { offsets[$0] + (horizontal ? sizes[$0].width : sizes[$0].height) }.max() ?? 0
    return (offsets, extent)
}

extension View {
    public func alignmentGuide(_ g: HorizontalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {
        _modify { ctx, c in _AlignmentGuideNode(path: ctx.path, horizontal: true, id: g.id, compute: computeValue, child: _resolve(c, ctx.child("ag"))) }
    }
    public func alignmentGuide(_ g: VerticalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {
        _modify { ctx, c in _AlignmentGuideNode(path: ctx.path, horizontal: false, id: g.id, compute: computeValue, child: _resolve(c, ctx.child("ag"))) }
    }
}

// MARK: - position

/// Takes the proposed space and centres the child at the point (parent coordinates).
final class _PositionNode: _WrapperNode {
    let point: CGPoint
    init(path: String, point: CGPoint, child: _Node) { self.point = point; super.init(path: path, child: child) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: min(p.width ?? 10, 1e6), height: min(p.height ?? 10, 1e6)) }
    override func place(_ rect: CGRect) {
        frame = rect
        let s = child.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        child.place(CGRect(x: point.x - s.width / 2, y: point.y - s.height / 2, width: s.width, height: s.height))
    }
}
extension View {
    public func position(_ position: CGPoint) -> some View {
        _modify { ctx, c in _PositionNode(path: ctx.path, point: position, child: _resolve(c, ctx.child("pos"))) }
    }
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View { position(CGPoint(x: x, y: y)) }
}

// MARK: - Layout protocol

public protocol LayoutValueKey {
    associatedtype Value
    static var defaultValue: Value { get }
}
final class _LayoutValueNode: _WrapperNode {
    let key: ObjectIdentifier, value: Any
    init(path: String, key: ObjectIdentifier, value: Any, child: _Node) { self.key = key; self.value = value; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
extension View {
    public func layoutValue<K: LayoutValueKey>(key: K.Type, value: K.Value) -> some View {
        _modify { ctx, c in _LayoutValueNode(path: ctx.path, key: ObjectIdentifier(K.self), value: value, child: _resolve(c, ctx.child("lv"))) }
    }
}

public struct ViewSpacing: Sendable {
    public static let zero = ViewSpacing(value: 0)
    let value: CGFloat
    public init() { value = 8 }
    init(value: CGFloat) { self.value = value }
    public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat { max(value, next.value) }
    public mutating func formUnion(_ other: ViewSpacing, edges: Edge.Set = .all) {}
    public func union(_ other: ViewSpacing, edges: Edge.Set = .all) -> ViewSpacing { self }
}
public struct LayoutProperties: Sendable {
    public var stackOrientation: Axis?
    public init() {}
}

/// A child of a custom layout: measure it and place it.
public struct LayoutSubview: Equatable {
    let node: _Node
    let placer: _LayoutPlacer
    let index: Int
    public static func == (a: LayoutSubview, b: LayoutSubview) -> Bool { a.node === b.node }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize {
        MainActor.assumeIsolated { node.isSpacer ? CGSize(width: proposal.width.map { min($0, 1e6) } ?? 8, height: proposal.height.map { min($0, 1e6) } ?? 8) : node.sizeThatFits(proposal._p) }
    }
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions {
        let s = sizeThatFits(proposal)
        return ViewDimensions(width: s.width, height: s.height, node: node)
    }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {
        let s = sizeThatFits(proposal)
        let o = placer.origin
        let r = CGRect(x: position.x - anchor.x * s.width - o.x, y: position.y - anchor.y * s.height - o.y, width: s.width, height: s.height)
        MainActor.assumeIsolated { node.place(r) }
        placer.placed.insert(index)
    }
    public var priority: Double { MainActor.assumeIsolated { node.layoutPriority } }
    public var spacing: ViewSpacing { ViewSpacing() }
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value {
        MainActor.assumeIsolated {
            var x: _Node? = node
            while let c = x {
                if let v = c as? _LayoutValueNode, v.key == ObjectIdentifier(K.self), let value = v.value as? K.Value { return value }
                x = c.children.count == 1 ? c.children[0] : nil
            }
            return K.defaultValue
        }
    }
}
final class _LayoutPlacer { var placed: Set<Int> = []; var origin = CGPoint.zero }

public struct LayoutSubviews: RandomAccessCollection, Equatable {
    let items: [LayoutSubview]
    /// the container's direction (SwiftUI mirrors the placements itself: Graph.mirrorRTL)
    var rtl = false
    public typealias Index = Int
    public typealias Element = LayoutSubview
    public typealias SubSequence = LayoutSubviews
    public var startIndex: Int { 0 }
    public var endIndex: Int { items.count }
    public subscript(i: Int) -> LayoutSubview { items[i] }
    public subscript(r: Range<Int>) -> LayoutSubviews { LayoutSubviews(items: Array(items[r]), rtl: rtl) }
    public var layoutDirection: LayoutDirection { rtl ? .rightToLeft : .leftToRight }
    public static func == (a: LayoutSubviews, b: LayoutSubviews) -> Bool { a.items == b.items }
}

public protocol Layout {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews
    static var layoutProperties: LayoutProperties { get }
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)
    func makeCache(subviews: Subviews) -> Cache
    func updateCache(_ cache: inout Cache, subviews: Subviews)
    func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing
    func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGFloat?
    func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGFloat?
}
extension Layout {
    public static var layoutProperties: LayoutProperties { LayoutProperties() }
    public func updateCache(_ cache: inout Cache, subviews: Subviews) { cache = makeCache(subviews: subviews) }
    public func spacing(subviews: Subviews, cache: inout Cache) -> ViewSpacing { ViewSpacing() }
    public func explicitAlignment(of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGFloat? { nil }
    public func explicitAlignment(of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGFloat? { nil }
    /// `MyLayout { ... }` lays the views out with this layout.
    public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> some View { _LayoutView(layout: AnyLayout(self), content: content()) }
}
extension Layout where Cache == Void {
    public func makeCache(subviews: Subviews) -> Cache { () }
}

/// Type-erased layout: switching between layouts keeps the children (and their state).
public struct AnyLayout: Layout {
    public typealias Cache = _AnyCache
    public final class _AnyCache { var value: Any; init(_ v: Any) { value = v } }
    let base: Any
    let _make: (LayoutSubviews) -> Any
    let _size: (ProposedViewSize, LayoutSubviews, inout Any) -> CGSize
    let _place: (CGRect, ProposedViewSize, LayoutSubviews, inout Any) -> Void
    public init<L: Layout>(_ layout: L) {
        if let a = layout as? AnyLayout { self = a; return }
        base = layout
        _make = { layout.makeCache(subviews: $0) }
        _size = { p, s, c in var cc = c as! L.Cache; defer { c = cc }; return layout.sizeThatFits(proposal: p, subviews: s, cache: &cc) }
        _place = { b, p, s, c in var cc = c as! L.Cache; defer { c = cc }; layout.placeSubviews(in: b, proposal: p, subviews: s, cache: &cc) }
    }
    public func makeCache(subviews: Subviews) -> _AnyCache { _AnyCache(_make(subviews)) }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout _AnyCache) -> CGSize { _size(proposal, subviews, &cache.value) }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout _AnyCache) { _place(bounds, proposal, subviews, &cache.value) }
}

struct _LayoutView<Content: View>: View, _PrimitiveView {
    let layout: AnyLayout, content: Content
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        // the children keep one identity whatever the layout (AnyLayout switches keep state)
        let children = _flatten([_resolve(content, ctx.child("layout"))])
        switch layout.base {
        case let h as HStackLayout: return _StackNode(path: ctx.path, axis: .horizontal, spacing: h.spacing, alignment: Alignment(horizontal: .center, vertical: h.alignment), children: children)
        case let v as VStackLayout: return _StackNode(path: ctx.path, axis: .vertical, spacing: v.spacing, alignment: Alignment(horizontal: v.alignment, vertical: .center), children: children)
        case let z as ZStackLayout: return _ZStackNode(path: ctx.path, alignment: z.alignment, children: children)
        default: return _CustomLayoutNode(path: ctx.path, layout: layout, children: children)
        }
    }
}
final class _CustomLayoutNode: _Node {
    let layout: AnyLayout
    let placer = _LayoutPlacer()
    lazy var subviews = LayoutSubviews(items: children.enumerated().map { LayoutSubview(node: $1, placer: placer, index: $0) }, rtl: isRTL)
    lazy var cache: AnyLayout._AnyCache = layout.makeCache(subviews: subviews)
    init(path: String, layout: AnyLayout, children: [_Node]) { self.layout = layout; super.init(path: path, children: children) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        var c = cache
        return layout.sizeThatFits(proposal: ProposedViewSize(width: p.width, height: p.height), subviews: subviews, cache: &c)
    }
    override func place(_ rect: CGRect) {
        frame = rect
        placer.placed = []; placer.origin = .zero
        var c = cache
        layout.placeSubviews(in: CGRect(origin: .zero, size: rect.size), proposal: ProposedViewSize(width: rect.width, height: rect.height), subviews: subviews, cache: &c)
        // children the layout did not place sit in the middle (like SwiftUI)
        for (i, n) in children.enumerated() where !placer.placed.contains(i) {
            let s = n.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
            n.place(CGRect(x: (rect.width - s.width) / 2, y: (rect.height - s.height) / 2, width: s.width, height: s.height))
        }
    }
}

// MARK: - Stock layouts

@MainActor private func _tempStack(_ s: LayoutSubviews, axis: Axis, spacing: CGFloat?, alignment: Alignment) -> _StackNode {
    _StackNode(path: "_layout", axis: axis, spacing: spacing, alignment: alignment, children: s.items.map(\.node))
}
public struct HStackLayout: Layout {
    public var alignment: VerticalAlignment, spacing: CGFloat?
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .horizontal; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        MainActor.assumeIsolated { _tempStack(subviews, axis: .horizontal, spacing: spacing, alignment: Alignment(horizontal: .center, vertical: alignment)).sizeThatFits(proposal._p) }
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        MainActor.assumeIsolated { _tempStack(subviews, axis: .horizontal, spacing: spacing, alignment: Alignment(horizontal: .center, vertical: alignment)).place(bounds) }
        for s in subviews { s.placer.placed.insert(s.index) }
    }
}
public struct VStackLayout: Layout {
    public var alignment: HorizontalAlignment, spacing: CGFloat?
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) { self.alignment = alignment; self.spacing = spacing }
    public static var layoutProperties: LayoutProperties { var p = LayoutProperties(); p.stackOrientation = .vertical; return p }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        MainActor.assumeIsolated { _tempStack(subviews, axis: .vertical, spacing: spacing, alignment: Alignment(horizontal: alignment, vertical: .center)).sizeThatFits(proposal._p) }
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        MainActor.assumeIsolated { _tempStack(subviews, axis: .vertical, spacing: spacing, alignment: Alignment(horizontal: alignment, vertical: .center)).place(bounds) }
        for s in subviews { s.placer.placed.insert(s.index) }
    }
}
public struct ZStackLayout: Layout {
    public var alignment: Alignment
    public init(alignment: Alignment = .center) { self.alignment = alignment }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        MainActor.assumeIsolated { _ZStackNode(path: "_layout", alignment: alignment, children: subviews.items.map(\.node)).sizeThatFits(proposal._p) }
    }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        MainActor.assumeIsolated { _ZStackNode(path: "_layout", alignment: alignment, children: subviews.items.map(\.node)).place(bounds) }
        for s in subviews { s.placer.placed.insert(s.index) }
    }
}
public struct GridLayout: Layout {
    public var alignment: Alignment, horizontalSpacing: CGFloat?, verticalSpacing: CGFloat?
    public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) {
        self.alignment = alignment; self.horizontalSpacing = horizontalSpacing; self.verticalSpacing = verticalSpacing
    }
    func node(_ s: Subviews) -> _GridLayoutNode {
        MainActor.assumeIsolated { _GridLayoutNode(path: "_layout", alignment: alignment, hSpacing: horizontalSpacing ?? 8, vSpacing: verticalSpacing ?? 8,
                                                   child: _GroupNode(path: "_layout/g", children: s.items.map(\.node))) }
    }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize { MainActor.assumeIsolated { node(subviews).sizeThatFits(proposal._p) } }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        MainActor.assumeIsolated { node(subviews).place(bounds) }
        for s in subviews { s.placer.placed.insert(s.index) }
    }
}

// MARK: - containerRelativeFrame

/// The size of the nearest container (scroll view, list, navigation stack or tab content, split view column, or the
/// window's safe area), set while laying out.
@MainActor var _containerSizes: [CGSize] = []
/// Lays out `body` inside a container of `size` (containerRelativeFrame measures against it).
@MainActor func _inContainer<T>(_ size: CGSize, _ body: () -> T) -> T {
    _containerSizes.append(size)
    defer { _containerSizes.removeLast() }
    return body()
}
final class _ContainerRelativeNode: _WrapperNode {
    let axes: Axis.Set, alignment: Alignment, length: (CGFloat, Axis) -> CGFloat
    init(path: String, axes: Axis.Set, alignment: Alignment, length: @escaping (CGFloat, Axis) -> CGFloat, child: _Node) {
        self.axes = axes; self.alignment = alignment; self.length = length; super.init(path: path, child: child)
    }
    func target(_ p: _Proposal) -> _Proposal {
        let c = _containerSizes.last ?? UIScreen.main.bounds.size
        return _Proposal(width: axes.contains(.horizontal) ? length(c.width, .horizontal) : p.width,
                         height: axes.contains(.vertical) ? length(c.height, .vertical) : p.height)
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let t = target(p)
        let s = child.sizeThatFits(t)
        return CGSize(width: axes.contains(.horizontal) ? t.width! : s.width, height: axes.contains(.vertical) ? t.height! : s.height)
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let s = child.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        child.place(_align(CGSize(width: min(s.width, rect.width), height: min(s.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
    }
}
extension View {
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View {
        containerRelativeFrame(axes, alignment: alignment) { l, _ in l }
    }
    public func containerRelativeFrame(_ axes: Axis.Set, count: Int, span: Int = 1, spacing: CGFloat, alignment: Alignment = .center) -> some View {
        containerRelativeFrame(axes, alignment: alignment) { l, _ in
            let n = CGFloat(max(1, count))
            return max(0, (l - spacing * (n - 1)) / n * CGFloat(span) + spacing * CGFloat(span - 1))
        }
    }
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center, _ length: @escaping (CGFloat, Axis) -> CGFloat) -> some View {
        _modify { ctx, c in _ContainerRelativeNode(path: ctx.path, axes: axes, alignment: alignment, length: length, child: _resolve(c, ctx.child("crf"))) }
    }
}

// MARK: - safeAreaInset, safeAreaPadding, contentMargins

public enum HorizontalEdge: Int8, CaseIterable, Sendable {
    case leading, trailing
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let leading = Set(rawValue: 1), trailing = Set(rawValue: 2), all = Set(rawValue: 3)
    }
}
/// The inset content sits at an edge. Like SwiftUI, a scroll view (or list) filling the main content extends beneath
/// it, its content inset by the inset's size (so the last rows scroll out from under it); other content is laid out
/// in the rest.
final class _SafeAreaInsetNode: _Node {
    let edge: Edge, spacing: CGFloat, alignment: Alignment
    var main: _Node { children[0] }
    var inset: _Node { children[1] }
    init(path: String, edge: Edge, spacing: CGFloat, alignment: Alignment, main: _Node, inset: _Node) {
        self.edge = edge; self.spacing = spacing; self.alignment = alignment
        super.init(path: path, children: [main, inset])
    }
    override var ignoresSafeArea: Bool { main.ignoresSafeArea }
    var vertical: Bool { edge == .top || edge == .bottom }
    override func sizeThatFits(_ p: _Proposal) -> CGSize {
        let i = inset.sizeThatFits(vertical ? _Proposal(width: p.width, height: nil) : _Proposal(width: nil, height: p.height))
        let used = (vertical ? i.height : i.width) + spacing
        let m = main.sizeThatFits(vertical ? _Proposal(width: p.width, height: p.height.map { max(0, $0 - used) })
                                           : _Proposal(width: p.width.map { max(0, $0 - used) }, height: p.height))
        return vertical ? CGSize(width: max(m.width, i.width), height: m.height + used) : CGSize(width: m.width + used, height: max(m.height, i.height))
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let i = inset.sizeThatFits(vertical ? _Proposal(width: rect.width, height: nil) : _Proposal(width: nil, height: rect.height))
        let used = (vertical ? i.height : i.width) + spacing
        var mainRect = CGRect(origin: .zero, size: rect.size), insetRect = mainRect
        switch edge {
        case .top: insetRect.size.height = i.height; mainRect.origin.y = used; mainRect.size.height -= used
        case .bottom: insetRect.origin.y = rect.height - i.height; insetRect.size.height = i.height; mainRect.size.height -= used
        case .leading: insetRect.size.width = i.width; mainRect.origin.x = used; mainRect.size.width -= used
        case .trailing: insetRect.origin.x = rect.width - i.width; insetRect.size.width = i.width; mainRect.size.width -= used
        }
        var extra = UIEdgeInsets.zero
        switch edge { case .top: extra.top = used; case .bottom: extra.bottom = used; case .leading: extra.left = used; case .trailing: extra.right = used }
        if !_placeBeneath(main, in: CGRect(origin: .zero, size: rect.size), extra) { main.place(mainRect) }
        inset.place(_align(CGSize(width: min(i.width, insetRect.width), height: min(i.height, insetRect.height)), in: insetRect, alignment))
    }
}
/// A scroll view or list that fills `rect` (through modifiers that keep its size): placed there with `extra` added to
/// its content insets. False if `main` is not one (it is laid out in the remaining space instead).
@MainActor func _placeBeneath(_ main: _Node, in rect: CGRect, _ extra: UIEdgeInsets) -> Bool {
    var x: _Node? = main, scroll: _Node?
    while let n = x {
        if n is _ScrollNode || n is _ListNode { scroll = n; break }
        if n is _PaddingNode || n is _PositionNode || n is _AspectNode { break }
        x = n.children.count == 1 ? n.children[0] : nil
    }
    guard let s = scroll else { return false }
    let fit = main.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
    guard abs(fit.width - rect.width) < 0.5, abs(fit.height - rect.height) < 0.5 else { return false }
    if let sc = s as? _ScrollNode { sc.extraInsets = sc.extraInsets.adding(extra) } else if let l = s as? _ListNode { l.extraInsets = l.extraInsets.adding(extra) }
    main.place(rect)
    return true
}
extension UIEdgeInsets {
    func adding(_ o: UIEdgeInsets) -> UIEdgeInsets { UIEdgeInsets(top: top + o.top, left: left + o.left, bottom: bottom + o.bottom, right: right + o.right) }
}
/// safeAreaPadding: a scroll view or list inside gets the padding as content insets (its content scrolls through the
/// padded area); other content is padded.
final class _SafeAreaPaddingNode: _WrapperNode {
    let insets: EdgeInsets
    init(path: String, insets: EdgeInsets, child: _Node) { self.insets = insets; super.init(path: path, child: child) }
    override var ignoresSafeArea: Bool { child.ignoresSafeArea }
    var pad: _PaddingNode { _PaddingNode(path: path + "/pad", insets: insets, child: child) }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { pad.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        let extra = UIEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
        if !_placeBeneath(child, in: CGRect(origin: .zero, size: rect.size), extra) {
            child.place(CGRect(x: insets.leading, y: insets.top, width: max(0, rect.width - insets.leading - insets.trailing), height: max(0, rect.height - insets.top - insets.bottom)))
        }
    }
}
extension View {
    public func safeAreaInset<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View {
        let v = content()
        return _modify { ctx, c in
            _SafeAreaInsetNode(path: ctx.path, edge: edge == .top ? .top : .bottom, spacing: spacing ?? 0, alignment: Alignment(horizontal: alignment, vertical: .center),
                               main: _resolve(c, ctx.child("sai")), inset: _resolve(v, ctx.child("saic")))
        }
    }
    public func safeAreaInset<V: View>(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View {
        let v = content()
        return _modify { ctx, c in
            _SafeAreaInsetNode(path: ctx.path, edge: edge == .leading ? .leading : .trailing, spacing: spacing ?? 0, alignment: Alignment(horizontal: .center, vertical: alignment),
                               main: _resolve(c, ctx.child("sai")), inset: _resolve(v, ctx.child("saic")))
        }
    }
    /// Adds to the safe area: scroll views and lists inside scroll through it, other content is padded.
    public func safeAreaPadding(_ insets: EdgeInsets) -> some View {
        _modify { ctx, c in _SafeAreaPaddingNode(path: ctx.path, insets: insets, child: _resolve(c, ctx.child("sap"))) }
    }
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View {
        let l = length ?? 16
        return safeAreaPadding(EdgeInsets(top: edges.contains(.top) ? l : 0, leading: edges.contains(.leading) ? l : 0,
                                          bottom: edges.contains(.bottom) ? l : 0, trailing: edges.contains(.trailing) ? l : 0))
    }
    public func safeAreaPadding(_ length: CGFloat) -> some View { safeAreaPadding(.all, length) }
    /// Margins around scroll view content (and its indicators' insets on iOS).
    /// Margins of scroll views inside: `.scrollContent` insets the content, `.scrollIndicators` the indicators,
    /// `.automatic` both.
    public func contentMargins(_ edges: Edge.Set = .all, _ insets: EdgeInsets, for placement: ContentMarginPlacement = .automatic) -> some View {
        _env { e in
            func set(_ m: inout EdgeInsets) {
                if edges.contains(.top) { m.top = insets.top }; if edges.contains(.bottom) { m.bottom = insets.bottom }
                if edges.contains(.leading) { m.leading = insets.leading }; if edges.contains(.trailing) { m.trailing = insets.trailing }
            }
            if placement.id != 2 { var m = e._contentMargins ?? EdgeInsets(); set(&m); e._contentMargins = m }
            if placement.id != 1 { var m = e._indicatorMargins ?? EdgeInsets(); set(&m); e._indicatorMargins = m }
        }
    }
    public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for placement: ContentMarginPlacement = .automatic) -> some View {
        let l = length ?? 16
        return contentMargins(edges, EdgeInsets(top: l, leading: l, bottom: l, trailing: l), for: placement)
    }
    public func contentMargins(_ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> some View { contentMargins(.all, length, for: placement) }
}
public struct ContentMarginPlacement: Sendable {
    let id: Int
    public static let automatic = ContentMarginPlacement(id: 0), scrollContent = ContentMarginPlacement(id: 1), scrollIndicators = ContentMarginPlacement(id: 2)
}
struct _ContentMarginsKey: EnvironmentKey { static var defaultValue: EdgeInsets? { nil } }
struct _IndicatorMarginsKey: EnvironmentKey { static var defaultValue: EdgeInsets? { nil } }
extension EnvironmentValues {
    var _contentMargins: EdgeInsets? { get { self[_ContentMarginsKey.self] } set { self[_ContentMarginsKey.self] = newValue } }
    var _indicatorMargins: EdgeInsets? { get { self[_IndicatorMarginsKey.self] } set { self[_IndicatorMarginsKey.self] = newValue } }
}
