// iOS 18: LADomainState (LAContext.domainState) and LAEnvironment (the device's authentication mechanisms and their
// state, with observers). Adapted: isim's device has Face ID or Touch ID (LocalAuthentication.swift), a passcode, and no
// companion devices (no Apple Watch, Mac or Vision Pro pairing). The state hashes change with the enrollment.
// Also the C constants (kLA…), and `biometry` script answers for a scan on screen.
import Foundation
import UIKit

@available(iOS 18.0, *)
@objc public enum LACompanionType: Int, Sendable {
    case watch = 1, mac = 2, vision = 4
}

// MARK: - LADomainState

@available(iOS 18.0, *)
@objc(LADomainStateBiometry) open class LADomainStateBiometry: NSObject, @unchecked Sendable {
    public let biometryType: LABiometryType
    public let stateHash: Data?
    init(_ type: LABiometryType, _ hash: Data?) { biometryType = type; stateHash = hash }
}

@available(iOS 18.0, *)
@objc(LADomainStateCompanion) open class LADomainStateCompanion: NSObject, @unchecked Sendable {
    /// no companions pair with isim's device
    public let availableCompanionTypes: Set<LACompanionType> = []
    public let stateHash: Data? = nil
    open func stateHash(for companionType: LACompanionType) -> Data? { nil }
}

@available(iOS 18.0, *)
@objc(LADomainState) open class LADomainState: NSObject, @unchecked Sendable {
    public let biometry: LADomainStateBiometry
    public let companion = LADomainStateCompanion()
    public let stateHash: Data?
    init(checked: Bool) {
        let hash = checked && _LADevice.enrolled ? _LADevice.enrollmentData : nil
        biometry = LADomainStateBiometry(checked ? _LADevice.biometry : .none, hash)
        stateHash = hash
    }
}

// MARK: - LAEnvironment

@available(iOS 18.0, *)
@objc(LAEnvironment) open class LAEnvironment: NSObject, @unchecked Sendable {
    @objc(LAEnvironmentObserver) public protocol Observer: NSObjectProtocol {
        @objc(environment:stateDidChangeFromOldState:) optional func environment(_ environment: LAEnvironment, stateDidChangeFromOldState oldState: LAEnvironment.State)
    }

    @objc(LAEnvironmentMechanism) open class Mechanism: NSObject, @unchecked Sendable {
        public let isUsable: Bool
        public let localizedName: String
        public let iconSystemName: String
        init(usable: Bool, name: String, icon: String) { isUsable = usable; localizedName = name; iconSystemName = icon }
    }
    @objc(LAEnvironmentMechanismBiometry) open class MechanismBiometry: Mechanism, @unchecked Sendable {
        public let biometryType: LABiometryType
        public let isEnrolled: Bool
        public let isLockedOut: Bool
        public let stateHash: Data
        public let builtInSensorInaccessible = false
        init() {
            biometryType = _LADevice.biometry
            isEnrolled = _LADevice.enrolled
            isLockedOut = _LADevice.lockedOut
            stateHash = isEnrolled ? _LADevice.enrollmentData : Data()
            let face = biometryType == .faceID
            super.init(usable: isEnrolled && !isLockedOut, name: face ? "Face ID" : "Touch ID", icon: face ? "faceid" : "touchid")
        }
    }
    @objc(LAEnvironmentMechanismUserPassword) open class MechanismUserPassword: Mechanism, @unchecked Sendable {
        /// isim's simulated device always has a passcode
        public let isSet = true
        init() { super.init(usable: true, name: UIDevice.current.userInterfaceIdiom == .pad ? "iPad Passcode" : "iPhone Passcode", icon: "lock") }
    }
    @objc(LAEnvironmentMechanismCompanion) open class MechanismCompanion: Mechanism, @unchecked Sendable {
        public let type: LACompanionType
        public let stateHash: Data?
        init(type: LACompanionType) { self.type = type; stateHash = nil; super.init(usable: false, name: "", icon: "") }
    }
    @objc(LAEnvironmentState) open class State: NSObject, @unchecked Sendable {
        public let biometry: MechanismBiometry?
        public let userPassword: MechanismUserPassword?
        public let companions: [MechanismCompanion] = []
        open var allMechanisms: [Mechanism] { [biometry, userPassword].compactMap { $0 } + companions }
        override init() { biometry = MechanismBiometry(); userPassword = MechanismUserPassword() }
        var signature: String { "\(biometry?.isEnrolled ?? false) \(biometry?.isLockedOut ?? false) \(_LADevice.enrollment)" }
    }

    static let _currentUser = LAEnvironment()
    open class var currentUser: LAEnvironment { _currentUser }
    open var state: State { State() }

    let observers = NSHashTable<AnyObject>.weakObjects()
    var last: State?
    open func addObserver(_ observer: any Observer) {
        observers.add(observer)
        if last == nil { last = State() }
        _LAEnvironmentWatch.start()
    }
    open func removeObserver(_ observer: any Observer) { observers.remove(observer) }

    /// tells the observers when the state changed since the last check
    func check() {
        guard let old = last else { return }
        let now = State()
        guard now.signature != old.signature else { return }
        last = now
        NSLog("isim LocalAuthentication: environment changed (biometry enrolled %d, locked out %d)", now.biometry?.isEnrolled == true ? 1 : 0,
              now.biometry?.isLockedOut == true ? 1 : 0)
        for case let o as Observer in observers.allObjects { o.environment?(self, stateDidChangeFromOldState: old) }
    }
}

/// watches the device-wide biometry state (another app, or the `biometry` script command, may change it)
enum _LAEnvironmentWatch {
    nonisolated(unsafe) static var timer: Timer?
    static func start() {
        DispatchQueue.main.async {
            guard timer == nil else { return }
            timer = Timer._isimScheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in if #available(iOS 18.0, *) { LAEnvironment._currentUser.check() } }
        }
    }
    static func changed() { if #available(iOS 18.0, *) { DispatchQueue.main.async { LAEnvironment._currentUser.check() } } }
}

extension Timer {
    /// a repeating timer with a block (Foundation's scheduledTimer(withTimeInterval:repeats:block:))
    static func _isimScheduledTimer(withTimeInterval t: TimeInterval, repeats: Bool, block: @escaping @Sendable (Timer) -> Void) -> Timer {
        let timer = Timer(timeInterval: t, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

// MARK: - `biometry match|nomatch` (UIKit posts it for the script command)

@_cdecl("isim_la_script_answer")
public func _isimLAScriptAnswer(_ match: Int32) {
    DispatchQueue.main.async { MainActor.assumeIsolated { _LAPrompt.answer(match: match != 0) } }
    _LAEnvironmentWatch.changed()
}

// MARK: - C constants (LAPublicDefines.h)

public var kLAPolicyDeviceOwnerAuthenticationWithBiometrics: Int32 { 1 }
public var kLAPolicyDeviceOwnerAuthentication: Int32 { 2 }
public var kLAPolicyDeviceOwnerAuthenticationWithWatch: Int32 { 3 }
public var kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch: Int32 { 4 }
public var kLAPolicyDeviceOwnerAuthenticationWithWristDetection: Int32 { 5 }
public var kLAOptionUserFallback: Int32 { 1 }
public var kLAOptionAuthenticationReason: Int32 { 2 }
public var kLACredentialTypeApplicationPassword: Int32 { 0 }
public var kLACredentialSmartCardPIN: Int32 { -3 }
public var kLAErrorDomain: String { LAErrorDomain }
public var kLAErrorAuthenticationFailed: Int32 { -1 }
public var kLAErrorUserCancel: Int32 { -2 }
public var kLAErrorUserFallback: Int32 { -3 }
public var kLAErrorSystemCancel: Int32 { -4 }
public var kLAErrorPasscodeNotSet: Int32 { -5 }
public var kLAErrorTouchIDNotAvailable: Int32 { -6 }
public var kLAErrorTouchIDNotEnrolled: Int32 { -7 }
public var kLAErrorTouchIDLockout: Int32 { -8 }
public var kLAErrorBiometryNotAvailable: Int32 { -6 }
public var kLAErrorBiometryNotEnrolled: Int32 { -7 }
public var kLAErrorBiometryLockout: Int32 { -8 }
public var kLAErrorAppCancel: Int32 { -9 }
public var kLAErrorInvalidContext: Int32 { -10 }
public var kLAErrorWatchNotAvailable: Int32 { -11 }
public var kLAErrorCompanionNotAvailable: Int32 { -11 }
public var kLAErrorBiometryNotPaired: Int32 { -12 }
public var kLAErrorBiometryDisconnected: Int32 { -13 }
public var kLAErrorInvalidDimensions: Int32 { -14 }
public var kLAErrorNotInteractive: Int32 { -1004 }
public var kLAAccessControlOperationCreateItem: Int32 { 0 }
public var kLAAccessControlOperationUseItem: Int32 { 1 }
public var kLAAccessControlOperationCreateKey: Int32 { 2 }
public var kLAAccessControlOperationUseKeySign: Int32 { 3 }
public var kLAAccessControlOperationUseKeyDecrypt: Int32 { 4 }
public var kLAAccessControlOperationUseKeyKeyExchange: Int32 { 5 }
public var kLABiometryTypeNone: Int32 { 0 }
public var kLABiometryTypeTouchID: Int32 { 1 }
public var kLABiometryTypeFaceID: Int32 { 2 }
public var kLABiometryTypeOpticID: Int32 { 4 }
public var kLACompanionTypeNone: Int32 { 0 }
public var kLACompanionTypeWatch: Int32 { 1 }
public var kLACompanionTypeMac: Int32 { 2 }
public var kLACompanionTypeVision: Int32 { 4 }
