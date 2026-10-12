// isim SwiftUI: coordinate spaces — `.coordinateSpace(name:)` / `.coordinateSpace(.named(_))`, frames in `.global`,
// `.local`, `.named` and `.scrollView` for GeometryReader, onGeometryChange and gestures.
// Frames come from the mounted views (like SwiftUI, they include offsets and other geometry effects of the views
// around). GeometryReader / onGeometryChange content laid out before its views exist reads the frame measured after
// the previous render; when a measurement changes the graph renders again (also while an enclosing scroll view
// scrolls, for frames that scrolling moves), like SwiftUI re-evaluating geometry readers.
import UIKit

// MARK: - Named spaces

final class _CoordinateSpaceNode: _WrapperNode {
    let name: AnyHashable
    init(path: String, name: AnyHashable, child: _Node) { self.name = name; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override var isSpacer: Bool { child.isSpacer }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUICoordinateSpaceView(frame: .zero) }
        v.spaceName = name
        return v
    }
}
/// The view of a named coordinate space.
final class _SUICoordinateSpaceView: _PassthroughViewBase { var spaceName: AnyHashable? }

extension View {
    public func coordinateSpace<T: Hashable>(name: T) -> some View {
        let n = AnyHashable(name)
        return _modify { ctx, c in _CoordinateSpaceNode(path: ctx.path, name: n, child: _resolve(c, ctx.child("cs"))) }
    }
    /// iOS 17: `.coordinateSpace(.named("..."))`.
    public func coordinateSpace(_ name: NamedCoordinateSpace) -> some View {
        let n = name.name
        return _modify { ctx, c in _CoordinateSpaceNode(path: ctx.path, name: n, child: _resolve(c, ctx.child("cs"))) }
    }
}

/// The view a coordinate space measures from: nil for the window (global).
@MainActor func _spaceView(_ v: UIView, _ space: CoordinateSpace) -> UIView? {
    switch space {
    case .local: return v
    case .global: return nil
    case .named(let name):
        var s = v.superview
        if name == AnyHashable("_isim.scrollView") {
            while let x = s, !(x is UIScrollView) { s = x.superview }
            return s
        }
        while let x = s { if let c = x as? _SUICoordinateSpaceView, c.spaceName == name { return c }; s = x.superview }
        return nil                                      // no such space around: like SwiftUI, the global one
    @unknown default: return nil
    }
}
/// A view's frame in a coordinate space (`rect` in the view's own coordinates, its bounds by default).
@MainActor func _liveFrame(_ v: UIView, _ space: CoordinateSpace, rect: CGRect? = nil) -> CGRect {
    let r = rect ?? CGRect(origin: .zero, size: v.bounds.size)
    if case .local = space { return r }
    let target = _spaceView(v, space)
    var f = v.convert(r, to: target)
    // a scroll view's space is its visible area (its bounds origin is the content offset)
    if let sv = target as? UIScrollView { f = f.offsetBy(dx: -sv.bounds.minX, dy: -sv.bounds.minY) }
    return f
}
@MainActor func _livePoint(_ p: CGPoint, in v: UIView, _ space: CoordinateSpace) -> CGPoint { _liveFrame(v, space, rect: CGRect(origin: p, size: .zero)).origin }

// MARK: - Geometry reads

func _spaceKey(_ s: CoordinateSpace) -> String {
    switch s {
    case .local: return "local"
    case .global: return "global"
    case .named(let n): return "named:\(n)"
    @unknown default: return "?"
    }
}
extension _Graph {
    /// A frame of the view of `viewKey` in `space`: as measured after the last render (or `fallback` before the view
    /// exists); the read is checked against the live views after this render.
    func geometryFrame(_ viewKey: String, _ space: CoordinateSpace, fallback: CGRect) -> CGRect {
        if case .local = space { return fallback }
        let key = viewKey + "|" + _spaceKey(space)
        geometryReads[key] = (viewKey, space)
        return geometryCache[key] ?? fallback
    }
    /// After a render: measures the frames read during it; renders again when one changed (at most a few times in a
    /// row, so content that moves with its own frame cannot loop).
    func verifyGeometry() {
        var changed = false
        var keep: [String: CGRect] = [:]
        for (key, (viewKey, space)) in geometryReads {
            guard let v = views[viewKey], v.window != nil else { if let c = geometryCache[key] { keep[key] = c }; continue }
            let f = _liveFrame(v, space)
            if let old = geometryCache[key], abs(old.minX - f.minX) < 0.5, abs(old.minY - f.minY) < 0.5, abs(old.width - f.width) < 0.5, abs(old.height - f.height) < 0.5 { keep[key] = old; continue }
            keep[key] = f; changed = true
        }
        geometryCache = keep
        if changed && geometryPasses < 3 { geometryPasses += 1; geometryPass = true; invalidate() } else if !changed { geometryPasses = 0 }
        installScrollGeometryObserver()
    }
    /// While a scroll view scrolls, frames measured across it move: check the reads inside it.
    func installScrollGeometryObserver() {
        guard scrollGeometryObserver == nil, !geometryReads.isEmpty else { return }
        scrollGeometryObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimScrollViewDidScroll"), object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            MainActor.assumeIsolated {
                guard let self, let sv = n.object as? UIView, !self.rendering else { return }
                for (key, (viewKey, space)) in self.geometryReads {
                    // (a space inside the scrolled content moves with the view; the scroll view's own space does not)
                    guard let v = self.views[viewKey], v.isDescendant(of: sv), _spaceView(v, space).map({ $0 === sv || !$0.isDescendant(of: sv) }) ?? true else { continue }
                    let f = _liveFrame(v, space)
                    if let old = self.geometryCache[key], abs(old.minX - f.minX) < 0.5 && abs(old.minY - f.minY) < 0.5 { continue }
                    self.geometryCache[key] = f
                    self.geometryPasses = 0
                    self.invalidate()
                }
            }
        })
    }
}
