// Sample: ads and privacy on isim — Google's User Messaging Platform consent flow at launch (GDPR form in the EEA,
// IAB TCF keys), then the Google Mobile Ads test ads: an anchored adaptive banner, interstitial, rewarded, rewarded
// interstitial, app open and native ads, and the privacy options form.
//   isim run out/apps/HelloAds.app [-- -geography eea|us|other] [-reset]
// The ad unit IDs are Google's public sample IDs (any ID gets a test ad on isim).
import UIKit
import GoogleMobileAds
import UserMessagingPlatform
import AppTrackingTransparency

func log(_ s: String) { FileHandle.standardError.write(Data(("HelloAds: " + s + "\n").utf8)) }   // unbuffered
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
        window?.rootViewController = UINavigationController(rootViewController: AdsViewController())
        window?.makeKeyAndVisible()
        return true
    }
}

final class AdsViewController: UIViewController, BannerViewDelegate, FullScreenContentDelegate, NativeAdLoaderDelegate, NativeAdDelegate {
    var banner: BannerView!
    var interstitial: InterstitialAd?, rewarded: RewardedAd?, rewardedInterstitial: RewardedInterstitialAd?, appOpen: AppOpenAd?
    var adLoader: AdLoader?
    let nativeView = NativeAdView()
    let status = UILabel()
    var coins = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Ads"
        view.backgroundColor = .systemGroupedBackground
        status.numberOfLines = 0
        status.font = .systemFont(ofSize: 13)
        status.accessibilityIdentifier = "status"
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        for (title, id, action) in [("Interstitial", "interstitial", #selector(showInterstitial)), ("Rewarded", "rewarded", #selector(showRewarded)),
                                    ("Rewarded Interstitial", "rewardedInterstitial", #selector(showRewardedInterstitial)),
                                    ("App Open", "appOpen", #selector(showAppOpen)), ("Native", "native", #selector(loadNative)),
                                    ("Privacy Settings", "privacy", #selector(privacy)), ("Ping Tracker", "track", #selector(ping)),
                                    ("Allow Tracking", "att", #selector(allowTracking))] {
            let b = UIButton(type: .system)
            b.setTitle(title, for: .normal)
            b.contentHorizontalAlignment = .leading
            b.accessibilityIdentifier = id
            b.addTarget(self, action: action, for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        stack.addArrangedSubview(status)
        nativeView.translatesAutoresizingMaskIntoConstraints = false
        nativeView.backgroundColor = .white
        nativeView.isHidden = true
        nativeView.accessibilityIdentifier = "nativeAd"
        let headline = UILabel(), body = UILabel(), cta = UIButton(type: .system), media = MediaView()
        headline.font = .boldSystemFont(ofSize: 15); body.font = .systemFont(ofSize: 13); body.numberOfLines = 2
        headline.accessibilityIdentifier = "nativeHeadline"
        cta.accessibilityIdentifier = "nativeCTA"
        for v in [headline, body, cta, media] { v.translatesAutoresizingMaskIntoConstraints = false; nativeView.addSubview(v) }
        nativeView.headlineView = headline; nativeView.bodyView = body; nativeView.callToActionView = cta; nativeView.mediaView = media
        view.addSubview(nativeView)
        let g = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: g.topAnchor, constant: 12), stack.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -20),
            nativeView.topAnchor.constraint(equalTo: stack.bottomAnchor, constant: 12), nativeView.leadingAnchor.constraint(equalTo: g.leadingAnchor, constant: 20),
            nativeView.trailingAnchor.constraint(equalTo: g.trailingAnchor, constant: -20), nativeView.heightAnchor.constraint(equalToConstant: 170),
            headline.topAnchor.constraint(equalTo: nativeView.topAnchor, constant: 8), headline.leadingAnchor.constraint(equalTo: nativeView.leadingAnchor, constant: 8),
            headline.trailingAnchor.constraint(equalTo: nativeView.trailingAnchor, constant: -40),
            body.topAnchor.constraint(equalTo: headline.bottomAnchor, constant: 2), body.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            body.trailingAnchor.constraint(equalTo: nativeView.trailingAnchor, constant: -8),
            media.topAnchor.constraint(equalTo: body.bottomAnchor, constant: 4), media.leadingAnchor.constraint(equalTo: headline.leadingAnchor),
            media.widthAnchor.constraint(equalToConstant: 140), media.bottomAnchor.constraint(equalTo: nativeView.bottomAnchor, constant: -8),
            cta.trailingAnchor.constraint(equalTo: nativeView.trailingAnchor, constant: -12), cta.bottomAnchor.constraint(equalTo: nativeView.bottomAnchor, constant: -12),
        ])
        let width = view.bounds.width
        banner = BannerView(adSize: currentOrientationAnchoredAdaptiveBanner(width: width))
        banner.adUnitID = "ca-app-pub-3940256099942544/2435281174"
        banner.rootViewController = self
        banner.delegate = self
        banner.accessibilityIdentifier = "banner"
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([banner.bottomAnchor.constraint(equalTo: g.bottomAnchor), banner.centerXAnchor.constraint(equalTo: g.centerXAnchor)])
        gatherConsent()
    }

    // MARK: consent, then ads

    func gatherConsent() {
        if ProcessInfo.processInfo.arguments.contains("-reset") { ConsentInformation.shared.reset() }
        let params = RequestParameters()
        let debug = DebugSettings()
        switch arg("-geography") {
        case "eea"?: debug.geography = .EEA
        case "us"?: debug.geography = .regulatedUSState
        case "other"?: debug.geography = .other
        default: break
        }
        params.debugSettings = debug
        ConsentInformation.shared.requestConsentInfoUpdate(with: params) { [weak self] error in
            guard let self else { return }
            let info = ConsentInformation.shared
            log("consent info: error=\(error?.localizedDescription ?? "none") status=\(info.consentStatus.rawValue) form=\(info.formStatus.rawValue) privacyOptions=\(info.privacyOptionsRequirementStatus.rawValue)")
            ConsentForm.loadAndPresentIfRequired(from: self) { error in
                log("consent gathered: error=\(error?.localizedDescription ?? "none") status=\(info.consentStatus.rawValue) canRequestAds=\(info.canRequestAds)")
                let d = UserDefaults.standard
                log("IABTCF gdprApplies=\(d.object(forKey: "IABTCF_gdprApplies") ?? "-") purposes=\(d.string(forKey: "IABTCF_PurposeConsents") ?? "-") "
                    + "tcString=\(d.string(forKey: "IABTCF_TCString").map { "\($0.prefix(8))…(\($0.count))" } ?? "-") cmp=\(d.object(forKey: "IABTCF_CmpSdkID") ?? "-")")
                if info.canRequestAds { self.startAds() }
            }
        }
    }
    var started = false
    func startAds() {
        guard !started else { return }
        started = true
        MobileAds.shared.start { status in
            log("ads started: adapters=\(status.adapterStatusesByClassName.count)")
            self.banner.load(Request())
        }
    }

    // MARK: banner
    func bannerViewDidReceiveAd(_ bannerView: BannerView) { log("banner received \(Int(bannerView.bounds.width))x\(Int(bannerView.bounds.height))") }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) { log("banner failed: \((error as NSError).code) \(error.localizedDescription)") }
    func bannerViewDidRecordImpression(_ bannerView: BannerView) { log("banner impression") }
    func bannerViewDidRecordClick(_ bannerView: BannerView) { log("banner click") }
    func bannerViewWillPresentScreen(_ bannerView: BannerView) { log("banner will present screen") }
    func bannerViewDidDismissScreen(_ bannerView: BannerView) { log("banner did dismiss screen") }

    // MARK: full-screen ads
    @objc func showInterstitial() {
        InterstitialAd.load(with: "ca-app-pub-3940256099942544/4411468910", request: Request()) { ad, error in
            guard let ad else { log("interstitial failed: \((error! as NSError).code)"); return }
            log("interstitial loaded")
            self.interstitial = ad
            ad.fullScreenContentDelegate = self
            ad.present(from: self)
        }
    }
    @objc func showRewarded() {
        RewardedAd.load(with: "ca-app-pub-3940256099942544/1712485313", request: Request()) { ad, error in
            guard let ad else { log("rewarded failed: \((error! as NSError).code)"); return }
            log("rewarded loaded: reward \(ad.adReward.amount) \(ad.adReward.type)")
            self.rewarded = ad
            ad.fullScreenContentDelegate = self
            ad.present(from: self) {
                self.coins += Int(ad.adReward.amount.intValue)
                log("user earned reward: coins=\(self.coins)")
            }
        }
    }
    @objc func showRewardedInterstitial() {
        RewardedInterstitialAd.load(with: "ca-app-pub-3940256099942544/6978759866", request: Request()) { ad, error in
            guard let ad else { log("rewarded interstitial failed: \((error! as NSError).code)"); return }
            self.rewardedInterstitial = ad
            ad.fullScreenContentDelegate = self
            ad.present(from: self) { log("user earned rewarded interstitial reward") }
        }
    }
    @objc func showAppOpen() {
        AppOpenAd.load(with: "ca-app-pub-3940256099942544/5575463023", request: Request()) { ad, error in
            guard let ad else { log("app open failed: \((error! as NSError).code)"); return }
            self.appOpen = ad
            ad.fullScreenContentDelegate = self
            ad.present(from: self)
            ad.present(from: self)                                // a second present fails: each ad shows once
        }
    }
    func name(_ ad: FullScreenPresentingAd) -> String {
        ad is InterstitialAd ? "interstitial" : ad is RewardedAd ? "rewarded" : ad is RewardedInterstitialAd ? "rewardedInterstitial" : "appOpen"
    }
    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) { log("\(name(ad)) will present") }
    func adDidRecordImpression(_ ad: FullScreenPresentingAd) { log("\(name(ad)) impression") }
    func adDidRecordClick(_ ad: FullScreenPresentingAd) { log("\(name(ad)) click") }
    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) { log("\(name(ad)) failed to present: \((error as NSError).code)") }
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) { log("\(name(ad)) dismissed") }

    // MARK: native
    @objc func loadNative() {
        adLoader = AdLoader(adUnitID: "ca-app-pub-3940256099942544/3986624511", rootViewController: self, adTypes: [.native], options: nil)
        adLoader?.delegate = self
        adLoader?.load(Request())
    }
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        log("native received: \(nativeAd.headline ?? "-") cta=\(nativeAd.callToAction ?? "-")")
        nativeAd.delegate = self
        (nativeView.headlineView as? UILabel)?.text = nativeAd.headline
        (nativeView.bodyView as? UILabel)?.text = nativeAd.body
        (nativeView.callToActionView as? UIButton)?.setTitle(nativeAd.callToAction, for: .normal)
        nativeView.isHidden = false
        nativeView.nativeAd = nativeAd
    }
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error) { log("native failed: \((error as NSError).code)") }
    func nativeAdDidRecordImpression(_ nativeAd: NativeAd) { log("native impression") }
    func nativeAdDidRecordClick(_ nativeAd: NativeAd) { log("native click") }

    // MARK: tracking domains (PrivacyInfo.xcprivacy lists localhost) and App Tracking Transparency
    @objc func ping() {
        let url = URL(string: (arg("-tracker") ?? "http://localhost:8765") + "/")!
        URLSession.shared.dataTask(with: url) { _, response, error in
            log("tracker ping: status=\((response as? HTTPURLResponse)?.statusCode ?? 0) error=\(error.map { "\(($0 as NSError).code)" } ?? "none")")
        }.resume()
    }
    @objc func allowTracking() {
        ATTrackingManager.requestTrackingAuthorization { status in log("tracking authorization: \(status.rawValue)") }
    }

    // MARK: privacy options
    @objc func privacy() {
        ConsentForm.presentPrivacyOptionsForm(from: self) { error in
            let d = UserDefaults.standard
            log("privacy options done: error=\(error.map { "\(($0 as NSError).code)" } ?? "none") purposes=\(d.string(forKey: "IABTCF_PurposeConsents") ?? "-")")
        }
    }
}
