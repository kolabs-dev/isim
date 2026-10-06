// isim Core NFC (self-authored, iOS API names). Like the iOS Simulator, there is no NFC reader: `readingAvailable` is
// false and a session that begins anyway is invalidated with NFCReaderError.readerErrorUnsupportedFeature.
import Foundation

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

open class NFCReaderSession: NSObject, @unchecked Sendable {
    open class var readingAvailable: Bool { false }
    open private(set) var isReady = false
    open var alertMessage = ""
    let queue: DispatchQueue
    init(queue: DispatchQueue?) { self.queue = queue ?? .global() }
    open func begin() {
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
}

public protocol NFCTagReaderSessionDelegate: NSObjectProtocol {
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession)
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error)
}
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
}
