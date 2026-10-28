// isim ManagedSettings: what happens when the user taps a shield's buttons. A Shield Action extension
// (NSExtensionPointIdentifier com.apple.ManagedSettings.shield-action-service, its principal class a
// ShieldActionDelegate subclass) runs as a helper process the home screen starts when a button of its app's shield is
// tapped (SBScreenTime.m): the request names the action and the shielded app, web domain or category; the response
// tells the home screen to close the shield (back to the Home Screen), keep it, or defer.
import Foundation

public enum ShieldAction: Int, Codable, Sendable {
    case primaryButtonPressed = 0
    case secondaryButtonPressed = 1
    @available(iOS 26.4, *) case firstSecondarySubmenuItemPressed = 2
    @available(iOS 26.4, *) case secondSecondarySubmenuItemPressed = 3
    @available(iOS 26.4, *) case thirdSecondarySubmenuItemPressed = 4
}

public enum ShieldActionResponse: Int, Codable, Sendable {
    /// the shield stays (the action did nothing the user sees)
    case none = 0
    /// the shield closes and the app goes away
    case close = 1
    /// the shield stays and its configuration is asked for again (after the extension changed a setting)
    case `defer` = 2
    /// iOS 26.5: the parental controls app opens
    @available(iOS 26.5, *) case openParentalControlsApp = 3
}

/// the principal class of a Shield Action extension: subclass it and override the handlers
@objc(ShieldActionDelegate)
open class ShieldActionDelegate: NSObject {
    public override init() { super.init() }
    open func handle(action: ShieldAction, for application: ApplicationToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
    open func handle(action: ShieldAction, for webDomain: WebDomainToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
    open func handle(action: ShieldAction, for category: ActivityCategoryToken, completionHandler: @escaping (ShieldActionResponse) -> Void) {
        completionHandler(.close)
    }
}

// MARK: - Screen Time extensions as helper processes (also DeviceActivity's monitor and ManagedSettingsUI's shields)

extension _IsimScreenTime {
    /// the request the home screen wrote (ISIM_EXTENSION_REQUEST), or nil
    public static var extensionRequest: [String: Any]? {
        guard let p = ProcessInfo.processInfo.environment["ISIM_EXTENSION_REQUEST"] else { return nil }
        return NSDictionary(contentsOfFile: p) as? [String: Any]
    }
    /// the extension's principal class (NSExtensionPrincipalClass)
    public static func principal<T: NSObject>(_ type: T.Type) -> T? {
        let ext = Bundle.main.infoDictionary?["NSExtension"] as? [String: Any]
        guard let name = ext?["NSExtensionPrincipalClass"] as? String, let cls = NSClassFromString(name) as? T.Type else {
            NSLog("isim: the extension's NSExtensionPrincipalClass is not a %@", String(describing: T.self))
            return nil
        }
        return cls.init()
    }
    /// runs the main run loop until `done` is called (the extension answers), writes the answer to the request's `out`
    public static func serve(_ body: (@escaping ([String: Any]) -> Void) -> Void) -> Int32 {
        guard let req = extensionRequest, let out = req["out"] as? String else { NSLog("isim: no extension request"); return 1 }
        var answer: [String: Any]?
        body { a in DispatchQueue.main.async { answer = a } }
        let limit = Date().addingTimeInterval(30)
        while answer == nil && Date() < limit { RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05)) }
        ((answer ?? ["timeout": true]) as NSDictionary).write(toFile: out, atomically: true)
        return answer == nil ? 1 : 0
    }
}

/// a Shield Action extension's process (UIKit's NSExtensionMain for com.apple.ManagedSettings.shield-action-service)
@_cdecl("isim_ms_extension_main")
public func _isimMSExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    _IsimScreenTime.serve { reply in
        guard let req = _IsimScreenTime.extensionRequest, let d = _IsimScreenTime.principal(ShieldActionDelegate.self) else {
            reply(["response": ShieldActionResponse.close.rawValue]); return
        }
        let action = ShieldAction(rawValue: req["action"] as? Int ?? 0) ?? .primaryButtonPressed
        let token = req["token"] as? String ?? ""
        let done: (ShieldActionResponse) -> Void = { r in reply(["response": r.rawValue]) }
        switch req["target"] as? String {
        case "webDomain": d.handle(action: action, for: _IsimScreenTime.token(id: token) as WebDomainToken, completionHandler: done)
        case "category": d.handle(action: action, for: _IsimScreenTime.token(id: token) as ActivityCategoryToken, completionHandler: done)
        default: d.handle(action: action, for: _IsimScreenTime.token(id: token) as ApplicationToken, completionHandler: done)
        }
    }
}
