// isim stand-in for Google's User Messaging Platform SDK (closed-source binary, not fetched or run).
// Consent requests succeed without a form; ads may not be requested (canRequestAds is false), so apps
// behave as if no ad consent was obtained. No network requests.
import UIKit

public enum ConsentStatus: Int, Sendable { case unknown = 0, required = 1, notRequired = 2, obtained = 3 }
public enum PrivacyOptionsRequirementStatus: Int, Sendable { case unknown = 0, required = 1, notRequired = 2 }
public enum FormStatus: Int, Sendable { case unknown = 0, available = 1, unavailable = 2 }

public final class DebugSettings: NSObject, @unchecked Sendable {
    public var testDeviceIdentifiers: [String] = []
    public var geography = 0
}
public final class RequestParameters: NSObject, @unchecked Sendable {
    public var isTaggedForUnderAgeOfConsent = false
    public var debugSettings: DebugSettings?
    public override init() {}
}

public final class ConsentInformation: NSObject, @unchecked Sendable {
    public static let shared = ConsentInformation()
    public var consentStatus: ConsentStatus { .notRequired }
    public var formStatus: FormStatus { .unavailable }
    public var canRequestAds: Bool { false }
    public var privacyOptionsRequirementStatus: PrivacyOptionsRequirementStatus { .notRequired }
    public func requestConsentInfoUpdate(with parameters: RequestParameters?, completionHandler: @escaping (Error?) -> Void) {
        NSLog("isim: User Messaging Platform stand-in (no consent form; ads are not requested on isim)")
        DispatchQueue.main.async { completionHandler(nil) }
    }
    public func requestConsentInfoUpdate(with parameters: RequestParameters?) async throws {}
    public func reset() {}
}

public final class ConsentForm: NSObject, @unchecked Sendable {
    public class func load(completionHandler: @escaping (ConsentForm?, Error?) -> Void) {
        DispatchQueue.main.async { completionHandler(nil, NSError(domain: "com.google.ump", code: 1, userInfo: [NSLocalizedDescriptionKey: "isim stand-in: no consent form"])) }
    }
    public class func loadAndPresentIfRequired(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    public class func presentPrivacyOptionsForm(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(nil) }
    }
    public func present(from viewController: UIViewController?, completionHandler: ((Error?) -> Void)? = nil) {
        DispatchQueue.main.async { completionHandler?(nil) }
    }
}
