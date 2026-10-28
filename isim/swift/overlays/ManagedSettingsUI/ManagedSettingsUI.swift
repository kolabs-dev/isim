// isim ManagedSettingsUI (adapted): how a shield looks. A Shield Configuration extension
// (com.apple.ManagedSettingsUI.shield-configuration-service, its principal class a ShieldConfigurationDataSource
// subclass) runs as a helper process the home screen starts before it shows its app's shield over a shielded app
// (system/SpringBoard/SBScreenTime.m); the configuration goes back as a property list (colors as RGBA, the icon as a
// PNG file beside the request). Without one the home screen shows iOS's default shield.
import Foundation
import UIKit
import ManagedSettings

public struct ShieldConfiguration {
    public struct Label {
        public let text: String
        public let color: UIColor
        public init(text: String, color: UIColor) { self.text = text; self.color = color }
    }
    public let backgroundBlurStyle: UIBlurEffect.Style?
    public let backgroundColor: UIColor?
    public let icon: UIImage?
    public let title: ShieldConfiguration.Label?
    public let subtitle: ShieldConfiguration.Label?
    public let primaryButtonLabel: ShieldConfiguration.Label?
    public let primaryButtonBackgroundColor: UIColor?
    public let secondaryButtonLabel: ShieldConfiguration.Label?
    @available(iOS 26.4, *)
    public var secondaryButtonSubmenuItems: [String]? { _submenu }
    let _submenu: [String]?

    public init(backgroundBlurStyle: UIBlurEffect.Style? = nil, backgroundColor: UIColor? = nil, icon: UIImage? = nil, title: ShieldConfiguration.Label? = nil,
                subtitle: ShieldConfiguration.Label? = nil, primaryButtonLabel: ShieldConfiguration.Label? = nil, primaryButtonBackgroundColor: UIColor? = nil,
                secondaryButtonLabel: ShieldConfiguration.Label? = nil) {
        self.backgroundBlurStyle = backgroundBlurStyle; self.backgroundColor = backgroundColor; self.icon = icon; self.title = title
        self.subtitle = subtitle; self.primaryButtonLabel = primaryButtonLabel; self.primaryButtonBackgroundColor = primaryButtonBackgroundColor
        self.secondaryButtonLabel = secondaryButtonLabel; _submenu = nil
    }
    @available(iOS 26.4, *)
    public init(backgroundBlurStyle: UIBlurEffect.Style? = nil, backgroundColor: UIColor? = nil, icon: UIImage? = nil, title: ShieldConfiguration.Label? = nil,
                subtitle: ShieldConfiguration.Label? = nil, primaryButtonLabel: ShieldConfiguration.Label? = nil, primaryButtonBackgroundColor: UIColor? = nil,
                secondaryButtonLabel: ShieldConfiguration.Label? = nil, secondaryButtonSubmenuItems: [String]? = nil) {
        self.backgroundBlurStyle = backgroundBlurStyle; self.backgroundColor = backgroundColor; self.icon = icon; self.title = title
        self.subtitle = subtitle; self.primaryButtonLabel = primaryButtonLabel; self.primaryButtonBackgroundColor = primaryButtonBackgroundColor
        self.secondaryButtonLabel = secondaryButtonLabel; _submenu = secondaryButtonSubmenuItems
    }
}

/// the principal class of a Shield Configuration extension: subclass it and return a configuration per shield
@objc(ShieldConfigurationDataSource)
open class ShieldConfigurationDataSource: NSObject {
    public override init() { super.init() }
    open func configuration(shielding application: Application) -> ShieldConfiguration { ShieldConfiguration() }
    open func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration { ShieldConfiguration() }
    open func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration { ShieldConfiguration() }
    open func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration { ShieldConfiguration() }
}

// MARK: - the extension's process

func _rgba(_ c: UIColor?) -> [Double]? {
    guard let c else { return nil }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    c.getRed(&r, green: &g, blue: &b, alpha: &a)
    return [Double(r), Double(g), Double(b), Double(a)]
}
func _label(_ l: ShieldConfiguration.Label?) -> [String: Any]? {
    guard let l else { return nil }
    return ["text": l.text, "color": _rgba(l.color) ?? [0, 0, 0, 1]]
}

/// a Shield Configuration extension's process (UIKit's NSExtensionMain for its extension point)
@_cdecl("isim_msui_extension_main")
public func _isimMSUIExtensionMain(_ argc: Int32, _ argv: UnsafeMutablePointer<UnsafeMutablePointer<CChar>?>) -> Int32 {
    _IsimScreenTime.serve { reply in
        guard let req = _IsimScreenTime.extensionRequest, let ds = _IsimScreenTime.principal(ShieldConfigurationDataSource.self) else { reply([:]); return }
        let token = req["token"] as? String ?? ""
        let category = (req["category"] as? String).map { ActivityCategory(token: _IsimScreenTime.categoryToken($0)) }
        let c: ShieldConfiguration
        if req["target"] as? String == "webDomain" {
            let w = WebDomain(token: _IsimScreenTime.token(id: token))
            c = category.map { ds.configuration(shielding: w, in: $0) } ?? ds.configuration(shielding: w)
        } else {
            let a = Application(token: _IsimScreenTime.token(id: token))
            c = category.map { ds.configuration(shielding: a, in: $0) } ?? ds.configuration(shielding: a)
        }
        var out: [String: Any] = [:]
        if let s = c.backgroundBlurStyle { out["blur"] = s.rawValue }
        if let b = _rgba(c.backgroundColor) { out["background"] = b }
        if let b = _rgba(c.primaryButtonBackgroundColor) { out["primaryBackground"] = b }
        for (k, l) in [("title", c.title), ("subtitle", c.subtitle), ("primary", c.primaryButtonLabel), ("secondary", c.secondaryButtonLabel)] {
            if let d = _label(l) { out[k] = d }
        }
        if let items = c._submenu { out["submenu"] = items }
        if let icon = c.icon, let png = icon.pngData(), let o = req["out"] as? String {
            let p = (o as NSString).deletingPathExtension + "-icon.png"
            FileManager.default.createFile(atPath: p, contents: png)
            out["icon"] = p
        }
        reply(out)
    }
}
