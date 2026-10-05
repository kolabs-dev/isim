// isim stand-in for the Google Mobile Ads SDK (a closed-source binary SDK isim does not fetch or run).
// It lets apps that integrate the SDK build and run: starting succeeds, every ad load fails with an
// error saying ads are unavailable on isim, so apps take their "no ad" paths. No network requests.
import UIKit

let _unavailable = NSError(domain: "com.google.admob", code: 1,
                           userInfo: [NSLocalizedDescriptionKey: "isim stand-in: Google Mobile Ads is not available on isim (no ads are served)"])

public struct AdapterStatus: Sendable { public let state = 0; public let latency = 0.0; public let description = "isim stand-in" }
public final class InitializationStatus: NSObject, @unchecked Sendable {
    public var adapterStatusesByClassName: [String: AdapterStatus] { [:] }
}

public final class MobileAds: NSObject, @unchecked Sendable {
    public static let shared = MobileAds()
    public let requestConfiguration = RequestConfiguration()
    public var applicationVolume: Float = 1
    public var isApplicationMuted = false
    public func start(completionHandler: ((InitializationStatus) -> Void)? = nil) {
        NSLog("isim: Google Mobile Ads stand-in started (no ads are served on isim)")
        DispatchQueue.main.async { completionHandler?(InitializationStatus()) }
    }
    public func start() async -> InitializationStatus { InitializationStatus() }
}
public final class RequestConfiguration: NSObject, @unchecked Sendable {
    public var testDeviceIdentifiers: [String]?
    public var maxAdContentRating: String?
    public var tagForChildDirectedTreatment: NSNumber?
    public var tagForUnderAgeOfConsent: NSNumber?
}

open class Request: NSObject {
    open var keywords: [String]?
    open var contentURL: String?
    public override init() {}
}

@objc public protocol FullScreenPresentingAd: NSObjectProtocol {
    weak var fullScreenContentDelegate: FullScreenContentDelegate? { get set }
}
@objc public protocol FullScreenContentDelegate: NSObjectProtocol {
    @objc optional func adDidRecordImpression(_ ad: FullScreenPresentingAd)
    @objc optional func adDidRecordClick(_ ad: FullScreenPresentingAd)
    @objc optional func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error)
    @objc optional func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd)
    @objc optional func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd)
    @objc optional func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd)
}

public final class AdReward: NSObject, @unchecked Sendable {
    public let type = ""
    public let amount = NSDecimalNumberStandIn()
}
public final class NSDecimalNumberStandIn: NSObject, @unchecked Sendable { public var intValue: Int { 0 } }

open class RewardedAd: NSObject, FullScreenPresentingAd {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var adReward: AdReward { AdReward() }
    open var adUnitID: String { "" }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (RewardedAd?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, _unavailable) }
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> RewardedAd { throw _unavailable }
    open func present(from rootViewController: UIViewController?, userDidEarnRewardHandler: @escaping () -> Void) {
        fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: _unavailable)
    }
    open func canPresent(from rootViewController: UIViewController?) throws { throw _unavailable }
}

open class InterstitialAd: NSObject, FullScreenPresentingAd {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var adUnitID: String { "" }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (InterstitialAd?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, _unavailable) }
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> InterstitialAd { throw _unavailable }
    open func present(from rootViewController: UIViewController?) {
        fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: _unavailable)
    }
    open func canPresent(from rootViewController: UIViewController?) throws { throw _unavailable }
}

open class AppOpenAd: NSObject, FullScreenPresentingAd {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (AppOpenAd?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, _unavailable) }
    }
    open func present(from rootViewController: UIViewController?) {
        fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: _unavailable)
    }
}

public struct AdSize: Sendable { public var size: CGSize; public var flags: UInt = 0 }
public let AdSizeBanner = AdSize(size: CGSize(width: 320, height: 50))
public let AdSizeLargeBanner = AdSize(size: CGSize(width: 320, height: 100))
public let AdSizeMediumRectangle = AdSize(size: CGSize(width: 300, height: 250))
public func currentOrientationAnchoredAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: 50)) }

@objc public protocol BannerViewDelegate: NSObjectProtocol {
    @objc optional func bannerViewDidReceiveAd(_ bannerView: BannerView)
    @objc optional func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error)
}
/// An empty view: no banner is ever loaded on isim.
open class BannerView: UIView {
    open var adUnitID: String?
    weak open var rootViewController: UIViewController?
    weak open var delegate: BannerViewDelegate?
    open var adSize: AdSize
    public init(adSize: AdSize) { self.adSize = adSize; super.init(frame: CGRect(origin: .zero, size: adSize.size)) }
    public required init?(coder: NSCoder) { adSize = AdSizeBanner; super.init(frame: .zero) }
    open func load(_ request: Request?) {
        DispatchQueue.main.async { self.delegate?.bannerView?(self, didFailToReceiveAdWithError: _unavailable) }
    }
}
