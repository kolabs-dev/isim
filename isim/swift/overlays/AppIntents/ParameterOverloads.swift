// isim AppIntents (issue #850): Apple's overloads of IntentParameter, EntityProperty and IntentParameterContext per value
// type, with Apple's signatures and `where` clauses, and their nested enums (units, control styles, date kinds). Generated
// once from Apple's AppIntents documentation (the 2026-10 sweep), one declaration per documented overload; adapted: the
// bodies hand the arguments to isim's engine (AppIntents.swift, IntentValue.swift): title, description, default value
// (a measurement's from defaultValue + defaultUnit), requestValueDialog, options providers and resolvers; the rest is kept
// for the getters (controlStyle, defaultUnit, dateKind, …). The overloads on FileEntity and AppUnionValue values are not
// here yet (those protocols are not in isim). The Codable-value overloads (iOS 26) are disfavored, so the concrete ones
// (String, Int, …) win, as on iOS.
import Foundation
import SwiftUI
import CoreLocation
import CoreSpotlight
import UniformTypeIdentifiers

extension EntityProperty {
    public convenience init<Entity>(customIndexingKey: CSCustomAttributeKey) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init<Entity>(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
}
extension EntityProperty where Value.ValueType: Decodable, Value.ValueType: Encodable {
    @_disfavoredOverload public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    @_disfavoredOverload public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    @_disfavoredOverload public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    @_disfavoredOverload public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    @_disfavoredOverload public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    @_disfavoredOverload public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    @_disfavoredOverload public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    @_disfavoredOverload public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    @_disfavoredOverload public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType: AppEntity {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType: AppEnum {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType: _IntentValueRepresentable {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType: _SystemIntentValue {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == AttributedString {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Bool {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == CLPlacemark {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Calendar.RecurrenceRule {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Date {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == DateComponents {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Double {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Swift.Duration {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Int {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == IntentCurrencyAmount {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == IntentFile {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == IntentPaymentMethod {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == IntentPerson {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitAcceleration> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitAngle> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitArea> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitConcentrationMass> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitDispersion> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitDuration> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitElectricCharge> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitElectricCurrent> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitElectricPotentialDifference> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitElectricResistance> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitEnergy> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitFrequency> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitFuelEfficiency> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitIlluminance> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitInformationStorage> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitLength> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitMass> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitPower> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitPressure> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitSpeed> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitTemperature> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == Measurement<UnitVolume> {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == String {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension EntityProperty where Value.ValueType == URL {
    public convenience init(customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: nil, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init(title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
    }
    public convenience init(title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>) {
        self.init(_title: title, identifier: nil, value: nil)
        _options = ["indexingKey": indexingKey]
    }
    public convenience init<Entity>(identifier: String, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: nil, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, customIndexingKey: CSCustomAttributeKey, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["customIndexingKey": customIndexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, asyncGetter: @escaping @Sendable (Entity) async throws -> Value) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        let get = asyncGetter
        _asyncGetter = { e in guard let e = e as? Entity else { return nil }; return try await get(e) }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getSetter: WritableKeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getSetter] } }
    }
    public convenience init<Entity>(identifier: String, title: LocalizedStringResource, indexingKey: PartialKeyPath<CSSearchableItemAttributeSet>, getter: KeyPath<Entity, Value>) where Entity : AppEntity {
        self.init(_title: title, identifier: identifier, value: nil)
        _options = ["indexingKey": indexingKey]
        _getter = { ($0 as? Entity).map { $0[keyPath: getter] } }
    }
}
extension IntentParameter {
    public convenience init<Entity>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) where Entity : AppEntity, Value.ValueType == EntityCollection<Entity> {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public enum DateKind: Hashable, Sendable {
        case date
        case dateTime
        case time
    }
    public enum DoubleControlStyle: Hashable, Sendable {
        case field
        case slider
        case stepper
    }
    public enum IntControlStyle: Hashable, Sendable {
        case field
        case stepper
    }
    public enum PlacemarkDisplayStyle: Hashable, Sendable {
        case address
        case city
        case name
    }
    public enum ValueState {
        case set(Value)
        case unset
    }
    public typealias InclusiveRange<Bound> = (lowerBound: Bound, upperBound: Bound) where Bound : Comparable
}
extension IntentParameter where Value.UnwrappedType: Collection, Value.ValueType: AppEntity {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<Query>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Query>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Query>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Query>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.UnwrappedType: Collection, Value.ValueType: _IntentValueRepresentable {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
}
extension IntentParameter where Value.UnwrappedType: Collection, Value.ValueType: _SystemIntentValue {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
}
extension IntentParameter where Value.UnwrappedType: Collection, Value.ValueType == IntentPerson {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, size: IntentCollectionSize, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, size: [IntentWidgetFamily : IntentCollectionSize], inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: nil, options: ["mode": mode as Any, "size": size as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
}
extension IntentParameter where Value.UnwrappedType: Collection, Value.ValueType == URL {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: [Value.ValueType?], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: [Value.ValueType?], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: [Value.ValueType?], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: [Value.ValueType?], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: AppEntity, Value.ValueType: AppEnum {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases)) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases)) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: Decodable, Value.ValueType: Encodable {
    @_disfavoredOverload public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    @_disfavoredOverload public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    @_disfavoredOverload public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    @_disfavoredOverload public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    @_disfavoredOverload public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    @_disfavoredOverload public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    @_disfavoredOverload public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    @_disfavoredOverload public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: AppEntity {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Query>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Query>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, query: Query) where Query : EntityQuery, Value.ValueType == Query.Entity {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["query"] = query
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: AppEnum {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases)) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases)) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, requestDisambiguationDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, supportedValues: [Value.ValueType] = Array(Value.ValueType.allCases), @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["requestDisambiguationDialog": requestDisambiguationDialog as Any, "inputConnectionBehavior": inputConnectionBehavior as Any, "supportedValues": supportedValues as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: _IntentValueRepresentable {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType: _SystemIntentValue {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, Value.ValueType == OptionsProvider.DefaultValue.ValueType {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType == AttributedString {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == AttributedString {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == AttributedString {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == AttributedString {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == AttributedString {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType == Bool {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: Bool.IntentDisplayName? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayName": displayName as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: Bool.IntentDisplayName? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayName": displayName as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: Bool.IntentDisplayName? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayName": displayName as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayName: Bool.IntentDisplayName? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayName": displayName as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var displayName: Bool.IntentDisplayName? { _isimOption("displayName") }
}
extension IntentParameter where Value.ValueType == CLPlacemark {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == CLPlacemark {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle = .name, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["displayStyle": displayStyle as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle? { _isimOption("displayStyle") }
}
extension IntentParameter where Value.ValueType == Calendar.RecurrenceRule {
    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Calendar.RecurrenceRule {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Calendar.RecurrenceRule {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Calendar.RecurrenceRule {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Calendar.RecurrenceRule {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType == Date {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Date {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var dateKind: IntentParameter<Value>.DateKind? { _isimOption("dateKind", "kind") }
}
extension IntentParameter where Value.ValueType == DateComponents {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == DateComponents {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, kind: IntentParameter<Value>.DateKind = .dateTime, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["kind": kind as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var dateKind: IntentParameter<Value>.DateKind? { _isimOption("dateKind", "kind") }
}
extension IntentParameter where Value.ValueType == Double {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Double {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Double {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Double {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Double {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.DoubleControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var controlStyle: IntentParameter<Value>.DoubleControlStyle? { _isimOption("controlStyle") }
}
extension IntentParameter where Value.ValueType == Swift.Duration {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Swift.Duration {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Swift.Duration {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Swift.Duration {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Swift.Duration {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, defaultUnit: IntentParameter<Value>.DurationUnit? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum DurationUnit: Hashable, Sendable {
        case hours
        case microseconds
        case milliseconds
        case minutes
        case nanoseconds
        case picoseconds
        case seconds
    }
    public final var defaultUnit: IntentParameter<Value>.DurationUnit? { _isimOption("defaultUnit", "unit") }
    public final var unit: IntentParameter<Value>.DurationUnit? { _isimOption("unit", "defaultUnit") }
}
extension IntentParameter where Value.ValueType == Int {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Int {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Int {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Int {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Int {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, controlStyle: IntentParameter<Value>.IntControlStyle = .stepper, inclusiveRange: IntentParameter<Value>.InclusiveRange<Value.ValueType>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["controlStyle": controlStyle as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var controlStyle: IntentParameter<Value>.IntControlStyle? { _isimOption("controlStyle") }
}
extension IntentParameter where Value.ValueType == IntentCurrencyAmount {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentCurrencyAmount {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, currencyCodes: [String] = [], inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["currencyCodes": currencyCodes as Any, "inclusiveRange": inclusiveRange as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var currencyCodes: [String]? { _isimOption("currencyCodes") }
    public final var inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? { _isimOption("inclusiveRange") }
}
extension IntentParameter where Value.ValueType == IntentFile {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedTypeIdentifiers: [String] = ["public.item"], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedTypeIdentifiers": supportedTypeIdentifiers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, supportedTypeIdentifiers: [String] = ["public.item"], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["supportedTypeIdentifiers": supportedTypeIdentifiers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, supportedTypeIdentifiers: [String] = ["public.item"], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentFile {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["supportedTypeIdentifiers": supportedTypeIdentifiers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedContentTypes: [UTType] = [UTType.item], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedContentTypes": supportedContentTypes as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, supportedTypeIdentifiers: [String] = ["public.item"], requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["supportedTypeIdentifiers": supportedTypeIdentifiers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType == IntentPaymentMethod {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPaymentMethod {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameter where Value.ValueType == IntentPerson {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == IntentPerson {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, mode: IntentPerson.ParameterMode = .contact, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["mode": mode as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var parameterMode: IntentPerson.ParameterMode? { _isimOption("parameterMode", "mode") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitAcceleration> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Acceleration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Acceleration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Acceleration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Acceleration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAcceleration> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAcceleration> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAcceleration> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAcceleration> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Acceleration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Acceleration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Acceleration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Acceleration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Acceleration: Hashable, Sendable {
        case gravity
        case metersPerSecondSquared
        var _isimUnit: UnitAcceleration {
            switch self {
            case .gravity: return .gravity
            case .metersPerSecondSquared: return .metersPerSecondSquared
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Acceleration? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Acceleration? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitAngle> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Angle? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Angle, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Angle? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Angle, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAngle> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAngle> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAngle> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitAngle> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Angle? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Angle, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Angle? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Angle, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Angle: Hashable, Sendable {
        case arcMinutes
        case arcSeconds
        case degrees
        case gradians
        case radians
        case revolutions
        var _isimUnit: UnitAngle {
            switch self {
            case .arcMinutes: return .arcMinutes
            case .arcSeconds: return .arcSeconds
            case .degrees: return .degrees
            case .gradians: return .gradians
            case .radians: return .radians
            case .revolutions: return .revolutions
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Angle? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Angle? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitArea> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Area? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Area, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Area? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Area, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitArea> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitArea> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitArea> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitArea> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Area? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Area, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Area? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Area, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Area: Hashable, Sendable {
        case acres
        case ares
        case hectares
        case squareCentimeters
        case squareFeet
        case squareInches
        case squareKilometers
        case squareMegameters
        case squareMeters
        case squareMicrometers
        case squareMiles
        case squareMillimeters
        case squareNanometers
        case squareYards
        var _isimUnit: UnitArea {
            switch self {
            case .acres: return .acres
            case .ares: return .ares
            case .hectares: return .hectares
            case .squareCentimeters: return .squareCentimeters
            case .squareFeet: return .squareFeet
            case .squareInches: return .squareInches
            case .squareKilometers: return .squareKilometers
            case .squareMegameters: return .squareMegameters
            case .squareMeters: return .squareMeters
            case .squareMicrometers: return .squareMicrometers
            case .squareMiles: return .squareMiles
            case .squareMillimeters: return .squareMillimeters
            case .squareNanometers: return .squareNanometers
            case .squareYards: return .squareYards
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Area? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Area? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitConcentrationMass> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ConcentrationMass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ConcentrationMass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ConcentrationMass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ConcentrationMass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitConcentrationMass> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitConcentrationMass> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitConcentrationMass> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitConcentrationMass> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ConcentrationMass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ConcentrationMass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ConcentrationMass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ConcentrationMass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum ConcentrationMass: Hashable, Sendable {
        case gramsPerLiter
        case milligramsPerDeciliter
        var _isimUnit: UnitConcentrationMass {
            switch self {
            case .gramsPerLiter: return .gramsPerLiter
            case .milligramsPerDeciliter: return .milligramsPerDeciliter
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.ConcentrationMass? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.ConcentrationMass? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitDispersion> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Dispersion? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Dispersion, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Dispersion? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Dispersion, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDispersion> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDispersion> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDispersion> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDispersion> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Dispersion? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Dispersion, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Dispersion? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Dispersion, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Dispersion: Hashable, Sendable {
        case partsPerMillion
        var _isimUnit: UnitDispersion {
            switch self {
            case .partsPerMillion: return .partsPerMillion
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Dispersion? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Dispersion? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitDuration> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Duration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Duration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Duration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Duration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDuration> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDuration> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDuration> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitDuration> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Duration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Duration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Duration? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Duration, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Duration: Hashable, Sendable {
        case hours
        case microseconds
        case milliseconds
        case minutes
        case nanoseconds
        case picoseconds
        case seconds
        var _isimUnit: UnitDuration {
            switch self {
            case .hours: return .hours
            case .microseconds: return .microseconds
            case .milliseconds: return .milliseconds
            case .minutes: return .minutes
            case .nanoseconds: return .nanoseconds
            case .picoseconds: return .picoseconds
            case .seconds: return .seconds
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Duration? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Duration? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitElectricCharge> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCharge? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCharge, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCharge? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCharge, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCharge> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCharge> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCharge> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCharge> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCharge? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCharge, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCharge? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCharge, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum ElectricCharge: Hashable, Sendable {
        case ampereHours
        case coulombs
        case kiloampereHours
        case megaampereHours
        case microampereHours
        case milliampereHours
        var _isimUnit: UnitElectricCharge {
            switch self {
            case .ampereHours: return .ampereHours
            case .coulombs: return .coulombs
            case .kiloampereHours: return .kiloampereHours
            case .megaampereHours: return .megaampereHours
            case .microampereHours: return .microampereHours
            case .milliampereHours: return .milliampereHours
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.ElectricCharge? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.ElectricCharge? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitElectricCurrent> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCurrent? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCurrent, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCurrent? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCurrent, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCurrent> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCurrent> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCurrent> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricCurrent> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCurrent? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCurrent, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricCurrent? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricCurrent, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum ElectricCurrent: Hashable, Sendable {
        case amperes
        case kiloamperes
        case megaamperes
        case microamperes
        case milliamperes
        var _isimUnit: UnitElectricCurrent {
            switch self {
            case .amperes: return .amperes
            case .kiloamperes: return .kiloamperes
            case .megaamperes: return .megaamperes
            case .microamperes: return .microamperes
            case .milliamperes: return .milliamperes
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.ElectricCurrent? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.ElectricCurrent? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitElectricPotentialDifference> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricPotentialDifference? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricPotentialDifference, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricPotentialDifference? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricPotentialDifference, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricPotentialDifference> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricPotentialDifference> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricPotentialDifference> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricPotentialDifference> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricPotentialDifference? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricPotentialDifference, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricPotentialDifference? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricPotentialDifference, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum ElectricPotentialDifference: Hashable, Sendable {
        case kilovolts
        case megavolts
        case microvolts
        case millivolts
        case volts
        var _isimUnit: UnitElectricPotentialDifference {
            switch self {
            case .kilovolts: return .kilovolts
            case .megavolts: return .megavolts
            case .microvolts: return .microvolts
            case .millivolts: return .millivolts
            case .volts: return .volts
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.ElectricPotentialDifference? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.ElectricPotentialDifference? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitElectricResistance> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricResistance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricResistance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricResistance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricResistance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricResistance> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricResistance> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricResistance> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitElectricResistance> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricResistance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricResistance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.ElectricResistance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.ElectricResistance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum ElectricResistance: Hashable, Sendable {
        case kiloohms
        case megaohms
        case microohms
        case milliohms
        case ohms
        var _isimUnit: UnitElectricResistance {
            switch self {
            case .kiloohms: return .kiloohms
            case .megaohms: return .megaohms
            case .microohms: return .microohms
            case .milliohms: return .milliohms
            case .ohms: return .ohms
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.ElectricResistance? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.ElectricResistance? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitEnergy> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Energy? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Energy, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Energy? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Energy, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitEnergy> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitEnergy> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitEnergy> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitEnergy> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Energy? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Energy, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Energy? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Energy, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Energy: Hashable, Sendable {
        case calories
        case joules
        case kilocalories
        case kilojoules
        case kilowattHours
        var _isimUnit: UnitEnergy {
            switch self {
            case .calories: return .calories
            case .joules: return .joules
            case .kilocalories: return .kilocalories
            case .kilojoules: return .kilojoules
            case .kilowattHours: return .kilowattHours
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Energy? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Energy? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitFrequency> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Frequency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Frequency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Frequency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Frequency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFrequency> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFrequency> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFrequency> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFrequency> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Frequency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Frequency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Frequency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Frequency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Frequency: Hashable, Sendable {
        case framesPerSecond
        case gigahertz
        case hertz
        case kilohertz
        case megahertz
        case microhertz
        case millihertz
        case nanohertz
        case terahertz
        var _isimUnit: UnitFrequency {
            switch self {
            case .framesPerSecond: return .framesPerSecond
            case .gigahertz: return .gigahertz
            case .hertz: return .hertz
            case .kilohertz: return .kilohertz
            case .megahertz: return .megahertz
            case .microhertz: return .microhertz
            case .millihertz: return .millihertz
            case .nanohertz: return .nanohertz
            case .terahertz: return .terahertz
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Frequency? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Frequency? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitFuelEfficiency> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.FuelEfficiency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.FuelEfficiency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.FuelEfficiency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.FuelEfficiency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFuelEfficiency> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFuelEfficiency> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFuelEfficiency> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitFuelEfficiency> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.FuelEfficiency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.FuelEfficiency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.FuelEfficiency? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.FuelEfficiency, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum FuelEfficiency: Hashable, Sendable {
        case litersPer100Kilometers
        case milesPerGallon
        case milesPerImperialGallon
        var _isimUnit: UnitFuelEfficiency {
            switch self {
            case .litersPer100Kilometers: return .litersPer100Kilometers
            case .milesPerGallon: return .milesPerGallon
            case .milesPerImperialGallon: return .milesPerImperialGallon
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.FuelEfficiency? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.FuelEfficiency? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitIlluminance> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Illuminance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Illuminance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Illuminance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Illuminance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitIlluminance> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitIlluminance> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitIlluminance> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitIlluminance> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Illuminance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Illuminance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Illuminance? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Illuminance, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Illuminance: Hashable, Sendable {
        case lux
        var _isimUnit: UnitIlluminance {
            switch self {
            case .lux: return .lux
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Illuminance? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Illuminance? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitInformationStorage> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.InformationStorage? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.InformationStorage, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.InformationStorage? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.InformationStorage, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitInformationStorage> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitInformationStorage> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitInformationStorage> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitInformationStorage> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.InformationStorage? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.InformationStorage, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.InformationStorage? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.InformationStorage, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum InformationStorage: Hashable, Sendable {
        case bits
        case bytes
        case exabits
        case exabytes
        case exbibits
        case exbibytes
        case gibibits
        case gibibytes
        case gigabits
        case gigabytes
        case kibibits
        case kibibytes
        case kilobits
        case kilobytes
        case mebibits
        case mebibytes
        case megabits
        case megabytes
        case nibbles
        case pebibits
        case pebibytes
        case petabits
        case petabytes
        case tebibits
        case tebibytes
        case terabits
        case terabytes
        case yobibits
        case yobibytes
        case yottabits
        case yottabytes
        case zebibits
        case zebibytes
        case zettabits
        case zettabytes
        var _isimUnit: UnitInformationStorage {
            switch self {
            case .bits: return .bits
            case .bytes: return .bytes
            case .exabits: return .exabits
            case .exabytes: return .exabytes
            case .exbibits: return .exbibits
            case .exbibytes: return .exbibytes
            case .gibibits: return .gibibits
            case .gibibytes: return .gibibytes
            case .gigabits: return .gigabits
            case .gigabytes: return .gigabytes
            case .kibibits: return .kibibits
            case .kibibytes: return .kibibytes
            case .kilobits: return .kilobits
            case .kilobytes: return .kilobytes
            case .mebibits: return .mebibits
            case .mebibytes: return .mebibytes
            case .megabits: return .megabits
            case .megabytes: return .megabytes
            case .nibbles: return .nibbles
            case .pebibits: return .pebibits
            case .pebibytes: return .pebibytes
            case .petabits: return .petabits
            case .petabytes: return .petabytes
            case .tebibits: return .tebibits
            case .tebibytes: return .tebibytes
            case .terabits: return .terabits
            case .terabytes: return .terabytes
            case .yobibits: return .yobibits
            case .yobibytes: return .yobibytes
            case .yottabits: return .yottabits
            case .yottabytes: return .yottabytes
            case .zebibits: return .zebibits
            case .zebibytes: return .zebibytes
            case .zettabits: return .zettabits
            case .zettabytes: return .zettabytes
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.InformationStorage? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.InformationStorage? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitLength> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Length? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Length, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Length? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Length, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitLength> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitLength> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitLength> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitLength> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Length? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Length, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Length? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Length, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Length: Hashable, Sendable {
        case astronomicalUnits
        case centimeters
        case decameters
        case decimeters
        case fathoms
        case feet
        case furlongs
        case hectometers
        case inches
        case kilometers
        case lightyears
        case megameters
        case meters
        case micrometers
        case miles
        case millimeters
        case nanometers
        case nauticalMiles
        case parsecs
        case picometers
        case scandinavianMiles
        case yards
        var _isimUnit: UnitLength {
            switch self {
            case .astronomicalUnits: return .astronomicalUnits
            case .centimeters: return .centimeters
            case .decameters: return .decameters
            case .decimeters: return .decimeters
            case .fathoms: return .fathoms
            case .feet: return .feet
            case .furlongs: return .furlongs
            case .hectometers: return .hectometers
            case .inches: return .inches
            case .kilometers: return .kilometers
            case .lightyears: return .lightyears
            case .megameters: return .megameters
            case .meters: return .meters
            case .micrometers: return .micrometers
            case .miles: return .miles
            case .millimeters: return .millimeters
            case .nanometers: return .nanometers
            case .nauticalMiles: return .nauticalMiles
            case .parsecs: return .parsecs
            case .picometers: return .picometers
            case .scandinavianMiles: return .scandinavianMiles
            case .yards: return .yards
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Length? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Length? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitMass> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Mass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Mass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Mass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Mass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitMass> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitMass> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitMass> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitMass> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Mass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Mass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Mass? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Mass, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Mass: Hashable, Sendable {
        case carats
        case centigrams
        case decigrams
        case grams
        case kilograms
        case metricTons
        case micrograms
        case milligrams
        case nanograms
        case ounces
        case ouncesTroy
        case picograms
        case pounds
        case shortTons
        case slugs
        case stones
        var _isimUnit: UnitMass {
            switch self {
            case .carats: return .carats
            case .centigrams: return .centigrams
            case .decigrams: return .decigrams
            case .grams: return .grams
            case .kilograms: return .kilograms
            case .metricTons: return .metricTons
            case .micrograms: return .micrograms
            case .milligrams: return .milligrams
            case .nanograms: return .nanograms
            case .ounces: return .ounces
            case .ouncesTroy: return .ouncesTroy
            case .picograms: return .picograms
            case .pounds: return .pounds
            case .shortTons: return .shortTons
            case .slugs: return .slugs
            case .stones: return .stones
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Mass? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Mass? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitPower> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Power? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Power, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Power? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Power, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPower> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPower> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPower> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPower> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Power? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Power, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Power? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Power, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Power: Hashable, Sendable {
        case femtowatts
        case gigawatts
        case horsepower
        case kilowatts
        case megawatts
        case microwatts
        case milliwatts
        case nanowatts
        case picowatts
        case terawatts
        case watts
        var _isimUnit: UnitPower {
            switch self {
            case .femtowatts: return .femtowatts
            case .gigawatts: return .gigawatts
            case .horsepower: return .horsepower
            case .kilowatts: return .kilowatts
            case .megawatts: return .megawatts
            case .microwatts: return .microwatts
            case .milliwatts: return .milliwatts
            case .nanowatts: return .nanowatts
            case .picowatts: return .picowatts
            case .terawatts: return .terawatts
            case .watts: return .watts
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Power? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Power? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitPressure> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Pressure? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Pressure, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Pressure? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Pressure, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPressure> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPressure> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPressure> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitPressure> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Pressure? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Pressure, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Pressure? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Pressure, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Pressure: Hashable, Sendable {
        case bars
        case gigapascals
        case hectopascals
        case inchesOfMercury
        case kilopascals
        case megapascals
        case millibars
        case millimetersOfMercury
        case newtonsPerMetersSquared
        case poundsForcePerSquareInch
        var _isimUnit: UnitPressure {
            switch self {
            case .bars: return .bars
            case .gigapascals: return .gigapascals
            case .hectopascals: return .hectopascals
            case .inchesOfMercury: return .inchesOfMercury
            case .kilopascals: return .kilopascals
            case .megapascals: return .megapascals
            case .millibars: return .millibars
            case .millimetersOfMercury: return .millimetersOfMercury
            case .newtonsPerMetersSquared: return .newtonsPerMetersSquared
            case .poundsForcePerSquareInch: return .poundsForcePerSquareInch
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Pressure? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Pressure? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitSpeed> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Speed? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Speed, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Speed? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Speed, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitSpeed> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitSpeed> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitSpeed> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitSpeed> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Speed? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Speed, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Speed? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Speed, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Speed: Hashable, Sendable {
        case kilometersPerHour
        case knots
        case metersPerSecond
        case milesPerHour
        var _isimUnit: UnitSpeed {
            switch self {
            case .kilometersPerHour: return .kilometersPerHour
            case .knots: return .knots
            case .metersPerSecond: return .metersPerSecond
            case .milesPerHour: return .milesPerHour
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Speed? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Speed? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitTemperature> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Temperature? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Temperature, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Temperature? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Temperature, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitTemperature> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitTemperature> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitTemperature> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitTemperature> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Temperature? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Temperature, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Temperature? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Temperature, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Temperature: Hashable, Sendable {
        case celsius
        case fahrenheit
        case kelvin
        var _isimUnit: UnitTemperature {
            switch self {
            case .celsius: return .celsius
            case .fahrenheit: return .fahrenheit
            case .kelvin: return .kelvin
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Temperature? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Temperature? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == Measurement<UnitVolume> {
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Volume? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Volume, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Volume? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Volume, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitVolume> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitVolume> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitVolume> {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec, optionsProvider: OptionsProvider) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == Measurement<UnitVolume> {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Volume? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Volume, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, defaultUnit: IntentParameter<Value>.Volume? = nil, defaultUnitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue.map { Measurement(value: $0, unit: defaultUnit?._isimUnit ?? .baseUnit()) }, requestValueDialog: requestValueDialog, options: ["defaultUnit": defaultUnit as Any, "defaultUnitAdjustForLocale": defaultUnitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, defaultValue: Double? = nil, unit: IntentParameter<Value>.Volume, unitAdjustForLocale: Bool = false, supportsNegativeNumbers: Bool = true, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["unit": unit as Any, "unitAdjustForLocale": unitAdjustForLocale as Any, "supportsNegativeNumbers": supportsNegativeNumbers as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public enum Volume: Hashable, Sendable {
        case acreFeet
        case bushels
        case centiliters
        case cubicCentimeters
        case cubicDecimeters
        case cubicFeet
        case cubicInches
        case cubicKilometers
        case cubicMeters
        case cubicMiles
        case cubicMillimeters
        case cubicYards
        case cups
        case deciliters
        case fluidOunces
        case gallons
        case imperialFluidOunces
        case imperialGallons
        case imperialPints
        case imperialQuarts
        case imperialTablespoons
        case imperialTeaspoons
        case kiloliters
        case liters
        case megaliters
        case metricCups
        case milliliters
        case pints
        case quarts
        case tablespoons
        case teaspoons
        var _isimUnit: UnitVolume {
            switch self {
            case .acreFeet: return .acreFeet
            case .bushels: return .bushels
            case .centiliters: return .centiliters
            case .cubicCentimeters: return .cubicCentimeters
            case .cubicDecimeters: return .cubicDecimeters
            case .cubicFeet: return .cubicFeet
            case .cubicInches: return .cubicInches
            case .cubicKilometers: return .cubicKilometers
            case .cubicMeters: return .cubicMeters
            case .cubicMiles: return .cubicMiles
            case .cubicMillimeters: return .cubicMillimeters
            case .cubicYards: return .cubicYards
            case .cups: return .cups
            case .deciliters: return .deciliters
            case .fluidOunces: return .fluidOunces
            case .gallons: return .gallons
            case .imperialFluidOunces: return .imperialFluidOunces
            case .imperialGallons: return .imperialGallons
            case .imperialPints: return .imperialPints
            case .imperialQuarts: return .imperialQuarts
            case .imperialTablespoons: return .imperialTablespoons
            case .imperialTeaspoons: return .imperialTeaspoons
            case .kiloliters: return .kiloliters
            case .liters: return .liters
            case .megaliters: return .megaliters
            case .metricCups: return .metricCups
            case .milliliters: return .milliliters
            case .pints: return .pints
            case .quarts: return .quarts
            case .tablespoons: return .tablespoons
            case .teaspoons: return .teaspoons
            }
        }
    }
    public final var defaultUnit: IntentParameter<Value>.Volume? { _isimOption("defaultUnit", "unit") }
    public final var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public final var unit: IntentParameter<Value>.Volume? { _isimOption("unit", "defaultUnit") }
    public final var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameter where Value.ValueType == String {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == String {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == String {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == String {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == String {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputOptions": inputOptions as Any, "inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public final var inputOptions: String.IntentInputOptions? { _isimOption("inputOptions") }
}
extension IntentParameter where Value.ValueType == StringSearchCriteria {
    public convenience init(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
}
extension IntentParameter where Value.ValueType == URL {
    public convenience init(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default) {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
    }
    public convenience init<OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == URL {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider) where OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == URL {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
    }
    public convenience init<Spec, OptionsProvider>(description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == URL {
        self.init(_isimTitle: nil, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec, OptionsProvider>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, optionsProvider: OptionsProvider, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification, OptionsProvider : DynamicOptionsProvider, OptionsProvider.DefaultValue.ValueType == URL {
        self.init(_isimTitle: title, description: description, default: nil, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        let provider = optionsProvider
        _optionsProvider = { await provider._isimOptions() }
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: nil, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
    public convenience init<Spec>(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default defaultValue: Value.UnwrappedType? = nil, requestValueDialog: IntentDialog? = nil, inputConnectionBehavior: InputConnectionBehavior = .default, @ResolverSpecificationBuilder<Value.UnwrappedType> resolvers: @escaping () -> Spec) where Spec : ResolverSpecification {
        self.init(_isimTitle: title, description: description, default: defaultValue, requestValueDialog: requestValueDialog, options: ["inputConnectionBehavior": inputConnectionBehavior as Any])
        _options["resolvers"] = resolvers()
    }
}
extension IntentParameterContext {
}
extension IntentParameterContext where Value.ValueType == Bool {
    public var displayName: Bool.IntentDisplayName? { _isimOption("displayName") }
}
extension IntentParameterContext where Value.ValueType == CLPlacemark {
    public var displayStyle: IntentParameter<Value>.PlacemarkDisplayStyle? { _isimOption("displayStyle") }
}
extension IntentParameterContext where Value.ValueType == Date {
    public var dateKind: IntentParameter<Value>.DateKind? { _isimOption("dateKind", "kind") }
}
extension IntentParameterContext where Value.ValueType == DateComponents {
    public var dateKind: IntentParameter<Value>.DateKind? { _isimOption("dateKind", "kind") }
}
extension IntentParameterContext where Value.ValueType == Double {
    public var controlStyle: IntentParameter<Value>.DoubleControlStyle? { _isimOption("controlStyle") }
    public var inclusiveRange: IntentParameter<Value>.InclusiveRange<Double>? { _isimOption("inclusiveRange") }
}
extension IntentParameterContext where Value.ValueType == Swift.Duration {
    public var defaultUnit: IntentParameter<Duration>.DurationUnit? { _isimOption("defaultUnit", "unit") }
    public var unit: IntentParameter<Duration>.DurationUnit? { _isimOption("unit", "defaultUnit") }
}
extension IntentParameterContext where Value.ValueType == Int {
    public var controlStyle: IntentParameter<Value>.IntControlStyle? { _isimOption("controlStyle") }
    public var inclusiveRange: IntentParameter<Value>.InclusiveRange<Int>? { _isimOption("inclusiveRange") }
}
extension IntentParameterContext where Value.ValueType == IntentCurrencyAmount {
    public var currencyCodes: [String]? { _isimOption("currencyCodes") }
    public var inclusiveRange: IntentParameter<Value>.InclusiveRange<Decimal>? { _isimOption("inclusiveRange") }
}
extension IntentParameterContext where Value.ValueType == IntentPerson {
    public var parameterMode: IntentPerson.ParameterMode? { _isimOption("parameterMode", "mode") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitAcceleration> {
    public var defaultUnit: IntentParameter<Measurement<UnitAcceleration>>.Acceleration? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitAcceleration>>.Acceleration? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitAngle> {
    public var defaultUnit: IntentParameter<Measurement<UnitAngle>>.Angle? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitAngle>>.Angle? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitArea> {
    public var defaultUnit: IntentParameter<Measurement<UnitArea>>.Area? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitArea>>.Area? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitConcentrationMass> {
    public var defaultUnit: IntentParameter<Measurement<UnitConcentrationMass>>.ConcentrationMass? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitConcentrationMass>>.ConcentrationMass? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitDispersion> {
    public var defaultUnit: IntentParameter<Measurement<UnitDispersion>>.Dispersion? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitDispersion>>.Dispersion? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitDuration> {
    public var defaultUnit: IntentParameter<Measurement<UnitDuration>>.Duration? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitDuration>>.Duration? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitElectricCharge> {
    public var defaultUnit: IntentParameter<Measurement<UnitElectricCharge>>.ElectricCharge? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitElectricCharge>>.ElectricCharge? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitElectricCurrent> {
    public var defaultUnit: IntentParameter<Measurement<UnitElectricCurrent>>.ElectricCurrent? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitElectricCurrent>>.ElectricCurrent? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitElectricPotentialDifference> {
    public var defaultUnit: IntentParameter<Measurement<UnitElectricPotentialDifference>>.ElectricPotentialDifference? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitElectricPotentialDifference>>.ElectricPotentialDifference? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitElectricResistance> {
    public var defaultUnit: IntentParameter<Measurement<UnitElectricResistance>>.ElectricResistance? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitElectricResistance>>.ElectricResistance? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitEnergy> {
    public var defaultUnit: IntentParameter<Measurement<UnitEnergy>>.Energy? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitEnergy>>.Energy? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitFrequency> {
    public var defaultUnit: IntentParameter<Measurement<UnitFrequency>>.Frequency? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitFrequency>>.Frequency? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitFuelEfficiency> {
    public var defaultUnit: IntentParameter<Measurement<UnitFuelEfficiency>>.FuelEfficiency? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitFuelEfficiency>>.FuelEfficiency? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitIlluminance> {
    public var defaultUnit: IntentParameter<Measurement<UnitIlluminance>>.Illuminance? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitIlluminance>>.Illuminance? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitInformationStorage> {
    public var defaultUnit: IntentParameter<Measurement<UnitInformationStorage>>.InformationStorage? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitInformationStorage>>.InformationStorage? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitLength> {
    public var defaultUnit: IntentParameter<Measurement<UnitLength>>.Length? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitLength>>.Length? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitMass> {
    public var defaultUnit: IntentParameter<Measurement<UnitMass>>.Mass? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitMass>>.Mass? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitPower> {
    public var defaultUnit: IntentParameter<Measurement<UnitPower>>.Power? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitPower>>.Power? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitPressure> {
    public var defaultUnit: IntentParameter<Measurement<UnitPressure>>.Pressure? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitPressure>>.Pressure? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitSpeed> {
    public var defaultUnit: IntentParameter<Measurement<UnitSpeed>>.Speed? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitSpeed>>.Speed? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitTemperature> {
    public var defaultUnit: IntentParameter<Measurement<UnitTemperature>>.Temperature? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitTemperature>>.Temperature? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
extension IntentParameterContext where Value.ValueType == Measurement<UnitVolume> {
    public var defaultUnit: IntentParameter<Measurement<UnitVolume>>.Volume? { _isimOption("defaultUnit", "unit") }
    public var supportsNegativeNumbers: Bool? { _isimOption("supportsNegativeNumbers") }
    public var unit: IntentParameter<Measurement<UnitVolume>>.Volume? { _isimOption("unit", "defaultUnit") }
    public var unitAdjustForLocale: Bool? { _isimOption("unitAdjustForLocale", "defaultUnitAdjustForLocale") }
}
