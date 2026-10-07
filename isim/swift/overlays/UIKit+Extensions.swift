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
                let p = NSItemProvider(contentsOf: url) ?? NSItemProvider(item: u, typeIdentifier: UTType.fileURL.identifier)
                p._isimSetItem(u, forTypeIdentifier: UTType.fileURL.identifier)
                out.append(p)
            } else {
                out.append(NSItemProvider(item: u, typeIdentifier: UTType.url.identifier))
            }
        } else if let image = item as? UIImage {
            let p = NSItemProvider()
            let png = image.pngData()
            p.registerDataRepresentation(forTypeIdentifier: UTType.png.identifier, visibility: .all) { done in
                done(png, png == nil ? NSError(domain: NSItemProviderErrorDomain, code: -1000) : nil); return nil
            }
            if let png { p._isimSetItem(png as NSData, forTypeIdentifier: UTType.png.identifier) }
            out.append(p)
        } else if let d = item as? NSData {
            out.append(NSItemProvider(item: d, typeIdentifier: UTType.data.identifier))
        }
    }
    return out as NSArray
}
