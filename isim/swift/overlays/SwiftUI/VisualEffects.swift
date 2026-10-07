// isim SwiftUI: visual effects drawn by isim's renderer — colour filters (brightness, contrast, saturation, grayscale,
// hueRotation, colorMultiply, colorInvert, luminanceToAlpha), blur, blend modes, compositingGroup / drawingGroup,
// drop shadows of the content's shape, alpha masks, clipped(), contentShape, and the iOS 17 geometry-driven effects
// visualEffect(_:) and scrollTransition(_:). Adapted: the content of the view is rendered into a group which isim's
// host (isim_gfx_pop_group_filtered) runs through a 4x5 colour matrix, a three-pass box blur (~ a Gaussian), a shadow
// of its alpha and a cairo blend operator. The filter modifiers are Animatable (withAnimation interpolates them).
import UIKit
import isim_host

// MARK: - Effect operations

/// One effect with its (animatable) parameters.
struct _VFXOp: Equatable {
    enum Kind: Int { case blur, blurOpaque, brightness, contrast, saturation, grayscale, hueRotation, colorMultiply, colorInvert,
                         luminanceToAlpha, blend, shadow, group, offset, scale, rotation, rotation3D, opacity }
    var kind: Kind
    var p: [Double]
    init(_ kind: Kind, _ p: [Double] = []) { self.kind = kind; self.p = p }
}

/// 4x5 colour matrix (rows R G B A; columns r g b a bias).
struct _ColorMatrix {
    var m: [Double] = [1, 0, 0, 0, 0,  0, 1, 0, 0, 0,  0, 0, 1, 0, 0,  0, 0, 0, 1, 0]
    var isIdentity: Bool { m == _ColorMatrix().m }
    /// self, then `n` (n ∘ self)
    func then(_ n: _ColorMatrix) -> _ColorMatrix {
        var o = _ColorMatrix()
        for r in 0..<4 {
            for c in 0..<5 {
                var v = 0.0
                for k in 0..<4 { v += n.m[r * 5 + k] * m[k * 5 + c] }
                if c == 4 { v += n.m[r * 5 + 4] }
                o.m[r * 5 + c] = v
            }
        }
        return o
    }
    static let lum = (0.2126, 0.7152, 0.0722)
    static func saturation(_ s: Double) -> _ColorMatrix {
        let (lr, lg, lb) = lum, k = 1 - s
        return _ColorMatrix(m: [lr * k + s, lg * k, lb * k, 0, 0,  lr * k, lg * k + s, lb * k, 0, 0,  lr * k, lg * k, lb * k + s, 0, 0,  0, 0, 0, 1, 0])
    }
    static func of(_ op: _VFXOp) -> _ColorMatrix? {
        let p = op.p
        switch op.kind {
        case .brightness: let b = p[0]; return _ColorMatrix(m: [1, 0, 0, 0, b,  0, 1, 0, 0, b,  0, 0, 1, 0, b,  0, 0, 0, 1, 0])
        case .contrast: let c = p[0], o = (1 - c) * 0.5; return _ColorMatrix(m: [c, 0, 0, 0, o,  0, c, 0, 0, o,  0, 0, c, 0, o,  0, 0, 0, 1, 0])
        case .saturation: return saturation(p[0])
        case .grayscale: return saturation(1 - min(1, max(0, p[0])))
        case .hueRotation:
            let c = Foundation.cos(p[0]), s = Foundation.sin(p[0])
            return _ColorMatrix(m: [0.213 + c * 0.787 - s * 0.213, 0.715 - c * 0.715 - s * 0.715, 0.072 - c * 0.072 + s * 0.928, 0, 0,
                                    0.213 - c * 0.213 + s * 0.143, 0.715 + c * 0.285 + s * 0.140, 0.072 - c * 0.072 - s * 0.283, 0, 0,
                                    0.213 - c * 0.213 - s * 0.787, 0.715 - c * 0.715 + s * 0.715, 0.072 + c * 0.928 + s * 0.072, 0, 0,
                                    0, 0, 0, 1, 0])
        case .colorMultiply: return _ColorMatrix(m: [p[0], 0, 0, 0, 0,  0, p[1], 0, 0, 0,  0, 0, p[2], 0, 0,  0, 0, 0, p[3], 0])
        case .colorInvert: return _ColorMatrix(m: [-1, 0, 0, 0, 1,  0, -1, 0, 0, 1,  0, 0, -1, 0, 1,  0, 0, 0, 1, 0])
        case .luminanceToAlpha:
            let (lr, lg, lb) = lum
            return _ColorMatrix(m: [0, 0, 0, 0, 0,  0, 0, 0, 0, 0,  0, 0, 0, 0, 0,  lr, lg, lb, 0, 0])
        default: return nil
        }
    }
}

/// The 32 values isim's UIKit hands to isim_gfx_pop_group_filtered (see isim_host.h), or nil when `ops` draws nothing
/// special. `isolate` keeps a group even without effects (compositingGroup / drawingGroup).
func _vfxSpec(_ ops: [_VFXOp]) -> [Double]? {
    var cm = _ColorMatrix(), blur = 0.0, blend = 0.0, shadow: [Double]? = nil, opaque = false, group = false
    for op in ops {
        if let m = _ColorMatrix.of(op) { cm = cm.then(m); continue }
        switch op.kind {
        case .blur: blur = max(blur, op.p[0])
        case .blurOpaque: blur = max(blur, op.p[0]); opaque = true
        case .blend: blend = op.p[0]
        case .shadow: shadow = op.p
        case .group: group = true
        default: break
        }
    }
    let hasMatrix = !cm.isIdentity
    guard hasMatrix || blur > 0 || blend != 0 || shadow != nil || group else { return nil }
    var v = [Double](repeating: 0, count: 32)
    for i in 0..<20 { v[i] = cm.m[i] }
    v[20] = blur; v[21] = blend
    if let s = shadow { for i in 0..<7 { v[22 + i] = s[i] } }
    v[29] = Double((hasMatrix ? 1 : 0) | (opaque ? 4 : 0))
    return v
}

@MainActor func _setVFX(_ v: UIView, _ spec: [Double]?) {
    if let s = spec { s.withUnsafeBufferPointer { v._isim_setVisualEffect($0.baseAddress) } } else { v._isim_setVisualEffect(nil) }
}

func _rgba(_ c: Color, _ env: EnvironmentValues) -> [Double] {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    let traits = UITraitCollection(userInterfaceStyle: env.colorScheme == .dark ? .dark : .light)
    if !c.uiColor.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a) { return [0, 0, 0, 1] }
    return [Double(r), Double(g), Double(b), Double(a)]
}

func _blendIndex(_ m: BlendMode) -> Double {
    switch m {
    case .normal: return 0
    case .multiply: return 1
    case .screen: return 2
    case .overlay: return 3
    case .darken: return 4
    case .lighten: return 5
    case .colorDodge: return 6
    case .colorBurn: return 7
    case .softLight: return 8
    case .hardLight: return 9
    case .difference: return 10
    case .exclusion: return 11
    case .hue: return 12
    case .saturation: return 13
    case .color: return 14
    case .luminosity: return 15
    case .sourceAtop: return 16
    case .destinationOver: return 17
    case .destinationOut: return 18
    case .plusDarker: return 19
    case .plusLighter: return 20
    @unknown default: return 0
    }
}

// MARK: - Filter modifiers

/// A view with one effect; its parameters animate (withAnimation) like any Animatable view.
struct _VFXView<Content: View>: View, _PrimitiveView, Animatable {
    var op: _VFXOp
    let content: Content
    var body: Never { fatalError() }
    var animatableData: _AnimatableVector {
        get { _AnimatableVector(op.kind == .blend ? [] : op.p) }
        set { if op.kind != .blend, newValue.values.count == op.p.count { op.p = newValue.values } }
    }
    func _makeNode(_ ctx: _Context) -> _Node { _VFXNode(path: ctx.path, spec: _vfxSpec([op]), child: _resolve(content, ctx.child("vfx"))) }
}
final class _VFXNode: _WrapperNode {
    let spec: [Double]?
    init(path: String, spec: [Double]?, child: _Node) { self.spec = spec; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        _setVFX(v, spec)
        return v
    }
}

extension View {
    func _vfx(_ op: _VFXOp) -> _VFXView<Self> { _VFXView(op: op, content: self) }
    /// Gaussian-like blur of the view's content (`opaque`: no transparent fringe at the edges).
    public func blur(radius: CGFloat, opaque: Bool = false) -> some View { _vfx(_VFXOp(opaque ? .blurOpaque : .blur, [Double(radius)])) }
    /// Adds `amount` to the red, green and blue components (1 = white).
    public func brightness(_ amount: Double) -> some View { _vfx(_VFXOp(.brightness, [amount])) }
    /// Contrast around mid grey (0 = flat grey, 1 = unchanged).
    public func contrast(_ amount: Double) -> some View { _vfx(_VFXOp(.contrast, [amount])) }
    /// Colour saturation (0 = grey, 1 = unchanged).
    public func saturation(_ amount: Double) -> some View { _vfx(_VFXOp(.saturation, [amount])) }
    /// Removes colour (1 = fully grey).
    public func grayscale(_ amount: Double) -> some View { _vfx(_VFXOp(.grayscale, [amount])) }
    public func hueRotation(_ angle: Angle) -> some View { _vfx(_VFXOp(.hueRotation, [angle.radians])) }
    public func colorMultiply(_ c: Color) -> some View {
        _modify { ctx, content in _resolve(_VFXView(op: _VFXOp(.colorMultiply, _rgba(c, ctx.environment)), content: content), ctx.child("cm")) }
    }
    public func colorInvert() -> some View { _vfx(_VFXOp(.colorInvert)) }
    /// The content's luminance becomes its alpha (black, transparent where dark).
    public func luminanceToAlpha() -> some View { _vfx(_VFXOp(.luminanceToAlpha)) }
    /// How the view composites over what is behind it (inside the nearest compositingGroup, or the window).
    public func blendMode(_ m: BlendMode) -> some View { _vfx(_VFXOp(.blend, [_blendIndex(m)])) }
    /// Renders the view and its children as one layer before its opacity, blend mode and effects apply.
    public func compositingGroup() -> some View { _vfx(_VFXOp(.group)) }
    /// Flattens the view into one image before compositing (isim: like compositingGroup).
    public func drawingGroup(opaque: Bool = false) -> some View { _vfx(_VFXOp(.group)) }
    public func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode) -> some View { _vfx(_VFXOp(.group)) }
    /// A drop shadow of the view's content (its alpha), blurred by `radius` and offset by (x, y).
    public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View {
        _modify { ctx, content in
            _resolve(_VFXView(op: _VFXOp(.shadow, _rgba(color, ctx.environment) + [Double(radius), Double(x), Double(y)]), content: content), ctx.child("sh"))
        }
    }
    /// Clips the view to its frame.
    public func clipped() -> some View { _modify { ctx, c in _ClipNode(path: ctx.path, kind: .rect, child: _resolve(c, ctx.child("clipped"))) } }
    public func clipped(antialiased: Bool) -> some View { clipped() }
    /// A border drawn inside the view's frame.
    public func border<S: ShapeStyle>(_ content: S, width: CGFloat = 1) -> some View { overlay { Rectangle().strokeBorder(content, lineWidth: width) } }
}

// MARK: - Masks

/// Masks: a plain shape clips to its path; any other view masks by its alpha (gradients, text, images, opacity).
extension View {
    public func mask<M: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> M) -> some View {
        let m = mask()
        if m is any Shape {
            if let info = m as? _ShapeInfo { let kind = info._kind; return AnyView(_modify { ctx, c in _ClipNode(path: ctx.path, kind: kind, child: _resolve(c, ctx.child("mask"))) }) }
            if let shape = _innerAnyShape(m) {
                return AnyView(_modify { ctx, c in _PathClipNode(path: ctx.path, shape: shape, eoFill: false, child: _resolve(c, ctx.child("mask"))) })
            }
        }
        return AnyView(_modify { ctx, c in
            _AlphaMaskNode(path: ctx.path, alignment: alignment, mask: _resolve(m, ctx.child("maskview")), child: _resolve(c, ctx.child("mask")))
        })
    }
    public func mask<M: View>(_ mask: M) -> some View { self.mask { mask } }
}
final class _AlphaMaskNode: _WrapperNode {
    let mask: _Node, alignment: Alignment
    init(path: String, alignment: Alignment, mask: _Node, child: _Node) { self.mask = mask; self.alignment = alignment; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) {
        frame = rect
        child.place(CGRect(origin: .zero, size: rect.size))
        let s = mask.sizeThatFits(_Proposal(width: rect.width, height: rect.height))
        mask.place(_align(CGSize(width: min(s.width, rect.width), height: min(s.height, rect.height)), in: CGRect(origin: .zero, size: rect.size), alignment))
    }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _PassthroughView() } }
    override func mountChildren(_ g: _Graph, in view: UIView) {
        g.mount(child, in: view, order: 0)
        let holder = g.view(path + "|maskholder") { _PassthroughView() }
        holder.frame = CGRect(origin: .zero, size: frame.size)
        g.mount(mask, in: holder, order: 0)
        if view.mask !== holder { view.mask = holder }
    }
}

// MARK: - contentShape

public struct ContentShapeKinds: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let interaction = ContentShapeKinds(rawValue: 1), dragPreview = ContentShapeKinds(rawValue: 2)
    public static let contextMenuPreview = ContentShapeKinds(rawValue: 4), hoverEffect = ContentShapeKinds(rawValue: 8)
    public static let focusEffect = ContentShapeKinds(rawValue: 16), accessibility = ContentShapeKinds(rawValue: 32)
}
extension View {
    /// The shape that takes touches: the whole shape (also where nothing is drawn, e.g. around a Spacer), nothing outside it.
    public func contentShape<S>(_ shape: S) -> some View {
        let s = (shape as? any Shape).map { _anyShape($0) }
        return _modify { ctx, c in
            let node = _resolve(c, ctx.child("cs"))
            guard let s else { return node }
            return _ContentShapeNode(path: ctx.path, shape: s, eoFill: false, child: node)
        }
    }
    public func contentShape<S: Shape>(_ shape: S, eoFill: Bool) -> some View {
        let s = AnyShape(shape)
        return _modify { ctx, c in _ContentShapeNode(path: ctx.path, shape: s, eoFill: eoFill, child: _resolve(c, ctx.child("cs"))) }
    }
    /// Shapes for other kinds (drag/context-menu previews, hover, focus) do not change hit testing.
    public func contentShape<S: Shape>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View {
        let s = AnyShape(shape)
        return _modify { ctx, c in
            let node = _resolve(c, ctx.child("cs"))
            return kind.contains(.interaction) ? _ContentShapeNode(path: ctx.path, shape: s, eoFill: eoFill, child: node) : node
        }
    }
}
func _anyShape<S: Shape>(_ s: S) -> AnyShape { AnyShape(s) }
final class _ContentShapeNode: _WrapperNode {
    let shape: AnyShape, eoFill: Bool
    init(path: String, shape: AnyShape, eoFill: Bool, child: _Node) { self.shape = shape; self.eoFill = eoFill; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIContentShapeView(frame: .zero) }
        v.hitPath = shape.path(in: CGRect(origin: .zero, size: frame.size)); v.eoFill = eoFill
        return v
    }
}
/// Takes every touch inside its shape (the gestures around it then see it), none outside.
final class _SUIContentShapeView: UIView {
    var hitPath = Path(), eoFill = false
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    func contains(_ p: CGPoint) -> Bool { hitPath.contains(p, eoFill: eoFill) }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, alpha > 0.01, contains(point) else { return nil }
        for s in subviews.reversed() { if let h = s.hitTest(s.convert(point, from: self), with: event) { return h } }
        return self
    }
}
/// A control (button, tap gesture) whose content has a contentShape takes touches only inside that shape.
@MainActor func _contentShapeRejects(_ control: UIView, _ point: CGPoint) -> Bool {
    var v: UIView? = control.subviews.first
    while let x = v {
        if let s = x as? _SUIContentShapeView { return !s.contains(s.convert(point, from: control)) }
        if x.subviews.count != 1 || x.transform != .identity { return false }
        v = x.subviews.first
    }
    return false
}

// MARK: - visualEffect / scrollTransition (iOS 17)

/// Effects that depend on the view's geometry (visualEffect) or scroll position (scrollTransition).
@available(iOS 17.0, *)
public protocol VisualEffect: Sendable, Animatable {}
protocol _VFXChain { var _ops: [_VFXOp] { get } }

@available(iOS 17.0, *)
public struct EmptyVisualEffect: VisualEffect, _VFXChain {
    public init() {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
    var _ops: [_VFXOp] { [] }
}
@available(iOS 17.0, *)
struct _VisualEffectChain: VisualEffect, _VFXChain, @unchecked Sendable {
    var ops: [_VFXOp]
    var _ops: [_VFXOp] { ops }
    var animatableData: _AnimatableVector {
        get { _AnimatableVector(ops.flatMap { $0.p }) }
        set {
            var i = 0
            for k in ops.indices { for j in ops[k].p.indices where i < newValue.values.count { ops[k].p[j] = newValue.values[i]; i += 1 } }
        }
    }
}
@available(iOS 17.0, *)
extension VisualEffect {
    func _adding(_ op: _VFXOp) -> _VisualEffectChain { _VisualEffectChain(ops: ((self as? _VFXChain)?._ops ?? []) + [op]) }
    public func offset(_ offset: CGSize) -> some VisualEffect { _adding(_VFXOp(.offset, [Double(offset.width), Double(offset.height)])) }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some VisualEffect { _adding(_VFXOp(.offset, [Double(x), Double(y)])) }
    public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some VisualEffect {
        _adding(_VFXOp(.scale, [Double(scale.width), Double(scale.height), Double(anchor.x), Double(anchor.y)]))
    }
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some VisualEffect { scaleEffect(CGSize(width: s, height: s), anchor: anchor) }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some VisualEffect { scaleEffect(CGSize(width: x, height: y), anchor: anchor) }
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some VisualEffect {
        _adding(_VFXOp(.rotation, [angle.radians, Double(anchor.x), Double(anchor.y)]))
    }
    public func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0,
                                 perspective: CGFloat = 1) -> some VisualEffect {
        _adding(_VFXOp(.rotation3D, [angle.radians, Double(axis.x), Double(axis.y), Double(axis.z), Double(anchor.x), Double(anchor.y), Double(anchorZ), Double(perspective)]))
    }
    public func opacity(_ opacity: Double) -> some VisualEffect { _adding(_VFXOp(.opacity, [opacity])) }
    public func blur(radius: CGFloat, opaque: Bool = false) -> some VisualEffect { _adding(_VFXOp(opaque ? .blurOpaque : .blur, [Double(radius)])) }
    public func brightness(_ amount: Double) -> some VisualEffect { _adding(_VFXOp(.brightness, [amount])) }
    public func contrast(_ amount: Double) -> some VisualEffect { _adding(_VFXOp(.contrast, [amount])) }
    public func saturation(_ amount: Double) -> some VisualEffect { _adding(_VFXOp(.saturation, [amount])) }
    public func grayscale(_ amount: Double) -> some VisualEffect { _adding(_VFXOp(.grayscale, [amount])) }
    public func hueRotation(_ angle: Angle) -> some VisualEffect { _adding(_VFXOp(.hueRotation, [angle.radians])) }
    public func colorMultiply(_ color: Color) -> some VisualEffect { _adding(_VFXOp(.colorMultiply, _rgba(color, EnvironmentValues()))) }
}

@available(iOS 17.0, *)
extension View {
    /// Effects computed from the view's geometry (its frame in the window, the scroll view or a named space); they follow
    /// scrolling without re-evaluating the view. Layout is unaffected.
    public func visualEffect(_ effect: @escaping @Sendable (EmptyVisualEffect, GeometryProxy) -> some VisualEffect) -> some View {
        _modify { ctx, c in
            _GeometryEffectNode(path: ctx.path, graph: ctx.graph, animated: false, child: _resolve(c, ctx.child("ve"))) { proxy, _ in
                (effect(EmptyVisualEffect(), proxy) as? _VFXChain)?._ops ?? []
            }
        }
    }
    /// Effects driven by the view's position in the enclosing scroll view: identity while fully visible, moving to
    /// `.topLeading` / `.bottomTrailing` as it leaves (interactive: interpolated with the visible fraction).
    public func scrollTransition(_ configuration: ScrollTransitionConfiguration = .interactive, axis: Axis? = nil,
                                 transition: @escaping @Sendable (EmptyVisualEffect, ScrollTransitionPhase) -> some VisualEffect) -> some View {
        scrollTransition(topLeading: configuration, bottomTrailing: configuration, axis: axis, transition: transition)
    }
    public func scrollTransition(topLeading: ScrollTransitionConfiguration, bottomTrailing: ScrollTransitionConfiguration, axis: Axis? = nil,
                                 transition: @escaping @Sendable (EmptyVisualEffect, ScrollTransitionPhase) -> some VisualEffect) -> some View {
        let animated = topLeading.kind == 0 || bottomTrailing.kind == 0
        return _modify { ctx, c in
            _GeometryEffectNode(path: ctx.path, graph: ctx.graph, animated: animated, child: _resolve(c, ctx.child("st"))) { proxy, view in
                let value = _scrollPhaseValue(view, axis: axis, topLeading: topLeading, bottomTrailing: bottomTrailing)
                let ops0 = (transition(EmptyVisualEffect(), .identity) as? _VFXChain)?._ops ?? []
                guard value != 0 else { return ops0 }
                let edge: ScrollTransitionPhase = value < 0 ? .topLeading : .bottomTrailing
                let cfg = value < 0 ? topLeading : bottomTrailing
                if cfg.kind == 2 { return ops0 }                                   // .identity
                let ops1 = (transition(EmptyVisualEffect(), edge) as? _VFXChain)?._ops ?? []
                guard cfg.kind == 1, ops1.count == ops0.count, zip(ops0, ops1).allSatisfy({ $0.kind == $1.kind && $0.p.count == $1.p.count }) else { return ops1 }
                let k = min(1, abs(value))                                          // .interactive: interpolated
                return zip(ops0, ops1).map { a, b in _VFXOp(a.kind, zip(a.p, b.p).map { $0 + ($1 - $0) * k }) }
            }
        }
    }
}

/// Where the scroll transition is: 0 fully visible, -1 out at the leading/top edge, 1 out at the trailing/bottom edge.
@MainActor func _scrollPhaseValue(_ v: UIView, axis: Axis?, topLeading: ScrollTransitionConfiguration, bottomTrailing: ScrollTransitionConfiguration) -> Double {
    var s: UIView? = v.superview
    while let x = s, !(x is UIScrollView) { s = x.superview }
    guard let sv = s as? UIScrollView, let sup = v.superview, let f0 = (v as? _SUIGeometryEffectView)?.layoutFrame else { return 0 }
    let f = sup.convert(f0, to: sv)
    let vis = sv.bounds
    let vertical = axis.map { $0 == .vertical } ?? (sv.contentSize.height > sv.bounds.height + 0.5 || sv.contentSize.width <= sv.bounds.width + 0.5)
    let (lo, hi, vlo, vhi) = vertical ? (f.minY, f.maxY, vis.minY, vis.maxY) : (f.minX, f.maxX, vis.minX, vis.maxX)
    let len = max(1, hi - lo)
    func amount(_ out: CGFloat, _ cfg: ScrollTransitionConfiguration) -> Double {
        // the threshold is the visible fraction where the edge phase is reached (0: when fully hidden, 1: as soon as it leaves)
        let outF = Double(min(1, max(0, out / len))), t = cfg.threshold
        return t >= 0.999 ? (outF > 0.001 ? 1 : 0) : min(1, outF / (1 - t))
    }
    if lo < vlo { let p = amount(vlo - lo, topLeading); return topLeading.kind == 0 ? (p > 0.5 ? -1 : 0) : -p }
    if hi > vhi { let p = amount(hi - vhi, bottomTrailing); return bottomTrailing.kind == 0 ? (p > 0.5 ? 1 : 0) : p }
    return 0
}

@available(iOS 17.0, *)
public enum ScrollTransitionPhase: Hashable, Sendable {
    case topLeading, identity, bottomTrailing
    public var isIdentity: Bool { self == .identity }
    public var value: Double { switch self { case .topLeading: return -1; case .identity: return 0; case .bottomTrailing: return 1 } }
}
@available(iOS 17.0, *)
public struct ScrollTransitionConfiguration: Sendable {
    /// 0 animated, 1 interactive, 2 identity
    var kind: Int
    /// the visible fraction of the view where the edge phase is reached (0: once fully hidden)
    var threshold: Double = 0
    var animation: Animation?
    public static var animated: ScrollTransitionConfiguration { ScrollTransitionConfiguration(kind: 0, animation: .default) }
    public static func animated(_ animation: Animation = .default) -> ScrollTransitionConfiguration { ScrollTransitionConfiguration(kind: 0, animation: animation) }
    public static var interactive: ScrollTransitionConfiguration { ScrollTransitionConfiguration(kind: 1) }
    public static func interactive(timingCurve: UnitCurve = .easeInOut) -> ScrollTransitionConfiguration { ScrollTransitionConfiguration(kind: 1) }
    public static var identity: ScrollTransitionConfiguration { ScrollTransitionConfiguration(kind: 2) }
    public func threshold(_ threshold: Threshold) -> ScrollTransitionConfiguration { var c = self; c.threshold = threshold.visible; return c }
    public func animation(_ animation: Animation) -> ScrollTransitionConfiguration { var c = self; c.animation = animation; return c }
    public struct Threshold: Sendable {
        /// the fraction of the view visible where the transition reaches its edge phase
        var visible: Double
        public static var visible: Threshold { Threshold(visible: 1) }
        public static var hidden: Threshold { Threshold(visible: 0) }
        public static var centered: Threshold { Threshold(visible: 0.5) }
        public static func visible(_ amount: Double) -> Threshold { Threshold(visible: max(0, min(1, amount))) }
        public func interpolated(towards other: Threshold, amount: Double) -> Threshold { Threshold(visible: visible + (other.visible - visible) * amount) }
        public func inset(by distance: Double) -> Threshold { self }
    }
}

/// Lays out like its content; its view applies effects computed from live geometry (after each render and while an
/// enclosing scroll view scrolls).
final class _GeometryEffectNode: _WrapperNode {
    let evaluate: (GeometryProxy, UIView) -> [_VFXOp]
    weak var graph: _Graph?
    let animated: Bool
    init(path: String, graph: _Graph, animated: Bool, child: _Node, evaluate: @escaping (GeometryProxy, UIView) -> [_VFXOp]) {
        self.evaluate = evaluate; self.graph = graph; self.animated = animated; super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIGeometryEffectView(frame: .zero) }
        v.evaluate = evaluate; v.layoutFrame = frame; v.animated = animated
        g.postRender.append { [weak v] in v?.apply() }
        return v
    }
}
final class _SUIGeometryEffectView: _PassthroughViewBase {
    var evaluate: ((GeometryProxy, UIView) -> [_VFXOp])?
    var layoutFrame = CGRect.zero
    var animated = false
    private var lastOps: [_VFXOp]?
    private var observer: NSObjectProtocol?
    override init(frame: CGRect) {
        super.init(frame: frame)
        observer = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimScrollViewDidScroll"), object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            MainActor.assumeIsolated {
                guard let self, let sv = n.object as? UIView, self.isDescendant(of: sv) else { return }
                self.apply()
            }
        })
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    func apply() {
        guard let evaluate, superview != nil else { return }
        let proxy = GeometryProxy(size: layoutFrame.size, safeAreaInsets: EdgeInsets(), globalFrame: superview?.convert(layoutFrame, to: nil) ?? layoutFrame,
                                  _space: { [weak self] space in self?.frame(in: space) })
        let ops = evaluate(proxy, self)
        if ops == lastOps { return }
        let first = lastOps == nil
        lastOps = ops
        if animated && !first { UIView.animate(withDuration: 0.3) { self.applyOps(ops) } } else { applyOps(ops) }
    }
    func applyOps(_ ops: [_VFXOp]) {
        // geometry: offset / scale / rotation (about anchors, in the view's own size) and 3D rotations
        let s = layoutFrame.size
        var p = ProjectionTransform(), alpha = 1.0
        for op in ops {
            let q = op.p
            switch op.kind {
            case .offset: p = p.concatenating(ProjectionTransform(CGAffineTransform(translationX: q[0], y: q[1])))
            case .scale:
                let ax = q[2] * s.width, ay = q[3] * s.height
                p = p.concatenating(ProjectionTransform(CGAffineTransform(translationX: -ax, y: -ay).concatenating(CGAffineTransform(scaleX: q[0], y: q[1])).concatenating(CGAffineTransform(translationX: ax, y: ay))))
            case .rotation:
                let ax = q[1] * s.width, ay = q[2] * s.height
                p = p.concatenating(ProjectionTransform(CGAffineTransform(translationX: -ax, y: -ay).concatenating(CGAffineTransform(rotationAngle: q[0])).concatenating(CGAffineTransform(translationX: ax, y: ay))))
            case .rotation3D:
                let e = _Rotation3DEffect(angle: .radians(q[0]), axis: (q[1], q[2], q[3]), anchor: UnitPoint(x: q[4], y: q[5]), anchorZ: q[6], perspective: q[7])
                p = p.concatenating(e.effectValue(size: s))
            case .opacity: alpha *= q[0]
            default: break
            }
        }
        _applyProjection(self, p, s)
        if abs(self.alpha - alpha) > 0.001 { self.alpha = alpha }
        _setVFX(self, _vfxSpec(ops))
    }
    /// this view's untransformed frame in a coordinate space
    func frame(in space: CoordinateSpace) -> CGRect? {
        guard let sup = superview else { return nil }
        switch space {
        case .local: return CGRect(origin: .zero, size: layoutFrame.size)
        case .global: return sup.convert(layoutFrame, to: nil)
        case .named(let name):
            if name == AnyHashable("_isim.scrollView") {
                var s: UIView? = sup
                while let x = s, !(x is UIScrollView) { s = x.superview }
                guard let sv = s as? UIScrollView else { return sup.convert(layoutFrame, to: nil) }
                let r = sup.convert(layoutFrame, to: sv)
                return r.offsetBy(dx: -sv.bounds.minX, dy: -sv.bounds.minY)
            }
            return sup.convert(layoutFrame, to: nil)
        @unknown default: return sup.convert(layoutFrame, to: nil)
        }
    }
}
/// A container that does not intercept touches outside its children (like _PassthroughView, but subclassable).
class _PassthroughViewBase: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if v != nil || clipsToBounds || isHidden || !isUserInteractionEnabled || alpha <= 0.01 { return v === self ? nil : v }
        for s in subviews.reversed() { if let h = s.hitTest(s.convert(point, from: self), with: event) { return h } }
        return nil
    }
}

/// Applies a top-leading based projection to a view (affine: its transform; perspective: its transform3D).
@MainActor func _applyProjection(_ v: UIView, _ p: ProjectionTransform, _ s: CGSize) {
    if p.isAffine {
        let m = p._affine(s)
        let c = CGAffineTransform(translationX: s.width / 2, y: s.height / 2)
        let t = c.concatenating(m).concatenating(CGAffineTransform(translationX: -s.width / 2, y: -s.height / 2))
        if v.transform != t || !CATransform3DIsAffine(v.transform3D) { v.transform = t }
    } else {
        var m = CATransform3DIdentity
        m.m11 = p.m11; m.m12 = p.m12; m.m14 = p.m13
        m.m21 = p.m21; m.m22 = p.m22; m.m24 = p.m23
        m.m41 = p.m31; m.m42 = p.m32; m.m44 = p.m33
        let t = CATransform3DConcat(CATransform3DConcat(CATransform3DMakeTranslation(s.width / 2, s.height / 2, 0), m),
                                    CATransform3DMakeTranslation(-s.width / 2, -s.height / 2, 0))
        if !CATransform3DEqualToTransform(v.transform3D, t) { v.transform3D = t }
    }
}

// MARK: - Coordinate spaces (iOS 17)

/// A coordinate space to measure in (GeometryProxy.frame(in:)).
public protocol CoordinateSpaceProtocol { var coordinateSpace: CoordinateSpace { get } }
public struct NamedCoordinateSpace: CoordinateSpaceProtocol, Equatable {
    let name: AnyHashable
    public var coordinateSpace: CoordinateSpace { .named(name) }
}
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol { public init() {}; public var coordinateSpace: CoordinateSpace { .global } }
public struct LocalCoordinateSpace: CoordinateSpaceProtocol { public init() {}; public var coordinateSpace: CoordinateSpace { .local } }
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace(name: AnyHashable(name)) }
    /// The nearest enclosing scroll view's visible area.
    public static var scrollView: NamedCoordinateSpace { NamedCoordinateSpace(name: AnyHashable("_isim.scrollView")) }
    public static func scrollView(axis: Axis) -> NamedCoordinateSpace { scrollView }
}
extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace { public static var global: GlobalCoordinateSpace { GlobalCoordinateSpace() } }
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace { public static var local: LocalCoordinateSpace { LocalCoordinateSpace() } }
extension GeometryProxy {
    public func frame(in space: some CoordinateSpaceProtocol) -> CGRect { frame(in: space.coordinateSpace) }
}
