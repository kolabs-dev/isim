// Sample: iOS 27.1 UIKit for foldable devices on isim's (non-folding) devices — UIArrangementViewController (split
// and overlay arrangements, dimension ranges, layout priority, view states, placements, arrangementViewController),
// UIHingeInteraction (no hinge), reserved regions (the Dynamic Island / notch occludes, no division), the vertical bar
// (verticalBarEdge, preferredVerticalBarBehavior through containers, axisBehavior, verticalBarCompressionBehavior),
// and iOS 26 layout regions (safe area, margins, a 27.1 bar strip along an edge).
import UIKit

func log(_ s: String) { print("harr \(s)") }
func rect(_ r: CGRect) -> String { "\(Int(r.minX)) \(Int(r.minY)) \(Int(r.width)) \(Int(r.height))" }

final class LibraryViewController: UIViewController {
    var onArrange: ((String) -> Void)?
    override func viewDidLoad() {
        title = "Library"
        view.backgroundColor = .systemBlue.withAlphaComponent(0.15)
        view.accessibilityIdentifier = "primary-view"
        let buttons = ["split", "overlay", "fixed", "stacked"].map { name in
            let b = UIButton(configuration: .bordered(), primaryAction: UIAction(title: name.capitalized) { [weak self] _ in self?.onArrange?(name) })
            b.accessibilityIdentifier = "arrange-\(name)"
            return b
        }
        let stack = UIStackView(arrangedSubviews: buttons)
        stack.axis = .vertical; stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor), stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12)])
        let item = UIBarButtonItem(systemItem: .add)
        item.accessibilityIdentifier = "add-item"
        if #available(iOS 27.1, *) { item.axisBehavior = .horizontalOnly; navigationItem.verticalBarCompressionBehavior = .prefersTabBar }
        navigationItem.rightBarButtonItem = item
        if #available(iOS 27.1, *) {
            view.addInteraction(UIHingeInteraction { _, update in
                log("hinge \(update.hinge.map { "status \($0.status.rawValue) angle \($0.angle)" } ?? "nil")")
            })
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if #available(iOS 27.1, *) {
            log("arrangement parent \(arrangementViewController != nil || navigationController?.arrangementViewController != nil)")
            log("vertical bar edge \(traitCollection.verticalBarEdge == .unspecified ? "unspecified" : "\(traitCollection.verticalBarEdge.rawValue)") traits \(UITraitCollection.systemTraitsAffectingVerticalBarEdge.count)")
            log("axis behavior \(navigationItem.rightBarButtonItem?.axisBehavior == .horizontalOnly) compression \(navigationItem.verticalBarCompressionBehavior == .prefersTabBar)")
        }
    }
}

final class PlayerViewController: UIViewController {
    let guideView = UIView()
    override func viewDidLoad() {
        view.backgroundColor = .systemOrange.withAlphaComponent(0.3)
        view.accessibilityIdentifier = "secondary-view"
        let label = UILabel(); label.text = "Now Playing"; label.font = .boldSystemFont(ofSize: 22)
        label.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(label)
        NSLayoutConstraint.activate([label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor)])
        if #available(iOS 27.1, *) {                             // a 44 pt bar strip along the leading edge of the safe area
            guideView.backgroundColor = .systemPurple.withAlphaComponent(0.4)
            guideView.accessibilityIdentifier = "bar-guide"
            guideView.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(guideView)
            let g = view.layoutGuide(for: .bar(onEdge: NSDirectionalRectEdge.leading, extent: 44))
            NSLayoutConstraint.activate([guideView.leadingAnchor.constraint(equalTo: g.leadingAnchor), guideView.trailingAnchor.constraint(equalTo: g.trailingAnchor),
                                         guideView.topAnchor.constraint(equalTo: g.topAnchor), guideView.bottomAnchor.constraint(equalTo: g.bottomAnchor)])
        }
    }
    @available(iOS 27.1, *)
    override var preferredVerticalBarBehavior: UIVerticalBarBehavior { .disabled }    // full screen playback: no vertical bar
}

final class RootViewController: UIViewController {
    override func viewDidLoad() {
        view.backgroundColor = .systemBackground
        guard #available(iOS 27.1, *) else {
            log("ios27.1 no")
            let label = UILabel(); label.text = "iOS 27.1 needed"; label.frame = CGRect(x: 20, y: 100, width: 300, height: 30)
            view.addSubview(label)
            return
        }
        log("ios27.1 yes")
        let arrangement = UIArrangementViewController()
        let library = LibraryViewController(), player = PlayerViewController()
        let nav = UINavigationController(rootViewController: library)
        arrangement.setViewController(nav, for: .primary)
        arrangement.setViewController(player, for: .secondary)
        addChild(arrangement)
        arrangement.view.frame = view.bounds
        arrangement.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(arrangement.view)
        arrangement.didMove(toParent: self)
        func report(_ name: String) {
            arrangement.view.layoutIfNeeded()
            for (label, p) in [("primary", UIArrangementViewController.ViewPlacement.primary), ("secondary", .secondary)] {
                guard let s = arrangement.state(for: p) else { log("\(name) \(label) none"); continue }
                let axis = s.splitAxis == .horizontal ? "horizontal" : s.splitAxis == .vertical ? "vertical" : "none"
                log("\(name) \(label) hidden \(s.isHidden) axis \(axis) z \(s.zIndex) frame \(rect(arrangement.viewController(for: p)!.view.frame))")
            }
        }
        library.onArrange = { name in
            switch name {
            case "overlay": arrangement.updateArrangement(.overlay.axes(.horizontal), animated: true)
            case "fixed":                                        // the primary asks for 240 pt wide / 30% high, and keeps it
                var split = UISplitArrangement()
                var p = split.defaultViewProperties
                p.width.preferred = .absolute(240); p.height.preferred = .fractional(0.3); p.layoutPriority = 1
                split.setViewProperties(p, for: .primary)
                arrangement.updateArrangement(split)
            case "stacked": arrangement.updateArrangement(.split.axes(.vertical))
            default: arrangement.updateArrangement(.split)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { report(name) }
        }
        DispatchQueue.main.async {
            report("initial")
            log("placement \(arrangement.placement(for: player) == .secondary) \(arrangement.placement(for: library) == nil)")
            let occ = self.view.reservedRegions(kind: .occlusion)
            log("occlusion \(occ.count) \(occ.first.map { "\($0.id) \(rect($0.frame)) active \($0.isActive)" } ?? "-")")
            log("division \(self.view.reservedRegions(kind: .division, options: .includeInactive).count)")
            log("safe area region \(self.view.edgeInsets(for: .safeArea()) == self.view.safeAreaInsets) margins \(self.view.directionalEdgeInsets(for: .margins(cornerAdaptation: .horizontal)) == self.view.directionalLayoutMargins)")
            player.setNeedsUpdateOfVerticalBarConfiguration()
        }
    }
    @available(iOS 27.1, *)
    override var childForPreferredVerticalBarBehavior: UIViewController? {
        (children.first as? UIArrangementViewController)?.viewController(for: .secondary)
    }
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = RootViewController()
        window?.makeKeyAndVisible()
        return true
    }
}
