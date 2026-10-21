// isim StoreKit: what StoreKitTest's SKTestSession drives — the local store's configuration, its dialogs and its
// transactions — exposed to the StoreKitTest overlay as `_SKTesting`. Not Apple API: an isim implementation detail
// (StoreKitTest is a separate module in Apple's SDK too, talking to the StoreKit daemon).
import Foundation

public enum _SKTesting {
    /// purchases confirm without the sheet, notices are not shown (SKTestSession.disableDialogs)
    nonisolated(unsafe) public static var disableDialogs = false
    /// overrides the configuration's Ask to Buy setting (SKTestSession.askToBuyEnabled)
    nonisolated(unsafe) public static var askToBuy: Bool?
    /// purchases need the customer's action before they complete (SKTestSession.interruptedPurchasesEnabled)
    nonisolated(unsafe) public static var interruptedPurchases = false

    /// SKTestSession.setSimulatedError(_:forAPI:): the error each failable StoreKit API throws while it is set, by
    /// the API's name (loadProducts, purchase, verification, appStoreSync, appTransaction, subscriptionStatus,
    /// refundRequest, manageSubscriptions, offerCodeRedeem)
    nonisolated(unsafe) static var simulatedErrors: [String: Error] = [:]
    static let simulatedLock = NSLock()
    public static func setSimulatedError(_ error: Error?, forAPI api: String) {
        simulatedLock.lock(); simulatedErrors[api] = error; simulatedLock.unlock()
        NSLog("isim StoreKit: simulated error for %@: %@", api, error.map { String(describing: $0) } ?? "none")
    }
    static func simulatedError(_ api: String) -> Error? { simulatedLock.lock(); defer { simulatedLock.unlock() }; return simulatedErrors[api] }
    /// throws the API's simulated error, if one is set
    static func check(_ api: String) throws {
        if let e = simulatedError(api) { NSLog("isim StoreKit: %@ fails with the simulated error %@", api, String(describing: e)); throw e }
    }
    /// a transaction as a verification result: unverified with the simulated verification error, if one is set
    static func verify(_ t: Transaction) -> VerificationResult<Transaction> {
        if let e = simulatedError("verification") as? VerificationResult<Transaction>.VerificationError { return .unverified(t, e) }
        return .verified(t)
    }

    /// uses the .storekit file at `path` instead of the bundle's
    public static func load(_ path: String) throws {
        guard let d = FileManager.default.contents(atPath: path), (try? JSONSerialization.jsonObject(with: d)) is [String: Any] else {
            throw NSError(domain: "SKTestErrorDomain", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read StoreKit configuration \(path)"])
        }
        _SKConfig.overridePath = path
        _SKConfig.cached = nil
        let c = _SKConfig.load()
        NSLog("isim StoreKit: SKTestSession uses %@ (%ld products)", (path as NSString).lastPathComponent, c.items.count)
        _SKUpdates.start()
    }
    /// Xcode's time rate, by SKTestSession.TimeRate's raw value
    public static var timeRate: Int {
        get {
            switch _SKConfig.load().timeRate {
            case .realTime: return 0
            case .oneSecondIsOneDay: return 1
            case .perRenewal(let s): return [2: 2, 10: 3, 15: 4, 30: 5, 60: 6][Int(s)] ?? 0
            case .perMonth(let s): return [30: 7, 60: 8, 300: 9, 900: 10, 1800: 11, 3600: 12][Int(s)] ?? 0
            }
        }
        set { _ = _SKConfig.load(); _SKConfig.cached?.timeRate = .xcode(newValue) }
    }
    public static var storefront: String {
        get { _SKConfig.load().storefront }
        set { _ = _SKConfig.load(); _SKConfig.cached?.storefront = newValue }
    }
    public static var billingGracePeriod: Bool {
        get { _SKConfig.load().gracePeriod }
        set { _ = _SKConfig.load(); _SKConfig.cached?.gracePeriod = newValue }
    }
    /// renewals fail with a billing issue while set (SKTestSession.shouldEnterBillingRetryOnRenewal)
    public static func setBillingIssue(_ on: Bool) {
        _SKLedger.shared.mutate { d in for g in d.subscriptions.keys { d.subscriptions[g]?.billingIssue = on } }
    }

    /// The local store's transactions, oldest first, as SKTestTransaction reads them.
    public struct Record: Sendable {
        public let id: Int, originalID: Int, productID: String, purchaseDate: Date, expirationDate: Date?, revocationDate: Date?
        public let isUpgraded: Bool, finished: Bool, willAutoRenew: Bool, billingIssue: Bool, pendingAskToBuy: Bool, interrupted: Bool
        public let webOrderLineItemID: String?, offerID: String?
    }
    public static func transactions() -> [Record] {
        _SKLedger.shared.read { d in
            var out = d.transactions.map { t -> Record in
                let s = t.groupID.flatMap { d.subscriptions[$0] }
                return Record(id: Int(t.id), originalID: Int(t.originalID), productID: t.productID, purchaseDate: Date(timeIntervalSince1970: t.purchaseDate),
                              expirationDate: t.expirationDate.map { Date(timeIntervalSince1970: $0) }, revocationDate: t.revocationDate.map { Date(timeIntervalSince1970: $0) },
                              isUpgraded: t.isUpgraded, finished: t.finished, willAutoRenew: s?.willAutoRenew ?? false, billingIssue: s?.billingIssue ?? false,
                              pendingAskToBuy: false, interrupted: false, webOrderLineItemID: t.groupID == nil ? nil : "\(t.id)", offerID: t.offerID)
            }
            for a in d.askToBuy ?? [] where a.state == "pending" {
                out.append(Record(id: Int(a.id), originalID: Int(a.id), productID: a.productID, purchaseDate: Date(timeIntervalSince1970: a.requested),
                                  expirationDate: nil, revocationDate: nil, isUpgraded: false, finished: false, willAutoRenew: false, billingIssue: false,
                                  pendingAskToBuy: a.interrupted != true, interrupted: a.interrupted == true, webOrderLineItemID: nil, offerID: a.offerID))
            }
            return out.sorted { $0.id < $1.id }
        }
    }

    public enum Failure: Error { case noTransaction(Int), noSubscription(String), notPending(Int) }

    public static func clear() {
        _SKLedger.shared.mutate { d in d.transactions = []; d.subscriptions = [:]; d.askToBuy = nil; d.usedOfferNonces = nil; d.redeemedOffers = nil; d.messages = nil }
        NSLog("isim StoreKit: SKTestSession cleared the transactions")
    }
    public static func delete(_ id: Int) throws {
        try _SKLedger.shared.mutate { d in
            guard let i = d.transactions.firstIndex(where: { $0.id == UInt64(id) }) else { throw Failure.noTransaction(id) }
            d.transactions.remove(at: i)
        }
    }
    public static func refund(_ id: Int) throws {
        guard _SKLedger.shared.transaction(UInt64(id)) != nil else { throw Failure.noTransaction(id) }
        _SKLedger.shared.revoke(UInt64(id))
    }
    /// the subscription group of a product's latest transaction
    static func group(_ productID: String) throws -> String {
        guard let g = _SKConfig.load().item(productID)?.groupID, _SKLedger.shared.everSubscribed(group: g) else { throw Failure.noSubscription(productID) }
        return g
    }
    public static func expire(_ productID: String) throws {
        let g = try group(productID)
        let now = Date().timeIntervalSince1970
        _SKLedger.shared.mutate { d in
            d.subscriptions[g]?.willAutoRenew = false
            d.subscriptions[g]?.expirationReason = 1
            if let t = _SKLedger.latest(d, group: g), let i = d.transactions.firstIndex(where: { $0.id == t.id }), (t.expirationDate ?? 0) > now {
                d.transactions[i].expirationDate = now
            }
        }
        _SKLedger.shared.tick()
    }
    /// renews now: the current period ends, and the subscription clock renews it
    public static func forceRenewal(_ productID: String) throws {
        let g = try group(productID)
        let now = Date().timeIntervalSince1970
        _SKLedger.shared.mutate { d in
            if let t = _SKLedger.latest(d, group: g), let i = d.transactions.firstIndex(where: { $0.id == t.id }) { d.transactions[i].expirationDate = now }
        }
        _SKLedger.shared.tick()
    }
    public static func setAutoRenew(transaction id: Int, _ on: Bool) throws {
        guard let g = _SKLedger.shared.transaction(UInt64(id))?.groupID else { throw Failure.noTransaction(id) }
        _SKLedger.shared.setAutoRenew(group: g, on)
    }
    /// answers a pending Ask to Buy or interrupted purchase
    public static func answer(_ id: Int, approve: Bool) throws {
        try _SKLedger.shared.mutate { d in
            guard let i = (d.askToBuy ?? []).firstIndex(where: { $0.id == UInt64(id) && $0.state == "pending" }) else { throw Failure.notPending(id) }
            d.askToBuy?[i].state = approve ? "approved" : "declined"
        }
        _SKLedger.shared.answerAskToBuy()
    }
    /// resolves an interrupted purchase, or a subscription's billing issue
    public static func resolveIssue(_ id: Int) throws {
        if (try? answer(id, approve: true)) != nil { return }
        guard let g = _SKLedger.shared.transaction(UInt64(id))?.groupID else { throw Failure.noTransaction(id) }
        _SKLedger.shared.mutate { d in d.subscriptions[g]?.billingIssue = false }
    }
    /// a purchase made outside the app (as SKTestSession.buyProduct does): no sheet; it arrives in Transaction.updates
    @MainActor public static func buy(_ productID: String, options: Set<Product.PurchaseOption>) async throws -> Transaction {
        guard let item = _SKConfig.load().item(productID) else { throw Product.PurchaseError.productUnavailable }
        let was = disableDialogs
        disableDialogs = true
        defer { disableDialogs = was }
        let r = try await Product(item)._purchase(options: options, api: nil)
        guard case .success(let v) = r else { throw StoreKitError.unknown }
        let t = v.unsafePayloadValue
        _SKUpdates.transactions.yield(v)
        return t
    }
}
