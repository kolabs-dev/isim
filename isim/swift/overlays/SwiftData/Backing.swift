// isim SwiftData: a model's backing data — its property values (typed once read or set, raw JSON as the store holds
// them until then), its relationships (models, or primary keys until read) with their inverses kept in step on both
// sides, and its state in its context (inserted, changed, deleted). One _ModelInfo per model type describes its
// properties from the schemaMetadata @Model generates.
import Foundation

/// The values of a model (Apple's protocol; isim's implementation is _DefaultBackingData).
public protocol BackingData<Model> {
    associatedtype Model: PersistentModel
    init(for modelType: Model.Type)
    var persistentModelID: PersistentIdentifier? { get }
    var metadata: Any { get }
    func getValue<Value: Decodable>(forKey key: KeyPath<Model, Value>) -> Value
    func getValue<Value: PersistentModel>(forKey key: KeyPath<Model, Value>) -> Value
    func getValue<Value: PersistentModel>(forKey key: KeyPath<Model, Value?>) -> Value?
    func getValue<Value, OtherModel>(forKey key: KeyPath<Model, Value>) -> Value where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func getValue<Value, OtherModel>(forKey key: KeyPath<Model, Value?>) -> Value? where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func getTransformableValue<Value>(forKey key: KeyPath<Model, Value>) -> Value
    func setValue<Value: Encodable>(forKey key: KeyPath<Model, Value>, to newValue: Value)
    func setValue<Value: PersistentModel>(forKey key: KeyPath<Model, Value>, to newValue: Value)
    func setValue<Value: PersistentModel>(forKey key: KeyPath<Model, Value?>, to newValue: Value?)
    func setValue<Value, OtherModel>(forKey key: KeyPath<Model, Value>, to newValue: Value) where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func setValue<Value, OtherModel>(forKey key: KeyPath<Model, Value?>, to newValue: Value?) where Value: RelationshipCollection, OtherModel == Value.PersistentElement
    func setTransformableValue<Value>(forKey key: KeyPath<Model, Value>, to newValue: Value)
}

// MARK: - Model types

protocol _ToOneTarget { static var _target: any PersistentModel.Type { get } }
extension Optional: _ToOneTarget where Wrapped: PersistentModel { static var _target: any PersistentModel.Type { Wrapped.self } }
protocol _ToManyMarker { static var _target: any PersistentModel.Type { get } }
extension Array: _ToManyMarker where Element: PersistentModel { static var _target: any PersistentModel.Type { Element.self } }
extension Optional: _ToManyMarker where Wrapped: _ToManyMarker { static var _target: any PersistentModel.Type { Wrapped._target } }

struct _PropInfo {
    let name: String
    let keyPath: AnyKeyPath
    let valueType: Any.Type
    let defaultValue: Any?
    let attribute: Schema.Attribute?
    let relationship: Schema.Relationship?
    /// the model type of a relationship (nil: an attribute)
    let target: (any PersistentModel.Type)?
    let toMany: Bool
    var schemaProperty: any SchemaProperty {
        if target != nil { return relationship! }
        return attribute!
    }
}

/// What isim knows about a model type: its entity name and properties.
final class _ModelInfo: @unchecked Sendable {
    let type: any PersistentModel.Type
    let entity: String
    let properties: [_PropInfo]
    let byKeyPath: [AnyKeyPath: Int]
    let byName: [String: Int]
    /// property indices that must be unique together (#Unique, @Attribute(.unique))
    let uniques: [[Int]]
    let indexes: [[Int]]
    private var inverses: [Int: (info: _ModelInfo, index: Int)?] = [:]
    private static let lock = NSRecursiveLock()
    nonisolated(unsafe) private static var cache: [ObjectIdentifier: _ModelInfo] = [:]

    static func of(_ t: any PersistentModel.Type) -> _ModelInfo {
        lock.lock(); defer { lock.unlock() }
        if let i = cache[ObjectIdentifier(t)] { return i }
        let i = _ModelInfo(t)
        cache[ObjectIdentifier(t)] = i
        return i
    }

    private init(_ t: any PersistentModel.Type) {
        type = t
        entity = String(describing: t)
        var props: [_PropInfo] = []
        for m in t.schemaMetadata {
            let vt = Swift.type(of: m.keypath).valueType
            let target: (any PersistentModel.Type)?, toMany: Bool
            if let many = vt as? _ToManyMarker.Type { target = many._target; toMany = true }
            else if let one = vt as? _ToOneTarget.Type { target = one._target; toMany = false }
            else if let model = vt as? any PersistentModel.Type { target = model; toMany = false }
            else { target = nil; toMany = false }
            var attribute: Schema.Attribute?, relationship: Schema.Relationship?
            if let target {
                let r = (m.metadata as? Schema.Relationship) ?? Schema.Relationship()
                r.name = m.name; r.keypath = m.keypath; r.valueType = vt; r.destination = String(describing: target)
                if r.originalName.isEmpty { r.originalName = m.name }
                relationship = r
            } else {
                let a = (m.metadata as? Schema.Attribute) ?? Schema.Attribute()
                a.name = m.name; a.valueType = vt; a.defaultValue = m.defaultValue
                if a.originalName.isEmpty { a.originalName = m.name }
                attribute = a
            }
            props.append(_PropInfo(name: m.name, keyPath: m.keypath, valueType: vt, defaultValue: m.defaultValue, attribute: attribute,
                                   relationship: relationship, target: target, toMany: toMany))
        }
        properties = props
        byKeyPath = Dictionary(props.enumerated().map { ($1.keyPath, $0) }, uniquingKeysWith: { a, _ in a })
        byName = Dictionary(props.enumerated().map { ($1.name, $0) }, uniquingKeysWith: { a, _ in a })
        let paths = { (lists: [[AnyKeyPath]]) in lists.compactMap { l -> [Int]? in
            let found = l.compactMap { kp in props.firstIndex { $0.keyPath == kp } }
            return found.count == l.count && !found.isEmpty ? found : nil
        } }
        uniques = props.indices.filter { props[$0].attribute?.isUnique == true }.map { [$0] } + paths(t._isimUniquenessConstraints)
        indexes = paths(t._isimIndexes)
    }

    /// the property on the other side of relationship i: the one named by `inverse:`, one naming i as its inverse,
    /// or the only relationship back to this type (as SwiftData infers it)
    func inverse(_ i: Int) -> (info: _ModelInfo, index: Int)? {
        _ModelInfo.lock.lock(); defer { _ModelInfo.lock.unlock() }
        if let cached = inverses[i] { return cached }
        var found: (info: _ModelInfo, index: Int)?
        if let target = properties[i].target {
            let other = _ModelInfo.of(target)
            if let kp = properties[i].relationship?.inverseKeyPath, let j = other.byKeyPath[kp] {
                found = (other, j)
            } else if let j = other.properties.firstIndex(where: { $0.relationship?.inverseKeyPath == properties[i].keyPath }) {
                found = (other, j)
            } else {
                let back = other.properties.indices.filter { j in
                    other.properties[j].target.map { ObjectIdentifier($0) } == ObjectIdentifier(type) && !(other === self && j == i)
                        && other.properties[j].relationship?.inverseKeyPath == nil
                }
                let mine = properties.indices.filter { properties[$0].target.map { ObjectIdentifier($0) } == ObjectIdentifier(target) && properties[$0].relationship?.inverseKeyPath == nil }
                if back.count == 1, mine.count == 1 || (other === self && mine.count == 2) { found = (other, back[0]) }
            }
        }
        inverses[i] = .some(found)
        if let f = found { f.info.inverses[f.index] = .some((self, i)) }
        return found
    }
}

// MARK: - Values

enum _Slot {
    /// an attribute's typed value, and how to encode it for the store
    case value(Any, encode: () throws -> Any)
    /// an attribute as the store holds it (a JSON fragment), decoded when read
    case raw(Any)
    case one(AnyObject?)
    case many([AnyObject])
    /// relationships as primary keys, resolved when read
    case rawOne(Int64?)
    case rawMany([Int64])
}

func _encodeJSON<V: Encodable>(_ v: V) throws -> Any {
    let d = try JSONEncoder().encode([v])
    return (try JSONSerialization.jsonObject(with: d, options: [.fragmentsAllowed]) as? [Any])?.first ?? NSNull()
}
func _decodeJSON<V: Decodable>(_ type: V.Type, _ j: Any) throws -> V {
    let d = try JSONSerialization.data(withJSONObject: [j], options: [.fragmentsAllowed])
    return try JSONDecoder().decode([V].self, from: d)[0]
}
/// a JSON fragment's text, to compare values
func _jsonText(_ j: Any) -> String {
    (try? JSONSerialization.data(withJSONObject: [j], options: [.fragmentsAllowed, .sortedKeys])).flatMap { String(data: $0, encoding: .utf8) } ?? ""
}

/// a model's backing data, untyped: what the context and the inverse bookkeeping work with
func _store(_ model: AnyObject) -> _BackingStore { (model as! any PersistentModel)._store }

class _BackingStore: @unchecked Sendable {
    let info: _ModelInfo
    var slots: [_Slot?]
    /// the values last read from or written to the store (rollback restores them)
    var saved: [_Slot?]?
    var pk: Int64?
    let temporaryKey: Int64
    weak var context: ModelContext?
    /// the model these values belong to, once known (insert, fetch, or a call through the model)
    weak var model: AnyObject?
    var isInserted = false, isDirty = false, isDeleted = false
    /// relationships set before the model was known, whose inverses are not set yet
    var pendingInverses: Set<Int> = []
    nonisolated(unsafe) private static var nextTemporary: Int64 = 0
    private static let lock = NSLock()

    init(_ info: _ModelInfo) {
        self.info = info
        slots = Array(repeating: nil, count: info.properties.count)
        _BackingStore.lock.lock(); _BackingStore.nextTemporary -= 1; temporaryKey = _BackingStore.nextTemporary; _BackingStore.lock.unlock()
    }

    var identifier: PersistentIdentifier {
        guard let pk else { return PersistentIdentifier(entityName: info.entity, storeIdentifier: nil, primaryKey: temporaryKey) }
        return context?.store.publicIdentifier(info.entity, pk) ?? PersistentIdentifier(entityName: info.entity, storeIdentifier: nil, primaryKey: pk)
    }

    func index(_ key: AnyKeyPath) -> Int {
        guard let i = info.byKeyPath[key] else { fatalError("SwiftData: \(key) is not a persisted property of \(info.entity)") }
        return i
    }

    /// the store's row: attributes as JSON fragments, relationships as primary keys
    func load(_ row: [String: Any]) {
        for (i, p) in info.properties.enumerated() {
            // a renamed property (`originalName`) is read from its old name until the model is saved again
            let old = p.attribute?.originalName ?? p.relationship?.originalName
            guard let v = row[p.name] ?? old.flatMap({ row[$0] }) else { slots[i] = nil; continue }
            if p.target == nil { slots[i] = .raw(v) }
            else if p.toMany { slots[i] = .rawMany(((v as? [Any]) ?? []).compactMap { ($0 as? NSNumber)?.int64Value }) }
            else { slots[i] = .rawOne((v as? NSNumber)?.int64Value) }
        }
        saved = slots
    }
    func row() throws -> [String: Any] {
        var out: [String: Any] = [:]
        for (i, p) in info.properties.enumerated() {
            guard let s = slots[i] else { continue }
            switch s {
            case .value(_, let encode): out[p.name] = try encode()
            case .raw(let j): out[p.name] = j
            case .one(let o): out[p.name] = o.flatMap { _store($0).pk }.map { NSNumber(value: $0) } ?? NSNull()
            case .many(let list): out[p.name] = list.compactMap { _store($0).pk }.map { NSNumber(value: $0) }
            case .rawOne(let k): out[p.name] = k.map { NSNumber(value: $0) } ?? NSNull()
            case .rawMany(let ks): out[p.name] = ks.map { NSNumber(value: $0) }
            }
        }
        return out
    }
    /// an attribute's JSON fragment (for uniqueness), nil when it has no value
    func json(_ i: Int) -> Any? {
        switch slots[i] {
        case .value(_, let encode)?: return try? encode()
        case .raw(let j)?: return j
        default: return nil
        }
    }

    // MARK: relationships

    func objects(_ i: Int) -> [AnyObject] {
        switch slots[i] {
        case .one(let o)?: return o.map { [$0] } ?? []
        case .many(let l)?: return l
        case .rawOne(let k)?:
            let o = k.flatMap { resolve(i, $0) }
            slots[i] = .one(o)
            return o.map { [$0] } ?? []
        case .rawMany(let ks)?:
            let l = ks.compactMap { resolve(i, $0) }
            slots[i] = .many(l)
            return l
        default: return []
        }
    }
    func resolve(_ i: Int, _ key: Int64) -> AnyObject? {
        guard let c = context, let t = info.properties[i].target else { return nil }
        return c._model(t, key)
    }

    /// sets relationship i, keeping the inverse in step (or later, once the owner is known)
    func setRelationship(_ i: Int, _ new: [AnyObject], owner: AnyObject?) {
        let old = objects(i)
        slots[i] = info.properties[i].toMany ? .many(new) : .one(new.first)
        changed()
        if let owner { relate(i, old: old, new: new, owner: owner) } else { pendingInverses.insert(i) }
        if let c = context { for n in new { c._insertObject(n) } }
    }
    func relate(_ i: Int, old: [AnyObject], new: [AnyObject], owner: AnyObject) {
        guard let inv = info.inverse(i) else { return }
        for o in old where !new.contains(where: { $0 === o }) { _store(o).unlink(inv.index, owner) }
        for n in new where !old.contains(where: { $0 === n }) { _store(n).link(inv.index, owner, me: n) }
    }
    /// this model (`me`) now points back at owner through relationship j
    func link(_ j: Int, _ owner: AnyObject, me: AnyObject) {
        if info.properties[j].toMany {
            var list = objects(j)
            guard !list.contains(where: { $0 === owner }) else { return }
            list.append(owner); slots[j] = .many(list)
        } else {
            let prev = objects(j).first
            guard prev !== owner else { return }
            if let p = prev, let back = info.inverse(j) { _store(p).unlink(back.index, me) }
            slots[j] = .one(owner)
        }
        changed()
        // a model related to one in a context joins that context
        if let c = context, _store(owner).context == nil { c._insertObject(owner) }
    }
    func unlink(_ j: Int, _ owner: AnyObject) {
        if info.properties[j].toMany {
            let list = objects(j)
            guard list.contains(where: { $0 === owner }) else { return }
            slots[j] = .many(list.filter { $0 !== owner })
        } else {
            guard objects(j).first === owner else { return }
            slots[j] = .one(nil)
        }
        changed()
    }
    /// the model is known: inverses of relationships set before
    func adopt(_ owner: AnyObject) {
        if model == nil { model = owner }
        guard !pendingInverses.isEmpty else { return }
        let pending = pendingInverses
        pendingInverses = []
        for i in pending.sorted() { relate(i, old: [], new: objects(i), owner: owner) }
    }

    func changed() {
        guard let c = context, let m = model else { return }
        c._changed(m)
    }
}

/// isim's backing data for a model type.
final class _DefaultBackingData<M: PersistentModel>: _BackingStore, BackingData, @unchecked Sendable {
    typealias Model = M
    init(for modelType: M.Type) { super.init(_ModelInfo.of(modelType)) }
    var persistentModelID: PersistentIdentifier? { identifier }
    var metadata: Any { info }

    func missing<Value>(_ i: Int, _ type: Value.Type) -> Value {
        if let d = info.properties[i].defaultValue as? Value { return d }
        if let none = (Optional<Any>.none as Any) as? Value { return none }
        fatalError("SwiftData: \(info.entity).\(info.properties[i].name) has no value")
    }

    func getValue<Value: Decodable>(forKey key: KeyPath<M, Value>) -> Value {
        let i = index(key)
        switch slots[i] {
        case .value(let v, _)?: return v as! Value
        case .raw(let j)?:
            if j is NSNull, let none = (Optional<Any>.none as Any) as? Value { return none }
            guard let v = try? _decodeJSON(Value.self, j) else {
                NSLog("SwiftData: could not decode %@.%@ as %@", info.entity, info.properties[i].name, String(describing: Value.self))
                return missing(i, Value.self)
            }
            slots[i] = .value(v, encode: { j })
            return v
        default: return missing(i, Value.self)
        }
    }
    func getValue<Value: PersistentModel>(forKey key: KeyPath<M, Value>) -> Value {
        let i = index(key)
        guard let o = objects(i).first as? Value else { fatalError("SwiftData: \(info.entity).\(info.properties[i].name) has no model") }
        return o
    }
    func getValue<Value: PersistentModel>(forKey key: KeyPath<M, Value?>) -> Value? { objects(index(key)).first as? Value }
    func getValue<Value, OtherModel>(forKey key: KeyPath<M, Value>) -> Value where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        Value(objects(index(key)).compactMap { $0 as? OtherModel })
    }
    func getValue<Value, OtherModel>(forKey key: KeyPath<M, Value?>) -> Value? where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        let i = index(key)
        if case .one(nil)? = slots[i] { return nil }
        if case .rawOne(nil)? = slots[i] { return nil }
        if slots[i] == nil { return nil }
        return Value(objects(i).compactMap { $0 as? OtherModel })
    }
    func getTransformableValue<Value>(forKey key: KeyPath<M, Value>) -> Value {
        let i = index(key)
        if case .value(let v, _)? = slots[i] { return v as! Value }
        return missing(i, Value.self)
    }

    func setValue<Value: Encodable>(forKey key: KeyPath<M, Value>, to newValue: Value) {
        let i = index(key)
        slots[i] = .value(newValue, encode: { try _encodeJSON(newValue) })
        changed()
    }
    func setValue<Value: PersistentModel>(forKey key: KeyPath<M, Value>, to newValue: Value) { setRelationship(index(key), [newValue], owner: model) }
    func setValue<Value: PersistentModel>(forKey key: KeyPath<M, Value?>, to newValue: Value?) { setRelationship(index(key), newValue.map { [$0] } ?? [], owner: model) }
    func setValue<Value, OtherModel>(forKey key: KeyPath<M, Value>, to newValue: Value) where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        setRelationship(index(key), newValue._models, owner: model)
    }
    func setValue<Value, OtherModel>(forKey key: KeyPath<M, Value?>, to newValue: Value?) where Value: RelationshipCollection, OtherModel == Value.PersistentElement {
        setRelationship(index(key), newValue?._models ?? [], owner: model)
    }
    /// a value that is not Codable (a transformable attribute): kept in memory only
    func setTransformableValue<Value>(forKey key: KeyPath<M, Value>, to newValue: Value) {
        slots[index(key)] = .value(newValue, encode: { NSNull() })
        changed()
    }
}
