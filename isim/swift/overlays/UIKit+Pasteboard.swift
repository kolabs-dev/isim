// isim UIKit overlay: the pasteboard's Swift API (self-authored) — pattern detection with Result and async forms,
// item providers and setObjects, and the iOS 16 paste control: UIPasteConfiguration, UIPasteConfigurationSupporting
// (UIResponder conforms) and UIPasteControl. A paste control reads the pasteboard as a user paste (no paste prompt),
// is enabled while the pasteboard has a type its target accepts, and hands the target item providers.
import ObjectiveC
@_exported import UniformTypeIdentifiers

// MARK: - detection
extension UIPasteboard {
    public func detectPatterns(for patterns: Set<UIPasteboard.DetectionPattern>,
                               completionHandler: @escaping (Result<Set<UIPasteboard.DetectionPattern>, Error>) -> Void) {
        __detectPatterns(forPatterns: patterns) { found, error in
            if let found { completionHandler(.success(found)) } else { completionHandler(.failure(error ?? NSError(domain: "UIPasteboardErrorDomain", code: -1))) }
        }
    }
    public func detectPatterns(for patterns: Set<UIPasteboard.DetectionPattern>, inItemSet itemSet: IndexSet?,
                               completionHandler: @escaping (Result<[Set<UIPasteboard.DetectionPattern>], Error>) -> Void) {
        __detectPatterns(forPatterns: patterns, inItemSet: itemSet) { found, error in
            if let found { completionHandler(.success(found)) } else { completionHandler(.failure(error ?? NSError(domain: "UIPasteboardErrorDomain", code: -1))) }
        }
    }
    public func detectValues(for patterns: Set<UIPasteboard.DetectionPattern>,
                             completionHandler: @escaping (Result<[UIPasteboard.DetectionPattern: Any], Error>) -> Void) {
        __detectValues(forPatterns: patterns) { found, error in
            if let found { completionHandler(.success(found)) } else { completionHandler(.failure(error ?? NSError(domain: "UIPasteboardErrorDomain", code: -1))) }
        }
    }
    public func detectValues(for patterns: Set<UIPasteboard.DetectionPattern>, inItemSet itemSet: IndexSet?,
                             completionHandler: @escaping (Result<[[UIPasteboard.DetectionPattern: Any]], Error>) -> Void) {
        __detectValues(forPatterns: patterns, inItemSet: itemSet) { found, error in
            if let found { completionHandler(.success(found)) } else { completionHandler(.failure(error ?? NSError(domain: "UIPasteboardErrorDomain", code: -1))) }
        }
    }
    public func detectedPatterns(for patterns: Set<UIPasteboard.DetectionPattern>) async throws -> Set<UIPasteboard.DetectionPattern> {
        let box = _PasteboardBox(self)
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<Set<UIPasteboard.DetectionPattern>, Error>) in
            DispatchQueue.main.async { box.value.detectPatterns(for: patterns) { c.resume(with: $0) } }
        }
    }
    public func detectedValues(for patterns: Set<UIPasteboard.DetectionPattern>) async throws -> [UIPasteboard.DetectionPattern: Any] {
        let box = _PasteboardBox(self)
        let r: _UncheckedBox<[UIPasteboard.DetectionPattern: Any]> = try await withCheckedThrowingContinuation { c in
            DispatchQueue.main.async { box.value.detectValues(for: patterns) { c.resume(with: $0.map { _UncheckedBox($0) }) } }
        }
        return r.value
    }
}
struct _PasteboardBox: @unchecked Sendable { let value: UIPasteboard; init(_ v: UIPasteboard) { value = v } }

// MARK: - item providers
/// an item (type -> value) as an item provider with a data representation per type
func _isimItemProvider(_ item: [String: Any]) -> NSItemProvider {
    let p = NSItemProvider()
    for (type, value) in item {
        let data: Data?
        switch value {
        case let d as Data: data = d
        case let s as String: data = Data(s.utf8)
        case let u as URL: data = Data(u.absoluteString.utf8)
        case let i as UIImage: data = i.pngData()
        case let c as UIColor:
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            c.getRed(&r, green: &g, blue: &b, alpha: &a)
            data = Data("\(r) \(g) \(b) \(a)".utf8)
        default: data = nil
        }
        guard let data else { continue }
        p.registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { $0(data, nil); return nil }
    }
    return p
}
/// a provider's representations as an item (waits briefly for each one, like UIKit copying them onto the pasteboard)
func _isimItem(_ provider: NSItemProvider) -> [String: Any] {
    var item: [String: Any] = [:]
    for type in provider.registeredTypeIdentifiers where item[type] == nil {
        let done = DispatchSemaphore(value: 0)
        let out = _UncheckedBox(NSMutableArray())
        _ = provider.loadDataRepresentation(forTypeIdentifier: type) { d, _ in if let d { out.value.add(d) }; done.signal() }
        if done.wait(timeout: .now() + 2) == .timedOut { continue }
        guard let d = out.value.firstObject as? Data else { continue }
        if UTType(type)?.conforms(to: .text) == true || type == UTType.utf8PlainText.identifier { item[type] = String(decoding: d, as: UTF8.self) }
        else if type == UTType.url.identifier, let u = URL(string: String(decoding: d, as: UTF8.self)) { item[type] = u }
        else { item[type] = d }
    }
    return item
}
extension UIPasteboard {
    /// the items as item providers (reading them is a paste: another app's content asks first)
    public var itemProviders: [NSItemProvider] {
        get { items.map { _isimItemProvider($0) } }
        set { items = newValue.map { _isimItem($0) } }
    }
    public func setItemProviders(_ itemProviders: [NSItemProvider], localOnly: Bool, expirationDate: Date?) {
        var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: localOnly]
        if let expirationDate { options[.expirationDate] = expirationDate }
        setItems(itemProviders.map { _isimItem($0) }, options: options)
    }
    public func setObjects(_ objects: [NSItemProviderWriting]) { itemProviders = objects.map { NSItemProvider(object: $0) } }
    public func setObjects(_ objects: [NSItemProviderWriting], localOnly: Bool, expirationDate: Date?) {
        setItemProviders(objects.map { NSItemProvider(object: $0) }, localOnly: localOnly, expirationDate: expirationDate)
    }
    public func setObjects<T: _ObjectiveCBridgeable>(_ objects: [T]) where T._ObjectiveCType: NSItemProviderWriting {
        setObjects(objects.map { $0._bridgeToObjectiveC() as NSItemProviderWriting })
    }
    public func setObjects<T: _ObjectiveCBridgeable>(_ objects: [T], localOnly: Bool, expirationDate: Date?) where T._ObjectiveCType: NSItemProviderWriting {
        setObjects(objects.map { $0._bridgeToObjectiveC() as NSItemProviderWriting }, localOnly: localOnly, expirationDate: expirationDate)
    }
}

// MARK: - paste configuration (iOS 11) and the paste control (iOS 16)
@objc(UIPasteConfiguration)
open class UIPasteConfiguration: NSObject, NSCopying {
    open var acceptableTypeIdentifiers: [String]
    public override init() { acceptableTypeIdentifiers = []; super.init() }
    public init(acceptableTypeIdentifiers: [String]) { self.acceptableTypeIdentifiers = acceptableTypeIdentifiers; super.init() }
    public convenience init(forAccepting aClass: NSItemProviderReading.Type) { self.init(acceptableTypeIdentifiers: aClass.readableTypeIdentifiersForItemProvider) }
    public convenience init<T: _ObjectiveCBridgeable>(forAccepting aClass: T.Type) where T._ObjectiveCType: NSItemProviderReading {
        self.init(acceptableTypeIdentifiers: T._ObjectiveCType.readableTypeIdentifiersForItemProvider)
    }
    open func addAcceptableTypeIdentifiers(_ ids: [String]) { acceptableTypeIdentifiers += ids.filter { !acceptableTypeIdentifiers.contains($0) } }
    open func addTypeIdentifiers(forAccepting aClass: NSItemProviderReading.Type) { addAcceptableTypeIdentifiers(aClass.readableTypeIdentifiersForItemProvider) }
    public func addTypeIdentifiers<T: _ObjectiveCBridgeable>(forAccepting aClass: T.Type) where T._ObjectiveCType: NSItemProviderReading {
        addAcceptableTypeIdentifiers(T._ObjectiveCType.readableTypeIdentifiersForItemProvider)
    }
    open func copy(with zone: NSZone? = nil) -> Any { UIPasteConfiguration(acceptableTypeIdentifiers: acceptableTypeIdentifiers) }
    /// whether a pasteboard type is one of the acceptable ones (or conforms to one)
    func _accepts(_ type: String) -> Bool {
        acceptableTypeIdentifiers.contains { a in a == type || (UTType(type).map { t in UTType(a).map { t.conforms(to: $0) } ?? false } ?? false) }
    }
}

@objc public protocol UIPasteConfigurationSupporting: NSObjectProtocol {
    var pasteConfiguration: UIPasteConfiguration? { get set }
    @objc(pasteItemProviders:) optional func paste(itemProviders: [NSItemProvider])
    @objc(canPasteItemProviders:) optional func canPaste(_ itemProviders: [NSItemProvider]) -> Bool
}
nonisolated(unsafe) private var isimPasteConfigurationKey: UInt8 = 0
extension UIResponder: UIPasteConfigurationSupporting {
    @objc open var pasteConfiguration: UIPasteConfiguration? {
        get { objc_getAssociatedObject(self, &isimPasteConfigurationKey) as? UIPasteConfiguration }
        set { objc_setAssociatedObject(self, &isimPasteConfigurationKey, newValue, objc_AssociationPolicy(OBJC_ASSOCIATION_RETAIN_NONATOMIC)) }
    }
    /// responders override these (paste controls, and pastes of the accepted types)
    @objc(pasteItemProviders:) open func paste(itemProviders: [NSItemProvider]) {}
    @objc(canPasteItemProviders:) open func canPaste(_ itemProviders: [NSItemProvider]) -> Bool { true }
}

@objc(UIPasteControl)
open class UIPasteControl: UIControl {
    public enum DisplayMode: Int, Sendable { case iconAndLabel, iconOnly, labelOnly, arrowAndLabel }
    open class Configuration: NSObject {
        open var displayMode: DisplayMode = .iconAndLabel
        open var cornerStyle: UIButtonConfigurationCornerStyle = .dynamic
        open var cornerRadius: CGFloat = 0
        open var baseForegroundColor: UIColor?
        open var baseBackgroundColor: UIColor?
        public override init() { super.init() }
    }
    public let configuration: Configuration
    open weak var target: (any UIPasteConfigurationSupporting)? { didSet { _isimUpdate() } }
    private let icon = UIImageView(image: UIImage(systemName: "doc.on.clipboard"))
    private let label = UILabel()
    private var observers: [NSObjectProtocol] = []

    public init(configuration: Configuration) {
        self.configuration = configuration
        super.init(frame: CGRect(x: 0, y: 0, width: 100, height: 44))
        _isimSetUp()
    }
    public override init(frame: CGRect) {
        configuration = Configuration()
        super.init(frame: frame)
        _isimSetUp()
    }
    public required init?(coder: NSCoder) { configuration = Configuration(); super.init(coder: coder); _isimSetUp() }
    deinit { for o in observers { NotificationCenter.default.removeObserver(o) } }

    private func _isimSetUp() {
        accessibilityLabel = "Paste"
        accessibilityTraits = .button
        label.text = "Paste"
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        icon.contentMode = .scaleAspectFit
        for v in [icon, label] as [UIView] { v.isUserInteractionEnabled = false; addSubview(v) }
        clipsToBounds = true
        addAction(UIAction { [unowned self] _ in _isimPaste() }, for: .primaryActionTriggered)
        for name in [UIPasteboard.changedNotification, UIApplication.didBecomeActiveNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?._isimUpdate() }
            })
        }
        _isimUpdate()
    }
    open override func didMoveToWindow() { super.didMoveToWindow(); _isimUpdate() }
    open override var intrinsicContentSize: CGSize {
        let l = label.intrinsicContentSize
        switch configuration.displayMode {
        case .iconOnly: return CGSize(width: 44, height: 44)
        case .labelOnly: return CGSize(width: l.width + 32, height: 44)
        case .iconAndLabel, .arrowAndLabel: return CGSize(width: l.width + 60, height: 44)
        }
    }
    open override func layoutSubviews() {
        super.layoutSubviews()
        let b = bounds, l = label.intrinsicContentSize
        icon.isHidden = configuration.displayMode == .labelOnly
        if configuration.displayMode == .arrowAndLabel { icon.image = UIImage(systemName: "arrow.right.doc.on.clipboard") }
        label.isHidden = configuration.displayMode == .iconOnly
        let iconW: CGFloat = icon.isHidden ? 0 : 22, gap: CGFloat = icon.isHidden || label.isHidden ? 0 : 6
        let total = iconW + gap + (label.isHidden ? 0 : l.width)
        var x = (b.width - total) / 2
        icon.frame = CGRect(x: x, y: (b.height - 22) / 2, width: iconW, height: 22)
        x += iconW + gap
        label.frame = CGRect(x: x, y: (b.height - l.height) / 2, width: l.width, height: l.height)
        switch configuration.cornerStyle {
        case .fixed: layer.cornerRadius = configuration.cornerRadius
        case .capsule, .dynamic: layer.cornerRadius = b.height / 2
        case .small: layer.cornerRadius = 6
        case .medium: layer.cornerRadius = 8
        case .large: layer.cornerRadius = 12
        @unknown default: layer.cornerRadius = b.height / 2
        }
    }
    open override func tintColorDidChange() { super.tintColorDidChange(); _isimColors() }
    private func _isimColors() {
        let fg = configuration.baseForegroundColor ?? .white, bg = configuration.baseBackgroundColor ?? tintColor ?? .systemBlue
        label.textColor = fg; icon.tintColor = fg
        backgroundColor = isEnabled ? bg : bg.withAlphaComponent(0.35)
        alpha = isEnabled ? 1 : 0.6
    }
    /// enabled while the pasteboard has a type the target accepts (checked without reading the content)
    func _isimUpdate() {
        let types = (UIPasteboard.general.types(forItemSet: nil) ?? []).flatMap { $0 }
        let accepted = target?.pasteConfiguration.map { c in types.contains { c._accepts($0) } } ?? false
        isEnabled = accepted
        accessibilityTraits = accepted ? .button : [.button, .notEnabled]
        _isimColors()
        setNeedsLayout()
    }
    private func _isimPaste() {
        guard let target, let config = target.pasteConfiguration else { return }
        let items = UIPasteboard.general._isim_itemsForUserPaste()
        let providers = items.filter { $0.keys.contains { config._accepts($0) } }.map { _isimItemProvider($0) }
        guard !providers.isEmpty else { return }
        if let can = target.canPaste?(providers), !can { print("isim: UIPasteControl: the target declined the paste"); return }
        print("isim: UIPasteControl: pasting \(providers.count) item(s)")
        target.paste?(itemProviders: providers)
    }
}
