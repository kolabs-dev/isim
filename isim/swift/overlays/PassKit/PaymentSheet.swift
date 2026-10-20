// isim PassKit: the simulated Apple Pay sheet, drawn like iOS's: the card, shipping address and method, contact,
// coupon code and summary, each row opening its choices; "Pay with Passcode" (the Simulator's confirmation, there is
// no side button), then Processing and Done. The delegate's updates refresh the summary and show its errors on
// their rows. Nothing is charged; the token is isim's test token (_PKWallet.token).
import Foundation
import UIKit
import SwiftUI

@MainActor final class _PKSheetModel: ObservableObject {
    enum Phase: Equatable { case review, processing, done, failed }
    enum Picker: Equatable { case card, address, method, contact }

    let request: PKPaymentRequest
    let handlers: _PKHandlers
    let cards: [_PKCard]
    @Published var phase = Phase.review
    @Published var picker: Picker?
    @Published var items: [PKPaymentSummaryItem]
    @Published var methods: [PKShippingMethod]
    @Published var card: _PKCard
    @Published var address = _PKWallet.addresses[0]
    @Published var method: PKShippingMethod?
    @Published var coupon: String
    /// errors of the latest updates, by what they are about
    @Published var contactErrors: [PKPaymentError] = []
    @Published var cardErrors: [PKPaymentError] = []
    @Published var couponErrors: [PKPaymentError] = []
    @Published var failure: String?
    var started = false, finished = false

    init(request: PKPaymentRequest, handlers: _PKHandlers) {
        self.request = request; self.handlers = handlers
        cards = _PKWallet.cards(networks: request.supportedNetworks, capabilities: request.merchantCapabilities)
        card = cards.first ?? _PKWallet.all[0]
        items = request.paymentSummaryItems
        methods = request.shippingMethods ?? []
        method = request.shippingMethods?.first
        coupon = request.couponCode ?? ""
    }

    var needsShipping: Bool { request.requiredShippingContactFields.contains(.postalAddress) }
    var contactFields: Set<PKContactField> { request.requiredShippingContactFields.union(request.requiredBillingContactFields).intersection([.emailAddress, .phoneNumber]) }
    var total: PKPaymentSummaryItem? { items.last }
    var canPay: Bool { phase == .review && contactErrors.isEmpty && cardErrors.isEmpty && total != nil }

    func money(_ n: NSDecimalNumber) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency; f.currencyCode = request.currencyCode
        return f.string(from: n) ?? "\(request.currencyCode) \(n)"
    }

    /// as iOS does when the sheet appears: the delegate hears the default card and shipping address
    func start() {
        guard !started else { return }
        started = true
        NSLog("isim PassKit: payment sheet for %@ (%@ %@, %ld items)", request.merchantIdentifier, total.map { money($0.amount) } ?? "?", total?.label ?? "", items.count)
        Task {
            await selectCard(card)
            if needsShipping { await selectAddress(address) }
        }
    }

    func selectCard(_ c: _PKCard) async {
        card = c
        NSLog("isim PassKit: payment method %@", c.displayName)
        guard let u = await handlers.paymentMethod(c.method), !u._unchanged else { return }
        cardErrors = u._errors.map { PKPaymentError(_nsError: $0 as NSError) }
        apply(u)
    }
    func selectAddress(_ a: _PKAddress) async {
        address = a
        guard needsShipping else { return }
        let contact = a.contact(fields: request.requiredShippingContactFields, redacted: true)
        NSLog("isim PassKit: shipping contact %@", contact.description)
        guard let u = await handlers.shippingContact(contact), !u._unchanged else { return }
        contactErrors = u._errors.map { PKPaymentError(_nsError: $0 as NSError) }
        apply(u)
    }
    func selectMethod(_ m: PKShippingMethod) async {
        method = m
        NSLog("isim PassKit: shipping method %@", m.identifier ?? m.label)
        guard let u = await handlers.shippingMethod(m), !u._unchanged else { return }
        apply(u)
    }
    func changeCoupon(_ code: String) async {
        coupon = code
        NSLog("isim PassKit: coupon code \"%@\"", code)
        guard let u = await handlers.couponCode(code), !u._unchanged else { return }
        couponErrors = u._errors.map { PKPaymentError(_nsError: $0 as NSError) }
        apply(u)
    }
    func apply(_ u: PKPaymentRequestUpdate) {
        if !u.paymentSummaryItems.isEmpty { items = u.paymentSummaryItems }
        if u._setsShippingMethods || !u.shippingMethods.isEmpty {
            methods = u.shippingMethods
            if let m = method, let same = methods.first(where: { $0.identifier != nil && $0.identifier == m.identifier }) { method = same } else { method = methods.first }
        }
        if u.status != .success && u._errors.isEmpty { failure = "Payment Not Completed" }
        NSLog("isim PassKit: summary %@", items.map { "\($0.label) \(money($0.amount))" }.joined(separator: ", "))
    }

    func pay() async {
        guard canPay, let total else { return }
        failure = nil
        phase = .processing
        handlers.willAuthorize()
        let token = _PKWallet.token(for: request, card: card, total: total.amount)
        let p = PKPayment(token: token)
        if needsShipping || !request.requiredShippingContactFields.isEmpty {
            p.shippingContact = address.contact(fields: request.requiredShippingContactFields, redacted: false)
        }
        if !request.requiredBillingContactFields.isEmpty {
            p.billingContact = address.contact(fields: request.requiredBillingContactFields, redacted: false)
        }
        p.shippingMethod = method
        NSLog("isim PassKit: authorized %@ with %@ (isim test token %@)", money(total.amount), card.displayName, token.transactionIdentifier)
        let r = await handlers.authorize(p)
        let errors = (r.errors ?? []).map { PKPaymentError(_nsError: $0 as NSError) }
        NSLog("isim PassKit: authorization result %@%@", r.status == .success ? "success" : "failure",
              errors.isEmpty ? "" : " (" + errors.map(\.localizedDescription).joined(separator: "; ") + ")")
        if r.status == .success {
            if let o = r.orderDetails { _PKWalletStore.addOrder(o, merchant: request.merchantIdentifier, total: money(total.amount)) }
            phase = .done
            try? await Task.sleep(nanoseconds: 900_000_000)
            finish()
        } else {
            contactErrors = errors.filter { $0.code == .shippingContactInvalidError || $0.code == .shippingAddressUnserviceableError }
            cardErrors = errors.filter { $0.code == .billingContactInvalidError }
            couponErrors = errors.filter { $0.code == .couponCodeInvalidError || $0.code == .couponCodeExpiredError }
            failure = errors.isEmpty ? "Payment Not Completed" : nil
            phase = .review
        }
    }
    func cancel() {
        NSLog("isim PassKit: payment sheet canceled")
        finish()
    }
    func finish() {
        guard !finished else { return }
        finished = true
        NSLog("isim PassKit: payment sheet finished")
        handlers.finish()
    }
}

@MainActor enum _PKSheet {
    static func topController() -> UIViewController? {
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
    /// the sheet as a page sheet that a swipe does not dismiss (Cancel does)
    static func host(_ model: _PKSheetModel) -> UIViewController {
        let h = UIHostingController(rootView: _PKSheetView(model: model))
        h.modalPresentationStyle = .pageSheet
        h.isModalInPresentation = true
        h.view.backgroundColor = .systemGroupedBackground
        return h
    }
}

// MARK: - The sheet

struct _PKSheetView: View {
    @ObservedObject var model: _PKSheetModel
    @State var couponText = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            if let p = model.picker { picker(p) } else if model.phase == .done || model.phase == .processing { status } else { review }
        }
        .background(Color(UIColor.systemGroupedBackground))
    }

    var header: some View {
        HStack {
            if model.picker != nil {
                Button(action: { model.picker = nil }) { Text("‹ Back").font(.system(size: 17)) }
                    .accessibilityIdentifier("pk-back")
            } else {
                Text("Apple Pay").font(.system(size: 22, weight: .semibold)).accessibilityIdentifier("pk-title")
            }
            Spacer()
            if model.phase == .review {
                Button(action: { model.cancel() }) {
                    Text("✕").font(.system(size: 15, weight: .bold)).foregroundColor(.secondary)
                        .frame(width: 30, height: 30).background(Circle().fill(Color(UIColor.tertiarySystemFill)))
                }
                .accessibilityIdentifier("pk-cancel").accessibilityLabel("Cancel")
            }
        }
        .padding(.horizontal, 20).padding(.top, 18).padding(.bottom, 12)
    }

    // the card, the delivery rows, the coupon field, the summary and the pay button
    var review: some View {
        ScrollView {
            VStack(spacing: 14) {
                group {
                    row(id: "pk-card", label: nil, errors: model.cardErrors, action: { model.picker = .card }) {
                        HStack(spacing: 12) {
                            cardArt(model.card)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(model.card.title).font(.system(size: 16))
                                Text("•••• \(model.card.suffix)").font(.system(size: 14)).foregroundColor(.secondary)
                            }
                        }
                    }
                }
                if model.needsShipping || !model.methods.isEmpty || !model.contactFields.isEmpty {
                    group {
                        if model.needsShipping {
                            row(id: "pk-shipping", label: shippingLabel, errors: model.contactErrors, action: { model.picker = .address }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.address.name).font(.system(size: 16))
                                    Text(model.address.oneLine).font(.system(size: 14)).foregroundColor(.secondary)
                                }
                            }
                        }
                        if !model.methods.isEmpty {
                            if model.needsShipping { divider }
                            row(id: "pk-method", label: "METHOD", errors: [], action: { model.picker = .method }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model.method.map { "\($0.label) \(model.money($0.amount))" } ?? "Choose").font(.system(size: 16))
                                    if let d = model.method?.detail { Text(d).font(.system(size: 14)).foregroundColor(.secondary) }
                                }
                            }
                        }
                        if !model.contactFields.isEmpty {
                            if model.needsShipping || !model.methods.isEmpty { divider }
                            row(id: "pk-contact", label: "CONTACT", errors: [], action: { model.picker = .contact }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    if model.contactFields.contains(.emailAddress) { Text(model.address.email).font(.system(size: 16)).lineLimit(1) }
                                    if model.contactFields.contains(.phoneNumber) { Text(model.address.phone).font(.system(size: 14)).foregroundColor(.secondary).lineLimit(1) }
                                }
                            }
                        }
                    }
                }
                if model.request.supportsCouponCode {
                    group {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("COUPON").font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).frame(width: 78, alignment: .leading)
                                TextField("Add Code", text: $couponText)
                                    .onSubmit { Task { await model.changeCoupon(couponText) } }
                                    .accessibilityIdentifier("pk-coupon")
                                Button(action: { Task { await model.changeCoupon(couponText) } }) { Text("Apply").font(.system(size: 15)) }
                                    .accessibilityIdentifier("pk-coupon-apply")
                            }
                            ForEach(Array(model.couponErrors.enumerated()), id: \.offset) { _, e in
                                Text(e.localizedDescription).font(.system(size: 13)).foregroundColor(.red)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                    }
                }
                group { summary }
                if let f = model.failure {
                    Text(f).font(.system(size: 15, weight: .semibold)).foregroundColor(.red).accessibilityIdentifier("pk-failure")
                }
                Button(action: { Task { await model.pay() } }) {
                    Text(model.failure == nil ? "Pay with Passcode" : "Try Again")
                        .font(.system(size: 17, weight: .semibold)).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(RoundedRectangle(cornerRadius: 12).fill(model.canPay ? Color.blue : Color.gray))
                }
                .disabled(!model.canPay)
                .accessibilityIdentifier("pk-pay")
                Text("Simulated by isim: nothing is charged.").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
        .onAppear { couponText = model.coupon }
    }

    var shippingLabel: String {
        switch model.request.shippingType {
        case .shipping: return "SHIP TO"
        case .delivery: return "DELIVER TO"
        case .storePickup: return "PICKUP"
        case .servicePickup: return "SERVICE"
        }
    }

    var summary: some View {
        VStack(spacing: 8) {
            ForEach(Array(model.items.enumerated()), id: \.offset) { i, item in
                let isTotal = i == model.items.count - 1
                HStack {
                    Text(isTotal ? "PAY \(item.label.uppercased())" : item.label)
                        .font(.system(size: isTotal ? 15 : 14, weight: isTotal ? .semibold : .regular))
                        .foregroundColor(isTotal ? .primary : .secondary)
                    Spacer()
                    Text(item.type == .pending ? "Amount Pending" : model.money(item.amount))
                        .font(.system(size: isTotal ? 22 : 14, weight: isTotal ? .semibold : .regular))
                        .accessibilityIdentifier(isTotal ? "pk-total" : "pk-item-\(i)")
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    var status: some View {
        VStack(spacing: 14) {
            Spacer()
            if model.phase == .done {
                ZStack {
                    Circle().stroke(Color.blue, lineWidth: 4).frame(width: 64, height: 64)
                    Text("✓").font(.system(size: 34, weight: .bold)).foregroundColor(.blue)
                }
                Text("Done").font(.system(size: 17, weight: .semibold)).accessibilityIdentifier("pk-done")
            } else {
                ProgressView()
                Text("Processing").font(.system(size: 17, weight: .semibold)).accessibilityIdentifier("pk-processing")
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: choices

    @ViewBuilder func picker(_ p: _PKSheetModel.Picker) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(pickerTitle(p)).font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary).padding(.leading, 4)
                group {
                    switch p {
                    case .card:
                        ForEach(Array(model.cards.enumerated()), id: \.element.id) { i, c in
                            if i > 0 { divider }
                            option(i, selected: c == model.card, action: { Task { await model.selectCard(c) } }) {
                                HStack(spacing: 12) {
                                    cardArt(c)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(c.title).font(.system(size: 16))
                                        Text("•••• \(c.suffix)").font(.system(size: 14)).foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    case .address, .contact:
                        ForEach(Array(_PKWallet.addresses.enumerated()), id: \.element.id) { i, a in
                            if i > 0 { divider }
                            option(i, selected: a == model.address, action: { Task { await model.selectAddress(a) } }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(a.name).font(.system(size: 16))
                                    Text(p == .contact ? "\(a.email) · \(a.phone)" : a.oneLine).font(.system(size: 14)).foregroundColor(.secondary).lineLimit(2)
                                }
                            }
                        }
                    case .method:
                        ForEach(Array(model.methods.enumerated()), id: \.offset) { i, m in
                            if i > 0 { divider }
                            option(i, selected: m === model.method, action: { Task { await model.selectMethod(m) } }) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(m.label) \(model.money(m.amount))").font(.system(size: 16))
                                    if let d = m.detail { Text(d).font(.system(size: 14)).foregroundColor(.secondary) }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 24)
        }
    }

    func pickerTitle(_ p: _PKSheetModel.Picker) -> String {
        switch p {
        case .card: return "CARDS"
        case .address: return "SHIPPING ADDRESS"
        case .method: return "SHIPPING METHOD"
        case .contact: return "CONTACT"
        }
    }

    // MARK: pieces

    func group<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(UIColor.secondarySystemGroupedBackground)))
    }

    var divider: some View { Rectangle().fill(Color(UIColor.separator)).frame(height: 0.5).padding(.leading, 16) }

    func row<C: View>(id: String, label: String?, errors: [PKPaymentError], action: @escaping () -> Void, @ViewBuilder _ content: () -> C) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 8) {
                    if let label {
                        Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).frame(width: 78, alignment: .leading)
                    }
                    content()
                    Spacer()
                    Text("›").font(.system(size: 22)).foregroundColor(Color(UIColor.tertiaryLabel))
                }
                ForEach(Array(errors.enumerated()), id: \.offset) { _, e in
                    Text(e.localizedDescription).font(.system(size: 13)).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }

    func option<C: View>(_ i: Int, selected: Bool, action: @escaping () -> Void, @ViewBuilder _ content: () -> C) -> some View {
        Button(action: { action(); model.picker = nil }) {
            HStack {
                content()
                Spacer()
                if selected { Text("✓").font(.system(size: 17, weight: .semibold)).foregroundColor(.blue) }
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("pk-option-\(i)")
    }

    func cardArt(_ c: _PKCard) -> some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 4).fill(c.color).frame(width: 46, height: 30)
            Text(c.brand.prefix(4).uppercased()).font(.system(size: 7, weight: .bold)).foregroundColor(.white).padding(3)
        }
    }
}
