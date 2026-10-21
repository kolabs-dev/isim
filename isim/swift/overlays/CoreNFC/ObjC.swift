// isim Core NFC for Objective-C (sdk-src/Frameworks/CoreNFC): the classes carry Apple's Objective-C names and these
// members Apple's selectors. The delegate protocols are Swift protocols here, so an Objective-C delegate is wrapped in an
// adapter (kept alive by the session) that sends it Apple's selectors. Sessions made from Objective-C call their delegate
// on a global queue, whatever queue they were given.
import Foundation
import ObjectiveC

nonisolated(unsafe) private var _nfcAdapterKey: UInt8 = 0
/// sends an Objective-C message with up to two object arguments to an object that implements it
private func _nfcSend(_ target: NSObject?, _ sel: String, _ a: AnyObject?, _ b: AnyObject? = nil) {
    guard let target else { return }
    let s = NSSelectorFromString(sel)
    guard target.responds(to: s) else { return }
    typealias Send = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?) -> Void
    unsafeBitCast(target.method(for: s), to: Send.self)(target, s, a, b)
}
final class _NFCObjCNDEFDelegate: NSObject, NFCNDEFReaderSessionDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        _nfcSend(target, "readerSession:didInvalidateWithError:", session, error as NSError)
    }
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        _nfcSend(target, "readerSession:didDetectNDEFs:", session, messages as NSArray)
    }
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) { _nfcSend(target, "readerSessionDidBecomeActive:", session) }
}
final class _NFCObjCTagDelegate: NSObject, NFCTagReaderSessionDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func tagReaderSessionDidBecomeActive(_ session: NFCTagReaderSession) { _nfcSend(target, "tagReaderSessionDidBecomeActive:", session) }
    func tagReaderSession(_ session: NFCTagReaderSession, didInvalidateWithError error: Error) {
        _nfcSend(target, "tagReaderSession:didInvalidateWithError:", session, error as NSError)
    }
}
final class _NFCObjCVASDelegate: NSObject, NFCVASReaderSessionDelegate {
    weak var target: NSObject?
    init(_ t: NSObject) { target = t }
    func readerSessionDidBecomeActive(_ session: NFCVASReaderSession) { _nfcSend(target, "readerSessionDidBecomeActive:", session) }
    func readerSession(_ session: NFCVASReaderSession, didInvalidateWithError error: Error) {
        _nfcSend(target, "readerSession:didInvalidateWithError:", session, error as NSError)
    }
    func readerSession(_ session: NFCVASReaderSession, didReceive responses: [NFCVASResponse]) {
        _nfcSend(target, "readerSession:didReceiveVASResponses:", session, responses as NSArray)
    }
}

extension NFCNDEFPayload {
    @objc(initWithFormat:type:identifier:payload:) convenience init(_objcFormat f: UInt8, type: Data, identifier: Data, payload: Data) {
        self.init(format: NFCTypeNameFormat(rawValue: f) ?? .unknown, type: type, identifier: identifier, payload: payload)
    }
    @objc(wellKnownTypeURIPayloadWithString:) class func _objc_uri(_ s: String) -> NFCNDEFPayload? { wellKnownTypeURIPayload(string: s) }
    @objc(wellKnownTypeTextPayloadWithString:locale:) class func _objc_text(_ s: String, locale: Locale) -> NFCNDEFPayload? {
        wellKnownTypeTextPayload(string: s, locale: locale)
    }
    @objc(typeNameFormat) var _objc_format: UInt8 { typeNameFormat.rawValue }
    @objc(type) var _objc_type: Data { type }
    @objc(identifier) var _objc_identifier: Data { identifier }
    @objc(payload) var _objc_payload: Data { payload }
    @objc(setTypeNameFormat:) func _objc_setFormat(_ f: UInt8) { typeNameFormat = NFCTypeNameFormat(rawValue: f) ?? .unknown }
    @objc(setType:) func _objc_setType(_ d: Data) { type = d }
    @objc(setIdentifier:) func _objc_setIdentifier(_ d: Data) { identifier = d }
    @objc(setPayload:) func _objc_setPayload(_ d: Data) { payload = d }
}
extension NFCNDEFMessage {
    @objc(initWithNDEFRecords:) convenience init(_objcRecords r: [NFCNDEFPayload]) { self.init(records: r) }
    @objc(records) var _objc_records: [NFCNDEFPayload] { get { records } set { records = newValue } }
    @objc(length) var _objc_length: Int { length }
}
extension NFCReaderSession {
    @objc(readingAvailable) class var _objc_readingAvailable: Bool { readingAvailable }
    @objc(isReady) var _objc_isReady: Bool { isReady }
    @objc(alertMessage) var _objc_alertMessage: String { get { alertMessage } set { alertMessage = newValue } }
    @objc(beginSession) func _objc_begin() { begin() }
    @objc(invalidateSession) func _objc_invalidate() { invalidate() }
    @objc(invalidateSessionWithErrorMessage:) func _objc_invalidate(_ m: String) { invalidate(errorMessage: m) }
    func _isimKeep(_ adapter: AnyObject) { objc_setAssociatedObject(self, &_nfcAdapterKey, adapter, .OBJC_ASSOCIATION_RETAIN) }
}
extension NFCNDEFReaderSession {
    @objc(initWithDelegate:queue:invalidateAfterFirstRead:)
    convenience init(_objcDelegate d: NSObject, queue: dispatch_queue_t?, invalidateAfterFirstRead: Bool) {
        let adapter = _NFCObjCNDEFDelegate(d)
        self.init(delegate: adapter, queue: nil, invalidateAfterFirstRead: invalidateAfterFirstRead)
        _isimKeep(adapter)
    }
}
extension NFCTagReaderSession {
    @objc(initWithPollingOption:delegate:queue:)
    convenience init?(_objcPolling p: Int, delegate d: NSObject, queue: dispatch_queue_t?) {
        let adapter = _NFCObjCTagDelegate(d)
        self.init(pollingOption: PollingOption(rawValue: p), delegate: adapter, queue: nil)
        _isimKeep(adapter)
    }
    @objc(restartPolling) func _objc_restartPolling() { restartPolling() }
}
extension NFCISO7816APDU {
    @objc(initWithInstructionClass:instructionCode:p1Parameter:p2Parameter:data:expectedResponseLength:)
    convenience init(_objcClass c: UInt8, instructionCode: UInt8, p1Parameter: UInt8, p2Parameter: UInt8, data: Data, expectedResponseLength: Int) {
        self.init(instructionClass: c, instructionCode: instructionCode, p1Parameter: p1Parameter, p2Parameter: p2Parameter, data: data, expectedResponseLength: expectedResponseLength)
    }
    @objc(initWithData:) convenience init?(_objcData d: Data) { self.init(data: d) }
    @objc(instructionClass) var _objc_cla: UInt8 { instructionClass }
    @objc(instructionCode) var _objc_ins: UInt8 { instructionCode }
    @objc(p1Parameter) var _objc_p1: UInt8 { p1Parameter }
    @objc(p2Parameter) var _objc_p2: UInt8 { p2Parameter }
    @objc(data) var _objc_data: Data? { data }
    @objc(expectedResponseLength) var _objc_le: Int { expectedResponseLength }
}
extension NFCVASCommandConfiguration {
    @objc(initWithVASMode:passTypeIdentifier:url:) convenience init(_objcMode m: Int, passTypeIdentifier: String, url: URL?) {
        self.init(vasMode: Mode(rawValue: m) ?? .normal, passTypeIdentifier: passTypeIdentifier, url: url)
    }
    @objc(mode) var _objc_mode: Int { get { mode.rawValue } set { mode = Mode(rawValue: newValue) ?? .normal } }
    @objc(passTypeIdentifier) var _objc_passTypeIdentifier: String { get { passTypeIdentifier } set { passTypeIdentifier = newValue } }
    @objc(url) var _objc_url: URL? { get { url } set { url = newValue } }
}
extension NFCVASResponse {
    @objc(status) var _objc_status: Int { status.rawValue }
    @objc(vasData) var _objc_vasData: Data { vasData }
    @objc(mobileToken) var _objc_mobileToken: Data { mobileToken }
}
extension NFCVASReaderSession {
    @objc(initWithVASCommandConfigurations:delegate:queue:)
    convenience init(_objcConfigurations c: [NFCVASCommandConfiguration], delegate d: NSObject, queue: dispatch_queue_t?) {
        let adapter = _NFCObjCVASDelegate(d)
        self.init(vasCommandConfigurations: c, delegate: adapter, queue: nil)
        _isimKeep(adapter)
    }
}
