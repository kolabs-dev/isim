// isim CarPlay: the simulated CarPlay screen. `carplay connect [WxH]` connects it (default 800x480 at scale 2, CarPlay's
// common size) and the app's CarPlay scene; `carplay disconnect` removes them. The screen is a UIScreen of its own, and
// its windows (isim's, which draws CarPlay's status bar and the templates, and a navigation app's CPWindow under it) are
// laid out and drawn only for `carplay shot PATH`, never on the device. The other commands act on what the screen
// shows: `carplay tap ID|X Y`, `carplay taptext TEXT`, `carplay back`, `carplay scroll down|up`, `carplay search TEXT`,
// `carplay pan up|down|left|right`, `carplay dump`, `carplay style dark|light`, `carplay limit lists|keyboard|none`,
// `carplay park on|off`.
import Foundation
import UIKit

/// the app's CarPlay categories (entitlements) and the templates each allows (Apple's CarPlay developer guide)
let _cpCategories: [(entitlement: String, name: String, templates: [AnyClass])] = {
    let base: [AnyClass] = [CPListTemplate.self, CPGridTemplate.self, CPTabBarTemplate.self, CPAlertTemplate.self, CPActionSheetTemplate.self]
    let poi: [AnyClass] = base + [CPInformationTemplate.self, CPPointOfInterestTemplate.self]
    return [
        ("com.apple.developer.carplay-audio", "audio", base + [CPNowPlayingTemplate.self]),
        ("com.apple.developer.carplay-communication", "communication", base + [CPContactTemplate.self, CPInformationTemplate.self]),
        ("com.apple.developer.carplay-maps", "navigation", base + [CPMapTemplate.self, CPSearchTemplate.self, CPVoiceControlTemplate.self,
                                                                    CPInformationTemplate.self, CPPointOfInterestTemplate.self, CPPanel.self]),
        ("com.apple.developer.carplay-charging", "EV charging", poi),
        ("com.apple.developer.carplay-fueling", "fueling", poi),
        ("com.apple.developer.carplay-parking", "parking", poi),
        ("com.apple.developer.carplay-quick-ordering", "quick food ordering", poi),
        ("com.apple.developer.carplay-driving-task", "driving task", poi),
        ("com.apple.developer.carplay-public-safety", "public safety", base + [CPInformationTemplate.self]),
        ("com.apple.developer.carplay-voice-based-conversation", "voice-based conversation", base + [CPVoiceControlTemplate.self, CPNowPlayingTemplate.self]),
    ]
}()

typealias _ConnectRole = @convention(c) (UISceneConfiguration?, NSString, UIScreen?, AnyObject?) -> Unmanaged<UIScene>?
typealias _DisconnectRole = @convention(c) (UIScene) -> Void
typealias _RoleConfiguration = @convention(c) (NSString) -> Unmanaged<NSDictionary>?
typealias _MakeScreen = @convention(c) (Double, Double, Double) -> Unmanaged<UIScreen>
func _uikit<T>(_ name: String, _ type: T.Type) -> T? {
    guard let p = dlsym(UnsafeMutableRawPointer(bitPattern: -2), name) else { return nil }   // RTLD_DEFAULT
    return unsafeBitCast(p, to: type)
}

final class _CPCar: NSObject {
    nonisolated(unsafe) static let shared = _CPCar()
    var screen: UIScreen?
    var size = CGSize(width: 800, height: 480)
    var scale: CGFloat = 2
    var scene: CPTemplateApplicationScene?
    var legacy: CPInterfaceController?          // CPApplicationDelegate apps (no CarPlay scene)
    var legacyWindow: CPWindow?
    var auxScenes: [UIScene] = []
    var system: _CPSystemWindow?
    var contentStyle: CPContentStyle = .dark
    var limited: CPLimitableUserInterface = []
    var parked = true
    var foreground: Bool { scene?.activationState == .foregroundActive || legacy != nil }
    let configurations = NSHashTable<CPSessionConfiguration>.weakObjects()
    var renderQueued = false
    var scroll: [ObjectIdentifier: CGFloat] = [:]
    var timer: Timer?

    var controller: CPInterfaceController? { scene?._controller ?? legacy }
    var carWindow: CPWindow? { scene?._window ?? legacyWindow }

    /// the app's CarPlay categories, from its entitlements
    static var categories: [(entitlement: String, name: String, templates: [AnyClass])] {
        let p = (Bundle.main.bundlePath as NSString).appendingPathComponent("archived-expanded-entitlements.xcent")
        let e = NSDictionary(contentsOfFile: p) ?? NSDictionary()
        return _cpCategories.filter { (e[$0.entitlement] as? Bool) == true }
    }
    var allowedTemplates: [AnyClass] { Self.categories.flatMap(\.templates) }
    var isNavigation: Bool { Self.categories.contains { $0.name == "navigation" } }

    static func describe(_ t: CPTemplate) -> String {
        let name = NSStringFromClass(type(of: t))
        if let title = t._barTitle, !title.isEmpty { return "\(name) “\(title)”" }
        return name
    }

    // MARK: connecting

    func connect(_ w: Int, _ h: Int, _ s: Double) {
        guard screen == nil else { NSLog("isim CarPlay: a CarPlay screen is already connected"); return }
        let cats = Self.categories
        guard !cats.isEmpty else {
            NSLog("isim CarPlay: the app has no CarPlay entitlement (com.apple.developer.carplay-audio, -communication, -maps, ...): CarPlay does not show it")
            return
        }
        guard let make = _uikit("isim_ui_make_screen", _MakeScreen.self), let connectRole = _uikit("isim_ui_connect_role_scene", _ConnectRole.self),
              let roleConfig = _uikit("isim_ui_role_configuration", _RoleConfiguration.self) else { NSLog("isim CarPlay: UIKit lacks the screen hooks"); return }
        size = CGSize(width: w, height: h); scale = CGFloat(s)
        let scr = make(Double(w), Double(h), s).takeUnretainedValue()
        screen = scr
        system = _CPSystemWindow(frame: CGRect(origin: .zero, size: size), screen: scr)
        NSLog("isim CarPlay: CarPlay screen connected (%dx%d @%gx, %@)", w, h, s, cats.map(\.name).joined(separator: ", "))
        let role = "CPTemplateApplicationSceneSessionRoleApplication" as NSString
        if roleConfig(role) != nil, let sc = connectRole(nil, role, scr, nil)?.takeUnretainedValue() as? CPTemplateApplicationScene {
            scene = sc
            let d = sc._sceneDelegate
            if isNavigation || d?.responds(to: #selector(CPTemplateApplicationSceneDelegate.templateApplicationScene(_:didConnect:to:))) == true && d?.responds(to: #selector(CPTemplateApplicationSceneDelegate.templateApplicationScene(_:didConnect:))) != true {
                let win = makeCarWindow(for: sc)
                d?.templateApplicationScene?(sc, didConnect: sc._controller, to: win)
            } else {
                d?.templateApplicationScene?(sc, didConnect: sc._controller)
            }
        } else if let ad = UIApplication.shared.delegate as? CPApplicationDelegate {
            let c = CPInterfaceController(_scene: nil)
            legacy = c
            let win = CPWindow(_car: contentFrame, screen: scr)
            win.isHidden = false
            legacyWindow = win
            ad.application(UIApplication.shared, didConnectCarInterfaceController: c, to: win)
        } else {
            NSLog("isim CarPlay: the app's scene manifest has no CPTemplateApplicationSceneSessionRoleApplication configuration")
        }
        // the dashboard and instrument cluster scenes, when the manifest has them
        for r in ["CPTemplateApplicationDashboardSceneSessionRoleApplication", "CPTemplateApplicationInstrumentClusterSceneSessionRoleApplication"] where roleConfig(r as NSString) != nil {
            guard let s = connectRole(nil, r as NSString, scr, nil)?.takeUnretainedValue() else { continue }
            auxScenes.append(s)
            if let ds = s as? CPTemplateApplicationDashboardScene {
                (ds.delegate as? CPTemplateApplicationDashboardSceneDelegate)?.templateApplicationDashboardScene?(ds, didConnect: ds._dashboard, to: ds._window)
            } else if let cs = s as? CPTemplateApplicationInstrumentClusterScene {
                (cs.delegate as? CPTemplateApplicationInstrumentClusterSceneDelegate)?.templateApplicationInstrumentClusterScene?(cs, didConnect: cs._cluster)
            }
        }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
        setNeedsRender()
    }

    func disconnect() {
        guard let scr = screen else { return }
        let disconnectRole = _uikit("isim_ui_disconnect_role_scene", _DisconnectRole.self)
        if let sc = scene {
            let d = sc._sceneDelegate
            if let w = sc._window { d?.templateApplicationScene?(sc, didDisconnect: sc._controller, from: w) }
            d?.templateApplicationScene?(sc, didDisconnectInterfaceController: sc._controller)
            scene = nil
            disconnectRole?(sc)
        }
        if let c = legacy, let w = legacyWindow, let ad = UIApplication.shared.delegate as? CPApplicationDelegate {
            ad.application(UIApplication.shared, didDisconnectCarInterfaceController: c, from: w)
        }
        legacy = nil; legacyWindow = nil
        for s in auxScenes {
            if let ds = s as? CPTemplateApplicationDashboardScene {
                (ds.delegate as? CPTemplateApplicationDashboardSceneDelegate)?.templateApplicationDashboardScene?(ds, didDisconnect: ds._dashboard, from: ds._window)
            } else if let cs = s as? CPTemplateApplicationInstrumentClusterScene {
                (cs.delegate as? CPTemplateApplicationInstrumentClusterSceneDelegate)?.templateApplicationInstrumentClusterScene?(cs, didDisconnectInstrumentClusterController: cs._cluster)
            }
            disconnectRole?(s)
        }
        auxScenes = []
        timer?.invalidate(); timer = nil
        system?.isHidden = true; system = nil
        _ = scr
        screen = nil
        NSLog("isim CarPlay: CarPlay screen disconnected")
    }

    /// where templates and the car window go: the screen less CarPlay's status bar
    var contentFrame: CGRect { CGRect(x: _CPStyle.sidebar, y: 0, width: size.width - _CPStyle.sidebar, height: size.height) }

    func makeCarWindow(for sc: CPTemplateApplicationScene) -> CPWindow {
        if let w = sc._window { return w }
        let w = CPWindow(_car: contentFrame, screen: screen ?? UIScreen.main)
        w.templateApplicationScene = sc
        w.isHidden = false                       // CarPlay shows it (apps don't make it key and visible)
        sc._window = w
        return w
    }
    func makeAuxWindow(_ s: CGSize) -> UIWindow {
        let w = UIWindow(frame: CGRect(origin: .zero, size: s))
        if let scr = screen { w.screen = scr }
        return w
    }

    // MARK: the session's settings

    func setStyle(_ style: CPContentStyle) {
        guard style != contentStyle else { return }
        contentStyle = style
        for c in configurations.allObjects { c.delegate?.sessionConfiguration?(c, contentStyleChanged: style) }
        let ui: UIUserInterfaceStyle = style == .light ? .light : .dark
        if let sc = scene { sc._sceneDelegate?.contentStyleDidChange?(ui) }
        for s in auxScenes { (s.delegate as? CPTemplateApplicationInstrumentClusterSceneDelegate)?.contentStyleDidChange?(ui) }
        NSLog("isim CarPlay: content style %@", style == .light ? "light" : "dark")
        setNeedsRender()
    }
    func setLimited(_ l: CPLimitableUserInterface) {
        guard l != limited else { return }
        limited = l
        for c in configurations.allObjects { c.delegate?.sessionConfiguration?(c, limitedUserInterfacesChanged: l) }
        NSLog("isim CarPlay: limited user interfaces %@", l.isEmpty ? "none" : [l.contains(.lists) ? "lists" : nil, l.contains(.keyboard) ? "keyboard" : nil].compactMap { $0 }.joined(separator: ", "))
        setNeedsRender()
    }

    // MARK: drawing

    func setNeedsRender() {
        guard screen != nil, !renderQueued else { return }
        renderQueued = true
        DispatchQueue.main.async { [weak self] in self?.renderQueued = false; self?.render() }
    }
    func render() {
        guard let sys = system else { return }
        _CPRenderer(car: self, root: sys.root).build()
    }
    /// the Now Playing screen follows MPNowPlayingInfoCenter's elapsed time
    func tick() {
        if controller?._stack.last is CPNowPlayingTemplate { render() }
    }

    /// what the screen shows, as a PNG: the car window (a navigation app's map) under isim's window
    func shot(_ path: String) {
        guard screen != nil, let sys = system else { NSLog("isim CarPlay: carplay shot: no CarPlay screen is connected"); return }
        render()
        let img = UIGraphicsImageRenderer(size: size, format: { let f = UIGraphicsImageRendererFormat(); f.scale = scale; f.opaque = true; return f }()).image { ctx in
            UIColor.black.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            if let w = carWindow, !w.isHidden, sys.root._showsCarWindow {
                w.layoutIfNeeded()
                w.drawHierarchy(in: w.frame, afterScreenUpdates: true)
            }
            sys.root.layoutIfNeeded()
            sys.root.drawHierarchy(in: sys.root.frame, afterScreenUpdates: true)
        }
        let ok = (img.pngData() as NSData?)?.write(toFile: path, atomically: true) ?? false
        NSLog("isim CarPlay: shot %@ (%gx%g)%@", path, size.width, size.height, ok ? "" : ": not written")
    }

    // MARK: the script commands

    func event(_ args: String) {
        let a = args.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        let verb = a.first ?? ""
        let rest = a.dropFirst().joined(separator: " ")
        switch verb {
        case "connect":
            var w = 800, h = 480, s = 2.0
            if a.count > 1 {
                let p = a[1].split(whereSeparator: { $0 == "x" || $0 == "@" }).compactMap { Double($0) }
                if p.count >= 2 { w = Int(p[0]); h = Int(p[1]) }
                if p.count >= 3 { s = p[2] }
            }
            connect(w, h, s)
        case "disconnect": disconnect()
        case "shot": shot(rest)
        case "style": setStyle(rest == "light" ? .light : .dark)
        case "limit": setLimited(rest == "lists" ? .lists : rest == "keyboard" ? .keyboard : rest == "all" ? [.lists, .keyboard] : [])
        case "park": parked = rest != "off"; NSLog("isim CarPlay: car %@", parked ? "parked" : "driving")
        default:
            guard screen != nil, let sys = system else { NSLog("isim CarPlay: no CarPlay screen is connected (carplay connect)"); return }
            render()
            switch verb {
            case "tap":
                let nums = a.dropFirst().compactMap { Double($0) }
                if nums.count == 2 { sys.root.tap(at: CGPoint(x: nums[0], y: nums[1])) } else { sys.root.tap(id: rest) }
            case "taptext": sys.root.tap(text: rest)
            case "back": sys.root.tap(id: "cp-back")
            case "scroll":
                guard let t = controller?._stack.last.map({ ($0 as? CPTabBarTemplate)?.selectedTemplate ?? $0 }) else { return }
                let k = ObjectIdentifier(t)
                scroll[k] = max(0, (scroll[k] ?? 0) + (rest == "up" ? -1 : 1) * (size.height - 120))
                NSLog("isim CarPlay: scroll %@", rest)
                setNeedsRender()
            case "search":
                guard let s = controller?._stack.last as? CPSearchTemplate else { NSLog("isim CarPlay: carplay search: no search template is shown"); return }
                s._type(rest)
                NSLog("isim CarPlay: search “%@”", rest)
            case "pan":
                guard let m = controller?._stack.last as? CPMapTemplate else { return }
                let d: CPMapTemplate.PanDirection = rest == "up" ? .up : rest == "down" ? .down : rest == "left" ? .left : .right
                m._pan(d)
                NSLog("isim CarPlay: pan %@", rest)
            case "dump": sys.root.dump()
            default: NSLog("isim CarPlay: carplay: unknown command '%@'", args)
            }
        }
    }
}

/// the window isim draws CarPlay in (its status bar, the templates); on the CarPlay screen, never on the device
final class _CPSystemWindow: UIWindow {
    let root: _CPRootView
    init(frame: CGRect, screen: UIScreen) {
        root = _CPRootView(frame: CGRect(origin: .zero, size: frame.size))
        super.init(frame: frame)
        self.screen = screen
        backgroundColor = .clear
        addSubview(root)
        isHidden = false
    }
    required init?(coder: NSCoder) { fatalError() }
}

/// UIKit sends `carplay ARGS` script commands here (UISystemIntegration.m)
@_cdecl("isim_carplay_event")
public func _isimCarPlayEvent(_ args: UnsafePointer<CChar>) {
    let s = String(cString: args)
    if Thread.isMainThread { _CPCar.shared.event(s) } else { DispatchQueue.main.async { _CPCar.shared.event(s) } }
}
