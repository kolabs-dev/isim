// isim StoreKit: the App Store review request (RequestReviewAction / SKStoreReviewController).
// No App Store connection: isim shows a stand-in rating card and logs the request. Like iOS, the prompt
// appears at most 3 times in 365 days per app (further requests are ignored); nothing is submitted.
import UIKit
import SwiftUI

public struct RequestReviewAction {
    public init() {}
    @MainActor public func callAsFunction() { _ISIMReviewPrompt.request() }
}
struct _RequestReviewKey: EnvironmentKey { static var defaultValue: RequestReviewAction { RequestReviewAction() } }
extension EnvironmentValues {
    public var requestReview: RequestReviewAction {
        get { self[_RequestReviewKey.self] }
        set { self[_RequestReviewKey.self] = newValue }
    }
}

open class SKStoreReviewController: NSObject {
    @MainActor public class func requestReview() { _ISIMReviewPrompt.request() }
    @MainActor public class func requestReview(in windowScene: UIWindowScene) { _ISIMReviewPrompt.request() }
}

@MainActor enum _ISIMReviewPrompt {
    static var window: UIWindow?
    static let key = "_ISIMStoreKitReviewPrompts"
    /// iOS shows the prompt at most three times within 365 days.
    static func request() {
        let now = Date().timeIntervalSince1970
        var shown = (UserDefaults.standard.array(forKey: key) as? [Double] ?? []).filter { now - $0 < 365 * 86400 }
        guard window == nil else { return }
        guard shown.count < 3 else {
            NSLog("isim StoreKit: requestReview() ignored: the prompt was already shown 3 times in the last 365 days")
            return
        }
        shown.append(now)
        UserDefaults.standard.set(shown, forKey: key)
        present()
    }
    static func present() {
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
        NSLog("isim StoreKit: requestReview() — showing the development-style rating prompt for %@", name)
        guard window == nil else { return }
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.windowLevel = UIWindow.Level(rawValue: 2000)
        let root = UIViewController()
        root.view.backgroundColor = UIColor.black.withAlphaComponent(0.25)
        let card = UIView()
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = 14
        card.translatesAutoresizingMaskIntoConstraints = false
        card.accessibilityIdentifier = "isim-review-prompt"
        root.view.addSubview(card)
        let title = UILabel(); title.text = "Enjoying \(name)?"; title.font = .systemFont(ofSize: 17, weight: .semibold); title.textAlignment = .center
        let body = UILabel(); body.text = "Tap a star to rate it on the App Store."; body.font = .systemFont(ofSize: 13); body.textAlignment = .center; body.numberOfLines = 0
        let note = UILabel(); note.text = "isim StoreKit stand-in: nothing is sent"; note.font = .systemFont(ofSize: 11); note.textColor = .secondaryLabel; note.textAlignment = .center
        let stars = UIStackView(); stars.axis = .horizontal; stars.spacing = 10; stars.distribution = .fillEqually
        for i in 1...5 {
            let b = UIButton(type: .system)
            b.setImage(UIImage(systemName: "star"), for: .normal)
            b.accessibilityIdentifier = "isim-review-star-\(i)"
            b.addAction(UIAction { _ in NSLog("isim StoreKit: rated %d star(s) (not submitted)", i); dismiss() }, for: .touchUpInside)
            stars.addArrangedSubview(b)
        }
        let notNow = UIButton(type: .system)
        notNow.setTitle("Not Now", for: .normal)
        notNow.accessibilityIdentifier = "isim-review-not-now"
        notNow.addAction(UIAction { _ in NSLog("isim StoreKit: review prompt dismissed"); dismiss() }, for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [title, body, stars, note, notNow])
        stack.axis = .vertical; stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(stack)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: root.view.centerXAnchor),
            card.centerYAnchor.constraint(equalTo: root.view.centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 270),
            stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -10),
            stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -16),
        ])
        w.rootViewController = root
        window = w
        w.isHidden = false
    }
    static func dismiss() { window?.isHidden = true; window = nil }
}
