// isim SwiftUI: a minimal IndexSet and `remove(atOffsets:)` / `move(fromOffsets:toOffset:)` for list editing
// (onDelete / onMove), used only while isim's Foundation overlay has no IndexSet of its own. build-overlays.sh
// defines ISIM_FOUNDATION_INDEXSET when Foundation provides it, and this file then compiles to nothing.
#if !ISIM_FOUNDATION_INDEXSET
/// Sorted, unique integers (Foundation's IndexSet subset).
public struct IndexSet: Hashable, Sendable, RandomAccessCollection, ExpressibleByArrayLiteral, CustomStringConvertible {
    var items: [Int] = []
    public init() {}
    public init(integer: Int) { items = [integer] }
    public init<S: Sequence>(_ s: S) where S.Element == Int { items = Array(Set(s)).sorted() }
    public init(integersIn r: Range<Int>) { items = Array(r) }
    public init(integersIn r: ClosedRange<Int>) { items = Array(r) }
    public init(arrayLiteral elements: Int...) { self.init(elements) }
    public var startIndex: Int { 0 }
    public var endIndex: Int { items.count }
    public subscript(i: Int) -> Int { items[i] }
    public func contains(_ i: Int) -> Bool { items.contains(i) }
    @discardableResult public mutating func insert(_ i: Int) -> (inserted: Bool, memberAfterInsert: Int) {
        if items.contains(i) { return (false, i) }
        items.append(i); items.sort(); return (true, i)
    }
    @discardableResult public mutating func remove(_ i: Int) -> Int? { guard let k = items.firstIndex(of: i) else { return nil }; return items.remove(at: k) }
    public func union(_ o: IndexSet) -> IndexSet { IndexSet(items + o.items) }
    public var description: String { "\(items.count) indexes" }
}
extension RangeReplaceableCollection {
    /// Removes the elements at the offsets (onDelete).
    public mutating func remove(atOffsets offsets: IndexSet) {
        for o in offsets.reversed() { remove(at: index(startIndex, offsetBy: o)) }
    }
}
extension MutableCollection where Self: RangeReplaceableCollection {
    /// Moves the elements at the offsets to `destination` (an offset in the collection before the move; onMove).
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[index(startIndex, offsetBy: $0)] }
        let before = source.filter { $0 < destination }.count
        remove(atOffsets: source)
        insert(contentsOf: moving, at: index(startIndex, offsetBy: destination - before))
    }
}
#endif
