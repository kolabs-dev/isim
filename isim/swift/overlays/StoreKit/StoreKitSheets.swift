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

    static func productPage(_ appID: String, close: @escaping () -> Void) -> AnyView { AnyView(_SKProductPage(appID: appID, close: close)) }

    /// Redeems an offer code from the .storekit file (matched against a code offer's reference name, offer ID
    /// or internal ID). The subscription arrives through Transaction.updates, as on iOS.
    static func redeem(_ code: String) -> String? {
        let key = code.trimmingCharacters(in: .whitespaces).lowercased()
        guard !key.isEmpty else { return "Enter a code." }
        for item in _SKConfig.load().items {
            guard let def = item.codes.first(where: { $0.keys.contains(key) }) else { continue }
            if let g = item.groupID, _SKLedger.shared.entitlements().contains(where: { $0.groupID == g }) { return "You’re already subscribed to \(item.groupName ?? "this subscription")." }
            if case .new(let t) = _SKLedger.shared.subscribe(item, offer: def.offer, token: nil) {
                NSLog("isim StoreKit: offer code %@ redeemed: %@ (%@)", code, item.id, def.offer.summary)
                _SKUpdates.transactions.yield(.verified(Transaction(t)))
            }
            return nil
        }
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
                    Text(verbatim: "Your subscription for \(_SKSheets.appName) is active.").font(.system(size: 15)).foregroundStyle(.secondary).accessibilityIdentifier("sk-redeem-done")
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

// MARK: - App Store product page (placeholder)

struct _SKProductPage: View {
    let appID: String, close: () -> Void
    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    _SKAppIcon(size: 96)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: "App \(appID)").font(.system(size: 20, weight: .bold)).accessibilityIdentifier("sk-product-page-title")
                        Text(verbatim: "App Store").font(.system(size: 14)).foregroundStyle(.secondary)
                        Text(verbatim: "GET").font(.system(size: 15, weight: .bold)).foregroundStyle(.white)
                            .padding(.horizontal, 20).padding(.vertical, 5).background(Color(uiColor: .systemGray3), in: Capsule())
                    }
                    Spacer()
                }
                Divider()
                Text(verbatim: "The App Store isn’t available on isim. This is a placeholder for the product page of app \(appID).")
                    .font(.system(size: 15)).foregroundStyle(.secondary).accessibilityIdentifier("sk-product-page-note")
                Spacer()
            }
            .padding(20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { close() }.accessibilityIdentifier("sk-product-page-done") } }
        }
    }
}
