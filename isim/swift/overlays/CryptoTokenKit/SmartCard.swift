// isim CryptoTokenKit: smart cards (adapted, over isim's virtual card readers: VirtualCard.swift). Same classes, names
// and selectors as Apple's CryptoTokenKit; the Objective-C interface is sdk-src/Frameworks/CryptoTokenKit. Like on iOS,
// the app needs the com.apple.security.smartcard entitlement, else TKSmartCardSlotManager.default is nil. Slots
// follow cards being inserted and removed (`isim smartcard insert|remove`): state, atr (KVO) and the manager's
// slotNames. NFC slots (createNFCSlot) are not supported: isNFCSupported() is false.
import Foundation

// MARK: - errors

public let TKErrorDomain = "CryptoTokenKit"

public struct TKError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case notImplemented = -1
        case communicationError = -2
        case corruptedData = -3
        case canceledByUser = -4
        case authenticationFailed = -5
        case objectNotFound = -6
        case tokenNotFound = -7
        case badParameter = -8
        case authenticationNeeded = -9
        case invalidatedDeviceKey = -10
        @available(*, deprecated, renamed: "authenticationFailed") public static let TKErrorAuthenticationFailed = Code.authenticationFailed
        @available(*, deprecated, renamed: "objectNotFound") public static let TKErrorObjectNotFound = Code.objectNotFound
        @available(*, deprecated, renamed: "tokenNotFound") public static let TKErrorTokenNotFound = Code.tokenNotFound
    }
    public let code: Code
    let message: String
    public init(_ code: Code, userInfo: [String: Any] = [:]) {
        self.code = code
        message = userInfo[NSLocalizedDescriptionKey] as? String ?? TKError.defaultMessage(code)
    }
    public static var errorDomain: String { TKErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: message] }
    public var errorDescription: String? { message }
    public var localizedDescription: String { message }
    public static func == (a: TKError, b: TKError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    public static var notImplemented: Code { .notImplemented }
    public static var communicationError: Code { .communicationError }
    public static var corruptedData: Code { .corruptedData }
    public static var canceledByUser: Code { .canceledByUser }
    public static var authenticationFailed: Code { .authenticationFailed }
    public static var objectNotFound: Code { .objectNotFound }
    public static var tokenNotFound: Code { .tokenNotFound }
    public static var badParameter: Code { .badParameter }
    public static var authenticationNeeded: Code { .authenticationNeeded }
    public static var invalidatedDeviceKey: Code { .invalidatedDeviceKey }
    @available(*, deprecated, renamed: "authenticationFailed") public static var TKErrorAuthenticationFailed: Code { .authenticationFailed }
    @available(*, deprecated, renamed: "objectNotFound") public static var TKErrorObjectNotFound: Code { .objectNotFound }
    @available(*, deprecated, renamed: "tokenNotFound") public static var TKErrorTokenNotFound: Code { .tokenNotFound }

    static func defaultMessage(_ c: Code) -> String {
        switch c {
        case .notImplemented: return "The operation is not implemented."
        case .communicationError: return "Communication with the smart card failed."
        case .corruptedData: return "The data from the smart card is corrupted."
        case .canceledByUser: return "The operation was canceled by the user."
        case .authenticationFailed: return "Authentication failed."
        case .objectNotFound: return "The object was not found."
        case .tokenNotFound: return "The token was not found."
        case .badParameter: return "A parameter is not valid."
        case .authenticationNeeded: return "Authentication is needed."
        case .invalidatedDeviceKey: return "The device key was invalidated."
        }
    }
}
extension TKError.Code {
    public static func ~= (code: TKError.Code, error: any Error) -> Bool {
        let e = error as NSError
        return e.domain == TKErrorDomain && e.code == code.rawValue
    }
}
func _tkError(_ c: TKError.Code, _ message: String? = nil) -> NSError {
    TKError(c, userInfo: message.map { [NSLocalizedDescriptionKey: $0] } ?? [:]) as NSError
}

/// the app's entitlements (com.apple.security.smartcard)
let _tkEntitled: Bool = {
    let path = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
    let ent = NSDictionary(contentsOfFile: path)
    return (ent?["com.apple.security.smartcard"] as? Bool) == true
}()

// MARK: - protocols

public struct TKSmartCardProtocol: OptionSet, Hashable, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static var t0: TKSmartCardProtocol { TKSmartCardProtocol(rawValue: 1 << 0) }
    public static var t1: TKSmartCardProtocol { TKSmartCardProtocol(rawValue: 1 << 1) }
    public static var t15: TKSmartCardProtocol { TKSmartCardProtocol(rawValue: 1 << 15) }
    public static var any: TKSmartCardProtocol { TKSmartCardProtocol(rawValue: (1 << 16) - 1) }
}

// MARK: - slot manager

@objc(TKSmartCardSlotManager) open class TKSmartCardSlotManager: NSObject, @unchecked Sendable {
    nonisolated(unsafe) private static var shared: TKSmartCardSlotManager?
    private var watch: UUID?
    private var names: [String]
    private var slots: [String: TKSmartCardSlot] = [:]

    @objc(defaultManager) open class var `default`: TKSmartCardSlotManager? {
        guard _tkEntitled else {
            NSLog("isim CryptoTokenKit: the app lacks the com.apple.security.smartcard entitlement: no slot manager")
            return nil
        }
        if let s = shared { return s }
        let s = TKSmartCardSlotManager(manager: ())
        shared = s
        return s
    }
    private init(manager: Void) {
        names = _TKReaders.shared.names
        super.init()
        watch = _TKReaders.shared.observe { [weak self] in self?.readersChanged() }
    }
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { key == "slotNames" ? false : super.automaticallyNotifiesObservers(forKey: key) }
    private func readersChanged() {
        let now = _TKReaders.shared.names
        if now != names { willChangeValue(forKey: "slotNames"); names = now; didChangeValue(forKey: "slotNames") }
        for (_, slot) in slots { slot.update() }
    }

    @objc open dynamic var slotNames: [String] { names }
    @objc(getSlotWithName:reply:) open func getSlot(withName name: String, reply: @escaping @Sendable (TKSmartCardSlot?) -> Void) {
        let s = slotNamed(name)
        DispatchQueue.global().async { reply(s) }
    }
    @objc(slotNamed:) open func slotNamed(_ name: String) -> TKSmartCardSlot? {
        guard names.contains(name) else { return nil }
        if let s = slots[name] { return s }
        let s = TKSmartCardSlot(name: name)
        slots[name] = s
        return s
    }
    @objc open func isNFCSupported() -> Bool { false }
    @objc(createNFCSlotWithMessage:completion:) open func createNFCSlot(message: String?, completion: @escaping @Sendable (TKSmartCardSlotNFCSession?, (any Error)?) -> Void) {
        DispatchQueue.global().async { completion(nil, _tkError(.notImplemented, "NFC smart card slots are not supported in isim")) }
    }
}

@objc(TKSmartCardSlotNFCSession) open class TKSmartCardSlotNFCSession: NSObject, @unchecked Sendable {
    @objc open var slotName: String? { nil }
    @objc(updateWithMessage:error:) open func update(message: String) throws { throw _tkError(.notImplemented) }
    @objc open func end() {}
}

// MARK: - slot

@objc(TKSmartCardSlot) open class TKSmartCardSlot: NSObject, @unchecked Sendable {
    @objc(TKSmartCardSlotState) public enum State: Int, Sendable {
        case missing = 0, empty = 1, probing = 2, muteCard = 3, validCard = 4
    }
    @objc public let name: String
    private var _state: State = .missing
    private var _atr: TKSmartCardATR?
    weak var current: TKSmartCard?
    let sessionLock = NSCondition()
    var sessionOwner: ObjectIdentifier?

    init(name: String) {
        self.name = name
        super.init()
        update(notify: false)
    }
    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool {
        key == "state" || key == "ATR" || key == "atr" ? false : super.automaticallyNotifiesObservers(forKey: key)
    }
    func update(notify: Bool = true) {
        let r = _TKReaders.shared.reader(name)
        let card = _TKReaders.shared.card(name)
        let state: State = r == nil ? .missing : r?.cardKey == nil ? .empty : card == nil ? .muteCard : .validCard
        let atr = card.flatMap { TKSmartCardATR(bytes: Data($0.atr)) }
        guard state != _state || atr?.bytes != _atr?.bytes else { return }
        if state != .validCard || atr?.bytes != _atr?.bytes { current?.invalidate() }
        if notify { willChangeValue(forKey: "state"); willChangeValue(forKey: "ATR") }
        _state = state; _atr = atr
        if notify { didChangeValue(forKey: "ATR"); didChangeValue(forKey: "state") }
    }
    @objc open dynamic var state: State { _state }
    @objc(ATR) open dynamic var atr: TKSmartCardATR? { _atr }
    @objc open var maxInputLength: Int { 65544 }
    @objc open var maxOutputLength: Int { 65538 }
    var pinPad: Bool { _TKReaders.shared.reader(name)?.pinPad ?? false }

    @objc open func makeSmartCard() -> TKSmartCard? {
        guard _state == .validCard, let card = _TKReaders.shared.card(name) else { return nil }
        let c = TKSmartCard(slot: self, card: card)
        current = c
        return c
    }
}

// MARK: - smart card

@objc(TKSmartCard) open class TKSmartCard: NSObject, @unchecked Sendable {
    @objc public let slot: TKSmartCardSlot
    let card: _TKVirtualCard
    private var valid = true
    private var inSession = false
    @objc open var context: Any?
    open var allowedProtocols: TKSmartCardProtocol = .any
    private var sensitive = false
    @objc open var isSensitive: Bool {
        @objc(isSensitive) get { sensitive }
        @objc(setSensitive:) set { sensitive = newValue }
    }
    @objc open var cla: UInt8 = 0
    @objc open var useExtendedLength = true
    @objc open var useCommandChaining = true
    let queue = DispatchQueue(label: "isim.CryptoTokenKit.card")

    init(slot: TKSmartCardSlot, card: _TKVirtualCard) { self.slot = slot; self.card = card; super.init() }

    open override class func automaticallyNotifiesObservers(forKey key: String) -> Bool { key == "valid" ? false : super.automaticallyNotifiesObservers(forKey: key) }
    func invalidate() {
        guard valid else { return }
        willChangeValue(forKey: "valid"); valid = false; didChangeValue(forKey: "valid")
        if inSession { releaseSession() }
    }
    @objc open dynamic var isValid: Bool { valid }
    /// T=1 when the card offers it and it is allowed, else T=0; nothing outside a session
    open var currentProtocol: TKSmartCardProtocol {
        guard inSession else { return [] }
        let offered = slot.atr?.protocols.map(\.intValue) ?? [0]
        if offered.contains(1), allowedProtocols.contains(.t1) { return .t1 }
        return allowedProtocols.contains(.t0) ? .t0 : []
    }

    private func acquireSession(timeout: TimeInterval) -> Bool {
        let me = ObjectIdentifier(self), deadline = Date(timeIntervalSinceNow: timeout)
        slot.sessionLock.lock(); defer { slot.sessionLock.unlock() }
        while let owner = slot.sessionOwner, owner != me { if !slot.sessionLock.wait(until: deadline) { return false } }
        slot.sessionOwner = me
        return true
    }
    private func releaseSession() {
        slot.sessionLock.lock()
        if slot.sessionOwner == ObjectIdentifier(self) { slot.sessionOwner = nil }
        slot.sessionLock.broadcast()
        slot.sessionLock.unlock()
        inSession = false
        card.endSession()
    }

    @objc(beginSessionWithReply:) open func beginSession(reply: @escaping @Sendable (Bool, (any Error)?) -> Void) {
        queue.async {
            guard self.valid else { reply(false, _tkError(.communicationError, "the card was removed")); return }
            guard self.acquireSession(timeout: 10) else { reply(false, _tkError(.communicationError, "another session holds the card")); return }
            guard self.valid else { self.releaseSession(); reply(false, _tkError(.communicationError, "the card was removed")); return }
            self.inSession = true
            reply(true, nil)
        }
    }
    @objc open func endSession() {
        guard inSession else { return }
        releaseSession()
    }

    /// one APDU to the card (in a session); the response ends with SW1 SW2
    func exchange(_ apdu: [UInt8]) throws -> [UInt8] {
        guard valid else { throw _tkError(.communicationError, "the card was removed") }
        guard inSession else { throw _tkError(.communicationError, "no session with the card: call beginSession first") }
        guard apdu.count <= slot.maxInputLength else { throw _tkError(.badParameter, "the APDU is longer than the reader accepts") }
        if isSensitive { NSLog("isim CryptoTokenKit: %@: sensitive APDU (not logged)", slot.name) }
        return card.respond(apdu)
    }
    @objc(transmitRequest:reply:) open func transmit(_ request: Data, reply: @escaping @Sendable (Data?, (any Error)?) -> Void) {
        queue.async {
            do { reply(Data(try self.exchange([UInt8](request))), nil) } catch { reply(nil, error) }
        }
    }

    /// builds the APDU(s) of a command (Le nil: none; 0: the maximum), chaining or extended as set, and follows
    /// 61xx (GET RESPONSE) and 6Cxx (wrong Le)
    func command(ins: UInt8, p1: UInt8, p2: UInt8, data: [UInt8]?, le: Int?) throws -> (UInt16, [UInt8]) {
        let d = data ?? []
        func apdu(_ cla: UInt8, _ body: [UInt8], _ le: Int?) -> [UInt8] {
            let extended = useExtendedLength && (body.count > 255 || (le ?? 0) > 256)
            var a = [cla, ins, p1, p2]
            if !body.isEmpty { a += extended ? [0, UInt8(body.count >> 8), UInt8(body.count & 0xFF)] : [UInt8(body.count)]; a += body }
            if let le {
                if extended { a += body.isEmpty ? [0, UInt8((le >> 8) & 0xFF), UInt8(le & 0xFF)] : [UInt8((le >> 8) & 0xFF), UInt8(le & 0xFF)] }
                else { a += [UInt8(le & 0xFF)] }
            }
            return a
        }
        var resp: [UInt8]
        if d.count > 255 && !useExtendedLength {
            guard useCommandChaining else { throw _tkError(.badParameter, "the command data is longer than 255 bytes") }
            var chunks = stride(from: 0, to: d.count, by: 255).map { Array(d[$0..<min($0 + 255, d.count)]) }
            let last = chunks.removeLast()
            for c in chunks {
                let r = try exchange(apdu(cla | 0x10, c, nil))
                guard r.suffix(2) == [0x90, 0x00] else { return (UInt16(r[r.count - 2]) << 8 | UInt16(r[r.count - 1]), Array(r.dropLast(2))) }
            }
            resp = try exchange(apdu(cla, last, le))
        } else {
            resp = try exchange(apdu(cla, d, le))
        }
        guard resp.count >= 2 else { throw _tkError(.corruptedData, "the card's response has no status word") }
        if resp[resp.count - 2] == 0x6C, le != nil { resp = try exchange(apdu(cla, d, Int(resp[resp.count - 1]))) }
        var out = Array(resp.dropLast(2))
        var sw1 = resp[resp.count - 2], sw2 = resp[resp.count - 1]
        while sw1 == 0x61 {
            let r = try exchange([cla, 0xC0, 0, 0, sw2])
            guard r.count >= 2 else { throw _tkError(.corruptedData, "the card's response has no status word") }
            out += r.dropLast(2)
            sw1 = r[r.count - 2]; sw2 = r[r.count - 1]
        }
        return (UInt16(sw1) << 8 | UInt16(sw2), out)
    }
    @objc(sendIns:p1:p2:data:le:reply:) open func _send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data?, le: NSNumber?,
                                                        reply: @escaping @Sendable (Data?, UInt16, (any Error)?) -> Void) {
        queue.async {
            do {
                let (sw, r) = try self.command(ins: ins, p1: p1, p2: p2, data: data.map { [UInt8]($0) }, le: le.map { Int(truncating: $0) })
                reply(Data(r), sw, nil)
            } catch { reply(nil, 0, error) }
        }
    }
    @objc(sendIns:p1:p2:data:le:sw:error:) open func _sendSync(ins: UInt8, p1: UInt8, p2: UInt8, data: Data?, le: NSNumber?,
                                                              sw: UnsafeMutablePointer<UInt16>) throws -> Data {
        let (s, r) = try command(ins: ins, p1: p1, p2: p2, data: data.map { [UInt8]($0) }, le: le.map { Int(truncating: $0) })
        sw.pointee = s
        return Data(r)
    }
    @objc(inSessionWithError:executeBlock:) open func _inSession(executeBlock block: (NSErrorPointer) -> Bool) throws {
        try withSession {
            var e: NSError?
            if !block(&e) { throw e ?? _tkError(.communicationError) }
        }
    }

    // MARK: secure PIN entry (the reader's PIN pad: isim's PIN sheet)

    @objc(userInteractionForSecurePINVerificationWithPINFormat:APDU:PINByteOffset:)
    open func userInteractionForSecurePINVerification(_ pinFormat: TKSmartCardPINFormat, apdu: Data, pinByteOffset: Int) -> TKSmartCardUserInteractionForSecurePINVerification? {
        guard slot.pinPad else { return nil }
        return TKSmartCardUserInteractionForSecurePINVerification(card: self, format: pinFormat, apdu: [UInt8](apdu), offsets: [pinByteOffset])
    }
    @objc(userInteractionForSecurePINChangeWithPINFormat:APDU:currentPINByteOffset:newPINByteOffset:)
    open func userInteractionForSecurePINChange(_ pinFormat: TKSmartCardPINFormat, apdu: Data, currentPINByteOffset: Int,
                                                newPINByteOffset: Int) -> TKSmartCardUserInteractionForSecurePINChange? {
        guard slot.pinPad else { return nil }
        return TKSmartCardUserInteractionForSecurePINChange(card: self, format: pinFormat, apdu: [UInt8](apdu),
                                                            offsets: [currentPINByteOffset, newPINByteOffset])
    }
}

extension TKSmartCard {
    /// Runs body in a session with the card (synchronously).
    public func withSession<T>(_ body: () throws -> T) throws -> T {
        let done = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var failure: (any Error)?
        nonisolated(unsafe) var ok = false
        beginSession { success, error in ok = success; failure = error; done.signal() }
        done.wait()
        guard ok else { throw failure ?? _tkError(.communicationError) }
        defer { endSession() }
        return try body()
    }
    public func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data? = nil, le: Int? = nil,
                     reply: @escaping @Sendable (Data?, UInt16, (any Error)?) -> Void) {
        _send(ins: ins, p1: p1, p2: p2, data: data, le: le.map { NSNumber(value: $0) }, reply: reply)
    }
    public func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data? = nil, le: Int? = nil) throws -> (sw: UInt16, response: Data) {
        let (sw, r) = try command(ins: ins, p1: p1, p2: p2, data: data.map { [UInt8]($0) }, le: le)
        return (sw, Data(r))
    }
    public func send(ins: UInt8, p1: UInt8, p2: UInt8, data: Data? = nil, le: Int? = nil) async throws -> (sw: UInt16, response: Data) {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<(sw: UInt16, response: Data), any Error>) in
            send(ins: ins, p1: p1, p2: p2, data: data, le: le) { r, sw, error in
                if let error { c.resume(throwing: error) } else { c.resume(returning: (sw, r ?? Data())) }
            }
        }
    }
}

// MARK: - ATR (ISO 7816-3)

@objc(TKSmartCardATR) open class TKSmartCardATR: NSObject, @unchecked Sendable {
    @objc(TKSmartCardATRInterfaceGroup) open class InterfaceGroup: NSObject, @unchecked Sendable {
        @objc(TA) public let ta: NSNumber?
        @objc(TB) public let tb: NSNumber?
        @objc(TC) public let tc: NSNumber?
        @objc public let `protocol`: NSNumber?
        init(ta: NSNumber?, tb: NSNumber?, tc: NSNumber?, protocol p: NSNumber?) { self.ta = ta; self.tb = tb; self.tc = tc; self.protocol = p }
    }
    @objc public let bytes: Data
    @objc public let protocols: [NSNumber]
    @objc public let historicalBytes: Data
    let groups: [InterfaceGroup]

    @objc(initWithBytes:) public convenience init?(bytes: Data) {
        var i = 0
        let b = [UInt8](bytes)
        self.init(source: { i < b.count ? { defer { i += 1 }; return Int32(b[i]) }() : -1 })
    }
    @objc(initWithSource:) public init?(source: () -> Int32) {
        var raw: [UInt8] = []
        func next() -> UInt8? { let v = source(); guard v >= 0 && v <= 255 else { return nil }; raw.append(UInt8(v)); return UInt8(v) }
        guard let ts = next(), ts == 0x3B || ts == 0x3F, var y = next() else { return nil }
        let k = Int(y & 0x0F)
        var groups: [InterfaceGroup] = [], protocols: [Int] = [], proto: Int? = nil
        while true {
            let ta = y & 0x10 != 0 ? next().map { NSNumber(value: $0) } : nil
            if y & 0x10 != 0 && ta == nil { return nil }
            let tb = y & 0x20 != 0 ? next().map { NSNumber(value: $0) } : nil
            if y & 0x20 != 0 && tb == nil { return nil }
            let tc = y & 0x40 != 0 ? next().map { NSNumber(value: $0) } : nil
            if y & 0x40 != 0 && tc == nil { return nil }
            groups.append(InterfaceGroup(ta: ta, tb: tb, tc: tc, protocol: proto.map { NSNumber(value: $0) }))
            guard y & 0x80 != 0 else { break }
            guard let td = next() else { return nil }
            let t = Int(td & 0x0F)
            if !protocols.contains(t) { protocols.append(t) }
            proto = t
            y = td
        }
        var hist: [UInt8] = []
        for _ in 0..<k { guard let h = next() else { return nil }; hist.append(h) }
        if protocols.contains(where: { $0 != 0 }) {                  // TCK: the XOR of T0 … TCK is zero
            guard next() != nil else { return nil }
            guard raw.dropFirst().reduce(0, ^) == 0 else { return nil }
        }
        if protocols.isEmpty { protocols = [0] }
        bytes = Data(raw)
        self.protocols = protocols.map { NSNumber(value: $0) }
        historicalBytes = Data(hist)
        self.groups = groups
        super.init()
    }
    /// interface group `index` (the first is 1)
    @objc(interfaceGroupAtIndex:) open func interfaceGroup(at index: Int) -> InterfaceGroup? {
        index >= 1 && index <= groups.count ? groups[index - 1] : nil
    }
    /// the first interface group the ATR announces for the protocol (T=0 or T=1; T=15 for the global bytes)
    open func interfaceGroup(for p: TKSmartCardProtocol) -> InterfaceGroup? {
        let t = p == .t0 ? 0 : p == .t1 ? 1 : p == .t15 ? 15 : -1
        return groups.first { $0.protocol.map { Int(truncating: $0) } == t }
    }
    /// the historical bytes as compact-TLV records (category indicator 0x80; 0x00 with a 3-byte status at the end)
    @objc open var historicalRecords: [TKCompactTLVRecord]? {
        let h = [UInt8](historicalBytes)
        guard let first = h.first else { return nil }
        let body: [UInt8]
        switch first {
        case 0x80: body = Array(h.dropFirst())
        case 0x00 where h.count >= 4: body = Array(h.dropFirst().dropLast(3))
        default: return nil
        }
        return TKCompactTLVRecord.sequenceOfRecords(from: Data(body)) as? [TKCompactTLVRecord]
    }
    open override var description: String { "<TKSmartCardATR \(_hex(bytes))>" }
}
