// Sample: local StoreKit testing on isim — StoreKit 2 (products, purchases, auto-renewable subscriptions on
// an accelerated clock, offers, Transaction.updates, finish(), refunds, AppTransaction), the StoreKit views
// (StoreView, ProductView, SubscriptionStoreView), system sheets (manage subscriptions, offer codes, refund),
// the review prompt, and StoreKit 1 (SKProductsRequest, SKPaymentQueue, receipt, SKOverlay, product page).
// Promotional offers are signed in the app with the key in HELLOSTORE_OFFER_KEY (standing in for the developer's
// server; `isim storekit offer-key` prints it). HELLOSTORE_MESSAGES=listen|defer makes the app take StoreKit messages
// (Message.messages) instead of letting isim show them. Every state change is printed, so tests/ui/test_store.py can
// check it.
import SwiftUI
import StoreKit
import CryptoKit

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
        // HELLOSTORE_MESSAGES=listen: take StoreKit messages and show them; =defer: take them and show none
        if let mode = ProcessInfo.processInfo.environment["HELLOSTORE_MESSAGES"] {
            Task { @MainActor in
                for await m in StoreKit.Message.messages {
                    print("message: \(m.reason)")
                    if mode == "listen" { try? m.display(in: UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first!) }
                }
            }
        }
        // purchases started on the App Store (`isim storekit <app> purchase-intent`): completed here
        Task { @MainActor in
            for await intent in PurchaseIntent.intents {
                var offer = "-"
                if #available(iOS 18.0, *) { offer = intent.offer?.id ?? "-" }
                print("purchase intent: \(intent.product.id) offer=\(offer)")
                if let r = try? await intent.product.purchase(), case .success(.verified(let t)) = r { print("purchase intent bought: txn \(t.id)"); await t.finish() }
            }
        }
        Task {
            for await s in Product.SubscriptionInfo.Status.updates {
                print("status update: \(s.state) \(s.transaction.unsafePayloadValue.productID) autoRenew=\(s.renewalInfo.unsafePayloadValue.willAutoRenew)")
            }
        }
        Task {
            let shared = try await AppTransaction.shared
            if case .verified(let a) = shared {
                print("appTransaction: bundle=\(a.bundleID) version=\(a.appVersion) original=\(a.originalAppVersion) env=\(a.environment.rawValue)")
                // device verification: SHA-384 of the nonce and the device verification ID, as Apple documents it
                let id = AppStore.deviceVerificationID!.uuidString.lowercased()
                let expected = Data(SHA384.hash(data: Data((a.deviceVerificationNonce.uuidString.lowercased() + id).utf8)))
                print("appTransaction deviceVerification ok=\(expected == a.deviceVerification)")
                print("appTransaction jws: \(shared.jwsRepresentation)")
            }
            let products = try await Product.products(for: [coinsID, fullGameID, "dev.isim.store.plus.monthly", "dev.isim.store.plus.yearly", "dev.isim.store.premium.monthly"])
            for p in products.sorted(by: { $0.id < $1.id }) {
                var line = "product: \(p.id) \(p.type.rawValue) \(p.displayPrice)"
                if let s = p.subscription {
                    line += " group=\(s.subscriptionGroupID) level=\(s.groupLevel) period=\(s.subscriptionPeriod.value)\(s.subscriptionPeriod.unit)"
                    if let i = s.introductoryOffer { line += " intro=\(i.paymentMode.rawValue):\(i.period.value)\(i.period.unit)" }
                    if !s.promotionalOffers.isEmpty { line += " promos=\(s.promotionalOffers.compactMap { $0.id }.joined(separator: ","))" }
                    if #available(iOS 18.0, *), !s.winBackOffers.isEmpty { line += " winbacks=\(s.winBackOffers.compactMap { $0.id }.joined(separator: ","))" }
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
        if let st {
            let info = st.renewalInfo.unsafePayloadValue
            if st.state == .inGracePeriod { s += " grace=\(info.gracePeriodExpirationDate != nil)" }
            if st.state == .inBillingRetryPeriod || st.state == .inGracePeriod { s += " billingRetry=\(info.isInBillingRetry)" }
            if let r = info.expirationReason, st.state != .subscribed { s += " reason=\(r.rawValue)" }
        }
        if s != lastStatus { lastStatus = s; status = s; print("status: \(s)") }
        var list: [String] = []
        for await r in Transaction.currentEntitlements { if case .verified(let t) = r { list.append(t.productID) } }
        if list != lastEntitlements { lastEntitlements = list; entitlements = list; print("entitlements: [\(list.joined(separator: ","))]") }
    }
}

// Compiles only when SKPaymentDiscount is an open reference type, as in Apple’s SDK.
final class SamplePaymentDiscount: SKPaymentDiscount, @unchecked Sendable {}

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
        let discount = SamplePaymentDiscount(identifier: "comeback", keyIdentifier: "sample", nonce: UUID(),
                                             signature: "", timestamp: NSNumber(value: Int64(1_700_000_000_000)))
        let object: NSObject = discount
        let timestamp: NSNumber = discount.timestamp
        print("sk1 discount: identity=\(object === discount) timestamp=\(timestamp.int64Value)")
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
    @State private var showPlans = false
    @State private var storeKind: StoreKind?
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
                    Button("Promotional offer") { Task { await buyOffer(.promo) } }.accessibilityIdentifier("promo")
                    Button("Promotional offer (JWS)") { Task { await buyOffer(.promoJWS) } }.accessibilityIdentifier("promo-jws")
                    Button("Promotional offer (bad signature)") { Task { await buyOffer(.promoForged) } }.accessibilityIdentifier("promo-bad")
                    Button("Win-back offer") { Task { await buyOffer(.winBack) } }.accessibilityIdentifier("winback")
                    Button("Plans (buttons)") { showPlans = true }.accessibilityIdentifier("open-plans")
                    Button("Restore (AppStore.sync)") {
                        Task {
                            do { try await AppStore.sync(); await shop.refresh(); print("sync: done entitlements=[\(shop.entitlements.joined(separator: ","))]") }
                            catch { print("sync failed: \(error)") }
                        }
                    }.accessibilityIdentifier("sync")
                    Button("Signed transaction") {
                        Task {
                            guard let r = await Transaction.latest(for: "dev.isim.store.plus.monthly") else { return }
                            print("transaction jws: \(r.jwsRepresentation)")
                        }
                    }.accessibilityIdentifier("jws")
                    Button("Request review") { requestReview() }.accessibilityIdentifier("review")
                }
                Section("iOS 18 and later") {
                    Button("Plans in tabs") { storeKind = .tabs }.accessibilityIdentifier("open-tabs")
                    Button("Plans by period (links)") { storeKind = .links }.accessibilityIdentifier("open-links")
                    Button("Plans in sections") { storeKind = .sections }.accessibilityIdentifier("open-sections")
                    Button("Plans, custom picker") { storeKind = .custom }.accessibilityIdentifier("open-custom")
                    Button("Upgrades only") { storeKind = .upgrades }.accessibilityIdentifier("open-upgrades")
                    Button("Subscription offer view") { storeKind = .offerView }.accessibilityIdentifier("open-offer-view")
                    Button("Promote products") { Task { await promote() } }.accessibilityIdentifier("promote")
                }
                Section("Family and renewals") {
                    // Ask to Buy: the purchase waits for the organizer (`isim storekit <app> approve|decline`)
                    Button("Ask to buy the full game") {
                        Task {
                            guard let p = try? await Product.products(for: [fullGameID]).first else { return }
                            switch try? await p.purchase(options: [.simulatesAskToBuyInSandbox(true)]) {
                            case .pending?: print("ask to buy: pending")
                            case .success?: print("ask to buy: bought at once?!")
                            default: print("ask to buy: cancelled")
                            }
                        }
                    }.accessibilityIdentifier("ask-to-buy")
                    Button("Renewal info") {
                        Task {
                            guard let st = (try? await Product.SubscriptionInfo.status(for: groupID))?.first else { print("renewal info: none"); return }
                            let r = st.renewalInfo.unsafePayloadValue
                            var winBacks = "-"
                            if #available(iOS 18.0, *) { winBacks = r.eligibleWinBackOfferIDs.joined(separator: ",") }
                            print("renewal info: state=\(r.state) price=\(r.renewalPrice.map { "\($0)" } ?? "-") currency=\(r.currency?.identifier ?? "-") offer=\(r.offer.map { "\($0.type.rawValue):\($0.id ?? "-")" } ?? "-") period=\(r.offerPeriodStringRepresentation ?? "-") winbacks=[\(winBacks)] app=\(r.appTransactionID.isEmpty ? "-" : "ok")")
                        }
                    }.accessibilityIdentifier("renewal-info")
                    Button("Age rating") {
                        Task {
                            if #available(iOS 26.2, *) { print("age rating: \(await AppStore.ageRatingCode.map { "\($0)" } ?? "nil")") }
                            else { print("age rating: needs iOS 26.2") }
                        }
                    }.accessibilityIdentifier("age-rating")
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
                        if let url = Bundle.main.appStoreReceiptURL, let d = try? Data(contentsOf: url) {
                            print("receipt: \(d.count) bytes, pkcs7=\(d.first == 0x30), path=\(url.path)")
                        }
                    }.accessibilityIdentifier("receipt")
                    Button("App Store overlay") { overlay.toggle() }.accessibilityIdentifier("overlay")
                    Button("App Store page") { showProductPage("1234567890") }.accessibilityIdentifier("product-page")
                    Button("App Store page (unknown app)") { showProductPage("999") }.accessibilityIdentifier("product-page-unknown")
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
        .sheet(isPresented: $showPlans) {
            NavigationStack {
                VStack(spacing: 0) {
                    SubscriptionStoreView(groupID: groupID)
                        .subscriptionStoreControlStyle(.buttons)
                        .subscriptionStoreButtonLabel(.multiline)
                        .storeButton(.visible, for: .policies)
                        .subscriptionStorePolicyDestination(url: URL(string: "https://isim.dev/terms")!, for: .termsOfService)
                        .subscriptionStorePolicyDestination(for: .privacyPolicy) { Text("HelloStore keeps nothing.").accessibilityIdentifier("privacy-text") }
                    ProductView(id: fullGameID).productViewStyle(BadgeStyle())
                }
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { showPlans = false }.accessibilityIdentifier("close-plans") } }
            }
        }
        .sheet(item: $storeKind) { kind in
            NavigationStack {
                ModernStore(kind: kind)
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { storeKind = nil }.accessibilityIdentifier("close-modern") } }
            }
        }
        .appStoreOverlay(isPresented: $overlay) { SKOverlay.AppConfiguration(appIdentifier: "1234567890", position: .bottom) }
    }
    /// promoted in-app purchases: the order (full game first) and coins hidden on the App Store
    func promote() async {
        do {
            try await Product.PromotionInfo.updateProductOrder(byID: [fullGameID, coinsID])
            try await Product.PromotionInfo.updateProductVisibility(.hidden, for: coinsID)
            let order = try await Product.PromotionInfo.currentOrder
            print("promotions: " + order.map { "\($0.productID)=\($0.visibility)" }.joined(separator: " "))
            try await Product.PromotionInfo.updateProductOrder(byID: ["dev.isim.store.nope"])
        } catch {
            print("promotion error: \(error)")
        }
    }
    enum OfferKind { case promo, promoJWS, promoForged, winBack }
    /// Plus Monthly with its promotional offer (signed here, standing in for the developer's server) or win-back offer.
    func buyOffer(_ kind: OfferKind) async {
        guard let p = try? await Product.products(for: ["dev.isim.store.plus.monthly"]).first, let s = p.subscription else { return }
        let env = ProcessInfo.processInfo.environment
        let offerID = s.promotionalOffers[0].id!
        let key = (try? P256.Signing.PrivateKey(pemRepresentation: env["HELLOSTORE_OFFER_KEY"] ?? "")) ?? P256.Signing.PrivateKey()
        let keyID = env["HELLOSTORE_OFFER_KEY_ID"] ?? "NOKEY"
        let token = UUID(), nonce = UUID(), timestamp = Int(Date().timeIntervalSince1970 * 1000)
        var option: Product.PurchaseOption
        switch kind {
        case .winBack:
            guard #available(iOS 18.0, *) else { print("win-back offers need iOS 18"); return }
            option = .winBackOffer(s.winBackOffers[0])
        case .promo, .promoForged:
            let message = [Bundle.main.bundleIdentifier!, keyID, p.id, offerID, token.uuidString.lowercased(), nonce.uuidString.lowercased(), "\(timestamp)"]
                .joined(separator: "\u{2063}")
            let signer = kind == .promoForged ? P256.Signing.PrivateKey() : key
            let signature = try! signer.signature(for: Data(message.utf8)).derRepresentation
            option = .promotionalOffer(offerID: offerID, keyID: keyID, nonce: nonce, signature: signature, timestamp: timestamp)
        case .promoJWS:
            func b64(_ d: Data) -> String { d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
            let header = b64(Data(#"{"alg":"ES256","kid":"\#(keyID)","typ":"JWT"}"#.utf8))
            let claims: [String: Any] = ["bid": Bundle.main.bundleIdentifier!, "productId": p.id, "offerIdentifier": offerID,
                                         "nonce": nonce.uuidString.lowercased(), "iat": Int(Date().timeIntervalSince1970), "appAccountToken": token.uuidString.lowercased()]
            let body = b64(try! JSONSerialization.data(withJSONObject: claims))
            let sig = try! key.signature(for: Data("\(header).\(body)".utf8)).rawRepresentation
            option = .promotionalOffer(offerID, compactJWS: "\(header).\(body).\(b64(sig))")
        }
        do {
            if case .success(.verified(let t)) = try await p.purchase(options: [option, .appAccountToken(token)]) {
                print("offer purchase: txn \(t.id) \(t.productID) offer=\(t.offerType?.rawValue ?? 0):\(t.offerID ?? "-") expires=\(t.expirationDate.map { "\(Int($0.timeIntervalSince(t.purchaseDate).rounded()))s" } ?? "-")")
                await t.finish()
            }
        } catch { print("offer purchase failed: \(error)") }
    }
    func scene() -> UIWindowScene { UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first! }
    /// SKStoreProductViewController, presented with UIKit as apps do
    func showProductPage(_ id: String) {
        let vc = SKStoreProductViewController()
        vc.delegate = ProductPageDelegate.shared
        vc.loadProduct(withParameters: [SKStoreProductParameterITunesItemIdentifier: id]) { ok, _ in print("product page \(id) loaded: \(ok)") }
        var top = scene().windows.first(where: { $0.isKeyWindow })?.rootViewController
        while let p = top?.presentedViewController { top = p }
        top?.present(vc, animated: true)
    }
}

final class ProductPageDelegate: NSObject, SKStoreProductViewControllerDelegate {
    static let shared = ProductPageDelegate()
    func productViewControllerDidFinish(_ vc: SKStoreProductViewController) { print("product page finished"); vc.dismiss(animated: true) }
}

/// an app's own ProductViewStyle (makeBody with the configuration)
struct BadgeStyle: ProductViewStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            Text(configuration.product?.displayName ?? configuration.productID).font(.headline)
            Spacer()
            if configuration.hasCurrentEntitlement { Text("Owned").accessibilityIdentifier("badge-owned") }
            else { Button("Get \(configuration.product?.displayPrice ?? "")") { configuration.purchase() }.accessibilityIdentifier("badge-buy") }
        }
        .padding()
        .accessibilityIdentifier("badge-style")
    }
}

// MARK: - iOS 18 and later subscription stores

enum StoreKind: String, Identifiable { case tabs, links, sections, custom, upgrades, offerView; var id: String { rawValue } }

func isPlus(_ p: Product) -> Bool { p.id.contains(".plus.") }

struct ModernStore: View {
    let kind: StoreKind
    var body: some View {
        switch kind {
        case .tabs:
            // option groups as tabs: Plus (filter) and Premium (its own section)
            SubscriptionStoreView(groupID: groupID) {
                SubscriptionOptionGroup("Plus") { isPlus($0) }
                SubscriptionOptionGroup("Premium", content: {
                    SubscriptionOptionSection("Everything", isIncluded: { !isPlus($0) }) { Text("Includes Plus.").accessibilityIdentifier("premium-footer") }
                }, marketingContent: { Text("Go Premium").font(.title).bold().accessibilityIdentifier("premium-marketing") })
            }
            .subscriptionStoreOptionGroupStyle(.tabs)
            .onInAppPurchaseCompletion { p, _ in print("modern store bought \(p.id)") }
        case .links:
            // a group set: one link per billing period
            SubscriptionStoreView(groupID: groupID) {
                SubscriptionOptionGroupSet(groupedBy: { $0.subscription?.subscriptionPeriod.unit == .year ? "Yearly" : "Monthly" }) { (period: String) in
                    Text(period)
                }
                .subscriptionStoreOptionGroupStyle(.links)
            }
        case .sections:
            SubscriptionStoreView(groupID: groupID) {
                SubscriptionOptionSection("Plus", isIncluded: isPlus) { Text("Cancel anytime.") }
                SubscriptionOptionSection(isIncluded: { !isPlus($0) }) { Text("PREMIUM ✦").accessibilityIdentifier("premium-header") } footer: { EmptyView() }
            }
        case .custom:
            SubscriptionStoreView(groupID: groupID).subscriptionStoreControlStyle(TilePickerStyle())
        case .upgrades:
            // a subscriber sees only the plans above theirs
            SubscriptionStoreView(groupID: groupID, visibleRelationships: .upgrade)
        case .offerView:
            VStack(spacing: 16) {
                if #available(iOS 26.0, *) {
                    SubscriptionOfferView(id: "dev.isim.store.plus.monthly")
                    SubscriptionOfferView(groupID: groupID, visibleRelationship: .upgrade)
                        .subscriptionOfferViewStyle(.compact)
                } else {
                    Text("Subscription offer views need iOS 26").accessibilityIdentifier("offer-view-unavailable")
                }
                Spacer()
            }
            .padding()
        }
    }
}

/// a custom control: SubscriptionStorePicker rows with a tile per plan, and a Join button
struct TilePickerStyle: SubscriptionStoreControlStyle {
    func makeBody(configuration: Configuration) -> some View {
        SubscriptionStorePicker(configuration) { option in
            HStack {
                Text(option.displayName).bold()
                Spacer()
                Text(option.isSelected ? "Selected" : option.displayPrice).foregroundStyle(option.isSelected ? Color.green : Color.secondary)
            }
            .padding()
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
        } confirmation: { option in
            Button("Join \(option.displayName)") { print("custom picker subscribe \(option.id) group=\(configuration.groupDisplayName) options=\(configuration.options.count)"); option.subscribe() }
                .accessibilityIdentifier("custom-join")
        }
    }
}
