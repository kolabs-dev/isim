// isim LinkPresentation: rich link previews (issue #323). Adapted: LPMetadataProvider loads the page with URLSession
// (redirects followed; the final URL becomes the metadata's url) and reads <title>, the Open Graph and Twitter card tags
// (title, image, video) and the icon links (apple-touch-icon, icon, else /favicon.ico); with shouldFetchSubresources the
// icon and the image are downloaded into NSItemProviders. LPLinkView is isim's drawing of iOS's link card: a large
// image above the title and host when there is one, else a compact row with the icon (Safari's compass without one);
// a tap opens the link. The classes carry Apple's Objective-C names (sdk-src/Frameworks/LinkPresentation).
import UIKit

public let LPErrorDomain = "LPErrorDomain"
public struct LPError: CustomNSError, Hashable, Sendable {
    public enum Code: Int, Sendable {
        case unknown = 1, metadataFetchFailed, metadataFetchCancelled, metadataFetchTimedOut
        @available(iOS 17.0, *) case metadataFetchNotAllowed
    }
    public let code: Code
    let message: String
    public init(_ code: Code) { self.code = code; message = "" }
    init(_ code: Code, _ message: String) { self.code = code; self.message = message }
    public static var errorDomain: String { LPErrorDomain }
    public var errorCode: Int { code.rawValue }
    public var errorUserInfo: [String: Any] { message.isEmpty ? [:] : [NSLocalizedDescriptionKey: message] }
    public static var unknown: Code { .unknown }
    public static var metadataFetchFailed: Code { .metadataFetchFailed }
    public static var metadataFetchCancelled: Code { .metadataFetchCancelled }
    public static var metadataFetchTimedOut: Code { .metadataFetchTimedOut }
    @available(iOS 17.0, *) public static var metadataFetchNotAllowed: Code { .metadataFetchNotAllowed }
    public static func == (a: LPError, b: LPError) -> Bool { a.code == b.code }
    public func hash(into h: inout Hasher) { h.combine(code) }
}

// MARK: - LPLinkMetadata

@objc(LPLinkMetadata) open class LPLinkMetadata: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open var originalURL: URL?
    @objc(URL) open var url: URL?
    @objc open var title: String?
    @objc open var iconProvider: NSItemProvider?
    @objc open var imageProvider: NSItemProvider?
    @objc open var videoProvider: NSItemProvider?
    @objc open var remoteVideoURL: URL?
    /// the downloaded subresources, for LPLinkView and archiving
    var _icon: UIImage?, _image: UIImage?

    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        originalURL = coder.decodeObject(of: NSURL.self, forKey: "originalURL") as URL?
        url = coder.decodeObject(of: NSURL.self, forKey: "URL") as URL?
        title = coder.decodeObject(of: NSString.self, forKey: "title") as String?
        remoteVideoURL = coder.decodeObject(of: NSURL.self, forKey: "remoteVideoURL") as URL?
        super.init()
        if let d = coder.decodeObject(of: NSData.self, forKey: "icon") as Data?, let i = UIImage(data: d) { _icon = i; iconProvider = NSItemProvider(object: i) }
        if let d = coder.decodeObject(of: NSData.self, forKey: "image") as Data?, let i = UIImage(data: d) { _image = i; imageProvider = NSItemProvider(object: i) }
    }
    open func encode(with coder: NSCoder) {
        coder.encode(originalURL.map { $0 as NSURL }, forKey: "originalURL")
        coder.encode(url.map { $0 as NSURL }, forKey: "URL")
        coder.encode(title.map { $0 as NSString }, forKey: "title")
        coder.encode(remoteVideoURL.map { $0 as NSURL }, forKey: "remoteVideoURL")
        if let d = _icon?.pngData() { coder.encode(d as NSData, forKey: "icon") }
        if let d = _image?.pngData() { coder.encode(d as NSData, forKey: "image") }
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        let m = LPLinkMetadata()
        m.originalURL = originalURL; m.url = url; m.title = title
        m.iconProvider = iconProvider; m.imageProvider = imageProvider; m.videoProvider = videoProvider
        m.remoteVideoURL = remoteVideoURL; m._icon = _icon; m._image = _image
        return m
    }
    open override var description: String {
        "<LPLinkMetadata: url: \(url?.absoluteString ?? "nil"); title: \"\(title ?? "")\"; icon: \(iconProvider != nil); image: \(imageProvider != nil)>"
    }
}

// MARK: - reading the page

enum _LPPage {
    struct Page { var title: String?; var image: URL?; var icon: URL?; var video: URL? }

    static let named: [String: String] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"", "apos": "'", "nbsp": "\u{a0}", "mdash": "\u{2014}",
                                          "ndash": "\u{2013}", "hellip": "\u{2026}", "rsquo": "\u{2019}", "lsquo": "\u{2018}", "rdquo": "\u{201d}", "ldquo": "\u{201c}"]
    static func decodeEntities(_ s: String) -> String {
        guard s.contains("&") else { return s }
        var out = "", rest = Substring(s)
        while let amp = rest.firstIndex(of: "&") {
            out += rest[..<amp]
            let after = rest.index(after: amp)
            if let semi = rest[after...].firstIndex(of: ";"), rest.distance(from: after, to: semi) < 10 {
                let name = String(rest[after..<semi])
                var scalar: Unicode.Scalar?
                if name.hasPrefix("#x") || name.hasPrefix("#X") { scalar = UInt32(name.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init) }
                else if name.hasPrefix("#") { scalar = UInt32(name.dropFirst()).flatMap(Unicode.Scalar.init) }
                if let scalar { out.unicodeScalars.append(scalar); rest = rest[rest.index(after: semi)...]; continue }
                if let n = named[name] { out += n; rest = rest[rest.index(after: semi)...]; continue }
            }
            out += "&"
            rest = rest[after...]
        }
        return out + rest
    }
    /// the attributes of one tag, names lowercased
    static func attributes(_ tag: String) -> [String: String] {
        var d: [String: String] = [:]
        let re = try! NSRegularExpression(pattern: #"([a-zA-Z_:-]+)\s*=\s*("([^"]*)"|'([^']*)'|([^\s>]+))"#)
        let ns = tag as NSString
        for m in re.matches(in: tag, range: NSRange(location: 0, length: ns.length)) {
            let name = ns.substring(with: m.range(at: 1)).lowercased()
            let v = (3...5).map { m.range(at: $0) }.first { $0.location != NSNotFound }!
            if d[name] == nil { d[name] = decodeEntities(ns.substring(with: v)) }
        }
        return d
    }
    static func parse(_ html: String, base: URL) -> Page {
        let ns = html as NSString
        var meta: [String: String] = [:]
        var touchIcon: String?, icon: String?
        let tags = try! NSRegularExpression(pattern: #"<(meta|link)\b[^>]*>"#, options: .caseInsensitive)
        for m in tags.matches(in: html, range: NSRange(location: 0, length: ns.length)) {
            let a = attributes(ns.substring(with: m.range))
            if ns.substring(with: m.range(at: 1)).lowercased() == "meta" {
                if let key = (a["property"] ?? a["name"])?.lowercased(), let content = a["content"], meta[key] == nil { meta[key] = content }
            } else if let href = a["href"] {
                let rel = (a["rel"] ?? "").lowercased().split(separator: " ")
                if rel.contains("apple-touch-icon") || rel.contains("apple-touch-icon-precomposed") { touchIcon = touchIcon ?? href }
                else if rel.contains("icon") { icon = icon ?? href }
            }
        }
        var title = meta["og:title"] ?? meta["twitter:title"]
        if title == nil {
            let t = try! NSRegularExpression(pattern: #"<title[^>]*>(.*?)</title>"#, options: [.caseInsensitive, .dotMatchesLineSeparators])
            if let m = t.firstMatch(in: html, range: NSRange(location: 0, length: ns.length)) { title = decodeEntities(ns.substring(with: m.range(at: 1))) }
        }
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines).split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }.joined(separator: " ")
        func url(_ s: String?) -> URL? { s.flatMap { URL(string: $0, relativeTo: base)?.absoluteURL } }
        return Page(title: trimmed?.isEmpty == false ? trimmed : nil,
                    image: url(meta["og:image"] ?? meta["og:image:url"] ?? meta["og:image:secure_url"] ?? meta["twitter:image"] ?? meta["twitter:image:src"]),
                    icon: url(touchIcon ?? icon ?? "/favicon.ico"),
                    video: url(meta["og:video"] ?? meta["og:video:url"] ?? meta["og:video:secure_url"] ?? meta["twitter:player"]))
    }
}

// MARK: - LPMetadataProvider

/// one fetch per provider; the completion handler runs on a background queue
@objc(LPMetadataProvider) open class LPMetadataProvider: NSObject, @unchecked Sendable {
    @objc open var shouldFetchSubresources = true
    @objc open var timeout: TimeInterval = 30
    private let lock = NSLock()
    private var started = false, done = false
    private var completion: ((LPLinkMetadata?, Error?) -> Void)?
    private var tasks: [URLSessionTask] = []
    private var session: URLSession?

    public override init() { super.init() }

    @objc(startFetchingMetadataForURL:completionHandler:)
    open func startFetchingMetadata(for url: URL, completionHandler: @escaping @Sendable (LPLinkMetadata?, Error?) -> Void) {
        startFetchingMetadata(for: URLRequest(url: url), completionHandler: completionHandler)
    }
    @objc(startFetchingMetadataForRequest:completionHandler:)
    open func startFetchingMetadata(for request: URLRequest, completionHandler: @escaping @Sendable (LPLinkMetadata?, Error?) -> Void) {
        lock.lock()
        if started {
            lock.unlock()
            NSException(name: "NSInternalInconsistencyException",
                        reason: "Trying to start fetching on an LPMetadataProvider that has already started. LPMetadataProvider is a one-shot object.").raise()
        }
        started = true
        completion = completionHandler
        lock.unlock()
        fetch(request)
    }
    open func startFetchingMetadata(for url: URL) async throws -> LPLinkMetadata {
        try await startFetchingMetadata(for: URLRequest(url: url))
    }
    open func startFetchingMetadata(for request: URLRequest) async throws -> LPLinkMetadata {
        try await withCheckedThrowingContinuation { k in
            startFetchingMetadata(for: request) { m, e in if let m { k.resume(returning: m) } else { k.resume(throwing: e ?? LPError(.unknown)) } }
        }
    }
    @objc open func cancel() {
        lock.lock(); let running = started && !done; lock.unlock()
        if running { finish(nil, LPError(.metadataFetchCancelled, "Metadata fetch cancelled")) }
    }

    private func finish(_ m: LPLinkMetadata?, _ e: LPError?) {
        lock.lock()
        guard !done else { lock.unlock(); return }
        done = true
        let c = completion, t = tasks
        completion = nil
        lock.unlock()
        t.forEach { if $0.state == .running { $0.cancel() } }
        session?.finishTasksAndInvalidate()
        if let e { NSLog("isim LinkPresentation: metadata fetch failed: %@", e.message) }
        let result = e == nil ? m : nil, error: Error? = e
        DispatchQueue.global(qos: .userInitiated).async { c?(result, error) }
    }
    private func track(_ t: URLSessionTask) { lock.lock(); tasks.append(t); lock.unlock(); t.resume() }

    private func fetch(_ request: URLRequest) {
        let url = request.url
        let m = LPLinkMetadata()
        m.originalURL = url; m.url = url
        guard let url else { finish(nil, LPError(.metadataFetchFailed, "No URL")); return }
        if url.isFileURL { m.title = url.lastPathComponent; finish(m, nil); return }       // a local file: its name, nothing to fetch
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { finish(nil, LPError(.metadataFetchFailed, "Unsupported URL")); return }
        let config = URLSessionConfiguration.ephemeral
        let seconds = timeout > 0 ? timeout : 30
        config.timeoutIntervalForRequest = seconds
        let session = URLSession(configuration: config)
        self.session = session
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.finish(nil, LPError(.metadataFetchTimedOut, "Metadata fetch timed out"))
        }
        var r = request
        if r.value(forHTTPHeaderField: "Accept") == nil { r.setValue("text/html,application/xhtml+xml;q=0.9,*/*;q=0.8", forHTTPHeaderField: "Accept") }
        let subresources = shouldFetchSubresources
        // the provider stays alive until it finishes, like Apple's
        track(session.dataTask(with: r) { data, response, error in
            if let error = error as? URLError {
                let code: LPError.Code = error.code == .cancelled ? .metadataFetchCancelled : error.code == .timedOut ? .metadataFetchTimedOut : .metadataFetchFailed
                self.finish(nil, LPError(code, error.localizedDescription)); return
            } else if let error { self.finish(nil, LPError(.metadataFetchFailed, error.localizedDescription)); return }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 200
            guard status < 400 else { self.finish(nil, LPError(.metadataFetchFailed, "HTTP \(status)")); return }
            let final = response?.url ?? url
            m.url = final
            let data = data ?? Data()
            if (response?.mimeType ?? "").lowercased().hasPrefix("image/") {      // a link straight to an image: the image is the preview
                m.title = final.lastPathComponent
                if subresources, let img = UIImage(data: data) { m._image = img; m.imageProvider = NSItemProvider(object: img) }
                self.finish(m, nil); return
            }
            let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
            let page = _LPPage.parse(html, base: final)
            m.title = page.title
            m.remoteVideoURL = page.video
            guard subresources else { self.finish(m, nil); return }
            self.fetchSubresources(page, into: m, session: session)
        })
    }
    private func fetchSubresources(_ page: _LPPage.Page, into m: LPLinkMetadata, session: URLSession) {
        let group = DispatchGroup()
        let mlock = NSLock()
        for (u, isIcon) in [(page.icon, true), (page.image, false)] {
            guard let u else { continue }
            group.enter()
            track(session.dataTask(with: u) { data, response, error in
                let status = (response as? HTTPURLResponse)?.statusCode ?? 200
                if error == nil, status < 400, let data, !data.isEmpty, let img = UIImage(data: data) {
                    mlock.lock()
                    if isIcon { m._icon = img; m.iconProvider = NSItemProvider(object: img) } else { m._image = img; m.imageProvider = NSItemProvider(object: img) }
                    mlock.unlock()
                }
                group.leave()
            })
        }
        group.notify(queue: .global()) { self.finish(m, nil) }
    }
}

// MARK: - LPLinkView

@objc(LPLinkView) open class LPLinkView: UIView {
    private static let radius: CGFloat = 14, pad: CGFloat = 12
    private var _metadata = LPLinkMetadata()
    private let card = UIView(), imageView = UIImageView(), iconView = UIImageView(), titleLabel = UILabel(), hostLabel = UILabel()
    private var placeholder = false

    /// a placeholder for the URL until metadata is set
    @objc(initWithURL:) public init(url: URL) {
        super.init(frame: .zero)
        setUp()
        let m = LPLinkMetadata()
        m.url = url; m.originalURL = url
        placeholder = true
        apply(m)
    }
    @available(*, deprecated, renamed: "init(url:)")
    public convenience init(URL: URL) { self.init(url: URL) }
    @objc(initWithMetadata:) public init(metadata: LPLinkMetadata) {
        super.init(frame: .zero)
        setUp()
        apply(metadata.copy() as! LPLinkMetadata)
    }
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
        apply(LPLinkMetadata())
    }
    @available(*, unavailable) public required init?(coder: NSCoder) { fatalError("LPLinkView does not support NSCoding") }

    @objc open var metadata: LPLinkMetadata {
        get { _metadata.copy() as! LPLinkMetadata }
        set { placeholder = false; apply(newValue.copy() as! LPLinkMetadata) }
    }

    private func setUp() {
        backgroundColor = .clear
        card.backgroundColor = .secondarySystemBackground
        card.layer.cornerRadius = Self.radius
        card.clipsToBounds = true
        card.isUserInteractionEnabled = false
        addSubview(card)
        imageView.contentMode = .scaleAspectFill; imageView.clipsToBounds = true
        iconView.contentMode = .scaleAspectFit; iconView.clipsToBounds = true; iconView.layer.cornerRadius = 8
        titleLabel.font = .systemFont(ofSize: 15, weight: .semibold); titleLabel.numberOfLines = 2
        hostLabel.font = .systemFont(ofSize: 13); hostLabel.textColor = .secondaryLabel
        [imageView, iconView, titleLabel, hostLabel].forEach { card.addSubview($0) }
        isAccessibilityElement = true
        accessibilityTraits = .link
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(open)))
    }
    private func apply(_ m: LPLinkMetadata) {
        _metadata = m
        var host = (m.url ?? m.originalURL).map { $0.host ?? $0.absoluteString } ?? ""
        if host.hasPrefix("www.") { host = String(host.dropFirst(4)) }
        let title = m.title.flatMap { $0.isEmpty ? nil : $0 }
        titleLabel.text = title ?? host
        hostLabel.text = title == nil ? nil : host
        titleLabel.textColor = placeholder ? .secondaryLabel : .label
        imageView.image = m._image
        iconView.image = m._icon
        accessibilityLabel = titleLabel.text
        // metadata the app built itself: load its providers' images
        if m._image == nil, let p = m.imageProvider, p.canLoadObject(ofClass: UIImage.self) {
            let view = _LPWeak(self)
            _ = p.loadObject(ofClass: UIImage.self) { img, _ in
                guard let img = img as? UIImage else { return }
                DispatchQueue.main.async { guard let v = view.view, v._metadata === m else { return }; m._image = img; v.imageView.image = img; v.changed() }
            }
        }
        if m._icon == nil, let p = m.iconProvider, p.canLoadObject(ofClass: UIImage.self) {
            let view = _LPWeak(self)
            _ = p.loadObject(ofClass: UIImage.self) { img, _ in
                guard let img = img as? UIImage else { return }
                DispatchQueue.main.async { guard let v = view.view, v._metadata === m else { return }; m._icon = img; v.iconView.image = img; v.changed() }
            }
        }
        changed()
    }
    private func changed() {
        if iconView.image == nil && imageView.image == nil {          // no icon: Safari's compass
            iconView.image = UIImage(systemName: "safari")?.withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
        }
        invalidateIntrinsicContentSize()
        setNeedsLayout()
        superview?.setNeedsLayout()            // a card that grows (an image loaded later) asks its container to lay out again
    }
    private var large: Bool { imageView.image != nil }
    private func titleHeight(_ w: CGFloat) -> CGFloat {
        min(titleLabel.sizeThatFits(CGSize(width: max(w, 1), height: .greatestFiniteMagnitude)).height, ceil(titleLabel.font.lineHeight * 2))
    }
    private func textHeight(_ w: CGFloat) -> CGFloat {
        titleHeight(w) + (hostLabel.text?.isEmpty == false ? 2 + ceil(hostLabel.font.lineHeight) : 0)
    }
    private func imageHeight(_ w: CGFloat) -> CGFloat {
        guard let s = imageView.image?.size, s.width > 0 else { return round(w / 1.91) }
        return round(min(w, max(w / 1.91, w * s.height / s.width)))     // up to 1.91:1, at most as tall as wide
    }
    /// the card's height for a width: an image above two lines of text, or one row with the icon
    private func height(_ w: CGFloat) -> CGFloat {
        large ? imageHeight(w) + textHeight(w - 2 * Self.pad) + 2 * Self.pad : max(64, textHeight(w - 2 * Self.pad - 52) + 2 * Self.pad)
    }
    open override func sizeThatFits(_ size: CGSize) -> CGSize {
        let w = size.width > 0 && size.width < .greatestFiniteMagnitude ? size.width : 300
        return CGSize(width: w, height: height(w))
    }
    open override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: height(bounds.width > 0 ? bounds.width : 300))
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds.size, pad = Self.pad
        card.frame = bounds
        if large {
            iconView.isHidden = true; imageView.isHidden = false
            let w = b.width - 2 * pad
            let ih = max(0, b.height - textHeight(w) - 2 * pad)
            imageView.frame = CGRect(x: 0, y: 0, width: b.width, height: ih)
            titleLabel.frame = CGRect(x: pad, y: ih + pad, width: w, height: titleHeight(w))
        } else {
            imageView.isHidden = true; iconView.isHidden = false
            let side: CGFloat = 40, w = b.width - 2 * pad - side - 12
            iconView.frame = CGRect(x: b.width - pad - side, y: (b.height - side) / 2, width: side, height: side)
            titleLabel.frame = CGRect(x: pad, y: (b.height - textHeight(w)) / 2, width: w, height: titleHeight(w))
        }
        hostLabel.frame = CGRect(x: pad, y: titleLabel.frame.maxY + 2, width: titleLabel.frame.width, height: ceil(hostLabel.font.lineHeight))
    }
    @objc private func open() {
        guard let u = _metadata.url ?? _metadata.originalURL else { return }
        UIApplication.shared.open(u)
    }
}

/// a link view an image load finishes for (on the main queue)
final class _LPWeak: @unchecked Sendable {
    weak var view: LPLinkView?
    init(_ v: LPLinkView) { view = v }
}
