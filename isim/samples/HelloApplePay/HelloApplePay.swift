// Sample: Apple Pay (PassKit) on isim's simulated payment sheet — a coffee order paid with PKPaymentButton and
// PKPaymentAuthorizationViewController (shipping address and methods, a coupon code, contact details, errors the
// delegate reports), a donation with PKPaymentAuthorizationController (no view controller), and SwiftUI's
// PayWithApplePayButton with a request and the onApplePay…Change modifiers. The token isim hands over is its own
// test token (paymentData is JSON with "version": "isim-test"); nothing is charged. The coffee order's result
// carries Wallet order details. Every step is printed, so tests/ui/test_apple_pay.py can check it.
import SwiftUI
import PassKit

let merchantID = "merchant.dev.isim.samples.coffee"
let networks: [PKPaymentNetwork] = [.visa, .masterCard, .amex]

func money(_ s: String) -> NSDecimalNumber { NSDecimalNumber(string: s) }

func describe(_ payment: PKPayment) -> String {
    let t = payment.token
    let json = (try? JSONSerialization.jsonObject(with: t.paymentData)) as? [String: Any] ?? [:]
    let ship = payment.shippingContact.map { c in
        [c.name.map { "\($0.givenName ?? "") \($0.familyName ?? "")" }, c.postalAddress.map { "\($0.street), \($0.city)" }, c.emailAddress]
            .compactMap { $0 }.joined(separator: " / ")
    } ?? "-"
    return "method=\(t.paymentMethod.displayName ?? "?") network=\(t.paymentMethod.network?.rawValue ?? "?") type=\(t.paymentMethod.type.rawValue) " +
        "token=\(json["version"] as? String ?? "?") amount=\(json["amount"] as? String ?? "?") id=\(t.transactionIdentifier.count) " +
        "shipping=\(payment.shippingMethod?.identifier ?? "-") contact=\(ship)"
}

// MARK: - The coffee order (PKPaymentAuthorizationViewController)

@MainActor final class CoffeeOrder: NSObject, ObservableObject, PKPaymentAuthorizationViewControllerDelegate {
    @Published var status = "ready"
    var shipping = money("0")
    var discount = money("0")
    var paid = false

    let methods: [PKShippingMethod] = {
        let standard = PKShippingMethod(label: "Standard", amount: money("0"))
        standard.identifier = "standard"; standard.detail = "Arrives in 5–7 days"
        let express = PKShippingMethod(label: "Express", amount: money("5.00"))
        express.identifier = "express"; express.detail = "Arrives tomorrow"
        return [standard, express]
    }()

    var items: [PKPaymentSummaryItem] {
        var list = [PKPaymentSummaryItem(label: "Coffee beans", amount: money("12.00")),
                    PKPaymentSummaryItem(label: "Shipping", amount: shipping)]
        if discount != money("0") { list.append(PKPaymentSummaryItem(label: "Coupon ISIM10", amount: discount.multiplying(by: money("-1")))) }
        let total = money("12.00").adding(shipping).subtracting(discount)
        list.append(PKPaymentSummaryItem(label: "isim Coffee", amount: total))
        return list
    }

    var request: PKPaymentRequest {
        let r = PKPaymentRequest()
        r.merchantIdentifier = merchantID
        r.countryCode = "US"; r.currencyCode = "USD"
        r.supportedNetworks = networks
        r.merchantCapabilities = [.threeDSecure, .credit, .debit]
        r.requiredShippingContactFields = [.postalAddress, .name, .emailAddress]
        r.shippingMethods = methods
        r.shippingType = .delivery
        r.supportsCouponCode = true
        r.applicationData = Data("order-42".utf8)
        r.paymentSummaryItems = items
        return r
    }

    func buy() {
        shipping = money("0"); discount = money("0"); paid = false
        guard let vc = PKPaymentAuthorizationViewController(paymentRequest: request) else { print("coffee: cannot pay"); return }
        vc.delegate = self
        top()?.present(vc, animated: true)
        print("coffee: presented")
    }

    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect paymentMethod: PKPaymentMethod,
                                            handler completion: @escaping (PKPaymentRequestPaymentMethodUpdate) -> Void) {
        print("coffee: card \(paymentMethod.displayName ?? "?") \(paymentMethod.network?.rawValue ?? "?")")
        completion(PKPaymentRequestPaymentMethodUpdate(errors: nil, paymentSummaryItems: items))
    }
    // the async form: isim's delegates take either
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelectShippingContact contact: PKContact) async -> PKPaymentRequestShippingContactUpdate {
        let a = contact.postalAddress
        print("coffee: ship to \(a?.city ?? "?") \(a?.postalCode ?? "?") street=\(a?.street.isEmpty == false ? "shown" : "redacted") name=\(contact.name == nil ? "nil" : "set")")
        if a?.state == "NY" {
            let e = PKPaymentRequest.paymentShippingAddressUnserviceableError(withLocalizedDescription: "We don't deliver to New York yet")
            return PKPaymentRequestShippingContactUpdate(errors: [e], paymentSummaryItems: items, shippingMethods: methods)
        }
        return PKPaymentRequestShippingContactUpdate(errors: nil, paymentSummaryItems: items, shippingMethods: methods)
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didSelect shippingMethod: PKShippingMethod,
                                            handler completion: @escaping (PKPaymentRequestShippingMethodUpdate) -> Void) {
        shipping = shippingMethod.amount
        print("coffee: shipping \(shippingMethod.identifier ?? "?")")
        completion(PKPaymentRequestShippingMethodUpdate(paymentSummaryItems: items))
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didChangeCouponCode couponCode: String,
                                            handler completion: @escaping (PKPaymentRequestCouponCodeUpdate) -> Void) {
        var errors: [Error] = []
        if couponCode.uppercased() == "ISIM10" { discount = money("1.20") } else {
            discount = money("0")
            if !couponCode.isEmpty { errors.append(PKPaymentRequest.paymentCouponCodeInvalidError(localizedDescription: "\(couponCode) is not a valid code")) }
        }
        print("coffee: coupon \(couponCode) errors=\(errors.count)")
        completion(PKPaymentRequestCouponCodeUpdate(errors: errors, paymentSummaryItems: items, shippingMethods: methods))
    }
    func paymentAuthorizationViewControllerWillAuthorizePayment(_ controller: PKPaymentAuthorizationViewController) {
        print("coffee: will authorize")
    }
    func paymentAuthorizationViewController(_ controller: PKPaymentAuthorizationViewController, didAuthorizePayment payment: PKPayment,
                                            handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        print("coffee: authorized \(describe(payment))")
        paid = true
        // the order Wallet tracks (isim's Wallet records it: `isim wallet orders`)
        let result = PKPaymentAuthorizationResult(status: .success, errors: nil)
        result.orderDetails = PKPaymentOrderDetails(orderTypeIdentifier: "order.dev.isim.samples.coffee", orderIdentifier: "coffee-42",
                                                    webServiceURL: URL(string: "https://orders.example.com/")!, authenticationToken: "order-token")
        completion(result)
    }
    func paymentAuthorizationViewControllerDidFinish(_ controller: PKPaymentAuthorizationViewController) {
        controller.dismiss(animated: true)
        status = paid ? "coffee paid" : "coffee canceled"
        print("coffee: finished paid=\(paid)")
    }
}

// MARK: - The donation (PKPaymentAuthorizationController)

@MainActor final class Donation: NSObject, ObservableObject, PKPaymentAuthorizationControllerDelegate {
    @Published var status = "ready"
    var declineNext = false
    var controller: PKPaymentAuthorizationController?

    func donate() {
        let r = PKPaymentRequest()
        r.merchantIdentifier = merchantID
        r.countryCode = "US"; r.currencyCode = "USD"
        r.supportedNetworks = networks
        r.merchantCapabilities = .threeDSecure
        r.paymentSummaryItems = [PKPaymentSummaryItem(label: "isim Open Source Fund", amount: money("5.00"))]
        let c = PKPaymentAuthorizationController(paymentRequest: r)
        c.delegate = self
        controller = c
        c.present { ok in print("donation: presented \(ok)") }
    }
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment) async -> PKPaymentAuthorizationResult {
        print("donation: authorized \(describe(payment)) decline=\(declineNext)")
        if declineNext { declineNext = false; return PKPaymentAuthorizationResult(status: .failure, errors: nil) }
        status = "donated"
        return PKPaymentAuthorizationResult(status: .success, errors: nil)
    }
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        controller.dismiss { print("donation: dismissed") }
        print("donation: finished")
    }
}

// MARK: - The app

struct PaymentButton: UIViewRepresentable {
    let type: PKPaymentButtonType, style: PKPaymentButtonStyle, action: () -> Void
    func makeUIView(context: Context) -> PKPaymentButton {
        let b = PKPaymentButton(paymentButtonType: type, paymentButtonStyle: style)
        b.cornerRadius = 8
        b.accessibilityIdentifier = "buy-coffee"
        b.addTarget(context.coordinator, action: #selector(Coordinator.tap), for: .touchUpInside)
        return b
    }
    func updateUIView(_ uiView: PKPaymentButton, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(action: action) }
    final class Coordinator: NSObject {
        let action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func tap() { action() }
    }
}

struct ContentView: View {
    @StateObject var coffee = CoffeeOrder()
    @StateObject var donation = Donation()
    @State var tip = "ready"

    var tipRequest: PKPaymentRequest {
        let r = PKPaymentRequest()
        r.merchantIdentifier = merchantID
        r.countryCode = "US"; r.currencyCode = "USD"
        r.supportedNetworks = networks
        r.merchantCapabilities = .threeDSecure
        r.paymentSummaryItems = [PKPaymentSummaryItem(label: "Barista tip", amount: money("2.00"))]
        return r
    }

    var body: some View {
        VStack(spacing: 14) {
            Text("Apple Pay").font(.largeTitle.bold())
            Text("canMakePayments \(PKPaymentAuthorizationController.canMakePayments() ? "yes" : "no")").font(.footnote).accessibilityIdentifier("can-pay")
            PaymentButton(type: .buy, style: .black) { coffee.buy() }.frame(height: 48)
            Text(coffee.status).accessibilityIdentifier("coffee-status")
            Button("Donate $5 (PKPaymentAuthorizationController)") { donation.donate() }.accessibilityIdentifier("donate")
            Button("Decline the next donation") { donation.declineNext = true; print("donation: decline next") }.accessibilityIdentifier("decline-next")
            Text(donation.status).accessibilityIdentifier("donation-status")
            PayWithApplePayButton(.tip, request: tipRequest) { phase in
                switch phase {
                case .willAuthorize: print("tip: will authorize")
                case .didAuthorize(let payment, let resultHandler):
                    print("tip: authorized \(describe(payment))")
                    tip = "tipped"
                    resultHandler(PKPaymentAuthorizationResult(status: .success, errors: nil))
                case .didFinish: print("tip: finished")
                @unknown default: break
                }
            } fallback: {
                Text("Apple Pay is not set up").accessibilityIdentifier("tip-fallback")
            }
            .onApplePayPaymentMethodChange { method in
                print("tip: card \(method.displayName ?? "?")")
                return PKPaymentRequestPaymentMethodUpdate(paymentSummaryItems: [PKPaymentSummaryItem(label: "Barista tip", amount: money(method.type == .debit ? "2.00" : "2.10"))])
            }
            .payWithApplePayButtonStyle(.whiteOutline)
            .frame(height: 48)
            .accessibilityIdentifier("tip")
            Text(tip).accessibilityIdentifier("tip-status")
        }
        .padding()
        .onAppear {
            print("can pay: \(PKPaymentAuthorizationController.canMakePayments()) visa+mc+amex \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks)) " +
                  "jcb \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.JCB])) debit \(PKPaymentAuthorizationController.canMakePayments(usingNetworks: networks, capabilities: .debit))")
            print("networks: \(PKPaymentRequest.availableNetworks().map(\.rawValue).joined(separator: ","))")
            let incomplete = PKPaymentRequest()
            print("incomplete request: \(PKPaymentAuthorizationViewController(paymentRequest: incomplete) == nil ? "refused" : "accepted")")
            let e = PKPaymentRequest.paymentContactInvalidError(withContactField: .emailAddress, localizedDescription: "Enter an email") as NSError
            print("error: \(e.domain) \(e.code) \(e.userInfo[PKPaymentErrorKey.contactFieldUserInfoKey.rawValue] ?? "-") \(e.localizedDescription)")
        }
    }
}

@MainActor func top() -> UIViewController? {
    var t = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow }.first?.rootViewController
    while let p = t?.presentedViewController { t = p }
    return t
}

@main struct HelloApplePayApp: App {
    var body: some Scene { WindowGroup { ContentView() } }
}
