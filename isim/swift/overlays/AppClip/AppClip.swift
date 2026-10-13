// isim AppClip (self-authored, iOS API names): the activation payload an App Clip gets with its invocation, and the
// location confirmation that checks a person is where the invocation (an App Clip Code, QR code or NFC tag) was.
//
// Adapted: the system side lives in isim's home screen (system/SpringBoard/SBAppClips.m). When it launches an App Clip
// for an invocation it records the invocation in the clip's container (Library/isim/AppClip.plist): the URL, its source
// (code / nfc: a scanned code or tag, `appclip URL`; link: `openurl`, Safari, Messages; xcode: the _XCAppClipURL
// variable of `isim run`; library: the App Library) and the App Clip card's choices (the location confirmation and
// notification notes). confirmAcquired(in:) checks the simulated device location (CoreLocation's, `location LAT LON`)
// against the region, as the system would, without giving the App Clip the location.
import Foundation
@_spi(isim) import CoreLocation

public let APActivationPayloadErrorDomain = "APActivationPayloadErrorDomain"

public struct APActivationPayloadError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        /// the invocation URL isn't registered for the App Clip (no App Clip experience or appclips: domain matches)
        case doesNotMatch = 0
        /// location confirmation isn't allowed: turned off on the App Clip card, not requested in Info.plist, or the
        /// invocation didn't come from an App Clip Code, QR code or NFC tag
        case disallowed = 1
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { APActivationPayloadErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (\(APActivationPayloadErrorDomain) error \(code.rawValue).)" }
    public var localizedDescription: String { errorDescription! }
    public static var doesNotMatch: Code { .doesNotMatch }
    public static var disallowed: Code { .disallowed }
}
public func ~= (code: APActivationPayloadError.Code, error: Error) -> Bool { (error as? APActivationPayloadError)?.code == code }

/// The invocation the system launched the App Clip with (isim: Library/isim/AppClip.plist, written by the home screen)
struct _APInvocation {
    var url: URL?, source = "", registered = false, locationConfirmation = true
    static var file: String { (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/AppClip.plist") }
    static func load() -> _APInvocation {
        var i = _APInvocation()
        guard let d = NSDictionary(contentsOfFile: file) as? [String: Any] else { return i }
        i.url = (d["invocationURL"] as? String).flatMap(URL.init(string:))
        i.source = d["source"] as? String ?? ""
        i.registered = d["registered"] as? Bool ?? false
        i.locationConfirmation = d["locationConfirmation"] as? Bool ?? true
        return i
    }
    static var isAppClip: Bool { Bundle.main.object(forInfoDictionaryKey: "NSAppClip") != nil }
    static func requested(_ key: String) -> Bool { ((Bundle.main.object(forInfoDictionaryKey: "NSAppClip") as? [String: Any])?[key] as? Bool) == true }
}

open class APActivationPayload: NSObject, NSSecureCoding, NSCopying, @unchecked Sendable {
    /// the invocation URL
    open private(set) var url: URL?
    init(url: URL?) { self.url = url }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { if let u = url?.absoluteString { coder.encode(u as NSString, forKey: "URL") } }
    public required init?(coder: NSCoder) { url = (coder.decodeObject(forKey: "URL") as? String).flatMap(URL.init(string:)) }
    public func copy(with zone: OpaquePointer? = nil) -> Any { self }

    /// Whether the person is in `region` (a CLCircularRegion of up to 500 m around the expected place). The system checks
    /// the location; the App Clip only learns the answer. Fails with .disallowed when the App Clip did not request
    /// location confirmation (NSAppClip > NSAppClipRequestLocationConfirmation), the person turned it off on the App Clip
    /// card, or the invocation was not a scanned code or tag; with .doesNotMatch when the invocation URL isn't registered.
    open func confirmAcquired(in region: CLRegion, completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
        let result = check(region)
        DispatchQueue.main.async {
            switch result {
            case .success(let inside): completionHandler(inside, nil)
            case .failure(let e): completionHandler(false, e)
            }
        }
    }
    open func confirmAcquired(in region: CLRegion) async throws -> Bool {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Bool, Error>) in
            confirmAcquired(in: region) { inside, error in
                if let error { k.resume(throwing: error) } else { k.resume(returning: inside) }
            }
        }
    }

    private func check(_ region: CLRegion) -> Result<Bool, APActivationPayloadError> {
        func no(_ code: APActivationPayloadError.Code, _ why: String) -> Result<Bool, APActivationPayloadError> {
            NSLog("isim AppClip: location confirmation %@: %@", code == .disallowed ? "disallowed" : "does not match", why)
            return .failure(APActivationPayloadError(code))
        }
        guard _APInvocation.isAppClip, _APInvocation.requested("NSAppClipRequestLocationConfirmation") else {
            return no(.disallowed, "the App Clip's Info.plist does not request it (NSAppClip > NSAppClipRequestLocationConfirmation)")
        }
        let inv = _APInvocation.load()
        guard inv.locationConfirmation else { return no(.disallowed, "turned off on the App Clip card") }
        guard inv.source == "code" || inv.source == "nfc" else {
            return no(.disallowed, "the invocation (\(inv.source.isEmpty ? "unknown" : inv.source)) did not come from an App Clip Code, QR code or NFC tag")
        }
        guard inv.registered, let invoked = inv.url, let mine = url, invoked.absoluteString == mine.absoluteString else {
            return no(.doesNotMatch, "\(url?.absoluteString ?? "no URL") is not a registered invocation of this App Clip")
        }
        guard let here = CLLocationManager._isimSimulatedLocation() else { return no(.disallowed, "no device location (Location ▸ None)") }
        guard let circle = region as? CLCircularRegion else {
            NSLog("isim AppClip: location confirmation needs a CLCircularRegion")
            return .success(false)
        }
        if circle.radius > 500 { NSLog("isim AppClip: location confirmation: the region's radius %.0f m is over the 500 m limit; 500 m is used", circle.radius) }
        let check = CLCircularRegion(center: circle.center, radius: min(circle.radius, 500), identifier: circle.identifier)
        let inside = check.contains(here.coordinate)
        NSLog("isim AppClip: location confirmation in %@: %@", circle.identifier, inside ? "true" : "false")
        return .success(inside)
    }
}

extension NSUserActivity {
    /// The App Clip's activation payload: for the web-browsing activity an App Clip is launched (or continued) with,
    /// nil otherwise and in full apps.
    public var appClipActivationPayload: APActivationPayload? {
        guard _APInvocation.isAppClip, activityType == NSUserActivityTypeBrowsingWeb, let url = webpageURL else { return nil }
        return APActivationPayload(url: url)
    }
}
