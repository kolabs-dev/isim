// isim Foundation: IndexSet (value type bridged to NSIndexSet), SortComparator / SortDescriptor / KeyPathComparator
// and sorting with them, Sequence conformances for Foundation collection classes, key-value observing in Swift
// (observe(\.x), NSKeyValueObservation, publisher(for:)).
import Combine

// MARK: - IndexSet
public struct IndexSet: Hashable, Sendable, BidirectionalCollection, SetAlgebra, CustomStringConvertible, Codable {
    public typealias Element = Int
    var ranges: [Range<Int>] = []        // sorted, disjoint, non-adjacent

    public struct Index: Comparable, Hashable, Sendable {
        let range: Int, value: Int
        public static func < (a: Index, b: Index) -> Bool { a.range != b.range ? a.range < b.range : a.value < b.value }
    }
    public struct RangeView: RandomAccessCollection, Sendable {
        let ranges: [Range<Int>]
        public var startIndex: Int { 0 }
        public var endIndex: Int { ranges.count }
        public subscript(i: Int) -> Range<Int> { ranges[i] }
    }

    public init() {}
    public init(integer: Int) { ranges = [integer..<(integer + 1)] }
    public init<R: RangeExpression>(integersIn range: R) where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        if !r.isEmpty { ranges = [r] }
    }
    public init<S: Sequence>(_ sequence: S) where S.Element == Int { for i in sequence { insert(i) } }
    public init(arrayLiteral elements: Int...) { self.init(elements) }

    public var startIndex: Index { ranges.isEmpty ? endIndex : Index(range: 0, value: ranges[0].lowerBound) }
    public var endIndex: Index { Index(range: ranges.count, value: 0) }
    public func index(after i: Index) -> Index {
        let r = ranges[i.range]
        if i.value + 1 < r.upperBound { return Index(range: i.range, value: i.value + 1) }
        return i.range + 1 < ranges.count ? Index(range: i.range + 1, value: ranges[i.range + 1].lowerBound) : endIndex
    }
    public func index(before i: Index) -> Index {
        if i.range < ranges.count, i.value > ranges[i.range].lowerBound { return Index(range: i.range, value: i.value - 1) }
        let p = i.range - 1
        return Index(range: p, value: ranges[p].upperBound - 1)
    }
    public subscript(i: Index) -> Int { i.value }
    public var count: Int { ranges.reduce(0) { $0 + $1.count } }
    public var isEmpty: Bool { ranges.isEmpty }
    public var first: Int? { ranges.first?.lowerBound }
    public var last: Int? { ranges.last.map { $0.upperBound - 1 } }
    public var rangeView: RangeView { RangeView(ranges: ranges) }
    public func rangeView<R: RangeExpression>(of range: R) -> RangeView where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        return RangeView(ranges: ranges.compactMap { let c = $0.clamped(to: r); return c.isEmpty ? nil : c })
    }
    public func contains(_ v: Int) -> Bool { ranges.contains { $0.contains(v) } }
    public func contains<R: RangeExpression>(integersIn range: R) -> Bool where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        return r.isEmpty || ranges.contains { $0.lowerBound <= r.lowerBound && r.upperBound <= $0.upperBound }
    }
    public func contains(integersIn other: IndexSet) -> Bool { other.ranges.allSatisfy { contains(integersIn: $0) } }
    public func intersects<R: RangeExpression>(integersIn range: R) -> Bool where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        return ranges.contains { $0.overlaps(r) }
    }
    public func count<R: RangeExpression>(in range: R) -> Int where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        return ranges.reduce(0) { $0 + $1.clamped(to: r).count }
    }
    public func integerGreaterThan(_ v: Int) -> Int? { first { $0 > v } }
    public func integerLessThan(_ v: Int) -> Int? { reversed().first { $0 < v } }
    public func integerGreaterThanOrEqualTo(_ v: Int) -> Int? { first { $0 >= v } }
    public func integerLessThanOrEqualTo(_ v: Int) -> Int? { reversed().first { $0 <= v } }

    mutating func add(_ r: Range<Int>) {
        guard !r.isEmpty else { return }
        var lo = r.lowerBound, hi = r.upperBound
        var out: [Range<Int>] = []
        var placed = false
        for x in ranges {
            if x.upperBound < lo { out.append(x) }
            else if x.lowerBound > hi { if !placed { out.append(lo..<hi); placed = true }; out.append(x) }
            else { lo = Swift.min(lo, x.lowerBound); hi = Swift.max(hi, x.upperBound) }
        }
        if !placed { out.append(lo..<hi) }
        ranges = out
    }
    mutating func cut(_ r: Range<Int>) {
        guard !r.isEmpty else { return }
        var out: [Range<Int>] = []
        for x in ranges {
            if x.upperBound <= r.lowerBound || x.lowerBound >= r.upperBound { out.append(x); continue }
            if x.lowerBound < r.lowerBound { out.append(x.lowerBound..<r.lowerBound) }
            if x.upperBound > r.upperBound { out.append(r.upperBound..<x.upperBound) }
        }
        ranges = out
    }
    @discardableResult public mutating func insert(_ v: Int) -> (inserted: Bool, memberAfterInsert: Int) {
        if contains(v) { return (false, v) }
        add(v..<(v + 1)); return (true, v)
    }
    @discardableResult public mutating func update(with v: Int) -> Int? { insert(v).inserted ? nil : v }
    public mutating func insert<R: RangeExpression>(integersIn range: R) where R.Bound == Int { add(range.relative(to: Int.min..<Int.max)) }
    @discardableResult public mutating func remove(_ v: Int) -> Int? { guard contains(v) else { return nil }; cut(v..<(v + 1)); return v }
    public mutating func remove<R: RangeExpression>(integersIn range: R) where R.Bound == Int { cut(range.relative(to: Int.min..<Int.max)) }
    public mutating func removeAll() { ranges = [] }
    public func union(_ o: IndexSet) -> IndexSet { var s = self; for r in o.ranges { s.add(r) }; return s }
    public func intersection(_ o: IndexSet) -> IndexSet {
        var s = IndexSet()
        for a in ranges { for b in o.ranges { let c = a.clamped(to: b); if !c.isEmpty { s.add(c) } } }
        return s
    }
    public func symmetricDifference(_ o: IndexSet) -> IndexSet { union(o).subtracting(intersection(o)) }
    public func subtracting(_ o: IndexSet) -> IndexSet { var s = self; for r in o.ranges { s.cut(r) }; return s }
    public mutating func formUnion(_ o: IndexSet) { self = union(o) }
    public mutating func formIntersection(_ o: IndexSet) { self = intersection(o) }
    public mutating func formSymmetricDifference(_ o: IndexSet) { self = symmetricDifference(o) }
    public mutating func subtract(_ o: IndexSet) { self = subtracting(o) }
    public func filteredIndexSet(includeInteger: (Int) throws -> Bool) rethrows -> IndexSet { IndexSet(try filter(includeInteger)) }
    public func filteredIndexSet<R: RangeExpression>(in range: R, includeInteger: (Int) throws -> Bool) rethrows -> IndexSet where R.Bound == Int {
        let r = range.relative(to: Int.min..<Int.max)
        return IndexSet(try filter { r.contains($0) }.filter(includeInteger))
    }
    public mutating func shift(startingAt integer: Int, by delta: Int) {
        let moved = IndexSet(compactMap { $0 >= integer ? ($0 + delta >= integer || delta >= 0 ? $0 + delta : nil) : $0 })
        self = moved
    }
    public var description: String { "\(count) indexes" }
    public static func == (a: IndexSet, b: IndexSet) -> Bool { a.ranges == b.ranges }
    public func hash(into h: inout Hasher) { h.combine(ranges.count); for r in ranges { h.combine(r.lowerBound); h.combine(r.upperBound) } }
    public init(from decoder: Decoder) throws {
        var c = try decoder.unkeyedContainer()
        while !c.isAtEnd { let lo = try c.decode(Int.self), len = try c.decode(Int.self); add(lo..<(lo + len)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.unkeyedContainer()
        for r in ranges { try c.encode(r.lowerBound); try c.encode(r.count) }
    }
}
extension IndexSet: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSIndexSet {
        let s = NSMutableIndexSet()
        for r in ranges { s.add(in: NSRange(location: r.lowerBound, length: r.count)) }
        return s
    }
    public static func _forceBridgeFromObjectiveC(_ x: NSIndexSet, result: inout IndexSet?) {
        var s = IndexSet()
        for i in 0..<x._rangeCount() { let r = x._range(at: i); s.add(r.location..<(r.location + r.length)) }
        result = s
    }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSIndexSet, result: inout IndexSet?) -> Bool { _forceBridgeFromObjectiveC(x, result: &result); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSIndexSet?) -> IndexSet {
        var r: IndexSet?; if let s { _forceBridgeFromObjectiveC(s, result: &r) }; return r ?? IndexSet()
    }
}
extension Array {
    /// isim: Foundation's `remove(atOffsets:)` / `move(fromOffsets:toOffset:)` (SwiftUI list editing).
    public mutating func remove(atOffsets offsets: IndexSet) { for i in offsets.reversed() { remove(at: i) } }
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[$0] }
        let before = source.filter { $0 < destination }.count
        for i in source.reversed() { remove(at: i) }
        insert(contentsOf: moving, at: destination - before)
    }
}

// MARK: - sorting
@frozen public enum SortOrder: Hashable, Codable, Sendable { case forward, reverse }
public protocol SortComparator<Compared>: Hashable {
    associatedtype Compared
    func compare(_ lhs: Compared, _ rhs: Compared) -> ComparisonResult
    var order: SortOrder { get set }
}
extension ComparisonResult {
    func _with(_ order: SortOrder) -> ComparisonResult {
        order == .forward ? self : self == .orderedAscending ? .orderedDescending : self == .orderedDescending ? .orderedAscending : .orderedSame
    }
}
public struct ComparableComparator<Compared: Comparable>: SortComparator, Sendable {
    public var order: SortOrder
    public init(order: SortOrder = .forward) { self.order = order }
    public func compare(_ a: Compared, _ b: Compared) -> ComparisonResult {
        (a < b ? ComparisonResult.orderedAscending : a > b ? .orderedDescending : .orderedSame)._with(order)
    }
}
extension String {
    public struct StandardComparator: SortComparator, Codable, Sendable {
        let kind: Int        // 0 lexical, 1 localized, 2 localizedStandard
        public var order: SortOrder
        public init(_ base: StandardComparator, order: SortOrder = .forward) { kind = base.kind; self.order = order }
        init(kind: Int, order: SortOrder = .forward) { self.kind = kind; self.order = order }
        public static let lexical = StandardComparator(kind: 0)
        public static let localized = StandardComparator(kind: 1)
        public static let localizedStandard = StandardComparator(kind: 2)
        public func compare(_ a: String, _ b: String) -> ComparisonResult {
            let r: ComparisonResult
            switch kind {
            case 0: r = a < b ? .orderedAscending : a > b ? .orderedDescending : .orderedSame
            case 1: r = a.localizedCompare(b)
            default: r = a.localizedStandardCompare(b)
            }
            return r._with(order)
        }
    }
}
extension SortComparator where Self == String.StandardComparator {
    public static var localizedStandard: String.StandardComparator { .localizedStandard }
    public static var localized: String.StandardComparator { .localized }
    public static var lexical: String.StandardComparator { .lexical }
}
public struct KeyPathComparator<Compared>: SortComparator, @unchecked Sendable {
    public let keyPath: PartialKeyPath<Compared>
    public var order: SortOrder
    let cmp: (Any, Any) -> ComparisonResult
    let comparatorID: AnyHashable
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) {
        self.keyPath = keyPath; self.order = order
        cmp = { a, b in let x = a as! Value, y = b as! Value; return x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame }
        comparatorID = 0
    }
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) {
        self.keyPath = keyPath; self.order = order
        cmp = { a, b in
            switch (a as! Value?, b as! Value?) {
            case let (x?, y?): return x < y ? .orderedAscending : x > y ? .orderedDescending : .orderedSame
            case (nil, nil): return .orderedSame
            case (nil, _): return .orderedAscending
            default: return .orderedDescending
            }
        }
        comparatorID = 0
    }
    public init<Value, C: SortComparator>(_ keyPath: KeyPath<Compared, Value>, comparator: C, order: SortOrder = .forward) where C.Compared == Value {
        self.keyPath = keyPath; self.order = order
        var c = comparator; c.order = .forward
        cmp = { a, b in c.compare(a as! Value, b as! Value) }
        comparatorID = AnyHashable(c)
    }
    public func compare(_ a: Compared, _ b: Compared) -> ComparisonResult { cmp(a[keyPath: keyPath], b[keyPath: keyPath])._with(order) }
    public static func == (a: Self, b: Self) -> Bool { a.keyPath == b.keyPath && a.order == b.order && a.comparatorID == b.comparatorID }
    public func hash(into h: inout Hasher) { h.combine(keyPath); h.combine(order) }
}
/// iOS 15 SortDescriptor (key path based; works with NSObject subclasses and Swift types).
public struct SortDescriptor<Compared>: SortComparator, @unchecked Sendable {
    var base: KeyPathComparator<Compared>
    public var order: SortOrder { get { base.order } set { base.order = newValue } }
    public var keyPath: PartialKeyPath<Compared>? { base.keyPath }
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value>, order: SortOrder = .forward) { base = KeyPathComparator(keyPath, order: order) }
    public init<Value: Comparable>(_ keyPath: KeyPath<Compared, Value?>, order: SortOrder = .forward) { base = KeyPathComparator(keyPath, order: order) }
    public init(_ keyPath: KeyPath<Compared, String>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder = .forward) {
        base = KeyPathComparator(keyPath, comparator: comparator, order: order)
    }
    public init(_ keyPath: KeyPath<Compared, String?>, comparator: String.StandardComparator = .localizedStandard, order: SortOrder = .forward) {
        base = KeyPathComparator(keyPath, comparator: _OptionalStringComparator(comparator), order: order)
    }
    public func compare(_ a: Compared, _ b: Compared) -> ComparisonResult { base.compare(a, b) }
}
struct _OptionalStringComparator: SortComparator {
    var inner: String.StandardComparator
    var order: SortOrder = .forward
    init(_ c: String.StandardComparator) { inner = c }
    func compare(_ a: String?, _ b: String?) -> ComparisonResult {
        switch (a, b) {
        case let (x?, y?): return inner.compare(x, y)._with(order)
        case (nil, nil): return .orderedSame
        case (nil, _): return ComparisonResult.orderedAscending._with(order)
        default: return ComparisonResult.orderedDescending._with(order)
        }
    }
}
extension Sequence {
    public func sorted<C: SortComparator>(using comparator: C) -> [Element] where C.Compared == Element {
        sorted { comparator.compare($0, $1) == .orderedAscending }
    }
    public func sorted<S: Sequence, C: SortComparator>(using comparators: S) -> [Element] where S.Element == C, C.Compared == Element {
        let list = Array(comparators)
        return sorted { a, b in
            for c in list { let r = c.compare(a, b); if r != .orderedSame { return r == .orderedAscending } }
            return false
        }
    }
}
extension MutableCollection where Self: RandomAccessCollection {
    public mutating func sort<C: SortComparator>(using comparator: C) where C.Compared == Element {
        sort { comparator.compare($0, $1) == .orderedAscending }
    }
    public mutating func sort<S: Sequence, C: SortComparator>(using comparators: S) where S.Element == C, C.Compared == Element {
        let list = Array(comparators)
        sort { a, b in
            for c in list { let r = c.compare(a, b); if r != .orderedSame { return r == .orderedAscending } }
            return false
        }
    }
}
extension NSSortDescriptor {
    /// NSSortDescriptor from a key path of an @objc property (Apple: init(keyPath:ascending:)).
    public convenience init<Root, Value>(keyPath: KeyPath<Root, Value>, ascending: Bool) {
        self.init(key: keyPath._kvcKeyPathString, ascending: ascending)
    }
}

// MARK: - Sequence conformances for Foundation collection classes
extension NSOrderedSet: Sequence {
    public func makeIterator() -> IndexingIterator<[Any]> { array.makeIterator() }
}
extension NSIndexSet: Sequence {
    public func makeIterator() -> IndexingIterator<[Int]> { Array((self as IndexSet)).makeIterator() }
}
extension NSPointerArray: Sequence {
    public func makeIterator() -> IndexingIterator<[Any]> { allObjects.makeIterator() }
}
extension BlockOperation {
    /// the blocks, without a dynamic cast of each block object (isim's runtime cannot cast a block object to a
    /// block function type when bridging an NSArray)
    public var executionBlocks: [@convention(block) () -> Void] {
        guard let blocks = value(forKey: "executionBlocks") as? NSArray else { return [] }
        return (0..<blocks.count).map { unsafeBitCast(blocks.object(at: $0) as AnyObject, to: (@convention(block) () -> Void).self) }
    }
}

// MARK: - key-value observing in Swift
public struct NSKeyValueObservedChange<Value> {
    public typealias Kind = NSKeyValueChange
    public let kind: Kind
    public let newValue: Value?
    public let oldValue: Value?
    public let indexes: IndexSet?
    public let isPrior: Bool
}
public class NSKeyValueObservation: NSObject {
    weak var object: NSObject?
    let path: String
    var callback: ((NSObject, [NSKeyValueChangeKey: Any]) -> Void)?
    init(object: NSObject, path: String, callback: @escaping (NSObject, [NSKeyValueChangeKey: Any]) -> Void) {
        self.object = object; self.path = path; self.callback = callback
    }
    func start(_ options: NSKeyValueObservingOptions) { object?.addObserver(self, forKeyPath: path, options: options, context: nil) }
    public func invalidate() {
        if let o = object { o.removeObserver(self, forKeyPath: path, context: nil) }
        object = nil; callback = nil
    }
    public override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        guard let o = object as? NSObject, let cb = callback else { return }
        cb(o, change ?? [:])
    }
    deinit { if let o = object { o.removeObserver(self, forKeyPath: path, context: nil) } }
}
public protocol _KeyValueCodingAndObserving {}
extension NSObject: _KeyValueCodingAndObserving {}
func _kvcString(_ kp: AnyKeyPath) -> String {
    guard let s = kp._kvcKeyPathString else { fatalError("Could not extract a String from KeyPath \(kp): use an @objc property") }
    return s
}
extension _KeyValueCodingAndObserving {
    public func observe<Value>(_ keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [],
                               changeHandler: @escaping (Self, NSKeyValueObservedChange<Value>) -> Void) -> NSKeyValueObservation {
        let obs = NSKeyValueObservation(object: self as! NSObject, path: _kvcString(keyPath)) { obj, change in
            func value(_ k: NSKeyValueChangeKey) -> Value? {
                guard let v = change[k], !(v is NSNull) else { return nil }
                return v as? Value
            }
            let kindRaw = (change[.kindKey] as? NSNumber)?.uintValue ?? 1
            let c = NSKeyValueObservedChange<Value>(kind: NSKeyValueChange(rawValue: kindRaw) ?? .setting, newValue: value(.newKey), oldValue: value(.oldKey),
                                                    indexes: change[.indexesKey] as? IndexSet, isPrior: (change[.notificationIsPriorKey] as? Bool) ?? false)
            changeHandler(obj as! Self, c)
        }
        obs.start(options)
        return obs
    }
    public func willChangeValue<Value>(for keyPath: KeyPath<Self, Value>) { (self as! NSObject).willChangeValue(forKey: _kvcString(keyPath)) }
    public func didChangeValue<Value>(for keyPath: KeyPath<Self, Value>) { (self as! NSObject).didChangeValue(forKey: _kvcString(keyPath)) }
}
extension NSObject {
    public struct KeyValueObservingPublisher<Subject: NSObject, Value>: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
        public let object: Subject
        public let keyPath: KeyPath<Subject, Value>
        public let options: NSKeyValueObservingOptions
        public init(object: Subject, keyPath: KeyPath<Subject, Value>, options: NSKeyValueObservingOptions) { self.object = object; self.keyPath = keyPath; self.options = options }
        public func receive<S: Subscriber>(subscriber: S) where S.Input == Value, S.Failure == Never {
            let token = _FoundationRef<NSKeyValueObservation?>(nil)
            let sub = _FoundationForwardingSubscription(subscriber, onCancel: { token.value?.invalidate(); token.value = nil })
            subscriber.receive(subscription: sub)
            let kp = keyPath
            token.value = object.observe(keyPath, options: options.union(.new)) { obj, change in
                if change.isPrior { return }
                sub.send(obj[keyPath: kp])
            }
        }
    }
}
extension _KeyValueCodingAndObserving where Self: NSObject {
    public func publisher<Value>(for keyPath: KeyPath<Self, Value>, options: NSKeyValueObservingOptions = [.initial, .new]) -> NSObject.KeyValueObservingPublisher<Self, Value> {
        NSObject.KeyValueObservingPublisher(object: self, keyPath: keyPath, options: options)
    }
}
