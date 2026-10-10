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
struct _SKStyleBodyKey: EnvironmentKey { static var defaultValue: (@MainActor (ProductViewStyleConfiguration) -> AnyView)? { nil } }
struct _SKControlKey: EnvironmentKey { static var defaultValue: String { "automatic" } }
struct _SKButtonLabelKey: EnvironmentKey { static var defaultValue: SubscriptionStoreButtonLabel { .automatic } }
struct _SKPoliciesKey: EnvironmentKey { static var defaultValue: [String: _SKPolicyDestination] { [:] } }
struct _SKOfferSelectorKey: EnvironmentKey {
    static var defaultValue: ((Product, Product.SubscriptionInfo, [Product.SubscriptionOffer]) -> Product.SubscriptionOffer?)? { nil }
}
/// where a policy link goes: a URL (opened like a link) or a view (shown in a sheet)
struct _SKPolicyDestination { var url: URL?; var view: (() -> AnyView)? }
extension EnvironmentValues {
    public var purchase: PurchaseAction { get { self[_SKPurchaseKey.self] } set { self[_SKPurchaseKey.self] = newValue } }
    var _skStyle: Int { get { self[_SKStyleKey.self] } set { self[_SKStyleKey.self] = newValue } }
    var _skButtons: [String: Visibility] { get { self[_SKButtonsKey.self] } set { self[_SKButtonsKey.self] = newValue } }
    var _skStart: ((Product) async -> Void)? { get { self[_SKStartKey.self] } set { self[_SKStartKey.self] = newValue } }
    var _skCompletion: ((Product, Result<Product.PurchaseResult, Error>) async -> Void)? { get { self[_SKCompletionKey.self] } set { self[_SKCompletionKey.self] = newValue } }
    var _skStyleBody: (@MainActor (ProductViewStyleConfiguration) -> AnyView)? { get { self[_SKStyleBodyKey.self] } set { self[_SKStyleBodyKey.self] = newValue } }
    var _skControl: String { get { self[_SKControlKey.self] } set { self[_SKControlKey.self] = newValue } }
    var _skButtonLabel: SubscriptionStoreButtonLabel { get { self[_SKButtonLabelKey.self] } set { self[_SKButtonLabelKey.self] = newValue } }
    var _skPolicies: [String: _SKPolicyDestination] { get { self[_SKPoliciesKey.self] } set { self[_SKPoliciesKey.self] = newValue } }
    var _skOfferSelector: ((Product, Product.SubscriptionInfo, [Product.SubscriptionOffer]) -> Product.SubscriptionOffer?)? {
        get { self[_SKOfferSelectorKey.self] } set { self[_SKOfferSelectorKey.self] = newValue }
    }
}

/// What a ProductViewStyle draws: the product (once loaded), its icon, whether the customer owns it, and the purchase.
public struct ProductViewStyleConfiguration {
    public enum State { case loading, success(Product), unavailable, failure(Error) }
    public struct Icon: View {
        let content: AnyView
        public var body: some View { content }
    }
    public let productID: String
    public let state: State
    public let icon: Icon
    public let hasCurrentEntitlement: Bool
    let buy: @MainActor () -> Void
    public var product: Product? { if case .success(let p) = state { return p }; return nil }
    /// starts the purchase, as the built-in styles' price button does
    @MainActor public func purchase() { buy() }
}

public protocol ProductViewStyle {
    associatedtype Body: View
    typealias Configuration = ProductViewStyleConfiguration
    @MainActor @ViewBuilder func makeBody(configuration: Configuration) -> Body
    var _skStyle: Int { get }
}
extension ProductViewStyle {
    /// an app's own style (its makeBody draws the product view)
    public var _skStyle: Int { -1 }
}
public struct AutomaticProductViewStyle: ProductViewStyle {
    public init() {}; public var _skStyle: Int { 0 }
    public func makeBody(configuration: Configuration) -> some View { _SKProductContent(configuration: configuration, style: 0) }
}
public struct CompactProductViewStyle: ProductViewStyle {
    public init() {}; public var _skStyle: Int { 1 }
    public func makeBody(configuration: Configuration) -> some View { _SKProductContent(configuration: configuration, style: 1) }
}
public struct RegularProductViewStyle: ProductViewStyle {
    public init() {}; public var _skStyle: Int { 0 }
    public func makeBody(configuration: Configuration) -> some View { _SKProductContent(configuration: configuration, style: 0) }
}
public struct LargeProductViewStyle: ProductViewStyle {
    public init() {}; public var _skStyle: Int { 2 }
    public func makeBody(configuration: Configuration) -> some View { _SKProductContent(configuration: configuration, style: 2) }
}
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
/// How SubscriptionStoreView lets the customer pick a plan: a picker (rows with a checkmark and one subscribe button),
/// a prominent picker (larger rows), a compact picker (side-by-side tiles) or buttons (one subscribe button per plan).
public protocol SubscriptionStoreControlStyle { var _skControl: String { get } }
extension SubscriptionStoreControlStyle { public var _skControl: String { "automatic" } }
public struct AutomaticSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {}; public var _skControl: String { "automatic" } }
public struct PickerSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {}; public var _skControl: String { "picker" } }
public struct ButtonsSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {}; public var _skControl: String { "buttons" } }
public struct PrefersProminentPickerSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {}; public var _skControl: String { "prominentPicker" } }
public struct CompactPickerSubscriptionStoreControlStyle: SubscriptionStoreControlStyle { public init() {}; public var _skControl: String { "compactPicker" } }
extension SubscriptionStoreControlStyle where Self == AutomaticSubscriptionStoreControlStyle { public static var automatic: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == PickerSubscriptionStoreControlStyle { public static var picker: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == ButtonsSubscriptionStoreControlStyle { public static var buttons: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == PrefersProminentPickerSubscriptionStoreControlStyle { public static var prominentPicker: Self { .init() } }
extension SubscriptionStoreControlStyle where Self == CompactPickerSubscriptionStoreControlStyle { public static var compactPicker: Self { .init() } }

/// The subscription store's policy links (shown with storeButton(.visible, for: .policies)).
public struct SubscriptionStorePolicyKind: Hashable, Sendable {
    let name: String
    public static let termsOfService = SubscriptionStorePolicyKind(name: "termsOfService")
    public static let privacyPolicy = SubscriptionStorePolicyKind(name: "privacyPolicy")
}
public enum SubscriptionStoreButtonLabel: Hashable, Sendable { case automatic, action, displayName, price, singleLine, multiline }

@MainActor func _skCustomBody<S: ProductViewStyle>(_ style: S, _ c: ProductViewStyleConfiguration) -> AnyView {
    let body: S.Body = style.makeBody(configuration: c)
    return AnyView(body)
}

extension View {
    public func productViewStyle<S: ProductViewStyle>(_ style: S) -> some View {
        let n: Int = style._skStyle
        var custom: (@MainActor (ProductViewStyleConfiguration) -> AnyView)?
        if n < 0 {
            custom = { @MainActor (c: ProductViewStyleConfiguration) -> AnyView in _skCustomBody(style, c) }
        }
        return environment(\EnvironmentValues._skStyle, n).environment(\EnvironmentValues._skStyleBody, custom)
    }
    public func storeButton(_ visibility: Visibility, for buttonKinds: StoreButtonKind...) -> some View {
        modifier(_SKStoreButtons(visibility: visibility, kinds: buttonKinds.map { $0.name }))
    }
    public func onInAppPurchaseStart(perform action: ((Product) async -> Void)?) -> some View { environment(\._skStart, action) }
    public func onInAppPurchaseCompletion(perform action: ((Product, Result<Product.PurchaseResult, Error>) async -> Void)?) -> some View {
        environment(\._skCompletion, action)
    }
    public func subscriptionStoreControlStyle<S: SubscriptionStoreControlStyle>(_ style: S) -> some View { environment(\._skControl, style._skControl) }
    public func subscriptionStoreButtonLabel(_ label: SubscriptionStoreButtonLabel) -> some View { environment(\._skButtonLabel, label) }
    public func subscriptionStorePolicyDestination(url: URL, for policy: Any) -> some View {
        modifier(_SKPolicyModifier(kind: (policy as? SubscriptionStorePolicyKind)?.name ?? "\(policy)", destination: _SKPolicyDestination(url: url, view: nil)))
    }
    public func subscriptionStorePolicyDestination(url: URL, for policy: SubscriptionStorePolicyKind) -> some View {
        modifier(_SKPolicyModifier(kind: policy.name, destination: _SKPolicyDestination(url: url, view: nil)))
    }
    public func subscriptionStorePolicyDestination<Destination: View>(for policy: SubscriptionStorePolicyKind, @ViewBuilder destination: @escaping () -> Destination) -> some View {
        modifier(_SKPolicyModifier(kind: policy.name, destination: _SKPolicyDestination(url: nil, view: { AnyView(destination()) })))
    }
    /// Chooses the offer SubscriptionStoreView and ProductView show and buy for a subscription (iOS 18): from the
    /// customer's eligible offers (introductory, or win-back for a lapsed subscriber); nil shows none.
    public func preferredSubscriptionOffer(_ offerSelector: @escaping (Product, Product.SubscriptionInfo, [Product.SubscriptionOffer]) -> Product.SubscriptionOffer?) -> some View {
        environment(\._skOfferSelector, offerSelector)
    }
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

/// The built-in product view styles (compact / regular / large). `prefersPromotionalIcon` falls back to the icon, as in
/// Xcode's local testing: promotional images come from App Store Connect, and .storekit files have none.
struct _SKProductContent: View {
    let configuration: ProductViewStyleConfiguration, style: Int
    var body: some View {
        if let p = configuration.product {
            let owned = configuration.hasCurrentEntitlement
            let buy = { configuration.purchase() }
            if style == 2 {
                VStack(spacing: 10) {
                    configuration.icon
                    Text(verbatim: p.displayName).font(.system(size: 22, weight: .bold))
                    Text(verbatim: p.description).font(.system(size: 15)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    _SKPriceButton(product: p, owned: owned, action: buy)
                }
                .frame(maxWidth: .infinity)
            } else if style == 1 {
                HStack(spacing: 10) {
                    Text(verbatim: p.displayName).font(.system(size: 16, weight: .semibold))
                    Spacer()
                    _SKPriceButton(product: p, owned: owned, action: buy)
                }
            } else {
                HStack(spacing: 12) {
                    configuration.icon
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: p.displayName).font(.system(size: 16, weight: .semibold))
                        Text(verbatim: p.description).font(.system(size: 13)).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    _SKPriceButton(product: p, owned: owned, action: buy)
                }
            }
        } else {
            Text(verbatim: "Product unavailable").foregroundStyle(.secondary)
        }
    }
}

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
        let p = product
        let style = env._skStyle
        let owned = p.map { p in p.type != .consumable && _SKLedger.shared.entitlements().contains { $0.productID == p.id } } ?? false
        let iconView: AnyView = p.map { p in icon.map { AnyView($0()) } ?? AnyView(_SKProductIcon(product: p, size: style == 2 ? 96 : 52)) } ?? AnyView(EmptyView())
        let env = self.env
        let bump = { version += 1 }
        let config = ProductViewStyleConfiguration(productID: id, state: p.map { .success($0) } ?? .unavailable, icon: .init(content: iconView),
                                                   hasCurrentEntitlement: owned, buy: { if let p { Task { @MainActor in await _skBuy(p, env); bump() } } })
        Group {
            if let custom = env._skStyleBody { custom(config) } else { _SKProductContent(configuration: config, style: style) }
        }
        .id(version)
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

struct _SKPolicyModifier: ViewModifier {
    let kind: String, destination: _SKPolicyDestination
    @Environment(\._skPolicies) var current
    func body(content: Content) -> some View {
        var merged = current
        merged[kind] = destination
        return content.environment(\._skPolicies, merged)
    }
}

/// Apple's standard license agreement: the terms of service when the app sets none
let _skStandardEULA = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

struct _SKStoreFooter: View {
    let restoreDefault: Bool
    @Environment(\.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var policySheet: String?
    var body: some View {
        let b = env._skButtons
        let restore = b["restorePurchases"].map { $0 == .visible } ?? restoreDefault
        let redeem = b["redeemCode"] == .visible
        let cancel = b["cancellation"] == .visible
        let policies = b["policies"] == .visible
        let privacy = env._skPolicies["privacyPolicy"]
        VStack(spacing: 10) {
            if restore {
                Button("Restore Purchases") { Task { try? await AppStore.sync(); NSLog("isim StoreKit: restore purchases (store view)") } }
                    .accessibilityIdentifier("sk-store-restore")
            }
            if redeem { Button("Redeem Code") { Task { @MainActor in await _SKSheets.redeemCode() } }.accessibilityIdentifier("sk-store-redeem") }
            if cancel { Button("Cancel") { dismiss() }.accessibilityIdentifier("sk-store-cancel") }
            if policies {
                HStack(spacing: 6) {
                    Button("Terms of Service") { open("termsOfService") }.accessibilityIdentifier("sk-policy-terms")
                    if privacy != nil {
                        Text(verbatim: "·").foregroundStyle(.secondary)
                        Button("Privacy Policy") { open("privacyPolicy") }.accessibilityIdentifier("sk-policy-privacy")
                    }
                }
                .font(.system(size: 13))
            }
            Text(verbatim: "[Environment: isim StoreKit testing]").font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .font(.system(size: 15))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .sheet(isPresented: Binding(get: { policySheet != nil }, set: { if !$0 { policySheet = nil } })) {
            if let k = policySheet, let v = env._skPolicies[k]?.view {
                NavigationStack {
                    v().toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { policySheet = nil }.accessibilityIdentifier("sk-policy-done") } }
                }
            }
        }
    }
    func open(_ kind: String) {
        let d = env._skPolicies[kind]
        if d?.view != nil { NSLog("isim StoreKit: policy %@: showing the app's view", kind); policySheet = kind; return }
        let url = d?.url ?? _skStandardEULA
        NSLog("isim StoreKit: policy %@: opening %@", kind, url.absoluteString)
        UIApplication.shared.open(url, options: [:], completionHandler: nil)
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

    /// the offer shown and bought for a plan: introductory (never subscribed) or win-back (lapsed, iOS 18), or the
    /// app's choice (preferredSubscriptionOffer)
    func offer(_ p: _SKItem, eligibleIntro: Bool, lapsed: Bool) -> Product.SubscriptionOffer? {
        var eligible: [Product.SubscriptionOffer] = []
        if eligibleIntro, let i = p.intro?.offer { eligible.append(i) }
        if lapsed, _skOSMajor() >= 18 { eligible += p.winBacks.map { $0.offer } }
        if let choose = env._skOfferSelector {
            let product = Product(p)
            guard let info = product.subscription else { return nil }
            return choose(product, info, eligible)
        }
        return eligible.first { $0.type == .winBack } ?? eligible.first
    }

    public var body: some View {
        let cfg = _SKConfig.load()
        let plans = (groupID.map { g in cfg.items.filter { $0.groupID == g } } ?? productIDs.compactMap { cfg.item($0) })
            .filter { $0.type == .autoRenewable }.sorted { ($0.groupLevel, $0.price) < ($1.groupLevel, $1.price) }
        let group = groupID ?? plans.first?.groupID ?? ""
        let current = _SKLedger.shared.entitlements().first { $0.groupID == group }
        let ever = _SKLedger.shared.everSubscribed(group: group)
        let lapsed = ever && current == nil
        let offers = Dictionary(plans.map { ($0.id, offer($0, eligibleIntro: !ever, lapsed: lapsed)) }, uniquingKeysWith: { a, _ in a })
        let choice = selected ?? current?.productID ?? plans.first?.id
        let chosen = plans.first { $0.id == choice }
        let control = env._skControl
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
                if control == "buttons" {
                    VStack(spacing: 10) {
                        ForEach(plans, id: \.id) { p in
                            subscribeButton(p, offer: offers[p.id] ?? nil, current: current).accessibilityIdentifier("sk-subscribe-\(p.id)")
                        }
                    }
                } else {
                    if control == "compactPicker" {
                        HStack(spacing: 8) {
                            ForEach(plans, id: \.id) { p in
                                Button { selected = p.id } label: { compactTile(p, chosen: p.id == choice, current: current?.productID == p.id) }
                                    .accessibilityIdentifier("sk-plan-\(p.id)")
                            }
                        }
                    } else {
                        VStack(spacing: control == "prominentPicker" ? 12 : 10) {
                            ForEach(plans, id: \.id) { p in
                                Button { selected = p.id } label: {
                                    planRow(p, chosen: p.id == choice, current: current?.productID == p.id, offer: offers[p.id] ?? nil, prominent: control == "prominentPicker")
                                }
                                .accessibilityIdentifier("sk-plan-\(p.id)")
                            }
                        }
                    }
                    if let chosen { subscribeButton(chosen, offer: offers[chosen.id] ?? nil, current: current).accessibilityIdentifier("sk-subscribe") }
                }
                if let chosen {
                    Text(verbatim: termsLine(chosen, offer: offers[chosen.id] ?? nil)).font(.system(size: 12)).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        .accessibilityIdentifier("sk-terms")
                }
                _SKStoreFooter(restoreDefault: true)
            }
            .padding(.horizontal, 20)
            .id(version)
        }
    }

    /// the subscribe button's label: the action, the plan's name or price, on one line or two
    func buttonText(_ p: _SKItem, offer: Product.SubscriptionOffer?, isCurrent: Bool, current: _SKTxn?) -> (String, String?) {
        let action = isCurrent ? "Current Plan" : offer?.paymentMode == .freeTrial ? "Try It Free" : offer?.type == .winBack ? "Resubscribe"
            : current == nil ? "Subscribe" : "Change Plan"
        let price = offer.map { "\($0.summary), then \(_SKSheets.pricePerPeriod(p))" } ?? _SKSheets.pricePerPeriod(p)
        switch env._skButtonLabel {
        case .displayName: return (p.name, nil)
        case .price: return (price, nil)
        case .singleLine: return ("\(action) · \(price)", nil)
        case .multiline: return (action, price)
        default: return (env._skControl == "buttons" ? "\(p.name) · \(_SKSheets.pricePerPeriod(p))" : action, nil)
        }
    }

    func subscribeButton(_ p: _SKItem, offer: Product.SubscriptionOffer?, current: _SKTxn?) -> some View {
        let isCurrent = current?.productID == p.id
        let (title, subtitle) = buttonText(p, offer: offer, isCurrent: isCurrent, current: current)
        let env = self.env
        return Button {
            Task { @MainActor in
                let options: Set<Product.PurchaseOption> = offer?.type == .winBack ? [.winBackOffer(offer!)] : []
                await _skBuy(Product(p), env, options: options); version += 1
            }
        } label: {
            VStack(spacing: 2) {
                Text(verbatim: title).font(.system(size: 17, weight: .semibold))
                if let subtitle { Text(verbatim: subtitle).font(.system(size: 13)) }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity).frame(minHeight: 50).padding(.vertical, subtitle == nil ? 0 : 4)
            .background(isCurrent ? Color(uiColor: .systemGray3) : Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
        }
        .disabled(isCurrent)
    }

    func termsLine(_ p: _SKItem, offer: Product.SubscriptionOffer?) -> String {
        let base = _SKSheets.pricePerPeriod(p)
        if let o = offer { return "\(o.summary), then \(base). Auto-renews until canceled." }
        return "\(base). Auto-renews until canceled."
    }

    func planRow(_ p: _SKItem, chosen: Bool, current: Bool, offer: Product.SubscriptionOffer?, prominent: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: chosen ? "checkmark.circle.fill" : "circle").font(.system(size: prominent ? 26 : 22))
                .foregroundStyle(chosen ? Color.accentColor : Color(uiColor: .tertiaryLabel))
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: p.name).font(.system(size: prominent ? 19 : 16, weight: .semibold)).foregroundStyle(.primary)
                Text(verbatim: _SKSheets.pricePerPeriod(p)).font(.system(size: prominent ? 16 : 14)).foregroundStyle(.secondary)
                if let o = offer {
                    Text(verbatim: o.summary).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.accentColor)
                        .accessibilityIdentifier("sk-offer-\(p.id)")
                }
            }
            Spacer()
            if current { Text(verbatim: "Current").font(.system(size: 12, weight: .semibold)).foregroundStyle(.secondary) }
        }
        .padding(prominent ? 18 : 14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: prominent ? 18 : 14))
        .overlay(RoundedRectangle(cornerRadius: prominent ? 18 : 14).stroke(chosen ? Color.accentColor : Color.clear, lineWidth: 2))
    }

    func compactTile(_ p: _SKItem, chosen: Bool, current: Bool) -> some View {
        VStack(spacing: 4) {
            Text(verbatim: p.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.primary).lineLimit(1)
            Text(verbatim: _SKSheets.pricePerPeriod(p)).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
            if current { Text(verbatim: "Current").font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary) }
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(chosen ? Color.accentColor : Color.clear, lineWidth: 2))
    }
}
extension SubscriptionStoreView where MarketingContent == EmptyView {
    public init(groupID: String) { self.groupID = groupID; productIDs = []; marketing = nil }
    public init<C: Collection>(productIDs: C) where C.Element == String { groupID = nil; self.productIDs = Array(productIDs); marketing = nil }
    public init(subscriptions: [Product]) { groupID = nil; productIDs = subscriptions.map { $0.id }; marketing = nil }
}
