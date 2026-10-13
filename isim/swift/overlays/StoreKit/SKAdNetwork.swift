// isim StoreKit: SKAdNetwork (ad attribution for installs). Adapted: there are no App Store installs from ads on isim,
// so nothing is attributed or sent to ad networks. Conversion value updates are checked like iOS (fine 0-63, coarse
// low / medium / high, locking closes a conversion window) and recorded with AdAttributionKit's in the shared state
// (_AdAttribution): they fill the app's development postbacks (`isim adattribution`). View-through impressions
// (startImpression / endImpression) are checked and recorded.
import Foundation

public let SKANErrorDomain = "SKANErrorDomain"
public struct SKANError: Error, CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case impressionMissingRequiredValue = 0, unsupported = 1, ambiguousInput = 2, impressionNotFound = 3, invalidCampaignIdentifier = 4,
             invalidConversionValue = 5, invalidSourceAppStoreIdentifier = 6, invalidAdvertisedAppStoreIdentifier = 7, invalidVersion = 8,
             mismatchedSourceAppStoreIdentifier = 9, impressionTooShort = 10, invalidCoarseConversionValue = 11, invalidLockWindowValue = 12
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { SKANErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: "SKAdNetwork error \(code)"] }
    public static let invalidConversionValue = Code.invalidConversionValue
}

open class SKAdImpression: NSObject, @unchecked Sendable {
    open var sourceAppStoreItemIdentifier: NSNumber = 0
    open var advertisedAppStoreItemIdentifier: NSNumber = 0
    open var adNetworkIdentifier = ""
    open var adCampaignIdentifier: NSNumber = 0
    open var sourceIdentifier: NSNumber = 0
    open var adImpressionIdentifier = ""
    open var adType: String?
    open var adDescription: String?
    open var adPurchaserName: String?
    open var timestamp: NSNumber = 0
    open var signature = ""
    open var version = ""
    public override init() { super.init() }
    public init(sourceAppStoreItemIdentifier: NSNumber, advertisedAppStoreItemIdentifier: NSNumber, adNetworkIdentifier: String,
                adCampaignIdentifier: NSNumber, adImpressionIdentifier: String, timestamp: NSNumber, signature: String, version: String) {
        self.sourceAppStoreItemIdentifier = sourceAppStoreItemIdentifier; self.advertisedAppStoreItemIdentifier = advertisedAppStoreItemIdentifier
        self.adNetworkIdentifier = adNetworkIdentifier; self.adCampaignIdentifier = adCampaignIdentifier; sourceIdentifier = adCampaignIdentifier
        self.adImpressionIdentifier = adImpressionIdentifier; self.timestamp = timestamp; self.signature = signature; self.version = version
        super.init()
    }
}

open class SKAdNetwork: NSObject {
    public struct CoarseConversionValue: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let high = CoarseConversionValue(rawValue: "high"), medium = CoarseConversionValue(rawValue: "medium"),
                          low = CoarseConversionValue(rawValue: "low")
    }
    static let lock = NSLock()
    nonisolated(unsafe) static var started: [String: Date] = [:]

    static func done(_ handler: ((Error?) -> Void)?, _ error: Error?) {
        guard let handler else { return }
        DispatchQueue.main.async { handler(error) }
    }
    static func check(_ i: SKAdImpression) -> SKANError? {
        if i.adNetworkIdentifier.isEmpty || i.adImpressionIdentifier.isEmpty || i.signature.isEmpty || i.version.isEmpty { return SKANError(.impressionMissingRequiredValue) }
        if !["2.0", "2.1", "2.2", "3.0", "4.0"].contains(i.version) { return SKANError(.invalidVersion) }
        if i.advertisedAppStoreItemIdentifier.int64Value <= 0 { return SKANError(.invalidAdvertisedAppStoreIdentifier) }
        if i.version == "4.0" ? !(0...9999).contains(i.sourceIdentifier.intValue) : !(0...99).contains(i.adCampaignIdentifier.intValue) {
            return SKANError(.invalidCampaignIdentifier)
        }
        return nil
    }

    /// view-through attribution: the impression is shown
    open class func startImpression(_ impression: SKAdImpression, completionHandler: ((Error?) -> Void)? = nil) {
        if let e = check(impression) { done(completionHandler, e); return }
        lock.lock(); started[impression.adImpressionIdentifier] = Date(); lock.unlock()
        print("isim: SKAdNetwork impression started (\(impression.adNetworkIdentifier), advertised \(impression.advertisedAppStoreItemIdentifier))")
        done(completionHandler, nil)
    }
    open class func startImpression(_ impression: SKAdImpression) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            startImpression(impression) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
    open class func endImpression(_ impression: SKAdImpression, completionHandler: ((Error?) -> Void)? = nil) {
        lock.lock(); let start = started.removeValue(forKey: impression.adImpressionIdentifier); lock.unlock()
        guard let start else { done(completionHandler, SKANError(.impressionNotFound)); return }
        let seconds = Date().timeIntervalSince(start)
        _IsimAttribution.recordImpression(["api": "SKAdNetwork", "type": "view-through", "adNetwork": impression.adNetworkIdentifier,
                                           "advertisedItem": impression.advertisedAppStoreItemIdentifier.int64Value,
                                           "seconds": seconds, "time": Date().timeIntervalSince1970])
        print("isim: SKAdNetwork impression ended after \(String(format: "%.1f", seconds)) s (recorded; no attribution on isim)")
        done(completionHandler, nil)
    }
    open class func endImpression(_ impression: SKAdImpression) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            endImpression(impression) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }

    @available(iOS, deprecated: 15.4)
    open class func registerAppForAdNetworkAttribution() { _IsimAttribution.update(api: "SKAdNetwork", fine: 0, coarse: nil, lockWindow: false) }
    @available(iOS, deprecated: 15.4)
    open class func updateConversionValue(_ conversionValue: Int) {
        _IsimAttribution.update(api: "SKAdNetwork", fine: conversionValue, coarse: nil, lockWindow: false)
    }
    open class func updatePostbackConversionValue(_ conversionValue: Int, completionHandler: ((Error?) -> Void)? = nil) {
        let ok = _IsimAttribution.update(api: "SKAdNetwork", fine: conversionValue, coarse: nil, lockWindow: false)
        done(completionHandler, ok ? nil : SKANError(.invalidConversionValue))
    }
    open class func updatePostbackConversionValue(_ fineValue: Int, coarseValue: CoarseConversionValue, completionHandler: ((Error?) -> Void)? = nil) {
        updatePostbackConversionValue(fineValue, coarseValue: coarseValue, lockWindow: false, completionHandler: completionHandler)
    }
    open class func updatePostbackConversionValue(_ fineValue: Int, coarseValue: CoarseConversionValue, lockWindow: Bool,
                                                  completionHandler: ((Error?) -> Void)? = nil) {
        guard [CoarseConversionValue.low, .medium, .high].contains(coarseValue) else {
            done(completionHandler, SKANError(.invalidCoarseConversionValue)); return
        }
        let ok = _IsimAttribution.update(api: "SKAdNetwork", fine: fineValue, coarse: coarseValue.rawValue, lockWindow: lockWindow)
        done(completionHandler, ok ? nil : SKANError(.invalidConversionValue))
    }
    open class func updatePostbackConversionValue(_ conversionValue: Int) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            updatePostbackConversionValue(conversionValue) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
    open class func updatePostbackConversionValue(_ fineValue: Int, coarseValue: CoarseConversionValue, lockWindow: Bool = false) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            updatePostbackConversionValue(fineValue, coarseValue: coarseValue, lockWindow: lockWindow) { e in e.map { k.resume(throwing: $0) } ?? k.resume() }
        }
    }
}
