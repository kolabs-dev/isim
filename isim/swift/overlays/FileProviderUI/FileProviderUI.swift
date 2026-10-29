// isim FileProviderUI (adapted): the UI extension of a file provider app (com.apple.fileprovider-actionsui). The
// document picker and browser (UIKit's UIDocumentPicker.m, through FileProvider.framework) load it into the app that
// shows the picker, like isim's other extensions, and present its FPUIActionExtensionViewController as a sheet: for
// one of its NSExtensionFileProviderActions (prepare(forAction:itemIdentifiers:)), or when syncing the domain fails
// with NSFileProviderError.notAuthenticated (prepare(forError:)). completeRequest() and cancelRequest(withError:)
// dismiss it. Objective-C: sdk-src/Frameworks/FileProviderUI.
@_exported import FileProviderUI
import FileProvider
import UIKit

@objc(FPUIActionExtensionContext)
open class FPUIActionExtensionContext: NSExtensionContext, @unchecked Sendable {
    var _domain: NSFileProviderDomainIdentifier?
    var _finish: ((NSError?) -> Void)?
    /// the domain of the items the action is for
    @objc open var domainIdentifier: NSFileProviderDomainIdentifier? { _domain }
    /// the action is done: the sheet closes
    @objc open func completeRequest() { finish(nil) }
    /// the action did not happen (FPUIExtensionErrorCode.userCancelled when the user cancelled)
    @objc(cancelRequestWithError:) open override func cancelRequest(withError error: any Error) { finish(error as NSError) }
    open override func completeRequest(returningItems items: [Any]?, completionHandler: ((Bool) -> Void)? = nil) {
        finish(nil)
        completionHandler?(false)
    }
    func finish(_ e: NSError?) {
        let f = _finish
        _finish = nil
        DispatchQueue.main.async { f?(e) }
    }
}

@objc(FPUIActionExtensionViewController)
open class FPUIActionExtensionViewController: UIViewController {
    var _isimContext = FPUIActionExtensionContext()
    open override var extensionContext: FPUIActionExtensionContext { _isimContext }
    /// shows the UI for an error of the provider (sign in after notAuthenticated)
    @objc(prepareForError:) open func prepare(forError error: any Error) {}
    /// shows the UI for one of the extension's actions on the items
    @objc(prepareForActionWithIdentifier:itemIdentifiers:)
    open func prepare(forAction actionIdentifier: String, itemIdentifiers: [NSFileProviderItemIdentifier]) {}
}

// MARK: - hosting (called by FileProvider.framework)

/// loads the UI extension at `appex`, prepares its view controller for the action (or the error) and presents it
@_cdecl("isim_fpui_present")
public func _isimFPUIPresent(_ appex: NSString, _ action: NSString?, _ items: NSArray, _ domain: NSString, _ error: NSError?, _ presenter: UIViewController,
                             _ done: @escaping @convention(block) (NSError?) -> Void) {
    let path = appex as String
    let info = NSDictionary(contentsOfFile: (path as NSString).appendingPathComponent("Info.plist")) as? [String: Any] ?? [:]
    let exe = (path as NSString).appendingPathComponent(info["CFBundleExecutable"] as? String ?? ((path as NSString).lastPathComponent as NSString).deletingPathExtension)
    func fail(_ why: String) {
        NSLog("isim FileProviderUI: %@", why)
        done(NSError(domain: "FPUIErrorDomain", code: Int(FPUIExtensionErrorCode.failed.rawValue), userInfo: [NSLocalizedDescriptionKey: why]))
    }
    guard dlopen(exe, RTLD_NOW) != nil else { fail("cannot load \(path): \(String(cString: dlerror()))"); return }
    if let reg = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "isim_bundle_register_extension") {
        unsafeBitCast(reg, to: (@convention(c) (NSString) -> Void).self)(path as NSString)
    }
    let ext = info["NSExtension"] as? [String: Any] ?? [:]
    var vc: UIViewController?
    if let name = ext["NSExtensionPrincipalClass"] as? String, let cls = NSClassFromString(name) as? UIViewController.Type {
        vc = cls.init(nibName: nil, bundle: Bundle(path: path))
    } else if let sb = ext["NSExtensionMainStoryboard"] as? String {
        vc = UIStoryboard(name: sb, bundle: Bundle(path: path)).instantiateInitialViewController()
    }
    guard let ui = vc as? FPUIActionExtensionViewController else { fail("\(path): no FPUIActionExtensionViewController"); return }
    let ctx = FPUIActionExtensionContext()
    ctx._domain = NSFileProviderDomainIdentifier(domain as String)
    ctx._finish = { [weak ui] e in
        NSLog("isim FileProviderUI: %@ %@", action as String? ?? "error UI", e == nil ? "completed" : "cancelled")
        if let ui, ui.presentingViewController != nil { ui.dismiss(animated: true) { done(e) } } else { done(e) }
    }
    ui._isimContext = ctx
    ui.modalPresentationStyle = .formSheet
    if let error {
        ui.prepare(forError: error)
    } else {
        ui.prepare(forAction: action as String? ?? "", itemIdentifiers: ((items as? [String]) ?? []).map { NSFileProviderItemIdentifier($0) })
    }
    NSLog("isim FileProviderUI: presents %@ for %@", NSStringFromClass(type(of: ui)), action as String? ?? "an error")
    presenter.present(ui, animated: true)
}
