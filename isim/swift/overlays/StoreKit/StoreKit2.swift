// isim StoreKit 2 (Product, Transaction, AppStore, AppTransaction): local StoreKit testing, like Xcode's.
// There is no App Store connection. Products come from the StoreKit configuration file that the
// project's scheme selects (`isim build` copies it into the bundle as isim-StoreKitConfiguration.storekit
// and records it under the Info.plist key ISIMStoreKitConfiguration). Purchases show a confirmation
// sheet, charge nothing, and are stored in the app's container (Library/isim/StoreKit/ledger.json).
// Transactions are always .verified, as in Xcode's local testing environment: nothing is signed by Apple
// (JWS representations are local and unsigned, "alg": "none").
//
// Auto-renewable subscriptions renew on an accelerated clock, like Xcode's StoreKit testing time rate:
// the .storekit settings "_timeRate" (SKTestSession.TimeRate order) or ISIM_STOREKIT_TIME_RATE, e.g.
// "monthlyRenewalEveryThirtySeconds", "oneRenewalEveryTenSeconds" or "month=5" (one month = 5 s).
// `isim storekit <app> ...` is the Transaction Manager: list, refund, expire, cancel, clear.
import UIKit

// MARK: - Subscription periods and offers

extension Product {
    public struct SubscriptionPeriod: Hashable, Sendable, CustomStringConvertible {
        public enum Unit: Int, Hashable, Sendable, CustomStringConvertible {
            case day, week, month, year
            public var localizedDescription: String { ["Day", "Week", "Month", "Year"][rawValue] }
            public var description: String { ["day", "week", "month", "year"][rawValue] }
        }
        public let unit: Unit
        public let value: Int
        public init(value: Int, unit: Unit) { self.value = value; self.unit = unit }
        public static let weekly = SubscriptionPeriod(value: 1, unit: .week)
        public static let monthly = SubscriptionPeriod(value: 1, unit: .month)
        public static let everyThreeMonths = SubscriptionPeriod(value: 3, unit: .month)
        public static let everySixMonths = SubscriptionPeriod(value: 6, unit: .month)
        public static let yearly = SubscriptionPeriod(value: 1, unit: .year)
        public var description: String { "\(value) \(unit)\(value == 1 ? "" : "s")" }
        /// "1 month", "2 weeks"
        public var localizedDescription: String { value == 1 ? "1 \(unit)" : "\(value) \(unit)s" }
        /// ISO 8601 durations as in .storekit files: P3D, P1W, P1M, P6M, P1Y
        init?(iso: String?) {
            guard let s = iso, s.hasPrefix("P"), s.count >= 3, let n = Int(s.dropFirst().dropLast()) else { return nil }
            switch s.last {
            case "D": self.init(value: n, unit: .day)
            case "W": self.init(value: n, unit: .week)
            case "M": self.init(value: n, unit: .month)
            case "Y": self.init(value: n, unit: .year)
            default: return nil
            }
        }
        /// days, for ordering and "same duration" crossgrades
        var approximateDays: Int { value * [1, 7, 30, 365][unit.rawValue] }
    }

    public struct SubscriptionOffer: Hashable, Sendable {
        public struct OfferType: RawRepresentable, Hashable, Sendable {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let introductory = OfferType(rawValue: 1)
            public static let promotional = OfferType(rawValue: 2)
            public static let code = OfferType(rawValue: 3)
            public static let winBack = OfferType(rawValue: 4)
            public var localizedDescription: String { ["", "Introductory", "Promotional", "Offer Code", "Win-Back"][min(max(rawValue, 0), 4)] }
        }
        public struct PaymentMode: RawRepresentable, Hashable, Sendable {
            public let rawValue: String
            public init(rawValue: String) { self.rawValue = rawValue }
            public static let payAsYouGo = PaymentMode(rawValue: "PayAsYouGo")
            public static let payUpFront = PaymentMode(rawValue: "PayUpFront")
            public static let freeTrial = PaymentMode(rawValue: "FreeTrial")
            public var localizedDescription: String {
                switch self { case .freeTrial: return "Free Trial"; case .payUpFront: return "Pay Up Front"; default: return "Pay As You Go" }
            }
        }
        public let id: String?
        public let type: OfferType
        public let price: Decimal
        public let displayPrice: String
        public let period: SubscriptionPeriod
        public let periodCount: Int
        public let paymentMode: PaymentMode
        /// "1 week free", "3 months for $0.99/month", "6 months for $2.99"
        var summary: String {
            let p = periodCount == 1 ? period.localizedDescription : "\(periodCount * period.value) \(period.unit)s"
            switch paymentMode {
            case .freeTrial: return "\(p) free"
            case .payUpFront: return "\(p) for \(displayPrice)"
            default: return "\(p) for \(displayPrice)/\(period.unit)"
            }
        }
    }
}

// MARK: - Configuration (.storekit)

struct _SKOfferDef: Hashable {
    let offer: Product.SubscriptionOffer
    let keys: [String]          // what redeems/identifies it: offerID, referenceName, internalID (lowercased)
}

struct _SKItem {
    let id: String, type: Product.ProductType, name: String, description: String, price: Decimal, displayPrice: String, familyShareable: Bool
    var groupID: String? = nil, groupName: String? = nil, groupLevel = 1
    var period: Product.SubscriptionPeriod? = nil
    var intro: _SKOfferDef? = nil
    var promos: [_SKOfferDef] = [], winBacks: [_SKOfferDef] = [], codes: [_SKOfferDef] = []
}

/// Xcode's StoreKit testing time rate: how fast subscriptions renew.
enum _SKTimeRate: Equatable {
    case realTime
    case oneSecondIsOneDay
    case perRenewal(Double)     // every period lasts N seconds
    case perMonth(Double)       // a month lasts N seconds; other periods scale
    /// SKTestSession.TimeRate, in declaration order (the .storekit "_timeRate" number)
    static func xcode(_ n: Int) -> _SKTimeRate {
        switch n {
        case 1: return .oneSecondIsOneDay
        case 2: return .perRenewal(2)
        case 3: return .perRenewal(10)
        case 4: return .perRenewal(15)
        case 5: return .perRenewal(30)
        case 6: return .perRenewal(60)
        case 7: return .perMonth(30)
        case 8: return .perMonth(60)
        case 9: return .perMonth(300)
        case 10: return .perMonth(900)
        case 11: return .perMonth(1800)
        case 12: return .perMonth(3600)
        default: return .realTime
        }
    }
    static func parse(_ s: String) -> _SKTimeRate? {
        let t = s.trimmingCharacters(in: .whitespaces)
        if let n = Int(t) { return xcode(n) }
        if t.hasPrefix("month="), let n = Double(t.dropFirst(6)) { return .perMonth(n) }
        if t.hasPrefix("renewal="), let n = Double(t.dropFirst(8)) { return .perRenewal(n) }
        let names = ["realTime", "oneSecondIsOneDay", "oneRenewalEveryTwoSeconds", "oneRenewalEveryTenSeconds", "oneRenewalEveryFifteenSeconds",
                     "oneRenewalEveryThirtySeconds", "oneRenewalEveryMinute", "monthlyRenewalEveryThirtySeconds", "monthlyRenewalEveryMinute",
                     "monthlyRenewalEveryFiveMinutes", "monthlyRenewalEveryFifteenMinutes", "monthlyRenewalEveryThirtyMinutes", "monthlyRenewalEveryHour"]
        if let i = names.firstIndex(where: { $0.lowercased() == t.lowercased() }) { return xcode(i) }
        return nil
    }
    func end(from start: Date, period p: Product.SubscriptionPeriod, count: Int = 1) -> Date {
        let n = Double(max(count, 1))
        switch self {
        case .realTime:
            var c = DateComponents()
            switch p.unit {
            case .day: c.day = p.value * Int(n)
            case .week: c.day = 7 * p.value * Int(n)
            case .month: c.month = p.value * Int(n)
            case .year: c.year = p.value * Int(n)
            }
            return Calendar.current.date(byAdding: c, to: start) ?? start.addingTimeInterval(Double(p.approximateDays) * 86400 * n)
        case .oneSecondIsOneDay: return start.addingTimeInterval(Double(p.approximateDays) * n)
        case .perRenewal(let s): return start.addingTimeInterval(s * n)
        case .perMonth(let s):
            let months: Double
            switch p.unit { case .day: months = 1.0 / 30; case .week: months = 7.0 / 30; case .month: months = 1; case .year: months = 12 }
            return start.addingTimeInterval(s * months * Double(p.value) * n)
        }
    }
    var label: String {
        switch self {
        case .realTime: return "real time"
        case .oneSecondIsOneDay: return "1 second is 1 day"
        case .perRenewal(let s): return "one renewal every \(s) s"
        case .perMonth(let s): return "one month every \(s) s"
        }
    }
}

struct _SKConfig {
    let items: [_SKItem]
    let groups: [String: String]           // group id -> display name
    let timeRate: _SKTimeRate
    let storefront: String
    nonisolated(unsafe) static var cached: _SKConfig?
    func item(_ id: String) -> _SKItem? { items.first { $0.id == id } }
    static func load() -> _SKConfig {
        if let c = cached { return c }
        var items: [_SKItem] = [], groups: [String: String] = [:]
        var rate = _SKTimeRate.realTime, storefront = "USA"
        let name = Bundle.main.object(forInfoDictionaryKey: "ISIMStoreKitConfiguration") as? String ?? "isim-StoreKitConfiguration.storekit"
        let path = (Bundle.main.bundlePath as NSString).appendingPathComponent(name)
        if let data = FileManager.default.contents(atPath: path),
           let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
            let locale = Locale.current.identifier
            func localized(_ locs: [[String: Any]]) -> [String: Any] {
                locs.first { ($0["locale"] as? String) == locale } ?? locs.first { ($0["locale"] as? String)?.hasPrefix("en") == true } ?? locs.first ?? [:]
            }
            func money(_ s: String) -> String { "$" + s }
            func offer(_ o: [String: Any], _ type: Product.SubscriptionOffer.OfferType) -> _SKOfferDef? {
                guard let period = Product.SubscriptionPeriod(iso: o["subscriptionPeriod"] as? String) else { return nil }
                let mode: Product.SubscriptionOffer.PaymentMode
                switch (o["paymentMode"] as? String ?? "").lowercased() {
                case "free", "freetrial": mode = .freeTrial
                case "payupfront": mode = .payUpFront
                default: mode = .payAsYouGo
                }
                let priceText = mode == .freeTrial ? "0.00" : (o["displayPrice"] as? String ?? "0.00")
                let id = (o["offerID"] as? String) ?? (type == .introductory ? nil : o["referenceName"] as? String)
                let keys = [o["offerID"], o["referenceName"], o["internalID"]].compactMap { ($0 as? String)?.lowercased() }
                return _SKOfferDef(offer: Product.SubscriptionOffer(id: id, type: type, price: Decimal(string: priceText) ?? .zero,
                                                                     displayPrice: mode == .freeTrial ? "Free" : money(priceText),
                                                                     period: period, periodCount: max(1, o["numberOfPeriods"] as? Int ?? 1), paymentMode: mode),
                                   keys: keys)
            }
            func add(_ list: [[String: Any]], _ fallback: Product.ProductType, group: (String, String)? = nil) {
                for p in list {
                    guard let id = p["productID"] as? String else { continue }
                    let loc = localized(p["localizations"] as? [[String: Any]] ?? [])
                    let priceText = (p["displayPrice"] as? String) ?? "0"
                    let type: Product.ProductType
                    switch p["type"] as? String {
                    case "Consumable": type = .consumable
                    case "NonConsumable": type = .nonConsumable
                    case "NonRenewingSubscription": type = .nonRenewable
                    case "RecurringSubscription", "AutoRenewable": type = .autoRenewable
                    default: type = fallback
                    }
                    var it = _SKItem(id: id, type: type, name: loc["displayName"] as? String ?? id,
                                     description: loc["description"] as? String ?? "", price: Decimal(string: priceText) ?? .zero,
                                     displayPrice: money(priceText), familyShareable: p["familyShareable"] as? Bool ?? false)
                    if type == .autoRenewable, let g = group {
                        it.groupID = (p["subscriptionGroupID"] as? String) ?? g.0
                        it.groupName = g.1
                        it.groupLevel = p["groupNumber"] as? Int ?? 1
                        it.period = Product.SubscriptionPeriod(iso: p["recurringSubscriptionPeriod"] as? String) ?? .monthly
                        it.intro = (p["introductoryOffer"] as? [String: Any]).flatMap { offer($0, .introductory) }
                        it.promos = (p["adHocOffers"] as? [[String: Any]] ?? []).compactMap { offer($0, .promotional) }
                        it.winBacks = (p["winbackOffers"] as? [[String: Any]] ?? []).compactMap { offer($0, .winBack) }
                        it.codes = (p["codeOffers"] as? [[String: Any]] ?? []).compactMap { offer($0, .code) }
                    }
                    items.append(it)
                }
            }
            add(root["products"] as? [[String: Any]] ?? [], .consumable)
            add(root["nonRenewingSubscriptions"] as? [[String: Any]] ?? [], .nonRenewable)
            for g in root["subscriptionGroups"] as? [[String: Any]] ?? [] {
                let gid = g["id"] as? String ?? (g["name"] as? String ?? "group")
                let gname = localized(g["localizations"] as? [[String: Any]] ?? [])["displayName"] as? String ?? g["name"] as? String ?? gid
                groups[gid] = gname
                add(g["subscriptions"] as? [[String: Any]] ?? [], .autoRenewable, group: (gid, gname))
            }
            let settings = root["settings"] as? [String: Any] ?? [:]
            if let n = settings["_timeRate"] as? Int { rate = .xcode(n) }
            if let s = settings["_storefront"] as? String { storefront = s }
            NSLog("isim StoreKit: local testing configuration %@ (%ld products)", name, items.count)
        } else {
            NSLog("isim StoreKit: no StoreKit configuration in the bundle; no products are available")
        }
        if let env = ProcessInfo.processInfo.environment["ISIM_STOREKIT_TIME_RATE"], let r = _SKTimeRate.parse(env) { rate = r }
        if items.contains(where: { $0.type == .autoRenewable }) { NSLog("isim StoreKit: subscription time rate: %@", rate.label) }
        let c = _SKConfig(items: items, groups: groups, timeRate: rate, storefront: storefront)
        cached = c
        return c
    }
}

// MARK: - The ledger (the device's purchase history for this app)

struct _SKTxn: Codable, Hashable, Sendable {
    var id: UInt64
    var originalID: UInt64
    var productID: String
    var type: String
    var groupID: String?
    var purchaseDate: Double
    var originalPurchaseDate: Double
    var expirationDate: Double?
    var revocationDate: Double?
    var revocationReason: Int?
    var finished: Bool
    var isUpgraded: Bool
    var reason: String               // "purchase" | "renewal"
    var offerType: Int?
    var offerID: String?
    var offerPaymentMode: String?
    var quantity: Int
    var appAccountToken: String?
    var price: String?
    var api: String?                 // "sk1": made with SKPaymentQueue
}

struct _SKSub: Codable, Hashable, Sendable {
    var groupID: String
    var originalID: UInt64
    var productID: String
    var autoRenewProductID: String
    var willAutoRenew: Bool
    var introPeriodsLeft: Int
    var offerType: Int?
    var offerID: String?
    var offerPaymentMode: String?
    var expirationReason: Int?
    var billingIssue: Bool?
}

struct _SKLedgerData: Codable {
    var version = 1
    var nextID: UInt64 = 1
    var transactions: [_SKTxn] = []
    var subscriptions: [String: _SKSub] = [:]
    var firstLaunch: Double?
    var firstAppVersion: String?
    var deviceID: String?
}

/// Thread-safe ledger, persisted as JSON in the app container. `isim storekit` edits the same file;
/// the running app notices (it re-reads the file every half second) and emits Transaction.updates.
final class _SKLedger: @unchecked Sendable {
    static let shared = _SKLedger()
    let lock = NSLock()
    private(set) var data = _SKLedgerData()
    private var lastBytes: Data?
    let path: String
    private var statusKeys: [String: String] = [:]

    init() {
        path = (NSHomeDirectory() as NSString).appendingPathComponent("Library/isim/StoreKit/ledger.json")
        try? FileManager.default.createDirectory(atPath: (path as NSString).deletingLastPathComponent, withIntermediateDirectories: true, attributes: nil)
        _ = reload()
        if lastBytes == nil { migrate(); save() }
        if data.firstLaunch == nil {
            data.firstLaunch = Date().timeIntervalSince1970
            data.firstAppVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
            data.deviceID = UUID().uuidString
            save()
        }
        statusKeys = currentStatusKeys(Date())
    }
    /// purchases stored by earlier isim versions (UserDefaults)
    private func migrate() {
        let old = UserDefaults.standard.array(forKey: "_ISIMStoreKitTransactions") as? [[String: Any]] ?? []
        for r in old {
            guard let id = (r["id"] as? NSNumber)?.uint64Value, let pid = r["productID"] as? String else { continue }
            let d = (r["date"] as? NSNumber)?.doubleValue ?? 0
            let type = r["type"] as? String ?? Product.ProductType.consumable.rawValue
            data.transactions.append(_SKTxn(id: id, originalID: id, productID: pid, type: type, groupID: nil, purchaseDate: d, originalPurchaseDate: d,
                                            expirationDate: nil, revocationDate: nil, revocationReason: nil, finished: true, isUpgraded: false,
                                            reason: "purchase", offerType: nil, offerID: nil, offerPaymentMode: nil, quantity: 1, appAccountToken: nil, price: nil, api: nil))
            data.nextID = max(data.nextID, id + 1)
        }
        if !old.isEmpty { NSLog("isim StoreKit: migrated %ld earlier purchases into the ledger", old.count) }
    }
    /// re-reads the file; true when it changed on disk (e.g. `isim storekit refund`)
    @discardableResult func reload() -> Bool {
        guard let bytes = FileManager.default.contents(atPath: path), bytes != lastBytes else { return false }
        guard let d = try? JSONDecoder().decode(_SKLedgerData.self, from: bytes) else { return false }
        data = d; lastBytes = bytes
        return true
    }
    private func save() {
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let bytes = try? enc.encode(data) else { return }
        try? bytes.write(to: URL(fileURLWithPath: path), options: .atomic)
        lastBytes = bytes
    }
    func read<R>(_ f: (_SKLedgerData) -> R) -> R { lock.lock(); defer { lock.unlock() }; return f(data) }
    func mutate<R>(_ f: (inout _SKLedgerData) -> R) -> R {
        lock.lock(); defer { lock.unlock() }
        reload()
        let r = f(&data)
        save()
        return r
    }
    func newID(_ d: inout _SKLedgerData) -> UInt64 { let n = d.nextID; d.nextID += 1; return n }

    // MARK: queries
    static func latest(_ d: _SKLedgerData, group: String) -> _SKTxn? {
        d.transactions.filter { $0.groupID == group && !$0.isUpgraded }.max { ($0.purchaseDate, $0.id) < ($1.purchaseDate, $1.id) }
    }
    static func isActive(_ t: _SKTxn, _ now: Date) -> Bool {
        t.revocationDate == nil && (t.expirationDate.map { $0 > now.timeIntervalSince1970 } ?? true)
    }
    func entitlements(_ now: Date = Date()) -> [_SKTxn] {
        read { d in
            var out = d.transactions.filter { ($0.type == Product.ProductType.nonConsumable.rawValue || $0.type == Product.ProductType.nonRenewable.rawValue) && $0.revocationDate == nil }
            for g in Set(d.transactions.compactMap { $0.groupID }).sorted() {
                if let t = _SKLedger.latest(d, group: g), _SKLedger.isActive(t, now) { out.append(t) }
            }
            return out.sorted { $0.id < $1.id }
        }
    }
    func all() -> [_SKTxn] {
        let keepConsumables = Bundle.main.object(forInfoDictionaryKey: "SKIncludeConsumableInAppPurchaseHistory") as? Bool ?? false
        return read { $0.transactions.filter { keepConsumables || $0.type != Product.ProductType.consumable.rawValue || !$0.finished } }
    }
    func transaction(_ id: UInt64) -> _SKTxn? { read { $0.transactions.first { $0.id == id } } }
    func everSubscribed(group: String) -> Bool { read { d in d.transactions.contains { $0.groupID == group } } }

    // MARK: subscriptions
    enum SubscribeResult { case new(_SKTxn), deferred(_SKTxn), already(_SKTxn) }

    /// Buys subscription `item` (optionally with an offer): a new subscription, a resubscription, an
    /// upgrade/crossgrade (immediate) or a downgrade/crossgrade to a different period (at the next renewal).
    func subscribe(_ item: _SKItem, offer: Product.SubscriptionOffer?, token: UUID?, api: String? = nil, finished: Bool = false) -> SubscribeResult {
        let cfg = _SKConfig.load(), now = Date()
        guard let g = item.groupID, let period = item.period else { fatalError("not a subscription") }
        return mutate { d in
            let latest = _SKLedger.latest(d, group: g)
            if let a = latest, _SKLedger.isActive(a, now) {
                if a.productID == item.id {
                    if var s = d.subscriptions[g], s.autoRenewProductID != item.id || !s.willAutoRenew {
                        s.autoRenewProductID = item.id; s.willAutoRenew = true; s.expirationReason = nil; d.subscriptions[g] = s
                    }
                    return .already(a)
                }
                let cur = cfg.item(a.productID)
                let curLevel = cur?.groupLevel ?? item.groupLevel, curDays = cur?.period?.approximateDays ?? period.approximateDays
                let immediate = item.groupLevel < curLevel || (item.groupLevel == curLevel && curDays == period.approximateDays)
                if !immediate {
                    if var s = d.subscriptions[g] { s.autoRenewProductID = item.id; s.willAutoRenew = true; s.expirationReason = nil; d.subscriptions[g] = s }
                    NSLog("isim StoreKit: %@ -> %@ takes effect at the next renewal", a.productID, item.id)
                    return .deferred(a)
                }
                if let i = d.transactions.firstIndex(where: { $0.id == a.id }) { d.transactions[i].isUpgraded = true }
                let t = makeSub(&d, item, period: period, offer: offer, start: now, originalID: a.originalID, original: a.originalPurchaseDate, token: token, api: api, finished: finished)
                NSLog("isim StoreKit: %@ -> %@ (immediate %@)", a.productID, item.id, item.groupLevel < curLevel ? "upgrade" : "crossgrade")
                return .new(t)
            }
            let previous = d.subscriptions[g]
            let id0 = previous?.originalID
            let t = makeSub(&d, item, period: period, offer: offer, start: now, originalID: id0, original: id0 == nil ? nil : d.transactions.first { $0.id == id0 }?.purchaseDate, token: token, api: api, finished: finished)
            return .new(t)
        }
    }
    private func makeSub(_ d: inout _SKLedgerData, _ item: _SKItem, period: Product.SubscriptionPeriod, offer: Product.SubscriptionOffer?, start: Date,
                         originalID: UInt64?, original: Double?, token: UUID?, api: String?, finished: Bool) -> _SKTxn {
        let rate = _SKConfig.load().timeRate
        let id = newID(&d)
        var end: Date
        var left = 0
        if let o = offer {
            if o.paymentMode == .payAsYouGo { end = rate.end(from: start, period: o.period); left = o.periodCount - 1 }
            else { end = rate.end(from: start, period: o.period, count: o.periodCount) }
        } else { end = rate.end(from: start, period: period) }
        let t = _SKTxn(id: id, originalID: originalID ?? id, productID: item.id, type: item.type.rawValue, groupID: item.groupID,
                       purchaseDate: start.timeIntervalSince1970, originalPurchaseDate: original ?? start.timeIntervalSince1970,
                       expirationDate: end.timeIntervalSince1970, revocationDate: nil, revocationReason: nil, finished: finished, isUpgraded: false,
                       reason: "purchase", offerType: offer?.type.rawValue, offerID: offer?.id, offerPaymentMode: offer?.paymentMode.rawValue,
                       quantity: 1, appAccountToken: token?.uuidString, price: "\(offer?.price ?? item.price)", api: api)
        d.transactions.append(t)
        d.subscriptions[item.groupID!] = _SKSub(groupID: item.groupID!, originalID: t.originalID, productID: item.id, autoRenewProductID: item.id,
                                                willAutoRenew: true, introPeriodsLeft: left, offerType: left > 0 ? offer?.type.rawValue : nil,
                                                offerID: left > 0 ? offer?.id : nil, offerPaymentMode: left > 0 ? offer?.paymentMode.rawValue : nil,
                                                expirationReason: nil, billingIssue: nil)
        NSLog("isim StoreKit: subscribed to %@ until %@%@ (local testing, nothing charged)", item.id, "\(end)", offer.map { " with \($0.type.localizedDescription.lowercased()) offer \($0.summary)" } ?? "")
        return t
    }

    func purchase(_ item: _SKItem, quantity: Int, token: UUID?, api: String? = nil) -> _SKTxn {
        mutate { d in
            let id = newID(&d), now = Date().timeIntervalSince1970
            let t = _SKTxn(id: id, originalID: id, productID: item.id, type: item.type.rawValue, groupID: nil, purchaseDate: now, originalPurchaseDate: now,
                           expirationDate: nil, revocationDate: nil, revocationReason: nil, finished: false, isUpgraded: false, reason: "purchase",
                           offerType: nil, offerID: nil, offerPaymentMode: nil, quantity: max(1, quantity), appAccountToken: token?.uuidString,
                           price: "\(item.price)", api: api)
            d.transactions.append(t)
            return t
        }
    }

    func finish(_ id: UInt64) {
        mutate { d in if let i = d.transactions.firstIndex(where: { $0.id == id }) { d.transactions[i].finished = true } }
    }
    func setAutoRenew(group: String, _ on: Bool) {
        mutate { d in
            guard var s = d.subscriptions[group] else { return }
            s.willAutoRenew = on; s.expirationReason = nil
            d.subscriptions[group] = s
        }
        NSLog("isim StoreKit: auto-renew %@ for subscription group %@", on ? "on" : "off", group)
        tick()
    }
    /// A refund: the transaction is revoked (and its subscription ends) and Transaction.updates delivers it.
    func revoke(_ id: UInt64, reason: Int = 0) {
        let t: _SKTxn? = mutate { d in
            guard let i = d.transactions.firstIndex(where: { $0.id == id }), d.transactions[i].revocationDate == nil else { return nil }
            d.transactions[i].revocationDate = Date().timeIntervalSince1970
            d.transactions[i].revocationReason = reason
            if let g = d.transactions[i].groupID, var s = d.subscriptions[g] { s.willAutoRenew = false; d.subscriptions[g] = s }
            return d.transactions[i]
        }
        if let t { NSLog("isim StoreKit: transaction %llu (%@) refunded", t.id, t.productID); _SKUpdates.transactions.yield(.verified(Transaction(t))) }
        tick()
    }

    /// Renews or expires subscriptions whose period ended (on the accelerated clock), and picks up changes
    /// made by `isim storekit`. New and changed transactions go to Transaction.updates.
    func tick(_ now: Date = Date()) {
        let cfg = _SKConfig.load()
        var events: [_SKTxn] = []
        lock.lock()
        let before = data.transactions
        if reload() {   // changed on disk by the Transaction Manager
            let old = Dictionary(before.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            for t in data.transactions {
                if let o = old[t.id] { if o.revocationDate == nil && t.revocationDate != nil { events.append(t) } }
                else { events.append(t) }
            }
            NSLog("isim StoreKit: ledger changed by the Transaction Manager")
        }
        var changed = false
        for (g, var s) in data.subscriptions.sorted(by: { $0.key < $1.key }) {
            guard var last = _SKLedger.latest(data, group: g), last.revocationDate == nil else { continue }
            var n = 0
            while let exp = last.expirationDate, exp <= now.timeIntervalSince1970, n < 100 {
                if !s.willAutoRenew || s.billingIssue == true {
                    let reason = s.billingIssue == true ? 2 : 1
                    if s.expirationReason != reason { s.expirationReason = reason; changed = true
                        NSLog("isim StoreKit: subscription %@ expired (%@)", last.productID, reason == 1 ? "auto-renew off" : "billing issue") }
                    break
                }
                guard let item = cfg.item(s.autoRenewProductID) ?? cfg.item(s.productID), let period = item.period else { break }
                var offerPeriod: Product.SubscriptionPeriod?
                var offerType = s.offerType, offerID = s.offerID, mode = s.offerPaymentMode
                if s.introPeriodsLeft > 0, let o = (cfg.item(s.productID).flatMap { i in ([i.intro].compactMap { $0 } + i.promos + i.winBacks + i.codes).first { $0.offer.type.rawValue == s.offerType && $0.offer.id == s.offerID } }) {
                    offerPeriod = o.offer.period; s.introPeriodsLeft -= 1
                } else { offerType = nil; offerID = nil; mode = nil; s.introPeriodsLeft = 0 }
                let start = Date(timeIntervalSince1970: exp)
                let end = cfg.timeRate.end(from: start, period: offerPeriod ?? period)
                let id = data.nextID; data.nextID += 1
                let t = _SKTxn(id: id, originalID: s.originalID, productID: item.id, type: item.type.rawValue, groupID: g, purchaseDate: exp,
                               originalPurchaseDate: data.transactions.first { $0.id == s.originalID }?.purchaseDate ?? last.originalPurchaseDate,
                               expirationDate: end.timeIntervalSince1970, revocationDate: nil, revocationReason: nil, finished: false, isUpgraded: false,
                               reason: "renewal", offerType: offerType, offerID: offerID, offerPaymentMode: mode, quantity: 1,
                               appAccountToken: last.appAccountToken, price: "\(item.price)", api: last.api)
                data.transactions.append(t)
                s.productID = item.id
                events.append(t); last = t; n += 1; changed = true
                NSLog("isim StoreKit: subscription %@ renewed: transaction %llu until %@", item.id, id, "\(end)")
            }
            data.subscriptions[g] = s
        }
        if changed { save() }
        let keys = currentStatusKeys(now)
        let changedGroups = keys.filter { statusKeys[$0.key] != $0.value }.map { $0.key }
        statusKeys = keys
        let d = data
        lock.unlock()
        for t in events where t.revocationDate == nil || true { _SKUpdates.transactions.yield(.verified(Transaction(t))) }
        for g in changedGroups.sorted() { for st in _SKLedger.statuses(d, group: g, now: now) { _SKUpdates.statuses.yield(st) } }
    }

    private func currentStatusKeys(_ now: Date) -> [String: String] {
        var out: [String: String] = [:]
        for g in Set(data.transactions.compactMap { $0.groupID }) {
            if let st = _SKLedger.statuses(data, group: g, now: now).first {
                out[g] = "\(st.state.rawValue)-\(st.transaction.unsafePayloadValue.id)-\(st.renewalInfo.unsafePayloadValue.willAutoRenew)-\(st.renewalInfo.unsafePayloadValue.autoRenewPreference ?? "")"
            }
        }
        return out
    }

    static func statuses(_ d: _SKLedgerData, group: String, now: Date) -> [Product.SubscriptionInfo.Status] {
        guard let t = latest(d, group: group) else { return [] }
        let s = d.subscriptions[group]
        let state: Product.SubscriptionInfo.RenewalState
        if t.revocationDate != nil { state = .revoked }
        else if isActive(t, now) { state = .subscribed }
        else if s?.billingIssue == true { state = .inBillingRetryPeriod }
        else { state = .expired }
        let info = Product.SubscriptionInfo.RenewalInfo(
            originalTransactionID: t.originalID, currentProductID: t.productID, willAutoRenew: (s?.willAutoRenew ?? false) && t.revocationDate == nil,
            autoRenewPreference: s?.autoRenewProductID, expirationReason: state == .expired || state == .inBillingRetryPeriod ? (s?.expirationReason).map { Product.SubscriptionInfo.RenewalInfo.ExpirationReason(rawValue: $0) } : nil,
            isInBillingRetry: s?.billingIssue == true && state == .inBillingRetryPeriod,
            renewalDate: t.expirationDate.map { Date(timeIntervalSince1970: $0) },
            offerType: (s?.introPeriodsLeft ?? 0) > 0 ? s?.offerType.map { Transaction.OfferType(rawValue: $0) } : nil,
            offerID: (s?.introPeriodsLeft ?? 0) > 0 ? s?.offerID : nil,
            recentSubscriptionStartDate: Date(timeIntervalSince1970: d.transactions.filter { $0.groupID == group }.map { $0.purchaseDate }.min() ?? t.purchaseDate))
        return [Product.SubscriptionInfo.Status(state: state, transaction: .verified(Transaction(t)), renewalInfo: .verified(info))]
    }
}

/// Fan-out of live updates to every listener (Transaction.updates, Status.updates).
final class _SKBroadcast<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuations: [UUID: AsyncStream<T>.Continuation] = [:]
    func stream(initial: [T] = []) -> AsyncStream<T> {
        AsyncStream { c in
            let key = UUID()
            for t in initial { c.yield(t) }
            lock.lock(); continuations[key] = c; lock.unlock()
            c.onTermination = { [weak self] _ in guard let self else { return }; self.lock.lock(); self.continuations[key] = nil; self.lock.unlock() }
        }
    }
    func yield(_ t: T) {
        lock.lock(); let cs = Array(continuations.values); lock.unlock()
        for c in cs { c.yield(t) }
    }
}

enum _SKUpdates {
    static let transactions = _SKBroadcast<VerificationResult<Transaction>>()
    static let statuses = _SKBroadcast<Product.SubscriptionInfo.Status>()
    nonisolated(unsafe) static var started = false
    /// the subscription clock: re-checks the ledger twice a second while the app runs
    static func start() {
        if started { return }
        started = true
        _ = _SKLedger.shared
        func loop() {
            _SKLedger.shared.tick()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { loop() }
        }
        DispatchQueue.main.async { loop() }
    }
}

// MARK: - Product

public struct Product: Identifiable, Hashable, Sendable {
    public struct ProductType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let consumable = ProductType(rawValue: "Consumable")
        public static let nonConsumable = ProductType(rawValue: "Non-Consumable")
        public static let nonRenewable = ProductType(rawValue: "Non-Renewing Subscription")
        public static let autoRenewable = ProductType(rawValue: "Auto-Renewable Subscription")
        public var localizedDescription: String { rawValue }
    }
    public enum PurchaseResult: Sendable {
        case success(VerificationResult<Transaction>)
        case userCancelled
        case pending
    }
    public struct PurchaseOption: Hashable, Sendable {
        enum Kind: Hashable, Sendable {
            case token(UUID), quantity(Int), promo(String), winBack(String), simulatesAskToBuy(Bool), custom(String), introEligibility
        }
        let kind: Kind
        public static func appAccountToken(_ token: UUID) -> PurchaseOption { PurchaseOption(kind: .token(token)) }
        public static func quantity(_ quantity: Int) -> PurchaseOption { PurchaseOption(kind: .quantity(quantity)) }
        /// The offer signature is not verified in isim's local testing (as with Xcode, nothing reaches Apple).
        public static func promotionalOffer(offerID: String, keyID: String, nonce: UUID, signature: Data, timestamp: Int) -> PurchaseOption { PurchaseOption(kind: .promo(offerID)) }
        public static func promotionalOffer(_ offerID: String, compactJWS: String) -> PurchaseOption { PurchaseOption(kind: .promo(offerID)) }
        public static func winBackOffer(_ offer: Product.SubscriptionOffer) -> PurchaseOption { PurchaseOption(kind: .winBack(offer.id ?? "")) }
        public static func introductoryOfferEligibility(compactJWS: String) -> PurchaseOption { PurchaseOption(kind: .introEligibility) }
        public static func simulatesAskToBuyInSandbox(_ value: Bool) -> PurchaseOption { PurchaseOption(kind: .simulatesAskToBuy(value)) }
        public static func custom(key: String, value: String) -> PurchaseOption { PurchaseOption(kind: .custom(key)) }
        public static func custom(key: String, value: Bool) -> PurchaseOption { PurchaseOption(kind: .custom(key)) }
        public static func custom(key: String, value: Double) -> PurchaseOption { PurchaseOption(kind: .custom(key)) }
    }
    public enum PurchaseError: Error, Sendable { case invalidQuantity, productUnavailable, purchaseNotAllowed, ineligibleForOffer, invalidOfferIdentifier, invalidOfferPrice, invalidOfferSignature, missingOfferParameters }

    public let id: String
    public let type: ProductType
    public let displayName: String
    public let description: String
    public let price: Decimal
    public let displayPrice: String
    public let isFamilyShareable: Bool
    public let subscription: SubscriptionInfo?

    init(_ i: _SKItem) {
        id = i.id; type = i.type; displayName = i.name; description = i.description; price = i.price; displayPrice = i.displayPrice
        isFamilyShareable = i.familyShareable
        if let g = i.groupID, let p = i.period {
            subscription = SubscriptionInfo(introductoryOffer: i.intro?.offer, promotionalOffers: i.promos.map { $0.offer }, winBackOffers: i.winBacks.map { $0.offer },
                                            subscriptionGroupID: g, subscriptionPeriod: p, groupLevel: i.groupLevel, groupDisplayName: i.groupName ?? g)
        } else { subscription = nil }
    }

    public static func products<C: Collection>(for identifiers: C) async throws -> [Product] where C.Element == String {
        _SKUpdates.start()
        let wanted = Set(identifiers)
        return _SKConfig.load().items.filter { wanted.contains($0.id) }.map(Product.init)
    }

    public var jsonRepresentation: Data {
        var d: [String: Any] = ["productID": id, "type": type.rawValue, "displayName": displayName, "description": description, "displayPrice": displayPrice, "isim": "local StoreKit testing"]
        if let s = subscription { d["subscriptionGroupID"] = s.subscriptionGroupID; d["subscriptionPeriod"] = s.subscriptionPeriod.description }
        return (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
    }

    /// The latest transaction for this product, and the current entitlement.
    public var latestTransaction: VerificationResult<Transaction>? { get async { await Transaction.latest(for: id) } }
    public var currentEntitlement: VerificationResult<Transaction>? { get async { await Transaction.currentEntitlement(for: id) } }

    @MainActor public func purchase(options: Set<PurchaseOption> = []) async throws -> PurchaseResult {
        try await _purchase(options: options, api: nil)
    }
    @MainActor public func purchase(confirmIn scene: UIScene, options: Set<PurchaseOption> = []) async throws -> PurchaseResult {
        try await _purchase(options: options, api: nil)
    }
    @MainActor public func purchase(confirmIn viewController: UIViewController, options: Set<PurchaseOption> = []) async throws -> PurchaseResult {
        try await _purchase(options: options, api: nil)
    }

    @MainActor func _purchase(options: Set<PurchaseOption>, api: String?) async throws -> PurchaseResult {
        _SKUpdates.start()
        guard let item = _SKConfig.load().item(id) else { throw PurchaseError.productUnavailable }
        var quantity = 1, token: UUID?, promo: String?, winBack: String?
        for o in options {
            switch o.kind {
            case .quantity(let q): quantity = q
            case .token(let t): token = t
            case .promo(let p): promo = p
            case .winBack(let w): winBack = w
            default: break
            }
        }
        guard quantity >= 1, quantity <= 10, quantity == 1 || type == .consumable else { throw PurchaseError.invalidQuantity }
        // offer
        var offer: SubscriptionOffer?
        if let promo {
            guard let o = item.promos.first(where: { $0.offer.id == promo || $0.keys.contains(promo.lowercased()) }) else { throw PurchaseError.invalidOfferIdentifier }
            offer = o.offer
            NSLog("isim StoreKit: promotional offer %@ (signature not verified in local testing)", promo)
        } else if let winBack {
            guard let o = item.winBacks.first(where: { $0.offer.id == winBack }) else { throw PurchaseError.invalidOfferIdentifier }
            guard let g = item.groupID, _SKLedger.shared.everSubscribed(group: g),
                  !_SKLedger.shared.entitlements().contains(where: { $0.groupID == g }) else { throw PurchaseError.ineligibleForOffer }
            offer = o.offer
        } else if let s = subscription, let intro = s.introductoryOffer, !_SKLedger.shared.everSubscribed(group: s.subscriptionGroupID) {
            offer = intro
        }
        // already owned?
        if type == .nonConsumable, let owned = _SKLedger.shared.entitlements().first(where: { $0.productID == id }) {
            await _SKSheets.notice(title: "You’ve already purchased this. Would you like to get it again for free?", message: "[Environment: isim StoreKit testing]")
            return .success(.verified(Transaction(owned)))
        }
        if let g = subscription?.subscriptionGroupID, let cur = _SKLedger.shared.entitlements().first(where: { $0.groupID == g }), cur.productID == id,
           _SKLedger.shared.read({ $0.subscriptions[g]?.willAutoRenew ?? true }) {
            await _SKSheets.notice(title: "You’re currently subscribed to this.", message: "\(displayName)\n[Environment: isim StoreKit testing]")
            return .success(.verified(Transaction(cur)))
        }
        guard await _SKPurchaseSheet.confirm(self, quantity: quantity, offer: offer) else { return .userCancelled }
        if type == .autoRenewable {
            switch _SKLedger.shared.subscribe(item, offer: offer, token: token, api: api) {
            case .new(let t), .deferred(let t), .already(let t):
                return .success(.verified(Transaction(t)))
            }
        }
        let t = _SKLedger.shared.purchase(item, quantity: quantity, token: token, api: api)
        NSLog("isim StoreKit: purchased %@ (local testing, nothing charged)", id)
        return .success(.verified(Transaction(t)))
    }

    // MARK: subscription info
    public struct SubscriptionInfo: Hashable, Sendable {
        public let introductoryOffer: SubscriptionOffer?
        public let promotionalOffers: [SubscriptionOffer]
        public let winBackOffers: [SubscriptionOffer]
        public let subscriptionGroupID: String
        public let subscriptionPeriod: SubscriptionPeriod
        public let groupLevel: Int
        public let groupDisplayName: String

        /// Eligible for the introductory offer: never subscribed to this group.
        public var isEligibleForIntroOffer: Bool { get async { await SubscriptionInfo.isEligibleForIntroOffer(for: subscriptionGroupID) } }
        public static func isEligibleForIntroOffer(for groupID: String) async -> Bool { !_SKLedger.shared.everSubscribed(group: groupID) }
        public var status: [Status] { get async throws { try await SubscriptionInfo.status(for: subscriptionGroupID) } }
        public static func status(for groupID: String) async throws -> [Status] {
            _SKUpdates.start()
            _SKLedger.shared.tick()
            return _SKLedger.shared.read { _SKLedger.statuses($0, group: groupID, now: Date()) }
        }

        public struct RenewalState: RawRepresentable, Hashable, Sendable, CustomStringConvertible {
            public let rawValue: Int
            public init(rawValue: Int) { self.rawValue = rawValue }
            public static let subscribed = RenewalState(rawValue: 1)
            public static let expired = RenewalState(rawValue: 2)
            public static let inBillingRetryPeriod = RenewalState(rawValue: 3)
            public static let inGracePeriod = RenewalState(rawValue: 4)
            public static let revoked = RenewalState(rawValue: 5)
            public var localizedDescription: String { ["", "Subscribed", "Expired", "In Billing Retry Period", "In Grace Period", "Revoked"][min(max(rawValue, 0), 5)] }
            public var description: String { ["unknown", "subscribed", "expired", "inBillingRetryPeriod", "inGracePeriod", "revoked"][min(max(rawValue, 0), 5)] }
        }

        public struct RenewalInfo: Hashable, Sendable {
            public struct ExpirationReason: RawRepresentable, Hashable, Sendable {
                public let rawValue: Int
                public init(rawValue: Int) { self.rawValue = rawValue }
                public static let autoRenewDisabled = ExpirationReason(rawValue: 1)
                public static let billingError = ExpirationReason(rawValue: 2)
                public static let didNotConsentToPriceIncrease = ExpirationReason(rawValue: 3)
                public static let productUnavailable = ExpirationReason(rawValue: 4)
                public static let unknown = ExpirationReason(rawValue: 5)
            }
            public enum PriceIncreaseStatus: Sendable, Hashable { case noIncreasePending, pending, agreed }
            public let originalTransactionID: UInt64
            public let currentProductID: String
            public let willAutoRenew: Bool
            public let autoRenewPreference: String?
            public let expirationReason: ExpirationReason?
            public let isInBillingRetry: Bool
            public let renewalDate: Date?
            public let offerType: Transaction.OfferType?
            public let offerID: String?
            public let recentSubscriptionStartDate: Date
            public var gracePeriodExpirationDate: Date? { nil }
            public var priceIncreaseStatus: PriceIncreaseStatus { .noIncreasePending }
            public var signedDate: Date { Date() }
            public var environment: AppStore.Environment { .xcode }
            public var deviceVerification: Data { Data() }
            public var deviceVerificationNonce: UUID { UUID() }
            public var jsonRepresentation: Data {
                let d: [String: Any] = ["originalTransactionId": "\(originalTransactionID)", "productId": currentProductID, "autoRenewStatus": willAutoRenew ? 1 : 0,
                                        "autoRenewProductId": autoRenewPreference ?? currentProductID, "environment": "Xcode", "isim": "local, unsigned"]
                return (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
            }
        }

        public struct Status: Hashable, Sendable {
            public let state: RenewalState
            public let transaction: VerificationResult<Transaction>
            public let renewalInfo: VerificationResult<RenewalInfo>
            /// Subscription status changes (renewals, expirations, refunds, plan changes).
            public static var updates: Statuses { Statuses(stream: _SKUpdates.statuses.stream()) }
            public static var all: AsyncStream<(String, [Status])> {
                let groups = _SKLedger.shared.read { Set($0.transactions.compactMap { $0.groupID }).sorted() }
                return AsyncStream { c in
                    for g in groups { c.yield((g, _SKLedger.shared.read { _SKLedger.statuses($0, group: g, now: Date()) })) }
                    c.finish()
                }
            }
        }
        public struct Statuses: AsyncSequence, Sendable {
            public typealias Element = Status
            let stream: AsyncStream<Status>
            public struct AsyncIterator: AsyncIteratorProtocol {
                var it: AsyncStream<Status>.AsyncIterator
                public mutating func next() async -> Status? { await it.next() }
            }
            public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(it: stream.makeAsyncIterator()) }
        }
    }
}

extension VerificationResult: Equatable where SignedType: Equatable {
    public static func == (a: Self, b: Self) -> Bool { a.unsafePayloadValue == b.unsafePayloadValue }
}
extension VerificationResult: Hashable where SignedType: Hashable {
    public func hash(into h: inout Hasher) { h.combine(unsafePayloadValue) }
}

// MARK: - Transactions

public enum VerificationResult<SignedType>: Sendable where SignedType: Sendable {
    case unverified(SignedType, VerificationError)
    case verified(SignedType)
    public enum VerificationError: Error, Sendable { case revokedCertificate, invalidCertificateChain, invalidDeviceVerification, invalidEncoding, invalidSignature, missingRequiredProperties }
    public var unsafePayloadValue: SignedType {
        switch self { case .verified(let v), .unverified(let v, _): return v }
    }
    public func payloadValue() throws -> SignedType {
        switch self { case .verified(let v): return v; case .unverified(_, let e): throw e }
    }
    /// isim local testing: an unsigned compact JWS ("alg": "none", empty signature). Apple never signed it.
    public var jwsRepresentation: String {
        func b64(_ d: Data) -> String { d.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "") }
        var payload = Data("{}".utf8)
        switch unsafePayloadValue {
        case let t as Transaction: payload = t.jsonRepresentation
        case let r as Product.SubscriptionInfo.RenewalInfo: payload = r.jsonRepresentation
        case let a as AppTransaction: payload = a.jsonRepresentation
        default: break
        }
        return b64(Data(#"{"alg":"none","typ":"JWT","isim":"local StoreKit testing, unsigned"}"#.utf8)) + "." + b64(payload) + "."
    }
    public var signedDate: Date { Date() }
    public var deviceVerification: Data { Data() }
    public var deviceVerificationNonce: UUID { UUID() }
}

public struct Transaction: Identifiable, Hashable, Sendable {
    let r: _SKTxn
    init(_ r: _SKTxn) { self.r = r }

    public struct OfferType: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let introductory = OfferType(rawValue: 1)
        public static let promotional = OfferType(rawValue: 2)
        public static let code = OfferType(rawValue: 3)
        public static let winBack = OfferType(rawValue: 4)
    }
    public struct RevocationReason: RawRepresentable, Hashable, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let developerIssue = RevocationReason(rawValue: 1)
        public static let other = RevocationReason(rawValue: 0)
    }
    public struct OwnershipType: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let purchased = OwnershipType(rawValue: "PURCHASED")
        public static let familyShared = OwnershipType(rawValue: "FAMILY_SHARED")
    }
    public struct Reason: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let purchase = Reason(rawValue: "PURCHASE")
        public static let renewal = Reason(rawValue: "RENEWAL")
    }
    public struct Offer: Hashable, Sendable {
        public let id: String?
        public let type: OfferType
        public let paymentMode: Product.SubscriptionOffer.PaymentMode?
    }
    public enum RefundRequestStatus: Sendable { case success, userCancelled }
    public enum RefundRequestError: Error, Sendable { case duplicateRequest, failed }

    public var id: UInt64 { r.id }
    public var originalID: UInt64 { r.originalID }
    public var webOrderLineItemID: String? { r.groupID == nil ? nil : "\(r.id)" }
    public var productID: String { r.productID }
    public var productType: Product.ProductType { Product.ProductType(rawValue: r.type) }
    public var subscriptionGroupID: String? { r.groupID }
    public var appBundleID: String { Bundle.main.bundleIdentifier ?? "" }
    public var appTransactionID: String { "isim-local-\(Bundle.main.bundleIdentifier ?? "")" }
    public var purchaseDate: Date { Date(timeIntervalSince1970: r.purchaseDate) }
    public var originalPurchaseDate: Date { Date(timeIntervalSince1970: r.originalPurchaseDate) }
    public var expirationDate: Date? { r.expirationDate.map { Date(timeIntervalSince1970: $0) } }
    public var revocationDate: Date? { r.revocationDate.map { Date(timeIntervalSince1970: $0) } }
    public var revocationReason: RevocationReason? { r.revocationReason.map { RevocationReason(rawValue: $0) } }
    public var isUpgraded: Bool { r.isUpgraded }
    public var purchasedQuantity: Int { r.quantity }
    public var ownershipType: OwnershipType { .purchased }
    public var signedDate: Date { Date() }
    public var environment: AppStore.Environment { .xcode }
    public var reason: Reason { r.reason == "renewal" ? .renewal : .purchase }
    public var appAccountToken: UUID? { r.appAccountToken.flatMap { UUID(uuidString: $0) } }
    public var offerType: OfferType? { r.offerType.map { OfferType(rawValue: $0) } }
    public var offerID: String? { r.offerID }
    public var offerPaymentModeStringRepresentation: String? { r.offerPaymentMode }
    public var offer: Offer? { r.offerType.map { Offer(id: r.offerID, type: OfferType(rawValue: $0), paymentMode: r.offerPaymentMode.map { Product.SubscriptionOffer.PaymentMode(rawValue: $0) }) } }
    public var price: Decimal? { r.price.flatMap { Decimal(string: $0) } }
    public var storefrontCountryCode: String { _SKConfig.load().storefront }
    public var deviceVerification: Data { Data() }
    public var deviceVerificationNonce: UUID { UUID() }
    public var jsonRepresentation: Data {
        var d: [String: Any] = ["transactionId": "\(r.id)", "originalTransactionId": "\(r.originalID)", "productId": r.productID, "type": r.type,
                                "purchaseDate": Int(r.purchaseDate * 1000), "originalPurchaseDate": Int(r.originalPurchaseDate * 1000),
                                "bundleId": appBundleID, "quantity": r.quantity, "environment": "Xcode", "isim": "local StoreKit testing, unsigned"]
        if let e = r.expirationDate { d["expiresDate"] = Int(e * 1000) }
        if let g = r.groupID { d["subscriptionGroupIdentifier"] = g }
        if let v = r.revocationDate { d["revocationDate"] = Int(v * 1000) }
        return (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
    }

    /// Marks the transaction finished; unfinished transactions are delivered again by Transaction.updates
    /// when the app launches (and listed by Transaction.unfinished).
    public func finish() async {
        _SKLedger.shared.finish(r.id)
        NSLog("isim StoreKit: transaction %llu (%@) finished", r.id, r.productID)
    }

    /// Transactions that don't come from the app's purchase() calls: renewals, refunds, offer-code
    /// redemptions, Transaction Manager changes; and, when a listener starts, unfinished transactions.
    public static var updates: Transactions {
        _SKUpdates.start()
        let pending = _SKLedger.shared.read { $0.transactions.filter { !$0.finished } }.map { VerificationResult<Transaction>.verified(Transaction($0)) }
        return Transactions(stream: _SKUpdates.transactions.stream(initial: pending))
    }
    public static var unfinished: Transactions {
        _SKUpdates.start()
        return Transactions(_SKLedger.shared.read { $0.transactions.filter { !$0.finished } })
    }
    /// Non-consumables, non-renewing subscriptions and active auto-renewable subscriptions (not refunded).
    public static var currentEntitlements: Transactions {
        _SKUpdates.start(); _SKLedger.shared.tick()
        return Transactions(_SKLedger.shared.entitlements())
    }
    public static func currentEntitlements(for productID: String) -> Transactions {
        _SKUpdates.start(); _SKLedger.shared.tick()
        return Transactions(_SKLedger.shared.entitlements().filter { $0.productID == productID })
    }
    public static var all: Transactions {
        _SKUpdates.start(); _SKLedger.shared.tick()
        return Transactions(_SKLedger.shared.all())
    }
    public static func all(for productID: String) -> Transactions { Transactions(_SKLedger.shared.all().filter { $0.productID == productID }) }
    public static func currentEntitlement(for productID: String) async -> VerificationResult<Transaction>? {
        for await r in currentEntitlements { if case .verified(let t) = r, t.productID == productID { return r } }
        return nil
    }
    public static func latest(for productID: String) async -> VerificationResult<Transaction>? {
        _SKUpdates.start(); _SKLedger.shared.tick()
        return _SKLedger.shared.read { $0.transactions.filter { $0.productID == productID }.max { $0.id < $1.id } }.map { .verified(Transaction($0)) }
    }

    /// The refund request sheet. In isim's local testing a submitted request is approved at once.
    @MainActor public static func beginRefundRequest(for transactionID: UInt64, in scene: UIWindowScene) async throws -> RefundRequestStatus {
        guard let t = _SKLedger.shared.transaction(transactionID) else { throw RefundRequestError.failed }
        if t.revocationDate != nil { throw RefundRequestError.duplicateRequest }
        return await _SKSheets.refund(Transaction(t)) ? .success : .userCancelled
    }
    @MainActor public func beginRefundRequest(in scene: UIWindowScene) async throws -> RefundRequestStatus {
        try await Transaction.beginRefundRequest(for: id, in: scene)
    }

    public struct Transactions: AsyncSequence, Sendable {
        public typealias Element = VerificationResult<Transaction>
        let stream: AsyncStream<Element>
        init(stream: AsyncStream<Element>) { self.stream = stream }
        init(_ list: [_SKTxn]) {
            let items = list.map { Element.verified(Transaction($0)) }
            stream = AsyncStream { c in for i in items { c.yield(i) }; c.finish() }
        }
        public struct AsyncIterator: AsyncIteratorProtocol {
            var it: AsyncStream<Element>.AsyncIterator
            public mutating func next() async -> Element? { await it.next() }
        }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(it: stream.makeAsyncIterator()) }
    }
}

// MARK: - AppStore, Storefront, AppTransaction

public enum StoreKitError: Error, Sendable {
    case unknown, userCancelled, networkError(Error), systemError(Error), notAvailableInStorefront, notEntitled, unsupported
}

public enum AppStore {
    public struct Environment: RawRepresentable, Hashable, Sendable {
        public let rawValue: String
        public init(rawValue: String) { self.rawValue = rawValue }
        public static let production = Environment(rawValue: "Production")
        public static let sandbox = Environment(rawValue: "Sandbox")
        /// local StoreKit testing (what isim provides)
        public static let xcode = Environment(rawValue: "Xcode")
    }
    /// Restores purchases: re-reads the local ledger (there is no App Store account to sync with).
    public static func sync() async throws {
        _SKUpdates.start()
        _SKLedger.shared.tick()
        NSLog("isim StoreKit: AppStore.sync() re-read the local ledger")
    }
    public static var canMakePayments: Bool { true }
    public static var deviceVerificationID: UUID? { _SKLedger.shared.read { $0.deviceID.flatMap { UUID(uuidString: $0) } } }
    @MainActor public static func showManageSubscriptions(in scene: UIWindowScene) async throws { await _SKSheets.manageSubscriptions(group: nil) }
    @MainActor public static func showManageSubscriptions(in scene: UIWindowScene, subscriptionGroupID: String) async throws { await _SKSheets.manageSubscriptions(group: subscriptionGroupID) }
    @MainActor public static func presentOfferCodeRedeemSheet(in scene: UIWindowScene) async throws { await _SKSheets.redeemCode() }
    @MainActor public static func requestReview(in scene: UIWindowScene) { _ISIMReviewPrompt.request() }
}

public struct Storefront: Identifiable, Hashable, Sendable {
    public let id: String
    public let countryCode: String
    public static var current: Storefront? { get async { let c = _SKConfig.load().storefront; return Storefront(id: c, countryCode: c) } }
    public static var updates: AsyncStream<Storefront> { AsyncStream { _ in } }
}

/// The app's "purchase" (here: its first launch on this device). Local and unsigned.
public struct AppTransaction: Sendable {
    public let appID: UInt64?
    public let appVersionID: UInt64?
    public let appVersion: String
    public let bundleID: String
    /// the app version (CFBundleVersion) at the first launch on this isim device
    public let originalAppVersion: String
    public let originalPurchaseDate: Date
    public let preorderDate: Date?
    public let signedDate: Date
    public var environment: AppStore.Environment { .xcode }
    public var appTransactionID: String { "isim-local-\(bundleID)" }
    public var deviceVerification: Data { Data() }
    public var deviceVerificationNonce: UUID { UUID() }
    public var jsonRepresentation: Data {
        let d: [String: Any] = ["bundleId": bundleID, "applicationVersion": appVersion, "originalApplicationVersion": originalAppVersion,
                                "originalPurchaseDate": Int(originalPurchaseDate.timeIntervalSince1970 * 1000), "receiptType": "Xcode", "isim": "local, unsigned"]
        return (try? JSONSerialization.data(withJSONObject: d)) ?? Data()
    }
    public static var shared: VerificationResult<AppTransaction> { get async throws { make() } }
    public static func refresh() async throws -> VerificationResult<AppTransaction> { make() }
    static func make() -> VerificationResult<AppTransaction> {
        let (first, version) = _SKLedger.shared.read { ($0.firstLaunch ?? Date().timeIntervalSince1970, $0.firstAppVersion ?? "1") }
        return .verified(AppTransaction(appID: nil, appVersionID: nil,
                                        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1",
                                        bundleID: Bundle.main.bundleIdentifier ?? "", originalAppVersion: version,
                                        originalPurchaseDate: Date(timeIntervalSince1970: first), preorderDate: nil, signedDate: Date()))
    }
}

// MARK: - Purchase sheet

@MainActor enum _SKPurchaseSheet {
    static func confirm(_ p: Product, quantity: Int = 1, offer: Product.SubscriptionOffer?) async -> Bool {
        await withCheckedContinuation { (k: CheckedContinuation<Bool, Never>) in
            guard let top = topController() else { k.resume(returning: false); return }
            let title: String, message: String, button: String
            if let s = p.subscription {
                title = "Confirm Subscription"
                let base = "\(p.displayPrice)/\(s.subscriptionPeriod.value == 1 ? "\(s.subscriptionPeriod.unit)" : s.subscriptionPeriod.localizedDescription)"
                let terms = offer.map { "\($0.summary), then \(base)" } ?? base
                message = "\(p.displayName)\n\(s.groupDisplayName)\n\(terms)\nRenews automatically until canceled.\n\n[Environment: isim StoreKit testing — nothing is charged]"
                button = "Subscribe"
            } else {
                title = "Confirm Your In-App Purchase"
                message = "Do you want to buy \(quantity == 1 ? "one" : "\(quantity)") \(p.displayName) for \(p.displayPrice)?\n\n[Environment: isim StoreKit testing — nothing is charged]"
                button = "Buy"
            }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in k.resume(returning: false) })
            alert.addAction(UIAlertAction(title: button, style: .default) { _ in k.resume(returning: true) })
            top.present(alert, animated: true, completion: nil)
        }
    }
    static func topController() -> UIViewController? {
        var top = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = top?.presentedViewController { top = p }
        return top
    }
}
