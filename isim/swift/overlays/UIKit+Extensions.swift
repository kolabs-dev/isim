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
