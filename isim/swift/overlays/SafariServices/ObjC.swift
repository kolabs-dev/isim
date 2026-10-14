// isim SafariServices for Objective-C (sdk-src/Frameworks/SafariServices): the classes carry Apple's Objective-C names
// and these members Apple's selectors. SFSafariViewControllerDelegate is an @objc protocol, so Objective-C delegates
// are used as they are.
import UIKit

extension SFSafariViewController.Configuration {
    @objc(entersReaderIfAvailable) var _objc_entersReaderIfAvailable: Bool { get { entersReaderIfAvailable } set { entersReaderIfAvailable = newValue } }
    @objc(barCollapsingEnabled) var _objc_barCollapsingEnabled: Bool { get { barCollapsingEnabled } set { barCollapsingEnabled = newValue } }
}

extension SFSafariViewController {
    @objc(initWithURL:configuration:) convenience init(_objcURL url: URL, configuration: Configuration) { self.init(url: url, configuration: configuration) }
    @objc(initWithURL:) convenience init(_objcURL url: URL) { self.init(url: url) }
    @objc(initWithURL:entersReaderIfAvailable:) convenience init(_objcURL url: URL, entersReaderIfAvailable: Bool) {
        self.init(url: url, entersReaderIfAvailable: entersReaderIfAvailable)
    }
    @objc(delegate) var _objc_delegate: SFSafariViewControllerDelegate? { get { delegate } set { delegate = newValue } }
    @objc(configuration) var _objc_configuration: Configuration { configuration }
    @objc(preferredBarTintColor) var _objc_preferredBarTintColor: UIColor? { get { preferredBarTintColor } set { preferredBarTintColor = newValue } }
    @objc(preferredControlTintColor) var _objc_preferredControlTintColor: UIColor? {
        get { preferredControlTintColor } set { preferredControlTintColor = newValue }
    }
    @objc(dismissButtonStyle) var _objc_dismissButtonStyle: DismissButtonStyle { get { dismissButtonStyle } set { dismissButtonStyle = newValue } }
}

extension SSReadingList {
    @objc(defaultReadingList) class func _objc_default() -> SSReadingList? { self.default() }
    @objc(supportsURL:) class func _objc_supportsURL(_ url: URL) -> Bool { supportsURL(url) }
    @objc(addReadingListItemWithURL:title:previewText:error:)
    func _objc_addItem(_ url: URL, title: String?, previewText: String?) throws { try addItem(with: url, title: title, previewText: previewText) }
}
