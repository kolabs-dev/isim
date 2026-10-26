// isim PassKit: PKPaymentAuthorizationController and PKPaymentAuthorizationViewController, their delegates, and the
// device's test cards and contacts. Adapted: the sheet is isim's simulated Apple Pay sheet (PaymentSheet.swift);
// the device has test cards (ISIM_APPLE_PAY=0: none, so canMakePayments() is false) and nothing is charged.
// The delegates are Swift protocols: each method has both forms Apple's SDK imports (completion handler and async),
// with defaults, so an app implements either.
import Foundation
import UIKit
import SwiftUI
import Contacts
import CryptoKit

// MARK: - The device's test cards and contacts

struct _PKCard: Identifiable, Equatable {
    let id: String, network: PKPaymentNetwork, type: PKPaymentMethodType, brand: String, suffix: String, color: Color
    var displayName: String { "\(brand) \(suffix)" }
    var title: String { "\(brand) Test \(type == .debit ? "Debit" : "Credit") Card" }
    var method: PKPaymentMethod {
        let m = PKPaymentMethod()
        m.displayName = displayName; m.network = network; m.type = type
        return m
    }
}

struct _PKAddress: Identifiable, Equatable {
    let id: Int, given: String, family: String, street: String, city: String, state: String, postalCode: String
    let country: String, iso: String, email: String, phone: String
    var name: String { "\(given) \(family)" }
    var oneLine: String { "\(street), \(city), \(state) \(postalCode)" }

    /// the contact the app receives: the fields it asked for; before authorization only a partial address
    /// (city, state, postal code, country), as iOS redacts it
    func contact(fields: Set<PKContactField>, redacted: Bool) -> PKContact {
        let c = PKContact()
        if fields.contains(.postalAddress) || redacted {
            let a = CNMutablePostalAddress()
            if !redacted { a.street = street }
            a.city = city; a.state = state; a.postalCode = postalCode; a.country = country; a.isoCountryCode = iso
            c.postalAddress = a
        }
        if redacted { return c }
        if fields.contains(.name) || fields.contains(.postalAddress) {
            var n = PersonNameComponents(); n.givenName = given; n.familyName = family
            c.name = n
        }
        if fields.contains(.emailAddress) { c.emailAddress = email }
        if fields.contains(.phoneNumber) { c.phoneNumber = CNPhoneNumber(stringValue: phone) }
        return c
    }
}

enum _PKWallet {
    static let all = [
        _PKCard(id: "visa", network: .visa, type: .credit, brand: "Visa", suffix: "4242", color: Color(red: 0.10, green: 0.20, blue: 0.55)),
        _PKCard(id: "mastercard", network: .masterCard, type: .debit, brand: "Mastercard", suffix: "4444", color: Color(red: 0.12, green: 0.12, blue: 0.14)),
        _PKCard(id: "amex", network: .amex, type: .credit, brand: "American Express", suffix: "0005", color: Color(red: 0.20, green: 0.55, blue: 0.75)),
        _PKCard(id: "discover", network: .discover, type: .credit, brand: "Discover", suffix: "1117", color: Color(red: 0.90, green: 0.45, blue: 0.10)),
    ]
    static let addresses = [
        _PKAddress(id: 0, given: "Jane", family: "Appleseed", street: "1 Test Street", city: "Cupertino", state: "CA", postalCode: "95014",
                   country: "United States", iso: "US", email: "jane.appleseed@example.com", phone: "(555) 010-0100"),
        _PKAddress(id: 1, given: "Jane", family: "Appleseed", street: "200 Sample Avenue", city: "New York", state: "NY", postalCode: "10001",
                   country: "United States", iso: "US", email: "jane.appleseed@example.com", phone: "(555) 010-0100"),
    ]
    /// the device's cards: none when ISIM_APPLE_PAY=0 (no cards in Wallet)
    static var cards: [_PKCard] { ProcessInfo.processInfo.environment["ISIM_APPLE_PAY"] == "0" ? [] : all }

    static func cards(networks: [PKPaymentNetwork], capabilities: PKMerchantCapability?) -> [_PKCard] {
        cards.filter { c in
            guard networks.contains(c.network) else { return false }
            guard let caps = capabilities, caps.contains(.credit) || caps.contains(.debit) else { return true }
            return c.type == .credit ? caps.contains(.credit) : caps.contains(.debit)
        }
    }

    static func transactionIdentifier() -> String {
        (0..<32).map { _ in String(format: "%02X", UInt8.random(in: 0...255)) }.joined()
    }

    /// isim's test token: JSON that says what it is; no cryptogram or card number, so a payment processor rejects it
    static func token(for request: PKPaymentRequest, card: _PKCard, total: NSDecimalNumber) -> PKPaymentToken {
        let id = transactionIdentifier()
        var header: [String: Any] = ["transactionId": id]
        if let d = request.applicationData {
            header["applicationData"] = SHA256.hash(data: d).map { String(format: "%02x", $0) }.joined()
        }
        let json: [String: Any] = [
            "version": "isim-test",
            "note": "isim simulated Apple Pay: a test token, not an Apple Pay payment token; it has no cryptogram and nothing can be charged with it",
            "header": header, "merchantIdentifier": request.merchantIdentifier,
            "network": card.network.rawValue, "type": card.type == .debit ? "debit" : "credit",
            "amount": total.stringValue, "currencyCode": request.currencyCode, "countryCode": request.countryCode,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
        return PKPaymentToken(paymentMethod: card.method, transactionIdentifier: id, paymentData: data)
    }
}

/// What the sheet calls back: one driver for each controller kind (its delegate), and SwiftUI's button.
@MainActor struct _PKHandlers {
    var willAuthorize: () -> Void = {}
    var authorize: (PKPayment) async -> PKPaymentAuthorizationResult = { _ in PKPaymentAuthorizationResult(status: .failure, errors: nil) }
    var paymentMethod: (PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate? = { _ in nil }
    var shippingContact: (PKContact) async -> PKPaymentRequestShippingContactUpdate? = { _ in nil }
    var shippingMethod: (PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate? = { _ in nil }
    var couponCode: (String) async -> PKPaymentRequestCouponCodeUpdate? = { _ in nil }
    var finish: () -> Void = {}
}

extension PKPaymentRequestUpdate {
    /// marks the updates the delegates' default methods return: the sheet keeps what it shows
    @objc func _markUnchanged() -> Self { _unchanged = true; return self }
}

// MARK: - PKPaymentAuthorizationController

public protocol PKPaymentAuthorizationControllerDelegate: NSObjectProtocol {
    @MainActor func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment,
                                                   handler completion: @escaping (PKPaymentAuthorizationResult) -> Void)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment) async -> PKPaymentAuthorizationResult
    @MainActor func paymentAuthorizationControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationController)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingMethod shippingMethod: PKShippingMethod,
                                                   handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingMethod shippingMethod: PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingContact contact: PKContact,
                                                   handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectPaymentMethod paymentMethod: PKPaymentMethod,
                                                   handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectPaymentMethod paymentMethod: PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didChangeCouponCode couponCode: String,
                                                   handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void)
    @MainActor func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate
    @MainActor func presentationWindow(for controller: PKPaymentAuthorizationController) -> UIWindow?
}

@MainActor public extension PKPaymentAuthorizationControllerDelegate {
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment,
                                        handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        NSLog("isim PassKit: the delegate does not handle didAuthorizePayment; the payment fails")
        completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment) async -> PKPaymentAuthorizationResult {
        await withCheckedContinuation { k in paymentAuthorizationController(controller, didAuthorizePayment: payment, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationController) {}
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingMethod shippingMethod: PKShippingMethod,
                                        handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingMethod shippingMethod: PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate {
        await withCheckedContinuation { k in paymentAuthorizationController(controller, didSelectShippingMethod: shippingMethod, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingContact contact: PKContact,
                                        handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void) {
        completion(PKPaymentRequestShippingContactUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate {
        await withCheckedContinuation { k in paymentAuthorizationController(controller, didSelectShippingContact: contact, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectPaymentMethod paymentMethod: PKPaymentMethod,
                                        handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didSelectPaymentMethod paymentMethod: PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate {
        await withCheckedContinuation { k in paymentAuthorizationController(controller, didSelectPaymentMethod: paymentMethod, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didChangeCouponCode couponCode: String,
                                        handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        completion(PKPaymentRequestCouponCodeUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate {
        await withCheckedContinuation { k in paymentAuthorizationController(controller, didChangeCouponCode: couponCode, handler: { k.resume(returning: $0) }) }
    }
    func presentationWindow(for controller: PKPaymentAuthorizationController) -> UIWindow? { nil }
}

/// Presents the Apple Pay sheet over the app (no view controller of the app's).
@objc(PKPaymentAuthorizationController) open class PKPaymentAuthorizationController: NSObject {
    open weak var delegate: (any PKPaymentAuthorizationControllerDelegate)?
    @objc let request: PKPaymentRequest
    @objc var host: UIViewController?

    @objc public init(paymentRequest request: PKPaymentRequest) { self.request = request; super.init() }

    @objc open class func canMakePayments() -> Bool { !_PKWallet.cards.isEmpty }
    open class func canMakePayments(usingNetworks supportedNetworks: [PKPaymentNetwork]) -> Bool {
        !_PKWallet.cards(networks: supportedNetworks, capabilities: nil).isEmpty
    }
    open class func canMakePayments(usingNetworks supportedNetworks: [PKPaymentNetwork], capabilities: PKMerchantCapability) -> Bool {
        !_PKWallet.cards(networks: supportedNetworks, capabilities: capabilities).isEmpty
    }

    @objc @MainActor open func present(completion: ((Bool) -> Void)? = nil) {
        guard host == nil else { completion?(false); return }
        if let p = request.problem { NSLog("isim PassKit: cannot present the payment sheet: %@", p); completion?(false); return }
        guard !_PKWallet.cards(networks: request.supportedNetworks, capabilities: request.merchantCapabilities).isEmpty else {
            NSLog("isim PassKit: cannot present the payment sheet: no card in Wallet for %@", request.supportedNetworks.map(\.rawValue).joined(separator: ", "))
            completion?(false); return
        }
        let window = delegate?.presentationWindow(for: self)
        var top = window?.rootViewController ?? _PKSheet.topController()
        while let p = top?.presentedViewController { top = p }
        guard let top else { completion?(false); return }
        let model = _PKSheetModel(request: request, handlers: handlers())
        let h = _PKSheet.host(model)
        host = h
        top.present(h, animated: true) { completion?(true) }
        model.start()
    }
    @objc @MainActor open func present() async -> Bool {
        await withCheckedContinuation { k in present(completion: { k.resume(returning: $0) }) }
    }
    @objc @MainActor open func dismiss(completion: (() -> Void)? = nil) {
        guard let h = host else { completion?(); return }
        host = nil
        h.dismiss(animated: true, completion: completion)
    }
    @objc @MainActor open func dismiss() async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in dismiss(completion: { k.resume() }) }
    }

    @MainActor func handlers() -> _PKHandlers {
        var h = _PKHandlers()
        h.willAuthorize = { [weak self] in guard let self else { return }; self.delegate?.paymentAuthorizationControllerWillAuthorizePayment(self) }
        h.authorize = { [weak self] p in
            guard let self, let d = self.delegate else { return PKPaymentAuthorizationResult(status: .failure, errors: nil) }
            return await d.paymentAuthorizationController(self, didAuthorizePayment: p)
        }
        h.paymentMethod = { [weak self] m in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationController(self, didSelectPaymentMethod: m) }
        h.shippingContact = { [weak self] c in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationController(self, didSelectShippingContact: c) }
        h.shippingMethod = { [weak self] m in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationController(self, didSelectShippingMethod: m) }
        h.couponCode = { [weak self] c in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationController(self, didChangeCouponCode: c) }
        h.finish = { [weak self] in guard let self else { return }; self.delegate?.paymentAuthorizationControllerDidFinish(self) }
        return h
    }
}

// MARK: - PKPaymentAuthorizationViewController

public protocol PKPaymentAuthorizationViewControllerDelegate: NSObjectProtocol {
    @MainActor func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,
                                                       handler completion: @escaping (PKPaymentAuthorizationResult) -> Void)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment) async -> PKPaymentAuthorizationResult
    @MainActor func paymentAuthorizationViewControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationViewController)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod,
                                                       handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact,
                                                       handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect paymentMethod: PKPaymentMethod,
                                                       handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect paymentMethod: PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didChangeCouponCode couponCode: String,
                                                       handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void)
    @MainActor func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate
}

@MainActor public extension PKPaymentAuthorizationViewControllerDelegate {
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,
                                            handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        NSLog("isim PassKit: the delegate does not handle didAuthorizePayment; the payment fails")
        completion(PKPaymentAuthorizationResult(status: .failure, errors: nil))
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment) async -> PKPaymentAuthorizationResult {
        await withCheckedContinuation { k in paymentAuthorizationViewController(controller, didAuthorizePayment: payment, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationViewControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationViewController) {}
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod,
                                            handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod) async -> PKPaymentRequestShippingMethodUpdate {
        await withCheckedContinuation { k in paymentAuthorizationViewController(controller, didSelect: shippingMethod, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact,
                                            handler completion: @escaping (PKPaymentRequestShippingContactUpdate) -> Void) {
        completion(PKPaymentRequestShippingContactUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate {
        await withCheckedContinuation { k in paymentAuthorizationViewController(controller, didSelectShippingContact: contact, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect paymentMethod: PKPaymentMethod,
                                            handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        completion(PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect paymentMethod: PKPaymentMethod) async -> PKPaymentRequestPaymentMethodUpdate {
        await withCheckedContinuation { k in paymentAuthorizationViewController(controller, didSelect: paymentMethod, handler: { k.resume(returning: $0) }) }
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didChangeCouponCode couponCode: String,
                                            handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        completion(PKPaymentRequestCouponCodeUpdate(paymentSummaryItems: [])._markUnchanged())
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didChangeCouponCode couponCode: String) async -> PKPaymentRequestCouponCodeUpdate {
        await withCheckedContinuation { k in paymentAuthorizationViewController(controller, didChangeCouponCode: couponCode, handler: { k.resume(returning: $0) }) }
    }
}

/// The Apple Pay sheet as a view controller the app presents (and dismisses in paymentAuthorizationViewControllerDidFinish).
@objc(PKPaymentAuthorizationViewController) open class PKPaymentAuthorizationViewController: UIViewController {
    open weak var delegate: (any PKPaymentAuthorizationViewControllerDelegate)?
    @objc let request: PKPaymentRequest
    var model: _PKSheetModel?

    /// nil when the device cannot pay with the request's networks, or the request is incomplete
    @objc public init?(paymentRequest request: PKPaymentRequest) {
        if let p = request.problem { NSLog("isim PassKit: PKPaymentAuthorizationViewController: %@", p); return nil }
        guard !_PKWallet.cards(networks: request.supportedNetworks, capabilities: request.merchantCapabilities).isEmpty else {
            NSLog("isim PassKit: PKPaymentAuthorizationViewController: no card in Wallet for %@", request.supportedNetworks.map(\.rawValue).joined(separator: ", "))
            return nil
        }
        self.request = request
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .pageSheet
        isModalInPresentation = true
    }
    @objc public required init?(coder: NSCoder) { return nil }

    @objc open class func canMakePayments() -> Bool { PKPaymentAuthorizationController.canMakePayments() }
    open class func canMakePayments(usingNetworks supportedNetworks: [PKPaymentNetwork]) -> Bool {
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks)
    }
    open class func canMakePayments(usingNetworks supportedNetworks: [PKPaymentNetwork], capabilities: PKMerchantCapability) -> Bool {
        PKPaymentAuthorizationController.canMakePayments(usingNetworks: supportedNetworks, capabilities: capabilities)
    }

    @objc open override func viewDidLoad() {
        super.viewDidLoad()
        let m = _PKSheetModel(request: request, handlers: handlers())
        model = m
        let h = UIHostingController(rootView: _PKSheetView(model: m))
        addChild(h)
        h.view.frame = view.bounds
        h.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(h.view)
        h.didMove(toParent: self)
        view.backgroundColor = .systemGroupedBackground
    }
    @objc open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        model?.start()
    }

    func handlers() -> _PKHandlers {
        var h = _PKHandlers()
        h.willAuthorize = { [weak self] in guard let self else { return }; self.delegate?.paymentAuthorizationViewControllerWillAuthorizePayment(self) }
        h.authorize = { [weak self] p in
            guard let self, let d = self.delegate else { return PKPaymentAuthorizationResult(status: .failure, errors: nil) }
            return await d.paymentAuthorizationViewController(self, didAuthorizePayment: p)
        }
        h.paymentMethod = { [weak self] m in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationViewController(self, didSelect: m) }
        h.shippingContact = { [weak self] c in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationViewController(self, didSelectShippingContact: c) }
        h.shippingMethod = { [weak self] m in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationViewController(self, didSelect: m) }
        h.couponCode = { [weak self] c in guard let self, let d = self.delegate else { return nil }; return await d.paymentAuthorizationViewController(self, didChangeCouponCode: c) }
        h.finish = { [weak self] in guard let self else { return }; self.delegate?.paymentAuthorizationViewControllerDidFinish(self) }
        return h
    }
}
