// isim SwiftUI: the focus system for views that are not text fields, and what follows focus.
//  - `.focusable()` views become the first responder (tap them, Tab to them, or set their `.focused` binding) and show a
//    focus ring (`.focusEffectDisabled()` hides it); text fields take part too.
//  - Tab / Shift-Tab move focus between the focusable views and text fields on screen, in reading order; the items of a
//    `.focusSection()` stay together.
//  - `@FocusedValue` sees the `.focusedValue`s of the focused view and its ancestors (the innermost wins) and the
//    `.focusedSceneValue`s of the scene; `.onKeyPress` handlers on the focused view and its ancestors get the key presses
//    (innermost first).
import UIKit

/// A view that takes part in focus: its node path (what focused values and key presses compare with) and graph.
@MainActor protocol _FocusParticipant: UIView {
    var _focusPath: String? { get }
    var _focusGraph: _Graph? { get }
}
extension _SUITextField: _FocusParticipant {
    var _focusPath: String? { node?.path }
    var _focusGraph: _Graph? { node?.graph }
}

@MainActor enum _FocusEngine {
    /// The focused view (the first responder among focus participants) of the key window.
    static func focused() -> (any _FocusParticipant)? {
        func find(_ v: UIView) -> (any _FocusParticipant)? {
            if let p = v as? any _FocusParticipant, v.isFirstResponder { return p }
            for s in v.subviews { if let f = find(s) { return f } }
            return nil
        }
        var windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        windows += UIApplication.shared.windows.filter { w in !windows.contains { $0 === w } }
        for w in windows where w.isKeyWindow { if let f = find(w) { return f } }
        for w in windows where !w.isHidden { if let f = find(w) { return f } }
        return nil
    }
    /// The focused node's path when it belongs to graph `g`.
    static func focusedPath(in g: _Graph) -> String? {
        guard let f = focused(), f._focusGraph === g else { return nil }
        return f._focusPath
    }
    /// Focus moved: focused values are worked out again.
    static func changed() {
        DispatchQueue.main.async { MainActor.assumeIsolated { _FocusedStore.shared.recompute() } }
    }
    /// Tab / Shift-Tab: the next focusable view or text field in reading order (sections stay together).
    static func advance(in root: UIView, backwards: Bool) -> Bool {
        var items: [(view: UIView, section: CGRect?, frame: CGRect)] = []
        func walk(_ v: UIView, _ section: CGRect?) {
            if v.isHidden || v.alpha < 0.01 { return }
            var sec = section
            if v is _SUIFocusSectionView { sec = v.convert(v.bounds, to: nil) }
            if let f = v as? _SUIFocusableView, f.isFocusable { items.append((v, sec, v.convert(v.bounds, to: nil))) }
            else if v is _SUITextField, v.isUserInteractionEnabled { items.append((v, sec, v.convert(v.bounds, to: nil))) }
            for s in v.subviews { walk(s, sec) }
        }
        walk(root, nil)
        guard !items.isEmpty else { return false }
        // reading order: by section (its top-left), then top to bottom, left to right
        func key(_ i: (view: UIView, section: CGRect?, frame: CGRect)) -> (CGFloat, CGFloat, CGFloat, CGFloat) {
            let s = i.section ?? i.frame
            return (s.minY.rounded(), s.minX.rounded(), i.frame.minY.rounded(), i.frame.minX.rounded())
        }
        let ordered = items.sorted { key($0) < key($1) }.map(\.view)
        let cur = ordered.firstIndex { $0.isFirstResponder }
        let next: Int
        if let c = cur { next = (c + (backwards ? ordered.count - 1 : 1)) % ordered.count } else { next = backwards ? ordered.count - 1 : 0 }
        return ordered[next].becomeFirstResponder()
    }
}

// MARK: - focusable

struct _FocusEffectDisabledKey: EnvironmentKey { static var defaultValue: Bool { false } }
extension EnvironmentValues {
    var _focusEffectDisabled: Bool { get { self[_FocusEffectDisabledKey.self] } set { self[_FocusEffectDisabledKey.self] = newValue } }
}
extension View {
    /// A view that can take focus (tap it, Tab to it, or set its `.focused` binding).
    public func focusable(_ isFocusable: Bool = true) -> some View { focusable(isFocusable, interactions: .automatic) }
    public func focusable(_ isFocusable: Bool = true, interactions: FocusInteractions) -> some View {
        _modify { ctx, c in
            _FocusableNode(path: ctx.path, focusable: isFocusable, ring: !ctx.environment._focusEffectDisabled,
                           tint: (ctx.environment._tint ?? .accentColor).uiColor, link: ctx.graph.focusLink(for: ctx.path),
                           graph: ctx.graph, child: _resolve(c, ctx.child("focusable")))
        }
    }
    /// Keeps the focus ring off this view and the focusable views inside it.
    public func focusEffectDisabled(_ disabled: Bool = true) -> some View { environment(\._focusEffectDisabled, disabled) }
    /// The focusable views inside stay together when Tab moves focus.
    public func focusSection() -> some View {
        _modify { ctx, c in _FocusSectionNode(path: ctx.path, child: _resolve(c, ctx.child("fsection"))) }
    }
}

final class _FocusableNode: _WrapperNode {
    let focusable: Bool, ring: Bool, tint: UIColor, link: _FocusLink?
    weak var graph: _Graph?
    init(path: String, focusable: Bool, ring: Bool, tint: UIColor, link: _FocusLink?, graph: _Graph, child: _Node) {
        self.focusable = focusable; self.ring = ring; self.tint = tint; self.link = link; self.graph = graph
        super.init(path: path, child: child)
    }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _SUIFocusableView() }
        v.node = self
        v.isFocusable = focusable
        if !focusable && v.isFirstResponder { _ = v.resignFirstResponder() }
        if let link {
            let want = link.get()
            g.postRender.append { [weak v] in
                guard let v else { return }
                if want && !v.isFirstResponder { _ = v.becomeFirstResponder() }
                else if !want && v.isFirstResponder { _ = v.resignFirstResponder() }
            }
        }
        v.updateRing()
        return v
    }
}
/// A focusable view: the first responder while focused, with a focus ring around it.
final class _SUIFocusableView: _PassthroughViewBase, _FocusParticipant {
    var node: _FocusableNode?             // (the latest render's; nodes are rebuilt on each)
    var isFocusable = true
    let ring = CALayer()
    var _focusPath: String? { node?.path }
    var _focusGraph: _Graph? { node?.graph }
    override init(frame: CGRect) {
        super.init(frame: frame)
        ring.borderWidth = 3; ring.cornerRadius = 8; ring.isHidden = true
        layer.addSublayer(ring)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func tapped() { if isFocusable && !isFirstResponder { _ = becomeFirstResponder() } }
    override var canBecomeFirstResponder: Bool { isFocusable }
    override func becomeFirstResponder() -> Bool {
        let ok = super.becomeFirstResponder()
        if ok { node?.link.map { if !$0.get() { $0.set(true) } }; updateRing(); _FocusEngine.changed() }
        return ok
    }
    override func resignFirstResponder() -> Bool {
        let ok = super.resignFirstResponder()
        if ok { node?.link.map { if $0.get() { $0.set(false) } }; updateRing(); _FocusEngine.changed() }
        return ok
    }
    /// the whole frame takes taps (to focus it), its content its own touches
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if let v = super.hitTest(point, with: event) { return v }
        return isFocusable && !isHidden && bounds.contains(point) ? self : nil
    }
    func updateRing() {
        ring.isHidden = !(isFirstResponder && (node?.ring ?? true))
        ring.borderColor = (node?.tint ?? .systemBlue).cgColor
        ring.frame = bounds.insetBy(dx: -4, dy: -4)
    }
    override func layoutSubviews() { super.layoutSubviews(); updateRing() }
}

final class _FocusSectionNode: _WrapperNode {
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView { g.view(viewKey) { _SUIFocusSectionView() } }
}
final class _SUIFocusSectionView: _PassthroughViewBase {}
