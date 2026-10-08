// Sample: UIKit presentation on isim — modal presentation and transition styles, sheets with detents, popovers,
// a custom (and interactively dismissed) transition with a custom UIPresentationController, UIPageViewController,
// UISplitViewController (collapsed), UIAlertController text fields, UIActivityViewController and
// UIContentUnavailableConfiguration. Each demo prints what happens.
import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: MenuViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

func button(_ title: String, _ id: String, _ action: @escaping () -> Void) -> UIButton {
    let config = UIButton.Configuration.gray()
    config.title = title
    let b = UIButton(configuration: config, primaryAction: UIAction { _ in action() })
    b.accessibilityIdentifier = id
    return b
}

/// A presented page with a title and a Close button.
final class PageViewController: UIViewController {
    let name: String
    let color: UIColor
    init(_ name: String, color: UIColor = .systemBackground) { self.name = name; self.color = color; super.init(nibName: nil, bundle: nil); title = name }
    required init?(coder: NSCoder) { fatalError() }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = color
        let label = UILabel()
        label.text = name
        label.font = .boldSystemFont(ofSize: 28)
        label.accessibilityIdentifier = "label-\(name)"
        let close = button("Close", "close-\(name)") { [weak self] in self?.dismiss(animated: true) { print("dismissed \(self?.name ?? "")") } }
        let stack = UIStackView(arrangedSubviews: [label, close])
        stack.axis = .vertical
        stack.spacing = 16
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                                     stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40)])
    }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); print("\(name) appeared, presenting \(presentingViewController != nil)") }
    override func viewDidDisappear(_ animated: Bool) { super.viewDidDisappear(animated); print("\(name) disappeared") }
}

final class MenuViewController: UIViewController, UIPopoverPresentationControllerDelegate, UISheetPresentationControllerDelegate,
                                UIAdaptivePresentationControllerDelegate {
    let transition = SlideUpTransition()
    var popoverAnchor: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Transitions"
        view.backgroundColor = .systemBackground
        popoverAnchor = button("Popover", "demo-popover") { [unowned self] in self.popover(adapt: false) }
        let items: [UIButton] = [
            button("Full Screen", "demo-full") { [unowned self] in self.modal(.fullScreen, .coverVertical, "Full") },
            button("Dissolve", "demo-dissolve") { [unowned self] in self.modal(.overFullScreen, .crossDissolve, "Dissolve") },
            button("Flip", "demo-flip") { [unowned self] in self.modal(.fullScreen, .flipHorizontal, "Flip") },
            button("Sheet", "demo-sheet") { [unowned self] in self.sheet() },
            popoverAnchor,
            button("Popover Sheet", "demo-popsheet") { [unowned self] in self.popover(adapt: true) },
            button("Custom", "demo-custom") { [unowned self] in self.custom() },
            button("Pages", "demo-pages") { [unowned self] in self.navigationController?.pushViewController(PagesHost(), animated: true) },
            button("Split", "demo-split") { [unowned self] in self.split() },
            button("Alert Field", "demo-alert") { [unowned self] in self.alertField() },
            button("Share", "demo-share") { [unowned self] in self.share() },
            button("Unavailable", "demo-unavailable") { [unowned self] in self.navigationController?.pushViewController(EmptyStateViewController(), animated: true) },
        ]
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        for row in stride(from: 0, to: items.count, by: 2) {
            let h = UIStackView(arrangedSubviews: Array(items[row..<min(row + 2, items.count)]))
            h.axis = .horizontal
            h.spacing = 10
            h.distribution = .fillEqually
            grid.addArrangedSubview(h)
        }
        grid.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(grid)
        NSLayoutConstraint.activate([
            grid.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            grid.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }
    override func viewWillDisappear(_ animated: Bool) { super.viewWillDisappear(animated); print("menu will disappear") }
    override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); print("menu appeared") }

    func modal(_ style: UIModalPresentationStyle, _ transition: UIModalTransitionStyle, _ name: String) {
        let vc = PageViewController(name, color: style == .overFullScreen ? UIColor.black.withAlphaComponent(0.6) : .systemTeal)
        vc.modalPresentationStyle = style
        vc.modalTransitionStyle = transition
        present(vc, animated: true)
    }

    func sheet() {
        let vc = SheetContentViewController()
        vc.modalPresentationStyle = .pageSheet
        if let s = vc.sheetPresentationController {
            s.detents = [.custom(identifier: .init("small")) { _ in 200 }, .medium(), .large()]
            s.selectedDetentIdentifier = .medium
            s.prefersGrabberVisible = true
            s.largestUndimmedDetentIdentifier = .medium
            s.delegate = self
        }
        present(vc, animated: true)
    }
    func sheetPresentationControllerDidChangeSelectedDetentIdentifier(_ s: UISheetPresentationController) {
        print("sheet detent \(s.selectedDetentIdentifier?.rawValue ?? "nil")")
    }
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) { print("swiped away \(type(of: presentationController.presentedViewController))") }

    func popover(adapt: Bool) {
        let vc = PageViewController(adapt ? "Adapted" : "Pop", color: .systemYellow)
        vc.modalPresentationStyle = .popover
        vc.preferredContentSize = CGSize(width: 260, height: 200)
        if let p = vc.popoverPresentationController {
            p.sourceView = popoverAnchor
            p.permittedArrowDirections = .up
            if !adapt { p.delegate = self }
        }
        present(vc, animated: true)
    }
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle { .none }
    func popoverPresentationControllerDidDismissPopover(_ p: UIPopoverPresentationController) { print("popover dismissed by tapping outside") }

    func custom() {
        let vc = PageViewController("Custom", color: .systemPink)
        vc.modalPresentationStyle = .custom
        vc.transitioningDelegate = transition
        transition.attach(to: vc)
        present(vc, animated: true) { print("custom presented, frame \(Int(vc.view.frame.origin.y)) \(Int(vc.view.frame.height))") }
    }

    func split() {
        let split = UISplitViewController(style: .doubleColumn)
        split.delegate = SplitDelegate.shared
        let primary = ListViewController()
        split.setViewController(primary, for: .primary)
        split.setViewController(PageViewController("Detail 0"), for: .secondary)
        split.modalPresentationStyle = .fullScreen
        present(split, animated: false) { print("split collapsed \(split.isCollapsed), stack \(primary.navigationController?.viewControllers.count ?? -1)") }
    }

    func alertField() {
        let alert = UIAlertController(title: "Name", message: "Who are you?", preferredStyle: .alert)
        alert.addTextField { tf in tf.placeholder = "Your name" }
        let ok = UIAlertAction(title: "OK", style: .default) { [weak alert] _ in print("hello \(alert?.textFields?.first?.text ?? "")") }
        ok.isEnabled = false
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(ok)
        alert.textFields?.first?.addAction(UIAction { [weak alert] _ in ok.isEnabled = !(alert?.textFields?.first?.text ?? "").isEmpty }, for: .editingChanged)
        present(alert, animated: true)
    }

    func share() {
        let vc = UIActivityViewController(activityItems: ["Hello isim", URL(string: "https://example.com/isim")!], applicationActivities: [ShoutActivity()])
        vc.completionWithItemsHandler = { type, completed, _, _ in
            print("share finished: \(type?.rawValue ?? "nil") completed \(completed), pasteboard \(UIPasteboard.general.strings ?? []) \(UIPasteboard.general.url?.absoluteString ?? "-") changeCount>0 \(UIPasteboard.general.changeCount > 0)")
        }
        present(vc, animated: true)
    }
}

final class SheetContentViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.accessibilityIdentifier = "sheet-content"
        let expand = button("Expand", "sheet-expand") { [weak self] in
            guard let s = self?.sheetPresentationController else { return }
            s.animateChanges { s.selectedDetentIdentifier = .large }
            print("expanded to \(s.selectedDetentIdentifier?.rawValue ?? "nil")")
        }
        expand.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(expand)
        NSLayoutConstraint.activate([expand.topAnchor.constraint(equalTo: view.topAnchor, constant: 30), expand.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
    }
}

// MARK: - custom transition: a half-height card that slides up; pan down to dismiss interactively
final class HalfPresentationController: UIPresentationController {
    let dimming = UIView()
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let c = containerView else { return .zero }
        return CGRect(x: 0, y: c.bounds.height / 2, width: c.bounds.width, height: c.bounds.height / 2)
    }
    override func presentationTransitionWillBegin() {
        guard let c = containerView else { return }
        dimming.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        dimming.frame = c.bounds
        dimming.alpha = 0
        dimming.accessibilityIdentifier = "custom-dimming"
        c.insertSubview(dimming, at: 0)
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.dimming.alpha = 1 }, completion: nil)
    }
    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in self.dimming.alpha = 0 }, completion: nil)
    }
    override func containerViewWillLayoutSubviews() { presentedView?.frame = frameOfPresentedViewInContainerView }
}

final class SlideAnimator: NSObject, UIViewControllerAnimatedTransitioning {
    let presenting: Bool
    init(presenting: Bool) { self.presenting = presenting }
    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval { 0.4 }
    func animateTransition(using ctx: UIViewControllerContextTransitioning) {
        if presenting {
            guard let to = ctx.viewController(forKey: .to), let v = ctx.view(forKey: .to) else { return }
            let final = ctx.finalFrame(for: to)
            v.frame = final.offsetBy(dx: 0, dy: final.height)
            ctx.containerView.addSubview(v)
            UIView.animate(withDuration: 0.4, animations: { v.frame = final }) { _ in ctx.completeTransition(!ctx.transitionWasCancelled) }
        } else {
            guard let v = ctx.view(forKey: .from) else { return }
            let start = v.frame
            UIView.animate(withDuration: 0.4, delay: 0, options: [.curveLinear], animations: { v.frame = start.offsetBy(dx: 0, dy: start.height) }) { _ in
                let cancelled = ctx.transitionWasCancelled
                print("custom dismissal \(cancelled ? "cancelled" : "finished")")
                ctx.completeTransition(!cancelled)
            }
        }
    }
}

final class SlideUpTransition: NSObject, UIViewControllerTransitioningDelegate {
    var interactive: UIPercentDrivenInteractiveTransition?
    weak var presented: UIViewController?
    func attach(to vc: UIViewController) {
        presented = vc
        vc.loadViewIfNeeded()
        let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        vc.view.addGestureRecognizer(pan)
    }
    @objc func panned(_ g: UIPanGestureRecognizer) {
        guard let v = g.view else { return }
        let p = max(0, min(1, g.translation(in: v).y / v.bounds.height))
        switch g.state {
        case .began:
            interactive = UIPercentDrivenInteractiveTransition()
            presented?.dismiss(animated: true) { print("custom dismissed") }
        case .changed: interactive?.update(p)
        default:
            print("custom pan ended at \(Int(p * 100))%")
            if p > 0.5 { interactive?.finish() } else { interactive?.cancel() }
            interactive = nil
        }
    }
    func presentationController(forPresented presented: UIViewController, presenting: UIViewController?, source: UIViewController) -> UIPresentationController? {
        HalfPresentationController(presentedViewController: presented, presenting: presenting)
    }
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? { SlideAnimator(presenting: true) }
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? { SlideAnimator(presenting: false) }
    func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? { interactive }
}

// MARK: - page view controller
final class PagesHost: UIViewController, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
    let pages = (1...3).map { PageViewController("Page \($0)", color: [UIColor.systemRed, .systemGreen, .systemBlue][$0 - 1]) }
    let pvc = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Pages"
        pvc.dataSource = self
        pvc.delegate = self
        pvc.setViewControllers([pages[0]], direction: .forward, animated: false)
        addChild(pvc)
        pvc.view.frame = view.bounds
        pvc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        pvc.view.accessibilityIdentifier = "pages"
        view.addSubview(pvc.view)
        pvc.didMove(toParent: self)
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Last", primaryAction: UIAction { [unowned self] _ in
            self.pvc.setViewControllers([self.pages[2]], direction: .forward, animated: true) { _ in print("jumped to \(self.pvc.viewControllers?.first?.title ?? "")") }
        })
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "pages-last"
    }
    func pageViewController(_ p: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc as! PageViewController), i > 0 else { return nil }
        return pages[i - 1]
    }
    func pageViewController(_ p: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
        guard let i = pages.firstIndex(of: vc as! PageViewController), i < pages.count - 1 else { return nil }
        return pages[i + 1]
    }
    func presentationCount(for p: UIPageViewController) -> Int { pages.count }
    func presentationIndex(for p: UIPageViewController) -> Int { pages.firstIndex(of: p.viewControllers?.first as! PageViewController) ?? 0 }
    func pageViewController(_ p: UIPageViewController, willTransitionTo pending: [UIViewController]) { print("will turn to \(pending.first?.title ?? "")") }
    func pageViewController(_ p: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        print("page turn completed \(completed), now \(p.viewControllers?.first?.title ?? "")")
    }
}

// MARK: - split view controller (collapsed on iPhone)
final class SplitDelegate: NSObject, UISplitViewControllerDelegate {
    static let shared = SplitDelegate()
    func splitViewController(_ svc: UISplitViewController, topColumnForCollapsingToProposedTopColumn proposedTopColumn: UISplitViewController.Column) -> UISplitViewController.Column { .primary }
}
final class ListViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Items"
        view.backgroundColor = .systemBackground
        let stack = UIStackView(arrangedSubviews: (1...3).map { i in
            button("Item \(i)", "item-\(i)") { [unowned self] in self.showDetailViewController(PageViewController("Detail \(i)"), sender: self) }
        } + [button("Done", "split-done") { [unowned self] in self.splitViewController?.dismiss(animated: false) { print("split closed") } }])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
                                     stack.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        print("split view controller found \(splitViewController != nil)")
    }
}

// MARK: - share activity
final class ShoutActivity: UIActivity {
    override var activityType: UIActivity.ActivityType? { UIActivity.ActivityType("dev.isim.shout") }
    override var activityTitle: String? { "Shout" }
    override var activityImage: UIImage? { UIImage(systemName: "speaker.wave.2") }
    var text = ""
    override func canPerform(withActivityItems activityItems: [Any]) -> Bool { activityItems.contains { $0 is String } }
    override func prepare(withActivityItems activityItems: [Any]) { text = (activityItems.first { $0 is String } as? String) ?? "" }
    override func perform() { print("SHOUT: \(text.uppercased())"); activityDidFinish(true) }
}

// MARK: - content unavailable
final class EmptyStateViewController: UIViewController {
    var items: [String] = []
    let label = UILabel()
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inbox"
        view.backgroundColor = .systemBackground
        label.frame = CGRect(x: 20, y: 140, width: 300, height: 30)
        label.accessibilityIdentifier = "inbox-label"
        view.addSubview(label)
        setNeedsUpdateContentUnavailableConfiguration()
    }
    override func updateContentUnavailableConfiguration(using state: UIContentUnavailableConfigurationState) {
        if !items.isEmpty { contentUnavailableConfiguration = nil; label.text = items.joined(separator: ", "); print("inbox shows \(items.count) items"); return }
        let config = UIContentUnavailableConfiguration.empty()
        config.image = UIImage(systemName: "envelope")
        config.text = "No Mail"
        config.secondaryText = "New messages appear here."
        let b = UIButton.Configuration.filled()
        b.title = "Load"
        config.button = b
        config.buttonProperties.primaryAction = UIAction { [weak self] _ in self?.load() }
        contentUnavailableConfiguration = config
        print("inbox is empty")
    }
    func load() {
        contentUnavailableConfiguration = UIContentUnavailableConfiguration.loading()
        print("inbox loading")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.items = ["Welcome", "Hello"]
            self?.setNeedsUpdateContentUnavailableConfiguration()
        }
    }
}
