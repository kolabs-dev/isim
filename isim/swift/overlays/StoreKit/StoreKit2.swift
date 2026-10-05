// isim StoreKit 2 (Product, Transaction, AppStore): local StoreKit testing, like Xcode's.
// There is no App Store connection. Products come from the StoreKit configuration file that the
// project's scheme selects (`isim build` copies it into the bundle as isim-StoreKitConfiguration.storekit
// and records it under the Info.plist key ISIMStoreKitConfiguration). Purchases show a confirmation
// sheet, charge nothing, and are stored in the app's container; transactions are always .verified
// (as in Xcode's local testing environment). Without a configuration file, no products exist.
import UIKit

// MARK: - Configuration

struct _SKConfig {
    struct Item { let id: String; let type: Product.ProductType; let name: String; let description: String; let price: Decimal; let displayPrice: String; let familyShareable: Bool }
    let items: [Item]
    nonisolated(unsafe) static var cached: _SKConfig?
    static func load() -> _SKConfig {
        if let c = cached { return c }
        var items: [Item] = []
        let name = Bundle.main.object(forInfoDictionaryKey: "ISIMStoreKitConfiguration") as? String ?? "isim-StoreKitConfiguration.storekit"
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent(name)
        if let data = FileManager.default.contents(atPath: path),
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let locale = Locale.current.identifier
            func add(_ list: [[String: Any]], _ fallback: Product.ProductType) {
                for p in list {
                    guard let id = p["productID"] as? String else { continue }
                    let locs = p["localizations"] as? [[String: Any]] ?? []
                    let loc = locs.first { ($0["locale"] as? String) == locale } ?? locs.first { ($0["locale"] as? String)?.hasPrefix("en") == true } ?? locs.first ?? [:]
                    let priceText = (p["displayPrice"] as? String) ?? "0"
                    let type: Product.ProductType
                    switch p["type"] as? String {
                    case "Consumable": type = .consumable
                    case "NonConsumable": type = .nonConsumable
                    case "NonRenewingSubscription": type = .nonRenewable
                    case "RecurringSubscription", "AutoRenewable": type = .autoRenewable
                    default: type = fallback
                    }
                    let price = Decimal(string: priceText) ?? .zero
                    items.append(Item(id: id, type: type, name: loc["displayName"] as? String ?? id,
                                      description: loc["description"] as? String ?? "", price: price,
                                      displayPrice: "$" + priceText, familyShareable: p["familyShareable"] as? Bool ?? false))
                }
            }
            add(root["products"] as? [[String: Any]] ?? [], .consumable)
            add(root["nonRenewingSubscriptions"] as? [[String: Any]] ?? [], .nonRenewable)
            for g in root["subscriptionGroups"] as? [[String: Any]] ?? [] {
                add(g["subscriptions"] as? [[String: Any]] ?? [], .autoRenewable)
            }
            NSLog("isim StoreKit: local testing configuration %@ (%ld products)", name, items.count)
        } else {
            NSLog("isim StoreKit: no StoreKit configuration in the bundle; no products are available")
        }
        let c = _SKConfig(items: items)
        cached = c
        return c
    }
}

/// Purchased transactions, persisted per app (the app's container preferences).
enum _SKLedger {
    static let key = "_ISIMStoreKitTransactions"
    static func all() -> [[String: Any]] { UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? [] }
    static func record(_ t: Transaction) {
        var list = all()
        list.append(["id": NSNumber(value: t.id), "productID": t.productID, "date": NSNumber(value: t.purchaseDate.timeIntervalSince1970),
                     "type": t.productType.rawValue])
        UserDefaults.standard.set(list, forKey: key)
    }
    static func nextID() -> UInt64 {
        let n = UInt64(UserDefaults.standard.integer(forKey: key + ".next")) + 1
        UserDefaults.standard.set(Int(n), forKey: key + ".next")
        return n
    }
}

// MARK: - Product

public struct Product: Identifiable, Hashable, Sendable {
    public struct ProductType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let consumable = ProductType(rawValue: "Consumable")
        public static let nonConsumable = ProductType(rawValue: "Non-Consumable")
        public static let nonRenewable = ProductType(rawValue: "Non-Renewing Subscription")
        public static let autoRenewable = ProductType(rawValue: "Auto-Renewable Subscription")
    }
    public enum PurchaseResult: Sendable {
        case success(VerificationResult<Transaction>)
        case userCancelled
        case pending
    }
    public enum PurchaseOption: Hashable, Sendable {
        case appAccountToken(UUID)
        case quantity(Int)
    }
    public enum PurchaseError: Error, Sendable { case invalidQuantity, productUnavailable, purchaseNotAllowed, ineligibleForOffer, invalidOfferIdentifier, invalidOfferPrice, invalidOfferSignature, missingOfferParameters }

    public let id: String
    public let type: ProductType
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let isFamilyShareable: Bool

    public static func products<C: Collection>(for identifiers: C) async throws -> [Product] where C.Element == String {
        let wanted = Set(identifiers)
        return _SKConfig.load().items.filter { wanted.contains($0.id) }.map {
            Product(id: $0.id, type: $0.type, displayName: $0.name, description: $0.description, price: $0.price,
                    displayPrice: $0.displayPrice, isFamilyShareable: $0.familyShareable)
        }
    }

    @MainActor public func purchase(options: Set<PurchaseOption> = []) async throws -> PurchaseResult {
        let confirmed = await _SKPurchaseSheet.confirm(self)
        guard confirmed else { return .userCancelled }
        let t = Transaction(id: _SKLedger.nextID(), productID: id, productType: type, purchaseDate: Date(), revocationDate: nil)
        _SKLedger.record(t)
        NSLog("isim StoreKit: purchased %@ (local testing, nothing charged)", id)
        return .success(.verified(t))
    }
}

// MARK: - Transactions

public enum VerificationResult<SignedType>: Sendable where SignedType: Sendable {
    case unverified(SignedType, VerificationError)
    case verified(SignedType)
    public enum VerificationError: Error, Sendable { case revokedCertificate, invalidCertificateChain, invalidDeviceVerification, invalidEncoding, invalidSignature, missingRequiredProperties }
    public var unsafePayloadValue: SignedType {
        switch self { case .verified(let v), .unverified(let v, _): return v }
    }
    public func payloadValue() throws -> SignedType {
        switch self { case .verified(let v): return v; case .unverified(_, let e): throw e }
    }
}

public struct Transaction: Identifiable, Hashable, Sendable {
    public let id: UInt64
    public let productID: String
    public let productType: Product.ProductType
    public let purchaseDate: Date
    public let revocationDate: Date?
    public var originalID: UInt64 { id }
    public var expirationDate: Date? { nil }
    public var isUpgraded: Bool { false }
    public var purchasedQuantity: Int { 1 }

    public func finish() async {}

    /// Transactions made outside the app's purchase calls (none in local testing on isim).
    public static var updates: Transactions { Transactions(items: []) }
    /// Non-consumables (and active subscriptions) the user owns.
    public static var currentEntitlements: Transactions {
        Transactions(items: _SKLedger.all().compactMap(Transaction.init(record:)).filter { $0.productType != .consumable }.map { .verified($0) })
    }
    public static var all: Transactions {
        Transactions(items: _SKLedger.all().compactMap(Transaction.init(record:)).map { .verified($0) })
    }
    public static func currentEntitlement(for productID: String) async -> VerificationResult<Transaction>? {
        for await r in currentEntitlements { if case .verified(let t) = r, t.productID == productID { return r } }
        return nil
    }
    public static func latest(for productID: String) async -> VerificationResult<Transaction>? {
        var last: VerificationResult<Transaction>?
        for await r in all { if case .verified(let t) = r, t.productID == productID { last = r } }
        return last
    }

    init(id: UInt64, productID: String, productType: Product.ProductType, purchaseDate: Date, revocationDate: Date?) {
        self.id = id; self.productID = productID; self.productType = productType; self.purchaseDate = purchaseDate; self.revocationDate = revocationDate
    }
    init?(record r: [String: Any]) {
        guard let id = (r["id"] as? NSNumber)?.uint64Value, let pid = r["productID"] as? String else { return nil }
        self.init(id: id, productID: pid, productType: Product.ProductType(rawValue: r["type"] as? String ?? "Consumable"),
                  purchaseDate: Date(timeIntervalSince1970: (r["date"] as? NSNumber)?.doubleValue ?? 0), revocationDate: nil)
    }

    public struct Transactions: AsyncSequence, Sendable {
        public typealias Element = VerificationResult<Transaction>
        let items: [Element]
        public struct AsyncIterator: AsyncIteratorProtocol {
            var items: [Element]
            var i = 0
            public mutating func next() async -> Element? {
                guard i < items.count else { return nil }
                defer { i += 1 }
                return items[i]
            }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(items: items) }
    }
}

public enum AppStore {
    /// Restores purchases: in local testing the ledger is already on the device.
    public static func sync() async throws {}
    public static var canMakePayments: Bool { true }
}

// MARK: - Purchase sheet

@MainActor enum _SKPurchaseSheet {
    static func confirm(_ p: Product) async -> Bool {
        await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            guard let top = topController() else { k.resume(returning: false); return }
            let alert = UIAlertController(title: "Confirm Your In-App Purchase",
                                          message: "Do you want to buy one \(p.displayName) for \(p.displayPrice)?\n\n[Environment: isim StoreKit testing — nothing is charged]",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in k.resume(returning: false) })
            alert.addAction(UIAlertAction(title: "Buy", style: .default) { _ in k.resume(returning: true) })
            top.present(alert, animated: true, completion: nil)
        }
    }
    static func topController() -> UIViewController? {
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}
