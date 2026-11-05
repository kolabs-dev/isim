// isim Foundation: the rest of AttributedString (issue #864, part 2): the shared protocol API (index navigation, UTF-8
// and UTF-16 views, scoped containers), more attributes slices, attribute transformers, discontiguous substrings,
// index validity, Markdown files, localized initializers with options, and the newer Foundation attributes
// (grammar agreement, localized arguments, writing direction, text alignment and line height, accessibility speech).

// MARK: - scoped containers

/// The attributes of one scope (`string.uiKit.font`).
@dynamicMemberLookup
public struct ScopedAttributeContainer<S: AttributeScope>: @unchecked Sendable {
  var _storage: AttributeContainer
  init(_ storage: AttributeContainer = AttributeContainer()) { _storage = storage }
  public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<S, T>) -> T.Value? {
    get { _storage[T.self] }
    set { _storage[T.self] = newValue }
  }
}
extension AttributeContainer {
  public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
    get { ScopedAttributeContainer(self) }
    set { _storage = newValue._storage._storage }
  }
  /// the attributes whose keys are (or are not) inherited by text added next to them
  public func filter(inheritedByAddedText: Bool) -> AttributeContainer {
    AttributeContainer(_storage: _storage.filter { (_attrKeys.type(named: $0.key)?.inheritedByAddedText ?? true) == inheritedByAddedText })
  }
  /// the attributes whose keys have these run boundaries (nil: none)
  public func filter(runBoundaries: AttributedString.AttributeRunBoundaries?) -> AttributeContainer {
    AttributeContainer(_storage: _storage.filter { _attrKeys.type(named: $0.key)?.runBoundaries == runBoundaries })
  }
  public init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key: Any], including scope: KeyPath<AttributeScopes, S.Type>) throws { self.init(dictionary) }
  public init<S: AttributeScope>(_ dictionary: [NSAttributedString.Key: Any], including scope: S.Type) throws { self.init(dictionary) }
}
extension _AttrKeyRegistry {
  func type(named name: String) -> (any AttributedStringKey.Type)? { lock.lock(); defer { lock.unlock() }; return types[name] }
}
extension AttributedString {
  /// the attributes every run in UTF-8 range `r` has, with the same value
  func _commonAttributes(_ r: Range<Int>) -> AttributeContainer {
    let ps = _pieces(r)
    guard var common = ps.first?.1._storage else { return AttributeContainer() }
    for p in ps.dropFirst() { common = common.filter { p.1._storage[$0.key] == $0.value } }
    return AttributeContainer(_storage: common)
  }
  /// sets the scoped attributes that differ from `old` over UTF-8 range `r`
  mutating func _applyScoped(_ new: AttributeContainer, old: AttributeContainer, _ r: Range<Int>) {
    for k in Set(new._storage.keys).union(old._storage.keys) where new._storage[k] != old._storage[k] {
      let v = new._storage[k]
      _editAttributes(_expandedForBoundaries(r, names: [k])) { $0._storage[k] = v }
    }
  }
  public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
    get { ScopedAttributeContainer(_commonAttributes(0..<_string.utf8.count)) }
    set { let r = 0..<_string.utf8.count; _applyScoped(newValue._storage, old: _commonAttributes(r), r) }
  }
}
extension AttributedSubstring {
  public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
    get { ScopedAttributeContainer(_base._commonAttributes(_offs)) }
    set { let r = _offs; _base._applyScoped(newValue._storage, old: _base._commonAttributes(r), r) }
  }
  public var utf8: AttributedString.UTF8View { AttributedString.UTF8View(self) }
  public var utf16: AttributedString.UTF16View { AttributedString.UTF16View(self) }
}

extension AttributeScope {
  /// the attribute keys of the scope and of the scopes it nests
  public static var attributeKeys: some Sequence<any AttributedStringKey.Type> {
    AttributeScopeCodableConfiguration(Self.self)._keys.values.map(\.type)
  }
}

// MARK: - the shared protocol API

extension AttributedStringProtocol {
  public var description: String { _whole.description }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? { _whole[K.self] }
  public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
    let w = _whole
    return ScopedAttributeContainer(w._base._commonAttributes(w._offs))
  }
  public var utf8: AttributedString.UTF8View { AttributedString.UTF8View(_whole) }
  public var utf16: AttributedString.UTF16View { AttributedString.UTF16View(_whole) }
  public func replacingAttributes(_ attributes: AttributeContainer, with others: AttributeContainer) -> AttributedString {
    var s = AttributedString(self); s.replaceAttributes(attributes, with: others); return s
  }

  // index navigation
  public func index(_ i: AttributedString.Index, offsetByCharacters distance: Int) -> AttributedString.Index {
    AttributedString.Index(_whole._base._string.index(i._i, offsetBy: distance))
  }
  public func index(_ i: AttributedString.Index, offsetByUnicodeScalars distance: Int) -> AttributedString.Index {
    AttributedString.Index(_whole._base._string.unicodeScalars.index(i._i, offsetBy: distance))
  }
  public func index(afterCharacter i: AttributedString.Index) -> AttributedString.Index { index(i, offsetByCharacters: 1) }
  public func index(beforeCharacter i: AttributedString.Index) -> AttributedString.Index { index(i, offsetByCharacters: -1) }
  public func index(afterUnicodeScalar i: AttributedString.Index) -> AttributedString.Index { index(i, offsetByUnicodeScalars: 1) }
  public func index(beforeUnicodeScalar i: AttributedString.Index) -> AttributedString.Index { index(i, offsetByUnicodeScalars: -1) }
  /// the start of the run `distance` runs from the one holding `i` (the end index past the last run)
  public func index(_ i: AttributedString.Index, offsetByRuns distance: Int) -> AttributedString.Index {
    let starts = runs.map(\.range.lowerBound)
    let here = starts.lastIndex { $0 <= i } ?? 0
    let n = here + distance
    precondition(n >= 0 && n <= starts.count, "run offset out of bounds")
    return n == starts.count ? endIndex : starts[n]
  }
  public func index(afterRun i: AttributedString.Index) -> AttributedString.Index { index(i, offsetByRuns: 1) }
  public func index(beforeRun i: AttributedString.Index) -> AttributedString.Index {
    let starts = runs.map(\.range.lowerBound)
    guard let n = starts.lastIndex(where: { $0 < i }) else { preconditionFailure("no run before the start") }
    return starts[n]
  }

  // transforming attributes
  public func transformingAttributes<K: AttributedStringKey>(_ k: K.Type, _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void) -> AttributedString {
    var out = AttributedString(self)
    for (v, r) in out.runs[K.self] {
      var t = AttributedString.SingleAttributeTransformer<K>(range: r, value: v); c(&t); t._apply(to: &out)
    }
    return out
  }
  public func transformingAttributes<K: AttributedStringKey>(_ k: KeyPath<AttributeDynamicLookup, K>, _ c: (inout AttributedString.SingleAttributeTransformer<K>) -> Void) -> AttributedString {
    transformingAttributes(K.self, c)
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey>(_ k: K1.Type, _ k2: K2.Type,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>) -> Void) -> AttributedString {
    var out = AttributedString(self)
    for r in out._segments(by: [K1.name, K2.name]) {
      var t1 = out._transformer(K1.self, r), t2 = out._transformer(K2.self, r)
      c(&t1, &t2); t1._apply(to: &out); t2._apply(to: &out)
    }
    return out
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey>(_ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>) -> Void) -> AttributedString {
    transformingAttributes(K1.self, K2.self, c)
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey>(_ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>) -> Void) -> AttributedString {
    var out = AttributedString(self)
    for r in out._segments(by: [K1.name, K2.name, K3.name]) {
      var t1 = out._transformer(K1.self, r), t2 = out._transformer(K2.self, r), t3 = out._transformer(K3.self, r)
      c(&t1, &t2, &t3); t1._apply(to: &out); t2._apply(to: &out); t3._apply(to: &out)
    }
    return out
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey>(
      _ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>) -> Void) -> AttributedString {
    transformingAttributes(K1.self, K2.self, K3.self, c)
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey, K4: AttributedStringKey>(
      _ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type, _ k4: K4.Type,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>) -> Void) -> AttributedString {
    var out = AttributedString(self)
    for r in out._segments(by: [K1.name, K2.name, K3.name, K4.name]) {
      var t1 = out._transformer(K1.self, r), t2 = out._transformer(K2.self, r), t3 = out._transformer(K3.self, r), t4 = out._transformer(K4.self, r)
      c(&t1, &t2, &t3, &t4); t1._apply(to: &out); t2._apply(to: &out); t3._apply(to: &out); t4._apply(to: &out)
    }
    return out
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey, K4: AttributedStringKey>(
      _ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>,
      _ k4: KeyPath<AttributeDynamicLookup, K4>,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>) -> Void) -> AttributedString {
    transformingAttributes(K1.self, K2.self, K3.self, K4.self, c)
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey, K4: AttributedStringKey, K5: AttributedStringKey>(
      _ k: K1.Type, _ k2: K2.Type, _ k3: K3.Type, _ k4: K4.Type, _ k5: K5.Type,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>,
            inout AttributedString.SingleAttributeTransformer<K5>) -> Void) -> AttributedString {
    var out = AttributedString(self)
    for r in out._segments(by: [K1.name, K2.name, K3.name, K4.name, K5.name]) {
      var t1 = out._transformer(K1.self, r), t2 = out._transformer(K2.self, r), t3 = out._transformer(K3.self, r)
      var t4 = out._transformer(K4.self, r), t5 = out._transformer(K5.self, r)
      c(&t1, &t2, &t3, &t4, &t5)
      t1._apply(to: &out); t2._apply(to: &out); t3._apply(to: &out); t4._apply(to: &out); t5._apply(to: &out)
    }
    return out
  }
  public func transformingAttributes<K1: AttributedStringKey, K2: AttributedStringKey, K3: AttributedStringKey, K4: AttributedStringKey, K5: AttributedStringKey>(
      _ k: KeyPath<AttributeDynamicLookup, K1>, _ k2: KeyPath<AttributeDynamicLookup, K2>, _ k3: KeyPath<AttributeDynamicLookup, K3>,
      _ k4: KeyPath<AttributeDynamicLookup, K4>, _ k5: KeyPath<AttributeDynamicLookup, K5>,
      _ c: (inout AttributedString.SingleAttributeTransformer<K1>, inout AttributedString.SingleAttributeTransformer<K2>,
            inout AttributedString.SingleAttributeTransformer<K3>, inout AttributedString.SingleAttributeTransformer<K4>,
            inout AttributedString.SingleAttributeTransformer<K5>) -> Void) -> AttributedString {
    transformingAttributes(K1.self, K2.self, K3.self, K4.self, K5.self, c)
  }
}

extension AttributedString {
  /// One run of an attribute's value in transformingAttributes: change `value`, or replace the attribute with another.
  public struct SingleAttributeTransformer<T: AttributedStringKey>: @unchecked Sendable {
    public var range: Range<AttributedString.Index>
    public var value: T.Value?
    var _replacement: (name: String, value: AnyHashable)?
    init(range: Range<AttributedString.Index>, value: T.Value?) { self.range = range; self.value = value }
    public mutating func replace<U: AttributedStringKey>(with key: U.Type, value: U.Value) {
      _registerAttributeKey(U.self)
      _replacement = (U.name, AnyHashable(value))
    }
    public mutating func replace<U: AttributedStringKey>(with keyPath: KeyPath<AttributeDynamicLookup, U>, value: U.Value) { replace(with: U.self, value: value) }
    func _apply(to s: inout AttributedString) {
      let r = s._off(range.lowerBound)..<s._off(range.upperBound)
      let v = value.map { AnyHashable($0) }, rep = _replacement
      s._editAttributes(r) { a in
        if let rep { a._storage[T.name] = nil; a._storage[rep.name] = rep.value } else { a._storage[T.name] = v }
      }
    }
  }
  func _transformer<K: AttributedStringKey>(_ k: K.Type, _ r: Range<AttributedString.Index>) -> SingleAttributeTransformer<K> {
    SingleAttributeTransformer(range: r, value: self[r][K.self])
  }
  /// the ranges over which the attributes named all keep one value
  func _segments(by names: [String]) -> [Range<AttributedString.Index>] {
    var out: [(Range<Int>, [AnyHashable?])] = []
    for (r, a) in _pieces(0..<_string.utf8.count) {
      let vals = names.map { a._storage[$0] }
      if let last = out.last, last.1 == vals, last.0.upperBound == r.lowerBound { out[out.count - 1].0 = last.0.lowerBound..<r.upperBound }
      else { out.append((r, vals)) }
    }
    return out.map { _idx($0.0.lowerBound)..<_idx($0.0.upperBound) }
  }
}

// MARK: - attribute mutation

/// The attribute-changing methods AttributedString and AttributedSubstring share.
public protocol AttributedStringAttributeMutation {
  mutating func setAttributes(_ attributes: AttributeContainer)
  mutating func mergeAttributes(_ attributes: AttributeContainer, mergePolicy: AttributedString.AttributeMergePolicy)
  mutating func replaceAttributes(_ attributes: AttributeContainer, with others: AttributeContainer)
}
extension AttributedString: AttributedStringAttributeMutation {}
extension AttributedSubstring: AttributedStringAttributeMutation {}

// MARK: - UTF-8 and UTF-16 views

extension AttributedString {
  public struct UTF8View: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = UInt8
    public typealias Index = AttributedString.Index
    public typealias SubSequence = AttributedString.UTF8View
    var _sub: AttributedSubstring
    init(_ s: AttributedSubstring) { _sub = s }
    var _u: String.UTF8View { _sub._base._string.utf8 }
    public var startIndex: Index { _sub._range.lowerBound }
    public var endIndex: Index { _sub._range.upperBound }
    public func index(after i: Index) -> Index { Index(_u.index(after: i._i)) }
    public func index(before i: Index) -> Index { Index(_u.index(before: i._i)) }
    public func index(_ i: Index, offsetBy n: Int) -> Index { Index(_u.index(i._i, offsetBy: n)) }
    public func distance(from a: Index, to b: Index) -> Int { _u.distance(from: a._i, to: b._i) }
    public subscript(i: Index) -> UInt8 { _u[i._i] }
    public subscript(bounds: Range<Index>) -> UTF8View { UTF8View(AttributedSubstring(_base: _sub._base, _range: bounds)) }
  }
  public struct UTF16View: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = UInt16
    public typealias Index = AttributedString.Index
    public typealias SubSequence = AttributedString.UTF16View
    var _sub: AttributedSubstring
    init(_ s: AttributedSubstring) { _sub = s }
    var _u: String.UTF16View { _sub._base._string.utf16 }
    public var startIndex: Index { _sub._range.lowerBound }
    public var endIndex: Index { _sub._range.upperBound }
    public func index(after i: Index) -> Index { Index(_u.index(after: i._i)) }
    public func index(before i: Index) -> Index { Index(_u.index(before: i._i)) }
    public func index(_ i: Index, offsetBy n: Int) -> Index { Index(_u.index(i._i, offsetBy: n)) }
    public func distance(from a: Index, to b: Index) -> Int { _u.distance(from: a._i, to: b._i) }
    public subscript(i: Index) -> UInt16 { _u[i._i] }
    public subscript(bounds: Range<Index>) -> UTF16View { UTF16View(AttributedSubstring(_base: _sub._base, _range: bounds)) }
  }
  public var utf8: UTF8View { UTF8View(AttributedSubstring(_base: self, _range: startIndex..<endIndex)) }
  public var utf16: UTF16View { UTF16View(AttributedSubstring(_base: self, _range: startIndex..<endIndex)) }
}

// MARK: - more attributes slices

extension AttributedString.Runs {
  /// the runs over which every attribute named keeps one value: (values, range)
  func _slices(_ names: [String]) -> [([AnyHashable?], Range<AttributedString.Index>)] {
    var out: [([AnyHashable?], Range<AttributedString.Index>)] = []
    for r in _list {
      let vals = names.map { r.attributes._storage[$0] }
      if let last = out.last, last.0 == vals, last.1.upperBound == r.range.lowerBound { out[out.count - 1].1 = last.1.lowerBound..<r.range.upperBound }
      else { out.append((vals, r.range)) }
    }
    return out
  }
  public struct AttributesSlice3<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey>: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = (T.Value?, U.Value?, V.Value?, Range<AttributedString.Index>)
    let _items: [Element]
    init(_ runs: AttributedString.Runs) {
      _items = runs._slices([T.name, U.name, V.name]).map { ($0.0[0]?.base as? T.Value, $0.0[1]?.base as? U.Value, $0.0[2]?.base as? V.Value, $0.1) }
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { _items.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public subscript(i: Int) -> Element { _items[i] }
  }
  public struct AttributesSlice4<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey>: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = (T.Value?, U.Value?, V.Value?, W.Value?, Range<AttributedString.Index>)
    let _items: [Element]
    init(_ runs: AttributedString.Runs) {
      _items = runs._slices([T.name, U.name, V.name, W.name]).map {
        ($0.0[0]?.base as? T.Value, $0.0[1]?.base as? U.Value, $0.0[2]?.base as? V.Value, $0.0[3]?.base as? W.Value, $0.1)
      }
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { _items.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public subscript(i: Int) -> Element { _items[i] }
  }
  public struct AttributesSlice5<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey, X: AttributedStringKey>: BidirectionalCollection, @unchecked Sendable {
    public typealias Element = (T.Value?, U.Value?, V.Value?, W.Value?, X.Value?, Range<AttributedString.Index>)
    let _items: [Element]
    init(_ runs: AttributedString.Runs) {
      _items = runs._slices([T.name, U.name, V.name, W.name, X.name]).map {
        ($0.0[0]?.base as? T.Value, $0.0[1]?.base as? U.Value, $0.0[2]?.base as? V.Value, $0.0[3]?.base as? W.Value, $0.0[4]?.base as? X.Value, $0.1)
      }
    }
    public var startIndex: Int { 0 }
    public var endIndex: Int { _items.count }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public subscript(i: Int) -> Element { _items[i] }
  }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey>(_ t: T.Type, _ u: U.Type, _ v: V.Type) -> AttributesSlice3<T, U, V> {
    AttributesSlice3(self)
  }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey>(
      _ t: KeyPath<AttributeDynamicLookup, T>, _ u: KeyPath<AttributeDynamicLookup, U>, _ v: KeyPath<AttributeDynamicLookup, V>) -> AttributesSlice3<T, U, V> {
    AttributesSlice3(self)
  }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey>(
      _ t: T.Type, _ u: U.Type, _ v: V.Type, _ w: W.Type) -> AttributesSlice4<T, U, V, W> { AttributesSlice4(self) }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey>(
      _ t: KeyPath<AttributeDynamicLookup, T>, _ u: KeyPath<AttributeDynamicLookup, U>, _ v: KeyPath<AttributeDynamicLookup, V>,
      _ w: KeyPath<AttributeDynamicLookup, W>) -> AttributesSlice4<T, U, V, W> { AttributesSlice4(self) }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey, X: AttributedStringKey>(
      _ t: T.Type, _ u: U.Type, _ v: V.Type, _ w: W.Type, _ x: X.Type) -> AttributesSlice5<T, U, V, W, X> { AttributesSlice5(self) }
  public subscript<T: AttributedStringKey, U: AttributedStringKey, V: AttributedStringKey, W: AttributedStringKey, X: AttributedStringKey>(
      _ t: KeyPath<AttributeDynamicLookup, T>, _ u: KeyPath<AttributeDynamicLookup, U>, _ v: KeyPath<AttributeDynamicLookup, V>,
      _ w: KeyPath<AttributeDynamicLookup, W>, _ x: KeyPath<AttributeDynamicLookup, X>) -> AttributesSlice5<T, U, V, W, X> { AttributesSlice5(self) }
}

// MARK: - index validity

extension AttributedString.Index {
  /// the attributed-string index for a position of `target`'s text (nil: not one of its scalar boundaries)
  public init?<S: AttributedStringProtocol>(_ sourcePosition: String.Index, within target: S) {
    let w = target._whole
    let i = AttributedString.Index(sourcePosition)
    guard i.isValid(within: w) else { return nil }
    self = i
  }
  /// whether this index is a Unicode scalar boundary within `text`'s bounds
  public func isValid(within text: some AttributedStringProtocol) -> Bool {
    let w = text._whole
    guard w._range.lowerBound <= self && self <= w._range.upperBound else { return false }
    return _i.samePosition(in: w._base._string.unicodeScalars) != nil
  }
  @available(iOS 18.0, *)
  public func isValid(within text: DiscontiguousAttributedSubstring) -> Bool {
    guard text.base.startIndex <= self && self <= text.base.endIndex, _i.samePosition(in: text.base._string.unicodeScalars) != nil else { return false }
    return text._ranges.ranges.contains { $0.contains(self) || $0.upperBound == self }
  }
}

// MARK: - discontiguous substrings

/// The parts of an attributed string a RangeSet selects.
@available(iOS 18.0, *)
@dynamicMemberLookup
public struct DiscontiguousAttributedSubstring: CustomStringConvertible, Hashable, @unchecked Sendable {
  public var base: AttributedString
  var _ranges: RangeSet<AttributedString.Index>
  init(base: AttributedString, ranges: RangeSet<AttributedString.Index>) { self.base = base; _ranges = ranges }
  var _offsets: [Range<Int>] { _ranges.ranges.map { base._off($0.lowerBound)..<base._off($0.upperBound) } }
  public var characters: DiscontiguousSlice<AttributedString.CharacterView> { base.characters[_ranges] }
  public var unicodeScalars: DiscontiguousSlice<AttributedString.UnicodeScalarView> { base.unicodeScalars[_ranges] }
  public var runs: AttributedString.Runs {
    let list = _offsets.flatMap { r in
      base._pieces(r).map { AttributedString.Runs.Run(range: base._idx($0.0.lowerBound)..<base._idx($0.0.upperBound), attributes: $0.1) }
    }
    return AttributedString.Runs(_sub: AttributedSubstring(_base: base, _range: base.startIndex..<base.endIndex), _list: list)
  }
  public subscript<K: AttributedStringKey>(_: K.Type) -> K.Value? {
    get {
      let vals = _offsets.flatMap { base._pieces($0) }.map { $0.1[K.self] }
      guard let first = vals.first, vals.allSatisfy({ $0 == first }) else { return nil }
      return first
    }
    set {
      _registerAttributeKey(K.self)
      let v = newValue.map { AnyHashable($0) }
      for r in _offsets { base._editAttributes(base._expandedForBoundaries(r, names: [K.name])) { $0._storage[K.name] = v } }
    }
  }
  public subscript<K: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeDynamicLookup, K>) -> K.Value? {
    get { self[K.self] }
    set { self[K.self] = newValue }
  }
  public subscript<S: AttributeScope>(dynamicMember keyPath: KeyPath<AttributeScopes, S.Type>) -> ScopedAttributeContainer<S> {
    get {
      let all = _offsets.map { base._commonAttributes($0)._storage }
      guard var common = all.first else { return ScopedAttributeContainer() }
      for s in all.dropFirst() { common = common.filter { s[$0.key] == $0.value } }
      return ScopedAttributeContainer(AttributeContainer(_storage: common))
    }
    set {
      let old = self[dynamicMember: keyPath]._storage
      for r in _offsets { base._applyScoped(newValue._storage, old: old, r) }
    }
  }
  public subscript(bounds: some RangeExpression<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
    let r = bounds.relative(to: base.characters)
    return DiscontiguousAttributedSubstring(base: base, ranges: _ranges.intersection(RangeSet(r)))
  }
  public subscript(bounds: RangeSet<AttributedString.Index>) -> DiscontiguousAttributedSubstring {
    DiscontiguousAttributedSubstring(base: base, ranges: _ranges.intersection(bounds))
  }
  public var description: String { _offsets.map { base._describe($0) }.joined(separator: "\n") }
  public static func == (a: Self, b: Self) -> Bool {
    a._offsets.count == b._offsets.count && zip(a._offsets, b._offsets).allSatisfy { a.base._pieces($0.0).map(\.1) == b.base._pieces($0.1).map(\.1) }
      && a.characters.elementsEqual(b.characters)
  }
  public func hash(into h: inout Hasher) { for c in characters { h.combine(c) } }
}
extension AttributedString.Runs {
  init(_sub: AttributedSubstring, _list: [Run]) { self._sub = _sub; self._list = _list }
}
@available(iOS 18.0, *)
extension AttributedString {
  public subscript(bounds: RangeSet<Index>) -> DiscontiguousAttributedSubstring {
    get { DiscontiguousAttributedSubstring(base: self, ranges: bounds) }
    set { self = newValue.base }
  }
  public mutating func removeSubranges(_ subranges: RangeSet<Index>) {
    for r in subranges.ranges.reversed() { removeSubrange(r) }
  }
}

// MARK: - tracking ranges through a change

extension AttributedString {
  /// UTF-8 offsets in the text before a change, mapped to the text after it (the change is the span between the
  /// common prefix and the common suffix; offsets inside it go to its edges)
  static func _track(_ before: String, _ after: String) -> (Int) -> Int {
    let a = Array(before.utf8), b = Array(after.utf8)
    var pre = 0
    while pre < a.count && pre < b.count && a[pre] == b[pre] { pre += 1 }
    var suf = 0
    while suf < a.count - pre && suf < b.count - pre && a[a.count - 1 - suf] == b[b.count - 1 - suf] { suf += 1 }
    let oldEnd = a.count - suf, newEnd = b.count - suf
    return { o in o <= pre ? o : o >= oldEnd ? o - oldEnd + newEnd : newEnd }
  }
  func _map(_ r: Range<Index>, _ f: (Int) -> Int, in new: AttributedString) -> Range<Index>? {
    let lo = f(_off(r.lowerBound)), hi = f(_off(r.upperBound))
    guard lo <= hi, hi <= new._string.utf8.count else { return nil }
    let l = new._idx(lo), h = new._idx(hi)
    guard l._i.samePosition(in: new._string.unicodeScalars) != nil, h._i.samePosition(in: new._string.unicodeScalars) != nil else { return nil }
    return l..<h
  }
  /// runs `body` on the string and gives back `range` where its text ended up
  @available(iOS 26.0, *)
  public mutating func transform<E: Error>(updating range: Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) -> Range<Index>? {
    let old = self
    try body(&self)
    return old._map(range, AttributedString._track(old._string, _string), in: self)
  }
  @available(iOS 26.0, *)
  public mutating func transform<E: Error>(updating ranges: [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) -> [Range<Index>]? {
    let old = self
    try body(&self)
    let f = AttributedString._track(old._string, _string)
    var out: [Range<Index>] = []
    for r in ranges { guard let m = old._map(r, f, in: self) else { return nil }; out.append(m) }
    return out
  }
  @available(iOS 26.0, *)
  public mutating func transform<E: Error>(updating range: inout Range<Index>, body: (inout AttributedString) throws(E) -> Void) throws(E) {
    let old = self
    try body(&self)
    if let m = old._map(range, AttributedString._track(old._string, _string), in: self) { range = m } else { range = endIndex..<endIndex }
  }
  @available(iOS 26.0, *)
  public mutating func transform<E: Error>(updating ranges: inout [Range<Index>], body: (inout AttributedString) throws(E) -> Void) throws(E) {
    let old = self
    try body(&self)
    let f = AttributedString._track(old._string, _string)
    ranges = ranges.compactMap { old._map($0, f, in: self) }
  }
}

// MARK: - options

extension AttributedString {
  /// Options of AttributedString(localized:options:) for strings without grammar agreement.
  public struct FormattingOptions: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    /// marks each interpolated argument with its replacementIndex
    public static let applyReplacementIndexAttribute = FormattingOptions(rawValue: 1 << 0)
  }
  /// How interpolated attributed strings combine with the attributes around them.
  public struct InterpolationOptions: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let insertAttributesWithoutMerging = InterpolationOptions(rawValue: 1 << 0)
  }
}

// MARK: - localized with options and scopes

extension AttributedString {
  public init(localized resource: LocalizedStringResource) {
    self = AttributedString._localized(String(localized: resource), options: LocalizationOptions(), locale: resource.locale)
  }
  public init<S: AttributeScope>(localized resource: LocalizedStringResource, including scope: KeyPath<AttributeScopes, S.Type>) { self.init(localized: resource) }
  public init<S: AttributeScope>(localized resource: LocalizedStringResource, including scope: S.Type) { self.init(localized: resource) }
  public init<S: AttributeScope>(localized resource: LocalizedStringResource, options: LocalizationOptions, including scope: S.Type) {
    self.init(localized: resource, options: options)
  }
  public init<S: AttributeScope>(localized resource: LocalizedStringResource, options: LocalizationOptions, including scope: KeyPath<AttributeScopes, S.Type>) {
    self.init(localized: resource, options: options)
  }
  static func _lookup(_ key: StaticString, _ defaultValue: String.LocalizationValue, table: String?, bundle: Bundle?, locale: Locale?) -> String {
    let format = (bundle ?? .main).localizedString(forKey: "\(key)", value: defaultValue.key, table: table)
    return defaultValue.resolve(defaultValue.expandingPlurals(format))
  }
  static func _formatting(_ s: String, _ options: FormattingOptions, locale: Locale) -> AttributedString {
    var o = LocalizationOptions(); o.inflect = false; o.applyReplacementIndexAttribute = options.contains(.applyReplacementIndexAttribute)
    return _localized(s, options: o, locale: locale)
  }
  public init(localized key: StaticString, defaultValue: String.LocalizationValue, options: LocalizationOptions = .init(), table: String? = nil,
              bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil) {
    self = AttributedString._localized(AttributedString._lookup(key, defaultValue, table: table, bundle: bundle, locale: locale), options: options, locale: locale ?? .current)
  }
  public init(localized key: StaticString, defaultValue: String.LocalizationValue, options: FormattingOptions, table: String? = nil,
              bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil) {
    self = AttributedString._formatting(AttributedString._lookup(key, defaultValue, table: table, bundle: bundle, locale: locale), options, locale: locale ?? .current)
  }
  public init<S: AttributeScope>(localized key: StaticString, defaultValue: String.LocalizationValue, options: FormattingOptions = [], table: String? = nil,
                                 bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil, including scope: KeyPath<AttributeScopes, S.Type>) {
    self.init(localized: key, defaultValue: defaultValue, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: StaticString, defaultValue: String.LocalizationValue, options: LocalizationOptions, table: String? = nil,
                                 bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil, including scope: KeyPath<AttributeScopes, S.Type>) {
    self.init(localized: key, defaultValue: defaultValue, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: StaticString, defaultValue: String.LocalizationValue, options: FormattingOptions = [], table: String? = nil,
                                 bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil, including scope: S.Type) {
    self.init(localized: key, defaultValue: defaultValue, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: StaticString, defaultValue: String.LocalizationValue, options: LocalizationOptions, table: String? = nil,
                                 bundle: Bundle? = nil, locale: Locale? = nil, comment: StaticString? = nil, including scope: S.Type) {
    self.init(localized: key, defaultValue: defaultValue, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init(localized key: String.LocalizationValue, options: FormattingOptions, table: String? = nil, bundle: Bundle? = nil,
              locale: Locale? = nil, comment: StaticString? = nil) {
    let s = String(localized: key, table: table, bundle: bundle, locale: locale ?? .current, comment: comment)
    self = AttributedString._formatting(s, options, locale: locale ?? .current)
  }
  public init<S: AttributeScope>(localized key: String.LocalizationValue, options: FormattingOptions = [], table: String? = nil, bundle: Bundle? = nil,
                                 locale: Locale? = nil, comment: StaticString? = nil, including scope: KeyPath<AttributeScopes, S.Type>) {
    self.init(localized: key, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: String.LocalizationValue, options: LocalizationOptions, table: String? = nil, bundle: Bundle? = nil,
                                 locale: Locale? = nil, comment: StaticString? = nil, including scope: KeyPath<AttributeScopes, S.Type>) {
    self.init(localized: key, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: String.LocalizationValue, options: FormattingOptions = [], table: String? = nil, bundle: Bundle? = nil,
                                 locale: Locale? = nil, comment: StaticString? = nil, including scope: S.Type) {
    self.init(localized: key, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
  public init<S: AttributeScope>(localized key: String.LocalizationValue, options: LocalizationOptions, table: String? = nil, bundle: Bundle? = nil,
                                 locale: Locale? = nil, comment: StaticString? = nil, including scope: S.Type) {
    self.init(localized: key, options: options, table: table, bundle: bundle, locale: locale, comment: comment)
  }
}

// MARK: - Markdown files

extension AttributedString {
  public init(contentsOf url: URL, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: try Data(contentsOf: url), options: options, baseURL: baseURL ?? url)
  }
  public init<S: AttributeScope>(contentsOf url: URL, including scope: KeyPath<AttributeScopes, S.Type>, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: try Data(contentsOf: url), including: scope, options: options, baseURL: baseURL ?? url)
  }
  public init<S: AttributeScope>(contentsOf url: URL, including scope: S.Type, options: MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    try self.init(markdown: try Data(contentsOf: url), including: scope, options: options, baseURL: baseURL ?? url)
  }
}
extension NSAttributedString {
  public convenience init(markdown: String, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    self.init(try AttributedString(markdown: markdown, options: options, baseURL: baseURL))
  }
  public convenience init(markdown: Data, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    self.init(try AttributedString(markdown: markdown, options: options, baseURL: baseURL))
  }
  public convenience init(contentsOf url: URL, options: AttributedString.MarkdownParsingOptions = .init(), baseURL: URL? = nil) throws {
    self.init(try AttributedString(contentsOf: url, options: options, baseURL: baseURL))
  }
}

// MARK: - newer Foundation attributes

extension AttributedString {
  /// The direction a paragraph's text runs (iOS 26).
  public enum WritingDirection: Hashable, Codable, CustomStringConvertible, Sendable {
    case leftToRight, rightToLeft
    public var description: String { self == .leftToRight ? "leftToRight" : "rightToLeft" }
  }
  /// How a paragraph's lines align (iOS 26).
  public enum TextAlignment: Hashable, Codable, CustomStringConvertible, Sendable {
    case left, right, center
    public var description: String { self == .left ? "left" : self == .right ? "right" : "center" }
  }
  /// The height of a paragraph's lines (iOS 26).
  public struct LineHeight: Hashable, Codable, CustomStringConvertible, Sendable {
    enum _Kind: Hashable, Codable, Sendable { case exact(Double), leading(Double), multiple(Double), loose, normal, tight, variable }
    let _kind: _Kind
    public static func exact(points: CGFloat) -> LineHeight { LineHeight(_kind: .exact(Double(points))) }
    public static func leading(increase: CGFloat) -> LineHeight { LineHeight(_kind: .leading(Double(increase))) }
    public static func multiple(factor: CGFloat) -> LineHeight { LineHeight(_kind: .multiple(Double(factor))) }
    public static var loose: LineHeight { LineHeight(_kind: .loose) }
    public static var normal: LineHeight { LineHeight(_kind: .normal) }
    public static var tight: LineHeight { LineHeight(_kind: .tight) }
    public static var variable: LineHeight { LineHeight(_kind: .variable) }
    public var description: String {
      switch _kind {
      case .exact(let p): return "exact(points: \(p))"
      case .leading(let p): return "leading(increase: \(p))"
      case .multiple(let f): return "multiple(factor: \(f))"
      case .loose: return "loose"
      case .normal: return "normal"
      case .tight: return "tight"
      case .variable: return "variable"
      }
    }
  }
}

extension AttributeScopes.FoundationAttributes {
  /// `^[text](agreeWithArgument: 1)`: the run agrees with the localized string's argument at that index
  public enum AgreementArgumentAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = Int
    public static let name = "NSInflectionAgreementArgument"
    public static let markdownName = "agreeWithArgument"
  }
  /// `^[text](agreeWithConcept: 1)`: the run agrees with the concept at that index of LocalizationOptions.concepts
  public enum AgreementConceptAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = Int
    public static let name = "NSInflectionAgreementConcept"
    public static let markdownName = "agreeWithConcept"
  }
  /// `^[text](referentConcept: 1)`: the run is the referent of the concept at that index
  public enum ReferentConceptAttribute: CodableAttributedStringKey, MarkdownDecodableAttributedStringKey {
    public typealias Value = Int
    public static let name = "NSInflectionReferentConcept"
    public static let markdownName = "referentConcept"
  }
  /// which interpolated argument a run came from (FormattingOptions.applyReplacementIndexAttribute)
  public enum ReplacementIndexAttribute: CodableAttributedStringKey {
    public typealias Value = Int
    public static let name = "NSReplacementIndex"
  }
  /// a paragraph's writing direction
  public enum WritingDirectionAttribute: CodableAttributedStringKey {
    public typealias Value = AttributedString.WritingDirection
    public static let name = "Foundation.WritingDirection"
    public static var runBoundaries: AttributedString.AttributeRunBoundaries? { .paragraph }
  }
  /// The values of a localized string's interpolated arguments, on the runs they formatted.
  public struct LocalizedStringArgumentAttributes: AttributeScope {
    public let localizedDateArgument: LocalizedDateArgumentAttribute
    public let localizedDateIntervalArgument: LocalizedDateIntervalArgumentAttribute
    public let localizedNumericArgument: LocalizedNumericArgumentAttribute
    public let localizedURLArgument: LocalizedURLArgumentAttribute
    public enum LocalizedDateArgumentAttribute: CodableAttributedStringKey {
      public typealias Value = Date
      public static let name = "Foundation.LocalizedDateArgumentAttribute"
    }
    public enum LocalizedDateIntervalArgumentAttribute: CodableAttributedStringKey {
      public typealias Value = Range<Date>
      public static let name = "Foundation.LocalizedDateIntervalArgumentAttribute"
    }
    public enum LocalizedNumericArgumentAttribute: CodableAttributedStringKey {
      public enum Value: Hashable, Codable, Sendable {
        case int(Int64), uint(UInt64), double(Double), decimal(Decimal)
      }
      public static let name = "Foundation.LocalizedNumericArgumentAttribute"
    }
    public enum LocalizedURLArgumentAttribute: CodableAttributedStringKey {
      public typealias Value = URL
      public static let name = "Foundation.LocalizedURLArgumentAttribute"
    }
  }
}
extension AttributeDynamicLookup {
  public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.FoundationAttributes.LocalizedStringArgumentAttributes, T>) -> T { self[T.self] }
}

extension AttributeScopes {
  public var coreText: CoreTextAttributes.Type { CoreTextAttributes.self }
  /// Paragraph layout attributes text views lay out with (iOS 26).
  public struct CoreTextAttributes: AttributeScope {
    public let alignment: TextAlignmentAttribute
    public let lineHeight: LineHeightAttribute
    public enum TextAlignmentAttribute: CodableAttributedStringKey {
      public typealias Value = AttributedString.TextAlignment
      public static let name = "CoreText.TextAlignment"
      public static var runBoundaries: AttributedString.AttributeRunBoundaries? { .paragraph }
    }
    public enum LineHeightAttribute: CodableAttributedStringKey {
      public typealias Value = AttributedString.LineHeight
      public static let name = "CoreText.LineHeight"
      public static var runBoundaries: AttributedString.AttributeRunBoundaries? { .paragraph }
    }
  }

  public var accessibility: AccessibilityAttributes.Type { AccessibilityAttributes.self }
  /// How VoiceOver speaks and describes text (the UIAccessibility speech and text attributes).
  public struct AccessibilityAttributes: AttributeScope {
    public let accessibilityHeadingLevel: HeadingLevelAttribute
    public let accessibilitySpeechAdjustedPitch: AdjustedPitchAttribute
    public let accessibilitySpeechAnnouncementPriority: AnnouncementPriorityAttribute
    public let accessibilitySpeechAnnouncementsQueued: QueueAnnouncementAttribute
    public let accessibilitySpeechIncludesPunctuation: IncludesPunctuationAttribute
    public let accessibilitySpeechPhoneticNotation: IPANotationAttribute
    public let accessibilitySpeechSpellsOutCharacters: SpellOutAttribute
    public let accessibilitySpeechSSML: SpeechSSMLAttribute
    public let accessibilityTextCustom: TextCustomAttribute
    public let accessibilityTextualContext: TextualContextAttribute

    public enum HeadingLevelAttribute: CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
      public enum HeadingLevel: Int, Hashable, Codable, Sendable { case unspecified = 0, h1, h2, h3, h4, h5, h6 }
      public typealias Value = HeadingLevel
      public typealias ObjectiveCValue = NSNumber
      public static let name = "UIAccessibilityTextAttributeHeadingLevel"
      public static func objectiveCValue(for value: HeadingLevel) throws -> NSNumber { NSNumber(value: value.rawValue) }
      public static func value(for object: NSNumber) throws -> HeadingLevel { HeadingLevel(rawValue: Int(object.intValue)) ?? .unspecified }
    }
    public enum AdjustedPitchAttribute: CodableAttributedStringKey {
      public typealias Value = Double
      public static let name = "UIAccessibilitySpeechAttributePitch"
    }
    public enum AnnouncementPriorityAttribute: CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
      public enum AnnouncementPriority: String, Hashable, Codable, Sendable {
        case `default` = "UIAccessibilityPriorityDefault", high = "UIAccessibilityPriorityHigh", low = "UIAccessibilityPriorityLow"
      }
      public typealias Value = AnnouncementPriority
      public typealias ObjectiveCValue = NSString
      public static let name = "UIAccessibilitySpeechAttributeAnnouncementPriority"
      public static func objectiveCValue(for value: AnnouncementPriority) throws -> NSString { value.rawValue as NSString }
      public static func value(for object: NSString) throws -> AnnouncementPriority { AnnouncementPriority(rawValue: object as String) ?? .default }
    }
    public enum QueueAnnouncementAttribute: CodableAttributedStringKey {
      public typealias Value = Bool
      public static let name = "UIAccessibilitySpeechAttributeQueueAnnouncement"
    }
    public enum IncludesPunctuationAttribute: CodableAttributedStringKey {
      public typealias Value = Bool
      public static let name = "UIAccessibilitySpeechAttributePunctuation"
    }
    public enum IPANotationAttribute: CodableAttributedStringKey {
      public typealias Value = String
      public static let name = "UIAccessibilitySpeechAttributeIPANotation"
    }
    public enum SpellOutAttribute: CodableAttributedStringKey {
      public typealias Value = Bool
      public static let name = "UIAccessibilitySpeechAttributeSpellOut"
    }
    public enum SpeechSSMLAttribute: CodableAttributedStringKey {
      public typealias Value = String
      public static let name = "AXSpeechAttributeSSML"
    }
    public enum TextCustomAttribute: CodableAttributedStringKey {
      public typealias Value = [String]
      public static let name = "UIAccessibilityTextAttributeCustom"
    }
    public enum TextualContextAttribute: CodableAttributedStringKey, ObjectiveCConvertibleAttributedStringKey {
      public enum TextualContext: String, Hashable, Codable, Sendable {
        case console = "UIAccessibilityTextualContextConsole", fileSystem = "UIAccessibilityTextualContextFileSystem"
        case messaging = "UIAccessibilityTextualContextMessaging", narrative = "UIAccessibilityTextualContextNarrative"
        case plain = "UIAccessibilityTextualContextPlain", sourceCode = "UIAccessibilityTextualContextSourceCode"
        case spreadsheet = "UIAccessibilityTextualContextSpreadsheet", wordProcessing = "UIAccessibilityTextualContextWordProcessing"
      }
      public typealias Value = TextualContext
      public typealias ObjectiveCValue = NSString
      public static let name = "UIAccessibilityTextAttributeContext"
      public static func objectiveCValue(for value: TextualContext) throws -> NSString { value.rawValue as NSString }
      public static func value(for object: NSString) throws -> TextualContext { TextualContext(rawValue: object as String) ?? .plain }
    }
  }
}
extension AttributeDynamicLookup {
  public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.CoreTextAttributes, T>) -> T { self[T.self] }
  public subscript<T: AttributedStringKey>(dynamicMember keyPath: KeyPath<AttributeScopes.AccessibilityAttributes, T>) -> T { self[T.self] }
}

// MARK: - async characters and scalars

/// The Unicode scalars of a sequence of UTF-8 bytes (`bytes.unicodeScalars`).
public struct AsyncUnicodeScalarSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
  public typealias Element = Unicode.Scalar
  let base: Base
  public struct AsyncIterator: AsyncIteratorProtocol {
    var it: Base.AsyncIterator
    var pending: UInt8?
    public mutating func next() async rethrows -> Unicode.Scalar? {
      let first: UInt8
      if let p = pending { pending = nil; first = p } else if let b = try await it.next() { first = b } else { return nil }
      let need = first < 0x80 ? 0 : first >= 0xF0 ? 3 : first >= 0xE0 ? 2 : first >= 0xC0 ? 1 : 0
      var bytes = [first]
      while bytes.count <= need, let b = try await it.next() {
        if b & 0xC0 != 0x80 { pending = b; break }
        bytes.append(b)
      }
      var parser = Unicode.UTF8.ForwardParser(), iter = bytes.makeIterator()
      if case .valid(let e) = parser.parseScalar(from: &iter) { return Unicode.UTF8.decode(e) }
      return "\u{FFFD}"
    }
  }
  public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(it: base.makeAsyncIterator()) }
}
/// The characters of a sequence of UTF-8 bytes (`bytes.characters`).
public struct AsyncCharacterSequence<Base: AsyncSequence>: AsyncSequence where Base.Element == UInt8 {
  public typealias Element = Character
  let base: Base
  public struct AsyncIterator: AsyncIteratorProtocol {
    var scalars: AsyncUnicodeScalarSequence<Base>.AsyncIterator
    var buffer = ""
    public mutating func next() async rethrows -> Character? {
      // a character ends where the next scalar starts a new one
      while true {
        guard let s = try await scalars.next() else {
          guard let c = buffer.first else { return nil }
          buffer.removeFirst(); return c
        }
        buffer.unicodeScalars.append(s)
        if buffer.count > 1 { let c = buffer.first!; buffer.removeFirst(); return c }
      }
    }
  }
  public func makeAsyncIterator() -> AsyncIterator { AsyncIterator(scalars: AsyncUnicodeScalarSequence(base: base).makeAsyncIterator()) }
}
extension AsyncSequence where Element == UInt8 {
  public var unicodeScalars: AsyncUnicodeScalarSequence<Self> { AsyncUnicodeScalarSequence(base: self) }
  public var characters: AsyncCharacterSequence<Self> { AsyncCharacterSequence(base: self) }
}

extension PresentationIntent {
  /// the number of intent types, innermost first
  public var count: Int { components.count }
}

// MARK: - notifications as an async sequence

extension NotificationCenter {
  /// The notifications posted with this name (and object), as they arrive.
  public struct Notifications: AsyncSequence, @unchecked Sendable {
    public typealias Element = Notification
    let stream: AsyncStream<Notification>
    public struct Iterator: AsyncIteratorProtocol {
      var base: AsyncStream<Notification>.Iterator
      public mutating func next() async -> Notification? { await base.next() }
    }
    public func makeAsyncIterator() -> Iterator { Iterator(base: stream.makeAsyncIterator()) }
  }
  public func notifications(named name: Notification.Name, object: (any AnyObject & Sendable)? = nil) -> Notifications {
    let (stream, cont) = AsyncStream<Notification>.makeStream(bufferingPolicy: .unbounded)
    nonisolated(unsafe) let token = addObserver(forName: name, object: object, queue: nil) { n in cont.yield(n) }
    let center = self
    cont.onTermination = { _ in center.removeObserver(token) }
    return Notifications(stream: stream)
  }
}

// MARK: - NSString's variadic formatting (Objective-C variadic methods don't import)

extension NSString {
  public convenience init(format: NSString, _ args: CVarArg...) {
    let s = withVaList(args) { NSString(format: format as String, arguments: $0) }
    self.init(string: s as String)
  }
  public convenience init(format: NSString, locale: Locale?, _ args: CVarArg...) {
    self.init(string: String(format: format as String, locale: locale, arguments: args))
  }
  public func appendingFormat(_ format: NSString, _ args: CVarArg...) -> NSString {
    let s = withVaList(args) { NSString(format: format as String, arguments: $0) }
    return appending(s as String) as NSString
  }
}
