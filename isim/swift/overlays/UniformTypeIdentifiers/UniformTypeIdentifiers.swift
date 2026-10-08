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

// MARK: - NSItemProvider

public protocol NSItemProviderReading: AnyObject {
    static var readableTypeIdentifiersForItemProvider: [String] { get }
    static func object(withItemProviderData data: Data, typeIdentifier: String) throws -> Self
}
public protocol NSItemProviderWriting: AnyObject {
    static var writableTypeIdentifiersForItemProvider: [String] { get }
    func loadData(withTypeIdentifier typeIdentifier: String, forItemProviderCompletionHandler completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress?
}

@objc public enum NSItemProviderRepresentationVisibility: Int, Sendable { case all = 0, teamOnly = 1, group = 2, ownProcess = 3 }

public let NSItemProviderErrorDomain = "NSItemProviderErrorDomain"
public struct _NSItemProviderError: CustomNSError, LocalizedError {
    public let errorCode: Int
    public static var errorDomain: String { NSItemProviderErrorDomain }
    public var errorDescription: String? { errorCode == -1000 ? "Cannot load representation of type" : "Item provider error \(errorCode)" }
}

/// isim's NSItemProvider: registered data representations, loaded asynchronously on a background queue like iOS.
open class NSItemProvider: NSObject, @unchecked Sendable {
    struct Rep { let type: String; let load: (@escaping (Data?, Error?) -> Void) -> Void }
    var reps: [Rep] = []
    var fileURL: URL?
    var items: [(type: String, item: NSSecureCoding)] = []      // init(item:typeIdentifier:): loadItem hands the object back
    open var suggestedName: String?

    public override init() { super.init() }
    public convenience init(item: NSSecureCoding?, typeIdentifier: String?) {
        self.init()
        if let t = typeIdentifier, let item {
            items.append((t, item))
            if let d = item as? NSData { let data = Data(referencing: d); registerDataRepresentation(forTypeIdentifier: t, visibility: .all) { $0(data, nil); return nil } }
            else if let s = item as? NSString { let data = Data((s as String).utf8); registerDataRepresentation(forTypeIdentifier: t, visibility: .all) { $0(data, nil); return nil } }
            else if let u = item as? NSURL {
                let data = Data((u.absoluteString ?? "").utf8)
                if u.isFileURL, let path = u.path { fileURL = URL(fileURLWithPath: path) }
                registerDataRepresentation(forTypeIdentifier: t, visibility: .all) { $0(data, nil); return nil }
            }
        }
    }
    public convenience init?(contentsOf fileURL: URL) {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        self.init()
        self.fileURL = fileURL
        suggestedName = fileURL.deletingPathExtension().lastPathComponent
        let type = UTType(filenameExtension: fileURL.pathExtension)?.identifier ?? UTType.data.identifier
        registerDataRepresentation(forTypeIdentifier: type, visibility: .all) { done in
            if let d = FileManager.default.contents(atPath: fileURL.path) { done(d, nil) } else { done(nil, _NSItemProviderError(errorCode: -1000)) }
            return nil
        }
    }
    public convenience init(object: NSItemProviderWriting) {
        self.init()
        for t in type(of: object).writableTypeIdentifiersForItemProvider {
            registerDataRepresentation(forTypeIdentifier: t, visibility: .all) { done in
                object.loadData(withTypeIdentifier: t) { d, e in done(d, e) }
            }
        }
    }

    open func registerDataRepresentation(forTypeIdentifier typeIdentifier: String, visibility: NSItemProviderRepresentationVisibility,
                                         loadHandler: @escaping @Sendable (@escaping (Data?, Error?) -> Void) -> Progress?) {
        reps.append(Rep(type: typeIdentifier, load: { done in _ = loadHandler(done) }))
    }
    open func registerObject(_ object: NSItemProviderWriting, visibility: NSItemProviderRepresentationVisibility) {
        for t in type(of: object).writableTypeIdentifiersForItemProvider {
            registerDataRepresentation(forTypeIdentifier: t, visibility: visibility) { done in object.loadData(withTypeIdentifier: t) { d, e in done(d, e) } }
        }
    }
    /// isim: the object loadItem(forTypeIdentifier:) hands back for this type (used by UIKit's extension hosting)
    public func _isimSetItem(_ item: NSSecureCoding, forTypeIdentifier typeIdentifier: String) { items.append((typeIdentifier, item)) }
    open var registeredTypeIdentifiers: [String] { reps.map(\.type) }
    open func registeredTypeIdentifiers(fileOptions: Int) -> [String] { registeredTypeIdentifiers }

    func conforms(_ have: String, _ want: String) -> Bool {
        if have == want { return true }
        guard let h = UTType(have), let w = UTType(want) else { return false }
        return h.conforms(to: w)
    }
    func rep(_ want: String) -> Rep? { reps.first { $0.type == want } ?? reps.first { conforms($0.type, want) } }
    open func hasItemConformingToTypeIdentifier(_ typeIdentifier: String) -> Bool { rep(typeIdentifier) != nil }
    open func hasRepresentationConforming(toTypeIdentifier typeIdentifier: String, fileOptions: Int) -> Bool { hasItemConformingToTypeIdentifier(typeIdentifier) }

    @discardableResult
    open func loadDataRepresentation(forTypeIdentifier typeIdentifier: String, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress {
        let p = Progress(totalUnitCount: 1)
        guard let r = rep(typeIdentifier) else {
            DispatchQueue.global().async { completionHandler(nil, _NSItemProviderError(errorCode: -1000)) }
            return p
        }
        DispatchQueue.global().async { r.load { d, e in p.completedUnitCount = 1; completionHandler(d, e) } }
        return p
    }
    /// the data written to a temporary file that is deleted when the handler returns (like iOS)
    @discardableResult
    open func loadFileRepresentation(forTypeIdentifier typeIdentifier: String, completionHandler: @escaping @Sendable (URL?, Error?) -> Void) -> Progress {
        let ext = UTType(typeIdentifier)?.preferredFilenameExtension ?? "data"
        return loadDataRepresentation(forTypeIdentifier: typeIdentifier) { d, e in
            guard let d else { completionHandler(nil, e); return }
            let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("\(UUID().uuidString).\(ext)")
            do { try d.write(to: url); completionHandler(url, nil); try? FileManager.default.removeItem(at: url) }
            catch { completionHandler(nil, error) }
        }
    }
    @discardableResult
    open func loadInPlaceFileRepresentation(forTypeIdentifier typeIdentifier: String, completionHandler: @escaping @Sendable (URL?, Bool, Error?) -> Void) -> Progress {
        if let fileURL { DispatchQueue.global().async { completionHandler(fileURL, true, nil) }; return Progress(totalUnitCount: 1) }
        return loadFileRepresentation(forTypeIdentifier: typeIdentifier) { u, e in completionHandler(u, false, e) }
    }
    open func canLoadObject(ofClass aClass: NSItemProviderReading.Type) -> Bool {
        aClass.readableTypeIdentifiersForItemProvider.contains { hasItemConformingToTypeIdentifier($0) }
    }
    @discardableResult
    open func loadObject(ofClass aClass: NSItemProviderReading.Type, completionHandler: @escaping @Sendable (NSItemProviderReading?, Error?) -> Void) -> Progress {
        guard let t = aClass.readableTypeIdentifiersForItemProvider.first(where: { hasItemConformingToTypeIdentifier($0) }) else {
            DispatchQueue.global().async { completionHandler(nil, _NSItemProviderError(errorCode: -1000)) }
            return Progress(totalUnitCount: 1)
        }
        nonisolated(unsafe) let cls = aClass
        return loadDataRepresentation(forTypeIdentifier: t) { d, e in
            guard let d else { completionHandler(nil, e); return }
            do { completionHandler(try cls.object(withItemProviderData: d, typeIdentifier: t), nil) } catch { completionHandler(nil, error) }
        }
    }
    @discardableResult
    open func loadItem(forTypeIdentifier typeIdentifier: String, options: [AnyHashable: Any]? = nil, completionHandler: (@Sendable (NSSecureCoding?, Error?) -> Void)? = nil) -> Progress {
        // the object given to init(item:typeIdentifier:) (a URL stays a URL, a string a string), like iOS
        if let hit = items.first(where: { $0.type == typeIdentifier }) ?? items.first(where: { conforms($0.type, typeIdentifier) }) {
            let obj = hit.item
            DispatchQueue.global().async { completionHandler?(obj, nil) }
            return Progress(totalUnitCount: 1)
        }
        return loadDataRepresentation(forTypeIdentifier: typeIdentifier) { d, e in completionHandler?(d.map { $0 as NSData }, e) }
    }
}

extension NSItemProvider {
    public func hasItemConforming(to contentType: UTType) -> Bool { hasItemConformingToTypeIdentifier(contentType.identifier) }
    public var registeredContentTypes: [UTType] { registeredTypeIdentifiers.compactMap { UTType($0) } }
    @discardableResult
    public func loadDataRepresentation(for contentType: UTType, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) -> Progress {
        loadDataRepresentation(forTypeIdentifier: contentType.identifier, completionHandler: completionHandler)
    }
    @discardableResult
    public func loadFileRepresentation(for contentType: UTType, openInPlace: Bool = false, completionHandler: @escaping @Sendable (URL?, Bool, Error?) -> Void) -> Progress {
        loadFileRepresentation(forTypeIdentifier: contentType.identifier) { u, e in completionHandler(u, false, e) }
    }
    public func registerDataRepresentation(for contentType: UTType, visibility: NSItemProviderRepresentationVisibility = .all,
                                           loadHandler: @escaping @Sendable (@escaping (Data?, Error?) -> Void) -> Progress?) {
        registerDataRepresentation(forTypeIdentifier: contentType.identifier, visibility: visibility, loadHandler: loadHandler)
    }
}

// NSExtensionItem (Foundation) keeps its attachments untyped in Objective-C; Swift sees [NSItemProvider]? like on iOS.
extension NSExtensionItem {
    public var attachments: [NSItemProvider]? {
        get { __attachments?.compactMap { $0 as? NSItemProvider } }
        set { __attachments = newValue }
    }
}
