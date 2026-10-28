// isim AppTrackingTransparency: the expanded tracking prompt (iOS 27.2, issue #397), a sheet with the app's purpose
// string and, when the app gives an action, a "Learn More" button that runs it (the sheet stays up). isim's rendition
// of iOS's expanded interface; the answer is stored like the alert's.
import UIKit

extension ATTrackingManager {
    @available(iOS 27.2, *)
    public class func requestTrackingAuthorization(preferExpandedInterface: Bool, additionalInformationAction: (() -> Void)?,
                                                   completionHandler: @escaping (AuthorizationStatus) -> Void) {
        guard preferExpandedInterface else { requestTrackingAuthorization(completionHandler: completionHandler); return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated { _expandedPrompt(additionalInformationAction, completionHandler) }
        }
    }
    @available(iOS 27.2, *)
    public class func requestTrackingAuthorization(preferExpandedInterface: Bool, additionalInformationAction: (() -> Void)?) async -> AuthorizationStatus {
        await withCheckedContinuation { k in
            requestTrackingAuthorization(preferExpandedInterface: preferExpandedInterface, additionalInformationAction: additionalInformationAction) { k.resume(returning: $0) }
        }
    }

    @MainActor static func _expandedPrompt(_ learnMore: (() -> Void)?, _ done: @escaping (AuthorizationStatus) -> Void) {
        let current = trackingAuthorizationStatus
        guard current == .notDetermined else { done(current); return }
        guard let purpose = Bundle.main.object(forInfoDictionaryKey: "NSUserTrackingUsageDescription") as? String else {
            NSLog("isim: requestTrackingAuthorization without NSUserTrackingUsageDescription in Info.plist (iOS would terminate the app)")
            done(.denied); return
        }
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        guard let vc = top else { done(.notDetermined); return }
        let sheet = _ATTExpandedSheet(appName: name, purpose: purpose, learnMore: learnMore) { s in
            UserDefaults.standard.set(Int(s.rawValue), forKey: key)
            NSLog("isim: tracking %@ (expanded prompt)", s == .authorized ? "allowed" : "denied")
            done(s)
        }
        sheet.sheetPresentationController?.detents = [.large()]
        sheet.isModalInPresentation = true                       // answered with its buttons only
        vc.present(sheet, animated: true, completion: nil)
    }
}

final class _ATTExpandedSheet: UIViewController {
    let appName: String, purpose: String
    let learnMore: (() -> Void)?
    let answer: (ATTrackingManager.AuthorizationStatus) -> Void
    init(appName: String, purpose: String, learnMore: (() -> Void)?, answer: @escaping (ATTrackingManager.AuthorizationStatus) -> Void) {
        self.appName = appName; self.purpose = purpose; self.learnMore = learnMore; self.answer = answer
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let icon = UIImageView(image: UIImage(systemName: "hand.raised"))
        icon.tintColor = .systemBlue
        icon.contentMode = .scaleAspectFit
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let title = label("Allow “\(appName)” to track your activity across other companies’ apps and websites?", .boldSystemFont(ofSize: 24), .label)
        let body = label(purpose, .systemFont(ofSize: 17), .secondaryLabel)
        body.accessibilityIdentifier = "att-purpose"
        let note = label("You can change this choice later in Settings > Privacy & Security > Tracking.", .systemFont(ofSize: 13), .secondaryLabel)
        var items: [UIView] = [icon, title, body, note]
        if learnMore != nil { items.append(button("Learn More…", "att-learn-more", filled: false) { [weak self] in self?.learnMore?() }) }
        let top = UIStackView(arrangedSubviews: items)
        top.axis = .vertical; top.spacing = 16; top.alignment = .fill
        let allow = button("Allow", "att-allow", filled: true) { [weak self] in self?.finish(.authorized) }
        let deny = button("Ask App Not to Track", "att-deny", filled: true) { [weak self] in self?.finish(.denied) }
        let bottom = UIStackView(arrangedSubviews: [allow, deny])
        bottom.axis = .vertical; bottom.spacing = 12
        for s in [top, bottom] { s.translatesAutoresizingMaskIntoConstraints = false; view.addSubview(s) }
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            top.topAnchor.constraint(equalTo: g.topAnchor, constant: 40),
            top.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 28), top.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -28),
            bottom.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 28), bottom.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -28),
            bottom.bottomAnchor.constraint(equalTo: g.bottomAnchor, constant: -20),
            allow.heightAnchor.constraint(equalToConstant: 50), deny.heightAnchor.constraint(equalToConstant: 50),
        ])
    }
    func label(_ text: String, _ font: UIFont, _ color: UIColor) -> UILabel {
        let l = UILabel()
        l.text = text; l.font = font; l.textColor = color; l.numberOfLines = 0; l.textAlignment = .center
        return l
    }
    func button(_ title: String, _ id: String, filled: Bool, _ action: @escaping () -> Void) -> UIButton {
        var c = filled ? UIButton.Configuration.filled() : UIButton.Configuration.plain()
        c.title = title
        c.cornerStyle = .large
        let b = UIButton(configuration: c, primaryAction: UIAction { _ in action() })
        b.accessibilityIdentifier = id
        return b
    }
    func finish(_ s: ATTrackingManager.AuthorizationStatus) {
        dismiss(animated: true) { self.answer(s) }
    }
}
