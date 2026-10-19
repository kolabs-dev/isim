// isim SwiftUI: ScrollView behaviours — `scrollTargetBehavior(.paging / .viewAligned / custom)` with
// `scrollTargetLayout()`, `scrollPosition(id:)` (reports the top/leading item, scrolls when the binding changes),
// `scrollDisabled`, `scrollIndicators`, `scrollBounceBehavior`, `scrollDismissesKeyboard` and `contentMargins`
// (CustomLayout.swift); ScrollPosition, scroll phases, default anchors, clipping and indicator flashes: Scroll+Position.swift.
// Paging uses UIScrollView.isPagingEnabled; view alignment snaps the drag's target offset to a child's edge.
import UIKit

struct _ScrollOptions {
    var disabled = false
    var indicators: Bool? = nil
    var bounceBasedOnSize = false
    var paging = false
    var viewAligned = false
    var custom: ((inout ScrollTarget, ScrollTargetBehaviorContext) -> Void)? = nil
    var position: (get: () -> AnyHashable?, set: (AnyHashable?) -> Void)? = nil
    var refresh: RefreshAction? = nil
    /// scrollDismissesKeyboard: 0 automatic, 1 immediately, 2 interactively, 3 never
    var keyboard = 0
    /// scrollPosition(_: Binding<ScrollPosition>, anchor:) (Scroll+Position.swift)
    var scrollPosition: _ScrollPositionBinding? = nil
    /// onScrollPhaseChange: (old phase, new phase, the scroll view, the release velocity), phases as ScrollPhase._code
    var phase: ((Int, Int, UIScrollView, CGVector?) -> Void)? = nil
    /// defaultScrollAnchor, per ScrollAnchorRole
    var anchor: (initial: UnitPoint?, sizeChanges: UnitPoint?, alignment: UnitPoint?) = (nil, nil, nil)
    var clipDisabled = false
    /// scrollIndicatorsFlash(trigger:) (the value and an equality test against a former value), (onAppear:)
    var flashTrigger: (value: Any, equals: (Any) -> Bool)? = nil
    var flashOnAppear = false
}
/// The UIKit keyboard dismiss mode of a scroll view (`editor`: a TextEditor's text view, interactive by default).
func _keyboardDismissMode(_ mode: Int, editor: Bool = false) -> UIScrollView.KeyboardDismissMode {
    switch mode {
    case 1: return .onDrag
    case 2: return .interactive
    case 3: return .none
    default: return editor ? .interactive : .onDrag
    }
}
struct _ScrollOptionsKey: EnvironmentKey { static var defaultValue: _ScrollOptions { _ScrollOptions() } }
extension EnvironmentValues { var _scrollOptions: _ScrollOptions { get { self[_ScrollOptionsKey.self] } set { self[_ScrollOptionsKey.self] = newValue } } }

@MainActor func _makeScrollNode(axes: Axis.Set, indicators: Bool, _ ctx: _Context, content: (_Context) -> _Node) -> _Node {
    let env = ctx.environment
    let margins = env._contentMargins
    // the options that apply to the first scroll view only
    var child = content(ctx.child("scroll").with {
        $0._contentMargins = nil; $0._indicatorMargins = nil; $0._scrollOptions.position = nil; $0._scrollOptions.scrollPosition = nil
        $0._scrollOptions.phase = nil; $0._scrollOptions.flashTrigger = nil; $0._scrollOptions.flashOnAppear = false
    })
    if let m = margins { child = _PaddingNode(path: ctx.path + "/margins", insets: m, child: child) }
    let n = _ScrollNode(path: ctx.path, axes: axes, indicators: indicators && env._scrollOptions.indicators != false, child: child)
    n.indicatorMargins = env._indicatorMargins.map { UIEdgeInsets(top: $0.top, left: $0.leading, bottom: $0.bottom, right: $0.trailing) } ?? .zero
    n.options = env._scrollOptions
    n.options.refresh = env.refresh            // .refreshable (Lists+Editing.swift)
    return n
}

/// The scroll targets: the children of the `.scrollTargetLayout()` container (or the content's own children), in
/// content coordinates, with their ids.
final class _ScrollTargetLayoutNode: _WrapperNode {
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
}
@MainActor func _scrollTargets(_ root: _Node) -> [(CGRect, AnyHashable?)] {
    // a node's children are placed relative to it, except for transparent groups (relative to the group's parent)
    func childBase(_ n: _Node, _ base: CGPoint) -> CGPoint { n.transparent ? base : CGPoint(x: base.x + n.frame.minX, y: base.y + n.frame.minY) }
    func find(_ n: _Node, _ base: CGPoint) -> (_Node, CGPoint)? {
        let cb = childBase(n, base)
        if n is _ScrollTargetLayoutNode { return (n, cb) }
        for c in n.children { if let f = find(c, cb) { return f } }
        return nil
    }
    var (node, base) = find(root, .zero) ?? (root, childBase(root, .zero))
    // down through single-child wrappers to the stack whose children are the targets
    while _flatten(node.children).count == 1, let only = _flatten(node.children).first { base = childBase(only, base); node = only }
    return _flatten(node.children).map { c in (c.frame.offsetBy(dx: base.x, dy: base.y), _tagged(c) ?? (c as? _IDNode).map { AnyHashable($0.idTag) }) }
}

@MainActor func _applyScrollOptions(_ n: _ScrollNode, _ v: _SUIScrollView, _ g: _Graph) {
    let o = n.options
    v.isScrollEnabled = !o.disabled
    v.keyboardDismissMode = _keyboardDismissMode(o.keyboard)
    if o.bounceBasedOnSize {
        v.alwaysBounceVertical = n.axes.contains(.vertical) && n.contentSize.height > n.frame.height
        v.alwaysBounceHorizontal = n.axes.contains(.horizontal) && n.contentSize.width > n.frame.width
    }
    v.isPagingEnabled = o.paging
    v.clipsToBounds = !o.clipDisabled
    _applyScrollAnchorAndFlash(n, v, g)
    guard o.viewAligned || o.position != nil || o.custom != nil || o.refresh != nil || o.scrollPosition != nil || o.phase != nil
    else { v.behavior = nil; v.delegate = nil; return }
    let b = v.behavior ?? _ScrollBehavior()
    v.behavior = b; v.delegate = b
    if o.refresh != nil || b.refresher != nil { let rd = b.refresher ?? _RefreshDriver(); b.refresher = rd; rd.attach(v, o.refresh) }
    // targets are measured relative to the scroll view's content (its child is at the origin)
    b.targets = _scrollTargets(n.child)
    b.horizontal = n.axes.contains(.horizontal) && !n.axes.contains(.vertical)
    b.snap = o.viewAligned
    b.custom = o.custom
    b.position = o.position
    if let pos = o.position, let want = pos.get(), want != b.reported, let t = b.targets.first(where: { $0.1 == want }) {
        b.reported = want
        let target = b.clamp(b.horizontal ? CGPoint(x: t.0.minX, y: v.contentOffset.y) : CGPoint(x: v.contentOffset.x, y: t.0.minY), v)
        g.postRender.append { [weak v] in v?.contentOffset = target }
    }
    b.phaseAction = o.phase
    b.scrollPosition = o.scrollPosition
    if let sp = o.scrollPosition { _applyScrollPosition(sp, b, v, g) }
}

/// Delegate of a SwiftUI scroll view with targets: snapping and position reporting.
final class _ScrollBehavior: NSObject, UIScrollViewDelegate {
    var targets: [(CGRect, AnyHashable?)] = []
    var horizontal = false, snap = false
    var custom: ((inout ScrollTarget, ScrollTargetBehaviorContext) -> Void)?
    var position: (get: () -> AnyHashable?, set: (AnyHashable?) -> Void)?
    var reported: AnyHashable?
    var refresher: _RefreshDriver?
    /// onScrollPhaseChange (Scroll+Position.swift): the current phase, the release velocity (points per second)
    var phaseAction: ((Int, Int, UIScrollView, CGVector?) -> Void)?
    var phase = _ScrollPhaseCode.idle
    var velocity: CGVector?
    /// scrollPosition(_: Binding<ScrollPosition>): the position last applied or reported
    var scrollPosition: _ScrollPositionBinding?
    var appliedPosition: _ScrollPositionState?
    func scrollViewDidScroll(_ s: UIScrollView) {
        refresher?.scrolled(s)
        if #available(iOS 17.4, *), phase == _ScrollPhaseCode.idle, !s.isDragging, s.isScrollAnimating { setPhase(_ScrollPhaseCode.animating, s) }
    }
    func scrollViewWillBeginDragging(_ s: UIScrollView) { velocity = nil; setPhase(_ScrollPhaseCode.interacting, s) }
    func clamp(_ p: CGPoint, _ s: UIScrollView) -> CGPoint {
        CGPoint(x: min(max(0, p.x), max(0, s.contentSize.width - s.bounds.width)), y: min(max(0, p.y), max(0, s.contentSize.height - s.bounds.height)))
    }
    func scrollViewWillEndDragging(_ s: UIScrollView, withVelocity velocity: CGPoint, targetContentOffset t: UnsafeMutablePointer<CGPoint>) {
        self.velocity = CGVector(dx: velocity.x * 1000, dy: velocity.y * 1000)     // (UIKit's is in points per millisecond)
        if let custom {
            var target = ScrollTarget(rect: CGRect(origin: t.pointee, size: s.bounds.size))
            let ctx = ScrollTargetBehaviorContext(originalTarget: target, velocity: CGVector(dx: velocity.x, dy: velocity.y), contentSize: s.contentSize,
                                                  containerSize: s.bounds.size, axes: horizontal ? .horizontal : .vertical)
            custom(&target, ctx)
            t.pointee = clamp(target.rect.origin, s)
            return
        }
        guard snap, !targets.isEmpty else { return }
        // the child edge nearest the natural target; a flick moves at least one child
        let cur = horizontal ? s.contentOffset.x : s.contentOffset.y
        let want = horizontal ? t.pointee.x : t.pointee.y
        let v = horizontal ? velocity.x : velocity.y
        let edges = targets.map { horizontal ? $0.0.minX : $0.0.minY }
        var best = edges.min { abs($0 - want) < abs($1 - want) } ?? want
        if v > 0.2, best <= cur + 0.5, let next = edges.first(where: { $0 > cur + 0.5 }) { best = next }
        if v < -0.2, best >= cur - 0.5, let prev = edges.last(where: { $0 < cur - 0.5 }) { best = prev }
        t.pointee = clamp(horizontal ? CGPoint(x: best, y: t.pointee.y) : CGPoint(x: t.pointee.x, y: best), s)
    }
    func scrollViewDidEndDragging(_ s: UIScrollView, willDecelerate d: Bool) {
        refresher?.endDragging(s)
        setPhase(d ? _ScrollPhaseCode.decelerating : _ScrollPhaseCode.idle, s)
        if !d { report(s); reportScrollPosition(s) }
    }
    func scrollViewDidEndDecelerating(_ s: UIScrollView) { setPhase(_ScrollPhaseCode.idle, s); report(s); reportScrollPosition(s) }
    func scrollViewDidEndScrollingAnimation(_ s: UIScrollView) { setPhase(_ScrollPhaseCode.idle, s); report(s) }
    func setPhase(_ p: Int, _ s: UIScrollView) {
        guard p != phase else { return }
        let old = phase
        phase = p
        phaseAction?(old, p, s, p == _ScrollPhaseCode.interacting ? nil : velocity)
    }
    /// scrollPosition(id:) gets the first target whose frame reaches past the top/leading edge.
    func report(_ s: UIScrollView) {
        guard let position else { return }
        let off = horizontal ? s.contentOffset.x : s.contentOffset.y
        guard let t = targets.first(where: { (horizontal ? $0.0.maxX : $0.0.maxY) > off + 1 }), let id = t.1 else { return }
        if id != reported { reported = id; position.set(id) }
    }
}

// MARK: - Public API

public struct ScrollTarget {
    public var rect: CGRect
    public var anchor: UnitPoint?
    public init(rect: CGRect, anchor: UnitPoint? = nil) { self.rect = rect; self.anchor = anchor }
}
public struct ScrollTargetBehaviorContext {
    public var originalTarget: ScrollTarget
    public var velocity: CGVector
    public var contentSize: CGSize
    public var containerSize: CGSize
    public var axes: Axis.Set
}
public protocol ScrollTargetBehavior {
    typealias TargetContext = ScrollTargetBehaviorContext
    func updateTarget(_ target: inout ScrollTarget, context: TargetContext)
}
public struct PagingScrollTargetBehavior: ScrollTargetBehavior {
    public init() {}
    public func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {}
}
public struct ViewAlignedScrollTargetBehavior: ScrollTargetBehavior {
    public struct LimitBehavior: Sendable { let id: Int; public static let automatic = LimitBehavior(id: 0), always = LimitBehavior(id: 1), never = LimitBehavior(id: 2) }
    public init(limitBehavior: LimitBehavior = .automatic) {}
    public func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {}
}
extension ScrollTargetBehavior where Self == PagingScrollTargetBehavior { public static var paging: PagingScrollTargetBehavior { .init() } }
extension ScrollTargetBehavior where Self == ViewAlignedScrollTargetBehavior {
    public static var viewAligned: ViewAlignedScrollTargetBehavior { .init() }
    public static func viewAligned(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior) -> ViewAlignedScrollTargetBehavior { .init(limitBehavior: limitBehavior) }
}

extension View {
    public func scrollTargetBehavior<B: ScrollTargetBehavior>(_ behavior: B) -> some View {
        _env { o in
            o._scrollOptions.paging = behavior is PagingScrollTargetBehavior
            o._scrollOptions.viewAligned = behavior is ViewAlignedScrollTargetBehavior
            o._scrollOptions.custom = (behavior is PagingScrollTargetBehavior || behavior is ViewAlignedScrollTargetBehavior) ? nil : { behavior.updateTarget(&$0, context: $1) }
        }
    }
    /// Marks the layout whose children are the scroll targets (view-aligned snapping, scrollPosition).
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View {
        _modify { ctx, c in
            let n = _resolve(c, ctx.child("stl"))
            return isEnabled ? _ScrollTargetLayoutNode(path: ctx.path, child: n) : n
        }
    }
    /// The id of the first visible child of the target layout; setting it scrolls there.
    public func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View {
        _env { o in o._scrollOptions.position = (get: { id.wrappedValue.map { AnyHashable($0) } }, set: { v in id.wrappedValue = v?.base as? ID }) }
    }
    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View {
        _env { $0._scrollOptions.indicators = visibility.id == 2 || visibility.id == 3 ? false : nil }
    }
    public func scrollDisabled(_ disabled: Bool) -> some View { _env { $0._scrollOptions.disabled = disabled } }
    // scrollPosition(_:anchor:), onScrollPhaseChange, defaultScrollAnchor, scrollClipDisabled, scrollIndicatorsFlash:
    // Scroll+Position.swift
    public func scrollBounceBehavior(_ behavior: ScrollBounceBehavior, axes: Axis.Set = [.vertical]) -> some View {
        _env { $0._scrollOptions.bounceBasedOnSize = behavior.id == 2 }
    }
}
