// isim AdAttributionKit (iOS 17.4). Adapted: there are no App Store installs from ads on isim, so nothing is
// attributed or sent to ad networks. AppImpression parses and checks an ad network's compact JWS (ES256 header with
// the ad network's key ID, the payload fields Apple documents); the signature cannot be checked against the ad
// network's key registered with Apple, so only its presence is. handleTap() needs a tap on a UIEventAttributionView
// in the last second, like iOS (missingAttributionView otherwise), records the click-through impression and opens
// the advertised app's App Store page URL (isim has no App Store: logged); beginView / endView record a view-through
// impression of at least two seconds. Postback.updateConversionValue checks and records conversion values with
// SKAdNetwork's in the shared state (_AdAttribution): they fill the app's development postbacks, which
// `isim adattribution` creates and transmits like Settings › Developer › Development Postbacks.
import Foundation
import UIKit

public enum AdAttributionKitError: Error, Equatable, Hashable, CustomStringConvertible, Sendable {
    case conversionTagNotSupported, impressionExpired, invalidConversionTag, invalidImpressionJWSComponents, invalidImpressionJWSHeader,
         invalidImpressionJWSPayload, invalidImpressionJWSSignature, missingAttributionView, unknown
    public var description: String {
        switch self {
        case .conversionTagNotSupported: return "The postback update failed due to an unsupported use of conversion tag"
        case .impressionExpired: return "The attribution failed because the impression expired."
        case .invalidConversionTag: return "The postback update failed due to an invalid conversion tag"
        case .invalidImpressionJWSComponents: return "The attribution failed due to invalid JWS components."
        case .invalidImpressionJWSHeader: return "The attribution failed due to an invalid JWS header."
        case .invalidImpressionJWSPayload: return "The attribution failed due to an invalid JWS payload."
        case .invalidImpressionJWSSignature: return "The attribution failed due to an invalid JWS signature."
        case .missingAttributionView: return "The attribution failed due to a missing attribution view."
        case .unknown: return "The attribution failed due to an unknown, unrecoverable error."
        }
    }
}

public enum CoarseConversionValue: Sendable, Hashable {
    case low, medium, high
    var name: String { switch self { case .low: return "low"; case .medium: return "medium"; case .high: return "high" } }
}

@_silgen_name("isim_ui_attribution_take_tap") func _isimTakeAttributionTap() -> Bool

public struct AppImpression: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let adNetworkID: String
    public let advertisedItemID: UInt64
    public let publisherItemID: UInt64
    public let sourceID: Int
    public let timestamp: Date
    public let keyID: String
    public let eligibleForReengagement: Bool
    public let compactJWSRepresentation: String
    public static var isSupported: Bool { true }

    static func base64url(_ s: Substring) -> Data? {
        var t = s.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        while t.count % 4 != 0 { t += "=" }
        return Data(base64Encoded: t)
    }
    public init(compactJWS: String) async throws {
        let parts = compactJWS.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3, let h = Self.base64url(parts[0]), let p = Self.base64url(parts[1]) else { throw AdAttributionKitError.invalidImpressionJWSComponents }
        guard let header = try? JSONSerialization.jsonObject(with: h) as? [String: Any], header["alg"] as? String == "ES256",
              let kid = header["kid"] as? String, !kid.isEmpty else { throw AdAttributionKitError.invalidImpressionJWSHeader }
        guard let payload = try? JSONSerialization.jsonObject(with: p) as? [String: Any],
              let network = payload["ad-network-identifier"] as? String, !network.isEmpty,
              let advertised = (payload["advertised-item-identifier"] as? NSNumber)?.uint64Value,
              let source = (payload["source-identifier"] as? NSNumber).map({ Int($0.int64Value) }), (0...9999).contains(source),
              let ms = (payload["timestamp"] as? NSNumber)?.doubleValue,
              (payload["impression-type"] as? String ?? "app-impression") == "app-impression" else {
            throw AdAttributionKitError.invalidImpressionJWSPayload
        }
        // the signature: ES256 is 64 bytes; it is checked by Apple against the ad network's registered key, which isim cannot
        guard let sig = Self.base64url(parts[2]), sig.count == 64 else { throw AdAttributionKitError.invalidImpressionJWSSignature }
        let ts = Date(timeIntervalSince1970: ms / 1000)
        if Date().timeIntervalSince(ts) > 30 * 86400 { throw AdAttributionKitError.impressionExpired }
        id = (payload["impression-identifier"] as? String).flatMap(UUID.init(uuidString:)) ?? UUID()
        adNetworkID = network; advertisedItemID = advertised
        publisherItemID = (payload["publisher-item-identifier"] as? NSNumber)?.uint64Value ?? 0
        sourceID = source; timestamp = ts; keyID = kid
        eligibleForReengagement = payload["eligible-for-re-engagement"] as? Bool ?? false
        compactJWSRepresentation = compactJWS
    }

    var openSince: Date? {
        get { _ViewThrough.lock.lock(); defer { _ViewThrough.lock.unlock() }; return _ViewThrough.started[id] }
        nonmutating set { _ViewThrough.lock.lock(); _ViewThrough.started[id] = newValue; _ViewThrough.lock.unlock() }
    }
    func record(_ type: String, extra: [String: Any] = [:]) {
        var info: [String: Any] = ["api": "AdAttributionKit", "type": type, "adNetwork": adNetworkID, "advertisedItem": advertisedItemID,
                                   "publisherItem": publisherItemID, "source": sourceID, "time": Date().timeIntervalSince1970]
        for (k, v) in extra { info[k] = v }
        _IsimAttribution.recordImpression(info)
    }

    public func handleTap() async throws { try await tap(reengagementURL: nil) }
    public func handleTap(reengagementURL: URL) async throws { try await tap(reengagementURL: reengagementURL) }
    func tap(reengagementURL: URL?) async throws {
        let tapped = await MainActor.run { _isimTakeAttributionTap() }
        guard tapped else {
            print("isim: AdAttributionKit: handleTap without a tap on a UIEventAttributionView in the last second")
            throw AdAttributionKitError.missingAttributionView
        }
        record("click", extra: ["reengagementURL": reengagementURL?.absoluteString ?? NSNull()])
        let page = URL(string: "https://apps.apple.com/app/id\(advertisedItemID)")!
        print("isim: AdAttributionKit: click-through impression recorded (\(adNetworkID), advertised item \(advertisedItemID)); "
              + "opening its App Store page \(page.absoluteString)")
        await MainActor.run { UIApplication.shared.open(page, options: [:], completionHandler: nil) }
    }
    public func beginView() async throws {
        openSince = Date()
        print("isim: AdAttributionKit: view-through impression begins (\(adNetworkID))")
    }
    public func endView() async throws {
        guard let start = openSince else { throw AdAttributionKitError.unknown }
        openSince = nil
        let seconds = Date().timeIntervalSince(start)
        guard seconds >= 2 else {
            print("isim: AdAttributionKit: the ad was visible \(String(format: "%.1f", seconds)) s, less than two: no view-through impression")
            throw AdAttributionKitError.unknown
        }
        record("view", extra: ["seconds": seconds])
        print("isim: AdAttributionKit: view-through impression recorded after \(String(format: "%.1f", seconds)) s")
    }
    public func handleView() async throws {
        record("view")
        print("isim: AdAttributionKit: view-through impression recorded (\(adNetworkID))")
    }
    public static func == (a: AppImpression, b: AppImpression) -> Bool { a.id == b.id }
    public func hash(into h: inout Hasher) { h.combine(id) }
}
enum _ViewThrough {
    static let lock = NSLock()
    nonisolated(unsafe) static var started: [UUID: Date] = [:]
}

public struct PostbackUpdate: Sendable {
    public enum ConversionType: Sendable, Hashable { case install, reengagement }
    public let fineConversionValue: Int
    public let lockPostback: Bool
    public let coarseConversionValue: CoarseConversionValue?
    public let conversionTag: String?
    public let conversionTypes: [ConversionType]?
    public init(fineConversionValue: Int, lockPostback: Bool, coarseConversionValue: CoarseConversionValue? = nil, conversionTypes: [ConversionType]? = nil) {
        self.fineConversionValue = fineConversionValue; self.lockPostback = lockPostback
        self.coarseConversionValue = coarseConversionValue; self.conversionTypes = conversionTypes; conversionTag = nil
    }
    public init(fineConversionValue: Int, lockPostback: Bool, conversionTag: String, coarseConversionValue: CoarseConversionValue? = nil,
                conversionTypes: [ConversionType]? = nil) {
        self.fineConversionValue = fineConversionValue; self.lockPostback = lockPostback; self.conversionTag = conversionTag
        self.coarseConversionValue = coarseConversionValue; self.conversionTypes = conversionTypes
    }
}

public struct Postback: Sendable {
    public static var isSupported: Bool { true }
    public static var reengagementOpenURLParameter: String { "AdAttributionKitReengagementOpen" }
    public static func updateConversionValue(_ conversionValue: Int, lockPostback: Bool) async throws {
        guard _IsimAttribution.update(api: "AdAttributionKit", fine: conversionValue, coarse: nil, lockWindow: lockPostback) else { throw AdAttributionKitError.unknown }
    }
    public static func updateConversionValue(_ conversionValue: Int, coarseConversionValue: CoarseConversionValue, lockPostback: Bool) async throws {
        guard _IsimAttribution.update(api: "AdAttributionKit", fine: conversionValue, coarse: coarseConversionValue.name, lockWindow: lockPostback) else {
            throw AdAttributionKitError.unknown
        }
    }
    public static func updateConversionValue(_ update: PostbackUpdate) async throws {
        if let tag = update.conversionTag, tag.isEmpty { throw AdAttributionKitError.invalidConversionTag }
        guard _IsimAttribution.update(api: "AdAttributionKit", fine: update.fineConversionValue, coarse: update.coarseConversionValue?.name,
                                      lockWindow: update.lockPostback, tag: update.conversionTag) else { throw AdAttributionKitError.unknown }
    }
}
