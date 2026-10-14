// isim Foundation: DataProtocol, MutableDataProtocol and their conformances, as Apple's Foundation (self-authored).
// A DataProtocol value is a run of bytes made of contiguous regions (`regions`); the defaults search and copy across
// them. Data, byte arrays, slices and the unsafe byte buffers conform, so `some DataProtocol` takes any of them.

public protocol DataProtocol: RandomAccessCollection where Element == UInt8, SubSequence: DataProtocol {
    associatedtype Regions: BidirectionalCollection
        where Regions.Element: DataProtocol & ContiguousBytes, Regions.Element.SubSequence: ContiguousBytes
    /// The contiguous regions that make up the bytes, in order.
    var regions: Regions { get }

    func firstRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index
    func lastRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index
    @discardableResult func copyBytes(to ptr: UnsafeMutableRawBufferPointer) -> Int
    @discardableResult func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>) -> Int
    @discardableResult func copyBytes(to ptr: UnsafeMutableRawBufferPointer, count: Int) -> Int
    @discardableResult func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int
    @discardableResult func copyBytes<R: RangeExpression>(to ptr: UnsafeMutableRawBufferPointer, from range: R) -> Int where R.Bound == Index
    @discardableResult func copyBytes<DestinationType, R: RangeExpression>(to ptr: UnsafeMutableBufferPointer<DestinationType>, from range: R) -> Int where R.Bound == Index
}

public protocol MutableDataProtocol: DataProtocol, MutableCollection, RangeReplaceableCollection {
    /// Sets the bytes in `range` to zero.
    mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index
}

extension DataProtocol {
    public func firstRange<D: DataProtocol>(of data: D) -> Range<Index>? { firstRange(of: data, in: startIndex..<endIndex) }
    public func lastRange<D: DataProtocol>(of data: D) -> Range<Index>? { lastRange(of: data, in: startIndex..<endIndex) }

    public func firstRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index {
        let r = range.relative(to: self)
        let length = data.count
        if length == 0 || length > distance(from: r.lowerBound, to: r.upperBound) { return nil }
        var position = r.lowerBound
        while distance(from: position, to: r.upperBound) >= length {
            let end = index(position, offsetBy: length)
            if self[position..<end].elementsEqual(data) { return position..<end }
            formIndex(after: &position)
        }
        return nil
    }

    public func lastRange<D: DataProtocol, R: RangeExpression>(of data: D, in range: R) -> Range<Index>? where R.Bound == Index {
        let r = range.relative(to: self)
        let length = data.count
        if length == 0 || length > distance(from: r.lowerBound, to: r.upperBound) { return nil }
        var position = index(r.upperBound, offsetBy: -length)
        while true {
            let end = index(position, offsetBy: length)
            if self[position..<end].elementsEqual(data) { return position..<end }
            if position == r.lowerBound { return nil }
            formIndex(before: &position)
        }
    }

    @discardableResult public func copyBytes(to ptr: UnsafeMutableRawBufferPointer) -> Int {
        copyBytes(to: ptr, from: startIndex..<endIndex)
    }
    @discardableResult public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>) -> Int {
        copyBytes(to: UnsafeMutableRawBufferPointer(ptr), from: startIndex..<endIndex)
    }
    @discardableResult public func copyBytes(to ptr: UnsafeMutableRawBufferPointer, count: Int) -> Int {
        copyBytes(to: ptr, from: startIndex..<index(startIndex, offsetBy: count))
    }
    @discardableResult public func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int {
        copyBytes(to: UnsafeMutableRawBufferPointer(ptr), from: startIndex..<index(startIndex, offsetBy: count))
    }
    @discardableResult public func copyBytes<DestinationType, R: RangeExpression>(to ptr: UnsafeMutableBufferPointer<DestinationType>, from range: R) -> Int where R.Bound == Index {
        copyBytes(to: UnsafeMutableRawBufferPointer(ptr), from: range)
    }
    /// Copies up to `ptr.count` bytes of `range`, region by region; returns the number of bytes copied.
    @discardableResult public func copyBytes<R: RangeExpression>(to ptr: UnsafeMutableRawBufferPointer, from range: R) -> Int where R.Bound == Index {
        precondition(ptr.baseAddress != nil || ptr.isEmpty, "the destination has no storage")
        let slice = self[range.relative(to: self)]
        let total = Swift.min(ptr.count, slice.count)
        var copied = 0
        for region in slice.regions where copied < total {
            region.withUnsafeBytes { bytes in
                let n = Swift.min(bytes.count, total - copied)
                if n > 0 { ptr.baseAddress!.advanced(by: copied).copyMemory(from: bytes.baseAddress!, byteCount: n) }
                copied += n
            }
        }
        return copied
    }
}

extension MutableDataProtocol {
    public mutating func resetBytes<R: RangeExpression>(in range: R) where R.Bound == Index {
        let r = range.relative(to: self)
        replaceSubrange(r, with: repeatElement(UInt8(0), count: distance(from: r.lowerBound, to: r.upperBound)))
    }
}

// MARK: - conformances

extension Data: MutableDataProtocol {
    public var regions: CollectionOfOne<Data> { CollectionOfOne(self) }
}

extension Array: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<Array<UInt8>> { CollectionOfOne(self) }
}
extension Array: MutableDataProtocol where Element == UInt8 {}

extension ArraySlice: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<ArraySlice<UInt8>> { CollectionOfOne(self) }
}
extension ArraySlice: ContiguousBytes where Element == UInt8 {}

extension ContiguousArray: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<ContiguousArray<UInt8>> { CollectionOfOne(self) }
}
extension ContiguousArray: MutableDataProtocol where Element == UInt8 {}
extension ContiguousArray: ContiguousBytes where Element == UInt8 {}

extension EmptyCollection: DataProtocol where Element == UInt8 {
    public var regions: EmptyCollection<Data> { EmptyCollection<Data>() }
}
extension EmptyCollection: ContiguousBytes where Element == UInt8 {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        try body(UnsafeRawBufferPointer(start: nil, count: 0))
    }
}

extension CollectionOfOne: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<CollectionOfOne<UInt8>> { CollectionOfOne<CollectionOfOne<UInt8>>(self) }
}
extension CollectionOfOne: ContiguousBytes where Element == UInt8 {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        var byte = self[startIndex]
        return try Swift.withUnsafeBytes(of: &byte) { try body($0) }
    }
}

extension UnsafeRawBufferPointer: DataProtocol {
    public var regions: CollectionOfOne<UnsafeRawBufferPointer> { CollectionOfOne(self) }
}
extension UnsafeRawBufferPointer: ContiguousBytes {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try body(self) }
}

extension UnsafeMutableRawBufferPointer: DataProtocol {
    public var regions: CollectionOfOne<UnsafeMutableRawBufferPointer> { CollectionOfOne(self) }
}
extension UnsafeMutableRawBufferPointer: ContiguousBytes {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try body(UnsafeRawBufferPointer(self)) }
}

extension UnsafeBufferPointer: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<UnsafeBufferPointer<UInt8>> { CollectionOfOne(self) }
}
extension UnsafeBufferPointer: ContiguousBytes where Element == UInt8 {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try body(UnsafeRawBufferPointer(self)) }
}

extension UnsafeMutableBufferPointer: DataProtocol where Element == UInt8 {
    public var regions: CollectionOfOne<UnsafeMutableBufferPointer<UInt8>> { CollectionOfOne(self) }
}
extension UnsafeMutableBufferPointer: ContiguousBytes where Element == UInt8 {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try body(UnsafeRawBufferPointer(self)) }
}

extension Slice: ContiguousBytes where Base: ContiguousBytes {
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R {
        let offset = base.distance(from: base.startIndex, to: startIndex)
        return try base.withUnsafeBytes { all in
            try body(UnsafeRawBufferPointer(rebasing: all[offset..<(offset + count)]))
        }
    }
}

extension Slice: DataProtocol where Base: DataProtocol {
    /// The parts of the base's regions that fall inside the slice.
    public var regions: [Base.Regions.Element.SubSequence] {
        var regionUpper = base.startIndex
        return base.regions.compactMap { region -> Base.Regions.Element.SubSequence? in
            let regionLower = regionUpper
            regionUpper = base.index(regionUpper, offsetBy: region.count)
            let lower = Swift.max(startIndex, regionLower), upper = Swift.min(endIndex, regionUpper)
            guard lower < upper else { return nil }
            let from = region.index(region.startIndex, offsetBy: base.distance(from: regionLower, to: lower))
            let to = region.index(region.startIndex, offsetBy: base.distance(from: regionLower, to: upper))
            return region[from..<to]
        }
    }
}
extension Slice: MutableDataProtocol where Base: MutableDataProtocol {}
