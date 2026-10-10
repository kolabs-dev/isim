// isim SwiftUI (iOS 27.1): ArrangementView — primary and secondary content in an adaptive layout — with the split and
// overlay styles (`axes`), custom ArrangementViewStyles, and the split sizing modifiers (`splitArrangementLayoutRatio`,
// `splitArrangementLayoutSize`, `splitArrangementFixedLayoutSize`) and `overlayArrangementEdge`. Signatures from Apple's
// documentation. Adapted like isim's UIArrangementViewController (isim has no foldable device): split stacks the views
// in compact width in portrait and puts them side by side otherwise (within the allowed axes); sizes along the split
// come from the views' ratio / size / ideal size, the rest shared, the view with the lower layout priority taking what
// is left; overlay layers the primary over the secondary, both filling the arrangement (it would turn side by side,
// at `overlayArrangementEdge`, only when a device folds).
import UIKit

/// The styles of an ArrangementView.
@available(iOS 27.1, *)
public protocol ArrangementViewStyle {
    associatedtype Body: View
    typealias Configuration = ArrangementViewStyleConfiguration
    @ViewBuilder @MainActor func makeBody(configuration: Configuration) -> Body
}
/// The content of an arrangement view, for a custom style.
@available(iOS 27.1, *)
public struct ArrangementViewStyleConfiguration {
    public struct Primary: View { let content: AnyView; public var body: some View { content } }
    public struct Secondary: View { let content: AnyView; public var body: some View { content } }
    public var primary: Primary
    public var secondary: Secondary
}
@available(iOS 27.1, *)
public struct SplitArrangementViewStyle: ArrangementViewStyle {
    var axes: Axis.Set = [.horizontal, .vertical]
    public init() {}
    public func axes(_ axes: Axis.Set) -> SplitArrangementViewStyle { var s = self; s.axes = axes; return s }
    public func makeBody(configuration: Configuration) -> some View { _ArrangementLayout(kind: 0, axes: axes, primary: configuration.primary.content, secondary: configuration.secondary.content) }
}
@available(iOS 27.1, *)
public struct OverlayArrangementViewStyle: ArrangementViewStyle {
    var axes: Axis.Set = [.horizontal, .vertical]
    public init() {}
    public func axes(_ axes: Axis.Set) -> OverlayArrangementViewStyle { var s = self; s.axes = axes; return s }
    public func makeBody(configuration: Configuration) -> some View { _ArrangementLayout(kind: 1, axes: axes, primary: configuration.primary.content, secondary: configuration.secondary.content) }
}
/// The default style: split.
@available(iOS 27.1, *)
public struct AutomaticArrangementViewStyle: ArrangementViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { SplitArrangementViewStyle().makeBody(configuration: configuration) }
}
@available(iOS 27.1, *)
extension ArrangementViewStyle where Self == AutomaticArrangementViewStyle { public static var automatic: AutomaticArrangementViewStyle { .init() } }
@available(iOS 27.1, *)
extension ArrangementViewStyle where Self == SplitArrangementViewStyle { public static var split: SplitArrangementViewStyle { .init() } }
@available(iOS 27.1, *)
extension ArrangementViewStyle where Self == OverlayArrangementViewStyle { public static var overlay: OverlayArrangementViewStyle { .init() } }

struct _ArrangementStyleKey: EnvironmentKey { static var defaultValue: Any? { nil } }      // any ArrangementViewStyle
extension EnvironmentValues {
    var _arrangementStyle: Any? { get { self[_ArrangementStyleKey.self] } set { self[_ArrangementStyleKey.self] = newValue } }
}

/// Primary and secondary content arranged by the arrangement view style in the environment.
@available(iOS 27.1, *)
public struct ArrangementView<Primary: View, Secondary: View>: View, _PrimitiveView {
    let primary: AnyView, secondary: AnyView
    public init(@ViewBuilder primary: () -> Primary, @ViewBuilder secondary: () -> Secondary) {
        self.primary = AnyView(primary()); self.secondary = AnyView(secondary())
    }
    /// In a custom style: the arrangement view as the default style draws it.
    public init(_ configuration: ArrangementViewStyleConfiguration) where Primary == ArrangementViewStyleConfiguration.Primary, Secondary == ArrangementViewStyleConfiguration.Secondary {
        primary = AnyView(configuration.primary); secondary = AnyView(configuration.secondary)
    }
    public var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let cfg = ArrangementViewStyleConfiguration(primary: .init(content: primary), secondary: .init(content: secondary))
        let style = ctx.environment._arrangementStyle as? any ArrangementViewStyle ?? AutomaticArrangementViewStyle()
        let inner = ctx.child("arrangement").with { $0._arrangementStyle = nil }        // nested ones get the default
        return _resolve(_styled(style, cfg), inner)
    }
    @MainActor func _styled<S: ArrangementViewStyle>(_ s: S, _ c: ArrangementViewStyleConfiguration) -> AnyView { AnyView(s.makeBody(configuration: c)) }
}
extension View {
    /// The style of the arrangement views inside.
    @available(iOS 27.1, *)
    public func arrangementViewStyle(_ style: some ArrangementViewStyle) -> some View { _env { $0._arrangementStyle = style } }
    /// Split: the share of the arrangement this view prefers (nil: none).
    @available(iOS 27.1, *)
    public func splitArrangementLayoutRatio(_ ratio: CGFloat?) -> some View { _arrangementSize { $0.ratio = (ratio, ratio) } }
    /// Split: the shares this view prefers in a horizontal and in a vertical arrangement (ideal; clamped to min / max).
    @available(iOS 27.1, *)
    public func splitArrangementLayoutRatio(minHorizontal: CGFloat? = nil, idealHorizontal: CGFloat? = nil, maxHorizontal: CGFloat? = nil,
                                            minVertical: CGFloat? = nil, idealVertical: CGFloat? = nil, maxVertical: CGFloat? = nil) -> some View {
        _arrangementSize { $0.ratio = (idealHorizontal, idealVertical); $0.ratioRange = ((minHorizontal, maxHorizontal), (minVertical, maxVertical)) }
    }
    /// Split: this view's size (width for a horizontal arrangement, height for a vertical one).
    @available(iOS 27.1, *)
    public func splitArrangementLayoutSize(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil,
                                           minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil) -> some View {
        _arrangementSize { $0.size = ((minWidth, idealWidth, maxWidth), (minHeight, idealHeight, maxHeight)) }
    }
    /// Split: this view prefers its ideal size along the split.
    @available(iOS 27.1, *)
    public func splitArrangementFixedLayoutSize(horizontal: Bool = true, vertical: Bool = true) -> some View {
        _arrangementSize { $0.fixed = (horizontal, vertical) }
    }
    /// Overlay: the edge this view moves to when the arrangement turns side by side (when a device folds).
    @available(iOS 27.1, *)
    public func overlayArrangementEdge(_ edge: HorizontalEdge?) -> some View { _arrangementSize { $0.edge = edge } }
    func _arrangementSize(_ f: @escaping (inout _ArrangementSizing) -> Void) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("arrsize"))
            var s = n.arrangementSizing ?? _ArrangementSizing()
            f(&s)
            n.arrangementSizing = s
            return n
        }
    }
}
/// A view's sizing preferences in an arrangement.
struct _ArrangementSizing {
    var ratio: (h: CGFloat?, v: CGFloat?) = (nil, nil)
    var ratioRange: (h: (CGFloat?, CGFloat?), v: (CGFloat?, CGFloat?)) = ((nil, nil), (nil, nil))
    var size: (w: (CGFloat?, CGFloat?, CGFloat?), h: (CGFloat?, CGFloat?, CGFloat?)) = ((nil, nil, nil), (nil, nil, nil))
    var fixed: (h: Bool, v: Bool) = (false, false)
    var edge: HorizontalEdge? = nil
}

struct _ArrangementLayout: View, _PrimitiveView {
    let kind: Int, axes: Axis.Set, primary: AnyView, secondary: AnyView
    var body: Never { fatalError() }
    func _makeNode(_ ctx: _Context) -> _Node {
        let p = _resolve(primary, ctx.child("primary")), s = _resolve(secondary, ctx.child("secondary"))
        let n = _ArrangementNode(path: ctx.path, kind: kind, axes: axes, primary: p, secondary: s)
        n.compact = ctx.environment.horizontalSizeClass == .compact
        return n
    }
}
final class _ArrangementNode: _Node {
    let kind: Int, axes: Axis.Set
    var compact = true
    /// the axis of the last split layout (logged when it changes)
    var lastAxis: Axis?
    init(path: String, kind: Int, axes: Axis.Set, primary: _Node, secondary: _Node) {
        self.kind = kind; self.axes = axes
        // overlay: the secondary is mounted first, so the primary is on top
        super.init(path: path, children: kind == 1 ? [secondary, primary] : [primary, secondary])
    }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { CGSize(width: p.width ?? 320, height: p.height ?? 480) }
    static func sizing(_ n: _Node) -> _ArrangementSizing? {
        var x: _Node? = n
        while let c = x { if let s = c.arrangementSizing { return s }; x = c.children.count == 1 ? c.children[0] : nil }
        return nil
    }
    override func place(_ rect: CGRect) {
        frame = rect
        let all = CGRect(origin: .zero, size: rect.size)
        guard kind == 0 else { children.forEach { $0.place(all) }; return }   // overlay: both fill, the primary on top
        let p = children[0], s = children[1]
        // split: stacked in compact width in portrait, else side by side (within the allowed axes)
        let horizontal: Bool
        if axes == .horizontal { horizontal = true } else if axes == .vertical { horizontal = false }
        else { horizontal = !(compact && rect.height > rect.width) }
        let total = horizontal ? rect.width : rect.height
        func preferred(_ n: _Node) -> CGFloat? {
            guard let z = _ArrangementNode.sizing(n) else { return nil }
            var v: CGFloat?
            if let r = horizontal ? z.ratio.h : z.ratio.v { v = r * total }
            let (lo, ideal, hi) = horizontal ? z.size.w : z.size.h
            if let i = ideal { v = i }
            if (horizontal ? z.fixed.h : z.fixed.v) {
                let ideal = n.sizeThatFits(horizontal ? _Proposal(width: nil, height: rect.height) : _Proposal(width: rect.width, height: nil))
                v = horizontal ? ideal.width : ideal.height
            }
            let rr = horizontal ? z.ratioRange.h : z.ratioRange.v
            if var x = v {
                if let l = lo { x = max(x, l) }; if let h = hi { x = min(x, h) }
                if let l = rr.0 { x = max(x, l * total) }; if let h = rr.1 { x = min(x, h * total) }
                v = x
            }
            return v
        }
        // the view with the higher layout priority is sized first; the other takes what is left (the secondary on a tie)
        var a = preferred(p), b = preferred(s)
        let primaryFirst = p.layoutPriority >= s.layoutPriority
        if a == nil && b == nil { a = total / 2 }
        if primaryFirst { if let x = a { a = min(x, total); b = total - a! } else { b = min(b!, total); a = total - b! } }
        else { if let x = b { b = min(x, total); a = total - b! } else { a = min(a!, total); b = total - a! } }
        let pa = a!, pb = b!
        if horizontal {
            p.place(CGRect(x: 0, y: 0, width: pa, height: rect.height))
            s.place(CGRect(x: pa, y: 0, width: pb, height: rect.height))
        } else {
            p.place(CGRect(x: 0, y: 0, width: rect.width, height: pa))
            s.place(CGRect(x: 0, y: pa, width: rect.width, height: pb))
        }
        let axis: Axis = horizontal ? .horizontal : .vertical
        if axis != lastAxis { lastAxis = axis }
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
}
