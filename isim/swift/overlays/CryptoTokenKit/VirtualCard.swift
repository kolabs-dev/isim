// isim CryptoTokenKit: the virtual card readers (adapted). There is no card reader hardware: the readers are listed in
// the device data ($ISIM_DATA/Library/isim/SmartCards/readers.json, written by `isim smartcard insert|remove`), each
// with the card it holds, if any:
//
//   {"readers": [{"name": "isim Virtual Reader", "pinPad": true,
//                 "card": {"atr": "3B…", "serial": "…", "token": "com.example.driver", "pinTries": 3,
//                          "applets": [{"aid": "A000000308…", "fci": "…", "pin": "123456", "pinReference": 128,
//                                       "files": {"3F00": "…"}, "objects": {"5FC102": "…"}, "protected": ["5FC105"],
//                                       "keys": {"9A": "04…"}}],
//                          "responses": {"00CA9F7F00": "…9000"}}}]}
//
// A card answers ISO 7816-4 commands: SELECT (an applet by AID, or a file of it), READ BINARY, GET DATA (also PIV's
// GET DATA with a 5C tag list), VERIFY (a retry counter; `protected` objects need it), CHANGE REFERENCE DATA (old ‖ new
// PIN), GET RESPONSE for answers longer than Le (61xx), command chaining; `responses` answers exact command APDUs
// first. Its security state (selected applet, verified PIN) resets at the end of each session; the retry counter and a
// changed PIN last until the card is removed. PIV's GENERAL AUTHENTICATE (issue #743) uses an applet's `keys` (by key
// reference; EC private keys in Apple's X9.63 form, 04 ‖ X ‖ Y ‖ D) once the PIN is verified: a challenge (81) is signed
// (ECDSA over the challenge as the digest, DER), an exponentiation (85, the other party's point) gives the ECDH secret.
import Foundation
import Security

func _unhex(_ s: String) -> [UInt8]? {
    let c = Array(s.utf8.filter { $0 != 32 })
    guard c.count % 2 == 0 else { return nil }
    var out = [UInt8](); out.reserveCapacity(c.count / 2)
    func v(_ x: UInt8) -> UInt8? {
        switch x { case 48...57: return x - 48; case 65...70: return x - 55; case 97...102: return x - 87; default: return nil }
    }
    var i = 0
    while i < c.count { guard let h = v(c[i]), let l = v(c[i + 1]) else { return nil }; out.append(h << 4 | l); i += 2 }
    return out
}
func _hex<S: Sequence>(_ s: S) -> String where S.Element == UInt8 { s.map { String(format: "%02X", $0) }.joined() }

/// what a slot's card talks to: a virtual card of readers.json, or a host PC/SC card (issue #745)
protocol _TKCardBackend: AnyObject, Sendable {
    var atr: [UInt8] { get }
    /// the token driver readers.json names (virtual cards only), and the serial number tokens are named by
    var token: String? { get }
    var serial: String { get }
    /// starts a session (T=0 bit 0, T=1 bit 1 as allowed); the protocol in use, nil: decided by the ATR (virtual cards)
    func beginSession(protocols: Int) -> Bool
    var activeProtocol: Int? { get }
    /// one command APDU's response (data, SW1, SW2); nil when the card cannot be reached
    func exchange(_ apdu: [UInt8]) -> [UInt8]?
    func endSession()
}
extension _TKCardBackend {
    /// whether the card has an applet of this AID (SELECT answers 9000 or 61xx): how a token driver is found for a card
    /// that names none
    func selects(_ aid: [UInt8]) -> Bool {
        guard !aid.isEmpty, aid.count < 256, beginSession(protocols: 3) else { return false }
        defer { endSession() }
        guard let r = exchange([0x00, 0xA4, 0x04, 0x00, UInt8(aid.count)] + aid + [0x00]), r.count >= 2 else { return false }
        return r[r.count - 2] == 0x90 && r[r.count - 1] == 0x00 || r[r.count - 2] == 0x61
    }
}

final class _TKVirtualCard: _TKCardBackend, @unchecked Sendable {
    struct Applet {
        var aid: [UInt8], fci: [UInt8]
        var files: [String: [UInt8]], objects: [String: [UInt8]], protected: Set<String>
        var pin: [UInt8]?, pinReference: UInt8
        var keys: [String: [UInt8]] = [:]
    }
    let atr: [UInt8]
    var applets: [Applet]
    let responses: [String: [UInt8]]
    let token: String?, serial: String
    let maxTries: Int
    var triesLeft: Int
    // the session state
    var selected: Int?, file: [UInt8]?, verified = false
    var chained: [UInt8] = [], rest: [UInt8] = []

    init?(_ j: [String: Any]) {
        guard let atr = _unhex(j["atr"] as? String ?? ""), atr.count >= 2 else { return nil }
        self.atr = atr
        applets = (j["applets"] as? [[String: Any]] ?? []).compactMap { a in
            guard let aid = _unhex(a["aid"] as? String ?? ""), !aid.isEmpty else { return nil }
            func hexMap(_ k: String) -> [String: [UInt8]] {
                var m: [String: [UInt8]] = [:]
                for (key, v) in a[k] as? [String: String] ?? [:] { if let b = _unhex(v) { m[key.uppercased()] = b } }
                return m
            }
            return Applet(aid: aid, fci: _unhex(a["fci"] as? String ?? "") ?? [], files: hexMap("files"), objects: hexMap("objects"),
                          protected: Set((a["protected"] as? [String] ?? []).map { $0.uppercased() }),
                          pin: (a["pin"] as? String).map { Array($0.utf8) }, pinReference: UInt8(truncatingIfNeeded: (a["pinReference"] as? Int) ?? 0x80),
                          keys: hexMap("keys"))
        }
        var r: [String: [UInt8]] = [:]
        for (k, v) in j["responses"] as? [String: String] ?? [:] {
            if let b = _unhex(v), b.count >= 2 { r[k.uppercased().replacingOccurrences(of: " ", with: "")] = b }
        }
        responses = r
        token = j["token"] as? String
        serial = j["serial"] as? String ?? String(_hex(atr).suffix(8))
        maxTries = max(1, (j["pinTries"] as? Int) ?? 3)
        triesLeft = maxTries
    }
    func endSession() { selected = nil; file = nil; verified = false; chained = []; rest = [] }
    func beginSession(protocols: Int) -> Bool { true }
    var activeProtocol: Int? { nil }
    func exchange(_ apdu: [UInt8]) -> [UInt8]? { respond(apdu) }

    static let ok: [UInt8] = [0x90, 0x00]
    private func tries() -> [UInt8] { triesLeft == 0 ? [0x69, 0x83] : [0x63, 0xC0 | UInt8(min(triesLeft, 15))] }

    /// the response (data, SW1, SW2) to one command APDU
    func respond(_ apdu: [UInt8]) -> [UInt8] {
        if let r = responses[_hex(apdu)] { return r }
        guard apdu.count >= 4 else { return [0x67, 0x00] }
        let cla = apdu[0], ins = apdu[1], p1 = apdu[2], p2 = apdu[3]
        guard cla & 0x80 == 0 else { return [0x6E, 0x00] }
        guard let (cmdData, le) = Self.parse(Array(apdu.dropFirst(4))) else { return [0x67, 0x00] }
        if cla & 0x10 != 0 { chained += cmdData; return Self.ok }    // command chaining: more data follows
        let data = chained + cmdData
        chained = []
        switch ins {
        case 0xA4:                                                     // SELECT
            if p1 == 0x04 {
                guard data.count >= 5, let i = applets.firstIndex(where: { Array($0.aid.prefix(data.count)) == data }) else { return [0x6A, 0x82] }
                selected = i; file = nil; verified = false
                return chunk(applets[i].fci, le: le)
            }
            guard let i = selected, let f = applets[i].files[_hex(data)] else { return [0x6A, 0x82] }
            file = f
            return Self.ok
        case 0xB0:                                                     // READ BINARY
            guard let f = file else { return [0x69, 0x86] }
            let off = Int(p1 & 0x7F) << 8 | Int(p2)
            guard off <= f.count else { return [0x6B, 0x00] }
            let want = le == 0 ? 256 : le, n = min(want, f.count - off)
            return Array(f[off..<(off + n)]) + (n < want ? [0x62, 0x82] : Self.ok)
        case 0xCA, 0xCB:                                               // GET DATA (PIV: 3FFF and a 5C tag list)
            guard let i = selected else { return [0x69, 0x85] }
            var key = String(format: "%02X%02X", p1, p2)
            if ins == 0xCB, data.count >= 2, data[0] == 0x5C { key = _hex(data.dropFirst(2).prefix(Int(data[1]))) }
            guard let obj = applets[i].objects[key] else { return [0x6A, 0x82] }
            if applets[i].protected.contains(key) && !verified { return [0x69, 0x82] }
            return chunk(obj, le: le)
        case 0xC0:                                                     // GET RESPONSE
            guard !rest.isEmpty else { return [0x69, 0x85] }
            return chunk(rest, le: le)
        case 0x20:                                                     // VERIFY
            guard let i = selected, applets[i].pin != nil, p2 == applets[i].pinReference else { return [0x6A, 0x88] }
            if p1 == 0xFF { verified = false; return Self.ok }           // reset the security status
            if triesLeft == 0 { return [0x69, 0x83] }
            if data.isEmpty { return verified ? Self.ok : tries() }
            if Array(data.prefix { $0 != 0xFF }) == applets[i].pin! { triesLeft = maxTries; verified = true; return Self.ok }
            triesLeft -= 1; verified = false
            return tries()
        case 0x24:                                                     // CHANGE REFERENCE DATA: old ‖ new PIN, equal halves
            guard let i = selected, applets[i].pin != nil, p2 == applets[i].pinReference else { return [0x6A, 0x88] }
            guard data.count >= 2, data.count % 2 == 0 else { return [0x6A, 0x80] }
            if triesLeft == 0 { return [0x69, 0x83] }
            let old = Array(data.prefix(data.count / 2).prefix { $0 != 0xFF }), new = Array(data.suffix(data.count / 2).prefix { $0 != 0xFF })
            guard old == applets[i].pin! else { triesLeft -= 1; verified = false; return tries() }
            applets[i].pin = new
            triesLeft = maxTries; verified = true
            return Self.ok
        case 0x87:                                                     // GENERAL AUTHENTICATE (PIV): sign or ECDH
            guard let i = selected else { return [0x69, 0x85] }
            guard let key = applets[i].keys[String(format: "%02X", p2)] else { return [0x6A, 0x88] }
            if applets[i].pin != nil && !verified { return [0x69, 0x82] }
            guard let t = Self.tlv(data)["7C"], let fields = Optional(Self.tlv(t)) else { return [0x6A, 0x80] }
            let attrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass as String: kSecAttrKeyClassPrivate]
            guard [0x11, 0x14].contains(p1), let priv = SecKeyCreateWithData(Data(key) as CFData, attrs as CFDictionary, nil) else { return [0x6A, 0x86] }
            var out: Data?
            if let challenge = fields["81"] {
                out = SecKeyCreateSignature(priv, .ecdsaSignatureDigestX962, Data(challenge) as CFData, nil) as Data?
            } else if let point = fields["85"] {
                let pubAttrs: [String: Any] = [kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom, kSecAttrKeyClass as String: kSecAttrKeyClassPublic]
                if let pub = SecKeyCreateWithData(Data(point) as CFData, pubAttrs as CFDictionary, nil) {
                    out = SecKeyCopyKeyExchangeResult(priv, .ecdhKeyExchangeStandard, pub, [:] as CFDictionary, nil) as Data?
                }
            }
            guard let out else { return [0x6A, 0x80] }
            return chunk(Self.encode(0x7C, Self.encode(0x82, Array(out))), le: le)
        default:
            return [0x6D, 0x00]
        }
    }
    /// BER-TLV objects with one-byte tags (as hex) and their values
    static func tlv(_ d: [UInt8]) -> [String: [UInt8]] {
        var out: [String: [UInt8]] = [:], i = 0
        while i + 1 < d.count {
            let tag = d[i]; var n = Int(d[i + 1]); i += 2
            if n == 0x81, i < d.count { n = Int(d[i]); i += 1 }
            else if n == 0x82, i + 1 < d.count { n = Int(d[i]) << 8 | Int(d[i + 1]); i += 2 }
            guard i + n <= d.count else { break }
            out[String(format: "%02X", tag)] = Array(d[i..<(i + n)]); i += n
        }
        return out
    }
    static func encode(_ tag: UInt8, _ v: [UInt8]) -> [UInt8] {
        let len: [UInt8] = v.count < 0x80 ? [UInt8(v.count)] : v.count < 0x100 ? [0x81, UInt8(v.count)] : [0x82, UInt8(v.count >> 8), UInt8(v.count & 0xFF)]
        return [tag] + len + v
    }
    /// Lc data and Le (0: the maximum) of an APDU body, short or extended
    static func parse(_ b: [UInt8]) -> ([UInt8], Int)? {
        if b.isEmpty { return ([], -1) }
        if b.count == 1 { return ([], Int(b[0])) }
        if b[0] == 0, b.count >= 3 {                                   // extended
            let n = Int(b[1]) << 8 | Int(b[2])
            if b.count == 3 { return ([], n) }
            guard b.count == 3 + n || b.count == 5 + n else { return nil }
            let le = b.count == 5 + n ? Int(b[3 + n]) << 8 | Int(b[4 + n]) : -1
            return (Array(b[3..<(3 + n)]), le)
        }
        let n = Int(b[0])
        guard b.count == 1 + n || b.count == 2 + n else { return nil }
        return (Array(b[1..<(1 + n)]), b.count == 2 + n ? Int(b[1 + n]) : -1)
    }
    /// an answer within Le (at most 256 bytes); the rest comes with 61xx GET RESPONSE
    func chunk(_ d: [UInt8], le: Int) -> [UInt8] {
        let n = le <= 0 ? 256 : min(le, 256)
        if d.count <= n { rest = []; return d + Self.ok }
        rest = Array(d.dropFirst(n))
        return Array(d.prefix(n)) + [0x61, rest.count >= 256 ? 0 : UInt8(rest.count)]
    }
}

@_silgen_name("isim_pcsc_readers") private func isim_pcsc_readers() -> UnsafeMutablePointer<CChar>?
@_silgen_name("isim_pcsc_begin") private func isim_pcsc_begin(_ reader: UnsafePointer<CChar>, _ protocols: Int32, _ proto: UnsafeMutablePointer<Int32>?) -> Int64
@_silgen_name("isim_pcsc_transmit") private func isim_pcsc_transmit(_ h: Int64, _ proto: Int32, _ apdu: UnsafePointer<UInt8>, _ len: Int32, _ out: UnsafeMutablePointer<UInt8>, _ cap: Int32) -> Int32
@_silgen_name("isim_pcsc_end") private func isim_pcsc_end(_ h: Int64, _ reset: Int32)
@_silgen_name("isim_media_free") private func _tk_host_free(_ p: UnsafeMutableRawPointer?)

/// a card in one of the host's PC/SC readers (passthrough to pcsclite, issue #745): each session is SCardConnect and a
/// transaction, each APDU one SCardTransmit
final class _TKPCSCCard: _TKCardBackend, @unchecked Sendable {
    let reader: String, atr: [UInt8]
    private var handle: Int64 = 0, proto: Int32 = 0
    init(reader: String, atr: [UInt8]) { self.reader = reader; self.atr = atr }
    var token: String? { nil }
    var serial: String { String(_hex(atr).suffix(8)) }
    func beginSession(protocols: Int) -> Bool {
        if handle != 0 { return true }
        handle = isim_pcsc_begin(reader, Int32(protocols), &proto)
        return handle != 0
    }
    var activeProtocol: Int? { handle != 0 ? Int(proto) : nil }
    func exchange(_ apdu: [UInt8]) -> [UInt8]? {
        guard handle != 0 else { return nil }
        var out = [UInt8](repeating: 0, count: 65538)
        let n = apdu.withUnsafeBufferPointer { a in isim_pcsc_transmit(handle, proto, a.baseAddress!, Int32(a.count), &out, Int32(out.count)) }
        return n < 2 ? nil : Array(out.prefix(Int(n)))
    }
    func endSession() {
        guard handle != 0 else { return }
        isim_pcsc_end(handle, 0)
        handle = 0
    }
    deinit { endSession() }
}

/// the readers of readers.json, re-read when the file changes (inserting or removing a card), and with ISIM_PCSC=1 the
/// host's PC/SC readers after them (a virtual reader's name wins)
final class _TKReaders: @unchecked Sendable {
    static let shared = _TKReaders()
    struct Reader { var name: String; var pinPad: Bool; var cardKey: String?; var card: [String: Any]?; var pcscATR: [UInt8]? = nil; var pcsc = false }
    private let lock = NSLock()
    private(set) var readers: [Reader] = []
    private var cards: [String: any _TKCardBackend] = [:]   // reader name -> the inserted card's state
    private var stamp = ""
    private var timer: DispatchSourceTimer?
    private var observers: [UUID: () -> Void] = [:]

    var path: String {
        let env = ProcessInfo.processInfo.environment["ISIM_DATA"] ?? ""
        let dir = env.isEmpty ? NSHomeDirectory() + "/.local/share/isim" : env
        return dir + "/Library/isim/SmartCards/readers.json"
    }
    private init() { reload() }

    /// re-reads the file when it changed; returns whether it did
    @discardableResult func reload() -> Bool {
        let attrs = try? FileManager.default.attributesOfItem(atPath: path)
        let pcsc = Self.pcscList()
        let s = "\((attrs?[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0) \((attrs?[.size] as? NSNumber)?.intValue ?? -1)\n" + (pcsc ?? "")
        lock.lock(); defer { lock.unlock() }
        if s == stamp { return false }
        stamp = s
        var list: [Reader] = []
        if let d = FileManager.default.contents(atPath: path), let j = (try? JSONSerialization.jsonObject(with: d)) as? [String: Any] {
            for r in j["readers"] as? [[String: Any]] ?? [] {
                guard let name = r["name"] as? String else { continue }
                let card = r["card"] as? [String: Any]
                let key = card.flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.sortedKeys]) }.map { String(decoding: $0, as: UTF8.self) }
                list.append(Reader(name: name, pinPad: r["pinPad"] as? Bool ?? false, cardKey: key, card: card))
            }
        }
        for line in (pcsc ?? "").split(separator: "\n") {
            let f = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 4, !f[0].isEmpty, !list.contains(where: { $0.name == f[0] }) else { continue }
            let atr = f[1] == "present" ? _unhex(f[2]).flatMap { $0.count >= 2 ? $0 : nil } : nil
            let key: String? = f[1] == "empty" ? nil : "pcsc:\(f[3]):\(f[1]):\(f[2])"     // the event count: a card put back
            list.append(Reader(name: f[0], pinPad: false, cardKey: key, card: nil, pcscATR: atr, pcsc: true))
        }
        for r in list {
            if r.cardKey == nil { cards[r.name] = nil; continue }
            if let old = readers.first(where: { $0.name == r.name }), old.cardKey == r.cardKey, cards[r.name] != nil { continue }
            if r.pcsc { cards[r.name] = r.pcscATR.map { _TKPCSCCard(reader: r.name, atr: $0) }; continue }
            cards[r.name] = r.card.flatMap(_TKVirtualCard.init)
        }
        for name in cards.keys where !list.contains(where: { $0.name == name }) { cards[name] = nil }
        readers = list
        return true
    }
    func reader(_ name: String) -> Reader? { lock.lock(); defer { lock.unlock() }; return readers.first { $0.name == name } }
    /// the host's PC/SC readers (lines: name, state, ATR, event count), nil without ISIM_PCSC=1 or PC/SC
    static func pcscList() -> String? {
        guard let p = isim_pcsc_readers() else { return nil }
        defer { _tk_host_free(p) }
        return String(cString: p)
    }
    func card(_ name: String) -> (any _TKCardBackend)? { lock.lock(); defer { lock.unlock() }; return cards[name] }
    var names: [String] { lock.lock(); defer { lock.unlock() }; return readers.map(\.name) }

    /// calls `changed` on the main queue whenever the readers change (polled: the file is written by `isim smartcard`)
    func observe(_ changed: @escaping () -> Void) -> UUID {
        let id = UUID()
        lock.lock()
        observers[id] = changed
        if timer == nil {
            let t = DispatchSource.makeTimerSource(queue: .main)
            t.schedule(deadline: .now() + 0.25, repeating: 0.25)
            t.setEventHandler { [weak self] in
                guard let self, self.reload() else { return }
                self.lock.lock(); let all = Array(self.observers.values); self.lock.unlock()
                for o in all { o() }
            }
            timer = t
            t.resume()
        }
        lock.unlock()
        return id
    }
    func stopObserving(_ id: UUID) { lock.lock(); observers[id] = nil; lock.unlock() }
}
