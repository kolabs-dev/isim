// isim WebKit (issue #421): file inputs and element fullscreen.
//
// - <input type=file>: WebKit's file chooser request goes to WKUIDelegate's runOpenPanelWith (iOS 18.4) with
//   WKOpenPanelParameters; the URLs it answers become the input's files. Without that method the web view offers
//   iOS's menu (Photo Library, Take Photo or Video, Choose File) over isim's photo picker, camera and document picker.
//   Adapted: WebKitGTK does not say whether the input asks for directories (allowsDirectories is false).
// - fullscreen: with isElementFullscreenEnabled, an element's requestFullscreen() shows the web view over the whole
//   window, as iOS does, with a close button; fullscreenState (KVO) goes entering -> in -> exiting -> not in. Without it
//   requestFullscreen() is refused, as on iOS.
import UIKit

@available(iOS 18.4, *)
@objc(WKOpenPanelParameters) open class WKOpenPanelParameters: NSObject, @unchecked Sendable {
    @objc open private(set) var allowsMultipleSelection: Bool
    @objc open private(set) var allowsDirectories: Bool
    init(multiple: Bool, directories: Bool) { allowsMultipleSelection = multiple; allowsDirectories = directories }
}

extension WKWebView {
    @objc(WKFullscreenState) public enum FullscreenState: Int, @unchecked Sendable {
        case notInFullscreen = 0, enteringFullscreen, inFullscreen, exitingFullscreen
    }
}

/// the default file panel: iOS's menu, then the picker the person chose
@MainActor final class _WKFilePanel: NSObject, @MainActor UIDocumentPickerDelegate, @MainActor UIImagePickerControllerDelegate, @MainActor UINavigationControllerDelegate {
    static var current: _WKFilePanel?
    let done: ([URL]?) -> Void
    let multiple: Bool
    init(multiple: Bool, done: @escaping ([URL]?) -> Void) { self.multiple = multiple; self.done = done }

    func present(from web: WKWebView) {
        guard let top = _wkTopController(web) else { done(nil); return }
        _WKFilePanel.current = self
        let sheet = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Photo Library", style: .default) { [self] _ in pickImage(top, .photoLibrary) })
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            sheet.addAction(UIAlertAction(title: "Take Photo or Video", style: .default) { [self] _ in pickImage(top, .camera) })
        }
        sheet.addAction(UIAlertAction(title: "Choose File", style: .default) { [self] _ in
            let p = UIDocumentPickerViewController(_isimOpeningTypeIdentifiers: ["public.item"], asCopy: true)
            p.allowsMultipleSelection = multiple
            p.delegate = self
            top.present(p, animated: true)
        })
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel) { [self] _ in finish(nil) })
        if let pop = sheet.popoverPresentationController { pop.sourceView = web; pop.sourceRect = CGRect(x: web.bounds.midX, y: web.bounds.midY, width: 1, height: 1) }
        top.present(sheet, animated: true)
    }
    func pickImage(_ top: UIViewController, _ source: UIImagePickerController.SourceType) {
        let p = UIImagePickerController()
        p.sourceType = source
        p.delegate = self
        top.present(p, animated: true)
    }
    func finish(_ urls: [URL]?) { done(urls); _WKFilePanel.current = nil }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) { finish(urls) }
    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { finish(nil) }
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
        var url = info[.imageURL] as? URL
        if url == nil, let image = info[.originalImage] as? UIImage, let data = image.jpegData(compressionQuality: 0.9) {
            let u = FileManager.default.temporaryDirectory.appendingPathComponent("image-\(UUID().uuidString.prefix(8)).jpeg")
            if (try? data.write(to: u)) != nil { url = u }
        }
        picker.dismiss(animated: true) { [self] in finish(url.map { [$0] }) }
    }
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { picker.dismiss(animated: true) { [self] in finish(nil) } }
}

@MainActor func _wkTopController(_ v: UIView) -> UIViewController? {
    var vc = v.window?.rootViewController ?? UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController
    while let p = vc?.presentedViewController { vc = p }
    return vc
}

/// the full-screen presentation (iOS's WKFullScreenViewController): black, no status bar, a close button
final class _WKFullscreenController: UIViewController {
    let close = UIButton(type: .system)
    init() { super.init(nibName: nil, bundle: nil); modalPresentationStyle = .fullScreen; modalTransitionStyle = .crossDissolve }
    required init?(coder: NSCoder) { fatalError() }
    override var prefersStatusBarHidden: Bool { true }
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        view.accessibilityIdentifier = "isim-web-fullscreen"
        close.setImage(UIImage(systemName: "xmark"), for: .normal)
        close.tintColor = .white
        close.backgroundColor = UIColor(white: 0.2, alpha: 0.75)
        close.layer.cornerRadius = 18
        close.accessibilityIdentifier = "isim-web-fullscreen-close"
        close.accessibilityLabel = "Close"
        view.addSubview(close)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for case let w as WKWebView in view.subviews { w.frame = view.bounds }
        close.frame = CGRect(x: max(16, view.safeAreaInsets.left + 8), y: max(16, view.safeAreaInsets.top), width: 36, height: 36)
        view.bringSubviewToFront(close)
    }
}

/// where a fullscreen web view came from, to put it back
struct _WKFullscreenHome {
    weak var superview: UIView?
    var index: Int
    var frame: CGRect
    var mask: UIView.AutoresizingMask
    var translates: Bool
}

extension WKWebView {
    func _filesEvent(_ f: [String]) {
        guard f.count >= 2 else { return }
        let req = f[0], multiple = f[1] == "1"
        let reply: ([URL]?) -> Void = { [weak self] urls in
            let paths = (urls ?? []).filter(\.isFileURL).map(\.path)
            self?._send(["files", req, String(paths.count), paths.joined(separator: "\n")])
        }
        let frame = WKFrameInfo(main: true, url: url, webView: self)
        if #available(iOS 18.4, *), let u = uiDelegate, _wkHas(u, "webView:runOpenPanelWithParameters:initiatedByFrame:completionHandler:") {
            u.webView?(self, runOpenPanelWith: WKOpenPanelParameters(multiple: multiple, directories: false), initiatedByFrame: frame, completionHandler: reply)
            return
        }
        NSLog("isim: WKWebView file panel (multiple %@)", multiple ? "yes" : "no")
        _WKFilePanel(multiple: multiple, done: reply).present(from: self)
    }

    func _setFullscreenState(_ s: FullscreenState) {
        guard s != _fullscreenState else { return }
        willChangeValue(forKey: "fullscreenState")
        _fullscreenState = s
        didChangeValue(forKey: "fullscreenState")
    }
    func _fullscreenEvent(_ f: [String]) {
        if f.first == "1" { _enterFullscreen() } else { _exitFullscreen() }
    }
    func _enterFullscreen() {
        guard _fullscreenHome == nil, let sv = superview, let top = _wkTopController(self) else { return }
        _setFullscreenState(.enteringFullscreen)
        _fullscreenHome = _WKFullscreenHome(superview: sv, index: sv.subviews.firstIndex(of: self) ?? sv.subviews.count, frame: frame,
                                            mask: autoresizingMask, translates: translatesAutoresizingMaskIntoConstraints)
        let vc = _WKFullscreenController()
        vc.loadViewIfNeeded()
        removeFromSuperview()
        translatesAutoresizingMaskIntoConstraints = true
        frame = vc.view.bounds
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        vc.view.insertSubview(self, at: 0)
        vc.close.addTarget(self, action: #selector(_isimExitFullscreen), for: .touchUpInside)
        _fullscreenCover = vc.view
        NSLog("isim: WKWebView entered fullscreen")
        top.present(vc, animated: true) { [weak self] in self?._setFullscreenState(.inFullscreen) }
    }
    @objc func _isimExitFullscreen() { _send(["exitfs"]) }
    func _exitFullscreen() {
        guard let home = _fullscreenHome else { return }
        _setFullscreenState(.exitingFullscreen)
        let vc = _fullscreenCover?.next as? UIViewController
        let restore = { [weak self] in
            guard let self else { return }
            self.removeFromSuperview()
            self.frame = home.frame
            self.autoresizingMask = home.mask
            self.translatesAutoresizingMaskIntoConstraints = home.translates
            if let sv = home.superview { sv.insertSubview(self, at: min(home.index, sv.subviews.count)) }
            self._fullscreenCover = nil
            self._fullscreenHome = nil
            NSLog("isim: WKWebView left fullscreen")
            self._setFullscreenState(.notInFullscreen)
        }
        if let vc, vc.presentingViewController != nil { vc.dismiss(animated: true, completion: restore) } else { restore() }
    }
    /// closes the fullscreen element (iOS 16 closeAllMediaPresentations also leaves fullscreen)
    func _leaveFullscreenIfNeeded() { if _fullscreenHome != nil { _send(["exitfs"]) } }
}
