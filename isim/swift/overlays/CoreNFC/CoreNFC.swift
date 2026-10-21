// isim Core NFC (self-authored, iOS API names). Like the iOS Simulator, there is no NFC reader: `readingAvailable` is
// false and a session that begins anyway is invalidated with NFCReaderError.readerErrorUnsupportedFeature. The tag types
// (NFCTag and the NFCNDEFTag, NFCISO7816Tag, NFCMiFareTag, NFCFeliCaTag and NFCISO15693Tag protocols) exist so apps
// build; no session ever detects a tag.
import Foundation
import UIKit

public let NFCErrorDomain = "NFCError"
public struct NFCReaderError: CustomNSError, LocalizedError, Sendable {
    public enum Code: Int, Sendable {
        case readerErrorUnsupportedFeature = 1, readerErrorSecurityViolation = 2, readerErrorInvalidParameter = 3
        case readerErrorInvalidParameterLength = 4, readerErrorParameterOutOfBound = 5, readerErrorRadioDisabled = 6
        case readerTransceiveErrorTagConnectionLost = 100, readerTransceiveErrorRetryExceeded = 101
        case readerTransceiveErrorTagResponseError = 102, readerTransceiveErrorSessionInvalidated = 103
        case readerTransceiveErrorTagNotConnected = 104, readerTransceiveErrorPacketTooLong = 105
        case readerSessionInvalidationErrorUserCanceled = 200, readerSessionInvalidationErrorSessionTimeout = 201
        case readerSessionInvalidationErrorSessionTerminatedUnexpectedly = 202, readerSessionInvalidationErrorSystemIsBusy = 203
        case readerSessionInvalidationErrorFirstNDEFTagRead = 204
        case tagCommandConfigurationErrorInvalidParameters = 300
        case ndefReaderSessionErrorTagNotWritable = 400, ndefReaderSessionErrorTagUpdateFailure = 401
        case ndefReaderSessionErrorTagSizeTooSmall = 402, ndefReaderSessionErrorZeroLengthMessage = 403
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { NFCErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
    public var errorDescription: String? { code == .readerErrorUnsupportedFeature ? "Feature not supported" : "NFC error \(code.rawValue)" }
    public static var readerErrorUnsupportedFeature: Code { .readerErrorUnsupportedFeature }
    public static var readerErrorSecurityViolation: Code { .readerErrorSecurityViolation }
    public static var readerErrorInvalidParameter: Code { .readerErrorInvalidParameter }
    public static var readerErrorInvalidParameterLength: Code { .readerErrorInvalidParameterLength }
    public static var readerErrorParameterOutOfBound: Code { .readerErrorParameterOutOfBound }
    public static var readerErrorRadioDisabled: Code { .readerErrorRadioDisabled }
    public static var readerTransceiveErrorTagConnectionLost: Code { .readerTransceiveErrorTagConnectionLost }
    public static var readerTransceiveErrorRetryExceeded: Code { .readerTransceiveErrorRetryExceeded }
    public static var readerTransceiveErrorTagResponseError: Code { .readerTransceiveErrorTagResponseError }
    public static var readerTransceiveErrorSessionInvalidated: Code { .readerTransceiveErrorSessionInvalidated }
    public static var readerTransceiveErrorTagNotConnected: Code { .readerTransceiveErrorTagNotConnected }
    public static var readerTransceiveErrorPacketTooLong: Code { .readerTransceiveErrorPacketTooLong }
    public static var readerSessionInvalidationErrorUserCanceled: Code { .readerSessionInvalidationErrorUserCanceled }
    public static var readerSessionInvalidationErrorSessionTimeout: Code { .readerSessionInvalidationErrorSessionTimeout }
    public static var readerSessionInvalidationErrorSessionTerminatedUnexpectedly: Code { .readerSessionInvalidationErrorSessionTerminatedUnexpectedly }
    public static var readerSessionInvalidationErrorSystemIsBusy: Code { .readerSessionInvalidationErrorSystemIsBusy }
    public static var readerSessionInvalidationErrorFirstNDEFTagRead: Code { .readerSessionInvalidationErrorFirstNDEFTagRead }
    public static var tagCommandConfigurationErrorInvalidParameters: Code { .tagCommandConfigurationErrorInvalidParameters }
    public static var ndefReaderSessionErrorTagNotWritable: Code { .ndefReaderSessionErrorTagNotWritable }
    public static var ndefReaderSessionErrorTagUpdateFailure: Code { .ndefReaderSessionErrorTagUpdateFailure }
    public static var ndefReaderSessionErrorTagSizeTooSmall: Code { .ndefReaderSessionErrorTagSizeTooSmall }
    public static var ndefReaderSessionErrorZeroLengthMessage: Code { .ndefReaderSessionErrorZeroLengthMessage }
}

public enum NFCTypeNameFormat: UInt8, Sendable { case empty = 0, nfcWellKnown, media, absoluteURI, nfcExternal, unknown, unchanged }
open class NFCNDEFPayload: NSObject, @unchecked Sendable {
    open var typeNameFormat: NFCTypeNameFormat
    open var type: Data, identifier: Data, payload: Data
    public init(format: NFCTypeNameFormat, type: Data, identifier: Data, payload: Data) {
        typeNameFormat = format; self.type = type; self.identifier = identifier; self.payload = payload
    }
    open class func wellKnownTypeURIPayload(string uri: String) -> NFCNDEFPayload? {
        NFCNDEFPayload(format: .nfcWellKnown, type: Data("U".utf8), identifier: Data(), payload: Data([0]) + Data(uri.utf8))
    }
    open class func wellKnownTypeTextPayload(string text: String, locale: Locale) -> NFCNDEFPayload? {
        let lang = Data((locale.languageCode ?? "en").utf8)
        return NFCNDEFPayload(format: .nfcWellKnown, type: Data("T".utf8), identifier: Data(), payload: Data([UInt8(lang.count)]) + lang + Data(text.utf8))
    }
}
open class NFCNDEFMessage: NSObject, @unchecked Sendable {
    open var records: [NFCNDEFPayload]
    public init(records: [NFCNDEFPayload]) { self.records = records }
    open var length: Int { records.reduce(0) { $0 + $1.payload.count + $1.type.count + 3 } }
}

/// what every reader session does
public protocol NFCReaderSessionProtocol: NSObjectProtocol {
    var isReady: Bool { get }
    var alertMessage: String { get set }
    func begin()
    func invalidate()
    func invalidate(errorMessage: String)
}
open class NFCReaderSession: NSObject, NFCReaderSessionProtocol, @unchecked Sendable {
    open class var readingAvailable: Bool { false }
    open private(set) var isReady = false
    open var alertMessage = ""
    let queue: DispatchQueue
    init(queue: DispatchQueue?) { self.queue = queue ?? .global() }
    open func begin() {
        if (Bundle.main.object(forInfoDictionaryKey: "NFCReaderUsageDescription") as? String ?? "").isEmpty {
            // iOS terminates an app that starts a reader session without it; isim ends the session as a security violation
            NSLog("isim CoreNFC: this app has attempted to access privacy-sensitive data without a usage description. The app's Info.plist must contain an NFCReaderUsageDescription key with a string value explaining to the user how the app uses this data (iOS would terminate the app; isim invalidates the session)")
            queue.async { self.invalidated(NFCReaderError(.readerErrorSecurityViolation)) }
            return
        }
        NSLog("isim CoreNFC: NFC reading is not available on this device (like the iOS Simulator)")
        queue.async { self.invalidated(NFCReaderError(.readerErrorUnsupportedFeature)) }
    }
    open func invalidate() { queue.async { self.invalidated(NFCReaderError(.readerSessionInvalidationErrorUserCanceled)) } }
    open func invalidate(errorMessage: String) { invalidate() }
    func invalidated(_ e: NFCReaderError) {}
}

public protocol NFCNDEFReaderSessionDelegate: NSObjectProtocol {
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error)
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage])
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession)
}
extension NFCNDEFReaderSessionDelegate { public func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {} }

open class NFCNDEFReaderSession: NFCReaderSession, @unchecked Sendable {
    open weak var delegate: NFCNDEFReaderSessionDelegate?
    public let invalidateAfterFirstRead: Bool
    public init(delegate: NFCNDEFReaderSessionDelegate, queue: DispatchQueue?, invalidateAfterFirstRead: Bool) {
        self.delegate = delegate; self.invalidateAfterFirstRead = invalidateAfterFirstRead
        super.init(queue: queue)
    }
    open override class var readingAvailable: Bool { false }
    override func invalidated(_ e: NFCReaderError) { delegate?.readerSession(self, didInvalidateWithError: e) }
    /// connects to a tag the session detected (none is ever detected)
    open func connect(to tag: NFCNDEFTag, completionHandler: @escaping @Sendable (Error?) -> Void) {
        queue.async { completionHandler(NFCReaderError(.readerTransceiveErrorTagNotConnected)) }
    }
    open func connect(to tag: NFCNDEFTag) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in connect(to: tag) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    open func restartPolling() {}
}

public protocol NFCTagReaderSessionDelegate: NSObjectProtocol {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession)
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error)
    func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag])
}
extension NFCTagReaderSessionDelegate { public func tagReaderSession(_ session: NFCTagReaderSession, didDetect tags: [NFCTag]) {} }
open class NFCTagReaderSession: NFCReaderSession, @unchecked Sendable {
    public struct PollingOption: OptionSet, Sendable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }
        public static let iso14443 = PollingOption(rawValue: 1), iso15693 = PollingOption(rawValue: 2), iso18092 = PollingOption(rawValue: 4), pace = PollingOption(rawValue: 8)
    }
    open weak var delegate: NFCTagReaderSessionDelegate?
    public init?(pollingOption: PollingOption, delegate: NFCTagReaderSessionDelegate, queue: DispatchQueue? = nil) {
        self.delegate = delegate
        super.init(queue: queue)
    }
    open override class var readingAvailable: Bool { false }
    override func invalidated(_ e: NFCReaderError) { delegate?.tagReaderSession(self, didInvalidateWithError: e) }
    /// the tag the session is connected to: none (no tag is ever detected)
    open var connectedTag: NFCTag? { nil }
    open func connect(to tag: NFCTag, completionHandler: @escaping @Sendable (Error?) -> Void) {
        queue.async { completionHandler(NFCReaderError(.readerTransceiveErrorTagNotConnected)) }
    }
    open func connect(to tag: NFCTag) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in connect(to: tag) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    open func restartPolling() {}
}

// MARK: - tags
public enum NFCTagType: UInt, @unchecked Sendable { case iso15693 = 1, feliCa = 2, iso7816Compatible = 3, miFare = 4 }
public enum NFCNDEFStatus: UInt, @unchecked Sendable { case notSupported = 1, readWrite = 2, readOnly = 3 }

/// a tag that reads and writes NDEF messages
public protocol NFCNDEFTag: NSObjectProtocol, NSCopying, NSSecureCoding {
    var isAvailable: Bool { get }
    func queryNDEFStatus(completionHandler: @escaping @Sendable (NFCNDEFStatus, Int, Error?) -> Void)
    func readNDEF(completionHandler: @escaping @Sendable (NFCNDEFMessage?, Error?) -> Void)
    func writeNDEF(_ ndefMessage: NFCNDEFMessage, completionHandler: @escaping @Sendable (Error?) -> Void)
    func writeLock(completionHandler: @escaping @Sendable (Error?) -> Void)
}
extension NFCNDEFTag {
    public func queryNDEFStatus() async throws -> (NFCNDEFStatus, Int) {
        try await withCheckedThrowingContinuation { c in queryNDEFStatus { s, cap, e in if let e { c.resume(throwing: e) } else { c.resume(returning: (s, cap)) } } }
    }
    public func readNDEF() async throws -> NFCNDEFMessage {
        try await withCheckedThrowingContinuation { c in
            readNDEF { m, e in if let m { c.resume(returning: m) } else { c.resume(throwing: e ?? NFCReaderError(.ndefReaderSessionErrorZeroLengthMessage)) } }
        }
    }
    public func writeNDEF(_ ndefMessage: NFCNDEFMessage) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in writeNDEF(ndefMessage) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    public func writeLock() async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in writeLock { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
}

/// an ISO 7816 command (an APDU)
open class NFCISO7816APDU: NSObject, NSCopying, @unchecked Sendable {
    public let instructionClass: UInt8, instructionCode: UInt8, p1Parameter: UInt8, p2Parameter: UInt8
    public let data: Data?
    public let expectedResponseLength: Int
    public init(instructionClass: UInt8, instructionCode: UInt8, p1Parameter: UInt8, p2Parameter: UInt8, data: Data, expectedResponseLength: Int) {
        self.instructionClass = instructionClass; self.instructionCode = instructionCode; self.p1Parameter = p1Parameter; self.p2Parameter = p2Parameter
        self.data = data.isEmpty ? nil : data; self.expectedResponseLength = expectedResponseLength
    }
    /// parses a command APDU: CLA INS P1 P2 [Lc data] [Le] (short form)
    public init?(data: Data) {
        let b = [UInt8](data)
        guard b.count >= 4 else { return nil }
        instructionClass = b[0]; instructionCode = b[1]; p1Parameter = b[2]; p2Parameter = b[3]
        var payload: Data?, le = -1
        if b.count == 5 { le = b[4] == 0 ? 256 : Int(b[4]) }
        else if b.count > 5 {
            let lc = Int(b[4])
            guard b.count >= 5 + lc else { return nil }
            payload = Data(b[5..<(5 + lc)])
            if b.count == 6 + lc { le = b[5 + lc] == 0 ? 256 : Int(b[5 + lc]) } else if b.count != 5 + lc { return nil }
        }
        self.data = payload; expectedResponseLength = le
    }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}
/// an ISO 7816 response: the payload and the status words
public struct NFCISO7816ResponseAPDU: Sendable {
    public let payload: Data?
    public let statusWord1: UInt8
    public let statusWord2: UInt8
    public init(data: Data) {
        let b = [UInt8](data)
        statusWord1 = b.count >= 2 ? b[b.count - 2] : 0; statusWord2 = b.last ?? 0
        payload = b.count > 2 ? Data(b[0..<(b.count - 2)]) : nil
    }
}

/// an ISO 7816-compatible tag (ISO 14443-4: smart cards, passports)
public protocol NFCISO7816Tag: NFCNDEFTag {
    var initialSelectedAID: String { get }
    var identifier: Data { get }
    var historicalBytes: Data? { get }
    var applicationData: Data? { get }
    var proprietaryApplicationDataCoding: Bool { get }
    func sendCommand(apdu: NFCISO7816APDU, completionHandler: @escaping @Sendable (Data, UInt8, UInt8, Error?) -> Void)
}
extension NFCISO7816Tag {
    public func sendCommand(apdu: NFCISO7816APDU) async throws -> (Data, UInt8, UInt8) {
        try await withCheckedThrowingContinuation { c in sendCommand(apdu: apdu) { d, s1, s2, e in if let e { c.resume(throwing: e) } else { c.resume(returning: (d, s1, s2)) } } }
    }
    public func sendCommand(apdu: NFCISO7816APDU, resultHandler: @escaping @Sendable (Result<NFCISO7816ResponseAPDU, Error>) -> Void) {
        sendCommand(apdu: apdu) { d, s1, s2, e in resultHandler(e.map { .failure($0) } ?? .success(NFCISO7816ResponseAPDU(data: d + Data([s1, s2])))) }
    }
}

public enum NFCMiFareFamily: UInt, @unchecked Sendable { case unknown = 1, ultralight = 2, plus = 3, desfire = 4 }
/// a MIFARE tag (Ultralight, Plus, DESFire)
public protocol NFCMiFareTag: NFCNDEFTag {
    var mifareFamily: NFCMiFareFamily { get }
    var identifier: Data { get }
    var historicalBytes: Data? { get }
    func sendMiFareCommand(commandPacket command: Data, completionHandler: @escaping @Sendable (Data, Error?) -> Void)
    func sendMiFareISO7816Command(_ apdu: NFCISO7816APDU, completionHandler: @escaping @Sendable (Data, UInt8, UInt8, Error?) -> Void)
}
extension NFCMiFareTag {
    public func sendMiFareCommand(commandPacket command: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { c in sendMiFareCommand(commandPacket: command) { d, e in if let e { c.resume(throwing: e) } else { c.resume(returning: d) } } }
    }
    public func sendMiFareISO7816Command(_ apdu: NFCISO7816APDU) async throws -> (Data, UInt8, UInt8) {
        try await withCheckedThrowingContinuation { c in sendMiFareISO7816Command(apdu) { d, s1, s2, e in if let e { c.resume(throwing: e) } else { c.resume(returning: (d, s1, s2)) } } }
    }
}

public enum NFCFeliCaPollingRequestCode: Int, @unchecked Sendable { case noRequest = 0, systemCode = 1, communicationPerformance = 2 }
public enum NFCFeliCaPollingTimeSlot: Int, @unchecked Sendable { case max1 = 0, max2 = 1, max4 = 3, max8 = 7, max16 = 15 }
public enum NFCFeliCaEncryptionId: Int, @unchecked Sendable { case AES = 0x4F, DES = 0x41 }
/// a FeliCa tag (JIS X 6319-4)
public protocol NFCFeliCaTag: NFCNDEFTag {
    var currentSystemCode: Data { get }
    var currentIDm: Data { get }
    func polling(systemCode: Data, requestCode: NFCFeliCaPollingRequestCode, timeSlot: NFCFeliCaPollingTimeSlot, completionHandler: @escaping @Sendable (Data, Data, Error?) -> Void)
    func requestService(nodeCodeList: [Data], completionHandler: @escaping @Sendable ([Data], Error?) -> Void)
    func requestResponse(completionHandler: @escaping @Sendable (Int, Error?) -> Void)
    func readWithoutEncryption(serviceCodeList: [Data], blockList: [Data], completionHandler: @escaping @Sendable (Int, Int, [Data], Error?) -> Void)
    func writeWithoutEncryption(serviceCodeList: [Data], blockList: [Data], blockData: [Data], completionHandler: @escaping @Sendable (Int, Int, Error?) -> Void)
    func requestSystemCode(completionHandler: @escaping @Sendable ([Data], Error?) -> Void)
    func requestServiceV2(nodeCodeList: [Data], completionHandler: @escaping @Sendable (Int, Int, NFCFeliCaEncryptionId, [Data], [Data], Error?) -> Void)
    func requestSpecificationVersion(completionHandler: @escaping @Sendable (Int, Int, Data, Data, Error?) -> Void)
    func resetMode(completionHandler: @escaping @Sendable (Int, Int, Error?) -> Void)
    func sendFeliCaCommand(commandPacket: Data, completionHandler: @escaping @Sendable (Data, Error?) -> Void)
}
extension NFCFeliCaTag {
    public func polling(systemCode: Data, requestCode: NFCFeliCaPollingRequestCode, timeSlot: NFCFeliCaPollingTimeSlot) async throws -> (Data, Data) {
        try await withCheckedThrowingContinuation { c in polling(systemCode: systemCode, requestCode: requestCode, timeSlot: timeSlot) { pm, rd, e in if let e { c.resume(throwing: e) } else { c.resume(returning: (pm, rd)) } } }
    }
    public func readWithoutEncryption(serviceCodeList: [Data], blockList: [Data]) async throws -> (Int, Int, [Data]) {
        try await withCheckedThrowingContinuation { c in readWithoutEncryption(serviceCodeList: serviceCodeList, blockList: blockList) { s1, s2, d, e in if let e { c.resume(throwing: e) } else { c.resume(returning: (s1, s2, d)) } } }
    }
    public func sendFeliCaCommand(commandPacket: Data) async throws -> Data {
        try await withCheckedThrowingContinuation { c in sendFeliCaCommand(commandPacket: commandPacket) { d, e in if let e { c.resume(throwing: e) } else { c.resume(returning: d) } } }
    }
}

/// ISO 15693 request flags
public struct NFCISO15693RequestFlag: OptionSet, Sendable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let dualSubCarriers = NFCISO15693RequestFlag(rawValue: 1), highDataRate = NFCISO15693RequestFlag(rawValue: 2)
    public static let protocolExtension = NFCISO15693RequestFlag(rawValue: 8), select = NFCISO15693RequestFlag(rawValue: 16)
    public static let address = NFCISO15693RequestFlag(rawValue: 32), option = NFCISO15693RequestFlag(rawValue: 64)
    public static let commandSpecificBit8 = NFCISO15693RequestFlag(rawValue: 128)
}
public typealias RequestFlag = NFCISO15693RequestFlag
/// an ISO 15693 (vicinity) tag
public protocol NFCISO15693Tag: NFCNDEFTag {
    var identifier: Data { get }
    var icManufacturerCode: Int { get }
    var icSerialNumber: Data { get }
    func readSingleBlock(requestFlags flags: RequestFlag, blockNumber: UInt8, completionHandler: @escaping @Sendable (Data, Error?) -> Void)
    func writeSingleBlock(requestFlags flags: RequestFlag, blockNumber: UInt8, dataBlock: Data, completionHandler: @escaping @Sendable (Error?) -> Void)
    func lockBlock(requestFlags flags: RequestFlag, blockNumber: UInt8, completionHandler: @escaping @Sendable (Error?) -> Void)
    func readMultipleBlocks(requestFlags flags: RequestFlag, blockRange: NSRange, completionHandler: @escaping @Sendable ([Data], Error?) -> Void)
    func writeMultipleBlocks(requestFlags flags: RequestFlag, blockRange: NSRange, dataBlocks: [Data], completionHandler: @escaping @Sendable (Error?) -> Void)
    func select(requestFlags flags: RequestFlag, completionHandler: @escaping @Sendable (Error?) -> Void)
    func resetToReady(requestFlags flags: RequestFlag, completionHandler: @escaping @Sendable (Error?) -> Void)
    func writeAFI(requestFlags flags: RequestFlag, afi: UInt8, completionHandler: @escaping @Sendable (Error?) -> Void)
    func lockAFI(requestFlags flags: RequestFlag, completionHandler: @escaping @Sendable (Error?) -> Void)
    func writeDSFID(requestFlags flags: RequestFlag, dsfid: UInt8, completionHandler: @escaping @Sendable (Error?) -> Void)
    func lockDFSID(requestFlags flags: RequestFlag, completionHandler: @escaping @Sendable (Error?) -> Void)
    func getSystemInfo(requestFlags flags: RequestFlag, completionHandler: @escaping @Sendable (Int, Int, Int, Int, Int, Error?) -> Void)
    func getMultipleBlockSecurityStatus(requestFlags flags: RequestFlag, blockRange: NSRange, completionHandler: @escaping @Sendable ([NSNumber], Error?) -> Void)
    func customCommand(requestFlags flags: RequestFlag, customCommandCode: Int, customRequestParameters: Data, completionHandler: @escaping @Sendable (Data, Error?) -> Void)
}
extension NFCISO15693Tag {
    public func readSingleBlock(requestFlags flags: RequestFlag, blockNumber: UInt8) async throws -> Data {
        try await withCheckedThrowingContinuation { c in readSingleBlock(requestFlags: flags, blockNumber: blockNumber) { d, e in if let e { c.resume(throwing: e) } else { c.resume(returning: d) } } }
    }
    public func writeSingleBlock(requestFlags flags: RequestFlag, blockNumber: UInt8, dataBlock: Data) async throws {
        try await withCheckedThrowingContinuation { (c: CheckedContinuation<Void, Error>) in writeSingleBlock(requestFlags: flags, blockNumber: blockNumber, dataBlock: dataBlock) { e in if let e { c.resume(throwing: e) } else { c.resume() } } }
    }
    public func readMultipleBlocks(requestFlags flags: RequestFlag, blockRange: NSRange) async throws -> [Data] {
        try await withCheckedThrowingContinuation { c in readMultipleBlocks(requestFlags: flags, blockRange: blockRange) { d, e in if let e { c.resume(throwing: e) } else { c.resume(returning: d) } } }
    }
}

/// a tag a tag reader session detected
public enum NFCTag: @unchecked Sendable {
    case feliCa(any NFCFeliCaTag)
    case iso7816(any NFCISO7816Tag)
    case iso15693(any NFCISO15693Tag)
    case miFare(any NFCMiFareTag)
    public var isAvailable: Bool {
        switch self {
        case .feliCa(let t): return t.isAvailable
        case .iso7816(let t): return t.isAvailable
        case .iso15693(let t): return t.isAvailable
        case .miFare(let t): return t.isAvailable
        }
    }
}

// MARK: - Value Added Services (Apple Wallet passes over NFC)
open class NFCVASCommandConfiguration: NSObject, NSCopying, @unchecked Sendable {
    public enum Mode: Int, @unchecked Sendable { case urlOnly = 0, normal = 1 }
    open var mode: Mode
    open var passTypeIdentifier: String
    open var url: URL?
    public init(vasMode mode: Mode, passTypeIdentifier: String, url: URL?) {
        self.mode = mode; self.passTypeIdentifier = passTypeIdentifier; self.url = url
    }
    public func copy(with zone: NSZone? = nil) -> Any { NFCVASCommandConfiguration(vasMode: mode, passTypeIdentifier: passTypeIdentifier, url: url) }
}
open class NFCVASResponse: NSObject, NSCopying, @unchecked Sendable {
    public enum ErrorCode: Int, @unchecked Sendable {
        case success = 0x9000, dataNotFound = 0x6A83, dataNotActivated = 0x6287, wrongParameters = 0x6B00, wrongLCField = 0x6700
        case userIntervention = 0x6984, incorrectData = 0x6A80, unsupportedApplicationVersion = 0x6340
    }
    open var status: ErrorCode { _status }
    open var vasData: Data { _vasData }
    open var mobileToken: Data { _mobileToken }
    let _status: ErrorCode, _vasData: Data, _mobileToken: Data
    init(status: ErrorCode, vasData: Data, mobileToken: Data) { _status = status; _vasData = vasData; _mobileToken = mobileToken }
    public func copy(with zone: NSZone? = nil) -> Any { self }
}
public protocol NFCVASReaderSessionDelegate: NSObjectProtocol {
    func readerSessionDidBecomeActive(_ session: NFCVASReaderSession)
    func readerSession(_ session: NFCVASReaderSession, didInvalidateWithError error: Error)
    func readerSession(_ session: NFCVASReaderSession, didReceive responses: [NFCVASResponse])
}
extension NFCVASReaderSessionDelegate { public func readerSessionDidBecomeActive(_ session: NFCVASReaderSession) {} }
/// reads Apple Wallet passes (the VAS protocol); needs the NFC Pass Type Identifiers entitlement on iOS
open class NFCVASReaderSession: NFCReaderSession, @unchecked Sendable {
    open weak var delegate: NFCVASReaderSessionDelegate?
    public let vasCommandConfigurations: [NFCVASCommandConfiguration]
    public init(vasCommandConfigurations: [NFCVASCommandConfiguration], delegate: NFCVASReaderSessionDelegate, queue: DispatchQueue?) {
        self.vasCommandConfigurations = vasCommandConfigurations; self.delegate = delegate
        super.init(queue: queue)
    }
    open override class var readingAvailable: Bool { false }
    override func invalidated(_ e: NFCReaderError) { delegate?.readerSession(self, didInvalidateWithError: e) }
}

// MARK: - scene events (iOS 17.4, the EEA's host card emulation)
/// what made the system create the app's scene for NFC. isim has no NFC: the event reaches an app only through the
/// launch marker isim-nfc:readerDetected|presentation (ISIM_LAUNCH_URL), in its launch scene's connection options
public enum NFCWindowSceneEvent: Sendable, Hashable {
    /// the device detected an NFC reader's RF field
    case readerDetected
    /// the person did the gesture that presents an NFC display
    case presentation
}
extension UIScene.ConnectionOptions {
    @available(iOS 17.4, *)
    @MainActor public var nfcEvent: NFCWindowSceneEvent? {
        switch value(forKey: "_isim_launchMarker") as? String {
        case "isim-nfc:readerDetected": return .readerDetected
        case "isim-nfc:presentation": return .presentation
        default: return nil
        }
    }
}
