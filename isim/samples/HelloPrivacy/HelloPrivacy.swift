// Sample: privacy and ad attribution with Apple's frameworks only — App Tracking Transparency and the IDFA, the app's
// privacy manifest (PrivacyInfo.xcprivacy: its tracking domain localhost is blocked until tracking is allowed),
// AdServices' attribution token, SKAdNetwork and AdAttributionKit conversion values, and AdAttributionKit app
// impressions: a click-through through a UIEventAttributionView and a view-through of two seconds.
//   isim run out/apps/HelloPrivacy.app -- -tracker http://localhost:PORT
import UIKit
import AppTrackingTransparency
import AdSupport
import AdServices
import StoreKit
import AdAttributionKit
import CryptoKit

func log(_ s: String) { FileHandle.standardError.write(Data(("HelloPrivacy: " + s + "\n").utf8)) }   // unbuffered
func arg(_ name: String) -> String? {
    let a = ProcessInfo.processInfo.arguments
    if let i = a.firstIndex(of: name), i + 1 < a.count { return a[i + 1] }
    return nil
}

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = UINavigationController(rootViewController: PrivacyViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

/// an ad network's signed impression, as a publisher app gets it (here signed with a key the sample makes)
func sampleImpressionJWS() -> String {
    func b64(_ d: Data) -> String {
        d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    let header = #"{"alg":"ES256","kid":"example.adattributionkit"}"#
    let payload = #"{"impression-identifier":"7AA9F8CC-5689-4C02-B963-22CA22136015","publisher-item-identifier":0,"#
        + #""impression-type":"app-impression","ad-network-identifier":"example.adattributionkit","source-identifier":5239,"#
        + #""timestamp":\#(Int64(Date().timeIntervalSince1970 * 1000)),"advertised-item-identifier":1108187390}"#
    let input = b64(Data(header.utf8)) + "." + b64(Data(payload.utf8))
    let signature = (try? P256.Signing.PrivateKey().signature(for: Data(input.utf8)).rawRepresentation) ?? Data(count: 64)
    return input + "." + b64(signature)
}

final class PrivacyViewController: UIViewController {
    let ad = UIView()
    var impression: AppImpression?

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Privacy"
        view.backgroundColor = .systemGroupedBackground
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for (title, id, action) in [("Allow Tracking", "att", #selector(allowTracking)), ("Ping Tracker", "track", #selector(ping)),
                                    ("Attribution Token", "token", #selector(token)), ("SKAdNetwork Value", "skan", #selector(skan)),
                                    ("Postback Value", "postback", #selector(postback)), ("Lock Postback", "lock", #selector(lockPostback)),
                                    ("Load Impression", "impression", #selector(loadImpression)), ("View Ad 2 s", "viewAd", #selector(viewAd))] {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.contentHorizontalAlignment = .leading
            b.accessibilityIdentifier = id
            b.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        // an ad with an attribution view over it: a tap on it is a click-through
        ad.backgroundColor = .systemOrange
        ad.accessibilityIdentifier = "ad"
        ad.translatesAutoresizingMaskIntoConstraints = false
        let label = UILabel()
        label.text = "Advertisement (tap)"
        label.translatesAutoresizingMaskIntoConstraints = false
        ad.addSubview(label)
        ad.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(adTapped)))
        let attribution = UIEventAttributionView()
        attribution.translatesAutoresizingMaskIntoConstraints = false
        ad.addSubview(attribution)
        view.addSubview(ad)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: g.topAnchor, constant: 12), stack.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -20),
            ad.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 16), ad.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 20),
            ad.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -20), ad.heightAnchor.constraint(equalToConstant: 80),
            label.centerXAnchor.constraint(equalTo: ad.centerXAnchor), label.centerYAnchor.constraint(equalTo: ad.centerYAnchor),
            attribution.leadingAnchor.constraint(equalTo: ad.leadingAnchor), attribution.trailingAnchor.constraint(equalTo: ad.trailingAnchor),
            attribution.topAnchor.constraint(equalTo: ad.topAnchor), attribution.bottomAnchor.constraint(equalTo: ad.bottomAnchor),
        ])
        let launches = UserDefaults.standard.integer(forKey: "launches") + 1     // a required-reason API (manifest: CA92.1)
        UserDefaults.standard.set(launches, forKey: "launches")
        log("launch \(launches)")
        log("tracking=\(ATTrackingManager.trackingAuthorizationStatus.rawValue) idfa=\(ASIdentifierManager.shared().advertisingIdentifier.uuidString)")
    }

    // MARK: App Tracking Transparency and the privacy manifest's tracking domain (localhost)
    @objc func allowTracking() {
        ATTrackingManager.requestTrackingAuthorization { status in
            log("tracking authorization: \(status.rawValue) idfa=\(ASIdentifierManager.shared().advertisingIdentifier.uuidString)")
        }
    }
    @objc func ping() {
        let url = URL(string: (arg("-tracker") ?? "http://localhost:8765") + "/")!
        URLSession.shared.dataTask(with: url) { _, response, error in
            log("tracker ping: status=\((response as? HTTPURLResponse)?.statusCode ?? 0) error=\(error.map { "\(($0 as NSError).code)" } ?? "none")")
        }.resume()
    }

    // MARK: AdServices
    @objc func token() {
        do { log("attribution token: \(try AAAttribution.attributionToken().prefix(12))…") } catch {
            log("attribution token failed: \((error as NSError).domain) \((error as NSError).code)")
        }
    }

    // MARK: conversion values (SKAdNetwork and AdAttributionKit share them)
    @objc func skan() {
        SKAdNetwork.updatePostbackConversionValue(12, coarseValue: .medium, lockWindow: false) { error in
            log("SKAdNetwork update 12/medium: error=\(error.map { "\(($0 as NSError).code)" } ?? "none")")
            SKAdNetwork.updatePostbackConversionValue(99) { error in      // out of range
                log("SKAdNetwork update 99: error=\(error.map { "\(($0 as NSError).domain) \(($0 as NSError).code)" } ?? "none")")
            }
        }
    }
    @objc func postback() {
        Task {
            do { try await Postback.updateConversionValue(42, coarseConversionValue: .high, lockPostback: false); log("postback update 42/high ok") }
            catch { log("postback update failed: \(error)") }
        }
    }
    @objc func lockPostback() {
        Task {
            do {
                try await Postback.updateConversionValue(PostbackUpdate(fineConversionValue: 50, lockPostback: true, coarseConversionValue: .high))
                log("postback locked at 50/high")
            } catch { log("postback lock failed: \(error)") }
        }
    }

    // MARK: AdAttributionKit impressions
    @objc func loadImpression() {
        Task {
            do {
                let i = try await AppImpression(compactJWS: sampleImpressionJWS())
                impression = i
                log("impression: network=\(i.adNetworkID) advertised=\(i.advertisedItemID) source=\(i.sourceID) kid=\(i.keyID)")
            } catch { log("impression failed: \(error)") }
            do { _ = try await AppImpression(compactJWS: "bm90.YQ.x") } catch { log("bad impression: \(error)") }
        }
    }
    @objc func adTapped() {
        guard let impression else { log("no impression loaded"); return }
        Task {
            do { try await impression.handleTap(); log("click-through recorded") } catch { log("click-through failed: \(error)") }
        }
    }
    @objc func viewAd() {
        guard let impression else { log("no impression loaded"); return }
        Task {
            do {
                try await impression.beginView()
                try await Task.sleep(nanoseconds: 2_200_000_000)
                try await impression.endView()
                log("view-through recorded")
            } catch { log("view-through failed: \(error)") }
            // a handleTap without a tap on the attribution view fails
            do { try await impression.handleTap() } catch { log("tap without attribution view: \(error)") }
        }
    }
}
