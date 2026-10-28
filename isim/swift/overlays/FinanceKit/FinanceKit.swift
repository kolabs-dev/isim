// isim FinanceKit (issue #398): an app reads the accounts, balances and transactions of the cards and accounts in
// Wallet. isim has no Wallet financial data, so the device keeps a simulated set: `isim finance seed` adds an example
// credit card and savings account with transactions, `isim finance add-transaction` adds more (ISIM_DATA/Library/isim/
// FinanceKit/data.json, with a change log the histories read). Access needs the com.apple.developer.financekit
// entitlement and the person's permission (isim's prompt, remembered per app; ISIM_FINANCEKIT_PERMISSION=allow|deny).
// Orders: saveOrder(signedArchive:) reads the .order archive's order.json and adds it to isim's Wallet
// (Library/Wallet/Orders, as `isim wallet orders` lists); signatures are not checked.
// Adapted: no banks, no background delivery extensions run; the prompt's wording is isim's.
import Foundation
import UIKit
import Compression

public enum AuthorizationStatus: Hashable, Sendable { case authorized, denied, notDetermined }

public enum CreditDebitIndicator: String, Codable, Hashable, Sendable { case credit, debit }

public struct CurrencyAmount: Codable, Hashable, Sendable {
    public let amount: Decimal
    public let currencyCode: String
    init(amount: Decimal, currencyCode: String) { self.amount = amount; self.currencyCode = currencyCode }
}

public struct AccountCreditInformation: Codable, Hashable, Sendable {
    public let creditLimit: CurrencyAmount?
    public let minimumNextPaymentAmount: CurrencyAmount?
    public let nextPaymentDueDate: Date?
    public let overduePaymentAmount: CurrencyAmount?
}

public struct AssetAccount: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let accountDescription: String?
    public let institutionName: String
    public let currencyCode: String
    public let openingDate: Date?
}

public struct LiabilityAccount: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let displayName: String
    public let accountDescription: String?
    public let institutionName: String
    public let currencyCode: String
    public let openingDate: Date?
    public let creditInformation: AccountCreditInformation
}

public enum Account: Identifiable, Codable, Hashable, Sendable {
    case asset(AssetAccount)
    case liability(LiabilityAccount)
    public var id: UUID { switch self { case .asset(let a): return a.id; case .liability(let l): return l.id } }
    public var displayName: String { switch self { case .asset(let a): return a.displayName; case .liability(let l): return l.displayName } }
    public var accountDescription: String? { switch self { case .asset(let a): return a.accountDescription; case .liability(let l): return l.accountDescription } }
    public var institutionName: String { switch self { case .asset(let a): return a.institutionName; case .liability(let l): return l.institutionName } }
    public var currencyCode: String { switch self { case .asset(let a): return a.currencyCode; case .liability(let l): return l.currencyCode } }
    public var openingDate: Date? { switch self { case .asset(let a): return a.openingDate; case .liability(let l): return l.openingDate } }
    public var assetAccount: AssetAccount? { if case .asset(let a) = self { return a }; return nil }
    public var liabilityAccount: LiabilityAccount? { if case .liability(let l) = self { return l }; return nil }
}

public struct Balance: Codable, Hashable, Sendable {
    public let amount: CurrencyAmount
    public let asOfDate: Date
    public let creditDebitIndicator: CreditDebitIndicator
}

public enum CurrentBalance: Codable, Hashable, Sendable {
    case available(Balance)
    case booked(Balance)
    case availableAndBooked(available: Balance, booked: Balance)
}

public struct AccountBalance: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let accountID: UUID
    public let currentBalance: CurrentBalance
    public var available: Balance? {
        switch currentBalance { case .available(let b): return b; case .availableAndBooked(let a, _): return a; case .booked: return nil }
    }
    public var booked: Balance? {
        switch currentBalance { case .booked(let b): return b; case .availableAndBooked(_, let b): return b; case .available: return nil }
    }
    public var currencyCode: String { (available ?? booked)?.amount.currencyCode ?? "USD" }
}

public enum TransactionType: String, Codable, Hashable, Sendable {
    case adjustment, atm, billPayment, check, deposit, directDebit, directDeposit, dividend, fee, interest, loan
    case pointOfSale, refund, standingOrder, transfer, unknown, withdrawal
}

public enum TransactionStatus: String, Codable, Hashable, Sendable { case authorized, booked, memo, pending, rejected }

public struct MerchantCategoryCode: RawRepresentable, Codable, Hashable, Sendable, CustomStringConvertible {
    public let rawValue: Int16
    public init(rawValue: Int16) { self.rawValue = rawValue }
    /// a four-digit ISO 18245 code
    public init?(_ description: String) {
        guard description.count == 4, let v = Int16(description) else { return nil }
        rawValue = v
    }
    public var description: String { String(format: "%04d", Int(rawValue)) }
}

public struct Transaction: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let accountID: UUID
    public let transactionAmount: CurrencyAmount
    public let foreignCurrencyAmount: CurrencyAmount?
    public let foreignCurrencyExchangeRate: Decimal?
    public let creditDebitIndicator: CreditDebitIndicator
    public let transactionDescription: String
    public let originalTransactionDescription: String
    public let merchantCategoryCode: MerchantCategoryCode?
    public let merchantName: String?
    public let transactionDate: Date
    public let postedDate: Date?
    public let transactionType: TransactionType
    public let status: TransactionStatus
}

public struct FullyQualifiedOrderIdentifier: Codable, Hashable, Sendable {
    public var orderTypeIdentifier: String
    public var orderIdentifier: String
    public init(orderTypeIdentifier: String, orderIdentifier: String) { self.orderTypeIdentifier = orderTypeIdentifier; self.orderIdentifier = orderIdentifier }
}

public struct AccountQuery: Sendable {
    let sortDescriptors: [SortDescriptor<Account>]
    let predicate: Predicate<Account>?
    let limit: Int?, offset: Int?
    public init(sortDescriptors: [SortDescriptor<Account>] = [], predicate: Predicate<Account>? = nil, limit: Int? = nil, offset: Int? = nil) {
        self.sortDescriptors = sortDescriptors; self.predicate = predicate; self.limit = limit; self.offset = offset
    }
}

public struct AccountBalanceQuery: Sendable {
    let sortDescriptors: [SortDescriptor<AccountBalance>]
    let predicate: Predicate<AccountBalance>?
    let limit: Int?, offset: Int?
    public init(sortDescriptors: [SortDescriptor<AccountBalance>] = [], predicate: Predicate<AccountBalance>? = nil, limit: Int? = nil, offset: Int? = nil) {
        self.sortDescriptors = sortDescriptors; self.predicate = predicate; self.limit = limit; self.offset = offset
    }
    /// balances whose available balance is as of a date in the range
    public static func predicate(availableSince startDate: Date, until endDate: Date? = nil) -> Predicate<AccountBalance> {
        let end = endDate ?? .distantFuture
        return #Predicate<AccountBalance> { b in b.available.flatMap { $0.asOfDate >= startDate && $0.asOfDate <= end } ?? false }
    }
    /// balances whose booked balance is as of a date in the range
    public static func predicate(bookedSince startDate: Date, until endDate: Date? = nil) -> Predicate<AccountBalance> {
        let end = endDate ?? .distantFuture
        return #Predicate<AccountBalance> { b in b.booked.flatMap { $0.asOfDate >= startDate && $0.asOfDate <= end } ?? false }
    }
}

public struct TransactionQuery: Sendable {
    let sortDescriptors: [SortDescriptor<Transaction>]
    let predicate: Predicate<Transaction>?
    let limit: Int?, offset: Int?
    public init(sortDescriptors: [SortDescriptor<Transaction>] = [], predicate: Predicate<Transaction>? = nil, limit: Int? = nil, offset: Int? = nil) {
        self.sortDescriptors = sortDescriptors; self.predicate = predicate; self.limit = limit; self.offset = offset
    }
    public static func predicate(forStatuses statuses: [TransactionStatus]) -> Predicate<Transaction> {
        #Predicate<Transaction> { statuses.contains($0.status) }
    }
    public static func predicate(forTransactionTypes types: [TransactionType]) -> Predicate<Transaction> {
        #Predicate<Transaction> { types.contains($0.transactionType) }
    }
    public static func predicate(forMerchantCategoryCodes codes: [MerchantCategoryCode]) -> Predicate<Transaction> {
        let raw = codes.map(\.rawValue)
        return #Predicate<Transaction> { t in t.merchantCategoryCode.flatMap { raw.contains($0.rawValue) } ?? false }
    }
}

public enum FinanceError: Error, LocalizedError, CustomNSError, Hashable, Sendable {
    case dataRestricted(FinanceStore.DataType)
    case historyTokenInvalid
    case unknown
    public static var errorDomain: String { "FinanceKit.FinanceError" }
    public var errorCode: Int {
        switch self { case .dataRestricted: return 1; case .historyTokenInvalid: return 2; case .unknown: return 0 }
    }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? {
        switch self {
        case .dataRestricted(let t): return t == .orders ? "Access to Wallet orders is restricted." : "Access to financial data is restricted."
        case .historyTokenInvalid: return "The history token is not valid."
        case .unknown: return "An unknown error occurred."
        }
    }
    public var failureReason: String? {
        switch self {
        case .dataRestricted: return "The app is not authorized, or does not have the FinanceKit entitlement."
        case .historyTokenInvalid: return "The token is from another device or was reset."
        case .unknown: return nil
        }
    }
}

public final class FinanceStore: @unchecked Sendable {
    public static let shared = FinanceStore()

    public enum DataType: Hashable, Sendable { case financialData, orders }
    public enum ContainsOrderResult: Hashable, Sendable { case exists, newerExists, notFound, olderExists }
    public enum SaveOrderResult: Hashable, Sendable { case added, cancelled, newerExisting }
    public enum BackgroundDataType: Hashable, Sendable { case accountBalances, accounts, transactions }
    public enum UpdateFrequency: Hashable, Sendable { case daily, hourly, weekly }

    public struct HistoryToken: Codable, Hashable, Sendable {
        let sequence: Int
        let store: String
    }

    public struct Changes<Model: Identifiable & Sendable>: Sendable where Model.ID: Sendable {
        public let inserted: [Model]
        public let updated: [Model]
        public let deleted: [Model.ID]
        public let newToken: HistoryToken
    }

    /// the changes since a token: everything first when there is none; with isMonitoring, then each new change as it
    /// comes (the store is checked twice a second)
    public struct History<Model: Identifiable & Codable & Sendable>: AsyncSequence, Sendable where Model.ID: Sendable {
        public typealias Element = Changes<Model>
        public typealias AsyncIterator = Iterator
        let kind: String
        let accountID: UUID?
        let token: HistoryToken?
        let monitoring: Bool
        public func makeAsyncIterator() -> Iterator { Iterator(history: self) }
        public struct Iterator: AsyncIteratorProtocol {
            let history: History
            var token: HistoryToken?
            var done = false
            init(history: History) { self.history = history; token = history.token }
            public mutating func next() async throws -> Changes<Model>? {
                guard !done else { return nil }
                while true {
                    try _FKStore.requireAccess(.financialData)
                    let data = _FKStore.load()
                    if let t = token, t.store != data.storeID || t.sequence > data.sequence { throw FinanceError.historyTokenInvalid }
                    let since = token?.sequence
                    let changes: Changes<Model> = _FKStore.changes(data, kind: history.kind, accountID: history.accountID, since: since)
                    if since == nil || !changes.inserted.isEmpty || !changes.updated.isEmpty || !changes.deleted.isEmpty {
                        token = changes.newToken
                        if !history.monitoring { done = true }
                        return changes
                    }
                    if !history.monitoring { done = true; return nil }
                    try await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }
    }

    /// whether the data type exists on this device: financial data once `isim finance seed` (or add-account) made it,
    /// orders always
    public static func isDataAvailable(_ type: DataType) -> Bool {
        type == .orders || FileManager.default.fileExists(atPath: _FKStore.file)
    }

    public func authorizationStatus() async throws -> AuthorizationStatus { _FKStore.status }

    /// isim's permission prompt ("Allow … to access your financial data?"), asked once per app
    public func requestAuthorization() async throws -> AuthorizationStatus {
        guard _FKStore.entitled else {
            NSLog("isim FinanceKit: requestAuthorization without the com.apple.developer.financekit entitlement")
            throw FinanceError.dataRestricted(.financialData)
        }
        if _FKStore.status != .notDetermined { return _FKStore.status }
        return await _FKStore.prompt()
    }

    public func accounts(query: AccountQuery) async throws -> [Account] {
        try _FKStore.requireAccess(.financialData)
        return try _FKStore.apply(_FKStore.load().accounts, query.predicate, query.sortDescriptors, query.limit, query.offset)
    }
    public func accountBalances(query: AccountBalanceQuery) async throws -> [AccountBalance] {
        try _FKStore.requireAccess(.financialData)
        return try _FKStore.apply(_FKStore.load().balances, query.predicate, query.sortDescriptors, query.limit, query.offset)
    }
    public func transactions(query: TransactionQuery) async throws -> [Transaction] {
        try _FKStore.requireAccess(.financialData)
        return try _FKStore.apply(_FKStore.load().transactions, query.predicate, query.sortDescriptors, query.limit, query.offset)
    }

    public func accountHistory(since token: HistoryToken? = nil, isMonitoring: Bool = true) -> History<Account> {
        History(kind: "account", accountID: nil, token: token, monitoring: isMonitoring)
    }
    public func accountBalanceHistory(forAccountID accountID: UUID, since token: HistoryToken? = nil, isMonitoring: Bool = true) -> History<AccountBalance> {
        History(kind: "balance", accountID: accountID, token: token, monitoring: isMonitoring)
    }
    public func transactionHistory(forAccountID accountID: UUID, since token: HistoryToken? = nil, isMonitoring: Bool = true) -> History<Transaction> {
        History(kind: "transaction", accountID: accountID, token: token, monitoring: isMonitoring)
    }

    /// whether Wallet has the order, and how its update date compares
    public func containsOrder(matching identifier: FullyQualifiedOrderIdentifier, updatedDate: Date?) async throws -> ContainsOrderResult {
        guard let existing = _FKOrders.find(identifier) else { return .notFound }
        guard let updatedDate, let stored = existing["updatedAt"] as? String, let d = ISO8601DateFormatter().date(from: stored) else { return .exists }
        if d == updatedDate { return .exists }
        return d > updatedDate ? .newerExists : .olderExists
    }

    /// adds a signed order archive (.order) to Wallet, after isim's "Add Order" sheet
    @MainActor public func saveOrder(signedArchive: Data) async throws -> SaveOrderResult {
        try await _FKOrders.save(signedArchive)
    }

    public func enableBackgroundDelivery(for types: [BackgroundDataType], frequency: UpdateFrequency) {
        NSLog("isim FinanceKit: background delivery of %@ (%@) requested; isim runs no background delivery extensions", "\(types)", "\(frequency)")
    }
    public func disableBackgroundDelivery(for types: [BackgroundDataType]) {}
    public func disableAllBackgroundDelivery() {}
}

/// the protocol of a background delivery extension's principal class (isim does not run these extensions)
public protocol BackgroundDeliveryExtensionProviding: Sendable {
    func didReceiveData(for types: [FinanceStore.BackgroundDataType]) async
    func willTerminate() async
}
public protocol BackgroundDeliveryExtension: BackgroundDeliveryExtensionProviding {}

// MARK: - the simulated store

struct _FKData: Codable {
    var storeID = UUID().uuidString
    var sequence = 0
    var accounts: [Account] = []
    var balances: [AccountBalance] = []
    var transactions: [Transaction] = []
    /// one entry per change: kind (account, balance, transaction), op (insert, update, delete), id, account id
    var log: [Entry] = []
    struct Entry: Codable { var seq: Int; var kind: String; var op: String; var id: UUID; var accountID: UUID? }
}

enum _FKStore {
    static var dataRoot: String {
        let env = ProcessInfo.processInfo.environment
        return env["ISIM_DATA"].flatMap { $0.isEmpty ? nil : $0 } ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
    }
    static var file: String { (dataRoot as NSString).appendingPathComponent("Library/isim/FinanceKit/data.json") }

    static let decoder: JSONDecoder = { let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d }()
    static func load() -> _FKData {
        guard let d = FileManager.default.contents(atPath: file), let data = try? decoder.decode(_FKData.self, from: d) else { return _FKData() }
        return data
    }

    static var entitled: Bool {
        let xcent = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        return ((NSDictionary(contentsOfFile: xcent) as? [String: Any])?["com.apple.developer.financekit"] as? Bool) == true
    }
    static let key = "_ISIMFinanceKitAuthorization"
    static var status: AuthorizationStatus {
        switch UserDefaults.standard.string(forKey: key) { case "authorized": return .authorized; case "denied": return .denied; default: return .notDetermined }
    }
    static func requireAccess(_ type: FinanceStore.DataType) throws {
        guard entitled, status == .authorized else { throw FinanceError.dataRestricted(type) }
    }

    @MainActor static func prompt() async -> AuthorizationStatus {
        func answer(_ s: AuthorizationStatus) -> AuthorizationStatus {
            UserDefaults.standard.set(s == .authorized ? "authorized" : "denied", forKey: key)
            NSLog("isim FinanceKit: access %@", s == .authorized ? "allowed" : "denied")
            return s
        }
        if let a = ProcessInfo.processInfo.environment["ISIM_FINANCEKIT_PERMISSION"]?.lowercased(), a == "allow" || a == "deny" {
            return answer(a == "allow" ? .authorized : .denied)
        }
        let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "This app"
        let purpose = Bundle.main.object(forInfoDictionaryKey: "NSFinancialDataUsageDescription") as? String
            ?? "The app will be able to read your Apple Card, Apple Cash and savings account data in Wallet."
        return await withCheckedContinuation { k in
            var top = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController
            while let p = top?.presentedViewController { top = p }
            guard let vc = top else { k.resume(returning: .notDetermined); return }
            let alert = UIAlertController(title: "“\(name)” Would Like to Access Your Financial Data", message: purpose, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Don’t Allow", style: .cancel) { _ in k.resume(returning: answer(.denied)) })
            alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in k.resume(returning: answer(.authorized)) })
            vc.present(alert, animated: true, completion: nil)
        }
    }

    static func apply<T>(_ items: [T], _ predicate: Predicate<T>?, _ sort: [SortDescriptor<T>], _ limit: Int?, _ offset: Int?) throws -> [T] {
        var out = try predicate.map { p in try items.filter { try p.evaluate($0) } } ?? items
        if !sort.isEmpty { out.sort(using: sort) }
        let start = min(out.count, max(0, offset ?? 0))
        out = Array(out[start...])
        if let limit { out = Array(out.prefix(max(0, limit))) }
        return out
    }

    /// the changes after `since` (all current items when nil), from the store's log
    static func changes<Model: Identifiable & Codable & Sendable>(_ data: _FKData, kind: String, accountID: UUID?, since: Int?) -> FinanceStore.Changes<Model> where Model.ID: Sendable {
        let token = FinanceStore.HistoryToken(sequence: data.sequence, store: data.storeID)
        let all: [Model]
        switch kind {
        case "account": all = data.accounts as? [Model] ?? []
        case "balance": all = (data.balances.filter { accountID == nil || $0.accountID == accountID }) as? [Model] ?? []
        default: all = (data.transactions.filter { accountID == nil || $0.accountID == accountID }) as? [Model] ?? []
        }
        guard let since else { return .init(inserted: all, updated: [], deleted: [], newToken: token) }
        var inserted: [Model] = [], updated: [Model] = [], deleted: [Model.ID] = []
        var seen = Set<UUID>()
        for e in data.log.reversed() where e.seq > since && e.kind == kind && (accountID == nil || e.accountID == accountID) {
            guard seen.insert(e.id).inserted else { continue }
            let current = all.first { ($0.id as? UUID) == e.id }
            switch (e.op, current) {
            case ("delete", _), (_, nil): if let id = e.id as? Model.ID { deleted.append(id) }
            case ("insert", let m?): inserted.append(m)
            case (_, let m?): updated.append(m)
            }
        }
        return .init(inserted: inserted.reversed(), updated: updated.reversed(), deleted: deleted, newToken: token)
    }
}

// MARK: - orders

enum _FKOrders {
    static var dir: URL {
        let d = URL(fileURLWithPath: _FKStore.dataRoot).appendingPathComponent("Library/Wallet/Orders")
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }
    static func url(_ id: FullyQualifiedOrderIdentifier) -> URL {
        let safe = "\(id.orderTypeIdentifier)_\(id.orderIdentifier)".map { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" ? $0 : "_" }
        return dir.appendingPathComponent(String(safe) + ".json")
    }
    static func find(_ id: FullyQualifiedOrderIdentifier) -> [String: Any]? {
        (try? Data(contentsOf: url(id))).flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
    }

    @MainActor static func save(_ archive: Data) async throws -> FinanceStore.SaveOrderResult {
        guard let files = try? _FKZip.files(archive), let json = files["order.json"],
              let order = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let type = order["orderTypeIdentifier"] as? String, let ident = order["orderIdentifier"] as? String else {
            throw FinanceError.unknown
        }
        let id = FullyQualifiedOrderIdentifier(orderTypeIdentifier: type, orderIdentifier: ident)
        let updated = order["updatedAt"] as? String ?? ""
        if let existing = find(id), let old = existing["updatedAt"] as? String, old > updated { return .newerExisting }
        let merchant = (order["merchant"] as? [String: Any])?["displayName"] as? String ?? type
        if let a = ProcessInfo.processInfo.environment["ISIM_FINANCEKIT_ORDER"]?.lowercased(), a == "add" || a == "cancel" {
            NSLog("isim FinanceKit: Add Order answered %@ (ISIM_FINANCEKIT_ORDER)", a)
            if a == "cancel" { return .cancelled }
        } else {
            let add: Bool = await withCheckedContinuation { k in
                var top = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows).first { $0.isKeyWindow }?.rootViewController
                while let p = top?.presentedViewController { top = p }
                guard let vc = top else { k.resume(returning: false); return }
                let alert = UIAlertController(title: "Add Order to Wallet?", message: "Track your order from \(merchant) in Wallet.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in k.resume(returning: false) })
                alert.addAction(UIAlertAction(title: "Add", style: .default) { _ in k.resume(returning: true) })
                vc.present(alert, animated: true, completion: nil)
            }
            if !add { NSLog("isim FinanceKit: order %@ %@ not added", type, ident); return .cancelled }
        }
        var saved: [String: Any] = ["orderTypeIdentifier": type, "orderIdentifier": ident, "merchantIdentifier": merchant,
                                    "added": ISO8601DateFormatter().string(from: Date()), "updatedAt": updated]
        if let ws = order["webServiceURL"] as? String { saved["webServiceURL"] = ws }
        if let status = order["status"] as? String { saved["status"] = status }
        let d = try JSONSerialization.data(withJSONObject: saved, options: [.sortedKeys, .prettyPrinted])
        try d.write(to: url(id), options: .atomic)
        NSLog("isim FinanceKit: Wallet added order %@ %@ (%@)", type, ident, merchant)
        return .added
    }
}

/// the files of a ZIP archive (stored and deflated entries), as Wallet reads an .order bundle
enum _FKZip {
    static func files(_ d: Data) throws -> [String: Data] {
        let b = [UInt8](d)
        func u16(_ i: Int) -> Int { i + 1 < b.count ? Int(b[i]) | Int(b[i + 1]) << 8 : 0 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }
        guard b.count >= 22 else { throw FinanceError.unknown }
        var end = -1, i = b.count - 22
        while i >= max(0, b.count - 22 - 65_535) { if u32(i) == 0x0605_4b50 { end = i; break }; i -= 1 }
        guard end >= 0 else { throw FinanceError.unknown }
        var p = u32(end + 16), out: [String: Data] = [:]
        for _ in 0..<u16(end + 10) {
            guard p + 46 <= b.count, u32(p) == 0x0201_4b50 else { throw FinanceError.unknown }
            let method = u16(p + 10), csize = u32(p + 20), usize = u32(p + 24)
            let nlen = u16(p + 28), elen = u16(p + 30), clen = u16(p + 32), local = u32(p + 42)
            guard p + 46 + nlen <= b.count, let name = String(bytes: b[(p + 46)..<(p + 46 + nlen)], encoding: .utf8) else { throw FinanceError.unknown }
            p += 46 + nlen + elen + clen
            if name.hasSuffix("/") { continue }
            guard local + 30 <= b.count, u32(local) == 0x0403_4b50 else { throw FinanceError.unknown }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            guard start + csize <= b.count else { throw FinanceError.unknown }
            let raw = Data(b[start..<(start + csize)])
            if method == 0 { out[name] = raw; continue }
            guard method == 8 else { throw FinanceError.unknown }
            var dst = [UInt8](repeating: 0, count: max(1, usize))
            let n = raw.withUnsafeBytes { s in
                compression_decode_buffer(&dst, usize, s.bindMemory(to: UInt8.self).baseAddress!, raw.count, nil, COMPRESSION_ZLIB)
            }
            guard n == usize else { throw FinanceError.unknown }
            out[name] = Data(dst.prefix(usize))
        }
        return out
    }
}
