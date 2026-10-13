// Sample: the last UIKit rows of #188, each logged with "kf".
// - Scroll events: a trackpad or mouse wheel (script `scroll`) scrolls a scroll view; a pan whose
//   allowedScrollTypesMask takes only wheel steps
// - Apple Pencil estimated properties and touchesEstimatedPropertiesUpdated
// - hasAmbiguousLayout / exerciseAmbiguityInLayout
// - a bar button group collapsing into its representative item when the bar has no room
// - key commands: applicationShouldAutomaticallyLocalizeKeyCommands and arrow mirroring right to left
// - NSTextViewportLayoutController rendering surfaces (iOS 27): made, cached and retrieved
import UIKit

func log(_ s: String) { print("kf \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: FinalViewController())
        window?.makeKeyAndVisible()
        return true
    }
    func applicationShouldAutomaticallyLocalizeKeyCommands(_ application: UIApplication) -> Bool {
        let on = ProcessInfo.processInfo.environment["HELLO_LOCALIZE"] != "0"
        log("asked to localize key commands: \(on)")
        return on
    }
}

/// a Pencil canvas: estimated force and angles, then their updates
final class PencilView: UIView {
    var pending: [NSNumber: CGFloat] = [:]
    var loggedEstimate = false, loggedUpdate = false
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) { note(touches) }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) { note(touches) }
    func note(_ touches: Set<UITouch>) {
        for t in touches where t.type == .pencil {
            if let i = t.estimationUpdateIndex { pending[i] = t.force }
            if !loggedEstimate {
                loggedEstimate = true
                log("pencil estimated \(t.estimatedProperties.rawValue) expecting \(t.estimatedPropertiesExpectingUpdates.rawValue) index \(t.estimationUpdateIndex != nil)")
            }
        }
    }
    override func touchesEstimatedPropertiesUpdated(_ touches: Set<UITouch>) {
        for t in touches {
            guard let i = t.estimationUpdateIndex, pending.removeValue(forKey: i) != nil else { continue }
            if !loggedUpdate { loggedUpdate = true; log("pencil updated expecting \(t.estimatedPropertiesExpectingUpdates.rawValue) force \(String(format: "%.1f", t.force))") }
            if pending.isEmpty { log("pencil all estimates updated") }
        }
    }
}

/// a layer drawing one layout fragment
final class SurfaceLayer: CALayer, NSTextViewportRenderingSurface {}

/// a text view drawing its fragments into cached surfaces (layers) through the viewport controller
final class SurfaceTextView: UIView, NSTextViewportLayoutControllerDelegate {
    let content = NSTextContentStorage(), manager = NSTextLayoutManager(), container = NSTextContainer(size: CGSize(width: 300, height: 0))
    var offset: CGFloat = 0
    var cache: [ObjectIdentifier: SurfaceLayer] = [:]
    var made = 0, cached = 0, retrieved = 0
    override init(frame: CGRect) {
        super.init(frame: frame)
        content.addTextLayoutManager(manager); manager.textContainer = container
        content.attributedString = NSAttributedString(string: (1...60).map { "Paragraph \($0)" }.joined(separator: "\n"),
                                                      attributes: [.font: UIFont.systemFont(ofSize: 17)])
        manager.textViewportLayoutController.delegate = self
        clipsToBounds = true
    }
    required init?(coder: NSCoder) { fatalError() }
    func scrollTo(_ y: CGFloat) {
        offset = y
        made = 0; cached = 0; retrieved = 0
        manager.textViewportLayoutController.layoutViewport()
        log("viewport made \(made) cached \(cached) retrieved \(retrieved)")
    }
    func viewportBounds(for c: NSTextViewportLayoutController) -> CGRect { CGRect(x: 0, y: offset, width: bounds.width, height: bounds.height) }
    func textViewportLayoutController(_ c: NSTextViewportLayoutController, configureRenderingSurfaceFor f: NSTextLayoutFragment) {
        guard #available(iOS 27.0, *), let layer = c.renderingSurface(for: f) as? CALayer else { return }
        layer.frame = f.layoutFragmentFrame.offsetBy(dx: 0, dy: -offset)
        if layer.superlayer == nil { self.layer.addSublayer(layer) }
    }
    @available(iOS 27.0, *)
    func textViewportLayoutController(_ c: NSTextViewportLayoutController, renderingSurfaceFor f: NSTextLayoutFragment) -> (any NSTextViewportRenderingSurface)? {
        made += 1
        let l = SurfaceLayer(); l.backgroundColor = UIColor.systemTeal.withAlphaComponent(0.2).cgColor
        return l
    }
    @available(iOS 27.0, *)
    func textViewportLayoutController(_ c: NSTextViewportLayoutController, cacheRenderingSurface s: any NSTextViewportRenderingSurface, for key: any NSTextViewportRenderingSurfaceKey) {
        cached += 1
        if let l = s as? SurfaceLayer { l.removeFromSuperlayer(); cache[ObjectIdentifier(key as AnyObject)] = l }
    }
    @available(iOS 27.0, *)
    func textViewportLayoutController(_ c: NSTextViewportLayoutController, retrieveCachedRenderingSurfaceFor key: any NSTextViewportRenderingSurfaceKey) -> (any NSTextViewportRenderingSurface)? {
        guard let l = cache.removeValue(forKey: ObjectIdentifier(key as AnyObject)) else { return nil }
        retrieved += 1
        return l
    }
}

final class FinalViewController: UIViewController, UIScrollViewDelegate {
    let scroller = UIScrollView(), wheelPad = UIView(), pencil = PencilView(), surfaces = SurfaceTextView(frame: .zero)
    let amb = UIView(), pinned = UIView()

    override var keyCommands: [UIKeyCommand]? {
        [UIKeyCommand(title: "Previous", action: #selector(previous), input: UIKeyCommand.inputLeftArrow)]
    }
    override var canBecomeFirstResponder: Bool { true }
    @objc func previous() { log("key command previous") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "Final"
        // a group of trailing items that does not fit: it collapses into its representative item
        let items = ["a", "b", "c", "d", "e", "f"].map { name in
            UIBarButtonItem(title: name.uppercased(), primaryAction: UIAction(title: name.uppercased()) { _ in log("group item \(name)") })
        }
        let rep = UIBarButtonItem(title: "Tools", style: .plain, target: nil, action: nil); rep.accessibilityIdentifier = "tools"
        navigationItem.trailingItemGroups = [UIBarButtonItemGroup(barButtonItems: items + [
            UIBarButtonItem(title: "Remaining", primaryAction: UIAction(title: "Remaining") { _ in })], representativeItem: rep)]

        scroller.frame = CGRect(x: 20, y: 110, width: 200, height: 200); scroller.accessibilityIdentifier = "scroller"
        scroller.contentSize = CGSize(width: 200, height: 2000); scroller.backgroundColor = .secondarySystemBackground; scroller.delegate = self
        for i in 0..<20 { let l = UILabel(frame: CGRect(x: 10, y: i * 100, width: 180, height: 40)); l.text = "Row \(i)"; scroller.addSubview(l) }
        wheelPad.frame = CGRect(x: 240, y: 110, width: 130, height: 90); wheelPad.backgroundColor = .systemYellow; wheelPad.accessibilityIdentifier = "wheelpad"
        let pan = UIPanGestureRecognizer(target: self, action: #selector(wheelPan(_:)))
        pan.allowedScrollTypesMask = .discrete
        wheelPad.addGestureRecognizer(pan)
        pencil.frame = CGRect(x: 240, y: 220, width: 130, height: 90); pencil.backgroundColor = .systemMint; pencil.accessibilityIdentifier = "pencil"
        surfaces.frame = CGRect(x: 20, y: 330, width: 300, height: 120); surfaces.backgroundColor = .tertiarySystemBackground
        let down = UIButton(type: .system, primaryAction: UIAction(title: "Text down") { [weak self] _ in self?.surfaces.scrollTo(600) })
        let up = UIButton(type: .system, primaryAction: UIAction(title: "Text up") { [weak self] _ in self?.surfaces.scrollTo(0) })
        down.frame = CGRect(x: 200, y: 470, width: 90, height: 40); down.accessibilityIdentifier = "textdown"
        up.frame = CGRect(x: 290, y: 470, width: 90, height: 40); up.accessibilityIdentifier = "textup"
        for v in [scroller, wheelPad, pencil, surfaces, amb, pinned, down, up] { view.addSubview(v) }

        // Auto Layout: one view without a height (ambiguous), one fully pinned
        for v in [amb, pinned] { v.translatesAutoresizingMaskIntoConstraints = false; v.backgroundColor = .systemPurple }
        NSLayoutConstraint.activate([
            amb.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20), amb.topAnchor.constraint(equalTo: view.topAnchor, constant: 470),
            amb.widthAnchor.constraint(equalToConstant: 60),
            pinned.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 100), pinned.topAnchor.constraint(equalTo: view.topAnchor, constant: 470),
            pinned.widthAnchor.constraint(equalToConstant: 60), pinned.heightAnchor.constraint(equalToConstant: 30),
        ])
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        becomeFirstResponder()
        view.layoutIfNeeded()
        log("ambiguous \(amb.hasAmbiguousLayout) pinned \(pinned.hasAmbiguousLayout)")
        let before = amb.frame
        amb.exerciseAmbiguityInLayout()
        pinned.exerciseAmbiguityInLayout()
        log("exercised moved \(amb.frame != before) pinned \(pinned.frame == CGRect(x: 100, y: 470, width: 60, height: 30))")
        log("representative \(navigationItem.trailingItemGroups.first?.isDisplayingRepresentativeItem ?? false)")
        surfaces.scrollTo(0)
        log("ready")
    }
    @objc func wheelPan(_ g: UIPanGestureRecognizer) {
        if g.state == .ended { log("wheel pan \(Int(g.translation(in: wheelPad).y)) touches \(g.numberOfTouches)") }
    }
    func scrollViewDidEndDragging(_ s: UIScrollView, willDecelerate d: Bool) { if !d { log("scrolled \(Int(s.contentOffset.y))") } }
    func scrollViewDidEndDecelerating(_ s: UIScrollView) { log("scrolled \(Int(s.contentOffset.y)) decelerated") }
}
