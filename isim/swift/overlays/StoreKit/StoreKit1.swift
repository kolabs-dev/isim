// isim StoreKit 1 (original API): SKProductsRequest, SKPaymentQueue + SKPaymentTransactionObserver,
// SKPayment, SKProduct / SKProductDiscount, the app receipt, SKStoreProductViewController and SKOverlay.
// It shares the local StoreKit testing ledger with StoreKit 2: products come from the .storekit file,
// purchases show the same confirmation sheet, renewals and refunds reach the transaction observer.
// The app receipt (Bundle.main.appStoreReceiptURL) is a LOCAL, UNSIGNED JSON document written by isim —
// not a PKCS #7 container and not signed by Apple; receipt validation code will (rightly) reject it.
import UIKit
import SwiftUI

public let SKErrorDomain = "SKErrorDomain"
public struct SKError: Error, CustomNSError, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 0, clientInvalid = 1, paymentCancelled = 2, paymentInvalid = 3, paymentNotAllowed = 4, storeProductNotAvailable = 5,
             cloudServicePermissionDenied = 6, cloudServiceNetworkConnectionFailed = 7, cloudServiceRevoked = 8, privacyAcknowledgementRequired = 9,
             unauthorizedRequestData = 10, invalidOfferIdentifier = 11, invalidSignature = 12, missingOfferParams = 13, invalidOfferPrice = 14,
             overlayCancelled = 15, overlayInvalidConfiguration = 16, overlayTimeout = 17, ineligibleForOffer = 18, unsupportedPlatform = 19,
             overlayPresentedInBackgroundScene = 20
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { SKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: code == .paymentCancelled ? "Payment cancelled." : "StoreKit error \(code.rawValue) (isim local testing)."] }
    public static let paymentCancelled = Code.paymentCancelled
    public static let storeProductNotAvailable = Code.storeProductNotAvailable
    public static let unknown = Code.unknown
}

/// Stand-in for Foundation's NSDecimalNumber (not in isim's Foundation yet): SKProduct.price.
open class NSDecimalNumber: NSObject, CustomStringConvertible, @unchecked Sendable {
    public let decimalValue: Decimal
    public init(decimal: Decimal) { decimalValue = decimal }
    public convenience init(string: String?) { self.init(decimal: Decimal(string: string ?? "") ?? .zero) }
    public var doubleValue: Double { NSDecimalNumberHelper.double(decimalValue) }
    public var floatValue: Float { Float(doubleValue) }
    public var intValue: Int { Int(doubleValue) }
    public var stringValue: String { "\(decimalValue)" }
    open override var description: String { stringValue }
    public static var zero: NSDecimalNumber { NSDecimalNumber(decimal: .zero) }
    open override func isEqual(_ object: Any?) -> Bool { (object as? NSDecimalNumber)?.decimalValue == decimalValue }
    open override var hash: Int { stringValue.hashValue }
}
enum NSDecimalNumberHelper { static func double(_ d: Decimal) -> Double { Double("\(d)") ?? 0 } }
extension NumberFormatter {
    public func string(from number: NSDecimalNumber) -> String? { string(from: NSNumber(value: number.doubleValue)) }
}

// MARK: - Products

open class SKProductSubscriptionPeriod: NSObject, @unchecked Sendable {
    public let numberOfUnits: Int
    public let unit: SKProduct.PeriodUnit
    init(_ p: Product.SubscriptionPeriod) { numberOfUnits = p.value; unit = SKProduct.PeriodUnit(rawValue: UInt(p.unit.rawValue)) ?? .month }
}

open class SKProductDiscount: NSObject, @unchecked Sendable {
    public enum PaymentMode: UInt, Sendable { case payAsYouGo = 0, payUpFront = 1, freeTrial = 2 }
    public enum `Type`: UInt, Sendable { case introductory = 0, subscription = 1 }
    public let price: NSDecimalNumber
    public let priceLocale: Locale
    public let identifier: String?
    public let subscriptionPeriod: SKProductSubscriptionPeriod
    public let numberOfPeriods: Int
    public let paymentMode: PaymentMode
    public let type: `Type`
    init(_ o: Product.SubscriptionOffer) {
        price = NSDecimalNumber(decimal: o.price); priceLocale = Locale(identifier: "en_US"); identifier = o.id
        subscriptionPeriod = SKProductSubscriptionPeriod(o.period); numberOfPeriods = o.periodCount
        paymentMode = o.paymentMode == .freeTrial ? .freeTrial : o.paymentMode == .payUpFront ? .payUpFront : .payAsYouGo
        type = o.type == .introductory ? .introductory : .subscription
    }
}

open class SKProduct: NSObject, @unchecked Sendable {
    public enum PeriodUnit: UInt, Sendable { case day = 0, week = 1, month = 2, year = 3 }
    public let productIdentifier: String
    public let localizedTitle: String
    public let localizedDescription: String
    public let price: NSDecimalNumber
    public let priceLocale: Locale
    public let isFamilyShareable: Bool
    public let subscriptionPeriod: SKProductSubscriptionPeriod?
    public let introductoryPrice: SKProductDiscount?
    public let discounts: [SKProductDiscount]
    public let subscriptionGroupIdentifier: String?
    public var isDownloadable: Bool { false }
    public var downloadContentLengths: [NSNumber] { [] }
    public var contentVersion: String { "" }
    public var downloadContentVersion: String { "" }
    init(_ i: _SKItem) {
        productIdentifier = i.id; localizedTitle = i.name; localizedDescription = i.description
        price = NSDecimalNumber(decimal: i.price); priceLocale = Locale(identifier: "en_US"); isFamilyShareable = i.familyShareable
        subscriptionPeriod = i.period.map(SKProductSubscriptionPeriod.init)
        introductoryPrice = i.intro.map { SKProductDiscount($0.offer) }
        discounts = i.promos.map { SKProductDiscount($0.offer) }
        subscriptionGroupIdentifier = i.groupID
    }
}

open class SKProductsResponse: NSObject, @unchecked Sendable {
    public let products: [SKProduct]
    public let invalidProductIdentifiers: [String]
    init(products: [SKProduct], invalid: [String]) { self.products = products; invalidProductIdentifiers = invalid }
}

public protocol SKRequestDelegate: AnyObject {
    func requestDidFinish(_ request: SKRequest)
    func request(_ request: SKRequest, didFailWithError error: Error)
}
extension SKRequestDelegate {
    public func requestDidFinish(_ request: SKRequest) {}
    public func request(_ request: SKRequest, didFailWithError error: Error) {}
}
public protocol SKProductsRequestDelegate: SKRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse)
}

open class SKRequest: NSObject {
    weak open var delegate: SKRequestDelegate?
    var cancelled = false
    open func start() {}
    open func cancel() { cancelled = true }
}

open class SKProductsRequest: SKRequest {
    let ids: Set<String>
    public init(productIdentifiers: Set<String>) { ids = productIdentifiers; super.init() }
    open override func start() {
        _SKUpdates.start()
        let items = _SKConfig.load().items.filter { ids.contains($0.id) }
        let response = SKProductsResponse(products: items.map(SKProduct.init), invalid: ids.subtracting(items.map { $0.id }).sorted())
        NSLog("isim StoreKit: SKProductsRequest: %ld products, %ld invalid identifiers", response.products.count, response.invalidProductIdentifiers.count)
        DispatchQueue.main.async {
            guard !self.cancelled else { return }
            (self.delegate as? SKProductsRequestDelegate)?.productsRequest(self, didReceive: response)
            self.delegate?.requestDidFinish(self)
        }
    }
}

/// Writes the local receipt again (there is no App Store to fetch a signed one from).
open class SKReceiptRefreshRequest: SKRequest {
    public let receiptProperties: [String: Any]?
    public init(receiptProperties: [String: Any]? = nil) { self.receiptProperties = receiptProperties; super.init() }
    open override func start() {
        _SKReceipt.write()
        DispatchQueue.main.async { self.delegate?.requestDidFinish(self) }
    }
}

// MARK: - Receipt

enum _SKReceipt {
    static var url: URL { URL(fileURLWithPath: (NSHomeDirectory() as NSString).appendingPathComponent("StoreKit/receipt")) }
    /// local, unsigned: a JSON summary of the ledger (not PKCS #7, not signed by Apple)
    @discardableResult static func write() -> URL {
        let app = AppTransaction.make().unsafePayloadValue
        let inApp: [[String: Any]] = _SKLedger.shared.all().map { t in
            var d: [String: Any] = ["product_id": t.productID, "transaction_id": "\(t.id)", "original_transaction_id": "\(t.originalID)",
                                    "purchase_date_ms": "\(Int(t.purchaseDate * 1000))", "quantity": "\(t.quantity)"]
            if let e = t.expirationDate { d["expires_date_ms"] = "\(Int(e * 1000))" }
            if let r = t.revocationDate { d["cancellation_date_ms"] = "\(Int(r * 1000))" }
            return d
        }
        let receipt: [String: Any] = [
            "isim": "LOCAL UNSIGNED RECEIPT written by isim StoreKit testing. Not a PKCS #7 container; not signed by Apple.",
            "receipt_type": "Xcode", "bundle_id": app.bundleID, "application_version": app.appVersion,
            "original_application_version": app.originalAppVersion, "original_purchase_date_ms": "\(Int(app.originalPurchaseDate.timeIntervalSince1970 * 1000))",
            "in_app": inApp]
        try? FileManager.default.createDirectory(atPath: url.deletingLastPathComponent().path, withIntermediateDirectories: true, attributes: nil)
        if let data = try? JSONSerialization.data(withJSONObject: receipt, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url, options: .atomic)
        }
        return url
    }
}

extension Bundle {
    /// isim: a local, unsigned receipt (see _SKReceipt), rewritten on each access.
    public var appStoreReceiptURL: URL? { self === Bundle.main ? _SKReceipt.write() : nil }
}

// MARK: - Payments

public struct SKPaymentDiscount: Sendable {
    public let identifier: String, keyIdentifier: String, nonce: UUID, signature: String, timestamp: Int
    public init(identifier: String, keyIdentifier: String, nonce: UUID, signature: String, timestamp: NSNumber) { let timestamp = Int(timestamp.int64Value)
        self.identifier = identifier; self.keyIdentifier = keyIdentifier; self.nonce = nonce; self.signature = signature; self.timestamp = timestamp
    }
}

open class SKPayment: NSObject, @unchecked Sendable {
    var _productIdentifier: String, _quantity = 1, _applicationUsername: String?, _requestData: Data?, _askToBuy = false, _discount: SKPaymentDiscount?
    public init(product: SKProduct) { _productIdentifier = product.productIdentifier; super.init() }
    init(id: String) { _productIdentifier = id; super.init() }
    open var productIdentifier: String { _productIdentifier }
    open var quantity: Int { _quantity }
    open var applicationUsername: String? { _applicationUsername }
    open var requestData: Data? { _requestData }
    open var simulatesAskToBuyInSandbox: Bool { _askToBuy }
    open var paymentDiscount: SKPaymentDiscount? { _discount }
}

open class SKMutablePayment: SKPayment, @unchecked Sendable {
    public override init(product: SKProduct) { super.init(product: product) }
    override init(id: String) { super.init(id: id) }
    public convenience init() { self.init(id: "") }
    open override var productIdentifier: String { get { _productIdentifier } set { _productIdentifier = newValue } }
    open override var quantity: Int { get { _quantity } set { _quantity = newValue } }
    open override var applicationUsername: String? { get { _applicationUsername } set { _applicationUsername = newValue } }
    open override var requestData: Data? { get { _requestData } set { _requestData = newValue } }
    open override var simulatesAskToBuyInSandbox: Bool { get { _askToBuy } set { _askToBuy = newValue } }
    open override var paymentDiscount: SKPaymentDiscount? { get { _discount } set { _discount = newValue } }
}

public enum SKPaymentTransactionState: Int, Sendable { case purchasing = 0, purchased = 1, failed = 2, restored = 3, deferred = 4 }

open class SKPaymentTransaction: NSObject, @unchecked Sendable {
    public let payment: SKPayment
    open internal(set) var transactionState: SKPaymentTransactionState
    open internal(set) var transactionIdentifier: String?
    open internal(set) var transactionDate: Date?
    open internal(set) var original: SKPaymentTransaction?
    open internal(set) var error: Error?
    open var downloads: [Any] { [] }
    var ledgerID: UInt64?
    init(payment: SKPayment, state: SKPaymentTransactionState) { self.payment = payment; transactionState = state }
    convenience init(_ t: _SKTxn, state: SKPaymentTransactionState) {
        let p = SKMutablePayment(id: t.productID); p.quantity = t.quantity
        self.init(payment: p, state: state)
        ledgerID = t.id; transactionIdentifier = "\(t.id)"; transactionDate = Date(timeIntervalSince1970: t.purchaseDate)
        if state == .restored || t.originalID != t.id {
            let o = SKPaymentTransaction(payment: p, state: .purchased)
            o.transactionIdentifier = "\(t.originalID)"; o.transactionDate = Date(timeIntervalSince1970: t.originalPurchaseDate)
            original = o
        }
    }
}

public protocol SKPaymentTransactionObserver: AnyObject {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction])
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction])
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error)
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue)
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool
    func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue)
    func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String])
}
extension SKPaymentTransactionObserver {
    public func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {}
    public func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {}
    public func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {}
    public func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool { true }
    public func paymentQueueDidChangeStorefront(_ queue: SKPaymentQueue) {}
    public func paymentQueue(_ queue: SKPaymentQueue, didRevokeEntitlementsForProductIdentifiers productIdentifiers: [String]) {}
}
public protocol SKPaymentQueueDelegate: AnyObject {}

open class SKStorefront: NSObject, @unchecked Sendable {
    public let countryCode: String, identifier: String
    init(_ c: String) { countryCode = c; identifier = c }
}

open class SKPaymentQueue: NSObject, @unchecked Sendable {
    nonisolated(unsafe) static let shared = SKPaymentQueue()
    open class func `default`() -> SKPaymentQueue { shared }
    open class func canMakePayments() -> Bool { true }
    weak open var delegate: SKPaymentQueueDelegate?
    final class Weak { weak var o: SKPaymentTransactionObserver?; init(_ o: SKPaymentTransactionObserver) { self.o = o } }
    private var observers: [Weak] = []
    open private(set) var transactions: [SKPaymentTransaction] = []
    open var transactionObservers: [SKPaymentTransactionObserver] { observers.compactMap { $0.o } }
    open var storefront: SKStorefront? { SKStorefront(_SKConfig.load().storefront) }
    private var listening = false

    open func add(_ observer: SKPaymentTransactionObserver) {
        _SKUpdates.start()
        guard !observers.contains(where: { $0.o === observer }) else { return }
        observers.append(Weak(observer))
        if !listening {
            listening = true
            // unfinished transactions come back when the app registers its observer (as on iOS)
            let pending = _SKLedger.shared.read { $0.transactions.filter { !$0.finished && $0.revocationDate == nil } }
            if !pending.isEmpty {
                let list = pending.map { SKPaymentTransaction($0, state: .purchased) }
                transactions.append(contentsOf: list)
                DispatchQueue.main.async { self.notify(list) }
            }
            let stream = _SKUpdates.transactions.stream()
            Task { @MainActor in
                for await r in stream {
                    let t = r.unsafePayloadValue.r
                    if t.revocationDate != nil {
                        for o in self.transactionObservers { o.paymentQueue(self, didRevokeEntitlementsForProductIdentifiers: [t.productID]) }
                    } else if !self.transactions.contains(where: { $0.ledgerID == t.id }) {
                        let st = SKPaymentTransaction(t, state: .purchased)
                        self.transactions.append(st)
                        self.notify([st])
                    }
                }
            }
        }
    }
    open func remove(_ observer: SKPaymentTransactionObserver) { observers.removeAll { $0.o == nil || $0.o === observer } }

    func notify(_ list: [SKPaymentTransaction]) {
        for o in transactionObservers { o.paymentQueue(self, updatedTransactions: list) }
    }

    open func add(_ payment: SKPayment) {
        _SKUpdates.start()
        let t = SKPaymentTransaction(payment: payment, state: .purchasing)
        transactions.append(t)
        notify([t])
        Task { @MainActor in
            guard let item = _SKConfig.load().item(payment.productIdentifier) else {
                t.transactionState = .failed; t.error = SKError(.storeProductNotAvailable); self.notify([t]); return
            }
            var options: Set<Product.PurchaseOption> = [.quantity(payment.quantity)]
            if let d = payment.paymentDiscount { options.insert(.promotionalOffer(d.identifier, compactJWS: "")) }
            do {
                switch try await Product(item)._purchase(options: options, api: "sk1") {
                case .success(let r):
                    let x = r.unsafePayloadValue
                    t.transactionState = .purchased; t.ledgerID = x.id; t.transactionIdentifier = "\(x.id)"; t.transactionDate = x.purchaseDate
                case .pending: t.transactionState = .deferred
                case .userCancelled: t.transactionState = .failed; t.error = SKError(.paymentCancelled)
                }
            } catch { t.transactionState = .failed; t.error = SKError(.paymentInvalid) }
            NSLog("isim StoreKit: SKPaymentQueue %@ -> state %ld", payment.productIdentifier, t.transactionState.rawValue)
            self.notify([t])
        }
    }

    open func finishTransaction(_ transaction: SKPaymentTransaction) {
        if let id = transaction.ledgerID, transaction.transactionState != .restored { _SKLedger.shared.finish(id) }
        transactions.removeAll { $0 === transaction }
        for o in transactionObservers { o.paymentQueue(self, removedTransactions: [transaction]) }
    }

    /// Non-consumables and subscriptions in the ledger come back as .restored transactions.
    open func restoreCompletedTransactions() { restoreCompletedTransactions(withApplicationUsername: nil) }
    open func restoreCompletedTransactions(withApplicationUsername username: String?) {
        _SKUpdates.start()
        let list = _SKLedger.shared.all().filter { $0.type != Product.ProductType.consumable.rawValue && $0.revocationDate == nil }
            .map { SKPaymentTransaction($0, state: .restored) }
        NSLog("isim StoreKit: restoreCompletedTransactions: %ld transactions", list.count)
        DispatchQueue.main.async {
            self.transactions.append(contentsOf: list)
            if !list.isEmpty { self.notify(list) }
            for o in self.transactionObservers { o.paymentQueueRestoreCompletedTransactionsFinished(self) }
        }
    }
    open func presentCodeRedemptionSheet() { Task { @MainActor in await _SKSheets.redeemCode() } }
    open func showPriceConsentIfNeeded() {}
}

// MARK: - App Store product page and overlay

public let SKStoreProductParameterITunesItemIdentifier = "id"
public let SKStoreProductParameterProductIdentifier = "productIdentifier"
public let SKStoreProductParameterCustomProductPageIdentifier = "ppid"
public let SKStoreProductParameterAffiliateToken = "at"
public let SKStoreProductParameterCampaignToken = "ct"
public let SKStoreProductParameterProviderToken = "pt"
public let SKStoreProductParameterAdvertisingPartnerToken = "advp"

public protocol SKStoreProductViewControllerDelegate: AnyObject {
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController)
}
extension SKStoreProductViewControllerDelegate {
    public func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {}
}

/// The App Store product page: a placeholder sheet (the App Store isn't available on isim).
open class SKStoreProductViewController: UIViewController {
    weak open var delegate: SKStoreProductViewControllerDelegate?
    var appID = ""
    open func loadProduct(withParameters parameters: [String: Any], completionBlock: ((Bool, Error?) -> Void)? = nil) {
        appID = "\(parameters[SKStoreProductParameterITunesItemIdentifier] ?? parameters[SKStoreProductParameterProductIdentifier] ?? "")"
        NSLog("isim StoreKit: SKStoreProductViewController: product page for app %@ (placeholder)", appID)
        DispatchQueue.main.async { completionBlock?(true, nil) }
    }
    open func loadProduct(withParameters parameters: [String: Any]) async throws { loadProduct(withParameters: parameters, completionBlock: nil) }
    open override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        let host = UIHostingController(rootView: _SKSheets.productPage(appID) { [weak self] in
            guard let self else { return }
            if let d = self.delegate { d.productViewControllerDidFinish(self) } else { self.dismiss(animated: true, completion: nil) }
        })
        addChild(host)
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
        host.didMove(toParent: self)
    }
}

public protocol SKOverlayDelegate: AnyObject {
    func storeOverlay(_ overlay: SKOverlay, didFailToLoadWithError error: Error)
    func storeOverlay(_ overlay: SKOverlay, willStartPresentation transitionContext: SKOverlay.TransitionContext)
    func storeOverlay(_ overlay: SKOverlay, didFinishPresentation transitionContext: SKOverlay.TransitionContext)
    func storeOverlay(_ overlay: SKOverlay, willStartDismissal transitionContext: SKOverlay.TransitionContext)
    func storeOverlay(_ overlay: SKOverlay, didFinishDismissal transitionContext: SKOverlay.TransitionContext)
}
extension SKOverlayDelegate {
    public func storeOverlay(_ overlay: SKOverlay, didFailToLoadWithError error: Error) {}
    public func storeOverlay(_ overlay: SKOverlay, willStartPresentation transitionContext: SKOverlay.TransitionContext) {}
    public func storeOverlay(_ overlay: SKOverlay, didFinishPresentation transitionContext: SKOverlay.TransitionContext) {}
    public func storeOverlay(_ overlay: SKOverlay, willStartDismissal transitionContext: SKOverlay.TransitionContext) {}
    public func storeOverlay(_ overlay: SKOverlay, didFinishDismissal transitionContext: SKOverlay.TransitionContext) {}
}

/// The App Store overlay: a card at the bottom of the screen (placeholder app; "GET" does nothing).
open class SKOverlay: NSObject {
    public enum Position: Int, Sendable { case bottom = 0, bottomRaised = 1 }
    open class Configuration: NSObject {}
    open class AppConfiguration: Configuration {
        open var appIdentifier: String
        open var position: Position
        open var campaignToken: String?
        open var providerToken: String?
        open var customProductPageIdentifier: String?
        open var latestReleaseID: String?
        open var userDismissible = true
        public init(appIdentifier: String, position: Position) { self.appIdentifier = appIdentifier; self.position = position }
    }
    open class AppClipConfiguration: Configuration {
        open var position: Position
        public init(position: Position) { self.position = position }
    }
    open class TransitionContext: NSObject {
        public func addAnimationBlock(_ block: @escaping () -> Void) { block() }
        public var startFrame: CGRect = .zero, endFrame: CGRect = .zero
    }
    public let configuration: Configuration
    weak open var delegate: SKOverlayDelegate?
    public init(configuration: Configuration) { self.configuration = configuration }
    @MainActor static var window: UIWindow?
    @MainActor static var current: SKOverlay?

    @MainActor open func present(in scene: UIWindowScene) {
        SKOverlay.window?.isHidden = true
        let appID = (configuration as? AppConfiguration)?.appIdentifier ?? Bundle.main.bundleIdentifier ?? ""
        let raised = ((configuration as? AppConfiguration)?.position ?? (configuration as? AppClipConfiguration)?.position) == .bottomRaised
        let screen = UIScreen.main.bounds
        let h: CGFloat = 80, bottomInset: CGFloat = raised ? 96 : 40
        // a full-screen window that lets touches through except on the card
        let w = UIWindow(frame: screen)
        w.windowLevel = UIWindow.Level(rawValue: 1500)
        w.backgroundColor = .clear
        let root = _ISIMPassThroughController()
        let host = UIHostingController(rootView: _SKOverlayCard(appID: appID, close: {
            MainActor.assumeIsolated { SKOverlay.dismiss(in: scene, overlay: SKOverlay.current) }
        }))
        host.view.backgroundColor = .clear
        root.addChild(host)
        host.view.frame = CGRect(x: 8, y: screen.height - h - bottomInset, width: screen.width - 16, height: h)
        root.view.addSubview(host.view)
        host.didMove(toParent: root)
        w.rootViewController = root
        SKOverlay.window = w; SKOverlay.current = self
        let ctx = TransitionContext()
        delegate?.storeOverlay(self, willStartPresentation: ctx)
        w.isHidden = false
        delegate?.storeOverlay(self, didFinishPresentation: ctx)
        NSLog("isim StoreKit: SKOverlay presented for app %@ (placeholder)", appID)
    }
    @MainActor open class func dismiss(in scene: UIWindowScene) { dismiss(in: scene, overlay: current) }
    @MainActor static func dismiss(in scene: UIWindowScene, overlay: SKOverlay?) {
        guard let w = window else { return }
        let ctx = TransitionContext()
        if let o = overlay { o.delegate?.storeOverlay(o, willStartDismissal: ctx) }
        w.isHidden = true; window = nil; current = nil
        if let o = overlay { o.delegate?.storeOverlay(o, didFinishDismissal: ctx) }
        NSLog("isim StoreKit: SKOverlay dismissed")
    }
}

struct _SKOverlayCard: View {
    let appID: String, close: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            _SKAppIcon(size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "App \(appID)").font(.system(size: 15, weight: .semibold)).lineLimit(1).accessibilityIdentifier("sk-overlay-title")
                Text(verbatim: "App Store (not available on isim)").font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(verbatim: "GET").font(.system(size: 15, weight: .bold)).foregroundStyle(Color.accentColor)
                .padding(.horizontal, 18).padding(.vertical, 6).background(Color(uiColor: .systemGray5), in: Capsule())
            Button { close() } label: { Image(systemName: "xmark").font(.system(size: 13, weight: .bold)).foregroundStyle(.secondary) }
                .accessibilityIdentifier("sk-overlay-close")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// Root of a floating window: touches outside its subviews go to the windows below.
final class _ISIMPassThroughView: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let v = super.hitTest(point, with: event)
        return v === self ? nil : v
    }
}
final class _ISIMPassThroughController: UIViewController {
    override func loadView() { view = _ISIMPassThroughView(frame: UIScreen.main.bounds); view.backgroundColor = .clear }
}
