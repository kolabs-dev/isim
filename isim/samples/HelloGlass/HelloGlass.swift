// Sample: iOS 26 Liquid Glass in UIKit, over colourful stripes so the glass's blur and lensing show.
// - UIGlassContainerEffect: three glass circles that merge into one shape when "Merge" animates them together
// - an interactive, tinted UIGlassEffect card
// - UISlider: iOS 26 look, trackConfiguration (ticks that snap, a neutral value), the thumbless style; and the classic
//   customisation (value images, a custom thumb image, trackRect / thumbRect)
// - capsule UISegmentedControl / UIStepper
// - UIView.cornerConfiguration (fixed, container-concentric, uniform top) and effectiveRadius(corner:)
// - bar button items sharing one glass capsule, a prominent item, an item with hidesSharedBackground
// On iOS 17/18 only the classic slider customisation shows.
import UIKit

func log(_ s: String) { print("glass \(s)") }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: GlassViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class Stripes: UIView {
    override func draw(_ rect: CGRect) {
        let colors: [UIColor] = [.systemRed, .systemOrange, .systemYellow, .systemGreen, .systemTeal, .systemBlue, .systemPurple, .systemPink]
        let w: CGFloat = 24
        var x: CGFloat = 0, i = 0
        while x < bounds.width {
            colors[i % colors.count].setFill()
            UIRectFill(CGRect(x: x, y: 0, width: w, height: bounds.height))
            x += w; i += 1
        }
    }
}

final class GlassViewController: UIViewController {
    var circles: [UIView] = []
    let custom = UISlider()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Glass"
        let stripes = Stripes(frame: view.bounds)
        stripes.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(stripes)
        let W = view.bounds.width

        // classic slider customisation (every iOS version)
        custom.frame = CGRect(x: 20, y: 470, width: W - 40, height: 34)
        custom.accessibilityIdentifier = "custom"
        custom.minimumValueImage = UIImage(systemName: "speaker.fill")
        custom.maximumValueImage = UIImage(systemName: "speaker.wave.3.fill")
        custom.setThumbImage(Self.dot(.black, 26), for: .normal)
        custom.setThumbImage(Self.dot(.white, 30), for: .highlighted)
        custom.value = 0.5
        custom.addTarget(self, action: #selector(customChanged), for: .valueChanged)
        view.addSubview(custom)
        let track = custom.trackRect(forBounds: custom.bounds), thumb = custom.thumbRect(forBounds: custom.bounds, trackRect: track, value: 0.5)
        log("custom track \(Int(track.minX)) \(Int(track.width)) thumb \(Int(thumb.midX)) \(Int(thumb.width)) images \(custom.currentThumbImage != nil) \(custom.thumbImage(for: .highlighted) != nil)")

        guard #available(iOS 26, *) else { log("ready (no iOS 26 APIs)"); return }

        // bar items: two sharing one capsule, a prominent one, one without glass
        let share = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: nil, action: nil)
        let more = UIBarButtonItem(image: UIImage(systemName: "ellipsis"), style: .plain, target: nil, action: nil)
        share.accessibilityIdentifier = "bar-share"; more.accessibilityIdentifier = "bar-more"
        let done = UIBarButtonItem(title: "Done", style: .prominent, target: nil, action: nil)
        done.accessibilityIdentifier = "bar-done"
        navigationItem.rightBarButtonItems = [done, more, share]
        let bare = UIBarButtonItem(image: UIImage(systemName: "star"), style: .plain, target: nil, action: nil)
        bare.hidesSharedBackground = true; bare.accessibilityIdentifier = "bar-star"
        navigationItem.leftBarButtonItem = bare

        // a glass container: circles merge when closer than its spacing
        let container = UIGlassContainerEffect()
        container.spacing = 24
        let host = UIVisualEffectView(effect: container)
        host.frame = CGRect(x: 0, y: 120, width: W, height: 90)
        host.accessibilityIdentifier = "container"
        view.addSubview(host)
        for (i, x) in [40.0, 171.0, 302.0].enumerated() {
            let c = UIVisualEffectView(effect: UIGlassEffect(style: .regular))
            c.frame = CGRect(x: x, y: 15, width: 60, height: 60)
            c.cornerConfiguration = .capsule()
            c.accessibilityIdentifier = "circle\(i)"
            host.contentView.addSubview(c)
            circles.append(c)
        }
        let merge = UIButton(configuration: .prominentGlass())
        merge.configuration?.title = "Merge"
        merge.accessibilityIdentifier = "merge"
        merge.frame = CGRect(x: W / 2 - 60, y: 220, width: 120, height: 44)
        merge.addAction(UIAction { [weak self] _ in self?.mergeCircles() }, for: .touchUpInside)
        view.addSubview(merge)

        let glass = UIGlassEffect(style: .regular)
        glass.isInteractive = true
        glass.tintColor = UIColor.systemBlue.withAlphaComponent(0.35)
        let card = UIVisualEffectView(effect: glass)
        card.frame = CGRect(x: 20, y: 280, width: W - 40, height: 56)
        card.cornerConfiguration = .corners(radius: 20)
        card.accessibilityIdentifier = "card"
        let label = UILabel(frame: card.bounds.insetBy(dx: 16, dy: 0))
        label.text = "Interactive glass"; label.font = .systemFont(ofSize: 17, weight: .semibold)
        card.contentView.addSubview(label)
        view.addSubview(card)

        // sliders
        let ticks = UISlider(frame: CGRect(x: 20, y: 350, width: W - 40, height: 34))
        ticks.accessibilityIdentifier = "ticks"
        ticks.trackConfiguration = .init(numberOfTicks: 5)
        ticks.value = 0.5
        ticks.addAction(UIAction { _ in log("ticks \(ticks.value)") }, for: .valueChanged)
        view.addSubview(ticks)
        let thumbless = UISlider(frame: CGRect(x: 20, y: 400, width: W - 40, height: 34))
        thumbless.accessibilityIdentifier = "thumbless"
        thumbless.sliderStyle = .thumbless
        thumbless.trackConfiguration = .init(allowsTickValuesOnly: false, neutralValue: 0.5, ticks: [])
        thumbless.value = 0.8
        thumbless.addAction(UIAction { _ in log("thumbless \(String(format: "%.2f", thumbless.value))") }, for: .valueChanged)
        view.addSubview(thumbless)
        log("track config ticks \(ticks.trackConfiguration?.ticks.count ?? 0) snaps \(ticks.trackConfiguration?.allowsTickValuesOnly == true) neutral \(thumbless.trackConfiguration?.neutralValue ?? -1) style \(thumbless.sliderStyle == .thumbless)")

        let segments = UISegmentedControl(items: ["Day", "Week", "Month"])
        segments.selectedSegmentIndex = 0
        segments.frame = CGRect(x: 20, y: 530, width: 220, height: 32)
        segments.accessibilityIdentifier = "segments"
        segments.addAction(UIAction { _ in log("segment \(segments.selectedSegmentIndex)") }, for: .valueChanged)
        view.addSubview(segments)
        let stepper = UIStepper(frame: CGRect(x: W - 114, y: 530, width: 94, height: 32))
        stepper.accessibilityIdentifier = "stepper"
        view.addSubview(stepper)

        // corner configurations
        let outer = UIView(frame: CGRect(x: 20, y: 590, width: W - 40, height: 120))
        outer.backgroundColor = .systemBackground
        outer.cornerConfiguration = .corners(radius: 32)
        outer.accessibilityIdentifier = "outer"
        let inner = UIView(frame: outer.bounds.insetBy(dx: 12, dy: 12))
        inner.backgroundColor = .systemIndigo
        inner.cornerConfiguration = .corners(radius: .containerConcentric())
        inner.accessibilityIdentifier = "inner"
        outer.addSubview(inner)
        view.addSubview(outer)
        let top = UIView(frame: CGRect(x: 20, y: 730, width: W - 40, height: 60))
        top.backgroundColor = .systemBackground
        top.cornerConfiguration = .uniformTopRadius(28, bottomLeftRadius: nil, bottomRightRadius: nil)
        top.accessibilityIdentifier = "top"
        view.addSubview(top)
        view.layoutIfNeeded()
        log("corners outer \(outer.effectiveRadius(corner: .topLeft)) inner \(inner.effectiveRadius(corner: .topLeft)) top \(top.effectiveRadius(corner: .topRight)) \(top.effectiveRadius(corner: .bottomLeft)) capsule \(circles[0].effectiveRadius(corner: .bottomRight))")
        log("config \(top.cornerConfiguration == .uniformTopRadius(28, bottomLeftRadius: nil, bottomRightRadius: nil)) \(inner.cornerConfiguration)")
        log("ready")
    }

    static func dot(_ c: UIColor, _ d: CGFloat) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: d, height: d)).image { _ in c.setFill(); UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: d, height: d)).fill() }
    }
    @objc func customChanged() { log("custom \(String(format: "%.2f", custom.value))") }

    func mergeCircles() {
        UIView.animate(withDuration: 0.6, animations: {
            for (i, c) in self.circles.enumerated() { c.frame.origin.x = 111 + CGFloat(i) * 60 }
        }, completion: { _ in log("merged") })
    }
}
