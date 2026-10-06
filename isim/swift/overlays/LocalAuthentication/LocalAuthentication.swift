// isim LocalAuthentication: LAContext with a simulated Face ID / Touch ID sensor (self-authored, iOS API names).
//
// The device's biometry follows the isim device: Face ID on iPhones without a Home button and on iPad Pro,
// Touch ID on iPhone SE and the other iPads. The first evaluation asks for Face ID permission (the iOS
// "Do you want to allow … to use Face ID?" alert, remembered per app). A scan shows an alert standing in for
// the Simulator's Features ▸ Face ID menu: "Matching Face" / "Non-matching Face" / "Cancel" ("… Touch").
// Automation hooks (environment):
//   ISIM_BIOMETRY=match|nomatch|cancel   answer every scan without the alert (a short Face ID HUD still shows)
//   ISIM_BIOMETRY_ENROLLED=0             no face/finger enrolled (biometryNotEnrolled)
// Scripts can also tap the alert buttons: `taptext Matching Face`.
import UIKit
internal import isim_host

public enum LAPolicy: Int, Sendable {
    case deviceOwnerAuthenticationWithBiometrics = 1
    case deviceOwnerAuthentication = 2
    case deviceOwnerAuthenticationWithWatch = 3
    case deviceOwnerAuthenticationWithBiometricsOrWatch = 4
    case deviceOwnerAuthenticationWithWristDetection = 5
    case deviceOwnerAuthenticationWithCompanion = 6
    case deviceOwnerAuthenticationWithBiometricsOrCompanion = 7
}

public enum LABiometryType: Int, Sendable {
    case none = 0
    @available(*, deprecated, renamed: "none") public static let LABiometryNone = LABiometryType.none
    case touchID = 1
    case faceID = 2
    case opticID = 4
}

public let LAErrorDomain = "com.apple.LocalAuthentication"
public let LATouchIDAuthenticationMaximumAllowableReuseDuration: TimeInterval = 300

public struct LAError: CustomNSError, LocalizedError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case authenticationFailed = -1
        case userCancel = -2
        case userFallback = -3
        case systemCancel = -4
        case passcodeNotSet = -5
        case biometryNotAvailable = -6
        case biometryNotEnrolled = -7
        case biometryLockout = -8
        case appCancel = -9
        case invalidContext = -10
        case companionNotAvailable = -11
        case biometryNotPaired = -12
        case biometryDisconnected = -13
        case invalidDimensions = -14
        case notInteractive = -1004
        @available(*, deprecated, renamed: "biometryNotAvailable") public static let touchIDNotAvailable = Code.biometryNotAvailable
        @available(*, deprecated, renamed: "biometryNotEnrolled") public static let touchIDNotEnrolled = Code.biometryNotEnrolled
        @available(*, deprecated, renamed: "biometryLockout") public static let touchIDLockout = Code.biometryLockout
    }
    public let code: Code
    let message: String
    public init(_ code: Code, message: String? = nil) { self.code = code; self.message = message ?? LAError.defaultMessage(code) }
    public static var errorDomain: String { LAErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: message] }
    public var errorDescription: String? { message }
    public var localizedDescription: String { message }
    public static func == (a: LAError, b: LAError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }

    public static var authenticationFailed: Code { .authenticationFailed }
    public static var userCancel: Code { .userCancel }
    public static var userFallback: Code { .userFallback }
    public static var systemCancel: Code { .systemCancel }
    public static var passcodeNotSet: Code { .passcodeNotSet }
    public static var biometryNotAvailable: Code { .biometryNotAvailable }
    public static var biometryNotEnrolled: Code { .biometryNotEnrolled }
    public static var biometryLockout: Code { .biometryLockout }
    public static var appCancel: Code { .appCancel }
    public static var invalidContext: Code { .invalidContext }
    public static var notInteractive: Code { .notInteractive }

    static func defaultMessage(_ c: Code) -> String {
        switch c {
        case .authenticationFailed: return "Application retry limit exceeded."
        case .userCancel: return "Canceled by user."
        case .userFallback: return "Fallback authentication mechanism selected."
        case .systemCancel: return "Canceled by another authentication."
        case .passcodeNotSet: return "Passcode not set."
        case .biometryNotAvailable: return "Biometry is not available on this device."
        case .biometryNotEnrolled: return "No identities are enrolled."
        case .biometryLockout: return "Biometry is locked out."
        case .appCancel: return "Canceled by application."
        case .invalidContext: return "Invalid context."
        case .notInteractive: return "Interaction not allowed."
        default: return "Authentication failed."
        }
    }
}
public func ~= (code: LAError.Code, error: Error) -> Bool { (error as? LAError)?.code == code }

open class LAContext: NSObject, @unchecked Sendable {
    private var checkedBiometry = false
    private var invalidated = false
    private var succeeded = false
    open var localizedFallbackTitle: String?
    open var localizedCancelTitle: String?
    open var localizedReason: String = ""
    open var touchIDAuthenticationAllowableReuseDuration: TimeInterval = 0
    open var interactionNotAllowed = false
    /// set after canEvaluatePolicy is called, like iOS
    open var biometryType: LABiometryType { checkedBiometry ? _LADevice.biometry : .none }
    open var evaluatedPolicyDomainState: Data? { checkedBiometry && _LADevice.enrolled ? Data("isim-\(_LADevice.biometry == .faceID ? "face" : "finger")-enrollment-1".utf8) : nil }

    public override init() { super.init() }

    open func canEvaluatePolicy(_ policy: LAPolicy, error: AutoreleasingUnsafeMutablePointer<NSError?>?) -> Bool {
        checkedBiometry = true
        if let e = availabilityError(policy) { error?.pointee = e as NSError; return false }
        return true
    }
    func availabilityError(_ policy: LAPolicy) -> LAError? {
        if invalidated { return LAError(.invalidContext) }
        switch policy {
        case .deviceOwnerAuthentication: return nil
        case .deviceOwnerAuthenticationWithBiometrics, .deviceOwnerAuthenticationWithBiometricsOrWatch, .deviceOwnerAuthenticationWithBiometricsOrCompanion:
            if _LADevice.biometry == .faceID && _LADevice.permission == false {
                return LAError(.biometryNotAvailable, message: "User has denied the use of biometry for this app.")
            }
            if !_LADevice.enrolled { return LAError(.biometryNotEnrolled) }
            return nil
        default: return LAError(.companionNotAvailable, message: "No paired companion device is nearby.")
        }
    }

    open func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping @Sendable (Bool, Error?) -> Void) {
        checkedBiometry = true
        func finish(_ ok: Bool, _ e: LAError?) { DispatchQueue.global().async { reply(ok, e) } }   // iOS replies on a private queue
        if localizedReason.isEmpty { finish(false, LAError(.invalidContext, message: "Non-empty localizedReason must be provided.")); return }
        if let e = availabilityError(policy) { finish(false, e); return }
        if interactionNotAllowed { finish(false, LAError(.notInteractive)); return }
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                _LAPrompt.run(context: self, policy: policy, reason: localizedReason) { ok, e in
                    if ok { self.succeeded = true }
                    finish(ok, e)
                }
            }
        }
    }
    open func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Bool, Error>) in
            evaluatePolicy(policy, localizedReason: localizedReason) { ok, e in
                if let e { k.resume(throwing: e) } else { k.resume(returning: ok) }
            }
        }
    }
    open func invalidate() {
        invalidated = true
        DispatchQueue.main.async { MainActor.assumeIsolated { _LAPrompt.cancel(context: self) } }
    }
    var isInvalidated: Bool { invalidated }
}

// MARK: - Device state

enum _LADevice {
    /// Face ID on Home-button-less iPhones and iPad Pro; Touch ID on iPhone SE and the other iPads
    static let biometry: LABiometryType = {
        var d = isim_device()
        isim_device_metrics(&d)
        let name = withUnsafeBytes(of: d.name) { String(decoding: $0.prefix(while: { $0 != 0 }), as: UTF8.self) }
        if name.hasPrefix("iPad") { return name.hasPrefix("iPad Pro") ? .faceID : .touchID }
        return d.safe_bottom > 0 ? .faceID : .touchID
    }()
    static var enrolled: Bool { getenv("ISIM_BIOMETRY_ENROLLED").map { String(cString: $0) != "0" } ?? true }
    static let permissionKey = "_ISIMFaceIDPermission"
    /// nil: not asked yet
    static var permission: Bool? {
        get { UserDefaults.standard.object(forKey: permissionKey) as? Bool }
        set { UserDefaults.standard.set(newValue, forKey: permissionKey) }
    }
    static var scripted: String? { getenv("ISIM_BIOMETRY").map { String(cString: $0).lowercased() } }
    static var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "this app"
    }
}

// MARK: - Prompts

@MainActor enum _LAPrompt {
    static var current: (context: LAContext, alert: UIAlertController, done: (Bool, LAError?) -> Void)?

    static func top() -> UIViewController? {
        var vc = UIApplication.shared.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? UIApplication.shared.windows.first?.rootViewController
        while let p = vc?.presentedViewController { vc = p }
        return vc
    }
    static func present(_ alert: UIAlertController, _ context: LAContext, _ done: @escaping (Bool, LAError?) -> Void) {
        guard let vc = top() else { done(false, LAError(.notInteractive)); return }
        current = (context, alert, done)
        vc.present(alert, animated: true, completion: nil)
    }
    static func cancel(context: LAContext) {
        guard let c = current, c.context === context else { return }
        current = nil
        c.alert.dismiss(animated: true, completion: nil)
        c.done(false, LAError(.appCancel))
    }

    static func run(context: LAContext, policy: LAPolicy, reason: String, done: @escaping (Bool, LAError?) -> Void) {
        let face = _LADevice.biometry == .faceID
        if face && _LADevice.permission == nil {
            guard let purpose = Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") as? String else {
                NSLog("isim LocalAuthentication: Face ID used without NSFaceIDUsageDescription in Info.plist (iOS refuses Face ID for this app)")
                if policy == .deviceOwnerAuthentication { passcode(context: context, reason: reason, done: done) }
                else { done(false, LAError(.biometryNotAvailable, message: "Face ID usage description is missing from Info.plist.")) }
                return
            }
            let alert = UIAlertController(title: "Do you want to allow “\(_LADevice.appName)” to use Face ID?", message: purpose, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Don’t Allow", style: .default) { _ in
                current = nil; _LADevice.permission = false
                if policy == .deviceOwnerAuthentication { passcode(context: context, reason: reason, done: done) }
                else { done(false, LAError(.biometryNotAvailable, message: "User has denied the use of biometry for this app.")) }
            })
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in
                current = nil; _LADevice.permission = true
                scan(context: context, policy: policy, reason: reason, done: done)
            })
            present(alert, context, done)
            return
        }
        if face && _LADevice.permission == false {
            if policy == .deviceOwnerAuthentication { passcode(context: context, reason: reason, done: done) }
            else { done(false, LAError(.biometryNotAvailable, message: "User has denied the use of biometry for this app.")) }
            return
        }
        if !_LADevice.enrolled { passcode(context: context, reason: reason, done: done); return }
        scan(context: context, policy: policy, reason: reason, done: done)
    }

    static func scan(context: LAContext, policy: LAPolicy, reason: String, done: @escaping (Bool, LAError?) -> Void) {
        let face = _LADevice.biometry == .faceID
        let kind = face ? "Face" : "Touch"
        func matched() { NSLog("isim LocalAuthentication: %@ ID matched", kind); done(true, nil) }
        func failed() {
            NSLog("isim LocalAuthentication: %@ ID did not match", kind)
            let title = face ? "Face Not Recognized" : "Touch ID"
            let alert = UIAlertController(title: title, message: face ? nil : "Try Again\n\(reason)", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: face ? "Try Face ID Again" : "Try Again", style: .default) { _ in
                current = nil; scan(context: context, policy: policy, reason: reason, done: done)
            })
            if policy == .deviceOwnerAuthentication {
                alert.addAction(UIAlertAction(title: "Enter Passcode", style: .default) { _ in current = nil; passcode(context: context, reason: reason, done: done) })
            } else if context.localizedFallbackTitle != "" {
                alert.addAction(UIAlertAction(title: context.localizedFallbackTitle ?? "Enter Password", style: .default) { _ in current = nil; done(false, LAError(.userFallback)) })
            }
            alert.addAction(UIAlertAction(title: context.localizedCancelTitle ?? "Cancel", style: .cancel) { _ in current = nil; done(false, LAError(.userCancel)) })
            present(alert, context, done)
        }
        if let s = _LADevice.scripted {
            _LAHUD.show(face: face)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                MainActor.assumeIsolated {
                    _LAHUD.hide()
                    switch s {
                    case "match", "1", "yes": matched()
                    case "cancel": done(false, LAError(.userCancel))
                    default: NSLog("isim LocalAuthentication: %@ ID did not match", kind); done(false, LAError(.authenticationFailed))
                    }
                }
            }
            return
        }
        let alert = UIAlertController(title: "\(kind) ID", message: "“\(_LADevice.appName)”: \(reason)\n\nSimulate the \(face ? "face scan" : "fingerprint"):", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Matching \(kind)", style: .default) { _ in current = nil; matched() })
        alert.addAction(UIAlertAction(title: "Non-matching \(kind)", style: .default) { _ in current = nil; failed() })
        alert.addAction(UIAlertAction(title: context.localizedCancelTitle ?? "Cancel", style: .cancel) { _ in current = nil; done(false, LAError(.userCancel)) })
        present(alert, context, done)
    }

    /// the device passcode (isim's simulated device has one; entering it succeeds)
    static func passcode(context: LAContext, reason: String, done: @escaping (Bool, LAError?) -> Void) {
        if let s = _LADevice.scripted { done(s == "cancel" ? false : true, s == "cancel" ? LAError(.userCancel) : nil); return }
        let alert = UIAlertController(title: "Enter iPhone Passcode", message: "“\(_LADevice.appName)”: \(reason)", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Enter Passcode", style: .default) { _ in current = nil; NSLog("isim LocalAuthentication: passcode accepted"); done(true, nil) })
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in current = nil; done(false, LAError(.userCancel)) })
        present(alert, context, done)
    }
}

/// the small Face ID / Touch ID glyph shown while a scripted scan runs
@MainActor enum _LAHUD {
    static var window: UIWindow?
    static func show(face: Bool) {
        let w = UIWindow(frame: UIScreen.main.bounds)
        w.windowLevel = UIWindow.Level(rawValue: 2050)
        w.isUserInteractionEnabled = false
        w.backgroundColor = .clear
        let root = UIViewController(); root.view.backgroundColor = .clear
        let size: CGFloat = 156
        let box = UIView(frame: CGRect(x: (UIScreen.main.bounds.width - size) / 2, y: (UIScreen.main.bounds.height - size) / 2, width: size, height: size))
        box.backgroundColor = UIColor(white: 0.12, alpha: 0.86)
        box.layer.cornerRadius = 30
        let icon = UIImageView(image: UIImage(systemName: face ? "faceid" : "touchid"))
        icon.tintColor = .white
        icon.frame = CGRect(x: 43, y: 30, width: 70, height: 70)
        box.addSubview(icon)
        let label = UILabel(frame: CGRect(x: 0, y: 112, width: size, height: 24))
        label.text = face ? "Face ID" : "Touch ID"
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
        box.addSubview(label)
        root.view.addSubview(box)
        w.rootViewController = root
        w.isHidden = false
        window = w
    }
    static func hide() { window?.isHidden = true; window = nil }
}
