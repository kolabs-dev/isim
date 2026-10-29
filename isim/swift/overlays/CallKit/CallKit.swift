// isim CallKit: VoIP calls with the system call UI (adapted). The app's CXProvider reports calls to the device: the
// shell (runtime/shell_calls.inc) shows an incoming call (a banner while the device is in use, full screen on the
// Lock Screen) and plays the ringtone (the provider's ringtoneSound, else isim's ringtone; Silent Mode vibrates), the
// in-call screen (mute, keypad, speaker, hold, the app's button, end) and, while the app is in the foreground or the
// call screen is hidden, the green call indicator. What the user does there comes back as provider actions
// (CXAnswerCallAction, CXEndCallAction, CXSetMutedCallAction, CXSetHeldCallAction, CXPlayDTMFCallAction), given to
// the provider's delegate; when an action is fulfilled the call changes, and answering / starting a call activates
// the audio session (provider(_:didActivate:)), ending the last one deactivates it. CXCallController requests
// (start, end, hold, mute, group, DTMF) are checked like iOS's and performed by the app's own provider. CXCallObserver
// sees the app's calls (isim has no telephony: not other apps' calls). Script ids: call-banner, call-accept,
// call-decline, call-mute, call-keypad, call-key-N, call-speaker, call-hold, call-app, call-end, call-pill.
// Stub: Call Directory extensions are never run (like iOS before the user enables them in Settings, reloading one
// fails with extensionDisabled).
@_exported import Foundation
@_exported import AVFoundation
import isim_host

// MARK: - errors

public let CXErrorDomain = "com.apple.CallKit.error"
public let CXErrorDomainIncomingCall = "com.apple.CallKit.error.incomingcall"
public let CXErrorDomainRequestTransaction = "com.apple.CallKit.error.requesttransaction"
public let CXErrorDomainCallDirectoryManager = "com.apple.CallKit.error.calldirectorymanager"
public let CXErrorDomainNotificationServiceExtension = "com.apple.CallKit.error.notificationserviceextension"

public struct CXErrorCodeIncomingCallError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknown = 0, unentitled = 1, callUUIDAlreadyExists = 2, filteredByDoNotDisturb = 3, filteredByBlockList = 4, filteredDuringRestrictedSharingMode = 5, callIsProtected = 6 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CXErrorDomainIncomingCall }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (\(CXErrorDomainIncomingCall) error \(code.rawValue).)" }
    public static var unknown: Code { .unknown }
    public static var unentitled: Code { .unentitled }
    public static var callUUIDAlreadyExists: Code { .callUUIDAlreadyExists }
    public static var filteredByDoNotDisturb: Code { .filteredByDoNotDisturb }
    public static var filteredByBlockList: Code { .filteredByBlockList }
}
public struct CXErrorCodeRequestTransactionError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknown = 0, unentitled = 1, unknownCallProvider = 2, emptyTransaction = 3, unknownCallUUID = 4, callUUIDAlreadyExists = 5, invalidAction = 6, maximumCallGroupsReached = 7, callIsProtected = 8 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CXErrorDomainRequestTransaction }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (\(CXErrorDomainRequestTransaction) error \(code.rawValue).)" }
    public static var unknown: Code { .unknown }
    public static var unknownCallProvider: Code { .unknownCallProvider }
    public static var emptyTransaction: Code { .emptyTransaction }
    public static var unknownCallUUID: Code { .unknownCallUUID }
    public static var callUUIDAlreadyExists: Code { .callUUIDAlreadyExists }
    public static var invalidAction: Code { .invalidAction }
    public static var maximumCallGroupsReached: Code { .maximumCallGroupsReached }
}
public struct CXErrorCodeCallDirectoryManagerError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable { case unknown = 0, noExtensionFound = 1, loadingInterrupted = 2, entriesOutOfOrder = 3, duplicateEntries = 4, maximumEntriesExceeded = 5, extensionDisabled = 6, currentlyLoading = 7, unexpectedIncrementalRemoval = 8 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { CXErrorDomainCallDirectoryManager }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public var errorDescription: String? { "The operation couldn’t be completed. (\(CXErrorDomainCallDirectoryManager) error \(code.rawValue).)" }
    public static var noExtensionFound: Code { .noExtensionFound }
    public static var extensionDisabled: Code { .extensionDisabled }
}
public func ~= (code: CXErrorCodeIncomingCallError.Code, error: Error) -> Bool { (error as? CXErrorCodeIncomingCallError)?.code == code }
public func ~= (code: CXErrorCodeRequestTransactionError.Code, error: Error) -> Bool { (error as? CXErrorCodeRequestTransactionError)?.code == code }
public func ~= (code: CXErrorCodeCallDirectoryManagerError.Code, error: Error) -> Bool { (error as? CXErrorCodeCallDirectoryManagerError)?.code == code }

// MARK: - handles, updates, configuration

@objc(CXHandle) open class CXHandle: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc public enum HandleType: Int, Sendable { case generic = 1, phoneNumber = 2, emailAddress = 3 }
    open private(set) var type: HandleType
    open private(set) var value: String
    public init(type: HandleType, value: String) { self.type = type; self.value = value }
    open func isEqual(to handle: CXHandle) -> Bool { type == handle.type && value == handle.value }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CXHandle).map(isEqual(to:)) ?? false }
    open override var hash: Int { value.hashValue ^ type.rawValue }
    open func copy(with zone: NSZone? = nil) -> Any { CXHandle(type: type, value: value) }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) { coder.encode(type.rawValue, forKey: "type"); coder.encode(value as NSString, forKey: "value") }
    public required init?(coder: NSCoder) {
        type = HandleType(rawValue: coder.decodeInteger(forKey: "type")) ?? .generic
        value = (coder.decodeObject(forKey: "value") as? String) ?? ""
    }
    open override var description: String { "<CXHandle type=\(type.rawValue) value=\(value)>" }
}

@objc(CXCallUpdate) open class CXCallUpdate: NSObject, NSCopying, @unchecked Sendable {
    open var remoteHandle: CXHandle?
    open var localizedCallerName: String?
    open var supportsHolding = false
    open var supportsGrouping = false
    open var supportsUngrouping = false
    open var supportsDTMF = false
    open var hasVideo = false
    public override init() {}
    open func copy(with zone: NSZone? = nil) -> Any {
        let u = CXCallUpdate()
        u.remoteHandle = remoteHandle; u.localizedCallerName = localizedCallerName; u.supportsHolding = supportsHolding
        u.supportsGrouping = supportsGrouping; u.supportsUngrouping = supportsUngrouping; u.supportsDTMF = supportsDTMF; u.hasVideo = hasVideo
        return u
    }
}

@objc(CXProviderConfiguration) open class CXProviderConfiguration: NSObject, NSCopying, @unchecked Sendable {
    open var localizedName: String?
    open var ringtoneSound: String?
    open var iconTemplateImageData: Data?
    open var maximumCallGroups = 2
    open var maximumCallsPerCallGroup = 5
    open var includesCallsInRecents = true
    open var supportsVideo = false
    open var supportedHandleTypes: Set<CXHandle.HandleType> = []
    /// iOS 26: the call UI offers Live Translation (CXSetTranslatingCallAction)
    @available(iOS 26.0, *)
    open var supportsAudioTranslation: Bool { get { _supportsAudioTranslation } set { _supportsAudioTranslation = newValue } }
    var _supportsAudioTranslation = false
    public override init() { localizedName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String }
    @available(*, deprecated, message: "use init() (the name is the app's)")
    public init(localizedName: String) { self.localizedName = localizedName }
    open func copy(with zone: NSZone? = nil) -> Any {
        let c = CXProviderConfiguration()
        c.localizedName = localizedName; c.ringtoneSound = ringtoneSound; c.iconTemplateImageData = iconTemplateImageData
        c.maximumCallGroups = maximumCallGroups; c.maximumCallsPerCallGroup = maximumCallsPerCallGroup
        c.includesCallsInRecents = includesCallsInRecents; c.supportsVideo = supportsVideo; c.supportedHandleTypes = supportedHandleTypes
        c._supportsAudioTranslation = _supportsAudioTranslation
        return c
    }
}

@objc public enum CXCallEndedReason: Int, Sendable { case failed = 1, remoteEnded = 2, unanswered = 3, answeredElsewhere = 4, declinedElsewhere = 5 }

// MARK: - actions

@objc(CXAction) open class CXAction: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    open private(set) var uuid = UUID()
    open private(set) var isComplete = false
    open private(set) var timeoutDate = Date(timeIntervalSinceNow: 30)
    weak var _provider: CXProvider?
    public override init() {}
    open func fulfill() { finish(true) }
    open func fail() { finish(false) }
    func finish(_ ok: Bool) {
        if isComplete { NSLog("isim: CallKit: %@ was already completed", String(describing: type(of: self))); return }
        isComplete = true
        _CallKit.completed(self, ok: ok)
    }
    open func copy(with zone: NSZone? = nil) -> Any { self }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with coder: NSCoder) {}
    public required init?(coder: NSCoder) {}
    var _name: String { "action" }
}
@objc(CXCallAction) open class CXCallAction: CXAction, @unchecked Sendable {
    open private(set) var callUUID: UUID
    public init(call callUUID: UUID) { self.callUUID = callUUID; super.init() }
    public required init?(coder: NSCoder) { callUUID = UUID() ; super.init(coder: coder) }
}
@objc(CXStartCallAction) open class CXStartCallAction: CXCallAction, @unchecked Sendable {
    open var handle: CXHandle
    open var contactIdentifier: String?
    open var isVideo = false
    public init(call callUUID: UUID, handle: CXHandle) { self.handle = handle; super.init(call: callUUID) }
    public required init?(coder: NSCoder) { handle = CXHandle(type: .generic, value: ""); super.init(coder: coder) }
    open func fulfill(withDateStarted dateStarted: Date) { fulfill() }
    override var _name: String { "start" }
}
@objc(CXAnswerCallAction) open class CXAnswerCallAction: CXCallAction, @unchecked Sendable {
    public override init(call callUUID: UUID) { super.init(call: callUUID) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open func fulfill(withDateConnected dateConnected: Date) { fulfill() }
    override var _name: String { "answer" }
}
@objc(CXEndCallAction) open class CXEndCallAction: CXCallAction, @unchecked Sendable {
    public override init(call callUUID: UUID) { super.init(call: callUUID) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    open func fulfill(withDateEnded dateEnded: Date) { fulfill() }
    override var _name: String { "end" }
}
@objc(CXSetHeldCallAction) open class CXSetHeldCallAction: CXCallAction, @unchecked Sendable {
    open var isOnHold: Bool
    public init(call callUUID: UUID, onHold: Bool) { isOnHold = onHold; super.init(call: callUUID) }
    public required init?(coder: NSCoder) { isOnHold = false; super.init(coder: coder) }
    override var _name: String { isOnHold ? "hold" : "unhold" }
}
@objc(CXSetMutedCallAction) open class CXSetMutedCallAction: CXCallAction, @unchecked Sendable {
    open var isMuted: Bool
    public init(call callUUID: UUID, muted: Bool) { isMuted = muted; super.init(call: callUUID) }
    public required init?(coder: NSCoder) { isMuted = false; super.init(coder: coder) }
    override var _name: String { isMuted ? "mute" : "unmute" }
}
@objc(CXSetGroupCallAction) open class CXSetGroupCallAction: CXCallAction, @unchecked Sendable {
    open var callUUIDToGroupWith: UUID?
    public init(call callUUID: UUID, callUUIDToGroupWith: UUID?) { self.callUUIDToGroupWith = callUUIDToGroupWith; super.init(call: callUUID) }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    override var _name: String { "group" }
}
@objc(CXPlayDTMFCallAction) open class CXPlayDTMFCallAction: CXCallAction, @unchecked Sendable {
    @objc public enum ActionType: Int, Sendable { case singleTone = 1, softPause = 2, hardPause = 3 }
    open var digits: String
    open var type: ActionType
    public init(call callUUID: UUID, digits: String, type: ActionType) { self.digits = digits; self.type = type; super.init(call: callUUID) }
    public required init?(coder: NSCoder) { digits = ""; type = .singleTone; super.init(coder: coder) }
    override var _name: String { "dtmf \(digits)" }
}

/// iOS 26: which engine translated a call
@available(iOS 26.0, *)
@objc public enum CXTranslationEngine: Int, Sendable { case `default` = 0, custom = 1 }

/// iOS 26: start or stop translating a call (Live Translation), between the local person's language and the remote one's
@available(iOS 26.0, *)
@objc(CXSetTranslatingCallAction) open class CXSetTranslatingCallAction: CXCallAction, @unchecked Sendable {
    open private(set) var isTranslating: Bool
    open private(set) var localLanguage: String
    open private(set) var remoteLanguage: String
    var _engine: CXTranslationEngine?
    public init(call callUUID: UUID, isTranslating: Bool, localLanguage: String, remoteLanguage: String) {
        self.isTranslating = isTranslating; self.localLanguage = localLanguage; self.remoteLanguage = remoteLanguage
        super.init(call: callUUID)
    }
    public convenience init(callUUID: UUID, isTranslating: Bool, localLanguage: String, remoteLanguage: String) {
        self.init(call: callUUID, isTranslating: isTranslating, localLanguage: localLanguage, remoteLanguage: remoteLanguage)
    }
    public required init?(coder: NSCoder) { isTranslating = false; localLanguage = ""; remoteLanguage = ""; super.init(coder: coder) }
    /// completes the action, saying which engine translates
    open func fulfill(using translationEngine: CXTranslationEngine) { _engine = translationEngine; fulfill() }
    override var _name: String { isTranslating ? "translate \(localLanguage)-\(remoteLanguage)" : "stop translating" }
}

@objc(CXTransaction) open class CXTransaction: NSObject, NSCopying, @unchecked Sendable {
    open private(set) var uuid = UUID()
    open var isComplete: Bool { actions.allSatisfy { $0.isComplete } }
    open private(set) var actions: [CXAction]
    public init(actions: [CXAction]) { self.actions = actions }
    public convenience init(action: CXAction) { self.init(actions: [action]) }
    open func addAction(_ action: CXAction) { actions.append(action) }
    open func copy(with zone: NSZone? = nil) -> Any { self }
}

// MARK: - calls and the observer

@objc(CXCall) open class CXCall: NSObject, @unchecked Sendable {
    open private(set) var uuid: UUID
    open internal(set) var isOutgoing: Bool
    open internal(set) var isOnHold = false
    open internal(set) var hasConnected = false
    open internal(set) var hasEnded = false
    var update = CXCallUpdate()
    var muted = false
    var _translation: (String, String)?                     /* Live Translation: the local and remote languages */
    var announced = false                   /* the shell knows it */
    init(uuid: UUID, outgoing: Bool) { self.uuid = uuid; isOutgoing = outgoing }
    open func isEqual(to call: CXCall) -> Bool { uuid == call.uuid }
    open override func isEqual(_ object: Any?) -> Bool { (object as? CXCall).map(isEqual(to:)) ?? false }
    open override var hash: Int { uuid.hashValue }
    func snapshot() -> CXCall {
        let c = CXCall(uuid: uuid, outgoing: isOutgoing)
        c.isOnHold = isOnHold; c.hasConnected = hasConnected; c.hasEnded = hasEnded
        return c
    }
}

@objc public protocol CXCallObserverDelegate: NSObjectProtocol {
    @objc(callObserver:callChanged:) func callObserver(_ callObserver: CXCallObserver, callChanged call: CXCall)
}
@objc(CXCallObserver) open class CXCallObserver: NSObject, @unchecked Sendable {
    weak var delegate: CXCallObserverDelegate?
    var queue: DispatchQueue = .main
    public override init() { super.init(); _CallKit.observers.append(_CallKit.WeakObserver(o: self)) }
    open var calls: [CXCall] { _CallKit.calls.values.filter { !$0.hasEnded }.map { $0.snapshot() } }
    open func setDelegate(_ delegate: CXCallObserverDelegate?, queue: DispatchQueue?) { self.delegate = delegate; self.queue = queue ?? .main }
}

// MARK: - the provider

@objc public protocol CXProviderDelegate: NSObjectProtocol {
    @objc(providerDidReset:) func providerDidReset(_ provider: CXProvider)
    @objc(providerDidBegin:) optional func providerDidBegin(_ provider: CXProvider)
    @objc(provider:executeTransaction:) optional func provider(_ provider: CXProvider, execute transaction: CXTransaction) -> Bool
    @objc(provider:performStartCallAction:) optional func provider(_ provider: CXProvider, perform action: CXStartCallAction)
    @objc(provider:performAnswerCallAction:) optional func provider(_ provider: CXProvider, perform action: CXAnswerCallAction)
    @objc(provider:performEndCallAction:) optional func provider(_ provider: CXProvider, perform action: CXEndCallAction)
    @objc(provider:performSetHeldCallAction:) optional func provider(_ provider: CXProvider, perform action: CXSetHeldCallAction)
    @objc(provider:performSetMutedCallAction:) optional func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction)
    @objc(provider:performSetGroupCallAction:) optional func provider(_ provider: CXProvider, perform action: CXSetGroupCallAction)
    @objc(provider:performPlayDTMFCallAction:) optional func provider(_ provider: CXProvider, perform action: CXPlayDTMFCallAction)
    @available(iOS 26.0, *)
    @objc(provider:performSetTranslatingCallAction:) optional func provider(_ provider: CXProvider, perform action: CXSetTranslatingCallAction)
    @objc(provider:timedOutPerformingAction:) optional func provider(_ provider: CXProvider, timedOutPerforming action: CXAction)
    @objc(provider:didActivateAudioSession:) optional func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession)
    @objc(provider:didDeactivateAudioSession:) optional func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession)
}

@objc(CXProvider) open class CXProvider: NSObject, @unchecked Sendable {
    open var configuration: CXProviderConfiguration
    weak var delegate: CXProviderDelegate?
    var queue: DispatchQueue = .main
    var invalidated = false
    public init(configuration: CXProviderConfiguration) {
        self.configuration = configuration
        super.init()
        _CallKit.start()
        _CallKit.provider = self
    }
    open func setDelegate(_ delegate: CXProviderDelegate?, queue: DispatchQueue?) {
        self.delegate = delegate; self.queue = queue ?? .main
        queue_async { [weak self] in guard let self else { return }; self.delegate?.providerDidBegin?(self) }
    }
    func queue_async(_ f: @escaping () -> Void) { queue.async(execute: f) }

    open func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate, completion: @escaping (Error?) -> Void) {
        if invalidated { queue_async { completion(CXErrorCodeIncomingCallError(.unknown)) }; return }
        if let c = _CallKit.calls[UUID], !c.hasEnded {
            NSLog("isim: CallKit: an incoming call %@ already exists", UUID.uuidString)
            queue_async { completion(CXErrorCodeIncomingCallError(.callUUIDAlreadyExists)) }
            return
        }
        let call = CXCall(uuid: UUID, outgoing: false)
        call.update = update.copy() as! CXCallUpdate
        _CallKit.calls[UUID] = call
        NotificationCenter.default.post(name: Notification.Name("_IsimCallKitIncomingReported"), object: UUID.uuidString)
        NSLog("isim: CallKit: incoming call %@ from %@%@", UUID.uuidString, _CallKit.callerName(call.update), update.hasVideo ? " (video)" : "")
        _CallKit.tell("call-incoming", call, extra: _CallKit.ringtone(configuration))
        call.announced = true
        _CallKit.changed(call)
        queue_async { completion(nil) }
    }
    public func reportNewIncomingCall(with UUID: UUID, update: CXCallUpdate) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            reportNewIncomingCall(with: UUID, update: update) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func reportCall(with UUID: UUID, updated update: CXCallUpdate) {
        guard let call = _CallKit.calls[UUID], !call.hasEnded else { NSLog("isim: CallKit: reportCall(with:updated:) for an unknown call %@", UUID.uuidString); return }
        let u = call.update
        if let h = update.remoteHandle { u.remoteHandle = h }
        if let n = update.localizedCallerName { u.localizedCallerName = n }
        u.supportsHolding = update.supportsHolding; u.supportsGrouping = update.supportsGrouping; u.supportsUngrouping = update.supportsUngrouping
        u.supportsDTMF = update.supportsDTMF; u.hasVideo = update.hasVideo
        NSLog("isim: CallKit: call %@ updated (%@)", UUID.uuidString, _CallKit.callerName(u))
        if call.announced { _CallKit.tell("call-update", call) }
    }
    open func reportCall(with UUID: UUID, endedAt dateEnded: Date?, reason endedReason: CXCallEndedReason) {
        guard let call = _CallKit.calls[UUID], !call.hasEnded else { NSLog("isim: CallKit: reportCall(with:endedAt:reason:) for an unknown call %@", UUID.uuidString); return }
        let why = ["", "failed", "remoteEnded", "unanswered", "answeredElsewhere", "declinedElsewhere"][endedReason.rawValue]
        NSLog("isim: CallKit: call %@ ended (%@)", UUID.uuidString, why)
        _CallKit.end(call, reason: why)
    }
    open func reportOutgoingCall(with UUID: UUID, startedConnectingAt dateStartedConnecting: Date?) {
        guard let call = _CallKit.calls[UUID], !call.hasEnded else { return }
        NSLog("isim: CallKit: outgoing call %@ connecting", UUID.uuidString)
        _CallKit.state(call, "connecting")
    }
    open func reportOutgoingCall(with UUID: UUID, connectedAt dateConnected: Date?) {
        guard let call = _CallKit.calls[UUID], !call.hasEnded else { return }
        NSLog("isim: CallKit: outgoing call %@ connected", UUID.uuidString)
        call.hasConnected = true
        _CallKit.state(call, "connected")
        _CallKit.changed(call)
    }
    open func invalidate() {
        invalidated = true
        for c in _CallKit.calls.values where !c.hasEnded { _CallKit.end(c, reason: "failed") }
        if _CallKit.provider === self { _CallKit.provider = nil }
        NSLog("isim: CallKit: provider invalidated")
    }
    open var pendingTransactions: [CXTransaction] { [] }
    open func pendingCallActions<T: CXCallAction>(of callActionClass: T.Type, withCall callUUID: UUID) -> [T] {
        _CallKit.pending.compactMap { $0 as? T }.filter { $0.callUUID == callUUID && !$0.isComplete }
    }

    /// gives an action to the delegate (on its queue); actions it does not handle fail
    func perform(_ action: CXAction) {
        action._provider = self
        _CallKit.pending.append(action)
        queue_async { [weak self] in
            guard let self, let d = self.delegate else { action.fail(); return }
            var handled: Void?
            switch action {
            case let a as CXStartCallAction: handled = d.provider?(self, perform: a)
            case let a as CXAnswerCallAction: handled = d.provider?(self, perform: a)
            case let a as CXEndCallAction: handled = d.provider?(self, perform: a)
            case let a as CXSetHeldCallAction: handled = d.provider?(self, perform: a)
            case let a as CXSetMutedCallAction: handled = d.provider?(self, perform: a)
            case let a as CXSetGroupCallAction: handled = d.provider?(self, perform: a)
            case let a as CXPlayDTMFCallAction: handled = d.provider?(self, perform: a)
            default:
                if #available(iOS 26.0, *), let a = action as? CXSetTranslatingCallAction { handled = d.provider?(self, perform: a) }
            }
            if handled == nil {
                NSLog("isim: CallKit: the provider's delegate does not handle %@", String(describing: type(of: action)))
                action.fail()
            }
        }
    }
    /// a transaction from the system or a call controller: provider(_:execute:) first
    func execute(_ t: CXTransaction) {
        queue_async { [weak self] in
            guard let self else { return }
            if self.delegate?.provider?(self, execute: t) == true { return }
            for a in t.actions { self.perform(a) }
        }
    }
}

// MARK: - the call controller

@objc(CXCallController) open class CXCallController: NSObject, @unchecked Sendable {
    let queue: DispatchQueue
    open private(set) var callObserver = CXCallObserver()
    public override init() { queue = .main; super.init() }
    public init(queue: DispatchQueue) { self.queue = queue; super.init() }
    open func request(_ transaction: CXTransaction, completion: @escaping (Error?) -> Void) {
        if let e = _CallKit.check(transaction) {
            NSLog("isim: CallKit: transaction refused (%@ error %ld)", CXErrorDomainRequestTransaction, e.code.rawValue)
            queue.async { completion(e) }
            return
        }
        NSLog("isim: CallKit: transaction %@", transaction.actions.map { $0._name }.joined(separator: ", "))
        queue.async { completion(nil) }
        _CallKit.provider?.execute(transaction)
    }
    public func request(_ transaction: CXTransaction) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            request(transaction) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func requestTransaction(with actions: [CXAction], completion: @escaping (Error?) -> Void) { request(CXTransaction(actions: actions), completion: completion) }
    open func requestTransaction(with action: CXAction, completion: @escaping (Error?) -> Void) { request(CXTransaction(action: action), completion: completion) }
    public func requestTransaction(with actions: [CXAction]) async throws { try await request(CXTransaction(actions: actions)) }
    public func requestTransaction(with action: CXAction) async throws { try await request(CXTransaction(action: action)) }
}

// MARK: - Call Directory (stub)

@objc(CXCallDirectoryManager) open class CXCallDirectoryManager: NSObject, @unchecked Sendable {
    @objc public enum EnabledStatus: Int, Sendable { case unknown = 0, disabled = 1, enabled = 2 }
    public static let sharedInstance = CXCallDirectoryManager()
    func find(_ identifier: String) -> Bool {
        let plugins = (Bundle.main.bundlePath as NSString).appendingPathComponent("PlugIns")
        for name in (try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? [] where name.hasSuffix(".appex") {
            let b = Bundle(path: (plugins as NSString).appendingPathComponent(name))
            let point = (b?.object(forInfoDictionaryKey: "NSExtension") as? [String: Any])?["NSExtensionPointIdentifier"] as? String
            if b?.bundleIdentifier == identifier && point == "com.apple.callkit.call-directory" { return true }
        }
        return false
    }
    /// isim never runs Call Directory extensions: like iOS before the user turns one on in Settings, it is disabled
    open func reloadExtension(withIdentifier identifier: String, completionHandler completion: ((Error?) -> Void)? = nil) {
        let e = CXErrorCodeCallDirectoryManagerError(find(identifier) ? .extensionDisabled : .noExtensionFound)
        NSLog("isim: CallKit: Call Directory extension %@ not loaded (%@)", identifier, find(identifier) ? "isim does not run Call Directory extensions" : "no such extension")
        DispatchQueue.main.async { completion?(e) }
    }
    public func reloadExtension(withIdentifier identifier: String) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            reloadExtension(withIdentifier: identifier) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    open func getEnabledStatusForExtension(withIdentifier identifier: String, completionHandler completion: @escaping (EnabledStatus, Error?) -> Void) {
        let found = find(identifier)
        DispatchQueue.main.async { completion(found ? .disabled : .unknown, found ? nil : CXErrorCodeCallDirectoryManagerError(.noExtensionFound)) }
    }
    public func enabledStatusForExtension(withIdentifier identifier: String) async throws -> EnabledStatus {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<EnabledStatus, Error>) in
            getEnabledStatusForExtension(withIdentifier: identifier) { s, e in if let e { k.resume(throwing: e) } else { k.resume(returning: s) } }
        }
    }
    open func openSettings(completionHandler completion: ((Error?) -> Void)? = nil) {
        NSLog("isim: CallKit: Settings > Apps > Phone > Call Blocking & Identification is not on isim")
        DispatchQueue.main.async { completion?(nil) }
    }
}
public typealias CXCallDirectoryPhoneNumber = Int64
@objc(CXCallDirectoryExtensionContext) open class CXCallDirectoryExtensionContext: NSExtensionContext, @unchecked Sendable {
    weak open var delegate: CXCallDirectoryExtensionContextDelegate?
    open var isIncremental: Bool { false }
    open func addBlockingEntry(withNextSequentialPhoneNumber phoneNumber: CXCallDirectoryPhoneNumber) {}
    open func removeBlockingEntry(withPhoneNumber phoneNumber: CXCallDirectoryPhoneNumber) {}
    open func removeAllBlockingEntries() {}
    open func addIdentificationEntry(withNextSequentialPhoneNumber phoneNumber: CXCallDirectoryPhoneNumber, label: String) {}
    open func removeIdentificationEntry(withPhoneNumber phoneNumber: CXCallDirectoryPhoneNumber) {}
    open func removeAllIdentificationEntries() {}
    open func completeRequest(completionHandler completion: ((Bool) -> Void)? = nil) { completion?(true) }
}
@objc public protocol CXCallDirectoryExtensionContextDelegate: NSObjectProtocol {
    @objc(requestFailedForExtensionContext:withError:) func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error)
}
@objc(CXCallDirectoryProvider) open class CXCallDirectoryProvider: NSObject, NSExtensionRequestHandling {
    public override init() {}
    open func beginRequest(with context: NSExtensionContext) {}
}

// MARK: - the device side

enum _CallKit {
    nonisolated(unsafe) static weak var provider: CXProvider?
    nonisolated(unsafe) static var calls: [UUID: CXCall] = [:]
    nonisolated(unsafe) static var pending: [CXAction] = []
    nonisolated(unsafe) static var observers: [WeakObserver] = []
    nonisolated(unsafe) static var started = false
    nonisolated(unsafe) static var audioActive = false
    struct WeakObserver { weak var o: CXCallObserver? }

    static func start() {
        guard !started else { return }
        started = true
        /* UIKit asks what keeps the app running in the background: a call */
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimBackgroundQuery"), object: nil, queue: nil) { n in
            if let q = n.object as? NSMutableDictionary, calls.values.contains(where: { !$0.hasEnded }) { q.setObject(true, forKey: "call" as NSString) }
        }
        NotificationCenter.default.addObserver(forName: Notification.Name("_IsimSystemEvent"), object: nil, queue: .main) { n in
            guard let t = n.object as? String, t.hasPrefix("call-action ") else { return }
            systemAction(String(t.dropFirst(12)))
        }
    }
    static func callerName(_ u: CXCallUpdate) -> String { u.localizedCallerName ?? u.remoteHandle?.value ?? "Unknown" }
    static func ringtone(_ c: CXProviderConfiguration) -> String {
        guard let name = c.ringtoneSound, !name.isEmpty else { return "" }
        if let p = Bundle.main.path(forResource: name, ofType: nil) { return p }
        let lib = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first ?? ""
        let p = ((lib as NSString).appendingPathComponent("Sounds") as NSString).appendingPathComponent(name)
        return FileManager.default.fileExists(atPath: p) ? p : ""
    }
    /// call-incoming / call-update / call-outgoing: b = UUID, c = caller\x1fhandle\x1fvideo\x1fringtone\x1fcapabilities\x1fapp name
    static func tell(_ verb: String, _ call: CXCall, extra: String = "") {
        let u = call.update, conf = provider?.configuration
        var caps = ""
        if u.supportsHolding { caps += "h" }
        if u.supportsGrouping { caps += "g" }
        if u.supportsDTMF { caps += "d" }
        if conf?.supportsVideo == true { caps += "v" }
        if conf?._supportsAudioTranslation == true { caps += "t" }
        let clean = { (s: String) in s.replacingOccurrences(of: "\u{1f}", with: " ").replacingOccurrences(of: "\n", with: " ") }
        let c = [clean(callerName(u)), clean(u.remoteHandle?.value ?? ""), u.hasVideo ? "1" : "0", extra, caps, clean(conf?.localizedName ?? "")].joined(separator: "\u{1f}")
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), verb, call.uuid.uuidString, c)
    }
    static func state(_ call: CXCall, _ s: String) { isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "call-state", call.uuid.uuidString, s) }
    static func end(_ call: CXCall, reason: String) {
        call.hasEnded = true
        isim_shell_request(Int32(ISIM_SHELL_SYSTEM), "call-end", call.uuid.uuidString, reason)
        changed(call)
        calls[call.uuid] = nil
        if audioActive && !calls.values.contains(where: { !$0.hasEnded && $0.hasConnected }) { setAudio(false) }
    }
    static func changed(_ call: CXCall) {
        let snap = call.snapshot()
        observers.removeAll { $0.o == nil }
        for w in observers { if let o = w.o, let d = o.delegate { o.queue.async { d.callObserver(o, callChanged: snap) } } }
    }
    static func setAudio(_ on: Bool) {
        guard on != audioActive, let p = provider else { return }
        audioActive = on
        let session = AVAudioSession.sharedInstance()
        NSLog("isim: CallKit: audio session %@", on ? "activated" : "deactivated")
        p.queue_async {
            if on { p.delegate?.provider?(p, didActivate: session) } else { p.delegate?.provider?(p, didDeactivate: session) }
        }
    }

    /// what a controller may ask for (iOS's checks)
    static func check(_ t: CXTransaction) -> CXErrorCodeRequestTransactionError? {
        if t.actions.isEmpty { return CXErrorCodeRequestTransactionError(.emptyTransaction) }
        guard let p = provider, !p.invalidated else { return CXErrorCodeRequestTransactionError(.unknownCallProvider) }
        for a in t.actions {
            guard let ca = a as? CXCallAction else { return CXErrorCodeRequestTransactionError(.invalidAction) }
            let existing = calls[ca.callUUID].flatMap { $0.hasEnded ? nil : $0 }
            if a is CXStartCallAction {
                if existing != nil { return CXErrorCodeRequestTransactionError(.callUUIDAlreadyExists) }
                let live = calls.values.filter { !$0.hasEnded }.count
                if live >= p.configuration.maximumCallGroups { return CXErrorCodeRequestTransactionError(.maximumCallGroupsReached) }
            } else if existing == nil { return CXErrorCodeRequestTransactionError(.unknownCallUUID) }
            if a is CXAnswerCallAction, let c = existing, c.isOutgoing || c.hasConnected { return CXErrorCodeRequestTransactionError(.invalidAction) }
            if #available(iOS 26.0, *), a is CXSetTranslatingCallAction, !p.configuration._supportsAudioTranslation {
                NSLog("isim: CallKit: translating a call needs CXProviderConfiguration.supportsAudioTranslation")
                return CXErrorCodeRequestTransactionError(.invalidAction)
            }
        }
        return nil
    }

    /// an action the delegate completed: what it does to the call
    static func completed(_ a: CXAction, ok: Bool) {
        pending.removeAll { $0 === a }
        guard let ca = a as? CXCallAction else { return }
        NSLog("isim: CallKit: %@ %@ %@", ca._name, ca.callUUID.uuidString, ok ? "fulfilled" : "failed")
        let call = calls[ca.callUUID]
        switch a {
        case let s as CXStartCallAction:
            guard ok else { return }
            let c = CXCall(uuid: s.callUUID, outgoing: true)
            let u = CXCallUpdate(); u.remoteHandle = s.handle; u.hasVideo = s.isVideo
            c.update = u
            calls[s.callUUID] = c
            tell("call-outgoing", c)
            c.announced = true
            changed(c)
            setAudio(true)
        case is CXAnswerCallAction:
            guard let c = call else { return }
            if !ok { end(c, reason: "failed"); return }
            c.hasConnected = true
            state(c, "connected")
            changed(c)
            setAudio(true)
        case is CXEndCallAction:
            guard let c = call else { return }
            end(c, reason: ok ? "ended" : "failed")
        case let h as CXSetHeldCallAction:
            guard ok, let c = call else { return }
            c.isOnHold = h.isOnHold
            state(c, h.isOnHold ? "held" : "unheld")
            changed(c)
        case let m as CXSetMutedCallAction:
            guard ok, let c = call else { return }
            c.muted = m.isMuted
            state(c, m.isMuted ? "muted" : "unmuted")
        default:
            if #available(iOS 26.0, *), let t = a as? CXSetTranslatingCallAction, ok, let c = call {
                c._translation = t.isTranslating ? (t.localLanguage, t.remoteLanguage) : nil
                if t.isTranslating { NSLog("isim: CallKit: translating call %@ (%@ and %@, %@ engine)", c.uuid.uuidString, t.localLanguage, t.remoteLanguage, t._engine == .custom ? "custom" : "default") }
                state(c, t.isTranslating ? "translating \(t.localLanguage) \(t.remoteLanguage)" : "translation-off")
            }
        }
    }

    /// "call-action answer|end|mute|hold|dtmf|speaker UUID [ARG]": what the user did in the call UI
    static func systemAction(_ s: String) {
        let p = s.split(separator: " ", maxSplits: 2).map(String.init)
        guard p.count >= 2, let uuid = UUID(uuidString: p[1]) else { return }
        let arg = p.count > 2 ? p[2] : ""
        if p[0] == "speaker" {
            NSLog("isim: CallKit: audio route %@", arg == "1" ? "speaker" : "receiver")
            if arg == "1" { try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.speaker) }
            else { try? AVAudioSession.sharedInstance().overrideOutputAudioPort(.none) }
            return
        }
        guard let provider, calls[uuid] != nil else { NSLog("isim: CallKit: %@ for an unknown call %@", p[0], p[1]); return }
        let action: CXAction
        switch p[0] {
        case "answer": action = CXAnswerCallAction(call: uuid)
        case "end": action = CXEndCallAction(call: uuid)
        case "mute": action = CXSetMutedCallAction(call: uuid, muted: arg == "1")
        case "hold": action = CXSetHeldCallAction(call: uuid, onHold: arg == "1")
        case "dtmf": action = CXPlayDTMFCallAction(call: uuid, digits: arg, type: .singleTone)
        case "translate":
            guard #available(iOS 26.0, *) else { return }
            /* the person's language, and the other's: isim's default is Spanish (iOS asks); "1 LANG" names it */
            let words = arg.split(separator: " ").map(String.init)
            let local = Locale.current.language.languageCode?.identifier ?? "en"
            let remote = words.count > 1 ? words[1] : (calls[uuid]?._translation?.1 ?? (local == "es" ? "en" : "es"))
            action = CXSetTranslatingCallAction(call: uuid, isTranslating: words.first == "1", localLanguage: local, remoteLanguage: remote)
        default: return
        }
        NSLog("isim: CallKit: the user chose %@ for call %@", (action as? CXCallAction)?._name ?? p[0], p[1])
        provider.execute(CXTransaction(action: action))
    }
}
