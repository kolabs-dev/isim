// isim SafariServices: content blockers. reloadContentBlocker runs the app's Safari content blocker extension
// (com.apple.Safari.content-blocker, loaded into this process like isim's share extensions): its
// NSExtensionRequestHandling returns blockerList.json, which is compiled with WebKit (WebKitGTK's content filters) into
// Safari's store on the device. isim's SFSafariViewController applies the enabled blockers. Adapted: there is no Settings >
// Safari > Extensions screen, so a blocker is off by default, as on iOS; ISIM_CONTENTBLOCKER_PERMISSION=allow turns
// them on.
import UIKit
import WebKit

public let SFErrorDomain = "SFErrorDomain"
public struct SFError: CustomNSError, Hashable, Sendable {
    /// 1-3 as in Apple's SDK; the raw values of the cases Apple added later are isim's (proposed)
    public enum Code: Int, Sendable {
        case noExtensionFound = 1, noAttachmentFound, loadingInterrupted, internalError, maximumAttemptsExceeded, missingEntitlement
    }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { SFErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { [:] }
    public static var noExtensionFound: Code { .noExtensionFound }
    public static var noAttachmentFound: Code { .noAttachmentFound }
    public static var loadingInterrupted: Code { .loadingInterrupted }
    public static var internalError: Code { .internalError }
    public static var maximumAttemptsExceeded: Code { .maximumAttemptsExceeded }
    public static var missingEntitlement: Code { .missingEntitlement }
}

@objc(SFContentBlockerState) open class SFContentBlockerState: NSObject, @unchecked Sendable {
    @objc open private(set) var isEnabled: Bool
    init(enabled: Bool) { isEnabled = enabled }
}

@objc(SFContentBlockerManager) open class SFContentBlockerManager: NSObject, @unchecked Sendable {
    /// Safari's compiled content blockers (device-wide)
    static var store: WKContentRuleListStore {
        let env = ProcessInfo.processInfo.environment
        let data = env["ISIM_DATA"] ?? ((env["HOME"] ?? "/tmp") as NSString).appendingPathComponent(".local/share/isim")
        return WKContentRuleListStore(url: URL(fileURLWithPath: (data as NSString).appendingPathComponent("Library/Safari/ContentBlockers")))
    }
    static var enabled: Bool {
        let v = (ProcessInfo.processInfo.environment["ISIM_CONTENTBLOCKER_PERMISSION"] ?? "").lowercased()
        return v == "allow" || v == "1" || v == "yes"
    }
    /// the app's content blocker extension with this bundle identifier
    static func extensionPath(_ identifier: String) -> (path: String, info: [String: Any])? {
        let plugins = (Bundle.main.bundlePath as NSString).appendingPathComponent("PlugIns")
        for name in (try? FileManager.default.contentsOfDirectory(atPath: plugins)) ?? [] where name.hasSuffix(".appex") {
            let path = (plugins as NSString).appendingPathComponent(name)
            guard let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any],
                  info["CFBundleIdentifier"] as? String == identifier,
                  (info["NSExtension"] as? [String: Any])?["NSExtensionPointIdentifier"] as? String == "com.apple.Safari.content-blocker" else { continue }
            return (path, info)
        }
        return nil
    }

    /// asks the extension for its rules again and compiles them for Safari
    @objc(reloadContentBlockerWithIdentifier:completionHandler:)
    open class func reloadContentBlocker(withIdentifier identifier: String, completionHandler: ((Error?) -> Void)? = nil) {
        let finish: (Error?) -> Void = { e in
            NSLog("isim SafariServices: content blocker %@ %@", identifier, e == nil ? "reloaded" : "failed: \(e!)")
            DispatchQueue.main.async { completionHandler?(e) }
        }
        guard let (path, info) = extensionPath(identifier) else { finish(SFError(.noExtensionFound)); return }
        DispatchQueue.main.async {
            _SFExtensionRunner.request(path: path, info: info) { items in
                guard let provider = items.lazy.compactMap({ ($0 as? NSExtensionItem)?.attachments?.first }).first else {
                    finish(SFError(.noAttachmentFound)); return
                }
                provider.loadItem(forTypeIdentifier: "public.json", options: nil) { item, _ in
                    var json: String?
                    if let u = item as? URL { json = try? String(contentsOf: u, encoding: .utf8) }
                    else if let d = item as? Data { json = String(data: d, encoding: .utf8) }
                    else if let s = item as? String { json = s }
                    guard let json else { finish(SFError(.noAttachmentFound)); return }
                    DispatchQueue.main.async {
                        store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: json) { _, e in
                            finish(e == nil ? nil : SFError(.loadingInterrupted))
                        }
                    }
                }
            } failed: { finish(SFError(.noExtensionFound)) }
        }
    }
    open class func reloadContentBlocker(withIdentifier identifier: String) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, Error>) in
            reloadContentBlocker(withIdentifier: identifier) { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    @objc(getStateOfContentBlockerWithIdentifier:completionHandler:)
    open class func getStateOfContentBlocker(withIdentifier identifier: String, completionHandler: @escaping (SFContentBlockerState?, Error?) -> Void) {
        let found = extensionPath(identifier) != nil
        DispatchQueue.main.async {
            completionHandler(found ? SFContentBlockerState(enabled: enabled) : nil, found ? nil : SFError(.noExtensionFound))
        }
    }
    open class func stateOfContentBlocker(withIdentifier identifier: String) async throws -> SFContentBlockerState {
        try await withCheckedThrowingContinuation { k in
            getStateOfContentBlocker(withIdentifier: identifier) { s, e in if let s { k.resume(returning: s) } else { k.resume(throwing: e ?? SFError(.noExtensionFound)) } }
        }
    }

    /// the enabled blockers, for isim's Safari view controller
    @MainActor static func apply(to controller: WKUserContentController, then done: @escaping () -> Void) {
        guard enabled else { done(); return }
        let s = store
        s.getAvailableContentRuleListIdentifiers { ids in
            let ids = ids ?? []
            guard !ids.isEmpty else { done(); return }
            var left = ids.count
            for id in ids {
                s.lookUpContentRuleList(forIdentifier: id) { l, _ in
                    if let l { MainActor.assumeIsolated { controller.add(l) } }
                    left -= 1
                    if left == 0 { done() }
                }
            }
        }
    }
}

/// runs an app extension's NSExtensionRequestHandling principal in this process and returns the items it completes with
@MainActor enum _SFExtensionRunner {
    static var running: [NSObject] = []
    static func request(path: String, info: [String: Any], done: @escaping ([Any]) -> Void, failed: @escaping () -> Void) {
        let ext = info["NSExtension"] as? [String: Any] ?? [:]
        let exe = (path as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? "")
        guard dlopen(exe, RTLD_NOW) != nil, let principal = (ext["NSExtensionPrincipalClass"] as? String).flatMap(NSClassFromString) as? NSObject.Type else {
            failed(); return
        }
        if let register = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {      // RTLD_DEFAULT
            typealias Register = @convention(c) (NSString) -> Void
            unsafeBitCast(register, to: Register.self)(path as NSString)
        }
        let handler = principal.init()
        running.append(handler)
        // NSExtensionContext -initISIMWithInputItems:handler: (isim's Foundation)
        guard let cls = NSClassFromString("NSExtensionContext"), let raw = class_createInstance(cls, 0) as AnyObject? else { failed(); return }
        let sel = NSSelectorFromString("initISIMWithInputItems:handler:")
        typealias Init = @convention(c) (AnyObject, Selector, NSArray, AnyObject?) -> Unmanaged<AnyObject>
        let block: @convention(block) (NSArray?, NSError?, Bool) -> Void = { returned, _, _ in
            DispatchQueue.main.async { running.removeAll { $0 === handler }; done((returned as? [Any]) ?? []) }
        }
        let initIMP = unsafeBitCast(class_getMethodImplementation(cls, sel), to: Init.self)
        let ctx = initIMP(raw, sel, NSArray(), unsafeBitCast(block, to: AnyObject.self)).takeUnretainedValue()
        let begin = NSSelectorFromString("beginRequestWithExtensionContext:")
        guard handler.responds(to: begin) else { failed(); return }
        _ = handler.perform(begin, with: ctx)
    }
}
