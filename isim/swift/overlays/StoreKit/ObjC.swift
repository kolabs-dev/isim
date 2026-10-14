// isim StoreKit for Objective-C (sdk-src/Frameworks/StoreKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors. StoreKit's delegate and observer protocols are Swift protocols in the overlay (apps built
// against them keep their witness tables), so an Objective-C delegate is wrapped in an adapter that conforms to the
// Swift protocol and forwards each call to the selectors the Objective-C object implements.
import UIKit
import ObjectiveC

nonisolated(unsafe) private var _skObjCDelegateKey: UInt8 = 0

/// forwards a Swift delegate call to an Objective-C object's selector, when it implements it
final class _SKObjCForwarder {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func send(_ sel: String, _ a: Any?, _ b: Any? = nil) {
        guard let t = target, t.responds(to: Selector(sel)) else { return }
        if b == nil && !sel.hasSuffix(":") { _ = t.perform(Selector(sel)) }
        else if sel.filter({ $0 == ":" }).count == 1 { _ = t.perform(Selector(sel), with: a) }
        else { _ = t.perform(Selector(sel), with: a, with: b) }
    }
}

final class _SKObjCProductDelegate: SKStoreProductViewControllerDelegate {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) { f.send("productViewControllerDidFinish:", viewController) }
}

extension SKStoreProductViewController {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _SKObjCProductDelegate)?.f.target }
        set {
            let a = newValue.map(_SKObjCProductDelegate.init)
            objc_setAssociatedObject(self, &_skObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)   // the delegate is weak
            delegate = a
        }
    }
}

final class _SKObjCOverlayDelegate: SKOverlayDelegate {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func storeOverlay(_ overlay: SKOverlay, didFailToLoadWithError error: Error) { f.send("storeOverlay:didFailToLoadWithError:", overlay, error as NSError) }
    func storeOverlay(_ overlay: SKOverlay, willStartPresentation c: SKOverlay.TransitionContext) { f.send("storeOverlay:willStartPresentation:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, didFinishPresentation c: SKOverlay.TransitionContext) { f.send("storeOverlay:didFinishPresentation:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, willStartDismissal c: SKOverlay.TransitionContext) { f.send("storeOverlay:willStartDismissal:", overlay, c) }
    func storeOverlay(_ overlay: SKOverlay, didFinishDismissal c: SKOverlay.TransitionContext) { f.send("storeOverlay:didFinishDismissal:", overlay, c) }
}

extension SKOverlay {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _SKObjCOverlayDelegate)?.f.target }
        set {
            let a = newValue.map(_SKObjCOverlayDelegate.init)
            objc_setAssociatedObject(self, &_skObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            delegate = a
        }
    }
    @objc(configuration) var _objc_configuration: Configuration { configuration }
}

extension SKOverlay.TransitionContext {
    @objc(addAnimationBlock:) func _objc_addAnimationBlock(_ block: @escaping () -> Void) { addAnimationBlock(block) }
    @objc(startFrame) var _objc_startFrame: CGRect { startFrame }
    @objc(endFrame) var _objc_endFrame: CGRect { endFrame }
}

final class _SKObjCTransactionObserver: SKPaymentTransactionObserver {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        f.send("paymentQueue:updatedTransactions:", queue, transactions as NSArray)
    }
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        f.send("paymentQueue:removedTransactions:", queue, transactions as NSArray)
    }
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        f.send("paymentQueue:restoreCompletedTransactionsFailedWithError:", queue, error as NSError)
    }
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) { f.send("paymentQueueRestoreCompletedTransactionsFinished:", queue) }
}

extension SKPaymentQueue {
    nonisolated(unsafe) private static var _objcObservers: [ObjectIdentifier: _SKObjCTransactionObserver] = [:]
    @objc(addTransactionObserver:) func _objc_add(_ o: NSObject) {
        let a = _SKObjCTransactionObserver(o)
        SKPaymentQueue._objcObservers[ObjectIdentifier(o)] = a
        add(a)
    }
    @objc(removeTransactionObserver:) func _objc_remove(_ o: NSObject) {
        if let a = SKPaymentQueue._objcObservers.removeValue(forKey: ObjectIdentifier(o)) { remove(a) }
    }
    @objc(transactions) var _objc_transactions: NSArray { transactions as NSArray }
}

// MARK: - StoreKit 1: products, payments, transactions (Unity IAP, Capacitor / Cordova plugins)

final class _SKObjCRequestDelegate: SKProductsRequestDelegate {
    let f: _SKObjCForwarder
    init(_ t: NSObject) { f = _SKObjCForwarder(t) }
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) { f.send("productsRequest:didReceiveResponse:", request, response) }
    func requestDidFinish(_ request: SKRequest) { f.send("requestDidFinish:", request) }
    func request(_ request: SKRequest, didFailWithError error: Error) { f.send("request:didFailWithError:", request, error as NSError) }
}

extension SKRequest {
    @objc(delegate) var _objc_delegate: NSObject? {
        get { (delegate as? _SKObjCRequestDelegate)?.f.target }
        set {
            let a = newValue.map(_SKObjCRequestDelegate.init)
            objc_setAssociatedObject(self, &_skObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)   // the delegate is weak
            delegate = a
        }
    }
    @objc(start) func _objc_start() { start() }
    @objc(cancel) func _objc_cancel() { cancel() }
}

extension SKProductsRequest {
    @objc(initWithProductIdentifiers:) convenience init(_objcProductIdentifiers ids: NSSet) {
        self.init(productIdentifiers: Set(ids.allObjects.compactMap { $0 as? String }))
    }
}

extension SKReceiptRefreshRequest {
    @objc(initWithReceiptProperties:) convenience init(_objcReceiptProperties p: NSDictionary?) { self.init(receiptProperties: p as? [String: Any]) }
    @objc(receiptProperties) var _objc_receiptProperties: NSDictionary? { receiptProperties as NSDictionary? }
}

extension SKProductsResponse {
    @objc(products) var _objc_products: NSArray { products as NSArray }
    @objc(invalidProductIdentifiers) var _objc_invalid: NSArray { invalidProductIdentifiers as NSArray }
}

extension SKProduct {
    @objc(productIdentifier) var _objc_productIdentifier: String { productIdentifier }
    @objc(localizedTitle) var _objc_localizedTitle: String { localizedTitle }
    @objc(localizedDescription) var _objc_localizedDescription: String { localizedDescription }
    @objc(price) var _objc_price: NSDecimalNumber { price }
    @objc(priceLocale) var _objc_priceLocale: NSLocale { priceLocale as NSLocale }
    @objc(isFamilyShareable) var _objc_familyShareable: Bool { isFamilyShareable }
    @objc(isDownloadable) var _objc_downloadable: Bool { isDownloadable }
    @objc(downloadContentLengths) var _objc_downloadContentLengths: NSArray { downloadContentLengths as NSArray }
    @objc(contentVersion) var _objc_contentVersion: String { contentVersion }
    @objc(downloadContentVersion) var _objc_downloadContentVersion: String { downloadContentVersion }
    @objc(subscriptionPeriod) var _objc_subscriptionPeriod: SKProductSubscriptionPeriod? { subscriptionPeriod }
    @objc(introductoryPrice) var _objc_introductoryPrice: SKProductDiscount? { introductoryPrice }
    @objc(discounts) var _objc_discounts: NSArray { discounts as NSArray }
    @objc(subscriptionGroupIdentifier) var _objc_subscriptionGroupIdentifier: String? { subscriptionGroupIdentifier }
}

extension SKProductSubscriptionPeriod {
    @objc(numberOfUnits) var _objc_numberOfUnits: Int { numberOfUnits }
    @objc(unit) var _objc_unit: UInt { unit.rawValue }
}

extension SKProductDiscount {
    @objc(price) var _objc_price: NSDecimalNumber { price }
    @objc(priceLocale) var _objc_priceLocale: NSLocale { priceLocale as NSLocale }
    @objc(identifier) var _objc_identifier: String? { identifier }
    @objc(subscriptionPeriod) var _objc_subscriptionPeriod: SKProductSubscriptionPeriod { subscriptionPeriod }
    @objc(numberOfPeriods) var _objc_numberOfPeriods: Int { numberOfPeriods }
    @objc(paymentMode) var _objc_paymentMode: UInt { paymentMode.rawValue }
    @objc(type) var _objc_type: UInt { type.rawValue }
}

extension SKPayment {
    /// +paymentWithProduct: on SKPayment or SKMutablePayment (a mutable payment from the subclass, as on iOS)
    @objc(paymentWithProduct:) class func _objc_payment(product: SKProduct) -> SKPayment {
        self == SKMutablePayment.self ? SKMutablePayment(product: product) : SKPayment(product: product)
    }
    @objc(productIdentifier) var _objc_productIdentifier: String { productIdentifier }
    @objc(quantity) var _objc_quantity: Int { quantity }
    @objc(applicationUsername) var _objc_applicationUsername: String? { applicationUsername }
    @objc(requestData) var _objc_requestData: Data? { requestData }
    @objc(simulatesAskToBuyInSandbox) var _objc_askToBuy: Bool { simulatesAskToBuyInSandbox }
}

extension SKMutablePayment {
    @objc(setProductIdentifier:) func _objc_setProductIdentifier(_ v: String) { productIdentifier = v }
    @objc(setQuantity:) func _objc_setQuantity(_ v: Int) { quantity = v }
    @objc(setApplicationUsername:) func _objc_setApplicationUsername(_ v: String?) { applicationUsername = v }
    @objc(setRequestData:) func _objc_setRequestData(_ v: Data?) { requestData = v }
    @objc(setSimulatesAskToBuyInSandbox:) func _objc_setAskToBuy(_ v: Bool) { simulatesAskToBuyInSandbox = v }
}

extension SKPaymentTransaction {
    @objc(payment) var _objc_payment: SKPayment { payment }
    @objc(transactionState) var _objc_transactionState: Int { transactionState.rawValue }
    @objc(transactionIdentifier) var _objc_transactionIdentifier: String? { transactionIdentifier }
    @objc(transactionDate) var _objc_transactionDate: Date? { transactionDate }
    @objc(originalTransaction) var _objc_originalTransaction: SKPaymentTransaction? { original }
    @objc(error) var _objc_error: NSError? { error.map { $0 as NSError } }
    @objc(downloads) var _objc_downloads: NSArray { downloads as NSArray }
}

extension SKPaymentQueue {
    @objc(addPayment:) func _objc_addPayment(_ p: SKPayment) { add(p) }
    @objc(finishTransaction:) func _objc_finish(_ t: SKPaymentTransaction) { finishTransaction(t) }
    @objc(restoreCompletedTransactions) func _objc_restore() { restoreCompletedTransactions() }
    @objc(restoreCompletedTransactionsWithApplicationUsername:) func _objc_restore(username: String?) {
        restoreCompletedTransactions(withApplicationUsername: username)
    }
    @objc(presentCodeRedemptionSheet) func _objc_presentCodeRedemptionSheet() { presentCodeRedemptionSheet() }
}

extension SKStoreReviewController {
    @MainActor @objc(requestReview) class func _objc_requestReview() { requestReview() }
    @MainActor @objc(requestReviewInScene:) class func _objc_requestReview(in scene: UIWindowScene) { requestReview(in: scene) }
}

extension Bundle {
    /// the app receipt for Objective-C too (StoreKit's, signed by the device; Foundation alone has none)
    @objc(appStoreReceiptURL) var _objc_appStoreReceiptURL: URL? { appStoreReceiptURL }
}
