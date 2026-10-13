// Third-party sample: Google's real Google Mobile Ads SDK (its Swift package, fetched by `isim build`; isim does not
// re-implement it). It starts the SDK and loads a banner and an interstitial with Google's public test ad unit IDs, and
// logs what happens, to show whether the SDK runs on isim. Needs the network (the package and Google's ad servers).
//   isim build -project samples/ThirdParty/GoogleAds/GoogleAds.xcodeproj -o /tmp/ga && isim run /tmp/ga/GoogleAds.app
import UIKit
import GoogleMobileAds

func log(_ s: String) { FileHandle.standardError.write(Data(("GoogleAds: " + s + "\n").utf8)) }

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = AdsViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

final class AdsViewController: UIViewController, BannerViewDelegate {
    var banner: BannerView!
    var interstitial: InterstitialAd?
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        banner = BannerView(adSize: AdSizeBanner)
        banner.adUnitID = "ca-app-pub-3940256099942544/2934735716"       // Google's test banner unit
        banner.rootViewController = self
        banner.delegate = self
        banner.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(banner)
        NSLayoutConstraint.activate([banner.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
                                     banner.centerXAnchor.constraint(equalTo: view.centerXAnchor)])
        log("SDK started")
        MobileAds.shared.start { status in
            log("started: \(status.adapterStatusesByClassName.map { "\($0.key)=\($0.value.state.rawValue)" }.sorted().joined(separator: " "))")
            self.banner.load(Request())
            InterstitialAd.load(with: "ca-app-pub-3940256099942544/4411468910", request: Request()) { ad, error in
                if let error { log("interstitial failed: \((error as NSError).code) \(error.localizedDescription)"); return }
                log("interstitial loaded")
                self.interstitial = ad
                ad?.present(from: self)
            }
        }
    }
    func bannerViewDidReceiveAd(_ bannerView: BannerView) { log("banner received") }
    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        log("banner failed: \((error as NSError).code) \(error.localizedDescription)")
    }
    func bannerViewDidRecordImpression(_ bannerView: BannerView) { log("banner impression") }
}
