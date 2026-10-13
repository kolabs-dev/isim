// isim stand-in for the Google Mobile Ads SDK (a closed-source binary SDK isim does not fetch or run), API of SDK 12.
//
// Adapted: like an app on Apple's Simulator, which Google always treats as a test device, an app on isim gets test
// ads. The stand-in draws isim's own "Test Ad" creatives (_Ads/TestAds.swift) for every ad unit and runs the SDK's
// flow around them: MobileAds.start with adapter statuses, banner loads with impressions and clicks (a landing
// page between bannerViewWillPresentScreen and bannerViewDidDismissScreen), interstitial / rewarded / rewarded
// interstitial / app open ads presented full screen with their FullScreenContentDelegate calls, rewards after a
// countdown, native ads through AdLoader and NativeAdView, response info and paid events (value 0: nothing is
// earned). Each full-screen ad shows once (a second present fails with "ad already used"). Nothing is sent over the
// network. Like the SDK, starting without GADApplicationIdentifier in Info.plist raises
// GADInvalidInitializationException. ISIM_ADS=nofill / =error make loads fail (no fill / network error).
import UIKit

// MARK: - errors

public let GADErrorDomain = "com.google.admob"
public enum RequestError: Int, Sendable {
    case invalidRequest = 0, noFill = 1, networkError = 2, serverError = 3, osVersionTooLow = 4, timeout = 5
    case mediationDataError = 7, mediationAdapterError = 8, mediationInvalidAdSize = 10, internalError = 11
    case invalidArgument = 12, receivedInvalidResponse = 13, mediationNoFill = 9, adAlreadyUsed = 19, applicationIdentifierMissing = 20
}
func _gadError(_ code: RequestError, _ message: String) -> NSError {
    NSError(domain: GADErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: message])
}
/// the error of a load, nil when a test ad fills it
func _gadLoadError(_ adUnitID: String) -> NSError? {
    if !_GADApp.hasApplicationID { return _gadError(.applicationIdentifierMissing, "The Google Mobile Ads SDK was initialized without an application ID.") }
    if adUnitID.isEmpty { return _gadError(.invalidRequest, "Invalid Request. Cannot determine request type. Is your ad unit id correct?") }
    switch _TestAds.mode {
    case .noFill: return _gadError(.noFill, "Request Error: No ad to show.")
    case .networkError: return _gadError(.networkError, "Network error: the Internet connection appears to be offline.")
    case .fill: return nil
    }
}
let _unavailable = _gadError(.adAlreadyUsed, "Ad was already used.")

enum _GADApp {
    static var hasApplicationID: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String).map { !$0.isEmpty } ?? false
    }
    static var started = false
    static func checkApplicationID() {
        guard !hasApplicationID else { return }
        NSException(name: "GADInvalidInitializationException",
                    reason: "The Google Mobile Ads SDK was initialized without an application ID. Google AdMob publishers, follow instructions at "
                        + "https://googlemobileadssdk.page.link/admob-ios-update-plist to set a valid application ID. Google Ad Manager "
                        + "publishers, follow instructions at https://googlemobileadssdk.page.link/ad-manager-ios-update-plist.",
                    userInfo: nil).raise()
    }
}

// MARK: - initialization

public enum AdapterInitializationState: Int, Sendable { case notReady = 0, ready = 1 }
public struct AdapterStatus: Sendable {
    public let state = 0
    public let latency = 0.0
    public let description = "isim stand-in: test ads"
    public var initializationState: AdapterInitializationState { .ready }
}
public final class InitializationStatus: NSObject, @unchecked Sendable {
    public var adapterStatusesByClassName: [String: AdapterStatus] { ["GADMobileAds": AdapterStatus()] }
}

public final class MobileAds: NSObject, @unchecked Sendable {
    public static let shared = MobileAds()
    public let requestConfiguration = RequestConfiguration()
    public var applicationVolume: Float = 1
    public var isApplicationMuted = false
    public var versionNumber: String { "12.0.0 (isim stand-in)" }
    public func start(completionHandler: ((InitializationStatus) -> Void)? = nil) {
        _GADApp.checkApplicationID()
        _GADApp.started = true
        print("isim: Google Mobile Ads stand-in started: test ads (isim draws them locally, nothing is requested)")
        DispatchQueue.main.async { completionHandler?(InitializationStatus()) }
    }
    public func start() async -> InitializationStatus {
        await withCheckedContinuation { k in start { k.resume(returning: $0) } }
    }
    public func disableSDKCrashReporting() {}
    public func disableMediationInitialization() {}
}
public final class RequestConfiguration: NSObject, @unchecked Sendable {
    public var testDeviceIdentifiers: [String]?
    public var maxAdContentRating: String?
    public var tagForChildDirectedTreatment: NSNumber?
    public var tagForUnderAgeOfConsent: NSNumber?
    public var publisherPrivacyPersonalizationState = 0
}
public let GADMaxAdContentRatingGeneral = "G", GADMaxAdContentRatingParentalGuidance = "PG",
           GADMaxAdContentRatingTeen = "T", GADMaxAdContentRatingMatureAudience = "MA"

open class Request: NSObject {
    open var keywords: [String]?
    open var contentURL: String?
    open var neighboringContentURLStrings: [String]?
    open var requestAgent: String?
    public override init() {}
}

// MARK: - response info and paid events

public final class AdNetworkResponseInfo: NSObject, @unchecked Sendable {
    public let adNetworkClassName = "GADMAdapterGoogleAdMobAds"
    public let adSourceName = "isim test ads"
    public let latency: TimeInterval = 0
    public let error: Error? = nil
}
public final class ResponseInfo: NSObject, @unchecked Sendable {
    public let responseIdentifier: String? = UUID().uuidString
    public let adNetworkInfoArray = [AdNetworkResponseInfo()]
    public var loadedAdNetworkResponseInfo: AdNetworkResponseInfo? { adNetworkInfoArray.first }
    public var extrasDictionary: [String: Any] { ["isim": "test ad"] }
}
public enum AdValuePrecision: Int, Sendable { case unknown = 0, estimated = 1, publisherProvided = 2, precise = 3 }
public final class AdValue: NSObject, @unchecked Sendable {
    public let value = NSDecimalNumber.zero
    public let precision = AdValuePrecision.precise
    public let currencyCode = "USD"
}
public typealias PaidEventHandler = (AdValue) -> Void

// MARK: - full-screen ads

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
    public let type: String
    public let amount: NSDecimalNumber
    public init(rewardType: String, rewardAmount: NSDecimalNumber) { type = rewardType; amount = rewardAmount }
    // isim ABI: until 0.20 `amount` was this placeholder type; keep its getter for apps built then
    @usableFromInline @_silgen_name("$s15GoogleMobileAds8AdRewardC6amountAA22NSDecimalNumberStandInCvg")
    final func _abi_amountStandIn() -> NSDecimalNumberStandIn { NSDecimalNumberStandIn(Int(amount.intValue)) }
}
/// isim ABI: the placeholder AdReward.amount had until 0.20 (AdReward.amount is an NSDecimalNumber now)
public final class NSDecimalNumberStandIn: NSObject, @unchecked Sendable {
    let value: Int
    init(_ v: Int) { value = v; super.init() }
    public override init() { value = 0; super.init() }
    public var intValue: Int { value }
}
public final class ServerSideVerificationOptions: NSObject, @unchecked Sendable {
    public var userIdentifier: String?
    public var customRewardString: String?
}

/// what the full-screen ad classes share: one presentation, the delegate calls around it
protocol _GADFullScreen: FullScreenPresentingAd {
    var unitID: String { get }
    var used: Bool { get set }
    var paidEventHandler: PaidEventHandler? { get }
    var testKind: _TestAdFullScreenController.Kind { get }
    var label: String { get }
}
extension _GADFullScreen {
    func checkPresent(_ rootViewController: UIViewController?) throws {
        if used { throw _unavailable }
        if _TestAds.presenter(rootViewController) == nil { throw _gadError(.internalError, "No view controller to present from.") }
    }
    func show(from rootViewController: UIViewController?, reward: (() -> Void)?) {
        do { try checkPresent(rootViewController) } catch {
            fullScreenContentDelegate?.ad?(self, didFailToPresentFullScreenContentWithError: error); return
        }
        used = true
        let vc = _TestAdFullScreenController(kind: testKind, network: "Google AdMob")
        vc.onImpression = { [weak self] in
            guard let self else { return }
            self.fullScreenContentDelegate?.adDidRecordImpression?(self)
            self.paidEventHandler?(AdValue())
        }
        vc.onClick = { [weak self] in guard let self else { return }; self.fullScreenContentDelegate?.adDidRecordClick?(self) }
        vc.onReward = reward
        vc.onWillDismiss = { [weak self] in guard let self else { return }; self.fullScreenContentDelegate?.adWillDismissFullScreenContent?(self) }
        vc.onDidDismiss = { [weak self] in
            guard let self else { return }
            print("isim: Google Mobile Ads test \(self.label) ad dismissed")
            self.fullScreenContentDelegate?.adDidDismissFullScreenContent?(self)
        }
        fullScreenContentDelegate?.adWillPresentFullScreenContent?(self)
        print("isim: Google Mobile Ads test \(label) ad shown (\(unitID))")
        _TestAds.presenter(rootViewController)?.present(vc, animated: true)
    }
}
func _gadLoad<T>(_ make: @escaping () -> T, _ adUnitID: String, _ name: String, _ done: @escaping (T?, Error?) -> Void) {
    let err = _gadLoadError(adUnitID)
    print("isim: Google Mobile Ads test \(name) ad \(err == nil ? "loaded" : "failed: \(err!.localizedDescription)") (\(adUnitID))")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { err == nil ? done(make(), nil) : done(nil, err) }
}
func _gadAwait<T>(_ load: (@escaping (T?, Error?) -> Void) -> Void) async throws -> T {
    try await withCheckedThrowingContinuation { k in load { a, e in a.map { k.resume(returning: $0) } ?? k.resume(throwing: e ?? _gadError(.internalError, "Internal error.")) } }
}

open class InterstitialAd: NSObject, _GADFullScreen {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var paidEventHandler: PaidEventHandler?
    public let responseInfo = ResponseInfo()
    var unitID = "", used = false
    var testKind: _TestAdFullScreenController.Kind { .interstitial }
    var label: String { "interstitial" }
    public override init() { super.init() }
    open var adUnitID: String { unitID }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (InterstitialAd?, Error?) -> Void) {
        _gadLoad({ let a = InterstitialAd(); a.unitID = adUnitID; return a }, adUnitID, "interstitial", completionHandler)
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> InterstitialAd {
        try await _gadAwait { load(with: adUnitID, request: request, completionHandler: $0) }
    }
    open func canPresent(from rootViewController: UIViewController?) throws { try checkPresent(rootViewController) }
    open func present(from rootViewController: UIViewController?) { show(from: rootViewController, reward: nil) }
}

open class RewardedAd: NSObject, _GADFullScreen {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var paidEventHandler: PaidEventHandler?
    open var serverSideVerificationOptions: ServerSideVerificationOptions?
    public let responseInfo = ResponseInfo()
    var unitID = "", used = false
    var testKind: _TestAdFullScreenController.Kind { .rewarded(seconds: _TestAds.rewardSeconds) }
    var label: String { "rewarded" }
    public override init() { super.init() }
    open var adReward: AdReward { AdReward(rewardType: "coins", rewardAmount: NSDecimalNumber(value: 10)) }
    open var adUnitID: String { unitID }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (RewardedAd?, Error?) -> Void) {
        _gadLoad({ let a = RewardedAd(); a.unitID = adUnitID; return a }, adUnitID, "rewarded", completionHandler)
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> RewardedAd {
        try await _gadAwait { load(with: adUnitID, request: request, completionHandler: $0) }
    }
    open func canPresent(from rootViewController: UIViewController?) throws { try checkPresent(rootViewController) }
    open func present(from rootViewController: UIViewController?, userDidEarnRewardHandler: @escaping () -> Void) {
        show(from: rootViewController, reward: userDidEarnRewardHandler)
    }
}

open class RewardedInterstitialAd: NSObject, _GADFullScreen {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var paidEventHandler: PaidEventHandler?
    open var serverSideVerificationOptions: ServerSideVerificationOptions?
    public let responseInfo = ResponseInfo()
    var unitID = "", used = false
    var testKind: _TestAdFullScreenController.Kind { .rewarded(seconds: _TestAds.rewardSeconds) }
    var label: String { "rewarded interstitial" }
    public override init() { super.init() }
    open var adReward: AdReward { AdReward(rewardType: "coins", rewardAmount: NSDecimalNumber(value: 10)) }
    open var adUnitID: String { unitID }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (RewardedInterstitialAd?, Error?) -> Void) {
        _gadLoad({ let a = RewardedInterstitialAd(); a.unitID = adUnitID; return a }, adUnitID, "rewarded interstitial", completionHandler)
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> RewardedInterstitialAd {
        try await _gadAwait { load(with: adUnitID, request: request, completionHandler: $0) }
    }
    open func canPresent(from rootViewController: UIViewController?) throws { try checkPresent(rootViewController) }
    open func present(from rootViewController: UIViewController?, userDidEarnRewardHandler: @escaping () -> Void) {
        show(from: rootViewController, reward: userDidEarnRewardHandler)
    }
}

open class AppOpenAd: NSObject, _GADFullScreen {
    weak open var fullScreenContentDelegate: FullScreenContentDelegate?
    open var paidEventHandler: PaidEventHandler?
    public let responseInfo = ResponseInfo()
    var unitID = "", used = false
    var testKind: _TestAdFullScreenController.Kind { .appOpen }
    var label: String { "app open" }
    public override init() { super.init() }
    open var adUnitID: String { unitID }
    public class func load(with adUnitID: String, request: Request?, completionHandler: @escaping (AppOpenAd?, Error?) -> Void) {
        _gadLoad({ let a = AppOpenAd(); a.unitID = adUnitID; return a }, adUnitID, "app open", completionHandler)
    }
    public class func load(with adUnitID: String, request: Request?) async throws -> AppOpenAd {
        try await _gadAwait { load(with: adUnitID, request: request, completionHandler: $0) }
    }
    open func canPresent(from rootViewController: UIViewController?) throws { try checkPresent(rootViewController) }
    open func present(from rootViewController: UIViewController?) { show(from: rootViewController, reward: nil) }
}

// MARK: - banners

public struct AdSize: Sendable { public var size: CGSize; public var flags: UInt = 0 }
public let AdSizeBanner = AdSize(size: CGSize(width: 320, height: 50))
public let AdSizeLargeBanner = AdSize(size: CGSize(width: 320, height: 100))
public let AdSizeMediumRectangle = AdSize(size: CGSize(width: 300, height: 250))
public let AdSizeFullBanner = AdSize(size: CGSize(width: 468, height: 60))
public let AdSizeLeaderboard = AdSize(size: CGSize(width: 728, height: 90))
public let AdSizeSkyscraper = AdSize(size: CGSize(width: 120, height: 600))
public let AdSizeFluid = AdSize(size: CGSize(width: 0, height: 0), flags: 1)
public let AdSizeInvalid = AdSize(size: .zero, flags: 0)
/// the height Google's anchored adaptive banners get for a width: about 15% of it, between 50 and 90 points
func _anchoredHeight(_ width: CGFloat) -> CGFloat { max(50, min(90, (width * 0.15).rounded())) }
public func currentOrientationAnchoredAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: _anchoredHeight(width))) }
public func portraitAnchoredAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: _anchoredHeight(width))) }
public func landscapeAnchoredAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: _anchoredHeight(width))) }
public func largeAnchoredAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: max(50, min(150, (width * 0.25).rounded())))) }
public func currentOrientationInlineAdaptiveBanner(width: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: 0), flags: 2) }
public func inlineAdaptiveBanner(width: CGFloat, maxHeight: CGFloat) -> AdSize { AdSize(size: CGSize(width: width, height: maxHeight), flags: 2) }
public func adSizeFor(cgSize size: CGSize) -> AdSize { AdSize(size: size) }
public func isAdSizeValid(_ size: AdSize) -> Bool { size.size.width > 0 || size.flags != 0 }

@objc public protocol BannerViewDelegate: NSObjectProtocol {
    @objc optional func bannerViewDidReceiveAd(_ bannerView: BannerView)
    @objc optional func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error)
    @objc optional func bannerViewDidRecordImpression(_ bannerView: BannerView)
    @objc optional func bannerViewDidRecordClick(_ bannerView: BannerView)
    @objc optional func bannerViewWillPresentScreen(_ bannerView: BannerView)
    @objc optional func bannerViewWillDismissScreen(_ bannerView: BannerView)
    @objc optional func bannerViewDidDismissScreen(_ bannerView: BannerView)
}
public protocol AdSizeDelegate: AnyObject {
    func adView(_ bannerView: BannerView, willChangeAdSizeTo size: AdSize)
}

/// a banner: a test creative of the ad size, an impression once it is on screen, clicks open the landing page
open class BannerView: UIView {
    open var adUnitID: String?
    weak open var rootViewController: UIViewController?
    weak open var delegate: BannerViewDelegate?
    weak open var adSizeDelegate: AdSizeDelegate?
    open var adSize: AdSize { didSet { invalidateIntrinsicContentSize() } }
    open var paidEventHandler: PaidEventHandler?
    open private(set) var responseInfo: ResponseInfo?
    open var isAutoloadEnabled = false
    var creative: _TestAdCreativeView?
    var impressionRecorded = false

    public init(adSize: AdSize) { self.adSize = adSize; super.init(frame: CGRect(origin: .zero, size: adSize.size)) }
    public convenience init(adSize: AdSize, origin: CGPoint) { self.init(adSize: adSize); frame.origin = origin }
    public required init?(coder: NSCoder) { adSize = AdSizeBanner; super.init(coder: coder) }
    open override var intrinsicContentSize: CGSize { adSize.size.height > 0 ? adSize.size : CGSize(width: adSize.size.width, height: 50) }

    open func load(_ request: Request?) {
        let unit = adUnitID ?? ""
        let err = _gadLoadError(unit)
        print("isim: Google Mobile Ads test banner \(err == nil ? "loaded" : "failed: \(err!.localizedDescription)") (\(unit), \(Int(adSize.size.width))x\(Int(intrinsicContentSize.height)))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            if let err { self.delegate?.bannerView?(self, didFailToReceiveAdWithError: err); return }
            self.show()
            self.delegate?.bannerViewDidReceiveAd?(self)
            self.recordImpressionIfVisible()
        }
    }
    func show() {
        creative?.removeFromSuperview()
        let size = intrinsicContentSize
        let c = _TestAdCreativeView(network: "Google AdMob", headline: "Nice job! This is a \(Int(size.width))x\(Int(size.height)) test ad.",
                                    frame: bounds)
        c.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        c.onTap = { [weak self] in self?.clicked() }
        addSubview(c)
        creative = c
        responseInfo = ResponseInfo()
        impressionRecorded = false
    }
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        recordImpressionIfVisible()
    }
    func recordImpressionIfVisible() {
        guard creative != nil, !impressionRecorded, window != nil, !isHidden else { return }
        impressionRecorded = true
        print("isim: Google Mobile Ads test banner impression")
        delegate?.bannerViewDidRecordImpression?(self)
        paidEventHandler?(AdValue())
    }
    func clicked() {
        delegate?.bannerViewDidRecordClick?(self)
        _TestAds.presentLanding(network: "Google AdMob", from: rootViewController,
                                willPresent: { [weak self] in guard let self else { return }; self.delegate?.bannerViewWillPresentScreen?(self) },
                                willDismiss: { [weak self] in guard let self else { return }; self.delegate?.bannerViewWillDismissScreen?(self) },
                                didDismiss: { [weak self] in guard let self else { return }; self.delegate?.bannerViewDidDismissScreen?(self) })
    }
}

// MARK: - native ads

public final class NativeAdImage: NSObject, @unchecked Sendable {
    public let image: UIImage?
    public let imageURL: URL? = nil
    public let scale: CGFloat = 1
    init(_ image: UIImage?) { self.image = image }
}
public final class MediaContent: NSObject, @unchecked Sendable {
    public let aspectRatio: CGFloat = 16.0 / 9.0
    public let hasVideoContent = false
    public var mainImage: UIImage?
}
open class MediaView: UIView {
    open var mediaContent: MediaContent? { didSet { setNeedsDisplay() } }
    open override func draw(_ rect: CGRect) {
        UIColor(red: 0.85, green: 0.9, blue: 0.97, alpha: 1).setFill()
        UIBezierPath(rect: bounds).fill()
        let s = "Test Ad media" as NSString
        let a: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 13), .foregroundColor: UIColor.gray]
        let z = s.size(withAttributes: a)
        s.draw(at: CGPoint(x: bounds.midX - z.width / 2, y: bounds.midY - z.height / 2), withAttributes: a)
    }
}
@objc public protocol NativeAdDelegate: NSObjectProtocol {
    @objc optional func nativeAdDidRecordImpression(_ nativeAd: NativeAd)
    @objc optional func nativeAdDidRecordClick(_ nativeAd: NativeAd)
    @objc optional func nativeAdWillPresentScreen(_ nativeAd: NativeAd)
    @objc optional func nativeAdWillDismissScreen(_ nativeAd: NativeAd)
    @objc optional func nativeAdDidDismissScreen(_ nativeAd: NativeAd)
}
/// a test native ad: the assets an app lays out itself in a NativeAdView
public final class NativeAd: NSObject, @unchecked Sendable {
    public let headline: String? = "Test Ad: isim native ad"
    public let body: String? = "This is a test native ad. Its assets come from isim, not from an ad server."
    public let callToAction: String? = "Install"
    public let advertiser: String? = "isim"
    public let store: String? = "App Store"
    public let price: String? = "Free"
    public let starRating: NSDecimalNumber? = NSDecimalNumber(value: 4.5)
    public let icon: NativeAdImage? = NativeAdImage(nil)
    public let images: [NativeAdImage]? = []
    public let mediaContent = MediaContent()
    public let responseInfo = ResponseInfo()
    weak public var delegate: NativeAdDelegate?
    weak public var rootViewController: UIViewController?
    public var paidEventHandler: PaidEventHandler?
    func recordImpression() {
        print("isim: Google Mobile Ads test native ad impression")
        delegate?.nativeAdDidRecordImpression?(self)
        paidEventHandler?(AdValue())
    }
    func clicked() {
        delegate?.nativeAdDidRecordClick?(self)
        _TestAds.presentLanding(network: "Google AdMob", from: rootViewController,
                                willPresent: { [weak self] in guard let self else { return }; self.delegate?.nativeAdWillPresentScreen?(self) },
                                willDismiss: { [weak self] in guard let self else { return }; self.delegate?.nativeAdWillDismissScreen?(self) },
                                didDismiss: { [weak self] in guard let self else { return }; self.delegate?.nativeAdDidDismissScreen?(self) })
    }
}
/// the app's layout for a native ad: taps on its registered asset views are clicks, an AdChoices-style "Ad" mark is added
open class NativeAdView: UIView {
    open var nativeAd: NativeAd? { didSet { attach() } }
    @IBOutlet open weak var headlineView: UIView?
    @IBOutlet open weak var bodyView: UIView?
    @IBOutlet open weak var callToActionView: UIView?
    @IBOutlet open weak var iconView: UIView?
    @IBOutlet open weak var imageView: UIView?
    @IBOutlet open weak var starRatingView: UIView?
    @IBOutlet open weak var storeView: UIView?
    @IBOutlet open weak var priceView: UIView?
    @IBOutlet open weak var advertiserView: UIView?
    @IBOutlet open weak var mediaView: MediaView?
    let adMark = UILabel()
    func attach() {
        for v in [headlineView, bodyView, callToActionView, iconView, imageView, starRatingView, storeView, priceView, advertiserView, mediaView].compactMap({ $0 }) {
            v.isUserInteractionEnabled = true
            v.gestureRecognizers?.filter { $0.name == "isim.nativeAd" }.forEach { v.removeGestureRecognizer($0) }
            let g = UITapGestureRecognizer(target: self, action: #selector(assetTapped))
            g.name = "isim.nativeAd"
            v.addGestureRecognizer(g)
        }
        mediaView?.mediaContent = nativeAd?.mediaContent
        adMark.text = " Ad "
        adMark.font = .boldSystemFont(ofSize: 10)
        adMark.textColor = .white
        adMark.backgroundColor = UIColor(red: 0.95, green: 0.6, blue: 0.1, alpha: 1)
        adMark.sizeToFit()
        adMark.accessibilityIdentifier = "ad-native-mark"
        addSubview(adMark)
        if window != nil { nativeAd?.recordImpression() }
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        adMark.frame.origin = CGPoint(x: bounds.maxX - adMark.bounds.width - 4, y: 4)
        bringSubviewToFront(adMark)
    }
    open override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil, nativeAd != nil { nativeAd?.recordImpression() }
    }
    @objc func assetTapped() { nativeAd?.clicked() }
}

public struct AdLoaderAdType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let native = AdLoaderAdType(rawValue: "6")
}
open class AdLoaderOptions: NSObject {}
public final class NativeAdViewAdOptions: AdLoaderOptions { public var preferredAdChoicesPosition = 1 }
public final class NativeAdMediaAdLoaderOptions: AdLoaderOptions { public var mediaAspectRatio = 0 }
public final class MultipleAdsAdLoaderOptions: AdLoaderOptions { public var numberOfAds = 1 }

@objc public protocol AdLoaderDelegate: NSObjectProtocol {
    func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: Error)
    @objc optional func adLoaderDidFinishLoading(_ adLoader: AdLoader)
}
@objc public protocol NativeAdLoaderDelegate: AdLoaderDelegate {
    func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd)
}
open class AdLoader: NSObject {
    public let adUnitID: String
    weak open var delegate: AdLoaderDelegate?
    weak var rootViewController: UIViewController?
    let count: Int
    open private(set) var isLoading = false
    public init(adUnitID: String, rootViewController: UIViewController?, adTypes: [AdLoaderAdType], options: [AdLoaderOptions]?) {
        self.adUnitID = adUnitID; self.rootViewController = rootViewController
        count = max(1, min(5, options?.compactMap { ($0 as? MultipleAdsAdLoaderOptions)?.numberOfAds }.first ?? 1))
        super.init()
    }
    open func load(_ request: Request?) {
        isLoading = true
        let err = _gadLoadError(adUnitID)
        print("isim: Google Mobile Ads test native ad \(err == nil ? "loaded" : "failed: \(err!.localizedDescription)") (\(adUnitID))")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self else { return }
            self.isLoading = false
            if let err { self.delegate?.adLoader(self, didFailToReceiveAdWithError: err); return }
            for _ in 0..<self.count {
                let ad = NativeAd()
                ad.rootViewController = self.rootViewController
                (self.delegate as? NativeAdLoaderDelegate)?.adLoader(self, didReceive: ad)
            }
            self.delegate?.adLoaderDidFinishLoading?(self)
        }
    }
}
