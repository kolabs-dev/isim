// isim CryptoTokenKit: TLV records (BER-TLV per ISO 8825-1, COMPACT-TLV and SIMPLE-TLV per ISO 7816-4), as Apple's
// TKTLVRecord classes.
import Foundation

public typealias TKTLVTag = UInt64

@objc(TKTLVRecord) open class TKTLVRecord: NSObject, @unchecked Sendable {
    @objc public let tag: TKTLVTag
    @objc public let value: Data
    @objc public let data: Data
    init(tag: TKTLVTag, value: Data, data: Data) { self.tag = tag; self.value = value; self.data = data; super.init() }

    /// one record at `offset` (nil: malformed), and the offset after it; each subclass reads its own format
    class func _parse(_ b: [UInt8], _ offset: Int) -> (TKTLVRecord, Int)? { nil }

    /// the records of `data` in sequence (nil if any is malformed)
    @objc(sequenceOfRecordsFromData:) open class func sequenceOfRecords(from data: Data) -> [TKTLVRecord]? {
        let b = [UInt8](data)
        var out: [TKTLVRecord] = [], i = 0
        while i < b.count {
            guard let (r, next) = _parse(b, i) else { return nil }
            out.append(r); i = next
        }
        return out
    }
    /// a single record that is all of `data`
    @objc(recordFromData:) open class func _record(from data: Data) -> Self? {
        let b = [UInt8](data)
        guard let (r, next) = _parse(b, 0), next == b.count else { return nil }
        return r as? Self
    }
    open override var description: String { String(format: "<%@ tag 0x%llX, %d bytes>", NSStringFromClass(type(of: self)), tag, value.count) }
}
extension TKTLVRecord {
    public convenience init?(from data: Data) {
        guard let r = type(of: self)._record(from: data) else { return nil }
        self.init(tag: r.tag, value: r.value, data: r.data)
    }
}

@objc(TKBERTLVRecord) open class TKBERTLVRecord: TKTLVRecord, @unchecked Sendable {
    /// the tag's bytes: as many as its value needs, the first one's low bits 11111 when it is longer than one byte
    @objc(dataForTag:) open class func data(forTag tag: TKTLVTag) -> Data {
        var t = tag, out: [UInt8] = []
        repeat { out.insert(UInt8(t & 0xFF), at: 0); t >>= 8 } while t != 0
        return Data(out)
    }
    static func length(_ n: Int) -> [UInt8] {
        if n < 0x80 { return [UInt8(n)] }
        var v = n, out: [UInt8] = []
        while v > 0 { out.insert(UInt8(v & 0xFF), at: 0); v >>= 8 }
        return [0x80 | UInt8(out.count)] + out
    }
    @objc(initWithTag:value:) public init(tag: TKTLVTag, value: Data) {
        let enc = [UInt8](TKBERTLVRecord.data(forTag: tag)) + TKBERTLVRecord.length(value.count) + [UInt8](value)
        super.init(tag: tag, value: value, data: Data(enc))
    }
    @objc(initWithTag:records:) public convenience init(tag: TKTLVTag, records: [TKTLVRecord]) {
        self.init(tag: tag, value: records.reduce(Data()) { $0 + $1.data })
    }
    override init(tag: TKTLVTag, value: Data, data: Data) { super.init(tag: tag, value: value, data: data) }
    override class func _parse(_ b: [UInt8], _ start: Int) -> (TKTLVRecord, Int)? {
        var i = start
        guard i < b.count else { return nil }
        var tag = TKTLVTag(b[i]); i += 1
        if b[i - 1] & 0x1F == 0x1F {                                    // more tag bytes, each but the last with bit 8 set
            repeat {
                guard i < b.count, tag >> 56 == 0 else { return nil }
                tag = tag << 8 | TKTLVTag(b[i]); i += 1
            } while b[i - 1] & 0x80 != 0
        }
        guard i < b.count else { return nil }
        var len = Int(b[i]); i += 1
        if len == 0x80 { return nil }                                   // indefinite length: not in ISO 7816
        if len > 0x80 {
            let n = len & 0x7F
            guard n <= 4, i + n <= b.count else { return nil }
            len = 0
            for _ in 0..<n { len = len << 8 | Int(b[i]); i += 1 }
        }
        guard i + len <= b.count else { return nil }
        return (TKBERTLVRecord(tag: tag, value: Data(b[i..<(i + len)]), data: Data(b[start..<(i + len)])), i + len)
    }
}

@objc(TKCompactTLVRecord) open class TKCompactTLVRecord: TKTLVRecord, @unchecked Sendable {
    @objc(initWithTag:value:) public init(tag: UInt8, value: Data) {
        precondition(tag <= 0x0F && value.count <= 0x0F, "a COMPACT-TLV record has a 4-bit tag and at most 15 bytes")
        super.init(tag: TKTLVTag(tag), value: value, data: Data([tag << 4 | UInt8(value.count)]) + value)
    }
    override init(tag: TKTLVTag, value: Data, data: Data) { super.init(tag: tag, value: value, data: data) }
    override class func _parse(_ b: [UInt8], _ start: Int) -> (TKTLVRecord, Int)? {
        guard start < b.count else { return nil }
        let tag = b[start] >> 4, len = Int(b[start] & 0x0F)
        guard start + 1 + len <= b.count else { return nil }
        return (TKCompactTLVRecord(tag: TKTLVTag(tag), value: Data(b[(start + 1)..<(start + 1 + len)]), data: Data(b[start..<(start + 1 + len)])), start + 1 + len)
    }
}

@objc(TKSimpleTLVRecord) open class TKSimpleTLVRecord: TKTLVRecord, @unchecked Sendable {
    @objc(initWithTag:value:) public init(tag: UInt8, value: Data) {
        let len: [UInt8] = value.count < 0xFF ? [UInt8(value.count)] : [0xFF, UInt8(value.count >> 8), UInt8(value.count & 0xFF)]
        super.init(tag: TKTLVTag(tag), value: value, data: Data([tag] + len) + value)
    }
    override init(tag: TKTLVTag, value: Data, data: Data) { super.init(tag: tag, value: value, data: data) }
    override class func _parse(_ b: [UInt8], _ start: Int) -> (TKTLVRecord, Int)? {
        guard start + 1 < b.count, b[start] != 0x00, b[start] != 0xFF else { return nil }
        var i = start + 1, len = Int(b[i]); i += 1
        if len == 0xFF { guard i + 2 <= b.count else { return nil }; len = Int(b[i]) << 8 | Int(b[i + 1]); i += 2 }
        guard i + len <= b.count else { return nil }
        return (TKSimpleTLVRecord(tag: TKTLVTag(b[start]), value: Data(b[i..<(i + len)]), data: Data(b[start..<(i + len)])), i + len)
    }
}
