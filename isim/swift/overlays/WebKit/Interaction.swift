// isim WebKit: touch interactions of WKWebView beyond taps and scrolling — adapted from iOS:
// - a long press on a link or an image opens a context menu (the UI delegate's
//   webView(_:contextMenuConfigurationForElement:completionHandler:), else Open / Copy Link / Share…), with a live
//   preview of the link's page; elsewhere it selects the word under the finger and shows the edit menu (Copy,
//   Select All, Share…); selections are made by the page's own Selection API, so WebKit draws them (no handles);
// - a tap on a <select> shows its options as a menu (checkmarks; groups; several kept open for a multiple select),
//   and the choice reaches the page with input and change events;
// - pinch zoom magnifies the page (the root element scaled from its corner, no relayout), between the viewport's
//   minimum and maximum scale (none with user-scalable=no); the page scroll pans it; scrollView.zoomScale follows;
// - the find navigator (isFindInteractionEnabled) finds text inside text nodes and paints matches with the CSS Custom
//   Highlight API, the current one in orange, scrolled into view.
// The page is reached from the private "isim" JavaScript world (runtime/isim-webkit.c, window.__isimTools).
import UIKit

extension WKContentWorld { static let _isim = WKContentWorld(name: nil, engineName: "isim") }

/// what a context menu is for (iOS 13)
@objc(WKContextMenuElementInfo) open class WKContextMenuElementInfo: NSObject, @unchecked Sendable {
    @objc open private(set) dynamic var linkURL: URL?
    init(linkURL: URL?) { self.linkURL = linkURL; super.init() }
}

/// what was under the finger when it came down (asked as the touch starts: the long press needs it at once)
struct _WKHit {
    var kind = "none"
    var link: URL?, image: URL?, title = ""
    var rect = CGRect.zero                     /* client (page viewport) coordinates */
}

extension WKWebView {
    func _tool(_ call: String, _ done: @escaping (Any?) -> Void = { _ in }) {
        _runJSTool("window.__isimTools ? window.__isimTools.\(call) : null", done)
    }
    /// a page rect (client coordinates) in this view's coordinates
    func _viewRect(_ r: CGRect) -> CGRect {
        let o = _scroll.pageOrigin, z = pageZoom
        return _scroll.convert(CGRect(x: r.minX * z + o.x, y: r.minY * z + o.y, width: r.width * z, height: r.height * z), to: self)
    }
    func _rect(_ o: [String: Any]) -> CGRect {
        CGRect(x: o["x"] as? Double ?? 0, y: o["y"] as? Double ?? 0, width: o["w"] as? Double ?? 0, height: o["h"] as? Double ?? 0)
    }

    func _setupInteractions() {
        let menus = _WKContextMenus(self)
        _interactions = menus
        _scroll.addInteraction(UIContextMenuInteraction(delegate: menus))
        let edit = UIEditMenuInteraction(delegate: menus)
        addInteraction(edit)
        menus.edit = edit
        let pinch = UIPinchGestureRecognizer(target: menus, action: #selector(_WKContextMenus.pinch(_:)))
        _scroll.addGestureRecognizer(pinch)
    }

    /// a touch came down at a page point: learn what is there, and end a selection
    func _touchDown(at p: CGPoint) {
        _hit = _WKHit()
        _tool("hit(\(_WKProto.num(Double(p.x))),\(_WKProto.num(Double(p.y))))") { [weak self] v in
            guard let self, let o = v as? [String: Any] else { return }
            var h = _WKHit()
            h.kind = o["kind"] as? String ?? "none"
            h.link = (o["href"] as? String).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            h.image = ((o["src"] as? String) ?? (o["image"] as? String)).flatMap { $0.isEmpty ? nil : URL(string: $0) }
            h.title = o["title"] as? String ?? (o["alt"] as? String ?? "")
            h.rect = self._rect(o)
            self._hit = h
        }
        if _hasSelection { _clearSelection() }
    }

    // MARK: selection
    func _selectWord(at p: CGPoint) {
        _tool("word(\(_WKProto.num(Double(p.x))),\(_WKProto.num(Double(p.y))))") { [weak self] v in self?._selectionChanged(v) }
    }
    func _selectionChanged(_ v: Any?) {
        guard let o = v as? [String: Any], let text = o["text"] as? String, !text.isEmpty else { _hasSelection = false; _selectedText = ""; return }
        _hasSelection = true
        _selectedText = text
        _selectionRect = _viewRect(_rect(o))
        _showSelection((o["rects"] as? [[Double]] ?? []).map { _viewRect(CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3])) })
        print("isim: WKWebView selected \"\(text.prefix(80))\"")
        let r = _selectionRect
        _interactions?.edit?.presentEditMenu(with: UIEditMenuConfiguration(identifier: "isim-web-selection" as NSString, sourcePoint: CGPoint(x: r.midX, y: r.minY)))
    }
    /// iOS's selection look over the page: a translucent tint on the selected lines, a handle at each end
    func _showSelection(_ rects: [CGRect]) {
        _selectionOverlay?.removeFromSuperview()
        guard !rects.isEmpty else { return }
        let overlay = _WKSelectionView(frame: bounds)
        overlay.rects = rects
        overlay.isUserInteractionEnabled = false
        overlay.accessibilityIdentifier = "web-selection"
        addSubview(overlay)
        _selectionOverlay = overlay
    }
    /// the page scrolled under a selection: follow it
    func _refreshSelection() {
        guard _hasSelection else { return }
        _tool("sel()") { [weak self] v in
            guard let self, let o = v as? [String: Any] else { return }
            self._selectionRect = self._viewRect(self._rect(o))
            self._showSelection((o["rects"] as? [[Double]] ?? []).map { self._viewRect(CGRect(x: $0[0], y: $0[1], width: $0[2], height: $0[3])) })
        }
    }
    func _clearSelection() {
        _selectionOverlay?.removeFromSuperview(); _selectionOverlay = nil
        _hasSelection = false; _selectedText = ""
        _tool("clear()")
        _interactions?.edit?.dismissMenu()
    }
    @objc open override func copy(_ sender: Any?) {
        guard _hasSelection else { return }
        UIPasteboard.general.string = _selectedText
        print("isim: WKWebView copied \"\(_selectedText.prefix(80))\"")
    }
    @objc open override func selectAll(_ sender: Any?) { _tool("all()") { [weak self] v in self?._selectionChanged(v) } }
    open override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(copy(_:)) { return _hasSelection }
        if action == #selector(selectAll(_:)) { return _hasSelection || !_editing }
        return super.canPerformAction(action, withSender: sender)
    }

    // MARK: <select>
    func _showSelect(_ o: [String: Any]) {
        let options = o["options"] as? [[String: Any]] ?? []
        let multiple = o["multiple"] as? Bool ?? false
        var chosen = Set(options.indices.filter { options[$0]["s"] as? Bool ?? false })
        func items(_ range: [Int]) -> [UIMenuElement] {
            range.map { i in
                let opt = options[i]
                var attrs: UIMenuElement.Attributes = (opt["d"] as? Bool ?? false) ? [.disabled] : []
                if multiple { attrs.insert(.keepsMenuPresented) }
                return UIAction(title: opt["t"] as? String ?? "", attributes: attrs, state: chosen.contains(i) ? .on : .off) { [weak self] _ in
                    if multiple { if chosen.contains(i) { chosen.remove(i) } else { chosen.insert(i) } } else { chosen = [i] }
                    self?._tool("choose([\(chosen.sorted().map(String.init).joined(separator: ","))])")
                    print("isim: WKWebView <select> chose \(chosen.sorted().map { options[$0]["t"] as? String ?? "" })")
                }
            }
        }
        // option groups become inline sections
        var children: [UIMenuElement] = [], i = 0
        while i < options.count {
            let g = options[i]["g"] as? String ?? ""
            var j = i
            while j < options.count && (options[j]["g"] as? String ?? "") == g { j += 1 }
            if g.isEmpty { children += items(Array(i..<j)) } else { children.append(UIMenu(title: g, options: .displayInline, children: items(Array(i..<j)))) }
            i = j
        }
        guard !children.isEmpty else { return }
        print("isim: WKWebView <select> with \(options.count) option(s)")
        _isim_present(UIMenu(title: "", children: children), from: _viewRect(_rect(o)))
    }

    // MARK: pinch zoom
    func _applyPinch(_ z: CGFloat, focus: CGPoint) {
        _pinchZoom = z
        _tool("zoom(\(_WKProto.num(Double(z))),\(_WKProto.num(Double(focus.x))),\(_WKProto.num(Double(focus.y))))")
    }
}

/// the web view's context menus, edit menu and pinch (an object of its own: WKWebView's delegate conformances stay hidden)
final class _WKContextMenus: NSObject, UIContextMenuInteractionDelegate, UIEditMenuInteractionDelegate {
    weak var web: WKWebView?
    weak var edit: UIEditMenuInteraction?
    var info: WKContextMenuElementInfo?
    var hit = _WKHit()
    init(_ w: WKWebView) { web = w }

    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, configurationForMenuAtLocation location: CGPoint) -> UIContextMenuConfiguration? {
        guard let w = web else { return nil }
        hit = w._hit
        guard hit.kind == "link" || hit.kind == "image" else {
            if hit.kind == "text" || hit.kind == "none" {
                let o = w._scroll.pageOrigin, z = w.pageZoom
                w._selectWord(at: CGPoint(x: (location.x - o.x) / z, y: (location.y - o.y) / z))
            }
            return nil
        }
        let element = WKContextMenuElementInfo(linkURL: hit.link ?? hit.image)
        info = element
        // the app's configuration: its handler normally answers at once
        if let d = w.uiDelegate, _wkHas(d, "webView:contextMenuConfigurationForElement:completionHandler:") {
            var answered = false, config: UIContextMenuConfiguration?
            d.webView?(w, contextMenuConfigurationForElement: element) { c in answered = true; config = c }
            if answered { if config != nil { d.webView?(w, contextMenuWillPresentForElement: element) }; return config }
        }
        w.uiDelegate?.webView?(w, contextMenuWillPresentForElement: element)
        let target = hit.link ?? hit.image
        let isLink = hit.link != nil
        let preview: UIContextMenuContentPreviewProvider? = isLink && w.allowsLinkPreview ? { [weak w] in
            guard let target, let w else { return nil }
            return _WKLinkPreview(target, configuration: w.configuration)
        } : nil
        return UIContextMenuConfiguration(identifier: nil, previewProvider: preview) { [weak w] _ in
            guard let w, let target else { return UIMenu(title: "", children: []) }
            var actions: [UIMenuElement] = []
            if isLink {
                actions.append(UIAction(title: "Open", image: UIImage(systemName: "safari")) { _ in w.load(URLRequest(url: target)) })
                actions.append(UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in UIPasteboard.general.url = target })
            } else {
                actions.append(UIAction(title: "Copy", image: UIImage(systemName: "doc.on.doc")) { _ in
                    URLSession.shared.dataTask(with: target) { d, _, _ in
                        guard let d, let img = UIImage(data: d) else { return }
                        DispatchQueue.main.async { UIPasteboard.general.image = img }
                    }.resume()
                })
            }
            actions.append(UIAction(title: "Share…", image: UIImage(systemName: "square.and.arrow.up")) { _ in
                let vc = UIActivityViewController(activityItems: [target], applicationActivities: nil)
                var top = w.window?.rootViewController
                while let p = top?.presentedViewController { top = p }
                top?.present(vc, animated: true)
            })
            return UIMenu(title: target.absoluteString, children: actions)
        }
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, previewForHighlightingMenuWith configuration: UIContextMenuConfiguration) -> UITargetedPreview? {
        guard let w = web, hit.rect.width > 0 else { return nil }
        let r = w._scroll.convert(w._viewRect(hit.rect), from: w)
        guard let snap = w._scroll.resizableSnapshotView(from: r, afterScreenUpdates: false, withCapInsets: .zero) else { return nil }
        let host = UIView(frame: r)
        snap.frame = host.bounds
        host.addSubview(snap)
        w._scroll.addSubview(host)
        DispatchQueue.main.async { host.removeFromSuperview() }
        return UITargetedPreview(view: host)
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willPerformPreviewActionForMenuWith configuration: UIContextMenuConfiguration,
                                animator: UIContextMenuInteractionCommitAnimating) {
        guard let w = web, let info else { return }
        if let d = w.uiDelegate, _wkHas(d, "webView:contextMenuForElement:willCommitWithAnimator:") {
            d.webView?(w, contextMenuForElement: info, willCommitWithAnimator: animator)
        } else if let u = info.linkURL {
            animator.addCompletion { w.load(URLRequest(url: u)) }   /* like iOS: the preview opens in the web view */
        }
    }
    func contextMenuInteraction(_ interaction: UIContextMenuInteraction, willEndFor configuration: UIContextMenuConfiguration, animator: UIContextMenuInteractionAnimating?) {
        guard let w = web, let info else { return }
        animator?.addCompletion { w.uiDelegate?.webView?(w, contextMenuDidEndForElement: info) }
        if animator == nil { w.uiDelegate?.webView?(w, contextMenuDidEndForElement: info) }
    }

    // the edit menu over a selection: Copy, Select All (the responder's), Share…
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, menuFor configuration: UIEditMenuConfiguration, suggestedActions: [UIMenuElement]) -> UIMenu? {
        guard let w = web else { return nil }
        let text = w._selectedText
        let share = UIAction(title: "Share…") { _ in
            let vc = UIActivityViewController(activityItems: [text], applicationActivities: nil)
            var top = w.window?.rootViewController
            while let p = top?.presentedViewController { top = p }
            top?.present(vc, animated: true)
        }
        return UIMenu(children: suggestedActions + [share])
    }
    func editMenuInteraction(_ interaction: UIEditMenuInteraction, targetRectFor configuration: UIEditMenuConfiguration) -> CGRect {
        web?._selectionRect ?? .zero
    }

    // pinch: zoom about the fingers' midpoint, within the page's limits
    var startZoom: CGFloat = 1
    var limits = (scalable: true, min: CGFloat(1), max: CGFloat(5))
    @objc func pinch(_ g: UIPinchGestureRecognizer) {
        guard let w = web else { return }
        switch g.state {
        case .began:
            startZoom = w._pinchZoom
            limits = (true, max(1, w._scroll.minimumZoomScale), min(5, max(1, w._scroll.maximumZoomScale)))
            w._tool("viewport()") { [weak self] v in
                guard let self, let o = v as? [String: Any] else { return }
                self.limits = (o["scalable"] as? Bool ?? true, CGFloat(o["min"] as? Double ?? 1), CGFloat(o["max"] as? Double ?? 5))
            }
        case .changed, .ended:
            guard limits.scalable, w._magnificationAllowed, w._scroll.isScrollEnabled else { return }
            let z = min(max(startZoom * g.scale, max(1, limits.min)), max(1, limits.max))
            let p = g.location(in: w._scroll), o = w._scroll.pageOrigin
            w._applyPinch(z, focus: CGPoint(x: (p.x - o.x) / w.pageZoom, y: (p.y - o.y) / w.pageZoom))
            if g.state == .ended { print(String(format: "isim: WKWebView zoom %.2f", Double(z))) }
        default: break
        }
    }
}

/// a link's page, live, as the context menu's preview (iOS: link previews)
final class _WKLinkPreview: UIViewController {
    let url: URL, config: WKWebViewConfiguration
    init(_ u: URL, configuration: WKWebViewConfiguration) { url = u; config = configuration; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError() }
    override func loadView() {
        let w = WKWebView(frame: CGRect(x: 0, y: 0, width: 340, height: 420), configuration: config)
        w.accessibilityIdentifier = "isim-link-preview"
        w.load(URLRequest(url: url))
        view = w
        preferredContentSize = CGSize(width: 340, height: 420)
    }
}

// MARK: - find (iOS 16 find navigator)

/// the find navigator's session over the page
final class _WKFindSession: UIFindSession {
    weak var web: WKWebView?
    var count = 0, current = -1
    init(_ w: WKWebView) { web = w; super.init() }
    override var resultCount: Int { count }
    override var highlightedResultIndex: Int { current }
    override var supportsReplacement: Bool { false }
    override func performSearch(query: String, options: UITextSearchOptions?) {
        let cs = !(options?.stringCompareOptions.contains(.caseInsensitive) ?? true)
        let mode = options?.wordMatchMethod == .startsWith ? 1 : options?.wordMatchMethod == .fullWord ? 2 : 0
        web?._tool("find(\(_wkJSONText(query)),\(cs),\(mode))") { [weak self] v in
            guard let self else { return }
            self.count = (v as? Int) ?? ((v as? Double).map(Int.init) ?? 0)
            self.current = self.count > 0 ? 0 : -1
            if self.count > 0 { self.web?._tool("show(0)") }
            print("isim: WKWebView find \"\(query)\": \(self.count) result(s)")
            self.web?.findInteraction?.updateResultCount()
        }
    }
    override func highlightNextResult(in direction: UITextStorageDirection) {
        guard count > 0 else { return }
        current = direction == .backward ? (current - 1 + count) % count : (current + 1) % count
        web?._tool("show(\(current))")
        web?.findInteraction?.updateResultCount()
    }
    override func invalidateFoundResults() { count = 0; current = -1; web?._tool("unfind()") }
}

extension WKWebView: UIFindInteractionDelegate {
    public func findInteraction(_ interaction: UIFindInteraction, sessionFor view: UIView) -> UIFindSession? { _WKFindSession(self) }
    public func findInteraction(_ interaction: UIFindInteraction, didEnd session: UIFindSession) { _tool("unfind()") }
}

/// the selected text's tint and the two lollipop handles (iOS 17 look: the tint color at 20 %, 2-pt stems)
final class _WKSelectionView: UIView {
    var rects: [CGRect] = [] { didSet { setNeedsDisplay() } }
    override init(frame: CGRect) { super.init(frame: frame); backgroundColor = .clear; isOpaque = false }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ rect: CGRect) {
        let tint = tintColor ?? .systemBlue
        tint.withAlphaComponent(0.2).setFill()
        for r in rects { UIBezierPath(rect: r).fill() }
        guard let first = rects.first, let last = rects.last else { return }
        tint.setFill()
        UIBezierPath(rect: CGRect(x: first.minX - 1, y: first.minY, width: 2, height: first.height)).fill()
        UIBezierPath(ovalIn: CGRect(x: first.minX - 5, y: first.minY - 10, width: 10, height: 10)).fill()
        UIBezierPath(rect: CGRect(x: last.maxX - 1, y: last.minY, width: 2, height: last.height)).fill()
        UIBezierPath(ovalIn: CGRect(x: last.maxX - 5, y: last.maxY, width: 10, height: 10)).fill()
    }
}
