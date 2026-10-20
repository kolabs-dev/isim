// isim StoreKitTest: SKTestSession, for StoreKit tests in XCTest / Swift Testing bundles — a StoreKit configuration
// file, transactions to inspect and edit, Ask to Buy, interrupted purchases, renewals, expirations, refunds and
// billing retry — over isim's local store (the same ledger `isim storekit` edits). Self-authored, iOS API names.
// Adapted: changes take effect in the app's process at once, as with Xcode's StoreKit testing; price increase
// consent is accepted and has no effect (isim's local store has no price increases); simulated errors are not there.
import Foundation
@_exported import StoreKit

public let SKTestErrorDomain = "SKTestErrorDomain"

/// A local StoreKit testing session (Xcode's StoreKit Testing in Xcode, for tests).
open class SKTestSession: NSObject {
    public enum TimeRate: Int, Sendable {
        case realTime = 0, oneSecondIsOneDay = 1, oneRenewalEveryTwoSeconds = 2, oneRenewalEveryTenSeconds = 3, oneRenewalEveryFifteenSeconds = 4
        case oneRenewalEveryThirtySeconds = 5, oneRenewalEveryMinute = 6, monthlyRenewalEveryThirtySeconds = 7, monthlyRenewalEveryMinute = 8
        case monthlyRenewalEveryFiveMinutes = 9, monthlyRenewalEveryFifteenMinutes = 10, monthlyRenewalEveryThirtyMinutes = 11, monthlyRenewalEveryHour = 12
    }
    let url: URL

    /// a .storekit file of the project, by name without the extension: in the test or app bundle, else (as Xcode
    /// does not copy .storekit files into products) in the project's folders, which `isim test` passes as
    /// ISIM_SRCROOT
    public convenience init(configurationFileNamed name: String) throws {
        let base = name.hasSuffix(".storekit") ? String(name.dropLast(9)) : name
        let bundles = Bundle.allBundles + Bundle.allFrameworks + [Bundle.main]
        if let url = bundles.lazy.compactMap({ $0.url(forResource: base, withExtension: "storekit") }).first {
            try self.init(contentsOf: url)
            return
        }
        guard let root = ProcessInfo.processInfo.environment["ISIM_SRCROOT"], let url = SKTestSession.find(base + ".storekit", in: root) else {
            throw NSError(domain: SKTestErrorDomain, code: 2, userInfo: [NSLocalizedDescriptionKey: "No StoreKit configuration named \(base).storekit in the test or app bundles or the project"])
        }
        try self.init(contentsOf: url)
    }
    /// the shallowest file of that name under root (build products and package checkouts are skipped)
    static func find(_ file: String, in root: String) -> URL? {
        var best: (depth: Int, url: URL)?
        let fm = FileManager.default
        guard let e = fm.enumerator(at: URL(fileURLWithPath: root), includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]) else { return nil }
        for case let u as URL in e {
            if ["build", "DerivedData", ".build", "SourcePackages"].contains(u.lastPathComponent) { e.skipDescendants(); continue }
            guard u.lastPathComponent == file else { continue }
            let depth = u.pathComponents.count
            if best == nil || depth < best!.depth { best = (depth, u) }
        }
        return best?.url
    }
    public init(contentsOf url: URL) throws {
        self.url = url
        try _SKTesting.load(url.path)
        super.init()
    }
    public convenience init(contentsOfURL url: URL) throws { try self.init(contentsOf: url) }

    /// clears the transactions and puts every setting back
    open func resetToDefaultState() {
        _SKTesting.clear()
        disableDialogs = false; askToBuyEnabled = false; interruptedPurchasesEnabled = false
        shouldEnterBillingRetryOnRenewal = false
        try? _SKTesting.load(url.path)
    }

    // environment
    open var storefront: String { get { _SKTesting.storefront } set { _SKTesting.storefront = newValue } }
    open var locale = Locale(identifier: "en_US")
    /// purchases confirm without the sheet; StoreKit's notices are not shown
    open var disableDialogs: Bool { get { _SKTesting.disableDialogs } set { _SKTesting.disableDialogs = newValue } }

    // transactions
    open func allTransactions() -> [SKTestTransaction] { _SKTesting.transactions().map(SKTestTransaction.init) }
    open func deleteTransaction(identifier: Int) throws { try wrap { try _SKTesting.delete(identifier) } }
    open func clearTransactions() { _SKTesting.clear() }

    // failures (deprecated in iOS 17; failed purchases are not simulated)
    open var failTransactionsEnabled = false
    open var failureError: SKError.Code = .unknown

    // interrupted purchases
    open var interruptedPurchasesEnabled: Bool {
        get { _SKTesting.interruptedPurchases } set { _SKTesting.interruptedPurchases = newValue }
    }
    open func resolveIssueForTransaction(identifier: Int) throws { try wrap { try _SKTesting.resolveIssue(identifier) } }

    // Ask to Buy
    open var askToBuyEnabled: Bool { get { _SKTesting.askToBuy ?? false } set { _SKTesting.askToBuy = newValue } }
    open func approveAskToBuyTransaction(identifier: Int) throws { try wrap { try _SKTesting.answer(identifier, approve: true) } }
    open func declineAskToBuyTransaction(identifier: Int) throws { try wrap { try _SKTesting.answer(identifier, approve: false) } }

    // renewals
    open var timeRate: TimeRate {
        get { TimeRate(rawValue: _SKTesting.timeRate) ?? .realTime } set { _SKTesting.timeRate = newValue.rawValue }
    }
    open func enableAutoRenewForTransaction(identifier: Int) throws { try wrap { try _SKTesting.setAutoRenew(transaction: identifier, true) } }
    open func disableAutoRenewForTransaction(identifier: Int) throws { try wrap { try _SKTesting.setAutoRenew(transaction: identifier, false) } }
    open func forceRenewalOfSubscription(productIdentifier: String) throws { try wrap { try _SKTesting.forceRenewal(productIdentifier) } }
    open func expireSubscription(productIdentifier: String) throws { try wrap { try _SKTesting.expire(productIdentifier) } }

    // billing retry and grace period
    open var billingGracePeriodIsEnabled: Bool { get { _SKTesting.billingGracePeriod } set { _SKTesting.billingGracePeriod = newValue } }
    open var shouldEnterBillingRetryOnRenewal = false { didSet { _SKTesting.setBillingIssue(shouldEnterBillingRetryOnRenewal) } }

    // price increases: accepted, without effect
    open func requestPriceIncreaseConsentForTransaction(identifier: Int) throws { try existing(identifier) }
    open func consentToPriceIncreaseForTransaction(identifier: Int) throws { try existing(identifier) }
    open func declinePriceIncreaseForTransaction(identifier: Int) throws { try existing(identifier) }

    // purchases outside the app
    open func refundTransaction(identifier: Int) throws { try wrap { try _SKTesting.refund(identifier) } }
    /// buys as the customer would outside the app (no sheet); the transaction also arrives in Transaction.updates
    @MainActor open func buyProduct(identifier: Product.ID, options: Set<Product.PurchaseOption> = []) async throws -> Transaction {
        try await _SKTesting.buy(identifier, options: options)
    }
    @available(*, deprecated, message: "Use buyProduct(identifier:options:)")
    open func buyProduct(productIdentifier: String) throws {
        Task { @MainActor in _ = try? await _SKTesting.buy(productIdentifier, options: []) }
    }

    func existing(_ id: Int) throws {
        guard allTransactions().contains(where: { $0.identifier == id }) else { throw error(_SKTesting.Failure.noTransaction(id)) }
    }
    func wrap(_ f: () throws -> Void) throws { do { try f() } catch { throw self.error(error) } }
    func error(_ e: Error) -> NSError {
        let text: String
        switch e as? _SKTesting.Failure {
        case .noTransaction(let id)?: text = "No transaction with identifier \(id)"
        case .noSubscription(let p)?: text = "No subscription to \(p)"
        case .notPending(let id)?: text = "Transaction \(id) is not waiting for an answer"
        default: return e as NSError
        }
        return NSError(domain: SKTestErrorDomain, code: 3, userInfo: [NSLocalizedDescriptionKey: text])
    }
}

/// A transaction of the test session, as Xcode's Transaction Manager shows it.
open class SKTestTransaction: NSObject {
    public let identifier: Int
    public let originalTransactionIdentifier: Int
    public let productIdentifier: String
    public let purchaseDate: Date
    public let expirationDate: Date?
    public let revocationDate: Date?
    public let webOrderLineItemID: String?
    public let state: SKPaymentTransactionState
    public let autoRenewingEnabled: Bool
    public let hasPurchaseIssue: Bool
    public let pendingAskToBuyConfirmation: Bool
    public let isUpgraded: Bool
    public var refunded: Bool { revocationDate != nil }
    init(_ r: _SKTesting.Record) {
        identifier = r.id; originalTransactionIdentifier = r.originalID; productIdentifier = r.productID; purchaseDate = r.purchaseDate
        expirationDate = r.expirationDate; revocationDate = r.revocationDate; webOrderLineItemID = r.webOrderLineItemID
        state = r.pendingAskToBuy || r.interrupted ? .deferred : .purchased
        autoRenewingEnabled = r.willAutoRenew; hasPurchaseIssue = r.interrupted || r.billingIssue
        pendingAskToBuyConfirmation = r.pendingAskToBuy; isUpgraded = r.isUpgraded
    }
}
