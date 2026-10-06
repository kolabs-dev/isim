// isim SwiftUI: projection effects — transformEffect, projectionEffect, rotation3DEffect and custom
// GeometryEffects. Affine transforms go to the view's transform; projective ones (rotation3DEffect,
// non-affine projectionEffect) go to its transform3D, which isim's UIKit draws by warping the rendered view onto
// its projected corners (true perspective foreshortening). The effects are animatable.
import UIKit

public struct ProjectionTransform: Equatable, Sendable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0
    public var m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0
    public var m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1
    public init() {}
    public init(_ m: CGAffineTransform) { m11 = m.a; m12 = m.b; m21 = m.c; m22 = m.d; m31 = m.tx; m32 = m.ty }
    public var isIdentity: Bool { self == ProjectionTransform() }
    public var isAffine: Bool { m13 == 0 && m23 == 0 && m33 == 1 }
    public func concatenating(_ r: ProjectionTransform) -> ProjectionTransform {
        var o = ProjectionTransform()
        o.m11 = m11 * r.m11 + m12 * r.m21 + m13 * r.m31; o.m12 = m11 * r.m12 + m12 * r.m22 + m13 * r.m32; o.m13 = m11 * r.m13 + m12 * r.m23 + m13 * r.m33
        o.m21 = m21 * r.m11 + m22 * r.m21 + m23 * r.m31; o.m22 = m21 * r.m12 + m22 * r.m22 + m23 * r.m32; o.m23 = m21 * r.m13 + m22 * r.m23 + m23 * r.m33
        o.m31 = m31 * r.m11 + m32 * r.m21 + m33 * r.m31; o.m32 = m31 * r.m12 + m32 * r.m22 + m33 * r.m32; o.m33 = m31 * r.m13 + m32 * r.m23 + m33 * r.m33
        return o
    }
    public mutating func invert() -> Bool {
        let det = m11 * (m22 * m33 - m23 * m32) - m12 * (m21 * m33 - m23 * m31) + m13 * (m21 * m32 - m22 * m31)
        guard abs(det) > 1e-12 else { return false }
        let o = self
        m11 = (o.m22 * o.m33 - o.m23 * o.m32) / det; m12 = (o.m13 * o.m32 - o.m12 * o.m33) / det; m13 = (o.m12 * o.m23 - o.m13 * o.m22) / det
        m21 = (o.m23 * o.m31 - o.m21 * o.m33) / det; m22 = (o.m11 * o.m33 - o.m13 * o.m31) / det; m23 = (o.m13 * o.m21 - o.m11 * o.m23) / det
        m31 = (o.m21 * o.m32 - o.m22 * o.m31) / det; m32 = (o.m12 * o.m31 - o.m11 * o.m32) / det; m33 = (o.m11 * o.m22 - o.m12 * o.m21) / det
        return true
    }
    public func inverted() -> ProjectionTransform { var p = self; _ = p.invert(); return p }
    /// the projective transform mapping (0,0) (w,0) (w,h) (0,h) to q0 q1 q2 q3
    static func _quad(_ w: CGFloat, _ h: CGFloat, _ q0: CGPoint, _ q1: CGPoint, _ q2: CGPoint, _ q3: CGPoint) -> ProjectionTransform {
        let dx1 = q1.x - q2.x, dx2 = q3.x - q2.x, dy1 = q1.y - q2.y, dy2 = q3.y - q2.y
        let sx = q0.x - q1.x + q2.x - q3.x, sy = q0.y - q1.y + q2.y - q3.y
        var g: CGFloat = 0, k: CGFloat = 0
        if abs(sx) > 1e-9 || abs(sy) > 1e-9 {
            let den = dx1 * dy2 - dx2 * dy1
            if abs(den) > 1e-12 { g = (sx * dy2 - dx2 * sy) / den; k = (dx1 * sy - sx * dy1) / den }
        }
        var p = ProjectionTransform()
        p.m11 = (q1.x - q0.x + g * q1.x) / w; p.m21 = (q3.x - q0.x + k * q3.x) / h; p.m31 = q0.x
        p.m12 = (q1.y - q0.y + g * q1.y) / w; p.m22 = (q3.y - q0.y + k * q3.y) / h; p.m32 = q0.y
        p.m13 = g / w; p.m23 = k / h; p.m33 = 1
        return p
    }
    func _apply(_ p: CGPoint) -> CGPoint {
        let w = p.x * m13 + p.y * m23 + m33
        let x = p.x * m11 + p.y * m21 + m31, y = p.x * m12 + p.y * m22 + m32
        return abs(w) < 1e-9 ? CGPoint(x: x, y: y) : CGPoint(x: x / w, y: y / w)
    }
    /// The affine transform closest to this one over a rect of `size` at the origin (exact when affine).
    func _affine(_ size: CGSize) -> CGAffineTransform {
        if isAffine { return CGAffineTransform(a: m11, b: m12, c: m21, d: m22, tx: m31, ty: m32) }
        let w = max(size.width, 1), h = max(size.height, 1)
        let p00 = _apply(.zero), pw0 = _apply(CGPoint(x: w, y: 0)), p0h = _apply(CGPoint(x: 0, y: h)), pwh = _apply(CGPoint(x: w, y: h))
        let a = ((pw0.x - p00.x) + (pwh.x - p0h.x)) / (2 * w), c = ((p0h.x - p00.x) + (pwh.x - pw0.x)) / (2 * h)
        let b = ((pw0.y - p00.y) + (pwh.y - p0h.y)) / (2 * w), d = ((p0h.y - p00.y) + (pwh.y - pw0.y)) / (2 * h)
        let tx = (p00.x + pw0.x + p0h.x + pwh.x) / 4 - a * w / 2 - c * h / 2
        let ty = (p00.y + pw0.y + p0h.y + pwh.y) / 4 - b * w / 2 - d * h / 2
        return CGAffineTransform(a: a, b: b, c: c, d: d, tx: tx, ty: ty)
    }
}

/// A modifier that moves the view with a projection computed from its size (shake effects, …).
public protocol GeometryEffect: Animatable, ViewModifier where Body == Never {
    func effectValue(size: CGSize) -> ProjectionTransform
}
extension GeometryEffect {
    public func body(content: Content) -> Never { fatalError("GeometryEffect has no body") }
    public func ignoredByLayout() -> _IgnoredByLayoutEffect<Self> { _IgnoredByLayoutEffect(base: self) }
}
public struct _IgnoredByLayoutEffect<Base: GeometryEffect>: GeometryEffect {
    public var base: Base
    public func effectValue(size: CGSize) -> ProjectionTransform { base.effectValue(size: size) }
    public var animatableData: Base.AnimatableData { get { base.animatableData } set { base.animatableData = newValue } }
}

/// Called by ModifiedContent for GeometryEffect modifiers.
@MainActor func _geometryEffectNode(_ effect: any GeometryEffect, _ content: any View, _ ctx: _Context) -> _Node {
    let e = effect
    return _ProjectionNode(path: ctx.path, transform: { size in e.effectValue(size: size) }, child: _resolve(content, ctx.child("geo")))
}

/// Applies a transform (top-leading based, computed from the size) to the child's view; layout is unaffected.
final class _ProjectionNode: _WrapperNode {
    let transform: (CGSize) -> ProjectionTransform
    init(path: String, transform: @escaping (CGSize) -> ProjectionTransform, child: _Node) { self.transform = transform; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        let s = frame.size, p = transform(s)
        if p.isAffine {
            let m = p._affine(s)
            // UIKit transforms act about the view's center
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
        return v
    }
}

public struct _TransformEffect: GeometryEffect {
    public var transform: CGAffineTransform
    public func effectValue(size: CGSize) -> ProjectionTransform { ProjectionTransform(transform) }
}
public struct _ProjectionEffect: GeometryEffect {
    public var transform: ProjectionTransform
    public func effectValue(size: CGSize) -> ProjectionTransform { transform }
}
public struct _Rotation3DEffect: GeometryEffect {
    public var angle: Angle
    public var axis: (x: CGFloat, y: CGFloat, z: CGFloat)
    public var anchor: UnitPoint, anchorZ: CGFloat, perspective: CGFloat
    public var animatableData: AnimatablePair<Double, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(angle.radians, AnimatablePair(anchorZ, perspective)) }
        set { angle.radians = newValue.first; anchorZ = newValue.second.first; perspective = newValue.second.second }
    }
    public func effectValue(size: CGSize) -> ProjectionTransform {
        let len = (axis.x * axis.x + axis.y * axis.y + axis.z * axis.z).squareRoot()
        guard len > 0 else { return ProjectionTransform() }
        let x = axis.x / len, y = axis.y / len, z = axis.z / len
        let c = Foundation.cos(angle.radians), s = Foundation.sin(angle.radians), t = 1 - c
        // rotation matrix (column vectors), Rodrigues
        let r = [[t * x * x + c, t * x * y - s * z, t * x * z + s * y],
                 [t * x * y + s * z, t * y * y + c, t * y * z - s * x],
                 [t * x * z - s * y, t * y * z + s * x, t * z * z + c]]
        let ax = anchor.x * size.width, ay = anchor.y * size.height
        let depth = max(size.width, size.height) * 1.0
        func project(_ p: CGPoint) -> CGPoint {
            let v = [p.x - ax, p.y - ay, -anchorZ]
            let q = (0..<3).map { i in r[i][0] * v[0] + r[i][1] * v[1] + r[i][2] * v[2] }
            let qz = q[2] + anchorZ
            let w = perspective != 0 && depth > 0 ? max(0.05, 1 - qz * perspective / (2 * depth)) : 1
            return CGPoint(x: q[0] / w + ax, y: q[1] / w + ay)
        }
        // the projective transform (homography) sending the rect's corners to the projected corners
        let w = max(size.width, 1), h = max(size.height, 1)
        let p00 = project(.zero), pw0 = project(CGPoint(x: w, y: 0)), p0h = project(CGPoint(x: 0, y: h)), pwh = project(CGPoint(x: w, y: h))
        return ProjectionTransform._quad(w, h, p00, pw0, pwh, p0h)
    }
}

extension View {
    public func transformEffect(_ transform: CGAffineTransform) -> some View { modifier(_TransformEffect(transform: transform)) }
    public func projectionEffect(_ transform: ProjectionTransform) -> some View { modifier(_ProjectionEffect(transform: transform)) }
    public func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center,
                                 anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some View {
        modifier(_Rotation3DEffect(angle: angle, axis: axis, anchor: anchor, anchorZ: anchorZ, perspective: perspective))
    }
}
