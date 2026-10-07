// isim SwiftUI: navigation stack transitions and chrome.
// - Push / pop slide like UINavigationController (the new level comes in from the trailing edge, the old one moves a
//   third of the way out); a swipe from the leading screen edge drags the top level back (pop when released past a
//   third or flicked). Adapted: a pop animates a picture of the leaving level.
// - iOS 18 navigationTransition(.zoom(sourceID:in:)) grows the pushed level out of the view marked with
//   matchedTransitionSource(id:in:) and shrinks it back into it on pop; iOS 27 .crossFade fades.
// - navigationBarBackButtonHidden, toolbarRole(.editor) (back button without title), toolbarTitleMenu, bottom bars
//   (.bottomBar / .status), the keyboard bar (.keyboard) and toolbar(.hidden, for: .bottomBar).
import UIKit

enum _NavTransition: Equatable { case push, zoom(AnyHashable), crossFade }

/// The view of a NavigationStack: animates level changes and drives the edge-swipe back gesture.
final class _SUINavStackView: _PassthroughViewBase {
    var shownTop = -1
    var levelViews: [Int: UIView] = [:]
    var transitions: [Int: _NavTransition] = [:]
    var animating: Set<Int> = []
    var canPop = false
    var pop: (() -> Void)?
    weak var bar: _SUINavBar?
    /// toolbarMinimizationBehavior (iOS 27): the bottom bar slides away while the content scrolls (2 down, 3 up)
    weak var bottomBar: UIView?
    var minimizeBottom = 0, minimizeTop = 0
    private var lastScroll: [ObjectIdentifier: CGFloat] = [:]
    private var scrollObserver: NSObjectProtocol?
    private var edge: UIScreenEdgePanGestureRecognizer?
    private var dragOffset: CGFloat?
    override init(frame: CGRect) {
        super.init(frame: frame)
        let e = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(edgePanned(_:)))
        e.edges = .left
        addGestureRecognizer(e); edge = e
        scrollObserver = NotificationCenter.default.addObserver(forName: NSNotification.Name("_IsimScrollViewDidScroll"), object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            MainActor.assumeIsolated {
                guard let self, let sv = n.object as? UIScrollView, sv.isDescendant(of: self) else { return }
                self.scrolled(sv)
            }
        })
    }
    deinit { if let o = scrollObserver { NotificationCenter.default.removeObserver(o) } }
    func scrolled(_ sv: UIScrollView) {
        guard minimizeBottom >= 2 || minimizeTop >= 2 else { return }
        let id = ObjectIdentifier(sv), y = sv.contentOffset.y
        let dy = y - (lastScroll[id] ?? y)
        lastScroll[id] = y
        guard abs(dy) > 0.5, sv.isDragging || sv.isTracking else { return }
        if minimizeBottom >= 2, let bb = bottomBar {
            let hide = (minimizeBottom == 2) == (dy > 0) && y > 10
            let target = hide ? CGAffineTransform(translationX: 0, y: bb.bounds.height) : .identity
            if bb.transform != target { UIView.animate(withDuration: 0.25) { bb.transform = target } }
        }
        if minimizeTop >= 2, let b = bar {
            let hide = (minimizeTop == 2) == (dy > 0) && y > 10
            if (b.alpha < 0.5) != hide { UIView.animate(withDuration: 0.25) { b.alpha = hide ? 0 : 1 } }
        }
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool { g === edge ? canPop && shownTop > 0 : true }
    /// touches at the leading edge reach the edge-swipe recognizer even over empty content
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        if v == nil, canPop, shownTop > 0, point.x <= 20, point.y > (bar?.frame.maxY ?? 0), !isHidden, isUserInteractionEnabled { return self }
        return v
    }

    static let duration = 0.35
    func animatePush(from old: Int, to new: Int, _ kind: _NavTransition) {
        guard let nv = levelViews[new], let ov = levelViews[old] else { return }
        let W = bounds.width
        animating = [old, new]
        UIView.performWithoutAnimation {
            ov.isHidden = false; nv.isHidden = false
            switch kind {
            case .push: nv.transform = CGAffineTransform(translationX: W, y: 0)
            case .crossFade: nv.alpha = 0
            case .zoom(let key):
                let src = _ZoomSources.frame(key, in: self) ?? CGRect(x: bounds.midX - 40, y: bounds.midY - 40, width: 80, height: 80)
                nv.transform = _zoomTransform(from: bounds, to: src); nv.layer.cornerRadius = 40; nv.clipsToBounds = true; nv.alpha = 0.4
            }
        }
        UIView.animate(withDuration: Self.duration, delay: 0, options: [.curveEaseOut], animations: {
            switch kind {
            case .push: nv.transform = .identity; ov.transform = CGAffineTransform(translationX: -W * 0.3, y: 0)
            case .crossFade: nv.alpha = 1
            case .zoom: nv.transform = .identity; nv.layer.cornerRadius = 0; nv.alpha = 1; ov.alpha = 0.6
            }
        }, completion: { [weak self] _ in
            guard let self else { return }
            ov.transform = .identity; ov.alpha = 1
            nv.clipsToBounds = false
            if self.shownTop != old { ov.isHidden = true }
            self.animating.subtract([old, new])
        })
    }
    func animatePop(_ snap: UIView, to new: Int, _ kind: _NavTransition) {
        guard let nv = levelViews[new] else { return }
        let W = bounds.width
        if let b = bar { insertSubview(snap, belowSubview: b) } else { addSubview(snap) }
        snap.isUserInteractionEnabled = false
        animating.insert(new)
        let dragged = dragOffset
        dragOffset = nil
        UIView.performWithoutAnimation {
            nv.isHidden = false
            if case .push = kind { nv.transform = CGAffineTransform(translationX: dragged.map { -W * 0.3 + 0.3 * $0 } ?? -W * 0.3, y: 0) }
        }
        UIView.animate(withDuration: dragged != nil ? 0.22 : Self.duration, delay: 0, options: [.curveEaseOut], animations: {
            switch kind {
            case .push: snap.frame.origin.x = W; nv.transform = .identity
            case .crossFade: snap.alpha = 0
            case .zoom(let key):
                let src = _ZoomSources.frame(key, in: self) ?? CGRect(x: self.bounds.midX - 40, y: self.bounds.midY - 40, width: 80, height: 80)
                snap.transform = _zoomTransform(from: snap.frame, to: src); snap.alpha = 0
            }
        }, completion: { [weak self] _ in
            snap.removeFromSuperview()
            self?.animating.remove(new)
        })
    }
    @objc func edgePanned(_ g: UIScreenEdgePanGestureRecognizer) {
        let top = shownTop
        guard canPop, top > 0, let tv = levelViews[top], let bv = levelViews[top - 1] else { return }
        let W = bounds.width, dx = max(0, min(W, g.translation(in: self).x))
        switch g.state {
        case .began:
            animating = [top, top - 1]
            UIView.performWithoutAnimation { bv.isHidden = false; bv.transform = CGAffineTransform(translationX: -W * 0.3, y: 0) }
        case .changed:
            UIView.performWithoutAnimation { tv.transform = CGAffineTransform(translationX: dx, y: 0); bv.transform = CGAffineTransform(translationX: -W * 0.3 + 0.3 * dx, y: 0) }
        case .ended, .cancelled:
            if g.state == .ended && (dx > W / 3 || g.velocity(in: self).x > 500) {
                dragOffset = dx
                animating = [top - 1]
                transitions[top] = .push                 // a dragged level leaves sideways whatever pushed it
                pop?()
            } else {
                UIView.animate(withDuration: 0.25, animations: { tv.transform = .identity; bv.transform = CGAffineTransform(translationX: -W * 0.3, y: 0) }, completion: { [weak self] _ in
                    bv.isHidden = true; bv.transform = .identity
                    self?.animating.removeAll()
                })
            }
        default: break
        }
    }
}

/// The transform that shows a view of frame `a` (in its superview) at frame `b`.
func _zoomTransform(from a: CGRect, to b: CGRect) -> CGAffineTransform {
    guard a.width > 0, a.height > 0 else { return .identity }
    let s = max(b.width / a.width, b.height / a.height)
    return CGAffineTransform(translationX: b.midX - a.midX, y: b.midY - a.midY).scaledBy(x: s, y: s)
}

/// matchedTransitionSource views by namespace + id (the zoom transitions' source frames).
@MainActor enum _ZoomSources {
    final class Ref { weak var view: UIView? }
    static var views: [AnyHashable: Ref] = [:]
    static func key(_ id: AnyHashable, _ ns: Namespace.ID) -> AnyHashable { AnyHashable("\(ns.value)|\(id)") }
    static func frame(_ key: AnyHashable, in v: UIView) -> CGRect? {
        guard let s = views[key]?.view, s.window != nil, s.window === v.window else { return nil }
        return s.convert(s.bounds, to: v)
    }
}
final class _ZoomSourceNode: _WrapperNode {
    let key: AnyHashable
    init(path: String, key: AnyHashable, child: _Node) { self.key = key; super.init(path: path, child: child) }
    override var layoutPriority: Double { child.layoutPriority }
    override func sizeThatFits(_ p: _Proposal) -> CGSize { child.sizeThatFits(p) }
    override func place(_ rect: CGRect) { frame = rect; child.place(CGRect(origin: .zero, size: rect.size)) }
    override func mountView(_ g: _Graph) -> UIView {
        let v = g.view(viewKey) { _PassthroughView() }
        let r = _ZoomSources.views[key] ?? _ZoomSources.Ref()
        r.view = v; _ZoomSources.views[key] = r
        return v
    }
}

// MARK: - Bottom bar, keyboard bar

/// The bottom toolbar (.bottomBar / .status items): material with a hairline (iOS 26+: a scroll-edge fade).
final class _SUIBottomBar: _PassthroughViewBase {
    let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    let hairline = UIView(), fade = _SUIEdgeFadeView(frame: .zero)
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backdrop); addSubview(fade); addSubview(hairline)
        hairline.backgroundColor = .separator
        fade.fromBottom = true
        accessibilityIdentifier = "isim-bottom-bar"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    /// edge: scrollEdgeEffectStyle for the bottom edge (1 hard: an opaque bar, 3 hidden)
    func configure(background: UIColor?, edge: Int = 0) {
        backdrop.frame = bounds; fade.frame = bounds
        hairline.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
        let glass = _isimGlassLook && background == nil && edge != 1
        backdrop.isHidden = glass || background != nil; hairline.isHidden = glass; fade.isHidden = !glass || edge == 3
        backgroundColor = background
        fade.setNeedsDisplay()
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, self.point(inside: point, with: event) else { return nil }
        return super.hitTest(point, with: event) ?? self                  // the bar takes the touches over it
    }
}
/// The keyboard toolbar (.keyboard items): a bar sitting on the keyboard while it is shown.
final class _SUIKeyboardBar: _PassthroughViewBase {
    let backdrop = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial)), hairline = UIView()
    private var observer: NSObjectProtocol?
    static var keyboardTop: CGFloat?                  // window y of the keyboard's top (nil: no keyboard)
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(backdrop); addSubview(hairline); hairline.backgroundColor = .separator
        accessibilityIdentifier = "isim-keyboard-bar"
        observer = NotificationCenter.default.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: nil, using: { [weak self] (n: NSNotification) in
            let end = (n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? .zero
            MainActor.assumeIsolated {
                _SUIKeyboardBar.keyboardTop = end.isEmpty || end.minY >= UIScreen.main.bounds.height ? nil : end.minY
                self?.place()
            }
        })
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }
    func place() {
        guard let sup = superview else { return }
        guard let top = Self.keyboardTop else { isHidden = true; return }
        isHidden = false
        let y = sup.convert(CGPoint(x: 0, y: top), from: nil).y
        frame = CGRect(x: 0, y: y - 44, width: sup.bounds.width, height: 44)
        backdrop.frame = bounds; hairline.frame = CGRect(x: 0, y: 0, width: bounds.width, height: 0.5)
    }
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard !isHidden, self.point(inside: point, with: event) else { return nil }
        return super.hitTest(point, with: event) ?? self
    }
}

// MARK: - Modifiers

extension View {
    /// Hides the back button (and the edge swipe back), e.g. for a custom one.
    public func navigationBarBackButtonHidden(_ hidden: Bool = true) -> some View {
        _modify { ctx, c in if hidden { ctx.nav?.backHidden = true }; return _resolve(c, ctx.child("bbh")) }
    }
    /// A menu from the navigation title (a chevron after the title; tap to open).
    public func toolbarTitleMenu<C: View>(@ViewBuilder content: () -> C) -> some View {
        let items = content()
        return _modify { ctx, c in
            if let lv = ctx.nav {
                let node = _resolve(items, ctx.child("titlemenu").with { $0._inList = false })
                lv.titleMenu = { UIMenu(title: "", children: _menuElements(node)) }
            }
            return _resolve(c, ctx.child("ttm"))
        }
    }
    /// `.editor` / `.browser`: the back button shows only the chevron (iPhone).
    public func toolbarRole(_ role: ToolbarRole) -> some View {
        _modify { ctx, c in ctx.nav?.role = role.id; return _resolve(c, ctx.child("trole")) }
    }
    /// How this view comes in when pushed (or presented): `.zoom(sourceID:in:)` grows it out of the matching
    /// matchedTransitionSource view, `.crossFade` fades it in; `.automatic` slides.
    @available(iOS 18.0, *)
    public func navigationTransition<T: NavigationTransition>(_ style: T) -> some View {
        var kind: _NavTransition = (style as? ZoomNavigationTransition).flatMap { $0.key.map { .zoom($0) } } ?? .push
        if #available(iOS 27.0, *), style is CrossFadeNavigationTransition { kind = .crossFade }
        return _modify { ctx, c in
            if let lv = ctx.nav { lv.transition = kind } else { ctx.environment._presentationTransition?.kind = kind }
            return _resolve(c, ctx.child("ntr"))
        }
    }
    /// Marks the view a zoom transition with the same id grows out of (and shrinks back into).
    @available(iOS 18.0, *)
    public func matchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View {
        let key = _ZoomSources.key(AnyHashable(id), namespace)
        return _modify { ctx, c in _ZoomSourceNode(path: ctx.path, key: key, child: _resolve(c, ctx.child("mts"))) }
    }
    @available(iOS 18.0, *)
    public func matchedTransitionSource<ID: Hashable>(id: ID, in namespace: Namespace.ID, configuration: (EmptyMatchedTransitionSourceConfiguration) -> some MatchedTransitionSourceConfiguration) -> some View {
        matchedTransitionSource(id: id, in: namespace)
    }
}
@available(iOS 18.0, *)
public protocol MatchedTransitionSourceConfiguration: Sendable {}
@available(iOS 18.0, *)
public struct EmptyMatchedTransitionSourceConfiguration: MatchedTransitionSourceConfiguration {
    public init() {}
    public func background(_ style: some ShapeStyle) -> EmptyMatchedTransitionSourceConfiguration { self }
    public func clipShape(_ shape: RoundedRectangle) -> EmptyMatchedTransitionSourceConfiguration { self }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> EmptyMatchedTransitionSourceConfiguration { self }
}

/// The presented content's transition (sheets / full-screen covers): set by navigationTransition inside it.
@MainActor final class _PresentationTransition { var kind: _NavTransition = .push }
struct _PresentationTransitionKey: EnvironmentKey { static var defaultValue: _PresentationTransition? { nil } }
extension EnvironmentValues {
    var _presentationTransition: _PresentationTransition? { get { self[_PresentationTransitionKey.self] } set { self[_PresentationTransitionKey.self] = newValue } }
}
