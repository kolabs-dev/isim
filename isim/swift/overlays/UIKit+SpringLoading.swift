// isim UIKit overlay: spring-loaded interactions (self-authored). While a drag (UIKit+DragDrop.swift) rests over a
// view with a UISpringLoadedInteraction, the interaction goes possible -> activating (after 0.4 s) -> activated
// (after 0.8 s: the activation handler runs; the default effect blinks the view), then finishes; moving away or
// ending the drag resets it. Buttons, segmented controls, table and collection views, bar button items, tab bars
// and alert controllers adopt UISpringLoadedInteractionSupporting (isSpringLoaded).
import ObjectiveC

@objc public enum UISpringLoadedInteractionEffectState: Int, Sendable { case inactive = 0, possible, activating, activated }

@MainActor public protocol UISpringLoadedInteractionContext: NSObjectProtocol {
    var state: UISpringLoadedInteractionEffectState { get }
    var targetView: UIView? { get set }
    var targetItem: Any? { get set }
    func location(in view: UIView?) -> CGPoint
}
@MainActor public protocol UISpringLoadedInteractionBehavior: NSObjectProtocol {
    func shouldAllow(_ interaction: UISpringLoadedInteraction, with context: UISpringLoadedInteractionContext) -> Bool
    func interactionDidFinish(_ interaction: UISpringLoadedInteraction)
}
extension UISpringLoadedInteractionBehavior {
    public func interactionDidFinish(_ interaction: UISpringLoadedInteraction) {}
}
@MainActor public protocol UISpringLoadedInteractionEffect: NSObjectProtocol {
    func interaction(_ interaction: UISpringLoadedInteraction, didChangeWith context: UISpringLoadedInteractionContext)
}
@MainActor public protocol UISpringLoadedInteractionSupporting: NSObjectProtocol {
    var isSpringLoaded: Bool { get set }
}

@MainActor final class _IsimSpringContext: NSObject, UISpringLoadedInteractionContext {
    var state: UISpringLoadedInteractionEffectState = .inactive
    weak var targetView: UIView?
    var targetItem: Any?
    var windowPoint = CGPoint.zero
    weak var window: UIWindow?
    func location(in view: UIView?) -> CGPoint { view.map { $0.convert(windowPoint, from: window) } ?? windowPoint }
}
/// the default behaviour: always allowed
@MainActor final class _IsimSpringBehavior: NSObject, UISpringLoadedInteractionBehavior {
    func shouldAllow(_ interaction: UISpringLoadedInteraction, with context: UISpringLoadedInteractionContext) -> Bool { true }
}
/// the default effect: the target dims while activating and blinks when activated
@MainActor final class _IsimSpringBlinkEffect: NSObject, UISpringLoadedInteractionEffect {
    func interaction(_ interaction: UISpringLoadedInteraction, didChangeWith context: UISpringLoadedInteractionContext) {
        guard let v = context.targetView ?? interaction.view else { return }
        switch context.state {
        case .activating: UIView.animate(withDuration: 0.15) { v.alpha = 0.6 }
        case .activated:
            UIView.animate(withDuration: 0.1, animations: { v.alpha = 0.3 }, completion: { _ in UIView.animate(withDuration: 0.1) { v.alpha = 1 } })
        default: v.alpha = 1
        }
    }
}

@MainActor open class UISpringLoadedInteraction: NSObject, UIInteraction {
    public let interactionBehavior: UISpringLoadedInteractionBehavior
    public let interactionEffect: UISpringLoadedInteractionEffect
    open private(set) weak var view: UIView?
    let handler: (UISpringLoadedInteraction, UISpringLoadedInteractionContext) -> Void
    public init(interactionBehavior: UISpringLoadedInteractionBehavior?, interactionEffect: UISpringLoadedInteractionEffect?,
                activationHandler handler: @escaping (UISpringLoadedInteraction, UISpringLoadedInteractionContext) -> Void) {
        self.interactionBehavior = interactionBehavior ?? _IsimSpringBehavior()
        self.interactionEffect = interactionEffect ?? _IsimSpringBlinkEffect()
        self.handler = handler
    }
    public convenience init(activationHandler handler: @escaping (UISpringLoadedInteraction, UISpringLoadedInteractionContext) -> Void) {
        self.init(interactionBehavior: nil, interactionEffect: nil, activationHandler: handler)
    }
    open func willMove(to view: UIView?) {}
    open func didMove(to view: UIView?) { self.view = view }
}

/// the spring loading in progress: the interaction under the drag and its timers
@MainActor enum _IsimSpringLoading {
    static weak var current: UISpringLoadedInteraction?
    static var context = _IsimSpringContext()
    static var generation = 0
    static func set(_ i: UISpringLoadedInteraction, _ s: UISpringLoadedInteractionEffectState) {
        context.state = s
        i.interactionEffect.interaction(i, didChangeWith: context)
    }
    /// the drag moved to a point (window coordinates)
    static func update(at p: CGPoint, in w: UIWindow?) {
        context.windowPoint = p; context.window = w
        var found: UISpringLoadedInteraction?
        if let w, let hit = w.hitTest(p, with: nil) {
            var v: UIView? = hit
            while let x = v, found == nil { found = x.interactions.compactMap { $0 as? UISpringLoadedInteraction }.first; v = x.superview }
        }
        if found === current { return }
        cancel()
        guard let i = found, i.interactionBehavior.shouldAllow(i, with: context) else { return }
        current = i; context.targetView = i.view; context.targetItem = nil
        set(i, .possible)
        generation += 1
        let g = generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            MainActor.assumeIsolated {
                guard g == generation, let i = current else { return }
                set(i, .activating)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    MainActor.assumeIsolated {
                        guard g == generation, let i = current, i.interactionBehavior.shouldAllow(i, with: context) else { return }
                        set(i, .activated)
                        print("isim: spring-loaded \(i.view.map { String(describing: type(of: $0)) } ?? "view") activated")
                        i.handler(i, context)
                        i.interactionBehavior.interactionDidFinish(i)
                        generation += 1
                    }
                }
            }
        }
    }
    static func cancel() {
        generation += 1
        if let i = current { set(i, .inactive); i.interactionBehavior.interactionDidFinish(i) }
        current = nil
        context = _IsimSpringContext()
    }
}

// MARK: - spring-loaded controls
nonisolated(unsafe) private var kSpringLoaded: UInt8 = 0
@MainActor private func _isimSetSpringLoaded(_ v: UIView, _ on: Bool, activate: @escaping (UIView, CGPoint) -> Void) {
    for i in v.interactions where i is UISpringLoadedInteraction { v.removeInteraction(i) }
    objc_setAssociatedObject(v, &kSpringLoaded, on, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    if on { v.addInteraction(UISpringLoadedInteraction { i, ctx in if let view = i.view { activate(view, ctx.location(in: view)) } }) }
}
extension UIButton: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set { _isimSetSpringLoaded(self, newValue) { v, _ in (v as? UIButton)?.sendActions(for: .touchUpInside) } }
    }
}
extension UISegmentedControl: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set {
            _isimSetSpringLoaded(self, newValue) { v, p in
                guard let s = v as? UISegmentedControl, s.numberOfSegments > 0, s.bounds.width > 0 else { return }
                let i = min(s.numberOfSegments - 1, max(0, Int(p.x / (s.bounds.width / CGFloat(s.numberOfSegments)))))
                s.selectedSegmentIndex = i; s.sendActions(for: .valueChanged)
            }
        }
    }
}
extension UITableView: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set {
            _isimSetSpringLoaded(self, newValue) { v, p in
                guard let t = v as? UITableView, let ip = t.indexPathForRow(at: p) else { return }
                t.selectRow(at: ip, animated: true, scrollPosition: .none); t.delegate?.tableView?(t, didSelectRowAt: ip)
            }
        }
    }
}
extension UICollectionView: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set {
            _isimSetSpringLoaded(self, newValue) { v, p in
                guard let c = v as? UICollectionView, let ip = c.indexPathForItem(at: p) else { return }
                c.selectItem(at: ip, animated: true, scrollPosition: []); c.delegate?.collectionView?(c, didSelectItemAt: ip)
            }
        }
    }
}
/// these keep the flag (isim's bars and alerts are not drop-through targets)
extension UIBarButtonItem: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &kSpringLoaded, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
extension UITabBar: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &kSpringLoaded, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
extension UIAlertController: UISpringLoadedInteractionSupporting {
    public var isSpringLoaded: Bool {
        get { (objc_getAssociatedObject(self, &kSpringLoaded) as? Bool) ?? false }
        set { objc_setAssociatedObject(self, &kSpringLoaded, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
