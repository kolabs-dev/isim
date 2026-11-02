// isim SafariServices (issue #423): SFSafariViewController.ActivityButton, SFAddToHomeScreenActivityItem and
// SFSafariSettings.
// - ActivityButton: the Safari extension button an app adds to SFSafariViewController's share sheet. isim has no Safari
//   extensions, so the button is kept in the configuration and nothing runs it.
// - SFAddToHomeScreenActivityItem: an activity item conforming to it makes the share sheet offer "Add to Home Screen"
//   (UIKit's UIActivity.m), which saves a web clip in the device data; the home screen shows it and opens its URL in Safari.
// - SFSafariSettings: opens Safari's pages in isim's Settings app (Settings > Apps > Safari), and reads its AutoFill switch.
import UIKit

extension SFSafariViewController {
    /// a Safari extension's button in the share sheet (isim: kept, not run)
    @objc(SFSafariViewControllerActivityButton) open class ActivityButton: NSObject, NSCopying, NSSecureCoding, @unchecked Sendable {
        @objc open private(set) var templateImage: UIImage?
        @objc open private(set) var extensionIdentifier: String?
        @objc(initWithTemplateImage:extensionIdentifier:) public init(templateImage: UIImage, extensionIdentifier: String) {
            self.templateImage = templateImage; self.extensionIdentifier = extensionIdentifier
            super.init()
        }
        public static var supportsSecureCoding: Bool { true }
        public func encode(with coder: NSCoder) {
            coder.encode(templateImage, forKey: "templateImage"); coder.encode(extensionIdentifier, forKey: "extensionIdentifier")
        }
        public required init?(coder: NSCoder) {
            templateImage = coder.decodeObject(of: UIImage.self, forKey: "templateImage")
            extensionIdentifier = coder.decodeObject(of: NSString.self, forKey: "extensionIdentifier") as String?
            super.init()
        }
        public func copy(with zone: NSZone? = nil) -> Any { self }
    }
}

/// an activity item that can be added to the Home Screen as a web clip (iOS 17.4)
@available(iOS 17.4, *)
@objc(SFAddToHomeScreenActivityItem) public protocol SFAddToHomeScreenActivityItem: UIActivityItemSource {
    @objc(URL) var url: URL { get }
    @objc var title: String { get }
    @objc optional var iconItemProvider: NSItemProvider? { get }
}

public let SFSafariSettingsErrorDomain = "SFSafariSettingsErrorDomain"
/// why SFSafariSettings could not open Settings
public enum SFSafariSettingsError: Int, Error, Sendable {
    case notAllowed = 1, failed = 2
    public static var errorDomain: String { SFSafariSettingsErrorDomain }
}

/// opens Safari's pages in Settings (iOS 26)
@available(iOS 26.0, *)
@objc(SFSafariSettings) open class SFSafariSettings: NSObject, @unchecked Sendable {
    @MainActor static func open(_ page: String, _ completionHandler: ((Error?) -> Void)?) {
        guard let url = URL(string: "app-settings:@" + page) else { completionHandler?(SFSafariSettingsError.failed); return }
        UIApplication.shared.open(url, options: [:]) { ok in
            NSLog("isim: SFSafariSettings opened %@: %@", page, ok ? "yes" : "no")
            completionHandler?(ok ? nil : SFSafariSettingsError.failed)
        }
    }
    /// Settings > Apps > Safari > Export Browsing Data
    @objc(openExportBrowsingDataSettingsWithCompletionHandler:)
    open class func openExportBrowsingDataSettings(completionHandler: (@Sendable (Error?) -> Void)? = nil) {
        MainActor.assumeIsolated { open("safari-export", completionHandler) }
    }
    /// whether Settings > Apps > Safari > AutoFill Names and Passwords is on (isim's Settings keeps it in the global
    /// preferences; on unless turned off)
    @objc(checkAutoFillUserNamesAndPasswordsEnabledWithCompletionHandler:)
    open class func checkAutoFillUserNamesAndPasswordsEnabled(completionHandler: @escaping @Sendable (Bool, Error?) -> Void) {
        let on = UserDefaults(suiteName: ".GlobalPreferences")?.object(forKey: "ISIMSafariAutoFillPasswords") as? Bool ?? true
        DispatchQueue.main.async { completionHandler(on, nil) }
    }
    /// Settings > Apps > Safari > Extensions, with these extensions' pages (iOS 26.2)
    @available(iOS 26.2, *)
    @objc(openExtensionsSettingsForIdentifiers:completionHandler:)
    open class func openExtensionsSettings(forIdentifiers identifiers: [String], completionHandler: (@Sendable (Error?) -> Void)? = nil) {
        let ids = identifiers.compactMap { $0.addingPercentEncoding(withAllowedCharacters: .alphanumerics.union(CharacterSet(charactersIn: ".-_"))) }
        MainActor.assumeIsolated { open("safari-extensions" + (ids.isEmpty ? "" : "?" + ids.joined(separator: ",")), completionHandler) }
    }
}
