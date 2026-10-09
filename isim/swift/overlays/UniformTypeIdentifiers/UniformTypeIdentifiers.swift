// isim UniformTypeIdentifiers (self-authored, iOS API names): UTType with the common system types, conformance
// (a fixed hierarchy), filename extensions and MIME types; plus NSItemProvider (Foundation on iOS; isim keeps it here
// next to the type system it needs — apps get it through PhotosUI or `import UniformTypeIdentifiers`).
import Foundation

public struct UTType: Hashable, Sendable, CustomStringConvertible, Codable {
    public let identifier: String
    let parents: [String]
    let exts: [String]
    let mimes: [String]
    let dynamic: Bool

    init(_ id: String, _ parents: [String], ext: [String] = [], mime: [String] = [], dynamic: Bool = false) {
        identifier = id; self.parents = parents; exts = ext; mimes = mime; self.dynamic = dynamic
    }
    public init?(_ identifier: String) {
        if let t = UTType.known[identifier] { self = t } else { self.init(identifier, ["public.data"], dynamic: false) }
    }
    public init?(filenameExtension: String) { self.init(filenameExtension: filenameExtension, conformingTo: .data) }
    public init?(filenameExtension: String, conformingTo supertype: UTType) {
        let e = filenameExtension.lowercased()
        if let t = UTType.all.first(where: { $0.exts.contains(e) && $0.conforms(to: supertype) }) { self = t }
        else { self.init("dyn.isim-ext-\(e)", [supertype.identifier], ext: [e], dynamic: true) }
    }
    public init?(mimeType: String) { self.init(mimeType: mimeType, conformingTo: .data) }
    public init?(mimeType: String, conformingTo supertype: UTType) {
        let m = mimeType.lowercased()
        guard let t = UTType.all.first(where: { $0.mimes.contains(m) && $0.conforms(to: supertype) }) else { return nil }
        self = t
    }
    public init(exportedAs identifier: String, conformingTo parentType: UTType? = nil) { self.init(identifier, [parentType?.identifier ?? "public.data"]) }
    public init(importedAs identifier: String, conformingTo parentType: UTType? = nil) { self.init(identifier, [parentType?.identifier ?? "public.data"]) }

    public var preferredFilenameExtension: String? { exts.first }
    public var preferredMIMEType: String? { mimes.first }
    public var tags: [String: [String]] { ["public.filename-extension": exts, "public.mime-type": mimes] }
    public var isDynamic: Bool { dynamic }
    public var isDeclared: Bool { !dynamic }
    public var isPublicType: Bool { identifier.hasPrefix("public.") }
    public var isSystemDeclared: Bool { UTType.known[identifier] != nil }
    public var localizedDescription: String? { identifier }
    public var description: String { identifier }
    public var supertypes: Set<UTType> {
        var out = Set<UTType>(), todo = parents
        while let p = todo.popLast() { if let t = UTType.known[p], out.insert(t).inserted { todo += t.parents } }
        return out
    }
    public func conforms(to type: UTType) -> Bool { type.identifier == identifier || supertypes.contains { $0.identifier == type.identifier } }
    public func isSupertype(of type: UTType) -> Bool { type.conforms(to: self) }
    public func isSubtype(of type: UTType) -> Bool { conforms(to: type) && type != self }
    public static func == (a: UTType, b: UTType) -> Bool { a.identifier == b.identifier }
    public func hash(into h: inout Hasher) { h.combine(identifier) }
    public init(from decoder: Decoder) throws { let s = try decoder.singleValueContainer().decode(String.self); self = UTType(s) ?? .data }
    public func encode(to encoder: Encoder) throws { var c = encoder.singleValueContainer(); try c.encode(identifier) }

    public static let item = UTType("public.item", [])
    public static let content = UTType("public.content", [])
    public static let data = UTType("public.data", ["public.item"])
    public static let compositeContent = UTType("public.composite-content", ["public.content"])
    public static let text = UTType("public.text", ["public.data", "public.content"])
    public static let plainText = UTType("public.plain-text", ["public.text"], ext: ["txt"], mime: ["text/plain"])
    public static let utf8PlainText = UTType("public.utf8-plain-text", ["public.plain-text"])
    public static let utf16PlainText = UTType("public.utf16-plain-text", ["public.plain-text"])
    public static let rtf = UTType("public.rtf", ["public.text"], ext: ["rtf"], mime: ["text/rtf"])
    public static let html = UTType("public.html", ["public.text"], ext: ["html", "htm"], mime: ["text/html"])
    public static let xml = UTType("public.xml", ["public.text"], ext: ["xml"], mime: ["application/xml", "text/xml"])
    public static let sourceCode = UTType("public.source-code", ["public.plain-text"])
    public static let swiftSource = UTType("public.swift-source", ["public.source-code"], ext: ["swift"])
    public static let json = UTType("public.json", ["public.text"], ext: ["json"], mime: ["application/json"])
    public static let commaSeparatedText = UTType("public.comma-separated-values-text", ["public.text"], ext: ["csv"], mime: ["text/csv"])
    public static let propertyList = UTType("com.apple.property-list", ["public.data"], ext: ["plist"])
    public static let url = UTType("public.url", ["public.data"])
    public static let fileURL = UTType("public.file-url", ["public.url"])
    public static let image = UTType("public.image", ["public.data", "public.content"])
    public static let png = UTType("public.png", ["public.image"], ext: ["png"], mime: ["image/png"])
    public static let jpeg = UTType("public.jpeg", ["public.image"], ext: ["jpeg", "jpg", "jpe"], mime: ["image/jpeg", "image/jpg"])
    public static let heic = UTType("public.heic", ["public.heif-standard", "public.image"], ext: ["heic"], mime: ["image/heic"])
    public static let heif = UTType("public.heif", ["public.image"], ext: ["heif"], mime: ["image/heif"])
    public static let gif = UTType("com.compuserve.gif", ["public.image"], ext: ["gif"], mime: ["image/gif"])
    public static let tiff = UTType("public.tiff", ["public.image"], ext: ["tiff", "tif"], mime: ["image/tiff"])
    public static let bmp = UTType("com.microsoft.bmp", ["public.image"], ext: ["bmp"], mime: ["image/bmp"])
    public static let svg = UTType("public.svg-image", ["public.image"], ext: ["svg"], mime: ["image/svg+xml"])
    public static let webP = UTType("org.webmproject.webp", ["public.image"], ext: ["webp"], mime: ["image/webp"])
    public static let rawImage = UTType("public.camera-raw-image", ["public.image"])
    public static let livePhoto = UTType("com.apple.live-photo", [])
    public static let audiovisualContent = UTType("public.audiovisual-content", ["public.data", "public.content"])
    public static let movie = UTType("public.movie", ["public.audiovisual-content"])
    public static let video = UTType("public.video", ["public.movie"])
    public static let quickTimeMovie = UTType("com.apple.quicktime-movie", ["public.movie"], ext: ["mov", "qt"], mime: ["video/quicktime"])
    public static let mpeg4Movie = UTType("public.mpeg-4", ["public.movie"], ext: ["mp4"], mime: ["video/mp4"])
    public static let audio = UTType("public.audio", ["public.audiovisual-content"])
    public static let mp3 = UTType("public.mp3", ["public.audio"], ext: ["mp3"], mime: ["audio/mpeg"])
    public static let mpeg4Audio = UTType("public.mpeg-4-audio", ["public.audio"], ext: ["m4a"], mime: ["audio/mp4"])
    public static let wav = UTType("com.microsoft.waveform-audio", ["public.audio"], ext: ["wav"], mime: ["audio/wav"])
    public static let pdf = UTType("com.adobe.pdf", ["public.data", "public.composite-content"], ext: ["pdf"], mime: ["application/pdf"])
    public static let archive = UTType("public.archive", ["public.data"])
    public static let zip = UTType("public.zip-archive", ["public.archive"], ext: ["zip"], mime: ["application/zip"])
    public static let contact = UTType("public.contact", ["public.item"])
    public static let vCard = UTType("public.vcard", ["public.text", "public.contact"], ext: ["vcf", "vcard"], mime: ["text/vcard"])
    public static let calendarEvent = UTType("public.calendar-event", ["public.item"])
    public static let emailMessage = UTType("public.email-message", ["public.data"], ext: ["eml"])
    public static let folder = UTType("public.folder", ["public.directory"])
    public static let directory = UTType("public.directory", ["public.item"])
    public static let executable = UTType("public.executable", ["public.item"])
    public static let font = UTType("public.font", ["public.data"])

    static let all: [UTType] = [item, content, data, compositeContent, text, plainText, utf8PlainText, utf16PlainText, rtf, html, xml, sourceCode,
                                swiftSource, json, commaSeparatedText, propertyList, url, fileURL, image, png, jpeg, heic, heif, gif, tiff, bmp, svg, webP,
                                rawImage, livePhoto, audiovisualContent, movie, video, quickTimeMovie, mpeg4Movie, audio, mp3, mpeg4Audio, wav, pdf,
                                archive, zip, contact, vCard, calendarEvent, emailMessage, folder, directory, executable, font,
                                UTType("public.heif-standard", ["public.image"])]
    static let known: [String: UTType] = Dictionary(uniqueKeysWithValues: all.map { ($0.identifier, $0) })

    public static func types(tag: String, tagClass: UTTagClass, conformingTo supertype: UTType?) -> [UTType] {
        let t = tag.lowercased()
        return all.filter { (tagClass == .filenameExtension ? $0.exts : $0.mimes).contains(t) && (supertype.map($0.conforms(to:)) ?? true) }
    }
}

public struct UTTagClass: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let filenameExtension = UTTagClass(rawValue: "public.filename-extension")
    public static let mimeType = UTTagClass(rawValue: "public.mime-type")
}

extension URL {
    public func appendingPathExtension(for contentType: UTType) -> URL {
        guard let e = contentType.preferredFilenameExtension else { return self }
        return appendingPathExtension(e)
    }
}

// MARK: - NSItemProvider (Foundation) with UTTypes, as on iOS

/// Foundation's NSItemProvider asks this for type conformance (declared types included) when the module is loaded.
@_cdecl("isim_uti_type_conforms")
public func _isimUTITypeConforms(_ have: UnsafePointer<CChar>, _ want: UnsafePointer<CChar>) -> Int32 {
    let h = String(cString: have), w = String(cString: want)
    if h == w { return 1 }
    guard let a = UTType(h), let b = UTType(w) else { return 0 }
    return a.conforms(to: b) ? 1 : 0
}
/// the type of a filename extension (a malloc'd C string for Foundation, or NULL)
@_cdecl("isim_uti_type_for_extension")
public func _isimUTITypeForExtension(_ ext: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>? {
    guard let t = UTType(filenameExtension: String(cString: ext)) else { return nil }
    return strdup(t.identifier)
}

extension NSItemProvider {
    public func hasItemConforming(to contentType: UTType) -> Bool { hasItemConformingToTypeIdentifier(contentType.identifier) }
    public func hasRepresentationConforming(to contentType: UTType, fileOptions: NSItemProviderFileOptions = []) -> Bool {
        hasRepresentationConforming(toTypeIdentifier: contentType.identifier, fileOptions: fileOptions)
    }
    public var registeredContentTypes: [UTType] { registeredTypeIdentifiers.compactMap { UTType($0) } }
    public var registeredContentTypesForOpenInPlace: [UTType] { registeredTypeIdentifiers(fileOptions: .openInPlace).compactMap { UTType($0) } }
    public func registeredContentTypes(conformingTo contentType: UTType) -> [UTType] { registeredContentTypes.filter { $0.conforms(to: contentType) } }
    @discardableResult
    public func loadDataRepresentation(for contentType: UTType, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress {
        loadDataRepresentation(forTypeIdentifier: contentType.identifier, completionHandler: completionHandler)
    }
    @discardableResult
    public func loadFileRepresentation(for contentType: UTType, openInPlace: Bool = false, completionHandler: @escaping @Sendable (URL?, Bool, Error?) -> Void) -> Progress {
        if openInPlace { return loadInPlaceFileRepresentation(forTypeIdentifier: contentType.identifier, completionHandler: completionHandler) ?? Progress(totalUnitCount: 1) }
        return loadFileRepresentation(forTypeIdentifier: contentType.identifier) { u, e in completionHandler(u, false, e) }
    }
    public func registerDataRepresentation(for contentType: UTType, visibility: NSItemProviderRepresentationVisibility = .all,
                                           loadHandler: @escaping @Sendable (@escaping @Sendable (Data?, Error?) -> Void) -> Progress?) {
        registerDataRepresentation(forTypeIdentifier: contentType.identifier, visibility: visibility) { done in
            loadHandler { d, e in done(d, e) }
        }
    }
    public func registerFileRepresentation(for contentType: UTType, visibility: NSItemProviderRepresentationVisibility = .all, openInPlace: Bool = false,
                                           loadHandler: @escaping @Sendable (@escaping @Sendable (URL?, Bool, Error?) -> Void) -> Progress?) {
        registerFileRepresentation(forTypeIdentifier: contentType.identifier, fileOptions: openInPlace ? .openInPlace : [], visibility: visibility) { done in
            loadHandler { u, c, e in done(u, c, e) }
        }
    }
    public convenience init(contentsOf fileURL: URL?, contentType: UTType?, openInPlace: Bool = false, coordinated: Bool = false,
                            visibility: NSItemProviderRepresentationVisibility = .all) {
        self.init()
        guard let fileURL else { return }
        suggestedName = fileURL.deletingPathExtension().lastPathComponent
        let type = contentType ?? UTType(filenameExtension: fileURL.pathExtension) ?? .data
        registerFileRepresentation(forTypeIdentifier: type.identifier, fileOptions: openInPlace ? .openInPlace : [], visibility: visibility) { done in
            done(fileURL, coordinated, nil); return nil
        }
    }
}

/// For UIKit's document picker and browser (Objective-C, which looks this up at run time): whether a file, by its
/// filename extension (or a directory), conforms to any of the comma-separated type identifiers.
@_cdecl("isim_uti_file_conforms")
public func _isimUTIFileConforms(_ ext: UnsafePointer<CChar>, _ isDirectory: Int32, _ types: UnsafePointer<CChar>) -> Int32 {
    let e = String(cString: ext)
    let t: UTType = isDirectory != 0 ? .folder : (e.isEmpty ? .data : UTType(filenameExtension: e) ?? .data)
    for id in String(cString: types).split(separator: ",") where UTType(String(id)).map(t.conforms(to:)) == true { return 1 }
    return 0
}
