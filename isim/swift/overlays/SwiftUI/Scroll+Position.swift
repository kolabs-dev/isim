// isim SwiftUI: ScrollView positions and phases — `ScrollPosition` with `scrollPosition(_:anchor:)`,
// `onScrollPhaseChange`, `defaultScrollAnchor` (`ScrollAnchorRole`), `scrollClipDisabled` and `scrollIndicatorsFlash`.
// They apply to the first ScrollView inside the modified view (options in `_ScrollOptions`, Scroll+Paging.swift); Lists
// have their own scroll view and do not take them.
// Phases come from the UIScrollView delegate: a drag goes idle → interacting (isim's UIScrollView has no separate
// tracking state before the drag starts), then decelerating or idle; animated programmatic scrolls are animating.
import UIKit

// MARK: - ScrollPosition

/// The availability-free state of a ScrollPosition (the scroll options and the delegate keep it).
struct _ScrollPositionState: Equatable {
    enum Kind: Equatable { case automatic, id(AnyHashable, UnitPoint?), edge(Edge), point(CGPoint), x(CGFloat), y(CGFloat), user }
    var kind = Kind.automatic
    /// the id type the position reports when the user scrolls past a view with an id of that type
    var idType: ObjectIdentifier
    var userID: AnyHashable?
    var byUser = false
}
struct _ScrollPositionBinding {
    let get: () -> _ScrollPositionState
    let set: (_ScrollPositionState) -> Void
    let anchor: UnitPoint?
}

/// The semantic position of a scroll view: a view's id, an edge, a point, or wherever the user scrolled it.
@available(iOS 18.0, *)
public struct ScrollPosition: Equatable, @unchecked Sendable {
    var _state: _ScrollPositionState
    init(_state: _ScrollPositionState) { self._state = _state }
    init(_ kind: _ScrollPositionState.Kind, _ idType: Any.Type) { _state = _ScrollPositionState(kind: kind, idType: ObjectIdentifier(idType)) }

    public init(idType: (some Hashable & Sendable).Type = Never.self) { self.init(.automatic, idType) }
    public init(id: some Hashable & Sendable, anchor: UnitPoint? = nil) { self.init(.id(AnyHashable(id), anchor), type(of: id)) }
    public init(idType: (some Hashable & Sendable).Type = Never.self, edge: Edge) { self.init(.edge(edge), idType) }
    public init(idType: (some Hashable & Sendable).Type = Never.self, point: CGPoint) { self.init(.point(point), idType) }
    public init(idType: (some Hashable & Sendable).Type = Never.self, x: CGFloat) { self.init(.x(x), idType) }
    public init(idType: (some Hashable & Sendable).Type = Never.self, y: CGFloat) { self.init(.y(y), idType) }
    public init(idType: (some Hashable & Sendable).Type = Never.self, x: CGFloat, y: CGFloat) { self.init(.point(CGPoint(x: x, y: y)), idType) }

    /// The edge the scroll view is positioned at, when positioned by edge.
    public var edge: Edge? { if case .edge(let e) = _state.kind { return e }; return nil }
    /// The point the scroll view is positioned at, when positioned by point.
    public var point: CGPoint? { if case .point(let p) = _state.kind { return p }; return nil }
    @available(iOS 26.0, *)
    public var x: CGFloat? {
        switch _state.kind { case .x(let x): return x; case .point(let p): return p.x; default: return nil }
    }
    @available(iOS 26.0, *)
    public var y: CGFloat? {
        switch _state.kind { case .y(let y): return y; case .point(let p): return p.y; default: return nil }
    }
    /// The id of the view positioned at, or of the first view (with an id of the position's id type) the user scrolled to.
    public var viewID: (any Hashable & Sendable)? {
        if case .id(let id, _) = _state.kind { return _sendableID(id) }
        return _state.userID.map(_sendableID)
    }
    public func viewID<T: Hashable & Sendable>(type: T.Type) -> T? { viewID as? T }
    /// Whether the user scrolled the scroll view since it was last positioned programmatically.
    public var isPositionedByUser: Bool {
        get { _state.byUser }
        set { _state.byUser = newValue }
    }

    public mutating func scrollTo(id: some Hashable & Sendable, anchor: UnitPoint? = nil) { set(.id(AnyHashable(id), anchor)) }
    public mutating func scrollTo(edge: Edge) { set(.edge(edge)) }
    public mutating func scrollTo(point: CGPoint) { set(.point(point)) }
    public mutating func scrollTo(x: CGFloat) { set(.x(x)) }
    public mutating func scrollTo(y: CGFloat) { set(.y(y)) }
    public mutating func scrollTo(x: CGFloat, y: CGFloat) { set(.point(CGPoint(x: x, y: y))) }
    private mutating func set(_ k: _ScrollPositionState.Kind) { _state.kind = k; _state.userID = nil; _state.byUser = false }
}

/// The id's value as Apple's `any Hashable & Sendable`: ids come from the app's own `Hashable & Sendable` ids (or a
/// ForEach's), and Sendable is a marker protocol, so both existentials have the same layout.
func _sendableID(_ id: AnyHashable) -> any Hashable & Sendable { unsafeBitCast(id.base as! any Hashable, to: (any Hashable & Sendable).self) }

/// Scrolls `v` to the position of the binding when it changed since it was last applied or reported.
@MainActor func _applyScrollPosition(_ sp: _ScrollPositionBinding, _ b: _ScrollBehavior, _ v: UIScrollView, _ g: _Graph) {
    let st = sp.get()
    guard st != b.appliedPosition else { return }
    b.appliedPosition = st
    guard !st.byUser else { return }
    let targets = b.targets, anchor = sp.anchor
    g.postRender.append { [weak v, weak g] in
        guard let v else { return }
        let maxX = max(0, v.contentSize.width - v.bounds.width), maxY = max(0, v.contentSize.height - v.bounds.height)
        var off = v.contentOffset
        switch st.kind {
        case .automatic, .user: return
        case .edge(let e):
            switch e {
            case .top: off.y = 0
            case .bottom: off.y = maxY
            case .leading: off.x = 0
            case .trailing: off.x = maxX
            }
        case .point(let p): off = p
        case .x(let x): off.x = x
        case .y(let y): off.y = y
        case .id(let id, let a):
            var r = targets.first(where: { $0.1 == id })?.0
            if r == nil, let iv = g?.idViews["\(id.base)"] { r = iv.convert(iv.bounds, to: v) }
            guard let r else { NSLog("isim SwiftUI: ScrollPosition: no view with id %@", "\(id.base)"); return }
            let a = a ?? anchor ?? UnitPoint(x: 0, y: 0)
            if v.contentSize.height > v.bounds.height { off.y = r.minY + r.height * a.y - v.bounds.height * a.y }
            if v.contentSize.width > v.bounds.width { off.x = r.minX + r.width * a.x - v.bounds.width * a.x }
        }
        v.contentOffset = CGPoint(x: min(maxX, max(0, off.x)), y: min(maxY, max(0, off.y)))
    }
}
extension _ScrollBehavior {
    /// After a user scroll: the position becomes "positioned by the user", with the id of the first target (of the
    /// position's id type) at the top / leading edge.
    func reportScrollPosition(_ s: UIScrollView) {
        guard let sp = scrollPosition else { return }
        var st = sp.get()
        let off = horizontal ? s.contentOffset.x : s.contentOffset.y
        let id = targets.first(where: { (horizontal ? $0.0.maxX : $0.0.maxY) > off + 1 })?.1
        st.kind = .user
        st.userID = id.flatMap { ObjectIdentifier(type(of: $0.base)) == st.idType ? $0 : nil }
        st.byUser = true
        appliedPosition = st
        sp.set(st)
    }
}

// MARK: - Scroll phases

enum _ScrollPhaseCode { static let idle = 0, tracking = 1, interacting = 2, decelerating = 3, animating = 4 }

/// What a scroll view is doing: nothing, following the user's finger, decelerating, or animating.
@available(iOS 18.0, *)
@frozen public enum ScrollPhase: Equatable, Hashable, Sendable, CustomDebugStringConvertible {
    case idle, tracking, interacting, decelerating, animating
    /// Whether the scroll view is scrolling (every phase but idle).
    public var isScrolling: Bool { self != .idle }
    public var debugDescription: String {
        switch self {
        case .idle: return "idle"
        case .tracking: return "tracking"
        case .interacting: return "interacting"
        case .decelerating: return "decelerating"
        case .animating: return "animating"
        }
    }
    init(_code: Int) { self = [.idle, .tracking, .interacting, .decelerating, .animating][_code] }
}
/// The scroll view's geometry and velocity when its phase changes.
@available(iOS 18.0, *)
public struct ScrollPhaseChangeContext {
    public var geometry: ScrollGeometry { _geometry }
    public var velocity: CGVector? { _velocity }
    let _geometry: ScrollGeometry, _velocity: CGVector?
}

/// What a default scroll anchor applies to.
@available(iOS 18.0, *)
public struct ScrollAnchorRole: Equatable, Hashable, Sendable {
    let id: Int
    /// where the scroll view starts
    public static var initialOffset: ScrollAnchorRole { .init(id: 0) }
    /// which part stays in place when the content size changes
    public static var sizeChanges: ScrollAnchorRole { .init(id: 1) }
    /// where content smaller than the scroll view sits
    public static var alignment: ScrollAnchorRole { .init(id: 2) }
}

// MARK: - Default anchor, indicator flashes

/// defaultScrollAnchor (initial offset, size changes) and scrollIndicatorsFlash, when the scroll view mounts.
@MainActor func _applyScrollAnchorAndFlash(_ n: _ScrollNode, _ v: _SUIScrollView, _ g: _Graph) {
    let o = n.options
    let size = n.contentSize
    func offset(_ a: UnitPoint, _ v: UIScrollView) -> CGPoint {
        CGPoint(x: max(0, v.contentSize.width - v.bounds.width) * a.x, y: max(0, v.contentSize.height - v.bounds.height) * a.y)
    }
    if size != .zero {
        let old = v.anchoredSize
        v.anchoredSize = size
        if old == nil, let a = o.anchor.initial {
            g.postRender.append { [weak v] in if let v { v.contentOffset = offset(a, v) } }
        } else if let old, old != size, let a = o.anchor.sizeChanges {
            g.postRender.append { [weak v] in
                guard let v else { return }
                let maxX = max(0, v.contentSize.width - v.bounds.width), maxY = max(0, v.contentSize.height - v.bounds.height)
                let x = v.contentOffset.x + (size.width - old.width) * a.x, y = v.contentOffset.y + (size.height - old.height) * a.y
                v.contentOffset = CGPoint(x: min(maxX, max(0, x)), y: min(maxY, max(0, y)))
            }
        }
    }
    var flash = false
    if let f = o.flashTrigger {
        if let old = v.flashValue, !f.equals(old) { flash = true }
        v.flashValue = f.value
    }
    if o.flashOnAppear, !v.flashedOnAppear { v.flashedOnAppear = true; flash = true }
    if flash { g.postRender.append { [weak v] in v?.flashScrollIndicators(); NSLog("isim SwiftUI: flashed scroll indicators") } }
}

// MARK: - Modifiers

extension View {
    /// Binds the position of the first ScrollView inside: setting it scrolls there; a user scroll writes back where.
    @available(iOS 18.0, *)
    public func scrollPosition(_ position: Binding<ScrollPosition>, anchor: UnitPoint? = nil) -> some View {
        _env { o in
            o._scrollOptions.scrollPosition = _ScrollPositionBinding(get: { position.wrappedValue._state },
                                                                     set: { position.wrappedValue = ScrollPosition(_state: $0) }, anchor: anchor)
        }
    }
    /// Calls `action` with the old and new phase when the first ScrollView inside starts or stops scrolling.
    @available(iOS 18.0, *)
    public func onScrollPhaseChange(_ action: @escaping (_ oldPhase: ScrollPhase, _ newPhase: ScrollPhase) -> Void) -> some View {
        onScrollPhaseChange { old, new, _ in action(old, new) }
    }
    /// Calls `action` with the old and new phase, and the geometry and velocity, when the first ScrollView inside
    /// starts or stops scrolling.
    @available(iOS 18.0, *)
    public func onScrollPhaseChange(_ action: @escaping (_ oldPhase: ScrollPhase, _ newPhase: ScrollPhase, _ context: ScrollPhaseChangeContext) -> Void) -> some View {
        _env { o in
            o._scrollOptions.phase = { old, new, s, velocity in
                action(ScrollPhase(_code: old), ScrollPhase(_code: new), ScrollPhaseChangeContext(_geometry: _scrollGeometry(s), _velocity: velocity))
            }
        }
    }
    /// Where the scroll view starts, which part stays put when its content grows, and where small content sits.
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View {
        _env { $0._scrollOptions.anchor = (anchor, anchor, anchor) }
    }
    @available(iOS 18.0, *)
    public func defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole) -> some View {
        _env { o in
            switch role.id {
            case 0: o._scrollOptions.anchor.initial = anchor
            case 1: o._scrollOptions.anchor.sizeChanges = anchor
            default: o._scrollOptions.anchor.alignment = anchor
            }
        }
    }
    /// Lets the content of scroll views inside draw (and take touches) outside their bounds.
    public func scrollClipDisabled(_ disabled: Bool = true) -> some View { _env { $0._scrollOptions.clipDisabled = disabled } }
    /// Flashes the scroll indicators when `value` changes.
    public func scrollIndicatorsFlash(trigger value: some Equatable) -> some View {
        func equals<V: Equatable>(_ v: V) -> (Any) -> Bool { { ($0 as? V) == v } }
        return _env { o in o._scrollOptions.flashTrigger = (value, equals(value)) }
    }
    /// Flashes the scroll indicators when the scroll view appears.
    public func scrollIndicatorsFlash(onAppear: Bool) -> some View { _env { $0._scrollOptions.flashOnAppear = onAppear } }
}
