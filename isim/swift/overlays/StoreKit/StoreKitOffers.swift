// isim StoreKit: offers around the store — SubscriptionOfferView (iOS 26), promoted in-app purchases' order and
// visibility (Product.PromotionInfo, iOS 16.4) and purchases started on the App Store (PurchaseIntent, iOS 16.4; and
// StoreKit 1's paymentQueue(_:shouldAddStorePayment:for:)). Self-authored, iOS API names. Adapted: promotion settings
// are kept with the app's local StoreKit data; purchase intents come from `isim storekit <app> purchase-intent`, which
// stands in for the customer tapping a promoted purchase on the App Store.
import SwiftUI

// MARK: - task states and icons

/// What a product icon closure gets: the promotional icon as it loads (isim's products have none).
public enum ProductIconPhase {
    case loading
    case success(Image)
    case unavailable
    case failure(any Error)
    public var promotionalIcon: Image? { if case .success(let i) = self { return i }; return nil }
    public var error: (any Error)? { if case .failure(let e) = self { return e }; return nil }
}

extension Product {
    /// Loading products for a view: loading, then the products found and the IDs that were not.
    public enum CollectionTaskState {
        case loading
        case failure(any Error)
        case success(_ products: [Product], unavailable: [Product.ID])
        public var products: [Product]? { if case .success(let p, _) = self { return p }; return nil }
        public var unavailableProductIDs: [Product.ID]? { if case .success(_, let u) = self { return u }; return nil }
    }
}

// MARK: - SubscriptionOfferView

/// What a SubscriptionOfferViewStyle draws: the plan the view merchandises, its offer and the subscribe action.
public struct SubscriptionOfferViewStyleConfiguration {
    /// The view's icon: the app's custom icon, or the app icon / a placeholder.
    @MainActor public struct Icon: View {
        let view: AnyView
        public var body: some View { view }
    }
    public let activeOffer: Product.SubscriptionOffer?
    public let icon: Icon
    public let state: Product.CollectionTaskState
    public let subscriptionStatus: [Product.SubscriptionInfo.Status]
    public var subscriptionGroupDisplayName: String
    public var subscriptions: [Product]? { state.products }
    /// the plan the view shows (nil when the customer has nothing left to see: already on it, or no plan matches)
    public var visibleSubscription: Product?
    let _subscribe: @MainActor () -> Void
    let _details: @MainActor () -> Void
    @MainActor public func subscribe() { _subscribe() }
    /// shows the plan's details (isim: the subscription store sheet for its group)
    @MainActor public func displayDetails() { _details() }
}

@MainActor public protocol SubscriptionOfferViewStyle {
    associatedtype Body: View
    typealias Configuration = SubscriptionOfferViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Configuration) -> Body
}
public struct AutomaticSubscriptionOfferViewStyle: SubscriptionOfferViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _SKOfferCard(configuration: configuration, compact: false) }
}
public struct CompactSubscriptionOfferViewStyle: SubscriptionOfferViewStyle {
    public init() {}
    public func makeBody(configuration: Configuration) -> some View { _SKOfferCard(configuration: configuration, compact: true) }
}
extension SubscriptionOfferViewStyle where Self == AutomaticSubscriptionOfferViewStyle { public static var automatic: Self { .init() } }
extension SubscriptionOfferViewStyle where Self == CompactSubscriptionOfferViewStyle { public static var compact: Self { .init() } }

struct _SKOfferStyleKey: EnvironmentKey { static var defaultValue: (@MainActor (SubscriptionOfferViewStyleConfiguration) -> AnyView)? { nil } }
extension EnvironmentValues {
    var _skOfferStyle: (@MainActor (SubscriptionOfferViewStyleConfiguration) -> AnyView)? { get { self[_SKOfferStyleKey.self] } set { self[_SKOfferStyleKey.self] = newValue } }
}
extension View {
    public func subscriptionOfferViewStyle<S: SubscriptionOfferViewStyle>(_ style: S) -> some View {
        environment(\._skOfferStyle, { c in AnyView(style.makeBody(configuration: c)) })
    }
}

/// Merchandises one subscription plan with its offer (iOS 26): the plan picked from a group by its relationship to the
/// customer's current plan (an upgrade, say), or a given plan. Tapping it subscribes.
public struct SubscriptionOfferView<Icon: View, PlaceholderIcon: View>: View {
    let groupID: String?
    let productID: Product.ID?
    let relationship: Product.SubscriptionRelationship
    let icon: ((ProductIconPhase) -> Icon)?
    let placeholder: (() -> PlaceholderIcon)?
    let useAppIcon: Bool
    let given: SubscriptionOfferViewStyleConfiguration?
    @Environment(\.self) private var env
    @State private var version = 0
    @State private var details = false

    init(groupID: String?, productID: Product.ID?, relationship: Product.SubscriptionRelationship = .all, icon: ((ProductIconPhase) -> Icon)?,
         placeholder: (() -> PlaceholderIcon)?, useAppIcon: Bool, configuration: SubscriptionOfferViewStyleConfiguration? = nil) {
        self.groupID = groupID; self.productID = productID; self.relationship = relationship; self.icon = icon
        self.placeholder = placeholder; self.useAppIcon = useAppIcon; given = configuration
    }
    /// draws a style's configuration (inside a custom SubscriptionOfferViewStyle)
    public init(_ configuration: SubscriptionOfferViewStyleConfiguration) where Icon == SubscriptionOfferViewStyleConfiguration.Icon, PlaceholderIcon == EmptyView {
        self.init(groupID: nil, productID: nil, icon: nil, placeholder: nil, useAppIcon: false, configuration: configuration)
    }

    public var body: some View {
        let c = given ?? configuration()
        Group {
            if let custom = env._skOfferStyle, given == nil { custom(c) } else { _SKOfferCard(configuration: c, compact: false) }
        }
        .id(version)
        .sheet(isPresented: $details) {
            if let g = c.visibleSubscription?.subscription?.subscriptionGroupID { SubscriptionStoreView(groupID: g) }
        }
    }

    func configuration() -> SubscriptionOfferViewStyleConfiguration {
        let cfg = _SKConfig.load()
        let ids = productID.map { [$0] } ?? []
        let group = groupID ?? productID.flatMap { cfg.item($0)?.groupID } ?? ""
        let current = _SKLedger.shared.entitlements().first { $0.groupID == group }
        let plans = (groupID.map { g in cfg.items.filter { $0.groupID == g } } ?? ids.compactMap { cfg.item($0) })
            .sorted { ($0.groupLevel, $0.price) < ($1.groupLevel, $1.price) }
        // a group's view shows the first plan of the relationship that is not the current one
        let visible = productID != nil ? plans.first : plans.first { $0.id != current?.productID && relationship.shows($0, current: current?.productID, cfg: cfg) }
        let ever = !group.isEmpty && _SKLedger.shared.everSubscribed(group: group)
        let offer: Product.SubscriptionOffer? = visible.flatMap { p in
            if !ever, let i = p.intro?.offer { return i }
            if ever && current == nil && _skOSMajor() >= 18 { return p.winBacks.first?.offer }
            return nil
        }
        let products = plans.map(Product.init)
        let missing = ids.filter { cfg.item($0) == nil }
        let iconView: AnyView = {
            if let icon { return AnyView(icon(.unavailable)) }
            if useAppIcon { return AnyView(_SKAppIcon(size: 56)) }
            if let placeholder { return AnyView(placeholder()) }
            return AnyView(visible.map { _SKProductIcon(product: Product($0), size: 56) })
        }()
        let env = self.env, bump = { version += 1 }, show = { details = true }
        return SubscriptionOfferViewStyleConfiguration(
            activeOffer: offer, icon: .init(view: iconView), state: .success(products, unavailable: missing), subscriptionStatus: [],
            subscriptionGroupDisplayName: cfg.groups[group] ?? "", visibleSubscription: visible.map(Product.init),
            _subscribe: {
                guard let p = visible else { return }
                Task { @MainActor in
                    let options: Set<Product.PurchaseOption> = offer?.type == ._winBack ? [._winBackOffer(offer!)] : []
                    NSLog("isim StoreKit: subscription offer view: subscribing to %@", p.id)
                    await _skBuy(Product(p), env, options: options); bump()
                }
            },
            _details: show)
    }
}

extension SubscriptionOfferView where Icon == EmptyView, PlaceholderIcon == EmptyView {
    public init(groupID: String, visibleRelationship: Product.SubscriptionRelationship) {
        self.init(groupID: groupID, productID: nil, relationship: visibleRelationship, icon: nil, placeholder: nil, useAppIcon: false)
    }
    public init(groupID: String, visibleRelationship: Product.SubscriptionRelationship, useAppIcon: Bool) {
        self.init(groupID: groupID, productID: nil, relationship: visibleRelationship, icon: nil, placeholder: nil, useAppIcon: useAppIcon)
    }
    public init(id: Product.ID, prefersPromotionalIcon: Bool = false) {
        self.init(groupID: nil, productID: id, icon: nil, placeholder: nil, useAppIcon: false)
    }
    public init(_ product: Product, prefersPromotionalIcon: Bool = false) {
        self.init(groupID: nil, productID: product.id, icon: nil, placeholder: nil, useAppIcon: false)
    }
}
extension SubscriptionOfferView where PlaceholderIcon == EmptyView {
    public init(groupID: String, visibleRelationship: Product.SubscriptionRelationship, @ViewBuilder icon: @escaping () -> Icon) {
        self.init(groupID: groupID, productID: nil, relationship: visibleRelationship, icon: { _ in icon() }, placeholder: nil, useAppIcon: false)
    }
    public init(id: Product.ID, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon) {
        self.init(groupID: nil, productID: id, icon: { _ in icon() }, placeholder: nil, useAppIcon: false)
    }
    public init(_ product: Product, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon) {
        self.init(groupID: nil, productID: product.id, icon: { _ in icon() }, placeholder: nil, useAppIcon: false)
    }
    public init(_ product: Product, @ViewBuilder icon: @escaping (ProductIconPhase) -> Icon) {
        self.init(groupID: nil, productID: product.id, icon: icon, placeholder: nil, useAppIcon: false)
    }
}
extension SubscriptionOfferView {
    public init(groupID: String, visibleRelationship: Product.SubscriptionRelationship, @ViewBuilder icon: @escaping () -> Icon,
                @ViewBuilder placeholderIcon: @escaping () -> PlaceholderIcon) {
        self.init(groupID: groupID, productID: nil, relationship: visibleRelationship, icon: { _ in icon() }, placeholder: placeholderIcon, useAppIcon: false)
    }
    public init(id: Product.ID, prefersPromotionalIcon: Bool = false, @ViewBuilder icon: @escaping () -> Icon,
                @ViewBuilder placeholderIcon: @escaping () -> PlaceholderIcon) {
        self.init(groupID: nil, productID: id, icon: { _ in icon() }, placeholder: placeholderIcon, useAppIcon: false)
    }
    public init(id: Product.ID, @ViewBuilder icon: @escaping (ProductIconPhase) -> Icon, @ViewBuilder placeholderIcon: @escaping () -> PlaceholderIcon) {
        self.init(groupID: nil, productID: id, icon: icon, placeholder: placeholderIcon, useAppIcon: false)
    }
}

/// the built-in offer card: icon, plan, offer or price, and a subscribe button
struct _SKOfferCard: View {
    let configuration: SubscriptionOfferViewStyleConfiguration
    let compact: Bool
    var body: some View {
        if let p = configuration.visibleSubscription {
            let item = _SKConfig.load().item(p.id)
            let price = item.map(_SKSheets.pricePerPeriod) ?? p.displayPrice
            HStack(spacing: 12) {
                if !compact { configuration.icon.frame(width: 56, height: 56) }
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: p.displayName).font(.system(size: compact ? 15 : 17, weight: .semibold)).foregroundStyle(.primary)
                    if let o = configuration.activeOffer {
                        Text(verbatim: "\(o.summary), then \(price)").font(.system(size: 13)).foregroundStyle(.secondary)
                            .accessibilityIdentifier("sk-offer-view-offer")
                    } else {
                        Text(verbatim: price).font(.system(size: 13)).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 8)
                Button { configuration.subscribe() } label: {
                    Text(verbatim: configuration.activeOffer?.paymentMode == .freeTrial ? "Try Free" : "Subscribe")
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).padding(.vertical, 7)
                        .background(Color.accentColor, in: Capsule())
                }
                .accessibilityIdentifier("sk-offer-view-subscribe")
            }
            .padding(compact ? 10 : 14)
            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16))
            .contentShape(Rectangle())
            .onTapGesture { configuration.displayDetails() }
            .accessibilityIdentifier("sk-offer-view")
        }
    }
}

// MARK: - promoted in-app purchases

extension Product {
    /// A promoted in-app purchase's place and visibility on the App Store, as the app overrides them for this customer.
    public struct PromotionInfo: Hashable, Sendable {
        public enum Visibility: Hashable, Sendable { case appStoreConnectDefault, visible, hidden }
        public let productID: Product.ID
        public var visibility: Visibility
        public init(productID: Product.ID, visibility: Visibility) { self.productID = productID; self.visibility = visibility }

        /// the overridden order, with each product's visibility (empty until the app sets an order)
        public static var currentOrder: [PromotionInfo] {
            get async throws { let s = _SKPromotions.read(); return s.order.map { PromotionInfo(productID: $0, visibility: s.visibility($0)) } }
        }
        public static func updateProductOrder<C: Collection>(byID productIDs: C) async throws where C.Element == String {
            try _SKPromotions.update { $0.order = Array(productIDs) }
        }
        public static func updateProductVisibility(_ visibility: Visibility, for productID: Product.ID) async throws {
            try _SKPromotions.update { $0.set(visibility, productID) }
        }
        /// saves this product's visibility
        public func update() async throws { try _SKPromotions.update { $0.set(visibility, productID) } }
        /// the products' order (as given) and their visibilities
        public static func updateAll<C: Collection>(_ promotions: C) async throws where C.Element == PromotionInfo {
            try _SKPromotions.update { s in
                s.order = promotions.map { $0.productID }
                for p in promotions { s.set(p.visibility, p.productID) }
            }
        }
    }
}

/// promotion settings, next to the app's StoreKit ledger (`isim storekit <app> promotions` lists them)
enum _SKPromotions {
    struct State { var order: [String]; var hidden: [String: String]
        func visibility(_ id: String) -> Product.PromotionInfo.Visibility {
            switch hidden[id] { case "visible": return .visible; case "hidden": return .hidden; default: return .appStoreConnectDefault }
        }
        mutating func set(_ v: Product.PromotionInfo.Visibility, _ id: String) {
            switch v { case .visible: hidden[id] = "visible"; case .hidden: hidden[id] = "hidden"; case .appStoreConnectDefault: hidden[id] = nil }
        }
    }
    static var path: String { ((_SKLedger.defaultPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent("promotions.json") }
    static func read() -> State {
        let d = FileManager.default.contents(atPath: path).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        return State(order: d["order"] as? [String] ?? [], hidden: d["visibility"] as? [String: String] ?? [:])
    }
    static func update(_ f: (inout State) -> Void) throws {
        var s = read(); f(&s)
        let cfg = _SKConfig.load()
        if let bad = s.order.first(where: { cfg.item($0) == nil }) ?? s.hidden.keys.first(where: { cfg.item($0) == nil }) {
            NSLog("isim StoreKit: promotion: unknown product %@", bad)
            throw StoreKitError.unknown
        }
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: ["order": s.order, "visibility": s.hidden], options: [.sortedKeys])
        try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        NSLog("isim StoreKit: promotion order %@", s.order.joined(separator: ","))
    }
}

// MARK: - purchase intents

/// A purchase the customer started on the App Store (a promoted in-app purchase, or a win-back offer), for the app to
/// complete with `product.purchase()`.
public struct PurchaseIntent: Identifiable, Sendable, Equatable {
    public let product: Product
    @available(iOS 18.0, *) public var offer: Product.SubscriptionOffer? { _offer }
    let _offer: Product.SubscriptionOffer?
    public var id: Product.ID { product.id }
    public static func == (a: PurchaseIntent, b: PurchaseIntent) -> Bool { a.product == b.product && a._offer?.id == b._offer?.id }

    /// The intents as the customer starts them (and those started before the app listened).
    public struct PurchaseIntents: AsyncSequence, Sendable {
        public typealias Element = PurchaseIntent
        public struct AsyncIterator: AsyncIteratorProtocol {
            var base: AsyncStream<PurchaseIntent>.Iterator
            public mutating func next() async -> PurchaseIntent? { await base.next() }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(base: _SKIntents.stream().makeAsyncIterator()) }
    }
    public static var intents: PurchaseIntents { _SKIntents.start(); return PurchaseIntents() }
}

/// purchase intents from `isim storekit <app> purchase-intent PRODUCT [OFFER]`: files next to the ledger, picked up
/// every half second once the app listens (PurchaseIntent.intents) or has a StoreKit 1 observer
enum _SKIntents {
    nonisolated(unsafe) static var continuations: [AsyncStream<PurchaseIntent>.Continuation] = []
    nonisolated(unsafe) static var timer: DispatchSourceTimer?
    static let lock = NSLock()
    static var dir: String { ((_SKLedger.defaultPath as NSString).deletingLastPathComponent as NSString).appendingPathComponent("intents") }
    static func stream() -> AsyncStream<PurchaseIntent> {
        AsyncStream { c in lock.lock(); continuations.append(c); lock.unlock() }
    }
    static func start() {
        lock.lock(); defer { lock.unlock() }
        guard timer == nil else { return }
        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + 0.1, repeating: .milliseconds(500))
        t.setEventHandler { poll() }
        timer = t
        t.resume()
    }
    static func poll() {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { return }
        for f in files.sorted() where f.hasSuffix(".json") {
            let p = (dir as NSString).appendingPathComponent(f)
            lock.lock()
            let listeners = continuations.count
            lock.unlock()
            let sk1 = SKPaymentQueue.default().transactionObservers
            guard listeners > 0 || !sk1.isEmpty else { return }       // kept until the app listens
            guard let d = fm.contents(atPath: p), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] else { try? fm.removeItem(atPath: p); continue }
            try? fm.removeItem(atPath: p)
            let cfg = _SKConfig.load()
            guard let id = j["productID"] as? String, let item = cfg.item(id) else {
                NSLog("isim StoreKit: purchase intent for unknown product %@", j["productID"] as? String ?? "?")
                continue
            }
            let offerID = j["offerID"] as? String
            let offer = offerID.flatMap { o in (item.promos + item.winBacks).first { $0.offer.id == o || $0.keys.contains(o.lowercased()) }?.offer }
            NSLog("isim StoreKit: purchase intent for %@%@", id, offer.map { " with offer \($0.id ?? "")" } ?? "")
            let intent = PurchaseIntent(product: Product(item), _offer: offer)
            lock.lock()
            let cs = continuations
            lock.unlock()
            for c in cs { c.yield(intent) }
            // StoreKit 1: the observer decides whether the payment goes on the queue now
            let q = SKPaymentQueue.default(), product = SKProduct(item)
            for o in sk1 where o.paymentQueue(q, shouldAddStorePayment: SKPayment(product: product), for: product) {
                q.add(SKPayment(product: product))
                break
            }
        }
    }
}
