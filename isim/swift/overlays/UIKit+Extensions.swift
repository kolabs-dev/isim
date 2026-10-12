// isim UIKit overlay: app extension items (self-authored).
// UIActivityViewController (Objective-C, UIActivity.m) hosts Share and Action extensions in the app's process; this
// turns its activity items into NSItemProviders (a Swift class on isim, UniformTypeIdentifiers) for the extension's
// NSExtensionItem: strings are public.plain-text, web URLs public.url, file URLs public.file-url (plus their own type),
// images PNG data (public.png), data public.data. loadItem gives back the string / URL itself, like iOS.

@_cdecl("isim_uikit_item_providers")
public func _isimItemProviders(_ raw: NSArray) -> NSArray {
    var out: [NSItemProvider] = []
    for index in 0..<raw.count {
        let item = raw.object(at: index) as AnyObject
        if let s = item as? NSString {
            out.append(NSItemProvider(item: s, typeIdentifier: UTType.plainText.identifier))
        } else if let a = item as? NSAttributedString {
            out.append(NSItemProvider(item: a.string as NSString, typeIdentifier: UTType.plainText.identifier))
        } else if let u = item as? NSURL {
            if u.isFileURL, let path = u.path {
                let url = URL(fileURLWithPath: path)
                let p = NSItemProvider(item: u, typeIdentifier: UTType.fileURL.identifier)       // loadItem gives the URL back
                let type = UTType(filenameExtension: url.pathExtension) ?? .data
                p.registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: [], visibility: .all) { done in done(url, false, nil); return nil }
                p.suggestedName = url.deletingPathExtension().lastPathComponent
                out.append(p)
            } else {
                out.append(NSItemProvider(item: u, typeIdentifier: UTType.url.identifier))
            }
        } else if let image = item as? UIImage {
            out.append(image.pngData().map { NSItemProvider(item: $0 as NSData, typeIdentifier: UTType.png.identifier) } ?? NSItemProvider(object: image))
        } else if let d = item as? NSData {
            out.append(NSItemProvider(item: d, typeIdentifier: UTType.data.identifier))
        }
    }
    return out as NSArray
}

// MARK: - band selection (iOS 15): the band rect is optional in Swift
@available(iOS 15.0, *)
extension UIBandSelectionInteraction {
    public var selectionRect: CGRect? { let r = __selectionRect; return r.isNull ? nil : r }
}

// MARK: - UIImage baselines and UIImageReader (part 10 of #9)
extension UIImage {
    /// the baseline's offset from the bottom, if the image has a baseline (symbols do)
    public var baselineOffsetFromBottom: CGFloat? { __hasBaseline ? __baselineOffsetFromBottom : nil }
}

/// reads images with options (iOS 17): HDR (isim: standard dynamic range), preparing for display, thumbnails, pixel density
@available(iOS 17.0, *)
public struct UIImageReader: Sendable {
    public struct Configuration: Sendable {
        public var prefersHighDynamicRange = false
        public var preparesImagesForDisplay = true
        public var preferredThumbnailSize = CGSize.zero
        public var pixelsPerInch: CGFloat = 0
        public init() {}
    }
    public let configuration: Configuration
    public static let `default` = UIImageReader(configuration: Configuration())
    public init(configuration: Configuration) { self.configuration = configuration }
    private func reader() -> __UIImageReader {
        let c = __UIImageReaderConfiguration()
        c.prefersHighDynamicRange = configuration.prefersHighDynamicRange
        c.preparesImagesForDisplay = configuration.preparesImagesForDisplay
        c.preferredThumbnailSize = configuration.preferredThumbnailSize
        c.pixelsPerInch = configuration.pixelsPerInch
        return __UIImageReader(configuration: c)
    }
    public func image(contentsOf url: URL) -> UIImage? { reader().image(withContentsOfFileURL: url) }
    public func image(data: Data) -> UIImage? { reader().image(with: data) }
    public func image(contentsOf url: URL) async -> UIImage? { await reader().image(withContentsOfFileURL: url) }
    public func image(data: Data) async -> UIImage? { await reader().image(with: data) }
}

/// printing errors as a Swift error type (`catch let e as UIPrintError`, `e.code == .jobFailed`)
public struct UIPrintError: CustomNSError, Hashable, _ObjectiveCBridgeableError {
    public typealias Code = UIPrintErrorCode
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public init?(_bridgedNSError e: __shared NSError) {
        guard e.domain == UIPrintErrorDomain, let c = Code(rawValue: e.code) else { return nil }
        self.init(c)
    }
    public static var errorDomain: String { UIPrintErrorDomain }
    public var errorCode: Int { code.rawValue }
    public static var notAvailable: Code { .notAvailable }
    public static var noContent: Code { .noContent }
    public static var unknownImageFormat: Code { .unknownImageFormat }
    public static var jobFailed: Code { .jobFailed }
}
