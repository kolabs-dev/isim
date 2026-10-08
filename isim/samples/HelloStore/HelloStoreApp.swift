// Sample: local StoreKit testing on isim — StoreKit 2 (products, purchases, auto-renewable subscriptions on
// an accelerated clock, offers, Transaction.updates, finish(), refunds, AppTransaction), the StoreKit views
// (StoreView, ProductView, SubscriptionStoreView), system sheets (manage subscriptions, offer codes, refund),
// the review prompt, and StoreKit 1 (SKProductsRequest, SKPaymentQueue, receipt, SKOverlay, product page).
// Every state change is printed, so tests/ui/test_store.py can check it.
import SwiftUI
import StoreKit

let groupID = "21000001"
let coinsID = "dev.isim.store.coins", fullGameID = "dev.isim.store.full_game"

@MainActor final class Shop: ObservableObject {
    @Published var status = "none"
    @Published var entitlements: [String] = []
    @Published var renewals = 0
    @Published var coins = 0
    var lastStatus = ""
    var lastEntitlements: [String]?

    func start() {
        Task {
            // Transaction.updates: unfinished transactions at launch, then renewals, refunds, offer codes...
            for await r in Transaction.updates {
                guard case .verified(let t) = r else { continue }
                let offer = t.offerType.map { " offer=\($0.rawValue):\(t.offerID ?? "-")" } ?? ""
                print("update: txn \(t.id) \(t.productID) reason=\(t.reason == .renewal ? "renewal" : "purchase")\(offer)\(t.revocationDate != nil ? " revoked" : "")")
                if t.reason == .renewal { renewals += 1 }
                if t.productID == coinsID, t.revocationDate == nil { coins += 100; print("coins \(coins)") }
                await t.finish()
            }
        }
        Task {
            for await s in Product.SubscriptionInfo.Status.updates {
                print("status update: \(s.state) \(s.transaction.unsafePayloadValue.productID) autoRenew=\(s.renewalInfo.unsafePayloadValue.willAutoRenew)")
            }
        }
        Task {
            if case .verified(let a) = try await AppTransaction.shared {
                print("appTransaction: bundle=\(a.bundleID) version=\(a.appVersion) original=\(a.originalAppVersion) env=\(a.environment.rawValue)")
            }
            let products = try await Product.products(for: [coinsID, fullGameID, "dev.isim.store.plus.monthly", "dev.isim.store.plus.yearly", "dev.isim.store.premium.monthly"])
            for p in products.sorted(by: { $0.id < $1.id }) {
                var line = "product: \(p.id) \(p.type.rawValue) \(p.displayPrice)"
                if let s = p.subscription {
                    line += " group=\(s.subscriptionGroupID) level=\(s.groupLevel) period=\(s.subscriptionPeriod.value)\(s.subscriptionPeriod.unit)"
                    if let i = s.introductoryOffer { line += " intro=\(i.paymentMode.rawValue):\(i.period.value)\(i.period.unit)" }
                    if !s.promotionalOffers.isEmpty { line += " promos=\(s.promotionalOffers.compactMap { $0.id }.joined(separator: ","))" }
                    if !s.winBackOffers.isEmpty { line += " winbacks=\(s.winBackOffers.compactMap { $0.id }.joined(separator: ","))" }
                    line += " introEligible=\(await s.isEligibleForIntroOffer)"
                }
                print(line)
            }
            while true {      // poll status + entitlements, print changes
                await refresh()
                try? await Task.sleep(nanoseconds: 400_000_000)
            }
        }
    }

    func refresh() async {
        let st = (try? await Product.SubscriptionInfo.status(for: groupID))?.first
        var s = "none"
        if let st { s = "\(st.state) \(st.transaction.unsafePayloadValue.productID) autoRenew=\(st.renewalInfo.unsafePayloadValue.willAutoRenew)" }
        if s != lastStatus { lastStatus = s; status = s; print("status: \(s)") }
        var list: [String] = []
        for await r in Transaction.currentEntitlements { if case .verified(let t) = r { list.append(t.productID) } }
        if list != lastEntitlements { lastEntitlements = list; entitlements = list; print("entitlements: [\(list.joined(separator: ","))]") }
    }
}

final class SK1Observer: NSObject, SKPaymentTransactionObserver, SKProductsRequestDelegate {
    static let shared = SK1Observer()
    var request: SKProductsRequest?
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for t in transactions {
            print("sk1: \(t.payment.productIdentifier) state=\(t.transactionState.rawValue) id=\(t.transactionIdentifier ?? "-")\(t.original.map { " original=\($0.transactionIdentifier ?? "-")" } ?? "")")
            if t.transactionState != .purchasing { queue.finishTransaction(t) }
        }
    }
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) { print("sk1: restore finished") }
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        for p in response.products {
            print("sk1 product: \(p.productIdentifier) \(p.localizedTitle) \(p.price) period=\(p.subscriptionPeriod.map { "\($0.numberOfUnits)/\($0.unit.rawValue)" } ?? "-") intro=\(p.introductoryPrice.map { "\($0.paymentMode.rawValue)" } ?? "-")")
        }
        print("sk1 invalid: \(response.invalidProductIdentifiers)")
        if let coins = response.products.first(where: { $0.productIdentifier == coinsID }) {
            SKPaymentQueue.default().add(SKPayment(product: coins))
        }
    }
    func requestDidFinish(_ request: SKRequest) { print("sk1: request finished") }
}

@main
struct HelloStoreApp: App {
    @StateObject private var shop = Shop()
    var body: some Scene { WindowGroup { RootView().environmentObject(shop).onAppear { shop.start() } } }
}

struct RootView: View {
    @EnvironmentObject var shop: Shop
    @Environment(\.requestReview) private var requestReview
    @State private var showSubs = false
    @State private var showProducts = false
    @State private var overlay = false
    var body: some View {
        NavigationStack {
            List {
                Section("StoreKit 2") {
                    Button("Subscription store") { showSubs = true }.accessibilityIdentifier("open-subs")
                    Button("Products") { showProducts = true }.accessibilityIdentifier("open-products")
                    Button("Manage subscriptions") {
                        Task { try? await AppStore.showManageSubscriptions(in: scene()) }
                    }.accessibilityIdentifier("manage")
                    Button("Refund full game") {
                        Task {
                            guard case .verified(let t)? = await Transaction.latest(for: fullGameID) else { print("refund: nothing to refund"); return }
                            let r = try? await t.beginRefundRequest(in: scene())
                            print("refund request: \(r.map { "\($0)" } ?? "error")")
                        }
                    }.accessibilityIdentifier("refund")
                    Button("Redeem code") { Task { try? await AppStore.presentOfferCodeRedeemSheet(in: scene()) } }.accessibilityIdentifier("redeem")
                    Button("Promotional offer") { Task { await buyOffer(winBack: false) } }.accessibilityIdentifier("promo")
                    Button("Win-back offer") { Task { await buyOffer(winBack: true) } }.accessibilityIdentifier("winback")
                    Button("Request review") { requestReview() }.accessibilityIdentifier("review")
                }
                Section("StoreKit 1") {
                    Button("SK1 buy coins") {
                        SKPaymentQueue.default().add(SK1Observer.shared)
                        let r = SKProductsRequest(productIdentifiers: [coinsID, "dev.isim.store.plus.monthly", "dev.isim.store.nope"])
                        r.delegate = SK1Observer.shared
                        SK1Observer.shared.request = r
                        r.start()
                    }.accessibilityIdentifier("sk1")
                    Button("SK1 restore") { SKPaymentQueue.default().restoreCompletedTransactions() }.accessibilityIdentifier("sk1-restore")
                    Button("Receipt") {
                        if let url = Bundle.main.appStoreReceiptURL, let d = try? Data(contentsOf: url), let s = String(data: d, encoding: .utf8) {
                            print("receipt: \(d.count) bytes, local unsigned=\(has(s, "LOCAL UNSIGNED")), full_game=\(has(s, fullGameID))")
                        }
                    }.accessibilityIdentifier("receipt")
                    Button("App Store overlay") { overlay.toggle() }.accessibilityIdentifier("overlay")
                    Button("App Store page") { showProductPage() }.accessibilityIdentifier("product-page")
                }
                Section("Status") {
                    Text("Plus: \(shop.status)").accessibilityIdentifier("status")
                    Text("Renewals: \(shop.renewals) · Coins: \(shop.coins)").accessibilityIdentifier("renewals")
                }
            }
            .navigationTitle("Store")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSubs) {
            NavigationStack {
                SubscriptionStoreView(groupID: groupID)
                    .storeButton(.visible, for: .redeemCode)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showSubs = false }.accessibilityIdentifier("close-subs") } }
            }
        }
        .sheet(isPresented: $showProducts) {
            NavigationStack {
                VStack(spacing: 0) {
                    StoreView(ids: [coinsID, fullGameID])
                    ProductView(id: fullGameID).productViewStyle(.large).padding()
                }
                .onInAppPurchaseCompletion { product, result in
                    if case .success(.success(.verified(let t))) = result {
                        print("completion: \(product.id) txn \(t.id)")
                        if product.id == coinsID { print("leaving coins txn \(t.id) not finished") } else { await t.finish() }
                    }
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showProducts = false }.accessibilityIdentifier("close-products") } }
            }
        }
        .appStoreOverlay(isPresented: $overlay) { SKOverlay.AppConfiguration(appIdentifier: "1234567890", position: .bottom) }
    }
    /// Plus Monthly with its promotional offer (signature not checked locally) or win-back offer.
    func buyOffer(winBack: Bool) async {
        guard let p = try? await Product.products(for: ["dev.isim.store.plus.monthly"]).first, let s = p.subscription else { return }
        let option: Product.PurchaseOption = winBack
            ? .winBackOffer(s.winBackOffers[0])
            : .promotionalOffer(offerID: s.promotionalOffers[0].id!, keyID: "LOCALKEY", nonce: UUID(), signature: Data(), timestamp: 0)
        do {
            if case .success(.verified(let t)) = try await p.purchase(options: [option]) {
                print("offer purchase: txn \(t.id) \(t.productID) offer=\(t.offerType?.rawValue ?? 0):\(t.offerID ?? "-") expires=\(t.expirationDate.map { "\(Int($0.timeIntervalSince(t.purchaseDate).rounded()))s" } ?? "-")")
                await t.finish()
            }
        } catch { print("offer purchase failed: \(error)") }
    }
    func scene() -> UIWindowScene { UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first! }
    /// SKStoreProductViewController, presented with UIKit as apps do
    func showProductPage() {
        let vc = SKStoreProductViewController()
        vc.delegate = ProductPageDelegate.shared
        vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: "1234567890"]) { ok, _ in print("product page loaded: \(ok)") }
        var top = scene().windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(vc, animated: true)
    }
}

final class ProductPageDelegate: NSObject, SKStoreProductViewControllerDelegate {
    static let shared = ProductPageDelegate()
    func productViewControllerDidFinish(_ vc: SKStoreProductViewController) { print("product page finished"); vc.dismiss(animated: true) }
}

func has(_ s: String, _ sub: String) -> Bool {
    let a = Array(s.utf8), b = Array(sub.utf8)
    guard b.count <= a.count else { return false }
    for i in 0...(a.count - b.count) where Array(a[i..<(i + b.count)]) == b { return true }
    return false
}
