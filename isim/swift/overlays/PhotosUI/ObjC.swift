// isim PhotosUI: the Objective-C interface (sdk-src/Frameworks/PhotosUI, issue #545). PHPickerViewController is
// @objc(PHPickerViewController); PHPickerConfiguration, PHPickerFilter and PHPickerResult are Swift structs, so
// Objective-C has classes of those names (frameworks/PhotosUI/PhotosUI.m), read and made here through key-value coding.
import UIKit

/// Apple's PHPickerViewControllerDelegate as Objective-C sees it (Swift has its own, non-@objc protocol)
@objc(PHPickerViewControllerDelegate) protocol _PUObjCPickerDelegate: NSObjectProtocol {
    @objc(picker:didFinishPicking:) func picker(_ picker: PHPickerViewController, didFinishPicking results: [NSObject])
}

enum _PUObjC {
    /// an Objective-C PHPickerFilter (its _isim_kind, or _isim_op over _isim_subfilters) as the Swift struct
    static func filter(_ o: NSObject) -> PHPickerFilter {
        if let k = o.value(forKey: "_isim_kind") as? String { return PHPickerFilter(.kind(k)) }
        let subs = (o.value(forKey: "_isim_subfilters") as? [NSObject] ?? []).map { filter($0).rule }
        switch o.value(forKey: "_isim_op") as? String {
        case "all": return PHPickerFilter(.all(subs))
        case "not": return PHPickerFilter(.not(subs.first ?? .any([])))
        default: return PHPickerFilter(.any(subs))
        }
    }
    static func configuration(_ o: NSObject) -> PHPickerConfiguration {
        var c = (o.value(forKey: "_isim_withPhotoLibrary") as? Bool) == true ? PHPickerConfiguration(photoLibrary: .shared()) : PHPickerConfiguration()
        c.selectionLimit = (o.value(forKey: "selectionLimit") as? Int) ?? 1
        c.preselectedAssetIdentifiers = o.value(forKey: "preselectedAssetIdentifiers") as? [String] ?? []
        c.selection = PHPickerConfiguration.Selection(rawValue: (o.value(forKey: "selection") as? Int) ?? 0) ?? .default
        c.preferredAssetRepresentationMode = PHPickerConfiguration.AssetRepresentationMode(rawValue: (o.value(forKey: "preferredAssetRepresentationMode") as? Int) ?? 0) ?? .automatic
        c.filter = (o.value(forKey: "filter") as? NSObject).map(filter)
        return c
    }
    /// a Swift result as an Objective-C PHPickerResult
    static func result(_ r: PHPickerResult) -> NSObject? {
        guard let cls = NSClassFromString("PHPickerResult") as? NSObject.Type else { return nil }
        let o = cls.init()
        o.setValue(r.itemProvider, forKey: "itemProvider")
        o.setValue(r.assetIdentifier, forKey: "assetIdentifier")
        return o
    }
}

extension PHPickerViewController {
    @objc(initWithConfiguration:) convenience init(_objcConfiguration o: NSObject) {
        self.init(configuration: _PUObjC.configuration(o))
        _objcConfiguration = o.copy() as? NSObject
    }
    @objc(configuration) var _objcConfigurationCopy: NSObject? { _objcConfiguration?.copy() as? NSObject }
    @objc(delegate) var _objcDelegateProperty: _PUObjCPickerDelegate? {
        get { _objcDelegate }
        set { _objcDelegate = newValue }
    }
}
