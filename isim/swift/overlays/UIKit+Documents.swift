// isim UIKit overlay: the UTType initializers of UIDocumentPickerViewController and UIDocumentBrowserViewController
// (isim's UTType is a Swift type, so the Objective-C classes take type identifiers; see UIDocumentPicker.m).
import UniformTypeIdentifiers

extension UIDocumentPickerViewController {
    public convenience init(forOpeningContentTypes contentTypes: [UTType], asCopy: Bool) {
        self.init(_isimOpeningTypeIdentifiers: contentTypes.map(\.identifier), asCopy: asCopy)
    }
    public convenience init(forOpeningContentTypes contentTypes: [UTType]) { self.init(forOpeningContentTypes: contentTypes, asCopy: false) }
}

extension UIDocumentBrowserViewController {
    public convenience init(forOpening contentTypes: [UTType]?) { self.init(_isimOpeningTypeIdentifiers: contentTypes?.map(\.identifier)) }
    public var contentTypesForRecentDocuments: [UTType] { (allowedContentTypes ?? []).compactMap { UTType($0) } }
}
