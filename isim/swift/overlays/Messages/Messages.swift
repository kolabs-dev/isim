// isim Messages (adapted): iMessage apps and sticker packs, hosted by isim's Messages app (system/Messages), which
// loads an app's Messages extension (com.apple.message-payload-provider) into its process, like iOS's Messages runs
// it: the extension's MSMessagesAppViewController shows in the compact area under the transcript or expanded, and
// gets its conversation through the lifecycle callbacks. MSConversation's insert… puts the content in the compose
// field (the user sends it; didStartSending / didCancelSending), send… sends it at once (iOS 11: only while the app
// is visible and right after the user touched it, else sendWhileNotVisible / sendWithoutRecentInteraction). Messages
// with a session replace the session's earlier bubbles in the transcript. MSSticker checks its file like iOS (a PNG,
// APNG, GIF or JPEG of at most 500 KB). MSStickerView inserts its sticker when tapped; MSStickerBrowserView is a
// grid of them. Stubs, like Apple's Simulator: MSCriticalSMSMessenger (no SMS: notSupported), MSUPIRequest (no UPI
// payments). Objective-C: sdk-src/Frameworks/Messages (the classes are this overlay's).
import Foundation
import UIKit
import ImageIO

// MARK: - constants

public let MSMessagesErrorDomain: String = "com.apple.messages.messagesErrorDomain"
public let MSStickersErrorDomain: String = "com.apple.messages.stickersErrorDomain"

@objc public enum MSMessageErrorCode: Int, Sendable {
    case unknown = -1
    case fileNotFound = 1
    case fileUnreadable = 2
    case improperFileType = 3
    case improperFileURL = 4
    case stickerFileImproperFileAttributes = 5
    case stickerFileImproperFileSize = 6
    case stickerFileImproperFileFormat = 7
    case urlExceedsMaxSize = 8
    case sendWhileNotVisible = 9
    case sendWithoutRecentInteraction = 10
    case apiUnavailableInPresentationContext = 11
}
func _msError(_ code: MSMessageErrorCode, _ why: String, stickers: Bool = false) -> NSError {
    NSError(domain: stickers ? MSStickersErrorDomain : MSMessagesErrorDomain, code: code.rawValue, userInfo: [NSLocalizedDescriptionKey: why])
}

@objc public enum MSMessagesAppPresentationStyle: UInt, Sendable { case compact = 0, expanded = 1, transcript = 2 }
@objc public enum MSMessagesAppPresentationContext: UInt, Sendable { case messages = 0, media = 1 }
@objc public enum MSStickerSize: Int, Sendable { case small = 0, regular = 1, large = 2 }

// MARK: - sessions, messages, layouts

@objc(MSSession) open class MSSession: NSObject, NSSecureCoding, @unchecked Sendable {
    /// the session's identity (the same session on every device of the conversation)
    public let _isimID: UUID
    public override init() { _isimID = UUID(); super.init() }
    public init(_isimID id: UUID) { _isimID = id; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        guard let s = coder.decodeObject(of: NSString.self, forKey: "id") as String?, let u = UUID(uuidString: s) else { return nil }
        _isimID = u; super.init()
    }
    open func encode(with coder: NSCoder) { coder.encode(_isimID.uuidString as NSString, forKey: "id") }
    open override func isEqual(_ object: Any?) -> Bool { (object as? MSSession)?._isimID == _isimID }
    open override var hash: Int { _isimID.hashValue }
}

@objc(MSMessageLayout) open class MSMessageLayout: NSObject, NSCopying, @unchecked Sendable {
    public override init() { super.init() }
    open func copy(with zone: NSZone? = nil) -> Any { MSMessageLayout() }
}

@objc(MSMessageTemplateLayout) open class MSMessageTemplateLayout: MSMessageLayout, @unchecked Sendable {
    @objc open var image: UIImage?
    @objc open var mediaFileURL: URL?
    @objc open var imageTitle: String?
    @objc open var imageSubtitle: String?
    @objc open var caption: String?
    @objc open var subcaption: String?
    @objc open var trailingCaption: String?
    @objc open var trailingSubcaption: String?
    public override init() { super.init() }
    open override func copy(with zone: NSZone? = nil) -> Any {
        let c = MSMessageTemplateLayout()
        c.image = image; c.mediaFileURL = mediaFileURL; c.imageTitle = imageTitle; c.imageSubtitle = imageSubtitle
        c.caption = caption; c.subcaption = subcaption; c.trailingCaption = trailingCaption; c.trailingSubcaption = trailingSubcaption
        return c
    }
}

/// a layout the app draws itself in the transcript (its MSMessagesAppViewController in the transcript style); the
/// alternate layout is what devices that cannot run the app show
@objc(MSMessageLiveLayout) open class MSMessageLiveLayout: MSMessageLayout, @unchecked Sendable {
    @objc open var alternateLayout: MSMessageTemplateLayout { _alternate }
    let _alternate: MSMessageTemplateLayout
    @objc public init(alternateLayout: MSMessageTemplateLayout) { _alternate = alternateLayout; super.init() }
    open override func copy(with zone: NSZone? = nil) -> Any { MSMessageLiveLayout(alternateLayout: _alternate.copy() as! MSMessageTemplateLayout) }
}

@objc(MSMessage) open class MSMessage: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
    @objc open private(set) var session: MSSession?
    @objc @NSCopying open var layout: MSMessageLayout?
    @objc(URL) open var url: URL?
    @objc open var shouldExpire = false
    /// its own label (what VoiceOver reads for the bubble), not NSObject's UIAccessibility one
    open override var accessibilityLabel: String? { get { label } set { label = newValue } }
    var label: String?
    @objc open var summaryText: String?
    @objc open var error: (any Error)?
    @objc open var senderParticipantIdentifier: UUID { _sender }
    @objc open var isPending: Bool { _pending }
    public var _sender = UUID()
    public var _pending = true
    /// the iMessage app that made it (its extension's bundle identifier); set by the Messages app
    public var _isimApp: String?
    public override init() { super.init() }
    @objc public init(session: MSSession) { self.session = session; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public required init?(coder: NSCoder) {
        session = coder.decodeObject(of: MSSession.self, forKey: "session")
        url = coder.decodeObject(of: NSURL.self, forKey: "url") as URL?
        shouldExpire = coder.decodeBool(forKey: "shouldExpire")
        label = coder.decodeObject(of: NSString.self, forKey: "accessibilityLabel") as String?
        summaryText = coder.decodeObject(of: NSString.self, forKey: "summaryText") as String?
        if let s = coder.decodeObject(of: NSString.self, forKey: "sender") as String?, let u = UUID(uuidString: s) { _sender = u }
        super.init()
    }
    open func encode(with coder: NSCoder) {
        coder.encode(session, forKey: "session")
        coder.encode(url as NSURL?, forKey: "url")
        coder.encode(shouldExpire, forKey: "shouldExpire")
        coder.encode(accessibilityLabel as NSString?, forKey: "accessibilityLabel")
        coder.encode(summaryText as NSString?, forKey: "summaryText")
        coder.encode(_sender.uuidString as NSString, forKey: "sender")
    }
    open func copy(with zone: NSZone? = nil) -> Any {
        let m = session.map { MSMessage(session: $0) } ?? MSMessage()
        m.layout = layout; m.url = url; m.shouldExpire = shouldExpire; m.accessibilityLabel = accessibilityLabel
        m.summaryText = summaryText; m.error = error; m._sender = _sender; m._pending = _pending; m._isimApp = _isimApp
        return m
    }
}

// MARK: - stickers

@objc(MSSticker) open class MSSticker: NSObject, @unchecked Sendable {
    @objc open var imageFileURL: URL { _url }
    @objc open var localizedDescription: String { _description }
    let _url: URL, _description: String
    /// the file checks of iOS: a file URL to a PNG, APNG, GIF or JPEG of at most 500 KB
    @objc(initWithContentsOfFileURL:localizedDescription:error:)
    public init(contentsOfFileURL fileURL: URL, localizedDescription: String) throws {
        guard fileURL.isFileURL else { throw _msError(.improperFileURL, "\(fileURL) is not a file URL", stickers: true) }
        let path = fileURL.path
        guard FileManager.default.fileExists(atPath: path) else { throw _msError(.fileNotFound, "no file at \(path)", stickers: true) }
        guard FileManager.default.isReadableFile(atPath: path), let data = FileManager.default.contents(atPath: path) else {
            throw _msError(.fileUnreadable, "cannot read \(path)", stickers: true)
        }
        guard data.count <= 500 * 1024 else { throw _msError(.stickerFileImproperFileSize, "\(path) is larger than 500 KB", stickers: true) }
        let b = [UInt8](data.prefix(8))
        let png = b.starts(with: [0x89, 0x50, 0x4E, 0x47]), gif = b.starts(with: [0x47, 0x49, 0x46]), jpeg = b.starts(with: [0xFF, 0xD8, 0xFF])
        guard png || gif || jpeg else { throw _msError(.stickerFileImproperFileFormat, "\(path) is not a PNG, APNG, GIF or JPEG", stickers: true) }
        _url = fileURL; _description = localizedDescription
        super.init()
    }
    /// the frames (more than one for an animated PNG or GIF) and their total duration
    var _frames: (images: [UIImage], duration: TimeInterval) {
        guard let src = CGImageSourceCreateWithURL(_url as CFURL, nil) else { return ([], 0) }
        let n = CGImageSourceGetCount(src)
        var images: [UIImage] = [], total: TimeInterval = 0
        for i in 0..<n {
            guard let cg = CGImageSourceCreateImageAtIndex(src, i, nil) else { continue }
            images.append(UIImage(cgImage: cg))
            let p = CGImageSourceCopyPropertiesAtIndex(src, i, nil) as? [CFString: Any]
            let gif = p?[kCGImagePropertyGIFDictionary] as? [CFString: Any], apng = p?[kCGImagePropertyPNGDictionary] as? [CFString: Any]
            total += (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? (apng?[kCGImagePropertyAPNGDelayTime] as? Double) ?? (n > 1 ? 0.1 : 0)
        }
        if images.isEmpty, let i = UIImage(contentsOfFile: _url.path) { images = [i] }
        return (images, total)
    }
}

/// shows a sticker: tapping it puts it in the compose field (MSConversation.insert)
@objc(MSStickerView) open class MSStickerView: UIView {
    @objc open var sticker: MSSticker? { didSet { load() } }
    @objc open var animationDuration: TimeInterval { duration }
    let imageView = UIImageView()
    var frames: [UIImage] = [], duration: TimeInterval = 0
    @objc public init(frame: CGRect, sticker: MSSticker?) {
        super.init(frame: frame)
        setUp()
        self.sticker = sticker
        load()
    }
    public override init(frame: CGRect) { super.init(frame: frame); setUp() }
    public required init?(coder: NSCoder) { super.init(coder: coder); setUp() }
    func setUp() {
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        isUserInteractionEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(_isimTapped)))
    }
    func load() {
        let f: (images: [UIImage], duration: TimeInterval) = sticker?._frames ?? ([], 0)
        frames = f.images; duration = f.duration
        imageView.image = frames.first
        accessibilityLabel = sticker?.localizedDescription
    }
    @objc open func startAnimating() {
        guard frames.count > 1 else { return }
        imageView.animationImages = frames; imageView.animationDuration = duration; imageView.startAnimating()
    }
    @objc open func stopAnimating() { imageView.stopAnimating() }
    @objc open func isAnimating() -> Bool { imageView.isAnimating }
    @objc func _isimTapped() {
        guard let s = sticker else { return }
        guard let c = _MSActive.conversation else { NSLog("isim Messages: a sticker tapped outside Messages: nothing to insert it into"); return }
        c.insert(s) { e in if let e { NSLog("isim Messages: inserting the sticker failed: %@", "\(e)") } }
    }
}

@objc public protocol MSStickerBrowserViewDataSource: NSObjectProtocol {
    @objc(numberOfStickersInStickerBrowserView:) func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int
    @objc(stickerBrowserView:stickerAtIndex:) func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker
}

/// a scrolling grid of the data source's stickers (small: 4 a row, regular: 3, large: 2 on iPhone)
@objc(MSStickerBrowserView) open class MSStickerBrowserView: UIView {
    @objc open weak var dataSource: (any MSStickerBrowserViewDataSource)? { didSet { reloadData() } }
    @objc open var stickerSize: MSStickerSize { size }
    let size: MSStickerSize
    let scroll = UIScrollView()
    var cells: [MSStickerView] = []
    @objc open var contentOffset: CGPoint { get { scroll.contentOffset } set { scroll.contentOffset = newValue } }
    @objc open var contentInset: UIEdgeInsets { get { scroll.contentInset } set { scroll.contentInset = newValue; setNeedsLayout() } }
    public override init(frame: CGRect) { size = .regular; super.init(frame: frame); setUp() }
    @objc public init(frame: CGRect, stickerSize: MSStickerSize) { size = stickerSize; super.init(frame: frame); setUp() }
    public required init?(coder: NSCoder) { size = .regular; super.init(coder: coder); setUp() }
    func setUp() {
        scroll.frame = bounds
        scroll.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scroll.alwaysBounceVertical = true
        addSubview(scroll)
    }
    @objc open func setContentOffset(_ contentOffset: CGPoint, animated: Bool) { scroll.setContentOffset(contentOffset, animated: animated) }
    @objc open func reloadData() {
        cells.forEach { $0.removeFromSuperview() }
        cells = []
        guard let ds = dataSource else { return }
        for i in 0..<ds.numberOfStickers(in: self) {
            let v = MSStickerView(frame: .zero, sticker: ds.stickerBrowserView(self, stickerAt: i))
            v.accessibilityIdentifier = "sticker-\(i)"
            scroll.addSubview(v)
            cells.append(v)
        }
        setNeedsLayout()
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        let columns = CGFloat(size == .small ? 4 : size == .regular ? 3 : 2), gap: CGFloat = 8
        let width = scroll.bounds.width - contentInset.left - contentInset.right
        let side = max(1, (width - gap * (columns + 1)) / columns)
        for (i, v) in cells.enumerated() {
            let r = CGFloat(i / Int(columns)), c = CGFloat(i % Int(columns))
            v.frame = CGRect(x: gap + c * (side + gap), y: gap + r * (side + gap), width: side, height: side)
        }
        let rows = (CGFloat(cells.count) / columns).rounded(.up)
        scroll.contentSize = CGSize(width: width, height: gap + rows * (side + gap))
    }
}

@objc(MSStickerBrowserViewController) open class MSStickerBrowserViewController: UIViewController, MSStickerBrowserViewDataSource, NSExtensionRequestHandling {
    @objc open var stickerSize: MSStickerSize { size }
    let size: MSStickerSize
    @objc open var stickerBrowserView: MSStickerBrowserView { loadViewIfNeeded(); return browser! }
    var browser: MSStickerBrowserView?
    @objc public init(stickerSize: MSStickerSize) { size = stickerSize; super.init(nibName: nil, bundle: nil) }
    public required init?(coder: NSCoder) { size = .regular; super.init(coder: coder) }
    open override func loadView() {
        let b = MSStickerBrowserView(frame: UIScreen.main.bounds, stickerSize: size)
        browser = b
        view = b
        b.dataSource = self
    }
    open func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int { 0 }
    open func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        fatalError("MSStickerBrowserViewController: override stickerBrowserView(_:stickerAt:)")
    }
    open func beginRequest(with context: NSExtensionContext) {}
}

// MARK: - the conversation

/// What isim's Messages app does for its extensions (system/Messages implements it).
public protocol _IsimMessagesHost: AnyObject {
    /// insert… (stage == true: into the compose field) or send…; nil or the error
    func _isimPut(_ item: _IsimMessagesItem, stage: Bool, from conversation: MSConversation) -> (any Error)?
    func _isimRequestStyle(_ style: MSMessagesAppPresentationStyle, for controller: MSMessagesAppViewController)
    func _isimDismiss(_ controller: MSMessagesAppViewController)
    func _isimTintChanged(_ controller: MSMessagesAppViewController)
}
@frozen public enum _IsimMessagesItem {
    case text(String)
    case sticker(MSSticker)
    case attachment(URL, String?)
    case message(MSMessage)
}
/// the active conversation of the visible extension (MSStickerView inserts into it)
public enum _MSActive { nonisolated(unsafe) public static weak var conversation: MSConversation? }

@objc(MSConversation) open class MSConversation: NSObject, @unchecked Sendable {
    @objc open var localParticipantIdentifier: UUID { local }
    @objc open var remoteParticipantIdentifiers: [UUID] { remote }
    @objc open var selectedMessage: MSMessage? { selected }
    let local: UUID, remote: [UUID]
    public var selected: MSMessage?
    weak var host: (any _IsimMessagesHost)?
    public weak var _isimController: MSMessagesAppViewController?
    public init(_isimHost host: any _IsimMessagesHost, local: UUID, remote: [UUID], selected: MSMessage?) {
        self.host = host; self.local = local; self.remote = remote; self.selected = selected
        super.init()
    }

    func put(_ item: _IsimMessagesItem, stage: Bool, _ completion: (@Sendable ((any Error)?) -> Void)?) {
        var error: (any Error)?
        if let c = _isimController, c.presentationContext == .media {
            error = _msError(.apiUnavailableInPresentationContext, "not available in the media context")
        } else if case .message(let m) = item, let u = m.url, u.absoluteString.utf8.count > 5000 {
            error = _msError(.urlExceedsMaxSize, "the message's URL is longer than 5000 bytes")
        } else if case .attachment(let u, _) = item, !u.isFileURL {
            error = _msError(.improperFileURL, "\(u) is not a file URL")
        } else if case .attachment(let u, _) = item, !FileManager.default.fileExists(atPath: u.path) {
            error = _msError(.fileNotFound, "no file at \(u.path)")
        } else if let h = host {
            error = h._isimPut(item, stage: stage, from: self)
        } else {
            error = _msError(.unknown, "the conversation is no longer in Messages")
        }
        let e = error
        DispatchQueue.main.async { completion?(e) }
    }
    @objc(insertMessage:completionHandler:) open func insert(_ message: MSMessage, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.message(message), stage: true, completionHandler)
    }
    @objc(insertSticker:completionHandler:) open func insert(_ sticker: MSSticker, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.sticker(sticker), stage: true, completionHandler)
    }
    @objc(insertText:completionHandler:) open func insertText(_ text: String, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.text(text), stage: true, completionHandler)
    }
    @objc(insertAttachment:withAlternateFilename:completionHandler:)
    open func insertAttachment(_ URL: URL, withAlternateFilename filename: String?, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.attachment(URL, filename), stage: true, completionHandler)
    }
    @objc(sendMessage:completionHandler:) open func send(_ message: MSMessage, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.message(message), stage: false, completionHandler)
    }
    @objc(sendSticker:completionHandler:) open func send(_ sticker: MSSticker, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.sticker(sticker), stage: false, completionHandler)
    }
    @objc(sendText:completionHandler:) open func sendText(_ text: String, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.text(text), stage: false, completionHandler)
    }
    @objc(sendAttachment:withAlternateFilename:completionHandler:)
    open func sendAttachment(_ URL: URL, withAlternateFilename filename: String?, completionHandler: (@Sendable ((any Error)?) -> Void)? = nil) {
        put(.attachment(URL, filename), stage: false, completionHandler)
    }

    func async(_ body: (@escaping @Sendable ((any Error)?) -> Void) -> Void) async throws {
        try await withCheckedThrowingContinuation { (k: CheckedContinuation<Void, any Error>) in
            body { e in if let e { k.resume(throwing: e) } else { k.resume() } }
        }
    }
    @nonobjc open func insert(_ message: MSMessage) async throws { try await async { insert(message, completionHandler: $0) } }
    @nonobjc open func insert(_ sticker: MSSticker) async throws { try await async { insert(sticker, completionHandler: $0) } }
    @nonobjc open func insertText(_ text: String) async throws { try await async { insertText(text, completionHandler: $0) } }
    @nonobjc open func insertAttachment(_ URL: URL, withAlternateFilename filename: String?) async throws {
        try await async { insertAttachment(URL, withAlternateFilename: filename, completionHandler: $0) }
    }
    @nonobjc open func send(_ message: MSMessage) async throws { try await async { send(message, completionHandler: $0) } }
    @nonobjc open func send(_ sticker: MSSticker) async throws { try await async { send(sticker, completionHandler: $0) } }
    @nonobjc open func sendText(_ text: String) async throws { try await async { sendText(text, completionHandler: $0) } }
    @nonobjc open func sendAttachment(_ URL: URL, withAlternateFilename filename: String?) async throws {
        try await async { sendAttachment(URL, withAlternateFilename: filename, completionHandler: $0) }
    }
}

// MARK: - the app's view controller

@objc public protocol MSMessagesAppTranscriptPresentation {
    @objc(contentSizeThatFits:) func contentSizeThatFits(_ size: CGSize) -> CGSize
    @available(iOS 26.0, *) var messageCornerRadius: CGFloat { get }
    @available(iOS 26.0, *) var messageTintColor: UIColor? { get }
    @available(iOS 26.0, *) func invalidateMessageTintColor()
}

@objc(MSMessagesAppViewController) open class MSMessagesAppViewController: UIViewController, MSMessagesAppTranscriptPresentation, NSExtensionRequestHandling {
    @objc open var activeConversation: MSConversation? { conversation }
    @objc open var presentationStyle: MSMessagesAppPresentationStyle { style }
    @objc open var presentationContext: MSMessagesAppPresentationContext { .messages }
    var conversation: MSConversation?
    var style: MSMessagesAppPresentationStyle = .compact
    public weak var _isimHost: (any _IsimMessagesHost)?
    /// the Messages app sets the conversation and the style before it calls the lifecycle methods
    public func _isimSet(conversation c: MSConversation?) { conversation = c; c?._isimController = self; if c != nil { _MSActive.conversation = c } }
    public func _isimSet(style s: MSMessagesAppPresentationStyle) { style = s }

    @objc open func requestPresentationStyle(_ presentationStyle: MSMessagesAppPresentationStyle) {
        guard presentationStyle != .transcript else { NSLog("isim Messages: the transcript style cannot be requested"); return }
        _isimHost?._isimRequestStyle(presentationStyle, for: self)
    }
    @objc(dismiss) open func dismiss() { _isimHost?._isimDismiss(self) }

    @objc(willBecomeActiveWithConversation:) open func willBecomeActive(with conversation: MSConversation) {}
    @objc(didBecomeActiveWithConversation:) open func didBecomeActive(with conversation: MSConversation) {}
    @objc(willResignActiveWithConversation:) open func willResignActive(with conversation: MSConversation) {}
    @objc(didResignActiveWithConversation:) open func didResignActive(with conversation: MSConversation) {}
    @objc(willSelectMessage:conversation:) open func willSelect(_ message: MSMessage, conversation: MSConversation) {}
    @objc(didSelectMessage:conversation:) open func didSelect(_ message: MSMessage, conversation: MSConversation) {}
    @objc(didReceiveMessage:conversation:) open func didReceive(_ message: MSMessage, conversation: MSConversation) {}
    @objc(didStartSendingMessage:conversation:) open func didStartSending(_ message: MSMessage, conversation: MSConversation) {}
    @objc(didCancelSendingMessage:conversation:) open func didCancelSending(_ message: MSMessage, conversation: MSConversation) {}
    @objc(willTransitionToPresentationStyle:) open func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}
    @objc(didTransitionToPresentationStyle:) open func didTransition(to presentationStyle: MSMessagesAppPresentationStyle) {}

    @objc(contentSizeThatFits:) open func contentSizeThatFits(_ size: CGSize) -> CGSize { size }
    @available(iOS 26.0, *) @objc open var messageCornerRadius: CGFloat { 18 }
    @available(iOS 26.0, *) @objc open var messageTintColor: UIColor? { nil }
    @available(iOS 26.0, *) @objc open func invalidateMessageTintColor() { _isimHost?._isimTintChanged(self) }
    open func beginRequest(with context: NSExtensionContext) {}
}

// MARK: - stubs: critical SMS (iOS 18.2) and UPI payments (iOS 27)

@available(iOS 18.2, *)
public struct MSRecipient: Hashable, Sendable {
    public var phoneNumber: String
    public init(phoneNumber: String) { self.phoneNumber = phoneNumber }
}
@available(iOS 18.2, *)
public struct MSCriticalMessage: Sendable {
    public var messageText: String
    public init(messageText: String) { self.messageText = messageText }
}
@available(iOS 18.2, *)
public enum MSCriticalMessagingAuthorizationStatus: Int, Hashable, Sendable { case unknown = 0, denied = 1, approved = 2 }
@available(iOS 18.2, *)
public enum MSCriticalMessagingError: Int, Error, CustomNSError, LocalizedError, Hashable, Sendable {
    case unknown = 0, invalidAuthenticationRequest, notSupported, notAuthorized, sendFailed
    public static var errorDomain: String { "MSCriticalMessagingErrorDomain" }
    public var errorCode: Int { rawValue }
    public var errorDescription: String? {
        switch self {
        case .notSupported: return "Critical messaging is not supported on this device"
        case .notAuthorized: return "The recipients have not approved critical messages"
        case .invalidAuthenticationRequest: return "The authentication request is not valid"
        case .sendFailed: return "The message could not be sent"
        case .unknown: return "An unknown error occurred"
        }
    }
}
/// critical SMS (emergency alerts over satellite or cellular): isim has no SMS, like the Simulator
@available(iOS 18.2, *)
@objc(MSCriticalSMSMessenger) public class MSCriticalSMSMessenger: NSObject, @unchecked Sendable {
    public override init() { super.init() }
    public var maximumCriticalMessagingRecipients: Int { 0 }
    public func requestAuthorization(for recipients: [MSRecipient]) async throws -> [MSRecipient: MSCriticalMessagingAuthorizationStatus] {
        NSLog("isim Messages: critical messaging is not supported (no SMS on isim)"); throw MSCriticalMessagingError.notSupported
    }
    public func checkAuthorizationStatus(for recipients: [MSRecipient]) async throws -> [MSRecipient: MSCriticalMessagingAuthorizationStatus] {
        throw MSCriticalMessagingError.notSupported
    }
    public func send(_ message: MSCriticalMessage, to recipient: MSRecipient) async throws -> Bool { throw MSCriticalMessagingError.notSupported }
}
/// a UPI payment verification message (India): isim sends none
@available(iOS 27.0, *)
@objc(MSUPIRequest) open class MSUPIRequest: NSObject, @unchecked Sendable {
    @objc open var validationToken: String { token }
    @objc open var recipients: [String] { to }
    let token: String, to: [String]
    @objc public init(validationToken: String, recipients: [String]) { token = validationToken; to = recipients; super.init() }
    @objc(sendWithCompletionHandler:) open func send(completionHandler: @escaping @Sendable (Bool) -> Void) {
        NSLog("isim Messages: UPI requests are not sent on isim")
        DispatchQueue.main.async { completionHandler(false) }
    }
    @nonobjc open func send() async -> Bool { await withCheckedContinuation { k in send { k.resume(returning: $0) } } }
}
