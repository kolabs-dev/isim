// isim: the test ads that the ad SDK stand-ins (GoogleMobileAds, AppLovinSDK, FBAudienceNetwork) show, compiled into
// each of them. Like an app on Apple's Simulator, which ad networks always treat as a test device, an app on isim gets
// test ads: isim draws its own clearly labelled "Test Ad" creatives locally (nothing is requested from an ad server,
// nothing is earned). The flow around them is the SDKs': loads, impressions, clicks with a landing page,
// full-screen presentation and dismissal, rewards after a countdown.
//
// ISIM_ADS=nofill makes every load fail with the network's "no fill" error and ISIM_ADS=error with a network error
// (to test an app's paths without ads); ISIM_ADS_REWARD_SECONDS sets the rewarded countdown (default 5).
import UIKit

enum _TestAds {
    enum Mode { case fill, noFill, networkError }
    static var mode: Mode {
        switch ProcessInfo.processInfo.environment["ISIM_ADS"]?.lowercased() {
        case "nofill", "no-fill": return .noFill
        case "error", "networkerror": return .networkError
        default: return .fill
        }
    }
    static var rewardSeconds: Int { Int(ProcessInfo.processInfo.environment["ISIM_ADS_REWARD_SECONDS"] ?? "") ?? 5 }

    /// the view controller to present from: the given one, else the key window's topmost
    static func presenter(_ vc: UIViewController?) -> UIViewController? {
        var top = vc ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
            ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController, !p.isBeingDismissed { top = p }
        return top
    }

    /// a landing page for a click on a test ad (the network's "learn more" page, drawn locally)
    static func presentLanding(network: String, from vc: UIViewController?, willPresent: @escaping () -> Void,
                               willDismiss: @escaping () -> Void, didDismiss: @escaping () -> Void) {
        guard let from = presenter(vc) else { return }
        let landing = _TestAdLandingController(network: network)
        landing.onClose = { willDismiss(); landing.dismiss(animated: true) { didDismiss() } }
        willPresent()
        print("isim: \(network) test ad clicked: landing page shown")
        from.present(landing, animated: true)
    }
}

/// a test creative: a white card with the "Test Ad" badge, the network and its size, like the networks' test creatives
final class _TestAdCreativeView: UIView {
    let badge = UILabel(), title = UILabel(), detail = UILabel()
    var onTap: (() -> Void)?

    init(network: String, headline: String, frame: CGRect = .zero) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.97, alpha: 1)
        layer.borderColor = UIColor(white: 0.82, alpha: 1).cgColor
        layer.borderWidth = 1
        clipsToBounds = true
        badge.text = " Test Ad "
        badge.font = .boldSystemFont(ofSize: 11)
        badge.textColor = .white
        badge.backgroundColor = UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1)
        badge.layer.cornerRadius = 3
        badge.clipsToBounds = true
        title.text = headline
        title.font = .boldSystemFont(ofSize: 14)
        title.textColor = UIColor(white: 0.15, alpha: 1)
        title.numberOfLines = 0
        detail.text = "\(network) · isim test ad"
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = UIColor(white: 0.45, alpha: 1)
        for v in [badge, title, detail] { addSubview(v) }
        isAccessibilityElement = true
        accessibilityLabel = "Test Ad. \(headline)"
        accessibilityIdentifier = "ad-creative"
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    @objc func tapped() { onTap?() }

    override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds.insetBy(dx: 8, dy: 4)
        badge.sizeToFit()
        let compact = bounds.height < 70
        if compact {                                       // a banner: badge, then the headline on one line
            badge.frame = CGRect(x: b.minX, y: b.minY + 2, width: badge.bounds.width, height: 16)
            title.font = .boldSystemFont(ofSize: bounds.height < 55 ? 12 : 14)
            title.numberOfLines = 2
            title.frame = CGRect(x: badge.frame.maxX + 8, y: b.minY, width: b.maxX - badge.frame.maxX - 8, height: b.height - 12)
            detail.frame = CGRect(x: badge.frame.maxX + 8, y: b.maxY - 12, width: b.maxX - badge.frame.maxX - 8, height: 12)
        } else {
            badge.frame = CGRect(x: b.minX, y: b.minY + 4, width: badge.bounds.width, height: 18)
            let tw = b.width
            let th = title.sizeThatFits(CGSize(width: tw, height: .greatestFiniteMagnitude)).height
            title.frame = CGRect(x: b.minX, y: badge.frame.maxY + 8, width: tw, height: min(th, b.height - 50))
            detail.frame = CGRect(x: b.minX, y: b.maxY - 16, width: tw, height: 14)
        }
    }
}

/// a full-screen test ad: interstitial, rewarded (a countdown before the reward and the close button) or app open
final class _TestAdFullScreenController: UIViewController {
    enum Kind { case interstitial, rewarded(seconds: Int), appOpen }
    let kind: Kind, network: String
    var onImpression: (() -> Void)?, onClick: (() -> Void)?, onReward: (() -> Void)?
    var onWillDismiss: (() -> Void)?, onDidDismiss: (() -> Void)?
    let close = UIButton(type: .system), countdown = UILabel(), cta = UIButton(type: .system)
    var remaining = 0, timer: Timer?, rewarded = false

    init(kind: Kind, network: String) {
        self.kind = kind; self.network = network
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .fullScreen
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var headline: String {
        switch kind {
        case .interstitial: return "This is a test interstitial ad."
        case .rewarded: return "This is a test rewarded ad."
        case .appOpen: return "This is a test app open ad."
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        let card = _TestAdCreativeView(network: network, headline: headline)
        card.onTap = { [weak self] in self?.clicked() }
        card.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(card)
        close.setTitle("✕", for: .normal)
        close.titleLabel?.font = .systemFont(ofSize: 22, weight: .semibold)
        close.tintColor = .darkGray
        close.accessibilityLabel = "Close Ad"
        close.accessibilityIdentifier = "ad-close"
        close.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        close.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(close)
        countdown.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        countdown.textColor = .darkGray
        countdown.accessibilityIdentifier = "ad-countdown"
        countdown.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(countdown)
        cta.setTitle(kindIsAppOpen ? "Continue to app" : "Learn more", for: .normal)
        cta.titleLabel?.font = .boldSystemFont(ofSize: 17)
        cta.accessibilityIdentifier = kindIsAppOpen ? "ad-continue" : "ad-learn-more"
        cta.addTarget(self, action: kindIsAppOpen ? #selector(closeTapped) : #selector(clicked), for: .touchUpInside)
        cta.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(cta)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            close.topAnchor.constraint(equalTo: g.topAnchor, constant: 8), close.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 12),
            close.widthAnchor.constraint(equalToConstant: 44), close.heightAnchor.constraint(equalToConstant: 44),
            countdown.centerYAnchor.constraint(equalTo: close.centerYAnchor), countdown.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -16),
            card.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 24), card.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -24),
            card.centerYAnchor.constraint(equalTo: g.centerYAnchor, constant: -30), card.heightAnchor.constraint(equalToConstant: 220),
            cta.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 24), cta.centerXAnchor.constraint(equalTo: g.centerXAnchor),
        ])
        if case .rewarded(let s) = kind {
            remaining = max(0, s)
            close.isHidden = remaining > 0
            countdown.text = remaining > 0 ? "Reward in \(remaining) s" : ""
        }
    }
    var kindIsAppOpen: Bool { if case .appOpen = kind { return true }; return false }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onImpression?(); onImpression = nil
        if case .rewarded = kind {
            if remaining == 0 { grant(); return }
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] t in
                guard let self else { t.invalidate(); return }
                self.remaining -= 1
                if self.remaining <= 0 { t.invalidate(); self.grant() } else { self.countdown.text = "Reward in \(self.remaining) s" }
            }
        }
    }
    func grant() {
        guard !rewarded else { return }
        rewarded = true
        countdown.text = "Reward granted"
        close.isHidden = false
        print("isim: \(network) test rewarded ad: reward granted")
        onReward?()
    }
    @objc func clicked() {
        onClick?()
        _TestAds.presentLanding(network: network, from: self, willPresent: {}, willDismiss: {}, didDismiss: {})
    }
    @objc func closeTapped() {
        timer?.invalidate()
        onWillDismiss?()
        let done = onDidDismiss
        presentingViewController?.dismiss(animated: true) { done?() }
    }
}

final class _TestAdLandingController: UIViewController {
    let network: String
    var onClose: (() -> Void)?
    init(network: String) { self.network = network; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let label = UILabel()
        label.text = "Test ad landing page\n\(network)\n\nTest ads do not lead anywhere."
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        let done = UIButton(type: .system)
        done.setTitle("Close", for: .normal)
        done.titleLabel?.font = .boldSystemFont(ofSize: 17)
        done.accessibilityIdentifier = "ad-landing-close"
        done.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        for v in [label, done] { v.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(v) }
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor), label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(lessThanOrEqualTo: view.widthAnchor, constant: -48),
            done.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            done.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -16),
        ])
    }
    @objc func closeTapped() { onClose?() }
}
