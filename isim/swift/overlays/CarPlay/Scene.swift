// isim CarPlay: the template application scene, the car window, the interface controller and the session
// configuration; the dashboard and instrument cluster scenes.
import Foundation
import UIKit

// MARK: - the session configuration

@objc(CPSessionConfigurationDelegate)
public protocol CPSessionConfigurationDelegate: NSObjectProtocol {
    @objc(sessionConfiguration:limitedUserInterfacesChanged:)
    optional func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration, limitedUserInterfacesChanged limitedUserInterfaces: CPLimitableUserInterface)
    @objc(sessionConfiguration:contentStyleChanged:)
    optional func sessionConfiguration(_ sessionConfiguration: CPSessionConfiguration, contentStyleChanged contentStyle: CPContentStyle)
}

/// what the connected car allows: `carplay limit lists|keyboard|none` and `carplay style light|dark` change it
@objc(CPSessionConfiguration)
open class CPSessionConfiguration: NSObject {
    @objc open weak var delegate: (any CPSessionConfigurationDelegate)?
    @objc open var limitedUserInterfaces: CPLimitableUserInterface { _CPCar.shared.limited }
    @objc open var contentStyle: CPContentStyle { _CPCar.shared.contentStyle }
    @objc open var supportsVideoPlayback: Bool { _CPCar.shared.screen != nil && _CPCar.shared.parked }
    @objc public init(delegate: any CPSessionConfigurationDelegate) {
        self.delegate = delegate
        super.init()
        _CPCar.shared.configurations.add(self)
    }
}

// MARK: - the window

@objc(CPWindow)
open class CPWindow: UIWindow {
    @objc open internal(set) weak var templateApplicationScene: CPTemplateApplicationScene?
    let _mapButtonGuide = UILayoutGuide()
    /// the area the map buttons leave free (the map's safe area)
    @objc open var mapButtonSafeAreaLayoutGuide: UILayoutGuide { _mapButtonGuide }
    init(_car frame: CGRect, screen: UIScreen) {
        super.init(frame: frame)
        self.screen = screen
        addLayoutGuide(_mapButtonGuide)
    }
    public required init?(coder: NSCoder) { super.init(coder: coder) }
    public override init(frame: CGRect) { super.init(frame: frame) }
    open override var safeAreaInsets: UIEdgeInsets { UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0) }
}

// MARK: - the scene

@objc(CPTemplateApplicationSceneDelegate)
public protocol CPTemplateApplicationSceneDelegate: UISceneDelegate {
    @objc(templateApplicationScene:didConnectInterfaceController:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController)
    @objc(templateApplicationScene:didDisconnectInterfaceController:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnectInterfaceController interfaceController: CPInterfaceController)
    @objc(templateApplicationScene:didConnectInterfaceController:toWindow:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController, to window: CPWindow)
    @objc(templateApplicationScene:didDisconnectInterfaceController:fromWindow:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController, from window: CPWindow)
    @objc(templateApplicationScene:didSelectNavigationAlert:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didSelect navigationAlert: CPNavigationAlert)
    @objc(templateApplicationScene:didSelectManeuver:)
    optional func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didSelect maneuver: CPManeuver)
    @objc optional func contentStyleDidChange(_ contentStyle: UIUserInterfaceStyle)
}

@objc(CPTemplateApplicationScene)
open class CPTemplateApplicationScene: UIScene {
    var _controller: CPInterfaceController!
    var _window: CPWindow?
    @objc open var interfaceController: CPInterfaceController { _controller }
    /// the car window (navigation apps draw their map in it)
    @objc open var carWindow: CPWindow { _window ?? _CPCar.shared.makeCarWindow(for: self) }
    @objc open var contentStyle: UIUserInterfaceStyle { _CPCar.shared.contentStyle == .light ? .light : .dark }
    public required override init(session: UISceneSession, connectionOptions: UIScene.ConnectionOptions) {
        super.init(session: session, connectionOptions: connectionOptions)
        _controller = CPInterfaceController(_scene: self)
    }
    var _sceneDelegate: CPTemplateApplicationSceneDelegate? { delegate as? CPTemplateApplicationSceneDelegate }
}

// the dashboard and the instrument cluster: their scenes connect with the CarPlay screen when the app's manifest has
// them, but isim's car has no dashboard or cluster display to draw them on (their windows are kept, not shown)

@objc(CPDashboardButton)
open class CPDashboardButton: NSObject, NSSecureCoding {
    @objc open private(set) var titleVariants: [String]
    @objc open private(set) var subtitleVariants: [String]
    @objc open private(set) var image: UIImage
    var _handler: ((CPDashboardButton) -> Void)?
    @objc public init(titleVariants: [String], subtitleVariants: [String], image: UIImage, handler: ((CPDashboardButton) -> Void)?) {
        self.titleVariants = titleVariants; self.subtitleVariants = subtitleVariants; self.image = image; _handler = handler
        super.init()
    }
    public static var supportsSecureCoding: Bool { true }
    public func encode(with c: NSCoder) { c.encode(titleVariants, forKey: "titles"); c.encode(subtitleVariants, forKey: "subtitles"); c.encode(image, forKey: "image") }
    public required init?(coder c: NSCoder) {
        titleVariants = _cpDecodeStrings(c, "titles"); subtitleVariants = _cpDecodeStrings(c, "subtitles")
        image = c.decodeObject(of: UIImage.self, forKey: "image") ?? UIImage()
        super.init()
    }
}

@objc(CPDashboardController)
open class CPDashboardController: NSObject {
    @objc open var shortcutButtons: [CPDashboardButton] = [] {
        didSet { NSLog("isim CarPlay: dashboard shortcuts %@", shortcutButtons.compactMap(\.titleVariants.first).joined(separator: ", ")) }
    }
    override init() { super.init() }
}

@objc(CPTemplateApplicationDashboardSceneDelegate)
public protocol CPTemplateApplicationDashboardSceneDelegate: UISceneDelegate {
    @objc(templateApplicationDashboardScene:didConnectDashboardController:toWindow:)
    optional func templateApplicationDashboardScene(_ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene, didConnect dashboardController: CPDashboardController, to window: UIWindow)
    @objc(templateApplicationDashboardScene:didDisconnectDashboardController:fromWindow:)
    optional func templateApplicationDashboardScene(_ templateApplicationDashboardScene: CPTemplateApplicationDashboardScene, didDisconnect dashboardController: CPDashboardController, from window: UIWindow)
}

@objc(CPTemplateApplicationDashboardScene)
open class CPTemplateApplicationDashboardScene: UIScene {
    let _dashboard = CPDashboardController()
    lazy var _window: UIWindow = _CPCar.shared.makeAuxWindow(CGSize(width: 400, height: 240))
    @objc open var dashboardController: CPDashboardController { _dashboard }
    @objc open var dashboardWindow: UIWindow { _window }
    public required override init(session: UISceneSession, connectionOptions: UIScene.ConnectionOptions) { super.init(session: session, connectionOptions: connectionOptions) }
}

@objc(CPInstrumentClusterControllerDelegate)
public protocol CPInstrumentClusterControllerDelegate: NSObjectProtocol {
    @objc(instrumentClusterControllerDidConnectWindow:) func instrumentClusterControllerDidConnect(_ instrumentClusterWindow: UIWindow)
    @objc(instrumentClusterControllerDidDisconnectWindow:) func instrumentClusterControllerDidDisconnectWindow(_ instrumentClusterWindow: UIWindow)
    @objc(instrumentClusterControllerDidZoomIn:) optional func instrumentClusterControllerDidZoom(in instrumentClusterController: CPInstrumentClusterController)
    @objc optional func instrumentClusterControllerDidZoomOut(_ instrumentClusterController: CPInstrumentClusterController)
    @objc(instrumentClusterController:didChangeCompassSetting:)
    optional func instrumentClusterController(_ instrumentClusterController: CPInstrumentClusterController, didChangeCompassSetting compassSetting: CPInstrumentClusterSetting)
    @objc(instrumentClusterController:didChangeSpeedLimitSetting:)
    optional func instrumentClusterController(_ instrumentClusterController: CPInstrumentClusterController, didChangeSpeedLimitSetting speedLimitSetting: CPInstrumentClusterSetting)
}

@objc(CPInstrumentClusterController)
open class CPInstrumentClusterController: NSObject {
    @objc open weak var delegate: (any CPInstrumentClusterControllerDelegate)?
    @objc open internal(set) var instrumentClusterWindow: UIWindow?
    @objc open internal(set) var speedLimitSetting: CPInstrumentClusterSetting = .unspecified
    @objc open internal(set) var compassSetting: CPInstrumentClusterSetting = .unspecified
    @objc open var inactiveDescriptionVariants: [String] = []
    @objc open var attributedInactiveDescriptionVariants: [NSAttributedString] = []
    override init() { super.init() }
}

@objc(CPTemplateApplicationInstrumentClusterSceneDelegate)
public protocol CPTemplateApplicationInstrumentClusterSceneDelegate: UISceneDelegate {
    @objc(templateApplicationInstrumentClusterScene:didConnectInstrumentClusterController:)
    optional func templateApplicationInstrumentClusterScene(_ templateApplicationInstrumentClusterScene: CPTemplateApplicationInstrumentClusterScene, didConnect instrumentClusterController: CPInstrumentClusterController)
    @objc(templateApplicationInstrumentClusterScene:didDisconnectInstrumentClusterController:)
    optional func templateApplicationInstrumentClusterScene(_ templateApplicationInstrumentClusterScene: CPTemplateApplicationInstrumentClusterScene, didDisconnectInstrumentClusterController instrumentClusterController: CPInstrumentClusterController)
    @objc optional func contentStyleDidChange(_ contentStyle: UIUserInterfaceStyle)
}

@objc(CPTemplateApplicationInstrumentClusterScene)
open class CPTemplateApplicationInstrumentClusterScene: UIScene {
    let _cluster = CPInstrumentClusterController()
    @objc open var instrumentClusterController: CPInstrumentClusterController { _cluster }
    @objc open var contentStyle: UIUserInterfaceStyle { _CPCar.shared.contentStyle == .light ? .light : .dark }
    public required override init(session: UISceneSession, connectionOptions: UIScene.ConnectionOptions) { super.init(session: session, connectionOptions: connectionOptions) }
}

/// iOS 12's app delegate protocol for CarPlay (apps without a CarPlay scene)
@objc(CPApplicationDelegate)
public protocol CPApplicationDelegate: UIApplicationDelegate {
    @objc(application:didConnectCarInterfaceController:toWindow:)
    func application(_ application: UIApplication, didConnectCarInterfaceController interfaceController: CPInterfaceController, to window: CPWindow)
    @objc(application:didDisconnectCarInterfaceController:fromWindow:)
    func application(_ application: UIApplication, didDisconnectCarInterfaceController interfaceController: CPInterfaceController, from window: CPWindow)
    @objc(application:didSelectNavigationAlert:) optional func application(_ application: UIApplication, didSelect navigationAlert: CPNavigationAlert)
    @objc(application:didSelectManeuver:) optional func application(_ application: UIApplication, didSelect maneuver: CPManeuver)
}

// MARK: - the interface controller

@objc(CPInterfaceControllerDelegate)
public protocol CPInterfaceControllerDelegate: NSObjectProtocol {
    @objc(templateWillAppear:animated:) optional func templateWillAppear(_ aTemplate: CPTemplate, animated: Bool)
    @objc(templateDidAppear:animated:) optional func templateDidAppear(_ aTemplate: CPTemplate, animated: Bool)
    @objc(templateWillDisappear:animated:) optional func templateWillDisappear(_ aTemplate: CPTemplate, animated: Bool)
    @objc(templateDidDisappear:animated:) optional func templateDidDisappear(_ aTemplate: CPTemplate, animated: Bool)
}

@objc(CPInterfaceController)
open class CPInterfaceController: NSObject {
    @objc open weak var delegate: (any CPInterfaceControllerDelegate)?
    @objc open var prefersDarkUserInterfaceStyle: Bool = false { didSet { _CPCar.shared.setNeedsRender() } }
    weak var _scene: CPTemplateApplicationScene?
    var _stack: [CPTemplate] = []
    var _presented: CPTemplate?
    var _overlay: CPTemplate?
    init(_scene: CPTemplateApplicationScene?) { self._scene = _scene; super.init() }

    @objc open var rootTemplate: CPTemplate { _stack.first ?? CPTemplate() }
    @objc open var topTemplate: CPTemplate? { _stack.last }
    @objc open var templates: [CPTemplate] { _stack }
    @objc open var presentedTemplate: CPTemplate? { _presented }
    @objc open var carTraitCollection: UITraitCollection {
        UITraitCollection(traitsFrom: [UITraitCollection(userInterfaceIdiom: .carPlay), UITraitCollection(displayScale: _CPCar.shared.scale),
                                       UITraitCollection(userInterfaceStyle: _CPCar.shared.contentStyle == .light && !prefersDarkUserInterfaceStyle ? .light : .dark)])
    }

    /// the templates the app's CarPlay category may use (setting another one raises, as on iOS)
    func _check(_ t: CPTemplate, _ call: String) {
        let allowed = _CPCar.shared.allowedTemplates
        guard !allowed.contains(where: { t.isKind(of: $0) }) else { return }
        let names = allowed.map { NSStringFromClass($0) }.joined(separator: ", ")
        NSException(name: "NSInvalidArgumentException", reason: "Unsupported object \(t) passed to \(call). Allowed classes: {(\(names))}", userInfo: nil).raise()
    }
    func _adopt(_ t: CPTemplate) {
        t._controller = self
        if let tab = t as? CPTabBarTemplate { for c in tab.templates { c._controller = self } }
    }
    func _appear(_ t: CPTemplate?, _ animated: Bool) {
        guard let t else { return }
        delegate?.templateWillAppear?(t, animated: animated); delegate?.templateDidAppear?(t, animated: animated)
    }
    func _disappear(_ t: CPTemplate?, _ animated: Bool) {
        guard let t else { return }
        delegate?.templateWillDisappear?(t, animated: animated); delegate?.templateDidDisappear?(t, animated: animated)
    }
    static let _maxDepth = 5

    @objc open func setRootTemplate(_ rootTemplate: CPTemplate, animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        _check(rootTemplate, "setRootTemplate:animated:completion:")
        let old = _stack.last
        _stack = [rootTemplate]; _adopt(rootTemplate)
        _disappear(old, animated); _appear(rootTemplate, animated)
        NSLog("isim CarPlay: root template %@", _CPCar.describe(rootTemplate))
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func pushTemplate(_ templateToPush: CPTemplate, animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        _check(templateToPush, "pushTemplate:animated:completion:")
        if templateToPush is CPTabBarTemplate { completion?(false, _cpError("A tab bar template can only be the root template.")); return }
        guard _stack.count < Self._maxDepth else {
            NSLog("isim CarPlay: push refused: the template stack is %ld deep (the limit)", _stack.count)
            completion?(false, _cpError("The template hierarchy is at its maximum depth (\(Self._maxDepth)).")); return
        }
        let old = _stack.last
        _stack.append(templateToPush); _adopt(templateToPush)
        _disappear(old, animated); _appear(templateToPush, animated)
        NSLog("isim CarPlay: push %@", _CPCar.describe(templateToPush))
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func popTemplate(animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard _stack.count > 1 else { completion?(false, _cpError("The root template cannot be popped.")); return }
        let gone = _stack.removeLast()
        _disappear(gone, animated); _appear(_stack.last, animated)
        NSLog("isim CarPlay: pop %@", _CPCar.describe(gone))
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func popToRootTemplate(animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard _stack.count > 1 else { completion?(false, _cpError("The root template is already shown.")); return }
        let top = _stack.last
        _stack = [_stack[0]]
        _disappear(top, animated); _appear(_stack.last, animated)
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc(popToTemplate:animated:completion:) open func pop(to targetTemplate: CPTemplate, animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard let i = _stack.firstIndex(where: { $0 === targetTemplate }) else { completion?(false, _cpError("The template is not in the stack.")); return }
        let top = _stack.last
        _stack = Array(_stack[...i])
        if top !== targetTemplate { _disappear(top, animated); _appear(targetTemplate, animated) }
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard templateToPresent is CPAlertTemplate || templateToPresent is CPActionSheetTemplate || templateToPresent is CPVoiceControlTemplate else {
            NSException(name: "NSInvalidArgumentException", reason: "Unsupported object \(templateToPresent) passed to presentTemplate:animated:completion:. Allowed classes: {(CPAlertTemplate, CPActionSheetTemplate, CPVoiceControlTemplate)}", userInfo: nil).raise()
        }
        _check(templateToPresent, "presentTemplate:animated:completion:")
        guard _presented == nil else { completion?(false, _cpError("A template is already presented.")); return }
        _presented = templateToPresent; _adopt(templateToPresent)
        _appear(templateToPresent, animated)
        NSLog("isim CarPlay: present %@", _CPCar.describe(templateToPresent))
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func dismissTemplate(animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard let p = _presented else { completion?(false, _cpError("No template is presented.")); return }
        _presented = nil
        _disappear(p, animated)
        NSLog("isim CarPlay: dismiss %@", _CPCar.describe(p))
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func showOverlayTemplate(_ templateToShow: CPTemplate, animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        _overlay = templateToShow; _adopt(templateToShow); _appear(templateToShow, animated)
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }
    @objc open func hideOverlayTemplate(animated: Bool, completion: ((Bool, (any Error)?) -> Void)?) {
        guard let o = _overlay else { completion?(false, _cpError("No overlay template is shown.")); return }
        _overlay = nil; _disappear(o, animated)
        _CPCar.shared.setNeedsRender()
        completion?(true, nil)
    }

    // the iOS 12 calls without completions
    @objc open func setRootTemplate(_ rootTemplate: CPTemplate, animated: Bool) { setRootTemplate(rootTemplate, animated: animated, completion: nil) }
    @objc open func pushTemplate(_ templateToPush: CPTemplate, animated: Bool) { pushTemplate(templateToPush, animated: animated, completion: nil) }
    @objc open func popTemplate(animated: Bool) { popTemplate(animated: animated, completion: nil) }
    @objc open func popToRootTemplate(animated: Bool) { popToRootTemplate(animated: animated, completion: nil) }
    @objc(popToTemplate:animated:) open func pop(to targetTemplate: CPTemplate, animated: Bool) { pop(to: targetTemplate, animated: animated, completion: nil) }
    @objc open func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool) { presentTemplate(templateToPresent, animated: animated, completion: nil) }
    @objc open func dismissTemplate(animated: Bool) { dismissTemplate(animated: animated, completion: nil) }
}

// the Swift async forms
extension CPInterfaceController {
    @discardableResult public func setRootTemplate(_ rootTemplate: CPTemplate, animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in setRootTemplate(rootTemplate, animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func pushTemplate(_ templateToPush: CPTemplate, animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in pushTemplate(templateToPush, animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func popTemplate(animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in popTemplate(animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func popToRootTemplate(animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in popToRootTemplate(animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func pop(to targetTemplate: CPTemplate, animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in pop(to: targetTemplate, animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func presentTemplate(_ templateToPresent: CPTemplate, animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in presentTemplate(templateToPresent, animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
    @discardableResult public func dismissTemplate(animated: Bool) async throws -> Bool {
        try await withCheckedThrowingContinuation { k in dismissTemplate(animated: animated) { ok, e in if let e { k.resume(throwing: e) } else { k.resume(returning: ok) } } }
    }
}
