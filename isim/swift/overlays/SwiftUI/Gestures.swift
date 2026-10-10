// isim SwiftUI: gestures on top of UIKit gesture recognizers attached to the view a `.gesture` wraps.
// TapGesture, SpatialTapGesture, LongPressGesture, DragGesture, MagnifyGesture (+ MagnificationGesture),
// RotateGesture (+ RotationGesture) — the two-finger ones get their second finger from isim's multi-touch (Option-drag
// on the host, script `pinch` / `rotate2`); onChanged / onEnded / updating(@GestureState) / map; composition with
// simultaneously(with:), sequenced(before:) and exclusively(before:). Recognizers recognize together (like
// .simultaneousGesture); highPriorityGesture is treated like gesture.
import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Callbacks a gesture reports to whoever installed it.
public final class _GestureEvents<Value> {
    var changed: (Value) -> Void = { _ in }
    var ended: (Value) -> Void = { _ in }
    var cancelled: () -> Void = {}
    public init() {}
    init(changed: @escaping (Value) -> Void, ended: @escaping (Value) -> Void, cancelled: @escaping () -> Void) {
        self.changed = changed; self.ended = ended; self.cancelled = cancelled
    }
}

public protocol Gesture<Value> {
    associatedtype Value
    /// adds the recognizers for this gesture to `view`, reporting through `events`; returns them
    @MainActor func _install(on view: UIView, _ events: _GestureEvents<Value>) -> [UIGestureRecognizer]
    /// isim 0.2.0 ABI (unused): kept so binaries built against 0.2.0 still link
    var _isimGesture: _GestureSpec { get }
}
/// isim 0.2.0 ABI: the old gesture description type (unused; gestures install recognizers through `_install`)
public struct _GestureSpec { public init() {} }
extension Gesture { public var _isimGesture: _GestureSpec { _GestureSpec() } }

/// Target object for recognizer actions.
final class _SUIGestureTarget: NSObject {
    let action: (UIGestureRecognizer) -> Void
    init(_ action: @escaping (UIGestureRecognizer) -> Void) { self.action = action }
    @objc func fired(_ g: UIGestureRecognizer) { action(g) }
}
nonisolated(unsafe) private var kTargets: UInt8 = 0
@MainActor func _addRecognizer(_ g: UIGestureRecognizer, to v: UIView, _ action: @escaping (UIGestureRecognizer) -> Void) {
    let t = _SUIGestureTarget(action)
    g.addTarget(t, action: #selector(_SUIGestureTarget.fired(_:)))
    g.cancelsTouchesInView = false
    var targets = objc_getAssociatedObject(g, &kTargets) as? [_SUIGestureTarget] ?? []
    targets.append(t)
    objc_setAssociatedObject(g, &kTargets, targets, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC))
    v.addGestureRecognizer(g)
}

// MARK: - Drag
/// A touch that moves at least `minimumDistance` (0: from touch down); location relative to the gesture's view.
final class _SUIDragRecognizer: UIGestureRecognizer {
    var minimumDistance: CGFloat = 10
    var start: CGPoint = .zero, startTime = Date(), samples: [(CGPoint, TimeInterval)] = [], current: CGPoint = .zero
    var tracked: UITouch?
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        guard tracked == nil, let t = touches.first else { return }
        tracked = t; start = t.location(in: view); current = start; startTime = Date(); samples = [(start, t.timestamp)]
        if minimumDistance <= 0 { state = .began }
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = tracked, touches.contains(t) else { return }
        current = t.location(in: view)
        samples.append((current, t.timestamp)); if samples.count > 5 { samples.removeFirst() }
        if state == .possible { if hypot(current.x - start.x, current.y - start.y) >= minimumDistance { state = .began } }
        else if state == .began || state == .changed { state = .changed }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard let t = tracked, touches.contains(t) else { return }
        current = t.location(in: view)
        state = (state == .began || state == .changed) ? .ended : .failed
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) { state = (state == .began || state == .changed) ? .cancelled : .failed }
    override func reset() { tracked = nil; samples = [] }
    var value: DragGesture.Value {
        var v = CGSize.zero
        if let a = samples.first, let b = samples.last, b.1 - a.1 > 0.005 { v = CGSize(width: (b.0.x - a.0.x) / (b.1 - a.1), height: (b.0.y - a.0.y) / (b.1 - a.1)) }
        return DragGesture.Value(time: Date(), location: current, startLocation: start, velocity: v)
    }
}
public struct DragGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date
        public var location: CGPoint
        public var startLocation: CGPoint
        public var translation: CGSize { CGSize(width: location.x - startLocation.x, height: location.y - startLocation.y) }
        public var velocity: CGSize
        public var predictedEndLocation: CGPoint { CGPoint(x: location.x + velocity.width * 0.25, y: location.y + velocity.height * 0.25) }
        public var predictedEndTranslation: CGSize { CGSize(width: predictedEndLocation.x - startLocation.x, height: predictedEndLocation.y - startLocation.y) }
    }
    public var minimumDistance: CGFloat
    public var coordinateSpace: CoordinateSpace
    public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) { self.minimumDistance = minimumDistance; self.coordinateSpace = coordinateSpace }
    // isim 0.2.0 ABI: onChanged/onEnded returned DragGesture itself, carrying the actions
    var _abiChanged: ((Value) -> Void)?, _abiEnded: ((Value) -> Void)?
    public var _isimGesture: _GestureSpec { _GestureSpec() }
    @_disfavoredOverload @usableFromInline func onChanged(_ action: @escaping (Value) -> Void) -> DragGesture {
        var g = self; let prev = g._abiChanged; g._abiChanged = { prev?($0); action($0) }; return g
    }
    @_disfavoredOverload @usableFromInline func onEnded(_ action: @escaping (Value) -> Void) -> DragGesture {
        var g = self; let prev = g._abiEnded; g._abiEnded = { prev?($0); action($0) }; return g
    }
    public func _install(on view: UIView, _ e0: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let c = _abiChanged, en = _abiEnded
        let e = (c == nil && en == nil) ? e0 : _GestureEvents(changed: { c?($0); e0.changed($0) }, ended: { en?($0); e0.ended($0) }, cancelled: e0.cancelled)
        let g = _SUIDragRecognizer(target: nil, action: nil)
        g.minimumDistance = minimumDistance
        let space = coordinateSpace
        _addRecognizer(g, to: view) { r in
            let d = r as! _SUIDragRecognizer
            var v = d.value
            if space != .local, let dv = d.view {             // .global, .named, .scrollView (Geometry+Spaces.swift)
                v.location = _livePoint(v.location, in: dv, space); v.startLocation = _livePoint(v.startLocation, in: dv, space)
            }
            switch r.state {
            case .began, .changed: e.changed(v)
            case .ended: e.ended(v)
            case .cancelled: e.cancelled()
            default: break
            }
        }
        return [g]
    }
}

// MARK: - Taps and long press
public struct TapGesture: Gesture {
    public typealias Value = Void
    public var count: Int
    public init(count: Int = 1) { self.count = count }
    // isim 0.2.0 ABI: onEnded returned TapGesture itself, carrying the action
    var _abiEnded: (() -> Void)?
    public var _isimGesture: _GestureSpec { _GestureSpec() }
    @_disfavoredOverload @usableFromInline func onEnded(_ action: @escaping () -> Void) -> TapGesture {
        var g = self; let prev = g._abiEnded; g._abiEnded = { prev?(); action() }; return g
    }
    public func _install(on view: UIView, _ e: _GestureEvents<Void>) -> [UIGestureRecognizer] {
        let g = UITapGestureRecognizer(target: nil, action: nil)
        g.numberOfTapsRequired = max(1, count)
        let en = _abiEnded
        _addRecognizer(g, to: view) { r in if r.state == .ended { en?(); e.ended(()) } }
        return [g]
    }
}
public struct SpatialTapGesture: Gesture {
    public struct Value: Equatable, Sendable { public var location: CGPoint }
    public var count: Int
    public var coordinateSpace: CoordinateSpace
    public init(count: Int = 1, coordinateSpace: CoordinateSpace = .local) { self.count = count; self.coordinateSpace = coordinateSpace }
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let g = UITapGestureRecognizer(target: nil, action: nil)
        g.numberOfTapsRequired = max(1, count)
        let space = coordinateSpace
        _addRecognizer(g, to: view) { r in
            guard r.state == .ended, let v = r.view else { return }
            e.ended(Value(location: _livePoint(r.location(in: v), in: v, space)))
        }
        return [g]
    }
}
public struct LongPressGesture: Gesture {
    public typealias Value = Bool
    public var minimumDuration: Double
    public var maximumDistance: CGFloat
    public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) { self.minimumDuration = minimumDuration; self.maximumDistance = maximumDistance }
    // isim 0.2.0 ABI: onEnded returned LongPressGesture itself, carrying the action
    var _abiEnded: ((Bool) -> Void)?
    public var _isimGesture: _GestureSpec { _GestureSpec() }
    @_disfavoredOverload @usableFromInline func onEnded(_ action: @escaping (Bool) -> Void) -> LongPressGesture {
        var g = self; let prev = g._abiEnded; g._abiEnded = { prev?($0); action($0) }; return g
    }
    public func _install(on view: UIView, _ e: _GestureEvents<Bool>) -> [UIGestureRecognizer] {
        let g = UILongPressGestureRecognizer(target: nil, action: nil)
        g.minimumPressDuration = minimumDuration; g.allowableMovement = maximumDistance
        let en = _abiEnded
        _addRecognizer(g, to: view) { r in
            switch r.state {
            case .began: e.changed(true); en?(true); e.ended(true)          // a long press ends (succeeds) when held long enough
            case .cancelled: e.cancelled()
            default: break
            }
        }
        return [g]
    }
}

// MARK: - Two fingers
public struct MagnifyGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date
        public var magnification: CGFloat
        public var velocity: CGFloat
        public var startAnchor: UnitPoint
        public var startLocation: CGPoint
    }
    public var minimumScaleDelta: CGFloat
    public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let g = UIPinchGestureRecognizer(target: nil, action: nil)
        var start = CGPoint.zero
        _addRecognizer(g, to: view) { r in
            let p = r as! UIPinchGestureRecognizer
            guard let v = p.view else { return }
            if p.state == .began { start = p.location(in: v) }
            let b = v.bounds.size
            let value = Value(time: Date(), magnification: p.scale, velocity: p.velocity,
                              startAnchor: UnitPoint(x: b.width > 0 ? start.x / b.width : 0.5, y: b.height > 0 ? start.y / b.height : 0.5), startLocation: start)
            switch p.state {
            case .began, .changed: e.changed(value)
            case .ended: e.ended(value)
            case .cancelled: e.cancelled()
            default: break
            }
        }
        return [g]
    }
}
/// iOS 13–16 name: the value is the magnification
public struct MagnificationGesture: Gesture {
    public typealias Value = CGFloat
    public var minimumScaleDelta: CGFloat
    public init(minimumScaleDelta: CGFloat = 0.01) { self.minimumScaleDelta = minimumScaleDelta }
    public func _install(on view: UIView, _ e: _GestureEvents<CGFloat>) -> [UIGestureRecognizer] {
        MagnifyGesture(minimumScaleDelta: minimumScaleDelta)._install(on: view, _GestureEvents(changed: { e.changed($0.magnification) }, ended: { e.ended($0.magnification) }, cancelled: e.cancelled))
    }
}
public struct RotateGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date
        public var rotation: Angle
        public var velocity: Angle
        public var startAnchor: UnitPoint
        public var startLocation: CGPoint
    }
    public var minimumAngleDelta: Angle
    public init(minimumAngleDelta: Angle = .degrees(1)) { self.minimumAngleDelta = minimumAngleDelta }
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let g = UIRotationGestureRecognizer(target: nil, action: nil)
        var start = CGPoint.zero
        _addRecognizer(g, to: view) { r in
            let p = r as! UIRotationGestureRecognizer
            guard let v = p.view else { return }
            if p.state == .began { start = p.location(in: v) }
            let b = v.bounds.size
            let value = Value(time: Date(), rotation: .radians(p.rotation), velocity: .radians(p.velocity),
                              startAnchor: UnitPoint(x: b.width > 0 ? start.x / b.width : 0.5, y: b.height > 0 ? start.y / b.height : 0.5), startLocation: start)
            switch p.state {
            case .began, .changed: e.changed(value)
            case .ended: e.ended(value)
            case .cancelled: e.cancelled()
            default: break
            }
        }
        return [g]
    }
}
/// iOS 13–16 name: the value is the angle
public struct RotationGesture: Gesture {
    public typealias Value = Angle
    public var minimumAngleDelta: Angle
    public init(minimumAngleDelta: Angle = .degrees(1)) { self.minimumAngleDelta = minimumAngleDelta }
    public func _install(on view: UIView, _ e: _GestureEvents<Angle>) -> [UIGestureRecognizer] {
        RotateGesture(minimumAngleDelta: minimumAngleDelta)._install(on: view, _GestureEvents(changed: { e.changed($0.rotation) }, ended: { e.ended($0.rotation) }, cancelled: e.cancelled))
    }
}

// MARK: - Modifiers on gestures
public struct _ChangedGesture<Base: Gesture>: Gesture {
    public typealias Value = Base.Value
    let base: Base, action: (Base.Value) -> Void
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        base._install(on: view, _GestureEvents(changed: { action($0); e.changed($0) }, ended: e.ended, cancelled: e.cancelled))
    }
}
public struct _EndedGesture<Base: Gesture>: Gesture {
    public typealias Value = Base.Value
    let base: Base, action: (Base.Value) -> Void
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        base._install(on: view, _GestureEvents(changed: e.changed, ended: { action($0); e.ended($0) }, cancelled: e.cancelled))
    }
}
public struct _MapGesture<Base: Gesture, Value>: Gesture {
    let base: Base, transform: (Base.Value) -> Value
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        base._install(on: view, _GestureEvents(changed: { e.changed(transform($0)) }, ended: { e.ended(transform($0)) }, cancelled: e.cancelled))
    }
}
public struct GestureStateGesture<Base: Gesture, State>: Gesture {
    public typealias Value = Base.Value
    let base: Base, state: GestureState<State>, body: (Base.Value, inout State, inout Transaction) -> Void
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let s = state, b = body
        return base._install(on: view, _GestureEvents(changed: { v in
            var x = s.box.value, t = Transaction()
            b(v, &x, &t)
            s.box.set(x)
            e.changed(v)
        }, ended: { v in s.box.reset(); e.ended(v) }, cancelled: { s.box.reset(); e.cancelled() }))
    }
}
extension Gesture {
    public func onChanged(_ action: @escaping (Value) -> Void) -> _ChangedGesture<Self> { _ChangedGesture(base: self, action: action) }
    public func onEnded(_ action: @escaping (Value) -> Void) -> _EndedGesture<Self> { _EndedGesture(base: self, action: action) }
    public func map<T>(_ body: @escaping (Value) -> T) -> _MapGesture<Self, T> { _MapGesture(base: self, transform: body) }
    public func updating<State>(_ state: GestureState<State>, body: @escaping (Value, inout State, inout Transaction) -> Void) -> GestureStateGesture<Self, State> {
        GestureStateGesture(base: self, state: state, body: body)
    }
    public func simultaneously<Other: Gesture>(with other: Other) -> SimultaneousGesture<Self, Other> { SimultaneousGesture(self, other) }
    public func sequenced<Other: Gesture>(before other: Other) -> SequenceGesture<Self, Other> { SequenceGesture(self, other) }
    public func exclusively<Other: Gesture>(before other: Other) -> ExclusiveGesture<Self, Other> { ExclusiveGesture(self, other) }
}

// MARK: - Composition
final class _SimState<A, B> { var a: A?; var b: B?; var endedA = false, endedB = false, activeA = false, activeB = false; init() {} }
final class _SeqState<A> { var a: A?; var done = false; init() {} }
final class _ExclState { var firstActive = false; init() {} }
public struct SimultaneousGesture<First: Gesture, Second: Gesture>: Gesture {
    public struct Value { public var first: First.Value?; public var second: Second.Value? }
    public var first: First, second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let s = _SimState<First.Value, Second.Value>()
        func finish() { if (!s.activeA || s.endedA) && (!s.activeB || s.endedB) { e.ended(Value(first: s.a, second: s.b)); s.a = nil; s.b = nil; s.activeA = false; s.activeB = false; s.endedA = false; s.endedB = false } }
        let ra = first._install(on: view, _GestureEvents(changed: { s.a = $0; s.activeA = true; e.changed(Value(first: s.a, second: s.b)) },
                                                          ended: { s.a = $0; s.activeA = true; s.endedA = true; finish() }, cancelled: { s.activeA = false; finish() }))
        let rb = second._install(on: view, _GestureEvents(changed: { s.b = $0; s.activeB = true; e.changed(Value(first: s.a, second: s.b)) },
                                                           ended: { s.b = $0; s.activeB = true; s.endedB = true; finish() }, cancelled: { s.activeB = false; finish() }))
        return ra + rb
    }
}
extension SimultaneousGesture.Value: Equatable where First.Value: Equatable, Second.Value: Equatable {}
public struct SequenceGesture<First: Gesture, Second: Gesture>: Gesture {
    public enum Value { case first(First.Value), second(First.Value, Second.Value?) }
    public var first: First, second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    /// the second gesture's events count only once the first one ended (both see the same touches)
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let s = _SeqState<First.Value>()
        let ra = first._install(on: view, _GestureEvents(changed: { if !s.done { e.changed(.first($0)) } },
                                                          ended: { s.a = $0; s.done = true; e.changed(.second($0, nil)) },
                                                          cancelled: { s.done = false; s.a = nil; e.cancelled() }))
        let rb = second._install(on: view, _GestureEvents(changed: { if s.done, let a = s.a { e.changed(.second(a, $0)) } },
                                                           ended: { if s.done, let a = s.a { e.ended(.second(a, $0)) }; s.done = false; s.a = nil },
                                                           cancelled: { if s.done { e.cancelled() }; s.done = false; s.a = nil }))
        // a touch that ends without the second gesture still ends the sequence
        let lift = _SUIDragRecognizer(target: nil, action: nil)
        lift.minimumDistance = 0
        _addRecognizer(lift, to: view) { r in
            if r.state == .ended || r.state == .cancelled {
                DispatchQueue.main.async { if s.done, let a = s.a { e.ended(.second(a, nil)); s.done = false; s.a = nil } }
            }
        }
        return ra + rb + [lift]
    }
}
public struct ExclusiveGesture<First: Gesture, Second: Gesture>: Gesture {
    public enum Value { case first(First.Value), second(Second.Value) }
    public var first: First, second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    /// the first gesture wins; the second one only counts if the first fails (discrete recognizers wait for it)
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] {
        let s = _ExclState()
        let ra = first._install(on: view, _GestureEvents(changed: { s.firstActive = true; e.changed(.first($0)) },
                                                          ended: { s.firstActive = false; e.ended(.first($0)) }, cancelled: { s.firstActive = false; e.cancelled() }))
        let rb = second._install(on: view, _GestureEvents(changed: { if !s.firstActive { e.changed(.second($0)) } },
                                                           ended: { if !s.firstActive { e.ended(.second($0)) } }, cancelled: { if !s.firstActive { e.cancelled() } }))
        for b in rb { for a in ra { b.require(toFail: a) } }
        return ra + rb
    }
}
public struct AnyGesture<Value>: Gesture {
    let install: @MainActor (UIView, _GestureEvents<Value>) -> [UIGestureRecognizer]
    public init<T: Gesture>(_ gesture: T) where T.Value == Value { install = { gesture._install(on: $0, $1) } }
    public func _install(on view: UIView, _ e: _GestureEvents<Value>) -> [UIGestureRecognizer] { install(view, e) }
}

// MARK: - @GestureState
@propertyWrapper
public struct GestureState<Value>: DynamicProperty, _DynamicProperty {
    final class Box {
        var storage: _StateStorage<Value>?; let initial: Value; weak var graph: _Graph?
        var resetHandler: ((Value) -> Void)?
        init(_ v: Value) { initial = v }
        var value: Value { storage?.value ?? initial }
        func set(_ v: Value) { if let s = storage { s.value = v; graph?.invalidate() } }
        func reset() { set(initial) }
    }
    let box: Box
    public init(wrappedValue: Value) { box = Box(wrappedValue) }
    public init(initialValue: Value) { box = Box(initialValue) }
    public init(wrappedValue: Value, resetTransaction: Transaction) { box = Box(wrappedValue) }
    public var wrappedValue: Value { box.value }
    public var projectedValue: GestureState<Value> { self }
    func _install(_ ctx: _Context, label: String) {
        let key = ctx.path + "#" + label
        if let s = ctx.graph.storage[key] as? _StateStorage<Value> { box.storage = s }
        else { let s = _StateStorage(box.initial); ctx.graph.storage[key] = s; box.storage = s }
        ctx.graph.usedKeys.insert(key)
        box.graph = ctx.graph
    }
}
extension GestureState where Value: ExpressibleByNilLiteral {
    public init(resetTransaction: Transaction = Transaction()) { self.init(wrappedValue: nil) }
}

extension Angle {
    public static func += (a: inout Angle, b: Angle) { a = a + b }
    public static func -= (a: inout Angle, b: Angle) { a = a - b }
}

public struct GestureMask: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let none: GestureMask = [], gesture = GestureMask(rawValue: 1), subviews = GestureMask(rawValue: 2), all = GestureMask(rawValue: 3)
}

// MARK: - attaching gestures to views
extension View {
    public func gesture<G: Gesture>(_ g: G, including mask: GestureMask = .all) -> some View {
        _modify { ctx, c in _GestureNode(path: ctx.path, install: { v in g._install(on: v, _GestureEvents()) }, child: _resolve(c, ctx.child("gst"))) }
    }
    public func gesture<G: Gesture>(_ g: G, isEnabled: Bool) -> some View { gesture(g, including: isEnabled ? .all : .none) }
    public func simultaneousGesture<G: Gesture>(_ g: G, including mask: GestureMask = .all) -> some View { gesture(g, including: mask) }
    public func highPriorityGesture<G: Gesture>(_ g: G, including mask: GestureMask = .all) -> some View { gesture(g, including: mask) }
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void) -> some View {
        gesture(LongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance).onEnded { _ in action() })
    }
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void,
                                   onPressingChanged: ((Bool) -> Void)?) -> some View {
        gesture(LongPressGesture(minimumDuration: minimumDuration, maximumDistance: maximumDistance).onEnded { _ in onPressingChanged?(false); action() })
    }
    public func onTapGesture(count: Int = 1, coordinateSpace: CoordinateSpace = .local, perform action: @escaping (CGPoint) -> Void) -> some View {
        gesture(SpatialTapGesture(count: count, coordinateSpace: coordinateSpace).onEnded { action($0.location) })
    }
}

final class _GestureNode: _WrapperNode {
    let install: @MainActor (UIView) -> [UIGestureRecognizer]
    init(path: String, install: @escaping @MainActor (UIView) -> [UIGestureRecognizer], child: _Node) { self.install = install; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGestureView(frame: .zero) }
        v.reinstall(install)
        return v
    }
}
/// Whether a view or one of its subviews (shown, not transparent containers) covers a point (in its coordinates).
@MainActor func _drawsAt(_ v: UIView, _ p: CGPoint) -> Bool {
    if v.isHidden || v.alpha <= 0.01 { return false }
    if !(v is _PassthroughView || v is _PassthroughViewBase), v.bounds.contains(p) { return true }
    if v.clipsToBounds && !v.bounds.contains(p) { return false }
    return v.subviews.contains { _drawsAt($0, $0.convert(p, from: v)) }
}
/// The view a `.gesture` wraps: it owns the gesture's recognizers (rebuilt with the latest closures on each update).
final class _SUIGestureView: UIView {
    var recognizers: [UIGestureRecognizer] = []
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func reinstall(_ install: @escaping @MainActor (UIView) -> [UIGestureRecognizer]) {
        // a gesture in progress keeps its recognizers until its touch ends
        if recognizers.contains(where: { $0.state == .began || $0.state == .changed }) { pending = install; return }
        for r in recognizers { removeGestureRecognizer(r) }
        recognizers = install(self)
    }
    var pending: (@MainActor (UIView) -> [UIGestureRecognizer])?
    /// like SwiftUI, content drawn outside the view's frame (moved by .offset, overflowing) takes the gesture too
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let v = super.hitTest(point, with: event) { return v }
        guard !isHidden, alpha > 0.01, isUserInteractionEnabled, !clipsToBounds else { return nil }
        for s in subviews.reversed() { if let h = s.hitTest(s.convert(point, from: self), with: event) { return h } }
        return subviews.contains { _drawsAt($0, $0.convert(point, from: self)) } ? self : nil
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let p = pending { pending = nil; DispatchQueue.main.async { MainActor.assumeIsolated { self.reinstall(p) } } }
    }
}

// MARK: - Optional gestures
/// As on iOS: `.gesture(enabled ? DragGesture() : nil)`; nil installs nothing.
extension Optional: Gesture where Wrapped: Gesture {
    public typealias Value = Wrapped.Value
    public func _install(on view: UIView, _ e: _GestureEvents<Wrapped.Value>) -> [UIGestureRecognizer] {
        switch self { case .some(let g): return g._install(on: view, e); case .none: return [] }
    }
}
