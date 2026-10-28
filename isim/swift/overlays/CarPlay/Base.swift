// isim CarPlay (adapted): templates on a simulated CarPlay screen.
//
// A CarPlay app (an entitlement of a CarPlay category, a CPTemplateApplicationSceneSessionRoleApplication scene in its
// manifest) gets a CPTemplateApplicationScene when the script command `carplay connect [WxH]` connects a CarPlay
// screen (default 800x480). Its delegate gets the CPInterfaceController (and, for navigation apps, the CPWindow its map
// draws in); the templates it sets are drawn by isim in CarPlay's own style (Screen.swift, Views.swift), on the
// CarPlay screen's window, never on the device. `carplay tap ID`, `carplay back`, `carplay dump` and `carplay shot PATH`
// drive and read it (docs/SCRIPTING.md). Apple's value types (the enums and option sets, CPLocationCoordinate3D) come
// from the Objective-C header (sdk-src/Frameworks/CarPlay); the classes and protocols are this overlay's, @objc with
// Apple's names and selectors.
@_exported import CarPlay
import Foundation
import UIKit

// MARK: - errors and limits

// the header's constants (CarPlay.framework's, which this overlay cannot link): their values
let _cpMaxGridImages = 8            // _cpMaxGridImages
let _cpGridMaxItems = 8             // _cpGridMaxItems
let _cpAlertMinimumDuration = 5.0   // _cpAlertMinimumDuration

func _cpError(_ text: String) -> NSError { NSError(domain: "CarPlayErrorDomain", code: 0, userInfo: [NSLocalizedDescriptionKey: text]) }

/// an image's copy for drawing on the CarPlay screen, at most this size (aspect kept)
func _cpFit(_ image: UIImage?, _ max: CGSize) -> UIImage? {
    guard let image else { return nil }
    let s = image.size
    guard s.width > max.width || s.height > max.height, s.width > 0, s.height > 0 else { return image }
    let k = min(max.width / s.width, max.height / s.height)
    return UIGraphicsImageRenderer(size: CGSize(width: s.width * k, height: s.height * k)).image { _ in
        image.draw(in: CGRect(x: 0, y: 0, width: s.width * k, height: s.height * k))
    }
}

/// what an archive keeps of a CarPlay object: its texts and numbers (images, handlers and user info are not archived)
func _cpDecodeStrings(_ c: NSCoder, _ key: String) -> [String] { (c.decodeObject(of: [NSArray.self, NSString.self], forKey: key) as? [String]) ?? [] }

// MARK: - images

@objc(CPImageSet)
open class CPImageSet: NSObject, NSSecureCoding {
    @objc open private(set) var lightContentImage: UIImage
    @objc open private(set) var darkContentImage: UIImage
    @objc public init(lightContentImage: UIImage, darkContentImage: UIImage) {
        self.lightContentImage = lightContentImage; self.darkContentImage = darkContentImage
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(lightContentImage, forKey: "light"); c.encode(darkContentImage, forKey: "dark") }
    public required init?(coder c: NSCoder) {
        guard let l = c.decodeObject(of: UIImage.self, forKey: "light"), let d = c.decodeObject(of: UIImage.self, forKey: "dark") else { return nil }
        lightContentImage = l; darkContentImage = d
        super.init()
    }
    /// the image for CarPlay's content style (dark unless the car asks for light)
    var _current: UIImage { _CPCar.shared.contentStyle == .light ? lightContentImage : darkContentImage }
}

// MARK: - buttons

public typealias CPBarButtonHandler = (CPBarButton) -> Void

@objc(CPBarButton)
open class CPBarButton: NSObject, NSSecureCoding {
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    @objc open var image: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var title: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var buttonStyle: CPBarButtonStyle = .none { didSet { _CPCar.shared.setNeedsRender() } }
    var _handler: CPBarButtonHandler?

    @objc public init(image: UIImage, handler: CPBarButtonHandler?) { self.image = image; _handler = handler; super.init() }
    @objc public init(title: String, handler: CPBarButtonHandler?) { self.title = title; _handler = handler; super.init() }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title"); c.encode(isEnabled, forKey: "enabled") }
    public required init?(coder c: NSCoder) {
        title = c.decodeObject(of: NSString.self, forKey: "title") as String?
        _isEnabled = c.containsValue(forKey: "enabled") ? c.decodeBool(forKey: "enabled") : true
        super.init()
    }
    func _tap() { if isEnabled { _handler?(self) } }
}

@objc(CPMessageComposeBarButton)
open class CPMessageComposeBarButton: CPBarButton {
    @objc public init() { super.init(image: UIImage(systemName: "square.and.pencil") ?? UIImage(), handler: nil) }
    @objc public override init(image: UIImage, handler: CPBarButtonHandler? = nil) { super.init(image: image, handler: handler) }
    public required init?(coder c: NSCoder) { super.init(coder: c) }
    @objc public convenience init(image: UIImage) { self.init(image: image, handler: nil) }
}

@objc(CPBarButtonProviding)
public protocol CPBarButtonProviding: NSObjectProtocol {
    @objc var leadingNavigationBarButtons: [CPBarButton] { get set }
    @objc var trailingNavigationBarButtons: [CPBarButton] { get set }
    @objc var backButton: CPBarButton? { get set }
}

@objc(CPButton)
open class CPButton: NSObject {
    @objc open var image: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var title: String? { didSet { _CPCar.shared.setNeedsRender() } }
    var _isEnabled: Bool = true
    @objc open var isEnabled: Bool {
        @objc(isEnabled) get { _isEnabled }
        @objc(setEnabled:) set { _isEnabled = newValue; _CPCar.shared.setNeedsRender() }
    }
    var _handler: ((CPButton) -> Void)?
    @objc public init(image: UIImage, handler: ((CPButton) -> Void)?) { self.image = image; _handler = handler; super.init() }
    init(_title: String?, image: UIImage?, handler: ((CPButton) -> Void)?) { title = _title; self.image = image; _handler = handler; super.init() }
    func _tap() { if isEnabled { _handler?(self) } }
    var _symbol: String? { nil }
}

@objc(CPTextButton)
open class CPTextButton: NSObject {
    @objc open var title: String { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var textStyle: CPTextButtonStyle = .normal { didSet { _CPCar.shared.setNeedsRender() } }
    var _handler: ((CPTextButton) -> Void)?
    @objc public init(title: String, textStyle: CPTextButtonStyle, handler: ((CPTextButton) -> Void)?) {
        self.title = title; self.textStyle = textStyle; _handler = handler
        super.init()
    }
    func _tap() { _handler?(self) }
}

public typealias CPAlertActionHandler = (CPAlertAction) -> Void

@objc(CPAlertAction)
open class CPAlertAction: NSObject, NSSecureCoding {
    @objc(CPAlertActionStyle) public enum Style: UInt, @unchecked Sendable { case `default` = 0, cancel, destructive }
    @objc open private(set) var title: String
    @objc open private(set) var style: CPAlertAction.Style
    @objc open private(set) var handler: CPAlertActionHandler
    @objc open private(set) var color: UIColor?
    @objc public init(title: String, style: CPAlertAction.Style, handler: @escaping CPAlertActionHandler) {
        self.title = title; self.style = style; self.handler = handler
        super.init()
    }
    @objc public init(title: String, color: UIColor, handler: @escaping CPAlertActionHandler) {
        self.title = title; style = .default; self.color = color; self.handler = handler
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(title, forKey: "title"); c.encode(Int(style.rawValue), forKey: "style") }
    public required init?(coder c: NSCoder) {
        title = (c.decodeObject(of: NSString.self, forKey: "title") as String?) ?? ""
        style = Style(rawValue: UInt(c.decodeInteger(forKey: "style"))) ?? .default
        handler = { _ in }
        super.init()
    }
}

// MARK: - templates

@objc(CPTemplate)
open class CPTemplate: NSObject, NSSecureCoding {
    @objc open var userInfo: Any?
    @objc open var tabTitle: String? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var tabImage: UIImage? { didSet { _CPCar.shared.setNeedsRender() } }
    @objc open var tabSystemItem: UITabBarItem.SystemItem = .more { didSet { _hasSystemItem = true; _CPCar.shared.setNeedsRender() } }
    @objc open var showsTabBadge: Bool = false { didSet { _CPCar.shared.setNeedsRender() } }
    var _hasSystemItem = false
    // the navigation bar of the templates that provide one (CPBarButtonProviding)
    var _leading: [CPBarButton] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    var _trailing: [CPBarButton] = [] { didSet { _CPCar.shared.setNeedsRender() } }
    var _back: CPBarButton? { didSet { _CPCar.shared.setNeedsRender() } }
    /// the interface controller that shows it (set while it is in a stack, presented or a tab)
    weak var _controller: CPInterfaceController?

    public override init() { super.init() }
    public static var supportsSecureCoding: Bool { true }
    open func encode(with c: NSCoder) { c.encode(tabTitle, forKey: "tabTitle"); c.encode(showsTabBadge, forKey: "badge") }
    public required init?(coder c: NSCoder) {
        tabTitle = c.decodeObject(of: NSString.self, forKey: "tabTitle") as String?
        showsTabBadge = c.decodeBool(forKey: "badge")
        super.init()
    }
    /// the title its navigation bar shows (subclasses)
    var _barTitle: String? { nil }
    /// whether it draws a navigation bar
    var _hasBar: Bool { self is CPBarButtonProviding }
}
