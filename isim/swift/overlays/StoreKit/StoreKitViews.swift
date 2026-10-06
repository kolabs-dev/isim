// isim StoreKit views for SwiftUI (iOS 17): ProductView, StoreView, SubscriptionStoreView, the purchase
// action, purchase/status/entitlement tasks and the StoreKit sheets as modifiers. Drawn like iOS's
// (product rows with a price button; a subscription store with marketing header, plan picker and a
// subscribe button) on isim's local StoreKit testing.
import UIKit
import SwiftUI

// MARK: - Environment

public struct PurchaseAction {
    @MainActor public func callAsFunction(_ product: Product, options: Set<Product.PurchaseOption> = []) async throws -> Product.PurchaseResult {
        try await product.purchase(options: options)
    }
}
struct _SKPurchaseKey: EnvironmentKey { static var defaultValue: PurchaseAction { PurchaseAction() } }
struct _SKStyleKey: EnvironmentKey { static var defaultValue: Int { 0 } }   // 0 automatic/regular, 1 compact, 2 large
struct _SKButtonsKey: EnvironmentKey { static var defaultValue: [String: Visibility] { [:] } }
struct _SKStartKey: EnvironmentKey { static var defaultValue: ((Product) async -> Void)? { nil } }
struct _SKCompletionKey: EnvironmentKey { static var defaultValue: ((Product, Result<Product.PurchaseResult, Error>) async -> Void)? { nil } }
extension EnvironmentValues {
    public var purchase: PurchaseAction { get { self[_SKPurchaseKey.self] } set { self[_SKPurchaseKey.self] = newValue } }
    var _skStyle: Int { get { self[_SKStyleKey.self] } set { self[_SKStyleKey.self] = newValue } }
    var _skButtons: [String: Visibility] { get { self[_SKButtonsKey.self] } set { self[_SKButtonsKey.self] = newValue } }
    var _skStart: ((Product) async -> Void)? { get { self[_SKStartKey.self] } set { self[_SKStartKey.self] = newValue } }
    var _skCompletion: ((Product, Result<Product.PurchaseResult, Error>) async -> Void)? { get { self[_SKCompletionKey.self] } set { self[_SKCompletionKey.self] = newValue } }
}

public protocol ProductViewStyle { var _skStyle: Int { get } }
public struct AutomaticProductViewStyle: ProductViewStyle { public init() {}; public var _skStyle: Int { 0 } }
public struct CompactProductViewStyle: ProductViewStyle { public init() {}; public var _skStyle: Int { 1 } }
public struct RegularProductViewStyle: ProductViewStyle { public init() {}; public var _skStyle: Int { 0 } }
public struct LargeProductViewStyle: ProductViewStyle { public init() {}; public var _skStyle: Int { 2 } }
extension ProductViewStyle where Self == AutomaticProductViewStyle { public static var automatic: AutomaticProductViewStyle { .init() } }
extension ProductViewStyle where Self == CompactProductViewStyle { public static var compact: CompactProductViewStyle { .init() } }
extension ProductViewStyle where Self == RegularProductViewStyle { public static var regular: RegularProductViewStyle { .init() } }
extension ProductViewStyle where Self == LargeProductViewStyle { public static var large: LargeProductViewStyle { .init() } }

public struct StoreButtonKind: Hashable, Sendable {
    let name: String
    public static let cancellation = StoreButtonKind(name: "cancellation")
    public static let restorePurchases = StoreButtonKind(name: "restorePurchases")
    public static let redeemCode = StoreButtonKind(name: "redeemCode")
    public static let signIn = StoreButtonKind(name: "signIn")
    public static let policies = StoreButtonKind(name: "policies")
}

public enum EntitlementTaskState<Value> {
    case loading
    case failure(Error)
    case success(Value)
    public var transaction: Value? { if case .success(let v) = self { return v }; return nil }
}

struct _SKStoreButtons: ViewModifier {
    let visibility: Visibility, kinds: [String]
    @Environment(\._skButtons) var current
    func body(content: Content) -> some View {
        var merged = current
        for k in kinds { merged[k] = visibility }
        return content.environment(\._skButtons, merged)
    }
}
public protocol SubscriptionStoreControlStyle {}
public struct AutomaticSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {} }
public struct PickerSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {} }
public struct ButtonsSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {} }
public struct PrefersProminentPickerSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {} }
extension SubscriptionStoreControlStyle where Self == AutomaticSubscriptionStoreControlStyle { public static var automatic: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == PickerSubscriptionStoreControlStyle { public static var picker: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == ButtonsSubscriptionStoreControlStyle { public static var buttons: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == PrefersProminentPickerSubscriptionStoreControlStyle { public static var prominentPicker: Self { .init() } }
public enum SubscriptionStoreButtonLabel: Hashable, Sendable { case automatic, action, displayName, price, singleLine, multiline }

extension View {
    public func productViewStyle<S: ProductViewStyle>(_ style: S) -> some View { environment(\._skStyle, style._skStyle) }
    public func storeButton(_ visibility: Visibility, for buttonKinds: StoreButtonKind...) -> some View {
        modifier(_SKStoreButtons(visibility: visibility, kinds: buttonKinds.map { $0.name }))
    }
    public func onInAppPurchaseStart(perform action: ((Product) async -> Void)?) -> some View { environment(\._skStart, action) }
    public func onInAppPurchaseCompletion(perform action: ((Product, Result<Product.PurchaseResult, Error>) async -> Void)?) -> some View {
        environment(\._skCompletion, action)
    }
    public func subscriptionStoreControlStyle<S: SubscriptionStoreControlStyle>(_ style: S) -> some View { self }
    public func subscriptionStoreButtonLabel(_ label: SubscriptionStoreButtonLabel) -> some View { self }
    public func subscriptionStorePolicyDestination(url: URL, for policy: Any) -> some View { self }
    public func storeProductTask(for id: String, priority: TaskPriority = .medium, action: @escaping (Product?) async -> Void) -> some View {
        task { await action(try? await Product.products(for: [id]).first) }
    }

    /// Runs `action` with the group's statuses now and whenever they change (renewal, expiry, refund, plan change).
    public func subscriptionStatusTask(for groupID: String, priority: TaskPriority = .medium,
                                       action: @escaping (EntitlementTaskState<[Product.SubscriptionInfo.Status]>) async -> Void) -> some View {
        task {
            await action(.loading)
            let updates = Product.SubscriptionInfo.Status.updates
            do { await action(.success(try await Product.SubscriptionInfo.status(for: groupID))) } catch { await action(.failure(error)) }
            for await s in updates where s.transaction.unsafePayloadValue.subscriptionGroupID == groupID {
                await action(.success((try? await Product.SubscriptionInfo.status(for: groupID)) ?? []))
            }
        }
    }
    /// Runs `action` with the product's current entitlement now and whenever transactions update.
    public func currentEntitlementTask(for productID: String, priority: TaskPriority = .medium,
                                       action: @escaping (EntitlementTaskState<VerificationResult<Transaction>?>) async -> Void) -> some View {
        task {
            await action(.loading)
            let updates = Transaction.updates
            await action(.success(await Transaction.currentEntitlement(for: productID)))
            for await t in updates where t.unsafePayloadValue.productID == productID {
                await action(.success(await Transaction.currentEntitlement(for: productID)))
            }
        }
    }

    public func manageSubscriptionsSheet(isPresented: Binding<Bool>) -> some View {
        sheet(isPresented: isPresented) { _SKManageView(group: nil, close: { isPresented.wrappedValue = false }) }
    }
    public func manageSubscriptionsSheet(isPresented: Binding<Bool>, subscriptionGroupID: String) -> some View {
        sheet(isPresented: isPresented) { _SKManageView(group: subscriptionGroupID, close: { isPresented.wrappedValue = false }) }
    }
    public func offerCodeRedemption(isPresented: Binding<Bool>, onCompletion: @escaping (Result<Void, Error>) -> Void = { _ in }) -> some View {
        sheet(isPresented: isPresented) { _SKRedeemView(close: { isPresented.wrappedValue = false; onCompletion(.success(())) }) }
    }
    /// In local testing a submitted refund request is approved at once (the app receives the revoked transaction).
    public func refundRequestSheet(for transactionID: UInt64, isPresented: Binding<Bool>,
                                   onDismiss: ((Result<Transaction.RefundRequestStatus, Transaction.RefundRequestError>) -> Void)? = nil) -> some View {
        sheet(isPresented: isPresented) {
            if let t = _SKLedger.shared.transaction(transactionID) {
                _SKRefundView(transaction: Transaction(t), submit: {
                    _SKLedger.shared.revoke(transactionID); isPresented.wrappedValue = false; onDismiss?(.success(.success))
                }, cancel: { isPresented.wrappedValue = false; onDismiss?(.success(.userCancelled)) })
            } else {
                Text(verbatim: "Unknown transaction").onAppear { isPresented.wrappedValue = false; onDismiss?(.failure(.failed)) }
            }
        }
    }
    public func appStoreOverlay(isPresented: Binding<Bool>, configuration: @escaping () -> SKOverlay.Configuration) -> some View {
        onChange(of: isPresented.wrappedValue, initial: true) { _, shown in
            MainActor.assumeIsolated {
                guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first else { return }
                if shown { SKOverlay(configuration: configuration()).present(in: scene) } else { SKOverlay.dismiss(in: scene) }
            }
        }
    }
}

/// Shared purchase flow for the store views (start/completion callbacks from the environment).
@MainActor func _skBuy(_ p: Product, _ env: EnvironmentValues, options: Set<Product.PurchaseOption> = []) async {
    if let s = env._skStart { await s(p) }
    do {
        let r = try await p.purchase(options: options)
        if let c = env._skCompletion { await c(p, .success(r)) }
    } catch {
        if let c = env._skCompletion { await c(p, .failure(error)) }
    }
}

struct _SKProductIcon: View {
    let product: Product, size: CGFloat
    var body: some View {
        let symbol = product.type == .autoRenewable || product.type == .nonRenewable ? "star.fill" : product.type == .consumable ? "plus" : "lock.fill"
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22).fill(Color.accentColor.opacity(0.18))
            Image(systemName: symbol).font(.system(size: size * 0.45, weight: .semibold)).foregroundStyle(Color.accentColor)
        }
        .frame(width: size, height: size)
    }
}

struct _SKPriceButton: View {
    let product: Product, owned: Bool, action: () -> Void
    var body: some View {
        if owned {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 22)).foregroundStyle(Color.accentColor)
                .accessibilityIdentifier("sk-owned-\(product.id)")
        } else {
            Button(action: action) {
                Text(verbatim: product.displayPrice).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
            }
            .accessibilityIdentifier("sk-buy-\(product.id)")
        }
    }
}

// MARK: - ProductView

public struct ProductView<Icon: View, PlaceholderIcon: View>: View {
    let id: String
    let given: Product?
    let icon: (() -> Icon)?
    @Environment(\.self) private var env
    @State private var version = 0

    public init(id: String, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon, @ViewBuilder placeholderIcon: @escaping () -> PlaceholderIcon) {
        self.id = id; given = nil; self.icon = icon
    }
    public init(_ product: Product, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon) where PlaceholderIcon == EmptyView {
        id = product.id; given = product; self.icon = icon
    }
    public init(id: String, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon) where PlaceholderIcon == EmptyView {
        self.id = id; given = nil; self.icon = icon
    }

    var product: Product? { given ?? _SKConfig.load().item(id).map(Product.init) }

    public var body: some View {
        if let p = product {
            let owned = _SKLedger.shared.entitlements().contains { $0.productID == p.id } && p.type != .consumable
            let style = env._skStyle
            let iconView = Group { if let icon { icon() } else { _SKProductIcon(product: p, size: style == 2 ? 96 : 52) } }
            let buy = { Task { @MainActor in await _skBuy(p, env); version += 1 } }
            Group {
                if style == 2 {
                    VStack(spacing: 10) {
                        iconView
                        Text(verbatim: p.displayName).font(.system(size: 22, weight: .bold))
                        Text(verbatim: p.description).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        _SKPriceButton(product: p, owned: owned) { _ = buy() }
                    }
                    .frame(maxWidth: .infinity)
                } else if style == 1 {
                    HStack(spacing: 10) {
                        Text(verbatim: p.displayName).font(.system(size: 16, weight: .semibold))
                        Spacer()
                        _SKPriceButton(product: p, owned: owned) { _ = buy() }
                    }
                } else {
                    HStack(spacing: 12) {
                        iconView
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: p.displayName).font(.system(size: 16, weight: .semibold))
                            Text(verbatim: p.description).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer()
                        _SKPriceButton(product: p, owned: owned) { _ = buy() }
                    }
                }
            }
            .id(version)
        } else {
            Text(verbatim: "Product unavailable").foregroundStyle(.secondary)
        }
    }
}

extension ProductView where Icon == EmptyView, PlaceholderIcon == EmptyView {
    public init(id: String, prefersPromotionalIcon: Bool = false) { self.id = id; given = nil; icon = nil }
    public init(_ product: Product, prefersPromotionalIcon: Bool = false) { id = product.id; given = product; icon = nil }
}

// MARK: - StoreView

public struct StoreView<Icon: View, PlaceholderIcon: View>: View {
    let ids: [String]
    let icon: ((Product) -> Icon)?
    @Environment(\.self) private var env
    @Environment(\.dismiss) private var dismiss

    public init<C: Collection>(ids: C, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping (Product) -> Icon,
                               @ViewBuilder placeholderIcon: @escaping () -> PlaceholderIcon) where C.Element == String {
        self.ids = Array(ids); self.icon = icon
    }
    public init(products: [Product], prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping (Product) -> Icon) where PlaceholderIcon == EmptyView {
        ids = products.map { $0.id }; self.icon = icon
    }

    public var body: some View {
        let cfg = _SKConfig.load()
        let products = ids.compactMap { cfg.item($0) }.map(Product.init)
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(products.enumerated()), id: \.element.id) { i, p in
                    if i > 0 { Rectangle().fill(Color(uiColor: .separator)).frame(height: 0.5).padding(.leading, 80) }
                    Group {
                        if let icon { ProductView(p) { icon(p) } } else { ProductView(p) }
                    }
                    .padding(.horizontal, 16).padding(.vertical, 12)
                }
                if products.isEmpty { Text(verbatim: "No products").foregroundStyle(.secondary).padding(16) }
                _SKStoreFooter(restoreDefault: false)
            }
        }
    }
}
extension StoreView where Icon == EmptyView, PlaceholderIcon == EmptyView {
    public init<C: Collection>(ids: C, prefersPromotionalIcon: Bool = false) where C.Element == String { self.ids = Array(ids); icon = nil }
    public init(products: [Product], prefersPromotionalIcon: Bool = false) { ids = products.map { $0.id }; icon = nil }
}

struct _SKStoreFooter: View {
    let restoreDefault: Bool
    @Environment(\.self) private var env
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        let b = env._skButtons
        let restore = b["restorePurchases"].map { $0 == .visible } ?? restoreDefault
        let redeem = b["redeemCode"] == .visible
        let cancel = b["cancellation"] == .visible
        VStack(spacing: 10) {
            if restore {
                Button("Restore Purchases") { Task { try? await AppStore.sync(); NSLog("isim StoreKit: restore purchases (store view)") } }
                    .accessibilityIdentifier("sk-store-restore")
            }
            if redeem { Button("Redeem Code") { Task { @MainActor in await _SKSheets.redeemCode() } }.accessibilityIdentifier("sk-store-redeem") }
            if cancel { Button("Cancel") { dismiss() }.accessibilityIdentifier("sk-store-cancel") }
            Text(verbatim: "[Environment: isim StoreKit testing]").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .font(.system(size: 15))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
}

// MARK: - SubscriptionStoreView

public struct SubscriptionStoreView<MarketingContent: View>: View {
    let groupID: String?
    let productIDs: [String]
    let marketing: (() -> MarketingContent)?
    @Environment(\.self) private var env
    @State private var selected: String?
    @State private var version = 0

    public init(groupID: String, @ViewBuilder marketingContent: @escaping () -> MarketingContent) { self.groupID = groupID; productIDs = []; marketing = marketingContent }
    public init<C: Collection>(productIDs: C, @ViewBuilder marketingContent: @escaping () -> MarketingContent) where C.Element == String {
        groupID = nil; self.productIDs = Array(productIDs); marketing = marketingContent
    }
    public init(subscriptions: [Product], @ViewBuilder marketingContent: @escaping () -> MarketingContent) {
        groupID = nil; productIDs = subscriptions.map { $0.id }; marketing = marketingContent
    }

    public var body: some View {
        let cfg = _SKConfig.load()
        let plans = (groupID.map { g in cfg.items.filter { $0.groupID == g } } ?? productIDs.compactMap { cfg.item($0) })
            .filter { $0.type == .autoRenewable }.sorted { ($0.groupLevel, $0.price) < ($1.groupLevel, $1.price) }
        let group = groupID ?? plans.first?.groupID ?? ""
        let current = _SKLedger.shared.entitlements().first { $0.groupID == group }
        let eligible = !_SKLedger.shared.everSubscribed(group: group)
        let choice = selected ?? current?.productID ?? plans.first?.id
        let chosen = plans.first { $0.id == choice }
        ScrollView {
            VStack(spacing: 16) {
                if let marketing { marketing() } else {
                    VStack(spacing: 8) {
                        _SKAppIcon(size: 72)
                        Text(verbatim: cfg.groups[group] ?? _SKSheets.appName).font(.system(size: 26, weight: .bold))
                        Text(verbatim: "Choose a plan").font(.system(size: 15)).foregroundStyle(.secondary)
                    }
                    .padding(.top, 24)
                }
                VStack(spacing: 10) {
                    ForEach(plans, id: \.id) { p in
                        Button { selected = p.id } label: { planRow(p, chosen: p.id == choice, current: current?.productID == p.id, eligible: eligible) }
                            .accessibilityIdentifier("sk-plan-\(p.id)")
                    }
                }
                if let chosen {
                    let isCurrent = current?.productID == chosen.id
                    let free = eligible && chosen.intro?.offer.paymentMode == .freeTrial
                    Button {
                        Task { @MainActor in await _skBuy(Product(chosen), env); version += 1 }
                    } label: {
                        Text(verbatim: isCurrent ? "Current Plan" : free ? "Try It Free" : current == nil ? "Subscribe" : "Change Plan")
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 50)
                            .background(isCurrent ? Color(uiColor: .systemGray3) : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(isCurrent)
                    .accessibilityIdentifier("sk-subscribe")
                    Text(verbatim: termsLine(chosen, eligible: eligible)).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
                _SKStoreFooter(restoreDefault: true)
            }
            .padding(.horizontal, 20)
            .id(version)
        }
    }

    func termsLine(_ p: _SKItem, eligible: Bool) -> String {
        let base = _SKSheets.pricePerPeriod(p)
        if eligible, let o = p.intro?.offer { return "\(o.summary), then \(base). Auto-renews until canceled." }
        return "\(base). Auto-renews until canceled."
    }

    func planRow(_ p: _SKItem, chosen: Bool, current: Bool, eligible: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: chosen ? "checkmark.circle.fill" : "circle").font(.system(size: 22))
                .foregroundStyle(chosen ? Color.accentColor : Color(uiColor: .tertiaryLabel))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: p.name).font(.system(size: 16, weight: .semibold)).foregroundStyle(.primary)
                Text(verbatim: _SKSheets.pricePerPeriod(p)).font(.system(size: 14)).foregroundStyle(.secondary)
                if eligible, let o = p.intro?.offer {
                    Text(verbatim: o.summary).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.accentColor)
                }
            }
            Spacer()
            if current { Text(verbatim: "Current").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(chosen ? Color.accentColor : Color.clear, lineWidth: 2))
    }
}
extension SubscriptionStoreView where MarketingContent == EmptyView {
    public init(groupID: String) { self.groupID = groupID; productIDs = []; marketing = nil }
    public init<C: Collection>(productIDs: C) where C.Element == String { groupID = nil; self.productIDs = Array(productIDs); marketing = nil }
    public init(subscriptions: [Product]) { groupID = nil; productIDs = subscriptions.map { $0.id }; marketing = nil }
}
