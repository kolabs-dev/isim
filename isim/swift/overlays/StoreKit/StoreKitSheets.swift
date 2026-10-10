// isim StoreKit system sheets, drawn like iOS's: Request a Refund, Subscriptions (manage: change plan,
// cancel), Redeem Code (offer codes), and the App Store product page used by SKStoreProductViewController
// and SKOverlay. Everything is local StoreKit testing: nothing is charged, refunds are approved at once,
// offer codes are the "codeOffers" of the .storekit file.
import UIKit
import SwiftUI

final class _SKHostingController: UIHostingController<AnyView> {
    var onGone: (() -> Void)?
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        if presentingViewController == nil { let f = onGone; onGone = nil; f?() }
    }
}

@MainActor enum _SKSheets {
    final class Box { var done = false; weak var host: UIViewController? }

    /// Presents SwiftUI content as a page sheet; returns when it closes (its close action or a swipe).
    static func present(_ build: (_ close: @escaping () -> Void) -> AnyView) async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            guard let top = _SKPurchaseSheet.topController() else { k.resume(); return }
            let box = Box()
            let close: () -> Void = {
                guard !box.done else { return }
                box.done = true
                box.host?.dismiss(animated: true, completion: nil)
                k.resume()
            }
            let h = _SKHostingController(rootView: build(close))
            h.onGone = { if !box.done { box.done = true; k.resume() } }
            box.host = h
            top.present(h, animated: true, completion: nil)
        }
    }

    static func notice(title: String, message: String) async {
        await withCheckedContinuation { (k: CheckedContinuation<Void, Never>) in
            guard let top = _SKPurchaseSheet.topController() else { k.resume(); return }
            let a = UIAlertController(title: title, message: message, preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default) { _ in k.resume() })
            top.present(a, animated: true, completion: nil)
        }
    }

    static func refund(_ t: Transaction) async -> Bool {
        var submitted = false
        NSLog("isim StoreKit: refund request sheet for transaction %llu (%@)", t.id, t.productID)
        await present { close in AnyView(_SKRefundView(transaction: t, submit: { submitted = true; close() }, cancel: close)) }
        if submitted { _SKLedger.shared.revoke(t.id, reason: Transaction.RevocationReason.other.rawValue) }
        return submitted
    }

    static func manageSubscriptions(group: String?) async {
        NSLog("isim StoreKit: manage subscriptions sheet%@", group.map { " (group \($0))" } ?? "")
        await present { close in AnyView(_SKManageView(group: group, close: close)) }
    }

    static func redeemCode() async {
        NSLog("isim StoreKit: offer code redemption sheet")
        await present { close in AnyView(_SKRedeemView(close: close)) }
    }


    /// Redeems an offer code from the .storekit file (matched against a code offer's reference name, offer ID or internal
    /// ID), like the App Store: the code's "eligibility" (new, existing, expired subscribers) applies, each offer is
    /// redeemed once, a current subscriber gets the offer from the next renewal, and (iOS 18) codes for one-time products
    /// give the product. The transaction arrives through Transaction.updates, as on iOS. nil: redeemed; else the error.
    static func redeem(_ code: String) -> String? {
        let key = code.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return "Enter a code." }
        let ledger = _SKLedger.shared
        for item in _SKConfig.load().items {
            guard let def = item.codes.first(where: { $0.keys.contains(key) }) else { continue }
            let tag = "\(item.id)/\(def.name)"
            if ledger.read({ ($0.redeemedOffers ?? []).contains(tag) }) {
                NSLog("isim StoreKit: offer code %@: already redeemed", code)
                return "You’ve already redeemed this offer."
            }
            if let g = item.groupID {
                let active = ledger.entitlements().contains { $0.groupID == g }
                let state = active ? "existing" : ledger.everSubscribed(group: g) ? "expired" : "new"
                guard def.eligibility.contains(state) else {
                    NSLog("isim StoreKit: offer code %@: not eligible (%@ subscriber; the code is for %@)", code, state, def.eligibility.joined(separator: ", "))
                    return "You’re not eligible for this offer."
                }
                if active {     // a current subscriber: the offer starts at the next renewal
                    let o = def.offer
                    ledger.mutate { d in
                        guard var s = d.subscriptions[g] else { return }
                        s.autoRenewProductID = item.id; s.willAutoRenew = true; s.expirationReason = nil
                        s.offerType = o.type.rawValue; s.offerID = o.id; s.offerPaymentMode = o.paymentMode.rawValue
                        s.introPeriodsLeft = o.paymentMode == .payAsYouGo ? o.periodCount : 1
                        d.subscriptions[g] = s
                        d.redeemedOffers = (d.redeemedOffers ?? []) + [tag]
                    }
                    ledger.tick()
                    NSLog("isim StoreKit: offer code %@ redeemed: %@ (%@) from the next renewal", code, item.id, o.summary)
                    return nil
                }
                if case .new(let t) = ledger.subscribe(item, offer: def.offer, token: nil) {
                    ledger.mutate { d in d.redeemedOffers = (d.redeemedOffers ?? []) + [tag] }
                    NSLog("isim StoreKit: offer code %@ redeemed: %@ (%@)", code, item.id, def.offer.summary)
                    _SKUpdates.transactions.yield(.verified(Transaction(t)))
                }
                return nil
            }
            guard _skOSMajor() >= 18 else {
                NSLog("isim StoreKit: offer code %@ is for a one-time product: offer codes for in-app purchases need iOS 18", code)
                return "This code isn’t valid."
            }
            if item.type != .consumable, ledger.entitlements().contains(where: { $0.productID == item.id }) { return "You already own this item." }
            let t = ledger.purchase(item, quantity: 1, token: nil, code: def)
            ledger.mutate { d in d.redeemedOffers = (d.redeemedOffers ?? []) + [tag] }
            NSLog("isim StoreKit: offer code %@ redeemed: %@ (one-time product)", code, item.id)
            _SKUpdates.transactions.yield(.verified(Transaction(t)))
            return nil
        }
        NSLog("isim StoreKit: offer code %@ isn’t valid", code)
        return "This code isn’t valid."
    }

    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "App"
    }
    static func date(_ d: Date?) -> String {
        guard let d else { return "" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .medium
        return f.string(from: d)
    }
    static func pricePerPeriod(_ i: _SKItem) -> String {
        guard let p = i.period else { return i.displayPrice }
        return "\(i.displayPrice)/\(p.value == 1 ? "\(p.unit)" : p.localizedDescription)"
    }
}

struct _SKAppIcon: View {
    var size: CGFloat = 56
    /// the app's icon, as `isim build` lays it out (isim-assets.plist)
    static let icon: UIImage? = {
        let dir = Bundle.main.bundlePath as NSString
        guard let assets = NSDictionary(contentsOfFile: dir.appendingPathComponent("isim-assets.plist")) as? [String: Any],
              let icons = assets["appIcons"] as? [String: Any], let files = (icons["AppIcon"] ?? icons.values.first) as? [[String: Any]],
              let f = files.filter({ ($0["appearance"] as? String ?? "any") == "any" }).last?["file"] as? String ?? files.first?["file"] as? String else { return nil }
        return UIImage(contentsOfFile: dir.appendingPathComponent(f))
    }()
    var body: some View {
        if let icon = _SKAppIcon.icon {
            Image(uiImage: icon).resizable().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22).fill(Color.accentColor.opacity(0.85))
                Image(systemName: "square.grid.2x2").font(.system(size: size * 0.42)).foregroundStyle(.white)
            }
            .frame(width: size, height: size)
        }
    }
}

struct _SKEnvironmentNote: View {
    var body: some View {
        Text(verbatim: "[Environment: isim StoreKit testing]").font(.system(size: 12)).foregroundStyle(.secondary)
    }
}

// MARK: - Refund

struct _SKRefundView: View {
    let transaction: Transaction, submit: () -> Void, cancel: () -> Void
    @State private var reason = -1
    static let reasons = ["I didn’t mean to purchase this item", "My child purchased this without permission", "I don’t want this item anymore",
                          "The item didn’t work as expected", "Other"]
    var body: some View {
        let name = _SKConfig.load().item(transaction.productID)?.name ?? transaction.productID
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        _SKAppIcon(size: 48)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: name).font(.system(size: 16, weight: .semibold))
                            Text(verbatim: "\(_SKSheets.appName) · \(_SKSheets.date(transaction.purchaseDate))").font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    ForEach(Array(_SKRefundView.reasons.enumerated()), id: \.offset) { i, r in
                        Button { reason = i } label: {
                            HStack {
                                Text(verbatim: r).foregroundStyle(.primary)
                                Spacer()
                                if reason == i { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                            }
                        }
                        .accessibilityIdentifier("sk-refund-reason-\(i)")
                    }
                } header: { Text(verbatim: "Choose a reason") } footer: {
                    Text(verbatim: "isim local StoreKit testing: a submitted request is approved at once and the app receives the refunded transaction.")
                }
                Section {
                    Button { submit() } label: { Text(verbatim: "Submit").frame(maxWidth: .infinity) }
                        .disabled(reason < 0)
                        .accessibilityIdentifier("sk-refund-submit")
                }
            }
            .navigationTitle("Request a Refund")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { cancel() }.accessibilityIdentifier("sk-refund-cancel") } }
        }
    }
}

// MARK: - Manage subscriptions

struct _SKManageView: View {
    let group: String?
    let close: () -> Void
    @State private var version = 0
    @State private var confirmCancel: String?
    var body: some View {
        let cfg = _SKConfig.load()
        let groups = cfg.groups.keys.sorted().filter { g in group == nil ? _SKLedger.shared.everSubscribed(group: g) : g == group }
        NavigationStack {
            List {
                if groups.isEmpty {
                    Section { Text(verbatim: "No subscriptions.").foregroundStyle(.secondary) }
                }
                ForEach(groups, id: \.self) { g in groupSection(g, cfg) }
                Section { _SKEnvironmentNote() }
            }
            .id(version)
            .navigationTitle("Subscriptions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { close() }.accessibilityIdentifier("sk-manage-done") } }
        }
    }

    @ViewBuilder func groupSection(_ g: String, _ cfg: _SKConfig) -> some View {
        let st = _SKLedger.shared.read { _SKLedger.statuses($0, group: g, now: Date()) }.first
        let plans = cfg.items.filter { $0.groupID == g }.sorted { ($0.groupLevel, $0.price) < ($1.groupLevel, $1.price) }
        let t = st?.transaction.unsafePayloadValue
        let info = st?.renewalInfo.unsafePayloadValue
        let active = st?.state == .subscribed
        Section {
            HStack(spacing: 12) {
                _SKAppIcon(size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: cfg.groups[g] ?? g).font(.system(size: 16, weight: .semibold))
                    Text(verbatim: t.flatMap { cfg.item($0.productID)?.name } ?? "").font(.system(size: 14))
                    Text(verbatim: statusLine(st)).font(.system(size: 13)).foregroundStyle(.secondary).accessibilityIdentifier("sk-manage-status-\(g)")
                }
            }
        } header: { Text(verbatim: _SKSheets.appName) }
        Section {
            ForEach(plans, id: \.id) { p in
                Button {
                    Task { @MainActor in
                        if active, let cur = t, cur.productID != p.id || !(info?.willAutoRenew ?? true) {
                            _ = _SKLedger.shared.subscribe(p, offer: nil, token: nil)
                            _SKLedger.shared.tick()
                        } else if !active {
                            _ = try? await Product(p)._purchase(options: [], api: nil)
                        }
                        version += 1
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: p.name).foregroundStyle(.primary)
                            Text(verbatim: _SKSheets.pricePerPeriod(p)).font(.system(size: 13)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if active && t?.productID == p.id { Image(systemName: "checkmark").foregroundStyle(Color.accentColor) }
                        else if active && info?.autoRenewPreference == p.id && info?.willAutoRenew == true { Text(verbatim: "Next").font(.system(size: 13)).foregroundStyle(.secondary) }
                    }
                }
                .accessibilityIdentifier("sk-manage-plan-\(p.id)")
            }
        } header: { Text(verbatim: "Options") }
        if active, info?.willAutoRenew == true {
            Section {
                if confirmCancel == g {
                    Button(role: .destructive) { _SKLedger.shared.setAutoRenew(group: g, false); confirmCancel = nil; version += 1 } label: {
                        Text(verbatim: "Confirm Cancellation").frame(maxWidth: .infinity)
                    }
                    .accessibilityIdentifier("sk-manage-confirm-cancel")
                } else {
                    Button(role: .destructive) { confirmCancel = g } label: { Text(verbatim: "Cancel Subscription").frame(maxWidth: .infinity) }
                        .accessibilityIdentifier("sk-manage-cancel")
                }
            } footer: {
                Text(verbatim: "If you cancel now, you can still access your subscription until \(_SKSheets.date(t?.expirationDate)).")
            }
        }
    }

    func statusLine(_ st: Product.SubscriptionInfo.Status?) -> String {
        guard let st else { return "" }
        let t = st.transaction.unsafePayloadValue, info = st.renewalInfo.unsafePayloadValue
        switch st.state {
        case .subscribed:
            if info.willAutoRenew {
                if let next = info.autoRenewPreference, next != t.productID, let n = _SKConfig.load().item(next) { return "Changes to \(n.name) on \(_SKSheets.date(t.expirationDate))" }
                return "Renews \(_SKSheets.date(t.expirationDate))"
            }
            return "Expires \(_SKSheets.date(t.expirationDate))"
        case .revoked: return "Refunded \(_SKSheets.date(t.revocationDate))"
        case .inBillingRetryPeriod: return "Billing problem"
        default: return "Expired \(_SKSheets.date(t.expirationDate))"
        }
    }
}

// MARK: - Offer codes

struct _SKRedeemView: View {
    let close: () -> Void
    @State private var code = ""
    @State private var error: String?
    @State private var redeemed = false
    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                _SKAppIcon(size: 64).padding(.top, 24)
                Text(verbatim: redeemed ? "Code Redeemed" : "Redeem Code").font(.system(size: 22, weight: .bold))
                if redeemed {
                    Text(verbatim: "Your offer for \(_SKSheets.appName) has been redeemed.").font(.system(size: 15)).foregroundStyle(.secondary).accessibilityIdentifier("sk-redeem-done")
                    Button { close() } label: { Text(verbatim: "Done").frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).accessibilityIdentifier("sk-redeem-ok")
                } else {
                    Text(verbatim: "Enter the offer code for \(_SKSheets.appName).").font(.system(size: 15)).foregroundStyle(.secondary)
                    TextField("Code", text: $code)
                        .textInputAutocapitalization(.characters).autocorrectionDisabled()
                        .padding(12).background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .accessibilityIdentifier("sk-redeem-field")
                    if let error { Text(verbatim: error).font(.system(size: 13)).foregroundStyle(.red).accessibilityIdentifier("sk-redeem-error") }
                    Button {
                        if let e = _SKSheets.redeem(code) { error = e } else { redeemed = true }
                    } label: { Text(verbatim: "Redeem").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent).accessibilityIdentifier("sk-redeem-submit")
                }
                _SKEnvironmentNote()
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { close() }.accessibilityIdentifier("sk-redeem-cancel") } }
        }
    }
}

// MARK: - App Store product data

/// An app's App Store listing from Apple's public lookup API (https://itunes.apple.com/lookup, no account needed):
/// name, developer, icon, rating, price, description. ISIM_APPSTORE_LOOKUP_URL replaces the endpoint (a URL with
/// "{id}" in it, or a base the query is appended to; file:// works for offline fixtures).
struct _SKAppListing: Sendable {
    var id: String
    var name = "", seller = "", price = "", genre = "", version = "", contentRating = "", description = ""
    var rating: Double = 0, ratingCount = 0
    var iconURL: String?
    var icon: Data?
}

enum _SKAppStore {
    /// looks the app up by App Store ID (or bundle ID); nil: not found; throws when the lookup itself failed
    static func lookup(id: String? = nil, bundleID: String? = nil) async throws -> _SKAppListing? {
        let country = String(_SKConfig.load().storefront.prefix(2)).lowercased()
        let env = ProcessInfo.processInfo.environment["ISIM_APPSTORE_LOOKUP_URL"].flatMap { $0.isEmpty ? nil : $0 }
        let key = id.map { "id=\($0)" } ?? "bundleId=\(bundleID ?? "")"
        var urlString: String
        if let env, env.contains("{id}") { urlString = env.replacingOccurrences(of: "{id}", with: id ?? bundleID ?? "") }
        else { urlString = (env ?? "https://itunes.apple.com/lookup") + "?\(key)&country=\(country)&entity=software" }
        guard let url = URL(string: urlString) else { return nil }
        let data = try await fetch(url)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let r = (root["results"] as? [[String: Any]])?.first else { return nil }
        var l = _SKAppListing(id: (r["trackId"] as? NSNumber).map { "\($0)" } ?? id ?? "")
        l.name = r["trackName"] as? String ?? ""
        l.seller = r["sellerName"] as? String ?? r["artistName"] as? String ?? ""
        l.price = r["formattedPrice"] as? String ?? ""
        l.genre = r["primaryGenreName"] as? String ?? ""
        l.version = r["version"] as? String ?? ""
        l.contentRating = r["trackContentRating"] as? String ?? ""
        l.description = r["description"] as? String ?? ""
        l.rating = (r["averageUserRating"] as? NSNumber)?.doubleValue ?? 0
        l.ratingCount = Int((r["userRatingCount"] as? NSNumber)?.int64Value ?? 0)
        l.iconURL = r["artworkUrl512"] as? String ?? r["artworkUrl100"] as? String
        if let s = l.iconURL, let u = URL(string: s) { l.icon = try? await fetch(u) }
        return l
    }
    static func fetch(_ url: URL) async throws -> Data {
        if url.isFileURL { return try Data(contentsOf: url) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: req)
        if let h = response as? HTTPURLResponse, h.statusCode >= 400 { throw URLError(.badServerResponse) }
        return data
    }
}

@MainActor final class _SKListingModel: ObservableObject {
    @Published var listing: _SKAppListing?
    @Published var failed: String?
    let appID: String
    init(appID: String) { self.appID = appID }
}

struct _SKListingIcon: View {
    let listing: _SKAppListing?, size: CGFloat
    var body: some View {
        if let d = listing?.icon, let img = UIImage(data: d) {
            Image(uiImage: img).resizable().frame(width: size, height: size).clipShape(RoundedRectangle(cornerRadius: size * 0.22))
                .overlay(RoundedRectangle(cornerRadius: size * 0.22).stroke(Color(uiColor: .separator), lineWidth: 0.5))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color(uiColor: .systemGray5)).frame(width: size, height: size)
        }
    }
}

struct _SKStars: View {
    let rating: Double
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: rating >= Double(i) + 0.75 ? "star.fill" : rating >= Double(i) + 0.25 ? "star.leadinghalf.filled" : "star")
                    .font(.system(size: 11))
            }
        }
        .foregroundStyle(.secondary)
    }
}

/// "GET": installing apps from the App Store is not possible on isim
@MainActor func _skGetUnavailable() {
    NSLog("isim StoreKit: App Store install requested (not available on isim)")
    guard let top = _SKPurchaseSheet.topController() else { return }
    let a = UIAlertController(title: "App Store Unavailable", message: "Apps from the App Store can’t be installed on isim.", preferredStyle: .alert)
    a.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
    top.present(a, animated: true, completion: nil)
}

// MARK: - App Store product page

struct _SKProductPage: View {
    @ObservedObject var model: _SKListingModel
    let close: () -> Void
    var body: some View {
        let l = model.listing
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top, spacing: 14) {
                        _SKListingIcon(listing: l, size: 108)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(verbatim: l?.name ?? (model.failed == nil ? "Loading…" : "App \(model.appID)")).font(.system(size: 22, weight: .bold)).lineLimit(2)
                                .accessibilityIdentifier("sk-product-page-title")
                            Text(verbatim: l?.seller ?? "").font(.system(size: 15)).foregroundStyle(.secondary).accessibilityIdentifier("sk-product-page-seller")
                            Spacer(minLength: 6)
                            if l != nil {
                                Button { _skGetUnavailable() } label: {
                                    Text(verbatim: (l?.price ?? "").isEmpty || l?.price == "Free" ? "GET" : l!.price).font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                                        .padding(.horizontal, 22).padding(.vertical, 6).background(Color.accentColor, in: Capsule())
                                }
                                .accessibilityIdentifier("sk-product-page-get")
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    if let l {
                        Divider()
                        HStack {
                            VStack(spacing: 2) {
                                Text(verbatim: "\(l.ratingCount) RATINGS").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                Text(verbatim: String(format: "%.1f", l.rating)).font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary)
                                    .accessibilityIdentifier("sk-product-page-rating")
                                _SKStars(rating: l.rating)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text(verbatim: "AGE").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                Text(verbatim: l.contentRating).font(.system(size: 20, weight: .bold)).foregroundStyle(.secondary)
                                Text(verbatim: "Years Old").font(.system(size: 11)).foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            VStack(spacing: 2) {
                                Text(verbatim: "CATEGORY").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                                Image(systemName: "square.grid.2x2").font(.system(size: 18, weight: .semibold)).foregroundStyle(.secondary)
                                Text(verbatim: l.genre).font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        Divider()
                        if !l.version.isEmpty { Text(verbatim: "Version \(l.version)").font(.system(size: 13)).foregroundStyle(.secondary) }
                        Text(verbatim: l.description).font(.system(size: 15)).lineLimit(8).accessibilityIdentifier("sk-product-page-description")
                    } else if let f = model.failed {
                        Text(verbatim: f).font(.system(size: 15)).foregroundStyle(.secondary).accessibilityIdentifier("sk-product-page-note")
                    } else {
                        ProgressView().frame(maxWidth: .infinity)
                    }
                    Text(verbatim: "[Environment: isim — App Store listing; apps can’t be installed]").font(.system(size: 11)).foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { close() }.accessibilityIdentifier("sk-product-page-done") } }
        }
    }
}
