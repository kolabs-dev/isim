// isim StoreKit: external purchases (issue #396). ExternalPurchase (the disclosure sheet before an in-app external
// purchase, with its token), ExternalPurchaseLink (the app's link out, opened after the same kind of notice) and
// ExternalPurchaseCustomLink (eligibility, tokens, notices). Eligibility follows the app's entitlements and Info.plist
// regions against the StoreKit storefront (USA unless the .storekit file sets another). The sheets are isim's
// rendition of iOS's disclosure; ISIM_STOREKIT_EXTERNAL_NOTICE=continue|cancel answers them without a sheet. Tokens
// are isim's own: base64 JSON like Apple's, marked as simulated, not verifiable by Apple's servers.
import UIKit
import SwiftUI

@available(iOS 15.4, *)
public enum ExternalPurchase {
    public enum NoticeResult: Sendable, Hashable {
        case continuedWithExternalPurchaseToken(token: String)
        case cancelled
    }

    /// the app has the external purchase entitlement and lists the storefront's country in SKExternalPurchase
    @available(iOS 17.4, *)
    public static var canPresent: Bool { get async { _SKExternal.allowed(entitlement: _SKExternal.purchaseKey, regions: "SKExternalPurchase") } }

    @MainActor public static func presentNoticeSheet() async throws -> NoticeResult {
        guard _SKExternal.allowed(entitlement: _SKExternal.purchaseKey, regions: "SKExternalPurchase") else { throw StoreKitError.notEntitled }
        guard await _SKExternal.notice(.inApp) else { return .cancelled }
        return .continuedWithExternalPurchaseToken(token: _SKExternal.token(type: "EXTERNAL_PURCHASE"))
    }
}

@available(iOS 15.4, *)
public enum ExternalPurchaseLink {
    /// the app has the link entitlement and an SKExternalPurchaseLink URL for the storefront's country
    public static var canOpen: Bool { get async { _SKExternal.link() != nil } }

    /// the storefront's SKExternalPurchaseMultiLink URLs (music streaming apps); nil without them
    @available(iOS 17.5, *)
    public static var eligibleURLs: [URL]? { get async { _SKExternal.multiLinks() } }

    /// iOS's notice, then the app's SKExternalPurchaseLink URL in the browser
    @MainActor public static func open() async throws {
        guard let url = _SKExternal.link() else { throw StoreKitError.notEntitled }
        try await _SKExternal.openOut(url)
    }

    /// one of `eligibleURLs`, after iOS's notice
    @available(iOS 17.5, *)
    @MainActor public static func open(url: URL) async throws {
        guard let urls = _SKExternal.multiLinks(), urls.contains(url) else { throw StoreKitError.notEntitled }
        try await _SKExternal.openOut(url)
    }
}

@available(iOS 18.1, *)
public enum ExternalPurchaseCustomLink {
    public struct Token: Sendable, Hashable {
        public let value: String
    }

    @available(iOS 27.2, *)
    public struct TokenType: Sendable, Hashable {
        let raw: String
        public static let withinApp = TokenType(raw: "WITHIN_APP")
        public static let outOfApp = TokenType(raw: "OUT_OF_APP")
    }

    @available(iOS 27.2, *)
    public enum ExternalPurchaseType: Sendable, Hashable {
        case withinApp
        case outOfApp(destinationURL: URL?)
    }

    @available(iOS, introduced: 18.1, deprecated: 27.2, message: "use showNotice(for:)")
    public enum NoticeType: Sendable, Hashable {
        case browser
        case withinApp
    }

    public enum NoticeResult: Sendable, Hashable {
        case cancelled
        case continued
    }

    /// the app has a custom link entitlement and lists the storefront's country in SKExternalPurchaseCustomLinkRegions
    public static var isEligible: Bool { get async { _SKExternal.customEligible() } }

    @available(iOS, introduced: 18.1, deprecated: 27.2, message: "use token(for: TokenType)")
    public static func token(for tokenType: String) async throws -> Token? {
        _SKExternal.customEligible() ? Token(value: _SKExternal.token(type: tokenType)) : nil
    }

    @available(iOS 27.2, *)
    public static func token(for tokenType: TokenType) async throws -> Token? {
        _SKExternal.customEligible() ? Token(value: _SKExternal.token(type: tokenType.raw)) : nil
    }

    @available(iOS, introduced: 18.1, deprecated: 27.2, message: "use showNotice(for:)")
    @MainActor public static func showNotice(type: NoticeType) async throws -> NoticeResult {
        guard _SKExternal.customEligible() else { throw StoreKitError.notEntitled }
        return await _SKExternal.notice(type == .browser ? .browser : .inApp) ? .continued : .cancelled
    }

    @available(iOS 27.2, *)
    @MainActor public static func showNotice(for type: ExternalPurchaseType) async throws -> NoticeResult {
        guard _SKExternal.customEligible() else { throw StoreKitError.notEntitled }
        if case .outOfApp = type { return await _SKExternal.notice(.browser) ? .continued : .cancelled }
        return await _SKExternal.notice(.inApp) ? .continued : .cancelled
    }
}

enum _SKExternal {
    static let purchaseKey = "com.apple.developer.storekit.external-purchase"
    static let linkKey = "com.apple.developer.storekit.external-purchase-link"
    static let streamingKey = "com.apple.developer.storekit.external-purchase-link-streaming"

    static var entitlements: [String: Any] {
        let xcent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return NSDictionary(contentsOfFile: xcent) as? [String: Any] ?? [:]
    }
    static func entitled(_ key: String) -> Bool { (entitlements[key] as? Bool) == true }

    /// the storefront's country as Info.plist lists it (ISO 3166-1 alpha-2)
    static var country: String {
        let s = _SKConfig.load().storefront.uppercased()
        return s.count == 3 ? (alpha2[s] ?? String(s.prefix(2))) : s
    }
    static func listed(_ codes: [String]) -> Bool { codes.contains { $0.uppercased() == country } }
    static func plist(_ key: String) -> Any? { Bundle.main.object(forInfoDictionaryKey: key) }

    static func allowed(entitlement: String, regions key: String) -> Bool {
        entitled(entitlement) && listed(plist(key) as? [String] ?? [])
    }
    static func link() -> URL? {
        guard entitled(linkKey), let links = plist("SKExternalPurchaseLink") as? [String: String] else { return nil }
        return links.first { $0.key.uppercased() == country }.flatMap { URL(string: $0.value) }
    }
    static func multiLinks() -> [URL]? {
        guard entitled(streamingKey), let links = plist("SKExternalPurchaseMultiLink") as? [String: [String]],
              let urls = links.first(where: { $0.key.uppercased() == country })?.value else { return nil }
        return urls.compactMap(URL.init(string:))
    }
    /// any of StoreKit's external purchase entitlements, and the storefront in SKExternalPurchaseCustomLinkRegions
    static func customEligible() -> Bool {
        entitlements.keys.contains { $0.hasPrefix(purchaseKey) && entitled($0) } && listed(plist("SKExternalPurchaseCustomLinkRegions") as? [String] ?? [])
    }

    /// base64 JSON in the shape of Apple's external purchase tokens; "isimSimulated" marks it as isim's own
    static func token(type: String) -> String {
        let body: [String: Any] = ["appAppleId": 0, "bundleId": Bundle.main.bundleIdentifier ?? "", "tokenType": type,
                                   "tokenCreationDate": Int(Date().timeIntervalSince1970 * 1000),
                                   "externalPurchaseId": UUID().uuidString.lowercased(), "isimSimulated": true]
        let data = (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
        return data.base64EncodedString()
    }

    @MainActor static func openOut(_ url: URL) async throws {
        guard await notice(.browser) else { NSLog("isim StoreKit: external purchase link cancelled"); return }
        NSLog("isim StoreKit: external purchase link opens %@", url.absoluteString)
        await UIApplication.shared.open(url)
    }

    enum Kind { case inApp, browser }
    /// iOS's disclosure; true: Continue
    @MainActor static func notice(_ kind: Kind) async -> Bool {
        if let a = ProcessInfo.processInfo.environment["ISIM_STOREKIT_EXTERNAL_NOTICE"]?.lowercased(), a == "continue" || a == "cancel" {
            NSLog("isim StoreKit: external purchase notice answered %@ (ISIM_STOREKIT_EXTERNAL_NOTICE)", a)
            return a == "continue"
        }
        NSLog("isim StoreKit: external purchase notice (%@)", kind == .browser ? "browser" : "in app")
        var go = false
        await _SKSheets.present { close in AnyView(_SKExternalNoticeView(kind: kind, proceed: { go = true; close() }, cancel: close)) }
        NSLog("isim StoreKit: external purchase notice %@", go ? "continued" : "cancelled")
        return go
    }

    static let alpha2: [String: String] = [
        "AUT": "AT", "BEL": "BE", "BGR": "BG", "HRV": "HR", "CYP": "CY", "CZE": "CZ", "DNK": "DK", "EST": "EE", "FIN": "FI",
        "FRA": "FR", "DEU": "DE", "GRC": "GR", "HUN": "HU", "IRL": "IE", "ITA": "IT", "LVA": "LV", "LTU": "LT", "LUX": "LU",
        "MLT": "MT", "NLD": "NL", "POL": "PL", "PRT": "PT", "ROU": "RO", "SVK": "SK", "SVN": "SI", "ESP": "ES", "SWE": "SE",
        "ISL": "IS", "LIE": "LI", "NOR": "NO", "CHE": "CH", "GBR": "GB", "USA": "US", "CAN": "CA", "MEX": "MX", "BRA": "BR",
        "KOR": "KR", "JPN": "JP", "CHN": "CN", "IND": "IN", "AUS": "AU", "NZL": "NZ", "TUR": "TR", "ZAF": "ZA",
    ]
}

/// isim's rendition of iOS's external purchase disclosure
struct _SKExternalNoticeView: View {
    let kind: _SKExternal.Kind
    let proceed: () -> Void
    let cancel: () -> Void
    var body: some View {
        VStack(spacing: 16) {
            _SKAppIcon(size: 64).padding(.top, 36)
            Text(verbatim: kind == .browser ? "You’re about to go to an external website." : "This app supports purchases from another source.")
                .font(.system(size: 22, weight: .bold)).multilineTextAlignment(.center)
            Text(verbatim: "You will no longer be transacting with Apple. Purchases will be managed by the developer of “\(_SKSheets.appName)”. Your App Store account, stored payment methods and features such as subscription management and refund requests will not be available. Apple is not responsible for the privacy or security of purchases made with this developer.")
                .font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Spacer()
            Button { proceed() } label: { Text(verbatim: "Continue").font(.system(size: 17, weight: .semibold)).frame(maxWidth: .infinity).padding(.vertical, 6) }
                .buttonStyle(.borderedProminent).accessibilityIdentifier("sk-external-continue")
            Button { cancel() } label: { Text(verbatim: "Cancel").font(.system(size: 17)).frame(maxWidth: .infinity) }
                .accessibilityIdentifier("sk-external-cancel")
            _SKEnvironmentNote().padding(.bottom, 12)
        }
        .padding(.horizontal, 28)
    }
}
