// IndexPath: a value type list of indexes, bridged to NSIndexPath (UIKit adds row/section/item).
public struct IndexPath: RandomAccessCollection, MutableCollection, Hashable, Comparable, Sendable, ExpressibleByArrayLiteral,
                         CustomStringConvertible, CustomDebugStringConvertible, Codable {
    public typealias Element = Int
    public typealias Index = Int
    var storage: [Int]
    public init() { storage = [] }
    public init(indexes: [Int]) { storage = indexes }
    public init<S: Sequence>(indexes: S) where S.Element == Int { storage = Array(indexes) }
    public init(index: Int) { storage = [index] }
    public init(arrayLiteral elements: Int...) { storage = elements }
    public var startIndex: Int { 0 }
    public var endIndex: Int { storage.count }
    public subscript(i: Int) -> Int { get { storage[i] } set { storage[i] = newValue } }
    public subscript(range: Range<Int>) -> IndexPath { get { IndexPath(indexes: storage[range]) } set { storage.replaceSubrange(range, with: newValue.storage) } }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
    public mutating func append(_ other: IndexPath) { storage += other.storage }
    public mutating func append(_ other: Int) { storage.append(other) }
    public mutating func append(_ other: [Int]) { storage += other }
    public func appending(_ other: Int) -> IndexPath { IndexPath(indexes: storage + [other]) }
    public func appending(_ other: IndexPath) -> IndexPath { IndexPath(indexes: storage + other.storage) }
    public func appending(_ other: [Int]) -> IndexPath { IndexPath(indexes: storage + other) }
    public func dropLast() -> IndexPath { IndexPath(indexes: storage.dropLast()) }
    public func compare(_ other: IndexPath) -> ComparisonResult {
        for (a, b) in zip(storage, other.storage) where a != b { return a < b ? .orderedAscending : .orderedDescending }
        return storage.count == other.storage.count ? .orderedSame : storage.count < other.storage.count ? .orderedAscending : .orderedDescending
    }
    public static func < (a: IndexPath, b: IndexPath) -> Bool { a.compare(b) == .orderedAscending }
    public static func + (a: IndexPath, b: IndexPath) -> IndexPath { a.appending(b) }
    public static func += (a: inout IndexPath, b: IndexPath) { a.append(b) }
    public var description: String { storage.description }
    public var debugDescription: String { storage.description }
    public init(from decoder: Decoder) throws { storage = try [Int](from: decoder) }
    public func encode(to encoder: Encoder) throws { try storage.encode(to: encoder) }
}
extension IndexPath: _ObjectiveCBridgeable {
    public func _bridgeToObjectiveC() -> NSIndexPath {
        storage.withUnsafeBufferPointer { NSIndexPath(indexes: $0.baseAddress, length: $0.count) }
    }
    static func _from(_ x: NSIndexPath) -> IndexPath { IndexPath(indexes: (0..<x.length).map { Int(x.index(atPosition: $0)) }) }
    public static func _forceBridgeFromObjectiveC(_ x: NSIndexPath, result: inout IndexPath?) { result = _from(x) }
    public static func _conditionallyBridgeFromObjectiveC(_ x: NSIndexPath, result: inout IndexPath?) -> Bool { result = _from(x); return true }
    public static func _unconditionallyBridgeFromObjectiveC(_ s: NSIndexPath?) -> IndexPath { s.map(_from) ?? IndexPath() }
}
