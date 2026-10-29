// isim CallKit for Objective-C (sdk-src/Frameworks/CallKit): the classes carry Apple's Objective-C names and these
// members Apple's selectors. CXProviderDelegate and CXCallObserverDelegate are @objc protocols, so Objective-C
// delegates are used as they are; one given with a dispatch queue other than the main queue is wrapped in an adapter
// that answers only the selectors the delegate implements and calls it on its queue.
import Foundation
import Darwin
import ObjectiveC

/// sends an Objective-C message with up to three object arguments to an object that implements it
@discardableResult
func _cxSend(_ target: NSObject, _ sel: Selector, _ a: AnyObject? = nil, _ b: AnyObject? = nil, _ c: AnyObject? = nil) -> Bool {
    guard target.responds(to: sel) else { return false }
    typealias Send = @convention(c) (AnyObject, Selector, AnyObject?, AnyObject?, AnyObject?) -> Void
    unsafeBitCast(target.method(for: sel), to: Send.self)(target, sel, a, b, c)
    return true
}
/// nil for the main queue (the overlay's default), else the queue
func _cxQueue(_ q: dispatch_queue_t?) -> dispatch_queue_t? {
    guard let q else { return nil }
    return q == _isim_dispatch_main_queue() ? nil : q
}

/// an Objective-C provider delegate with its own queue
final class _CXObjCProviderDelegate: NSObject, CXProviderDelegate {
    weak var target: NSObject?
    let queue: dispatch_queue_t
    /// the queue is an Objective-C caller's: held while the adapter lives (ARC releases the caller's reference)
    init(_ t: NSObject, queue: dispatch_queue_t) { target = t; self.queue = queue; dispatch_retain(UnsafeMutableRawPointer(queue)) }
    deinit { dispatch_release(UnsafeMutableRawPointer(queue)) }
    override func responds(to s: Selector) -> Bool {
        s == #selector(CXProviderDelegate.providerDidReset(_:)) || (target?.responds(to: s) ?? false)
    }
    func on(_ sel: Selector, _ a: AnyObject?, _ b: AnyObject? = nil) {
        dispatch_async(queue) { [weak self] in if let t = self?.target { _cxSend(t, sel, a, b) } }
    }
    func providerDidReset(_ provider: CXProvider) { on(#selector(CXProviderDelegate.providerDidReset(_:)), provider) }
    func providerDidBegin(_ provider: CXProvider) { on(#selector(CXProviderDelegate.providerDidBegin(_:)), provider) }
    func provider(_ provider: CXProvider, execute transaction: CXTransaction) -> Bool {
        let sel = #selector(CXProviderDelegate.provider(_:execute:))
        var handled = false
        dispatch_sync(queue) { [weak self] in
            guard let t = self?.target, t.responds(to: sel) else { return }
            typealias Send = @convention(c) (AnyObject, Selector, AnyObject, AnyObject) -> Bool
            handled = unsafeBitCast(t.method(for: sel), to: Send.self)(t, sel, provider, transaction)
        }
        return handled
    }
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) { on(NSSelectorFromString("provider:performStartCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) { on(NSSelectorFromString("provider:performAnswerCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) { on(NSSelectorFromString("provider:performEndCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction) { on(NSSelectorFromString("provider:performSetHeldCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) { on(NSSelectorFromString("provider:performSetMutedCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction) { on(NSSelectorFromString("provider:performSetGroupCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction) { on(NSSelectorFromString("provider:performPlayDTMFCallAction:"), provider, action) }
    @available(iOS 26.0, *)
    func provider(_ provider: CXProvider, perform action: CXSetTranslatingCallAction) { on(NSSelectorFromString("provider:performSetTranslatingCallAction:"), provider, action) }
    func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) { on(NSSelectorFromString("provider:timedOutPerformingAction:"), provider, action) }
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) { on(NSSelectorFromString("provider:didActivateAudioSession:"), provider, audioSession) }
    func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) { on(NSSelectorFromString("provider:didDeactivateAudioSession:"), provider, audioSession) }
}
final class _CXObjCObserverDelegate: NSObject, CXCallObserverDelegate {
    weak var target: NSObject?
    let queue: dispatch_queue_t
    init(_ t: NSObject, queue: dispatch_queue_t) { target = t; self.queue = queue; dispatch_retain(UnsafeMutableRawPointer(queue)) }
    deinit { dispatch_release(UnsafeMutableRawPointer(queue)) }
    func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall) {
        dispatch_async(queue) { [weak self] in if let t = self?.target { _cxSend(t, #selector(CXCallObserverDelegate.callObserver(_:callChanged:)), callObserver, call) } }
    }
}
nonisolated(unsafe) private var _cxObjCDelegateKey: UInt8 = 0
nonisolated(unsafe) private var _cxObjCQueueKey: UInt8 = 0
final class _CXQueueBox {
    let queue: dispatch_queue_t
    init(_ q: dispatch_queue_t) { queue = q; dispatch_retain(UnsafeMutableRawPointer(q)) }
    deinit { dispatch_release(UnsafeMutableRawPointer(queue)) }
}

// MARK: - errors are NSErrors with Apple's domains and codes (CallKit.m has the domain constants)

func _cxError(_ e: Error?) -> NSError? { e.map { $0 as NSError } }

// MARK: - handles, updates, configuration

extension CXHandle {
    @objc(initWithType:value:) convenience init(_objcType type: HandleType, value: String) { self.init(type: type, value: value) }
    @objc(type) var _objc_type: HandleType { type }
    @objc(value) var _objc_value: String { value }
    @objc(isEqualToHandle:) func _objc_isEqual(_ handle: CXHandle) -> Bool { isEqual(to: handle) }
}
extension CXCallUpdate {
    @objc(remoteHandle) var _objc_remoteHandle: CXHandle? { get { remoteHandle } set { remoteHandle = newValue } }
    @objc(localizedCallerName) var _objc_localizedCallerName: String? { get { localizedCallerName } set { localizedCallerName = newValue } }
    @objc(supportsHolding) var _objc_supportsHolding: Bool { get { supportsHolding } set { supportsHolding = newValue } }
    @objc(supportsGrouping) var _objc_supportsGrouping: Bool { get { supportsGrouping } set { supportsGrouping = newValue } }
    @objc(supportsUngrouping) var _objc_supportsUngrouping: Bool { get { supportsUngrouping } set { supportsUngrouping = newValue } }
    @objc(supportsDTMF) var _objc_supportsDTMF: Bool { get { supportsDTMF } set { supportsDTMF = newValue } }
    @objc(hasVideo) var _objc_hasVideo: Bool { get { hasVideo } set { hasVideo = newValue } }
}
extension CXProviderConfiguration {
    @objc(initWithLocalizedName:) convenience init(_objcLocalizedName name: String) { self.init(); localizedName = name }
    @objc(localizedName) var _objc_localizedName: String? { localizedName }
    @objc(ringtoneSound) var _objc_ringtoneSound: String? { get { ringtoneSound } set { ringtoneSound = newValue } }
    @objc(iconTemplateImageData) var _objc_iconTemplateImageData: Data? { get { iconTemplateImageData } set { iconTemplateImageData = newValue } }
    @objc(maximumCallGroups) var _objc_maximumCallGroups: Int { get { maximumCallGroups } set { maximumCallGroups = newValue } }
    @objc(maximumCallsPerCallGroup) var _objc_maximumCallsPerCallGroup: Int { get { maximumCallsPerCallGroup } set { maximumCallsPerCallGroup = newValue } }
    @objc(includesCallsInRecents) var _objc_includesCallsInRecents: Bool { get { includesCallsInRecents } set { includesCallsInRecents = newValue } }
    @objc(supportsVideo) var _objc_supportsVideo: Bool { get { supportsVideo } set { supportsVideo = newValue } }
    @objc(supportsAudioTranslation) var _objc_supportsAudioTranslation: Bool { get { _supportsAudioTranslation } set { _supportsAudioTranslation = newValue } }
    @objc(supportedHandleTypes) var _objc_supportedHandleTypes: Set<NSNumber> {
        get { Set(supportedHandleTypes.map { NSNumber(value: $0.rawValue) }) }
        set { supportedHandleTypes = Set(newValue.compactMap { CXHandle.HandleType(rawValue: Int(truncating: $0)) }) }
    }
}

// MARK: - actions and transactions

extension CXAction {
    @objc(UUID) var _objc_uuid: UUID { uuid }
    @objc(isComplete) var _objc_isComplete: Bool { isComplete }
    @objc(timeoutDate) var _objc_timeoutDate: Date { timeoutDate }
    @objc(fulfill) func _objc_fulfill() { fulfill() }
    @objc(fail) func _objc_fail() { fail() }
}
extension CXCallAction {
    @objc(initWithCallUUID:) convenience init(_objcCallUUID uuid: UUID) { self.init(call: uuid) }
    @objc(callUUID) var _objc_callUUID: UUID { callUUID }
}
extension CXStartCallAction {
    @objc(initWithCallUUID:handle:) convenience init(_objcCallUUID uuid: UUID, handle: CXHandle) { self.init(call: uuid, handle: handle) }
    @objc(handle) var _objc_handle: CXHandle { get { handle } set { handle = newValue } }
    @objc(contactIdentifier) var _objc_contactIdentifier: String? { get { contactIdentifier } set { contactIdentifier = newValue } }
    @objc(isVideo) var _objc_isVideo: Bool { get { isVideo } set { isVideo = newValue } }
    @objc(setVideo:) func _objc_setVideo(_ v: Bool) { isVideo = v }
    @objc(fulfillWithDateStarted:) func _objc_fulfill(_ date: Date) { fulfill(withDateStarted: date) }
}
extension CXAnswerCallAction {
    @objc(fulfillWithDateConnected:) func _objc_fulfill(_ date: Date) { fulfill(withDateConnected: date) }
}
extension CXEndCallAction {
    @objc(fulfillWithDateEnded:) func _objc_fulfill(_ date: Date) { fulfill(withDateEnded: date) }
}
extension CXSetHeldCallAction {
    @objc(initWithCallUUID:onHold:) convenience init(_objcCallUUID uuid: UUID, onHold: Bool) { self.init(call: uuid, onHold: onHold) }
    @objc(isOnHold) var _objc_isOnHold: Bool { get { isOnHold } set { isOnHold = newValue } }
    @objc(setOnHold:) func _objc_setOnHold(_ v: Bool) { isOnHold = v }
}
extension CXSetMutedCallAction {
    @objc(initWithCallUUID:muted:) convenience init(_objcCallUUID uuid: UUID, muted: Bool) { self.init(call: uuid, muted: muted) }
    @objc(isMuted) var _objc_isMuted: Bool { get { isMuted } set { isMuted = newValue } }
    @objc(setMuted:) func _objc_setMuted(_ v: Bool) { isMuted = v }
}
extension CXSetGroupCallAction {
    @objc(initWithCallUUID:callUUIDToGroupWith:) convenience init(_objcCallUUID uuid: UUID, callUUIDToGroupWith other: UUID?) {
        self.init(call: uuid, callUUIDToGroupWith: other)
    }
    @objc(callUUIDToGroupWith) var _objc_callUUIDToGroupWith: UUID? { get { callUUIDToGroupWith } set { callUUIDToGroupWith = newValue } }
}
extension CXPlayDTMFCallAction {
    @objc(initWithCallUUID:digits:type:) convenience init(_objcCallUUID uuid: UUID, digits: String, type: ActionType) {
        self.init(call: uuid, digits: digits, type: type)
    }
    @objc(digits) var _objc_digits: String { get { digits } set { digits = newValue } }
    @objc(type) var _objc_type: ActionType { get { type } set { type = newValue } }
}
@available(iOS 26.0, *)
extension CXSetTranslatingCallAction {
    @objc(initWithCallUUID:isTranslating:localLanguage:remoteLanguage:)
    convenience init(_objcCallUUID uuid: UUID, isTranslating: Bool, localLanguage: String, remoteLanguage: String) {
        self.init(call: uuid, isTranslating: isTranslating, localLanguage: localLanguage, remoteLanguage: remoteLanguage)
    }
    @objc(isTranslating) var _objc_isTranslating: Bool { isTranslating }
    @objc(localLanguage) var _objc_localLanguage: String { localLanguage }
    @objc(remoteLanguage) var _objc_remoteLanguage: String { remoteLanguage }
    @objc(fulfillUsingTranslationEngine:) func _objc_fulfill(using engine: CXTranslationEngine) { fulfill(using: engine) }
}
extension CXTransaction {
    @objc(initWithActions:) convenience init(_objcActions actions: [CXAction]) { self.init(actions: actions) }
    @objc(initWithAction:) convenience init(_objcAction action: CXAction) { self.init(action: action) }
    @objc(UUID) var _objc_uuid: UUID { uuid }
    @objc(isComplete) var _objc_isComplete: Bool { isComplete }
    @objc(actions) var _objc_actions: [CXAction] { actions }
    @objc(addAction:) func _objc_addAction(_ action: CXAction) { addAction(action) }
}

// MARK: - calls, the observer, the provider, the controller

extension CXCall {
    @objc(UUID) var _objc_uuid: UUID { uuid }
    @objc(isOutgoing) var _objc_isOutgoing: Bool { isOutgoing }
    @objc(isOnHold) var _objc_isOnHold: Bool { isOnHold }
    @objc(hasConnected) var _objc_hasConnected: Bool { hasConnected }
    @objc(hasEnded) var _objc_hasEnded: Bool { hasEnded }
    @objc(isEqualToCall:) func _objc_isEqual(_ call: CXCall) -> Bool { isEqual(to: call) }
}
extension CXCallObserver {
    @objc(calls) var _objc_calls: [CXCall] { calls }
    @objc(setDelegate:queue:) func _objc_setDelegate(_ delegate: CXCallObserverDelegate?, queue: dispatch_queue_t?) {
        if let d = delegate as? NSObject, let q = _cxQueue(queue) {
            let a = _CXObjCObserverDelegate(d, queue: q)
            objc_setAssociatedObject(self, &_cxObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)   // the delegate is weak
            setDelegate(a, queue: nil)
        } else {
            objc_setAssociatedObject(self, &_cxObjCDelegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setDelegate(delegate, queue: nil)
        }
    }
}
extension CXProvider {
    @objc(initWithConfiguration:) convenience init(_objcConfiguration configuration: CXProviderConfiguration) { self.init(configuration: configuration) }
    @objc(configuration) var _objc_configuration: CXProviderConfiguration { get { configuration } set { configuration = newValue } }
    @objc(setDelegate:queue:) func _objc_setDelegate(_ delegate: CXProviderDelegate?, queue: dispatch_queue_t?) {
        if let d = delegate as? NSObject, let q = _cxQueue(queue) {
            let a = _CXObjCProviderDelegate(d, queue: q)
            objc_setAssociatedObject(self, &_cxObjCDelegateKey, a, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setDelegate(a, queue: nil)
        } else {
            objc_setAssociatedObject(self, &_cxObjCDelegateKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            setDelegate(delegate, queue: nil)
        }
    }
    @objc(reportNewIncomingCallWithUUID:update:completion:)
    func _objc_reportNewIncomingCall(_ uuid: UUID, update: CXCallUpdate, completion: @escaping @convention(block) (NSError?) -> Void) {
        reportNewIncomingCall(with: uuid, update: update) { completion(_cxError($0)) }
    }
    @objc(reportCallWithUUID:updated:) func _objc_reportCall(_ uuid: UUID, updated update: CXCallUpdate) { reportCall(with: uuid, updated: update) }
    @objc(reportCallWithUUID:endedAtDate:reason:) func _objc_reportCall(_ uuid: UUID, endedAt date: Date?, reason: CXCallEndedReason) {
        reportCall(with: uuid, endedAt: date, reason: reason)
    }
    @objc(reportOutgoingCallWithUUID:startedConnectingAtDate:) func _objc_reportOutgoing(_ uuid: UUID, startedConnectingAt date: Date?) {
        reportOutgoingCall(with: uuid, startedConnectingAt: date)
    }
    @objc(reportOutgoingCallWithUUID:connectedAtDate:) func _objc_reportOutgoing(_ uuid: UUID, connectedAt date: Date?) {
        reportOutgoingCall(with: uuid, connectedAt: date)
    }
    @objc(invalidate) func _objc_invalidate() { invalidate() }
    @objc(pendingTransactions) var _objc_pendingTransactions: [CXTransaction] { pendingTransactions }
    @objc(pendingCallActionsOfClass:withCallUUID:) func _objc_pendingCallActions(_ cls: AnyClass, withCallUUID uuid: UUID) -> [CXCallAction] {
        pendingCallActions(of: CXCallAction.self, withCall: uuid).filter { $0.isKind(of: cls) }
    }
}
extension CXCallController {
    @objc(initWithQueue:) convenience init(_objcQueue queue: dispatch_queue_t) {
        self.init()
        if let q = _cxQueue(queue) { objc_setAssociatedObject(self, &_cxObjCQueueKey, _CXQueueBox(q), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
    /// the completion on the Objective-C caller's queue (the controller itself completes on the main queue)
    func _objcComplete(_ completion: @escaping @convention(block) (NSError?) -> Void) -> (Error?) -> Void {
        let q = (objc_getAssociatedObject(self, &_cxObjCQueueKey) as? _CXQueueBox)?.queue
        return { e in
            let err = _cxError(e)
            if let q { dispatch_async(q) { completion(err) } } else { completion(err) }
        }
    }
    @objc(callObserver) var _objc_callObserver: CXCallObserver { callObserver }
    @objc(requestTransaction:completion:) func _objc_request(_ t: CXTransaction, completion: @escaping @convention(block) (NSError?) -> Void) {
        request(t, completion: _objcComplete(completion))
    }
    @objc(requestTransactionWithActions:completion:)
    func _objc_request(actions: [CXAction], completion: @escaping @convention(block) (NSError?) -> Void) {
        requestTransaction(with: actions, completion: _objcComplete(completion))
    }
    @objc(requestTransactionWithAction:completion:)
    func _objc_request(action: CXAction, completion: @escaping @convention(block) (NSError?) -> Void) {
        requestTransaction(with: action, completion: _objcComplete(completion))
    }
}

// MARK: - Call Directory (stub)

extension CXCallDirectoryManager {
    @objc(sharedInstance) static var _objc_sharedInstance: CXCallDirectoryManager { sharedInstance }
    @objc(reloadExtensionWithIdentifier:completionHandler:)
    func _objc_reload(_ identifier: String, completionHandler: (@convention(block) (NSError?) -> Void)?) {
        reloadExtension(withIdentifier: identifier) { completionHandler?(_cxError($0)) }
    }
    @objc(getEnabledStatusForExtensionWithIdentifier:completionHandler:)
    func _objc_getEnabledStatus(_ identifier: String, completionHandler: @escaping @convention(block) (EnabledStatus, NSError?) -> Void) {
        getEnabledStatusForExtension(withIdentifier: identifier) { s, e in completionHandler(s, _cxError(e)) }
    }
    @objc(openSettingsWithCompletionHandler:) func _objc_openSettings(_ completionHandler: (@convention(block) (NSError?) -> Void)?) {
        openSettings { completionHandler?(_cxError($0)) }
    }
}
extension CXCallDirectoryExtensionContext {
    @objc(delegate) var _objc_delegate: CXCallDirectoryExtensionContextDelegate? { get { delegate } set { delegate = newValue } }
    @objc(isIncremental) var _objc_isIncremental: Bool { isIncremental }
    @objc(addBlockingEntryWithNextSequentialPhoneNumber:) func _objc_addBlocking(_ n: Int64) { addBlockingEntry(withNextSequentialPhoneNumber: n) }
    @objc(removeBlockingEntryWithPhoneNumber:) func _objc_removeBlocking(_ n: Int64) { removeBlockingEntry(withPhoneNumber: n) }
    @objc(removeAllBlockingEntries) func _objc_removeAllBlocking() { removeAllBlockingEntries() }
    @objc(addIdentificationEntryWithNextSequentialPhoneNumber:label:) func _objc_addIdentification(_ n: Int64, label: String) {
        addIdentificationEntry(withNextSequentialPhoneNumber: n, label: label)
    }
    @objc(removeIdentificationEntryWithPhoneNumber:) func _objc_removeIdentification(_ n: Int64) { removeIdentificationEntry(withPhoneNumber: n) }
    @objc(removeAllIdentificationEntries) func _objc_removeAllIdentification() { removeAllIdentificationEntries() }
    @objc(completeRequestWithCompletionHandler:) func _objc_complete(_ h: (@convention(block) (Bool) -> Void)?) { completeRequest { h?($0) } }
}
