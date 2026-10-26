// isim StoreKitTest: SKTestSession, for StoreKit tests in XCTest / Swift Testing bundles — a StoreKit configuration
// file, transactions to inspect and edit, Ask to Buy, interrupted purchases, renewals, expirations, refunds and
// billing retry — over isim's local store (the same ledger `isim storekit` edits). Self-authored, iOS API names.
// Adapted: changes take effect in the app's process at once, as with Xcode's StoreKit testing; price increase
// consent is accepted and has no effect (isim's local store has no price increases). Simulated errors
// (setSimulatedError(_:forAPI:)) make the StoreKit API throw them, as Xcode's StoreKit testing does.
import Foundation
@_exported import StoreKit

public let SKTestErrorDomain = "SKTestErrorDomain"

/// A local StoreKit testing session (Xcode's StoreKit Testing in Xcode, for tests).
@objc(SKTestSession) open class SKTestSession: NSObject {
    public enum TimeRate: Int, Sendable {
        case realTime = 0, oneSecondIsOneDay = 1, oneRenewalEveryTwoSeconds = 2, oneRenewalEveryTenSeconds = 3, oneRenewalEveryFifteenSeconds = 4
        case oneRenewalEveryThirtySeconds = 5, oneRenewalEveryMinute = 6, monthlyRenewalEveryThirtySeconds = 7, monthlyRenewalEveryMinute = 8
        case monthlyRenewalEveryFiveMinutes = 9, monthlyRenewalEveryFifteenMinutes = 10, monthlyRenewalEveryThirtyMinutes = 11, monthlyRenewalEveryHour = 12
    }
    @objc let url: URL

    /// a .storekit file of the project, by name without the extension: in the test or app bundle, else (as Xcode
    /// does not copy .storekit files into products) in the project's folders, which `isim test` passes as
    /// ISIM_SRCROOT
    @objc public convenience init(configurationFileNamed name: String) throws {
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
    @objc static func find(_ file: String, in root: String) -> URL? {
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
    @objc public init(contentsOf url: URL) throws {
        self.url = url
        try _SKTesting.load(url.path)
        super.init()
    }
    @objc public convenience init(contentsOfURL url: URL) throws { try self.init(contentsOf: url) }

    /// clears the transactions and puts every setting back
    @objc open func resetToDefaultState() {
        _SKTesting.clear()
        disableDialogs = false; askToBuyEnabled = false; interruptedPurchasesEnabled = false
        for key in _SKTestFailureStore.clear() { _SKTesting.setSimulatedError(nil, forAPI: key) }
        shouldEnterBillingRetryOnRenewal = false
        try? _SKTesting.load(url.path)
    }

    // environment
    @objc open var storefront: String { get { _SKTesting.storefront } set { _SKTesting.storefront = newValue } }
    @objc open var locale = Locale(identifier: "en_US")
    /// purchases confirm without the sheet; StoreKit's notices are not shown
    @objc open var disableDialogs: Bool { get { _SKTesting.disableDialogs } set { _SKTesting.disableDialogs = newValue } }

    // transactions
    @objc open func allTransactions() -> [SKTestTransaction] { _SKTesting.transactions().map(SKTestTransaction.init) }
    @objc open func deleteTransaction(identifier: Int) throws { try wrap { try _SKTesting.delete(identifier) } }
    @objc open func clearTransactions() { _SKTesting.clear() }

    // failures (deprecated in iOS 17; failed purchases are not simulated)
    @objc open var failTransactionsEnabled = false
    open var failureError: SKError.Code = .unknown

    // interrupted purchases
    @objc open var interruptedPurchasesEnabled: Bool {
        get { _SKTesting.interruptedPurchases } set { _SKTesting.interruptedPurchases = newValue }
    }
    @objc open func resolveIssueForTransaction(identifier: Int) throws { try wrap { try _SKTesting.resolveIssue(identifier) } }

    // Ask to Buy
    @objc open var askToBuyEnabled: Bool { get { _SKTesting.askToBuy ?? false } set { _SKTesting.askToBuy = newValue } }
    @objc open func approveAskToBuyTransaction(identifier: Int) throws { try wrap { try _SKTesting.answer(identifier, approve: true) } }
    @objc open func declineAskToBuyTransaction(identifier: Int) throws { try wrap { try _SKTesting.answer(identifier, approve: false) } }

    // renewals
    open var timeRate: TimeRate {
        get { TimeRate(rawValue: _SKTesting.timeRate) ?? .realTime } set { _SKTesting.timeRate = newValue.rawValue }
    }
    @objc open func enableAutoRenewForTransaction(identifier: Int) throws { try wrap { try _SKTesting.setAutoRenew(transaction: identifier, true) } }
    @objc open func disableAutoRenewForTransaction(identifier: Int) throws { try wrap { try _SKTesting.setAutoRenew(transaction: identifier, false) } }
    @objc open func forceRenewalOfSubscription(productIdentifier: String) throws { try wrap { try _SKTesting.forceRenewal(productIdentifier) } }
    @objc open func expireSubscription(productIdentifier: String) throws { try wrap { try _SKTesting.expire(productIdentifier) } }

    // billing retry and grace period
    @objc open var billingGracePeriodIsEnabled: Bool { get { _SKTesting.billingGracePeriod } set { _SKTesting.billingGracePeriod = newValue } }
    @objc open var shouldEnterBillingRetryOnRenewal = false { didSet { _SKTesting.setBillingIssue(shouldEnterBillingRetryOnRenewal) } }

    // price increases: accepted, without effect
    @objc open func requestPriceIncreaseConsentForTransaction(identifier: Int) throws { try existing(identifier) }
    @objc open func consentToPriceIncreaseForTransaction(identifier: Int) throws { try existing(identifier) }
    @objc open func declinePriceIncreaseForTransaction(identifier: Int) throws { try existing(identifier) }

    // purchases outside the app
    @objc open func refundTransaction(identifier: Int) throws { try wrap { try _SKTesting.refund(identifier) } }
    /// buys as the customer would outside the app (no sheet); the transaction also arrives in Transaction.updates
    @MainActor @nonobjc open func buyProduct(identifier: Product.ID, options: Set<Product.PurchaseOption> = []) async throws -> Transaction {
        try await _SKTesting.buy(identifier, options: options)
    }
    @available(*, deprecated, message: "Use buyProduct(identifier:options:)")
    @objc open func buyProduct(productIdentifier: String) throws {
        Task { @MainActor in _ = try? await _SKTesting.buy(productIdentifier, options: []) }
    }

    // simulated errors (iOS 17): the StoreKit API fails with the failure while it is set
    @available(iOS 17.0, *)
    @nonobjc open func setSimulatedError<API: FailableStoreKitAPI>(_ error: API.Failure?, forAPI api: API) async throws {
        let key = API._isimName
        _SKTestFailureStore.set(error, key)
        _SKTesting.setSimulatedError(error.map(SKTestFailures._error), forAPI: key)
    }
    @available(iOS 17.0, *)
    @nonobjc open func simulatedError<API: FailableStoreKitAPI>(forAPI api: API) async -> API.Failure? {
        _SKTestFailureStore.get(API._isimName) as? API.Failure
    }

    @objc func existing(_ id: Int) throws {
        guard allTransactions().contains(where: { $0.identifier == id }) else { throw error(_SKTesting.Failure.noTransaction(id)) }
    }
    func wrap(_ f: () throws -> Void) throws { do { try f() } catch { throw self.error(error) } }
    @objc func error(_ e: Error) -> NSError {
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
@objc(SKTestTransaction) open class SKTestTransaction: NSObject {
    @objc public let identifier: Int
    @objc public let originalTransactionIdentifier: Int
    @objc public let productIdentifier: String
    @objc public let purchaseDate: Date
    @objc public let expirationDate: Date?
    @objc public let revocationDate: Date?
    @objc public let webOrderLineItemID: String?
    public let state: SKPaymentTransactionState
    @objc public let autoRenewingEnabled: Bool
    @objc public let hasPurchaseIssue: Bool
    @objc public let pendingAskToBuyConfirmation: Bool
    @objc public let isUpgraded: Bool
    @objc public var refunded: Bool { revocationDate != nil }
    init(_ r: _SKTesting.Record) {
        identifier = r.id; originalTransactionIdentifier = r.originalID; productIdentifier = r.productID; purchaseDate = r.purchaseDate
        expirationDate = r.expirationDate; revocationDate = r.revocationDate; webOrderLineItemID = r.webOrderLineItemID
        state = r.pendingAskToBuy || r.interrupted ? .deferred : .purchased
        autoRenewingEnabled = r.willAutoRenew; hasPurchaseIssue = r.interrupted || r.billingIssue
        pendingAskToBuyConfirmation = r.pendingAskToBuy; isUpgraded = r.isUpgraded
    }
}

// MARK: - simulated errors (iOS 17)

/// A failure a StoreKit API can be made to throw (SKTestFailures' enums).
@available(iOS 17.0, *)
public protocol SKTestFailure: Error, Sendable {}

/// A StoreKit API that SKTestSession can make fail (`.loadProducts`, `.purchase`, …).
@available(iOS 17.0, *)
public protocol FailableStoreKitAPI: Sendable {
    associatedtype Failure: SKTestFailure
}
@available(iOS 17.0, *)
extension FailableStoreKitAPI {
    /// the StoreKit overlay's name for the API (isim)
    static var _isimName: String {
        switch self {
        case is StoreKitLoadProductsAPI.Type: return "loadProducts"
        case is StoreKitPurchaseAPI.Type: return "purchase"
        case is StoreKitVerificationAPI.Type: return "verification"
        case is StoreKitAppStoreSyncAPI.Type: return "appStoreSync"
        case is StoreKitAppTransactionAPI.Type: return "appTransaction"
        case is StoreKitSubscriptionStatusAPI.Type: return "subscriptionStatus"
        case is StoreKitRefundRequestAPI.Type: return "refundRequest"
        case is StoreKitManageSubscriptionsAPI.Type: return "manageSubscriptions"
        case is StoreKitOfferCodeRedeemAPI.Type: return "offerCodeRedeem"
        default: return String(describing: self)
        }
    }
}
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitLoadProductsAPI { public static var loadProducts: StoreKitLoadProductsAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitPurchaseAPI { public static var purchase: StoreKitPurchaseAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitVerificationAPI { public static var verification: StoreKitVerificationAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitAppStoreSyncAPI { public static var appStoreSync: StoreKitAppStoreSyncAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitAppTransactionAPI { public static var appTransaction: StoreKitAppTransactionAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitSubscriptionStatusAPI {
    public static var subscriptionStatus: StoreKitSubscriptionStatusAPI { .init() }
}
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitRefundRequestAPI { public static var refundRequest: StoreKitRefundRequestAPI { .init() } }
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitManageSubscriptionsAPI {
    public static var manageSubscriptions: StoreKitManageSubscriptionsAPI { .init() }
}
@available(iOS 17.0, *) extension FailableStoreKitAPI where Self == StoreKitOfferCodeRedeemAPI { public static var offerCodeRedeem: StoreKitOfferCodeRedeemAPI { .init() } }

@available(iOS 17.0, *) public struct StoreKitLoadProductsAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.LoadProducts; public init() {} }
@available(iOS 17.0, *) public struct StoreKitPurchaseAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.Purchase; public init() {} }
@available(iOS 17.0, *) public struct StoreKitVerificationAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.Verification; public init() {} }
@available(iOS 17.0, *) public struct StoreKitAppStoreSyncAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.AppStoreSync; public init() {} }
@available(iOS 17.0, *) public struct StoreKitAppTransactionAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.AppTransaction; public init() {} }
@available(iOS 17.0, *) public struct StoreKitSubscriptionStatusAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.SubscriptionStatus; public init() {} }
@available(iOS 17.0, *) public struct StoreKitRefundRequestAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.RefundRequest; public init() {} }
@available(iOS 17.0, *) public struct StoreKitManageSubscriptionsAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.ManageSubscriptions; public init() {} }
@available(iOS 17.0, *) public struct StoreKitOfferCodeRedeemAPI: FailableStoreKitAPI { public typealias Failure = SKTestFailures.OfferCodeRedeem; public init() {} }

/// The failures each failable StoreKit API can be made to throw.
@available(iOS 17.0, *)
public enum SKTestFailures: Sendable {
    public enum LoadProducts: SKTestFailure { case generic(StoreKitError) }
    public enum Purchase: SKTestFailure { case generic(StoreKitError), purchase(Product.PurchaseError) }
    /// (VerificationResult<Any>'s error, as on iOS: its errors are values, though Any is not Sendable)
    public enum Verification: SKTestFailure, @unchecked Sendable { case verification(VerificationResult<Any>.VerificationError) }
    public enum AppStoreSync: SKTestFailure { case generic(StoreKitError) }
    public enum AppTransaction: SKTestFailure { case generic(StoreKitError) }
    public enum SubscriptionStatus: SKTestFailure { case generic(StoreKitError) }
    public enum RefundRequest: SKTestFailure { case generic(StoreKitError), refundRequest(Transaction.RefundRequestError) }
    public enum ManageSubscriptions: SKTestFailure { case generic(StoreKitError) }
    public enum OfferCodeRedeem: SKTestFailure { case generic(StoreKitError) }

    /// the error the StoreKit API throws (or, for verification, reports) for a failure
    static func _error(_ f: any SKTestFailure) -> Error {
        switch f {
        case let f as LoadProducts: if case .generic(let e) = f { return e }
        case let f as Purchase: switch f { case .generic(let e): return e; case .purchase(let e): return e }
        case let f as Verification:
            if case .verification(let e) = f { return _transactionVerificationError(e) }
        case let f as AppStoreSync: if case .generic(let e) = f { return e }
        case let f as AppTransaction: if case .generic(let e) = f { return e }
        case let f as SubscriptionStatus: if case .generic(let e) = f { return e }
        case let f as RefundRequest: switch f { case .generic(let e): return e; case .refundRequest(let e): return e }
        case let f as ManageSubscriptions: if case .generic(let e) = f { return e }
        case let f as OfferCodeRedeem: if case .generic(let e) = f { return e }
        default: break
        }
        return f
    }
}

/// the same verification error for transactions (VerificationError is nested in the generic VerificationResult)
@available(iOS 17.0, *)
func _transactionVerificationError(_ e: VerificationResult<Any>.VerificationError) -> VerificationResult<Transaction>.VerificationError {
    switch e {
    case .revokedCertificate: return .revokedCertificate
    case .invalidCertificateChain: return .invalidCertificateChain
    case .invalidDeviceVerification: return .invalidDeviceVerification
    case .invalidEncoding: return .invalidEncoding
    case .invalidSignature: return .invalidSignature
    case .missingRequiredProperties: return .missingRequiredProperties
    @unknown default: return .invalidSignature
    }
}

/// the failures set on the session, by API (what simulatedError(forAPI:) returns)
enum _SKTestFailureStore {
    nonisolated(unsafe) static var failures: [String: Any] = [:]
    static let lock = NSLock()
    static func set(_ f: Any?, _ key: String) { lock.lock(); failures[key] = f; lock.unlock() }
    static func get(_ key: String) -> Any? { lock.lock(); defer { lock.unlock() }; return failures[key] }
    /// clears them; returns their keys
    static func clear() -> [String] { lock.lock(); defer { lock.unlock() }; let k = Array(failures.keys); failures = [:]; return k }
}

// MARK: - Objective-C (sdk-src/Frameworks/StoreKitTest, issue #564): the Swift-only enums as raw values

extension SKTestSession {
    /// SKTestTimeRate's raw value
    @objc(timeRate) var _objcTimeRate: Int {
        get { timeRate.rawValue }
        set { timeRate = TimeRate(rawValue: newValue) ?? .realTime }
    }
    /// SKErrorCode's raw value
    @objc(failureError) var _objcFailureError: Int {
        get { failureError.rawValue }
        set { failureError = SKError.Code(rawValue: newValue) ?? .unknown }
    }
}
extension SKTestTransaction {
    /// SKPaymentTransactionState's raw value
    @objc(state) var _objcState: Int { state.rawValue }
}
