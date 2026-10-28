// isim CoreMIDI: the Swift side of `import CoreMIDI`: builders, collections and sequences over packets and packet
// lists, and the mutable list pointers, over isim's C framework (frameworks/CoreMIDI, re-exported). Self-authored,
// Apple's names.
@_exported import CoreMIDI

private let packetHeader = MemoryLayout<MIDITimeStamp>.size + MemoryLayout<UInt16>.size           // timeStamp, length
private let eventPacketHeader = MemoryLayout<MIDITimeStamp>.size + MemoryLayout<UInt32>.size      // timeStamp, wordCount
private let packetListHeader = MemoryLayout<UInt32>.size                                         // numPackets
private let eventListHeader = MemoryLayout<MIDIProtocolID>.size + MemoryLayout<UInt32>.size       // protocol, numPackets

private func packetData(_ p: UnsafePointer<MIDIPacket>) -> UnsafePointer<UInt8> {
    UnsafeRawPointer(p).advanced(by: packetHeader).assumingMemoryBound(to: UInt8.self)
}
private func eventWords(_ p: UnsafePointer<MIDIEventPacket>) -> UnsafePointer<UInt32> {
    UnsafeRawPointer(p).advanced(by: eventPacketHeader).assumingMemoryBound(to: UInt32.self)
}

// MARK: - MIDI 1.0 packets

extension MIDIPacket {
    /// The bytes of a packet, by index.
    public struct ByteCollection: RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = UInt8
        let packet: UnsafePointer<MIDIPacket>
        public init(_ packet: UnsafePointer<MIDIPacket>) { self.packet = packet }
        public init?(_ packet: UnsafePointer<MIDIPacket>?) {
            guard let packet else { return nil }
            self.packet = packet
        }
        public var startIndex: Int { 0 }
        public var endIndex: Int { Int(packet.pointee.length) }
        public var count: Int { endIndex }
        public subscript(position: Int) -> UInt8 { packetData(packet)[position] }
    }

    /// The bytes of a packet, in order.
    public struct ByteSequence: Sequence {
        let packet: UnsafePointer<MIDIPacket>
        public var count: Int { Int(packet.pointee.length) }
        public func makeIterator() -> AnyIterator<UInt8> {
            var i = 0
            let n = count, data = packetData(packet)
            return AnyIterator { () -> UInt8? in
                guard i < n else { return nil }
                defer { i += 1 }
                return data[i]
            }
        }
    }

    /// Builds one packet of up to a number of bytes.
    public final class Builder {
        let storage: UnsafeMutableRawPointer
        let byteSize: Int
        public let capacity: Int
        public init(maximumNumberMIDIBytes: Int) {
            capacity = maximumNumberMIDIBytes
            byteSize = Swift.max(MemoryLayout<MIDIPacket>.size, packetHeader + maximumNumberMIDIBytes)
            storage = UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: 8)
            storage.initializeMemory(as: UInt8.self, repeating: 0, count: byteSize)
        }
        deinit { storage.deallocate() }
        var packet: UnsafeMutablePointer<MIDIPacket> { storage.assumingMemoryBound(to: MIDIPacket.self) }
        public var count: Int { Int(packet.pointee.length) }
        public var timeStamp: Int {
            get { Int(packet.pointee.timeStamp) }
            set { packet.pointee.timeStamp = MIDITimeStamp(newValue) }
        }
        public func append(_ bytes: UInt8...) {
            let n = count
            precondition(n + bytes.count <= capacity, "MIDIPacket.Builder: more bytes than its capacity")
            let data = storage.advanced(by: packetHeader).assumingMemoryBound(to: UInt8.self)
            for (i, b) in bytes.enumerated() { data[n + i] = b }
            packet.pointee.length = UInt16(n + bytes.count)
        }
        public func withUnsafeMutableMIDIPacketPointer<Result>(_ body: (inout UnsafeMutableMIDIPacketPointer) -> Result) -> Result {
            var p = UnsafeMutableMIDIPacketPointer(packet)
            return body(&p)
        }
        public func withUnsafePointer<Result>(_ body: (UnsafePointer<MIDIPacket>) -> Result) -> Result { body(UnsafePointer(packet)) }
    }
}

extension UnsafePointer where Pointee == MIDIPacket {
    /// The packet's bytes.
    public func bytes() -> MIDIPacket.ByteSequence { MIDIPacket.ByteSequence(packet: self) }
}

/// A mutable packet: its bytes by index and its time stamp.
public struct UnsafeMutableMIDIPacketPointer: MutableCollection, RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = UInt8
    public let UnsafeMutablePointer: Swift.UnsafeMutablePointer<MIDIPacket>
    public init(_ pointer: Swift.UnsafeMutablePointer<MIDIPacket>) { UnsafeMutablePointer = pointer }
    public init?(_ pointer: Swift.UnsafeMutablePointer<MIDIPacket>?) {
        guard let pointer else { return nil }
        UnsafeMutablePointer = pointer
    }
    var data: Swift.UnsafeMutablePointer<UInt8> { UnsafeMutableRawPointer(UnsafeMutablePointer).advanced(by: packetHeader).assumingMemoryBound(to: UInt8.self) }
    public var startIndex: Int { 0 }
    public var endIndex: Int { Int(UnsafeMutablePointer.pointee.length) }
    public var count: Int { endIndex }
    public var timeStamp: Int {
        get { Int(UnsafeMutablePointer.pointee.timeStamp) }
        nonmutating set { UnsafeMutablePointer.pointee.timeStamp = MIDITimeStamp(newValue) }
    }
    public subscript(position: Int) -> UInt8 {
        get { data[position] }
        nonmutating set { data[position] = newValue }
    }
}

extension MIDIPacketList {
    /// The packets of a list, as pointers.
    public struct UnsafeSequence: Sequence {
        let list: UnsafePointer<MIDIPacketList>
        public init(_ list: UnsafePointer<MIDIPacketList>) { self.list = list }
        public var count: Int { Int(list.pointee.numPackets) }
        public func makeIterator() -> AnyIterator<UnsafePointer<MIDIPacket>> {
            var i = 0
            let n = count
            var p = UnsafePointer(UnsafeRawPointer(list).advanced(by: packetListHeader).assumingMemoryBound(to: MIDIPacket.self))
            return AnyIterator { () -> UnsafePointer<MIDIPacket>? in
                guard i < n else { return nil }
                defer { i += 1; if i < n { p = UnsafePointer(MIDIPacketNext(p)) } }
                return p
            }
        }
    }

    /// The size of a list's header and packets, in bytes.
    public static func sizeInBytes(pktList: UnsafePointer<MIDIPacketList>) -> Int {
        var end = UnsafeRawPointer(pktList).advanced(by: packetListHeader)
        for p in UnsafeSequence(pktList) { end = UnsafeRawPointer(p).advanced(by: packetHeader + Int(p.pointee.length)) }
        return end - UnsafeRawPointer(pktList)
    }

    /// Builds a packet list in storage of a number of bytes.
    public final class Builder {
        let storage: UnsafeMutableRawPointer
        let byteSize: Int
        var current: UnsafeMutablePointer<MIDIPacket>
        public init(byteSize: Int) {
            self.byteSize = Swift.max(byteSize, MemoryLayout<MIDIPacketList>.size)
            storage = UnsafeMutableRawPointer.allocate(byteCount: self.byteSize, alignment: 8)
            storage.initializeMemory(as: UInt8.self, repeating: 0, count: self.byteSize)
            current = MIDIPacketListInit(storage.assumingMemoryBound(to: MIDIPacketList.self))
        }
        deinit { storage.deallocate() }
        var list: UnsafeMutablePointer<MIDIPacketList> { storage.assumingMemoryBound(to: MIDIPacketList.self) }
        public var count: Int { Int(list.pointee.numPackets) }
        @discardableResult
        public func append(timestamp: MIDITimeStamp, data: [UInt8]) -> UnsafePointer<MIDIPacket>? {
            guard let p = MIDIPacketListAdd(list, byteSize, current, timestamp, data.count, data) else { return nil }
            current = p
            return UnsafePointer(p)
        }
        public func clear() { current = MIDIPacketListInit(list) }
        public func withUnsafeMutableMIDIPacketListPointer<Result>(_ body: (inout UnsafeMutableMIDIPacketListPointer) -> Result) -> Result {
            var p = UnsafeMutableMIDIPacketListPointer(list, byteSize: byteSize)
            return body(&p)
        }
        public func withUnsafePointer<Result>(_ body: (UnsafePointer<MIDIPacketList>) -> Result) -> Result { body(UnsafePointer(list)) }
    }
}

extension UnsafePointer where Pointee == MIDIPacketList {
    /// The list's packets, as pointers.
    public func unsafeSequence() -> MIDIPacketList.UnsafeSequence { MIDIPacketList.UnsafeSequence(self) }
}
extension UnsafeMutablePointer where Pointee == MIDIPacketList {
    public func unsafeSequence() -> MIDIPacketList.UnsafeSequence { MIDIPacketList.UnsafeSequence(UnsafePointer(self)) }
}

/// A packet list in storage of a known size, to add packets to.
public struct UnsafeMutableMIDIPacketListPointer: Sequence {
    public let UnsafeMutablePointer: Swift.UnsafeMutablePointer<MIDIPacketList>
    let byteSize: Int
    public init(_ pointer: Swift.UnsafeMutablePointer<MIDIPacketList>, byteSize: Int) {
        UnsafeMutablePointer = pointer
        self.byteSize = byteSize
    }
    public init?(_ pointer: Swift.UnsafeMutablePointer<MIDIPacketList>?, byteSize: Int) {
        guard let pointer else { return nil }
        self.init(pointer, byteSize: byteSize)
    }
    public var count: Int { Int(UnsafeMutablePointer.pointee.numPackets) }
    public var listSizeInBytes: Int { MIDIPacketList.sizeInBytes(pktList: UnsafeMutablePointer) }
    public var lastPacket: Swift.UnsafeMutablePointer<MIDIPacket>? {
        var last: UnsafePointer<MIDIPacket>?
        for p in MIDIPacketList.UnsafeSequence(UnsafeMutablePointer) { last = p }
        return last.map { Swift.UnsafeMutablePointer(mutating: $0) }
    }
    @discardableResult
    public func append(timestamp: MIDITimeStamp, data: [UInt8]) -> UnsafePointer<MIDIPacket>? {
        let current = lastPacket ?? MIDIPacketListInit(UnsafeMutablePointer)
        return MIDIPacketListAdd(UnsafeMutablePointer, byteSize, current, timestamp, data.count, data).map { UnsafePointer($0) }
    }
    public func clear() { _ = MIDIPacketListInit(UnsafeMutablePointer) }
    public func makeIterator() -> AnyIterator<UnsafeMutableMIDIPacketPointer> {
        let it = MIDIPacketList.UnsafeSequence(UnsafeMutablePointer).makeIterator()
        return AnyIterator { it.next().map { UnsafeMutableMIDIPacketPointer(Swift.UnsafeMutablePointer(mutating: $0)) } }
    }
}

// MARK: - Universal MIDI Packets

extension MIDIEventPacket {
    /// The words of a packet, by index.
    public struct WordCollection: RandomAccessCollection {
        public typealias Index = Int
        public typealias Element = UInt32
        let packet: UnsafePointer<MIDIEventPacket>
        public init(_ packet: UnsafePointer<MIDIEventPacket>) { self.packet = packet }
        public init?(_ packet: UnsafePointer<MIDIEventPacket>?) {
            guard let packet else { return nil }
            self.packet = packet
        }
        public var startIndex: Int { 0 }
        public var endIndex: Int { Int(packet.pointee.wordCount) }
        public var count: Int { endIndex }
        public subscript(position: Int) -> UInt32 { eventWords(packet)[position] }
    }

    /// The words of a packet, in order.
    public struct WordSequence: Sequence {
        let packet: UnsafePointer<MIDIEventPacket>
        public var count: Int { Int(packet.pointee.wordCount) }
        public func makeIterator() -> AnyIterator<UInt32> {
            var i = 0
            let n = count, words = eventWords(packet)
            return AnyIterator { () -> UInt32? in
                guard i < n else { return nil }
                defer { i += 1 }
                return words[i]
            }
        }
    }

    /// Builds one packet of up to a number of words.
    public final class Builder {
        let storage: UnsafeMutablePointer<MIDIEventPacket>
        public let capacity: Int
        public init(maximumNumberMIDIWords: Int) {
            capacity = Swift.min(maximumNumberMIDIWords, 64)
            storage = .allocate(capacity: 1)
            storage.initialize(to: MIDIEventPacket())
        }
        deinit { storage.deallocate() }
        public var count: Int { Int(storage.pointee.wordCount) }
        public var timeStamp: Int {
            get { Int(storage.pointee.timeStamp) }
            set { storage.pointee.timeStamp = MIDITimeStamp(newValue) }
        }
        public func append(_ words: UInt32...) {
            let n = count
            precondition(n + words.count <= capacity, "MIDIEventPacket.Builder: more words than its capacity")
            let w = UnsafeMutableRawPointer(storage).advanced(by: eventPacketHeader).assumingMemoryBound(to: UInt32.self)
            for (i, x) in words.enumerated() { w[n + i] = x }
            storage.pointee.wordCount = UInt32(n + words.count)
        }
        public func withUnsafeMutableMIDIEventPacketPointer<Result>(_ body: (inout UnsafeMutableMIDIEventPacketPointer) -> Result) -> Result {
            var p = UnsafeMutableMIDIEventPacketPointer(storage)
            return body(&p)
        }
        public func withUnsafePointer<Result>(_ body: (UnsafePointer<MIDIEventPacket>) -> Result) -> Result { body(UnsafePointer(storage)) }
    }
}

extension UnsafePointer where Pointee == MIDIEventPacket {
    /// The packet's words.
    public func words() -> MIDIEventPacket.WordSequence { MIDIEventPacket.WordSequence(packet: self) }
}

/// A mutable Universal MIDI Packet: its words by index and its time stamp.
public struct UnsafeMutableMIDIEventPacketPointer: MutableCollection, RandomAccessCollection {
    public typealias Index = Int
    public typealias Element = UInt32
    public let UnsafeMutablePointer: Swift.UnsafeMutablePointer<MIDIEventPacket>
    public init(_ pointer: Swift.UnsafeMutablePointer<MIDIEventPacket>) { UnsafeMutablePointer = pointer }
    public init?(_ pointer: Swift.UnsafeMutablePointer<MIDIEventPacket>?) {
        guard let pointer else { return nil }
        UnsafeMutablePointer = pointer
    }
    var words: Swift.UnsafeMutablePointer<UInt32> { UnsafeMutableRawPointer(UnsafeMutablePointer).advanced(by: eventPacketHeader).assumingMemoryBound(to: UInt32.self) }
    public var startIndex: Int { 0 }
    public var endIndex: Int { Int(UnsafeMutablePointer.pointee.wordCount) }
    public var count: Int { endIndex }
    public var timeStamp: Int {
        get { Int(UnsafeMutablePointer.pointee.timeStamp) }
        nonmutating set { UnsafeMutablePointer.pointee.timeStamp = MIDITimeStamp(newValue) }
    }
    public subscript(position: Int) -> UInt32 {
        get { words[position] }
        nonmutating set { words[position] = newValue }
    }
}

extension MIDIEventList {
    /// The packets of an event list, as pointers.
    public struct UnsafeSequence: Sequence {
        let list: UnsafePointer<MIDIEventList>
        public init(_ list: UnsafePointer<MIDIEventList>) { self.list = list }
        public var count: Int { Int(list.pointee.numPackets) }
        public func makeIterator() -> AnyIterator<UnsafePointer<MIDIEventPacket>> {
            var i = 0
            let n = count
            var p = UnsafePointer(UnsafeRawPointer(list).advanced(by: eventListHeader).assumingMemoryBound(to: MIDIEventPacket.self))
            return AnyIterator { () -> UnsafePointer<MIDIEventPacket>? in
                guard i < n else { return nil }
                defer { i += 1; if i < n { p = UnsafePointer(MIDIEventPacketNext(p)) } }
                return p
            }
        }
    }

    /// The size of an event list's header and packets, in bytes.
    public static func sizeInBytes(pktList: UnsafePointer<MIDIEventList>) -> Int {
        var end = UnsafeRawPointer(pktList).advanced(by: eventListHeader)
        for p in UnsafeSequence(pktList) { end = UnsafeRawPointer(p).advanced(by: eventPacketHeader + 4 * Int(p.pointee.wordCount)) }
        return end - UnsafeRawPointer(pktList)
    }

    /// Builds an event list of a protocol, in storage of a number of words.
    public final class Builder {
        let storage: UnsafeMutableRawPointer
        let byteSize: Int
        var current: UnsafeMutablePointer<MIDIEventPacket>
        let midiProtocol: MIDIProtocolID
        public init(inProtocol: MIDIProtocolID, wordSize: Int) {
            midiProtocol = inProtocol
            byteSize = Swift.max(eventListHeader + eventPacketHeader + 4 * wordSize, MemoryLayout<MIDIEventList>.size)
            storage = UnsafeMutableRawPointer.allocate(byteCount: byteSize, alignment: 8)
            storage.initializeMemory(as: UInt8.self, repeating: 0, count: byteSize)
            current = MIDIEventListInit(storage.assumingMemoryBound(to: MIDIEventList.self), inProtocol)
        }
        deinit { storage.deallocate() }
        var list: UnsafeMutablePointer<MIDIEventList> { storage.assumingMemoryBound(to: MIDIEventList.self) }
        public var count: Int { Int(list.pointee.numPackets) }
        @discardableResult
        public func append(timestamp: MIDITimeStamp, words: [UInt32]) -> UnsafePointer<MIDIEventPacket>? {
            guard let p = MIDIEventListAdd(list, byteSize, current, timestamp, words.count, words) else { return nil }
            current = p
            return UnsafePointer(p)
        }
        public func clear() { current = MIDIEventListInit(list, midiProtocol) }
        public func withUnsafeMutableMIDIEventListPointer<Result>(_ body: (inout UnsafeMutableMIDIEventListPointer) -> Result) -> Result {
            var p = UnsafeMutableMIDIEventListPointer(list, wordSize: (byteSize - eventListHeader) / 4, inProtocol: midiProtocol)
            return body(&p)
        }
        public func withUnsafePointer<Result>(_ body: (UnsafePointer<MIDIEventList>) -> Result) -> Result { body(UnsafePointer(list)) }
    }
}

extension UnsafePointer where Pointee == MIDIEventList {
    /// The event list's packets, as pointers.
    public func unsafeSequence() -> MIDIEventList.UnsafeSequence { MIDIEventList.UnsafeSequence(self) }
}
extension UnsafeMutablePointer where Pointee == MIDIEventList {
    public func unsafeSequence() -> MIDIEventList.UnsafeSequence { MIDIEventList.UnsafeSequence(UnsafePointer(self)) }
}

/// An event list in storage of a known number of words, to add packets to.
public struct UnsafeMutableMIDIEventListPointer: Sequence {
    public let UnsafeMutablePointer: Swift.UnsafeMutablePointer<MIDIEventList>
    let byteSize: Int
    /// Starts an empty list of a protocol.
    public init(_ pointer: Swift.UnsafeMutablePointer<MIDIEventList>, wordSize: Int, inProtocol: MIDIProtocolID) {
        UnsafeMutablePointer = pointer
        byteSize = eventListHeader + 4 * wordSize
        _ = MIDIEventListInit(pointer, inProtocol)
    }
    /// A list as it is (its protocol and packets).
    public init?(_ pointer: Swift.UnsafeMutablePointer<MIDIEventList>?, wordSize: Int) {
        guard let pointer else { return nil }
        UnsafeMutablePointer = pointer
        byteSize = eventListHeader + 4 * wordSize
    }
    public var midiProtocol: MIDIProtocolID { UnsafeMutablePointer.pointee.protocol }
    public var count: Int { Int(UnsafeMutablePointer.pointee.numPackets) }
    public var listSizeInBytes: Int { MIDIEventList.sizeInBytes(pktList: UnsafeMutablePointer) }
    public var lastPacket: Swift.UnsafeMutablePointer<MIDIEventPacket>? {
        var last: UnsafePointer<MIDIEventPacket>?
        for p in MIDIEventList.UnsafeSequence(UnsafeMutablePointer) { last = p }
        return last.map { Swift.UnsafeMutablePointer(mutating: $0) }
    }
    @discardableResult
    public func append(timestamp: MIDITimeStamp, words: [UInt32]) -> UnsafePointer<MIDIEventPacket>? {
        let current = lastPacket ?? MIDIEventListInit(UnsafeMutablePointer, midiProtocol)
        return MIDIEventListAdd(UnsafeMutablePointer, byteSize, current, timestamp, words.count, words).map { UnsafePointer($0) }
    }
    public func clear() { _ = MIDIEventListInit(UnsafeMutablePointer, midiProtocol) }
    public func makeIterator() -> AnyIterator<UnsafeMutableMIDIEventPacketPointer> {
        let it = MIDIEventList.UnsafeSequence(UnsafeMutablePointer).makeIterator()
        return AnyIterator { it.next().map { UnsafeMutableMIDIEventPacketPointer(Swift.UnsafeMutablePointer(mutating: $0)) } }
    }
}
