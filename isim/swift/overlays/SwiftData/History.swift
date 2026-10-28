// isim SwiftData: history (iOS 18) — the transactions a store recorded: who saved (author, bundle, process), when, and
// the models inserted, updated (with the attributes that changed) and deleted (with a tombstone of the attributes
// marked .preserveValueOnDeletion). The default store keeps them in its database (Store.swift); ModelContext's
// fetchHistory and deleteHistory read and trim them with a HistoryDescriptor. A custom data store provides its own
// (HistoryProviding).
import Foundation

/// A position in a store's history: the transactions after it are the changes since.
public protocol HistoryToken: Comparable, Decodable, Encodable, Hashable, Sendable {
    associatedtype TokenType
    var storeIdentifier: String { get }
    var tokenValue: Self.TokenType? { get }
}

/// A transaction a store recorded: one save.
public protocol HistoryTransaction: Hashable, Identifiable, Sendable {
    associatedtype TokenType: HistoryToken
    associatedtype TransactionIdentifier
    var transactionIdentifier: Self.TransactionIdentifier { get }
    var changes: [HistoryChange] { get }
    var storeIdentifier: String { get }
    var author: String? { get }
    var timestamp: Date { get }
    var token: Self.TokenType { get }
}

/// One change in a transaction.
public enum HistoryChange: Sendable {
    case insert(any HistoryInsert)
    case update(any HistoryUpdate)
    case delete(any HistoryDelete)
    public var changedPersistentIdentifier: PersistentIdentifier {
        switch self {
        case .insert(let c): return c.changedPersistentIdentifier
        case .update(let c): return c.changedPersistentIdentifier
        case .delete(let c): return c.changedPersistentIdentifier
        }
    }
}

public protocol HistoryInsert<Model>: Hashable, Identifiable, Sendable {
    associatedtype Model: PersistentModel
    associatedtype ChangeIdentifier
    associatedtype TransactionIdentifier
    var changeIdentifier: Self.ChangeIdentifier { get }
    var transactionIdentifier: Self.TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
}

public protocol HistoryUpdate<Model>: Hashable, Identifiable, Sendable {
    associatedtype Model: PersistentModel
    associatedtype ChangeIdentifier
    associatedtype TransactionIdentifier
    typealias PropertyUpdate = any PartialKeyPath<Self.Model> & Sendable
    var changeIdentifier: Self.ChangeIdentifier { get }
    var transactionIdentifier: Self.TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
    var updatedAttributes: [any PartialKeyPath<Self.Model> & Sendable] { get }
}

public protocol HistoryDelete<Model>: Hashable, Identifiable, Sendable {
    associatedtype Model: PersistentModel
    associatedtype ChangeIdentifier
    associatedtype TransactionIdentifier
    var changeIdentifier: Self.ChangeIdentifier { get }
    var transactionIdentifier: Self.TransactionIdentifier { get }
    var changedPersistentIdentifier: PersistentIdentifier { get }
    var tombstone: HistoryTombstone<Self.Model> { get }
}

/// a model's key path as the Sendable key path the history API hands out (Sendable is a marker: same representation)
func _sendablePath<M>(_ kp: AnyKeyPath, _: M.Type) -> (any PartialKeyPath<M> & Sendable)? {
    guard let p = kp as? PartialKeyPath<M> else { return nil }
    return unsafeBitCast(p, to: (any PartialKeyPath<M> & Sendable).self)
}

/// The values a deleted model kept: its attributes marked .preserveValueOnDeletion.
public struct HistoryTombstone<Model: PersistentModel>: @unchecked Sendable {
    let values: [String: Any]
    init(json: [String: Any]) { values = json }
    /// the attribute's value when the model was deleted (nil: not preserved)
    public subscript(keyPath: PartialKeyPath<Model>) -> (any Sendable)? {
        let info = _ModelInfo.of(Model.self)
        guard let i = info.byKeyPath[keyPath], let j = values[info.properties[i].name] else { return nil }
        if j is NSNull { return nil }
        func decode<V: Decodable>(_ t: V.Type) -> Any? { try? _decodeJSON(t, j) }
        var t = info.properties[i].valueType
        if let o = t as? _OptionalWrapped.Type { t = o._wrapped }
        guard let d = t as? any Decodable.Type, let v = decode(d) else { return nil }
        return unsafeBitCast(v, to: (any Sendable).self)
    }
}
protocol _OptionalWrapped { static var _wrapped: Any.Type { get } }
extension Optional: _OptionalWrapped { static var _wrapped: Any.Type { Wrapped.self } }

// MARK: - the default store's history

public struct DefaultHistoryToken: HistoryToken {
    public typealias TokenType = Int64
    public var storeIdentifier: String
    public var tokenValue: Int64?
    init(storeIdentifier: String, tokenValue: Int64) { self.storeIdentifier = storeIdentifier; self.tokenValue = tokenValue }
    public static func < (a: DefaultHistoryToken, b: DefaultHistoryToken) -> Bool {
        (a.storeIdentifier, a.tokenValue ?? 0) < (b.storeIdentifier, b.tokenValue ?? 0)
    }
}

public struct DefaultHistoryTransaction: HistoryTransaction {
    public typealias TokenType = DefaultHistoryToken
    public typealias TransactionIdentifier = Int64
    public let transactionIdentifier: Int64
    public let changes: [HistoryChange]
    public let storeIdentifier: String
    public let author: String?
    public let timestamp: Date
    public let token: DefaultHistoryToken
    public let bundleIdentifier: String
    public let processIdentifier: String
    public var id: Int64 { transactionIdentifier }
    public static func == (a: DefaultHistoryTransaction, b: DefaultHistoryTransaction) -> Bool {
        a.storeIdentifier == b.storeIdentifier && a.transactionIdentifier == b.transactionIdentifier
    }
    public func hash(into h: inout Hasher) { h.combine(storeIdentifier); h.combine(transactionIdentifier) }
}

public struct DefaultHistoryInsert<Model: PersistentModel>: HistoryInsert {
    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier
    public var id: Int64 { changeIdentifier }
    public static func == (a: DefaultHistoryInsert<Model>, b: DefaultHistoryInsert<Model>) -> Bool { a.changeIdentifier == b.changeIdentifier && a.changedPersistentIdentifier == b.changedPersistentIdentifier }
    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier); hasher.combine(changedPersistentIdentifier) }
}

public struct DefaultHistoryUpdate<Model: PersistentModel>: HistoryUpdate, @unchecked Sendable {
    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier
    public let updatedAttributes: [any PartialKeyPath<Model> & Sendable]
    public var id: Int64 { changeIdentifier }
    public static func == (a: DefaultHistoryUpdate<Model>, b: DefaultHistoryUpdate<Model>) -> Bool { a.changeIdentifier == b.changeIdentifier && a.changedPersistentIdentifier == b.changedPersistentIdentifier }
    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier); hasher.combine(changedPersistentIdentifier) }
}

public struct DefaultHistoryDelete<Model: PersistentModel>: HistoryDelete {
    public let changeIdentifier: Int64
    public let transactionIdentifier: Int64
    public let changedPersistentIdentifier: PersistentIdentifier
    public let tombstone: HistoryTombstone<Model>
    public var id: Int64 { changeIdentifier }
    public static func == (a: DefaultHistoryDelete<Model>, b: DefaultHistoryDelete<Model>) -> Bool { a.changeIdentifier == b.changeIdentifier && a.changedPersistentIdentifier == b.changedPersistentIdentifier }
    public func hash(into hasher: inout Hasher) { hasher.combine(changeIdentifier); hasher.combine(changedPersistentIdentifier) }
}

/// Which transactions to fetch or delete: a predicate, a sort and a limit (0: no limit).
public struct HistoryDescriptor<TransactionType: HistoryTransaction> {
    public var predicate: Predicate<TransactionType>?
    public var sortBy: [SortDescriptor<TransactionType>]
    public var fetchLimit: UInt64 = 0
    public init(predicate: Predicate<TransactionType>? = nil) { self.predicate = predicate; sortBy = [] }
    public init(predicate: Predicate<TransactionType>? = nil, sortBy: [SortDescriptor<TransactionType>]) { self.predicate = predicate; self.sortBy = sortBy }
}

// MARK: - context

extension ModelContext {
    /// the transactions the container's store recorded that match the descriptor
    public func fetchHistory<T>(_ descriptor: HistoryDescriptor<T>) throws -> [T] where T: HistoryTransaction {
        try store.fetchHistory(descriptor, schema: container.schema)
    }
    /// removes the matching transactions from the store's history
    public func deleteHistory<T>(_ descriptor: HistoryDescriptor<T>) throws where T: HistoryTransaction {
        try store.deleteHistory(descriptor, schema: container.schema)
    }
}
